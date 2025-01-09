#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies python-vendor

# Python cache
find python-vendor -type d \( \
    -iname 'googletest' -or \
    -iname 'gtest' -or \
    -iname '__pycache__' \
    \) -prune -exec rm -rf {} \;

# Compiled python files
find python-vendor -type f -iname '*.py[co]' -delete

# Misc
find python-vendor -type f \( \
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
find python-vendor -type f \( \
    -iname '*.test' -and \
    -not -iname 'py.test' \
    \) -delete

# Potentially hazardous group
rm -rf python-vendor/cloudsplaining/output
find python-vendor -type f -iname '*.json.gz' -delete

### Rest ###

removeEmptyDirectories python-vendor

### Minify files ###

minifyJsonFiles python-vendor
minifyYamlFiles python-vendor
