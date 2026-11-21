# L63 leg 19: every constant of the Shield run's Lean instances against the code; a profile-parameter design probe

Written by the L63 leg 19 agent (clock read 2026-11-21 02:12 UTC at the start of the write-up). Labels: PROVED = green
guarded build plus a green full check; CHECKED = elaborated or run in a guarded job; ARGUED = read, no Lean.

## Part 1. The constants of the Shield run's instances

**Verdict: no mismatch.** 58 constants (rows below) of the instances the top `sshC_productionReadyL_epP_blkEF`
reaches were inventoried. Before this leg **14** were covered by a committed check against a code-side export (by
name, or by a theorem that ties them to a checked definition); 13 more agreed with a checked value only through an
untied duplicate literal. Now **43** are covered (32 by this leg's regression, 11 by earlier lanes' checks only);
**8** have no code-side export and are ARGUED from the Rust source (all match); 6 are Lean-derived from covered rows;
1 row (`preChecks`, `name`) is no code constant. Every value read in the Rust matches the Lean value. One scope observation (L63-14, not a constant mismatch): the code does not pin the run's
block count to 26.

The new check is `formal/ZK60Formal/RunStgShieldInstCheck.lean` (not in the root: it defines `main`), run by
`check_l63merge.sh` as a regression (`RunStgShieldInstCheck: 158 checks, 0 failed`, ten `#print axioms` reports, all
standard). It has two halves, both executed on every run of the check:

* **ties** (theorems the kernel re-checks on every run, quantified over every tag, layer, public data and run):
  `shdIC_lists`, `shdIC_counts`, `shdIC_geometry`, `shdIC_cube`, `shdIC_rowsOf`, `shdIC_kinds` (by `decide`),
  `shdIC_rtBlk`, `shdIC_r13Prm`, `shdIC_sgeom`, `shdIC_stageAxes`: each instance field IS a named definition
  (`R13.shieldSlots`, `numsR13Shield.rA`, `R13.blkDim.path`, `W16R2.maskPath`, `shShieldR13`, `cbBndRows 128 4096 14 2`,
  `kindOf`, …). A literal that drifts from its named definition stops the file elaborating;
* **comparison** (`main`): the named definitions against three committed exports of the production code: L17's shape
  corpus (`results/zk60_lean_l17_20261107/shape_corpus.txt`, profile `…-shieldstral-3b-t128-lowh24-blocks/2`: the
  registered shape's constructors), L49's Shieldstral block export (`results/zk60_lean_l49_20261110/pub_shield_short.txt`:
  the production `Shape`, `define` and draws of one layer that `prove_core` proved and `verify_core` accepted), and L17's
  segment corpus (the R13 rung's segment shape, for the R13-generic wire ceiling). Check kinds: CORPUS 3, RUN 1,
  SHAPE-AXES 26, SHAPE-DOMS 26, LAYER-SHAPE 26, LAYER-CUBE 26 (every one of the 26 layers' `cfgShieldR13 Ly` and
  `shieldShape Ly`), HEADER 3, STAGE-AXES 1, SCHEDULE 1, TERMS 1, DRAWS 24, COUNTS 8, OPENING 8, SCHEDULE-H 2,
  SCHEDULE-A 1, IO-ROWS 1.

Coverage legend: **C0** covered before this leg (check named); **C19** covered by this leg's check (and, where noted,
also before by value through an untied literal); **A** ARGUED only (code value, file:line under
`ops/zkp-mvp/gpu-metal/hashline/src/`, and the export line that would make it mechanical); **D** derived in Lean from
covered rows. Rust paths below are relative to that directory; `zkp-core/` is `ops/zkp-mvp/gpu-metal/zkp-core/src/`.

### 1a-1b. Inventory and coverage

**Block instance: `shdP_blkParams` (RunShieldBlkInst.lean, lane L68a), `IsShieldR13`, `ShieldBlkAtD`**

| # | name | value | coverage |
|---|---|---|---|
| 1 | `geom.slots` | `R13.shieldSlots` (23 `(n,e,d)`) | C0 by name (BlockInstCheck SHAPE-SCHEDULE, L31); C19 SCHEDULE |
| 2 | `geom.terms` | `R13.shieldTerms` | C0 by name (BlockInstCheck SHAPE-TERMS); C19 TERMS |
| 3 | `geom.mRows` | 50 | C19 (`2·S+4`, COUNTS m_rows 50). Before: none (finding L68b-1 was this literal) |
| 4 | `geom.aGroups` | 36 | C19. Before: `numsR13Shield.aGroups` checked by BlockInstCheck, the literal untied |
| 5 | `geom.aRows`, `aRows` | 4577 | C19 (tie to `numsR13Shield.rA`). Before: value checked through `numsR13Shield`, literal untied |
| 6 | `geom.hGroups` | 9 | C19. Before: as row 4 |
| 7 | `geom.hRows`, `hRows` | 4390 | C19. Before: as row 5 |
| 8 | `logCols` | 14 | C19 (`R13.logCols`, COUNTS log_cols, L49 header) |
| 9 | `endpointLogN` | 14 | C19 (e_log_n) |
| 10 | `aPath`, `hPath` | 16, 16 | C19 (`R13.blkDim.path` = log_cols + log2 inv_rate) |
| 11 | `geom.blk` | `R13.blkDim` ⟨256, 2^14+256, 2^16, 16⟩ | C0 R13-generic (CheckR13Block SEG-SHAPE, L17 rung); C19 against the Shield shape |
| 12 | `maskPath`, `geom.mask*` | 12; `W16R2.maskVec 1024`, `maskQ 256`, `maskDom 4096`, `maskPath 12` | C0 R13-generic for the named constants (CheckR13Open / L10 accept real mask openings at these constants; open corpus off-repo, sha256 recorded); the literal `maskPath := 12` tied now (C19 tie only). A: `wire.rs:23-32`, `zk.rs:391-393` (`MASK_LOG_DOM 12`, `MASK_Q 256`) |
| 13 | `geom.ceiling` | `R13.ceiling` 2^28 | C0 R13-generic (CheckR13Block); C19 (segment corpus) |
| 14 | `kind` | `shdP_slotKind`: hosts {2,14..18}, standalone {3,19..22} | C19 by `shdIC_kinds` (`decide`, = `kindOf`, which CheckR13Slots checks slot by slot at the R13 rung). Before: by reading (L68b-2). A: `layout.rs:1077-1100` matches |
| 15 | `draws` | `R13.shieldDraws` (451) | C19 DRAWS (23 slots of L49's export). Before: only through `shieldDraws_eq` to the shape facts, half of which BlockAlgCheck checked |
| 16 | `define` | `defineS (progR13 (cfgShieldR13 Ly)) (pubsR13L …)` | C0 at layer 0 (BlockR13HostExportCheck, L49: per-slot table counts, every public table by value, 210 checks); layers 1-25 through the same generic definitions only |
| 17 | `nFunctionals` | 34 | C19. Before: as row 4 |
| 18 | `logupSumClaim` | `logupSumR13 (cfgShieldR13 Ly)` | C0 at layer 0 (BlockR13HostExportCheck "sum claim" 108 checks) |
| 19 | `maskVerify` | `maskField tag 23` | C19 (`numsR13Shield.S`, mask_specs 23). The field itself C0 generic (L10, CheckR13Open) |
| 20 | `pcsVerify` | `pcsFieldR13 tag shdP_rowsOf` | C0 generic (CheckR13Open: real R13 openings, roots 2^14 / 2^16, refusals); rows via 21-22 |
| 21 | `shdP_rowsOf .a/.h` | 4577 / 4390 | C19 |
| 22 | `shdP_rowsOf .inp/.out` | 38 | C19 (`cbBndRows t_pad d_pad e_log_n 2` = e_rows 37 + 1). Before: `cbBndRows_r13` checked by RunCloseBGeoCheck (L55), literal untied |
| 23 | `preChecks`, `name` | `.ok ()`, `toString` | not constants of the code's verifier (no proof reads `name`); not compared |
| 24 | `shdP_bitLay` cube widths | tok 7, wid 12, grp 3, slot 3+2, hd 7 (flip + 6), hid 14 | C19: the widths are the types `CtR … CfR (cfgShieldR13 Ly)`, tied to `shShieldR13` (`shdIC_cube`); every `ShapeW` field against SHAPE (SHAPE-AXES, SHAPE-DOMS) and the paddings `2^lt … 2^lkv` against L49's SHAPE (LAYER-CUBE), at all 26 layers. Before: lt, lh, lq, lf, logs, helpers by BlockAlgCheck (L36); ld, ldh, lkv, lkvw, pads, zero rules, per_row not |
| 25 | `shdP_bitLay` / `shdP_w16Pub` embedding | MSB-first axes, head = flip bit + 6 bits, head slot `4g + j`, gates at 3072 / 9216 | A. L49's BlockR13HostExportCheck compares the code's tables at the same natural embedding (`msbIndex`, `s = 2^(lh−lkv)·g + j`) through its own record `natF`; no theorem ties `shdP_w16Pub` to `natF`. Needs no new export: a Lean lemma `ofBR (shdP_w16Pub Ly Pb) = natF …` would close it |
| 26 | `shdP_K`, `shdP_U` | `GF[u]/(u² − 7)` | C0 (L5Check, in the lane's regression: 960 `F2` records with `NONRESIDUE = 7`; `zkp-core/field.rs:15`) |
| 27 | `shdP_Pk0` fallback | `min k 25`, `Ly0 = shieldExport[0]` literal | D / unreachable for `k < 26` (`shdP_Pk0_eq_blkParams`); `Ly0` duplicates layer 0's literal, uncompared |

**Profile numbers: `numsR13Shield`, `profR13Shield`, `aCnt` / `hCnt` (BlockInstProf.lean, L31)**

| # | name | value | coverage |
|---|---|---|---|
| 28 | `numsR13Shield` S, rA, rH, aGroups, hGroups, nFun, Q | 23, 4577, 4390, 36, 9, 34, 256 | C0 (BlockInstCheck SHAPE-COUNTS); C19 COUNTS / OPENING |
| 29 | `numsR13Shield.mI` | 64 | C19 (`⌈q/4⌉`). A: `zkp-core/transcript.rs:155-167` (4 indices per squeeze) |
| 30 | `numsR13Shield.nA`, `nH` | 146, 54 | C0 for `nH` (SHAPE-H-PLANES + 1); `nA` D before (`cnt_sums`, `cnt_terms`); C19 SCHEDULE-A / -H |
| 31 | `hCntR13Shield` | 23 counts | C0 (SHAPE-H-SCHEDULE); C19 |
| 32 | `aCntR13Shield` | 23 counts | D before (`cnt_terms` from row 2 and 31); C19 SCHEDULE-A directly |
| 33 | `profR13Shield` sl, sq | 1283, 844 | D (`r13_shield_counts` by `decide` from rows 1, 15) |

**Opening parameters (OpeningR13.lean, ExecBlockR13.lean, L17)**

| # | name | value | coverage |
|---|---|---|---|
| 34 | `r13Prm` | ⟨14, 4, 256, 256⟩ | C0 generic (CheckR13Open, rung); C19 against the Shield shape (`shdIC_r13Prm`, OPENING) |
| 35 | `R13.logCols`, `invRate`, `openedCols` | 14, 4, 256 | C19 (COUNTS log_cols, inv_rate, q) |
| 36 | coset `cosetPt (rootFp 16)`, `colEncLag (rootFp 14)` | 7·G_{2^16}, interpolant on G_{2^14} | C0 generic (CheckR13Open "root 2^14 / 2^16 equal", accepted openings). A: `protocol.rs:72`, `zkp-core/pcs.rs:599` |
| 37 | `rkR13` (decoding radius) | e = 24448 | D (`(2^16 − 2^14 − 256)/2`) |

**Run instance (RunShieldInstP.lean, L67/L68)**

| # | name | value | coverage |
|---|---|---|---|
| 38 | `shdP_rtBlk` S, nA, nH, pA/pH rows, prm, lc, Q, N, m | 23, 146, 54, 4577/4390, `r13Prm`, 14, 256, 2^16, 64 | C19 (`shdIC_rtBlk`). Before: literals untied |
| 39 | `shdP_rtBlk` nIn, nOut | 1, 1 | C0 generic (BlockInstCheck TERMS at both rungs: one endpoint table at slots 21, 22 = `ioCnt`) |
| 40 | `shdP_sgeom` boundaryRows, sites | 38, 2 | C19 (`shdIC_sgeom`, IO-ROWS). Sites: C0 by source text (RunCloseBGeoCheck SOURCE: `boundary_spec` has two sites) |
| 41 | `shdP_sgeom` l, k | 28, k + 1 | A: `classify_run.rs:345` (segments `l + 2`), `classify.rs:1359` (block k → segment k + 1). 28 assumes 26 blocks (L63-14). Export: a run-shape line `segments`, `block_segment` from a Shield classify run |
| 42 | `shdP_blockProf` rows / logN / `cbBndOpen tag 38` | 38, 14 | value C0 (RunCloseBGeoCheck, cbBndRows 38); the literals sit in the top's statement, untied |
| 43 | run blocks | 26 (`shieldExport.length`, `ShieldRun`) | C0 (L40 `l40_shield_export.py` on the app's verifier export, 26 layers, 2222 checks). Code: an upper bound only (L63-14) |
| 44 | `shieldExport`, `shieldCal` per layer | 26 calibrations | C0 (L40); C19 for T, d, f, H, 2·half, G at every layer (LAYER-SHAPE) |
| 45 | `shdP_runDomain` | 73 bytes | A: decodes to `hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2` = `run.rs:153` (checked by a byte decode this leg). Export: a classify-run receipt of this profile (`DOMAIN` line, as L51's) |
| 46 | header widths | `run-shape` 88, chunk 56, expected-IO 84 | C0 (RunAbsCheck MODEL, L51, on a real classify receipt; the widths are profile-independent) |
| 47 | stage IN-C tokens, tPad, dPad | 128, 128, 4096 | C19 (`shdIC_stageAxes`, STAGE-AXES against L49's SHAPE) |
| 48 | stage IN-C `v` | 131072 | C0 by value (L40: embedding `(V, d) = (131072, 3072)`); in the top only through the premise `hV131072` (L63-7). A: `token_io/classify.rs:216,717,737` |
| 49 | stage IN-C / OUT-C `lt`, `shdP_stgDim`, `lr` | 12, ⟨256, 2^12+256, 2^14, 14⟩, 2 | A: `token_io.rs:190` (`R1_MVP`: `stage_log_n 12`, `stage_inv_rate 4`, `opened_cols 256`), `wire.rs:93-96`. Export: a Shield classify-run stage line (`stage_log_n`, `stage_inv_rate`, `opened_cols`) |
| 50 | input endpoint `epLogN`, `shdP_epDim`, `elr`, `eq` | 8, ⟨256, 2^8+256, 2^11, 11⟩, 3, 256 | A: `token_io.rs:190` (`ep_log_n 8`, `ep_inv_rate 8`), `classify.rs:825,908`. Same export |
| 51 | input endpoint rows `Rr`, `dR`, `shdP_epPos` | 6, 1, token t at row 0 column t | A: `endpoint_g.rs:92,183-188` (1 data row + `MASK_ROWS` 5), `stage_in_c.rs:175-184` |
| 52 | `shdP_incGeo` | ⟨bLogN 14, bRows 38, bInRow, 1, 6⟩ | 14, 38: value C0 (L55); 1, 6 as row 51 |
| 53 | `incHeadDraws` | 15 | C0 generic (RunStgCheck LIST, L53: the head's challenge count `3 + clog2 dPad` on a real dev-rung receipt); at 4096 D |
| 54 | stage OUT-C `d`, `dPad`, `tPad` | 3072, 4096, 128 | C19 (STAGE-AXES) |
| 55 | `shdP_outcGeo` | ⟨14, 38, 32, 2, bOutRow⟩ | 14, 38, 32, 2: value C0 (RunCloseBGeoCheck DEV / SOURCE: B_out is `boundary_spec(l)`, data rows `t_pad·d_pad/2^14`) |
| 56 | `shdP_outcV` stage index, `lr`, `blr`, `q`, `bq`, `bd` | 27, 2, 2, 256, 256, `R13.blkDim` | A: `stage_out_c.rs:71-101,538,681`, `classify_run.rs:323` (index `l + 1`; 27 assumes 26 blocks). Export: as row 49 |
| 57 | `768` in the top's protocol | the input endpoint code's decoding radius | D (`(2^11 − 2·256)/2` from row 50) |
| 58 | `15 8 14` in the top (`mIn kIn kOut`) | head draws, IN-C / OUT-C functionals | D (`shdP_incPub_logs`, `shdP_incLay_nums`, `shdP_outcLay_nums` from rows 47-56) |

Counts: C0 before this leg (rows whose value was compared with an export by a committed check, through the same
definition or a tie): 1, 2, 11, 12, 13, 16, 18, 20, 26, 28, 31, 36, 43, 46 = **14** (plus by-value-only, untied
coverage of 4-7, 17, 22, 39, 40, 42, 44, 48, 52, 55: **13**). C19 now (new or re-checked with a tie, in the lane's
regression): 1-11, 12 (tie), 13-15, 17, 19, 21, 22, 24, 28-32, 34, 35, 38, 40, 44, 47, 54 = **32**. Covered by an
earlier lane's check only (not in the lane's regression): 16, 18, 20, 26 (L5 is in it), 36, 39, 42, 43, 46, 48, 55 =
**11**. ARGUED only (no export; code value read): 25, 41, 45, 49, 50, 51, 52 (fields 1, 6), 56 = **8**. Derived: 27,
33, 37, 53, 57, 58 = **6**. Not a code constant: 23.

### 1c. What was closed

`RunStgShieldInstCheck.lean` (new) and `check_l63merge.sh` (the regression section, the verdict). Every NOT COVERED
row whose value one of the three committed exports carries now has a comparison; the remaining rows have no export
(stage log widths, endpoint geometry, the stage-index / segment numbering, the run domain) or are embedding
conventions (row 25).

### 1d. The rows with no export (ARGUED; read by a read-only sub-agent this leg and spot-checked: `token_io.rs:190`,
`layout.rs:1077-1100`, `run.rs:153`, `trained_statement.rs:164,785-797`)

All match the Lean values: the `R1_MVP` tier (`token_io.rs:190`: `opened_cols 256, stage_log_n 12, stage_inv_rate 4,
ep_log_n 8, ep_inv_rate 8`), the endpoint layout (1 data row + 5 mask rows = 6), B_in / B_out as `boundary_spec`
(38 rows, 2 sites, `log_n` 14), the stage index `l + 1`, segments `l + 2`, the head's 15 draws (`stage_in_c.rs:254-258`),
the run domain string. One export would make most of them mechanical: a test-only `lean_l19_export` of a REAL Shield
classify run's geometry (stage `log_n`, rates, opened columns; endpoint rows, `ep_log_n`; boundary rows and sites;
segment count; stage index; the run profile's domain), in the style of L29's dev-rung corpus.

### 1e. Findings

* **No mismatch** between any Lean constant and the code.
* **L63-14 (Low, ARGUED, scope):** the code does not pin the run's block count. `TrainedStatement` checks only that the
  layer records are consecutive and that the last index is below `checkpoint_layers = 26`
  (`private_block/trained_statement.rs:164`, `785-797`); `RunShape::new(sh, p.layers.len(), …)` takes the count from the
  statement (`token_io/classify_cli.rs:765,924`, per the sub-agent). So a receipt over a consecutive sub-range of the 26
  layers is accepted by the code's verifier for a statement that lists that sub-range. The Lean top covers runs with
  `ShieldRun Rp` (all 26 layers, in order: `shdP_blks_length`), and the numbers 28 and 27 (segments, OUT-C's stage
  index) follow from 26. This is sound for the top as stated (it is a premise), but the model-to-code correspondence
  holds only when the verifier's public statement lists all 26 layers; the app or the verifier policy must pin that
  (the calibration and schedule digests in the header bind whatever list the statement carries). Decision for the
  coordinator: record that the verifier policy pins 26 layers from 0, or add the sub-range case to the model.

### 1f. Full check

* **merge38 (iter210, guard run 2e799b97690e): RED on two script defects, no Lean defect.** Every Lean verdict was green
  (root build rc 0, 586 of 586 audited, standard axioms, 23 + 1 top reports, Statements.lean unchanged, root diff exact,
  0 modified existing files, L6 / L5 / L11 / L1 and `RunStgShieldInstCheck: 158 checks, 0 failed`). The two defects:
  (1) the new regression's axiom count read a log whose indented per-kind lines the joining `awk` glued onto the last
  report (10 reports, "other axioms 1" being that glued line); fixed by reading the raw log; (2) the name-clash script
  flagged the new file's top-level `main` against every other executable check's `main`; fixed by setting aside `main`
  of a lane file the root does not import (printed as "set aside"). Log kept as check_merge38.log.
* The same job's probe (probeTY19, a copy of leg 18's probeTY18a): the 25 tops' elaborated types and the 15
  declarations of L68b-3 are byte-identical with leg 18's dumps (`tops_types_19.txt`, `decls15_19.txt` = the `after18`
  files). No existing file under formal/ was edited this leg; the new file is not in the root.
* **merge39 (iter211, guard run 24002a82f0bf): GREEN.** 216 s job wall, peak RSS 3.80 GiB; root build rc 0, 0 warnings;
  586 of 586 audited, standard axioms only; blkAlive and newer tops 23 of 23, L62 top 1; source scan clean; generators 0;
  name clashes 0 (the check's `main` set aside); Statements.lean unchanged; root diff exact; 0 modified existing files;
  regressions L6 1206, L5 5553, L11 404, L1 101956, **RunStgShieldInstCheck 158**, all 0 failed; its 10 axiom reports
  standard. Log check_merge39.log.

## Part 2. A design probe: the lane's chain over a block-profile parameter

### 2a. How the lane reaches the profile (ARGUED, grep of the 122 `RunStgShield*` files and the 25 generators)

68 of the 122 `RunStgShield*.lean` files name 4577 / 4390, an R13 identifier, a `shdP_` instance or `shdRk*`. By kind:

* **Numbers in a proof step (arithmetic):** only `8 * 4577 ≤ Lq` and `8 * 4390 ≤ Lq` (`fun _ => by change … ; omega`,
  the `hfBA` / `hfBH` arguments) in TopSJ, ClSJ, TopL (2 sites), ClTopL (2), ClTopLO (2), emitted by `l63_mk_topl.py`
  and `l63_mk_lo.py` (the other 23 generators carry no profile number).
* **Tables evaluated by `decide`:** `shdSD_shieldSlots_deg` (the 23 degrees in `[1, 5]`, SlotDeg), `shdIC_kinds` (this
  leg's check). In other lanes: `cnt_sums`, `cnt_terms`, `r13_shield_counts` (L31), `shield_len` (L17),
  `progR13_shield_cnt*` (L49), `rkR13_ok` (L48).
* **Passed along only:** the premise `hbpRows : ∀ k < Lb, (bp k).pA.rows = 4577 ∧ (bp k).pH.rows = 4390` (ClPins, ClTrO,
  TopIO, TopDz, TopPd, TopTrO, TopTrI; discharged by `⟨rfl, rfl⟩` at `shdP_rtBlk` in TopSJ / ClSJ and consumed in
  lane L64's `RunBlkAliveR13`); `RkPcsR13` hypotheses (41 files) and `rkR13` (32 files): R13's CODE geometry
  ⟨16, 14, 256, 24448, rows, 64⟩, not the Shield block's; the generated tops' notations through `shdP_Pk0` (9 files),
  `shdP_rtBlk` (11), `shdP_sgeom` (11), `ShieldRunAtD` (13), `shdRkD` (19), `logupSumR13` (9), `R13.blkDim` (6), and the
  literals `27 2 256 28 1`, `256 256 256 16 16 12 26`, `15 8 14`, `38`, `14`, `768` in the statements.
* So the lane's own proofs read the profile in two arithmetic facts and one degree table; everything else enters through
  other lanes' instances: `shdP_blkParams` / `shdP_Pk0` (L68a), `shdP_rtBlk` / `shdP_sgeom` / `shdP_runV` /
  `shdP_rtRun` (L67 / L68), `shdRkD` / `shdRkBase` (L66), `BlkLists` / `shieldAlkL` / `shieldMlkL` (L64),
  `rdBlkR13B_shield` (L62), the block statement (L49), `RkPcsR13` / `rkR13` (L48 and the R13 opening lanes).

### 2b. The record (ARGUED design)

`BlkProf` would carry:
* **tables:** slot schedule `(n, e, d)`, terminal counts, draws, kinds, `A` / `H` commitment schedules;
* **numbers:** mask specs `S`, `A` / `H` groups and rows, endpoint rows, functionals, claim counts `nA` / `nH`, index
  squeezes `mI`, block `Dim`, row width, ceiling;
* **code geometry:** an `OGeo` (`h, lc, Q, e, mI`) with the coset point, the column evaluator and the PCS field, replacing
  `rkR13` / `RkPcsR13` by `rkAt g` / an `RkPcs g` predicate (L48 already has `rkAt`);
* **per-layer program:** `define`, the public tables, the LogUp sum claim (functions of the layer and its public data);
* **stage and run numbers:** stage `log_n`, rates, endpoint `log_n` / rows, IN-C / OUT-C geometries, block count, and
  the derived `15 8 14`, `768`;
* **proof fields** (the facts the proofs use): degrees in `[1, 5]`, `slots.length = terms.length`, `8 · rA ≤ 2^20`,
  `8 · rH ≤ 2^20`, `rowsOf .a = rA`, `rowsOf .h = rH`, the commitment-schedule facts (`DefCm`, `cnt_sums` / `cnt_terms`
  analogues), the code geometry's `Ok` and its column-round bound, the layout facts `ShieldBlkAtD` asks
  (`W16Layout`, `LayR`, `dPos`), and the block statement at every layer (L49's `block_knowledge_r13_shield` analogue).

### 2c. The probe (CHECKED; scratch file, not committed: guarded iter211, run 24002a82f0bf)

A scratch file (outside the repository) defines a cut-down `BlkProf` (tables, numbers, `rowsOf`, `Dim`, ceiling, kinds,
`define`, `logup`, `pcs`, and five proof fields: `rowsOf_a`, `rowsOf_h`, `deg`, `fitA`, `fitH`), the block parameters as
a function of it (`blkParamsOf B tag ioIn ioOut co Ly Pb`), and `profShieldR13`. It proves:
* `blkParamsOf_R13 : blkParamsOf profShieldR13 … = shdP_blkParams …` by **`rfl`** (the committed instance IS the
  generic one at R13);
* `gen_of_slots`, `gen_blkParams` (the lane's slot-degree theorems over any `B`; the proof is `shdSD_of_slots`'s with
  `B.deg` for `shdSD_shieldSlots_deg`) and `gen_fit` / `gen_fit_blk` (`8 · rows ≤ Lq` from `B.fitA`, `B.fitH` and
  `2^20 ≤ Lq`, no `omega` on literals);
* `rec_shdSD_blkParams`, `rec_shdSD_Pk0`, `rec_fit`: the committed `shdSD_blkParams`, `shdSD_Pk0` and the `hfBA` /
  `hfBH` facts recovered from the R13 instance; `example : @rec_shdSD_blkParams = @shdSD_blkParams := rfl` (and the same
  for `shdSD_Pk0`) confirm the recovered statements are the committed ones, type for type.

Result: **it went through on the first run**, rc 0, axioms `propext`, `Classical.choice`, `Quot.sound`. Wall time 3 s
for the file, of which about 2 s is the import (the import-only baseline in the same job), so the probe's own
elaboration is about 1 s: an abstract profile costs nothing measurable here. What had to change in the proofs: only the
two R13 facts used (the `decide` on the 23 degrees, the `omega` on 4577 / 4390) became record fields; the `decide`
moved into the instance (`profShieldR13.deg := shdSD_shieldSlots_deg`), and the recovery of `shdSD_Pk0` still goes
through L68a's `shdP_Pk0_eq_blkParams` (an R13-specific equation: a generic `shdP_Pk0` would need its own).

### 2d. Estimate (ARGUED)

* **The lane's own chain generic:** the record and the R13 instance in a new lane file (about 1 leg, mostly the proof
  fields `ShieldBlkAtD` and the opening geometry ask); the two generators that emit profile numbers and the generators of
  the 23 tops take `B` and regenerate (the statements gain one binder and lose the literals; 1 to 2 legs with the
  byte-identity comparisons of the R13 instances); **2 to 3 legs in all.**
* **What stays R13-only afterwards (other lanes' files):** L49's block statement (47 files: the extracted planes,
  lookups and program at `cfgShieldR13` at every layer), L62's `rdBlkR13B_shield`, L64's `BlkLists` / `shieldAlkL` /
  `shieldMlkL` and `RunBlkAliveR13`'s `hbpRows` consumer, L66's `shdRkD` / `shdRkBase` (R13 lists and `RkPcsR13`),
  L68a's `shdP_blkParams` / `shdP_Pk0` (their equations), L67's `shdP_rtBlk` / `shdP_runV`, and every `RkPcsR13` /
  `rkR13` user. The generic lane chain would state "for every profile that supplies these", and only R13 supplies them
  until those lanes produce a W16R2 / W16R3 instance (the 12 to 25 legs of L68B3_REPAIR Part 3).
* **When:** after a production profile is chosen. Before the choice it saves nothing (the expensive part, the block
  statement per profile, is other lanes' and does not get cheaper), and it adds churn to 23 generated tops. One cheap
  step is worth doing early if a W16R3 decision is imminent: commit the record plus the R13 instance and the `rfl` tie
  (the probe's first half, under a day), so that later lanes can target `BlkProf` instead of copying `shdP_blkParams`.
