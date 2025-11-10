#!/usr/bin/env bash

SRC_DIR="/srv/media/video/"
FORCE=0

if [[ "$1" == "-f" || "$1" == "--force" ]]; then
  FORCE=1
  echo "Force mode ON - existing thumbnails will be overwritten."
fi

find "$SRC_DIR" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.m4v' \) | while read -r f; do
  dir="$(dirname "$f")"
  base="$(basename "$f")"
  name="${base%.*}"
  thumb="${dir}/${name}.jpg"

  if [[ -f "$thumb" && $FORCE -eq 0 ]]; then
    echo "Thumbnail already exists for: $f (use -f to overwrite)"
    continue
  fi

  echo "Processing: $f"

  ffmpegthumbnailer \
    -i "$f" \
    -o "$thumb" \
    -t 50% \
    -s 0 \
    -q 8
done

