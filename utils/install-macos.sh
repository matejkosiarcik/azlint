#!/bin/sh
set -euf
cd "$(dirname "${0}")"

# update
brew update

# install system dependencies
brew bundle
