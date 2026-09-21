#!/bin/sh
set -euf

# shellcheck disable=SC2154
if [ "${TARGETOS}" != 'linux' ]; then
    printf 'Unsupported target OS: %s\n' "${TARGETOS}"
    exit 1
fi

# shellcheck disable=SC2154
case "${TARGETARCH}" in
arm64)
    printf 'aarch64-unknown-linux-gnu\n'
    ;;

amd64)
    printf 'x86_64-unknown-linux-gnu\n'
    ;;

*)
    # shellcheck disable=SC2154
    printf 'Unsupported architecture: %s\n' "${TARGETARCH}"
    exit 1
    ;;
esac
