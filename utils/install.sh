#!/bin/sh
set -euf
cd "$(dirname "${0}")/.."

if [ "$(uname -s)" = Darwin ]; then
    sh 'utils/install-macos.sh'
elif command -v apt-get >/dev/null 2>&1; then
    sudo sh 'utils/install-debian.sh'
elif command -v apk >/dev/null 2>&1; then
    sh 'utils/install-alpine.sh'
fi

# make sure brew is installed correctly
# mainly for linuxbrew
if command -v brew >'/dev/null' 2>&1; then
    brew --help <'/dev/null' >'/dev/null'
    brew update >'/dev/null'
fi

sh 'utils/install-components.sh'
