#!/bin/sh
set -euf

# some packages are only available in edge
echo http://dl-cdn.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories
echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories
echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories

# update apk
apk update
apk upgrade

# install system dependencies
apk add git
apk add make cmake clang gcc
apk add bash dash mksh loksh zsh yash
apk add nodejs npm
apk add python3
# python3-dev py3-setuptools
apk add shellcheck shfmt
apk add libxml2-utils
