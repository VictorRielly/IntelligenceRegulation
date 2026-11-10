# D63 lane L31: the block instance. Profiles, the accumulator's reader, the claim counts, the corrected evaluation interface, and the mask half of the slot polynomials (2026-11-09)

Lean lane L31 (Claude), on its own worktree at perf `6e788dcb` (L9 to L29 merged). Lean 4.34.1, Mathlib v4.34.1, no new
dependency. Eight new library files under `formal/ZK60Formal/`, imported by the library root: `BlockInstRead.lean`,
`BlockInstProf.lean`, `BlockInstRung.lean`, `BlockInstShield.lean`, `SlotPolyInstMask.lean`, `SlotPolyInstEval.lean`,
`BlockInstChainN.lean`, `BlockInstFinal.lean`. One checker, `BlockInstCheck.lean`, not imported by the root. No Rust.
`Statements.lean` and every existing Lean file are unchanged. Evidence: `results/zk60_lean_l31_20261109/`.

**STATUS: part A done; of part B, the mask half of item 2 and the final statements in their present form; the rest of
part B is left (§6). The check of §7 is green.** The merged-tree check is the coordinator's.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**MEASURED** (read off a real receipt and checked by `BlockInstCheck`), **ESTIMATE** (derived by a rule, no receipt),
**ARGUED** (a reasoned claim, not a Lean theorem), **HYPOTHESIS** (a named premise, with the shape a later lane must
prove), **LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** Lane L28 proved the security statement of ONE transformer block: "the chance that the
block verifier accepts while the committed data breaks the block's equations is at most your target". That statement
still assumed two lists of things. List A was bookkeeping: the block's concrete numbers, how many claims each opening
carries, and a "reader" that recovers the verifier's working lists from its transcript. List B was the algebra: the
block's 23 slot polynomials written out over the committed data, and the facts about them. This lane was to remove
list A, then as much of list B as it could, in order.

**What is now proved.**
1. **List A is gone.** PROVED, for three block profiles: the W16R2 test rung, the R13 test rung, and the Shieldstral
   T128 R13 block, which is the block the media app's classifier really runs.
   - The concrete numbers of each profile are built, with their size bounds (`profW16Rung`, `profR13Rung`,
     `profR13Shield`). On the two rungs they agree with real receipts (82 checks, MEASURED).
   - The reader is written out and PROVED correct: from the verifier's own transcript it recomputes the verifier's
     whole working state, for any block shape (`tAccRd_trace`).
   - The claim counts follow from one table per profile: how many of each slot's private tables sit in each
     commitment (`hcnt_of_defCm`).
2. **The app's block shape has its own statement.** L28's R13 statement was written for the test rung's schedule. The
   same proof is now carried out at the Shieldstral T128 schedule (`block_knowledge_open_r13_shield`). The block uses
   `30,353,054` of the `67,108,864` budget units the target allows (PROVED).
3. **Half of list B's first item: the masks.** Each slot's polynomial is "tables part + c × mask part". The mask part
   is now built from the committed mask table and PROVED to have every property the block statement needs: its
   degree, its value at the verifier's point, and its sum over the cube. The fact that the mask commitment's test
   reads its inputs linearly, which L23 assumed, is PROVED (`msXof_mlin`).
4. **The final statements.** `block_knowledge_final_w16r2`, `block_knowledge_final_r13` and
   `block_knowledge_final_r13_shield` are the block statement at the three profiles with everything above
   discharged. §4 lists every premise they still take.

**One finding needs your attention (L31-1, High for the Lean chain, not a protocol weakness).** A premise that every
block theorem since lane L16 carries (`hEval`, the "evaluation interface") was written too strongly. It asks for an
identity at challenge lists of ANY length, while the verifier only ever produces one list of the right length. As
written, no polynomial can meet it at a real block, so those theorems said nothing about a real block. The repair is
small: state the premise at the verifier's own challenges. This lane states the repaired premise (`SlotEvalN`) and
re-proves the chain of block theorems for it in new files, so the final statements above are NOT affected. The
coordinator should decide whether to repair L16's definition in place (two small edits, §5) or to cite this lane's
chain.

**What is not done** (§6). The tables part of the slot polynomials: the block's 23 slot definitions written as one Lean
`define` with the layout of the committed planes, and the algebra on top of it (that a failing equation is caught by
the random challenges, the lookup bridge). These are the rest of list B. They are the largest part of the original
brief and remain for the next lane.

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 `BlockInstRead.lean`: the reader (`hRd`) and the claim counts (`hcnt`), any block shape

| Theorem / definition | Statement |
|---|---|
| `decAll`, `decAll_toBytes`, `decAll_rounds` | an absorbed vector's bytes decode to the vector (canonical words) |
| `tRounds`, `tRounds_trace`, `SlotRead`, `slotReadOf`, `tSlotFull`, `tSlotFull_trace` | one whole slot read off its own trace: `define`'s draws, `c`, the scalar, each round's message and challenge, the terminals |
| `accStepCore`, `accStep`, **`slotStep_read`** | an accepting slot's accumulator is a function of what its trace shows; the acceptance fixes the number of rounds |
| `tAccLoop`, **`slotsLoop_read`** | the slot loop |
| `tAccRd`, **`tAccRd_trace`**, **`accRd_slotTrace`** | **`hRd`**: on the verifier's own accepting trace the reader returns the verifier's WHOLE accumulator (so `acc.fs ++ acc.hostFs`, `acc.claims.a`, `acc.claims.h`), for every `BlockParams` with slot degrees at least `1` |
| `cmCount`, `push_get_length`, `slotClaims_length`, `sumFrom`, `slotsLoop_claims`, `blockSlots_claims`, **`hcnt_of_define`** | **`hcnt`**: when every definition of slot `k` has a fixed number of private tables in a commitment, the accumulator's claim list for it has the schedule's length |

The reader needs no fact about the header's squeeze count. It reads the header's length only.

### 2.2 `BlockInstProf.lean`: the profiles

| Theorem / definition | Statement |
|---|---|
| `shapeLenW`, `shapeSqW`, `shapeLen_eq`, `shapeSq_eq`, `w16r2_rung_counts`, `r13_rung_counts`, `r13_shield_counts` | the slot phase's operation and squeeze counts from the draws and the schedule |
| `mkProf`, **`profW16Rung`**, **`profR13Rung`**, **`profR13Shield`**, `ProfNums`, `prof_nums` | the concrete `OProf` of each profile, from the run's header numbers (`hdrLen ≤ 2^19`, `hdrSq ≤ 2^63`), with the four size bounds proved |
| `DefCm`, `aCntW16Rung` … `hCntR13Shield`, `cnt_sums`, `cnt_terms`, **`hcnt_of_defCm`** | `define`'s commitment schedule (the `A` and `H` tables per slot), its totals, its agreement with the terminal counts at every slot, and `hcnt` from it |
| `IsRungW16`, `IsRungR13`, `IsShieldR13` | what makes a `BlockParams` a block verifier of the profile: the schedule, 36 and 9 groups, 34 functionals, the opening fields `maskField`, `pcsField` / `pcsFieldR13` with the profile's rows |
| `csXof`, `msXof`, `csRungW16`, `csRungR13`, `csShieldR13`, `msRung` | the reading definitions: `hcsA`, `hcsH`, `hms` hold by definition; the endpoint commitments' semantics `csE` is a parameter of the run |

### 2.3 `BlockInstRung.lean`, `BlockInstShield.lean`: L28's statements with list A discharged

| Theorem | Statement |
|---|---|
| **`block_knowledge_rung_w16r2`**, **`block_knowledge_rung_r13`** | L28's `block_knowledge_open_w16r2` / `_r13` with the profile, the fields, `hcnt`, `hRd`, `hcsA`, `hcsH`, `hms`, `hrows`, `hk`, `hkF` discharged |
| `shield_defLen_r13`, `shield_draws_sum_r13`, `shield_defND_le_r13`, `shield_blockND_r13`, `shield_budget_r13`, `shield_budget_r13_val` | the Shieldstral T128 R13 schedule's numbers: `defLen = hdrLen + 1,293`, 451 draws, `Σ (n + e)·d = 1,159`, the budget `30,353,054 ≤ 2^25` |
| **`block_knowledge_open_r13_shield`** | L28's R13 statement at the Shieldstral T128 schedule (L28's proof with the schedule's facts replaced) |
| **`block_knowledge_shield_r13`** | the same with list A discharged |

These three "rung / shield" statements still carry L16's `SlotEval` (finding L31-1). The statements to cite are §2.6's.

### 2.4 `SlotPolyInstMask.lean`: the mask half of the slot polynomials

| Theorem / definition | Statement |
|---|---|
| `mRowX`, `mrow_term`, **`msOfTab_mlin`**, **`msXof_mlin`** | the extracted mask rows; `M`'s semantics reads a functional linearly on them (L23's `MLin`, the premise `hlin` of `unmask_slots`) |
| `mdot_eq_dot`, `exists_words`, `maskA`, `coeffsK_words`, `mdot_evalWeights`, `mdot_sumWeights` | a term's dot with a row is the code's `dot` with words reading the row; L5's `toK_evalDot` and `toK_total` on the extracted row |
| `maskPoly`, `maskPoly_succ`, `indDeg_prod`, **`maskPoly_indDeg`** | the CFS mask polynomial of a slot's row, of individual degree `≤ d` |
| **`maskPoly_point`** | the row's dot with `eval_weights(ρ, d)` is the mask polynomial at `ρ`: the value of the slot's `M` functional |
| **`maskPoly_cubeSum`** | the row's dot with `sum_weights(N, d)` is the mask polynomial's cube sum: what a `Γ` functional weighs |

### 2.5 `SlotPolyInstEval.lean`: the corrected interface and `Poly + c·mask`

| Theorem / definition | Statement |
|---|---|
| `SlotEvalN`, `SlotEval.toN` | the evaluation interface with the run's facts (finding L31-1); L16's form implies it |
| `slotEval_rhs_indep` | what L16's `SlotEval` forces: its right side is the same for any two readings of a slot with the same trace data and the same first `n + e` challenges, whatever `rhoFull` holds beyond them |
| **`blockSlots_terminalN`** | L16's `blockSlots_terminal` for `SlotEvalN`: on an accepting slot phase whose claims and `M` functionals are true, every slot's terminal check `fin = f(ρ)` holds |
| `seenOf_c`, `maskedF` | the masked slot polynomial `Poly + c·mask`, `c` the slot's CFS challenge as the trace shows it |
| **`maskedF_indDeg`**, `maskedF_indDeg_all` | `hdeg`, from the tables part's degree |
| **`maskedF_slotEvalN`** | it meets `SlotEvalN` for any `M` semantics linear on the rows, when the tables part meets `SlotEvalN` with the zero `M` semantics (`Poly(ρ) = poly(vals)`) |
| **`maskedF_cubeSum`**, `claimed_unmasked` | its cube sum is `Σ Poly + c·⟨row, sum_weights⟩`: the premise `hcl` of `unmask_slots` |
| `hpolyC_of_ir` | `hpolyC` for any `define` whose polynomials are IR evaluations |

### 2.6 `BlockInstChainN.lean`, `BlockInstFinal.lean`: the chain for `SlotEvalN`, and the final statements

| Theorem | Statement |
|---|---|
| `blockWinT_blockWinN`, `block_terminal_knowledge_posN`, `block_knowledge_acc_RN`, **`block_knowledge_target_RN`** | L16's, L20's and L28's block theorems with `hEval : SlotEvalN`, each proof unchanged |
| `block_knowledge_open_w16r2N`, `block_knowledge_open_r13N`, `block_knowledge_open_r13_shieldN` | L28's block statements (and §2.3's Shieldstral one) with `hEval : SlotEvalN` |
| `maskedFX`, `w16r2_rung_mask_facts`, `r13_rung_mask_facts`, `r13_shield_mask_facts` | `F` over the mask table extracted for the statement's `M` root; every slot has a degree in `[1, 5]`, at least one variable, and at most 112 mask coefficients (a mask row holds 512) |
| **`block_knowledge_final_w16r2`**, **`block_knowledge_final_r13`**, **`block_knowledge_final_r13_shield`** | for EVERY `q`: `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`, with list A, the corrected interface and the mask half discharged |

## 3. The numbers

| | W16R2 rung | R13 rung | Shieldstral T128 R13 (the app's block) |
|---|---|---|---|
| source | L9's corpus (MEASURED) | L17's block corpus (MEASURED) | L17's shape corpus (MEASURED counts; claim counts ESTIMATE) |
| mask specs `S`, functionals | 23, 34 | 23, 34 | 23, 34 |
| `A` rows, groups, claims `nA` | 320, 36, 114 | 437, 36, 148 | 4,577, 36, 146 |
| `H` rows, groups, claims `nH` (with the LogUp sum claim) | 202, 9, 47 | 248, 9, 55 | 4,390, 9, 54 |
| opened columns `Q`, index squeezes `mI` | 280, 70 | 256, 64 | 256, 64 |
| slot phase: draws, rounds, operations, squeezes | 351, 296, 1,035, 670 | 375, 296, 1,059, 694 | 451, 370, 1,283, 844 |
| chain items of the whole run (`OProf.hlen`, limit `2^20`) | `hdrLen + 2,030` | `hdrLen + 2,247` | `hdrLen + 10,750` |
| squeezes of the whole run (`OProf.hsq`) | `hdrSq + 1,609` | `hdrSq + 1,826` | `hdrSq + 10,255` |
| the receipt's end counter (header counter 0) | 1,609 (MEASURED, equal) | 1,826 (MEASURED, equal) | no receipt in the repository |
| block budget (limit `2^26 = 67,108,864`) | 30,263,665 (L28) | 30,322,419 (L28) | **30,353,054** (PROVED, `shield_budget_r13_val`) |
| largest slot: variables, degree, mask coefficients | 16, 5, 82 | 16, 5, 82 | 22, 5, 112 |

The `A` / `H` tables per slot (`aCnt…`, `hCnt…`), slots 0 to 22:

| profile | `A` | `H` |
|---|---|---|
| W16R2 rung | 1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 21, 7, 7, 12, 9, 17, 0, 1, 1 | 0, 0, 0, 1, 0×10, 10, 3, 3, 6, 5, 17, 1, 0, 0 |
| R13 rung | 1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 41, 15, 15, 17, 16, 3, 0, 1, 1 | 0, 0, 0, 1, 0×10, 17, 7, 7, 10, 8, 3, 1, 0, 0 |
| Shieldstral T128 R13 | 1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 41, 15, 15, 15, 16, 3, 0, 1, 1 | 0, 0, 0, 1, 0×10, 17, 7, 7, 9, 8, 3, 1, 0, 0 |

How these were obtained. The totals `nA`, `nH` are the sums of the receipts' group member counts (MEASURED). The `H`
schedule is the shape's helper counts (`Dom::L`, `D`, `Q`, `Kv`, `S + 1`, `F + 1`, `3 + n_range` at `SC_TAB`, `1` at
`SC_ZS`); on both rungs it equals the receipt's `H` group counts one by one (MEASURED: a slot's `H` claims share its
point, so they form one group). The `A` schedule is the terminal count minus the `H` tables and the one endpoint table
of `SC_IO_IN` / `SC_IO_OUT`; it is checked by its total and by `cnt_terms` (PROVED: it accounts for every terminal),
not group by group. For the Shieldstral block the same rule is applied to the shape corpus; there is no receipt of
that block in the repository (ESTIMATE, L31-3).

## 4. The premises that are left, by name

`block_knowledge_final_w16r2`, `_r13`, `_r13_shield` take, besides `U`, `hU`, `hK2`, the transcript's `key`, `domain`,
`hs`, `hL`, `hL64`, `hL20` and the prover `A`, `hA`:

| Premise | What it is | Kind |
|---|---|---|
| `hP : IsRungW16 / IsRungR13 / IsShieldR13 P tag rowsOf` | `P` is a block verifier of the profile: schedule, group counts, functional count, opening fields | the profile's definition |
| `aC`, `hC`, `hdc : DefCm P aC hC`, `hsA`, `hsH` | `define`'s commitment schedule: SOME per-slot split of the `A` and `H` tables whose totals are the profile's claim counts (114 / 47, 148 / 55, 146 / 54) | HYPOTHESIS on `define` (follows from the concrete `define`; §3's lists with `cnt_sums` are the splits the layouts give) |
| `hpolyC` | `define`'s polynomials return canonical words | HYPOTHESIS on `define` (`hpolyC_of_ir` for an IR-defined one) |
| `Poly`, `hPoly`, `hdegP` | the tables part of the slot polynomials: at an accepting slot whose claims are true `Poly(ρ) = poly(vals)`; its individual degree is the slot's | HYPOTHESIS (L23 §5 item 2, the part LEFT) |
| `hh`, `hq` | the run's header: at most `2^19` operations, at most `2^63` squeezes | run level |
| `csE`, `εend`, `hEnd` | the endpoint commitments' semantics and the endpoint claims' term (L22-5) | run level |
| `Pb`, `Lay`, `B`, `h24`; `fams`, `hF`, `hW` (W16R2); `hW13` (R13) | the block's public statement, layout and tables; LowH24; the range families / the shifts' limb windows | public data |
| `xtE`; `spR`, `hdgR`, `hvR`, `hgdR`; `HGd`, `spH`, `hdgH`, `hvH`, `hgdH` | the extracted planes; the certified slot polynomials and the per-outcome algebra | HYPOTHESIS (L23 §5 items 3, 4, LEFT) |
| `Alk`, `T`, `mlk`, `hN`, `he`, `hbr`, `hhr` | the lookup list, the table, the multiplicities, and the lookup bridge | HYPOTHESIS (L23 §5 item 3, LEFT) |

Gone, against L28's statements: `pr`, `hm70` / `hm64`, `hPm`, `hPp`, `hrA`, `hrH` (inside `hP`), `hrows`, `hk`, `hkF`,
`hcnt`, `accRd`, `hRd`, `hcsA`, `hcsH`, `hms`, and `F`, `hEval`, `hdeg` (replaced by `Poly`, `hPoly`, `hdegP`).

## 5. Findings

No statement of `Statements.lean` changed. No target weakened.

**L31-1 (High for the Lean chain; for the coordinator. Not a protocol weakness): `SlotEval` cannot be met at a real
block.**
- L16's `SlotEval` (`ExtractW16Terminal.lean:244`) is the premise `hEval` of every block theorem from L16's
  `block_knowledge` to L28's `block_knowledge_open_*`. It asks
  `f(ρ) = poly(vals) + c·ms[(k, eval_weights(rhoFull, d))]` for EVERY list `rhoFull` with `r.rho = rhoFull.take n`
  and `r.es = rhoFull.drop n`. Nothing bounds `rhoFull`'s length.
- The polynomial `f` sees only the first `n + e` entries. The right side reads all of `rhoFull`. PROVED
  (`slotEval_rhs_indep`): `SlotEval` forces the right side to be the same for any two readings that agree on what
  `f` sees. ARGUED (that a real block breaks this): take an
  accepting slot's `rhoFull` and append one zero word. Then `∏(1 − e_i)` and the mask coefficients are unchanged, so
  `vals` and the claims are unchanged, and `f`'s input is unchanged. But `eval_weights`' second entry, the product of
  all challenges, becomes `0`. So `SlotEval` would force `c · (mask row entry 1) · ∏ρ = 0` at every such slot. That
  entry is the CFS mask's product coefficient, which the prover chooses. So `hEval` is false whenever the extracted
  mask table has a nonzero such entry, and the theorems that assume it hold vacuously there.
- Where it enters: only in `blockSlots_terminal` (`ExtractW16Terminal.lean:260`), which applies `hEval` at the
  verifier's own `rhoFull`. Every theorem above passes `hEval` down unchanged.
- What the verifier's acceptance gives: `rhoFull` is the sumcheck's challenges, exactly `n + e` canonical words; the
  slot is one of the shape's; the slot proof is canonical.
- The repair, done here in new files: `SlotEvalN` is `SlotEval` with those facts as premises; `blockSlots_terminalN`
  proves the terminal theorem for it; `BlockInstChainN.lean` re-proves the chain above it (each proof is the existing
  one, generated by `l31_mk_chain.py`). The final statements of this lane use `SlotEvalN`.
- The decision for the coordinator: (a) repair in place: replace `SlotEval`'s body by `SlotEvalN`'s, give
  `blockSlots_terminal` the premises `hcan`, `hsh`, `hd` and the proof of `blockSlots_terminalN`, and pass them at
  its one call site (`blockWinT_blockWin`, `ExtractW16Block.lean:116`, which has `CoreCanon`, `CoreShape` and `hgeom`
  in scope). Nothing else unfolds `SlotEval`. Or (b) leave L16's files and cite this lane's `…N` chain. Lanes L30,
  L32, L33 and L27 should cite a block statement with `SlotEvalN`.

**L31-2 (Low; for the coordinator and the app lane): the R13 block statement existed only at the rung's schedule.**
L28's `block_knowledge_open_r13` fixes `R13.rungDraws`, `rungSlots`, `rungTerms`. The media app's classifier blocks run
`R13.shieldSlots` (451 draws, 370 rounds). `block_knowledge_open_r13_shield` is the statement at that schedule. Its
budget is `30,353,054` units, `30,635` above the rung's.

**L31-3 (Low; for the next lane): `hcnt` is reduced to `define`'s commitment schedule, and the schedule is checked
only in part.** `DefCm` is a HYPOTHESIS on `define` until the concrete `define` exists. The statements take ANY
per-slot split with the profile's totals, so a wrong per-slot entry in §3's lists cannot make them vacuous; only the
totals matter. The `H` schedule and both
totals are MEASURED on the two rungs. The per-slot `A` split is derived (terminals minus `H` minus endpoints). The
Shieldstral numbers (`nA = 146`, `nH = 54`) are an ESTIMATE by the same rule from the shape corpus; a real Shieldstral
R13 block receipt would settle them (the real export is not in the repository, D62).

**L31-4 (Info): the reader returns the whole accumulator and needs no squeeze count.** L28's `hRd` asks three lists
under the header's squeeze count. `tAccRd_trace` gives the whole `Acc` on any accepting slot phase. So `hRd` is not a
property of a profile.

**L31-5 (Info): the profiles' end counters are the receipts'.** `OProf.hsq`'s expression, evaluated at the profile's
numbers with the receipt's start counter, is the receipt's end counter: 1,609 at the W16R2 rung, 1,826 at the R13
rung (MEASURED). The same expression gives the counter at `M`'s window: 673 and 697 (MEASURED).

**L31-6 (Info): the endpoint semantics must be multilinear for the tables part.** At `SC_IO_IN` / `SC_IO_OUT` the
tables part `Poly` reads an endpoint table through `csE`. Its degree bound `hdegP` needs `csE` to be the claim
functional of the endpoint commitment's decoded rows (as `csXof` is for `A` and `H`). A note for the run-level lanes.

**L31-7 (Info, method).** Lean 4.34 deprecates `if_pos` / `if_neg` / `dif_pos` / `dif_neg` (`ite_eq_left`, …); here
`Finset.range_subset` is `range n ⊆ s ↔ …`, not the monotonicity of `range`. The agreement checkers all define a
root-level `main`; the name-clash scan must leave that name out.

## 6. What is left

In the brief's order:
1. **Part A.** Done, up to `DefCm` (L31-3), which is a property of the concrete `define`.
2. **Part B item 2, the tables part.** LEFT. What exists now: the mask half, `hpolyC_of_ir`, and the exact interface
   the tables part must meet (`hPoly : SlotEvalN U P cs (fun _ => 0) Poly`, `hdegP`). What the next lane needs:
   - the W16R2 `define` as a Lean `BlockParams.define`: L13's IR builders (today driven by the checker
     `SlotW16BuildCheck.build`) as a library definition, plus each private table's `Priv` (its commitment, plane
     slices, coordinates, mask row and extension round: the plane allocation), the `eq` tables' points (L11's
     `eqPoints`) and the public tables (the folded weights, RoPE, gains, gates);
   - `Poly` as `irEval` of the IR over the tables' extensions: `sel·eq`, `sel·mle(pub)`, and for a private table the
     claim functional of `build_claim`, `cd·plane~(ρ) + cm·(R_re + u·R_im)(tail)`. That last needs `claimSem` of
     `buildClaim` unfolded through L10's `zpartWeights` / `zkeyWeights`;
   - the degree of each slot's IR in the tables (at most the slot's `d`), by naturality (`*_map`) on the shape alone;
   - then R13 through L17's reduction (R13's `SC_TAB` has no transcribed IR, L17-9).
3. **Part B items 3 and 4.** LEFT, unchanged from L23 §5: `hvR`, `hvH` (with `unmask_slots`, whose premises `hlin`
   and `hcl` are now `msXof_mlin` and `claimed_unmasked`), `hgdR`, `hgdH`, `hbr`, `hhr`, `spR`, `spH`, `hdgR`, `hdgH`.
4. **The final theorem.** Done in the form of §4; it shrinks as items 2 and 3 land.
5. **L31-1's decision**, and a real Shieldstral T128 R13 block receipt for L31-3.

## 7. Checks

All in `results/zk60_lean_l31_20261109/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB).

- `iter1.log` (job `lean-l31-iter1`, 35 s, peak RSS 3.84 GiB, admitted after 4 minutes): the four part A modules,
  green at the first build; one linter warning (an unused `simp` argument), removed.
- `iter2.log` (109 s, admitted after 25 minutes): part A's full check, green except the name-clash scan, which counted
  every checker's root-level `main` (L31-7; the scan now leaves `main` out); part B's first build stopped at
  `SlotPolyInstMask.lean` (a wrong lemma name, `Finset.range_subset`, and four deprecated names).
- `iter3.log` (17 s, admitted after 17 minutes): the four part B modules, green, no warning.
- **`check.log`** (`check_l31.sh`, job `lean-l31-check`, `iter4.log`; exit 0, 85 s, peak RSS 6.69 GiB, admitted after
  25 minutes behind the app lane's GPU job):
  - the eight L31 modules built one target at a time, then the full build (`full.log`): **3,599 jobs, rc 0,
    0 warnings, 0 errors, no `sorry`**;
  - the axiom audit (`axioms_l31.lean`, written by `gen_axioms.py`: every `theorem`, `def`, `abbrev` and `structure`
    of the eight files; `axioms.log`): **115 declarations (71 theorems, 34 definitions, 5 abbreviations,
    5 structures)**; 62 on `[propext, Classical.choice, Quot.sound]`, 18 on `[propext, Quot.sound]`, 14 on `[propext]`,
    21 on none; no `sorryAx`, no `ofReduceBool`, no other axiom;
  - the source scan of the eight library files and `BlockInstCheck.lean` for the forbidden words: none;
  - the library root imports the eight files and not the checker; `Statements.lean` unchanged; no existing file under
    `formal/` modified, deleted or renamed; no file under `ops/` changed;
  - the name-clash scan against the Lean files of all 39 worktrees (`l31_nameclash.py`, `nameclash.log`): 0 clashes;
  - **`BlockInstCheck`** on L9's corpus, L17's block corpus and L17's shape corpus (`blockinstcheck.log`):
    **82 checks, 0 failed**. Per rung receipt (2 each): rows, groups, mask specs, functionals, `Q` and `⌈Q/4⌉`, the
    claims of `A` and of `H` (the sums of the group member counts) and the group counts, `H`'s groups against the `H`
    schedule, the slot count, the schedule, the draws, the counter at `M`'s window, the end counter; 23 terminal counts
    each. Per shape (R13 rung, Shieldstral T128 R13; 2 each): the counts, the schedule, the terminal counts, the `H`
    schedule from the helper counts, the `H` plane count;
  - its negative control (`l31_mutate.py`: eight single changes, to `a_rows`, one `A` group count, two `H` groups
    swapped, the end counter, one terminal count, `mask_specs`, the last slot's counter, the Shieldstral shape's
    `Dom::S` helper count; copies written outside the repository; `negative_control.log`): **exactly 8 failed**, one
    per change;
  - regressions: `L6Check` 1,206, `L5Check` 5,553, `L11Check` 404, the fixture L1 check 101,956; 0 failed.
- The generated files (`BlockInstRung.lean`, `BlockInstShield.lean`, `BlockInstChainN.lean`, `BlockInstFinal.lean`)
  are byte for byte the output of `l31_mk_rung.py`, `l31_mk_shield.py`, `l31_mk_chain.py` on this tree (the files the
  final check built, hashed in `l31_generated.sha256`; the generators re-run afterwards reproduce all four hashes).
- Not run by this lane: `ExecBlockCheck`, `CheckR13Block`, `CoverW16MCheck` (no file they read was changed), and the
  merged-tree check on perf, which is the coordinator's.
