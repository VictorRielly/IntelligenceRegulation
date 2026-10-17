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
