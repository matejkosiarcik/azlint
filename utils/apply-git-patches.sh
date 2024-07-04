#!/bin/sh
set -euf

if [ "$#" -lt 2 ]; then
    printf 'Not enough arguments\nExpected "script <patches-directory> <repository-directory>"\n' >&2
    exit 1
fi

# This is source patches directory
patches_dir="$1"
export patches_dir

# This is target repository to apply patches into
repo_dir="$2"
export repo_dir

find "$patches_dir" -name '*.patch' -exec sh -c 'patchfile="$PWD/$0" && cd "$repo_dir" && git apply "$patchfile"' {} \;
