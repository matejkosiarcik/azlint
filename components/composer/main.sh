#!/bin/sh
set -euf
cd '/project'

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (xargs --no-run-if-empty <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='--no-run-if-empty'
elif (xargs -r <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='-r'
fi

grep -iE '(^|/)composer\.json$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -n1 -I% -0 ${xargs_r} sh -c 'composer validate --quiet --no-interaction --no-cache --ansi --no-check-all --no-check-publish % || composer validate --no-interaction --no-cache --ansi --no-check-all --no-check-publish %'
# shellcheck disable=SC2016
grep -iE '(^|/)composer\.json$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -n1 -I% -0 ${xargs_r} sh -c 'filepath="${PWD}/%" && cd /src && composer normalize --no-interaction --no-cache --ansi --dry-run --diff "${filepath}"'
