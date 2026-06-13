source $ZDOTDIR/the-usual/utils.zsh

OPTIONS_DESCRIPTION+=("-v, --verbose" "Increase verbosity")
OPTIONS_DESCRIPTION+=("-q, --quiet" "Decrease verbosity")

# Argument parser
zparseopts -D -E -- \
    {v,-verbose}+=FLAG_V \
    {q,-quiet}+=FLAG_Q
(( VERBOSITY = ${VERBOSITY:-0} + ${#FLAG_V} - ${#FLAG_Q} ))
[[ $VERBOSITY < 0 ]] && VERBOSITY=0
export VERBOSITY

# Logging headers
LOG_SCRIPT_NAME=1
function log_header {
    [[ -n "$MODE_DRY_RUN" ]] && print -n "[DRY_RUN] "
    [[ -n "$LOG_TIMESTAMP" ]] && print -n "$(date "+%Y-%m-%d %H:%M:%S") "
    [[ -n "$LOG_SCRIPT_NAME" ]] && print -n "[$(current_script_name)] "
}

# Success
function log_success {
    print -P "%F{green}$(log_header)$*%f" >&2
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
    print -P "%F{blue}$(log_header)$*%f" >&2
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
    print -P "%F{yellow}$(log_header)$*%f" >&2
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
    print -P "%F{red}$(log_header)$*%f" >&2
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
