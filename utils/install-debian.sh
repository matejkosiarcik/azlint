#!/bin/sh
set -euf

# prepare 3rd party repos
# apt-get update
# apt-get install -y software-properties-common
# add-apt-repository -y ppa:longsleep/golang-backports

# update apt
apt-get update

# install system dependencies
apt-get install -y git build-essential
apt-get install -y bash dash ksh mksh zsh yash
apt-get install -y nodejs npm
apt-get install -y python3 python3-pip python3-venv python3-setuptools
apt-get install -y composer
apt-get install -y libxml2-utils

# install other packages
apt-get install -y snapd
snap install --classic go
snap install shellcheck
