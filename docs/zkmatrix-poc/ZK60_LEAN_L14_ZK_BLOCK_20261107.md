# D63 step L14: zero knowledge for one W16R2 block receipt, and the hybrid to `ZeroKnowledge` (2026-11-07)

Lean lane L14 (Claude), on its own worktree branched from perf `6610324a` (L9 and L11 merged). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. Six new library files under `formal/ZK60Formal/`, imported by the library root:
`ZKW16Prog.lean`, `ZKW16Step.lean`, `ZKW16View.lean`, `ZKW16Block.lean`, `ZKW16Hyb.lean`, `ZKW16Shape.lean`. No Rust,
no prover source, no existing Lean file changed (only the root's import lines); `Statements.lean` is unchanged.
Evidence: `results/zk60_lean_l14_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CODE** (read off the sources), **ESTIMATE** (arithmetic or reasoning not proved in Lean).

## 1. In plain words, for Victor

**What this step is.** Your Statement 2 says the receipt hides the private data. In Lean it is `ZeroKnowledge`: a
simulator that never sees the input produces receipts no one can tell from real ones, except with a tiny,
stated probability. The earlier L4 lanes proved the pieces for FIXED challenges (each opening, each masked sumcheck,
`M`, the salted Merkle layer, the refusal). The assembly lane proved two generic tools (the random-oracle programming
lemma and the many-receipt hybrid) and left the per-profile work: the real Fiat–Shamir challenges, one block composed,
the hybrid's step, the simulator, the leakage and the error budget. This lane does that work for W16R2 (the 8B stack's
block profile), stated generically in the block's shape, so that the R13 blocks the real Shieldstral classifier runs
(A25's finding, 2026-11-07) and a whole classify run are further instances (§3.1).

**What is now proved.**
1. **The simulator** (`standinSim`): the honest prover run on a stand-in input that has the same public output and the
   same declared leakage. Its receipts are honest receipts of the protocol's own type (L9's block `Core` for the W16R2
   block instance), so they decode and verify like real ones.
2. **The declared leakage** (`Leak16`): the profile (model, shapes, slot schedule, D55 plan, hence the receipt length),
   the token count `T`, and the served bit. With your D65(2) constant refusal, the leakage determines what a refused
   request returns, which is exactly what the existing theorem says it must (`constRefusal_meets_leak_condition`).
3. **Fiat–Shamir done for the code's real points.** The code's challenges are hash outputs at TRANSCRIPT STATES, each
   state itself a hash output, so the points form a chain. A new lemma programs the whole chain at once
   (`aprog_real_ideal`): an exact coupling, whose only cost is a distinguisher guessing a fresh point beforehand or two
   points colliding.
4. **One receipt, honest versus simulated** (`fs_step`): for ANY context before and after the request, the honest
   receipt on the real input and on the stand-in are indistinguishable within an explicit error, if the receipt's view at
   fixed challenges has a data-independent law (the L4 lemmas).
5. **One block's whole view composed** (`block_view_law_eq_slots_M`): the two openings, ALL slots at once (of the three
   kinds: private, standalone, host), and `M`. The earlier composition handled one slot.
6. **The hybrid's step and `ZeroKnowledge`** (`hstep_of_oneStep`, `zeroKnowledge_of_oneStep`): the bookkeeping that
   turns "one receipt in a context" into hybrid `j` versus `j + 1` of the approved worlds, so the one-receipt theorem
   gives `ZeroKnowledge M P ε` exactly as `Statements.lean` states it.
7. **The W16R2 budget** (`w16Budget_le`, `w16r2_error_le_target`): with W16R2's counts, the error is within your
   approved `εzkTarget = q·2^-128 + R·2^-120` for EVERY number of hash queries `q` and every number of receipts
   `R ≤ 2^96` (about 8·10^28 receipts per weight set).
8. **All of it in one theorem** (`w16r2_zk_within_target`): for a protocol whose prover meets the instance obligations
   below, `ZeroKnowledge` holds with an error within `εzkTarget` for every `q` and every `R ≤ 2^96`.

**Generic in the block shape.** Nothing above depends on W16R2 except four counts (leaves, nodes, transcript
points, prover queries; `ZKShape`). So the same theorems serve the R13 blocks that the real Shieldstral classifier runs
(L17) and a whole classify run as one receipt (L18): one bit of the receipt cap per doubling of those counts; a full
26-block classify run is estimated at `R ≤ 2^85` receipts per weight set (§3.1).

**What needs your attention (finding L14-1, the assembly's A5 confirmed at W16R2 with numbers).** The approved target
quantifies over EVERY `R`, with no term mixing `q` and `R`. This proof's per-query cost is about `2^-237` per receipt
(the salted Merkle leaves dominate), where a cross-term-free target needs `2^-248` (`w16r2_rate_gt`, proved). So for
`R` above about `2^97` receipts the target does not follow from this proof. In practice this is irrelevant (a weight
set will never see `2^97` receipts), and a guessing attack is estimated to reach only about `q·2^-256`, so the target
is probably TRUE; the gap is in the proof's union bounds. Three ways out, the first one mine to do, the other two
yours to rule on: (a) a sharper per-query count (a query names one leaf content and one transcript counter), (b) a
cross term in the target, such as `+ q·R·2^-230`, or (c) a cap on the receipts per weight set, such as `R ≤ 2^96`.

**What this does not do yet** (§5). The Lean honest W16R2 block prover does not exist yet, so the theorems take it
as a structure (`FSModel`: its points, its receipt, which points the receipt shows) with crisp counting hypotheses
(fresh salts and fresh states give the counts) and the "links" of the layout (which claim value is which masked
terminal, which `M` functional is which `g(ρ)`). Writing that prover in Lean and discharging those hypotheses is the
next per-profile step; the counts it must give are named in `W16R2Z`. The run of several blocks and the token stages
are not done.

## 2. What is proved

All PROVED (`results/zk60_lean_l14_20261107/`; the axiom audit and source scan in §6).

**`ZKW16Prog.lean`: programming a chain of Fiat–Shamir points** (item a).

| Theorem / definition | Statement |
|---|---|
| `Causal`, `chainStep`, `chainVals` | points causal in the values (point `i` reads only the values before it); the honest chain = `k` passes of "ask the oracle at every point" |
| `chainVals_fix`, **`chainVals_unique`** | the honest chain is the unique solution of `w i = H(y w i)`: it is what the honest prover obtains by asking in order |
| `apReal`, `apIdeal`, `apGoodR`, `apGoodI` | on one space `(H, (σ, v))`: the honest world uses the chain of `H`; the programmed world uses fresh `v` and `H` programmed at `y v ↦ v`; the good sets: points distinct, not asked by `A₁` before the request, outside the dependency set `dep` |
| `apPsi`, `apPhi`, **`apPsi_spec`**, **`apPhi_spec`** | `(H, σ, v) ↦ (H[y(w) := v], σ, w)` and `(H, σ, v) ↦ (H[y(v) := v], σ, H∘y(v))` are mutually inverse bijections between the good sets that carry one world's event to the other's (not an involution: the chain moves with the oracle) |
| `apCount`, `apBad_card` | the counts: each world is at most the other plus the bad count; the bad count is at most `#{H : F}·(q₁·K + Kc)` |
| **`aprog_real_ideal`** | for any flag `F` of `A₁`'s result: `Pr[F ∧ honest] ≤ Pr[F ∧ programmed] + Pr_H[F]·(q₁·K + Kc)/|S × D^k|` and back; `K`: how many `(σ, v)` put a point on one query; `Kc`: how many make two points collide or land in `dep`; nothing about the queries after the request |
| `apReal_marginal`, `prob_filter`, `card_filter_prod` | the honest world over `(H, σ)` alone; uniform probabilities as counts |

**`ZKW16Step.lean`: one receipt in its context** (items 2 and 4).

| Theorem / definition | Statement |
|---|---|
| `FSModel`, `FSModel.prove` | a receipt model: `k` points `pts x c H v` (causal, reading `H` only at `dep`), the receipt `out x c v`, the visible points `vis` / `vp` (read off the receipt); the honest prover `out x c (chainVals (pts x c H) H)` |
| `progVis`, `progVis_agree` | the oracle programmed at the visible points only, a function of the receipt; it agrees with the fully programmed oracle away from the hidden points |
| `unprog_count` (Lemma U) | un-programming the hidden points (the unopened leaves) costs the collisions plus `A₂` asking a hidden point |
| `unprog_law_eq` (Lemma W) | with the hidden points un-programmed, an honest-verifier law equality at every value vector gives EQUAL counts for `x` and `x'` |
| `coll_card`, `hid_card`, `card_preimage_eq_of_map_eq`, `card_filter_prod_right` | the fibre-by-fibre counts |
| **`fs_step`** | honest on `x` versus honest on `x'`, any `A₁` (`q₁` queries) and `A₂` (`q₂` queries), any flag: at most `Pr_H[F]·(2(q₁·K + 2·Kc)/|C × D^k| + 2·q₂·KU/|C|)`, both ways |

**`ZKW16View.lean`: one block's whole honest-verifier view** (items 3 and 4).

| Theorem / definition | Statement |
|---|---|
| `slotView`, `SlotLink`, `slotView_shift` | a slot's view by kind (`cfsViewMasked` for a private slot, `cfsView` for standalone and host slots); the coin translate from its link |
| **`slots_shift`**, **`slots_law_eq`** | ALL slots at once: one translate of the product of the slots' mask spaces; the joint law of every slot's view is the same for any two families of rounds with the same links |
| `law_eq_prod`, `map_comp_law_eq` | two independent layers (the `A` and `H` openings); a receipt computed from the view |
| **`block_view_law_eq_slots_M`** | the openings (data-independent law), `ns` slots of any kinds and shapes (each linked to the openings' view: `hdef`), and `M` (its functional value a function of the views below: `hV`): the joint law of the whole view is the same for every data as for `d₀` |

**`ZKW16Block.lean`: the W16R2 profile** (items 1, 5).

| Theorem / definition | Statement |
|---|---|
| `Leak16`, `leak16`, `leak16_served` | the declared leakage: profile, `T`, served bit |
| `ConstRefusal`, **`constRefusal_meets_leak_condition`** | D65(2): with the served bit in the leakage, two inputs with the same leakage answered deterministically, one refused, get the SAME output: the premise of `refusal_output_must_be_leaked` cannot hold |
| `site_refusal_breaks_zk` | a refusal naming its site (the code before D65(2)) admits no simulator below error `1/2` |
| `standin`, `standin_spec`, **`standinSim`**, `standinSimulator`, `standin_hybStep` | the stand-in input (same public part and leakage), the simulator (a `ProgSim` programming nothing, hence a `Simulator`), its hybrid step |
| **`zeroKnowledge_of_hybrid_R`** | the hybrid with a step error that may depend on `R` |
| `W16R2Z.*`, `w16r2_rates` | the counts: 69,632 salted leaves, 69,629 nodes, at most 4,096 transcript points, at most `2^18` prover queries per receipt; rates `δprog + δhid ≤ 2^-237`, collisions `≤ 2^-124` |
| **`w16Budget_le`**, **`w16r2_error_le_target`** | the summed per-step error is at most `εzkTarget q R` for every `q` and every `R ≤ 2^96` |
| **`w16r2_rate_gt`** | the per-query, per-receipt rate `2(δprog + δhid)` exceeds `2^-248` (finding L14-1) |
| **`w16r2_zeroKnowledge`** | from the per-step bound: `ZeroKnowledge M P (min (Σ_j w16Step) 1)` with the stand-in simulator |

**`ZKW16Hyb.lean`: the hybrid's step from one receipt** (item d).

| Theorem / definition | Statement |
|---|---|
| `card_coord` | an event reading one coordinate only through its first argument splits along it |
| `prob_le_of_forall_fst`, `splitAt`, `extend_lt`, `extend_update`, `trunc`, `trunc_bounded`, `trunc_eq` | averaging a fibrewise bound; splitting off coordinate `j`; truncating a computation at its budget |
| `hans`, `runPos`, `runIdx`, `hyb_runPos`, `runPos_congr`, `runIdx_congr` | the stand-in hybrid's run with coins by POSITION (as `hybProb` draws them) and by REQUEST INDEX |
| **`reindex_count`**, **`hybProb_reindex`** | the two indexings give the same probability (each position is read at most once) |
| `pre`, `post`, `ctx₂`, `pre_bounded`, `post_bounded`, `runIdx_post`, **`runIdx_split`**, **`runIdx_split_succ`** | with the other indices fixed, hybrid `j` is `A₁` (before request `j`, `q + j·qp` queries) then the honest receipt then `A₂` (`q + R·qp`), and hybrid `j + 1` the same with the stand-in's receipt |
| `OneStep`, **`hstep_of_oneStep`** | a one-receipt bound `ε q₁ q₂` in every context gives hybrid `j` versus `j + 1` within `ε (q + j·qp) (q + R·qp)`, both ways |
| **`zeroKnowledge_of_oneStep`** | with a query-bounded honest prover: `ZeroKnowledge M P (fun q R => Σ_{j<R} ε (q + j·qp) (q + R·qp))` |
| **`oneStep_of_fsModel`** | `fs_step` gives `OneStep` for a protocol whose prover is an `FSModel`'s |
| `oneStep_mono`, `fsStep_err_le` | `OneStep` for a larger error; `fs_step`'s error in rate form `2·q₁·δp + 4·εc + 2·q₂·δh` |
| **`w16r2_zeroKnowledge_of_fsModel`** | the instance obligations (per weight set: an `FSModel` whose honest prover is the protocol's, given as a `qp`-query oracle computation; `hHV`; the counts `hK`, `hKc`, `hU` within rates `δp`, `εc`, `δh`) give `ZeroKnowledge M P (Σ_j w16Step δp δh εc qp q R j)` |
| **`w16r2_zk_within_target`** | with W16R2's rates (`W16R2Z`) and `qp ≤ 2^18`: that `ZeroKnowledge`, and its error `≤ εzkTarget q R` for every `q` and every `R ≤ 2^96` |

**`ZKW16Shape.lean`: the budget generic in the receipt's shape** (§3.1).

| Theorem / definition | Statement |
|---|---|
| `ZKShape`, `pts`, `δprog`, `δhid`, `εcoll`, `ZKShape.add` | a receipt's counts (`leaves`, `nodes`, `chain`, `qp`), its rates, and the sum of two shapes (a run) |
| `pow2_mul_inv_pow`, `count_le`, **`ZKShape.rates_le`** | `chain + 2·leaves + nodes ≤ 2^a` gives rates `≤ 2^-(256 − a)`; `pts ≤ 2^c` gives collisions `≤ 2^-(256 − 2c)` |
| `zkStep`, **`zkBudget_le`**, **`zkStep_within_target`** | the summed per-step error is within `εzkTarget q R` for every `q` and every `R ≤ 2^r` when `r + b + 123 + a ≤ 256` |
| **`zk_within_target_of_shape`** | the assembled statement with the shape as the parameter (L17, L18) |
| `W16R2Z.shape`, `W16R2Z.shape_fits`, `W16R2Z.shape_rates` | W16R2 as the instance `a = 19`, `b = 18`, `c = 18`, `r = 96` |

**The chain to the approved statement.** `oneStep_of_fsModel` (from `fs_step`, from `aprog_real_ideal` and the view's
law, from `block_view_law_eq_slots_M`) → `zeroKnowledge_of_oneStep` (from `hstep_of_oneStep` and
`zeroKnowledge_of_hybrid_R`) → `ZeroKnowledge M P ε`, assembled with the budget in `w16r2_zk_within_target`;
`Assembly.semanticHiding_of_zeroKnowledge` then gives `SemanticHiding` with `ε q 1`. What stays a hypothesis is the
instance: the Lean honest W16R2 prover as an `FSModel` with its counts and its view's law (§5).

## 3. The error budget against `εzkTarget`

Per hybrid step `j` (`fs_step` used twice, honest-to-programmed for `x` and back for the stand-in):
`2·(q₁·δprog + 2·εcoll) + 2·q₂·δhid`, with `q₁ = q + j·qp` (the distinguisher and the `j` earlier stand-in provers
before the request) and `q₂ = q + R·qp` (after it). W16R2's numbers (`W16R2Z`, the development rung's geometry from
L9's corpus: `enc_cols 32768`, `MASK_LOG_DOM` 12, end counter 1,609):

| Term | Count | Rate | Proved bound |
|---|---|---|---|
| programmed points before the request: transcript (fresh state each) | ≤ 4,096 (1,609 squeezes, about 420 absorbs) | `2^-256` each | |
| … salted leaves (fresh salt each) | 69,632 | `2^-256` each | |
| … Merkle nodes (two fresh children) | 69,629 | `2^-512` each | `δprog + δhid ≤ 2^-237` |
| hidden points after the request: unopened leaves | ≤ 69,632 | `2^-256` each | |
| collisions (pairs of the ≤ `2^18` points) | ≤ `2^36` | `2^-256` | `εcoll ≤ 2^-124` |
| prover queries per receipt `qp` | column hash + leaf per column, nodes, transcript: 212,989 | | `qp ≤ 2^18` |

- Summed over `R` steps: `≤ q·(2R·(δprog + δhid)) + R·(2R·qp·(δprog + δhid) + 4·εcoll)`.
- **PROVED** (`w16Budget_le`, `w16r2_error_le_target`): for every `q` and every `R ≤ 2^96` this is at most
  `q·2^-140 + R·2^-121 ≤ εzkTarget q R`.
- **PROVED** (`w16r2_rate_gt`): the per-query, per-receipt rate `2(δprog + δhid)` is above `2^-248`, so
  `zeroKnowledge_target_of_hybrid`'s condition fails; the query-free part (`4·εcoll ≈ 2^-218`) is far below its
  `2^-120`.
- Which term dominates: the salted leaves (139,264 of the ≈ 143,000 `2^-256`-units, before and after the request); then
  the `R²` term from the other receipts' provers inside each step's context, which is what caps `R` at about `2^97`.
- What would fix it (L14-1): see §4.

### 3.1 Generic in the block shape: the parameter for L17 (R13 blocks) and L18 (the classify run)

Coordinator's request (2026-11-07, after A25 found that the real Shieldstral classifier runs R13 blocks on the D12a
classify run, not W16R2). Everything above except the W16R2 counts is already generic; `ZKW16Shape.lean` adds the
budget with the shape as the parameter.

- **Generic, no profile in it:** the receipt model `FSModel` (its points, receipt, visible points, dependency set),
  the simulator `standinSim P` (any `Protocol`), the one-receipt step (`fs_step`, `OneStep`, `oneStep_of_fsModel`), the
  hybrid (`hstep_of_oneStep`, `zeroKnowledge_of_oneStep`), the view's composition (`block_view_law_eq_slots_M`: any
  number of slots, any kinds and shapes, so any plane list and range families; `law_eq_prod` for independent layers).
- **Where the block shape enters.** The plane list and the range families enter through the slots and their tables
  (the view's law, `hHV`); the rate and `log_cols` through the encoded widths (the shape's `leaves` and `nodes`); `Q`
  through the openings' law (`openingView_law_eq` needs the opened columns within the pads, `Q ≤ q_pad`) and the
  receipt's size, NOT through the rates (every leaf is counted, opened or not); `M`'s mask rows only through the column
  contents (one column hash per column whatever the rows), so not at all in the budget.
- **The parameter L18 takes: `ZKShape`** (`leaves`, `nodes`, `chain`, `qp`) and the obligations of
  **`zk_within_target_of_shape`**: an `FSModel` of the receipt per weight set whose honest prover is the protocol's,
  that prover as a `qp`-query computation, the view's law on an input and its stand-in (`hHV`), and the counts within
  the shape's rates (`hK`, `hKc`, `hU` with `hrK`, `hrKc`, `hrKU`). The conclusion: `ZeroKnowledge M P (Σ_j zkStep Z q R j)`
  with the stand-in simulator, within `εzkTarget q R` for every `q` and every `R ≤ 2^r`, where
  `chain + 2·leaves + nodes ≤ 2^a`, `qp ≤ 2^b`, `pts ≤ 2^c` (`2c ≤ 132`) and `r + b + 123 + a ≤ 256`, i.e.
  **`R ≤ 2^(133 − a − b)`**.
- **A run is one receipt.** The D12a classify run is one transcript end to end, so it is ONE `FSModel` (one stand-in
  simulator for the whole run, no per-block simulator), and its shape is the sum of its blocks', its stages' and its
  boundary commitments' shapes (`ZKShape.add`). The blocks enter through that sum and through the view's law (each
  block's composed view with its own independent coins; `law_eq_prod` combines independent layers). The per-receipt
  bound in `OneStep` form is the block parameter of `oneStep_of_fsModel`; `zkStep` is its rate form.
- **W16R2 is the instance** `W16R2Z.shape` with `a = 19`, `b = 18`, `c = 18`, `r = 96` (`W16R2Z.shape_fits`).
- **R13's numbers [ESTIMATE; L17 and L18 compute the exact `a`, `b` from their shapes].** At rate 1/4 the encoded width
  doubles at the same `log_cols`, so the leaves and nodes double. One R13 block at `log_cols` 14: about 135,000 leaves,
  135,000 nodes and a few thousand transcript points, so `chain + 2·leaves + nodes ≈ 410,000 ≤ 2^19` (`a = 19`) and
  `qp ≈ 410,000 ≤ 2^19` (`b = 19`): `R ≤ 2^95`. A whole Shieldstral classify run as one receipt (26 blocks, the IN and
  OUT stages, the boundary commitments) is about 26 times that: `a ≈ b ≈ 24`, so `R ≤ 2^85` receipts per weight set,
  still within `εzkTarget` for every `q`. The cap moves by one bit per doubling of the leaves or of the prover's
  queries; no term of the target changes.

## 4. Findings

No finding is a mismatch between the code and the approved statements; none weakens a statement or a target.

**L14-1 (Low; a ruling, or a sharper per-profile argument): the assembly's A5 confirmed at W16R2, with the numbers.**
- PROVED: this proof's per-query, per-receipt rate is above `2^-248` (`w16r2_rate_gt`; about `2^-237`), and its error
  is within `εzkTarget` for every `q` and every `R ≤ 2^96` (`w16r2_error_le_target`).
- For `R` between about `2^97` and `2^120` (where the target is still below `1`) the target does not follow from this
  proof, for two reasons: the `q·R·δ` cross term of A5 (dominated by the salted leaves), and an `R²·qp·δ` term (each
  step's context contains the other receipts' honest provers, whose queries are counted like the distinguisher's).
- ESTIMATE: a real distinguisher does much worse. A query `enc(content, salt)` names ONE content; with the pads the
  contents of one commitment are distinct except with probability about `N²·|F|^-rows`; so a query hits at most one leaf
  per commitment, and a squeeze query names its counter, one point per receipt. The attack advantage is then about
  `q·2^-256` per hit receipt, and the target is likely true.
- Options: (a) prove the sharper count (per-query multiplicity instead of the union over all points: the leaf contents
  distinct by the pads, the squeeze counter, the absorb labels and lengths), and separate the provers' own fresh queries
  from the distinguisher's; my estimate is that it brings the rate near `2^-247` (the absorbs that share a label are the
  binding constraint, about 296 round absorbs) and removes the `R²` term; (b) a cross term in the target; (c) a cap on
  `R` per weight set (`R ≤ 2^96` is proved now). (b) and (c) change the approved statement and need your ruling.

**L14-2 (Info, modelling): the chain-state points are handled directly.** The code's Fiat–Shamir points are transcript
states (CODE: `ExecTranscript.lean`, an absorb `H(key; s ‖ …)`, a squeeze `H(key; s ‖ "squeeze" ‖ le64 ctr)`). The
assembly suggested first replacing "the first fresh chain digest by a uniform value"; `aprog_real_ideal` programs the
whole causal chain (leaves, nodes, transcript) with one exact bijective coupling instead. The points may read the
oracle at a dependency set (the column hashes, keyed apart by D19 T-1, and the PUBLIC header's chain points, which must
not be programmed since the distinguisher can compute them); a programmed point landing there is a bad event, counted
with the collisions. (A first draft asked every point to be of a programmed kind for every value vector, which the
code cannot meet, since a fresh state can equal a header state; it was replaced by the dependency set before any
commit.)

**L14-3 (Info): the simulator programs nothing (finding A6's route), and why.** `standinSim` runs the honest prover on a
stand-in with the same public output and leakage. Its hybrid steps are honest-versus-honest against the real oracle, so
the hybrid's programmed table stays empty, and programming is a proof device inside each step. The price is a factor
2 in each step (two programming passes). A programming simulator would save that factor but needs its points disjoint
from the earlier receipts' table, which adds a term per earlier receipt.

**L14-4 (Info; answers L11-4): `ν`'s nonzero refusal is not needed for zero knowledge.** In the composed view
(`block_view_law_eq_slots_M`) `M`'s layer needs only that its functional value be a function of the slots' views (`hV`),
which the verifier's own computation of the functionals guarantees for every `ν`. With `ν = 0` a hosted slot's total
simply drops out of its host's `Γ`; nothing else changes. The refusal itself is challenge-only (class C), so keeping it
costs nothing in `εzk` and `2/|F|` in completeness. Not changed.

**L14-5 (Info): the leakage determines the refusal output.** With `Leak16` (profile, `T`, served) and D65(2), the premise
of `refusal_output_must_be_leaked` cannot hold (`constRefusal_meets_leak_condition`); a prover that named the refusal
site again would break `ZeroKnowledge` at any error below `1/2` (`site_refusal_breaks_zk`). The receipt length is a
function of the profile (`Geom.forkLen`), so it is in the leakage too. The classifier's verdict (D58/D61) is
`IntModel.publicPart`, outside `Leak16`, as `Statements.lean` has it.

**L14-6 (Low, for the Lean prover to come): two modelling conditions on the honest prover.** (i) `zeroKnowledge_of_oneStep`
needs the honest prover as a query-bounded oracle computation (`pOC`, `qp` queries); (ii) `oneStep_of_fsModel` needs it
in the `FSModel` form: every value the receipt depends on is the oracle's answer at a point of the chain, and the points
read the rest of the oracle only at the dependency set. The code's prover has both shapes (CODE: the column hash, the
salted leaf, `MerkleTree::build`, the transcript), but the Lean prover must be written so.

## 5. What is left

- **The Lean honest W16R2 block prover as an `FSModel`** in L9's receipt type (`Core`): its points (every salted leaf,
  every node, every transcript point of `blockOps`, `maskTranscript`, `pcsTranscript`), its receipt, its visible points
  (the opened set `J` from the challenges), its dependency set; and its `pOC`. Then discharge `hK`, `hKc`, `hU` from
  its structure (fresh salts, fresh states, the counter); the counts in `W16R2Z` are what they must give.
- **`hHV` from `block_view_law_eq_slots_M`**: the links (item b) as Lean functions of the registered layout: each slot's
  masked terminals as claim values (`slotClaims`, `buildClaim`), `M`'s functionals as `g(ρ)` and `Γ` (`slotAcc`'s
  `fs` and `hostFs`), `CfsMask`'s layout as `M`'s a-rows (`mask_aRows_law_eq`, `codePub`), and the openings' layer at the
  opened set (`openingView_law_eq`, `openingViewH_law_eq`, `law_eq_prod`).
- **L14-1**: the sharper count (a), or your ruling (b) or (c).
- **The run** (item c): `L` block receipts on the D55 tree or the D12a frame are one receipt of a run `FSModel` (the same
  theorems; the run's points and the boundary commitments); the token stages IN-C and OUT-C; at the DD and next-token
  profiles the class (E) refusal term `N/|Fp2|` per block (`logup_attempt_prob_le`).
- **W16R3**: B1 changes the openings' `out` and `pts` (coefficient-form rows), B2 the slot list and draws (`slots_shift`
  is generic in the slot list and kinds), B3 the layout; the theorems of this lane are unchanged, the instance and the
  counts are swapped.

## 6. Checks

All in `results/zk60_lean_l14_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB; caps 10–12 GiB while iterating, 24 for the check):
- `file1.log` … `file9.log`: the files while they were written (`stage.sh`; peak RSS 3.7–3.8 GiB, 11–24 s of build
  each; most of the wall time was the shared heavy lock). The errors fixed on the way are in those logs: lambda binders
  whose type could not be inferred, decidability of filters over `Prop`-valued predicates (`open Classical in`),
  Finset membership unfolded to `Quot.lift` by a `simp … at` (replaced by `mem_filter.mp/.mpr` terms), a
  `whnf` timeout in the slot composition (explicit implicit types), this Mathlib's names (`mul_le_mul_left'` →
  `mul_le_mul_right`, `add_le_add_left` and `_right` swapped, `if_pos`/`dif_pos` → `ite_eq_left`/`dite_eq_left`,
  `ENNReal.mul_lt_mul_right`'s implication form, `Set.mem_ofPred_eq`), and a line break before `.toOuterMeasure`.
- `check.log`: `check_l14.sh`, run three times (appended; the last run is the current tree), which runs:
  - the full build (`full.log`): **3,468 jobs, rc 0, 0 warnings, 0 errors, no `sorry`**;
  - the axiom audit (`axioms_l14.lean`, written by `gen_axioms.py`, → `axioms.log`): **80 theorems**, 65 on
    `propext, Classical.choice, Quot.sound`, 5 on `propext, Quot.sound`, 3 on `propext`, 1 on `Quot.sound`, 6 on none;
    `sorryAx` and `Lean.ofReduceBool` nowhere;
  - the source scan of the six files for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
    `implemented_by`, `@[extern]`, `bv_decide`, `ofReduceBool`: the only matches are the header sentence "no `sorry`,
    axiom or `native_decide`" of each file;
  - the root imports the six files;
  - the regressions: **L6Check 1,206 checks, L5Check 5,553 checks, L11Check 404 checks, 0 failed**.
