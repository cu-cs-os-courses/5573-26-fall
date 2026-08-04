#!/bin/bash
# Boot the reference VM.
#
#   env/run.sh                 interactive serial console (exit: Ctrl-a x)
#   env/run.sh -g              wait for gdb on :1234 before starting
#                              (host: gdb dist/vmlinux -ex 'target remote :1234')
#   SHARE=/path env/run.sh     mount host dir into guest at /share (9p)
#   HEADLESS=1 env/run.sh      no console on stdio (for scripted runs)
#   KERNEL=/path/bzImage ...   boot an alternate kernel image (same rootfs)
#                              — this is how mutation images are booted
#   SCRATCH=/path/img ...      attach a second disk as /dev/vdb (created
#                              512M empty if missing) — the crash-experiment
#                              disk: mkfs/mount it in the guest, hard-kill
#                              qemu, boot again, observe recovery. Keeps
#                              crash experiments off the shared rootfs.
#   SCRATCH_IOPS=N ...         throttle the scratch disk to N IOPS (QEMU
#                              drive throttling). A slow disk is the only
#                              way to make queueing REAL on a fast host:
#                              without it the device drains instantly and
#                              the I/O scheduler has nothing to decide.
#   SCRATCH_BPS=N ...          throttle the scratch disk to N bytes/s -
#                              writeback floods are MB-scale requests, so
#                              iops throttling barely touches them; bps is
#                              what sustains a backlog.
#   SCRATCH_QSIZE=N ...        shrink the scratch disk's virtio queue to N
#                              entries (default 256). Throttling alone
#                              queues inside QEMU; only a small DEVICE
#                              queue pushes the backlog up into the guest
#                              block layer where the I/O scheduler works.
#
# ssh into the guest:  ssh -p 2222 root@localhost   (password in config.sh)
set -euo pipefail
ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ENV_DIR/config.sh"

BZIMAGE="${KERNEL:-$ENV_DIR/dist/bzImage}"
ROOTFS="$ENV_DIR/dist/rootfs.ext4"
[ -f "$BZIMAGE" ] && [ -f "$ROOTFS" ] || { echo "ERROR: build artifacts missing. Run env/scripts/build-all.sh first."; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "ERROR: qemu-system-x86_64 not found. Run make -C env setup first (host-setup-macos.sh / host-setup-ubuntu.sh)."; exit 1; }

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
    -drive "file=$ROOTFS,if=none,id=root0,format=raw"
    -device "virtio-blk-pci,drive=root0"
    -append "root=/dev/vda rw console=ttyS0 nokaslr"
    -device virtio-rng-pci
    -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_FWD_PORT}-:22"
    -device virtio-net-pci,netdev=n0
    -no-reboot
)

if [ -n "${SCRATCH:-}" ]; then
    [ -f "$SCRATCH" ] || { mkdir -p "$(dirname "$SCRATCH")"; truncate -s 512M "$SCRATCH"; }
    SCRATCH_DRIVE="file=$SCRATCH,if=none,id=scratch0,format=raw"
    [ -n "${SCRATCH_IOPS:-}" ] && SCRATCH_DRIVE+=",throttling.iops-total=$SCRATCH_IOPS"
    [ -n "${SCRATCH_BPS:-}" ] && SCRATCH_DRIVE+=",throttling.bps-total=$SCRATCH_BPS"
    SCRATCH_DEV="virtio-blk-pci,drive=scratch0"
    [ -n "${SCRATCH_QSIZE:-}" ] && SCRATCH_DEV+=",queue-size=$SCRATCH_QSIZE"
    ARGS+=(-drive "$SCRATCH_DRIVE" -device "$SCRATCH_DEV")
fi
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
