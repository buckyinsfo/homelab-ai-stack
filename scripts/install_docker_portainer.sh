#!/usr/bin/env bash
# Docker CE + NVIDIA Container Toolkit + Portainer Installation
# For Rocky Linux 10
#
# Usage: sudo ./install_docker_portainer.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo):"
  echo "  sudo $0"
  exit 1
fi

# Preserve the actual logged-in user for group membership
INSTALL_USER="${SUDO_USER:-$USER}"

echo "==> Adding Docker repository"
dnf config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

echo "==> Installing Docker"
dnf install -y \
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

echo "==> Installing NVIDIA Container Toolkit"
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
  | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
dnf install -y nvidia-container-toolkit

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
