#!/bin/sh
set -euf

"${BINPREFIX:-}circleci" --help
"${BINPREFIX:-}circleci" version
