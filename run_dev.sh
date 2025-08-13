#!/usr/bin/env bash
set -euo pipefail

# === Config modificabile ===
BACKEND_DIR="backend"
FRONTEND_DIR="sgb_start"
VENV_DIR="env"
DJANGO_HOST="127.0.0.1"
DJANGO_PORT="${DJANGO_PORT:-8000}"
HUGO_BIND="127.0.0.1"
HUGO_PORT="${HUGO_PORT:-1313}"
HUGO_BASEURL="${HUGO_BASEURL:-http://localhost}"
OPEN_BROWSER="${OPEN_BROWSER:-true}"

# === Utility ===
have() { command -v "$1" >/dev/null 2>&1; }
in_use() { lsof -ti :"$1" >/dev/null 2>&1; }

pick_free_port() {
  local start="$1"
  local p="$start"
  while in_use "$p"; do p=$((p+1)); done
  echo "$p"
}

# === Check prerequisiti ===
if [[ ! -d "$FRONTEND_DIR" ]]; then
  echo "❌ Frontend directory '$FRONTEND_DIR' non trovata"; exit 1
fi
if [[ ! -d "$BACKEND_DIR" ]]; then
  echo "❌ Backend directory '$BACKEND_DIR' non trovata"; exit 1
fi
if ! have hugo; then
  echo "❌ 'hugo' non trovato nel PATH. Installa Hugo Extended."; exit 1
fi
if ! have python3; then
  echo "❌ python3 non trovato"; exit 1
fi

# === Attiva venv se presente ===
if [[ -d "$VENV_DIR" ]]; then
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  echo "✅ venv attivato ($VENV_DIR)"
else
  echo "⚠️  Nessun venv '$VENV_DIR' trovato: proseguo senza."
fi

# === Porte ===
if in_use "$DJANGO_PORT"; then
  echo "⚠️  Porta Django $DJANGO_PORT occupata. Cerco porta libera…"
  DJANGO_PORT="$(pick_free_port "$DJANGO_PORT")"
  echo "➡️  Userò $DJANGO_PORT per Django."
fi
if in_use "$HUGO_PORT"; then
  echo "⚠️  Porta Hugo $HUGO_PORT occupata. Cerco porta libera…"
  HUGO_PORT="$(pick_free_port "$HUGO_PORT")"
  echo "➡️  Userò $HUGO_PORT per Hugo."
fi

# === Trap per uscita pulita ===
PIDS=()
cleanup() {
  echo -e "\n🧹 Stop in corso…"
  for pid in "${PIDS[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  echo "✅ Arresto completato."
}
trap cleanup INT TERM EXIT

# === Avvia Django ===
echo "🚀 Avvio Django su http://${DJANGO_HOST}:${DJANGO_PORT}"
(
  cd "$BACKEND_DIR"
  python3 manage.py runserver "${DJANGO_HOST}:${DJANGO_PORT}"
) &
PIDS+=($!)

# === Avvia Hugo ===
echo "🚀 Avvio Hugo su ${HUGO_BASEURL}:${HUGO_PORT}"
(
  cd "$FRONTEND_DIR"
  # Nota: --baseURL è usato da PaperMod; --bind limita il bind locale.
  hugo server -D --bind "$HUGO_BIND" -p "$HUGO_PORT" --baseURL "$HUGO_BASEURL"
) &
PIDS+=($!)

# === Apertura browser (opzionale) ===
if [[ "$OPEN_BROWSER" == "true" ]]; then
  URL="${HUGO_BASEURL}:${HUGO_PORT}"
  if have xdg-open; then xdg-open "$URL" >/dev/null 2>&1 || true; fi
fi

echo "🟢 Dev up! Hugo: ${HUGO_BASEURL}:${HUGO_PORT} | Django: http://${DJANGO_HOST}:${DJANGO_PORT}"
echo "👉 Ctrl+C per fermare entrambi."
wait
