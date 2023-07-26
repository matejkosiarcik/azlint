#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies python

# Python cache
find python -type d \( \
    -iname '__pycache__' -or \
    -iname 'googletest' -or \
    -iname 'gtest' \
    \) -prune -exec rm -rf {} \;

# find python -type d -iname '*.dist-info' -prune -exec rm -rf {} \;

# Compiled python files
find python -type f -iname '*.py[cio]' -delete

# -iname '*.pem' -or \

# -iname '*.cfg' -or \
# -iname '*.in' -or \
# -iname '*.json' \

# Misc
find python -type f \( \
    -iname '*.impl' -or \
    -iname '*.pump' -or \
    -iname '*.tmpl' \
    \) -delete

    # -iname '*.typed' -or \
    # -iname '*.xsd' -or \
    # -iname '*.xslt' \

# -iname 'VERSIONS' -or \

# Test files
# find python -type f \( \
#     -iname '*.test' -and \
#     -not -iname 'py.test' \
#     \) -delete

### Minification ###

minifyJsonFiles python

### Rest ###

removeEmptyDirectories python
