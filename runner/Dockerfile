FROM docker:19.03.11

COPY . /azlint
WORKDIR /project
ARG AZLINT_VERSION=dev
ENV AZLINT_VERSION=$AZLINT_VERSION

# TODO: replace node with rust and use builder image patter
RUN apk add --no-cache git nodejs npm && \
    npm install --prefix /azlint && \
    printf '#!/bin/sh\nnode /azlint/main.js\n' >'/bin/azlint' && \
    chmod +x '/bin/azlint'

CMD [ "azlint" ]
