#!/bin/sh
# shellcheck disable=SC2086
set -euf

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi
# default build environment
if [ -z "${BUILD_ENV+x}" ]; then
    BUILD_ENV='dev'
fi
build_args='--no-cache --pull'

docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" --build-arg "AZLINT_VERSION=${AZLINT_VERSION}" './runner/' -t "matejkosiarcik/azlint:${AZLINT_VERSION}"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/alpine' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-alpine"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/bash' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-bash"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/brew' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-brew"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/composer' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-composer"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/debian' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-debian"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/go' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-go"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/haskell' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-haskell"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/node' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-node"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/python' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-python"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/ruby' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-ruby"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/swift' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-swift"
docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" './components/zsh' -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-zsh"
