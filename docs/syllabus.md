
# CSCI 5573 — Graduate Operating Systems

**Fall 2026 · University of Colorado Boulder · Mon/Wed 4:40–5:55 PM MT · ECCR 116**
**Instructor:** Yueqi Chen (yueqi.chen@colorado.edu) · **TA:** none

---

## 1. What this course is

You will spend the semester interrogating a **real Linux kernel** — a
pinned 6.6 LTS tree running in QEMU — by tracing it, probing it, and
modifying it, with an LLM agent doing the mechanical work and **you**
answering for everything it produces.

There are **no lectures and no written exams.** The course is one repeated
loop: every batch of investigation questions is published before week 1 —
read the whole semester on day one if you want — and one batch of four
opens each Monday. You are assigned
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
| Meetings | Monday & Wednesday, **4:40–5:55 PM MT**, **ECCR 116** |
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
  options (free tiers, educational credits — the department does not
  currently fund model access, so do not count on that) and no student
  will be graded down for lacking a subscription. Do not skip the course
  over $20.

## 6. Grading

| Component | Weight | What it measures |
|---|---|---|
| Weekly reports | 25% | evidence submitted on time, in the required schema, re-runnable |
| **Defenses** | **35%** | your live defense of your own evidence (lowest defense dropped) |
| Participation | 10% | questioning peers, studio engagement |
| Final report | 10% | your final-mutation report, plus a **design section** defending your toolkit: tool interface, evidence pipeline, self-verification |
| Final interview | 20% | one-on-one, on a kernel mutation no one has seen before |

The **final report** is the report you commit for your final-interview
mutation, before your slot. It follows the same evidence schema as a weekly
report, plus a design section: what your toolkit is, why each instrument is
built the way it is, and how your pipeline protects you from your own
model's mistakes. Expect the interview to probe it.

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
statements in the university's official wording, reproduced in full below
and also posted on the course Canvas page. Where a statement calls for a
course-specific procedure, mine follows it in a note marked *In this
class*.

### Honor Code

All students enrolled in a University of Colorado Boulder course are
responsible for knowing and adhering to the Honor Code. Violations of the
Honor Code may include but are not limited to: plagiarism (including use
of paper writing services or technology [such as essay bots]), cheating,
fabrication, lying, bribery, threat, unauthorized access to academic
materials, clicker fraud, submitting the same or similar work in more than
one course without permission from all course instructors involved, and
aiding academic dishonesty. Understanding the course's syllabus is a vital
part of adhering to the Honor Code.

All incidents of academic misconduct will be reported to Student Conduct &
Conflict Resolution: StudentConduct@colorado.edu. Students found
responsible for violating the Honor Code will be assigned resolution
outcomes from Student Conduct & Conflict Resolution and will be subject to
academic sanctions from the faculty member. Visit
[Honor Code](https://www.colorado.edu/sccr/honor-code) for more information
on the academic integrity policy.

*In this class:* the Honor Code applies exactly as written, and the
university-wide language above is deliberately broad because most courses
restrict AI use. This one does not. **Section 7 defines permitted AI use
here, and it permits everything** — any model, any part of the work, no
disclosure required. Using an LLM to write your triggers, probes, analysis,
or prose is never an Honor Code matter in this course. What the Honor Code
still governs is unchanged by that: submitting another student's triggers,
probes, or reports as your own, fabricating evidence or results, or
claiming a re-run you did not perform. The line is authorship of the
*artifact you are defending*, not which tool produced it.

### Accommodation for Disabilities, Temporary Medical Conditions, and Medical Isolation

If you qualify for accommodations because of a disability, please submit
your accommodation letter from Disability Services to your faculty member
in a timely manner so that your needs can be addressed. Disability Services
determines accommodations based on documented disabilities in the academic
environment. Information on requesting accommodations is located on the
[Disability Services website](https://www.colorado.edu/disabilityservices/).
Contact Disability Services at 303-492-8671 or DSinfo@colorado.edu for
further assistance. If you have a temporary medical condition, see
[Temporary Medical Conditions](https://www.colorado.edu/disabilityservices/students/temporary-medical-conditions)
on the Disability Services website.

*In this class:* if illness, injury, or required medical isolation keeps
you from a class session or a deadline, **email me before the session if
you can, or as soon as you are able afterwards.** Do not tell me what is
wrong — I am not permitted to ask, and I do not want to know — and do not
send a doctor's note; I will not ask for one and campus health services no
longer issues them. What happens next:

- **A defense day you cannot attend.** You are withdrawn from that
  session's draw. It is not an absence, it does not affect your
  participation grade, and it does **not** use up your dropped defense —
  that stays available for a defense you actually give and would rather not
  count.
- **A report deadline you cannot meet.** Tell me and we will set a new one.
  An extension for illness does not consume any of your three late days.

If you have a documented disability, or think you may need an
accommodation of any kind, contact me early. The weekly-defense format has
more moving parts than a lecture course, and there is a great deal I can
adjust when I know in advance — far less once a defense day has passed.

### Accommodation for Religious Obligations

Instructional faculty members must make every reasonable effort to
accommodate all students who have conflicts with scheduled exams,
assignment deadlines or required attendance due to a religious observance.
Whenever possible, students must notify the instructional faculty member at
least two weeks in advance of the expected exam, assignment deadline, or
attendance conflict to request an accommodation for religious observance.
If the start date of the course is less than two weeks before the date of
requested accommodation, students must notify the instructional faculty
member on the start date of the course. See the
[Student Academic Accommodations for Religious Observances Policy](https://www.colorado.edu/compliance/student-academic-accommodations-religious-observances-policy)
for more information.

*In this class:* email me at least two weeks ahead — or on the first day of
class, if the conflict falls in the first two weeks — and name the sessions
or deadlines involved. You never need to explain or justify the observance.
Then:

- **A defense day.** I move your defense to another session, or hold your
  question over to the next docket. A defense missed for religious
  observance is not an absence, does not affect your participation grade,
  and does **not** count against your dropped defense.
- **A report deadline.** It shifts to accommodate the observance, without
  using your late days.
- **A final-interview slot.** Tell me when the slot schedule is published
  in Week 13 and I will place you outside the conflict. The interview
  window spans three sessions, so there is room.

The draw is a mechanism, not a trap. It exists to make defenses
unbluffable, not to punish you for observing your religion.

### Student Names and Pronouns

CU Boulder recognizes that students' legal information does not always
align with how they identify. If you wish to have a name other than your
legal name appear on your instructors’ class rosters and in Canvas, or if
you wish to choose pronouns to appear on your instructors’ class rosters
and in Canvas, visit the
[Registrar’s website](https://www.colorado.edu/registrar/students/records/info/preferred)
for instructions on how to change your personal information in university
systems.

*In this class:* you can also just tell me, and I will use it from that
point on whatever the roster says.

### Classroom Behavior

Students and faculty are responsible for maintaining an appropriate
learning environment in all instructional settings, whether in person,
remote, or online. Failure to adhere to such behavioral standards may be
subject to discipline. Professional courtesy and sensitivity are especially
important with respect to individuals and topics dealing with race, color,
national origin, sex, pregnancy, age, disability, creed, religion, sexual
orientation, gender identity, gender expression, veteran status, marital
status, political affiliation, or political philosophy.

Additional classroom behavior information:

- [Student Classroom and Course-Related Behavior Policy](https://www.colorado.edu/compliance/policies/student-classroom-course-related-behavior)
- [Student Code of Conduct](https://www.colorado.edu/sccr/students/honor-code-and-student-code-conduct)
- [Office of Institutional Equity and Compliance](https://www.colorado.edu/oiec/)

*In this class:* this one has teeth in a course built on public defense.
You will watch classmates be questioned hard about evidence that turns out
to be wrong — that is the format working, and it is the most useful thing
in the room. Challenge the evidence as sharply as you like. Never make it
about the person holding it.

### Sexual Misconduct, Discrimination, Harassment and/or Related Retaliation

CU Boulder is committed to fostering a productive and welcoming learning,
working, and living environment. University policy prohibits
protected-class discrimination and harassment, sexual misconduct
(harassment, exploitation, and assault), intimate partner abuse (dating or
domestic violence), stalking, and related retaliation by or against members
of our community on- or off-campus. Denial of an approved accommodation for
disability, religious observance, or pregnancy or pregnancy related medical
conditions may be discriminatory.

The Office of Institutional Equity and Compliance (OIEC) addresses these
concerns, and individuals who have been subjected to misconduct can contact
OIEC at 303-492-2127 or email OIEC@colorado.edu. Information about
university policies, OIEC reporting options, and OIEC support resources
including confidential services can be found on the
[OIEC website](https://www.colorado.edu/oiec/).

Faculty and graduate instructors are required to inform OIEC when someone
discloses misconduct regardless of when or where it occurred. This is to
ensure that those impacted receive outreach from OIEC about resolution
options and support resources. To learn more about reporting and support
options for a variety of concerns, visit the
[Don’t Ignore It](https://www.colorado.edu/dontignoreit/) page.

*In this class:* note the reporting duty above — I am required to pass a
disclosure to OIEC, so I cannot be a confidential resource. If you want to
talk to someone who can keep it confidential, OIEC's support-resources page
lists those options.

### Mental Health and Wellness

The University of Colorado Boulder is committed to supporting students’
mental health and overall wellbeing. If personal, academic, or emotional
challenges are affecting your wellbeing or success, Counseling and
Psychiatric Services
([CAPS](https://www.colorado.edu/counseling/)), is here to help. CAPS
offers counseling, referrals, psychiatric care, crisis support, and much
more. Visit CAPS in the C4C, or call (303) 492-2277, 24/7.

*In this class:* a weekly cadence with a public defense attached is a
sustained kind of pressure, and it is easy to read a bad defense as a
verdict on you. It is not — the lowest one is dropped precisely because
everyone has one. If the cadence is becoming a health problem rather than a
workload problem, come talk to me early and we will find adjustments.

## 10. Getting unstuck

There is no TA. The support model is deliberate:

1. **Your own agent**, plus the environment's self-diagnosis (`make
   doctor` in `env/`) and troubleshooting playbook
   (`env/TROUBLESHOOTING.md`), and the gotchas your workspace
   accumulates. "My probe doesn't fire" is itself a kernel investigation
   — solving it with the course's own method is the course working as
   intended. Classmates helping each other with builds and environment
   problems is explicitly legal (§7) — lean on each other in studio.
2. **Me**, for judgment calls — is this the right invariant to test, would
   this evidence actually support that claim. Those are the highest-value
   conversations available in this course; bring them to studio.
