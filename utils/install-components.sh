#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

npm --prefix 'components/npm' install

python3 -m ensurepip
python3 -m venv 'components/pip/venv' || python3 -m virtualenv 'components/pip/venv'
. 'components/pip/venv/bin/activate'
pip3 install --upgrade pip setuptools
pip3 install --requirement 'components/pip/requirements.txt'

composer --working-dir='components/composer' install
