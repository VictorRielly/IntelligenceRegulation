# ZK60 Lean lane L57: the stages' algebra under the stage lists (2026-11-10)

Lane L57 of D63 (Claude Opus 5.5), on its own worktree holding perf `fceca671` (lane L53 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency, no Rust. Evidence: `results/zk60_lean_l57_20261110/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (a script this lane ran against the code, with a negative control), **MEASURED**, **ARGUED** (reading the code
or the Lean, not a theorem), **ESTIMATE**, **LEFT** (not done).

**STATUS.** Deliverable 1 DONE for the hosting and the slot polynomials, after a type repair (finding L57-1): `hhIn`,
`hhOut` PROVED and gone from the top theorem; `FstI`, `FstO` SET to the stages' own slot polynomials over the extracted
data. NOT done for `ΦI`, `ΦO`, `ΛI`, `ΛO` (their exact shapes are written in §5). Deliverable 2 DONE for `StgTermAt`
(reduced to the run-level facts `StgTrueAt`, the same link the blocks still lack); NOT done for `StgDefAt`, `StgLkAt`,
`StgDoomAt`. Deliverable 3: the count CHECKED at the app's profile (15 squeezes) and `hD`'s count condition PROVED as
arithmetic at the model's escape count; the model of IN-C's state written (§5), its round-by-round proof LEFT.
Deliverable 4 DONE: two restated top theorems (generated), every premise listed (§4).

## 1. In plain words, for Victor

**The question.** Lane L53 fixed, for the two stages around the blocks (IN-C turns the hidden token ids into the first
block's input; OUT-C turns the last block's output into the verdict), which checks the top theorem lists. It left the
stages' own algebra as named premises: four "stage-level facts" and fourteen free objects (the stage polynomials, the
hosting). This lane was to set those objects to the real ones and prove the facts.

**What we found first (finding L57-1, High).** L53's lists hand each stage polynomial only the prover's log cut at each
position of the transcript. A cut stops just BEFORE the commitment root it is cut at, so the polynomial cannot see the
root, nor the statement. Every extraction of a committed table in the project reads the root as well as the cut. So
with L53's types no polynomial can be "the stage's polynomial over the extracted tables": the premises could only be
met by objects that are not the real ones. This is the same kind of fault as the ten unmeetable premises found before
(the latest L54-1): a type that cannot see the data the code reads. The blocks' lookup entries have the same fault
(finding L57-2).

**The repair (PROVED).** New stage lists, with the same windows, degrees, rounds and claims, whose polynomials also read
the transcript itself (the "view": the cuts AND the header). The view still reads the log only through the cuts, the one
condition the kinds data asks. L53's lists are exactly the special case that ignores the header, and L53's proofs carry
over without being redone. The app's top theorem is restated at the view lists (generated, PROVED).

**The hosting (PROVED).** Two premises are gone outright: `hhIn` and `hhOut` ("the slot definitions host what the lists
say"). They are now theorems about the code's own slot definitions: IN-C hosts nothing; OUT-C's TZC hosts SS with its
6th draw and LZC hosts PD with its `(llo + 3)`-th draw.

**The real slot polynomials (PROVED where stated).** `FstI` and `FstO` are now the code's own slot polynomials over the
extracted data: the code's `define`, its tables at the point, the private tables' values read from the matrices
extracted at the stage's roots (decoded, as the blocks' are), plus the mask term from the extracted mask table. Lean
proves that at every reading of a stage these polynomials meet the terminal identity the top theorem asks, as soon as
the openings' and the mask's claims are true of the extracted data and the header reader reads the statement. That
condition is the same run-level link the blocks still lack (L50 §5 item a).

**The count at the app's profile (CHECKED, and PROVED as arithmetic).** Stage IN-C's lookup draws 15 challenges at the
app's profile (3 + 12; the development rung's 12 was the only value known). The top theorem's count condition holds
with room: 15 × 270,336 = 4,055,040 against 201,326,592.

**What is not done.** The define polynomials `ΦI`, `ΦO` and the lookup states `ΛI`, `ΛO` are not yet set to the real
ones; IN-C's lookup state has a written model (§5) but no Lean proof of its round-by-round bound; the stage dooms
(`hdinS`, `hdoutS`) are not proved.

## 2. What is proved

All in namespace `ZK60.ProtocolClassify` (the top theorems in `ZK60.ProtocolClassify.RunShapeP`). Seven new files.

### 2.1 The hosting (`RunStgAlgHost.lean`)

| Theorem or object | Meaning |
|---|---|
| `sah_finishT`, `sah_build`, `sah_walk` | the slot builder's last action `finish(poly, hosted)` fixes the hosted list (a triple over L29's builder, as L39's walk) |
| `sah_nz1` | `nz1`'s coefficient is the draw at its index |
| **`sah_incDefine`** | every stage IN-C definition that succeeds hosts nothing |
| **`sah_outcDefine`** | every stage OUT-C definition hosts as `stgHostOut` says: TZC hosts SS with draw 5, LZC hosts PD with draw `llo + 2` |
| `stgHostIn`, `stgHostOut P0` | the hosting as data (`stgHostOut` reads `llo + 2` as `P0.draws 4 − 1`) |
| **`stg_hhIn`** | L53's premise `hhIn`, for EVERY stage IN-C verifier `inc : Hdr → IncV` |
| **`stg_hhOut`** | L53's premise `hhOut`, for every OUT-C verifier whose lists' schedule has its draws (`hPout`, already a premise) |
| `sah_finishT_canon`, **`sah_incDefine_canon`**, **`sah_outcDefine_canon`** | every stage definition's polynomial returns canonical words (each closure ends in an `Fp2` product or sum, both canonical on any input) |
| **`stg_hpolyIn`**, **`stg_hpolyOut`** | the side premise `hpolyC` of the real polynomials' terminal theorem, for every IN-C and OUT-C verifier |

### 2.2 The view lists (`RunStgAlgList.lean`)

| Theorem or object | Meaning |
|---|---|
| `StgVw`, `stgVw`, **`stgVw_cut`** | the view `(stgCuts absOf Lg τ, τ)`; it reads the log only through the cuts |
| `stgSlotV`, `stgSchedV`, `stgDefSqV`, `stgDefsV`, `stgLkSqV` | L53's list entries with `F`, `Φ`, `Λ` reading the view |
| `stgSlotV_cut`, `stgDefSqV_cut`, `stgLkSqV_cut`, **`stgDefSqV_rbr`** | `hD`'s side conditions that do not depend on the polynomials |
| `stgSchedV_get`, **`stgV_win`** | slot `k` and its window = define window + `draws k + 3` |
| `stgSlotX_V`, `stgSchedX_V`, `stgDefSq_V`, `stgDefs_V`, `stgLkSq_V` | L53's lists ARE the view lists that ignore the header (definitional) |

### 2.3 L53's alive premises and doom covers at the view lists (`RunStgAlgRun.lean`)

| Theorem or object | Meaning |
|---|---|
| `stgFAt`, `stgΦAt`, `stgΛAt` | at one transcript `τ`, a view polynomial is an L53 polynomial reading `τ`'s header at the entry's window |
| `subSt_slotSub_stmt`, **`stg_slot_V`**, **`stg_allSt_V`**, **`stg_def_V`**, `stg_defs_V`, **`stg_lk_V`** | the two lists' sub-protocols have the same windows, rounds, errors and states at `τ` |
| `StgTermAtV`, `StgDefAtV`, `StgLkAtV` | L53's stage-level facts over the view |
| **`stgTermAt_of_V`**, **`stgDefAt_of_V`**, **`stgLkAt_of_V`** | the view facts give L53's at `τ` (through L53's `stg_rd_slot`, `stg_rd_def`, `stg_rd_head`) |
| **`stg_hal_slV`**, **`stg_hal_r0V`**, **`stg_hal_luV`** | `hsl_stg`'s, `hR0_stg`'s, `hLU_stg`'s conclusions at the view lists (L53's `stg_sl_rd`, `stg_def_rd`, `stg_lk_rd` reused) |
| `StgDoomAtV`, **`stg_cover_rdV`**, **`stg_hal_doomV`** | the doom cover at the view lists (L53's `stg_cover_rd`, `stg_hal_doom` at them) |

### 2.4 The real slot polynomials (`RunStgAlgPoly.lean`)

| Theorem or object | Meaning |
|---|---|
| `stgWords`, `stgWords_toK` | the canonical words of a point; of a canonical word list's values, the list |
| `stgPrivVals`, **`stg_tabVals_data`** | the private tables' values over the data; at a point where every claim the slot builds is true of the data, the verifier's table values from the data are the ones from the proof |
| `stgPolyT`, **`stgPolyT_eval`** | the table side of slot `k` over the data, as the code evaluates it (ANY `BlockParams`); at the verifier's point of an accepted slot whose claims are true it is `poly(vals)` |
| **`stgFR`** | THE STAGE SLOT POLYNOMIAL over the view: the table side at the schedule the header reader reads, plus `c` times the CFS mask polynomial of the extracted mask rows |
| `StgTrueAt` | at every reading: the reader reads the reading's schedule, the claims are true of the data (`ClaimsTrue`), `M`'s functionals are true (`MTrue`) |
| **`stgFR_termAt`** | `StgTrueAt` gives `StgTermAtV` for `stgFR` (L16's `blockSlots_terminal` at the stages) |
| `stgCsv`, **`stgCsv_value`** | the claims' semantics over the view: `A` and `H` decoded from the matrices extracted at the stage's roots (L36's `csXof` at the stage), the IO commitments' a parameter; it reads a claim's functional only |
| `stgMsv`, `stgRv`, **`stgMsv_mlin`** | `M`'s semantics and rows over the view; linear on the rows (L31's `msOfTab_mlin`) |
| **`stgFstI`**, **`stgFstO`** | THE REAL `FstI`, `FstO`: `stgFR` at the stage's schedule as `Win` / `Wout` read it, the stage's roots `hdrLen`, `hdrLen + 3`, `hdrLen + 4 + m` |

### 2.5 The count (`RunStgAlgCount.lean`)

| Theorem | Meaning |
|---|---|
| `stgClog2_4096`, **`stgShield_m`** | at `d_pad = 4096`, IN-C's head is `incHeadDraws = 15` squeezes |
| `stgInEsc`, **`stgShield_count`**, `stgShield_count_room` | `15 · 270,336 ≤ 3 · 2^26` and `270,336 ≤ 2^26`; the condition holds up to `e ≤ 13,421,772` |

### 2.6 The top theorems (generated)

| Theorem | Meaning |
|---|---|
| **`stgAlg_productionReadyL_epP_exec_view`** (`RunStgAlgTop.lean`, `l57_mk_top.py`) | L53's top theorem at the view lists: `hostIn`, `hostOut`, `hhIn`, `hhOut` gone (PROVED); the stage facts and dooms over the view; the proof applies L50's theorem with this lane's stage terms |
| **`stgAlg_productionReadyL_epP_exec_real`** (`RunStgAlgTopR.lean`, `l57_mk_topr.py`) | the above with `FstI`, `FstO` the real polynomials (`stgFstI`, `stgFstO`) and `hTI_stg`, `hTO_stg` replaced by `StgTrueAt` (`hTrI`, `hTrO`), under the SAME hypotheses |

## 3. The numbers

| Figure | Value | Label |
|---|---|---|
| IN-C's LogUp head at the app's profile (R13 Shieldstral T128: `width 3072`, `d_pad 4096`) | `3 + clog2(4096) = 15` squeezes | CHECKED (`l57_count_check.py` on shape.rs, stage_in_c.rs, token_io.rs, classify.rs and Lean's `incHeadDraws`; 23 checks, 0 failed; 9 of 9 single changes caught); PROVED at `d_pad = 4096` (`stgShield_m`) |
| the same at the development rung (`d = 384`) | 12 | MEASURED by L53, re-derived by the check |
| IN-C's position and vocabulary domains at the app's profile | `tiLog = max(7, 12) = 12`, `vocLog = max(17, 12) = 17` (tier R1_MVP `stage_log_n = 12`, tekken `V = 131,072`) | CHECKED |
| IN-C's per-round escape count in the polynomial-identity model | `2·(2^12 + 2^17) = 270,336` | ESTIMATE (the model's degree bound, §5.3) |
| `hD`'s count condition for IN-C's LogUp run at `eL = 2^26` | `15 · 270,336 = 4,055,040 ≤ 3 · 2^26 = 201,326,592`; `270,336 ≤ 2^26`; room up to `e ≤ 13,421,772` | PROVED (`stgShield_count`, `stgShield_count_room`) |
| OUT-C DZC's define polynomial degree in `ζ` (the fold of twelve pad planes) | 11 (not 1, finding L57-3); `hD`'s define count still holds: `e = 11 ≤ 80`, `n·e = 23·11 = 253 ≤ 36,080` at `ldo = 12` | ARGUED (the code's `zeta_fold`, L15's CHECKED copy `zfoldW`) |
| binders of the top theorem | L53's `…_doom`: 156 explicit; `stgAlg_…_view`: 152 (`hostIn`, `hostOut`, `hhIn`, `hhOut` gone); `stgAlg_…_real`: 156 (`FstI`, `FstO` gone; `csIOI`, `csIOO`, `hIOI`, `hIOO`, `hNin`, `hNout` added; `hTI_stg`, `hTO_stg` replaced by `hTrI`, `hTrO`) | CHECKED (the generators) |

## 4. What is left, premise by premise

The final theorem is **`stgAlg_productionReadyL_epP_exec_real`** (`RunStgAlgTopR.lean`). Against L53's
`stg_productionReadyL_epP_exec_doom`:

**Gone**: `hostIn`, `hostOut`, `hhIn`, `hhOut` (PROVED: `stg_hhIn`, `stg_hhOut`); `FstI`, `FstO` (DEFINED: `stgFstI`,
`stgFstO`); `hTI_stg`, `hTO_stg` (replaced, below). Discharged inside the proof, never premises: the closures'
canonicity (`stg_hpolyIn`, `stg_hpolyOut`), `M`'s linearity on the extracted rows (`stgMsv_mlin`), the `A`/`H` claims'
semantics reading the functional only (`stgCsv_value`), the slot degrees `≥ 1` (`Iin.hgeomL`, `Oout.hgeomL`), the
schedules' shapes (`hPin`, `hPout`).

**New or changed** (every other binder is L53's, unchanged; L53 §5.4 lists them):

| Premise | What it says | Met by the real objects? |
|---|---|---|
| `csIOI`, `csIOO` | the claims' semantics of the IO commitments (IN-C: the input endpoint, `B_in`; OUT-C: `B_out`) over the view | ARGUED yes: each root is absorbed inside the header the view carries (`B_in` in IN-C's frame, the input endpoint inside `expected-IO`, L51-1 / L50-5; `B_out` in the last block's frame); the extraction is lanes L55's and L56's. LEFT |
| `hIOI`, `hIOO` | the IO semantics reads a claim's functional only, not its value field | ARGUED yes: true of L28's `claimSem` (PROVED for `A`, `H` here: `stgCsv_value`) |
| `hNin`, `hNout` | every stage slot has a variable and `(n + e)·d + 2 ≤ 512` (the mask row) | ARGUED yes: the largest at the app's profile is INC-02, `(17 + 1)·4 + 2 = 74`; at the rung L53 CHECKED `rounds × degree ≤ 65` |
| **`hTrI`, `hTrO`** (`StgTrueAt`) | under `hTI_stg`'s hypotheses: at every reading, the header reader (`Win`, `Wout`) reads the reading's schedule, the stage accumulator's claims are true of the extracted data, `M`'s functionals are true | ARGUED yes: the reader is the top theorem's `hW` at a prefix (LEFT to formalise); the claims and `M` are the run-level link "no doomed opening or `M` ⇒ claims true" the blocks also lack (L50 §5 item a) |
| `ΦI`, `ΦO` (view type) | the define polynomials | free; the real ones are written in §5.1; LEFT |
| `ΛI`, `ΛO` (view type) | the LogUp states | free; OUT-C's is a block-style state (§5.2), IN-C's the model of §5.3; LEFT |
| `hb0`, `hbL` | THE CHOICE, at the view lists with the code's hosting and `FstI`, `FstO` the real ones | YES by construction (`stgPart_lists` applies unchanged) |
| `hDI_stg`, `hDO_stg` (`StgDefAtV`) | the define polynomials vanish at the drawn challenges | LEFT (as L53; with §5.1's `Φ`) |
| `hLI_stg`, `hLO_stg` (`StgLkAtV`) | LogUp's state at the head's challenges | LEFT (as L53) |
| `hdinS`, `hdoutS` (`StgDoomAtV`) | the stages' dooms at their readings | LEFT (as L53: the contrapositives of L12's `inc_stage_sound`, L15's `outc_stage_sound`, now expressible over the extracted data) |

`hD` keeps L53's form at the view lists (`stgSlotV_cut`, `stgDefSqV_cut`, `stgLkSqV_cut`, `stgDefSqV_rbr` PROVED); its
open parts at the stages are the define degrees (`dg`, §3 and L57-3) and LogUp's round-by-round bound (§5.3).

## 5. The shapes the next lane needs

### 5.1 `ΦI`, `ΦO`
Over the view `v`, slot `k`, history `(ch, earlier draws)` and draws `y`: the cube sum of the table side
`stgPolyT` at the define drawn with `y` (over `csv v`), minus `Σ_{(j,i) ∈ host k} y_i · (slot j's cube sum)`. With
`StgTrueAt` and the slots' true start claims, L36's unmasking (`accT_unmask`) gives `Φ(draws) = 0` (`StgDefAtV`). The
round-by-round condition (`stgDefSqV_rbr`) needs its degree in `y`: 1 for every stage slot but OUT-C's DZC (11, L57-3),
which needs the closures read as polynomials (L15 §6 item 4, the `toK` bridge per closure).

### 5.2 `ΛO`
OUT-C's head `γ, α` is a block-style LogUp run (L21's `lkSt3` with `β` absent): its lookups are LZC's limb plane and
DZC's twelve `Do` planes read from `A` extracted at the root the view shows, the table the 256 bytes shifted by
`γ·TAG_U8`. It needs the lookups to read the root as well as the cut (L57-2 for the blocks' `lkSq`).

### 5.3 `ΛI` (finding L53-2)
The code draws `β, γ, α` and THEN `r_emb` (L29-3), so LogUp's `α` is drawn while the folded embedding row is still a
polynomial in `r_emb`. The state that is round-by-round sound in this order: let `Q(β, γ, α, r)` be the LogUp identity
with its denominators cleared (`Π_t (α − q_t) · Π_v (α − τ_v) · (Σ_t s_t / (α − q_t) − Σ_v m_v / (α − τ_v))`, `q_t`,
`τ_v` the code's folds `tok + β·x~(t, r) + β²·c + γ·TAG`); after a prefix of the 15 challenges, the state is "Q with that
prefix substituted is the zero polynomial in the challenges not yet drawn". A failing lookup makes the start state
false; each challenge escapes at most at the roots of a non-zero polynomial of degree `≤ 2·(N + M)` in it (`β` appears
squared; the bad poles of L12-1 add at most `M` to `α`'s count); the final state is implied by the verifier's helper
relations. So `e = 2·(N + M) = 270,336` at the app's profile and `hD`'s count condition holds (§3). LEFT: the state in
Lean (multivariate polynomials in the remaining challenges) and its round-by-round proof.

## 6. Findings

**L57-1 (High; for the coordinator and every later stage lane): L53's stage lists cannot hold the real polynomials.**
`stgSlotX`, `stgDefSq`, `stgLkSq` hand `F`, `Φ`, `Λ` only `stgCuts absOf Lg τ`, the log cut before each header absorb. The
roots (and the statement) are not in it, and every extraction reads the root (`colX` reads `rootAt hdr i`; `csXof` reads
`rootsAt`). A prover that builds two Merkle trees and absorbs one root gives two runs with the same cuts and different
committed tables, so no fixed `F` of the cuts is the slot polynomial over the extracted tables of both: the premises
`StgTermAt`, `StgDefAt`, `StgLkAt`, `StgDoomAt` could not be met by the real objects. ARGUED (it is a statement about all
functions of a type). Repaired here (§2.2, §2.3): the view lists, the top theorems restated. Later lanes should build on
`stgAlg_productionReadyL_epP_exec_real`, not on L53's.

**L57-2 (Medium; for the coordinator and the block lanes L46, L47, L50): the blocks' LogUp entry has the same fault.**
`lkSq` (LookupW16FS.lean:212-217) reads its lookups `Alk` and multiplicities `mlk` off the cut at the `A` root only;
`RdBlkR13.hlu` asks `lkSq … Alk … mlk ∈ D.lu (k + 1)` with `D` fixed for every run, so `Alk` cannot be the extracted
`A`'s lookups. The blocks' slots (`Fsl k : Cuts3 → RootsO → …`) and define draws (`defSq`'s `Φ`) do see the roots. The
same repair applies (a block LogUp entry whose lookups read the root bytes too). ARGUED; not changed (not this lane's files).

**L57-3 (Low; for the next stage lane): OUT-C's DZC define polynomial has degree 11 in `ζ`.** L53 §5.1 ARGUED `dg = 1`
per draw; DZC's pad is the code's `zeta_fold` of twelve planes (`Σ_{j<12} ζ^j·P_j`), so `dgO 5` must be 11. The count
condition still holds (§3).

**L57-4 (Info; L53-2 settled): IN-C's head is 15 squeezes at the app's profile and `hD`'s count condition holds** with
the polynomial-identity model's `e = 270,336`, against a bound of `13,421,772` (§3, §5.3). No split head is needed. No
classifier receipt at the app's profile exists in the repository or under `zk60-artifacts` (the Shieldstral weights are
not in the repository, D62): the 15 is CHECKED against the code, not MEASURED from a run.

**L57-5 (Info; for L55, L56): the IO semantics the real `FstI`, `FstO` need.** `csIOI`, `csIOO` are the endpoint's and
the boundaries' claims' semantics over the view, read at their roots' header positions; the roots are in the header
the view carries (unlike with L53's lists).

**L57-6 (Info; Lean method).** In a `show (match … with | .error e => …)`, write `Except.error e`, `Except.ok …` in the
arms (the dot notation has no expected type there; iter3). `split_ifs at h` closes a branch whose hypothesis became a
constructor clash (iter4). A view polynomial at ONE transcript is an L53 polynomial (`stgFAt`), so L53's reading-level
theorems carry over by congruence (`subSt_congr`) instead of being re-proved.

## 7. Checks

_Filled in from `check1.log`._
