FROM swift:5.2.4 AS build
WORKDIR /src
COPY . .
RUN swift build --configuration release --static-swift-stdlib && \
    swift run --configuration release mint bootstrap --link

FROM swift:5.2.4-slim
WORKDIR /src
COPY main.sh .
COPY --from=build /usr/lib/libsourcekitdInProc.so /usr/lib/libsourcekitdInProc.so
COPY --from=build /usr/local/bin/swiftlint /usr/bin/swiftlint

CMD [ "sh", "main.sh" ]
