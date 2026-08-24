# Batch 9 — `fs/` + `mm/filemap.c`: what a file costs

*On the docket: Monday, week 9 (assignment sheets ship that day; the
questions have been public since before week 1). Defended: week 10 — **Monday:
vfs-lookup-01, vfs-readpath-01 · Wednesday: vfs-readahead-01,
vfs-writeback-01**. You are assigned two of the four. No mutation this
week — batch 10 carries the next one.*

*Two standing tools for this batch: the `filemap:` tracepoints
(`mm_filemap_add_to_page_cache` / `_delete_from_page_cache` — the page-cache
**ledger**, with `i_ino` and `index` fields) and the `writeback:` family. Two
standing cautions: `drop_caches` evicts *everything*, including your own
binaries' text pages and the dentries of paths you didn't think you were using
(1 = page cache, 2 = dentries+inodes, 3 = both — pick the control that matches
the claim); and after a drop, the dynamic loader's own lookups and reads
pollute any unfiltered capture — attribute by `i_ino`, by component string, or
by per-phase deltas inside one process, never by "it happened while my command
ran". Reports: `reports/batch-09/<question-id>/`, [course-design.md
§7](../../docs/course-design.md) schema, `repro.sh`. Budget ~3–4 focused hours
per question.*

---

## vfs-lookup-01 — The name tax, paid once *(Q1, Monday)*

Every syscall that takes a path pays a per-component walk before any
real work happens. Make the cost and the cache visible. Build a deep
directory chain (7+ components) and produce: (a) **the cold walk**:
after the dcache-specific drop, one `stat()` of the full path, with
probe evidence that the slow path ran **once per component** — name
them; (b) **the hot walk**: repeat the `stat()` and show the slow-path
count for your path is now **zero** — same syscall, same result, all
answered from the dcache; (c) **absence, cached**: `stat()` a
nonexistent name in your deepest directory twice; show the first miss
takes the slow path and the second doesn't, *while both return
ENOENT* — the dcache caches negative answers too; explain what a
negative dentry is and cite where the walk short-circuits on one; (d)
the **anatomy paragraph**: cite the walk loop, the fast path, the
slow path's call, and state which of these functions you could and
could not probe directly (check kallsyms — this layer has an inlining
roster of its own, and finding the probeable anchor *is* part of the
question).

**Required evidence**
- Per-component slow-path fires for the cold walk (component names
  visible in the capture), the hot-walk zero, and the
  negative-lookup pair.
- Source cites: walk loop, fast lane, slow-lane call site, and a
  `d_is_negative` short-circuit.
- The kallsyms/attach evidence for what is probeable here.
- `repro.sh`: build the chain, cold walk — assert slow fires ≥ path
  depth and component names present; hot walk — assert zero new
  fires for your components; negative pair — assert 1 then 0.

**Tools:** `kprobe:__lookup_slow` (its first argument is a
`struct qstr *` — mind that `str()` on its `name` runs to the NUL,
so you'll see the *remaining path suffix*, not one component; the
`len` field is the component boundary — use the suffix as a free
component label), `kprobe:d_alloc`, `echo 2 > drop_caches`,
`tools/ksrc view fs/namei.c`.

**At the defense, expect:** Your cold capture has slow-path fires for
names you never typed (loader config files, nscd sockets) — where do
they come from, and how did your filtering exclude them? A path
component is a symlink — what does the walk do differently? Why does
the kernel bother caching ENOENT — name a workload where that's the
whole ballgame. `stat` twice in two *processes* vs twice in one — did
your hot-walk evidence distinguish those, and does it need to?

---

## vfs-readpath-01 — One copy, and a ledger that proves it *(Q1, Monday)*

The page cache is where file data lives; reads are visits, not
copies-from-disk. Instrument the full journey. Produce: (a) the
**path**: source-cite the chain from `read(2)` to the function that
actually finds the folios — syscall entry through `vfs_read`, the
`f_op` dispatch (name the concrete ext4 entry), into
`mm/filemap.c` — and one kstack from a pid-filtered probe on the
page-cache read function proving your read went through it; (b) the
**ledger**: a cold sequential read of a multi-MiB test file with
`mm_filemap_add_to_page_cache` counted **for your file's inode**
— ≈ one add per 4 KiB page; then the immediate re-read: **zero**
adds, same bytes delivered (state where they came from); then
`drop_caches=1` with the delete tracepoint counted — the folios
leaving; (c) the **non-member**: read a `/proc` file with the same
instrumentation and show the ledger stays silent no matter how much
you read — explain what `f_op` dispatch means for "everything is a
file"; (d) `/proc/meminfo` `Cached` deltas corroborating (b).

**Required evidence**
- The cited chain + the kstack through it.
- Add/delete counts per phase, inode-filtered, with the hot-read
  zero explicit; the meminfo corroboration.
- The `/proc` negative control with its mechanism explanation.
- `repro.sh`: cold — assert adds ≈ file pages within tolerance; hot —
  assert zero adds for your ino; drop — assert deletes ≥ adds·0.9;
  proc-read — assert zero ledger entries.

**Tools:** `filemap:mm_filemap_add_to_page_cache` (filter
`args->i_ino`; have your trigger print its ino), a sequential reader
you write, `kprobe:filemap_read`, `tools/ksrc grep read_iter
fs/ext4/file.c`.

**At the defense, expect:** Your hot read moved bytes with zero adds —
walk me from `filemap_get_pages` to the copy into your buffer: what,
exactly, is "hot" (which structure was hit)? Two processes read the
same file — how many copies in RAM, and what evidence of yours shows
it? `dd` your file after `drop_caches=1` but read it via `mmap` +
touches instead — which of your instruments still fire, and which
change (careful — batch 5 lives here)? Where does the 4 KiB
granularity of your ledger come from, and could a folio be bigger?

---

## vfs-readahead-01 — The kernel reads ahead of you *(Q2, Wednesday)*

Batch 3 told you readahead flattens small-read latencies; this week
you catch it in the act. For a cold sequential 4 KiB-read loop over a
multi-MiB file, produce: (a) the **division of labor**: fire counts
for the synchronous entry (`page_cache_sync_ra`) vs the asynchronous
one (`page_cache_async_ra`) — on this kernel the sequential loop
shows **one** sync fill and a few dozen async refills; explain the
pipeline: what the *marker folio* is (cite where it's tested and what
it triggers), and why the reader almost never waits after the first
miss; (b) the **window growth**: evidence that the readahead window
ramps up (cite the doubling function and its cap; connect the cap to
`read_ahead_kb` of your device); (c) the **contrast**: the same loop
with `POSIX_FADV_RANDOM` — the sync/async split inverts (≈ one sync
fill *per read*, async silent); state what the advice changed in
`file_ra_state` terms; (d) the **honesty tie-back**: one paragraph
connecting (a)–(c) to your batch-3 cold/hot experiment — why 4 KiB
cold reads looked hot, and what read size would have paid its own
I/O.

**Required evidence**
- sync/async fire counts, both modes, plus the inode-filtered add
  ledger showing bursts vs per-read fills.
- Source cites: sync/async entries, the marker-folio test site, the
  window-growth function, the cap.
- The fadvise call in your trigger + both mode outputs.
- `repro.sh`: sequential — assert sync ≤ a small constant and async ≥
  10; random — assert sync ≈ read count and async ≈ 0.

**Tools:** your reader from the previous question, extended with a
`POSIX_FADV_RANDOM` mode (one flag, two behaviours — keep it one
program and print the file's ino either way),
`kprobe:page_cache_sync_ra`, `kprobe:page_cache_async_ra`,
`mm_filemap_add_to_page_cache` index field,
`/sys/block/vda/queue/read_ahead_kb`, `tools/ksrc view
mm/readahead.c`.

**At the defense, expect:** Predict the sync/async split for
stride-2 reads (every other page) — then check. Your async refills
each added ~32 pages — who *issued* that I/O, in whose context, and
who slept? If two processes stream the same file 1 s apart, what does
the second one's split look like? `read_ahead_kb` to 0 — which of
your numbers change and which don't (careful: is that knob the cap or
the mechanism)?

---

## vfs-writeback-01 — Your write returns; the disk finds out later *(Q2, Wednesday)*

A buffered `write()` is a memory operation with a promise attached.
Trace the promise. Produce: (a) **the write moment**: write a few MiB
buffered (start with 4 MiB); show `Dirty` in `/proc/meminfo` jumping
by ≈ the bytes written, the `writeback_dirty_folio` tracepoint
counting your folios (≈ one per 4 KiB), and `block:block_rq_issue`
**silent** for the data during the write itself — the syscall
returned, the disk heard nothing; (b) **the age trigger**: keep the
system idle and sample `Dirty` once per second for ≥45 s — your 4 MiB
stays dirty for tens of seconds, then drains *without any action from
you*; correlate the drain with `writeback_start` events (the `reason`
field is an enum — the event's format file maps the numbers to names)
and with the first write-direction `block_rq_issue`; state the two
`vm.dirty_*` knobs whose values explain the cliff's timing (which
sets the floor, which the jitter), and which kernel thread did the
work; (c) **the pressure trigger**: read the live background
threshold from `/proc/vmstat`'s `nr_dirty_background_threshold`
(≈180 MiB on this VM — connect it to `dirty_background_ratio`), then
repeat (b) writing enough to cross it (256 MiB) — the drain now
starts within seconds, under a *different* reason, before your
sampling loop barely begins; (d) **the explicit trigger**: write then
`fsync` — `Dirty` drains immediately; (e) the **verdict paragraph**:
what exactly was promised at `write()` return, what at `fsync()`
return, and what a power cut in between each pair would have done —
cite, don't vibe (the crash story continues in batch 10).

**Required evidence**
- Dirty before/after write, the dirty-folio count, the block-layer
  silence in the write window.
- The 4 MiB per-second timeline with its ~30–35 s cliff, decoded
  reasons, first-write-issue timing, and the two knobs cited.
- The 256 MiB timeline with its early drain, its decoded reason, and
  the threshold readback it crossed.
- The fsync contrast.
- `repro.sh`: write phase — assert Dirty delta ≥ ~0.8× bytes and zero
  write issues in the write window; fsync phase — assert Dirty
  returns near baseline and write issues > 0; assert the 256 MiB
  drain strictly earlier than the 4 MiB drain. (The full 4 MiB timeline is
  report evidence; asserting the exact cliff second would fight the
  5 s scan jitter — bound it instead.)

**Tools:** a buffered-writer trigger you write (write N MiB, print
`/proc/meminfo` `Dirty` before/after, optional `fsync`, and a
once-per-second Dirty sampler for the timeline),
`writeback:writeback_start` (int `reason`;
enum map in its format file), `writeback:writeback_dirty_folio`,
`block:block_rq_issue` (`rwbs` field, `W` prefix),
`/proc/sys/vm/dirty_*`, `/proc/vmstat`, `tools/ksrc grep wb_thresh
mm/page-writeback.c`.

**At the defense, expect:** Your 4 MiB survived two jbd2 commit
cycles before the cliff — the journal committed at ~5 s and your
data pages did NOT go with it; what does that tell you about what's
in an ext4 transaction under delayed allocation (batch 10 opens this
door — walk through it as far as you can)? Decompose the 30–35 s
cliff into its two knobs. The kworker did your I/O — who gets billed,
and how would batch 6's instruments show it? On a freshly booted,
otherwise-idle VM, even a 32 MiB write sometimes drains within
seconds — no *global* number explains that; what does the writeback
code compute *per device*, and what makes it grow (`tools/ksrc grep
wb_calc_thresh`)? `fsync` returned — is your data on a *platter*?
What does this VM's virtio disk promise, and where would you look
next week?

---

*Connection to what's next: `fsync` above was a black box that made
`Dirty` vanish. Batch 10 opens it: ext4's journal — what, exactly, is
written where before your data is safe, and what a crash between the
steps leaves behind.*
