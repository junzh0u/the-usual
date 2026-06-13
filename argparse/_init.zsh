# Expand `-abc` to `-a -b -c`.
# Doing this because zparsopts can only handle `-abc` when `-a`, `-b` and `-c`
# are defined in the same zparsopts call.
# Because I'm putting common flags, like `-q`, `-v`, `-n`, `-h` in their own
# files, thus separate zparseopts calls, args like `-qn` won't work unless
# expanded to `-q -n`.
local expanded_args=()
local stop_expand=""
for arg in $argv; do
    [[ $arg == -- ]] && stop_expand=1
    if [[ -z $stop_expand ]] && [[ $arg =~ "^-[a-zA-Z0-9]{2,}$" ]]; then
        for (( i = 1; i < ${#arg}; i++ )); do
            expanded_args+=("-${arg:$i:1}")
        done
    else
        expanded_args+=($arg)
    fi
done
set -- "${(@)expanded_args}"

declare -A OPTIONS_DESCRIPTION
declare -A EXIT_CODES_DESCRIPTION
EXIT_CODES_DESCRIPTION[0]="Success"
