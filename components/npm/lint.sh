#!/bin/sh
set -euf
cd "${WORKDIR}"

# Default in GNU xargs is to execute always
# But not all xargs have this flag
xargs_r=''
if (printf '\n' | xargs --no-run-if-empty >/dev/null 2>&1); then
    xargs_r='--no-run-if-empty'
elif (printf '\n' | xargs -r >/dev/null 2>&1); then
    xargs_r='-r'
fi

git ls-files -z | xargs -0 ${xargs_r} eclint check
git ls-files -z '*.md' '*.markdown' '*.mdown' '*.mdwn' '*.mdx' '*.mkd' '*.mkdn' '*.mkdown' '*.ronn' '*.workbook' 'contents.lr' '*/contents.lr' | xargs -0 ${xargs_r} markdownlint
git ls-files -z '*.json' '*.geojson' '*.htmlhintrc' '*.babelrc' '*.jsonl' '*.eslintrc.json' '*.jscsrc' '*.jshintrc' '*.jshintrc' 'composer.lock' '*/composer.lock' | xargs -0 ${xargs_r} jsonlint --quiet --comments
git ls-files -z '*.sh' '*.ksh' '*.bash' '*.zsh' '*.bats' | xargs -0 ${xargs_r} shellcheck -x
git ls-files -z 'package.json' '*/package.json' | xargs -0 -n1 ${xargs_r} pjv --quiet --filename
git ls-files -z '*.gitlab-ci.yml' | xargs -0 -n1 ${xargs_r} gitlab-ci-lint
git ls-files -z '*.gitlab-ci.yml' | xargs -0 -n1 ${xargs_r} gitlab-ci-validate validate
