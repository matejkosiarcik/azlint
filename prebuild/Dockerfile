# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# ^^^ Healhcheck doesn't make sense for us here, because we are building a CLI tool, not server program

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
FROM golang:1.20.6-bookworm AS go
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/freshautomations/stoml@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/rhysd/actionlint/cmd/actionlint@latest' && \
    GOPATH="$PWD/go" GO111MODULE=on go install -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'
COPY --from=gitman /app/gitman/checkmake ./gitman/checkmake
RUN BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make -C gitman/checkmake
COPY --from=gitman /app/gitman/editorconfig-checker ./gitman/editorconfig-checker
RUN make -C gitman/editorconfig-checker build

# Rust #
FROM rust:1.71.0-slim-bookworm AS rust
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs npm && \
    rm -rf /var/lib/apt/lists/*
ENV NODE_OPTIONS=--dns-result-order=ipv4first
COPY package.json package-lock.json ./
RUN npm ci --unsafe-perm
COPY utils/cargo-packages.js ./utils/
COPY linters/Cargo.toml ./linters/
RUN node utils/cargo-packages.js | while read -r package version; do \
        cargo install "$package" --force --version "$version" --root "$PWD/cargo"; \
    done

# Composer #
FROM debian:12.0-slim AS composer
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl php php-cli php-common php-mbstring php-zip && \
    curl -fLsS https://getcomposer.org/installer -o composer-setup.php && \
    mkdir -p /app/composer/bin && \
    php composer-setup.php --install-dir=/app/composer/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/* composer-setup.php

# CircleCI-CLI #
# It has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
FROM debian:12.0-slim AS circleci
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/circleci-cli /app/circleci-cli
WORKDIR /app/circleci-cli
RUN bash install.sh

# Shell - loksh #
FROM debian:12.0-slim AS loksh
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential ca-certificates git meson && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/loksh /app/loksh
WORKDIR /app/loksh
RUN meson setup --prefix="$PWD/install" build && \
    ninja -C build install

# Shell - oksh #
FROM debian:12.0-slim AS oksh
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*
COPY --from=gitman /app/gitman/oksh /app/oksh
WORKDIR /app/oksh
RUN ./configure && \
    make && \
    DESTDIR="$PWD/install" make install

# ShellCheck #
FROM koalaman/shellcheck:v0.9.0 AS shellcheck

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint

# Upx #
FROM ubuntu:23.10 AS upx
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/*
COPY --from=circleci /usr/local/bin/circleci ./
COPY --from=go /app/gitman/checkmake/checkmake /app/gitman/editorconfig-checker/bin/ec /app/go/bin/actionlint /app/go/bin/shfmt /app/go/bin/stoml /app/go/bin/tomljson ./
COPY --from=loksh /app/loksh/install/bin/ksh ./loksh
COPY --from=oksh /app/oksh/install/usr/local/bin/oksh ./
COPY --from=rust /app/cargo/bin/dotenv-linter /app/cargo/bin/hush /app/cargo/bin/shellharden ./
COPY --from=shellcheck /bin/shellcheck ./
RUN parallel upx --ultra-brute ::: /app/*

# Pre-Final #
FROM debian:12.0-slim AS pre-final
WORKDIR /app/bin
COPY --from=composer /app/composer/bin/composer ./
COPY --from=hadolint /bin/hadolint ./
COPY --from=upx /app/actionlint /app/checkmake /app/circleci /app/dotenv-linter /app/ec /app/hush /app/loksh /app/oksh /app/shellcheck /app/shellharden /app/shfmt /app/stoml /app/tomljson ./
RUN find . -type f -exec mv {} {}.bin \;

# Final #
FROM debian:12.0-slim
WORKDIR /app
COPY --from=pre-final /app/ ./
RUN useradd --create-home --no-log-init --shell /bin/sh --user-group --system user
USER user
