#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

# update
brew update

# install system dependencies
printf 'Before bundling:\n'
brew bundle --help

printf 'Bundling:\n'
brew bundle
