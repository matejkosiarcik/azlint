#!/bin/sh
set -euf
# This file is used on non-x64 systems, to make HomeBrew think it is running on x64 system

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
