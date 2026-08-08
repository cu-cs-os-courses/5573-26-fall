# Batch 11 — `block/`: where I/O becomes hardware's problem

*Released: Monday, week 11. Defended: week 12 — **Monday: blk-bio-01,
blk-size-01 · Wednesday: blk-queue-01, blk-complete-01**. You are
assigned two of the four. No mutation this week — batch 12 carries
the last one.*

*Env update shipped with this batch (pull the offering repo): the scratch disk
can now be **throttled** — `SCRATCH_IOPS=` (request rate), `SCRATCH_BPS=`
(byte rate), `SCRATCH_QSIZE=` (virtio queue depth) on `vm up` — and both disks
are now explicit drive/device pairs so the disk order is pinned. Why you'd
throttle a perfectly good disk is Wednesday's first question. A warning that
is also a hint, for the whole batch: several textbook stories about this layer
are **decades older than your storage stack** — when your measurement
contradicts the story, the measurement is the assignment. Reports:
`reports/batch-11/<question-id>/`, [course-design.md
§7](../../docs/course-design.md) schema, `repro.sh`. Budget ~3–4 focused hours
per question.*

---

## blk-bio-01 — Follow one bio to the metal *(Q1, Monday)*

Take one cold sequential read of a multi-MiB file on the scratch disk
and account for every block-layer event it generates. Produce: (a)
the **census**: counts of `block_bio_queue`, `block_rq_issue`,
`block_rq_complete` for the read (device-filtered), and the
explanation of the ratio you find (how many pages per bio? who chose
that number — you met the mechanism in batch 9); (b) the
**biography**: for a handful of individual requests, the
queue→issue→complete timeline joined by `(dev, sector)`, with
issue→complete as the device-service-time distribution; (c) the
**grounding**: use `filefrag -v` to predict, *before capturing*,
which sector range a targeted 128 KiB read of a chosen file offset
must touch — then show the captured sectors match the arithmetic
(state the sector-unit and block-size conversion explicitly); (d) the
**chain of custody** paragraph: cite the path from `submit_bio`
through `blk_mq_submit_bio` to the issue and completion tracepoints,
and state which layers above already decided everything the block
layer merely carries out.

**Required evidence**
- The three counts + ratio explanation; the per-request joined
  timelines.
- The written sector prediction (committed as predicted) and the
  matching capture.
- Source cites: submit_bio → blk_mq_submit_bio → rq_issue site →
  rq_complete site.
- `repro.sh`: cold read — assert bio_queue ≈ rq_issue ≈ completes
  within tolerance and ≥90% of predicted sectors observed.

**Tools:** `block:block_bio_queue`/`block_rq_issue`/
`block_rq_complete` (join on `args->sector`, filter `args->dev`),
`filefrag -v`, your batch-9 sequential reader, `tools/ksrc view
block/blk-core.c block/blk-mq.c`.

**At the defense, expect:** Your bios were 128 KiB — change
`read_ahead_kb` to 32 and predict all three counts. Which event in
your chain is the *last* moment the kernel can cheaply cancel this
I/O, and what exists after it? The `sector` field of a bio on `vda`
vs `vdb` — same arithmetic? (What would a partition change?) Two
files, same content — same sectors? Why (not)?

---

## blk-size-01 — Who decides how big an I/O is *(Q1, Monday)*

The textbook says the block layer merges small requests into big
ones. Test that story on three workloads, capturing for each:
`block_bio_queue` count, `block_rq_issue` count + size histogram
(`args->bytes`), `block_bio_backmerge` count, and `block_split`
count. The workloads: (1) buffered sequential read of 4 MiB (cold);
(2) a **single** 4 MiB `O_DIRECT` read (one `read()` call, aligned
buffer); (3) a 4 KiB-per-call `O_DIRECT` sequential loop over the
same span. Then explain the three signatures: who built the I/O size
in each case and *at which layer*; where the device's size cap
(`max_sectors_kb` — read it) bit, and which tracepoint showed it;
and the merge question — your backmerge counters read a number the
textbook doesn't predict: state precisely what two conditions a
back-merge needs, and why **each** workload denies at least one of
them. Cite the merge machinery you never saw fire (the function
behind the backmerge tracepoint, and the plug-list merge entry) and
the plug events that show where co-queueing would happen.

**Required evidence**
- The 3×4 counter matrix + size histograms, device-filtered.
- The per-workload size-decision explanation with layer named.
- The two merge preconditions + per-workload denial argument, with
  merge-machinery and plug source cites.
- `repro.sh`: workload (2) — assert bio_queue == 1, split ≥ 2, max
  request size within [1024,1280] KiB; workload (3) — assert
  rq_issue ≈ read count and backmerge == 0.

**Tools:** the four `block:` events above + `block_plug`/
`block_unplug`, `dd iflag=direct` / your batch-9 reader,
`/sys/block/vdb/queue/max_sectors_kb`, `tools/ksrc view
block/blk-merge.c`.

**At the defense, expect:** Design a workload that WOULD produce
back-merges on this kernel — what has to be true, and which of your
tools could generate it? Your one 4 MiB bio: how does it hold 1024
pages (what changed in bio anatomy since the textbook — one word)?
If `max_sectors_kb` were 64, predict workload (2)'s three counters.
Where did the *front*-merge tracepoint fire? (Trick question — argue
from your data.)

---

## blk-queue-01 — Manufacturing a traffic jam *(Q2, Wednesday)*

On this VM, `/sys/block/vdb/queue/scheduler` reads `[none]` — the
kernel ships a no-op scheduler by default for this device class, and
this question is about *earning* that fact. Produce: (a) **the
missing queue**: under an unthrottled write flood + random reads,
sample `/sys/block/vdb/inflight` and show the queue never builds
(sync I/O caps in-flight at 1 structurally — show that too with a
sync loop); state why a scheduler with an empty queue is pure
overhead; (b) **scarcity, manufactured**: re-up the scratch disk
with `SCRATCH_BPS=8388608 SCRATCH_QSIZE=8` and repeat — inflight
pins at the device cap, and your random-read p50 under flood moves
from µs to **hundreds of ms**; report both distributions; (c) **the
scheduler test the textbook demands**: with the backlog sustained,
A/B `none` vs `mq-deadline` on the read distribution — **predict the
outcome in writing first**. Then report what you measure, and
explain it with arithmetic: request sizes × device rate = how much
*device time* the in-flight requests represent, and which side of
the `block_rq_issue` boundary the scheduler controls. (d) Close with
one paragraph: what would have to change on this topology for
`mq-deadline`'s read preference to show — name the knob(s) and the
workload shape.

**Required evidence**
- inflight timelines + read distributions for unthrottled and
  throttled runs; the sync depth-1 demonstration.
- The written A/B prediction (committed as predicted) and both
  measured distributions.
- The device-time arithmetic and the dispatch-boundary source cite
  (the deadline dispatch entry point).
- `repro.sh`: throttled — assert flood-read p50 ≥ 100× the
  unthrottled flood-read p50 and inflight max ≥ QSIZE-1. (The A/B
  leg is report evidence — asserting a *null* result is the report's
  job, not a gate.)

**Tools:** `SCRATCH_BPS=`/`SCRATCH_QSIZE=` (header note),
`/sys/block/vdb/inflight`, a random O_DIRECT reader (write it — an
aligned-buffer pread loop; the library grows one this week),
`/sys/block/vdb/queue/scheduler`, `tools/ksrc view
block/mq-deadline.c`.

**At the defense, expect:** Your prediction was probably wrong —
defend the *measurement* against "you just didn't load it right"
(what did inflight prove?). Where exactly does a request stop being
the scheduler's to reorder — show the line. Your 150 ms p50: decompose
it (token bucket? queue wait? service?). If the flood were 4 KiB
O_DIRECT sync writes instead of writeback, what changes in the whole
picture? `kyber` exists on this kernel too — what is its bet, one
sentence?

---

## blk-complete-01 — The bio's death, in someone else's context *(Q2, Wednesday)*

I/O completion is the half of the block layer nobody instruments
until it surprises them. For a cold sequential read on the scratch
disk, produce: (a) **whose context**: tally `block_rq_complete`
events by `comm` and CPU — the names you find are *not* kernel I/O
threads; explain what they actually are (what does `comm` mean
inside an interrupt handler?) and why one of them is probably your
own reader; (b) **the interrupt ledger**: over the same window,
delta the virtio-blk row of `/proc/interrupts` (batch-8 discipline)
and relate its count to your completion count; (c) **the service
meter**: the issue→complete latency histogram per request (joined by
sector), on the unthrottled disk — and once more on the throttled
disk from blk-queue-01, showing what the throttle did to *service
time* vs what it did to *queue wait* (which histogram moved?); (d)
**the resurrection chain**: cite the path from the completion
tracepoint through `blk_mq_complete_request` to the folio unlock,
and close the loop with batch 6: show (kstack or tracepoint
correlation) that the completion context is where your sleeping
reader's wakeup originates — the waker in batch 6's pipe story was a
process; here it is an interrupt.

**Required evidence**
- The comm/CPU tally with the borrowed-context explanation.
- The interrupt-line delta vs completion count.
- Both issue→complete histograms (unthrottled/throttled) with the
  moved-vs-unmoved reading.
- The cited completion chain + the wakeup-origin evidence.
- `repro.sh`: unthrottled cold read — assert completes ≈ issues,
  and the wakeup-origin evidence present (probe fired in irq-context
  with your reader as the wake target).

**Tools:** `block:block_rq_complete` (+ `comm`, `cpu` builtins),
`/proc/interrupts`, `kprobe:try_to_wake_up` (batch 6's instrument,
now aimed at an interrupt's stack), `tools/ksrc view block/blk-mq.c`.

**At the defense, expect:** Your completion events carry your
reader's comm — was your reader *executing*? (What was?) Why does the kernel
finish I/O in interrupt context instead of handing it to a worker —
and name a subsystem from this course that made the opposite choice
(batch 9 has one). If two CPUs both read, which one completes a
given request — what pins it? What happens to your histogram if the
completion work itself were slow — which other measurements in this
course did *that* effect contaminate (batch 6 has one)?

---

*Connection to what's next: this was the last subsystem tour stop
with hardware at the bottom. Batch 12 turns inward: the locks and
RCU grace periods that kept every structure you've traced this
semester from tearing — made visible, under load, on purpose. It
carries the last mutation.*
