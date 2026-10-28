# Resource protocol — one heavy job at a time, always through the guard

Opened 2026-09-30 UTC by Claude with both Codex sessions, after the box froze
on 2026-09-29 at 17:40 PDT. Tool: `scripts/zk60_resource_guard.py`. Tests:
`tests/test_zk60_resource_guard.py` (45 pass). Shared acknowledgment channel:
`ops/zkp-mvp/RECOVERY_COORDINATION.md`.

## What happened, in plain words

The WSL machine (15.4 GiB RAM, 4 GiB swap, RTX 4070 Laptop 8,188 MiB) died
without warning at 17:40:27 PDT on 2026-09-29. The journal simply stops: no
out-of-memory kill, no `dxgk make_resident` error, no shutdown. Victor had to
restart it (back up at 17:49:44).

What was running in the last minutes (from result-file timestamps and the
sessions' logs):

- the 12-block synthetic GPU stack proof (`cli-stack-gpu`, keyed GPU
  commitments, no finish marker);
- a TinyLlama calibration smoke run (Claude lane B);
- a dense-dev-block proof run (Claude lane C);
- a Rust build and test run for the Sonnet hardening copy;
- the main Python regression suite (finished 17:38);
- three Codex sessions, one Claude session and the hourly researcher.

**The exact cause is not proven.** No log names it. What we can say is that
these jobs were live together on a box where a single one-block CPU proof peaks
near 10.5 GiB of host RAM (2026-09-27 dense A/B; 4.4 GiB with the GPU), and the
older voluntary rule (one heavy job under `/tmp/zk-heavy.lock`) covered neither
builds nor calibration scripts nor the "CPU-light" exemption. The fix is to
make the rule impossible to skip, not to guess which job was the last straw.
An earlier successful 12-block GPU run (17:12-17:19) peaked at only 2,113 MiB
of VRAM, so VRAM exhaustion alone is not the obvious cause.

## The rules

1. **Anything that may use more than 1.5 GiB of RAM, more than a minute of
   several cores, or the GPU runs through the guard.** That includes builds,
   test suites, calibration scripts, proofs and benchmarks. Guard the *leaf*
   command. Do not wrap a script that itself guards its steps (nested calls
   are refused).
2. **One heavy job at a time.** `cpu`, `gpu` and `build` jobs all hold
   `/tmp/zk-heavy.lock`. A build never overlaps a proof. Old-style
   `flock /tmp/zk-heavy.lock cmd` wrappers share the same lock and still work.
3. **Only `light` jobs run beside a heavy job**, and each is capped at 1.5 GiB
   unless it declares more (declared memory of all live guarded jobs must fit
   the 11.9 GiB budget).
4. **The GPU must read idle before a GPU job starts, and must drain before the
   next one.** The guard checks both. Never chain two GPU passes in one script.
5. **Nobody kills the guard with SIGKILL.** Send SIGTERM and wait; the guard
   stops the job, writes its record, then frees the lock.
6. **Timing runs need a quiet box.** Run `status` first; a light job running
   beside a benchmark makes it a "shared host" diagnostic and must be labelled so.
7. **Do not relaunch a run from a stale status file.** Check the `.done`
   marker or the guard's `--result-json`; a reboot leaves running-looking files.

## Job classes

| Class | Declared need | Hard cap | Locks | Use for |
|---|---|---|---|---|
| `light` | 0.5 GiB | 1.5 GiB | none | verification, small scripts, Python checks |
| `build` | 4 GiB | 5.5 GiB | heavy, then build | `cargo build/test`, hashline compile |
| `cpu` | 11 GiB | 11.5 GiB | heavy | CPU proofs and heavy suites |
| `gpu` | 5 GiB | 6.5 GiB | heavy | GPU proofs; VRAM cap 7,400 MiB of 8,188 |

`cpu`/`gpu` defaults come from the one-block dense A/B (10,524 / 4,411.5 MiB
host high-water). Override with `--need-gib` and `--cap-gib` once you have a
measured number; the guard refuses a job whose need exceeds the whole budget
(15.4 GiB minus 3.5 GiB reserved for the OS and agent sessions).

## How to run

```
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run \
    --class gpu --label m125-stack --wait-secs 3600 --max-secs 3600 \
    --log /path/run.log --done /path/run.done --result-json /path/run.guard.json \
    -- <command> <args>
python3 .../zk60_resource_guard.py status          # RAM, budget, locks, GPU, top RSS
python3 .../zk60_resource_guard.py check --class gpu   # dry run
```

Detached (survives session death): wrap it exactly like the old protocol,
`setsid nohup bash -c '<guard run ...>; echo $? > run.done' &`. The guard
already queues on the lock, so enqueue follow-ups immediately.

Exit codes: the command's own code; **70** refused (would never fit, wait
expired, bad number, nested call, SIGTERM while queued); **71** the guard's
watchdog failed and it killed the job; **75** the guard killed the job (memory
floor, RSS cap, VRAM cap, lost GPU telemetry, `--max-secs`, SIGTERM); **76**
the command succeeded but the GPU did not drain; **127** launch failed;
**137** the kernel memory cap fired.

## What enforces it

- **Kernel cap.** Each job runs in a `systemd-run --user --scope` with
  `MemoryMax` and no swap, inside `zk60.slice` (12 GiB for all guarded jobs
  together; unit file `~/.config/systemd/user/zk60.slice`). A runaway is
  killed inside its cgroup instead of freezing the VM. Verified on this box:
  a 600 MB allocation under a 200 MB cap was killed (exit 137).
- **Cgroup tracking.** Children that call `setsid` or double-fork are still
  counted, capped and killed; stragglers left after the command exits are
  killed and counted.
- **Watchdog (0.5 s).** Kills the job if host MemAvailable drops under
  1.2 GiB, if RSS passes the cap, if VRAM passes 7,400 MiB, if GPU telemetry is
  lost for 10 s, or on `--max-secs`.
- **Locks outlive the guard.** The job inherits the lock descriptors, so if the
  guard is SIGKILLed the locks stay held until the job's processes are gone.
- **If `systemd-run --user` is not reachable** (some sandboxes), the guard
  falls back to `watchdog-only` and says so in `enforcement`. Ask for the
  kernel cap by running the guard once from a shell that can reach it.

## Evidence and limits

Every run appends one line to `results/zk60_resource_guard/history.jsonl`
(and to `--result-json`): exit, child wall time, peak RSS, kernel peak, peak
VRAM, minimum MemAvailable, enforcement mode, kill reason. This survives
reboots, unlike `/tmp`. **Use it to replace the defaults above** after the
first 12-block and trained-stack runs; no peak RSS was ever recorded for the
12-block stack before this.

Known limits, stated plainly:

- `peak_rss_gib` is sampled every 0.5 s and can under-read a spike faster than
  that; `peak_cgroup_gib` is the kernel's high-water mark and includes
  reclaimable page cache. Read both.
- The guard protects jobs launched through it. A process started outside it
  (a bare `cargo build`) is invisible to the budget, though the live
  MemAvailable check still makes guarded jobs wait or refuse when it is eating
  RAM.
- Guard timing (`child_wall_seconds`) runs from launch to the command's exit
  and includes about 50 ms of scope creation; it is whole-process timing, not
  a native clock.
- In `watchdog-only` mode (no reachable systemd user scope, e.g. inside a
  sandbox) a job that double-forks and calls `setsid` escapes tracking once its
  parent exits. Kernel-enforced mode does not have this gap.
- The guard only ever adopts a cgroup named exactly `zk60-<run_id>.scope` that
  contains neither itself nor its parent (found by Codex 2026-09-30; fixed and
  regression-tested). It never signals a caller's session scope.
- Without a Windows-side `.wslconfig` memory limit the VM can still be starved
  by the host; that is outside this tool's reach.
- Nothing here is a privacy or soundness statement; it only keeps the box up.

## Watching for violations

`python3 scripts/zk60_resource_watch.py` (read-only, never kills) prints one line
per new problem: `LOWMEM` (MemAvailable under 3 GiB), `UNGUARDED` (a process over
1.5 GiB outside a `zk60-<run>.scope` unit that is not session infrastructure),
`GPUBUSY` (VRAM in use with no guarded gpu job), `TWOHEAVY`, and `GUARDKILL`
(a new guard record with exit 71/75/76). Silence means nothing new. The main
Claude session runs it as a persistent monitor.

## Changing the guard

The benchmark runner pins the guard's SHA-256 and fails a command if it changes
mid-run. Announce a change in `ops/zkp-mvp/RECOVERY_COORDINATION.md` first,
never edit it while a guarded run is live, and rerun
`python3 -m unittest discover -s tests -p test_zk60_resource_guard.py`.
Owner: Claude (main session).
