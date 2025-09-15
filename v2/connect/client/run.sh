#!/usr/bin/env bash
set -euo pipefail

SERVER_HOST=${SERVER_HOST:-server}
SERVER_PORT=${SERVER_PORT:-22}
SSH_USER=${SSH_USER:-demo}
KEY_PATH=${KEY_PATH:-/opt/keys/id_demo}
ATTEMPTS=${ATTEMPTS:-20}
SLEEP_SECONDS=${SLEEP_SECONDS:-1}

chmod 600 "${KEY_PATH}"

for attempt in $(seq 1 "${ATTEMPTS}"); do
  echo "[CLIENT] attempt ${attempt} -> ${SSH_USER}@${SERVER_HOST}:${SERVER_PORT}"
  if OUTPUT=$(ssh -i "${KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=2 \
        -p "${SERVER_PORT}" \
        "${SSH_USER}@${SERVER_HOST}" \
        "hostname" 2>/dev/null); then
    echo "[CLIENT] success; server reported hostname: ${OUTPUT}"
    exit 0
  fi
  sleep "${SLEEP_SECONDS}"
done

echo "[CLIENT] failed after ${ATTEMPTS} attempts" >&2
exit 1
