#!/bin/sh
set -euf

if [ "$#" -lt 1 ]; then
    dir='.'
else
    dir="$1"
fi

cd "$dir"
git tag |
    grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' |
    sed -E 's~^v~~' |
    sort --version-sort |
    tail -n 1
