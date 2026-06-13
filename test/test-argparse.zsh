#!/usr/bin/env zsh
#
# Automated argparse test — verifies flag parsing, expansion, and error handling.
#
# Tests:
#   1. Combined short flags are expanded (-vv → -v -v)
#   2. -- stops flag expansion
#   3. -n/--dry-run sets MODE_DRY_RUN=1
#   4. -v/--verbose increments VERBOSITY, -q/--quiet decrements, -vv gives 2
#   5. -y/--yes sets YES_OR_NO_ANSWER=y
#   6. Long flags work (--verbose, --dry-run, --yes, --quiet)
#   7. Remaining positional args are preserved
#   8. -h/--help prints usage and exits 0
#   9. Unsupported flags exit 2 with error message
#  10. wrong_usage prints error message before usage

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

source $the_usual/argparse/_init.zsh
export VERBOSITY=${VERBOSITY:-1}
source $the_usual/argparse/qv.zsh

run_test() {
    VERBOSITY=${TEST_VERBOSITY:-0} "$the_usual/test/manual/test-argparse.zsh" $@
}
failures=0

assert_output_contains() {
    local description=$1 output=$2 pattern=$3
    if echo "$output" | grep -qE -- "$pattern"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected pattern: $pattern)"
        (( failures++ ))
    fi
}

assert_output_not_contains() {
    local description=$1 output=$2 pattern=$3
    if ! echo "$output" | grep -qE -- "$pattern"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (unexpected pattern: $pattern)"
        (( failures++ ))
    fi
}

assert_exit_code() {
    local description=$1 expected=$2 actual=$3
    if (( actual == expected )); then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected exit $expected, got $actual)"
        (( failures++ ))
    fi
}

# ── Test 1: Combined flag expansion ─────────────────────────────────

log_info "── Test 1: Combined flag expansion ──"

output=$(run_test -vnq 2>&1)

assert_output_contains "-vnq expands to -v -n -q" "$output" "Argument after expanding:"
# After expanding, -v -n -q should appear as separate args
assert_output_contains "-v is split out" "$output" $'^\t-v$'
assert_output_contains "-n is split out" "$output" $'^\t-n$'
assert_output_contains "-q is split out" "$output" $'^\t-q$'

# ── Test 2: -- stops flag expansion ─────────────────────────────────

log_info "── Test 2: -- stops expansion ──"

output=$(run_test -- -vn 2>&1)
# -vn after -- should NOT be expanded
assert_output_contains "-vn stays combined after --" "$output" $'^\t-vn$'

# ── Test 3: -n sets MODE_DRY_RUN ────────────────────────────────────

log_info "── Test 3: Dry run flag ──"

output=$(run_test -n 2>&1)
assert_output_contains "-n sets MODE_DRY_RUN=1" "$output" "MODE_DRY_RUN.*: 1"

output=$(run_test --dry-run 2>&1)
assert_output_contains "--dry-run sets MODE_DRY_RUN=1" "$output" "MODE_DRY_RUN.*: 1"

output=$(run_test 2>&1)
assert_output_not_contains "no -n leaves MODE_DRY_RUN unset/0" "$output" "MODE_DRY_RUN.*: 1"

# ── Test 4: Verbosity ──────────────────────────────────────────────

log_info "── Test 4: Verbosity levels ──"

output=$(run_test 2>&1)
assert_output_contains "default VERBOSITY is 0" "$output" "VERBOSITY.*: 0"

output=$(run_test -v 2>&1)
assert_output_contains "-v sets VERBOSITY to 1" "$output" "VERBOSITY.*: 1"

output=$(run_test --verbose 2>&1)
assert_output_contains "--verbose sets VERBOSITY to 1" "$output" "VERBOSITY.*: 1"

output=$(run_test -vv 2>&1)
assert_output_contains "-vv sets VERBOSITY to 2" "$output" "VERBOSITY.*: 2"

output=$(run_test -q 2>&1)
assert_output_contains "-q from 0 stays at 0 (clamped)" "$output" "VERBOSITY.*: 0"

output=$(run_test --quiet 2>&1)
assert_output_contains "--quiet from 0 stays at 0 (clamped)" "$output" "VERBOSITY.*: 0"

output=$(TEST_VERBOSITY=2 run_test -q 2>&1)
assert_output_contains "-q from 2 gives 1" "$output" "VERBOSITY.*: 1"

# ── Test 5: -y sets YES_OR_NO_ANSWER ────────────────────────────────

log_info "── Test 5: Yes flag ──"

output=$(run_test -y 2>&1)
assert_output_contains "-y sets YES_OR_NO_ANSWER=y" "$output" "YES_OR_NO_ANSWER.*: y"

output=$(run_test --yes 2>&1)
assert_output_contains "--yes sets YES_OR_NO_ANSWER=y" "$output" "YES_OR_NO_ANSWER.*: y"

# ── Test 6: Positional args preserved ───────────────────────────────

log_info "── Test 6: Positional args ──"

output=$(run_test -v foo bar baz 2>&1)
assert_output_contains "foo is in remaining args" "$output" $'^\tfoo$'
assert_output_contains "bar is in remaining args" "$output" $'^\tbar$'
assert_output_contains "baz is in remaining args" "$output" $'^\tbaz$'

# ── Test 7: -h/--help prints usage and exits 0 ─────────────────────

log_info "── Test 7: Help flag ──"

output=$(run_test -h 2>&1)
exit_code=$?
assert_exit_code "-h exits 0" 0 $exit_code
assert_output_contains "-h shows Usage:" "$output" "^Usage:"
assert_output_contains "-h shows Options:" "$output" "^Options:"
assert_output_contains "-h shows Exit codes:" "$output" "^Exit codes:"
assert_output_contains "-h lists all options" "$output" "--dry-run"
assert_output_contains "-h lists exit code 0" "$output" "0.*Success"
assert_output_contains "-h lists exit code 2" "$output" "2.*Wrong usage"

output=$(run_test --help 2>&1)
exit_code=$?
assert_exit_code "--help exits 0" 0 $exit_code
assert_output_contains "--help shows Usage:" "$output" "^Usage:"

# ── Test 8: Unsupported flags exit 2 with error ────────────────────

log_info "── Test 8: Unsupported flags ──"

output=$(run_test --invalid 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code "--invalid exits 2" 2 $exit_code
assert_output_contains "--invalid shows usage" "$output" "^Usage:"
assert_output_contains "--invalid shows bad option error" "$output" "bad option"

output=$(run_test -x 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code "-x exits 2" 2 $exit_code

# ── Summary ─────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
