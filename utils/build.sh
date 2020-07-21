#!/bin/sh
# shellcheck disable=SC2086
set -euf
cd "$(dirname "${0}")/.."

# default version for development
if [ -z "${AZLINT_VERSION+x}" ]; then
    AZLINT_VERSION='dev'
fi
# default build environment
if [ -z "${BUILD_ENV+x}" ]; then
    BUILD_ENV='dev'
fi
build_args='--no-cache --pull'

build_list="$(mktemp)"
if [ "${#}" -eq 0 ]; then
    # no arguments, build all
    printf 'runner\n' >"${build_list}"
    ls -1 'components' | sort >>"${build_list}"
else
    # list components  to build
    while [ "${#}" -ge 1 ]; do
        printf "${1}\n" >>"${build_list}"
        shift 1
    done
fi

while read -r component; do
    if [ "${component}" = runner ]; then
        printf '%s\n' '--- runner ---'
        docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" --build-arg "AZLINT_VERSION=${AZLINT_VERSION}" './runner/' -t "matejkosiarcik/azlint:${AZLINT_VERSION}"
    else
        printf '%s %s %s\n' '---' "${component}" '---'
        docker build ${build_args} --build-arg "BUILD_ENV=${BUILD_ENV}" "./components/${component}" -t "matejkosiarcik/azlint-internal:${AZLINT_VERSION}-${component}"
    fi
done <"${build_list}"

rm -f "${build_list}" # TODO: set up trap to remove properly on error
