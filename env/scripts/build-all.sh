#!/bin/bash
# Host-side build entrypoint: builds the container image, then the kernel
# and rootfs inside it. Artifacts land in env/dist/.
# Usage: build-all.sh [kernel|rootfs]   (default: both)
set -euo pipefail
ENV_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(dirname "$ENV_DIR")"
source "$ENV_DIR/config.sh"

command -v docker >/dev/null || { echo "ERROR: docker not found. Run env/scripts/host-setup-macos.sh (or install docker) first."; exit 1; }

echo "==> Building container image ($DOCKER_IMAGE)"
docker build --platform linux/amd64 -t "$DOCKER_IMAGE" "$ENV_DIR/docker"

# The build cache (kernel source tree, debootstrap rootfs) lives in a Docker
# named volume, NOT a host bind mount: macOS filesystems are case-insensitive
# and the kernel tree contains case-colliding files (xt_tcpmss.c vs
# xt_TCPMSS.c), which silently corrupts an extraction onto a bind mount. Only
# final artifacts (no collisions) are written to the host-visible dist/.
# HOST_UID/GID: on native Linux, artifacts written by the (root) container
# would otherwise be root-owned on the host and QEMU couldn't open the
# rootfs read-write. The in-container scripts chown their outputs back.
run_in_container() {
    local script="$1"; shift
    docker run --rm --platform linux/amd64 "$@" \
        -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
        -v "$ENV_DIR:/work/env:ro" \
        -v kernel-lens-cache:/work/cache \
        -v "$ENV_DIR/dist:/work/dist" \
        "$DOCKER_IMAGE" bash "/work/env/scripts/in-container/$script"
}

# The rootfs is built as a Docker image (apt in a real container — chroot is
# broken under Rosetta), then docker-exported and packed into ext4.
build_rootfs() {
    echo "==> Building rootfs image"
    docker build --platform linux/amd64 \
        -f "$ENV_DIR/docker/rootfs.Dockerfile" \
        --build-arg PACKAGES="$ROOTFS_PACKAGES" \
        --build-arg ROOT_PASSWORD="$GUEST_ROOT_PASSWORD" \
        -t kernel-lens-rootfs "$ENV_DIR"
    echo "==> Exporting and packing rootfs"
    local cid
    cid=$(docker create --platform linux/amd64 kernel-lens-rootfs true)
    docker export "$cid" | run_in_container pack-rootfs.sh -i
    docker rm "$cid" >/dev/null
}

mkdir -p "$ENV_DIR/dist"
target="${1:-all}"
case "$target" in
    kernel) run_in_container build-kernel.sh ;;
    rootfs) build_rootfs ;;
    all)    run_in_container build-kernel.sh
            build_rootfs ;;
    *) echo "usage: $0 [kernel|rootfs]"; exit 1 ;;
esac
echo "==> Done. Artifacts in env/dist/. Next: env/run.sh (interactive) or env/scripts/smoke-test.sh"
