#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
SSH_HOST="drf-hugo-vue-prod"                 # alias definito in ~/.ssh/config
REMOTE_DIR="/opt/drf-hugo-vue"               # progetto su Hetzner
REMOTE_DB="$REMOTE_DIR/backend/db.sqlite3"   # DB di produzione su Hetzner
LOCAL_DB="./backend/db.sqlite3"              # DB locale usato da Django

STAMP=$(date '+%Y%m%d_%H%M%S')
LOCAL_BACKUP="backups/db/db_${STAMP}.sqlite3"

echo "🔗 Connessione a $SSH_HOST per backup DB..."
mkdir -p backups/db

# === 1) Backup coerente lato server ===
ssh "$SSH_HOST" "
  set -e
  if command -v sqlite3 >/dev/null 2>&1; then
    echo '🧬 Uso sqlite3 .backup lato server...'
    sqlite3 '$REMOTE_DB' \".backup '$REMOTE_DIR/db_backup.sqlite3'\"
  else
    echo '⚠️ sqlite3 non trovato, uso cp (best-effort backup)...' >&2
    cp '$REMOTE_DB' '$REMOTE_DIR/db_backup.sqlite3'
  fi
"

# === 2) Download del backup in locale ===
echo "⬇️ Download del backup in $LOCAL_BACKUP ..."
scp \"$SSH_HOST:$REMOTE_DIR/db_backup.sqlite3\" \"$LOCAL_BACKUP\"

echo
echo \"✅ Backup completato: $LOCAL_BACKUP\"
echo

# === 3) Chiedo se vuoi usarlo anche come DB locale ===
read -rp \"Vuoi sovrascrivere ANCHE il DB locale ($LOCAL_DB) con questo backup? (yes/no) \" ANSWER

if [[ \"\$ANSWER\" == \"yes\" ]]; then
  cp \"$LOCAL_BACKUP\" \"$LOCAL_DB\"
  echo \"✅ DB locale aggiornato da $LOCAL_BACKUP\"
else
  echo \"ℹ️ DB locale lasciato invariato. Puoi usare il backup quando vuoi con:\"
  echo \"   cp $LOCAL_BACKUP $LOCAL_DB\"
fi
