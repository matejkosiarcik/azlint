FROM haskell:8.10.2 AS build
ARG BUILD_ENV=dev
# TODO: replace base haskell with raw debian for multiplatform builds

WORKDIR /src
# must copy everything, docker won't copy folder when listed explicitely (e.g. src/)
COPY . ./

RUN stack setup && \
    stack build --ghc-options -O2 && \
    mkdir binaries && \
    find / -name 'shellcheck' -path '*/bin/shellcheck' -exec cp {} /src/binaries/ \; && \
    find / -name 'hadolint' -path '*/bin/hadolint' -exec cp {} /src/binaries/ \;

FROM debian:10.6-slim AS build2
WORKDIR /src
COPY --from=build /src/binaries/shellcheck /usr/bin/
COPY --from=build /src/binaries/hadolint /usr/bin/
RUN if [ "${BUILD_ENV}" = prod ]; then \
    apt-get update && \
    apt-get install --yes --no-install-recommends upx-ucl && \
    rm -rf /var/lib/apt/lists/* && \
    upx --ultra-brute /usr/bin/shellcheck && \
    upx --ultra-brute /usr/bin/hadolint \
    ; fi

FROM debian:10.6-slim
WORKDIR /src
COPY --from=build2 /usr/bin/shellcheck /usr/bin/
COPY --from=build2 /usr/bin/hadolint /usr/bin/
COPY main.sh .

CMD [ "sh", "main.sh" ]
