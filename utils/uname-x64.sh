#!/bin/sh
set -euf

if [ "$#" -gt 1 ]; then
    printf 'Too many arguments (%s): %s\n' "$#" "$@"
    exit 1
fi

current_arch="$(uname-bak -m)"
x64_arch='x86_64'

if [ "$#" -eq 0 ]; then
    uname-bak | sed "s~$current_arch~$x64_arch~g"
elif [ "$#" -eq 1 ]; then
    uname-bak "$1" | sed "s~$current_arch~$x64_arch~g"
fi
