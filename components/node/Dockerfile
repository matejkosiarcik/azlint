FROM node:14.4.0-alpine
COPY . /src
WORKDIR /src

# jq - check package.json content
# bash - for bats
RUN apk add --no-cache jq bash && \
    npm install

CMD WORKDIR=/project npm run --silent lint
