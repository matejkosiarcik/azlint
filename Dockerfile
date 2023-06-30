# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK

### Linters ###

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
FROM debian:12.0-slim AS ruby
WORKDIR /cwd
COPY linters/Gemfile linters/Gemfile.lock ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends bundler ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/* && \
    BUNDLE_DISABLE_SHARED_GEMS=true BUNDLE_PATH__SYSTEM=false BUNDLE_PATH="$PWD/bundle" BUNDLE_GEMFILE="$PWD/Gemfile" bundle install

# Rust/Cargo #
FROM rust:1.70.0-slim-bookworm AS rust
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

# Python/Pip #
FROM debian:12.0-slim AS python
WORKDIR /cwd
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-dev python3-pip && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt --target install

# PHP/Composer #
FROM debian:12.0-slim AS composer
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
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    parallel upx --best ::: /cwd/*

# Pre-Final #
FROM debian:12.0-slim AS pre-final
WORKDIR /app/cli
COPY --from=node /cwd/cli ./
COPY --from=node /cwd/node_modules ./node_modules
COPY src/shell-dry.sh src/find_files.py ./
WORKDIR /app/bin
RUN printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'node /app/cli/main.js $@' >azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >lint && \
    chmod a+x azlint fmt lint
WORKDIR /app/linters
COPY linters/Gemfile linters/Gemfile.lock ./
COPY --from=composer /cwd/linters/vendor ./vendor
COPY --from=node /cwd/linters/node_modules ./node_modules
COPY --from=python /cwd/install ./python
COPY --from=ruby /cwd/bundle ./bundle
WORKDIR /app/linters/bin
COPY --from=composer /cwd/linters/composer/bin/composer ./
COPY --from=hadolint /bin/hadolint ./
COPY --from=upx /cwd/checkmake /cwd/circleci /cwd/dotenv-linter /cwd/ec /cwd/shellcheck /cwd/shellharden /cwd/shfmt /cwd/stoml /cwd/tomljson ./

### Main runner ###

FROM debian:12.0-slim
WORKDIR /app
COPY --from=pre-final /app/ ./
ENV PATH="$PATH:/app/bin"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        bmake bundler git libxml2-utils make nodejs php python3 python3-pip ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh && \
    rm -rf /var/lib/apt/lists/* && \
    git config --system --add safe.directory '*' && \
    useradd --create-home --no-log-init --shell /usr/bin/bash --user-group --system azlint && \
    su - azlint -c "git config --global --add safe.directory '*'"
ENV NODE_OPTIONS=--dns-result-order=ipv4first

USER azlint
WORKDIR /project
ENTRYPOINT [ "azlint" ]
CMD []
