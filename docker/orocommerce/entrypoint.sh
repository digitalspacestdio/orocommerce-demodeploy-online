#!/bin/sh
# Starts as root: makes the named volumes writable by the application user (uid 1000 = host
# user in dev), then drops privileges and hands over to the orodc base-image entrypoint
# (xdebug toggle, msmtp config), which finally execs the service command.
set -e
APP_DIR="${APP_DIR:-/var/www}"
RUN_UID="${PHP_UID:-1000}"
RUN_GID="${PHP_GID:-1000}"

if [ "$(id -u)" = "0" ]; then
  # The base image drops the xdebug ini only when running as root; do it here before su-exec.
  if [ "${XDEBUG_MODE:-off}" = "off" ]; then
    rm -f "${PHP_INI_DIR:-/usr/local/etc/php}/conf.d/docker-php-ext-xdebug.ini" \
          "${PHP_INI_DIR:-/usr/local/etc/php}/conf.d/app.xdebug.ini"
  fi
  for d in vendor node_modules var public/build public/bundles public/js public/media /dumps; do
    case "$d" in /*) p="$d" ;; *) p="$APP_DIR/$d" ;; esac
    mkdir -p "$p"
    if [ "$(stat -c %u "$p")" != "$RUN_UID" ]; then
      chown "$RUN_UID:$RUN_GID" "$p"
    fi
  done
  # Files created by `docker compose exec` as root (cache, logs) would block the app user.
  if [ -n "$(find "$APP_DIR/var" -not -uid "$RUN_UID" -print -quit 2>/dev/null)" ]; then
    echo "[oro-entrypoint] fixing ownership of var/ (files not owned by uid $RUN_UID)"
    chown -R "$RUN_UID:$RUN_GID" "$APP_DIR/var"
  fi
  exec su-exec "$RUN_UID:$RUN_GID" docker-entrypoint "$@"
fi

exec docker-entrypoint "$@"
