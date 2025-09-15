#!/usr/bin/env bash
set -euo pipefail

DATA_DIR=${DATA_DIR:-/opt/connect}
STREAM_DIR="${DATA_DIR}/streams"
LATEST_FILE="${DATA_DIR}/latest"
REFRESH_DELAY=${REFRESH_DELAY:-0.1}

mkdir -p "${STREAM_DIR}"

use_alt=false
if [ -t 1 ] && tput smcup >/dev/null 2>&1; then
  use_alt=true
  tput civis >/dev/null 2>&1 || true
fi

cleanup() {
  if $use_alt; then
    tput rmcup >/dev/null 2>&1 || true
    tput cnorm >/dev/null 2>&1 || true
  else
    printf '\033[H\033[J'
  fi
}

trap cleanup EXIT

while true; do
  if $use_alt; then
    printf '\033[H'
    printf '\033[J'
  else
    printf '\033[H\033[J'
  fi

  if [ -f "$LATEST_FILE" ]; then
    exec 3< "$LATEST_FILE" || true
    read -r client <&3 || client=""
    read -r value <&3 || value=""
    exec 3<&-
    if [ -n "$client" ] && [[ "$value" =~ ^[0-9]+$ ]]; then
      printf 'Latest client: %s\n' "$client"
      printf 'CPU: %s%%\n' "$value"
      filled=$(( value * 50 / 100 ))
      if [ "$filled" -gt 50 ]; then
        filled=50
      fi
      empty=$((50 - filled))
      printf -v bar '%*s' "$filled" ''
      bar=${bar// /#}
      printf -v pad '%*s' "$empty" ''
      pad=${pad// /.}
      printf '[%s%s]\n' "$bar" "$pad"
    else
      echo "Waiting for samples..."
    fi
  else
    echo "Waiting for clients..."
  fi

  sleep "$REFRESH_DELAY"
done
