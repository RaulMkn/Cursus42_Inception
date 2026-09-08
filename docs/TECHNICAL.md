# Inception — Documentación Técnica Extendida

Este documento profundiza en la lógica compleja de la infraestructura: arquitectura,
estructuras de datos (Docker Compose, redes y volúmenes), manejo de errores en los
entrypoints y prevención de fugas (leaks) de datos y recursos.

Para la vista general del proyecto e instrucciones de uso, consulta el
[`README.md`](../README.md) en la raíz. Para operación y despliegue paso a paso, consulta
[`DEV_DOC.md`](../DEV_DOC.md) y [`USER_DOC.md`](../USER_DOC.md).

---

## 1. Diagrama interactivo de arquitectura

La topología completa está disponible como diagrama interactivo (Archify) en:

- Local: [`inception-architecture.html`](inception-architecture.html)
- GitHub Pages: <https://RaulMkn.github.io/Cursus42_Inception/docs/inception-architecture.html>

El diagrama muestra los ocho contenedores, la red bridge `inception_network`, los dos
volúmenes con bind mount y los caminos de datos (HTTPS, FastCGI, SQL, caché y persistencia).

---

## 2. Arquitectura general

La infraestructura se compone de ocho servicios, cada uno construido desde una imagen
propia basada en **Debian Bookworm**, comunicándose a través de una única red bridge.

### 2.1 Servicios base (obligatorios)

| Servicio | Rol | Puerto | Exposición |
|----------|-----|--------|------------|
| NGINX | Proxy inverso + terminación TLS | 443 | Publicado al host |
| WordPress | Aplicación PHP-FPM 8.2 | 9000 | Solo red interna |
| MariaDB | Base de datos | 3306 | Solo red interna |

### 2.2 Servicios bonus

| Servicio | Rol | Puerto | Exposición |
|----------|-----|--------|------------|
| Redis | Caché de objetos de WordPress | 6379 | Solo red interna |
| FTP (vsftpd) | Acceso a archivos de WordPress | 21 + 30000-30009 | Publicado |
| Adminer | Consola web de base de datos | 8080 | Publicado |
| Static Site | Dashboard de monitorización | 8443 | Publicado |
| cAdvisor | Métricas de contenedores | 8181 | Publicado |

### 2.3 Flujo de una petición

1. El cliente abre `https://rmakende.42.fr` (puerto 443).
2. NGINX termina TLS y sirve estáticos o reenvía el PHP a WordPress por FastCGI (`:9000`).
3. WordPress (PHP-FPM) ejecuta el PHP, consulta MariaDB por SQL (`:3306`) y usa Redis
   como caché de objetos para reducir la carga de la base de datos.
4. La respuesta vuelve por NGINX al cliente.

NGINX es el **único punto de entrada TLS**. MariaDB y Redis nunca se exponen al host: solo
son alcanzables por nombre de servicio dentro de la red bridge.

---

## 3. Estructuras de datos

### 3.1 Red: `inception_network`

Red bridge dedicada. Docker provee DNS interno, por lo que cada servicio resuelve a los
demás por su nombre (`wordpress`, `db`, `redis`, ...). Esto evita hardcodear IPs y aísla
los contenedores del host salvo por los puertos explícitamente publicados.

```yaml
networks:
  inception_network:
    driver: bridge
```

### 3.2 Volúmenes con bind mount

Se usan volúmenes **nombrados** con `driver_opts` para satisfacer dos requisitos a la vez:
Docker gestiona el ciclo de vida del volumen (aparece en `docker volume ls`) mientras los
datos residen físicamente en una ruta concreta del host.

```yaml
volumes:
  wordpress:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rmakende/data/wordpress
  mariadb:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/rmakende/data/mariadb
```

| Dato | Ruta en contenedor | Ruta en host | Volumen |
|------|--------------------|--------------|---------|
| Archivos WordPress | `/var/www/html` | `/home/rmakende/data/wordpress` | `wordpress` |
| Base de datos | `/var/lib/mysql` | `/home/rmakende/data/mariadb` | `mariadb` |

El volumen `wordpress` es **compartido** por tres servicios:

- **wordpress** escribe el core, `wp-config.php`, plugins, temas y subidas.
- **nginx** lee esos archivos para servir estáticos y localizar el socket/puerto PHP.
- **ftp** ofrece acceso a nivel de archivo sobre el mismo directorio.

### 3.3 Variables de entorno y secretos

Las credenciales viven fuera del control de versiones:

- `srcs/.env` (gitignored): nombres de dominio, base de datos, hosts y puertos.
- `secrets/` (gitignored): ficheros con contraseñas.

Ningún Dockerfile hardcodea credenciales; se inyectan por `environment:` en el Compose.

---

## 4. Manejo de errores

### 4.1 Ordenamiento de arranque (wait-for-it)

`depends_on` solo garantiza el **orden de arranque**, no que el servicio esté listo. Por eso
el entrypoint de WordPress espera activamente a que MariaDB responda antes de instalar:

```bash
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
```

Puntos clave del manejo de errores:

- **Timeout acotado**: si MariaDB no responde en 60 s, el contenedor sale con código `1`
  en lugar de colgarse indefinidamente. Con `restart` configurado, Docker reintenta.
- **Idempotencia**: WordPress solo se instala si no existe `wp-config.php`. Un reinicio no
  reinstala ni sobreescribe una instalación existente.
- **Tolerancia en la caché**: `wp redis enable ... || true` evita abortar el arranque si el
  plugin de Redis aún no está disponible.

### 4.2 PID 1 y señales

Todos los entrypoints terminan con `exec`, reemplazando el shell por el daemon real
(`exec /usr/sbin/php-fpm8.2 -F`, `exec /usr/sbin/vsftpd ...`). Así el servicio corre como
PID 1 y recibe correctamente `SIGTERM`/`SIGINT`, permitiendo apagados limpios (`make down`)
sin dejar procesos zombie.

### 4.3 Reinicios

Los servicios usan políticas `restart` (`always` / `unless-stopped`) para recuperarse de
fallos transitorios (por ejemplo, si un dependiente aún no está listo tras el timeout).

---

## 5. Prevención de fugas (leaks) y persistencia

### 5.1 Fugas de datos y persistencia

- Los datos persisten en bind mounts del host, sobreviviendo a `make down` y a la
  recreación de contenedores.
- La destrucción es **explícita**: solo `make fclean` borra los volúmenes y las rutas del
  host. Ningún flujo normal elimina datos de forma accidental.
- Las credenciales no se filtran al repositorio: `.env` y `secrets/` están en `.gitignore`.
  Se referencian por nombre de clave, nunca por valor.

### 5.2 Fugas de procesos y descriptores

- El patrón `exec` evita procesos huérfanos: no queda un shell padre reteniendo recursos.
- vsftpd usa un `secure_chroot_dir` vacío (`/var/run/vsftpd/empty`) y `chroot_local_user`,
  encerrando al usuario FTP en `/var/www/html` para que no acceda al resto del sistema.

### 5.3 Superficie de exposición mínima

- Solo se publican al host los puertos estrictamente necesarios.
- MariaDB y Redis permanecen internos; nunca aceptan conexiones directas desde el host.
- NGINX centraliza la terminación TLS, evitando exponer HTTP en claro.

### 5.4 Permisos de archivos

Los entrypoints normalizan la propiedad y permisos del contenido compartido para evitar
errores de acceso entre servicios:

```bash
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 775 {} \;
find /var/www/html -type f -exec chmod 664 {} \;
```

El usuario FTP se añade al grupo `www-data` para compartir permisos sobre los mismos
archivos sin escalar privilegios.

---

## 6. Verificación rápida

```bash
docker ps                       # deben aparecer 8 contenedores en ejecución
docker network inspect inception_network
docker volume inspect wordpress mariadb
docker exec mariadb mysqladmin -u root -p ping   # "mysqld is alive"
```
