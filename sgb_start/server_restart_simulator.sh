#!/bin/bash

# File di log
LOG_FILE="./server_restart_simulator.log"

# Funzione per scrivere messaggi di debug con timestamp
log_debug() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Funzione per verificare se una porta è occupata
is_port_in_use() {
    local PORT=$1
    if lsof -i:$PORT > /dev/null 2>&1; then
        return 0  # Porta in uso
    else
        return 1  # Porta libera
    fi
}

# Funzione per simulare un server HTTP con Python
start_server() {
    local PORT=$1
    local NAME=$2

    log_debug "Avvio del server $NAME sulla porta $PORT..."
    nohup python3 -m http.server $PORT > /dev/null 2>&1 &
    sleep 2

    if is_port_in_use $PORT; then
        log_debug "Il server $NAME è avviato correttamente sulla porta $PORT."
    else
        log_debug "Errore: il server $NAME non è stato avviato correttamente sulla porta $PORT."
    fi
}

# Funzione per chiudere un server sulla porta specificata
stop_server() {
    local PORT=$1
    local NAME=$2

    log_debug "Arresto del server $NAME sulla porta $PORT..."
    local PID=$(lsof -t -i:$PORT)
    if [ -n "$PID" ]; then
        kill -9 $PID
        sleep 1
        if ! is_port_in_use $PORT; then
            log_debug "Il server $NAME è stato arrestato con successo."
        else
            log_debug "Errore: il server $NAME non è stato arrestato correttamente."
        fi
    else
        log_debug "Il server $NAME non era in esecuzione."
    fi
}

# Simulazione completa: apertura, chiusura e riapertura
simulate_restart() {
    local PORT=$1
    local NAME=$2

    # Avvia il server
    start_server $PORT $NAME

    # Attendi 5 secondi
    log_debug "Attesa di 5 secondi prima di riavviare il server $NAME..."
    sleep 5

    # Arresta il server
    stop_server $PORT $NAME

    # Attendi 5 secondi
    log_debug "Attesa di 5 secondi prima di riavviare il server $NAME..."
    sleep 5

    # Riavvia il server
    start_server $PORT $NAME
}

# Inizio script
log_debug "==== Inizio Simulazione dei Server ===="

# Simula il server Django sulla porta 8000
simulate_restart 8000 "Django"

# Simula il server Hugo sulla porta 1313
simulate_restart 1313 "Hugo"

log_debug "==== Simulazione Completata ===="
