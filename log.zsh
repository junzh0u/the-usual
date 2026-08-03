# Severity-colored, script-name-prefixed, stderr-bound logging — plus a couple
# of verbosity-aware command wrappers. No argument parsing: source this directly
# for the log_* family, or source argparse/qv.zsh to also wire up -q/-v.
#
# Reads $VERBOSITY (default 0) to gate the _v/_vv/_vvv variants, and
# $MODE_DRY_RUN / $LOG_TIMESTAMP / $LOG_SCRIPT_NAME to decorate the header.
# Severity colors apply only when stderr is a terminal and $NO_COLOR is unset
# (https://no-color.org) — logs redirected to a file stay plain.
#
# One body, many names: each family below is a single function defined under
# every generated name, dispatching on the name it was called by ($0) —
# severity picks the color, the trailing _v/_vv/_vvv is the minimum $VERBOSITY
# to print at.

source ${${(%):-%x}:A:h}/utils.zsh

# Logging headers
: ${LOG_SCRIPT_NAME=1}
function log_header {
    [[ -n "$MODE_DRY_RUN" ]] && print -n "[DRY_RUN] "
    [[ -n "$LOG_TIMESTAMP" ]] && print -n "$(date "+%Y-%m-%d %H:%M:%S") "
    [[ -n "$LOG_SCRIPT_NAME" ]] && print -n "[$(current_script_name)] "
}

function _log_print {
    local color=$1
    shift
    if [[ -t 2 && -z $NO_COLOR ]]; then
        print -P "%F{$color}$(log_header)$*%f" >&2
    else
        print -P "$(log_header)$*" >&2
    fi
}

function log_{success,info,warning,error} {
    local -A colors=(log_success green log_info blue log_warning yellow log_error red)
    _log_print $colors[$0] $*
}

function log_{success,info,warning,error}_{v,vv,vvv} {
    local vees=${0##*_}
    (( VERBOSITY >= $#vees )) || return 1
    ${0%_v*} $*
}

function log_fatal {
    log_error "$1"
    [[ -n "$2" ]] && exit $2 || exit 1
}

# mkdir/mv, announcing themselves (-v) at the matching verbosity
function {mkdir,mv}_{v,vv} {
    local vees=${0##*_}
    if (( VERBOSITY >= $#vees )); then
        ${0%_*} -v $@
    else
        ${0%_*} $@
    fi
}
