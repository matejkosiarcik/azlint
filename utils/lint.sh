#!/bin/sh
set -euf

npm --prefix /azlint/components/npm run lint
sh /azlint/components/system/lint.sh
