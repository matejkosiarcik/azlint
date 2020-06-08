FROM node:14.4.0-alpine AS build
# TODO: replace node with rust and use builder image pattern
WORKDIR /azlint
COPY . .

RUN apk add --no-cache bash && \
    npm install && \
    npm install --global node-prune && \
    node-prune && \
    npm prune --production && \
    rm -rf 'node_modules/.cache'

FROM docker:19.03.11
WORKDIR /project
COPY --from=build /azlint/main.js /azlint/main.js
COPY --from=build /azlint/node_modules /azlint/node_modules
ARG AZLINT_VERSION=dev
ENV AZLINT_VERSION=$AZLINT_VERSION

RUN apk add --no-cache git nodejs && \
    chmod +x '/azlint/main.js' && \
    ln -s '/azlint/main.js' '/usr/bin/azlint'

CMD [ "azlint" ]
