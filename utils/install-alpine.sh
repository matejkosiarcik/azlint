#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

# some packages are only available in edge
printf '%s\n%s\n%s\n' 'http://dl-cdn.alpinelinux.org/alpine/edge/main' 'http://dl-cdn.alpinelinux.org/alpine/edge/community' 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >>'/etc/apk/repositories'

# update apk
apk update

# install system dependencies
apk add alpine-sdk
apk add bash dash mksh loksh zsh yash
apk add nodejs npm
apk add python3 python3-dev py3-setuptools py3-virtualenv
apk add composer
apk add go
apk add libxml2-utils
