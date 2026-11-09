# D63 lane L28: the openings' glue. `hexec` for `A` / `H`, the header readers, and the probability glue, at W16R2 and R13 (2026-11-07, resumed 2026-11-09)

Lean lane L28 (Claude), on its own worktree at perf `9d59ff9a` (L9 to L24 merged, L22 among them). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. New library files under `formal/ZK60Formal/`, imported by the library root:
`LinkW16Pcs.lean`, `LinkW16Head.lean`, `LinkW16Glue.lean`, `LinkW16GlueW16.lean`, `LinkW16GlueW16T.lean`,
`LinkW16GlueR13.lean`. No Rust and no production source changed. `Statements.lean` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l28_20261107/`.

The lane was started on 2026-11-07, cut off by a usage limit as its first build finished, and resumed on 2026-11-09
from the uncommitted drafts (five files, never compiled). The resumed session compiled them, made the instance file
generic in the opening's geometry so that one proof serves W16R2 and R13, and added the R13 instance. **STATUS: done;
the check of §7 is green.** Not in this tree: L25 (merged into perf after this lane's base) and the lanes running
beside it (L26, L27, L29); the merged-tree check is the coordinator's.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**HYPOTHESIS** (a named premise, with the shape a later lane must prove), **LEFT** (not done).

## 1. In plain words, for Victor

**What this lane was asked.** A block's proof ends with three "openings": the prover reveals a few random columns of
three committed tables (`A`, `H`, and the mask table `M`) and the verifier checks them. The security argument for
those openings (lane L20) is a probability bound that rests on two plain facts about the verifier's code: "if the
verifier accepted, each opening's checks really are the checks the bound talks about" (`hexec`) and "if the committed
data passes the bound's good test, every value the verifier was told is true" (`hsem`). Lane L22 proved both facts for
`M` and half of each for `A` and `H`. This lane was to finish them, plug in the real numbers, and so remove the
openings' assumptions from the block's security statement, first for the test profile W16R2 and then for R13, the
profile the media app really runs.

**What is now proved.**
1. **The opening verifier's arithmetic is the model's.** The code checks an opening with integer arithmetic on pairs of
   64-bit numbers; the security model states the same checks as equations in a field. PROVED (`pcsOk_groupsAccept`):
   whenever the code's opening check accepts, the model's acceptance condition holds, with the same random
   coefficients and the same sampled columns, for ANY opening parameters.
2. **Both facts are finished, for any opening geometry.** PROVED (`hexec_geo`, `hsem_geo`): for a block profile and an
   opening geometry (how long the codewords are, how many columns are sampled, how many errors are tolerated), on
   every run with the profile's header that the block verifier accepts. One proof covers W16R2 (codewords of 32,768 symbols, 280 sampled columns) and
   R13 (65,536 symbols, 256 sampled columns).
3. **The numbers are plugged in.** PROVED (`evMW_bound`, `evOW_bound`, with L22's `extract_fail_block`): the chance that
   a cheating prover gets a bad opening past the verifier is bounded per opening kind, at the real transcript, with
   R13's numbers as well as W16R2's (`opA_eps_r13`: 2^-110 per attempt for the batching round; `opB_eps_r13u`: below
   2^-126 for the column round). With these, one R13 block uses 30,322,419 of the 67,108,864 budget units the
   approved target allows, and one W16R2 block 30,263,665 (§3.1).
4. **The block statement no longer assumes anything about the openings' soundness.** PROVED
   (`block_knowledge_open_w16r2`, `block_knowledge_open_r13`): the chance that the block verifier accepts while the
   committed data does not satisfy the block's equations is at most the approved target, plus one term for the
   block's input and output claims, which the block verifier does not check itself (see below).

**Two things you should know about the shape of the result.**
- **The result is stated for the real run, not for every imaginable header.** L22 found that `hexec` is false if the
  prover may choose how many random numbers the header draws (L22-1). In the real system the verifier fixes the
  header, so the coordinator decided to state the result with the header's draw count fixed. That is what is proved.
  It narrows none of the two approved statements.
- **The block's input and output claims are checked elsewhere.** The block's opening premise, as L21 wrote it, also
  covers the claims about the block's input and output. The block verifier does not open those; the run around it
  does (L22-5). So the result carries a separate term `εend` for them, which the run-level lane (L27) must supply.

**So is `hOpen` discharged?** Not in the literal form L21 wrote, and that form cannot be reached this way: the fact
`hexec` it rests on is false when the prover chooses the header (L22-1), and it includes the input and output claims
(L22-5). What is discharged is the form the real run needs: on runs with the profile's header, every soundness
premise about the openings (`hM`, `hEA`, `hEH`, `hX`, `hsem`, `hexec`) is now a theorem, at W16R2 and at R13. §3 lists
exactly which premises are left; none of them is a soundness assumption about the openings.

**What is not done.** §6. In short: three bookkeeping premises about the profile (how many claims each opening
carries, a reader that recovers the verifier's claim list from its transcript, and the size bounds of a concrete
profile), and the run-level term for the input and output claims.

## 2. What is proved

Every theorem below is stated for an arbitrary quadratic extension `K` of the Goldilocks field with `U² = 7`, for every
oracle, and (where a probability appears) for every prover with at most `q` oracle queries.

### 2.1 `LinkW16Pcs.lean`: the regular opening's field link (L22 §5 item 1)

- `toK_dotF`, `claimWeights_length`, `groupZclaims_lens`, `sum_memsOf`, `groupComb_K`, `zkRhosAux_K`: the code's
  arithmetic read in `K`: the claim check's dot product, the weights' lengths, sums over the draw positions, one
  group's combination, and `zk_rhos`' combinations as sums of the run's batching challenges.
- `groupWeights_oclOf`, `groupWant_oclOf`: `SoundGroups.lean`'s combinations of L22's `oclOf` are the code's.
- **`pcsOk_groupsAccept`**: L10's `PcsOk` (any parameters, any column evaluator meeting `ColEncSpec`), with a matrix
  agreeing with the opened columns at the sampled indices, is `GroupsAccept` of `oclOf` for the encoder `encLin` at the
  run's `(λ, ρ)` and indices. This is the `A` / `H` analogue of L22's `maskOk_mFinal`.
- `lrCode_sqDs`: the code's `(λ, ρ)` vector is `FSOpening.lean`'s `lrCode` of the batching run's digests.
- `cRd_opA`, `cRd_opB`, **`pcs_subSt_of_acc`**: `opA`'s and `opB`'s rounds read off the trace, and `opB` alive at the
  end of the chain when the opening's checks hold (the analogue of L22's `mask_subSt_of_ok`).

### 2.2 `LinkW16Head.lean`: the header readers the openings need (L22-7, the part that reads absorbed vectors)

- `decFp2s`, `decFp2s_toBytes`: field pairs decoded from absorbed bytes; on a canonical vector it is the vector.
- **`vRd`**, **`vRd_trace`**: the group-vector reader, and on the verifier's own trace it returns the group's vector.
- `proxDec`, `proxDec_enc`: the proximity vector's decoder.
- `groupsAccept_congr_v`, `heads_single` (`hhd` of L20's chain theorems).

### 2.3 `LinkW16Glue.lean`: the composition on the real run (L22-1, L22-5)

- `EndTrue`, `OpenBlk`, `openTrue_of`: `OpenTrue` split into the endpoint claims and the block's own part.
- **`block_knowledge_acc_R`**, **`block_open_R`**, **`block_knowledge_target_R`**: L23's composition
  (`block_knowledge_target_gen`) re-done on `BlockAcc ∧ R` for any predicate `R` of the oracle, with `hsem` for
  `OpenBlk`, `hexec` on `BlockAcc ∧ R`, and the endpoint term: `Pr[BlockAcc ∧ R ∧ ¬Sat] ≤ εsTarget q + εend`, for
  EVERY `q`. Restricting the event is the same as wrapping the prover (the brief's suggestion): `BlockAcc` of the
  wrapped prover is `BlockAcc ∧ R` of the original.

### 2.4 `LinkW16GlueW16.lean`: the concrete chain, the kinds, `hexec` and `hsem` at a geometry

A geometry is `(h, Q, e)`: codeword length `2^h`, `Q` queries and pads, radius `e`, with `2e + (2^14 + Q) ≤ 2^h`.
W16R2 is `(15, 280, 8052)`; R13 is `(16, 256, 24448)`.

- `OProf` and its step parse (`W`, `W_at`, `W_r0` .. `W_r6`, `stpOK_vS`), the heads (`heads_len`, `heads_hd`), the
  trace split at the windows (`vS_trace`), the fit bounds, the extracted table and matrices (`colsM`, `UxW`).
- **The kinds**: `GMW`, `EvMW`, **`evMW_bound`** (`M`: `q·maskEps + 3·maskEps + coll`); `GOW`, `EvOW`, **`evOW_bound`**
  (a regular opening at any geometry: `(q·εA + εA + coll) + (q·εB + εB + coll)` with `εA = 2^h/|K|·bias` and
  `εB = ((2^h − e − 1)/2^h)^Q`). These are L20's `mask_knowledge_chain_pos` and `opening_knowledge_chain_pos` at the
  concrete chain, heads, `hℓ = 2^20` and `hhd`.
- `pcsOk_named`, `pcs_tr_after`: `PcsOk` with the parameters' numbers named; the transcript after an opening.
- **`mask_alt`**, **`opening_alt`**: an accepted `M` / regular opening satisfies its good predicate or its chain event.
- `RunAcc`, **`run_acc`**: on `BlockAcc` with the profile's header squeeze count, the chain the FS theorems read IS the
  verifier's trace, split at `M`'s, `A`'s and `H`'s windows, with the three accepted checks, the counters and the
  parse at the windows.
- **`hexec_geo`**: `hexec` on `BlockAcc ∧ (header squeeze count = the profile's)`, outside the extraction failure.
- **`hsem_geo`**: `hsem` for `OpenBlk` (every claim of `A` and `H`, `H`'s LogUp sum claim, every functional `M`
  received).
- **`open_cover_geo`**: both as one inclusion of events (§4).

### 2.5 `LinkW16GlueW16T.lean` and `LinkW16GlueR13.lean`: the two instances

- **`block_knowledge_open_w16r2`**: `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend` for EVERY `q`,
  at the W16R2 rung, with L10's fields (`maskField`, `pcsField`). `w16r2_budget_open`: its budget count.
- `opA_eps_r13` (`2^-110`, for a variable `p`, L7-4), `opB_eps_r13u` (`2^-126`), `r13_budget_open`.
- **`block_knowledge_open_r13`**: the same at the R13 rung, with L17's fields (`maskField`, `pcsFieldR13`), R13's
  relations and lookups, and R13's opening geometry. Its statement is generated from L23's
  `block_knowledge_target_r13` (`results/zk60_lean_l28_20261107/l28_mk_r13.py`).

## 3. Which premises of `block_knowledge_target_mt` remain, at W16R2 and at R13

`block_knowledge_target_mt` (L21) takes `hOpen : Pr[BlockAcc ∧ ¬OpenTrue] ≤ εopen`, which L20 / L23 reduce to `hM`,
`hEA`, `hEH`, `hX`, `hsem`, `hexec`. In the two theorems of §2.5:

| premise | at W16R2 | at R13 |
|---|---|---|
| `hM` (`M`'s chain bound) | PROVED (`evMW_bound`, `maskEps_le`: `2^-106`) | PROVED (the same) |
| `hEA`, `hEH` (the openings' chain bounds) | PROVED (`evOW_bound`; `opA 2^-111`, `opB 2^-113`) | PROVED (`evOW_bound`; `opA 2^-110`, `opB 2^-126`) |
| `hX` (extraction failure) | PROVED (L22's `extract_fail_block`, `xfail_T_w16r2`) | PROVED (`xfail_T_r13`) |
| `hsem` | PROVED for `OpenBlk` (`hsem_geo`) | PROVED (the same) |
| `hexec` | PROVED on `BlockAcc ∧ header` (`hexec_geo`) | PROVED (the same) |

`hOpen` in L21's literal form (on all of `BlockAcc`, with the endpoint claims inside `OpenTrue`) is NOT proved, and
it cannot be reached through `hexec` and `hsem` as L20 states them (L22-1, L22-5). What is proved is `block_open_R`'s
form: on `BlockAcc ∧ sqN header = hdrSq`,
`Pr[¬OpenTrue] ≤ (εM + εA + εH + εX) + εend`.

The premises the two theorems still take, beyond L23's own (the slot polynomials over the extracted data and the
per-outcome algebra, unchanged):

1. **The profile** `pr : OProf P` (HYPOTHESIS, bookkeeping): the tag keys, `S`, the rows and claim counts, the header's
   length and squeeze count, and four size bounds (the whole run at most `2^20` items, under `2^64` squeezes, each
   batching run at most `2^61`, `2S + 2 ≤ 2^20`). No concrete profile is constructed here (L28-4).
2. **The fields**: `P.maskVerify = maskField`, `P.pcsVerify = pcsField` (W16R2) or `pcsFieldR13` (R13), the rows
   `rowsOf`, `mI = 70` (W16R2) or `64` (R13). These define the profile; L10 / L17 proved the fields are the code's.
3. **`hcnt`** (HYPOTHESIS, L22-2): on every accepting run `A` has `nA` claims and `H` has `nH` (with its LogUp sum
   claim).
4. **`hRd`** (HYPOTHESIS, the rest of L22-7): a reader `accRd` of the slot phase's trace returns the verifier's
   functional list and its `A` and `H` claim lists on the verifier's own trace.
5. **`hcsA`, `hcsH`, `hms`**: the semantics `csX`, `msX` read the extracted matrices and table. These are definitions
   of `csX` and `msX`, not assumptions about the prover.
6. **`hrows`**, `hk`, `hkF`: the opened columns fit the oracle's input bound, `0 < nFunctionals ≤ 2^20`.
7. **`hEnd`** (HYPOTHESIS, run level, L22-5): `Pr[BlockAcc ∧ header ∧ ¬EndTrue] ≤ εend`.

### 3.1 The numbers

| | W16R2 | R13 |
|---|---|---|
| geometry `(h, Q, e)` | `(15, 280, 8052)` | `(16, 256, 24448)` |
| codeword length, tree depth | `2^15`, `15` | `2^16`, `16` |
| index squeezes `mI = ⌈Q/4⌉` | `70` | `64` |
| `2e + (2^14 + Q)` against `2^h` | `32,768 = 2^15` (tight) | `65,536 = 2^16` (tight) |
| `M`, per attempt (`maskEps_le`) | `2^-106` | `2^-106` |
| `opA`, per attempt | `2^-111` (`opA_eps_w16r2`) | `2^-110` (`opA_eps_r13`) |
| `opB`, per attempt | `2^-113` (`opB_eps_w16r2`) | `2^-126` (`opB_eps_r13u`; the true figure is `2^-172`) |
| extraction failure, `T'` | `q + 13,104` (`xfail_T_w16r2`) | `q + 12,800` (`xfail_T_r13`) |
| chain items per run, `ℓo` | at most `2^20` | at most `2^20` |
| block budget (`hbud` of `block_total_le_target`, limit `2^26 = 67,108,864`) | `30,263,665` (`w16r2_budget_open`) | `30,322,419` (`r13_budget_open`) |

Both block budgets are under `2^25`. L23's `r13_budget` allowed `38,579,953` because it assumed each regular round at
`2^-105` (L28-6).

## 4. The per-kind results, for lane L27

L24-7: the run-level joint count needs the per-kind pieces, not a per-block total. They are separate theorems, each
for a profile `pr`, a geometry and a prover `A` with at most `q` queries:

| piece | theorem | bound |
|---|---|---|
| `M`'s chain event `EvMW` | `evMW_bound` | `q·maskEps + 3·maskEps + collBound(q + 2^20 + 1) + collBound(q + 2^20 + 2)` |
| an opening's chain event `EvOW` (`A`: root at `hdrLen`, window `aA`; `H`: root at `hdrLen + 7`, window `aH`) | `evOW_bound` | `(q·εA + εA + coll) + (q·εB + εB + coll)` |
| the extraction failure `EvXB` | L22's `extract_fail_block` | `collBound T' + (2T'² + 4T')/|Dig|` |
| the cover | **`open_cover_geo`** | `BlockAcc ∧ header ∧ ¬OpenBlk ⊆ EvMW ∪ EvOW_A ∪ EvOW_H ∪ EvXB` |
| the two links separately | `hexec_geo`, `hsem_geo` | deterministic |
| the endpoint split | `openTrue_of`, `block_open_R` | `¬OpenTrue ⊆ ¬OpenBlk ∪ ¬EndTrue` |

The events are plain predicates of the oracle (`EvMW U hbij pr L h64 key domain hs hL accRd A`, and so on), so a run of
several blocks can union them per kind with its own counts.

## 5. Findings

- **L28-1 (Medium, shape of the result; follows L22-1 and L22-5).** `hOpen` as `block_knowledge_target_mt` states it
  is not discharged: it ranges over runs whose header squeeze count differs from the profile's (where the step parse,
  hence `hexec`, fails) and its `OpenTrue` contains the endpoint claims, which the block verifier does not open. The
  lane therefore re-composes L23's theorem on `BlockAcc ∧ R` with `OpenBlk` and an endpoint term
  (`block_knowledge_target_R`) rather than citing `block_knowledge_target_mt`. Every bound composed is the existing
  one. Consequence for L27: the run-level statement must (a) hold the header's squeeze count fixed, which the real
  verifier does, and (b) bound `εend` from the run's boundary and endpoint openings. No approved statement is
  narrowed.
- **L28-2 (Low, HYPOTHESIS `hRd`).** The reader of the accumulator (`acc.fs ++ acc.hostFs`, `acc.claims.a`,
  `acc.claims.h`) from the slot phase's trace is a premise. It asks that the verifier's functional and claim lists are
  a function of the trace it produced; the slot loop computes them from the absorbed proof and the squeezed
  challenges, so this is expected to hold, but it is not proved here.
- **L28-3 (Low, HYPOTHESIS `hcnt`).** The claim counts per opening are premises (L22-2). They fix the widths of the
  batching runs in the step parse.
- **L28-4 (Low, LEFT).** The theorems hold for every profile `OProf P` meeting its bounds; no `OProf` with the media
  app's real numbers (`S`, rows, claim counts, header length and squeeze count) is constructed. The bounds are loose
  (`2^20` items against about 2,000 for a rung block), but they are unchecked for a concrete profile.
- **L28-5 (Info).** One proof serves both profiles: `LinkW16GlueW16.lean` is generic in the geometry `(h, Q, e)` and in
  the opening parameters (it needs only `log_cols = 14`, `nQ = qPad = Q`, `nn = 2^h`, a column evaluator meeting
  `ColEncSpec`, and `pcsVerify` accepting only when `PcsOk` holds). The code facts come from `encLin_minDist` and
  `encLin_caOn` at `2e + (2^14 + Q) ≤ 2^h`, which is an equality at both W16R2 and R13 (the radius is tight).
- **L28-6 (Low, a figure other lanes use).** At R13's unique-decoding radius `e = 24448` the regular opening's rounds
  are `opA ≤ 2^-110` (one bit weaker than W16R2's `2^-111`: the codeword is twice as long) and `opB ≤ 2^-172`, stated
  as `2^-126` because the budget lemma takes exponents up to 126. L20's `opB_eps_r13` (`2^-105`, the δ/3 radius
  `e = 16298`) was an assumption for L17 to confirm; L24 §3 priced R13's `opB` with it ("`opB` at `2^-105` costs `2.1` M
  per kind"). With the proved figures a regular opening's two rounds cost `2^16 + 1` units, not `2^21 + 2^21`, and one
  R13 block is `30,322,419` units (`r13_budget_open`), under `2^25`. L27 should use these figures for R13's per-kind
  constants.
- **L28-7 (Info, method).** `PcsOk` mentions the parameters through projections (`prm.logCols`, `prm.nn`), and a
  statement with the numbers written out does not rewrite against it. `pcsOk_named` restates `PcsOk` with the numbers
  named, for any parameters; the instances then pass `rfl` proofs.

## 6. What is left

- LEFT (L28-2, L28-3): `hRd` and `hcnt`, for the real `define` schedule.
- LEFT (L28-4): a concrete `OProf` for the W16R2 rung and for the media app's R13 blocks.
- LEFT (run level, L27): `hEnd`, and the fact that the run fixes each block's header.
- Unchanged from L23: the slot polynomials over the extracted data and the per-outcome algebra (`hEval`, `hdeg`,
  `hvR`, `hgdR`, `hvH`, `hgdH`, `hbr`, `hhr`).

## 7. Checks

All in `results/zk60_lean_l28_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB).

- 2026-11-07: `warm.log` (the build cache was valid: 16 s) and `iter1.log` (`stage.sh`; the first build, admitted after
  62 minutes behind A28's GPU jobs: 8 errors in `LinkW16Pcs`, 1 in `LinkW16Glue`; the session was cut off as it ended).
- 2026-11-09: `iter2.log` to `iter7.log` (`l28_iter.sh`, with one log per module, `l28_i<N>_<module>.log`): the files
  brought to green. What was fixed:
  - `rw` closing a goal by `rfl`, so the tactics after it had no goal (`groupComb_K`);
  - `simp` rewriting `List.getD` to `getElem?` while a hypothesis kept the `getD` form (`groupWeights_oclOf`: `show`,
    then `by_cases`);
  - a higher-order pattern `∑ i, ?f ↑i` that `rw` cannot match (`sum_vecK_cwK`);
  - `rw` taking another instance of its pattern than the one meant (`List.drop_of_length_le`,
    `Block.opTrace_append`, `List.mem_append`, `runOps_append`): explicit arguments, or a lemma stated for the case
    (`drop_append_len`, `mem_vS_ops`, `vS_ops_length`);
  - `← hlen` rewriting every `w0` (`absAt_append_right'`);
  - the parameters' projections against written-out numbers (`pcsOk_named`, L28-7);
  - a `by` block continued on a line to the left of its first tactic (a parse error);
  - two copies of one 90-line derivation in the draft, replaced by one lemma (`run_acc`);
  - a hash argument left unassigned where unification went through a counter that does not depend on it
    (`ctr_squeeze`);
  - Lean 4.34's deprecations (`if_pos` / `if_neg`) and its unused-section-variable linter.

  Each build took 7 to 28 s once admitted, peak RSS 3.8 to 3.9 GiB. Waiting dominated: 12 to 23 minutes per job behind
  A28's GPU jobs and the other Lean lanes.
- **`check.log`** (`check_l28.sh`, job `lean-l28-check`, exit 0, 43 s, peak RSS 3.69 GiB, admitted after 23 minutes):
  - the six L28 modules built one target at a time, then the full build (`full.log`): **3,566 jobs, rc 0, 0 warnings,
    0 errors, no `sorry`**;
  - the axiom audit (`axioms_l28.lean`, written by `gen_axioms.py`: every `theorem` of the six files; `axioms.log`):
    **121 theorems**; 76 on `[propext, Classical.choice, Quot.sound]`, 28 on `[propext, Quot.sound]`, 17 on
    `[propext]`; no `sorryAx`, no `ofReduceBool`, no other axiom;
  - the source scan of the six files for the forbidden words: none;
  - the library root imports all six;
  - regressions: `L6Check` 1,206, `L5Check` 5,553, `L11Check` 404, the fixture L1 check 101,956; 0 failed.
- Not run by this lane: `ExecBlockCheck` and `CheckR13Block` (not in the brief's list; no file they read was
  changed), and the merged-tree check on perf.
