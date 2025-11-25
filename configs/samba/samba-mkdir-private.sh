#!/bin/sh

u="$1"
base="/srv/private"
dir="$base/$u"
if [ ! -d "$dir" ]; then
  umask 077
  mkdir -p -- "$dir" || exit 1
  chown "$u" "$dir" || exit 1
  chmod 700 "$dir"
fi
exit 0
