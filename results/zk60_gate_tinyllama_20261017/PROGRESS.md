# PRIVACY GATE lane — the joint-view / run gate at the trained TinyLlama T32 profile (2026-10-17 UTC)

Scope: produce, at the trained TinyLlama-1.1B T=32 profile (calibration
export `pg_rot1_export_T32`), the same privacy evidence the 125M development
shape has (all-zero reference proves; per-commitment linear view; blinding
reproduction; joint assignment; hash layer; tamper controls), so the security
owner can decide. **Nothing here is a privacy acceptance and no statement here
establishes a privacy property.** D22 covers only the toy.

Ownership: `ops/zkp-mvp/trained-1b-gate/` (native copy, additive test-scoped
capture code only), `ops/zkp-mvp/gate-tinyllama/` (adapted gate tools), this
directory (evidence), `/home/victor/zk60-artifacts/tinyllama-trained-capture-*`
(bundles, outside the repo). No git. Every build/test/proof/heavy pass through
`scripts/zk60_resource_guard.py`, one guarded job of this lane at a time.

## Log

- 10:11 UTC: lane opened; read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md, readiness
  §3 runbook, MVP_STATUS privacy table, decisions D12..D24, the gate's round 9m.
- 10:12 UTC: `ops/zkp-mvp/trained-1b-gate/` = rsync of
  `ops/zkp-mvp/trained-1b-review-r2/` excluding `target/` (the r2 copy checked
  first against `trained-1b-review-r2.sha256`: all 193 OK).
- 10:13-10:18 UTC: capture support written (ADDITIVE, TEST-SCOPED; no
  prover/verifier relation touched). `run_capture.rs` (a `cfg(test)` module):
  (1) for a TRAINED-calibration shape only, `run.json["shape"]` gains
  `trained_calibration`, `norm_tn`, `norm_cn_a`, `norm_cn_m`, `norm_ceps`,
  `sh_ao`, `sh_qkv`, `sh_s`, `sh_o`, `sh_g`, `sh_h`, `sh_z`, `d_max` (all
  public, all bound into the schedule/parameter lines and the trained-model
  statement); every other shape writes the identical bytes (the string is
  empty there); the 13 keys are added to `ALLOWED_KEYS`; (2) the README's
  "weights are synthetic" sentence is replaced by a trained-export sentence
  for the two trained run profiles only. `run_capture_tests.rs`: new ignored
  test `capture_a_tinyllama_trained_run` (+ `TrainedChain`, a per-layer
  `RunWitnessSource`, `prove_and_capture_trained`), which builds the run
  through the production constructors the stack CLI uses
  (`TrainedExport::{load,run_constants,shape_for,load_layer,
  statement_of_records,load_seq}`, `IoSpec::new_shaped`, `prepare_endpoints`,
  `RunStatement::new_bound`, `run::prove_run`), checks parity bit-exact against
  the export's `x_out` at every layer (dense), VERIFIES with the production
  `run::verify_run` with the recorder attached, writes only after acceptance,
  and re-checks the bundle on disk (`check_bundle_on_disk`). Default window:
  layers 7..9 of `pg_rot1_export_T32` (both per-block table keys change at the
  7|8 boundary: exp e_s 1->2, SiLU (-1,-10)->(-4,-13)), sequence ho00.
  Patch: `trained-1b-gate-vs-review-r2.patch` (2 files; sha256 64eacf22...);
  sources: `trained-1b-gate.sources.sha256` (214 files; sha256 1a52c5c8...).
- 10:18-10:21 UTC: guarded release build of the lib test binary
  (`build-rel.*`, class build need 3 / cap 5 GiB): exit 0, 3 m 09 s. Binary
  sha256 4480f5a1... (copy outside the repo:
  `/home/victor/zk60-artifacts/tinyllama-gate-bins/`).
- 10:1x-10:3x UTC (while building): read the gate (41 modules, 26.5 k lines,
  copied untouched to `ops/zkp-mvp/gate-tinyllama/original/` with
  SHA256SUMS, working copies in `.../scripts/`) and diffed every source file a
  bundle pins between the 125M-gated tree (`/home/victor/wt-zk60-block125m`
  working files = the `17830dc` digests the gate read in round 9m) and the
  trained copy. FINDING G-1 (lineage, reported, not a privacy figure): the
  trained tree descends from the integrator's `candidate`, which branched
  BEFORE the 125M lane's stages 36-45: it does NOT carry rulings CS-1, CS-3,
  CS-4, CS-6, CS-7, CS-8, CS-9 (run/block statement-fits-shape refusals, the
  prover's lookup-miss refusal before the A commitment, statement-names-the-
  blocks check, run-profile registry, sealed fields), nor S38-F1(a)'s
  `act[128] == 0` refusal at a shape whose Dom::F pads, nor stage 45's
  standalone-block capture writer or stage 36's draw observer. All are
  refusals or test hooks; none moves an absorb or a draw (to be confirmed by
  the replay). New files on the commit path that NO bundle pins:
  `zkp-core/src/pcs/encode_buffer.rs` (a re-implementation of
  `encode_row_zk`, read: same arithmetic) and `zkp-core/src/sumcheck/
  {rounds,grouped}.rs` (prover-side round evaluators; published rounds are
  still the CFS masker's).
- 10:22-10:23 UTC **DENSE CAPTURE DONE** (`capture-dense.*`, guarded cpu need
  3 / cap 5 GiB): layers 7..9, ho00, parity BIT-EXACT at both layers (131,072
  words), the bound run proved and VERIFIED with the recorder attached;
  bundle `/home/victor/zk60-artifacts/tinyllama-trained-capture-dense-l2`,
  42,002,498 B (run.json 35,043 B, stages 3.60 / 4.31 MB, arrays.bin 34.05 MB
  over 1,157 distinct arrays), segments 23,019,088 B (pinned by digest, not
  written). Guard: child wall 47.4 s, peak RSS 0.98 GiB.
- 10:2x UTC: FAILING-FIRST probe with the UNEDITED gate tools
  (`probe_before_port/`, load + replay, 1.8 s, 133 MB): the replay
  RE-DERIVED EVERY CHALLENGE of the trained run (251 positions, 9,002
  challenges, run binding reproduced, 4 position tags) -- the transcript
  structure is the one the gate transcribes; the pins refused by name:
  run.rs 296aeaaf, run_capture.rs c69e5776 (run layer); zk.rs 66d11286,
  zkp-core pcs.rs 5c9cfc4e, backend.rs ff2cb5c1, sumcheck.rs fc7374bb,
  src/pcs.rs 8b14096b (shared); argument.rs 9b26bda8 (no definition),
  layout.rs bfd3677b, protocol.rs efb3dff1, plane_index.rs 13a7dd6f, shape.rs
  a53e2fe2, pad.rs 4f0c11c5 (terminals); argument/layout/shape (mask).
- 10:3x-10:5x UTC: every refused file READ (diffs against the nearest digest
  the gate already read; the candidate's bytes are READ digests for 9 of the
  pinned files) and re-pinned with its reading in ONE new module,
  `gate-tinyllama/scripts/zk60_native_rg_tinyllama_pins.py`, merged at each
  table's definition site (runpins, terminals, gqa, mask; one marked block
  each; an existing digest can never be replaced -- the merge refuses).
  After the re-pin all five pin checks are ok on the dense bundle.
  READINGS THAT CHANGE A TRANSCRIPTION: layout.rs (the windowed top-limb
  coefficients `2^(8-sh)` / `2^(16-sh)` per shape) and argument.rs (SC_TZC
  Ceps; SC_DZC 2Cn_a / 2Cn_m / 2^tn / 2^(tn+1) / 2^sh_ao / 2^sh_z with
  half(sh); SC_FZC sh_h / sh_g; SC_QZC/KVZC sh_qkv / sh_o; SC_SZC sh_s) --
  ported next, reading the constants from `run.json["shape"]`.
- 10:2x-10:3x UTC **ZERO CAPTURE DONE** (`capture-zero.*`, waited ~10 min for
  the heavy lock behind another lane's suite): the ALL-ZERO hidden plane on
  the same trained blocks 7..9 PROVES AND VERIFIES; bundle
  `/home/victor/zk60-artifacts/tinyllama-trained-capture-zero-l2`, 42,066,863
  B; guard child wall 50.4 s, peak RSS 1.01 GiB.
- (timestamp correction: the re-pin entry above ran 10:30-10:41 UTC, not
  "10:3x-10:5x"; the zero capture finished 10:3x as written.)
- 10:41 UTC **PREDICTION, computed half** (`predict.sh` -> `l2/prediction_
  tinyllama_l2_{dense,zero}.json`, guarded light, 7 s, 0.29 GiB): VALIDATED
  OK x4 on the joint-view lane's committed rung-K4 / rung-P2 / rung-E32 /
  rung-K8 records (my D24 edit to `zk60_native_rg_predict` moves no frozen
  prediction). Pad rule CHECKED from the capture: TinyLlama pads exactly
  {F, L, Tab}; {D, Ht, Kv, Q, S, T} are exact; every derived per-slot draw
  count equals the capture's. D24 window: D_max 1,482,910 = declared, window
  32 = declared, C-6 on (17 D-helpers, slot 14 at 54 terminals).
- 10:45 UTC **PREDICTION, hand half** (`l2/prediction_tinyllama_l2_by_hand.
  json`), written before any stage past load ran on the ported tools. It says
  honestly that the failing-first probe had already SEEN the integrity and
  replay figures.
- 10:42-10:44 UTC: first pass A (dense) raised in the terminal stage on a port
  bug (`TerminalGate` lacked `cal`; fixed, the attempt kept in
  `l2/attempts/`); re-run 10:44: **pass A dense OK in 27.4 s, peak 188 MB**.
- 10:47-10:52 UTC: driver labels made shape-generic (records named "125M");
  the port's modules added to `TOOLS`; control CT-5 generalised (it flipped
  an entry of supp(Dom::S), which does not exist at TinyLlama because S does
  not pad: now the first padded domain in a fixed list, still S/slot 17 at
  every earlier shape).
- 10:55 UTC: dated correction to the TL-1 prediction written BEFORE the
  control ran (`l2/prediction_correction_TL1.json`: sh_s, sh_o, sh_h coincide
  with the frozen values, so slot 17 must still hold under TL-1).
- 10:56 UTC **TL CONTROLS (the port's own, new module
  `zk60_native_rg_tlcontrols.py`) on the dense bundle: 15 of 15 fire,
  every failing set EXACTLY the predicted one**: TL-1 frozen constants ->
  slots {2, 14, 15, 16, 18} fail, 17 holds; TL-2 each of the 11 trained
  constants moved one step in class -> exactly its reading slot(s) fail
  (Ceps {2}; tn, Cn_a, Cn_m, sh_ao, sh_z {14}; sh_qkv {15, 16}; sh_o {15};
  sh_s {17}; sh_g, sh_h {18}); TL-3 three malformed calibration declarations
  refused. So the terminal identity at the trained constants is not vacuous.
- 10:5x UTC: counting script `run_hash_counts.py` copied to
  `gate-tinyllama/counts/` (original sha256 recorded) with the TinyLlama
  shape added (row/site/round figures read from the capture; per-profile
  shifts in the parameter line). Every old figure reproduced byte-identical;
  TL-C1 its run parameter line == the bundle's character for character;
  TL-C2 squeeze-counter model 9,578 == measured; TL-C3 sum L_s 979. COUNTED
  residuals: L=2 sampler bias 2^-73.8, input-dependent refusal 2^-117.4,
  liveness 2^-61.2; L=22 (the stack) sampler 2^-70.4, refusal 2^-114.0,
  liveness 2^-57.9 (125M L=12: 2^-69.3 / 2^-114.8 / 2^-58.8).
  Output: `run_hash_counts_tinyllama.json`.
- 10:46-11:02 UTC: EXPLORATORY "everything" pass on the dense bundle with
  the pre-freeze tools (`l2/attempts/tl-dense-everything-probe.*`, guarded
  light, 939.7 s, peak 615 MB): every stage ran but the terminal controls,
  which raised in CT-5 (supp(Dom::S) is None at TinyLlama: S does not pad)
  -- the generalisation above was written from this. Full preimage 2,246,389
  view entries / 0 differing / 1,792 salted leaves (844 s incl. its
  controls); mask/CFS 32,310 entries / 0 differing / 512 leaves; joint,
  run controls, hash-rule controls and round-9 controls ok. NOT a record of
  record (tools not frozen).
- 11:0x UTC: port unit tests `gate-tinyllama/tests/test_tinyllama_port.py`
  (10 tests, OK): frozen calibration = the literals; `lookups_at` of the port
  == the original's at rung-K4 and 125M; at the trained shape exactly six
  top-limb pins move (RAL 2->32, RDL 4->8, RGL 2->1, RQL/RKL/RVL 2->1); every
  TinyLlama digest has a reading; the merge never replaces a reading; every
  original pin survives the merge. `equivalence.py` written: original tools
  vs ported tools on a FROZEN development bundle, leaf for leaf.
- 11:03:55 UTC **TOOLS FROZEN**: `gate-tinyllama.tools.frozen.sha256` (45
  files: scripts, tests, counts); originals == the joint-view worktree's
  scripts byte for byte (`gate-original.sha256`); the whole port as a patch:
  `gate-tinyllama-vs-original.patch` (sha256 68fb574b...; 8 edited modules,
  2 new). Edited: terminals (+Calibration, constants read per bundle, record
  of per-stage recovered exp/act tables), predict (D24 window), runpins /
  terminals / gqa / mask (one merge block each), tcontrols (CT-5), m125
  driver (shape named, calibration recorded), run_gate (TOOLS). New:
  tinyllama_pins (readings), tlcontrols.
- 11:04 UTC: the records-of-record queue launched detached
  (`l2/queue.sh`: equivalence on rung-K4, pass A dense, pass A zero, TL
  controls dense and zero, witness comparison, everything dense, zero arms;
  one guarded light job at a time).
- 11:05 UTC: L = 1 hand prediction written before any L = 1 bundle exists
  (`l1/prediction_tinyllama_l1_by_hand.json`), naming in advance the
  predictor's L = 1 fallback as expected to be wrong.
- 11:04-11:30 UTC **RECORDS OF RECORD, L = 2 (tools v1 frozen)**, all guarded
  light, one at a time (`l2/queue.sh`, progress `l2/queue.progress`):
  * `equivalence/equivalence-k4.json` -- ORIGINAL vs PORTED tools on the
    frozen rung-K4 dense bundle, pass-A stages WITH controls: 5,261 leaves
    compared, 0 differ, 0 missing on either side, beyond three explained
    classes (stage wall clocks; the port's one extra argument.rs definition
    in the listing; CT-5's description naming its slot). Both exit 1 (the
    same skipped CT-4). 59 s, 0.28 GiB. THE PORT MOVES NO FROZEN FIGURE.
  * `l2/tl-dense-a.json` (26.9 s, 0.19 GiB) and `l2/tl-zero-a.json` (27.2 s,
    0.18 GiB): every pass-A figure = the prediction (summary below).
  * `l2/tl-controls-{dense,zero}.json`: 15 of 15 each, exactly as predicted.
  * `l2/witness_comparison_tl_dense_vs_zero.json`: 128 figures, 114
    identical, the 14 that differ are exactly P13's class (distinct opened
    columns, pad margins, the H-pad cross-check on B0).
  * `l2/tl-dense-everything.json` (1,093.8 s, 0.70 GiB): exit 1, decomposed
    in `l2/tl-dense-everything_exit1_decomposition.json` -- CT-4 and CH-6
    skipped by name (no old / legacy bundle) and M9-3's draw-count wording
    criterion, the SAME three items as the 125M everything records; every
    family fires; channels 10 / 5 / 5 / 8 = 125M's.
  * `l2/tl-zero-arms.json` (305.6 s, 0.58 GiB): exit 1 only because the
    mask stage's controls were not requested (125M's zero-arms record has
    the same state) and the joint stage inherits that flag; full preimage
    2,255,011 view entries / 0 differing; mask 32,310 / 0; joint 2,287,321
    / 0, all four couplings respected.
  * cross-check outside the gate: the act/exp tables the terminal port
    RECOVERS from each stage's public table equal the export's layer-7 and
    layer-8 `act.bin` / `exp.bin` (SHA-256 of the int64 entries), act[128]
    = 0 and exp[0] = 512 in both stages.
- 11:31 UTC: tools v2 = v1 + one predictor fix (a ONE-BLOCK run has no
  boundary; its identified rows are the endpoints', not A's -- named as
  expected-wrong before any L=1 bundle existed). v1 kept byte-exact in
  `gate-tinyllama/frozen_v1/` (checked against the v1 manifest).
  `gate-tinyllama.tools.frozen.v2.sha256`, `gate-tinyllama-vs-original.v2.
  patch`. Test-only Rust change: `TrainedChain` borrows its blocks (no
  1.3 GB clone at L = 22); sources manifest v2 (9b0265cd...), patch v2;
  the first bundles were written from sources v1 (1a52c5c8...), which
  differ only in `run_capture_tests.rs` (no bundle pins it).
- 11:34-11:37 UTC: release test binary rebuilt (guarded build, 2 m 57 s;
  sha256 dc96e8c5...). 11:37 UTC: L = 1 queue launched (`l1/queue.sh`).
- 11:37-11:43 UTC **L = 1 (the standalone block at a trained profile, a
  one-block BOUND run; layer 0, the export's real embedding output on ho00,
  and the all-zero plane)**: captures `tinyllama-trained-capture-{dense,
  zero}-l1` (25.0 MB each; prove+verify+record 25.1 / 25.9 s; guard peak
  0.82 / 0.81 GiB; parity bit-exact, 65,536 words). Predictor: tools v1 says
  identified rows 2,974 (= 2 x A's 1,487) -- WRONG EXACTLY AS NAMED in the
  hand prediction; tools v2 says 32 (`l1/prediction_tinyllama_l1_*`; their
  `ok` is false only because no `--validate` was passed: the v2 branch needs
  one block and no boundary, so it is inert on every validation record).
  Pass A dense / zero (18.2 / 19.4 s, 146 MB): positions 127, challenges
  4,511, final counter 4,831, 5 openings / 1,280 columns / 7,411,712 B,
  terminals 23 of 23, A 0, H 2, endpoints 0, M 0, whole run 104 x 3,587,
  joint 2 = sum 2, identified rows 32 -- all as predicted, EXCEPT one figure
  of mine: I predicted 5 distinct roots and the record says 4 (the
  integrity count is over PCS openings, 3L + 1; M is not among them, as
  L = 2's 7 already showed -- a counting slip in the prediction, not a gate
  figure). TL controls on the L = 1 dense bundle: 15 of 15.
- 11:44 UTC: L = 22 hand prediction and cost projection written before the
  bundle exists (`l22/prediction_tinyllama_l22_by_hand.json`, with the root
  law corrected); `l22/queue.sh` enqueued behind the L = 1 queue (capture
  cpu 4.5 / 6 GiB, predict, pass A cpu 7.5 / 9 GiB, pass M light).
- 11:52-12:04 UTC: L = 1 dense EVERYTHING pass (`l1/tl-l1-dense-everything.
  json`, 750.2 s, 600 MB): full preimage 1,125,324 view entries / 0
  differing, 1,024 salted leaves, P-1..P-6 6 of 6; mask/CFS 16,155 / 0, 256
  leaves, M1..M6 fire; joint 1,141,479 / 0, 1,280 leaves, couplings
  respected; GQ 13 of 13; X 23 fire (the boundary clause X10c has no
  boundary to act on); CT as at L = 2 (CT-4 skipped by name); channels
  10 / 5 / 5 / 8. The RUN-CONTROLS stage RAISED `KeyError: 'B0'` -- the
  run family C1..C6 perturbs an internal boundary and a one-block run has
  none; this was named in the L = 1 prediction. Because the stage raised as
  a whole, the CH and M9 families were NOT run on the L = 1 bundle (they
  fired on both L = 2 bundles of the same profile and hash rule). Not
  repaired (a v3 tool change for a bookkeeping gap), reported.

## Results so far (L = 2 and L = 1; L = 22 below when it lands)

Not a privacy acceptance; no statement here establishes a privacy property.
Same five steps as the 125M table of `MVP_STATUS.md`.

| Step | Two-block run, layers 7-8 (dense = held-out ho00, zero = all-zero) | One-block run, layer 0 (the standalone block at a trained profile) |
|---|---|---|
| 1. All-zero reference proves and verifies | YES: the all-zero plane on the trained blocks proves and verifies with the production run verifier (captured with the recorder attached), L = 2 and L = 1 | YES |
| 2. Per commitment, the linear view discloses nothing | A 0 (x2; 1,729 rows, 120 claims, 36 groups, rank 74), H 2 (x2; exact u* 2 = per-indicator 2 = the public LogUp identity), endpoints 0, boundary B0 0 on its reserved block (rank 6 of 6), M 0 (x2); exclusivity 16 of 16 on all 7; whole run 206 x 7,154, joint 4 = sum of parts 4, k0 0; three-role joint 0 = sum 0; dense = zero | A 0, H 2, endpoints 0, M 0; whole run 104 x 3,587, joint 2 = sum 2 |
| 3. Blinding reproduced from all-zero data | dense 2,246,389 view entries / 0 differing (1,792 salted leaves); zero 2,255,011 / 0; mask/CFS 32,310 / 0 (512 leaves) on each | 1,125,324 / 0; mask 16,155 / 0 |
| 4. One joint assignment | dense 2,278,699 / 0, zero 2,287,321 / 0 (2,304 leaves), four couplings respected, 64 identified pairs all data rows | 1,141,479 / 0 |
| 5. Hash layer and challenges | 9,002 challenges re-derived (251 positions, run binding, 4 tags); 2,304 opened columns (14.78 MB) re-hashed and re-authenticated under independently derived keys; 4 wrong rules never reach a root | 4,511 challenges; 1,280 columns |
| Terminal identity at the trained constants | 46 of 46 (all 23 slots, per-stage exp/SiLU tables recovered and equal to the export's) | 23 of 23 |
| Controls | CT 8 of 9 (CT-4 skipped by name), GQ 13/13, X 24 fire (old check accepts the same 7), P 6/6, M 6/6, C 6/6, CH 6 of 7 (CH-6 skipped by name), M9-1/2/3 fire (M9-3's wording criterion as at 125M), TL 15/15 | CT, GQ, X (23), P, M, TL fire; run controls RAISE (no boundary), so C/CH/M9 not run at L = 1 |
| Channels | 28 = 10 constructed / 5 derived / 5 argued / 8 open (125M's) | the same |
- 12:00-12:17 UTC: L = 2 ZERO everything pass (`l2/tl-zero-everything.json`,
  1,021.4 s, 586 MB): exit 1 for the same three explained items as the dense
  one (CT-4, CH-6 skipped by name; M9-3's wording criterion); full preimage
  2,255,011 / 0, P 6/6; mask 32,310 / 0, M 6/6; joint 2,287,321 / 0; X 24
  (old check: the same seven), GQ 13/13, C 6/6, CH 6 of 7, M9 fire;
  channels 10 / 5 / 5 / 8. Every control family has now fired on BOTH the
  dense and the all-zero two-block bundles.
- 12:20-12:30 UTC **22-BLOCK CAPTURE DONE** (`l22/capture-l22-dense.*`,
  guarded cpu 4.5 / 6 GiB, waited 150 s for the heavy lock): all 22 trained
  blocks of pg_rot1 on ho00 as ONE bound run, parity BIT-EXACT at every
  layer (1,441,792 words), proved and VERIFIED with the recorder attached;
  segments 250,855,088 B (= the native lane's 22-block stack receipt to the
  byte); bundle `/home/victor/zk60-artifacts/tinyllama-trained-capture-dense-
  l22`, 370,823,399 B (arrays.bin 290.7 MB over 12,622 distinct arrays; 22
  stage files of 3.6 MB, the last 4.3 MB). Guard: 580.4 s, peak RSS 2.33 GiB
  (cgroup 2.87), against a projection of ~10 min / ~3.5 GiB.
- 12:30 UTC: computed half of the L = 22 prediction (`l22/prediction_
  tinyllama_l22_dense.json`) equals the hand prediction written at 11:44 on
  every figure both name: 2,731 positions, 98,822 challenges, 44 tags; 89
  openings / 22,784 columns / 162,197,504 B; 506 slot checks; 2,246
  generators, 704 identified rows, joint 44 = sum 44; pad rule and D24 window
  equal to the capture's. (`ok` false: no `--validate` passed.)
- 12:30 UTC: pass A (cpu, declared 7.5 / 9 GiB from the projection) is QUEUED
  behind the native lane's heavy job and the 8B calibration lane's 4.5 GiB
  light job (budget 11.89 GiB); my attempt to re-queue it with a smaller
  declaration was refused by the session's permission classifier (no kill of
  a guard), so it waits on admission as the guard intends.
- 12:35-12:44 UTC **22-BLOCK PASS A** (`l22/tl-l22-dense-a.json`, guarded cpu
  7.5 / 9 GiB, admitted after 332 s; 502 s, peak RSS 5.53 GiB, cgroup 5.6;
  projected 10-15 min / ~6.5 GB): EVERY FIGURE AS PREDICTED but one of my
  own: integrity ok, 0 findings, 67 PCS roots none twice, pins ok, but 25
  manifest files where I wrote 5 (copied from L = 2: 22 stage files +
  run.json + arrays.bin + README -- a prediction slip, recorded); replay
  2,731 positions / 98,822 challenges / final counter 104,518 / 44 tags /
  binding reproduced; hash layer 89 openings, 22,784 of 22,784 columns,
  162,197,504 B; terminal identity 506 of 506 at the trained constants, 484
  public tables digest-checked, 330 structure checks; per commitment 22 A at
  0 (16/16 exclusivity each), 22 H at 2, 21 boundaries at 0 with reserved
  rank 6 of 6, both endpoints 0, 22 M at 0, k0 0 everywhere; three-role 0 =
  0 at all 21 boundaries; 21 adjacent pairs each joint 4 = sum 4 (19 at
  198 x 7,144, the two end pairs 202 x 7,149); WHOLE RUN 2,246 x 78,494,
  704 identified rows, joint 44 = sum of parts 44, exact u* 44 = per
  indicator; singleton preimage 23 of 23 (21 boundaries 0 free, endpoints
  1 free Fp per position). The recovered exp / SiLU tables of all 22 stages
  equal the export's layer tables (7 distinct SiLU members, 2 distinct exp
  tables; act[128] = 0, exp[0] = 512 in every stage).
- 12:44-12:47 UTC **22-BLOCK PASS M** (`l22/tl-l22-dense-m.json`, light,
  214 s, 0.89 GiB): mask/CFS at all 22 stages, 355,410 entries recomputed /
  0 differing, 5,632 salted leaves, M1..M6 fire. No job of this lane is
  running after 12:47.

## Results (final)

Not a privacy acceptance; no statement here establishes a privacy property.

| Step | L = 2, layers 7-8 (dense ho00 / all-zero) | L = 1, layer 0 (dense / zero) | L = 22, the whole stack (dense ho00) |
|---|---|---|---|
| 1. All-zero reference proves and verifies | yes (captured verify) | yes | not run (dense only) |
| 2. Linear view per commitment | A 0, H 2 (= LogUp identity), endpoints 0, B0 0 (rank 6/6), M 0; exclusivity 16/16; whole run 206 x 7,154, joint 4 = sum 4, k0 0 | A 0, H 2, E 0, M 0; 104 x 3,587, joint 2 = 2 | 22 A 0, 22 H 2, 21 B 0 (6/6), 2 E 0, 22 M 0; 2,246 x 78,494, joint 44 = 44, u* 44; 21 three-role 0 = 0; 21 pairs 4 = 4 |
| 3. Blinding reproduced (all-zero data) | 2,246,389 / 2,255,011 entries, 0 differing; mask 32,310 / 0 each | 1,125,324 / 0; mask 16,155 / 0 (dense) | mask 355,410 / 0 (PCS full preimage NOT run: ~1 h) |
| 4. Joint assignment | 2,278,699 / 2,287,321, 0 differing, couplings respected | 1,141,479 / 0 (dense) | not run |
| 5. Hash layer + challenges | 9,002 challenges; 2,304 columns re-hashed and re-authenticated | 4,511; 1,280 | 98,822; 22,784 columns (162.2 MB) |
| Terminal identity, trained constants | 46/46 | 23/23 | 506/506 |
| Controls | every family fires on BOTH bundles except by-name skips (CT-4, CH-6) and M9-3's wording criterion, as at 125M; TL 15/15 | CT/GQ/X/P/M/TL fire (dense); run-control stage raises (no boundary) | M1..M6 (pass M); pass-A runs no controls |

Costs (guard records, shared box, CPU): captures L=1 25 s / 0.82 GiB,
L=2 47-50 s / 1.0 GiB, L=22 580 s / 2.33 GiB; gate pass A L=1 18 s /
0.15 GB, L=2 27 s / 0.19 GB, L=22 502 s / 5.53 GiB; everything L=1 750 s
/ 0.60 GB, L=2 1,022-1,094 s / 0.6-0.7 GB; pass M L=22 214 s / 0.89 GiB;
TL controls ~41 s / 0.16 GiB; prediction 7 s; equivalence 59 s. The
runbook's "[UNCHECKED] At T32 expect minutes and under 2 GB" is CHECKED for
L <= 2 (everything in 18 min under 0.7 GB); the 22-block whole-run joint
system needs 5.5 GiB.

Prediction misses (all mine, all recorded before/at the run): TL-1's slot 17
(corrected in writing before the control ran); L = 1 distinct roots 5 vs 4;
L = 22 manifest files 5 vs 25. The predictor's v1 one-block fallback was
wrong exactly as named in advance (2,974 vs 32).

## Findings and what remains (for the security owner)

- G-1 lineage: the trained tree lacks the 125M lane's rulings CS-1, CS-3,
  CS-4, CS-6, CS-7, CS-8, CS-9 and S38-F1(a) (all refusals; CS-3 sits on the
  refusal channel D20 sizes, CS-6 on soundness). No absorb, draw or published
  byte depends on them (replay with unedited tools); decide whether to port
  them into the trained tree before any acceptance.
- G-2 unpinned prover-path files: `zkp-core/src/pcs/encode_buffer.rs`
  (read: `encode_row_zk`'s arithmetic), `zkp-core/src/sumcheck/rounds.rs`,
  `grouped.rs` (prover round evaluators). Writer-side ask: add them to
  `run_capture.rs::SHARED_SOURCE_FILES`.
- G-3 the gate's channel text "retained captures ... a deliberately public
  synthetic fixture" is a stale literal for these bundles (real held-out
  activations, which the calibration export itself stores in
  `seq_ho00/x_in_L*.bin`); my writer's README states it correctly.
- G-4 M9-3's own ok-criterion is false here as at 125M (wording); new here:
  faking D or S padded also stops slots 00/01 or 04 (their indicators).
- G-5 a one-block run's run-control stage raises (C1/C2 need a boundary), so
  CH and M9 were not run at L = 1.
- CPU path only: the trained tree offers tagged column hashing to a keyed
  device hook (`try_commit_zk_keyed`); GPU-built receipts are not what these
  bundles read.
- Remaining before an acceptance could be considered: the three paper steps
  (rank lemma, joint law Theorem B with G-R1/G-R2/G-R4, hash-layer/FS lift)
  re-read at this layout; the 22-block full-preimage arm and controls (~1 h,
  not run) and a 22-block all-zero capture; G-1 and G-2 decided; D23
  (endpoint roots never referred to later) ruled by Victor; an independent
  adversarial check of this port's readings and constant transcription.
  Sized terms COUNTED (`run_hash_counts_tinyllama.json`): L = 22 sampler
  2^-70.4, input-dependent refusal 2^-114.0, liveness 2^-57.9 per run.

## Round 2 (coordinator, 12:48 UTC): the draft statement, then the L = 22 arms

- 12:49 UTC: priority rule acknowledged: no heavy (cpu/build) job of this lane
  while any r4-* guard is running or queued (the native lane's 8B stack).
- 12:49-12:55 UTC **P2-1**: read the toy statement (D22), the rulings page,
  the shaped privacy-path status inventory, the dispositions of the shaped
  rank lemma, the run joint law, the run hash layer / lift, G-R4 and its toy
  reading, the GS-4/5/11/12 closures and the non-linear channel; checked
  in the trained tree that the CUDA backend implements the keyed commit hook
  (`hashline/src/gpu/mod.rs:691`: ruling T-8 no longer holds here, G-6) and
  that the stack CLI seals first, writes `statement/` only after verifying,
  and does not remove a failed directory. Sized terms at L = 1 / 2 / 22
  computed with the copied counting script. DRAFT written:
  `PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md` (not an acceptance). New
  findings beyond G-1..G-5: G-6 (T-8 gone: tagged commitments go to the GPU
  under gpu-cuda + HL_GPU), G-7 (sh = 8 / 16 makes the scaled top-limb
  lookup a duplicate of the byte lookup: four duplicate H helper planes at
  pg_rot1; NL-1's check and the terminal surjection not re-run at a trained
  export), G-8 (GS-12 is non-vacuous here because Dom::F pads; its closure's
  S38-F1(a) and CS-3 are absent; act[128] = 0 measured at all 22 layers).
- 12:52-12:55 UTC: tools v3 = v2 + G-3 (the "retained captures" channel
  sentence for trained bundles) + G-5 (`zk60_native_rg_controls`: a run with
  no boundary reports C1..C4 NOT APPLICABLE by name and runs C5 on stage 0
  and C6); both branches inert at frozen bundles. Frozen:
  `gate-tinyllama.tools.frozen.v3.sha256`, `gate-tinyllama-vs-original.v3.
  patch`; unit tests OK. Predictions first: `p2/prediction_p2_light.json`,
  `l22/prediction_tinyllama_l22_arms_by_hand.json`.
- 12:55 UTC: light queue (`p2/light_queue.sh`: v3 equivalence on rung-K4,
  the run-control families on the L = 1 dense bundle). 12:56 UTC: heavy
  queue (`l22/heavy_queue.sh`) enqueued: it waits for the light queue, then
  before EVERY heavy step for no r4-* guard running or queued (checked twice,
  30 s apart): 22-block all-zero capture, its prediction, the zero arms pass,
  the dense arms pass.
- 12:56-13:00 UTC: light queue done. `p2/equivalence-k4-v3.json`: v3 against
  the originals on rung-K4, 5,261 leaves, 0 unexplained differences.
  `p2/tl-l1-dense-runcontrols.json` (the first record attempt omitted the
  preimage stage the channel table needs; it is kept in `p2/attempts/`):
  - G-5 RUN: C1..C4 NOT APPLICABLE by name; C6 fires.
  - **C5 fires on the replay (4,770 failures) but not on integrity.** The
    run integrity pass does not compare a stage's external-endpoint
    opening roots with run.json's; the block reader does. This is finding
    **G-10**, not repaired: the heavy queue had already verified the v3
    tool bytes.
  - CH-1..5 and CH-7 fire; CH-6 is skipped by name.
  - M9-1 and M9-2 fire; M9-3 fires on D, Kv, Q, S and T, with its wording
    criterion false (G-4), as predicted.
  - G-3: the trained-bundle channel sentence is in place.
