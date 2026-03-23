#!/usr/bin/env bash
# Node.js Installation via fnm (Fast Node Manager)
# For Debian 12 (Bookworm) — installs to the current user's home directory
#
# Run as the user who will be doing development (NOT root / sudo).
# fnm is user-scoped — no system-level changes are made.
#
# Usage: bash ./install-node.sh
#
# After running, either open a new shell or run:
#   source ~/.bashrc

set -euo pipefail

NODE_VERSION="${NODE_VERSION:-22}"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Do not run as root. Run as the dev user (e.g. tim):"
  echo "  bash $0"
  exit 1
fi

echo "==> Checking dependencies"
MISSING=()
for cmd in curl unzip; do
  command -v "${cmd}" >/dev/null 2>&1 || MISSING+=("${cmd}")
done

if [[ "${#MISSING[@]}" -gt 0 ]]; then
  echo "==> Installing missing dependencies: ${MISSING[*]}"
  sudo apt-get install -y "${MISSING[@]}"
fi

echo "==> Installing fnm (Fast Node Manager)"
curl -fsSL https://fnm.vercel.app/install | bash

# Source fnm into the current shell so we can use it immediately
export FNM_PATH="${HOME}/.local/share/fnm"
export PATH="${FNM_PATH}:${PATH}"
eval "$(fnm env)"

echo "==> Installing Node.js ${NODE_VERSION}"
fnm install "${NODE_VERSION}"
fnm default "${NODE_VERSION}"
fnm use "${NODE_VERSION}"

echo ""
echo "Installation complete."
echo ""
echo "Node: $(node --version)"
echo "npm:  $(npm --version)"
echo ""
echo "To use node in your current shell, run:"
echo "  source ~/.bashrc"
echo ""
echo "To install dependencies in a project:"
echo "  cd ~/development/<project>/client && npm install"
echo "  cd ~/development/<project>/server && npm install"
