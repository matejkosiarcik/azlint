#!/bin/sh
set -euf

### Remove files ###

# Documentation
find vendor -type f \( \
    -iname 'CHANGELOG' -or \
    -iname 'CHANGELOG.*' -or \
    -iname 'LICENSE' -or \
    -iname 'LICENSE.*' -or \
    -iname 'README' -or \
    -iname 'README.*' -or \
    -iname '*.markdown' -or \
    -iname '*.md' -or \
    -iname '*.mdown' -or \
    -iname '*.rst' -or \
    -iname '*.tex' -or \
    -iname '*.txt' \
    \) -delete

# Misc
find vendor -type f \( \
    -iname '*.lock' -or \
    -iname '*.xml' -or \
    -iname '*.yaml' -or \
    -iname '*.yml' \
    \) -delete
