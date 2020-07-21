FROM golang:1.14.6-alpine AS build
ARG BUILD_ENV=dev
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt' && \
    if [ "${BUILD_ENV}" = prod ]; then \
    apk add --no-cache upx && \
    upx --ultra-brute bin/shfmt \
    ; fi

FROM alpine:3.12.0
WORKDIR /src
COPY --from=build /src/bin/shfmt /usr/bin/shfmt
COPY main.sh .

CMD [ "sh", "main.sh" ]
