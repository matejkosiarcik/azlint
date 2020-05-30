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

# disable indent size for eclint, because sometimes it is beneficial to disregard perfect indent size
# such as with properties in HTML elements or arguments in C functions, example:
# <a prop1="foo"
#    prop2="bar">
#    ^ this is aligned with previous property, so it ends up 3 spaces from original indent level, which is unbalanced
tr '\n' '\0' <'/projectlist/projectlist.txt' | xargs -0 ${xargs_r} eclint check --indent_size 1

grep -iE '(\.(md|markdown|mdown|mdwn|mdx|mkd|mkdn|mkdown|ronn|workbook))|((^|/)contents.lr)$' <'/projectlist/projectlist.txt' | tr '\n' '\0' | xargs -0 ${xargs_r} markdownlint
# git ls-files -z '*.json' '*.geojson' '*.htmlhintrc' '*.htmllintrc' '*.babelrc' '*.jsonl' '*.jscsrc' '*.jshintrc' '*.jslintrc' 'composer.lock' '*/composer.lock' | xargs -0 ${xargs_r} jsonlint --quiet --comments
# git ls-files -z '*.sh' '*.ksh' '*.bash' '*.zsh' '*.bats' | xargs -0 ${xargs_r} shellcheck -x
# git ls-files -z '*.bats' | xargs -0 -I% ${xargs_r} bats --count % >/dev/null
# # git ls-files -z 'package.json' '*/package.json' | xargs -0 -n1 ${xargs_r} pjv --quiet --filename
# git ls-files -z '*.gitlab-ci.yml' | xargs -0 -n1 ${xargs_r} gitlab-ci-lint
# git ls-files -z '*.gitlab-ci.yml' | xargs -0 -n1 ${xargs_r} gitlab-ci-validate validate
