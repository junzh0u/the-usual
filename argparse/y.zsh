OPTIONS_DESCRIPTION+=("-y, --yes" "Always answer yes to y/n question")

zparseopts -D -E -- \
    {y,-yes}+=FLAG_YES

[[ -n $FLAG_YES ]] && export YES_OR_NO_ANSWER="y"

function yes_or_no {
    if [[ -n $YES_OR_NO_ANSWER ]]; then
        [[ "$YES_OR_NO_ANSWER" =~ "[Yy].*" ]] && return 0 || return 1
    fi
    print -n $'\a' > /dev/tty  # ring the bell to alert the user
    read -qs "PROMPT?$1 <y/N>" < /dev/tty
    local ret=$?
    print ""
    return $ret
}
