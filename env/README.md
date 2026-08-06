# Reference Environment

QEMU + pinned Linux kernel (6.6.87, x86_64) + Debian bookworm rootfs with the
course tracing toolchain (bpftrace, trace-cmd, gcc, python3). All Linux-side
builds run inside an amd64 Docker container, so the same scripts work on
macOS (Apple Silicon or Intel) and Linux hosts. The full flow (host setup →
`make images` → `make smoke`) is tested and passing on both macOS
(Apple Silicon) and Ubuntu x86_64. Versions are pinned in
[`config.sh`](config.sh); the kernel's observability contract is
[`kernel/kernel-lens.fragment`](kernel/kernel-lens.fragment).

## Quick start

```sh
# 1. One-time host setup (macOS; installs qemu + colima via Homebrew)
make setup

# 2. Build kernel + rootfs images into dist/  (first run: ~30-60 min)
make images

# 3. Verify everything works
make smoke

# 4. Boot an interactive VM (login: root, auto-login on console; exit: Ctrl-a x)
make run
```

Anything fails or misbehaves: `make doctor` (fast self-diagnosis), then
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) — the playbook for every known
failure mode, written to be actionable by your agent.

`make setup` detects your OS and runs the right script (`make setup-macos` /
`make setup-linux` force one). On Linux it installs qemu, docker and the
build tools, and adds you to the docker/kvm groups — **re-login after the
first run**, then continue from step 2. On x86_64 with `/dev/kvm` the VM
runs hardware-accelerated automatically. `make help` lists every target.

## Using the VM

| Task | How |
|---|---|
| Console | `./run.sh` — serial console, root auto-login |
| SSH | `ssh -p 2222 root@localhost` (password: see `config.sh`) |
| Share a host dir | `SHARE=/some/dir ./run.sh` → appears at `/share` in guest |
| **Boot a different kernel** | `KERNEL=/path/to/bzImage ./run.sh` — same rootfs, another image. **This is how you boot a mutation image** (`KERNEL=... tools/vm up` works too) |
| Scripted / headless boot | `HEADLESS=1 ./run.sh` (no console on stdio); `CONSOLE_LOG=/path/console.log` captures the serial output |
| **Second disk** (crash experiments) | `SCRATCH=/path/img ./run.sh` → `/dev/vdb`, created 512 M if missing. `mkfs.ext4` it in the guest and keep crash tests off the rootfs |
| Make the disk slow (on purpose) | `SCRATCH_BPS=8388608` (bytes/s), `SCRATCH_IOPS=300`, `SCRATCH_QSIZE=8` (virtio queue depth) — a fast disk never queues, so queueing has to be manufactured |
| Run a script at boot | put `autorun.sh` in the shared dir; output → `autorun.log`, exit code → `autorun.exit` |
| Kernel debugging | `./run.sh -g` (VM waits, frozen), then **`scripts/gdb.sh`** in another terminal — runs gdb inside the amd64 build container, so no host gdb is needed on either platform; extra args pass through (`scripts/gdb.sh -ex 'break do_sys_openat2' -ex continue`). KASLR is off, so vmlinux symbols match runtime addresses |
| Tracing | tracefs at `/sys/kernel/tracing`, `bpftrace`, `trace-cmd` preinstalled |

## Working on the kernel source

| Task | How |
|---|---|
| Browse the source | `make src-export` copies the pinned tree to `env/src/` (host-side **browsing only** — the build does not read it) |
| Edit and rebuild | `make src` opens a shell inside the build container on the real tree, then `make kernel` rebuilds incrementally (the Docker cache volume keeps it fast) |
| Rebuild only the rootfs | `make rootfs` |
| Start over | `make clean` (keeps downloads) / `make distclean` (removes everything) |

The **autorun channel** (9p share + `kl-autorun.service`) is the deterministic
host→guest execution path: the smoke test uses it, and in-class re-runs and
spot replays of report repro scripts use the same mechanism.

## Performance expectations

On Apple Silicon the x86_64 guest runs under TCG (emulation). Measured on an
M-series host: boot-to-login ≈ 10 s; heavy in-guest work (large compiles) is
where TCG cost shows. This is fine — the course grades kernel *behavior*,
which is identical under TCG, and builds happen in the (Rosetta-accelerated)
container, not the VM. On x86_64 hosts QEMU uses KVM/HVF automatically.

## Beyond the pinned kernel (after the course)

The 6.6.87 pin exists for grading reproducibility, not as a limitation of the
tooling. `KERNEL_VERSION` in [`config.sh`](config.sh) is a parameter: point it
at any kernel.org release, run `make images`, and your agent and probe
libraries work against that kernel — this environment is meant to outlive the
course as a personal kernel-investigation rig. Expect minor upkeep across
major versions: config-fragment options occasionally get renamed, and probe
attach points can shift as functions are renamed or inlined (you have already
seen `wp_page_copy` disappear into `do_wp_page` — diagnosing that kind of
drift is exactly what the course trained you for).
