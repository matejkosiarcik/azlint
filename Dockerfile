#
# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# ^^^ Healhcheck doesn't make sense, because we are building a CLI tool, not server program
# checkov:skip=CKV_DOCKER_7:Disable FROM :latest
# ^^^ false positive for `--platform=$BUILDPLATFORM`

# Upx #
# TODO: Change upx target from ubuntu to debian when possible
# NOTE: `upx-ucl` is no longer available in debian 12 bookworm
# It is available in older versions, see https://packages.debian.org/bullseye/upx-ucl
# However, there were upgrade problems for bookworm, see https://tracker.debian.org/pkg/upx-ucl
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS helper--upx--final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        parallel upx-ucl >/dev/null && \
    rm -rf /var/lib/apt/lists/*

FROM debian:12.9-slim AS bins-aggregator--base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        file >/dev/null && \
    rm -rf /var/lib/apt/lists/*

# Executable optimizer #
FROM --platform=$BUILDPLATFORM debian:12.9-slim AS executable-optimizer--base
WORKDIR /app
COPY utils/rust/get-target-arch.sh ./
ARG TARGETARCH
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        "binutils-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" file moreutils >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/validate-executable.sh ./

# Golang builder #
FROM --platform=$BUILDPLATFORM golang:1.23-bookworm AS go-builder--base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        moreutils >/dev/null && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Gitman #
FROM --platform=$BUILDPLATFORM debian:12.9-slim AS gitman--base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        python3 python3-pip git >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY build-dependencies/gitman/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python-vendor --quiet
ENV PATH="/app/python-vendor/bin:$PATH" \
    PYTHONPATH=/app/python-vendor

# LinuxBrew - rbenv #
FROM --platform=$BUILDPLATFORM gitman--base AS rbenv--gitman
COPY linters/gitman-repos/rbenv-install/gitman.yml ./
RUN gitman install --quiet && \
    find . -type d -name .git -prune -exec rm -rf {} \;

# Dependency optimizer #
FROM --platform=$BUILDPLATFORM debian:12.9-slim AS directory-optimizer--base
WORKDIR /optimizations
COPY utils/rust/get-target-arch.sh ./
ARG TARGETARCH
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        "binutils-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" file jq moreutils nodejs npm python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY build-dependencies/yq/requirements.txt ./yq/
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement yq/requirements.txt --target yq/python-vendor --quiet
COPY build-dependencies/yaml-minifier/package.json build-dependencies/yaml-minifier/package-lock.json ./yaml-minifier/
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm --no-progress --no-audit --no-fund --loglevel=error --prefix yaml-minifier
ENV PATH="/optimizations/yq/python-vendor/bin:$PATH" \
    PYTHONPATH=/optimizations/yq/python-vendor
COPY build-dependencies/yaml-minifier/minify-yaml.js ./yaml-minifier/
COPY utils/optimize/.common.sh ./
WORKDIR /app

### Components/Linters ###

# GoLang #
FROM --platform=$BUILDPLATFORM go-builder--base AS linters--go--actionlint--build
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    chronic go install -ldflags='-s -w -buildid=' 'github.com/rhysd/actionlint/cmd/actionlint@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/actionlint" './go/bin/actionlint' && \
    true; fi

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--go--actionlint--optimize
COPY --from=linters--go--actionlint--build /app/go/bin/actionlint ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/actionlint && \
    sh validate-executable.sh bin/actionlint

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--go--actionlint--upx
COPY --from=linters--go--actionlint--optimize /app/bin/actionlint ./
# RUN upx --best /app/actionlint

FROM bins-aggregator--base AS linters--go--actionlint--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=linters--go--actionlint--upx /app/actionlint ./
WORKDIR /app
COPY utils/sanity-check/go-actionlint.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman--base AS linters--go--shfmt--gitman
COPY linters/gitman-repos/go-shfmt/gitman.yml ./
RUN gitman install --quiet

FROM --platform=$BUILDPLATFORM go-builder--base AS linters--go--shfmt--build
COPY --from=linters--go--shfmt--gitman /app/gitman/shfmt ./shfmt
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

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--go--shfmt--optimize
COPY --from=linters--go--shfmt--build /app/go/bin/shfmt ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/shfmt && \
    sh validate-executable.sh bin/shfmt

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--go--shfmt--upx
COPY --from=linters--go--shfmt--optimize /app/bin/shfmt ./
# RUN upx --best /app/shfmt

FROM bins-aggregator--base AS linters--go--shfmt--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=linters--go--shfmt--upx /app/shfmt ./
WORKDIR /app
COPY utils/sanity-check/go-shfmt.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman--base AS linters--go--stoml--gitman
COPY linters/gitman-repos/go-stoml/gitman.yml ./
RUN gitman install --quiet

FROM --platform=$BUILDPLATFORM go-builder--base AS linters--go--stoml--build
COPY --from=linters--go--stoml--gitman /app/gitman/stoml ./stoml
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

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--go--stoml--optimize
COPY --from=linters--go--stoml--build /app/go/bin/stoml ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/stoml && \
    sh validate-executable.sh bin/stoml

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--go--stoml--upx
COPY --from=linters--go--stoml--optimize /app/bin/stoml ./
# RUN upx --best /app/stoml

FROM bins-aggregator--base AS linters--go--stoml--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=linters--go--stoml--upx /app/stoml ./
WORKDIR /app
COPY utils/sanity-check/go-stoml.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM go-builder--base AS linters--go--tomljson--build
ARG BUILDARCH TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    --mount=type=cache,target=/app/go/pkg \
    export GOPATH="$PWD/go" GOOS="$TARGETOS" GOARCH="$TARGETARCH" GO111MODULE=on && \
    chronic go install -ldflags='-s -w -buildid=' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        mv "./go/bin/linux_$TARGETARCH/tomljson" './go/bin/tomljson' && \
    true; fi

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--go--tomljson--optimize
COPY --from=linters--go--tomljson--build /app/go/bin/tomljson ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/tomljson && \
    sh validate-executable.sh bin/tomljson

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--go--tomljson--upx
COPY --from=linters--go--tomljson--optimize /app/bin/tomljson ./
# RUN upx --best /app/tomljson

FROM bins-aggregator--base AS linters--go--tomljson--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=linters--go--tomljson--upx /app/tomljson ./
WORKDIR /app
COPY utils/sanity-check/go-tomljson.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman--base AS linters--go--checkmake--gitman
COPY linters/gitman-repos/go-checkmake/gitman.yml ./
RUN gitman install --quiet && \
    find . -type d -name .git -prune -exec rm -rf {} \;
COPY utils/apply-git-patches.sh ./
COPY linters/git-patches/checkmake ./git-patches
RUN sh apply-git-patches.sh git-patches gitman/checkmake

FROM --platform=$BUILDPLATFORM go-builder--base AS linters--go--checkmake--build
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        pandoc >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=linters--go--checkmake--gitman /app/gitman/checkmake /app/checkmake
WORKDIR /app/checkmake
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make --silent

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS go-checkmake--optimize
COPY --from=linters--go--checkmake--build /app/checkmake/checkmake ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/checkmake && \
    sh validate-executable.sh bin/checkmake

FROM --platform=$BUILDPLATFORM helper--upx--final AS go-checkmake--upx
COPY --from=go-checkmake--optimize /app/bin/checkmake ./
# RUN upx --best /app/checkmake

FROM bins-aggregator--base AS linters--go--checkmake--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=go-checkmake--upx /app/checkmake ./
WORKDIR /app
COPY utils/sanity-check/go-checkmake.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM --platform=$BUILDPLATFORM gitman--base AS linters--go--editorconfig-checker--gitman
COPY linters/gitman-repos/go-editorconfig-checker/gitman.yml ./
RUN gitman install --quiet && \
    find . -type d -name .git -prune -exec rm -rf {} \;
COPY utils/apply-git-patches.sh ./
COPY linters/git-patches/editorconfig-checker ./git-patches
RUN sh apply-git-patches.sh git-patches gitman/editorconfig-checker

FROM --platform=$BUILDPLATFORM go-builder--base AS linters--go--editorconfig-checker--build
COPY --from=linters--go--editorconfig-checker--gitman /app/gitman/editorconfig-checker /app/editorconfig-checker
WORKDIR /app/editorconfig-checker
ARG TARGETARCH TARGETOS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" make build --silent

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--go--editorconfig-checker--optimize
COPY --from=linters--go--editorconfig-checker--build /app/editorconfig-checker/bin/ec ./bin/
ARG TARGETARCH
RUN "$(sh get-target-arch.sh)-linux-gnu-strip" --strip-all bin/ec && \
    sh validate-executable.sh bin/ec

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--go--editorconfig-checker--upx
COPY --from=linters--go--editorconfig-checker--optimize /app/bin/ec ./
# RUN upx --best /app/ec

FROM bins-aggregator--base AS linters--go--editorconfig-checker--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=linters--go--editorconfig-checker--upx /app/ec ./
WORKDIR /app
COPY utils/sanity-check/go-editorconfig-checker.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM bins-aggregator--base AS linters--go--final
WORKDIR /app/bin
COPY --from=linters--go--actionlint--final /app/bin/actionlint ./
COPY --from=linters--go--checkmake--final /app/bin/checkmake ./
COPY --from=linters--go--editorconfig-checker--final /app/bin/ec ./
COPY --from=linters--go--shfmt--final /app/bin/shfmt ./
COPY --from=linters--go--stoml--final /app/bin/stoml ./
COPY --from=linters--go--tomljson--final /app/bin/tomljson ./

# Rust #
FROM --platform=$BUILDPLATFORM debian:12.9-slim AS linters--rust--dependencies
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        jq python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY build-dependencies/yq/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python-vendor --quiet
ENV PATH="/app/python-vendor/bin:$PATH" \
    PYTHONPATH=/app/python-vendor
COPY linters/Cargo.toml ./
RUN tomlq -r '."dev-dependencies" | to_entries | map("\(.key) \(.value)")[]' Cargo.toml >cargo-dependencies.txt

# Rust #
FROM --platform=$BUILDPLATFORM rust:1.84.1-slim-bookworm AS linters--rust--build
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        file >/dev/null && \
    rm -rf /var/lib/apt/lists/*
ARG BUILDARCH BUILDOS TARGETARCH TARGETOS
COPY utils/rust/get-target-arch.sh ./
RUN if [ "$BUILDARCH" != "$TARGETARCH" ]; then \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
            "gcc-$(sh get-target-arch.sh | tr '_' '-')-linux-gnu" "libc6-dev-$TARGETARCH-cross" >/dev/null && \
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
COPY --from=linters--rust--dependencies /app/cargo-dependencies.txt ./
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

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--rust--optimize
COPY --from=linters--rust--build /app/cargo/bin ./bin/
# NOTE: `strip` is skipped, because it has no effect here
RUN find bin -type f -exec sh validate-executable.sh {} \;

FROM --platform=$BUILDPLATFORM helper--upx--final AS rust--upx
COPY --from=linters--rust--optimize /app/bin ./
# RUN parallel upx --best ::: /app/*

FROM bins-aggregator--base AS linters--rust--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=rust--upx /app ./
WORKDIR /app
COPY utils/sanity-check/rust.sh ./sanity-check.sh
RUN sh sanity-check.sh

# CircleCI CLI #
FROM --platform=$BUILDPLATFORM gitman--base AS linters--circleci--gitman
COPY linters/gitman-repos/circleci-cli/gitman.yml ./
RUN gitman install --quiet && \
    find . -type d -name .git -prune -exec rm -rf {} \;

# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.9-slim AS linters--circleci--base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        ca-certificates curl >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=linters--circleci--gitman /app/gitman/circleci-cli /app/circleci-cli
WORKDIR /app/circleci-cli
RUN bash install.sh

FROM --platform=$BUILDPLATFORM helper--upx--final AS circleci--upx
COPY --from=linters--circleci--base /usr/local/bin/circleci ./
# RUN upx --best /app/circleci

FROM bins-aggregator--base AS linters--circleci--final
COPY utils/sanity-check/circleci.sh ./sanity-check.sh
COPY --from=circleci--upx /app/circleci ./bin/
ENV BINPREFIX=/app/bin/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# Shell - loksh #
FROM --platform=$BUILDPLATFORM gitman--base AS linters--shell--loksh--gitman
COPY linters/gitman-repos/shell-loksh/gitman.yml ./
RUN gitman install --quiet

FROM debian:12.9-slim AS linters--shell--loksh--base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        build-essential ca-certificates git meson >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=linters--shell--loksh--gitman /app/gitman/loksh /app/loksh
WORKDIR /app/loksh
RUN CC="gcc -flto -fuse-linker-plugin -Wl,--build-id=none" \
    meson setup --fatal-meson-warnings --buildtype release --optimization s --strip --prefix="$PWD/install" build && \
    ninja --quiet -C build install && \
    mv /app/loksh/install/bin/ksh /app/loksh/install/bin/loksh

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS shell-loksh--optimize
COPY --from=linters--shell--loksh--base /app/loksh/install/bin/loksh ./bin/
# NOTE: `strip` is skipped, because it has no effect here
RUN sh validate-executable.sh bin/loksh

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--shell--loksh--upx
COPY --from=shell-loksh--optimize /app/bin/loksh ./
# RUN upx --best /app/loksh

FROM bins-aggregator--base AS linters--shell--loksh--final
COPY --from=linters--shell--loksh--upx /app/loksh ./bin/
COPY utils/sanity-check/shell-loksh.sh ./sanity-check.sh
ENV BINPREFIX=/app/bin/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# Shell - oksh #
FROM --platform=$BUILDPLATFORM gitman--base AS linters--shell--oksh--gitman
COPY linters/gitman-repos/shell-oksh/gitman.yml ./
RUN gitman install --quiet && \
    find . -type d -name .git -prune -exec rm -rf {} \;

FROM debian:12.9-slim AS linters--shell--oksh--base
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        build-essential >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=linters--shell--oksh--gitman /app/gitman/oksh /app/oksh
WORKDIR /app/oksh
RUN ./configure --enable-small --enable-lto --cc='gcc -Os -Wl,--build-id=none' && \
    make --silent && \
    DESTDIR="$PWD/install" make install --silent

FROM --platform=$BUILDPLATFORM executable-optimizer--base AS linters--shell--oksh--optimize
COPY --from=linters--shell--oksh--base /app/oksh/install/usr/local/bin/oksh ./bin/
# NOTE: `strip` is skipped, because it has no effect here
RUN sh validate-executable.sh bin/oksh

FROM --platform=$BUILDPLATFORM helper--upx--final AS linters--shell--oksh--upx
COPY --from=linters--shell--oksh--optimize /app/bin/oksh ./
# RUN upx --best /app/oksh

FROM bins-aggregator--base AS linters--shell-oksh--final
COPY --from=linters--shell--oksh--upx /app/oksh ./bin/
COPY utils/sanity-check/shell-oksh.sh ./sanity-check.sh
ENV BINPREFIX=/app/bin/
RUN sh sanity-check.sh && \
    rm -f sanity-check.sh

# ShellCheck #
FROM koalaman/shellcheck:v0.10.0 AS linters--shellcheck--base

FROM --platform=$BUILDPLATFORM helper--upx--final AS shellcheck--upx
COPY --from=linters--shellcheck--base /bin/shellcheck ./
# RUN upx --best /app/shellcheck

FROM bins-aggregator--base AS linters--shellcheck--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=shellcheck--upx /app/shellcheck ./
WORKDIR /app
COPY utils/sanity-check/haskell-shellcheck.sh ./sanity-check.sh
RUN sh sanity-check.sh

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS linters--hadolint--base

FROM --platform=$BUILDPLATFORM helper--upx--final AS hadolint--upx
COPY --from=linters--hadolint--base /bin/hadolint ./
# RUN upx --best /app/hadolint

FROM bins-aggregator--base AS linters--hadolint--final
WORKDIR /app/bin
ENV BINPREFIX=/app/bin/
COPY --from=hadolint--upx /app/hadolint ./
WORKDIR /app
COPY utils/sanity-check/haskell-hadolint.sh ./sanity-check.sh
RUN sh sanity-check.sh

FROM bins-aggregator--base AS linters--haskell--final
WORKDIR /app/bin
COPY --from=linters--hadolint--final /app/bin/hadolint ./
COPY --from=linters--shellcheck--final /app/bin/shellcheck ./

# NodeJS/NPM #
FROM --platform=$BUILDPLATFORM node:23.7.0-slim AS linters--nodejs--base
WORKDIR /app
COPY linters/package.json linters/package-lock.json ./
COPY linters/npm-patches/ ./npm-patches/
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm --no-progress --no-audit --no-fund --loglevel=error && \
    npm prune --production

FROM --platform=$BUILDPLATFORM directory-optimizer--base AS linters--nodejs--optimize
COPY utils/optimize/optimize-nodejs.sh /optimizations/
COPY --from=linters--nodejs--base /app/node_modules ./node_modules
RUN sh /optimizations/optimize-nodejs.sh

FROM debian:12.9-slim AS linters--nodejs--final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        nodejs npm >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/nodejs.sh ./sanity-check.sh
COPY --from=linters--nodejs--optimize /app/node_modules ./node_modules
ENV BINPREFIX=/app/node_modules/.bin/
RUN sh sanity-check.sh

# Ruby/Gem #

# Install ruby with rbenv
FROM debian:12.9-slim AS rbenv--install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        autoconf bison build-essential ca-certificates curl git moreutils \
        libffi-dev libgdbm-dev libncurses5-dev libreadline-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=rbenv--gitman /app/gitman/rbenv-installer ./rbenv-installer
ENV PATH="$PATH:/root/.rbenv/bin:/.rbenv/bin:/.rbenv/shims" \
    RBENV_ROOT=/.rbenv
RUN bash rbenv-installer/bin/rbenv-installer
COPY ./utils/rbenv-install-logging.sh /utils/
COPY ./.ruby-version ./
# hadolint ignore=DL3001
RUN --mount=type=cache,target=/.rbenv/cache \
    ruby_version="$(cat .ruby-version)" && \
    (sh '/utils/rbenv-install-logging.sh' &) && \
    chronic rbenv install "$ruby_version" && \
    kill "$(cat '/utils/logging-pid.txt')" && \
    ln -s "/.rbenv/versions/$ruby_version" /.rbenv/versions/current

FROM debian:12.9-slim AS linters--ruby--base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        libyaml-0-2 libyaml-dev build-essential >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY linters/Gemfile linters/Gemfile.lock ./
COPY --from=rbenv--install /.rbenv/versions /.rbenv/versions
ENV BUNDLE_DISABLE_SHARED_GEMS=true \
    BUNDLE_FROZEN=true \
    BUNDLE_GEMFILE=/app/Gemfile \
    BUNDLE_PATH=/app/bundle \
    BUNDLE_PATH__SYSTEM=false \
    PATH="$PATH:/.rbenv/versions/current/bin"
RUN bundle install --quiet

FROM --platform=$BUILDPLATFORM directory-optimizer--base AS linters--ruby--optimize
COPY utils/optimize/optimize-bundle.sh /optimizations/
COPY --from=rbenv--install /.rbenv/versions /.rbenv/versions
COPY --from=linters--ruby--base /app/bundle ./bundle
RUN sh /optimizations/optimize-bundle.sh

FROM debian:12.9-slim AS linters--ruby--final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        libyaml-0-2 libyaml-dev build-essential >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/ruby.sh ./sanity-check.sh
COPY linters/Gemfile linters/Gemfile.lock ./
COPY --from=rbenv--install /.rbenv/versions /.rbenv/versions
COPY --from=linters--ruby--optimize /app/bundle ./bundle
ENV BUNDLE_DISABLE_SHARED_GEMS=true \
    BUNDLE_FROZEN=true \
    BUNDLE_GEMFILE=/app/Gemfile \
    BUNDLE_PATH__SYSTEM=false \
    BUNDLE_PATH=/app/bundle \
    PATH="$PATH:/.rbenv/versions/current/bin"
RUN sh sanity-check.sh

# Python/Pip #
FROM debian:12.9-slim AS linters--python--base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY linters/requirements.txt ./
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --requirement requirements.txt --target python-vendor --quiet

FROM --platform=$BUILDPLATFORM directory-optimizer--base AS linters--python--optimize
COPY utils/optimize/optimize-python.sh /optimizations/
COPY --from=linters--python--base /app/python-vendor ./python-vendor
# TODO: Reenable
# RUN sh /optimizations/optimize-python.sh

FROM debian:12.9-slim AS linters--python--final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        python-is-python3 python3 python3-pip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/python.sh ./sanity-check.sh
COPY --from=linters--python--optimize /app/python-vendor ./python-vendor
ENV BINPREFIX=/app/python-vendor/bin/ \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app/python-vendor
RUN sh sanity-check.sh

# Composer #
FROM composer:2.8.5 AS linters--composer-bin--base

FROM --platform=$BUILDPLATFORM debian:12.9-slim AS linters--composer-bin--optimize
WORKDIR /app
COPY --from=linters--composer-bin--base /usr/bin/composer ./bin/
# TODO: optimize `composer` script

# PHP/Composer #
FROM debian:12.9-slim AS linters--composer-vendor--base
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        ca-certificates composer php php-mbstring php-zip >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY linters/composer.json linters/composer.lock ./
RUN composer install --no-cache --quiet

FROM --platform=$BUILDPLATFORM directory-optimizer--base AS composer-vendor--optimize
COPY utils/optimize/optimize-composer.sh /optimizations/
COPY --from=linters--composer-vendor--base /app/vendor ./vendor
RUN sh /optimizations/optimize-composer.sh

FROM debian:12.9-slim AS linters--composer--final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        ca-certificates php >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/composer.sh ./sanity-check.sh
COPY linters/composer.json ./linters/
COPY --from=composer-vendor--optimize /app/vendor ./linters/vendor
COPY --from=linters--composer-bin--optimize /app/bin/composer ./bin/
ENV BINPREFIX=/app/bin/ \
    VENDORPREFIX=/app/linters/ \
    COMPOSER_ALLOW_SUPERUSER=1
RUN sh sanity-check.sh

# LinuxBrew - gitman #
FROM --platform=$BUILDPLATFORM gitman--base AS linters--brew--gitman
COPY linters/gitman-repos/brew-install/gitman.yml ./
RUN gitman install --quiet && \
    find . -type d -name .git -prune -exec rm -rf {} \;

# LinuxBrew - install #
# This is first part of HomeBrew, here we just install it
# We have to provide our custom `uname`, because HomeBrew prohibits installation on non-x64 Linux systems
FROM --platform=$BUILDPLATFORM debian:12.9-slim AS linters--brew--install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        ca-certificates curl git moreutils procps ruby >/dev/null && \
    if [ "$(uname -m)" != 'amd64' ]; then \
        dpkg --add-architecture amd64 && \
        apt-get update -qq && \
        DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
            libc6:amd64 >/dev/null && \
    true; fi && \
    rm -rf /var/lib/apt/lists/* && \
    touch /.dockerenv
COPY utils/uname-x64.sh /usr/bin/uname-x64
RUN if [ "$(uname -m)" != 'amd64' ]; then \
        chmod a+x /usr/bin/uname-x64 && \
        mv /usr/bin/uname /usr/bin/uname-bak && \
        mv /usr/bin/uname-x64 /usr/bin/uname && \
    true; fi
COPY --from=linters--brew--gitman /app/gitman/brew-installer ./brew--installer
ENV HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1
RUN NONINTERACTIVE=1 chronic bash brew--installer/install.sh && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    chronic brew update --quiet && \
    chronic brew bundle --help --quiet
    # TODO: Reenable?
    # find /home/linuxbrew -type d -name .git -prune -exec rm -rf {} \;

# We need to replace ruby bundled with HomeBrew, because it is only a x64 version
# Instead we install the same ruby version via rbenv and replace it in HomeBrew
FROM debian:12.9-slim AS linters--brew--rbenv--install
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        autoconf bison build-essential ca-certificates curl git moreutils \
        libffi-dev libgdbm-dev libncurses5-dev libreadline-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=rbenv--gitman /app/gitman/rbenv-installer ./rbenv-installer
ENV PATH="$PATH:/root/.rbenv/bin:/.rbenv/bin:/.rbenv/shims" \
    RBENV_ROOT=/.rbenv
RUN bash rbenv-installer/bin/rbenv-installer
COPY ./utils/rbenv-install-logging.sh /utils/
COPY --from=linters--brew--install /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version ./
# hadolint ignore=DL3001
RUN --mount=type=cache,target=/.rbenv/cache \
    ruby_version_short="$(sed -E 's~_.*$~~' <portable-ruby-version)" && \
    (sh '/utils/rbenv-install-logging.sh' &) && \
    chronic rbenv install "$ruby_version_short" && \
    kill "$(cat '/utils/logging-pid.txt')" && \
    ln -s "/.rbenv/versions/$ruby_version_short" /.rbenv/versions/brew

FROM --platform=$BUILDPLATFORM debian:12.9-slim AS linters--brew--rbenv--link
WORKDIR /app
COPY --from=linters--brew--install /home/linuxbrew /home/linuxbrew
COPY --from=linters--brew--rbenv--install /.rbenv/versions /.rbenv/versions
# RUN ruby_version_full="$(cat /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
#     ruby_version_short="$(sed -E 's~_.+$~~' </home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version)" && \
#     ln -sf "/.rbenv/versions/$ruby_version_short" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/$ruby_version_full" && \
#     ln -sf "/.rbenv/versions/$ruby_version_short/bundle" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/bundle" && \
#     ln -sf "/.rbenv/versions/$ruby_version_short/gems" "/home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/gems" && \
#     find /.rbenv/versions -mindepth 1 -maxdepth 1 -type d -not -name "$ruby_version_short" -exec rm -rf {} \;

# In this stage we collect trace information about which files from linuxbrew and rbenv's ruby are actually neeeded
FROM debian:12.9-slim AS brew--trace
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        curl git inotify-tools psmisc >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/brew.sh ./sanity-check.sh
COPY --from=linters--brew--rbenv--link /home/linuxbrew /home/linuxbrew
COPY --from=linters--brew--rbenv--link /.rbenv/versions /.rbenv/versions
ENV BINPREFIX=/home/linuxbrew/.linuxbrew/bin/ \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1
ENV PATH="/.rbenv/versions/brew/bin:$PATH"
# TODO: Reenable on all architectures
# RUN touch /.dockerenv rbenv-list.txt brew-list.txt && \
#     if [ "$(uname -m)" = x86_64  ]; then \
#         inotifywait --daemon --recursive --event access /.rbenv/versions --outfile rbenv-list.txt --format '%w%f' && \
#         inotifywait --daemon --recursive --event access /home/linuxbrew --outfile brew-list.txt --format '%w%f' && \
#         sh sanity-check.sh && \
#         killall inotifywait && \
#     true; fi

# Use trace information to optimize rbenv and brew directories
FROM --platform=$BUILDPLATFORM directory-optimizer--base AS linters--brew--optimize
COPY utils/optimize/optimize-rbenv.sh utils/optimize/optimize-brew.sh /optimizations/
COPY --from=brew--trace /home/linuxbrew /home/linuxbrew
COPY --from=brew--trace /.rbenv/versions /.rbenv/versions
# COPY --from=brew--trace /app/rbenv-list.txt /app/brew-list.txt ./
# TODO: Reenable on all architectures
# RUN if [ "$(uname -m)" = x86_64  ]; then \
#         sh /optimizations/optimize-rbenv.sh && \
#         sh /optimizations/optimize-brew.sh && \
#     true; fi

# Aggregate everything brew here and do one more sanity-check
FROM debian:12.9-slim AS linters--brew--final
WORKDIR /app
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        curl git >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY utils/sanity-check/brew.sh ./sanity-check.sh
COPY --from=linters--brew--optimize /home/linuxbrew /home/linuxbrew
COPY --from=linters--brew--optimize /.rbenv/versions /.rbenv/versions
ENV BINPREFIX=/home/linuxbrew/.linuxbrew/bin/ \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1
# TODO: Make ruby version dynamic
ENV PATH="/.rbenv/versions/brew/bin:$PATH"
RUN touch /.dockerenv && \
    if [ "$(uname -m)" = x86_64  ]; then \
        sh sanity-check.sh && \
    true; fi

### Helpers ###

# Main CLI #
FROM --platform=$BUILDPLATFORM node:23.7.0-slim AS cli--base
WORKDIR /app
COPY package.json package-lock.json ./
RUN NODE_OPTIONS=--dns-result-order=ipv4first npm ci --unsafe-perm --no-progress --no-audit --no-fund --loglevel=error && \
    npx modclean --patterns default:safe --run --error-halt && \
    npx node-prune
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build && \
    npm prune --production

FROM --platform=$BUILDPLATFORM directory-optimizer--base AS cli--optimize
COPY utils/optimize/optimize-nodejs.sh /optimizations/
COPY --from=cli--base /app/node_modules ./node_modules
RUN sh /optimizations/optimize-nodejs.sh

FROM --platform=$BUILDPLATFORM debian:12.9-slim AS cli--final
WORKDIR /app
COPY --from=cli--base /app/cli-dist ./cli-dist
COPY --from=cli--optimize /app/node_modules ./node_modules

# AZLint binaries #
FROM --platform=$BUILDPLATFORM debian:12.9-slim AS azlint--bin
WORKDIR /app
RUN printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'node /app/cli-dist/main.js $@' >azlint && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint fmt $@' >fmt && \
    printf '%s\n%s\n%s\n' '#!/bin/sh' 'set -euf' 'azlint lint $@' >lint && \
    chmod a+x azlint fmt lint

# prefinal #
FROM debian:12.9-slim AS prefinal
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        moreutils curl git libxml2-utils \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python-is-python3 python3 python3-pip \
        bash dash ksh ksh93u+m mksh posh yash zsh \
        >/dev/null && \
    rm -rf /var/lib/apt/lists/*
COPY --from=linters--brew--final /home/linuxbrew /home/linuxbrew
COPY --from=linters--brew--final /.rbenv/versions /.rbenv/versions
COPY --from=linters--ruby--final /.rbenv/versions /.rbenv/versions
COPY --from=azlint--bin /app/azlint /app/fmt /app/lint /usr/bin/
WORKDIR /app
COPY VERSION.txt ./
WORKDIR /app/cli-dist
COPY --from=cli--final /app/cli-dist ./
COPY --from=cli--final /app/node_modules ./node_modules
COPY src/shell-dry-run.sh src/shell-dry-run-utils.sh ./
WORKDIR /app/linters
COPY linters/Gemfile linters/Gemfile.lock linters/composer.json ./
COPY --from=linters--composer--final /app/linters/vendor ./vendor
COPY --from=linters--nodejs--final /app/node_modules ./node_modules
COPY --from=linters--python--final /app/python-vendor ./python-vendor
COPY --from=linters--ruby--final /app/bundle ./bundle
COPY --from=linters--ruby--final /.rbenv /.rbenv
WORKDIR /app/linters/bin
COPY --from=linters--composer--final /app/bin ./
COPY --from=linters--haskell--final /app/bin ./
COPY --from=linters--go--final /app/bin ./
COPY --from=linters--rust--final /app/bin ./
COPY --from=linters--circleci--final /app/bin ./
COPY --from=linters--shell--loksh--final /app/bin ./
COPY --from=linters--shell-oksh--final /app/bin ./
WORKDIR /app-tmp
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    PATH="$PATH:/app/linters/bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore
COPY utils/sanity-check/system.sh ./sanity-check.sh
RUN chronic sh sanity-check.sh

### Final stage ###

FROM debian:12.9-slim
RUN find / -type f -not -path '/proc/*' -not -path '/sys/*' >/filelist.txt 2>/dev/null && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=yes DEBCONF_NOWARNINGS=yes apt-get install -qq --yes --no-install-recommends \
        curl git libxml2-utils libyaml-0-2 \
        bmake make \
        nodejs npm \
        php php-mbstring \
        python-is-python3 python3 python3-pip \
        bash dash ksh ksh93u+m mksh posh yash zsh \
        >/dev/null && \
    rm -rf /var/lib/apt/lists/* /var/log/apt /var/log/dpkg* /var/cache/apt /usr/share/zsh/vendor-completions && \
    find /usr/share/bug /usr/share/doc /var/cache /var/lib/apt /var/log -type f | while read -r file; do \
        if ! grep -- "$file" </filelist.txt >/dev/null; then \
            rm -f "$file" && \
        true; fi && \
    true; done && \
    rm -f /filelist.txt && \
    git config --system --add safe.directory '*' && \
    git config --global --add safe.directory '*' && \
    mkdir -p /root/.cache/proselint && \
    useradd --create-home --no-log-init --shell /bin/sh --user-group --system azlint && \
    su - azlint -c "git config --global --add safe.directory '*'" && \
    su - azlint -c 'mkdir -p /home/azlint/.cache/proselint'
COPY --from=prefinal /usr/bin/azlint /usr/bin/fmt /usr/bin/lint /usr/bin/
COPY --from=prefinal /home/linuxbrew /home/linuxbrew
COPY --from=prefinal /.rbenv/versions /.rbenv/versions
COPY --from=prefinal /app/ /app/
ENV NODE_OPTIONS=--dns-result-order=ipv4first \
    PATH="$PATH:/app/bin:/usr/local/go/bin:/home/linuxbrew/.linuxbrew/bin" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1
USER azlint
WORKDIR /project
ENTRYPOINT ["azlint"]
CMD []
