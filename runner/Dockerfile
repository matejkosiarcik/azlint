FROM docker:19.03.9

COPY . /azlint
WORKDIR /project
ENV AZLINT_VERSION=dev

RUN apk add --no-cache git nodejs npm && \
    npm install --prefix /azlint && \
    printf '#!/bin/sh\n%s\n' 'node /azlint/main.js' >'/bin/azlint' && \
    chmod +x '/bin/azlint'

CMD azlint
