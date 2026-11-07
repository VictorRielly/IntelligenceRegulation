# D63 step L13: the W16R2 slot polynomials built in Lean, and what they are (2026-11-07)

Lean lane L13 (Claude), on its own worktree branched from perf `def4cf1e` (L11 merged; L9 was merged into perf as
`6610324a` after this lane started, and is not on this branch). Lean 4.34.1, Mathlib v4.34.1, no new dependency. New
library files under `formal/ZK60Formal/` (imported by the library root): `SlotW16Build.lean`, `SlotW16BuildEval.lean`,
`SlotW16BuildSlots.lean`, `SlotW16BuildLayout.lean`, `SlotW16Compose.lean`; the checker `SlotW16BuildCheck.lean` (not
imported: it defines `main`). One TEST-ONLY Rust file, `ops/zkp-mvp/gpu-metal/hashline/src/private_block/
lean_l13_export_tests.rs`, declared by four lines in the test-only `w16r2_tests.rs` and listed in the test-only
`s25_tests.rs`'s `TEST_ONLY_FILES` (82 → 83 on this branch; perf has 83 after L9, so the merge gives 84). No production
source changed. `Statements.lean` and every existing Lean file are unchanged. Evidence: `results/zk60_lean_l13_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**TESTED** (value for value against the Rust code), **CODE** (read off the sources, file:line), **ESTIMATE**.

## 1. In plain words, for Victor

**What this step is.** Each W16R2 block runs 23 sumcheck "slots". Each slot's polynomial is built by the code
(`build_slot_ir`) out of the slot's tables (the committed planes, the gates, the public tables) and its challenges. L11
wrote the verifier's per-slot arithmetic in Lean, but took each slot's polynomial FROM the Rust code (via the corpus).
The link from "the polynomial the verifier checks" to "the relations the layout theorem needs" (`W16Rels`) was read off
the code, not proved. This lane closes most of that link.

**What now exists.**
1. **The 23 slot polynomials, built in Lean.** A Lean port of the code's builders: every slot's table list and its
   polynomial (every node, every term, every coefficient value), as functions of the shape, the precision, the
   committed layout and the challenges. Lean also builds the layout facts the builders read (the 71 to 75 committed planes
   and their names, the helper planes, every lookup of every domain, the zero-rule planes, the range families).
2. **Checked against the code.** At the W16R2 development rung (a real receipt, accepted by the production verifier)
   Lean rebuilds all 23 slots' tables and polynomials from the shape and the challenges alone, and they are identical to
   the code's; and Lean's layout facts are identical to the code's at the rung, Shieldstral T128 and 8B T128 shapes
   [TESTED, §6].
3. **What the polynomials are, PROVED.** For any challenges and any table values: each of the six host slots'
   polynomial is `eq(τ)·Z + ν₀·eq(p₁)·gate·host₁ + ν₁·eq(p₂)·gate·host₂`, where `Z` is the batched relation of its
   named clause list (the LogUp helper relations, the tuple relation, the pad term, the gated clauses) and the hosts are
   the requantizations; the standalone zero-checks are `eq(τ)·Z`; the private slots are their summands. With the bridge
   to `hostPoly` this is exactly the polynomial `SlotW16Sound.lean`'s soundness lemmas count.
4. **Per-slot soundness on the code's polynomial, PROVED.** If a host slot's relation fails on the committed data, its
   claimed sum survives the challenges with probability at most `(3n + m + 2)/|F|` (`n` its cube's variables, `m` its pad
   planes); at the W16R2 8B and Shieldstral shapes that is at most `129/p²`, below `2^-120` per slot.
5. **End to end at one slot.** At `SC_DZC` it is a theorem that the number the executable verifier computes as the
   slot polynomial's value (an `Fp2` word), read in the field, IS the named host form above.
6. **Layout facts, PROVED for every W16 precision** (so at 8B and Shieldstral whatever their trained calibration, and
   block by block when a run's layers are calibrated differently, A25): the LogUp family list is well-formed
   (`FamsOK`), every width the layout theorem needs is a family (`W16Widths`), the code's layout map is a `W16Layout`
   (the padded axes, the head-slot order, the RoPE flip); and L11-1 checked: the product remainder's literal lookup
   width equals the product fold's shift at both stacks, so the literal is safe today.

**What this does not do yet** (§5): the Fiat–Shamir composition of the slots' challenge draws on the transcript (L8's
schedule, one wide round per slot), which needs the committed data as a function of the transcript; the premise "the
terminal values are true of the committed tables", which stays explicit here and which lane L16 supplies; the
reindexing of each slot's clause list into `W16Rels`'s named fields on the product cubes; `M`'s mask totals; the
end-to-end corollary at the 22 slots other than `SC_DZC`. So there is no single block-level theorem yet; the estimated
block error (§5) is about `2^-120` per prover query, against the target's `2^-100`.

**Findings** (§4): no mismatch between the code and the approved statements. Notes L13-1 … L13-4 (Info).

## 2. What is proved

All PROVED (`results/zk60_lean_l13_20261107/`; the numbers are in §6).

### 2.1 `SlotW16Build.lean`: the builders (a port of `build_slot_ir` and `slot_ir_accuracy.rs`'s W16 arms)

| Definition | What it mirrors (CODE) |
|---|---|
| `Cst`, `cstW`, `cstR`, `Cst.map` | the constants a builder writes (`Coef::one`, `neg_one`, `zero`, `base` = `Fp2::from_i64`, the `2^(16k)` of `limbs16_node`, `pow256`), at the code's words (`cstW`) or in a ring (`cstR`) |
| `limbs16B`, `limbsB`, `reqB`, `gatedSt`, `batchB`, `threeTerms` | `limbs16_node`, `limbs_node` / `l3_node`, `requant16`, `gated`, `batch`, `three_terms` (slot_ir.rs:906-931, slot_ir_accuracy.rs:84-121, 438-442) |
| `LkD`, `denB`, **`logupGo`** | `logup_subterms` (slot_ir.rs:870-902): per pair two denominators `α − (cst + g_tag) − Σ coef·t` and `h·d₁·d₂ − d₁ − d₂`, an odd last `h·d − 1`; node ids from the segment's start |
| **`padGo`** | `IrPad` (slot_ir.rs:790-836): per group `1 − supp` and `Σ ζ^j·plane`, the powers continuing across a slot's groups |
| **`zcIr`** | every zero-check slot's node list: the slot's own nodes, the LogUp segment, the pad segment, the zero-check node, the host nodes (each node's id its position, as `IrB` numbers them) |
| `ssIr`, `rsIr`, `mmIr`, `bilIr`, `zsIr`, `ioIr` | `SC_SS`/`SC_SSM`, `SC_RS`, the seven matmuls, `SC_SCORE`/`SC_PV`, `SC_ZS`, `SC_IO_*` (slot_ir.rs:959-1157, 1540-1552) |
| `tzcIr` (`TzcR`), `lzcIr`, `tabGo`/`tabIr` | `SC_TZC` (977-1044), `SC_LZC` (1045-1064), `tab_w16` (slot_ir_accuracy.rs:712-762) |
| `dzcIr` (`DzcR`, `DzcK`), `fzcIr`, `qzcIr`, `szcIr` | `dzc_w16` (444-497), `fzc_w16` (499-553), `qzc_w16` (555-614, `SC_QZC` and `SC_KVZC`), `szc_w16` (616-705) |

Each W16R2 specific is a named definition (the slot builders, the role records `DzcR`…, the constants `DzcK`…), so
W16R3's B2 (one batched sumcheck over several slots) and B3 (F's compact index) are new builders of the same types.

### 2.2 `SlotW16BuildEval.lean`: node values, the segments, the template

| Theorem | Statement |
|---|---|
| `nodeVals_append`, `nodeVals_ext`, `nodeVals_length`, `getD_len_add`, `getD_lt` | a node's value is fixed when it is pushed: later nodes only append |
| `logupSem`, **`logupGo_spec`** | the LogUp segment's subterms, read against any later node list, sum to `Σ_k μ_k·(h_k·d_{2k}·d_{2k+1} − d_{2k} − d_{2k+1})` (`h·d − 1` for an odd last lookup) |
| `padSem`, **`padGo_spec`** | the pad segment's to `Σ_groups μ_pad·(1 − supp)·Σ_j ζ^j·plane_j` |
| **`zcIr_vals`** | the zero-check template's node values: the slot's own nodes' values, then the zero-check node's value `logupSem + extra + padSem + last`, then the host nodes evaluated after it |
| `logupGo_map`, `padGo_map`, **`zcIr_map`** | naturality: `Ir.map f` of a builder is the builder at the images, so a theorem stated in a ring for ANY constants applies to the code's IR read in `K` (`toK_irEvalW`) |

### 2.3 `SlotW16BuildSlots.lean`: what each slot's polynomial is

For any commutative ring and constants with `one = 1`, `negOne = −1`, `zero = 0` (`Cst.Std`), at ANY terminal values
`v` (each statement is `irEval (slot IR) v = …`):

| Theorem | The slot's polynomial |
|---|---|
| `ssIr_eval`, `rsIr_eval` | `supp·eq·x²`; `supp·eq·(mask·e + λ·zsel)` |
| `mmIr_eval`, `bilIr_eval`, `zsIr_eval` | `a·w`; `eq(r_g)·a·b`; `ones·u` |
| `ioIr_eval` | `eq(τ)·(plane − endpoint)` |
| `lzcIr_eval`, `tabIr_eval` | `eq(τ)·(logupSem + padSem)`; `eq(τ)·(Σ_k μ_k·(h_k·(α − t_k) − m_k) + padSem)` |
| **`tzcIr_eval`** | `hostTerms` with `Z = Σ_k μ_k·c_k + padSem` over `tzcClauses` (`dsq − d²`, `d − dl`, `2d − a1 − a2`, twice), hosts `dsq + a1 − ceps` |
| **`dzcIr_eval`** | `hostTerms` with `Z = logupSem + padSem + gate·Σ_k μ_k·c_k` over `dzcClauses` (the six norm / residual clauses), hosts `reqV(ao)`, `reqV(down)` |
| **`fzcIr_eval`** | the same with the ACT tuple's relation `fzcAct` at `μ_1` and the product clause `fzcClauses`, hosts `reqV(gate)`, `reqV(up)` |
| **`qzcIr_eval`** | the RoPE clause `qzcClauses`, hosts `reqV(s₁)`, `reqV(s₂)` (`SC_QZC`: `q`, `pv`; `SC_KVZC`: `k`, `v`) |
| **`szcIr_eval`** | the exp tuple's relation `szcExp` and the four softmax clauses `szcClauses`; hosts `sum + λ` (gate `supp(Ht)`) and `reqV(score)` (gate `supp(S)`) |
| `hostTerms`, `reqV`, `L16`, `L256`, `gV`, `batchV`, `stVal_gated`, `post2_vals`, `threeTerms_eval`, `nodeVals_getD` | the named pieces and the steps |

### 2.4 `SlotW16BuildLayout.lean`: the layout facts

| Theorem / definition | Statement |
|---|---|
| `PrecW`, `aPlanes`, `pIx`, `gIx`, `domPlanes` | `AccuracyIds::new_w16`'s `A` plane list (non-DD) and its words / limb groups |
| `lookupsW`, `remLks`, `nHelp` | `lookups_w16` with `rem_lookups`, `word16`, `word24`, `direct`; the helpers per domain |
| `hIds`, `hPlanes`, `zeroPlanes` | `HIds::new`; `pad::zero_rule_a_planes` (`E` and full range families exempt) |
| `widthsRaw`, `widthsW`, `famsW`, `famsOf` | `range16::widths`, `families`; the block's LogUp family list (`U8` and the widths) |
| **`rhWidth_eq_foldShift`** | L11-1, checked: the product remainder's lookup width (accuracy_layout.rs:324) is the product fold's shift (accuracy_aligned.rs:25-29) at both stacks: `16` at LowH24, the stack of both W16R2 profiles |
| **`famsOK_famsOf`** | the family list of widths `≤ 24` is `FamsOK` (distinct tags below `p`, none `TAG_EXP`, `TAG_ACT`) |
| **`w16Widths_of`** | for every block shape whose shifts are a W16 precision's (`S.sprod` the fold's shift, `f_p + 1 ≤ 16`), `W16Widths S (famsOf (widthsW p))`: `blockSat_of_slots`'s width premise, at every W16R2 shape, with no table evaluated (L7-4) |
| `axPad`, **`stdLayout`** | the code's layout map is a `W16Layout` at every shape: the axes padded by `Fin.castLE` (the logical indices first), the head-slot order C-1 `h ↦ (h / hpg, h % hpg)` (injective, with the code's grouping of consecutive heads `grp h = h / hpg`), the head dimension `(top bit, index)` with the RoPE flip of the top bit |

### 2.5 `SlotW16Compose.lean`: per-slot soundness on the code's polynomial

| Theorem | Statement |
|---|---|
| **`hostTerms_hostPoly`**, `hostTerms_hostPoly₂` | at a cube point `b`, with the `eq` tables' values `eq(τ, b)`, `eq(p_i, b)` and the gate's, the code's host terms ARE `SlotW16Sound.hostPoly τ Z ν p g h b` (`₂`: one gate per host, `SC_SZC`) |
| **`host_claim_sound`** | `dens_host_hosted` on that polynomial: a host whose relation fails (a clause or pad plane nonzero, or a hosted identity `g·h_i = M_i` false) has its claimed sum `Σ_b hostPoly(b) = Σ_i ν_i·M̃_i(p_i)` hold with probability at most `(n + n + (m + 1 + n + 1))/|F|` over `(p₁, p₂, ζ, μ_pad, μ, τ, ν)` |
| **`standalone_claim_sound`** | a standalone zero-check (`SC_LZC`, `SC_TAB`, `SC_IO_*`): `Σ_b eq(τ, b)·Z(b) = 0` with probability at most `(m + 1 + n)/|F|` |
| `hostNum`, **`w16r2_host_num_le`**, `w16r2_8B_host_cubes` | at the W16R2 8B and Shieldstral shapes every host slot's numerator is at most `129` for any pad count `m ≤ 64` (the host cubes at 8B: `TZC 7, DZC 19, QZC 19, KVZC 17, SZC 19, FZC 21`) |
| **`host_bound_goldilocks`** | `129/p² ≤ 2^-120` for every `p ≥ 2^64 − 2^32` |
| `cstW_map_std`, `getD_map_f`, `dzcIr_map`, **`dzc_code_eval`** | the end-to-end link at `SC_DZC`: the word the executable verify arm computes as `poly(vals)` (`irEvalW`, `slotVerifyW`'s `polyVal`) on the Lean builder's IR at the code's words, read in `K` (`toK_irEvalW`), IS `hostTerms` with `dzcClauses` (the builder commutes with `Ir.map`; the code's constants read in `K` are standard) |

## 3. How it fits L9's `BlockParams.define`

L9's `blockVerify` (perf `6610324a`, `ExecBlockVerify.lean`) takes the slot definitions as a field
`define : ℕ → Hist → List Fp2 → Except String SlotDef`, `SlotDef = (tabs, poly, hosted)`. This lane's ports are the W16R2
instance of that field's polynomial and table list: for slot `s`, `Hist` (β, γ, α and the earlier slots' draws) and the
slot's own draws, `SlotW16BuildCheck.build` produces the tables (kinds and labels) and the IR, and `poly := irEvalW ir`.
The adapter is not written here because `ExecBlockVerify.lean` is not on this branch (it was merged after this lane
started): `Tab.priv` there carries the private table's opening data (`Priv`: commitment, slices, coordinates, mask row),
which is the openings' (L10's) part of `define` and is not built here. The hosted list is L11's `hostedCoefs`.

**Per block, not per run (A25's finding).** At W16 and W16R2 the 16-bit range families, and with them the `A` plane
list and the `Dom::Tab` sub-planes, depend on the layer's requantization shifts and gate (`range16::widths`); a real
trained model's per-layer calibration gives several plane lists in one run (A25: three at the real Shieldstral
export). Nothing here assumes one shape for a run: every layout fact is a function of ONE block's precision
(`PrecW`: `aPlanes p (famsW (widthsW p) logCols)`, `lookupsW p`, `hIds`, `zeroPlanes`), every slot builder takes that
block's table positions and constants (`DzcR`, `DzcK`, …), and the layout theorems (`famsOK_famsOf`, `w16Widths_of`,
`rhWidth_eq_foldShift`, `stdLayout`) and the per-slot soundness hold for every precision. A run instantiates them block
by block, from each block's calibration; the rung corpus is one concrete instance (one block), and the export's three
shapes are three precisions.

## 4. Findings

No mismatch between the code and the approved statements was found.

**L13-1 (Info): the slot polynomials are now a theorem about Lean's builder, and a test about the code's.** The
link "the code's IR = Lean's builder's" is TESTED on one real receipt (all 23 slots, every coefficient value) and the
layout facts at three shapes; it is not a theorem about the Rust source (that would need a Rust-to-Lean translation,
statement §5 row "Verifier"). With production acceptance by the Lean verifier (decision 3), the Lean builder IS the
definition, and the test becomes moot.

**L13-2 (Info, known L3 F2): `SC_LZC` batches its helper relations with the all-ones weight.** `standalone_claim_sound`
counts a random `μ`; `SC_LZC`'s relation is `rel + μ_pad·pad`, with the constant weight `1` (slot_ir.rs:1059). It is
sound because every W16R2 shape has ONE `Dom::L` helper (two lookups, `LK L 1`, TESTED at all three shapes): one
relation needs no batching. A second `Dom::L` lookup pair in a later profile would need a random weight.

**L13-3 (Info): a host's hosted claim points live on the host's cube.** The code's `eq(p_a)`, `eq(p_z)` … tables of a
host have the host's length (`eqT (lt + ld)` at `Dom::D`, TESTED), so `dens_host_hosted`'s `n₁ = n₂ = n` and a host's
numerator is `3n + m + 2`. The points are drawn by the private slots BEFORE the host (the schedule), which is what makes
them independent of the host's batch; under Fiat–Shamir they are part of the host's header.

**L13-4 (Info, engineering).** (a) Proofs about IR node lists go through `nodeVals_append`/`getD_len_add` (a node's
value is fixed when it is pushed); stating a value lemma with the list in `acc ++ x :: y :: t` form and the index as
`acc.length + j` keeps `simp only` deterministic. (b) `set` abbreviations made before `unfold` are not seen by `rw` in
the unfolded goal; `generalize` after `unfold` is. (c) In Lean 4.34 `String.drop` returns a `String.Slice`.

## 5. What is left

**The premise this lane keeps explicit: "the terminal values are true of the committed tables".** Every soundness
statement here (`host_claim_sound`, `standalone_claim_sound`) is about the slot polynomial evaluated on the TRUE tables
(the committed planes as cube functions, the `eq` tables at the drawn points, the gates); the bridge
`hostTerms_hostPoly` takes, as named hypotheses, that the terminal values `v` at a cube point are those tables' values.
That the verifier's opened terminal values are the committed tables' (L10's finding L10-6: `BlockWin`'s
`fin = f(ρ)`) is supplied by lane L16 (the knowledge versions of the openings and `M`, the claim-to-table map); it is
not proved here.

1. **The Fiat–Shamir composition of the slots' challenge draws** on the code's chain: one `CSub` per slot's `define` step
   (a wide round with no message, its width the slot's draw count, `W` the width at the step's first counter), its
   state "the slot's relation fails" before and "the slot's identity holds at the drawn challenges" after, `RbrWide` from
   `host_claim_sound`'s density through `prob_fp2_vec_le`; composed with L8's `fs_code_chain_sound_sched` and, for the
   sumchecks, L9's `block_sumchecks_fs_sound`. This needs the committed data as a function of the transcript's header
   (the soundness version: any decoding of the roots) or the extractor (the knowledge version, ASSEMBLY §4.2 a), and
   the unmasked identities from the sumchecks' claims, which needs `M`'s mask totals (L10).
2. **`W16Rels` from the slots' clause lists**: the clause families above are the code's, on the slot's flat cube; the
   reindexing to `W16Rels`'s named fields on the product cubes (`Ct × Cw` …) needs the axes' index maps
   (`plane_index.rs`, msb-first: `mleAt_append`), the gates as `pad::indicator_table`, and the extracted planes.
3. **Naturality per slot** beyond `SC_DZC` (`dzcIr_map`), and `Ir.Canon` of the built IR (the checker's `canonB`).
4. `SC_RS`'s row claim on `rsIr` (`dens_rowsum`), `SC_LZC`'s fixed-weight variant (L13-2).
5. **W16R3**: B2 (one batched sumcheck over several slots) and B3 (F's compact index) are new builders of the same types.

**Estimated block error** [ESTIMATE, the form L8's composition gives, not proved here]: per prover query, the largest
per-step error of the 23 slots' draws (`129/p²`, `w16r2_host_num_le`, with the `challenge_fp2` bias `(1 + 2^-64)^(2w)`,
`w ≤ 64`) and of their sumchecks (`5/p²`, L9-5's degree 5) is about `2^-120`; so
`ε(q) ≈ (q + ℓ + 1)·2^-120 + q²/2^256`, `ℓ ≈ 2^11` (L9's `rung_len`). Against `εsTarget q = q·2^-100 + 2^-100` this has
about 20 bits of margin per query and holds for every `q ≤ 2^150`.

## 6. Checks

All in `results/zk60_lean_l13_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `rust.log`: the layout export (`export_l13.sh`: `cargo test --release --offline --locked -j 2 --lib lean_l13_export`,
  170 s): 1 passed. `layout.txt`: 5,514 bytes, the rung, Shieldstral T128 and 8B T128 shapes.
- `file1.log` … `file3.log`, `iter1.log`, `iter2.log` (`stage.sh`, `iterate.sh`): the new files while they were written;
  the errors fixed on the way are in those logs (§4 L13-4). The jobs waited behind the other lanes' and the media lane's
  jobs (up to about 50 minutes per job).
- `check.log`: `check_l13.sh`, ONE guarded job (545 s, peak RSS 4.71 GiB; it first builds the root's modules one target at a
  time, because a fresh worktree's first full build in parallel exceeded the 24 GiB cap at 28 GiB), which runs:
  - the full build (`full.log`): 3,464 jobs, rc 0, 0 warnings, 0 errors, no `sorry` (the three evaluation files set
    four Mathlib style linters off, `linter.unusedSimpArgs`, `unreachableTactic`, `unusedTactic`,
    `unnecessarySeqFocus`: their proofs try a short list of simp sets with `first`, and the linters flag the branches
    not taken);
  - the axiom audit (`axioms_l13.lean`, written by `gen_axioms.py`, → `axioms.log`): 60 theorems of the five library
    files, nothing beyond `propext`, `Classical.choice`, `Quot.sound`: 13 on all three, 31 on `propext, Quot.sound`, 13
    on `propext`, 3 on none; `sorryAx` and `Lean.ofReduceBool` appear nowhere;
  - the source scan (none of `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
    `implemented_by`, `extern`, `bv_decide`, `ofReduceBool` in the six files) and the root imports;
  - the regressions: `L6Check` 1,206 checks, 0 failed; `L5Check` 5,553, 0 failed; the fixture L1 check 101,956, 0 failed;
    `L11Check` on the W16R2 rung corpus 404, 0 failed;
  - **`SlotW16BuildCheck`** (`l13check_full.log`) on `layout.txt` and the L11 corpus: **179 checks, 0 failed** (the table
    below);
  - the negative control (`mutate_l13.py`, `negative_control.log`): seven single changes, exactly 7 failed, one each;
  - the R19b file census (`cargo test … r19b_every_rs_file`, `r19b.log`): 1 passed.

| `SlotW16BuildCheck` kind | Checks | What |
|---|---|---|
| `shape-count`, `stack`, `fold-shift`, `rh-width` | 1 + 3 + 1 + 3 | three shapes exported; all LowH24; the rung's product fold's shift is `foldShift` (16); the remainder width is the fold's shift |
| `widths`, `families` | 3 + 3 | `widthsW`, `famsW` equal `range16::widths`, `Shape::range_families` at each shape |
| `a-planes`, `h-planes`, `h-ids` | 3 + 3 + 3 | `aPlanes` (75 / 71 / 71 planes at the rung / Shieldstral / 8B: domain and name), `hPlanes`, `hIds` equal `AccuracyIds::new_w16`, `HIds` |
| `lookups`, `helpers` | 18 + 18 | every lookup of `Dom::L, D, Q, Kv, S, F` (terms, constant, family) and the helper count, at each shape |
| `zero-planes` | 27 | `zeroPlanes` equals `pad::zero_rule_a_planes` for all nine domains at each shape |
| `ir-tables`, `table-kinds` | 23 + 23 | every slot's table list (kind and label, in `IrB`'s push order) built by Lean from the shape, the precision and the draws equals the code's; its kinds match the verifier's `Tab`s |
| `ir-nodes`, `ir-terms` | 23 + 23 | every slot's nodes and terms (every coefficient VALUE: the challenges, the constants, LogUp's `α − (cst + g_tag)`, the `ζ` powers) equal the code's IR |
| `slot-count` | 1 | 23 slots |

**Negative control** (`mutate_l13.py`): the 8B shape's first plane name, the Shieldstral `Dom::D` first lookup constant,
one of the rung's `Dom::F` zero-rule planes, one constant of slot 14's `c0`, slot 17's `ν₀`, one table label of slot 19,
slot 15's first draw (`μ₀`). Exactly 7 checks fail, one per change.
