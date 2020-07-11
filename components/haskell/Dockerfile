FROM haskell:8.10.1 AS build
# TODO: replace base with raw debian

WORKDIR /src
COPY . ./

RUN stack setup && \
    stack build && \
    mkdir binaries && \
    find / -name 'shellcheck' -path '*/bin/shellcheck' -exec cp {} /src/binaries/ \; && \
    find / -name 'hadolint' -path '*/bin/hadolint' -exec cp {} /src/binaries/ \;

FROM debian:10.4-slim
WORKDIR /src
COPY --from=build /src/binaries/shellcheck /usr/bin/shellcheck
COPY --from=build /src/binaries/hadolint /usr/bin/hadolint
COPY main.sh .

CMD [ "sh", "main.sh" ]
