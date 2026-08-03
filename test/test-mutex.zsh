#!/usr/bin/env zsh
#
# Automated mutex test — verifies mutual exclusion, handoff, and signal handling.
# Event-driven: holders log millisecond timestamps and coordinate through log
# markers and release-flag files instead of fixed sleeps, so the test costs
# process-startup time, not calibrated multi-second holds.
#
# Test 1 (handoff):
#   P1 acquires the mutex and holds until told to release
#   P2 starts once P1 holds, blocks on the mutex
#   Asserts P2 stays blocked while P1 holds, then acquires after P1 releases
#
# Test 2 (signal):
#   P1 acquires the mutex and holds indefinitely (10s cap)
#   P2 starts once P1 holds, blocks on the mutex
#   P1 is killed with SIGINT (ctrl+c)
#   Asserts P1 dies promptly and P2 acquires the mutex shortly after
#
# Timing SLAs (P1 dies within 1s, P2 acquires within 2s) are generous upper
# bounds — they only add wall time when they fail.

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh
zmodload zsh/datetime
zmodload zsh/zselect  # sub-second sleep without relying on non-integer sleep(1)

failures=0

assert() {
    local description=$1 condition=$2
    if eval "(( $condition ))"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description ($condition)"
        (( ++failures ))
    fi
}

# Poll (50ms) until a marker line appears; fail the run after 10s
wait_for() {
    local pattern=$1 file=$2
    local -F deadline=$(( EPOCHREALTIME + 10 ))
    until grep -q -- "$pattern" "$file" 2>/dev/null; do
        (( EPOCHREALTIME < deadline )) || return 1
        zselect -t 5 || :
    done
}

# Helper: log waiting, acquire mutex, log acquired, hold until the release
# flag file exists (10s cap), log released. Pass /dev/null to release
# immediately. Timestamps are $EPOCHREALTIME (ms precision, no date fork).
run_holder() {
    local name=$1 logfile=$2 release=$3
    zsh -c "
        export VERBOSITY=-1
        zmodload zsh/datetime
        zmodload zsh/zselect
        source $the_usual/mutex.zsh
        echo \"$name waiting \$EPOCHREALTIME\" >> $logfile
        mutex test_mutex_auto
        echo \"$name acquired \$EPOCHREALTIME\" >> $logfile
        for (( i = 0; i < 200; i++ )); do
            [[ -e $release ]] && break
            zselect -t 5 || :
        done
        echo \"$name released \$EPOCHREALTIME\" >> $logfile
    " &
}

stamp() {  # last field of the marker line, or 0 if absent
    local line=$(grep -- "$1" "$2" 2>/dev/null | tail -1)
    print -- ${line##* }
}

# ── Test 1: Normal handoff ──────────────────────────────────────────

log_info "── Test 1: Normal handoff ──"

log1="$(mktemp -t test_mutex_auto.XXXXX)"
release1="$log1.release"

log_info "Starting P1 (holds mutex until released)"
run_holder P1 "$log1" "$release1"
p1_pid=$!
wait_for "P1 acquired" "$log1" || log_fatal "P1 never acquired the mutex"

log_info "Starting P2 (should block until P1 releases)"
run_holder P2 "$log1" /dev/null
p2_pid=$!
wait_for "P2 waiting" "$log1" || log_fatal "P2 never started"
zselect -t 20 || :  # let P2 reach the blocking mutex call

if grep -q "P2 acquired" "$log1"; then
    log_error "FAIL: P2 acquired the mutex while P1 still held it"
    (( ++failures ))
else
    log_info "PASS: P2 blocked while P1 held the mutex"
fi

touch "$release1"
wait $p1_pid $p2_pid

p1_released=$(stamp "P1 released" "$log1")
p2_acquired=$(stamp "P2 acquired" "$log1")
p2_released=$(stamp "P2 released" "$log1")

assert "P2 acquired mutex after P1 released" "$p2_acquired >= $p1_released"
assert "Both processes completed" "${p2_released:-0} > 0 && ${p1_released:-0} > 0"

rm -f "$log1" "$release1"

# ── Test 2: Signal handling (SIGINT kills holder, releases mutex) ───

log_info "── Test 2: Signal handling ──"

log2="$(mktemp -t test_mutex_auto.XXXXX)"

log_info "Starting P1 (holds mutex until killed)"
run_holder P1 "$log2" "$log2.never"
p1_pid=$!
wait_for "P1 acquired" "$log2" || log_fatal "P1 never acquired the mutex"

log_info "Starting P2 (should block until P1 is killed)"
run_holder P2 "$log2" /dev/null
p2_pid=$!
wait_for "P2 waiting" "$log2" || log_fatal "P2 never started"
zselect -t 20 || :  # let P2 reach the blocking mutex call

kill_time=$EPOCHREALTIME
# Simulate ctrl+c: kill P1 and all its children (holder loop, lock coprocess)
log_info "Sending SIGINT to P1 process tree (pid $p1_pid)"
pkill -INT -P $p1_pid 2>/dev/null
kill -INT $p1_pid 2>/dev/null

# Wait for P1 to die (should be immediate)
wait $p1_pid 2>/dev/null || true
p1_death_time=$EPOCHREALTIME

# Wait for P2 to finish (should acquire mutex promptly)
wait $p2_pid

p2_acquired=$(stamp "P2 acquired" "$log2")
p2_released=$(stamp "P2 released" "$log2")

assert "P1 died within 1s of SIGINT" "$p1_death_time - $kill_time <= 1"
assert "P2 acquired mutex within 2s of SIGINT" "$p2_acquired - $kill_time <= 2"
assert "P2 completed after signal handoff" "${p2_released:-0} > 0"

# P1 should NOT have a "released" line (it was killed)
if grep -q "P1 released" "$log2"; then
    log_error "FAIL: P1 logged release after being killed"
    (( ++failures ))
else
    log_info "PASS: P1 did not log release (killed as expected)"
fi

rm -f "$log2"

# ── Summary ─────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
