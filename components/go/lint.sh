#!/bin/sh
set -euf
cd "${WORKDIR}"
PATH="$(dirname "${0}")/bin:${PATH}"

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (printf '\n' | xargs --no-run-if-empty >/dev/null 2>&1); then
    xargs_r='--no-run-if-empty'
elif (printf '\n' | xargs -r >/dev/null 2>&1); then
    xargs_r='-r'
fi

git ls-files -z '*.sh' '*.bash' '*.zsh' '*.ksh' '*.bats' | xargs -0 ${xargs_r} shfmt -l -d
