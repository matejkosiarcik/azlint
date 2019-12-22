#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

npm --prefix 'components/npm' install

python3 -m ensurepip
pip3 install --upgrade pip setuptools
pip3 install --requirement 'components/pip/requirements.txt'

composer --working-dir='components/composer' install
