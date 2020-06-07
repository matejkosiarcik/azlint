FROM alpine:3.12.0
COPY . /src
WORKDIR /src

# sh ash - already available
RUN apk add --no-cache bash dash loksh mksh yash zsh libxml2-utils

ENV WORKDIR=/project
CMD [ "sh", "main.sh" ]
