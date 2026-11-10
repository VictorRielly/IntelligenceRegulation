# D63 lane L41: the join of the block's `define` (L35) and its per-outcome algebra (L36) at the W16R2 rung (2026-11-10)

Lean lane L41 (Claude Opus 5.5), on its own worktree: perf `347cc00d` (L35 and L36 merged). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. New library files under `formal/ZK60Formal/`, all `BlockJoin*.lean`, imported by the
library root. No checker against the code was added (the slot tables this lane reads are L35's program, which L35's
`BlockDefineCheck` compares with the code; this lane proves them equal to explicit lists by evaluation). No Rust.
`Statements.lean` and every existing Lean file are unchanged. Evidence: `results/zk60_lean_l41_20261110/`.

**STATUS: NOT FINISHED. Deliverables 1 to 4 are done for ONE of the six hosts (`SC_TZC`) and for every part that does
not depend on the other five hosts' slot programs; deliverables 2 (the lookup side), 3 (the helper layer) and 5 (R13)
are not started.** What is green and committed is listed in section 2; where it stops, and what the next lane needs, is
in section 4. The check of section 7 is green.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**MEASURED** (read off the code or a corpus), **ARGUED** (a reasoned claim, not a Lean theorem), **HYPOTHESIS** (a named
premise), **LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** The security statement of one transformer block ("the block verifier accepts while the
committed data breaks the block's equations with probability at most the target") was proved in two halves that meet
at named assumptions: lane L35 built the slot polynomials from the block's program, lane L36 proved the algebra from a
list of facts about them. This lane was to prove those facts for the real block, so that only run-level assumptions and
public-data facts remain.

**What is now proved.**
1. **The extracted data is now a definition, built from the committed matrix** (PROVED). Until now the statement took
   "the extracted planes" `xtE` as a free input: any data at all. Here `xtW` reads each of the block's 58 planes (the
   norms, the 16-bit words, every remainder limb, the softmax planes, the MLP planes) out of the committed `A` matrix,
   at the plane's offset in the code's layout, on the code's padded axes (5 token bits, 9 width bits, …).
2. **A gap in the earlier interface, closed (finding L41-1).** Lane L36's facts compare the slot tables (values in the
   extension field `K`) with the block's relations (values in the Goldilocks field). They can only hold if the decoded
   committed data is Goldilocks-valued. The extraction decodes each row in `K`, so this was not automatic. PROVED: at
   the opening's radius (W16R2: 8,052 errors, minimum distance 16,105; R13: 24,448 errors, distance 48,897) the decoded
   rows of the committed matrix ARE Goldilocks values. So the premises are meetable; without this lemma they were not
   known to be.
3. **The block's tables on the Boolean cube** (PROVED, L35's first open item): every table the verifier builds, at a
   cube point, is what it should be: an `eq` table is `eq(point, bits)`, a public table is its entry, a private table is
   its plane's entry; and at ANY point a private table is its plane's multilinear extension.
4. **Lane L36's `hspec` is discharged at the rung** (PROVED): the algebra data `dt` is defined as the block's named
   relations evaluated on the extracted data, the cube encodings are defined and shown onto.
5. **The first host's named identity is proved** (`SC_TZC`, the norm host, with its two hosted row sums of squares):
   on every accepting outcome, the slot polynomial the verifier checks, summed over the cube, is exactly the named
   formula L36 needs. This is the hard step L36 could not do from L35's one-point identity (L36-2). The method is now
   in place for the other five hosts.
6. **The W16R2 rung block's statement with all of the above removed** (`block_knowledge_join_w16r2_rung`, PROVED).

**What is not done.** The same named identity for the other five hosts (`SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`,
`SC_FZC`): it is a premise, `hformRest`. The lookup side (`Alk`, `T`, `mlk`, `hTtab`, `hcov`), the helper layer
(`HGd`, `spH`, …, `hhr`): still lane L36's premises. R13 (the `SC_TAB` transcription and the Shieldstral counts): not
started. The public tables `pubs` are tied to the public data only for the two tables `SC_TZC`'s hosted slots read.

**Findings that need a decision.** None of this lane's findings needs a ruling. L41-1 (Medium, resolved by proof)
shows that an assumption of the earlier interface was only meetable because of a decoding fact nobody had proved.
L41-3 (Medium): the statements are generic in the integer model's shape `S`, but the slot programs carry the rung's
constants; the two must agree, which is now an explicit public-data premise `RungS`.

## 2. What is proved

Every theorem below is on at most `propext`, `Classical.choice`, `Quot.sound` (section 7).

### 2.1 `BlockJoinGF.lean`: the decoded rows are Goldilocks values (finding L41-1)

| Theorem | Statement |
|---|---|
| **`decodeRows_base`** | for a `K`-encoder that is a base encoder with its scalars extended, at base points, with `2e < d = N − (n + Q − 1)`: every entry of the decoded rows of an embedded base matrix is an embedded base value |
| `ptsB`, `ptsB_injective`, `RWB`, `RWB_ext`, **`decode_encG_base`** | the code's encoder `encG h Q` is such an encoder (the coset `7·G_{2^h}`, the interpolant rows on `G_{2^14}`) |
| **`xAof_base`**, **`xHof_base`** | every entry of the `A` (`H`) matrix L31's `csXof` reads is `algebraMap GF K` of a base value, at any geometry within the radius |
| `w16r2_unique_radius`, **`xAof_base_w16`**, **`xHof_base_w16`** | at W16R2's `(15, 280, 8052)`: `2·8,052 = 16,104 < 16,105` |
| `r13_unique_radius`, **`xAof_base_r13`**, **`xHof_base_r13`** | at R13's block geometry `(16, 256, 24448)`: `2·24,448 = 48,896 < 48,897` (by one) |

### 2.2 `BlockJoinCube.lean`: the tables on the Boolean cube (L35 "Not finished" item 1)

| Theorem / definition | Statement |
|---|---|
| **`eq_mleAt_of_affAt`** | a function affine in every variable is the multilinear extension of its cube values |
| **`cubeSum_split`**, `bpt`, `cpt` | a cube sum over `n + e` variables is a double sum over main bits and extension bits; the cube point with the zero extension |
| **`selK_cpt`**, **`cmK_cpt`**, **`selK_off`**, `xrK_cpt` | at the zero extension `sel = 1` and every mask coefficient is `0`; off it `sel = 0` |
| `privZ`, **`tabK_priv_sel`** | a private table where `sel = 1` and its mask coefficient is `0` is its claim functional without the mask parts |
| `planeZ`, **`privZ_mle`** | **a private table's plane**; at ANY point the claim functional is the plane's multilinear extension |
| **`tabK_eq_cpt`**, **`tabK_pub_cpt`**, **`tabK_priv_cpt`**, `tabK_eq_off`, `tabK_pub_off` | at `cpt` an `eq` table is `eq(point, bits)`, a public table is its entry `v[msbIndex b]`, a private table is its plane's extension at its claim point; off the zero extension the first two are `0` |
| `baseR`, `eqPoly_mem`, `claimK_mem`, **`planeZ_base`** | a plane of base slices on a base matrix is a base value |

### 2.3 `BlockJoinHost.lean`, `BlockJoinVals.lean`, `BlockJoinBatch.lean`: generic host machinery

| Theorem / definition | Statement |
|---|---|
| **`cubeSum_host`** | a slot polynomial that is L13's `hostTerms` of its value list, whose `τ`, `p₁`, `p₂` entries vanish off the zero extension and are `eq(·, b)` on it, sums over the cube to `Σ_b hostPoly(τ, Z, ν, P, 1, h)(b)` |
| `hostPoly_congr`, `hostPoly_ext` | `hostPoly` with pointwise equal arguments |
| **`formAt_host_of`** | L36's `FormAt` for a host from its kind, its hosted slots' kinds and its identity at each outcome's draws |
| **`slotFns_of_accT`**, **`kind_of_accT`** | on an accepting outcome every verified slot passed `run_slot`'s checks; a slot is a host exactly when its definition hosts slots |
| `eqPoly_len`, `castB`, `sum_bool_cast`, `tabK_eqFull_cpt`, `tabK_eqHead_cpt`, **`tabK_rho_cpt`**, `aTab_eval`, `rhoC_eval` | the value list a slot's IR reads, entry by entry, at the cube points |
| `wsum`, `wsum_eq_sum`, `lkRels`, **`logupSem_eq_wsum`**, `lkRels_length`, `padPls`, **`padSem_eq_wsum`** | a zero-check's batch split into its entries: LogUp's helper relations and the pad planes (for the five remaining hosts) |

### 2.4 `BlockJoinW16.lean`: the rung's extracted planes

| Theorem / definition | Statement |
|---|---|
| `CtW` … `CfW` | the padded axes as bit vectors: tokens 5, width 9, groups 3, in-group 1, head dimension 6, hidden 10 |
| `piB`, `piB_alg`, `alg_piB` | a base projection `K → GF` (a left inverse of `algebraMap`) |
| `aPl`, **`aPl_base`**, `planeZ_aPl` | the `A` plane at an offset; base-valued on a base matrix |
| `offW`, **`offW_eq`**, **`idsR_eq`**, **`idsR_limbs`** | the 58 planes' offsets at the rung (`aOff cfgRungW16`, evaluated) and their ids by name |
| `plT`, `plD`, `plQ`, `plK`, `plS`, `plH`, `plF`, `plL`, `remR`, **`xtW`** | **the rung's `W16Data`, each field the base projection of its plane** |
| **`aPl_alg`** | on a base-valued matrix the projection loses nothing |
| `RungS` | the integer model's shape constants are the rung's `PREC` (public-data premise) |

### 2.5 `BlockJoinTzc.lean`, `BlockJoinTzcForm.lean`: `SC_TZC`'s named identity

| Theorem / definition | Statement |
|---|---|
| `tabs0`, `tabs1`, `tabs2`, **`slot0_eq`**, **`slot1_eq`**, **`slot2_eq`** | slots `SC_SS`, `SC_SSM`, `SC_TZC` of L35's program at the rung, as explicit tables, IR and hosted list (by evaluation) |
| `cstK`, `cstK_base`, `cstK_p256`, `cstK_p16`, `cstK_tzc` | the builders' constants in the field |
| **`tzc_vals`** | `SC_TZC`'s value list at a cube point: the three `eq` tables, then the norms' planes and their nine byte limbs each |
| **`relCl2_alg`**, **`relGh2_alg`** | the IR's six clauses and two hosted terms there ARE `W16Rels`' `SC_TZC` relations of `xtW`, embedded (the token gate is `1`) |
| `tzc_irEval`, **`tzc_cube`** | `SC_TZC`'s cube sum is `Σ_t hostPoly(τ, Σ_j μ_j·relCl 2 j, ν, P, 1, relGh 2)(t)` |
| **`ss_cube`** | `SC_SS`'s (`SC_SSM`'s) cube sum is the MLE, at its point `r_t`, of the gated row sums of squares `Σ_c gD·X²` |
| **`formAt_tzc`** | **L36's `FormAt` at host 2**: for every `dt` whose host-2 tables are the relation tables, on every outcome whose verified slots passed their checks |

### 2.6 `BlockJoinDt.lean`: `dt`, the encodings, `hspec`

| Theorem / definition | Statement |
|---|---|
| `splitD`, `splitQ`, `splitK`, `splitS`, `splitHt`, `splitF` and their `_append` inverses | a domain's cube point as its product cube's position, most significant axis first |
| **`encW`**, **`encHtW`** | the hosts' and `Dom::Ht`'s encodings |
| `mpadW`, **`mpadW_zeroPl`**, `mpadW_hm0`, `mpadW_hm78` | the hosts' pad plane counts at the rung (`SC_DZC` 19, `SC_FZC` 9, others 0), equal to the zero-rule plane lists `DefW16.zeroPl` (evaluated); they meet `hm0`, `hm78` |
| `thirtytwo_ne_zero`, **`dtW`** | the algebra data: the named relations of the extracted planes through the encodings; the batch's other entries `xc` and the pad planes `pwc` given; `SC_RS`'s scale `2^5` |
| `relCount_room` | every host's batch has room for its named clauses (evaluated) |
| **`hspecW`** | **L36's `hspec : W16Spec` holds for `dtW`, `encW`, `encHtW`, for every `xc`, `pwc`** |

### 2.7 `BlockJoinFinal.lean`: the statement

| Theorem | Statement |
|---|---|
| **`dXof_base`** | the rung's committed `A` matrix (`dXof`) is base-valued |
| **`block_knowledge_join_w16r2_rung`** | `Pr[BlockAcc ∧ header ∧ ¬BlockSat(xtW)] ≤ εsTarget q + εend` at the W16R2 rung, on L35's `block_knowledge_define_alg_w16r2_rung`, with `xtE`, `sh`, `dt`, `enc`, `encHt` DEFINED, `hspec` PROVED and `hform` PROVED at `SC_TZC` |

## 3. The numbers

| | value | label |
|---|---|---|
| W16R2 opening: `N`, message length, errors `e`, distance `d` | `2^15`, `2^14 + 280`, 8,052, 16,105 (`2e = 16,104 < d`) | PROVED |
| R13 opening (rung and Shieldstral blocks) | `2^16`, `2^14 + 256`, 24,448, 48,897 (`2e = 48,896 < d`, margin 1) | PROVED |
| planes read into `xtW` | 58 `A` planes (`T` 4, `Ht` 2, `L` 2 (as 2 × 9 limb slices), `D` 19, `Q` 6, `Kv` 6, `S` 10, `F` 9); offsets `0` … `1,163,264` | PROVED equal to `aOff cfgRungW16` (`offW_eq`) |
| `SC_TZC`'s tables, IR, hosted list | 25 tables; 6 clauses; hosts `SC_SS`, `SC_SSM` | PROVED equal to L35's program (`slot2_eq`), which is MEASURED against the code by L35 |
| hosts whose named identity is proved | 1 of 6 (`SC_TZC`) | PROVED |
| declarations / theorems (section 7.1) | 175 / 122 | MEASURED |

## 4. What is left, by name

`block_knowledge_join_w16r2_rung` takes, besides lane L31's run-level premises (`U`, `hU`, `hK2`, `key`, `domain`, `hs`,
`hL`, `hL64`, `hL20`, `hdrLen`, `hdrSq`, `hh`, `hq`, `csE`, `rE`, `QE`, `XE`, `hcsE`, `q`, `A`, `hA`, `εend`, `hEnd`), the
verifier's facts (`hP : IsRungW16`, `hdef : P.define = defineS (progW16 …) pubs`, `hlc`, `hep`, all as in L35) and the
public data (`Pb`, `Lay`, `B`, `fams`, `hF`, `hW`, `h24`):

| Premise | What it is | Kind | Meetable at the real block? |
|---|---|---|---|
| `hS : RungS S` | the integer model's shape constants are the rung's `PREC` | public-data fact (new, L41-3) | YES by construction of the rung's `S`; ARGUED (not compared with a corpus) |
| `hTok`, `hHd` | the token and head-dimension axes do not pad | public-data fact (L36) | YES, MEASURED by L36 |
| `hgD` | the verifier's public table 0 of `SC_SS`, `SC_SSM` (`supp(D)`) IS `B.gD` | public-data fact (L35-2, in part) | YES if `pubs` is the code's `pad::indicator_table` and `B.gD` its indicator; ARGUED |
| `mpad`, `hm0`, `hm78`, `xc`, `pwc` | the pad plane counts, the batch's LogUp entries and pad planes | free data for the next lane | the real ones: `mpad` from `DefW16.zeroPl` (`SC_DZC` 19, `SC_FZC` 9, others 0, MEASURED by L35's agreement through the IRs), `xc` / `pwc` as the hosts' IRs compute them |
| **`hformRest`** | `FormAt` for hosts 14 to 18 | HYPOTHESIS, LEFT | ARGUED yes by L36 §5; the method is `formAt_tzc`'s |
| `HGd`, `spH`, `hdgH`, `hformH`, `hgdH`, `hhr` | the helper layer | HYPOTHESIS (L36), LEFT | not examined beyond L36 |
| `Alk`, `T`, `mlk`, `hN`, `he`, `hTtab`, `hcov` | the lookup list and table | HYPOTHESIS (L36), LEFT; `hcov` now reads the DEFINED `xtW` | ARGUED by L36; with L41-1 the base-valued planes make `hcov` meetable |

Gone against `block_knowledge_define_alg_w16r2_rung`: `xtE`, `sh`, `dt`, `enc`, `encHt` (defined), `hspec` (proved),
`hform` at `SC_TZC` (proved). The other block-level premises stand; deliverables 1 to 4 are therefore NOT finished.

### 4.1 What the next lane needs, concretely (in order)

1. **The five other hosts, by `formAt_tzc`'s pattern** (`BlockJoinTzc.lean` / `BlockJoinTzcForm.lean`): per host, the
   explicit table list and IR by `rfl` against `progW16` (the probe `l41_probe.lean` prints them; `l41_probe2.lean` shows
   `rfl` works); the value list at `cpt` (`tabK_pa_cpt`, `tabK_eqFull_cpt`, `tabK_pub_cpt`); the IR's evaluation by
   L13's `*Ir_eval` through `*Ir_map`; the clauses against `relCl k j`, the hosted terms against `relGh k i`, as
   `relCl2_alg` does; the batch's LogUp entries through `logupSem_eq_wsum` and the pad term through `padSem_eq_wsum`,
   which DEFINE `xc` and `pwc` (they read only the helper planes, the looked-up planes, `α`, `β`, `γ`; `W16Spec` does not
   constrain them); and each hosted slot's cube sum against `mleAt (relMm k i)`: the matmuls through L36's
   `mleAt_append_bit` and L23's `matmul_sum`, the bilinear `SC_SCORE` / `SC_PV` with their group `eq`, `SC_RS`'s row sums
   through `rs_cubeSum`. The hosted slots' folded weights are public tables that READ the draws: their premise is
   `(pubs s hist dr 0)[msbIndex c] = W̃(c, r)` with `r` the slot's output draws (an `hgD`-style public-data fact).
2. `mpad := mpadW` (DONE as data: `mpadW_zeroPl`, `mpadW_hm0`, `mpadW_hm78`; the final statement keeps `mpad` a parameter so that
   the next lane's `xc`, `pwc` can be stated at it).
3. **`pubs` from `B`** (L35-2): a concrete `pubsW16 B` (a word per cube point, `Fp2.fromBase (Fp.ofGF ·)` of `B`'s
   value; the folded weights through `Fp2` sums of `eqTableMsb` products, `toK_add`, `toK_mul`), proving `hgD` and the
   per-host premises of item 1, so that `hdef` reads `defineS (progW16 …) (pubsW16 B)`.
4. The lookup side and the helper layer (L36 §4 items 3): with `xtW` base-valued, `hcov` asks the code's lookup list to
   contain `tupK` of every logical query; `Alk` should be the per-position lookups of `lookupsN`, read off the same
   planes (`aPl`), paired as the helpers pair them.
5. R13: the same at R13 (the R13 program `progR13`, R13's `SC_TAB` IR untranscribed, finding L17-9).

## 5. Findings

No statement of `Statements.lean` changed. No target weakened. No existing file changed.

**L41-1 (Medium; for the coordinator and the block lanes; resolved here, PROVED): lane L36's `W16Spec` and `hcov` can
only hold on Goldilocks-valued extracted data, and the extraction decodes in the extension field.** `W16Spec` asks the
slot tables (values in `K`) to be `algebraMap` of relation tables over the `GF`-valued `xtE`; `hcov` asks the lookup
list's `K` tuples to be `tupK` of `GF` tuples. L31's extraction decodes each committed row in `K` (`decodeRows (encG h Q)
e …`, `closeTable` a `Classical.choose`). If a decoded entry were not a base value, both premises would fail on that
outcome, and the statement's premises would be unmeetable there (L31-1's pattern). PROVED (`decodeRows_base`,
`xAof_base_w16`, `xAof_base_r13`, `dXof_base`): at the unique-decoding radius the closest codewords are unique, each
equals the embedding of its base projection (L26-3's `encLin_base_fact`), so every decoded entry IS a base value. At
R13 the margin is one (`2·24,448 = 48,896 < 48,897`): a larger opening radius at R13 would reopen this.

**L41-2 (Low; for L35's agreement check and the next lane): the program's tables are now pinned by evaluation.**
`slot0_eq`, `slot1_eq`, `slot2_eq` prove L35's program at the rung equal to explicit lists (offsets, log sizes,
coordinates, reserved rows); the offsets `offW_eq` are `aOff`'s. These are L35's, so the agreement with the code is
L35's (`BlockDefineCheck`: plane ids, not offsets, L35-7).

**L41-3 (Medium; for the coordinator; a new public-data premise): the integer model's shape must be the rung's
precision.** The statements are generic in `S : BlockShape`. The slot programs carry the rung's constants
(`precRungW16`: `ceps = 1`, the shifts, …) while `W16Rels` reads `S.ceps`, `S.sq`, …. `hform` (the IR's terms) and
`hspec` (the relation tables) can hold together only if the two agree; this lane makes that a named premise `RungS S`
(only `S.ceps` is used so far, by `SC_TZC`). The same holds at R13 and at the Shieldstral block (their `PREC`).

**L41-4 (Info; for the next lane): the token gate.** `SC_TZC`'s hosted terms carry no gate in the IR (the token axis
does not pad), while `W16Rels` multiplies them by `gT`; they agree because `gT = 1` on every token when `hTok` holds.
A padded token axis would need `SC_TZC`'s gate.

**L41-5 (Info, method).** `Fin (segLn (sh.dl k) .tau) → Bool` is definitionally `Fin 5 → Bool` at the rung's shape
(evaluation), so `dt`'s fields can be stated on the product cubes without casts; the program's tables at a concrete
slot are proved equal to explicit lists by `rfl` in seconds; `set` on a term that a hypothesis's type depends on breaks
the goal (use the term).

## 6. Note for the next lanes: the test-only Rust export that would close L35-7

L35-7: the agreement check compares the private tables' plane ids, not their offsets, log sizes, coordinates or
extension rounds, nor the public tables' values. A test-only file (as L18's `lean_l18_export_tests.rs`), run on a real
W16R2 rung receipt and on an R13 rung receipt, should print per slot, per table, in `define`'s order:

1. for a private table (`Tab::Priv`): its commitment, every slice `(offset, coefficient)` (so the six tables whose label
   names no plane are checked by offset), its log size, its coordinates (`Rho k`, `Flip k`, `Fixed v` with `v` as its two
   base words), its reserved mask row and its extension round; then the parts `build_claim` returns (offset, log size,
   coefficient, point), at the receipt's own point;
2. for a public table: its length and its values (two base words each), or, for a table longer than a threshold, a
   BLAKE3 digest of the words plus the first and last 16 values; with, per slot, the draws it was built from;
3. per domain, the plane offsets `a_off`, `h_off` and `rows_of`, so that `offW_eq` and `DefW16.aOff` are compared with
   the code at every plane, not only through the totals `aDataRows`, `hDataRows`.

A Lean checker would then compare items 1 and 3 with `progW16` / `progR13` (this lane's `slot*_eq` lists), and item 2
with a concrete `pubsW16 B` once written (section 4.1 item 3). It must keep hashline's census tests green (`s25_tests`,
`hash_domain`). Fresh-entropy receipts differ per export: compare a corpus only with the export it came from.

## 7. Checks

All in `results/zk60_lean_l41_20261110/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB).

- `iter1` … `iter13`: the modules one at a time (`iter*.log`); `l41_probe.lean` (the program at the rung, printed:
  `iter4.log`), `l41_probe2.lean` (`rfl` against the program), `l41_probe3.lean` (the cube types reduce).
- **`check.log`** (`check_l41.sh`, job `lean-l41-check`, exit 0, 126 s), on the tree at `883a00fb`: the nine
  modules built one at a time, then the full build: **3,661 jobs, rc 0, 0 warnings, 0 errors, no `sorry`**; 0
  warnings in the modules' own builds; the axiom audit (`axioms_l41.lean`, every `theorem`, `def`, `abbrev` and
  `structure` of the nine files, `axioms.log`): **158 declarations (109 theorems, 40 definitions, 8 abbreviations, 1
  structure)**; 91 on `[propext, Classical.choice, Quot.sound]`, 23 on `[propext, Quot.sound]`, 11 on `[propext]`, 33 on
  none; no `sorryAx`, no `ofReduceBool`, no other axiom; the source scan for the forbidden words: none; the root imports
  the nine files; `Statements.lean` unchanged, no existing file under `formal/` modified, no import line removed, no
  file under `ops/` changed; name clashes over every worktree: 0; regressions `L6Check` 1,206, `L5Check` 5,553,
  `L11Check` 404, the fixture L1 check 101,956, 0 failed.
- The final check after `BlockJoinBatch`, the R13 radius and `mpadW`: section 7.1.

### 7.1 The final check

`check.log` (`check_l41.sh`, run as the last step of job `lean-l41-final2`, `iter16.log`, exit 0, 55 s, peak RSS
3.63 GiB), after `BlockJoinBatch`, the R13 radius (`xAof_base_r13`) and `mpadW`:
- the ten L41 modules built one at a time (`prebuild_*.log`), then the full build (`full.log`): **3,662 jobs, rc 0,
  0 warnings, 0 errors, no `sorry`**; 0 warnings in the modules' own builds;
- the axiom audit (`axioms_l41.lean`, `axioms.log`): **175 declarations (122 theorems, 44 definitions, 8
  abbreviations, 1 structure)**; 96 on `[propext, Classical.choice, Quot.sound]`, 26 on `[propext, Quot.sound]`, 17 on
  `[propext]`, 36 on none; no `sorryAx`, no `ofReduceBool`, no other axiom;
- the source scan of the ten library files for the forbidden words: none;
- the root imports the ten files; `Statements.lean` unchanged; no existing file under `formal/` modified, deleted or
  renamed; no import line removed; no file under `ops/` changed;
- name clashes over every worktree (`l41_nameclash.py`, prefixes `BlockJoin`, `BlockR13Prog`; `nameclash.log`): 0;
- regressions: `L6Check` 1,206, `L5Check` 5,553, `L11Check` 404, the fixture L1 check 101,956; 0 failed.

Not run by this lane: `BlockDefineCheck`, `BlockAlgCheck`, `ExecBlockCheck`, `CheckR13Block` (no file they read was
changed), and the merged-tree check on perf, which is the coordinator's.
