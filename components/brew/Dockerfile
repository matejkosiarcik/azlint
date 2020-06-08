FROM linuxbrew/brew:2.3.0
COPY . /src
WORKDIR /src

RUN brew cask ls >/dev/null && \
    brew bundle --help >/dev/null

ENV WORKDIR=/project
CMD [ "sh", "main.sh" ]
