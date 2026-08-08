# Batch 3 — Probes anywhere: dynamic instrumentation and the stopped kernel

*Released: Wednesday, week 3 (the holiday week's single session — same day
batch 2 is defended). Defended: week 4 — **Monday: obs-kprobe-stacks-01,
obs-kprobe-args-01 · Wednesday: obs-kretprobe-hist-01, obs-gdb-current-01**.
You are assigned two of the four. This is the last manual batch: next week the
tool layer arrives and the questions start requiring triggers you design.
Everything here is still yours to type and explain — with any LLM help you
like ([course-design.md §10](../../docs/course-design.md)); it is the running
and the explaining that must be yours.*

*Report format as before: `reports/batch-03/<question-id>/` with `report.md`
([course-design.md §7](../../docs/course-design.md) fields in prose), raw
captures, `repro.sh`. Budget ~3–4 focused hours per question.*

*Batches 1–2 used the kernel's pre-built windows — static events and
tracepoints, placed where the maintainers chose. This batch removes that
restriction twice: **kprobes/bpftrace** let you attach a probe to (almost)
any of the kernel's functions, and the **QEMU gdbstub** lets you stop the
whole kernel and walk its memory with types. With great power comes the
first real footguns; two of them are built into these questions on purpose.*

---

## obs-kprobe-stacks-01 — Many roads lead to `schedule()` *(Q1, Monday)*

Attach a kprobe to `schedule()` and aggregate kernel stacks
(`@[kstack] = count()` in bpftrace). Design a set of small workloads that
make **at least three distinctly different call stacks** appear — three
different *reasons* the kernel decided to switch away from a task — and for
each stack: name the path, cite the pivotal frame's `file:line` in the
pinned tree, and explain what made the task stop running.

**Required evidence**
- The aggregated stacks (trimmed to the three you claim, full capture as a
  file), each annotated frame-by-frame at the pivotal points.
- The workloads that produced each stack, and *why* each one forces its
  path (a sleeping reader, a CPU hog on a contended core, a task waiting
  on I/O are all fair game — the design is the graded part).
- `repro.sh`: run the workloads under the probe, assert ≥3 distinct stacks
  containing `schedule` appear.

**Tools:** `bpftrace -e 'kprobe:schedule { @[kstack] = count(); }'` plus
filtering (`/comm == .../`) to keep your workloads separable from system
noise.

**At the defense, expect:** Which of your three stacks is an *involuntary*
switch, and how does that connect to the `prev_state=R` evidence from
batch 1? What is the topmost common frame in every stack, and why must it
be there? If you probed `__schedule` instead — predict the difference,
then try it. What you hit is itself the answer to a question: why would
the scheduler's core be off-limits to the tracer?

---

## obs-kprobe-args-01 — Catch it red-handed *(Q1, Monday)*

Using a dynamic probe on the open path (`kprobe:do_sys_openat2`, or the
syscall tracepoint if you argue for it), produce the complete list of files
that `python3 -c 'pass'` — a program that ostensibly does nothing —
actually opens. Filter **in the probe** (comm/pid), print the filename
argument, and group the results: interpreter startup, standard library,
locale/encodings, anything that surprised you.

One footgun is planted here: the filename lives in a **user-space**
pointer, and a probe runs in kernel context. If your strings come back
empty, ask yourself whose address space that pointer belongs to — and look
up what `uptr()` declares. Explaining this in the report is part of full
credit.

**Required evidence**
- The complete, deduplicated open list for one run, grouped and annotated;
  raw capture as a file.
- The probe program, with the in-probe filter and the pointer-space
  handling explained in a sentence each.
- A one-paragraph justification of your probe placement: what does
  `do_sys_openat2` catch, and name one way a process can read a file's
  contents **without** ever passing through it.
- `repro.sh`: run, assert the list is non-empty and contains an expected
  entry (e.g. an `encodings` module) and that a bare `/bin/true` run
  produces a much shorter list.

**Tools:** bpftrace `str()`, `uptr()`, `comm`; `/sys/kernel/tracing/events/syscalls/`
for the tracepoint alternative.

**At the defense, expect:** Why did `str(arg1)` come back empty before you
fixed it — what hardware feature is the kernel honoring? Your probe fires
per *call*: how would you count files opened *successfully*? (That is a
return-value question — your Wednesday classmates have one of those.)

---

## obs-kretprobe-hist-01 — Distribution, not anecdote *(Q2, Wednesday)*

Time `vfs_read` with an entry/return probe pair (`kprobe` +
`kretprobe`, timestamps correlated per-thread) and render the latency as an
**in-kernel histogram** (`hist()`), for a workload that reads a large file
twice: cold cache, then hot. You saw this collapse qualitatively in
batch 2's function graph; now quantify it — one histogram per pass, or one
bimodal histogram you decompose and defend.

**Required evidence**
- The histogram(s), with the workload and the cache-state control
  (`echo 3 > /proc/sys/vm/drop_caches` between passes, or argue an
  alternative).
- The probe program: how entry and return were correlated (per-tid map),
  and what `retval` was used for (at minimum: excluding failed reads).
- A paragraph on *why the aggregation happens in the kernel*: what would
  the same measurement cost if every event were streamed out instead —
  connect to batch 2's firehose argument.
- An honest overhead statement: what does probing every `vfs_read` on the
  system do to the numbers you are reporting?
- `repro.sh`: run both passes, assert the histogram output exists and the
  hot-pass median bucket is lower than the cold-pass one.

**Tools:** bpftrace `nsecs`, per-`tid` maps, `hist()`, `retval`;
`drop_caches` for the control. Mind your read size: reads smaller than the
readahead window mostly hit folios readahead already filled, and the cold
median collapses onto the hot one — either read in chunks at or above the
window (256 KiB works) or keep small reads and defend a tail statistic
instead of the median.

**At the defense, expect:** Point at the two modes — which kernel work
does each contain? Why correlate by `tid` and not by `pid`? Your probe
adds latency to the thing it measures: is the *shape* still trustworthy
when the *numbers* are not?

---

## obs-gdb-current-01 — Stop the world *(Q1, Wednesday)*

Boot the VM frozen under the gdbstub (`./run.sh -g`), attach gdb
(`scripts/gdb.sh` — it runs in the build container; no host gdb needed),
set a breakpoint on `do_sys_openat2`, and let the system boot into it.
From the **stopped kernel**, recover: which process is making the call
(`current` task's `comm` and `pid` — find them via the per-CPU current
task or a typed backtrace), the filename argument **read three ways** (the
typed parameter gdb shows, the raw register per the x86_64 calling
convention, and `x/s` on that register), and a 5-frame backtrace with
source lines.

Then answer the comparison question this whole batch builds to: name one
thing this debugger view gives you that no tracer in batches 1–3 could,
and one reason it is nonetheless the wrong tool for most of this course's
questions.

**Required evidence**
- The gdb transcript: breakpoint definition, the hit, the three
  filename reads agreeing with each other, the `comm`/`pid` recovery, the
  backtrace.
- The calling-convention explanation: why *that* register holds the
  second parameter.
- The second footgun, observed and explained: while you sit at the
  breakpoint, what happens to the guest's wall-clock time — and what does
  that imply for using breakpoints on timing-sensitive questions?
- `repro.sh` (host-side): boot with `-g`, drive `scripts/gdb.sh` in batch
  mode to the breakpoint, assert the typed argument prints.

**Tools:** `./run.sh -g`, `scripts/gdb.sh` (extra `-ex` args pass
through), `dist/vmlinux` symbols (KASLR is off — symbol addresses are
runtime addresses).

**At the defense, expect:** gdb printed `filename=0x... "/some/path"` with
type and contents — where did it get the *type* from, when the running
kernel binary has no such thing? Re-run with the breakpoint on
`__x64_sys_openat` instead — predict what changes in the backtrace. Why is
`current` not a global variable?

---

*Connection to what's next: you now hold every observation instrument the
course uses — static events, filters, function graphs, dynamic probes,
histograms, and the debugger. What you do not yet have is **triggers**:
workloads engineered to force a chosen kernel path on demand. That is
batch 4, the tool layer arrives with it, and the subsystem tour begins.*
