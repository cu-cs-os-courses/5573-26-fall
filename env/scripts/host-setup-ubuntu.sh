#!/bin/bash
# One-time host setup for Ubuntu/Debian hosts. Installs QEMU and Docker,
# adds the user to the docker and kvm groups. Needs sudo; safe to re-run.
set -euo pipefail

echo "==> Installing qemu, docker and the build tools the next step needs"
sudo apt-get update
sudo apt-get install -y qemu-system-x86 docker.io make git rsync

echo "==> Adding $USER to the docker group"
sudo usermod -aG docker "$USER"

if [ -e /dev/kvm ]; then
    echo "==> /dev/kvm present; adding $USER to the kvm group"
    sudo usermod -aG kvm "$USER"
else
    echo "==> No /dev/kvm (not x86_64, or virtualization disabled) — QEMU will use TCG (slower, same behavior)"
fi

echo "==> Verifying docker works"
if ! docker info >/dev/null 2>&1; then
    sudo docker info >/dev/null
    cat <<'EOF'
NOTE: group changes take effect on next login. Log out and back in
(or run 'newgrp docker'), then continue with: make images
EOF
else
    echo "==> Host setup complete. Next: make images"
fi
