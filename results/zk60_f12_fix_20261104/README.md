# F12 fixed under new profile versions (D65(1), 2026-11-04)

**Finding F12 (High).** `M`'s product-form check combined its functionals with powers of θ starting at θ⁰ = 1
(`zk.rs`, `combined_weights`), and nothing checks that the blinding polynomial `b` sums to zero over G_512. A
prover that commits a `b` with G_512-sum δ could claim functional 0 as `true + δ`, and `mask_verify` accepted
(`hashline/src/zk_f12_tests.rs`; the Lean model is `formal/ZK60Formal/SoundMProduct.lean`,
`mproduct_offset_accepts`; the fix is `mproduct_sound_shift`).

**The fix.** The powers start at θ¹, for the prover and the verifier alike. Then a `b` offset, or any false
functional, makes the residual `Σ_i δ_i·θ^(i+1) − off` a nonzero polynomial in θ, caught with probability at
least `1 − k/|F_p²|`. Completeness and hiding are unchanged: the honest `b` still sums to zero, and `q'` is
still uniform given `V`. The fix changes every `M` opening, so every receipt that contains one. Victor's ruling
D65(1): every profile whose receipts use `M` gets a NEW version string, and no proof is made under an old one.

This file is the map of what that touches (written before the code change, as the task asked), the versioning
design, and what is invalidated. `REPIN.md` beside it lists every pinned value that moved, old → new.

## 1. Where `M` is opened and checked

`combined_weights` (`ops/zkp-mvp/gpu-metal/hashline/src/zk.rs`) is the one place the θ powers are formed. It is
shared by `mask_open` (prover), `mask_verify` and `mask_verify_tagged` (verifier). No other code in the crate
or in `zkp-core` forms them. Every caller of the three:

| Caller | What it proves | Opens/verifies `M` |
|---|---|---|
| `private_block/protocol.rs` (`prove_core`, `verify_core`) | one private block (every block profile, every run) | `mask_commit_tagged`, `mask_open`, `mask_verify_tagged` |
| `private_block/token_io/stage_in.rs`, `stage_in_c.rs`, `stage_out.rs`, `stage_out_c.rs` | token-I/O and classifier stages IN, IN-C, OUT, OUT-C | same |
| `private_block/run_capture.rs:2283` | the run capture recorder (test only) re-verifies each `M` | `mask_verify_tagged` |
| `private_block/tests.rs:443` | a block test | `mask_verify` |
| `private_attention/protocol.rs` | the private attention PoC | `mask_commit`, `mask_open`, `mask_verify` |
| `zk.rs` (`prove_layer_zk`/`verify_layer_zk`; `prove_layer_zk_v3[_mr1]`/`verify_layer_zk_v3[_mr1]`) | the `--zk` FFN layers (v2, v3), the repaired-mask probe; `zk_ffn_fresh_poc.rs` and `zk_ffn_fresh_io.rs` reach the v3 inner function | `mask_commit`, `mask_open`, `mask_verify` |
| `private_seam.rs` | the experimental seam receipt | `mask_commit`, `mask_open`, `mask_verify` |
| `zk_ffn_io_diagnostic.rs:212`, `native_capture.rs:166` | capture/diagnostic re-verification (export `theta` for outside tools) | `mask_verify` |
| `zk_f12_tests.rs` | the F12 reproduction | `mask_open`, `mask_verify` |

`M` itself never reaches the GPU (`mask_commit_tagged`'s doc comment), so no Metal kernel is touched.

Outside the crate, one tool recomputes the combination independently: `scripts/zk60_io_opening_translation.py:162`
(starts `theta = ONE`). See section 5.

## 2. The profile families that use `M`, and how their version is written

A profile's version is the trailing `/N` of its string. The string is the transcript constructor domain
(`Transcript::new` hashes `hashline-v1/ ‖ profile`), and for a tagged profile it also keys every commitment hash
(`HashTag::for_profile`, D19). Counts are distinct literals in `ops/zkp-mvp/gpu-metal/hashline` (src, tests,
examples), 186 literal occurrences in 29 files.

| Family | Strings (version today) | Registered in | Uses `M` |
|---|---|---|---|
| Private block `hashline-zk-mr1/private-block-*` | 62 (all `/1`): the toy, the frozen-seam rung, the dev rungs, 125M, the trained TinyLlama / Llama-3-8B / Shieldstral blocks and DD blocks, R13 accuracy bases (12), W16 (6), W16R2 (3), and test-only probe identities | `private_block/shape.rs` | every block |
| Dev twin `unregistered-dev-twin/private-{block,run}-tinyllama-1.1b-t32-w32-dev` | 2 (`/1`) | `shape.rs`, `run.rs` (test only) | yes |
| D12a private run `hashline-zk-mr1/private-run-*` | 42 (`/1`), incl. W16 / W16R2 test-only run identities (`w16_privacy_gate_tests.rs`) | `private_block/run.rs` (`RUN_PROFILE_*`, `ACCURACY_RUN_PROFILES`), `w16_privacy_gate_tests.rs` | every block of the run |
| Token-I/O run `hashline-zk-mr1/private-token-io-run-*` | 5 (`/1`) | `run.rs` (`TOKEN_IO_RUN_PROFILES`) | blocks and stages IN, OUT |
| Classifier run `hashline-zk-mr1/private-classify-run-*` | 5 (`/1`), incl. one test-only and `classify_batch.rs`'s `BATCH_PROFILE` | `run.rs` (`CLASSIFY_RUN_PROFILES`, `ACCURACY_CLASSIFY_RUN_PROFILES`) | blocks and stages IN-C, OUT-C |
| D55 registered (D60) `hashline-zk-mr1/` ‖ `d55-commit-fork-join-run/registered-opt-in-d60/v1/` ‖ base tail | 12; their version is the BASE's trailing `/1` | `run.rs` (`D55_RUN_PROFILES`) | every fork |
| D55 test-only prototype `d55-commit-fork-join-runs/opt-in-prototype-unregistered/test-only/v1/` ‖ base | built by `run_fork::fork_profile_for(base)` | `run_fork.rs` | every fork |
| Private attention `hashline-zk-mr1/private-attention-t32-poc` | 1 (`/1`) | `private_attention.rs` | yes |
| `--zk` FFN layers, repaired-mask probe | `hashline-zk-mr1/ffn-v3-mr1-probe/1` (`zk.rs`); headers `P1` (v2), `P1-v3` (v3 legacy tuple), `HL-ZK/1\|profile=…` (v3 other modes) | `zk.rs` | yes |
| Fresh FFN PoC | `hashline-zk-mr1/ffn-v3-mr1-fresh-poc/1` (`zk_ffn_fresh_poc.rs`); its layout self-report `ffn-v3-mr1-fresh-poc/1: …` (`zk.rs`) and observation JSON (`zk_ffn_observation_json.rs`) | | yes |
| Fresh FFN with private IO | `hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2` (`zk_ffn_fresh_io.rs`, `zk_ffn_io_diagnostic.rs`) | | yes |
| Experimental seam | transcript domain `experimental-private-seam/v1`, wire magic `HLSEAM01` (`private_seam.rs`) | | yes |

**Not `M` users, unchanged:** `hashline-zk-rng/…` (randomness domains), `hashline/private-*-schedule/1`,
`hashline/private-block-public/1` and the other digest domains, `hashline-zk-mr1/metal-test/1` and
`metal-bench/1` (hash-tag strings of the GPU commit tests), the negative-test strings
`no-such-block/1`, `wrong-profile/1`, `private-run-not-registered/1`, and the D55 marker and prefix
themselves (they version the D55 construction; a D55 string changes through its base).

## 3. Where the strings are registered, pinned and checked

- **CS-9** (`Shape::new` → `block_profile_names_this_shape`): a registered block string is admitted only with its
  one shape; a release build refuses an unregistered string, a test build admits it (probe shapes).
- **CS-7** (`RunShape::new`): a run string names exactly one block shape; an unregistered run string is refused
  in every build. **CS-8** (`check_constructed`) re-runs `Shape::new` at every single-block entry and in the two
  shared bodies, so a hand-built `Shape` with an unregistered string reaches CS-9 too.
- **The run registries**: `ACCURACY_RUN_PROFILES`, `TOKEN_IO_RUN_PROFILES`, `CLASSIFY_RUN_PROFILES`,
  `ACCURACY_CLASSIFY_RUN_PROFILES`, `D55_RUN_PROFILES` (`run.rs`), `W16_TEST_RUN_PROFILES`.
- **Source scans**: `s24_tests.rs`, `s25_tests.rs`, `s33_tests.rs` read every `"hashline-zk-mr1/…` literal out of
  `shape.rs` and `run.rs` (the ASCII/NUL premise, the J-7a length lemma over every registered length). `/1` →
  `/2` keeps every length. `s25`/`s26` also pin literals and line numbers of `private_seam.rs` (its `DOMAIN`,
  its two `ZkRng::from_os(DOMAIN)` sites, line 349).
- **Schedule digests**: `Layout::describe` line 1 is the profile string for every profile except the toy, which
  prints the legacy label `private-block-t32/1` (D17). So every non-toy block schedule digest, and every run,
  token-I/O and fork schedule digest built on it, moves with the string; `TOY_SCHEDULE_DIGEST`
  (`grow_tests.rs`) does not.
- **Hash tags**: every tagged commitment root (A, H, M, endpoints, boundaries) is keyed off the block string, so it
  moves with the string. The toy and the frozen-seam rung hash under the legacy (unkeyed) rule, keyed on their
  constants.
- **Goldens and pins in tests**: `r9_golden_tests`, `r12_golden_tests` (seeded core proofs, `#[ignore]`, heavy),
  `r12` statement identities, `w16r2_tests::W16R2_RUNG_GOLDEN` (`c6d5c2d8`, `#[ignore]`, needs the GPU),
  `hash_tag_tests`, `slot_ir_tests::EXPORT_DIGESTS`, `s35_tests` PINS, and the 64-hex pins in `run_tests`,
  `r4_tests`, `r12_tests`, `trained_statement.rs`, `trained_accuracy.rs`, `run_capture_tests`,
  `accuracy_proof_tests`, the token-I/O tests. Which of them actually move is measured, not assumed: see
  `REPIN.md`.
- **Pinned trained digests**: the six of `results/zk60_h124_witness_20261104/check_par2.sh` (`2b0d04bb`
  R13_SHIELD_T128_H24, `678953f6` R13_8B_T128_H24, `01a6d51d` W16_SHIELD_T128_H24, `c5e0bdac` W16_8B_T128_H24,
  `a9a19ee5` W16R2_SHIELD_T128_H24, `4e189ccc` W16R2_8B_T128_H24), printed by
  `slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times`.
- **Receipts on disk**: the toy's frozen receipt is 2,816,472 B (its length does not change, its value does);
  `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` reads archived pre-lane toy receipts, which
  stayed on the laptop (that is why it is one of the three known failures).
- **Capture source pins**: `run_capture::SHARED_SOURCE_FILES` records the SHA-256 of `src/zk.rs` and others in
  every capture, so every capture made after this change pins a new `zk.rs`.

## 4. The versioning design

**One code path.** `combined_weights` starts at θ¹ unconditionally. There is no θ⁰ verifier in the build. Old
receipts are not kept verifiable: they are unsound by F12, nothing is in production (D63), and a legacy verifier
would need the old strings registered beside the new ones in every registry above, which is not cheap. A test
build has one hook, `zk::set_pre_f12_theta_start_for_tests` (`#[cfg(test)]`, thread-local, the same pattern as
`shape::set_force_legacy_hash_rule`), so that the cross-version tests can make an opening the old way.

**A new version string per affected profile, the θ start keyed to it.** Every string of section 2 gets its
version one higher:
- every `hashline-zk-mr1/…/1` profile above and the two dev twins: `/1` → `/2` (the D55 strings follow their base;
  the D55 prototype prefix follows its base);
- the fresh IO PoC: `ffn-v3-mr1-fresh-io-poc/2` → `/3` (its `/1` was already a superseded draft);
- the `--zk` layer headers: `P1` → `P1/2` (v2), `P1-v3` → `P1-v3/2` (the v3 legacy tuple), `HL-ZK/1|…` → `HL-ZK/2|…`
  (the other v3 modes, and `header_v2`'s body);
- the seam: its wire magic `HLSEAM01` → `HLSEAM02`. Its `DOMAIN` is NOT changed: it is also the input of every
  frozen endpoint's spec digest (`SeamSpec::digest`, checked by `PreparedPlane::into_ffn_endpoint`) and the
  domain of the frozen endpoint generator (`private_seam::prepare`, used by the toy, the frozen-seam rung,
  private attention and fresh IO), so changing it would move values outside `M`'s opening. A seam receipt of the old construction is refused at decode
  (magic) and, in memory, at `M` (θ).

Since every registered string is at the new version, the build has exactly one θ start, and the string a
receipt is checked under says which `M` it used. The toy keeps every frozen treatment it had (legacy hash rule,
legacy schedule label, frozen parameter line), keyed on the renamed `TOY_PROFILE`: only `M` and the transcript
domain change for it. The same holds for the frozen-seam rung.

**Old strings refused for proving.** CS-9 and CS-7 already refuse an unregistered string (CS-9 only in a release
build). A test build admits unregistered block strings, so the refusal is made explicit and unconditional: a
string that ends in `/1` and whose `/2` successor is a registered block or run profile is refused at CS-9 and at
CS-7 in every build, by name ("retired by D65(1), finding F12"), before any registry lookup. Because CS-8 re-runs
`Shape::new` at every single-block entry and inside `prove_core`/`verify_core`, a hand-built `Shape` carrying an
old string cannot be proved or verified either.

## 4a. Tests

- **The F12 reproduction, flipped** (`hashline/src/zk_f12_tests.rs`):
  `f12_the_first_functional_is_certified_only_up_to_the_blinding_sum` now requires the forgery (a `b` with G_512
  sum δ = 5, functional 0 claimed as `true + δ`) to be REJECTED at the sum check, and also rejects a shift of k ∈
  {1, 5, 7, 512} on either functional. `f12_the_pre_f12_start_accepts_the_forgery` keeps the old reproduction
  through the test hook. The honest control still passes.
- **The two versions refuse each other**: at `M` (`f12_an_opening_under_one_version_does_not_verify_under_the_other`,
  both directions) and on real rung receipts (`private_block/f12_version_tests.rs`): a `/2` receipt verifies under
  `/2`, is refused under the `/1` string by name ("retired by ruling D65(1)") and under the θ⁰ `M` at `M`'s sum
  check; the `/1` string cannot be proved under; a receipt whose `M` was opened the θ⁰ way verifies only under
  θ⁰ and is refused by this build at `M`'s sum check.
- **Every retired string is refused**: 30 block profiles (the nine frozen constructors, the 12 R13 bases, W16,
  W16R2) at CS-8/CS-9 in the test build and at CS-9 as a release build makes it, and 19 run profiles (seven
  frozen-shape runs, the 12 R13 runs) at CS-7; every successor is admitted; the 12 D55 strings are at `/2`.
- `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` is renamed
  `a_toy_receipt_made_before_f12_is_refused` and now requires the archived pre-lane toy receipts to be REFUSED.
  The receipts are not on the Mac, so it still fails for the same reason as before ("no pre-lane toy receipt
  was found").
- `run_tests::the_retained_125m_statements_still_regenerate_their_public_weights` reads two archived pre-F12
  statements; it now expects them to name the retired `/1` 125M profile, and their public block digests still
  regenerate.

## 4b. Results (the Mac, 2026-11-05 UTC, every step under the resource guard, class gpu)

| Check | Result | Log |
|---|---|---|
| Full lib suite, θ change only (Run A) | 907 passed, 4 failed (the known three and the W16R2 rung golden), 94 ignored | `logs/a_theta_only_full.log` |
| Full lib suite, with the `/2` strings, before re-pinning (Run B) | 904 passed, 10 failed, 94 ignored; see `REPIN.md` | `logs/b_versions_full.log` |
| **Full lib suite, final** | **911 passed, 3 failed, 94 ignored (1,008 tests)**: exactly the known three, same causes (`a_toy_receipt_made_before_f12_is_refused`: no archived receipt on the Mac; `accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`: a missing file; `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`: the live-pid directory) | `logs/final/full.log` |
| W16R2 rung golden, CPU and Metal (`HL_GPU_REQUIRED=1`) | ok, both `96e4f0b6f34f…`, device sumcheck rounds ran | `logs/final/r2rung.log` |
| Six trained digests, CPU and Metal, cold and warm | ok, all six at their new values (`REPIN.md` 2a) | `logs/final/trained.log` |
| r9/r12 seeded goldens and statement identities (`#[ignore]`) | 7 passed at the new pins | `logs/final/goldens.log` |
| Integration tests that reach `M` (seam, private attention, private block, CFS channel, proof size, mask rank, tagged GPU commit) | all passed (26 tests; `zk60_tagged_gpu_commit` has 0 tests in this build) | `logs/final/integration.log` |
| Release build, `--bins --examples` (the `hashline` CLI and every example, incl. `zk60_trained_block`) | ok, no errors; warning count unchanged | `logs/final/cli_build.log` |

`check_f12.sh` reruns the final checks: `check_f12.sh <worktree> <out_dir>`.

## 5. What this invalidates (not redone here)

- **The D55 privacy-gate records**: the 12 merged records in `results/zk60_d60_20261102/privacy_gate_merged/records/`
  (and `privacy_gate/`, `privacy_gate_r26/`, the bundle manifests) were captured under the `/1` D55 profiles and
  θ⁰. They must be recaptured under the `/2` profiles. `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` stays `false`
  (not touched).
- **The trained captures and every other capture**: every capture records profile strings, the `M` opening and
  the SHA-256 of `src/zk.rs`; none made before this change matches this build.
- **Archived receipts**: every `/1` receipt (toy, rungs, trained runs, token-I/O, classifier, D55), the `--zk`
  layer proofs and their round-13/14 byte gates (`results/am_r3_8b*.sh`, the 8B row `930ce9a0..`), the seam
  receipts, the fresh FFN and fresh IO observations.
- **`apps/proven-media`** (another lane; not edited): `proven_media/shieldstral_runtime.py:20` pins
  `RUN_PROFILE = 'hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1'`; it needs `/2`.
- **Python tools that pin the old strings** (not edited, because they read archived pre-F12 captures and their tests
  run on those): `scripts/zk60_native_capture.py:23,27`, `scripts/zk60_private_block_inventory.py:338`,
  `scripts/zk60_attention_native_inventory.py:1017`, `scripts/zk60_opus_repaired_capture.py:117`,
  `scripts/zk60_opus_io_layout.py:57` (`PROFILE`, fresh IO `/2`; the preflight and capture scripts derive from it),
  and `scripts/zk60_io_opening_translation.py:162`, which recomputes `M`'s combined functional starting at
  `theta = ONE` and must start at `mask["theta"]` for any capture made by this build.
- **Frozen copies elsewhere in the repository** (the repo-root `hashline/` crate and the `ops/zkp-mvp/*` frozen
  trees and scratch copies) still carry θ⁰. They are records of earlier rounds and are not built here.
