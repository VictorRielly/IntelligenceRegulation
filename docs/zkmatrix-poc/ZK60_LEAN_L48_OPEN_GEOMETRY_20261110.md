# ZK60 Lean lane L48: the opening width as a parameter, the real geometries, and the input commitment at its real geometry (2026-11-10)

Lane L48 of D63 (Claude Opus 5.5), on its own worktree holding perf `a0fe9e98` (lane L45 merged, decision row D77a).
Lean 4.34.1, Mathlib v4.34.1, no new dependency. Evidence: `results/zk60_lean_l48_20261110/`. It repairs finding
L45-2 (High): the Lean opening model fixed every opening's message width at `2^14`, the block geometry, while the
code's only registered token-I/O tier opens the two stages at `2^12` and the classifier's input commitment at `2^8`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (a script or Lean checker this lane ran against the code, with its log and a negative control),
**MEASURED**, **ARGUED** (reading the code, not a theorem), **ESTIMATE**, **LEFT** (not done).

**STATUS.** Deliverables 1, 2 and 3 DONE, green and committed. Deliverable 4 carried to the app's top theorem at the
real widths (`og_productionReadyL_epP_exec_blk`, with L46's block cover carried in); what is left of it is listed in
section 5 by premise name.

## 1. In plain words, for Victor

**What was wrong.** Every commitment the verifier opens is a table whose rows are encoded with an error-correcting
code. The Lean model of the whole classify run assumed every such table has `16,384` columns per row (`2^14`). That is
true of the 26 blocks. It is not true of the two token stages (`4,096` columns) or of the commitment to your input
(`256` columns, encoded to `2,048`). So three of the top theorem's premises could never be met by the real run, and
the input-commitment instance of your ruling D77 (1) was built at the wrong size.

**What this lane did.**
1. The width is now a parameter of every opening in the Lean model. The blocks are the special case `2^14`, and every
   theorem that existed before is still there and still says what it said at the blocks.
2. The real widths are named in Lean, and a checker compares them with the code: the tier constants in the source,
   and the parameters a real classifier run recorded (lane L29's export). 29 checks pass; 21 deliberately broken
   copies are all refused.
3. Your ruling D77 (1) is rebuilt at the real input commitment. The largest unique-decoding radius is exactly
   `768` of `2,048` columns (D77a's estimate was right). Binding holds at the approved target. The spot check misses
   more than `768` bad columns with probability at most `2^-173` per query (the coordinator's estimate `2^-174` was the
   rounded figure). The instance with the executable stages is `classifyProtocolUExecEp`.
4. The app's top theorem is restated at the real widths: stages at `2^12`, blocks at `2^14`, input at `2^8`, with the
   stage premises now PROVED to be met by the real stage verifiers.

**What is still open.** The same open premises as before (the slots, the draws, LogUp, the doom covers other than the
blocks', the closing openings of parts `1` and on), plus one new, small one: where the run header absorbs your input's
root (the header is still a free parameter of the run model, finding L45-1).

## 2. What is proved

All in namespace `ZK60.Exec.Link` (geometry), `ZK60.Exec` (the commitment), `ZK60.ProtocolClassify` (the run), or
`ZK60.ProtocolClassify.RunShapeP` (the top theorems). Every declaration on at most `propext`, `Classical.choice`,
`Quot.sound` (section 7).

### 2.1 Deliverable 1: the opening geometry as a parameter (`RunOpenGeo.lean`, the edited files)

| Theorem or object | Meaning |
|---|---|
| `RWL`, `RWL_of_le`, **`RWL_14`** | the row form at width `2^lc` (the interpolant on `G_{2^lc}`, `lc ≤ 32`); at `14` it is L28's `RW` |
| `encGL`, **`encGL_14`**, **`encGL_injective`**, `og_side` | the encoder at `(lc, h, Q)`; at `14` it is L28's `encG`; injective when `2^lc + Q ≤ 2^h`; the radius's side conditions at any width |
| `OGeo`, `OGeo.Ok`, `ogR13`, **`ogR13_ok`** | an opening's code geometry `(h, lc, Q, e, mI)` and its conditions; the block geometry `(16, 14, 256, 24448, 64)` |
| `RtOpen` (field `lc`), `RtOpen.opA`, `RtOpen.opB`, `RtOpen.Valid`, **`RtOpen.opA_rbr`**, **`RtOpen.opB_rbr`** | L34's opening of the run at its own width (RunTrKinds.lean, edited) |
| `RkGeo` (field `lc`), `RkGeo.Ok`, `rkR13`, `rkAt`, **`rkAt_ok`**, `rkR13_eq`, `rkOpen`, `rkData_opA_cl` … | L43's run geometry and readers at their own width (RunKindsData.lean, edited) |
| **`rh_opB_alive`**, `RhOpW` | L43's second-half liveness at any width (RunHalOpB.lean, edited) |
| `RkPcsAt`, `RkPcsAt.hm`, **`RkPcsR13.at`** | an opening verifier's numbers at any code geometry; `RkPcsR13` is `RkPcsAt ogR13` (RunHalBlk.lean, edited) |
| **`rs_inc_opAG`**, **`rs_inc_opHG`**, **`rs_outc_opAG`**, **`rs_outc_opHG`** | L45's stage openings' acceptance facts at any geometry; `rs_inc_opA` … kept as their instances at `ogR13` |
| **`rx_inc_opAG`**, **`rx_inc_opHG`**, **`rx_outc_opAG`**, **`rx_outc_opHG`** | the same outright outside `EvXR` (any geometry with `Q ≤ 256`); `rx_inc_opA` … kept |
| `rxDinG`, `rxDoutG`, **`rx_parts_AHG`**, **`rx_parts_MG`** | L45's parts' `A`, `H`, `M` facts with the stages at any geometry; `rx_parts_AH`, `rx_parts_M` kept |
| **`rh_opB_alive_14`**, **`rkData_opA_cl_14`**, `rkData_opH_cl_14`, `rkData_opX_cl_14`, `rkR13_lc` | (RunOpenGeoBlock.lean) the statements whose text changed, in their OLD form at width `14` |

### 2.2 Deliverable 2: the real geometries (`RunOpenGeoTier.lean`, `RunOpenGeoCheck.lean`)

| Theorem or object | Meaning |
|---|---|
| `OTier`, `tierR1` | the code's only registered tier `R1_MVP`: `opened_cols 256`, stages `2^12` rate `1/4`, endpoints `2^8` rate `1/8` |
| `ogStage`, **`ogStage_tier`** | the stages' geometry `(14, 12, 256, 6016, 64)`; it is the tier's |
| `ogEp`, **`ogEp_tier`** | the input endpoint's geometry `(11, 8, 256, 768, 64)`; it is the tier's |
| **`ogStage_radius`**, **`ogStage_e_largest`** | `2·6016 + 2^12 + 256 = 2^14`; `2e + n + Q ≤ N` exactly when `e ≤ 6016` |
| **`ogEp_radius`**, **`ogEp_e_largest`** | `2·768 + 2^8 + 256 = 2^11`; `2e + n + Q ≤ N` exactly when `e ≤ 768` |
| **`opB_eps_stage`**, **`opB_eps_ep`** | the column rounds: `≤ 2^-169`, `≤ 2^-173` |
| **`opA_eps_stage`**, **`opA_eps_ep`** | the first rounds (`N/p²`·bias): `≤ 2^-112`, `≤ 2^-115` |
| **`ogStage_ok`**, **`ogEp_ok`** | both meet `OGeo.Ok` |
| `RunOpenGeoCheck.lean` (executable) | CHECKED: the definitions against lane L29's real classifier corpus and the production sources (section 7) |

### 2.3 Deliverable 3: the input commitment at its real geometry (`BindingEP.lean`, `ProtocolClassifyEP.lean`)

| Theorem or object | Meaning |
|---|---|
| `epForm`, `epPts`, `ep_pts_injective`, `ep_hNQ` | the endpoint code: interpolant rows on `G_{2^8}`, the coset `7·G_{2^11}` |
| **`epPlaneCommit`**, **`epTokenCommit`**, `epTokenCommit_plane`, `epTokenCommit_ok` | the classifier's input token commitment at the real geometry (depth `11`) |
| **`ep_radiusU`**, **`ep_radiusU_max`**, `epPlaneCommit_radiusU`, `epPlaneCommit_largest` | the radius `768` is valid and the LARGEST (`769` breaks it) |
| **`ep_open_code_factsU`** | minimum distance `1,537`, `2·768 < 1,537`, correlated agreement with `A = N` |
| **`xA_eps_ep`**, **`xB_eps_ep`** | the column test's rounds: `≤ 2^-115`, `≤ 2^-173` |
| `rowFormK8`, `rowFormK8_ext_ep`, **`closeIn_ep_iff`**, `rowFormK8_eq_RWL` | L30's extension-to-base code fact at the endpoint code; the test's row form is the run model's `RWL 8` |
| `XTest.εA_ep`, `XTest.εA_ep110`, **`XTest.εB_ep`** | the endpoint test's rounds at its parameters |
| **`classifyU_binding_ep`** | `Binding` at the approved target, every `q`, at the real input commitment, radius `768` |
| **`classifyU_O11d_ep`** | L26's O11d at the real commitment: `hokC`, `hplane` PROVED, `hX` DISCHARGED through the test's two kinds and L30's code fact |
| **`classifyProtocolUExecEp`** | D77 (1)'s instance as it should have been: L30's `classifyProtocolUExec` at `epTokenCommit`, `e = 768` |
| `classifyUExecEp_verify`, `classifyUExecEp_opensIn`, **`classifyUExecEp_binding`**, `classifyUExecEp_complete`, `classifyUExecEp_zk` | its verifier is `classifyProtocolExec`'s; its opening is `OpensU` at `768`; binding; completeness and ZK carried from L18's instance |

### 2.4 Deliverable 4: the app's top theorem at the real widths

| Theorem | Meaning |
|---|---|
| **`rcPcsAt_stage`**, **`rcPcsAt_ep`** | (RunOpenGeoStage.lean) L29's `pcsAt` at `log_cols 12` rate `1/4` (resp. `8`, `1/8`), `256` checks, meets `RkPcsAt` at `ogStage` (resp. `ogEp`), its column evaluator meeting `ColEncSpec` at `RWL 12` (resp. `8`) |
| **`rcIncAt_pA_stage`**, **`rcIncAt_pH_stage`**, **`rcOutcAt_pA_stage`**, **`rcOutcAt_pH_stage`** | the real stage contracts (L39's `rcIncAt`, `rcOutcAt` at L29's verifiers) at the tier's numbers meet `hIA`, `hIH`, `hOA`, `hOH` |
| **`rcIncAt_pX_ep`** | stage IN-C's closing opening (the input endpoint) meets `RkPcsAt ogEp` |
| **`og_productionReadyL_r13P_exec_stage`** | (RunOpenGeoTop.lean, generated by `l48_mk_top.py`) L45's top theorem with `hIA`, `hIH`, `hOA`, `hOH` at `ogStage` |
| **`rs_inc_opXG`**, **`rx_inc_opX`**, `og_closes_canon`, `rx_stmtInRoot_mem` | (RunOpenGeoStageX.lean) part `0`'s closing opening (the input endpoint) meets `RhOpW` at any geometry: from the acceptance up to its extraction, and outright outside `EvXR` given `hInAbs` |
| **`og_hopX0`** | exactly the `i = 0` instance of the top theorem's `hopX` (at `rxPs`, `rxAcc`), when part `0`'s closing geometry is the endpoint's (`(base 0).gX = rkAt ogEp …`, `(base 0).nX = I.nIn`) |
| `og_productionReadyL_run_epP_some_range` … `og_productionReadyL_epP_exec_rk` | (RunOpenGeoEP.lean, generated by `l48_mk_ep.py`) the chain the top theorem is proved through, with the input commitment at `epTokenCommit`, radius `768`, the test at `2^11` |
| **`og_productionReadyL_epP_exec_stage`** | THE APP'S TOP THEOREM AT THE REAL WIDTHS: stages `2^12`, blocks `2^14`, input `2^8` / rate `1/8` / radius `768` |
| **`og_productionReadyL_epP_exec_blk`** | the same with lane L46's block cover carried in (`hdblk` replaced by the blocks' bundles `RdBlkR13`, through `rd_hdblk`) |

## 3. The numbers

| Figure | Value | Label |
|---|---|---|
| block openings (R13 Shieldstral T128) | `2^14` columns, `N = 2^16`, `Q = 256`, `e = 24,448` | PROVED (`ogR13_ok`); `log_cols 14` CHECKED in `shape.rs` |
| stage openings (R1_MVP) | `2^12` columns, rate `1/4`, `N = 2^14`, `Q = q_pad = 256` | CHECKED (corpus `INP`, `INDIM`, `INPCS`, `OUTDIM`, `OUTPCS`; source `R1_MVP`) |
| stage radius (largest) | `e = 6,016` (`2e + 4,352 = 16,384` exactly) | PROVED (`ogStage_radius`, `ogStage_e_largest`) |
| stage column round, first round | `≤ 2^-169` (`2^-169.03`), `≤ 2^-112` | PROVED; decimals ESTIMATE |
| input commitment (R1_MVP) | `2^8` columns, rate `1/8`, `N = 2,048`, `256` checked, `256` pads, depth `11`, `1` data row + `5` mask rows at the corpus's rung | CHECKED (corpus `INDIM`, `INPCS`, `INGEO`, `INDERIV`; source `input_endpoint_spec`, `ZkOpts::standard`, `MASK_ROWS`) |
| input radius (largest; D77 (1)) | `e = 768` (`2e + 512 = 2,048` exactly; `769` fails) | PROVED (`ep_radiusU`, `ep_radiusU_max`, `ogEp_e_largest`) |
| columns that must open | `2,048 − 768 = 1,280` of `2,048` (62.5 %) | PROVED (arithmetic of the radius) |
| input column test per query | `((2048 − 769)/2048)^256 ≤ 2^-173` (`2^-173.88`) | PROVED (`xB_eps_ep`); decimal ESTIMATE |
| input column test, round 0 | `2^11/p²·bias ≤ 2^-115` | PROVED (`xA_eps_ep`) |
| input binding | `N · collBound ≤ q·2^-100 + 2^-100`, every `q` (`N = 2^11 ≤ 2^20`, depth `11 ≤ 64`) | PROVED (`classifyU_binding_ep`) |
| the top theorem's joint budget at the real endpoint | the R13 gate's `55,525,211 ≤ 2^26` (the test's first-round constant kept at `2^16` via `XTest.εA_ep110`; a `2^11` constant is available) | PROVED (`eleven_bud_r13` reused) |
| the code's own pricing of the same commitments | stage `2^-103.69`, endpoint `2^-106.25` per opening (D15's δ/3 count, `hiding_opening_log2`) | ARGUED (code; the Lean bound is the unique-decoding count, finding L48-2) |

## 4. The files

New (this lane's prefixes): `RunOpenGeo.lean`, `RunOpenGeoTier.lean`, `RunOpenGeoStage.lean`, `RunOpenGeoTop.lean`
(generated), `RunOpenGeoBlock.lean`, `RunOpenGeoStageX.lean`, `RunOpenGeoEP.lean` (generated), `BindingEP.lean`,
`ProtocolClassifyEP.lean`, all imported by the root; `RunOpenGeoCheck.lean` (an executable checker, not imported).

Edited in place under the brief's exception (each change forced by the width; every edited file's header says so):

| File | Change | Why |
|---|---|---|
| `RunTrKinds.lean` | `RtOpen` field `lc`; `opA`, `opB`, `Valid.he`, `opA_rbr`, `opB_rbr` at `encGL lc` / `RWL lc`; imports `RunOpenGeo` | L34's opening hard-wired `Fin (2^14 + Q)`, `encG`, `RW` |
| `RunKindsData.lean` | `RkGeo` field `lc`; `RkGeo.Ok.he`; `rkR13` at `14`; `rkOpen`'s claims at `g.lc`; `rkData_op*_cl` at the part's width; new `rkAt`, `rkAt_ok`, `rkR13_eq` | L43's run geometry hard-wired `14` |
| `RunHalOpA.lean` | `rh_KA_al` at `encGL` | it named `encG`, `2^14` |
| `RunHalOpB.lean` | `rh_opB_alive`, `RhOpW` at `g.lc`, `RWL g.lc` | L43's lemma asked `logCols = 14`, `RW` |
| `RunHalBlk.lean` | new `RkPcsAt`, `RkPcsAt.hm`, `RkPcsR13.at` | the stages need a non-R13 premise |
| `RunStageRdHal.lean` | `rs_inc_opAG` … `rs_outc_opHG`; the old four as instances | L45's stage lemmas asked `RkPcsR13` |
| `RunExtractStage.lean` | `rx_inc_opAG` … `rx_outc_opHG`; the old four as instances | the same, plus the path depth `16` → `g.h` |
| `RunExtractParts.lean` | `rxDinG`, `rxDoutG`, `rx_parts_AHG`, `rx_parts_MG`; `rxDin_eq`, `rxDout_eq`; the old as instances | L45's parts built the stages at `rkR13` |
| `ZK60Formal.lean` | nine import lines | the new modules |

Every other existing theorem kept its statement text. The ones whose text had to change (`rh_opB_alive`,
`rkData_opA_cl`, `rkData_opH_cl`, `rkData_opX_cl`) are restated in their OLD form at width `14` and PROVED
(`rh_opB_alive_14`, `rkData_op*_cl_14`; the claims' version is a heterogeneous equality, since the type now carries
the width). The structures `RtOpen`, `RkGeo`, `RhOpW` changed (a field, or a field's statement); at the blocks the new
field is `14` by definition (`rkR13_lc`). `Statements.lean` is unchanged.

## 5. What is left, premise by premise (the final theorem `og_productionReadyL_epP_exec_blk`)

Introduced or discharged by this lane, and whether the real objects meet them:

| Premise | Status | Met by the real objects? |
|---|---|---|
| `hIA`, `hIH`, `hOA`, `hOH` | now `RkPcsAt U tag ogStage …` | YES: PROVED at `rcIncAt` / `rcOutcAt` at the tier's numbers (`rcIncAt_pA_stage` …), the numbers CHECKED against the code |
| `hBA`, `hBH` | unchanged (`RkPcsR13`, the blocks) | as L43 (block geometry, `r13_colEnc_spec`) |
| `hD` (via `rkData_valid`): each part's `gA.Ok`, `gH.Ok`, `gX.Ok` | now at the part's width | YES: stages `rkAt_ok ogStage ogStage_ok`; part `0`'s closing opening `rkAt_ok ogEp ogEp_ok` (it was unmeetable before: `2e + 2^14 + 256 ≤ 2^11` is false) |
| the input commitment `CinR := epTokenCommit …`, radius `768`, `hr`, `hon` | the real geometry | YES for the geometry and radius (PROVED, CHECKED); `hon` (the honest opening data) as before |
| the test `T : XTest F (Fin Rr) (Fin (2^8 + 256)) Cl 11`, `hTenc` (its code `encLin epPts (rowFormK8 F)`), `hTe : T.e = 768`, `hTQ : T.nQ = 256`, `hβLR`, `hβJ`, `hw0`, `hF` | the real endpoint test | the code facts it needs exist (`ep_open_code_factsU`); building `T` from the run's transcript is the endpoint lane's (as at L30) |
| `Ux`, `Xx`, `ops` over `Fin (2^11)`; `hwin`, `hread`, `hBal`, `hdzero`, `hE`, `hops`, `hcan`, `mk` | as L45 (now at the real width) | LEFT (the endpoint's reading of the run; L46 item 5) |
| `hopX` | as L45 (all parts) | its part-`0` instance (the input endpoint, at `ogEp`) PROVED by `og_hopX0` outside `EvXR`, given `hInAbs` (where the header absorbs `s.inRoot`, finding L48-3), `rcIncAt_pX_ep`, and the choice `(base 0).gX = rkAt ogEp …`, `(base 0).nX = I.nIn`; parts `1 …` (the boundaries, `B_out`) LEFT |
| `hdblk` | GONE in `og_productionReadyL_epP_exec_blk` (L46's `hblk` bundles) | as L46 |
| `hW` | as L45 (finding L45-1) | IN-C `rfl`; OUT-C needs the verdict off the header |
| `hal_slots`, `hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`, `hal_LU`, `hdin`, `hdout`, `hdzero` | as L45 / L46 | LEFT |
| `hσ`, `Iin`, `Oout`, `bp`, `hgeo`, `wXk`, `gXk`, `mXk`, `cx0`, `pin`, `pout`, `base`, `eL`, `hDe`, `hlsc*`, `hmIn`, `hk*`, `ht*`, `hf*`, `hLb`, `hU`, `O`, `hzk` | as L45 | as L45 |

## 6. Findings

**L48-1 (Info; for Victor and the coordinator): D77a's estimate confirmed.** At the real input commitment the largest
unique-decoding radius is exactly `768` (`2·768 + 256 + 256 = 2,048`), and the spot check misses more than `768` bad
columns with probability at most `2^-173` per query (`2^-173.88`; D77a's `2^-174` was the rounded figure). PROVED.
D77 (1)'s instance is now `classifyProtocolUExecEp` (`ProtocolClassifyEP.lean`); L26's `r13TokenCommit` instances stay
in the tree but describe a geometry the code does not use for the input commitment. The decisions register's pointer
for D77 (1) should name the new instance (the coordinator's).

**L48-2 (Low; for the coordinator): the code and the Lean model price the stage and endpoint openings differently.**
The code's tier door prices the stage and token-endpoint commitments with D15's general-code count
(`hiding_opening_log2`: `(1 − δ/3)^Q`, `2^-103.69` per stage opening, `2^-106.25` per endpoint opening), while the Lean
model proves the unique-decoding count at these geometries (`2^-169` and `2^-173` for the column round, `2^-112` and
`2^-115` for the first round). The Lean bound is the stronger, so nothing is unsound; but the B-1 floors the door
enforces are not the figures the proofs use. ARGUED.

**L48-3 (Medium; for the endpoint lane): where the run header absorbs the input root is not modelled.** `rx_inc_opX`
needs `hInAbs`: the run's transcript absorbs `s.inRoot` at a fixed position. The run header is a free parameter of L34's
`rtRunClassify` (the same gap as L45-1's verdict). Once the header is the code's, `hInAbs` is a lemma like L45's
`rs_incPre_get`.

**L48-4 (Info): L45's top theorem stays in the tree, true but inapplicable.** `rx_productionReadyL_r13P_exec_own`
still asks `RkPcsR13` of the stages and the R13 input commitment; it is proved, but its premises cannot be met by the
real run (L45-2). `og_productionReadyL_epP_exec_blk` is the form to use.

**L48-5 (Low; for the coordinator): `EvXR` and `rxVx` keep two fixed numbers.** `EvXR` hard-codes the blocks' openings
(`256 256 256 16 16 12`), right for R13's blocks; `rxVx` checks the first `256` columns of each other opening, hence the
premise `g.Q ≤ 256` of the generalized stage lemmas (met: `Q = 256` at R1_MVP). A profile with more column checks
needs both parameterized.

**L48-6 (Info): the corpus is the development rung.** L29's corpus is a classifier run at the rung
`private-classify-run-rung-tc-t32-public-row-dev/2`, not R13 Shieldstral T128. The stage and endpoint geometries are
the TIER's, not the shape's, and the source check confirms `R1_MVP` is the only registered tier and the classifier
door refuses any other (`tier.check()?`). The blocks' `2^14` at R13 T128 is checked in `shape.rs` only (text).

**L48-7 (Info): the endpoint test's first-round constant.** The generated top theorem reuses the R13 gate's budget by
weakening the endpoint test's first round to `2^-110` (`XTest.εA_ep110`; proved `2^-115`). The budget is within the
target either way.

## 7. Checks

`results/zk60_lean_l48_20261110/check_l48.sh`, one guarded cpu job (`lean-l48-iter`, need 24 GiB, cap 36 GiB,
`LEAN_NUM_THREADS=4`). All figures MEASURED; logs in the evidence directory (`check.log`, `full.log`,
`axioms_flat.log`, `nameclash.log`, `geocheck.log`, `negative.log`, the regression logs). The modules were built
first in guarded iterations (`iter1` … , logs kept).

The run of record is iteration 11 (`iter11.log`; the guard's record: exit 0, 283 s, peak 12.64 GiB), on perf
`a0fe9e98` plus this lane.

| Check | Result |
|---|---|
| each L48 module built alone (nine) | 9 of 9 green, 0 warnings |
| full `lake build` | green, 3,723 jobs, 0 warnings, 0 errors, no `sorry` |
| axiom audit (`gen_axioms.py`) of every declaration of the nine L48 files AND of the eight edited files | 245 of 245 (172 theorems, 56 definitions, 17 structures): 195 on `propext`, `Classical.choice`, `Quot.sound`; 17 on `propext`, `Quot.sound`; 14 on `propext`; 19 on none; `sorryAx` 0, `ofReduceBool` 0, other axioms 0 |
| source scan for the forbidden words (the L48 files, the checker, the edited files) | none |
| root imports | the nine modules imported (the checker not); no import line removed |
| existing files changed | only the eight exception files and the root's imports; `Statements.lean` unchanged; no Rust |
| name clashes (`l48_nameclash.py`, 40 worktrees, 4,188 other Lean files) | 0 (118 names: the new files' and the 20 added to the edited files) |
| generated files are their generators' output | `RunOpenGeoTop.lean` (`l48_mk_top.py`), `RunOpenGeoEP.lean` (`l48_mk_ep.py`): identical |
| agreement with the code (`RunOpenGeoCheck.lean`) | 29 checks, 0 failed |
| its controls (`l48_negative.py`) | 22 cases, all as required |
| regressions | L6Check 1,206, L5Check 5,553, L11Check 404, fixture L1 101,956 checks; 0 failed in each |

The agreement check (`RunOpenGeoCheck.lean` on `results/zk60_lean_l29_20261107/corpus.txt` and the production sources):

| Kind | What | Result |
|---|---|---|
| CORPUS | the export is L29's; the run's tier `stage_log_n 12` (IN-C and OUT-C), `ep_log_n 8` | 3 of 3 |
| STAGE | IN-C's and OUT-C's `A`/`H` `Dim::of(params)` = `(256, 4352, 16384, 14)`, log inverse rate `2`, `256` checks | 4 of 4 |
| ENDPOINT | the input endpoint spec's `Dim` = `(256, 512, 2048, 11)`, log inverse rate `3`, `256` checks, `1` data row of `2^8` words, `6` committed rows | 3 of 3 |
| LEAN | `ogStage`, `ogEp` are `tierR1`'s; the radii are the largest | 3 of 3 |
| SOURCE | `R1_MVP`'s five levers; `REGISTERED = [R1_MVP]`; the door; `stage_params`; the stages' `lt`; `input_endpoint_spec`; `ZkOpts::standard`; the endpoint's parameters and five mask rows; R13 T128 `log_cols 14`; the boundary default | 16 of 16 |
| total | | **29 checks, 0 failed** |
| negative control (`l48_negative.py`) | one unchanged copy (passes) and 21 single changes, 11 to the corpus and 10 to the sources (each refused) | **22 cases, all as required** |
