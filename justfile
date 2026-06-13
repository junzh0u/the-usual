# the-usual — zsh scripting toolkit

# List available recipes
default:
    @just --list

# Run the automated test suite (test/test-*.zsh)
test:
    #!/usr/bin/env zsh
    typeset -i failures=0
    for t in {{justfile_directory()}}/test/test-*.zsh; do
        print -P "%F{blue}━━ ${t:t} ━━%f"
        if zsh "$t"; then
            print -P "%F{green}✓ ${t:t}%f"
        else
            print -P "%F{red}✗ ${t:t}%f"
            (( ++failures ))
        fi
    done
    if (( failures )); then
        print -P "%F{red}$failures test file(s) failed%f"
        exit 1
    fi
    print -P "%F{green}All tests passed%f"

# Non-destructive check — same as `test` (no build/lint step for pure zsh)
alias check := test
