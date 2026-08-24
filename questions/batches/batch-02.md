# Batch 2 — Inside view: following the kernel, filtering at the source

*On the docket: Monday, week 2 (the questions have been public since before
week 1; this batch needs no assignment sheet — everyone does both). Defended: **Wednesday of week 3** — the Monday
holiday removes a session that week, so this batch is two
questions, **everyone does both**, and both are on Wednesday's docket. The
long window (nine days) is intentional: these go deeper than batch 1.
Still manual — which, as in batch 1, does not mean LLM-free
([course-design.md §10](../../docs/course-design.md)): no agent tooling
required, and every command yours to type, re-run, and explain, however you
learned it.*

*Report format as batch 1: `reports/batch-02/<question-id>/` with
`report.md` ([course-design.md §7](../../docs/course-design.md) fields in
prose), raw captures, and `repro.sh`. Budget ~3–4 focused hours per
question.*

*Batch 1 taught you to watch the kernel from outside — static events at the
syscall boundary, /proc after the fact. This batch upgrades you twice: see
**inside** a syscall (function_graph), and make the kernel **filter at the
source** instead of grepping the firehose afterwards. Both skills are the
daily workhorses of the subsystem tour that starts next week.*

---

## obs-funcgraph-01 — Anatomy of one `read()` *(Q1, Wednesday)*

Perform a single `read()` of a real file and capture, with the
`function_graph` tracer, the kernel-side **call tree of that one syscall**:
which functions ran, nested how, taking how long. Annotate the three or four
major stages you find (VFS entry → page-cache lookup → copy back to
userspace — your annotation, backed by source references). Then do the same
`read()` a second time in the same run and put the two graphs side by side:
a large part of the tree collapses. Name what disappeared, and why.

**Required evidence**
- Two trimmed call-graph excerpts (first read vs. repeat read), plus the
  full captures as files. An ungraphed dump of the whole system scores
  zero — show the filtering that isolated your one syscall
  (`set_graph_function`, PID filtering, depth limits are your friends;
  document what you used and why).
- Stage annotations: for each major stage, the top function's `file:line`
  in the pinned tree and one sentence on its job.
- Per-stage durations from the graph, **with an honest caveat**: are these
  numbers trustworthy, and what is distorting them?
- `repro.sh`: reproduce the capture and assert the entry function (e.g.
  `ksys_read`) and at least one stage function appear in the graph.

**Tools:** `/sys/kernel/tracing`: `current_tracer=function_graph`,
`set_graph_function`, `set_ftrace_pid`, `max_graph_depth`; or trace-cmd's
function_graph plugin. (Both verified working in the reference image.)
Not every kernel function can appear in the graph — only those listed in
`available_filter_functions`. If a stage you know is there (check the
source) never shows up, its time is hiding in the caller's self-time; say
so and cite the source line. And make sure the buffer you read *into* has
been touched before the traced read — otherwise the graph will faithfully
time your program's own page faults, which is worth staring at once (and
worth mentioning in your duration caveat) but is not the read path.

**At the defense, expect:** Why does your graph start at `ksys_read` rather
than "read"? What exactly collapsed on the second read — and where did the
data come from instead? Predict the graph's shape under `O_DIRECT`. Would
you trust these microsecond numbers in a paper — what would you do to
deserve trusting them?

---

## obs-tracepoint-01 — One fault, filtered at the source *(Q1, Wednesday)*

Write a program that `mmap`s an anonymous region at a known address and
touches **one byte** of it — the first touch takes a page fault. Capture
**exactly that fault and nothing else**, using the static tracepoint
`exceptions:page_fault_user` with an **in-kernel event filter** (written to
the event's `filter` file, matching on the fault `address`). Capturing
everything and grepping afterwards is explicitly not an answer — the point
is filtering at the source.

**Required evidence**
- The filter expression you installed, and why it can only match your
  region.
- The capture: the fault event(s), with the `address` field shown to fall
  inside your mapped region, tied to the page you touched.
- A **negative control**: the identical run without the touch — zero events
  captured.
- One paragraph on the difference between filtering in-kernel and grepping
  a full capture: what breaks with the firehose approach (buffer pressure,
  perturbation, lost events), and where your filter actually executes.
- `repro.sh`: run, assert captured event count ≥ 1 with all addresses in
  range; run the control, assert zero.

**Tools:** `/sys/kernel/tracing/events/exceptions/page_fault_user/`
(`enable`, `filter`, `format` — read `format` first: `address`, `ip`,
`error_code` are all filterable; verified working in the reference image).
`mmap` with a requested address keeps your filter expression simple. Check
`tracing_on` is `1` before you conclude anything — a leftover `0` from an
earlier session makes every run look like your negative control.

**At the defense, expect:** Where, in the code path of a fault, does your
filter run? Change the write to a *read* of the untouched page — does a
fault still fire, and what in `error_code` distinguishes it? You saw this
region's pages absent in batch 1's pagemap question — connect the two
pieces of evidence into one story. (That story continues in the `mm/` week.)

---

*Connection to what's next: Wednesday's anchor — the same session where you
defend these — introduces kprobes and bpftrace: dynamic probes you place
anywhere, where this batch used only the kernel's pre-built windows. Batch 3
puts those in your hands.*
