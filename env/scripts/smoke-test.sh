#!/bin/bash
# Boots the VM headless and verifies the course's observability contract
# from inside the guest, via the 9p autorun channel. No expect scripting,
# no serial parsing: the guest writes results to the shared directory and
# powers off; we assert on the files it left behind.
#
# Checks: boot, BTF present, ftrace works, kprobes fire (bpftrace),
# pagemap readable, in-guest gcc works, 9p share works (implicitly).
set -euo pipefail
ENV_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ENV_DIR/config.sh"

TIMEOUT="${TIMEOUT:-900}"   # TCG on Apple Silicon is slow; be generous.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kl-smoke.XXXXXX")"
# Keep $WORK on failure — the console log and guest results are the only
# evidence for diagnosing a bad boot. Only a fully passing run cleans up.
trap 'kill "$QEMU_PID" 2>/dev/null || true; echo "(artifacts kept at $WORK)"' EXIT

cat > "$WORK/autorun.sh" <<'EOF'
#!/bin/bash
r() { echo "== $1"; shift; "$@" && echo "PASS" || echo "FAIL"; }
exec > /share/result.txt 2>&1

r btf              test -s /sys/kernel/btf/vmlinux
r tracefs          test -f /sys/kernel/tracing/available_tracers
r ftrace-function  grep -qw function /sys/kernel/tracing/available_tracers
r pagemap          dd if=/proc/self/pagemap bs=8 count=1 of=/dev/null status=none
r sched-debug      test -f /proc/schedstat

r gcc sh -c 'echo "int main(){return 42;}" > /tmp/t.c && gcc -o /tmp/t /tmp/t.c; /tmp/t; test $? -eq 42'

# kprobe end-to-end: probe a syscall the trigger itself makes. Absolute
# path: usr-merge puts cat at both /bin and /usr/bin, and bpftrace -c
# refuses an ambiguous PATH lookup.
r bpftrace sh -c 'bpftrace -e "kprobe:do_sys_openat2 { printf(\"hit\\n\"); exit(); }" -c "/bin/cat /etc/hostname" | grep -q hit'

echo "SMOKE-DONE"
poweroff
EOF
chmod +x "$WORK/autorun.sh"

echo "==> Booting VM headless (timeout ${TIMEOUT}s, accel-dependent — TCG is slow)"
SHARE="$WORK" HEADLESS=1 CONSOLE_LOG="$WORK/console.log" "$ENV_DIR/run.sh" &
QEMU_PID=$!

waited=0
while kill -0 "$QEMU_PID" 2>/dev/null; do
    sleep 5; waited=$((waited + 5))
    if [ "$waited" -ge "$TIMEOUT" ]; then
        echo "ERROR: timed out after ${TIMEOUT}s. Console tail:"
        tail -30 "$WORK/console.log" 2>/dev/null || true
        exit 1
    fi
done

echo "==> VM exited after ~${waited}s. Results:"
if [ ! -f "$WORK/result.txt" ]; then
    echo "ERROR: guest never wrote result.txt (autorun/9p failure). Console tail:"
    tail -30 "$WORK/console.log" 2>/dev/null || true
    exit 1
fi
cat "$WORK/result.txt"

fails=$(grep -c '^FAIL' "$WORK/result.txt" || true)
grep -q 'SMOKE-DONE' "$WORK/result.txt" || { echo "ERROR: smoke script did not finish"; exit 1; }
[ "$fails" -eq 0 ] || { echo "ERROR: $fails check(s) failed"; exit 1; }
echo "==> SMOKE TEST PASSED"
trap - EXIT
rm -rf "$WORK"
