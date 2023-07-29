#!/bin/sh
set -euf

case "$TARGETARCH" in
arm64)
    printf 'aarch64\n'
    ;;

amd64)
    printf 'x86_64\n'
    ;;

*)
    printf 'Unsupported architecture: %s\n' "$TARGETARCH"
    exit 1
    ;;
esac
