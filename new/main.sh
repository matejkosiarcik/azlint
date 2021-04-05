#!/bin/sh
set -euf
export PATH="/src/node_modules/.bin:${PATH}" # npm
export PATH="/usr/local/bundle/bin:${PATH}" # ruby bundler
export GEM_HOME=/usr/local/bundle
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
if [ -z "${VALIDATE_STOML+x}" ] || [ "${VALIDATE_STOML}" != 'false' ]; then
    project-find '*.toml' 'Cargo.lock' | while read -r file; do
        printf "## stoml %s ##\n" "${file}" >&2
        stoml "${file}" . >/dev/null
    done
fi
if [ -z "${VALIDATE_TOMLJSON+x}" ] || [ "${VALIDATE_TOMLJSON}" != 'false' ]; then
    project-find '*.toml' 'Cargo.lock' | while read -r file; do
        printf "## tomljson %s ##\n" "${file}" >&2
        tomljson "${file}" >/dev/null
    done
fi

## NodeJS ##

if [ -z "${VALIDATE_GITLAB_LINT+x}" ] || [ "${VALIDATE_GITLAB_LINT}" != 'false' ]; then
    project-find '.gitlab-ci.yml' | while read -r file; do
        printf "## gitlab-ci-lint %s ##\n" "${file}" >&2
        gitlab-ci-lint "${file}"
    done
fi
if [ -z "${VALIDATE_GITLAB_VALIDATE+x}" ] || [ "${VALIDATE_GITLAB_VALIDATE}" != 'false' ]; then
    project-find '.gitlab-ci.yml' | while read -r file; do
        printf "## gitlab-ci-validate %s ##\n" "${file}" >&2
        gitlab-ci-validate validate "${file}"
    done
fi

## Ruby ##

if [ -z "${VALIDATE_TRAVIS_LINT+x}" ] || [ "${VALIDATE_TRAVIS_LINT}" != 'false' ]; then
    project-find '.travis.yml' | while read -r file; do
        printf "## travis lint %s ##\n" "${file}" >&2
        travis lint --no-interactive --skip-version-check --skip-completion-check --exit-code --quiet
    done
fi

## Exectables ##

if [ -z "${VALIDATE_CIRCLE_VALIDATE+x}" ] || [ "${VALIDATE_CIRCLE_VALIDATE}" != 'false' ]; then
    project-find '.circleci/config.yml' | while read -r file; do
        printf "## circleci validate %s ##\n" "${file}" >&2
        (cd "$(dirname "$(dirname "${file}")")" && circleci config validate)
    done
fi
