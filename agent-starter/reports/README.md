Weekly reports live here, one directory per question. **The path is exact** —
the collection script looks in one place and nowhere else:

```
reports/
└── batch-01/                 ← two digits, always: batch-01, not batch-1
    └── obs-ls-trace-01/      ← the question id, exactly as the batch file prints it
        ├── report.md         ← batches 1–3 (prose).  report.json from batch 4 on
        ├── repro.sh          ← required every week
        └── evidence/         ← your raw captures, in this subdirectory
            └── ls-trace.txt      name the files whatever you like
```

**`evidence/` is a real requirement, not tidiness.** It is the directory your
report's excerpts are checked against: `tools/report-check` looks for exactly
this name beside the report, and reports that every excerpt quoting a number
found nowhere under it is quoting a run nobody kept. Leave the captures loose
in the question directory and the check cannot see them at all — it says
*"no evidence/ directory — nothing to trace the excerpts back to"* and your
report goes unverified.

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
in the offering repo).

## Models to copy — one complete hand-in, all three parts

`examples/cow/vm-cow-01/` **is a hand-in** — the same file names in the same
nesting you are required to produce, missing only the `reports/batch-NN/`
prefix above it, because that question came from no batch. Copy its shape
before you copy anything else. Read all three parts before your first
hand-in; the report gets most of the attention and the `repro.sh` is where
marks are actually lost.

```
examples/cow/vm-cow-01/     →     reports/batch-NN/<question-id>/
├── report.md   report.json        ├── report.md  (or report.json)
├── repro.sh                       ├── repro.sh
└── evidence/                      └── evidence/
```

(The example carries both report formats so you can read the same
investigation either way; you commit the one your week calls for. Its
trigger and probe sit *outside* the directory, in `examples/cow/guest/` —
in your workspace those are your `triggers/` and `probes/` libraries. A
report directory holds the record of an investigation, never the
instruments.)

| you commit | model | what to take from it |
|---|---|---|
| `report.md` (batches 1–3) | `examples/cow/vm-cow-01/report.md` | the §7 fields as prose: claim, evidence entries (command + raw excerpt + interpretation), reproduction, limitations |
| `report.json` (batches 4–12) | `examples/cow/vm-cow-01/report.json` | the same contract, structured |
| `repro.sh` (every week) | `examples/cow/vm-cow-01/repro.sh` (worked) · `repro-template.sh` (skeleton to copy) | push trigger+probe, run, pull raw output, then one `pass`/`fail` line per expectation; non-zero exit if any fails |
| your raw captures, in `evidence/` | `examples/cow/vm-cow-01/evidence/` | plain text straight out of the tools, no hand-editing; name the files whatever you like |

**Starting point:** `repro-template.sh`, here in this directory. Copy it to
`reports/batch-NN/<question-id>/repro.sh` and replace the TODOs. It carries
the boilerplate every weekly repro needs — locating the VM, choosing an
output directory, `pass`/`fail`, a non-zero exit — so the only thing you
write is the part being assessed: the assertions. Until you write some, it
exits non-zero and says so, rather than exiting 0 and looking like a
reproduction that never happened.

Two things the worked example does deliberately, and you should copy:

- **Assert, don't print.** A `repro.sh` that dumps output and exits 0 proves
  nothing. Every claim in the report should have a line in the script that
  fails loudly when it stops being true.
- **Never let the repro overwrite the captures the report quotes.** Write to
  a scratch directory by default. Otherwise re-running to check your work
  silently replaces the evidence your report cites, and the report ends up
  quoting a run that no longer exists — which the defense will find by
  asking where a number came from.

`report-check` reads JSON only, so it has nothing to say about a batch-1
prose report — that is not a bug. Weeks 1–3 the check is you, re-running
your own `repro.sh` and watching the assertions hold.
