#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-camp-fai}"
CERT_BASENAME="${CERT_BASENAME:-$DOMAIN}"
CERT_DAYS="${CERT_DAYS:-3650}"
OPENCLAW_UID="${OPENCLAW_UID:-1000}"
OPENCLAW_GID="${OPENCLAW_GID:-1000}"
WORKSPACE_SUBDIR="${WORKSPACE_SUBDIR:-development}"
OPENCLAW_SKILLS="${OPENCLAW_SKILLS:-}"
FORCE_CERTS="${FORCE_CERTS:-0}"
FORCE_DYNAMIC="${FORCE_DYNAMIC:-0}"

OPENCLAW_ROOT="/srv/openclaw"
CERT_DIR="/srv/certs"
TRAEFIK_DIR="/srv/traefik"
BACKUP_DIR="/srv/backups/volumes"
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

echo "==> Creating host directories"
mkdir -p \
  "${OPENCLAW_ROOT}/config" \
  "${OPENCLAW_ROOT}/workspace" \
  "${OPENCLAW_ROOT}/workspace/${WORKSPACE_SUBDIR}" \
  "${OPENCLAW_ROOT}/.skillet" \
  "${CERT_DIR}" \
  "${TRAEFIK_DIR}" \
  "${BACKUP_DIR}"

echo "==> Setting ownership for OpenClaw host paths (${OPENCLAW_UID}:${OPENCLAW_GID})"
chown -R "${OPENCLAW_UID}:${OPENCLAW_GID}" "${OPENCLAW_ROOT}"

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

if [[ -n "${OPENCLAW_SKILLS// }" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to preinstall OpenClaw skills (OPENCLAW_SKILLS)."
    exit 1
  fi

  echo "==> Preinstalling OpenClaw skills into ${OPENCLAW_ROOT}/.skillet"
  echo "    Skills: ${OPENCLAW_SKILLS}"

  echo "${OPENCLAW_SKILLS}" | tr "," "\n" | while IFS= read -r skill; do
    skill="$(echo "${skill}" | xargs)"
    [ -n "${skill}" ] || continue

    # Allow optional github: prefix in skill entries.
    skill="${skill#github:}"

    if [[ "${skill}" != */* ]]; then
      echo "Skipping '${skill}': expected GitHub owner/repo format."
      continue
    fi

    target_dir="${OPENCLAW_ROOT}/.skillet/${skill}"
    repo_url="https://github.com/${skill}.git"

    if [[ -d "${target_dir}" ]]; then
      echo "${skill} already installed"
      continue
    fi

    echo "Installing ${skill}"
    mkdir -p "$(dirname "${target_dir}")"
    git clone --depth 1 "${repo_url}" "${target_dir}"
  done

  chown -R "${OPENCLAW_UID}:${OPENCLAW_GID}" "${OPENCLAW_ROOT}/.skillet"
fi

echo
echo "Bootstrap complete."
echo "Domain: ${DOMAIN}"
echo "Certificate: ${CERT_FILE}"
echo "Traefik dynamic config: ${DYNAMIC_FILE}"
echo "Workspace code path: ${OPENCLAW_ROOT}/workspace/${WORKSPACE_SUBDIR}"
echo
echo "Next step: in Portainer, pull and redeploy the infra stack."
