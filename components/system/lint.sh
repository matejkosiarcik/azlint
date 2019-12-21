#!/bin/sh
set -euf
cd /mount

shellcheck $(git ls-files "*.sh" "*.bash" "*.zsh" "*.ksh" "*.bats")
