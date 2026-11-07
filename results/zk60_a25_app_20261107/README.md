# A25: the media app's classifier proofs at a W16R2 development profile (2026-11-07)

Lane A25. Goal (Victor, 2026-11-07): "implement the new optimizations into the proof of concept media
app ... get the media app speed up to 30 or so tokens per second for the proofs." A24 left the app at
11.4 proved tok/s (`results/zk60_a24_app_20261107/README.md`). It named the lever: the classifier's 26
blocks at W16R2 instead of R13 (efficiency plan A10).

**Labels:**
- [MEASURED]: a number from a log in this directory.
- [INFERRED]: derived from measured numbers.
- [CODE]: read from the source.

**Metric** (MVP_STATUS's): proved tok/s = 128 × (category proofs completed) / wall seconds. Public text
only.

**Machine:** the M3 Ultra Mac, shared with the Lean lanes.
- Every run went through the resource guard at its default floors.
- Every run was launched by `polite_launch.py`, which leaves a 3-minute free window.
- No `ds4-bench` was running (`*.quiet`).

## 0. Plain summary

- **The real Shieldstral model cannot be proved at the W16R2 profile as the code stands.**
  - A W16R2 development classifier profile was built, tested at the development rung, and committed
    (section 2).
  - On the real export, its startup is refused before any header. The refusing check is the trained
    door's rule in `Shape::with_layer_calibration`: "a per-layer constant may change coefficients only".
  - At layer 0 it reports: "a layer calibration of
    `hashline-zk-mr1/private-block-shieldstral-3b-t128-lh24-w16r2/2` moves the plane list (A 72 -> 71,
    H 44 -> 43)" [MEASURED, `f1.progress` and the owner-private refusal log].
- **Why** [CODE + MEASURED]:
  - At R13 the plane list does not depend on the requantization shifts or the gate denominator. Every
    layer of this export has R13's (A 107, H 53).
  - At W16 / W16R2 the 16-bit range families do depend on them (`Shape::range_families`: the precision's
    widths, the gate shift, `wrho_s`).
  - The Shieldstral export names `sh_ao`, `sh_h`, `sh_s` and `sh_z` per layer: 17 distinct shift sets
    over 26 layers. It also names the gate denominator per layer (18, 19 or 20).
  - **The census** (`c1.progress`) [MEASURED]:
    - the door refuses 8 of the 26 layers (0, 1, 2, 3, 4, 5, 7, 8);
    - at each layer's own calibration and gate, the 26 W16R2 stages would have **3 different plane
      lists**: (A 70, H 42) for 2 layers, (A 71, H 43) for 12, (A 72, H 44) for 12.
  - The 8B W16R2 stack's 32 tok/s used a synthetic model, one calibration copied into all 32 blocks, so
    it never met this rule.
- **Per your ruling, I stopped there and loosened nothing.** No W16R2 run on the real model exists, so
  this report gives no W16R2 tok/s figure, measured or modelled.
- **The R13 path is unchanged** [MEASURED]:
  - Without the switch, this lane's binary reports A24's trained statement identity `e4f97455…`.
  - It proves and freshly verifies one public post in 55.5 s: 6.92 proved tok/s with 3 × 10 prover
    lanes. A24's one-post run was 64.4 s; that is one run each, not a pair.
  - A24's pinned binary (`ccd58102…`) accepts this binary's R13 receipts, re-checking the published
    statements byte for byte. This binary accepts them too.
- **The app mode was written but is not committed.**
  - `PM_PROVER=shieldstral-fast-w16r2`, a sibling of A24's `shieldstral-fast`, must pin the real
    export's W16R2 trained statement identity. That identity cannot be derived, because the export does
    not load under the profile.
  - Its code is kept as `app_w16r2_mode_unmerged.patch` (section 4).
  - The app on this branch is A24's, byte for byte (216 tests OK).
- **30 proved tok/s is still not reached.** The W16R2 lever first needs a design step and a ruling
  (section 5).

## 1. What was measured

| run | what | result | label |
|---|---|---|---|
| `stream_w1` (f1) | one public post, `serve --dev-w16r2-public-content-only` | startup refused at layer 0 by `with_layer_calibration` (A 72 -> 71, H 44 -> 43); nothing created | [MEASURED] |
| `stream_r1` (f1) | the same post, this binary, no switch (R13), 3 × 10 prover lanes, 3 × 4 verifier lanes, every receipt freshly verified | 55.5 s wall, 6.92 proved tok/s; writer 10.3 s; the three proofs at once 34.9–35.2 s; the three checks 10.0 s (verify 9.35 s each); identity `e4f97455…`; receipts 809 MB each | [MEASURED] |
| c1 compat | A24's pinned binary `verify` on this binary's R13 receipts (sexual, hate); this binary's `verify` without the switch (violence) | all exit 0, "an earlier verifier (re-checked byte for byte)" | [MEASURED] |
| c1 census | each real layer at the W16R2 twin of the run seed (`a25_census_the_real_export_at_w16r2`, ignored, guarded) | door refuses 8/26; 3 distinct W16R2 plane lists across the 26 stages (table below) | [MEASURED] |

The census [MEASURED, `c1.progress`]:
- **Run seed:** R13 (A 107, H 53); its W16R2 twin (A 72, H 44).
- **Run calibration:** `tn 9, cn_a 2174, cn_m 1481, ceps 2439, sh_ao 6, sh_qkv 8, sh_s 6, sh_o 9, sh_g 8, sh_h 14, sh_z 8`.

| W16R2 plane list at the layer's own calibration and gate | layers | of which the door refuses |
|---|---|---|
| A 70, H 42 | 0, 3 | 0, 3 |
| A 71, H 43 | 1, 2, 4, 5, 7, 8, 14, 16, 18, 20, 22, 25 | 1, 2, 4, 5, 7, 8 |
| A 72, H 44 | 6, 9, 10, 11, 12, 13, 15, 17, 19, 21, 23, 24 | none |

Six layers pass the door but would still change the plane list through their own gate denominator:
14, 16, 18, 20, 22 and 25. The door compares at the seed's gate of 17, so it does not test this. The run
proves each stage at its own `block_layout(k)`, but two parts read one block shape for all stages:
- the statement's schedule line and its single `Layout::for_shape(seed)` description;
- the whole-run LogUp count (`r13_block_logup_numerator(sh)` × L).

Both would need per-stage forms, which is a design and review item. Since the door refuses first, I did
not test how such a run would behave. Either way the profile cannot carry this model without a design
change (section 5).

**Not run** (the W16R2 refusal stops them):
- the m1 / m2 stream pairs (`m1.sh`, `m2.sh`, written);
- the deferred-verification "proof-only" clock (`stream_driver.py --defer-check`, written);
- the app runs.

No measured or inferred W16R2 throughput exists for this model.

## 2. What was built and committed (native)

**The profile** [CODE], `run.rs` (a small additive edit; the coordinator accepted it for this lane):
- **The run profile:**
  `hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-w16r2-dev-only/2`
  (`RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV`).
  - It is 73 bytes, the R13 T128 classifier profile's length.
  - Its one block profile is `W16R2_SHIELD_T128_H24`, in `W16R2_DEV_CLASSIFY_RUN_PROFILES`.
- **How it is admitted:**
  - CS-7's `registered_block_shape` rebuilds that shape through the same R13 door.
  - `is_classify_run_profile` admits the profile.
  - A blocks-only run statement refuses it.
- **Not registered:**
  - `CLASSIFY_RUN_PROFILES` and `ACCURACY_CLASSIFY_RUN_PROFILES` are unchanged.
  - It has no D55 profile, and `run_fork` refuses it as a base.
- **A test-only twin** at the W16R2 rung: `RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST`.

**The switch** `--dev-w16r2-public-content-only` (`token_io/classify_w16r2.rs`, new):
- It works on `prove`, `verify`, `input-owner`, `label`, `serve` and `check-serve`.
- With it, the export's registered R13 Shieldstral T128 seed maps to its W16R2 twin. Every geometry field
  is compared, and every other seed is refused by name.
- The digest pass then loads at that shape (`ExportPublic::load_keeping_at`).
- The statement's `scope` says "a DEVELOPMENT classifier proof ... for PUBLIC development content only;
  not registered for real content ...; NOT a privacy acceptance; not production (D63)".
- The server start line names `development_profile`.
- Without the switch, every byte is as before.

**What the profile is:** the same classifier run with every block at the W16R2 stage shape.
- Unchanged from R13: stages IN-C and OUT-C, the input endpoint (the tier's rate 1/4), the policies, the
  tied tables, and the chunk plan (overlap 8).
- Its own transcript domain, run seed domain, hash keys (the W16R2 block profile's) and trained statement
  identity, which names both profiles.
- The whole-run figure prices block and boundary openings at the unique-decoding radius (D59, review F6).
  The L = 26 floor is at least 95 bits (tested).

**Tests** (`token_io/classify_w16r2_tests.rs`, all at the development rung or on the census statement):
- The profile is on no registered list; CS-7 holds in both directions.
- The R13 tied source, chunk plan and D27 floor apply; the L = 26 floor is at least 95 bits with
  3 × 26 + 1 openings at the unique-decoding radius; the run headers are distinct; a blocks-only run
  refuses the profile.
- The seed map: the T128 seed maps; T256, W16, W16R2 itself and the legacy rung are refused.
- On the public R13 loader fixture, the W16R2 digest pass keeps the R13 pass's blocks (equal digests)
  under its own identity. The R13 load is the old loader's identity.
- A two-stage W16R2 rung run (two gate denominators):
  - proves, verifies under a fresh statement and passes the input-owner check;
  - has the same boundary planes and verdict as the R13 rung run on the same content.
- Negative controls, all refused:
  - a changed byte;
  - the R13 statement over the W16R2 segments, and the reverse;
  - the other verdict;
  - tables bound to the other statement.
- The switch on the legacy rung export refuses `serve` and `check-serve` at startup, and `prove` (which
  creates nothing) and `verify`. Without the switch the fixture proves and verifies.
- `a25_census_the_real_export_at_w16r2` (ignored): the census above.

**Minimal edits elsewhere:**
- `classify.rs`: the overlap; the census lists.
- `classify_tied.rs`: the tied source.
- `load.rs`: `load_keeping_at`; `load_keeping` is it with the seed itself.
- `classify_cli.rs` / `classify_serve.rs`: the switch.
- `s25_tests.rs` / `hash_domain_tests.rs`:
  - module graph 54 -> 55 files;
  - `TEST_ONLY_FILES` 84 -> 85;
  - the r18 list;
  - label scan 54 -> 55 files, followed 52 -> 53.

**No change** to `shape.rs`, `trained_block.rs`, `run_fork.rs`, `protocol.rs`, `argument*.rs`, the PCS,
`src/manifest.rs`, any 8B path, or the R13 classifier's bytes.

## 3. Tests and byte preservation

**accept_t1** (one guarded job, `accept_t1.progress`):
- the release test build;
- `a25_` 5 passed, `a24_` 5, `s25_tests` 20, `hash_domain` 15, `s24_tests` 10, `s33_tests` 10;
- `token_io::classify` 87 passed (12 ignored), `w16r2_f6` 1, `w16r2_profiles` 1; 0 failed;
- `cargo check --tests` without the gpu-metal feature: clean;
- release `zk60_classify` built, SHA-256 `32a386ff…` (a copy sits outside the repo at
  `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a25`).

**c1:**
- the census;
- the R13 compatibility checks above;
- `a25_` 5 passed, 1 ignored;
- **the full hashline lib suite** (release, gpu-metal): 972 passed, 3 failed, 131 ignored. The 3 failures
  are exactly the A23 merge's known ones: `a_toy_receipt_made_before_f12_is_refused`,
  `accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces` (a fixture absent on the
  Mac) and `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`;
- zkp-core: 81 passed;
- no warning in this lane's files;
- the guarded job's peak RSS was 9.29 GiB.

**App:** 216 tests OK (A24's app; this lane's app mode is not on the branch).

**Byte preservation** [CODE + MEASURED]:
- Without the switch, every command runs the old function with the old inputs:
  - `load_keeping` is `load_keeping_at` with the export's own seed;
  - the scope text and the start line are chosen only for the development profile.
- The R13 identity is `e4f97455…`, as A24's.
- A24's pinned binary accepts this binary's R13 receipts byte for byte.
- No 8B source changed.
- The fixed-entropy byte-identity harness needs bubblewrap and was not run on the Mac.

## 4. The app mode (written, not committed)

`app_w16r2_mode_unmerged.patch` holds it; `git apply` on A24's app restores it.

**Why a sibling mode** rather than a switch inside `shieldstral-fast`:
- every record, statement and receipt then names its mode, binary, identity and run profile;
- A24's mode keeps its pins and tests;
- the two services keep separate directories, screening sets and guard labels.

**What it contains:**
- New `shieldstral_fast_w16r2_runtime.py` (pins, the servers' command lines with the switch,
  `production: False`, privacy pending, `public_posts_only`) and `shieldstral_fast_w16r2_prover.py`.
  - The new prover is A24's prover over this runtime.
  - It also refuses a verified statement that does not name the development run and block profiles.
- Changes to A24's files:
  - A24's prover reads its pins through `self.runtime`;
  - `tools/fast_service.py` takes `--runtime w16r2`;
  - `fast_service.guard_command` keeps A24's command line unchanged;
  - `config.py`, `provers.py`, `app.py`, `jobs.py` and `hardware_profiles.py` are updated;
  - `deploy.json` gains `shieldstral-mac-fast-w16r2`.
- An 8-test file.
- All of A24's 216 tests passed with it applied. Its own 8 tests need the `IDENTITY` pin, which this
  export cannot give.

## 5. What it would take, and the decisions for Victor

**A10 for the classifier now needs a design step** before the privacy gate and the ruling. Three routes,
none taken here:
1. **Per-stage plane lists in the statement and the accounting.** The run already proves each stage at
   its own layout. Three pieces would change:
   - the statement's schedule would describe each stage's layout;
   - the whole-run LogUp count would sum per stage;
   - the trained door's rule would admit a layer whose calibration and gate move the W16 plane list.
   Under D17 that is a new profile, with review, and the Lean statements would follow. The census gives
   3 layouts for this model.
2. **A uniform-calibration Shieldstral export.** One shift set and one gate for all 26 layers is a
   different integer model (accuracy re-validation by the calibration lane, a new trained statement).
3. **Rate 1/2 at R13's byte limbs** (no W16 families, so a calibration-independent plane list). This
   would be a new D59-style profile with its own lemma check, review and accounting. It keeps R13's
   larger A and H, so it is a smaller gain.

**Decisions for Victor:**
- Which route, if any, to commission for the classifier.
- Whether the committed W16R2 development profile (unregistered, behind its switch, public content only)
  stays on the branch as groundwork, or is dropped.
- Whether to register W16R2 for real content at all. That remains his ruling (A10), after the W16R2
  privacy gate on GPU-made bundles and D60's conditions.

## 6. Operational notes

- **Commands:**
  - `stream_driver.py`: A24's driver with `--profile r13|w16r2`, `--bin` and `--defer-check`.
  - `stream.sh`: the quiet-box record.
  - `f1.sh`, `c1.sh`, `accept.sh`: the jobs that ran.
  - `m1.sh` (W R R W stream pairs) and `m2.sh` (one-post pairs, deferred verification): ready for a
    profile that loads.
  - `app_driver.py`: A24's driver with `--mode`.
  - `negctl.sh`: real-receipt controls for W16R2.
- **Data:** private run data was under `~/zk60-owner-private/a25-*` (0700) and receipts under
  `~/zk60-artifacts/a25-*`. Both were deleted once their numbers were recorded. This directory holds
  scripts, summaries and logs of public words only.
- **Guard:** default disk floor; about 128 GiB free throughout.
