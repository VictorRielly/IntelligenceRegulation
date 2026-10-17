# Lane B progress: TinyLlama-1.1B full-block integer calibration

Owner: lane B subagent (Claude). Writes only under this directory. No native
edits, no git operations. Times are UTC (`date -u`).

Scope: design and implement, in Python/numpy, a per-layer FULL-BLOCK integer
calibration and bit-exact integer reference forward for the pinned trained
checkpoint `TinyLlama/TinyLlama-1.1B-Chat-v1.0` rev `fe8a4ea1`, validate it
against a float32 reference on held-out token sequences, and document where
the native kernel's fixed toy constants would have to change. Not a proof,
not a privacy claim, not proof readiness.

## Log

- 2026-09-30 00:17 UTC: lane opened. Read CLAUDE.md, ZK60_1B_CHECKPOINT.md,
  import README, `hashline/src/private_block.rs` + `witness.rs` + `layout.rs`
  (main tree, toy), the SHAPED block in `~/wt-zk60-block125m/hashline/src/
  private_block/{shape.rs,witness.rs}` and `private_block.rs` (padding and head
  permutation, ruling P-2), and `~/wt-zk60-block125m/private-block-kernel-shaped/
  src/lib.rs` (the shape-generic reference kernel; `private-block-kernel-shaped`
  is not in the main tree). Pinned inputs: importer sha256 7333977…ec23,
  config.json 486bedd…e9, tokenizer.model 9e556af…347; model sha256 pin
  6e6001da… (re-verified by the importer at every run).
- 00:20: `sentencepiece` is not installed and transformers' converter needs
  it; wrote `spm_bpe.py` (stdlib protobuf reader + SentencePiece-BPE merge
  rule, byte fallback). Self-check passes on two known Llama-2 id sequences
  and a UTF-8 round trip.
- 00:40: `tlcalib.py` (float reference, exact integer block with every
  calibration constant a parameter, per-layer solver, native export) and
  `explore.py` written. Float exploration, 9 calibration sequences x T128,
  log `logs/explore_T128.log`. Findings that decide the design:
  * embedding absmax 0.149, rms 0.0149; layer-0 input median |x| 0.005;
  * MASSIVE ACTIVATIONS: layer 2's FFN writes ~140 into channels 624/1661
    (BOS-type tokens), ~186 from layer 7 on, removed by layer 21
    (final absmax 42.8). One int16 residual scale for the whole stack is
    therefore ~0.007 per LSB, while layer 0-2 inputs are below 1.0;
  * gamma_a of layer 0 spans [-0.58, 0.77] with 1,826 of 2,048 entries below
    max/64 (int8 gains would be 0/+-1 without the fold used here); several
    gamma_m have tiny negative entries;
  * raw q.k up to 374 (logit 47) at layer 8, 130-275 elsewhere; gate up to
    30, FFN product up to 182 at the massive-activation layers (2, 7, 21).
- 00:43: naive BPE was O(n^2) per document (5 min); switched to exact
  word-chunked BPE (no vocab piece contains U+2581 after a non-U+2581, checked:
  0 such pieces) with a cache; chunked == whole-string on two 4 kB samples.
- (box froze 2026-09-29 17:40 PDT = 2026-09-30 00:40 UTC; lane B agent died.
  Its smoke run `runs/smoke/` survived; no log of it was retained.)

## Lane B2 (continuation, Claude Opus agent), from 2026-09-30 01:27 UTC

Every python job runs through `scripts/zk60_resource_guard.py` (class
`light`), logs + `.done` + `.guard.json` under `logs/`.

- 01:29 UTC: smoke re-run under the guard as `runs/smoke_b2/`
  (`logs/b2-smoke.{log,done,guard.json}`): exit 0, 14 s, **peak RSS 1.31 GiB**
  (cgroup high-water 3.45 GiB incl. the 2.2 GB model page cache). Numbers
  are identical to the pre-crash `runs/smoke/` (L0 iso cos 0.97335, L1 dcos
  0.8868, L2 dcos 0.8513): the code is deterministic.
- (B2 ended after its two T=32 runs, 2026-09-30 01:37 UTC; its numbers are
  in `logs/b2-t32-{default,perlayer}.log`: held-out top-1 agreement 0.731 on
  279 positions, ppl float 20.56 vs integer 31.88 (global residual) / 25.96
  (per-layer residual rescale), 3/9 and 2/9 held-out sequences refused.
  `oracle.py` was left referring to solver helpers that were never written.)

## Lane B3 (calibration ladder + native exports, Claude Opus agent), from 2026-10-17 01:39 UTC

Scope: K1 fidelity ladder (profile-uniform -> per-layer norm -> per-layer
residual rescale -> free shifts), K2 byte-exact native tables (SiLU registry
member, exp_member, rope), K3 exports in schema `zk60-trained-profile-export/1`.
Writes only here; no git; every python job >few s through the guard (`light`).
Calibration data, not a proof, not a privacy claim.

- 01:39 UTC: read CLAUDE.md, resource protocol, this log, B2 logs,
  `ops/zkp-mvp/trained-calibration-next.txt`, the contract-review HANDOFF,
  native witness.rs / layout.rs / shape.rs, kernel-shaped lib.rs, the SiLU
  registry (zkp-core tables.rs) and tables_attn.rs. Findings that shape B3:
  * B2's tables are NOT native-exact: its exp table uses an arbitrary decay
    (native: lam = 2^e_s / sqrt(64), e_s integer) and its SiLU table arbitrary
    (e_in, e_out) (native: one of 9 frozen registry members). B3 forces
    s_score = 2^e_s, s_gate = 2^e_in, s_act = 2^e_out exactly.
  * With native shifts the residual scale has FLOORS besides the int16 range:
    SH_AO = 7 forces s_x = s_v * s_wo * 2^7 and SH_Z = 6 forces
    s_x = s_h * s_wd * 2^6, so v/Wo and h/Wd cannot both be finer than that.
  * Real scales may differ per channel inside one int8 matrix as long as the
    chain equalities hold per channel: V rows / Wo columns, Q,K pair rows
    (s_q,c * s_k,c = 2^(e_s - SH_S)), Wu rows / Wd columns. B3's solver uses
    this (no native change; the matrices are public data).
  * The int8 norm gain g is per channel and the fold W' = W diag(gamma K/g)
    corrects its rounding exactly, so one Cn per norm type can serve all
    layers (the hint); only g's dynamic range [1,127] is lost.
- 01:55 UTC: `b3calib.py` (native-exact table generators, per-channel stats,
  optional Hadamard rotation, constrained solver) and `b3_ladder.py` (driver:
  pass 1 stats, profile pre-pass, pass 2 exact integer runs, head metrics,
  exports) written. `verify_tables()` reproduces all 9 frozen SiLU registry
  digests of zkp-core `tables.rs`, the exp_member pins (e_s -1 `15903694..`,
  -2 `b4f01aca..`) and both RoPE pins (t16 `355be440..`, t32 `e0de1cf4..`)
  byte for byte; tlcalib's rope tables equal the native generator.
- 02:05 UTC: first probe (variant a, T=32, 27 calibration sequences) exposed
  three binding constraints: (1) layer 0's norm search, minimising Q/K/V noise
  alone, chose a gain shape whose Q/K weight bounds force e_s = 3 (logit
  quantum 1.0) and a profile e_s = 3 for every layer; (2) the SH_Z floor of
  layer 21 (one calibration newline token: up 123, gate -105.6) forced
  s_x = 0.026, 3.7x the int16-range need; (3) one SiLU member for the stack.
- 02:20 UTC: `b3_diag.py` (float only; log `logs/b3-diag.log`,
  `runs/b3_diag_T32.json`): MASSIVE ACTIVATIONS sit on BOS (from layer 2 on,
  ~140) and on the first newline token `<0x0A>` (id 13) of nearly every
  sequence (from layer 7 on, ~186; 51/54 positions in 27 calib/held-out
  sequences); layer 21 removes them. Gates beyond +-16 occur at layers 2, 7
  and 21 in 20-27 of 27 sequences; beyond +-32 only once (layer 21, calib,
  gate -105.6, outside every frozen SiLU member's +-63.5: that sequence must
  refuse). Held-out maxima at layer 21: gate 28.8, up 20.9, h 161.
- 02:25 UTC: solver revised: the norm-gain search now minimises an exact
  objective per consumer group (Q/K at the scales the score chain forces +
  score rounding at 2^e_s + V; gate at its pinned 2^e_in with clipping, up at
  its bound, product rounding); calibration sequences whose gate leaves
  +-63.5 at a layer are excluded from that layer's statistics on (they refuse
  under any registry member; counted); the profile e_s is the one minimising
  the summed attention objective over the layers.
- 02:37 UTC: first full T=32 ladder attempt (54 calibration / 36 held-out
  sequences, margin 1.5) — SUPERSEDED, kept in `logs/b3-ladder-{a,b,a_t}.log`
  / `runs/b3_{a,b,a_t}_T32`: variant a collapsed (top-1 14%, ppl 1350,
  24/36 held-out refused at layer 21 after drift). Diagnosis
  (`b3_layerdiag.py`, per-site error budget now in every run): a solver
  defect — with SH_U = 0, s_u is both the up scale and the Wu weight scale,
  and the h/Wd balance pushed it 90x above its bound (Wu at +-4 levels; up
  error 0.98 at layer 3). Also: per-channel calibration maxima are unreliable
  (held-out/calib up to 2.2x for xhat/q/k/v, 5x up, 86x product; per-tensor
  <= 1.38x), so per-channel bounds are now min(3 x channel max, m x tensor
  max); power-of-two table exponents use margin 1.25, other ranges 1.5.
- 02:55 UTC: objectives rewritten to model whole chains at the actual
  residual scale (attention: Q/K/score + V->O->Wo->ao; FFN: gate->act,
  up->product->down measured on z), shared with the solver. Layer 3 update
  error (b) 0.80 -> 0.59. Inherent at one residual scale s_x = 0.0089 (set by
  the 186 massive activations): attention/FFN outputs of layers 0-6 are 1-2
  LSB rms (rounding alone 14-40%), and o is 1-3 LSB of its int8 scale in every
  variant (SH_O >= F_P ties o's scale to v's heavy-tailed range).
- 02:59 UTC: ROTATION (randomized Hadamard of the residual basis, public
  weights only): 3-layer smoke at s_x 3.1e-4 gives isolated update cos
  0.995/0.987 at layers 0/1 (unrotated 0.74-0.85). Needs shifts that can
  move (AO/Z floors); new rungs dg (per-layer free shifts, one s_x) and pg
  (ONE TinyLlama shift set for all layers, one s_x). Ceps at s_x 3e-4 is
  ~2e5, above the contract review's checked bound (2684).
- 03:05 UTC: ladder round 2 launched (`logs/b3_queue2.sh`, logs
  `logs/b3-L-<variant>.log`): a b c d pg, and d+rot dg+rot pg+rot a_t dg.
- 03:13 UTC: round-2 results so far (T=32, 54 calib / 36 held-out seqs):
  * a (profile-uniform, toy shifts, one s_x 0.0089): held-out top-1 0.136
    (all) / 0.140 (15 accepted), ppl 29.3 -> 1379, 21/36 refused (layers 14
    and 21, after drift). Chain cos falls 0.90 -> 0.25 by layer 10.
  * d+rot (per-layer free shifts + per-layer rescale + Hadamard rotation):
    top-1 0.778 (all) / 0.775 (35 accepted), ppl 29.30 -> 32.84, KL 0.230,
    1/36 refused; chain cos 0.93-0.95 at every layer. Ceps reaches 1.2e9 at
    layer 0 (s_x 4.2e-6) — far outside the reviewed Ceps bound.
- 03:15 UTC: variant-a export run launched (`logs/b3_export.sh a`,
  `--export --export-seqs 2`, export dir `export/a_export_T32`).
- 03:40 UTC: variant-a export VERIFIED by `b3_verify_export.py` (streams one
  layer at a time; first version kept all layers as int64 and hit the 3 GiB
  kernel cap, exit 137): 22 layers, sequences ho00 and ho01 bit-exact at every
  layer, every sha256 / table key / -128 check clean. Another lane's guarded
  job (`t5-verify-a_export_T32-L0`) was already reading it.
- 03:38 UTC: ladder (T=32; all 36 held-out; float ppl 29.30): a 0.136/1379,
  b 0.458/82.9, c 0.454/79.6, d 0.642/40.9, a+rot 0.285/232 (14M Wo words
  clipped: toy SH_AO cannot follow the finer residual), c+rot 0.615/43.0,
  d+rot 0.778/32.8, dg+rot 0.757/31.8. Pending: a_t, b+rot, pg, pg+rot, dg;
  T=128 runs of a and dg+rot queued (`logs/b3_queue128.sh`).
- 03:58 UTC: more rungs: a_t 0.466/82.1 (per-layer tables alone recover
  most of a's loss; gate/act error 0.58 -> 0.19), b 0.458 (per-layer Cn adds
  nothing), pg 0.228 (36/36 refused), pg+rot 0.698/36.5 KL 0.36, 0/36 refused,
  no clipping (ONE shift set {qkv 8, s 6, ao 3, g 8, h 14, z 5}), b+rot
  0.682/40.6 but with 14.1M of 92M Wo words clipped (toy SH_AO = 7).
  ROOT CAUSE of the unrotated collapse (`logs/b3-dbg-bos.log`): the BOS row is
  deterministic, but at one residual scale 0.0089 its layer-2 input is ~23 LSB
  and the float block applied to that dequantized state writes -4.06 into
  channel 624 instead of ~-140: the trigger that CREATES the massive
  activation (attention sink) is quantized away. Exports dg+rot and pg+rot
  queued (`logs/b3_exportq.sh`); a_t+rot queued.

### B3 final state, 2026-10-17 04:20 UTC (all B3 jobs finished; nothing running)

Ladder (`runs/b3_ladder_summary.{txt,json}`; held-out = 36 sequences x T,
disjoint sources; calibration = 54 x T; top-1/ppl over all held-out, refusals
clamped only to continue = diagnostic; float ppl 29.30 at T=32, 7.96 at T=128):

| variant | what is per layer / special | top-1 | ppl int | KL | refused h/c | clipped |
|---|---|---|---|---|---|---|
| a | nothing (toy shifts, 1 Cn/norm, 1 e_s, 1 SiLU, 1 s_x) | 0.136 | 1379 | 4.65 | 21/36, 32/54 | Wo 106 |
| a_t | + tables | 0.466 | 82.1 | 1.47 | 14/36 | Wo 106, Wg 105 |
| b | + Cn | 0.458 | 82.9 | 1.48 | 6/36 | Wo 106, Wg 106 |
| c | + residual rescale k | 0.454 | 79.6 | 1.57 | 17/36 | Wg 173 |
| d | + free shifts | 0.642 | 40.9 | 0.69 | 1/36 | Wg 221 |
| dg | b + free shifts (one s_x) | 0.571 | 45.1 | 0.84 | 12/36 | Wg 318 |
| pg | 1 TinyLlama shift set, tables | 0.228 | 384 | - | 36/36 | Wg 5176 |
| a+rot | a, rotated | 0.285 | 232 | 2.72 | 14/36 | Wo 14.1M |
| a_t+rot | a_t, rotated | 0.651 | 39.9 | 0.56 | 3/36 | Wo 14.1M |
| b+rot | b, rotated | 0.682 | 40.6 | 0.54 | 0/36 | Wo 14.1M |
| c+rot | c, rotated | 0.615 | 43.0 | 0.67 | 6/36 | 0 |
| pg+rot | pg, rotated | 0.698 | 36.5 | 0.36 | 0/36 | 0 |
| dg+rot | dg, rotated | 0.757 | 31.8 | 0.25 | 1/36 | 0 |
| d+rot | d, rotated | 0.778 | 32.8 | 0.23 | 1/36 | 0 |
| a @T128 | | 0.220 | 255 | 3.74 | 36/36 | Wo 170 |
| dg+rot @T128 | | 0.814 | 9.67 | 0.25 | 2/36 | 0 |

Exports (all verified by `b3_verify_export.py`: every sha256, table key and
-128 check, both sequences bit-exact through 22 layers; logs
`logs/b3-verify-{a,dg_rot1,pg_rot1}.log`), 937 MB each:
* `export/a_export_T32` (variant a, required first) profile.json sha256
  2b5ded29d292a9c369aa4d207af2bc7d274ac1c80bd6ea3b1b36cd2b07b09a92;
* `export/pg_rot1_export_T32` (one TinyLlama profile: Cn_a 3999, Cn_m 3122,
  Ceps 91255, shifts qkv 8 s 6 ao 3 g 8 h 14 z 5; per-layer only e_s and SiLU
  member) b25ba5f5e1df5617d9d60b41998eca101dc1e41ae6e70bf2d67da344eb6bffa4;
* `export/dg_rot1_export_T32` (per-layer Cn/shifts/tables, one s_x, k = 0)
  7cafa66ab989fa2559af69146363db2c44ae57843b3d8b6cb7ab8741b601740a.
Rotated exports carry `rotation_sign.bin` + `rotation.json` (sign sha256
db7b32c2..., equal to profile.json's sign_sha256).

Superseded (kept, do not use): `logs/b3-ladder-*.log` (round 1, solver defect)
and the probes' stats caches b3_stats{,2,3}_*.pkl; current cache b3_stats4_*.

Open: o (attention output) is ~30% rel. error in every variant (SH_O >= F_P
ties o's int8 scale to v's heavy-tailed range); 2/54 calibration sequences
have layer-21 gates beyond +-63.5 (no frozen member); Ceps > 2684 in every
rotated variant needs the norm no-wrap re-check; SiLU (-2,-11) at layer 2
saturates act at 16 (BOS gate 17.2); calibration/held-out text is licenses +
stdlib docstrings (no chat data); parity with the native Rust prover is the
native lane's x_in/x_out check (not done here).

## Lane B4 (coordinator round 2), from 2026-10-17 08:10 UTC

Native lane result relayed by the coordinator: all 22 blocks of
`export/a_export_T32` proved one block at a time with bit-exact parity against
these x_in/x_out. It is making shifts per-profile to prove pg_rot1, then the
22-block stack.

- 08:10 UTC: FineWeb-Edu local copy = HF `HuggingFaceFW/fineweb-edu`
  `sample/10BT/000_00000.parquet` (HF metadata: revision 87f09149ef47...,
  sha256 b1ba7b2c...e871; 726,000 documents, row groups of 1,000) plus a
  derived `sample_text.txt`. NO licence file in the directory; the public
  dataset card states ODC-By 1.0 + Common Crawl terms of use (recorded, not
  verified offline). `corpus4.py`: calibration docs from row group 0,
  held-out docs from row group 1 (disjoint documents), [BOS] + first T-1
  tokens, doc id / url recorded.
- 08:12 UTC: B3 tool versions whose sha256 the three B3 exports record are
  frozen in `tool_snapshots/b3_exports_20261017/` (all matched) before any
  B4 edit. Driver: `--corpus b4` (54 FineWeb calib docs + 36 held-out docs
  added; per-domain head metrics/refusals), `--calib-T` (calibrate at one T,
  evaluate/export at another: one weight set for the context ladder),
  chunked + atomic stats cache, `--token-io` (int16 embedding table).
  Library: `o16` experiment flag (B4-3, NOT native). `export/FORMAT_CHANGES.md`
  and `export/TOKEN_IO_SPEC.md` written before any new export.
- 08:17 UTC: launched (logs `logs/b4-<label>.log`): pg_rot1_T128 (+ export +
  token-io), pg_rot1_T32, dg_rot1_T32; dg_rot1_T128 was stopped by SIGTERM to
  its guard (exit 75, logs kept as *.stopped.*) to avoid two processes writing
  the same stats cache; it is relaunched after the cache exists.
- 08:37 UTC: B4-1 at T=32 (calibration 54 licence/docstring + 54 FineWeb-Edu
  seqs; held-out 36 + 36, disjoint documents):
  * pg+rot (profile shifts now qkv 8 s 6 ao 3 g 8 h 14 z 4; Cn 3619/3122;
    s_x 4.87e-4): FineWeb top-1 0.725, ppl 26.05 -> 29.70, KL 0.352, 0/36
    refused; licence/docstring 0.714, ppl 29.30 -> 34.26, KL 0.466, 1/36.
  * dg+rot: FineWeb 0.803, ppl 26.05 -> 27.92, KL 0.194, 0/36; licence 0.766,
    ppl 29.30 -> 31.77, KL 0.266, 2/36.
  (B3's pg+rot on the licence domain, calibrated on licence text only, was
  0.698: the broader calibration did not cost the old domain anything.)
- 08:55 UTC: ACKNOWLEDGED orchestrator scheduling rule: at most ONE guarded
  B4 job at a time, declared need <= 3.5 GiB (four concurrent light jobs had
  held 11.5 of 11.89 GiB and starved the native stack build and the D24
  reviewer's build). The two queued jobs (dg_rot1_T128, pg_rot1_T64_cal128)
  were cancelled while waiting (SIGTERM to their guards, exit 70, records
  `logs/b4-*.cancelled.*`); the four running ones finish untouched.
  Remaining work runs through `logs/b4_serial.sh` (next step only after the
  previous `.done`). Also acknowledged: `export/pg_rot1_export_T32` (profile
  sha256 b25ba5f5...) and `export/a_export_T32` are NOT modified; every B4
  recalibration goes to a NEW export directory (`export/pg_rot1_b4_*`).
- 09:05 UTC: results (all T, both domains, refusals never clamped silently):
  * pg_rot1_b4_T128 (export written, profile sha256 ff479471...): FineWeb
    0.745 top-1, ppl 12.67 -> 15.80, KL 0.298, 0/36; licence 0.724, ppl 7.96 ->
    12.01, KL 0.488, 0/36. Peak RSS 4.39 GiB (> declared 3.5): the held-out
    float pass is now chunked for later runs.
  * pg_rot1_b4_T32_cal128 (the T=128 calibration evaluated/exported at T=32;
    export sha256 826f7641...): FineWeb 0.690 (ppl 33.7), licence 0.681 (ppl
    37.0), 0/72 refused — ~0.035 below the T=32-calibrated pg+rot.
  * B4-3 o16 (o int16, SH_O = 1, SH_AO window 1..16; Python only): pg+rot
    FineWeb 0.725 -> 0.746, licence 0.714 -> 0.726; dg+rot 0.803 -> 0.801 /
    0.766 -> 0.774; site error of o only 0.326 -> 0.302 (pg). CORRECTION of
    the B3 attribution: o's ~30% error is NOT mainly o's int8 rounding at v's
    scale; next suspects are the probability grid (F_P = 9, floor) and the exp
    table (f_e = 9) amplified by cancellation (o rms << v rms). Knobs f_e/f_p
    added (`pg+fe13`, `pg+fp13`, ...); runs queued in `logs/b4_serial3.sh`
    after `b4_serial2.sh` (one guarded job at a time).
- 09:30 UTC: B4-2 DONE. One pg+rot calibration at T=128 (108 calibration
  sequences, both domains) exported at three context lengths, each verified by
  `b3_verify_export.py` (22 layers bit-exact on two held-out sequences, one per
  domain: ho00 licence, ho36 FineWeb) and by `b4_token_io.py` (table[tokens] ==
  x_in_L00 == float recomputation):
  * `export/pg_rot1_b4_T128` profile sha256 b418a1dd... — FineWeb 0.745 /
    licence 0.724, 0/72 refused;
  * `export/pg_rot1_b4_T64_cal128` 0ad58b25... — FineWeb 0.725 (ppl 17.14 ->
    21.82, KL 0.343) / licence 0.708 (13.47 -> 19.31, KL 0.484), 0/72 refused;
  * `export/pg_rot1_b4_T32_cal128` 826f7641... — FineWeb 0.690 / licence
    0.681, 0/72 refused.
  Weights are byte-identical across the three: `b4_dedup.py` hard-linked 246
  files per derived export (1.10 GB saved each; T64/T32 dirs now 24/12 MB of
  their own). Profile constants of this calibration: Cn_a / Cn_m from the
  T=128 statistics, Ceps from s_x 5.2456e-4, shifts qkv 8 s 6 ao 3 g 8 h 14 z 4.
  Tool provenance of two exports corrected (see export/FORMAT_CHANGES.md).
- 09:52 UTC: B4-1 DONE. dg+rot T=128 (both domains): FineWeb 0.809, ppl
  12.67 -> 14.53, KL 0.161, 0/36; licence 0.793, ppl 7.96 -> 9.87, KL 0.280,
  0/36 (peak RSS 3.77 GiB with the chunked held-out pass). B4-1 table:
  | run | domain | top-1 | ppl float -> int | KL | refused |
  | pg+rot T32 | FineWeb | 0.725 | 26.05 -> 29.70 | 0.352 | 0/36 |
  | pg+rot T32 | licence | 0.714 | 29.30 -> 34.26 | 0.466 | 1/36 |
  | dg+rot T32 | FineWeb | 0.803 | 26.05 -> 27.92 | 0.194 | 0/36 |
  | dg+rot T32 | licence | 0.766 | 29.30 -> 31.77 | 0.266 | 2/36 |
  | pg+rot T128 | FineWeb | 0.745 | 12.67 -> 15.80 | 0.298 | 0/36 |
  | pg+rot T128 | licence | 0.724 | 7.96 -> 12.01 | 0.488 | 0/36 |
  | dg+rot T128 | FineWeb | 0.809 | 12.67 -> 14.53 | 0.161 | 0/36 |
  | dg+rot T128 | licence | 0.793 | 7.96 -> 9.87 | 0.280 | 0/36 |
  B4-3 f_e/F_P runs proceeding serially (`logs/b4_serial3.sh`).
