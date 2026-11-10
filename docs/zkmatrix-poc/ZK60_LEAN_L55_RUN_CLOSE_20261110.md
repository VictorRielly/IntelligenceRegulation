# ZK60 Lean lane L55: the stages' readers off the code's header (`hW`), the verdict refusal, and the closing openings of parts `1` on (`hopX1`) (2026-11-10)

Lane L55 of D63 (Claude Opus 5.5), on its own worktree holding perf `2e5cde97` (lanes L49 and L52 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Evidence: `results/zk60_lean_l55_20261110/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (a script or Lean checker run against the code, with its log and a negative control), **MEASURED**,
**ARGUED** (reading the code or the Lean, not a theorem), **ESTIMATE**, **LEFT** (not done).

**STATUS.** Deliverable 1 DONE, green, committed: `hW` PROVED at the code's header (`vd_hW`), with finding L55-1 (High:
the Lean verifier omits the code's refusal of a verdict above `1`; without it `hW` cannot be met, and neither can
`hdout`; repaired in Lean, no code change). Deliverable 2 DONE, green, committed: both closing geometries (the
boundaries and `B_out`) CHECKED against the code with a negative control (24 checks, 26 controls), and `hopX1` PROVED at
EVERY part `1 … Lb + 1` (`B_in`, the blocks' boundaries, `B_out`), with the carry tied to the previous part; no new
extraction event. Deliverable 3 NOT started (§5.2). Deliverable 4 DONE: the top theorem restated in a generated chain,
ending at `cb_productionReadyL_epP_codeF`, with `hW` and `hopX1` gone; every premise still left listed by name (§5.3).

## 1. In plain words, for Victor

**`hW`: which verifier each stage used.** The app's top theorem reads, off the proof's transcript, which verifier each
of the two stages used. For the input stage that is trivial (one verifier for every statement). For the output stage the
verifier depends on the PUBLIC verdict, so the reader must find the verdict in the transcript. The code's run header
absorbs the verdict as one byte, the seventh of its eight absorbs. This lane proved that the reader that takes that byte
gets the statement's verdict, on every accepted run, at the code's header, and restated the top theorem without `hW`.

**What I found on the way (finding L55-1).** In the Lean model the verdict is any whole number; in the code it is one
byte, and the code refuses any verdict other than `0` or `1` before it reads a single segment (twice: when it reads
`statement.json`, and when it builds the statement). The Lean model of the verifier had no such refusal. That matters:
a byte cannot tell `1` from `257`, so no reader of the transcript could meet `hW`, and the output stage's soundness
premise (`hdout`, lane L53's) would also be false (a prover could claim the verdict `2` and pass the output stage's
arithmetic honestly). The repair needs no code change: the model's "statement check" of the first block now carries the
code's refusal (`vdChk`, with the code's message). On every statement the code can build it is the old check, so the
model accepts exactly what the code accepts.

**`hopX1`: the closing openings of parts `1` on.** After the input stage, every part's last opening opens the
commitment the PREVIOUS part made (a "boundary": block `0` opens the input stage's, block `k` opens block `k − 1`'s,
the output stage opens the last block's). I read their geometry off the code and checked it with a checker and 25
single-change controls: at the app's profile each boundary is `2^14` columns at rate `1/4`, `256` checks, `38` rows,
the same code geometry as the blocks' own commitments. The model so far handed each part a carry with only the NUMBER
of pending claims, so the opening could not be tied to what the previous part committed. This lane tied the carry to
the previous part (the claims it left pending, the root it absorbed, at the third absorb of its frame), and proved the
opening facts the top theorem asks at every part `1 … 27`: block `0` (`B_in`), blocks `1 … 25`, the output stage
(`B_out`). No new extraction event was needed: the run's existing Merkle event already covers these roots and columns.

## 2. What is proved

All in namespace `ZK60.ProtocolClassify` (the top theorems in `ZK60.ProtocolClassify.RunShapeP`; the geometry in
`ZK60.Exec.Link`). Every declaration on at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 Deliverable 1: `hW` (`RunVerdictW.lean`)

| Theorem or object | Meaning |
|---|---|
| `vdByte`, **`vdWout`**, **`vdWin`** | the readers: the verdict byte at header position `6` (exactly a one-byte absorb, else `0`) and `F` of it; the constant IN-C verifier |
| **`vdByte_eq`** | the byte is the verdict when the verdict is below `256` |
| **`vdChk`**, **`vdChk_eq`**, **`vdChk_le`** | the code's verdict refusal as block `k`'s statement check in front of the existing one; it IS the existing check on every verdict `0` or `1`; it passes only a verdict `≤ 1` (the premise `hchk`, met) |
| **`vd_check0_of_accept`** | an accepted run with a block passed block `0`'s statement check |
| **`vd_hdr_wrap`**, **`vd_outc_ne`** | without the refusal: the code's header is the same at verdicts `v` and `v + 256`, while stage OUT-C's verifiers there differ (finding L55-1) |
| **`vd_hW`** | THE TOP THEOREM'S `hW` IN ITS EXACT FORM, at the code's header (`hRn`), for `Win := vdWin Vi`, `Wout := vdWout F`, from `hinc` (IN-C's family constant), `houtc` (OUT-C's reads only the verdict), `hchk`, `0 < Lb` |

### 2.2 Deliverable 2: the boundary geometry (`RunCloseBGeo.lean`, `RunCloseBPcs.lean`)

| Theorem or object | Meaning |
|---|---|
| `cbBndRows`, **`cbBndRows_r13`** | a boundary's rows (`BoundarySpec::commitment_rows`: `t_pad·d_pad/2^log_n + 2·sites + 2`); `38` at R13 Shieldstral T128 |
| **`cb_bnd_geo`** | the boundary geometry at R13 Shieldstral T128 is L48's `ogR13` (`2^14` columns, `2^16` symbols, `256` queries, the largest radius `24448`, `64` index squeezes) and meets `OGeo.Ok` |
| **`rcPcsAt_bnd`**, `rcPcsAt_bnd_r13` | L29's `pcsAt` (the code's `pcs::verify_zk_tagged`) at `log_cols 14`, rate `1/4`, `256` meets `RkPcsAt ogR13` and `RkPcsR13` |
| **`rcOutcAt_pX_bnd`**, `rcOutcAt_pX_bnd_r13` (`RunCloseBEnds.lean`) | stage OUT-C's closing opening (`B_out`) at the real OUT-C contract `rcOutcAt` (`geo.bLogN = 14`, `blr = 2`, `bq = 256`) meets `RkPcsAt ogR13` / `RkPcsR13` |
| `cbBndOpen`, `cbBndPcs`, **`cbBndPcs_at`**, `cbBndPcs_r13`, `cbBndPcs_rows` | the code's boundary opening as the run's `bndOpen`, its `RtPcs` (each block's `pX` in `rcRunClassifyAt`), its numbers at `ogR13`, `38` rows at R13 |

### 2.3 Deliverable 2: the carry tied to the previous part, and the openings (`RunCloseBRun`, `RunCloseBBlk`, `RunCloseBEnd`, `RunCloseBInc`)

| Theorem | Meaning |
|---|---|
| `cb_pre_succ`, **`cb_two`** | the run's steps before part `j + 1` are those before part `j` and part `j`'s; two consecutive parts on ONE carry, each on the run's transcript before it |
| **`cb_blk_run_of`**, **`cb_outc_run_of`**, **`cb_inc_run_of`** | L43's / L45's per-part run lemmas at a GIVEN carry and step (so the carry can be the previous part's), with the carry a block or stage IN-C hands on: `⟨acc.claims.out, its boundary root⟩` (finding L55-4) |
| `cb_blockData_bRoot` | a block's data determine its boundary root (its frame's third absorb) |
| **`cb_blk_opX`** | part `k + 2` (block `k + 1`): its closing opening of `B_{k+1}` meets `RhOpW` OUTRIGHT outside L45's `EvXR`, at `rkR13 rows (off (k + 1) + 2)`, claims block `k`'s outgoing then block `k + 1`'s incoming |
| **`cb_outc_opX`** | part `Lb + 1` (stage OUT-C): `B_out` meets `RhOpW` outright, root at `off Lb + 2`, claims the last block's outgoing then OUT-C's incoming |
| **`cb_inc_opX`** | part `1` (block `0`): `B_in` meets `RhOpW` outright, root at `off 0 + 2` (stage IN-C's frame), claims IN-C's outgoing then block `0`'s incoming |

### 2.4 Deliverable 2 in the top theorem's form (`RunCloseBMid`, `RunCloseBEnds`)

| Theorem | Meaning |
|---|---|
| **`cb_hopX1_mid`** | the top theorem's `EbXW` at parts `2 … Lb` (kinds data `rxPs`, readers `rxAcc`) |
| **`cb_hopX1_one`**, **`cb_hopX1_last`** | the same at parts `1` and `Lb + 1` |

### 2.5 Deliverable 4: the top theorem restated (generated, in a chain)

| Theorem | Meaning |
|---|---|
| **`vd_productionReadyL_epP_codeW`** (`RunVerdictTop.lean`, `l55_mk_top.py`) | lane L52's `eb_productionReadyL_epP_codeT` (repair B, the column test built from part `0`'s opening; L50's alive discharges kept) with `Win := vdWin Vi`, `Wout := vdWout F` and `hW` PROVED |
| `cb_productionReadyL_epP_codeX` (`RunCloseBTop.lean`, `l55_mk_topX.py`) | the above with `hopX1` PROVED at parts `2 … Lb`, asked only at parts `1`, `Lb + 1` |
| **`cb_productionReadyL_epP_codeF`** (`RunCloseBTopF.lean`, `l55_mk_topF.py`) | THE APP'S TOP THEOREM WITH `hW` AND `hopX1` GONE |

### 2.6 The check against the code (`RunCloseBGeoCheck.lean`, executable, not imported)

See §7.

## 3. The numbers

| Figure | Value | Label |
|---|---|---|
| where the code's header absorbs the verdict | position `6` (the 7th of `8` absorbs), ONE byte | PROVED from the header (`ab_verdictAbs`); the header CHECKED by L51, re-run here (§7) |
| verdicts the code accepts | `0` and `1` only (classify_cli.rs:464, classify.rs:1018-1019) | ARGUED (source reading) |
| verdicts the Lean verifier accepted before `vdChk` | any `ℕ` | ARGUED (reading `classifyVerifyE`) |
| a boundary's geometry at R13 Shieldstral T128 (`B_in`, `B_1 … B_25`, `B_out`) | `log_n 14`, rate `1/4`, `256` checks and pads, `2^16` symbols: `ogR13` | CHECKED (§7); PROVED equal to `ogR13` (`cb_bnd_geo`) |
| a boundary's rows at R13 Shieldstral T128 | `128·4096/2^14 + 2·2 + 2 = 38` (`32` data rows) | CHECKED (§7); PROVED (`cbBndRows_r13`) |
| where part `i ≥ 1`'s closing root is absorbed | `off (i − 1) + 2`, alone (32 bytes; rows and `log_n` are separate absorbs) | PROVED (`cb_blk_opX`, `cb_inc_opX`, `cb_outc_opX`) |
| new extraction events | none (L45's `EvXR` covers every boundary root and opening) | PROVED (the lemmas use `EvXR` only) |
| R13 total | unchanged, `55,852,891` of `2^26 = 67,108,864` | PROVED (L52's `eb_total`) |
| the top theorem's explicit binders | L52's `124`; `vd_…_codeW` `127`; `cb_…_codeF` `142` (gone `Win`, `Wout`, `hW`, `hopX1`; new `Vi`, `F`, `hinc`, `houtc`, `hchk`, `hLb1`, `pXk`, `hXk`, `hwXk`, `hmXk`, `hfitXk`, `hgXk`, `hnXk`, `hwX0`, `hmX0`, `hgX1`, `hnX1`, `hOX`, `hwXo`, `hfitXo`, `hgXo`, `hnXo`) | CHECKED (the generators' binder parser) |

## 4. The files

New, imported by the root (in this order): `RunVerdictW`, `RunVerdictTop` (generated), `RunCloseBGeo`, `RunCloseBPcs`,
`RunCloseBRun`, `RunCloseBBlk`, `RunCloseBMid`, `RunCloseBTop` (generated), `RunCloseBEnd`, `RunCloseBInc`,
`RunCloseBEnds`, `RunCloseBTopF` (generated). Not imported: `RunCloseBGeoCheck.lean` (an executable checker). No existing
Lean file changed (the root's import lines apart); `Statements.lean` unchanged; no Rust.

## 5. What is left, premise by premise

### 5.1 The premises this lane introduced (of `cb_productionReadyL_epP_codeF`), and whether the real objects meet them

| Premise | What it says | Met by the real objects? |
|---|---|---|
| `Vi`, `F`, `hinc` | stage IN-C's verifier family is the constant `Vi` | YES: the real family is `fun _ => incVAt …` (L39's `rcIncAt`), `hinc` is `fun _ => rfl` |
| `houtc` | stage OUT-C's family reads only the verdict | YES: the real family is `fun _ v => outcVAt … (rcVerdict O v) …` (`rcOutcAt`), `houtc` is `fun _ _ => rfl` |
| `hchk` | block `0`'s statement check passes only a verdict `≤ 1` | YES with `check := vdChk check0` (`vdChk_le`, PROVED), the code's refusal (`vdChk_eq`; classify_cli.rs:464, classify.rs:1018-1019) [ARGUED that the accepted inputs are the code's]. NOT with a `check` that omits it (finding L55-1) |
| `hLb1` | `0 < Lb` | YES: `26` blocks |
| `pXk`, `hXk` | each block's boundary opening has an `RtPcs` with R13's numbers | YES: `pXk := cbBndPcs tag 38` for the code's `bndOpen := cbBndOpen tag 38`, `hXk := cbBndPcs_r13` (PROVED); the geometry CHECKED (§7); that the run's `bndOpen` is `pcs::verify_zk_tagged` at the boundary spec: CHECKED in the source (classify_run.rs:436-441) |
| `hfitXk`, `hfitXo` | `8 · rows ≤ Lq` | YES: `8 · 38 = 304 ≤ 2^20 ≤ Lq` (`cbBndPcs_rows`) |
| `hwXk`, `hmXk`, `hwX0`, `hmX0`, `hwXo` | each part's closing width is the pending count + the incoming count + the boundary's rows, and its index squeezes the opening's | YES: as L34's `rcRunClassifyAt` / `rtBlock_holds` build the parts (`wX = pend + nIn + pX.rows`, `mX = pX.m`) and `rcOutcPart` (`wX = pend + 1 + bRows`) [ARGUED: definitional at those builders] |
| `hgXk`, `hnXk`, `hgX1`, `hnX1`, `hgXo`, `hnXo` | part `i ≥ 1`'s closing geometry is `rkR13 rows (off (i − 1) + 2)` with the previous part's outgoing plus part `i`'s incoming claims | a CHOICE of `base` (like L52's `hgX0`, `hnX0`); the root position is the code's (PROVED in the opening lemmas); the counts are the parts' (`RtBlk`, `RtInc`, `RtOutc` counts) |
| `hOX` | `B_out`'s verifier has R13's numbers | YES at the real stage: `rcOutcAt_pX_bnd_r13` (PROVED) with `geo.bLogN = 14`, `blr = 2`, `bq = 256` (the boundary spec, CHECKED) |

### 5.2 Deliverable 3 (the input endpoint's extractor): NOT started

As L52 §5.3 items 1 to 3 left it: `ops`, `Xx`, `Ux` read from L52's tag-checked `ebOpenX`; its failure event bounded by
L16's `ExtBad` argument (`extract_of_opens`); `hread` by definition; `hE`, `mk`. If the new event REPLACES `ebEvIn`, the
R13 total stays `55,852,891`; if it is added with the same constant `2^16 + 2^18`, it becomes `56,180,571 ≤ 2^26`
(83.7 %) [ESTIMATE: the sum; the event's bound is the work].

### 5.3 Every premise of `cb_productionReadyL_epP_codeF` still left, by name

Objects: `Rp`, `Lq`, `Lb`, `preA`, `preB`, `start`, `inc`, `incG`, `Pk`, `sgeom`, `check`, `paths`, `digest`, `bRows`,
`bLogN`, `bndCheck`, `bndOpen`, `outc`, `outcG`, `P`, `U`, `key`, `domain`, `Rn`, `D`, `site`, `kOf`, `δOf`, `E`, `O`,
`tag`, `cx0`, `pin`, `pout`, `Iin`, `Oout`, `bp`, `wXk`, `gXk`, `mXk`, `Vi`, `F`, `lscIn`, `lscOut`, `mIn`, `kIn`, `kOut`,
`base`, `eL`, `hw`, `pXk`, `Fsl`, `AlkL`, `TL`, `mlkL`, `mk`, `ops` (and the section's `Rr`, `dR`, `pos`, `place`,
`msg`, `pad`, `salt`, `path`, `tagc`).

Hypotheses: `h64`, `hr`, `hon`, `hbij`, `hs`, `hL`, `hL64`, `hv`, `hRn`, `hD`, `hU`, `hσ`, `hLb`, `hgeo`, `hIA`, `hIH`,
`hOA`, `hOH`, `hBA`, `hBH`, `htI`, `htO`, `htB`, `hfIA`, `hfIH`, `hfOA`, `hfOH`, `hfBA`, `hfBH`, `hfIM`, `hfOM`, `hfBM`,
`hinc`, `houtc`, `hchk`, `hLb1`, `hlscIn`, `hlscOut`, `hmIn`, `hkIn`, `hkOut`, `hDe`, `hXk`, `hwXk`, `hmXk`, `hfitXk`,
`hgXk`, `hnXk`, `hwX0`, `hmX0`, `hgX1`, `hnX1`, `hOX`, `hwXo`, `hfitXo`, `hgXo`, `hnXo` (§5.1: met), `hgX0`, `hnX0`,
`hXep`, `hfitX`, `hRr`, `hL81`, `hslB`, `hsl_blk`, `hsl_stg`, `hR0_blk`, `hR0_stg`, `hR1_blk`, `hR1_stg`, `hH0_blk`,
`hH0_stg`, `hH1_blk`, `hH1_stg`, `hLU_blk`, `hLU_stg` (L53, L54), `hdin`, `hdout` (L53; `hdout` needs `hchk`'s refusal,
finding L55-1), `hblk` (L54), `hE`, `hops`, `hcan`, `hread`, `hdzero` (§5.2; `hdzero` L53's lists), `hzk`.

### 5.4 What the next lane needs

1. **Deliverable 3** (§5.2): the input endpoint's extractor (`ops`, `Xx`, `Ux` from L52's tag-checked `ebOpenX`), its
   failure event and bound, `hread`, `hE`, `mk`. Start from `cb_productionReadyL_epP_codeF`.
2. **Whoever instantiates the top theorem** must take the run's `check` as `vdChk check0` (finding L55-1), the
   boundary opening as `cbBndOpen tag 38` with `pXk := cbBndPcs tag 38`, and `base` with the closing geometries of
   §5.1 (`rkR13 38 (off (i − 1) + 2)` at parts `i ≥ 1`, with the counts given there).
3. **Lane L53 (`hdout`)**: with `hchk` the accepted verdict is `0` or `1`; without it `hdout` is false (L55-1).

## 6. Findings

**L55-1 (High; for the coordinator, lane L53 (`hdout`) and whoever instantiates the top theorem): the Lean run
verifier omits the code's refusal of a verdict other than `0` or `1`, and without it `hW` and `hdout` cannot be met.**
The code refuses a verdict above `1` twice before reading any segment: `found_statement` (classify_cli.rs:464,
"statement.json: verdict_bit is not 0 or 1") and `ClassifyRunStatement::new_chunk` (classify.rs:1018-1019, "classifier
run: the verdict is one bit"), the only constructor of the statement the verifier runs on (classify.rs:897; the
verifier's door, classify_cli.rs:902). The Lean `classifyVerifyE` reads the verdict (a `ℕ`) only in the header (as
`UInt8.ofNat v`) and in stage OUT-C; `preA`, `preB` read only the header type. Consequences: (1) `hW` is unmeetable by any
reader: the header is the same at `v` and `v + 256` (`vd_hdr_wrap`, PROVED) while the OUT-C verifiers differ
(`vd_outc_ne`, PROVED) [that both can be accepted with the same transcript prefix: ARGUED]; (2) `hdout` is unmeetable:
at `v = 2` the Lean OUT-C reads `σ = −1` and the constant `2 + c`, so a prover whose margin is at most `c − 2` passes
OUT-C's arithmetic honestly with `δ = c − 2 − Δ`, no entrant is doomed, and `OutOkP` fails (`b ≤ 1`) [ARGUED]. The
repair, Lean only, no code change: the real `check` is `vdChk check0` (the refusal in front of block `0`'s statement
check); `vdChk_eq` shows it is the old check on every statement the code can build, so the model's accepted inputs are
the code's [ARGUED]. Not a protocol issue: the code refuses. This is the tenth premise found unmeetable as modelled;
found and repaired in this lane.

**L55-2 (Low; for the coordinator): `hW`'s reader of the verdict needs the verdict below `256`, and the real header
absorbs ONE byte.** `vdByte` reads exactly a one-byte absorb at position `6`; the width is the code's
(`&[self.verdict]`, a `u8`), CHECKED by L51 on a real receipt (re-run here). With the refusal the verdict is `0` or `1`.

**L55-3 (Info; for the coordinator): the run's Merkle event already covers the closing openings of parts `1` on.**
`rxRoots` lists IN-C's `B_in` root and every block's boundary root; `rxOpenings` lists every block's `in_open` and
OUT-C's `B_out`. So `hopX1` needed no new extraction event and the count is unchanged.

**L55-4 (Info; for the coordinator and later lanes): the per-part run lemmas' carry was not tied to the previous
part.** `rk_blk_run`, `rs_inc_run`, `rs_outc_run` take their carry from `RtRun.accept_part`, an existential per part, so
the closing opening's claims and root could not be read from them. `cb_two` and the three `…_run_of` lemmas fix that
(new files; the old lemmas unchanged).

## 7. Checks

`results/zk60_lean_l55_20261110/check_l55.sh`, one guarded cpu job (`lean-l55-check`, need 24 GiB, cap 36 GiB,
`LEAN_NUM_THREADS=4`), run as the last step of `iter4` on perf `2e5cde97` plus this lane (commit `86d10afd` plus the
`Lb ≤ 26` fix): the guard's record exit 0, 269 s, peak 13.37 GiB. All figures MEASURED; logs in the evidence directory
(`check.log`, `full.log`, `axioms_flat.log`, `nameclash.log`, `geocheck.log`, `negative.log`, `abscheck.log`, the
regression logs). The modules were built first in guarded iterations (`iter1` … `iter4`, logs kept: iter1 caught a
missing import, iter2 a missing `open`, iter3 an `omega` that needed the `Lb ≤ 26` premise I had dropped as unused).

| Check | Result |
|---|---|
| each L55 module built alone (twelve) | 12 of 12 green, 0 warnings |
| full `lake build` | green, 3,815 jobs, 0 warnings, 0 errors, no `sorry` |
| axiom audit (`gen_axioms.py`) of every declaration of the twelve files | 38 of 38 (31 theorems, 7 definitions): 24 on `propext`, `Classical.choice`, `Quot.sound`; 4 on `propext`, `Quot.sound`; 7 on `propext`; 3 on none; `sorryAx` 0, `ofReduceBool` 0, other axioms 0 |
| source scan for the forbidden words (the twelve files, the checker, the three generators, the negative control) | none |
| root imports | the twelve modules imported (the checker not); no import line removed |
| existing files changed | none under `formal/` but the root's imports; `Statements.lean` unchanged; nothing under `ops/` |
| name clashes (`l55_nameclash.py`, prefixes `RunVerdict`, `RunCloseB`; 46 names; 42 worktrees, 5,335 other Lean files) | 0 |
| the generated files against their generators | `RunVerdictTop`, `RunCloseBTop`, `RunCloseBTopF`: identical |
| the boundary geometry against the code (`RunCloseBGeoCheck.lean`) | 24 checks, 0 failed (below) |
| its controls (`l55_negative.py`) | 26 cases: the unchanged copy passes; 11 corpus changes and 14 source changes, each refused |
| L51's agreement check of the code's header, re-run (`RunAbsCheck.lean`) | 29 checks, 0 failed |
| regressions | L6Check 1,206, L5Check 5,553, L11Check 404, fixture L1 101,956 checks; 0 failed in each |

The geometry check:

| Kind | What | Result |
|---|---|---|
| R13 | lane L49's export of the app's R13 Shieldstral T128 shape from the production code: the profile, `log_cols 14`, tokens `128`, `t_pad 128`, `d_pad 4096`; a boundary's rows there `38` | 4 of 4 |
| DEV | `B_out`'s spec on L29's real classifier run (development rung): `log_n 10`, `16` data rows of the `2^14` plane, `2` sites, `22` rows (`cbBndRows`), `Dim::of` `(256, 1280, 4096, 12)` = the geometry's, rate `1/4`, `256` checks | 4 of 4 |
| SOURCE | the R13 registration and `trained_geometry` (rate `4`, no endpoint override, not W16R2), the endpoint defaults, `COL_CHECKS = 256`, `boundary_spec` (the plane, `2` sites, `endpoint_log_n`, `endpoint_inv_rate`, `opened_cols`), `BoundarySpec`'s rows, refusal and params, the verifier's `B_in` / `B_{k+1}` / `prev`, block `k` opening the PREVIOUS boundary, OUT-C handed the last boundary, `B_out` opened at its params, `MASK_ROWS = 5` and the R13 `endpoint_rows = 37` | 14 of 14 |
| LEAN | `cbBndRows 128 4096 14 2 = 38` = `endpoint_rows + 1`; `ogR13` is the boundary geometry | 2 of 2 |
| total | | **24 checks, 0 failed** |
