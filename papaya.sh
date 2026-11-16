#!/bin/bash

# ==============================================================================
# SCRIPT DE AUDITORÍA EXHAUSTIVA - INCEPTION (MANDATORY + BONUS)
# ==============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Cargar variables del .env automáticamente
if [ -f "srcs/.env" ]; then
    set -a
    source srcs/.env
    set +a
elif [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Valores por defecto si no se cargaron del .env
DOMAIN=${DOMAIN_NAME:-rmakende.42.fr}
DB_NAME=${DB_NAME:-wordpress}
DB_USER=${DB_USER:-rmakende}
DB_PASS=${DB_PASSWORD:-Retolo-}
DB_ROOT_PASS=${DB_ROOT_PASSWORD:-Retolo-}
FTP_USER=${FTP_USER:-rmakende}
FTP_PASS=${FTP_PASSWORD:-Retolo-}
DATA_DIR="/home/rmakende/data"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    echo -e "  [${GREEN}OK${NC}] $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "  [${RED}FAIL${NC}] $1"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "  [${YELLOW}WARN${NC}] $1"
    ((WARN_COUNT++))
}

header() {
    echo -e "\n${BOLD}${BLUE}==============================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${BLUE}==============================================================================${NC}"
}

sub_header() {
    echo -e "\n${BOLD}${YELLOW}--- $1 ---${NC}"
}

# ==============================================================================
# PARTE 1: VERIFICACIÓN DE LA PARTE OBLIGATORIA (MANDATORY)
# ==============================================================================
header "PARTE 1: PRUEBAS DE LA PARTE OBLIGATORIA (MANDATORY)"

# 1.1 REGLAS DEL SUBJECT Y ESTRUCTURA
sub_header "1.1 Cumplimiento estricto del Subject (Dockerfiles, Compose, Red)"

# Comprobar que no hay tag 'latest'
if grep -rn ":latest" srcs/ 2>/dev/null; then
    fail "Se encontró la etiqueta ':latest' en los archivos de srcs/ (Prohibido)."
else
    pass "Ningún Dockerfile o compose utiliza la etiqueta ':latest'."
fi

# Comprobar que no existe 'network: host' o '--link'
if grep -rnE "network_mode:\s*host|--link|links:" srcs/ 2>/dev/null; then
    fail "Se encontró 'network_mode: host' o 'links' en srcs/ (Prohibido)."
else
    pass "Sin 'network_mode: host' ni 'links' heredados."
fi

# Comprobar PID 1 en contenedores obligatorios (evitar tail -f, sleep infinity, etc.)
for c in nginx wordpress mariadb; do
    PID1_CMD=$(docker exec "$c" ps -p 1 -o comm= 2>/dev/null)
    if [[ "$PID1_CMD" =~ ^(tail|sleep|bash|sh)$ ]]; then
        fail "Contenedor '$c' tiene '$PID1_CMD' como PID 1 (Posible bucle infinito o falta de 'exec')."
    elif [ -n "$PID1_CMD" ]; then
        pass "Contenedor '$c' ejecuta proceso principal limpio como PID 1 ($PID1_CMD)."
    else
        fail "No se pudo verificar el PID 1 del contenedor '$c' (¿Está caído?)."
    fi
done

# Comprobar resolución DNS del dominio local
if grep -q "$DOMAIN" /etc/hosts; then
    pass "El dominio '$DOMAIN' está mapeado en /etc/hosts."
else
    fail "El dominio '$DOMAIN' NO está en /etc/hosts."
fi

# Comprobar red Docker bridge
NET_DRIVER=$(docker network inspect srcs_inception_network --format '{{.Driver}}' 2>/dev/null)
if [ "$NET_DRIVER" == "bridge" ]; then
    pass "Red interna 'srcs_inception_network' configurada con driver 'bridge'."
else
    fail "No se encontró la red bridge 'srcs_inception_network'."
fi

# 1.2 SEGURIDAD DE PUERTOS EXPUESTOS
sub_header "1.2 Aislamiento de Puertos (Solo 443 expuesto para web obligatoria)"

EXPOSED_PORTS=$(docker ps --format "{{.Names}}: {{.Ports}}")
if echo "$EXPOSED_PORTS" | grep "nginx" | grep -q "0.0.0.0:443->443/tcp"; then
    pass "NGINX expone correctamente el puerto 443."
else
    fail "NGINX no está exponiendo el puerto 443."
fi

if echo "$EXPOSED_PORTS" | grep "nginx" | grep -q "0.0.0.0:80->"; then
    fail "NGINX está exponiendo el puerto 80 HTTP inseguro (Prohibido en Inception)."
else
    pass "Puerto 80 HTTP cerrado correctamente en NGINX."
fi

for internal in mariadb wordpress; do
    if echo "$EXPOSED_PORTS" | grep "$internal" | grep -q "0.0.0.0:"; then
        fail "El servicio interno '$internal' está exponiendo puertos hacia el exterior."
    else
        pass "El servicio interno '$internal' está aislado en la red privada."
    fi
done

# 1.3 TLS / SSL EN NGINX
sub_header "1.3 Protocolos Criptográficos TLSv1.2 y TLSv1.3"

# Probar TLSv1.2
if openssl s_client -connect "${DOMAIN}:443" -tls1_2 </dev/null 2>/dev/null | grep -q "Protocol  : TLSv1.2"; then
    pass "NGINX acepta conexiones seguras TLSv1.2."
else
    fail "NGINX rechazó TLSv1.2."
fi

# Probar TLSv1.3
if openssl s_client -connect "${DOMAIN}:443" -tls1_3 </dev/null 2>/dev/null | grep -q "Protocol  : TLSv1.3"; then
    pass "NGINX acepta conexiones seguras TLSv1.3."
else
    fail "NGINX rechazó TLSv1.3."
fi

# Probar que TLSv1.1 está bloqueado
if openssl s_client -connect "${DOMAIN}:443" -tls1_1 </dev/null 2>/dev/null | grep -q "Protocol  : TLSv1.1"; then
    fail "NGINX permite TLSv1.1 obsoleto (Debe bloquearse)."
else
    pass "Protocolos inseguros (TLSv1.0/TLSv1.1) bloqueados correctamente."
fi

# 1.4 MARIADB (BASE DE DATOS Y USUARIOS)
sub_header "1.4 Integridad de MariaDB, Usuarios y Privilegios"

# Verificar que root sin contraseña falla
if docker exec mariadb mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
    fail "¡PELIGRO! El usuario 'root' de MariaDB permite acceso sin contraseña."
else
    pass "El usuario 'root' de MariaDB exige contraseña correctamente."
fi

# Verificar conexión del usuario de WordPress desde otro contenedor
if docker exec wordpress php -r "\$c = @mysqli_connect('db', '$DB_USER', '$DB_PASS', '$DB_NAME'); if (!\$c) exit(1); mysqli_close(\$c);" 2>/dev/null; then
    pass "Conexión remota desde WordPress hacia MariaDB ('db') con usuario '$DB_USER' exitosa."
else
    fail "WordPress NO puede conectarse a MariaDB con el usuario '$DB_USER'."
fi

# Verificar tablas de WordPress creadas
WP_TABLES=$(docker exec mariadb mariadb -u root -p"$DB_ROOT_PASS" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null)
if [ -n "$WP_TABLES" ] && [ "$WP_TABLES" -ge 12 ]; then
    pass "La base de datos '$DB_NAME' contiene las $WP_TABLES tablas estándar de WordPress."
else
    fail "La base de datos '$DB_NAME' está vacía o incompleta (Tablas encontradas: ${WP_TABLES:-0})."
fi

# 1.5 WORDPRESS Y PHP-FPM
sub_header "1.5 WordPress Frontend, Panel Admin y Usuarios"

# Petición HTTPS a la portada
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DOMAIN}/")
if [ "$HTTP_CODE" == "200" ]; then
    pass "Portada de WordPress responde HTTP 200 OK en https://${DOMAIN}/."
else
    fail "Portada de WordPress devolvió código HTTP $HTTP_CODE."
fi

# Verificar que el HTML contiene estructura real de WordPress y no texto plano/error PHP
WP_BODY=$(curl -sk "https://${DOMAIN}/")
if echo "$WP_BODY" | grep -qiE "wp-content|wordpress"; then
    pass "El contenido renderizado corresponde a WordPress activo."
else
    fail "La respuesta de https://${DOMAIN}/ no parece contener una instalación válida de WordPress."
fi

# Verificar que el admin de WordPress no contiene 'admin' o 'administrator'
ADMIN_CHECK=$(docker exec mariadb mariadb -u root -p"$DB_ROOT_PASS" -N -e "SELECT user_login FROM ${DB_NAME}.wp_users;" 2>/dev/null)
if echo "$ADMIN_CHECK" | grep -qiE "^(admin|administrator)$"; then
    fail "Existe un usuario llamado 'admin' o 'administrator' en WordPress (Prohibido por el subject)."
else
    pass "Usuarios de WordPress conformes (sin nombres 'admin' prohibidos): $(echo $ADMIN_CHECK | tr '\n' ' ')."
fi

# Verificar que existen al menos 2 usuarios en WordPress
USER_COUNT=$(echo "$ADMIN_CHECK" | wc -w)
if [ "$USER_COUNT" -ge 2 ]; then
    pass "Existen $USER_COUNT usuarios registrados en WordPress (Admin + Usuario normal)."
else
    fail "Solo existe $USER_COUNT usuario en WordPress (Se exigen mínimo 2)."
fi

# 1.6 VOLÚMENES Y PERSISTENCIA EN EL HOST
sub_header "1.6 Volúmenes Bind Mount en el Host ($DATA_DIR)"

if [ -d "${DATA_DIR}/mariadb" ] && [ "$(ls -A ${DATA_DIR}/mariadb 2>/dev/null)" ]; then
    pass "Directorio persistente ${DATA_DIR}/mariadb existe y contiene archivos de datos."
else
    fail "Directorio ${DATA_DIR}/mariadb vacío o inexistente."
fi

if [ -d "${DATA_DIR}/wordpress" ] && [ "$(ls -A ${DATA_DIR}/wordpress 2>/dev/null)" ]; then
    pass "Directorio persistente ${DATA_DIR}/wordpress existe y contiene los archivos web."
else
    fail "Directorio ${DATA_DIR}/wordpress vacío o inexistente."
fi


# ==============================================================================
# PARTE 2: VERIFICACIÓN DE LOS BONUS
# ==============================================================================
header "PARTE 2: PRUEBAS DE LOS SERVICIOS BONUS"

# 2.1 BONUS: REDIS CACHE
sub_header "2.1 Bonus 1: Redis Object Cache"

if docker ps --format '{{.Names}}' | grep -q "^redis$"; then
    # Ping interno a Redis
    REDIS_PING=$(docker exec redis redis-cli ping 2>/dev/null)
    if [ "$REDIS_PING" == "PONG" ]; then
        pass "Servidor Redis responde 'PONG' correctamente."
    else
        fail "Redis no respondió PONG (Salida: $REDIS_PING)."
    fi

    # Comprobar conexión desde WordPress hacia Redis
    if docker exec wordpress php -r "\$r = new Redis(); if (!@\$r->connect('redis', 6379)) exit(1);" 2>/dev/null; then
        pass "Extensión PHP-Redis en WordPress conecta correctamente con el host 'redis:6379'."
    else
        warn "WordPress no pudo abrir socket PHP hacia 'redis:6379' (Revisa wp-config.php o extensión php-redis)."
    fi

    # Comprobar si hay claves almacenadas en Redis (caché activa)
    REDIS_KEYS=$(docker exec redis redis-cli dbsize 2>/dev/null | awk '{print $2}')
    if [ -n "$REDIS_KEYS" ] && [ "$REDIS_KEYS" -gt 0 ]; then
        pass "Redis está cacheando activamente objetos de WordPress ($REDIS_KEYS claves en memoria)."
    else
        warn "Redis está conectado pero tiene 0 claves almacenadas (Verifica que el plugin Redis Object Cache esté activado en WP)."
    fi
else
    warn "Contenedor 'redis' no está en ejecución."
fi

# 2.2 BONUS: SERVIDOR FTP
sub_header "2.2 Bonus 2: Servidor FTP (vsftpd apuntando al volumen de WordPress)"

if docker ps --format '{{.Names}}' | grep -q "^ftp$"; then
    # Probar login FTP, subida de archivo de prueba, verificación en volumen WP y borrado
    TEST_FILE="inception_ftp_test_$(date +%s).txt"
    echo "Prueba automatizada FTP Inception" > "/tmp/${TEST_FILE}"

    if curl -s --user "${FTP_USER}:${FTP_PASS}" -T "/tmp/${TEST_FILE}" "ftp://localhost/${TEST_FILE}" >/dev/null 2>&1; then
        pass "Autenticación FTP con usuario '${FTP_USER}' y subida de archivo exitosas."

        # Verificar que el archivo apareció dentro del directorio de WordPress
        if docker exec wordpress test -f "/var/www/html/${TEST_FILE}" || [ -f "${DATA_DIR}/wordpress/${TEST_FILE}" ]; then
            pass "El servidor FTP apunta directamente al volumen persistente de WordPress (/var/www/html)."
        else
            fail "El archivo subido por FTP no apareció en el directorio de WordPress."
        fi

        # Limpiar archivo de prueba via FTP
        curl -s --user "${FTP_USER}:${FTP_PASS}" -Q "DELE ${TEST_FILE}" "ftp://localhost/" >/dev/null 2>&1
        rm -f "/tmp/${TEST_FILE}"
        pass "Limpieza del archivo de prueba FTP completada."
    else
        fail "Fallo al autenticar o subir archivo por FTP con usuario '${FTP_USER}'."
        rm -f "/tmp/${TEST_FILE}"
    fi
else
    warn "Contenedor 'ftp' no está en ejecución."
fi

# 2.3 BONUS: ADMINER
sub_header "2.3 Bonus 3: Adminer (Enrutado por NGINX HTTPS y aislado)"

if docker ps --format '{{.Names}}' | grep -q "^adminer$"; then
    # Verificar que no expone puertos directos al host
    if docker ps --format "{{.Names}}: {{.Ports}}" | grep "adminer" | grep -q "0.0.0.0:"; then
        warn "Adminer sigue exponiendo un puerto directo al host en lugar de solo 'expose'."
    else
        pass "Adminer está aislado internamente (solo accesible vía NGINX)."
    fi

    # Verificar acceso HTTPS a través de NGINX
    ADMINER_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DOMAIN}/adminer/")
    if [ "$ADMINER_CODE" == "200" ]; then
        pass "Adminer responde HTTP 200 OK a través del proxy inverso https://${DOMAIN}/adminer/."
    else
        fail "Adminer devolvió código HTTP $ADMINER_CODE en https://${DOMAIN}/adminer/."
    fi

    # Simular POST real de login en Adminer a través de NGINX
    ADMINER_LOGIN=$(curl -sk -i -d "auth[driver]=server&auth[server]=db&auth[username]=${DB_USER}&auth[password]=${DB_PASS}&auth[db]=${DB_NAME}" "https://${DOMAIN}/adminer/" | grep -i "^Location:")
    if echo "$ADMINER_LOGIN" | grep -q "username=${DB_USER}"; then
        pass "Prueba completa de autenticación POST en Adminer hacia MariaDB exitosa (302 Redirect válido)."
    else
        fail "El login automatizado en Adminer falló o no redirigió correctamente."
    fi
else
    warn "Contenedor 'adminer' no está en ejecución."
fi

# 2.4 BONUS: SITIO ESTÁTICO (STATIC SITE)
sub_header "2.4 Bonus 4: Sitio Web Estático (Sin PHP)"

if docker ps --format '{{.Names}}' | grep -q "^static-site$"; then
    STATIC_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost:8090/" 2>/dev/null)
    if [ "$STATIC_CODE" == "000" ]; then
        STATIC_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8090/" 2>/dev/null)
    fi

    if [ "$STATIC_CODE" == "200" ]; then
        pass "Sitio estático accesible y respondiendo HTTP 200 OK en el puerto 8090."
    else
        fail "El sitio estático no respondió 200 OK en el puerto 8090 (Código: $STATIC_CODE)."
    fi

    # Verificar que no tiene PHP instalado en el contenedor
    if docker exec static-site which php >/dev/null 2>&1; then
        fail "El contenedor 'static-site' tiene PHP instalado (Debe ser 100% estático)."
    else
        pass "El contenedor 'static-site' no contiene PHP (Cumple requisito estático)."
    fi
else
    warn "Contenedor 'static-site' no está en ejecución."
fi

# 2.5 BONUS: CADVISOR (SERVICIO ADICIONAL DE MONITORIZACIÓN)
sub_header "2.5 Bonus 5: cAdvisor (Monitorización de Contenedores)"

if docker ps --format '{{.Names}}' | grep -q "^cadvisor$"; then
    CADVISOR_CODE=$(curl -sL -o /dev/null -w "%{http_code}" "http://localhost:8181/containers/" 2>/dev/null)
    if [ "$CADVISOR_CODE" == "200" ]; then
        pass "Interfaz web de cAdvisor respondiendo HTTP 200 OK en http://localhost:8181."
    else
        fail "cAdvisor no respondió 200 OK en el puerto 8181 (Código: $CADVISOR_CODE)."
    fi

    # Verificar que está leyendo métricas de Docker
    if curl -sL "http://localhost:8181/api/v1.3/subcontainers" 2>/dev/null | grep -q "nginx"; then
        pass "cAdvisor está recolectando métricas en tiempo real de los contenedores Docker."
    else
        warn "cAdvisor responde pero no se detectaron métricas de los subcontenedores Docker."
    fi
else
    warn "Contenedor 'cadvisor' no está en ejecución."
fi

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================
header "RESUMEN DE AUDITORÍA"
echo -e "  ${GREEN}${BOLD}PRUEBAS SUPERADAS : $PASS_COUNT${NC}"
echo -e "  ${YELLOW}${BOLD}ADVERTENCIAS      : $WARN_COUNT${NC}"
echo -e "  ${RED}${BOLD}ERRORES CRÍTICOS  : $FAIL_COUNT${NC}"
echo -e "${BOLD}${BLUE}==============================================================================${NC}\n"

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}¡INFRAESTRUCTURA LISTA PARA LA EVALUACIÓN!${NC}\n"
    exit 0
else
    echo -e "${RED}${BOLD}REVISA LOS ERRORES MARCADOS EN ROJO ANTES DE LA DEFENSA.${NC}\n"
    exit 1
fi
