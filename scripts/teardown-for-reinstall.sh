#!/usr/bin/env bash
# Teardown script — resets camp-fai to post-NVIDIA, pre-Docker/Portainer state.
# Safe to run on a Debian 12 host where Docker may or may not be installed.
#
# What this removes:
#   - All running containers, images, volumes, networks
#   - Docker CE packages + daemon
#   - NVIDIA Container Toolkit packages
#   - /var/lib/docker, /var/lib/containerd, /var/lib/grafana  (container runtime data)
#   - /var/lib/containers, /var/lib/cni  (Podman/CNI leftovers from prior Rocky Linux setup)
#   - /etc/docker  (daemon.json config dir)
#   - /home/docker-data  (ollama models and other bind-mount data)
#   - /srv  (Portainer GitOps stacks, certs, openclaw config, traefik)
#   - /data/compose  (Portainer artifact dirs)
#   - /opt/stacks, /opt/containerd, /opt/backups  (deployment artifacts)
#   - Legacy home directory artifacts
#
# What this KEEPS:
#   - NVIDIA driver (nvidia-smi should still work after reboot)
#   - ~/openclaw-config-backup.json  (your secrets backup)
#   - ~/.ssh  (your SSH keys)
#   - All other home directory dotfiles and config
#
# Usage: sudo ./teardown-for-reinstall.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

# Resolve the actual user's home dir (not root's)
ACTUAL_USER="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "${ACTUAL_USER}" | cut -d: -f6)"

echo
echo "============================================="
echo " Homelab AI Stack — Pre-reinstall teardown"
echo "============================================="
echo " Server user : ${ACTUAL_USER}"
echo " Home dir    : ${HOME_DIR}"
echo
read -rp "This will DELETE Docker, all container data, /srv, and legacy home artifacts. Continue? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# ── 1) Stop and remove all containers ─────────────────────────────────────────
if command -v docker &>/dev/null; then
  echo
  echo "==> Stopping all running containers"
  docker ps -aq | xargs -r docker stop || true

  echo "==> Removing all containers"
  docker ps -aq | xargs -r docker rm -f || true

  echo "==> Removing all images"
  docker images -q | xargs -r docker rmi -f || true

  echo "==> Removing all volumes"
  docker volume ls -q | xargs -r docker volume rm || true

  echo "==> Removing all non-default networks"
  docker network ls --filter type=custom -q | xargs -r docker network rm || true
else
  echo "==> Docker not found, skipping container cleanup"
fi

# ── 2) Stop Docker daemon ──────────────────────────────────────────────────────
echo
echo "==> Stopping Docker service"
systemctl stop docker.socket docker.service containerd || true
systemctl disable docker.socket docker.service containerd || true

# ── 3) Remove Docker + NVIDIA Container Toolkit packages ──────────────────────
echo
echo "==> Removing Docker CE + NVIDIA toolkit packages"
PACKAGES_TO_REMOVE=(
  docker-ce docker-ce-cli containerd.io
  docker-compose-plugin docker-buildx-plugin
  docker-ce-rootless-extras
  nvidia-container-toolkit
  libnvidia-container-tools
  libnvidia-container1
)

INSTALLED_PACKAGES=()
for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
  if dpkg -s "${pkg}" &>/dev/null; then
    INSTALLED_PACKAGES+=("${pkg}")
  fi
done

if [[ "${#INSTALLED_PACKAGES[@]}" -gt 0 ]]; then
  apt-get purge -y "${INSTALLED_PACKAGES[@]}" || true
else
  echo "==> No Docker/NVIDIA toolkit packages currently installed"
fi

echo "==> Running apt autoremove/clean"
apt-get autoremove -y --purge || true
apt-get clean

echo "==> Removing repo files"
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
rm -f /etc/apt/keyrings/docker.asc
rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# ── 4) Remove Docker data directories ─────────────────────────────────────────
echo
echo "==> Removing /var/lib/docker"
rm -rf /var/lib/docker

echo "==> Removing /var/lib/containerd"
rm -rf /var/lib/containerd

echo "==> Removing /var/lib/grafana"
rm -rf /var/lib/grafana

echo "==> Removing /var/lib/containers (Podman leftovers)"
rm -rf /var/lib/containers

echo "==> Removing /var/lib/cni (CNI network leftovers)"
rm -rf /var/lib/cni

echo "==> Removing /etc/docker (daemon.json config dir)"
rm -rf /etc/docker

echo "==> Removing /run/docker*"
rm -rf /run/docker /run/docker.sock

# ── 5) Remove docker-data on /home ────────────────────────────────────────────
echo
echo "==> Removing /home/docker-data (ollama models, postgres data, etc.)"
rm -rf /home/docker-data

# Also clean up old path from before migration
echo "==> Removing legacy /home/ollama-data if present"
rm -rf /home/ollama-data

# ── 6) Remove /srv (certs, traefik config, openclaw config, Portainer stacks) ─
echo
echo "==> Removing /srv"
rm -rf /srv

# ── 7) Remove /opt deployment artifacts ──────────────────────────────────────
echo
echo "==> Removing /opt deployment artifacts"
rm -rf /opt/stacks
rm -rf /opt/containerd
rm -rf /opt/backups
# Note: /opt/nvidia is intentionally preserved (NVIDIA driver)

# ── 8) Remove Portainer GitOps artifact dirs ──────────────────────────────────
echo
echo "==> Removing /data/compose (Portainer GitOps artifacts)"
rm -rf /data/compose

# ── 9) Remove user from docker group (group may be gone already) ──────────────
if getent group docker &>/dev/null; then
  gpasswd -d "${ACTUAL_USER}" docker 2>/dev/null || true
  groupdel docker 2>/dev/null || true
fi

# ── 10) Clean up legacy home directory artifacts ───────────────────────────────
echo
echo "==> Cleaning up legacy home directory artifacts"

# Old repo clone (renamed to homelab-ai-stack on GitHub)
rm -rf "${HOME_DIR}/AI_server_cachehive"

# Old ai/ and data/ dirs from earlier experiments
rm -rf "${HOME_DIR}/ai"
rm -rf "${HOME_DIR}/data"

# Old install scripts (superseded by scripts/ in the repo)
rm -f "${HOME_DIR}/install-docker-portaner.sh"   # note: typo in original filename
rm -f "${HOME_DIR}/install-nvidia-drivers.sh"

# Old Rigel miner artifacts
rm -rf "${HOME_DIR}/rigel-1.23.0-linux"
rm -f  "${HOME_DIR}/rigel-backup.tar.gz"

# Docker client config dir
rm -rf "${HOME_DIR}/.docker"

# ── 11) Verify NVIDIA driver still intact ─────────────────────────────────────
echo
echo "==> Verifying NVIDIA driver is still intact"
if nvidia-smi &>/dev/null; then
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
  echo "    ✅ nvidia-smi OK"
else
  echo "    ⚠️  nvidia-smi not responding — driver may need attention after reboot"
fi

echo
echo "============================================="
echo " Teardown complete."
echo "============================================="
echo
echo " Preserved:"
echo "   ${HOME_DIR}/openclaw-config-backup.json  (secrets backup)"
echo "   ${HOME_DIR}/.ssh  (SSH keys)"
echo "   NVIDIA driver"
echo
echo " Next steps:"
echo "   1. sudo reboot  (recommended to clear kernel modules)"
echo "   2. Verify: nvidia-smi"
echo "   3. Clone the repo:"
echo "      git clone https://github.com/buckyinsfo/homelab-ai-stack.git ~/homelab-ai-stack"
echo "   4. Run: sudo ~/homelab-ai-stack/scripts/install-docker-portainer.sh"
echo "   5. Run: sudo DOMAIN=<domain> ~/homelab-ai-stack/scripts/bootstrap-server.sh"
echo "   6. Deploy stacks in Portainer"
echo
