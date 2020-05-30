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

# TODO: enable always, after installing LinuxBrew everywhere
if command -v brew >/dev/null 2>&1; then
    git ls-files -z '*Brewfile' | xargs -0 -n1 -I% ${xargs_r} brew bundle list --all --file=% >/dev/null
fi
