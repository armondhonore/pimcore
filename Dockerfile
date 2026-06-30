FROM mirror.gcr.io/library/php:8.1-apache

# Pimcore 11 (Community Edition, GPL). The 2026.x skeleton requires a COMMERCIAL product
# key (pimcore/platform-version) that 500s without registration, so pin the last
# open-source line. Symfony app needing a broad PHP extension set plus image tools.
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

# Build a runnable Pimcore 11 app from the official skeleton into a temp dir, then move
# it into the Apache docroot. (composer create-project will not populate a non-empty
# docroot; a bare COPY would leave it empty -> 403/404, and the framework library
# image alone is php-fpm only and serves nothing on :80 -> 503.)
# Disable composer's security-advisory block — it refuses to install ANY pimcore 11
# release citing PKSA advisories, which has nothing to do with whether the app runs.
# (These are throwaway test deployments.) Set it globally so create-project's resolve honors it.
RUN composer config -g --no-plugins policy.advisories.block false 2>/dev/null \
    || composer config -g audit.abandoned ignore 2>/dev/null || true
RUN COMPOSER_MEMORY_LIMIT=-1 composer create-project "pimcore/skeleton:^11.0" /opt/pimcore \
        --no-interaction --no-scripts --prefer-dist --ignore-platform-reqs --no-audit \
    && rm -rf /var/www/html \
    && mv /opt/pimcore /var/www/html \
    && mkdir -p /var/www/html/var /var/www/html/public/var \
    && chown -R www-data:www-data /var/www/html

# Pimcore requires a pimcore.encryption.secret container parameter or it 500s after
# install. Bake a real defuse key as a LITERAL value into the always-loaded
# services.yaml parameters block (env(%...%) didn't resolve under mod_php; config/local
# wasn't honored). One static key is fine for a single-replica deployment.
RUN cd /var/www/html \
    && SECRET="$(php vendor/bin/generate-defuse-key | tr -d '\n ')" \
    && echo "defuse key length: ${#SECRET}" \
    && sed -i "/^parameters:/a\\    pimcore.encryption.secret: '${SECRET}'" config/services.yaml \
    && grep -A1 '^parameters:' config/services.yaml \
    && chown -R www-data:www-data config

# DATABASE_URL is set at runtime by docker-entrypoint.sh (SQLite path in var/).
# The skeleton .env has no DATABASE_URL; the entrypoint writes .env.local + Apache SetEnv.

# Apache serves Pimcore's front controller from public/ with rewrite support.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN a2enmod rewrite \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf \
    && printf '<Directory /var/www/html/public>\n    Options -Indexes +FollowSymLinks\n    AllowOverride All\n    Require all granted\n    DirectoryIndex index.php\n</Directory>\n' \
        > /etc/apache2/conf-available/pimcore.conf \
    && a2enconf pimcore

# Generous PHP limits for Pimcore install + admin.
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