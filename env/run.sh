#!/bin/bash
# Boot the reference VM.
#
#   env/run.sh                 interactive serial console (exit: Ctrl-a x)
#   env/run.sh -g              wait for gdb on :1234 before starting
#                              (host: gdb dist/vmlinux -ex 'target remote :1234')
#   SHARE=/path env/run.sh     mount host dir into guest at /share (9p)
#   HEADLESS=1 env/run.sh      no console on stdio (for scripted runs)
#
# ssh into the guest:  ssh -p 2222 root@localhost   (password in config.sh)
set -euo pipefail
ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ENV_DIR/config.sh"

BZIMAGE="$ENV_DIR/dist/bzImage"
ROOTFS="$ENV_DIR/dist/rootfs.ext4"
[ -f "$BZIMAGE" ] && [ -f "$ROOTFS" ] || { echo "ERROR: build artifacts missing. Run env/scripts/build-all.sh first."; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "ERROR: qemu-system-x86_64 not found. Run env/scripts/host-setup-macos.sh first."; exit 1; }

# Accel: HVF only helps when the host is x86_64 (arch must match). On
# Apple Silicon this is TCG — slower, but identical kernel behavior, which
# is what the course grades on.
ACCEL=tcg
[ "$(uname -sm)" = "Darwin x86_64" ] && ACCEL=hvf
[ "$(uname -sm)" = "Linux x86_64" ] && [ -w /dev/kvm ] && ACCEL=kvm

ARGS=(
    -machine q35,accel=$ACCEL
    -m "$VM_MEM" -smp "$VM_SMP"
    -kernel "$BZIMAGE"
    -drive "file=$ROOTFS,if=virtio,format=raw"
    -append "root=/dev/vda rw console=ttyS0 nokaslr"
    -device virtio-rng-pci
    -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_FWD_PORT}-:22"
    -device virtio-net-pci,netdev=n0
    -no-reboot
)

if [ -n "${SHARE:-}" ]; then
    ARGS+=(-virtfs "local,path=$SHARE,mount_tag=share,security_model=none")
fi
if [ "${HEADLESS:-0}" = "1" ]; then
    ARGS+=(-display none -serial "file:${CONSOLE_LOG:-/dev/null}")
else
    ARGS+=(-nographic)
fi
if [ "${1:-}" = "-g" ]; then
    ARGS+=(-gdb "tcp::${GDB_PORT}" -S)
    echo "Waiting for gdb: gdb $ENV_DIR/dist/vmlinux -ex 'target remote :${GDB_PORT}'"
fi

exec qemu-system-x86_64 "${ARGS[@]}"
