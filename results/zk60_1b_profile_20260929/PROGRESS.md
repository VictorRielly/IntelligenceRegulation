# Lane C progress — trained TinyLlama-1.1B block profile plan (2026-09-29/30 UTC)

Scope: design + scratch prototype only. Read-only on every source tree.
Writes only under `results/zk60_1b_profile_20260929/`; compile experiments
in `/tmp/zk60-lane-c-20260929` (copy, no git metadata).

Source under study: the restored unpromoted candidate
`ops/zkp-mvp/candidate/` (184 pins, `restore.json`), which is the tree the
2026-09-27 TinyLlama layout probe ran against (as `/tmp/zk60-groups-20260926`,
now gone after the reboot). The main tree's `hashline/src/private_block/`
lacks shape.rs / run.rs and is NOT the current native code.

## Log

- 00:09 UTC 09-30: lane opened; results dir + scratch dir created.
- 00:12: copied `ops/zkp-mvp/candidate/{hashline,zkp-core,private-block-kernel,
  private-block-kernel-shaped}` (no target/, no .git) to
  `/tmp/zk60-lane-c-20260929`. Baseline debug test build under
  `/tmp/zk-build.lock`, `--offline --locked -j2`: exit 0 (39.7 s).
- ~00:40: scratch prototype written in the copy (patch retained later as
  `lane-c-prototype.patch`): `Shape::tinyllama_t32_probe/dev`, run profile,
  `trained_statement.rs` (model/profile/calibration statement),
  `RunStatement::new_bound` (literal path byte-identical), test module
  `lane_c_tinyllama_tests.rs`. Compiles; 7 fast tests pass, 2 heavy ignored.
  Findings so far: true geometry = layout OK (A 1801 / H 1934 / 12,053,320 B at
  lc12, reproduces Sol probe) but NO WITNESS (norm window 33 bits = 5 limbs,
  `witness.rs:429` refuses). Dev shape (norm window override 32): A 1729 /
  H 1798 rows, counted receipt 11,627,208 B.

## Recovery after the 2026-09-29 crash (main Claude session, 2026-09-30 01:19 UTC)

The box froze at 00:40:27 UTC while this lane's agent was mid-refactor; its
scratch tree `/tmp/zk60-lane-c-20260929` was wiped and `lane-c-prototype.patch`
had never been written. Recovered from the agent's saved transcript:

- `replay_lane_c_from_transcript.py` replays every Edit/Write the agent made on
  the scratch tree onto a fresh copy of `ops/zkp-mvp/candidate/` (25 ops:
  21 with recorded success, 4 issued at 00:40:14-21 whose results were cut off
  by the crash; none were recorded errors). One edit (`private_block.rs`
  module declarations) was applied by anchor because the candidate gained
  `mod mvp_driver;` after this lane copied it; it was a pure insertion.
- Recovered patch: `lane-c-prototype-recovered.patch` (63,107 B), relative to
  the CURRENT candidate (so it already coexists with the driver overlay).
- Validation (guarded `build` job, `recovered-fast-tests.log`, `.guard.json`):
  `cargo test --offline --locked -j2 --lib lane_c_tinyllama_tests` -> compiles
  (31.9 s), **7 passed, 2 ignored** - identical to the pre-crash report. Guard
  peak RSS for the debug build: 1.61 GiB.
- The two ignored heavy tests: the one-block dense proof at the dev shape
  already passed at 00:39 UTC before the crash (`dense-dev-block.log`,
  exit 0, 10.69 s wall, 855 MB max RSS, T=32, norm window override 32 = 4
  limbs, synthetic dense weights, NOT a trained block).
- The recovered tree is `/tmp/zk60-lane-c2-20260930` (dies on reboot); the
  patch above is the durable copy. The last four edits (witness.rs x3,
  layout.rs x1: shape-level `norm_cn` / `norm_ceps` / `sh_ao`) are applied but
  their compile-and-test status beyond the 7 fast tests is unverified.

## Lane C2 (continuation agent), 2026-09-30 UTC

- 01:26 UTC: opened. Read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md, the 1B
  checkpoint, this file, Codex's HANDOFF.md (norm contract), trained-calibration-
  next.txt, the recovered patch and the replay tool. Scratch tree
  `/tmp/zk60-lane-c2-20260930` present (base `-base`); it already compiled with
  all 25 replayed edits (the fast-test log above built the whole lib).
- 01:31 UTC: guarded `build` job `c2-baseline-full-lib` (the WHOLE `--lib`
  suite on the recovered tree, detached): establishes which pre-existing tests
  the recovered patch passes before any C2 edit. Log/marker/guard JSON:
  `c2-baseline-full-lib.{log,done,guard.json}`.
