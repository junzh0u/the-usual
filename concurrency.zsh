source ${${(%):-%x}:A:h}/log.zsh  # log_warning_vvv

if (( $+commands[nproc] )); then
    MAX_CONCURRENCY=$(( $(nproc --all) * 2 ))
else
    MAX_CONCURRENCY=$(( $(sysctl -n hw.ncpu) * 2 ))
fi

function wait_if_too_many_jobs {
    local interval=0.1
    while (( ${#jobstates} >= $MAX_CONCURRENCY )); do
        log_warning_vvv "Reached max concurrency $MAX_CONCURRENCY, wait for $interval sec"
        sleep $interval
    done
}
