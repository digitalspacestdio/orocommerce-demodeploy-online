#!/bin/bash
# Restores a snapshot made by oro-dump into the current database and file volumes,
# rewriting the source URL to ORO_APP_URL. Replaces ALL data. Usage: oro-restore [name]
# When ORO_DUMP_URL is set and the dump is missing locally, the archive is downloaded first
# (a .tar.gz produced by `tar -C /dumps -czf name.tar.gz name`).
source /usr/local/bin/oro-lib

NAME="${1:-${ORO_DUMP_NAME:-demo}}"
SRC="$DUMPS_DIR/$NAME"

if [[ ! -f "$SRC/db.sql.gz" && -n "${ORO_DUMP_URL:-}" ]]; then
  echo "[oro-restore] downloading $ORO_DUMP_URL"
  mkdir -p "$DUMPS_DIR"
  curl -fsSL "$ORO_DUMP_URL" -o "$DUMPS_DIR/$NAME.tar.gz"
  tar -xzf "$DUMPS_DIR/$NAME.tar.gz" -C "$DUMPS_DIR"
  rm -f "$DUMPS_DIR/$NAME.tar.gz"
fi
[[ -f "$SRC/db.sql.gz" ]] || { echo "[oro-restore] no dump at $SRC" >&2; exit 1; }

OLD_URL=$(python3 -c "import json,sys;print(json.load(open('$SRC/meta.json'))['app_url'])" 2>/dev/null \
  || sed -n 's/.*"app_url": *"\([^"]*\)".*/\1/p' "$SRC/meta.json")
echo "[oro-restore] source URL: ${OLD_URL:-unknown} -> $APP_URL"

echo "[oro-restore] resetting database $DB_NAME"
psql_cmd -d "$DB_NAME" -q -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "[oro-restore] importing database"
if [[ -n "$OLD_URL" && "$OLD_URL" != "$APP_URL" ]]; then
  gunzip -c "$SRC/db.sql.gz" | sed "s#${OLD_URL}#${APP_URL}#g" | psql_cmd -d "$DB_NAME" -q
else
  gunzip -c "$SRC/db.sql.gz" | psql_cmd -d "$DB_NAME" -q
fi

echo "[oro-restore] restoring files"
rm -rf public/media/* var/data/*
tar -xzf "$SRC/files.tar.gz" -C .

if [[ -f "$SRC/assets.tar.gz" ]]; then
  echo "[oro-restore] restoring built assets"
  rm -rf public/build/* public/bundles/* public/js/*
  tar -xzf "$SRC/assets.tar.gz" -C .
fi

rm -rf var/cache/*
echo "[oro-restore] database and files restored"
