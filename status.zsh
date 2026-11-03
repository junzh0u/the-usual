# Report the script's state to its terminal as OSC 7501, the Program Status
# Protocol (https://www.superlogical.com/rex/docs/build/program-status.md), so
# a terminal that speaks it (Rex, herdr-core) can show it: a spinner on the
# tab, a mark when the script is done or needs you, and a confirmation before
# closing a pane whose script is still working.
#
#   status_track [MSG]               working now; done (exit 0) or error at exit,
#                                    unless the script reported done, error or idle
#   status_working [MSG]
#   status_blocked [-k KIND] [MSG]   needs the user; KIND: permission, question, auth
#   status_done [MSG]  status_error [MSG]  status_idle [MSG]
#   status_ask [MSG]  status_answered  a prompt is waiting on the user / no longer
#
# Reports go to /dev/tty, so piped or captured output stays clean; without a
# controlling terminal (launchd, cron) every call is a silent no-op. They are
# sent whatever the terminal: a script reached over ssh can't tell it runs in
# Rex (ssh forwards no REX_* variable), and terminals that don't implement
# OSC 7501 discard it. NO_PROGRAM_STATUS=1 turns reporting off;
# PROGRAM_STATUS_TTY sends it elsewhere (tests).
#
# One script owns the pane's root record: the first to report exports
# PROGRAM_STATUS_OWNER, and scripts it runs leave the root record alone, so a
# nested script's done can't hide its caller still working. A prompt uses a
# record of its own (prompt-<pid>), so it shows from any depth, and clearing it
# leaves the root record as it was.
#
# The terminal drops working and blocked by itself when the script exits back
# to a shell prompt; done and error stay until the user has seen them.

source ${${(%):-%x}:A:h}/utils.zsh
zmodload zsh/system  # $sysparams[pid]: the real pid, which $$ isn't in a subshell

# _status_emit PAIRS [MSG]: send one report, adding app and the encoded msg
function _status_emit {
    [[ -z ${NO_PROGRAM_STATUS:-} ]] || return 0
    local pairs=$1 msg=${2:-} app=
    if [[ $pairs != state=clear* ]]; then
        app=${$(current_script_name)//[^A-Za-z0-9_.+-]/-}
        [[ -n $app ]] && pairs+=":app=${app[1,32]}"
    fi
    if [[ -n $msg ]] && (( $+commands[base64] )); then
        # One line of at most 2048 bytes: no control characters, and 500
        # characters stay under the limit even at 4 bytes each
        msg=${${msg//[[:cntrl:]]/ }[1,500]}
        pairs+=":msg=$(print -rn -- $msg | base64 | tr -d '\n')"
    fi
    { print -rn -- $'\e]7501;'$pairs$'\e\\' >> ${PROGRAM_STATUS_TTY:-/dev/tty} } 2> /dev/null
    return 0
}

# Claim the root record for this script unless a calling script holds it
function _status_owns {
    [[ -n ${PROGRAM_STATUS_OWNER:-} ]] || export PROGRAM_STATUS_OWNER=$$
    [[ $PROGRAM_STATUS_OWNER == $$ ]]
}

typeset -g _status_final= _status_tracker=

function status_{working,done,error,idle} {
    _status_owns || return 0
    local state=${0#status_}
    [[ $state == (done|error|idle) ]] && _status_final=1 || _status_final=
    _status_emit state=$state ${1:-}
}

function status_blocked {
    local -a kind=()
    zparseopts -D -F -- k:=kind || return 1
    _status_owns || return 0
    _status_final=
    _status_emit "state=blocked${kind:+:kind=$kind[-1]}" ${1:-}
}

function status_ask {
    _status_emit "state=blocked:kind=question:id=prompt-$$" ${1:-}
}

function status_answered {
    _status_emit "state=clear:id=prompt-$$"
}

function status_track {
    _status_owns || return 0
    status_working ${1:-}
    _status_tracker=$sysparams[pid]
    autoload -Uz add-zsh-hook
    add-zsh-hook zshexit _status_at_exit
}

# zshexit also runs as subshells and background jobs exit; only the script
# itself reports, and not over a done, error or idle it already reported (idle:
# interrupted, per the protocol)
function _status_at_exit {
    local rc=$?
    [[ $sysparams[pid] == $_status_tracker && -z $_status_final ]] || return 0
    if (( rc == 0 )); then
        status_done
    else
        status_error "Exited with $rc"
    fi
}
