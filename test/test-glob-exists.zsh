#!/usr/bin/env zsh
#
# Automated glob_exists test — verifies glob matching against a temp directory.
#
# Tests:
#   1. Matches existing files by extension
#   2. Returns false for non-matching globs
#   3. Handles empty directories
#   4. Matches dotfiles
#   5. Matches nested paths with **

setopt err_exit

the_usual=${${(%):-%x}:A:h:h}  # the-usual repo root

export VERBOSITY=${VERBOSITY:-1}
source $the_usual/log.zsh
source $the_usual/utils.zsh

tmpdir=$(mktemp -d -t test_glob_exists.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT

failures=0

assert_exists() {
    local description=$1 pattern=$2
    if glob_exists "$pattern"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (expected match for: $pattern)"
        (( failures++ ))
    fi
}

assert_not_exists() {
    local description=$1 pattern=$2
    if ! glob_exists "$pattern"; then
        log_info "PASS: $description"
    else
        log_error "FAIL: $description (unexpected match for: $pattern)"
        (( failures++ ))
    fi
}

# Set up test files
mkdir -p "$tmpdir/sub/deep"
touch "$tmpdir/foo.txt" "$tmpdir/bar.txt" "$tmpdir/baz.jpg"
touch "$tmpdir/.hidden"
touch "$tmpdir/sub/nested.txt"
touch "$tmpdir/sub/deep/deep.txt"

# ── Test 1: Matches existing files ──────────────────────────────────

log_info "── Test 1: Basic glob matching ──"

assert_exists "*.txt matches txt files" "$tmpdir/*.txt"
assert_exists "*.jpg matches jpg files" "$tmpdir/*.jpg"
assert_exists "foo.txt matches exactly" "$tmpdir/foo.txt"

# ── Test 2: Non-matching globs ──────────────────────────────────────

log_info "── Test 2: Non-matching globs ──"

assert_not_exists "*.py has no match" "$tmpdir/*.py"
assert_not_exists "*.mp4 has no match" "$tmpdir/*.mp4"
assert_not_exists "nonexistent file" "$tmpdir/nonexistent.txt"

# ── Test 3: Empty directory ─────────────────────────────────────────

log_info "── Test 3: Empty directory ──"

emptydir="$tmpdir/empty"
mkdir "$emptydir"
assert_not_exists "empty dir has no *.txt" "$emptydir/*.txt"
assert_not_exists "empty dir has no *" "$emptydir/*"

# ── Test 4: Dotfiles ────────────────────────────────────────────────

log_info "── Test 4: Dotfiles ──"

assert_exists ".hidden matches with dot glob" "$tmpdir/.hidden"
assert_exists ".* matches dotfiles" "$tmpdir/.*"

# ── Test 5: Nested paths ───────────────────────────────────────────

log_info "── Test 5: Nested paths ──"

assert_exists "sub/*.txt matches nested" "$tmpdir/sub/*.txt"
assert_exists "**/*.txt matches deep" "$tmpdir/**/*.txt"
assert_not_exists "*.txt doesn't match nested" "$tmpdir/*.csv"

# ── Summary ─────────────────────────────────────────────────────────

if (( failures > 0 )); then
    log_error "$failures assertion(s) failed"
    exit 1
fi

log_success "All assertions passed"
