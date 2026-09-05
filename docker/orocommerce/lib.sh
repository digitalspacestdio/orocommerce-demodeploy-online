#!/bin/bash
# Shared helpers for the Oro container scripts (install, dump, restore).
set -euo pipefail

cd "${APP_DIR:-/var/www}"

ORO_ENV="${ORO_ENV:-prod}"
DUMPS_DIR="${ORO_DUMPS_DIR:-/dumps}"
APP_URL="${ORO_APP_URL:-http://localhost:8080}"
KEYS_DIR="var/data/oauth"

# Connection settings from ORO_DB_URL (postgres://user:pass@host:port/db?...)
db_parse() {
  local url="${ORO_DB_URL:?ORO_DB_URL is required}"
  url="${url#*://}"
  local creds="${url%%@*}" rest="${url#*@}"
  DB_USER="${creds%%:*}"; DB_PASS="${creds#*:}"
  DB_HOST="${rest%%:*}"; rest="${rest#*:}"
  DB_PORT="${rest%%/*}"; rest="${rest#*/}"
  DB_NAME="${rest%%\?*}"
  export PGPASSWORD="$DB_PASS"
}

db_parse

psql_cmd() { /usr/bin/psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$@"; }
pg_dump_cmd() { /usr/bin/pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$@"; }

# True when the Oro schema exists and the installer marked the application as installed.
oro_is_installed() {
  local installed
  installed=$(psql_cmd -d "$DB_NAME" -tAc \
    "select coalesce((select text_value from oro_config_value where name='is_installed' and section='oro_distribution' limit 1), '')" 2>/dev/null || true)
  [[ -n "$installed" && "$installed" != "0" && "$installed" != "false" ]]
}

console() { bin/console "$@" --env="$ORO_ENV" --no-interaction; }

# Symfony parameters resolve %kernel.project_dir%; the scripts need the real path.
ensure_oauth_keys() {
  mkdir -p "$KEYS_DIR"
  if [[ ! -f "$KEYS_DIR/oauth_private.key" || ! -f "$KEYS_DIR/oauth_public.key" ]]; then
    echo "[oro] generating OAuth2 server keys in $KEYS_DIR"
    console oro:oauth-server:generate-keys
  fi
  chmod 600 "$KEYS_DIR/oauth_private.key" 2>/dev/null || true
}

# Point Oro at the public URL of this environment (Oro redirects when the host differs).
apply_public_url() {
  echo "[oro] application URL: $APP_URL"
  console oro:config:update oro_ui.application_url "$APP_URL"
  console oro:config:update oro_website.url "$APP_URL"
  console oro:config:update oro_website.secure_url "$APP_URL"
}

ensure_assets() {
  if [[ ! -d public/build/default ]]; then
    echo "[oro] public assets missing: building (several minutes)"
    console oro:assets:install
    console oro:assets:build
  fi
}

warm_caches() {
  console cache:clear --no-warmup
  console cache:warmup
}
