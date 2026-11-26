#!/bin/sh
set -euf

# NodeJS - NPM
node --help
node --version
npm help
npm version
npm --version
npm install --help
npm ci --help

# NodeJS - packages
"${BINPREFIX:-}jsonlint" --help
"${BINPREFIX:-}jsonlint" --version
"${BINPREFIX:-}bats" --help
"${BINPREFIX:-}bats" --version
"${BINPREFIX:-}dockerfilelint" --help
"${BINPREFIX:-}dockerfilelint" --version
"${BINPREFIX:-}eclint" --help
"${BINPREFIX:-}eclint" --version
"${BINPREFIX:-}gitlab-ci-lint" --help
"${BINPREFIX:-}gitlab-ci-lint" --version
"${BINPREFIX:-}gitlab-ci-validate" --help
"${BINPREFIX:-}gitlab-ci-validate" --version
"${BINPREFIX:-}htmlhint" --help
"${BINPREFIX:-}htmlhint" --version
"${BINPREFIX:-}htmllint" --help
"${BINPREFIX:-}htmllint" --version
"${BINPREFIX:-}jscpd" --help
"${BINPREFIX:-}jscpd" --version
"${BINPREFIX:-}markdown-link-check" --help
"${BINPREFIX:-}markdown-link-check" --version
"${BINPREFIX:-}markdown-table-formatter" --help
"${BINPREFIX:-}markdown-table-formatter" --version
"${BINPREFIX:-}markdownlint" --help
"${BINPREFIX:-}markdownlint" --version
"${BINPREFIX:-}package-json-validator-cli" --help
"${BINPREFIX:-}prettier" --help
"${BINPREFIX:-}prettier" --version
"${BINPREFIX:-}secretlint" --help
"${BINPREFIX:-}secretlint" --version
"${BINPREFIX:-}sql-lint" --help
"${BINPREFIX:-}sql-lint" --version
"${BINPREFIX:-}svglint" --help
"${BINPREFIX:-}svglint" --version
"${BINPREFIX:-}textlint" --help
"${BINPREFIX:-}textlint" --version

printf 'A clean document.\n' | "${BINPREFIX:-}textlint" --no-textlintrc --stdin --stdin-filename 'sample.txt' --rule no-todo
if textlint_output=$(printf 'TODO: fix this\n' | "${BINPREFIX:-}textlint" --no-textlintrc --stdin --stdin-filename 'sample.md' --rule no-todo --format compact 2>&1); then
    printf '%s\n' 'textlint did not detect the TODO' >&2
    exit 1
else
    textlint_status=$?
    [ "${textlint_status}" -eq 1 ] && printf '%s\n' "${textlint_output}" | grep -F 'Found TODO:'
fi
