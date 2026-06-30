#!/bin/sh
set -e

cd /var/www/html

DB_HOST="${PIMCORE_DB_HOST:-pimcore-mysql.pod}"
DB_PORT="${PIMCORE_DB_PORT:-3306}"
DB_NAME="${PIMCORE_DB_NAME:-pimcore}"
DB_USER="${PIMCORE_DB_USER:-pimcore}"
DB_PASS="${PIMCORE_DB_PASS:-pimcorepass}"

export APP_ENV="${APP_ENV:-dev}"
export DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

if [ -z "${PIMCORE_ENCRYPTION_SECRET:-}" ]; then
    if [ ! -f var/.encryption-secret ]; then
        mkdir -p var
        php vendor/bin/generate-defuse-key 2>/dev/null | tr -d '\n' > var/.encryption-secret || true
    fi
    PIMCORE_ENCRYPTION_SECRET="$(cat var/.encryption-secret 2>/dev/null)"
fi
export PIMCORE_ENCRYPTION_SECRET

cat > .env.local <<ENVEOF
APP_ENV=${APP_ENV}
DATABASE_URL=${DATABASE_URL}
ENVEOF
cat > /etc/apache2/conf-available/pimcore-env.conf <<APENVEOF
SetEnv APP_ENV ${APP_ENV}
SetEnv DATABASE_URL ${DATABASE_URL}
PassEnv APP_ENV
PassEnv DATABASE_URL
APENVEOF
a2enconf pimcore-env >/dev/null 2>&1 || true

mkdir -p config/local
cat > config/local/doctrine.yaml <<DOCEOF
doctrine:
    dbal:
        connections:
            default:
                host: ${DB_HOST}
                port: ${DB_PORT}
                user: ${DB_USER}
                password: '${DB_PASS}'
                dbname: ${DB_NAME}
                driver: pdo_mysql
DOCEOF

mkdir -p var public/var config files
chown -R www-data:www-data var public/var config files .env.local 2>/dev/null || true
rm -rf var/cache/* 2>/dev/null || true

INSTALL_MARKER=var/.pimcore-installed
if [ ! -f "$INSTALL_MARKER" ] && [ "${PIMCORE_SKIP_INSTALL:-0}" != "1" ]; then
    mkdir -p public
    : > public/install-log.txt
    chown www-data:www-data public/install-log.txt 2>/dev/null || true
    ( /usr/local/bin/pimcore-bootstrap.sh 2>&1 | tee -a public/install-log.txt ) &
fi

exec "$@"
