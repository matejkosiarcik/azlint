#!/bin/sh
set -euf

# update apt
printf 'Updating...\n'
apt update -y
# apt upgrade -y

# install system dependencies
printf 'Installing...\n'
apt install -y git build-essential cmake
apt install -y bash dash ksh mksh zsh yash
apt install -y nodejs npm
apt install -y python3 python3-pip python3-venv python3-setuptools
apt install -y composer
apt install -y shellcheck libxml2-utils
