FROM golang:1.15.5-alpine AS toml
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml'

FROM rust:1.48.0-alpine AS build
ARG BUILD_ENV=dev
WORKDIR /src
# must copy everything, docker won't copy folder when listed explicitely (e.g. src/)
COPY Cargo.toml .
COPY --from=toml /src/bin/stoml /usr/bin/stoml
# hadolint ignore=DL4006
RUN stoml 'Cargo.toml' dev-dependencies | tr ' ' '\n' | xargs -n1 --no-run-if-empty cargo install --force && \
    mkdir bin && \
    find / -name 'dotenv-linter' \( -path '*/cargo/bin/dotenv-linter' -or -path '*/.cargo/bin/dotenv-linter' \) -exec cp {} bin/ \; && \
    if [ "${BUILD_ENV}" = prod ]; then \
    apk add --no-cache upx && \
    upx --ultra-brute bin/dotenv-linter \
    ; fi

FROM alpine:3.12.2
WORKDIR /src
COPY main.sh .
COPY --from=build /src/bin/dotenv-linter /usr/bin/dotenv-linter
CMD [ "sh", "main.sh" ]
