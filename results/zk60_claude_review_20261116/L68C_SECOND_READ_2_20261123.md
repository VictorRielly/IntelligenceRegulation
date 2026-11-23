# L68c second read 2: HonestShieldStageInArith (finding M3 of the first read, IN-C half)

Written by a Claude sub-agent (clock read 2026-11-23 04:01 UTC). Source: branch agy/lean-l68c at commit 10112106,
read through `git show` only (merge base 2bfcbccc). **Nothing was built by me**: no lake, no Lean run. Every claim
is READ (source reading). Line numbers are at 10112106; bare numbers refer to HonestShieldStageInArith.lean.
"Builds green" and the axiom list in the header (line 8) are the author's claims.

## Verdict

**HonestShieldStageInArith.lean: merge with named changes (M1 doc, M1 corollary; M2 recorded as an open
obligation).** The module does what M3 asked for on the IN-C side. All 20 conjuncts of IN-C's `hArith` are proved
for the concrete witness `shdP_incTables`. No conjunct is left as a premise. Its proofs avoid every degenerate branch
I looked for. It does not yet discharge the shell's `hsegIn` by itself, for one wiring reason (M1).

## Findings

### High

None.

### Medium

- **M1 (1602-1622; header 4-6; RunShieldOpenShell.lean:711-716).** The header and the docstring say the theorem
  "discharges `hsegIn` ... completely". The shapes differ in one place. `hsegIn` is about `P.inC` for the top's
  arbitrary `P : RunP`. The theorem is about `inSegP _ (shdP_incP tag Rp embDigest bInRow C)` with
  `C := fun H _ x c => shdP_incTables … H x (epBase c) (rndOf c)`. No definition at 10112106 builds a `RunP` with
  this `inC` (git grep of `inC :=` finds only `segPMapCoins`, ZKView:663). The other differences close
  definitionally:
  - `hInRoot` holds by `rfl` for the top's `stOf`. `clsStmtOfP` sets `inRoot := honestRoot Cin … G x (base c)`
    (RunShapeProtocol.lean:143-144), and `shdP_honestIn.base := epBase` (RunShieldInstP.lean:93).
  - The verifier side is definitional: `shdP_runV` is `classifyRunV … (fun _ => shdP_incV … (embFoldL Rp.inp) bInRow)
    (fun _ => rcIncGeom … 28)` (RunShieldInstP.lean:633-635). `classifyRunV`'s `inC` is `incStageV inc incG`
    (StageVerifyExec.lean:553). `shdVi`/`shdGi` are those abbrevs (Stages:718, 721).
  - `fun G => liftH G` is `liftH` up to eta.
  
  **Settles it:** reword the two docs ("discharges `hsegIn` for any `P` with `P.inC = inSegP _ (shdP_incP …)`").
  Add a corollary stated with the top's exact `hsegIn` type under a premise `P.inC = …`. Its proof should use
  `hInRoot := fun _ _ _ _ => rfl`. Then fix `P` once for all of `hsegIn`, `hsegBlk`, `hsegOut`, `hcover` and `hzk`.
- **M2 (1521-1523, 1604-1622; StageVerifyExecComplete.lean:187-222).** `SegComplete` is conditional. It speaks only of
  runs where `incProve` returns `.ok`. Besides the probabilistic refusals (`incAlphaBad`, 188; zero slot challenge,
  1387), `incProve` has deterministic checks that could refuse:
  - `stSlotsProve` errors from `define`, `slotDefChecks` or `hostedSum`;
  - the functional count (195);
  - `checkOpening .a` / `.h` (197, 200);
  - `checkTokenEp` (204).
  
  Nothing here shows that these checks pass on `shdP_incTables`. If one always failed, `hsegIn` would still hold
  (vacuously), and the weight would move to `hcover`, which could then not be proved. That is the same vacuity class
  as before, moved from `hsegIn` to `hcover`. **Settles it:** a lemma saying that `incProve` on `shdP_incTables`
  returns `.ok` unless `incAlphaBad` holds or some slot challenge is zero. Feed it to `hcover`.

### Low

- **L1 (settles first read L5; 302, 562, 939, 1156, 1448).** The `slotPolyK` fallback (0 when `tabVals` errors) is
  unreachable on the honest slot definitions. `tabVals_stgTabK` returns `.ok vals` at every point, given `hfit` and
  `hcan`, which are proved per slot. `IndDegLE` therefore rests on the real polynomial.
- **L2 (first read L3; 820-827, 1098-1101).** The slot proofs never use `0⁻¹ = 0`. Every inverse is cancelled with
  `inv_mul_cancel₀`. Its nonzero denominator comes from `incAlpha_ne_tauK` with `hbad`, which `incProve_ok` supplies
  (1553). At padding columns (≥ 128) the TH rows are 0 by definition (StageInTables:207). The logup sum claim
  (StageInTables:1034) still holds unconditionally, as already noted.
- **L3 (StageInTables:162-285).** The tables are Lean constructions. Their layout matches `incLay`: see Q4. Nothing
  formally ties them to the Rust `stage_in_c` table builder. `incProve` models `stage_in_c::prove` (comment at
  StageVerifyExecComplete.lean:186), but the tables are its input. This is a modelling statement worth one line in
  the docs.

## Answers

**Q1.** `shdP_inc_arith` (1517-1550): for any `H`, `x` with `admissible x`, and coins `epR`, `rnd`, if `incProve` on
`incDataAt … (shdP_incTables …)` returns `R`, then all 20 `hArith` conjuncts hold. So does `ClaimTrue` of every
pending `claims.out` on `shdP_incTB` (the Block-0 carry). Premises:
- `Rp.inp.Valid` and `hV : Rp.inp.V = 131072`: deployment premises, already in the shell's tops as `hinPub` and
  `hV131072` (Shell:706, 708).
- `hx` and `hR`: supplied by `SegComplete` itself.

`shdP_inc_segComplete_of_adm` (1604-1622) adds:
- `hL20`: a setting.
- `epBase`, `rndOf`, `stOf`: free choices.
- `hInRoot`: a code fact, `rfl` for the shell's `stOf` (M1).

It discharges `hEpRoot` with `hInRoot` and `shdP_epTable_root`.

**Q2.** Each slot (234-1275) splits the cube at the selector bit. At `y = 1` the `.eq` table vanishes (`selK = 0`).
At `y = 0`, `claimSem_priv_cube_y0` drops the mask rows, and the slot is evaluated pointwise at `msbIndex`.
- Slot 0: `supp·x − x = 0`.
- Slot 1: LogUp `h·(α−q) − supp = 0` with `q = τ(x t)` (799-819), plus BOS, template and pad clauses; padding columns
  give zeros.
- Slot 2: `m·(α−τ)⁻¹·(α−τ) − m = 0`, with `supp_V ≡ 1`.
- Slot 3: a zero-sum row; `shdP_incHUVal` sums to 0 through a `Fin 4096` equivalence.

Degrees come from `IndDegLE` composition of degree-1 tables. The default branches:
- `getD` defaults: indices are bounded by lengths that are proved.
- `stgTabK` length-mismatch branches: the proofs take the proved branch.
- `decide`: none.
- Empty ranges: none.

`incAlphaBad = false` is the prover's real refusal test, not a degenerate one. See L1 and L2.

**Q3.** All are proved; none is assumed.
- TA, TH, TE, TB_in: proved by `IncAccInv` induction (1284-1513), through `slotClaims_claimTrue` and
  `claimTrue_iff_claimSem` (1416-1424). The prover's values are `claimSem` of the same tables.
- The logup claim on TH: `shdP_inc_logupSumClaim_true` (1598).
- M: `mkMTable_honest` (1579). Mask truth comes from the invariant's last field (1462-1468, via `scVerify_honest`
  and `Slot.terminal_iff`), with `hostFs = []`.

**Q4.**
- `shdP_incP = incP_abs` (Stages:623-631) runs `incProve` on `incDataAt C`. All roots and openings are computed
  from `C` (HonestRunStageIn.lean:53-64). So the theorem's tables are exactly what that prover commits.
- Nothing ties this prover to the top's `P` (M1).
- Layout agreement, which I recomputed from `Lay` (StageVerifyExecLay.lean:84-102) and `incSched`
  (StageVerifyExecInC.lean:85-100):
  - TA: data 1+32 rows, aMaskBase 33, aProx 39, aRows 41.
  - TH: data 2·(1+32+1) = 68 rows, hMaskBase 68, hProx 74, hRows 76.
  - TH offsets: `incH_TAB` at rows 2/34, `incH_U` at rows 66/67.
  
  These equal the witness rows (StageInTables:162-223) and the offsets the proofs compute (502, 889-893, 1121).
  The mask-row positions do not enter any completeness proof (y = 0). They matter for ZK only.

**Q5.** `hInRoot` holds by `rfl` (M1). No new theorem is needed. `hV` and `Rp.inp.Valid` are already premises of
both tops (`hV131072`, `hinPub`).

**Q6.** Not exactly. The missing piece is `P.inC = inSegP _ (shdP_incP …)` plus a short corollary (M1). Nothing
else is missing for `hsegIn`.

**Q7.** None of `sorry`, `admit`, `axiom`, `native_decide`, `unsafe`, `implemented_by`, `opaque`, `decide`,
`maxHeartbeats` or `maxRecDepth`. The only options are `autoImplicit false` and the constructor-name linter (13-14).
`simp` runs on small concrete layout arithmetic. There are no large kernel computations.

**Q8.** `shdP_outc_segComplete_of_adm` (OutArith:1302-1315, statement only) additionally assumes:
- `hOut : Rp.out.Valid`: a deployment premise (`houtPub`).
- `hVerdict`: `rfl` for `clsStmtOfP` (RunShapeProtocol:144).
- `hTB`: `BndTableSpec` of `TBOf`, the Block-25 boundary table, against `outcWitness_of_adm … .y25`. This is an
  unproved cross-segment obligation.
- `TBOf` and `rndOf`: free choices.

It uses `shdP_outcTables_total`, which falls back to junk tables for inadmissible `x` (1280-1297). That is harmless,
because `SegComplete` assumes `adm x`. It has the same `P.outC` wiring gap as M1, and the same refusal caveat as M2
(including the first read's M2 `own` check).

**Shortest list to a discharged `hsegIn`:**
1. Build a `RunP` with `inC := inSegP _ (shdP_incP …)`.
2. Write the corollary with `hInRoot := rfl`.
3. Get a guarded build and axiom report.

Separately, the top stays non-vacuous only with M2 settled inside `hcover`.

## The 20 conjuncts of IN-C's `hArith` (Stages:860-884)

| # | conjunct | discharged by (line) |
|---|---|---|
| 1 | slot scalars canonical | `ofK_canon` (1571) |
| 2 | slot terms canonical | `stgPrivVals_canon` (1572) |
| 3 | TA columns canonical | `mkPcsTable_cols_canon` (1573) |
| 4 | TH columns canonical | `mkPcsTable_cols_canon` (1574) |
| 5 | TE columns canonical | `shdP_epTable_cols_canon` (1575) |
| 6 | TA column lengths | `mkPcsTable_cols_length` (1576) |
| 7 | TH column lengths | `mkPcsTable_cols_length` (1577) |
| 8 | TE column lengths | `shdP_epTable_cols_length` (1578) |
| 9 | `StSlotsSum` (4 slots) | `shdP_inc_slots_ok` ← `inc_slot_step` ← `inc_slot0..3_arith` (1563, 1471-1513) |
| 10 | `MHonest` M | `mkMTable_honest` (1579) |
| 11 | mask functionals true | `IncAccInv` field 6, `hostFs = []` (1580-1589) |
| 12 | TA rows = 41 | `shdP_incTA_rows_len` (1590) |
| 13 | `ColsHonest` TA | `shdP_incTA_colsHonest` (1591) |
| 14 | `ClaimTrue` claims.a on TA | `IncAccInv` (`hclA`, 1569) |
| 15 | TH rows = 76 | `shdP_incTH_rows_len` (1592) |
| 16 | `ColsHonest` TH | `shdP_incTH_colsHonest` (1593) |
| 17 | `ClaimTrue` claims.h + logup on TH | `hclH` + `shdP_inc_logupSumClaim_true` (1594-1598) |
| 18 | TE rows = 6 | `shdP_epTable_rows_length` (1599) |
| 19 | `ColsHonest` TE | `shdP_epTable_colsHonest` (1600) |
| 20 | `ClaimTrue` claims.inp on TE | `IncAccInv` (`hclE`, 1570) |
| + | `ClaimTrue` claims.out on TB_in (carry) | `hclB` (1550, 1570) |

Discharged: 20 of 20. None remains a premise.

## Not checked

- Any build or axiom report.
- Proof bodies outside the main file:
  - StageInTables:633-845 (`shdP_incTB_eval_rEmb`, used at 797);
  - StageInTables:357-530 and 880-1028;
  - `slotClaims_claimTrue`, `slotSum_of_poly`, `scVerify_honest`, `tabVals_stgTabK`, `slotPolyK_vecK_eq`,
    `incDefIO_ok` / `incDefQZC_ok` / `incDefTZC_ok` / `incDefZS_ok`, `shdP_epTable_root` (statements trusted by
    name).
- Whether `Ps.define s` reduces definitionally to `incDefIO` / `incDefQZC` / `incDefTZC` / `incDefZS` at
  `interval_cases` (1341-1365): elaboration only.
- RunStgShieldIncZS.lean (imported, not opened).
- HonestShieldStageOutArith.lean proof bodies 34-1278 (statements only, as instructed).
- Whether the deterministic refusal checks of `incProve` pass on the honest tables (M2).
