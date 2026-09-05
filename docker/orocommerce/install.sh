#!/bin/bash
# One-shot initialiser for the demo stack. Idempotent, runs on every `docker compose up`,
# so a deploy of a fresh environment installs OroCommerce with demo data by itself.
#
#  ORO_INSTALL_MODE=auto (default)  restore a dump when one is available, otherwise oro:install
#  ORO_INSTALL_MODE=install         always a fresh oro:install (unless already installed)
#  ORO_INSTALL_MODE=restore         require a dump (ORO_DUMP_NAME in /dumps or ORO_DUMP_URL)
#  ORO_DUMP_NAME=demo               dump directory name under /dumps (docker/orocommerce/dumps on the host)
#  ORO_DUMP_URL=https://...tar.gz   remote dump archive, downloaded into /dumps/$ORO_DUMP_NAME
#  ORO_SAMPLE_DATA=y                install the OroCommerce demo data (default for this repository)
#  ORO_SKIP_COMPOSER=1              vendor is baked into the image (production)
#
# Afterwards (all modes): OAuth keys, public URL, assets, cron definitions, caches.
source /usr/local/bin/oro-lib

MODE="${ORO_INSTALL_MODE:-auto}"
DUMP_NAME="${ORO_DUMP_NAME:-demo}"
STAMP_DIR="var/.docker"
# var/data/oauth must exist before composer runs the post-install scripts: one of them
# generates the OAuth2 server keys at ORO_OAUTH_PRIVATE_KEY_PATH and does not create the folder.
mkdir -p "$STAMP_DIR" var/cache var/logs var/data var/data/oauth var/sessions var/maintenance \
  public/media public/build public/bundles public/js node_modules

lock_hash() { sha256sum composer.lock | cut -c1-16; }

if [[ "${ORO_SKIP_COMPOSER:-0}" == "1" ]]; then
  echo "[oro-install] ORO_SKIP_COMPOSER=1: vendor is baked into the image"
elif [[ ! -f vendor/autoload.php || "$(cat "$STAMP_DIR/composer.lock.sha" 2>/dev/null || true)" != "$(lock_hash)" ]]; then
  echo "[oro-install] composer install (this takes a while on the first run)"
  composer install --no-interaction --no-progress --prefer-dist --no-scripts
  composer run-script set-permissions --no-interaction
  composer run-script install-npm-assets --no-interaction
  composer run-script set-assets-version --no-interaction
  composer run-script execute-post-install-package-scripts --no-interaction
  lock_hash > "$STAMP_DIR/composer.lock.sha"
else
  echo "[oro-install] vendor is up to date"
fi

# Source changes (config, bundles) must reach the container before any console command below.
# Other Oro containers may be writing into the cache concurrently, so a partial removal is fine.
rm -rf var/cache/"${ORO_ENV}"/* 2>/dev/null || true
ensure_oauth_keys

if [[ "$MODE" == "restore" ]]; then
  # Explicit restore replaces the current database and files (used by `make restore`).
  echo "[oro-install] ORO_INSTALL_MODE=restore: importing dump '$DUMP_NAME' (replaces all data)"
  oro-restore "$DUMP_NAME"
elif oro_is_installed; then
  echo "[oro-install] application already installed"
else
  dump_available=0
  if [[ -n "${ORO_DUMP_URL:-}" ]] || oro-dump-exists "$DUMP_NAME"; then dump_available=1; fi

  case "$MODE" in
    install) do_restore=0 ;;
    auto)    do_restore=$dump_available ;;
    *)       echo "[oro-install] unknown ORO_INSTALL_MODE=$MODE" >&2; exit 1 ;;
  esac

  if [[ $do_restore -eq 1 ]]; then
    echo "[oro-install] restoring dump '$DUMP_NAME'"
    oro-restore "$DUMP_NAME"
  else
    echo "[oro-install] running oro:install --env=${ORO_ENV} (demo data: ${ORO_SAMPLE_DATA:-y})"
    bin/console oro:install \
      --env="${ORO_ENV}" --no-interaction --timeout=0 \
      --application-url="$APP_URL" \
      --organization-name="${ORO_ORGANIZATION_NAME:-OroCommerce Demo}" \
      --user-name="${ORO_USER_NAME:-admin}" \
      --user-email="${ORO_USER_EMAIL:-admin@example.com}" \
      --user-firstname="${ORO_USER_FIRSTNAME:-Admin}" \
      --user-lastname="${ORO_USER_LASTNAME:-User}" \
      --user-password="${ORO_USER_PASSWORD:-Admin1234!}" \
      --language="${ORO_LANGUAGE:-en}" \
      --formatting-code="${ORO_FORMATTING_CODE:-en_US}" \
      --sample-data="${ORO_SAMPLE_DATA:-y}"
    echo "[oro-install] fresh installation finished"
  fi
fi

ensure_assets
apply_public_url
console oro:cron:definitions:load || true
warm_caches
echo "[oro-install] done"
