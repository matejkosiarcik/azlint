#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z '*.json' 'composer.lock' '*/composer.lock' '*.htmlhintrc' '*.babelrc' | xargs -0 jsonlint
git ls-files -z 'composer.json' '*/composer.json' | xargs -0 composer validate
