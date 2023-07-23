#!/bin/sh
set -euf
# This script checks executables/binaries/dependencies are actually runnable
# How can they not be runnable?
# Somewhere in the chain, we might do an optimization which screws them up,
# eg. UPX
# Or remove too much files from node_modules/bundle/python directories

# Brew
brew --help
brew --version
brew bundle --help

# Composer
composer --help
composer --version
composer install --help
(cd /app/linters && composer normalize --help)
(cd /app/linters && composer validate --help)

# Go
actionlint --help
actionlint --version
checkmake --help
checkmake --list-rules
checkmake --version
ec --help
ec --version
shfmt --help
shfmt --version
stoml --help
stoml --version
tomljson --help

# Haskell
hadolint --help
hadolint --version
shellcheck --help
shellcheck --version

# Make
bmake -n -f /dev/null /dev/null
# TODO: Reenable # bsdmake -n -f /dev/null /dev/null
make --help
make --version
make -n -f /dev/null /dev/null
gmake --help
gmake --version
gmake -n -f /dev/null /dev/null

# NodeJS - NPM
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
sql-lint --help
sql-lint --version
svglint --help
svglint --version

# Python - main
pip --help
pip --version
pip install --help

# Python - python proper
autopep8 --help
autopep8 --version
isort --help
isort --version
pycodestyle --help
pycodestyle --version
pylint --help
pylint --version
bandit --help
bandit --version
flake8 --help
flake8 --version
black --help
black --version
mypy --help
mypy --version

# Python - other
bashate --help
bashate --version
bashate --show
# TODO: add # gitman --help
# TODO: add # gitman --version
proselint --help
proselint --version
sqlfluff --help
sqlfluff --version
yamllint --help
yamllint --version

# Ruby
bundle --help >/dev/null
bundle --version
bundle exec mdl --help
bundle exec mdl --version
bundle exec travis --help --no-interactive
bundle exec travis --version --no-interactive

# Rust
dotenv-linter --help
dotenv-linter --version
hush --help
hush --version
shellharden --help
shellharden --version

# Shells
loksh -c 'true'
oksh -c 'true'

# System/Other
circleci --help
circleci version
git --help
xmllint --version
