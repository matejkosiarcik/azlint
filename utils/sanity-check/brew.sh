#!/bin/sh
set -euf

"${BINPREFIX:-}brew" --help
"${BINPREFIX:-}brew" --version
"${BINPREFIX:-}brew" bundle --help
