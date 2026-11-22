# L68c second read 1: HonestShieldCore, MTable, Stages, StageInTables (+ RunShieldOpenShell documentation)

Written by a Claude sub-agent (clock read 2026-11-22 00:48 UTC). Source: branch agy/lean-l68c at commit 10112106,
read through `git show` only (merge base with the working branch: 2bfcbccc). **Nothing was built by me**: no lake,
no Lean run. Every claim below is READ (source reading). Line numbers are at 10112106.

## Verdicts per module

- **HonestShieldCore.lean: merge with doc changes.** Transport lemmas: bounded slot loops, wire-length lemmas, the
  group-count bridge, slot shape extraction, the generic PCS table `mkPcsTable` and the endpoint table `shdP_epTable`
  with its root and `ColsHonest` facts. No hypothesis bundle of its own. The only real obligation it passes on is
  `SlotsSum`, the slots' sumcheck arithmetic. The headers are stale (L1, L2).
- **HonestShieldMTable.lean: merge as it stands, two small cleanups optional (L4, L5).** `mkMTable_honest` proves
  upstream's `MHonest` for any mask count. The `b_512 = -b_0` adjustment matches `MHonest.off`
  (HonestOpenM.lean:144-149).
- **HonestShieldStages.lean: merge as conditional results, with changes to the doc and one recorded deviation
  (M2).** Every completeness theorem carries the 20-conjunct `hArith` bundle. Nothing in this file proves it.
  The names `*_stageInOK` / `*_segComplete` are accurate only as conditional statements.
- **HonestShieldStageInTables.lean: merge with one doc fix (L3).** It gives concrete IN-C witness tables (TA 41,
  TH 76, TB_in 38, TE, M with S = 4) and proves the LogUp sum claim true on TH. This file is the main evidence
  that IN-C's `hArith` is inhabited. Its consumer (StageInArith) was not reviewed (see M3).
- **RunShieldOpenShell.lean (documentation only): not yet.** Item (ii) is not done (M1).

## Findings

### High

- **H1 (carried, known since L68b-4/5; RunShieldOpenShell.lean:741-747, 831ff).** Both tops still take `hzk` at
  `refErr RunK.kinds`. The file's own note (lines 43-46) says this budget undercounts the 28-segment run (mT 79 > 32,
  chain 283820 > 57344, leaves 5359616 > 3784704). If the run's real ZK error exceeds `refErr RunK.kinds`, `hzk`
  cannot be proved and the top is vacuous through it: the defect class of L25/L29/L32. The four modules do not
  touch this. **Settles it:** prove ZK at `shdRunErr` and switch the tops to it, or prove
  `refErr RunK.kinds` ≥ the real error.

### Medium

- **M1 (RunShieldOpenShell.lean:459, 469, 604).** The file still says "Non-vacuous" in three places: the section
  header (459), `classifyP_parts_of_segs` (469) and `shdP_classifyOpenP_shell` (604). Neither is shown non-vacuous:
  the parts lemma only rearranges `hin`/`hblk`/`hout`, and the shell's `hparts`, `hcover` and `hzk` are not shown
  inhabited. **Settles it:** delete the word, or cite a theorem producing the premises.
- **M2 (HonestShieldStages.lean:162-177, 764-767).** The repaired `own` is `decide` (classical) of "root =
  rootOf TB ∧ every pending claim is ClaimTrue on TB". So the Lean OUT-C honest prover refuses on any carry whose
  pending claims are false. The code's prover does not make that check. This is acceptable for `StageOutOK` (it is
  conditional on non-refusal). But at run level, a refusal of the honest OUT-C must be covered by `hcover`. So `hcover`
  is satisfiable only if the honest block-25 carry passes `own`: its root is OUT-C's `TB`, and its pending claims are
  true on that `TB`. I found no such theorem in the four files. **Settles it:** a named theorem (probably
  StageOutArith or HonestShieldBlockWitness) that the honest carry satisfies `shdP_outcDataAt.own`. Also record the
  deviation from the code's prover.
- **M3 (HonestShieldStages.lean:855-884, 943-972).** The `hArith` bundle (canonicity, column lengths,
  `StSlotsSum`/`SlotsSum`, `MHonest`, mask truth, row counts, `ColsHonest`, `ClaimTrue` on every opening) is the
  whole arithmetic content of stage completeness. These four files discharge parts of it:
  - `MHonest` (MTable);
  - `ColsHonest`, row lengths and canonicity (Core, StageInTables);
  - the LogUp claim (StageInTables:1034).

  They do not discharge the slot arithmetic or the other `ClaimTrue` conjuncts.
  - IN-C: the discharge claimed is `shdP_inc_arith` / `shdP_inc_segComplete_of_adm`
    (HonestShieldStageInArith.lean:1515-1626). I read only its statement. Its extra premises are `Rp.inp.Valid`,
    `hV`, and `hInRoot` (the statement's input root is the honest endpoint root).
  - OUT-C: its header (HonestShieldStageOutArith.lean:1205) adds a premise that TB satisfies `BndTableSpec`.

  **Settles it:** green guarded builds and axiom reports of both `*_segComplete_of_adm` theorems, and a construction
  of a TB meeting `BndTableSpec` from the honest block-25 output.
- **M4 (RunShieldOpenShell.lean:12-13, 450-453).** `shdRunErr_hzk` and its doc ("Numeric `hzk` discharge") read as if
  `hzk` were discharged. The theorem is only the inequality `shdRunErr q R ≤ εzkTarget q R`. Item (v) risk.
  **Settles it:** rename (for example `shdRunErr_le_target`) or reword.

### Low

- **L1 (Core:8-10, Stages:7-9, Shell:471).** These lines say the bounded loop lemmas replace "L25/L29's vacuous
  unbounded `∀ s`". Upstream was already bounded at the merge base by ruling L63-10 (HonestClassifyBlock.lean:292, 430;
  StageVerifyExecComplete.lean:84). The Shell itself says so at 40-41. `slotsLoop_of_prove_bd`,
  `stSlotsLoop_of_prove_bd` and `blockVerify_of_prove_bd` (Core:56-170) duplicate upstream. Reword them, or use the
  upstream lemmas.
- **L2 (Core:4, MTable:4).** Both cite `HonestShieldBlock.lean`, which does not exist at 10112106 (the files are
  BlockBase / BlockTables / BlockWitness).
- **L3 (StageInTables:1033).** The doc says "(given `incAlphaBad = false`)", but the theorem has no such premise. It
  holds unconditionally because Lean's `0⁻¹ = 0` makes the fibre identity exact. Harmless, but the doc should say so.
- **L4 (MTable:507-510).** `ZK60.Exec.Block.toK_fp2U` is declared into an upstream namespace from a lane file. If
  upstream adds the same name, the two will clash.
- **L5 (MTable:393-395).** `slotPolyK` returns 0 when `tabVals` errors. `IndDegLE` of the slot polynomial over
  all of `K^n` needs this branch to be unreachable or uniform. The proof is in StageInArith (not reviewed).
- **L6 (Shell:12 vs 44, 352).** The doc gives qpT = 283822 at line 12 and chain = 283820 at lines 44 and 352
  (the code uses 283822 at line 384). Say whether these are two quantities.

## Questions 1 and 3 (names vs statements; degenerate definitions)

- Names match statements apart from L3 and M4. The `*_stageInOK` / `*_segComplete` theorems give codec round-trip
  and acceptance whenever the honest prover does not refuse, given `hArith` (+ `hEpRoot` for IN-C): conditional
  completeness, not refusal bounds.
- `encSeg_length` covers only non-closing segments, as its doc says.
- Degenerate definitions: the classical `own` (M2) and the `slotPolyK` fallback (L5). Also two zero cases:
  `mkMTable` rows ≥ 2S+4 are 0, and in the IN-C TH rows 0-1 the columns ≥ 128 are 0 and `x⁻¹` is 0 at `α = τ`
  (the `incAlphaBad` refusal guards that case). Both are harmless.
- No simulator or view is defined here. `IncRand` is arbitrary, so completeness holds for every value.

## Question 4: premise table

| premise (where) | kind |
|---|---|
| `hslots` / `SlotsSum` / `StSlotsSum` (Core, Stages) | unproved mathematical obligation (slot sumcheck arithmetic); IN-C claimed in StageInArith |
| `hdeg` (Core) | code fact (schedule degrees); discharged in Stages by `rc_incBounds` / `rc_outcBounds` (RunCoverStage.lean:164,171) |
| `hpre`, `hpA/hpH/hpM` (Core) | code fact / honest-opening fact; discharged in Stages by `bOpen_pathsDepth`, `bMask_pathsDepth` |
| `hMh` | proved for `mkMTable` (MTable:199) |
| `hMt`, `htA`, `htH`, `htE`, `htB_inp` | mathematical obligations; LogUp part of `htH` proved (StageInTables:1034); rest in StageInArith / StageOutArith |
| `hrA/hrH/hrE/hrB`, `hcA/hcH/hcE/hcB` | proved for the concrete tables (StageInTables:287-307; Core:775-880) |
| `hEpRoot` / `hInRoot` | fact about the statement construction (input root = honest endpoint root); not proved here |
| `hArith` (Stages) | bundle of the above; see M3 |
| `own` success at run level | unproved cross-segment invariant (M2) |
| `hL20` | setting (Lq ≥ 2^20) |
| `hAct0` | not used in these four files (it is in BlockWitness; now `hPb.act0`) |
| Shell top: `hR`, `hV131072`, `hweights`/`hinPub`/`houtPub` | deployment premises 5, 4, 6 |
| Shell top: `hpol` | code policy; discharged in `_okPre` |
| Shell top: `hsegIn`, `hsegBlk`, `hsegOut` | unproved obligations (IN-C/OUT-C claimed by the Arith files; blocks not reviewed) |
| Shell top: `hk`, `hδ`, `hcover` | unproved obligations on the site construction |
| Shell top: `hzk` | unproved, possibly unprovable at the stated budget (H1) |

## Question 5: hygiene

All five files: none of `sorry`, `admit`, `axiom`, `native_decide`, `unsafe`, `implemented_by`, `opaque`. The
only options are `autoImplicit false` and a linter switch. `decide` appears as a Boolean coercion (Core:425-434,
551-554) and in the classical `own` (Stages:176). I saw no large kernel computation.

## Question 6: RunShieldOpenShell documentation

- (i) O described as split: **done** (29-35, 679-686).
- (ii) no "non-vacuous" for hseg / `classifyP_parts_of_segs`: **not done** (459, 469; also 604 for the shell).
- (iii) `hzk` still at `refErr RunK.kinds`, `shdRunErr` used by neither top: **done** (14-15, 34, 43-46, 685).
- (iv) L68b-1 / L68b-2 fixed by ruling L63-9: **done** (38-39).
- (v) no claim that completeness, refusal or ZK is proved when assumed: **done, one caveat** (M4: 450 "Numeric
  `hzk` discharge"). Line 24's "completeness refusal total ≤ εcTarget" is a proved sum bound, correctly worded.

## Question 7: constants

These agree with RunShieldBlkInst / RunShieldInstP and with INST_CONSTANTS rows 22, 40, 47-56:
- stage `lt` 12, `lr` 2, `q` 256, path 14;
- endpoint 8 / rate 8 / path 11, 6 rows (1 data + 5 mask);
- boundary `bLogN` 14, 38 rows = 32 data + 2·2 sites + 2 (`cbBndRows`, RunCloseBGeo.lean:32);
- OUT-C B opening ⟨14, 4, 256, 256⟩, path 16;
- 28 segments; OUT-C index 27; V = 131072; T = 128; d = 3072 padded to 4096.

IN-C aRows 41 / hRows 76 and OUT-C 76 / 38 are taken from `shdP_incLay_nums` / `shdP_outcLay_nums` (tied, not
restated). The witness layouts sum correctly: 1+32+6+2 = 41 and 2+64+2+6+2 = 76. **No disagreement found.**

## Not checked

- Any build or axiom report ("builds green" is the author's claim).
- The other 14 HonestShield* modules (statements only where quoted).
- Whether the witness mask-row positions match the code (enforced only implicitly, by StageInArith's proofs).
- StageInTables:700-840 (proof body of `shdP_incTB_eval_rEmb`).
- The Shell's proofs, its lines 3-4 claim about `blkEF`, and its ZK counts against the code.
