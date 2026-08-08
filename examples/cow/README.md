# Worked example: copy-on-write, end-to-end

This is the [course design doc §9](../../docs/course-design.md) investigation
carried out for real, **with no agent** — every step is a plain script, so it
proves the reference environment supports the course's pedagogy and gives
students a concrete model of what a full-credit investigation looks like.
It also prototypes the evidence pattern that in-class re-runs and spot replays
build on: raw evidence files + machine-checkable assertions
([`check.sh`](check.sh)).

**The question (vm-cow-01):** *"How does this kernel implement copy-on-write
for forked processes? Support every claim with runtime evidence."*

## Run it

```sh
# prerequisite: reference images built (make -C ../../env images)
./run.sh        # boots the VM headless, runs the investigation, checks evidence (~1 min)
```

Expected output: 16 `PASS` lines and `ALL CHECKS PASSED`.

## The hand-in this produced

Everything a submission consists of sits in
[`vm-cow-01/`](vm-cow-01/) — **that directory is one hand-in, with the
names and the nesting the collection script requires**
([`agent-starter/reports/README.md`](../../agent-starter/reports/README.md)).
Only the `reports/batch-NN/` prefix is missing, because this question came
from no batch:

```
examples/cow/
├── run.sh, check.sh, guest/    scaffolding — NOT part of a hand-in
│                               (your triggers and probes live in your
│                               workspace's triggers/ and probes/)
└── vm-cow-01/          ←  copy this shape into reports/batch-NN/
    ├── report.md              prose — what batches 1–3 ask for
    ├── report.json            structured — from batch 4 on
    ├── repro.sh               required every week
    └── evidence/              the raw captures, in this subdirectory
```

You commit **one** report file, whichever matches your week; both are here
so you can read the same investigation in both renderings. Every excerpt in
both is quoted from `evidence/` beside them, so you can check them against
the raw files — and should.

Note what the report files do *not* do: reach outside their own directory
for their evidence. `report.md` cites `evidence/probe-private.txt`, and
`report.json` names `"script": "repro.sh"` — both siblings, exactly as
`tools/report-check` expects to find them next to a report.

## The investigation, step by step

Mirrors §9 of the design doc. All file:line references are into the pinned
6.6.87 tree (browse via `../../env/src/` — create or refresh it with `make -C ../../env src-export`).

**1. Source localization.** Fork side: `copy_page_range`
(`mm/memory.c:1268`) → `copy_present_pte` (`mm/memory.c:923`), which
write-protects the PTE in *both* parent and child for private writable
mappings (`mm/memory.c:961-963`). Fault side: `handle_mm_fault` →
`do_wp_page` (`mm/memory.c:3354`) → `wp_page_copy` (`mm/memory.c:3069`),
which allocates the new page and re-maps the faulting PTE read-write.

**2. Hypothesis.** After fork, parent and child PTEs map the same PFN
read-only; the first write by either takes a write-protect fault;
`wp_page_copy` gives the writer a fresh page; the other process keeps the
original.

**3. Trigger design** ([`guest/cow-trigger.c`](guest/cow-trigger.c)). One
private anonymous page at a **fixed address** (`0x100000000000`, so the probe
can filter on it), sentinel written pre-fork, then exactly one child write.
Parent and child run in lockstep over pipes, so every measurement is ordered;
each records its PFN view (`/proc/self/pagemap`) before/after the write, and
the child brackets the write with `/proc/self/stat` minor-fault readings.

**4. Instrumentation** ([`guest/probe-do-wp-page.bt`](guest/probe-do-wp-page.bt)).
A kprobe on the write-protect fault handler, filtered to the workload's comm
and the fixed map address, printing pid, faulting address, and kernel stack.
`bpftrace -c` starts the workload only after the probe is attached, so the
write can never race the instrumentation.

> **Why probe `do_wp_page` and not `wp_page_copy`?** In this kernel build the
> compiler inlined `wp_page_copy` into its only caller — `nm dist/vmlinux`
> shows no `wp_page_copy` symbol, so there is nothing to kprobe. This is the
> course's source↔binary mapping lesson in miniature: *the function named in
> every textbook may not exist as a probe point in your build.* The probe
> proves a write-protect fault was handled at our address; the **pagemap PFN
> divergence proves the copy itself**. Two independent evidence kinds carry
> the claim together.
>
> Second build-specific lesson, learned the hard way: `bpftrace -c` accepts
> only a real ELF binary — a shell-wrapper script is rejected — hence the
> trigger writes its own report file instead of relying on redirection.

**5. Run + evidence** (private mapping, from [`vm-cow-01/evidence/`](vm-cow-01/evidence/)):
probe fires **exactly once**, in the child, at the mapped address, with
`handle_mm_fault → do_wp_page` on the stack; PFNs identical before the write
(`0x1323a` in both processes), divergent after (child `0x143ad`, parent still
`0x1323a`); the child's minor-fault counter increments by **exactly one**;
the parent's sentinel is intact — isolation held.

**6. Negative control** (shared mapping) — and the behavior is *more
interesting than the naive expectation*: for `MAP_SHARED` anonymous memory,
fork does not copy the PTEs at all (`vma_needs_copy()`, `mm/memory.c:1241`,
is false — no `anon_vma`), so the child starts with a **non-present** PTE
(`child_present_before=0`). Its write takes one minor fault that simply maps
the parent's page — same PFN, `do_wp_page` silent, and the parent sees the
child's value. No copy anywhere. This control distinguishes COW from both
generic fault noise *and* ordinary lazy population.

**7. The answer.** Written twice, to the same design-doc §7 evidence contract:
[`vm-cow-01/report.md`](vm-cow-01/report.md) in prose and
[`vm-cow-01/report.json`](vm-cow-01/report.json) structured. Either way every
evidence entry carries the command that produced it, a raw-output excerpt,
and an interpretation; `repro` names the `repro.sh` beside it, carrying the
assertion list `check.sh` enforces. The JSON is what `tools/report-check`
validates and what an agent emits from batch 4 on — the prose is the same
contract with the punctuation taken out.

## Files

**The hand-in** — `vm-cow-01/`, the part you copy the shape of:

| File | Role |
|---|---|
| `vm-cow-01/report.md` | the answer in prose — the batch 1–3 hand-in format |
| `vm-cow-01/report.json` | the same answer structured (design-doc §7 schema) — the batch 4+ format |
| `vm-cow-01/repro.sh` | **the model for the `repro.sh` you hand in every week** — re-run against an already-booted VM and assert; scratch output by default, `REPRO_ARCHIVE=1` to refresh `evidence/` |
| `vm-cow-01/evidence/` | raw captures from a real passing run — the model for the `evidence/` directory in your own hand-in |

**The scaffolding** — outside the hand-in, because none of it belongs in one:

| File | Role |
|---|---|
| `run.sh` | host side: boot VM headless, run investigation via the autorun channel, check evidence |
| `check.sh` | the 16 machine-checkable assertions (replay-gate prototype) |
| `guest/cow-trigger.c` | deterministic trigger workload (private + shared modes) — in your workspace this would live in `triggers/` |
| `guest/probe-do-wp-page.bt` | bpftrace probe on the wp-fault path — in your workspace, `probes/` |
| `guest/investigate.sh` | guest-side orchestration (compile → attach → run → collect) |

## Where this goes next (Q3 preview)

Under the design-doc §9 mutation — skip the `pte_wrprotect` in
`copy_present_pte` for private mappings — these same instruments produce the
opposite record: probe never fires, PFNs stay shared after the child's write,
and the parent's sentinel is corrupted (`parent_reads=0x5a` in a *private*
mapping). The identical toolkit, with no changes, converts a mechanism
question into a mutation verdict: fork's memory-isolation contract is
violated.