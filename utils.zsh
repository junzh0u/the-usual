function current_script_name {
    print ${${ZSH_ARGZERO:t}%.zsh}
}

function glob_exists {
    local files=(${~1}(DNY1))
    [[ ${#files} -gt 0 ]]
}

# Fail fatally (log_fatal, exit 1) if any named env var is unset or empty.
# Requires log.zsh loaded (consumer scripts get it via argparse/qv.zsh).
# Usage: require_env VAR1 VAR2 ...
function require_env {
    local var
    local -a missing=()
    for var in $@; do
        [[ -n ${(P)var} ]] || missing+=$var
    done
    (( $#missing )) && log_fatal "Required env not set: ${(j:, :)missing}"
    return 0
}
