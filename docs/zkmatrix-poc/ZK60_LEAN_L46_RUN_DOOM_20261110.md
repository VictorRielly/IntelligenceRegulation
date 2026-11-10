# ZK60 Lean lane L46: the run's doom covers. The block cover `hdblk` discharged on the run's transcript (2026-11-10)

Lane L46 of D63 (Claude Opus 5.5), on its own worktree holding perf `31af9ac1` (lanes L43 and L44 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Evidence: `results/zk60_lean_l46_20261110/`.

New library files under `formal/ZK60Formal/`, imported by the root: `RunDoomBlk.lean` and `RunDoomTop.lean` (generated
by `l46_mk_top.py` from L43's `RunCoverPRk.lean`). No existing Lean file changed; `Statements.lean` unchanged. No Rust.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CHECKED** (Lean output this lane ran, with its log), **MEASURED** (a number read off a run), **ARGUED** (reasoning,
not a Lean theorem), **LEFT** (not done).

**STATUS.** Deliverable 1 (`hdblk`) DONE: PROVED through L27's `block_doom_r13` on the run's transcript, at the
per-block-shape model, with every remaining link a named field of one bundle per block (`RdBlkR13`), and the app's top
theorem restated with `hdblk` replaced by those bundles (`rd_productionReadyL_r13P_exec_blk`). Deliverable 2 (the
endpoint links `hBal`, `hdzero`, `hread`) NOT done. Deliverable 3 (`hdin`, `hdout`) NOT done. Deliverable 4 PARTLY:
the top theorem with `hdblk` discharged (§2.3); the premises left are listed in §4.

## 1. In plain words, for Victor

**What `hdblk` says.** The top theorem assumed, for each of the 26 blocks: "if the block's equations fail on the data the
extractor pulled out, then some check of the run started from a false claim". Nobody had proved it. Lane L39 found that
the per-block security theorems could not simply be plugged in (they bound a probability for one block alone; the run
needs a yes/no statement on the run's own transcript) and named the route: the block's case analysis (L27's
`block_doom_r13`) on the run's transcript.

**What is now proved.** That route, end to end. A check "starts from a false claim" exactly when, at the point where
it begins, its starting claim about the committed data is false. For the checks that matter here (the random draws that
test the block's relations, and the lookup check) every point of the transcript is a valid starting point, so no
bookkeeping about step boundaries is needed. The proof then runs:
1. if the block's input or output plane on the run is not the block's own copy, one of the two boundary checks
   (`SC_IO_IN`, `SC_IO_OUT`) starts from a false claim;
2. if the block's 50 relations fail, one of the four relation layers has a false starting claim (lane L36's algebra),
   and its random draw starts doomed;
3. if the relations hold but a lookup fails, some looked-up value is outside the table (L36's lookup bridge), and the
   lookup check starts doomed.
Every one of these lands in the block's own part of the run.

**What is still assumed, per block.** The block's link to the run, bundled as one object per block: that the run's
lists of checks for that block are the block's real checks at their run positions, that the transcript reads as the
block's history there, the block's layout facts and L36's two table facts (the ones lane L47 is proving), and one NEW
fact about the two boundary checks (§4, finding L46-3: no Lean object models them yet). None of these is about
probability; each is a statement about the real objects that is expected to hold, and §4 says for each why.

**One correction to the plan (finding L46-1).** The plan said the block cover needs the NEXT part's opening (a block's
output claims are opened by the next part). Not for `hdblk`: every doom of the block cover is in the block's own part.
The next part's opening is needed elsewhere: to show that the boundary check of block `k` ends well, which is part of
the "alive" premises (`hal_R0` and on), not of the doom cover.

**What is not done.** The input endpoint's three links (`hBal`, `hdzero`, `hread`) and the two stage covers (`hdin`,
`hdout`). §5 says exactly what they need.

## 2. What is proved

All in namespace `ZK60.ProtocolClassify` (`RunDoomTop.lean` in `ZK60.ProtocolClassify.RunShapeP`). Every declaration
on at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 Doomed entrants of the run's squeeze kinds (`RunDoomBlk.lean`)

| Theorem | Meaning |
|---|---|
| **`rd_ksq_cs`** | part `i` of a squeeze kind (`rtKsq`: the four define kinds, LogUp) lists exactly part `i`'s squeeze runs |
| **`rd_entD_sq`** | a squeeze run whose header state is false enters its window doomed (single-step parse: every position is a step's end, `tRem_W1`) |
| **`rd_some_sq`** | a squeeze run of part `i`'s `r0`, `r1`, `h0`, `h1` or `lu` list with a false header state is a doomed entrant of `rtKo` (L39's `RcSome`) |
| `rd_absAt_take`, `rd_rootsAt_take` | the roots a header shows are the transcript's |
| **`rd_defSq_doom`** | L21's define draw `defSq` of a slot whose start claim fails is doomed at entry (state `Φ ≡ 0`; `Φ ≡ 0` gives the start claim) |
| **`rd_lkSq_doom`** | L21's LogUp run `lkSq` is doomed at entry when a looked-up tuple is no table entry |
| **`rd_def_some`**, **`rd_lu_some`** | the two on the run's transcript, at part `i`'s lists, with the history the transcript shows |

### 2.2 The block's doom (`RunDoomBlk.lean`)

| Theorem or object | Meaning |
|---|---|
| **`rd_r13_notGd`** | L36 at R13: `R13Rels` failing on the extracted planes ⇒ some slot of the four relation layers has a false start claim (`r13Rels_of_algGood` with `R13Spec`, `algGood_of_gd`) |
| `RdDefAt` | a slot's define draw sits in part `i`'s define lists at its run position, and the transcript before it reads as `define`'s history of the outcome's `bga`, `rs` |
| **`rd_blk_doom`** | BLOCK `k`'S DOOM AT ONE OUTCOME: `¬ BlockOn Pb Xin Xout` ⇒ a doomed entrant of `rtKo` in part `k + 1`. L27's `block_doom_r13` with `h1`, `h2` vacuous (§3), `h3` by `rd_r13_notGd` and the relation layers' draws, `h4` by L36's `hbr_r13_of_cover` and LogUp; the planes by the boundary slots (if their start claims hold the run's planes are the block's, else their draws are doomed) |
| **`RdBlkR13`** | block `k`'s R13 objects and links at one outcome, as one structure (its layout types are fields: they differ per block) |
| `rd_blk_doom_of` | `rd_blk_doom` from the bundle |
| **`rd_hdblk`** | **`hdblk`**: for any acceptance event and any extracted planes, if on every accepted outcome every block `k` has its bundle at its own shape `Rp.blks[k]`, then the premise `hdblk` of the app's top theorem holds, in its exact (unfolded some-part) form |

### 2.3 The app's top theorem with `hdblk` discharged (`RunDoomTop.lean`, generated)

| Theorem | Meaning |
|---|---|
| **`rd_productionReadyL_r13P_exec_blk`** | L43's `rc_productionReadyL_r13P_exec_rk` (D76's approved form, one shape per block, `D := rkData …`) with `hdblk` REPLACED by `hblk`: on every accepted outcome outside the run's extraction failure `EvXR`, every block `k` has its `RdBlkR13` bundle on the run extractor's planes `k`, `k + 1`. The proof is `rc_productionReadyL_r13P_exec_rk` with every argument by name and `hdblk := rd_hdblk …`; the part count `pf.parts.length = Rp.blks.length + 2` comes from `RtRun.parts_length` and `O.blocks` |

`l46_mk_top.py` copies L43's statement and changes only the name, the docstring, the `hdblk` block (asserted to occur
once, with its verify and `EvXR` lines) and the proof. The check compares the file with the generator's output.

## 3. The numbers, and the shape of the cover

| Figure | Value | Label |
|---|---|---|
| parts of the run in which `hdblk`'s dooms lie | ONE: block `k`'s own part `k + 1` | PROVED (`rd_blk_doom`'s conclusion) |
| links of `block_doom_r13` used | 2 of 4 (`h3`, `h4`); `h1`, `h2` with `Op := True`, `Cl := True` | PROVED |
| relation layers whose start claims cover `R13Rels` | 4 (`w16r2RelKs 0 … 3`: 9, 12, 2, 1 slots) | PROVED (`rd_r13_notGd`, L36) |
| premises of the top theorem replaced | `hdblk` → `hblk` (one bundle per block and outcome) | PROVED (`rd_productionReadyL_r13P_exec_blk`) |

Why `h1`, `h2` are vacuous [ARGUED, and PROVED in the sense that the proof uses `True`]. At the run level "entered
doomed" is a property of the extracted data at the window: a define draw is doomed when its slot polynomial is not
identically zero; LogUp is doomed when a lookup is outside the table. Neither depends on whether the openings' values or
the claimed sums are true. Those enter when the doomed check must END alive, which is the ordered `halive` side
(`hal_R0 … hal_LU`), where L30-1 already puts them.

## 4. What is left, premise by premise

### 4.1 The fields of `RdBlkR13` (block `k`, one accepted outcome), and whether the real objects meet them

| Field | What it is | Class | Met by the real objects? |
|---|---|---|---|
| `Ct … Cf` (with `Fintype`, `DecidableEq`), `ls`, `Lay`, `B`, `hWr`, `h24` | block `k`'s R13 layout, gates, limb windows, LowH24 | (e) public data | ARGUED: L17's layout at the block's own shape `Rp.blks[k].cal.over S`; `hWr` is L17's `derive_windows` at LowH24 (PROVED there for derived shifts; A29's single calibration must stay in the windows); `h24` true at the app's profile |
| `P`, `hdrLen` | the block profile and block `k`'s run position | (a) bookkeeping | ARGUED: the D12a profile; `hdrLen = pf.off (k+1) + 5` (L43's `rkAccBlk` convention) |
| `sh`, `dt`, `xtE`, `enc`, `encHt`, **`hspec`** (`R13Spec`), `hTok`, `hHd` | L36's shape facts, tables and reindexing | (a), L36's form; L47's | `sh`: PROVED for pad counts `≤ 78` (`algShapeR13Shield`). `hspec`: ARGUED definitional once `dt`, `xtE` read the same planes (L36 §5). `hTok`, `hHd`: MEASURED (`pads = 0` for `T`, `S`, `Kv`, L36) |
| `bga`, `rs` | the outcome's LogUp challenges and slot records | data | the run verifier's own, read off the transcript |
| **`hdefR`** (`RdDefAt` for every slot of the four layers) | the layers' define draws in part `k + 1`'s define lists, their windows on the transcript, the history the transcript shows | (a) bookkeeping; the draw lane's (L45) | ARGUED: (i) met by the CHOICE of `ps (k+1)` in `rkData` (finding L46-2 proposes the assignment, and it keeps `RkPart.Ok`'s window order: each layer's slots are in increasing order, `defPart_sorted`); (ii) the history: L21's `tHistD_trace` PROVES it on the block's own trace; the carry to the run's transcript is the same carry as L43's `rk_blk_run` (LEFT); (iii) the windows: on accepted runs the block lies inside the transcript (`rh_win`'s layout, LEFT for these windows) |
| **`DIO`**, `hIOΦ`, **`hdefIO`**, **`hIO`** | the boundary slots `SC_IO_IN`, `SC_IO_OUT` as a define schedule in part `k + 1`; their start claims make the run's planes `k`, `k + 1` the block's `X`, `X2` | (a), NEW (finding L46-3) | `hIOΦ`: PROVED for any schedule built by `schedOf` (`schedOf_facts`). `DIO`, `hIO`: ARGUED (L46-3): needs the IO slots' certified polynomial (not in Lean) and the run extractor's planes defined as the decoded boundary commitments |
| `ι`, `π`, `κ`, `Alk`, `T`, `mlk`, `hlu`, `hlen` | LogUp's lists and its run in part `k + 1` at `hdrLen + 4` | (a); L47's (lists), L45's (placement) | ARGUED as `hdefR` (placement by the choice of `ps (k+1).lu`) |
| **`hTtab`**, **`hcov`** | L36's lookup side: every table entry is an R13 table tuple; every logical query of `R13Lookups` is an entry of the lookup list at the `A` cut | (a), L36's exact form; L47's | ARGUED by L36 §5 (`hTtab` from the code's table columns; `hcov` from `AccuracyIds::lookups`) |

Not needed by `hdblk` (they were in L36's block statements): `hform`, the helper layer (`HGd`, `spH`, `hdgH`, `hformH`,
`hgdH`), `hhr`, `hN`, `he`. They belong to the "alive" side (`hal_R0 … hal_LU`) and to the counts.

### 4.2 The premises of `rd_productionReadyL_r13P_exec_blk`

As L43 §4 for `rc_productionReadyL_r13P_exec_rk`, except:

| Premise | Class | Status after this lane |
|---|---|---|
| `hdblk` | — | GONE: discharged by `rd_hdblk` |
| `absOf` | (a) bookkeeping | the cut reader of the define draws; at the real objects `absOfC (chainEncB key domain hs Lq hL)` (the one `rkData_valid` uses) |
| `hcard : 78 < Fintype.card K` | — | PROVED true of every `K` here (`card_K_gt`); kept as a premise in this version (§5) |
| **`hblk`** | (a), (e) | NEW: one `RdBlkR13` per block on every accepted outcome outside `EvXR` (§4.1) |

Unchanged from L43: `hopW`, `hMW` (the stages' `A`, `H`, `M` and every closing opening `X`, L43-3, L43-6), the
extraction `RhXOk` / `RhXMOk` (GA-8, L43-2), `hal_slots`, `hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`, `hal_LU`, `hdin`,
`hdout`, `hread`, `hBal`, `hdzero`, `ps`, `acc`, `lsc`, `eL`, `hDe`, `hD`, `hU`, `Rn`, `hv`, `O` (`ClassifyOpenP`),
`hzk`, the Merkle work, the endpoint's test data, the token-plane layout, `E` (except through `hE` and now `hIO`).

## 5. Not done, and what the next lane needs

1. **`hcard`** can be removed from the top theorem with `card_K_gt K` (BlockAlgFinal.lean) in its statement; not done
   here (a one-line change of the generator).
2. **The boundary slots' schedule `DIO` and `hIO`** (finding L46-3): a certified polynomial for `SC_IO_IN`, `SC_IO_OUT`
   (`progR13`'s `ioIr cstS 0 1 2` on `[eq, aPlane x / x2, epTab inp / out]`), its start claim "the A plane equals the
   endpoint table on the gated D positions", and the run extractor `E` with `planes j` the decoded boundary `j` read
   through the D layout. Then `hIO` follows from the gates (`gD = 1` at logical positions).
3. **`hdefR`, `hdefIO`, `hlu` at the real `ps`**: the draw lane's `ps (k+1)` (finding L46-2) and the carry of
   `tHistD_trace` to the run's transcript (as `rk_blk_run` carries `tAccRd`).
4. **`hdin`, `hdout`** (deliverable 3): the same pattern as `rd_blk_doom` at parts `0` and `L + 1`: IN-C's and
   OUT-C's conclusions (`InOkP`, `OutOkP`) from their slots' start claims (L12 `inc_stage_sound`, L15
   `outc_stage_sound`, L29's `incSlots_model`, `outcSlots_model`), and a doomed define draw or LogUp run of the stage
   part when one fails, through `rd_some_sq`. What is missing is the stages' define and LogUp sub-protocols as `SqX`
   (the stages have no `defSq`; their slot loop is `stSlotsLoop`, L43-6), which is L45's stage-reader work.
5. **`hdzero`** (deliverable 2): IN-C's `SIC_IO` zero-check is a stage define draw whose start claim is "the decoded
   endpoint plane vanishes off the token positions" (with L26's `decodeIn_eq` identifying the decoded plane); then
   `rd_some_sq` at part `0` gives the doom. Needs the same stage `SqX` as item 4, and `hdzero`'s `K'.Dm` is `RcSome`'s
   content.
6. **`hBal`, `hread`** (deliverable 2): `xB_subSt_of_opB` needs the test `T` to BE part 0's closing opening (`rkData`'s
   `opX 0`, whose `opB` is alive by `hopW`), but `T` is an `XTest` over `F` with its own claim type and matrix reader,
   while `opX 0` is an `RtOpen` over `K` with `rkPend`'s claims. Identifying them (or restating the endpoint test as
   `opX 0`) and putting the endpoint opening's column checks into `Vx` (L45, GA-8) come first.

## 6. Findings

**L46-1 (Medium; for the coordinator and L45): the block cover needs no "next part".** With "entered doomed" read as
L27 / L30 define it (the header state false at the window), every doom of `hdblk` is in block `k`'s own part `k + 1`
(`rd_blk_doom`, PROVED): a boundary slot's or a relation layer's define draw, or LogUp. L34-2's "some part" form and the
next part's closing opening matter for the ALIVE side: the boundary slot `SC_IO_OUT` of block `k` ends alive only if its
claim on boundary `k + 1` is true, and that claim is opened by part `k + 2`. The some-part form of the covers stays
right (it is weaker), but the next lane proving `hal_R0 …` must use the next part's opening there.

**L46-2 (Medium; for L45, the draw lane): six define schedules, four define kinds.** Part `k + 1` has the four relation
layers, the helper layer and the boundary slots; `rkData` has four define kinds (`r0`, `r1`, `h0`, `h1`), and the
ordered cover asks a kind alive only when no EARLIER kind has a doomed entrant, while layer `i` vanishes only when
layers below `i` hold (L23-2). An assignment that fits [ARGUED]: `r0` = layer 0 and the boundary slots; `r1` = layer 1
and the helper layer (both need only layer 0); `h0` = layer 2; `h1` = layer 3. Each list sorted by window
(`defPos` increases with the slot index; layers 2 and 3 share slot 5's window, which `≤` allows). This lane needs only
that each layer's draws are in the union (`RdDefAt`).

**L46-3 (Medium; for L45, L47 and the coordinator): the boundary slots have no Lean model.** `SC_IO_IN`, `SC_IO_OUT`
are outside L36's four relation layers by design (`w16r2RelKs_cover`: "every slot but the run's boundary slots"), and
no certified polynomial or start claim exists for them. They are what ties block `k`'s own copy of its input and output
(`xt.X`, `xt.X2`, in `A`) to the run's boundary planes. This lane takes them as `DIO` with `hIO`. Two facts the next
lane must check [ARGUED, not CHECKED]: consecutive blocks read boundary `k + 1` through the same D layout (D is tokens ×
width; a block's calibration changes `H`, `G`, `f` and the shifts, not D), and the IO slot's endpoint table is
extracted at the same root and cut as the closing opening that opens it.

**L46-4 (Low; for the coordinator): `E`'s planes were unconstrained.** The top theorem pins only `E`'s endpoint part
(`hE`); its boundary planes were free, so no `hdblk` could have been proved without a premise on them. `hIO` is now that
premise, met by the definition "plane `j` is the decoded boundary commitment `j`" [ARGUED]; nothing else in the top
theorem constrains `E.planes`, so the choice is free.

**L46-5 (Info; Lean method): instance fields of a bundled structure.** `haveI := bd.fCt` introduces an opaque instance
that is not definitionally the field, and the elaborator refuses it ("synthesized type class instance is not
definitionally equal", iter2); `attribute [local instance] RdBlkR13.fCt …` works (iter3).

**L46-6 (Info): deliverables 2 and 3 not started in Lean.** §5 items 4 to 6.

## 7. Checks

See `results/zk60_lean_l46_20261110/check.log` (filled in after the run, below).
