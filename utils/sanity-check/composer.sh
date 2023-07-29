#!/bin/sh
set -euf

composer --help
composer --version
composer install --help
(cd /app/linters && composer normalize --help)
(cd /app/linters && composer validate --help)
php --help
php --version
