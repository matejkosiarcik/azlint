FROM debian:10.4-slim
COPY . /src
WORKDIR /src

# sh dash bash - already available
RUN apt-get update --yes && apt-get install --yes --no-install-recommends ash ksh mksh yash zsh && rm -rf /var/lib/apt/lists/*
CMD WORKDIR=/project sh main.sh
