# Batch 5 — `mm/`: virtual memory is a set of promises, lazily kept

*Released: Monday, week 5. Defended: week 6 — **Monday: mm-lazy-01,
mm-zeropage-01 · Wednesday: mm-dontneed-01, mm-thp-01**. You are
assigned two of the four.*

*You watched the COW demo Monday; this batch is the rest of the lie anonymous
memory tells you. Every question below is about the gap between what `mmap`
promises and when the kernel actually delivers — and every claim is checkable
from userspace with `/proc/<pid>/pagemap` (bit 63 = present, bits 0–54 = PFN
as root: your page-table window), `VmRSS`, and the fault events you already
know from batch 2. Reports: `reports/batch-05/<question-id>/` with
`report.json` ([course-design.md §7](../../docs/course-design.md),
`tools/report-check`), raw captures, `repro.sh`. Budget ~3–4 focused hours per
question.*

*Standing hygiene note, one last time in the header: this VM boots THP
`[always]`. Three of these questions require `madvise(MADV_NOHUGEPAGE)`
discipline (verify with `AnonHugePages: 0 kB` in smaps) — and the
fourth question is about what happens when you don't.*

---

## mm-lazy-01 — The loan and the prepayment *(Q2, Monday)*

Write one trigger with two modes mapping the same N anonymous pages:
`lazy` (plain `MAP_PRIVATE|MAP_ANONYMOUS`) and `populate` (same +
`MAP_POPULATE`). For both modes, **predict in writing, then measure,
three numbers**: pagemap-present count immediately after `mmap`
returns, `exceptions:page_fault_user` events during a full write sweep
of the region, and the `VmRSS` delta across the sweep. (`NOHUGEPAGE`
the region first — question four explains why.)

Then find the cost that moved: the populate mode's faults didn't
disappear. Show where the pages were created — cite the call path from
the `mmap` syscall to the function that walks the range pre-faulting
it, back it with one kernel-side probe on that path firing at mmap
time, and measure what `MAP_POPULATE` did to the `mmap` call's own
latency.

**Required evidence**
- The 2×3 prediction table (committed as predicted) and the measured
  table, with every mismatch explained.
- Raw pagemap summaries and the filtered fault-event captures for both
  modes.
- The populate call path cited `file:line` from the mmap syscall down
  to the range-walker, plus your probe firing during `mmap` in
  populate mode and not in lazy mode.
- `repro.sh`: both modes; assert lazy = {0 present at return, ~N sweep
  faults, +N RSS} and populate = {N present at return, ~0 sweep
  faults}.

**Tools:** `/proc/<pid>/pagemap` (`agent-starter` ships a reader),
`exceptions:page_fault_user` with an in-kernel address-range filter
(batch 2), `tools/ksrc grep MAP_POPULATE`, kprobes. One timing wrinkle
you must reason through: `MAP_POPULATE` faults *inside* the `mmap`
call — before any `madvise` window exists — so per-region
`MADV_NOHUGEPAGE` cannot cover the populate mode; there is a
process-wide `prctl` that can precede the mmap. Finding it (and saying
why the asymmetry exists) is part of the answer.

**At the defense, expect:** Why is the populate-mode page creation
invisible to `page_fault_user`? Your populate probe fired once per
mmap — or once per page? Check before you claim. `time mmap` went up
by roughly what your sweep cost saved — where would `MAP_POPULATE`
actually be worth it? What does `mlock` share with this path?

---

## mm-zeropage-01 — One PFN to rule them all *(Q1, Monday)*

Map N anonymous pages (`NOHUGEPAGE`'d), and touch every page with a
**read** — a volatile load, not a store. Now look at pagemap: every
page is present, `VmRSS` barely moved, and — the claim you must prove —
**every single page maps the same PFN**. Identify what that page is,
cite the branch in the anonymous-fault handler that installs it (what
condition sends a fault down this path instead of allocating?), and
explain why it can be safely shared by every process on the system.

Then break the spell: write one byte to one page. Show that exactly
that page's PFN diverged, RSS moved by exactly one page, and the write
went down a path you already know from the COW demo — name it, and
explain in one paragraph why the zero page is copy-on-write's
degenerate case.

**Required evidence**
- Pagemap dumps (raw) after the read sweep: N present entries, one
  distinct PFN value across them — and after the single write: N−1
  shared + 1 diverged.
- The *region's* smaps `Rss:` at each stage — that is the exact meter
  (process `VmRSS` is served from cached per-task counters and lags by
  hundreds of KB; per-page claims must not rest on it). And when you
  read the region's Rss after the sweep, the number will demand an
  explanation — give it.
- The cited fault-handler branch (read vs. write condition) and the
  write-path connection to the COW mechanism.
- `repro.sh`: assert one-distinct-PFN after reads, exactly-one-diverged
  after the write, and the RSS deltas.

**Tools:** pagemap reader (PFNs need root — you are root),
`tools/ksrc view mm/memory.c`, smaps.

**At the defense, expect:** What is the PFN you saw — find the actual
page it names (there is a way to check what the kernel calls it). Why
did your read sweep cost N faults but ~0 resident pages — reconcile
with question one's "N faults = N pages" arithmetic. Predict: does
`MAP_POPULATE` on a region you'll only read map the zero page or real
pages? Try it. A write to a *never-touched* page skips the zero page
entirely — what single condition in the handler decides that?

---

## mm-dontneed-01 — The eviction you aim at yourself *(Q1, Wednesday)*

`madvise(MADV_DONTNEED)` is routinely described as a "hint". Show that
on this kernel it is nothing of the sort — it acts now, and what comes
back afterward depends on what was behind the mapping.

Build a trigger with two modes. **anon**: write sentinel bytes into
`NOHUGEPAGE`'d anonymous pages, `MADV_DONTNEED` the region, then read
it again — show present bits drop at the madvise (not later — present-bit counts
are your exact meter; process `VmRSS` corroborates approximately), and
the re-read returns zeros: your bytes are unrecoverable, and the old
page is gone (PFN evidence — and look closely at *which* PFN your
zero-read landed on; Monday's second question is watching). **file**: `MAP_PRIVATE` a file, dirty a page in memory,
`MADV_DONTNEED`, re-read — your modification is gone and the *file's*
bytes are back. Cite the madvise dispatch down to the function that
does the teardown, and explain the asymmetry: where do the two refault
paths get their contents from?

**Required evidence**
- Both modes' before/madvise/after pagemap + `VmRSS` + content
  checks (raw), with PFN evidence that refaulted anon pages are new.
- The cited path: madvise dispatch → single-VMA handler → the zap, with
  one kernel-side probe firing at madvise time.
- The one-paragraph asymmetry explanation (anon refault vs. file
  refault sources).
- `repro.sh`: assert the present-bit drop at madvise (exact); zeros
  after anon refault; original file content after file refault.

**Tools:** `madvise(2)`, pagemap reader, `tools/ksrc view
mm/madvise.c`, kprobes.

**At the defense, expect:** How is this different from `MADV_FREE` —
and which would show delayed, not immediate, present-bit drops?
Predict `MADV_DONTNEED` on a `MAP_SHARED` file mapping: what happens
to a dirty page, and why must it be different? If a kernel change made
DONTNEED silently do nothing, exactly which of your assertions catches
it? (Keep that answer; it will age well.) What legitimate software
wants this syscall — name a real user pattern.

---

## mm-thp-01 — The 2 MiB page behind your back *(Q4, Wednesday)*

Since batch 1 the question texts have told you to `MADV_NOHUGEPAGE`
first and move on. This week you explain the thing you've been fencing
out. Same trigger, two modes, dense write sweep over the same
2 MiB-aligned anonymous region: `nothp` (`MADV_NOHUGEPAGE`) and `thp`
(let the boot default act). Explain **every difference** between the
two runs' numbers: the fault-event counts (predict the ratio before
you run — think about what one fault installs in each mode), the
pagemap picture (in `thp` mode, pages you never touched read present —
reconcile), smaps `AnonHugePages`, and the faults' destinations in the
kernel — two different handler functions: cite both, then go probe
them, knowing by now that one of the two will refuse (the kallsyms
discipline); find a probeable witness for each side (the region-filtered
fault count *is* one).

Close the loop on the course's own history: using your evidence,
explain in one paragraph why batch 1's pagemap question produced
*nondeterministic* present-bit spill until the `NOHUGEPAGE` hint was
added — including what the nondeterminism depended on.

**Required evidence**
- Both modes: fault counts (in-kernel-filtered), pagemap summaries,
  `AnonHugePages` smaps lines, and the two cited+probed fault
  handlers with per-mode fire counts.
- The written ratio prediction and its reconciliation.
- The batch-1 post-mortem paragraph (alignment is part of the answer —
  show it, e.g. by mapping with and without an aligned hint).
- `repro.sh`: assert the handler split (huge handler fires only in
  `thp` mode), the ~512× fault-count separation per 2 MiB, and
  `AnonHugePages` ≥ region size in `thp` mode only.

**Tools:** your batch-1 pagemap trigger, extended with a second mode
(the two runs differ only by one `madvise` call — keep both in one
program so the contrast is a flag, not a fork of your source);
`/sys/kernel/mm/transparent_hugepage/`, smaps,
`tools/ksrc grep huge_pmd_anonymous`.

**At the defense, expect:** Were your THP faults minor or major — and
why must they be minor? What would `perf`-visible cost look like if a
workload touched one byte per 2 MiB across a huge range under
`[always]` — who pays, and in what currency (memory? time? both)?
`echo never` vs. `madvise` vs. `always` — which processes does each
policy protect, and from what? khugepaged exists — what does it do
that the fault path doesn't, and how would you catch it in the act?

---

*Connection to what's next: every fault this week was a scheduling
event too — the faulting task blocked, someone else ran. Batch 6 opens
`kernel/sched/` on exactly that machinery: who runs next, why, and
what evidence "why" even means. It also carries the course's first
mutation question — the briefing is in the batch file.*
