# Pinned versions and knobs for the reference environment.
# Every script in env/ sources this file. Change versions here only.

KERNEL_VERSION=6.6.87
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"

DEBIAN_SUITE=bookworm
DEBIAN_MIRROR="http://deb.debian.org/debian"

# Packages installed into the guest rootfs (space-separated, apt syntax).
# Binary packages only — no source builds. Everything hands-on in this
# course has to be prebuilt, automated, or self-serve, and a source build
# here would be none of the three.
ROOTFS_PACKAGES="systemd-sysv udev openssh-server bpftrace trace-cmd gcc make libc6-dev python3 procps psmisc strace file less nano kmod iproute2"

ROOTFS_SIZE_MB=4096
GUEST_ROOT_PASSWORD=kernellens

VM_MEM=2G
VM_SMP=2
# Host ports. Overridable from the environment so a second VM can be booted
# without editing this file: SSH_FWD_PORT=2223 ./run.sh. (Two VMs must still
# never share rootfs.ext4 — see env/TROUBLESHOOTING.md.)
SSH_FWD_PORT=${SSH_FWD_PORT:-2222}
GDB_PORT=${GDB_PORT:-1234}

DOCKER_IMAGE=kernel-lens-build
