# The native joint view: the complete-block and attention receipts' real verifier view, analysed at their real challenges

| | |
|---|---|
| Author | delegated security lane (Claude Opus 5), 2026-09-19 |
| Lane | `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`, based on `d399b32` |
| Inputs | the four source-pinned captures of `results/zk60_native_captures_20260919` (two `private-block-t32-poc/1`, two `private-attention-t32-poc/1`), source commit `2b5c65c3…`, verifier binary `fec86a7b…` |
| Gate | `python3 scripts/zk60_native_joint_view.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_joint_view` (21 s, record `results/zk60_native_joint_view/joint_view.json`, marker `joint_view.done`) |
| Tests | `python3 -m unittest discover -s tests -p "test_zk60_native*.py"` — 85 tests, ~66 s (one pre-existing skip) |
| Scope guard | P1 hides inputs, outputs and intermediate activations; weights may be public. Nothing here narrows that set. |
| **Status** | **No privacy property is established.** Every number below is a rank of an explicitly stated **linear model** at **two receipts' real challenges**. The caller-fixed endpoint-root obligation (**D8/D11**) is untouched and remains **OPEN**. |
| **Correction** | **2026-09-20, ruling G-1: §4's "joint disclosed dimension = the sum of the parts" was NOT COMPUTED before that date** — the tool hard-coded it and stage 4 could not fail. **§12** states the defect, the joint computation that replaces it, its controls, the certifying minor, and the `mle.rs` re-pin. |

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
the three stacked (**see §12: until 2026-09-20 "stacked" meant the parts
added up with an assumption, not a joint computation**). In that model the
commitment side discloses **nothing
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

> *Later the same day: the request was answered the other way round — the
> closures were PORTED to Python instead of encoded in the capture, and no new
> capture field turned out to be needed. The strong check now runs on all four
> captures; see §11. Everything above stands as the record of what was true
> before that, and of why the weak form was the honest thing to claim then.*

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

> **CORRECTION, 2026-09-20 (the security owner's ruling G-1).** As written on
> 2026-09-19 this section presented "the joint disclosed dimension is the sum
> of the parts" as a RESULT of the gate. It was not computed. The tool set
> `joint_equals_sum_of_parts` to the literal `True` and stage 4's own verdict
> to `True` with it, so the stage could not fail: the table below was four
> MARGINALS and the structural argument in the paragraph, not a joint
> elimination — as its own last sentence half-admits. **Read every "joint"
> figure in this section, as written on 2026-09-19, as NOT COMPUTED.**
> §12 records what is computed now, on the same four captures: the joint
> figure is unchanged at 4, but it is now a rank over one generator system
> built on the union of the commitments' coordinates, the endpoint planes are
> identified with A's planes because the protocol proves them equal, and four
> controls make the stage fail.

The four commitments and the CFS masks draw **disjoint** parts of one prover
randomness vector (`commit_zk_owned_with` draws fresh pads and salts per
commitment; `mask_commit` draws the CFS coefficients, their pads, `b` and
`u`). A functional supported on data coordinates that is a sum of
functionals of several channels must therefore have each channel's part
separately supported on data coordinates. **The joint disclosed space is the
sum of the per-channel spaces** — and can only be *smaller*, never larger,
if data is aliased across commitments (two channels then disclose the same
functional). *(2026-09-20: that argument is sound — §12 turns it into a
theorem about a block structure the tool now checks — but on 2026-09-19 it
was doing the work the gate claimed to be doing.)*

| capture | A | H | In | Out | PCS sum | CFS (opening only) | **joint** | sum of parts |
|---|---|---|---|---|---|---|---|---|
| both block | 0 | 2 | 0 | 0 | 2 | 2 | **4** | 4 |
| both attention | 0 | 2 | 0 | 0 | 2 | 2 | **4** | 4 |

(Under the pessimistic CFS accounting of §3 the joint figure is 70 Fp on the
block and 58 Fp on attention, all of it the public terminal identities.)
This is the first time A and H have been treated together for this profile
rather than apart: the answer is that the stacking adds nothing, for the
structural reason above rather than by a joint elimination. *(2026-09-20:
"rather than by a joint elimination" is the sentence that should have been
read as a warning. The joint elimination exists now — §12.)*

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
   so the joint disclosed dimension is the sum of the parts). *(CORRECTED
   2026-09-20: on 2026-09-19 that last clause was an assumption the tool
   hard-coded, not evidence it produced. Since §12 it is computed — one
   generator system over the union, the joint dimension by rank — and the
   disjointness of the randomness is itself a checked property of that
   system rather than a premise.)*

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

## 11. 2026-09-19 (later) — the terminal polynomials ported: the STRONG form of each slot's final check

| | |
|---|---|
| Author | a second delegated security lane (Claude Opus 5), same worktree, 2026-09-19 |
| Asked for by | Codex, in the integration review: *"port the 23/18 terminal polynomials to the Python diagnostic and compare every recomputed value against all four captures… with a changed-terminal negative control"* |
| Port | `scripts/zk60_native_terminal_polys.py` (pure Python, the field layer imported from the existing tool) |
| Runs as | stage 7 of the gate, and as its own command (`--evidence results/zk60_native_terminal_polys`, 1.2 s) |
| **Status** | **Still no privacy property.** This is a consistency check of the verifier's view at the receipts' real challenges. **D8/D11 untouched and OPEN.** |

### 11.1 What is now checked

§3.1 could assert only the **weak** identity `mask_eval = (fin − stored
terminal_polynomial) / c`, because the composition polynomial is a Rust
closure. All 41 closures (23 block, 18 attention) are now **ported to Python**,
so the verifier's own final equation is recomputed and compared, per slot:

> `fin_s == c_s · mask_eval_s + poly_s(vals_s)`
> (`private_block/argument.rs:340`, `private_attention/argument.rs:326`)

with `vals_s` rebuilt exactly as the verifier builds it
(`argument.rs:328-339` / `:314-325`): `sel·eq_point(point, rho_main[start…])`
for an eq table, `sel·eval_mle_ext(values, rho_main)` for a public table, the
**published terminal** for a private one, and `sel = Π(1 − e)` over the
extension challenges. `fin_s` is recomputed from the published rounds,
`c_s` and `rho` come from the stage-1 transcript replay, the challenges each
closure captured are the slot's `definition_challenges` consumed in the Rust
draw order, and `alpha`, `beta`, `g_u8`, `g_exp`, `g_act` come from the
capture's `logup_challenges` = (β, γ, α) with `g_x = γ·TAG_x`.

**No new capture field was needed.** The request of §3.1 is answered the other
way round: the closures were ported rather than encoded, and everything the
evaluation needs — the definition challenges, every eq point, every public
table's full `2^main` values, the terminals, the hosted coefficients — is
already in the schema-3 capture. **Nothing is "not checkable from this
capture"** on any slot of any capture. The one cross-slot value a closure
reads, `pts.lam_z` (drawn in `SC_RS`, read again by `SC_SZC`), is the `SC_RS`
slot's seventh definition challenge of the same capture.

Before a slot is scored, four structural facts must match the port's declared
table: the slot's index, its name, its **number of definition challenges**
and its **table push order**. A mismatch makes that slot `not_checkable` with
the reason, never silently equal.

**What this check does NOT cover, stated so it is not read into it.** The
PUBLIC tables (the folded int8 weight columns, the RoPE `C`/`S'` tables, the
causal mask, the U8 / exp / activation value tables) are taken from the
capture, which records the values the verifier itself built; they are **not
re-derived from the public statement**, because the bundle carries only the
statement's digest, not the public fixture. So this is the verifier's own
equation on the verifier's own view, and the tie between those tables and the
caller's public statement is the one the *receipt's* transcript makes
(`public-statement` and `schedule` are absorbed in the header, §1), not one
this stage re-checks. Re-deriving them here would need the public fixture, or
a per-table digest, in the capture — a request only if someone wants that
second tie checked, not a gap in the equation above.

### 11.2 Results — all four captures, every slot

| capture | profile | slots | checked | **equal** | not checkable | poly = stored `terminal_polynomial` | mask eval = its M functional |
|---|---|---|---|---|---|---|---|
| `40083e7ac8f3f6c7…` | block | 23 | 23 | **23** | 0 | 23 / 23 | 23 / 23 |
| `7d334e069c84f0c1…` | block | 23 | 23 | **23** | 0 | 23 / 23 | 23 / 23 |
| `6c5e83fd1b2d8c16…` | attention | 18 | 18 | **18** | 0 | 18 / 18 | 18 / 18 |
| `c26d1f05754be35c…` | attention | 18 | 18 | **18** | 0 | 18 / 18 | 18 / 18 |

**82 of 82 slot equations hold**, at the receipts' real challenges. The last
two columns are the links to the rest of the gate: the recomputed polynomial
equals the value the capture stores (which is what §3.1's weak identity used),
and each slot's mask evaluation is the value of the M functional the schedule
reserves for it (`[Γ_s if standalone] eval_s`, hosts' batched Γ last), which
is the functional stage 3 shows is absorbed by the M opening.

### 11.3 Negative controls

Each perturbs one published or ported quantity by one and is undone
afterwards; the requirement is that it fails **at that slot and only there**.

| control | block | attention |
|---|---|---|
| one term of the SLOT'S PORTED POLYNOMIAL (+1), every slot in turn | fires at that slot only, 23 / 23 | fires at that slot only, 18 / 18 |
| one CLAIMED EVALUATION (a published terminal) perturbed, every slot in turn | fires at that slot only, 23 / 23 | fires at that slot only, 18 / 18 |
| the same two, as the gate's standing controls on all four captures (slots 0, 11, 14, 17 block / 0, 9, 10, 13 attention) | pass | pass |
| a slot's table push order altered | that slot is reported `not_checkable`, the run is not `ok` | — |
| a pinned Rust source changed by one byte | `SourcePinError` naming the file | — |

The second row is the gap §3.1 measured and could not close: **the weak
identity is blind to a perturbed terminal, the ported polynomial is not.** A
test asserts both halves side by side on slot 14 of a block capture — the weak
per-slot identity still passes 23 / 23 while the strong check fails at 14.

### 11.4 Source pins, and what remains a reviewed obligation

The port is a transcription of code that lives elsewhere, so eight Rust files
are pinned by **sha256 and git blob id** and re-checked at run time — both
`argument.rs` (the closures), both `layout.rs` (plane indices, lookup lists,
shifts, slot order), both `protocol.rs` (the (β, γ, α) derivation and the
tags), `native_capture.rs` (the meaning of every captured field the port
reads) and `zkp-core/src/mle.rs` (`eq_point`, `eval_mle_ext`). A changed file
is a **hard error** that refuses to run and says to re-read the closures
rather than re-pin. The pins are listed in `SOURCE_PINS` and copied into
`ZK60_NATIVE_TERMINAL_POLYS_PROGRESS.md`.

**REVIEWED OBLIGATION — stated plainly.** The equality of each Python function
with its Rust closure is established **by reading, not by machine**. The
reader is the delegated Opus agent that wrote the port; **the security owner
has not re-read it line by line**, and no test can establish it (a test can
only show that the two agree on the four captures' challenges, which is what
§11.2 is). What the 82 agreements are worth: each closure is a polynomial of
degree up to 4 in up to 61 table values at challenges neither side chose, so a
wrong constant, a wrong plane index or a dropped term would have to vanish at
those points — but that is evidence, not a proof of transcription.

Unchanged by any of this: **no privacy property is established**, the joint
hypothesis of the sequential-kernel lemma stays open (U-3), the hash layer is
untouched, and **D8 / D11 remain OPEN**.

### 11.5 Reproduce

```
python3 scripts/zk60_native_terminal_polys.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_terminal_polys
python3 scripts/zk60_native_joint_view.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_joint_view
python3 -m unittest discover -s tests -p "test_zk60_native*.py"
```

The port writes `results/zk60_native_terminal_polys/terminal_polys.json` and
the marker `terminal_polys.done`; the gate's record gains
`stage7_terminal_polynomial_port` (the same per-capture rows, the pins, and
`privacy_property_established: false`). Counts, names and equal / not-equal
only: no witness value, salt or plane leaves the capture bundles. The gate
still runs in ~18 s; stage 7 adds ~2 s.

## 12. 2026-09-20 — the defect in stage 4, and the joint computation that replaces it

Written by a delegated agent working for the security owner, on lane
`zk60-native-jointview`, after ruling **G-1** of
`ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`. Nothing in this section
establishes a privacy property; the project's open obligations (D8/D11, the
nonlinear link between the channels, the hash layer) are untouched.

### 12.1 The defect, plainly

`scripts/zk60_native_joint_view.py` stage 4 wrote

```
"joint_equals_sum_of_parts": True,          # a literal
...
return {"per_capture": rows, "ok": True}    # a literal
```

so **stage 4 could not fail**, whatever the four captures contained, and its
"joint" column was the four per-commitment figures added together. Every
statement in this report, in the privacy case and in the messages to the
integrator that quoted *"joint disclosed dimension 4, equal to the sum of
the parts"* as a computed fact was quoting **four marginals and an
assumption**. The assumption was reasonable and is argued in §4 — the
commitments draw disjoint randomness — but an argument in a docstring is not
a gate. The defect was found by the generic-rank lemma's drafter, confirmed
by its independent check, and ruled on by the security owner, who had
written the tool's acceptance and repeated the figure.

### 12.2 What is computed now

`scripts/zk60_native_jv_joint.py` builds **one generator system over the
union of the receipt's commitments** — A, H, the two endpoints and the
masking commitment M — and computes

```
k0_joint  = rank(gens_joint) - rank(gens_joint | non-data coordinate classes)
joint     = 256 * k0_joint + (the u-row term)  +  the CFS channel's own figure
```

over the joint coordinate set, in which **coordinates the protocol makes the
same unknown are identified** and a shared coordinate merges two columns
into their sum. The per-commitment parts are recomputed through the same
code path and cross-checked against stage 2's, so the two sides of
`joint == sum` are like for like.

**What is shared at these two toy profiles, read off the capture and the
pinned Rust rather than assumed.** The last two slots of either profile
(`SC_IO_IN`, `SC_IO_OUT`; `private_block/argument.rs:902-908`) are
Standalone slots — `SLOT_KINDS`, `layout.rs:474-498`, so the sum they prove
is zero and the published scalar is the CFS mask term alone — running
`eq(tau) * (A_plane - endpoint_plane)` over 9 variables. A zero sum at a
random `tau` says the two planes are **equal**, so each endpoint's two data
rows *are* two of A's data rows, position by position. The tool rebuilds
those four row pairs from the capture's own claim offsets and points
(`A[10] = Input[0]`, `A[11] = Input[1]`, `A[68] = Output[0]`,
`A[69] = Output[1]` on the block captures) and refuses to guess. **No
blinding source is shared**: every commitment draws its own pads, its own
reserved mask pairs and its own proximity rows, and M its own coefficients,
so no identification class contains a non-data row of two roles — which the
tool checks and reports. That makes the non-data block **block diagonal by
role**, and `joint == sum` a *theorem* about that block structure at these
profiles. The output says so in words, and the rank is computed anyway.

Identifying **data** coordinates can only *lower* the joint (two commitments
disclosing the same functional would otherwise be counted twice). What that
aliasing is worth here is also computed: **0** — the only disclosed
functional lives on H, which is identified with nothing.

**M participates as a commitment** (its `2*slots + 4` rows and its proximity
combination) but commits no witness data, so its contribution to `k0_joint`
is nil — computed, not argued. Its own disclosed figure belongs to a
different unknown space, the honest sumcheck round messages, and is added.

### 12.3 The per-capture table (all computed)

| capture | profile | joint | sum | equal | joint `k0` | u-row term | coordinate classes | certifying minors `g` (A/H/In/Out) | distinct opened columns |
|---|---|---:|---:|---|---:|---:|---:|---|---|
| `40083e7ac8f3` | block | **4** | 4 | yes | 0 | 2 | 899 | 72 / 20 / 4 / 4 | 246 / 242 / 246 / 241 |
| `7d334e069c84` | block | **4** | 4 | yes | 0 | 2 | 899 | 72 / 20 / 4 / 4 | 243 / 240 / 231 / 239 |
| `6c5e83fd1b2d` | attention | **4** | 4 | yes | 0 | 2 | 646 | 62 / 18 / 4 / 4 | 234 / 243 / 243 / 235 |
| `c26d1f05754b` | attention | **4** | 4 | yes | 0 | 2 | 646 | 62 / 18 / 4 / 4 | 241 / 239 / 237 / 239 |

Shared coordinate classes per capture: **4 data** (the two endpoint planes),
**0 non-data**. Joint without the endpoint identification: 4 — the aliasing
is worth 0. The figure is the same 4 as before; what changed is that it is
now the output of a rank rather than of an addition and a literal.

### 12.4 The joint reduction is itself validated against a dense rank

The joint figure is a *reduction*: on a receipt the dense alternative is a
rank over roughly 400,000 unknowns. So the reduction is checked the way the
per-commitment one already was — on a small model where both can be
computed. `zk60_native_jv_smallmodel.joint_controls()` stacks two toy
commitments and computes the joint disclosed dimension **from the
definition, densely**, against the reduction:

| case | marginals (brute force) | joint (brute force) | joint (reduction) | agree |
|---|---|---:|---:|---|
| two honest commitments | 0, 0 | 0 | 0 | yes |
| one **blinding** row shared | 0, 0 | **4** | 4 | yes |
| one **data** row shared | 0, 0 | 0 | 0 | yes |

The middle row is the whole point: **both marginals are 0 and the joint is
positive.** (The identification is of message coordinates only; each
commitment still draws its own pads, as `commit_zk_owned_with` does.)

### 12.5 The controls on the real capture — each makes stage 4 FAIL

Run on the first block capture; the honest verdict is recorded beside each.
Honest: `ok`, joint 4, sum 4.

| control | what it does | honest | perturbed | which way it moved |
|---|---|---|---|---|
| **(a) a blinding source shared across two commitments** | `A[213]` and `H[280]` — one reserved mask row of a singleton opening group in each — made the same unknown | passes | **FAILS** | **UP.** The marginals do not move at all (`A 0, H 2, In 0, Out 0`, unchanged) and the joint rises from 4 to **260**: `k0` goes 0 → 1, so one whole message row (256 Fp) becomes determined. A combination of the two commitments' group vectors now cancels on every non-data coordinate and survives on the data rows. This is exactly the case the literal hid. |
| **(b) one masking row removed from one commitment** | `A[213]` deleted, so that singleton group's non-data block is 2 generators against 1 column | passes | **FAILS** | UP **in the marginal as well**: A alone discloses 256, the sum rises to 260 with the joint, so the equality survives and the stage fails on its other arm — *a part exceeding its expected public value* (`A: 256 > 0`). |
| **(b′) one pad fewer than the distinct opened columns** | A's pad count set to 245 against 246 distinct opened columns | passes | **FAILS** | the pad step (H-pad) fails, so the ranks are no longer a disclosed dimension at all and the stage **refuses** rather than printing a number. |
| **(c) a claim's weight reaching a non-data row outside its reserved pair** | A's claim 0 given a weight on row 215, another claim's pair row | passes | **FAILS** | the pair step (H-pair) fails — two claims now share a reserved pair — and the stage refuses. On a real receipt the Rust verifier panics first, on the row-span assertions in `pcs.rs` (ruling G-3). |

**A control that cannot fire is not a control — and here is where this one
cannot.** The joint rank sees a shared blinding row only where the non-data
block is *tight*: a singleton opening group's reserved pair is two
generators against exactly two columns, so losing one column costs a rank.
Where a group has several claims (A has 17 singleton groups out of 35, H has
2 out of 9) the block has slack and the *same* sharing changes no rank at
all. That is recorded as a test — the honest capture passes, the
tight-position sharing fails, the slack-position sharing passes — so the
blind spot is visible rather than hidden. It is a limit of this linear
model, not a property of the protocol: in the protocol nothing is shared at
all, which is the checked fact above.

### 12.6 The certifying minor (what the lemma needs printed)

`ZK60_GENERIC_RANK_LEMMA.md` §1.3 makes the good event *"the non-data block
of the generators has full row rank `g = 2(G+1)`"*, i.e. *some* `g x g`
minor does not vanish; the check's gap list noted that the tool never
printed one. Stage 2 now emits, per role and per capture,
`certifying_minor`:

* `generator_indices` and `non_data_row_indices` — the `g x g` submatrix
  chosen by the row reduction's pivot columns,
* `determinant` as an element of Fp, and `determinant_nonzero`,
* `g`, `G` and `rank_on_non_data_rows`.

Measured: `g = 2(G+1)` exactly, the rank equals `g`, and the determinant is
nonzero, for every role of every capture — A 72 (G 35), H 20 (G 9), each
endpoint 4 (G 1) on the block; 62 / 18 / 4 / 4 on attention. Beside it the
budget the minor must live inside: `distinct_opened_columns` (231–246 of the
256 sampled — they are drawn *with* replacement) against `pad_count` (256),
with the explicit check `distinct_opened_columns <= pad_count`. The rank of
the pad block *is* the number of distinct columns, so that inequality is the
entire pad budget and it has no slack by construction (ruling: the pad count
and Q move together, always).

Two tests hold this honest: each reported determinant is recomputed **from
the emitted indices alone** by a fraction-free Bareiss recurrence written in
the test file — a different algorithm from the tool's normalised elimination
— and a perturbed index set with a repeated column is checked to come out
singular under both.

### 12.7 The `mle.rs` re-pin (the integrator's request)

The integrator's commit `4bf1fa0` on `perf/zk-batch-optimizations` adds an
integer fast path to `fold_rows_i8` and `fold_rows_i32`. The merge into this
lane was clean. Every other function of `zkp-core/src/mle.rs` is
**byte-identical** to the bytes the four captures were taken against, among
them all six the Python tools port or rely on (`eq_table`, `eq_table_msb`,
`eq_point`, `eval_mle_base`, `eval_mle_ext`, `interpolate_eval`). The
changed pair computes the same field values: `Fp` is a canonical `u64`, so
the deferred accumulator holds the exact integer sum whose residue is the
inherited loop's field sum; the zero skip drops only zero terms; the `i128`
guard makes overflow impossible and falls back where it would not; the
output's length and order are unchanged. Neither function is transcribed by
the port.

The pin table keeps **both** hashes (`REPIN_HISTORY` in
`scripts/zk60_native_terminal_polys.py`): *captured against* sha256
`131cf1b4…` / blob `649a63d3…`; *re-read and re-pinned at* sha256
`b20c8b75…` / blob `51655b76…`, 2026-09-20, by a delegated agent's reading,
with the verdict recorded function by function. **The captured proof/source
relationship is unchanged**: the receipts were produced and verified by the
old bytes, and nothing was recaptured. With the re-pin in place the gate was
rerun on the four captures and every number was identical to the retained
record except two elapsed-seconds fields.

### 12.8 What remains a reviewed obligation, and what is still open

* The **joint reduction's validity on the receipt geometry** rests on the
  same three hypotheses as the per-commitment one (H-pad, H-pair, H-prox,
  each checked per role on each capture) plus the structural fact that after
  the pad step every surviving functional is `p (x) e_t` with `t` a message
  position, so the joint message block is again a tensor product. That step
  is argued in the module's header and validated on the small model against
  a dense rank; it is **not** machine-checked at the receipt geometry.
* The **blind spot of §12.5** — sharing at a slack position is invisible to
  this rank — stands as a recorded limit.
* `joint == sum` is a **theorem about the block structure** at these two toy
  profiles, because nothing non-data is shared. At the development rung and
  the 125M shape the layout changes and the question is owed again (ruling
  G-2).
* Everything §7 lists is untouched: the nonlinear terminal link between the
  two channels, the Merkle roots, the leaf salts and the authentication
  paths, the caller-fixed endpoint-root obligation D8/D11, the adaptive and
  distributional lift. **No privacy property is established here.**

### 12.9 Reproduce

```
python3 scripts/zk60_native_joint_view.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_joint_view
python3 -m unittest discover -s tests -p "test_zk60_native*.py"
```

85 tests (69 before this lane), one pre-existing skip; the gate runs in
~21 s. The lane's own logs and a second copy of the record are under
`results/zk60_native_joint_view_fix/`; the ledger is
`docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW_FIX_PROGRESS.md`. Evidence files
carry counts, indices, ranks, determinants and hashes only.

## 13. 2026-09-20 — the small model gets real opening GROUPS (review change R-8)

**Not a privacy acceptance.** Everything in this section is a rank of an
explicitly stated linear model on a synthetic instance whose data and
blinding are both known and both public. No receipt, capture or Rust source
is read or written by it.

### 13.1 What was never validated before

Stage 2's reduction replaces one dense rank over ~10^5 unknowns with small
rank computations plus three checked hypotheses. Its validation is the small
model (§6, `scripts/zk60_native_jv_smallmodel.py`): a toy commitment where
the dense rank *is* computable, so the reduction can be compared with the
truth. **That toy has one opening group per claim.** The real receipts do
not: `pcs.rs::group_zclaims` batches every claim with the same column-weight
key into ONE group, `zk_rhos` draws a coefficient `lambda_c` per member, and
the prover publishes one group vector for the batch plus every member's
claim value separately. A's largest group on the block profile has **35
members**.

So the object the reduction is actually applied to — a `lambda`-batched
group — had never appeared in the thing that validates the reduction. The
independent review of the terminal-surjection step
(`ZK60_TERMINAL_SURJECTION_REVIEW.md`, 2026-09-20) made that its change
**R-8**, and the security owner accepted it
(`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, ruling block "J-2 is
resolved"). Two further shapes had never appeared either: a group whose
members **share** a reserved mask pair, and the legitimate cross-group
sharing that H actually performs.

### 13.2 What is validated now

`scripts/zk60_native_jv_groups.py` **subclasses** `ToyView` and overrides
only `build()` (the group schedule) and `hypotheses()` (the group-aware
checks). The dense forward map (`observation_rows`), the dense disclosed
dimension (`disclosed_bruteforce`) and **the reduction under test**
(`disclosed_reduction`) are inherited unmodified, so "reduction" below is
the gate's own code and "dense" is a rank of the full forward map with no
reduction at all. The toy geometry is the existing one: `n = 4` message
columns, `q = 4` pads, 16 encoded positions, three data rows.

`tests/test_zk60_native_small_model_groups.py` — 27 tests, one of them a
recorded `expectedFailure` (case f). Evidence:
`results/zk60_native_small_model_groups/small_model_groups.json`, written by
`python3 scripts/zk60_native_jv_groups.py --evidence
results/zk60_native_small_model_groups` in ~0.5 s and reproduced exactly by
a test, because the model is seeded.

### 13.3 The six cases

"per-group" is the reviewed step applied one group at a time, in **its own
model** (a reserved pair is two unconstrained uniform rows). `n = 4` here,
so a figure of 4 is the toy's analogue of 256 `Fp` at the real scale and 8
of 512.

| # | case | dense (full map) | reduction | per-group | expected | observed |
|---|---|---|---|---|---|---|
| **a** | multi-member group, `m = 3, 4, 5`, 4 challenge draws each (12 instances) | 0 | 0 | 0 | agree at 0 | **as expected** |
| **b** | two ordinary terminals on one reserved pair, same group | **2** | **0** | 2 | dense > 0 | **as expected; the reduction does not see it** |
| **b'** | the same two terminals in two different groups | **2** | **0** | **0** | dense > 0 | **as expected; per-group misses it too** |
| **c** | H-style: two groups on the zero-sum pair, tied by a public identity | **2** | **2** | **0** | jointly 2 | **as expected; per-group is wrong** |
| **d** | singleton group, pair weights `Fp`-dependent, `cm != 0` | **4** | **4** | 4 | `n` = 4 | **as expected** |
| **d'** | the same broken shape in a 4-member group | 0 | 0 | 0 | 0 | **as expected** |
| **d''** | singleton group, pair removed (`cm = 0`) | **8** | **8** | 8 | `2n` = 8 | **as expected** |
| **e** | `lambda_c = 0` on one member, `m = 3, 5`, 3 draws each | 0 | 0 | 0 | 0 | **as expected** |
| **f** | one opened position beyond the pad budget, 3 draws | **3** | **refused** (0 unguarded) | 0 | dense > 0 | **as expected; see 13.5** |

Four readings.

* **The batched case is sound and the closed form holds.** On every honest
  multi-member instance the reduction and the dense rank are both 0, and the
  per-group blinding rank is exactly the review's closed form
  `2(n + m) − 2` for every `m` from 1 to 6 — observation space `2n + 2m`,
  codimension exactly 2, which is the verifier's own identity
  `<v_g, cw> = Σ λ_c y_c` and nothing else. Machine-checked here for the
  first time.
* **`lambda_c = 0` does not disclose** (case e), confirming the review's
  demotion of that condition: its refusal in
  `check_opening_challenges` is a soundness refusal. The zeroed member's
  pair drops out of the group vector while still blinding that member's own
  published terminal (support 2 of 2, no surviving functional).
* **The shape of the pair is what carries it** (cases d, d', d''). With
  `cm != 0` but the two weights `Fp`-dependent, a singleton group discloses
  a whole message width and the same broken shape in a 4-member group
  discloses nothing — so the condition must be in the *statement*, not
  inferred from a figure.
* **Marginals are not enough** (case b). Each of the two terminals sharing a
  pair has support dimension 2 of 2 — uniform on `Fp2`, no surviving data
  functional, indistinguishable between data vectors. Their **joint** support
  is 2 of 4, with a 2-dimensional annihilator whose image on the data is
  2-dimensional, and the two data vectors `0` and `e_j` give **disjoint**
  supports. Both marginals are the same measure for both data vectors; the
  joint is a different measure for each.

### 13.4 The H exception, machine-formed

Case c models H's two groups: one claim evaluates the zero-sum rows and
carries its own reserved pair (the `zsum` slot), the other's reserved pair
**is** the zero-sum pair and its group's column weights are all-ones (the
LogUp sum claim). Under the published constraint `Σ_t msg_u[t] = 0` the
pair's contribution to that claim's value vanishes identically, so the value
is pure data.

* Ranked **jointly**: 2 `Fp`, and the span of what is disclosed equals the
  span of that claim's own data-row weights exactly
  (`rank_disclosed = rank_public_identity = rank_of_both_together = 2`) —
  the same span comparison `RoleView._disclosed` makes on the real captures.
* Ranked **per group in the step's own model**: **0**. The step treats a
  reserved pair as two unconstrained uniform rows; the zero-sum pair is not
  that. Put the public constraint back into the per-group system and it
  returns 2.
* The gate's own `H-pair` check **passes** here, exactly as
  `audit_claims` does on the real H: a claim may evaluate the zero-sum rows
  as well as carry its own pair, so the two groups' pair keys differ and
  nothing fires. The premise that actually fails is the review's assembly
  premise (a), *pairs disjoint across groups*; the model reports it
  separately as `groups_pairwise_disjoint_off_data`, and it is `false`.

That is the machine form of the review's §3.4 exception: the number 2 is
right, and it is right because of the joint computation, not because of the
per-group argument.

### 13.5 Findings about the tool's reduction

**F-1 — the reduction does not see one opened position beyond the pad
budget** (confirms the review's §3.5 / addendum A5 against this gate's own
reduction, not only the review's). Dense 3 `Fp`, reduction 0. It is not a
wrong rank: it is the right rank of the wrong system, because the reduction
of the full view to the message half is licensed only under `H-pad`. The
test records it as an `expectedFailure` with that reason, so it cannot be
lost by someone reading a green suite.

**The guard.** The real-capture path already carries the condition
(`zk60_native_jv_pcs.py`, `_check_pad_budget` → fact
`distinct_opened_columns_within_pad_count`, which feeds stage 2's verdict
and is asserted by a test on every role of every capture). The small-model
path did not. `GroupedToyView.disclosed_reduction` now raises
`PadBudgetRefusal` on exactly that condition — *distinct opened positions >
pad count* — before computing anything, and is silent at the budget.
`disclosed_reduction_unguarded` remains, so the finding stays exhibitable.

The guard lives in the new module rather than in
`zk60_native_jv_smallmodel.ToyView` because that file's SHA-256 is written
into the gate's own record (`zk60_native_joint_view.py::TOOLS`) and compared
by `GateRecord`; editing it would change
`results/zk60_native_joint_view/joint_view.json`, which this lane may not
do. Moving it into `ToyView` is a one-line follow-up for the next time the
gate's evidence is regenerated. A test pins the current behaviour of the old
class so the difference cannot be forgotten.

**F-2 — the reduction is blind to pair sharing; the `H-pair` check is the
whole defence.** Case b: dense 2, reduction 0. The reduction drops the
individual claim values (that collapse is exactly what `H-pair` licenses)
and the group vector is unharmed by two members sitting on one pair, so
`k0` stays 0. The figure is only sound *behind* the check. That was always
the design; this is the first machine demonstration of what the check is
holding up.

**F-3 — sharing across two groups is invisible to the per-group system as
well** (case b'). Sharing within one group is caught by that group's own
system (the review's control C1 reproduces here at 2). Sharing across two
groups is not: each group in isolation looks perfect, and only the joint
rank sees it. The gate's `H-pair` check does catch this particular one
(the pair key repeats), but the *argument* needs the cross-group premise
stated, which is what R-4 and R-5 do.

### 13.6 What remains a reviewed obligation

* The toy geometry is `n = 4`, `q = 4`, three data rows and one or two
  groups. The receipt geometry is 256 / 256 / up to 35 members and 35
  groups; the review computed the real sizes independently
  (`results/zk60_terminal_surjection_review/`), and the agreement of the two
  is read, not machine-linked.
* The model is the same model stage 2 states — affine in `(msg, pad)` at
  **fixed** challenges. The Fiat–Shamir lift, the hash layer, the leaf salts
  and the authentication paths are outside it, as everywhere else in this
  report.
* The `H-pair` check's exception for the zero-sum rows is now shown to be
  load-bearing; whether every future profile's layout keeps the two groups
  tied by a public identity is a **layout obligation**, not a fact this
  model can establish.
* **No privacy property is established by any of it.**

### 13.7 Reproduce

```
python3 scripts/zk60_native_jv_groups.py \
  --evidence results/zk60_native_small_model_groups
python3 -m unittest discover -s tests -p "test_zk60_native*.py"
```

139 tests (112 before this lane), one pre-existing skip and one recorded
expected failure; the case runner takes ~0.5 s. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_SMALL_MODEL_GROUPS_PROGRESS.md`. Both gates
were re-run against the four real captures afterwards and their records
compared with the committed ones; nothing but the timing fields moved.

## 14. 2026-09-20 — the masking commitment M ported: its three OPEN channels closed

Author: delegated security lane (Claude Opus 5), worktree
`/home/victor/wt-zk60-jointview`, branch `zk60-native-jointview`, off
`1857c04`. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_GATE_CHANNELS_PROGRESS.md`.

**Nothing in this section establishes a privacy property and nothing here is
a privacy acceptance.** The P10 gate is a consistency gate on four captured
receipts at two fixed toy layouts. Every figure below is a rank, a count or
an entry-by-entry comparison in an explicitly stated **linear** model at
those four receipts' real challenges.

### 14.1 The channel table, before and after

P10 grades 28 channels, and its `by_status` count is identical on all four
captures. Before this lane, and after:

| | CONSTRUCTED | DERIVED | ARGUED | OPEN |
|---|---|---|---|---|
| **before** (record of 04:41) | 8 | 2 | 8 | **10** |
| **after** (record of 05:01) | **11** | 2 | 8 | **7** |

The three that moved are M's own: **the M opening's `q`**, **the M proximity
vector** and **opened column values (the M opening's own 256 columns)**. All
three said the same thing before — "a port of `encode_coeffs_coset` and
`mask_commit`'s row layout into this tool; **no capture field is missing**"
— and the port is what this section reports.

Nothing else moved. The two records were compared key by key: every
difference is inside those three channel entries or the two `by_status`
counters, with `seconds`, `tool_sha256` and the new `version_2` note
excluded. No other channel's status, no fibre dimension, no rank and no
mismatch count changed.

**The seven that remain OPEN, each with why and the memo that covers it.**
None of them is closable from a capture, and none of them needs a capture
field that does not exist — so **no field was requested from the
integrator**, and in particular none that is a function of hidden data (the
security owner has already refused one such, a slot's unmasked honest
rounds).

| channel | § | why it cannot be closed here | covered by |
|---|---|---|---|
| whether a proof attempt produced a receipt | 2.2 | a refusal event. One refusal class is witness-dependent at about 2^-112, and **no capture can ever show it, because a capture only exists when the proof was accepted** (ruling C-2) | the refusal rate counted as liveness in `ZK60_HASH_LAYER_AND_FS_LIFT.md` (revised) |
| rejected-but-emitted receipts | 2.2 | a procedural condition on the deployment (history item H8): `finish` has no equality precheck, so a rejected receipt is fully constructed and must never be transmitted | a deployment condition, not a channel |
| retained captures | 2.2 | a procedural condition (H9): a retained capture IS a published opening of its two endpoint roots. Today the writer is behind `#[cfg(test)]` and every capture is of a deliberately public fixture | a deployment condition (and the D8/D11 obligation) |
| timing, memory, power | 2.2 | declared out of scope for the first MVP (M-5, ruling C-2); no field of the capture bears on it | a scope ruling |
| prior proofs by the same prover | 2.2 | multi-receipt composition; this gate analyses one receipt at a time | `ZK60_JOINT_LAW_COMPOSITION.md` (revised), chain item 21 / open item U-3b |
| the integer-range facts the statement implies | 4.2 r16 | chain item 20: the statement implies the hidden values are in range, which is information about them that **no preimage argument removes** | `ZK60_JOINT_LAW_COMPOSITION.md` (revised) |
| any nonlinear functional of the joint view | 4.2 r17 | the terminal identity links the commitment and masking channels with degree up to 4 in the terminals, and **no linear model sees that link** | `ZK60_JOINT_LAW_COMPOSITION.md` (revised) |

The eight ARGUED channels are unchanged: the three hash-layer ones (the
roots, the 256 leaf salts per opening and the 11- and 12-level
authentication paths) under M-2 and M-3, the four shape-fact ones, and the
public statement and policy under condition O-1. **The port does not hash**,
so it moves none of them.

### 14.2 The port

`scripts/zk60_native_mask_commit.py`. Six source pins, each checked (sha256
and git blob) at every entry point, and each ported function's docstring
quotes the Rust it transcribes:

| pinned file | what is ported from it |
|---|---|
| `hashline/src/zk.rs` | `MASK_LOG_MSG/DOM/Q` (373-375), `MaskCommit`'s row layout (377-390, 430-467), `encode_coeffs_coset` (424-428), `combined_weights` (470-487), `weight_polys` (490-496), `poly_mul_512` (499-510), `mask_open` (512-550), `mask_verify`'s three identities (552-590) |
| `hashline/src/private_block/argument.rs` | the DECLARED functional order (361-376, 924-925) |
| `hashline/src/private_attention/argument.rs` | the same order for the 18-slot profile |
| `zkp-core/src/sumcheck.rs` | `CfsMask::len / sum_weights / eval_weights` (197-243) |
| `zkp-core/src/ntt.rs` | `forward`/`inverse` (55-108): the convention the whole port rests on |
| `zkp-core/src/pcs.rs` | `coset_powers` (605-614) and its assertion that the coset misses the subgroup |

**M's row layout**, with `S` slots (`S = 23` on the block profile, 18 on
attention; `2S + 4` rows, so 50 and 40):

| rows | what it holds | its free values |
|---|---|---|
| `0 .. 2S-1` | two a-rows per slot (re, im), each the message `[L_s coefficients \| 256 pads \| zeros]` in **value** form over G_512, with `L_s = n_s d_s + 2` | the 256 pads |
| `2S, 2S+1` | `b_re`, `b_im`, 1,024 coefficients each with the single constraint `b[512] = -b[0]` (zero sum over G_512) | 1,023 each |
| `2S+2, 2S+3` | `u_re`, `u_im`, 1,024 coefficients each | 1,024 each, unconstrained |

**The declared functional order — taken from the code, not from the earlier
memo, which had it wrong.** `run_slot` pushes, for slot `s`: a **Standalone**
slot's Gamma first, then that slot's evaluation functional; a **Host** slot's
Gamma goes to a separate list and only its evaluation is pushed here; a
**Private** slot contributes its evaluation alone. Then `argument`
(`:924-925`) does `acc.fs.extend(hosts)`. So:

> for each slot `s` in slot order: **`[Gamma_s, if slot s is Standalone]`
> then `eval_s`**; then **every Host slot's Gamma, in slot order, LAST**.

On the block capture (23 slots — 12 Private, 6 Host, 5 Standalone — and 34
functionals) the port checks that order against the capture three ways and
all three pass **34 of 34**: **position** (each functional's term rows),
**value** (against the slot's own captured `scalar` for a Gamma, `mask_eval`
for an evaluation) and **weights** (recomputed here from
`CfsMask::sum_weights * c` and `CfsMask::eval_weights` at the replayed
challenges, and for a Host Gamma the hosted terms' coefficient
`-(coef * c_hs)`). The order as the code has it, first six and last seven:

```
eval_00 eval_01 eval_02 Gamma_03 eval_03 eval_04 ...
... eval_22 Gamma_02 Gamma_14 Gamma_15 Gamma_16 Gamma_17 Gamma_18
```

**The solver.** An a-row's value at a sampled node `y` is
`sum_t msg[t] L_t(y)` with `L_t(y) = ((y^512 - 1)/512) · g^t / (y - g^t)`, so
over the pad positions the map is a **Cauchy matrix** in the distinct sampled
nodes and 256 consecutive powers of `g` — nonsingular whenever the nodes are
distinct and off G_512, both of which the gate checks. It is solved in closed
form by a rational interpolation rather than by elimination, so a preimage
builds in 1.9 s and verifies in 0.6 s per capture.

### 14.3 What the three channels now say

| figure | block (23 slots) | attention (18 slots) |
|---|---|---|
| coefficient unknowns | 1,166 Fp (583 Fp2) | 926 Fp (463 Fp2) |
| blinding unknowns | 15,870 Fp | 13,310 Fp |
| **disclosed dimension, predicted** | **2 Fp** | **2 Fp** |
| **disclosed dimension, computed** | **2 Fp** | **2 Fp** |
| fibre dimension | 1,164 Fp | 924 Fp |
| `q` entries recomputed / differing | 1,024 Fp2 / **0** | 1,024 / **0** |
| `prox` entries recomputed / differing | 1,024 Fp2 / **0** | 1,024 / **0** |
| opened column entries recomputed / differing | **12,800** / **0** | 10,240 / **0** |
| distinct opened columns / pads / margin | 246 and 247 / 256 / 10 and 9 | 247 and 249 / 256 / 9 and 7 |

(the two captures of each profile differ only in how many of the 256 sampled
column indices collide; the figures above name both)

The predicted figure is **one Fp2 — the theta-batched functional value `V`,
and nothing else** — and it is *computed*, as the exact Fp rank of `V` over
the coefficient unknowns, rather than asserted. The derivation the gate
checks rather than assumes:

* the sum over G_512 of `p_{a_s} p_{W_s}` is `sum_t msg_s[t] · ws[s][t]`;
* `combined_weights` bounds every term's weights by `L_row`, so
  `ws[s][t] = 0` for `t >= L_s` and **the pads drop out of that sum**
  (checked on every capture as `weights_vanish_above_L`);
* therefore `b`'s only constraint, its zero sum, reads exactly
  `512 (q[0] + q[512]) = V(a)` — the verifier's own first check.

This is the composition memo's hypotheses H3/H4 (M's opening depends on the
coefficients only through one functional `V(a)` that is a public function of
the rest of the view) **derived and checked here, not assumed**.

**The preimage, exhibited twice.** Two coefficient vectors, both generated
from a published seed and each corrected at one position onto the plane
`V(a) = 512 (q[0] + q[512])`, each with a full set of blinding values — 256
pads per a-row, the two b rows, the two u rows — that reproduces the captured
opening entry by entry. **All 583 coefficient positions differ between the
two**; the two blinding digests differ; both verify with zero mismatches.
And **off** that plane, at `V(a)` one away from the captured batch, `b` is
inadmissible and **the fibre is EMPTY** — while the 256 columns still match,
because the pads absorb every coefficient vector. The disclosure is exactly
that one Fp2 and nothing else.

**Honest epistemics, recorded in the gate's own JSON.** `q` and `prox` are
reproduced BY CONSTRUCTION — `b` and `u` are *defined* as the residues — so
their zero mismatch counts record that two arithmetic paths agree, not that
anything new was tested. What the `q` channel actually pins is `b`'s zero-sum
admissibility. What the **column** channel tests is genuinely independent
data: the pads were solved by rational interpolation and are re-encoded here
through the NTT path `mask_commit` itself uses, and the b and u rows' own
column values follow from `q` and `prox`.

**M in the joint stage (§4 / §12).** M was already in the union of
commitments as a block (`zk60_native_jv_joint.mask_block`: `2S+4` rows, no
data row, one published row combination — its proximity vector). Both of its
figures are now computed rather than asserted: its part over the
commitments' coordinates is **0** (it commits no witness data) and its own
disclosed figure over the coefficients is **2 Fp**, cross-checked in stage 3
against the ported layout's exact rank. Stage 4 is unchanged: **joint 4, sum
of parts 4, equal — on all four captures** (2 Fp from H's LogUp identity,
2 Fp from M's `q`).

### 14.4 The three controls

Each must PASS on the honest capture and FAIL when perturbed; each entry in
the record carries the honest verdict beside the perturbed one. All three
fire on all four captures.

| control | honest | perturbed |
|---|---|---|
| **a pad removed from M** — every a-row modelled with 245 pads against 246 distinct opened columns (the real budget is 256, margin 10, so the control has to go *below* the distinct count to bite) | preimage exhibited, 0 of 12,800 wrong | **50 of 12,800 column entries wrong** — exactly one unmet node, on all 50 rows: the 46 a-rows and the b and u rows, which inherit it |
| **the functional order permuted** — functionals 0 and 1 swapped, so each takes the other's power of theta | preimage exhibited | *flavour 1*, same coefficients: the batched value moves and **b is inadmissible**. *flavour 2*, which removes b's excuse by choosing coefficients so the PERMUTED batch still hits the captured `512 (q[0]+q[512])`: **b IS admissible and the view still has no preimage — 1,024 of 12,800 column entries wrong** (the four b and u rows at all 256 columns, first at row 46). The order is pinned by the per-column identity, not only by the scalar sum |
| **a second functional leaked** — functionals 0 and 1 published on their own beside the theta batch, as an unbatched opening would | disclosed **2 Fp** | disclosed **6 Fp**, fibre 1,164 → 1,160. Batching is what keeps M's disclosure at one Fp2 |

### 14.5 The owed one-line follow-up: the pad-budget guard in the base class

§13 left one item owed: the guard that refuses when the distinct opened
positions exceed the pad count lived only in
`zk60_native_jv_groups.GroupedToyView`, because editing the base module
changes the hash recorded in evidence already committed. It is now in the
base class. `PadBudgetRefusal` is defined in `zk60_native_jv_smallmodel`;
`ToyView.disclosed_reduction` raises it and `disclosed_reduction_unguarded`
is the way to see what the reduction would have said;
`zk60_native_jv_groups.PadBudgetRefusal` is an **alias of the same class**,
so every existing `except` and `assertRaises` against either name catches
both paths. One internal caller moved to the unguarded entry point on
purpose and says why in place: `group_pad_freedom` reads only `k0`, a rank of
the row-space generators that has nothing to do with the pad budget, and is
called on the deliberately out-of-budget case (c) of `pad_boundary`.

**Evidence regenerated, and exactly what changed in it:**

| record | command | what moved |
|---|---|---|
| `results/zk60_native_small_model_groups/small_model_groups.json` | `python3 scripts/zk60_native_jv_groups.py --evidence results/zk60_native_small_model_groups` | **`tool_sha256` and `seconds` only.** Compared key by key against the committed version: **zero** other differences |
| `results/zk60_native_joint_view/joint_view.json` | `python3 scripts/zk60_native_joint_view.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_joint_view` | `tool_sha256`, `seconds`, and 28 **ADDED** keys (M's ported figures in stage 3, M's block summary in stage 4). **No existing value changed** |

The third record that carries the same tool hash,
`results/zk60_native_joint_view_fix/joint_view.json`, is a superseded
snapshot of the §12 fix round and is deliberately left as it was.

### 14.6 What remains a reviewed obligation

* **The port equals the Rust by this lane's reading only.** Six files are
  pinned by sha256 and git blob, every ported function's docstring quotes
  the lines it transcribes, and the arithmetic is checked against the four
  captures — but no reviewer other than this lane has read the
  transcription. A changed pin is a hard error, never a warning, and
  re-pinning to make it pass is forbidden.
* **The port does not hash.** M's root, its 256 leaf salts and its 12-level
  authentication paths stay ARGUED under M-2 and M-3.
* **Four captures, two toy layouts, fixed challenges.** Nothing here is a
  statement about the 125M profile, about all challenges, or about the
  composition of the channels into one law.
* **The seven remaining OPEN channels of §14.1** are unchanged, and four of
  them are conditions on a deployment or on scope rather than anything a
  gate can close.

### 14.7 Reproduce

```
python3 scripts/zk60_native_privacy_gate.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_privacy_gate_channels \
  --columns full --controls-on all
python3 scripts/zk60_native_joint_view.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_joint_view
python3 scripts/zk60_native_jv_groups.py \
  --evidence results/zk60_native_small_model_groups
python3 -m unittest discover -s tests -p "test_zk60_native*.py"
```

P10 takes 222 s with M (193 s without), the joint view 24 s, the case runner
0.6 s. **161 tests in 213 s, OK** (139 before this section; 21 new in
`tests/test_zk60_native_mask_commit.py`, and one more in
`tests/test_zk60_native_small_model_groups.py` for the guard's two names),
one pre-existing skip and one recorded expected failure. Logs:
`results/zk60_native_privacy_gate_channels/tests_baseline.log` (139, OK) and
`tests_after.log` (161, OK).

## 15. 2026-09-20 (13:46 PDT) — the committed P10 record refreshed: it was stale, and no number moved

Bookkeeping, not a result. **No figure quoted in this report or in
`ZK60_NATIVE_PRIVACY_GATE.md` changes, no privacy property is claimed and
nothing here is a privacy acceptance.** Evidence:
`results/zk60_native_gate_record_refresh/`.

**What was stale.** §14 closed M's three channels in the tool but wrote the
new record into one evidence directory only. Since commit `d360466`, the
older committed record — `results/zk60_native_privacy_gate/privacy_gate.json`,
last written at `825213e` — still carried the pre-port picture: `version` 1,
**8 / 2 / 8 / 10**, no `masking_commitment_M_opening` block, 7 controls
instead of 10, and the pre-port `tool_sha256`. The report numbers were right
all along; the file on disk was behind the tool that is supposed to have
produced it. The run-gate lane found it and, correctly, left another lane's
evidence alone (`ZK60_NATIVE_RUN_GATE_PROGRESS.md`, finding 5); this section
answers it.

**What the comparison showed.** The gate was re-run with the documented
command into a scratch path first, and compared leaf by leaf with each
committed record (`jsondiff.py` in the refresh directory):

| committed record | differing paths | which |
|---|---:|---|
| `zk60_native_privacy_gate/privacy_gate.json` | 218 | the three M channels on each of the four captures (`open` -> `constructed`), the two `by_status` counters, the new `masking_commitment_M_opening` block, the three M controls, `version` / `version_2`, three `tool_sha256` entries, `seconds` |
| `zk60_native_privacy_gate_channels/privacy_gate.json` | 2 | `seconds`, and `tool_sha256/zk60_native_jv_cfs.py` — that run finished at 05:01 and the pad-budget guard moved into `jv_cfs.py` at 05:02, inside the same commit |

Everything else is identical: `transcript_replay`, `model`, `fixed_inputs`,
`masking_commitment`, `proof_bytes` and `ok` on all four captures, and the
other 25 channels entry for entry. So §14.1's "**the two records were
compared key by key**" claim holds against the current tool as well.

**What was refreshed.** Both records, in place, by re-running the documented
command with the evidence path of record: **249.1 s** into
`results/zk60_native_privacy_gate/` and **267.7 s** into
`results/zk60_native_privacy_gate_channels/`, four captures `ok` and marker
`0` each (logs `gate_refresh_p10.log` and `gate_refresh_channels.log` in the
refresh directory; the box was shared, which is why the same work reads
between 240.9 s and 267.7 s across the three runs). Nothing was copied and
nothing was deleted; the old bytes stay in git history, correct at `825213e`
and `d360466` respectively. Both now read **28 channels, 11 CONSTRUCTED / 2
DERIVED / 8 ARGUED / 7 OPEN** on every capture — the counts of §14.1's
`after` row, unchanged — and each is identical to the scratch run leaf for
leaf **except `seconds`**, so the gate is deterministic at this shape over
three independent runs. `seconds` is the only figure in either file that no
report quotes.

**The guard.** `tests/test_zk60_native_gate_record.py`. The counts of record
live in one small JSON,
`results/zk60_native_gate_record_refresh/channel_counts_of_record.json`,
which this report and the test both cite; the test re-derives the counts from
each committed record's own `channels` array, compares them with that record's
own `grade.by_status`, with the pin and with the `after` row of §14.1 parsed
narrowly (the section by its heading, the status order from the table's own
header row), and compares each record's `tool_sha256` with the hashes of the
tools now in the tree — the convention `tests/test_zk60_native_run_gate.py`
already follows. **A tool edited without re-running the gate now turns the
suite red**, which is exactly what did not happen on 2026-09-20. Before the
refresh the new file was 6 tests, FAILED (failures=2), on precisely the two
things above (`guard_before.log`); after it, 6 tests, OK
(`guard_after.log`).

**One older table now reads as history.** §3 of `ZK60_NATIVE_PRIVACY_GATE.md`
states the P10 lane's channel table, 8 / 2 / 8 / 10, as of `825213e`. That
statement was and remains true of that lane; it is no longer the content of
the record in that lane's evidence directory, and a dated pointer in that
report now says so. No number in it was edited.
