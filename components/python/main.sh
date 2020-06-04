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

grep -iE '\.(yml|yaml)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} yamllint --strict
grep -iE '\.(sh|ksh|bash|zsh)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} bashate --ignore E001,E002,E003,E004,E005,E006 # ignore all whitespace/basic errors
grep -iE '(^|/)requirements(-.+)?\.txt$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} -n1 requirements-validator
grep -iE '(^|/)\.travis\.yml$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} -n1 travislint
