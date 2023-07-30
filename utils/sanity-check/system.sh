#!/bin/sh

# Shells
ash -c 'true'
bash -c 'true'
dash -c 'true'
ksh -c 'true'
ksh93 -c 'true'
mksh -c 'true'
posh -c 'true'
sh -c 'true'
yash -c 'true'
zsh -c 'true'

# Make
bmake -n -f /dev/null /dev/null
# TODO: Reenable: bsdmake -n -f /dev/null /dev/null
make --help
make --version
make -n -f /dev/null /dev/null
gmake --help
gmake --version
gmake -n -f /dev/null /dev/null

# Other
git --help
(tmpdir="$(mkdtemp)" &&
    cd "$tmpdir" &&
    git init &&
    rm -rf "$tmpdir")
xmllint --version

# Python - main
python --help
python --version
pip --help
pip --version
pip install --help

# PHP
composer --help
composer --version
composer install --help
php --help
php --version

# NodeJS - NPM
node --help
node --version
npm help
npm version
npm --version
npm install --help
npm ci --help
