#!/usr/bin/env bash
set -euo pipefail

DATA_DIR=${DATA_DIR:-/opt/connect}
APPROVED_DIR="${DATA_DIR}/approved"
STREAM_DIR="${DATA_DIR}/streams"
LATEST_FILE="${DATA_DIR}/latest"

mkdir -p "${APPROVED_DIR}" "${STREAM_DIR}"

read -r first_line || exit 1

if [[ ! $first_line =~ ^HELLO\ ([A-Za-z0-9_.-]+)$ ]]; then
  echo "[SERVER] invalid handshake" >&2
  exit 1
fi

CLIENT_ID="${BASH_REMATCH[1]}"
REMOTE_INFO=${SSH_CLIENT:-unknown}

echo "[SERVER] connection from ${CLIENT_ID} (${REMOTE_INFO})" >&2

approved_file="${APPROVED_DIR}/${CLIENT_ID}"
stream_file="${STREAM_DIR}/${CLIENT_ID}.log"

if [ ! -f "$approved_file" ]; then
  {
    echo "client_id=${CLIENT_ID}"
    echo "approved_at=$(date -u +%s)"
  } > "$approved_file"
fi

touch "$stream_file"

echo "APPROVED"

while IFS= read -r line; do
  case "$line" in
    CPU\ *)
      value=${line#CPU }
      if [[ $value =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$value" >> "$stream_file"
        mv "$stream_file" "${stream_file}.tmp"
        tail -n 600 "${stream_file}.tmp" > "$stream_file"
        rm -f "${stream_file}.tmp"
        printf '%s\n%s\n' "$CLIENT_ID" "$value" > "$LATEST_FILE"
      fi
      ;;
    *)
      ;;
  esac
done

echo "[SERVER] stream from ${CLIENT_ID} ended" >&2
