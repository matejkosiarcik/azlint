#!/bin/sh
set -euf

# some packages are only available in edge
printf '%s\n%s\n%s\n' 'http://dl-cdn.alpinelinux.org/alpine/edge/main' 'http://dl-cdn.alpinelinux.org/alpine/edge/community' 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >>'/etc/apk/repositories'

# update apk
apk update
# apk upgrade

# install system dependencies
apk add alpine-sdk
apk add bash dash mksh loksh zsh yash
apk add nodejs npm
apk add python3 python3-dev py3-setuptools py3-virtualenv
apk add composer
apk add cabal shellcheck
apk add go shfmt
apk add libxml2-utils
