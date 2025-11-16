#!/usr/bin/env bash
set -euo pipefail

SSH_HOST="drf-hugo-vue-prod"
REMOTE_DIR="/opt/drf-hugo-vue"
REMOTE_DB="$REMOTE_DIR/backend/db.sqlite3"

STAMP=$(date '+%Y%m%d_%H%M%S')
LOCAL_BACKUP="backups/db/db_${STAMP}.sqlite3"

echo "🔗 Connessione a $SSH_HOST per backup DB..."
mkdir -p backups/db

# 1) Backup coerente lato server
ssh "$SSH_HOST" bash -lc "
  set -e
  sqlite3 '$REMOTE_DB' \".backup '$REMOTE_DIR/db_backup.sqlite3'\"
"

# 2) Download in locale
scp "$SSH_HOST:$REMOTE_DIR/db_backup.sqlite3" "$LOCAL_BACKUP"

echo "✅ Backup completato: $LOCAL_BACKUP"
