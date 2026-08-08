# Batch 7 — `arch/x86/entry/`: how execution enters the kernel

*Released: Monday, week 7. Defended: week 8 — **Monday:
entry-path-01, entry-vdso-01 · Wednesday: entry-dispatch-01,
entry-tracecost-01**. You are assigned two of the four. No mutation
this week — batch 8 carries the next one.*

*Every trace you have taken since batch 1 ended its kernel stacks in
the same two frames: `do_syscall_64` and
`entry_SYSCALL_64_after_hwframe`. This week you climb down to them.
Two notes up front: first, this is the course's assembly week —
`tools/ksrc grep` searches `.S` files too, and the gdbstub
(batch 3) is the instrument of choice for code that runs before any
tracer can; second, several functions in this layer are `noinstr` for
reasons that are themselves worth explaining at a defense — when a
probe refuses, you know the drill by now. Reports:
`reports/batch-07/<question-id>/`,
[course-design.md §7](../../docs/course-design.md) schema, `repro.sh`. Budget
~3–4 focused hours per question.*

---

## entry-path-01 — Four hops from ring 3 *(Q1, Monday)*

Trace the full path of one `getpid()` from the `syscall` instruction
to the C function that computes the answer, with evidence at three
altitudes: (a) **where the hardware jumps**: find where the kernel
registers the entry point in the `LSTAR` MSR at boot (cite it), then
break on that entry point in the gdbstub and, sitting at the
breakpoint with a known caller, read the ABI off the registers —
which register holds the syscall number, which two did the *hardware*
overwrite (with what), and where are the six arguments; (b) **the
first instruction problem**: what does `swapgs` switch, and why can
almost nothing else run before it; (c) **the climb into C**: a kprobe
kernel stack on `__x64_sys_getpid` showing the complete ancestry, with
each frame cited to its source line — including what you learn when
you try to probe the middle frame directly.

**Required evidence**
- The LSTAR registration and entry-point cites (`.S` and the boot
  code); the gdb transcript with the register readings annotated
  against the ABI.
- The swapgs paragraph (what world does it switch into, one sentence
  on what would go wrong without it).
- The annotated kstack from the C end, plus the kallsyms/attach
  evidence for what sits between asm and the handler and why it
  refuses instrumentation.
- `repro.sh`: gdb batch-mode to the breakpoint asserting the NR
  register value for a known syscall; the kstack capture asserting
  both entry frames present.

**Tools:** `run.sh -g` + `scripts/gdb.sh` (batch 3), `tools/ksrc grep
... arch/x86/entry` (now searches `.S`), bpftrace `kstack`,
`/proc/kallsyms`.

**At the defense, expect:** At your breakpoint — is the kernel stack
even valid yet? What's in rsp? Why does the ABI document rcx and r11
as clobbered — show the hardware's hand. `int 0x80` and `sysenter`
still exist — where do *they* land, and does your getpid ever use
them? What does `noinstr` protect against here — what would a probe
in that window corrupt?

---

## entry-vdso-01 — The syscalls that never enter (except when they do) *(Q1, Monday)*

The manual says `clock_gettime(CLOCK_MONOTONIC)` is a vDSO fast call
that never enters the kernel. Write one trigger that performs
N=20000 calls each, in separate phases, of: `getpid()`,
`clock_gettime(CLOCK_MONOTONIC)`, and
`clock_gettime(CLOCK_MONOTONIC_COARSE)`. **Predict all three
`raw_syscalls:sys_enter` counts in writing — from the manual, before
measuring** (in-kernel filter by your pid — batch-2 discipline). Then
measure. On this VM, one of your three predictions will be badly
wrong.

Explaining the wrong one is the question. Your explanation must
connect: the `[vdso]` mapping (you watched exec replace it in
batch 4) and how libc finds it; the fact that the vDSO code *is*
being called (show it — `strace` sees syscalls, not calls; what
tool or reasoning shows the vDSO ran and then fell through?); what
this VM's **clocksource** is and how the vDSO learns it can or
cannot read that hardware from userspace; and why the COARSE clock
stays fast when the fine one doesn't — what, exactly, does each need
to *read*, and which of those reads can the kernel export as shared
read-only data?

**Required evidence**
- The three written predictions (committed as predicted) and the
  three measured counts, raw capture attached, filter shown.
- The `[vdso]` mapping + `AT_SYSINFO_EHDR` evidence, and the
  clocksource readback
  (`/sys/devices/system/clocksource/clocksource0/current_clocksource`).
- The mechanism paragraph: the vDSO's clock-mode decision, the
  fallthrough path to the real syscall, and the fine-vs-coarse
  boundary in terms of what data can be shared.
- `repro.sh`: all three phases; assert getpid ≈ N, fine-clock ≈ N
  (the fallback is real), coarse-clock ≪ N.

**Tools:** `raw_syscalls:sys_enter` with an in-kernel pid+NR filter,
`/proc/self/maps`, `ldd`, `LD_SHOW_AUXV=1`, `tools/ksrc grep vdso`.

**At the defense, expect:** Why can time be exported read-only but
`getpid` cannot — what, exactly, would go stale? Your fallback clocks
— trace *where* they re-enter (which NR shows up). `strace` your fast
loop: what does it show, and why is that itself evidence? What
happens to vDSO time during your batch-3 gdb freeze?

---

## entry-dispatch-01 — The bouncer and the guest list *(Q1, Wednesday)*

The textbook story says syscall dispatch is an indexed jump through
`sys_call_table`. On this kernel that story is half-true at best.
Locate the actual dispatch this build compiles (cite the code that
runs, and the comment on the table that no longer does); then probe
the boundary with a trigger that calls (a) one ordinary syscall, (b)
`syscall(999)`, and (c) `syscall(-1)`. For each: does the kernel get
*entered* (event evidence), what comes back (raw return value and
errno), and which code path produced that answer (cite the bound
check, the `default:` case, and what `array_index_nospec` is doing in
between — that last one has a story worth one paragraph: why did the
indexed-jump story die?).

**Required evidence**
- The dispatch-site citations: the switch, the table-is-vestigial
  comment, the bound check, the ni_syscall default.
- Per-call evidence: sys_enter/sys_exit raw events (NR and return
  value) for all three calls, decoded; userspace errno confirmation.
- The Spectre paragraph (what attack shape killed the table lookup).
- `repro.sh`: run the trigger, assert syscall(999) enters the kernel
  (event present) and returns ENOSYS while the valid call succeeds.

**Tools:** `raw_syscalls:sys_enter/sys_exit` + your batch-1 syscall
decoder (the guest's own `asm/unistd_64.h` is the table), `tools/ksrc view
arch/x86/entry/syscall_64.c arch/x86/entry/common.c`.

**At the defense, expect:** syscall(-1) vs syscall(999) — same path?
(Look at the unsigned conversion comment.) If you *added* a syscall
to this kernel, list every artifact that would need to change. The
table still exists and is exported — name something that still uses
it, or prove nothing does. Where would seccomp have intercepted your
999 — before or after the bound check?

---

## entry-tracecost-01 — The observer's bill *(Q2, Wednesday)*

Measure the cost of entering the kernel, then measure what happens to
that cost when someone is watching. Three timed loops of N `getpid()`
calls (report calls/second and ns/call with TCG-honest error bars —
counts over wall-clock windows, batch-6 discipline): (a) bare; (b)
under `strace` (tracing everything); (c) under `strace -e trace=none`
— **predict (c) before you run it**. Explain the mechanism behind
each gap: what does ptrace do to every syscall of a traced process —
where in the generic entry code does that work hang, how many extra
context switches does one traced syscall cost (prove the number with
batch-6 sched instruments, not the manual), and why does (c) land
where it lands?

Close with the course connection: this is the entry-layer version of
batch 2's firehose argument — one paragraph on what this implies for
*your own* measurement practice in this course.

**Required evidence**
- The three rates with methodology stated; the written prediction for
  (c) committed as predicted.
- The ptrace-stop arithmetic: sched-level evidence (switch counts
  between tracee and strace per syscall) that grounds the multiplier.
- Source citation for where syscall-entry tracework hooks
  (`kernel/entry/common.c`), and the mechanism paragraph.
- `repro.sh`: run (a) and (b), assert the slowdown factor exceeds a
  stated floor; run (c), assert it sits between (a) and (b) and
  closer to whichever your prediction argued.

**Tools:** a timed getpid loop (write it), `strace`,
`sched:sched_switch` counting (batch 6), `tools/ksrc grep
syscall_trace_enter kernel/entry`.

**At the defense, expect:** Where do strace's own getpid-loop numbers
come from — is strace itself syscalling while it watches? Would
`perf trace` (if it existed here) cost the same — what's structurally
different about a ring buffer vs a stop? Your (c) prediction was
wrong (most are): what did you learn about *which part* of ptrace is
expensive? seccomp filters also run at entry — same cost class or
not, and why?

---

*Connection to what's next: you now know the door. Batch 8 is about
being interrupted — the timer tick you saw preempt batch 6's hogs and
the signals that arrive, both of which do their real work on the exit
path you just mapped.*
