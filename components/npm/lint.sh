#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z | xargs -0 eclint check
git ls-files -z '*.sh' '*.bash' '*.zsh' '*.ksh' '*.mksh' '*.bats' | xargs -0 shellcheck -x
git ls-files -z 'package.json' | xargs -0 -n1 pjv --filename
git ls-files -z '.gitlab-ci.yml' | xargs -0 -n1 gitlab-ci-lint
git ls-files -z '.gitlab-ci.yml' | xargs -0 -n1 gitlab-ci-validate validate
git ls-files -z '*.md' '*.markdown' | xargs -0 markdownlint
