# D60: the privacy gate on REGISTERED D55 fork runs over R13 bases (2026-11-02)

D60 (`docs/zkmatrix-poc/ZK60_DECISIONS.md`, records `../README.md`) requires the Python privacy gate on a D55
capture before any receipt for real content. The D60 review (`../REVIEW_D60_20261102.md`, finding F3) adds: the
registered strings change header bytes (the parameter-line clause, the schedule literal and the F6 schedule
lines), so the Python replay must accept and fully recompute the REGISTERED header, and the Rust gate's PG-7
allow-list and fork checks must run on a bundle the production writer wrote under a registered R13 profile.
This directory records both. Privacy requirement P1 (`ZK60_PRIVACY_REQUIREMENTS.md`), not reopened.

**Verdict: no leak found.** Every part of the extended Python D55 gate passed on four registered R13 fork-run
bundles (the R13 h24 development rung and the trained Llama-3-8B T128 base, two hidden inputs each), every Rust
capture check passed on the same four bundles as written to disk, the run-level joint rank over `A_k`, `B_k`,
`A_{k+1}` is 0 = the sum of its parts at every interior boundary, and every control fired.

What this is not:
- **Not a privacy acceptance, a registration or a statement.** Every Python record is `D55-DEV-PASS`: the
  figures are computed on the bundles as given, but 23 moved source pins are unread (section 6), so they are not
  admissible evidence.
- **Not real content.** The bundles are test-only: the R13 rung is Sol's public synthetic loader fixture; the
  8B run is the registered trained base's run profile at its true geometry with ONE public synthetic block at
  every layer (no trained weights are on this host).
- v25 is NOT frozen and no v24 file was edited.

## 1. The captures (production writer, registered profiles)

New ignored test `run_fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles` (test code only,
`run_fork_tests.rs`). Per case it proves one honest `L = 3` fork run under the base's REGISTERED D55 run profile
on 3 workers, verifies it with the recorder attached (arrays and public-table values, each fork on its own
verifier worker), export-replays the statement tables and writes the bundle with **`run_capture::write_bundle`**
(the production writer; its manifest names `run_capture::write_bundle (a registered D55 run profile, D60)`).
Then, in the same test, it reads every bundle back from disk and runs the Rust gate's checks on it (section 3).

| bundle | run profile (registered D55) | hidden input | size |
|---|---|---|---:|
| `d55-r13_rung_h24-s0` | `…/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1` | the fixture `r13-h24-wide`'s public sequence (layer 0, its other-gate twin, layer 0) | 107 MB |
| `d55-r13_rung_h24-s1` | the same | that sequence with its token rows rotated by 5 and every word nudged by `((7 i + 1) mod 3) - 1` (the first admissible variant) | 107 MB |
| `d55-r13_8b_t128_h24-s0` | `…/registered-opt-in-d60/v1/private-run-llama-3-8b-t128-lh24-v1-statement/1` | M10's input family at `s = 0` (`range16_tests::case`, tame diagonal weights, 3 groups) | 303 MB |
| `d55-r13_8b_t128_h24-s1` | the same | the same family at `s = 7` | 303 MB |

(`…` = `hashline-zk-mr1/d55-commit-fork-join-run`.) The 8B run is at the true geometry (T128, d 4096, f 14336,
32 / 8 heads, boundaries of 32 data rows). The bundles are outside the repository under
`/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles/` (marked `TEST_BUNDLES_NOT_FOR_PUBLICATION.txt`);
their manifests and READMEs are kept in `bundle_manifests/` (`MANIFEST_SHA256.txt`). Writer run:
`logs/write.log` and `logs/run_write.out` (guarded cpu, 34 s, peak RSS 21.0 GiB), binary `a6f1dd05…`
(`logs/write.cmd`, build `logs/build2.log`), `HL_TEST_SOURCE_COMMIT=dd81ab4f+uncommitted-test` (the production code
is `dd81ab4f`'s: this work changes test files only). `logs/build1.log`, `write_rung.*` and `write_8b.*` are a
first pass before the Rust checks were added (the same writer; those bundles were deleted and are superseded).

## 2. The Python D55 gate, extended (v25 staging)

Files: `staging_v25/scripts/zk60_native_rg_d55.py` (the driver: a family dispatch, two new parts),
`zk60_native_rg_d55r13.py` (new: the R13 items) and `zk60_native_rg_d55joint.py` (new: the run-level joint rank);
tests `staging_v25/tests/test_d55_r13_gate.py` (new). The W16 path's parts are unchanged; it gains D55-IO and
D55-J.

The parts, at an R13 base:
- **D55-0** integrity (unchanged): manifest, every file's bytes and SHA-256, the receipt head against the tail's
  roots, no root opened twice.
- **D55-1/2 facts (R13-1)**: the block profile is an R13 accuracy profile (a DD profile is refused by name:
  SC_DD and the DD softmax twin are not ported); the run profile is a REGISTERED D55 profile (`run.rs`
  `D55_RUN_PROFILES`, ported) = `hashline-zk-mr1/` + the 50-byte marker + its base, and the base is that block
  profile's registered R13 run profile; the parameter line ends in `/d55-commit-fork-join-registered-d60` (D12a's
  one-transcript clause replaced); **the registered schedule digest** (literal
  `hashline/private-run-fork-schedule/d55-registered-d60/1`, the F6 lines: counts, and each fork line saying its
  IO claims are opened in phase 3; `run_fork.rs::schedule_lines`, the registered branch) recomputed from
  run.json's own lines; the R13 calibration line parsed and its printed precision re-derived; the PCS geometry of
  every regular opening (forks' A / H, the tail's boundaries and endpoints: rate 1/4, Q = pads = 256) and M
  (2^12, 256).
- **D55-3 replay** (unchanged): header → `run_binding`, phase 1 → S0 (= the receipt head's S0 tag), each fork
  from S0, the join → S1 (= the tail's header), the tail, its end tag; every challenge re-derived.
- **R13-H the registered header, recomputed word by word**: the constructor domain is the registered profile
  string; run-shape recomputed; expected-IO bound by its SHA-256 and the parsed policy; **the parameter line
  recomputed** from the shape, the calibration line's base and the boundary table (`protocol::parameter_line`
  then `run.rs::parameter_line` with the registered clause); the schedule digest recomputed; `run_binding`
  reproduced by the replay. The public-statement and calibration digests are taken as bound bytes (a capture
  does not carry the model statement they hash). Controls: **H-1** the same run replayed as its TEST-ONLY
  identity (prototype constructor string, parameter-line clause, schedule literal and lines) — the binding is not
  reproduced and the facts refuse; **H-2** one byte of a quoted stage line changed — the schedule digest does not
  recompute; **H-3** one byte of the parameter line changed — the recompute differs.
- **R13-2 layout**: the capture's plane index (its own integrity) against the independent R13 plane list
  (`r13slots.check_plane_index`): 109 A planes, names and domains equal.
- **R13-3 the per-slot terminal identity of all 23 slots on EVERY fork** (`r13blocks.check_stage`, the R13 block
  port unchanged, through a one-fork shim), at the fork's own calibration and its own R13 gate denominator G_k,
  with every public table rebuilt from the shape and challenges or (statement tables) taken from the capture after
  their structure checks. **G_k is recovered, not read**: a D12a / D55 stage line does not print it (the
  classifier's does), so every G in [17, 24] is tried on SC_FZC (slot 18) and exactly one must close it. The R13
  block port's own controls run on fork 1 (each predicted to fail exactly its slot): R13-G (G ± 1 → slot 18),
  NC-1 (score precision + 1 → 17), R13-N (norm tn + 1 → 14), R13-GC (one group id doctored → 18), R13-ACT (one
  ACT3 entry → 19), R13-W (one gate-fold entry → 11), R13-L (the legacy SC_FZC body → 18), and, where forks'
  G differ, R13-G2 (fork 1 at another fork's G → 18).
  To evaluate the two bilinear slots (8, 9) the gate needs the definition the bundle's `argument.rs` pin selects;
  this tree's digest (`86c9941d…`) had no reading. **Read here** (in memory for the call, removed after):
  `define` (all 23 slot polynomials, 955 lines) is byte-identical to frozen-r19b's `bc0332e3…`, the R13 reading
  the gate already accepts as the repaired definition; the 570 other changed lines are outside `define` (a
  test-only accessor, the Metal IR seam on a twin transcript, the parallel table builders, the prover's
  `mask_eval_eq`) and are NOT read. The terminal port's own pin check is run and reported, not applied (5 pins
  moved: `layout.rs`, `protocol.rs`, `plane_index.rs`, `shape.rs`, `pad.rs`).
- **R13-6 per commitment** (`d55_stage3`, unchanged): every fork's A, H and M and every tail opening (each
  boundary, both endpoints), ranked by `RunRoleView` as `run_gate.stage3` ranks a D12a run, the pad block's exact
  rank on B0, the exclusivity clauses and their controls.
- **R13-7 mask / CFS** (unchanged) on every fork and the six mask controls.
- **D55-IO the joined claims derived from the forks** (new, both families): every IO claim the tail opens has the
  value of its fork's slot-21 / slot-22 IO-table terminal and the point and size of that slot's A claim, and each
  A claim equals its A terminal. (The replay binds the claims through S1; this ties them to each fork's own slot
  transcript.) Control: one IO terminal read moved by one → refused.
- **D55-J the run-level joint rank** (section 4).
- **D55-C replay controls** (unchanged): C1 a joined claim value moved by one (S1 not reproduced); C2 the fork
  index dropped (review F2's mutation).

## 3. The Rust gate's checks on the bundles AS WRITTEN (review F3 (2))

`w16_privacy_gate_tests::d60_registered_bundle_checks` (new, test code), run on each bundle read back from disk by
the writer test (`logs/write.log`), and on the D60 capture-writer test's own bundle (that test now calls it; it
runs in the ordinary suite):
- **REG**: the manifest is the production writer's, its profile is in `run::D55_RUN_PROFILES`, schema `SCHEMA_D55`;
  run.json, every fork stage file, the tail and every fork frame re-hash to their manifest entries;
- **PG-7** the allow-list and the forbidden words over run.json, every fork stage file and the tail;
- **PG-8** per fork: every A / H masked claim on its own reserved pair inside the reserved rows, one per site;
- **PG-10** per fork and for the tail, between the two hidden inputs: the same keys in the same order, the same
  array and table lengths, every slot's claims and mask pairs, the same fork-frame lengths;
- controls **C-6** (a field off the allow-list), **C-2** (two A claims sharing a mask pair), **C-5** (one mask pair
  moved in the other bundle) — each refused.
PG-9 (W16's range and support columns) has no object at R13 and is not run; R13-3 rebuilds or structure-checks
every R13 public table instead.

| bundle | REG | PG-7 | PG-8 (3 forks) | PG-10 (3 forks + tail) | C-2 / C-5 / C-6 |
|---|---|---|---|---|---|
| `d55-r13_rung_h24-s0` | PASS | PASS, 56,803 fields | PASS (148 A, 54 H claims each) | PASS (18,845 keys per fork, tail 4,526) | fire |
| `d55-r13_rung_h24-s1` | PASS | PASS, 56,803 fields | PASS | PASS | fire |
| `d55-r13_8b_t128_h24-s0` | PASS | PASS, 137,567 fields | PASS (146 A, 53 H claims each) | PASS (45,621 keys per fork, tail 4,898) | fire |
| `d55-r13_8b_t128_h24-s1` | PASS | PASS, 137,567 fields | PASS | PASS | fire |

`D60-PG-RUST VERDICT 4 bundles, every check PASS and every control fired` (12 checks per bundle).

## 4. The run-level joint rank (task 3)

**What it is.** The privacy re-check (`results/zk60_w16r2_20261101/PRIVACY_RECHECK_20261102.md` §5) names D12a's
run-level joint rank over the three commitments that hold each interior plane — `A_k`'s output rows, `B_k`,
`A_{k+1}`'s input rows, restricted to the reserved rows — as the one run-level obligation the per-commitment rank
does not discharge (`boundary.rs:32-38`), ported to neither W16 nor D55.

**Its original form.** Ruling M-8 in the D12a run gate: `zk60_native_run_gate.stage4` with
`zk60_native_rg_joint` — (a) `boundary_reserved_figure`, each boundary restricted to its two claim pairs and its
proximity pair (rank 6 of 6, disclosed 0); (b) `three_role_figure`, the three commitments as ONE generator system
with the shared data rows identified from `claim_sources` (finding U-8) against the sum of the parts; (c)
`run_wide_figure`, the whole run and each adjacent stage pair — with `zk60_native_rg_controls` C1 (a shared
reserved pair), C2 (a single proximity row), C3 (a blinding row shared between `A_k` and `B_k`: the joint rises
above the sum), C4, C5, C6. At R13 it last ran on the block commitments of the R13 classifier rung capture
(gate round 19, `classify-r13-rung-L2-v1-short11`: "per commitment, mask / CFS, the joint figure … all ok on
the R13 rung's block commitments unchanged", `results/zk60_gate_tinyllama_20261017/PROGRESS.md`); at TinyLlama
D12a it gave "three-role joint 0 = sum 0" at every boundary of the 22-block run.

**The port** (`zk60_native_rg_d55joint.py`). At D55 the boundary is opened once in the TAIL, not in stage k+1's
file, so the identification resolves each fork's IO claim against the tail's openings (and refuses a fork that
declares an IO source); the rank functions are v24's, imported unchanged (a test asserts the identity). The same
three figures; controls J-C1 (shared reserved pair), J-C2 (one proximity row), **J-C3 (a blinding row shared
between `A_0` and `B_0`: the run-level joint rank FAILS)**, J-C4 (the tail's boundary-0 claim sources swapped:
integrity and discovery refuse), J-C5 (fork 1's file from the other hidden input's run: the replay refuses), J-C6
(H@0 one pad short: H-pad fails).

**Results** (every bundle; figures in field elements):

| bundle | per boundary: reserved rank, disclosed | three roles `A_k, B_k, A_{k+1}`: parts, joint | identified rows per boundary | whole run (generators × classes): joint = sum | adjacent pairs | J-C3 perturbed joint |
|---|---|---|---|---|---|---|
| R13 rung s0 / s1 | 6 / 6, 0 (B0, B1) | 0 + 0 + 0, **0**, block-diagonal | 2 | 308 × 2,225: 6 = 6 (the three H's 2 each) | 4 = 4 (both) | 16,384 (> sum 0) |
| R13 8B T128 s0 / s1 | 6 / 6, 0 (B0, B1) | 0 + 0 + 0, **0**, block-diagonal | 64 | 308 × 27,009: 6 = 6 | 4 = 4 (both) | 16,384 (> sum 0) |
| W16 rung (test-only D55) s0 / s1 | 6 / 6, 0 | 0, block-diagonal | 2 | 308 × 1,736: 6 = 6 | 4 = 4 | 16,384 |
| W16R2 rung (test-only D55) s0 / s1 | 6 / 6, 0 | 0, block-diagonal | 2 | 308 × 1,736: 6 = 6 | 4 = 4 | 16,384 |

Every joint control fires on every bundle. Ruling R-3 applies: `joint == sum` is a consistency check of the
model's coordinate classes, not evidence that the blinding is independent; independence rests on the generator
discipline (separate OS generators per fork and for the commit phase, `run_fork.rs:719, 776`; s25's W-8 census).
The "theorem here" condition of `three_role_figure` (only data coordinates shared, every part 0) is computed and
holds at every boundary.

## 5. Results per capture

All Python runs: `pygate_all.sh` (detached, `logs/pygate_all.done` = 0), one tool state (`tool_sha256` in every
record), each guarded (cpu class) with its log `logs/py-<tag>.log`; records `records/d55-py-<tag>.json`;
`summarize.py` prints the figures below (`logs/summarize.out`). Tool state, the same in all eight records:
`zk60_native_rg_d55.py` `0c606ce9…`, `zk60_native_rg_d55r13.py` `a6d4a143…`, `zk60_native_rg_d55joint.py`
`3fc784d6…`, `zk60_native_rg_w16.py` `0ebcb0cb…` (unchanged). Interpreter: the session's gate venv (Python 3.13.13,
blake3 1.0.11), as the privacy re-check.

| record | status | replay: positions / challenges / failures | R13-3: G per fork, slots | per commitment (disclosed) | mask / CFS | D55-IO | D55-J | D55-C (C1 / C2 failures) | wall / peak |
|---|---|---|---|---|---|---|---|---|---|
| `py-r13-rung-s0` | D55-DEV-PASS | 376 / 4,934 / 0; binding, S0, S1, tail end reproduced | 20 / 21 / 20, 23 of 23 each | 3 × (A 0, H 2, M 0); B0 0, B1 0, E-In 0, E-Out 0; B0 pad block rank 255 = 255 distinct | 48,375 entries, 0 differing, 768 leaves | 6 claims | ok | 55 / 5,704 | 98 s / 0.63 GB |
| `py-r13-rung-s1` | D55-DEV-PASS | 376 / 4,934 / 0 | 20 / 21 / 20, 23 of 23 | as above; B0 pad rank 256 = 256 | 48,375 / 0 | 6 | ok | 55 / 5,704 | 97 s / 0.63 GB |
| `py-r13-8b-s0` | D55-DEV-PASS | 376 / 30,339 / 0 | 19 / 19 / 19, 23 of 23 (73 s per fork) | 3 × (A 0 [4,577 rows], H 2 [4,390], M 0); B0, B1 0 [38 rows]; E 0 / 0 [37]; B0 pad rank 255 = 255 | 49,122 / 0, 768 | 6 | ok | 179 / 31,109 | 376 s / 1.9 GB |
| `py-r13-8b-s1` | D55-DEV-PASS | 376 / 30,339 / 0 | 19 / 19 / 19, 23 of 23 | as above | 49,122 / 0 | 6 | ok | 179 / 31,109 | 376 s / 1.9 GB |
| `py-w16-rung-s0` / `-s1` (test-only D55, regression) | D55-DEV-PASS | 376 / 4,247 / 0 | (W16: owed) | as the re-check | 48,375 / 0 | 6 | ok | 55 / 5,017 | 81 s / 0.6 GB |
| `py-w16r2-rung-s0` / `-s1` (test-only D55, regression) | D55-DEV-PASS | 376 / 4,247 / 0 | (W16: owed) | as the re-check (Q = pads = 260) | 48,375 / 0 | 6 | ok | 55 / 5,017 | 80 s / 0.6 GB |

Over the eight records: 80 regular commitments ranked, every disclosed dimension its expectation (56 at 0, the 24
H at 2 — the two public zero-sum constraints of H's u-rows, as at W16 and D12a), every certifying minor of full
rank with a nonzero determinant, every reduction hypothesis true; 24 M at 0; pad margins 0 (46), 1 (25), 2 (9).
Every control fired: R13-H's three, the R13 block port's seven (plus R13-G2 on the rung, whose forks' G differ;
at the 8B run every fork carries the same block, so G2 has no object), D55-IO's, J-C1 .. J-C6, the exclusivity
controls, the six mask controls, D55-C's two. The R13 rung's G_k is unique in [17, 24] at every fork (20 for
layer 0, 21 for its other-gate twin); the 8B block's is 19.

**The registered header (review F3 (1)).** At both R13 bases the parameter line recomputes byte for byte (e.g.
`T32/d384/f768/H16/KV8/dh64/log_cols14/inv_rate4/Q256/P1/sh-g8-u0-h14-z6/two-private-endpoints/one-proof-one-transcript/endpoint-log_n14-rate4-pad256-rows6/L3/boundary-log_n14-rate4-pad256-rows7-sites2/external-rows6/d55-commit-fork-join-registered-d60`),
the registered schedule digest recomputes from 41 lines (rung) under the registered literal, the replay reproduces
`run_binding`, the head's S0 tag, every fork's start and end tags, S1 and the tail's end tag. H-1 (the run as its
test-only identity) breaks the binding (5,706 replay failures at the rung) and is refused by the facts.

**The Rust floors before the commit** (`final_gates.sh`, final test code; binary `logs/binary.sha256` after
`build3`): see section 8.

## 6. Owed (v25 items not covered)

Covered here for the first time: the Python replay of the REGISTERED D55 header and transcript; the per-slot
terminal identity (T-0) of all 23 slots on every fork **at R13** (R13-3); the joined IO claims derived from the
forks' terminals (D55-IO, both families); the run-level joint rank at D55 (D55-J, both families); the Rust
PG-7 / PG-8 / PG-10 checks on bundles the production writer laid on disk under a registered profile.

Still owed:
- **T-0 at W16**: the seven W16-redefined slots (SC_LZC 3, SC_DZC 14, SC_QZC 15, SC_KVZC 16, SC_SZC 17, SC_FZC 18,
  SC_TAB 19) have no Python port; W16 / W16R2 D55 records still run without a terminal identity.
- **NL-1 (S1–S5)**: the non-linear table checks are not ported to a D55 (or D12a R13 blocks-only) capture, at R13
  or W16.
- **TS-1 and the claim census**: not run on any D55 capture.
- **The hash census** on the Python side (the Rust s25 W-2 census measures the registered D55 profiles; no Python
  census reads a D55 bundle).
- **The full zero-data preimage** (A and H at MSG != PAD, both halves, every opened column, the salted leaves): not
  run on a D55 capture.
- **Reading the moved pins**: 23 pins unread on every R13 D55 record (classified by `zk60_native_rg_w16.classify_pins`
  against the r19b manifest: 43 at r19b, 7 read by the W16 readings; unread include `run_fork.rs`,
  `run_fork_wire.rs`, `run_capture.rs`, `run.rs`, `protocol.rs`, `layout.rs`, `shape.rs`, `argument_accuracy.rs`,
  `accuracy_*.rs`, `plane_index.rs`, `pad.rs`, `wire.rs`, `hash_domain.rs`, `private_block.rs`, `trained_block.rs`,
  `witness_accuracy.rs`, `range16.rs`, `slot_ir*.rs`, `metal_slot.rs`, and `argument.rs`, whose `define` only was read
  here). The R13 terminal port's own pin check refuses 5 (`layout.rs`, `protocol.rs`, `plane_index.rs`,
  `shape.rs`, `pad.rs`) and is reported, not applied. Until they are read, every record is DEV-PASS.
- **Two header words are taken as bound bytes**: the public-statement digest and the calibration identity digest
  (a capture does not carry the model statement they hash).
- **G_k in the clear**: recovered on SC_FZC, not read (finding 1).
- **Bases not exercised**: the TinyLlama T128 LOW and Shieldstral T128 / T256 registered bases (the same R13 code
  path; not captured here); the four R13 DD bases are refused by the Python port by name (SC_DD not ported).
- Real trained weights: none on this host; the 8B run is one synthetic block at every layer.
- Freezing v25 (with these modules) is a separate step with its own review; not done. v24 untouched.

## 7. Findings

No leak found. Notes for the coordinator (none is a privacy defect; each would need a production change, which
this task does not make):
1. **A D12a / D55 capture does not print each stage's R13 gate denominator.** It is a layer record's
   `accuracy-gate-layer`, bound through the public-statement digest; the classifier's stage line prints it, the
   blocks-only run's `stage_line` does not. The gate recovers it (unique in [17, 24] on SC_FZC at every fork), which
   is a determination, not a reading of a bound line. Fix options: a captured-only `run.json` field (no transcript
   byte moves), or the stage line (moves the D12a and D55 schedule digests: a ruling).
2. **The registered bundle's `transcript_program[0]` still reads "D55 PROTOTYPE (opt-in, unregistered, test builds
   only)"** (`run_capture.rs:3363`, the descriptive text written into every fork-run run.json). Text only, not
   hashed into any transcript; misleading in a registered bundle.
3. Not exercised by these bundles: a base with per-layer own calibration clauses (Shieldstral). The R13-3 port
   applies a fork's own clauses to its shim (`fork_calibrations`); untested on real own-clause data.

## 8. The floors before the commit

`final_gates.sh` (detached, `logs/final_gates.done` = 0), on the final test code, binary `87b5d29d…`
(`logs/binary.sha256`, `logs/build3.log`). The bundles were written by the previous build of the same tree
(`a6f1dd05…`, `logs/build2.log`); the two differ only in test code (the D60 capture-writer test's call of the
Rust checks). No production (non-test) file is changed by this work (`git diff --stat` in the commit).

| step | result | log |
|---|---|---|
| gpu-metal test build + no-feature `cargo check --release --lib --tests` | ok, both `Finished`; **133 warnings** (the D60 baseline, same count method) | `build3.log` |
| scans `r19b s24 s25 absorb s33 hash_domain::` | **58 / 58** | `scans.log` |
| dev bytes gate (`HL_GPU_REQUIRED=1 HL_METAL_TIMING=0`) | **01fa1b2e / 992034f8 / 371e6b00 / 3ab090df**, CPU = Metal | `devbytes.log` |
| D55 / D60 set `private_block::run::fork::` (CPU) | **18 passed, 4 ignored** (the new writer test is the fourth ignored); the D60 writer test runs the Rust gate on its bundle: `7 checks, all PASS` | `d55_cpu.log` |
| staging_v25 Python suite (W16 rung, W16R2 rung, the W16 D55 bundle and the registered R13 rung pair named) | 139 tests; the only failure is the pre-existing `test_r19b_self_check_and_its_control` (it needs the r16b..r19b CLI binaries that stayed on the laptop; round 25 and the privacy re-check record the same); every new D55 R13 test and every W16 / W16R2 / D55 test passes | `suite_v25.log` |

## 9. Files

Commits (worktree branch `worktree-agent-ac47d053f76c60f1c`, on `perf/zk-batch-optimizations` at `dd81ab4f`):
`0ab231bd` (the code: Rust tests, the v25 staging modules and tests), and the records commit that adds this
directory.

- `README.md` (this), `summarize.py` and `logs/summarize.out` (the figures), `records/d55-py-*.json` (the eight
  Python records), `bundle_manifests/` (the four bundles' manifests and READMEs, `MANIFEST_SHA256.txt`).
- Scripts: `detach.py`, `build.sh`, `run.sh` (one guarded test-binary run), `pygate.sh` (one guarded Python gate
  run), `pygate_all.sh` (the eight), `final_gates.sh` (the floors). Logs in `logs/` (each run's `.log`, `.cmd`,
  `.guard.done`).
- Code: `ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_fork_tests.rs` (the writer test, the rung's hidden
  inputs, the D60 writer test's Rust check), `.../w16_privacy_gate_tests.rs` (`d60_registered_bundle_checks`),
  `ops/zkp-mvp/gate-tinyllama/staging_v25/scripts/zk60_native_rg_d55.py` (driver), `zk60_native_rg_d55r13.py`,
  `zk60_native_rg_d55joint.py`, `staging_v25/tests/test_d55_r13_gate.py`.

To repeat: `build.sh full build3`; `run.sh write cpu 24 96 HL_D60PG_CAPTURE_DIR=<dir>
HL_D60PG_CASES=R13_RUNG_H24:0,R13_RUNG_H24:1,R13_8B_T128_H24:0,R13_8B_T128_H24:1 -- --ignored --exact --nocapture
--test-threads=1 private_block::run::fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles` (needs
`HL_R13_LOADER_FIXTURES`, set by `run.sh`); then `pygate_all.sh` with its bundle paths.
