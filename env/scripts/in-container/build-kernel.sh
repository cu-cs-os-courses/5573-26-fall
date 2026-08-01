#!/bin/bash
# Runs INSIDE the build container. Builds the pinned kernel with the
# KernelLens config fragment. Outputs to /work/dist:
#   bzImage          - bootable kernel
#   vmlinux          - uncompressed ELF with debug info (gdb, drgn, BTF)
#   kernel-config    - the exact config the kernel was built with
set -euo pipefail
source /work/env/config.sh

CACHE=/work/cache
DIST=/work/dist
SRC=$CACHE/linux-$KERNEL_VERSION
mkdir -p "$CACHE" "$DIST"

if [ ! -d "$SRC" ]; then
    echo "==> Downloading linux-$KERNEL_VERSION"
    wget -q --show-progress -O "$CACHE/linux-$KERNEL_VERSION.tar.xz" "$KERNEL_URL"
    echo "==> Extracting"
    tar -C "$CACHE" -xf "$CACHE/linux-$KERNEL_VERSION.tar.xz"
fi

cd "$SRC"
echo "==> Configuring (defconfig + kernel-lens fragment)"
make defconfig
scripts/kconfig/merge_config.sh -m .config /work/env/kernel/kernel-lens.fragment
make olddefconfig

# Fail loudly if a fragment option was silently dropped: the course's
# observability contract depends on every one of these.
echo "==> Verifying fragment options survived"
missing=0
while IFS= read -r line; do
    case "$line" in
        \#*|"") continue ;;
        *=n) want_off=${line%=n}; grep -q "^${want_off}=y" .config && { echo "MISSING: wanted $line, got =y"; missing=1; } ;;
        *=*) grep -qF "$line" .config || { echo "MISSING: $line"; missing=1; } ;;
    esac
done < /work/env/kernel/kernel-lens.fragment
[ "$missing" -eq 0 ] || { echo "ERROR: config fragment not fully applied"; exit 1; }

echo "==> Building (this is the long step)"
make -j"$(nproc)" bzImage

cp arch/x86/boot/bzImage "$DIST/bzImage"
cp vmlinux "$DIST/vmlinux"
cp .config "$DIST/kernel-config"
# Best-effort: needed on native Linux (see build-all.sh), but a no-op or an
# outright EPERM on macOS, where the dist/ mount maps ownership to the host
# user already. Never fail the build this late over it.
chown "${HOST_UID:-0}:${HOST_GID:-0}" "$DIST/bzImage" "$DIST/vmlinux" "$DIST/kernel-config" || true
echo "==> Kernel build complete:"
ls -lh "$DIST/bzImage" "$DIST/vmlinux"
