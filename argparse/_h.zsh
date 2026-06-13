source ${${(%):-%x}:A:h:h}/utils.zsh

OPTIONS_DESCRIPTION+=("-h, --help" "Print this help message")
EXIT_CODES_DESCRIPTION[2]="Wrong usage"

function usage {
    print "Usage: $(current_script_name) [options] ${ARGS_DESCRIPTION}"
    print "Options:"
    for key val in ${(kv)OPTIONS_DESCRIPTION}; do
        printf "    %-30s %s\n" "$key" "$val"
    done | sort
    if [[ -n "$EXIT_CODES_DESCRIPTION" ]]; then
        print "Exit codes:"
        for key val in ${(kv)EXIT_CODES_DESCRIPTION}; do
            printf "    %-30s %s\n" "$key" "$val"
        done | sort -n
    fi
}

function wrong_usage {
    [[ -n "$1" ]] && print -P "%F{red}$1%f" >&2
    usage >&2
    exit 2
}

zparseopts -D -E -F -- \
    {h,-help}+=FLAG_HELP ||
wrong_usage

[[ -n "$FLAG_HELP" ]] && usage && exit 0
