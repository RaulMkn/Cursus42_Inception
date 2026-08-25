# Developer Documentation

## Setting Up the Environment from Scratch

### Prerequisites

- A virtual machine running Debian 12 (Bookworm) or Ubuntu 22.04+
- Docker Engine installed (not Docker Desktop)
- Docker Compose v2 (comes with Docker Engine)
- `make` installed (`apt-get install make`)
- `sudo` access for managing host directories

### Installation Steps

1. Install Docker:
   ```bash
   sudo apt-get update
   sudo apt-get install docker.io docker-compose-plugin
   sudo usermod -aG docker $USER
   ```
   Log out and back in for group changes to take effect.

2. Clone the repository:
   ```bash
   git clone <repo-url> inception
   cd inception
   ```

3. Configure the environment file:
   ```bash
   cp srcs/.env.example srcs/.env   # if template exists
   # Or create srcs/.env manually with required variables
   ```

   Required variables in `srcs/.env`:
   - `DOMAIN_NAME` — your login.42.fr domain
   - `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_ROOT_PASSWORD`
   - `REDIS_HOST`, `REDIS_PORT`
   - `WP_ADMIN`, `WP_ADMIN_PASS`, `WP_USER`, `WP_USER_PASS`
   - `FTP_USER`, `FTP_PASSWORD`, `FTP_PASV_ADDRESS`
   - `ADMINER_DEFAULT_SERVER`

4. Create the secrets files:
   ```bash
   mkdir -p secrets
   echo "your_db_password" > secrets/db_password.txt
   echo "your_root_password" > secrets/db_root_password.txt
   ```

5. Configure DNS resolution:
   ```bash
   sudo echo "127.0.0.1  rmakende.42.fr" >> /etc/hosts
   ```

6. Build and launch:
   ```bash
   make
   ```

## Building and Launching with Makefile and Docker Compose

### Makefile Targets

| Command | Action |
|---------|--------|
| `make` or `make build` | Creates host directories, builds all images, starts containers |
| `make down` | Stops all containers (data preserved) |
| `make clean` | Stops containers + removes all Docker images |
| `make fclean` | Nuclear: removes containers, images, volumes, and host data |
| `make re` | Full rebuild: `fclean` then `build` |

### How the Build Works

1. `make build` creates `/home/rmakende/data/mariadb` and `/home/rmakende/data/wordpress` on the host.
2. Docker Compose reads `srcs/docker-compose.yaml` and the `srcs/.env` file.
3. Each service builds its image from its Dockerfile in `srcs/requirements/<service>/`.
4. Named volumes are created with `driver_opts` pointing to the host directories.
5. Containers start in dependency order (db → wordpress → nginx).

### Building a Single Service

```bash
docker compose -f srcs/docker-compose.yaml build <service_name>
docker compose -f srcs/docker-compose.yaml up -d <service_name>
```

## Managing Containers and Volumes

### Container Management

```bash
# List running containers
docker ps

# View logs for a specific container
docker logs <container_name>
docker logs -f <container_name>    # follow mode

# Enter a running container
docker exec -it <container_name> /bin/bash

# Restart a single service
docker compose -f srcs/docker-compose.yaml restart <service_name>

# Rebuild a single service without stopping others
docker compose -f srcs/docker-compose.yaml up -d --build <service_name>
```

### Volume Management

```bash
# List all Docker volumes
docker volume ls

# Inspect a specific volume
docker volume inspect wordpress
docker volume inspect mariadb

# Check volume disk usage
du -sh /home/rmakende/data/wordpress
du -sh /home/rmakende/data/mariadb
```

### Network Inspection

```bash
# See all containers on the network
docker network inspect inception_network

# Test connectivity between containers
docker exec wordpress ping db
docker exec nginx ping wordpress
```

## Data Storage and Persistence

### Where Data Lives

| Data | Container Path | Host Path | Volume Name |
|------|---------------|-----------|-------------|
| WordPress files | `/var/www/html` | `/home/rmakende/data/wordpress` | `wordpress` |
| MariaDB database | `/var/lib/mysql` | `/home/rmakende/data/mariadb` | `mariadb` |

### How Persistence Works

- Named volumes with `driver: local` and `driver_opts` (type: none, o: bind) map Docker-managed volumes to specific host paths.
- Data survives `make down` (container stop) and `docker compose up` (container recreation).
- Data is destroyed only by `make fclean` which explicitly removes the host directories.
- The Makefile creates the host directories before Docker Compose runs, ensuring the mount points exist.

### Shared Volumes

Three services share the `wordpress` volume:
- **wordpress** — writes PHP files, wp-config.php, plugins, themes, uploads
- **nginx** — reads PHP files to serve static content and proxy PHP to wordpress
- **ftp** — provides file-level access for uploading/editing WordPress content

### Backup Strategy

```bash
# Backup WordPress files
sudo tar -czf wp-backup.tar.gz /home/rmakende/data/wordpress

# Backup database
docker exec mariadb mysqldump -u root -p wordpress > db-backup.sql

# Restore database
docker exec -i mariadb mysql -u root -p wordpress < db-backup.sql
```

## Project Structure

```
inception/
├── Makefile                          # Build orchestration
├── README.md                         # Project overview and comparisons
├── USER_DOC.md                       # End-user documentation
├── DEV_DOC.md                        # This file
├── secrets/                          # Credentials (gitignored)
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                          # Environment variables (gitignored)
    ├── docker-compose.yaml           # Service orchestration
    └── requirements/
        ├── nginx/                    # Reverse proxy + TLS
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── utils/entrypoint.sh
        ├── wordpress/                # PHP-FPM + WP-CLI
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/entrypoint.sh
        ├── mariadb/                  # Database
        │   ├── Dockerfile
        │   ├── conf/mariadb.conf
        │   └── tools/entrypoint.sh
        ├── redis/                    # Cache
        │   ├── Dockerfile
        │   ├── conf/redis.conf
        │   └── tools/entrypoint.sh
        ├── ftp/                      # FTP server
        │   ├── Dockerfile
        │   └── tools/entrypoint.sh
        ├── adminer/                  # DB web interface
        │   ├── Dockerfile
        │   └── tools/entrypoint.sh
        ├── static-site/              # Static HTML portfolio
        │   ├── Dockerfile
        │   ├── site/index.html
        │   ├── site/style.css
        │   └── tools/entrypoint.sh
        └── cadvisor/                 # Container monitoring
            ├── Dockerfile
            └── tools/entrypoint.sh
```

## Debugging Common Issues

### WordPress shows "Error establishing a database connection"
- MariaDB may not be ready yet. Check logs: `docker logs mariadb`
- Verify credentials match between `.env` and what MariaDB initialized with.
- If the volume already had data from a previous run with different credentials, do `make fclean && make`.

### NGINX returns 502 Bad Gateway
- WordPress container may not be running: `docker ps | grep wordpress`
- PHP-FPM may not be listening on port 9000: `docker exec wordpress ss -tlnp`

### Permission errors on WordPress files
- The entrypoint sets ownership to `www-data`. If you manually edited files, run:
  ```bash
  docker exec wordpress chown -R www-data:www-data /var/www/html
  ```

### Volumes not mounting correctly
- Ensure host directories exist before running compose: `ls -la /home/rmakende/data/`
- Check volume configuration: `docker volume inspect wordpress`
- The `device` path in `driver_opts` must be an absolute path that already exists.
