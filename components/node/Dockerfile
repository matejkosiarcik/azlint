FROM node:14.4.0-alpine
WORKDIR /src
COPY package.json package-lock.json main.sh ./

# jq - check package.json content
# bash - for bats
RUN apk add --no-cache jq bash && \
    npm install
# TODO: node-prune

CMD [ "npm", "run", "--silent", "lint" ]
