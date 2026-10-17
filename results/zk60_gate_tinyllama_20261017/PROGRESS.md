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
