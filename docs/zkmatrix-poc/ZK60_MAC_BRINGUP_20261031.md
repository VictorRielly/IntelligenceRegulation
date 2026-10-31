# Mac bring-up, 2026-10-31: continuing on the M3 Ultra after the laptop was lost

Written by Claude on the Mac Studio. Evidence: `results/zk60_mac_bringup_20261031/`.
Labels: [MEASURED] on this Mac, n = 1, box otherwise idle apart from Spotlight indexing the new files.

## Plain words for Victor

- **The pull is complete.** The last push from the laptop (Snapshot 15, 2026-10-30 15:16 PDT, `68506378`)
  is now the local `perf/zk-batch-optimizations`. It fast-forwarded cleanly from the old Mac checkout.
  Nothing was pushed back to GitHub.
- **The production prover builds and runs on the Mac's processor.** Its tests pass apart from three macOS
  bugs and a few missing test files. A Linux-made proof verifies on the Mac, and the Mac's toy proof
  verifies too, so the two machines agree on the proof format.
- **The safety guard that every heavy job must go through now works on macOS.** Before today it crashed
  at once on the Mac.
- **The Mac's GPU cannot run the prover yet.** The GPU code is NVIDIA-only. A plan for an Apple GPU port is
  in `ZK60_METAL_PORT_PLAN.md`.
- **What was lost with the laptop:** about 446 GiB of large files inside the repo folders, and everything
  kept outside the repo (model exports, fixtures, the demo posts' signer key, salts and openings). The
  list with hashes is `SNAPSHOT_20261017_EXCLUDED_LARGE_FILES.json`. If the laptop's disk can be read
  again, those files can be restored by hash.

## 1. The pull

- `git fetch --all --prune`, then `git merge --ff-only origin/snapshot/20261017-uncommitted` on
  `perf/zk-batch-optimizations`. Both `origin/perf/zk-batch-optimizations` (`b504328c`, 2026-09-23) and
  `origin/main` (`9d9d9aee`) are ancestors of the snapshot tip, so the merge is a fast-forward of 15
  snapshot commits. About 99,000 files changed on disk.
- The local branch is now 15 commits ahead of `origin/perf/zk-batch-optimizations`. Publishing it (a push)
  is left for Victor to decide.
- 33 lane branches were also fetched (`uperf3-*`, `zk60-*`, `fsp-*`); none is newer than the snapshot.

## 2. The machine [MEASURED]

| Item | Value |
|---|---|
| Model | Mac Studio (Mac15,14), Apple M3 Ultra |
| CPU | 32 cores (24 performance + 8 efficiency) |
| GPU | 80 cores, Metal 4 |
| Memory | 256 GB unified (`hw.memsize` 274,877,906,944) |
| OS | macOS 26.5 (25F71), arm64 |
| Rust | Homebrew rustc / cargo 1.96.0 (`aarch64-apple-darwin`); no rustup |
| Free disk | about 620 GiB of 3.6 TiB |

The rustup path in the old command-style rule does not exist here. Call `cargo` from Homebrew directly.

## 3. CPU gates on the production tree (`ops/zkp-mvp/token-io-r19b`, run on a scratch copy)

Source pins: `results/zk60_mac_bringup_20261031/source_pins.txt` (commit `68506378`, tree `45430e84`).
All tests use `cargo test --release --locked`. CUDA is off: the default build has no GPU dependency.

| Gate | Result |
|---|---|
| `zkp-core` tests | pass (21 s) |
| `hashline` library tests, no fixtures (pass 1) | 811 passed, 15 failed, 71 ignored |
| the same with the surviving R13 loader fixtures and the four archived toy receipts (pass 2) | 821 passed, 5 failed, 71 ignored |
| `hashline` integration tests (27 binaries) | all pass except one test-harness flake (below) |
| `stable-weight-storage` feature, library tests | 831 passed, the same 15 failed (pass 1) |
| CLI `hashline` and `zk60_private_block` example, release build | pass |
| toy private block: prove, then verify in a fresh process | ACCEPT, 2,816,472 B (the recorded frame size), three corrupted copies refused |
| four toy receipts made on the Linux laptop, verified by the Mac build | all four ACCEPT |
| the pre-lane receipt test (`a_toy_receipt_made_before_the_lane_still_verifies`) | pass once the archived receipts are staged |

### The five pass-2 failures

| Test | Cause | Kind |
|---|---|---|
| three `r18` batch tests | `classify_batch.rs` defines `O_NOFOLLOW / O_NONBLOCK` only for x86-64 Linux, so **`classify-prove-batch` refuses every request on macOS** | macOS bug (fails closed) |
| `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name` | `trained_block.rs::clear_stale_writing_dirs` decides liveness by `/proc/<pid>`, which never exists on macOS, so **a live verifier's `statement.writing-<pid>` directory is deleted** | macOS bug (fails open, destructive) |
| `accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces` | needs `independent_trace.tsv` fixtures that stayed on the laptop | missing fixture |

The integration flake: `zk60_stable_weight_slots::process_death_releases_lock_without_refunding_the_slot`
failed in 1 of 5 parallel runs and passes single-threaded. Its scratch directory name uses a nanosecond
timestamp, but macOS clocks resolve only microseconds, so two parallel tests can pick the same name.

### Further macOS findings in the same tree (no test fails)

- `run.rs` (segment reads), `token_io/load.rs` (table reads) and `tied_tables.rs` set
  `O_NOFOLLOW | O_NONBLOCK` only on x86-64 Linux. On macOS they open with no flags. The `lstat` before and
  the metadata check after the open remain, so this weakens the review TR4-4 / r3_6 hardening rather than
  removing it. A symlink swapped in between the two checks would be followed, and a FIFO would block the
  open.
- `timing.rs` and `run.rs` read RSS and its high-water mark from `/proc/self/status`. On macOS the values
  are `NaN`. A separate repair exists, unmerged: `results/zk60_sol_macmem_20260927/README.md`.

**The fix for the open flags is small.** On macOS `O_NOFOLLOW = 0x0100` and `O_NONBLOCK = 0x0004`
(`<sys/fcntl.h>`). For liveness, use `kill(pid, 0)` through the `libc` crate (already in the lock file), or
fail closed (refuse by name) on non-Linux targets. These files are frozen production sources owned by the
Sol token and native lanes, so the fixes belong in their next round (R15), with the usual freeze and
review. They were not edited here.

**Until then, on the Mac:** do not use `classify-prove-batch`, and do not run two verifiers of the same run
directory at once.

## 4. The resource guard on macOS

`scripts/zk60_resource_guard.py` crashed on the Mac at its first probe (`/proc/meminfo`). On macOS it now
reads:

| Linux source | macOS source |
|---|---|
| `/proc/meminfo` | `vm_stat` (MemAvailable = free + speculative + min(inactive, file-backed − speculative) pages, at or below the kernel's own figure) plus `sysctl hw.memsize` and `vm.swapusage` |
| `/proc/<pid>/stat`, `statm`, `cmdline` | `ps -Axo pid,ppid,pgid,rss,stat,command` |
| `boot_id` | `kern.bootsessionuuid`; the start time is epoch seconds from `ps -o lstart` |
| `nvidia-smi` | `ioreg` IOAccelerator "In use system memory" against the GPU working-set budget (`iogpu.wired_limit_mb`, else 3/4 of RAM [MODEL]) |
| `/mnt/c` disk floor | `/System/Volumes/VM`, the swap volume |
| systemd scope + cgroup cap | none: enforcement is **watchdog-only** (RSS cap, memory floor, disk floor, `--max-secs`, process-tree kill) |

- Each Linux code path is unchanged. On Darwin a probe switches only while its source is the built-in
  default, so the regression tests' fake `/proc/meminfo` and fake `nvidia-smi` still exercise the Linux
  parsers.
- On the Apple GPU the idle threshold is 4,096 MiB, because the window server alone holds about 1.2 GiB
  [MEASURED]. The kill cap is 90% of the GPU budget. Both are set by environment variables.
- **Before the port, the guard could not kill anything on the Mac.** Its liveness check read `/proc`, so
  every process looked dead and the kill step returned at once. The RSS cap test and the disk kill-floor
  test failed for that reason.
- Guard suites on this Mac: before the port, 4 failures and 5 errors of 98; after it, see §4.1.
  New tests: `tests/test_zk60_guard_darwin.py` (parsers with recorded macOS output on any host; live probes
  on Darwin).
- Two existing tests were made portable without changing what they check on Linux. The s8 admission
  helper now names its simulated `nvidia-smi`. The setsid tracking test calls `setsid(2)` from Python
  where `setsid(1)` is absent.
- **`ps` can fail where `/proc` never does.** It needs a fork, which fails exactly when a job exhausts the
  process limit. An unreadable process table therefore raises instead of reading as empty. The sampler
  reuses the last good sample for two failures, then raises, which the watchdog turns into a kill. Kills
  always also signal the job's process group (`killpg`), which needs no `ps`. Liveness uses `kill(pid, 0)`
  first.
- **Gaps:** there is no kernel memory cap (a runaway job is stopped by the 0.5 s watchdog, not the kernel).
  `ps` RSS leaves out compressed pages, so the per-job cap under-reads once the compressor is active.
  Metal allocations may not appear in a process's RSS; the host MemAvailable floor still sees them.

### 4.1 Review and test results

- **Independent review** (a separate agent given only the diff): it found **no Linux behaviour change**.
  It diffed the old and new admission verdicts under `sys.platform = 'linux'` over 4 classes × 3 GPU readings
  × 3 disk readings: 0 differences. On macOS it found one blocking defect: a `ps` failure turned a kill into
  a no-op, and the guard then waited forever with the locks held. It reproduced this. It also found that
  the first MemAvailable formula overstated free memory under anonymous-memory pressure, plus five nits.
  All are fixed except the compressed-RSS nit, which is documented above. The fixes have regression tests.
  A second review pass confirmed the fixes and Linux equivalence again, and found one leftover: a `finally`
  block still called the raising liveness check. That is fixed too. Two nits remain:
  - with `ps` unavailable, a kill always waits the full grace plus 5 s, because the exited root is an
    unreaped zombie that `kill(pid, 0)` still finds;
  - `killpg` after the root is reaped could in principle hit a reused pid's group once the pid counter
    wraps, which is plausible only during a fork bomb.
- **Guard suites on the Mac** (`resource_guard`, `guard_fix`, `guard_s8`, `guarded_command`, `guard_darwin`):
  120 tests, all pass; 4 skipped (they need a systemd user scope). Before the port: 4 failures and 5 errors
  of 98. Log: `results/zk60_mac_bringup_20261031/guard_suites_final.log`.
- Recovery coordination asks for a review of any guard edit before native execution relies on it. This
  review is that check for the macOS backend. The Linux path is unchanged, so the laptop's released guard
  behaviour stands.

## 4.2 The full Python suite on the Mac (before the review fixes)

`python3 -m unittest discover -s tests`: 1,329 tests in 982 s; 41 failures, 28 errors, 84 skipped. None is in
the guard suites. By cause:

| Module | Count | Cause |
|---|---|---|
| `test_zk60_zkvm_demo`, `test_zk60_techweek_demo`, `test_zk60_zkvm_cycle_gate` | 53 | The zkVM runner refuses a destination "reached through a symlink": macOS temp dirs live under `/var`, a symlink to `/private/var`. Also identity pins and the zkVM toolchain, which is not installed here |
| `test_regression_fixtures` | 5 | the same `/var` → `/private/var` symlink in path-equality assertions |
| `test_zk60_private_stack_benchmark`, `test_zk60_mvp_baseline` | 8 | read the Linux `boot_id` from `/proc` (one assertion differs: "failed" against "interrupted") |
| `test_zk60_resource_watch` | 1 | `os.O_NOATIME` is Linux-only |
| `test_zk60_endpoint_view` | 1 | retained captures absent (left on the laptop) |
| `test_zk60_io_review_gate` | 1 | its input preflight fails first, before the dependency-change check it tests |

These are environment ports, not prover defects; each module belongs to its lane. The suite is not green on
the Mac until they are ported.

## 5. Other Linux-only pieces the lanes use

- `scripts/zk60_explorer.py` (the hourly researcher) needs bubblewrap and a crontab. It refuses to start
  without bubblewrap, so it fails safe. A macOS port would need `sandbox-exec` and launchd: a separate
  decision.
- `scripts/zk60_private_stack_benchmark.py` and `ops/zkp-mvp/start_demo_server.py` read
  `/proc/sys/kernel/random/boot_id`.
- 17 files across the top-level `hashline` and `zkp-core` sources, `scripts/` and the app reference
  `/home/victor/...` (more in the frozen trees and older scripts). Most take an environment
  override (`M125_EXPORT_DIR`, `HL_EXPORT_DIR`, `HL_R13_LOADER_FIXTURES`, `PM_*`). The app's defaults now
  resolve under `/Users/victorrielly`, where its private store does not exist yet.

## 6. What the lanes need before real-scale work on the Mac

1. **Model exports.** The Shieldstral export (about 76 GiB), the 8B calibration exports and the 1B
   native exports stayed on the laptop. Regenerate them from the public checkpoints here, or recover them
   from the laptop's disk by hash.
2. **The app's stores.** The demo posts' signer, salts and openings (`~/zk60-owner-private`) and their public
   segments (`~/zk60-artifacts/proven-media`) are not here. The anchors remain on Base Sepolia, but neither the
   segments nor the openings can be served from this Mac.
3. **R15 macOS fixes** (§3) before the batch prover or concurrent verifiers are used here.
4. **A Metal backend** for any GPU timing on this machine (`ZK60_METAL_PORT_PLAN.md`).
