# Batch 8 — `kernel/irq/` `kernel/time/` `kernel/signal.c`: interrupted, on schedule

*Released: Monday, week 8. Defended: week 9 — **Monday: irq-tick-01,
sig-deliver-01 · Wednesday: time-sleep-01, time-mutation-01**. You are
assigned two of the four.*

*This batch carries the course's **second mutation question**. The
drill is batch 6's — short form: `bzImage-2026f-03` ships as release
asset `batch-08`; it is the pinned 6.6.87 plus exactly one private
modification **somewhere in this batch's subsystems** (`kernel/irq/`,
`kernel/time/`, `kernel/signal.c`). Boot it with
`KERNEL=path/to/bzImage-2026f-03 ./run.sh` or `KERNEL=... tools/vm
up`. Three classes, differential evidence, "it's broken" is never a
safe default, `uname -r` is identical on purpose.*

*Standing facts you already own that this batch leans on: HZ=1000 and the
burst arithmetic (batch 6), the exit-to-user work loop (batch 7),
`prev_state=R` on user-space preemption (batch 1), and TCG timing honesty —
counts and distributions, not single microseconds. Reports:
`reports/batch-08/<question-id>/`, [course-design.md
§7](../../docs/course-design.md) schema, `repro.sh`. Budget ~3–4 focused hours
per question.*

---

## irq-tick-01 — The heartbeat and the shove *(Q1, Monday)*

Batch 6 told you a contended hog gets preempted about every slice;
batch 7 showed you where returning-to-user work runs. This question
makes you trace the machinery between them as **one chain**, each link
with its own evidence. (a) **The heartbeat**: something fires ~1000
times per second per busy CPU on this kernel. Identify it at the
tracepoint level — which `timer:` event, expiring what function — and
show its per-CPU count over a fixed window twice: once with a hog
pinned to the CPU, once with that CPU idle. Explain the difference you
find (it is large, it has a name, and `/proc/interrupts`' LOC row
corroborates it — delta the counters, batch-1 discipline). (b) **The
payload**: cite the call chain from the expiring tick function down to
the scheduler's per-tick hook, file:line per hop — and identify the
line where, for a task that has run out of entitlement, the kernel
does *not* switch tasks but only **sets a flag**. (c) **The shove**:
with two hogs contending on one CPU, capture `sched:sched_switch` and
the tick expiry events together and show the involuntary switch-outs
ride the ticks; then state where the actual `schedule()` call runs
(you cited that loop last week). Negative control: the same capture
with one hog alone — ticks keep firing; who *doesn't* get switched
out, and why not.

**Required evidence**
- Busy-vs-idle per-CPU tick counts (tracepoint) + LOC deltas over the
  same windows, with the stopped-tick explanation.
- The cited chain, tick → scheduler hook → the flag-setting line, and
  the cited exit-path line where the switch actually happens.
- The correlated capture: involuntary hog switch-outs vs tick
  timestamps, plus the solo-hog control.
- `repro.sh`: assert the busy-CPU tick rate within a band you justify,
  idle-CPU rate ≪ busy, and ≥90% of contended involuntary switch-outs
  within a stated window of a tick expiry.

One measurement honesty note: don't be surprised when the busy-CPU
rate *undershoots* HZ noticeably — under TCG the tick handler can run
late, and its re-arm skips missed periods rather than replaying them
(the re-arm call in the tick function is worth reading). A justified
tolerance band is part of your methodology, not an apology.

**Tools:** `timer:hrtimer_expire_entry` (its `function` field is a
pointer — filter with `args->function == kaddr("...")`),
`/proc/interrupts`, `sched:sched_switch`, your batch-6 hog trigger,
`tools/ksrc view kernel/time/tick-sched.c kernel/time/timer.c
kernel/sched/core.c`.

**At the defense, expect:** Why set a flag instead of switching right
there in the interrupt? Your solo hog was never switched out — but was
`need_resched` ever set for it? (Check, don't guess.) The idle CPU's
tick stopped — what re-arms it, and what would break if nothing did?
`preempt=voluntary` is this kernel's config: where *else* could the
flag have been acted on, and why does user-return dominate here?

---

## sig-deliver-01 — The two timestamps of a signal *(Q1, Monday)*

"The kernel delivered SIGUSR1" is two events, in two processes, at two
times, and this question is the gap between them. Build a
sender/receiver pair (fork; receiver installs a handler). Produce:
(a) **generation**: the `signal:signal_generate` event for your kill,
with the field evidence that it fired in the **sender's** context —
and the source citation for where the pending bit is set and where the
just-flagged target gets woken or kicked; (b) **delivery**: the
`signal:signal_deliver` event in the **receiver's** context, with the
citation for the loop it runs in on the way back to user mode (batch 7
again) and the function that dequeues and decides; (c) the **pending
window**: the generate→deliver timestamp gap, measured over ≥100
kills, as a distribution — with the receiver in two states: mid-sleep
in a blocking syscall, and with the signal **blocked** via
`sigprocmask` for a controlled interval. In the blocked run, read the
parked bit out of `/proc/<pid>/status` *during* the window and show
delivery lands only after your unblock — and mind *which* status line
you read: `kill()` is a process-directed signal, so think about which
pending set it lands in before you conclude from a zero that nothing
is pending. Explain what ended the window
in each mode — what did the receiver have to *do* for delivery to
happen?

**Required evidence**
- Both tracepoint captures with PID fields interpreted (who ran the
  generate, who ran the deliver).
- Source cites: the pending-bit site, the wake/kick site, the
  return-to-user delivery loop, the dequeue site.
- The two gap distributions with the blocked-mode `SigPnd`/`ShdPnd`
  readback mid-window.
- `repro.sh`: unblocked mode — assert ≥100 deliver events and a median
  gap below a stated bound; blocked mode — assert the gap ≈ your
  chosen block interval and `SigPnd` shows the bit mid-window.

**Tools:** `signal:signal_generate`, `signal:signal_deliver` (both
have pid fields — filter in-kernel, and note your fork'd pair shares
one comm: join the two ends by pid, never by comm),
`/proc/<pid>/status`, a sender/receiver trigger you write, `tools/ksrc
grep send_signal kernel/signal.c`.

**At the defense, expect:** Your receiver was mid-`nanosleep` — walk
me from the sender's `kill()` return to the receiver's handler frame:
which process's kernel stack does each step run on? What does the
syscall the sleep was in *return*, and who saw it — strace the
receiver and reconcile with what libc showed. If the receiver had
been spinning in pure userspace on the other CPU instead — what forces
its kernel entry, and how fast? A second SIGUSR1 lands while the first
is still pending — one delivery or two, and where does the source say
so?

---

## time-sleep-01 — What a millisecond actually costs *(Q2, Wednesday)*

`usleep(2000)` does not sleep 2 ms, and every number in this course
that came out of a sleep-paced loop inherits the difference. Measure
it, then explain every microsecond of it. (a) The **oversleep
distribution**: N ≥ 1000 iterations of `clock_nanosleep` for a
parameterized request (measure 2 ms; spot-check one shorter, one
longer), reporting (actual − requested) as a histogram with median and
tail. (b) The **armed window**: while the loop runs, capture
`timer:hrtimer_start` for your PID and read the timer's `expires` and
`softexpires` fields — compute their difference and identify, with a
source cite, exactly which per-task attribute that number *is*, where
the sleep path reads it, and its default value. (c) The **knob
moved**: rerun (a) with the attribute changed from inside your trigger
(`prctl` — cite the constant) to 1 ns and to 5 ms. Before running,
predict *which of the two runs your noise floor can actually resolve*;
then show the distribution follows the attribute in the direction it
can, show `/proc/<pid>/timerslack_ns` agrees in both, and explain what
dominates the run where nothing visibly moved. (d) The **boundary**: name which timer subsystem served your
sleep (two live in this kernel — your (b) capture already proves which
one; say what the other is for and one API that uses it).

**Required evidence**
- The three distributions (default, 1 ns, 5 ms) with the arithmetic
  connecting median oversleep ≈ slack + wakeup latency.
- The tracepoint field readback with expires−softexpires computed and
  the source cite for the range-arming line.
- The prctl call in your trigger source + the proc readback.
- `repro.sh`: default run — assert median oversleep within a stated
  band; 5 ms run — assert the median moved by ≈ the slack delta.

**Tools:** `timer:hrtimer_start` / `timer:hrtimer_expire_entry`
(pid-filtered), `prctl(PR_SET_TIMERSLACK)`, `clock_gettime`
bracketing (write the trigger; keep it — you will want it again
within the week), `tools/ksrc view kernel/time/hrtimer.c`.

**At the defense, expect:** Why does slack exist at all — who wins
when wakeups coalesce, and what class of task sets it to zero? Your
1 ns run still oversleeps — decompose what's left (and say which part
TCG inflates). Would `poll()` with the same 2 ms timeout show the same
distribution — where does *its* slack come from? Predict: a hog
pinned to your sleeper's CPU — does the tail get better or worse, and
why might it get *better* on this kernel?

---

## time-mutation-01 — The second mutant *(Q3, Wednesday)*

The image `bzImage-2026f-03` differs from the pinned kernel by exactly
one private modification somewhere in `kernel/irq/`, `kernel/time/`,
or `kernel/signal.c`. Characterize it.

The contract is batch 6's: (a) the **differential experiment log** —
stock vs mutant, same triggers, same probes, including at least one
experiment that came back *unchanged* (what a mutation does **not**
touch is half the characterization — this subsystem trio offers three
natural directions to clear); (b) the **behavioral signature** — the
smallest reproducible difference, quantified with distributions, not
single runs; (c) the **mechanism hypothesis** — argued from behavior
to mechanism with the honesty section on what you cannot pin down
without source; (d) the **verdict** — name the guarantee(s) you
tested, show they hold or break, and place the mutation in one of the
three classes. One methodological note this time: if your signature
involves timing, your batch-6 obligations apply doubly — state what
TCG jitter could and could not produce, and design the experiment
whose effect size no jitter explains.

**Required evidence**
- The experiment matrix (ran / on which kernel / changed / unchanged —
  negative results are required content).
- The quantified signature with raw captures from both kernels.
- The hypothesis, argued; the verdict, argued from tested guarantees.
- `repro.sh`: takes the image path, runs against both kernels, asserts
  the signature on the mutant and its absence on stock.

**Tools:** everything you have — and note that this batch's other
three questions each built an instrument.

**At the defense, expect:** On-the-spot: "run your signature
experiment on this third image." Which of your experiments would have
caught a *correctness* mutation here, had it been one? If your
hypothesis names a quantity, predict the effect of doubling it — and
how you would check without source. What single user-visible program
behavior (no tracing) would a sharp-eyed sysadmin have noticed?

---

*Connection to what's next: interrupts, timers and signals all did
their work on the way into and out of a kernel you entered for free.
Batch 9 pays the toll: `read()` — path lookup, the page cache, and
what a file actually is to this kernel.*
