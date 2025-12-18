<div align="center">

# WordPress + Nginx + PHP-FPM

**Battle-tested WordPress images on top of the secured `lahiru98s/php-nginx` base. WP core and WP-CLI are baked in with opinionated PHP/Nginx defaults, non-root runtime, Supervisor-managed services, and ready-to-ship health checks.**

<div align="center">
  <p>
    <a href="https://hub.docker.com/r/lahiru98s/wordpress-nginx"><img src="https://img.shields.io/badge/Docker-Hub-2496ED?logo=docker&logoColor=white" alt="Docker Hub" /></a>
    <a href="#"><img src="https://img.shields.io/badge/PHP-7.4%20|%208.1%20|%208.2%20|%208.3%20|%208.4-777BB4?logo=php&logoColor=white" alt="PHP versions" /></a>
    <a href="#"><img src="https://img.shields.io/badge/WordPress-latest-21759B?logo=wordpress&logoColor=white" alt="WordPress latest" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache--2.0-blue" alt="License" /></a>
    <a href="https://github.com/nooblk-98/wordpress-docker-template/actions/workflows/build-and-push.yml"><img src="https://github.com/nooblk-98/wordpress-docker-template/actions/workflows/build-and-push.yml/badge.svg" alt="CI/CD" /></a>
  </p>

  <p><a href="#overview">Overview</a> | <a href="#features">Features</a> | <a href="#quick-start">Quick Start</a> | <a href="#available-tags">Available Tags</a> | <a href="#configuration">Configuration</a> | <a href="#troubleshooting">Troubleshooting</a></p>
</div>

---

## Overview

- WordPress core downloaded at build time (override with `WORDPRESS_VERSION`).
- WP-CLI installed globally; used to create `wp-config.php` with sane defaults and shuffled salts.
- Hardened Nginx + PHP-FPM from `lahiru98s/php-nginx`, running as non-root `app`.
- Supervisor manages Nginx/PHP-FPM with proper init (tini) and Docker healthcheck wired to `/fpm-ping`.

---

## Features

### Security & hardening
- Non-root runtime, minimal Alpine base inherited from the php-nginx image.
- Locked-down Nginx headers; socket-based PHP-FPM for faster, safer IPC.
- Secrets stay out of the image: config generated at runtime, salts shuffled once.

### WordPress experience
- `wp-config.php` auto-created if missing; respects DB/env overrides and common toggles (debug, cache, cron, SSL admin, environment type).
- Optional auto-install via `WORDPRESS_AUTO_INSTALL=true` once the DB is reachable.
- PHP overrides for uploads, memory/time limits, and input vars via [php/php.ini](php/php.ini).

### Operations & observability
- Health endpoints (`/fpm-ping`, `/fpm-status`) plus Docker healthcheck.
- Structured logs from Nginx and PHP-FPM; Supervisor keeps both services up.
- Compose example with MariaDB and persistent `wp-content`.

### Flexibility
- Mirrors base layout: versioned Dockerfiles in `wp74`, `wp81`, `wp82`, `wp83`, `wp84`.
- Build args to pin PHP tag (`PHP_TAG`), PHP package suffix (`PHP_VERSION` dotless), and `WORDPRESS_VERSION`.

---

## Quick Start

### Option 1: Docker Compose (recommended)

```bash
git clone https://github.com/nooblk-98/wordpress-docker-template.git
cd wordpress-docker-template

docker compose up -d
open http://localhost:8080
```

Defaults: builds PHP 8.4 image, starts MariaDB 11, auto-installs WordPress with starter admin creds. Persist data by enabling the volumes in `docker-compose.yml`.

### Option 2: Run with an external database

```bash
docker run -d \
  --name wordpress-nginx \
  -p 8080:8080 \
  -e WORDPRESS_DB_HOST=your-db:3306 \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=wordpress \
  lahiru98s/wordpress-nginx:8.4
```

### Option 3: Pull image directly

```bash
docker pull lahiru98s/wordpress-nginx:8.4
```

---

## Available Tags

| PHP version | Image tag | Dockerfile | Status |
| ----------- | --------- | ---------- | ------ |
| 8.4 | `8.4`, `latest` | [wp84/Dockerfile](wp84/Dockerfile) | Stable |
| 8.3 | `8.3` | [wp83/Dockerfile](wp83/Dockerfile) | Stable |
| 8.2 | `8.2` | [wp82/Dockerfile](wp82/Dockerfile) | Stable |
| 8.1 | `8.1` | [wp81/Dockerfile](wp81/Dockerfile) | Stable |
| 7.4 | `7.4` | [wp74/Dockerfile](wp74/Dockerfile) | Legacy |

Default build args: `PHP_TAG=8.4`, `PHP_VERSION=84`, `WORDPRESS_VERSION=latest`.

---

## Building from Source

### Generic build (default PHP 8.4)

```bash
docker build -t lahiru98s/wordpress-nginx:8.4 .
```

### Pin PHP/WordPress versions

```bash
docker build \
  -t lahiru98s/wordpress-nginx:8.3 \
  --build-arg PHP_TAG=8.3 \
  --build-arg PHP_VERSION=83 \
  --build-arg WORDPRESS_VERSION=6.7.1 \
  .
```

### Build from a versioned Dockerfile

```bash
docker build -t lahiru98s/wordpress-nginx:8.1 -f wp81/Dockerfile .
```

---

## Configuration

Entrypoint environment variables (all optional):

- `WORDPRESS_DB_HOST` (default `db:3306`)
- `WORDPRESS_DB_NAME` (default `wordpress`)
- `WORDPRESS_DB_USER` / `WORDPRESS_DB_PASSWORD` (default `wordpress` / `wordpress`)
- `WORDPRESS_TABLE_PREFIX` (default `wp_`)
- `WORDPRESS_DEBUG`, `WORDPRESS_CACHE`, `WORDPRESS_FORCE_SSL_ADMIN`, `WORDPRESS_DISABLE_CRON`, `WORDPRESS_ENVIRONMENT_TYPE` (defaults: `false`, `false`, `false`, `false`, `production`)
- `WORDPRESS_AUTO_INSTALL` (`true` triggers `wp core install` once DB is reachable)
- `WORDPRESS_SITE_URL`, `WORDPRESS_SITE_TITLE`, `WORDPRESS_ADMIN_USER`, `WORDPRESS_ADMIN_PASSWORD`, `WORDPRESS_ADMIN_EMAIL` (used when auto-install is enabled)
- `WORDPRESS_PATH` (default `/var/www/html`)

Volume examples:

```yaml
services:
  wordpress:
    volumes:
      - ./wp-data:/var/www/html/wp-content
  db:
    volumes:
      - ./db-data:/var/lib/mysql
```

Key configuration files:

- [nginx/nginx.conf](nginx/nginx.conf) and [nginx/conf.d/default.conf](nginx/conf.d/default.conf)
- [php/php.ini](php/php.ini)
- [supervisord/supervisord.conf](supervisord/supervisord.conf)
- [docker/entrypoint.sh](docker/entrypoint.sh)

---

## Monitoring & Health

- FPM ping: `http://localhost:8080/fpm-ping`
- FPM status: `http://localhost:8080/fpm-status`
- Docker health status: `docker inspect --format='{{.State.Health.Status}}' wordpress` (container name may differ)

Log examples:

```bash
docker compose logs -f
docker logs wordpress
docker exec wordpress tail -f /var/log/nginx/access.log
docker exec wordpress tail -f /var/log/php-fpm/error.log
```

---

## Troubleshooting

- `apk add php81-* not found`: use matching Alpine/PHP pair via versioned Dockerfile or override `PHP_TAG`/`PHP_VERSION` consistently.
- Healthcheck failing: confirm `/run/php/php-fpm.sock` exists and `nginx -t` passes.
- Permission denied on mounts: ensure host paths are writable by UID/GID 1000 (`app`) or set `user: "1000:1000"` in compose.
- White page: temporarily enable `display_errors` in PHP overrides and inspect PHP-FPM logs.

---

## License

Distributed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

---

<div align="center">
  <p><a href="#overview">Back to top</a></p>
</div>
