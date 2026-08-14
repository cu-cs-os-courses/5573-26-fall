# CSCI 5573 — Fall 2026

Graduate Operating Systems, run as **agent-driven kernel investigation**:
you direct an LLM agent that triggers, traces, and modifies a real Linux
kernel (pinned 6.6 LTS in QEMU), and you defend the evidence it produces —
live, in class, with re-runs on demand.

Start with the [syllabus](docs/syllabus.md) — grading, the AI-use line,
what the model subscription costs — then the
[schedule](docs/schedule.md). Setup is below.

## Get running

```sh
git clone https://github.com/cu-cs-os-courses/5573-26-fall
cd 5573-26-fall/env

make setup    # one-time host setup; detects macOS vs Linux
              # (Windows is not supported, including WSL)
make images   # build the kernel + rootfs (first run: ~30-60 min, one time)
make smoke    # must end all-green
```

Stuck? `make doctor` (in `env/`) diagnoses the common failures and points
into `env/TROUBLESHOOTING.md`, and the whole point of this course is that
"my tool doesn't work" is itself an investigation.

## Your repo (week 1)

You work with **two checkouts**. This repo is read-only, and all twelve
question batches are in it from week 1 — read ahead as far as you like.
Still `git pull` every Monday: that is how each batch's per-student
assignments reach you, and how any fix to `env/` or the starter tools
does. Your graded work lives in your own **workspace repo**, born from
the starter template:

```sh
cp -r agent-starter my-workspace   # inside this checkout, so the tools find env/
cd my-workspace && git init
```

```
      GitHub                                     your laptop
┌─────────────────────────────┐             ┌──────────────────────────────────┐
│ 5573-26-fall — this repo:   │  git clone, │ 5573-26-fall/  (offering clone)  │
│ public, read-only. All 12   │ pull weekly │ ├─ env/            build once    │
│ batches from week 1;        │────────────▶│ ├─ agent-starter/ ─┐  cp -r +    │
│ assignments + mutation      │             │ │                  │  git init   │
│ images on their Monday      │             │ └─ my-workspace/ ◀─┘  YOURS:     │
└─────────────────────────────┘             │      tools/  triggers/  probes/  │
                                            │      reports/batch-NN/...        │
┌─────────────────────────────┐             │      (untracked by the offering) │
│ your workspace repo:        │◀─ git push ─│                                  │
│ PRIVATE + instructor as     │             └──────────────────────────────────┘
│ collaborator; registered    │
│ under students/ as a        │
│ submodule — grading pulls   │
│ reports from here           │
└─────────────────────────────┘
```

Push it to a **private** GitHub repository (a public one leaks graded work
— an honor-code problem), add the instructor as a collaborator, and submit
the repo URL through the **Repo registration** assignment on Canvas so it
can be registered for grading — all by the week-1 Wednesday studio; batch 1
reports are collected from it. Details:
[agent-starter/README.md](agent-starter/README.md).

One transparency note: registration lists your repo's URL — and therefore
your GitHub username — in this public repo's `.gitmodules`. Your repo's
*contents* stay visible only to you and the instructor. If being publicly
associated with the course is a problem for you, talk to the instructor
before the week-1 studio.

## Layout

| Path | What |
|---|---|
| `env/` | the reference environment: QEMU + pinned kernel 6.6.87 + tracing rootfs |
| `agent-starter/` | your workspace template — tools, methodology, empty instrument libraries ([README](agent-starter/README.md)) |
| `worked-example/` | a complete worked investigation (copy-on-write), the model of full credit |
| `docs/course-design.md` | why the course is built this way: motivation, learning objectives, assessment design, the evidence contract |
| `docs/syllabus.md` | grading, late policy, AI use, required setup, university policies |
| `docs/schedule.md` | the week-by-week structure: batches, defenses, the final |
| `questions/batches/` | all twelve question batches, from week 1; each batch's per-student assignment sheet lands on the Monday that batch opens (batch 1's lands the Wednesday evening of week 1, once everyone has a registered repo) |
| `students/` | pointers to everyone's private repos, registered as submodules **by the instructor** once the roster settles — nothing for you to do or put here (park your workspace copy elsewhere) |

## The rhythm (one paragraph)

Every batch is published up front, but one opens each Monday (week 3
differs — see the schedule): four questions, of which
you are assigned two; you investigate
them with your agent and commit evidence-backed reports to your repo before
**noon** on the day each is scheduled; in class, one student per question
is drawn from those who reported to present and defend — any evidence may
be re-run on the spot. Weeks 1–3 are tool-free and hand-answerable. The final
is a 20-minute one-on-one interview in the last three class sessions;
nothing happens in finals week.

LLM help is unrestricted, always. What is graded is whether *you* can stand
behind every command and every claim, on stage.

## License

Code: [Apache-2.0](LICENSE). Course materials (docs, questions, methodology text): [CC BY 4.0](LICENSE-docs).
