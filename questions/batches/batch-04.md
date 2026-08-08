# Batch 4 — `kernel/`: the process lifecycle (the subsystem tour begins)

*Released: Monday, week 4 — the same session as the thick-starter
walkthrough. Defended: week 5 — **Monday: proc-forktree-01,
proc-exec-maps-01 · Wednesday: proc-zombie-wait-01, proc-clone-flags-01**.
You are assigned two of the four.*

*Two things change this week. First, **triggers**: batches 1–3 handed you the
workload; from now on, designing the workload that forces the kernel path
deterministically is part of the question — and part of the grade. Second, the
**tool layer**: these questions are sized for a student driving the starter
workspace with an agent ([course-design.md §5](../../docs/course-design.md)).
Use any model you like — the evidence chain and the understanding you defend
are what is graded. Reports switch to the machine-checkable [course-design.md
§7](../../docs/course-design.md) schema: `reports/batch-04/<question-id>/` now
contains **`report.json`** (validate with `tools/report-check` before
committing), raw captures, and `repro.sh`. Budget ~3–4 focused hours per
question.*

*This subsystem is the gentlest trigger-writing week on the tour — every
trigger here is a handful of lines around `fork`, `exec`, and `wait`.
That is deliberate: learn the trigger discipline (deterministic, filtered
to your own pids, with a negative control) while the workloads are small.*

---

## proc-forktree-01 — Count the forks before you run them *(Q1, Monday)*

Every task on this system is created down one kernel path. Show it, then
use its tracepoint to audit a shell.

Part one: write one driver that creates a child four different ways —
`fork()`, `vfork()`, raw `clone()`, and `posix_spawn()` — and produce
kernel-stack evidence that all four converge on the same creation path
(`kernel_clone` → `copy_process`), citing `file:line` for where
`sched:sched_process_fork` fires and for why the child cannot have run
before that point.

Part two: take this compound command —
`out=$( (ls /etc | wc -l) & sleep 0.2 ); echo done $out` — **predict, in
writing, how many `sched_process_fork` events it emits under
`bash -c`**, then capture and reconstruct the full fork tree
(parent→child edges, annotated with what each node is). If your
prediction was wrong, the diff between prediction and tree is the most
valuable part of your report — explain every extra or missing node.

**Required evidence**
- Aggregated kernel stacks from a probe on the creation path, one per
  API, annotated at the converging frame.
- The written prediction (committed *as predicted*, not corrected), the
  captured fork tree, and the node-by-node reconciliation.
- Source citations: where the fork tracepoint fires and what has already
  happened to the child by then.
- `repro.sh`: run the shell trigger under tracing, assert the event
  count and at least the pipeline's edge structure.

**Tools:** `sched:sched_process_fork` (its `format` file tells you the
fields), `sched:sched_process_exec` to label nodes, bpftrace `kstack` on
a creation-path kprobe, `tools/ksrc` for citations. Two heads-ups: you
may find *fewer distinct stacks than APIs* — that is a finding, not a
bug; and if a stack frame's symbol name surprises you, remember kallsyms
answers by address, and two byte-identical syscall wrappers can be
folded into one symbol by the linker.

**At the defense, expect:** Which nodes of your tree would disappear if
the subshell used `exec`? Run the same command under `sh` (dash) —
predict the tree change first. Where exactly does `posix_spawn`'s
stack diverge from `fork`'s before they converge, and what does that
buy it? Your tracepoint fired in *whose* context — parent or child —
and how does your capture prove it?

---

## proc-exec-maps-01 — What exec actually replaces *(Q1, Monday)*

`execve` is routinely described as "replacing the process". Replace is
the right verb; *process* is the wrong noun. Design a trigger that
snapshots its own state — at minimum `/proc/self/maps` and its open fd
list — immediately before `execve`, into a program that snapshots the
same state immediately after. Present the two snapshots as a diff:
**everything mapped is gone; the task identity is not.**

Then delimit the replacement precisely, with one probed boundary on each
side: one fd opened with `O_CLOEXEC` and one without (which survives,
and where in the kernel is that decided?), and the kernel moment the old
address space dies — cite and probe the function that swaps the
`mm_struct`, and place `sched:sched_process_exec` on your timeline
relative to it.

Two speed bumps are planted here. First: when you go to probe the
swapping function, check `/proc/kallsyms` before you trust the probe —
you have seen this movie in the COW worked example, and citing the
source line while probing the nearest probeable ancestor is the honest
move. Second: your "everything is gone" diff assertion will not quite
hold — one line survives. Explaining what that page is and why it cannot
move is part of full credit.

**Required evidence**
- Before/after snapshots (raw files) and the annotated diff: what
  vanished, what survived (account for *every* surviving line), same
  pid throughout.
- The fd contrast (CLOEXEC vs. not) with the deciding kernel code cited.
- A trace tying `sched_process_exec` and your probe on the mm-swap
  function to one timeline of one exec.
- `repro.sh`: run the trigger, assert (a) no mapping of the old
  *program* survives the diff (and that what does survive is exactly
  what you claimed), (b) the non-CLOEXEC fd does, (c) the pid is
  unchanged.

**Tools:** `/proc/self/maps`, `/proc/self/fd`, `tools/ksrc grep exec_mmap`,
kprobes, `sched:sched_process_exec`.

**At the defense, expect:** Your heap landed at a different address after
exec — but this kernel boots with KASLR *off*; reconcile. Name two more
things that survive exec besides pid and fds, and how you would show one
of them. If the exec *fails* after the point of no return, what does the
kernel do with a task whose old program is already gone? What does the
`old_pid` field in `sched_process_exec` exist to express?

---

## proc-zombie-wait-01 — The funeral is scheduled by the parent *(Q1, Wednesday)*

Folklore says zombies leak memory. Show what a zombie actually is, and
who controls how long it exists.

Build a trigger whose child exits while the parent delays `waitpid` by a
commanded interval. While the child is a zombie, capture what remains of
it (`/proc/<pid>/status`, `smaps` — where did the memory go, and *when*
did it go, in the exit sequence?). Then put the three lifecycle
tracepoints — `sched_process_exit`, `sched_process_wait`,
`sched_process_free` — on one timeline and demonstrate that the
exit→free interval **tracks your parent's delay parameter**: the reaping
moment belongs to the parent, not the child.

Close with the negative control: one added line —
`signal(SIGCHLD, SIG_IGN)` — and the zombie stage vanishes. Show the
collapsed timeline, show what `waitpid` now returns, and cite the kernel
decision (the `autoreap` logic) that both behaviors fall out of.

**Required evidence**
- The zombie's remains: `status`/`smaps` captured during `Z`, with the
  exit-sequence citation for when the address space was released.
- Tracepoint timelines at ≥3 delay values showing exit→free tracking
  the delay (state your timing tolerance — this VM has jitter; choose
  delays that dwarf it).
- The `SIG_IGN` control: timeline, `waitpid` errno, and the cited
  `autoreap` decision point.
- `repro.sh`: both modes, asserting `Z` observed in one and never
  observable in the other, and the errno flip.

**Tools:** `sched:sched_process_{exit,wait,free}`, `/proc/<pid>/status`,
`tools/ksrc view kernel/exit.c`.

**At the defense, expect:** What, precisely, is still allocated for a
zombie — and which of those things is the scarce one? Your child was
killed by SIGKILL instead of exiting: predict the raw `wstatus` word
before running it. The parent dies *without* waiting — walk the orphan's
fate through the kernel's re-parenting choice (there is a prctl that
changes the answer; what is it for?). Why does the design put the free
on `wait` instead of on exit?

---

## proc-clone-flags-01 — One syscall, eight processes *(Q1, Wednesday)*

`fork` and `pthread_create` are the same syscall wearing different
flags. Write one trigger — a raw `clone()` caller taking its flag mask
from argv, whose child always performs the same three acts: `open` a
file, `chdir`, and store to a plain global variable — and run it under
masks that toggle **`CLONE_FILES`, `CLONE_FS`, and `CLONE_VM`**.

For each flag, report the behavioral flip the parent observes (does the
child's fd appear in the parent's `/proc/self/fd`? did the parent's cwd
move? did the store land?) and tie it to the single `if` in
`copy_process`'s resource-copy ladder that the flag controls — cite each
branch, and back one of them with a kernel-side probe that fires only on
the copy path.

Then explain the constraint ladder: try `CLONE_SIGHAND` without
`CLONE_VM`, report what the kernel says, and find the check that said
it. End with the thread question: which mask *is* a pthread, and show
one piece of `/proc` or trace evidence that a thread is a schedulable
task with its own tid inside a shared tgid.

**Required evidence**
- The flag-by-flag observation matrix (raw outputs per mask), each row
  tied to its cited branch in the copy ladder.
- The kernel-side probe distinguishing share from copy for one resource,
  with its firing evidence in both directions.
- The rejected-combination experiment: errno, and the cited validity
  check.
- The thread evidence: tid ≠ pid inside one tgid, from `/proc` or a
  scheduler tracepoint.
- `repro.sh`: run the mask matrix, assert each behavioral flip.

**Tools:** raw `clone(2)` (mind the child-stack argument), `/proc/self/fd`,
`/proc/<pid>/task/`, `tools/ksrc view kernel/fork.c`, kprobes.

**At the defense, expect:** Why must `CLONE_SIGHAND` imply `CLONE_VM` —
what would a signal handler even *mean* across separate address spaces?
Your `CLONE_VM`-off store didn't land — is that because fork copied the
page? (Careful: batch 5 will make you regret a lazy answer here.) Glibc's
`fork()` doesn't pass the mask you'd guess — what does it actually do
about `CLONE_CHILD_SETTID` and why? Which of your three probes would a
`vfork` child break, and why is that syscall's manpage so nervous?

---

*Connection to what's next: every child you made this week got its
parent's memory "copied" — and none of that copying actually moved a
page. Batch 5 opens `mm/` on exactly that lie: copy-on-write, demand
paging, and what `/proc/<pid>/pagemap` lets you prove about a page you
never touched.*
