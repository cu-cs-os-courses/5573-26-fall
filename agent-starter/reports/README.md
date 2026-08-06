Weekly reports live here, one directory per question. **The path is exact** —
the collection script looks in one place and nowhere else:

```
reports/
└── batch-01/                 ← two digits, always: batch-01, not batch-1
    └── obs-ls-trace-01/      ← the question id, exactly as the batch file prints it
        ├── report.md         ← batches 1–3 (prose).  report.json from batch 4 on
        ├── repro.sh          ← required every week
        └── ls-trace.txt      ← your raw captures; name these whatever you like
```

**Where the question id comes from.** The batch file's heading for the
question, verbatim:

```
## obs-ls-trace-01 — What does `ls` ask the kernel for?
   ^^^^^^^^^^^^^^^ this is the directory name
```

So `obs-ls-trace-01`. Not `01`, not `Q1`, not `obs-ls-trace`, not
`obs-ls-trace-01-report`. Copy-paste it rather than retyping it.

**Why this is strict rather than fussy.** Collection is automated: the
script builds the path `reports/batch-NN/<question-id>/` from the batch file
and your assignment sheet, and if nothing is there it records *no report
submitted*, which scores zero. It does not search for near-misses, and you
will not be asked about it — a report in `reports/batch-1/01/` is invisible
and grades as missing. Ten seconds checking the path is worth more than any
paragraph in the report.

## What must be in the directory

| Batch | Report file | Also required | Validate with |
|---|---|---|---|
| 1–3 | `report.md` — prose | `repro.sh` | re-run `repro.sh` yourself |
| 4–12 | `report.json` — structured | `repro.sh` | `tools/report-check <path>/report.json` |

Both renderings carry the same evidence contract (`docs/course-design.md` §7
in the offering repo). Models to copy, same investigation written both ways:
`examples/cow/answer/vm-cow-01.md` (prose) and `.json` (structured).

`report-check` reads JSON only, so it has nothing to say about a batch-1
prose report — that is not a bug. Weeks 1–3 the check is you, re-running
your own `repro.sh` and watching the assertions hold.
