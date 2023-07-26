#!/bin/sh
set -euf

cleanDependencies() {
    # Test directories
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

    # VCS directories
    find "$1" -type d \( \
        -iname '.git' -or \
        -iname '.hg' \
        \) -prune -exec rm -rf {} \;

    # CI/CD and Git-hosts directories
    find "$1" -type d \( \
        -iname '.github' \
        \) -prune -exec rm -rf {} \;

    # Documentation directories
    find "$1" -type d \( \
        -iname 'html' -or \
        -iname 'man' \
        \) -prune -exec rm -rf {} \;
    find "$1" -type d -not -path '*/markdown-table-prettify/*' -iname 'doc' -prune -exec rm -rf {} \;
    find "$1" -type d -not -path '*/botocore/*' -not -path '*/boto3/*' -iname 'docs' -prune -exec rm -rf {} \;

    # OS specific directories (non-Linux)
    find "$1" -type d \( \
        -iname 'mac' -or \
        -iname 'macos' -or \
        -iname 'win' -or \
        -iname 'windows' \
        \) -prune -exec rm -rf {} \;

    # System files
    find "$1" -type f \( \
        -iname '*~' -or \
        -iname '.DS_Store' \
        \) -delete

    # Config files:
    # - dockerignore, gitignore, npmignore, ...
    # - .prettierrc, .eslintrc, ...
    # - .prettierrc.json, .prettierrc.yml, ...
    # - .gitconfig, .gitattributes, .gitmodules, .gitkeep, ...
    find "$1" -type f \( \
        -iname '*.*ignore' -or \
        -iname '*.*rc' -or \
        -iname '*.*rc.*' -or \
        -iname '*.git*' \
        \) -delete

    # HTML, XML
    find "$1" -type f \( \
        -iname '*.htm' -or \
        -iname '*.html' -or \
        -iname '*.html5' -or \
        -iname '*.xhtml' -or \
        -iname '*.xml' \
        \) -delete

    # CSS
    find "$1" -type f \( \
        -iname '*.css' -or \
        -iname '*.less' -or \
        -iname '*.sass' -or \
        -iname '*.scss' \
        \) -delete

    # Images
    find "$1" -type f \( \
        -iname '*.apng' -or \
        -iname '*.gif' -or \
        -iname '*.ico' -or \
        -iname '*.icon' -or \
        -iname '*.icns' -or \
        -iname '*.jpeg' -or \
        -iname '*.jpg' -or \
        -iname '*.png' -or \
        -iname '*.svg' -or \
        -iname '*.svgz' \
        \) -delete

    # C/Cpp files
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

    # Shell files
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

    # Markdown & Text
    find "$1" -type f \( \
        -name 'CHANGELOG' -or \
        -name 'CHANGELOG.*' -or \
        -name 'HISTORY' -or \
        -name 'HISTORY.*' -or \
        -name 'NOTICE' -or \
        -name 'NOTICE.*' -or \
        -name 'README' -or \
        -name 'README.*' -or \
        -name 'TODO' -or \
        -name 'TODO.*' -or \
        -iname '*.document' -or \
        -iname '*.doc' -or \
        -iname '*.doctree' -or \
        -iname '*.latex' -or \
        -iname '*.markdown' -or \
        -iname '*.markdown-it' -or \
        -iname '*.md' -or \
        -iname '*.mdown' \
        -iname '*.rdoc' -or \
        -iname '*.rst' -or \
        -iname '*.tex' -or \
        -iname '*.text' \
        \) -delete
    find "$1" -type f -iname '*.txt' -not \( \
        -path '*/blib2to3/*' -or \
        -name 'entry_points.txt' \
        \) -delete

    # YAML
    find "$1" -type f \
        -not -path '*/yamllint/*' \
        -not -path '*/cloudsplaining/*' \
        \( \
        -iname '*.yaml' -or \
        -iname '*.yml' \
        \) \
        -delete

    # Build files
    find "$1" -type f \( \
        -iname 'Dockerfile' -or \
        -iname 'Jenkinsfile' -or \
        -iname 'Makefile' -or \
        -iname 'Rakefile' \
        \) -delete
}

# Remove leftover empty directories
removeEmptyDirectories() {
    find "$1" -type d -empty -prune -exec rm -rf {} \;
}

### Minification ###

# Minify JSONs
minifyJsonFiles() {
    find "$1" -iname '*.json' | while read -r file; do
        jq -c '.' <"$file" | sponge "$file"
    done
}
