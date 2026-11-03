#!/usr/bin/env zsh
#
# Automated status.zsh test: reports land in a file via PROGRAM_STATUS_TTY.
#
# Tests:
#   1. Each state's exact sequence, with app and a base64 msg
#   2. Control characters in msg become spaces; no msg means no msg key
#   3. NO_PROGRAM_STATUS and an unwritable target report nothing, still succeed
#   4. A calling script's ownership leaves the root record alone; prompts still report
#   5. Root reports, and only those, also go to PROGRAM_STATUS_LAST
#   6. status_track reports done or error at exit, never for subshells, and not
#      over an explicit done
#   7. yes_or_no reports nothing when answered by YES_OR_NO_ANSWER

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh

sandbox=$(mktemp -d ${TMPDIR:-/tmp}/test-status.XXXXXX)
trap "rm -rf $sandbox" EXIT
out=$sandbox/tty
unset NO_PROGRAM_STATUS PROGRAM_STATUS_OWNER
export PROGRAM_STATUS_TTY=$out

failures=0
esc=$'\e]7501;' st=$'\e\\'

assert_eq() {  # description, expected, actual
    if [[ $3 == $2 ]]; then
        log_info "PASS: $1"
    else
        log_error "FAIL: $1"
        log_error "  expected: ${(q+)2}"
        log_error "  actual:   ${(q+)3}"
        (( ++failures ))
    fi
}

# Runs zsh code in a fresh script named "tracked" and prints what it reported
report() {
    : > $out
    print -r -- "source $the_usual/status.zsh; $1" > $sandbox/tracked
    zsh $sandbox/tracked || true
    print -rn -- "$(<$out)"
}

b64() { print -rn -- $1 | base64 | tr -d '\n' }

# 1. States
assert_eq "working with msg" "${esc}state=working:app=tracked:msg=$(b64 'Copying 3 files')$st" \
    "$(report 'status_working "Copying 3 files"')"
assert_eq "done" "${esc}state=done:app=tracked$st" "$(report status_done)"
assert_eq "error" "${esc}state=error:app=tracked:msg=$(b64 bad)$st" "$(report 'status_error bad')"
assert_eq "idle" "${esc}state=idle:app=tracked$st" "$(report status_idle)"
assert_eq "blocked with kind" "${esc}state=blocked:kind=auth:app=tracked:msg=$(b64 'Log in')$st" \
    "$(report 'status_blocked -k auth "Log in"')"
assert_eq "blocked without kind" "${esc}state=blocked:app=tracked:msg=$(b64 Stalled)$st" \
    "$(report 'status_blocked Stalled')"
assert_eq "ask and answered" \
    "${esc}state=blocked:kind=question:id=prompt-<->:app=tracked:msg=$(b64 'Go?')$st${esc}state=clear:id=prompt-<->$st" \
    "$(report 'status_ask "Go?"; status_answered' | sed -E 's/prompt-[0-9]+/prompt-<->/g')"

# 2. msg sanitizing
assert_eq "control characters become spaces" "${esc}state=working:app=tracked:msg=$(b64 'a b c')$st" \
    "$(report 'status_working $'"'"'a\nb\tc'"'"'')"

# 3. Off and unwritable
assert_eq "NO_PROGRAM_STATUS reports nothing" "" "$(NO_PROGRAM_STATUS=1 report status_working)"
assert_eq "unwritable target fails silently" "ok" \
    "$(PROGRAM_STATUS_TTY=$sandbox/missing/tty report 'status_working && print -n ok >> '$out)"

# 4. Nesting
assert_eq "a caller's ownership skips root reports" "" \
    "$(PROGRAM_STATUS_OWNER=1 report 'status_track; status_working; status_done')"
assert_eq "a nested prompt still reports" "${esc}state=blocked:kind=question:id=prompt-<->:app=tracked$st" \
    "$(PROGRAM_STATUS_OWNER=1 report status_ask | sed -E 's/prompt-[0-9]+/prompt-<->/g')"
report 'status_working; zsh -c "[[ \$PROGRAM_STATUS_OWNER == $$ ]]" && print -n ok > '$sandbox/child >/dev/null
assert_eq "the first reporter exports ownership to its children" "ok" "$(<$sandbox/child)"

# 5. PROGRAM_STATUS_LAST: root reports only, the last one replacing the others
last=$sandbox/last
PROGRAM_STATUS_LAST=$last report 'status_working; status_ask "Go?"; status_answered; status_done "All moved"' >/dev/null
assert_eq "last root report goes to PROGRAM_STATUS_LAST" "state=done:app=tracked:msg=$(b64 'All moved')" "$(<$last)"
rm -f $last
PROGRAM_STATUS_LAST=$last report 'status_ask "Go?"; status_answered' >/dev/null
assert_eq "prompt records leave PROGRAM_STATUS_LAST alone" "absent" "$([[ -e $last ]] && print present || print absent)"
PROGRAM_STATUS_LAST=$last PROGRAM_STATUS_OWNER=1 report 'status_done' >/dev/null
assert_eq "a caller's ownership leaves PROGRAM_STATUS_LAST alone" "absent" "$([[ -e $last ]] && print present || print absent)"

# 6. status_track
assert_eq "track: done at exit 0" "${esc}state=working:app=tracked$st${esc}state=done:app=tracked$st" \
    "$(report 'status_track')"
assert_eq "track: error at a failing exit" \
    "${esc}state=working:app=tracked$st${esc}state=error:app=tracked:msg=$(b64 'Exited with 3')$st" \
    "$(report 'status_track; exit 3')"
assert_eq "track: subshells and jobs don't report" \
    "${esc}state=working:app=tracked$st${esc}state=done:app=tracked$st" \
    "$(report 'status_track; ( exit 4 ); x=$(exit 5); { exit 6 } & wait; true')"
assert_eq "track: an explicit done stands" \
    "${esc}state=working:app=tracked$st${esc}state=done:app=tracked:msg=$(b64 'All moved')$st" \
    "$(report 'status_track; status_done "All moved"')"
assert_eq "track: an explicit idle stands (interrupted)" \
    "${esc}state=working:app=tracked$st${esc}state=idle:app=tracked$st" \
    "$(report 'status_track; status_idle; exit 130')"
assert_eq "track: working again after done reports at exit" \
    "${esc}state=working:app=tracked$st${esc}state=done:app=tracked$st${esc}state=working:app=tracked$st${esc}state=error:app=tracked:msg=$(b64 'Exited with 1')$st" \
    "$(report 'status_track; status_done; status_working; false; exit')"

# 7. yes_or_no answered without a prompt
assert_eq "preset answer reports nothing" "" \
    "$(report "source $the_usual/argparse/_init.zsh; source $the_usual/argparse/y.zsh; YES_OR_NO_ANSWER=y yes_or_no 'Go?'")"

if (( failures )); then
    log_error "$failures test(s) failed"
    exit 1
fi
log_success "All assertions passed"
