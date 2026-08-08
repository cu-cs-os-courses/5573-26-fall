#!/bin/bash
# repro.sh — <question-id>: <one line: what this re-runs and what it proves>
#
# Copy this next to your report, as reports/batch-NN/<question-id>/repro.sh,
# and replace every TODO. A worked, runnable version of this same skeleton is
# worked-example/reports/vm-cow-01/repro.sh — read that one first.
#
#   ./repro.sh                     re-run, write to a scratch dir, assert
#   REPRO_ARCHIVE=1 ./repro.sh     also refresh the captures you committed
#
# Assumes the VM is already up (tools/vm up).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WS="$(cd "$HERE/../../.." && pwd)"     # reports/batch-NN/<qid>/ -> workspace
VM="$WS/tools/vm"

# Output goes to a scratch dir. Do NOT default this to the directory holding
# the captures your report quotes: re-running to check your work would then
# silently replace the evidence the report cites, and the report would end up
# quoting a run that no longer exists. Refresh the archive deliberately, with
# REPRO_ARCHIVE=1, in the same commit where you re-quote the report.
EV="${REPRO_OUT:-${TMPDIR:-/tmp}/kl-repro-$(basename "$HERE")}"
if [ "${REPRO_ARCHIVE:-0}" = "1" ]; then EV="$HERE/evidence"; fi
mkdir -p "$EV"

fails=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails+1)); }

# --- 1. run -----------------------------------------------------------------
# Push your trigger and probe, run them, pull the RAW output back into $EV.
# Attach probes before the workload runs -- `bpftrace -c PROG` guarantees that
# ordering; starting them separately lets the workload race your probe.
echo "== run: TODO describe the capture =="
# "$VM" push "$WS/triggers/TODO.c" "$WS/probes/TODO.bt" /root/
# "$VM" sh 'TODO: compile and run, writing output to files under /root/'
# "$VM" pull /root/TODO.txt "$EV/TODO.txt"

# --- 2. assert --------------------------------------------------------------
# One pass/fail line per claim in your report. Two rules that decide the mark:
#
#   * Assert, don't print. A script that dumps output and exits 0 proves
#     nothing. If a claim in your report has no line here that fails when the
#     claim stops being true, it is not reproduced.
#   * Assert what is stable, not what your run happened to print. PIDs,
#     addresses, timestamps and PFNs change every boot; compare readings
#     against each other (equal / changed / ordered), or assert a floor you
#     can justify. A hard-coded 0x1323a passes once and fails forever after.
echo "== assert: TODO what must be true =="
# grep -q 'TODO' "$EV/TODO.txt" \
#     && pass "TODO the claim, stated so a reader knows what held" \
#     || fail "TODO what was expected, and what was actually seen"

# --- fail closed ------------------------------------------------------------
# Delete this block once you have written real assertions above. It is here so
# an unfinished repro reports itself instead of exiting 0 and looking passed.
if [ "$fails" -eq 0 ] && grep -q 'TODO' "$0"; then
    echo "FAIL  repro-template.sh still has TODOs and no assertions of its own"
    echo "      (an empty repro that exits 0 is worse than none: it claims a"
    echo "       reproduction nobody performed)"
    exit 2
fi

echo
if [ "$fails" -eq 0 ]; then echo "repro: ALL ASSERTIONS PASSED"; else echo "repro: $fails ASSERTION(S) FAILED"; exit 1; fi
