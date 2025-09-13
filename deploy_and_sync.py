#!/bin/bash
set -euo pipefail

# === Config ===
REMOTE_HOST="root@157.180.16.0"
REMOTE_DIR="/opt/djungo"
REMOTE_DB="$REMOTE_DIR/db.sqlite3"
LOCAL_DB="./db.sqlite3"
PASSWORD_FILE="./hetzner_password.txt"
COMMIT_MSG=${1:-"🚀 Auto deploy + Hugo build"}

# === Checks ===
if [ ! -f "$PASSWORD_FILE" ]; then
  echo "❌ Password file $PASSWORD_FILE not found. Aborting."
  exit 1
fi
SSH_PASSWORD=$(<"$PASSWORD_FILE")

# === 1) Push codice su GitHub (senza DB) ===
echo ""
echo "📦 [1/6] Committing code (excluding DB) and pushing to GitHub..."
git add .
git reset "$LOCAL_DB" 2>/dev/null || true
git commit -m "$COMMIT_MSG" || echo "ℹ️ Nothing to commit."
git push origin main

# === 2) Pulizia public/ su Hetzner ===
echo ""
echo "🧹 [2/6] Cleaning sgb_start/public on Hetzner..."
sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no $REMOTE_HOST "cd $REMOTE_DIR/sgb_start && rm -rf public || true"

# === 3) Pull/Reset su Hetzner ===
echo ""
echo "🌐 [3/6] Pulling latest code on Hetzner..."
sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no $REMOTE_HOST \
  "cd $REMOTE_DIR && git fetch origin && git reset --hard origin/main"

# === 4) Build Hugo in produzione ===
echo ""
echo "🏗️ [4/6] Building Hugo (production) on Hetzner..."
sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no $REMOTE_HOST "
  set -e
  export ENV_FILE=.env.prod
  set -a; [ -f \"$REMOTE_DIR/\$ENV_FILE\" ] && . \"$REMOTE_DIR/\$ENV_FILE\"; set +a
  cd $REMOTE_DIR/sgb_start
  # Se usi config TOML/YAML non serve altro; baseURL da env:
  hugo --minify --baseURL \"\$HUGO_BASEURL\"
"

# === 5) (Opzionale) Restart servizi (Nginx/Gunicorn) ===
# Scommenta questi se hai i servizi già settati
# echo ""
# echo "🔁 [5/6] Restarting services..."
# sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no $REMOTE_HOST "
#   systemctl restart gunicorn || true
#   systemctl reload nginx || true
# "

# === 6) Backup DB di produzione in locale (NO GIT) ===
echo ""
echo "🧬 [6/6] Downloading production DB to local backups/ (not committed)..."
mkdir -p backups/db
STAMP=$(date '+%Y%m%d_%H%M%S')
LOCAL_BACKUP=\"backups/db/db_${STAMP}.sqlite3\"
sshpass -p \"$SSH_PASSWORD\" scp $REMOTE_HOST:$REMOTE_DB \"$LOCAL_BACKUP\" || echo \"⚠️ DB download skipped/failed.\"

echo ""
echo \"✅ Done. Code deployed, Hugo built on Hetzner, DB backup saved to \$LOCAL_BACKUP.\"
