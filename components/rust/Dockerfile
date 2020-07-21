FROM rust:1.44.0-alpine AS build
ARG BUILD_ENV=dev
WORKDIR /src
RUN if [ "${BUILD_ENV}" = prod ]; then \
    apk add --no-cache upx && \
    upx --ultra-brute bin/shfmt \
    ; fi
# TODO: compile dependencies

FROM alpine:3.12.0
WORKDIR /src
COPY main.sh .

CMD [ "sh", "main.sh" ]
