#!/bin/bash
# Runs INSIDE the build container. Reads a docker-export tar of the rootfs
# image on stdin, applies the fixups Docker cannot persist, and packs an
# ext4 image with mke2fs -d (no loop mounts, no privileges beyond container
# root). Output: /work/dist/rootfs.ext4.
set -euo pipefail
source /work/env/config.sh

ROOT=/work/cache/rootfs
DIST=/work/dist
mkdir -p "$DIST"

echo "==> Extracting rootfs tar"
rm -rf "$ROOT"
mkdir -p "$ROOT"
tar -C "$ROOT" -xf -

# /etc/hostname, /etc/hosts, /etc/resolv.conf are bind-mounted during
# `docker build` RUN steps, so writes there never reach the image — set
# them here instead. 10.0.2.3 is QEMU user-mode net's DNS proxy.
echo "==> Post-extract fixups"
echo kernel-lens > "$ROOT/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 kernel-lens\n' > "$ROOT/etc/hosts"
echo 'nameserver 10.0.2.3' > "$ROOT/etc/resolv.conf"
rm -f "$ROOT/.dockerenv"

echo "==> Packing ext4 image (${ROOTFS_SIZE_MB}MB)"
rm -f "$DIST/rootfs.ext4"
mke2fs -q -t ext4 -d "$ROOT" -L kernel-lens-root \
    "$DIST/rootfs.ext4" "${ROOTFS_SIZE_MB}M"
chown "${HOST_UID:-0}:${HOST_GID:-0}" "$DIST/rootfs.ext4" || true  # best-effort; see build-kernel.sh
echo "==> Rootfs build complete:"
ls -lh "$DIST/rootfs.ext4"
