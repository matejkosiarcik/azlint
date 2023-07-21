# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# ^^^ Healhcheck doesn't make sense for us here, because we are building a CLI tool, not server program

### Components/Linters ###

# Upx #
FROM ubuntu:23.10 AS upx-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/*

# Gitman #
FROM debian:12.0-slim AS gitman
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
RUN python3 -m pip install --no-cache-dir --requirement requirements.txt --target python
COPY linters/gitman.yml ./
RUN PYTHONPATH=/app/python PATH="/app/python/bin:$PATH" gitman install

# GoLang #
FROM golang:1.20.6-bookworm AS go-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/*
COPY linters/gitman.yml ./
RUN GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/freshautomations/stoml@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/rhysd/actionlint/cmd/actionlint@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'
COPY --from=gitman /app/gitman/checkmake ./gitman/checkmake
RUN BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make -C gitman/checkmake
COPY --from=gitman /app/gitman/editorconfig-checker ./gitman/editorconfig-checker
RUN make -C gitman/editorconfig-checker build

# Golang -> UPX #
FROM upx-base AS go
COPY --from=go-base /app/gitman/checkmake/checkmake /app/gitman/editorconfig-checker/bin/ec /app/go/bin/actionlint /app/go/bin/shfmt /app/go/bin/stoml /app/go/bin/tomljson /app/
RUN parallel upx --ultra-brute ::: /app/*

# Rust #
FROM rust:1.71.0-slim-bookworm AS rust-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm
COPY utils/cargo-packages.js ./utils/
COPY linters/Cargo.toml ./linters/
RUN node utils/cargo-packages.js | while read -r package version; do \
        cargo install "$package" --force --version "$version" --root "$PWD/cargo"; \
    done

# Rust -> UPX #
FROM upx-base AS rust
COPY --from=rust-base /app/cargo/bin/dotenv-linter /app/cargo/bin/hush /app/cargo/bin/shellharden /app/
RUN parallel upx --ultra-brute ::: /app/*

# CircleCI CLI #
# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.0-slim AS circleci-base
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/circleci-cli /app/circleci-cli
WORKDIR /app/circleci-cli
RUN bash install.sh

# CircleCI CLI -> UPX #
FROM upx-base AS circleci
COPY --from=circleci-base /usr/local/bin/circleci /app/
RUN upx --ultra-brute /app/circleci

# Shell - loksh #
FROM debian:12.0-slim AS loksh-base
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential ca-certificates git meson && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/loksh /app/loksh
WORKDIR /app/loksh
RUN meson setup --prefix="$PWD/install" build && \
    ninja -C build install

# loksh -> UPX #
FROM upx-base AS loksh
COPY --from=loksh-base /app/loksh/install/bin/ksh /app/loksh
RUN upx --ultra-brute /app/loksh

# Shell - oksh #
FROM debian:12.0-slim AS oksh-base
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/oksh /app/oksh
WORKDIR /app/oksh
RUN ./configure && \
    make && \
    DESTDIR="$PWD/install" make install

# oksh -> UPX #
FROM upx-base AS oksh
COPY --from=oksh-base /app/oksh/install/usr/local/bin/oksh /app/
RUN upx --ultra-brute /app/oksh

# ShellCheck #
FROM koalaman/shellcheck:v0.9.0 AS shellcheck-base

# ShellCheck -> UPX #
FROM upx-base AS shellcheck
COPY --from=shellcheck-base /bin/shellcheck ./
RUN upx --ultra-brute /app/shellcheck

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint

# NodeJS/NPM #
FROM node:20.4.0-slim AS node
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY linters/package.json linters/package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm && \
    npm prune --production && \
    find 'node_modules' -type d \( -iname 'test' -or -iname 'tests' -or -iname 'man' \) -prune -exec rm -rf {} \; && \
    find 'node_modules' -type d -not -path '*/markdown-table-prettify/*' \( -iname 'doc' -or -name 'docs' \) -prune -exec rm -rf {} \; && \
    find 'node_modules' -type f \( -name 'README' -or -name 'LICENSE' -or -name 'README.*' -or -name 'LICENSE.*' -or -name '*.md' -or -name '*.txt' \) -exec rm -rf {} \; && \
    find 'node_modules/yargs/locales' -iname '*.json' -and -not -name 'en.json' -delete && \
    find 'node_modules' -iname '*.json' | while read -r file; do jq -r tostring <"$file" | sponge "$file"; done

# Ruby/Gem #
FROM debian:12.0-slim AS ruby
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends bundler ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/*
COPY linters/Gemfile linters/Gemfile.lock ./
RUN BUNDLE_DISABLE_SHARED_GEMS=true BUNDLE_PATH__SYSTEM=false BUNDLE_PATH="$PWD/bundle" BUNDLE_GEMFILE="$PWD/Gemfile" bundle install

# Python/Pip #
FROM debian:12.0-slim AS python
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*
COPY linters/requirements.txt ./
RUN PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONDONTWRITEBYTECODE=1 python3 -m pip install --no-cache-dir --requirement requirements.txt --target python && \
    find python -type d -name '__pycache__' -prune -exec rm -rf {} \; && \
    find python -type f -name '*.py[oc]' -delete

# Composer #
FROM composer:2.5.8 AS composer-bin

# PHP/Composer #
FROM debian:12.0-slim AS composer-vendor
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates composer php php-cli php-common php-mbstring php-zip && \
    rm -rf /var/lib/apt/lists/*
COPY linters/composer.json linters/composer.lock ./
RUN composer install --no-cache

# LinuxBrew - install #
# This is first part of HomeBrew, here we just install it
# We have to provide our custom `uname`, because HomeBrew prohibits installation on non-x64 Linux systems
FROM debian:12.0-slim AS brew-install
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl git procps ruby && \
    if [ "$(uname -m)" != 'amd64' ]; then \
        dpkg --add-architecture amd64 && \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends libc6:amd64 && \
    true; fi && \
    rm -rf /var/lib/apt/lists/* && \
    touch /.dockerenv
COPY utils/uname-x64.sh /usr/bin/uname-x64
RUN if [ "$(uname -m)" != 'amd64' ]; then \
        chmod a+x /usr/bin/uname-x64 && \
        mv /usr/bin/uname /usr/bin/uname-bak && \
        mv /usr/bin/uname-x64 /usr/bin/uname && \
    true; fi
COPY --from=gitman /app/gitman/brew-installer ./brew-installer
RUN NONINTERACTIVE=1 bash brew-installer/install.sh && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew update && \
    brew bundle --help && \
    ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    rm -rf "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full"

# LinuxBrew - rbenv #
# We need to replace ruby bundled with HomeBrew, because it is only a x64 version
# Instead we install the same ruby version via rbenv and replace it in HomeBrew
FROM debian:12.0-slim AS brew-rbenv
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        autoconf bison build-essential ca-certificates curl git \
        libffi-dev libgdbm-dev libncurses5-dev libreadline-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/rbenv-installer ./rbenv-installer
ENV PATH="$PATH:/root/.rbenv/bin:/.rbenv/bin:/.rbenv/shims" \
    RBENV_ROOT=/.rbenv
RUN bash rbenv-installer/bin/rbenv-installer
COPY --from=brew-install /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version ./
RUN ruby_version_short="$(sed -E 's~_.+$~~' <portable-ruby-version)" && \
    rbenv install "$ruby_version_short"

# LinuxBrew - final #
FROM debian:12.0-slim AS brew-final
WORKDIR /app
COPY --from=brew-install /home/linuxbrew /home/linuxbrew
COPY --from=brew-rbenv /.rbenv/versions /.rbenv/versions
RUN ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ruby_version_short="$(sed -E 's~_.+$~~' </home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ln -sf "/.rbenv/versions/$ruby_version_short" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full"

### Helpers ###

# Main CLI #
FROM node:20.4.0-slim AS cli
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm && \
    npx modclean --patterns default:safe --run --error-halt && \
    npx node-prune && \
    find 'node_modules/yargs/locales' -name '*.json' -and -not -name 'en.json' -delete && \
    find 'node_modules' -name '*.json' | while read -r file; do jq -r tostring <"$file" | sponge "$file"; done
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build && \
    npm prune --production

# Azlint binaries #
FROM debian:12.0-slim AS azlint-bin
WORKDIR /app
RUN printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'node /app/cli/main.js $@' >azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >lint && \
    chmod a+x azlint fmt lint

# Pre-Final #
FROM debian:12.0-slim AS pre-final
COPY --from=brew-final /home/linuxbrew /home/linuxbrew
COPY --from=brew-final /.rbenv/versions /.rbenv/versions
COPY --from=azlint-bin /app/azlint /app/fmt /app/lint /usr/bin/
WORKDIR /app
COPY VERSION.txt ./
WORKDIR /app/cli
COPY --from=cli /app/cli ./
COPY --from=cli /app/node_modules ./node_modules
COPY src/shell-dry-run.sh src/shell-dry-run-utils.sh ./
WORKDIR /app/linters
COPY linters/Gemfile linters/Gemfile.lock linters/composer.json ./
COPY --from=composer-vendor /app/vendor ./vendor
COPY --from=node /app/node_modules ./node_modules
COPY --from=python /app/python ./python
COPY --from=ruby /app/bundle ./bundle
WORKDIR /app/linters/bin
COPY --from=composer-bin /usr/bin/composer ./
COPY --from=hadolint /bin/hadolint ./
COPY --from=go /app ./
COPY --from=rust /app ./
COPY --from=circleci /app ./
COPY --from=loksh /app ./
COPY --from=oksh /app ./
COPY --from=shellcheck /app ./

### Final stage ###

FROM debian:12.0-slim
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        curl git libxml2-utils \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python3 python3-pip \
        bundler ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh && \
    rm -rf /var/lib/apt/lists/* && \
    git config --system --add safe.directory '*' && \
    git config --global --add safe.directory '*' && \
    mkdir -p /root/.cache/proselint && \
    useradd --create-home --no-log-init --shell /bin/sh --user-group --system azlint && \
    su - azlint -c "git config --global --add safe.directory '*'" && \
    su - azlint -c 'mkdir -p /home/azlint/.cache/proselint'
COPY --from=pre-final /usr/bin/azlint /usr/bin/fmt /usr/bin/lint /usr/bin/
COPY --from=pre-final /home/linuxbrew /home/linuxbrew
COPY --from=pre-final /.rbenv/versions /.rbenv/versions
COPY --from=pre-final /app/ ./
ENV HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_ENV_HINTS=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    NODE_OPTIONS=--dns-result-order=ipv4first \
    PATH="$PATH:/app/bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1
USER azlint
WORKDIR /project
ENTRYPOINT ["azlint"]
CMD []
