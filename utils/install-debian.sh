#!/bin/sh
set -euf

# update apt
apt update -y
# apt upgrade -y

# install system dependencies
apt install -y git build-essential
apt install -y bash dash ksh mksh zsh yash
apt install -y nodejs npm
apt install -y python3 python3-pip python3-venv python3-setuptools
apt install -y composer
apt install -y cabal-install shellcheck
apt install -y golang
apt install -y libxml2-utils
