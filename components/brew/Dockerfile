FROM linuxbrew/brew:2.4.11
WORKDIR /src
COPY main.sh .

RUN brew bundle --help >/dev/null

CMD [ "sh", "main.sh" ]
