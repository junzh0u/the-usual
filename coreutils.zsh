# Fork-free file and time helpers, backed by zsh builtins (zsh/stat,
# zsh/datetime) — no subprocess per call. The file once wrapped GNU-vs-BSD
# stat(1)/date(1) flag differences, hence the name, kept for consumers.

zmodload -F zsh/stat b:zstat  # -F b:zstat only — a full zmodload would shadow
                              # the external stat command with a stat builtin
zmodload zsh/datetime         # $EPOCHSECONDS, strftime

# Get file size in bytes
# Usage: file_size /path/to/file
function file_size {
    zstat +size -- "$1" 2>/dev/null
}

# Get file modification time as epoch seconds
# Usage: file_mtime /path/to/file
function file_mtime {
    zstat +mtime -- "$1" 2>/dev/null
}

# Format epoch timestamp to human readable string
# Usage: format_epoch 1234567890 [format]
# Default format: %Y-%m-%d %H:%M:%S
function format_epoch {
    local epoch=$1
    local fmt=${2:-'%Y-%m-%d %H:%M:%S'}
    strftime "$fmt" "$epoch" 2>/dev/null
}

# Parse an ISO-8601 datetime string and reformat in local timezone
# Usage: parse_date "2026-03-29T22:39:08+00:00" [format]
# Default format: %Y-%m-%d %H:%M:%S %Z
# Accepts ±HH:MM / ±HHMM offsets and a trailing Z.
# The one helper that still forks date(1): zsh's strftime -r parses %z but
# the glibc mktime path IGNORES the offset (wrong epoch for non-local input
# on Ubuntu; macOS and Synology's static zsh honor it) — so the builtin
# can't be trusted here.
function parse_date {
    local input=$1
    local fmt=${2:-'%Y-%m-%d %H:%M:%S %Z'}
    if [[ -z $_COREUTILS_DATE_FLAVOR ]]; then  # lazy, cached per shell
        if date --version &>/dev/null; then
            typeset -g _COREUTILS_DATE_FLAVOR=gnu
        else
            typeset -g _COREUTILS_DATE_FLAVOR=bsd
        fi
    fi
    if [[ $_COREUTILS_DATE_FLAVOR == gnu ]]; then
        date -d "$input" "+$fmt" 2>/dev/null
    else
        [[ $input == *Z ]] && input=${input%Z}+0000
        if [[ $input == *[+-][0-9][0-9]:[0-9][0-9] ]]; then
            input=${input[1,-4]}${input[-2,-1]}  # strptime %z takes only ±HHMM
        fi
        date -jf "%Y-%m-%dT%H:%M:%S%z" "$input" "+$fmt" 2>/dev/null
    fi
}

# Get epoch seconds for N hours/days ago — pure arithmetic on $EPOCHSECONDS
# (fixed 3600/86400-second units, unlike date(1)'s calendar-aware relative
# dates; indistinguishable for the cutoff comparisons these serve)
function epoch_hours_ago {
    local hours=${1:-1}
    [[ $hours == <-> ]] || return 1
    print $(( EPOCHSECONDS - hours * 3600 ))
}

function epoch_days_ago {
    local days=${1:-1}
    [[ $days == <-> ]] || return 1
    print $(( EPOCHSECONDS - days * 86400 ))
}
