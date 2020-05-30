#!/bin/sh
set -euf
cd "${WORKDIR}"

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (xargs --no-run-if-empty <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='--no-run-if-empty'
elif (xargs -r <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='-r'
fi

grep -iE '(\.(json))|((^|/)composer\.lock)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} jsonlint --quiet
grep -iE '(^|/)composer\.json$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} composer validate --no-check-publish
