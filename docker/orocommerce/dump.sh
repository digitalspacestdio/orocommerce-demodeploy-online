#!/bin/bash
# Creates a portable snapshot of the running Oro instance:
#   /dumps/<name>/db.sql.gz     plain SQL dump (URL is rewritten on restore)
#   /dumps/<name>/files.tar.gz  public/media, var/data (attachments, OAuth keys)
#   /dumps/<name>/assets.tar.gz built public assets (public/build, bundles, js) — skips the asset build on restore
#   /dumps/<name>/meta.json     source URL and versions
# Usage: oro-dump [name]        (default name: demo)
source /usr/local/bin/oro-lib

NAME="${1:-demo}"
TARGET="$DUMPS_DIR/$NAME"
mkdir -p "$TARGET"

echo "[oro-dump] database -> $TARGET/db.sql.gz"
pg_dump_cmd -d "$DB_NAME" --no-owner --no-privileges --format=plain | gzip -1 > "$TARGET/db.sql.gz"

echo "[oro-dump] files -> $TARGET/files.tar.gz"
tar -czf "$TARGET/files.tar.gz" --exclude='var/data/cache' public/media var/data

echo "[oro-dump] assets -> $TARGET/assets.tar.gz"
tar -czf "$TARGET/assets.tar.gz" public/build public/bundles public/js

cat > "$TARGET/meta.json" <<JSON
{
  "app_url": "$APP_URL",
  "oro_env": "$ORO_ENV",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "composer_lock": "$(sha256sum composer.lock | cut -c1-16)"
}
JSON
du -sh "$TARGET"/* | sed 's#^#[oro-dump] #'
echo "[oro-dump] done: $TARGET (pack with: tar -C $DUMPS_DIR -czf $NAME.tar.gz $NAME)"
