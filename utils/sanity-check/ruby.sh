#!/bin/sh
set -euf

ruby --help | cat
ruby --version
bundle --help | cat
bundle --version
bundle exec mdl --help
bundle exec mdl --version
bundle exec travis --help --no-interactive
bundle exec travis --version --no-interactive
