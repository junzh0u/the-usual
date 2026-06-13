# Internal helper for mutex acquisition
# Returns 0 on success, 1 on failure
# Sets MUTEX and holder_pid variables in caller's scope
function _mutex_acquire {
    local name=$1
    local timeout=$2
    MUTEX="$TMPPREFIX.$name.lock"

    log_info_v "PID $$ acquiring mutex $MUTEX${timeout:+ (timeout: ${timeout}s)}"

    # Ensure lock file exists (append mode doesn't truncate)
    : >> $MUTEX

    # Start a coprocess that holds the lock.
    # Uses lockf (macOS/BSD) or flock (Linux).
    if (( $+commands[lockf] )); then
        if [[ -n $timeout ]]; then
            coproc lockf -st $timeout $MUTEX sh -c "echo ready; read"
        else
            coproc lockf -s $MUTEX sh -c "echo ready; read"
        fi
    elif (( $+commands[flock] )); then
        if [[ -n $timeout ]]; then
            coproc flock -w $timeout $MUTEX sh -c "echo ready; read"
        else
            coproc flock $MUTEX sh -c "echo ready; read"
        fi
    else
        log_fatal "Neither lockf nor flock found"
    fi
    holder_pid=$!

    # Block until lock is acquired (or timeout)
    if ! read -p; then
        wait $holder_pid
        return 1
    fi

    # Record holder PID for debugging
    echo $$ > $MUTEX

    # Set up signal handlers
    set -o POSIX_TRAPS
    trap "echo ''; exit 130" INT TERM
    trap "log_info_v 'PID $$ releasing mutex $MUTEX'; kill $holder_pid 2>/dev/null; wait $holder_pid 2>/dev/null" EXIT

    log_info_v "PID $$ acquired mutex $MUTEX"
    return 0
}

# Acquire mutex, blocking until available (or timeout if specified)
# Calls log_fatal on failure
# Usage: mutex <name> [timeout_seconds]
function mutex {
    (( $# >= 1 && $# <= 2 )) || log_fatal "Usage: mutex <name> [timeout_seconds]"
    local name=$1
    local timeout=${2:-}

    if _mutex_acquire "$name" "$timeout"; then
        return 0
    fi

    if [[ -n $timeout ]]; then
        log_fatal "Timed out acquiring mutex $MUTEX after ${timeout}s"
    else
        log_fatal "Failed to acquire mutex $MUTEX"
    fi
}

# Try to acquire mutex without blocking (timeout=0)
# Returns 0 on success, 1 if lock is held by another process
# Usage: try_mutex <name>
function try_mutex {
    (( $# == 1 )) || log_fatal "Usage: try_mutex <name>"
    _mutex_acquire "$1" 0
}
