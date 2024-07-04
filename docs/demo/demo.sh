#!/usr/bin/env bash
set -euf

cd "$(git rev-parse --show-toplevel)"

# shellcheck source=/dev/null
. ./docs/demo/gitman/demo-magic/demo-magic.sh

TYPE_SPEED=7
export TYPE_SPEED

clear
# shellcheck disable=SC2016
pei 'docker run -itv "$PWD:/project:ro" matejkosiarcik/azlint:dev'
