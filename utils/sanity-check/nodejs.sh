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
jsonlint --help
jsonlint --version
bats --help
bats --version
dockerfilelint --help
dockerfilelint --version
eclint --help
eclint --version
gitlab-ci-lint --help
gitlab-ci-lint --version
gitlab-ci-validate --help
gitlab-ci-validate --version
htmlhint --help
htmlhint --version
htmllint --help
htmllint --version
jscpd --help
jscpd --version
markdown-link-check --help
markdown-link-check --version
markdown-table-formatter --help
markdown-table-formatter --version
markdownlint --help
markdownlint --version
pjv --help
prettier --help
prettier --version
secretlint --help
secretlint --version
sql-lint --help
sql-lint --version
svglint --help
svglint --version
textlint --help
textlint --version
