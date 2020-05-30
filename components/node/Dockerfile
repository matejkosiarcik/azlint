FROM node:14.3.0-alpine
COPY . /src
WORKDIR /src

RUN npm install
CMD WORKDIR=/project npm run lint
