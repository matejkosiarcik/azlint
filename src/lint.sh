#!/bin/sh
set -euf

# shellcheck disable=SC2068
val 'azlint lint $@'
