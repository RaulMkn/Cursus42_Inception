#!/bin/bash

# 1. Definimos la ruta donde se montará el volumen de WordPress
WP_PATH="/var/www/html"
cd $WP_PATH

# 2. EL BUCLE 'WAIT-FOR-IT'
# Esperamos pacientemente a que MariaDB esté lista antes de hacer nada
# 'mariadb' es el nombre del contenedor de la base de datos en docker-compose
echo "Esperando a que MariaDB arranque..."
while ! mysqladmin ping -h "$DB_HOST" --silent; do
    sleep 1
done
echo "MariaDB está lista. Iniciando configuración de WordPress..."

# 3. COMPROBACIÓN DE INSTALACIÓN
# Si el archivo wp-config.php ya existe, significa que el volumen persistió
# y no necesitamos volver a instalarlo.
if [ -f "$WP_PATH/wp-config.php" ]; then
    echo "WordPress ya está instalado y configurado."
else
    echo "Descargando el core de WordPress..."
    wp core download --allow-root

    echo "Creando archivo de configuración (wp-config.php)..."
    # Aquí es donde inyectas las variables de tu .env o de tus secrets
    wp config create \
        --dbname=$DB_NAME \
        --dbuser=$DB_USER \
        --dbpass=$DB_PASSWORD \
        --dbhost=$DB_HOST \
        --allow-root

    echo "Instalando WordPress..."
    # ¡Cuidado! Recuerda que el admin_user NO puede llevar la palabra "admin"
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

# 4. Aseguramos los permisos de los archivos para que NGINX pueda leerlos
chown -R www-data:www-data $WP_PATH
find "$WP_PATH" -type d -exec chmod 775 {} \;
find "$WP_PATH" -type f -exec chmod 664 {} \;

# 5. EL TRUCO DEL PID 1
# Ejecutamos PHP-FPM en primer plano (-F) usando exec
echo "Iniciando PHP-FPM..."
exec /usr/sbin/php-fpm8.2 -F