FROM debian:10.4-slim
WORKDIR /src
COPY main.sh .

# sh dash bash - already available
RUN apt-get update && \
    apt-get install --yes --no-install-recommends ash ksh mksh yash zsh libxml2-utils && \
    rm -rf /var/lib/apt/lists/*

CMD [ "sh", "main.sh" ]
