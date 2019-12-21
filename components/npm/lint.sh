#!/bin/sh
set -euf
cd /mount

eclint check $(git ls-files)
