#!/usr/bin/env bash
set -euf

cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./gitman/demo-magic/demo-magic.sh
# shellcheck disable=SC2034
TYPE_SPEED=7

cd '../..' # cd to project root

clear
pei 'docker run -itv "$PWD:/project:ro" matejkosiarcik/azlint:dev'
