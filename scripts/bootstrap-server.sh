#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-myserver.local}"
CERT_BASENAME="${CERT_BASENAME:-$DOMAIN}"
CERT_DAYS="${CERT_DAYS:-3650}"
OPENCLAW_UID="${OPENCLAW_UID:-1000}"
OPENCLAW_GID="${OPENCLAW_GID:-1000}"
FORCE_CERTS="${FORCE_CERTS:-0}"
FORCE_DYNAMIC="${FORCE_DYNAMIC:-0}"
SANDBOX_ROOT="${SANDBOX_ROOT:-/srv/sandbox}"
OPENCLAW_ROOT="/srv/openclaw"
CERT_DIR="/srv/certs"
TRAEFIK_DIR="/srv/traefik"
BACKUP_DIR="/srv/backups"
DYNAMIC_FILE="${TRAEFIK_DIR}/dynamic.yml"
CERT_FILE="${CERT_DIR}/${CERT_BASENAME}.crt"
KEY_FILE="${CERT_DIR}/${CERT_BASENAME}.key"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo), for example:"
  echo "  sudo DOMAIN=${DOMAIN} CERT_BASENAME=${CERT_BASENAME} $0"
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required but not installed."
  exit 1
fi

ONLYOFFICE_ROOT="/srv/onlyoffice"

echo "==> Creating host directories"
mkdir -p \
  "${OPENCLAW_ROOT}" \
  "${SANDBOX_ROOT}" \
  "${CERT_DIR}" \
  "${TRAEFIK_DIR}" \
  "${BACKUP_DIR}" \
  "${ONLYOFFICE_ROOT}/data" \
  "${ONLYOFFICE_ROOT}/logs" \
  "${ONLYOFFICE_ROOT}/lib"

# OpenClaw populates its own subdirectory structure on first boot.
# SANDBOX_ROOT is intentionally left empty for the same reason.

echo "==> Setting ownership for OpenClaw host paths (${OPENCLAW_UID}:${OPENCLAW_GID})"
chown -R "${OPENCLAW_UID}:${OPENCLAW_GID}" "${OPENCLAW_ROOT}"
chown -R "${OPENCLAW_UID}:${OPENCLAW_GID}" "${SANDBOX_ROOT}"

echo "==> Setting ownership for ONLYOFFICE host paths"
chown -R 1000:1000 "${ONLYOFFICE_ROOT}"

if [[ "${FORCE_CERTS}" == "1" || ! -s "${CERT_FILE}" || ! -s "${KEY_FILE}" ]]; then
  echo "==> Generating self-signed certificate: ${CERT_FILE}"
  openssl req -x509 -nodes -days "${CERT_DAYS}" -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -subj "/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN}"
else
  echo "==> Existing certificate found, keeping current files"
fi

chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

if [[ "${FORCE_DYNAMIC}" == "1" || ! -s "${DYNAMIC_FILE}" ]]; then
  echo "==> Writing Traefik dynamic config: ${DYNAMIC_FILE}"
  cat > "${DYNAMIC_FILE}" <<EOF
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/certs/${CERT_BASENAME}.crt
        keyFile: /etc/certs/${CERT_BASENAME}.key
EOF
else
  echo "==> Existing ${DYNAMIC_FILE} found, keeping current file"
fi

chmod 644 "${DYNAMIC_FILE}"

echo
echo "Bootstrap complete."
echo "Domain:              ${DOMAIN}"
echo "Certificate:         ${CERT_FILE}"
echo "Traefik dynamic:     ${DYNAMIC_FILE}"
echo "OpenClaw path:       ${OPENCLAW_ROOT}"
echo "Sandbox path:        ${SANDBOX_ROOT}"
echo "Backup path:         ${BACKUP_DIR}"
echo "ONLYOFFICE path:     ${ONLYOFFICE_ROOT}"
echo
echo "Next step: in Portainer, pull and redeploy the infra stack."
