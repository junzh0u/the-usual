#!/usr/bin/env zsh
#
# Automated require_env test.
#
# Tests:
#   1. All vars set  -> succeeds (no exit)
#   2. An unset var  -> exits non-zero
#   3. An empty var  -> exits non-zero (empty is treated as missing)
#   4. No args       -> succeeds (nothing required)
#   5. Message lists every missing var

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh
source $the_usual/utils.zsh

failures=0

# require_env calls log_fatal (which exit()s) on failure, so every call runs in
# a ( ) subshell and we assert on its exit status.
assert_ok() {   # description, VAR...
    local description=$1; shift
    if ( require_env $@ ) 2>/dev/null; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected success)"
        (( failures++ ))
    fi
}

assert_fatal() {  # description, VAR...
    local description=$1; shift
    if ( require_env $@ ) 2>/dev/null; then
        log_error "FAIL: $description (expected fatal exit)"
        (( failures++ ))
    else
        log_info "PASS: $description"
    fi
}

SET_A="/tmp/a"
SET_B="/tmp/b"
EMPTY_VAR=""
# NEVER_SET intentionally never assigned

# ── Test 1: all set ─────────────────────────────────────────────────
log_info "── Test 1: all set ──"
assert_ok "both vars set" SET_A SET_B

# ── Test 2: unset var ───────────────────────────────────────────────
log_info "── Test 2: unset var ──"
assert_fatal "one var unset" SET_A NEVER_SET

# ── Test 3: empty var ───────────────────────────────────────────────
log_info "── Test 3: empty var ──"
assert_fatal "empty var counts as missing" SET_A EMPTY_VAR

# ── Test 4: no args ─────────────────────────────────────────────────
log_info "── Test 4: no args ──"
assert_ok "no vars required"

# ── Test 5: message lists all missing ───────────────────────────────
log_info "── Test 5: message lists all missing ──"
msg=$( ( require_env MISS_ONE MISS_TWO ) 2>&1 ) || true  # log_fatal exits non-zero; don't trip err_exit
if [[ $msg == *MISS_ONE* && $msg == *MISS_TWO* ]]; then
    log_info "PASS: message lists every missing var"
else
    log_error "FAIL: message missing a var name (got: $msg)"
    (( failures++ ))
fi

# ── Summary ─────────────────────────────────────────────────────────
if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
