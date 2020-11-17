FROM composer:2.0.7
WORKDIR /src
COPY composer.json composer.lock main.sh ./

RUN composer install

CMD [ "composer", "run-script", "lint" ]
