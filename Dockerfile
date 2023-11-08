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
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends parallel upx-ucl >/dev/null && \
    rm -rf /var/lib/apt/lists/*

FROM debian:12.2-slim AS bins-aggregator
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends file >/dev/null && \
    rm -rf /var/lib/apt/lists/*

# Executable optimizer #
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS executable-optimizer-base
WORKDIR /app
COPY utils/rust/get-target-arch.sh ./
ARG TARGETARCH
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        "binutils-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" file moreutils >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/check-executable.sh ./

# Golang builder #
FROM --platform=$BUILDPLATFORM golang:1.21.4-bookworm AS go-builder-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends moreutils >/dev/null && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Gitman #
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS gitman-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends python3 python3-pip git >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY build-dependencies/gitman/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python --quiet
ENV PATH="/app/python/bin:$PATH" \
    PYTHONPATH=/app/python

# Dependency optimizer #
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS directory-optimizer-base
WORKDIR /optimizations
COPY utils/rust/get-target-arch.sh ./
ARG TARGETARCH
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        "binutils-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" file jq moreutils nodejs npm python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY build-dependencies/yq/requirements.txt ./yq/
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement yq/requirements.txt --target yq/python --quiet
COPY build-dependencies/yaml-minifier/package.json build-dependencies/yaml-minifier/package-lock.json ./yaml-minifier/
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm --no-progress --no-audit --quiet --prefix yaml-minifier
ENV PATH="/optimizations/yq/python/bin:$PATH" \
    PYTHONPATH=/optimizations/yq/python
COPY build-dependencies/yaml-minifier/minify-yaml.js ./yaml-minifier/
COPY utils/optimize/.common.sh ./
WORKDIR /app

### Components/Linters ###

# GoLang #
FROM --platform=$BUILDPLATFORM go-builder-base AS go-actionlint-build
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    chronic go install -ldflags='-s -w -buildid=' 'github.com/rhysd/actionlint/cmd/actionlint@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/actionlint" './go/bin/actionlint' && \
    true; fi

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS go-actionlint-optimize
COPY --from=go-actionlint-build /app/go/bin/actionlint ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/actionlint && \
    sh check-executable.sh bin/actionlint

FROM --platform=$BUILDPLATFORM upx-base AS go-actionlint-upx
COPY --from=go-actionlint-optimize /app/bin/actionlint ./
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

FROM --platform=$BUILDPLATFORM go-builder-base AS go-shfmt-build
COPY --from=go-shfmt-gitman /app/gitman/shfmt ./shfmt
COPY utils/git-latest-version.sh ./
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    chronic go install -ldflags='-s -w -buildid=' "mvdan.cc/sh/v3/cmd/shfmt@v$(sh git-latest-version.sh shfmt)" && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/shfmt" './go/bin/shfmt' && \
    true; fi

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS go-shfmt-optimize
COPY --from=go-shfmt-build /app/go/bin/shfmt ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/shfmt && \
    sh check-executable.sh bin/shfmt

FROM --platform=$BUILDPLATFORM upx-base AS go-shfmt-upx
COPY --from=go-shfmt-optimize /app/bin/shfmt ./
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

FROM --platform=$BUILDPLATFORM go-builder-base AS go-stoml-build
COPY --from=go-stoml-gitman /app/gitman/stoml ./stoml
COPY utils/git-latest-version.sh ./
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    chronic go install -ldflags='-s -w -buildid=' "github.com/freshautomations/stoml@v$(sh git-latest-version.sh stoml)" && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/stoml" './go/bin/stoml' && \
    true; fi

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS go-stoml-optimize
COPY --from=go-stoml-build /app/go/bin/stoml ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/stoml && \
    sh check-executable.sh bin/stoml

FROM --platform=$BUILDPLATFORM upx-base AS go-stoml-upx
COPY --from=go-stoml-optimize /app/bin/stoml ./
# RUN upx --best /app/stoml

FROM bins-aggregator AS go-stoml-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-stoml-upx /app/stoml ./
WORKDIR /app
COPY utils/sanity-check/go-stoml.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM go-builder-base AS go-tomljson-build
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    chronic go install -ldflags='-s -w -buildid=' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/tomljson" './go/bin/tomljson' && \
    true; fi

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS go-tomljson-optimize
COPY --from=go-tomljson-build /app/go/bin/tomljson ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/tomljson && \
    sh check-executable.sh bin/tomljson

FROM --platform=$BUILDPLATFORM upx-base AS go-tomljson-upx
COPY --from=go-tomljson-optimize /app/bin/tomljson ./
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
COPY utils/apply-git-patches.sh ./
COPY linters/git-patches/checkmake ./git-patches
RUN sh apply-git-patches.sh git-patches gitman/checkmake

FROM --platform=$BUILDPLATFORM go-builder-base AS go-checkmake-build
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends pandoc >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=go-checkmake-gitman /app/gitman/checkmake /app/checkmake
WORKDIR /app/checkmake
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make --silent

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS go-checkmake-optimize
COPY --from=go-checkmake-build /app/checkmake/checkmake ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/checkmake && \
    sh check-executable.sh bin/checkmake

FROM --platform=$BUILDPLATFORM upx-base AS go-checkmake-upx
COPY --from=go-checkmake-optimize /app/bin/checkmake ./
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
COPY utils/apply-git-patches.sh ./
COPY linters/git-patches/editorconfig-checker ./git-patches
RUN sh apply-git-patches.sh git-patches gitman/editorconfig-checker

FROM --platform=$BUILDPLATFORM go-builder-base AS go-editorconfig-checker-build
COPY --from=go-editorconfig-checker-gitman /app/gitman/editorconfig-checker /app/editorconfig-checker
WORKDIR /app/editorconfig-checker
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" make build --silent

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS go-editorconfig-checker-optimize
COPY --from=go-editorconfig-checker-build /app/editorconfig-checker/bin/ec ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/ec && \
    sh check-executable.sh bin/ec

FROM --platform=$BUILDPLATFORM upx-base AS go-editorconfig-checker-upx
COPY --from=go-editorconfig-checker-optimize /app/bin/ec ./
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
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS rust-dependencies-versions
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends jq python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY build-dependencies/yq/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python --quiet
ENV PATH="/app/python/bin:$PATH" \
    PYTHONPATH=/app/python
COPY linters/Cargo.toml ./
RUN tomlq -r '."dev-dependencies" | to_entries | map("\(.key) \(.value)")[]' Cargo.toml >cargo-dependencies.txt

# Rust #
FROM --platform=$BUILDPLATFORM rust:1.73.0-slim-bookworm AS rust-builder
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends file >/dev/null && \
    rm -rf /var/lib/apt/lists/*
ARG BUILDARCH BUILDOS TARGETARCH TARGETOS
COPY utils/rust/get-target-arch.sh ./
RUN if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
            "gcc-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" \
            "libc6-dev-$TARGETARCH-cross" >/dev/null && \
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
    RUSTFLAGS='-Cstrip=symbols -Clink-args=-Wl,--build-id=none'
COPY --from=rust-dependencies-versions /app/cargo-dependencies.txt ./
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        export \
            HOST_CC=gcc \
            HOST_CXX=g++ \
            "AR_$(sh get-target-arch.sh)_unknown_linux_gnu=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-ar" \
            "CC_$(sh get-target-arch.sh)_unknown_linux_gnu=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-gcc" \
            "CARGO_TARGET_$(sh get-target-arch.sh | tr '[:lower:]' '[:upper:]')_UNKNOWN_LINUX_GNU_LINKER=/usr/bin/$(sh get-target-arch.sh)-linux-gnu-gcc" \
        && \
    true; fi && \
    while read -r package version; do \
        cargo install "$package" --quiet --force --version "$version" --root "$PWD/cargo" --target "$(sh get-target-tripple.sh)" && \
    true; done <cargo-dependencies.txt

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS rust-optimize
COPY --from=rust-builder /app/cargo/bin ./bin/
# NOTE: `strip` is skipped, because it has no effect here
RUN find bin -type f -exec sh check-executable.sh {} \;

FROM --platform=$BUILDPLATFORM upx-base AS rust-upx
COPY --from=rust-optimize /app/bin ./
# RUN parallel upx --best ::: /app/*

FROM bins-aggregator AS rust-final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=rust-upx /app ./
WORKDIR /app
COPY utils/sanity-check/rust.sh ./sanity-check.sh
RUN sh sanity-check.sh

# CircleCI CLI #
FROM --platform=$BUILDPLATFORM gitman-base AS circleci-gitman
COPY linters/gitman-repos/circleci-cli/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.2-slim AS circleci-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends ca-certificates curl >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=circleci-gitman /app/gitman/circleci-cli /app/circleci-cli
WORKDIR /app/circleci-cli
RUN bash install.sh

FROM --platform=$BUILDPLATFORM upx-base AS circleci-upx
COPY --from=circleci-base /usr/local/bin/circleci ./
# RUN upx --best /app/circleci

FROM bins-aggregator AS circleci-final
COPY utils/sanity-check/circleci.sh ./sanity-check.sh
COPY --from=circleci-upx /app/circleci ./bin/
ENV BINPREFIX=/app/bin/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# Shell - loksh #
FROM --platform=$BUILDPLATFORM gitman-base AS shell-loksh-gitman
COPY linters/gitman-repos/shell-loksh/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM debian:12.2-slim AS shell-loksh-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends build-essential ca-certificates git meson >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=shell-loksh-gitman /app/gitman/loksh /app/loksh
WORKDIR /app/loksh
RUN CC="gcc -flto -fuse-linker-plugin -Wl,--build-id=none" \
    meson setup --fatal-meson-warnings --buildtype release --optimization s --strip --prefix="$PWD/install" build && \
    ninja --quiet -C build install && \
    mv /app/loksh/install/bin/ksh /app/loksh/install/bin/loksh

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS shell-loksh-optimize
COPY --from=shell-loksh-base /app/loksh/install/bin/loksh ./bin/
# NOTE: `strip` is skipped, because it has no effect here
RUN sh check-executable.sh bin/loksh

FROM --platform=$BUILDPLATFORM upx-base AS shell-loksh-upx
COPY --from=shell-loksh-optimize /app/bin/loksh ./
# RUN upx --best /app/loksh

FROM bins-aggregator AS shell-loksh-final
COPY --from=shell-loksh-upx /app/loksh ./bin/
COPY utils/sanity-check/shell-loksh.sh ./sanity-check.sh
ENV BINPREFIX=/app/bin/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# Shell - oksh #
FROM --platform=$BUILDPLATFORM gitman-base AS shell-oksh-gitman
COPY linters/gitman-repos/shell-oksh/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

FROM debian:12.2-slim AS shell-oksh-base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends build-essential >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=shell-oksh-gitman /app/gitman/oksh /app/oksh
WORKDIR /app/oksh
RUN ./configure --enable-small --enable-lto --cc='gcc -Os -Wl,--build-id=none' && \
    make --silent && \
    DESTDIR="$PWD/install" make install --silent

FROM --platform=$BUILDPLATFORM executable-optimizer-base AS shell-oksh-optimize
COPY --from=shell-oksh-base /app/oksh/install/usr/local/bin/oksh ./bin/
# NOTE: `strip` is skipped, because it has no effect here
RUN sh check-executable.sh bin/oksh

FROM --platform=$BUILDPLATFORM upx-base AS shell-oksh-upx
COPY --from=shell-oksh-optimize /app/bin/oksh ./
# RUN upx --best /app/oksh

FROM bins-aggregator AS shell-oksh-final
COPY --from=shell-oksh-upx /app/oksh ./bin/
COPY utils/sanity-check/shell-oksh.sh ./sanity-check.sh
ENV BINPREFIX=/app/bin/
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
FROM --platform=$BUILDPLATFORM node:21.1.0-slim AS nodejs-base
WORKDIR /app
COPY linters/package.json linters/package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm --no-progress --no-audit --quiet && \
    npm prune --production

FROM --platform=$BUILDPLATFORM directory-optimizer-base AS nodejs-optimize
COPY utils/optimize/optimize-nodejs.sh /optimizations/
COPY --from=nodejs-base /app/node_modules ./node_modules
RUN sh /optimizations/optimize-nodejs.sh

FROM debian:12.2-slim AS nodejs-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends nodejs npm >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/nodejs.sh ./sanity-check.sh
COPY --from=nodejs-optimize /app/node_modules ./node_modules
ENV BINPREFIX=/app/node_modules/.bin/
RUN sh sanity-check.sh

# Ruby/Gem #
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS ruby-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends bundler ruby ruby-build ruby-dev >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY linters/Gemfile linters/Gemfile.lock ./
RUN BUNDLE_DISABLE_SHARED_GEMS=true BUNDLE_PATH__SYSTEM=false BUNDLE_PATH="$PWD/bundle" BUNDLE_GEMFILE="$PWD/Gemfile" bundle install --quiet

FROM --platform=$BUILDPLATFORM directory-optimizer-base AS ruby-optimize
COPY utils/optimize/optimize-bundle.sh /optimizations/
COPY --from=ruby-base /app/bundle ./bundle
RUN sh /optimizations/optimize-bundle.sh

FROM debian:12.2-slim AS ruby-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends bundler ruby ruby-build ruby-dev >/dev/null && \
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
FROM debian:12.2-slim AS python-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python --quiet

FROM --platform=$BUILDPLATFORM directory-optimizer-base AS python-optimize
COPY utils/optimize/optimize-python.sh /optimizations/
COPY --from=python-base /app/python ./python
RUN sh /optimizations/optimize-python.sh

FROM debian:12.2-slim AS python-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends python-is-python3 python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/python.sh ./sanity-check.sh
COPY --from=python-optimize /app/python ./python
ENV BINPREFIX=/app/python/bin/ \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app/python
RUN sh sanity-check.sh

# Composer #
FROM composer:2.6.5 AS composer-bin

FROM --platform=$BUILDPLATFORM debian:12.2-slim AS composer-bin-optimize
WORKDIR /app
COPY --from=composer-bin /usr/bin/composer ./bin/
# TODO: optimize `composer` script

# PHP/Composer #
FROM debian:12.2-slim AS composer-vendor-base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends ca-certificates composer php php-mbstring php-zip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY linters/composer.json linters/composer.lock ./
RUN composer install --no-cache --quiet

FROM --platform=$BUILDPLATFORM directory-optimizer-base AS composer-vendor-optimize
COPY utils/optimize/optimize-composer.sh /optimizations/
COPY --from=composer-vendor-base /app/vendor ./vendor
RUN sh /optimizations/optimize-composer.sh

FROM debian:12.2-slim AS composer-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends ca-certificates php >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/composer.sh ./sanity-check.sh
COPY linters/composer.json ./linters/
COPY --from=composer-vendor-optimize /app/vendor ./linters/vendor
COPY --from=composer-bin-optimize /app/bin/composer ./bin/
ENV BINPREFIX=/app/bin/ \
    VENDORPREFIX=/app/linters/ \
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
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS brew-install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends ca-certificates curl git moreutils procps ruby >/dev/null && \
    if [ "$(uname -m)" != 'amd64' ]; then \
        dpkg --add-architecture amd64 && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends libc6:amd64 >/dev/null && \
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
ENV HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1
RUN NONINTERACTIVE=1 chronic bash brew-installer/install.sh && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew bundle --help --quiet >/dev/null && \
    find /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/ -maxdepth 1 -mindepth 1 | \
        sed -E 's~^.*/~~' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+(_[0-9]+)?$' \
        >'/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version' && \
    ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    rm -rf "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full" && \
    find /home/linuxbrew -type d -name .git -prune -exec rm -rf {} \;
# TODO: Resolve this homebrew version mismatch
# NOTE: Somehow HomeBrew is kinda broken currently
# Because it supposedly has 3.1.4 version in /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version
# But it has actually a 2.6.10_1 bundled ruby at /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/2.6.10_1

# LinuxBrew - rbenv #
FROM --platform=$BUILDPLATFORM gitman-base AS rbenv-gitman
COPY linters/gitman-repos/rbenv-install/gitman.yml ./
RUN --mount=type=cache,target=/root/.gitcache \
    gitman install --quiet

# We need to replace ruby bundled with HomeBrew, because it is only a x64 version
# Instead we install the same ruby version via rbenv and replace it in HomeBrew
FROM debian:12.2-slim AS brew-rbenv-install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        autoconf bison build-essential ca-certificates curl git moreutils \
        libffi-dev libgdbm-dev libncurses5-dev libreadline-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=rbenv-gitman /app/gitman/rbenv-installer ./rbenv-installer
ENV PATH="$PATH:/root/.rbenv/bin:/.rbenv/bin:/.rbenv/shims" \
    RBENV_ROOT=/.rbenv
RUN bash rbenv-installer/bin/rbenv-installer
COPY --from=brew-install /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version ./
RUN --mount=type=cache,target=/.rbenv/cache \
    ruby_version_short="$(sed -E 's~_.*$~~' <portable-ruby-version)" && \
    chronic rbenv install "$ruby_version_short"

FROM --platform=$BUILDPLATFORM debian:12.2-slim AS brew-link-rbenv
WORKDIR /app
COPY --from=brew-install /home/linuxbrew /home/linuxbrew
COPY --from=brew-rbenv-install /.rbenv/versions /.rbenv/versions
RUN ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ruby_version_short="$(sed -E 's~_.+$~~' </home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
    ln -sf "/.rbenv/versions/$ruby_version_short" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby/$ruby_version_full" && \
    find /.rbenv/versions -mindepth 1 -maxdepth 1 -type d -not -name "$ruby_version_short" -exec rm -rf {} \;

# In this stage we collect trace information about which files from linuxbrew and rbenv's ruby are actually neeeded
FROM debian:12.2-slim AS brew-optimize-trace
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends curl git inotify-tools psmisc >/dev/null && \
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
FROM --platform=$BUILDPLATFORM directory-optimizer-base AS brew-optimize
COPY utils/optimize/optimize-rbenv.sh utils/optimize/optimize-brew.sh /optimizations/
COPY --from=brew-optimize-trace /home/linuxbrew /home/linuxbrew
COPY --from=brew-optimize-trace /.rbenv/versions /.rbenv/versions
COPY --from=brew-optimize-trace /app/rbenv-list.txt /app/brew-list.txt ./
RUN sh /optimizations/optimize-rbenv.sh && \
    sh /optimizations/optimize-brew.sh

# Aggregate everything brew here and do one more sanity-check
FROM debian:12.2-slim AS brew-final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends curl git >/dev/null && \
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
FROM --platform=$BUILDPLATFORM node:21.1.0-slim AS cli-base
WORKDIR /app
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm --no-progress --no-audit --quiet && \
    npx modclean --patterns default:safe --run --error-halt && \
    npx node-prune
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build && \
    npm prune --production

FROM --platform=$BUILDPLATFORM directory-optimizer-base AS cli-optimize
COPY utils/optimize/optimize-nodejs.sh /optimizations/
COPY --from=cli-base /app/node_modules ./node_modules
RUN sh /optimizations/optimize-nodejs.sh

FROM --platform=$BUILDPLATFORM debian:12.2-slim AS cli-final
WORKDIR /app
COPY --from=cli-base /app/cli ./cli
COPY --from=cli-optimize /app/node_modules ./node_modules

# AZLint binaries #
FROM --platform=$BUILDPLATFORM debian:12.2-slim AS azlint-bin
WORKDIR /app
RUN printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'node /app/cli/main.js $@' >azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >lint && \
    chmod a+x azlint fmt lint

# Pre-Final #
FROM debian:12.2-slim AS pre-final
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        curl git libxml2-utils \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python-is-python3 python3 python3-pip \
        bundler ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh >/dev/null && \
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
COPY --from=composer-final /app/bin ./
COPY --from=haskell-final /app/bin ./
COPY --from=go-final /app/bin ./
COPY --from=rust-final /app/bin ./
COPY --from=circleci-final /app/bin ./
COPY --from=shell-loksh-final /app/bin ./
COPY --from=shell-oksh-final /app/bin ./
WORKDIR /app-tmp
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    PATH="$PATH:/app/linters/bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore
COPY utils/sanity-check/system.sh ./sanity-check.sh
RUN sh sanity-check.sh

### Final stage ###

FROM debian:12.2-slim
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        curl git libxml2-utils \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python-is-python3 python3 python3-pip \
        bundler ruby \
        ash bash dash ksh ksh93u+m mksh posh yash zsh >/dev/null && \
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
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1
USER azlint
WORKDIR /project
ENTRYPOINT ["azlint"]
CMD []
