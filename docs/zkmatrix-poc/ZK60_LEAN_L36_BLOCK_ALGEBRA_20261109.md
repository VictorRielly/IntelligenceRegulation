# D63 lane L36: the block's algebra. The certified slot polynomials, their vanishing on acceptance, the reindexing to the named relations, and the lookup bridge (2026-11-09)

Lean lane L36 (Claude Fable 5.2, then Claude Opus 5.5 after a usage-limit stop at 19:21 PST), on its own worktree,
merged with perf `2155ede8` (L9 to L34 and A28). Lean 4.34.1, Mathlib v4.34.1, no new dependency. Twelve new library
files under `formal/ZK60Formal/`, imported by the library root: `BlockAlgUnmask`, `BlockAlgKinds`, `BlockAlgInst`,
`BlockAlgRels`, `BlockAlgFinal`, `BlockAlgShapes`, `BlockAlgR13`, `BlockAlgLk26`, `BlockAlgLkR13`, `BlockAlgLkW16`,
`BlockAlgLkFinal`, `BlockAlgSat`. One checker, `BlockAlgCheck.lean`, not imported by the root. No Rust.
`Statements.lean` and every existing Lean file are unchanged. Evidence: `results/zk60_lean_l36_20261109/`.

**STATUS.** Deliverables 1 to 3 done for the four relation layers, at W16R2 and at R13, up to named premises that
join lane L35 (§4). Deliverable 4 done for the lookup bridge `hbr` (reduced to two facts about the code's lists) and
for the counts `hN`, `he` (with finding L36-1 repaired at the app's block); NOT done for the helper layer (`spH`,
`hdgH`, `hformH`, `hgdH`, `HGd`) and `hhr`. Deliverable 5 done in the form of §2.9: the three block statements with
all of the above removed. Deliverable 6: `BlockAlgCheck` on L17's shape corpus, with a negative control (§7).

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**MEASURED** (read off the code's registered shapes and checked by `BlockAlgCheck`), **ESTIMATE** (arithmetic on
bounds, not a Lean theorem), **ARGUED** (a reasoned claim from reading the code, not a Lean theorem), **HYPOTHESIS** (a
named premise, with the shape a later lane must prove), **LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** Lane L31 left the security statement of ONE transformer block in this form: "the
chance that the block verifier accepts while the committed data breaks the block's equations is at most your target",
given a list of facts about the block's algebra. This lane was to prove that list. It had four parts: the block's 23
slot identities written as polynomials of the verifier's random challenges; the fact that these polynomials are zero
on every accepted proof; the fact that "all of them identically zero" means the block's named equations hold; and the
lookup tables' side.

**What is now proved.**
1. **The slot polynomials are built** (PROVED). For all three block profiles (the W16R2 test rung, the R13 test rung,
   and the Shieldstral T128 R13 block the media app runs), the polynomials of the four "relation layers" are built in
   Lean from the block's tables, with their degrees (at most 80).
2. **They are zero on every accepted proof.** PROVED outright for three of the four layers. For the first layer (the
   six "host" slots) it is PROVED from one named fact per host: "this slot's sum, without its mask, is the slot's
   named formula". That fact needs lane L35's definition of the slot polynomials, which is being written beside this
   lane; it is stated here in the form L35 can prove (§4).
3. **"All claims hold" gives the block's named equations** (PROVED, at W16R2 and now at R13): once every slot's claim
   holds, all the named relations of the layout theorem hold on the committed data (34 at W16R2, 50 at R13). This is
   the step lane L23 called the reindexing. What it needs: the slot tables are the named relations' tables read
   through the cube's index maps (a fact about how L35 builds the tables).
4. **The lookup side, half of it** (PROVED): "a failing lookup is a value outside the table" now follows from two
   plain facts about the code's lists: every table row is a real table row, and the lookup list contains every
   lookup the named relations ask for. The other half, that the helper columns satisfy their equations, is NOT done.
5. **The app's block statement is repaired** (finding L36-1, PROVED). Every block statement since L21 assumed at most
   35,153,256 table lookups (the 8B block's count). The app's Shieldstral R13 block makes 64,258,048, so that
   statement said nothing at the app's block. This lane re-proved the Shieldstral chain with the bound `2^26`
   (67,108,864), the bound the run-level chain already used. The block still fits your target: 54,314,754 of
   67,108,864 budget units (PROVED arithmetic).
6. **The premises can be met** (§5, the audit you asked for): each premise this lane takes is either PROVED to hold
   at the registered shapes, or ARGUED from the code to be meetable, or left to a named later lane. None was found
   that no real block can meet, apart from the one this lane repaired (L36-1).

**What is not done** (§6): the six hosts' named sums and the tables' definition (the join with L35), and the helper
layer with the helper columns' equations.

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 `BlockAlgUnmask.lean`: the unmasking on an accepting outcome, and a layer's vanishing from named identities (any block shape)

| Theorem / definition | Statement |
|---|---|
| `spSum` | a slot's unmasked cube sum `Σ_b Poly_k(b)` at an outcome |
| **`accT_unmask`** | on an accepting outcome (`AccT`, `F = Poly + c·mask`): every verified slot has a definition; a standalone slot's unmasked sum is `0`; a host's (hosted slots not hosts) is `Σ_h κ_h·(slot h's unmasked sum)`. It is L23's `unmask_slots` with every premise discharged from `AccT` |
| `FormAt` | **the named identity of slot `k`**: its certified polynomial at the drawn challenges is the slot's unmasked residual (`Σ Poly_k` for a standalone slot, `Σ Poly_k − Σ_h κ_h·Σ Poly_h` for a host) |
| **`schedVan_of_form`** | a define schedule whose slots meet `FormAt` vanishes at the drawn challenges of every accepting outcome (`SchedVan`): `hvR`'s layer 0, and `hvH` |

### 2.2 `BlockAlgKinds.lean`: the slot kinds' algebra (any block shape)

| Theorem / definition | Statement |
|---|---|
| `mleAt_one`, `mleAt_castCube`, **`mleAt_rowOnly`**, `mleAt_lin2`, `append_cast_ite` | the multilinear extension of `1` is `1`; of a function through a relabelling of the cube; of a function of the first block of coordinates only (its value at `(p, s)` is its value at `p`, whatever `s`); linearity; a two-block claim point read coordinate by coordinate |
| `segAt`, **`hostAt_Gd`**, **`hostAt_dg`**, **`hostAt_Φ`** | L23's host polynomial on its draw vector: its start claim is `hostGd`, its degree `m + 2`, and at a vector it is `hostPhi` at the segments' entries |
| **`hostPhi_of_sums`** | a host's identity is (its named sum `Z̃(τ) + Σ_i ν_i·h̃_i(p_i)`) minus (its hosted slots' named sums `Σ_i ν_i·M̃_i(p_i)`) |
| **`priv_van`**, **`part_van`**, **`rs_van`**, **`cross_van`** | a private slot's polynomial at its drawn point is `0` once its host's hosted difference at that point is `0`, for the four ways a claim point is made |
| `part_pointwise` | the drawing slot's start claim gives the hosted identity at every cube point |

### 2.3 `BlockAlgInst.lean`: the certified slot polynomials of a W16R2-family block (`spR`, `hdgR`, `hvR` layers 1 to 3)

| Theorem / definition | Statement |
|---|---|
| `algHosts`, `hostedOf`, `partSrc`, `HostLay` | the six hosts, the private slot each hosts at `ν_i` (L11's `hostsOf`), the slot a split claim point starts with |
| `AlgShape` | the shape facts read off the draw schedule: the hosts' draw lists, pad plane counts (at most 78), where each hosted claim point sits in the draws, the cube splits |
| `AlgData` | the block's tables on the hosts' flat cubes: batched clauses `cl`, pad planes `pw`, each hosted pair's gated host term `gh` and contraction `mm`, `SC_RS`'s row differences `rsA`, `rsB`, the scale `2^b` |
| `algDrawAt`, `algLam`, `algH`, `algM`, `algPt`, `partD` | a host's hosted functions and claim points read off the history (L11's `claimPoint`) |
| `hostSp`, `privSp`, `partSp`, `rsSp`, `crossSp5`, `crossSp11`, **`algSp`** | **`spR`**: the certified polynomials by layer and slot (L23 §3's table) |
| **`algSp_dg`** | **`hdgR`**: every degree is at most `80` |
| **`algSp_van1`**, **`algSp_van2`**, **`algSp_van3`** | **`hvR` for layers 1, 2, 3**: each layer vanishes at the drawn challenges once the layers below hold their start claims. No further premise |
| `AlgGood`, **`algGood_of_gd`** | all four layers' start claims say: every host's clauses and pad planes vanish on its cube, every hosted identity `gh = mm` holds at every cube point, `rsA` and `rsB` vanish |
| **`formAt_host`** | a host's `FormAt` from its kind, its hosted slots not being hosts, and its polynomial at the draws being (named sum) − (hosted named sums) |

### 2.4 `BlockAlgRels.lean`: `hgdR` at W16R2

| Theorem / definition | Statement |
|---|---|
| `W16Pos` | a position of one of the seven padded product cubes |
| `relCl`, `relCount`, `relGh`, `relMm`, `relRsA`, `relRsB` | L11's `W16Rels` as tables: 19 gated clauses (6, 6, 1, 1, 4, 1 per host), 11 hosted pairs, `SC_RS`'s two row differences |
| `W16Spec` | the block's tables are those relation tables read through encodings of the flat cubes, each encoding onto its product cube |
| **`w16Rels_of_algGood`** | **`AlgGood` and `W16Spec` give `W16Rels`** (all 34 fields), at a layout whose token and head-dimension axes do not pad |

### 2.5 `BlockAlgR13.lean`: `hgdR` at R13 (new in this session)

| Theorem / definition | Statement |
|---|---|
| `r13Cl`, `r13Count`, `r13Cl_count`, `r13Gh`, `r13Mm`, `r13RsA`, `r13RsB` | L17's `R13Rels` as tables: 35 gated clauses (`SC_TZC` 6, `SC_DZC` 13, `SC_QZC` 4, `SC_KVZC` 4, `SC_SZC` 5, `SC_FZC` 3: W16R2's plus the word, product-word and quotient decompositions), the 11 hosted pairs with the byte-limb sums `lv`, `SC_RS`'s two row differences |
| `R13Spec` | as `W16Spec`, for `R13Rels`'s tables |
| **`r13Rels_of_algGood`** | **`AlgGood` and `R13Spec` give `R13Rels`** (all 50 fields): L31's premise `hrels` discharged |
| **`block_knowledge_alg_r13_spec`**, **`block_knowledge_alg_r13_shield_spec`** | the R13 statements with `hrels` replaced by `R13Spec` and the two axes that do not pad |

### 2.6 `BlockAlgLk26.lean`: the app's block at LogUp's bound `2^26` (finding L36-1 repaired; new)

Generated by `l36_mk_lk26.py` from the existing theorems: each is its source's statement and proof with only the
lookup bound (`35153256` → `2 ^ 26`), LogUp's constant (`26370000` → `50331700`) and the cited theorems' names changed.

| Theorem | Statement |
|---|---|
| `lk_main_le_u126_26`, `lk_pos_le_u126_26` | LogUp's term per position for `e ≤ 2^26`: `(q + 1)·(50,331,700 + 2^15)/2^126` (L24's `lk_main_le_u126_r13`, in this namespace) |
| `shield_budget_r13_26`, `shield_budget_r13_26_val` | the Shieldstral block's budget with that term: `54,314,754 ≤ 2^26 = 67,108,864` |
| `block_knowledge_target_RN26`, `block_knowledge_open_r13_shieldN26`, `block_knowledge_final_r13_shield26` | L31's chain at `he ≤ 2^26` |
| **`block_knowledge_alg_r13_shield26`**, **`block_knowledge_alg_r13_shield_spec26`** | this lane's Shieldstral statements at `he ≤ 2^26` |

### 2.7 `BlockAlgLkR13.lean`, `BlockAlgLkW16.lean`: the lookup bridge `hbr` (deliverable 4, half; new)

| Theorem / definition | Statement |
|---|---|
| `tupK`, `tupK_injective` | a lookup tuple over `GF` read in `K` |
| `R13LookupsG`, `W16LookupsG`; `r13LookupsG_code`, `w16LookupsG_code` | the lookups' conclusion with the table predicate a parameter; at the block's table it IS `R13Lookups` / `W16Lookups` |
| `r13LookupsG_mono`, `w16LookupsG_mono`, `bytes_mono`, `bytesPin_mono` | monotone in the table predicate |
| `R13Query`, `W16Query`; `r13LookupsG_query`, `w16LookupsG_query`, `r13Query_of` | **the logical queries** of the lookups' conclusion (a tuple is one when some field asks it); every field's query is one |
| **`r13Lookups_of_queries`**, **`w16Lookups_of_queries`** | if every logical query is a table tuple, the lookups' conclusion holds |
| **`hbr_r13_of_cover`**, **`hbr_w16_of_cover`** | `hTtab` (every table entry is a table tuple) and `hcov` (every logical query is a lookup-list entry) give `hbr`'s conclusion (L21's `hbr_of_cover`) |

### 2.8 `BlockAlgFinal.lean`: the statements with the relation layers' algebra discharged

| Theorem | Statement |
|---|---|
| `card_K_gt`, `w16r2_rung_slot64`, `r13_rung_slot64`, `r13_shield_slot64` | a field over Goldilocks has more than 78 elements; every slot has fewer than 64 variables |
| **`alg_hvR`**, **`alg_hvH`** | `hvR` for `algSp` (layer 0 from the hosts' `FormAt`, layers 1 to 3 outright) and `hvH` for any helper polynomials with `FormAt` |
| **`block_knowledge_alg_w16r2`** | for EVERY `q`: `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend` at the W16R2 rung, with `spR`, `hdgR`, `hvR`, `hgdR` discharged and `hvH` reduced to `hformH` |
| `block_knowledge_alg_r13`, `block_knowledge_alg_r13_shield` | the same at R13, with `hgdR` reduced to `hrels` (now discharged in §2.5) |

### 2.9 `BlockAlgLkFinal.lean`: the block statements as far as this lane takes them (new)

Generated by `l36_mk_lkfinal.py`: each is its source's statement and proof with only `hbr` replaced by `hTtab` and
`hcov` (and the lambda that applies §2.7 to them) and the name changed.

| Theorem | Statement |
|---|---|
| **`block_knowledge_alg_w16r2_lk`** | the W16R2 rung block: `Pr[BlockAcc ∧ header ∧ ¬BlockSat] ≤ εsTarget q + εend` for every `q`, with `spR`, `hdgR`, `hvR`, `hgdR`, `hbr` discharged |
| **`block_knowledge_alg_r13_lk`** | the R13 rung block, the same, with the R13 reindexing included |
| **`block_knowledge_alg_r13_shield_lk26`** | **the media app's classifier block** (Shieldstral T128 R13), the same, at `he ≤ 2^26` |

### 2.10 `BlockAlgShapes.lean`, `BlockAlgSat.lean`: the shape facts, the lookup counts and the audit facts

| Theorem / definition | Statement |
|---|---|
| `hostedOf_hostsOf`, `ipStd`, `ipStd_inj`, `ipStd_lt`, `r13_host_layout`, `hostLay_w16`, `hostLay_r13`, `algShapeStd` | the hosts' draw lists have the layout `hostAt` needs, at every shape |
| **`algShapeW16Rung`**, **`algShapeR13Rung`**, **`algShapeR13Shield`** | `AlgShape` at the three profiles, for any pad plane counts of at most 78: every hypothesis decided on the recorded draw lists |
| `lkCount`, `perW16Rung`, `perR13Rung`, `perR13Shield`, **`lkCount_w16r2_rung`**, **`lkCount_r13_rung`**, **`lkCount_r13_shield`**, **`lkCount_r13_shield_gt`** | the block's looked-up tuples over the padded cubes: `1,015,808`, `2,015,232`, `64,258,048`; the last is above `35,153,256` and within `2^26` |
| **`w16r2_batch_room`**, **`r13_batch_room_rung`**, **`r13_batch_room_shield`** | each host's batch has room for the named clauses `W16Spec` / `R13Spec` place in it |
| **`shield_he26_room`**, `w16r2_he_room`, `r13_rung_he_room` | the lookup count plus twice the table domain's positions is within the bound `he` asks: `2^26` at the app's block, `35,153,256` at the rungs |

## 3. The numbers

| | W16R2 rung | R13 rung | Shieldstral T128 R13 (the app's block) |
|---|---|---|---|
| relation layers, slots per layer | 4; 9, 12, 2, 1 | the same | the same |
| largest degree (PROVED) | a host's `m + 2 ≤ 80`; `SC_RS` 2; the others 1 | the same | the same |
| named relations from the reindexing (PROVED) | 34 (`W16Rels`) | 50 (`R13Rels`) | 50 |
| clauses per host batch (PROVED room, MEASURED draws) | 6, 6, 1, 1, 4, 1 | 6, 13, 4, 4, 5, 3 | 6, 13, 4, 4, 5, 3 |
| `lt`, `lh`, `lq`, `lf`, `Dom::Ht` log, `Dom::S` column log (MEASURED) | 5, 4, 10, 10, 9, 5 | 5, 4, 10, 10, 9, 5 | 7, 5, 12, 14, 12, 7 |
| lookups per position `L, D, Q, Kv, S, F` (MEASURED) | 2, 19, 6, 6, 9, 7 | 2, 34, 14, 14, 17, 14 | 2, 34, 14, 14, 15, 14 |
| lookups over the padded cubes (PROVED on the MEASURED counts) | 1,015,808 | 2,015,232 | **64,258,048** |
| the bound `he` the statement takes | 35,153,256 | 35,153,256 | **`2^26` = 67,108,864** (`_lk26`; L36-1) |
| block budget, units of `2^-126` per query (PROVED) | 30,263,665 | 30,322,419 | **54,314,754** (was 30,353,054 at the unmeetable bound) |
| against `2^26` | within | within | within |

## 4. The premises that are left, by name

`block_knowledge_alg_r13_shield_lk26` (the app's block) takes L31's premises this lane does not touch: the profile
`hP : IsShieldR13 P tag rowsOf`; `aC`, `hC`, `hdc`, `hsA`, `hsH` (the commitment split); `hdrLen`, `hdrSq`, `hh`,
`hq`; `Poly`, `csE`, `hpolyC`, `hPoly`, `hdegP` (the tables part of the slot polynomials, lane L35); `Pb`, `Lay`,
`B`, `hW13`, `h24`, `xtE`; `q`, `A`, `hA`; `εend`, `hEnd` (the endpoint term, a run-level term). And this lane's:

| Premise | What it is | Kind |
|---|---|---|
| `sh : AlgShape P` | the shape facts | given by `algShapeR13Shield` (PROVED for any pad plane counts `≤ 78`); the pad plane counts are the layout's (L35) |
| `dt : AlgData K L sh` | the block's tables on the hosts' flat cubes | data; L35 builds it from the committed planes |
| **`hform`** | on every accepting outcome, each of the six hosts meets `FormAt` for `algSp`'s layer 0 | HYPOTHESIS, the join with L35 (below) |
| `enc`, `encHt`, **`hspec : R13Spec …`** | the tables are `R13Rels`'s relation tables through onto encodings | HYPOTHESIS; definitional once `dt` and `xtE` are built from the same planes (below) |
| `hTok`, `hHd` | the layout's token and head-dimension axes do not pad | HYPOTHESIS on the layout; MEASURED true at the three registered shapes (`pads = 0` for `T`, `S`, `Kv`) |
| `HGd`, `spH`, `hdgH`, **`hformH`**, `hgdH` | the helper layer: its polynomials, their degrees, their named identities, its claims | HYPOTHESIS (LEFT) |
| `Alk`, `T`, `mlk` | the lookup list, the table enumeration, the multiplicities | data; L35 / the next lane |
| `hN` | `card ι + 2·card π < ringChar K` | HYPOTHESIS; true for any list of the code's size (`< 2^26 < p`) |
| `he` | `card ι + 2·card π + 2·|T| ≤ 2^26` | HYPOTHESIS; meetable at the code's sizes (`shield_he26_room`, PROVED on MEASURED counts) |
| **`hTtab`** | every table entry is (the image of) a tuple of `CodeTable r13Fams …` | HYPOTHESIS; ARGUED true of the code (§5) |
| **`hcov`** | on every outcome, every logical query of `R13Lookups` at the extracted planes is an entry of `Alk` at the A cut | HYPOTHESIS; ARGUED true of the code's lookup list (§5) |
| **`hhr`** | on every outcome with the helper claims, helper values with LogUp's relations exist | HYPOTHESIS (LEFT, unchanged from L31) |

The W16R2 rung's `block_knowledge_alg_w16r2_lk` takes the same with `IsRungW16`, `fams`, `hF`, `hW`, `W16Data`,
`W16Spec` and `CodeTable fams …` in `hTtab`, `W16Query` in `hcov`, and `he ≤ 35,153,256`. The R13 rung's
`block_knowledge_alg_r13_lk` takes the same as the app's block with `IsRungR13` and `he ≤ 35,153,256`.

Gone, against L31's `block_knowledge_final_*`: `spR`, `hdgR`, `hvR`, `hgdR` (built or proved), `hvH` (now `alg_hvH`
from `hformH`), `hbr` (now `hTtab`, `hcov`), and at the app's block the unmeetable `he ≤ 35,153,256`.

**The join with lane L35, premise by premise.**
1. **`hform`.** `formAt_host` reduces it, per host `k` and outcome, to four facts:
   - `P.kind k = SlotKind.host`, and no hosted slot of `df.hosted` is a host (facts of the concrete `BlockParams`);
   - the host's unmasked sum is its named sum: `spSum … k = mleAt (batched (dt.cl k …) (dt.pw k …) ω) τ + Σ_i ν_i ·
     mleAt (algH … i) (algPt … i)`, with `ω`, `τ`, `ν` the segments of the host's draws that `hostSp_Φ` names;
   - the hosted list's weighted sums are the hosted named sums: `(df.hosted.map (κ·spSum)).sum = Σ_i ν_i · mleAt
     (algM … i) (algPt … i)`;
   - then `hostSp_Φ` and `hostPhi_of_sums` give `hostSp.Φ(draws) = (named sum) − (hosted named sums)`.
   What L35 supplies for the two sums: `Poly` on the Boolean cube as the slot's IR over the true tables. From there:
   L13's `*Ir_eval`, `hostTerms_hostPoly`, `host_cubeSum`, `matmul_sum` and `mleAt_append`, `rs_cubeSum` and
   `rs_host_cubeSum` with this lane's `mleAt_rowOnly`, and the extension variables vanishing off `e = 0`. `hPoly`
   alone does not give these sums (finding L36-2).
2. **`dt` and `hspec`.** When the tables are built as: clause `j` of host `k` the pullback of `relCl` / `r13Cl … k j`
   (anywhere in the host's batch), `gh` and `mm` the pullbacks of `relGh` / `r13Gh`, `relMm` / `r13Mm`, `rsA` and
   `rsB` those of the row differences, the fields of `W16Spec` / `R13Spec` hold by definition, and what remains is
   that the cube encodings are onto (the axes' index maps; L13 item 2). The work is then inside item 1: showing the
   code's cube sums are those of the pullbacks.
3. **`hTtab`, `hcov`** (the lookup list and the table as the code's: `lookups_w16`, `AccuracyIds::lookups`), and
   **the helper layer** with `hhr` (the helper columns' relations from the hosts' and `SC_TAB`'s clauses, the sum
   claim): the next lane, with L35's plane allocation.

## 5. Can the premises be met? (the audit)

A premise no real block can meet makes the statement say nothing (finding L31-1's pattern). This lane's premises, one
by one, at the Shieldstral T128 R13 block:

| Premise | Can it be met at the real block? |
|---|---|
| `sh` (`AlgShape`) | YES for pad plane counts `≤ 78`, PROVED (`algShapeR13Shield`). The real counts: ARGUED at most 39 per host (the D domain carries 39 A planes at R13: 7 words, 14 word limbs, 12 norm-remainder limbs, 6 shift-remainder limbs; the zero rule acts on A planes only, the LogUp helpers are exempt, pad.rs:387-403); NOT checked against an export (no corpus records the pad planes per host at R13) |
| `hform` | YES if `dt` and `Poly` are built from the same committed planes: it is an algebraic identity of the host's IR (L13's host form), with no probability in it; it does not ask anything at challenges outside the slot's own draws (the L31-1 trap: checked, `FormAt` reads the slot's own draws `r.draws` only) |
| `hspec` (`W16Spec` / `R13Spec`) | YES if the product cubes are the padded index types and the encodings are bijections: every gated clause and gated hosted term is `0` at a padded position on both sides; the ungated `SC_TZC` clauses live on `Dom::T`, which does not pad. The batches have room for the clauses: PROVED (`r13_batch_room_shield`, `r13_batch_room_rung`, `w16r2_batch_room`) |
| `hTok`, `hHd` | YES at the registered shapes: MEASURED `pads = 0` for `T`, `S`, `Kv` (L17's shape corpus) |
| `he` | at `35,153,256`: NO at the Shieldstral block (finding L36-1; `lkCount_r13_shield_gt`). At `2^26`: YES (`shield_he26_room`: `64,258,048 + 2·3·2^14 ≤ 2^26`) |
| `hN` | YES (`< 2^26 < p`) |
| `hTtab` | YES, ARGUED: the u8 and exp columns repeat their rows `i mod 256` over the table domain (`table_values_u8_at`, `table_values_exp_at`, argument.rs:1953-1961), and the ACT column's padding rows are group 0's row at `i = 2048` (accuracy_act.rs; `ActTable`'s note) |
| `hcov` | YES, ARGUED: the code's list (`AccuracyIds::lookups`, accuracy_layout.rs:218-280) is what L17 read `R13Lookups` from, and it runs over the padded cubes, so it contains every logical position's queries. It needs the looked-up planes of `xtE` to be read from the A commitment's cut, which `Alk`'s argument is (D54: the lookups read words of `A`) |
| `hhr`, the helper layer | not examined beyond L21/L23's statement of them (LEFT) |

## 6. Findings

No statement of `Statements.lean` changed. No target weakened. No earlier lane's file changed.

**L36-1 (High for the Lean chain at the app's block; for the coordinator. Not a protocol weakness. REPAIRED here at
the block level): the block statements' lookup bound `he` cannot be met at the Shieldstral T128 R13 block.**
- Every block statement since L21 (`block_knowledge_target_mt`), at R13 from L23's `block_knowledge_target_r13` to
  L31's `block_knowledge_final_r13_shield`, takes `he : card ι + 2·card π + 2·|T| ≤ 35,153,256`, the 8B T128 W16R2
  block's count (L3).
- The Shieldstral T128 R13 block looks up `2·2^14 + 34·2^19 + 14·2^19 + 14·2^17 + 15·2^19 + 14·2^21 = 64,258,048`
  tuples (PROVED: `lkCount_r13_shield`, on per-position counts and domain sizes MEASURED on L17's shape corpus; it is
  D54's "64.3 M words"). R13 looks up two bytes per 16-bit word, and LogUp's arm runs over the padded cubes.
- So L31's `block_knowledge_final_r13_shield` holds vacuously for the code's lookup list. That a shorter list cannot
  meet `hbr` and `hhr` together is ARGUED: `hhr` asks for helpers of exactly the listed lookups whose sum closes
  against the table, and the code's helper columns sum over every position.
- Repaired: `BlockAlgLk26.lean` re-proves the Shieldstral chain at `he ≤ 2^26` with L24's LogUp constant; the block
  budget is `54,314,754 ≤ 2^26` (PROVED). The repaired statements are `block_knowledge_final_r13_shield26`,
  `block_knowledge_alg_r13_shield26`, `_spec26` and `block_knowledge_alg_r13_shield_lk26`. Cite those at the app's
  block; L31's `block_knowledge_final_r13_shield` should not be cited there.
- NOT affected: the two rungs (`1,015,808` and `2,015,232` lookups); the run-level chain, which already takes LogUp at
  `e ≤ 2^26` (L24's `lk_main_le_u126_r13`, L27's `lin_lk_r13`, L30's `eleven_bud_r13`).

**L36-2 (Medium; for L35 and the coordinator): `hPoly` does not determine the slot polynomials where the algebra
reads them.** `hPoly` (`SlotEvalN`) pins `Poly` at ONE point per accepted slot, the sumcheck's. The per-outcome
algebra needs each slot's cube sum, which reads `Poly` on the whole Boolean cube. So `hvR`'s layer 0 cannot be proved
from `Poly`, `hPoly`, `hdegP` as premises; it needs `Poly`'s definition. This lane states the fact it needs (`hform`,
`FormAt`) and proves everything around it.

**L36-3 (Low; for the next lane): the standalone zero-checks carry no relation of `W16Rels` / `R13Rels`.** `SC_LZC`,
`SC_TAB` and `SC_ZS` (in layer 0's slot list) prove only LogUp's helper relations. In the relation layers their
certified polynomial is the trivial one, so `hform` is asked of the six hosts only. They belong to the helper layer
(`spH`), which is LEFT.

**L36-4 (Low; for the next lane): two fields of `W16Rels` / `R13Rels` do not follow from the gates of `W16Pub`.**
`pp_pad` and `kr_pad` say a plane vanishes at a padded token or head-dimension index. `W16Pub` records the pad
behaviour of the `D` and `S` gates only. At the registered shapes neither axis pads (MEASURED), so the fields are
empty; the reindexing takes that as `hTok`, `hHd`. A shape that pads tokens would need the pad-zero planes of `SC_SZC`
and `SC_KVZC` and one more gate fact.

**L36-5 (Info): `SC_SZC`'s hosted `SC_RS` term needs no special point.** L23-4 suggested the column coordinates at
`1/2`. Any column point works (`mleAt_rowOnly`). The instance uses `s = 0` and carries the factor `2^b` in `rsScale`.

**L36-6 (Info): two exports of the W16R2 rung differ in their range sub-planes.** L17's shape corpus has
`n_range = 13`, `a_rows = 317` for the W16R2 rung; L9's corpus (L23's `shRungW16`, L31's `IsRungW16`) has 14 and 320.
The range families depend on the export's calibration (A25). This lane reads the hosts' draw lists only, which do not
depend on it; `BlockAlgCheck` compares the logs, helper counts and lookups, which agree.

**L36-7 (Info, method).** `rw [lemma] at h` rewrites the first match, which may be on the wrong side; a `calc` or
`Eq.trans` with the stated sides is safer. `decide` proves a bounded `∀ k ∈ list` over the draw lists.

**L36-8 (Info; for the coordinator and L35): a declaration name was shared with lane L35.** This lane's
`ZK60.Exec.Block.drawAt` (and `drawAt_hist`) clashed with L35's `drawAt` in `BlockDefineSym.lean` (the scan found it
on the first full check). This lane renamed its own to `algDrawAt`, `algDrawAt_hist`; the second scan finds no clash.
A later rename on L35's side would reopen it only if L35 adds an `algDrawAt`.

## 7. What is left

In the brief's order:
1. **The certified slot polynomials** `spR`, `hdgR`: done (`algSp`, `algSp_dg`). `spH`, `hdgH`: LEFT (the helper
   layer; the hosts' polynomials can be reused, `SC_LZC`, `SC_TAB`, `SC_ZS` need L23's `lzc`, `zc`, `zs`).
2. **`hvR`**: done from `hform` (layer 0) and outright (layers 1 to 3). **`hvH`**: done from `hformH`. LEFT: `hform`,
   `hformH` (the join of §4 item 1).
3. **`hgdR`**: done at W16R2 from `W16Spec` and at R13 from `R13Spec`. **`hgdH`**: LEFT.
4. **The lookup side**: `hbr` done from `hTtab` and `hcov`; `hN`, `he` meetable (`he` repaired at the app's block).
   LEFT: `Alk`, `T`, `mlk` as the code's lists, `hTtab` and `hcov` for them, and `hhr` with the helper layer.
5. **The final theorems**: `block_knowledge_alg_w16r2_lk`, `block_knowledge_alg_r13_lk`,
   `block_knowledge_alg_r13_shield_lk26` (§2.9).
6. **Checks against the corpora**: `BlockAlgCheck` (§8).

What the next lane needs, concretely: L35's `define`, `Poly` and plane allocation; then (a) the six hosts' named sums
(§4 item 1), slot by slot with L13's `*Ir_eval`; (b) the tables as pullbacks (`hspec` by definition); (c) the lookup
list and the table as the code's (`hTtab`, `hcov`), the helper layer and `hhr`.

## 8. Checks

`results/zk60_lean_l36_20261109/check_l36.sh`, run as the last step of iteration 9 (one guarded cpu job, exit 0,
77 s with the build of `BlockAlgSat`, peak 3.77 GiB), on the lane's tree merged with perf `2155ede8`. Log: `check.log`
(the earlier runs: `check_run1_clash.log`, the six first modules, green but for the name clash of L36-8; and a run on
eleven modules, green). MEASURED:

| Check | Result |
|---|---|
| each of the twelve L36 modules built alone | rc 0, no warning |
| full `lake build` | 3,641 jobs, rc 0, 0 warnings, 0 errors, no `sorry` |
| axiom audit (`axioms_l36.lean`, every declaration of the twelve files) | 145 declarations (94 theorems, 44 definitions, 7 structures); 106 on `propext, Classical.choice, Quot.sound`, 12 on `propext, Quot.sound`, 20 on `propext`, 7 on none; 0 `sorryAx`, 0 `ofReduceBool`, 0 other |
| source scan (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`) | none |
| root imports | the twelve modules, not the checker |
| unchanged since the base `2155ede8` | `Statements.lean`; every existing Lean file (0 modified); no import line removed; no file under `ops/` |
| name clashes over 46 worktrees | 0 (after the `algDrawAt` rename, L36-8) |
| `BlockAlgCheck` on L17's committed shape corpus | 56 checks, 0 failed |
| its negative control (five single changes to a copy of the corpus, outside the repository) | exactly the 7 expected failures |
| regressions | L6Check 1,206, L5Check 5,553, L11Check 404, fixture L1 101,956: 0 failed |

The two generated files are reproduced by `python3 -I results/zk60_lean_l36_20261109/l36_mk_lk26.py formal/ZK60Formal`
and `python3 -I results/zk60_lean_l36_20261109/l36_mk_lkfinal.py formal/ZK60Formal` (each substitution asserts its
expected count of matches).
