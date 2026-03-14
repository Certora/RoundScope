#!/bin/sh
set -e

IMAGE="ghcr.io/certora/roundscope:latest"
CONF="$1"

if [ -z "$CONF" ]; then
  echo "Usage: $0 <config.json>" >&2
  exit 1
fi

PROJECT_DIR="$(pwd)"

docker run --rm --platform linux/amd64 \
  -v "$PROJECT_DIR":/project \
  "$IMAGE" \
  /project/"$CONF"
