# ZK60 Lean lane L53: the stage parts' sub-protocol lists, chosen once to match the code, and their alive premises (2026-11-10)

Lane L53 of D63 (Claude Opus 5.5), on its own worktree holding perf `912441c0` (lanes L50 and L51 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Evidence: `results/zk60_lean_l53_20261110/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (a script or Lean checker this lane ran against the code, with its log and a negative control),
**MEASURED**, **ARGUED** (reading the code or the Lean, not a theorem), **ESTIMATE**, **LEFT** (not done).

**STATUS.** Deliverable 1 DONE, green, committed: the stage parts' lists, CHECKED against a real classifier receipt
(108 checks, 0 failed; 21 single changes, each caught). Deliverable 2 DONE in L50's sense: the six stage alive
premises are PROVED from stage-level facts at each stage's reading of the run (as L50 did for the blocks); three of the
six (`hR1_stg`, `hH0_stg`, `hH1_stg`) are gone outright. Deliverable 4 DONE: the top theorem restated
(`stg_productionReadyL_epP_exec_lists`, generated). Deliverable 3 (`hdin`, `hdout`) NOT started in Lean; §5.3 gives the
route, which the lists now make possible.

## 1. In plain words, for Victor

**The question.** The app's top theorem splits the classify run into 28 parts: stage IN-C, the 26 blocks, stage OUT-C.
For each part it lists the part's checks of four kinds: sumcheck slots, "define" draws (the random points a zero-check
draws), and the lookup check (LogUp). The blocks' lists were fixed by earlier lanes. The two stages' lists were left
free, and lane L50 found (L50-1) that a wrong choice makes the theorem's premises false at the real system: if a
stage's define draw is listed but its slot is not, a cheating prover that passes the slot by luck leaves the draw
"not alive", and nothing earlier in the order catches it.

**The choice (this lane, made once).** Each stage part lists exactly what the code's stage verifier runs:
- every stage slot, in order (IN-C: 4, OUT-C: 8);
- the define draws of every slot that draws, all in the first define kind (IN-C: slots 0, 1, 2; OUT-C: slots 0, 2, 4,
  5, 6);
- the stage's head challenges as its one LogUp run (IN-C: `β, γ, α` and the embedding point `r_emb`; OUT-C: `γ, α`);
- nothing in the other three define kinds.
Why one define kind suffices: every stage define draw ends well as soon as its own slot (and the slots it hosts) started
from a true claim and the mask `M` is honest, and both are checked earlier in the order. LogUp comes last, after the
zero-checks it relies on.

**Checked against the code.** A Lean checker replays the stage operations of a real classifier receipt (lane L29's)
under BLAKE3 and confirms, for every entry of both lists, that its position on the transcript is where the code draws
or sums (the transcript state matches the code's at every slot boundary), that the counts and degrees are the code's,
and that the claimed sums the lists read are the ones the code's sumcheck used. Ten deliberate errors in the lists and
eleven in the receipt or the sources are each caught.

**What this buys.** In the top theorem, the six stage "alive" premises are replaced: three disappear (those kinds list
nothing at the stages), and three become plain facts about each stage's own algebra at its reading of the run (the same
form L50 left for the blocks). The run plumbing in between (the run's transcript at a stage IS the stage's verifier
trace and more) is proved.

**What is not done.** The two doom covers `hdin`, `hdout` (deliverable 3): the lists now contain everything the covers
need, and §5.3 gives the route, but no Lean was written for it.

## 2. What is proved

All in namespace `ZK60.ProtocolClassify` (the top theorem in `ZK60.ProtocolClassify.RunShapeP`). Every declaration on at
most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 Deliverable 1: the lists (`RunStgList.lean`)

| Theorem or object | Meaning |
|---|---|
| `stgS`, `stgN`, `stgLen`, `stgDefPos`, `stgDrawing` | the numbers: slot `k`'s interstitial count (before slot 0: the header, the head's `7 + m` operations, `draws + 3`), its rounds, the operations before it, its define window, the slots that draw |
| **`stg_len_win`** | slot `k`'s window is its define window plus `draws k + 3` |
| **`stg_ops_slot`**, **`stg_ops_head`** | on the stage's operations (`frame ++ stageRootOps ++ fullOps`, what the run's transcript at the stage is the trace of), the define window is the first of slot `k`'s draws (then `pb-slot k`, `c`, `pb-scalar`, its rounds, `pb-term`), the LogUp window the first head challenge |
| `stgCuts` | the cuts a header shows: at each position, the log cut at what is absorbed there |
| `stgClaim` | a stage slot's claimed sum from the trace, with the stage's hosting as data (`hostOf`) |
| **`stgSlotX`**, **`stgSchedX`** | the stage's slots as kinds-data slots: window, degree, rounds, statement (polynomial `F` over the cuts, claim `stgClaim`) |
| `tHistS`, **`stgDefSq`**, **`stgDefs`** | the define draws as squeeze runs (Schwartz–Zippel state on `Φ` over the cuts, at what `define` saw) |
| **`stgLkSq`** | the head as the LogUp squeeze run (state `Λ` over the cuts) |
| `stgSlotX_cut`, `stgDefSq_cut`, `stgLkSq_cut`, **`stgDefSq_rbr`** | the lists' side conditions of `hD` that do not depend on the polynomials: cut readers; define draws round-by-round sound from their degree |
| `stgSchedX_get`, **`stg_win`** | the list's slot `k` and its window (`slotsLenX` form) = define window + `draws k + 3` |
| **`StgLists`**, `stgPart`, `stgPart_lists` | THE CHOICE: a part's `sls`, `r0`, `r1 = []`, `h0 = []`, `h1 = []`, `lu = [head]` |
| `stg_rxPs_0`, `stg_rxPs_out` | the kinds data's parts `0` and `Lb + 1` carry `base 0`'s and `base (Lb + 1)`'s lists |

`RunStgCheck.lean` (executable, not imported): the CHECK (§7).

### 2.2 Deliverable 2: the stage half (`RunStgAlive.lean`)

| Theorem | Meaning |
|---|---|
| `StgSame`, `stg_tSeenS`, `stg_tHistS`, `stg_stgDefPos`, … | the lists read the schedule only through its draws and slot shapes (IN-C's schedule depends on the head's challenges through `define` alone) |
| `stgClaim_seenOfS` | on the verifier's records the list's claim is the claim the slot loop used, when `define`'s hosting is the lists' |
| **`stg_slotsAcc`** | an accepted stage slot phase with the terminal identities meets L50's `RaSlotsAcc` for the lists' slots (L15's `stageWin_slotsWin` at the lists' statements) |
| **`stg_slots_alive`** | the lists' slots are alive at the end of the stage's trace and any extension |
| `stg_def_window`, `stg_tHistS_trace` | L21's `def_window`, `tHistD_trace` with the stage's head |
| **`stg_def_alive`** | a list define draw is alive at the end, when its polynomial vanishes at the drawn challenges |
| **`stg_lk_alive`** | the list LogUp run is alive at the end, when its state holds at the head's challenges |

### 2.3 Deliverable 2: the run half (`RunStgRun.lean`, `RunStgHal.lean`)

| Theorem or object | Meaning |
|---|---|
| `stg_inc_stageSlots` | IN-C's slot phase is L15's `stageSlots` at the schedule of its head's challenges (L29's `incSlots_model`) |
| `stg_root_congr`, `stg_incBp_*` | IN-C's head and slot operations do not read the context |
| **`StgRd`** | a reading of a stage on a transcript: header, core, the stage's slot phase accepted after it, the transcript its trace and more |
| **`stg_inc_rd`**, **`stg_outc_rd`** | THE RUN'S TRANSCRIPT AT STAGE IN-C (part `i`, header `off i + 5`) AND AT STAGE OUT-C (header `off i + 2`) IS A READING OF THE STAGE (L50's `ra_blk_acc` for the stages) |
| **`StgTermAt`**, **`StgDefAt`**, **`StgLkAt`** | the stage-level facts at every reading (L50's `RaTermAt`, `RaDefAt`, `RaLkAt` for a stage) |
| `stg_sl_rd`, `stg_def_rd`, `stg_lk_rd` | at a reading, the lists' sub-protocols are alive at the end of the transcript, from those facts |
| `stg_rds` | the classify run's two stage readings (parts `0` and `Lb + 1`) |
| `stg_D_lists` | the kinds data's stage parts carry `StgLists`' lists |
| **`stg_hal_sl`**, **`stg_hal_r0`**, **`stg_hal_lu`** | `hsl_stg`'s, `hR0_stg`'s, `hLU_stg`'s conclusions, from the stage-level facts |
| **`stg_hal_nil`** | `hR1_stg`'s, `hH0_stg`'s, `hH1_stg`'s conclusions, outright |

### 2.4 Deliverable 4: the top theorem (`RunStgTop.lean`, generated)

| Theorem | Meaning |
|---|---|
| **`stg_productionReadyL_epP_exec_lists`** | L50's `ra_productionReadyL_epP_exec_alive` with the stage lists fixed (`hb0`, `hbL`) and `hsl_stg`, `hR0_stg`, `hLU_stg` replaced by the stages' stage-level facts under the SAME hypotheses; `hR1_stg`, `hH0_stg`, `hH1_stg` gone. Generated by `l53_mk_top.py` |

## 3. The numbers

On the development rung (lane L29's receipt, `private-classify-run-rung-tc-t32-public-row-dev/2`, `L = 1`), positions
relative to the stage part's start (absolute: add `off 0 = 8` for IN-C, `off (L + 1)` for OUT-C). All MEASURED by the
checker on the receipt (and equal to the Lean lists' numbers there, CHECKED).

| Figure | IN-C | OUT-C |
|---|---|---|
| slots (degree, rounds) | 4: (3, 9), (4, 13), (4, 13), (2, 13) | 8: (2, 10), (4, 13), (3, 2), (2, 10), (4, 13), (5, 13), (3, 13), (2, 13) |
| slots that draw (draws) | 0 (8), 1 (17), 2 (15) | 0 (9), 2 (7), 4 (15), 5 (23), 6 (15) |
| head challenges `m` (LogUp run) | 12 = 3 + clog2 512, window 9 | 2, window 6 |
| define windows | 24, 54, 101 | 11, 74, 113, 158, 211 |
| slot windows | 35, 74, 119, 149 | 23, 47, 84, 92, 131, 184, 229, 259 |
| frame (header length of the stage) | 5 | 2 |
| hosting | none | TZC hosts SS with draw 5 (`ν`), LZC hosts PD with draw `llo + 2` |

| Figure | Value | Label |
|---|---|---|
| list entries per stage part | IN-C 4 slots + 3 draws + 1 LogUp; OUT-C 8 + 5 + 1 | CHECKED |
| stage premises of the top theorem | 6 before; 6 stage-level facts after, 3 of the old premises removed outright | PROVED (`stg_productionReadyL_epP_exec_lists`) |
| explicit binders of L50's theorem passed by name | 136 (146 named arguments) | CHECKED (`l53_mk_top.py`) |

## 4. The choice, and why (finding L53-1)

1. **Slots: all of them.** Every stage define draw's end state ("its polynomial vanishes at the drawn point") is its
   slot's start claim; if the slot were not listed, a lucky sumcheck would leave the draw dead with no doomed entrant
   earlier in the order (L50-1). Slots with no draws (IN-C's zero-sum, OUT-C's SS, PD, ZS) carry their relation in the
   slot's own start claim, so they must be listed for the doom cover too.
2. **Define draws: all in `r0`.** The order is `opB, M, opA, slots, r0, r1, h0, h1, LogUp`. A stage define draw ends well
   given its slot's true start claim (`¬ Ksl.Dm`), the hosted slots' true claims (OUT-C's TZC and LZC host SS and PD,
   also `Ksl`) and `M`'s honest functionals (`¬ KM.Dm`). No stage draw needs another draw's relation (the blocks' layered
   relations, L46-2, do), so all can sit in the first define kind. ARGUED from the code's define functions.
3. **LogUp: the head, last.** The head's challenges are drawn before `H` is committed; LogUp ends well when the helpers
   satisfy their relations at the drawn point, which the zero-checks (`r0`) and the zero-sum slot (`Ksl`) give, both
   earlier.
4. **`r1`, `h0`, `h1`: empty**, so their stage premises are discharged outright.

## 5. What is left, premise by premise

### 5.1 The new premises of `stg_productionReadyL_epP_exec_lists`

| Premise | What it says | Met by the real objects? |
|---|---|---|
| `P0in`, `P0out`, `hPin`, `hPout` | the lists' schedules have the stages' draws and slot shapes, for every header (and context, and verdict) | YES for one deployment: the stage layout is a function of the classifier profile (ARGUED); take `P0in := (inc hd₀).bp cx₀`. The numbers CHECKED on the receipt |
| `hostIn`, `hostOut`, `hhIn`, `hhOut` | `define`'s hosted list is the layout's hosting with the drawn coefficient | YES: CHECKED on the receipt (every claimed sum, `CLAIM`) and in the source (`hosts`, the `finish` calls, the `ν` draws); provable from L29's `incDefine` / `outcDefine` (LEFT) |
| `hb0`, `hbL` | THE CHOICE | YES by construction: `stgPart` builds such parts (`stgPart_lists`) |
| `FstI`, `FstO`, `ΦI`, `ΦO`, `dgI`, `dgO`, `ΛI`, `ΛO`, `eI`, `eO` | the stage polynomials and LogUp states | free parameters, as L50's `Fsl`; they must be L12 / L15's stage polynomials over the extracted tables (LEFT) |
| **`hTI_stg`, `hTO_stg`** (`StgTermAt`) | every stage slot's final value is `F` over the extracted tables at its point, at every reading | ARGUED yes, as L50's `hsl_blk`: the verifier's terminal check plus the openings' claims true of the extracted data (A, H, the closing commitment, and for IN-C's `Out` claims block 0's closing opening); the run-level link "no doomed `opB`, `M`" ⇒ claims true is LEFT (L50 §5 item a) |
| **`hDI_stg`, `hDO_stg`** (`StgDefAt`) | every stage define polynomial vanishes at the drawn challenges, at every reading | ARGUED yes with `Φ` := the slot polynomial's cube sum minus its hosted claim: the slot's true start claim (`¬ Ksl.Dm`) and `M`'s true functionals (`¬ KM.Dm`) give it; LEFT in Lean |
| **`hLI_stg`, `hLO_stg`** (`StgLkAt`) | LogUp's state at the head's challenges, at every reading | ARGUED yes once `Λ` is LogUp's "helpers exist" state: the zero-checks and the zero-sum give the helpers; IN-C's `Λ` (the tuple folded at `r_emb`, drawn after `α`) has no Lean model (L53-2) |

Every other binder is L50's (§4 of L50's doc), unchanged, including `hD` (which now asks `RkPart.Ok` of the stage lists:
cut readers PROVED, define round-by-round PROVED from degrees, degrees `≤ 5 ≤ 7` and rounds × degree `≤ 65 ≤ 2,590`
CHECKED, windows inside the part CHECKED (`SPAN`), define degrees `dg = 1` per draw ARGUED, LogUp's count L53-2).

### 5.2 Gone

`hsl_stg`, `hR0_stg`, `hLU_stg` (replaced, above); `hR1_stg`, `hH0_stg`, `hH1_stg` (PROVED outright, `stg_hal_nil`).

### 5.3 Deliverable 3 (`hdin`, `hdout`): not started; the route

`hdin` asks: if IN-C's conclusion `InOkP` fails on the extracted data, some kind has a doomed entrant. With the lists:
at the run's reading of IN-C (`stg_inc_rd`), (a) if a zero-check relation fails, the slot's define polynomial is not
identically zero, so its `stgDefSq` entry's header state is false at its window (`stg_def_window`, `stg_tHistS_trace`),
and L46's `rd_some_sq` gives the doom; (b) if the zero-sum fails, the zero-sum slot's start claim is false: the doom is
in the slot kind (a slot version of `rd_some_sq` through `ra_ksl_cs` and `ra_slot_ent_iff`, not written); (c) if a
lookup fails, the head's `stgLkSq` header state is false. What is missing: the stage algebra "all relations and lookups
⇒ `InOkP`" (L12's `inc_stage_sound`, on L29's `incSlots_model`) as a stage-level cover fact at the reading, and the same
for OUT-C (L15's `outc_stage_sound`). The lists are now fixed, so this is the next lane's work.

### 5.4 Every binder of `stg_productionReadyL_epP_exec_lists`, by name

163 named binders (`l53_binders.py`, CHECKED against the file). Objects and data (no claim of their own): `Rp`, `Lq`,
`Lb`, `preA`, `preB`, `start`, `inc`, `incG`, `Pk`, `sgeom`, `check`, `paths`, `digest`, `bRows`, `bLogN`, `bndCheck`,
`bndOpen`, `outc`, `outcG`, `P`, `U`, `key`, `domain`, `Rn`, `D`, `ι`, `site`, `kOf`, `δOf`, `E`, `εzk`, `O`, `F`, `Cl`,
`T`, `Ux`, `Xx`, `pr`, `tag`, `cx0`, `pin`, `pout`, `Iin`, `Oout`, `bp`, `wXk`, `gXk`, `mXk`, `Win`, `Wout`, `lscIn`,
`lscOut`, `mIn`, `kIn`, `kOut`, `base`, `eL`, `Fsl`, `ιL`, `πL`, `κL`, `AlkL`, `TL`, `mlkL`, `mk`, `ops`, and this lane's
`P0in`, `P0out`, `hostIn`, `hostOut`, `FstI`, `FstO`, `ΦI`, `ΦO`, `dgI`, `dgO`, `eI`, `eO`, `ΛI`, `ΛO`.

Premises: `h64`, `hr`, `hon`, `hbij`, `hs`, `hL`, `hL64`, `hv`, `hD`, `hTenc`, `hTaA`, `hTaB`, `hUc`, `hXc`, `hp1`,
`hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ`, `hU`, `hσ`, `hLb`, `hgeo`, `hIA`, `hIH`, `hOA`, `hOH`, `hBA`, `hBH`,
`htI`, `htO`, `htB`, `hfIA`, `hfIH`, `hfOA`, `hfOH`, `hfBA`, `hfBH`, `hfIM`, `hfOM`, `hfBM`, `hlscIn`, `hlscOut`, `hmIn`,
`hkIn`, `hkOut`, `hDe`, `hW`, `hopX`, `hL81`, `hslB`, `hsl_blk`, `hR0_blk`, `hR1_blk`, `hH0_blk`, `hH1_blk`, `hLU_blk`,
`hdin`, `hblk`, `hdout`, `hE`, `hops`, `hcan`, `hwin`, `hread`, `hBal`, `hdzero`, `hzk` (all L50's, unchanged: L50 §4,
L48 §5, L46 §4, L51 §5), and this lane's `hb0`, `hbL`, `hPin`, `hPout`, `hhIn`, `hhOut`, `hTI_stg`, `hTO_stg`,
`hDI_stg`, `hDO_stg`, `hLI_stg`, `hLO_stg` (§5.1). Gone against L50's theorem: `hsl_stg`, `hR0_stg`, `hR1_stg`,
`hH0_stg`, `hH1_stg`, `hLU_stg`.

## 6. Findings

**L53-1 (Medium; for the coordinator and lane L52): the stage lists are fixed, and the choice is the code's.** §4.
Every stage slot, every stage define draw in `r0`, the head as LogUp, nothing else. L52 (part 0's closing opening, the
endpoint test) and L49 are untouched by it; the combiner must take `base 0`'s and `base (Lb + 1)`'s lists from `hb0`,
`hbL` and their `M`, `A`, `H`, `X` fields from L45 / L48 / L52 (`rxPs` overwrites `M`, `A`, `H`; `gX`, `nX` stay
`base`'s, L52's).

**L53-2 (Medium; for the coordinator): IN-C's LogUp run is `3 + clog2(d_pad)` squeezes.** On the development rung 12
(MEASURED); at the R13 T128 profile not measured. `hD` asks every LogUp run `n · e ≤ 3 · eL` and `e ≤ eL`; with `n = 12`
that needs `e ≤ eL / 4`, which holds only if `eL` is set at least four times IN-C's per-round escape count, or if the
head is split into two runs (`β, γ, α` and `r_emb`), which needs a state for the second. In either case IN-C's LogUp
state `Λ` has no Lean model: its tuple's middle entry is the embedding row folded at `r_emb`, drawn AFTER `α` (finding
L29-3). OUT-C's head (`γ, α`, `n = 2`) is like a block's.

**L53-3 (Low; for L52 and the coordinator): the stage polynomials read the endpoint at the header's position 1.** IN-C's
`SIC_IO` reads the input endpoint's table. The lists give `F` the cut at EVERY header position (`stgCuts`), so it can
read the cut at the 84-byte `expected-IO` absorb (L51-1, repair B: L51's `colXM` reader) or at position 2 (repair A)
without changing the lists.

**L53-4 (Info; Lean method): never `rfl` between two `IncV.bp` contexts.** Comparing `stageRootOps (V.bp cx)` with
`stageRootOps (V.bp cx')` by `rfl` makes Lean compare the two `stageBP` structures field by field and unfold
`incDefine` / `incCtx` (the τ table): recursion limit and `whnf` timeout (iter6, iter7). Going through the three fields
the head reads (`stg_incBp_aRows`, `stg_incBp_hRows`, `stg_incBp_logCols`, `stg_root_congr`) compiles at once.

**L53-5 (Info): negative controls must hit the verifier's copy.** The prover and the verifier share code text (OUT-C's
`γ, α` draws appear in both); the first source mutation hit the prover's and was not caught (case 11, `neg1.log`), as
L51's case 18; retargeted, it is caught.

## 7. Checks

`results/zk60_lean_l53_20261110/check_l53.sh`, one guarded cpu job (`lean-l53-check`, need 24 GiB, cap 36 GiB,
`LEAN_NUM_THREADS=4`). The run of record is `check2.log` (all five modules): exit 0, 173 s, peak 3.74 GiB (the guard's
record). `check1.log` is deliverable 1's (one module), green too: exit 0, 210 s, peak 3.75 GiB. All figures MEASURED. Modules built first in guarded iterations (`iter1` … `iter8`, logs
kept; iter2–4 the checker's syntax and a vacuous negative, iter5–7 the D2 files: L53-4).

| Check | Result |
|---|---|
| each L53 module built alone (five) | 5 of 5 green, 0 warnings |
| full `lake build` | green, 3,756 jobs, 0 warnings, 0 errors, no `sorry` |
| axiom audit (`gen_axioms.py`) of every declaration of the five files | 69 of 69 (49 theorems, 19 definitions, 1 structure): 22 on `propext`, `Classical.choice`, `Quot.sound`; 28 on `propext`, `Quot.sound`; 12 on `propext`; 7 on none; `sorryAx` 0, `ofReduceBool` 0, other axioms 0 |
| source scan for the forbidden words (the five files and the checker) | none |
| root imports | the five modules imported, the checker not |
| existing files changed | only the root's import lines; `Statements.lean` unchanged; nothing under `ops/` |
| name clashes (`l53_nameclash.py`, prefix `RunStg`; 41 worktrees, 4,698 other Lean files) | 0 |
| `RunStgTop.lean` against `l53_mk_top.py`'s output | identical |
| the lists against the code (`RunStgCheck.lean` on L29's receipt and the stage sources) | 108 checks, 0 failed: LIST 20, LU 4, DEF 16, SLOT 36, CLAIM 12, SPAN 2, SOURCE 8, NEGATIVE 10 |
| its controls (`l53_negative.py`) | the unchanged corpus passes; 11 of 11 single changes (7 to the receipt, 4 to the sources) caught |
| regressions | L6Check 1,206, L5Check 5,553, L11Check 404, fixture L1 101,956 checks; 0 failed in each |

The agreement check, by kind (both stages):

| Kind | What | Checks |
|---|---|---|
| LIST | slot count, the slots that draw, the head's length, each slot's rounds and degree, L29's slot walk accepts | 20 |
| LU | the LogUp window is the first head squeeze after `M` and before `H`; the operations to the head's end land on the code's transcript after `H` | 4 |
| DEF | every define window is the first of the slot's draws, then `pb-slot k`; the operations before it land on the code's transcript before the slot | 16 |
| SLOT | every slot window = define window + draws + 3, in order; `pb-scalar`, then (`sc-round`, squeeze) per round, then `pb-term`; the operations to `pb-term` land on the code's transcript after the slot | 36 |
| CLAIM | every claimed sum the list reads (`stgClaim`, with the hosting) is the slot loop's | 12 |
| SPAN | the head before the slots; the operations end on the last `pb-term` | 2 |
| SOURCE | the slot degrees in order; IN-C hosts nothing; OUT-C's TZC / LZC hosting with the `ν` after `τ`, `μ`; `define` before `run_stage_slot`; the heads' order | 8 |
| NEGATIVE | the block's head `m = 3` (IN-C, OUT-C); the frame one longer; a slot's draws one more; two slots swapped (IN-C 0 and 1; OUT-C 4 and 5); the zero-sum slot listed as drawing; a degree one more; OUT-C with no hosting; LZC's coefficient one draw later: each caught | 10 |
