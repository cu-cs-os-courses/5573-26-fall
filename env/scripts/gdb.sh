#!/bin/bash
# Kernel debugging without host gdb: runs gdb inside the (amd64) build
# container, attached to the VM's gdbstub. Neither macOS nor a bare Linux
# host needs gdb installed — the container has it, and its architecture
# matches the x86_64 target so there are no cross-debugging quirks.
#
# Usage:
#   terminal 1:  ./run.sh -g          # VM waits, frozen, on :GDB_PORT
#   terminal 2:  scripts/gdb.sh       # connects; extra args pass to gdb
#   e.g.         scripts/gdb.sh -ex 'break do_sys_openat2' -ex continue
set -euo pipefail
ENV_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ENV_DIR/config.sh"

# host.docker.internal is built in on macOS (colima/Docker Desktop); the
# add-host flag provides it on native-Linux docker engines too.
# Allocate a TTY only when we have one — batch/scripted use (gdb -batch,
# repro scripts) runs without a terminal and docker -t would fail.
TTY_FLAGS=(-i); [ -t 0 ] && TTY_FLAGS=(-it)
exec docker run --rm "${TTY_FLAGS[@]}" \
    --add-host host.docker.internal:host-gateway \
    -v "$ENV_DIR/dist:/dist:ro" \
    "$DOCKER_IMAGE" \
    gdb /dist/vmlinux \
        -ex "target remote host.docker.internal:${GDB_PORT}" \
        "$@"
