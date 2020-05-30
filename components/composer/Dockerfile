FROM composer:1.10.6
COPY . /src
WORKDIR /src

RUN composer install
CMD WORKDIR=/project composer run-script lint
