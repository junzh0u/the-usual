function current_script_name {
    print ${${ZSH_ARGZERO:t}%.zsh}
}

function glob_exists {
    local files=(${~1}(DNY1))
    [[ ${#files} -gt 0 ]]
}
