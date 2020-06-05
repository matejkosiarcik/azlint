FROM python:3.8.3-alpine
COPY . /src
WORKDIR /src

# bash - for bashate
# curl - travis
RUN apk add --no-cache bash curl && \
    pip install --requirement requirements.txt

CMD WORKDIR=/project sh main.sh
