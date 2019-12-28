FROM alpine:latest

RUN mkdir -p /azlint
WORKDIR /azlint

COPY . ./

RUN sh 'utils/install-alpine.sh' && sh 'utils/install-components.sh'

RUN mkdir -p /mount
WORKDIR /mount

CMD WORKDIR='/mount' sh '/azlint/utils/lint.sh'
