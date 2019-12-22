FROM alpine:latest

LABEL maintainer="Matej Košiarčik <matej.kosiarcik@gmail.com>"
LABEL name="matejkosiarcik/azlint"

RUN mkdir -p /azlint
WORKDIR /azlint

COPY . ./

RUN sh 'utils/install-alpine.sh' && sh 'utils/install-components.sh'

RUN mkdir -p /mount
WORKDIR /mount

# ENTRYPOINT []
CMD WORKDIR='/mount' sh '/azlint/utils/lint.sh'
