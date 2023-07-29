#!/bin/sh
set -euf

"${BINPREFIX:-}shellcheck" --help
"${BINPREFIX:-}shellcheck" --version
