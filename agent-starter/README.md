# Agent starter

Your kernel-investigation workspace, batteries included: the course tool
layer (VM control, source search, report validation), the investigation
methodology (`CLAUDE.md`), and empty library shelves (`triggers/`,
`probes/`) that your semester's work will fill.

## Setup

You will work with **two checkouts**: the offering repo (read-only —
`git pull` there brings each Monday's batch; you never push to it) and
this directory copied out as **your own workspace repo**, where your
toolkit and reports live and grading happens.

**Week 1:**

1. Copy this directory out and make it a repo of your own — keep it
   inside the offering checkout, so the tools find `env/` automatically
   (anywhere else works too: export `KL_ENV=/path/to/env`):

   ```sh
   cp -r agent-starter my-workspace
   cd my-workspace && git init
   ```

   Three things must be true before your first report is due: the GitHub
   repo is **private** (a public one leaks graded work and is an
   honor-code problem), the **instructor is added as a collaborator**,
   and you have emailed the repo URL so it can be registered for grading.
   Do all three in the week-1 Wednesday studio — batch 1 reports are
   collected from this repo. (Registration lists your repo URL, i.e. your
   GitHub username, in the public offering repo; the contents stay
   private to you and the instructor.)
2. Build the course environment once on your machine — follow
   `env/README.md` in the offering repo (`make setup` detects macOS vs
   Linux, then `make images && make smoke`).
3. That is all weeks 1–3 need: batches 1–3 are answered **by hand**, and
   each report (`report.md` + raw captures + `repro.sh` under
   `reports/batch-NN/<question-id>/`) is committed here.

**Week 4 — the agent arrives:**

4. Open your agent product of choice in this directory (`CLAUDE.md` is
   picked up as context by Claude Code; other products can be pointed at
   it) — then start investigating: `tools/vm up`, ask your question, make
   it prove its answers. Week 4's Monday session walks through the tool
   layer; nothing before then requires it.

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
