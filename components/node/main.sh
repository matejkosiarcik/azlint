#!/bin/sh
set -euf
export PATH="${PWD}/node_modules/.bin:${PATH}"
cd '/project'

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (xargs --no-run-if-empty <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='--no-run-if-empty'
elif (xargs -r <'/dev/null' >'/dev/null' 2>&1); then
    xargs_r='-r'
fi
tmpfile="$(mktemp)"

# disable indent size for editorconfig-lint, because sometimes it is beneficial to disregard perfect indent size
# such as with properties in HTML elements or arguments in C functions, example:
# <a prop1="foo"
#    prop2="bar">
#    ^ this is aligned with previous property, so it ends up 3 spaces from original indent level, which is unbalanced
tr '\n' '\0' <'/projectlist/projectlist.txt' | xargs -0 ${xargs_r} eclint check --indent_size 1

grep -iEe '\.(md|markdown|mdown|mdwn|mdx|mkd|mkdn|mkdown|ronn|workbook)$' -e '(^|/)contents\.lr$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} markdownlint
grep -iEe '\.(json|geojson|htmlhintrc|htmllintrc|babelrc|jsonl|jscsrc|jshintrc|jslintrc)$' -e '(^|/)composer\.lock$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} jsonlint --quiet --comments
grep -iE '\.bats$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 -I% ${xargs_r} bats --count % >/dev/null
grep -iE '\.gitlab-ci\.yml$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 -n1 ${xargs_r} gitlab-ci-lint
grep -iE '\.gitlab-ci\.yml$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 -n1 ${xargs_r} gitlab-ci-validate validate

if grep -E '^/.svglintrc.js$' <'/projectlist/projectlist.txt'; then
    grep -iE '\.svg$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} svglint --ci
fi

grep -iE '(^|/|\.)Dockerfile$' <'/projectlist/projectlist.txt' | while read -r file; do
    if ! dockerfilelint "${file}" >"${tmpfile}"; then
        cat "${tmpfile}"
        exit 1
    fi
done

grep -iE '(^|/)package\.json$' <'/projectlist/projectlist.txt' | while read -r file; do
    # only run pjv on non-private packages
    if [ "$(jq .private <"${file}")" != 'true' ]; then
        pjv --quiet --filename "${file}"
    fi
done

rm -f "${tmpfile}"
