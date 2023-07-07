#!/bin/sh
set -euf

cd "$(git rev-parse --show-toplevel)/linters"
find ./git-patches/loksh -name '*.patch' -exec cp {} gitman/loksh/ \;
cd gitman/loksh
find . -name '*.patch' -exec git apply {} \;
