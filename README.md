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
  source /path/to/the-usual/argparse/_init.zsh  # expands -abc to -a -b -c
  source /path/to/the-usual/argparse/n.zsh      # -n  (dry run)
  source /path/to/the-usual/argparse/qv.zsh     # -q/-v + the log_* family
  source /path/to/the-usual/argparse/_h.zsh     # -h  (help) — must be last
  ```

  (`utils.zsh` and `log.zsh` are the shared dependencies; each module pulls in
  what it needs relative to its own location, so you only source the entry
  files above. `qv.zsh` layers `-q`/`-v` on top of the `log_*` family.)
- **`log.zsh`** — the severity-colored, script-name-prefixed, stderr-bound
  `log_*` family (success/info/warning/error/fatal, each with verbosity-gated
  `_v`/`_vv` variants) plus `mkdir_v`/`mv_v` wrappers. Source it directly for
  logging without the `-q`/`-v` flag parsing.
- **`concurrency.zsh`** — `wait_if_too_many_jobs`, a bounded job pool that
  caps background jobs at twice the CPU count.
- **`mutex.zsh`** — `mutex` / `try_mutex`, a lock held by a coprocess so it
  releases on exit even on Ctrl-C, leaving no orphaned lock.
- **`coreutils.zsh`** — portable wrappers over GNU-vs-BSD coreutils
  differences (`file_size`, etc.).
- **`debug.zsh`** — `inspect`, a one-call dump of a variable, array, or
  associative array.

## Dry-run

`argparse/n.zsh` adds `-n`/`--dry-run` and sets `MODE_DRY_RUN=1` — but it can't
know which lines are destructive, so guard the side effects yourself:

```zsh
if (( MODE_DRY_RUN )); then
    log_info "Would remove $f"
else
    rm "$f"
fi
```

`(( MODE_DRY_RUN ))` is false when the flag is absent (an unset variable is
arithmetic zero) and true once `n.zsh` sets it, so it needs no default; the
short form `(( MODE_DRY_RUN )) && exit 0` bails early. And because the `log_*`
family prefixes `[DRY_RUN]` to every line whenever `MODE_DRY_RUN` is set, a dry
run reads back as a labeled transcript of what a real run would do — no extra
wiring.

## Testing

```zsh
just test                    # run the whole suite
zsh test/test-log.zsh        # or run one file directly
```

Tests live in `test/`; the `test/manual/` scripts are fixtures the automated
tests invoke (and can also be run by hand). Each test locates the library
relative to its own path, so the suite runs from anywhere.

## Status

Lifted out of my dotfiles, where it lives as a submodule. The pieces are now
path-independent: each file resolves its siblings relative to its own location
(via `${${(%):-%x}:A:h}`), so you can drop the checkout anywhere and source any
single file by its path — it pulls in what it needs. The concurrency and mutex
helpers source `log.zsh` themselves, so they no longer assume the argparse
flags were sourced first.

## License

[MIT](LICENSE)
