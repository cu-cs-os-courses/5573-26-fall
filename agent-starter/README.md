# Agent starter

Your kernel-investigation workspace, batteries included: the course tool
layer (VM control, source search, report validation), the investigation
methodology (`CLAUDE.md`), and empty library shelves (`triggers/`,
`probes/`) that your semester's work will fill.

## Setup

1. Make this the root of **your own private repo** (copy the directory or
   use it as a template — week 4, session A shows the workflow).
2. You need the course environment built once on your machine:
   `make -C <offering-repo>/env setup images smoke`. The tools find `env/`
   automatically when your repo sits inside the offering repo checkout;
   anywhere else, export `KL_ENV=/path/to/env`.
3. Open your agent product of choice in this directory (`CLAUDE.md` is
   picked up as context by Claude Code; other products can be pointed at
   it) — then start investigating: `tools/vm up`, ask your question, make
   it prove its answers.

## Layout

| Path | What |
|---|---|
| `CLAUDE.md` | the investigation methodology your agent works under |
| `tools/` | `vm` (drive the reference VM), `ksrc` (pinned source search), `report-check` |
| `triggers/`, `probes/` | your instrument libraries — empty shelves, graded as they fill |
| `reports/` | weekly reports: `reports/batch-NN/<question-id>/` |
| `.vm/` | VM runtime state (gitignored) |

The canonical copies of `tools/` live in the course's instructor repo; the
offering repo re-syncs them if fixes ship mid-semester — don't edit them in
place (add your own tools alongside instead).
