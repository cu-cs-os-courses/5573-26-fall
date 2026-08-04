# CSCI 5573 — Fall 2026

Graduate Operating Systems, run as **agent-driven kernel investigation**:
you direct an LLM agent that triggers, traces, and modifies a real Linux
kernel (pinned 6.6 LTS in QEMU), and you defend the evidence it produces —
live, in class, with re-runs on demand.

Start with the [schedule](docs/schedule.md). Course policies (grading,
model-subscription cost, platform requirements) are in the syllabus; the
pre-semester email covers setup, and the short version is below.

## Get running

```sh
git clone https://github.com/cu-cs-os-courses/5573-26-fall
cd 5573-26-fall/env

make setup    # one-time host setup; detects macOS vs Linux
              # (Windows is not supported, including WSL)
make images   # build the kernel + rootfs (first run: ~30-60 min, one time)
make smoke    # must end all-green
```

Stuck? `env/README.md` has a troubleshooting section, and the whole point
of this course is that "my tool doesn't work" is itself an investigation.

## Layout

| Path | What |
|---|---|
| `env/` | the reference environment: QEMU + pinned kernel 6.6.87 + tracing rootfs |
| `agent-starter/` | your workspace template — tools, methodology, empty instrument libraries ([README](agent-starter/README.md)) |
| `examples/cow/` | a complete worked investigation (copy-on-write), the model of full credit |
| `docs/course-design.md` | why the course is built this way: motivation, learning objectives, assessment design, the evidence contract |
| `docs/schedule.md` | the week-by-week structure: batches, defenses, design reviews, the final |
| `questions/batches/` | question batches appear here every Monday |
| `students/` | your private repos, registered as submodules once the roster settles |

## The rhythm (one paragraph)

Four questions publish most Mondays (week 3 differs — see the schedule);
you are assigned two; you investigate
them with your agent and commit evidence-backed reports to your repo before
the session where each is scheduled; in class, one student per question is
drawn from those who reported to present and defend — any evidence may be
re-run on the spot. Weeks 1–3 are tool-free and hand-answerable. The final
is a 20-minute one-on-one interview in the last three class sessions;
nothing happens in finals week.

LLM help is unrestricted, always. What is graded is whether *you* can stand
behind every command and every claim, on stage.

## License

Code: [Apache-2.0](LICENSE). Course materials (docs, questions, methodology text): [CC BY 4.0](LICENSE-docs).
