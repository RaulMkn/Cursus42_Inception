#!/bin/bash

SSL_DIR="/etc/nginx/ssl"
CERTIFICATE="$SSL_DIR/inception.crt"
PRIVATE_KEY="$SSL_DIR/inception.key"

if [ ! -f "$CERTIFICATE" ] || [ ! -f "$PRIVATE_KEY" ]; then
    echo "Generando certificado SSL autofirmado para NGINX..."
    
    mkdir -p "$SSL_DIR"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$PRIVATE_KEY" \
        -out "$CERTIFICATE" \
        -subj "/C=ES/ST=Madrid/L=Madrid/O=42/OU=Inception/CN=${DOMAIN_NAME}/UID=${WP_ADMIN}"

    chmod 600 "$PRIVATE_KEY"
    chmod 644 "$CERTIFICATE"
    
    echo "Certificado generado correctamente."
else
    echo "El certificado SSL ya existe. Omitiendo generación."
fi

envsubst '$DOMAIN_NAME' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "Iniciando NGINX..."

exec nginx -g "daemon off;"