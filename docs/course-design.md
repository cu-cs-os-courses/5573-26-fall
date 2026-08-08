# KernelLens: Course Design Document

**Graduate Operating Systems — Agent-Driven Kernel Investigation**


---

## 1. Motivation

**The founding premise is an opportunity, not a defense.** Students will use
LLMs regardless of course policy. Rather than fencing that off, this course is
designed *around* it: give students an LLM as leverage, and use that leverage
to reach kernel content that a traditional course structurally cannot teach.
The end goal is unchanged — a working command of the Linux kernel — but the
ceiling moves.

### 1.1 What the leverage unlocks

Four things become teachable that were not before:

- **The real kernel, not a teaching kernel.** Traditional courses use xv6-class
  toys, or touch real Linux only through one narrow module project — because the
  entry fee (build systems, C idioms, debugger setup) consumes weeks of student
  time. With an LLM absorbing that mechanical cost, students stand in front of
  the pinned 6.6 tree in week one asking real questions, instead of reaching
  `fork` by week ten.
- **Breadth.** Genuinely entering four subsystems (VM, scheduling,
  syscalls/interrupts, filesystems) in one semester was impossible when each
  subsystem's experimental scaffolding cost two weeks to erect. Here the
  scaffolding *is* the student's agent tool layer, built once and reused;
  student time goes to what to ask, where to probe, and whether observed
  behavior is correct.
- **Experimental cadence.** The hypothesis → instrument → trigger → evidence
  loop shrinks from once-a-week to several-times-an-hour. The scientific method
  is only truly internalized when iteration is fast enough to feel like
  conversation with the kernel — that speed was never available in a manual
  course.
- **The maintainer's perspective.** "Given this kernel change, decide whether
  it is acceptable" is what kernel maintainers do daily — and was never
  assignable as coursework, because authoring, validating, and grading such
  questions was economically infeasible. With mutations generated and validated
  by tooling and examined in live defense (§6), it becomes a routine question
  type — arguably the most authentic exercise in the course.

**The durable take-home.** What students leave with is not a grade but an
instrument and a method, in three layers of decreasing perishability. The
*tool*: each student's agent repo is theirs (the course records only submodule
pointers), and its trigger and probe libraries remain usable against any
future kernel question — a production bug, an unfamiliar subsystem, a
performance investigation. The *method*: claims need evidence, evidence comes
from triggers plus probes, negative controls separate signal from noise — the
epistemology of interrogating any complex system one didn't write, kernels or
otherwise. And the *meta-skill*: knowing how to encode domain knowledge into
a tool layer that makes an LLM effective in a new domain — the first thing
they will do in every technical field they enter next. Models depreciate
fast; the tool layer's encoded kernel knowledge and the habit of building
instruments do not — which is why the course grades understanding and the
tool layer, and stays agnostic about which model a student runs (§6.5).

### 1.2 Why assessment must be rebuilt anyway

The same LLMs have undermined the traditional course's instruments:

- **Conceptual questions are free.** Any student can get a correct, well-written
  explanation of copy-on-write, RCU, or the CFS scheduler in seconds. Lecturing on
  these topics, and examining students on them, no longer measures anything.
- **Standard projects are free.** Classic projects (write a scheduler, a shell, a
  toy filesystem) appear in training data thousands of times. An LLM can produce a
  passing solution with minimal student involvement.

What LLMs *cannot* do cheaply is **answer evidence-backed questions about a specific
running kernel instance** — especially one that has been deliberately modified. A
claim like "COW is implemented in `wp_page_copy()`" is worthless without a trace
showing that function firing when a forked child writes to a shared page, on *this*
kernel, triggered by a workload the student designed. Producing that evidence
requires exactly the skills a graduate OS course should teach:

1. Knowing the kernel well enough to locate the relevant code path.
2. Designing a userspace workload that deterministically exercises that path.
3. Instrumenting the kernel (ftrace, eBPF, kprobes, gdb) to capture the behavior.
4. Interpreting raw evidence and connecting it back to source code.
5. Judging whether observed behavior is *correct* — which requires understanding
   what the subsystem is supposed to guarantee.

The two motivations converge on one design. Instead of listening to lectures and
writing a toy kernel component, **students run an investigation practice**: an
agent product of their choice driving a course-provided tool layer against a
real Linux kernel, with the student accountable for everything it produces
(§5).
The instructor acts as an **evaluator** — live, in the classroom: posing
questions that must be answered with verifiable, re-runnable evidence, and
interrogating the answers. The LLM is not the threat to assessment; it is the
*substrate* the course is built on — and the leverage of §1.1 only works if
its fulcrum sits in the student's head. The assessment design (§6) exists to
guarantee exactly that: machine-produced artifacts are free, but standing
behind them under live questioning is not.

One principle governs every design decision below: **the agent is the
instrument, not the subject.** The goal of the course remains a working command
of the Linux kernel. Directing an agent is the vehicle (and a genuinely useful
side skill), but every graded surface is constructed so that what it measures
is kernel understanding — where to place a probe, what workload forces a code
path, whether an observed behavior honors a subsystem's contract.

## 2. Learning objectives

By the end of the course, students can:

- **LO1 — Kernel internals.** Explain and empirically demonstrate the mechanisms of
  core Linux subsystems: virtual memory, process lifecycle and scheduling, system
  call and interrupt paths, filesystems and block I/O, and synchronization.
- **LO2 — Instrumentation.** Use the Linux observability stack (ftrace/trace-cmd,
  eBPF/bpftrace, kprobes/kretprobes/tracepoints, `/proc` and `/sys`
  interfaces, the QEMU gdbstub) to capture kernel behavior with precision.
- **LO3 — Workload design.** Construct minimal userspace programs that reliably and
  reproducibly trigger specific kernel code paths.
- **LO4 — Kernel modification.** Patch, rebuild, and boot a modified kernel; reason
  about whether an observed behavioral change is consistent with the subsystem's
  contract.
- **LO5 — Directing AI investigation.** Direct and verify an LLM agent
  investigating a system it can get wrong: encode method and domain knowledge
  into context and tools, judge machine-produced evidence, and catch
  confident errors — a directly industry-relevant skill.
- **LO6 — Scientific method.** Practice hypothesis → instrumentation → experiment →
  evidence → conclusion, with reproducibility as a hard requirement.

**Priority:** LO1–LO4 (kernel mastery) are the primary objectives; LO5–LO6 are
the vehicle. A student whose agent produces beautiful reports but who cannot
say *why* `wp_page_copy` is the right probe point has missed the course. The assessment
design (§6) enforces this ordering: questions are about the kernel, mutations
are in the kernel, and the defenses examine whether the understanding sits in
the student, not the model.

## 3. Course architecture overview

The course runs on a weekly evaluation cycle, not on lectures and exams:

```
  Instructor                                  Classroom (Mon & Wed)
  ┌──────────────────────┐  all 12 batches    ┌───────────────────────────────┐
  │ subsystem claim banks│ ─────────────────► │ every student: per-question       │
  │  → weekly question   │  before week 1     │ report due before class;       │
  │  batch, validated by │                    │ random draw picks presenter;   │
  │  the reference agent │                    │ defense under questioning;     │
  │  (+ mutation images) │                    │ live re-runs on demand         │
  └──────────────────────┘                    └───────────────┬───────────────┘
                                                              │ evidence
                                                              ▼
  Student side:   agent product of choice ◄─► course tool layer ◄─► QEMU VM
                  (self-funded, any model)    + the student's trigger/  (pinned
                                              probe libraries —      Linux 6.6)
                                              defended, not authored
```

The instructor never grades investigations offline by hand: understanding is
measured **live**, in the defense, where fabricated or borrowed work cannot
survive questioning and any evidence item can be re-run on the spot. The
reports collected before class are the paper trail and the spot-check
substrate, not the primary instrument.

The course infrastructure:

1. **Reference environment** (`env/`): QEMU + pinned Linux kernel (6.6 LTS) +
   Debian-based rootfs containing the tracing toolchain. Fully scripted and
   reproducible — students and instructor run the same image.
2. **Reference agent** — not a custom program, but the same workspace shape
   students get (tool layer + context + trigger/probe libraries), driven by
   an off-the-shelf agent product. Instructor-side only: it is the
   classroom demo vehicle, the mutation validator, and the instrument that
   calibrates every question batch (§6.5). Its stripped public form is the
   `agent-starter/` you clone.
3. **Question pipeline** — per-subsystem claim banks distilled into weekly
   batches, plus the private mutation images: the course's principal
   recurring workload, four validated questions per week (§6.1).
4. **Tool layer / starter** (`agent-starter/`): a model-agnostic library of
   VM-facing tools plus a report formatter — thick enough that a student is
   productive on day one with whatever agent product they bring (§5.4).
5. **Offering repos** — one per semester (e.g. `5573-26-fall`): the
   student-facing distribution plus the roster; each student's private repo
   is registered as a submodule *inside* the offering repo (§5.4).

## 4. The reference environment

**Decisions (rationale in parentheses):**

- **Kernel:** Linux 6.6.y LTS, exact version pinned per semester (reproducibility;
  LTS gets fixes without churn; 6.6 has mature BTF/eBPF support).
- **Virtualization:** QEMU system emulation, x86_64 primary (works on every
  student laptop incl. Apple Silicon via TCG; provides gdbstub for kernel
  debugging; a throttleable scratch disk for crash and queueing experiments).
  KVM/HVF acceleration
  used when host arch matches; correctness of the labs must not depend on it.
- **Rootfs:** Debian (bookworm), assembled inside a Docker container and
  packed into an ext4 image, containing bpftrace, trace-cmd, gcc (for in-VM
  workload compilation), python3, e2fsprogs, sshd, and the autorun/9p
  channel that `tools/vm` (§5.3) and the spot-replay tooling (§6.4) build
  on. *(Changed from Buildroot: bpftrace under Buildroot means a
  multi-hour, fragile LLVM source build; Debian ships everything as binary
  packages — the robust choice: binary packages, never source builds.)* The
  kernel and rootfs are **built on the student's own machine** by the
  scripts in `env/` (a one-time ~30–60 min cost, paid before week 1); they
  run inside a Docker container so they work identically on macOS and Linux
  hosts. Mutation kernels are the exception — those ship prebuilt, since
  students must never see their source. **These are the only supported
  host platforms — the syllabus states macOS/Linux only; Windows, including
  WSL, is unsupported** (stated in the pre-semester email so students can
  raise it before the semester).
- **Kernel config:** `CONFIG_DEBUG_INFO_BTF=y`, ftrace, kprobes, tracepoints,
  eBPF JIT, `/proc/kpageflags` + pagemap enabled. Lock debugging (lockdep,
  LOCK_STAT) and the sanitizers (KASAN, KCSAN) are **off** — they change the
  timing the course measures, and their absence is itself a teaching point
  (§8, batch 12). Config fragment version-controlled in `env/`.
- **Build caching:** the kernel tree and its objects live in a persistent
  Docker volume, so an incremental rebuild after a one-line
  kernel patch rebuilds in minutes, not an hour. First full build is a Week-1
  lab exercise.

**Non-goals:** real-hardware deployment, distro kernels, container-based
"kernels" (no actual kernel isolation), architectures beyond x86_64/arm64.

## 5. The student's work

### 5.1 Responsibility, not authorship

Earlier drafts said students would "build" an agent and its trigger/probe
libraries, and defended the course against prompt engineering by grading that
tool layer instead of the LLM's prose. That premise is obsolete: a
subscription agent product driving the course tool layer can write the
triggers, the probes, and the verification scripts itself. Whether a student
personally authored a bpftrace script is unverifiable — and, like "did you
use an LLM" (§1.2, §10), the wrong question. The artifacts are now free; the
understanding is not.

The course therefore models the student not as an *author* but as the
**responsible party** — the role a maintainer has toward a patch, or a PI
toward a lab's results: the work need not be done by your hands, but every
line of it is yours to answer for. Four kinds of work cannot be delegated:

- **Judgment during the investigation.** The model's output is
  plausible-looking; the kernel's feedback is ground truth. Probes that never
  fire (the target function was inlined), counts that come out wrong,
  triggers that fire only sometimes — models are routinely confident and
  wrong at exactly these junctures, and noticing that the evidence does not
  actually support the claim is the student's job. Quantitative and mutation
  questions on a pinned kernel guarantee such junctures keep occurring.
- **Internalization to defense depth.** The bulk of the weekly workload. An
  investigation the agent completes in minutes takes hours to digest
  critically: why this probe point, how the number would change under a
  different config, which link in the evidence chain is weakest. Every student
  must carry both assigned questions each week to the depth where
  counterfactual questioning (§6.1) is survivable. The course's theory of learning is **learning by
  interrogation**: the model absorbs the mechanical cost of investigation;
  the understanding cost is undiminished — and understanding was the goal
  all along (LO1–LO4).
- **Accountability for the toolkit.** Who wrote a probe is irrelevant; being
  unable to say why it attaches where it does is disqualifying. That
  accountability is enforced live in every defense, and in the final
  report's design section, defended one-on-one at the final interview
  (§6.6).
- **The manual foundation (weeks 1–3).** The only work required to be done
  by hand — and the reframing makes it more necessary, not less: a student
  who cannot verify by hand cannot tell when the model is wrong.

### 5.2 The toolkit (what accumulates in the student repo)

Authorship aside, each student's repository must accumulate a working
investigation toolkit: it is the scaffolding every defense stands on, the
subject of the final report's design section, and the durable take-home of §1.1. Its parts,
each documented well enough to defend:

- **Trigger library:** parameterized userspace workloads, each documented with
  the kernel path it exercises and *why* it triggers deterministically (e.g.,
  "fork, then write one byte into a private anonymous page → forces
  `handle_mm_fault` → `do_wp_page` → `wp_page_copy`").
- **Observation library:** probe scripts (bpftrace programs, ftrace configs,
  gdb command files) with documented attach points and expected signal.
- **Evidence pipeline:** how raw tool output becomes structured evidence in the
  report schema (§7), including the repro script that an on-the-spot re-run or
  spot replay executes (§6.4).
- **Self-verification:** checks that run before a report is written — confirm
  the probe actually fired, confirm PID filtering worked, negative controls.
  The part of the toolkit that protects the student from their own model.
- **Context layer:** the encoding of the course's method into the student's
  harness — instructions, skills/commands, tool wiring — so the agent
  investigates the way §9 does instead of improvising. This is the
  meta-skill of §1.1 in its current form.

The required capability surface the toolkit must cover:

| Category | Capability | Example implementations |
|---|---|---|
| Trigger | compile & run workloads in the VM, with PID/timing coordination | in-VM gcc + `tools/vm push`/`sh` |
| Trace | dynamic probes, static tracepoints, function graphs | bpftrace, trace-cmd, ftrace |
| Inspect | task/memory state of live system | /proc/[pid]/{pagemap,smaps,status}, /proc/vmstat, /sys |
| Debug | breakpoints, memory/register reads on the stopped kernel | QEMU gdbstub + gdb scripts |
| Source | search & read pinned kernel source; map symbol → file:line | local source tree + ctags/grep |
| Modify | apply patch, rebuild, reboot VM, A/B compare behavior | `make src` + incremental build + `KERNEL=` boot |

Students choose their own agent harness — a commercial agentic product (e.g.
Claude Code under a personal subscription), an agent SDK, or a raw API loop;
the expectation is that most students will drive the course tool layer from a
subscription product they already pay for (§6.5). The harness is not graded;
the tool design is.

### 5.3 Agent–VM boundary

The agent process runs on the host; the kernel under study runs in the VM. The
starter's `tools/vm` owns that boundary: it boots the guest headless, installs
its own ssh key through a 9p share on first boot, and runs every guest command
over ssh on a forwarded port. This keeps the boundary
honest: every observation the agent makes must flow through a loggable channel,
which is also what makes on-demand re-runs and spot replay possible.

### 5.4 Repository architecture: three layers

- **The instructor's working repository — private.** It holds the material
  this course cannot show you and stay honest: the mutation patches, the
  answer keys behind every question batch, and the instructor's own
  investigation workspace. You never need it.
- **The offering repo — this one, rebuilt each semester.** Student-safe
  material is copied in on the course's cadence: the environment, the
  starter workspace, the worked example, the schedule and **all twelve
  question batches** before week 1; then, on each batch's Monday, its
  per-student assignments and — where the batch calls for one — its
  mutation kernel image as a release asset. Copies rather than nested
  submodules, so publication is always a deliberate act.

- **Per-student private repos**, registered as submodules *of the offering
  repo*: each student's toolkit and reports. Repos are private — students
  cannot see each other's (the offering repo records only pointers); the
  instructor holds access to all.

With grading live (§6), the student repo is not an evaluation pipeline — it
serves three quieter purposes:

- **Weekly reports.** Each question's report (§7 schema, rendered Markdown
  alongside) is committed to the student repo under `reports/` before the class
  session in which that question may be drawn. The commit timestamp is the
  deadline mechanism; course tooling pulls all student repos before each session
  and lists who has submitted what.
- **Audit.** The instructor can always inspect exactly what produced a
  given report — or spot-replay any repro script against a clean
  environment; the final report's design section (§6.6) is defended
  against the repo as it actually is.
- **Archival.** A final submodule pin at semester end freezes each student's work
  for records — and for the student to take with them (§1.1).

There is no `run`/`agent.yaml` contract and no batch driver: nothing in the
course invokes a student's agent programmatically. Students drive their own
agents — in studio, at home, and on stage.

The **thick starter** (`agent-starter/`) is what makes this workable from week
one: it ships the entire plumbing layer — VM control (boot, run, copy in and
out, crash), pinned-source search, and report validation — as model-agnostic
command-line tools that
any harness can drive. Effectively the reference agent minus its trigger/probe
libraries. What accumulates all semester is the knowledge layer on top —
triggers, probes, verification, context (§5.2) — the student's accountability
surface, growing week by week as the questions demand it.

## 6. Assessment design

### 6.1 The weekly cycle

Assessment is one repeated mechanism, not a set of instruments:

1. **Publish.** All twelve batches — **four questions** each, drawn from that
   week's subsystem claim bank (§8) and validated by the reference agent
   (§6.5) — are published before week 1. Because the questions carry no
   secret, lead time costs nothing to give away, and a student who can see
   the whole semester can plan around it; §6.4's final interview, not batch
   timing, is what carries the unseen assessment. What still moves weekly is
   the **docket**: each Monday one batch opens, two of its questions defended
   the following Monday and two the following Wednesday. Two things ship with
   the docket rather than up front, neither for secrecy: the per-student
   assignments (below — they need a roster that add/drop is still moving) and
   a mutation batch's prebuilt kernel image, which ships with the question it
   serves. Not a secret either: the mutation drill (§6.3) tells students
   outright that they may take the image apart, and that binary archaeology
   answers a different question than the defense asks.
2. **Investigate.** The instructor **assigns each student two of the four**
   (published with the docket; a simple rotation keeps every question's pool
   at ~5 students, mixes question types per student, and lands every student
   on a mutation question several times across the semester). The student
   investigates their two with their own agent and tools, committing a
   per-question report (§7) before the session in which that question is
   scheduled. Coverage of the two questions not assigned comes from the
   stage, not the terminal: watching a peer defend a question you did not
   run, and questioning them, is the format's built-in breadth.
3. **Defend.** In class, for each question on the day's docket, the presenting
   student is **drawn at random from those who submitted a report on it**
   (the instructor may also pick). The student walks the class through their
   evidence chain, then defends it: students who prepared the same question
   open the questioning — they ran it and know exactly where it is hard —
   then the floor, then the instructor closes. The instructor may point at
   any evidence item in the student's report and have it re-run on the
   spot — the student's environment is already set up, so a re-run costs a
   minute and settles the argument.

The random draw is the load-bearing element: any of a question's ~5 assigned
students may be called, so every report must be written to presentation
depth — and the two-of-four assignment keeps that depth affordable. Advance publication
is thereby a feature, not a leak — and the provenance of
the work needs no policing, because the defense measures what is in the
student's head, not what is in the report. A student whose frontier model did the
whole investigation autonomously still had to internalize it to survive the
stage; a student that cannot answer "why is this the right probe point?" is
exposed in the first minute, whatever its report looks like.

### 6.2 Question types

Every question falls into one of four types, escalating in what they demand;
a weekly batch mixes types:

- **Q1 — Mechanism.** "How does this kernel implement copy-on-write?" Requires:
  source localization + trigger + trace evidence tying source to runtime.
- **Q2 — Quantitative.** "For this given workload, how many minor page faults does
  the child take, and why that number?" Requires precise measurement and a
  mechanistic explanation of the count. Hard to answer from training data because
  the number depends on the workload and kernel config.
- **Q3 — Mutation judgment.** "This kernel image has been modified somewhere in
  the memory subsystem. Characterize the change in behavior and state whether the
  modified kernel is still correct." The most authentic exercise in the course
  (§6.3).
- **Q4 — Differential/why.** "Why does workload A run 3× slower on kernel B than
  kernel A?" Requires comparative experiments and causal narrowing.

Weeks 1–3 carry deliberately small Q1-type questions answerable **by hand**
with ftrace/bpftrace — the manual-first principle (§8) executed through the
same weekly format. From week 4 the batches cross the threshold where a tool
layer pays for itself, and the agent becomes a practical necessity rather
than a mandate.

### 6.3 Mutation-based questions

The instructor maintains a **private set of kernel patches** ("mutations"), new
each semester, distributed to students only as prebuilt bootable images. Each
mutation must be: bootable, localized to the subsystem under test, and behaviorally
consequential (observable through the course toolchain). Three mutation classes,
mixed so that students cannot pattern-match:

- **Correctness-breaking (subtle):** e.g., skip write-protecting PTEs in `fork()`
  → child writes silently corrupt the parent; off-by-one in refcount check →
  unnecessary copies or premature sharing. Expected verdict: *incorrect*, with
  evidence of the violated guarantee.
- **Performance-degrading (semantics-preserving):** e.g., always copy on fork
  (disable COW entirely). Expected verdict: *correct but with quantified cost*.
- **Benign refactor:** behavior-identical restructuring. Expected verdict:
  *no observable behavioral change* — this class exists so "it's broken" is never
  a safe default answer.

Because mutations are generated fresh and never published, the answers exist in
no training corpus. Mutation questions appear regularly in the weekly batches
and dominate the final interview (§6.4). They are also the course's most
authentic exercise: "given a kernel change, determine whether it is acceptable"
is precisely what kernel maintainers do.

### 6.4 Grading protocol

Four graded surfaces replace the earlier gates-and-batch-scoring design:

1. **Weekly reports (two per student per week).** Checked automatically for
   format and completeness; an LLM-judge pass scores evidence–claim linkage as
   a first cut; the instructor spot-audits a sample per student every few weeks plus
   anything the judge flags or the stage contradicts. A report whose evidence
   fails a live or spot re-run scores zero for that question.
2. **Defenses (random-draw, §6.1).** Rubric: does the evidence entail the
   claim; causal completeness; negative controls; quantitative precision;
   conduct under questioning — including on-the-spot re-runs and prediction
   twists ("change `MAP_PRIVATE` to `MAP_SHARED`: what will happen? run it").
   The old evidence-supports-claim and depth gates live on here, applied in
   person.
3. **Participation.** Audience questioning earns credit; the students who
   prepared the same question open each defense (§6.1).
4. **Final interview (the last three class sessions, not finals week).**
   The final runs in class time — Mon/Wed/Mon of the last two teaching
   weeks, 3–4 individual interviews per 75-minute session, ~20 minutes per
   student. Each student receives a **fresh, never-published mutation** 48
   hours before their own slot, investigates it with their own toolkit, then
   presents and defends it one-on-one, including a live twist variant. Before
   the slot the student commits a **final report**: the mutation evidence in
   the §7 schema, plus a **design section** describing and justifying the
   toolkit — trigger and observation libraries, evidence pipeline,
   self-verification (§5.2) — which the interview may probe. The
   semester's only fully unseen assessment — it exists precisely because
   every other question was published before the semester began.

### 6.5 Model and cost policy

**There is no model cap.** Earlier drafts capped graded runs at a Sonnet-class
tier so that an autonomous evaluator would measure the student's tool layer
rather than the model. Live defense makes the cap pointless and unenforceable
at once: pointless because the graded object is now the student's
understanding, which no model can carry onto the stage; unenforceable because
students run their agents on their own machines and accounts. A rule that
cannot be checked only penalizes the honest — and it would contradict the
course premise (§1) that LLM leverage is designed around, not fenced off.

- **Students choose and fund their own model access.** The recommended path is
  a subscription agent product (flat monthly cost, no billing surprises)
  driving the course tool layer. Expected cost is on the order of a textbook
  (≈ $20–25/month for the semester), stated in the syllabus before
  registration; genuine hardship is handled case-by-case by the instructor
  (free tiers, educational credits) — no mechanism needed.
- **Every question batch is calibrated on both sides before release.**
  *Floor:* the reference agent, configured with the recommended baseline
  subscription tier (Fall 2026: Claude Opus 4.6 / GPT-5.5 class or better,
  the tier the syllabus names), must solve every question — so money buys convenience,
  never the passing line. *Ceiling:* a strong model given only a shell and
  **no VM access** must fail — if a question can be answered without touching
  the pinned kernel, it is a conceptual question that an LLM answers for free
  (§1.2), and it goes back to the shop.
- **The LLM judge for report scoring runs on a capable model** (judge volume
  is one pass per report; cost negligible), with a refusal fallback so a
  classifier false-positive on kernel-mutation content cannot corrupt scores.

### 6.6 Semester grade composition

| Component | Weight | Notes |
|---|---|---|
| Weekly reports (cumulative) | 25% | two per week (instructor-assigned from the batch's four, §6.1); auto-checked + LLM-judge first pass + instructor spot-audit (§6.4) |
| Defenses (4–5 per student) | 35% | random-draw within each question's preparers; §6.4 rubric; each student's lowest defense is dropped |
| Participation | 10% | audience questioning + studio engagement |
| Final report | 10% | the final-mutation report (§7 schema) plus a **design section** over the student's own toolkit — tool interface, evidence pipeline, self-verification; graded on the student's ability to defend its instrument choices, not on authorship or artifact polish (§5.1) |
| Final interview | 20% | fresh per-student mutation, 48 h lead, ~20 min one-on-one in the last three class sessions (§6.4); probes the final report, design section included |

The distribution is deliberately flat across the semester: with 4–5 defenses
per student plus weekly reports, no single performance is decisive, and the final
is a capstone rather than a cliff. One expectation to hold openly: as agent
products improve, report scores will compress toward the top — the reports
function as the entry ticket to the draw and as the audit trail, while the
discriminating weight sits in the defenses and the final interview.

## 7. Report schema (evidence contract)

Every weekly report is one document per question, carrying the fields below.

**Two renderings, one contract.** Batches 1–3 are answered by hand, and the
hand-in is `report.md` — these fields as prose, no JSON, nothing to validate.
From batch 4 the agent emits `report.json` in the shape given here, and
`tools/report-check` enforces its structure mechanically. The JSON is not a
stricter standard, only a machine-readable one: the same claim, the same
evidence entries, the same repro assertions. The worked example is written
both ways from the same run — [prose](../examples/cow/answer/vm-cow-01.md),
[structured](../examples/cow/answer/vm-cow-01.json) — and reading them side
by side is the cheapest way to see that the format is not the point.

The structured rendering:

```json
{
  "question_id": "vm-cow-01",
  "claim": "COW is implemented via write-protected shared PTEs resolved in do_wp_page().",
  "confidence": "high",
  "evidence": [
    {
      "kind": "trace",
      "tool": "bpftrace",
      "command": "bpftrace -e 'kprobe:do_wp_page /pid == $CHILD/ { printf(...) }'",
      "output_excerpt": "do_wp_page fired: pid=142 addr=0x7f3a...",
      "interpretation": "The probe fires exactly once, at the child's first write to the shared page. (The copy itself happens in wp_page_copy, which this build INLINES into do_wp_page — no kallsyms entry, nothing to attach to. Probing the caller and letting the pagemap evidence below carry the copy claim is the honest move, and the kind of thing you will find out the hard way at least once.)"
    },
    {
      "kind": "state",
      "tool": "pagemap",
      "command": "read /proc/$PID/pagemap at $ADDR before and after write",
      "output_excerpt": "before: parent PFN 0x1a2b == child PFN 0x1a2b; after: child PFN 0x3c4d",
      "interpretation": "Physical page shared before the write, distinct after — the copy happened."
    },
    {
      "kind": "source",
      "ref": "mm/memory.c:3354",
      "symbol": "do_wp_page",
      "interpretation": "Resolves the write-protect fault; allocates the new page (inlined wp_page_copy) and re-maps the faulting PTE read-write."
    }
  ],
  "repro": {
    "script": "repro/vm-cow-01.sh",
    "expected": [
      "probe do_wp_page fires >=1 time under child PID",
      "child PFN changes across the write; parent PFN does not"
    ],
    "tolerance": "exact"
  },
  "limitations": "THP disabled in this config; with THP the path differs (do_huge_pmd_wp_page)."
}
```

Design principles: every `evidence` entry carries the command that produced it
(re-runnable), an excerpt of *raw* output (auditable), and an interpretation
(gradeable). `repro.expected` is a machine-checkable assertion list — this is
what an on-the-spot re-run or a spot replay executes (§6.4).

## 8. The subsystem tour and question-bank outline

Weeks 1–3 build foundations by hand, through the same weekly question format
(§6.2). Batches 4–12 then tour **nine kernel subsystems, one per week,
classified by source-tree directory** — each subsystem has its own claim
bank (instructor-side) from which its week's four
questions are generated. The ordering tells a story: process → memory →
scheduling are three mutually explanatory foundations; entry →
interrupts/signals cover how the kernel gets entered; VFS → ext4 → block
walk one I/O path top to bottom; synchronization closes. The final
interview replaces the last three class sessions (§6.4). The full calendar
lives in [schedule.md](schedule.md).

**Weeks 1–3 — Foundations (agent optional, questions hand-answerable).**
Environment bring-up; build and boot the kernel; small observability questions
answered with ftrace, bpftrace, gdbstub by hand ([batch 1](../questions/batches/batch-01.md)).
The thick starter is distributed in week 1 so students can begin driving it
as they ramp. *Rationale: students must be able to do by hand what their
agent will automate — otherwise they cannot debug the agent's mistakes.*

**Batch 4 — `kernel/`: process lifecycle.** fork-tree evidence; what `exec`
actually replaces (maps before/after); zombies and `wait`; clone flags as
behavioral switches. The gentlest trigger-writing week — that is why the
tour starts here. Mutation targets: `kernel/fork.c`, exit/reaping paths.

**Batch 5 — `mm/`: virtual memory.** COW (worked example, §9); demand paging
vs. `MAP_POPULATE`; page-table walks via pagemap; what
`madvise(MADV_DONTNEED)` actually does. Mutation targets: `mm/memory.c`,
`mm/mmap.c` — the §9 mutation variant is the W6 walkthrough demo.

**Batch 6 — `kernel/sched/`: the scheduler.** EEVDF picking decisions ("why
did task A run before B — show the vruntime/deadline evidence"); wake-up
paths; context-switch cost measured honestly. Carries the first mutation
question. Targets: `kernel/sched/fair.c`, `kernel/sched/core.c`.

**Batch 7 — `arch/x86/entry/` + `kernel/entry/`: syscall entry.** vDSO vs.
trap (which "syscalls" never enter the kernel at all); the path from the
`syscall` instruction to a `SYSCALL_DEFINE` body; dispatch. Mutation
targets chosen conservatively — the image must boot.

**Batch 8 — `kernel/irq/`, `kernel/time/`, `kernel/signal.c`: interrupts,
timers, signals.** Timer interrupt → `need_resched` → preemption as one
traced chain; hrtimers; when exactly a signal is delivered
(return-to-user evidence). Mutation.

**Batch 9 — `fs/` + `mm/filemap.c`: VFS & the page cache.** Path lookup
(dcache hit vs. miss); a `read()`'s journey through the page cache;
readahead observed; dirty pages and what triggers writeback.

**Batch 10 — `fs/ext4/` + `fs/jbd2/`: a real filesystem.** `fsync` traced
down to the bio; journal replay after a crash (QEMU snapshot + kill);
ordered vs. journaled data modes. Mutation targets: drop a barrier, reorder
journal steps — does crash consistency still hold?

**Batch 11 — `block/`: the block layer.** A bio's life from page cache to
virtual disk; request merging; the I/O scheduler's observable decisions;
writeback throttling.

**Batch 12 — `kernel/locking/` + RCU: synchronization.** Lock contention
made visible under a designed adversarial workload; an RCU grace period
demonstrated as a measurable duration; and the toolbox map — which
synchronization oracles this kernel does *not* carry (lockdep, LOCK_STAT,
KCSAN) and what each would and would not have caught. Mutation: remove a lock on a
well-chosen path — with the standing caution that race evidence is
nondeterministic, so this mutation must be validated
observable-under-stress before release — with a workload, an invariant and
a trial count, since this kernel ships no sanitizer to lean on.

**Out of scope by design:** `net/` (belongs to the networking course),
`drivers/`, and arch internals beyond the entry path.

Each subsystem's batch is four questions generated from its claim bank; the
final interview draws structurally similar but never-published mutations.

## 9. Worked example: the COW question end-to-end

**The question:** *"How does this kernel implement copy-on-write for forked
processes? Support every claim with runtime evidence."*

A full-credit investigation, as the agent should perform it:

1. **Source localization.** Search the tree: `fork` → `copy_process` →
   `copy_mm` → `dup_mmap` → `copy_page_range`, which write-protects PTEs of
   private writable mappings. The fault side: `handle_mm_fault` → `do_wp_page` →
   `wp_page_copy` (`mm/memory.c`). Cite file:line from the pinned tree.
2. **Hypothesis.** After fork, parent and child PTEs map the same PFN read-only;
   the first write by either triggers a write-protect fault; `wp_page_copy`
   allocates a fresh page for the writer; the other process keeps the original.
3. **Trigger design.** C workload: allocate one private anonymous page, write a
   sentinel, `fork()`; child reads `/proc/self/pagemap` (PFN + flags), writes one
   byte, reads pagemap again; parent does the same reads; both report minor-fault
   counters from `/proc/self/stat`.
4. **Instrumentation.** `bpftrace` kprobe on `wp_page_copy` filtered to the
   workload PIDs, printing pid, faulting address, and kernel stack. Optionally an
   ftrace function-graph of `handle_mm_fault` for the same window.
5. **Run + evidence.** Probe fires exactly once, for the child, at the write
   address, with `do_wp_page` on the stack. Pagemap shows identical PFNs before
   the write, divergent after; parent PFN unchanged. Child minor-fault counter
   increments by exactly one.
6. **Negative control.** A `MAP_SHARED` mapping: probe does not fire on write
   (no COW), PFNs stay shared. This distinguishes COW from generic fault noise.
7. **Structured report** per §7, with a repro script asserting: probe count == 1,
   child PFN changed, parent PFN stable, shared-mapping control silent.

**Mutation variant (Q3):** instructor's kernel skips `pte_wrprotect` in
`copy_page_range` for private mappings. The same instruments now show:
probe never fires, PFNs stay shared after the child's write, and the parent's
sentinel is corrupted. Verdict: incorrect — fork's memory-isolation contract is
violated; evidence: the parent-side value change.

## 10. LLM policy and academic integrity

- **LLM use is unrestricted and expected.** Students use LLMs to write their
  agent, their probes, everything — with any model they choose (§6.5). The
  assessment never asks "did you use an LLM" — it asks whether the student can
  stand behind the evidence their system produced, on stage, under questioning.
- **Integrity rests on three legs:** (1) fresh private mutations each semester,
  (2) the random-draw defense with on-the-spot re-runs — fabricated or
  borrowed work cannot survive questioning, (3) the final interview on
  never-published mutations. If inter-student copying of results ever becomes a
  concern, the cheap additional lock is issuing each question in 2–3 parameter
  variants.
- **Inter-student sharing:** trigger/probe libraries are each student's graded work;
  sharing them is collusion, and the weekly defenses plus the final report's
  design section make a copied library hard to defend. Cross-student *tooling help* (fixing builds,
  environment problems) is explicitly legal (§11.1).

## 11. Support model

There is no TA. Support is structured so you are never stuck alone:

### 11.1 Getting unstuck

- **First line: your own agent** plus the environment's self-diagnosis
  (`make doctor`) and troubleshooting playbook (`env/TROUBLESHOOTING.md`),
  and the gotchas your own workspace accumulates — "my probe doesn't fire"
  is itself a kernel investigation, and solving it with the course's own
  methodology is the course working as intended.
- **The instructor owns judgment calls** — is this the right invariant to
  test, would this evidence actually support that claim. Bring those
  questions to studio; they are the highest-value conversations in the
  course.
- Cross-student *tooling help* is explicitly legal; sharing trigger/probe
  libraries is collusion (§10). The line: help them fix their build, don't
  hand them your probes.
