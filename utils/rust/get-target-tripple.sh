#!/bin/sh
set -euf

if [ "$TARGETOS" != linux ]; then
    printf 'Unsupported target OS: %s\n' "$TARGETOS"
    exit 1
fi

case "$TARGETARCH" in
arm64)
    printf 'aarch64-unknown-linux-gnu\n'
    ;;

amd64)
    printf 'x86_64-unknown-linux-gnu\n'
    ;;

*)
    printf 'Unsupported architecture: %s\n' "$TARGETARCH"
    exit 1
    ;;
esac
