#!/bin/sh
set -euf

# Python - main
python --help
python --version
pip --help
pip --version
pip install --help

# Python - python proper
"${BINPREFIX:-}autopep8" --help
"${BINPREFIX:-}autopep8" --version
"${BINPREFIX:-}isort" --help
"${BINPREFIX:-}isort" --version
"${BINPREFIX:-}pycodestyle" --help
"${BINPREFIX:-}pycodestyle" --version
"${BINPREFIX:-}pylint" --help
"${BINPREFIX:-}pylint" --version
"${BINPREFIX:-}bandit" --help
"${BINPREFIX:-}bandit" --version
"${BINPREFIX:-}flake8" --help
"${BINPREFIX:-}flake8" --version
"${BINPREFIX:-}black" --help
"${BINPREFIX:-}black" --version
"${BINPREFIX:-}mypy" --help
"${BINPREFIX:-}mypy" --version

# Python - other
"${BINPREFIX:-}bashate" --help
"${BINPREFIX:-}bashate" --version
"${BINPREFIX:-}bashate" --show
"${BINPREFIX:-}checkov" --help
"${BINPREFIX:-}checkov" --version
# TODO: "${BINPREFIX:-}gitman" --help
# TODO: "${BINPREFIX:-}gitman" --version
"${BINPREFIX:-}proselint" --help
"${BINPREFIX:-}proselint" --version
"${BINPREFIX:-}sqlfluff" --help
"${BINPREFIX:-}sqlfluff" --version
"${BINPREFIX:-}yamllint" --help
"${BINPREFIX:-}yamllint" --version
