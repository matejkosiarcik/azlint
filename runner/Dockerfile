FROM node:14.4.0-alpine AS build
# TODO: replace builder with rust
WORKDIR /src
COPY main.js package.json package-lock.json ./

# bash - for node-prune
RUN apk add --no-cache upx binutils bash && \
    npm install && \
    npm run create-executable && \
    strip --strip-unneeded --strip-all --remove-section=.comment --remove-section=.note azlint && \
    upx -9 azlint

FROM docker:19.03.11-git
WORKDIR /project
COPY --from=build /src/azlint /usr/bin/azlint
ARG AZLINT_VERSION=dev
ENV AZLINT_VERSION=$AZLINT_VERSION

CMD [ "azlint" ]
