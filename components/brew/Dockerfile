FROM linuxbrew/brew:2.3.0
COPY . /src
WORKDIR /src

RUN brew bundle --help >/dev/null
CMD WORKDIR=/project sh main.sh
