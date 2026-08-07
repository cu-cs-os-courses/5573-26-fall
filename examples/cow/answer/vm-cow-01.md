*The same answer as [`vm-cow-01.json`](vm-cow-01.json), written the way
batches 1–3 ask for it: the [§7](../../../docs/course-design.md) fields in
prose. Nothing here is content the JSON does not carry — it is the same
evidence contract in the format you hand in before the agent arrives in
week 4. Use it as the shape of a full-credit manual report.*

---

# vm-cow-01 — How does this kernel implement copy-on-write for forked processes?

## Claim

`fork()` write-protects the PTEs of private writable mappings in **both**
parent and child (`copy_present_pte`). The first write then takes a
write-protect fault, handled by `do_wp_page` → `wp_page_copy` (inlined in
this build), which gives the writer a fresh physical page while the other
process keeps the original.

Shared mappings are never write-protected — fork does not even copy their
PTEs — so no copy ever occurs there.

**Confidence:** high. Two independent evidence kinds (kprobe on the fault
path, PFN readings from pagemap) agree, and a negative control rules out
the two things that could imitate the result.

## Evidence

### 1. The write-protect fault fires exactly once, in the child — trace (bpftrace)

**Command**

```sh
bpftrace guest/probe-do-wp-page.bt \
  -c '/tmp/cow-trigger private /share/evidence/trigger-private.txt'
```

**Raw output** (excerpt — full file: [`expected/probe-private.txt`](../expected/probe-private.txt))

```
do_wp_page fired: pid=184 addr=0x100000000000

        do_wp_page+1
        __handle_mm_fault+2133
        handle_mm_fault+323
        do_user_addr_fault+352
        exc_page_fault+103
        asm_exc_page_fault+38
```

**Interpretation.** The write-protect fault handler fires exactly once, in
the child (pid 184), at the mapped page, reached from the page-fault entry
path — the stack shows `asm_exc_page_fault → … → handle_mm_fault →
do_wp_page`, so this is a real fault on a write-protected PTE and not some
other call into the same function.

`wp_page_copy` has no kallsyms entry in this build — the compiler inlined it
into its only caller, so there is nothing to attach a kprobe to. This probe
therefore proves *a write-protect fault was handled at our address*; the
copy itself is proven by the pagemap evidence below. Two evidence kinds
carry the claim together because neither can carry it alone.

### 2. One page before the write, two after — state (pagemap)

**Command**

```sh
/tmp/cow-trigger private
# reads /proc/self/pagemap in parent and child, before and after the
# child's single write; source: guest/cow-trigger.c
```

**Raw output** (excerpt — full file: [`expected/trigger-private.txt`](../expected/trigger-private.txt))

```
parent_pfn_before=0x1323a
child_pfn_before=0x1323a
child_minflt_delta=1
child_pfn_after=0x143ad
parent_pfn_after=0x1323a
parent_reads=0xa5
```

**Interpretation.** One physical page (PFN `0x1323a`) is shared by both
processes after fork — same PFN from both sides. After the child's write the
child maps a **new** page (`0x143ad`) while the parent keeps the original.
That divergence is the copy.

Two supporting readings: the write cost exactly one minor fault
(`child_minflt_delta=1`), which matches one write-protect fault and rules
out a storm of unrelated faults; and the parent's sentinel still reads
`0xa5`, so memory isolation held.

### 3. Negative control: a shared mapping never copies — state (pagemap)

**Command**

```sh
/tmp/cow-trigger shared /share/evidence/trigger-shared.txt
```

**Raw output** (excerpt — full file: [`expected/trigger-shared.txt`](../expected/trigger-shared.txt))

```
parent_pfn_before=0x855d
child_pfn_before=0x0
child_present_before=0
child_minflt_delta=1
child_pfn_after=0x855d
parent_reads=0x5a
```

**Interpretation.** For a `MAP_SHARED` mapping, fork copies no PTEs at all —
the child's PTE is non-present at fork (`child_present_before=0`,
`child_pfn_before=0x0`). The child's write takes one minor fault that simply
maps the parent's page: **same** PFN (`0x855d`), `do_wp_page` silent, and
the write is visible to the parent (`parent_reads=0x5a`).

This control is what makes the claim specific. The private case also showed
"one minor fault," so a fault alone proves nothing; and lazy population also
produces a fault-then-mapped page. Only the private case changes the PFN.
The control separates COW from both fault noise and ordinary lazy
population.

### 4. Where the kernel does it — source

All references into the pinned 6.6.87 tree (browse with `make -C env
src-export`, or `tools/ksrc`).

| Ref | Symbol | Interpretation |
|---|---|---|
| `mm/memory.c:961-963` | `copy_present_pte` | **Fork side.** For COW-eligible mappings (`is_cow_mapping && pte_write`): `ptep_set_wrprotect()` on the parent and `pte_wrprotect()` on the child's copy. This is the arming of COW — and it explains why the fault lands in the *child* even though the parent was never touched. |
| `mm/memory.c:3354` | `do_wp_page` | **Fault side.** Handles the write to a write-protected PTE; for a page still shared with the other process it falls through to `wp_page_copy`. |
| `mm/memory.c:3069` | `wp_page_copy` | Allocates the new page, copies the contents, re-maps the faulting PTE writable. Inlined into `do_wp_page` in this build — hence no kallsyms entry and no probe point (see evidence 1). |
| `mm/memory.c:1241` | `vma_needs_copy` | Why the shared-mapping control behaves as observed: fork skips PTE copying entirely for VMAs with no `anon_vma`, so shared mappings are lazily re-faulted, never write-protected. |

## Reproduction

**Script:** [`../repro.sh`](../repro.sh) — re-runs the investigation against
a booted VM and asserts on what comes back. **That file is the model for the
`repro.sh` you hand in**, and this directory is the model for the rest of the
hand-in:

| you commit | model to copy |
|---|---|
| `report.md` | this file |
| `repro.sh` | [`../repro.sh`](../repro.sh) |
| your raw captures, under `evidence/` | [`../expected/`](../expected/) — five plain text files, named however you like |

(There is also [`../run.sh`](../run.sh), which boots a VM from cold and runs
the whole example unattended. That one is the example's *harness*, not a
model for your weekly hand-in — yours assumes the VM is already up.)

**Expected** (what a re-run must show; enforced by
[`../check.sh`](../check.sh), which `repro.sh` calls):

1. Probe `do_wp_page` fires exactly once, under the child PID, at address
   `0x100000000000`, via `handle_mm_fault` — private mapping.
2. Parent and child PFNs equal before the write; child PFN changes across
   the write; parent PFN does not — private mapping.
3. Child minor-fault delta across the single write == 1 — private mapping.
4. Parent sentinel reads `0xa5` after the child's write — private mapping,
   isolation.
5. Probe silent; child PTE non-present at fork; child faults in the
   parent's PFN; parent reads `0x5a` — shared control.

**Tolerance:** exact. PFN values vary per boot, so every assertion compares
equality or inequality *between* readings — never an absolute value. A
report that hard-codes `0x1323a` passes once and fails forever after.

## Limitations

- **THP is not exercised.** The trigger uses a single 4 KiB page; the
  huge-page path (`do_huge_pmd_wp_page`) is a different function and this
  evidence says nothing about it.
- **`wp_page_copy` is claimed indirectly** — via a probe on its caller plus
  the PFN divergence — because it is inlined in this build. If a future
  build stops inlining it, probe it directly and the claim gets stronger.
- **Minor-fault exactness depends on the measurement window.** The count is
  taken across a warmed, lockstepped single write; see
  [`guest/cow-trigger.c`](../guest/cow-trigger.c). Widen the window and
  unrelated faults will creep into the delta.
