FROM golang:1.14.4-alpine AS build
WORKDIR /src
RUN apk add --no-cache upx && \
    GOPATH="${PWD}" GO111MODULE=on go get -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt' && \
    upx --brute bin/shfmt

FROM alpine:3.12.0
WORKDIR /src
COPY --from=build /src/bin/shfmt /usr/bin/shfmt
COPY main.sh .

CMD [ "sh", "main.sh" ]
