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

# ksh
git ls-files -z '*.sh' '*.ksh' | xargs -0 -n1 ${xargs_r} ksh -n
git ls-files -z '*.sh' '*.ksh' | xargs -0 -n1 ${xargs_r} mksh -n
if command -v loksh >/dev/null 2>&1; then
    git ls-files -z '*.sh' '*.ksh' | xargs -0 -n1 ${xargs_r} loksh -n
fi

# bash/zsh/yash
git ls-files -z '*.sh' '*.ksh' '*.bash' | xargs -0 -n1 ${xargs_r} bash -n
git ls-files -z '*.sh' '*.ksh' '*.zsh' | xargs -0 -n1 ${xargs_r} zsh -n

# posix sh
git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} sh -n
git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} dash -n
git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} bash --posix -n
git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} bash -o posix -n
if command -v yash >/dev/null 2>&1; then
    git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} yash -n
    git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} yash --posix -n
    git ls-files -z '*.sh' | xargs -0 -n1 ${xargs_r} yash -o posixly-correct -n
fi

# TODO: enable always, after installing LinuxBrew everywhere
if command -v brew >/dev/null 2>&1; then
    git ls-files -z '*Brewfile' | xargs -0 -n1 -I% ${xargs_r} brew bundle list --all --file=% >/dev/null
fi
