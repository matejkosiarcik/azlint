#!/bin/sh
set -euf

exit 0

### Remove files ###

# Documentation
find vendor -type f \( \
    -iname 'CHANGELOG' -or \
    -iname 'CHANGELOG.*' -or \
    -iname 'LICENSE' -or \
    -iname 'LICENSE.*' -or \
    -iname 'README' -or \
    -iname 'README.*' -or \
    -iname '*.latex' -or \
    -iname '*.markdown' -or \
    -iname '*.md' -or \
    -iname '*.mdown' -or \
    -iname '*.rst' -or \
    -iname '*.tex' -or \
    -iname '*.text' -or \
    -iname '*.txt' \
    \) -delete

# HTML
find vendor -type f \( \
    -iname '*.css' -or \
    -iname '*.htm' -or \
    -iname '*.html' -or \
    -iname '*.less' -or \
    -iname '*.sass' -or \
    -iname '*.scss' -or \
    -iname '*.xhtml' \
    \) -delete

# Misc
find vendor -type f \( \
    -iname '*.lock' -or \
    -iname '*.xml' -or \
    -iname '*.yaml' -or \
    -iname '*.yml' \
    \) -delete

# Remove leftover empty directories
find vendor -type d -empty -prune -exec rm -rf {} \;
