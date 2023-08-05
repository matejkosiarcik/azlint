#!/bin/sh
set -euf

"${BINPREFIX:-}composer" --help
"${BINPREFIX:-}composer" --version
"${BINPREFIX:-}composer" install --help
(cd "${VENDORPREFIX:-}" && "${BINPREFIX:-}composer" normalize --help)
(cd "${VENDORPREFIX:-}" && "${BINPREFIX:-}composer" validate --help)
php --help
php --version
