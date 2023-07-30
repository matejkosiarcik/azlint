#!/bin/sh
set -euf

composer --help
composer --version
composer install --help
(cd "${BINPREFIX:-}linters" && composer normalize --help)
(cd "${BINPREFIX:-}linters" && composer validate --help)
php --help
php --version
