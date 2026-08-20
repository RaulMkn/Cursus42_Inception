# 1. Cumplimos la regla de la penúltima versión estable
FROM debian:bookworm

# 2. Actualizamos e instalamos los paquetes necesarios (sin usar sudo)
# - php-fpm: El motor de PHP
# - php-mysql: Para que PHP hable con MariaDB
# - mariadb-client: Para poder hacer el "ping" de comprobación en el script
# - curl: Para descargar wp-cli
RUN apt-get update && apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-redis \
    mariadb-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 3. Descargamos WP-CLI y lo hacemos ejecutable
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# 4. Creamos el directorio de ejecución que necesita PHP-FPM para arrancar
RUN mkdir -p /run/php

# 5. Copiamos los archivos de configuración y scripts
# OJO a la ruta de destino de www.conf, es específica de Debian y PHP 8.2
COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY ./tools/entrypoint.sh /usr/local/bin/

# 6. Damos permisos al script
RUN chmod +x /usr/local/bin/entrypoint.sh

# 7. Exponemos el puerto donde escuchará PHP-FPM
EXPOSE 9000

# 8. Asignamos el script como PID 1 inicial
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]