#!/usr/bin/env bash
# NVIDIA Driver + CUDA Toolkit Installation Script for Rocky Linux 10
# Supports: Full desktop acceleration + CUDA compute
# Tested on RTX 3070 with driver 570.xx and CUDA 12.x
#
# Usage: sudo ./install-nvidia-drivers.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo):"
  echo "  sudo $0"
  exit 1
fi

echo "==> Installing kernel headers and build essentials"
dnf install -y \
  kernel-devel-$(uname -r) \
  kernel-headers-$(uname -r) \
  cmake gcc gcc-c++ make

echo "==> Enabling CRB and EPEL"
dnf config-manager --set-enabled crb
dnf install -y epel-release

echo "==> Adding NVIDIA CUDA repository"
dnf config-manager --add-repo \
  https://developer.download.nvidia.com/compute/cuda/repos/rhel10/x86_64/cuda-rhel10.repo

dnf clean all
dnf makecache

echo "==> Blacklisting Nouveau driver"
cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
dracut --force

echo "==> Installing NVIDIA driver + CUDA toolkit"
dnf install -y \
  nvidia-driver \
  nvidia-driver-cuda \
  kmod-nvidia-open-dkms \
  cuda-toolkit

echo "==> Setting up CUDA environment (system-wide)"
cat > /etc/profile.d/cuda.sh <<'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
chmod +x /etc/profile.d/cuda.sh

echo ""
echo "Installation complete."
echo "After reboot, verify with:"
echo "  nvidia-smi"
echo "  nvcc --version"
echo ""
read -rp "Reboot now? [y/N] " confirm
if [[ "${confirm,,}" == "y" ]]; then
  reboot
else
  echo "Reboot skipped. Run 'sudo reboot' when ready."
fi
