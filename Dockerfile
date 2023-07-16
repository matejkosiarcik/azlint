# checkov:skip=CKV_DOCKER_2:Disable HEALTHCHECK
# ^^^ Healhcheck doesn't make sense for us here, because we are building a CLI tool, not server program

### Components/Linters ###

# Gitman #
FROM node:20.4.0-slim AS gitman
WORKDIR /app
COPY requirements.txt linters/gitman.yml ./
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt --target python
RUN PYTHONPATH=/app/python PATH="/app/python/bin:$PATH" gitman install

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

# Python/Pip #
FROM debian:12.0-slim AS python
WORKDIR /app
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
    mkdir -p /app/composer/bin && \
    php composer-setup.php --install-dir=/app/composer/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/* composer-setup.php
COPY linters/composer.json linters/composer.lock ./
RUN PATH="/app/composer/bin:$PATH" composer install --no-cache

# Hadolint #
FROM hadolint/hadolint:v2.12.0 AS hadolint

# LinuxBrew - install #
# This is first part of HomeBrew, here we just install it
# We have to provide our custom `uname`, because HomeBrew prohibits installation on non-x64 Linux systems
FROM debian:12.0-slim AS brew-install
WORKDIR /app
COPY --from=gitman /app/gitman/brew-installer ./brew-installer
COPY utils/uname-x64.sh /usr/bin/uname-x64
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl git procps ruby && \
    if [ "$(uname -m)" != 'amd64' ]; then \
        dpkg --add-architecture amd64 && \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends libc6:amd64 && \
        chmod a+x /usr/bin/uname-x64 && \
        mv /usr/bin/uname /usr/bin/uname-bak && \
        mv /usr/bin/uname-x64 /usr/bin/uname && \
    true; fi && \
    rm -rf /var/lib/apt/lists/* && \
    bash brew-installer/install.sh && \
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
COPY --from=gitman /app/gitman/rbenv-installer ./rbenv-installer
COPY --from=brew-install /home/linuxbrew/.linuxbrew/Homebrew/Library/Homebrew/vendor/portable-ruby-version ./
ENV PATH="$PATH:/root/.rbenv/bin:/.rbenv/bin:/.rbenv/shims"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        autoconf bison build-essential ca-certificates curl git \
        libffi-dev libgdbm-dev libncurses5-dev libreadline-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/* && \
    export RBENV_ROOT="/.rbenv" && \
    bash rbenv-installer/bin/rbenv-installer && \
    ruby_version_short="$(sed -E 's~_.+$~~' <portable-ruby-version)" && \
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

# Upx #
# Single stage to compress all executables from multiple components
FROM ubuntu:23.10 AS upx
WORKDIR /app
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends parallel upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    parallel upx --best ::: /app/*

# Prepare prebuild binaries #
FROM debian:12.0-slim AS prebuild
ARG TARGETPLATFORM
WORKDIR /app/bin
COPY prebuild/bin/platform/$TARGETPLATFORM ./
# hadolint disable=SC2016
RUN find . -name '*.bin' -type f -exec sh -c 'mv "$0" "$(basename "$0" .bin)"' {} \;

# Pre-Final #
FROM debian:12.0-slim AS pre-final
COPY --from=brew-final /home/linuxbrew /home/linuxbrew
COPY --from=brew-final /.rbenv/versions /.rbenv/versions
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
COPY --from=composer /app/vendor ./vendor
COPY --from=node /app/linters/node_modules ./node_modules
COPY --from=python /app/python ./python
COPY --from=ruby /app/bundle ./bundle
WORKDIR /app/linters/bin
COPY --from=prebuild /app/bin ./
COPY --from=composer /app/composer/bin/composer ./
COPY --from=hadolint /bin/hadolint ./

### Final stage ###

FROM debian:12.0-slim
WORKDIR /app
COPY --from=pre-final /home/linuxbrew /home/linuxbrew
COPY --from=pre-final /.rbenv/versions /.rbenv/versions
COPY --from=pre-final /app/ ./
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
    useradd --create-home --no-log-init --shell /bin/sh --user-group --system azlint && \
    su - azlint -c "git config --global --add safe.directory '*'" && \
    mkdir -p /root/.cache/proselint /home/azlint/.cache/proselint
ENV NODE_OPTIONS=--dns-result-order=ipv4first \
    PATH="$PATH:/app/bin:/home/linuxbrew/.linuxbrew/bin" \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    HOMEBREW_NO_ENV_HINTS=1 \
    HOMEBREW_NO_ANALYTICS=1
USER azlint
WORKDIR /project
ENTRYPOINT ["azlint"]
CMD []
