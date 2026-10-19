# G-7 sub-lane (privacy gate): NL-1 and the terminal surjection at the TRAINED slot-IR export

**Nothing in this directory is a privacy acceptance.** It is a machine check
of two algebraic steps (NL-1's `nl_check.py` stages and the terminal-surjection
computation of `ZK60_TERMINAL_SURJECTION_REVIEW.md`) at the trained TinyLlama
T32 layout (pg_rot1), where four lookups (RQL, RKL, RVL, RGL) are duplicated
at sh_qkv = sh_g = 8 (draft §7 row G-7, §3 step 4 item (e)). Only the security
review process can accept; rulings are Victor's.

Brief: delegated by the privacy gate lane. Rules: `ops/zkp-mvp/LANE_RULES_20261017.md`.
Write set (exclusive): `ops/zkp-mvp/trained-1b-gate-g7/` and this directory.

## Ledger (UTC, from `date -u`)

- 2026-10-18 04:43 UTC: first start; read the lane rules, the draft's G-7 row,
  `nl_check.py`, the surjection review, R5b's `slot_ir.rs` / `slot_ir_tests.rs`.
  Cut off by the usage limit at about 04:50 UTC before anything was written.
- 2026-10-19 09:29 UTC: resumed (coordinator message 09:27 UTC; the box
  rebooted 2026-10-18 21:29 UTC). Write set absent, created now. Guard status:
  heavy lock held (`r7-check`, cpu, 4 GiB), 4.0 of 11.89 GiB committed.
- 09:31 UTC: `ops/zkp-mvp/trained-1b-gate-g7/` = rsync of R5b's frozen tree
  excluding target dirs; **218 of 218 files equal the manifest**, none missing,
  none unlisted (`copy_verify_g7.json`, `tree_tools.py verify`).
- 09:32 UTC: R5b carries stage 34 (`slot_ir.rs`, `slot_ir_tests.rs`), so
  nothing is ported. Test-only addition: `hashline/src/private_block/
  g7_trained_slot_ir_tests.rs` (new), mounted by 5 lines at the end of
  `slot_ir_tests.rs` (`#[path] mod g7_trained_slot_ir_tests;`). Both files are
  `cfg(test)` (slot_ir_tests is `#[cfg(test)] mod` in private_block.rs); no
  pinned source changes. The ignored test reaches the shape through the
  trained door (load / run_constants over all 22 layers / shape_for), checks
  it equals `Shape::tinyllama_t32_trained(pg_calibration, 9)`, prints the
  duplicate-lookup census, builds the export twice, runs the stage-34 oracle
  (IR == closure at random points) on every trained layer's real public
  statement and requires the same export bytes there, and writes the trained
  export and the frozen twin's (`tinyllama_t32_dev`) into `g7/export/`.
- 09:33 UTC, reading the code before any run [READ]: helpers pair lookups
  `(2k, 2k+1)` (`argument.rs::helper_sum`, `slot_ir.rs::logup_subterms`);
  `sym()` is two lookups; so at Dom::Q the list is sym Q8 (0, 1), byte RQL (2),
  scaled RQL (3), ... and the duplicate byte/scaled pair lands in ONE helper
  (helper 1), likewise RKL (Kv helper 1), RVL (Kv helper 3), RGL (F helper 0).
  If the run confirms it, the duplicate is a repeated DENOMINATOR inside one
  helper relation (`h d^2 - 2d`), not two H helper planes, and the slot's
  table list (hence its terminal map) has no repeated coordinate.
- 09:34:56 UTC: `g7/queue.sh` launched detached (marker `g7/queue.done`):
  build (class build, need 3 / cap 5, label g7-build), then the export test
  (class light, need 2 / cap 3.5, RAYON_NUM_THREADS=2, label g7-export).
- 09:38-09:40 UTC: `g7/g7_nl.py` written: a wrapper that imports the frozen
  `nl_check.py` (sha256 e4db99a2..., `nl_field.py` ea8ca392..., checked before
  import; bytecode writing off so nothing lands in the frozen directory) and
  patches four attributes only (`load_shapes` + extra exports, `SRC`,
  `SHAPES_OF_RECORD`, `HERE` = output dir), then writes `g7_nl_probes.json`
  (duplicate structure read off the IR, trained-vs-twin diff, S2 parse under
  both source sets). **Fidelity control** (`g7/nl_lane_reproduction/`, nine
  lane exports, lane sources, 50 s, peak RSS 29 MB [MEASURED, shared box, n=1]):
  summary, S0, S1, S2 budgets, S3, S4 (miniatures and terminal pairs) and S5
  all EQUAL to the frozen `nl_check.json`; S2 sources differ only in line
  numbers (the lane's layout.rs / argument.rs / shape.rs moved after
  2026-09-23; IR digests unchanged). The S2 parse of the g7 (R5b) sources
  equals the lane's parse, line numbers aside (kinds, hosts, the two
  non-zero extension-round pushes, the helper defaults).
- 09:40 UTC: build still queued behind the heavy lock (r7-suite, cpu 4.5 GiB).
- 09:41-09:44 UTC: `g7/ts_trained.py` written: imports the frozen
  `ts_review.py` (6fffaed1...), `ts_field.py` (aee16c59...) and checks
  `ts_components.py` (6c1f8c74...); reuses Role / zpart / zkey / group_claims,
  stage 0 and stage 1 unchanged with N_COLS = 4096, LOG_COLS = 12 (the trained
  rows are 2^12 wide; the review's captures 2^8). Restated (one change each):
  stage 2's `group_system` / `annihilator` (claim columns at 2N + 2k instead
  of the literal 512 + 2k, which would collide at N = 4096); "disclosed" by
  the null-space form (rank{Phi(g)} over streamed data generators, Phi = the
  functionals vanishing on every blinding generator) so that ~10^7 data
  generators are never stored; ts_components' joint system in the same form.
  Adds: a 5-run bundle loader (arrays resolved from arrays.bin, each checked
  against its SHA-256 name), the PCS-level G-7 census (identical claims,
  equal published values, same data weights in one group), the review's
  controls C1/C2/C3/C6/C8 on a two-member A group, and G-7 probes D1 (insert
  a duplicate claim with its own reserved pair), D2 (an exact copy: two
  identical coordinates), D3 (control: a copy sharing the pair with one data
  weight changed).
- 09:44 UTC: **fidelity control** at the review's own width and captures
  (`g7/ts_fidelity/`, 31 s, peak RSS 144 MB [MEASURED, shared box, n=1]):
  176 per-group rows (every group of every role of the four 2026-09-19
  captures) — blinding rank, disclosed, surjective, annihilator-kills-data
  all EQUAL to `ts_review.json`, and the null-space form equals the original
  form (blinding then data in one eliminator) at every group, 0
  disagreements; H's joint component {7, 8} / {6, 7}: blinding rank 1,022,
  disclosed 2, equal to `ts_components.json`.
- 09:45:08 UTC: `g7/ts_queue.sh` launched detached (marker
  `g7/ts_queue.done`): ts_trained on the R5b trained captures dense-l1,
  zero-l1, dense-l2 (class light, need 1.5 / cap 3, label g7-ts). The build
  queue still waits for the heavy lock (r7-suite).
- 09:46 UTC: `g7/g7_nlc.py` written (supplementary): the parts of NL-1's
  ADVERSARIAL check that the NL-1 disposition rests on, by calling the frozen
  `nlc_check.py` (486ecfbd..., `nlc_field.py` 3168dcc6...) functions directly:
  K3 source parse, K1 symbolic monomial expansion, K2 counts, K5 host
  coupling (six hosts, real kinds). **Fidelity anchor at m125**
  (`g7/nlc_m125_anchor/`, 0.4 s): K1 rows and the six K5 host rows EQUAL to
  the frozen `nlc_check.json`; the K3 parse of the R5b sources equals the
  lane's on every field (13 pushes, the two non-zero extension rounds,
  helper defaults, kinds, hosts, bilinear order).
- 09:46 UTC: the ts job has passed stage 1 on all seven stage files of the
  three trained bundles with **no finding** (A 120 pairs exactly (cm, cm U),
  H 50, cm != 0, no zero lambda, cw != 0, 0 group-identity failures, 0
  rho-combination failures) and is in stage 2. Build still waits for the
  heavy lock.
- 09:50 UTC: ts, first trained capture (dense-l1, stage 00) done in 305 s
  [MEASURED, shared box, n=1]. **A: 36 groups, 36/36 surjective, rank
  2(4096+m)-2 at every group (8,192 at m = 1 ... 8,260 at m = 35), the
  annihilator kills every blinding and data generator, disclosed 0.**
  **H: 9 groups, 8/9 surjective; group 8 (one claim, the LogUp sum on the
  zero-sum pair) rank 8,190 of 8,192, disclosed 2; joint component {7, 8}
  (u rows 1696/1697): 16,388 observations, blinding rank 16,382, with data
  16,384, disclosed 2** — the same structure as the review's toy figures
  (1,028 / 1,022 / 1,024 / 2). Input, Output: surjective, disclosed 0. The
  null-space form agreed with the original form at all 16 small groups where
  both ran. **PCS-level G-7 census: no identical claims, NO TWO EQUAL
  PUBLISHED CLAIM VALUES in A (120), H (50), Input, Output**, no two claims of
  one group on the same data weights.
- 10:01:14 UTC: g7-build exit 0 (waited 1,414 s for the heavy lock; cargo
  2 min 44 s; peak RSS 1.79 GiB [MEASURED, shared box, n=1]); test binary
  `hashline-3e8a1475e1d05930` sha256 f24e1d1f... (`hashline-lib-test-release.g7.sha256`).
- 10:01:19 UTC: g7-export exit 0 (`g7-export.log`, 5.5 s, peak RSS 0.26 GiB
  [MEASURED, shared box, n=1]). The trained door gives the pg_rot1 shape
  (22 layers, profile `.../private-block-tinyllama-1.1b-t32-trained/1`,
  tn 10, Cn_a 3999, Cn_m 3122, Ceps 91,255, sh_qkv 8 / s 6 / o 9 / ao 3 / g 8 /
  h 14 / z 5, norm_wrho 32, f_e 9), equal to
  `Shape::tinyllama_t32_trained(pg_calibration, 9)`. **Duplicate census
  [MEASURED]: 4 identical lookup pairs at the trained shape, 0 at the frozen
  twin (sh_qkv = sh_g = 7): F lookups 0/1 (A_RGL), Q 2/3 (A_RQL), Kv 2/3
  (A_RKL), Kv 6/7 (A_RVL); every pair lands in the SAME helper (F helper 0,
  Q helper 1, Kv helpers 1 and 3).** Helper counts equal to the twin's (L 1,
  D 17, F 5, Q 7, Kv 6, S 7). Oracle: 22 layers x 23 slots, 4,048 random
  points, IR == closure on each layer's real public statement; the export
  built on every layer equals the shape's (twice-built, canonical).
  **Trained export `g7/export/slot_ir_tl_t32_trained_pg_rot1.json`, 100,323
  bytes, sha256 a63b3f35b1c010528755dc0cc0e53b9300179f0148aa35689f4b6fb2b5683239**;
  twin `slot_ir_tl_t32_dev.json`, 100,319 bytes, sha256 cef02f11...
  PUBLIC data only: no witness is built in the test; no table payload, claim
  point or challenge value is written (challenge coefficients by provenance).
- 10:03 UTC: **NL-1 at the trained export** (`g7/nl/`, g7 sources, 11
  exports, 45.8 s, peak RSS 31 MB [MEASURED, shared box, n=1]):
  S1 premise 23/23, public factor in every monomial 23/23, degree fits 23/23
  (max declared 5), supp slots 3, group-eq slots 2, Sigma L 979 / dim C 956 /
  ker 23, worst L 97 at slot 18 (97 + 256 <= 512); S3 Fact 2.1 230/230 (46
  (N, d) pairs; four new: (14,2), (16,3), (17,3), (19,5)); S4 miniatures 23/23
  with the Private-Gamma control firing 23/23; S4 terminal map onto Fp2^m
  23/23 (slots 15 / 16 / 18: m = 15 / 13 / 17, Fp-rank 30 / 26 / 34); S5
  controls 12/12. S1 rows of the trained export equal the twin's at 23/23.
  Probes: logup relations with two identical denominators at slots 15
  (logup[Q:1], helper H[19]), 16 (logup[Kv:1] H[26], logup[Kv:3] H[28]),
  18 (logup[F:0] H[39]); **repeated terminal coordinate: none; repeated
  table: none**; trained vs twin differ in coefficient VALUES only (slots 2,
  14, 15, 16, 18), same tables, nodes and terms.
- 10:04 UTC: adversarial-check parts at the trained export (`g7/nlc/`):
  K1 symbolic premise 23/23, public TABLE in every monomial 23/23, top-level
  public factor 23/23, product degree <= declared 23/23, = export 23/23, 359
  monomials, no constant monomial, no supp monomial without eq; K2 terminals
  A 120 + H 49 + EP 2 = 171 (the capture has A 120 claims, H 50 = 49 + the
  LogUp sum claim); K5 host coupling 6/6 pass (twin 6/6; m125 anchor 6/6 =
  frozen).
- 10:04 UTC: patch of the G-7 copy against R5b's frozen tree:
  `trained-1b-gate-g7-vs-frozen-r5b.v1.patch` (14,005 B, sha256 c4023db5...,
  2 files: the new `g7_trained_slot_ir_tests.rs` and +5 lines at the end of
  `slot_ir_tests.rs`); sources manifest `trained-1b-gate-g7.sources.v1.sha256`
  (219 files, sha256 3350f441...). No pinned file changed (both are
  `cfg(test)` test modules; `slot_ir.rs` untouched).
- 10:05:53 UTC: g7-ts exit 0 (1,245 s, peak RSS 0.42 GiB [MEASURED, shared
  box, n=1]; `g7/ts/ts_trained.json` sha256 624081cf..., log `ts_trained.log`).
  Seven stage files (dense-l1 s00, zero-l1 s00, dense-l2 s00 + s01), every
  one the same figures: **A 36/36 groups surjective (rank 2(4096+m)-2),
  disclosed 0; H 8/9 surjective, group 8 (the LogUp sum claim) rank 8,190
  of 8,192, disclosed 2, joint component {7, 8} on the zero-sum rows
  1696/1697: 16,388 obs, blinding 16,382, with data 16,384, disclosed 2;
  Input / Output (external 21 rows, boundary 22 rows with 2 claims)
  surjective, disclosed 0.** The annihilator (the verifier's identity)
  kills every blinding and data generator of every group. PCS census: no
  identical claims, no two equal published values, in any role of any stage.
  Controls on a two-member A group (dense-l1), null-space form = original
  form at every one: honest 8,194 / disclosed 0; C1 shared pair 8,192 /
  disclosed 2 (fires); C2 cm = 0 8,192 / 2 (fires); C3 lambda = 0 8,194 / 0;
  C6 cw = delta 8,194 / 0; C8 Fp-dependent pair 8,194 / 0 — every outcome as
  in the review of record. **G-7 probes: D1 (duplicate claim, its own
  pair) rank 8,196 = 2(N+3)-2, surjective, disclosed 0; D2 (exact copy, two
  identical coordinates) rank 8,194, short by 2 of the onto-lemma's 8,196,
  disclosed 0; D3 (copy sharing the pair, one data weight changed) rank
  8,194, disclosed 2 (fires).**

## RESULT (2026-10-19 10:07 UTC) — not a privacy acceptance

1. **The trained slot-IR export exists**: `g7/export/slot_ir_tl_t32_trained_pg_rot1.json`
   (sha256 a63b3f35b1c010528755dc0cc0e53b9300179f0148aa35689f4b6fb2b5683239,
   100,323 B), reached through the trained door at pg_rot1, oracle-checked
   (IR == closure) on all 22 layers' real public statements [MEASURED].
2. **G-7's premise, as worded in the draft, does not occur in the code**
   [MEASURED]: at sh_qkv = sh_g = 8 the scaled lookup equals the byte lookup,
   but helpers pair lookups (2k, 2k+1) and each duplicate pair is the two
   lookups of ONE helper (Q helper 1, Kv helpers 1 and 3, F helper 0). The
   effect is a helper relation `h d^2 - 2d` with two identical denominator
   nodes, not two H helper planes; no slot's table list (terminal map) has a
   repeated coordinate, and no two published claim values are equal in any
   trained capture. The helper and terminal counts equal the frozen twin's.
3. **NL-1 at the trained export: PASS on every stage** [MEASURED]: S1 23/23
   premise, 23/23 public factor in every monomial, 23/23 degree; budgets
   Sigma L 979 / dim C 956, worst L 97 (slot 18); Fact 2.1 230/230; miniatures
   and fibre test 23/23; terminal map onto 23/23; controls 12/12. The
   adversarial check's K1 (symbolic) 23/23 and K5 host coupling 6/6 too.
   On the duplicate-coordinate question NL-1 says NOT APPLICABLE (none
   exists at this export).
4. **Terminal surjection at the trained layout: the same structure as the
   review's** [MEASURED]: A and the endpoints surjective, disclosed 0; H
   disclosed 2 on the LogUp sum group / its joint component (the public
   identity, as at the toy). Probe D2 shows what the step would say if a
   terminal map DID repeat a coordinate: the onto-lemma's rank figure fails
   (short by 2) but the disclosure stays 0, because the repeated
   coordinate's equality holds for the data too; a repeat that is not exact
   (D3) is caught.
5. Adapted, not edited: `nl_check.py` / `nlc_check.py` by attribute patching
   (fidelity: lane reproduction equal stage by stage; m125 anchor equal);
   `ts_review.py` reused for Role / stage 0 / stage 1 with N_COLS = 4096,
   stage 2 restated with the claim columns at 2N + 2k (the literal 512 would
   collide) and disclosed by the null-space form (fidelity at the review's
   own captures: 176 rows, 0 disagreements).
6. Nothing pending: queue.done (0), ts_queue.done (0), every guarded job of
   this sub-lane has its .done marker; no job of this sub-lane is live.
