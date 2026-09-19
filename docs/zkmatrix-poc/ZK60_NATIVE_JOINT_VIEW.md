# The native joint view: the complete-block and attention receipts' real verifier view, analysed at their real challenges

| | |
|---|---|
| Author | delegated security lane (Claude Opus 5), 2026-09-19 |
| Lane | `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`, based on `d399b32` |
| Inputs | the four source-pinned captures of `results/zk60_native_captures_20260919` (two `private-block-t32-poc/1`, two `private-attention-t32-poc/1`), source commit `2b5c65c3…`, verifier binary `fec86a7b…` |
| Gate | `python3 scripts/zk60_native_joint_view.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_joint_view` (19 s, record `results/zk60_native_joint_view/joint_view.json`, marker `joint_view.done`) |
| Tests | `python3 -m unittest discover -s tests -p "test_zk60_native_joint_view.py"` — 22 tests, 54 s |
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

**The pad budget is met, and only just.** Q = 256 pads are reserved per row
and the receipt opens 256 columns; birthday collisions among the 256 draws
from 2048 positions leave 231–247 **distinct** positions, so the margin is
**9 to 25 pad symbols** — and the margin only has to be positive. An exact
Gaussian elimination cross-check confirms the pad block's rank is exactly
the distinct count (246 of 246, 2.2 s); for the other role/capture pairs the
rank is taken from the Vandermonde theorem with the distinctness and
`x_j^256 ≠ 1` checks done exactly. The control "one pad fewer than the
distinct opened positions" discloses (§6), so this is a live budget, not
slack.

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
measured. Its consequence depends on an **accounting choice the security
owner must make**, because the M functional *values* are not independently
published — the verifier **derives** each from the slot's masked rounds and
its terminals (`terminal_polynomial = fin − c·mask_eval` in the capture):

| accounting | block | attention | what the disclosed functionals are |
|---|---|---|---|
| only what the M **opening** independently reveals (the single Fp2 functional `q[0] + q[512]`) | **2 Fp** (1 Fp2) | **2 Fp** | the theta-combination of the slots' terminal identities |
| **every derived mask evaluation** counted as an independent observation | 68 Fp (34 Fp2) | 56 Fp (28 Fp2) | each slot's terminal identity `φ_s(h_s) = poly_s(published terminals)` |

In both accountings the disclosed functionals of the honest rounds are
exactly the slots' **public terminal identities** — functions of values the
receipt already publishes — and not additional information about the
witness. But that redundancy is a **nonlinear** fact (`poly_s` has degree up
to 4 in the terminals), so **linear algebra cannot show it** and this
analysis does not. See §7 and the questions in §9.

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

Every control fires. The reduction agrees with brute force on both honest
instances.

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
   num_col_checks` exactly. If a future profile ever drew 256 *distinct*
   positions (probability ≈ 1.2·10⁻⁷ per opening at this geometry), the
   margin would be zero and the columns would stop being absorbed. Should
   the source reserve `q_pad = num_col_checks + 1`?
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
takes 19 s. `privacy_review_complete` and `privacy_property_established`
stay **false** in the record.
