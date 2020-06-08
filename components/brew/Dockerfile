FROM linuxbrew/brew:2.3.0
WORKDIR /src
COPY main.sh .

RUN brew cask ls >/dev/null && \
    brew bundle --help >/dev/null

CMD [ "sh", "main.sh" ]
