#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies bundle

# macOS apps
find bundle -type d \( \
    -iname 'cache' -or \
    -iname '*.app' \
    \) -prune -exec rm -rf {} \;

# find bundle -type d \( \
#     -iname 'template' -or \
#     -iname 'templates' -or \
#     \) -prune -exec rm -rf {} \;

# # Documentation
# find bundle -type f \( \
#     -iname 'VERSION' \
#     \) -delete

# Misc
find bundle -type f \( \
    -iname 'Gemfile' -or \
    -iname '*.autotest' -or \
    -iname '*.dat' -or \
    -iname '*.erb' -or \
    -iname '*.gemtest' -or \
    -iname '*.jar' -or \
    -iname '*.java' -or \
    -iname '*.log' -or \
    -iname '*.nib' -or \
    -iname '*.o' -or \
    -iname '*.out' -or \
    -iname '*.provisionprofile' -or \
    -iname '*.rake' -or \
    -iname '*.rspec' -or \
    -iname '*.rl' -or \
    -iname '*.simplecov' -or \
    -iname '*.time' -or \
    -iname '*.tt' -or \
    -iname '*.y' -or \
    -iname '*.yardopts' \
    \) -delete

removeEmptyDirectories bundle

### Minify files ###

minifyJsonFiles bundle
minifyYamlFiles bundle
