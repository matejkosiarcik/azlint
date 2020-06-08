FROM node:14.4.0-alpine
WORKDIR /src
COPY . .

# jq - check package.json content
# bash - for bats
RUN apk add --no-cache jq bash && \
    npm install

CMD [ "npm", "run", "--silent", "lint" ]
