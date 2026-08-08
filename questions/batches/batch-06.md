# Batch 6 — `kernel/sched/`: who runs next, and how you'd prove why

*Released: Monday, week 6. Defended: week 7 — **Monday:
sched-eevdf-pick-01, sched-wakeup-01 · Wednesday: sched-ctxcost-01,
sched-mutation-01**. You are assigned two of the four.*

*This batch carries the course's **first mutation question**
([course-design.md §6.3](../../docs/course-design.md)). The drill, once, in
full: alongside this batch you get a
prebuilt kernel image, `bzImage-2026f-01` (release asset `batch-06` on
the course repo — `gh release download batch-06`). It is the pinned
6.6.87 **plus exactly one private modification, somewhere in
`kernel/sched/`**. Boot it with the same rootfs and tooling:
`KERNEL=path/to/bzImage-2026f-01 ./run.sh` (or `KERNEL=... tools/vm
up`). Mutations come in three classes — correctness-breaking,
performance-degrading, benign refactor — so **"it's broken" is never a
safe default**; your verdict must be argued from differential evidence,
stock vs. mutant, same triggers, same probes. `uname -r` is identical
on purpose. No, you may not diff the binaries — you may, but the
defense will ask you what the *behavior* is, and binary archaeology
answers a different question.*

*Timing honesty note for the whole batch: this VM runs under TCG with ±5 ms
wall-clock jitter. Event **counts** and **ratios** are your friends; single
microsecond measurements are not. Reports: `reports/batch-06/<question-id>/`,
[course-design.md §7](../../docs/course-design.md) schema, `repro.sh`. Budget
~3–4 focused hours per question.*

---

## sched-eevdf-pick-01 — Equal progress, unequal wall clocks *(Q1, Monday)*

Run two CPU hogs pinned to one CPU: one at nice 0, one at nice 5
(write the trigger: a syscall-free spin loop that pins itself with
`sched_setaffinity`, sets its own comm via `prctl(PR_SET_NAME)` so
your in-kernel filters can name it, and takes a nice value — you will
reuse this hog for the rest of the semester). Over a
≥10 s window, produce: (a) each task's **wall-clock CPU share** (from
`sched:sched_switch` timestamp deltas — you did this arithmetic in
batch 1), and (b) each task's **vruntime progress** over the same
window (readable per-task in `/sys/kernel/debug/sched/debug` snapshots,
or live via a probe that reads the outgoing task's
`curtask->se.vruntime` at switch time).

The claim you must defend: **the CPU shares are unequal in exactly the
weight ratio the nice table promises, while the two vruntimes advance
at (nearly) the same rate** — because vruntime is weighted time, and
equalizing *it* is what "fair" formally means here. Cite where vruntime
is advanced (the weighting happens there) and where the next task is
picked, and connect: the picker chooses by eligibility+deadline over
*virtual* time, so equal-vruntime-progress *is* the fairness invariant,
and the wall-clock skew is its shadow.

**Required evidence**
- Per-task CPU shares and the nice-weight prediction they should match
  (state the expected ratio *before* measuring; the weight table is in
  the source).
- Vruntime-progress evidence for both tasks over the same window, with
  the ~equal rates shown.
- Source citations: the advance site (weighting) and the pick site.
- `repro.sh`: run the pair, assert the share ratio within stated
  tolerance and the vruntime-rate ratio ≈ 1 within stated tolerance.

**Tools:** your hog trigger (above), `sched:sched_switch`,
`/sys/kernel/debug/sched/debug`, bpftrace `curtask` + BTF field access,
`tools/ksrc grep calc_delta_fair`.

**At the defense, expect:** Predict, then verify: nice 0 vs nice 10 —
what share ratio? Where exactly does nice enter the arithmetic — show
the multiplication. If vruntime advanced equally but shares were also
equal, what would that tell you? A third hog joins at nice 0 — predict
both columns. Why does the debug file show `deadline` per entity, and
what picks between two *eligible* entities?

---

## sched-wakeup-01 — The moment of waking *(Q1, Monday)*

Instrument the path from "an event makes a task runnable" to "the task
runs": a blocked reader on a pipe, a writer that writes at controlled
intervals. Produce (a) **who wakes whom**: kernel-stack evidence from
the wakeup side showing the writer's syscall path invoking the wakeup
(`try_to_wake_up` is probeable), with the woken pid in the probe's
arguments; (b) the **wakeup-to-run latency**: the delta from
`sched:sched_wakeup` to the `sched:sched_switch` that puts the reader
on CPU, as a distribution over ≥100 wakeups (in-kernel histogram —
batch 3 skill); and (c) the **contended contrast**: the same
measurement with a CPU hog pinned to the reader's CPU — does the woken
reader preempt the hog immediately, or wait? Explain what the
scheduler consults to decide (eligibility — the reader slept; what did
sleeping do to its entitlement?).

**Required evidence**
- The wakeup kstack, annotated: syscall → pipe machinery → wakeup, with
  the woken pid tied to your reader.
- Two latency histograms (idle CPU vs. hog-contended CPU), medians
  stated with TCG-honest tolerances.
- The preemption answer, with the deciding mechanism cited (where does
  the just-woken task's position come from — what does the placement
  code do with a task that slept?).
- `repro.sh`: both scenarios, assert wakeup events ≥100, assert the
  idle-CPU median below a stated bound and *an explicit statement*
  of what the contended median did relative to it.

**Tools:** `kprobe:try_to_wake_up` (arg0 is the task being woken —
BTF: `((struct task_struct *)arg0)->pid`), `sched:sched_wakeup`,
`sched:sched_switch`, per-pid timestamp maps, your hog trigger.

**At the defense, expect:** Your writer's stack shows the wakeup
running in the *writer's* context — what does that cost the writer,
and where does it end (who takes over)? What would the latency
histogram look like on a kernel where wakeup preemption was disabled?
The placement code gives a sleeper a vruntime near the current
minimum, not its stale one — why is *not* crediting the full sleep the
fairer choice? (Careful: what would happen to a task that slept a
week?)

---

## sched-ctxcost-01 — The price of a context switch, honestly *(Q2, Wednesday)*

Measure what a context switch costs on this system — and be explicit
about what you can and cannot separate. Build a pipe ping-pong pair
pinned to one CPU (a 1-byte token bouncing forever): every roundtrip is
two syscall-driven switches. Report (a) roundtrips/second over a ≥10 s
window, (b) `sched:sched_switch` **count** evidence that each
roundtrip really costs exactly two switches between your two tasks (the
count is exact even when the clock is not — assert it), and (c) the
derived per-switch cost, presented with an honest error budget: what's
in that number besides the switch itself (two `read`/`write` syscalls,
pipe locking, wakeup work — enumerate, and bound what you can).

Then the differential that bounds how much of the cost the switch
itself is: run the same pair **on two CPUs** (the token still
serializes them, but each CPU mostly stops context-switching and
instead pays cross-CPU wakeup costs). Compare roundtrip rates and
switch counts. Warning worth having: the difference may be far
smaller than you expect — reporting *why* that is honest evidence
rather than a failed experiment is the point of this question.

**Required evidence**
- Same-CPU: roundtrips/s, switch counts (exactly 2× roundtrips ± noise
  you account for), derived µs/switch with the error budget written
  out.
- Two-CPU contrast: both metrics, and the paragraph on what the delta
  isolates.
- An explicit statement of TCG's effect on the absolute numbers and
  why the *counts* and *ratios* survive it.
- `repro.sh`: same-CPU run, assert switch-count ≈ 2× roundtrips within
  tolerance and a roundtrip rate floor.

**Tools:** pipe pair + `sched_setaffinity` (write the trigger; your
hog from this batch's first question shows the pinning idiom),
`sched:sched_switch`
with comm filtering, `taskset` for the contrast run.

**At the defense, expect:** Your µs/switch number — defend its
numerator and denominator. Which part of the cost would a larger
working set inflate (what state actually gets switched, and what just
gets *cold*)? Why is `perf bench sched pipe` (if you found it) not
automatically the same number? Two switches per roundtrip — show me
the four `sched_switch` events of one roundtrip in your raw capture
and name every transition.

---

## sched-mutation-01 — The first mutant *(Q3, Wednesday)*

The image `bzImage-2026f-01` differs from the pinned kernel by exactly
one private modification somewhere in `kernel/sched/`. Characterize it.

Your report must contain: (a) a **differential experiment log** — the
triggers/probes you ran on both kernels and what came back, including
at least one experiment that came back *unchanged* (knowing what the
mutation does **not** affect is half the characterization); (b) the
**behavioral signature** — the smallest reproducible difference you
found, quantified, with tolerances; (c) a **mechanism hypothesis** —
what change in scheduler behavior explains your signature (you cannot
see the source; argue from behavior to mechanism, and be explicit
about what you can and cannot pin down); and (d) the **verdict**: is
this kernel still *correct*? Correct is a claim about guarantees —
name the guarantee(s) you tested, show they hold or break, and place
the mutation in one of the three classes.

**Required evidence**
- The experiment matrix: what you ran, on which kernel, what changed,
  what didn't (negative results are required content, not filler).
- The quantified signature with raw captures from both kernels.
- The hypothesis, argued; the verdict, argued from tested guarantees.
- `repro.sh`: runs against **both** kernels (takes the image path as
  an argument), asserts the signature on the mutant and its absence on
  stock.

**Tools:** everything you have; the batch-header boot instructions;
your batch-1 sched instruments are more relevant than you might
expect.

**At the defense, expect:** On-the-spot: "run your signature
experiment on this third image" (it may be stock, it may not). Which
of your experiments would have caught a *correctness* mutation in this
subsystem, had this been one? What single additional observation would
most narrow your mechanism hypothesis? If your hypothesis names a
specific quantity, predict what doubling it would do — and how you'd
check without source access.

---

*Connection to what's next: every switch you traced this week was the
kernel choosing between tasks already in the kernel. Batch 7 goes one
layer down: how execution* enters *the kernel at all — the `syscall`
instruction, the entry path, and the "syscalls" that never enter it.*
