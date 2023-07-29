#!/bin/sh
set -euf

# Python - main
python --help
python --version
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
checkov --help
checkov --version
# TODO: add # gitman --help
# TODO: add # gitman --version
proselint --help
proselint --version
sqlfluff --help
sqlfluff --version
yamllint --help
yamllint --version
