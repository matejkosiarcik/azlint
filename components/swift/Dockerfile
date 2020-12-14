FROM swift:5.3 AS build
ARG BUILD_ENV=dev
WORKDIR /src
# must copy everything, docker won't copy folder when listed explicitely (e.g. Sources/)
COPY . .
RUN if [ "${BUILD_ENV}" = prod ]; then \
    swift run --configuration release mint bootstrap --link && \
    strip --strip-unneeded --strip-all --remove-section=.comment --remove-section=.note "$(readlink /usr/local/bin/swiftlint)" \
    ; else \
    swift run --configuration debug mint bootstrap --link \
    ; fi

FROM debian:10.7 AS build2
WORKDIR /src
COPY --from=build /usr/local/bin/swiftlint /usr/bin/swiftlint
RUN if [ "${BUILD_ENV}" = prod ]; then \
    apt-get update && \
    apt-get install --yes --no-install-recommends upx-ucl && \
    upx --ultra-brute /usr/bin/swiftlint && \
    rm -rf /var/lib/apt/lists/* \
    ; fi

FROM swift:5.3-slim
WORKDIR /src
COPY main.sh .
COPY --from=build /usr/lib/libsourcekitdInProc.so /usr/lib/libsourcekitdInProc.so
COPY --from=build2 /usr/bin/swiftlint /usr/bin/swiftlint

CMD [ "sh", "main.sh" ]
