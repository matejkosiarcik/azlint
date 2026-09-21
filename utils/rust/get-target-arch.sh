#!/bin/sh
set -euf

# shellcheck disable=SC2154
case "${TARGETARCH}" in
arm64)
    printf 'aarch64\n'
    ;;

amd64)
    printf 'x86_64\n'
    ;;

*)
    # shellcheck disable=SC2154
    printf 'Unsupported architecture: %s\n' "${TARGETARCH}"
    exit 1
    ;;
esac
