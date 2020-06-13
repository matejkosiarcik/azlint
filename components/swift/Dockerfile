FROM swift:5.2.4 AS build
WORKDIR /src
# must copy everything, docker won't copy folder when listed explicitely (e.g. Sources/)
COPY . .
RUN swift run --configuration release mint bootstrap --link && \
    strip --strip-unneeded --strip-all --remove-section=.comment --remove-section=.note "$(readlink /usr/local/bin/swiftlint)"

FROM debian:10.4-slim AS build2
WORKDIR /src
COPY --from=build /usr/local/bin/swiftlint /usr/bin/swiftlint
RUN apt-get update && \
    apt-get install --yes --no-install-recommends upx-ucl &&  \
    upx --ultra-brute /usr/bin/swiftlint && \
    rm -rf /var/lib/apt/lists/*

FROM swift:5.2.4-slim
WORKDIR /src
COPY main.sh .
COPY --from=build /usr/lib/libsourcekitdInProc.so /usr/lib/libsourcekitdInProc.so
COPY --from=build2 /usr/bin/swiftlint /usr/bin/swiftlint

CMD [ "sh", "main.sh" ]
