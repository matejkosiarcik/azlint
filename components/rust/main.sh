#!/bin/sh
set -euf
cd '/project'

# Default in GNU xargs is to execute always
# But not all xargs have this flag
# xargs_r=''
# if (xargs --no-run-if-empty <'/dev/null' >'/dev/null' 2>&1); then
#     xargs_r='--no-run-if-empty'
# elif (xargs -r <'/dev/null' >'/dev/null' 2>&1); then
#     xargs_r='-r'
# fi
tmpfile="$(mktemp)"

# grep -iE '\.toml$' <'/projectlist/projectlist.txt' | while read -r file; do
#     if ! toml get "${file}" . >/dev/null 2>"${tmpfile}"; then
#         printf '%s\n' "${file}"
#         cat "${tmpfile}"
#         exit 1
#     fi
# done

rm -f "${tmpfile}"
