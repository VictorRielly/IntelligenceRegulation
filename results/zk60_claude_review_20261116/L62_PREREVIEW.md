# Pre-review of Lean lane L62 (`formal/ZK60Formal/RunBlkShieldInst.lean`), as found on disk

- **Reviewer:** Claude (read-only pre-review, 2026-11-16, requested by the co-coordinator before the author, the
  Antigravity coordinator, has declared L62 finished). Nothing under the main checkout's `formal/` was written, moved or
  built; no git write anywhere.
- **File reviewed:** `formal/ZK60Formal/RunBlkShieldInst.lean`, untracked, 707 lines, 63,507 bytes, last written
  16:08:02Z. sha256 `c68a7c490561a309924eb89984ea3701ef025d630b5fea36c3cb182701a4249c` at the start of the review (about 17:30Z) and
  `c68a7c490561a309924eb89984ea3701ef025d630b5fea36c3cb182701a4249c (unchanged)` at the end (18:17:50Z). It is byte-identical to the `LEAN_L62_FIXED` text inside the author's
  `results/zk60_coord_batch4_20261115/finish_batch4_and_reviews.py` (lines 177-883), i.e. the version the author's
  fourth (queued) check builds.
- **Builds:** in worktree `.claude/worktrees/agent-a8b5788916259e1b2` (base `1668946a`; its `formal/ZK60Formal/*.lean`
  are byte-identical to the main checkout's for every file both have, CHECKED by hash), as scratch modules
  `L62Scratch.lean` (the file unchanged) and `L62Scratch2.lean` (patched), each a guarded `cpu` job (label
  `lean-l62-review`). Scripts, plans and logs: `l62_prereview/`.
- **Labels:** PROVED = a green build I ran confirms it; CHECKED = read against the cited file and line; ARGUED = my
  reasoning, not machine-checked; NOT VERIFIED = not settled.

## 0. In plain words

- **The file compiles as it is.** My guarded build of an unchanged copy finished with no errors (four harmless style
  warnings). The author's earlier failures were from earlier versions; the version on disk now is fine. No repair was
  needed; the only patch I propose silences the four warnings.
- **It removes four small leftover assumptions properly** (`hoAK`, `hoHK`, `hoIK`, `hoOK`, the column sizes of the
  openings), at the price of one new, true but unchecked assumption ("the endpoint size is 14").
- **It does not yet remove the big one.** The 26-block bundle `hblk` is gone by name, but a new assumption `hblkS`
  takes its place, and it still asks for the parts of `hblk` that depend on the actual proof transcript (the define and
  lookup draws sitting in the right lists, the header length, and how block inputs and outputs are read). What is now
  genuinely proved is the fixed, public half of the bundle (layout, tables, lookup coverage, the input/output check's
  algebra). That is real progress, but the summary "discharges `hblk`" overstates it.
- **Nothing found is false or unmeetable**; the open items are named below with a concrete next step for each.

## 1. Build state

| Item | Result | Label |
|---|---|---|
| Unchanged copy `L62Scratch` (sha256 `c68a7c49…`) | `lake build ZK60Formal.L62Scratch`: rc 0, 0 errors, 4 warnings (all four: `linter.unusedSectionVars`, `[Fintype K] [DecidableEq K]` in `shield_hoAK`, `shield_hoHK`, `shield_hoIK`, `shield_hoOK`, L62Scratch.lean:306, 325, 344, 363). Guarded job `iter1` (admitted after 1,685 s; 16 s wall; peak 4.00 GiB), log `l62_prereview/iter1.log` lines 5-48 | PROVED |
| Compiled as found? | **Yes** (0 errors). No statement or proof needed changing | PROVED |
| Patched copy | `L62Scratch3` = the file plus `omit [Fintype K] [DecidableEq K] in` before the four `shield_ho*K` theorems: `lake build ZK60Formal.L62Scratch3`: rc 0, 0 errors, 0 warnings in the L62 file (job `iter2`, admitted after 762 s, 10 s wall, peak 4.00 GiB; `iter2.log` lines 4-19). Patch: `l62_prereview/l62_fix.patch` (patched sha256 `8e66b103…`) | PROVED |
| Axioms of the as-found module | One `lake env lean L62ScratchAxioms.lean` importing the unchanged `L62Scratch` (job `iter2`, `iter2.log` lines 21-38): `propext, Classical.choice, Quot.sound` for `rdBlkR13B_shield`, `ShieldBlkRunData`, `nonempty_rdBlkR13B_of_shieldBlkRunData`, `shield_hoAK`, `shield_hoHK`, `shield_hoIK`, `shield_hoOK`, `RunShapeP.bw_productionReadyL_epP_shield_r13` (wrapped lines joined), `rdBlkR13B_cast`, `shieldRun_logCols`; `[propext]` for `shield_draws_21/22`; none for `rxPs_gX_succ`, `rxPs_succ_lt`. No `sorryAx`, no other axiom | PROVED |
| Root module `ZK60Formal` (the main checkout's root already has `import ZK60Formal.RunBlkShieldInst` at line 474, uncommitted, added by the author's script) | not built by me (out of scope; the main checkout's `.lake` belongs to the author) | NOT VERIFIED |

Notes. (a) My first job also built a variant `L62Scratch2` in which I had rewritten the two `rxPs` helper proofs,
expecting `dsimp only [rxPs]` to leave a `match` (the author's third check failed exactly there, on an earlier
version). The unchanged file built green, so that rewrite is unnecessary and is not proposed; job 1's axiom lines
(iter1.log:94-111) are for that variant and are superseded by job 2's. (b) The author's check logs
(`results/zk60_coord_batch4_20261115/batch4.log`) show three earlier versions failing (unknown `dXof`, ambiguous
`ZClaim`, `rxPs` rewriting, a heartbeat timeout, `split_ifs`); the on-disk file is byte-identical to the
`LEAN_L62_FIXED` text in `finish_batch4_and_reviews.py`:177-883, the version the queued fourth check builds. That
check also builds the full root; my result says nothing about the root.

## 2. Premise diff: `bw_productionReadyL_epP_shield` (RunBlkWireTop.lean:344) → `RunShapeP.bw_productionReadyL_epP_shield_r13` (RunBlkShieldInst.lean:412)

Parsed with `l62_prereview/premise_diff.py` (reuses `binders.py`; normalises the notation name `CinS`→`CinR`). Binder
count 166 → 164 (the script's own total, 163 → 161, folds the four anonymous instance binders). CHECKED.

| Status | Binders |
|---|---|
| Removed (5) | `hoAK`, `hoHK`, `hoIK`, `hoOK`, `hblk` |
| Added (3) | `hL20 : 2 ^ 20 ≤ Lq`; `hep14 : ∀ k, k < Lb → (Pk k).endpointLogN = 14`; `hblkS : ∀ A G k hk, verify … = true → ¬ (EvXR … ∨ exEvIn …) → ShieldBlkRunData hL20 Rp Pk U D k hk lg τ absOf Xin Xout` (same antecedents and the same `Xin`/`Xout` = `epxE … .planes k`, `.planes (k + 1)` as `hblk`) |
| Changed (5) | `Rp`, `P`, `site`, `E0`: `S` specialised to `shieldS0` (the block carrier); `hslB`: its four `hoXK` arguments become `shield_hoAK hDe (fun _ _ => rfl) hPk`, `shield_hoHK …`, `shield_hoIK hDe … hep14`, `shield_hoOK hDe … hep14` |
| Kept (153 named + 4 instance binders) | everything else, including all eight stage facts, `hdzero`, `hR0_blk`…`hH1_blk`, `hLU_blk`, `O`, `hzk`, `hPk`, `hDe` |
| Conclusion | identical text (`CONCL same: True`). CHECKED |

So: **`hblk` is gone by name and replaced by `hblkS`; `hoAK`…`hoOK` are gone** (two derived from `hDe` + `hPk`, two
from the new `hep14`). Specialising `S := shieldS0` is a narrowing to the app's carrier, which `hPk`'s
`ShieldRunAt … Rp.blks` already implies in use (ARGUED).

## 3. What `ShieldBlkRunData` contains (RunBlkShieldInst.lean:210-268)

One field, `exists_layer`: there exist `Ly Pb tag rowsOf Lay B hP hlc hdrLen rE QE XE bIn bOut bga rs` with ten
conjuncts. Against `RdBlkR13B` (RunStgJoinLk.lean:396-458):

| # | Conjunct | Kind | Comment |
|---|---|---|---|
| w | witnesses `hP : IsShieldR13 (Pk k) tag rowsOf`, `hlc : (Pk k).logCols = 14` | (i) public | Already given by `hPk` (`ShieldBlkAt`, RunBndShield.lean:46-49). Redundant. CHECKED |
| 1 | `Ly ∈ shieldExport` | (i) public | `hPk` gives `shieldExport[k]? = some Ly'`; this `Ly` is not tied to `Ly'`. Redundant, untied. CHECKED |
| 2 | `Rp.blks[k].cal = shieldCal Ly` | (i) public | From `hPk` (`b.cal = shieldCal Ly'`). Redundant. CHECKED |
| 3 | `HEq Pb Rp.blks[k].pub` | (i) public | From `hPk`. Redundant. CHECKED |
| 4 | `LayR Lay` | (i) public | `ShieldBlkAt` already carries `LayR` for its layout. Redundant. CHECKED |
| 5, 6 | `hXin`, `hXout`: `Xin p = piB K (bIn (hdrX absOf lg hdrLen τ) (Fin.append (Lay.dPos p)…))`, same for `Xout`/`bOut` | (iii) assumption | `Xin` is the extractor's plane `epxE … .planes k` and `bIn`, `bOut` are existential, undefined functions. These replace `RdBlkR13B.hIO`; the R1-1 obligation "`bIn`/`bOut` are the header's boundary tables" is not met (§5). CHECKED |
| 7 | `hdefR` (four relation layers' define squeezes `RdDefAt D (k+1) τ bga rs …`) | (iii) = `RdBlkR13B.hdefR` verbatim at the instance's `sh`, `dt`, `hcard := card_K_gt K` | Its parts: membership in `D.r0…h1 (k+1)` (a fact about how the fixed `D` is built), `defPos ≤ τ.length` and the `tHistD` parse of the transcript with existential `bga`, `rs` (run-level, from acceptance). CHECKED (RunDoomBlk.lean:265-268) |
| 8 | `hdefIO` (slots 21, 22 under `ioDefSchedB`) | (iii) = `RdBlkR13B.hdefIO` at `DIO := ioDefSchedB …` | Same three parts. CHECKED |
| 9 | `hlu` (`lkSqB … (AlkR13B …) (TR13 …) (mlkR13B …) ∈ D.lu (k+1)`) | (iii) = `RdBlkR13B.hlu` | A fact about `D`'s construction. CHECKED |
| 10 | `hdrLen + 4 ≤ τ.length` | (ii) run-level | = `RdBlkR13B.hlen`. CHECKED |

Proved by `rdBlkR13B_shield` (PROVED by the build; all from L61/L49 lemmas): the six carrier types and their instances,
`ls := 1`, `Lay`, `B`, `hWr` (`shield_shapes_r13`), `h24` (`rfl`), `P`, `sh` (`algShapeR`), `dt` (`dtR`), `xtE`
(`xtR … dXof …`), `enc`, `encHt`, `hspec` (`hspecR`), `hTok`, `hHd` (from `LayR`), `DIO := ioDefSchedB`, `hIOΦ`
(`ioDefSchedB_hIOΦ`), `hIO` (`ioDefSchedB_r13_hIO` from conjuncts 5-6), `ι`, `π`, `κ`, `Alk := AlkR13B`, `T := TR13`,
`mlk := mlkR13B`, `hTtab` (`hTtab_shield`), `hcov` (`hcov_shieldB`). This fixes R1-1's first half: L61's
`hcov_shieldB`, `AlkR13B`, `mlkR13B`, `ioDefSchedB`, `ioDefSchedB_hIOΦ`, `ioDefSchedB_r13_hIO` are now used by a top
theorem.

**Assumes what it should prove?** Partly, by design: conjuncts 7-10 are `RdBlkR13B`'s four transcript-dependent fields
copied word for word, and 5-6 are the IO tie in a new form. **Unmeetable field?** None found (ARGUED): the
memberships hold if `base (k+1)`'s lists are built to contain these squeezes (`D.r0 (k+1) = (base (k+1)).r0` is free
through `hDe`, since `rxSet` overrides only `S k mpos gA gH nA nH`, RunExtractParts.lean:49-50); `ioDefSchedB`'s `Φ` is
multilinear in the draws, so `IndDegLE 1` for `hD`'s round condition is plausible; the `tHistD` parse is L21's
`tHistD_trace` on an accepted transcript. Two consistency constraints are left to whoever discharges `hblkS`:
`hLU_blk` forces every `sx ∈ D.lu (k+1)` to be `lkSqB … (AlkL k) (TL k) (mlkL k)` with `hdrLen = off (k+1) + 5`
(RaLkAtB, RunStgJoinLk.lean:148-153), so the existential `hdrLen`, `Ly`, `Lay`, `B`, `tag`, `XE` must in effect be the
same for every adversary and match `AlkL k`; and `hdefIO` with the fixed `D` pins `bIn`, `bOut` to the ones `D` was
built with, which then makes conjuncts 5-6 real constraints on the extractor `E0` (a free parameter).

## 4. Findings

**L62-1 (High): `hblk` is shifted, not discharged.** `hblkS` (RunBlkShieldInst.lean:646-654) asks, for every
adversary and block, for `ShieldBlkRunData`, whose conjuncts 7-10 are `RdBlkR13B`'s `hdefR`, `hdefIO`, `hlu`, `hlen`
verbatim and whose 5-6 replace `hIO` (§3). CHECKED. What L62 really proves is the public half of the bundle
(PROVED, §3), which is worthwhile and makes L61's lemmas count. The author's prepared coordination text
(`finish_batch4_and_reviews.py`:1137, "Discharges `hblk` via `rdBlkR13B_shield` … + `ShieldBlkRunData`") overstates;
the same sentence correctly says a lane L64 will discharge `hdefR`/`hdefIO`/`hlu`. *Repair:* word it as "`hblk`
reduced to `hblkS` (transcript facts only)" in the REPORT, MVP_STATUS and the coordination entry.

**L62-2 (High): R1-1's second requirement is not met.** R1-1 asked L62 to prove `hdefIO` and that `bIn`/`bOut` are
the header's boundary tables. `hdefIO` is ASSUMED (conjunct 8). `bIn`, `bOut` are existential, never defined
(RunBlkShieldInst.lean:227); conjuncts 5-6 only assume that the extractor's planes equal them. MISSING. CHECKED.
*Repair (next lane):* define `bIn`, `bOut` as functions of `HdrX` that read the boundary commitment the header absorbs
(presumably the one the closing openings `D.opX (k+1)`, `D.opX (k+2)` are checked against; ARGUED), prove `epxE`'s planes are those tables (or define `E0`'s
planes that way), and prove the `hdefIO` memberships from how `base` is built.

**L62-3 (Medium): R1-3 is half met.** `hoAK`, `hoHK` are now derived from `hDe` and `hPk` (`shield_hoAK`,
`shield_hoHK`, with `hdA`/`hdH` by `rfl` through `rxDblk`/`rkR13`'s `lc = 14`): PROVED. `hoIK`, `hoOK` are derived
from a new top-level premise `hep14` (RunBlkShieldInst.lean:485): PROVED from it. But R1-3 asked for
`endpointLogN = 14` inside the shield predicate, checked against the export as L56 did (`l56_src_check.py` style);
`ShieldBlkAt` (RunBndShield.lean:49) still says only `0 < P.endpointLogN`, and no export/source check of shape.rs:1072
(`endpoint_log_n` defaults to `log_cols`) and :229 (T128 `log_cols: 14`) exists for L62. CHECKED. The fact is true at
T128 (R1's reading), so `hep14` is meetable. *Repair:* add `P.endpointLogN = 14` to `ShieldBlkAt` (RunBndShield.lean,
L56's file; the anonymous-constructor patterns that destructure it, e.g. `ShieldBlkAt.defineS` and L62's
`shieldRun_logCols`, may need adjusting depending on where the conjunct goes) or to `IsShieldR13`, add the shape.rs source check, and derive `hep14` from `hPk`.

**L62-4 (SETTLED in §9: SAME; now Low): `ioDefSchedB` is now load-bearing, and its fidelity to the code's IO slots was
unchecked at the time of the pre-review.** The mask-commitment worry below was wrong; see §9. Through `hdefIO` its squeezes enter `D.r0…h1 (k+1)`, and `hR0_blk`…`hH1_blk` then require each of them
alive: its `Φ = Σ_b eq(y, b)·(aIn − bIn)` must vanish at the drawn challenges on every accepted run (RaDefAtB,
RunBndDef.lean:201-212). That holds only if the code's `SC_IO_IN`/`SC_IO_OUT` define residual equals this `Φ` wherever
the code accepts. The code's program numbers IO mask rows into the slots (`progR13 … ioIn ioOut` = `numProg … ioIn
ioOut …`, BlockR13Prog.lean:666), so the code's IO check also reads the mask commitment; whether its residual is
`ioDefSchedB`'s was not checked by L61, R1 (§8) or me. If it is not, `hblkS.hdefIO` and `hR*_blk` are jointly
unmeetable. *Repair:* a source/fixture check of `ioDefSchedB` against the code's slot 21/22 `define` (or derive the
IO schedule from `progR13`'s slots, as `w16r2DR` does for the relation layers).

**L62-5 (Low): `ShieldBlkRunData` carries six conjuncts already implied by `hPk` and leaves `Ly`, `tag`, `hdrLen`
untied.** Conjuncts w, 1-4 (§3) follow from `hPk`; `Ly` is not required to be `shieldExport[k]`, `tag` not the run's
`tag` (`htB`), `hdrLen` not `off (k+1) + 5`. Not unsound (they are premises), but it makes `hblkS` larger than needed
and pushes consistency onto the next lane (§3). CHECKED. *Repair:* take `Ly`, `Pb`, `tag`, `rowsOf`, `Lay`, `B`, `hP`,
`hlc` from `hPk` by `Classical.choose` (as `shieldRunProg` does, RunBlkWireSlots.lean:229-238), fix
`hdrLen := (RtRun.pf Rn).off (k+1) + 5`, and keep only the run-level fields.

**L62-6 (Low): warnings and duplicate helpers.** The four `shield_ho*K` theorems carry unused section instances
(4 warnings; the prepared text claims "0 warnings"). `rxPs_succ_lt` restates `rxPs_blk` (RunExtractParts.lean:107) and
`rxPs_gX_succ` is `rxPs_gX` (RunBndSem.lean:96) at `i + 1`; reusing them avoids two names. `shield_draws_21/22` depend
on `propext` only. CHECKED; the warning fix is `l62_prereview/l62_fix.patch` (built green with 0 warnings, job `iter2`).

**L62-7 (Info): the stage finding L63-4 does not carry over to the block defines (ARGUED, partly CHECKED).** The
block `defineS` does refuse a zero `ν`/`ζ` (`SlotS.nonzero`, BlockDefineSym.lean:194-199, refusal at :225). But
`w16r2DR` is `schedOf … (spR i) (fun _ => 80)` over certified slot polynomials (CoverW16Inst.lean:45-47), and
`SlotPoly` carries `hdeg : IndDegLE dg Φ` (SlotPolyW16.lean:30-35); `ioDefSchedB`'s `Φ` has no refusal branch either
(RunBlkWireDoom.lean:82-96). So `hD`'s round condition for these entries is Schwartz–Zippel with no extra escape, and
the refusal only strengthens acceptance in the alive direction (`hR*_blk`, still open), where acceptance gives
nonzero challenges and hence residual = polynomial. L62 itself proves no `hdefR` (it is assumed), so no refusal branch
is traversed in this file. The author's statement to the same effect (`finish_batch4_and_reviews.py`:1018-1019) agrees
with this reading; it still depends on L62-4 for slots 21/22.

**L62-8 (Info): `hL20 : 2 ^ 20 ≤ Lq`** is a new public premise used by `dXof`/`dofARB`; L49's block theorems already
assume it, and it is consistent with `hL64` (ARGUED).

## 5. Answers to the brief's questions

- (a) `hblk` gone: yes by name, replaced by `hblkS` (L62-1). `hoAK`, `hoHK`, `hoIK`, `hoOK` gone: yes; new `hL20`, `hep14`.
- (b) `ShieldBlkRunData`: §3. Six (i)-kind conjuncts redundant with `hPk`; one (ii) (`hlen`); five (iii) restating
  `RdBlkR13B` (`hdefR`, `hdefIO`, `hlu`) or replacing its `hIO` (`hXin`, `hXout`). No field found that no real run can meet.
- (c) R1-1: `hdefIO` ASSUMED; "`bIn`/`bOut` are the header's boundary tables" MISSING (L62-2).
- (d) R1-3: `endpointLogN = 14` is a separate premise, not in the shield predicate, not tied to the export; `hoAK`/`hoHK`
  derived from `hDe` + `hPk`, `hoIK`/`hoOK` from `hep14` (L62-3).
- (e) Block `define` refuses a zero challenge, but L62 has no `hdefR` argument to go through it; the block defines are
  refusal-free polynomials, so L63-4 does not apply (L62-7).

## 6. What the author should do next

1. Post L62 as "compiles; `hblk` reduced to `hblkS`", not "discharges `hblk`" (L62-1), and list `hblkS`, `hep14`,
   `hL20` as open/new premises in MVP_STATUS.
2. Apply the warnings patch or equivalent (L62-6) before merging.
3. In the next lane: derive conjuncts w, 1-4 from `hPk` and fix `hdrLen` (L62-5); define `bIn`/`bOut` and prove the IO
   ties and `hdefIO` (L62-2); check `ioDefSchedB` against the code's slots 21/22 (L62-4); move `endpointLogN = 14` into
   the shield predicate with a shape.rs check (L62-3).

## 7. Files

- `l62_prereview/run_guarded.py`, `iter.sh`: copies of the L63 lane's, label `lean-l62-review`, `ZK60_GUARD_POLL_SECS=0.05`,
  output cap 3000 lines. `plan1.txt`, `plan2.txt`; logs `iter1.log`, `iter2.log` (+ `.guard`, `.done`).
- `l62_prereview/premise_diff.py` (§2), `make_patch.py`, `l62_fix.patch` (proposal; not applied).
- Scratch modules in the worktree (allowed names only): `formal/ZK60Formal/L62Scratch.lean` (unchanged copy),
  `L62Scratch2.lean` (superseded `rxPs` rewrite), `L62Scratch3.lean` (warnings patch), `L62ScratchAxioms.lean`.


## 9. L62-4 settled (follow-up, 2026-11-16)

**Question.** On every accepted run, is `ioDefSchedB`'s residual at slots 21 and 22
(`Φ = Σ_b eqB(y, b)·(aIn b − bIn hx b)`, RunBlkWireDoom.lean:82-96, and the `aOut`/`bOut` twin) what the code's
`define` computes for `SC_IO_IN` / `SC_IO_OUT` at the drawn challenges?

**Verdict: SAME** (CHECKED against the Rust source and against the Lean execution model; the code-model side is partly
PROVED by a probe; no existing theorem links the two). This holds under two conditions that L62's statement does not
yet secure. Neither condition is a difference in the polynomial:
- (A) the witness `bIn`/`bOut` must be the endpoint tables (L62-2, carried by `hblkS`);
- (B) slots 21/22 must have kind `standalone` (new finding L62-9 below).

With both conditions met, no accepted run separates `hdefIO` from the alive premises.

| Point | Rust (`hashline/src/private_block/`) | Lean execution model | `ioDefSchedB` (as L62 instantiates it) | Same? |
|---|---|---|---|---|
| Draws | `tau = tr.challenge_fp2_vec(sh.log(Dom::D))`, the slot's only draw (argument.rs:2958) | `R13.draws sh 21 = W16R2.draws sh 21 = [(.tau, logs .D)]` (SlotW16R2.lean:203, SlotR13.lean:41); `seg c 21 0 = dr 21 0 … dr 21 18` (BlockR13Prog.lean:262-264); at Shieldstral `logs D = 19 = lt 7 + ld 12` (SlotR13.lean:97-110) | `n := nD c = c.sh.lt + c.sh.ld`, `y ⟨i⟩` for `i < n` (RunBlkWireDoom.lean:89-90) | **yes**: the same 19 draws in the same order, and all of the slot's draws. PROVED: `io_nD` (`nD = P.draws 21 = P.draws 22` at any `P.draws = shieldDraws`), `io_drawsList`, `io_seg` |
| Zero refusal | none: the arm calls no `nonzero(…)`. Other arms do: argument.rs:2053-2054 etc.; the helper is at :1854 | `rawSlot c 21`'s `nonzero = []` | no refusal branch | **yes**. PROVED (`io_rawSlot`) |
| Tables | `b.eq(&tau, 0)`; `b.a(ids.at(A_X / A_X2))`; `b.endpoint(Cm::In / Cm::Out)` (argument.rs:2959-2962) | `[TabS.eq (seg c s 0) 0, aPlane c 8 / 44, epTab c .inp / .out]`; plane ids `x = 8`, `x2 = 41 + 3 = 44` at `h24` (BlockR13Prog.lean:126-139, 656-658) | `aIn := aPl … (offR c 8) …`, `aOut := aPl … (offR c 44) …` (RunBlkShieldInst.lean:120-123); `bIn`, `bOut`: free | planes **yes**, PROVED (`io_rawSlot`, `io_ids`). The endpoint side is **yes only if** `bIn hx` / `bOut hx` is the `Cm::In` / `Cm::Out` endpoint table (condition A) |
| Polynomial, sign | `v[0]·(v[1] − v[2])` = eq·(plane − endpoint) (argument.rs:2963) | `ioIr cstS 0 1 2` = one term `eq(τ)·node0`, `node0 = 1·tab1 + (−1)·tab2` (SlotW16Build.lean:159-160) | `eqB(y, b)·(aIn b − bIn b)` | **yes**: plane minus endpoint. PROVED for the model's IR (`io_rawSlot`) |
| Hosted terms, masks | `b.finish(…, vec![])`: nothing hosted | `hosted = []`. `io_mask_row` is the endpoint table's own reserved opening pair (`setRow … .inp => ioIn`, BlockDefineW16.lean:504-511), not the mask commitment `M`, and it does not enter the define | none | **yes**. This corrects my L62-4 text, which suspected an `M` term |
| eq convention | `Tab::Eq { point: tau, start: 0 }` (argument.rs:1550-1551): eq over the slot's variables `0…18`, paired with `tau` in order | the same; `mle::eq_table` is LSB-first (`eqTable`, ExecMle.lean:396-409) | `eqB(y, b) = ∏ᵢ eq1(yᵢ, bᵢ)`, `eq1(t, true) = t`, `eq1(t, false) = 1 − t` (RunBlkWireDoom.lean:35-40); `aPl … b` is `planeZ` at the boolean point with variable `a := b a` (BlockJoinCube.lean:282-283) | **yes** (ARGUED). The hypercube sum runs over named variables, and eq, the plane and the endpoint table are all read at the same variables, so the storage bit order of the tables cannot enter. `planeZ` ignores the coordinates field (`planeZ_aPl`, BlockJoinW16.lean:85) |
| Claimed sum | `SlotKind::Standalone` for 21 and 22: "public zero claimed sum; publishes Γ = cG" (layout.rs:1067-1100, entries 21-22 at :1099-1100) | `claimOf` = `hostedSum … scalar []` = the slot's own scalar; for a `standalone` slot `slotAcc` adds the `M` functional `⟨[(s, sw)], scalar⟩` (ExecBlockVerify.lean:279-283, 302-319), so after unmasking the cube sum is 0 | `Φ(drawn) = 0` is what `RaDefAtB` asks (RunBndDef.lean:201-212) | **yes if** `P.kind 21 = P.kind 22 = standalone` (condition B) |

**Existing Lean link?** None. `ioDefSchedB` and its `Φ` appear only in RunBlkWireDoom.lean and in L62's file (grep over
`formal/ZK60Formal/`). RunBndDef.lean:5-7 states the identity in a docstring only. L61's `bwFslRun` builds the slot side
of slot 21 from the program itself (`polyS … prog pubs`, RunBlkWireSlots.lean:49-87), but no theorem equates its cube
sum with `ioDefSchedB.Φ`.

**Probe (PROVED).** `formal/ZK60Formal/L62ScratchIO.lean` in the L63 worktree, one guarded job (`iter3`, admitted
after 802 s, 4 s wall, peak 3.45 GiB, rc 0, `l62_prereview/iter3.log`). It proves `io_nD`, `io_drawsList`, `io_seg`,
`io_ids` and `io_rawSlot` at every Shieldstral layer, each on `[propext]` only.

**Why the two conditions matter, and who carries them.**
- (A) `bIn`/`bOut` are existential in `ShieldBlkRunData`. With any other choice, `Φ` is a different polynomial, and on
  an honest accepted run `Σ eq(τ, x)(A − bIn)` need not vanish. The run would then fail the alive premises `hR*_blk`
  for an entry that `hdefIO` put into `D`. Nothing in L62 forces the right choice; this is L62-2. The right choice is
  `bIn hx b :=` the extracted `Cm::In` endpoint table at `b`, read through the header root that `bwFslRun` already uses
  for the slot side.
- (B) **L62-9 (Low, new): the shield predicate does not fix the IO slots' kind.** `ShieldBlkAt` (RunBndShield.lean:50)
  pins `kind 3`, `19` and `20` to `standalone` but not `21` and `22`, and `IsShieldR13` (BlockInstProf.lean:273-283) has
  no kinds. The verifier model refuses `host` for a slot with nothing hosted (ExecBlockVerify.lean:291), but it allows
  `priv`. A `priv` IO slot publishes only a masked scalar that no host consumes, so acceptance would not force the cube
  sum to 0. The fact is true in the code (layout.rs:1099-1100) and L62's premises stay meetable for the real verifier.
  The lane that proves `hR*_blk` for the IO entries will still need it. *Repair:* add `P.kind 21 = standalone ∧ P.kind
  22 = standalone` to `ShieldBlkAt`, export-checked alongside R1-3's `endpointLogN = 14`.

**Severity after settling:** L62-4 drops to Low and closes as a fidelity question. What remains open is L62-2 (define
`bIn`/`bOut`) and L62-9 (the kinds).
