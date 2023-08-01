#!/bin/sh
set -euf

# shellcheck source=utils/optimize/.common.sh
. "$(dirname "$0")/.common.sh"

cleanDependencies /.rbenv/versions

find /.rbenv/versions -type d -path '/.rbenv/versions/*/share/ri' -prune -exec rm -rf {} \;

# Unused components
find /.rbenv/versions -type d \( \
    -iname 'bigdecimal' -or \
    -iname 'bundler' -or \
    -iname 'cache' -or \
    -iname 'csv' -or \
    -iname 'drb' -or \
    -iname 'enc' -or \
    -iname 'irb' -or \
    -iname 'gems' -or \
    -iname 'matrix' -or \
    -iname 'optparse' -or \
    -iname 'pkgconfig' -or \
    -iname 'psych' -or \
    -iname 'rdoc' -or \
    -iname 'rexml' -or \
    -iname 'rss' -or \
    -iname 'unicode_normalize' -or \
    -iname 'webrick' -or \
    -iname 'yaml' \
    \) -prune -exec rm -rf {} \;

# Unused components - ruby files
find /.rbenv/versions -type f \( \
    -iname 'bigdecimal.rb' -or \
    -iname 'bundler.rb' -or \
    -iname 'csv.rb' -or \
    -iname 'drb.rb' -or \
    -iname 'enc.rb' -or \
    -iname 'irb.rb' -or \
    -iname 'matrix.rb' -or \
    -iname 'psych.rb' -or \
    -iname 'rdoc.rb' -or \
    -iname 'rexml.rb' -or \
    -iname 'rss.rb' -or \
    -iname 'webrick.rb' -or \
    -iname 'yaml.rb' \
    \) -prune -exec rm -rf {} \;

# Unused rubygems
find /.rbenv/versions -type d -path '*/rubygems/*' \( \
    -iname 'commands' -or \
    -iname 'ext' -or \
    -iname 'package' -or \
    -iname 'resolver' -or \
    -iname 'request' -or \
    -iname 'request_set' -or \
    -iname 'security' -or \
    -iname 'source' -or \
    -iname 'ssl_certs' \
    \) -prune -exec rm -rf {} \;

find /.rbenv/versions -maxdepth 3 -type f -path '/.rbenv/versions/*/bin/*' -not -name ruby -delete

find /.rbenv/versions -type d -path '*/lib/ruby/*' \( \
    -iname 'openssl' -or \
    -iname 'shell' \
    \) -prune -exec rm -rf {} \;

# Misc
find /.rbenv/versions -type f \( \
    -iname 'c_rehash' -or \
    -iname 'Gemfile' -or \
    -iname '*.a' -or \
    -iname '*.autotest' -or \
    -iname '*.cnf' -or \
    -iname '*.dist' -or \
    -iname '*.gemspec' -or \
    -iname '*.pc' -or \
    -iname '*.pl' \
    \) -delete

# Misc again
find /.rbenv/versions -type d -path '*/openssl/lib/*' -name 'engines-*' -prune -exec rm -rf {} \;
find /.rbenv/versions -type f -path '*/json/add/*' -not -name 'exception.rb' -delete
find /.rbenv/versions -type f -path '*/openssl/bin/*' -delete

removeEmptyDirectories /.rbenv/versions

### Minification ###

minifyJsonFiles /.rbenv/versions
