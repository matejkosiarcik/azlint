#!/bin/sh
set -euf

"${BINPREFIX:-}dotenv-linter" --help
"${BINPREFIX:-}dotenv-linter" --version
"${BINPREFIX:-}hush" --help
"${BINPREFIX:-}hush" --version
printf 'true\n' | "${BINPREFIX:-}hush"
"${BINPREFIX:-}shellharden" --help
"${BINPREFIX:-}shellharden" --version
