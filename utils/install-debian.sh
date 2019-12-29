#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

# prepare 3rd party repos
# apt-get update
# apt-get install -y software-properties-common
# add-apt-repository -y ppa:longsleep/golang-backports
# apt-get update
# apt-get install -y golang-go

# update apt
apt-key update
apt-get update
apt-get dist-upgrade

# install system dependencies
apt-get install -y git build-essential
apt-get install -y bash dash ksh mksh zsh yash
apt-get install -y nodejs npm
apt-get install -y python3 python3-pip python3-venv python3-setuptools
apt-get install -y composer
apt-get install -y libxml2-utils
apt-get install -y linuxbrew-wrapper

brew --help <'/dev/null' >'/dev/null' # run post-install linuxbrew scripts
