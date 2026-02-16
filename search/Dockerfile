FROM php:8.3-cli-alpine
RUN apk add --no-cache unzip curl
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock* ./
RUN composer install --no-dev --no-scripts --no-autoloader
COPY . .
RUN composer dump-autoload --optimize
EXPOSE 3006
CMD ["php", "-S", "0.0.0.0:3006", "-t", "public"]
