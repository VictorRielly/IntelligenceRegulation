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
