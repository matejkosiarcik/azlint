FROM node:14.4.0-alpine
COPY . /src
WORKDIR /src

RUN apk add --no-cache jq && npm install
CMD WORKDIR=/project npm run --silent lint
