#!/bin/sh
set -euf

cd "$(dirname "$0")"
cd "$(git rev-parse --show-toplevel)"

# pull images from Dockerfile ahead of time
grep '^FROM' <Dockerfile |
    grep ':' |
    perl -pe 's~FROM (\-\-platform=[\w:\$-]+ )?(.+?)( AS [\w-]+)?$~\2~' |
    sort |
    uniq |
    while read -r image; do
        docker pull "$image" --platform linux/amd64
        docker pull "$image" --platform linux/arm64
    done
