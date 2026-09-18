# Adds repeatable -q/-v verbosity flags that feed $VERBOSITY, on top of the
# log_* family that log.zsh defines.
source ${${(%):-%x}:A:h:h}/log.zsh

OPTIONS_DESCRIPTION+=("-v, --verbose" "Increase verbosity")
OPTIONS_DESCRIPTION+=("-q, --quiet" "Decrease verbosity")

# Argument parser
zparseopts -D -E -- \
    {v,-verbose}+=FLAG_V \
    {q,-quiet}+=FLAG_Q
# Plain assignment, not a `(( VERBOSITY = ... ))` statement — that form's
# exit status is the computed value, so verbosity 0 would kill an err_exit
# caller mid-source (same trap as `(( n++ ))`, see STYLE.md)
VERBOSITY=$(( ${VERBOSITY:-0} + ${#FLAG_V} - ${#FLAG_Q} ))
(( VERBOSITY < 0 )) && VERBOSITY=0
export VERBOSITY
# A verbose run announces its own level, so the transcript says why the
# extra lines are there. An if, not log_info_v's own gate or an && list:
# either would leave 1 as this file's (so source's) status at verbosity 0
# and kill an err_exit caller
if (( VERBOSITY )); then
    log_info_v "Verbosity: $VERBOSITY"
fi
