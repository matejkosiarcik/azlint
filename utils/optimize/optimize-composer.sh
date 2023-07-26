#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies vendor

# # Documentation
# find vendor -type f \( \
#     -iname 'LICENSE' -or \
#     -iname 'LICENSE.*' -or \
#     \) -delete

# # Misc
# find vendor -type f \( \
#     -iname '*.lock' -or \
#     -iname '*.xml' \
#     \) -delete

### Minification ###

minifyJsonFiles vendor

### Rest ###

removeEmptyDirectories vendor
