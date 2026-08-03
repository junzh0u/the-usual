# CLAUDE.md — the-usual

## Repository Overview

`the-usual` is a small zsh scripting toolkit — the boilerplate sourced at the
top of every script: composable argument parsing, severity-colored logging,
dry-run, a bounded job pool, and a coprocess-backed mutex, so the script itself
can be a few lines of real work.

Extracted from my dotfiles, where it's vendored as a git submodule at
`.config/zsh/the-usual`; published standalone at
[junzh0u/the-usual](https://github.com/junzh0u/the-usual). This repo is the
canonical source: edit/commit/push here, then bump the submodule pointer in the
dotfiles repo.

## Layout

- `argparse/` — composable argument parser; source one file per capability, in
  order (see below).
- `log.zsh` — the `log_*` family + `mkdir_v`/`mv_v` verbosity wrappers. No
  argument parsing.
- `utils.zsh` — `current_script_name`, `glob_exists`, `require_env`.
- `concurrency.zsh` — `wait_if_too_many_jobs`, a bounded job pool.
- `mutex.zsh` — `mutex` / `try_mutex`, a coprocess-held lock.
- `coreutils.zsh` — fork-free file/time helpers backed by zsh builtins
  (`file_size`, `file_mtime`, `format_epoch`, `parse_date`, `epoch_*_ago`).
- `debug.zsh` — `inspect`, a one-call dump of a var / array / assoc.
- `test/` — automated tests; `test/manual/` fixtures.

## Path independence

Every file resolves its dependencies relative to its own location — never via an
absolute or `$ZDOTDIR`-rooted path — so the checkout can live anywhere:

```zsh
source ${${(%):-%x}:A:h}/log.zsh        # a sibling file
source ${${(%):-%x}:A:h:h}/utils.zsh    # one level up (e.g. from argparse/)
```

`${(%):-%x}` expands to the path of the file currently being sourced (robust
against `POSIX_ARGZERO`, unlike `$0`); `:A` resolves symlinks to an absolute
path; each `:h` strips one trailing path component. **Don't** reassign `$0`
(`0=${(%):-%x}`) at file scope — these files are sourced into the caller's
scope, so it would clobber the caller's `$0`; use the inline form above.

Tests anchor the repo root once into a local var (which also expands inside
`zsh -c "..."` / heredoc strings, where an inline `%x` would resolve to the
wrong file):

```zsh
the_usual=${${(%):-%x}:A:h:h}    # from test/;  :A:h:h:h from test/manual/
source $the_usual/log.zsh
```

## The argparse pattern

Source order matters — each file is its own `zparseopts` call (so combined flags
like `-qn` only work because `_init.zsh` pre-expands them):

```zsh
#!/usr/bin/env zsh
# === Argparse begins ===
source $the_usual/argparse/_init.zsh   # expand -abc → -a -b -c; declare the *_DESCRIPTION arrays
source $the_usual/argparse/n.zsh       # -n / --dry-run  → MODE_DRY_RUN
source $the_usual/argparse/qv.zsh      # -q / -v         → VERBOSITY, plus the log_* family
source $the_usual/argparse/y.zsh       # -y / --yes      → YES_OR_NO_ANSWER, yes_or_no
source $the_usual/argparse/_h.zsh      # -h / --help (auto-generated) — must be last
# === Argparse ends ===
```

`_init.zsh` is required first; `_h.zsh` last (it renders `--help` from whichever
modules were sourced). `n`/`qv`/`y` are independent — source only what you need.
(Dotfiles consumer scripts source these via `$ZDOTDIR/the-usual/argparse/...`;
inside this repo, anchor `$the_usual` as shown under Path independence.)

**Option defaults:** initialize `ARG_*` before `zparseopts`; the `-K` flag
preserves the value when the flag is absent:

```zsh
ARG_HOST=("default-host")
OPTIONS_DESCRIPTION+=("-H, --host HOST" "Host, default ${ARG_HOST[-1]}")
zparseopts -D -E -K {H,-host}:=ARG_HOST
```

## log.zsh vs argparse/qv.zsh

`log.zsh` defines the `log_*` family and reads `$VERBOSITY` (default 0) to gate
the `_v`/`_vv`/`_vvv` variants — no argument parsing, no side effects on the
caller's args. `qv.zsh` sources `log.zsh` and adds the `-q`/`-v` flag parsing
that feeds `$VERBOSITY`.

**If a piece only needs logging — verbosity set via the `$VERBOSITY` env var,
not `-q`/`-v` flags — source `log.zsh` directly, not `qv.zsh`.** `concurrency.zsh`
and `mutex.zsh` do this, and so do the tests here.

## Module gotchas

- **`coreutils.zsh`** — helpers are zsh builtins (`zsh/stat`, `zsh/datetime`),
  no fork per call — except `parse_date` (ISO-8601 input only), which forks
  `date(1)`: glibc's `strftime -r` ignores the parsed `%z` offset.
  `epoch_*_ago` subtract fixed 3600/86400-second units, not calendar days.
- **`concurrency.zsh`** — after each `&`, call `wait_if_too_many_jobs`; finish
  with `wait`. `MAX_CONCURRENCY = 2 × ncpu`.
- **`mutex.zsh`** — `mutex <name>` spawns a coprocess to hold the lock. If the
  script also runs parallel jobs, wrap them in `( ... )` so the script-level
  `wait` doesn't block on the mutex coprocess.

## Testing

```zsh
just test                # run the suite (alias: just check)
zsh test/test-log.zsh    # run one file
```

Tests are assert-based and `exit 1` on failure. `test/manual/` holds fixtures
the automated tests invoke (e.g. `test-log.zsh` drives `manual/test-log.zsh` at
several `$VERBOSITY` levels); some are also runnable by hand. `test-current-script-name`
and `test-log` assert on a script's own `current_script_name`, so keep those
assertions in sync if you rename a test file.

## Zsh style & runtime gotchas

Canonical for this repo *and* its consumers, which import the file from their
own agent instructions instead of copying the rules — imported here:

@STYLE.md
