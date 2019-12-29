FROM alpine:3.11

RUN mkdir -p /azlint
WORKDIR /azlint

COPY . ./

RUN sh 'utils/install-alpine.sh' && \
    sh 'utils/install-components.sh' && \
    printf '#!/bin/sh\nsh /azlint/utils/lint.sh\n' >'/bin/azlint' && \
    chmod +x '/bin/azlint'

RUN mkdir -p /mount
WORKDIR /mount

CMD azlint
