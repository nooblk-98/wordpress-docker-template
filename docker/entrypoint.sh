#!/bin/sh

set -e

WP_PATH="${WORDPRESS_PATH:-/var/www/html}"
WP_CLI_BIN="${WP_CLI_BIN:-/usr/local/bin/wp}"

ensure_wp_core() {
  # Check if WordPress core files exist
  if [ -f "${WP_PATH}/wp-load.php" ]; then
    return
  fi

  echo "-> WordPress core files missing. Downloading..."
  "${WP_CLI_BIN}" core download \
    --path="${WP_PATH}" \
    --version="${WORDPRESS_VERSION:-latest}" \
    --allow-root \
    --force
  
  echo "-> WordPress core files downloaded successfully"
}

ensure_wp_config() {
  if [ -f "${WP_PATH}/wp-config.php" ]; then
    return
  fi

  echo "-> Generating wp-config.php"
  "${WP_CLI_BIN}" config create \
    --path="${WP_PATH}" \
    --allow-root \
    --skip-check \
    --dbname="${WORDPRESS_DB_NAME:-wordpress}" \
    --dbuser="${WORDPRESS_DB_USER:-wordpress}" \
    --dbpass="${WORDPRESS_DB_PASSWORD:-wordpress}" \
    --dbhost="${WORDPRESS_DB_HOST:-db:3306}" \
    --dbprefix="${WORDPRESS_TABLE_PREFIX:-wp_}"

  "${WP_CLI_BIN}" config set WP_DEBUG "${WORDPRESS_DEBUG:-false}" --raw --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set WP_CACHE "${WORDPRESS_CACHE:-false}" --raw --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set WP_ENVIRONMENT_TYPE "${WORDPRESS_ENVIRONMENT_TYPE:-production}" --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set FORCE_SSL_ADMIN "${WORDPRESS_FORCE_SSL_ADMIN:-false}" --raw --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DISABLE_WP_CRON "${WORDPRESS_DISABLE_CRON:-false}" --raw --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set FS_METHOD "direct" --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config shuffle-salts --path="${WP_PATH}" --allow-root

  mkdir -p "${WP_PATH}/wp-content/uploads"
}

sync_db_config() {
  if [ ! -f "${WP_PATH}/wp-config.php" ]; then
    return
  fi

  "${WP_CLI_BIN}" config set DB_NAME "${WORDPRESS_DB_NAME:-wordpress}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_USER "${WORDPRESS_DB_USER:-wordpress}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD:-wordpress}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_HOST "${WORDPRESS_DB_HOST:-db:3306}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_CHARSET "${WORDPRESS_DB_CHARSET:-utf8mb4}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_COLLATE "${WORDPRESS_DB_COLLATE:-}" --type=constant --path="${WP_PATH}" --allow-root
}

maybe_install_wp() {
  if [ "${WORDPRESS_AUTO_INSTALL:-false}" != "true" ]; then
    return
  fi

  if "${WP_CLI_BIN}" core is-installed --path="${WP_PATH}" --allow-root >/dev/null 2>&1; then
    echo "-> WordPress already installed"
    return
  fi

  if ! "${WP_CLI_BIN}" db check --path="${WP_PATH}" --allow-root >/dev/null 2>&1; then
    echo "-> Database not reachable yet, skipping automatic install"
    return
  fi

  echo "-> Installing WordPress"
  "${WP_CLI_BIN}" core install \
    --path="${WP_PATH}" \
    --allow-root \
    --url="${WORDPRESS_SITE_URL:-http://localhost:8080}" \
    --title="${WORDPRESS_SITE_TITLE:-WordPress}" \
    --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
    --admin_password="${WORDPRESS_ADMIN_PASSWORD:-password}" \
    --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
    --skip-email
}

main() {
  ensure_wp_core
  ensure_wp_config
  sync_db_config
  maybe_install_wp

  if [ "$#" -eq 0 ]; then
    set -- /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
  fi

  exec /sbin/tini -- "$@"
}

main "$@"
