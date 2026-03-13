#!/usr/bin/env bash
# NVIDIA Driver + CUDA Toolkit Installation Script for Debian 12 (Bookworm)
# Supports: Full desktop acceleration + CUDA compute
# Tested on RTX 3070 with driver 535.x and CUDA 12.x
#
# Usage: sudo ./install-nvidia-drivers.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo):"
  echo "  sudo $0"
  exit 1
fi

echo "==> Installing kernel headers and build essentials"
apt-get update
apt-get install -y \
  linux-headers-$(uname -r) \
  build-essential \
  cmake gcc g++ make

echo "==> Enabling non-free repos (if not already enabled)"
if ! grep -q 'non-free' /etc/apt/sources.list 2>/dev/null; then
  sed -i 's/bookworm main/bookworm main contrib non-free non-free-firmware/' /etc/apt/sources.list
  apt-get update
fi

echo "==> Blacklisting Nouveau driver"
cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
update-initramfs -u

echo "==> Installing NVIDIA driver + firmware"
apt-get install -y \
  nvidia-driver \
  firmware-misc-nonfree

echo "==> Installing CUDA toolkit from NVIDIA repo"
# Add NVIDIA's CUDA repo for the full toolkit
curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb \
  -o /tmp/cuda-keyring.deb
dpkg -i /tmp/cuda-keyring.deb
apt-get update
apt-get install -y cuda-toolkit

echo "==> Setting up CUDA environment (system-wide)"
cat > /etc/profile.d/cuda.sh <<'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
chmod +x /etc/profile.d/cuda.sh

echo "==> Setting up GPU tuning systemd service (power limit + persistence mode)"
cat > /etc/systemd/system/gpu-tune.service <<'EOF'
[Unit]
Description=GPU tune (power limit + persistence mode)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pm 1
ExecStart=/usr/bin/nvidia-smi -pl 140
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now gpu-tune.service
echo "  GPU persistence mode and 140W power limit will apply on every boot."
echo "  To change the power limit later: sudo nvidia-smi -pl <watts>"

echo ""
echo "Installation complete."
echo "After reboot, verify with:"
echo "  nvidia-smi"
echo "  nvcc --version"
echo "  systemctl status gpu-tune.service"
echo ""
read -rp "Reboot now? [y/N] " confirm
if [[ "${confirm,,}" == "y" ]]; then
  reboot
else
  echo "Reboot skipped. Run 'sudo reboot' when ready."
fi
