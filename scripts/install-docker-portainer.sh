#!/usr/bin/env bash
# Docker CE + NVIDIA Container Toolkit + Portainer Installation
# For Debian 12 (Bookworm)
#
# Usage: sudo ./install-docker-portainer.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo):"
  echo "  sudo $0"
  exit 1
fi

# Preserve the actual logged-in user for group membership
INSTALL_USER="${SUDO_USER:-$USER}"

echo "==> Installing prerequisites"
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg

echo "==> Adding Docker repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "==> Installing Docker"
apt-get update
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

echo "==> Enabling and starting Docker"
systemctl enable --now docker

echo "==> Adding ${INSTALL_USER} to docker group"
usermod -aG docker "${INSTALL_USER}"

echo "==> Verifying Docker installation"
docker version
docker run --rm hello-world

echo "==> Adding NVIDIA Container Toolkit repository"
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

echo "==> Installing NVIDIA Container Toolkit"
apt-get update
apt-get install -y nvidia-container-toolkit

echo "==> Configuring Docker runtime for NVIDIA"
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "==> Verifying GPU passthrough"
docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi

echo "==> Installing Portainer CE"
docker volume create portainer_data
docker run -d \
  --name portainer \
  --restart=unless-stopped \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo ""
echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Log out and back in (or run 'newgrp docker') for docker group to take effect"
echo "  2. Open Portainer at https://$(hostname):9443"
echo "  3. Run bootstrap-server.sh before deploying stacks"
