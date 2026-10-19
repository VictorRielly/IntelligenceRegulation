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
