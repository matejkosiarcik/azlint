#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

# update
brew update >'/dev/null'

# install system dependencies
brew bundle
