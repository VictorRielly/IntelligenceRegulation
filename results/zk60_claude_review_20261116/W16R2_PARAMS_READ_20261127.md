# W16R2_SHIELD_T128_H24: Lean block-verifier record against the Rust verifier (independent read, 2026-11-27)

Read-only correspondence check. Lean side: `BlockParams` (`formal/ZK60Formal/ExecBlockVerify.lean:178`), the
fixing structure `Link.IsShieldW16` (`BlockInstW16Shield.lean:140-150`), the premises of
`block_knowledge_w16r2_shieldU1` (`BlockW16U1Done.lean:59-97`) and the witness record `covParamsW16`
(`BlockW16U1Cover.lean:65-86`). Rust side: `ops/zkp-mvp/gpu-metal/hashline/src/` only. Nothing was built, compiled or
edited. COUNTED = read at file:line; DERIVED = arithmetic shown (all arithmetic re-run in one `python3 -c` block).
Paths below: `pb/` = `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`; `F/` = `formal/ZK60Formal/`.

## 0. Findings first

1. **F1, the witness record makes acceptance impossible.** `covParamsW16.geom` is `R13.geom ...`, whose block `Dim` is
   R13's `blkDim = ⟨256, 2^14+256, 2^16, 16⟩` (`F/ExecBlockR13.lean:289,296-298`). `BlockAcc` requires
   `SlotsAcc` (`F/OpenKnowBlock.lean:45-48`), which requires `CoreShape P.geom` (`F/ExtractW16Block.lean:52`), which
   requires every `A`/`H` opened column to carry a path of `g.blk.path = 16` entries and exactly `g.blk.checks = 256`
   columns (`F/ExecBlockWire.lean:244-245`). The same `BlockAcc` requires `blockVerify` to return `.ok`, whose second
   step `pathsDepth "A" P.aPath` refuses any `A` column whose path is not `P.aPath = 15` entries
   (`F/ExecBlockVerify.lean:369-375,392`). 256 columns of path length 16 and every column of path length 15 cannot
   both hold, so `BlockAcc ... (covParamsW16 ...) ...` is false for every oracle `G`. Consequence: the conclusion of
   `cov_block_knowledge_w16r2_shieldU1` is an event of probability 0 at that record, and its `hEnd` premise holds
   with `εend = 0`. The cover establishes that the premises are jointly satisfiable, as its header says; it does not
   exhibit a record at which the statement has content. The cover header's placeholder list
   (`BlockW16U1Cover.lean:20-22`) omits `geom.blk`. This is a placeholder issue (`IsShieldW16` does not fix
   `geom.blk`), not a mismatch in a fixed field. (Reading of the definitions; not machine-checked.)
2. **The Rust block `Dim` for this profile is `⟨280, 16664, 32768, 15⟩`** (DERIVED, §1 row `geom.blk`); with it,
   `CoreShape` and `pathsDepth 15` agree. The run-level record needs this value.
3. **No field that `IsShieldW16` or a theorem premise fixes disagrees with the Rust code.** Draws, slot schedule,
   terminal counts, groups, functional count, mask count, `A`/`H` rows and `logCols` all match, by derivation from the
   shape code (with one input taken from Lean's typed calibration, see §4).
4. **`IsShieldW16` leaves `geom.blk`, `aPath`, `hPath`, `maskPath`, `aRows`, `hRows`, `endpointLogN` (except `> 0`),
   `preChecks`, `checkOpening` and `name` free.** `block_knowledge_w16r2_shieldU1` is therefore stated for a class of
   records that includes the code's record and also records like the cover's, at which it says nothing. The claim
   "this is the installed verifier" needs the run-level record to fix them.
5. **Endpoint rows: the placeholder 38 equals the Rust internal-boundary row count; the external endpoints have 37.**
   Neither enters `blockVerify` (it calls `pcsVerify` only at `.a` and `.h`).

Counts: **MATCH 27, MISMATCH 3, NOT DETERMINED 3** (rows of §1).

## 1. Field and constant table

Profile inputs (COUNTED, `pb/shape.rs:301`): tokens 128, width 3072, hidden 9216, 32 query heads of 128, 8 KV heads,
`log_cols` 14. `inv_rate = W16R2_INV_RATE = 2` (`pb/shape.rs:306`, applied at `:698`), `opened_cols = 280`
(`pb/shape.rs:320`, applied at `:1083-1091`), endpoints `endpoint_log_n = log_cols = 14`,
`endpoint_inv_rate = inv_rate = 2` (`pb/shape.rs:1072`, `None` passed at `:699`; D59 refusal at `:1084`).
Pads (`pb/shape.rs:1036-1037`, DERIVED): `t_pad 128, d_pad 4096, h_pad 32, f_pad 16384`, `q_pad = 32·128 = 4096`
(`:2300`). Domain logs (`natural_log` `pb/shape.rs:2415-2431`, P-3 lift `pb/layout.rs:175-181` lifts every domain but
`T`, `Ht` to ≥ 14), DERIVED: T 7, Ht 12, L 11→14, D 19, Q 19, Kv 17, S 19, F 21, Tab 8→14. Rows per plane
`max(1, 2^log >> 14)` (`pb/shape.rs:2455`): T 1, Ht 1, L 1, D 32, Q 32, Kv 8, S 32, F 128, Tab 1. Padded domains
(size ≠ true size, `:2434-2447`): L, D, F, Tab; not T, Ht, Q (2^19 = 128·32·128), Kv (2^17), S (2^19).

| # | Field / constant | Lean value (file:line) | Fixed by | Rust value (file:line, derivation) | Verdict |
|---|---|---|---|---|---|
| 1 | `geom.slots` | `W16R2.shieldSlots = R13.shieldSlots` (`F/BlockInstW16Shield.lean:33`, list `F/ExecBlockR13.lean:390-393`) | `IsShieldW16.hsl` | `Shape::slots` `pb/shape.rs:2660-2713`: main = domain log (cube slots) or inner log (QMM/KMM/VMM/GMM/UMM `clog2 d_pad`=12, WO `clog2 q_pad`=12, SCORE `lkv+clog2 hd`=3+7=10, PV 3+7=10, DMM `clog2 f_pad`=14); ext 2 at slots 8,9 else 1; degree = `BASE_DEGREE` (`:619`) + 1 if indicator domain pads (`:626-627`: SS, SSM, DZC on D; FZC on F) + 1 at 8,9 (`lkv = 3 > 0`). DERIVED list equals Lean's 23 triples; Σ(n+e) = 370 | MATCH |
| 2 | `geom.terms` | `[1,1,22,3,2,1,1,1,2,2,1,1,1,1,31,10,10,15,14,32,1,2,2]` (`F/BlockInstW16Shield.lean:37-38`) | `IsShieldW16.htm` | `slot_terms` `pb/shape.rs:2646-2653` = a+h+[21,22], `claim_sites` `:2597-2641`; DERIVED a = `[1,1,22,2,2,1,1,1,2,2,1,1,1,1,21,7,7,10,9,16,0,1,1]` (Σ111), h = `[0,0,0,1,0,…,10,3,3,5,5,16,1,0,0]` (Σ44); equal to `aCntW16Shield`/`hCntW16Shield` (`:120-125`) | MATCH |
| 3 | `draws` = `shieldDraws` | `[7,7,15,16,13,19,10,10,19,19,19,21,14,19,39,25,23,30,31,32,0,19,19]` (`F/BlockInstW16Shield.lean:41-44`), Σ426 | `IsShieldW16.hdr` | DERIVED from the challenge calls: legacy `define` `pb/argument.rs:2982-4012` for slots 0-13,20-22; W16 arms `pb/argument_accuracy.rs:24-33` for DZC `:464-467` (17+2+1+19=39), FZC `:506-509` (7+2+1+21=31), QZC/KVZC `:540-543` (4+2+19=25; 4+2+17=23), SZC `:575-580` (19+9+2=30), TAB `:746-748` (14+(3+13+1)+1=32). Others: SS/SSM `lt`=7; TZC 7+6+2=15 (T does not pad); LZC 14+1+1=16; RS 12+1=13; QMM 7+12=19; KMM/VMM 10; SCORE 5+7+7=19; PV 5+7+7=19; WO 7+12=19; GMM 7+14=21; UMM 14; DMM 7+12=19; ZS 0; IO 19,19. Σ426 | MATCH |
| 4 | `geom.aGroups` | 36 (`IsShieldW16.hag`, `:144`) | `IsShieldW16` | `a_groups` `pb/shape.rs:2806-2826`: tzc = #distinct{(k·128) mod 2^14, k<9}∪{0} = 9; 9+15+2·2+4·2 = 36 | MATCH |
| 5 | `geom.hGroups` | 9 (`:145`) | `IsShieldW16` | `h_groups` `pb/shape.rs:2832-2835`: 8+1+0 = 9 | MATCH |
| 6 | `nFunctionals` | 34 (`:146`, cover `:82`) | `IsShieldW16.hnf` | `N_FUNCTIONALS = 34` `pb/layout.rs:1124`; `n_functionals` `pb/shape.rs:2902` (+0, `dd_cap` 0); checked at `pb/argument.rs:4213`. DERIVED 23 evals + 5 standalone + 6 hosts = 34 | MATCH |
| 7 | `maskVerify` = `maskField tag 23` | `:147` | `IsShieldW16.hPm` | `mask_verify_tagged` with `lay.mask_specs()` (`pb/protocol.rs:4364`, `pb/layout.rs:1460-1462`): 23 specs, `n_base = 2·23+4 = 50` (`hashline/src/zk.rs:1244`) | MATCH (count) |
| 8 | `pcsVerify` = `pcsField tag rowsOf` | `:148`; `w16r2Prm = ⟨14,2,280,280⟩` (`F/ExecOpening.lean:942`); log 14 hard-coded (`F/ExecOpeningBlock.lean:219-222`) | `IsShieldW16.hPp` | `pcs_params_at` `pb/protocol.rs:72-74` = (14, 2, 280); `ZkOpts::standard` q_pad = num_col_checks = 280 (`zkp-core/src/pcs.rs:598-600`); `commitment(root, rows, 14)` (`pb/protocol.rs:4372`) | MATCH (parameters) |
| 9 | `rowsOf .a` / 2504 | `:149`; cover `covRowsW16` `:58` | `IsShieldW16.hrA` | `Layout::for_shape` `pb/layout.rs:1322-1342`: data = Σ planes×rows over `a_plane_doms` (`pb/shape.rs:2466-2482`, W16 branch): T4·1+Ht2·1+L2·1+D(7+8+2+2=19)·32+Q6·32+Kv6·8+S(4+2+2·1=8)·32+F(4+2+1+1+1=9)·128+Tab(3+13)·1 = 4+2+2+608+192+48+256+1152+16 = 2280; + 2·111 sites + 2 prox = 2504 | MATCH |
| 10 | `rowsOf .h` / 2606 | `:150`; cover `:59` | `IsShieldW16.hrH` | `pb/layout.rs:1343-1353`: 2·rows per `h_plane_doms` plane (`pb/shape.rs:2568-2590`): L1·1+D10·32+Q3·32+Kv3·8+S5·32+F5·128+Tab(4+13)·1, ×2 = 2516; + 2·44 + 2 = 2606 | MATCH |
| 11 | `rowsOf` at `.inp`/`.out` | 38 (`BlockW16U1Cover.lean:60`) | placeholder | external endpoint rows `sh.endpoint_rows` (`pb/run.rs:1527,1559`) = `ceil(128·4096 / 2^14) + MASK_ROWS` = 32+5 = **37** (`pb/shape.rs:695`, `MASK_ROWS = 5` `pb/endpoint_g.rs:92`); internal boundary rows = `endpoint_rows + 1` = 38 = 32 + 2·`BOUNDARY_SITES`(2) + 2 (`pb/run.rs:50,790`) | MISMATCH for the external endpoints (38 vs 37); MATCH for internal boundaries |
| 12 | `logCols` / 14 | cover `:69` | premise `hlc` | `sh.log_cols = 14` (`pb/shape.rs:301,323`), absorbed `pb/protocol.rs:4343,4349` | MATCH |
| 13 | `endpointLogN` | 14 (cover `:70`) | placeholder (`hep` only `> 0`) | `endpoint_log_n = 14` (`pb/shape.rs:1072,1107`); `endpoint_pcs_params` `pb/protocol.rs:86-88`; boundary `log_n` = same (`pb/run.rs:790`) | MATCH |
| 14 | `aRows` | 2504 (cover `:71`) | not fixed (only `rowsOf .a` is) | `absorb_root(..., lay.a_rows, ...)` `pb/protocol.rs:4343`; row 9 | MATCH |
| 15 | `hRows` | 2606 (cover `:72`) | not fixed | `pb/protocol.rs:4349`; row 10 | MATCH |
| 16 | `aPath` | 15 (cover `:73`) | placeholder | `paths_are_the_tree_depth("A", params, …)` `pb/protocol.rs:4340` → `tree_depth` → `wire::path_len` = trailing zeros of `next_pow2(2^14·2)` = 15 (`pb/hash_domain.rs:675-677`, `pb/wire.rs:93-97,126-128`) | MATCH |
| 17 | `hPath` | 15 (cover `:74`) | placeholder | same, `pb/protocol.rs:4341` | MATCH |
| 18 | `maskPath` | 12 (cover `:75`) | placeholder | `MASK_PATH_LEN = MASK_LOG_DOM = 12` (`pb/wire.rs:25,131`, `hashline/src/zk.rs:691`); also inside `mask_verify_tagged` `zk.rs:1265` | MATCH |
| 19 | `preChecks` | `.ok ()` (cover `:76`) | placeholder | `sh.check_constructed()`, `lay.check_is_for_shape(sh)`, `blk.check_for_shape(sh)` (`pb/protocol.rs:4328-4331`); verifier-side, read nothing of the proof; bodies not read | NOT DETERMINED (that they return `Ok` on the installed statement) |
| 20 | `kind` | `shdP_slotKind`: hosts {2,14..18}, standalone {3,19..22} (`F/RunShieldBlkInst.lean:497-500`) | premises `hk3`,`hk19`,`hk20` fix 3 slots | `SLOT_KINDS` `pb/layout.rs:1077-1103`: Host at 2,14,15,16,17,18; Standalone at 3,19,20,21,22; Private elsewhere | MATCH |
| 21 | `name` | `toString s` (cover `:78`) | free | `SLOT_NAMES[s]` (`pb/layout.rs:1013`, e.g. `"01 SS row sums norm_a (private)"`), used in refusal text | MISMATCH (refusal text only; acceptance unaffected) |
| 22 | `define` | `defineS (progW16 (cfgU1 …)) (pubsU1 …)` (cover `:80-81`) | premise `hdef` | `argument::define` → `define_changed` W16 arms (`pb/argument.rs:2953-2956`, `pb/argument_accuracy.rs:11-33`) | NOT DETERMINED (bodies not compared; only draw counts, row 3) |
| 23 | `logupSumClaim` | `logupSumW16 (cfgU1 …)` (`F/BlockDefineW16.lean:599-603`) | premise `hls` | `logup_sum_claim` `pb/protocol.rs:171-187`: two parts per `H` plane (offsets `h_off`, log of its domain), sign −1 on table helpers, value 0. Lean: two parts per `H` plane, sign −1 on the `3 + nRange` table helpers, value 0 | MATCH (structure); per-plane offsets not compared |
| 24 | `checkOpening` | parameter of the cover (`:66`) | free | `check_opening(claims, 14, rows, site_rows, sum_rows, prox, groups)` `pb/protocol.rs:4369,4394`. DERIVED for the run-level record: A (2504, rows 2280..2501, None, prox 2502, 36); H (2606, rows 2516..2603, `h_u_rows` = [2514, 2515], prox 2604, 9) | NOT DETERMINED (free in Lean; values recorded) |
| 25 | `geom.blk` (`Dim`) | `R13.blkDim = ⟨256, 2^14+256 = 16640, 2^16 = 65536, 16⟩` (`F/ExecBlockR13.lean:289`) | placeholder, not listed in the cover header | `Dim::block` = `Dim::new(14, 2, 280)` (`pb/wire.rs:93-101`): checks 280, vec 2^14+280 = 16664, enc_cols 2^15 = 32768, path 15 | **MISMATCH** (all four; see F1) |
| 26 | `geom.maskVec` | 1024 (`F/ExecBlockFS.lean:972`) | via `R13.geom` | `MASK_VEC = 2 << MASK_LOG_MSG(9)` = 1024 (`pb/wire.rs:23`, `zk.rs:690`) | MATCH |
| 27 | `geom.maskChecks` | 256 (`F/ExecBlockFS.lean:974`) | via `R13.geom` | `MASK_CHECKS = MASK_Q = 256` (`pb/wire.rs:32`, `zk.rs:692`) | MATCH |
| 28 | `geom.maskDom` | 4096 (`:976`) | via `R13.geom` | `1 << MASK_LOG_DOM` = 4096 (`pb/wire.rs:24`) | MATCH |
| 29 | `geom.maskPath` | 12 (`:978`) | via `R13.geom` | `pb/wire.rs:25` = 12 | MATCH |
| 30 | `geom.mRows` / 50 | 50 (cover `:68`) | placeholder | `m_rows = 2·23+4 = 50` (`pb/shape.rs:2897-2899`); `n_base` `zk.rs:1244` | MATCH |
| 31 | `geom.aRows`, `geom.hRows` | 2504, 2606 (cover `:68`) | via `R13.geom` arguments | rows 9, 10 | MATCH |
| 32 | `geom.ceiling` | 256 MiB (`F/ExecBlockR13.lean:292`) | via `R13.geom` | `wire_ceiling` = `MAX_WIRE_BYTES_TRAINED` = 256 MiB for a trained-calibration shape (`pb/wire.rs:48-59`); W16R2 strings require the trained door (`pb/layout.rs:1310-1312`) | MATCH |
| 33 | `(h, Q, e) = (15, 280, 8052)` in `dXof`/`csShieldW16` | `BlockW16U1Done.lean:91`, `BlockInstW16Shield.lean:157` | fixed in the statement | h: log2 N = log2(2^14·2) = 15 = tree depth (row 16). Q: `W16R2_OPENED_COLS` 280. e: `floor((N−K)/2)` (`pb/shape.rs:359-360`), N 32768, K 16384+280 = 16664 → 8052; 2·8052+16664 = 32768. (e is an accounting quantity; no verifier check reads it) | MATCH |
| 34 | 23 (slots, mask specs) | `maskField tag 23`; `numsW16Shield` (`:117`) | `IsShieldW16` | `N_SLOTS = 23` (`pb/layout.rs:976`), `n_slots` (`pb/shape.rs:2893`, +0) | MATCH |
| 35 | `nRange` 13 / widths `[3,4,5,6,7,12,13,15,16]` (enter rows 2,9,10, draws slot 19) | `F/RunShapeShieldU1.lean:21-22` | Lean derived | `range16::widths` (`pb/range16.rs:164-196`) at LowH24 `derive` (`pb/accuracy_precision.rs:55-100`): q=k=15, v=16, pv=12, up=12, ao=21, down=22, score=19, gate shift 20, f_p+1=13, `wrho_s` = 7+f_e = 16 (`pb/shape.rs:1125`, not changed by the trained door `:1882-1916`), `SH_ROPE` 7 (`pb/layout.rs:67`) → widths as Lean; sub-planes 7·1+2+4 = 13 (`pb/range16.rs:207-214`) | MATCH, conditional on the calibration (§4) |

Verdict tally: MATCH rows 1-10, 12-18, 20, 23, 26-35 (27); MISMATCH rows 11 (external part), 21, 25 (3);
NOT DETERMINED rows 19, 22, 24 (3).

## 2. Mismatches: what each touches

- **Row 25, `geom.blk` (placeholder, not fixed by `IsShieldW16`).** Touches `SlotsAcc`/`CoreShape`
  (`F/ExtractW16Block.lean:52`, `F/ExecBlockWire.lean:238-248`) and hence `BlockAcc` in both
  `block_knowledge_w16r2_shieldU1` (at the record a user supplies) and `cov_block_knowledge_w16r2_shieldU1` (at the
  cover's record). It does not change what the theorem says for a record carrying the code's `Dim`; it empties the
  cover's instance (F1). Rust side: `Dim::new(14, 2, 280)`, the same `Dim` the frame decoder's `hiding_ok` enforces
  (`pb/wire.rs:109-115`: 280 columns, vectors of 16664, index < 32768, path 15). Also feeds `decodeFork`/`forkVerify`
  (`F/ExecBlockVerify.lean:421`) at the run level.
- **Row 11, endpoint rows 38 (placeholder).** Not read by `blockVerify` (`pcsVerify` at `.a`, `.h` only,
  `F/ExecBlockVerify.lean:402-409`). The run-level record needs 37 for the two external endpoints
  (`pb/run.rs:1527,1559`) and 38 for internal boundaries (`pb/run.rs:790`, absorbed `:1468`). One `rowsOf` cannot carry
  both values if `.inp` is used for block 0's external input and for a later block's boundary.
- **Row 21, `name` (free).** Affects only refusal strings (`scCheck`, `F/ExecBlockVerify.lean:322-325,345`); acceptance and
  transcript unaffected.

No mismatch in a field that `IsShieldW16` or a premise of `block_knowledge_w16r2_shieldU1` fixes.

## 3. What the Lean record does not model at block level (seen in the Rust code)

1. The three pre-checks of `verify_core` (`pb/protocol.rs:4328-4331`: CS-8 shape and layout, CS-1/CS-4 block
   statement) are one opaque `preChecks` value, `.ok ()` in the cover.
2. `IsShieldW16` does not tie `checkOpening` to `check_opening`'s geometry (rows, site rows, the `H` zero-sum pair
   `Some(h_u_rows)` vs `None` for `A`, prox row, group count; `pb/protocol.rs:4369,4394`). The theorem quantifies over
   any `checkOpening`. `checkField` (`F/ExecOpeningBlock.lean:226-228`) exists but is not required.
3. `IsShieldW16` does not tie `P.aRows`/`P.hRows` (absorbed in the header, `F/ExecBlockVerify.lean:379,384`) to
   `rowsOf` (used by `pcsField`); Rust uses one `lay.a_rows`/`lay.h_rows` for both (`pb/protocol.rs:4343,4372`).
4. `IsShieldW16` does not tie `aPath`/`hPath` (T-4) to `pcsField`'s parameters, nor `geom.blk` to either; Rust derives
   all three from `pcs_params_at` (`pb/protocol.rs:4334,4340-4341`, `pb/wire.rs:126-128`).
5. Inside `define` for the W16 arms: the accuracy registry check `check_for_registry` (skipped when a fork preflight
   covers it) and the gate-shift equality refusal (`pb/argument_accuracy.rs:19-22`). Not checked whether
   `defineS (progW16 …)` contains them.
6. `mask_verify_tagged` reads the 23 `(n+e, d)` specs in `combined_weights` (`zk.rs:1246`); the Lean `maskField` takes
   only the count 23 (`F/ExecOpeningM.lean:690-691`). Not checked whether the functionals carry the same information.

## 4. Limits

- The calibration (per-layer `sh_ao 7, sh_s 7, sh_z 8, gate shift 20, f_e 9, sh_qkv 8, sh_o 9`) is a runtime input to
  the Rust shape, not in the Rust source. I used the Lean-typed values (`F/RunShapeShieldU1.lean:8-12,44-56`, first 12
  of 26 layers seen; uniformity taken from that file's statement). I did not read the `export_u1` manifests (outside the
  repository). Rows 2, 9, 10, 35 and slot 19's draw count depend on `nRange = 13` and on `wrho_s ≤ 16`; the window
  limbs `ao`, `down`, `score`, `gate` are 2 at every LowH24 calibration the `derive` accepts (DERIVED from the ranges in
  `pb/accuracy_precision.rs:87-89` and `limbs_of` `pb/range16.rs:114-121`).
- Pad-rule activation (`pad_on`) was derived from `a_rule` (`pb/pad.rs:294-314`) by inspection of its branches, not by
  enumerating every plane's rule; the draw counts 39, 31, 32, 16 and the slot degrees depend on it.
- Not read: `check_constructed`, `check_is_for_shape`, `check_for_shape`, `finish_claims`, `check_opening`'s body,
  `pcs::verify_zk_tagged`'s body, the slot `define` bodies beyond their challenge calls, `run.rs` beyond
  `RunVerifier::start`/`step` lines cited, the Lean `w16r2OpenCheck`/`maskVerify` bodies, `decodeFork`'s readers.
- No compile, no test, no execution of Rust or Lean; F1 is a reading of four definitions.
