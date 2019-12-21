#!/bin/sh
set -euf
project_path=$(cd "$(dirname "${0}")/.." && pwd)

npm --prefix "${project_path}/components/npm" run lint
sh "${project_path}/components/system/lint.sh"
composer --working-dir ""${project_path}"/components/composer" run-script lint
