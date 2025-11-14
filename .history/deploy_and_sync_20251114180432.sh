#!/usr/bin/env bash
set -euo pipefail
# -e  = esci se un comando fallisce
# -u  = errore se usi variabili non definite
# pipefail = se una pipe fallisce, fallisce tutto lo script

# === Config ===
SSH_HOST="drf-hugo-vue-prod"                    # alias SSH definito in ~/.ssh/config
SSH_BASE_OPTS='-o RemoteCommand=none -o RequestTTY=no'
REMOTE_DIR="/opt/drf-hugo-vue"                  # directory progetto su Hetzner
REMOTE_DB="$REMOTE_DIR/backend/db.sqlite3"      # DB di produzione
LOCAL_DB="./backend/db.sqlite3"                 # DB locale (da NON committare)
ENV_FILE=".env.prod"                            # file env usato in produzione

COMMIT_MSG="${1:-"🚀 Deploy drf_hugo_vue"}"     # messaggio di commit, opzionale da CLI
LOCKFILE="/tmp/deploy_and_sync.lock"

STAMP=$(date '+%Y%m%d_%H%M%S')
LOCAL_BACKUP="backups/db/db_${STAMP}.sqlite3"

# === 0) Evita doppio deploy in parallelo ===
exec 9>"$LOCKFILE"
flock -n 9 || { echo "⛔ Deploy già in esecuzione."; exit 0; }

# === 1) Controllo branch ===
echo
echo "🔍 [1/6] Verifico che tu sia su 'main'..."
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "❌ Sei su '$CURRENT_BRANCH', non su 'main'. Interrompo."
  exit 1
fi

# === 2) Commit + push locale → GitHub ===
echo
echo "📦 [2/6] Commit & push (tri-sincro: locale → GitHub)..."

git status

# Aggiunge TUTTE le modifiche (aggiunte, modifiche, cancellazioni)
git add -A

# Rimuove il DB dall'index (così NON viene committato)
git reset "$LOCAL_DB" 2>/dev/null || true

# Se hai altri file da non committare e non sono già nel .gitignore, potresti aggiungerli qui:
# git reset .env 2>/dev/null || true
# git reset .env.dev 2>/dev/null || true

git commit -m "$COMMIT_MSG" || echo "ℹ️ Nessun nuovo commit (working tree pulita)."

git push origin main

# === 3) Allinea Hetzner a origin/main (GitHub → Hetzner) ===
echo
echo "🌐 [3/6] Aggiorno codice su Hetzner da origin/main..."

ssh $SSH_BASE_OPTS "$SSH_HOST" bash -lc "
  set -e
  cd '$REMOTE_DIR'
  git fetch --all --prune
  git reset --hard origin/main
"

# === 4) Pulizia build Hugo precedente ===
echo
echo "🧹 [4/6] Pulizia sgb_start/public su Hetzner..."

ssh $SSH_BASE_OPTS "$SSH_HOST" bash -lc "
  cd '$REMOTE_DIR/sgb_start' && rm -rf public || true
"

# === 5) Build Hugo in produzione ===
echo
echo "🏗️ [5/6] Build Hugo (prod) su Hetzner..."

ssh $SSH_BASE_OPTS "$SSH_HOST" bash -lc "
  set -e
  cd '$REMOTE_DIR'
  set -a
  [ -f '$ENV_FILE' ] && . '$ENV_FILE'
  set +a
  cd sgb_start
  hugo --minify --baseURL \"\${HUGO_BASEURL:?HUGO_BASEURL mancante in $ENV_FILE}\"
"

# === 6) Backup DB produzione → locale (NO GIT) ===
echo
echo "🧬 [6/6] Backup DB produzione in $LOCAL_BACKUP ..."

mkdir -p backups/db

ssh $SSH_BASE_OPTS "$SSH_HOST" bash -lc "
  sqlite3 '$REMOTE_DB' \".backup '$REMOTE_DIR/db_backup.sqlite3'\" >/dev/null 2>&1 || true
"

scp -o RemoteCommand=none -o RequestTTY=no "$SSH_HOST:$REMOTE_DIR/db_backup.sqlite3" "$LOCAL_BACKUP" \
  || echo '⚠️ DB download skipped/failed.'

echo
echo "✅ TRI-SYNC COMPLETATA."
echo "   1) Locale → GitHub (commit + push)"
echo "   2) GitHub → Hetzner (reset su origin/main)"
echo "   3) Hugo build + backup DB → $LOCAL_BACKUP"
