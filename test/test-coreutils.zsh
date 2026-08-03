#!/usr/bin/env zsh
#
# Automated coreutils test — verifies the builtin-backed file/time helpers.
#
# Tests:
#   1. file_size / file_mtime on a fixture file
#   2. format_epoch renders an epoch (TZ-pinned)
#   3. parse_date epochs match across ±HHMM / ±HH:MM / Z spellings
#   4. Invalid inputs fail (return nonzero / empty) instead of lying

setopt err_exit

export TZ=UTC  # pin the timezone so rendered strings are deterministic

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh
source $the_usual/coreutils.zsh

failures=0

assert_eq() {
    local description=$1 actual=$2 expected=$3
    if [[ $actual == $expected ]]; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected '$expected', got '$actual')"
        (( ++failures ))
    fi
}

assert_fails() {
    local description=$1
    shift
    if ! out=$($@ 2>/dev/null) || [[ -z $out ]]; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected failure, got '$out')"
        (( ++failures ))
    fi
}

# ── Test 1: file_size / file_mtime ──────────────────────────────────

log_info "── Test 1: file_size / file_mtime ──"

fixture=$(mktemp)
print -n 12345 > $fixture

assert_eq "file_size counts bytes" "$(file_size $fixture)" 5

mtime=$(file_mtime $fixture)
now=$EPOCHSECONDS
if (( now - mtime >= 0 && now - mtime < 10 )); then
    log_info "PASS: file_mtime is current epoch"
else
    log_error "FAIL: file_mtime is current epoch (mtime=$mtime now=$now)"
    (( ++failures ))
fi

rm -f $fixture

# ── Test 2: format_epoch ────────────────────────────────────────────

log_info "── Test 2: format_epoch ──"

assert_eq "default format"  "$(format_epoch 1234567890)"       "2009-02-13 23:31:30"
assert_eq "custom format"   "$(format_epoch 1234567890 %Y)"    "2009"

# ── Test 3: parse_date offset spellings agree ───────────────────────

log_info "── Test 3: parse_date ──"

assert_eq "UTC, ±HHMM offset" \
    "$(parse_date 2026-03-29T22:39:08+0000 '%Y-%m-%d %H:%M:%S')" \
    "2026-03-29 22:39:08"
assert_eq "±HH:MM normalized to ±HHMM" \
    "$(parse_date 2026-03-29T22:39:08+00:00 %s)" \
    "$(parse_date 2026-03-29T22:39:08+0000 %s)"
assert_eq "trailing Z means +0000" \
    "$(parse_date 2026-03-29T22:39:08Z %s)" \
    "$(parse_date 2026-03-29T22:39:08+0000 %s)"
assert_eq "non-local offset honored" \
    "$(parse_date 2026-03-29T22:39:08-0700 %s)" \
    "$(( $(parse_date 2026-03-29T22:39:08+0000 %s) + 7 * 3600 ))"

# ── Test 4: invalid inputs fail ─────────────────────────────────────

log_info "── Test 4: invalid inputs ──"

assert_fails "file_size on missing file"   file_size /nonexistent/file
assert_fails "parse_date on a bare date"   parse_date 2026-03-29
assert_fails "epoch_hours_ago on garbage"  epoch_hours_ago abc

# ── Summary ─────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
