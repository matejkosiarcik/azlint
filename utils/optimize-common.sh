#!/bin/sh
set -euf

### Directories ###

# Test directories
removeTestDirectories() {
    find "$1" -type d \( \
        -iname 'test' -or \
        -iname 'tests' -or \
        -iname '__test__' -or \
        -iname '__tests__' -or \
        -iname 'testutils' -or \
        -iname 'test-data' -or \
        -iname 'snapshots' -or \
        -iname '__snapshots__' \
        \) -prune -exec rm -rf {} \;
}

# VCS directories
removeVcsDirectories() {
    find "$1" -type d \( \
        -iname '.git' -or \
        -iname '.hg' \
        \) -prune -exec rm -rf {} \;
}

# CI/CD and Git-hosts directories
removeCiDirectories() {
    find "$1" -type d \( \
        -iname '.github' \
        \) -prune -exec rm -rf {} \;
}

# Documentation directories
removeDocsDirectories() {
    find "$1" -type d \( \
        -iname 'man' \
        -iname 'html' \
        \) -prune -exec rm -rf {} \;

    find "$1" -type d -not -path '*/markdown-table-prettify/*' \( \
        -iname 'doc' -or \
        -iname 'docs' \
        \) -prune -exec rm -rf {} \;
}

# OS specific directories (non-Linux)
removeNonLinuxOsDirectories() {
    find node_modules -type d \( \
        -iname 'mac' -or \
        -iname 'macos' -or \
        -iname 'win' -or \
        -iname 'windows' \
        \) -prune -exec rm -rf {} \;
}

# Remove leftover empty directories
removeEmptyDirectories() {
    find "$1" -type d -empty -prune -exec rm -rf {} \;
}

### Files ###

# System files
removeOsFiles() {
    find "$1" -type f \( \
        -iname '*~' -or \
        -iname '.DS_Store' \
        \) -delete
}

# Config files:
# - dockerignore, gitignore, npmignore, ...
# - .prettierrc, .eslintrc, ...
# - .prettierrc.json, .prettierrc.yml, ...
# - .gitconfig, .gitattributes, .gitmodules, .gitkeep, ...
removeLowLevelConfigFiles() {
    find "$1" -type f \( \
        -iname '*.*ignore' -or \
        -iname '*.*rc' -or \
        -iname '*.*rc.*' -or \
        -iname '*.git*' \
        \) -delete
}

# HTML
removeHtmlFiles() {
    find "$1" -type f \( \
        -iname '*.htm' -or \
        -iname '*.html' -or \
        -iname '*.html5' -or \
        -iname '*.xhtml' \
        \) -delete
}

# CSS
removeCssFiles() {
    find "$1" -type f \( \
        -iname '*.css' -or \
        -iname '*.less' -or \
        -iname '*.sass' -or \
        -iname '*.scss' \
        \) -delete
}

# Images
removeImageFiles() {
    find "$1" -type f \( \
        -iname '*.gif' -or \
        -iname '*.ico' -or \
        -iname '*.icon' -or \
        -iname '*.icns' -or \
        -iname '*.jpeg' -or \
        -iname '*.jpg' -or \
        -iname '*.apng' -or \
        -iname '*.png' -or \
        -iname '*.svg' -or \
        -iname '*.svgz' \
        \) -delete
}

# C/Cpp files
removeCppFiles() {
    find "$1" -type f \( \
        -iname '*.c' -or \
        -iname '*.cc' -or \
        -iname '*.cpp' -or \
        -iname '*.cxx' -or \
        -iname '*.c++' -or \
        -iname '*.h' -or \
        -iname '*.hh' -or \
        -iname '*.hpp' -or \
        -iname '*.hxx' -or \
        -iname '*.h++' \
        \) -delete
}

# Shell files
removeShellFiles() {
    find "$1" -type f \( \
        -iname '*.bat' -or \
        -iname '*.hush' -or \
        -iname '*.ksh' -or \
        -iname '*.loksh' -or \
        -iname '*.mksh' -or \
        -iname '*.oksh' -or \
        -iname '*.pdksh' -or \
        -iname '*.posh' -or \
        -iname '*.pwsh' -or \
        -iname '*.yash' -or \
        -iname '*.zsh' \
        \) -delete

    find "$1" -type f -not -path '*/bats/*' -not -path '*/bats-core/*' \( \
        -iname '*.bash' -or \
        -iname '*.sh' \
        \) -delete
}

# Markdown
removeMarkdownFiles() {
    find "$1" -type f \( \
        -iname 'README' -or \
        -iname 'README.*' -or \
        -iname '*.markdown' -or \
        -iname '*.md' -or \
        -iname '*.mdown' -or \
        \) -delete
}

### Minification ###

# Minify JSONs
minifyJsonFiles() {
    find "$1" -iname '*.json' | while read -r file; do
        jq -c '.' <"$file" | sponge "$file"
    done
}
