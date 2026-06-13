#!/usr/bin/env zsh

the_usual=${${(%):-%x}:A:h:h:h}  # the-usual repo root

print "Argument before expanding:"
for arg in $@; do
    echo "\t$arg"
done
source $the_usual/argparse/_init.zsh
print "Argument after expanding:"
for arg in $@; do
    echo "\t$arg"
done

source $the_usual/argparse/n.zsh
source $the_usual/argparse/qv.zsh
source $the_usual/argparse/y.zsh
source $the_usual/argparse/_h.zsh

source $the_usual/debug.zsh
inspect MODE_DRY_RUN
inspect VERBOSITY
inspect YES_OR_NO_ANSWER

print "Remaining arguments:"
for arg in $@; do
    echo "\t$arg"
done
