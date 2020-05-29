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

grep -iE '\.(sh|ksh|dash|bash|zsh|bats)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} shellcheck -x
