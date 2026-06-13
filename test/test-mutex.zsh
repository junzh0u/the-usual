#!/usr/bin/env zsh
#
# Automated mutex test — verifies mutual exclusion, handoff, and signal handling.
#
# Test 1 (handoff):
#   P1 acquires the mutex, holds it for 3s, then exits
#   P2 starts 1s after P1, blocks on the mutex, acquires it after P1 exits
#   Asserts ordering and that P2 was genuinely blocked
#
# Test 2 (signal):
#   P1 acquires the mutex, sleeps for a long time
#   P2 starts 1s after P1, blocks on the mutex
#   P1 is killed with SIGINT (ctrl+c) after 2s
#   Asserts P1 dies promptly and P2 acquires the mutex shortly after

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh

failures=0

assert() {
    local description=$1 condition=$2
    if eval "(( $condition ))"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description ($condition)"
        (( failures++ ))
    fi
}

# Helper: acquire mutex, log timestamps, hold for N seconds
run_holder() {
    local name=$1 logfile=$2 hold=$3
    zsh -c "
        export VERBOSITY=-1
        source $the_usual/mutex.zsh
        mutex test_mutex_auto
        echo \"$name acquired \$(date +%s)\" >> $logfile
        sleep $hold
        echo \"$name released \$(date +%s)\" >> $logfile
    " &
}

# ── Test 1: Normal handoff ──────────────────────────────────────────

log_info "── Test 1: Normal handoff ──"

log1="$(mktemp -t test_mutex_auto.XXXXX)"

log_info "Starting P1 (holds mutex for 3s)"
run_holder P1 "$log1" 3
p1_pid=$!

sleep 1

log_info "Starting P2 (should block until P1 exits)"
run_holder P2 "$log1" 1
p2_pid=$!

wait $p1_pid $p2_pid

p1_acquired=$(grep "P1 acquired" "$log1" | awk '{print $NF}')
p1_released=$(grep "P1 released" "$log1" | awk '{print $NF}')
p2_acquired=$(grep "P2 acquired" "$log1" | awk '{print $NF}')
p2_released=$(grep "P2 released" "$log1" | awk '{print $NF}')

assert "P2 acquired mutex after P1 released" "$p2_acquired >= $p1_released"
assert "P2 was blocked for >= 2s" "$(( p2_acquired - p1_acquired )) >= 2"
assert "Both processes completed" "${p2_released:-0} > 0 && ${p1_released:-0} > 0"

rm -f "$log1"

# ── Test 2: Signal handling (SIGINT kills holder, releases mutex) ───

log_info "── Test 2: Signal handling ──"

log2="$(mktemp -t test_mutex_auto.XXXXX)"

log_info "Starting P1 (holds mutex for 30s, will be killed)"
run_holder P1 "$log2" 30
p1_pid=$!

sleep 1

log_info "Starting P2 (should block until P1 is killed)"
run_holder P2 "$log2" 1
p2_pid=$!

sleep 2

kill_time=$(date +%s)
# Simulate ctrl+c: kill P1 and all its children (sleep, lockf coprocess)
log_info "Sending SIGINT to P1 process tree (pid $p1_pid)"
pkill -INT -P $p1_pid 2>/dev/null
kill -INT $p1_pid 2>/dev/null

# Wait for P1 to die (should be immediate)
wait $p1_pid 2>/dev/null || true
p1_death_time=$(date +%s)

# Wait for P2 to finish (should acquire mutex promptly)
wait $p2_pid

p2_acquired=$(grep "P2 acquired" "$log2" | awk '{print $NF}')
p2_released=$(grep "P2 released" "$log2" | awk '{print $NF}')

assert "P1 died within 1s of SIGINT" "$(( p1_death_time - kill_time )) <= 1"
assert "P2 acquired mutex within 2s of SIGINT" "$(( p2_acquired - kill_time )) <= 2"
assert "P2 completed after signal handoff" "${p2_released:-0} > 0"

# P1 should NOT have a "released" line (it was killed)
if grep -q "P1 released" "$log2"; then
    log_error "FAIL: P1 logged release after being killed"
    (( failures++ ))
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
