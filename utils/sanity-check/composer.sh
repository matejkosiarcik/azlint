#!/bin/sh
set -euf

"${BINPREFIX:-}composer" --help
"${BINPREFIX:-}composer" --version
"${BINPREFIX:-}composer" install --help
(cd "${BINPREFIX:-}linters" && "${BINPREFIX:-}composer" normalize --help)
(cd "${BINPREFIX:-}linters" && "${BINPREFIX:-}composer" validate --help)
php --help
php --version
