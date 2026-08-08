#!/bin/bash
# Guest-side COW investigation, run as root by the autorun channel.
# Compiles the trigger, then for each mode attaches the probe FIRST
# (bpftrace -c starts the workload only after all probes are attached,
# so the write can never race the instrumentation) and collects all
# evidence under /share/evidence/.
set -u
EV=/share/evidence
mkdir -p "$EV"
{ uname -a; cat /proc/version; bpftrace --version; } > "$EV/kernel.txt"

echo "== compile trigger"
gcc -O2 -Wall -Werror -o /tmp/cow-trigger /share/cow-trigger.c || { echo "COMPILE FAIL"; exit 1; }

rc=0
for mode in private shared; do
    echo "== $mode run"
    # -c only accepts a real ELF binary (a shell-script wrapper is
    # rejected), so the trigger takes its report file as an argument
    # instead of relying on shell redirection.
    bpftrace /share/probe-do-wp-page.bt \
        -c "/tmp/cow-trigger $mode $EV/trigger-$mode.txt" \
        > "$EV/probe-$mode.txt" 2>&1 || { echo "bpftrace $mode FAIL"; rc=1; tail -3 "$EV/probe-$mode.txt"; }
done

echo "INVESTIGATE-DONE rc=$rc"
exit $rc
