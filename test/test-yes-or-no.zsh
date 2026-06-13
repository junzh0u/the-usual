#!/usr/bin/env zsh
#
# Automated yes_or_no test — verifies preset answer behavior.
#
# Tests:
#   1. YES_OR_NO_ANSWER="Y"/"y"/"yes" makes yes_or_no return true
#   2. YES_OR_NO_ANSWER="N"/"n"/"no" makes yes_or_no return false
#   3. -y flag sets YES_OR_NO_ANSWER=y
#   4. Interactive prompt accepts y/n keystrokes via TTY (uses expect)

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

source $the_usual/argparse/_init.zsh
export VERBOSITY=${VERBOSITY:-1}
source $the_usual/argparse/qv.zsh
source $the_usual/argparse/y.zsh

failures=0

assert_yes() {
    local description=$1 answer=$2
    local YES_OR_NO_ANSWER=$answer
    if yes_or_no "should not prompt"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected yes)"
        (( failures++ ))
    fi
}

assert_no() {
    local description=$1 answer=$2
    local YES_OR_NO_ANSWER=$answer
    if ! yes_or_no "should not prompt"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected no)"
        (( failures++ ))
    fi
}

# ── Test 1: Affirmative answers ─────────────────────────────────────

log_info "── Test 1: Affirmative answers ──"

assert_yes "Y returns true"   "Y"
assert_yes "y returns true"   "y"
assert_yes "yes returns true" "yes"
assert_yes "Yes returns true" "Yes"

# ── Test 2: Negative answers ────────────────────────────────────────

log_info "── Test 2: Negative answers ──"

assert_no "N returns false"  "N"
assert_no "n returns false"  "n"
assert_no "no returns false" "no"
assert_no "No returns false" "No"

# ── Test 3: -y flag integration ─────────────────────────────────────

log_info "── Test 3: -y flag integration ──"

output=$(zsh -c "
    source $the_usual/argparse/_init.zsh
    export VERBOSITY=-1
    source $the_usual/argparse/qv.zsh
    source $the_usual/argparse/y.zsh
    source $the_usual/argparse/_h.zsh
    yes_or_no 'should not prompt' && echo YES || echo NO
" -- -y 2>&1)

if [[ $output == *YES* ]]; then
    log_info "PASS: -y flag makes yes_or_no return true"
else
    log_error "FAIL: -y flag did not make yes_or_no return true"
    (( failures++ ))
fi

# ── Test 4: Interactive prompt via expect ───────────────────────────

log_info "── Test 4: Interactive prompt ──"

expect_yes_or_no() {
    local key=$1
    expect -c "
        log_user 0
        spawn zsh -c {
            source $the_usual/argparse/y.zsh
            yes_or_no \"Confirm?\" && echo RESULT:YES || echo RESULT:NO
        }
        expect \"Confirm?\"
        send \"$key\"
        expect eof
        puts \$expect_out(buffer)
    " 2>/dev/null
}

output=$(expect_yes_or_no y)
if [[ $output == *RESULT:YES* ]]; then
    log_info "PASS: typing 'y' at interactive prompt returns true"
else
    log_error "FAIL: typing 'y' at interactive prompt did not return true"
    (( failures++ ))
fi

output=$(expect_yes_or_no n)
if [[ $output == *RESULT:NO* ]]; then
    log_info "PASS: typing 'n' at interactive prompt returns false"
else
    log_error "FAIL: typing 'n' at interactive prompt did not return false"
    (( failures++ ))
fi

# ── Summary ─────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
