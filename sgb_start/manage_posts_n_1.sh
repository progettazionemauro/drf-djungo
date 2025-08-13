#!/bin/bash

LOG_FILE="/home/mauro/Scrivania/djungo-iso/djungo-iso/manage_posts.log"
POSTS_DIR="/home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start/content/contenuti"

# Limita la dimensione del file di log a 1 MB
MAX_LOG_SIZE=1048576
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
  > "$LOG_FILE"
fi

# Funzione per rigenerare il sito
regenerate_site() {
  echo "Inizio rigenerazione completa del sito con Hugo..." >> "$LOG_FILE"
  cd /home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start || {
    echo "Errore: impossibile accedere alla directory di Hugo." >> "$LOG_FILE"
    exit 1
  }
  hugo --minify --cleanDestinationDir >> "$LOG_FILE" 2>&1
  if [ $? -eq 0 ]; then
    echo "Rigenerazione completata con successo." >> "$LOG_FILE"
  else
    echo "Errore durante la rigenerazione del sito." >> "$LOG_FILE"
    exit 1
  fi
}

# Funzione per creare o aggiornare un post
create_or_update_post() {
  POST_NAME="$1"
  POST_TITLE="$2"
  POST_DATE="$3"
  POST_TAGS="$4"
  POST_CATEGORIES="$5"
  POST_IMAGE="$6"
  POST_IMAGE_ALT="$7"
  POST_IMAGE_CAPTION="$8"
  ADDITIONAL_IMAGES="$9"

  if [ -z "$POST_NAME" ]; then
    echo "Errore: il nome del post è obbligatorio." >> "$LOG_FILE"
    exit 1
  fi

  FILE_NAME="${POST_NAME}.md"
  POST_FILE="$POSTS_DIR/$FILE_NAME"

  # Format tag e categorie come array TOML
  formatted_tags=$(echo "$POST_TAGS" | sed 's/, */,/g' | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
  formatted_categories=$(echo "$POST_CATEGORIES" | sed 's/, */,/g' | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')

  # Formattazione immagini aggiuntive
  formatted_additional_images=""
  if [ -n "$ADDITIONAL_IMAGES" ]; then
    IFS=',' read -ra images_array <<< "$ADDITIONAL_IMAGES"
    for i in "${!images_array[@]}"; do
      IFS='|' read -r img alt caption <<< "${images_array[$i]}"
      formatted_additional_images+="
[[images]]
    id = \"$(($i+1))\"
    image = \"$img\"
    alt = \"${alt:-Default Alt Text}\"
    caption = \"${caption:-Default Caption}\""
    done
  fi

  cat <<EOF > "$POST_FILE"
+++
title = "$POST_TITLE"
date = "$POST_DATE"
draft = true
tags = $formatted_tags
categories = $formatted_categories
[cover]
    image = "$POST_IMAGE"
    alt = "$POST_IMAGE_ALT"
    caption = "$POST_IMAGE_CAPTION"
$formatted_additional_images
+++
EOF

  chmod 644 "$POST_FILE"
  echo "Post '$FILE_NAME' creato o aggiornato." >> "$LOG_FILE"

  regenerate_site
}

# Funzione per eliminare un post
delete_post() {
  POST_NAME="$1"
  FILE_NAME="${POST_NAME}.md"
  POST_FILE="$POSTS_DIR/$FILE_NAME"

  if [ -f "$POST_FILE" ]; then
    rm "$POST_FILE"
    echo "Post '$POST_FILE' eliminato." >> "$LOG_FILE"
  else
    echo "Errore: Post '$POST_FILE' non trovato." >> "$LOG_FILE"
  fi

  regenerate_site
}

# Logica principale
ACTION="$1"
shift

case "$ACTION" in
  add|update)
    create_or_update_post "$@"
    ;;
  delete)
    delete_post "$1"
    ;;
  *)
    echo "Azione non valida. Usa 'add', 'update' o 'delete'." >> "$LOG_FILE"
    exit 1
    ;;
esac
