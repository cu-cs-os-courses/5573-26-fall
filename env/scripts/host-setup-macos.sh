#!/bin/bash
# One-time host setup for macOS (Apple Silicon or Intel).
# Installs QEMU and a Docker runtime (colima) via Homebrew, and starts a
# Rosetta-accelerated VM for the amd64 build container.
# Safe to re-run; each step is skipped if already satisfied.
set -euo pipefail

if ! command -v brew >/dev/null; then
    cat <<'EOF'
ERROR: Homebrew is not installed. Install it first (needs your password):

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

then re-run this script.
EOF
    exit 1
fi

echo "==> Installing qemu, colima, docker CLI"
brew list qemu   >/dev/null 2>&1 || brew install qemu
brew list colima >/dev/null 2>&1 || brew install colima
brew list docker >/dev/null 2>&1 || brew install docker

if ! colima status >/dev/null 2>&1; then
    echo "==> Starting colima (vz + Rosetta for fast amd64 containers)"
    if [ "$(uname -m)" = "arm64" ]; then
        colima start --cpu 4 --memory 8 --disk 60 --vm-type vz --vz-rosetta
    else
        colima start --cpu 4 --memory 8 --disk 60
    fi
else
    echo "==> colima already running"
fi

echo "==> Verifying docker works"
docker run --rm --platform linux/amd64 debian:bookworm-slim uname -m

echo "==> Host setup complete. Next: env/scripts/build-all.sh"
