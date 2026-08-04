# Zsh Style & Runtime Gotchas

Conventions for zsh scripts built on the-usual. Canonical here — consumer repos import this file from their own agent instructions rather than copying it, so a rule is written (and fixed) exactly once.

## Coding style

**Variable naming**

- `UPPER_CASE` for exported env vars and the argparse variables (`FLAG_*`, `ARG_*`, `MODE_DRY_RUN`, `VERBOSITY`, `OPTIONS_DESCRIPTION`, `ARGS_DESCRIPTION`, `EXIT_CODES_DESCRIPTION`); `lower_case` for everything else (loop vars, temp vars, computed values).
- **Never** name a variable `path` — it shadows zsh's `$path` (tied to `$PATH`).
- Use `local` for variables inside functions — not at script level.

**Quoting**

- No quotes needed inside `[[ ]]` — zsh doesn't word-split or glob there.
- No quotes needed around `$@` — zsh doesn't word-split by default (`SH_WORD_SPLIT` off).

**Conditionals**

- Never use `(( ))` to compare associative-array values when keys may contain special characters (`;`, `/`, `:`) — `(( ))` tries to evaluate the key as arithmetic. Use `[[ ${arr[$key]} == $val ]]` instead.
- Avoid `A && B || C` as an if/else substitute — `C` also runs when `B` fails; use proper `if/then/else`. Exceptions: `A && var=x || var=y` is fine since assignments don't fail, and `C` as a shared fallback for both `A` and `B` failing is acceptable.
- Check dry-run with `[[ -n $MODE_DRY_RUN ]]` (`[[ -z ]]` for the wet path), never `(( MODE_DRY_RUN ))` — arithmetic evaluation reads a hand-set non-numeric value (`MODE_DRY_RUN=true`; the var is exported for exactly that kind of use) as false, so the guards run wet while `log_*` still prefixes every line with `[DRY_RUN]`.

**Dry-run logging**

- When `MODE_DRY_RUN` is set, `log_*` already prefix every line with `[DRY_RUN]` (`log.zsh`) — log the bare command (`log_info "scp $src $host:$dest/"`), never "Would run:"-style wording.

**Exit codes**

- `EXIT_CODES_DESCRIPTION` is an associative array rendered by `_h.zsh`. Assign custom codes (start at 10) before sourcing `_h.zsh`.
- Use `wrong_usage "message"` for argument-validation errors (exits with code 2); `log_fatal "message" <code>` for runtime errors with specific exit codes (defaults to 1 if code omitted).

## Runtime gotchas

- Scripts run non-interactively — `whence` can't see aliases/functions from an interactive `.zshrc`. To check command existence including aliases, use `zsh -ic 'whence "$cmd"'`.
- `local var` without an assignment, re-run for an already-set var in the same function scope (e.g. inside a loop body), neither resets it nor stays silent — zsh keeps the stale value AND echoes `var='stale'` to stdout. Always give loop-body locals an assignment: `local -a arr=()`, `local x=`.
- `(( n++ ))` as a statement evaluates to the *old* value, so incrementing a counter from 0 exits **1**. Under `setopt err_exit` that aborts the run without printing anything — the-usual's own test suite sets it, so `(( failures++ ))` would swallow the first failing assertion and everything after it. Use `(( ++n ))`, which evaluates to the new value and stays truthy while counting up. The same trap applies to any `(( ))` whose value can be zero — `(( x = a - b ))` as a statement exits 1 when the result is 0; write `x=$(( a - b ))` instead (a plain assignment always exits 0).
- `trap ... EXIT` set **inside a function** is function-scoped — it fires when that function returns, and a callee's `trap - EXIT` cannot clear its caller's. Never split trap-set and trap-clear across functions; clean up explicitly on each exit path.
- `exit` (so also `log_fatal`) inside `$(...)` kills only the subshell — the caller silently gets an empty string and carries on as if it succeeded. A function whose stdout is captured must `return` nonzero and let the caller fatal. Same trap in tests: a stub's in-memory counter is lost across `$(...)`, so count into a file.
