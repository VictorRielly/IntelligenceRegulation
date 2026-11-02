# D55 prototype: "commit, fork, join" (2026-11-01)

This directory holds the opt-in, **unregistered**, test-builds-only prototype run profile that Victor ruled on
(D55, `docs/zkmatrix-poc/ZK60_DECISIONS.md`). The design is `docs/zkmatrix-poc/ZK60_D55_CONCURRENT_RUN_DESIGN.md`.
Nothing here is accepted, registered or reachable from production. The soundness accounting for the reviewer is
`SOUNDNESS_NOTE.md`.

## Code

The code is in `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`:
- `run_fork.rs`: `ForkRun` (the opt-in door, `D55OptIn`), `prove_run_with_forks` and `verify_run_with_forks`,
  plus the controls' cheating prover;
- `run_fork_wire.rs`: the head, fork and tail frames;
- `run_fork_tests.rs`: the tests and the A/B.

The production files change only as follows:
- `run.rs` and `wire.rs` each gain three `#[cfg(test)]` lines at the end;
- `s25_tests.rs` lists the three new test-only files.

## Review findings F1–F5 closed (2026-11-01, uncommitted)

The independent review (`REVIEW_D55_20261101.md`) asked for five things before any use. All five are done in
the working tree; nothing is committed. Still test builds only, still unregistered, still not a privacy
statement. Gate chain: `results/zk60_metal_20261031/logs/m27d55/` (script `m27d55_gates.sh`), exit 0:
- the build passed, including the no-feature `cargo check --tests`, with the warning count unchanged at 134;
- the scans passed, 58 of 58, with every D55 census line present;
- zkp-core passed;
- the D55 rung tests passed, 10 of 10 on the CPU and with Metal;
- the D55 capture passed, 20 of 20;
- D12a's R13 two-stage run passed;
- the dev bytes are unchanged in both modes: `01fa1b2e/992034f8/371e6b00/3ab090df`;
- unit tests passed, 99 of 99 in both modes;
- the trained digests are unchanged: `2b0d04bb/678953f6/01a6d51d/c5e0bdac`;
- the r13 run test passed, and golden is 8 of 8;
- the full lib suite is 857 passed, 6 failed, 82 ignored. The 6 failures are exactly the known Mac-only ones,
  and the extra 4 passes are the new tests.

- **F5, test hooks and the recorder on worker threads.**
  - `protocol::ThreadHooks` (test builds only) captures every thread-local switch `prove_core` and
    `verify_core` read: the CS-3 / CS-6 cheating prover, both moved-multiplicity hooks, the W16 misfiled
    range, the D30 lapse bits, the collapsed range tags, the forced legacy rule and the timing override.
  - `run_fork::ForkHooks` adds the F2 mutation switch. Every prover and verifier worker installs the calling
    thread's switches. Each fork reports what it held (`ForkStats::fork_hooks`), and the tests assert this.
  - The recorder cannot cross threads: its replay transcripts are not `Send`. So
    `run_capture::begin_fork_run_with` seeds a fresh per-fork recorder on each verifier worker. Each one
    replays its fork independently from the public header and roots, and the run's recorder merges the
    forks in block order. It also replays S0, the join and the tail on its own transcript.
  - Control: with the cheating switch off, the fork prover on its worker refuses a limb of 300 by CS-3's name.
- **F1, false statements through the fork path.** At rung-G, `L = 3`, with D12a's harness:
  - the headline test at the interior boundary `B_1`. Variant (i) is rejected with `D55: fork 1: slot 22
    [IO-out endpoint equality]: sumcheck round 0: s(0) + s(1) != claim`, variant (ii) with `D55: fork 2: slot
    21 [IO-in endpoint equality]: ...`;
  - all 27 single-block tamper families on the interior fork 1. Each is rejected by `verify_run_with_forks`
    inside fork 1's `verify_core`, at slots 2, 14, 15, 16, 17 or 18, always `sumcheck round 0: s(0) + s(1) !=
    claim`. These tests pass on the CPU and with Metal.
- **F2, a same-block swap.** Swapping forks 0 and 2, which carry one block, with forged tags is rejected:
  `D55: fork 0: slot 0 [01 SS row sums norm_a (private)]: sumcheck round 1: s(0) + s(1) != claim`.
  - Under `DropForkIndex` (the index dropped from the derivation on both sides) the same cheat **verifies**.
    So the index alone separates the two forks.
  - Under the same mutation, swapping forks 1 and 2 (different blocks) is still rejected, by the digest.
- **F3, the fork run's own constructor.** The transcript is now `hashline-v1/` ‖ the D55 profile string
  (`d55-commit-fork-join-runs/opt-in-prototype-unregistered/test-only/v1/` ‖ the base profile), and the
  `run-construction` absorb is gone. That changes D55 receipt bytes only.
  - `ForkRun::census` holds the constructor against every absorb of the path. At the R13 rung it is 126 B,
    and the nearest absorb is 6 B away.
  - s25 W-2 measures the fork run over 73 base statements, with one declared pair (`pb-fork-s0` /
    `pb-fork-s1`, 66 B, separated by the label byte).
  - s33's J-7a premise and lemma cover 37 D55 constructor domains.
  - The absorb-label scan reads the D55 files, against `D55_LABELS`, in both directions.
- **F4, the generators.** The dead `FixtureSeed(ZkRng::new)` arm is gone.
  - s25 W-8(7) and an amended W-8(5) now scan `run_fork.rs`. They find two `from_os` sites:
    `ForkCtx::prove_one` (one per fork, in its worker) and `prove_forks_inner` (the commit phase, dropped
    before the forks). That makes `L + 1` generators per run, and `ForkStats::generators` asserts it.
- **The privacy capture at the W16 rung** (`d55_fork_run_capture_passes_the_w16_gate_checks_at_the_development_rung`):
  - one honest 3-fork run, captured with each fork on its own verifier thread;
  - checks PG-6 to PG-10, with PG-8, PG-9 and PG-10 run per fork and PG-10 also on the tail;
  - controls C-2 to C-6 on fork 0, plus two recorder refusals: a block run's recorder, and the base-profile
    header;
  - result: **20 of 20 PASS**.

  This is not a privacy acceptance. The Python gate (rank lemma, NL-1, joint passes) has not seen a D55
  capture, and a fork-run bundle is in memory only.

## A/B on one request

**[MEASURED]** `logs/ab_l32/ab.log`, test `d55_ab_one_request_serial_against_forks`. The conditions:
- W16 8B T128, a 32-block run at the true geometry;
- ONE synthetic diagonal-weight block (M10's recipe) at every layer, with an honest witness chain;
- every witness built before the timed call;
- one process, `HL_GPU=1`, `HL_PB_ORACLE=0`, no `HL_METAL_TIMING`;
- 3 warm passes after a cold serial pass, interleaved;
- the first pass of every arm verified;
- guarded (gpu class), on a shared Mac. The peak RSS was 25.3 GB and the peak VRAM 29.4 GB.

Proved tokens/s per request = 128 / wall. The table gives the best of 3, with the mean of 3 in brackets.

| arm | wall | proved tokens/s | vs serial |
|---|---:|---:|---:|
| D12a serial (`prove_run_with`) | 12.11 s (12.22) | **10.57** (10.47) | 1.00x |
| D55, N = 1 | 11.97 s (12.03) | 10.70 (10.64) | 1.01x |
| D55, N = 2 | 9.13 s (9.24) | 14.02 (13.85) | 1.33x |
| D55, N = 4 | 6.80 s (6.87) | 18.83 (18.64) | 1.78x |
| D55, N = 6 | 6.14 s (6.23) | **20.85** (20.56) | 1.97x |

**Phases at N = 6:**
- preflight about 0.36 s (serial, and in both arms);
- commit about 0.30 s (31 boundary commitments);
- forks 5.35–5.59 s;
- join and openings about 0.08 s.

Each fork's `prove_core` takes a median of 0.93–0.97 s under 6-way sharing, against 0.34 s alone. The run is
GPU-bound, as in M10.

**Receipts:**
- D12a: 786,061,536 B;
- D55: 786,061,728 B (+192 B: the head's 32-byte root list overhead and the tags).

**Verification:**
- D12a's verifier on one thread: 4.76 s;
- D55's verifier with 6 fork threads: 2.5–2.9 s.

**Reading.**
- One request now reaches the independent-proof ceiling that M10 measured (about 22 tokens/s aggregate) to
  within about 6%.
- The remaining serial part is the preflight, the commit phase and the join: about 0.75 s of 6.1 s.
- Dense real weights add their folds, about +15 ms per block per M8. The figure is not a dense-weight
  measurement.

## Gates

`d55_gates.sh` (detached through `run_d55.py`); logs are in `logs/gates/`:
- the build, plus the no-feature `cargo check --tests`;
- zkp-core;
- the source-scan hooks: r19b, s24 pins, the absorb-label scan, the W-8 generator tests. Four of the five scans
  **already fail at the base commit `7ee0fcda`**, on files of the Metal / W16 lanes:
  - `metal_slot.rs` and `range16.rs` are missing from the production lists;
  - `range16_tests.rs` and `w16_privacy_gate_tests.rs` are missing from `TEST_ONLY_FILES`;
  - `slot_ir.rs` is now on the path.

  The step therefore passes when:
  - W-8(5) passes;
  - no scan names a D55 file;
  - r19b's complaint is exactly those three files.

  The scan lists still owe that repair, and it is not D55's;
- the D55 rung tests on the CPU and on Metal;
- D12a's R13 two-stage run test;
- the dev-shape bytes in both modes;
- the unit tests in both modes;
- the trained digests;
- the r13 run test;
- golden 8/8.
