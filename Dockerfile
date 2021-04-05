### Components ###

# GoLang #
FROM golang:1.15.5 AS go
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml' && \
  GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson'

# NodeJS #
FROM node:lts-slim AS node
WORKDIR /src
COPY dependencies/package.json dependencies/package-lock.json ./
RUN npm install --unsafe-perm && \
    npm prune --production
# TODO: `npm ci` instead of `npm install`?

# Ruby #
# confusingly it has 2 stages
# first stage installs all gems with bundler
# second stage reinstalls these gems to the (almost) same container as our production one (without this stage we get warnings for gems with native extensions in production)
FROM ruby:2.7.0 AS pre-ruby
WORKDIR /src
COPY dependencies/Gemfile dependencies/Gemfile.lock ./
RUN gem install bundler && \
    gem update --system && \
    bundle install
FROM debian:10.9 AS ruby
WORKDIR /src
COPY --from=pre-ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update && \
    apt-get install --yes --no-install-recommends ruby ruby-dev ruby-build && \
    rm -rf /var/lib/apt/lists/* && \
    GEM_HOME=/usr/local/bundle gem pristine --all

# CircleCI #
# it has custom install script that has to run https://circleci.com/docs/2.0/local-cli/#alternative-installation-method
# this script builds the executable and optimizes with https://upx.github.io
# then we just copy it to production container
FROM debian:10.9 AS circleci
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl ca-certificates && \
    curl -fLSs https://raw.githubusercontent.com/CircleCI-Public/circleci-cli/master/install.sh | bash && \
    rm -rf /var/lib/apt/lists/*

### Helpers ###

# Upx #
# Single stage to compress all executables from components
FROM debian AS upx
COPY --from=go /src/bin/stoml /usr/bin/stoml
COPY --from=go /src/bin/tomljson /usr/bin/tomljson
COPY --from=circleci /usr/local/bin/circleci /usr/bin/circleci
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends upx-ucl && \
    upx --ultra-brute /usr/bin/stoml && \
    upx --ultra-brute /usr/bin/tomljson && \
    upx --ultra-brute /usr/bin/circleci

### Main runner ###
# curl is only needed to install nodejs&composer
FROM debian:10.9
LABEL maintainer="matej.kosiarcik@gmail.com"
WORKDIR /src
COPY utils/project-find.py utils/main.sh dependencies/composer.json dependencies/composer.lock dependencies/requirements.txt ./
COPY --from=upx /usr/bin/stoml /usr/bin/stoml
COPY --from=upx /usr/bin/tomljson /usr/bin/tomljson
COPY --from=upx /usr/bin/circleci /usr/bin/circleci
COPY --from=node /src/node_modules node_modules/
COPY --from=ruby /usr/local/bundle/ /usr/local/bundle/
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends curl git jq php-cli php-zip unzip php-mbstring python3 python3-pip ruby && \
    curl -sL https://deb.nodesource.com/setup_lts.x | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends nodejs && \
    curl -sL -o composer-setup.php https://getcomposer.org/installer && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -f composer-setup.php && \
    apt-get remove --purge --yes curl && \
    rm -rf /var/lib/apt/lists/* && \
    composer install && \
    python3 -m pip install --upgrade setuptools && \
    python3 -m pip install --requirement requirements.txt && \
    ln -s /src/main.sh /usr/bin/azlint && \
    chmod a+x /src/main.sh && \
    ln -s /src/project-find.py /usr/bin/project-find && \
    chmod a+x /src/project-find.py

ENTRYPOINT [ "azlint" ]
# WORKDIR /project
# CMD [ "azlint" ]
