# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# TODO: Update debian 11 (bullseye) to 12 (bookworm)

### Components ###

# GoLang #
FROM golang:1.20.5-bullseye AS go
WORKDIR /src
RUN GOPATH="$PWD" GO111MODULE=on go install -ldflags='-s -w' 'github.com/freshautomations/stoml@latest' && \
    GOPATH="$PWD" GO111MODULE=on go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    GOPATH="$PWD" GO111MODULE=on go install -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'

FROM golang:1.20.5-bullseye AS checkmake
WORKDIR /src/checkmake
RUN apt-get update && \
    apt-get install --yes --no-install-recommends git pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/mrtazz/checkmake . && \
    BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make

FROM golang:1.20.5-bullseye AS editorconfig-checker
WORKDIR /src/editorconfig-checker
RUN git clone https://github.com/editorconfig-checker/editorconfig-checker . && \
    make build

# NodeJS/NPM #
FROM node:20.3.1-slim AS node
ENV NODE_OPTIONS=--dns-result-order=ipv4first
WORKDIR /cwd
COPY package.json package-lock.json tsconfig.json ./
COPY src/ ./src/
RUN npm ci --unsafe-perm && \
    npm run build && \
    npx node-prune && \
    npm prune --production
WORKDIR /cwd/dependencies
COPY dependencies/package.json dependencies/package-lock.json ./
RUN npm ci --unsafe-perm && \
    npx node-prune && \
    npm prune --production

# Ruby/Gem #
# confusingly it has 2 stages
# first stage installs all gems with bundler
# second stage reinstalls these gems to the (almost) same container as our production one (without this stage we get warnings for gems with native extensions in production)
FROM ruby:3.2.2 AS pre-ruby
WORKDIR /src
COPY dependencies/Gemfile dependencies/Gemfile.lock ./
RUN gem install bundler && \
    gem update --system && \
    bundle install

FROM debian:11.7 AS ruby
WORKDIR /src
COPY --from=pre-ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/* && \
    GEM_HOME=/usr/local/bundle gem pristine --all

# Rust/Cargo #
FROM rust:1.70.0-bullseye AS rust
WORKDIR /src
COPY package.json package-lock.json cargo-packages.js ./
COPY dependencies/Cargo.toml ./dependencies/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/* && \
    npm ci --unsafe-perm && \
    node cargo-packages.js | while read -r package version; do \
        cargo install "$package" --force --version "$version"; \
    done

# CircleCI #
# it has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
# this script builds the executable and optimizes with https://upx.github.io
# then we just copy it to production container
FROM debian:12.0 AS circleci
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    curl -fLsS https://raw.githubusercontent.com/CircleCI-Public/circleci-cli/master/install.sh | bash && \
    rm -rf /var/lib/apt/lists/*

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint

# Shellcheck #
FROM koalaman/shellcheck:v0.9.0 AS shellcheck

### Helpers ###

# Upx #
# Single stage to compress all executables from multiple components
FROM debian:11.7 AS upx
COPY --from=circleci /usr/local/bin/circleci /usr/bin/
COPY --from=go /src/bin/shfmt /src/bin/stoml /src/bin/tomljson /usr/bin/
COPY --from=checkmake /src/checkmake/checkmake /usr/bin/
COPY --from=editorconfig-checker /src/editorconfig-checker/bin/ec /usr/bin/
COPY --from=rust /usr/local/cargo/bin/shellharden /usr/local/cargo/bin/dotenv-linter /usr/bin/
COPY --from=shellcheck /bin/shellcheck /usr/bin/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    upx --best /usr/bin/checkmake && \
    upx --best /usr/bin/circleci && \
    upx --best /usr/bin/dotenv-linter && \
    upx --best /usr/bin/shellcheck && \
    upx --best /usr/bin/shellharden && \
    upx --best /usr/bin/stoml && \
    upx --best /usr/bin/tomljson

# Prepare executable files
# Well this is not strictly necessary
# But doing it before the final stage is potentilly better (saves layer space)
# As the final stage only copies these files and does not modify them further
FROM debian:12.0 AS chmod
WORKDIR /src
COPY src/glob_files.py src/main.py src/run.sh ./
RUN chmod a+x glob_files.py main.py run.sh

FROM debian:12.0-slim AS aggregator1
COPY dependencies/composer.json dependencies/composer.lock dependencies/requirements.txt src/shell-dry.sh /src/
COPY --from=chmod /src/glob_files.py /src/main.py /src/run.sh /src/

FROM debian:12.0 AS curl
WORKDIR /cwd
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fLsS https://getcomposer.org/installer -o composer-setup.php

### Main runner ###

# curl is only needed to install nodejs&composer
FROM debian:11.7
WORKDIR /src
COPY --from=aggregator1 /src/ ./
COPY --from=hadolint /bin/hadolint /usr/bin/
COPY --from=node /cwd/cli /src/cli
COPY --from=node /cwd/dependencies/node_modules node_modules/
COPY --from=ruby /usr/local/bundle/ /usr/local/bundle/
COPY --from=upx /usr/bin/checkmake /usr/bin/circleci /usr/bin/dotenv-linter /usr/bin/ec /usr/bin/shellcheck /usr/bin/shellharden /usr/bin/shfmt /usr/bin/stoml /usr/bin/tomljson /usr/bin/
COPY --from=curl /cwd/composer-setup.php ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ash bash bmake dash git jq ksh libxml2-utils make mksh nodejs php php-cli php-common php-mbstring php-zip posh python3 python3-pip ruby unzip yash zsh && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/* composer-setup.php && \
    composer install && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt && \
    ln -s /src/main.py /usr/bin/azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >/usr/bin/fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >/usr/bin/lint && \
    chmod a+x /usr/bin/lint /usr/bin/fmt && \
    git config --system --add safe.directory /project && \
    useradd --create-home --no-log-init --shell /bin/sh --user-group --system azlint && \
    git config --global --add safe.directory '*' && \
    su - root -c "git config --global --add safe.directory '*'" && \
    su - azlint -c "git config --global --add safe.directory '*'"

USER azlint
WORKDIR /project
ENTRYPOINT [ "azlint" ]
CMD []
