### Components ###

# GoLang #
FROM golang:1.15.5 AS go
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml' && \
  GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson'

### Helpers ###

# Upx #
# Single stage to compress all executables from components
FROM debian AS upx
COPY --from=go /src/bin/stoml /usr/bin/stoml
COPY --from=go /src/bin/tomljson /usr/bin/tomljson
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends upx-ucl && \
    upx /usr/bin/stoml && \
    upx /usr/bin/tomljson

# Curl #
# Single stage to download setup scripts for main runner
FROM debian AS curl
WORKDIR /src
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/* && \
    curl -L -o composer-setup.php https://getcomposer.org/installer

### Main runner ###
FROM debian:10.6-slim
WORKDIR /src
COPY find.py main.sh dependencies/composer.json dependencies/composer.lock ./
COPY --from=upx /usr/bin/stoml /usr/bin/stoml
COPY --from=upx /usr/bin/tomljson /usr/bin/tomljson
COPY --from=curl /src/composer-setup.php .
RUN apt-get update --yes && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends php-cli php-zip unzip php-mbstring python3 git && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    composer install && \
    ln -s /src/find.py /usr/bin/project-find && \
    chmod a+x /src/find.py

CMD [ "sh", "main.sh" ]
