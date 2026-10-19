# Lane B5: Llama-3-8B calibration (pg+rot port) — progress

Owner: calibration lane (Claude). Writes only here (plus the shared tools in
results/zk60_1b_calibration_20260929/). No git. One guarded job at a time,
declared need from measured peaks (<= 6 GiB, lower while the native lane works).
Calibration data, not a proof, not a privacy claim.

- 10:45 UTC 2026-10-17: model NousResearch/Meta-Llama-3-8B rev 315b2009...,
  local at local-models/zk60-llama3-8b (4 shards, sha256 pinned in
  results/zk60_mvp_20260929/llama3-8b/source.json; config: width 4096, FFN
  14336, 32 q / 8 kv, head_dim 128, 32 layers, theta 500000, eps 1e-5, vocab
  128256, BF16, untied head, no RoPE scaling).
  * LICENCE: the repo's LICENSE / USE_POLICY.md were never downloaded; the
    Meta Llama 3 Community License + AUP text is in the local provider metadata
    (model card) -> copied to `LLAMA3_LICENSE_from_model_card.txt`; attribution
    in `NOTICE` (required if derived weights are distributed).
  * TOKENIZER: NOT AVAILABLE OFFLINE. The repo lists tokenizer.json
    (9,085,698 B, git blob b197f72effb9d5ed16ee0f5663e11e4cfac2ba62),
    tokenizer_config.json (50,566 B, blob 72193e9e...), special_tokens_map.json
    (73 B); none is on this box, and no other local tokenizer is Llama-3's (a
    full search found TinyLlama/Mistral SentencePiece, Gemma, SmolLM2, DeBERTa,
    BGE). Not substituting any. PROPOSED smallest fetch (not done): tokenizer.json
    at the pinned revision (+ the two small config files, optionally LICENSE and
    USE_POLICY.md), verified by git blob sha1.
- 10:50 UTC: B5-1 port: tlcalib/b3calib/b3_ladder select the 8B with
  ZK60_MODEL=llama3-8b (geometry, shard pins, D24 AO window 0..8, norm window
  with -32768 => tn 9 gives 32 bits at width 4096, Cn <= 2^20, float32 weight
  transforms, row-blocked rotation, column-blocked exact int matmul for the
  14336 x 4096 matrices (int8 kept, float64 blocks of 2048 columns; exactness
  asserted below 2^53)). TinyLlama behaviour unchanged by construction
  (float64 path, same windows). Driver `b5_8b.py` (tokenizer.json via
  `tokenizers`, or an explicit SYNTHETIC plumbing input with no fidelity
  meaning; vocabulary-streamed head; lean pass 2).
- 10:56 UTC: 8B plumbing smoke (2 layers, T=32, SYNTHETIC seeded token ids =
  no fidelity meaning; `logs/b5-smoke_syn_L2.*`): exit 0, 307 s, peak RSS
  3.02 GiB (cgroup 3.86 incl. page cache); checkpoint pin of 4 shards 23 s;
  per layer ~50 s pre-pass stage 1, ~33 s stage 2, ~30 s pass 2 (12+12 seqs);
  profile constants inside D24 (Cn 1595/834, shifts qkv 8 s 7 ao 6 g 8 h 16
  z 5, s_x 5.57e-4), no clipping, no refusal.
- 11:00 UTC: BOS massive activations (`b5_bos.py`, `runs/b5_bos_massive.json`,
  float, token 128000 alone — exact for every sequence since position 0 sees
  only itself; 62 s, peak 1.81 GiB): layer 1 writes +226 (ch 788), -205 (ch
  1384), -202 (ch 4062); held ~227 through layer 30; layer 31 removes them
  (absmax 17). One int16 residual scale at margin 1.5 needs s_x >= 0.0104 in
  the model basis (coarser than TinyLlama's 0.0089 that collapsed) but only
  5.6e-4 in the rotated basis (BOS rotated absmax ~11.7). Non-BOS massive
  tokens need real text (tokenizer).
- 11:01 UTC: B5-2 / B5-3 BLOCKED on the tokenizer (see 10:45). Handing back
  with the fetch proposal; nothing of mine is running.
- 11:05 UTC: tokenizer UNBLOCKED by the orchestrator: tokenizer.json,
  tokenizer_config.json, special_tokens_map.json, LICENSE, USE_POLICY.md
  fetched from the pinned revision, all git blobs match
  (results/zk60_mvp_20260929/llama3-8b/tokenizer-license-fetch-20261017.json).
  Checked: vocab 128256, <|begin_of_text|> = 128000 (the driver prepends it,
  add_special_tokens=False). NOTICE now cites the repo's LICENSE / USE_POLICY.md
  (copied into every export). Driver spills the per-layer integer chain to
  disk (runs/<name>/chain_int16/) instead of RAM.
- 11:06 UTC: launched `logs/b5_serial.sh` (one guarded job at a time):
  pg+rot T=32 with export (need 4.5 / cap 6) -> independent verifier ->
  pg+rot T=128 (smaller sets).
- 12:35 UTC: pg+rot T=32 DONE (`logs/b5-pg_T32.*`, `runs/llama3_8b_pg_rot1_T32`):
  calibration 27 licence + 27 FineWeb seqs, held-out 36 + 36. Profile shifts
  qkv 8 s 6 ao 3 g 8 h 14 z 5 (same set as TinyLlama's B3 pg_rot1), one s_x
  in the rotated basis (~5.6e-4). FineWeb top-1 0.623, ppl 18.85 -> 37.11,
  KL 0.737, 1/36 refused; licence 0.547, ppl 22.81 -> 49.75, KL 1.06, 0/36.
  Peak RSS 3.45 GiB (cgroup 6.0 incl. page cache), wall 94 min.
  Weak spot: LAYER 1 (creates the BOS massive activation): its attention has
  raw scores up to 223 (BOS sink) so e_s = 2 (score quantum 4 raw = 0.35
  logit at head_dim 128); score error 0.67, prob 0.81, o 2.1; isolated cos
  0.735, chain cos 0.947 -> 0.71 across that layer (other layers isolated
  0.95-0.996). FFN of layer 1 is fine (h 0.03). No clipping anywhere.
  Export `export/llama3_8b_pg_rot1_T32` (6.6 GB) profile sha256 2507fbde...
- 12:37 UTC: export VERIFIED (`logs/b5-verify-pg_T32.*`, report
  `logs/b5-verify-pg_T32.report.json`): 32 layers bit-exact on seq_ho00
  (licence) and seq_ho36 (FineWeb), every sha256 / table key / no -128;
  156 s, peak 1.58 GiB. README.md written (sha256 0fcd7649...). Profile:
  tn 9, Cn_a 2266, Cn_m 1557, Ceps 78617, shifts qkv 8 s 6 ao 3 g 8 h 14 z 5,
  per-layer e_s and SiLU member, RoPE theta 500000.
- 12:38 UTC: added the `s16` experiment knob (int16 score class, SH_S = 1,
  65536-row exp table; NOT native; no-op for every default path) and
  `b5_layer1.py` (layer-1 isolated comparison, int8 vs int16 scores), queued
  after the T=128 run (`logs/b5_serial2.sh`, one guarded job at a time).
- 14:12 UTC: pg+rot T=128 DONE (`logs/b5-pg_T128.*`; no export, smaller sets:
  calibration 18 licence + 12 FineWeb seqs, held-out 18 + 12): s_x 7.22e-4,
  Cn 2092/1424, shifts qkv 8 s 6 ao 3 g 8 h 14 z 4. FineWeb top-1 0.653, ppl
  10.59 -> 20.55, KL 0.678, 0/12 refused; licence 0.612, ppl 4.07 -> 11.46,
  KL 1.057, 0/18. Peak RSS 3.63 GiB (cgroup 6.0 incl. page cache), 88 min.
  Layer 1 again the weak spot (iso cos 0.765, chain 0.94 -> 0.74).
- 14:15 UTC: layer-1 score-class check (`b5_layer1.py`, `runs/b5_layer1_score_class.json`;
  isolated, 24 held-out seqs, same calibration; 209 s, peak 2.84 GiB): native
  int8 score (e_s 2, SH_S 6): iso cos 0.727, dcos 0.617, score err 0.666, prob
  0.805, o 2.05; s16 experiment (int16 score, SH_S 1, e_s -4, 65536-row exp
  table; NOT native): iso cos 0.825, dcos 0.733, score 0.310, prob 0.508, o 1.28.
  A wider score class helps but does not close layer 1 (q/k int8 + the BOS sink).
- 14:16 UTC: all B5 jobs finished; nothing of mine running.

## B6 (coordinator round 4), from 2026-10-17 14:18 UTC

- 14:20 UTC: driver options added: `--profile-from <prepass.json>` (reuse a
  run's profile decisions; with the same cached statistics the words are
  identical), `--export-name`, `--link-from <export>` (hard-link byte-identical
  files layer by layer as they are written: transient disk stays ~one layer),
  `--l1-mode {s16, perhead, m2zero, fe13}` (layer-1 experiments) and
  `--check-against <export>` (every non-overridden layer's words compared with
  an existing export). tlcalib: per-query-head exp-table hook (experiment only).
  2-layer synthetic smoke OK (`logs/b6-smoke.*`, 202 s).
- 14:23 UTC: `logs/b6_serial.sh` launched (one guarded job at a time, need 4 /
  cap 5): B6-1 exports llama3_8b_pg_rot1_b6_T128 then _T64 (one calibration:
  B5's T=128 statistics + profile, 18 licence + 12 FineWeb calibration seqs;
  held-out 9 licence + 6 FineWeb), both verifiers; then B6-2 whole-model T=32
  FineWeb runs with layer 1 as int16 score / per-head e_s / no-margin e_s /
  native (B5's T=32 calibration and profile, checked against the B5 export).
- 14:55 UTC: T=128 export DONE: `export/llama3_8b_pg_rot1_b6_T128`, profile.json
  sha256 eedbcff1201f631c2d5aaa46bbd2cee6a1b1290ec08078415a9ed31567ee23df;
  profile = B5 T=128 decisions (Cn 2092/1424, shifts qkv 8 s 6 ao 3 g 8 h 14
  z 4, s_x 7.218e-4). Held-out FineWeb 6 seqs top-1 0.651 (ppl 9.72 -> 17.97,
  KL 0.607), licence 9 seqs 0.633 (3.71 -> 9.59, KL 0.968), 0 refused. Peak RSS
  3.32 GiB, 31 min. T=64 export started (same calibration, hard links).
- 14:59 UTC: queue trimmed: the B6-2 'none' run would repeat B5 T=32's FineWeb
  numbers exactly (same words, same 36 sequences, per-sequence chains), so
  `logs/b5_run.sh` (replaced atomically; the running instance keeps the old
  inode) now runs label b6_l1_none on the first 2 layers only: the layer-1
  isolated baseline on the same FineWeb sequences, ~5 min instead of ~50.
- 14:59:58 UTC: clean box shutdown. T=64 export (guard label b5-b6_T64) got
  SIGTERM, exit 143 after layer 5; the queue then started the T=128 verifier
  at 14:59:55, which died at once (`logs/b6-verify-llama3_8b_pg_rot1_b6_T128.log`
  is 0 bytes, no .done): **T=128 was never independently verified**. Box up
  again 18:21 UTC, /tmp empty.

## B6 resume (round B6, coordinator brief 18:40 UTC), from 2026-10-17 18:29 UTC

- 18:30 UTC: inspected the partial `export/llama3_8b_pg_rot1_b6_T64`: layers
  00..05 only, every weight/table file a hard link (nlink 2) into the T128
  export; manifests and rope tables own inodes. `b3_ladder.write_bin` writes
  IN PLACE, so re-running over it would truncate shared T128 inodes. Removed
  the partial tree with `rm -r` (unlinking names never changes the T128
  inodes; afterwards 0 of T128's 584 files have nlink > 1; T128 profile.json
  sha256 still eedbcff1...). Moved the killed run dir to
  `runs/KILLED_20261017T1459Z_llama3_8b_pg_rot1_b6_T64_cal128` (evidence only).
  The driver now refuses to export into a non-empty export dir (b5_8b.py sha
  changes; T128 export records the earlier sha).
- 18:31 UTC: launched `logs/b6r_serial.sh` detached (stdout `logs/b6r_serial.out`,
  marker `logs/b6r_serial.done`), one guarded `light` job at a time: verify
  T128 (need 2.5 / cap 3.5) -> T64 export `b5-b6r_T64` (need 4 / cap 5, same
  args as before, hard links from T128) -> verify T64 -> B6-2 `b6_l1_s16`,
  `b6_l1_perhead`, `b6_l1_m2zero` (whole model, T=32, 36 FineWeb held-out) ->
  `b6_l1_none` (2 layers).
- 18:37 UTC: T=128 export VERIFIED (`logs/b6r-verify-llama3_8b_pg_rot1_b6_T128.*`,
  independent reader, fresh process, export bytes only): 32 layers, seq_ho00
  (licence) and seq_ho09 (FineWeb) bit-exact at all 32 layers, every sha256 /
  table key / no -128, errors [] [MEASURED; 396 s, peak RSS 2.00 GiB, shared
  box n=1]. T64 export `b5-b6r_T64` started 18:37 UTC.
- 18:38 UTC: native-cost facts collected (read-only, from
  ops/zkp-mvp/trained-1b/hashline/src/private_block/): one 256-row exp table
  per layer (per-layer key exp_e_s in -8..8), SH_S and f_e RUN-LEVEL (one value
  for all 32 layers), score s8 checked by two U8 lookups, 11 committed planes +
  8 Fp2 helper planes per score element at 8B T32, table domain padded to
  2^13 = 8192 rows at 8B (log_cols 13), importer accepts only exp shape [256].
  Feeds the B6-2 cost column (B6_REPORT.md).
- 19:05 UTC: T=64 export DONE (`logs/b5-b6r_T64.*`, run
  `runs/llama3_8b_pg_rot1_b6_T64_cal128`): `export/llama3_8b_pg_rot1_b6_T64`,
  profile.json sha256 ea84a6b74bbbbc8c3145e3fb746b87c536004b9165ab2337baaa9dc1289d25be.
  Same calibration as T128 (B5 T=128 statistics + profile). Layer numbers
  identical to the killed run's layers 0-5 (deterministic). Held-out FineWeb
  6 seqs top-1 0.630 (ppl 12.59 -> 23.21, KL 0.581), licence 9 seqs 0.628
  (5.84 -> 13.46, KL 0.911), 0 refused [MEASURED; 1655 s, peak RSS 3.02 GiB,
  shared box n=1]. 352 files (32 layers x 11 weight/table words) hard-linked
  to T128 (byte-identical), 232 own files (manifests, RoPE T=64 tables, 2
  sequences seq_ho00 / seq_ho09, root files). T64 verifier started 19:05 UTC.
- 19:08 UTC: T=64 export VERIFIED (`logs/b6r-verify-llama3_8b_pg_rot1_b6_T64.*`):
  32 layers, seq_ho00 and seq_ho09 bit-exact at all 32 layers, errors []
  [MEASURED; 197 s, peak RSS 1.69 GiB]. Its 352 linked files are T128's
  inodes, so T128's weight bytes are re-confirmed after the linking run; T128
  profile.json sha256 unchanged (eedbcff1...). B6-1 COMPLETE. B6-2 `b6_l1_s16`
  started 19:08 UTC.
- 19:30 UTC: COORDINATOR HOLD: the privacy gate's guarded job
  `tl-v4-l22-dense-f` (light, need 6 GiB) has been starved of admission since
  18:50. My running job (s16) finishes normally; no new guarded job of mine
  starts until the guard status lists `tl-v4-l22-dense-f` as a live job or
  20:30 UTC, whichever is first. Implemented by atomically replacing
  `logs/b5_run.sh` (each queue step execs it afresh; the running s16 instance
  keeps the old inode) with a version that polls the guard status every 30 s
  before launching; it prints "hold released" to `logs/b6r_serial.out`.
- 19:48 UTC: B6-2 `s16` DONE (`logs/b5-b6_l1_s16.*`, run
  `runs/llama3_8b_pg_rot1_b6l1s16_T32`; 2398 s, peak RSS 3.01 GiB, shared box
  n=1): words of every layer other than 1 identical to the B5 T32 export
  (0 layers differ). FineWeb 36 seqs: top-1 0.680, ppl 18.85 -> 29.14, KL
  0.529, 1 refused (same sequence count as B5). Layer 1 e_s -4, iso cos 0.824.
- 19:49 UTC: `tl-v4-l22-dense-f` admitted 19:48:34 (when s16 freed its
  budget); hold released 19:49:04; `perhead` waiting in guard admission
  (budget 10.5 + 4 > 11.9 GiB).
- 19:51 UTC: added `b6_sink.py` (FLOAT-only layer-1 diagnostic: how much of
  the score / Q / K range is the BOS sink; per head, with and without the BOS
  key column / row; implied e_s; softmax mass on BOS) and enqueued it
  detached behind the serial queue (starts only once `logs/b6r_serial.done`
  exists; guard label b6-sink, light need 3.5 / cap 4.5; marker
  `logs/b6-sink.done`). Also `b6_summarize.py` (B6-2 table ->
  `runs/b6_l1_summary.json`) and `b6_t512_estimate.py` (task 3 arithmetic ->
  `runs/b6_t512_estimate.json`).
- 20:02 UTC: `perhead` (need 4) still waiting for admission: smaller jobs
  (2-3 GiB) keep fitting beside the 6 GiB privacy job. `logs/b5_run.sh`
  atomically replaced again: B6-2 labels now declare need 3.5 / cap 4.5
  (measured s16 peak RSS 3.01 GiB + margin) for the remaining runs (m2zero,
  none). The waiting perhead guard keeps its 4 / 5 (a waiting guard is never
  killed).
- 20:26 UTC: `perhead` admitted (waited 2225 s). Layer 1: per-head e_s
  [1,1,0,1,1,1,1,1,1,0,1,1,1,1,1,1,2,2,2,1,1,1,0,1,1,1,1,1,1,0,1,1]; raw score
  max per head 67-223 on the calibration set (the sink reaches every head);
  iso cos 0.790.
- 20:50 UTC: COORDINATOR HOLD #2: heavy queue blocked on budget
  (`r5-ladder8b-T128-cpu` need 7 holds the heavy lock in admission; GPU stack
  runs behind it). perhead finishes normally; no new guarded job of mine until
  `r5-ladder8b-T128-*`, `gzc-stack-s0*`, `gzc-stack-s4*` have completion
  records in the guard history (ts_end >= 20:45Z) and none is live, or 22:00
  UTC. Implemented as `logs/b6_hold2.py` (tested both paths), polled every
  30 s by the again atomically replaced `logs/b5_run.sh` (release line in
  `logs/b6_hold2.log` and `logs/b6r_serial.out`). The b6-sink follow-up starts
  only after the queue's last run, so it is behind the same hold. Limitation:
  the guard status lists only admitted jobs; the 22:00 deadline bounds it.
- 20:58 UTC: B6-2 `perhead` DONE (`logs/b5-b6_l1_perhead.*`, run
  `runs/llama3_8b_pg_rot1_b6l1perhead_T32`; 1948 s, peak RSS 3.06 GiB, shared
  box n=1): other layers' words identical to the B5 export. FineWeb 36 seqs:
  top-1 0.648 (accepted 0.656), ppl 18.85 -> 29.99, KL 0.570 (acc 0.547),
  2 refused: FineWeb #10 at layer 24 V (the same sequence refuses in the
  baseline and s16) and #21 at layer 2 FFN gate (downstream of the changed
  layer-1 output). m2zero held by hold #2.
- 21:26 UTC: hold #2 released by its condition (history: r5-ladder8b-T128-cpu
  ended 21:10:26Z, gzc-stack-s0-base 21:13:37Z, a gzc-stack-s4* run by
  21:26Z; none live). `m2zero` started 21:26:46 (need 3.5 / cap 4.5).
- 21:30 UTC: `m2zero` layer 1: e_s 1, SiLU member (-3, -11) instead of
  (-2, -11), iso cos 0.834 (12 iso seqs, no refusal) BUT chain: all 36
  held-out sequences REFUSE at layer 1's FFN GATE (integer chain max 133 >
  127; float-quantized iso input stays inside). m2zero drops the margin of
  all three power-of-two exponents of layer 1 (score e_s, gate e_in, act
  e_out), so it does not isolate "no-margin e_s"; its whole-model numbers can
  only be diagnostic (refusals clamped; head_accepted empty -> None).
- 21:33 UTC: added l1-mode `s0m` to b5_8b.py (margin 1.0 on the SCORE
  exponent only, by wrapping b3.qk_scales for layer 1's solve_layer call;
  gate / act exponents keep their margin; native: a per-layer table key).
  Enqueued detached `b6_l1_s0m` after b6-sink (same args as the other B6-2
  runs; through logs/b5_run.sh, so need 3.5 / cap 4.5 and the hold check;
  marker `logs/b6_s0m_chain.done`, guard marker `logs/b5-b6_l1_s0m.done`).
- 21:40 UTC: MECHANISM from the layer-1 site errors: s16 (score step 1/16)
  and m2zero (step 2) have the SAME score error 0.297 and the same q/k errors
  0.095 / 0.072; native has 0.668 with q/k 0.194 / 0.142. The solver ties
  s_q s_k 2^SH_S = 2^e_s; with the run-level SH_S 6, native e_s 2 forces the
  int8 Q/K words one bit coarser than their ranges need (qk slack 2.84 vs
  1.84 bits). The score grid itself is not the bottleneck; Q/K coarseness
  is. o stays at rel err ~1.44 in every option (next suspect: the int8 o
  class). Added l1-modes `sh7` (layer-1 SH_S 7, e_s 2, all margins kept =
  per-layer SH_S), `o16` (layer-1 o int16, B4-3 knob), `sh7o16`; enqueued as
  2-layer screens (~5 min each) after s0m (labels b5-b6_l1_scr_*, marker
  `logs/b6_screens_chain.done`).
- 22:03 UTC: `m2zero` DONE (2184 s; other layers' words identical to B5):
  36/36 refused (layer 1 FFN gate). DIAGNOSTIC ONLY (refusals clamped):
  top-1 0.685, ppl 18.85 -> 29.87, KL 0.549. `none` (2 layers) next.
- 22:08 UTC: `none` (2 layers) DONE (299 s): layer 1 on the 36 FineWeb seqs
  (12 iso): iso cos 0.720, dcos 0.608, chain cos 0.712 (layer 0: 0.949).
  `logs/b6r_serial.done` written (queue complete).
- 22:10 UTC: `b6-sink` DONE (109 s; `runs/b6_sink_layer1_v1_unsigned.json`):
  layer-1 max |raw score| is NOT at the BOS key: 223.4 (calibration) / 229.9
  (held-out FineWeb) on the full rectangle, identical without the BOS key
  column and without BOS row+column (causal non-BOS 223.4 / 227.6); implied
  e_s 2 at margin 1.25 either way. K per-pair ranges unchanged without
  position 0 (ratio 1.0); Q ranges up to 1.34-1.42x. Softmax mass on BOS
  0.80-0.81 (the sink is a probability phenomenon, not the range driver).
  So a "public BOS key/value" special case would not lower layer 1's e_s.
  Held-out max 229.9 < 254 = 127 x 2^1, so e_s 1 without margin holds in
  float on held-out (s0m test running). Extended b6_sink.py with signed
  extremes (positive vs negative, diagonal, BOS column, off-diagonal) and
  enqueued it as `b6-sink2` after the screens (behind hold2 as well).
- 22:10 UTC: `s0m` (whole model) started.
- 22:13 UTC: `s0m` layer 1: e_s 1, SiLU member unchanged (-2, -11), iso cos
  0.824, dcos 0.731, chain 0.801, no refusal; site errors = s16's exactly
  (q 0.095, k 0.072, score 0.297, prob 0.487, o 1.447): confirms the Q/K
  coupling mechanism. BUT the T=128 calibration's layer-1 raw max is 278.9 >
  254 = 127 x 2^1 (T=32: 223.4), so e_s 1 is infeasible at T=128 even with no
  margin: s0m is a T=32-only fix. Layer 1's own free-shift choice was SH_S 7
  in both the T=32 and T=128 pre-passes (profile median imposed 6); SH_S 7
  with e_s 2 is feasible at both (log2 need_P -5.73 / -5.64 <= -5). The sh7
  screen decides between "per-layer SH_S" and the T=32-only s0m.
- 22:50 UTC: `s0m` DONE (`logs/b5-b6_l1_s0m.*`, run
  `runs/llama3_8b_pg_rot1_b6l1s0m_T32`; 2373 s; other layers' words identical
  to B5): FineWeb 36 seqs top-1 0.668 (accepted 0.669), ppl 18.85 -> 29.69
  (acc 30.17), KL 0.544 (acc 0.521), 1 refused (FineWeb #10, as baseline).
  Within noise of s16 (acc 0.679 / 29.97 / 0.517). Screens started.
- 22:57 UTC: screen `sh7` (2 layers; 241 s): layer 1 e_s 2, SH_S 7, SiLU
  (-2, -11): iso cos 0.8236, dcos 0.731, chain 0.8006, no refusal = s0m / s16
  at layer 1 with every margin kept. Screen `o16`: iso cos 0.717, dcos 0.406,
  chain 0.684 (WORSE than native: the int8 o class is not the lever as
  wired). `sh7o16` running.
- 23:01 UTC: enqueued `b6_l1_sh7_T128` after b6-sink2: sh7 at T=128 (B5
  T=128 statistics + profile, held-out 9 licence + 6 FineWeb as the T128
  export, words checked against `export/llama3_8b_pg_rot1_b6_T128`; no
  export; marker `logs/b6_sh7T128_chain.done`), to test the fix at the export
  length, where s0m is infeasible.
- 23:01 UTC: screen `sh7o16` = `o16` at layer 1 (iso 0.717, dcos 0.406).
  The o16 screens are INVALID, not negative: layer-1 AO rel err is exactly
  1.000 (integer AO output all zero) because the profile's run-level SH_AO 3
  was not re-solved for SH_O 1 (o 2^8 larger); attention contributed nothing.
  (Their internal site errors, o 0.69 vs 1.45, hint the o class matters;
  untested.)
- 23:03 UTC: `b6-sink2` DONE (121 s; `runs/b6_sink_layer1.json`, signed):
  layer 1's score range is set by NEGATIVE scores: max positive raw 61.7
  (calibration) / 57.4 (held-out), BOS column max 43.9 / 43.2, diagonal 29.5 /
  29.9; most negative -223.4 / -229.9 (causal region -223.4 / -227.6).
  Negative scores that far below the row max contribute exp ~ 0 to the
  softmax, but the symmetric int8 class must hold them -> e_s 2. A
  positive-side range alone would allow e_s 0 (61.7 x 1.25 / 127 < 1).
  `b6_l1_sh7_T128` started 23:03:08.
- 23:05 UTC: sh7 at T=128, layer 1: e_s 2, SH_S 7: iso cos 0.841, dcos 0.753,
  chain 0.800, no refusal (native T128 export on the same sequences: 0.768 /
  0.670 / 0.733). B6_REPORT.md drafted (all sections; sh7-T128 whole-model
  numbers pending).
- 23:10-23:21 UTC: session stopped (coordinator resumed 23:21); the detached
  sh7-T128 job kept running.
- 23:43 UTC: `b6_l1_sh7_T128` DONE (`logs/b5-b6_l1_sh7_T128.*`, run
  `runs/llama3_8b_pg_rot1_b6l1sh7_T128`; 2403 s, peak RSS 3.32 GiB, shared
  box n=1; other layers' words identical to the T128 export). Against the
  T128 export (same calibration, same held-out seqs): FineWeb 6 seqs top-1
  0.651 -> 0.673, ppl 17.97 -> 15.48 (float 9.72), KL 0.607 -> 0.496;
  licence 9 seqs 0.633 -> 0.663, ppl 9.59 -> 8.94 (float 3.71), KL 0.968 ->
  0.879; 0 refused.
- 23:43 UTC: B6 COMPLETE. `B6_REPORT.md` final (plain words, exports, layer-1
  diagnosis + options + native costs, recommendation = per-layer SH_S for
  layer 1 (SH_S 7), T=512 laptop-vs-Mac arithmetic). `runs/b6_l1_summary.json`
  refreshed. Every chain marker present (b6r_serial, b6-sink, b6_s0m_chain,
  b6_screens_chain, b6-sink2, b6_sh7T128_chain); guard status lists no job of
  mine. NEXT: native lane decides whether `sh_s` can become a per-block key;
  if yes, re-export T32/T64/T128 with layer 1 at SH_S 7 (+ verifiers).

## B7 (coordinator: native R6 supports per-layer sh_s), from 2026-10-18 00:5x UTC

- Brief: exports `llama3_8b_pg_rot1_b7_T128` FIRST, then `_b7_T64`, `_b7_T32`:
  b6 calibration + profile decisions (B5 T=128 statistics), layer 1 at SH_S 7
  (l1-mode sh7), all other layers 6. Format: profile_constants.sh_s null;
  per_layer_constants_differ ["exp_e_s", "sh_s", "silu_member"]; each layer
  manifest constants.sh_s (layer 1 = 7, others 6); manifest sha256s
  recomputed; x_out from the integer chain with layer 1 at SH_S 7. The driver
  produces exactly this with `--l1-mode sh7 --export` (layer_constants
  carries sh_s; the profile nulls keys that differ and lists them sorted;
  manifest sha256 taken from the written manifest). Added
  `b7_check_format.py` (asserts the three format rules + uniform keys;
  negative-tested on b6_T128: 3 errors as expected).
- 00:54 UTC: launched `logs/b7_serial.sh` detached (stdout
  `logs/b7_serial.out`, marker `logs/b7_serial.done`): b7_T128 export
  (need 3.5 / cap 4.5; --link-from b6_T128 for byte-identical files only;
  --check-against b6_T128) -> verifier + format check -> marker
  `logs/b7_T128_stage.done` -> b7_T64 (calib 128, link from b7_T128) ->
  verify -> b7_T32 (calib 128) -> verify. b7_T128 started 00:54:09.
- 01:41 UTC: b7_T128 DONE and VERIFIED. `export/llama3_8b_pg_rot1_b7_T128`,
  profile.json sha256 040eb5cfa3e21634e8e13c9a00a108b301231af456bd3c539ac725c7f6269a6e
  (run `runs/llama3_8b_pg_rot1_b7_T128`, `logs/b5-b7_T128.*`; 2572 s, peak
  RSS 3.28 GiB, shared box n=1). Format check ok (`logs/b7-format-*.json`:
  sh_s 7 at layer 1, 6 elsewhere; sh_s null in profile_constants; differ list
  exact). Verifier: 32/32 layers bit-exact on seq_ho00 and seq_ho09, 0 errors
  (255 s, 2.00 GiB). Every other layer's words identical to b6_T128.
  442 files hard-linked (byte-identical to b6: 31 layers x 14 incl. RoPE
  tables and identical manifests, + 8 layer-1 files); layer 1's own new
  files: wq, wk, wv, wo, gamma_a, manifest. Held-out: FineWeb top-1 0.673,
  ppl 9.72 -> 15.48, KL 0.496; licence 0.663, 3.71 -> 8.94, KL 0.879;
  0 refused. Coordinator messaged. b7_T64 started 01:41:16.
- 01:43 UTC: COORDINATOR HOLD #3 (arrived after T64 had started): hold b7
  T64/T32 until the privacy gate's L22 chain finishes
  (`results/zk60_gate_tinyllama_20261017/r5b/light_queue.finished` exists and
  no `tl-r5b-l22-*` live) or 05:30 UTC. T64 is in flight (cannot be stopped:
  kill refused, guards never killed); its verifier runs straight from the
  queue after it (no hook). T32 and every later job go through the again
  atomically replaced `logs/b5_run.sh`, which polls `logs/b7_hold3.py`
  every 60 s (tested: held). Coordinator told.
- 01:43 UTC: NEW TASK queued after b7 T64/T32 and the hold: 8B token I/O
  artifacts (R3 rung) for b7_T32 and b7_T128 under `export/<name>/token_io/`:
  int16 embedding table (rotated, at s_in, checked against every x_in_L00),
  folded head lm_head diag(norm) R^T with per-row int8 + 12-bit multipliers
  (D25 T4 as amended), final-norm Cn/Ceps (tn 9), F2 fidelity (integer vs
  float head; overall, top-2 margin >= 0.3, ties, max logit bits vs 56).
  Reading the TinyLlama R2 format and the fidelity lane's s4_head first.
- 01:50 UTC (smoke end 01:50:56): wrote `b8_token_io.py` (modes build / reuse): (1) embedding
  table = TOKEN_IO_SPEC steps 1-3 at the export's s_in, checked against every
  exported seq's x_in_L00 (and its x_out_L31 == the run's chain) and the run's
  whole held-out x_L00 chain (ids regenerated, digests checked against the
  run's metadata); (2) W' = lm_head diag(norm) R^T float64, per-row int8,
  m_j = max(1, floor(2^12 s_j / max s + 0.5)); final norm by the calibration
  rule (norm_site c = 1 on the rotated xhat maxima of the calibration set's
  final residual, float forward in the rotated basis, margin 0.5, tn 9, Ceps
  asserted = profile; cached under runs/); refusal-free Cn = 2^tn beside it;
  (3) F2 vs the TOKEN_IO_SPEC float head on the same integer stack output
  (overall / margin >= 0.3 / domain / last position, refusals, ties, raw and
  scaled logit bits, keyed delta vs the 56-bit window [COUNTED: bits(2^17 x
  2 x 4096 x 127^2 x 2^12 + V - 1) = 56]). Files under
  `export/<name>/token_io/`: embedding_int16.bin, head_int8_perrow.bin,
  head_mult12.bin, calib_final_xhat_rot_absmax.bin, token_io.json,
  head_manifest.json, f2_fidelity.json, SHA256SUMS (README added after).
  Unguarded smoke on a 16,384-row vocab subset (49 s, peak RSS 1.25 GB;
  scratchpad b8_smoke.py): table formula = run x_L00 on all 1,629 positions
  with ids < 16384; head subset 0 clipped, 0 -128; Ceps 78617 = profile;
  final_norm == i_norm; F2 machinery ok (window 56).
- 01:51 UTC: launched `logs/b8_queue.sh` detached (stdout `logs/b8_queue.out`,
  marker `logs/b8_queue.done`): waits for `logs/b7_serial.done`, then hold #3,
  then guarded `b8-tio-b7_T128` (build; need 4 / cap 5), hold #3 again, then
  `b8-tio-b7_T32` (reuse: hard links of the byte-identical shared files;
  need 3 / cap 4).
- 02:15 UTC: b7_T64 DONE and VERIFIED. `export/llama3_8b_pg_rot1_b7_T64`,
  profile.json sha256 02261f3b4b318f56f9918255a36442948f273b5f17b4e29ba7f7d59210763f2a
  (`logs/b5-b7_T64.*`; 1864 s, peak RSS 2.99 GiB, shared box n=1; other
  layers' words identical to b6). Format check ok (sh_s 7 at layer 1 only).
  Verifier: 32/32 bit-exact on seq_ho00 and seq_ho09, 0 errors (177 s,
  1.69 GiB). Held-out: FineWeb top-1 0.680, ppl 12.59 -> 19.01, KL 0.433
  (b6 T64: 0.630 / 23.21 / 0.581); licence 0.656, 5.84 -> 13.08, KL 0.819
  (b6: 0.628 / 13.46 / 0.911); 0 refused. b7_T32 now held by hold #3 (the
  gate's tl-r5b-l22-dense-t is live).
- ~03:17-04:21 UTC: session stopped (usage limit) while holding; resumed
  04:21. Checked 04:23: both detached queues alive (one-shot `ps` by elapsed
  time): `b7_serial.sh` (etimes 12,540 s) inside `b5_run.sh b7_T32`'s hold-3
  poll (7,672 s), `b8_queue.sh` (9,103 s) waiting for `b7_serial.done`.
  Nothing restarted. Gate's last pass `tl-r5b-l22-zero-f` live since 03:38;
  release at its end (light_queue.finished + no tl-r5b-l22-* live) or 05:30.
- 04:38 UTC: hold #3 released by its condition (gate L22 chain finished;
  `light_queue.finished` present, no tl-r5b-l22-* live). `b5-b7_T32` started
  04:38:39 (layer 1 SH_S 7: iso cos 0.846, chain 0.804, 0 refused at L1).
  Then: T32 verifier + format check -> `b7_serial.done` -> b8 token I/O
  (T128 build, then T32 reuse). T64 verifier already ran (02:15).
- (from the logs; session was cut off 10-18, box rebooted 21:29 UTC, resumed
  2026-10-19 09:25) 05:07 UTC 10-18: b7_T32 DONE (1737 s, peak RSS 2.86 GiB):
  `export/llama3_8b_pg_rot1_b7_T32`, profile.json sha256
  209b07ac78baa3f3ebae0ca40cd1807c3d7098549818c50f6a15691906c0013c; other
  layers' words identical to b6; held-out FineWeb 6 seqs top-1 0.661, ppl
  16.99 -> 27.51, KL 0.463; licence 9 seqs 0.656, 12.44 -> 23.90, KL 0.700;
  0 refused. Verifier 32/32 bit-exact on seq_ho00 / seq_ho09, 0 errors
  (146 s, 1.58 GiB); format check ok (sh_s 7 at layer 1 only).
- 05:31 UTC 10-18: `b8-tio-b7_T128` DONE (1263 s, peak RSS 2.72 GiB):
  `export/llama3_8b_pg_rot1_b7_T128/token_io/` (8 files + SHA256SUMS).
  Embedding table sha256 8b5a5fb1...; head rows f50ba1aa...; multipliers
  9eafb7f4... (m_j in [859, 4096], 2304 distinct; 0 clipped, 0 -128).
  Final norm g0 127, tn 9, Ceps 78617 (= profile), Cn 4234 (calibration
  rule; calib xhat' max 5.159), refusal-free 512, window 32. Checks: table =
  x_in_L00 of seq_ho00/seq_ho09 and the whole held-out chain (15 x 128);
  final_norm == i_norm. F2 (1920 positions): 99.06% overall (1902/1920),
  100% at float margin >= 0.3 (1576/1576, D25 T4 MET), 0 refusals, 0 ties,
  max |raw logit| 640,767 (20 bits / class 26), scaled 30 bits, keyed delta
  48 of 56 bits, strict; all 18 misses at float margin < 0.3.
- 05:32 UTC 10-18: `b8-tio-b7_T32` DONE (39 s, 2.43 GiB): token_io/ with the
  4 shared files hard-linked (same sha256s); F2 (480 positions): 99.79%
  (479/480), 100% at margin >= 0.3 (371/371, MET), 0 refusals, 0 ties, raw
  20 bits, keyed delta 48 of 56; the one miss at float margin 0.03-0.1.
- 09:26 UTC 10-19: both SHA256SUMS re-verified after the reboot (16/16 files
  match). Head manifest keys = the R2 manifest's (+ informational extras;
  only R2's `seconds` absent). All markers present; nothing of mine running.
  B7 + B8 COMPLETE.
