# WordPress on lahiru98s/php-nginx

Hardened WordPress images built on top of [`lahiru98s/php-nginx`](https://github.com/nooblk-98/php-nginx-docker-template), published for every supported PHP version (7.4, 8.1, 8.2, 8.3, 8.4). The repository mirrors the folder structure of the base PHP image (`wp74`, `wp81`, `wp82`, `wp83`, `wp84`) so you can build or publish each tag independently.

## What you get

- Pre-baked WordPress core (configurable via `WORDPRESS_VERSION`, defaults to `latest`).
- WP-CLI included and used to generate `wp-config.php` with sensible defaults for WordPress (uploads, cache, cron, debug, salts).
- Re-uses the base image’s Nginx, PHP-FPM, Supervisor, and non-root `app` user hardening.
- Lightweight entrypoint that optionally auto-installs WordPress when DB is reachable.

## Building images

### Generic (all versions from one Dockerfile)

```bash
# PHP 8.4 (default args: PHP_TAG=8.4, PHP_VERSION=84)
docker build -t lahiru98s/wordpress-nginx:8.4 .

# Override PHP version/tag (dotless PHP_VERSION matches Alpine package names)
docker build -t lahiru98s/wordpress-nginx:8.3 \
  --build-arg PHP_TAG=8.3 \
  --build-arg PHP_VERSION=83 .
```

### Version-pinned Dockerfiles (mirrors base repo layout)

```bash
docker build -t lahiru98s/wordpress-nginx:7.4 -f wp74/Dockerfile .
docker build -t lahiru98s/wordpress-nginx:8.1 -f wp81/Dockerfile .
docker build -t lahiru98s/wordpress-nginx:8.2 -f wp82/Dockerfile .
docker build -t lahiru98s/wordpress-nginx:8.3 -f wp83/Dockerfile .
docker build -t lahiru98s/wordpress-nginx:8.4 -f wp84/Dockerfile .
```

`WORDPRESS_VERSION` is also overridable: `--build-arg WORDPRESS_VERSION=6.7.1`.

## Runtime configuration

Entrypoint env vars (all optional):

- `WORDPRESS_DB_HOST` (default `db:3306`)
- `WORDPRESS_DB_NAME` (default `wordpress`)
- `WORDPRESS_DB_USER` / `WORDPRESS_DB_PASSWORD` (default `wordpress`/`wordpress`)
- `WORDPRESS_TABLE_PREFIX` (default `wp_`)
- `WORDPRESS_DEBUG`, `WORDPRESS_CACHE`, `WORDPRESS_FORCE_SSL_ADMIN`, `WORDPRESS_DISABLE_CRON`, `WORDPRESS_ENVIRONMENT_TYPE` (defaults: `false`, `false`, `false`, `false`, `production`)
- `WORDPRESS_AUTO_INSTALL` (`true` to run `wp core install` automatically)
- `WORDPRESS_SITE_URL`, `WORDPRESS_SITE_TITLE`, `WORDPRESS_ADMIN_USER`, `WORDPRESS_ADMIN_PASSWORD`, `WORDPRESS_ADMIN_EMAIL` (used when `WORDPRESS_AUTO_INSTALL=true`)
- `WORDPRESS_PATH` (default `/var/www/html`)

The entrypoint always creates `wp-config.php` if missing and shuffles salts. Automatic install is skipped until the DB responds to `wp db check`.

## Local compose example

```bash
docker compose up -d
open http://localhost:8080
```

`docker-compose.yml` builds the PHP 8.4 image by default, runs MariaDB, persists `/var/www/html/wp-content`, and enables `WORDPRESS_AUTO_INSTALL`.

## Folder map

- `Dockerfile` — default build (PHP 8.4) using `lahiru98s/php-nginx` base.
- `wp74`, `wp81`, `wp82`, `wp83`, `wp84` — version-pinned Dockerfiles.
- `nginx/` — hardened defaults plus WordPress-friendly location rules.
- `php/php.ini` — WordPress-friendly PHP overrides (uploads, URL fopen, input vars).
- `supervisord/` — starts Nginx + PHP-FPM under the non-root `app` user.
- `docker/entrypoint.sh` — generates config, optional auto-install, then starts Supervisor via `tini`.

## Publishing

Tag and push per version:

```bash
docker build -t lahiru98s/wordpress-nginx:8.4 -f wp84/Dockerfile .
docker push lahiru98s/wordpress-nginx:8.4
```

Repeat for `7.4`, `8.1`, `8.2`, `8.3` (or automate in CI).
