FROM golang:1.14.4-alpine
COPY . /src
WORKDIR /src

RUN GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt


ENV WORKDIR=/project
CMD [ "sh", "main.sh" ]
