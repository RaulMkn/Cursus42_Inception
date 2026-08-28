#!/bin/bash

WP_PATH="/var/www/html"
cd $WP_PATH

echo "Esperando a que MariaDB arranque..."
TIMEOUT=60
COUNTER=0
while ! mysqladmin ping -h "$DB_HOST" --silent 2>/dev/null; do
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo "ERROR: MariaDB no respondió en ${TIMEOUT} segundos. Abortando."
        exit 1
    fi
    sleep 1
done
echo "MariaDB está lista. Iniciando configuración de WordPress..."
if [ -f "$WP_PATH/wp-config.php" ]; then
    echo "WordPress ya está instalado y configurado."
else
    echo "Descargando el core de WordPress..."
    wp core download --path=$WP_PATH --allow-root

    echo "Creando archivo de configuración (wp-config.php)..."
    wp config create \
        --dbname=$DB_NAME \
        --dbuser=$DB_USER \
        --dbpass=$DB_PASSWORD \
        --dbhost=$DB_HOST \
        --allow-root

    echo "Instalando WordPress..."
    wp core install \
        --url=$DOMAIN_NAME \
        --title="Inception 42" \
        --admin_user=$WP_ADMIN \
        --admin_password=$WP_ADMIN_PASS \
        --admin_email="contacto@tudominio.com" \
        --allow-root

    echo "Creando usuario secundario..."
    wp user create \
        $WP_USER \
        "usuario@tudominio.com" \
        --role=author \
        --user_pass=$WP_USER_PASS \
        --allow-root

    echo "WordPress instalado correctamente."
fi

wp config set WP_REDIS_HOST "$REDIS_HOST" --type=constant --raw --allow-root --path="$WP_PATH"
wp config set WP_REDIS_PORT "$REDIS_PORT" --type=constant --raw --allow-root --path="$WP_PATH"
wp config set WP_CACHE true --type=constant --raw --allow-root --path="$WP_PATH"

if ! wp plugin is-installed redis-cache --allow-root --path="$WP_PATH"; then
    echo "Instalando el plugin de Redis para WordPress..."
    wp plugin install redis-cache --activate --allow-root --path="$WP_PATH"
fi

wp redis enable --allow-root --path="$WP_PATH" || true

chown -R www-data:www-data $WP_PATH
find "$WP_PATH" -type d -exec chmod 775 {} \;
find "$WP_PATH" -type f -exec chmod 664 {} \;

echo "Iniciando PHP-FPM..."
exec /usr/sbin/php-fpm8.2 -F