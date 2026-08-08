#!/bin/bash
# Assert on the evidence produced by the guest-side COW investigation.
# Same shape as the evaluator's replay gate: machine-checkable
# expectations over raw evidence files.
#
#   check.sh <evidence-dir>
set -u
EV="${1:?usage: check.sh <evidence-dir>}"
fails=0
chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $d"; else echo "FAIL  $d"; fails=$((fails+1)); fi; }
val() { grep -m1 "^$2=" "$EV/$1" | cut -d= -f2; }

for f in trigger-private.txt probe-private.txt trigger-shared.txt probe-shared.txt; do
    [ -s "$EV/$f" ] || { echo "FAIL  missing evidence file $f"; exit 1; }
done

# --- private mapping: COW must happen, exactly once, in the child ---
child=$(val trigger-private.txt child_pid)
addr=$(val trigger-private.txt map_addr)
fired=$(grep -c 'do_wp_page fired' "$EV/probe-private.txt")
ppid=$(grep -m1 'do_wp_page fired' "$EV/probe-private.txt" | sed 's/.*pid=\([0-9]*\).*/\1/')
paddr=$(grep -m1 'do_wp_page fired' "$EV/probe-private.txt" | sed 's/.*addr=\(0x[0-9a-f]*\).*/\1/')

chk "probe fired exactly once (private)"          [ "$fired" = "1" ]
chk "probe fired in the child (pid $child)"       [ "$ppid" = "$child" ]
chk "probe fired at the mapped page ($addr)"      [ "$paddr" = "$addr" ]
chk "fault came through handle_mm_fault"          grep -q handle_mm_fault "$EV/probe-private.txt"
chk "page shared before write (parent PFN == child PFN)" \
    [ "$(val trigger-private.txt parent_pfn_before)" = "$(val trigger-private.txt child_pfn_before)" ]
chk "child got a new page (PFN changed)" \
    [ "$(val trigger-private.txt child_pfn_after)" != "$(val trigger-private.txt child_pfn_before)" ]
chk "parent kept the original PFN" \
    [ "$(val trigger-private.txt parent_pfn_after)" = "$(val trigger-private.txt parent_pfn_before)" ]
chk "exactly one minor fault for the write" \
    [ "$(val trigger-private.txt child_minflt_delta)" = "1" ]
chk "parent sentinel intact (isolation held)" \
    [ "$(val trigger-private.txt parent_reads)" = "0xa5" ]
chk "child exited cleanly (private)" \
    [ "$(val trigger-private.txt child_exit)" = "0" ]

# --- shared mapping (negative control): no COW anywhere ---
# fork does not copy PTEs of a shared mapping at all (vma_needs_copy() is
# false: no anon_vma); the child's write takes ONE minor fault that maps
# the parent's page — same PFN, no write-protect fault, write visible.
sfired=$(grep -c 'do_wp_page fired' "$EV/probe-shared.txt")
chk "wp probe silent (shared)"                    [ "$sfired" = "0" ]
chk "child PTE not populated by fork (shared)" \
    [ "$(val trigger-shared.txt child_present_before)" = "0" ]
chk "write faults in the parent's page, no copy (shared)" \
    [ "$(val trigger-shared.txt child_pfn_after)" = "$(val trigger-shared.txt parent_pfn_before)" ]
chk "one minor fault, but not a wp fault (shared)" \
    [ "$(val trigger-shared.txt child_minflt_delta)" = "1" ]
chk "parent sees child's write (shared)" \
    [ "$(val trigger-shared.txt parent_reads)" = "0x5a" ]
chk "child exited cleanly (shared)" \
    [ "$(val trigger-shared.txt child_exit)" = "0" ]

echo
if [ "$fails" -eq 0 ]; then
    echo "==> COW EXAMPLE: ALL CHECKS PASSED"
else
    echo "==> COW EXAMPLE: $fails CHECK(S) FAILED"
    exit 1
fi
