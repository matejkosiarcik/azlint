#!/bin/sh
set -euf
venv_path="${PWD}/$(dirname "${0}")"
cd "${WORKDIR}"

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (printf '\n' | xargs --no-run-if-empty >/dev/null 2>&1); then
    xargs_r='--no-run-if-empty'
elif (printf '\n' | xargs -r >/dev/null 2>&1); then
    xargs_r='-r'
fi

set +u && . "${venv_path}/venv/bin/activate" && set -u
git ls-files -z '*.yml' '*.yaml' | xargs -0 ${xargs_r} yamllint --strict
git ls-files -z '*.sh' '*.ksh' '*.bash' '*.zsh' '*.bats' | xargs -0 ${xargs_r} bashate --ignore E006,E003
