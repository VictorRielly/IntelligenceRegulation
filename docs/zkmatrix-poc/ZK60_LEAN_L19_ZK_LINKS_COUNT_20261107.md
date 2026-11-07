# D63 step L19: zero knowledge, the layout links and the sharper count (2026-11-07)

Lean lane L19 (Claude), on its own worktree branched from perf `73f733fd` (L9–L15 merged). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. Seven new library files under `formal/ZK60Formal/`, imported by the library root:
`ZKLinks.lean`, `ZKLinksM.lean`, `ZKLinksRun.lean`, `ZKCount.lean`, `ZKCountStep.lean`, `ZKCountHyb.lean`,
`ZKCountBudget.lean`. No Rust, no prover source, no existing Lean file changed (only the root's import lines);
`Statements.lean` is unchanged. Evidence: `results/zk60_lean_l19_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off the
sources, file:line), **ESTIMATE** (arithmetic or reasoning not proved in Lean).

## 1. In plain words, for Victor

**What this step is.** Lane L14 proved zero knowledge (your Statement 2) for one block receipt, with two things left
open: (i) a hypothesis `hHV` ("the receipt's law at fixed challenges does not depend on the private data"), which was to
come from L14's composed-view theorem once the layout's links are written down; and (ii) a receipt cap: the error was
within your approved `εzkTarget = q·2^-128 + R·2^-120` only for at most `R = 2^96` receipts per weight set, because
the proof charged every hash query at one worst-case rate. This lane does both.

**(i) The links, written down.** The view of one block is now assembled from the layout as Lean functions, and `hHV`
is a THEOREM (`hHV_of_blockLinks`), from properties of the honest prover that are stated by name, so that L18 (who
writes the prover's specification) can discharge them one by one:
1. which slot claim value is which masked terminal (`terminal_of_claims`): a slot's final value is its polynomial of the
   claim values the `A` and `H` openings show;
2. which `M` functional is which `g(ρ)` or `Γ` (`MFun`, `codeFuns`, `mfMask_eq_mfView`): the code's list in the code's
   order, and for an honest prover each functional's value on the masks is the value the verifier computes from the
   views;
3. a host slot's published scalar is a function of the views (`hostScalar_of_views`);
4. the `A` and `H` openings at the opened set have a law that does not depend on the data (`openingsAH_law_eq`).

Everything is generic in the block's shape (slot count, kinds, sizes, `M`'s geometry), so the R13 blocks that the real
Shieldstral classifier runs are an instance, as are W16R3's.

On the way I found that L14's description of a HOST slot (as an unmasked slot) does not match the code: the code masks
the host's claimed sum too, and only a standalone slot is unmasked. With the correct kinds (`maskedOfKind`) the links
hold; with L14's description they could not. Nothing L14 proved is wrong (its theorem takes the kinds as a parameter);
this is a modelling correction for whoever instantiates it (finding L19-1).

**(ii) The sharper count: the cap is gone from the theorem.** The code keys every hash by its role (column digest,
salted leaf, Merkle node, Fiat–Shamir), so a query of one kind can only meet points of that kind. I re-proved the
one-receipt step and the many-receipt hybrid with EACH query charged at the rate of its own kind (`ZKCountStep`,
`ZKCountHyb`). The result (`zk_every_R`, PROVED): zero knowledge with the stand-in simulator, with an error within your
approved target for EVERY `q` and EVERY `R`, no cap, whenever three rate conditions hold. A shape criterion
(`ZKKinds.every_R`, PROVED) turns them into counts: at most 2 transcript points met by one query, at most `2^13`
for (transcript points × that multiplicity), and enough bits of freshness in the column digests (the pads give them
hundreds).

- **One W16R2 block and one R13 block meet the criterion** (`W16R2K.every_R`, `R13K.every_R`, PROVED arithmetic on
  counts by kind that are an ESTIMATE until L18's prover gives them): the receipt cap is gone for block receipts.
- **A whole classify run as ONE receipt does not** (finding L19-2): its transcript is about 14 times longer and, since
  the slot-index absorb repeats in each of the 26 blocks, one query meets up to 26 of its states. The proof then gives
  the target for every `R ≤ 2^112` receipts per weight set (`RunK.cap_112`), not for every `R`. The term that blocks it
  is real, not slack in the proof: the OTHER receipts' honest provers ask the hash at their own transcript states, and
  two receipts' states coincide (at the same squeeze counter) with probability about `R²·(transcript length)·2^-256`
  in total, which at `R ≈ 2^118` is already about 5%. The choice of fix is yours (§4, L19-2): (b) a cross term in the
  target, (c) a cap (`2^112` is proved for the run), (d) a protocol change for W16R3, a per-receipt transcript key (my
  estimate is that it removes the term), or (e) a sharper proof that these coincidences do not help a distinguisher
  (they have the same law in both worlds), which this lane does not attempt.

**(iii) If time allows, the stages.** A run's view as a family of independent layers (blocks, the IN-C and OUT-C
stages, the boundary commitments) is now one theorem (`law_eq_pi`, `hHV_of_layers`), and a run's counts are the sum of
its layers' (`ZKKinds.add`). The stages' own slot lists are not instantiated here.

**What this does not do yet** (§5). The Lean honest prover does not exist yet, so the counts by kind and the named
honest-prover properties are hypotheses (the instance obligations); L18 writes that prover's specification. The
column digests must be modelled as programmed points for the sharper count (finding L19-3).

## 2. What is proved

All PROVED (`results/zk60_lean_l19_20261107/`; the axiom audit and source scan in §6).

**`ZKLinks.lean`: the links as factoring hypotheses, and `hHV`** (item 1).

| Theorem / definition | Statement |
|---|---|
| `slotDefect`, `slotLink_iff` | what a slot's simulation must match, as one value (masked: middle defects and terminal; unmasked: the whole chain defects); `SlotLink` is its equality |
| `slotDefect_honest` | an honest slot (zero gaps, a standalone's claimed sum `0`) has defect `(0, 0, T)`, `T` its terminal |
| `defectRep`, **`hdef_of_defectFun`** | if every slot's defect is a function `δ` of the openings' view, a representative round family exists and meets L14's `hdef` (no rounds need be built) |
| `defectFun_of_terminals` | honest slots whose terminals are a function of the openings' view have defects that factor |
| `mRep`, **`hV_of_mFactor`** | if `M`'s functional value is a function `Φ` of the views below, a representative message family meets L14's `hV` |
| **`block_view_law_eq_links`** | L14's `block_view_law_eq_slots_M` with the two factoring hypotheses in place of its chosen functions |
| **`hHV_of_view`** | a receipt read off a view whose law does not depend on the data (at every value vector), through coins pushed to uniform view coins, has the same law on any two inputs |
| **`hHV_of_blockLinks`** | the assembled link: the block's composed view at every value vector (openings, every slot of any kind and shape, `M`), the factoring links and the receipt read off that view give `hHV` for every two inputs |
| `hHV_standin` | the same in the stand-in form `zk_within_target_of_shape` and `zk_every_R` take |

**`ZKLinksM.lean`: the per-profile links as Lean functions** (item 1).

| Theorem / definition | Statement (CODE: `hashline/src/private_block/argument.rs`) |
|---|---|
| `slotView_true`, `slotView_false`, `slotView_eval` | a slot's view by kind; `g(ρ)` is the view's third part for either kind |
| **`hostScalar_of_views`** | an honest host (unmasked sum `Σ ν_k·S_k`, the host polynomial's cube sum) publishes `c·G − Σ ν_k·c_k·G_k` (argument.rs:1273-1275) = its masked claimed sum minus the hosted slots' masked scalars: a function of the slot views |
| **`terminal_of_claims`** | a slot with an honest sumcheck and an identity extension round, whose masked terminals are the claim values `claimVal x (claimOf i)` (argument.rs:1471-1476, `build_claim`), has zero gaps and terminal `poly(claim values)` |
| `MFun`, `mfMask`, `mfView`, `MHonest` | `M`'s functionals (argument.rs:1478-1495): a standalone `Γ` (`c·G`), an evaluation (`g(ρ)`), a host `Γ` (`c·G − Σ ν_k·c_k·G_k`); their value on the masks and from the views; the honest prover's conditions |
| **`mfMask_eq_mfView`**, `mfComb_eq_viewComb` | for an honest prover every functional's value on the masks is the verifier's value from the views; so is the θ-combination at offset 1 (`θ^(i+1)`, D65(1)) |
| `mPhi`, **`mFactor_of_funs`** | from the layout hypothesis "`M`'s committed messages and weights carry the θ-combined functional" (`hMK`, read in `Fp2` by `fp2`, injective), `M`'s functional value is a function of the views: `block_view_law_eq_links`'s `hM` |
| `hMK_of_K` | `hMK` from the same statement about `Fp2` values (the coefficients against the combined weights, `fp2_mVal`, `U² = κ`) |
| **`maskedOfKind`** | the code's kinds as view kinds: private and host masked, standalone unmasked (finding L19-1) |
| `w16r2_hosted_priv`, `w16r2_hosts_two` | (`decide`) every W16R2 host hosts exactly two private slots, each earlier in the transcript; only hosts host |
| `codeFuns`, **`codeFuns_honest`**, `codeFunsAt`, `codeFunsAt_honest` | the functional list in the code's declared order ("[Γ_s if standalone] eval_s; host Γs last"), and its honest conditions from the hand-off (hosted slots masked) and the honest host sums |
| `padSurj_of_points`, **`openingsAH_law_eq`** | the openings' layer at the opened set: at most `Q` distinct opened points outside the message domain make the pad blocks surjective; the `A` and `H` openings together (independent coins, `H`'s honest data summing to zero) have a data-independent joint law: `hA` |

**`ZKLinksRun.lean`: a run as independent layers** (item 3, generic).

| Theorem | Statement |
|---|---|
| `map_eq_of_card` | equal preimage counts, equal laws |
| **`law_eq_pi`** | a `Fin n` family of layers on independent coins, each with a data-independent law, has a data-independent joint law |
| **`hHV_of_layers`** | a run receipt read off such a family (blocks, stages, boundary commitments) has `hHV` for every two inputs |

**`ZKCount.lean`: weighted budgets and the per-point counts** (item 2).

| Theorem / definition | Statement |
|---|---|
| `WB`, `WB.mono`, `WB.bind`, `WB_of_bounded`, `WB.queries_sum`, `sum_toFinset_le`, `WB.toFinset_sum` | a weighted query budget (the weights of the questions asked add up to at most `W` on every path); monotone, additive under composition, implied by an `n`-question bound at weight `≤ w`, and bounding the asked questions' weights |
| `wtrunc`, `wtrunc_wb`, `wtrunc_eq` | the weighted truncation; within budget it changes nothing |
| `within_mono` | `OC.Within` budgets can be raised |
| `hit_card_le_sum`, **`hit_card_label`** | a query's hits are at most the sum over points; with labels read off the points (the key, a squeeze's counter, an absorb's label and data), only the points of the query's label count: the MULTIPLICITY bound |
| **`fresh_card`** | a point injective in a fresh coordinate is met by a given query for at most `1/|fresh|` of the outcomes |
| **`hidden_card_of_cond`** | hidden points with conditional min-entropy given the receipt: a query set read off the receipt catches one for at most `k·B/N` of the coins (`hU` in weighted form) |

**`ZKCountStep.lean`: one receipt, every query at its own rate** (item 2).

| Theorem / definition | Statement |
|---|---|
| `apBad_card_w` | the chain-programming bad set with per-query hit counts `Kf z` and a weighted budget `W₁`: at most `Pr_H[F]·(W₁ + Kc)` |
| `hid_card_w` | the hidden hits with per-query hit counts and a weighted budget `W₂`: at most `Pr_H[F]·|D^k|·W₂` |
| **`fs_step_w`** | honest on `x` versus honest on `x'`, both ways, within `Pr_H[F]·(2(W₁ + 2·Kc)/|C × D^k| + 2·W₂/|C|)` |
| `OneStepW`, **`oneStepW_of_fsModel`**, `oneStepW_mono` | the per-receipt bound in every context of weighted budgets, for a protocol whose prover is an `FSModel`'s |

**`ZKCountHyb.lean`: the hybrid with weighted budgets** (item 2).

| Theorem / definition | Statement |
|---|---|
| `pre_wb`, `post_wb` | before request `j`: the distinguisher's `q` queries (weight `≤ Km` each) and `j` stand-in provers (`≤ Wp` each), within `q·Km + j·Wp`; after it: `q·KUm + R·Wpa` |
| `pre_cont`, `ctx₂W`, `ctx₂W_wb`, `ctx₂W_eq` | request `j`'s continuation stays within the distinguisher's budget, so the weighted truncation of the context changes nothing on the hybrid's own runs |
| **`hstep_of_oneStepW`** | hybrid `j` versus `j + 1` within `ε (q·Km + j·Wp) (q·KUm + R·Wpa)`, both ways |
| **`zeroKnowledge_of_oneStepW`** | `ZeroKnowledge M P (Σ_{j<R} e q R j)` with the stand-in simulator, for any per-step bound `e` uniform in the weight set |

**`ZKCountBudget.lean`: the budget, every `q`, every `R`** (item 2).

| Theorem / definition | Statement |
|---|---|
| `wStep`, `fsStepW_le_wStep` | the per-step error in rate form: `2(q·δp + j·ωp) + 4·εc + 2(q·δh + R·ωh)` |
| **`wBudget_le`** | within `εzkTarget q R` for every `q` and every `R ≤ 2^r` when `2^(r+1)(δp + δh) ≤ 2^-128` and `2^(r+1)(ωp + ωh) + 4·εc ≤ 2^-120` |
| `one_le_target_of_large` | at `R ≥ 2^120` the target is at least `1` |
| **`wBudget_every_R`** | with `δp + δh ≤ 2^-249`, `ωp + ωh ≤ 2^-242`, `εc ≤ 2^-124`: the error capped at `1` is within the target for EVERY `q` and EVERY `R` |
| **`zk_every_R`** | the assembled statement: `ZeroKnowledge` (Statements.lean's) with that error, within `εzkTarget q R` for every `q`, `R`; every instance obligation an explicit hypothesis |
| `ZKKinds`, `δp`, `ωp`, `δh`, `ωh`, `εc`, `pts`, `add` | a receipt's counts by hash kind and their rates; a run's counts are the sum of its layers' |
| `term_le`, `five_le`, `one_four_le`, `δ_le_gen`, `δ_le`, `ω_le`, `εc_le` | the rates from counts in powers of two |
| **`ZKKinds.every_R`** | the shape criterion for every `R`: `mT ≤ 2^4`, `qpT·mT ≤ 2^13`, the other counts `≤ 2^c` with `2c + 252` bits of column freshness, `pts ≤ 2^p` with `2p + 124 ≤ 256` |
| **`ZKKinds.cap_R`** | with only `qpT·mT ≤ 2^b` and `mT ≤ 2^a`: within the target for every `R ≤ 2^r`, `r + b ≤ 133`, `a + r + 132 ≤ 256` |
| `W16R2K.kinds`, **`W16R2K.every_R`**; `R13K.kinds`, **`R13K.every_R`** | one W16R2 block (`c = 18`) and one R13 block (`c = 19`) meet the criterion (counts: ESTIMATE) |
| `RunK.kinds`, `RunK.not_every`, **`RunK.cap_112`** | a whole classify run as one receipt fails the criterion's transcript conditions and is within the target for every `R ≤ 2^112` (counts: ESTIMATE) |

**The chain to the approved statement, now.** `oneStepW_of_fsModel` (from `fs_step_w`, from L14's
`aprog_real_ideal`-counting `apCount` and the view's law `hHV`, from `hHV_of_blockLinks`, from
`block_view_law_eq_links`) → `zeroKnowledge_of_oneStepW` (from `hstep_of_oneStepW` and L14's
`zeroKnowledge_of_hybrid_R`) → `ZeroKnowledge M P ε` with the budget in `zk_every_R`, within `εzkTarget q R` for every
`q` and `R`. L14's `zk_within_target_of_shape` (uniform rates, `R ≤ 2^(133 − a − b)`) stays valid; with constant
weights (`WB_of_bounded`) the weighted step gives back its uniform bound.

## 3. The budget against `εzkTarget`: is the receipt cap gone?

**In the theorem: yes.** `zk_every_R` has no receipt cap: its error, capped at `1`, is within `εzkTarget q R` for
every `q` and every `R`, under three rate conditions:

| Condition | Meaning | Why it suffices (PROVED, `wBudget_every_R`) |
|---|---|---|
| `δp + δh ≤ 2^-249` | one distinguisher query's worst chance of meeting a programmed point before the request, plus a hidden point after it | the `q`-term: `2R(δp + δh) ≤ 2^-128` for `R < 2^120` |
| `ωp + ωh ≤ 2^-242` | one OTHER receipt's honest prover, over all its queries each at its own kind's rate, before and after | the `R`-term: `2R(ωp + ωh) ≤ 2^-121` for `R < 2^120` |
| `εc ≤ 2^-124` | two points of one receipt collide or land in the dependency set | `4·εc ≤ 2^-122` |

For `R ≥ 2^120` the target is at least `1` (`one_le_target_of_large`), so the capped error is within it.

**Why L14's proof could not reach it, and what changed.** L14 charged the other receipts' provers inside each step's
context at the distinguisher's worst single-query rate, about `2^-255`, for all `2^18` of their queries: `2^-237` per
other receipt, above the `2^-242` needed. Their column-digest, leaf and node queries can only meet points of `320` to
`512` bits of freshness; only their transcript queries (about `2^12`) meet points of `2^-256`. Charging each at its own
kind's rate gives `ωp ≈ 2^12·2·2^-256 = 2^-243`.

**At a shape** (`ZKKinds.every_R`; counts by kind ESTIMATED from L9's corpus and the code until L18's prover gives
them):

| Receipt | Transcript points × multiplicity (`qpT·mT`) | Columns, leaves, nodes (`2^c`) | `δp + δh` | `ωp + ωh` | Result (PROVED from the counts) |
|---|---|---|---|---|---|
| one W16R2 block (`W16R2K`) | `4,096 × 2 = 2^13` | `≤ 2^18` | `≤ 2^-249` (about `2^-255`) | `≤ 2^-242` (about `2^-243`) | every `R` |
| one R13 block (`R13K`, rate 1/4) | `4,096 × 2 = 2^13` | `≤ 2^19` | `≤ 2^-249` | `≤ 2^-242` | every `R` |
| a whole classify run as one receipt (`RunK`) | `57,344 × 32 ≈ 2^20.8` | `≤ 2^23` | `≤ 2^-241` | about `2^-235` | `R ≤ 2^112` (`cap_112`) |

The counts behind the rows [ESTIMATE]: W16R2's transcript has 1,609 squeezes and about 420 absorbs after the header
(L9's corpus; bounded by 4,096); a query meets at most 2 of its points at `2^-256` each (a squeeze names its counter,
`pb-slot` names its slot, every other absorb carries masked data: `sc-round`, `pb-scalar`, `pb-term`, `pcs-vec`,
`pcs-prox`, `mask-q`, `mask-prox`, or a fresh root; CODE: argument.rs:1171, 1277, 1468; zk.rs:639-719, 1186, 1404;
pcs.rs:429-511; sumcheck.rs:114-411). Columns and leaves: `32,768 + 32,768 + 4,096`, nodes one fewer per tree (L14's
`W16R2Z`). Column freshness: `320` bits before the request (at least 5 padded Goldilocks rows per commitment), `300`
given the receipt (the rows beyond the view's linear constraints). For the run: 26 R13 blocks plus the stages and
boundary commitments (`28 × 2,048` transcript points, `28 × 135,168` columns); `mT = 32` because `pb-slot`'s datum is
the slot index, not the block's, so the same slot's absorb in each of the 26 blocks counts.

## 4. Findings

No finding is a mismatch between the code and the approved statements; none weakens a statement or a target.

**L19-1 (Low, modelling; corrects L14's description of a host slot).**
- CODE: a host publishes `c·G − Σ_k ν_k·c_k·G_k` (argument.rs:1273-1275); its claimed sum is that plus
  `Σ_k ν_k·scalar_k` (argument.rs:1440), i.e. `Σ_k ν_k·S_k + c·G`, where `S_k` are the hosted private slots' true sums.
- So a host is a MASKED slot in the view (`cfsViewMasked`, `masked = true`): its own mask total `G` hides `Σ ν_k·S_k`.
  L14's text describes it as unmasked ("a host slot `c·G` of a claimed sum computed from the earlier scalars"); as an
  unmasked slot (`cfsView`, which shows `G`) its link would need `Σ ν_k·S_k`, private data, to be a function of the
  openings' view, which it is not.
- No privacy issue in the code. Nothing L14 proved is wrong: `block_view_law_eq_slots_M` takes the kinds as a parameter.
  `maskedOfKind` records the right assignment; `hostScalar_of_views` shows the published scalar is a function of the
  views; `codeFuns_honest` uses it. Whoever instantiates the view must use `maskedOfKind`.

**L19-2 (Low, for Victor: a ruling or a protocol change; the receipt cap for a multi-block receipt).**
- PROVED: no receipt cap in the theorem (`zk_every_R`); one W16R2 block and one R13 block meet its conditions at the
  estimated counts (`W16R2K.every_R`, `R13K.every_R`).
- PROVED: a whole classify run as one receipt, at the estimated counts, fails the criterion's transcript conditions
  (`RunK.not_every`) and is within the target for every `R ≤ 2^112` (`RunK.cap_112`). With distinct per-block slot
  absorbs (`mT = 2`) the same proof gives `2^116` [ESTIMATE].
- The blocking term: `ωp`'s transcript part, `qpT·mT·2^-256` per other receipt: each other receipt's honest prover asks
  the hash at its own transcript states, and meets this receipt's state at the same counter with chance `2^-256`. This
  is the actual probability of cross-receipt transcript coincidences, summed: about `R²·qpT·2^-256`; at `R ≈ 2^118` and
  the run's `qpT ≈ 2^15.8` it is about `2^-4` [ESTIMATE]. No per-query count removes it; the hybrid's own slack (the
  stand-in simulator's double pass, `j ≤ R` for the earlier provers, `R` for the later ones; about `8×`) moves the cap by
  at most three bits (L19-4).
- Options: (b) a cross term in the target, e.g. `+ R²·2^-238`; (c) a cap of `R ≤ 2^112` receipts per weight set for a run
  receipt; (d) for W16R3, a per-receipt transcript key (the transcript keyed by a fresh nonce published in the receipt):
  the other receipts' queries are then under other keys, and the term drops to the nonces' collisions, `R²·2^-256`
  [ESTIMATE]; (e) a different proof that couples the coincidences (they have the same law in the real and the stand-in
  worlds), not attempted. (b), (c) and (d) are yours to rule on.

**L19-3 (Info, modelling guidance for L18's instance): the column digests must be programmed points.**
- L14's W16R2 model put the column digests in the dependency set. Then a salted leaf's point is `(H(column), salt)`
  and, for a fixed oracle (the counts hold for every oracle), all of a commitment's leaves may share the content, so one
  leaf query can meet every leaf: L14's `69,632·2^-256` is then tight.
- With the column digests among the programmed points (each column has at least 5 padded rows, so `≥ 320` bits; an
  unopened one keeps its pads beyond the view's linear constraints given the receipt, `hidden_card_of_cond`), a leaf
  has 512 bits of freshness (`fresh_card` on two coordinates). `ZKKinds` counts them so.

**L19-4 (Info): the hybrid's slack.** The weighted hybrid bounds request `j`'s context by `j ≤ R` earlier provers and
`R` later ones (not `R − 1 − j`), and the stand-in simulator pays the programming twice (L14-3). Together about `8×` on
the cross-receipt term; tightening both moves a run's cap by at most three bits [ESTIMATE], not to every `R`.

**L19-5 (Info): the slot index absorb in a run.** `pb-slot` absorbs the slot index (argument.rs:1171) but not the block
index; in a run's single transcript the same slot's absorb recurs in every block, so one query meets up to 26 states
instead of 1. Harmless for soundness and for one block; it costs a run receipt about four bits of cap (`mT = 32`
against `2`) [ESTIMATE]. A block index in that absorb (W16R3) would remove it.

## 5. What is left

- **The honest prover's obligations** (L18's specification), each a named hypothesis here:
  - the coin map to the view's coins and the receipt read off the view (`hπ`, `hout` of `hHV_of_blockLinks`), with the
    host's scalar by `hostScalar_of_views`;
  - honest rounds: zero gaps, a standalone's claimed sum `0`, an identity extension round (`terminal_of_claims`), and the
    masked terminals as the claim values (`hclaim`, the `build_claim` order);
  - the honest host sums (`codeFuns_honest`'s `hsum`) and the hand-off (`hhosted`);
  - `M`'s layout (`mFactor_of_funs`'s `hMK`: the `CfsMask` coefficients laid out as `M`'s a-rows and
    `combined_weights` carry the θ-combined functional);
  - the openings' coins and weights (`openingsAH_law_eq`'s independence and pad hypotheses, `H`'s zero-sum data);
  - the counts by kind (`zk_every_R`'s `hKw`, `hKc`, `hUw`, `hwb`, `hwba` with the rates), via `hit_card_label`,
    `fresh_card` and `hidden_card_of_cond`, with the column digests as programmed points (L19-3).
- **L19-2**: your ruling (b), (c) or (d) for multi-block receipts.
- **The stages' instance** (item 3): each of IN-C and OUT-C as a layer of `hHV_of_layers`, with its own slot list in
  `block_view_law_eq_links`; not instantiated here (L15's stage definitions are the input).
- **W16R3**: the theorems are unchanged; B1 swaps the openings' rows, B2 the slot list and `codeFuns`, B3 the layout;
  option (d) of L19-2 would change the transcript's key.

## 6. Checks

All in `results/zk60_lean_l19_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, need 14 GiB, cap 24 GiB). Most of the wall time was the shared heavy lock (other lanes' GPU and
merge jobs: the jobs waited 1,372 to 9,954 s for admission and ran 6 to 38 s).
- `prebuild.log`: the fresh worktree's first build, the library root's modules one target at a time (`prebuild.sh`):
  639 s, peak RSS 7.9 GiB, no failure.
- `file1.log` … `file3.log`: the new modules while they were written (`stage.sh`). The errors fixed on the way: a
  `rw` under a lambda in `fresh_card` (replaced by a term), a `Fin` binder inferred as `ℕ` from `((i : ℕ) + 1)` in
  `mfComb` / `viewComb` (annotated), and an exponent congruence that `congr 1` already closes in `cap_R`.
- `check.log`: `check_l19.sh`, run twice (appended; the second run is the current tree: the first differed only by
  three linter warnings on that `congr 1` line, then removed), which runs:
  - the full build (`full.log`): **3,509 jobs, rc 0, 0 warnings, 0 errors, no `sorry`** (68 s, peak RSS 3.7 GiB);
  - the axiom audit (`axioms_l19.lean`, written by `gen_axioms.py`, → `axioms.log`): **71 theorems** (ZKLinks 9,
    ZKLinksM 16, ZKLinksRun 3, ZKCount 13, ZKCountStep 5, ZKCountHyb 7, ZKCountBudget 18): 58 on `propext,
    Classical.choice, Quot.sound`, 6 on `propext, Quot.sound`, 2 on `propext`, 1 on `Quot.sound`, 4 on none;
    `sorryAx` and `Lean.ofReduceBool` nowhere;
  - the source scan of the seven files for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
    `implemented_by`, `@[extern]`, `extern`, `bv_decide`, `ofReduceBool`: **none**;
  - the root imports the seven files;
  - the regressions: **L6Check 1,206 checks, L5Check 5,553 checks, the fixture L1 check 101,956 checks, L11Check 404
    checks, 0 failed**.
