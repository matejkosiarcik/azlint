#!/bin/sh
set -euf
export PATH="/src/node_modules/.bin:/usr/local/bundle/bin:$PATH"
export GEM_HOME='/usr/local/bundle'
cd '/project'

if [ "$#" -lt 2 ]; then
    printf 'Not enough arguments\n' >&2
    exit 1
fi

logfile="$(mktemp)"
mode="$1"
filelist="$2"
filelistpy="$(dirname "$0")/glob_files.py"
# shellcheck disable=SC2139
alias list="$filelistpy $filelist"

if [ "$mode" = 'lint' ]; then
    _is_lint=0
else
    _is_lint=1
fi
is_lint() {
    return "$_is_lint"
}

## General ##

if [ -z "${VALIDATE_EDITORCONFIG+x}" ] || [ "$VALIDATE_EDITORCONFIG" != 'false' ]; then
    if is_lint; then
        list '*' | while read -r file; do
            printf "## editorconfig-checker %s ##\n" "$file" >&2
            ec "$file"
        done
    fi
fi

## Configs (JSON, YAML, TOML, ENV) ##

if [ -z "${VALIDATE_JSONLINT+x}" ] || [ "$VALIDATE_JSONLINT" != 'false' ]; then
    list '*.json' '*.geojson' '*.jsonl' '*.json5' '.htmlhintrc' '.htmllintrc' '.babelrc' '.jscsrc' '.jshintrc' '.jslintrc' '.ecrc' '.remarkrc' | while read -r file; do
        printf "## jsonlint %s ##\n" "$file" >&2
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

if [ -z "${VALIDATE_PRETTIER+x}" ] || [ "$VALIDATE_PRETTIER" != 'false' ]; then
    list '*.yml' '*.yaml' '*.json' | while read -r file; do
        printf "## prettier %s ##\n" "$file" >&2
        if is_lint; then
            prettier --list-different "$file"
        else
            prettier --loglevel error --write "$file"
        fi
    done
fi

if [ -z "${VALIDATE_YAMLLINT+x}" ] || [ "$VALIDATE_YAMLLINT" != 'false' ]; then
    if is_lint; then
        list '*.yml' '*.yaml' | while read -r file; do
            printf "## yamllint %s ##\n" "$file" >&2
            yamllint --strict "$file"
        done
    fi
fi

if [ -z "${VALIDATE_PACKAGE_JSON+x}" ] || [ "$VALIDATE_PACKAGE_JSON" != 'false' ]; then
    if is_lint; then
        list 'package.json' | while read -r file; do
            # only validate non-private package.json
            if [ "$(jq .private <"$file")" != 'true' ]; then
                printf "## package-json-validator %s ##\n" "$file" >&2
                pjv --warnings --recommendations --filename "$file"
            fi
        done
    fi
fi

if [ -z "${VALIDATE_COMPOSER_VALIDATE+x}" ] || [ "$VALIDATE_COMPOSER_VALIDATE" != 'false' ]; then
    if is_lint; then
        list 'composer.json' | while read -r file; do
            printf "## composer-validate %s ##\n" "$file" >&2
            composer validate --no-interaction --no-cache --ansi --no-check-all --no-check-publish "$file" >"$logfile" 2>&1 || { cat "$logfile" && exit 1; }
        done
    fi
fi

if [ -z "${VALIDATE_COMPOSER_NORMALIZE+x}" ] || [ "$VALIDATE_COMPOSER_NORMALIZE" != 'false' ]; then
    list 'composer.json' | while read -r file; do
        printf "## composer-normalize %s ##\n" "$file" >&2
        file="$PWD/$file"
        if is_lint; then
            if ! (cd /src && composer normalize --no-interaction --no-cache --ansi --dry-run --diff "$file" >"$logfile" 2>&1); then
                cat "$logfile"
                exit 1
            fi
        else
            (cd /src && composer normalize --no-interaction --no-cache --ansi "$file")
        fi
    done
fi

if [ -z "${VALIDATE_TOMLJSON+x}" ] || [ "$VALIDATE_TOMLJSON" != 'false' ]; then
    if is_lint; then
        list '*.toml' | while read -r file; do
            printf "## tomljson %s ##\n" "$file" >&2
            tomljson "$file" >/dev/null
        done
    fi
fi

if [ -z "${VALIDATE_DOTENV+x}" ] || [ "$VALIDATE_DOTENV" != 'false' ]; then
    if is_lint; then
        list '*.env' | while read -r file; do
            printf "## dotenv-linter %s ##\n" "$file" >&2
            dotenv-linter --quiet "$file"
        done
    fi
fi

## CI ##

if [ -z "${VALIDATE_GITLAB_LINT+x}" ] || [ "$VALIDATE_GITLAB_LINT" != 'false' ]; then
    if is_lint; then
        list '.gitlab-ci.yml' | while read -r file; do
            printf "## gitlab-ci-lint %s ##\n" "$file" >&2
            gitlab-ci-lint "$file"
        done
    fi
fi

if [ -z "${VALIDATE_GITLAB_VALIDATE+x}" ] || [ "$VALIDATE_GITLAB_VALIDATE" != 'false' ]; then
    if is_lint; then
        list '.gitlab-ci.yml' | while read -r file; do
            printf "## gitlab-ci-validate %s ##\n" "$file" >&2
            gitlab-ci-validate validate "$file"
        done
    fi
fi

if [ -z "${VALIDATE_CIRCLE_VALIDATE+x}" ] || [ "$VALIDATE_CIRCLE_VALIDATE" != 'false' ]; then
    if is_lint; then
        list '.circleci/config.yml' | while read -r file; do
            printf "## circleci-validate %s ##\n" "$file" >&2
            if ! (cd "$(dirname "$(dirname "$file")")" && circleci --skip-update-check config validate >"$logfile" 2>&1); then
                cat "$logfile"
                exit 1
            fi
        done
    fi
fi

if [ -z "${VALIDATE_TRAVIS_LINT+x}" ] || [ "$VALIDATE_TRAVIS_LINT" != 'false' ]; then
    if is_lint; then
        list '.travis.yml' | while read -r file; do
            printf "## travis-lint %s ##\n" "$file" >&2
            (cd "$(dirname "$file")" && travis lint --no-interactive --skip-version-check --skip-completion-check --exit-code --quiet)
        done
    fi
fi

## Build tools ##

if [ -z "${VALIDATE_GMAKE+x}" ] || [ "$VALIDATE_GMAKE" != 'false' ]; then
    if is_lint; then
        list 'makefile' 'Makefile' '*.make' 'GNUMakefile' | while read -r file; do
            printf "## gmake %s ##\n" "$file" >&2
            make --dry-run --file="$file" >/dev/null
        done
    fi
fi

if [ -z "${VALIDATE_BMAKE+x}" ] || [ "$VALIDATE_BMAKE" != 'false' ]; then
    if is_lint; then
        list 'makefile' 'Makefile' '*.make' 'BSDMakefile' | while read -r file; do
            printf "## bmake %s ##\n" "$file" >&2
            make -n -f "$file" >/dev/null
        done
    fi
fi

if [ -z "${VALIDATE_CHECKMAKE+x}" ] || [ "$VALIDATE_CHECKMAKE" != 'false' ]; then
    if is_lint; then
        list 'makefile' 'Makefile' '*.make' 'GNUMakefile' 'BSDMakefile' | while read -r file; do
            printf "## checkmake %s ##\n" "$file" >&2
            checkmake "$file" >"$logfile" 2>&1 || { cat "$logfile" && exit 1; }
        done
    fi
fi

if [ -z "${VALIDATE_DOCKERFILELINT+x}" ] || [ "$VALIDATE_DOCKERFILELINT" != 'false' ]; then
    if is_lint; then
        list 'Dockerfile' '*.Dockerfile' | while read -r file; do
            printf "## dockerfilelint %s ##\n" "$file" >&2
            dockerfilelint "$file" >"$logfile" 2>&1 || { cat "$logfile" && exit 1; }
        done
    fi
fi

if [ -z "${VALIDATE_HADOLINT+x}" ] || [ "$VALIDATE_HADOLINT" != 'false' ]; then
    if is_lint; then
        list 'Dockerfile' '*.Dockerfile' | while read -r file; do
            printf "## hadolint %s ##\n" "$file" >&2
            hadolint "$file"
        done
    fi
fi

## Markup (XML, HTML, SVG, CSS) ##

if [ -z "${VALIDATE_XMLLINT+x}" ] || [ "$VALIDATE_XMLLINT" != 'false' ]; then
    list '*.xml' | while read -r file; do
        printf "## xmllint %s ##\n" "$file" >&2
        if is_lint; then
            xmllint --noout "$file"
        else
            xmllint --format --output "$file" "$file"
        fi
    done
fi

if [ -z "${VALIDATE_HTMLLINT+x}" ] || [ "$VALIDATE_HTMLLINT" != 'false' ]; then
    if is_lint && [ -e '.htmllintrc' ]; then
        list '*.html' '*.htm' | while read -r file; do
            printf "## htmllint %s ##\n" "$file" >&2
            htmllint "$file"
        done
    fi
fi

if [ -z "${VALIDATE_HTMLHINT+x}" ] || [ "$VALIDATE_HTMLHINT" != 'false' ]; then
    if is_lint && [ -e '.htmlhintrc' ]; then
        list '*.html' '*.htm' | while read -r file; do
            printf "## htmlhint %s ##\n" "$file" >&2
            htmlhint "$file"
        done
    fi
fi

if [ -z "${VALIDATE_SVGLINT+x}" ] || [ "$VALIDATE_SVGLINT" != 'false' ]; then
    if is_lint && [ -e '.svglintrc.js' ]; then
        list '*.svg' | while read -r file; do
            printf "## svglint %s ##\n" "$file" >&2
            svglint --ci "$file"
        done
    fi
fi

if [ -z "${VALIDATE_PRETTIER+x}" ] || [ "$VALIDATE_PRETTIER" != 'false' ]; then
    list '*.html' '*.htm' '*.xhtml' '*.css' '*.scss' '*.sass' | while read -r file; do
        printf "## prettier %s ##\n" "$file" >&2
        if is_lint; then
            prettier --list-different "$file"
        else
            prettier --loglevel error --write "$file"
        fi
    done
fi

## Documentation (Markdown, TeX, RST) ##

if [ -z "${VALIDATE_PRETTIER+x}" ] || [ "$VALIDATE_PRETTIER" != 'false' ]; then
    list '*.md' | while read -r file; do
        printf "## prettier %s ##\n" "$file" >&2
        if is_lint; then
            prettier --list-different "$file"
        else
            prettier --loglevel error --write "$file"
        fi
    done
fi

if [ -z "${VALIDATE_MARKDOWNLINT+x}" ] || [ "$VALIDATE_MARKDOWNLINT" != 'false' ]; then
    list '*.md' | while read -r file; do
        printf "## markdownlint %s ##\n" "$file" >&2
        if is_lint; then
            markdownlint "$file"
        else
            markdownlint --fix "$file" || true
        fi
    done
fi

if [ -z "${VALIDATE_MDL+x}" ] || [ "$VALIDATE_MDL" != 'false' ]; then
    if is_lint && [ -e '.mdlrc' ]; then
        list '*.md' | while read -r file; do
            printf "## mdl %s ##\n" "$file" >&2
            mdl "$file" --config .mdlrc
        done
    fi
fi

if [ -z "${VALIDATE_MARKDOWN_LINK_CHECK+x}" ] || [ "$VALIDATE_MARKDOWN_LINK_CHECK" != 'false' ]; then
    if is_lint && [ -e '.markdown-link-check.json' ]; then
        list '*.md' | while read -r file; do
            printf "## markdown-link-check %s ##\n" "$file" >&2
            markdown-link-check --quiet --config '.markdown-link-check.json' --retry "$file" >"$logfile" 2>&1 || { cat "$logfile" && exit 1; }
        done
    fi
fi

## Shell ##

if [ -z "${VALIDATE_BASHATE+x}" ] || [ "$VALIDATE_BASHATE" != 'false' ]; then
    if is_lint; then
        list '*.sh' '*.bash' '*.ksh' '*.ash' '*.dash' '*.yash' | while read -r file; do
            printf "## bashate %s ##\n" "$file" >&2
            bashate --ignore E001,E002,E003,E004,E005,E006 "$file" # ignore all whitespace/basic errors
        done
    fi
fi

if [ -z "${VALIDATE_SHFMT+x}" ] || [ "$VALIDATE_SHFMT" != 'false' ]; then
    list '*.sh' '*.bash' '*.ksh' '*.ash' '*.dash' '*.yash' | while read -r file; do
        printf "## shfmt %s ##\n" "$file" >&2
        if is_lint; then
            shfmt -l -d "$file"
        else
            shfmt -w "$file"
        fi
    done
fi

if [ -z "${VALIDATE_SHELLHARDEN+x}" ] || [ "$VALIDATE_SHELLHARDEN" != 'false' ]; then
    list '*.sh' '*.bash' '*.ksh' '*.ash' '*.dash' '*.zsh' '*.yash' '*.bats' | while read -r file; do
        printf "## shellharden %s ##\n" "$file" >&2
        if is_lint; then
            shellharden --check --suggest -- "$file" >"$logfile" 2>&1 || { cat "$logfile" && exit 1; }
        else
            shellharden --replace -- "$file"
        fi
    done
fi

if [ -z "${VALIDATE_SHELLCHECK+x}" ] || [ "$VALIDATE_SHELLCHECK" != 'false' ]; then
    if is_lint; then
        list '*.sh' '*.bash' '*.ksh' '*.ash' '*.dash' '*.zsh' '*.yash' '*.bats' | while read -r file; do
            printf "## shellcheck %s ##\n" "$file" >&2
            shellcheck --external-sources "$file"
        done
    fi
fi

if [ -z "${VALIDATE_BATS+x}" ] || [ "$VALIDATE_BATS" != 'false' ]; then
    if is_lint; then
        list '*.bats' | while read -r file; do
            printf "## bats %s ##\n" "$file" >&2
            bats --count "$file" >/dev/null
        done
    fi
fi

## Python ##

if [ -z "${VALIDATE_AUTOPEP8+x}" ] || [ "$VALIDATE_AUTOPEP8" != 'false' ]; then
    list '*.py' | while read -r file; do
        printf "## autopep8 %s ##\n" "$file" >&2
        if is_lint; then
            autopep8 --diff "$file"
        else
            autopep8 --in-place "$file"
        fi
    done
fi

if [ -z "${VALIDATE_PYCODESTYLE+x}" ] || [ "$VALIDATE_PYCODESTYLE" != 'false' ]; then
    if is_lint; then
        list '*.py' | while read -r file; do
            printf "## pycodestyle %s ##\n" "$file" >&2
            pycodestyle --quiet --quiet "$file"
        done
    fi
fi

if [ -z "${VALIDATE_FLAKE8+x}" ] || [ "$VALIDATE_FLAKE8" != 'false' ]; then
    if is_lint; then
        list '*.py' | while read -r file; do
            printf "## flake8 %s ##\n" "$file" >&2
            flake8 --quiet --quiet "$file"
        done
    fi
fi

if [ -z "${VALIDATE_ISORT+x}" ] || [ "$VALIDATE_ISORT" != 'false' ]; then
    list '*.py' | while read -r file; do
        printf "## isort %s ##\n" "$file" >&2
        if is_lint; then
            isort --honor-noqa --check-only --diff "$file"
        else
            isort --honor-noqa "$file"
        fi
    done
fi

if [ -z "${VALIDATE_PYLINT+x}" ] || [ "$VALIDATE_PYLINT" != 'false' ]; then
    if is_lint; then
        list '*.py' | while read -r file; do
            printf "## pylint %s ##\n" "$file" >&2
            # doesn't have --quiet mode
            pylint "$file" >"$logfile" 2>&1 || { cat "$logfile" && exit 1; }
        done
    fi
fi

if [ -z "${VALIDATE_BLACK+x}" ] || [ "$VALIDATE_BLACK" != 'false' ]; then
    list '*.py' | while read -r file; do
        printf "## black %s ##\n" "$file" >&2
        if is_lint; then
            black --check --diff --quiet "$file"
        else
            black --quiet "$file"
        fi
    done
fi

rm -f "$logfile"
