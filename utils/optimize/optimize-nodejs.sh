#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies node_modules

# lockfiles
find node_modules -type f \( \
    -iname 'package-lock.json' -or \
    -iname '*.lock' \
    \) -delete

# Unused yargs locales
find node_modules -ipath '*/locale*/*' -iname '*.json' -not -iname 'en*.json' -delete

# JS preprocessors left unprocessed
find node_modules -type f \( \
    -iname '*.coffee' -or \
    -iname '*.ts' -or \
    -iname '*.flow' -or \
    -iname '*.tsbuildinfo' \
    \) -delete

# Other languages
find node_modules -type f \( \
    -iname '*.py' -or \
    -iname '*.py-js' \
    \) -delete

# Misc
find node_modules -type f \( \
    -iname '*.bnf' -or \
    -iname '*.conf' -or \
    -iname '*.cts' -or \
    -iname '*.def' -or \
    -iname '*.editorconfig' -or \
    -iname '*.el' -or \
    -iname '*.env' -or \
    -iname '*.exe' -or \
    -iname '*.hbs' -or \
    -iname '*.iml' -or \
    -iname '*.in' -or \
    -iname '*.jst' -or \
    -iname '*.lock' -or \
    -iname '*.map' -or \
    -iname '*.mts' -or \
    -iname '*.mts' -or \
    -iname '*.ne' -or \
    -iname '*.nix' -or \
    -iname '*.patch' -or \
    -iname '*.properties' -or \
    -iname '*.targ' -or \
    -iname '*.tm_properties' \
    \) -delete

removeEmptyDirectories node_modules

### Minify files ###

minifyJsonFiles node_modules

# Remove extra keys from `package.json`s
find node_modules -iname 'package.json' | while read -r file; do
    jq -c '. | to_entries | map(select(.key | test("^(description|engine|engines|exports|imports|main|module|name|type|version)$"))) | from_entries' <"$file" | sponge "$file"
done

minifyYamlFiles node_modules
