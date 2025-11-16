#!/usr/bin/env bash
set -euo pipefail

#############################################
# DJUNGŌ: run_dev.sh — Versione Definitiva  #
# Porte Fisse, Kill Zombie, Zero Sorprese   #
#############################################

# === Config ===
BACKEND_DIR="backend"
FRONTEND_DIR="sgb_start"
VENV_DIR="env"

DJANGO_HOST="127.0.0.1"
DJANGO_PORT="${DJANGO_PORT:-8000}"

HUGO_BIND="127.0.0.1"
HUGO_PORT="${HUGO_PORT:-1313}"
HUGO_BASEURL="${HUGO_BASEURL:-http://localhost}"

OPEN_BROWSER="${OPEN_BROWSER:-true}"

# === Helpers ===
have() { command -v "$1" >/dev/null 2>&1; }
in_use() { lsof -ti :"$1" >/dev/null 2>&1; }

# === Pre-check ===
[[ -d "$BACKEND_DIR" ]] || { echo "❌ Backend non trovato ($BACKEND_DIR)"; exit 1; }
[[ -d "$FRONTEND_DIR" ]] || { echo "❌ Frontend non trovato ($FRONTEND_DIR)"; exit 1; }

have python3   || { echo "❌ python3 non trovato"; exit 1; }
have hugo      || { echo "❌ hugo non trovato"; exit 1; }

# === Attiva venv ===
if [[ -d "$VENV_DIR" ]]; then
  source "$VENV_DIR/bin/activate"
  echo "✅ venv attivato"
else
  echo "⚠️ Nessun venv trovato"
fi

# === Kill zombie ===
echo "🧹 Killing processi Django/Hugo già attivi..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "hugo server" 2>/dev/null || true

# === Controllo porte FISSO ===
if in_use "$DJANGO_PORT"; then
  echo "❌ Porta Django $DJANGO_PORT ancora occupata."
  echo "   Usa: lsof -i :$DJANGO_PORT"
  exit 1
fi

if in_use "$HUGO_PORT"; then
  echo "❌ Porta Hugo $HUGO_PORT ancora occupata."
  echo "   Usa: lsof -i :$HUGO_PORT"
  exit 1
fi

# === Trap cleanup ===
PIDS=()
cleanup() {
  echo -e "\n🧹 Stop in corso…"
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  echo "✅ Arresto completato."
}
trap cleanup INT TERM EXIT

# === Avvio Django ===
echo "🚀 Avvio Django su http://${DJANGO_HOST}:${DJANGO_PORT}"
(
  cd "$BACKEND_DIR"
  python3 manage.py runserver "${DJANGO_HOST}:${DJANGO_PORT}"
) &
PIDS+=($!)

# === Avvio Hugo ===
echo "🚀 Avvio Hugo su ${HUGO_BASEURL}:${HUGO_PORT}"
(
  cd "$FRONTEND_DIR"
  hugo server -D --bind "$HUGO_BIND" -p "$HUGO_PORT" --baseURL "$HUGO_BASEURL"
) &
PIDS+=($!)

# === Browser locale ===
if [[ "$OPEN_BROWSER" == "true" ]] && have xdg-open; then
  xdg-open "${HUGO_BASEURL}:${HUGO_PORT}" >/dev/null 2>&1 || true
fi

echo "🟢 Dev up! Hugo: ${HUGO_BASEURL}:${HUGO_PORT} | Django: http://${DJANGO_HOST}:${DJANGO_PORT}"
echo "👉 Ctrl+C per fermare entrambi."
wait

