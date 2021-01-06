FROM node:15.5.1-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./

# bash - for node-prune
RUN apk add --no-cache bash && \
    npm install --unsafe-perm && \
    npm prune --production

# production image with just node, without npm
FROM alpine:3.12.1
WORKDIR /src
COPY main.sh .
COPY --from=build /src/node_modules node_modules

# jq - check json contents
# bash - for bats
RUN apk add --no-cache jq bash nodejs

CMD [ "sh", "main.sh" ]
