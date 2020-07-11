#!/bin/sh
set -euf

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi
build_args="${1---no-cache --pull}"

docker build --build-arg "AZLINT_VERSION=${AZLINT_VERSION}" './runner/' -t "matejkosiarcik/azlint:${AZLINT_VERSION}"
docker build "${build_args}" './components/alpine' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-alpine"
docker build "${build_args}" './components/bash' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-bash"
docker build "${build_args}" './components/brew' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-brew"
docker build "${build_args}" './components/composer' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-composer"
docker build "${build_args}" './components/debian' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-debian"
docker build "${build_args}" './components/go' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-go"
docker build "${build_args}" './components/hadolint' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-hadolint"
docker build "${build_args}" './components/haskell' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-haskell"
docker build "${build_args}" './components/node' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-node"
docker build "${build_args}" './components/python' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-python"
docker build "${build_args}" './components/shellcheck' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-shellcheck"
docker build "${build_args}" './components/swift' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-swift"
docker build "${build_args}" './components/zsh' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-zsh"
