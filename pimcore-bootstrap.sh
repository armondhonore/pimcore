#!/bin/sh
# Background one-time Pimcore installer — MySQL.
cd /var/www/html

DB_HOST="${PIMCORE_DB_HOST:-pimcore-mysql.pod}"
DB_PORT="${PIMCORE_DB_PORT:-3306}"
DB_NAME="${PIMCORE_DB_NAME:-pimcore}"
DB_USER="${PIMCORE_DB_USER:-pimcore}"
DB_PASS="${PIMCORE_DB_PASS:-pimcorepass}"
ADMIN_USER="${PIMCORE_ADMIN_USER:-admin}"
ADMIN_PASS="${PIMCORE_ADMIN_PASS:-pimcoreadmin}"

export APP_ENV=dev
export DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# Wait for MySQL (up to 5 min; fresh PVC init can be slow).
i=0
while [ "$i" -lt 100 ]; do
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e 'SELECT 1' >/dev/null 2>&1; then
        break
    fi
    i=$((i+1)); sleep 3
done

if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e 'SELECT 1' >/dev/null 2>&1; then
    echo "[bootstrap] ERROR: MySQL not reachable at ${DB_HOST}:${DB_PORT}"
    exit 1
fi
echo "[bootstrap] MySQL reachable at ${DB_HOST}:${DB_PORT}"

mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
    -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" 2>&1 || true

echo "[bootstrap] running pimcore-install ..."
if su -s /bin/sh -p www-data -c "DATABASE_URL='$DATABASE_URL' APP_ENV=dev php -d memory_limit=512M vendor/bin/pimcore-install \
    --admin-username='$ADMIN_USER' \
    --admin-password='$ADMIN_PASS' \
    --no-interaction --ignore-existing-config" 2>&1; then
    touch var/.pimcore-installed
    chown -R www-data:www-data var public/var config files 2>/dev/null || true
    echo "[bootstrap] pimcore-install complete."
else
    echo "[bootstrap] pimcore-install FAILED"
fi
