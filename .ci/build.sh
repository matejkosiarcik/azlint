#!/bin/sh
set -euf

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi

docker build '.' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-all"
docker build './components/shellcheck' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-shellcheck"
docker build './components/python' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-python"
docker build './components/composer' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-composer"
docker build './components/go' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-go"
docker build './components/node' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-node"
