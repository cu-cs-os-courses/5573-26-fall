# Batch 12 — `kernel/locking/` + RCU: what held it all together

*On the docket: Monday, week 12 (assignment sheets ship that day; the
questions have been public since before week 1). Defended: week 13 — **Monday:
lock-contend-01, rcu-gp-01 · Wednesday: lock-invariant-01,
lock-mutation-01**. You are assigned two of the four. **This is the
last batch.** Wednesday of week 13 is the final-interview briefing.*

*This batch carries the course's **last mutation question** —
`bzImage-2026f-05`, release asset `batch-12`, exactly one private
modification somewhere in the locking/synchronization story. The
drill is batch 6's, with one difference that defines the week:
**the evidence for a synchronization bug is statistical.** A single
run proves nothing in either direction. Every claim you make this
week needs a trial count, an observation count, and an effect size —
and a zero needs the same, because "I didn't see it" is only as
strong as how hard you looked.*

*One environment fact you should confirm yourself before planning
anything (`/proc/config.gz`): the debug oracles this subsystem is
famous for — `PROVE_LOCKING` (lockdep), `LOCK_STAT`, `KCSAN` — are
**not compiled into this kernel**. Working out what that removes from
your toolbox, and what it does *not* remove, is part of Wednesday's
question. Reports: `reports/batch-12/<question-id>/`,
[course-design.md §7](../../docs/course-design.md) schema,
`repro.sh`. Budget ~3–4 focused hours per question.*

---

## lock-contend-01 — Design a traffic jam, then measure it *(Q1, Monday)*

Uncontended locks are invisible: the fast path is an atomic operation
with nothing to probe. Your job is to make a real kernel lock hurt,
on purpose, and then describe the pain precisely. Build an adversarial
workload around one shared inode's `i_rwsem` (N processes `pwrite`ing
overlapping offsets of one file — write the trigger). Produce: (a)
the **null**: with N=1, show the write-side slowpath
(`rwsem_down_write_slowpath`) fires **zero** times, and explain what
that means about where uncontended acquisition happens and why it
leaves no trace; (b) the **jam**: with N=4 on this 2-vCPU VM, the
slowpath count over a fixed window (expect six figures) and the
**wait-time distribution** (kprobe → kretprobe delta) — report it as
a histogram; (c) the **structure**: that distribution is *bimodal*.
Name both mechanisms, cite where the source chooses between them
(the optimistic-spinning path and its MCS queue), and support the
split with a second measurement — e.g. `osq_lock` fire counts, or
correlating the slow mode with `sched:sched_switch` of your waiter
(batch 6 comes back); (d) the **control**: the same N=4 workload
against N *different* files — what happens to every number, and what
that proves about your attribution.

**Required evidence**
- N=1 zero-count with its explanation; N=4 count + wait histogram.
- The bimodality argument with source cites and a second, independent
  measurement supporting the two-mechanism reading.
- The different-files control.
- `repro.sh`: assert N=1 slowpath == 0; N=4 slowpath ≥ 10⁴ with a
  populated µs-scale mode and a populated ms-scale mode.

**Tools:** a pwrite-contention trigger (write it: N processes,
S seconds, one shared file — plus a separate-files mode for (d)),
`kprobe`/`kretprobe` on
`rwsem_down_write_slowpath`, `kprobe:osq_lock`, `sched:sched_switch`,
`tools/ksrc view kernel/locking/rwsem.c`.

**At the defense, expect:** Your ms-scale mode — who was on the CPU
while your waiter slept, and how would you prove it? Predict both
modes on a 4-vCPU machine. Why does the kernel spin *at all* before
sleeping — what does it know that userspace mutexes usually don't?
Which of your numbers would change if the file were opened O_DIRECT
(and which lock would you then be fighting)?

---

## rcu-gp-01 — Timing a promise about the past *(Q1, Monday)*

RCU's grace period is the strangest object in this course: a wait for
an event that has no single cause. Make it observable. Produce: (a)
the **trigger**: `membarrier(MEMBARRIER_CMD_GLOBAL)` calls
`synchronize_rcu()` from plain userspace — verify that claim with a
probe (don't take the manual's word), then measure the syscall's
latency distribution over ≥20 calls; (b) the **anatomy**: with the
`rcu:` tracepoint family, capture the phase sequence around one
grace period (`rcu_grace_period`'s `gpevent` strings tell the story:
request, start, force-quiescent-state rounds, per-CPU quiescence,
end) and name the kernel thread that runs it; (c) the **bargain**:
attempt to instrument the *read* side (`rcu_read_lock`) and report
what you find — then explain, from source and from your numbers, what
RCU trades away and what it buys, and why that trade fits the places
this course already saw it used (batch 9's path walk is one — find
the others); (d) the **load contrast**: repeat (a) with both CPUs
busy (batch 6's hogs) and **predict the direction first** — does a
busy system make a grace period longer or shorter? Explain the answer
in terms of what actually ends a grace period.

**Required evidence**
- The probe evidence that membarrier reaches synchronize_rcu; the
  latency distribution.
- The gpevent phase capture + the GP kthread named.
- The read-side attempt and its interpretation, with source cites.
- The written prediction and the idle-vs-loaded distributions.
- `repro.sh`: assert ≥20 grace periods observed and a median in a
  stated band; assert the phase events present.

**Tools:** `membarrier(2)` (write the trigger),
`kprobe`/`kretprobe:synchronize_rcu`, `tracepoint:rcu:rcu_grace_period`
(+ `rcu_batch_start/end`), your batch-6 hog trigger, `tools/ksrc view
kernel/rcu/tree.c kernel/sched/membarrier.c`.

**At the defense, expect:** Your grace period was milliseconds — what
is it *waiting for*, precisely? A CPU that is idle: does it hold up a
grace period, and what mechanism makes the answer no? What would
`synchronize_rcu` do if one CPU spun in a kernel loop without ever
scheduling (name the config option that decides how bad that gets)?
Why is `call_rcu` usually preferred over `synchronize_rcu` — with
your latency number as the argument.

---

## lock-invariant-01 — Proving a negative *(Q2, Wednesday)*

Correct synchronization produces **no** evidence. This question is
about building the only kind of test that can speak about it: a
workload plus an invariant plus enough observations to make a zero
mean something. Pick the kernel's hostname (`sethostname` takes the
uts rwsem for writing; `uname`/`gethostname` take it for reading —
cite all three sites). Produce: (a) the **invariant**, stated
formally: what must a reader observe, given the lock? Design writer
and reader workloads that make a violation *checkable* — the trick is
choosing names such that any mixture is self-evident (think about
lengths and characters); (b) the **run**: multi-process stress on both
CPUs for ≥5 s, reporting reads, writes, violations, and the
observation rate; (c) the **power argument**: your violation count is
zero — now defend that zero. How many observations did it cover?
Under what timing would a violation have been visible at all? What is
the smallest effect your experiment could have detected, and how
would you *increase* its power (name three changes)? (d) the
**toolbox map**: read `/proc/config.gz` and report which
synchronization-debugging oracles this kernel does and does not carry;
for the missing ones, state precisely what class of bug each would
have caught — and, for lockdep specifically, whether it would catch a
*missing* lock at all. Cite, don't assume.

**Required evidence**
- The invariant, the workload design rationale, and the validator
  logic (in your trigger's source).
- The run table (reads/writes/violations/duration) with the rate.
- The statistical-power paragraph with the three power increases.
- The config readback + the per-oracle scope statement.
- `repro.sh`: assert ≥10⁶ validated observations with zero
  violations (a passing baseline is the deliverable here).

**Tools:** a uts-race trigger (write it: forked writers alternating
two distinguishable names, forked readers validating every `uname`),
`/proc/config.gz`, `tools/ksrc view kernel/sys.c`.

**At the defense, expect:** Your zero — convince me it isn't just a
slow reader. What would you change to make a *real* torn read more
likely, if one existed (three levers)? Where else in this kernel does
the same rwsem get taken, and does your test cover those writers?
Suppose I told you a violation happens once per ten million reads —
design the experiment that would find it, and say what it costs.

---

## lock-mutation-01 — The last mutant *(Q3, Wednesday)*

The image `bzImage-2026f-05` differs from the pinned kernel by exactly
one private modification in the synchronization story. Characterize
it. The contract is batch 6's — experiment matrix with negatives,
quantified signature, mechanism hypothesis, verdict with the
guarantee named — with this batch's amendment: **every number is a
rate over trials**, and your report must state trial counts,
observation counts, and what a null result in each experiment would
and would not have ruled out.

Two warnings, both earned: (1) this subsystem's mutations may leave
*every single-threaded measurement identical* — if your matrix is all
serial workloads, you will confidently conclude "benign"; (2) the
effect, if you find one, may be **rare** — an event per million is
still a broken kernel. Design for detection, then quantify.

**Required evidence**
- The matrix: serial AND concurrent probes, stock vs mutant, with
  trial/observation counts per cell.
- The quantified signature (rate, trials positive/total, a sample
  observation) with raw captures from both kernels.
- The hypothesis, argued from behavior to mechanism; the verdict,
  argued from the named guarantee.
- `repro.sh`: takes the image path, runs N trials per kernel, asserts
  stock clean at a stated observation count and mutant positive in
  the majority of trials.

**Tools:** everything — this batch's own instruments are the point.

**At the defense, expect:** On-the-spot: "run your detector on this
third image" (with your rate, how long must I wait before your
silence means anything?). Which of your experiments would have caught
this if the effect were 100× rarer? What userspace program in normal
use would ever notice this, and what would the symptom look like in a
bug report? Would lockdep have caught it — argue from (d) of
lock-invariant-01, not from reputation.

---

*Connection to what's next: nothing — and that is the point. Twelve
batches ago you traced a `ls` with ftrace because you had no other
instrument. Since then you have built a toolkit, an evidence habit,
and a way of arguing about a system that does not care what you
believe. The final interview is one hour of exactly that, on a kernel
none of us has seen yet. Bring the method; the kernel will be new for
me too.*
