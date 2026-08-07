#!/bin/bash
# repro.sh — vm-cow-01: re-run the copy-on-write investigation and assert on
# the evidence, in one shot.
#
# THIS FILE IS A MODEL. It is the third of the three things you hand in every
# week, and the one with no other example in the course material:
#
#     reports/batch-NN/<question-id>/
#     ├── report.md      <- ../answer/vm-cow-01.md is the model
#     ├── repro.sh       <- THIS FILE is the model
#     └── evidence/      <- ../evidence/ is the model (raw captures, any names)
#
# The shape to copy, in order:
#   1. locate the VM tool and pick an output directory
#   2. push trigger + probe into the guest, run them, pull the raw output
#   3. assert, one `pass`/`fail` line per expectation, from the pulled files
#   4. exit non-zero if any assertion failed
#
#   ./repro.sh                     re-run, write to a scratch dir, assert
#   REPRO_ARCHIVE=1 ./repro.sh     also refresh the committed captures
#
# Note what the default does NOT do: overwrite the captures your report
# quotes. A repro that rewrites its own evidence lets a report drift into
# citing numbers from a run nobody kept — the one defect this course's whole
# evidence contract exists to prevent. Refresh the archive deliberately, and
# re-quote the report in the same commit.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# In your own repo this is just tools/vm — your workspace ships it. This
# example sits outside a workspace, so it looks next door for one.
VM="${VM:-}"
if [ -z "$VM" ]; then
    for cand in "$HERE/../../agent-starter/tools/vm" "$HERE/../../reference-agent/tools/vm"; do
        [ -x "$cand" ] && { VM="$cand"; break; }
    done
fi
[ -n "$VM" ] && [ -x "$VM" ] || {
    echo "repro: no vm tool found. Set VM=/path/to/tools/vm and re-run." >&2
    exit 2
}

EV="${REPRO_OUT:-${TMPDIR:-/tmp}/kl-repro-vm-cow-01}"
if [ "${REPRO_ARCHIVE:-0}" = "1" ]; then EV="$HERE/evidence"; fi
mkdir -p "$EV"

echo "== run: COW trigger under a do_wp_page probe, private and shared =="
"$VM" up
"$VM" push "$HERE/guest/cow-trigger.c" "$HERE/guest/probe-do-wp-page.bt" /root/
"$VM" sh 'gcc -O2 -Wall -Werror -o /root/cow-trigger /root/cow-trigger.c'
"$VM" sh '{ uname -a; cat /proc/version; bpftrace --version; } > /root/kernel.txt'

# The probe attaches FIRST: bpftrace -c starts the workload only once every
# probe is attached, so the write can never race the instrumentation. -c also
# insists on a real ELF binary, which is why the trigger takes its report
# path as an argument instead of using shell redirection.
for mode in private shared; do
    "$VM" sh "bpftrace /root/probe-do-wp-page.bt \
                  -c '/root/cow-trigger $mode /root/trigger-$mode.txt' \
                  > /root/probe-$mode.txt 2>&1" || true
done

for f in kernel.txt trigger-private.txt probe-private.txt \
         trigger-shared.txt probe-shared.txt; do
    "$VM" pull "/root/$f" "$EV/$f"
done

echo
echo "== assert: the evidence says what the report claims =="
# Reusing the example's checker keeps the assertions in one place; a weekly
# repro.sh of your own would simply inline these greps.
"$HERE/check.sh" "$EV"
