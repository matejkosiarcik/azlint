FROM alpine:3.12.3
WORKDIR /src
COPY main.sh .

# sh ash - already available
RUN apk add --no-cache bash dash loksh mksh yash zsh libxml2-utils

CMD [ "sh", "main.sh" ]
