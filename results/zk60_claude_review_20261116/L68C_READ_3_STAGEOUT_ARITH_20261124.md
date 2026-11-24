# L68c read 3: HonestShieldStageOutArith (output stage arithmetic)

Written by a Claude sub-agent (clock read 2026-11-24 00:04 UTC). Source: branch agy/lean-l68c at commit 326007ebd,
read through `git show` / `git grep` only. **Nothing was built by me**: no lake, no Lean run. Every claim is READ.
Bare line numbers refer to HonestShieldStageOutArith.lean at 326007ebd. "Builds green", "0 sorry" and the axiom
list in the header (line 9) are the author's claims.

## Verdict

**HonestShieldStageOutArith.lean: merge.** The L-items below are optional doc fixes. All 20 conjuncts of OUT-C's
`hArith` are proved for the concrete tables `shdP_outcTables`. Fifteen come from the module's own work. Four come
from the premise `hTB : BndTableSpec` on the incoming boundary table, and the top discharges that premise for the
real Block-25 table. The two gaps of the earlier read are closed for the output stage, outside this module, in
HonestShieldTop.lean and HonestShieldRunRefusal.lean.

## Findings

### High

None.

### Medium

None.

### Low

- **L1 (Top:196).** The author names `shdP_blk_outClaims_true`. No theorem of that name exists at 326007ebd. The
  theorem is `shdP_blk_outClaims_true_uncond`. This module does not use it. Its only use is in `hcover`
  (Top:1021). **Settles it:** correct the name wherever it is cited.
- **L2 (RunShieldInstP:176-179; RunShapeShield:120).** `shdP_outcPub` writes `d := 3072` and `tPad := 128` as
  literals. They are not taken from `shieldS0 := carrier 128 3072`. Drift could not pass silently: `OutcWitness`
  indexes `y25 (Rp.row, i)` with `i : Fin 3072` (StageOutTables:128), which must be defeq to `Fin shieldS0.d`, and
  the slot proofs use 3072 and 4096 against `O.d`. **Settles it (optional):** derive the fields from `shieldS0`,
  or add an `rfl` example.
- **L3 (header 6-7).** The header says the module discharges `hsegOut` of
  `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`. What the module does is reduce `hsegOut` to `hVerdict`
  and `hTB` (1537-1546). The discharge for the run's prover is `shdP_honestRun_hsegOut` (Top:364-401). The
  docstring at 1533-1535 states this correctly. **Settles it:** one-line header edit.
- **L4 (Top header 10-14).** The tables are a Lean model of `stage_out_c`. The Rust correspondence lies outside the
  kernel. The author states this.

## Answers

**Q1.**
- `outc_slot5/6/7_arith` (35, 696, 856) prove the DZC, TAB and ZS slots. For each, `IndDegLE d`, `cubeSum = 0`,
  `hosted = []` and canonical polynomial values, under `define = .ok df`.
- `OutcAccInv` (976-996) is the 10-field invariant.
- `outc_slot_step` (998) and `shdP_outc_slots_ok` (1395) induct over the 8 slots. They take `hbad : outcAlphaBad
  ch = false`, canonical `ch` and `hTB`.
- `shdP_outc_arith` (1441-1513) is the bundle. Its premises are `hOut : Rp.out.Valid`, a witness `w : OutcWitness`,
  `hTB : BndTableSpec w.y25 Rp.row TB` and `hR : outcProve … = .ok R`. Its conclusion is exactly the 20 conjuncts.
  `hbad` and `hchCan` come from `outcProve_ok` (1474-1477). This is a real statement about the concrete tables,
  conditional only on `hTB`.
- `shdP_outc_segComplete_of_adm` (1537-1569) is a wrapper. It feeds `shdP_outc_arith` into `shdP_outc_segComplete`
  (Stages:989), with premises `hVerdict` and `hTB`.

**Q2.** See the table. All 20 are proved. None is a hypothesis of the theorem, apart from the four that are read
off `hTB`.

**Q3.**
- No vacuous premise. `hTB` is satisfiable: `shdP_outcBndTable_spec` (StageOutTables:99) and the real table
  (BlockArith:1813).
- Inverses: the slot 5 proof cancels `(α − (doLook+γ·TAG))⁻¹` with `field_simp`. The nonzero denominators come from
  `halphaNe` (520-524), whose source is `hbad`, the prover's real refusal test. `0⁻¹ = 0` is never used.
- Padding columns ≥ 3072: proved by case split. `doLook` = 127 there and `supp = 0` (474-500, 553).
- `getD`: the defaults are in range. `dr.length = 23` and `ldo = 12` make index 22 real (54). `R.ch` has length 2
  (`chalVec … 2`, 1477), so `ch.getD 0/1` are the real challenges. `Option.getD_none` at 315 applies only past the
  21 tables, for the degree bound.
- `decide`: none in this module.
- The fallback branch of `shdP_outcTables_total` (1527-1533) is junk tables for inadmissible `x`. `SegComplete`
  assumes `adm x`, and `dite_eq_left hx` (1560) selects the real branch.
- `hinv0` (1478) is the s = 0 base case. It is not a shortcut.

**Q4.**
- `shdP_bndTableAt_spec` (BlockArith:1795-1810): every `shdP_bndTableAt … idx`, `idx : Fin 27`, satisfies
  `FullBndTableSpec (shdP_blkState … idx)`. Its premises are deployment facts (`hR`, `hweights`, `hinPub`) and
  `hx`.
- `shdP_bndTableAt_last_outcSpec` (BlockArith:1813-1821) combines it with `shdP_blkState_last`
  (BlockWitness:272-275: state 26 = `outcWitness_of_adm … .y25`). That gives `hTB` for the OUT-C witness.
- Top applies it at 391, inside `shdP_honestRun_hsegOut`. `hVerdict` is `rfl` there (386).
- `shdP_blk_outClaims_true_uncond` (Top:196-211): a successful `coreProve` gives `ClaimTrue` on `TB_next` for every
  `claims.out`. It is the Block→next hand-off for `hBlkOutTrue` in `hcover` (Top:1021-1026). For OUT-C, it feeds
  `htrue26`, from which `hown` is proved (RunRefusal:3141-3144).
- All of these premises are discharged in the top. None is left to the caller.

**Q5.**
- **M1: settled.** `shdP_honestRunP.outC` (Top:281-284) is literally `outSegP _ (shdP_outcP … (shdP_outcTables_total
  … (shdP_bndTableLast_total …) outcRndOf))`. That is the object of `shdP_outc_segComplete_of_adm`.
  `shdP_honestRun_hsegOut` states it with `P.outC` and the run's verifier. The concrete top uses this `P` with
  `bOutRow = 34` (Top:1405-1411).
- **M2: settled for OUT-C, through `hcover`.** `outcSeg_refuse_cover` (SegRefusal:3470-3727) handles each refusal
  that `outcProve_refuses` (StageVerifyExecComplete:702) lists:
  - `own`: proved true (RunRefusal:3141-3144);
  - `outcAlphaBad`: a site;
  - `define` zero draws: a site;
  - depC/depE: sites;
  - deterministic slot checks: shown `.ok` by `shdP_outc_slotChecks_ok` (3624-3629);
  - functional count and `claims.out = []`: shown to hold by `shdP_outc_postSlots` (3631-3633);
  - `checkOpening` A/H and `bCheck`: a start site, or a collision site under `OpenAuditOk` from `shdP_outc_audit`
    (RunRefusal:1587).

  So `SegComplete` cannot hold vacuously unless a named site fires.

**Q6.**
- The stage shape is shared. `shdVo`/`shdP_outcV`/`shdP_outcPub`/`shdP_outcGeo` (Stages:724; RunShieldInstP:175-196)
  are used by both prover and verifier, and the concrete top uses them.
- The row counts 76/38 are proved from `shdP_outcLay_nums`, not assumed.
- `shieldS0 = carrier 128 3072` is the single model shape (L2).
- Heads (24) do not enter OUT-C.

## The 20 conjuncts of OUT-C's `hArith` (Stages:998-1022)

| # | conjunct (Stages line) | discharged by (line) |
|---|---|---|
| 1 | slot scalars canonical (998) | `ofK_canon` (1488-1490) |
| 2 | slot terms canonical (999) | `stgPrivVals_canon` (1491) |
| 3 | TA cols canonical (1000) | `mkPcsTable_cols_canon` (1492) |
| 4 | TH cols canonical (1001) | `mkPcsTable_cols_canon` (1493) |
| 5 | TB cols canonical (1002) | `hTB.cols_canon` (1486) |
| 6 | TA col lengths (1003) | `mkPcsTable_cols_length` (1494) |
| 7 | TH col lengths (1004) | `mkPcsTable_cols_length` (1495) |
| 8 | TB col lengths (1005) | `hTB.cols_len`, `rows_len` (1486) |
| 9 | `SlotsSum` 8 slots (1006) | `hsl.1` ← `outc_slot_step` ← slots 0-7 (1087-1188, 1483) |
| 10 | `MHonest` M (1008) | `mkMTable_honest` (1496) |
| 11 | mask functionals true (1009) | `OutcAccInv` last field, incl. 2-term `hostFs` (1497-1504) |
| 12 | TA rows = 76 (1013) | `shdP_outcTA_rows_len` (1505) |
| 13 | `ColsHonest` TA (1014) | `shdP_outcTA_colsHonest` (1506) |
| 14 | `ClaimTrue` claims.a (1015) | `hclA` (1485) |
| 15 | TH rows = 38 (1016) | `shdP_outcTH_rows_len` (1507) |
| 16 | `ColsHonest` TH (1017) | `shdP_outcTH_colsHonest` (1508) |
| 17 | `ClaimTrue` claims.h + logup (1018) | `hclH` + `shdP_outc_logupSumClaim_true` (1509-1513) |
| 18 | TB rows = 38 (1020) | `hTB.rows_len` (1486) |
| 19 | `ColsHonest` TB (1021) | `hTB.cols_honest` (1486) |
| 20 | `ClaimTrue` claims.inp on TB (1022) | `hclB` (1485) |

Discharged: 20 of 20. Four (5, 8, 18, 19) are read off `hTB`. The top discharges `hTB` at Top:388-391.

**Escape scan.** Across all `HonestShield*.lean` and RunShieldOpenShell.lean, `sorry`, `admit`, `axiom`,
`native_decide`, `unsafe`, `implemented_by` and `opaque` appear only in comments and docstrings. Examples: line 3
and 9 here; Stages:293 and 457; Top:822. `decide` is not used in this module. StageOutTables:659, 676 and 951 and
StageOutSlots:1016 and 1027 use it on small concrete facts.

## Not checked

- Any build or axiom report.
- The proofs of `outc_slot0..4_arith` (StageOutSlots:338-1163). Their statements were trusted by name.
- The StageOutTables proof bodies (`shdP_outcTA/TH_colsHonest`, `shdP_outc_logupSumClaim_true`,
  `outcWitness_of_adm` after line 200).
- The bodies of the slot 6 and 7 cubeSum arguments (712-966). I skimmed them; I did not check each line.
- The meaning of "site kind 0" (`h0` branches of `checkOpeningFull_startCover`), and whether every site's `fires`
  is a genuinely probabilistic event.
- `shdP_outc_audit_A/H/B` and `shdP_outc_postSlots`. Statements only.
- The open ZK premise `W_zk` of the top (Top:17-19). It is outside this module.
