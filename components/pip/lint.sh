#!/bin/sh
# shellcheck source=venv/bin/activate
set -euf
cd "${WORKDIR}"

. "$(dirname "${0}")/venv/bin/activate"
git ls-files -z '*.yml' '*.yaml' | xargs -0 yamllint
