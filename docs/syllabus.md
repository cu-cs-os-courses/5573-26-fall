
# CSCI 5573 — Graduate Operating Systems

**Fall 2026 · University of Colorado Boulder · Mon/Wed, 75 minutes**
**Instructor:** Yueqi Chen (yueqi.chen@colorado.edu) · **TA:** none

---

## 1. What this course is

You will spend the semester interrogating a **real Linux kernel** — a
pinned 6.6 LTS tree running in QEMU — by tracing it, probing it, and
modifying it, with an LLM agent doing the mechanical work and **you**
answering for everything it produces.

There are **no lectures and no written exams.** The course is one repeated
loop: four investigation questions publish every Monday, you are assigned
two, you commit evidence-backed reports before class, and in class one
student per question is drawn at random to present and defend that evidence
— with live re-runs on demand.

This design is a deliberate response to a fact everyone in the room already
knows: an LLM will answer any conceptual OS question, correctly and
instantly, for free. So this course does not grade conceptual answers. It
grades what an LLM cannot do for you — producing and defending evidence
about *this* kernel, on *this* machine, under questioning.

The reasoning behind every design decision is written up in
[`docs/course-design.md`](course-design.md). You are welcome to disagree
with it out loud.

## 2. Prerequisites

Comfort with C and an undergraduate operating systems course. **Kernel
experience is not assumed** — the course exists to build it. You must be
able to read code you did not write and stay skeptical of confident
explanations.

## 3. Meetings and calendar

| | |
|---|---|
| First class | **Mon Aug 24** |
| Meetings | Monday & Wednesday, 75 min |
| No class | **Mon Sep 7** (Labor Day) · **Nov 23–27** (fall break) |
| Last teaching week | week of **Nov 16** (batch 12 defenses) |
| Final interviews | **Nov 30, Dec 2, Dec 4** — in our regular class slots |
| Finals week (Dec 7–11) | **nothing scheduled** |

Note that **Fri Dec 4 runs a Monday schedule** and is the last session.
The week-by-week structure is in [`docs/schedule.md`](schedule.md); the
exact date mapping is in [`docs/calendar-2026-fall.md`](calendar-2026-fall.md).

## 4. Required setup — do this before the first class

**Platform: macOS (Apple Silicon or Intel) or Linux. Windows is not
supported, including WSL.** If a Windows machine is all you have, email me
now. Recommended: 8 GB RAM (16 GB is more comfortable), ~20 GB free disk.

```sh
git clone https://github.com/cu-cs-os-courses/5573-26-fall
cd 5573-26-fall/env
make setup     # one-time host setup; detects macOS vs Linux
make images    # builds the kernel + rootfs (~30-60 min, once)
make smoke     # must end all-green
```

The first Wednesday session is dedicated to getting everyone running, but
arriving with `make smoke` already green puts you a week ahead.

## 5. Model access — you fund it, and here is exactly what you need

You will drive the course tools through an **LLM agent product of your
choice, on your own subscription**. Plan on roughly **$20–25/month for the
semester — about the price of a textbook.**

- **Recommended tier: a frontier flagship model — Claude Opus 4.6 or
  GPT-5.5 class, or better.** Every question batch is validated to be
  solvable at that tier before it is released to you. Money does not buy a
  better grade; it buys convenience.
- A **flat-rate subscription product** (e.g. Claude Code on a paid Claude
  plan) is strongly preferred over pay-per-token API access, because the
  cost is capped and predictable.
- Weeks 1–3 need no agent at all — they are deliberately hand-answerable —
  so you have until roughly **mid-September** to choose and subscribe.
- **If this cost is a genuine hardship, talk to me privately.** There are
  options (free tiers, educational credits, department support) and no
  student will be graded down for lacking a subscription. Do not skip the
  course over $20.

## 6. Grading

| Component | Weight | What it measures |
|---|---|---|
| Weekly reports | 25% | evidence submitted on time, in the required schema, re-runnable |
| **Defenses** | **35%** | your live defense of your own evidence (lowest defense dropped) |
| Design reviews (×2) | 10% | oral exams over your own repo: tool interface (W7), evidence pipeline (W12) |
| Participation | 10% | questioning peers, studio engagement, duty-student weeks |
| Final interview | 20% | one-on-one, on a kernel mutation no one has seen before |

**Reports are your ticket to the draw and your audit trail** — most students
score near the top on them. The discrimination lives in the defenses and the
final, which is deliberate: the artifacts are cheap to produce and the
understanding is not.

**Late policy:** three late days for the semester, applicable to **reports
only**. A late report enters the next session's draw pool. Defenses cannot
be late — the draw happens with or without you. No report on an assigned
question means a zero for that report and ineligibility for its draw.

## 7. AI use — unrestricted, and that is the point

**Use LLMs for everything: your triggers, your probes, your analysis,
your report prose.** There is no disclosure requirement and no cap on which
model you run. This is not a concession; the course is built on it.

What is graded is whether **you** can stand behind the results. In a defense
I can point at any line of your evidence and say "re-run that now, and tell
me why it proves what you claim." An artifact you cannot defend is worth
nothing, no matter who or what produced it. "It worked at home" without a
working re-run caps that defense at partial credit.

**Where the line is:** helping a classmate fix their build or their
environment is explicitly legal and encouraged. Handing a classmate your
triggers, probes, or reports is collusion under the honor code. The
distinction is simple — help them make their instrument work, don't give
them your instrument.

## 8. What you keep

Your repository is yours: a working kernel-investigation toolkit, a method
for interrogating systems you did not write, and the habit of building
instruments that make an AI effective in an unfamiliar domain. Models
depreciate quickly. Those three do not.

## 9. University policies

This section carries the University of Colorado Boulder's required policy
statements — accommodations, classroom behavior, names and pronouns, the
Honor Code, discrimination and harassment, and religious observance — in
the Provost's current official wording. They are posted in full on the
course Canvas page, and they apply here exactly as written there.

Two of them matter enough to say in my own words as well:

- **Accommodations.** If you have a documented disability, or think you may
  need an accommodation of any kind, contact me early — the weekly-defense
  format has more moving parts than a lecture course, and there is a lot I
  can adjust if I know in advance.
- **Religious observance.** Tell me ahead of time and we will move your
  defense slot. The draw is a mechanism, not a trap.

## 10. Getting unstuck

There is no TA. The support model is deliberate and layered:

1. **Your own agent**, plus the environment's self-diagnosis (`make
   doctor` in `env/`) and troubleshooting playbook
   (`env/TROUBLESHOOTING.md`), and the gotchas your workspace
   accumulates. "My probe doesn't fire" is itself a kernel investigation
   — solving it with the course's own method is the course working as
   intended.
2. **The week's duty student** (the role rotates; everyone serves once or
   twice), in the Wednesday studio.
3. **Me**, for judgment calls — is this the right invariant to test, would
   this evidence actually support that claim. Those are the highest-value
   conversations available in this course; bring them to studio.
