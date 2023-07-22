#!/bin/sh
set -euf

### Remove directories ###

find python -type d \( \
    -iname 'doc' -or \
    -iname 'docs' -or \
    -iname 'man' -or \
    -iname 'test' -or \
    -iname 'tests' -or \
    -iname 'testutils' -or \
    -iname 'test-data' -or \
    -iname '__pycache__' \
    \) -prune -exec rm -rf {} \;

find python -type d -iname '*.dist-info' -prune -exec rm -rf {} \;

### Remove files ###

# System files
find python -type f \( \
    -iname '*~' -or \
    -iname '.DS_Store' \
    \) -delete

# Compiled python
find python -type f -iname '*.py[cio]' -delete

# Documentation
find python -type f \( \
    -iname 'APACHE' -or \
    -iname 'CHANGELOG' -or \
    -iname 'CHANGELOG.*' -or \
    -iname 'BSD' -or \
    -iname 'LICENSE' -or \
    -iname 'LICENSE.*' -or \
    -iname 'README' -or \
    -iname 'README.*' -or \
    -iname '*.markdown' -or \
    -iname '*.markdown-it' -or \
    -iname '*.md' -or \
    -iname '*.mdown' -or \
    -iname '*.rst' -or \
    -iname '*.tex' -or \
    -iname '*.txt' \
    \) -delete

# HTML
find python -type f \( \
    -iname '*.css' -or \
    -iname '*.htm' -or \
    -iname '*.html' -or \
    -iname '*.xhtml' \
    \) -delete

# Compiled resources
find python -type f \( \
    -iname '*.c' -or \
    -iname '*.cc' -or \
    -iname '*.cpp' -or \
    -iname '*.cxx' -or \
    -iname '*.c++' -or \
    -iname '*.h' -or \
    -iname '*.hh' -or \
    -iname '*.hpp' -or \
    -iname '*.hxx' -or \
    -iname '*.h++' \
    \) -delete

# Misc
find python -type f \( \
    -iname 'Makefile' -or \
    -iname 'VERSIONS' -or \
    -iname '*.1' -or \
    -iname '*.bat' -or \
    -iname '*.cfg' -or \
    -iname '*.in' -or \
    -iname '*.impl' -or \
    -iname '*.json' -or \
    -iname '*.pem' -or \
    -iname '*.pump' -or \
    -iname '*.sh' -or \
    -iname '*.tmpl' -or \
    -iname '*.typed' -or \
    -iname '*.xsd' -or \
    -iname '*.xslt' \
    \) -delete

# YAML (except in yamllint)
find python -type f -not -ipath '*/yamllint/*' \( \
    -iname '*.yaml' -or \
    -iname '*.yml' \
    \) -delete

# Test files (except pytest)
find python -type f \( \
    -iname '*.test' -and \
    -not -iname 'py.test' \
    \) -delete
