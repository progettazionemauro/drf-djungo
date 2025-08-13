#!/bin/bash

# Log file for debugging
LOG_FILE="/home/mauro/Scrivania/djungo-iso/djungo-iso/manage_posts.log"

# Limit log size to 1 MB
MAX_LOG_SIZE=1048576
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
  > "$LOG_FILE"  # Clear log file
fi

# Directory containing the posts
POSTS_DIR="/home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start/content/contenuti"
PUBLIC_DIR="/home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start/public/contenuti"

# Function to regenerate the public directory
regenerate_public() {
  echo "Regenerating public directory with Hugo..." >> "$LOG_FILE"
  hugo --cleanDestinationDir --destination /home/mauro/Scrivania/djungo-iso/djungo-iso/sgb_start/public >> "$LOG_FILE" 2>&1
  echo "Hugo regeneration complete." >> "$LOG_FILE"
}

# Function to synchronize content and public directories
sync_directories() {
  echo "Synchronizing content and public directories..." >> "$LOG_FILE"
  rsync -av --delete "$POSTS_DIR/" "$PUBLIC_DIR/" >> "$LOG_FILE" 2>&1
  echo "Synchronization complete." >> "$LOG_FILE"
}

# Function to create or update a post
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
    echo "Error: POST_NAME is required." >> "$LOG_FILE"
    exit 1
  fi

  NORMALIZED_POST_NAME=$(echo "$POST_NAME" | tr '[:upper:]' '[:lower:]')
  FILE_NAME="${NORMALIZED_POST_NAME}.md"
  POST_FILE="$POSTS_DIR/$FILE_NAME"

  # Default values
  POST_TITLE=${POST_TITLE:-"Default Title"}
  POST_DATE=${POST_DATE:-$(date +'%Y-%m-%dT%H:%M:%S%z')}
  POST_YEAR=$(date -d "$POST_DATE" +'%Y')  # Extract the year from the date
  POST_TAGS=${POST_TAGS:-""}
  POST_CATEGORIES=${POST_CATEGORIES:-"adventure,food,health,art,entertainment,science,lifestyle"}
  POST_IMAGE=${POST_IMAGE:-"img/default.jpeg"}
  POST_IMAGE_ALT=${POST_IMAGE_ALT:-"Default Alt Text"}
  POST_IMAGE_CAPTION=${POST_IMAGE_CAPTION:-"Default Caption"}

  # Format tags into TOML array
  if [ -n "$POST_TAGS" ]; then
    formatted_tags=$(echo "$POST_TAGS" | sed 's/, */,/g' | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
  else
    formatted_tags="[]"  # Default to an empty TOML array
  fi

  # Add year to categories and format into TOML array
  formatted_categories=$(echo "$POST_CATEGORIES,$POST_YEAR" | sed 's/, */,/g' | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')

  # Format additional images for TOML
  formatted_additional_images=""
  image_counter=1
  if [ -n "$ADDITIONAL_IMAGES" ]; then
    IFS=',' read -ra images_array <<< "$ADDITIONAL_IMAGES"
    for image_data in "${images_array[@]}"; do
      IFS='|' read -r image alt caption <<< "$image_data"
      formatted_additional_images+="[[images]]
    id = \"$image_counter\"
    image = \"$image\"
    alt = \"${alt:-Default Alt Text}\"
    caption = \"${caption:-Default Caption}\"
"
      ((image_counter++))
    done
  fi

  # Generate frontmatter
  cat <<EOF > "$POST_FILE"
+++
title = "$POST_TITLE"
date = "$POST_DATE"
draft = true
ShowToc = true
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
  echo "Post '$FILE_NAME' has been created or updated at $POST_FILE." >> "$LOG_FILE"

  sync_directories
  regenerate_public
}

# Function to delete a post
delete_post() {
  POST_NAME="$1"

  NORMALIZED_POST_NAME=$(echo "$POST_NAME" | tr '[:upper:]' '[:lower:]')
  FILE_NAME="${NORMALIZED_POST_NAME}.md"
  POST_FILE="$POSTS_DIR/$FILE_NAME"

  if [ -f "$POST_FILE" ]; then
    rm "$POST_FILE"
    echo "Post '$POST_FILE' has been deleted." >> "$LOG_FILE"
  else
    echo "Error: Post '$POST_FILE' does not exist." >> "$LOG_FILE"
  fi

  sync_directories
  regenerate_public
}

# Main script logic
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
    echo "Invalid action. Use 'add', 'update', or 'delete'." >> "$LOG_FILE"
    exit 1
    ;;
esac