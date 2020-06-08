FROM composer:1.10.7
COPY . /src
WORKDIR /src

RUN composer install

CMD [ "composer", "run-script", "lint" ]
