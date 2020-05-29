FROM python:3.8.3-slim
COPY . /src
WORKDIR /src

RUN pip install --requirement requirements.txt
CMD WORKDIR=/project sh main.sh
