#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
RUN_FLUTTER=true
RUN_DOCKER=true

usage() {
  cat <<'USAGE'
Usage: scripts/redeploy_web.sh [options]

Rebuilds the Flutter web bundle and redeploys the docker-compose stack.

Options:
  --skip-flutter   Skip the Flutter clean/build step and only restart Docker
  --flutter-only   Only rebuild the Flutter bundle (no Docker changes)
  -h, --help       Show this help text
USAGE
}

log() {
  printf '[redeploy] %s\n' "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-flutter)
      RUN_FLUTTER=false
      ;;
    --flutter-only)
      RUN_DOCKER=false
      ;;
    --docker-only)
      RUN_FLUTTER=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

remove_container_if_exists() {
  local name="$1"
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$name"; then
    log "Removing stale container: $name"
    docker rm -f "$name" >/dev/null
  fi
}

if $RUN_FLUTTER; then
  log "Cleaning and rebuilding Flutter web bundle"
  pushd "$ROOT_DIR/my_cross_app" >/dev/null
  flutter clean
  flutter pub get
  flutter build web --release
  popd >/dev/null
else
  log "Skipping Flutter build step"
fi

if $RUN_DOCKER; then
  log "Stopping running docker-compose services (if any)"
  pushd "$ROOT_DIR" >/dev/null
  docker-compose down --remove-orphans || true

  remove_container_if_exists "heritage-api"
  remove_container_if_exists "heritage-web"

  log "Rebuilding heritage-api image without cache"
  docker-compose build --no-cache heritage-api

  log "Starting heritage-web (and dependency heritage-api)"
  docker-compose up -d heritage-web
  popd >/dev/null
else
  log "Skipping Docker restart step"
fi

log "Done."
