#!/usr/bin/env bash
set -euo pipefail

SSH_USER=${SSH_USER:-demo}
SSH_PORT=${SSH_PORT:-22}
KEY_SOURCE=${KEY_SOURCE:-/opt/keys/id_demo.pub}
DATA_DIR=${DATA_DIR:-/opt/connect}
APPROVED_DIR="${DATA_DIR}/approved"
STREAM_DIR="${DATA_DIR}/streams"

USER_HOME="/home/${SSH_USER}"
AUTHORIZED_KEYS_DIR="${USER_HOME}/.ssh"
AUTHORIZED_KEYS_FILE="${AUTHORIZED_KEYS_DIR}/authorized_keys"

if ! id "${SSH_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${SSH_USER}"
fi

mkdir -p "${AUTHORIZED_KEYS_DIR}"
chmod 700 "${AUTHORIZED_KEYS_DIR}"
install -m 600 "${KEY_SOURCE}" "${AUTHORIZED_KEYS_FILE}"
chown -R "${SSH_USER}:${SSH_USER}" "${AUTHORIZED_KEYS_DIR}"

mkdir -p "${APPROVED_DIR}" "${STREAM_DIR}"
chown -R "${SSH_USER}:${SSH_USER}" "${DATA_DIR}"

sshd_cfg="/etc/ssh/sshd_config"
ensure_line() {
  local line="$1"
  if ! grep -qxF "$line" "${sshd_cfg}"; then
    echo "$line" >> "${sshd_cfg}"
  fi
}

ensure_line "Port ${SSH_PORT}"
ensure_line "PasswordAuthentication no"
ensure_line "PermitRootLogin no"
ensure_line "PubkeyAuthentication yes"
ensure_line "ForceCommand /usr/local/bin/handle_client.sh"
ensure_line "AllowTcpForwarding no"
ensure_line "X11Forwarding no"
ensure_line "PermitTTY yes"

mkdir -p /var/run/sshd
ssh-keygen -A

echo "[SERVER] accepting ${SSH_USER} via ${AUTHORIZED_KEYS_FILE}"

touch "${DATA_DIR}/server.log"

trap 'kill "${SSHD_PID:-0}" "${MONITOR_PID:-0}" 2>/dev/null || true' EXIT

/usr/sbin/sshd -D -e &
SSHD_PID=$!

/usr/local/bin/monitor.sh &
MONITOR_PID=$!

wait "$SSHD_PID"
