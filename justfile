# the-usual — zsh scripting toolkit

# Run recipes with zsh as a normal command (not a shebang script) so they work
# even where the system temp dir is mounted noexec — e.g. Synology mounts /tmp
# noexec, which breaks just's default shebang-recipe execution.
set shell := ['zsh', '-c']

# List available recipes
default:
    @just --list

# Run the automated test suite (test/test-*.zsh)
test:
    @typeset -i failures=0; \
    for t in {{ justfile_directory() }}/test/test-*.zsh; do \
        print -P "%F{blue}━━ ${t:t} ━━%f"; \
        if zsh "$t"; then \
            print -P "%F{green}✓ ${t:t}%f"; \
        else \
            print -P "%F{red}✗ ${t:t}%f"; \
            (( ++failures )); \
        fi; \
    done; \
    if (( failures )); then \
        print -P "%F{red}$failures test file(s) failed%f"; \
        exit 1; \
    fi; \
    print -P "%F{green}All tests passed%f"

# Non-destructive check — same as `test` (no build/lint step for pure zsh)
alias check := test
