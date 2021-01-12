FROM linuxbrew/brew:2.7.3
WORKDIR /src
COPY main.sh .

RUN brew bundle --help >/dev/null

CMD [ "sh", "main.sh" ]
