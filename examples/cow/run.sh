#!/bin/bash
# Run the COW worked example end-to-end: boot the reference VM headless,
# execute guest/investigate.sh via the autorun channel, then assert on
# the evidence it produced (check.sh).
#
#   examples/cow/run.sh        # needs env/ images: make -C ../../env images
#
# The work dir (console log + evidence files) is always kept and its path
# printed — the evidence IS the product of this example.
set -euo pipefail
COW_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="$(cd "$COW_DIR/../../env" && pwd)"

TIMEOUT="${TIMEOUT:-900}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kl-cow.XXXXXX")"
QEMU_PID=
trap 'kill "$QEMU_PID" 2>/dev/null || true' EXIT

cp "$COW_DIR"/guest/* "$WORK/"
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
"$COW_DIR/check.sh" "$WORK/evidence"
echo "==> Evidence kept at $WORK/evidence"
