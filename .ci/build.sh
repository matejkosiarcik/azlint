#!/bin/sh
set -euf

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi

docker build --no-cache --pull '.' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-all"
docker build --no-cache --pull './components/alpine' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-alpine"
docker build --no-cache --pull './components/node' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-node"
docker build --no-cache --pull './components/python' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-python"
docker build --no-cache --pull './components/composer' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-composer"
docker build --no-cache --pull './components/go' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-go"
docker build --no-cache --pull './components/shellcheck' -t "matejkosiarcik/azlint:${AZLINT_VERSION}-shellcheck"
