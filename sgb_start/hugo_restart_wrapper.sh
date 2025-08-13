#!/bin/bash

# Path to manage_posts.sh
MANAGE_POSTS_SCRIPT="/home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start/manage_posts.sh"

# Log file per il debug
LOG_FILE="/home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start/hugo_restart_debug.log"

# Funzione per assicurarsi che il log sia accessibile
ensure_log_file() {
  if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
  fi
  if [ ! -w "$LOG_FILE" ]; then
    echo "Cannot write to log file at $LOG_FILE. Check permissions." >&2
    exit 1
  fi
}

# Funzione per terminare Hugo
stop_hugo() {
  echo "Stopping Hugo server..." >> "$LOG_FILE"
  local PIDS=$(lsof -t -i:1313)
  if [ -n "$PIDS" ]; then
    echo "Found processes on port 1313: $PIDS. Killing them..." >> "$LOG_FILE"
    kill -9 $PIDS
    if [ $? -eq 0 ]; then
      echo "Processes on port 1313 killed successfully." >> "$LOG_FILE"
    else
      echo "Failed to kill processes on port 1313." >> "$LOG_FILE"
    fi
  else
    echo "No processes found on port 1313." >> "$LOG_FILE"
  fi
}

# Funzione per avviare Hugo
start_hugo() {
  echo "Starting Hugo server..." >> "$LOG_FILE"
  nohup hugo serve -D --bind 0.0.0.0 --port 1313 --baseURL http://localhost:1313 >> "$LOG_FILE" 2>&1 &
  sleep 2  # Attendi che il processo si avvii
  if pgrep -f 'hugo serve' > /dev/null; then
    echo "Hugo server started successfully." >> "$LOG_FILE"
  else
    echo "Failed to start Hugo server." >> "$LOG_FILE"
    exit 1
  fi
}

# Assicurati che il log sia scrivibile
ensure_log_file

# Log iniziale
echo "==== Hugo Restart Wrapper ====" >> "$LOG_FILE"
date >> "$LOG_FILE"

# Esegui il manage_posts.sh
if [ -x "$MANAGE_POSTS_SCRIPT" ]; then
  echo "Executing manage_posts.sh with arguments: $@" >> "$LOG_FILE"
  "$MANAGE_POSTS_SCRIPT" "$@"
else
  echo "Error: manage_posts.sh not found or not executable at $MANAGE_POSTS_SCRIPT" >> "$LOG_FILE"
  exit 1
fi

# Interrompi Hugo
stop_hugo

# Riavvia Hugo
start_hugo

# Log finale
echo "Hugo restart process completed." >> "$LOG_FILE"
