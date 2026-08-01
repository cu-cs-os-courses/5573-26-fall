# CSCI 5573 — Fall 2026

Graduate Operating Systems, run as **agent-driven kernel investigation**:
you direct an LLM agent that triggers, traces, and modifies a real Linux
kernel (pinned 6.6 LTS in QEMU), and you defend the evidence it produces —
live, in class, with re-runs on demand.

Start with the [schedule](docs/schedule.md). The pre-semester email covers
setup; short version below.

## Get running

```sh
git clone https://github.com/cu-cs-os-courses/5573-fall-26
cd 5573-fall-26/env
make setup    # one-time host setup (macOS or Linux; Windows unsupported)
make images   # build the kernel + rootfs (first run: ~30-60 min)
make smoke    # must end all-green
```

## Layout

| Path | What |
|---|---|
| `env/` | the reference environment: QEMU + pinned kernel 6.6.87 + tracing rootfs |
| `agent-starter/` | your workspace template — tools, methodology, empty instrument libraries ([README](agent-starter/README.md)) |
| `examples/cow/` | a complete worked investigation (copy-on-write), the model of full credit |
| `docs/schedule.md` | the week-by-week structure: batches, defenses, design reviews, the final |
| `questions/batches/` | question batches appear here every Monday |
| `students/` | your private repos, registered as submodules once the roster settles |

## The rhythm (one paragraph)

Four questions publish every Monday; you are assigned two; you investigate
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
