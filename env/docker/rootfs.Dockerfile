# The guest rootfs IS a Docker image: packages install via apt inside a real
# amd64 container (works under Rosetta), then build-all.sh docker-exports the
# filesystem and packs it into ext4. No debootstrap, no chroot — chroot'd
# execution is broken under Rosetta (it cannot open /proc/self/exe).
#
# Guest config lives as real files in env/guest/ and is COPY'd in: no
# Dockerfile heredocs, which the legacy (non-buildx) builder silently
# mangles into empty files. Build context = env/.
FROM --platform=linux/amd64 debian:bookworm-slim

ARG PACKAGES
ARG ROOT_PASSWORD

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       $PACKAGES \
    && rm -rf /var/lib/apt/lists/*

RUN echo "root:${ROOT_PASSWORD}" | chpasswd

COPY guest/fstab                 /etc/fstab
COPY guest/autologin.conf        /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
COPY guest/kernel-lens-sshd.conf /etc/ssh/sshd_config.d/kernel-lens.conf
COPY guest/kl-autorun            /usr/local/bin/kl-autorun
COPY guest/kl-autorun.service    /etc/systemd/system/kl-autorun.service
COPY guest/20-wired.network      /etc/systemd/network/20-wired.network

RUN chmod +x /usr/local/bin/kl-autorun \
    && mkdir -p /share \
    && ln -sf /etc/systemd/system/kl-autorun.service \
       /etc/systemd/system/multi-user.target.wants/kl-autorun.service \
    && ln -sf /lib/systemd/system/systemd-networkd.service \
       /etc/systemd/system/multi-user.target.wants/systemd-networkd.service
