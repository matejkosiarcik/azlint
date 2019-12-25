#!/bin/sh
set -euf
cd "$(dirname "${0}")"

# update
brew update
# brew upgrade

# install system dependencies
brew bundle
