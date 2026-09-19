# The native joint view: the complete-block and attention receipts' real verifier view, analysed at their real challenges

| | |
|---|---|
| Author | delegated security lane (Claude Opus 5), 2026-09-19 |
| Lane | `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`, based on `d399b32` |
| Inputs | the four source-pinned captures of `results/zk60_native_captures_20260919` (two `private-block-t32-poc/1`, two `private-attention-t32-poc/1`), source commit `2b5c65c3…`, verifier binary `fec86a7b…` |
| Gate | `python3 scripts/zk60_native_joint_view.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_joint_view` (23 s, record `results/zk60_native_joint_view/joint_view.json`, marker `joint_view.done`) |
| Tests | `python3 -m unittest discover -s tests -p "test_zk60_native_joint_view.py"` — 30 tests, 49 s |
| Scope guard | P1 hides inputs, outputs and intermediate activations; weights may be public. Nothing here narrows that set. |
| **Status** | **No privacy property is established.** Every number below is a rank of an explicitly stated **linear model** at **two receipts' real challenges**. The caller-fixed endpoint-root obligation (**D8/D11**) is untouched and remains **OPEN**. |

## 0. What this is, in one paragraph

The earlier leak-checking tools for this profile
(`results/zk60_private_block_tools/`) ran on **seeded stand-in challenges**
and **excluded** the sampled columns, the salted Merkle paths, the masking
commitment at real challenges, transcript conditioning and the A/H
correlation. This lane runs the analysis on the **real captured verifier
views**: it re-derives the entire Fiat–Shamir transcript from the captures'
public data, then builds, at those real challenges, the joint linear view of
the A and H commitments **together with the two endpoint commitments, every
claimed evaluation, every opening group's combination and all 256 sampled
columns with their pads**, then the masking-commitment (CFS/M) channel, then
the three stacked. In that model the commitment side discloses **nothing
about the hidden planes except the public LogUp identity** (A 0, H 2, Input
0, Output 0, over Fp), and the CFS side discloses **the slots' public
terminal identities and nothing else**. Every negative control fires. The
important caveats — the nonlinear link between the two channels, the hash
layer, D8/D11, and a genuine geometry difference against the seeded runs —
are in §6–§8.

## 1. Stage 1 — transcript replay (the analysis runs at the real challenges)

`scripts/zk60_native_jv_replay.py` rebuilds the transcript in Python with
BLAKE3, label by label after `hashline/src/private_block/protocol.rs`,
`hashline/src/private_attention/protocol.rs`,
`zkp-core/src/sumcheck.rs::verify`, `hashline/src/zk.rs::mask_verify` and
`zkp-core/src/pcs.rs::verify_zk`, from the capture's public data only: the
112 expected-IO policy bytes, the public-statement digest, the pinned
`parameters` literal, the block's `calibration` digest
`blake3("B3 public fixed calibration v1")`, the schedule digest, the three
roots and every published field value. A *checkpoint* is the pair (32-byte
state, next Fp2 challenge) exactly as `native_capture.rs::state` writes it,
so the squeeze counter is checked as well as the state.

| capture | profile | checkpoints | challenges | final counter | failures |
|---|---|---|---|---|---|
| `40083e7a…` | block | 80 | 1543 | 1863 | 0 |
| `7d334e06…` | block | 80 | 1543 | 1863 | 0 |
| `6c5e83fd…` | attention | 65 | 1122 | 1442 | 0 |
| `c26d1f05…` | attention | 65 | 1122 | 1442 | 0 |

Everything reproduces: the header state, the three LogUp challenges, every
slot's definition draws, mask challenge `c_s`, every round challenge and the
`before_definition`/`before`/`after` joins, the M opening's `theta`, its
`2·slots+2` proximity draws and its 256 column indices, and each role's
per-group lambdas, `rows` proximity draws and 256 column indices. Manifest
cross-check: 4/4 bundles match `validation.json` by sha256 and byte count;
all four carry `canonical_capture_reproduced` and `native_reverified` true
and `privacy_review_complete` false.

## 2. Stage 2 — the joint commitment-side view, with the opened columns

### 2.1 The model, stated exactly

For one commitment with `rows` rows, row `i` is `z_i = (msg_i, pad_i)` in
`Fp^256 × Fp^256`: the committed message and the row's Q = 256 uniform pad
symbols (`pcs.rs::commit_zk_owned_with`). At fixed challenges the whole
field-valued view is affine in `(msg, pad)`:

| object | value |
|---|---|
| each claim value | `value_c = Σ_i rw_c[i] ⟨msg_i, cw_c⟩` |
| each group vector (512 entries) | `v_g = Σ_i rho_g[i] z_i` |
| the proximity vector | `v_prox = Σ_i rho_prox[i] z_i` |
| each sampled column `j` | `col_j[i] = ⟨E_j, z_i⟩`, one functional **per row** |

with `rw`/`cw` from `zpart_weights`/`zkey_weights`, `rho` from `zk_rhos` at
the replayed lambdas and proximity draws, and `E_j` the closed form of
`encode_row_zk`: with `x_j = 7·ω_2048^j`,
`E_j[msg s] = (x_j^256 − 1)/(256(x_j ω_256^{−s} − 1))` and
`E_j[pad k] = (x_j^256 − 1)·x_j^k`. **Each opened column therefore reveals
exactly one linear functional of every committed row, and the pad half of
that functional is `(x_j^256 − 1)` times a Vandermonde row in `x_j`.**

Writing `F` for the Fp-span of all those functionals (an Fp2-valued
functional contributes its `c0` and `c1` coefficient vectors) and `T` for
the functionals supported on the **data rectangle** (data rows × message
positions), the disclosed dimension is
**`disclosed = dim_Fp (F ∩ T)`** — the rank of what is revealed about the
hidden planes beyond what the public statement implies, counted over Fp so
that one Fp2-valued public identity counts 2.

The `E_j` model is not assumed: the gate **re-checks the verifier's own
accepted column identity** `Σ_i rho_g[i]·col_j[i] = ⟨E_j, v_g⟩` on sampled
(group, column) pairs of every role of every capture — 77 checks per block
capture, 0 failures — and the group identity
`⟨v_g[:256], cw_g⟩ = Σ λ·value` on every group, 0 failures.

### 2.2 The reduction, and why the columns drop out

A dense rank over ~10^5 unknowns is not computable here, so the gate uses a
reduction whose three hypotheses are **checked on the capture** and whose
formula is **validated against a brute-force dense rank** on a small
synthetic instance of the same shape (§6):

- **H-pad** — the `d` **distinct** sampled columns satisfy `d ≤ Q = 256`,
  the nodes `x_j` are distinct and `x_j^256 − 1 ≠ 0`. The pad block is then
  a Vandermonde of rank `d`, so no functional of `{E_j}` is supported on the
  message positions and the 256 columns contribute **nothing** to `F ∩ T`.
- **H-pair** — every claim's row weights, restricted to the non-data rows,
  sit on exactly one adjacent reserved pair, that pair is used by no other
  claim, its two coefficients are an Fp-basis of Fp2, and no claim touches
  the proximity pair (`protocol.rs::audit_claims`, re-verified here on the
  captured claims rather than trusted).
- **H-prox** — `det(rho_prox[prox], rho_prox[prox+1]) ≠ 0`, which
  `check_opening_challenges` refuses otherwise.

Under H-pair and H-prox every admissible combination of claim functionals
collapses into the group combinations `rho_g` (per group, the coefficients
must be proportional to that group's lambdas), so the claim values add
nothing either, and

> `disclosed = 256·k0 + (u-row term)`, where
> `k0 = dim { p ∈ rowspace(rho) : p vanishes on every non-data row }`.

### 2.3 The numbers (all four captures)

| role | rows | data rows | groups | rank(rho) | k0 | distinct columns | pad margin | **disclosed (Fp)** |
|---|---|---|---|---|---|---|---|---|
| A (block) | 455 | 213 | 35 | 72 | 0 | 243–246 | 10–13 | **0** |
| H (block) | 384 | 278 | 9 | 20 | 0 | 240–242 | 14–16 | **2** |
| Input / Output (block) | 7 | 2 | 1 | 4 | 0 | 231–246 | 10–25 | **0** |
| A (attention) | 306 | 154 | 30 | 62 | 0 | 234–241 | 15–22 | **0** |
| H (attention) | 290 | 216 | 8 | 18 | 0 | 239–243 | 13–17 | **2** |
| Input / Output (attention) | 7 | 2 | 1 | 4 | 0 | 235–243 | 13–21 | **0** |

The two dimensions on H are **exactly the public LogUp identity**: the gate
computes the disclosed row-functional `ξ(γ)` explicitly and checks that its
Fp-span equals the span of the LogUp sum claim's data-row weights (139
nonzero data rows on the block, 108 on attention) and that both have
dimension 2 — the real and imaginary parts of one Fp2 identity whose
published value is zero. Nothing else is disclosed on any role of any
capture.

**The pad budget is met.** Q = 256 pads are reserved per row and the receipt
opens 256 columns; birthday collisions among the 256 draws from 2048
positions leave 231–247 **distinct** positions, so the observed margin is
**9 to 25 pad symbols** — and what the reduction needs is only
`distinct ≤ Q`, so a margin of **zero** would do (this is measured, not
asserted: §9b). An exact Gaussian elimination cross-check confirms the pad
block's rank is exactly the distinct count (246 of 246, 2.2 s), and a second
one confirms it at the boundary — 256 pads against 256 **distinct** positions
of the receipts' own coset, rank 256 of 256, 2.0 s. For the other
role/capture pairs the rank is taken from the Vandermonde theorem with the
distinctness and `x_j^256 ≠ 1` checks done exactly. The control "one pad
fewer than the distinct opened positions" discloses (§6), so the budget is
live in the sense that it cannot be *reduced*, not in the sense that the
observed surplus is doing work.

## 3. Stage 3 — the masking-commitment (CFS / M) view, and the one finding

Slot `s` runs `N_s` rounds of degree `d_s` masked by a CFS polynomial with
`L_s = N_s d_s + 2` uniform Fp2 coefficients; the receipt publishes
`masked_round_j = honest_round_j + c_s·g_s.round(j, rho_{<j})` at the real
`c_s` and `rho`. Writing `C_s` for the consistency subspace of the published
round space (`dim_Fp2 C_s = N_s d_s + 1`), `R_s` for the map
coefficients → rounds and `F_s` for the published functionals,

> `disclosed_s = (dim C_s − rank R_s) + dim(rowspace(R_s) ∩ rowspace(F_s))`.

**Measured at the real challenges, on all four captures:**

- `rank R_s = dim C_s` for **every** slot (23 block, 18 attention): the mask
  covers the whole consistency subspace, so the first term is **0
  everywhere** and the masked rounds are uniform on `C_s` given the data.
- the mask's own rounds stay inside `C_s` (checked, 0 violations).
- **every published M functional lies inside the round span**:
  `rank F = 34` (block) / `28` (attention) and `rank(F mod rounds) = 0`. The
  theta-combination the `q` channel reveals is in the span too.

The second bullet is the finding of this lane and it is reported as
measured. Its consequence depended on an **accounting choice**, because the
M functional *values* are not independently published — the verifier
**derives** each from the slot's masked rounds and its terminals
(`terminal_polynomial = fin − c·mask_eval` in the capture). The choice has
since been made (§9a answer 1: a derived value is not an independent
observation; the headline is the first row, the second is reported beside
it), and the identity it rests on is now asserted per slot — §3.1:

| accounting | block | attention | what the disclosed functionals are |
|---|---|---|---|
| only what the M **opening** independently reveals (the single Fp2 functional `q[0] + q[512]`) | **2 Fp** (1 Fp2) | **2 Fp** | the theta-combination of the slots' terminal identities |
| **every derived mask evaluation** counted as an independent observation | 68 Fp (34 Fp2) | 56 Fp (28 Fp2) | each slot's terminal identity `φ_s(h_s) = poly_s(published terminals)` |

In both accountings the disclosed functionals of the honest rounds are
exactly the slots' **public terminal identities** — functions of values the
receipt already publishes — and not additional information about the
witness. But that redundancy is a **nonlinear** fact (`poly_s` has degree up
to 4 in the terminals), so **linear algebra cannot show it** and this
analysis does not; what it is shown by instead is the identity of §3.1,
checked numerically per slot. See also §7 and the questions in §9.

## 3.1 The lemma the accounting rests on, and what the gate now checks

(Added after the security owner's answer 1 of §9a, which rules that a derived
mask evaluation is not an independent observation. The paragraph above is
therefore replaced by a lemma and a per-slot assertion.)

**Statement.** For every slot `s`, the mask evaluation `mask_eval_s` — the
quantity the pessimistic accounting counts as an extra observation — is a
**deterministic function of values the receipt already publishes**. It is
computed by the verifier, never observed.

**Proof, in three lines.** The verifier's own final check of slot `s` is

1. `fin_s = c_s · mask_eval_s + poly_s(terminals_s)` — this *is* the code:
   `let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());`
   (`hashline/src/private_block/argument.rs:340`, and the same line in
   `private_attention/argument.rs`), where `vals` holds the published
   terminals in the slot's private-table positions and public values
   (`eq_point`, `eval_mle_ext`) elsewhere;
2. `c_s ≠ 0`, because the verifier refuses a zero mask challenge outright and
   never redraws it — `if c.is_zero() { return Err("zero CFS mask challenge;
   discard attempt") }`, `private_block/argument.rs:275` and
   `private_attention/argument.rs:261` (the legacy paths refuse it too,
   `zk.rs:1675`, `zk.rs:3533`);
3. therefore `mask_eval_s = (fin_s − poly_s(terminals_s)) · c_s^{-1}`, and
   every quantity on the right is public: `fin_s` is the sumcheck's final
   claim, itself determined by the published round messages and the
   transcript challenges (`zkp-core/src/sumcheck.rs::verify`), `c_s` is a
   transcript challenge, and the terminals are published and absorbed under
   the slot's terminal label. ∎

**Consequence for the accounting.** The 68 Fp (block) / 56 Fp (attention)
"derived" dimensions of the table above are functions of published values,
so they are not observations of the hidden data; the functional the M opening
independently reveals is the **single theta-combination** `q[0] + q[512]`,
2 Fp. The headline for these four receipts is 4 Fp, with 70 / 58 reported
beside it, never instead of it (§9a answer 1).

**What the lemma does NOT give.** It is an *ingredient* of a simulation
argument, not the argument. It says the simulator need not sample
`mask_eval_s`; it does not say the simulator's other samples are correctly
distributed, and it says nothing about the adaptive (distributional) lift:
the **joint hypothesis of the sequential-kernel lemma stays open** (U-3,
§9a answer 5). It is also silent on the hash layer and on D8/D11.

**What the gate asserts, per slot, on all four captures** (stage 3,
`derived_mask_evaluation` in the record):

| checked, per slot | block (2 captures) | attention (2 captures) |
|---|---|---|
| `claimed_sum` recomputed from the published scalars and hosted coefficients | 23 / 23 | 18 / 18 |
| every round's own `s(0) + s(1) = claim` | 23 / 23 | 18 / 18 |
| `fin_s` recomputed by iterated `interpolate_eval` at the replayed challenges, equal to the capture's | 23 / 23 | 18 / 18 |
| `c_s ≠ 0` | 23 / 23 | 18 / 18 |
| **`mask_eval_s == (fin_s − terminal_polynomial_s) / c_s`**, the weak form (see below) | **23 / 23** | **18 / 18** |
| every published terminal is republished as the value of the PCS claim its private table names | 173 / 173 | 112 / 112 |

**The form actually asserted is the weak one, and here is exactly why.** The
capture writes `terminal_polynomial` as the *already evaluated* value
`fin.sub(c.mul(mask_eval))` (`hashline/src/native_capture.rs:118`), and the
slot's composition polynomial `def.poly` is a Rust closure
(`Poly = Box<dyn Fn(&[Fp2]) -> Fp2>`) that the capture does not carry. So
`poly_s(terminals_s)` **cannot be recomputed here from the terminals**: what
is asserted is that `fin_s − c_s·mask_eval_s` equals the stored terminal
polynomial value, with `fin_s` and `c_s` **not** taken from the capture but
recomputed — `fin_s` from the published rounds by a port of `sumcheck::verify`
and `c_s` from the stage-1 transcript replay. The terminals themselves are
anchored by the last row of the table: each one is republished as a PCS claim
value (`build_claim(..., value = terms[k])`,
`private_block/argument.rs:223`), which is the claim stage 2 shows is absorbed
by its reserved mask pair.

**Negative controls** (stage 6, `derived_mask_evaluation_controls`; each
perturbs one published field of slot 0 by one and is undone afterwards):

| perturbation | the per-slot identity | the terminal → claim cross-check | the transcript replay |
|---|---|---|---|
| one round coefficient | **fires** (4/4 captures) | — | — |
| `mask_eval` | **fires** (4/4) | — | — |
| `terminal_polynomial` | **fires** (4/4) | — | — |
| **one terminal** | **does NOT fire** | **fires** (4/4) | **fires** (checked on capture `40083e7a…`) |

The last row is the honest result and it is the measure of the gap: the weak
identity is blind to a perturbed terminal, because the terminals only enter
the stored value it uses. Two other published places do see it.

**What would let the strong check run** (a request, not a defect): one
additional captured field per slot — the slot's composition polynomial in
machine-readable form, e.g. `"poly": [[coefficient, [table indices]], …]`, its
monomials over the slot's declared table list. Everything else the evaluation
needs is already in the capture and was checked structurally here (25 eq / 19
public / 173 private tables per block capture, 19 / 14 / 112 per attention
capture; every public table carries its full `2^main` values, and the private
table count equals the terminal count on every slot). With that one field,
`poly_s(terminals_s)` could be recomputed from the published terminals, a
perturbed terminal would break the per-slot identity directly, and the lemma's
step 1 would be checked rather than cited.

The M opening's other channels are handled by three source facts, each
checked here: `q = Σ_s p_{a_s} p_{W_s} + p_b` with `b` uniform on 1024
coefficients subject to `b[512] = −b[0]`, so `b` masks every coefficient of
`q` except `q[0] + q[512]`, and the verifier's identity
`512·(q[0]+q[512]) = Σ_i θ^i value_i` **holds on all four captures**; the
proximity vector is `u + Σ r_row p_row` with `u` uniform and coefficient 1,
so it is perfectly masked; and the a-rows' 256 pads absorb the M columns —
246 distinct sampled positions of 4096, margin 7–10, exact rank check 246 of
246 (2.1 s), the pad block being a Cauchy matrix in distinct nodes. The `b`
and `u` rows' column values are the verifier's own two column identities and
add nothing.

## 4. Stage 4 — A and H and M stacked

The four commitments and the CFS masks draw **disjoint** parts of one prover
randomness vector (`commit_zk_owned_with` draws fresh pads and salts per
commitment; `mask_commit` draws the CFS coefficients, their pads, `b` and
`u`). A functional supported on data coordinates that is a sum of
functionals of several channels must therefore have each channel's part
separately supported on data coordinates. **The joint disclosed space is the
sum of the per-channel spaces** — and can only be *smaller*, never larger,
if data is aliased across commitments (two channels then disclose the same
functional).

| capture | A | H | In | Out | PCS sum | CFS (opening only) | **joint** | sum of parts |
|---|---|---|---|---|---|---|---|---|
| both block | 0 | 2 | 0 | 0 | 2 | 2 | **4** | 4 |
| both attention | 0 | 2 | 0 | 0 | 2 | 2 | **4** | 4 |

(Under the pessimistic CFS accounting of §3 the joint figure is 70 Fp on the
block and 58 Fp on attention, all of it the public terminal identities.)
This is the first time A and H have been treated together for this profile
rather than apart: the answer is that the stacking adds nothing, for the
structural reason above rather than by a joint elimination.

## 5. Stage 5 — the zero-witness gate

In this linear model, for a fixed view the set of `(data, randomness)`
consistent with it is an **affine coset of the kernel of the randomness
map**, so every fibre has the **same free dimension** whichever data value
it sits over — channel by channel, for the real witness and for the zero
witness alike. A zero-data preimage exists exactly when every disclosed
functional takes the value it takes at zero. On A, Input and Output nothing
is disclosed, so a zero-data preimage exists unconditionally. On H the only
disclosed functional is the LogUp identity, whose **published claim value is
`Fp2::ZERO`** (checked on every capture) — which is what the zero witness
gives — so a zero-data preimage exists there too. On the CFS side the masked
rounds are uniform on `C_s` given the data (`rank R_s = dim C_s`), so the
same holds for the honest rounds.

**Channels covered:** the claim values, the group vectors, the proximity
vector, every sampled column value, the M opening's `q`, proximity vector
and column values, and the slots' masked round messages.

**Channels NOT covered, and what is assumed instead:** the three Merkle
roots, the 256 leaf salts served per opening and the 11- and 12-level
authentication paths are **hash objects; linear algebra does not cover
them**. What is assumed for them — not shown here — is salted-leaf hiding of
the unopened columns (leaf = `blake3(blake3(column) ‖ salt)`) and, for the
two caller-fixed endpoint roots, the programmable random-oracle argument of
**D8/D11, which is OPEN**. Also not covered: the receipt's byte encoding and
length, and anything nonlinear in the view.

## 6. Stage 6 — the negative controls

The stage-2 reduction is validated against a **brute-force dense rank**
`rank([M_randomness | M_data]) − rank(M_randomness)` on a small synthetic
instance of the same shape (4 message columns, Q pads, data rows, one
reserved pair per claim, a proximity pair, optionally a zero-sum pair), and
every control is run there, where the direct computation is feasible:

| control | brute-force disclosed | reduction | hypothesis it breaks |
|---|---|---|---|
| honest | **0** | 0 | — |
| honest with a zero-sum pair | **1** | 1 | — (the public identity) |
| masks removed | **24** | n/a | H-pair |
| two claims sharing one mask pair | **8** | n/a | H-pair |
| the commitment opened twice | **10** | n/a | H-pad |
| an extra published helper sum | **1** | n/a | none — the extra observation *is* the disclosure |
| one pad fewer than the opened columns | **3** | n/a | H-pad |
| **a capture whose bytes were altered** | the stage-1 replay **fails on all four captures** (first failure: `slot 0 round 0 challenge: challenge differs`), and the honest replay still passes afterwards | | |
| the pad-budget **boundary** cases `q_pad = d`, `d + 1`, `d − 1` | **0**, **0**, **3** | — | §9b: a zero margin is sufficient |
| one published field of a slot perturbed by one (round coefficient, `mask_eval`, `terminal_polynomial`, one terminal) | the derived-mask-evaluation identity fires on the first three; a perturbed **terminal** is seen by the terminal → claim cross-check and by the replay, not by that identity | — | §3.1 |

Every control fires (the boundary cases are predictions, not controls: (a)
and (b) are *expected* to disclose 0 and do). The reduction agrees with
brute force on both honest instances.

## 7. What is NOT established

1. **D8/D11, the caller-fixed endpoint-root obligation, is untouched and
   OPEN.** Nothing here is a simulator, a reduction or a root-only argument;
   the two endpoint roots enter this analysis only as public bytes.
2. **Only two challenge vectors per profile.** These are the real challenges
   of four real receipts, not a generic-rank argument for every non-refused
   challenge. Codex's 2026-09-18 criticism of the round-2 memo applies here
   unchanged.
3. **Transcript conditioning beyond stage 1.** Stage 1 shows the challenges
   are the ones BLAKE3 produces from the public prefix; it is not the
   distributional (adaptive) argument. Lifting fixed-challenge evidence to
   the adaptive view needs the sequential-kernel lemma with its **joint**
   hypothesis, which is not discharged here.
4. **The nonlinear link between the two channels** (`fin − c·g(rho) =
   poly(terminals)`, degree up to 4). A linear model cannot see it; nothing
   here rules out a nonlinear functional of the joint view.
5. **The hash layer** (§5) and the salted-leaf hiding it rests on.
6. **Integer-range side information.** The committed planes are small
   integers embedded in Fp; the analysis treats them as free Fp values.
   Anything the view implies about their *range* (an out-of-range value is
   caught only by the LogUp identity, `protocol.rs` line 292) is outside
   this model.
7. **Timing, memory and any other side channel**; the prover's RNG is a
   keyed BLAKE3 stream (`ZkRng`), so "uniform independent randomness" is a
   **PRG assumption**, and the `fp()` reduction bias is not re-measured here.
8. **P3 (hidden weights).** This profile has no W commitment.
9. **Soundness.** Nothing here is about soundness.

## 8. Differences from the seeded runs in `results/zk60_private_block_tools/`

- **A genuine geometry difference (a finding).** The seeded pair-schedule
  run records `group_counts {A: 35, H: 8}` for the **block** profile and
  emits seven H group verdicts (`group_H_h0…h6`). The real block receipts
  form **nine** H groups, which is also what `layout.rs`'s `H_GROUPS = 9`
  declares and what `check_opening` enforces. The likely cause is that
  tool's own adaptation R-4 ("the SC_ZS slot's H site … is not emitted in
  the tool's view of the claim list, because the tool builds that claim
  itself with the fresh pair u'"). **Its H numbers are therefore about a
  different opening from the one the verifier performs.** The A side agrees
  (35 groups), as do the row geometries (A 455 rows / 213 data, H 384 / 278).
- **Challenges.** The seeded runs use stand-in challenges with `seed 2026`
  and explicitly exclude the degenerate cases; this lane uses the receipts'
  real challenges, re-derived and checked.
- **Channels.** The seeded runs state that "hashing, Merkle paths, salted
  leaves, the sampled columns / folded pads and the CFS-masked sumcheck" are
  excluded. This lane includes the sampled columns with their pads and the
  CFS/M channel at real challenges; the hash layer remains excluded (§5).
- **The CFS numbers agree structurally.** The seeded CFS run already
  records, per slot, `rank_map = dim_consistency_subspace`,
  `kernel_dim_fp2 = 1`, `m_functionals_in_view_span: true` and
  `theta_combination_in_view_span: true`, and reports `leaked_dim_fp2: 0`.
  This lane reproduces all of those **at the real challenges**. The
  difference is one of **accounting, not arithmetic**: the seeded run treats
  a functional that lies in the view span as contributing nothing, while §3
  records that, taken as an independent observation, such a functional
  yields the corresponding combination of the honest rounds — which is the
  slot's public terminal identity. Both readings are defensible; §9 asks for
  a ruling.
- **No other numerical disagreement was found.** The disclosed dimensions
  the seeded pair-schedule run reports per group and per endpoint (0
  everywhere) agree with this lane's per-role 0 on A and the endpoints.

## 9. Questions for the security owner

1. **The CFS accounting (§3).** Should a derived M functional value — one
   the verifier computes from the masked rounds and the published terminals
   — count as an observation in the linear model? If yes, the CFS channel
   discloses 34/28 Fp2 dimensions, all of them the slots' public terminal
   identities; if no, it discloses 1 Fp2. A ruling here decides whether the
   headline joint number for these receipts is **4 Fp** or **70/58 Fp**, and
   in either case whether "the disclosed functionals are public functions of
   published values" is accepted as discharging them.
2. **Is the pad margin acceptable as a design invariant?** It is 9–25 pad
   symbols and it is produced by birthday collisions among the 256 draws,
   not by a reserved surplus. `ZkOpts::standard` sets `q_pad =
   num_col_checks` exactly. ~~If a future profile ever drew 256 *distinct*
   positions (probability ≈ 1.2·10⁻⁷ per opening at this geometry), the
   margin would be zero and the columns would stop being absorbed.~~
   **CORRECTED (§9b, measured): that sentence was wrong.** A zero margin is
   sufficient — with 256 distinct opened positions the pad block is a square
   Vandermonde in distinct nodes, rank 256, and the columns are still
   absorbed (disclosed 0 in the small model, exact rank 256 of 256 at the
   receipts' real geometry). The question stands only as a defence-in-depth
   one, and the security owner's answer 2 declines it for a frozen-digest
   reason: should the source reserve `q_pad = num_col_checks + 1` anyway?
3. **The seeded tool's H geometry (§8).** Should
   `scripts/zk60_attention_pair_schedule.py`'s block adaptation be corrected
   to nine H groups, or its record annotated so its H numbers are not read
   as covering the receipt's H opening? (That script is not mine to edit.)
4. **What the capture does not contain.** The capture exports no witness
   plane, private pad, mask coefficient or RNG state — correctly. Two things
   would let this lane go further without weakening that: (a) the
   **unmasked** honest round messages of one slot on a synthetic fixture,
   which would let the zero-witness gate be *exhibited* rather than argued
   from linearity; (b) a capture of the **same** commitment opened twice, to
   run the repeated-opening control against a real receipt instead of the
   small model. Both are the other agent's to decide; neither is needed for
   the numbers above.
5. **Is the sequential-kernel lemma's joint hypothesis to be discharged on
   this profile in this lane**, or does it stay with the round-2 write-up
   obligation (U-3)?

## 9a. The security owner's answers (Claude Fable 5.1, 2026-09-19 13:00)

Before answering I ran the gate myself against the four capture bundles, into
a scratch evidence directory: exit 0; stage 2 as expected on every channel (A
0, H 2, both endpoints 0); the pad block's exact rank 246 of 246; all five
negative controls fire; `privacy_property_established` stays false. I read §3
and §9 of this report in full; the rest I take from the delegated agent's
work and its tests. **Nothing below is a privacy acceptance.**

1. **The accounting: a derived mask evaluation is not an independent
   observation. The headline for these four receipts is 4 Fp, all of it
   public identity; the 68 / 56 figure is reported beside it, never instead
   of it.** Reason. The object of this analysis is what the view determines
   about the *hidden data* beyond what the receipt already publishes. Each
   slot's final check is `fin_s = c_s · mask_eval_s + poly_s(terminals_s)`.
   The verifier does not *observe* `mask_eval_s`; it *computes* it from
   `fin_s`, `c_s` and the published terminals. So the functional of the
   honest rounds that the second accounting counts as disclosed —
   `φ_s(h_s) = poly_s(terminals_s)` — is a deterministic function of values
   already in the view, and those terminals are themselves claim-site values
   that stage 2 shows are absorbed by their reserved mask pairs. In a
   simulator these quantities are *computed*, not sampled: sample the masked
   rounds uniformly on `C_s` (stage 3's first bullet is exactly what licenses
   that), sample the terminals as stage 2 allows, then *set*
   `mask_eval_s := (fin_s − poly_s(terminals_s)) / c_s` and derive the one
   independent M functional `q[0] + q[512]` from the θ-combination. That the
   redundancy is nonlinear (degree up to 4) is why the linear tool cannot
   certify it; it is certified instead by the identity itself, which this
   gate already checks numerically on all four captures. **Owed, and small:**
   state that as a lemma in this report with its three-line proof, and make
   the gate assert, per slot, that the derived mask evaluation recomputed from
   published values equals the one in the capture — so the accounting rests
   on a checked identity and not on this paragraph. It remains an ingredient
   of a simulation argument, not the argument: the joint hypothesis of the
   sequential-kernel lemma is not discharged here (answer 5).
2. **No change to `q_pad`, and one test owed.** I do not accept the sentence
   "if 256 distinct positions were drawn the columns would stop being
   absorbed" as written. With `Q'` distinct opened positions and `q_pad` pad
   coefficients per row, the opened symbols of a row are jointly uniform
   exactly when the `Q' × q_pad` pad block has rank `Q'`; a Cauchy block in
   distinct nodes has full rank for every `Q' ≤ q_pad`, **including**
   `Q' = q_pad = 256`. The group vectors do not spend pad freedom, because
   each is masked by its own fresh rows over *all* coordinates, pads
   included. So the margin produced by birthday collisions is a surplus, not
   a requirement. Your negative control shows the failure at `q_pad = Q' − 1`;
   **add the boundary case `q_pad = Q'` with no collisions to the small
   model and show it discloses 0** — if it does not, I am wrong and that is a
   finding. Independently of who is right, `ZkOpts::standard` is shared with
   the legacy zero-knowledge paths whose two digests are frozen and in use by
   a live lane, so it is not changed now.
3. **Annotate now, correct later.** This gate reads the receipts' own nine H
   groups and supersedes the seeded run for H. The seeded tool's record gets
   a note that its block H figures model eight groups and are not the
   receipt's opening; correcting the adaptation is owed to whoever next
   touches `scripts/zk60_private_block_inventory.py` (mine to schedule).
4. **Passed to Codex as requests, its call:** (a) the unmasked honest round
   messages of one slot on a *synthetic* fixture, so the zero-witness gate
   can be exhibited; (b) a capture of one commitment deliberately opened
   twice, as a real-receipt negative control. Neither weakens the capture's
   rule of exporting no witness plane, private pad, mask coefficient or RNG
   state for real proofs — both are test fixtures and must be labelled so.
5. **It stays with U-3.** The sequential-kernel lemma's joint hypothesis is
   not discharged in this lane. What this lane adds to that obligation is
   evidence at real challenges that the per-channel pieces the lemma needs
   hold on this profile (uniformity of masked rounds on `C_s`; absorption of
   claims and columns; disjoint randomness across A, H, the endpoints and M,
   so the joint disclosed dimension is the sum of the parts).

**What this lane establishes, in one sentence the project may quote:** on a
linear model of the complete verifier view — claims, opening-group vectors,
the 256 sampled columns with their pads, the masking commitment and the
masked rounds — evaluated at the real challenges of two complete-block
receipts and two attention receipts, nothing about the hidden planes is
determined beyond public identities, every negative control fires, and an
altered capture breaks the transcript replay. **What it does not:** any
privacy property; the hash layer (roots, salts, paths), which rests on the
open D8/D11 obligation; more than two challenge vectors per profile; the
adaptive and distributional lift; integer-range side information; timing.

## 9b. What the two owed items measured (this lane, after §9a)

**Owed item 1 (answer 1) is discharged as a checked fact: see §3.1.** The
lemma is stated there with its three-line proof and the source lines where
`c_s = 0` is refused; the gate asserts the identity per slot (23 / 23 block,
18 / 18 attention, on each of the two captures per profile) and the terminals'
republication as PCS claim values (173 / 173 block, 112 / 112 attention).
Only the **weak** form could be asserted, for the reason given in §3.1: the
capture stores `terminal_polynomial` already evaluated and does not carry
`def.poly`. The terminal-perturbation control is therefore blind in the
per-slot identity and fires in the two other places, which is reported above
rather than smoothed over.

**Owed item 2 (answer 2): the boundary discloses 0. The security owner is
right and the report's §9 question 2 was wrong; it is corrected in place.**

Each case is a named check in the small model (where the dense rank is
computable), built exactly as the real code builds the pad block, with its
prediction written before the run:

| case | distinct opened positions | `q_pad` | predicted | **brute-force disclosed** |
|---|---|---|---|---|
| (a) `q_pad == distinct`, no collisions | 4 | 4 | 0 | **0** |
| (b) `q_pad == distinct + 1` | 4 | 5 | 0 | **0** |
| (c) `q_pad == distinct − 1` (the existing control) | 4 | 3 | > 0 | **3** |

and at the receipts' own geometry, as a second, non-toy check: 256 pads
against **256 distinct** opened positions of the real encoded domain — this
role's own distinct sampled positions extended by unused ones until the
birthday surplus is gone — exact Gaussian rank **256 of 256** (2.0 s,
`pad_block_at_the_full_budget` in the record). A zero margin is therefore
**sufficient**, and the 9–25 symbols the receipts happen to have are a
surplus, not a requirement. The one-line reason: the pad half of `E_j` is
`diag(x_j^n − 1)` times a Vandermonde in the distinct nodes `x_j`, which has
full row rank for **every** `d ≤ q_pad`, including `d = q_pad`; absorption
needs full **row** rank (no nonzero combination of the opened columns vanishes
on the pads), not spare columns.

**One correction of detail to answer 2's reasoning, which does not change
its conclusion.** The block that absorbs the *PCS* columns is a **Vandermonde**,
not a Cauchy matrix: `encode_row_zk` (`zkp-core/src/pcs.rs:618`) subtracts
`pad[i]` at coefficient position `i` and adds it at `n + i`, so
`E_j[pad k] = (x_j^n − 1)·x_j^k`. The **Cauchy** block is the *masking
commitment's* (§3): there the pads sit inside the 512-position message
(`hashline/src/zk.rs::mask_commit:445`), so a column's pad coefficients are
Lagrange weights `L_t(y_j)`. Both are full row rank in distinct nodes for
`d ≤ q`, so the argument holds on both sides. (`ZkOpts::standard` sets
`q_pad = num_col_checks`, `pcs.rs:543`; `commit_zk_owned_with` refuses
`q_pad < num_col_checks`, `pcs.rs:670`.)

**Do the opening-group vectors consume pad freedom? No — measured, not
assumed.** A group vector contributes, per pad coordinate `k`, the functional
`z ↦ Σ_i rho_g[i]·pad_i[k]`. It constrains a data row's pads only in the
directions it cannot already reach through the mask rows, i.e. by
`rank(over all rows) − rank(restricted to the non-data rows)`. Measured
directly on the small model at all three boundary cases: **0** (32 pad
functionals, rank 32 over all rows, rank 32 over the non-data rows alone),
and equal to `q_pad · k0` as the reduction predicts. On the four real
captures the same quantity is `q_pad · k0` with **`k0 = 0` on every role of
every capture** (§2.3), so the group vectors consume no pad freedom there
either — which is the security owner's reason (each group is masked by its
own fresh reserved pair over all coordinates, pads included), confirmed in
this model. The proximity vector is included in the same measurement.

**Still true, and unchanged by either item:** no privacy property is
established, D8/D11 is open, and the joint hypothesis of the
sequential-kernel lemma stays with U-3.

## 10. Reproduce

```
python3 scripts/zk60_native_joint_view.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_joint_view
python3 -m unittest discover -s tests -p "test_zk60_native_joint_view.py"
```

The gate writes `results/zk60_native_joint_view/joint_view.json` (every
number in this memo, plus the tool sha256s and the manifest cross-check) and
the marker `joint_view.done` holding the exit code. It reads only the
capture bundles; it runs no prover, no verifier, no Rust and no GPU, and it
takes 23 s. `privacy_review_complete` and `privacy_property_established`
stay **false** in the record.
