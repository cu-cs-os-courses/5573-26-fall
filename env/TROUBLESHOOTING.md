# Troubleshooting the environment

Start every environment problem the same way:

```sh
cd env && make doctor
```

It checks your host, toolchain, and built images in seconds and points at
the matching section below. If doctor is green but the VM misbehaves,
`make smoke` is the full acceptance test (boots headless, verifies the
observability contract, and **keeps its work directory on failure** — the
console log in there is your evidence).

**What this file covers:** getting the environment itself to work — host
setup, builds, booting, ssh, gdb, mutation images. **What it deliberately
does not cover:** probes that don't fire, traces that look wrong, counts
that surprise you. That is not a support issue — "my probe doesn't fire"
is a kernel investigation, and doing it with the course's method is the
course working as intended (syllabus §10).

Feed this file to your agent. It is written to be actionable by an agent
running on your machine, not just by you.

---

## Unsupported hosts

macOS and Linux only. **Windows — including WSL — is unsupported**: the
course cannot debug Windows-specific virtualization and file-sharing
behavior, and no course machinery is tested there. If a Windows machine is
all you have, email the instructor *now*, before the first batch, not the
night a report is due.

## Host setup, macOS

`make setup` installs qemu, colima, and the docker CLI via Homebrew, then
starts colima (on Apple Silicon: `--vm-type vz --vz-rosetta`, which makes
amd64 build containers fast). Failure modes:

- **"Homebrew is not installed"** — install it from https://brew.sh, then
  re-run `make setup`. Every step is skip-if-done; re-running is safe.
- **colima exists but was created with the wrong settings** (builds crawl
  while doctor is green): you likely ran `colima start` yourself before
  the course, without the course flags. `colima status` must say
  `macOS Virtualization.Framework`; if it says QEMU — or it says vz but
  amd64 builds are still painfully slow (Rosetta off) — reset:
  `colima delete && make setup` (destroys only the Docker VM, not your
  images in `env/dist/` — those live on the host filesystem; the source
  cache volume *is* lost and `make images` re-fetches it).
- **`docker: command not found` but Docker Desktop is installed** — the
  course uses the docker *CLI* against colima; Docker Desktop also works
  (any reachable Docker daemon does). Don't run both daemons at once.

## Host setup, Linux

`make setup` uses apt (Ubuntu/Debian): qemu, docker.io, build tools, and
adds you to the `docker` and `kvm` groups. It installs docker.io only if
you have no `docker` on PATH already — any working Docker is fine.
Non-apt distros: read `scripts/host-setup-ubuntu.sh` — it is short — and
install the same list with your package manager.

- **`containerd.io : Conflicts: containerd`, setup exits 100** — you
  installed Docker CE from docker.com's apt repo, and its `containerd.io`
  package is incompatible with the `containerd` that `docker.io` depends
  on. apt cannot satisfy both and refuses. **You already have what the
  course needs** — Docker CE is strictly newer than docker.io. Skip
  `make setup` and confirm with `make doctor`; if it is green, go
  straight to `make images`. (Setup also adds you to the `docker` and
  `kvm` groups — `id -nG` to check, section below if either is missing.)

## Groups and re-login (Linux)

Group membership (`docker`, `kvm`) takes effect at **login**, not when the
setup script adds you. Symptoms of a stale session: `permission denied ...
docker.sock`, or doctor warning about `/dev/kvm` access. Log out and back
in (or reboot); `id -nG` should list both groups.

## Docker daemon unreachable

`Cannot connect to the Docker daemon` — the single most common failure:

- **macOS:** colima does not survive reboots. `colima start`, wait ~30 s,
  re-run `make doctor`. (`brew services start colima` makes it automatic.)
- **Linux:** `sudo systemctl enable --now docker`; if you were just added
  to the docker group, re-login (section above).

## Disk space

Budget ~20 GB: the Docker build image plus the kernel source-and-objects
cache volume (the big one), plus `env/dist/` (rootfs 4 GB + kernel
images). Reclaim, in order of increasing severity:

1. Delete other projects' Docker debris: `docker system prune` (does not
   touch the course volume).
2. `make clean` — removes `env/dist/`; `make images` rebuilds from cache
   in minutes.
3. `make distclean` — also removes the source cache volume; the next
   `make images` is a full ~30–60 min rebuild. Last resort.

On macOS the Docker side lives *inside colima's* 60 GB disk — host `df`
won't show it filling. `docker system df` shows the truth.

## Building images

`make images` needs the network twice: kernel.org (source tarball, first
time only) and deb.debian.org (rootfs packages). Failure modes:

- **Interrupted or flaky-network build:** just re-run `make images`. The
  build is incremental and resumes; nothing needs cleaning first.
- **`make kernel` finishes but the VM still boots the old kernel:** boots
  use `env/dist/bzImage` — check its timestamp. The build copies it there;
  a failed copy (disk full) leaves the old one.
- **doctor: "bzImage does not look like 6.6.87":** versions drifted
  between `config.sh` and your build — `make kernel` refreshes it.
- **Smoke test times out:** check the `console.log` path the script
  prints. The most common cause is a partial `dist/` from an interrupted
  build — `make clean images`.
- **bpftrace errors about BTF:** `dist/bzImage` and `dist/rootfs.ext4`
  are out of sync with each other — rebuild both (`make images`).
- **`rosetta error: Unable to open /proc/self/exe`:** something is trying
  to chroot into an amd64 tree on Apple Silicon; Rosetta cannot execute
  inside a chroot. The rootfs is deliberately built as a Docker image and
  docker-exported (see `docker/rootfs.Dockerfile`) to avoid chroot
  entirely — don't introduce one.
- **`No rule to make target 'net/netfilter/xt_TCPMSS.o'`** (or similar
  odd-missing-file errors): the kernel tree ended up on a
  case-insensitive filesystem. The build cache must stay in the
  `kernel-lens-cache` Docker volume; never bind-mount it to a macOS path.
- **Dockerfile edits fail mysteriously:** the environment uses the legacy
  docker builder (no buildx on the course toolchain) — heredoc `RUN <<EOF`
  syntax is not supported. Not a student-facing path, but if you tinker:
  one command per RUN line.

## VM already running

Two VMs must never share `rootfs.ext4` (it is writable and persistent —
concurrent boots corrupt it). Symptoms: boot hangs, fs errors, port 2222
taken.

**A VM belongs to the workspace that booted it.** `tools/vm down` stops only
that one (it reads `<workspace>/.vm/qemu.pid`), so from any other workspace
it refuses — and `tools/vm up` refuses too, rather than putting a second VM
on the same rootfs. Both name the owner, so you can copy the fix:

```
vm: a course VM is up and it belongs to another workspace: /path/to/WORKSPACE
    only that workspace can stop it:  /path/to/WORKSPACE/tools/vm down
```

`make doctor` names the same owner. By hand, the console-log path in the
qemu command line is the giveaway:

```sh
pgrep -fl qemu-system-x86_64     # who is running
#   ... -serial file:/path/to/WORKSPACE/.vm/console.log
#                     ^^^^^^^^^^^^^^^^^^ that workspace owns it
```

A VM started by `env/run.sh` is `-nographic` and has no `-serial file:` at
all: no workspace owns it, so exit it with **Ctrl-a x** in its own terminal.

If `.vm/qemu.pid` went missing or stale while the VM is still up, `tools/vm`
says so and prints the one-line `echo <pid> > .vm/qemu.pid` that adopts it
back.

If a crash test ever corrupts the **rootfs** anyway (boot log full of
EXT4-fs errors): `make rootfs` rebuilds just the rootfs image in a couple
of minutes. Lesson: crash experiments go on the scratch disk, never the
rootfs (see below).

## Port 2222 in use

The VM forwards guest ssh to host port 2222. If doctor says something
other than the course VM holds it: `lsof -nP -iTCP:2222` and stop that
process, or move this VM's port:

```sh
SSH_FWD_PORT=2223 ./run.sh        # or: SSH_FWD_PORT=2223 tools/vm up
ssh -p 2223 root@localhost
```

`config.sh` takes the value from the environment when one is set, so
nothing needs editing for a one-off; to change it permanently, edit
`SSH_FWD_PORT` there and `run.sh`, `tools/vm`, and `doctor` all follow.
`GDB_PORT` (default 1234) works the same way.

This is what you want when a **second** course VM must run — two
checkouts of the offering, say. Give it its own port *and* make sure it
is not the same `rootfs.ext4`: concurrent boots on one rootfs corrupt it
(section above).

## Boot problems

- **Console shows nothing / appears hung:** boot to login is ~10 s on
  Apple Silicon (emulated), ~4 s with KVM. For anything scripted, use
  `HEADLESS=1 CONSOLE_LOG=/tmp/console.log ./run.sh` and read the log —
  that file is the diagnostic, and it's what the smoke test keeps on
  failure.
- **VM starts "frozen" after `./run.sh -g`:** not a bug — `-g` waits,
  stopped at the first instruction, for gdb to attach (`scripts/gdb.sh`).
- **Exiting the console:** `Ctrl-a x` kills the VM. `exit` at the shell
  just logs out; the VM keeps running.

## SSH into the VM

`ssh -p 2222 root@localhost`, password in `config.sh` (`kernellens`).
`tools/vm` installs its own key on first boot via the autorun channel and
needs no password. Host-key warnings after a rootfs rebuild are expected —
the guest generated new host keys; remove the old line from
`~/.ssh/known_hosts` (the ssh error message names the exact line).

## gdb

There is no host gdb on macOS, by design — `scripts/gdb.sh` runs gdb
inside the amd64 build container against the VM's gdb stub, on both
platforms. Workflow: `./run.sh -g` in one terminal (VM waits), then
`scripts/gdb.sh` in another. Notes:

- Needs the docker daemon up (it's a container) and the build image
  present (`make images` if you cleaned it).
- **The guest clock freezes at a breakpoint.** Every sleep, timeout, and
  latency measurement in the guest distorts across a stop. That's physics,
  not breakage — plan measurements and breakpoints as separate runs.
- KASLR is off in the course kernel: `dist/vmlinux` symbol addresses match
  runtime addresses.

## Mutation kernels (batch 6 onward)

Mutation images ship prebuilt as GitHub release assets — the batch file
names the release. Boot one with the same rootfs:

```sh
gh release download batch-06 -R <offering-repo>   # gets bzImage-2026f-01
KERNEL=/path/to/bzImage-2026f-01 tools/vm up      # or ./run.sh
```

- **`uname -r` looks identical to stock — did the boot take?** Yes, by
  design: the mutation is behaviorally hidden, not labeled. QEMU refuses
  to boot a nonexistent image path, loudly — so if the VM came up, the
  file you named in `KERNEL=` is what's running.
- Your repro for a mutation question must take the image path as `$1` —
  the batch file states the contract.

## Scratch disk and crash tests

Crash experiments (`vm kill`, forced power loss) go on the second disk,
never the rootfs:

```sh
SCRATCH=/tmp/scratch.img tools/vm up    # creates 512 M /dev/vdb if missing
# in guest: mkfs.ext4 /dev/vdb && mount /dev/vdb /mnt
```

Throttle it to make queueing observable (`SCRATCH_BPS=`, `SCRATCH_IOPS=`,
`SCRATCH_QSIZE=` — batch 11 uses these). Delete the image file to reset.

## Performance

On Apple Silicon the guest is emulated (TCG): boot ~10 s, in-guest
compiles slow. This is expected and graded around — kernel *behavior* is
identical, timing *magnitudes* differ from bare metal, and questions state
tolerances measured in this environment. Kernel builds happen in the
(Rosetta-accelerated) container, not the VM, so they're fast everywhere.
On x86_64 with `/dev/kvm`, everything is hardware-speed.

## Starter tools can't find the env

`tools/vm` and `tools/ksrc` locate `env/` by walking up from the
workspace, or by `KL_ENV=/absolute/path/to/env`. Symptom: `vm: cannot
find env/`. Set `KL_ENV` when your workspace lives outside the offering
checkout.

---

## When to escalate

Exhausted this file with your agent? Bring it to studio, or email the
instructor. Include, always:

1. `make doctor` output,
2. the exact command you ran,
3. the log it produced (console log, smoke artifacts, or terminal output).

"It doesn't work" without those three restarts the conversation at
step 1; with them, most answers take a minute.
