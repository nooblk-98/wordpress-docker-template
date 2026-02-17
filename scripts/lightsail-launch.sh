#!/usr/bin/env bash
set -euo pipefail

# Lightsail Launch Script for WordPress + Caddy
# - Installs Docker, Docker Compose plugin, and dependencies
# - Creates required directories and permissions
# - Writes .env and Caddyfile if missing
# - Starts the stack using docker-compose-caddy.yml


DOMAINS=(www.example.com example.com)
SITE_URL="www.example.com"
EMAIL="admin@example.com"
SITE_TITLE="WordPress on Docker"
ADMIN_USER="admin"
ADMIN_PASS="admin"
DB_NAME="masterdb"
DB_USER="master-user"
DB_PASS="master-password"
DB_ROOT_PASS="rootpassword"
COMPOSE_URL="https://raw.githubusercontent.com/nooblk-98/wordpress-docker-template/refs/heads/main/docker-compose-caddy.yml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAINS+=("$2"); shift 2 ;;
    --email)
      EMAIL="$2"; shift 2 ;;
    --site-title)
      SITE_TITLE="$2"; shift 2 ;;
    --admin-user)
      ADMIN_USER="$2"; shift 2 ;;
    --admin-pass)
      ADMIN_PASS="$2"; shift 2 ;;
    --db-name)
      DB_NAME="$2"; shift 2 ;;
    --db-user)
      DB_USER="$2"; shift 2 ;;
    --db-pass)
      DB_PASS="$2"; shift 2 ;;
    --db-root-pass)
      DB_ROOT_PASS="$2"; shift 2 ;;
    --site-url)
      SITE_URL="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
 done

if [[ ${#DOMAINS[@]} -eq 0 ]]; then
  echo "--domain is required" >&2
  exit 1
fi

if [[ -z "$EMAIL" ]]; then
  echo "--email is required" >&2
  exit 1
fi

# Keep admin email aligned with TLS email
ADMIN_EMAIL="$EMAIL"

if [[ -z "$SITE_URL" ]]; then
  SITE_URL="https://${DOMAINS[0]}"
fi

if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO apt-get update -y
$SUDO apt-get install -y ca-certificates curl gnupg lsb-release ufw

# Configure UFW firewall rules
$SUDO ufw allow 22/tcp
$SUDO ufw allow 80/tcp
$SUDO ufw allow 443/tcp
$SUDO ufw --force enable

if ! command -v docker >/dev/null 2>&1; then
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if ! getent group docker >/dev/null 2>&1; then
  $SUDO groupadd docker
fi

if [[ $EUID -ne 0 ]]; then
  $SUDO usermod -aG docker "$USER"
fi

STACK_ROOT="/opt/www"
CADDY_ROOT="/opt/www/caddy"

$SUDO mkdir -p "$STACK_ROOT/html" "$STACK_ROOT/database" "$CADDY_ROOT"

$SUDO chown -R 33:33 "$STACK_ROOT/html"
$SUDO chmod -R 755 "$STACK_ROOT/html"
$SUDO chown -R 999:999 "$STACK_ROOT/database"
$SUDO chmod -R 700 "$STACK_ROOT/database"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose-caddy.yml"

ENV_FILE="$REPO_ROOT/.env"
CADDY_FILE="$CADDY_ROOT/Caddyfile"

if [[ ! -f "$ENV_FILE" ]]; then
  cat > "$ENV_FILE" <<EOF
WORDPRESS_DB_HOST=db:3306
WORDPRESS_DB_NAME=${DB_NAME}
WORDPRESS_DB_USER=${DB_USER}
WORDPRESS_DB_PASSWORD=${DB_PASS}
WORDPRESS_SITE_TITLE=${SITE_TITLE}
WORDPRESS_AUTO_INSTALL=true
WORDPRESS_ADMIN_USER=${ADMIN_USER}
WORDPRESS_ADMIN_PASSWORD=${ADMIN_PASS}
WORDPRESS_ADMIN_EMAIL=${ADMIN_EMAIL}
WORDPRESS_SITE_URL=${SITE_URL}
MYSQL_ROOT_PASSWORD=${DB_ROOT_PASS}
EOF
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  curl -fsSL "$COMPOSE_URL" -o "$COMPOSE_FILE"
fi

if [[ ! -f "$CADDY_FILE" ]]; then
  CADDY_DOMAINS="${DOMAINS[*]}"
  cat > "$CADDY_FILE" <<EOF
${CADDY_DOMAINS} {
  encode zstd gzip
  reverse_proxy wordpress:80
  tls ${EMAIL}
}
EOF
fi

cd "$REPO_ROOT"
$SUDO docker compose -f "$COMPOSE_FILE" up -d

echo "Done. Visit: ${SITE_URL}"