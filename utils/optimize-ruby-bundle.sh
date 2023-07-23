#!/bin/sh
set -euf

exit 0

### Remove directories ###

find bundle -type d \( \
    -iname '.github' -or \
    -iname 'cache' -or \
    -iname 'doc' -or \
    -iname 'docs' -or \
    -iname 'html' -or \
    -iname 'man' -or \
    -iname 'test' -or \
    -iname 'tests' -or \
    -iname 'testutils' -or \
    -iname 'test-data' -or \
    -iname 'template' -or \
    -iname 'templates' -or \
    -iname '__pycache__' -or \
    -iname '*.app' \
    \) -prune -exec rm -rf {} \;

### Remove files ###

# System files
find bundle -type f \( \
    -iname '*~' -or \
    -iname '.DS_Store' \
    \) -delete

# Config files:
# - dockerignore, gitignore, npmignore, ...
# - .prettierrc, .eslintrc, ...
# - .prettierrc.json, .prettierrc.yml, ...
# - .gitconfig, .gitattributes, .gitmodules, .gitkeep, ...
find bundle -type f \( \
    -iname '*.*ignore' -or \
    -iname '*.*rc' -or \
    -iname '*.*rc.*' -or \
    -iname '*.git*' \
    \) -delete

# Compiled resources
find bundle -type f \( \
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

# Images
find bundle -type f \( \
    -iname '*.icns' -or \
    -iname '*.ico' -or \
    -iname '*.icon' -or \
    -iname '*.jpeg' -or \
    -iname '*.jpg' -or \
    -iname '*.apng' -or \
    -iname '*.png' -or \
    -iname '*.svg' \
    \) -delete

# Documentation
find bundle -type f \( \
    -iname 'AUTHORS' -or \
    -iname 'AUTHORS.*' -or \
    -iname 'CHANGELOG' -or \
    -iname 'CHANGELOG.*' -or \
    -iname 'CONTRIBUTING' -or \
    -iname 'CONTRIBUTING.*' -or \
    -iname 'CONTRIBUTERS' -or \
    -iname 'CONTRIBUTERS.*' -or \
    -iname 'COPYING' -or \
    -iname 'COPYING.*' -or \
    -iname 'LICENSE' -or \
    -iname 'LICENSE.*' -or \
    -iname '*-LICENSE' -or \
    -iname 'LICENSE-*' -or \
    -iname 'NOTICE' -or \
    -iname 'NOTICE.*' -or \
    -iname 'README' -or \
    -iname 'README.*' -or \
    -iname 'TODO' -or \
    -iname 'TODO.*' -or \
    -iname 'VERSION' -or \
    -iname '*.document' -or \
    -iname '*.doc' -or \
    -iname '*.latex' -or \
    -iname '*.markdown' -or \
    -iname '*.md' -or \
    -iname '*.mdown' -or \
    -iname '*.rdoc' -or \
    -iname '*.rst' -or \
    -iname '*.tex' -or \
    -iname '*.text' -or \
    -iname '*.txt' \
    \) -delete

# HTML
find bundle -type f \( \
    -iname '*.css' -or \
    -iname '*.htm' -or \
    -iname '*.html' -or \
    -iname '*.less' -or \
    -iname '*.sass' -or \
    -iname '*.scss' -or \
    -iname '*.xhtml' \
    \) -delete

# Misc
find bundle -type f \( \
    -iname 'Gemfile' -or \
    -iname 'Makefile' -or \
    -iname 'Rakefile' -or \
    -iname '*.autotest' -or \
    -iname '*.dat' -or \
    -iname '*.data' -or \
    -iname '*.erb' -or \
    -iname '*.gemtest' -or \
    -iname '*.jar' -or \
    -iname '*.java' -or \
    -iname '*.log' -or \
    -iname '*.nib' -or \
    -iname '*.o' -or \
    -iname '*.out' -or \
    -iname '*.provisionprofile' -or \
    -iname '*.pem' -or \
    -iname '*.rake' -or \
    -iname '*.rspec' -or \
    -iname '*.rl' -or \
    -iname '*.sh' -or \
    -iname '*.simplecov' -or \
    -iname '*.time' -or \
    -iname '*.tt' -or \
    -iname '*.y' -or \
    -iname '*.yardopts' -or \
    -iname '*.yaml' -or \
    -iname '*.yml' \
    \) -delete

# Remove leftover empty directories
find bundle -type d -empty -prune -exec rm -rf {} \;
