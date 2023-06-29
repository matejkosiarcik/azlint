#!/bin/sh
set -euf
export PATH="/src/node_modules/.bin:/usr/local/bundle/bin:$PATH"
export GEM_HOME='/usr/local/bundle'

if [ "$#" -lt 2 ]; then
    printf 'Not enough arguments\n' >&2
    exit 1
fi

logfile="$(mktemp)"
mode="$1"
projectlist="$2"
glob="$(dirname "$0")/glob_files.py"
# shellcheck disable=SC2139
alias list="$glob $projectlist"

# shellcheck source=./src/shell-dry.sh
. "$(dirname "$0")/shell-dry.sh"

if [ "$mode" = 'lint' ]; then
    _is_lint=0
else
    _is_lint=1
fi
is_lint() {
    return "$_is_lint"
}

status_file="$(mktemp)"
printf '0' >"$status_file"

## General files ##

if [ "${VALIDATE_EDITORCONFIG+x}" = "" ] || [ "$VALIDATE_EDITORCONFIG" != 'false' ]; then
    if is_lint; then
        list '*' | while read -r file; do
            printf "## editorconfig-checker %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            ec "$file" || printf '1' >"$status_file"
        done
    fi
fi

if [ "${VALIDATE_GITIGNORE+x}" = "" ] || [ "$VALIDATE_GITIGNORE" != 'false' ]; then
    if [ -d ".git" ]; then
        list '*' | while read -r file; do
            printf "## git-check-ignore %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            if is_lint; then
                if git check-ignore --no-index "$file" >/dev/null; then
                    printf 'File %s should be ignored\n' "$file"
                    printf '1' >"$status_file"
                fi
            else
                if git check-ignore --no-index "$file" >/dev/null; then
                    git rm --cached "$file"
                fi
            fi
        done
    fi
fi

## General configs (JSON, YAML, TOML, ENV, etc.) ##

# TODO: Reenable jsonlint
# list '*.{json,json5,jsonl,geojson}' '*.{htmlhintrc,htmllintrc,babelrc,jscsrc,jshintrc,jslintrc,ecrc,remarkrc}' | while read -r file; do
#     if [ -z "${VALIDATE_JSONLINT+x}" ] || [ "$VALIDATE_JSONLINT" != 'false' ]; then
#         printf "## jsonlint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
#         if is_lint; then
#             jsonlint --quiet --comments --no-duplicate-keys "$file" || printf '1' >"$status_file"
#         else
#             jsonlint --in-place --quiet --comments --enforce-double-quotes --trim-trailing-commas "$file"
#             if [ "$(tail -c 1 <"$file")" != "$(printf '\n')" ]; then
#                 printf '\n' >>"$file" # jsonlint omits final newline
#             fi
#         fi
#     fi
# done

if [ "${VALIDATE_PRETTIER+x}" = "" ] || [ "$VALIDATE_PRETTIER" != 'false' ]; then
    list '*.{json,json5,yml,yaml,html,vue,css,scss,sass,less}' | while read -r file; do
        printf "## prettier %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            prettier --list-different "$file" || printf '1' >"$status_file"
        else
            prettier --loglevel warn --write "$file"
        fi
    done
fi

if [ "${VALIDATE_YAMLLINT+x}" = "" ] || [ "$VALIDATE_YAMLLINT" != 'false' ]; then
    if is_lint; then
        list '*.{yml,yaml}' | while read -r file; do
            printf "## yamllint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            yamllint --strict "$file" || printf '1' >"$status_file"
        done
    fi
fi

if [ "${VALIDATE_PACKAGE_JSON+x}" = "" ] || [ "$VALIDATE_PACKAGE_JSON" != 'false' ]; then
    if is_lint; then
        list 'package.json' | while read -r file; do
            # only validate non-private package.json
            if [ "$(jq .private <"$file")" != 'true' ]; then
                printf "## package-json-validator %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
                pjv --warnings --recommendations --filename "$file" || printf '1' >"$status_file"
            fi
        done
    fi
fi

list 'composer.json' | while read -r file; do
    if [ "${VALIDATE_COMPOSER_VALIDATE+x}" = "" ] || [ "$VALIDATE_COMPOSER_VALIDATE" != 'false' ]; then
        if is_lint; then
            printf "## composer-validate %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            composer validate --no-interaction --no-cache --ansi --no-check-all --no-check-publish "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi

    if [ "${VALIDATE_COMPOSER_NORMALIZE+x}" = "" ] || [ "$VALIDATE_COMPOSER_NORMALIZE" != 'false' ]; then
        printf "## composer-normalize %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        composerfile="$PWD/$file"
        if is_lint; then
            if ! (cd /src && composer normalize --no-interaction --no-cache --ansi --dry-run --diff "$composerfile" >"$logfile" 2>&1); then
                cat "$logfile"
                printf '1' >"$status_file"
            fi
        else
            (cd /src && composer normalize --no-interaction --no-cache --ansi "$composerfile")
        fi
    fi
done

if [ "${VALIDATE_TOMLJSON+x}" = "" ] || [ "$VALIDATE_TOMLJSON" != 'false' ]; then
    if is_lint; then
        list '*.toml' | while read -r file; do
            printf "## tomljson %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            tomljson "$file" >/dev/null || printf '1' >"$status_file"
        done
    fi
fi

if [ "${VALIDATE_DOTENV+x}" = "" ] || [ "$VALIDATE_DOTENV" != 'false' ]; then
    if is_lint; then
        list '*.env' | while read -r file; do
            printf "## dotenv-linter %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            dotenv-linter --quiet "$file" || printf '1' >"$status_file"
        done
    fi
fi

## CI configs ##

list '.gitlab-ci.yml' | while read -r file; do
    if [ "${VALIDATE_GITLAB_LINT+x}" = "" ] || [ "$VALIDATE_GITLAB_LINT" != 'false' ]; then
        if is_lint; then
            printf "## gitlab-ci-lint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            gitlab-ci-lint "$file" || printf '1' >"$status_file"
        fi
    fi

    if [ "${VALIDATE_GITLAB_VALIDATE+x}" = "" ] || [ "$VALIDATE_GITLAB_VALIDATE" != 'false' ]; then
        if is_lint; then
            printf "## gitlab-ci-validate %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            gitlab-ci-validate validate "$file" || printf '1' >"$status_file"
        fi
    fi
done

if [ "${VALIDATE_CIRCLE_VALIDATE+x}" = "" ] || [ "$VALIDATE_CIRCLE_VALIDATE" != 'false' ]; then
    if is_lint; then
        list '.circleci/config.yml' | while read -r file; do
            printf "## circleci-validate %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            if ! (cd "$(dirname "$(dirname "$file")")" && circleci --skip-update-check config validate >"$logfile" 2>&1); then
                cat "$logfile"
                printf '1' >"$status_file"
            fi
        done
    fi
fi

if [ "${VALIDATE_TRAVIS_LINT+x}" = "" ] || [ "$VALIDATE_TRAVIS_LINT" != 'false' ]; then
    if is_lint; then
        list '.travis.yml' | while read -r file; do
            printf "## travis-lint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            (cd "$(dirname "$file")" && travis lint --no-interactive --skip-version-check --skip-completion-check --exit-code --quiet) || printf '1' >"$status_file"
        done
    fi
fi

## Markup (XML, HTML, SVG, CSS) ##

if [ "${VALIDATE_XMLLINT+x}" = "" ] || [ "$VALIDATE_XMLLINT" != 'false' ]; then
    list '*.xml' | while read -r file; do
        printf "## xmllint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            xmllint --noout "$file" || printf '1' >"$status_file"
        else
            xmllint --format --output "$file" "$file"
        fi
    done
fi

list '*.{html,htm,xhtml}' | while read -r file; do
    if [ "${VALIDATE_HTMLLINT+x}" = "" ] || [ "$VALIDATE_HTMLLINT" != 'false' ]; then
        if is_lint && [ -e '.htmllintrc' ]; then
            printf "## htmllint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            htmllint "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi

    if [ "${VALIDATE_HTMLHINT+x}" = "" ] || [ "$VALIDATE_HTMLHINT" != 'false' ]; then
        if is_lint && [ -e '.htmlhintrc' ]; then
            printf "## htmlhint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            htmlhint "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi
done

if [ "${VALIDATE_SVGLINT+x}" = "" ] || [ "$VALIDATE_SVGLINT" != 'false' ]; then
    if is_lint && [ -e '.svglintrc.js' ]; then
        list '*.svg' | while read -r file; do
            printf "## svglint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            svglint --ci "$file" || printf '1' >"$status_file"
        done
    fi
fi

## Make ##

if [ "${VALIDATE_CHECKMAKE+x}" = "" ] || [ "$VALIDATE_CHECKMAKE" != 'false' ]; then
    if is_lint; then
        list '*{makefile,Makefile}' '*.make' | while read -r file; do
            printf "## checkmake %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            checkmake "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        done
    fi
fi

if [ "${VALIDATE_GMAKE+x}" = "" ] || [ "$VALIDATE_GMAKE" != 'false' ]; then
    if is_lint; then
        list '{,GNU}{makefile,Makefile}' '*.make' | while read -r file; do
            printf "## gmake %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            make --dry-run --file="$file" >/dev/null || printf '1' >"$status_file"
        done
    fi
fi

if [ "${VALIDATE_BMAKE+x}" = "" ] || [ "$VALIDATE_BMAKE" != 'false' ]; then
    if is_lint; then
        list '{,BSD}{makefile,Makefile}' '*.make' | while read -r file; do
            printf "## bmake %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            make -n -f "$file" >/dev/null || printf '1' >"$status_file"
        done
    fi
fi

## Docker ##

list 'Dockerfile' '*.Dockerfile' | while read -r file; do
    if [ "${VALIDATE_DOCKERFILELINT+x}" = "" ] || [ "$VALIDATE_DOCKERFILELINT" != 'false' ]; then
        if is_lint; then
            printf "## dockerfilelint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            dockerfilelint "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi

    if [ "${VALIDATE_HADOLINT+x}" = "" ] || [ "$VALIDATE_HADOLINT" != 'false' ]; then
        if is_lint; then
            printf "## hadolint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            hadolint "$file" || printf '1' >"$status_file"
        fi
    fi
done

## Documentation (Markdown, TeX, RST) ##

list '*.{md,mdown,markdown}' | while read -r file; do
    # TODO: Reenable markdownlint
    # if [ -z "${VALIDATE_MARKDOWNLINT+x}" ] || [ "$VALIDATE_MARKDOWNLINT" != 'false' ]; then
    #     printf "## markdownlint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
    #     if is_lint; then
    #         markdownlint "$file" || printf '1' >"$status_file"
    #     else
    #         markdownlint --fix "$file" || true
    #     fi
    # fi

    if [ "${VALIDATE_MDL+x}" = "" ] || [ "$VALIDATE_MDL" != 'false' ]; then
        if is_lint && [ -e '.mdlrc' ]; then
            printf "## mdl %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            mdl "$file" --config .mdlrc || printf '1' >"$status_file"
        fi
    fi

    if [ "${VALIDATE_MARKDOWN_LINK_CHECK+x}" = "" ] || [ "$VALIDATE_MARKDOWN_LINK_CHECK" != 'false' ]; then
        if is_lint && [ -e '.markdown-link-check.json' ]; then
            printf "## markdown-link-check %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            markdown-link-check --quiet --config '.markdown-link-check.json' --retry "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi
done

## Shell ##

if [ "${VALIDATE_BASHATE+x}" = "" ] || [ "$VALIDATE_BASHATE" != 'false' ]; then
    if is_lint; then
        list '*.{sh,bash,ksh,mksh,ash,dash,zsh,yash}' | while read -r file; do
            printf "## bashate %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            bashate --ignore E001,E002,E003,E004,E005,E006 "$file" || printf '1' >"$status_file" # ignore all whitespace/basic errors
        done
    fi
fi

if [ "${VALIDATE_SHFMT+x}" = "" ] || [ "$VALIDATE_SHFMT" != 'false' ]; then
    list '*.{sh,bash,ksh,ash,dash,zsh,yash}' | while read -r file; do
        printf "## shfmt %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            shfmt -l -d "$file" || printf '1' >"$status_file"
        else
            shfmt -w "$file"
        fi
    done
fi

if [ "${VALIDATE_SHELLHARDEN+x}" = "" ] || [ "$VALIDATE_SHELLHARDEN" != 'false' ]; then
    list '*.{sh,bash,ksh,ash,dash,zsh,yash}' | while read -r file; do
        printf "## shellharden %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            shellharden --check --suggest -- "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        else
            shellharden --replace -- "$file"
        fi
    done
fi

if [ "${VALIDATE_SHELLCHECK+x}" = "" ] || [ "$VALIDATE_SHELLCHECK" != 'false' ]; then
    if is_lint; then
        list '*.{sh,bash,ksh,ash,dash,zsh,yash,bats}' | while read -r file; do
            printf "## shellcheck %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            shellcheck --external-sources "$file" || printf '1' >"$status_file"
        done
    fi
fi

if [ "${VALIDATE_BATS+x}" = "" ] || [ "$VALIDATE_BATS" != 'false' ]; then
    if is_lint; then
        list '*.bats' | while read -r file; do
            printf "## bats %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            bats --count "$file" >/dev/null || printf '1' >"$status_file"
        done
    fi
fi

if [ "${VALIDATE_SHELL_DRY+x}" = "" ] || [ "$VALIDATE_SHELL_DRY" != 'false' ]; then
    if is_lint; then
        list '*.{sh,bash,ksh,mksh,ash,dash,zsh,yash}' | while read -r file; do
            printf "## shell-dry %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            check_file "$file" || printf '1' >"$status_file"
        done
    fi
fi

## Python ##

list '*.py' | while read -r file; do
    if [ "${VALIDATE_AUTOPEP8+x}" = "" ] || [ "$VALIDATE_AUTOPEP8" != 'false' ]; then
        printf "## autopep8 %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            autopep8 --diff "$file" || printf '1' >"$status_file"
        else
            autopep8 --in-place "$file"
        fi
    fi

    if [ "${VALIDATE_PYCODESTYLE+x}" = "" ] || [ "$VALIDATE_PYCODESTYLE" != 'false' ]; then
        if is_lint; then
            printf "## pycodestyle %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            pycodestyle --quiet --quiet "$file" || printf '1' >"$status_file"
        fi
    fi

    if [ "${VALIDATE_FLAKE8+x}" = "" ] || [ "$VALIDATE_FLAKE8" != 'false' ]; then
        if is_lint; then
            printf "## flake8 %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            flake8 --quiet --quiet "$file" || printf '1' >"$status_file"
        fi
    fi

    if [ "${VALIDATE_ISORT+x}" = "" ] || [ "$VALIDATE_ISORT" != 'false' ]; then
        printf "## isort %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            isort --honor-noqa --check-only --diff "$file" || printf '1' >"$status_file"
        else
            isort --honor-noqa "$file"
        fi
    fi

    if [ "${VALIDATE_PYLINT+x}" = "" ] || [ "$VALIDATE_PYLINT" != 'false' ]; then
        if is_lint; then
            printf "## pylint %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            # doesn't have --quiet mode
            pylint "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi

    if [ "${VALIDATE_MYPY+x}" = "" ] || [ "$VALIDATE_MYPY" != 'false' ]; then
        if is_lint; then
            printf "## mypy %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
            mypy --follow-imports skip "$file" >"$logfile" 2>&1 || { cat "$logfile" && printf '1' >"$status_file"; }
        fi
    fi

    if [ "${VALIDATE_BLACK+x}" = "" ] || [ "$VALIDATE_BLACK" != 'false' ]; then
        printf "## black %b%s%b ##\n" '\033[36m' "$file" '\033[0m' >&2
        if is_lint; then
            black --check --diff --quiet "$file" || printf '1' >"$status_file"
        else
            black --quiet "$file"
        fi
    fi
done

## Finish ##

status_code="$(cat "$status_file")"
rm -f "$logfile"
exit "$status_code"
