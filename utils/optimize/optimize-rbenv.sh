#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

# These files are accessed, but unecessary anyway
find /.rbenv/versions -type f -name '*.gemspec' -delete

# Remove all files not found in access log
accesslist="$(mktemp)"
sort </app/rbenv-list.txt | uniq >"$accesslist"
find /.rbenv/versions -type f | while read -r file; do
    file_found=1
    grep -- "$file" <"$accesslist" || file_found=0
    if [ "$file_found" -eq 0 ]; then
        rm -f "$file"
    fi
done
rm -f "$accesslist"

removeEmptyDirectories /.rbenv/versions

