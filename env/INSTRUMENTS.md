# The instruments

Everything batch 1 needs is already in the VM. This is a short tour of the
two you will actually use; the questions tell you which one they want.

## 1. tracefs — the kernel's own tracer

It is a filesystem. Everything below is reading and writing files.

    T=/sys/kernel/tracing
    ls $T/events                 # one directory per event group
    ls $T/events/syscalls        # named syscall events live here

Capture by hand — enable an event, run your workload, read the buffer:

    echo 1 > $T/events/raw_syscalls/sys_enter/enable
    echo > $T/trace                       # clear
    echo 1 > $T/tracing_on
    ./your-program
    echo 0 > $T/tracing_on
    cat $T/trace

`trace-cmd` does the same thing with less ceremony, and can follow a
program you launch:

    trace-cmd record -e raw_syscalls:sys_enter -F -o t.dat ./your-program
    trace-cmd report -i t.dat

When you are done: `trace-cmd reset`. A left-over enabled event turns into
mystery noise in your next capture.

### Isolate your process — this is the graded part

A plain capture records the *whole system*. Your program's events are in
there, mixed with everyone else's. Three ways to cut it down:

- `trace-cmd record ... -F ./prog` — follow only the program it launches.
- `echo <pid> > $T/set_event_pid` — restrict tracefs to one pid.
- Per-event filters: `echo 'common_pid==1234' > $T/events/<ev>/filter`.

Worth knowing before it confuses you: **your capture starts before your
program does.** `-F` launches the process, and the syscalls between the
fork and the `execve` still belong to the shell — but the trace labels
them with your program's name, because it resolves a pid to the name that
pid has *now*. Split your trace at `execve` and the two halves make sense.

### Two things that will waste your evening

- **Flag order.** `trace-cmd record -e EV -F -o out.dat ./prog` works.
  Put `-F` or `-o` *after* the command and trace-cmd records **0 events
  and tells you nothing** — it read them as arguments to your program.
- **`raw_syscalls` gives numbers, not names.** `NR 39` is getpid. Decode
  against `/usr/include/x86_64-linux-gnu/asm/unistd_64.h`, or skip the
  problem and use the named events under `$T/events/syscalls/` instead.
- **`trace-cmd report` hides fields.** For `sched_switch` it pretty-prints
  a bare `R` and drops `prev_state=` entirely, so grepping for it finds
  nothing. `-N` turns the pretty-printer off and shows the real fields;
  `-R` gives raw values.

## 2. /proc — maps and pagemap

`/proc/<pid>/maps` is the process's memory layout, one line per region:

    cat /proc/<pid>/maps

`/proc/<pid>/pagemap` says whether a given virtual page is actually backed
by physical memory. It is binary: one 8-byte entry per page, indexed by
page number. Bit 63 is *present*, bits 0–54 are the PFN. You are root, so
the PFN is readable.

    # seek to (vaddr / 4096) * 8, read 8 bytes, unpack little-endian
    f.seek(vaddr // 4096 * 8)
    entry, = struct.unpack("<Q", f.read(8))
    present = bool(entry >> 63)
    pfn     = entry & ((1 << 55) - 1)

**Transparent huge pages will lie to you.** This VM boots with THP
`[always]`. Touch one byte and the kernel may back 2 MB, so pages you
never touched come back present and your conclusion is wrong. Check
`AnonHugePages` in `/proc/<pid>/smaps` **for the region you care about**
(not the first one in the file), and turn it off before drawing
page-granular conclusions — `madvise(p, size, MADV_NOHUGEPAGE)` on your
region, or `echo never > /sys/kernel/mm/transparent_hugepage/enabled`.
With THP out of the way the numbers come out clean.

## At the defense

You re-run your own evidence, live, on a clean boot, and explain it. So
whatever you capture, make sure `repro.sh` actually reproduces it from
nothing — and that you can say what every command in it is for.
