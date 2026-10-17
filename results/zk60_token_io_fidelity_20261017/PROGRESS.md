# Lane TOKEN-HEAD FIDELITY, 2026-10-17 — progress ledger

Owner: token-head fidelity lane (Claude agent). Writes only under
`results/zk60_token_io_fidelity_20261017/`. No git writes. Times UTC from
`date -u`. Python only; every job over 1.5 GiB or a minute of several cores
runs through `scripts/zk60_resource_guard.py` as class `light` with a declared
need, detached, with a `.done` marker under `logs/`.

Scope (brief): F1 build the integer final norm + int8 LM head exactly as
`results/zk60_token_io_design_20261017/DESIGN.md` sections 3 / 6.3 state; F2
top-1 agreement of the integer head vs the float head on the same integer
stack output (T32 and T128 held-out), plus both vs the float model; F4 prefix
consistency of the integer stack. Calibration data, not a proof, not a privacy
claim.

## Inputs (read-only)

* exports `results/zk60_1b_calibration_20260929/export/pg_rot1_b4_{T128,T32_cal128,T64_cal128}`
  (one weight set, hard-linked; profile constants Cn_a 3583, Cn_m 2873, Ceps 74429, tn 10; s_x 5.2456e-4);
* model `~/models/tinyllama-1.1b-chat-fe8a4ea1/model.safetensors` (`model.norm.weight`, `lm_head.weight`);
* tool copies in `tools/` = the B4 export snapshot `tool_snapshots/b4_exports_20261017`
  (sha256 equal to the export profile's `calibration_tool`): tlcalib d42a8647..., b3calib 637cd418...,
  corpus 273e4ef4..., corpus4 1b3b08ca..., spm_bpe 26f8be84...; plus b4_token_io.py f51bce4f... (current tree).

## Log

- 19:02 UTC: lane opened. Read LANE_RULES_20261017.md, TOKEN_IO_SPEC.md, DESIGN.md sections 3, 4.4, 6, 7,
  the calibration PROGRESS.md, b3_verify_export.py, b4_token_io.py, tlcalib/b3calib (norm, i_block, norm_site,
  choose_norm, Rotation), b3_ladder (corpus, head metrics). Copied the tools (above). Guard status at 19:0x:
  r5-suite (cpu, 4.5G) and b5-b6r_T64 (light, 4G) live; 8.5 of 11.89 GiB committed.
  Plan: s1 tokens (both T + calibration set), s2 float model (calibration xhat stats for the final-norm Cn;
  held-out final residuals), s3 integer stack on all 72 held-out sequences at T128 and T32 from the export
  binaries (bit-exact check on the exported ho00/ho36), s4 head analysis (F1/F2), s5 prefix consistency (F4).
- 19:05 UTC: first s1 attempt failed (exit 1: the snapshot tlcalib derives the importer path from its own
  location, two levels up; the copies sit one level deeper). Fixed in `tools/fid_common.py` (puts
  `results/zk60_1b_checkpoint_20260927` on sys.path; tlcalib's REPO constant is otherwise unused here).
  Failed-try logs kept in `logs/failed/`. All scripts set `sys.dont_write_bytecode` (no __pycache__ in
  read-only trees).
- 19:05 UTC: s1 DONE (`logs/s1_tokens.*`, exit 0): calibration set 108 x 128; held-out 72 x {128, 64, 32}
  (36 licence/docstring + 36 FineWeb-Edu each); the exported sequences' token ids (seq_ho00 = index 0,
  seq_ho36 = index 36) equal the rebuilt sets at all three T.
- 19:06 UTC: s2 (float model; calibration xhat' stats + held-out final residuals) launched (`logs/s2_float.*`).
- 19:10 UTC: s3 T32 DONE (`logs/s3_int_T32.*`, exit 0, 196 s, peak RSS 0.69 GiB): integer stack on all 72
  held-out T32 sequences, 0/72 refused, x_out_L21 of seq_ho00 and seq_ho36 bit-exact with the export.
- 19:10 UTC: s3 T128 (`logs/s3_int_T128.*`) and s5 prefix consistency (`logs/s5_prefix.*`) launched.
  s4 (head analysis) waits for s2 + s3 T128.
- 19:13 UTC: s5 (F4) DONE (`logs/s5_prefix.*`, exit 0, 141 s, peak RSS 0.99 GiB; `data/s5_prefix.json`):
  held-out T128 sequences 0, 1, 36, 37: every layer's output at positions < T' is IDENTICAL between the
  T128 run and the T64 / T32 prefix runs (exports T64_cal128 / T32_cal128, same weights); with positions
  64..127 replaced by other sequences' tokens (253 of 256 tokens changed) every layer's output at positions
  < 64 is identical, while 524,155 of 524,288 L21 words at positions >= 64 differ (control). No refusals.
- 19:19 UTC: s2 DONE (`logs/s2_float.*`, exit 0, 775 s): calibration (108 x 128) rotated final-residual
  xhat' max 5.454 (per-position max: median 3.54, p99 4.49); unrotated xhat max 37.5 (the rotation is what
  makes an int8 final norm reasonable). Held-out float final residuals saved (T128, T32).
- 19:20 UTC: coordinator instruction ACKNOWLEDGED: let the privacy gate's `tl-v4-l22-dense-f` (light, 6 GiB)
  through — no new guarded job declaring > 1 GiB until `status` lists it live or 20:30 UTC, whichever first.
  s3 T128 (already running) finishes normally; s4 (needs ~2-3 GiB) is held until then.
- 19:20 UTC: s3 T128 DONE (`logs/s3_int_T128.*`, exit 0, 584 s, peak RSS 1.34 GiB): integer stack on all 72
  held-out T128 sequences, 0/72 refused, x_out_L21 of seq_ho00 / seq_ho36 bit-exact with the export.
  Nothing of mine running now; s4 waits for the gate job's admission (see 19:20 entry).
- 19:22 UTC (unguarded, < 0.5 GiB): held-out integer x_out_L21 rotated |xhat'| max 5.30 (T128) / 4.79 (T32),
  below the calibration max 5.45; max |x| 10,893 of 32,767.
- 19:48 UTC: `tl-v4-l22-dense-f` listed live by `status` (admitted 19:48:34) -> hold released.
- 19:49 UTC: `logs/s4_chain.sh` launched detached: guarded s4 smoke (T32, 2 chunks, `*_smoke` outputs),
  then the full s4 only if the smoke exits 0 (need 2.5 / cap 3.5 GiB, light; markers `logs/s4_smoke.done`,
  `logs/s4_head.done`; 99 in s4_head.done = skipped after a smoke failure).
- 19:55 UTC: s4 smoke DONE (exit 0, 41 s): selftests pass (final_norm == tlcalib.i_norm; keyed argmax ==
  numpy first max on 800 forced-tie vectors); fold check: rotated float head vs spec float head top-1 1.0,
  max |logit diff| 1.6e-5 (W' = lm_head diag(nw) R^T is right).
- 20:00 UTC: s4 full DONE (`logs/s4_head.*`, exit 0, 313 s; `data/s4_head.json`, `data/s4_positions.npz`,
  tables `data/s6_tables.md`). Final norm g0 127, Cn 5664, Ceps 74429, tn 10. Pooled 11,520 positions:
  per-tensor int8 head vs float head 98.45 % (T128 98.50, T32 98.26); per-row (float scales) 98.91 %
  (T128 99.00, T32 98.52); per-row 12-bit integer multipliers 98.88 %, 8-bit 98.19 %. 0 refusals, 0 integer
  ties, max |l| 181,485 (17.5 bits), keyed delta 33 bits (window 41). Every disagreement sits where the
  float head's own top-2 margin is < 0.3 logits.
- 20:02 UTC: s7 decomposition run 1 DONE (exit 0; kept as `logs/s7_decomp.run1.*`, `data/s7_decomp.run1.json`):
  exact y + per-tensor W 98.76 %, exact y + per-row W 99.55 %, int8 y + float W 98.94 %, int16 y + per-tensor
  W 98.78 %, int16 y + per-row W (float scales) 99.56 % (pooled).
- 20:04 UTC: s7 extended (int16 y with 12-/8-bit integer row multipliers, measured + worst-case keyed
  windows) relaunched (`logs/s7_decomp.*`).
- 20:11 UTC: s7 run 2 DONE (exit 0, 130 s, peak RSS 1.71 GiB; `data/s7_decomp.json`): int16 y + per-row W with
  12-bit integer multipliers 99.57 % pooled (T128 99.60, T32 99.48); 8-bit 98.46 %. Worst-case keyed windows
  [COUNTED]: int8 per-tensor 41, int8 per-row 12-bit 53, int16 per-tensor 49, int16 per-row 12-bit 61 bits
  (measured 33 / - / 39 / 51). Paired per-row vs per-tensor: 112 positions fixed, 60 broken.
- 20:13 UTC: lane FINISHED; nothing of mine is running or queued (`status` lists no `fid-*` job; every
  `logs/*.done` holds 0). The harness refused to let this agent write `REPORT.md` (subagent report files are
  blocked); the full report text went to the coordinator in the hand-back, and every number in it is in
  `data/s4_head.json`, `data/s6_tables.md`, `data/s7_decomp.json`, `data/s5_prefix.json`, `data/s3_int_T*.json`.
  Result: per-tensor int8 head 98.45 % vs float head (misses 99 %); per-row 98.91 % (12-bit multipliers
  98.88 %); per-row + int16 final-norm output 99.57 %; all misses at float-head margins < 0.3 logits; 0
  refusals, 0 ties, max |l| 17.5 bits, keyed delta 33 of 41 bits; F4 prefix consistency exact.
  Next concrete step: Victor's R4 ruling (keep 99 % and adopt int16 y + per-row, or restate the criterion);
  then F3 (greedy continuations) and F6 (right-padded hidden-selector inputs), not run here.
