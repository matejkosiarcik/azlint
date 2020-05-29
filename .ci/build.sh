#!/bin/sh
set -euf

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi

docker build '.' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-all"
docker build './components/shellcheck' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-shellcheck"
docker build './components/python' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-python"
