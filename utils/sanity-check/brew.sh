#!/bin/sh
set -euf

"${BINPREFIX:-}brew" --help
"${BINPREFIX:-}brew" --version
"${BINPREFIX:-}brew" bundle --help
"${BINPREFIX:-}brew" bundle list --help

tmpdir="$(mktemp -d)"
dryRun() {
    printf '%s\n' "$1" >"$tmpdir/Brewfile"
    (cd "$tmpdir" && "${BINPREFIX:-}brew" bundle list --no-lock)
}

dryRun 'brew "example"'
dryRun 'cask "example"'
dryRun "$(printf 'tap "homebrew/cask"\ncask "example"')"
dryRun 'brew "example" if OS.mac?'
dryRun 'brew "example" if OS.linux?'
dryRun 'mas "example", id: 1'
dryRun 'whalebrew "example"'
dryRun 'vscode "example"'
