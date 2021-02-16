FROM linuxbrew/brew:3.0.1
WORKDIR /src
COPY main.sh .

RUN brew bundle --help >/dev/null

CMD [ "sh", "main.sh" ]
