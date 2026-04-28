#!/bin/bash
# Generate the MQTT TLS certificate and fingerprint used by agent invites.
# Reuses an existing certificate when present in the persistent data volume.
set -euo pipefail

CERT_DIR="/data/mqtt"
FINGERPRINT_FILE="$CERT_DIR/fingerprint"
CONSOLE_HOST="${CONSOLE_HOST:-localhost}"

mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/server.crt" ]; then
    echo "[mqtt-cert] Certificate already exists, skipping generation"
    exit 0
fi

echo "[mqtt-cert] Generating self-signed certificate..."
openssl genrsa -out "$CERT_DIR/server.key" 4096 2>/dev/null

if [[ "$CONSOLE_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    DNS_SAN="DNS.1 = lumenmon-console
DNS.2 = localhost"
    IP_SAN="IP.1 = $CONSOLE_HOST
IP.2 = 127.0.0.1"
else
    DNS_SAN="DNS.1 = lumenmon-console
DNS.2 = localhost
DNS.3 = $CONSOLE_HOST"
    IP_SAN="IP.1 = 127.0.0.1"
fi

cat > "$CERT_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $CONSOLE_HOST
O = Lumenmon
C = US

[v3_req]
subjectAltName = @alt_names

[alt_names]
$DNS_SAN
$IP_SAN
EOF

openssl req -new -x509 \
    -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.crt" \
    -days 7300 \
    -config "$CERT_DIR/openssl.cnf" \
    -extensions v3_req \
    2>/dev/null

rm "$CERT_DIR/openssl.cnf"

openssl x509 -in "$CERT_DIR/server.crt" -noout -fingerprint -sha256 | cut -d= -f2 > "$FINGERPRINT_FILE"

chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt" "$FINGERPRINT_FILE"

echo "[mqtt-cert] Fingerprint: $(cat "$FINGERPRINT_FILE")"
