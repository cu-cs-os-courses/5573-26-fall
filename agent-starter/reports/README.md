Weekly reports live here: `reports/batch-NN/<question-id>/` with the report,
the raw captures, and `repro.sh`.

Two renderings, one evidence contract (`docs/course-design.md` §7, in the
offering repo):

- **Batches 1–3 — `report.md`, prose.** You write it by hand. Copy the shape
  from the worked example's `examples/cow/answer/vm-cow-01.md`.
- **Batch 4 on — `report.json`, structured.** Your agent emits it; run
  `tools/report-check reports/batch-NN/<question-id>/report.json` before you
  commit. Same example, `.json` instead.

`report-check` reads JSON only, so it has nothing to say about a batch-1
prose report — that is not a bug. Weeks 1–3 the check is you, re-running
your own `repro.sh` and seeing the assertions hold.
