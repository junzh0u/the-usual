#!/usr/bin/env zsh
#
# Automated log test — verifies log functions respect verbosity levels.
#
# Tests:
#   1. At verbosity 0: only base log functions produce output
#   2. At verbosity 1: _v variants also appear
#   3. At verbosity 2: _vv variants also appear
#   4. log_fatal exits with the specified code
#   5. Log output includes script name in brackets

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh

test_script="$the_usual/test/manual/test-log.zsh"
failures=0

assert_contains() {
    local description=$1 output=$2 pattern=$3
    if echo "$output" | grep -qE -- "$pattern"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected: $pattern)"
        (( failures++ ))
    fi
}

assert_not_contains() {
    local description=$1 output=$2 pattern=$3
    if ! echo "$output" | grep -qE -- "$pattern"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (unexpected: $pattern)"
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

strip_ansi() {
    sed $'s/\x1b\[[0-9;]*m//g'
}

run_log_test() {
    VERBOSITY=0 "$test_script" $@ 2>&1 | strip_ansi
}

# ── Test 1: Verbosity 0 — base functions only ──────────────────────

log_info "── Test 1: Verbosity 0 ──"

output=$(run_log_test 2>&1) || true

assert_contains     "log_success shown"    "$output" "log_success$"
assert_not_contains "log_success_v hidden" "$output" "log_success_v$"
assert_not_contains "log_success_vv hidden" "$output" "log_success_vv"

assert_contains     "log_info shown"       "$output" "log_info$"
assert_not_contains "log_info_v hidden"    "$output" "log_info_v$"
assert_not_contains "log_info_vv hidden"   "$output" "log_info_vv"

assert_contains     "log_warning shown"    "$output" "log_warning$"
assert_not_contains "log_warning_v hidden" "$output" "log_warning_v$"
assert_not_contains "log_warning_vv hidden" "$output" "log_warning_vv"

assert_contains     "log_error shown"      "$output" "log_error$"
assert_not_contains "log_error_v hidden"   "$output" "log_error_v$"
assert_not_contains "log_error_vv hidden"  "$output" "log_error_vv"

# ── Test 2: Verbosity 1 — _v variants appear ───────────────────────

log_info "── Test 2: Verbosity 1 ──"

output=$(VERBOSITY=1 "$test_script" 2>&1 | strip_ansi) || true

assert_contains     "log_success_v shown"   "$output" "log_success_v$"
assert_not_contains "log_success_vv hidden" "$output" "log_success_vv"

assert_contains     "log_info_v shown"      "$output" "log_info_v$"
assert_not_contains "log_info_vv hidden"    "$output" "log_info_vv"

assert_contains     "log_warning_v shown"   "$output" "log_warning_v$"
assert_not_contains "log_warning_vv hidden" "$output" "log_warning_vv"

assert_contains     "log_error_v shown"     "$output" "log_error_v$"
assert_not_contains "log_error_vv hidden"   "$output" "log_error_vv"

# ── Test 3: Verbosity 2 — _vv variants appear ──────────────────────

log_info "── Test 3: Verbosity 2 ──"

output=$(VERBOSITY=2 "$test_script" 2>&1 | strip_ansi) || true

assert_contains "log_success_vv shown" "$output" "log_success_vv"
assert_contains "log_info_vv shown"    "$output" "log_info_vv"
assert_contains "log_warning_vv shown" "$output" "log_warning_vv"
assert_contains "log_error_vv shown"   "$output" "log_error_vv"

# ── Test 4: log_fatal exits with specified code ─────────────────────

log_info "── Test 4: log_fatal exit code ──"

VERBOSITY=0 "$test_script" &>/dev/null && exit_code=$? || exit_code=$?
assert_exit_code "log_fatal exits 42" 42 $exit_code

output=$(run_log_test 2>&1) || true
assert_contains "log_fatal message shown" "$output" "log fatal and exit 42"

# ── Test 5: Log output includes script name ─────────────────────────

log_info "── Test 5: Script name in output ──"

assert_contains "output includes [test-log]" "$output" '\[test-log\]'

# ── Summary ─────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
