#!/bin/sh
set -euf

"${BINPREFIX:-}checkmake" --help
"${BINPREFIX:-}checkmake" --version
"${BINPREFIX:-}checkmake" --list-rules
