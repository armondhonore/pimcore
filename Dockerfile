FROM mirror.gcr.io/library/php:8.2-apache

# Pimcore 11 CE requires PHP 8.2. symfony/property-info included via symfony/serializer
# had a Constant-expression bug (fixed in 7.2+). We avoid running PHP at build time
# (which would trigger the buggy autoloader) and generate the defuse key via openssl.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git unzip zip libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libwebp-dev \
        libicu-dev libxml2-dev libonig-dev libmagickwand-dev \
        default-mysql-client ghostscript poppler-utils \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        gd exif intl pdo_mysql pdo_sqlite zip bcmath sockets opcache pcntl \
    && (pecl install imagick || true) \
    && (docker-php-ext-enable imagick || true) \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -rf /var/lib/apt/lists/*

RUN composer config -g --no-plugins policy.advisories.block false 2>/dev/null \
    || composer config -g audit.abandoned ignore 2>/dev/null || true

RUN COMPOSER_MEMORY_LIMIT=-1 composer create-project "pimcore/skeleton:^11.0" /opt/pimcore \
        --no-interaction --no-scripts --prefer-dist --ignore-platform-reqs --no-audit \
    && rm -rf /var/www/html \
    && mv /opt/pimcore /var/www/html \
    && mkdir -p /var/www/html/var /var/www/html/public/var \
    && chown -R www-data:www-data /var/www/html

# Force symfony/property-info >=7.2 to fix the Constant-expression compile error
# that affects 7.0.x and 7.1.x (invalid use of ?? in class constant expressions).
RUN cd /var/www/html \
    && composer require --no-scripts --ignore-platform-reqs --no-update \
        "symfony/property-info:>=7.2" \
    && COMPOSER_MEMORY_LIMIT=-1 composer update --no-scripts --ignore-platform-reqs --no-audit \
        symfony/property-info \
    && chown -R www-data:www-data vendor

# Generate the defuse encryption key via openssl (no PHP execution at build time).
# Format: hex("\xDE\xF0\x00\x00") + hex(32 random bytes) = 72 hex chars.
RUN cd /var/www/html \
    && SECRET="def00000$(openssl rand -hex 32)" \
    && sed -i "/^parameters:/a\\    pimcore.encryption.secret: '${SECRET}'" config/services.yaml \
    && chown -R www-data:www-data config

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN a2enmod rewrite \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf \
    && printf '<Directory /var/www/html/public>\n    Options -Indexes +FollowSymLinks\n    AllowOverride All\n    Require all granted\n    DirectoryIndex index.php\n</Directory>\n' \
        > /etc/apache2/conf-available/pimcore.conf \
    && a2enconf pimcore

RUN { \
        echo 'memory_limit=512M'; \
        echo 'max_execution_time=300'; \
        echo 'upload_max_filesize=100M'; \
        echo 'post_max_size=100M'; \
    } > /usr/local/etc/php/conf.d/pimcore.ini

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY pimcore-bootstrap.sh /usr/local/bin/pimcore-bootstrap.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/pimcore-bootstrap.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
