FROM golang:1.15.5-alpine AS build
ARG BUILD_ENV=dev
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt' && \
    GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/freshautomations/stoml' && \
    GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson' && \
    if [ "${BUILD_ENV}" = prod ]; then \
    apk add --no-cache upx && \
    upx --ultra-brute bin/shfmt \
    upx --ultra-brute bin/stoml \
    upx --ultra-brute bin/tomljson \
    ; fi

FROM alpine:3.13.1
WORKDIR /src
COPY --from=build /src/bin/shfmt /usr/bin/shfmt
COPY --from=build /src/bin/stoml /usr/bin/stoml
COPY --from=build /src/bin/tomljson /usr/bin/tomljson
COPY main.sh .

CMD [ "sh", "main.sh" ]
