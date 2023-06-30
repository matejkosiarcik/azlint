#!/bin/sh
set -euf
cd "$(git rev-parse --show-toplevel)"

tmpfile="$(mktemp)"
version="$(cat VERSION.txt)"
date="$(date +'%Y-%m-%d')"

# package.json
# jq ".version=\"$version\" | ." package.json >"$tmpfile"
# mv "$tmpfile" package.json

# CHANGELOG
sed "s~## \\\\\\[Unreleased\\\\\\]~## \\\\[Unreleased\\\\]\n\n## \\\\[$version\\\\] - $date~g" <CHANGELOG.md >"$tmpfile"
mv "$tmpfile" CHANGELOG.md

rm -f "$tmpfile"
