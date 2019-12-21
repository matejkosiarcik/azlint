#!/bin/sh
set -euf

npm --prefix components/npm install

python3 -m ensurepip
pip3 install --upgrade pip setuptools
pip3 install --requirement components/pip/requirements.txt
