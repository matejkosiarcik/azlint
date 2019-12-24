#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z '*.sh' '*.bash' '*.zsh' '*.ksh' '*.bats' | xargs -0 shellcheck -x
