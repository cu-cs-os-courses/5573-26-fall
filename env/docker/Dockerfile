# Build container for the KernelLens reference environment.
# Always amd64: the course kernel is x86_64, and building natively inside an
# amd64 container (Rosetta-accelerated on Apple Silicon) avoids all
# cross-compilation and foreign-debootstrap complexity.
FROM --platform=linux/amd64 debian:bookworm-slim

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential bc bison flex \
    libssl-dev libelf-dev libncurses-dev \
    dwarves \
    debootstrap e2fsprogs gdb \
    ca-certificates wget xz-utils cpio kmod rsync python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
