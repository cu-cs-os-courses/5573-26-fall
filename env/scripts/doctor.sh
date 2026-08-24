#!/bin/bash
# doctor.sh — fast self-diagnosis of the course environment (make doctor).
# Checks the host, the toolchain, and the built artifacts in a few seconds
# and points every failure at the matching TROUBLESHOOTING.md section.
# It does NOT boot the VM — after everything here is green, `make smoke`
# is the real acceptance test.
set -uo pipefail
ENV_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ENV_DIR/config.sh"
TS="env/TROUBLESHOOTING.md"

fails=0; warns=0
ok()   { printf 'ok    %s\n' "$1"; }
warn() { printf 'WARN  %s\n      -> %s\n' "$1" "$2"; warns=$((warns+1)); }
bad()  { printf 'FAIL  %s\n      -> %s\n' "$1" "$2"; fails=$((fails+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

echo "== host"
OS="$(uname -s)"
case "$OS" in
    Darwin) ok "macOS ($(uname -m))" ;;
    Linux)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            bad "this is WSL" "Windows incl. WSL is unsupported ($TS: Unsupported hosts); email the instructor now"
        else
            ok "Linux ($(uname -m))"
        fi ;;
    *) bad "unsupported OS: $OS" "macOS and Linux only ($TS: Unsupported hosts)" ;;
esac

free_kb=$(df -k "$ENV_DIR" | awk 'NR==2 {print $4}')
free_gb=$((free_kb / 1024 / 1024))
if [ "$free_gb" -lt 8 ]; then
    bad "only ${free_gb} GB free on this disk" "the environment needs ~20 GB total ($TS: Disk space)"
elif [ "$free_gb" -lt 15 ]; then
    warn "${free_gb} GB free on this disk" "fine if images are already built; a full rebuild wants ~20 GB ($TS: Disk space)"
else
    ok "${free_gb} GB free disk"
fi

echo "== toolchain"
if have qemu-system-x86_64; then
    ok "qemu-system-x86_64 ($(qemu-system-x86_64 --version | head -1 | awk '{print $4}'))"
else
    bad "qemu-system-x86_64 not found" "run 'make setup' ($TS: Host setup)"
fi

if [ "$OS" = Darwin ]; then
    have brew   || bad "Homebrew not found" "install it, then 'make setup' ($TS: Host setup, macOS)"
    have docker || bad "docker CLI not found" "run 'make setup' ($TS: Host setup, macOS)"
    if have colima; then
        if colima status >/dev/null 2>&1; then
            ok "colima running"
        else
            bad "colima not running (it does not survive reboots)" "colima start   ($TS: Docker daemon unreachable)"
        fi
    else
        bad "colima not found" "run 'make setup' ($TS: Host setup, macOS)"
    fi
else
    have docker || bad "docker not found" "run 'make setup' ($TS: Host setup, Linux)"
    if [ -e /dev/kvm ]; then
        if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
            ok "/dev/kvm accessible (hardware acceleration)"
        else
            warn "/dev/kvm exists but you lack access" "re-login after 'make setup' added you to the kvm group ($TS: Groups and re-login)"
        fi
    else
        warn "no /dev/kvm" "the VM falls back to emulation — works, slower ($TS: Performance)"
    fi
fi

if have docker && docker info >/dev/null 2>&1; then
    ok "docker daemon reachable"
    if docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
        ok "build image '$DOCKER_IMAGE' present"
    else
        [ -f "$ENV_DIR/dist/bzImage" ] \
            && warn "build image '$DOCKER_IMAGE' missing" "only needed to rebuild — 'make images' recreates it" \
            || bad "build image '$DOCKER_IMAGE' missing" "run 'make images' ($TS: Building images)"
    fi
    if docker volume inspect kernel-lens-cache >/dev/null 2>&1; then
        ok "source cache volume present"
    else
        [ -f "$ENV_DIR/dist/bzImage" ] \
            && warn "source cache volume missing" "tools/ksrc and kernel rebuilds need it — 'make images' recreates it" \
            || bad "source cache volume missing" "run 'make images' ($TS: Building images)"
    fi
elif have docker; then
    bad "docker daemon unreachable" "$([ "$OS" = Darwin ] && echo 'colima start' || echo 'sudo systemctl start docker; re-login if newly added to the docker group')   ($TS: Docker daemon unreachable)"
fi

echo "== built artifacts (env/dist/)"
for f in bzImage vmlinux rootfs.ext4; do
    if [ -f "$ENV_DIR/dist/$f" ]; then
        ok "dist/$f"
    else
        bad "dist/$f missing" "run 'make images' ($TS: Building images)"
    fi
done
if [ -f "$ENV_DIR/dist/bzImage" ] && have file; then
    ver="$(file -b "$ENV_DIR/dist/bzImage" 2>/dev/null)"
    case "$ver" in
        *"$KERNEL_VERSION"*) ok "kernel image is $KERNEL_VERSION" ;;
        *) warn "bzImage does not look like $KERNEL_VERSION" "rebuild with 'make kernel' if versions drifted ($TS: Building images)" ;;
    esac
fi

echo "== runtime"
vm_pids="$(pgrep -f "qemu-system-x86_64.*$ENV_DIR" 2>/dev/null)"
if [ -n "$vm_pids" ]; then
    # Name the workspace that started it. A `tools/vm up` VM logs the guest
    # console to <workspace>/.vm/console.log, so its own qemu cmdline says who
    # owns it -- and only that workspace's `tools/vm down` can stop it (down
    # reads <workspace>/.vm/qemu.pid). A console VM (env/run.sh) is -nographic,
    # has no such argument, and belongs to a terminal rather than a workspace.
    vm_ws=""
    for p in $vm_pids; do
        cmd="$(ps -o command= -p "$p" 2>/dev/null)"
        vm_ws="$(printf '%s' "$cmd" | sed -n 's|.*-serial file:\(.*\)/\.vm/console\.log.*|\1|p')"
        [ -n "$vm_ws" ] && { vm_pid="$p"; break; }
    done
    if [ -n "$vm_ws" ]; then
        warn "a course VM is already running (workspace: $vm_ws, pid $vm_pid)" \
             "fine if intentional; two VMs cannot share the rootfs — stop it with '$vm_ws/tools/vm down' (only that workspace can; $TS: VM already running)"
    else
        warn "a course VM is already running (console VM, pid $(echo $vm_pids))" \
             "fine if intentional; two VMs cannot share the rootfs — no workspace owns it, so exit it with Ctrl-a x in its terminal ($TS: VM already running)"
    fi
else
    ok "no VM currently running"
fi
if have lsof && lsof -nP -iTCP:"$SSH_FWD_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    if [ -n "$vm_pids" ]; then
        ok "port $SSH_FWD_PORT held by the running VM"
    else
        bad "port $SSH_FWD_PORT is taken by something else" "find it: lsof -nP -iTCP:$SSH_FWD_PORT   ($TS: Port 2222 in use)"
    fi
else
    ok "ssh forward port $SSH_FWD_PORT free"
fi

echo
if [ "$fails" -gt 0 ]; then
    echo "doctor: $fails problem(s), $warns warning(s) — fixes above, details in $TS"
    exit 1
elif [ "$warns" -gt 0 ]; then
    echo "doctor: healthy with $warns warning(s). Final check: make smoke"
else
    echo "doctor: all green. Final check: make smoke"
fi
