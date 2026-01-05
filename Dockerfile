ARG BASE_IMAGE=lahiru98s/php-nginx
ARG PHP_TAG=8.4
ARG PHP_VERSION=84
ARG WORDPRESS_VERSION=latest
ARG APP_USER=app
ARG APP_GROUP=app

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
    PHP_VERSION=${PHP_VERSION}

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
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d /etc/nginx/conf.d/
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER ${APP_USER}

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1
