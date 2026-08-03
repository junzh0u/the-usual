# Severity-colored, script-name-prefixed, stderr-bound logging — plus a couple
# of verbosity-aware command wrappers. No argument parsing: source this directly
# for the log_* family, or source argparse/qv.zsh to also wire up -q/-v.
#
# Reads $VERBOSITY (default 0) to gate the _v/_vv/_vvv variants, and
# $MODE_DRY_RUN / $LOG_TIMESTAMP / $LOG_SCRIPT_NAME to decorate the header.
# Severity colors apply only when stderr is a terminal and $NO_COLOR is unset
# (https://no-color.org) — logs redirected to a file stay plain.

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

# Success
function log_success {
    _log_print green $*
}
function _log_success_v {
  (( VERBOSITY >= $1 )) || return 1
  shift
  log_success $*
}
function log_success_v {
  _log_success_v 1 $*
}
function log_success_vv {
  _log_success_v 2 $*
}

# Info
function log_info {
    _log_print blue $*
}
function _log_info_v {
  (( VERBOSITY >= $1 )) || return 1
  shift
  log_info $*
}
function log_info_v {
  _log_info_v 1 $*
}
function log_info_vv {
  _log_info_v 2 $*
}

# Warning
function log_warning {
    _log_print yellow $*
}
function _log_warning_v {
  (( VERBOSITY >= $1 )) || return 1
  shift
  log_warning $*
}
function log_warning_v {
  _log_warning_v 1 $*
}
function log_warning_vv {
  _log_warning_v 2 $*
}
function log_warning_vvv {
  _log_warning_v 3 $*
}

# Error
function log_error {
    _log_print red $*
}
function _log_error_v {
  (( VERBOSITY >= $1 )) || return 1
  shift
  log_error $*
}
function log_error_v {
  _log_error_v 1 $*
}
function log_error_vv {
  _log_error_v 2 $*
}

# Fatal
function log_fatal {
  log_error "$1"
  [[ -n "$2" ]] && exit $2 || exit 1
}

# mkdir
function mkdir_v {
  if (( VERBOSITY >= 1 )); then
    mkdir -v $@
  else
    mkdir $@
  fi
}

function mkdir_vv {
  if (( VERBOSITY >= 2 )); then
    mkdir -v $@
  else
    mkdir $@
  fi
}

# mv
function mv_v {
  if (( VERBOSITY >= 1 )); then
    mv -v $@
  else
    mv $@
  fi
}

function mv_vv {
  if (( VERBOSITY >= 2 )); then
    mv -v $@
  else
    mv $@
  fi
}
