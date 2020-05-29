FROM docker:19.03.9

COPY ./runner/ /azlint
WORKDIR /project
ENV AZLINT_VERSION=dev

RUN apk add --no-cache nodejs npm git && \
    npm install --prefix /azlint && \
    printf '#!/bin/sh\n%s\n' 'node /azlint/main.js' >'/bin/azlint' && \
    chmod +x '/bin/azlint'

CMD azlint
