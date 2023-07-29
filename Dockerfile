#
# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# ^^^ Healhcheck doesn't make sense, because we are building a CLI tool, not server program
# checkov:skip=CKV_DOCKER_7:Disable FROM :latest
# ^^^ false positive for `--platform=$BUILDPLATFORM`

# hadolint global ignore=DL3042
# ^^^ pip cache

# Upx #
# NOTE: `upx-ucl` is no longer available in debian 12 bookworm
# It is available in older versions, see https://packages.debian.org/bullseye/upx-ucl
# However, there were upgrade problems for bookworm, see https://tracker.debian.org/pkg/upx-ucl
# TODO: Change upx target from ubuntu to debian when possible
FROM --platform=$BUILDPLATFORM ubuntu:23.10 AS upx-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/*

FROM debian:12.1-slim AS bins-aggregator
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends file && \
    rm -rf /var/lib/apt/lists/*

### Components/Linters ###

# Gitman #
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS gitman
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python
COPY linters/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    PYTHONPATH=/app/python PATH="/app/python/bin:$PATH" gitman install

# GoLang #
FROM --platform=$BUILDPLATFORM golang:1.20.6-bookworm AS go-actionlint-build
WORKDIR /app
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w' 'github.com/rhysd/actionlint/cmd/actionlint@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/actionlint" './go/bin/actionlint' && \
    true; fi

FROM --platform=$BUILDPLATFORM upx-base AS go-actionlint
COPY --from=go-actionlint-build /app/go/bin/actionlint ./
# RUN upx --best /app/actionlint

FROM --platform=$BUILDPLATFORM golang:1.20.6-bookworm AS go-shfmt-build
WORKDIR /app
COPY --from=gitman /app/gitman/shfmt /app/shfmt
COPY utils/git-latest-version.sh ./
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w' "mvdan.cc/sh/v3/cmd/shfmt@v$(sh git-latest-version.sh shfmt)" && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/shfmt" './go/bin/shfmt' && \
    true; fi

FROM --platform=$BUILDPLATFORM upx-base AS go-shfmt
COPY --from=go-shfmt-build /app/go/bin/shfmt ./
# RUN upx --best /app/shfmt

FROM --platform=$BUILDPLATFORM golang:1.20.6-bookworm AS go-stoml-build
WORKDIR /app
COPY --from=gitman /app/gitman/stoml /app/stoml
COPY utils/git-latest-version.sh ./
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w' "github.com/freshautomations/stoml@v$(sh git-latest-version.sh stoml)" && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/stoml" './go/bin/stoml' && \
    true; fi

FROM --platform=$BUILDPLATFORM upx-base AS go-stoml
COPY --from=go-stoml-build /app/go/bin/stoml ./
# RUN upx --best /app/stoml

FROM --platform=$BUILDPLATFORM golang:1.20.6-bookworm AS go-tomljson-build
WORKDIR /app
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/tomljson" './go/bin/tomljson' && \
    true; fi

FROM --platform=$BUILDPLATFORM upx-base AS go-tomljson
COPY --from=go-tomljson-build /app/go/bin/tomljson ./
# RUN upx --best /app/tomljson

FROM --platform=$BUILDPLATFORM golang:1.20.6-bookworm AS go-checkmake-build
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/checkmake /app/checkmake
WORKDIR /app/checkmake
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make

FROM --platform=$BUILDPLATFORM upx-base AS go-checkmake
COPY --from=go-checkmake-build /app/checkmake/checkmake ./
# RUN upx --best /app/checkmake

FROM --platform=$BUILDPLATFORM golang:1.20.6-bookworm AS go-editorconfig-checker-build
COPY --from=gitman /app/gitman/editorconfig-checker /app/editorconfig-checker
WORKDIR /app/editorconfig-checker
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" make build

FROM --platform=$BUILDPLATFORM upx-base AS go-editorconfig-checker
COPY --from=go-editorconfig-checker-build /app/editorconfig-checker/bin/ec ./
# RUN upx --best /app/ec

FROM bins-aggregator AS go-final
COPY --from=go-actionlint /app/actionlint ./
COPY --from=go-checkmake /app/checkmake ./
COPY --from=go-editorconfig-checker /app/ec ./
COPY --from=go-shfmt /app/shfmt ./
COPY --from=go-stoml /app/stoml ./
COPY --from=go-tomljson /app/tomljson ./
RUN /app/actionlint --help && \
    /app/checkmake --help && \
    /app/ec --help && \
    /app/shfmt --help && \
    /app/stoml --help && \
    /app/tomljson --help

# Rust #
FROM --platform=$BUILDPLATFORM rust:1.71.0-slim-bookworm AS rust-builder
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends file nodejs npm && \
    rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm
ARG BUILDARCH BUILDOS TARGETARCH TARGETOS
COPY utils/rust/get-target-machinename.sh ./
RUN if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
            "gcc-$(sh get-target-machinename.sh | tr '_' '-')-linux-gnu" \
            "g++-$(sh get-target-machinename.sh | tr '_' '-')-linux-gnu" \
            "libc6-dev-$TARGETARCH-cross" && \
        rm -rf /var/lib/apt/lists/* && \
    true; fi
COPY utils/rust/get-target-tripple.sh ./
RUN if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        rustup target add "$(sh get-target-tripple.sh)" && \
    true; fi
ENV CARGO_PROFILE_RELEASE_LTO=true \
    CARGO_PROFILE_RELEASE_PANIC=abort \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
    CARGO_PROFILE_RELEASE_OPT_LEVEL=s \
    RUSTFLAGS='-Cstrip=symbols'
COPY utils/cargo-packages.js ./utils/
COPY linters/Cargo.toml ./linters/
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        HOST_CC=gcc \
        HOST_CXX=g++ \
        AR_x86_64_unknown_linux_gnu="/usr/bin/$(sh get-target-machinename.sh)-linux-gnu-ar" \
        CC_x86_64_unknown_linux_gnu="/usr/bin/$(sh get-target-machinename.sh)-linux-gnu-gcc" \
        CXX_x86_64_unknown_linux_gnu="/usr/bin/$(sh get-target-machinename.sh)-linux-gnu-g++" \
        CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="/usr/bin/$(sh get-target-machinename.sh)-linux-gnu-gcc" \
        export HOST_CC HOST_CXX AR_x86_64_unknown_linux_gnu CC_x86_64_unknown_linux_gnu CXX_x86_64_unknown_linux_gnu CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER && \
    true; fi && \
    node utils/cargo-packages.js | while read -r package version; do \
        cargo install "$package" --force --version "$version" --root "$PWD/cargo" --target "$(sh get-target-tripple.sh)" && \
        file "/app/cargo/bin/$package" | grep "stripped" && \
        ! file "/app/cargo/bin/$package" | grep "not stripped" && \
    true; done

FROM --platform=$BUILDPLATFORM upx-base AS rust-upx
COPY --from=rust-builder /app/cargo/bin/dotenv-linter /app/cargo/bin/hush /app/cargo/bin/shellharden ./
# RUN parallel upx --best ::: /app/*

FROM bins-aggregator AS rust-final
COPY --from=rust-upx /app/dotenv-linter /app/hush /app/shellharden ./
RUN /app/dotenv-linter --help && \
    /app/hush --help && \
    /app/shellharden --help

# CircleCI CLI #
# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.1-slim AS circleci-base
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/circleci-cli /app/circleci-cli
WORKDIR /app/circleci-cli
RUN bash install.sh

FROM --platform=$BUILDPLATFORM upx-base AS circleci-upx
COPY --from=circleci-base /usr/local/bin/circleci ./
# RUN upx --best /app/circleci

FROM bins-aggregator AS circleci-final
COPY --from=circleci-upx /app/circleci ./
RUN /app/circleci --help

# Shell - loksh #
FROM debian:12.1-slim AS loksh-base
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential ca-certificates git meson && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/loksh /app/loksh
WORKDIR /app/loksh
RUN meson setup --prefix="$PWD/install" build && \
    ninja -C build install

FROM --platform=$BUILDPLATFORM upx-base AS loksh-upx
COPY --from=loksh-base /app/loksh/install/bin/ksh /app/loksh
# RUN upx --best /app/loksh

FROM bins-aggregator AS loksh-final
COPY --from=loksh-upx /app/loksh ./
COPY utils/sanity-check/shell-loksh.sh ./
ENV BINPREFIX=/app/
RUN sh shell-loksh.sh

# Shell - oksh #
FROM debian:12.1-slim AS oksh-base
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/oksh /app/oksh
WORKDIR /app/oksh
RUN ./configure && \
    make && \
    DESTDIR="$PWD/install" make install

FROM --platform=$BUILDPLATFORM upx-base AS oksh-upx
COPY --from=oksh-base /app/oksh/install/usr/local/bin/oksh ./
# RUN upx --best /app/oksh

FROM bins-aggregator AS oksh-final
COPY --from=oksh-upx /app/oksh ./
COPY utils/sanity-check/shell-oksh.sh ./
ENV BINPREFIX=/app/
RUN sh shell-oksh.sh

# ShellCheck #
FROM koalaman/shellcheck:v0.9.0 AS shellcheck-base

FROM --platform=$BUILDPLATFORM upx-base AS shellcheck-upx
COPY --from=shellcheck-base /bin/shellcheck ./
# RUN upx --best /app/shellcheck

FROM bins-aggregator AS shellcheck-final
COPY --from=shellcheck-base /bin/shellcheck ./
RUN /app/shellcheck --help

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint-base

FROM bins-aggregator AS hadolint-final
COPY --from=hadolint-base /bin/hadolint ./
# TODO: Run this when qemu bugs are resolved
# RUN /app/hadolint --help

# NodeJS/NPM #
FROM node:20.5.0-slim AS nodejs-base
WORKDIR /app
COPY linters/package.json linters/package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm && \
    npm prune --production

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS nodejs-final
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=nodejs-base /app/node_modules ./node_modules
COPY utils/optimize/.common.sh utils/optimize/optimize-nodejs.sh ./
RUN sh optimize-nodejs.sh

# Ruby/Gem #
FROM debian:12.1-slim AS ruby-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends bundler ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/*
COPY linters/Gemfile linters/Gemfile.lock ./
RUN BUNDLE_DISABLE_SHARED_GEMS=true BUNDLE_PATH__SYSTEM=false BUNDLE_PATH="$PWD/bundle" BUNDLE_GEMFILE="$PWD/Gemfile" bundle install

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS ruby-final
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=ruby-base /app/bundle ./bundle
COPY utils/optimize/.common.sh utils/optimize/optimize-bundle.sh ./
RUN sh optimize-bundle.sh

# Python/Pip #
FROM debian:12.1-slim AS python-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS python-final
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=python-base /app/python ./python
COPY utils/optimize/.common.sh utils/optimize/optimize-python.sh ./
RUN sh optimize-python.sh

# Composer #
FROM composer:2.5.8 AS composer-bin

# PHP/Composer #
FROM debian:12.1-slim AS composer-vendor-base
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates composer php php-cli php-mbstring php-zip && \
    rm -rf /var/lib/apt/lists/*
COPY linters/composer.json linters/composer.lock ./
RUN composer install --no-cache

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS composer-vendor-final
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=composer-vendor-base /app/vendor ./vendor
COPY utils/optimize/.common.sh utils/optimize/optimize-composer.sh ./
RUN sh optimize-composer.sh

# LinuxBrew - install #
# This is first part of HomeBrew, here we just install it
# We have to provide our custom `uname`, because HomeBrew prohibits installation on non-x64 Linux systems
FROM debian:12.1-slim AS brew-install
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
FROM debian:12.1-slim AS brew-rbenv
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
RUN --mount=type=cache,target=/.rbenv/cache \
    ruby_version_short="$(sed -E 's~_.*$~~' <portable-ruby-version)" && \
    rbenv install "$ruby_version_short" && \
    find /.rbenv/versions -mindepth 1 -maxdepth 1 -type d -not -name "$ruby_version_short" -exec rm -rf {} \;

# LinuxBrew - join brew & rbenv #
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS brew-link
WORKDIR /app
COPY --from=brew-install /home/linuxbrew /home/linuxbrew
COPY --from=brew-rbenv /.rbenv/versions /.rbenv/versions
RUN ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ruby_version_short="$(sed -E 's~_.+$~~' </home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ln -sf "/.rbenv/versions/$ruby_version_short" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full"

# LinuxBrew - final #
FROM debian:12.1-slim AS brew-final
WORKDIR /app
COPY --from=brew-link /home/linuxbrew /home/linuxbrew
COPY --from=brew-link /.rbenv/versions /.rbenv/versions
# TODO: individual sanity-check here

### Helpers ###

# Main CLI #
FROM node:20.5.0-slim AS cli-base
WORKDIR /app
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm && \
    npx modclean --patterns default:safe --run --error-halt && \
    npx node-prune
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build && \
    npm prune --production

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS cli-final
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=cli-base /app/cli ./cli
COPY --from=cli-base /app/node_modules ./node_modules
COPY utils/optimize/.common.sh utils/optimize/optimize-nodejs.sh ./
RUN sh optimize-nodejs.sh

# AZLint binaries #
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS azlint-bin
WORKDIR /app
RUN printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'node /app/cli/main.js $@' >azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >lint && \
    chmod a+x azlint fmt lint

# Pre-Final #
FROM debian:12.1-slim AS pre-final
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        curl git libxml2-utils \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python-is-python3 python3 python3-pip \
        bundler ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh && \
    rm -rf /var/lib/apt/lists/*
COPY --from=brew-final /home/linuxbrew /home/linuxbrew
COPY --from=brew-final /.rbenv/versions /.rbenv/versions
COPY --from=azlint-bin /app/azlint /app/fmt /app/lint /usr/bin/
WORKDIR /app
COPY VERSION.txt ./
WORKDIR /app/cli
COPY --from=cli-final /app/cli ./
COPY --from=cli-final /app/node_modules ./node_modules
COPY src/shell-dry-run.sh src/shell-dry-run-utils.sh ./
WORKDIR /app/linters
COPY linters/Gemfile linters/Gemfile.lock linters/composer.json ./
COPY --from=composer-vendor-final /app/vendor ./vendor
COPY --from=nodejs-final /app/node_modules ./node_modules
COPY --from=python-final /app/python ./python
COPY --from=ruby-final /app/bundle ./bundle
WORKDIR /app/linters/bin
COPY --from=composer-bin /usr/bin/composer ./
COPY --from=hadolint-final /app ./
COPY --from=go-final /app ./
COPY --from=rust-final /app ./
COPY --from=circleci-final /app ./
COPY --from=loksh-final /app ./
COPY --from=oksh-final /app ./
COPY --from=shellcheck-final /app ./
WORKDIR /app-tmp
ENV BUNDLE_DISABLE_SHARED_GEMS=true \
    BUNDLE_GEMFILE=/app/linters/Gemfile \
    BUNDLE_PATH__SYSTEM=false \
    BUNDLE_PATH=/app/linters/bundle \
    COMPOSER_ALLOW_SUPERUSER=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    PATH="$PATH:/app/linters/bin:/app/linters/python/bin:/app/linters/node_modules/.bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app/linters/python
COPY utils/sanity-check ./sanity-check
RUN touch /.dockerenv && \
    sh sanity-check/.main.sh

### Final stage ###

FROM debian:12.1-slim
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        curl git libxml2-utils \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python-is-python3 python3 python3-pip \
        bundler ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh && \
    rm -rf /var/lib/apt/lists/* /var/log/apt /var/log/dpkg* /var/cache/apt /usr/share/zsh/vendor-completions && \
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
ENV NODE_OPTIONS=--dns-result-order=ipv4first \
    PATH="$PATH:/app/bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1
USER azlint
WORKDIR /project
ENTRYPOINT ["azlint"]
CMD []
