# Course Schedule

*Companion to [course-design.md](course-design.md). The schedule is
**week-relative and reusable across offerings** — it assumes a standard
16-week US fall shape: two 75-minute meetings per week (**Monday and
Wednesday**), one Monday holiday in week 3, a one-week break in week 14,
and a finals week after week 16. Map week numbers onto the registrar's
calendar for each offering; a typical fall (classes late Aug – early Dec,
Labor Day in W3, Thanksgiving-week break as W14) fits without changes.
The Fall 2026 mapping lives in
[calendar-2026-fall.md](calendar-2026-fall.md).*

## 1. The weekly cycle

The course runs one repeated loop (design-doc §6.1): a four-question batch is
published one week before it is defended (two questions per session); each
student is **assigned two of the four** by the instructor and submits a
per-question report before the session where that question is scheduled; the
presenter for each question is drawn at random from its ~5 assigned
students. There are no lectures and no exams — the loop is the course.

- **Monday.** ~15 min **anchor**: the instructor frames what this week's
  subsystem *guarantees*, where the invariants are, and what would count as
  evidence — the one lecture-shaped thing that remains, because contracts are
  judgment, not lookup. Then **two defense rounds** (~20 min each: the drawn
  student walks their evidence chain; peers who prepared the same question
  ask first, the floor follows, the instructor closes — often with an
  on-the-spot re-run or a prediction twist). Closing: **next week's batch is
  released** and briefly framed.
- **Wednesday.** **Two defense rounds**, then **studio**: students work with the
  instructor circulating — 2-minute standups, then probe-placement and
  workload-design conversations (the highest-value teaching in the course).
  Early weeks are studio-heavy; by mid-semester defenses fill most of the
  slot.
- **Capacity:** 4 rounds/week over the ~12 presenting weeks (W2–W13) ≈ 46
  defense slots; at ~10 students (the course is solo, no teams) each
  question has a ~5-person draw pool and every student lands **4–5
  defenses** — a deliberate course-size decision. The final interview adds
  one more high-weight individual sample.
Division of labor per design-doc §11.1 (no TA): **hands-on unblocking is
self-serve** — the student's own agent plus the environment's own
troubleshooting playbook (`env/TROUBLESHOOTING.md`), with cross-student tooling help
explicitly legal; the
**instructor owns judgment calls** — is this the right invariant to test,
would this evidence actually support that claim.

## 2. Week-by-week

Batches are numbered by the Monday they are **released**; batch N is defended
the following week. Twelve batches total — teaching ends with batch 12's
defenses in W13, and the last three sessions are the final. Batches 1–3 are
deliberately hand-answerable (design-doc §6.2); batches 4–12 are the
**subsystem tour**: one kernel subsystem per week, classified by source-tree
directory (design-doc §8), ordered process → memory → scheduling (three
mutually explanatory foundations), then entry → interrupts/signals (how the
kernel gets entered), then VFS → ext4 → block (one I/O path walked top to
bottom), closing on synchronization. Each week's anchor and released batch
cover the same subsystem; that batch is defended the following week while
the next subsystem opens. **The Theme column below names what is being
defended that week** — defenses are the bulk of class time — while the
Monday anchor always belongs to the batch released the same day, one
subsystem ahead.

*Batch links below go live in this repo on their release Mondays — a 404
just means that week hasn't arrived yet.*

| Wk | Theme | Monday | Wednesday | Released / due |
|---|---|---|---|---|
| 1 | The course & the environment | • Course pitch — open by asking an LLM a conceptual question live ("so we never grade that")<br>• The weekly cycle, grading, cost disclosure<br>• **Full-loop demo** on a toy question (reference agent, live, with a scripted probe-failure the evidence catches) | • Studio: env bring-up — goal: everyone boots the VM and commits a first ftrace capture before leaving | **[Batch 1](../questions/batches/batch-01.md) released in the last ~15 min of Monday's class**, together with the per-student assignments, one question walked through as a worked "what counts as evidence" example. Manual observability; doubles as env acceptance; defended W2 (Mon 2 + Wed 2). Realistic working window opens after Wednesday's env studio — students who arrive with the env preinstalled (pre-semester email) can start Monday night |
| 2 | Observability: first contact (defends batch 1) | • Anchor: ftrace/tracepoints<br>• **First defenses** — rounds (batch 1) | • Rounds (batch 1)<br>• Studio | **[Batch 2](../questions/batches/batch-02.md)** (2 questions, and everyone does both — week 3 has a single session because of the Monday holiday) |
| 3 | Observability: the inside view (defends batch 2) | *Holiday — no class* | • Anchor: kprobes/bpftrace/BTF, gdbstub<br>• Rounds (batch 2) | **[Batch 3](../questions/batches/batch-03.md)** released Wed |
| 4 | Observability: probes anywhere (defends batch 3); the agent arrives | • Anchor: the tool layer & report schema<br>• **Thick-starter walkthrough** (deferred from W1)<br>• Demo: an agent-driven fork/exec investigation<br>• Rounds (batch 3) | • Rounds (batch 3)<br>• Studio (tool-layer work) | **[Batch 4](../questions/batches/batch-04.md)** (`kernel/`: fork/exec/exit/wait) — first trigger-design questions; agent now necessary |
| 5 | `kernel/` — process lifecycle (defends batch 4) | • Anchor: `mm/` — address spaces & fault paths<br>• **Live COW demo** (worked example, design-doc §9)<br>• Rounds (batch 4) | • Rounds (batch 4)<br>• Studio | **[Batch 5](../questions/batches/batch-05.md)** (`mm/`) |
| 6 | `mm/` — virtual memory (defends batch 5) | • Anchor: `kernel/sched/` — what the scheduler guarantees, EEVDF/vruntime; honest timing methodology<br>• Demo: mutation investigation (Q3 walkthrough on the §9 COW mutation — mm/ is fresh)<br>• Rounds (batch 5) | • Rounds (batch 5)<br>• Studio | **[Batch 6](../questions/batches/batch-06.md)** (`kernel/sched/`; **first mutation question**) |
| 7 | `kernel/sched/` — the scheduler (defends batch 6 — first mutation defenses) | • Anchor: `arch/x86/entry/` — how the kernel gets entered: vDSO vs. trap, entry paths<br>• Rounds (batch 6) | • Rounds (batch 6)<br>• Studio | **[Batch 7](../questions/batches/batch-07.md)** (`arch/x86/entry/` + `kernel/entry/`) |
| 8 | `arch/x86/entry/` — syscall entry (defends batch 7) | • Anchor: `kernel/irq/` `time/` `signal.c` — timer tick → preemption chain; signal delivery on return-to-user<br>• Rounds (batch 7) | • Rounds (batch 7)<br>• Studio | **[Batch 8](../questions/batches/batch-08.md)** (irq/time/signals; mutation) |
| 9 | `kernel/irq/` `time/` `signal.c` — interrupts, timers, signals (defends batch 8) | • Anchor: `fs/` — path lookup; a `read()`'s journey through `mm/filemap.c`<br>• Rounds (batch 8) | • Rounds (batch 8)<br>• Studio | **[Batch 9](../questions/batches/batch-09.md)** (VFS + page cache) |
| 10 | `fs/` — VFS & page cache (defends batch 9) | • Anchor: `fs/ext4/` + `fs/jbd2/` — what `fsync` guarantees; journaling & crash consistency<br>• Rounds (batch 9) | • Rounds (batch 9)<br>• Studio | **[Batch 10](../questions/batches/batch-10.md)** (ext4/jbd2; mutation) |
| 11 | `fs/ext4/` + `fs/jbd2/` — a real filesystem (defends batch 10) | • Anchor: `block/` — a bio's life from page cache to virtual disk; writeback<br>• Rounds (batch 10) | • Rounds (batch 10)<br>• Studio | **[Batch 11](../questions/batches/batch-11.md)** (`block/`) |
| 12 | `block/` — the block layer (defends batch 11) | • Anchor: `kernel/locking/` + RCU — what locks promise; an RCU grace period as an observable event<br>• Rounds (batch 11) | • Rounds (batch 11)<br>• Studio | **[Batch 12](../questions/batches/batch-12.md)** (locking/RCU; mutation) — **the last batch** |
| 13 | `kernel/locking/` + RCU — synchronization (defends batch 12, the last) | • Rounds (batch 12) | • Rounds (batch 12)<br>• **Final-interview briefing**: format, per-student slot schedule, 48-h mutation issuance, final-report requirements (incl. the toolkit design section, design-doc §6.6) | Interview slots posted |
| 14 | **Break** | — | — | Mutations for W15 Monday's slots issued the Saturday before (48 h ahead) |
| 15 | **Final interviews I & II** | • 3–4 individual interviews (~20 min each) | • 3–4 individual interviews | Each student's fresh mutation issued 48 h before their own slot; **final report** (evidence + toolkit design section) committed before the slot |
| 16 | **Final interviews III; wrap** | • Remaining 3–4 interviews | • Retrospective + results discussion<br>• **Repos pinned** (archival, design-doc §5.4) | — |
| F | Finals week — **nothing scheduled**; grades finalized | | | |

Grade weights (design-doc §6.6): weekly reports 25 %, defenses 35 % (lowest
dropped), participation 10 %, final report 10 %, final interview 20 %.

## 3. Rhythm rules

- **Publication:** batch N is published Monday of week N with a **docket** —
  two questions defended Monday of week N+1, two Wednesday — so every
  student knows each question's report deadline; per-student assignments
  (two of the four) are published alongside.
- **Assignment:** the instructor assigns each student two of the four,
  published with the batch (design-doc §6.1). A simple rotation script keeps
  every pool at ~5, mixes question types per student, and spreads mutation
  questions so everyone lands one several times over the semester.
- **Reports:** committed to the student repo before the session in which the
  question may be drawn (design-doc §5.4). No report on an assigned
  question → a zero for that report and ineligibility for its draw.
- **The draw:** per question, live in class, within the question's assigned
  pool — weighted lightly against students who have presented recently so
  appearances spread out; over the semester every student lands 4–5
  defenses.
- **Re-runs:** any evidence item in the presenting student's report may be re-run
  on the spot, in the student's own environment. "It worked at home" without a
  working re-run caps that defense at partial credit.
- **Late policy:** three late days per student for the semester, applicable to reports only (a late
  report enters the next session's draw pool). Defenses cannot be late — the
  draw happens with or without you.
- **Difficulty control:** every batch is validated before release — solvable
  by the reference agent at the recommended baseline tier, not solvable
  without VM access (design-doc §6.5). If a batch still lands too hard, the
  correction goes into the *next* batch; defended questions are graded on the
  rubric, not on a curve.

