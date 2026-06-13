# Adds repeatable -q/-v verbosity flags that feed $VERBOSITY, on top of the
# log_* family that log.zsh defines.
source ${${(%):-%x}:A:h:h}/log.zsh

OPTIONS_DESCRIPTION+=("-v, --verbose" "Increase verbosity")
OPTIONS_DESCRIPTION+=("-q, --quiet" "Decrease verbosity")

# Argument parser
zparseopts -D -E -- \
    {v,-verbose}+=FLAG_V \
    {q,-quiet}+=FLAG_Q
(( VERBOSITY = ${VERBOSITY:-0} + ${#FLAG_V} - ${#FLAG_Q} ))
[[ $VERBOSITY < 0 ]] && VERBOSITY=0
export VERBOSITY
