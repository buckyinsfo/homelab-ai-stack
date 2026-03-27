#!/bin/bash
# Regenerates camp-fai CA + server cert with proper CA:FALSE leaf cert
# macOS Secure Transport rejects certs where CA:TRUE is set on the server cert
# Run this on camp-fai as tim

set -e

CERT_DIR="/srv/certs"
DOMAIN="camp-fai"

echo "==> Backing up existing certs..."
sudo cp "$CERT_DIR/$DOMAIN.crt" "$CERT_DIR/$DOMAIN.crt.bak"
sudo cp "$CERT_DIR/$DOMAIN.key" "$CERT_DIR/$DOMAIN.key.bak"

echo "==> Generating CA key and cert..."
openssl genrsa -out /tmp/ca.key 4096

openssl req -new -x509 -days 3650 \
  -key /tmp/ca.key \
  -out /tmp/ca.crt \
  -subj "/CN=camp-fai-ca" \
  -extensions v3_ca \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

echo "==> Generating server key and CSR..."
openssl genrsa -out /tmp/$DOMAIN.key 4096

openssl req -new \
  -key /tmp/$DOMAIN.key \
  -out /tmp/$DOMAIN.csr \
  -subj "/CN=$DOMAIN"

echo "==> Signing server cert with CA..."
openssl x509 -req -days 3650 \
  -in /tmp/$DOMAIN.csr \
  -CA /tmp/ca.crt \
  -CAkey /tmp/ca.key \
  -CAcreateserial \
  -out /tmp/$DOMAIN.crt \
  -extfile <(printf "basicConstraints=critical,CA:FALSE\nsubjectAltName=DNS:%s,DNS:*.%s\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth" "$DOMAIN" "$DOMAIN")

echo "==> Moving certs into place..."
sudo cp /tmp/ca.crt "$CERT_DIR/ca.crt"
sudo cp /tmp/$DOMAIN.crt "$CERT_DIR/$DOMAIN.crt"
sudo cp /tmp/$DOMAIN.key "$CERT_DIR/$DOMAIN.key"

echo "==> Cleaning up..."
rm /tmp/ca.key /tmp/ca.crt /tmp/$DOMAIN.key /tmp/$DOMAIN.csr /tmp/$DOMAIN.crt

echo "==> Verifying cert chain..."
openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/$DOMAIN.crt"

echo "==> Done. New cert SANs:"
openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -noout -text | grep -A3 "Subject Alternative"

echo ""
echo "Next steps:"
echo "  1. Restart Traefik: docker restart traefik"
echo "  2. Copy ca.crt to camp-lgw: scp tim@camp-fai:/srv/certs/ca.crt ~/camp-fai-ca.crt"
echo "  3. Trust the CA on camp-lgw: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/camp-fai-ca.crt"
