#!/bin/sh
set -euf
WORKDIR="$(cd "${WORKDIR:-.}" && printf '%s\n' "${PWD}")"
export WORKDIR
cd "$(dirname "${0}")/.."

sh 'components/system/lint.sh'
npm --prefix 'components/npm' run lint
sh 'components/pip/lint.sh'
composer --working-dir='components/composer' run-script lint
