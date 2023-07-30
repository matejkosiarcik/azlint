#!/bin/sh
set -euf
# This script checks executables/binaries/dependencies are actually runnable
# How can they not be runnable?
# Somewhere in the chain, we might do an optimization which screws them up,
# eg. upx, or being too aggressive with removing files from node_modules/bundle/python directories

# sh "$(dirname "$0")/brew.sh"
# sh "$(dirname "$0")/circleci.sh"
# sh "$(dirname "$0")/composer.sh"
# sh "$(dirname "$0")/go-actionlint.sh"
# sh "$(dirname "$0")/go-checkmake.sh"
# sh "$(dirname "$0")/go-editorconfig-checker.sh"
# sh "$(dirname "$0")/go-shfmt.sh"
# sh "$(dirname "$0")/go-stoml.sh"
# sh "$(dirname "$0")/go-tomljson.sh"
# sh "$(dirname "$0")/haskell-hadolint.sh"
# sh "$(dirname "$0")/haskell-shellcheck.sh"
# sh "$(dirname "$0")/nodejs.sh"
# sh "$(dirname "$0")/python.sh"
# sh "$(dirname "$0")/ruby.sh"
# sh "$(dirname "$0")/rust.sh"
# sh "$(dirname "$0")/shell-loksh.sh"
# sh "$(dirname "$0")/shell-oksh.sh"
sh "$(dirname "$0")/system.sh"
