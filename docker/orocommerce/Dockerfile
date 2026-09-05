# OroCommerce CE 7.0.4 runtime image for the local demo stack.
#
# Base: the orodc PHP 8.5 + Node 24 + Composer 2 image (all PHP extensions Oro needs,
# php-fpm on 0.0.0.0:9000, ofelia for cron, non-root user `developer` uid 1000).
# The application code is bind-mounted from the repository root; vendor/, node_modules/,
# var/ and generated public assets live in named volumes (see docker/compose/orocommerce.yml).
# `docker/orocommerce/install.sh` runs composer install + oro:install on first start.
ARG BASE_IMAGE=ghcr.io/digitalspacestdio/orodc-php-node-symfony:8.5-node24-composer2-alpine
FROM ${BASE_IMAGE}

ARG APP_DIR=/var/www
ARG PHP_UID=1000
ARG PHP_GID=1000

USER root

RUN apk add --no-cache fcgi su-exec python3 \
  && mkdir -p "${APP_DIR}" /dumps \
  && chown ${PHP_UID}:${PHP_GID} /dumps \
  && chown -R ${PHP_UID}:${PHP_GID} "${APP_DIR}"

COPY --chmod=0755 entrypoint.sh /usr/local/bin/oro-entrypoint
COPY --chmod=0755 lib.sh /usr/local/bin/oro-lib
COPY --chmod=0755 install.sh /usr/local/bin/oro-install
COPY --chmod=0755 dump.sh /usr/local/bin/oro-dump
COPY --chmod=0755 dump-exists.sh /usr/local/bin/oro-dump-exists
COPY --chmod=0755 restore.sh /usr/local/bin/oro-restore
COPY --chmod=0755 healthcheck.sh /usr/local/bin/oro-fpm-healthcheck
COPY php.ini /usr/local/etc/php/conf.d/zz-oro.ini
COPY ofelia.conf /etc/ofelia.conf

ENV APP_DIR=${APP_DIR} \
    XDEBUG_MODE=off \
    COMPOSER_MEMORY_LIMIT=-1 \
    NODE_OPTIONS=--max-old-space-size=4096

WORKDIR ${APP_DIR}
# Stays root; oro-entrypoint drops to uid 1000 after fixing volume ownership.
ENTRYPOINT ["oro-entrypoint"]
