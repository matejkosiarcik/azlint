FROM node:15.2.0-alpine AS build
# TODO: replace builder with rust
WORKDIR /src
COPY main.js package.json package-lock.json ./

# bash - for node-prune
RUN apk add --no-cache bash && \
    npm install --unsafe-perm && \
    npm prune --production && \
    rm -rf node_modules/.bin && \
    chmod +x main.js

FROM docker:19.03.13-git
WORKDIR /project
COPY --from=build /src/main.js /src/main.js
COPY --from=build /src/node_modules /src/node_modules
RUN apk add --no-cache nodejs && \
    ln -s /src/main.js /usr/bin/azlint
ARG AZLINT_VERSION=dev
ENV AZLINT_VERSION=$AZLINT_VERSION

CMD [ "azlint" ]
