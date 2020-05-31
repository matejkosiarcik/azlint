FROM debian:10.4-slim
COPY . /src
WORKDIR /src

# sh dash bash - already available
RUN apt-get install --yes ash ksh mksh yash zsh
CMD WORKDIR=/project sh main.sh
