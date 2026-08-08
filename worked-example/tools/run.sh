#!/bin/bash
# Run the COW worked example end-to-end: boot the reference VM headless,
# execute investigate.sh inside the guest via the autorun channel, then
# assert on the evidence it produced (check.sh).
#
#   worked-example/tools/run.sh   # needs env/ images: make -C ../env images
#
# The work dir (console log + evidence files) is always kept and its path
# printed — the evidence IS the product of this example.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"      # this workspace's root
ENV_DIR="$(cd "$WS/../env" && pwd)"

TIMEOUT="${TIMEOUT:-900}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kl-cow.XXXXXX")"
QEMU_PID=
trap 'kill "$QEMU_PID" 2>/dev/null || true' EXIT

# Everything the guest needs, flattened into the 9p share: the trigger and
# the probe out of this workspace's instrument libraries, plus the guest-side
# orchestration. They land at /share/<name> — the paths investigate.sh uses
# and the report's evidence entries record, so reorganizing the host side
# never rewrites the commands that produced the archived captures.
cp "$WS/triggers/cow-trigger.c" "$WS/probes/probe-do-wp-page.bt" \
   "$WS/tools/investigate.sh" "$WORK/"
cat > "$WORK/autorun.sh" <<'EOF'
#!/bin/bash
/share/investigate.sh
poweroff
EOF
chmod +x "$WORK/autorun.sh" "$WORK/investigate.sh"

echo "==> Booting VM headless (timeout ${TIMEOUT}s; short run even under TCG)"
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

echo "==> VM exited after ~${waited}s. Guest log:"
if [ ! -f "$WORK/autorun.log" ]; then
    echo "ERROR: autorun never ran (9p/autorun failure). Console tail:"
    tail -30 "$WORK/console.log" 2>/dev/null || true
    exit 1
fi
cat "$WORK/autorun.log"
echo
"$WS/tools/check.sh" "$WORK/evidence"
echo "==> Evidence kept at $WORK/evidence"
