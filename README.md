# the-usual

The zsh I source at the top of every script — flags, logging, dry-run,
parallelism, and locking — so the script itself can be five lines of real
work. It's the boilerplate I always reach for, factored out of my dotfiles.

## What's in it

- **`argparse/`** — a composable argument parser. Source one small file per
  capability, in order, and a script gets `-h`/`--help` (auto-generated from
  whichever modules it sourced), `-n`/`--dry-run`, repeatable `-q`/`-v`
  verbosity, and `-y`/`--yes`:

  ```zsh
  source $ZDOTDIR/the-usual/argparse/_init.zsh  # expands -abc to -a -b -c
  source $ZDOTDIR/the-usual/argparse/n.zsh      # -n  (dry run)
  source $ZDOTDIR/the-usual/argparse/qv.zsh     # -q/-v + the log_* family
  source $ZDOTDIR/the-usual/argparse/_h.zsh     # -h  (help) — must be last
  ```

  (`utils.zsh` is its one shared dependency; `qv.zsh` also provides the
  severity-colored, script-name-prefixed, stderr-bound `log_*` functions.)
- **`concurrency.zsh`** — `wait_if_too_many_jobs`, a bounded job pool that
  caps background jobs at twice the CPU count.
- **`mutex.zsh`** — `mutex` / `try_mutex`, a lock held by a coprocess so it
  releases on exit even on Ctrl-C, leaving no orphaned lock.
- **`coreutils.zsh`** — portable wrappers over GNU-vs-BSD coreutils
  differences (`file_size`, etc.).
- **`debug.zsh`** — `inspect`, a one-call dump of a variable, array, or
  associative array.

## Status

First cut: a straight lift out of my dotfiles. The files still source one
another by `$ZDOTDIR/the-usual/...`, so for now they assume a checkout at that
path (it's a submodule of my dotfiles), and the concurrency/mutex helpers
assume `argparse/qv.zsh` is sourced for their `log_*` calls. Making the pieces
path-independent and standalone is the next step.

## License

[MIT](LICENSE)
