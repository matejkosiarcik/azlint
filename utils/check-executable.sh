#!/bin/sh
# shellcheck disable=SC2251
# Inspect executables for unecessary baggage
set -euf

# Check for debug symbols and strip-ing (relevant for: all)
file "$1" | grep -i 'stripped'
! file "$1" | grep -i 'not stripped'
! file "$1" | grep -i 'with debuginfo'

# # Check BuildID (relevant for: Rust, Go)
! file "$1" | grep -i 'buildid'
! file "$1" | grep -i 'build-id'
