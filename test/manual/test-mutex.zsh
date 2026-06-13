#!/usr/bin/env zsh

the_usual=${${(%):-%x}:A:h:h:h}  # the-usual repo root

# === Argparse begins ===
source $the_usual/argparse/_init.zsh
source $the_usual/argparse/n.zsh
export VERBOSITY=${VERBOSITY:-1}
source $the_usual/argparse/qv.zsh

ARG_SLEEP=(10)
OPTIONS_DESCRIPTION+=("-s, --sleep N" "Sleep for N seconds")
zparseopts -D -E -K \
    {s,-sleep}:=ARG_SLEEP

ARGS_DESCRIPTION=""
source $the_usual/argparse/_h.zsh
(( $# == 0 )) || wrong_usage "Expecting no argument"
# === Argparse ends ===

source $the_usual/mutex.zsh

mutex test_mutex $ARG_SLEEP[-1]
log_info "PID $$ sleeping for $ARG_SLEEP[-1] seconds"
sleep $ARG_SLEEP[-1]
log_info "PID $$ reached end of script"
