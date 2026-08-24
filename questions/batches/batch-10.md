# Batch 10 — `fs/ext4/` + `fs/jbd2/`: the promise machine

*On the docket: Monday, week 10 (assignment sheets ship that day; the
questions have been public since before week 1). Defended: week 11 — **Monday:
ext4-fsync-01, ext4-journal-01 · Wednesday: ext4-crash-01,
ext4-mutation-01**. You are assigned two of the four.*

*This batch carries the course's **third mutation question** —
`bzImage-2026f-04`, release asset `batch-10`, exactly one private
modification **somewhere in `fs/ext4/` or `fs/jbd2/`**. The drill is
batch 6's. One new warning for this subsystem: mutations now come in
a class where **normal operation looks perfectly healthy** — decide
what the subsystem promises before deciding what to measure.*

*Env update shipped with this batch (pull the offering repo): `env/run.sh`
gained `SCRATCH=/path/img` — attaches a second disk as `/dev/vdb`
(auto-created, 512 M) so crash experiments never touch the shared rootfs — and
the starter's `tools/vm` gained a `kill` verb (SIGKILL qemu, no sync: the
crash). Port the `kill` verb into your own repo's `tools/vm` (it is five lines
— and knowing why it must NOT call poweroff is part of this week). The rootfs
persists across boots; scratch state survives `vm kill` exactly as a real disk
survives a power cut, which is the point. Reports:
`reports/batch-10/<question-id>/`, [course-design.md
§7](../../docs/course-design.md) schema, `repro.sh`. Budget ~3–4 focused hours
per question.*

---

## ext4-fsync-01 — Three acts and a receipt *(Q1, Monday)*

`fsync(2)` is the most expensive one-line contract in userspace.
Itemize the bill. Write a trigger that appends 4 KiB and fsyncs, in a
loop (append, not rewrite-in-place — you want fresh metadata every
cycle; discovering *why* that matters is part (d)). Produce: (a) the
**price**: cycle-latency distributions with and without the fsync —
on this VM the gap is ~60× at the median; (b) the **three acts**,
cited and individually evidenced: data writeback
(`file_write_and_wait_range`), the journal commit kick-and-wait (find
the function `ext4_sync_file` delegates to and the line that starts
and waits on the commit), and the device flush (`blkdev_issue_flush`)
— for each act, one piece of runtime evidence that it ran inside your
fsync window (tracepoints bracket the whole thing:
`ext4_sync_file_enter/exit`); (c) the **receipt**: show
`jbd2:jbd2_start_commit` firing **once per fsync** (200:200 in a
200-cycle run — in-window correlation, batch-8 style), and the
flush-flagged request in `block:block_rq_issue` (`rwbs` field) as the
last write of the sequence; (d) the **rewrite contrast**: rerun with
rewrite-in-place instead of append and explain what happens to the
correlation and the latency — what did the journal no longer have to
do, and which tid arithmetic in the fsync path explains it?

**Required evidence**
- Both latency distributions (append±fsync), stated gap.
- Source cites for the three acts + per-act runtime evidence.
- The 1:1 commit correlation and the flush-flag capture.
- The rewrite-mode numbers with the tid-based explanation.
- `repro.sh`: append+fsync — assert p50 above a floor, commits ≈
  fsyncs within tolerance; nofsync — assert p50 below a ceiling.

**Tools:** an append+fsync loop you write (three modes in one program:
no fsync, fsync, fsync+dir-fsync — and append rather than rewrite, for
the reason part (d) makes you discover), `jbd2:jbd2_start_commit`,
`ext4:ext4_sync_file_enter/_exit`, `block:block_rq_issue`,
`tools/ksrc view fs/ext4/fsync.c`.

**At the defense, expect:** Walk the three acts for `fdatasync` —
which tid changes and when would it skip work fsync wouldn't? Your
flush-flagged request — what exactly has the device promised when it
completes, and on what layer's authority? A second process fsyncs a
*different* file at the same moment — one commit or two, and why?
What does your dirfsync mode add, and when would POSIX say you need
it?

---

## ext4-journal-01 — Write twice, promise once *(Q1, Monday)*

The journal is why batch 9's crash story isn't a horror story. Map
it. Produce: (a) **where it is**: locate the journal on the rootfs
device (`dumpe2fs` shows the journal inode/blocks) and the commit
daemon in source (`kjournald2`) with the default commit age
(`JBD2_DEFAULT_MAX_COMMIT_AGE`) and where ext4 wires it
(`s_commit_interval`); (b) the **phases of one commit**: a
metadata-heavy burst (untar something, or a file-create loop) with
the jbd2 tracepoint sequence captured per commit —
`jbd2_commit_flushing` → `jbd2_commit_logging` → `jbd2_end_commit` —
plus `jbd2_run_stats` fields interpreted (blocks logged, handle
counts, phase times); (c) the **write-twice evidence**: correlate
`block:block_rq_issue` sectors during the burst against the journal's
block range from (a) — two write clusters, journal-area first, home
locations later (checkpoint; `jbd2_checkpoint` may fire much later —
catch it or explain its absence); (d) the **cadence and the gap**:
with only a light metadata drip (touch a file every second), show
commits at the ~5 s timer cadence; then tie in your batch-9 evidence:
dirty *data* survived those commits — state precisely what is and is
not inside a `data=ordered` transaction under delayed allocation.

**Required evidence**
- The journal location + daemon/interval cites.
- One commit's phase timeline + interpreted run_stats.
- The sector-clustering evidence (or an honest partial with the
  checkpoint explanation).
- The cadence capture + the what's-in-a-transaction paragraph.
- `repro.sh`: burst — assert phase sequence order and run_stats
  blocks > 0; drip — assert inter-commit gap ≈ 5 s within tolerance.

**Tools:** `dumpe2fs -h` + `debugfs` (guest has e2fsprogs), the
`jbd2:` tracepoint family, `block:block_rq_issue` sector field,
`tools/ksrc view fs/jbd2/journal.c fs/jbd2/commit.c`.

**At the defense, expect:** Why write everything twice instead of
just writing home carefully? What is in a *descriptor* block — and
what would replay do if the crash clipped the commit record off the
end? Your run_stats show handle counts — what is a handle, and who
was holding them (connect to a syscall you know)? If the journal
filled up mid-burst, what must happen before new handles start —
which tracepoint would show it?

---

## ext4-crash-01 — The kill test *(Q2, Wednesday)*

This is the batch's centerpiece: crash the machine on purpose and
read what the journal paid for. Method (new env capability, header
note): scratch disk via `SCRATCH=`, `mkfs.ext4` + mount it in the
guest, run a **pair workload** — `synced.txt` (write, `fsync`) and
`unsynced.txt` (write, no sync) — then `tools/vm kill` within the 5 s
commit window, boot again, mount, and inventory. Produce: (a) the
**replay evidence**: the mount-time `EXT4-fs (vdb): recovery
complete` dmesg line, plus the recovery entry point cited
(`jbd2_journal_recover` and its passes); (b) the **survival matrix**:
fsync'd file present *with its data*; unsynced file **gone entirely**
— not truncated, not empty: absent — explain both fates from the
transaction contents (where was each file's metadata? its data?);
(c) the **consistency claim**: the filesystem needed no fsck — argue
from (a) what replay guarantees and what it deliberately does not;
(d) the **mode contrast**: remount the scratch disk `data=journal`
(read the mount line carefully — it silently turned something else
off; connect that something to batch 9) and **predict, in writing,
what changes in your survival matrix** before rerunning the pair.
Then run it. If your matrix reads identical — explain *why this
particular experiment cannot distinguish the modes* (what would each
file's data have needed to be, for the journal to make the
difference?) and describe one experiment that could. Independently,
quantify the mode's streaming-write tax (a 48 MiB `conv=fsync` write:
~2.7× slower here) and say where the second write goes.

**Required evidence**
- The scripted crash loop (kill → re-up → mount → dmesg + inventory),
  reproducible in one command.
- The survival matrix for both mounts — with the written prediction
  committed as predicted, and the reads-identical explanation if that
  is what you find.
- The throughput contrast ordered vs journal, honest about TCG.
- `repro.sh`: run the ordered-mode loop, assert recovery line
  present, synced content intact, unsynced absent. (The data=journal
  leg may be a second script or a flag — say which.)

**Tools:** `SCRATCH=` + `tools/vm kill` (header note), `dmesg`,
`dumpe2fs`, your batch-9 writer or `dd` for the throughput leg, `tools/ksrc
view fs/jbd2/recovery.c`.

**At the defense, expect:** Kill *during* an fsync instead of after —
enumerate the states the scratch fs can be in and which your replay
evidence rules out. Why is `unsynced.txt` absent rather than empty —
what single missing piece removed it? Re-run your pair but fsync the
**directory** instead of the file — predict, then explain. Your
throughput tax number — where exactly does the second write happen,
and which tracepoint from the journal question would prove it?

---

## ext4-mutation-01 — The healthy-looking mutant *(Q3, Wednesday)*

The image `bzImage-2026f-04` differs from the pinned kernel by
exactly one private modification somewhere in `fs/ext4/` or
`fs/jbd2/`. Characterize it.

The contract is batch 6's — experiment matrix with negatives, a
quantified signature, a mechanism hypothesis, a verdict placing it in
one of the three classes. Two notes specific to this subsystem: (1)
this layer's job is a *promise about a future failure* — a mutation
can leave every normal-operation number identical and still be the
most broken kernel this course ships; your matrix should say what the
subsystem *guarantees*, not just what it does; (2) the crash loop
from ext4-crash-01 is a differential instrument like any other — same
script, two kernels, compare inventories. `uname -r` is identical, on
purpose, as always.

**Required evidence**
- The experiment matrix: normal-operation probes AND
  guarantee-probes, stock vs mutant, changed and unchanged both
  reported.
- The quantified signature with raw captures from both kernels.
- The hypothesis, argued from behavior to mechanism; the verdict,
  argued from the *named* guarantee.
- `repro.sh`: takes the image path, runs against both kernels,
  asserts your signature differentially.

**Tools:** everything — and note that all three other questions of
this batch built instruments.

**At the defense, expect:** On-the-spot: "run your signature on this
third image." If your hypothesis names a function, what *adjacent*
behavior should also have changed — did you check? A sysadmin runs
this mutant in production for a month and sees nothing; a power cut
ends the month — write their incident report's root-cause paragraph.
What one-line userspace workaround closes the hole your mutant opens
(there is one; finding it bounds the mutation exactly)?

---

*Connection to what's next: every journal write and every flush you
traced this week entered a queue you haven't looked at. Batch 11 is
the block layer: a bio's life from the page cache to the virtual
disk, request merging, and who decides what the device sees first.*
