### Components ###

# GoLang #
FROM golang:1.16.4 AS go
WORKDIR /src
RUN GOPATH="$PWD" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml' && \
    GOPATH="$PWD" GO111MODULE=on go get -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson' && \
    GOPATH="$PWD" GO111MODULE=on go get -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt'

# NodeJS/NPM #
FROM node:lts-slim AS node
WORKDIR /src
COPY dependencies/package.json dependencies/package-lock.json ./
RUN npm install --unsafe-perm && \
    npm prune --production

# Ruby/Gem #
# confusingly it has 2 stages
# first stage installs all gems with bundler
# second stage reinstalls these gems to the (almost) same container as our production one (without this stage we get warnings for gems with native extensions in production)
FROM ruby:3.0.1 AS pre-ruby
WORKDIR /src
COPY dependencies/Gemfile dependencies/Gemfile.lock ./
RUN gem install bundler && \
    gem update --system && \
    bundle install
FROM debian:10.9 AS ruby
WORKDIR /src
COPY --from=pre-ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ruby ruby-build ruby-dev && \
    rm -rf /var/lib/apt/lists/* && \
    GEM_HOME=/usr/local/bundle gem pristine --all

# Rust/Cargo #
FROM rust:1.46.0 AS rust
WORKDIR /src
COPY dependencies/Cargo.toml ./
COPY --from=go /src/bin/stoml /usr/bin/stoml
# hadolint ignore=DL4006
RUN stoml 'Cargo.toml' dev-dependencies | tr ' ' '\n' | xargs --no-run-if-empty cargo install --force

# CircleCI #
# it has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
# this script builds the executable and optimizes with https://upx.github.io
# then we just copy it to production container
FROM debian:10.9 AS circleci
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    curl -fLsS https://raw.githubusercontent.com/CircleCI-Public/circleci-cli/master/install.sh | bash && \
    rm -rf /var/lib/apt/lists/*

# Checkmake #
FROM golang:1.16.4 AS checkmake
WORKDIR /checkmake
RUN apt-get update && \
    apt-get install --yes --no-install-recommends git pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/mrtazz/checkmake . && \
    BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make

### Helpers ###

# Upx #
# Single stage to compress all executables from components
FROM debian:10.9 AS upx
COPY --from=go /src/bin/shfmt /src/bin/stoml /src/bin/tomljson /usr/bin/
COPY --from=checkmake /checkmake/checkmake /usr/bin/
COPY --from=circleci /usr/local/bin/circleci /usr/bin/
COPY --from=rust /usr/local/cargo/bin/shellharden /usr/local/cargo/bin/dotenv-linter /usr/bin/
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    upx --best /usr/bin/checkmake && \
    upx --best /usr/bin/circleci && \
    upx --best /usr/bin/dotenv-linter && \
    upx --best /usr/bin/shellharden && \
    upx --best /usr/bin/stoml && \
    upx --best /usr/bin/tomljson

### Main runner ###

# curl is only needed to install nodejs&composer
FROM debian:10.9
LABEL maintainer="matej.kosiarcik@gmail.com" \
    repo="https://github.com/matejkosiarcik/azlint"
WORKDIR /src
COPY src/project_find.py src/main.sh dependencies/composer.json dependencies/composer.lock dependencies/requirements.txt ./
COPY --from=upx /usr/bin/checkmake /usr/bin/circleci /usr/bin/dotenv-linter /usr/bin/shellharden /usr/bin/shfmt /usr/bin/stoml /usr/bin/tomljson /usr/bin/
COPY --from=node /src/node_modules node_modules/
COPY --from=ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends bmake curl git jq libxml2-utils make php-cli php-mbstring php-zip python3 python3-pip ruby unzip && \
    curl -fLsS https://deb.nodesource.com/setup_lts.x | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs && \
    curl -fLsSo composer-setup.php https://getcomposer.org/installer && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -f composer-setup.php && \
    apt-get remove --purge --yes curl && \
    rm -rf /var/lib/apt/lists/* && \
    composer install && \
    python3 -m pip install --no-cache-dir --upgrade setuptools && \
    python3 -m pip install --no-cache-dir --requirement requirements.txt && \
    ln -s /src/main.sh /usr/bin/azlint && \
    ln -s /src/project_find.py /usr/bin/project_find && \
    chmod a+x /src/main.sh /src/project_find.py

WORKDIR /project
ENTRYPOINT [ "azlint" ]
CMD [ ]
