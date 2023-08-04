#
# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# ^^^ Healhcheck doesn't make sense, because we are building a CLI tool, not server program
# checkov:skip=CKV_DOCKER_7:Disable FROM :latest
# ^^^ false positive for `--platform=$BUILDPLATFORM`

# hadolint global ignore=DL3042
# ^^^ Allow pip's cache, because we use it for cache mount

# Upx #
# TODO: Change upx target from ubuntu to debian when possible
# NOTE: `upx-ucl` is no longer available in debian 12 bookworm
# It is available in older versions, see https://packages.debian.org/bullseye/upx-ucl
# However, there were upgrade problems for bookworm, see https://tracker.debian.org/pkg/upx-ucl
FROM --platform=$BUILDPLATFORM ubuntu:23.10 AS upx-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/*

FROM debian:12.1-slim AS bins-aggregator
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends file && \
    rm -rf /var/lib/apt/lists/*

# Gitman #
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS gitman-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python --quiet
ENV PATH="/app/python/bin:$PATH" \
    PYTHONPATH=/app/python

### Components/Linters ###

# GoLang #
FROM --platform=$BUILDPLATFORM golang:1.20.7-bookworm AS go-actionlint-build
WORKDIR /app
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w -buildid=' 'github.com/rhysd/actionlint/cmd/actionlint@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/actionlint" './go/bin/actionlint' && \
    true; fi

FROM debian:12.1-slim AS go-actionlint-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends binutils file && \
    rm -rf /var/lib/apt/lists/*
COPY --from=go-actionlint-build /app/go/bin/actionlint ./
RUN strip --strip-all actionlint
COPY utils/check-executable.sh ./
RUN sh check-executable.sh actionlint

FROM --platform=$BUILDPLATFORM upx-base AS go-actionlint-upx
COPY --from=go-actionlint-optimize /app/actionlint ./
# RUN upx --best /app/actionlint

FROM bins-aggregator AS go-actionlint-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-actionlint-upx /app/actionlint ./
WORKDIR /app
COPY utils/sanity-check/go-actionlint.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman-base AS go-shfmt-gitman
COPY linters/gitman-repos/go-shfmt/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM --platform=$BUILDPLATFORM golang:1.20.7-bookworm AS go-shfmt-build
WORKDIR /app
COPY --from=go-shfmt-gitman /app/gitman/shfmt ./shfmt
COPY utils/git-latest-version.sh ./
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w -buildid=' "mvdan.cc/sh/v3/cmd/shfmt@v$(sh git-latest-version.sh shfmt)" && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/shfmt" './go/bin/shfmt' && \
    true; fi

FROM debian:12.1-slim AS go-shfmt-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends binutils file && \
    rm -rf /var/lib/apt/lists/*
COPY --from=go-shfmt-build /app/go/bin/shfmt ./
RUN strip --strip-all shfmt
COPY utils/check-executable.sh ./
RUN sh check-executable.sh shfmt

FROM --platform=$BUILDPLATFORM upx-base AS go-shfmt-upx
COPY --from=go-shfmt-optimize /app/shfmt ./
# RUN upx --best /app/shfmt

FROM bins-aggregator AS go-shfmt-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-shfmt-upx /app/shfmt ./
WORKDIR /app
COPY utils/sanity-check/go-shfmt.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman-base AS go-stoml-gitman
COPY linters/gitman-repos/go-stoml/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM --platform=$BUILDPLATFORM golang:1.20.7-bookworm AS go-stoml-build
WORKDIR /app
COPY --from=go-stoml-gitman /app/gitman/stoml ./stoml
COPY utils/git-latest-version.sh ./
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w -buildid=' "github.com/freshautomations/stoml@v$(sh git-latest-version.sh stoml)" && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/stoml" './go/bin/stoml' && \
    true; fi

FROM debian:12.1-slim AS go-stoml-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends binutils file && \
    rm -rf /var/lib/apt/lists/*
COPY --from=go-stoml-build /app/go/bin/stoml ./
RUN strip --strip-all stoml
COPY utils/check-executable.sh ./
RUN sh check-executable.sh stoml

FROM --platform=$BUILDPLATFORM upx-base AS go-stoml-upx
COPY --from=go-stoml-optimize /app/stoml ./
# RUN upx --best /app/stoml

FROM bins-aggregator AS go-stoml-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-stoml-upx /app/stoml ./
WORKDIR /app
COPY utils/sanity-check/go-stoml.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM golang:1.20.7-bookworm AS go-tomljson-build
WORKDIR /app
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    go install -ldflags='-s -w -buildid=' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/tomljson" './go/bin/tomljson' && \
    true; fi

FROM debian:12.1-slim AS go-tomljson-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends binutils file && \
    rm -rf /var/lib/apt/lists/*
COPY --from=go-tomljson-build /app/go/bin/tomljson ./
RUN strip --strip-all tomljson
COPY utils/check-executable.sh ./
RUN sh check-executable.sh tomljson

FROM --platform=$BUILDPLATFORM upx-base AS go-tomljson-upx
COPY --from=go-tomljson-optimize /app/tomljson ./
# RUN upx --best /app/tomljson

FROM bins-aggregator AS go-tomljson-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-tomljson-upx /app/tomljson ./
WORKDIR /app
COPY utils/sanity-check/go-tomljson.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman-base AS go-checkmake-gitman
COPY linters/gitman-repos/go-checkmake/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM --platform=$BUILDPLATFORM golang:1.20.7-bookworm AS go-checkmake-build
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/*
COPY --from=go-checkmake-gitman /app/gitman/checkmake /app/checkmake
WORKDIR /app/checkmake
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make

FROM --platform=$BUILDPLATFORM upx-base AS go-checkmake-upx
COPY --from=go-checkmake-build /app/checkmake/checkmake ./
# RUN upx --best /app/checkmake

FROM bins-aggregator AS go-checkmake-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-checkmake-upx /app/checkmake ./
WORKDIR /app
COPY utils/sanity-check/go-checkmake.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman-base AS go-editorconfig-checker-gitman
COPY linters/gitman-repos/go-editorconfig-checker/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM --platform=$BUILDPLATFORM golang:1.20.7-bookworm AS go-editorconfig-checker-build
COPY --from=go-editorconfig-checker-gitman /app/gitman/editorconfig-checker /app/editorconfig-checker
WORKDIR /app/editorconfig-checker
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" make build

FROM --platform=$BUILDPLATFORM upx-base AS go-editorconfig-checker-upx
COPY --from=go-editorconfig-checker-build /app/editorconfig-checker/bin/ec ./
# RUN upx --best /app/ec

FROM bins-aggregator AS go-editorconfig-checker-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-editorconfig-checker-upx /app/ec ./
WORKDIR /app
COPY utils/sanity-check/go-editorconfig-checker.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM bins-aggregator AS go-final
WORKDIR /app/bin
COPY --from=go-actionlint-final /app/bin/actionlint ./
COPY --from=go-checkmake-final /app/bin/checkmake ./
COPY --from=go-editorconfig-checker-final /app/bin/ec ./
COPY --from=go-shfmt-final /app/bin/shfmt ./
COPY --from=go-stoml-final /app/bin/stoml ./
COPY --from=go-tomljson-final /app/bin/tomljson ./

# Rust #
FROM --platform=$BUILDPLATFORM rust:1.71.0-slim-bookworm AS rust-builder
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends file nodejs npm && \
    rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm
ARG BUILDARCH BUILDOS TARGETARCH TARGETOS
COPY utils/rust/get-target-arch.sh ./
RUN if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends \
            "gcc-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" \
            "g++-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" \
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
# TODO: Add `CRATE_CC_NO_DEFAULTS=1` if compiler errors
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        export \
            HOST_CC=gcc \
            HOST_CXX=g++ \
            "AR_$(sh get-target-arch.sh)_unknown_linux_gnu=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-ar" \
            "CC_$(sh get-target-arch.sh)_unknown_linux_gnu=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-gcc" \
            "CXX_$(sh get-target-arch.sh)_unknown_linux_gnu=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-g++" \
            "CARGO_TARGET_$(sh get-target-arch.sh | tr '[:lower:]' '[:upper:]')_UNKNOWN_LINUX_GNU_LINKER=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-gcc" \
        && \
    true; fi && \
    node utils/cargo-packages.js | while read -r package version; do \
        cargo install "$package" --quiet --force --version "$version" --root "$PWD/cargo" --target "$(sh get-target-tripple.sh)" && \
        file "/app/cargo/bin/$package" | grep "stripped" && \
        ! file "/app/cargo/bin/$package" | grep "not stripped" && \
    true; done

FROM --platform=$BUILDPLATFORM upx-base AS rust-upx
COPY --from=rust-builder /app/cargo/bin/dotenv-linter /app/cargo/bin/hush /app/cargo/bin/shellharden ./
# RUN parallel upx --best ::: /app/*

FROM bins-aggregator AS rust-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=rust-upx /app/dotenv-linter /app/hush /app/shellharden ./
WORKDIR /app
COPY utils/sanity-check/rust.sh ./sanity-check.sh
RUN sh sanity-check.sh

# CircleCI CLI #
FROM --platform=$BUILDPLATFORM gitman-base AS circleci-gitman
COPY linters/gitman-repos/circleci-cli/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.1-slim AS circleci-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
COPY --from=circleci-gitman /app/gitman/circleci-cli /app/circleci-cli
WORKDIR /app/circleci-cli
RUN bash install.sh

FROM --platform=$BUILDPLATFORM upx-base AS circleci-upx
COPY --from=circleci-base /usr/local/bin/circleci ./
# RUN upx --best /app/circleci

FROM bins-aggregator AS circleci-final
COPY utils/sanity-check/circleci.sh ./sanity-check.sh
COPY --from=circleci-upx /app/circleci ./
ENV BINPREFIX=/app/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# Shell - loksh #
FROM --platform=$BUILDPLATFORM gitman-base AS loksh-gitman
COPY linters/gitman-repos/shell-loksh/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM debian:12.1-slim AS loksh-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends build-essential ca-certificates git meson && \
    rm -rf /var/lib/apt/lists/*
COPY --from=loksh-gitman /app/gitman/loksh /app/loksh
WORKDIR /app/loksh
RUN meson setup --prefix="$PWD/install" build && \
    ninja -C build install

FROM --platform=$BUILDPLATFORM upx-base AS loksh-upx
COPY --from=loksh-base /app/loksh/install/bin/ksh /app/loksh
# RUN upx --best /app/loksh

FROM bins-aggregator AS loksh-final
COPY --from=loksh-upx /app/loksh ./
COPY utils/sanity-check/shell-loksh.sh ./sanity-check.sh
ENV BINPREFIX=/app/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# Shell - oksh #
FROM --platform=$BUILDPLATFORM gitman-base AS oksh-gitman
COPY linters/gitman-repos/shell-oksh/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM debian:12.1-slim AS oksh-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*
COPY --from=oksh-gitman /app/gitman/oksh /app/oksh
WORKDIR /app/oksh
RUN ./configure && \
    make && \
    DESTDIR="$PWD/install" make install

FROM --platform=$BUILDPLATFORM upx-base AS oksh-upx
COPY --from=oksh-base /app/oksh/install/usr/local/bin/oksh ./
# RUN upx --best /app/oksh

FROM bins-aggregator AS oksh-final
COPY --from=oksh-upx /app/oksh ./
COPY utils/sanity-check/shell-oksh.sh ./sanity-check.sh
ENV BINPREFIX=/app/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# ShellCheck #
FROM koalaman/shellcheck:v0.9.0 AS shellcheck-base

FROM --platform=$BUILDPLATFORM upx-base AS shellcheck-upx
COPY --from=shellcheck-base /bin/shellcheck ./
# RUN upx --best /app/shellcheck

FROM bins-aggregator AS shellcheck-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=shellcheck-upx /app/shellcheck ./
WORKDIR /app
COPY utils/sanity-check/haskell-shellcheck.sh ./sanity-check.sh
RUN sh sanity-check.sh

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint-base

FROM --platform=$BUILDPLATFORM upx-base AS hadolint-upx
COPY --from=hadolint-base /bin/hadolint ./
# RUN upx --best /app/hadolint

FROM bins-aggregator AS hadolint-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=hadolint-upx /app/hadolint ./
WORKDIR /app
COPY utils/sanity-check/haskell-hadolint.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM bins-aggregator AS haskell-final
WORKDIR /app/bin
COPY --from=hadolint-final /app/bin/hadolint ./
COPY --from=shellcheck-final /app/bin/shellcheck ./

# NodeJS/NPM #
FROM --platform=$BUILDPLATFORM node:20.5.0-slim AS nodejs-base
WORKDIR /app
COPY linters/package.json linters/package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm && \
    npm prune --production

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS nodejs-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=nodejs-base /app/node_modules ./node_modules
COPY utils/optimize/.common.sh utils/optimize/optimize-nodejs.sh ./
RUN sh optimize-nodejs.sh

FROM debian:12.1-slim AS nodejs-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/nodejs.sh ./sanity-check.sh
COPY --from=nodejs-optimize /app/node_modules ./node_modules
ENV BINPREFIX=/app/node_modules/.bin/
RUN sh sanity-check.sh

# Ruby/Gem #
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS ruby-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends bundler ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/*
COPY linters/Gemfile linters/Gemfile.lock ./
RUN BUNDLE_DISABLE_SHARED_GEMS=true BUNDLE_PATH__SYSTEM=false BUNDLE_PATH="$PWD/bundle" BUNDLE_GEMFILE="$PWD/Gemfile" bundle install --quiet

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS ruby-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=ruby-base /app/bundle ./bundle
COPY utils/optimize/.common.sh utils/optimize/optimize-bundle.sh ./
RUN sh optimize-bundle.sh

FROM debian:12.1-slim AS ruby-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends bundler ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/ruby.sh ./sanity-check.sh
COPY linters/Gemfile ./
COPY --from=ruby-optimize /app/bundle ./bundle
ENV BUNDLE_DISABLE_SHARED_GEMS=true \
    BUNDLE_GEMFILE="/app/Gemfile" \
    BUNDLE_PATH__SYSTEM=false \
    BUNDLE_PATH="/app/bundle"
RUN sh sanity-check.sh

# Python/Pip #
FROM debian:12.1-slim AS python-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS python-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=python-base /app/python ./python
COPY utils/optimize/.common.sh utils/optimize/optimize-python.sh ./
RUN sh optimize-python.sh

FROM debian:12.1-slim AS python-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends python-is-python3 python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/python.sh ./sanity-check.sh
COPY --from=python-optimize /app/python ./python
ENV BINPREFIX=/app/python/bin/ \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app/python
RUN sh sanity-check.sh

# Composer #
FROM composer:2.5.8 AS composer-bin

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS composer-bin-optimize
WORKDIR /app
COPY --from=composer-bin /usr/bin/composer ./
# TODO: optimize `composer` script

# PHP/Composer #
FROM debian:12.1-slim AS composer-vendor-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends ca-certificates composer php php-mbstring php-zip && \
    rm -rf /var/lib/apt/lists/*
COPY linters/composer.json linters/composer.lock ./
RUN composer install --no-cache --quiet

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS composer-vendor-optimize
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends jq moreutils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=composer-vendor-base /app/vendor ./vendor
COPY utils/optimize/.common.sh utils/optimize/optimize-composer.sh ./
RUN sh optimize-composer.sh

FROM debian:12.1-slim AS composer-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends ca-certificates php && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/composer.sh ./sanity-check.sh
COPY linters/composer.json ./linters/
COPY --from=composer-vendor-optimize /app/vendor ./linters/vendor
COPY --from=composer-bin-optimize /app/composer ./
ENV BINPREFIX=/app/ \
    COMPOSER_ALLOW_SUPERUSER=1
RUN sh sanity-check.sh

# LinuxBrew - gitman #
FROM --platform=$BUILDPLATFORM gitman-base AS brew-gitman
COPY linters/gitman-repos/brew-install/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

# LinuxBrew - install #
# This is first part of HomeBrew, here we just install it
# We have to provide our custom `uname`, because HomeBrew prohibits installation on non-x64 Linux systems
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS brew-install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends ca-certificates curl git procps ruby && \
    if [ "$(uname -m)" != 'amd64' ]; then \
        dpkg --add-architecture amd64 && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends libc6:amd64 && \
    true; fi && \
    rm -rf /var/lib/apt/lists/* && \
    touch /.dockerenv
COPY utils/uname-x64.sh /usr/bin/uname-x64
RUN if [ "$(uname -m)" != 'amd64' ]; then \
        chmod a+x /usr/bin/uname-x64 && \
        mv /usr/bin/uname /usr/bin/uname-bak && \
        mv /usr/bin/uname-x64 /usr/bin/uname && \
    true; fi
COPY --from=brew-gitman /app/gitman/brew-installer ./brew-installer
RUN NONINTERACTIVE=1 bash brew-installer/install.sh && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew update && \
    brew bundle --help && \
    ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    rm -rf "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full" && \
    find /home/linuxbrew -type d -name .git -prune -exec rm -rf {} \;

# LinuxBrew - rbenv #
FROM --platform=$BUILDPLATFORM gitman-base AS rbenv-gitman
COPY linters/gitman-repos/rbenv-install/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

# We need to replace ruby bundled with HomeBrew, because it is only a x64 version
# Instead we install the same ruby version via rbenv and replace it in HomeBrew
FROM debian:12.1-slim AS brew-rbenv-install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends \
        autoconf bison build-essential ca-certificates curl git \
        libffi-dev libgdbm-dev libncurses5-dev libreadline-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*
COPY --from=rbenv-gitman /app/gitman/rbenv-installer ./rbenv-installer
ENV PATH="$PATH:/root/.rbenv/bin:/.rbenv/bin:/.rbenv/shims" \
    RBENV_ROOT=/.rbenv
RUN bash rbenv-installer/bin/rbenv-installer
COPY --from=brew-install /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version ./
RUN --mount=type=cache,target=/.rbenv/cache \
    ruby_version_short="$(sed -E 's~_.*$~~' <portable-ruby-version)" && \
    rbenv install "$ruby_version_short"

FROM --platform=$BUILDPLATFORM debian:12.1-slim AS brew-link-rbenv
WORKDIR /app
COPY --from=brew-install /home/linuxbrew /home/linuxbrew
COPY --from=brew-rbenv-install /.rbenv/versions /.rbenv/versions
RUN ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ruby_version_short="$(sed -E 's~_.+$~~' </home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ln -sf "/.rbenv/versions/$ruby_version_short" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full" && \
    find /.rbenv/versions -mindepth 1 -maxdepth 1 -type d -not -name "$ruby_version_short" -exec rm -rf {} \;

# In this stage we collect trace information about which files from linuxbrew and rbenv's ruby are actually neeeded
FROM debian:12.1-slim AS brew-optimize-trace
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends curl git inotify-tools psmisc && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/brew.sh ./sanity-check.sh
COPY --from=brew-link-rbenv /home/linuxbrew /home/linuxbrew
COPY --from=brew-link-rbenv /.rbenv/versions /.rbenv/versions
ENV BINPREFIX=/home/linuxbrew/.linuxbrew/bin/ \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1
RUN touch /.dockerenv rbenv-list.txt brew-list.txt && \
    inotifywait --daemon --recursive --event access /.rbenv/versions --outfile rbenv-list.txt --format '%w%f' && \
    inotifywait --daemon --recursive --event access /home/linuxbrew --outfile brew-list.txt --format '%w%f' && \
    sh sanity-check.sh && \
    killall inotifywait

# Use trace information to optimize rbenv and brew directories
FROM --platform=$BUILDPLATFORM debian:12.1-slim AS brew-optimize
WORKDIR /app
COPY utils/optimize/.common.sh utils/optimize/optimize-rbenv.sh utils/optimize/optimize-brew.sh ./
COPY --from=brew-optimize-trace /home/linuxbrew /home/linuxbrew
COPY --from=brew-optimize-trace /.rbenv/versions /.rbenv/versions
COPY --from=brew-optimize-trace /app/rbenv-list.txt /app/brew-list.txt ./
RUN sh optimize-rbenv.sh && \
    sh optimize-brew.sh

# Aggregate everything brew here and do one more sanity-check
FROM debian:12.1-slim AS brew-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends curl git && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/brew.sh ./sanity-check.sh
COPY --from=brew-optimize /home/linuxbrew /home/linuxbrew
COPY --from=brew-optimize /.rbenv/versions /.rbenv/versions
ENV BINPREFIX=/home/linuxbrew/.linuxbrew/bin/ \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1
RUN touch /.dockerenv && \
    sh sanity-check.sh

### Helpers ###

# Main CLI #
FROM --platform=$BUILDPLATFORM node:20.5.0-slim AS cli-base
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
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends jq moreutils && \
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
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends \
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
COPY --from=composer-final /app/linters/vendor ./vendor
COPY --from=nodejs-final /app/node_modules ./node_modules
COPY --from=python-final /app/python ./python
COPY --from=ruby-final /app/bundle ./bundle
WORKDIR /app/linters/bin
COPY --from=composer-final /app/composer ./
COPY --from=haskell-final /app/bin ./
COPY --from=go-final /app/bin ./
COPY --from=rust-final /app/bin ./
COPY --from=circleci-final /app ./
COPY --from=loksh-final /app ./
COPY --from=oksh-final /app ./
WORKDIR /app-tmp
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    PATH="$PATH:/app/linters/bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1
COPY utils/sanity-check/system.sh ./sanity-check.sh
RUN sh sanity-check.sh

### Final stage ###

FROM debian:12.1-slim
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -qq --yes --no-install-recommends \
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
