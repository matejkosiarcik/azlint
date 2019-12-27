#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z | xargs -0 eclint check
git ls-files -z '*.md' '*.markdown' '*.mdown' '*.mdwn' '*.mdx' '*.mkd' '*.mkdn' '*.mkdown' '*.ronn' '*.workbook' 'contents.lr' '*/contents.lr' | xargs -0 markdownlint
git ls-files -z '*.json' 'composer.lock' '*/composer.lock' | xargs -0 jsonlint --quiet
git ls-files -z '*.sh' '*.bash' '*.zsh' '*.ksh' '*.mksh' '*.bats' | xargs -0 shellcheck -x
git ls-files -z 'package.json' '*/package.json' | xargs -0 -n1 pjv --quiet --filename
git ls-files -z '*.gitlab-ci.yml' | xargs -0 -n1 -t gitlab-ci-lint
git ls-files -z '*.gitlab-ci.yml' | xargs -0 -n1 -t gitlab-ci-validate validate
