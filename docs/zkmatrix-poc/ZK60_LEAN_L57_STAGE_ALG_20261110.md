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

_§3 to §7 follow._
