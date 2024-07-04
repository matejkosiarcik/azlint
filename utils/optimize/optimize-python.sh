#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies python-packages

# Python cache
find python-packages -type d \( \
    -iname 'googletest' -or \
    -iname 'gtest' -or \
    -iname '__pycache__' \
    \) -prune -exec rm -rf {} \;

# Compiled python files
find python-packages -type f -iname '*.py[co]' -delete

# Misc
find python-packages -type f \( \
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
find python-packages -type f \( \
    -iname '*.test' -and \
    -not -iname 'py.test' \
    \) -delete

# Potentially hazardous group
rm -rf python-packages/cloudsplaining/output
find python-packages -type f -iname '*.json.gz' -delete

### Rest ###

removeEmptyDirectories python-packages

### Minify files ###

minifyJsonFiles python-packages
minifyYamlFiles python-packages
