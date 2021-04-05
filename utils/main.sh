#!/bin/sh
set -euf
export PATH="/src/node_modules/.bin:${PATH}" # npm
export PATH="/usr/local/bundle/bin:${PATH}"  # ruby bundler
export GEM_HOME=/usr/local/bundle
cd '/project'

## Composer ##

if [ -z "${VALIDATE_COMPOSER_VALIDATE+x}" ] || [ "${VALIDATE_COMPOSER_VALIDATE}" != 'false' ]; then
    project-find 'composer.json' | while read -r file; do
        printf "## composer validate %s ##\n" "${file}" >&2
        composer validate --quiet --no-interaction --no-cache --ansi --no-check-all --no-check-publish "${file}" ||
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
if [ -z "${VALIDATE_PACKAGE_JSON+x}" ] || [ "${VALIDATE_PACKAGE_JSON}" != 'false' ]; then
    project-find 'package.json' | while read -r file; do
        # only validate non-private package.json
        if [ "$(jq .private <"${file}")" != 'true' ]; then
            printf "## package-json-validator %s ##\n" "${file}" >&2
            pjv --warnings --recommendations --filename "${file}"
        fi
    done
fi
if [ -z "${VALIDATE_SVGLINT+x}" ] || [ "${VALIDATE_SVGLINT}" != 'false' ]; then
    if [ -e '.svglintrc.js' ]; then
        project-find '*.svg' | while read -r file; do
            printf "## svglint %s ##\n" "${file}" >&2
            svglint --ci "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_HTMLLINT+x}" ] || [ "${VALIDATE_HTMLLINT}" != 'false' ]; then
    if [ -e '.htmllintrc' ]; then
        project-find '*.html' '*.htm' | while read -r file; do
            printf "## htmllint %s ##\n" "${file}" >&2
            htmllint "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_BATS+x}" ] || [ "${VALIDATE_BATS}" != 'false' ]; then
    project-find '*.bats' | while read -r file; do
        printf "## bats %s ##\n" "${file}" >&2
        bats --count "${file}" >/dev/null
    done
fi
if [ -z "${VALIDATE_JSONLINT+x}" ] || [ "${VALIDATE_JSONLINT}" != 'false' ]; then
    project-find '*.json' '*.geojson' '*.jsonl' '*.json5' 'composer.lock' '.htmlhintrc' '.htmllintrc' '.babelrc' '.jscsrc' '.jshintrc' '.jslintrc' '.ecrc' '.remarkrc' | while read -r file; do
        printf "## jsonlint %s ##\n" "${file}" >&2
        jsonlint --quiet --comments "${file}"
    done
fi

## Python ##

if [ -z "${VALIDATE_BASHATE+x}" ] || [ "${VALIDATE_BASHATE}" != 'false' ]; then
    project-find '*.sh' '*.bash' '*.ksh' '*.ash' '*.dash' '*.' | while read -r file; do
        printf "## bashate %s ##\n" "${file}" >&2
        bashate --ignore E001,E002,E003,E004,E005,E006 "${file}" # ignore all whitespace/basic errors
    done
fi

## Ruby ##

if [ -z "${VALIDATE_TRAVIS_LINT+x}" ] || [ "${VALIDATE_TRAVIS_LINT}" != 'false' ]; then
    project-find '.travis.yml' | while read -r file; do
        printf "## travis lint %s ##\n" "${file}" >&2
        (cd "$(dirname "${file}")" && travis lint --no-interactive --skip-version-check --skip-completion-check --exit-code --quiet)
    done
fi
if [ -z "${VALIDATE_MDL+x}" ] || [ "${VALIDATE_MDL}" != 'false' ]; then
    if [ -e '.mdlrc' ]; then
        project-find '*.md' | while read -r file; do
            printf "## mdl %s ##\n" "${file}" >&2
            mdl "${file}" --config .mdlrc
        done
    fi
fi

## Exectables ##

if [ -z "${VALIDATE_CIRCLE_VALIDATE+x}" ] || [ "${VALIDATE_CIRCLE_VALIDATE}" != 'false' ]; then
    project-find '.circleci/config.yml' | while read -r file; do
        printf "## circleci validate %s ##\n" "${file}" >&2
        (cd "$(dirname "$(dirname "${file}")")" && circleci config validate)
    done
fi
if [ -z "${VALIDATE_GMAKE+x}" ] || [ "${VALIDATE_GMAKE}" != 'false' ]; then
    project-find 'makefile' 'Makefile' 'GNUMakefile' '*.make' | while read -r file; do
        printf "## gmake dry run %s ##\n" "${file}" >&2
        make --dry-run --file="${file}" >/dev/null
    done
fi
if [ -z "${VALIDATE_BMAKE+x}" ] || [ "${VALIDATE_BMAKE}" != 'false' ]; then
    project-find 'makefile' 'Makefile' 'BSDMakefile' '*.make' | while read -r file; do
        printf "## bmake dry run %s ##\n" "${file}" >&2
        make -n -f "${file}" >/dev/null
    done
fi
