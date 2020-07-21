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

grep -iEe '\.(md|markdown|mdown|mdwn|mdx|mkd|mkdn|mkdown|ronn|workbook)$' -e '(^|/)contents\.lr$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} mdl
grep -iE '\.travis\.yml$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 -n1 ${xargs_r} travis lint
