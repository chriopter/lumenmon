#!/bin/bash
# Generates self-signed certificate for MQTT TLS (20 year validity).
# Creates server certificate and calculates fingerprint for agent registration.
set -euo pipefail

CERT_DIR="/data/mqtt"
FINGERPRINT_FILE="$CERT_DIR/fingerprint"

# Create cert directory
mkdir -p "$CERT_DIR"

# Check if certificate already exists
if [ -f "$CERT_DIR/server.crt" ]; then
    echo "[mqtt-cert] Certificate already exists, skipping generation"
    exit 0
fi

echo "[mqtt-cert] Generating self-signed certificate (20 year validity)..."

# Generate private key
openssl genrsa -out "$CERT_DIR/server.key" 4096 2>/dev/null

# Create config file for Subject Alternative Names
cat > "$CERT_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = lumenmon-mqtt-test
O = Lumenmon
C = US

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = lumenmon-mqtt-test
DNS.2 = lumenmon-console
DNS.3 = localhost
EOF

# Generate self-signed certificate with SANs (20 years = 7300 days)
openssl req -new -x509 \
    -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.crt" \
    -days 7300 \
    -config "$CERT_DIR/openssl.cnf" \
    -extensions v3_req \
    2>/dev/null

# Cleanup config file
rm "$CERT_DIR/openssl.cnf"

# Calculate SHA256 fingerprint
FINGERPRINT=$(openssl x509 -in "$CERT_DIR/server.crt" \
    -noout -fingerprint -sha256 | cut -d= -f2)

# Save fingerprint to file
echo "$FINGERPRINT" > "$FINGERPRINT_FILE"

echo "[mqtt-cert] ✓ Certificate generated successfully"
echo "[mqtt-cert] Fingerprint: $FINGERPRINT"
echo "[mqtt-cert] This fingerprint will be included in agent invite URLs"

# Set permissions
chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"
chmod 644 "$FINGERPRINT_FILE"
