#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies python

# Python cache
find python -type d \( \
    -iname 'googletest' -or \
    -iname 'gtest' -or \
    -iname '__pycache__' \
    \) -prune -exec rm -rf {} \;

# Compiled python files
find python -type f -iname '*.py[cio]' -delete

# -iname '*.json' \

# Misc
find python -type f \( \
    -iname '*.cfg' -or \
    -iname '*.impl' -or \
    -iname '*.in' -or \
    -iname '*.pem' -or \
    -iname '*.pump' -or \
    -iname '*.tar.gz' -or \
    -iname '*.tmpl' -or \
    -iname '*.typed' \
    \) -delete

# Test files
find python -type f \( \
    -iname '*.test' -and \
    -not -iname 'py.test' \
    \) -delete

# Potentially hazardous group
rm -rf python/cloudsplaining/output
find python -type f -iname '*.json.gz' -delete

### Minification ###

minifyJsonFiles python

### Rest ###

removeEmptyDirectories python
