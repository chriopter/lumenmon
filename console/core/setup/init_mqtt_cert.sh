#!/bin/bash
# Generates self-signed certificate for MQTT TLS (20 year validity).
# Creates server certificate with user-provided hostname and calculates fingerprint for agent registration.
set -euo pipefail

CERT_DIR="/data/mqtt"
FINGERPRINT_FILE="$CERT_DIR/fingerprint"
CONSOLE_HOST="${CONSOLE_HOST:-localhost}"  # Read from environment (set by docker-compose from .env)

# Create cert directory
mkdir -p "$CERT_DIR"

# Check if certificate already exists
if [ -f "$CERT_DIR/server.crt" ]; then
    echo "[mqtt-cert] Certificate already exists, skipping generation"
    exit 0
fi

echo "[mqtt-cert] Generating self-signed certificate (20 year validity)..."
echo "[mqtt-cert] Including hostname: $CONSOLE_HOST"

# Generate private key
openssl genrsa -out "$CERT_DIR/server.key" 4096 2>/dev/null

# Detect if CONSOLE_HOST is an IP address
if [[ "$CONSOLE_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # IP address - add as IP SAN
    IP_SAN="IP.1 = $CONSOLE_HOST
IP.2 = 127.0.0.1"
    DNS_SAN="DNS.1 = lumenmon-console
DNS.2 = localhost"
else
    # Hostname - add as DNS SAN
    DNS_SAN="DNS.1 = lumenmon-console
DNS.2 = localhost
DNS.3 = $CONSOLE_HOST"
    IP_SAN="IP.1 = 127.0.0.1"
fi

# Create config file for Subject Alternative Names
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
echo "[mqtt-cert] CN: $CONSOLE_HOST"
echo "[mqtt-cert] Fingerprint: $FINGERPRINT"
if [[ "$CONSOLE_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[mqtt-cert] SANs: lumenmon-console, localhost, $CONSOLE_HOST (IP)"
else
    echo "[mqtt-cert] SANs: lumenmon-console, localhost, $CONSOLE_HOST (DNS)"
fi
echo "[mqtt-cert] This fingerprint will be included in agent invite URLs"

# Set permissions
chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"
chmod 644 "$FINGERPRINT_FILE"
