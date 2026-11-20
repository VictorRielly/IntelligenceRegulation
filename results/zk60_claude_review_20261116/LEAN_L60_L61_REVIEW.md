# Independent review of D63 lanes L60 and L61 (Lean), merged at `1668946a`

- **Reviewer:** Claude (read-only review, 2026-11-16). Nothing under `formal/`, `docs/`, `ops/` was edited; no commit.
- **Scope:** commits `d0a4eb54` (L60, `RunStgJoin*`) and `00352079` (L61, `RunBlkWire*`), merged at `1668946a`;
  the generators `l60_mk_join.py`, `l61_mk_wire.py`; the authors' `REPORT.md` files, `merged_axiom_audit.txt`.
- **Method:** binder lists were parsed with the scripts in this directory (`binders.py`, `tdiff.py`,
  `chain_diff.py`, `dump_premises.py`, `binder_lines.py`; full premise lists in `premises/`, the step-by-step chain diff in
  `chain_diff.txt`). The short helper files were read in full. No `lake build` was run. One guarded `lake env lean`
  probe (`AxiomProbe.lean`, class `cpu`, exit 0, `axiom_probe.log`) ran `#print axioms`; its result is in section 5.
  (`GPU_FRIENDLY_REVIEW.md` and `archive_and_prune_worktrees.py` in this directory are not mine.)
- **Labels:** CHECKED = I verified it against the source or by a command; ARGUED = my reasoning, not machine-checked;
  NOT VERIFIED = I could not settle it.

## 0. Headline

The five new top theorems are genuine, sorry-free Lean proofs of the same approved conclusion as L58's
`ex_productionReadyL_epP_codeH`, and `Statements.lean` is untouched (CHECKED). But they make little net progress on the
open premises:

- **One substantive premise is genuinely discharged:** the block slot-evaluation cover `hsl_blk`. L60 reduces it to an
  adversary-free property of the slot polynomial (`hsl_argsN` + `hdefS`); L61 proves that property for an explicit
  slot polynomial `bwFslRun` (REAL). It costs four new small geometry premises (`hoAK`, `hoHK`, `hoIK`, `hoOK`).
  Bookkeeping premises `hdefS`, `hLb`, `progK`, `pubsK`, `hdefK`, `hprogK`, `hNK` are discharged from `hPk : ShieldRunAt`
  (REAL; the `hdefS` and `hLb` lemmas are L56's, already used in `RunBndTop.lean`).
- **Eight premises are SHIFTED, not proved:** L58's stage covers `hsl_stg`, `hR0_stg`, `hR1_stg`, `hH0_stg`, `hH1_stg`,
  `hLU_stg`, `hdin`, `hdout` are replaced by L57's eight stage facts `hTrI`, `hTrO`, `hDI_stg`, `hDO_stg`, `hLI_stg`,
  `hLO_stg`, `hdinS`, `hdoutS` (plus their set-up data). The join theorem is the union of L57's and L58's open premises.
- **One instantiation is DEFINITIONAL but faithful:** `Fsl := bwFslRun`, the slot polynomial built from the extracted
  tables. I judge it to describe the extractor's polynomial, not an idealisation (section 2).
- **Still open in every new top theorem:** `hblk` (the per-block R13 bundle `RdBlkR13B`, i.e. the wiring of L49's block
  theorem for all 26 blocks), `hdzero`, the eight stage facts, the block alive premises
  `hR0_blk`…`hH1_blk`, `hLU_blk`, and `O`, `hzk`. The parsed binder count rises from 144 (L58's `codeH`) to 165 for
  `sj_..._join` and 166 for `bw_..._shield`.
- **L61's "adversary-free LogUp coverage" and "adversary-free IO schedule" lemmas are proved but not used by any top
  theorem** (CHECKED by grep). They remove no premise.

## 1. Premise diff

The proof chain (CHECKED from each body's `exact`):
`eb_..._exec_stage` (RunEpBChain) → `sj_..._exec_blk` → `sj_..._exec_alive` → `sj_..._code` → `sj_..._codeT` →
**`sj_..._wireT`** → `sj_..._wireW` → `wireX` → `wireF` → `wireG` → **`sj_..._join`** → **`sj_..._join_shield`**, and
`sj_..._join` → **`bw_..._wire`** → **`bw_..._shield`**. L60 rebuilds the chain from L52's `eb_..._exec_stage` and
re-runs L56, L57 and L58's transformations on the widened block forms. It does not `exact` L58's `codeH` or L57's
`stgAlg_..._exec_real`. The direct predecessors below are therefore the theorem each one `exact`s. The comparison against
the two named predecessors uses binder names and types.

Binder counts as parsed (all explicit, implicit and instance binders; section variables excluded): `codeH` 144,
`stgAlg_exec_real` 173, `wireT` 155, `join` 165, `join_shield` 164, `bw_wire` 171, `bw_shield` 166.

### 1a. `sj_productionReadyL_epP_join` (RunStgJoinTop.lean:1531) against L58's `codeH` (RunEpXTopH.lean:51)

| Status | Premises |
|---|---|
| Removed (9) | `hsl_blk` (codeH:127), `hsl_stg` (:136), `hR0_stg` (:155), `hR1_stg`, `hH0_stg`, `hH1_stg`, `hLU_stg` (:251), `hdin` (:265), `hdout` (:281) |
| Added (29) | `hdefS` (join:1608), `hsl_argsN` (:1610); from L57: `P0in`, `P0out`, `csIOI`, `csIOO`, `hIOI`, `hIOO`, `hNin`, `hNout`, `ΦI`, `ΦO`, `dgI`, `dgO`, `eI`, `eO`, `ΛI`, `ΛO`, `hb0`, `hbL`, `hPin`, `hPout`, `hTrI` (:1632), `hTrO`, `hDI_stg` (:1660), `hDO_stg`, `hLI_stg` (:1730), `hLO_stg`, `hdinS` (:1758), `hdoutS` (:1774) |
| Changed (11) | `Fsl` (gains `HdrX`), `hslB` (`blockSchedX`→`blockSchedXB`), `AlkL`, `mlkL` (read `(cut, root)`), `hR0_blk`, `hR1_blk`, `hH0_blk`, `hH1_blk` (`RaDefAt`→`RaDefAtB`), `hLU_blk` (`RaLkAt`→`RaLkAtB`), `hblk` (`RdBlkR13`→`RdBlkR13B`, :1765) |
| Kept (122) | everything else, including `hdzero` (:1782, identical to codeH:290), `O`, `hzk`, `hLb`, the 26 PCS/geometry facts, L58's `pXk…hRr` |

Each changed premise is a generalisation, so it is weaker than or equal to the old one (ARGUED):
`lkSqB` (RunStgJoinLk.lean:25-33) is `lkSq` (LookupW16FS.lean:212-217) with `Alk`/`mlk` also given the absorbed
root, so `Alk' cr := Alk cr.1` turns any old witness into a new one. `RaDefAtB` lets `Φ` also read `HdrX`. `RdBlkR13B`
(RunStgJoinLk.lean:396-458) is `RdBlkR13` (RunDoomBlk.lean:359-420) over `defSqB`/`DefSchedB`/`lkSqB`.

### 1b. `sj_productionReadyL_epP_join` against L57's `stgAlg_productionReadyL_epP_exec_real` (RunStgAlgTopR.lean:50)

| Status | Premises |
|---|---|
| Removed (34) | L58's discharges: `E`, `Cl`, `T`, `hTenc`, `hTaA`, `hTaB`, `Ux`, `Xx`, `hUc`, `hXc`, `pr`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ`, `Win`, `Wout`, `hW`, `hopX`, `mk`, `ops`, `hE`, `hops`, `hcan`, `hwin`, `hread` (L57:334), `hBal` (L57:342); also `tag` (now a section variable), and `hsl_blk` (L57:143) |
| Added (33) | L58's bookkeeping: `hw`, `hRn`, `E0`, `Vi`, `hinc`, `houtc`, `hchk`, `hLb1`, `pXk`, `hXk`, `hwXk`, `hmXk`, `hfitXk`, `hgXk`, `hnXk`, `hwX0`, `hmX0`, `hgX1`, `hnX1`, `hOX`, `hwXo`, `hfitXo`, `hgXo`, `hnXo`, `hgX0`, `hnX0`, `hXep`, `hfitX`, `hRr`; L60's `hdefS`, `hsl_argsN`; `F` changes kind (`Type` → `ℕ → OutcV`) |
| Changed (21) | `hDe` (`rkData`→`ebData`), `Fsl`, `hslB`, `AlkL`, `mlkL`, `hb0`, `hbL` (`Win`→`vdWin Vi`), and `hTrI`, `hTrO`, `hDI_stg`, `hDO_stg`, `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`, `hR*_blk`, `hLU_blk`, `hblk`, `hdzero`. For the stage facts the only changes are an extra antecedent `¬ exEvIn …` (weaker) and `W := vdWin Vi` / `vdWout F` (L58's verdict tie). Token diff: `tdiff.py` output in section 4. |

L57's eight stage facts are therefore still premises of the join, in L57's form.

### 1c. Successive steps (from `chain_diff.txt`)

| Step | Removed | Added | How removed |
|---|---|---|---|
| `eb_exec_stage`→`sj_exec_blk` | `hdblk` | `hblk` (RdBlkR13B) | `rd_hdblkB` (RunStgJoinLk.lean:478), REAL reduction (same pattern as L46) |
| →`sj_exec_alive` | `hal_slots`, `hal_R0/R1/H0/H1`, `hal_LU`, `hdin`, `hdout` | `Fsl`, `hslB`, `AlkL`…, `hsl_blk`, the L57 stage set, `hR*_blk`, `hLU_blk`, `hdinS`, `hdoutS` | L56's `ra_hal_defB`/`ra_hal_slB`, L60's `ra_hal_luB` (RunStgJoinLk.lean:181), L57's `stg_hal_*V`, `stg_hal_doomV`: REAL reductions to SHIFTED premises |
| →`sj_code` | `hTaA`, `hTaB`, `Ey`, `εy`, `hEy`, `cy`, `hcy`, `hcyB`, `hopX`, `hwin` | `hw`, `hRn`, `hTwA`, `hTwB`, `hopX1`, `hgX0`, `hnX0`, `hXep`, `hfitX` | L58's generator transformations re-applied (`exEvIn_of_eb`, `eb_hopX0`) |
| →`sj_codeT` | XTest family, `hBal` | `hRr` | L58 (REAL there) |
| →**`wireT`** | `hsl_blk` | `hgXB`, `hdefS`, `hsl_argsN` | `bnd_hsl_evBN_of_args` (RunStgJoinBnd.lean:123), `wr_termBN` (:21): REAL reduction, SHIFTED to an adversary-free premise |
| →`wireW` | `Win`, `Wout`, `hW` | `Vi`, `F`, `hinc`, `houtc`, `hchk`, `hLb1` | L55's verdict link (as L58) |
| →`wireX` | `hopX1` | `hopX1e`, `pXk`, `hXk`, `hwXk`, `hmXk`, `hfitXk`, `hgXk`, `hnXk` | L55 closing openings (as L58) |
| →`wireF` | `hopX1e`, `hgXB` | `hwX0`, `hmX0`, `hgX1`, `hnX1`, `hOX`, `hwXo`, `hfitXo`, `hgXo`, `hnXo` | `sj_hgXB` (RunStgJoinBnd.lean:50, REAL) and L55 |
| →`wireG` | `ops`, `hops`, `hcan`, `hread`, `tag` | — | L58's extractor (REAL in L58) |
| →**`join`** | `E`, `mk`, `hE` | `E0` | L58's `epxMk`/`epxE` (REAL in L58) |
| `join`→**`join_shield`** | `hLb`, `hdefS` | `hPk` | `ShieldRunAt.lb_le`, `.hdefS` (RunBndShield.lean:72-86, L56): REAL |
| `join`→**`bw_wire`** | `Fsl`, `hdefS`, `hsl_argsN` | `progK`, `pubsK`, `hdefK`, `hprogK`, `hNK`, `hoAK`, `hoHK`, `hoIK`, `hoOK` (bw_wire:116-126); `hslB` now at `bwFslRun` | `bwFslRun_slotEvalN` (RunBlkWireSlots.lean:150): REAL; `Fsl` DEFINITIONAL |
| `bw_wire`→**`bw_shield`** | `hLb`, `progK`, `pubsK`, `hdefK`, `hprogK`, `hNK` | `hPk` (bw_shield:413) | `shieldRunProg/Pubs`, `shieldRun_hdef/hprog/hN` (RunBlkWireSlots.lean:188-254), via L49/L54's `progR13_shield_ok`, `r13_shield_mask_facts`: REAL |

## 2. Classification of every removed premise (net, against the L57 ∪ L58 premise sets)

| Premise | Discharged by | Class | Notes |
|---|---|---|---|
| `hsl_blk` | `bnd_hsl_evBN_of_args` + `wr_termBN` (L60), then `bwFslRun_slotEvalN` (L61) | **REAL** (two steps) | The per-adversary slot cover now follows from one adversary-free property. That property is proved for `Fsl := bwFslRun = maskedF (mRowX …) (polyS (dArgs …) prog pubs)`, built from the decoded tables `bndTab` at the A, H roots/cuts and the header's boundary data `hx pi`, `hx po` (RunBlkWireSlots.lean:49-87). Residual cost: `hoAK`…`hoOK` (finding R1-3). |
| `Fsl` (free parameter) | instantiated `:= bwFslRun` | **DEFINITIONAL, faithful** (ARGUED) | `Fsl` was a parameter the user had to supply; fixing it is legitimate if the other premises stay meetable. `D.sls` is free through `base`, and `D.opA/opH/opX` do not read `sls` (RunKindsData.lean:198-214, RunExtractParts.lean:49-57), so `hslB` at `bwFslRun` can be met with no circularity. `hD.slCut` holds for any `blockSchedXB` (L56). `bwFslRun` reads only cut, root and header data, which matches the extractor's polynomial, not a prover-chosen object. |
| `hdefS` | `hdefK` (bw_wire), `hPk` (join_shield, bw_shield) | REAL | `ShieldRunAt.hdefS` is L56's lemma. |
| `hLb` | `ShieldRunAt.lb_le hPk` | REAL | L56's lemma (RunBndShield.lean:80). |
| `progK`, `pubsK`, `hdefK`, `hprogK`, `hNK` | `shieldRun*` from `hPk` | REAL | Programs are chosen with `Classical.choose`, not literally `progR13` (RunBlkWireSlots.lean:229-238). Only their properties are used, so this does not matter. |
| `hgXB` (added in `wireT`) | `sj_hgXB` | REAL | Trivial from `hgX1`, `hgXk`, `hgXo`. |
| `hsl_stg`, `hR0_stg`, `hR1_stg`, `hH0_stg`, `hH1_stg`, `hLU_stg` | L57's `stg_hal_*V` (in `sj_exec_alive`) | **SHIFTED** | Replaced by `hTrI`, `hTrO`, `hDI_stg`, `hDO_stg`, `hLI_stg`, `hLO_stg` + `hb0`, `hbL`, `hPin`, `hPout`, `hNin`, `hNout`, `hIOI`, `hIOO` and the free `ΦI`, `ΦO`, `ΛI`, `ΛO`, `dgI`, `dgO`, `eI`, `eO`. These are L57's reductions; L60 adds nothing to them. |
| `hdin`, `hdout` | `stg_hal_doomV` | **SHIFTED** | To `hdinS`, `hdoutS` (`StgDoomAtV …`), L57's form. |
| `hdblk` (L52) | `rd_hdblkB` | SHIFTED to `hblk` | Same structure as L58's `hblk`, now over `RdBlkR13B`. |
| L58-side removals (`hread`, `hBal`, `mk`, `hE`, `ops`, `hops`, `hcan`, `hW`, `hopX`, `hwin`, XTest family) | L58's lemmas, re-applied by L60's generator | REAL (L58's work) | Not new in L60; correctly carried over. |

**On "adversary-free":** I found no definition in L60/L61 that fixes by definition a quantity the adversary chooses
(ARGUED). `lkSqB` reads the cut and the root the transcript absorbed. `dofARB` (RunBlkWireLk.lean:33-37) sets the M and
H cuts and roots to `[]`/`none`, but only its A planes are used, and `dofARB_aPl` proves they agree with the real data
by `rfl`. `ioDefSchedB` (RunBlkWireDoom.lean:82-96) takes `aIn`, `aOut`, `bIn`, `bOut` as parameters and fixes nothing.
In these files, "adversary-free" means "not parameterised by the prover oracle `A`". The data is still read from the
adversary's transcript. These objects are sound as stated, but none of them is used by any top theorem (R1-1).

## 3. Conclusion check

- `join`, `join_shield`, `bw_wire` and `bw_shield` have the same conclusion text as L58's `codeH` (`CONCL same: True` in
  every diff). It is `ProductionReadyL (classifyModelP Rp) (classifyArithP Rp) (classifyProtocolUExecP Rp Lq Lb … P (CinR)
  h64 hr hon.base 768) (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget`. The section variables
  (`Rr dR pos hpos place hplace tag`) and the `CinR` notation (`epTokenCommit … epxMsg … EpxSalt…`) are identical in
  RunEpXTopH.lean:39-44, RunStgJoinTop.lean:1520-1525 and RunBlkWireTop.lean:37-42. So it is the same proposition about
  the same protocol object and instance, neither weaker nor a different protocol. CHECKED (textual).
- `wireT` and the Chain-file theorems are stated at L57's general salt (`msg`, `pad`, `salt`, `path`, `tagc` section
  variables). That is more general, not weaker. `join` specialises to `EpxSalt`, as L58 did.
- `git diff eee3eb57 HEAD -- formal/ZK60Formal/Statements.lean` is empty. CHECKED.
- The nine reviewed files have no uncommitted changes. CHECKED (`git status`).
- Running the two generators on a copy of `formal/ZK60Formal` reproduces all nine files byte for byte
  (`diff -rq` empty). CHECKED.

## 4. Satisfiability of new or changed hypotheses

No hypothesis in the new top theorems is evidently unmeetable, and I found no jointly contradictory set. I could not
construct a full instance; that needs the real run's data.

| Hypothesis | Real instance plausibly satisfies it? | Why |
|---|---|---|
| `hdefS` | yes | Follows from `hPk` (L56). |
| `hsl_argsN` | yes | Shown constructively: L61 proves it for `bwFslRun` under meetable premises. |
| `Fsl`/`hslB` widened (`HdrX`), `hslB` at `bwFslRun` | yes | `base (k+1)).sls` is free; openings do not depend on `sls`; `slCut` holds for `blockSchedXB`. |
| `AlkL`, `mlkL`, `hLU_blk`, `hR*_blk`, `hblk` (B forms) | at least as meetable as L58's | Generalisations (section 1a). Consistency between `hLU_blk` (every `sx ∈ D.lu (k+1)` is `lkSqB … (AlkL k)`) and `hblk.hlu` forces `RdBlkR13B`'s `hdrLen = off (k+1) + 5` and its `Alk` to match `AlkL k`. That is consistent. |
| Stage set (`hTrI` … `hdoutS`, `hb0`, `hbL`, …) | inherited from L57, now weaker | The extra `¬ exEvIn` antecedent and `W := vdWin Vi` (fixed by L58's `hinc`) only weaken them. NOT VERIFIED here: whether L57's `hdinS`/`hdoutS` with free `ΦI`/`ΛI` are meetable was L57's question, and I did not re-audit it. |
| `progK`, `pubsK`, `hdefK`, `hprogK`, `hNK` | yes | Discharged from `hPk`. |
| `hoAK`, `hoHK` | yes | `(D.opA (k+1)).lc` is `rkR13`'s `14` (RunKindsData.lean:70) through `hDe`/`rxDblk`, and `ShieldBlkAt` gives `logCols = 14` (RunBndShield.lean:49). They are derivable but are left as premises. |
| `hoIK`, `hoOK` | yes at T128, but not derivable from `hPk` | `(D.opX j).lc = 14` (base `gX` = `rkR13 …` through `hgX1`, `hgXk`, `hgXo`), so these require `(Pk k).endpointLogN = 14`. `ShieldBlkAt` only states `0 < endpointLogN`. The Rust shape takes `endpoint_log_n = log_cols` by default (shape.rs:1072), and the Shieldstral R13 T128 profile has `log_cols: 14` (shape.rs:229). True for the real T128 run, but an unproved new premise. At T256 (`log_cols 15`) the Lean model (`rkR13` fixes 14) does not apply anyway. |
| `hPk` | yes | L56's tie, checked by L56 against the export. |

## 5. Hygiene

- `sorry`, `admit`, `axiom`, `native_decide`, `ofReduceBool`, `implemented_by`, `unsafe`, `opaque`, `@[extern]`,
  `maxHeartbeats`, `maxRecDepth`: **none** in the nine files (CHECKED by grep).
- `decide`: three uses on tiny propositions. `(by decide)` arguments at RunStgJoinChain.lean:1108 and :1503 (a numeric
  side condition of `ogEp_ok`), and `¬ (22 = 21)` at RunBlkWireDoom.lean:122. These are kernel `decide` on small goals.
- `set_option`: only `autoImplicit false` and `linter.constructorNameAsVariable false`. Harmless.
- `Classical.choose` in `shieldRunProg`/`shieldRunPubs`: standard.
- **Axioms of the top theorems:** both lane `REPORT.md` files list the top theorems as `['propext']` only (L60
  REPORT.md:25-27, L61 REPORT.md:32-33). The `.txt` audits (`axiom_audit.txt` of both lanes and
  `merged_axiom_audit.txt`) show `[propext,` then `Classical.choice,` and `Quot.sound]` on continuation lines. The
  REPORT generator read only the first line of each wrapped `#print axioms` output. **The `.txt` files are right**: the
  top theorems depend on the three standard axioms. The reports' own "Foundation audit" lines say the same.
- **Guarded re-check (CHECKED, 2026-11-16):** one `lake env lean AxiomProbe.lean` run under the resource guard (class
  `cpu`, exit 0; log `axiom_probe.log`) loaded the compiled modules. It printed `[propext, Classical.choice,
  Quot.sound]` for all five top theorems and for `bwFslRun_slotEvalN`, `hcov_shieldB`, `ioDefSchedB_r13_hIO` and
  `shieldRun_hN`. No `sorryAx` and no other axiom.

## 6. Verdicts on the authors' claims

| Claim (source) | Verdict | Evidence |
|---|---|---|
| Statements.lean diff 0 (L60, L61, batch 3) | **supported** | Empty `git diff eee3eb57 HEAD`. |
| Forbidden tokens 0 | **supported** | grep (section 5). |
| Foundation audit `[propext, Classical.choice, Quot.sound]` only | **supported** | `.txt` audits; guarded probe (`axiom_probe.log`). |
| Top theorems' axioms `['propext']` (REPORT tables) | **not supported** | Parse error; the real list is the three standard axioms. |
| `hsl_blk` PROVED from `hsl_argsN` (join docstring) | **supported** | `bnd_hsl_evBN_of_args`, `wr_termBN`. |
| `hsl_argsN` (`SlotEvalN`) "completely discharged" via `bwFslRun` (L61) | **partly** | Discharged, but `hoAK`, `hoHK`, `hoIK`, `hoOK` are added in its place (bw_wire:123-126, bw_shield:417-420). |
| `bw_..._shield`: "from `hPk` alone … `progR13`, `pubsR13L`, `progOKb`, `hNK`, `SlotEvalN`, `hdefS`, `Lb ≤ 26`" | **partly** | All discharged except that `SlotEvalN` still needs `hoAK`…`hoOK`. "alone" is inaccurate. `hdefS`/`Lb ≤ 26` from `ShieldRunAt` were already L56's (and in `join_shield`). The programs are a `Classical.choose`, not literally `progR13`. |
| "adversary-free R13 LogUp coverage for `RdBlkR13B`" (`dofARB_aPl`, `AlkR13B`, `mlkR13B`, `hcov_r13B`, `hcov_shieldB`) | **partly** | The lemmas are proved and sound as stated, but no top theorem uses them. `hblk` (whose `hcov` field they target) is still a premise everywhere. |
| "hypercube eq-vanishing and adversary-free IO schedule" (`eqB_vanish_zero`, `ioDefSchedB*`) | **partly** | Proved, not used. `RdBlkR13B`'s `DIO`/`hIOΦ`/`hdefIO`/`hIO` are still supplied through `hblk`. |
| Coordinator summary (TODOS line 2787): "proved adversary-free R13 LogUp coverage + IO hypercube eq-vanishing" listed with the discharges | **partly** | Same as the two rows above. A reader would take these as discharges; they are not. |
| L60 joins L57 + L58 (join theorem) | **supported** | Section 1. The join is the union of the open premises. |
| (Implied by MVP_STATUS:44, 77-81 and the L58 doc:99) L60 discharges the stage define/LogUp/doom facts, `hdin`/`hdout`, `hdzero` and settles L57-2 | **not supported** (not claimed in L60's REPORT) | All eight stage facts and `hdzero` remain premises. L57-2 is made moot by generalisation (R1-6), not settled. |
| Build times, "502 modules" | NOT VERIFIED | No build run. The root file imports 474 modules; the 502 count may include dependencies. |

## 7. Findings, ranked

**R1-1 (High): L61's coverage and IO lemmas discharge no premise; the 26-block wiring (`hblk`) is still open.**
`hcov_r13B`, `hcov_shieldB`, `AlkR13B`, `mlkR13B`, `dofARB_aPl`, `eqB_vanish_zero`, `ioDefSchedB`,
`ioDefSchedB_hIOΦ` and `ioDefSchedB_r13_hIO` are referenced only inside their own files (grep over `formal/`; only
`bwFslRun*` and `shieldRun_*` appear in RunBlkWireTop.lean:45-624). Every new top theorem still assumes
`hblk : ∀ A G k, … → Nonempty (RdBlkR13B …)` (bw_shield:578, join:1765). That bundle contains exactly what these lemmas
target (`hcov`, `DIO`, `hIOΦ`, `hdefIO`, `hIO`), plus `hdefR`, `hlu`, `hspec`. MVP_STATUS:44 names this wiring as L61's
job, and the lane and coordinator texts present the lemmas next to real discharges.
*Smallest repair:* say in both REPORTs and MVP_STATUS that these are unused lemmas and `hblk` stays open. The next lane
builds `RdBlkR13B` from `hPk`, using `hcov_shieldB` for `hcov` and `ioDefSchedB` for `DIO`. That also needs to prove that
`ioDefSchedB`'s draws are members of `D.r0…h1 (k+1)` (`hdefIO`) and that `bIn`/`bOut` are the header's boundary tables.

**R1-2 (High): L60's assigned stage obligations are shifted, not proved; the open-premise count went up.**
Against L58's `codeH`, L60 removes `hsl_stg`, `hR0_stg`, `hR1_stg`, `hH0_stg`, `hH1_stg`, `hLU_stg`, `hdin`, `hdout` only
by importing L57's reduction to `hTrI`, `hTrO`, `hDI_stg`, `hDO_stg`, `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS` (join:1632-1774,
bw_shield:445-587), with 20 set-up premises. `hdzero` is unchanged (codeH:290 = join:1782). The parsed binder count rises
from 144 to 165 (`join`) and 166 (`bw_shield`). The only substantive new discharge across L60+L61 is `hsl_blk`. Nothing
false is claimed in L60's REPORT, but MVP_STATUS still lists these as L60's targets. The batch-3 report states the build
and axiom audits without saying what stays open.
*Smallest repair:* update MVP_STATUS with the open list: the eight stage facts, `hdzero`, `hblk`, `hR0_blk`…`hLU_blk`,
`O`, `hzk`. Name `bw_productionReadyL_epP_shield` as the current top theorem. Open a lane for the stage facts proper.

**R1-3 (Medium): "`hsl_argsN` completely discharged" / "from `hPk` alone" overstates; four new premises.**
`bw_wire` and `bw_shield` add `hoAK`, `hoHK`, `hoIK`, `hoOK` (bw_shield:417-420). `hoAK` and `hoHK` follow from `hDe`
(`rkR13`'s `lc = 14`) and `ShieldBlkAt`'s `logCols = 14`. `hoIK` and `hoOK` need `(Pk k).endpointLogN = 14`.
`ShieldBlkAt` (RunBndShield.lean:39-52) only states `0 < endpointLogN`. The fact holds in Rust at T128 (shape.rs:1072,
229) but is unproved in Lean.
*Smallest repair:* derive `hoAK`/`hoHK` inside `bw_shield` from `hDe` + `hPk`. Add `P.endpointLogN = 14` to `ShieldBlkAt`
(or `IsShieldR13`), checked against the shape export as L56 did, and derive `hoIK`/`hoOK`.

**R1-4 (Low): REPORT axiom tables misreport the top theorems as `['propext']`.** The audit `.txt` files show the three
standard axioms on wrapped lines. The REPORT generator takes only the first line.
*Repair:* parse `#print axioms` output up to the closing `]`, or print with a wide `format.width`.

**R1-5 (Low): stale docstrings.** `sj_..._code`, `codeT`, `wireT`, `wireW`, `wireX`, `wireF` and `wireG` carry L58's
docstring verbatim ("…Generated by `results/zk60_lean_l58_20261110/l58_mk_chain.py`", e.g. RunStgJoinTop.lean:46-52),
though they are L60 theorems with different premises. `sj_..._exec_blk`'s docstring still names `RdBlkR13` (L46).
`bw_..._shield`'s docstring says "from `hPk` alone".
*Repair:* regenerate the docstrings from the generator with each step's actual removed and added premises.

**R1-6 (Low, informational): L57-2 sidestepped, not settled.** L60 replaced `lkSq` (whose `Alk` reads only the cut)
with `lkSqB` (`Alk` also reads the absorbed `A` root). This is a sound generalisation: old witnesses map to new ones, so
the premises got weaker. Whether the old form was unmeetable (L57-2) or answered by L47-2 is left undecided and is now
moot. MVP_STATUS:79-81 should record it that way.

**R1-7 (Low): wording of the "synthesis".** `shieldRunProg`/`shieldRunPubs` are `Classical.choose` witnesses
(RunBlkWireSlots.lean:229-238), not literally `progR13`/`pubsR13L`. That is harmless because only `define`-equality and
`progOKb` are used.

## 8. What I could not verify

- Whether the full premise set of `bw_productionReadyL_epP_shield` is jointly satisfiable by the real run. No instance was
  built. In particular, L57's stage facts (`hdinS`, `hdoutS` with free `ΦI`, `ΛI`) were not re-audited.
- Whether the compiled `.olean` files match the sources. The sources' mtimes (checkout, 22:43:35) are later than the
  `.olean`s (22:43:12); the generators reproduce the sources exactly. I did not rebuild.
- The authors' build wall times and the "502 modules" count.
- The faithfulness of `ioDefSchedB` to the Rust `SC_IO_IN`/`SC_IO_OUT` define draws. It is unused, so this matters only
  for the next lane.
