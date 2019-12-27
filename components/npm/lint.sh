#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z | xargs -0 eclint check
git ls-files -z '*.sh' '*.bash' '*.zsh' '*.ksh' '*.mksh' '*.bats' | xargs -0 shellcheck -x
