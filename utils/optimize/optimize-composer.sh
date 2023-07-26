#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies vendor

find vendor -type f -iname '*.lock' -delete

### Minification ###

minifyJsonFiles vendor

### Rest ###

removeEmptyDirectories vendor
