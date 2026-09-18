#!/bin/sh

# extracts the shell from given file
# uses shebang and extension
# `bash` is returned as fallback if neither succeed
detect_shell() {
    file="$1"
    shebang="$(head -n1 "$file")"

    if printf '%s' "$shebang" | grep -E '^#!' >/dev/null; then
        shebang_shell="$(printf '%s' "$shebang" | cut -d ' ' -f 1 | rev | cut -d '/' -f 1 | rev)"
        if [ "$shebang_shell" = 'env' ]; then
            # in this case the shell is the 2. argument, such as `#!/usr/bin/env bash` -> bash
            printf '%s\n' "$shebang" | cut -d ' ' -f 2 | rev | cut -d '/' -f 1 | rev
        else
            # in this case the first argument is the shell, such as `#!/bin/sh` -> sh
            printf '%s\n' "$shebang_shell"
        fi
    elif printf '%s' "$file" | grep '.' >/dev/null 2>&1; then
        # in this case the file does not start with a shebang
        extension="$(printf '%s' "$file" | rev | cut -d '.' -f 1 | rev)"
        printf '%s\n' "$extension"
    else
        printf 'bash\n'
    fi
}
