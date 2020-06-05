#!/bin/sh
set -euf

if [ -n "${WORKDIR+x}" ]; then
    cd "${WORKDIR}"
fi

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (xargs --no-run-if-empty <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='--no-run-if-empty'
elif (xargs -r <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='-r'
fi

grep -iEe '\.json$' -e '(^|/)composer\.lock$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} jsonlint --quiet
grep -iE '(^|/)composer\.json$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -n1 -I% -0 ${xargs_r} sh -c 'composer validate --quiet --no-interaction --no-cache --ansi --no-check-all --no-check-publish % || composer validate --no-interaction --no-cache --ansi --no-check-all --no-check-publish %'
grep -iE '(^|/)composer\.json$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -n1 -I% -0 ${xargs_r} sh -c 'cd "$(dirname %)" && composer normalize --no-interaction  --no-cache --ansi --dry-run --diff "$(basename %)"'
