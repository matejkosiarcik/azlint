#!/bin/sh
set -euf

### Remove directories ###

find node_modules -type d \( \
    -iname 'test' -or \
    -iname 'tests' -or \
    -iname '__test__' -or \
    -iname '__tests__' -or \
    -iname 'man' -or \
    -iname 'snapshots' -or \
    -iname '__snapshots__' \
    \) -prune -exec rm -rf {} \;

find node_modules -type d -not -path '*/markdown-table-prettify/*' \( \
    -iname 'doc' -or \
    -iname 'docs' \
    \) -prune -exec rm -rf {} \;

# OS specific directories (non-Linux)
find node_modules -type d \( \
    -iname 'mac' -or \
    -iname 'macos' -or \
    -iname 'win' -or \
    -iname 'windows' \
    \) -prune -exec rm -rf {} \;

### Remove files ###

# Unused yargs locales
find node_modules -ipath '*/locale*/*' -iname '*.json' -not -iname 'en*.json' -delete

# System files
find node_modules -type f \( \
    -iname '*~' -or \
    -iname '.DS_Store' \
    \) -delete

# Config files:
# - dockerignore, gitignore, npmignore, ...
# - .prettierrc, .eslintrc, ...
# - .prettierrc.json, .prettierrc.yml, ...
# - .gitconfig, .gitattributes, .gitmodules, .gitkeep, ...
find node_modules -type f \( \
    -iname '*.*ignore' -or \
    -iname '*.*rc' -or \
    -iname '*.*rc.*' -or \
    -iname '*.git*' \
    \) -delete

# Docs
find node_modules -type f \( \
    -iname 'AUTHORS' -or \
    -iname 'AUTHORS.*' -or \
    -iname 'CHANGELOG' -or \
    -iname 'CHANGELOG.*' -or \
    -iname 'HISTORY' -or \
    -iname 'HISTORY.*' -or \
    -iname 'LICENSE' -or \
    -iname 'LICENSE.*' -or \
    -name 'LICENSE-*' -or \
    -iname 'README' -or \
    -iname 'README.*' -or \
    -iname '*.latex' -or \
    -iname '*.markdown' -or \
    -iname '*.md' -or \
    -iname '*.mdown' -or \
    -iname '*.rst' -or \
    -iname '*.tex' -or \
    -iname '*.text' -or \
    -iname '*.txt' \
    \) -delete

# Images
find node_modules -type f \( \
    -iname '*.jpeg' -or \
    -iname '*.jpg' -or \
    -iname '*.apng' -or \
    -iname '*.png' -or \
    -iname '*.svg' \
    \) -delete

# HTML
find node_modules -type f \( \
    -iname '*.css' -or \
    -iname '*.htm' -or \
    -iname '*.html' -or \
    -iname '*.less' -or \
    -iname '*.sass' -or \
    -iname '*.scss' -or \
    -iname '*.xhtml' \
    \) -delete

# JS preprocessors left unprocessed
find node_modules -type f \( \
    -iname '*.coffee' -or \
    -iname '*.ts' -or \
    -iname '*.flow' -or \
    -iname '*.tsbuildinfo' \
    \) -delete

# CSS
find node_modules -type f \( \
    -iname '*.css' -or \
    -iname '*.less' -or \
    -iname '*.sass' \
    \) -delete

# Other languages
find node_modules -type f \( \
    -iname '*.py' -or \
    -iname '*.py-js' \
    \) -delete

# Misc
find node_modules -type f \( \
    -iname 'Jenkinsfile' -or \
    -iname 'Makefile' -or \
    -iname 'Dockerfile' -or \
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
    -iname '*.tm_properties' -or \
    -iname '*.xml' -or \
    -iname '*.yaml' -or \
    -iname '*.yml' \
    \) -delete

# Other languages
find node_modules -type f -not -path '*/bats/*' -not -path '*/bats-core/*' \( \
    -iname '*.sh' -or \
    -iname '*.bash' \
    \) -delete

# Remove leftover empty directories
find node_modules -type d -empty -prune -exec rm -rf {} \;

### Minification ###

# Minify JSON
find node_modules -iname '*.json' | while read -r file; do jq -r tostring <"$file" | sponge "$file"; done
