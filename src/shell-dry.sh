#!/bin/sh
set -euf

# extracts the shell from given file
# uses shebang or extension
detect_shell() {
    file="$1"
    shebang="$(head -n1 "$file")"

    if printf '%s' "$shebang" | grep -E '^#!' >/dev/null; then
        shebang_shell="$(printf '%s' "$shebang" | cut -d ' ' -f 1 | rev | cut -d '/' -f 1 | rev)"
        if [ "$shebang_shell" = 'env' ]; then
            # in this case the shell is the 2. argument, such as `#!/usr/bin/env bash` -> bash
            printf '%s' "$shebang" | cut -d ' ' -f 2 | rev | cut -d '/' -f 1 | rev
        else
            # in this case the first argument is the shell, such as `#!/bin/sh` -> sh
            printf '%s' "$shebang_shell"
        fi
    else
        # in this case the file does not start with a shebang
        extension="$(printf '%s' "$file" | rev | cut -d '.' -f 1 | rev)"
        printf '%s' "$extension"
    fi
}

check_file() {
    file="$1"
    shell="$(detect_shell "$file")"
    printf 'Detected %s as %s\n' "$file" "$shell" >&2

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
    elif [ "$shell" = bash ]; then
        check_bash "$file"
    elif [ "$shell" = zsh ]; then
        check_zsh "$file"
    fi
}

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
}

check_bash() {
    bash -n "$file"
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
