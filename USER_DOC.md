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
| Adminer | Web-based database management | https://rmakende.42.fr/adminer/ |
| Static Site | Portfolio / showcase website | https://rmakende.42.fr/static/ |
| cAdvisor | Container resource monitoring | https://rmakende.42.fr/cadvisor/ |

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
   - Username: see `srcs/.env` (WP_ADMIN field)
   - Password: see `srcs/.env` (WP_ADMIN_PASS field)

3. From the admin panel you can manage posts, pages, themes, plugins, and users.

## Accessing Adminer (Database Management)

1. Navigate to `https://rmakende.42.fr/adminer/`

2. Log in with:
   - System: MySQL
   - Server: pre-filled (db)
   - Username: see `srcs/.env` (DB_USER field)
   - Password: see `srcs/.env` (DB_PASSWORD field)
   - Database: see `srcs/.env` (DB_NAME field)

## Accessing FTP

1. Use any FTP client (FileZilla, command-line ftp, etc.)

2. Connect to:
   - Host: rmakende.42.fr
   - Port: 21
   - Username: see `srcs/.env` (FTP_USER field)
   - Password: see `srcs/.env` (FTP_PASSWORD field)

3. You will have access to the WordPress files at `/var/www/html`.

## Managing Credentials

All configuration and credentials live in `srcs/.env` (not tracked by git):

- Domain name, database name, hostnames, ports
- WordPress admin/user, database and FTP credentials

To change a password:
1. Edit the corresponding variable in `srcs/.env`
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
- Adminer: https://rmakende.42.fr/adminer/ should show login page
- Static site: https://rmakende.42.fr/static/ should show the portfolio
- cAdvisor: https://rmakende.42.fr/cadvisor/ should show monitoring dashboard

### Check database connectivity

```bash
docker exec mariadb mysqladmin -u root -p ping
```

If it responds "mysqld is alive", the database is running correctly.
