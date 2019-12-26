#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

npm --prefix 'components/npm' install

command -v pip3 >/dev/null 2>&1 || python3 -m ensurepip
python3 -m venv 'components/pip/venv' || python3 -m virtualenv 'components/pip/venv' || virtualenv -p python3 'components/pip/venv'
set +eu
. 'components/pip/venv/bin/activate'
set -eu
pip3 install --upgrade pip setuptools
pip3 install --requirement 'components/pip/requirements.txt'

composer --working-dir='components/composer' install

GOPATH="${PWD}/components/go" GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt
