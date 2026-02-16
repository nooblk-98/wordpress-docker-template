ARG BASE_IMAGE=lahiru98s/php-nginx
ARG PHP_TAG=8.1
ARG PHP_VERSION=81
ARG WORDPRESS_VERSION=latest
ARG APP_USER=www-data
ARG APP_GROUP=www-data

FROM ${BASE_IMAGE}:${PHP_TAG}

USER root

ARG PHP_TAG
ARG PHP_VERSION
ARG WORDPRESS_VERSION
ARG APP_USER
ARG APP_GROUP

ENV WORDPRESS_PATH=/var/www/html \
    WORDPRESS_VERSION=${WORDPRESS_VERSION} \
    WP_CLI_BIN=/usr/local/bin/wp \
    PHP_VERSION=${PHP_VERSION} \
    APP_USER=${APP_USER} \
    APP_GROUP=${APP_GROUP}

WORKDIR ${WORDPRESS_PATH}

LABEL Maintainer="nooblk-98" \
      Description="WordPress on top of lahiru98s/php-nginx base image." \
      Version="1.0"

RUN set -eux; \
  curl -fL "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" -o "${WP_CLI_BIN}"; \
  chmod +x "${WP_CLI_BIN}"

RUN set -eux; \
  rm -rf "${WORDPRESS_PATH:?}/"*; \
  "${WP_CLI_BIN}" core download \
    --path="${WORDPRESS_PATH}" \
    --version="${WORDPRESS_VERSION}" \
    --allow-root \
    --force; \
  chown -R "${APP_USER}:${APP_GROUP}" "${WORDPRESS_PATH}"

COPY php/php.ini /etc/php${PHP_VERSION}/conf.d/99-wordpress.ini
COPY php/php-fpm-www.conf /etc/php${PHP_VERSION}/php-fpm.d/www.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d /etc/nginx/conf.d/
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN set -eux; \
  sed -i "s/\r$//" /usr/local/bin/docker-entrypoint.sh; \
  mkdir -p /run/php; \
  if command -v groupadd >/dev/null 2>&1 && ! getent group "${APP_GROUP}" >/dev/null 2>&1; then groupadd --system "${APP_GROUP}"; fi; \
  if command -v useradd >/dev/null 2>&1 && ! id -u "${APP_USER}" >/dev/null 2>&1; then useradd --system --no-create-home --gid "${APP_GROUP}" "${APP_USER}"; fi; \
  if command -v addgroup >/dev/null 2>&1 && ! getent group "${APP_GROUP}" >/dev/null 2>&1; then addgroup -S "${APP_GROUP}"; fi; \
  if command -v adduser >/dev/null 2>&1 && ! id -u "${APP_USER}" >/dev/null 2>&1; then adduser -S -D -H -G "${APP_GROUP}" "${APP_USER}"; fi; \
  chown -R "${APP_USER}:${APP_GROUP}" /run/php "${WORDPRESS_PATH}" || true

USER root

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/fpm-ping || exit 1
