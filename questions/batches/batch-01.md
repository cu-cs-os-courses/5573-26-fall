# Batch 1 — First contact: observing a running kernel

*Released: Monday, week 1, in the last 15 minutes of class.
Defended: week 2 — **Monday: obs-ls-trace-01, obs-pagemap-01 · Wednesday:
obs-sched-switch-01, obs-syscall-count-01**. You are assigned two of the
four (assignment sheet distributed with this batch). All four are answerable
by hand in the reference VM — no agent tooling required. **Manual does not
mean LLM-free**: LLM help is welcome here as everywhere in this course
([course-design.md §10](../../docs/course-design.md)) — use it to
learn these tools faster. It means the commands must be *yours*: whoever
helped you write one, you can type it, re-run it, and explain it on stage.
That is exactly what the defense tests.*

*Report format (manual weeks): commit to your repo under
`reports/batch-01/<question-id>/` — a `report.md` following the evidence
contract in [course-design.md §7](../../docs/course-design.md) written as
prose (claim, evidence entries each with the command, a raw-output excerpt,
and your interpretation; limitations), your raw capture files in an
`evidence/` subdirectory, and a `repro.sh` that reproduces your key evidence
in one shot. **All three sit together in
[`worked-example/reports/vm-cow-01/`](../../worked-example/reports/vm-cow-01/)**, arranged
exactly as you must arrange yours — the report in
[`report.md`](../../worked-example/reports/vm-cow-01/report.md), the script in
[`repro.sh`](../../worked-example/reports/vm-cow-01/repro.sh), the captures in
[`evidence/`](../../worked-example/reports/vm-cow-01/evidence/); the table in
[`agent-starter/reports/README.md`](../../agent-starter/reports/README.md)
maps each one to what you commit, and
[`agent-starter/reports/repro-template.sh`](../../agent-starter/reports/repro-template.sh)
is a skeleton to copy so you only write the assertions. Read the `repro.sh`
model before you write yours: "it printed some output" is not a reproduction
— every claim in your report wants a line in the script that fails loudly
when it stops being true. (§7 renders the contract as JSON, and `tools/report-check` only reads
JSON; both are for batch 4 on, when your agent emits the report. Weeks 1–3 you
write prose and nothing validates it but you.) Budget: each question is sized
for roughly 2–4 focused hours.*

---

## obs-ls-trace-01 — What does `ls` ask the kernel for? *(Q1, Monday)*

Run `ls /etc` in the reference VM and capture every system call it makes,
using the kernel's own tracing (tracefs / trace-cmd), not a userspace
wrapper. From your capture, pick **three different syscalls**, and for each:
name it, find its kernel entry point in the pinned source tree, and say in
one sentence what `ls` needed it for.

**Required evidence**
- A trace capture filtered to the `ls` process (show how you isolated it
  from the rest of the system's noise — this is graded).
- For each of your three syscalls: the trace lines showing it, the
  `file:line` of its implementation in the pinned tree (e.g. the
  `SYSCALL_DEFINE` site), and the one-sentence purpose.
- `repro.sh` that re-captures the trace and greps out your three syscalls.

**Tools:** `trace-cmd record -e raw_syscalls` or
`/sys/kernel/tracing/events/syscalls/`; the source tree + grep/ctags.
raw_syscalls records syscall *numbers* only — decode them against the VM's
`asm/unistd_64.h`, or use the named events under `events/syscalls/`
instead. Your capture will begin with the tracer's own launch of `ls` (an
unmatched `sys_exit` and the execve chain) — recognizing and accounting
for that is part of reading the trace.

**At the defense, expect:** Why does `ls` open files with `openat` rather
than `open`? What is all the activity *before* your program's first line of
`main` runs? Re-run it on `ls -l` — predict first what changes.

---

## obs-pagemap-01 — Is that memory real? *(Q2, Monday)*

Write a tiny program that `malloc`s a few MB and *touches only half of it*.
Using `/proc/<pid>/maps` and `/proc/<pid>/pagemap`, reconstruct the
process's memory layout (text, heap, stack) and then prove, page by page,
which parts of the allocation are actually backed by physical memory — and
that the untouched half is not.

**Required evidence**
- An annotated excerpt of `maps` identifying text / heap (or the mmap'd
  region) / stack for *your* process.
- Decoded `pagemap` entries (the present bit, and PFNs where present) for
  pages in the touched and untouched halves — a small reader script counts
  as evidence tooling, include it.
- The before/after contrast: the same untouched page, absent; then touched,
  present.
- `repro.sh` asserting: touched pages present, untouched pages absent.

**Tools:** `/proc/<pid>/maps`, `/proc/<pid>/pagemap` (binary format — a few
lines of Python or C to decode; python3 and gcc are in the VM; you are root,
so PFNs are readable). One warning: this VM boots with transparent huge
pages `[always]` — if pages you never touched show up present, you have met
THP. `madvise(MADV_NOHUGEPAGE)` on the region (or `echo never` to
`/sys/kernel/mm/transparent_hugepage/enabled`) before drawing page-granular
conclusions; `AnonHugePages` in smaps tells you whether it happened.

**At the defense, expect:** What did `malloc` actually return, if not
memory? Where is the boundary between your two halves in pagemap, exactly —
and why is it page-aligned? What do you predict `free()` does to the
present bits?

---

## obs-sched-switch-01 — Catch a preemption in the act *(Q1, Wednesday)*

Using `sched:sched_switch` events, capture a moment where the kernel takes
the CPU **away** from a task that still wanted it — an involuntary
preemption, as opposed to a task blocking voluntarily. Show one concrete
switch: who was running, who came next, when, and how you know the
outgoing task did not give up the CPU willingly.

**Required evidence**
- The captured `sched_switch` lines for your chosen switch, with the
  `prev_state` field decoded — and a contrasting *voluntary* switch (a task
  going to sleep), also decoded.
- A workload of your design that makes involuntary preemption happen on
  demand rather than by luck (hint: more runnable hogs than CPUs), with a
  one-paragraph account of why it must preempt.
- `repro.sh`: run the workload, capture, and grep out at least one
  `prev_state=R` switch between your own tasks.

**Tools:** `trace-cmd record -e sched:sched_switch` (add
`sched:sched_wakeup` if it helps your story); `taskset`/`nproc` to control
placement. Note: plain `trace-cmd report` pretty-prints sched_switch and
hides the `prev_state=` fields — use `trace-cmd report -N` (and `-R` for
raw values) to see what this question asks you to grep.

**At the defense, expect:** What does `prev_state=R` literally mean in the
event? What decided *which* task came next? What would change if you gave
one hog a nicer nice value — predict, then run it.

---

## obs-syscall-count-01 — The five-line program that wasn't *(Q2, Wednesday)*

Write a C program whose entire `main` is one `write(1, "hi\n", 3)` and a
`return 0`. **Before measuring, write down your prediction: how many
syscalls will one run of this program make?** Then count the real number
with kernel-side tracing, list every syscall observed, and account for the
gap: which belong to your code, and which to the machinery that ran it?

**Required evidence**
- Your written prediction (leave it in the report — being wrong here is
  expected and costs nothing; unexplained wrongness does).
- The full syscall list for one run, kernel-side (not strace), with the
  count, grouped into: loader/startup, libc runtime, your program.
- One experiment that *changes* the count in a direction you predicted in
  advance — e.g. static vs. dynamic linking — with both counts shown.
- `repro.sh`: build, trace one run, emit the total count and the list.

**Tools:** `trace-cmd record -e raw_syscalls -F ./yourprog` traces exactly
the launched process (including the `execve` that launched it); `gcc` (and
`-static`) in the VM.

**At the defense, expect:** Pick any syscall from your "machinery" group —
what breaks if it fails? Why does the dynamic build `openat` things your
program never asked for? Your `write` went to a serial console — trace
where the bytes went *after* the syscall boundary, if you dare (that
thread ends in the course's later modules).

---

*Common trap for all four: evidence that shows the whole system instead of
your process. The kernel is noisy; isolating your signal (PID filters,
`-F`, comm filters) is not busywork — it is the first instrument skill this
course teaches, and the first thing questioned at a defense.*
