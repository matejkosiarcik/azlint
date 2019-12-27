#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z '*.json' 'composer.lock' '.htmlhintrc' '.babelrc' | xargs -0 jsonlint
