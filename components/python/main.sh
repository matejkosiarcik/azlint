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

grep -iE '\.(yml|yaml)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} yamllint --strict
grep -iE '\.(sh|ksh|bash|zsh)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} bashate --ignore E001,E002,E003,E004,E005,E006 # ignore all whitespace/basic errors
grep -iE '\.py(2|3)?$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} pylint
grep -iE '\.py(2|3)?$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} pycodestyle
grep -iE '\.py(2|3)?$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} flake8
grep -iE '\.py(2|3)?$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} pyflakes
# grep -iE '(^|/)\.travis\.yml$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} -n1 travislint
