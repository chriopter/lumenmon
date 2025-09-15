#!/usr/bin/env bash
set -euo pipefail

SERVER_HOST=${SERVER_HOST:-server}
SERVER_PORT=${SERVER_PORT:-22}
SSH_USER=${SSH_USER:-demo}
KEY_PATH=${KEY_PATH:-/opt/keys/id_demo}
CLIENT_ID=${CLIENT_ID:-$(hostname)}
ATTEMPTS=${ATTEMPTS:-20}
SLEEP_SECONDS=${SLEEP_SECONDS:-1}
SAMPLE_DELAY=${SAMPLE_DELAY:-0.1}

chmod 600 "${KEY_PATH}"

prev_total=""
prev_idle=""

sample_cpu() {
  local cpu user nice system idle iowait irq softirq steal guest guest_nice
  read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  local idle_all=$((idle + iowait))
  local non_idle=$((user + nice + system + irq + softirq + steal))
  local total=$((idle_all + non_idle))

  if [ -n "${prev_total}" ]; then
    local diff_total=$((total - prev_total))
    local diff_idle=$((idle_all - prev_idle))
    if [ "$diff_total" -gt 0 ]; then
      local usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
      if [ "$usage" -lt 0 ]; then
        usage=0
      elif [ "$usage" -gt 100 ]; then
        usage=100
      fi
      echo "$usage"
    fi
  fi

  prev_total=$total
  prev_idle=$idle_all
}

stream_cpu() {
  echo "HELLO ${CLIENT_ID}"
  while true; do
    local value
    value=$(sample_cpu || true)
    if [ -n "${value}" ]; then
      printf 'CPU %s\n' "$value"
    fi
    sleep "${SAMPLE_DELAY}"
  done
}

for attempt in $(seq 1 "${ATTEMPTS}"); do
  echo "[CLIENT] attempt ${attempt} -> ${SSH_USER}@${SERVER_HOST}:${SERVER_PORT}"
  if stream_cpu | ssh -i "${KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=2 \
        -p "${SERVER_PORT}" \
        "${SSH_USER}@${SERVER_HOST}" "cat"; then
    echo "[CLIENT] stream ended"
    exit 0
  fi
  sleep "${SLEEP_SECONDS}"
done

echo "[CLIENT] failed after ${ATTEMPTS} attempts" >&2
exit 1
