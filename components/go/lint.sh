#!/bin/sh
set -euf
cd "${WORKDIR}"
PATH="${PATH}:$(dirname "${0}")/bin"

git ls-files -z '*.sh' '*.bash' '*.zsh' '*.ksh' '*.bats' | xargs -0 shfmt -l -d
