#!/usr/bin/env bash
set -euo pipefail

SSH_USER=${SSH_USER:-demo}
SSH_PORT=${SSH_PORT:-22}
KEY_SOURCE=${KEY_SOURCE:-/opt/keys/id_demo.pub}

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

grep -q "^Port ${SSH_PORT}$" /etc/ssh/sshd_config || echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
grep -q "^PasswordAuthentication no$" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
grep -q "^PermitRootLogin no$" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication yes$" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

mkdir -p /var/run/sshd
ssh-keygen -A

echo "[SERVER] accepting ${SSH_USER} via ${AUTHORIZED_KEYS_FILE}" 
exec /usr/sbin/sshd -D -e
