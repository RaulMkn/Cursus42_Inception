# User Documentation

## Services Overview

This infrastructure provides the following services:

| Service | Purpose | Access |
|---------|---------|--------|
| WordPress | Main website and blog platform | https://rmakende.42.fr |
| MariaDB | Database backend for WordPress | Internal only (not exposed) |
| NGINX | Reverse proxy with TLS encryption | https://rmakende.42.fr (port 443) |
| Redis | Cache layer for faster WordPress performance | Internal only |
| FTP | File access to WordPress content | ftp://rmakende.42.fr:21 |
| Adminer | Web-based database management | http://rmakende.42.fr:8080 |
| Static Site | Portfolio / showcase website | http://rmakende.42.fr:8443 |
| cAdvisor | Container resource monitoring | http://rmakende.42.fr:8181 |

## Starting and Stopping the Project

### Start everything

```bash
make
```

This creates the necessary directories and starts all containers. The first run will take a few minutes as Docker builds all images.

### Stop without losing data

```bash
make down
```

All your WordPress content, database, and uploads are preserved. Next time you run `make`, everything comes back as it was.

### Full reset (destructive)

```bash
make fclean
```

This removes all containers, images, volumes, and data. Use only if you want to start completely fresh.

## Accessing the Website

1. Make sure the domain is configured in your `/etc/hosts` file:
   ```
   127.0.0.1  rmakende.42.fr
   ```

2. Open a browser and navigate to `https://rmakende.42.fr`

3. Accept the self-signed certificate warning (the certificate is generated automatically on first boot).

4. You should see the WordPress site.

## Accessing the Administration Panel

1. Navigate to `https://rmakende.42.fr/wp-admin`

2. Log in with the administrator credentials:
   - Username: see `secrets/credentials.txt` (WP_ADMIN field)
   - Password: see `secrets/credentials.txt` (WP_ADMIN_PASS field)

3. From the admin panel you can manage posts, pages, themes, plugins, and users.

## Accessing Adminer (Database Management)

1. Navigate to `http://rmakende.42.fr:8080`

2. Log in with:
   - System: MySQL
   - Server: pre-filled (db)
   - Username: see `srcs/.env` (DB_USER field)
   - Password: see `secrets/db_password.txt`
   - Database: see `srcs/.env` (DB_NAME field)

## Accessing FTP

1. Use any FTP client (FileZilla, command-line ftp, etc.)

2. Connect to:
   - Host: rmakende.42.fr
   - Port: 21
   - Username: see `secrets/credentials.txt` (FTP_USER field)
   - Password: see `secrets/credentials.txt` (FTP_PASSWORD field)

3. You will have access to the WordPress files at `/var/www/html`.

## Managing Credentials

Credentials are stored in two locations:

- **`secrets/`** — Contains password files (not tracked by git):
  - `credentials.txt` — WordPress admin, user, and FTP credentials
  - `db_password.txt` — Database user password
  - `db_root_password.txt` — Database root password

- **`srcs/.env`** — Contains environment configuration (not tracked by git):
  - Domain name, database name, hostnames, ports

To change a password:
1. Edit the corresponding file in `secrets/` or `srcs/.env`
2. Run `make fclean && make` to rebuild with new credentials

## Checking That Services Are Running

### Quick check

```bash
docker ps
```

You should see 8 containers running: nginx, wordpress, mariadb, redis, ftp, adminer, static-site, cadvisor.

### Check a specific service

```bash
docker logs <container_name>
```

For example: `docker logs wordpress` or `docker logs mariadb`

### Check from browser

- WordPress: https://rmakende.42.fr should show the site
- Adminer: http://rmakende.42.fr:8080 should show login page
- Static site: http://rmakende.42.fr:8443 should show the portfolio
- cAdvisor: http://rmakende.42.fr:8181 should show monitoring dashboard

### Check database connectivity

```bash
docker exec mariadb mysqladmin -u root -p ping
```

If it responds "mysqld is alive", the database is running correctly.
