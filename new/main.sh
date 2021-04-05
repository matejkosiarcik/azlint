#!/bin/sh
set -euf
cd '/project'

## Composer ##
if [ -z "${VALIDATE_COMPOSER_VALIDATE+x}" ] || [ "${VALIDATE_COMPOSER_VALIDATE}" != 'false' ]; then
    project-find 'composer.json' | while read -r file; do
        printf "## composer validate %s ##\n" "${file}" >&2
        composer validate --quiet --no-interaction --no-cache --ansi --no-check-all --no-check-publish "${file}" || \
            composer validate --no-interaction --no-cache --ansi --no-check-all --no-check-publish "${file}"
    done
fi
if [ -z "${VALIDATE_COMPOSER_NORMALIZE+x}" ] || [ "${VALIDATE_COMPOSER_NORMALIZE+x}" != 'false' ]; then
    project-find 'composer.json' | while read -r file; do
        printf "## composer normalize %s ##\n" "${file}" >&2
        file="${PWD}/${file}"
        (cd /src && composer normalize --no-interaction --no-cache --ansi --dry-run --diff "${file}")
    done
fi

## GoLang ##
if [ -z "${VALIDATE_GO_STOML+x}" ] || [ "${VALIDATE_GO_STOML}" != 'false' ]; then
    project-find '*.toml' 'Cargo.lock' | while read -r file; do
        printf "## stoml %s ##\n" "${file}" >&2
        stoml "${file}" . >/dev/null
    done
fi
if [ -z "${VALIDATE_GO_TOMLJSON+x}" ] || [ "${VALIDATE_GO_TOMLJSON}" != 'false' ]; then
    project-find '*.toml' 'Cargo.lock' | while read -r file; do
        printf "## tomljson %s ##\n" "${file}" >&2
        tomljson "${file}" >/dev/null
    done
fi
