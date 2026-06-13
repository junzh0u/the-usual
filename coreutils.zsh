# Portable wrappers for GNU vs BSD coreutils differences

# Detect GNU vs BSD coreutils once at source time
if stat --version &>/dev/null 2>&1; then
    _COREUTILS_FLAVOR=gnu
else
    _COREUTILS_FLAVOR=bsd
fi

# Get file size in bytes
# Usage: file_size /path/to/file
function file_size {
    if [[ $_COREUTILS_FLAVOR == gnu ]]; then
        stat -c %s "$1" 2>/dev/null
    else
        stat -f %z "$1" 2>/dev/null
    fi
}

# Get file modification time as epoch seconds
# Usage: file_mtime /path/to/file
function file_mtime {
    if [[ $_COREUTILS_FLAVOR == gnu ]]; then
        stat -c %Y "$1" 2>/dev/null
    else
        stat -f %m "$1" 2>/dev/null
    fi
}

# Format epoch timestamp to human readable string
# Usage: format_epoch 1234567890 [format]
# Default format: %Y-%m-%d %H:%M:%S
function format_epoch {
    local epoch=$1
    local fmt=${2:-'%Y-%m-%d %H:%M:%S'}
    if [[ $_COREUTILS_FLAVOR == gnu ]]; then
        date -d "@$epoch" "+$fmt" 2>/dev/null
    else
        date -r "$epoch" "+$fmt" 2>/dev/null
    fi
}

# Parse a date string and reformat in local timezone
# Usage: parse_date "2026-03-29T22:39:08+00:00" [format]
# Default format: %Y-%m-%d %H:%M:%S %Z
function parse_date {
    local input=$1
    local fmt=${2:-'%Y-%m-%d %H:%M:%S %Z'}
    if [[ $_COREUTILS_FLAVOR == gnu ]]; then
        date -d "$input" "+$fmt" 2>/dev/null
    else
        date -jf "%Y-%m-%dT%H:%M:%S%z" "$input" "+$fmt" 2>/dev/null
    fi
}

# Get epoch seconds for a relative time
# Usage: epoch_ago "1 hour ago"  (GNU) or epoch_ago "-1H" (BSD)
# For portability, use epoch_hours_ago/epoch_days_ago instead
function epoch_hours_ago {
    local hours=${1:-1}
    if [[ $_COREUTILS_FLAVOR == gnu ]]; then
        date +%s -d "$hours hours ago" 2>/dev/null
    else
        date -v-${hours}H +%s 2>/dev/null
    fi
}

function epoch_days_ago {
    local days=${1:-1}
    if [[ $_COREUTILS_FLAVOR == gnu ]]; then
        date +%s -d "$days days ago" 2>/dev/null
    else
        date -v-${days}d +%s 2>/dev/null
    fi
}
