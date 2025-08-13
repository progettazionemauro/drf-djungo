#!/bin/bash

# Directory base del progetto
BASE_DIR="/home/mauro/Scrivania/djungo-iso/djungo-iso"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/hugo_flow.log"
HUGO_LOG_FILE="$LOG_DIR/hugo_server.log"
POSTS_DIR="$BASE_DIR/sgb_start/content/contenuti"
PUBLIC_DIR="$BASE_DIR/sgb_start/public/contenuti"

# Funzione per scrivere messaggi nel log con timestamp
log_debug() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Assicurarsi che i file di log siano scrivibili
ensure_log_files() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE" "$HUGO_LOG_FILE"
    if [ ! -w "$LOG_FILE" ] || [ ! -w "$HUGO_LOG_FILE" ]; then
        echo "Errore: non è possibile scrivere nei file di log. Controlla i permessi." >&2
        exit 1
    fi
}

# Funzione per sincronizzare i contenuti
sync_content() {
    log_debug "Sincronizzazione dei contenuti da '$POSTS_DIR' a '$PUBLIC_DIR'..."
    rsync -av --delete "$POSTS_DIR/" "$PUBLIC_DIR/" | tee -a "$LOG_FILE"
    log_debug "Sincronizzazione completata."
}

# Funzione per rigenerare la directory pubblica
regenerate_public() {
    log_debug "Rigenerazione del sito con Hugo..."
    hugo --cleanDestinationDir --destination "$PUBLIC_DIR" >> "$HUGO_LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_debug "Rigenerazione completata con successo."
    else
        log_debug "Errore durante la rigenerazione di Hugo. Controlla il log in $HUGO_LOG_FILE."
    fi
}

# Funzione per fermare il server Hugo
stop_hugo() {
    log_debug "Arresto del server Hugo..."
    pkill -f "hugo serve" && log_debug "Server Hugo arrestato con successo." || log_debug "Hugo non era in esecuzione."
}

# Funzione per avviare il server Hugo
start_hugo() {
    log_debug "Avvio del server Hugo..."
    cd "$BASE_DIR/sgb_start" || { log_debug "Errore: impossibile accedere alla directory $BASE_DIR/sgb_start."; exit 1; }
    nohup hugo serve -D --bind 0.0.0.0 --port 1313 --baseURL http://localhost:1313 \
        --source "$BASE_DIR/sgb_start" --config "$BASE_DIR/sgb_start/hugo.yaml" \
        >> "$HUGO_LOG_FILE" 2>&1 &
    sleep 5
    if lsof -i:1313 > /dev/null; then
        log_debug "Hugo avviato correttamente sulla porta 1313."
    else
        log_debug "Errore durante l'avvio di Hugo. Controlla il log in $HUGO_LOG_FILE."
        exit 1
    fi
}

# Funzione per monitorare il server Hugo
monitor_hugo() {
    log_debug "Monitoraggio del server Hugo. Arresta il server con Ctrl+C."
    tail -f "$HUGO_LOG_FILE"
}

# Funzione principale per gestire il flusso di Hugo
main() {
    ensure_log_files
    log_debug "==== Monitoraggio flusso Hugo ===="

    # Sincronizza i contenuti
    sync_content

    # Rigenera il sito
    regenerate_public

    # Riavvia Hugo
    stop_hugo
    start_hugo

    # Monitora il server Hugo
    monitor_hugo

    log_debug "Flusso Hugo completato."
}

# Esegui la funzione principale
main
