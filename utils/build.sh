#!/bin/sh
set -euf

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi

docker build --no-cache --pull --build-arg "AZLINT_VERSION=${AZLINT_VERSION}" './runner/' -t "matejkosiarcik/azlint:${AZLINT_VERSION}"
docker build --no-cache --pull './components/alpine' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-alpine"
docker build --no-cache --pull './components/debian' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-debian"
docker build --no-cache --pull './components/node' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-node"
docker build --no-cache --pull './components/python' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-python"
docker build --no-cache --pull './components/composer' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-composer"
docker build --no-cache --pull './components/go' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-go"
docker build --no-cache --pull './components/swift' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-swift"
docker build --no-cache --pull './components/bash' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-bash"
docker build --no-cache --pull './components/zsh' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-zsh"
docker build --no-cache --pull './components/shellcheck' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-shellcheck"
docker build --no-cache --pull './components/hadolint' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-hadolint"
docker build --no-cache --pull './components/brew' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-brew"
