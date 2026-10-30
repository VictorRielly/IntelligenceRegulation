# Token review, round 16: the real Shieldstral-1.0-3B classifier on native R13

Reviewer: independent soundness / code review of the frozen token tree `frozen-r16/` (2026-10-29, 09:31–10:05 UTC).
**This is not a privacy review and not a classifier-fidelity review.**

## Verdict

**Round 16 is ACCEPTED WITH FIXES on soundness for its scope.** The proof side holds at every item. One fix is
required before the app or the privacy gate relies on "the fixed policy list"; it is a D45(2) conformance defect,
not a soundness one (F-1).

In plain words:

* **The proofs are sound.** The frozen-tree binary `dae5abd7…` re-verified the real moderate-hate receipt in a fresh
  process: statement `29aeba6c…`, verdict not-flagged, floor 96 bits. The lane had already checked the sexual one.
  Each block is checked at its own layer's gate denominator before the run header. A doctored denominator, a block
  at the wrong stage and the run seed's shape are all refused. The R13 lookup term is the one native R13's review
  asked for.
* **The security figure is right.** I recomputed it from first principles, using the native reviewer's own lookup
  count. T128 gives 2^-96.86 (floor 96) and T256 gives 2^-95.91 (floor 95), at every registered policy, matching the
  lane. `--min-bits 95` passes at both; one bit more is refused at both.
* **The activations cannot cheat.** I ran a prover with its own checks switched off and handed it three kinds of
  wrong activations. The verifier refused all three receipts. So `--seq-dir` is a completeness and app-integration
  matter, not a soundness one (§8).
* **One checkpoint read per command, and it is still authenticated.** The table derivation now happens inside the
  export load's own pass. The checkpoint is still checked against the model pin. The reused derivation is taken only
  with the bound profile's own parameters.
* **The defect (F-1):** the deployed profiles admit **four** Shieldstral policies, not three. Round 12's
  `shieldstral-1.0-3b-card-unsafe/1` (the model card's 7-category template) is still in the production policy list.
  It carries the export's own (yes, no, scale, c), so the T128 profile door and the statement constructor accept it,
  and a verifier would accept its receipts. The freeze note, DESIGN §17.4 and the README all say "one fixed list,
  three policies" (D45(2)).
* **A test gap (N-r16-1):** none of the lane's tests pins the whole-run figure itself. A mutant that charges one
  block instead of 26 raises T128's floor from 96 to 98, and the lane's tests stay green. My S2 kills it.

## What was reviewed

* **The freeze.**
  * `results/zk60_token_io_r1_20261017/frozen-r16/` has 300 files, matching `manifest_final_r16.sha256` (list sha256
    `f42f8c6e…`, recomputed). It still matched after all my runs (`r16/tree_check_r16.py`).
  * My copy `ops/zkp-mvp/token-io-review-r16-scratch/` matched it file for file before my edits
    (`r16/tree_check_r16.before.json`).
  * Native R13's frozen tree re-hashes against its own manifest: 269 files, tree `bb9eb212…`.
* **Read in full:**
  * every r15 → r16 change in the token files: `classify.rs`, `classify_run.rs`, `classify_cli.rs`,
    `classify_tied.rs`, `load.rs`, `token_io/run.rs` and `examples/zk60_classify.rs` (diffs saved in `r16/diffs/`);
  * the round's test file `classify_r16_tests.rs`;
  * all 12 native files where the token tree differs from R13 (`r16/diffs/native13_vs_token16.diff`);
  * native R13's `LayerRecord::shape_at` / `check_accuracy_gate`, `RunStatement::stage_shape`, `fit_the_stages`,
    the CS-7 registry, the trained identity encoding, and the tied derivation `tied_tables/derive.rs`.
* **My runs.** All were guarded, detached and serial, on a shared box with nothing else live (n = 1). Each started
  only after a `WINDOW_HOLD` check and a lean-memory check (no other non-light job).
  * a from-scratch test build: 191 s, peak 2.25 GiB;
  * one test batch: the lane's 7 round-16 tests plus my S1–S4 (11 passed, 1 ignored; 109 s, 1.65 GiB);
  * two mutant runs (1.65 GiB each);
  * **one** real verify, the only checkpoint read of the whole review: 71 s, 2.25 GiB RSS, cgroup 5.0 GiB, which is
    the cap, filled with reclaimable page cache; no kill.
  * I did not re-run the full suite or any prove (§7).
* **My code lives only in my scratch copy** (`r16/review_scratch_vs_frozen_r16.diff`):
  * `token_io/review_r16_tests.rs` (sha256 `ff9b2c62…`), registered by one `mod` line;
  * two mutant hooks, `rv16_mut("bits-l")` in `classify.rs` and `rv16_mut("prehdr-cs6")` in `classify_run.rs`. Both
    are inert unless `RV16_MUT` is set in a test build.

Line numbers below are those of `frozen-r16/hashline/src/private_block/`.

## 1. Per-item table

| # | Item | Verdict | Where |
|---|---|---|---|
| 1 | Rebase onto R13: native files are frozen R13's except the documented token lines; conflicts resolved correctly | **HOLDS** | §2; `r16/tree_check_r16.json`, `r16/rebase_check_r16.json` |
| 2a | Per-layer gate shift in `stage_shape`; a doctored shift is refused before the header | **HOLDS** | `token_io/classify.rs:981–982` (record checked, G kept), `:1052–1066` (`stage_shape`, native `shape_at`), `:992` (every stage shape built at construction); verifier `classify_run.rs:250–255`; prover `classify_run.rs:135–139`, CLI `classify_cli.rs:487` |
| 2b | Each block checked against its own stage shape; a wrong shape is refused | **HOLDS** | `classify_run.rs:74–80` (`stage_block_is_the_statements`), `:253` (pre-header), `:283` (per stage) |
| 2c | `build_for_block` used | **HOLDS** | `classify_run.rs:436`, `classify_cli.rs:444, 491` |
| 2d | R13 run and block profiles | **HOLDS** | `run.rs:146–189` (profiles, CS-7 pairs), `:265–268` (CS-7 rebuild through `Shape::accuracy_trained`), `:546` (blocks-only refusal) |
| 2e | Export schema v2 | **HOLDS** | native `TrainedExport::load`; the r15 binary refuses the export (`r16/logs/red-r15-binary.log`) |
| 2f | No prover-supplied derived tables | **HOLDS** | the token lane reads blocks only through native `reload_block` (`token_io/load.rs:279`) and no accuracy table anywhere (grep, §3) |
| 2g | `block_logup_size` = (N + 4·T_d − 1)/p² per block | **HOLDS, recomputed** | `token_io/run.rs:128–143`, `classify.rs:878–887`; T128 2^-96.86 → 96, T256 2^-95.91 → 95 (§3, `r16/bits_r16.json`) |
| 2h | `--min-bits 95` enforced at both profiles | **HOLDS** | CLI floor `classify_cli.rs:658–665`, `classify_tied.rs:533`; statement floor `classify_run.rs:235`; my S2 |
| 3a | The run profiles bind the export profile digests (T128 `2ba468f9…`, T256 `1d500782…`) | **HOLDS, through the pinned statement identity** | identity encodes block and run profile, the weights pin, the tied record, `export-profile-sha256` and each layer's G (`trained_statement.rs:815–905`); `--expect-statement` is required (`classify_cli.rs:666–669`). T256 has no published identity yet (N-r16-5) |
| 3b | The fixed three-policy list (moderate, flagged pending Victor) | **NOT AS STATED: four policies admitted (F-1)** | `classify.rs:243–247` (the card policy is still in `registered_policies()`), `:145–166`; my S1 |
| 3c | Pad id 11, overlap 8 | **HOLDS** | `classify.rs:208` (pad), `:266–273` (overlaps); the lane's registry test |
| 3d | A T256 statement under T128 is refused | **HOLDS** | CS-7 (`run.rs:322–329`), trained-statement calibration check; the lane's test |
| 3e | A policy outside the list is refused (D45(2)) | **HOLDS for unregistered ids** (strict-\*, `/2`, self-harm refused by name, `classify.rs:253`); see F-1 for the list itself |
| 4 | One checkpoint stream; load and derivation read the same bytes; the sha256 is still checked against the pin | **HOLDS** | §5; `trained_block.rs:575–649`, `tied_tables/derive.rs:134–156, 221–223, 265`, `classify_tied.rs:252–276` |
| 5 | A real receipt re-verified by `dae5abd7…` in a fresh guarded process | **PASS** | moderate-hate: identity `29aeba6c…`, not-flagged, floor 96, root `4cf9e8ae…` = the lane's (`r16/logs/rvtk16-verify-hate.log`) |
| 6 | Evidence: s20 934/0/68; the red run; 4/4 mutants; r15 ↔ r16 cross-verify | **HOLDS** | §7 |
| 7 | The `--seq-dir` activations are bound by the proof | **HOLDS: a completeness / app-integration issue, not a soundness one** | §8; my S3 |

## 2. The rebase (item 1)

* **Tree level.** I checked independently of the lane's lists.
  * The token tree has 257 files equal to native R13, 12 that differ (the lane's list) and 31 token-only files.
  * No native R13 file is missing from the token tree, and no file was left at R12b's bytes.
  * R12b → R13 changed or added 67 native files: 55 are byte for byte R13's, and the other 12 are the token-touched
    ones.
* **Line level** (`r16/rebase_check_r16.py`). For each of the 12 files I compared two things: the token lane's
  delta over native at r15 (frozen-r15 vs R12b) and its delta at r16 (frozen-r16 vs R13).
  * **Every r15 token edit survives.** That covers the `pub use` lines in `private_block.rs`, the 62 lines of run
    profiles in `run.rs`, and the visibility words in `trained_block.rs`.
  * **The only R13 lines missing from the token tree** are the ones the lane replaced on purpose:
    * three merged counters: `hash_domain_tests` lane list 36, `OWN_SOURCE_FILES` 38, the s25 count;
    * the four `HL_R13_LOADER_FIXTURES` fixture paths (test only).
* **Conflict resolutions.** All are correct:
  * `OWN_SOURCE_FILES` keeps R13's 32 entries in R13's order (N-r13-6), then the token entries, with no duplicate.
  * `tied_tables.rs` takes R13's side (R13 already carried the three `pub(crate)` words).
  * The s24 / s33 registrations keep both lists, and the s25 count sums both registries.
* **The round's own native edits** are confined to:
  * `run.rs` (classifier profiles, CS-7 entries, the blocks-only refusal);
  * `trained_block.rs` and `tied_tables(.rs, /derive.rs)` (N-r13-5);
  * two test files (the fixture path).

## 3. REVIEW_R13 §10 (item 2)

**Gate denominators (§10 item 3).**

* `ClassifyRunStatement::new_chunk` calls native `check_accuracy_gate` on every layer record. The rule is: an R13
  layer has exactly one class-checked G, a legacy layer has none. The statement keeps that G (`classify.rs:981–982`)
  and builds every stage shape at construction (`:992`).
* `stage_shape(k)` is native R13's (`:1052–1066`): the layer's own calibration first, then
  `with_accuracy_gate_shift(G_k)`. A legacy stage that carries a G is refused.
* G is bound three ways:
  * through the model identity's `accuracy-gate-layer` field (the `calibration` absorb);
  * through the block digests (the `public-statement` absorb);
  * through the stage line (the `schedule` absorb).
* The real export's denominators are 18–20 per layer (the lane's `real-act.log`). None is the seed's 17, so the
  pre-round code would have refused every stage.

**Per-block stage check (§10 item 4).**

* Before its header, the verifier checks every block against its own stage shape plus CS-6 (`classify_run.rs:250–255`).
  It checks again per stage before `verify_core` (`:283`).
* The prover's sealing pass does the same (`:135–139`), and so does the CLI's seal chain (`classify_cli.rs:487`).
* The lane's tests cover a doctored G (21 → 22, self-consistent records and tables), swapped blocks, the run seed's
  shape, and junk segments with the stage check firing first. Its `gate` and `prehdr` mutants are killed.
* My `prehdr-cs6` mutant (CS-6 dropped from the pre-header pass only) **survives**, and correctly so: the per-stage
  CS-6 at `:283` still refuses a foreign block before its segment is verified (N-r16-4).

**`build_for_block`, profiles, export v2, derived tables (§10 items 2, 5).**

* All three witness builders use native `build_for_block`.
* The two classifier run profiles have their own ids (D17), and the CS-7 registry rebuilds each one through
  `Shape::accuracy_trained`, as native `RunShape::accuracy` does.
* Only non-DD Shieldstral profiles are registered (N-r16-6).
* The token lane never reads an accuracy table. Blocks come from native `reload_block` with a CS-6 digest check
  (`load.rs:279–281`). The only accuracy reference in token production code is `with_accuracy_gate_shift`.

**The whole-run figure (§10 item 6) [COUNTED, recomputed].** `r16/bits_r16.py` recomputes the figure from first
principles, not from the lane's `WholeRun`:

* **Column term:** per opening q·log2(1 − δ/3), with hiding openings RS(n + q, n·rate) and the mask
  RS(1024, 4096); 112 openings.
* **LogUp term:**
  * **REVIEW_R13 §6's own N** per block (66,879,488 at T128 and 154,730,496 at T256, the native reviewer's census),
    T_d = 512 + 4·4096, term (N + 4·T_d − 1)/p².
  * The code's U8 + S + F counts give the same N at both T.
  * Stage OUT-C (N + 3R − 1) and stage IN-C are included.
* **PCS and sumcheck bound:** 2^-113 per opening and 2^-117.2 per stage.

| Profile | Column | LogUp (per block) | PCS + sumcheck | **Whole run** | Floor | Margin over 95 |
|---|---:|---:|---:|---:|---:|---:|
| T128 | 2^-98.79 | 2^-97.30 (2^-102.00) | 2^-106.17 | **2^-96.86** | 96 | 1.86 |
| T256 | 2^-99.01 | 2^-96.09 (2^-100.79) | 2^-106.17 | **2^-95.91** | 95 | 0.91 |

* The figures are identical at all four admitted policies: P0 does not enter the figure.
* The stage terms are 2^-107.09 (IN-C) and 2^-112.28 (OUT-C).
* Everything equals the code's figures and the lane's claim.

**`--min-bits` (S2).**

* With `--min-bits` equal to the floor (96 at T128, 95 at T256), the verifier passes its floor door at
  `classify_run.rs:235`. One bit more is refused there, by name, before anything else is read.
* The CLI refuses `--min-bits` below 95 at both profiles (`min_bits_floor`, `classify_tied.rs:533`; the lane's
  registry test).

## 4. Profile binding (item 3)

* **The export profile digests.**
  * The run profiles do not carry export digests as constants. The binding is the trained statement identity,
    which `--expect-statement` requires on every verify, input-owner and label (`classify_cli.rs:666–669`).
  * That identity encodes the block profile, the run profile, the pinned weights sha256, the tied record (new in
    `load_with`, `load.rs:244`), `export-profile-sha256` and every layer's G.
  * The real export's `profile.json` has sha256 `2ba468f9…` (recomputed), and my verify under
    `--expect-statement 29aeba6c…` passed.
  * T256 (`1d500782…`, pinned only in native's `accuracy_proof_tests.rs:134`) has no published statement identity
    (N-r16-5).
* **Pad 11, overlap 8, c = 0, yes 13059 / no 2649, scale bits `0x3ed11ff597db2fb6`:** all hold. Each moderate
  prefix is pinned by SHA-256 against Astra's candidates in the lane's test.
* **T256 under T128:** refused by CS-7 and by the trained statement's calibration check (the lane's test; 3d above).
* **The policy list: F-1.**
  * The production `registered_policies()` (`classify.rs:243–247`) returns five entries: the rung's dev policy,
    **`shieldstral-1.0-3b-card-unsafe/1`**, and the three moderate category policies.
  * My S1 hands each one to the T128 profile door with V = 131,072 tables:
    * the dev policy is refused (V = 300);
    * **all four Shieldstral policies are admitted**, the card one at P0 84 (chunk 43);
    * the card policy also passes the whole statement constructor.
  * The real T128 export's `classifier_margin_parameters` equal the card's (13059, 2649, 4.08288030735373e-6, 0), so
    `check_policy` and `check_for` accept it on the real model too.
  * The card's doc comment still says "until then no run profile admits it" (`classify.rs:144`); that stopped being
    true this round.
  * Unregistered ids are refused by name (S1).

## 5. One checkpoint stream (item 4, N-r13-5)

* **Same pass.**
  * `TrainedExport::load` → `tied_of_with_derivation` (`trained_block.rs:575–649`) derives the margin row inside
    the load's own authenticated pass. It does so when `profile.json` names well-formed
    `classifier_margin_parameters` (`declared_classifier_margin`, `:567`).
  * The classifier's loader then reuses that derivation (`classify_tied.rs:261–264`). There is no second derivation
    that could see another checkpoint.
* **The pin and the bytes.**
  * Inside the pass, `Checkpoint::open` hashes the whole 7.7 GB file and refuses unless the hash is the model pin
    (`tied_tables/derive.rs:156`). The norm bytes are captured from those same reads (`:134`).
  * The tensor rows the derivation reads are re-hashed against the pinned tensor digest (`:265`), so even a file
    changed between the two reads is refused.
  * `profile.json` is re-read and compared with the loader's parsed copy (`:221–223`).
  * All of this is native R12b code and unchanged. The token edit only passes `Some(margin)` through.
* **Reuse rule.**
  * The derivation is reused only if its `(yes, no, scale bits)` equal the bound profile's (`:261`). The bound
    profile is read with its digest checked against the statement's `export_profile_sha256` (`:224–231`).
  * The derivation's own `profile_sha256` must also equal that digest (`:274–276`).
  * The lane's `reuse` mutant is killed. My S4 adds: a reused derivation with no row, or with a row 3071 or 3073 wide,
    is refused; under another statement digest it is refused at the bound-profile read; the stub proves no second
    stream.
* **Notes:** N-r16-2 (the type boundary now also rests on `TiedDerivation`) and N-r16-3 (streams on the refusal path).

## 6. The real receipt (item 5)

* **Command.** `cli/zk60_classify.r16-frozen.release.bin` (sha256 `dae5abd78954…`, rehashed), run through the guard
  as `verify`, needing 3.0 GiB with a 5.0 GiB cap. Arguments:
  * the T128 export and its `token_io/`;
  * `--policy shieldstral-1.0-3b-moderate-hate/1`;
  * `--expect-statement 29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1`;
  * `--min-bits 95`.
* **The receipt.** It was made by `e94cecf9…`. I read it through hard links in
  `~/zk60-artifacts/token-io/review-r16/hate-run-link/`, so nothing was written into the lane's directory, and I
  removed the links afterwards.
* **Result [MEASURED, n = 1]:**
  * exit 0, `classified`, verdict **not-flagged**, floor 96;
  * the published statement re-checked byte for byte;
  * input root `4cf9e8ae…`, equal to the lane's `real-verify-hate.log`;
  * verify 39.6 s, total 71.1 s, peak RSS 2.25 GiB;
  * one checkpoint stream.
* **Coverage.** With the lane's frozen-binary sexual verify, two of the three categories are now verified by the
  frozen tree's own binary.

## 7. Evidence (item 6)

* **s20** (`r16/logs/s20-suite.log`): 29 `test result` lines, all `ok`.
  * Tally recomputed: **934 passed, 0 failed, 68 ignored**, with no `FAILED` and no panic.
  * The run used `cargo test --release --offline --locked -j2 --no-fail-fast` on `ops/zkp-mvp/token-io-r16` (the
    chain script and the `Compiling` line).
  * Guard record: exit 0, 875 s, 6.80 GiB.
  * The manifests taken before and after the suite equal the freeze.
* **Red run:** the frozen r15 binary on the real R13 export refuses with "schema `/2`, this reader reads `/1`", exit 1,
  with no stream.
* **Mutants:** `gate`, `prehdr`, `bits` and `reuse` each fail their killing test (`mut-*.log`, each reverted with its
  sha256 checked).
  * My two: `bits-l` survives all 7 lane tests and is killed only by my S2 (N-r16-1); `prehdr-cs6` survives (N-r16-4).
  * Table: `r16/mutation_table_r16.json`.
* **Cross-verify:**
  * `xbin-r16-r15.log`: 23- and 22-id rung items proved by r16 and verified by r15 and the reverse, all exit 0,
    identity `061340df…` unchanged.
  * `xbin-frozen-r16.log`: the two r16 binaries cross-verify both ways.

## 8. The activations (item 7)

* **Where the activations enter.** The prover's `--seq-dir` files are witness data only:
  * `x_in_L00` must equal the embedding of the item (`classify_cli.rs:559`);
  * every block is rebuilt from the builder's own chain and compared with `x_out_LXX` (`:454`, `:491`, `:591`);
  * the committed boundary planes are the files' `x_out` (`:460–461`).
* **What binds them.** The proof does:
  * block k's outgoing IO claim and block k+1's incoming claim open the same committed boundary;
  * stage IN-C ties `B_in` to the sealed token endpoint through the embedding lookup;
  * the input root is bound to the statement.
* **Shown live (S3).** I used a cheating prover (CS-3, CS-6 and the sealing checks off) on native R13's h24 rung,
  with two stages at different G. The sealed input was always the honest content's.
  * **Control:** verifies.
  * **Wrong boundary 1:** the receipt (4 segments) is **refused**: block 0, slot 22 [IO-out endpoint equality].
  * **A self-consistent chain from a wrong layer-1 input** (block 1's witness, B_2 and stage OUT-C all recomputed from
    it): **refused**, at the same slot.
  * **A whole chain from a wrong `B_in`:** **refused**: stage IN-C's H opening.
* **Conclusion: the activation source is a completeness and app-integration issue, not a soundness one.** A wrong
  activation set gives either a refusal in the sealing pass (the honest CLI) or a receipt no verifier accepts.
* **What remains (no soundness effect):**
  * the app needs a per-item source of these files;
  * the round's parity is self-consistency (the lane says so; REVIEW_R13 §2 is the independent parity);
  * the activation files are prover-private and must never be published: `refuse_prover_private_entries` guards
    the export, and the files are 0600 under `~/zk60-artifacts/`.

## 9. Findings

**F-1 (medium; D45(2) conformance, not a soundness defect; fix before the app or the gate relies on the list).**

* **What is wrong.** The production policy registry still holds round 12's `shieldstral-1.0-3b-card-unsafe/1`
  (`classify.rs:145–166, 243–247`). At both R13 Shieldstral profiles it is admitted next to the three moderate D37
  policies, because its (yes, no, scale, c) are the export's own.
* **Why it matters.**
  * A receipt under it would verify, so the verifier accepts a fourth yes / no question about the hidden content.
  * D45(2) fixes one list, and every document of the round says that list has three entries.
* **Fix:**
  * Remove the card policy from the production list: make it `#[cfg(test)]`, or keep it registered for no Shieldstral
    run profile through a per-profile policy list.
  * Correct its doc comment.
  * Add a test that each R13 Shieldstral profile admits exactly the three registered category ids.
* Victor's strict / moderate ruling then replaces those three, as planned.

**N-r16-1 (low, test gap).**

* The lane's bits test pins the per-block numerator and only `floor ≥ 95`.
* The `bits-l` mutant, which charges one block instead of L, gives a too-optimistic floor (98 at T128) and passes
  every lane test.
* Fix: pin the floors (96 / 95) and `total_log2` to ±0.01 per profile, as my S2 does.

**N-r16-2 (info, API).**

* `load_bound_tables_pre` accepts any `Option<&TiedDerivation>`, a `pub(crate)` struct with public fields.
* Round 14's "only the re-derivation constructs `BoundClassifierTables`" now also rests on `TiedDerivation` having
  one production literal (`trained_block.rs:649`). That holds today, and the crate exports no path to it.
* Suggest: private fields with a constructor used only by `tied_of_with_derivation`, and extending the r14 structural
  test to `TiedDerivation` literals.

**N-r16-3 (info, liveness, and a merge note for the native lane).**

* If the load's with-row pass is refused (for example, a margin quantization overflow), the load streams again
  without the row. The classifier's own recompute then streams a third time and refuses by name. That is fail-closed,
  but costs three streams on that path.
* The token tree's `trained_block.rs` now derives the row for any tied export that names
  `classifier_margin_parameters`. Native R13 does not, so Sol's next native round must carry this edit or the token
  lane must re-port it.

**N-r16-4 (info).**

* CS-6 in the verifier's pre-header pass is defence in depth. Without it a foreign block is still refused at
  `classify_run.rs:283`, only later, after stage IN-C has been checked. The `prehdr-cs6` mutant survives, as it
  should.

**N-r16-5 (info, for the model approver).**

* T256 is registered but not proved. No statement identity has been published for the T256 export (`1d500782…`).
* Its margin is 0.91 bit. Anything that adds lookups or openings at T256, such as S4 split-width or DD, must be
  recounted before registration (S4 condition (d)).

**N-r16-6 (info).** No DD classifier profiles are registered, the CLI has no DD switch, and the blocks-only refusal
covers only the R13 classifier profiles. The lane records all three.

**N-r16-7 (documents).** Tied to F-1, three texts say "one fixed list … three", which the build does not enforce:
`frozen-r16.FROZEN.txt` ("policies … this list is the moderate one"), DESIGN §17.4, and the README's round-16
bullets and app recipe.

## 10. What the privacy gate must capture for the real classifier

No R13-stack classifier capture exists yet. The lane's P-18 bundle `classify-rc3-cli-p18-r16` is the legacy rung's.
For a Shieldstral classifier privacy statement, the gate needs:

1. **R13 block stages in the classifier run.**
   * Captures at the R13 h24 rung through `RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST`, at two different G and at
     verdict 0 / 1 / tie, with derived tables. The census helper uses synthetic tables, which the replay refuses.
   * One CLI-path capture at the real Shieldstral T128 profile (one prove, about 8.2 GiB, plus one checkpoint
     stream).
   * Native N-r13-9's recount applies: the ACT3 table inversions are now 4096·G rows, and the D30 / D34 terms change.
2. **Gate denominators are public model constants.**
   * They appear in the trained identity, the block digests and the stage lines ("R13 gate denominator G").
   * The allow-list gains that stage-line text. Confirm that it is a function of the export only, not of the content.
3. **Source pins move.**
   * `OWN_SOURCE_FILES` now has 38 entries, with R13's 32 in front (N-r13-6).
   * The classifier pins `classify.rs`, `classify_run.rs` and `classify_tied.rs` all changed.
   * `trained_block.rs` and `tied_tables/derive.rs` in a token bundle have token-tree hashes, not native R13's. Do not
     compare them across token and native bundles (as N-r13-12).
4. **Short items at Shieldstral.**
   * The real item is short: 35 ids, with 20 / 20 / 14 trailing pads under the three templates.
   * C-13 (REVIEW_R14 §10) applies at pad id 11 and P0 72 / 72 / 78.
   * Count pad-row refusals (N-r14-6): none were seen on this item, but they depend on the content.
5. **The refusal-distance figure.** D40's 2^-112.7 must be recounted at the R13 Shieldstral shape: R13's extra
   lookups, plus the pad rows.
6. **The policy list.**
   * Capture under each registered category policy, and confirm the card policy is gone (F-1).
   * Per D45(2), the statement must name the exact list and its count.
7. **Prover-private files.**
   * The `--seq-dir` activations and `input.dec` never appear in a bundle or an export.
   * Check that no published artifact carries `seq_*` or `x_in_L*` / `x_out_L*`.

**Not a privacy acceptance.**

## Evidence

Everything is under `results/zk60_token_io_review_r1_20261017/` unless a path says otherwise.

* **Ledger:** `PROGRESS_R16.md`.
* **Tree and rebase:** `r16/tree_check_r16.py` with `tree_check_r16.json` (after my runs) and
  `tree_check_r16.before.json` (with the scratch); `r16/rebase_check_r16.py` / `.json`; the diffs in `r16/diffs/`.
* **Bits:** `r16/bits_r16.py` / `bits_r16.json` (it reads `r16/logs/rvtk16-tests.log`).
* **Runs:** `r16/run_rv16.sh`; `r16/logs/rvtk16-{build,tests,mut-bits-l,mut-prehdr-cs6,verify-hate}.{log,guard.json,done}`,
  `queue.out`, `test-binary.sha256` (`hashline-ebd2a2ba…`), `verify-binary.sha256`.
* **Mutants:** `r16/mutation_table_r16.json`.
* **My code:** `r16/review_scratch_vs_frozen_r16.diff`; the scratch `ops/zkp-mvp/token-io-review-r16-scratch/`.
