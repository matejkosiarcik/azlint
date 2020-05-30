FROM golang:1.14.3-alpine
COPY . /src
WORKDIR /src

RUN GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt
CMD WORKDIR=/project sh main.sh
