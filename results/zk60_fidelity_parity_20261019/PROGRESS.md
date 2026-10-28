# Fidelity parity lane — progress ledger

Owner: fidelity parity lane (Claude agent), opened 2026-10-19 11:29 UTC.
Exclusive write set: `results/zk60_fidelity_parity_20261019/`. Read-only
elsewhere (tools copied in when modified). No git writes. Every Python job
over 1.5 GiB or a minute of several cores runs through
`scripts/zk60_resource_guard.py` (class `light`, declared need), detached with
a `.done` marker. Target: D32 (Victor, 2026-10-19 11:30 UTC) — "no
performance degradation versus float"; token agreement is a diagnostic. This
lane proposes the metric set and the numeric threshold; Victor rules.
Calibration/fidelity data only: not a proof, not a privacy claim.

## Log

- 11:29 UTC: read LANE_RULES_20261017.md, B6_REPORT.md (8B), TinyLlama
  calibration PROGRESS (B3/B4), tlcalib.py / b3calib.py / b3_ladder.py /
  b5_8b.py / b8_token_io.py, D24 declared classes, D25 T4, D30, D32, speed
  plan §2 cost law. Box: guard budget 8.0/11.89 GiB committed (gate light job
  + token-io cpu suite holding the heavy lock).
- 11:35 UTC: no LAMBADA / WikiText offline (FineWeb-Edu sample/10BT parquet
  and MuSiQue are the only text datasets cached). Downloaded two SMALL files
  (said so in the report): `data/lambada_openai/en_test.parquet`
  (EleutherAI/lambada_openai rev 900124bf3b82..., en/test/en.parquet,
  1,157,764 B, sha256 99d8a9e5...eea7 = the HF LFS oid; licence MIT per card)
  and `data/wikitext2/test.parquet` (Salesforce/wikitext rev b08601e04326...,
  wikitext-2-raw-v1/test-00000-of-00001.parquet, 732,610 B, sha256
  5f1bea06...6d91 = LFS oid; CC-BY-SA-3.0 / GFDL per card). Read only with
  `python3 -I` from scripts outside `data/`.
- 11:43 UTC: tools written: `fp_lib.py` (export reader with per-array sha256,
  RELAXED block `rx_block` = tlcalib.i_block with every quantizer switchable,
  real weights in LSB units by an interval fit of the solver's per-group
  scales, float / D25-T4 integer heads, one-pass streamed metrics),
  `fp_data.py` (fineweb row group 3, wikitext-2 test windows, lambada seeded
  sample, fwcal = row group 0), `fp_eval.py` (driver), `fp_selfcheck.py`,
  `fp_gptq.py` (GPTQ word rounding at fixed scales), `fp_table.py`.
  SELFCHECK (TinyLlama pg_rot1_b4_T128, layers 0-2, `logs/selfcheck_tl3.log`):
  rx_block all-exact == tlcalib.i_block == export x_out BIT-EXACT; all-relaxed
  vs float block update cos 0.99999997 (rel l2 3e-4); real weights round back
  to the words (mismatch <= 3.5e-7) [MEASURED]. GPTQ unit test on synthetic
  correlated inputs: output error 0.48x of round-to-nearest.
- 11:45 UTC: smoke eval queued (`logs/smoke_tl.*`, light need 3); guard budget
  full (11.0/11.89: gate 6G light + token-io 5G cpu), waiting for admission.
- between 11:45 and 11:49 UTC (date reads): literature check delegated to a helper agent (8-bit / 4-bit /
  integer-only losses, MLPerf accuracy targets), results to be folded in.
- 11:56 UTC: SMOKE OK (`logs/smoke_tl.log`, run `runs/tinyllama/smoke_int`, 16
  seqs): pipeline end to end, TinyLlama integer head built by the D25 T4 rule
  (`runs/tinyllama/inthead_pg_rot1_b4_T128.json`); integer stack 0.15 s per
  sequence-layer at 4 threads, float 1.2 s per sequence; peak RSS 1.52 GiB.
  Literature helper returned (folded into REPORT.md section 1).
- 11:57 UTC: launched detached (one guarded light job each, 4 BLAS threads):
  queue abA (TinyLlama ablations, base + head/score/qk/pdiv/exp/softmax/
  attn_core/o/rope relaxed; fineweb:48,wikitext:48; `logs/queue_abA.out`),
  queue abB (starts after abA's float cache: resid/normq/v/gate/act/uh/
  ffn_core/wts/w_attn/w_ffn/all; `logs/queue_abB.out`), queue ab8 (8B b7 T128
  baseline, same corpora sizes, need 4.5; `logs/queue_ab8.out`).
- 12:08-12:34 UTC: first TinyLlama ablations (fineweb:48 + wikitext:48, T128,
  export pg_rot1_b4_T128, integer head) [MEASURED, shared box n=1]: baseline
  ppl ratio int/float FineWeb 1.230 (95% CI 1.199-1.261), WikiText 1.276
  (1.232-1.322), 2/96 refused (layer 21 FFN gate). Share of the log-ppl gap
  closed by relaxing ONE site family (FineWeb / WikiText): gate int8 28% / 28%,
  norm outputs + norm arithmetic 27% / 21%, score 9% / 6%, Q/K int8 5% / 2%,
  V 2% / 5%, residual stream 3% / 3%, integer head 0.5% / 0.4%.
- 12:36 UTC: added what-ifs (NOT native): `--mods pround` (softmax division
  rounded half up) and `--gate-pc EMIN[:sat]` (per-channel-group SiLU tables,
  e_j per FFN channel from calibration maxima; unit test: exact path still
  bit-exact; layer 2 / 7 / 21 move 5587 / 5430 / 80 of 5632 channels to e_in -5).
  Queued: fx (GPTQ fwcal:64, pround), wi (gate-pc -5, gate-pc -8:sat), var_pg
  (pseudo-export reproduction of pg). My own two ablation queues win guard
  admission first (not FIFO), so these wait ~1 h.
- 12:32 UTC: 8B b7 baseline running: 48 of 96 sequences refused at LAYER 0
  (177 violations) — site to be read from its summary; the b7 held-out had 0
  refusals on 15 seqs (licence + FineWeb).
- 12:43 UTC: COORDINATOR BUDGET REQUEST acknowledged: keep my concurrently
  declared total <= ~5 GiB (one 8B job or two TinyLlama jobs). Running jobs
  finish normally (8B base 4.5, abA exp 2.5, abB uh 2.5 — all started before
  the request was read). Every not-yet-started entry of the old queues
  (abA, abB, fx, wi, var_pg) now DEFERS: `logs/HOLD` exists and fp_eval /
  fp_variant exit 3 at start unless FP_ALLOW=1. Re-queued as two serial
  streams `logs/stream.sh` T1 / T2 (one TinyLlama job each, 2.5-3 GiB), gated
  to start only after the 8B base and the two running TinyLlama jobs have
  written their .done markers. 8B jobs will run later ALONE (no TinyLlama
  stream beside them).
- 13:05 UTC: 8B b7 T128 baseline DONE (`runs/llama3-8b/abl_base`, 4068 s,
  fineweb:48 + wikitext:48) [MEASURED]: FineWeb ppl 9.588 -> 15.623, ratio
  1.630 (CI 1.491-1.781), top-1 0.689, KL 0.515, 0 refused; WikiText 15.419 ->
  27.318, ratio 1.772 (1.667-1.883), top-1 0.644, ALL 48 REFUSED at layer 0
  site V (clamped = diagnostic).
- 13:07 UTC: `fp_diag_v0.py` (calibration lane's own tlcalib.i_block, layer 0,
  `runs/llama3-8b/diag_v0.json`): the token " ." (Ġ., id via tokenizer) gives
  |V| = 140 > 127 at layer 0 in every WikiText window (FineWeb max |V| 68-70).
  Layer-0 Q/K/V depend on the token only, so a vocabulary-wide layer-0 range
  check is exact and cheap. TinyLlama ablations add: exp -1% / 4%, uh -1% / 8%
  (noise).
- 13:08 UTC: interim report sent to the coordinator (SendMessage main). The
  harness REFUSED a Write of REPORT.md ("subagents should return findings as
  text"); the report goes into the final hand-back text; this ledger + runs/
  + logs/ hold the evidence.
- 12:47 UTC (logged late): streams re-planned within the budget request:
  T1 (gate-pc -5, wts, GPTQ), V (variant builds dg / dg+w16 / pg+w16 with
  `fp_variant.py --window qkv:16,g:16,z:16`, then T2's deferred entries), F
  (after T1: full metric set fineweb:128,wikitext:128 + lambada 4 x 250, then
  o / rope / attn_core). Per-tag holds `logs/HOLD_<tag>`.
- 13:09-13:13 UTC: COORDINATOR PRIORITY CHANGE acknowledged: vocabulary-wide
  layer-0 check + recalibration at the FRONT of the 8B queue, same check for
  TinyLlama, and a by-product list of refusing tokens/inputs for the demo lane;
  two-job cap kept. Implemented: `fp_vocab0.py` (exhaustive integer layer-0
  check over the whole vocabulary: norm, Q/K/V, RoPE by pair bound + exact
  re-check), `fp_variant.py --vocab0 --only-layers 0` (layer-0 statistics merged
  with vocabulary-wide float maxima; all other layers and token_io hard-linked
  from the reference export), position/token recording of every violation in
  fp_eval (`RecPos`, summary keys violations_where / refusal_tokens).
  Old streams drained with `logs/HOLD2_<tag>`; new two-lane scheduler
  `logs/lane.sh`: lane X (priority, 8B + small checks; a weight-2 job takes
  `logs/laneY.lock` so lane Y pauses) with `logs/jobs_X.txt`; lane Y (TinyLlama,
  one job at a time) with `logs/jobs_Y.txt`. Lane X starts after
  T1_wi_gatepc5; lane Y after the old streams report finished.
- 13:22 UTC: VARIANT dg (per-layer Cn + per-layer free shifts + per-layer
  tables, one s_x; zero new planes; `variants/tl_dg`, built 385 s;
  `runs/tinyllama/var_dg`) [MEASURED]: ppl ratio FineWeb 1.230 -> 1.105
  (CI 1.086-1.124), WikiText 1.276 -> 1.121 (1.099-1.143): 52% / 53% of the
  log gap closed (paired CI 40-64% / 41-66%); top-1 0.81 / 0.80; 1/96 refused
  (layer 7 score). 
- 13:25 UTC: `wi_gatepc5` (13:05-13:15) is INVALID: the what-if re-quantized
  a gate already rounded to the layer grid (bug). Fixed in fp_lib (the gate is
  taken unrounded when gate_pc is active); per-layer check now moves the block
  error toward the gate-relaxed value (layer 20 update error 0.1827 exact,
  0.1776 gate-pc, 0.1753 gate relaxed). Re-queued as wi_gatepc5b / wi_gatepc8b
  (per-channel bound min(3 x channel max, 1.25 x tensor max)).
- 13:2x UTC: memory: 8B base peaked 4.61 GiB RSS; fp_lib now memmaps the 1 GB
  bf16 embedding / LM head after a once-per-process sha256 re-check
  (TensorRef.read_tile), and fp_eval keeps the residual in float32 between
  layers (exact for int16 values).
- 13:26 UTC: VOCABULARY-WIDE LAYER-0 CHECK [MEASURED, exhaustive, exact]:
  8B b7 T128 (`runs/llama3-8b/vocab0_llama3_8b_pg_rot1_b7_T128.json`, 741 s):
  2 of 128,256 tokens refuse, both at V: " ." (id 662) and "Tags" (id 16309);
  worst |y| 25, |Q| 66, |K| 67, |V| 166 (class 127). TinyLlama pg_rot1_b4_T128
  (`runs/tinyllama/vocab0_pg_rot1_b4_T128.json`, 48 s): 0 of 32,000 refuse;
  worst |y| 19, |Q| 48, |K| 78, |V| 98. Loose all-pairs score bound (info, not
  exhaustive): 588 (8B) / 279 (TinyLlama) vs class 127. Demo-lane list sent to
  the coordinator.
- 13:47 UTC: VARIANT dg + two-byte windows qkv/g/z (`variants/tl_dg_w16`, solver
  picks sh_qkv 11, sh_g 11; `runs/tinyllama/var_dg_w16`) [MEASURED]: ppl ratio
  FineWeb 1.061 (1.043-1.080), WikiText 1.092 (1.076-1.108): 71% / 64% of the
  log gap closed; 4/96 refused (FFN up int16 at layers 0 / 6: tokens
  "Progress", "ps", "É", "Angeles"). Needs a class/layout change (cost: proof
  +3.8% TinyLlama T128, +4.4% 8B T128, +3.4% 8B T512 [MODEL]).
- 13:50 UTC: 8B layer-0 recalibration `variants/l8_b7_voc0` (b7 profile
  decisions, layer 1 sh_s 7, layer-0 stats merged with vocabulary-wide float
  maxima: v_max 0.52 -> 0.73, k_pair 15.1 -> 18.2, q_pair 14.4 -> 15.9, xa_max
  4.67 -> 5.53; layers 1-31 hard-linked from b7): exhaustive check 0 of
  128,256 tokens refuse at layer 0, worst |V| 85 (was 166) [MEASURED].
- 13:45 UTC: COORDINATOR: native R8 accepts per-layer constants; produce dg
  exports in that format. Wrote `fp_export.py` (R8 format writer: per-layer
  keys null + listed, classes checked, run-wide keys asserted, sequences chained
  through tlcalib.i_block and cross-checked with rx_block, rotation/token_io/
  licences hard-linked only at identical residual scales). Queued:
  exports/tinyllama_dg_rot1_T128 (lane Y), exports/llama3_8b_pg_rot1_b7voc0_T128
  and exports/llama3_8b_dg_rot1_voc0_T128 (lane X).
- 14:37 UTC: GPTQ word rounding on dg (`runs/tinyllama/fix_gptq_dg`, fwcal:64 =
  FineWeb row group 0, damp 0.01, act-order, true-sequential; 2951 s) [MEASURED]:
  matmul output error vs real weights down to 0.27-0.41 of round-to-nearest
  (median per matrix); ppl ratio FineWeb 1.105 -> 1.078, WikiText 1.121 ->
  1.127 (no gain off-domain: calibration was FineWeb only); 0 refused.
- 14:38 UTC: 8B b7 + vocabulary-wide layer-0 recalibration (`runs/llama3-8b/
  e8_voc0`, 2858 s) [MEASURED]: WikiText refusals 48 -> 2, ppl ratio 1.772 ->
  1.710; FineWeb 1.630 -> 1.647 (paired change within noise, CI -6%..+2% of
  gap), 1 refused. Deeper refusals now visible (3 of 96 sequences): layer 23
  FFN gate (" each"), layer 31 residual 2 / FFN down (":" , " ").
- 14:40 UTC: SCHEDULING INCIDENT (mine): two lane-Y loops are alive (pid
  520543 from the 13:11 launch, which I misread as dead, and 520839 from
  start_y.sh). They share `logs/laneY.lock`, so they never run two jobs at once
  (cap respected), but a job checked before the other loop finished it runs
  twice: var_dg (13:22-13:30, identical result) and fix_gptq_dg (duplicate
  started 14:37, ~50 min). Fix: fp_eval now exits 0 at once if the run's
  summary.json exists (FP_RERUN=1 overrides); fp_variant / fp_export already
  refuse an existing output dir. Lane X reordered so the TinyLlama dg export
  and the first 8B LAMBADA chunk run while the duplicate holds the lane-Y lock
  (still two jobs at a time).
- 14:40 UTC: export_l8_b7_voc0 running (lane X, started 14:37:55).
- 14:42 UTC: EXPORTS WRITTEN (R8 per-layer format; every array sha256 re-read;
  both exported sequences chained through tlcalib.i_block at each layer's own
  constants, accepted at every layer, rx_block bit-equal — this also validates
  rx_block on the 8B): `exports/llama3_8b_pg_rot1_b7voc0_T128` (profile sha256
  26fc103b...f796; b7 + layer-0 vocab recalibration; per-layer exp_e_s, sh_s,
  silu_member) and `exports/tinyllama_dg_rot1_T128` (profile sha256
  b01a6db1...e6b8a; per-layer exp_e_s, norm_cn_a, norm_cn_m, sh_ao, sh_h, sh_s,
  sh_z, silu_member; run-wide tn 10, sh_qkv 8, sh_g 8). Reported to the
  coordinator. Lane X now: e8_lam0 (8B LAMBADA items 0-99 on b7).
- 14:46 UTC: COORDINATOR: (1) also write llama3_8b_pg_rot1_b7voc0_T32 (b7_T32
  + the recalibrated layer-0 words, T32 RoPE, layers 1-31 / token_io linked,
  exhaustive layer-0 re-check, bit-exact on two sequences, token_io.json
  describing this export's checks); (2) the 8B dg calibration must include the
  deeper refusal sites in its range statistics. Done in code: fp_variant
  `--T 32 --calib-T 128 --ref`, `--extra-calib wtval:64` (WikiText-2
  VALIDATION windows, a third small download: 657,209 B, sha256 204929b7...4c
  = LFS oid, never evaluated) and `--extra-refused e8_voc0` (the 3 sequences
  that refused on b7voc0) merge float MAXIMA into every layer's statistics;
  fp_export now rewrites token_io/token_io.json + SHA256SUMS for the export
  (checks: table[tokens] == x_in_L00 == TOKEN_IO rule from checkpoint rows;
  chained x_out) and drops the reference's README.md. Lane X queue: e8_lam0
  (running) -> T32 build/export/vocab check -> 8B dg build (with extras) ->
  export -> vocab check -> eval -> e8_lam100.
- 14:46 UTC note: the T128 b7voc0 export (already handed over) still carries
  b7's token_io.json / README.md as hard links (stale wording, data files
  correct); not modified in place (the files are b7's inodes).
- 15:25 UTC: the second lane-Y loop re-attempted export_tl_dg and fp_export
  refused (output exists, exit 1): `logs/L_export_tl_dg.done` now reads 1
  although the export written 14:42:31 by lane X is intact (profile.json sha256
  b01a6db1...e6b8a re-checked 15:25). Lane Y now: full_ppl (pg_rot1_b4,
  fineweb:128 + wikitext:128), then LAMBADA 4 x 250, dg ablations, dg full set.
- 15:41 UTC: 8B LAMBADA chunk 1 on b7 (`runs/llama3-8b/e8_lam0`, items 0-99 of
  the seeded order, T128, integer head; 3517 s) [MEASURED]: accuracy float
  0.780, int 0.540, difference -0.240 (95% CI -0.333..-0.147), 5 refused.
- 15:48 UTC: `exports/llama3_8b_pg_rot1_b7voc0_T32` written (profile sha256
  82c7c752...c4f6): layer-0 words byte-equal to the T128 b7voc0 export except
  RoPE tables (= b7_T32's); layers 1-31 hard links into b7_T32; seq_ho00 /
  seq_ho09 chained through tlcalib.i_block at T32, accepted, rx_block equal;
  token_io/token_io.json + SHA256SUMS rewritten for this export (README.md of
  b7 not carried). Exhaustive layer-0 check on it running (lane X).
- 15:49 UTC: TinyLlama FULL ppl set on the current integer model
  (`runs/tinyllama/full_ppl`, pg_rot1_b4_T128, fineweb:128 + wikitext:128)
  [MEASURED]: FineWeb 11.617 -> 14.318, ratio 1.233 (CI 1.210-1.256), top-1
  0.752, KL 0.283; WikiText 18.568 -> 23.991, ratio 1.292 (1.268-1.317), top-1
  0.715, KL 0.338; 1/256 refused (layer 21 FFN gate on "\n").
- 16:01 UTC: exhaustive layer-0 check of exports/llama3_8b_pg_rot1_b7voc0_T32:
  0 of 128,256 tokens refuse (worst |V| 85, |Q| / |K| 64) [MEASURED]. Reported
  to the coordinator. Lane X next: 8B dg build with layer-0 vocab maxima +
  wtval:64 + the 3 e8_voc0 refused sequences merged into the maxima.
- 16:03 UTC: COORDINATOR: leave the T128 b7voc0 export as is (native R8 is
  proving that stack from it); record the stale token_io wording (done, 14:46
  entry; repeated in the final report). Put the 8B LAMBADA gap next to the dg
  result: queued e8_dg_lam0 (same items 0-99) right after e8_dg_voc0.
- 16:13 UTC: COORDINATOR request (token-lane demo): `fp_nexttoken.py` on
  exports/llama3_8b_pg_rot1_b7voc0_T32 seq_ho00 (last of 32 positions):
  integer token 11 (",", margin C 313,660,358 = ~9.51 logits) and float token
  11 (",", margin 6.962 logits) AGREE [MEASURED]; `runs/llama3-8b/
  nexttoken_ho00_b7voc0_T32.json` (profile sha256, ids sha256 as int64 LE and
  as csv). Waited 396 s for guard admission (native r8-stack 7.5G live).
- 16:17 UTC: TinyLlama LAMBADA chunk 1 on pg_rot1_b4 (`runs/tinyllama/full_lam0`,
  items 0-249, 4 truncated contexts) [MEASURED]: accuracy float 0.628, int
  0.512, difference -0.116 (CI -0.163..-0.069), discordant 5 int-only / 34
  float-only, 3 refused. Lane X: 8B dg build started 16:17 (weight 2; lane Y
  paused until it ends).
- 17:02 UTC: D32 THRESHOLD RULED by Victor (relayed by the coordinator):
  integer ppl <= 1.01 x float on FineWeb and WikiText, LAMBADA >= 99% of
  float, zero refusals on the evaluation sets; point estimates (CIs reported
  beside; no upper-CI clause). Final report: pass/fail per metric / model /
  export, lever effects, smallest projected lever set per model (MODEL), and a
  plain statement if a proof-cost change is needed. Lane Y re-prioritised
  (lines 9+): pg LAMBADA rest, dg+w16u build/eval, CUMULATIVE relaxations on
  the dg export (gate; +normq; +attn_core; +wts; all) to find the smallest set
  of site families that would reach 1.01, dg full metric set, the same on
  w16u, then what-ifs.
- 17:27 UTC: 8B dg variant built (`variants/l8_dg_voc0`, 4231 s): extras merged
  into the maxima = 64 WikiText-2 validation windows + the 3 sequences e8_voc0
  refused (layer 31 residual 2, layer 23 FFN gate, layer 31 FFN down), plus
  the layer-0 vocabulary maxima. Per-layer: exp_e_s, norm_cn_a/m, sh_ao, sh_h,
  sh_s, sh_z, silu_member (sh_qkv 8, sh_g 8 uniform). TRADE-OFF: admitting the
  extras doubled the run-wide residual scale s_x 7.218e-4 -> 1.392e-3 (the
  largest layer-31 residual / FFN-down value of the extras is about 2x the
  calibration maximum), i.e. one bit coarser residual at every layer; Ceps
  78617 -> 21140.
- 17:27 UTC: export_l8_dg_voc0 REFUSED by fp_export (residual scales differ
  from b7, token_io cannot be shared) and the three dependent lane-X jobs
  failed at once (exit 1, no compute). Added `--rebuild-token-io` (embedding
  table rebuilt by the TOKEN_IO rule at the new s_in, streamed; final-norm
  Ceps / Cn re-derived by the b8 rule; head words / multipliers / calibration
  xhat maxima hard-linked; f2_fidelity.json not carried). Removed the empty
  partial export dir. Re-queued export + vocab check + eval + LAMBADA after
  e8_lam100 (b7 LAMBADA items 100-199, running since 17:27).
- 17:58 UTC: COORDINATOR HOLD: drop to ONE light job until both token-lane
  tio-cap-llama3 captures (7 GiB each, waiting since ~17:40, their guard holds
  the heavy lock and blocks native R9) show END in the guard history.
  Implemented without touching running jobs: `logs/hold_tiocap.sh` (detached)
  takes `logs/laneY.lock` as soon as lane Y's running full_lam500 releases it
  and keeps it until `history.jsonl` holds 2 END records labelled
  tio-cap-llama3*; `logs/X_wants` set so the lane-Y loops do not race for the
  lock; lane X's next job (export_l8_dg_voc0b, line 18) changed to weight 2 so
  it waits on the same lock after e8_lam100 (running) ends.
- 18:17 UTC: hold acquired the lane-Y lock when full_lam500 ended (18:17:03);
  only e8_lam100 (3 GiB, since 17:27) runs; after it lane X waits too. Guard at
  18:17: gate-token-r7c 6G + e8_lam100 3G committed; tio-cap-llama3 not yet
  started.
- 18:18 UTC: lane Y pruned to what the ruled bar needs (pg LAMBADA rest, dg+w16u,
  cumulative relaxations on dg and w16u, dg full metric set, gate-pc / pround
  what-ifs, damped GPTQ); dropped single-family dg ablations, margin 0.25 and
  extra pg ablations. TinyLlama LAMBADA on pg so far (items 0-749, merged
  `runs/tinyllama/lambada_pg_partial.json`) [MEASURED]: float 0.601, int 0.528,
  difference -0.073 (CI -0.102..-0.045), int/float 0.878, 6 refused.
- 18:23 UTC: HOLD RELEASED 18:22:43 (tio-cap-llama3-8b-t32-L1-dense-pt1 END
  18:21:34, -fixed-pt1 END 18:22:25, both exit 0); removed `logs/X_wants` so
  lane Y resumes; back to two jobs at a time (lane X: e8_lam100 still running,
  then the 8B dg export as a weight-2 job).
- 18:23 UTC: 8B LAMBADA chunk 2 on b7 (`runs/llama3-8b/e8_lam100`, items
  100-199) [MEASURED]: float 0.780, int 0.600, difference -0.180, 5 refused.
  Merged 200 items (`runs/llama3-8b/lambada_b7.json`): float 0.780 (CI
  0.722-0.838), int 0.570, difference -0.210 (CI -0.273..-0.147), int/float
  0.731, 10 refused. Lane X: 8B dg export with token_io rebuild started 18:23:23.
- 18:28 UTC: `exports/llama3_8b_dg_rot1_voc0_T128` WRITTEN (profile sha256
  00aba3d9...5827): R8 per-layer exp_e_s, norm_cn_a/m, sh_ao, sh_h, sh_s,
  sh_z, silu_member; s_x 1.392e-3; token_io REBUILT (embedding sha256
  be317b7e..., final norm Cn 4234 / Ceps 21140; head words / multipliers b7's
  hard links); seq_ho00 / seq_ho09 chained through i_block, accepted, rx_block
  equal. Reported to the coordinator. Lane X: vocab check -> eval -> LAMBADA.
- 19:12 UTC: COORDINATOR request: T128 next-token references for ho00 on
  (a) llama3_8b_pg_rot1_b7voc0_T128, (b) tinyllama_dg_rot1_T128, (c)
  llama3_8b_dg_rot1_voc0_T128 (after its evaluation), and token_io/ for the
  TinyLlama dg export (it had only the root embedding table + token_io.json; no
  head). Wrote `fp_tokenio_tl.py` (TOKEN_IO_SPEC + D25 T4 head rule at TinyLlama:
  per-row int8 head, 12-bit multipliers, final norm g0 127 / Cn by norm_site on
  the b4 calibration set / the export's tn 10 and Ceps; checks table[tokens] ==
  x_in_L00) and generalized fp_nexttoken.py. Queued (a), token_io, (b) next in
  lane Y; (c) in lane X right after e8_dg_voc0.
- 19:15 UTC: COORDINATOR: TinyLlama dg export needs a head side (token lane
  loaders read head_int8_perrow.bin, head_mult12.bin, head_manifest.json,
  token_io.json, SHA256SUMS). fp_tokenio_tl.py (queued, lane Y next) writes
  token_io/ INTO exports/tinyllama_dg_rot1_T128 (the R8 stack proof reads only
  layers + profile, so no proved artifact reads these paths); added a byte
  identity check against R2's r2_inputs (head_int8_perrow b99cbec5...,
  head_mult12 7824019e..., final norm Cn 5664). Cn: the b8 rule uses the FLOAT
  model's rotated final residual on the calibration set, identical for dg and
  pg at the same rotation -> 5664 expected (confirmed when the job runs); the
  dg integer stack had 0 final-norm violations on 96 held-out sequences.
- 19:16 UTC: dg + two-byte windows + FFN-up tensor bound (`variants/tl_dg_w16u`,
  `runs/tinyllama/var_dg_w16u`) [MEASURED]: ppl ratio FineWeb 1.075 (CI
  1.059-1.093), WikiText 1.096 (1.078-1.115), 0 refused (w16 without the up
  fix: 1.061 / 1.092 with 4 refused).
- 19:18 UTC: exports/tinyllama_dg_rot1_T128/token_io WRITTEN (19:16): head words
  / multipliers / final norm BYTE-IDENTICAL to R2 r2_inputs (b99cbec5...,
  7824019e..., Cn 5664 confirmed, tn 10, Ceps 74429); table[tokens] ==
  x_in_L00 on seq_ho00 / seq_ho36. References [MEASURED]: (a) b7voc0_T128 ho00
  integer 11 "," (margin ~0.55 logits) = float 11 "," (12.31); (b)
  tinyllama_dg_T128 ho00 integer 491 "by" (~2.26) = float 491 "by" (10.01).
  Sent to the coordinator.
- 19:29 UTC: 8B dg + layer-0 vocab + extras (`runs/llama3-8b/e8_dg_voc0`, export
  llama3_8b_dg_rot1_voc0_T128) [MEASURED]: ppl ratio FineWeb 1.630 -> 1.281
  (CI 1.192-1.377), WikiText 1.772 -> 1.277 (1.231-1.326): 49% / 57% of the
  log gap closed (paired CI 42-56% / 50-65%); top-1 0.766 / 0.731; KL 0.270 /
  0.330; 2 of 96 refused (layer 25 FFN up on token "s"). Exhaustive layer-0
  check on the export: 0 of 128,256 refuse (worst |V| 86). Queued in lane X
  after e8_dg_lam0: 8B cumulative relaxations on dg (gate+normq;
  +attn_core) to test whether TinyLlama's attribution transfers.
- 19:41 UTC: CUMULATIVE relaxations on the TinyLlama dg export (fineweb:48 +
  wikitext:48) [MEASURED]: dg 1.105 / 1.121; + gate float 1.069 / 1.073; + norm
  outputs float 1.040 / 1.045; + whole attention core float (q, k, v, RoPE,
  score, exp, p, o) 1.020 / 1.014. Even then the ruled bar (1.01) is not met:
  the remaining families are weights, residual int16, FFN up / product, SiLU
  output and the head (dg_gnaw = + weights and dg_all running next).
- 19:58 UTC: dg + gate + norm outputs + attention core + WEIGHTS float
  (`dg_gnaw`) [MEASURED]: 1.0028 / 1.0000 -> would PASS 1.01; everything still
  integer there (int16 residual, int16 FFN up / product, SiLU output, integer
  head) costs ~0.3%. `dg_all` = 1.0000 / 1.0000 exactly (control: the relaxed
  replica reproduces the float model). Queued the measured projection ladder on
  dg+w16u: combo = GPTQ + per-channel-group SiLU (e_in down to -8, what-if) +
  softmax round-half-up (what-if); then + norm outputs float; + attention core
  float; + weights float (words from the combo's GPTQ run).
- 20:01 UTC: reference (c) `runs/llama3-8b/nexttoken_ho00_dg_voc0_T128.json`:
  integer 11 "," (margin ~3.69 logits) = float 11 "," (12.31) [MEASURED]; sent.
- 20:02 UTC: COORDINATOR: cost weight-side options explicitly. Counted
  (`cost/fp_cost_weights.json`, layout replica + speed-plan law): the matmul
  relation does not see the weight width (public words are field elements; the
  verifier's weight fold costs per weight, not per bit); what grows is the
  ACCUMULATOR: int16 weights add 8 bits (8B FFN down |acc| 2^35.8 -> 2^43.8,
  far below p but every no-wrap clause must be re-derived per D24), so every
  requant fed by a matmul needs a wider shift: two-byte remainders at sh_qkv
  (Q +1, Kv +2 planes), sh_ao and sh_z (D +2), sh_g (F +1) and a NEW two-limb
  remainder at FFN up (sh_u is fixed 0 today: F +2) -> committed +10.3% /
  +11.9% / +8.3%, proof +8.9% / +10.3% / +8.1% (TinyLlama T128 / 8B T128 / 8B
  T512) [MODEL]; plus weight bytes 2x (export, load and digest time). int12
  weights cost the same planes (same two-byte limbs). Two-byte remainders alone
  (qkv/g/z, letting int8 words use their full range) cost +3.8% / +4.4% / +3.4%.
- 20:16 UTC: COORDINATOR HOLD #2 (about 1.5-2 h): at most ONE light job (need
  <= 3 GiB) from all my lanes until results/zk60_token_io_r1_20261017/logs/
  r8_round.done exists (corrected from r8_chain.done by the coordinator; nothing
  of mine watched the old name). Running at 20:16: full_ppl_dg (lane Y) and
  e8_dg_gn (lane X), both left to finish. `logs/hold_r8.sh` takes the lane-Y
  lock after full_ppl_dg and keeps it until e8_dg_gn ends (X_wants set so the
  hold wins the lock, removed once it holds it); lane X's queue ends at
  e8_dg_gn; everything else runs one at a time in lane Y, highest value first:
  combo ladder on dg+w16u, dg-export LAMBADA, w16u relaxations, e8_dg_gna, the
  gate / pround what-ifs.
- 20:17 UTC: 8B LAMBADA on the dg export (`runs/llama3-8b/e8_dg_lam0`, items 0-99,
  same items as e8_lam0) [MEASURED]: float 0.780, int 0.690 (b7: 0.540),
  difference -0.090 (CI -0.159..-0.021), int/float 0.885, 4 refused; paired
  dg - b7 integer accuracy +0.150 (CI +0.065..+0.235).
- 20:17 UTC: TinyLlama dg export FULL ppl set (`runs/tinyllama/full_ppl_dg`,
  fineweb:128 + wikitext:128) [MEASURED]: FineWeb 11.617 -> 12.991, ratio
  1.118 (CI 1.103-1.133), top-1 0.818, KL 0.149; WikiText 18.568 -> 21.120,
  ratio 1.138 (1.123-1.153), top-1 0.787, KL 0.185; 0/256 refused (pg: 1.233 /
  1.292, 1 refused). Hold #2 phase 1 active since 20:17:04 (only e8_dg_gn runs).
- 21:59 UTC: the combo ladder (20:49) FAILED at argument parsing: argparse
  reads "--gate-pc -8:mc3" as an option (the value starts with "-"); exit 2, no
  compute. Fixed to "--gate-pc=-8:mc3" (also in the wi_dg_gatepc lines) and
  re-queued as combo2_w16u (+ _na, _naw) after e8_dg_gna (8B, running since
  21:57 as the single job of hold #2). Meanwhile lane Y ran the dg-export
  LAMBADA (4 x 250) and the w16u relaxations [MEASURED]: w16u 1.075 / 1.096;
  + gate float 1.035 / 1.051; + gate + norm outputs float 1.045 / 1.056 (no
  gain from norm outputs once two-byte windows fill the int8 range); + attention
  core float 1.014 / 1.022.
- 22:00 UTC: TinyLlama LAMBADA, 1000 items (4 x 250, T128, integer head)
  [MEASURED]: float 0.598 (CI 0.568-0.628); pg_rot1_b4 int 0.522 (difference
  -0.076, CI -0.101..-0.051; int/float 0.873; 7 refused) -> `runs/tinyllama/
  lambada_pg.json`; dg export int 0.542 (difference -0.056, CI -0.079..-0.033;
  int/float 0.906; 2 refused) -> `runs/tinyllama/lambada_dg.json`.
- 22:01 UTC: 8B dg + gate + norm outputs float (`runs/llama3-8b/e8_dg_gn`)
  [MEASURED]: 1.182 / 1.174 (dg 1.281 / 1.277): closes 33% / 35% of dg's
  remaining log gap (TinyLlama: 61%) -> at 8B more of the error sits in the
  attention core / weights (e8_dg_gna running). Queued TinyLlama LAMBADA on the
  combo (4 x 250, words from combo2_w16u) after the combo ladder.
- 22:32 UTC: 8B dg + gate + norm outputs + attention core float
  (`runs/llama3-8b/e8_dg_gna`) [MEASURED]: 1.140 / 1.130 — far from 1.01
  (TinyLlama at the same step: 1.020 / 1.014). At 8B the families still
  integer there (weights, residual at the doubled s_x, FFN up / product, SiLU
  output, head) cost ~13%. Queued e8_dg_gnar (+ residual float) after the
  TinyLlama combo ladder; e8_dg_gnaw (+ weights float) needs ~5 GiB (real 8B
  weights) and waits for the end of hold #2.
- 23:20 UTC: COMBO LADDER on TinyLlama dg+w16u (`runs/tinyllama/combo2_w16u*`)
  [MEASURED; gate-pc and pround are what-ifs, not native]: combo = GPTQ
  (fwcal:64) + per-channel-group SiLU (e_in down to -8, bound 3x channel max)
  + softmax round-half-up: 1.032 / 1.062 (2 refused: layer-0 FFN gate on "Q",
  the per-channel gate bound); + norm outputs and attention core float: 1.010 /
  1.028; + weights float: 1.005 / 1.009 (both under 1.01).
- 23:22 UTC: wide-class costs counted (`cost/fp_cost_ladder.json`,
  `cost/fp_cost_union.json`) [MODEL plane deltas, layout replica + speed-plan
  law]: R1 two-byte remainders +3.8% / +4.4% / +3.4% proof (TinyLlama T128 /
  8B T128 / 8B T512); R2 softmax round-half-up +2.4% / +1.4% / 0; R3 int16
  score +1.4% / +0.8% / +2.4%; R4 int16 q,k,v,qr,kr,o +5.1% / +6.0% / +4.5%;
  R5 int16 norm outputs (+ up remainder) +7.4% / +8.3% / +6.6%; R6 int16
  weights +8.9% / +10.3% / +8.1%; union of R1-R6 +21.1% / +22.1% / +17.8%
  (committed +22.8% / +23.5% / +16.9%).
- 23:53 UTC: 8B dg + gate + norm outputs + attention core + RESIDUAL float
  (`runs/llama3-8b/e8_dg_gnar`) [MEASURED]: 1.142 / 1.131 = no change from
  e8_dg_gna (1.140 / 1.130): the doubled s_x costs nothing measurable. Queued
  e8_dg_noW (every site float except the int8 WEIGHTS; 3 GiB) next to isolate
  the weights' share at 8B under the hold's memory cap.
- 23:56 UTC: HOLD #2 OVER (r8_round.done seen 23:56:35); back to two jobs at a
  time. Moved e8_dg_noW to lane X (removed from lane Y before it was read) and
  added e8_dg_lam100 (8B dg LAMBADA items 100-199) and e8_dg_gnaw (8B weights
  share; real 8B weights need ~5 GiB -> weight 2, lane Y pauses while it runs).
- 00:23 UTC: COORDINATOR HOLD #3 (~50 min): one light job (<= 3 GiB) at a time
  until results/zk60_token_io_r1_20261017/logs/r8_8b.done exists. Running at
  00:23: e8_dg_noW (lane X) and combo2_lam0 (lane Y), left to finish.
  `logs/hold_r8b.sh` takes the lane-Y lock after combo2_lam0 and keeps it until
  e8_dg_noW ends; lane X's next job (e8_dg_lam100) made weight 2 so it needs the
  same lock; e8_dg_gnaw (needs ~5 GiB > 3 GiB cap) removed from lane X until the
  hold ends (kept in logs/_deferred_gnaw.txt).
- 00:24 UTC: single-lever what-ifs on the TinyLlama dg export [MEASURED]:
  per-channel-group SiLU tables, frozen registry only (e_in >= -5, bound 3x
  channel max): 1.105 -> 1.063 / 1.121 -> 1.078 (39% / 34% of dg's remaining
  log gap), 1 refused; with new members down to e_in -8: 1.069 / 1.085 (worse,
  2 refused on "Q" at layer 0); softmax round-half-up: 1.112 / 1.130 (no gain,
  within noise) -> the combo ladder carried two sub-optimal what-ifs (e_in -8
  and pround); registry-only groups and no pround are the better choice.
- 00:37 UTC: 8B dg with EVERY site float except the int8 WEIGHTS
  (`runs/llama3-8b/e8_dg_noW`) [MEASURED]: 1.133 / 1.113 -> at 8B the int8
  weight words alone cost ~11-13% ppl on the dg export (TinyLlama: ~1.5-2%);
  gate + norm outputs + attention core + residual together: e8_dg_gnar 1.142 /
  1.131. The 8B lever after dg is the WEIGHTS. Plan once hold #3 ends: 8B dg +
  weights float (upper bound, 5 GiB) and an 8B dg + two-byte-remainder build
  (realizable weight-range lever, +4.4% proof) with export and evaluation.
- 00:40 UTC: COORDINATOR: plan approved (8B weights-float bound, 8B dg +
  two-byte build/export/eval, then final report); cost weight-range options
  side by side and give the one-line decision X. Counted
  (`cost/fp_cost_weight_options.json`) [MODEL plane deltas]: (a) two-byte
  remainders qkv/g/z +4.4% proof (8B T128) / +3.4% (T512); (b) per-output-
  channel public multipliers = a DIFFERENT relation (public factor on the
  accumulator before requant; no new committed planes for m_j, the verifier
  folds an O(columns) public vector) whose remainder grows by the multiplier's
  bits: 12-bit multipliers need three-byte remainders at qkv/ao/g/z and a new
  3-limb remainder at FFN up -> +19.5% / +15.4%; 4-bit multipliers fit two-byte
  windows (~ the int16-weight count, +10.3% / +8.1%); (c) GPTQ 0%. 8B dg word
  use (exports/llama3_8b_dg_rot1_voc0_T128): per-channel median max |W8| wq
  3-7, wk 4-7, wg 5-19, wu 8-33, wd 10-62, wv ~25, wo 21-41 (of 127);
  sh_qkv = sh_g = 8 = window max in every layer.
- 01:13 UTC: HOLD #3 OVER (r8_8b.done 01:13:02). Queued in lane X after
  e8_dg_lam100: e8_dg_w (8B dg with weights float only, upper bound of the
  weight levers; replaces the deferred e8_dg_gnaw), build_l8_dg_w16u (8B dg +
  two-byte remainders qkv/g/z + FFN-up tensor bound + layer-0 vocab + extras),
  its EVALUATION export (fp_export --class-change sh_qkv:16,sh_g:16,sh_z:16:
  recorded in profile.json as outside today's classes) and evaluation.
- 02:44 UTC: 8B dg with only the WEIGHTS float (`runs/llama3-8b/e8_dg_w`)
  [MEASURED]: 1.165 / 1.137 (dg 1.281 / 1.277; everything-but-weights float
  1.133 / 1.113): at 8B the weights and the activation sites each carry about
  half of dg's remaining log gap; neither alone approaches 1.01. 8B dg LAMBADA
  items 100-199: int 0.66 / float 0.78, 3 refused.
- 02:45 UTC: 8B dg LAMBADA merged 200 items (`runs/llama3-8b/lambada_dg.json`)
  [MEASURED]: float 0.780, int 0.675 (difference -0.105, CI -0.154..-0.056),
  int/float 0.865, 7 refused (b7 on the same 200 items: int 0.570, 0.731).
- 04:25 UTC: 8B dg + two-byte remainders built (`variants/l8_dg_w16u`, 4927 s)
  but its EVALUATION export was REFUSED by fp_export: the reference sequence
  seq_ho00 (licence text) leaves the FFN-up int16 class at layer 0 (a
  completeness defect of this variant: the up range needs a larger margin);
  e8_dg_w16u (export missing) failed at once. Evaluating the variant directly
  instead, with the FLOAT head (no token_io in a pseudo-export), and the dg
  export with the float head for a like-for-like pair: e8_dg_w16u_fh, e8_dg_fh.
- 05:27 UTC: COORDINATOR: native R10 counted the weight-range levers exactly
  (results/zk60_1b_native_20261017/r10/WEIGHT_RANGE_COST.md): (a)-exact
  (two-byte q/k/v/g/z remainders, union pin at z, NEW one-byte up remainder)
  committed +9.59% (8B T128) / +6.73% (8B T512) / +8.29% (TinyLlama T128);
  (a) without up +4.20 / +2.91 / +3.59 (= my earlier count); (c2) narrow
  per-channel multipliers in (a)'s windows +10.06 / +7.05 / +8.72; (b) 12-bit
  multipliers +21.96 / +15.39 / +19.07. My w16u layer-0 up refusals are
  explained: the up site was not covered (sh_u stayed 0). Asked to measure
  (i) (a)-exact and (ii) (c2) at 8B dg (and TinyLlama). Implemented:
  fp_variant --sh-u (per-layer up remainder 0..8, Wu words rescaled at the
  same output scale) and --up-margin; fp_lib/fp_eval --mult-bits (per-output-
  channel b-bit public multipliers, m_j = ceil(2^b rowmax/127), words
  round(W_real 2^b/m_j), out = round(m acc / 2^(sh+b)); b capped at window -
  sh). Unit check (TinyLlama dg layers 3 / 12): exact path still bit-exact;
  (c2) at q5,k5,v7,o8,g6,u4,d6 lifts the median channel max word 6 -> 96 (q)
  and brings the block update error to the weights-float level (0.208 vs
  0.207; 0.157 vs 0.157; int8 dg 0.256 / 0.199). Queued: TinyLlama c2_dg,
  c2+gate-pc, (a)-exact build/eval; 8B e8_c2_dg (5 GiB), (a)-exact build and
  float-head eval.
- 05:42 UTC: 8B like-for-like pair with the FLOAT head [MEASURED]: dg export
  1.2813 / 1.2767 (integer head 1.2812 / 1.2771: the D25 T4 head costs nothing
  measurable at 8B); dg + two-byte windows qkv/g/z + up tensor bound
  (`variants/l8_dg_w16u`, a without the up remainder) 1.142 / 1.107 = 47% / 59%
  of dg's remaining log gap, BUT 44 of 96 sequences refused (layer-0 FFN up
  int16 overflow on tokens like "cl", " $", " animal"): the (a)-exact build with
  the up remainder and up margin 3 is queued to remove them.
- 06:31 UTC: COORDINATOR HOLD #4: after e8_c2_dg (running since 05:46) start
  nothing until results/zk60_token_io_r1_20261017/logs/r11_chain.done exists.
  Implemented: HOLD2_build_l8_dg_aex / HOLD2_build_tl_dg_aex make the next
  lane jobs (the (a)-exact builds) exit 3 at start and their evaluations fail
  fast (variant missing), so both lanes go idle; `logs/hold4_resume.sh` removes
  the holds and re-appends the four jobs (fresh labels) when the marker
  appears. TinyLlama c2_dg and c2gpc_dg finished before the hold.
- 06:32 UTC: TinyLlama (c2) on the dg export (`runs/tinyllama/c2_dg`, multipliers
  q5 k5 v7 o8 g6 u4 d6; WHAT-IF, native +8.72% committed) [MEASURED]: 1.067 /
  1.093, 0 refused (dg 1.105 / 1.121; dg+w16u 1.075 / 1.096); (c2) + per-channel-
  group SiLU (registry, e_in >= -5) (`c2gpc_dg`): 1.036 / 1.056, 1 refused.
- 06:42 UTC: 8B (c2) on the dg export (`runs/llama3-8b/e8_c2_dg`, integer head;
  WHAT-IF; native-counted +10.06% committed T128 / +7.05% T512) [MEASURED]:
  1.166 / 1.149, 0 refused = the weights-float bound (1.165 / 1.137): narrow
  multipliers capture the whole weight lever. Sent to the coordinator. Hold #4:
  the deferred builds exited 3 and the dependent evals failed fast at 06:41:34;
  both lanes idle until r11_chain.done.
- 06:49 UTC: COORDINATOR: after (a)-exact, measure the realizable ACTIVATION
  levers at the smallest widths (norm outputs int12 / int16, F_P 10 / 11 / 12,
  group SiLU at 8B), stacked on c2; native lane counting them in r11/
  ACTIVATION_COST.md. Implemented what-ifs in fp_lib: `--mods yK` (norm outputs
  int(8+K): y = round(x g Cn 2^K / (D 2^tn)), consumer shifts +K, exact int64
  path) and `--mods fpN` (F_P = N, sh_o + N - 9). Unit check (TinyLlama dg layer
  12, block update error vs float): int8 0.199, y4 0.186, y8 0.186, norm
  outputs float 0.185 -> int12 already equals float; fp10 0.194, fp12 0.192,
  y8+fp12 0.175; exact path still bit-exact. The post-hold queue
  (`logs/hold4_resume.sh`, edited after its wait loop) now runs: TinyLlama
  c2+gpc with y4 / y8 / y4+fp12 (lane X, weight 1) and fp10 / fp11 / fp12 /
  y4+fp12+attention-core-float (lane Y); 8B c2+gpc, + y4+fp12, + y4 (weight 2);
  then the (a)-exact builds and evals.
- 07:09 UTC: COORDINATOR: native R11 activation costs landed (r11/
  ACTIVATION_COST.md): F_P 10-12 zero cost; SiLU input int12 and group SiLU
  zero planes; norm outputs int16 cheaper than int12 (+6.6% on c2 at 8B T128);
  stacks vs R9 committed (8B T128 / T512): LOW = c2 + norm int16 + F_P 12 +
  attention words int16 (int12 at 8B T512 non-DD) + group SiLU + SiLU input
  int12: +22.4% / +17.9%; MID = LOW + SiLU output 4 bits finer: +27.7% /
  +21.7%; HIGH = MID + attention int16 + product h int24 + score int12: +29.2% /
  +26.1%. Measure LOW, MID, HIGH at 8B, LOW at TinyLlama, LAMBADA on the best.
  Implemented width what-ifs in rx_block (`--mods yK fpN aK gK oK hK sK`;
  consumer shifts absorb each change; default path unchanged: exact ==
  export re-checked). Unit check (TinyLlama dg layers 3 / 12, block update
  error vs float): int8 dg 0.256 / 0.199; c2+gpc 0.208 / 0.155; LOW 0.056 /
  0.039; MID = LOW (SiLU output finer buys nothing); HIGH 0.036 / 0.023;
  near-float 0.013 / 0.004. (First LOW attempt subtracted the attention bits
  from the PV shift twice: O overflow; fixed before any run.) Queued: lane X
  t_LOW, then 8B e8_LOW, e8_HIGH, e8_MID, e8_c2gpc, then the (a)-exact chain;
  lane Y TinyLlama t_HIGH, t_LOWs4, t_LOWh8, t_MID.
- 07:37 UTC: TinyLlama activation widths on the dg export (48 + 48)
  [MEASURED, WHAT-IFs on c2 + group SiLU]: c2+gpc 1.036 / 1.056; + norm int12
  1.0195 / 1.0245; + norm int16 1.022 / 1.033; + F_P 10 / 11 / 12: 1.031 /
  1.045, 1.041 / 1.046, 1.034 / 1.051 (F_P alone ~ noise); + norm int12 + F_P
  12: 1.015 / 1.021; + that + attention core float: 1.0035 / 1.0030. LOW (c2 +
  group SiLU + norm int16 + F_P 12 + attention words int16 + SiLU input int12):
  1.0061 (CI 1.0013-1.0108) / 1.0081 (1.0034-1.0128) -> PASSES the 1.01 ppl
  bar on both corpora (native LOW +20.98% committed at TinyLlama T128), but 1
  refused sequence (layer 19 FFN gate on "Der": the group-SiLU per-channel
  bound, 3x channel max). Queued t_LOW_mc5 (bound 5x) and TinyLlama LOW
  LAMBADA 4 x 250 (mc5) before t_HIGH.
- 08:36 UTC: 8B LOW (`runs/llama3-8b/e8_LOW`, c2 + group SiLU (bound 3x) + norm
  int16 + F_P 12 + attention words int16 + SiLU input int12; native +22.4%
  committed 8B T128 / +17.9% T512) [MEASURED, WHAT-IF]: 1.0226 (CI 1.010-1.035)
  / 1.0139 (1.005-1.023): close to, not under, 1.01; 29 of 96 sequences
  refused, all at the FFN gate of the group-SiLU what-if (layers 17 / 21 / 31,
  tokens " the", ":", " ", " first", " ,") -> per-channel gate bounds too tight
  at 8B (statistics without the extras). Queued e8_LOW_mc5 and e8_HIGH_mc5 (5x
  bound) after e8_HIGH.
- 00:10 UTC Oct 21 (resumed after the coordinator's login expiry; every detached
  job had finished: lane X through e8_c2gpc 17:46, lane Y through t_MID 18:09;
  box idle, guard budget 0). Results that landed while down [MEASURED, WHAT-IF
  widths on the dg export + c2 + group SiLU; 48 FineWeb + 48 WikiText; ratio
  int/float ppl; refused sequences]:
  TinyLlama: LOW_mc5 1.0052 / 1.0098, 0; LOW + score int12 (s4) 0.9997 /
  1.0018, 0; LOW + product int24 (h8) 1.0009 / 1.0053, 1; MID 1.0050 / 1.0074,
  1; HIGH 0.9971 / 0.9987, 0. TinyLlama LOW_mc5 LAMBADA 1000 items
  (`runs/tinyllama/lambada_LOW.json`): float 0.598, int 0.604 (+0.006, CI
  -0.006..+0.018), ratio 1.010 PASSES 0.99, but 7 refused sequences: layer 21 V
  on "prepared" / "be" / "liked" / "concerned" (the attention-word range: a8
  keeps the int8 calibrated range) and layer 10 FFN gate on "Em" / "say" / "St"
  (group-SiLU channel bound).
  8B: c2+gpc 1.140 / 1.098, 30; LOW (gate bound 3x) 1.0226 / 1.0139, 29;
  LOW_mc5 1.0207 / 1.0099, 2 (L17 gate " ", L23 gate " each"); MID 1.0239 /
  1.0126, 30; HIGH 1.0034 / 1.0048, 30; HIGH_mc5 1.0045 / 1.0034, 1 (L23 gate
  " each"). So at 8B HIGH passes the ppl bar, LOW does not (FineWeb 1.021);
  every remaining refusal is a calibration bound (no proof cost to widen).
  (a)-exact runs (var_aex, aex_c2gpc, e8_aex_fh, e8_aex_c2gpc_fh) are INVALID
  as (a)-exact measurements: fp_variant took the ids of the up statistics
  BEFORE merge_extra / merge_vocab0 replaced those arrays, so --up-margin was
  silently ignored at 8B, and --up-mc was never passed (per-channel bound
  stayed 3x channel max; b3calib's own note says held-out up maxima reach 5x):
  all their refusals are layer-0..15 FFN up. Fixed (fp_variant: the up hook now
  runs after the merges).
  New zero-proof-cost what-ifs: `--mods ahJ` (attention words keep their int(8+K)
  width but spend J bits on range: V/Q/K/O headroom 2^J) and `--gate-pc=E:mcX:tmY`
  (group-SiLU channel bound min(X chan max, Y tensor max); tm default 1.25).
  Unit check (TinyLlama dg layers 3 / 12 / 19, block update error vs float):
  exact path still == export; LOW mc5 0.0560 / 0.0392 / 0.0296, LOW ah1 mc8 tm2
  0.0563 / 0.0394 / 0.0302; LOWs4 0.0372 / 0.0236 / 0.0223, LOWs4 ah2 mc8 tm2
  0.0373 / 0.0241 / 0.0230; HIGH 0.0361 / 0.0232 / 0.0221 (the free headroom
  costs <= 0.0007). Queued (lane X, 8B, weight 2): e8_LOWs4f (LOW + s4 + ah2,
  gate mc8 tm2), e8_LOWs4h8f (+ h8). Lane Y (TinyLlama): t_LOWs4f, t_LOWf,
  build_tl_aex3 (--up-mc 8 --up-margin 2) + t_aex3, then LAMBADA 4 x 250 on
  LOWs4f. Then 8B LAMBADA on the best stack and the corrected 8B (a)-exact.
- 00:15 UTC: COST-FAITHFULNESS CATCH: r11 section 4 says per-channel-group SiLU
  with SiLU input int12 needs groups x 4096 <= 2^log_cols: at most 4 groups per
  layer at T128 (8 at T512), else Dom::Tab and every Tab plane grow. My LOW /
  MID / HIGH runs used up to 8 groups per layer (8B HIGH_mc5: 8 in one layer,
  6 in one, 5 in 12; TinyLlama up to 8), so they are slightly OUTSIDE the
  costed LOW form. Added `--gate-pc=...:ngN` (fp_lib gate_groups ngroups: the
  finest e_in values merge into the N-th coarsest, one output member per e_in
  group, the coarsest its channels need). Unit check (TinyLlama dg layers 3 /
  12 / 19, LOW + s4 + ah2, mc8 tm2): uncapped 0.0373 / 0.0241 / 0.0230; ng4
  identical; ng1 (ONE table per layer, i.e. no grouping) 0.0373 / 0.0241 /
  0.0232 -> with SiLU input int12 the grouping itself buys almost nothing on
  TinyLlama. Rewrote the unstarted jobs: lane X e8_LOWs4g (ng4) replaces
  e8_LOWs4h8f; lane Y t_LOWs4g, t_LOWg, t_LOWs4g1 (ng1), the (a)-exact pair,
  LAMBADA 4 x 250 on LOWs4g. e8_LOWs4f (started 00:10:31, uncapped groups)
  keeps running (its fp_lib was loaded before the ng edit; its recorded
  tool_sha256 of fp_lib.py will be the post-edit file, whose default path is
  unchanged).
- 00:17 UTC: COUNTED the candidate stacks with a COPY of the native r11 counter
  (`cost/fp_r11_stacks.py` -> `cost/fp_r11_stacks.json`; the replica anchor
  re-runs and asserts; only stacks added). Committed vs R9 non-DD (8B T128 /
  8B T512 / TinyLlama T128), [MODEL] prove time at T128:
  LOW16 +22.35 / +19.41 / +20.98 (LOW12 at T512 +17.88);
  LOW + S12 (score int12) +23.29 / +21.96 / +22.61, time +15.8%;
  LOW + S12 + H24 +23.77 / +22.28 / +23.04, time +16.2%;
  LOW + H24 +22.82 / +19.73 (LOW12+H24 +18.85) / +21.41, time +15.5%;
  HIGH (WIDE) +29.16 / +26.10 / +27.74, time +18.9%.
  DD CAVEAT (r11 3.2: S12 makes DD infeasible): R9 with DD is 3.9% smaller
  than R9 non-DD at 8B T128 but 20.8% smaller at 8B T512. Against R9 DD
  (absolute): LOW16 in DD form +23.25 (T128) / +24.51 (T512); LOW + H24 DD
  +23.74 / +24.92; LOW + S12 (non-DD only) +28.25 / +54.02; HIGH (non-DD)
  +34.35 / +59.25. So at T512 any stack with the score word int12 costs ~30
  points more than a DD-compatible one. Queued 8B e8_LOWh8g (LOW + product
  int24 + fixes, DD-compatible) BEFORE e8_LOWs4g; TinyLlama t_LOWh8g in lane Y.
  Group SiLU with no group column (one table per layer) saves the +1.8 to
  +1.95% element-terms and nothing committed.
- 00:29 UTC: COORDINATOR (~00:27): Victor amended D32 (~00:19, console): "1-2%
  is acceptable ... fix the refusals and proceed with the current fidelity".
  Register: ppl <= 1.02x float on FineWeb and WikiText; LAMBADA >= 98% of
  float; ZERO refusals still. Task: the CHEAPEST stack meeting it at each
  model (subsets cheaper than LOW too), LAMBADA on it at both models, and the
  exact native build spec. (a)-exact optional unless a candidate.
  Re-planned: TinyLlama prune set first (lane X weight 1, beside lane Y), then
  8B. Counted (copy of r11; committed vs R9 non-DD, 8B T128 / 8B T512 /
  TinyLlama T128; [MODEL] prove time 8B T128):
  P1 = c2 + F_P 12 + group SiLU + SiLU input int12: +10.06 / +7.05 / +8.72
  (= c2: all three are zero committed), time +7.0%;
  P2 = P1 + norm int16 (LOW without attention int16): +17.35 / +12.17 / +14.95,
  time +11.3%;
  P3 = P1 + attention words int16 (LOW without norm int16): +15.98 / +14.93 /
  +15.57, time +11.2%;
  P2 + score int12: +18.29 / +14.72 / +16.57 (non-DD only);
  P2 + h int24: +18.74 / +13.14 / +16.19 (DD form +19.49 / +16.60 / +17.35);
  LOW +22.35 / +19.41 (LOW12 +17.88) / +20.98; LOW + h int24 +22.82 / +19.73
  / +21.41; LOW + score int12 +23.29 / +21.96 / +22.61; HIGH +29.16 / +26.10
  / +27.74. Lane X after e8_LOWs4f: t_P1, t_P2, t_P3, t_P2s4, t_P2h8 (all with
  the fixes: gate bound mc8 tm2, <= 4 tables; ah2 wherever attention words are
  int16), then e8_LOWh8g. Lane Y: t_LOWs4g, t_LOWg, t_LOWs4g1 (one SiLU table),
  t_LOWh8g, build_tl_aex3 + t_aex3 ((a)-exact is +9.59 at 8B T128, 0.47 below
  c2, so it stays a candidate weight lever). LAMBADA lines removed until the
  stack is chosen.
- 00:40 UTC: COORDINATOR: (1) prefer DD-compatible stacks: D37 sets the first
  application (public proofs that media content passed a safety classifier;
  fixed policy prompts of a few hundred tokens -> T256-T512+, where DD saves
  20.8% at T512); score-int12 stacks rank last unless nothing else passes;
  LOW + h int24 and the P2 / P3 family first. The deciding cost column is
  therefore 8B T512 in DD form: P2 +15.37, P2 + h int24 +16.60, P3 (A16)
  +18.86, LOW16 +24.51, LOW16 + h int24 +24.92 (vs R9 DD). (2) Next round will
  likely be a classifier (survey in results/zk60_classifier_survey_20261021/;
  fidelity = decision agreement + F1/AUPRC); do not start it before the model
  choice. Lane X order now t_P1, t_P2, t_P3, t_P2h8, t_P2s4 (last), e8_LOWh8g.
  e8_LOWs4f at layer 18, 0 refused so far.
- 01:06 UTC: 8B LOW + score int12 WITH the zero-cost refusal fixes
  (`runs/llama3-8b/e8_LOWs4f`: c2 + norm int16 + F_P 12 + attention words int16
  with 2 bits of range (ah2) + SiLU input int12 + group SiLU bound min(8x
  channel, 2x tensor) (groups uncapped, up to 8) + score int12) [MEASURED,
  WHAT-IF]: FineWeb 1.0113 (CI 1.0029-1.0197), WikiText 1.0100 (0.9997-1.0204),
  0 of 96 refused, 0 head final-norm violations. PASSES the amended bar
  (<= 1.02, zero refusals) on perplexity; LOW without score int12 was 1.0207 /
  1.0099 (2 refused). Ranked last by the DD steer (non-DD only: +23.29 at 8B
  T128, +21.96 at T512 vs R9 non-DD; +54.0 at T512 vs R9 DD).
- 01:08 UTC: scheduling note: lane Y had already read the t_LOWs4f line (00:10)
  and was blocked on laneY.lock behind e8_LOWs4f when I rewrote the unstarted
  lines (00:15), so it now runs t_LOWs4f (uncapped groups, with ah2 / mc8 tm2)
  and its next line is t_LOWg: t_LOWs4g (ng4) will not run (score int12 ranks
  last anyway; t_LOWs4g1 gives the one-table evidence). Guard budget 11.5 /
  11.89 GiB committed (other lanes' gate-* jobs 5.5 GiB), so the next 8B job
  may wait for admission.
- 01:30 UTC: TinyLlama prune results (dg export, 48 + 48, all with c2 and the
  fixes: gate bound min(8x channel, 2x tensor), <= 4 SiLU tables per layer
  (ng4), ah2 where attention words are int16) [MEASURED, WHAT-IF]:
  P1 (c2 + F_P 12 + SiLU input int12 + group SiLU) 1.0310 / 1.0470, 0 refused
  -> FAILS; P2 (P1 + norm int16) 1.0221 / 1.0278, 0 -> FAILS; LOWg (P2 +
  attention int16) 1.0086 / 1.0101, 0 -> PASSES (LOW_mc5 without the fixes was
  1.0052 / 1.0098); LOW + score int12 with fixes (t_LOWs4f, uncapped groups)
  1.0017 / 1.0048, 0 -> passes. So the attention words int16 are the step that
  clears 1.02 at TinyLlama; P2 + h int24 is projected ~1.018 / ~1.023 from the
  measured h8 effect (-0.004) and is dropped (with t_P2s4) so that 8B
  e8_LOWh8g starts after t_P3.
- 01:44 UTC: TinyLlama [MEASURED, WHAT-IF, fixes on]: P3 (c2 + attention int16
  + F_P 12 + SiLU input int12 + group SiLU, norm outputs int8) 1.0164 / 1.0225,
  0 refused -> FAILS WikiText by 0.0025; LOW + score int12 with ONE SiLU table
  per layer (ng1, no group column) 1.0025 / 1.0066 vs uncapped 1.0017 /
  1.0048 (grouping buys ~0.001-0.002). Queued t_P3h8 (P3 + h int24; counted
  +16.00 TinyLlama T128, +17.12 8B T128 DD, +19.27 8B T512 DD vs LOW + h int24
  +21.41 / +23.74 / +24.92). 8B e8_LOWh8g started 01:43 (LOW + h int24 +
  fixes, DD-compatible); TinyLlama lane waits behind it (cap).
- 01:45 UTC: dropped the corrected (a)-exact pair (build_tl_aex3, t_aex3) per
  the coordinator (optional unless a candidate): the counted stacks are built
  on c2, (a)-exact would save only 0.47 (8B T128) / 0.32 (8B T512) committed
  points and would need its own activation-stack measurement at 8B (~2.7 h).
  The earlier (a)-exact runs stay reported as INVALID (up bound bug). Lane X
  gets the 8B LAMBADA line after e8_LOWh8g's result.
- 01:51 UTC: CORRECTION (window check of the ah2 what-if): I called the
  attention-range bits "zero proof cost"; they are only if every shift stays in
  its counted window. Taught the copied counter an `ah` parameter (q/k/v/o
  scales 2^ah coarser: q/k/v shifts +ah, ao shift -ah, score shift -2ah, PV
  unchanged): with the native (c2) base shifts (sh_a +
  bits, q/k reaching 16) ah2 pushes the q/k/v remainders to three bytes: LOW +
  h int24 +24.74 (8B T128 non-DD) / +26.58 (8B T512 DD) instead of +22.82 /
  +24.92. But in the what-if as measured, sh_qkv = 8 in every layer of both dg
  exports, so q / k shift = 8 + 5 + 2 = 15 <= 16 (fits two bytes) and only v
  (8 + 7 + 2 = 17) leaves its window. Unit check (TinyLlama dg layers 3 / 12 /
  19 / 21, LOW + h8, gate mc8 tm2 ng4): ah0 v7 0.0555 / 0.0392 / 0.0300 /
  0.0184; ah2 v7 0.0554 / 0.0392 / 0.0299 / 0.0183; ah2 with the V multiplier
  at 6 bits (shift 8 + 6 + 2 = 16) 0.0556 / 0.0392 / 0.0296 / 0.0183 -> SAME.
  So the zero-cost realizable form is ah2 with v multiplier 6 bits (q/k stay
  5): every window then equals the counted LOW (+ h int24) windows. The native
  realization must keep q/k/v shifts <= 16 (spend at most 16 - 8 - 2 bits on
  the multiplier at v); recorded for the build spec. e8_LOWh8g (running) uses
  v7: its perplexity stands for the v6 form per this unit check [MODEL]; the
  LAMBADA runs will use v6.
- 02:54 UTC: 8B LOW + h int24 with the fixes (`runs/llama3-8b/e8_LOWh8g`: c2
  (v multiplier 7 bits) + norm int16 + F_P 12 + attention words int16 with ah2
  + SiLU input int12 + group SiLU <= 4 tables per layer (bound min(8x channel,
  2x tensor)) + product h int24; DD-compatible) [MEASURED, WHAT-IF]: FineWeb
  1.0108 (CI 1.0054-1.0162), WikiText 1.0094 (1.0043-1.0147), 0 of 96
  refused, 0 head violations, max 4 tables per layer -> PASSES the amended bar
  on perplexity, same fidelity as LOW + score int12 (1.0113 / 1.0100) at the
  DD-compatible cost (+22.82 8B T128 non-DD / +23.74 DD; 8B T512 +24.92 DD;
  TinyLlama T128 +21.41). LOW alone (no fixes) was 1.0207 / 1.0099: the h
  int24 step (+0.47 / +0.41 points) is what clears FineWeb. Chosen 8B stack
  unless P3 + h int24 (counted 5.6 points cheaper at 8B T512 DD) passes at
  TinyLlama comfortably. Queued 8B LAMBADA 2 x 100 (items 0-199, same as b7
  and dg) on the build-spec form (v multiplier 6 bits): e8_LOWh8v6_lam0 / 100.
- 03:22 UTC: TinyLlama [MEASURED, WHAT-IF, fixes on]: P3 + h int24 1.0133 /
  1.0221, 0 refused -> FAILS WikiText (the P2 / P3 family fails even at
  TinyLlama, so no 8B run of it); LOW + h int24 1.0041 / 1.0084, 0 -> passes.
  Cheapest passing: TinyLlama = LOW (+20.98 TinyLlama T128); 8B = LOW + h int24
  (+22.82 8B T128 non-DD; +24.92 8B T512 DD). Queued LAMBADA (all in the
  build-spec form: v multiplier 6 bits, ah2, gate mc8 tm2 ng4): 8B
  e8_LOWh8v6_lam0 / lam100 (lane X), TinyLlama t_LOWv6_lam0..750 (lane Y) and
  t_LOWh8v6_lam0..750 (lane X, weight 1). The 8B job has waited for guard
  admission since 03:09 (8.8 of 11.9 GiB committed by gate-*, shieldstral-*,
  r12-t1-build; new small jobs admitted ahead) while holding laneY.lock;
  asked the coordinator for a 5 GiB window.
- 03:31 UTC: COORDINATOR: 8B choice accepted (LOW + h int24, zero-cost fixes,
  <= 4 SiLU tables, DD-compatible). 5 GiB window: gate lane on HOLD, Shieldstral
  prep lane holding new jobs; my run is admitted when the current jobs drain.
  Order: 8B LAMBADA first, then the TinyLlama chunks, then the final report with
  the native build spec. Next round (after the report, D38): Shieldstral at
  this stack (prep in results/zk60_shieldstral_prep_20261021/); not started.
- 03:43 UTC: COORDINATOR note for the coming Shieldstral round (not started):
  do NOT take RoPE tables from transformers 4.48.1 (it mis-computes the YaRN
  config: ignores original_max_position_embeddings 16384 and mscale, applies a
  1.277 attention factor; margins move by up to 1.33 logits, borderline verdicts
  flip). Use results/zk60_shieldstral_prep_20261021/crosscheck/
  rope_tables_reference.npz (float64), or transformers >= 5.13.1 (Ministral3),
  or 4.48 with max_position_embeddings 16384 and attention_factor 1.0; the
  native loader regenerates the tables and must match. 8B LAMBADA chunk 1
  admitted 03:33, at layer 2 (163 s / layer on the loaded box).
- 04:36 UTC: COORDINATOR (04:35): after the 8B LAMBADA, TinyLlama LAMBADA chunks
  ONE at a time (<= 3 GiB; native R12 freeze needs an 8 GiB window beside me),
  8B items 100-199 first. Implemented: unread TinyLlama chunk lines removed from
  both lanes (saved in logs/pending_tl_lambada.txt); HOLD_t_LOWv6_lam0 makes the
  one already-read lane-Y chunk defer (exit at start) when it gets the lock after
  lam0; detached `logs/tl_lambada_release.sh` (pid 817259) lifts that hold and
  appends all eight chunks to lane Y once lam100 has started, so they run
  serially after it. NOTE: 8B LAMBADA chunk 1 shows 1 refused sequence at layer
  15 (first violation; site in the summary when the chunk ends).
- 05:09 UTC: 8B LAMBADA items 0-99 on the chosen stack in build-spec form
  (`runs/llama3-8b/e8_LOWh8v6_lam0`: LOW + h int24, v multiplier 6 bits, ah2,
  gate mc8 tm2 ng4) [MEASURED]: accuracy float 0.780, int 0.820 (+0.040, CI
  +0.001..+0.079; discordant 4 int-only / 0 float-only), top-1 agreement 0.967,
  KL 0.0092; 2 of 100 refused: layer 15 score on " it" (seq 96, pos 93) and
  layer 21 FFN gate on " the" (seq 9, pos 50). Same items on b7: 0.540; on dg:
  0.690. Items 100-199 (e8_LOWh8v6_lam100) were admitted at 05:05:50, just
  before the coordinator asked to defer them for the native R12 8 GiB window;
  I cannot stop it (no guard cancel, kill refused) and the coordinator lets it
  run (~06:40); the native window moves after it. Wrote `fp_diag_refusal.py`
  (re-runs one fp_eval configuration on the refused sequences only, records the
  UNCLAMPED value at each first refusal, the range, and the bits a zero-cost
  bound change would need; inputs to a sequence's first refused layer are
  bit-identical to the run). Queued in lane Y after the first TinyLlama chunk:
  diag on t_LOW_lam0 (TinyLlama, code check) and on e8_LOWh8v6_lam0 (8B,
  need 3 GiB). Dropped the TinyLlama LOW + h int24 LAMBADA chunks (the
  coordinator's one-at-a-time rule makes 8 chunks ~2.3 h; the TinyLlama chosen
  stack is LOW, whose 4 chunks stay).
- 06:16 UTC: 8B LAMBADA items 100-199 (`runs/llama3-8b/e8_LOWh8v6_lam100`)
  [MEASURED]: float 0.780, int 0.780 (0 discordant), top-1 0.992, KL 0.0091, 0
  refused. Merged 200 items (`runs/llama3-8b/lambada_LOWh8v6.json`): float
  0.780, int 0.800, ratio 1.026 -> PASSES >= 98%; 2 refused sequences (both in
  items 0-99). Next to the same 200 items: b7 0.570 (ratio 0.731, 10 refused),
  dg 0.675 (0.865, 7 refused). My lane now runs only <= 3 GiB jobs one at a
  time (t_LOWv6_lam0 started 06:16:23, then the two diagnostics, then 3 chunks).
- 17:34 UTC Oct 26 (resumed after the usage-limit stop; the lane's queued jobs
  had all finished by 07:51 Oct 21; a second lane-Y loop re-ran each line once
  more, harmlessly: fp_eval exits ALREADY DONE, the diagnostic rewrote an
  identical file). Results [MEASURED]:
  TinyLlama LOW in build-spec form (v multiplier 6, ah2, gate mc8 tm2 ng4)
  LAMBADA 1000 items (`runs/tinyllama/lambada_LOWv6.json`): float 0.598, int
  0.599, ratio 1.002, discordant 20 / 19, 0 refused -> PASSES; the 7 refusals
  of the earlier LOW_mc5 run are gone. Code-check diagnostic on t_LOW_lam0
  (`runs/tinyllama/t_LOW_lam0/refusal_diag.json`): L10 gate channel 4350 at
  -9.04 vs +-8 (member -4; calib channel max 4.14, tensor 5.49; bound was
  min(5x, 1.25x tensor) = 6.87) -> mc8 tm2 gives member -3 (+-16): a
  calibration bound, fixed at zero cost.
  8B diagnostic (`runs/llama3-8b/e8_LOWh8v6_lam0/refusal_diag.json`):
  (1) L21 FFN gate on " the": channel 5158 at 16.19 vs +-16 (member -3; calib
  channel max 6.84, tensor 7.80; bound min(8 x 6.84, 2 x 7.80) = 15.6, capped
  by the tensor term) -> member -2 (+-32) admits it: CALIBRATION BOUND,
  zero cost (tensor cap 4 instead of 2). (2) L15 score on " it" (seq 96, query
  93): the causal row's max |s| is 87 < 127, so the refused entry is a MASKED
  (future, j > t) score: the native relation (tlcalib.i_block, "all (t, j)")
  range-checks every T x T score including the masked ones. Zero-cost fix:
  SH_S + 1 (and exp e_s + 1) at that layer, inside the counted score window,
  if the masked score is <= 2x over. Launched (detached, guard 3 GiB) the fix
  check: both refused sequences through all 32 layers with gate tm4 and SH_S
  + 1 at layer 15 (`refusal_fixcheck.json`), recording the full-row maximum.
- 17:56 UTC: 8B refusal FIX CHECK (`runs/llama3-8b/e8_LOWh8v6_lam0/
  refusal_fixcheck.json`, guard 3 GiB, 11 min) [MEASURED]: both refused LAMBADA
  sequences through all 32 layers with the gate tensor cap 4 (mc8 tm4 ng4) and
  SH_S + 1 / exp e_s + 1 at layer 15: 0 violations at every layer. Layer 15 at
  the refused query: causal max |s| 44, full-row max 66 at key position 124
  (> query 93: a MASKED score; ~132 > 127 before the extra bit). Layer 21
  channel 5158 now at member -2 (+-32), admitted. Both are calibration bounds,
  fixed at zero proof cost (score shift 19 stays in the counted three-byte
  window; tables stay registry members, <= 4 per layer). Root causes for the
  rules: score calibration statistics are causal-only while the native relation
  checks all T x T scores; the group-SiLU bounds used the 30-sequence b5
  statistics without the export's extra calibration. tm4 coarsens 5.9% of 8B
  gate channels by one member [effect on the full sets not re-measured].
  Wrote the self-contained build spec `S2_BUILD_SPEC.json` (data file for the
  native S2 / R13 build and Astra's A2); final report goes to the coordinator
  as text. Lanes stopped (END appended to both job files); nothing running.
