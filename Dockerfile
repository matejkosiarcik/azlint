# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# TODO: Update debian 11 (bullseye) to 12 (bookworm)

### Components ###

# GoLang #
FROM golang:1.20.5-bookworm AS go
WORKDIR /cwd
RUN GOPATH="$PWD" GO111MODULE=on go install -ldflags='-s -w' 'github.com/freshautomations/stoml@latest' && \
    GOPATH="$PWD" GO111MODULE=on go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    GOPATH="$PWD" GO111MODULE=on go install -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'
WORKDIR /cwd/editorconfig-checker
RUN git clone https://github.com/editorconfig-checker/editorconfig-checker . && \
    make build
WORKDIR /cwd/checkmake
RUN apt-get update && \
    apt-get install --yes --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/mrtazz/checkmake . && \
    BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make

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
WORKDIR /cwd/linters
COPY linters/package.json linters/package-lock.json ./
RUN npm ci --unsafe-perm && \
    npx node-prune && \
    npm prune --production

# Ruby/Gem #
# confusingly it has 2 stages
# first stage installs all gems with bundler
# second stage reinstalls these gems to the (almost) same container as our production one (without this stage we get warnings for gems with native extensions in production)
FROM ruby:3.2.2 AS pre-ruby
WORKDIR /cwd
COPY linters/Gemfile linters/Gemfile.lock ./
RUN gem install bundler && \
    gem update --system && \
    bundle install

FROM debian:12.0 AS ruby
WORKDIR /cwd
COPY --from=pre-ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/* && \
    GEM_HOME=/usr/local/bundle gem pristine --all

# Rust/Cargo #
FROM rust:1.70.0-bookworm AS rust
WORKDIR /cwd
COPY package.json package-lock.json cargo-packages.js ./
COPY linters/Cargo.toml ./linters/
ENV NODE_OPTIONS=--dns-result-order=ipv4first
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/* && \
    npm ci --unsafe-perm && \
    node cargo-packages.js | while read -r package version; do \
        cargo install "$package" --force --version "$version"; \
    done

# Python #
FROM debian:12.0 AS python
WORKDIR /cwd
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-dev python3-pip && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt --target install

# PHP/Composer #
FROM debian:12.0 AS composer
WORKDIR /cwd
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl php php-cli php-common php-mbstring php-zip && \
    curl -fLsS https://getcomposer.org/installer -o composer-setup.php && \
    mkdir -p /cwd/linters/composer/bin && \
    php composer-setup.php --install-dir=/cwd/linters/composer/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/* composer-setup.php
WORKDIR /cwd/linters
COPY linters/composer.json linters/composer.lock ./
RUN PATH="/cwd/linters/composer/bin:$PATH" composer install --no-cache

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
FROM ubuntu:23.10 AS upx
WORKDIR /cwd
COPY --from=circleci /usr/local/bin/circleci ./
COPY --from=go /cwd/checkmake/checkmake /cwd/editorconfig-checker/bin/ec /cwd/bin/shfmt /cwd/bin/stoml /cwd/bin/tomljson ./
COPY --from=rust /usr/local/cargo/bin/shellharden /usr/local/cargo/bin/dotenv-linter ./
COPY --from=shellcheck /bin/shellcheck ./
COPY --from=hadolint /bin/hadolint ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    upx /cwd/checkmake && \
    upx /cwd/circleci && \
    upx /cwd/dotenv-linter && \
    upx /cwd/shellcheck && \
    upx /cwd/shellharden && \
    upx /cwd/stoml && \
    upx /cwd/tomljson
# hadolint is skipped, because it's already packed #

# Prepare executable files
# Well this is not strictly necessary
# But doing it before the final stage is potentilly better (saves layer space)
# As the final stage only copies these files and does not modify them further
FROM debian:12.0 AS chmod
WORKDIR /cwd
COPY src/glob_files.py src/main.py src/run.sh ./
RUN chmod a+x glob_files.py main.py run.sh

FROM debian:12.0-slim AS aggregator1
WORKDIR /cwd
COPY linters/composer.json linters/composer.lock linters/requirements.txt src/shell-dry.sh ./
COPY --from=chmod /cwd/glob_files.py /cwd/main.py /cwd/run.sh ./

### Main runner ###

FROM debian:12.0
WORKDIR /app
COPY --from=aggregator1 /cwd/ ./
COPY --from=node /cwd/cli ./cli
COPY --from=node /cwd/linters/node_modules node_modules/
COPY --from=ruby /usr/local/bundle/ /usr/local/bundle/
COPY --from=upx /cwd/checkmake /cwd/circleci /cwd/dotenv-linter /cwd/ec /cwd/hadolint /cwd/shellcheck /cwd/shellharden /cwd/shfmt /cwd/stoml /cwd/tomljson /usr/bin/
COPY --from=composer /cwd/linters/composer/bin/composer /app/bin/
COPY --from=composer /cwd/linters/vendor /app/linters/vendor
COPY --from=python /cwd/install /app/linters/python
ENV PATH="$PATH:/app/bin"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        ash bash bmake dash git jq ksh libxml2-utils make mksh nodejs php php-cli php-common php-mbstring php-zip posh python3 python3-pip ruby unzip yash zsh && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /app/main.py /usr/bin/azlint && \
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
