#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

accesslist="$(mktemp)"
sort </app/brew-list.txt | uniq >"$accesslist"

# Remove all files not found in access log
find /home/linuxbrew -type f | while read -r file; do
    file_found=1
    grep -- "$file" <"$accesslist" || file_found=0
    if [ "$file_found" -eq 0 ]; then
        rm -f "$file"
    fi
done

find /home/linuxbrew -type d \( \
    -name .bundle -or \
    -name .devcontainer -or \
    -name .git -or \
    -name .github -or \
    -name .sublime -or \
    -name .vscode -or \
    -name dev-cmd -or \
    -name docs -or \
    -name etc -or \
    -name html -or \
    -name mac -or \
    -name manpages -or \
    -name rubocops -or \
    -name share -or \
    -name shared -or \
    -name spec -or \
    -name test -or \
    -name yard \
    \) -prune -exec rm -rf {} \;

removeEmptyDirectories /home/linuxbrew

# Cleanup tmpfile
rm -f "$accesslist"
