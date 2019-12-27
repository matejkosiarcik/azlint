#!/bin/sh
set -euf
cd "${WORKDIR}"

set +u && . "$(dirname "${0}")/venv/bin/activate" && set -u
git ls-files -z '*.yml' '*.yaml' | xargs -0 yamllint --strict
