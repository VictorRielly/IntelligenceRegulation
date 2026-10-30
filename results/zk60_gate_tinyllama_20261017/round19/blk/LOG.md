# Gate round 19, block-port sub-lane log (R13 block stages)

- 11:39 UTC started (fork of the lane agent). Goal: block-stage gate at R13 accuracy shapes; entry
  point `zk60_native_rg_r13blocks.r13_block_terminals`. Not a privacy acceptance.
- ~11:50 UTC (time from the next clock reading, 11:55) [MEASURED, dev, in-process] `zk60_native_rg_r13blocks.r13_block_terminals` on
  `classify-r13-rung-L2-v1` (2 stages, G 20 / 21): **23 / 23 slots equal at both stages** (the seven
  R13 ports DZC / QZC / KVZC / SZC / FZC / TAB written from argument_accuracy.rs, plus the 16 legacy
  bodies through a name alias A_Q8->A_Q etc.), plane index ok, the R13 plane list (109 A planes) equal
  to the independent AccuracyIds port, source pins ok (R13 digests added with readings), group factor
  ok; ~0.8-0.9 s per stage. The R13 calibration line and every stage's G are bound: the CLASSIFIER
  schedule digest (classify.rs `schedule_digest`, domain "hashline/classify-run-schedule/v1") recomputes
  from run.json's lines plus the gate's own IN-C / OUT-C StageLayout lines. One fix on the way: the
  legacy SC_LZC read `lookups_at` (legacy limb counts -> a negative pin shift); the R13 Dom::L lookups
  are now supplied (= LIMB, LIMBM bytes).
- Controls (each predicted, then fired, 7 / 7): G +1 -> exactly slot 18; precision.score +1 -> 17;
  norm tn' +1 -> 14; one group id +1 (digest recomputed) -> 18; one ACT3 entry +1 -> 19; fold(w_g)
  entry +1 -> 11; the legacy FZC body on R13 bytes -> refused at 18.
- 11:56-12:00 UTC [MEASURED, dev, in-process, 213 MB peak] all 13 R13 rung captures (L1 v1; L2 v0 / v1 /
  vtie; the 27-id item's two chunks; short n = 1 / 11 x 3 verdicts, n = 22 v1): 23 / 23 per stage at G 20
  (and 21 at L2), 7 / 7 controls fire on each, ~10 s per capture with controls; the legacy rung capture
  `classify-rc3-rung-L2-v1` delegates to `class_block_terminals` and passes 23 / 23 per stage with NC-1.
- 12:01:31 UTC guarded dev on the REAL Shieldstral capture, block 0 only (light 2.5 / 3.5): **it overlapped
  the lane agent's gate19-real-dev-2 (cpu 6.5 / 8, started 12:01:06) -- a lean-rule breach on my side**
  (my status read at ~11:59 showed the box idle; the lane agent's warning arrived after the launch).
  Reported to the lane agent at once; not signalled (rules); it ended by itself: exit 0, 27.4 s, peak
  RSS 1.38 GiB (cgroup 0.63). Result [MEASURED]: block 0 (G 19, own constants sh_s 7, cn_a 848, cn_m 1716,
  sh_ao 8, sh_h 16): the 11 table-free slots 0-4, 8, 9, 17, 20-22 EQUAL in 5.1 s; plane index ok (107 A
  planes: 2 sigma limbs at wrho_s 16), the R13 plane list equal to the port, source pins ok, classifier
  schedule digest recomputed equal, the export's constants equal the transcript-bound line (per-layer
  fields excepted). The capture carries NO public-table values (lane agent's option), so the other 12
  slots need their tables. Nothing else will be run on the real capture by this sub-lane.
- 12:02-12:04 UTC no-tables path (lane agent's request): slots 5-7, 10-16, 18, 19 OPEN per slot with the
  capture-option reason; `tables_absent_by_capture_option`, `slots_covered_without_tables`,
  `ok_on_the_covered_slots`; `ok` is False whenever tables are absent (never a full pass). Tested on rung
  captures with their values stripped in memory: 11 / 11 per stage, controls NC-1 (score precision -> 17)
  and NC-2 (ceps -> 2) fire; the six table-needing R13 controls listed as not applicable.
- 12:05-12:10 UTC [MEASURED, dev, in-process] final code: the 13 R13 rung captures 23 / 23 per stage and
  7 / 7 controls each (`dev_summary.json`, peak 213 MB, 8-10 s per capture with controls, ~0.8-0.9 s
  per block stage without); legacy `classify-rc3-rung-L2-v1` and `-L1-vtie-short20` delegate, 23 / 23 +
  NC-1; no-tables path on L2-v1 (values stripped in memory): ok false by design, 11 / 11 covered,
  NC-1 / NC-2 fire (`dev_notables_final.log`); staging suite 97 OK (`suite-staging-v22-blk-final.log`).
  Generic parts at the R13 rung (classgate functions on `classify-r13-rung-L2-v1`, unchanged code):
  hash layer ok; per commitment A 0 / H 2 / B 0 = expected; masking 0; CFS ok; joint 0 over 33,312
  pairs; full preimage 2,246,541 entries, 0 differing, **641.5 s** (legacy L2: 165 s).
- Files: zk60_native_rg_r13slots.py 09878d5e (new), zk60_native_rg_r13blocks.py f4ef6373 (new),
  zk60_native_rg_terminals.py 43eed070 -> 094029b7 (R13 pin readings; weight_fold@heads length q_pad),
  zk60_native_rg_gqa.py 24e9b963 -> 1d540c53 (argument.rs bc0332e3 = the repaired definition).
  Remove staging_v22/scripts/__pycache__ before the freeze.
