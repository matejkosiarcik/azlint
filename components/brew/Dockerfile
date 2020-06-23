FROM linuxbrew/brew:2.4.1
WORKDIR /src
COPY main.sh .

RUN brew bundle --help >/dev/null

CMD [ "sh", "main.sh" ]
