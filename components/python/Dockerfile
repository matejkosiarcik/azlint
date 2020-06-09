FROM python:3.8.3-alpine
WORKDIR /src
COPY requirements.txt main.sh ./

# bash - for bashate
# curl - travis
RUN apk add --no-cache bash curl && \
    pip install --requirement requirements.txt

CMD [ "sh", "main.sh" ]
