#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies python

# Python cache
find python -type d -iname '__pycache__' -prune -exec rm -rf {} \;

# find python -type d -iname '*.dist-info' -prune -exec rm -rf {} \;

# Compiled python files
find python -type f -iname '*.py[cio]' -delete

# # Documentation
# find python -type f \( \
#     -iname 'APACHE' -or \
#     -iname 'CHANGELOG' -or \
#     -iname 'CHANGELOG.*' -or \
#     -iname 'BSD' -or \
#     -iname 'LICENSE' -or \
#     -iname 'LICENSE.*' -or \
#     -iname 'README' -or \
#     -iname 'README.*' -or \
#     -iname '*.latex' -or \
#     -iname '*.markdown' -or \
#     -iname '*.markdown-it' -or \
#     -iname '*.md' -or \
#     -iname '*.mdown' -or \
#     -iname '*.rst' -or \
#     -iname '*.tex' -or \
#     -iname '*.text' -or \
#     -iname '*.txt' \
#     \) -delete

# # Misc
# find python -type f \( \
#     -iname 'VERSIONS' -or \
#     -iname '*.1' -or \
#     -iname '*.cfg' -or \
#     -iname '*.in' -or \
#     -iname '*.impl' -or \
#     -iname '*.json' -or \
#     -iname '*.pem' -or \
#     -iname '*.pump' -or \
#     -iname '*.sh' -or \
#     -iname '*.tmpl' -or \
#     -iname '*.typed' -or \
#     -iname '*.xsd' -or \
#     -iname '*.xslt' \
#     \) -delete

# # Test files (except pytest)
# find python -type f \( \
#     -iname '*.test' -and \
#     -not -iname 'py.test' \
#     \) -delete

### Minification ###

minifyJsonFiles python

### Rest ###

removeEmptyDirectories python
