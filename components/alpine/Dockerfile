FROM alpine:3.11
COPY . /src
WORKDIR /src

# sh ash - already available
RUN apk add --no-cache bash dash loksh mksh yash zsh
CMD WORKDIR=/project sh main.sh
