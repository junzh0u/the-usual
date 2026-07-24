#!/usr/bin/env zsh
#
# Automated current_script_name test — verifies it returns the calling script's
# name, not the file where the function is defined.
#
# Tests:
#   1. Direct call returns this script's name
#   2. Call from a different script returns that script's name

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh
source $the_usual/utils.zsh

failures=0

assert_eq() {
    local description=$1 expected=$2 actual=$3
    if [[ $actual == $expected ]]; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected '$expected', got '$actual')"
        (( ++failures ))
    fi
}

# ── Test 1: Direct call returns this script's name ────────────────────

log_info "── Test 1: Direct call ──"

result=$(current_script_name)
assert_eq "returns calling script name" "test-current-script-name" "$result"

# ── Test 2: Call from a different script ──────────────────────────────

log_info "── Test 2: Call from helper script ──"

tmpfile=$(mktemp -t test_current_script_name.XXXXXX.zsh)
trap 'rm -f "$tmpfile"' EXIT
cat > "$tmpfile" <<HELPER
source $the_usual/utils.zsh
print \$(current_script_name)
HELPER
result=$(zsh "$tmpfile")
expected=${${tmpfile:t}%.zsh}
assert_eq "helper returns its own name" "$expected" "$result"

# ── Summary ───────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
