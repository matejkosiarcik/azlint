FROM linuxbrew/brew:2.5.9
WORKDIR /src
COPY main.sh .

RUN brew bundle --help >/dev/null

CMD [ "sh", "main.sh" ]
