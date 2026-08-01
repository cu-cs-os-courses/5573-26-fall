/* cow-trigger: deterministic copy-on-write demonstrator (examples/cow).
 *
 * Maps one anonymous page at a fixed address (so the probe can filter on
 * it), writes a sentinel, forks, and has the child perform exactly one
 * write into the page. Parent and child record their view of the physical
 * page number (/proc/self/pagemap) and the child's minor-fault counter
 * around the write. The two processes run in lockstep over a pair of
 * pipes, so every measurement is ordered:
 *
 *   child: record before-state  ->  parent: record before-state
 *     ->  child: minflt, WRITE, minflt, after-state
 *     ->  parent: after-state, read sentinel, reap child
 *
 * Output is key=value lines via dprintf (unbuffered writes), one writer
 * at a time by construction. Mode "private" (MAP_PRIVATE: COW expected)
 * or "shared" (MAP_SHARED: negative control, no COW). The optional
 * outfile argument makes the report go to a file — needed because this
 * runs under `bpftrace -c`, which shares stdout with the probe output
 * and only accepts a real ELF binary (no shell-wrapper redirection).
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAP_ADDR ((void *)0x100000000000UL)
#define PAGE 4096UL

static void die(const char *what) { perror(what); _exit(1); }

static uint64_t pagemap_entry(int fd, volatile void *addr) {
    uint64_t e;
    off_t off = (off_t)((uintptr_t)addr / PAGE * 8);
    if (pread(fd, &e, sizeof e, off) != sizeof e) die("pread pagemap");
    return e;
}
static unsigned long long pfn(uint64_t e) { return e & ((1ULL << 55) - 1); }
static int present(uint64_t e) { return (int)((e >> 63) & 1); }

/* /proc/self/stat field 10, counted after the ')' closing comm */
static unsigned long minflt(void) {
    static char buf[512];
    int fd = open("/proc/self/stat", O_RDONLY);
    if (fd < 0) die("open stat");
    ssize_t n = read(fd, buf, sizeof buf - 1);
    if (n <= 0) die("read stat");
    close(fd);
    buf[n] = 0;
    char *p = strrchr(buf, ')');
    unsigned long m;
    if (!p || sscanf(p + 2, "%*c %*d %*d %*d %*d %*d %*u %lu", &m) != 1)
        die("parse stat");
    return m;
}

static void step(int fd)      { char c = 'x'; if (write(fd, &c, 1) != 1) die("write pipe"); }
static void wait_step(int fd) { char c;       if (read(fd, &c, 1) != 1) die("read pipe"); }

static int out = 1;

int main(int argc, char **argv) {
    int shared = 0;
    if ((argc == 2 || argc == 3) && !strcmp(argv[1], "shared")) shared = 1;
    else if (argc < 2 || argc > 3 || strcmp(argv[1], "private")) {
        dprintf(2, "usage: %s private|shared [outfile]\n", argv[0]);
        return 2;
    }
    if (argc == 3) {
        out = open(argv[2], O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (out < 0) die("open outfile");
    }

    volatile unsigned char *map = mmap(MAP_ADDR, PAGE, PROT_READ | PROT_WRITE,
        (shared ? MAP_SHARED : MAP_PRIVATE) | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE,
        -1, 0);
    if (map == MAP_FAILED) die("mmap");
    if ((void *)map != MAP_ADDR) { dprintf(2, "mmap ignored fixed address\n"); return 1; }

    map[0] = 0xA5;                /* fault the page in before the fork */

    int p2c[2], c2p[2];
    if (pipe(p2c) || pipe(c2p)) die("pipe");

    dprintf(out, "mode=%s\nmap_addr=%p\nparent_pid=%d\n", argv[1], (void *)map, getpid());

    pid_t child = fork();
    if (child < 0) die("fork");

    if (child == 0) {
        int pm = open("/proc/self/pagemap", O_RDONLY);
        if (pm < 0) die("open pagemap");
        uint64_t before = pagemap_entry(pm, map);
        dprintf(out, "child_pid=%d\nchild_pfn_before=0x%llx\nchild_present_before=%d\n",
                getpid(), pfn(before), present(before));
        minflt();                          /* warm the stat reader before the window */
        step(c2p[1]);                      /* A: child before-state recorded */
        wait_step(p2c[0]);                 /* B: parent before-state recorded */
        unsigned long m0 = minflt();
        map[0] = 0x5A;                     /* THE write under investigation */
        unsigned long m1 = minflt();
        uint64_t after = pagemap_entry(pm, map);
        dprintf(out, "child_minflt_delta=%lu\nchild_pfn_after=0x%llx\n",
                m1 - m0, pfn(after));
        step(c2p[1]);                      /* C: write + after-state done */
        _exit(0);
    }

    int pm = open("/proc/self/pagemap", O_RDONLY);
    if (pm < 0) die("open pagemap");
    wait_step(c2p[0]);                     /* A */
    uint64_t before = pagemap_entry(pm, map);
    dprintf(out, "parent_pfn_before=0x%llx\nparent_present_before=%d\n",
            pfn(before), present(before));
    step(p2c[1]);                          /* B */
    wait_step(c2p[0]);                     /* C */
    uint64_t after = pagemap_entry(pm, map);
    dprintf(out, "parent_pfn_after=0x%llx\nparent_reads=0x%02x\n", pfn(after), map[0]);
    int st;
    if (waitpid(child, &st, 0) != child) die("waitpid");
    dprintf(out, "child_exit=%d\n", WIFEXITED(st) ? WEXITSTATUS(st) : -1);
    return 0;
}
