FROM unit:1.33.0-php8.3

ARG BMAC_TAG=v4.1.3

# Install PHP extensions
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y git libfreetype6 libfreetype6-dev libjpeg62-turbo libjpeg62-turbo-dev libpng16-16 libpng-dev libwebp7 libwebp-dev libzip4 libzip-dev unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install gd opcache pcntl pdo_mysql zip \
    && pecl install redis-6.0.2 \
    && docker-php-ext-enable redis \
    && apt-get purge -y --auto-remove git libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libzip-dev \
    && rm -rf /tmp/pear /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure PHP & Unit
COPY php.ini /usr/local/etc/php/php.ini
COPY bootstrap-laravel.sh /docker-entrypoint.d/
COPY unit.json /docker-entrypoint.d/

# Copy application files
WORKDIR /var/www/app
RUN set -ex \
    && curl -L https://github.com/daveroverts/bmac/archive/refs/tags/${BMAC_TAG}.tar.gz | tar -C /var/www/app --strip-components=1 -xz \
    && chown -R unit:unit /var/www/app

# Install Composer dependencies
RUN set -ex \
    && composer install --no-dev --optimize-autoloader \
    && rm -rf /root/.composer \
    && php artisan storage:link \
    && chown -R unit:unit bootstrap/cache public/storage vendor

# Build frontend assets
COPY favicon.ico /var/www/app/public/favicon.ico
COPY vatsim-logo.png /var/www/app/public/images/division-horizontal.png
COPY vatsim-logo.png /var/www/app/public/images/division-square.png
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y build-essential git nodejs npm \
    && npm ci \
    && npm run build \
    && apt-get purge -y --auto-remove build-essential git nodejs npm \
    && rm -rf /root/.npm /var/lib/apt/lists/* /var/www/app/node_modules \
    && chown -R unit:unit public

# CMD and ENTRYPOINT are inherited from the Unit image
