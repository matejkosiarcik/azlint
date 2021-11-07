# Well this is kinda long Dockerfile ¯\_(ツ)_/¯

### Components ###

# GoLang #
FROM golang:1.17.3 AS go
WORKDIR /src
RUN GOPATH="$PWD" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml' && \
    GOPATH="$PWD" GO111MODULE=on go get -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson' && \
    GOPATH="$PWD" GO111MODULE=on go get -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt'
FROM golang:1.17.3 AS go2
WORKDIR /src/checkmake
RUN apt-get update && \
    apt-get install --yes --no-install-recommends git pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/mrtazz/checkmake . && \
    BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make
WORKDIR /src/editorconfig-checker
RUN git clone https://github.com/editorconfig-checker/editorconfig-checker . && \
    make build

# NodeJS/NPM #
FROM node:lts-slim AS node
WORKDIR /src
COPY dependencies/package.json dependencies/package-lock.json ./
RUN npm ci --unsafe-perm && \
    npm prune --production

# Ruby/Gem #
# confusingly it has 2 stages
# first stage installs all gems with bundler
# second stage reinstalls these gems to the (almost) same container as our production one (without this stage we get warnings for gems with native extensions in production)
FROM ruby:3.0.2 AS pre-ruby
WORKDIR /src
COPY dependencies/Gemfile dependencies/Gemfile.lock ./
RUN gem install bundler && \
    gem update --system && \
    bundle install
FROM debian:11.1 AS ruby
WORKDIR /src
COPY --from=pre-ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/* && \
    GEM_HOME=/usr/local/bundle gem pristine --all

# Rust/Cargo #
FROM rust:1.56.1 AS rust
WORKDIR /src
COPY dependencies/Cargo.toml ./
COPY --from=go /src/bin/stoml /usr/bin/stoml
RUN stoml 'Cargo.toml' dev-dependencies | tr ' ' '\n' | xargs --no-run-if-empty cargo install --force

# CircleCI #
# it has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
# this script builds the executable and optimizes with https://upx.github.io
# then we just copy it to production container
FROM debian:11.1 AS circleci
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    curl -fLsS https://raw.githubusercontent.com/CircleCI-Public/circleci-cli/master/install.sh | bash && \
    rm -rf /var/lib/apt/lists/*

# Hadolint #
FROM hadolint/hadolint:v2.7.0 AS hadolint

# Shellcheck #
FROM koalaman/shellcheck:v0.8.0 AS shellcheck

### Helpers ###

# Upx #
# Single stage to compress all executables from multiple components
FROM debian:11.1 AS upx
COPY --from=circleci /usr/local/bin/circleci /usr/bin/
COPY --from=go /src/bin/shfmt /src/bin/tomljson /usr/bin/
COPY --from=go2 /src/checkmake/checkmake /src/editorconfig-checker/bin/ec  /usr/bin/
COPY --from=rust /usr/local/cargo/bin/shellharden /usr/local/cargo/bin/dotenv-linter /usr/bin/
COPY --from=shellcheck /bin/shellcheck /usr/bin/
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    upx --best /usr/bin/checkmake && \
    upx --best /usr/bin/circleci && \
    upx --best /usr/bin/dotenv-linter && \
    upx --best /usr/bin/shellcheck && \
    upx --best /usr/bin/shellharden && \
    upx --best /usr/bin/tomljson

# Prepare executable files
# Well this is not strictly necessary
# But doing it before the final stage is potentilly better (saves layer space)
# As the final stage only copies these files and does not modify them further
FROM debian:11.1 AS chmod
WORKDIR /src
COPY src/glob_files.py src/main.py src/run.sh ./
RUN chmod a+x glob_files.py main.py run.sh

### Main runner ###

# curl is only needed to install nodejs&composer
FROM debian:11.1
LABEL maintainer="matej.kosiarcik@gmail.com" \
    repo="https://github.com/matejkosiarcik/azlint"
WORKDIR /src
COPY dependencies/composer.json dependencies/composer.lock dependencies/requirements.txt src/shell-dry.sh ./
COPY --from=chmod /src/glob_files.py /src/main.py /src/run.sh ./
COPY --from=hadolint /bin/hadolint /usr/bin/
COPY --from=node /src/node_modules node_modules/
COPY --from=ruby /usr/local/bundle/ /usr/local/bundle/
COPY --from=upx /usr/bin/checkmake /usr/bin/circleci /usr/bin/dotenv-linter /usr/bin/ec /usr/bin/shellcheck /usr/bin/shellharden /usr/bin/shfmt /usr/bin/tomljson /usr/bin/
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ash bash bmake curl dash git jq ksh libxml2-utils make mksh php php-cli php-common php-mbstring php-zip posh python3 python3-pip ruby unzip yash zsh && \
    curl -fLsS https://deb.nodesource.com/setup_lts.x | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs && \
    curl -fLsSo composer-setup.php https://getcomposer.org/installer && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -f composer-setup.php && \
    apt-get remove --purge --yes curl && \
    rm -rf /var/lib/apt/lists/* && \
    composer install && \
    python3 -m pip install --no-cache-dir --upgrade setuptools && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt && \
    ln -s /src/main.py /usr/bin/azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >/usr/bin/fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >/usr/bin/lint && \
    chmod a+x /usr/bin/lint /usr/bin/fmt

WORKDIR /project
ENTRYPOINT [ "azlint" ]
CMD [ ]
