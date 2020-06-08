FROM composer:1.10.7
WORKDIR /src
COPY . .

RUN composer install

CMD [ "composer", "run-script", "lint" ]
