#!/bin/sh
set -euf

ruby --help | cat
ruby --version
"${BINPREFIX:-}bundle" --help | cat
"${BINPREFIX:-}bundle" --version
"${BINPREFIX:-}bundle" exec mdl --help
"${BINPREFIX:-}bundle" exec mdl --version
"${BINPREFIX:-}bundle" exec travis --help --no-interactive
"${BINPREFIX:-}bundle" exec travis --version --no-interactive
