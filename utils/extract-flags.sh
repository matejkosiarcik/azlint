#!/bin/sh
set -euf
cd "$(dirname "${0}")"

grep -Eo -- '-z "\${.+?}"' <'main.sh' | \
    sed -E 's~[^A-Z_]~~g;s~^~- `~;s~$~`~' | \
    sort
