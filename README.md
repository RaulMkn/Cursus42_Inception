*This project has been created as part of the 42 curriculum by rmakende.*

# Inception

## Description

Inception is a system administration project that uses Docker to virtualize a complete web infrastructure inside a virtual machine. The goal is to build, configure, and orchestrate multiple services using custom Docker images, Docker Compose, and Docker networks — without relying on pre-made images from DockerHub.

The infrastructure deploys a functional WordPress website backed by MariaDB, served through NGINX with TLS encryption, and enhanced with bonus services including Redis caching, FTP access, a real-time monitoring dashboard, Adminer for database management, and cAdvisor for container metrics collection.

All containers are built from Debian Bookworm, use custom Dockerfiles, and communicate through a dedicated Docker network. Data persistence is handled through Docker named volumes stored on the host filesystem.

### Design Choices

- **Debian Bookworm** was chosen as the base image for all services for consistency and package availability.
- **PID 1 best practices**: all entrypoints use `exec` to replace the shell process with the actual service daemon, ensuring proper signal handling.
- **Wait-for-it pattern**: WordPress entrypoint waits for MariaDB to be ready before proceeding with installation, handling startup ordering beyond `depends_on`.
- **Environment variables and secrets**: credentials are stored in `.env` (gitignored) and a `secrets/` directory, never hardcoded in Dockerfiles.
- **Monitoring Dashboard**: the static site bonus is a real-time infrastructure dashboard (HTML/CSS/JS, no PHP) that consumes cAdvisor's REST API to display SLO metrics, container health, CPU/memory graphs, and network I/O. NGINX proxies API requests internally to avoid CORS issues.

### Virtual Machines vs Docker

| Aspect | Virtual Machines | Docker Containers |
|--------|-----------------|-------------------|
| Isolation | Full OS kernel per VM | Shares host kernel |
| Resource usage | Heavy (GB of RAM per VM) | Lightweight (MB per container) |
| Boot time | Minutes | Seconds |
| Portability | Limited, tied to hypervisor | Highly portable across systems |
| Use case | Full OS isolation needed | Application-level isolation |

Docker containers are not VMs — they share the host kernel and run as isolated processes. This makes them faster and lighter, but with less isolation than a full VM.

### Secrets vs Environment Variables

| Aspect | Environment Variables | Docker Secrets |
|--------|----------------------|----------------|
| Storage | In .env file or compose | In files, mounted at /run/secrets/ |
| Visibility | Visible via `docker inspect` | Only accessible inside the container |
| Security | Moderate (exposed in process env) | Higher (tmpfs, not persisted to disk) |
| Use case | Non-sensitive config (ports, hosts) | Passwords, API keys, tokens |

For this project, sensitive credentials are stored in the `secrets/` directory and the `.env` file is gitignored to prevent accidental exposure.

### Docker Network vs Host Network

| Aspect | Docker Bridge Network | Host Network |
|--------|----------------------|--------------|
| Isolation | Containers isolated from host | No isolation, shares host ports |
| DNS | Built-in service discovery by name | No container DNS |
| Security | Containers only reach declared peers | All ports exposed to host |
| Use case | Multi-service apps (like this project) | Performance-critical single containers |

This project uses a bridge network (`inception_network`) so containers communicate via service names (e.g., `wordpress` resolves to the WordPress container IP).

### Docker Volumes vs Bind Mounts

| Aspect | Named Volumes | Bind Mounts |
|--------|--------------|-------------|
| Management | Docker manages lifecycle | User manages manually |
| Portability | Portable, listed in `docker volume ls` | Tied to specific host path |
| Backup | Easy via Docker commands | Manual file operations |
| Permissions | Docker handles ownership | Host permission issues common |
| Use case | Database storage, persistent app data | Development hot-reload, config files |

This project uses named volumes with `driver_opts` to satisfy both requirements: Docker manages the volumes (named), while data physically resides at `/home/rmakende/data/` on the host.

## Instructions

### Prerequisites

- A virtual machine running Debian/Ubuntu with Docker and Docker Compose installed.
- `make` available in the system.
- The domain `rmakende.42.fr` must resolve to the VM's local IP (add to `/etc/hosts`).

### Building and Running

```bash
make        # Creates data directories, builds images, and starts all containers
make down   # Stops containers without deleting data
make clean  # Stops containers and removes images
make fclean # Nuclear option: removes everything including volume data
make re     # Full rebuild from scratch
```

### Accessing Services

| Service | URL / Access |
|---------|-------------|
| WordPress | https://rmakende.42.fr |
| Adminer | http://rmakende.42.fr:8080 |
| Monitoring Dashboard | http://rmakende.42.fr:8443 |
| cAdvisor API | http://rmakende.42.fr:8181 |
| FTP | ftp://rmakende.42.fr:21 |

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Specification](https://docs.docker.com/compose/compose-file/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [WordPress CLI Documentation](https://developer.wordpress.org/cli/commands/)
- [NGINX Configuration Guide](https://nginx.org/en/docs/)
- [MariaDB Docker Setup](https://mariadb.com/kb/en/installing-and-using-mariadb-via-docker/)
- [Redis Configuration](https://redis.io/docs/management/config/)
- [cAdvisor GitHub](https://github.com/google/cadvisor)

### AI Usage

AI tools were used during this project for:
- Generating boilerplate entrypoint scripts and Dockerfile structures.
- Debugging Docker Compose configuration issues.
- Understanding Docker named volumes with driver_opts.
- Drafting documentation structure.

All AI-generated content was reviewed, tested, and adapted to fit the project requirements. The final implementation reflects personal understanding validated through peer discussion and hands-on testing.
