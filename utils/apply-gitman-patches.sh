#!/bin/sh
set -euf

cd "$(git rev-parse --show-toplevel)/linters"

find ./git-patches/loksh -name '*.patch' -exec cp {} gitman-repos/shell-loksh/gitman/loksh/ \;
cd gitman-repos/shell-loksh/gitman/loksh
find . -name '*.patch' -exec git apply {} \;
find . -name '*.patch' -delete
