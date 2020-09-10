FROM composer:1.10.12
WORKDIR /src
COPY composer.json composer.lock main.sh ./

RUN composer install

CMD [ "composer", "run-script", "lint" ]
