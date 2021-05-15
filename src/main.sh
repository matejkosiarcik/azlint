#!/bin/sh
set -euf
export PATH="/src/node_modules/.bin:${PATH}" # npm
export PATH="/usr/local/bundle/bin:${PATH}"  # ruby bundler
export GEM_HOME=/usr/local/bundle
cd '/project'

if [ "$#" -ge 1 ] && ([ "$1" = '-h' ] || [ "$1" = '--help' ] || [ "$1" = 'help' ]); then
    printf 'azlint [options]... command\n'
    printf '\n'
    printf 'Options\n'
    printf '%s\n' '-h, --help    print help message'
    printf '\n'
    printf 'Command:\n'
    printf 'lint          lint files with available linters\n'
    printf 'fmt           format files with available formatters\n'
    exit 0
fi

mode='lint'
if [ "$#" -ge 1 ]; then
    mode="$1"
fi
if [ "$mode" != 'lint' ] && [ "$mode" != 'fmt' ]; then
    printf 'Unrecognised command %s\n' "$mode" >&2
    exit 1
fi

is_lint() {
    if [ "$mode" = 'lint' ]; then
        return 0
    else
        return 1
    fi
}

is_fmt() {
    if [ "$mode" = 'fmt' ]; then
        return 0
    else
        return 1
    fi
}

## Composer ##

if [ -z "${VALIDATE_COMPOSER_VALIDATE+x}" ] || [ "${VALIDATE_COMPOSER_VALIDATE}" != 'false' ]; then
    if is_lint; then
        project-find 'composer.json' | while read -r file; do
            printf "## composer validate %s ##\n" "${file}" >&2
            composer validate --quiet --no-interaction --no-cache --ansi --no-check-all --no-check-publish "${file}" ||
                composer validate --no-interaction --no-cache --ansi --no-check-all --no-check-publish "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_COMPOSER_NORMALIZE+x}" ] || [ "${VALIDATE_COMPOSER_NORMALIZE+x}" != 'false' ]; then
    project-find 'composer.json' | while read -r file; do
        printf "## composer normalize %s ##\n" "${file}" >&2
        file="${PWD}/${file}"
        if is_lint; then
            (cd /src && composer normalize --no-interaction --no-cache --ansi --dry-run --diff "${file}")
        else
            (cd /src && composer normalize --no-interaction --no-cache --ansi "${file}")
        fi
    done
fi

## GoLang ##

if [ -z "${VALIDATE_STOML+x}" ] || [ "${VALIDATE_STOML}" != 'false' ]; then
    if is_lint; then
        project-find '*.toml' 'Cargo.lock' | while read -r file; do
            printf "## stoml %s ##\n" "${file}" >&2
            stoml "${file}" . >/dev/null
        done
    fi
fi
if [ -z "${VALIDATE_TOMLJSON+x}" ] || [ "${VALIDATE_TOMLJSON}" != 'false' ]; then
    if is_lint; then
        project-find '*.toml' 'Cargo.lock' | while read -r file; do
            printf "## tomljson %s ##\n" "${file}" >&2
            tomljson "${file}" >/dev/null
        done
    fi
fi

## NodeJS ##

if [ -z "${VALIDATE_GITLAB_LINT+x}" ] || [ "${VALIDATE_GITLAB_LINT}" != 'false' ]; then
    if is_lint; then
        project-find '.gitlab-ci.yml' | while read -r file; do
            printf "## gitlab-ci-lint %s ##\n" "${file}" >&2
            gitlab-ci-lint "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_GITLAB_VALIDATE+x}" ] || [ "${VALIDATE_GITLAB_VALIDATE}" != 'false' ]; then
    if is_lint; then
        project-find '.gitlab-ci.yml' | while read -r file; do
            printf "## gitlab-ci-validate %s ##\n" "${file}" >&2
            gitlab-ci-validate validate "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_PACKAGE_JSON+x}" ] || [ "${VALIDATE_PACKAGE_JSON}" != 'false' ]; then
    if is_lint; then
        project-find 'package.json' | while read -r file; do
            # only validate non-private package.json
            if [ "$(jq .private <"${file}")" != 'true' ]; then
                printf "## package-json-validator %s ##\n" "${file}" >&2
                pjv --warnings --recommendations --filename "${file}"
            fi
        done
    fi
fi
if [ -z "${VALIDATE_SVGLINT+x}" ] || [ "${VALIDATE_SVGLINT}" != 'false' ]; then
    if is_lint && [ -e '.svglintrc.js' ]; then
        project-find '*.svg' | while read -r file; do
            printf "## svglint %s ##\n" "${file}" >&2
            svglint --ci "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_HTMLLINT+x}" ] || [ "${VALIDATE_HTMLLINT}" != 'false' ]; then
    if is_lint && [ -e '.htmllintrc' ]; then
        project-find '*.html' '*.htm' | while read -r file; do
            printf "## htmllint %s ##\n" "${file}" >&2
            htmllint "${file}"
        done
    fi
fi
if [ -z "${VALIDATE_BATS+x}" ] || [ "${VALIDATE_BATS}" != 'false' ]; then
    if is_lint; then
        project-find '*.bats' | while read -r file; do
            printf "## bats %s ##\n" "${file}" >&2
            bats --count "${file}" >/dev/null
        done
    fi
fi
if [ -z "${VALIDATE_JSONLINT+x}" ] || [ "${VALIDATE_JSONLINT}" != 'false' ]; then
    project-find '*.json' '*.geojson' '*.jsonl' '*.json5' '.htmlhintrc' '.htmllintrc' '.babelrc' '.jscsrc' '.jshintrc' '.jslintrc' '.ecrc' '.remarkrc' | while read -r file; do
        printf "## jsonlint %s ##\n" "${file}" >&2
        if is_lint; then
            jsonlint --quiet --comments --no-duplicate-keys "$file"
        else
            jsonlint --in-place --quiet --comments --enforce-double-quotes --trim-trailing-commas "$file"
            if [ "$(tail -c 1 <"$file")" != "$(printf '\n')" ]; then
                printf '\n' >>"$file" # jsonlint omits final newline
            fi
        fi
    done
fi
if [ -z "${VALIDATE_PRETTIER+x}" ] || [ "${VALIDATE_PRETTIER}" != 'false' ]; then
    project-find '*.yml' '*.yaml' '*.json' '*.html' '*.htm' '*.xhtml' '*.css' '*.scss' '*.sass' '*.md' | while read -r file; do
        printf "## prettier %s ##\n" "${file}" >&2
        if is_lint; then
            prettier --list-different "${file}"
        else
            prettier --write "$file"
        fi
    done
fi

## Python ##

if [ -z "${VALIDATE_BASHATE+x}" ] || [ "${VALIDATE_BASHATE}" != 'false' ]; then
    if is_lint; then
        project-find '*.sh' '*.bash' '*.ksh' '*.ash' '*.dash' '*.zsh' '*.yash' | while read -r file; do
            printf "## bashate %s ##\n" "${file}" >&2
            bashate --ignore E001,E002,E003,E004,E005,E006 "${file}" # ignore all whitespace/basic errors
        done
    fi
fi
if [ -z "${VALIDATE_AUTOPEP8+x}" ] || [ "${VALIDATE_AUTOPEP8}" != 'false' ]; then
    project-find '*.py' | while read -r file; do
        printf "## autopep8 %s ##\n" "${file}" >&2
        if is_lint; then
            autopep8 --diff "$file"
        else
            autopep8 --in-place "$file"
        fi
    done
fi
if [ -z "${VALIDATE_PYCODESTYLE+x}" ] || [ "${VALIDATE_PYCODESTYLE}" != 'false' ]; then
    if is_lint; then
        project-find '*.py' | while read -r file; do
            printf "## pycodestyle %s ##\n" "${file}" >&2
            pycodestyle "$file"
        done
    fi
fi
if [ -z "${VALIDATE_FLAKE8+x}" ] || [ "${VALIDATE_FLAKE8}" != 'false' ]; then
    if is_lint; then
        project-find '*.py' | while read -r file; do
            printf "## flake8 %s ##\n" "${file}" >&2
            flake8 "$file"
        done
    fi
fi
if [ -z "${VALIDATE_ISORT+x}" ] || [ "${VALIDATE_ISORT}" != 'false' ]; then
    project-find '*.py' | while read -r file; do
        printf "## isort %s ##\n" "${file}" >&2
        if is_lint; then
            isort --honor-noqa --check-only --diff "$file"
        else
            isort --honor-noqa "$file"
        fi
    done
fi
if [ -z "${VALIDATE_PYLINT+x}" ] || [ "${VALIDATE_PYLINT}" != 'false' ]; then
    if is_lint; then
        project-find '*.py' | while read -r file; do
            printf "## pylint %s ##\n" "${file}" >&2
            pylint "$file"
        done
    fi
fi
if [ -z "${VALIDATE_BLACK+x}" ] || [ "${VALIDATE_BLACK}" != 'false' ]; then
    project-find '*.py' | while read -r file; do
        printf "## black %s ##\n" "${file}" >&2
        if is_lint; then
            black --check --diff "$file"
        else
            black "$file"
        fi
    done
fi

## Ruby ##

if [ -z "${VALIDATE_TRAVIS_LINT+x}" ] || [ "${VALIDATE_TRAVIS_LINT}" != 'false' ]; then
    if is_lint; then
        project-find '.travis.yml' | while read -r file; do
            printf "## travis lint %s ##\n" "${file}" >&2
            (cd "$(dirname "${file}")" && travis lint --no-interactive --skip-version-check --skip-completion-check --exit-code --quiet)
        done
    fi
fi
if [ -z "${VALIDATE_MDL+x}" ] || [ "${VALIDATE_MDL}" != 'false' ]; then
    if is_lint && [ -e '.mdlrc' ]; then
        project-find '*.md' | while read -r file; do
            printf "## mdl %s ##\n" "${file}" >&2
            mdl "${file}" --config .mdlrc
        done
    fi
fi

## Exectables ##

if [ -z "${VALIDATE_CIRCLE_VALIDATE+x}" ] || [ "${VALIDATE_CIRCLE_VALIDATE}" != 'false' ]; then
    if is_lint; then
        project-find '.circleci/config.yml' | while read -r file; do
            printf "## circleci validate %s ##\n" "${file}" >&2
            (cd "$(dirname "$(dirname "${file}")")" && circleci config validate)
        done
    fi
fi
if [ -z "${VALIDATE_GMAKE+x}" ] || [ "${VALIDATE_GMAKE}" != 'false' ]; then
    if is_lint; then
        project-find 'makefile' 'Makefile' 'GNUMakefile' '*.make' | while read -r file; do
            printf "## gmake dry run %s ##\n" "${file}" >&2
            make --dry-run --file="${file}" >/dev/null
        done
    fi
fi
if [ -z "${VALIDATE_BMAKE+x}" ] || [ "${VALIDATE_BMAKE}" != 'false' ]; then
    if is_lint; then
        project-find 'makefile' 'Makefile' 'BSDMakefile' '*.make' | while read -r file; do
            printf "## bmake dry run %s ##\n" "${file}" >&2
            make -n -f "${file}" >/dev/null
        done
    fi
fi
