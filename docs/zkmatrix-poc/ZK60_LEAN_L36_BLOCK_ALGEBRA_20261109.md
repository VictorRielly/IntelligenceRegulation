# D63 lane L36: the block's algebra. The certified slot polynomials, their vanishing on acceptance, and the reindexing to the named relations (2026-11-09)

Lean lane L36 (Claude), on its own worktree at perf `192ccef5` (L9 to L31 and L33 merged). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. Six new library files under `formal/ZK60Formal/`, imported by the library root:
`BlockAlgUnmask.lean`, `BlockAlgKinds.lean`, `BlockAlgInst.lean`, `BlockAlgRels.lean`, `BlockAlgFinal.lean`,
`BlockAlgShapes.lean`. One checker, `BlockAlgCheck.lean`, not imported by the root. No Rust. `Statements.lean` and
every existing Lean file are unchanged. Evidence: `results/zk60_lean_l36_20261109/`.

**STATUS: deliverables 1, 2 and 3 done for the relation layers (deliverable 2's layer 0 and deliverable 3 up to
named premises that join lane L35, §4); deliverable 4 (the lookup side) NOT done, except the lookup counts and one
finding; deliverable 5 done in the form of §2.5 (the premises that remain are listed in §4).**

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**MEASURED** (read off the code's registered shapes and checked by `BlockAlgCheck`), **ESTIMATE** (arithmetic on
bounds, not a Lean theorem), **ARGUED** (a reasoned claim, not a Lean theorem), **HYPOTHESIS** (a named premise, with
the shape a later lane must prove), **LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** Lane L31 left the security statement of ONE transformer block in this form: "the
chance that the block verifier accepts while the committed data breaks the block's equations is at most your
target", given a list of facts about the block's algebra. This lane was to prove that list. The list had four parts:
the block's 23 slot identities written as polynomials of the verifier's random challenges; the fact that these
polynomials are zero on every accepted proof; the fact that "all of them identically zero" means the block's named
equations hold; and the lookup tables' side.

**What is now proved.**
1. **The slot polynomials are built** (PROVED). For all three block profiles (the W16R2 test rung, the R13 test rung,
   the Shieldstral T128 R13 block the media app runs) the polynomials of the four "relation layers" are constructed
   in Lean from the block's tables, with their degrees (at most 80) and with the property the security argument
   needs (a polynomial that is identically zero forces its claim).
2. **They are zero on every accepted proof.** PROVED outright for three of the four layers. For the first layer (the
   six "host" slots) it is PROVED from one named fact per host: "this slot's sum, without its mask, is the slot's
   named formula". That fact needs lane L35's definition of the slot polynomials, which is being written beside this
   lane; it is stated here in the form L35 can prove (§4).
3. **"All claims hold" gives the block's named equations** (PROVED at W16R2): once every slot polynomial's claim
   holds, the 34 named relations of the layout theorem hold on the committed data. This is the step lane L23 called
   the reindexing. At R13 this step is left as one named premise (§4).
4. **The three block statements are restated with the above removed** (`block_knowledge_alg_w16r2`,
   `block_knowledge_alg_r13`, `block_knowledge_alg_r13_shield`). §4 lists every premise they still take.
5. **The shape facts the proofs read are true of the code's schedules** (PROVED, and checked against the code's
   registered shapes): the statements are not empty in that part.

**One finding needs your attention (L36-1, High for the Lean chain at the app's block; not a protocol weakness).**
The block statement for the Shieldstral T128 R13 block (the app's block) assumes that the block makes at most
35,153,256 table lookups. That number was counted for the 8B W16R2 block. The Shieldstral R13 block makes
**64,258,048** lookups (your D54 figure, 64.3 M), so that assumption cannot be met there, and the block statement at
that profile says nothing as written. The run-level statements (lanes L24, L27, L30) are NOT affected: they already
use the larger bound `2^26`. With the larger bound the block still fits your target (about 54.3 of 67.1 million
budget units, ESTIMATE). The repair is a re-statement of one block theorem with the larger bound; it is not done
here (§5).

**What is not done** (§6). The lookup side: the list of looked-up values as the code's, the proof that a failing
lookup is a value outside the table, and the helper columns' relations. And the two joins with lane L35: the six
hosts' named sums, and the R13 reindexing.

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (§7).

### 2.1 `BlockAlgUnmask.lean`: the unmasking on an accepting outcome, and a layer's vanishing from named identities (any block shape)

| Theorem / definition | Statement |
|---|---|
| `spSum` | a slot's unmasked cube sum `Σ_b Poly_k(b)` at an outcome |
| **`accT_unmask`** | on an accepting outcome (`AccT`, `F = Poly + c·mask`): every verified slot has a definition; a standalone slot's unmasked sum is `0`; a host's (hosted slots not hosts) is `Σ_h κ_h·(slot h's unmasked sum)`. It is L23's `unmask_slots` with every premise discharged from `AccT` (`claimed_unmasked`, `OpenTrue`, `blockSlots_fns`) |
| `FormAt` | **the named identity of slot `k`**: its certified polynomial at the drawn challenges is the slot's unmasked residual (`Σ Poly_k` for a standalone slot, `Σ Poly_k − Σ_h κ_h·Σ Poly_h` for a host) |
| **`schedVan_of_form`** | a define schedule whose slots meet `FormAt` vanishes at the drawn challenges of every accepting outcome (`SchedVan`): `hvR`'s layer 0, and `hvH` |

### 2.2 `BlockAlgKinds.lean`: the slot kinds' algebra (any block shape)

| Theorem / definition | Statement |
|---|---|
| `mleAt_one`, `mleAt_castCube`, **`mleAt_rowOnly`**, `mleAt_lin2`, `append_cast_ite` | the multilinear extension of `1` is `1`; of a function through a relabelling of the cube; of a function of the first block of coordinates only (its value at `(p, s)` is its value at `p`, whatever `s`); linearity; a two-block claim point read coordinate by coordinate |
| `segAt`, **`hostAt_Gd`**, **`hostAt_dg`**, **`hostAt_Φ`** | L23's host polynomial on its draw vector: its start claim is `hostGd`, its degree `m + 2`, and at a vector it is `hostPhi` at the segments' entries (`ζ`, `μ_pad` only where the slot pads) |
| **`hostPhi_of_sums`** | a host's identity is (its named sum `Z̃(τ) + Σ_i ν_i·h̃_i(p_i)`) minus (its hosted slots' named sums `Σ_i ν_i·M̃_i(p_i)`) |
| **`priv_van`**, **`part_van`**, **`rs_van`**, **`cross_van`** | a private slot's polynomial at its drawn point is `0` once its host's hosted difference at that point is `0`, for the four ways a W16R2 claim point is made: the slot's own draws in any order; an earlier slot's coordinates then its own (`SC_KMM`, `SC_VMM`, `SC_UMM`); `SC_RS` (its row point, then `λ`, hosted by `SC_SZC` on the larger cube of `Dom::S` with the scale `2^b`); the drawing slot's layer of finding L23-2 |
| `part_pointwise` | the drawing slot's start claim gives the hosted identity at every cube point |

### 2.3 `BlockAlgInst.lean`: the certified slot polynomials of a W16R2-family block (`spR`, `hdgR`, `hvR` layers 1 to 3)

| Theorem / definition | Statement |
|---|---|
| `algHosts`, `hostedOf`, `partSrc`, `HostLay` | the six hosts, the private slot each hosts at `ν_i` (L11's `hostsOf`), the slot a split claim point starts with |
| `AlgShape` | the shape facts read off the draw schedule: the hosts' draw lists, pad plane counts (at most 78), where each hosted claim point sits in the draws, the cube splits |
| `AlgData` | the block's tables on the hosts' flat cubes: batched clauses `cl` (at `β, γ, α`), pad planes `pw`, each hosted pair's gated host term `gh` and contraction `mm`, `SC_RS`'s row differences `rsA`, `rsB`, the scale `2^b` |
| `drawAt`, `algLam`, `algH`, `algM`, `algPt`, `partD` | a host's hosted functions and claim points read off the history (L11's `claimPoint`) |
| `hostSp`, `privSp`, `partSp`, `rsSp`, `crossSp5`, `crossSp11`, **`algSp`** | **`spR`**: the certified polynomials by layer and slot (L23 §3's table), built with L23's constructors |
| **`algSp_dg`** | **`hdgR`**: every degree is at most `80` |
| `hostSp_Gd`, `hostSp_dg`, **`hostSp_Φ`** | a host's start claim, degree, and its polynomial at a draw vector, over the block's tables |
| `host_gd_of_sched`, `privSp_van`, `partSp_van`, `rsSp_van`, `crossSp5_van`, `crossSp11_van` | the links by kind on an outcome |
| **`algSp_van1`**, **`algSp_van2`**, **`algSp_van3`** | **`hvR` for layers 1, 2, 3**: each layer vanishes at the drawn challenges once the layers below hold their start claims. No further premise |
| `AlgGood`, **`algGood_of_gd`** | all four layers' start claims say: every host's clauses and pad planes vanish on its cube, every hosted identity `gh = mm` holds at every cube point, `rsA` and `rsB` vanish (the generic half of `hgdR`) |
| **`formAt_host`** | a host's `FormAt` from: its kind, its hosted slots not being hosts, and its polynomial at the draws being (named sum) − (hosted named sums) |

### 2.4 `BlockAlgRels.lean`: `hgdR` at W16R2

| Theorem / definition | Statement |
|---|---|
| `W16Pos` | a position of one of the seven padded product cubes |
| `relCl`, `relCount`, `relCl_count`, `relGh`, `relMm`, `relRsA`, `relRsB` | L11's `W16Rels` as tables on those positions: 19 gated clauses (6, 6, 1, 1, 4, 1 per host), 11 hosted pairs, `SC_RS`'s two row differences |
| `W16Spec` | the block's tables are those relation tables read through encodings of the flat cubes, each encoding onto its product cube |
| **`w16Rels_of_algGood`** | **`AlgGood` and `W16Spec` give `W16Rels`** of the extracted planes (all 34 fields), at a layout whose token and head-dimension axes do not pad |

### 2.5 `BlockAlgFinal.lean`: the statements

| Theorem | Statement |
|---|---|
| `card_K_gt`, `w16r2_rung_slot64`, `r13_rung_slot64`, `r13_shield_slot64` | a field over Goldilocks has more than 78 elements; every slot has fewer than 64 variables |
| **`alg_hvR`**, **`alg_hvH`** | `hvR` for `algSp` (layer 0 from the hosts' `FormAt`, layers 1 to 3 outright) and `hvH` for any helper polynomials with `FormAt`, generic in the profile |
| **`block_knowledge_alg_w16r2`** | for EVERY `q`: `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend` at the W16R2 rung, with `spR`, `hdgR`, `hvR`, `hgdR` discharged and `hvH` reduced to `hformH` |
| **`block_knowledge_alg_r13`**, **`block_knowledge_alg_r13_shield`** | the same at the R13 rung and at the Shieldstral T128 R13 block, with `spR`, `hdgR`, `hvR` discharged, `hgdR` reduced to `hrels`, `hvH` reduced to `hformH` |

### 2.6 `BlockAlgShapes.lean`: the shape facts and the lookup counts

| Theorem / definition | Statement |
|---|---|
| `hostedOf_hostsOf` | the hosted pairs are L11's `hostsOf` |
| `ipStd`, `ipStd_inj`, `ipStd_lt` | where a hosted claim point's coordinates sit in the hosted slot's draws: draw order, except `SC_PV` (draws `(r_h, r_t, r_i)`, publishes `(r_t, r_h, r_i)`) |
| `r13_host_layout`, `hostLay_w16`, `hostLay_r13`, `algShapeStd` | the hosts' draw lists have the layout `hostAt` needs, at every shape |
| **`algShapeW16Rung`**, **`algShapeR13Rung`**, **`algShapeR13Shield`** | `AlgShape` at the three profiles, for any pad plane counts of at most 78 (none where a host draws no `ζ`): every hypothesis decided on the recorded draw lists |
| `lkCount`, `perW16Rung`, `perR13Rung`, `perR13Shield`, **`lkCount_w16r2_rung`**, **`lkCount_r13_rung`**, **`lkCount_r13_shield`**, **`lkCount_r13_shield_gt`** | the block's looked-up tuples over the padded cubes: `1,015,808`, `2,015,232`, `64,258,048`; the last is above `35,153,256` and within `2^26` |

## 3. The numbers

| | W16R2 rung | R13 rung | Shieldstral T128 R13 (the app's block) |
|---|---|---|---|
| relation layers, slots per layer | 4; 9, 12, 2, 1 | the same | the same |
| certified polynomials built (`algSp`) | 6 hosts, 12 private, 3 drawing-slot layers; 3 trivial (`SC_LZC`, `SC_TAB`, `SC_ZS`) | the same | the same |
| largest degree (PROVED) | a host's `m + 2 ≤ 80` (`m` its pad planes, at most 78); `SC_RS` 2; the others 1 | the same | the same |
| `lt`, `lh`, `lq`, `lf`, `Dom::Ht` log, `Dom::S` column log (MEASURED) | 5, 4, 10, 10, 9, 5 | 5, 4, 10, 10, 9, 5 | 7, 5, 12, 14, 12, 7 |
| lookups per position `L, D, Q, Kv, S, F` (MEASURED) | 2, 19, 6, 6, 9, 7 | 2, 34, 14, 14, 17, 14 | 2, 34, 14, 14, 15, 14 |
| lookups of the block over the padded cubes (PROVED arithmetic on the MEASURED counts) | 1,015,808 | 2,015,232 | **64,258,048** |
| against `he`'s bound 35,153,256 | within | within | **above** (L36-1); within `2^26 = 67,108,864` |

The block budgets are L31's (unchanged by this lane): 30,263,665, 30,322,419 and 30,353,054 of `2^26` units. At the
Shieldstral T128 R13 block the last figure charges LogUp for 35,153,256 lookups; with `2^26` lookups LogUp's term is
L24's `50,331,700 + 2^15` units instead of `26,370,000 + 2^15`, and the block total would be `54,314,754 ≤ 2^26`
(ESTIMATE; L36-1).

## 4. The premises that are left, by name

`block_knowledge_alg_w16r2` takes L31's premises that this lane does not touch (the profile `hP`; `aC`, `hC`, `hdc`,
`hsA`, `hsH`; `hpolyC`; `Poly`, `hPoly`, `hdegP`; `hh`, `hq`; `csE`, `εend`, `hEnd`; `Pb`, `Lay`, `B`, `h24`, `fams`,
`hF`, `hW`; `xtE`), and:

| Premise | What it is | Kind |
|---|---|---|
| `sh : AlgShape P` | the shape facts | given by `algShapeW16Rung` (PROVED for any pad plane counts `≤ 78`); the pad plane counts are the layout's (L35) |
| `dt : AlgData K L sh` | the block's tables on the hosts' flat cubes | data; L35 builds it from the committed planes |
| **`hform`** | on every accepting outcome, each of the six hosts meets `FormAt` for `algSp`'s layer 0 | HYPOTHESIS, the join with L35 (below) |
| `enc`, `encHt`, **`hspec : W16Spec …`** | the tables are `W16Rels`'s relation tables through onto encodings | HYPOTHESIS; definitional once `dt` and `xtE` are built from the same planes (below) |
| `hTok`, `hHd` | the layout's token and head-dimension axes do not pad | HYPOTHESIS on the layout; MEASURED true at the three registered shapes (`pads = 0` for `T`, `S`, `Kv`; L36-4) |
| `HGd`, `spH`, `hdgH`, **`hformH`**, `hgdH` | the helper layer: its polynomials, their named identities, its claims | HYPOTHESIS (LEFT, the lookup side) |
| `Alk`, `T`, `mlk`, `hN`, `he`, `hbr`, `hhr` | the lookup list, the table, the multiplicities, the counts, the lookup bridge | HYPOTHESIS (LEFT, unchanged from L31) |

Gone, against L31's `block_knowledge_final_w16r2`: `spR`, `hdgR`, `hvR`, `hgdR` (built or proved), and `hvH` (now
`alg_hvH` from `hformH`).

`block_knowledge_alg_r13` and `block_knowledge_alg_r13_shield` take the same with `hW13` for `fams`, `hF`, `hW`, and,
in place of `enc`, `encHt`, `hspec`, `hTok`, `hHd`:

| Premise | What it is | Kind |
|---|---|---|
| **`hrels`** | `∀ cu rt bga, AlgGood sh dt cu rt bga → R13Rels S Pb Lay B (xtE cu rt)` | HYPOTHESIS: the R13 reindexing (LEFT). It is a statement about tables only: no probability, no outcome |

**The join with lane L35, premise by premise.**
1. **`hform`.** `formAt_host` reduces it, per host `k` and outcome, to four facts:
   - `P.kind k = SlotKind.host`, and no hosted slot of `df.hosted` is a host (facts of the concrete `BlockParams`);
   - the host's unmasked sum is its named sum: `spSum … k = mleAt (batched (dt.cl k …) (dt.pw k …) ω) τ + Σ_i ν_i ·
     mleAt (algH … i) (algPt … i)`, with `ω`, `τ`, `ν` the segments of the host's draws that `hostSp_Φ` names;
   - the hosted list's weighted sums are the hosted named sums: `(df.hosted.map (κ·spSum)).sum = Σ_i ν_i · mleAt
     (algM … i) (algPt … i)`;
   - then `hostSp_Φ` and `hostPhi_of_sums` give `hostSp.Φ(draws) = (named sum) − (hosted named sums)`.
   What L35 supplies for the two sums: `Poly` on the Boolean cube as the slot's IR over the true tables. From there:
   L13's `*Ir_eval` (the IR's named form), `hostTerms_hostPoly`, `host_cubeSum` (a host's cube sum), `matmul_sum`
   and `mleAt_append` (a private matmul's sum is the contraction's extension at its claim point), `rs_cubeSum` and
   `rs_host_cubeSum` with this lane's `mleAt_rowOnly` (`SC_RS` and its hosted term), and the extension variables
   vanishing off `e = 0`. `hPoly` alone does not give these sums (finding L36-2).
2. **`dt` and `hspec`.** When the tables are built as: clause `j` of host `k` the pullback of `relCl … k j`
   (`W16Rels`'s order, anywhere in the host's batch), `gh` and `mm` the pullbacks of `relGh`, `relMm`, `rsA` and `rsB`
   those of `relRsA`, `relRsB`, the fields of `W16Spec` hold by definition, and what remains of it is that the cube
   encodings are onto (the axes' index maps; L13 item 2). The work is then inside item 1: showing the code's cube
   sums are those of the pullbacks.
3. **`hrels`** (R13): `R13Rels`'s relations as tables, as §2.4 does for `W16Rels`.

## 5. Findings

No statement of `Statements.lean` changed. No target weakened. No earlier lane's file changed.

**L36-1 (High for the Lean chain at the app's block; for the coordinator. Not a protocol weakness): the block
statements' lookup bound `he` cannot be met at the Shieldstral T128 R13 block.**
- Every block statement since L21 (`block_knowledge_target_mt`), at R13 from L23's `block_knowledge_target_r13` to
  L31's `block_knowledge_final_r13_shield` (and this lane's `block_knowledge_alg_r13_shield`), takes
  `he : card ι + 2·card π + 2·|T| ≤ 35,153,256`. The number is the 8B T128 W16R2 block's (`N = 34,897,920`, L3).
- The Shieldstral T128 R13 block looks up `2·2^14 + 34·2^19 + 14·2^19 + 14·2^17 + 15·2^19 + 14·2^21 = 64,258,048`
  tuples (PROVED: `lkCount_r13_shield`; the per-position counts and domain sizes are MEASURED on L17's shape corpus;
  it is D54's "64.3 M words"). R13 looks up two bytes per 16-bit word, and LogUp's arm runs over the padded cubes.
- So a lookup list that covers the block's lookups has `card ι + 2·card π = 64,258,048 > 35,153,256`, and `he` is
  false for it. That a shorter list cannot meet `hbr` and `hhr` together is ARGUED: `hhr` asks for helpers of
  exactly the listed lookups whose sum closes against the table, and the helper columns sum over every position.
  The statement at this profile therefore holds vacuously for the code's lookup list.
- NOT affected: the two rungs (`1,015,808` and `2,015,232` lookups); the run-level chain, which already takes
  LogUp at `e ≤ 2^26` (L24's `lk_main_le_u126_r13`, L27's `lin_lk_r13`, L30's `eleven_bud_r13`).
- The repair: the R13 block theorem with `he ≤ 2^26` and L24's LogUp constant. The budget then reads
  `30,353,054 − 26,402,768 + 50,364,468 = 54,314,754 ≤ 2^26` (ESTIMATE). It needs `block_knowledge_target_gen`,
  `block_knowledge_open_r13_shieldN` and the final statement re-stated with that constant (the proofs are the
  existing ones; L31's generator scripts show the method). Not done here.

**L36-2 (Medium; for L35 and the coordinator): `hPoly` does not determine the slot polynomials where the algebra
reads them.** `hPoly` (`SlotEvalN`) pins `Poly` at ONE point per accepted slot, the sumcheck's. The per-outcome
algebra needs each slot's cube sum, which reads `Poly` on the whole Boolean cube. So `hvR`'s layer 0 cannot be proved
from `Poly`, `hPoly`, `hdegP` as premises; it needs `Poly`'s definition. This lane states the fact it needs
(`hform`, `FormAt`) and proves everything around it.

**L36-3 (Low; for the next lane): the standalone zero-checks carry no relation of `W16Rels`.** `SC_LZC`, `SC_TAB`
and `SC_ZS` (in layer 0's slot list) prove only LogUp's helper relations. In the relation layers their certified
polynomial is the trivial one, so `hform` is asked of the six hosts only. They belong to the helper layer
(`spH`), which is LEFT.

**L36-4 (Low; for the next lane): two fields of `W16Rels` do not follow from the gates of `W16Pub`.** `pp_pad` and
`kr_pad` say a plane vanishes at a padded token or head-dimension index. `W16Pub` records the pad behaviour of the
`D` and `S` gates only. At the registered shapes neither axis pads (MEASURED, `pads = 0` for `T`, `S`, `Kv`), so the
fields are empty; `w16Rels_of_algGood` takes that as `hTok`, `hHd`. A shape that pads tokens would need the
pad-zero planes of `SC_SZC` and `SC_KVZC` and one more gate fact.

**L36-5 (Info): `SC_SZC`'s hosted `SC_RS` term needs no special point.** L23-4 suggested the column coordinates at
`1/2`. Any column point works: a function of the row coordinates only has the same extension at `(p, s)` for every
`s` (`mleAt_rowOnly`, the `eq` weights sum to `1`). The instance uses `s = 0` and carries the factor `2^b` in
`rsScale`.

**L36-6 (Info): two exports of the W16R2 rung differ in their range sub-planes.** L17's shape corpus has
`n_range = 13`, `a_rows = 317` for the W16R2 rung; L9's corpus (L23's `shRungW16`, L31's `IsRungW16`) has 14 and 320.
The range families depend on the export's calibration (A25). This lane reads the hosts' draw lists only, which do not
depend on it; `BlockAlgCheck` compares the logs, helper counts and lookups, which agree.

**L36-7 (Info, method).** `rw [lemma] at h` rewrites the first match, which may be on the wrong side; a `calc` or
`Eq.trans` with the stated sides is safer. `decide` proves a bounded `∀ k ∈ list` over the draw lists; an unbounded
`∀ k, k = 17 → …` must be `subst`ed by hand.

## 6. What is left

In the brief's order:
1. **The certified slot polynomials** `spR`, `hdgR`: done (`algSp`, `algSp_dg`). `spH`, `hdgH`: LEFT (the helper
   layer; the hosts' polynomials can be reused, `SC_LZC`, `SC_TAB`, `SC_ZS` need L23's `lzc`, `zc`, `zs` on their
   draw vectors).
2. **`hvR`**: done from `hform` (layer 0) and outright (layers 1 to 3). **`hvH`**: done from `hformH`.
   LEFT: `hform`, `hformH` (the join of §4 item 1).
3. **`hgdR`**: done at W16R2 from `W16Spec`; at R13 LEFT as `hrels`. **`hgdH`**: LEFT.
4. **The lookup side** (`hbr`, `hhr`, `Alk`, `T`, `mlk`, `hN`, `he`): LEFT. Done: the lookup counts over the padded
   cubes, and finding L36-1 on `he`.
5. **The final theorems**: done in the form of §2.5 and §4. The R13 Shieldstral statement needs L36-1's repair
   before it is cited.
6. **Checks against the corpora**: `BlockAlgCheck` (§7).

What the next lane needs, concretely: L35's `define`, `Poly` and plane allocation; then (a) the six hosts' and
twelve private slots' named sums (§4 item 1), slot by slot with L13's `*Ir_eval`; (b) the tables as pullbacks
(`hspec` by definition) and the R13 relation tables (`hrels`); (c) the helper layer and the lookup list; (d) the
block chain at `he ≤ 2^26` for the Shieldstral T128 R13 block.

## 7. Checks

CHECKS_PLACEHOLDER
