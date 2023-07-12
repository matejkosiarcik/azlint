# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK

### Components/Linters ###

# Gitman #
FROM node:20.4.0-slim AS gitman
WORKDIR /app
COPY requirements.txt ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt --target python
WORKDIR /app/linters
COPY linters/gitman.yml ./
RUN PYTHONPATH=/app/python PATH="/app/python/bin:$PATH" gitman install

# GoLang #
FROM golang:1.20.6-bookworm AS go
WORKDIR /app
RUN GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/freshautomations/stoml@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'
WORKDIR /app/linters
COPY --from=gitman /app/linters/gitman ./gitman
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    make -C /app/linters/gitman/editorconfig-checker build && \
    BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make -C /app/linters/gitman/checkmake

# NodeJS/NPM #
FROM node:20.4.0-slim AS node
ENV NODE_OPTIONS=--dns-result-order=ipv4first
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
COPY src/ ./src/
RUN npm ci --unsafe-perm && \
    npm run build && \
    npx node-prune && \
    npm prune --production
WORKDIR /app/linters
COPY linters/package.json linters/package-lock.json ./
RUN npm ci --unsafe-perm && \
    npm prune --production

# Ruby/Gem #
FROM debian:12.0-slim AS ruby
WORKDIR /app
COPY linters/Gemfile linters/Gemfile.lock ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends bundler ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/* && \
    BUNDLE_DISABLE_SHARED_GEMS=true BUNDLE_PATH__SYSTEM=false BUNDLE_PATH="$PWD/bundle" BUNDLE_GEMFILE="$PWD/Gemfile" bundle install

# Rust/Cargo #
FROM rust:1.70.0-slim-bookworm AS rust
WORKDIR /app
COPY package.json package-lock.json ./
COPY utils/cargo-packages.js ./utils/
COPY linters/Cargo.toml ./linters/
ENV NODE_OPTIONS=--dns-result-order=ipv4first
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/* && \
    npm ci --unsafe-perm && \
    node utils/cargo-packages.js | while read -r package version; do \
        cargo install "$package" --force --version "$version" --root "$PWD/cargo"; \
    done

# Python/Pip #
FROM debian:12.0-slim AS python
WORKDIR /app/linters
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt --target python

# PHP/Composer #
FROM debian:12.0-slim AS composer
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl php php-cli php-common php-mbstring php-zip && \
    curl -fLsS https://getcomposer.org/installer -o composer-setup.php && \
    mkdir -p /app/linters/composer/bin && \
    php composer-setup.php --install-dir=/app/linters/composer/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/* composer-setup.php
WORKDIR /app/linters
COPY linters/composer.json linters/composer.lock ./
RUN PATH="/app/linters/composer/bin:$PATH" composer install --no-cache

# CircleCI #
# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.0-slim AS circleci
WORKDIR /app/linters
COPY --from=gitman /app/linters/gitman ./gitman
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    bash ./gitman/circleci-cli/install.sh && \
    rm -rf /var/lib/apt/lists/*

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint

# ShellCheck #
FROM koalaman/shellcheck:v0.9.0 AS shellcheck

# TODO: Finish LinuxBrew setup
# LinuxBrew #
FROM debian:12.0-slim AS brew
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl ruby ruby-build qemu-user && \
    if [ "$(uname -m)" != x86_64 ]; then \
        dpkg --add-architecture amd64 && \
    true; fi && \
    rm -rf /var/lib/apt/lists/* && \
    touch linuxbrew-placeholder.txt

# apt-get update -o APT::Architecture="amd64" -o APT::Architectures="amd64"
# NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# brew bundle --help

FROM debian:12.0-slim AS loksh
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential ca-certificates git meson && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/linters/gitman ./gitman
WORKDIR /app/gitman/loksh/
RUN meson setup --prefix="$PWD/install" build && \
    ninja -C build install

### Helpers ###

# Upx #
# Single stage to compress all executables from multiple components
FROM ubuntu:23.10 AS upx
WORKDIR /app
COPY --from=circleci /usr/local/bin/circleci ./
COPY --from=go /app/linters/gitman/checkmake/checkmake /app/linters/gitman/editorconfig-checker/bin/ec /app/go/bin/shfmt /app/go/bin/stoml /app/go/bin/tomljson ./
COPY --from=rust /app/cargo/bin/shellharden /app/cargo/bin/dotenv-linter ./
COPY --from=shellcheck /bin/shellcheck ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    parallel upx --best ::: /app/*

# Pre-Final #
FROM debian:12.0-slim AS pre-final
WORKDIR /
COPY --from=brew /app/linuxbrew-placeholder.txt ./
RUN rm linuxbrew-placeholder.txt
WORKDIR /app
COPY VERSION.txt ./
WORKDIR /app/cli
COPY --from=node /app/cli ./
COPY --from=node /app/node_modules ./node_modules
COPY src/shell-dry-run.sh src/shell-dry-run-utils.sh ./
WORKDIR /app/bin
RUN printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'node /app/cli/main.js $@' >azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >lint && \
    chmod a+x azlint fmt lint
WORKDIR /app/linters
COPY linters/Gemfile linters/Gemfile.lock linters/composer.json ./
COPY --from=composer /app/linters/vendor ./vendor
COPY --from=node /app/linters/node_modules ./node_modules
COPY --from=python /app/linters/python ./python
COPY --from=ruby /app/bundle ./bundle
WORKDIR /app/linters/bin
COPY --from=composer /app/linters/composer/bin/composer ./
COPY --from=hadolint /bin/hadolint ./
COPY --from=upx /app/checkmake /app/circleci /app/dotenv-linter /app/ec /app/shellcheck /app/shellharden /app/shfmt /app/stoml /app/tomljson ./
COPY --from=loksh /app/gitman/loksh/install/bin/ksh ./loksh

### Final ###

FROM debian:12.0-slim
WORKDIR /app
COPY --from=pre-final /app/ ./
ENV PATH="$PATH:/app/bin"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        bmake bundler git libxml2-utils make nodejs npm php php-mbstring python3 python3-pip ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh && \
    rm -rf /var/lib/apt/lists/* && \
    git config --system --add safe.directory '*' && \
    git config --global --add safe.directory '*' && \
    useradd --create-home --no-log-init --shell /bin/sh --user-group --system azlint && \
    su - azlint -c "git config --global --add safe.directory '*'" && \
    mkdir -p /home/azlint/.cache/proselint
ENV NODE_OPTIONS=--dns-result-order=ipv4first
USER azlint
WORKDIR /project
ENTRYPOINT ["azlint"]
CMD []
