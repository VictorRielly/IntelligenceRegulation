# The generic-rank lemma for the disclosed-dimension statement (U-3a)

**Status: REVISED AFTER INDEPENDENT CHECK — the core is accepted for the two
toy profiles, per `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md` (security owner,
2026-09-20): on the linear channels, the challenges at which anything would be
disclosed lie inside the set the prover already refuses on. Blocking items
B-1 … B-4, the corrections and conditions of
`ZK60_GENERIC_RANK_LEMMA_CHECK.md` and rulings G-1 … G-5 applied. NOT a
privacy acceptance: linear channels, two fixed layouts, nothing else; the
joint statement is not computed. Drafted by a delegated Opus agent.**

Every step is labelled proved here, relies on, or gap. The revision record is
at the end of the file.

## 0. Plain words, for a reader who is not a cryptographer

The project has a tool that takes a real receipt of the toy private block,
replays it, and counts how much the verifier's view pins down about the
hidden data. It answers "nothing" for three of the four commitments and "one
public identity" for the fourth. The objection to that answer has always
been the same: the tool measured **four particular receipts**, and a receipt
is built around random numbers the protocol draws on the fly. Four samples
do not tell you what happens on the fifth. The obligation, called U-3a, was
to show that the same answer holds for essentially all draws, not just the
four we looked at.

The usual way to do that is a counting argument (Schwartz–Zippel): show the
answer is wrong only when a certain polynomial in the random numbers happens
to hit zero, and polynomials hit zero rarely. This draft says that argument
is available but is **not the best answer here, and on a corrected count it
would not even be a good one**. The better answer came out of reading the
code: the quantity that has to be non-zero factorises into a product of very
small, very explicit pieces — one per opening, each of the form "this
challenge is not zero" or "these two challenges are not proportional" — and
**the prover already refuses to produce a proof when any of those pieces is
zero**. So on every run that produces a receipt at all, the tool's answer is
forced, not merely likely. Nothing is left to chance except the chance of
the prover throwing a run away and starting again, which costs availability,
not privacy, and happens about once in 2^62 proofs.

Three smaller results fall out of the same reading. The part of the argument
that depends on **which 256 columns the verifier opens** — the step the brief
flagged as the likeliest hiding place for a gap — turns out not to depend on
the columns at all: the relevant matrix is a Vandermonde (for the data
commitments) or a Cauchy matrix (for the mask commitment) on distinct
non-zero nodes, and those have full rank on *every* choice of rows. No union
bound over column sets is needed. The mask-commitment side is an identity
too. And the one thing the verifier *does* learn about H — a public
sum-to-zero identity, worth 2 field elements — is exactly that identity and
nothing more, again by the same block structure rather than by luck.

The one place this draft **disagrees with the earlier check of 2026-09-19**
is the size of the fallback. That sketch put the Schwartz–Zippel term near
2^-121 (a figure now withdrawn) and concluded that closing U-3a "buys a
label, not a bound". Recomputed here, the relevant matrix is twice as large
as the sketch assumed and its entries are polynomials over the *base* field,
not the extension, so the generic fallback lands near **2^-56**. The
independent check of 2026-09-20 confirmed this correction and settled it with
a two-row counterexample: full rank over the extension field on the non-data
rows does **not** imply the quantity the tool measures is zero, so a bound
taken over the extension bounds the wrong event. But a loose bound is not a
finding: 2^-55.85 is what a generic tool returns when it is pointed at a
polynomial we happen to know is a product of norm forms, and the true
probability is far smaller. The honest reading is that **the generic tool is
weak here**, which is one more reason to argue structurally, not that the
project has a problem (check correction C-7).

Two things a reader must not over-read. First, everything below is **per
commitment**: four separate statements, about A, about H and about the two
endpoints, not one statement about the four together. The joint statement —
"the joint disclosed dimension equals the sum of the parts" — is **not
computed today**: the project's own gate hard-codes it
(`scripts/zk60_native_joint_view.py`, lines 245 and 248, branch
`zk60-native-jointview`), a fix is in progress (2026-09-20), and the
per-commitment result of this lemma does not depend on it. It stays a GAP
(ruling G-1; §1.5, §3.8 row 17, §4 item 3). Second, the numerical
confirmation of record for the factorisation is the **independent check's**,
not this draft's: the check rebuilt it from the captures' real claim
schedules over 48 uniform and 78 adversarial challenge vectors with zero
mismatches, while this draft's own `pair_block_identity.py` worked on
invented groupings and is superseded for that purpose (§3.2 step 5, §7).

**Nothing in this document establishes a privacy property.** It closes one
named hole in an argument that has six others open.

## 1. The objects, exactly as the tool defines them

Everything in this section is read off the tool's source, not its prose
report. The tool is `scripts/zk60_native_joint_view.py` and its modules on
branch `zk60-native-jointview` (read-only worktree
`/home/victor/wt-zk60-jointview`); the file that matters here is
`scripts/zk60_native_jv_pcs.py` (`RoleView`), with
`scripts/zk60_native_jv_cfs.py` (`CfsView`) for the mask channel.

### 1.1 What is committed, and what the verifier sees

A proof of the toy private block opens **four** hiding commitments of the
Ligero/Brakedown-class PCS and **one** masking commitment:

| role | rows | data rows | non-data rows | opening groups G | claims |
|---|---:|---:|---:|---:|---:|
| A (activations) | 455 | 213 | 242 | 35 | 120 |
| H (LogUp helpers) | 384 | 278 | 106 | 9 | 52 |
| Input endpoint | 7 | 2 | 5 | 1 | 1 |
| Output endpoint | 7 | 2 | 5 | 1 | 1 |
| M (mask coefficients) | 50 | — (see §1.4) | — | — | 34 functionals |

(Toy attention: A 306/154/152/G=30/75, H 290/216/74/G=8/36, the same two
endpoints, M 40 rows, 28 functionals. `A_GROUPS`/`H_GROUPS` are declared
constants — `hashline/src/private_block/layout.rs:516-517`,
`hashline/src/private_attention/layout.rs:392-393` — and the verifier
refuses a different count, `private_block/protocol.rs:169-171`.)

Row `i` of one commitment is the pair `z_i = (msg_i, pad_i)` in
`Fp^256 x Fp^256`: `msg_i` is the committed message (hidden witness data on
the **data** rows, uniform on the **mask** and **proximity** rows) and
`pad_i` is that row's Q = 256 uniform pad symbols
(`zkp-core/src/pcs.rs:665-700`; the pads are drawn at `:673`, the leaf salts
at `:674`). The non-data rows partition exactly:

* **reserved mask pairs**, two rows per claim — 240 rows for A (120 claims),
  102 for H (51 evaluation claims), 2 for each endpoint;
* for H only, the **zero-sum pair** `u` (rows 278, 279), carrying the LogUp
  identity's public linear constraint;
* the **proximity pair** (the last two rows; the endpoints reserve three
  proximity rows of which the refusal uses the first two).

At **fixed** challenges the verifier's whole field-valued view of one
commitment is affine in `(msg, pad)` — this is the tool's model, stated in
`zk60_native_jv_pcs.py:1-67`:

* (a) each claim value `value_c = sum_i rw_c[i] <msg_i, cw_c>`, with the row
  weights `rw_c` and column weights `cw_c` recomputed from
  `zkp-core/src/pcs.rs::zpart_weights` (`:752-792`) and `zkey_weights`
  (`:794-806`);
* (b) each group vector `v_g = sum_i rho_g[i] z_i` (512 entries);
* (c) the proximity vector `v_prox = sum_i rho_prox[i] z_i`;
* (d) each sampled column `j`: `col_j[i] = <E_j, z_i>`, with `E_j` the coset
  encoding functional of `zkp-core/src/pcs.rs::encode_row_zk` (`:618-637`),
  in closed form `E_j[msg s] = (x_j^n - 1)/(n (x_j w_n^{-s} - 1))`,
  `E_j[pad k] = (x_j^n - 1) x_j^k`, `x_j = 7 w_2048^j`.

### 1.2 The disclosed dimension and the reduction the tool computes

Write `X` in `Fp^{rows x 512}` for the unknowns, `F` for the **Fp**-span of
all the observation functionals above (an `Fp2`-valued functional
contributes its `c0` and its `c1` coefficient vector — two Fp functionals),
and `T` for the space of functionals supported on the data rectangle
(data rows x message positions). Then

```
disclosed = dim_Fp (F  intersect  T).
```

The tool does not compute that intersection directly. It applies a
reduction, whose three hypotheses it checks on the capture and whose
validity it cross-checks against a dense brute force on a small synthetic
instance (`zk60_native_jv_smallmodel.py`):

* **H-pad** — the `d` distinct sampled columns satisfy `d <= Q = 256` and the
  pad block of `{E_j}` has rank `d`. Then no combination of the column
  functionals is supported on message positions, and (d) adds nothing.
  (`_check_pad_budget`, `zk60_native_jv_pcs.py:309-336`; the exact rank
  cross-check `pad_block_rank`, `:338-344`.)
* **H-pair** — every claim's row weights, restricted to the non-data rows,
  sit on exactly one adjacent reserved pair; that pair is used by no other
  claim; the pair's two coefficients are an Fp-basis of Fp2; no claim
  touches the proximity pair. (`_check_pair_schedule`, `:366-405`; the Rust
  enforcement is `private_block/protocol.rs::audit_claims`, `:89-133`.)
* **H-prox** — `det(rho_prox[prox], rho_prox[prox+1]) != 0`, where `det` is
  the Fp wedge `a.c0 b.c1 - a.c1 b.c0`. (`_check_prox_refusal`, `:407-417`;
  the Rust refusal is `protocol.rs:135-137,148-150`.)

Under those three,

```
disclosed = 256 * k0  +  (the u-row term),
k0 = dim { p in rowspace(rho-tilde) : p vanishes on every non-data row }.
```

### 1.3 The good event, stated as a rank

This is the step the brief insists be stated precisely, because the shape of
the event decides whether a generic argument is even the right tool.

The tool's generators of `P1 = rowspace(rho-tilde)` are, literally
(`_p1_rows`, `zk60_native_jv_pcs.py:420-426`), the **real and imaginary
parts** of the `G` group combinations `rho_g` and of the proximity
combination `rho_prox`: that is

```
g := 2 (G + 1)     Fp row vectors of length `rows`.
```

`_disclosed` (`:428-484`) then computes

```
k0 = rank_Fp(gens)  -  rank_Fp(gens restricted to the non-data rows).
```

Restricting to a subset of coordinates can only lower a rank, so `k0 >= 0`
always, and

> **`rank_Fp(gens | non-data rows) = g` implies `k0 = 0`.**
>
> Because `rank(gens) <= g` by row count, so both ranks equal `g`.

That implication is the whole reason a generic argument is usable here:
**the good event can be taken to be a rank being AT LEAST a value**, namely
the `g x R` non-data block having full row rank `g`, which is the
non-vanishing of some `g x g` minor. (The converse is false — `k0 = 0` can
hold with a smaller rank, for instance when a group vector is identically
zero; §3 uses only the implication, so the lemma is conservative.)
**PROVED HERE.**

On the captures `rank(gens) = rank(gens | non-data) = g = 2(G+1)` for every
role of every capture: 72, 20, 4, 4 for the block and 62, 18, 4, 4 for
attention (`results/zk60_generic_rank_lemma/captured_ranks.txt`).

The **u-row term** is not a rank-at-least event and must be handled
separately. For H, the layout declares a public linear constraint on the
two zero-sum rows; `_disclosed` (`:436-481`) solves, for each u row, for the
unique generator combination whose non-data restriction is that row's
indicator, maps it to the data rows (`xi`), and reports both its dimension
beyond `k0` and whether its span **equals** the span of the public LogUp
identity's data-row weights (`equals_public_logup_identity`). The reported
value is 2 on all four captures. An equality of spans is a rank being **at
most** something, i.e. a polynomial identity, not a generic statement; §3.3
proves it as an identity rather than bounding it.

### 1.4 The mask commitment M: a different shape, two different events

The mask channel is not of the same shape and the check of 2026-09-19 was
right to say so: M has 50 rows (block) or 40 (attention) — two `a` rows per
slot plus `b` and `u` — against up to 47 combined vectors, so `k0 = 0`
cannot be a full-rank condition there. The tool models it differently
(`zk60_native_jv_cfs.py:1-62`). Slot `s` runs a masked sumcheck of
`N_s` rounds and degree `d_s` over a CFS mask `g_s` with
`L_s = N_s d_s + 2` uniform Fp2 coefficients
(`zkp-core/src/sumcheck.rs::CfsMask`, `:189-276`). The hidden objects are
the **honest round messages**, which live in a consistency subspace `C_s` of
dimension `N_s d_s + 1`. With `R_s` the Fp2 matrix (coefficients -> the
`N_s` published round vectors at the replayed challenges) and `F_s` the
published functionals,

```
disclosed_s = (dim C_s - rank R_s)  +  dim( rowspace(R_s) intersect rowspace(F_s) ).
```

Two separate events, of opposite shape:

* `uncovered_s := dim C_s - rank R_s = 0` — a rank **at least** `N_s d_s + 1`,
  i.e. a minor of `R_s` non-vanishing. Generic-argument-shaped.
  (`CfsView.run`, `:399-450`.)
* `rank_F mod rounds = 0` — every published functional lies **inside**
  `rowspace(R_s)`. A rank at most, i.e. an identity. (`:463-475`.)

The M **opening** itself is handled by three source facts the tool checks
(`_mask_opening_checks`, `:515-562`): `M-q` (the only unmasked Fp2 direction
of `q` is the public theta-combination of the published values), `M-prox`
(the proximity vector carries a fresh uniform `u` row with coefficient 1),
and `M-cols` (the `d` distinct sampled columns restrict on the 256 pad
positions to a Cauchy matrix in distinct nodes, so the columns are absorbed
by the pads; exact rank cross-check `m_pad_block_rank`, `:564-586`).

### 1.5 The joint view

Stage 4 (`zk60_native_joint_view.py:226-248`) reports the joint disclosed
dimension as the **sum** of the parts — `A 0 + H 2 + endpoints 0 + M 2 = 4
Fp` on the opening-only accounting — but that sum is an arithmetic sum of
four independently computed marginals: the field `joint_equals_sum_of_parts`
is **hard-coded `True`** at line 245, and the stage's own pass flag
`"ok": True` is **hard-coded** at line 248 (`scripts/zk60_native_joint_view.py`
on branch `zk60-native-jointview`), so **stage 4 cannot fail** (check
correction C-12). The justification offered for the equality is the
disjoint-randomness decomposition written in the two docstrings, which is an
assumption, not a computation.

Therefore, per ruling **G-1**: the **JOINT statement is not computed today**,
and every earlier quotation of "joint disclosed dimension 4, equal to the sum
of parts" as a computed figure should be read as four marginals plus an
assumption. A fix is in progress (2026-09-20): a genuine joint computation
across the commitments of one receipt, a negative control that makes the
stage fail, and the certifying minor printed per role. **This lemma's
per-commitment results do not depend on the joint statement**; the joint
statement is U-3(b), a different obligation, and it stays labelled GAP (§3.8
row 17, §4 item 3).

## 2. The challenge variables

### 2.1 Which draws are independent, and from which field

Every field challenge in these two profiles is drawn by
`Transcript::challenge_fp2` (`zkp-core/src/transcript.rs:103-112`) or
`challenge_fp2_vec` (`:114-116`), i.e. from **Fp2**, `|Fp2| = p^2` with
`p = 2^64 - 2^32 + 1`; `log2(p^2) = 127.99999999...`. `challenge_fp` (the
base field, `:97-100`) is not used on these paths. Each draw is one
`squeeze_bytes` (BLAKE3) split into two 128-bit halves, each reduced mod p —
so in the random-oracle model the draws are independent and uniform up to a
per-coordinate reduction bias of at most `2^-64` (`:96`), which the privacy
case prices at `2^-96` per draw and decision D9 has already accepted.
**RELIES ON** the ROM assumption and D9; this lemma states its probabilities
for ideal uniform draws and carries the sampler residual separately (§5).

The draws that enter the matrices of §1 are:

| symbol | where drawn | count, block | count, attention | role |
|---|---|---:|---:|---|
| `lambda_{g,j}` | `zkp-core/src/pcs.rs:839` (one per claim, per group, in transcript order) | 174 | 113 | batches a group's claims into `rho_g` |
| `rho_prox` | `zkp-core/src/pcs.rs:853` — `challenge_fp2_vec(rows)`, **one fresh Fp2 per row** | 853 | 610 | the proximity combination |
| `e` (terminal-mask) | the extension rounds, `private_block/argument.rs:304` (`extension(...)`) | 25 | 20 | builds `cm`, `cd` |
| `c_s` (CFS multiplier) | `private_block/argument.rs:274` | 23 | 18 | scales the mask into the rounds |
| sumcheck round challenges `rho_j` | `zkp-core/src/sumcheck.rs` per round | — | — | the claim **points** |
| `beta, gamma, alpha` | `private_block/protocol.rs:330-332` | 3 | 3 | LogUp tags (data rows only) |
| the 256 column indices | `transcript.rs:119-131` (`challenge_indices`) | 256 per opening | same | select columns, **not** field variables |

Counts from the captures' structural header (claim and group counts, slot
geometry) — `results/zk60_generic_rank_lemma/bounds.py`.

### 2.2 Which quantities are derived, and of what degree

The claim row weights are built by `build_claim`
(`private_block/argument.rs:223-236`, identically
`private_attention/argument.rs`, and `private_seam.rs::terminal_claim:273-306`
for the standalone endpoint path). A claim has

* **data parts**: `ZPart { slice: the plane, coef: coef * cd, point: the full
  point }`, and
* **exactly two mask parts**: rows `mask_row` and `mask_row + 1`, of
  `log_size = min(p.log, LOG_N)`, with coefficients `cm * 1` and `cm * U`.

with

```
cd = prod_k (1 - e_k)                       (argument.rs:352)
cm = e_r * prod_{k > r} (1 - e_k)           (argument.rs:356, r = the table's ext_round)
```

**The decisive structural fact** is where the equality-polynomial tensors
go. In `zpart_weights` (`zkp-core/src/pcs.rs:752-792`) a part whose slice is
a whole row or less contributes its coefficient to **one** row weight with
no `eq` factor; the point tail becomes the *column* key, not a row weight.
The two mask parts have `log_size <= LOG_N`, so

> the row weights of a claim at its reserved pair are exactly `(cm, cm*U)`,
> with **no** dependence on any sumcheck point.

The `eq` expansions — the high-degree, few-variable objects the brief warned
about — live entirely on the **data** rows and never reach the non-data
block whose rank we need. **PROVED HERE, GIVEN the four assertions cited
next** (read off `zpart_weights:752-792` together with
`build_claim:223-236`; verified numerically against the captures by the
tool's own `_check_pair_schedule`, which recomputes
`det(rw[pair0], rw[pair1])` and finds it non-zero on all sixteen
role-captures).

**The four assertions that make `part_rows` exact (B-2 / C-1, ruling G-3).**
`audit_claims` reasons about a claim's support through `part_rows`
(`hashline/src/private_block/protocol.rs:74-77`), which returns
`r0 .. r0 + (1<<ls).div_ceil(N)`. That is *exactly* the support
`zpart_weights` writes — but only because of four `assert!`s in the
commitment code, **`zkp-core/src/pcs.rs:759, 768, 775, 786`**, which pin the
two shapes (`ls >= log_cols` with `offset % n == 0`; `ls < log_cols` with
`c0 + (1<<ls) <= n`). A straddling slice would make `part_rows`
under-report by one row and `audit_claims` would then miss a spill; what
prevents that is not the audit but the PCS **panicking**, and Rust `assert!`
is unconditional in release builds. So a straddle is a liveness bug, not a
leak. The independent check recomputed `part_rows` against `zpart_weights`
part by part on all sixteen role-captures — 360 / 306 / 3 / 3 parts for the
block and 225 / 210 / 3 / 3 for attention, zero over-, under- or straddling
reports — and verified from the layout that no straddle is constructible at
either toy profile. Per ruling G-3 these four assertions are recorded as
**invariants that must not be weakened: a change to them is a privacy
change** (§3.8 row 21).

Consequently the entries of the `g x R` non-data block are:

| generator rows | entry at a reserved pair of a member claim | degree in the Fp coordinates of the draws |
|---|---|---:|
| `Re(rho_g)`, `Im(rho_g)` | an Fp coordinate of `lambda_{g,j} * cm_j` (or of `lambda_{g,j} * cm_j * U`), and **zero** at every other claim's pair and at the proximity pair | `1 + ext <= 3` |
| `Re(rho_prox)`, `Im(rho_prox)` | an Fp coordinate of a fresh uniform draw | 1 |

`ext <= 2` at both toy profiles: the declared `SLOTS` table
(`private_block/layout.rs:438`) gives every slot one extension round except
the two bilinear ones, which have two, and the captures' slot geometry
agrees (25 extension rounds over 23 slots; 20 over 18). So a `g x g` minor
has total degree
at most `3 * 2G + 1 * 2 = 6G + 2` **over Fp**: 212 for block A, 56 for
block H, 8 for each endpoint; 182 and 50 for attention.

Two corrections to the sketch in `ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` §4
follow, both against the project:

1. the minor is `2(G+1) x 2(G+1)`. The sketch's literal words are `G x G` of
   an `R x G` matrix, with its `G` counting the opening groups **plus** the
   proximity vector (`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md:329-337`) — i.e.
   the same `(G+1)` said differently; the earlier wording of this correction
   misquoted it as `(G+1) x (G+1)` (check correction C-8). The substance
   stands: the tool's rank is an **Fp** rank of the realification
   (`_p1_rows`), not an Fp2 rank, so realification doubles the minor to
   `2(G+1)`;
2. the entries are polynomials in the **Fp coordinates** of the challenges
   (taking a real part is Fp-linear but not Fp2-linear), so Schwartz–Zippel
   runs over `Fp`, `2^64`, not over `Fp2`, `2^128`.

Together they move the sketch's `2^-121` — a figure the independent check
confirms is withdrawn — to about `2^-56` (§3.7, §5). The check settled the
second point with a two-row counterexample: one Fp2 generator `rho = [1, u]`
has full Fp2 rank on the non-data rows while `k0 = 1`, so an Fp2-sized bound
does not bound the event the tool measures, and there is no "standard
device" that recovers `D/p^2` without handling the conjugates (C-8; this
also answers §6 item 5).

### 2.3 The 256 opened column indices

`challenge_indices` (`transcript.rs:119-131`) squeezes bytes and masks them
into `[0, nn)` with `nn = 2048` and pushes them with no distinctness check,
so the opened columns are sampled **with replacement**: repeats are normal
and the captures show **241 to 246** distinct out of 256 (block A 246, H
242, Input 246, Output 241). A repeat helps hiding — it consumes one fewer
pad degree of freedom. These are not field variables: they **select rows**
of the pad block. A lemma "for all but a negligible fraction of
challenges" cannot be stated conditionally on the column set, because the
capture's column set is one of `C(2048,256)` and no capture can certify a
minor for a set it did not open.

The honest resolution is that **no union bound is needed, because the
relevant non-vanishing holds for every admissible column set**:

* the pad half of `E_j` is `E_j[pad k] = Z_n(x_j) x_j^k`,
  `x_j = 7 w_2048^j`, `Z_n(x) = x^256 - 1`
  (`zkp-core/src/pcs.rs::encode_row_zk:618-637`, closed form recorded at
  `zk60_native_jv_pcs.py:20-23`). The pad block on a set `S` of distinct
  indices is `diag(Z_n(x_j)) * Vandermonde(x_j)_{k<256}`, which has rank
  `|S|` for every `|S| <= 256` provided the nodes are distinct and
  `Z_n(x_j) != 0`;
* the nodes are distinct because `j -> 7 w_2048^j` is injective on
  `[0, 2048)`;
* `Z_n(x_j) != 0` for **all 2048** `j`: `x_j^256 = 7^256 w_8^j`, so it fails
  only if `7^256` is an 8th root of unity, i.e. if `7^2048 = 1`. It is not.
  Checked exhaustively over the whole encoded domain in
  `results/zk60_generic_rank_lemma/pad_block_structure.py` (`7^2048 != 1`;
  zero vanishing nodes out of 2048), with the rank verified directly on five
  column sets including the adversarial ones (consecutive, maximally
  spread, pseudo-random, the observed 246) and a negative control in which
  one repeated index correctly drops the rank to 255;
* the same for M: row `j`, pad position `t` is
  `z_j m^{-1} w^t / (y_j - w^t)` with `y_j = 7 w_4096^j`, `m = 512`
  (`zk60_native_jv_cfs.py:564-586`), a Cauchy matrix scaled on both sides.
  Cauchy matrices on distinct nodes are totally non-singular. `z_j != 0`
  for all 4096 `j` (`7^4096 != 1`), and `y_j` never collides with a message
  node — both checked exhaustively in the same script.

**PROVED HERE**, with the finite arithmetic as evidence. This is the step
the brief said was the likeliest hiding place; the answer is that the
protocol's coset construction removes it, and the capture's column set is
irrelevant to it.

## 3. The lemma and its proof

### 3.1 Statement

> **Lemma (U-3a, disclosed dimension at fixed layout).** Fix a public
> statement and layout of the toy private-block profile
> `hashline-zk-mr1/private-block-t32-poc/1` or of the toy private-attention
> profile `.../private-attention-t32-poc/1`. Run the prover on any witness
> the constructors admit, with the verifier's challenges drawn as the
> protocol draws them. Then **on every run that is not discarded by one of
> the prover's own refusals**:
>
> 1. hypotheses H-pad, H-pair, H-prox of the tool's reduction hold;
> 2. `k0 = 0` for A, for H and for both endpoints, so those commitments'
>    disclosed dimensions are `0`, `0 + (the u-row term)`, `0`, `0`;
> 3. the u-row term of H is exactly 2 over Fp and its span is exactly the
>    span of the public LogUp identity's data-row weights;
> 4. in the mask channel, `uncovered_s = 0` for every slot and every
>    published functional lies in the span of that slot's published rounds,
>    so the M opening's independent contribution is the single public
>    theta-combination, 1 Fp2 = 2 Fp.
>
> These hold **with probability 1** on non-refused runs — not "for all but a
> negligible fraction of challenges". That framing is a statement **inside
> the random-oracle model**, because the event conditioned on (the prover
> did not refuse) is itself defined by the oracle's outputs; see §3.6 and
> check correction C-11. The only probabilistic statement left is how often
> the prover discards a run and starts again: at most `2^-62.00` per proof
> at either toy profile (§5). That is a liveness cost, not a privacy
> residual, because the refusal predicate is a function of the transcript
> challenges alone.
>
> Consequently the tool's per-role numbers — A 0, H 2, endpoints 0, mask
> channel 2 Fp — are not four measurements: they are the values of those
> quantities on every receipt the profile can emit.
>
> Item 3 additionally assumes what §3.3 now states as an explicit
> hypothesis: **every H plane's `log_size` lies on the same side of
> `LOG_N`**, so that the LogUp sum claim has a single column key and can be
> formed at all. True at both toy profiles, false at the development rung
> and at 125M until the lookup-summation repair (§3.3, §4 item 6).
>
> All four items are **per commitment**. Nothing here is a statement about
> the four commitments jointly; that is U-3(b) and it is not computed
> (§1.5, ruling G-1).
>
> **The lemma is conditional**, on the RELIES ON rows 5, 6, 7, 8, 13, 14,
> 15, 21, 22 and 23 of the label table in §3.8 — chiefly that
> `audit_claims` and `check_opening_challenges` are called on every path and
> test the challenge stream the PCS actually consumes; that the tool's
> reduction `disclosed = 256 k0 + u-term` is itself correct; that the four
> assertions of `zkp-core/src/pcs.rs:759, 768, 775, 786` and the `d + 1`
> published values per sumcheck round (`zkp-core/src/sumcheck.rs:148-150`)
> stand unweakened (ruling G-3); and that the non-data rows' messages are
> uniform (`private_block/protocol.rs:361, 364-372`). Those are facts about
> the code and about another document, established by reading, and a
> checker should treat each as an attack surface.

Scope note, stated once and not softened: the lemma is about the tool's
**linear model at a fixed layout** (§1), for the **two toy layouts only**
(ruling G-2). It does not say the receipt is private. §4 lists what it
leaves untouched.

### 3.2 Proof of the block-triangular identity (the group and endpoint blocks)

Let one commitment have opening groups `g = 1..G` with member claims, and
let every claim `j` carry a reserved pair `(r_j, r_j + 1)`.

**Step 1 (supports are disjoint and miss the proximity pair).** Every
reserved pair row is touched by exactly one claim with a non-zero
coefficient; each evaluation claim touches exactly one pair; only the sum
claim may be pairless and must then cover the zero-sum rows; nothing but the
proximity combination touches the proximity pair. **RELIES ON**
`private_block/protocol.rs::audit_claims:89-133` (proximity exclusion
`:100-102`, zero-coefficient refusal `:103-108`, one-adjacent-pair
`:118-122`, exclusivity `:129-131`), called on the prover path at `:396,399`
and on the verifier path at `:458,464`; identically
`private_attention/protocol.rs:84-133,384,387,443,449`. Independently
re-derived from the captures by `_check_pair_schedule`
(`zk60_native_jv_pcs.py:366-405`), which reports `reserved_pairs_used` equal
to the claim count on all sixteen role-captures.

**Step 2 (the pair coefficients are `(cm, cm U)`).** §2.2. **PROVED HERE**
from `build_claim:223-236` and `zpart_weights:752-792`; for the standalone
seam path, `private_seam.rs::terminal_claim:273-306` gives `(e, e U)`, the
same shape.

**Step 3 (the group vector at that pair).** `zk_rhos`
(`zkp-core/src/pcs.rs:835-856`) sets
`rho_g[i] = sum_j lambda_{g,j} rw_j[i]`. By Step 1 only claim `j` is
non-zero at `(r_j, r_j+1)`, so
`rho_g[r_j] = lambda_{g,j} cm_j` and `rho_g[r_j+1] = lambda_{g,j} cm_j U`.
**PROVED HERE.**

**Step 4 (each 2x2 block's determinant is a norm).** Write
`wedge(a,b) = a.c0 b.c1 - a.c1 b.c0` — the same function the code calls
`determinant` (`protocol.rs:135-137`) and the tool computes inline
(`zk60_native_jv_pcs.py:398,413`). With `Fp2 = Fp[U]/(U^2 - 7)`
(`zkp-core/src/field.rs:15,133-141,163`), for any `x` in Fp2

```
wedge(x, x U) = x.c0^2 - 7 x.c1^2 = Norm(x)      (field.rs:177)
```

and `wedge` is the Fp volume form, so multiplying both arguments by
`lambda` scales it by `det_Fp(multiplication by lambda) = Norm(lambda)`:

```
wedge(lambda cm, lambda cm U) = Norm(lambda) Norm(cm).
```

**PROVED HERE**, and checked on 20,000 random pairs each in
`results/zk60_generic_rank_lemma/pair_block_identity.py` (zero failures).
Since Fp2 is a field, `Norm(x) = 0` iff `x = 0`.

**Step 5 (the minor factorises).** Choose one member claim per group and
take the `2(G+1)` columns `{ (r_j, r_j+1) : the chosen j }` together with
the proximity pair. Order the generator rows as
`Re(rho_1), Im(rho_1), ..., Re(rho_G), Im(rho_G), Re(rho_prox),
Im(rho_prox)`. By Steps 1 and 3 the group rows vanish outside their own
chosen pair — including at the proximity pair — so the square submatrix is
block lower triangular with the proximity block last, and

```
det = ( prod_{g=1..G} Norm(lambda_{g,j(g)}) Norm(cm_{j(g)}) )
      *  wedge( rho_prox[prox], rho_prox[prox+1] ).
```

**PROVED HERE.** The **numerical confirmation of record is the independent
check's**, not this draft's: the check took the **real** claim schedules out
of the four captures (offsets, `log_size`, coefficients, points),
re-implemented `zpart_weights` from the Rust, re-derived the first-occurrence
grouping from `part_key` — obtaining the Rust `group_zclaims` grouping
element by element on all sixteen role-captures — and resampled the
challenge side: **48 fresh uniform challenge vectors** (3 per role-capture)
and **78 adversarial ones** (3 draws over 26 regime-role combinations:
lambdas in the base field, purely imaginary, all equal, all `= U`, `cm` in
the base field, `cm` with zero real part, `cm = U`, tiny integer pairs, and
the mixed regimes), with **zero mismatches**, no zero determinants, and
ranks `72 / 20 / 4 / 4` for the block and `62 / 18 / 4 / 4` for attention,
`k0 = 0` in every case (`results/zk60_generic_rank_lemma_check/`,
`check_pair_factorisation.py`, `check_adversarial_challenges.py`). No
adversarial value of `lambda` or `cm` short of zero kills the minor. This
draft's own `pair_block_identity.py` part (b) built a **synthetic**
commitment whose groupings it invented (member counts `[4]*25 + [2]*10` for
block A, which is not the real grouping) and is therefore **superseded** for
this purpose; its part (a) identity checks stand (§7).

**Step 6 (every factor is non-zero on a non-refused run).**

* `cm_j = e_r prod_{k>r} (1 - e_k)` is a product of factors each refused
  when zero: `argument.rs:347-349` refuses if any `e` is `0` or `1`
  ("degenerate terminal mask challenge; discard attempt"). Fp2 is a field,
  so `cm_j != 0`. (`audit_claims:103-108` refuses the same thing again, from
  the constructed claim, on both the prover and the verifier side.)
* `lambda_{g,j} != 0`: `check_opening_challenges:141-146` replays the PCS
  challenge prefix from a **cloned** transcript and refuses if any group
  member coefficient is zero. The replay order matches `zk_rhos` exactly
  (lambdas per group in first-occurrence order, then `rows` proximity
  draws), and the group order is rebuilt the same way at `:157-171`.
* `wedge(rho_prox[prox], rho_prox[prox+1]) != 0`:
  `check_opening_challenges:147-150` refuses otherwise; the endpoints use
  the same function with `rows = 7, prox = 4`
  (`check_endpoint_opening:191-203`).

**The verifier refuses too, before it verifies (check correction C-4).**
`verify_inner` calls `check_opening` at `private_block/protocol.rs:458` (A)
and `:464` (H) and `check_endpoint_opening` at `:471`, each *before* the
corresponding `pcs::verify_zk`; the attention path is the same
(`private_attention/protocol.rs:443, 449, …`). So a modified prover cannot
publish a receipt whose challenges the honest prover would have refused: a
receipt in the wild implies the refusal predicate held. The draft originally
cited only the prover side.

**The replay order (condition O-1).** The check re-derived the grouping
independently from `part_key` and found it equal, member list by member
list, to the Rust `group_zclaims` output recorded in all sixteen
role-captures, and read the chain `check_opening:155-175` ->
`clone_state:139-142` -> `open_zk:915-921` -> `zk_rhos:835-856` element by
element. That is the strongest evidence available short of Rust. **There is
still no Rust test pinning the draw order**: `tests.rs:295-315`
(`opening_refusals_are_functions_of_the_challenges_only`) injects a
hand-written draw iterator and never compares with `zk_rhos`, and the
attention twin (`private_attention/tests.rs:289`) is the same. Until such a
test exists, label 8 stays **RELIES ON** and §6 item 2 stays open.

**Restart semantics (condition O-5).** The lemma needs a refused attempt to
be discarded whole and re-run with **fresh pads, salts and masks**, so that
the accepted transcript is uniform on the non-refused set; a restart that
reused the pads would correlate the two worlds. That holds here: refusals
are never resampled on the same transcript (`argument.rs:272-273` states the
rule) and every randomness owner is created and dropped inside one
`prove_inner` (`protocol.rs:5-8`), so the attempts are i.i.d.

**RELIES ON** those three call sites, the verifier-side re-runs above, and
the restart semantics.

**Conclusion of §3.2.** On a non-refused run the chosen minor is non-zero,
so the non-data block has full row rank `g = 2(G+1)`, so `k0 = 0` (§1.3).
**PROVED HERE**, conditional on the RELIES ON items.

**Which refusals are necessary, measured on the real schedules (B-4, ruling
G-4).** The zero-mask-challenge refusal is **exactly necessary, not
conservative**. The independent check recomputed the negative controls on
the **real** block A and block H claim schedules: setting **one** `cm` to
zero (claim 0) already gives `k0 = 2`, i.e. 512 Fp disclosed, because group
0 is a **singleton** — and singleton groups are common at these shapes (A
has 35 groups over 120 claims, H has 9 over 52, and the LogUp sum claim's
group is a singleton on all four captures). So for every group with one
member the refusal on `cm != 0` is exactly what keeps the disclosed
dimension at zero. **Nobody weakens that refusal**: `argument.rs:347-349`
and `audit_claims:103-108` are load-bearing for privacy, not belt and
braces. The draft's earlier reading — that another member of the same group
would still carry it — is **withdrawn**: it is false at the real schedule.

Two of the other controls do read as the draft said, and the check
reproduced them: with every `lambda` of one group zero the group vector is
identically zero, `det = 0` but `k0` stays 0; with a dependent proximity
pair, `det = 0` and `k0` stays 0 at these shapes (and a base-field proximity
draw would refuse every honest run — a completeness matter, §5). "Two claims
share one reserved pair" gives `k0 = 16`, and that is exactly what
`audit_claims` forbids.

### 3.3 Proof for the u-row term of H

H's two zero-sum rows carry a public linear constraint, so `k0 = 0` is not
the whole answer: the tool additionally solves, for each u row, for the
generator combination whose non-data restriction is that row's indicator
(`_disclosed:436-481`). Claim: that solution exists, is unique, and its
data-row image spans exactly the public LogUp identity — on every
non-refused run.

**Enabling hypothesis, stated explicitly (B-1).** This whole subsection
assumes **every H plane's `log_size` lies on the same side of `LOG_N`**, so
that the LogUp sum claim's parts all carry one column-weight key and the
claim can be formed at all. That is true at both toy profiles and **false at
the development rung and at 125M** until the lookup-summation repair
(ruling P-3 of the layout disposition): there the H domains straddle the row
width at `LOG_N = 14` (`Tab` 8 and `L` 13 below; `Kv` 17, `D`/`Q` 19, `F`
20, `S` 22 at or above), `check_opening` returns **"claim parts with
different column weights"** and `pcs.rs:817` asserts below it
(`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §2.2 :494-503, §4.1 :1396-1429; the
rung reproduces the three keys `([],0,256)`, `([],0,512)`, `([],0,1024)`
deliberately, §9a :2003, :2026). After the repair — lift `Dom::L` and
`Dom::Tab` to `log = LOG_N`, zero extra rows — every H part is back to one
key and step 1 below is restored. Until then this subsection is about a
claim that **cannot be constructed** at those shapes; see §4 item 6.

1. **The sum claim is alone in its group.** Its column key is
   `(tail = [], c0 = 0, len = 256)` (`logup_sum_claim:52-62`, all parts have
   an empty point). Every evaluation claim's key has a non-empty tail,
   because `build_claim` passes a point of length `p.log >= 1`
   (`zpart_weights:772-792`). So `group_zclaims:809-831` puts the sum claim
   in a group of its own. **PROVED HERE**, under the enabling hypothesis
   above. The enumeration the draft left undone (§6 item 3) was completed by
   the independent check: the three `Priv` constructors are
   `argument.rs:423, 445, 449`, with `log` taken from `a_dom`/`h_dom`
   (minimum 5) or the literals 5 / 6 / 9, so `p.log >= 5 > 0` always at the
   toy; and the check confirmed on all four H captures that the sum claim's
   group is a singleton.
2. **The proximity coefficients must vanish.** No group vector touches the
   proximity pair (Step 1), and the proximity 2x2 block there has
   determinant `wedge(rho_prox[prox], rho_prox[prox+1]) != 0` on a
   non-refused run, so any combination equal to `e_u` must use the
   proximity generators with coefficient 0.
3. **Every other group's coefficients must vanish.** For group `g != g_sum`,
   pick any member `j`; the combination must vanish at `(r_j, r_j+1)`, where
   the only contribution is group `g`'s own, through a 2x2 block of
   determinant `Norm(lambda_{g,j} cm_j) != 0`. So both of group `g`'s
   coefficients are 0.
4. **The sum group's coefficients are determined.** The combination must
   equal `e_u` on `(u_0, u_1)`, where `rho_{g_sum}` is
   `(lambda_sum s, lambda_sum s U)` for the sum claim's coefficient `s` at
   the u pair. At this layout `s = 1` exactly: the `u` plane `H_U`
   (`layout.rs:239`) has `Dom::Tab`, `log = 8 = LOG_N`, so it occupies rows
   278 and 279 one each (`layout.rs:640-642`), and `logup_sum_claim:52-62`
   gives it `coef = ONE` and `coef = ONE * U`. The 2x2 block therefore has
   determinant `Norm(lambda_sum) != 0`, so the two remaining coefficients
   are unique. Hence the solution exists and is unique, for both u rows:
   the tool's `u_row_indicators_admissible = 2` is forced, not observed.
5. **The image is exactly the public identity.** The resulting `xi` is an
   Fp-combination of `Re(lambda_sum rw_sum)|data` and
   `Im(lambda_sum rw_sum)|data`. For any `v` in Fp2 and `lambda` in Fp2,
   `Re(lambda v) = lambda.c0 v.c0 + 7 lambda.c1 v.c1` and
   `Im(lambda v) = lambda.c0 v.c1 + lambda.c1 v.c0`, so
   `span_Fp{Re(lambda v), Im(lambda v)} subset span_Fp{v.c0, v.c1}`, with
   equality iff `Norm(lambda) != 0`. Therefore the two `xi` vectors span
   exactly `span_Fp{ Re(rw_sum)|data, Im(rw_sum)|data }`, which is what the
   tool compares against (`_disclosed:463-474`) — so
   `equals_public_logup_identity` is **true by construction** and the u-row
   term is **exactly 2**, not "2 as measured".

**PROVED HERE** (steps 1-5), conditional on the same three refusals and on
the enabling hypothesis above. This matters because it is the one place
where the tool reports a rank *equality* rather than a rank lower bound: an
equality cannot be obtained from a generic argument at all, and here it
comes out as an identity.

**A second claim does evaluate the u rows, harmlessly (correction C-2; this
closes §6 item 7).** No other *plane* lands on rows 278-279: `h_off` is
built by a strictly increasing cursor and `H_U = 50` is the last of
`N_H = 51`, with `h_dom(H_U) = Dom::Tab` and `log = 8`, hence exactly those
two rows (`layout.rs:239, 241-252, 576-583`). But a second *claim* does
evaluate that plane — `argument.rs:899` (`b.h(H_U)`) — and the check
recomputed `claims_evaluating_u = 2` on every H capture. It changes nothing:
that claim sits in a group with a non-empty key, and step 3 above forces
that group's coefficients to zero before the u-row equation is reached. The
check confirmed it at fresh challenges: the solved u-row combination uses
**only** generators `{16, 17}` on block H and `{14, 15}` on attention H,
i.e. the Re/Im pair of the sum claim's own singleton group. The tool already
documents this case (`zk60_native_jv_pcs.py:377-380`).

**Why the tool adds 2 and not `256 * 2` — the reduction step (condition
O-2).** `_disclosed` adds `u_dim` (2), not `256 * u_dim`, to `disclosed`
(`:459, 484`). That is a step of the *reduction*, not of the rank
computation, and the argument for it, supplied by the independent check
(its §3.3), is: the observer learns
`w = z_u + sum_{data i} xi[i] z_i`; the `u` row's message is uniform on the
hyperplane `sum_t msg_u[t] = 0` (`protocol.rs:364-372`), so only the
all-ones column direction escapes it — summing `w`'s 256 message entries
kills the `u` row and leaves one Fp value per u row, two in all. The two
functionals are then, by step 5,

```
phi_re = sum_{H planes p} sign_p * (sum of all entries of p's re rows)
phi_im = sum_{H planes p} sign_p * (sum of all entries of p's im rows)
```

with `sign_p = -1` exactly for `H_GU8, H_GEXP, H_GACT`
(`protocol.rs:52-62`, `h_is_table:255-257`) — the real and imaginary parts
of the **value-0 LogUp identity**, whose declared value is `Fp2::ZERO`
(`protocol.rs:62`). They are a function of the statement alone, i.e.
**public**, and the check verified span equality at fresh challenges
(`rank(xi) = rank(logup) = rank(xi + logup) = 2` in 12 trials). **RELIES
ON** the reduction (§3.8 row 14), for which the check's derivation now
stands in place of the tool's docstring.

### 3.4 Proof for the pad block (every column set, no union bound)

Proved in §2.3, with exhaustive finite arithmetic in
`results/zk60_generic_rank_lemma/pad_block_structure.py`. Restated for the
label table: **H-pad holds for every admissible set of opened columns**, for
A, H, both endpoints and M; `d <= Q = 256` holds because only 256 indices
are drawn; the nodes are distinct because the index map is injective; the
scalars `Z_n(x_j)` and `z_j` are non-zero at *every* point of the encoded
domain. **PROVED HERE.** No challenge enters and no union bound is owed.

The tool re-verifies the same thing per capture, both at the observed
distinct count and at the collision-free boundary `q_pad = 256`
(`stage2.pad_block_at_the_full_budget`, `zk60_native_joint_view.py:140-151`;
the record shows exact rank 256 of 256 there).

**The pad budget, as the independent check established it (condition O-3).**
Stated once, because it is the whole of the column story and it has no
slack:

* the opened columns are sampled **with replacement**, so the captures show
  241 to 246 distinct indices out of 256 (block A 246, H 242, Input 246,
  Output 241; slack 10 / 14 / 10 / 15 against `q_pad = 256`);
* **the pad block's rank equals the number of distinct columns**, every
  time — recomputed on the real captured index sets, at the collision-free
  boundary (256 of 256), with the negative controls: one repeated index
  drops the rank to 255, and **257** distinct positions against 256 pads
  give rank 256, i.e. one more distinct opened position would break H-pad;
* the group and proximity vectors are published in full, but their **pad
  halves are determined by the opened columns** and the vectors' message
  halves: `F^pad (sum_i rho_g[i] pad_i) = sum_i rho_g[i] c_i - F^msg (sum_i
  rho_g[i] msg_i)`. So revealing them consumes no further pad entropy and
  **nothing is counted twice**;
* consequently **256 pads suffice jointly, per commitment, against
  everything revealed about that commitment — with zero slack**:
  `q_pad == num_col_checks == 256` exactly, and `commit_zk_owned_with`
  (`pcs.rs:670`) only asserts `q_pad >= num_col_checks`;
* therefore, as a standing condition: **the pad count and Q must move
  together, always.** Any profile that raises `num_col_checks` without
  raising `q_pad` in lockstep breaks H-pad at the first collision-free
  draw.

### 3.5 Proof for the mask channel M

**(a) `uncovered_s = 0` for every slot and every `rho`.** The CFS mask is
`g(x_1..x_N) = a_0 + a' prod_j x_j + sum_j u_j(x_j)`,
`u_j(X) = sum_{e=1..d} a_{j,e} X^e`, i.e. `L = N d + 2` coefficients
(`zkp-core/src/sumcheck.rs:189-218`). Its round-`j` message is

```
s_j(X) = 2^{N-1-j} ( a_0 + sum_{i<j} u_i(rho_i) + sum_{i>j} u_i(1)/2 + u_j(X) )
         + a' (prod_{i<j} rho_i) X                       (sumcheck.rs:255-274)
```

A coefficient direction in `ker R` must make each `s_j` vanish at
`X = 0..d`; `s_j` has degree at most `d` in `X` and `0..d` are `d+1`
distinct points of Fp, so it must vanish identically. **That premise is the
protocol publishing `d + 1` values per round, which is enforced at
`zkp-core/src/sumcheck.rs:148-150`
(`if s.len() != degree + 1 { return Err(...) }`) and nowhere else** (B-3 /
C-5). It is load-bearing: the check's negative control publishes only `d`
values per round and `dim ker R` rises to **2 at slots 8 and 17**. Per
ruling G-3 this is recorded as an **invariant that must not be weakened: a
change to it is a privacy change** (§3.8 row 22). The `X^e` terms for
`e >= 2` give `a_{j,e} = 0`; the `X^1` term gives
`a_{j,1} = - a' (prod_{i<j} rho_i) / 2^{N-1-j}`; the constant terms give `N`
equations `E_j`, and substituting the previous line makes
`E_{j+1} - E_j = a_{j,1} rho_j - a_{j+1,1}/2 = 0` **identically**, so only
`E_0` survives and it determines `a_0` from `a'`. Hence
`dim ker R = 1` for every `rho`, so
`rank R = L - 1 = N d + 1 = dim C`, so `uncovered_s = 0` **identically**.
**PROVED HERE**; checked at the actual `(N_s, d_s)` of all 23 + 18 slots and
at five `rho` regimes including all-zero, all-one, all-equal and base-field
`rho` — zero failures
(`results/zk60_generic_rank_lemma/cfs_round_rank.py`).

**(b) every published functional lies in `rowspace(R_s)`, for every `rho`.**
The two families are `CfsMask::sum_weights` (`:222-227`) and
`CfsMask::eval_weights` (`:230-243`). `sum_weights` computes
`sum_x g(x) = s_0(0) + s_0(1)`, a combination of round 0's published values;
`eval_weights` computes `g(rho) = s_{N-1}(rho_{N-1})`, the Lagrange
combination of round `N-1`'s `d+1` published values. Both are therefore in
the row span identically. **PROVED HERE**; checked as above, with a negative
control (drop the last round: `eval_weights` leaves the span, `sum_weights`
does not, exactly as predicted).

**(c) the M opening.** `M-q`, `M-prox` and `M-cols`
(`zk60_native_jv_cfs.py:515-562`) are source facts about
`hashline/src/zk.rs::mask_commit`'s `b` and `u` rows and about the pad
budget. `M-cols` is §3.4. `M-q` and `M-prox` are **RELIES ON** —
uniformity of `b` on `2*512` coefficients subject to `b[m] = -b[0]`, and of
`u` with coefficient 1 — asserted from `hashline/src/zk.rs:452-457` (the two
`b` rows with their pinned wrap-around entry, and the two `u` rows) by the
tool's author and re-checked per capture (`q_public_sum_identity`), not
re-derived here.

**One defect in the tool, not in the lemma (condition O-4).**
`m_pad_block_rank` (`zk60_native_jv_cfs.py:564-586`) builds the Cauchy block
at message positions `t in range(MASK_Q)`, i.e. `[0, 256)`, with the comment
"any 256 consecutive message positions" — but the real pads sit at
`[L, L + 256)` with `L = N d + 2` varying per row
(`hashline/src/zk.rs:373-375, 430-467`). The mathematics is unaffected,
because a Cauchy matrix on distinct nodes is totally non-singular and the
check confirmed rank 256 of 256 at **both** ranges; but the tool is checking
a matrix the protocol does not use, and should be pointed at the positions
the protocol uses.

Therefore the mask channel's disclosed dimension on the opening-only
accounting is `0 + 1` Fp2 `= 2` Fp on every non-refused run, with `c_s != 0`
supplied by `argument.rs:274-277`.

### 3.6 Which reading is right: is the prover's refusal the good event?

The brief asks which of two readings holds, because it changes what the
lemma is for. The answer here is the **second** reading, and it is stronger
than the first:

* the bad set (the good event fails) is **contained in** the refusal set;
* therefore `Pr[bad and not refused] = 0`, exactly, and the tool's numbers
  hold on every non-refused run by construction;
* the lemma's only probabilistic content is `Pr[refused]`, which is a
  liveness figure.

The containment is not an accident of the code: `audit_claims` was written
for this purpose and says so in its own comment — "the map from (one pair
per group, the proximity pair) to (group vectors, proximity vector) is block
triangular with invertible diagonal, so the opened vectors are jointly
uniform whatever the data is" (`private_block/protocol.rs:83-86`). What that
comment lacked, and what §3.2-§3.3 supply, is (i) the explicit factorisation
of the determinant, (ii) the identification of the diagonal factors with the
quantities the refusals test, (iii) the proof that the eq-tensors never
reach the non-data block, and (iv) the u-row case, which the comment does
not address at all. The same comment also names the premise it does not
discharge — independence from the sampled columns, the salted paths and the
CFS channel — which is §3.4 (columns, now proved), §3.5 (CFS, now proved)
and U-3(b) plus the hash layer (still open).

**Is the refusal channel itself a leak?** The refusal predicate is a
function of the transcript challenges only; in the random-oracle model the
challenge law is the same for every witness, so the refusal probability is
witness-independent and the refusal channel carries no information about the
witness. **RELIES ON** the ROM assumption and on the project's own finding
that no refusal on this path is witness-dependent except the zero LogUp
denominator at `2^-112.0`
(`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` §6, ruling C-2). That finding is not
re-derived here, and a checker should treat it as an input.

**The whole "probability 1 on non-refused runs" framing is a statement
inside the random-oracle model (correction C-11).** For a fixed (witness,
randomness) pair the refusal event is deterministic, and the challenges are
BLAKE3 images of a prefix containing the Merkle roots, which are functions
of the witness and of the pads and salts. What makes conditioning on
non-refusal free is only that in the ROM each fresh prefix's challenge is
uniform and independent of the prefix, so the refusal *law* — and the
conditional law of the challenges given "not refused" — is the same for
every witness. This is more than bookkeeping: it is the only reason the two
worlds stay equidistributed under conditioning (the earlier check's C-12
ruled the same point and this draft did not carry it).

Two supports the check added, and they close §6 item 4: the number of
openings and the row counts are witness-independent — `A_ROWS`, `H_ROWS`,
`ENDPOINT_ROWS`, `A_GROUPS`, `H_GROUPS` are compile-time constants asserted
by `Layout::new` (`layout.rs:588-591`), and the verifier refuses a different
group count (`protocol.rs:169-171`); and a refused attempt restarts with
fresh pads, salts and masks, so the accepted transcript is uniform on the
non-refused set (§3.2 step 6, condition O-5).

### 3.7 The Schwartz–Zippel backstop, if a structural step is rejected

If a checker breaks §3.2 (say by finding a claim whose pair coefficients are
not `(cm, cm U)`, or a path where `audit_claims` is not called), the fallback
is the argument the check of 2026-09-19 sketched: one capture at full rank
exhibits a point at which some maximal minor of the non-data block is
non-zero, so that minor is not the zero polynomial, and Schwartz–Zippel
bounds the bad set.

That argument is sound in outline, and this draft keeps it, with three
changes:

1. **Which minor.** The tool does not currently output one. It reports
   `rank_P1_on_non_data_rows` only. To certify the fallback, the tool would
   need to emit, per role, the **row and column selection of one non-zero
   maximal minor** and its value — concretely: after computing
   `rank(gens | other_rows)`, record the pivot columns of the row reduction
   (the `other_rows` indices) together with the full generator index list,
   and the determinant of that square submatrix. That is a few lines inside
   `_disclosed` and a new field `certifying_minor: {generators, rows,
   determinant}`; **this draft does not modify the tool**, as instructed.
   Without it a reader cannot re-verify which minor the capture certifies,
   only that *some* minor is non-zero — which is in fact enough for the
   mathematics, but not enough for an auditor to reproduce. Two updates:
   the check showed the minor can be named **a priori** from the layout
   (one member claim per group plus the proximity pair), which is cheaper
   than extracting pivots; and the tool fix now in progress under ruling
   G-1 prints the certifying minor per role.
2. **Which field.** Over `Fp`, not `Fp2` (§2.2, correction 2).
3. **Which size.** `2(G+1)` square, not `(G+1)` as the earlier wording of
   correction 1 put it; the sketch itself said `G x G` with `G` counting
   groups plus the proximity vector (§2.2, correction 1, as corrected).

With entry degrees `3` (group rows) and `1` (proximity rows) the bound is
`(6G+2)/p` per role, union `2^-55.85` for the block and `2^-56.05` for
attention (`results/zk60_generic_rank_lemma/bounds.py`). The mask channel's
backstop is genuinely over Fp2 — `R_s` is an Fp2 matrix in Fp2 variables
with no conjugation — and lands at `2^-115.7` / `2^-116.0`, so the PCS side
dominates.

This is the draft's substantive disagreement with the earlier check's §4 and
with ruling C-5's summary, and the independent check of 2026-09-20 upheld
the arithmetic and the field question while trimming the rhetoric
(correction C-7). Stated as the check requires: `2^-55.85` is a **generic
bound**, produced by applying Schwartz–Zippel to a polynomial we already
know is a product of norm forms, not an estimate of the probability, which
is far smaller. So the honest reading is that **the generic tool is weak
here** — weak enough that, if it were all we had, the fallback term would be
the largest on the page — and that is one more reason to argue structurally.
It is not a statement that the project has a problem. §3.2-§3.5 should still
be attacked harder than the backstop's arithmetic.

### 3.8 Label table: proved here / relies on / gap

| # | Statement | Label |
|---|---|---|
| 1 | full row rank of the non-data block implies `k0 = 0` | PROVED HERE (§1.3) |
| 2 | the eq-tensors never reach the non-data rows; pair weights are `(cm, cm U)` | PROVED HERE (§2.2) from `build_claim:223-236`, `zpart_weights:752-792`, **GIVEN row 21** (the four asserts that make `part_rows` exact) |
| 3 | `wedge(x, xU) = Norm(x)`; `wedge(lam a, lam b) = Norm(lam) wedge(a,b)` | PROVED HERE (§3.2 step 4) |
| 4 | the maximal minor factorises as `prod Norm(lam cm) * wedge(prox pair)` | PROVED HERE (§3.2 step 5); numerical confirmation of record is the check's, on the real claim schedules (48 uniform + 78 adversarial challenge vectors, zero mismatches) |
| 5 | claim supports on non-data rows are disjoint, one pair each, prox untouched | RELIES ON `private_block/protocol.rs::audit_claims:89-133`, called at `:396,399,458,464` |
| 6 | `cm != 0` on a non-refused run | RELIES ON `private_block/argument.rs:347-349` (and `protocol.rs:103-108`) |
| 7 | `lambda != 0` and the proximity pair independent on a non-refused run | RELIES ON `private_block/protocol.rs:141-152`, called via `check_opening:155-175`, `check_endpoint_opening:191-203` |
| 8 | the refusal replay draws the same challenges the PCS will draw | RELIES ON `protocol.rs:157-174` vs `zkp-core/src/pcs.rs:835-856`; the *grouping* is machine-checked (the check's independent `part_key` grouping equals the Rust `group_zclaims` on 16 role-captures), the *draw order* is checked by reading only and **a Rust test is owed** (condition O-1) |
| 9 | the u-row solution exists, is unique, and spans the public LogUp identity; the two functionals are the public value-0 LogUp identity | PROVED HERE (§3.3), **conditional on** every H plane's `log_size` lying on the same side of `LOG_N` (B-1; false at the rung and 125M until the P-3 repair) |
| 10 | H-pad / M-cols for **every** column set | PROVED HERE (§2.3, §3.4) with exhaustive finite arithmetic, **conditional on `q_pad == num_col_checks == 256`** — zero slack, the pad count and Q must move together (condition O-3) |
| 11 | `uncovered_s = 0` identically | PROVED HERE (§3.5a), **GIVEN row 22** (`d + 1` published values per round) |
| 12 | every published mask functional lies in the round span, identically | PROVED HERE (§3.5b) |
| 13 | `M-q` and `M-prox` (the `b` and `u` rows mask `q` and the proximity vector) | RELIES ON `hashline/src/zk.rs:452-457` via `zk60_native_jv_cfs.py:515-562`; not re-derived here |
| 14 | the tool's reduction `disclosed = 256 k0 + u-term` itself, including that the u-term enters as `u_dim` and not `256 * u_dim` | RELIES ON `zk60_native_jv_pcs.py:38-63` and its brute-force cross-check `zk60_native_jv_smallmodel.py`; this lemma proves the hypotheses, not the reduction. The check re-derived the reduction on paper under H-pad (`ZK60_GENERIC_RANK_LEMMA_CHECK.md` §3.3, §4.4) and that derivation, recorded in §3.3, now stands in place of the tool's docstring (condition O-2) |
| 15 | refusals carry no witness information | RELIES ON the ROM assumption and `ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` §6 / ruling C-2 |
| 16 | the tool can name the minor a capture certifies | **GAP** — the tool reports ranks only; §3.7 specifies the addition, the minor can be named a priori from the layout, and the G-1 fix in progress prints it per role |
| 17 | `joint = sum of the parts` | **GAP** — **not computed**: `zk60_native_joint_view.py:245` hard-codes `joint_equals_sum_of_parts: True` and `:248` hard-codes stage 4's `"ok": True`, so the stage cannot fail (C-12); fix in progress 2026-09-20 (ruling G-1). This is U-3(b), and nothing in this lemma's per-commitment results depends on it |
| 18 | anything non-linear in the joint view (the terminal identity links the channels at degree up to 4) | **GAP** — out of scope, named at `zk60_native_jv_cfs.py:57-62` |
| 19 | the hash layer: roots, salts, authentication paths | **GAP** — out of scope, named at `zk60_native_joint_view.py:302-308` |
| 20 | the 125M profile and the development rung | **GAP** — §4 item 6; owed again from the start, not re-checked (ruling G-2) |
| 21 | the four assertions that make `part_rows` exact | RELIES ON `zkp-core/src/pcs.rs:759, 768, 775, 786` — **an invariant that must not be weakened; a change to it is a privacy change** (ruling G-3, B-2). A straddle panics in the PCS rather than spilling silently |
| 22 | the protocol publishes `d + 1` values per sumcheck round | RELIES ON `zkp-core/src/sumcheck.rs:148-150` — **an invariant that must not be weakened; a change to it is a privacy change** (ruling G-3, B-3). Negative control: with only `d` values the kernel has dimension 2 at slots 8 and 17 |
| 23 | the non-data rows' messages are uniform (mask and proximity rows; the `u` rows uniform on a hyperplane) | RELIES ON `private_block/protocol.rs:361` and `:364-372`, and `hashline/src/private_seam.rs` for the endpoints (condition O-6); the whole argument is vacuous without it |

### 3.9 What this lets the privacy case say (ruling G-5)

Exactly this much, and no more. With the errata of this revision applied,
the privacy case's **seven** steps that are today labelled "computed on
captures" and concern the **linear channels** may be re-labelled
**PROVED-CONDITIONAL on this lemma, for the two toy layouts**. The
conditions are:

1. the invariants of ruling G-3 — the four assertions
   `zkp-core/src/pcs.rs:759, 768, 775, 786` and the `d + 1` published values
   per sumcheck round, `zkp-core/src/sumcheck.rs:148-150` (§3.8 rows 21 and
   22) — unweakened;
2. the refusal replay order, which matches by reading and by the check's
   grouping evidence, but for which **a Rust test is owed** (condition O-1,
   §3.8 row 8);
3. the random-oracle reading of "refusals are independent of the hidden
   data" (§3.6, correction C-11, §3.8 row 15).

The **joint** statement is not re-labelled: it stays **not computed** (§1.5,
§3.8 row 17, ruling G-1). Nothing here re-labels the hash layer, the
non-linear channel, the composition U-3(b), or any shape other than the two
toy layouts, and nothing here is a privacy acceptance.

## 4. What the lemma does NOT give

Listed so that no later document can quote this one for more than it says.

1. **It is not a privacy property, and not a privacy acceptance.** It is a
   statement about the rank of an explicitly stated linear model. The tool
   says the same of itself at `zk60_native_joint_view.py:31-34`.
2. **The hash layer is untouched.** The three Merkle roots, the 256 leaf
   salts served per opening, the 11- and 12-level authentication paths and
   the receipt's byte encoding and length are not linear objects and no
   rank covers them (`zk60_native_joint_view.py:302-308`). The
   caller-fixed endpoint-root obligation (D8/D11) is likewise untouched.
3. **U-3(b), the composition, is untouched.** `joint = sum of the parts` is
   asserted, not computed: the tool hard-codes it at
   `scripts/zk60_native_joint_view.py:245` and hard-codes stage 4's own
   pass flag `"ok": True` at `:248` (branch `zk60-native-jointview`), so
   the stage cannot fail, and any document quoting "the joint view
   discloses 4 Fp" is quoting four marginals plus an unproved composition
   assumption (correction C-12, ruling G-1). A fix is in progress
   (2026-09-20). This lemma proves per-channel facts, does not depend on
   the joint statement, and says nothing about the joint law. That is the
   harder half of U-3 and it remains open.
4. **The non-linear channel is untouched.** The terminal identity
   `fin_s - c_s g_s(rho) = poly_s(terminals)` links the commitment channel
   to the mask channel with `poly_s` of degree up to 4; a linear model
   cannot see it (`zk60_native_jv_cfs.py:56-62`). Nothing here rules out a
   non-linear functional of the joint view.
5. **The sampler bias is untouched.** The lemma's probabilities are for
   ideal uniform challenges; the reduction residual is D9's, already
   accepted, and §5 prints the part of it that attaches to the draws this
   lemma uses.
6. **Other shapes are untouched — the certificate is owed again from the
   start (B-1, ruling G-2).** The lemma holds for the two toy layouts. At
   the development rung and at the 125M shape the word is **re-prove**, not
   "re-check": the H step of §3.3 is about a claim that **cannot be formed
   at all** until the lookup-summation repair (ruling P-3 of the layout
   disposition), because the sum claim's parts sit under three different
   column-weight keys, `check_opening` returns "claim parts with different
   column weights" and `pcs.rs:817` asserts below it
   (`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §2.2 :494-503, §4.1 :1396-1429;
   the rung reproduces the keys `([],0,256)`, `([],0,512)`, `([],0,1024)`
   deliberately, §9a :2003, :2026). After the repair the whole certificate
   is owed from the start, and at minimum:
   (i) one capture at full rank at the new shape, i.e.
   `rank(gens | non-data) = 2(G+1)` per role;
   (ii) the structural steps **re-proved**, in particular that every claim's
   reserved pair still carries `(cm, cm U)` and that `audit_claims` still
   enforces exclusivity once relations are gated by `supp` on padding — the
   layout memo asserts that audit is "shape-general already" (§5 :1505)
   rather than re-examining it;
   (iii) the pad-block arithmetic of §2.3 recomputed at the new `n`, `nn`
   and coset, and at the rung at **two** `(n, nn)` pairs, because `n ∤ tdb`
   forces a per-commitment `log_n` (§9a :2004) and `inv_rate` drops to 4
   with `n = 1024`, `nn = 4096`;
   (iv) the group count: **`A_GROUPS` moves 35 → 36** at 125M *and* at the
   rung (the nine `Dom::L` sub-slices sit at nine distinct `c0 = 512k`,
   where the toy's `32k mod 256` wraps at `k = 8` and gives eight), so
   `g = 2(G+1)` goes 72 → 74 and the backstop degree `6G+2` goes 212 → 218
   for A; H stays 9 / 20 / 56, and no slot gains a third extension round;
   (v) the endpoints, re-tiled: `ENDPOINT_ROWS` 7 → **29** and
   `ENDPOINT_PROX` 4 → **26** at 125M (9 / 14 at the rung), the endpoint
   plane is **three** `d`-blocks not one and each endpoint claim gains
   **three data parts** instead of one (§6 :1522-1581), which is exactly
   what `check_endpoint_opening`'s three hard-coded `part_rows` equalities
   (`protocol.rs:194-196`) pin. The memo intends the non-data coefficients
   to stay `(e, e·U)` on one reserved pair (§6 :1587) — a design intention
   in another document, not a verified fact;
   (vi) a **new refusal** the inventory here does not have: each padded
   domain's term carries one fresh challenge `ζ` refused on zero plus one
   more `mu` entry (§3.7a :1077-1085). It adds no rows, planes or claim
   sites, so the pair structure is untouched, but the refusal list of §3.2
   step 6 and the probability table of §5 both grow.
   Nothing in this lemma transfers by itself.
7. **It does not say the prover's refusals are complete.** Other refusals
   exist on this path (zero LogUp denominators, `nu = 0`, entropy failure,
   panics); the lemma names only the three that bear on the rank and takes
   the rest from the check's inventory.

## 5. The bound in bits

All arithmetic exact, in `results/zk60_generic_rank_lemma/bounds.py`;
output in `bounds.txt`.

**(A) Probability the good event fails on a non-refused run: 0.** The bad
set is contained in the refusal set (§3.2 step 6, §3.6). This is the
lemma's headline and it is not a bound.

**(B) Probability the prover refuses** (liveness, not privacy):

| term | block | attention |
|---|---:|---:|
| a terminal-mask `e` in `{0,1}` (50 / 40 ways) | `2^-122.36` | `2^-122.68` |
| a PCS batching `lambda = 0` (174 / 113 draws) | `2^-120.56` | `2^-121.18` |
| a CFS multiplier `c = 0` (23 / 18 draws) | `2^-123.48` | `2^-123.83` |
| a proximity pair Fp-dependent (4 openings) | **`2^-62.000`** | **`2^-62.000`** |
| **total** | **`2^-62.000`** | **`2^-62.000`** |

The proximity term dominates by 58 bits. Exactly, for `a, b` uniform in
Fp2, `Pr[wedge(a,b) = 0] = (p^2 + (p^2-1)p)/p^4 = 2^-64.0000`, and there are
four openings per proof. About one proof in `4.6 * 10^18` is discarded and
re-run. **This is not a privacy residual**: the predicate is a function of
the challenges alone (§3.6).

A note for ruling C-1, which asks the errata pass to find "the larger
residual of about `2^-62` that D9's own text records". **State the category
first (correction C-10): the `2^-62.000` here is a completeness/liveness
probability — the chance of discarding a run, `4/p` over four openings —
while D9's `2^-62` is described as a privacy residual in the
indistinguishability bound. They are different kinds of quantity, and
identifying them on the strength of the digits alone would be a category
error.** The number here is `2^-62.000` and it is the proximity-pair
refusal. Whether it is the same item as the one D9 records is **not
established here** — I did not read `ZK60_FABLE_TRANSCRIPT_REVIEW.md` §B.7
— and on the categories it is probably not; the errata pass should still
look, before carrying two terms of the same size.

**(B') the sampler's residual on the draws this lemma uses**, at the case's
`2^-96` per draw: 1,075 draws for the block, `2^-85.93`; 761 for attention,
`2^-86.43`. Inside D9's accepted residual, listed here only so that the
lemma's own inputs are priced.

**(C) the Schwartz–Zippel backstop**, if §3.2 is rejected:

| | block | attention |
|---|---:|---:|
| PCS side, over Fp, realified minors (degree `6G+2`) | `2^-55.85` | `2^-56.05` |
| with a x100 slack on every degree | `2^-49.21` | `2^-49.40` |
| mask channel, over Fp2 (degree `(Nd+1) max(d,N)`) | `2^-115.68` | `2^-115.98` |
| **total backstop** | **`2^-55.85`** | **`2^-56.05`** |

Compare the terms already on the page: the `fp()` sampler bias `2^-77.7` —
which is the **privacy case's** recount for one toy block proof, not D9's
own figure; D9 records `2^-96` per draw and `2^-75` at the toy shape
(`ZK60_DECISIONS.md:371-409`), correction C-9 — and the LogUp collision
`2^-112.0`. Taken at face value the backstop would be the **largest** term,
by 22 bits; but it is a generic bound on a polynomial known to be a product
of norm forms, not an estimate of the probability (correction C-7), so what
it shows is that the generic tool is weak here. The sketch in the check of
2026-09-19 reported `2^-120.8` for the same quantity (withdrawn); the
difference is the two corrections of §2.2 (minor twice as wide: 8 bits at
A's shape; the field 64 bits) plus the degree bookkeeping. The independent
check reproduced both arithmetics exactly — the draft's `2^-55.85` /
`2^-56.05` and the sketch's `2^-120.77` / `2^-120.96` — and ruled that the
disagreement is entirely about which event, in which ring, with the draft
right on both counts.

**Sensitivity — what if a draw I placed in Fp2 is really in Fp?**

* A `lambda` or a terminal-mask `e` in the base field: `Norm(x) = x^2`, so
  its vanishing probability rises from `2^-128` to `2^-64` per draw. Over
  the 224 (block) / 153 (attention) such draws those terms move from
  `2^-120.19` / `2^-120.74` to `2^-56.19` / `2^-56.74`, which **overtakes**
  the proximity term and makes the total refusal probability about
  `2^-56.2` — roughly one discarded proof in `8 * 10^16`. Still a liveness
  figure, and the lemma's conclusion (A) is unaffected, because (A) does
  not depend on the size of the refusal set, only on the bad set being
  inside it. I checked the draw sites and they are all `challenge_fp2`
  (`transcript.rs:103-116`), so this is a sensitivity line, not a finding.
* The proximity draw in the base field would be fatal to **completeness**,
  not to the bound: `wedge(a,b) = a.c0 b.c1 - a.c1 b.c0` vanishes
  identically when both imaginary parts are zero, so
  `check_opening_challenges` would refuse every run. The
  `challenge_fp2_vec` at `zkp-core/src/pcs.rs:853` is load-bearing.
* The backstop (C) is already taken over Fp and does not move. If a checker
  argued the realified minor may be treated over Fp2 after all, (C) would
  improve by 64 bits to about `2^-119.85` / `2^-120.05` — close to the
  earlier sketch. **This draft does not claim that**, and the independent
  check closed the question against it: its two-row counterexample shows
  full Fp2 rank on the non-data rows does not imply `k0 = 0`, so an
  Fp2-sized bound bounds a different event and no device recovers `D/p^2`
  without handling the conjugates (correction C-8).

## 6. Open questions for the checker, and how the check answered them

Most doubtful first. Each item now carries the disposition from
`ZK60_GENERIC_RANK_LEMMA_CHECK.md` (2026-09-20); only items 2, 8 and 9
remain open.

1. **Is the bad set really inside the refusal set — or is there a fifth
   diagonal factor I have not found?** The factorisation of §3.2 step 5
   assumes the chosen columns are the reserved pairs and the proximity
   pair, and that group vectors vanish elsewhere among them. If some claim
   in either profile reaches a non-data row outside its pair — through a
   data part whose slice happens to span a mask row — the block structure
   fails. `audit_claims` is supposed to forbid exactly that, and the tool
   confirms it on four captures, but I verified the Rust by reading, not by
   running it against an adversarial layout. **Attack `part_rows`
   (`protocol.rs:74-77`) and the `div_ceil` rounding first.**
   **ANSWERED (check §2a):** no claim's weights reach a non-data row
   outside its own pair — checked part by part on all sixteen role-captures
   — and `part_rows` is exact **because of** the four assertions
   `pcs.rs:759, 768, 775, 786` (§2.2, §3.8 row 21); a straddle would panic,
   not spill. No straddle is constructible at either toy layout.
2. **Is `check_opening_challenges`'s replay really the same challenge
   stream the PCS consumes?** It clones the transcript prefix and redraws
   (`protocol.rs:173-174`); `zk_rhos` draws `members.len()` per group in
   `group_zclaims` first-occurrence order, then `rows` proximity values
   (`pcs.rs:839,853`). The two orderings are rebuilt independently, in
   different files. If they ever diverge — a group ordering change, an
   endpoint with a different row count — the refusal tests the wrong
   numbers and item 7 of the label table falls, taking §3.2 step 6 with it.
   A Rust test that asserts the replayed vector equals the PCS's own would
   close this; there is none that I found.
   **STILL OPEN (condition O-1):** the check matched the grouping element
   by element on sixteen role-captures and read the draw chain, but the
   byte stream is still pinned by nothing; the Rust test is owed.
3. **Could a claim's column key collide with the LogUp sum claim's key?**
   §3.3 step 1 needs "no evaluation claim has key `([], 0, 256)`". I argued
   it from the point being non-empty. The residual case is `p.log = 0`,
   which would give an empty tail — but then the key's `len` is `1`, not
   `256`, so there is still no collision (`zpart_weights:765-771`). I did
   **not** enumerate every `Priv` construction to confirm `p.log >= 1`, and
   a slice of exactly one row (`p.log = LOG_N`) takes the other branch with
   an 8-coordinate tail. The claim survives either way, but a checker
   should confirm the enumeration rather than the argument.
   **ANSWERED (check §7):** the enumeration is done — the three `Priv`
   constructors are `argument.rs:423, 445, 449` with `log >= 5` always — so
   the item is **closed at the toy**; it **fails at the rung and at 125M**,
   which is B-1 (§3.3, §4 item 6).
4. **Is the `2^-62` refusal really witness-independent?** §3.6 rests on the
   ROM and on the check's refusal inventory. If the number of openings or
   the row counts could depend on the witness, the refusal probability
   would too. They are layout constants here, but the argument is one
   sentence and deserves a second reading.
   **ANSWERED (check §6):** closed by citation — `A_ROWS`, `H_ROWS`,
   `ENDPOINT_ROWS`, `A_GROUPS`, `H_GROUPS` are compile-time constants
   asserted by `Layout::new` (`layout.rs:588-591`) and the verifier refuses
   a different group count (`protocol.rs:169-171`) — with the ROM caveat of
   correction C-11 (§3.6).
5. **Is the Fp-vs-Fp2 correction of §2.2 right?** It is the difference
   between the withdrawn `2^-121` sketch and a `2^-56` fallback, and it
   turns ruling C-5's summary around. The claim is that
   `Re(x) = (x + x^p)/2` is not a polynomial in `x` over Fp2 of bounded
   degree, so the realified minor is an Fp-polynomial in the Fp coordinates
   and Schwartz–Zippel gives `D/p`. If there is a standard device that
   recovers `D/p^2` here (a resultant over the Frobenius twist, say), it
   should be named — the project would rather have it than not.
   **ANSWERED (check §5, correction C-8):** the correction is right and
   there is no such device without handling the conjugates; the two-row
   counterexample `rho = [1, u]` has full Fp2 rank on the non-data rows
   with `k0 = 1`. Separately, D15's soundness figure is a function of the
   opened column count and rate, not of the field size, so nothing quoted
   there moves.
6. **Is `dim ker R = 1` right at `d = 2`?** §3.5a divides the argument by
   the degree-`>= 2` coefficients of `u_j`; at `d = 2` there is exactly one
   such coefficient per round and the telescoping still works numerically,
   but the algebra is thinner there than at `d = 4`. **Twelve** of the
   block's 23 slots have `d = 2` — slots 5-13 and 20-22, recounted from
   `SLOTS` (`layout.rs:438-462`); the draft said eleven (correction C-6).
   **ANSWERED (check §3.1):** `dim ker R = 1` in all 115 recomputed cases,
   including every `d = 2` slot and the smallest slot (`N = 5`, `d = 2`,
   `L = 12`) — given the `d + 1` published values per round (§3.8 row 22).
7. **The sum claim's own pair coefficients.** Resolved while drafting, and
   recorded here so the checker can disagree: the `u` plane is
   `H_U = 50` (`layout.rs:239`), whose domain is `Dom::Tab` with
   `log = 8 = LOG_N` (`layout.rs:242-252,97-103`), i.e. one row for `re`
   and one for `im`, at `h_u_rows() = [h_off[H_U].0 / N, .1 / N] =
   [278, 279]` (`:640-642`). `logup_sum_claim:52-62` gives that plane
   `coef = ONE` and `coef = ONE * U` (it is not a table plane,
   `h_is_table:255-256`). So the pair coefficients are exactly `(1, U)` and
   the determinant is `Norm(1) = 1`, a **constant** — the sum claim's
   diagonal factor is not even challenge-dependent. What I did not verify
   is that no *other* plane of `h_planes()` also lands on rows 278-279 and
   adds to those weights; `audit_claims:110-116` constrains the sum claim
   to cover both u rows but does not by itself forbid a second contributor.
   **CLOSED (check §2a, correction C-2):** no other *plane* lands there
   (`h_off` is a strictly increasing cursor and `H_U = 50` is the last of
   `N_H = 51`, `Dom::Tab`, `log = 8`; `layout.rs:239, 241-252, 576-583`),
   and the second *claim* that evaluates those rows (`argument.rs:899`) is
   harmless because §3.3 step 3 zeroes its group's coefficients first. Note
   also that `audit_claims` only counts rows satisfying `is_site(r)`, so
   the `u` pair is outside its view by construction (`protocol.rs:399`,
   `:464`); the tool documents the case at `zk60_native_jv_pcs.py:377-380`.
8. **Is `_disclosed`'s `k0` the right quantity to bound at all?** This
   lemma proves the hypotheses of the tool's reduction and the rank values;
   it takes the reduction itself (`disclosed = 256 k0 + u-term`) as given,
   from the tool's docstring and its brute-force cross-check on a small
   synthetic instance. If the reduction is wrong, this lemma is about the
   wrong number.
   **PARTLY ANSWERED, STILL RELIES ON (check §4.4, §3.3; condition O-2):**
   the check re-derived the reduction on paper under H-pad, including why
   the u-term enters as `u_dim` and not `256 * u_dim` (§3.3). That
   derivation is per commitment, treats the hash layer as outside the view,
   and is not a substitute for the tool's small-model cross-check, which
   the check did not run. Label 14 stays RELIES ON.
9. **The certifying minor.** §3.7 specifies the tool addition the fallback
   route needs. Should it be built even though the structural route makes
   it unnecessary? My view: yes, cheaply, because it is the only way a
   third party can re-verify the fallback if step 1 above ever fails.
   **IN PROGRESS:** the check showed the minor can be named a priori from
   the layout, and the tool fix under ruling G-1 prints it per role
   (2026-09-20).

## 7. Evidence

`results/zk60_generic_rank_lemma/`, all plain-Python exact integer
arithmetic, no builds, no prover runs, nothing read from a capture bundle
beyond challenge-independent structure (row, claim, group and slot counts).

| file | what it establishes |
|---|---|
| `pad_block_structure.py` / `.txt` | H-pad and M-cols for **every** column set: node distinctness, `Z_n(x_j) != 0` over all 2048 encoded positions and `z_j != 0` over all 4096 of M's, ranks on five column sets each, one negative control |
| `pair_block_identity.py` / `.txt` | `wedge(x, xU) = Norm(x)` and `wedge(lam a, lam b) = Norm(lam) wedge(a,b)` on 20,000 draws each — these stand. Its factorisation, `k0 = 0` and negative-control parts ran on **synthetic** roles whose groupings were invented (e.g. member counts `[4]*25 + [2]*10` for block A, not the real grouping) and are **SUPERSEDED** by the check's runs on the real claim schedules; one of its negative-control readings was false at the real schedule (B-4, §3.2) |
| `cfs_round_rank.py` / `.txt` | `rank R_s = dim C_s` and "every published functional is in the round span", at the actual `(N_s, d_s)` of all 23 + 18 slots, under five `rho` regimes, plus a negative control |
| `bounds.py` / `.txt` | the refusal probability term by term, the sampler residual on these draws, the Schwartz–Zippel backstop over Fp and over Fp2, and the sensitivity lines |
| `captured_ranks.txt` | the sixteen role-captures' ranks and counts, from the joint-view gate's own record (`joint_view.json` on `zk60-native-jointview`), for comparison with the synthetic shapes |

**The evidence of record for the factorisation is the independent check's**,
`results/zk60_generic_rank_lemma_check/` (not modified here):

| file | what it establishes |
|---|---|
| `check_pair_factorisation.py` / `factorisation_smoke.txt` | the factorisation rebuilt from the **real** captured claim schedules: the grouping equals the Rust `group_zclaims` element by element on all sixteen role-captures, and at 48 fresh uniform challenge vectors `det == prod Norm(lambda cm) * wedge(prox)` with zero mismatches, zero zero-determinants, ranks 72 / 20 / 4 / 4 and 62 / 18 / 4 / 4, `k0 = 0`; plus `part_rows` exact for every part of every claim |
| `check_adversarial_challenges.py` / `adversarial.txt` | the same identity under 26 adversarial regime-role combinations, 78 challenge vectors: no value of `lambda` or `cm` short of zero kills the minor; and the singleton-group control (one `cm = 0` gives `k0 = 2`) |
| `check_channels_and_numbers.py` / `channels_and_numbers.txt` | `dim ker R = 1` in 115 recomputed cases under five `rho` regimes with the `d`-values negative control; the exhaustive pad arithmetic including the 257-distinct-position boundary control; the refusal and backstop numbers; the two-row Fp/Fp2 counterexample |
| `check_u_row_term.py` / `u_row_term.txt` | the u-row indicators, the solving combination's generators, and span equality with the public LogUp identity at fresh challenges |

Source read, not modified: `zkp-core/src/{pcs,transcript,field,sumcheck}.rs`,
`hashline/src/private_block/{protocol,argument,layout}.rs`,
`hashline/src/private_attention/{protocol,argument,layout}.rs`,
`hashline/src/{private_seam,zk}.rs`, and on branch `zk60-native-jointview`
`scripts/zk60_native_joint_view.py`, `scripts/zk60_native_jv_pcs.py`,
`scripts/zk60_native_jv_cfs.py`, `scripts/zk60_native_jv_capture.py`.

## Revision record (2026-09-20)

One row per adjudicated item: the blocking items, corrections and omitted
conditions of `ZK60_GENERIC_RANK_LEMMA_CHECK.md` and the rulings G-1 … G-5
of `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`. No claim was added beyond what
those two documents establish; no evidence file was edited.

| Item | Section(s) changed | What changed |
|---|---|---|
| B-1 | §3.1, §3.3, §3.8 row 9, §4 item 6, §6 item 3 | the enabling hypothesis ("every H plane's `log_size` on one side of `LOG_N`") is now stated, with the 125M/rung citations and the refusal string; §3.3 is flagged as being about a claim that cannot be formed there until the P-3 repair |
| B-2 / C-1 | §2.2, §3.8 rows 2 and 21, §6 item 1 | the four assertions `zkp-core/src/pcs.rs:759, 768, 775, 786` are cited as what makes `part_rows` exact; the failure mode is recorded as a PCS panic (liveness), and the assertions as an invariant that must not be weakened |
| B-3 / C-5 | §3.5a, §3.8 rows 11 and 22, §6 item 6 | `zkp-core/src/sumcheck.rs:148-150` (`d + 1` values per round) is cited as the premise, with the negative control (kernel dimension 2 at slots 8 and 17) and the invariant wording |
| B-4 / C-3 / G-4 | §3.2 ("Where this is conservative" → "Which refusals are necessary") | paragraph replaced: one zero `cm` gives `k0 = 2` at the real schedule because singleton groups are common, so the zero-mask-challenge refusal is exactly necessary; the old reading is marked withdrawn; the two surviving controls kept |
| C-2 | §3.3, §6 item 7 | §6 item 7 closed (no other plane on rows 278-279; a second claim does evaluate them, harmlessly), with the tool's own comment cited |
| C-4 | §3.2 step 6 | the verifier's own `check_opening` / `check_endpoint_opening` calls (`protocol.rs:458, 464, 471`) added: a receipt in the wild implies the refusal predicate held |
| C-6 | §6 item 6 | eleven → **twelve** `d = 2` slots (5-13, 20-22) |
| C-7 | §0, §3.7, §5 | "the project … has a problem" replaced by "the generic tool is weak here"; the backstop is labelled a generic bound on a product of norm forms, not an estimate |
| C-8 | §2.2 correction 1, §3.7 item 3, §5 sensitivity, §6 item 5 | the misquotation fixed (the sketch said `G x G` with `G` = groups plus proximity); the substance (realification doubles it) kept; the two-row counterexample recorded, settling §6 item 5 |
| C-9 | §5 | `2^-77.7` attributed to the privacy case's recount, with D9's own `2^-96` per draw and `2^-75` at the toy shape |
| C-10 | §5 | the category stated before the invitation: this `2^-62` is completeness/liveness, D9's is a privacy residual; identifying them would be a category error |
| C-11 | §3.1, §3.6 | "probability 1 on non-refused runs" is stated as a claim inside the random-oracle model, because the conditioning event is defined by oracle outputs |
| C-12 / G-1 | §0, §1.5, §3.8 row 17, §4 item 3 | both hard-codings named (lines 245 and 248), stage 4 recorded as unable to fail, the JOINT statement recorded as NOT computed today with the fix in progress (2026-09-20), the label kept GAP, and the independence of this lemma's per-commitment results stated |
| O-1 | §3.2 step 6, §3.8 row 8, §3.9, §6 item 2 | the grouping evidence recorded, the missing Rust test recorded as owed, label 8 kept RELIES ON |
| O-2 | §3.3, §3.8 row 14, §6 item 8 | the `u_dim`-not-`256 u_dim` step of the reduction argued (hyperplane-uniform `u` row; the two public functionals written down); label 14 kept RELIES ON |
| O-3 | §2.3, §3.4, §3.8 row 10 | the pad budget stated as established: with-replacement sampling, 241-246 distinct, rank = distinct count, pad halves determined, 256 sufficient jointly per commitment with zero slack, pad count and Q must move together |
| O-4 | §3.5c | the tool's Cauchy block is built at `[0,256)` while the real pads sit at `[L, L+256)`; harmless, but the tool should check the protocol's positions |
| O-5 | §3.2 step 6, §3.6 | restart semantics stated: a refused attempt redraws pads, salts and masks (`protocol.rs:5-8`), so the accepted transcript is uniform on the non-refused set |
| O-6 | §3.8 row 23 | new label row for the uniformity of the non-data rows' messages (`protocol.rs:361`, `:364-372`, `private_seam.rs`) |
| G-1 | §0, §1.5, §3.7 item 1, §3.8 rows 16 and 17, §4 item 3 | see C-12; plus the certifying-minor fix in progress recorded |
| G-2 | §3.1 scope note, §3.8 row 20, §4 item 6 | "re-check" replaced by "re-prove"; what is owed spelled out (P-3 first, then `A_GROUPS` 35 → 36, 29-row endpoints with three data parts, the new pad-zero refusal, a second `(n, nn)` pair at the rung) |
| G-3 | §2.2, §3.1, §3.5a, §3.8 rows 21 and 22, §3.9 | the two code facts cited where used and added to the RELIES-ON list as invariants that must not be weakened, with the recomputed negative control |
| G-4 | §3.2 | see B-4 |
| G-5 | new §3.9 | "What this lets the privacy case say": seven linear-channel steps may be re-labelled PROVED-CONDITIONAL for the two toy layouts, under the three named conditions; the joint statement stays not computed |
| Evidence of record | §0, §3.2 step 5, §3.8 row 4, §7 | the check's runs on the real claim schedules (48 uniform + 78 adversarial vectors, zero mismatches, ranks 72/20/4/4 and 62/18/4/4) recorded as the confirmation of record; `pair_block_identity.py` marked superseded for that purpose (its identity checks stand) |
| Status line | header | replaced with the revised-after-check status required by the disposition |

Items that needed no change: none of the adjudicated items was left
unapplied. The check's suggestions that are not in its errata tables (for
instance a footnote distinguishing the tool's "data rows" from the Rust
`h_data_rows`) were not acted on, since this pass applies only the
adjudicated lists.

(revision complete)
