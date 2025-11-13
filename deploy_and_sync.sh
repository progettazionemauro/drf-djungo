#!/usr/bin/env bash
set -euo pipefail
# -e  -> esci se un comando fallisce
# -u  -> errore se usi variabili non definite
# pipefail -> se fallisce una parte di una pipe, fallisce tutta la pipe

# === Config ===
SSH_HOST="drf-hugo-vue-prod"             # alias ssh (~/.ssh/config) -> 157.180.16.0 con chiave id_hetzener
REMOTE_DIR="/opt/drf-hugo-vue"           # cartella progetto in produzione
REMOTE_DB="$REMOTE_DIR/backend/db.sqlite3"  # DB del backend nuovo
LOCAL_DB="./backend/db.sqlite3"          # DB locale (da NON committare)
ENV_FILE=".env.prod"                     # file env in REMOTE_DIR
COMMIT_MSG=${1:-"🚀 Auto deploy + Hugo build"}  # usa argomento 1 se passato, altrimenti default

LOCKFILE="/tmp/deploy_and_sync.lock"

# === Lock per evitare esecuzioni sovrapposte ===
exec 9>"$LOCKFILE"
flock -n 9 || { echo "⛔ Deploy già in esecuzione."; exit 0; }
# flock -n -> prende un lock non bloccante sul file; se il lock è occupato, esce

# === Pre-check: branch ===
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "❌ Sei su '$CURRENT_BRANCH', non su 'main'. Interrompo."
  exit 1
fi

# === 1) Commit & push (escludi DB) ===
echo -e "\n📦 [1/6] Commit & push su GitHub..."
git add -A
# add -A = aggiunge/rimuove qualunque file tracciato/non tracciato (rispetto a .gitignore)
git reset "$LOCAL_DB" 2>/dev/null || true
# git reset <file> = toglie quel file dall'index per evitare di includerlo nel commit
git commit -m "$COMMIT_MSG" || echo "ℹ️ Niente da committare."
git push origin main
# push origin main = invia i commit al remoto 'origin', branch 'main'

# === 2) Aggiorna codice su Hetzner ===
echo -e "\n🌐 [2/6] Aggiorno codice su Hetzner..."
ssh "$SSH_HOST" bash -lc "
  set -e
  cd '$REMOTE_DIR'
  git fetch --all --prune
  # fetch --all --prune = scarica aggiornamenti da tutti i remoti e pulisce i branch remoti eliminati
  git reset --hard origin/main
  # reset --hard origin/main = forza la working copy ad allinearsi esattamente al remoto
"

# === 3) Pulizia sgb_start/public su Hetzner ===
echo -e "\n🧹 [3/6] Pulizia sgb_start/public su Hetzner..."
ssh "$SSH_HOST" bash -lc "
  cd '$REMOTE_DIR/sgb_start' && rm -rf public || true
  # rm -rf = rimozione ricorsiva e forzata (non chiede conferme)
"

# === 4) Build Hugo ===
echo -e "\n🏗️ [4/6] Build Hugo (prod) su Hetzner..."
ssh "$SSH_HOST" bash -lc "
  set -e
  cd '$REMOTE_DIR'
  set -a; [ -f '$ENV_FILE' ] && . '$ENV_FILE'; set +a
  # set -a = esporta automaticamente le variabili definite successivamente (utile per . env)
  # . '$ENV_FILE' = 'source': carica variabili d'ambiente dal file ENV_FILE se esiste
  cd sgb_start
  hugo --minify --baseURL \"\${HUGO_BASEURL:?HUGO_BASEURL mancante in $ENV_FILE}\"
  # --minify = minimizza l'output
  # --baseURL = URL base del sito; qui fallisce se HUGO_BASEURL non è definita
"

# === 5) (Opzionale) Restart servizi (abilita se hai systemd pronto) ===
# echo -e "\n🔁 [5/6] Restart servizi..."
# ssh "$SSH_HOST" bash -lc "systemctl restart gunicorn || true; systemctl reload nginx || true"
# systemctl restart = riavvia il servizio; reload = ricarica la config senza fermare il processo

# === 6) Backup DB coerente (SQLite .backup) in locale (NO GIT) ===
echo -e "\n🧬 [6/6] Backup DB produzione in ./backups/db ..."
mkdir -p backups/db
# -p = crea la directory e non dà errore se già esiste
STAMP=$(date '+%Y%m%d_%H%M%S')
LOCAL_BACKUP="backups/db/db_${STAMP}.sqlite3"
ssh "$SSH_HOST" bash -lc "
  sqlite3 '$REMOTE_DB' \".backup '$REMOTE_DIR/db_backup.sqlite3'\" >/dev/null 2>&1 || true
  # sqlite3 '.backup' = crea un backup consistente anche a DB 'caldo'
"
scp "$SSH_HOST:$REMOTE_DIR/db_backup.sqlite3" "$LOCAL_BACKUP" || echo '⚠️ DB download skipped/failed.'
# scp <origine> <destinazione> = copia sicura via SSH

echo -e "\n✅ Fatto. Deploy + build Hugo eseguiti. DB salvato in: $LOCAL_BACKUP"

