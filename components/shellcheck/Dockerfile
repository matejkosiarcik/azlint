FROM koalaman/shellcheck-alpine:v0.7.1
COPY . /src
WORKDIR /src

RUN apk add --no-cache git
CMD WORKDIR=/project sh main.sh
