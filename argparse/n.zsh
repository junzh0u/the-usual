OPTIONS_DESCRIPTION+=("-n, --dry-run" "Dry run mode")

zparseopts -D -E -- \
    {n,-dry-run}+=FLAG_DRY_RUN

[[ -n "$FLAG_DRY_RUN" ]] && MODE_DRY_RUN=1
export MODE_DRY_RUN
