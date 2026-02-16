#!/bin/sh

set -e

WP_PATH="${WORDPRESS_PATH:-/var/www/html}"
WP_CLI_BIN="${WP_CLI_BIN:-/usr/local/bin/wp}"
WP_CONFIG_TEMPLATE_PATH="${WORDPRESS_CONFIG_TEMPLATE_PATH:-/usr/src/wordpress/wp-config-docker.php}"
APP_USER="${APP_USER:-www-data}"
APP_GROUP="${APP_GROUP:-www-data}"

fix_permissions() {
  # When running as root, ensure bind mounts and runtime dirs are writable.
  if [ "$(id -u)" -ne 0 ]; then
    return
  fi

  mkdir -p /run/php "${WP_PATH}/wp-content/uploads"
  chown -R "${APP_USER}:${APP_GROUP}" /run/php "${WP_PATH}" 2>/dev/null || true
  chmod -R g+w "${WP_PATH}/wp-content" 2>/dev/null || true
}

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
  if [ -f "${WP_PATH}/wp-config.php" ] && [ -s "${WP_PATH}/wp-config.php" ]; then
    maybe_sync_legacy_wp_config
    return
  fi

  mkdir -p "${WP_PATH}/wp-content/uploads"

  if [ -f "${WP_CONFIG_TEMPLATE_PATH}" ] && [ -s "${WP_CONFIG_TEMPLATE_PATH}" ]; then
    echo "-> Creating wp-config.php from wp-config-docker.php template"
    cp "${WP_CONFIG_TEMPLATE_PATH}" "${WP_PATH}/wp-config.php"
    chmod 640 "${WP_PATH}/wp-config.php" 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ]; then
      chown "${APP_USER}:${APP_GROUP}" "${WP_PATH}/wp-config.php" 2>/dev/null || true
    fi
    return
  fi

  echo "-> wp-config-docker.php template not found. Falling back to wp-cli config generation"
  "${WP_CLI_BIN}" config create \
    --path="${WP_PATH}" \
    --allow-root \
    --skip-check \
    --force \
    --dbname="${WORDPRESS_DB_NAME:-wordpress}" \
    --dbuser="${WORDPRESS_DB_USER:-wordpress}" \
    --dbpass="${WORDPRESS_DB_PASSWORD:-wordpress}" \
    --dbhost="${WORDPRESS_DB_HOST:-db:3306}" \
    --dbprefix="${WORDPRESS_TABLE_PREFIX:-wp_}"
}

maybe_sync_legacy_wp_config() {
  if [ ! -f "${WP_PATH}/wp-config.php" ]; then
    return
  fi

  # Template-based configs resolve values from env at runtime.
  # Only patch constants when an older static config is detected.
  if grep -q "getenv_docker(" "${WP_PATH}/wp-config.php"; then
    return
  fi

  if [ ! -w "${WP_PATH}/wp-config.php" ]; then
    chmod u+w "${WP_PATH}/wp-config.php" 2>/dev/null || true
  fi

  if [ ! -w "${WP_PATH}/wp-config.php" ]; then
    echo "-> Legacy wp-config.php is not writable; skipping DB constant sync"
    return
  fi

  echo "-> Updating legacy static wp-config.php DB constants from environment"
  "${WP_CLI_BIN}" config set DB_NAME "${WORDPRESS_DB_NAME:-wordpress}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_USER "${WORDPRESS_DB_USER:-wordpress}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD:-wordpress}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_HOST "${WORDPRESS_DB_HOST:-db:3306}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_CHARSET "${WORDPRESS_DB_CHARSET:-utf8mb4}" --type=constant --path="${WP_PATH}" --allow-root
  "${WP_CLI_BIN}" config set DB_COLLATE "${WORDPRESS_DB_COLLATE:-}" --type=constant --path="${WP_PATH}" --allow-root
}

wait_for_db() {
  timeout="${WORDPRESS_DB_WAIT_TIMEOUT:-60}"
  interval="${WORDPRESS_DB_WAIT_INTERVAL:-2}"
  elapsed=0

  while ! "${WP_CLI_BIN}" db check --path="${WP_PATH}" --allow-root >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${timeout}" ]; then
      echo "-> Database not reachable after ${timeout}s, skipping automatic install"
      return 1
    fi

    echo "-> Waiting for database (${elapsed}s/${timeout}s)"
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  return 0
}

maybe_install_wp() {
  if [ "${WORDPRESS_AUTO_INSTALL:-false}" != "true" ]; then
    return
  fi

  if "${WP_CLI_BIN}" core is-installed --path="${WP_PATH}" --allow-root >/dev/null 2>&1; then
    echo "-> WordPress already installed"
    return
  fi

  if ! wait_for_db; then
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
  fix_permissions
  ensure_wp_core
  ensure_wp_config
  maybe_install_wp

  if [ "$#" -eq 0 ]; then
    set -- /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
  fi

  exec /sbin/tini -- "$@"
}

main "$@"
