#!/bin/sh
set -euf

if [ "$#" -lt 1 ]; then
    printf 'Not enough arguments. Expected file.\n' >&2
    exit 1
fi
file="$1"

# shellcheck source=src/shell-dry-run-utils.sh
. "$(dirname "$0")/shell-dry-run-utils.sh"

check_sh() {
    sh -n "$file"
    bash --posix -n "$file"
    bash -o posix -n "$file"
    yash --posix -n "$file"
    yash -o posixly-correct -n "$file"
}

check_ksh() {
    ksh -n "$file"
    mksh -n "$file"
    ksh93 -n "$file"
    loksh -n "$file"
}

check_bash() {
    bash -n "$file"
    zsh -n "$file"
}

check_zsh() {
    zsh -n "$file"
}

check_yash() {
    yash -n "$file"
}

check_dash() {
    if [ "$(uname -s)" != 'Darwin' ]; then
        ash -n "$file"
    fi
    dash -n "$file"
}

shell="$(detect_shell "$file")"
printf 'Detected %s as %s\n' "$file" "$shell" >&2
# TODO: check with posh

if [ "$shell" = sh ] || [ "$shell" = yash ] || [ "$shell" = dash ] || [ "$shell" = ash ] || [ "$shell" = posh ] || [ "$shell" = hush ]; then
    check_sh "$file"
    check_dash "$file"
    check_ksh "$file"
    check_bash "$file"
    check_zsh "$file"
    check_yash "$file"
elif [ "$shell" = ksh ] || [ "$shell" = mksh ] || [ "$shell" = pdksh ] || [ "$shell" = oksh ] || [ "$shell" = loksh ]; then
    check_ksh "$file"
    check_bash "$file"
    check_zsh "$file"
elif [ "$shell" = bash ] || [ "$shell" = '' ]; then
    check_bash "$file"
elif [ "$shell" = zsh ]; then
    check_zsh "$file"
fi
