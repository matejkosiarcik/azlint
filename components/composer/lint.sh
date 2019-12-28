#!/bin/sh
set -euf
cd "${WORKDIR}"

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (printf '\n' | xargs --no-run-if-empty >/dev/null 2>&1); then
    xargs_r='--no-run-if-empty'
elif (printf '\n' | xargs -r >/dev/null 2>&1); then
    xargs_r='-r'
fi

git ls-files -z '*.json' 'composer.lock' '*/composer.lock' | xargs -0 ${xargs_r} jsonlint --quiet
git ls-files -z 'composer.json' '*/composer.json' | xargs -0 ${xargs_r} composer validate --no-check-publish
