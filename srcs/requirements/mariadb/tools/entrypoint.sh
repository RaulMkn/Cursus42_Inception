#!/bin/bash

if [ ! -d "/var/lib/mysql/mysql" ]; then
    
    echo "1. El volumen está vacío. Instalando estructura básica de MariaDB..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db
    
    echo "2. Iniciando MariaDB en segundo plano temporalmente..."
    mysqld_safe &
    
    echo "3. Esperando a que el servicio esté listo..."
    while ! mysqladmin ping --silent; do
        sleep 1
    done
    
    echo "4. Inyectando configuración de seguridad y usuarios..."
    mariadb -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
    
    echo "5. Configuración terminada. Apagando servicio temporal..."
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

else
    echo "La base de datos ya existe en el volumen. Saltando configuración inicial."
fi

echo "6. Arrancando MariaDB definitivamente (PID 1)..."
exec mysqld_safe