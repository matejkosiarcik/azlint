FROM golang:1.14.4-alpine AS build
WORKDIR /src
RUN GOPATH="${PWD}" GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt

FROM alpine:3.12.0
WORKDIR /src
COPY --from=build /src/bin/shfmt /usr/bin/shfmt
COPY main.sh .

ENV WORKDIR=/project
CMD [ "sh", "main.sh" ]
