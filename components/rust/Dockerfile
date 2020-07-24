FROM golang:1.14.6-alpine AS toml
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml'

FROM rust:1.45.0-alpine AS build
ARG BUILD_ENV=dev
WORKDIR /src
# must copy everything, docker won't copy folder when listed explicitely (e.g. src/)
COPY . .
COPY --from=toml /src/bin/stoml /usr/bin/stoml
# hadolint ignore=DL4006
RUN stoml 'Cargo.toml' dev-dependencies | tr ' ' '\n' | xargs -n1 --no-run-if-empty cargo install --force && \
    mkdir bin && \
    if [ "${BUILD_ENV}" = prod ]; then \
    apk add --no-cache upx \
    ; fi

FROM alpine:3.12.0
WORKDIR /src
COPY main.sh .
CMD [ "sh", "main.sh" ]
