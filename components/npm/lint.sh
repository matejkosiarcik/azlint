#!/bin/sh
set -euf
cd "${WORKDIR}"

git ls-files -z | xargs -0 eclint check
