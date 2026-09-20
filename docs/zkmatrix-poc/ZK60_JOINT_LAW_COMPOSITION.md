# The joint law of the field view (U-3b), and the nonlinear link between the two channels (item 21)

**DRAFT argument for the security owner's review — NOT ACCEPTED, NOT a
privacy acceptance. Delegated Opus draft, 2026-09-20. Every step is labelled
proved here, relies on, or gap.**

## 0. Plain words, for the project owner

**What this memo is.** The project has, for the toy private block, a pile of
per-channel facts: the opened columns are absorbed by the pads; each claim
carries its own reserved mask pair; each slot's masked sumcheck rounds are
uniform on the space the verifier's own equations leave free; the mask
evaluation is not an extra observation. What nobody had written is the
sentence that ties them together: *the receipt's arithmetic content, taken all
at once, has a distribution that does not depend on the hidden input.* Per
channel is not enough — the project's own counterexample `(H(mask), mask ⊕ w)`
has two published values each of which is uniform on its own, and together
they hand over `w`. This memo writes the joint statement, for fixed
challenges, and then says what is needed to lift it to the real protocol.

**What is shown.** At fixed, non-refused challenges, the joint law of every
field value a private-block receipt publishes is the same for every hidden
input the constructors admit — *provided* five named inputs hold, four of them
already accepted elsewhere. The argument has a concrete form: an algorithm,
written out in §3.4, that samples the whole field view from public data alone,
with exactly the honest prover's distribution. The earlier drafts called that
object **O1** and said it did not exist. It does; §3.4 is it.

**What the argument turns on.** One identity does almost all the work. The
mask commitment `M` — the one place where the blinding of the 23 sumchecks is
published a second time — reveals exactly one field value beyond what is
already public, and that value is *computed by the verifier* from the rounds
and the terminals it already has. So the blinding variable that appears in two
places is not, in fact, published twice: the second publication is a function
of the first. That is why the counterexample does not apply, and it is the
answer to the question the project has been calling "the nonlinear link"
(item 21), because the function in question is the degree-≤4 slot polynomial.

**What it rests on.** (i) The generic-rank lemma, accepted 2026-09-20 for the
two toy layouts, for the commitment side. (ii) A block-diagonality fact — no
blinding source is shared between two commitments — which is read off the
code and computed on four captures, not proved. (iii) The mask channel's two
identities from that lemma's §3.5. (iv) The standard assumption that the
prover's BLAKE3 stream is indistinguishable from uniform. (v) For the lift to
real challenges, the random-oracle model for one untagged hash table, and
salted-leaf hiding for the part of the Merkle tree that is never opened.

**What is still missing.** Three things, and they are named in §6 and §8.
The hash layer is not covered by anything here — this memo is about field
values, and the roots and authentication paths are not field values. The
125M profile and the development rung owe the whole argument again from the
start. And the step from "the law is the same for each fixed challenge
vector" to "the law is the same when the challenges are hashes of the
messages" is the sequential-kernel lemma, whose hypothesis this memo is
written to discharge — for the field messages only, which is all that lemma
ever asked for, but the lemma itself lives on a branch and not in the main
tree.

**What must not be read into it.** Nothing here establishes a privacy
property. It is one of the five steps of the path in
`ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` §3 (step 4), it has not been
independently checked, and its central theorem is stated with hypotheses two
of which are themselves labelled "relies on". A checker should start at §8.



## 1. The view as random variables

Everything in this section is read off the source of the **toy private block**
profile `hashline-zk-mr1/private-block-t32-poc/1`. Where a fact is a source
reading it is cited at a line; where it is arithmetic it is marked.

### 1.1 Notation, and the two things "the view" can mean

Fix an admissible public statement `P` (weights, the three tables, `gamma`,
the calibration and schedule digests, the 112-byte policy) and a hidden input
`w`. The prover's output splits into two parts that need different tools:

* the **field view** `V` — every `Fp` / `Fp2` word the receipt carries, i.e.
  everything the verifier does arithmetic on;
* the **hash view** `H` — the three 32-byte roots, the 5 × 256 leaf salts and
  the 5 × 256 authentication paths (11 sibling digests each for `A`, `H` and
  the two endpoints, 12 for `M`).

**This memo is about `V`.** `H` is items 14–16 of the privacy case and enters
here only in §5.2, as one assumption. The split is not cosmetic: `V` is an
(affine or polynomial) image of field-valued randomness and is amenable to
exact statements; `H` is not.

Write `p = 2^64 − 2^32 + 1`, `Fp2 = Fp[U]/(U^2 − 7)` (`zkp-core/src/field.rs:10`,
`:15`). Every transcript challenge is an `Fp2` element drawn by
`Transcript::challenge_fp2` (`zkp-core/src/transcript.rs:103-112`); the opened
column indices are drawn by `challenge_indices` (`:118-131`) **with
replacement**. Write `ρ` for the whole vector of challenges of one attempt —
the 23 slot mask challenges `c_s`, every sumcheck round challenge, every
extension challenge `e`, the three LogUp challenges, the slot definition
challenges (τ, μ, ν, points), `θ`, the group `λ`s, the proximity ρs and the
five index lists. Write `NR(ρ)` for the event that no refusal fires (the
inventory is item 24 of the privacy case; the challenge-driven classes are
`c_s = 0`, `e ∈ {0,1}`, a zero group coefficient, a dependent proximity pair,
a zero batching challenge).

Everywhere below, **"at fixed challenges" means: condition on `ρ` and on
`NR(ρ)`.** §5 removes the conditioning.

### 1.2 The blinding families, named and counted

Five families, all drawn from three OS-seeded `ZkRng` streams (item 22 of the
privacy case; `private_block/protocol.rs:275`, `private_seam.rs:196` twice).
Counts are this drafter's, recomputed from the layout and agreeing with the
privacy case §3.2 item 23 term by term.

| # | family | where committed | size (Fp draws) | published? |
|---|---|---|---:|---|
| B1 | `A`'s 120 **reserved mask pairs** (240 rows) + `A`'s **proximity pair** (2 rows) — uniform row messages | `A` rows 213…454 | 242 × 256 = 61,952 | no (only through openings) |
| B2 | `A`'s **pads**, 256 per row | `A`, all 455 rows | 455 × 256 = 116,480 | no |
| B3 | `H`'s 51 reserved pairs (102 rows) + proximity pair (2 rows) | `H` rows 280…383 | 104 × 256 = 26,624 | no |
| B4 | `H`'s **zero-sum pair** `u` (rows 278, 279): `N − 1` uniform entries, the last set to the negated sum (`protocol.rs:364-372`) | `H` | 2 × 255 = 510 free | no |
| B5 | `H`'s pads | `H`, 384 rows | 384 × 256 = 98,304 | no |
| B6 | the **23 CFS mask coefficient vectors** `a_s ∈ Fp2^{L_s}`, `L_s = (n_s+ext_s)·d_s + 2`, `Σ_s L_s = 583` | `M` rows `2s`, `2s+1` | 2 × 583 = 1,166 | no |
| B7 | `M`'s pads, 256 per a-row, at message positions `[L_s, L_s+256)` | `M`, 46 a-rows | 46 × 256 = 11,776 | no |
| B8 | `M`'s `b_re, b_im` (1024 coefficients each, `b[512] = −b[0]`) and `u_re, u_im` (1024 each) | `M` rows 46…49 | 4 × 1,024 = 4,096 | no |
| B9 | each endpoint's 5 non-data rows (one reserved pair, three proximity rows) and 7 rows of pads | the two endpoint commitments | 2 × (5+7) × 256 = 6,144 | no |
| B10 | the 5 × 2,048 / 4,096 **leaf salts** | — | 32 B each | **yes**, for the 256 opened leaves per commitment |
| | **total `fp()` draws** | | **327,052** | |

Two facts about B1–B9 that the rest of the memo uses and does not prove:

* **[RELIES ON]** every one of them is uniform and the families are mutually
  independent. In the code they are consecutive disjoint segments of at most
  three BLAKE3 XOF streams, so "independent" is **computational**, under
  assumption M-3 of the privacy case (`ZK60_PRIVACY_CASE_FIRST_MVP.md` §1.3,
  ruling C-3), and "uniform" carries the `fp()` residual of D9.
* **[RELIES ON]** no draw count depends on a witness value (privacy case item
  22, confirmed by its independent check), so the *assignment* of stream
  positions to families is a compile-time fact.

### 1.3 The published field messages, in transcript order, with their form

Transcript order is fixed at `private_block/protocol.rs:1-8`: header → `A`
root → `M` root → (`beta`, `gamma`, `alpha`) → `H` root → the 23 slots → the
single `M` opening → one PCS opening each for `A`, `H`, the input endpoint,
the output endpoint. (The *wire* order of the roots differs — `a_root`,
`h_root`, `mask_root`, `wire.rs:71-99` — which matters for byte counting and
not for anything here.)

**Per slot `s = 0…22`** (`private_block/argument.rs:255-380`; shapes
`SLOTS`, kinds `SLOT_KINDS`, `layout.rs:438-498`; 159 main + 25 extension
rounds, 721 round values, 173 terminals in total):

| symbol | count | exact form at fixed challenges |
|---|---:|---|
| `Γ_s` (the one published scalar, `b"pb-scalar"`) | 23 × 1 `Fp2` | **Private**: `σ_s(d) + c_s·G_s`; **Standalone**: `c_s·G_s`; **Host**: `c_s·G_s − Σ_{(h,κ)} κ·c_h·G_h` (`argument.rs:286-290`). Here `σ_s(d) = Σ_{x∈{0,1}^{n_s}} poly_s(tables(x))` and `G_s = ⟨sum_weights(N_s,d_s), a_s⟩` (`sumcheck.rs:222-227`, `:245-247`) |
| masked round values (`b"sc-round"`) | 721 `Fp2` | round `j` of slot `s`, `d_s+1` values at `X = 0…d_s`: `honest_j(X) + c_s·g_s.round(j, ρ_{<j})(X)` (`sumcheck.rs:284-294`, `zk.rs:984-997`). For `j < n_s` the honest part is `Σ_{x_{>j}} poly_s(tables(ρ_{<j},X,x_{>j}))`; for the `ext_s` extension rounds it is `poly_s((1−X)·cur + X·exts)` (`sumcheck.rs:296-309`) with `exts` = the reserved mask pair's evaluation for the private table extended in that round and `0` for every other table (`argument.rs:296-304`) |
| masked terminals (`b"pb-term"`) | 173 `Fp2` | `term_k = cd·T̃_k(point_k) + cm_k·(R_re + U·R_im)(tail point_k)` with `cd = ∏_m (1−e_m)`, `cm_k = e_{r(k)}·∏_{m>r(k)}(1−e_m)` (`argument.rs:352-358`; the identity is `build_claim`'s doc, `:222-236`; the fold is `masked_terminal(fin, ext, e) = fin + e(ext − fin)`, `sumcheck.rs:311-314`) |
| the mask evaluation `g_s(ρ_full)` | **0** | **not published.** The verifier *computes* it: `let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());` (`argument.rs:340`). The wire frame has no field for it (`wire.rs:71-99`) |

**The single `M` opening** (`protocol.rs:392`, implementation
`hashline/src/zk.rs:512-550`; geometry `MASK_LOG_MSG = 9`, `MASK_LOG_DOM = 12`,
`MASK_Q = 256`, `zk.rs:373-375`):

| symbol | count | exact form |
|---|---:|---|
| `q` (`b"mask-q"`) | 1,024 `Fp2` | `q = Σ_s p_{a_s}·p_{W_s} + p_b`, the coefficients of a product of polynomials of degree < 512 (`zk.rs:518-531`). `p_{a_s}` interpolates `M` row `s`'s message (its `L_s` coefficients, then its 256 pads, then zeros) on `G_512`; `p_{W_s}` interpolates the θ-batched functional weights, which are **public** given the challenges (`combined_weights`, `:469-486`); `p_b` is B8 |
| `prox` (`b"mask-prox"`) | 1,024 `Fp2` | `u + Σ_{row} r_row·p_row` over the 46 a-rows and the two `b` rows, `r_row` fresh challenges (`zk.rs:534-542`) |
| 256 opened columns | 256 × 50 `Fp` | `col_j[i] = ` the `i`-th base row's codeword at coset position `j`, for all `n_base = 2·23 + 4 = 50` rows (`zk.rs:545-548`) |

**Each PCS opening** of `A` (35 groups, 455 rows), `H` (9, 384) and the two
endpoints (1, 7) — `zkp-core/src/pcs.rs:917-943`:

| symbol | count per role | exact form |
|---|---:|---|
| group vectors `v_g` | `G_r` × 512 `Fp2` | `v_g = Σ_i ρ_g[i]·z_i` over all rows, `z_i = (msg_i ‖ pad_i) ∈ Fp^{256}×Fp^{256}`, `ρ_g = Σ_{c ∈ g} λ_c · rw_c` with `λ_c` fresh challenges and `rw_c` the claim's row weights (`pcs.rs:835-856`, `:858-875`) |
| the proximity vector | 512 `Fp2` | `Σ_i ρ_prox[i]·z_i`, `ρ_prox` `rows` fresh challenges |
| 256 opened columns | 256 × `rows` `Fp` | `col_j[i] = ⟨E_j, z_i⟩`, `E_j[msg t] = (x_j^n − 1)/(n(x_j ω^{-t} − 1))`, `E_j[pad k] = (x_j^n − 1)x_j^k`, `x_j = 7·ω_{2048}^j` (`pcs.rs:611-637`) |
| claim values | — | **not separately transmitted.** Every evaluation claim's value *is* a published terminal (`build_claim(..., value = terms[k])`, `argument.rs:357`); the one sum claim on `H` — the LogUp identity — has the compile-time value `Fp2::ZERO` (`protocol.rs:50-62`) |

### 1.4 What is linear at fixed challenges, and what is not

Write `d` for the hidden data (the committed witness planes: `A` rows 0…212
including the three multiplicity histograms, `H` rows 0…277, and the two
endpoint data rows, which are **copies of two of `A`'s rows** each — see §4.2)
and `β = (B1…B9)` for the blinding.

> **Split.** At fixed `ρ`:
>
> * **Linear channel `V_lin`** — every PCS object of `A`, `H`, `In`, `Out`
>   (group vectors, proximity vectors, opened columns), the 173 terminals, and
>   every `M` object (`q`, `prox`, columns). Each of these is an **affine**
>   function of `(d, β)`.
> * **Sumcheck channel `V_sc`** — the 23 published scalars `Γ_s` and the 721
>   round values. These are **not** affine in `d`: `σ_s(d)` and every honest
>   round message are polynomials of degree up to `d_s ≤ 4` in the table
>   values, hence of degree up to 4 in `d`. The extension rounds are in
>   addition nonlinear in `B1`/`B3`, because `exts` is a reserved mask pair's
>   evaluation and it enters `poly_s` multiplicatively.
>
> **PROVED HERE** (a reading of the forms in §1.3; the degree bound is the
> declared `SLOTS[s].2 ≤ 4`, `layout.rs:438-462`).

Three consequences worth stating before any argument:

1. **The whole of the project's existing evidence is about `V_lin`.** The
   generic-rank lemma, the joint-view tool's stages 2 and 4, the pad-budget
   proof — all of it is a rank computation on an affine model. `V_sc` is
   outside that model by construction, and the joint-view lane says so
   (`ZK60_NATIVE_JOINT_VIEW.md` §7.4).
2. **`q` is affine in the blinding** even though it is a polynomial *product*,
   because the second factor `p_{W_s}` is public once `θ` and the slot
   challenges are fixed. This is why `M` can be handled by the same linear
   machinery.
3. **The only blinding family that appears in both channels is B6**, the CFS
   mask coefficients: in `V_sc` through `c_s·R_s(a_s)`, in `V_lin` through
   `M`'s `q`, proximity vector and columns. B1/B3 appear in `V_lin` (through
   the terminals and the openings) and in `V_sc` (through the extension
   rounds' honest part). **Those two facts are the entire content of the
   composition problem**, and §3 is about them.



## 2. The masked sumcheck as a one-time pad, exactly

### 2.1 The mask, the multiplier, and the map `R_s`

**The mask.** Slot `s` runs `N_s = n_s + ext_s` sumcheck rounds of degree
`d_s` and is masked by a Chiesa–Forbes–Spooner polynomial

```
g_s(x_1..x_N) = a_0 + a'·∏_j x_j + Σ_j u_j(x_j),   u_j(X) = Σ_{e=1..d} a_{j,e} X^e
```

with `L_s = CfsMask::len(N_s, d_s) = N_s·d_s + 2` coefficients, **all uniform
in `Fp2`** from the proof RNG (`zkp-core/src/sumcheck.rs:189-203`; the layout
`[a_0, a', a_{0,1..d}, …]` at `:192-193`). The 23 masks are drawn once, inside
`mask_commit`, **before any slot challenge exists** — `M`'s root is absorbed
at `protocol.rs:326`, and the first `c_s` is drawn at `argument.rs:274`.
[VERIFIED IN THE CODE]

**The multiplier.** `c_s = tr.challenge_fp2()` drawn immediately after the
slot index is absorbed, from `Fp2` (not the base field), and **`c_s = 0` is
refused outright, never redrawn** (`private_block/argument.rs:274-277`):

```rust
let c = tr.challenge_fp2();
if c.is_zero() { return Err("zero CFS mask challenge; discard attempt".into()); }
```

**What is published.** Exactly `d_s + 1` values per round — the evaluations at
`X = 0…d_s`, with `s(0)` and `s(1)` both sent although `s(0)+s(1) = claim` is
checked (`sumcheck.rs:147-158`, the length check at `:148-150`; ruling G-3
records that length as an invariant that must not be weakened). The masking is
elementwise on those values, inside the transcript, so nothing unmasked is
ever absorbed (`transcript.rs:66-77`, `sumcheck.rs:284-294`).

**Nothing else about `g_s` is published.** Its total `G_s` reaches the view
only inside `Γ_s`; its evaluation `g_s(ρ_full)` is **never transmitted** — the
verifier derives it (`argument.rs:340`) — and both are bound to the committed
coefficients by the single `M` opening. [VERIFIED IN THE CODE]

**The map.** Fix `ρ`. Let `R_s : Fp2^{L_s} → Fp2^{N_s(d_s+1)}` send the
coefficient vector to the mask's own round messages
`(g_s.round(j, ρ_{<j}))_{j<N_s}` (`sumcheck.rs:255-274`). Let `C_s` be the
**consistency subspace**: the set of pairs `(A, r)` — a claimed sum and a
round tuple — satisfying the verifier's own equations

```
r_0(0) + r_0(1) = A,      r_j(0) + r_j(1) = interpolate_eval(r_{j-1}, ρ_{j-1})  (j ≥ 1).
```

`C_s` is a linear subspace of `Fp2^{1 + N_s(d_s+1)}` of dimension
`N_s·d_s + 1`. *Proof.* The first equation **defines** `A` from `r_0`, so
`C_s` is the graph of a linear map over the set of round tuples `r` that
satisfy the remaining `N_s − 1` equations; those involve pairwise disjoint
"left-hand" coordinate pairs `(r_j(0), r_j(1))` for `j ≥ 1` and are therefore
independent, so that set has dimension `N_s(d_s+1) − (N_s − 1)`, and
`dim C_s = N_s(d_s+1) − N_s + 1 = N_s d_s + 1`. ∎ **PROVED HERE.**
(The script of §7.1 recomputes `dim C_s` from the constraint matrix at all 23
shapes and five `ρ` regimes and gets `N_s d_s + 1` every time.)

> **Fact 2.1 (the mask covers `C_s` exactly).** `rank R_s = N_s d_s + 1` and
> `dim ker R_s = 1`, **for every `ρ`** — an identity, not a rank measured at
> captured challenges. Hence the map `a_s ↦ (G_s, R_s(a_s))` has image exactly
> `C_s`.
>
> **RELIES ON** `ZK60_GENERIC_RANK_LEMMA.md` §3.5(a) (labelled PROVED HERE
> there, by an explicit elimination on the round formula, and re-checked at
> all 23 + 18 real `(N_s, d_s)` and five `ρ` regimes), which in turn relies on
> the `d+1` published values per round (`sumcheck.rs:148-150`, ruling G-3).
> The image identification uses in addition `G_s = Σ_x g_s(x) = r_0(0)+r_0(1)`
> of the mask's own rounds (`sum_weights`, `sumcheck.rs:222-227`), so `G_s` is
> a coordinate of `R_s(a_s)` rather than an extra output. Re-checked
> independently by this drafter over a prime field at the block's 23 slot
> shapes (11 distinct `(N, d)`) × 5 `ρ` regimes = 115 pairs, 0 failures:
> §7.1, `mask_rank_identity.py`.

### 2.2 The slot-system lemma: the whole sumcheck channel is uniform on a public subspace

Hosts make the 23 slots one system, so state it once for all of them.

Let `T = (Γ_s, r_s)_{s=0..22} ∈ Fp2^{744}` be the published sumcheck channel
(23 scalars + 721 round values). Change coordinates to
`T' = (A_s, r_s)_s` with

```
A_s = Γ_s + Σ_{(h,κ) ∈ hosted(s)} κ·Γ_h          (argument.rs:322)
```

— the verifier's own claimed sum. Because every hosted slot runs **before**
its host (`layout.rs:716-723`, `assert!(s < host, "a host runs after the slots
it hosts")`), this is a unit-lower-triangular, hence invertible, linear change
of coordinates. **PROVED HERE.**

> **Lemma 2.2 (one-time pad, whole channel).** Fix `ρ` with `NR(ρ)`. Let
> `C = ⊕_s C_s ⊂ Fp2^{744}` in the `T'` coordinates; `dim_Fp2 C = Σ_s
> (N_s d_s + 1) = 537 + 23 = 560`. Then for **every** admissible hidden input
> `w`, `T'` is distributed **uniformly on `C`**. `C` depends on `ρ` only.
>
> *Proof.* Write `T'(w, a) = T'(w, 0) + R(a)` where `R = ⊕_s (c_s · R_s)` in
> the `T'` coordinates — it is a direct sum because the mask's contribution to
> `A_s` is `c_s G_s − Σ κ c_h G_h + Σ κ (c_h G_h) = c_s G_s`, the hosted
> masks cancelling exactly (prover `argument.rs:286-290`, verifier `:322`).
> (i) `T'(w, 0)` is the unmasked honest transcript, which satisfies the
> verifier's equations, so `T'(w,0) ∈ C`. (ii) By Fact 2.1 and `c_s ≠ 0`,
> `Im(c_s R_s) = C_s`, so `Im R = C`, and every fibre of `R` has the same
> cardinality `|Fp2|^{23}`. (iii) `a` is uniform on `⊕_s Fp2^{L_s}` and
> independent of `w`. Hence `R(a)` is uniform on `C` and `T' = T'(w,0) + R(a)`
> is uniform on `C`, whatever `T'(w,0) ∈ C` is. ∎
>
> **PROVED HERE**, given Fact 2.1 [RELIES ON], `c_s ≠ 0` [RELIES ON
> `argument.rs:274-277`], and uniform independent `a` [RELIES ON M-3, D9].

Three remarks, because Lemma 2.2 is stronger than the project's existing
statement and it is worth seeing why.

* It is not "the disclosed dimension is zero", it is "the law is *uniform on a
  subspace the verifier can write down*". That is what a sampler needs.
* It covers the **extension rounds** with no extra work: they are rounds of
  the same `SumcheckProof`, masked by the same `c_s` with the same `g_s`
  (`zk.rs:984-997`), and `C_s` is defined by the verifier's chain, which does
  not distinguish them.
* It says nothing yet about the **terminals**, which are absorbed after the
  rounds and are *not* part of `T`. They are the linear channel's business
  (§4), and the link between the two is §3.

### 2.3 The degrees-of-freedom count, honestly

Per slot, in `Fp2` dimensions:

| | count | why |
|---|---:|---|
| free mask coefficients | `L_s = N_s d_s + 2` | `CfsMask::len`, `sumcheck.rs:197-199` |
| **consumed by the published rounds and the claimed sum** | `N_s d_s + 1` | `rank R_s`, Fact 2.1 — and this is exactly `dim C_s`, so the covering is **tight with no slack** |
| consumed by `M`'s 256 opened columns | **0** | the a-row's own 256 pads absorb them: the pad block restricted to the ≤ 256 distinct sampled positions is a Cauchy matrix in distinct nodes (`M-cols`, lemma §3.4; pads at `[L_s, L_s+256)`, `zk.rs:443-446`) |
| consumed by the mask evaluation `g_s(ρ_full)` | **0** | `eval_weights` is the Lagrange combination of round `N−1`'s `d+1` published values, so the functional lies in `rowspace(R_s)` identically (lemma §3.5(b), PROVED HERE there) |
| consumed by the mask total `G_s` | **0** | `sum_weights` is `r_0(0)+r_0(1)`, likewise in `rowspace(R_s)` |
| consumed by `M`'s `q` | **0 additional** | `q` reveals exactly one `Fp2` functional of `a` across all slots (§3.1), and that functional is a combination of the 34 above, hence also in `rowspace(R)` |
| **left over** | `dim ker R_s = 1` | a **redundancy of the parametrisation**, not spare masking power |

So: **"exactly enough" is an identity, not a rank computed at captured
challenges.** `Im(R_s) = C_s` holds for every `ρ`, by the elimination in the
lemma's §3.5(a); the captures confirm it but do not carry it.

**A discrepancy a checker should resolve (open question O-3 in §8).** The
code's own comment says `a'` is *"the extra freedom that makes the total `G`
AND the terminal `g(rho)` jointly uniform given the round messages"*
(`sumcheck.rs:163-183`). The lemma's §3.5(a) computes `ker R_s` to be
one-dimensional with `a'` as its free parameter — which says the opposite:
that `a'` is removable without changing the image. This drafter recomputed
both over a prime field at the block's 23 slot shapes × 5 `ρ` regimes
(§7.1, `mask_rank_identity.py`): **dropping `a'` leaves the rank at
`N d + 1` on 115 of 115 pairs, i.e. the mask still covers `C_s` exactly.** The two statements can
both be true only if the code comment means "given the *masked* published
rounds", under which `G` and `g(ρ)` are indeed not determined — but then `a'`
is not what makes them uniform either, `c_s` and the unknown honest rounds
are. The comment should be corrected or this drafter's reading refuted;
nothing in this memo depends on which way it goes, because §2.2 uses only
`Im(R_s) ⊇ C_s`.

**Where `L_s + 256 ≤ 512` and `n_base = 2·slots + 4` come from.** `M` is an
ordinary Ligero-form commitment with its own geometry (`zk.rs:373-375`):
message length `m = 2^9 = 512` per row, codeword length `2^12 = 4096` on the
coset `7·G_4096` (rate 1/8), `MASK_Q = 256` opened columns. A mask's `L_s`
`Fp2` coefficients are split into a real and an imaginary **row**, and each
row's 512 message positions hold `L_s` coefficients **then 256 pads** then
zeros (`zk.rs:437-447`) — hence the assertion

```rust
assert!(part.len() + MASK_Q <= m, "mask row: {} coefficients + {MASK_Q} pads > {m}");
```

i.e. `L_s ≤ 256`. At the toy block the largest is `L = 50` at the softmax
zero-check (`layout.rs:733-736` asserts `n*d + 2 + 256 <= 512` for every
slot). And `n_base = 2·masks.len() + 4 = 2·23 + 4 = 50` rows
(`zk.rs:434`, `M_ROWS`, `layout.rs:519`): two rows per slot, plus `b_re`,
`b_im`, `u_re`, `u_im`. So **the "50-row `M`" and the "`L + 256 ≤ 512`"
constraint are the same fact seen from two sides**: `M` is a 50 × 512 matrix
in which each slot owns two rows and each row spends 256 of its 512 positions
on the pads that absorb its 256 opened columns.

### 2.4 Hosted slots, host slots, and slots that share a point

**Hosted / host.** `HOSTS` (`layout.rs:501-508`) has six entries, each a host
zero-check and two Private slots it hosts; `layout.rs:711-714` asserts the
split (12 Private, 5 Standalone, 6 Host). The ordering rule "hosts after
hosted slots" is enforced three times over: statically
(`assert!(s < host, …)`, `layout.rs:716-723`), by construction (a host reads
`acc.cs[hs]`, `acc.scalars[hs]`), and by the sequential-order refusal
(`argument.rs:262-264`). Lemma 2.2 is exactly where that rule earns its
keep: without `hosted(s) ⊂ {0..s-1}` the change of coordinates `T ↦ T'` need
not be triangular, and the mask map need not be a direct sum.
[VERIFIED IN THE CODE + PROVED HERE for the consequence]

**A Private slot never publishes its mask total as a functional.** Only the 5
Standalone and 6 Host slots contribute a `Γ` functional to `M`; every slot
contributes an `eval` functional; `23 + 5 + 6 = 34 = N_FUNCTIONALS`
(`argument.rs:361-376`, `:924-928`; `layout.rs:711-714`). This is load-bearing
for §3: a Private slot's `G_s` is a quantity the verifier **cannot** compute,
and it is never asked to.

**Slots sharing a point.** The schedule shares evaluation points in five
places — `r_t`/`r_t2` re-read by `SC_TZC` as *public* `eq` tables
(`argument.rs:567-569`); `r_q` drawn at `SC_QMM` and reused by `SC_KMM`,
`SC_VMM` (`:617-630`); `r_tf` shared by the gate and up matmuls (`:668-673`);
hosts reading their hosted slots' output points as public `eq`; and
`SC_IO_IN`/`SC_IO_OUT` evaluating an `A` plane and an endpoint plane at the
**same** `rho` (`:902-909`). In every case the sharing is of a *point*, never
of a *reserved pair*: `b.a_at` allocates a fresh site per claim
(`argument.rs:420-424`, `layout.rs:620-631`) and `audit_claims` refuses a
shared or unused pair (`protocol.rs:119-131`). The consequence for the law:
two terminals may be evaluations of the same plane at the same point, so
their *data parts* are equal and a public combination of the two published
terminals annihilates the data — but that combination is
`cm_1·M_1 − cm_2·M_2` with `M_1`, `M_2` independent uniform, so it is itself
uniform and independent. **PROVED HERE** (given disjoint pairs and uniform
mask rows). The `SC_IO_*` case additionally identifies **data** coordinates
across two commitments; §4.2 handles it.



## 3. The nonlinear link (item 21), and the conditional sampler O1

### 3.1 The only cross-channel equation

The two channels of §1.4 share one blinding family, B6, the mask
coefficients. `V_sc` uses them through `c_s·R_s(a_s)`; `V_lin` uses them
through `M`. So everything turns on: *how much of `a` does `M`'s opening
publish?*

Let `w_i` (`i < 34`) be the functional weight vectors of the declared `M`
functionals — `eval_weights(ρ_full^s, d_s)` for each of the 23 slots, and
`sum_weights` (scaled by `c`, and for a host by `−κ·c_h` on the two hosted
rows) for the 5 Standalone and 6 Host `Γ`s (`argument.rs:361-376`). Let

```
V(a) = Σ_{i<34} θ^i ⟨a_{s(i)}, w_i⟩        (combined_weights, zk.rs:469-486)
```

> **Lemma 3.1 (`M` publishes exactly one `Fp2` functional of `a`).** Fix `ρ`
> with `NR(ρ)`. Conditionally on `a`, the joint law of `M`'s published
> opening `(q, prox, columns)` is:
> * `q` uniform on `{q ∈ Fp2^{1024} : 512·(q[0] + q[512]) = V(a)}`;
> * `prox` uniform on `Fp2^{1024}`, independent of `q`;
> * the 46 a-rows' opened column values uniform on their distinct sampled
>   positions, independent of `(q, prox)`;
> * the 4 `b`/`u` rows' opened column values **determined** by the above.
>
> In particular **it depends on `a` only through `V(a)`.**
>
> *Proof.* (i) `q = Σ_s p_{a_s} p_{W_s} + p_b` (`zk.rs:518-531`). `p_{W_s}`
> is public. `b_re, b_im` are uniform on `Fp^{1024}` subject to
> `b[512] = −b[0]` (`zk.rs:452-455`) and independent of everything else, so
> `q` is uniform on a coset of `{c : c[0] + c[512] = 0}`. The coset is fixed
> by `Σ_{x ∈ G_512} q(x) = 512·(q[0] + q[512])`, and
> `Σ_{x ∈ G_512} p_{a_s}(x) p_{W_s}(x) = ⟨msg_s, w_s⟩ = ⟨a_s, w_s⟩`, because
> `p_{a_s}` interpolates `msg_s = (a_s ‖ 256 pads ‖ zeros)` on `G_512` and
> `w_s` is supported on the first `L_s` positions (`combined_weights` writes
> only `j < L_s`, `zk.rs:476-479`). **The pads cancel out of `V`.**
> (ii) `prox = u + Σ r_row p_row` with `u_re, u_im` uniform on `Fp^{1024}`
> and coefficient 1 (`zk.rs:456-457`, `:534-542`): a one-time pad.
> (iii) Row `i`'s codeword value at a sampled position is
> `⟨E_j|coeff, a_i⟩ + ⟨E_j|pad, pad_i⟩`; on the `d ≤ 256` **distinct**
> sampled positions the pad block is a Cauchy matrix in distinct nodes, hence
> of rank `d` (`M-cols`, `ZK60_GENERIC_RANK_LEMMA.md` §3.4), so those values
> are uniform whatever `a_i` is, independently per row. Since `q`'s law given
> `(a, pads)` does not depend on the pads (by (i)), `q` and the a-columns are
> conditionally independent given `a`.
> (iv) The verifier's per-column identities (`zk.rs:560-561`, `:585-587`)
> determine `b(x_j)` and `u(x_j)` from `q`, `prox` and the a-columns — which
> is what the module's own header comment states: *"b and u are determined by
> (q', prox, the a columns)"* (`zk.rs:361-362`). ∎
>
> **PROVED HERE**, given: uniformity and mutual independence of `b`, `u` and
> `M`'s pads [RELIES ON `zk.rs:443-457` and M-3]; `M-cols` [RELIES ON the
> generic-rank lemma §3.4, which proves it for **every** column set,
> conditional on `q_pad == num_col_checks == 256` with **zero slack**].

**So the entire cross-channel link is one `Fp2` equation**: the receipt
publishes `q`, and the only thing `q` says about the 583 mask coefficients is
the single value `V(a)`. That is the precise form of item 21's "nonlinear
link", because — next — `V(a)` is a *nonlinear* function of the rest of the
view.

### 3.2 The derived-value identity, used distributionally

> **Fact 3.2.** On every honest run, for every witness and every non-refused
> `ρ`:
>
> 1. the 23 `eval` functional values are `g_s(ρ_full^s) = (fin_s −
>    poly_s(vals_s))·c_s^{-1}`, where `fin_s` is the sumcheck's final claim,
>    computed from the **published rounds** by iterated `interpolate_eval`,
>    and `vals_s` is built from the **published terminals** in the slot's
>    private-table positions and from public quantities (`eq_point`,
>    `eval_mle_ext`, the selector `sel = ∏(1−e)`) elsewhere
>    (`argument.rs:326-340`);
> 2. the 5 + 6 `Γ` functional values are the published scalars themselves
>    (`argument.rs:365-376`);
> 3. therefore `V(a) = V_pub(T, terms)` — a **public** function of the
>    sumcheck channel and the terminals, of degree up to 4 in up to 61
>    terminals, and with **no other dependence on the witness**.
>
> **RELIES ON** two things this memo does not re-derive: completeness of the
> masked sumcheck with extension rounds, i.e. that the honest `fin_s` really
> equals `poly_s(masked terminals) + c_s·g_s(ρ_full)`, which needs the
> CONSTRUCTION PREMISE *"every slot polynomial has a public factor in every
> monomial, so `poly(extensions) = 0`"* (`argument.rs:18-22`, stated there as
> a premise); and the numerical confirmation of the same identity on all 82
> slot equations of the four captures with two negative controls
> (privacy case item 13, `ZK60_NATIVE_JOINT_VIEW.md` §11).

Item 12 of the privacy case already proved sentence 1 as an *accounting*
rule: a derived value is not an independent observation. **Fact 3.2 is the
same identity used for a different purpose** — as the statement that the
functional `V` of the hidden mask coefficients is pinned to a public function
of the published view. That is what makes the composition go through, and it
is the step nobody had written.

Two structural details make Fact 3.2 possible and are worth naming, because
a redesign could break either:

* **a Private slot never contributes a `Γ` functional** (§2.4). Its mask
  total `G_s = (Γ_s − σ_s)/c_s` involves the honest sum `σ_s`, which is
  *not* public; if `M` batched it, `V` would not be a public function of the
  view and the argument would fail at exactly this point;
* **the 34 weight vectors all lie in `rowspace(R_s)`** (lemma §3.5(b)), so
  `ker R ⊆ ker V` and `V` **factors through `R`**: there is a linear
  functional `V̂` on `C` with `V(a) = V̂(R(a))`. **PROVED HERE** given
  §3.5(b). This is used in the next proof and is not the same statement as
  Fact 3.2.

### 3.3 The composition theorem at fixed challenges

Partition the blinding into three independent groups (§1.2, M-3):
`α = B6` (mask coefficients), `π = (B1..B5, B9)` (the four PCS commitments'
mask rows, zero-sum rows and pads), `μ = (B7, B8)` (`M`'s pads, `b`, `u`).
The field view splits as

```
V_sc  = F_sc (w, α, π)      the 23 scalars and 721 round values
V_pcs = F_pcs(w, π)         A, H, In, Out: group vectors, proximity vectors,
                            opened columns, and the 173 terminals
V_M   = F_M  (α, μ)         q, prox, M's 256 opened columns
```

(`V_pcs` does not involve `α` or `μ`; `V_M` involves neither `w` nor `π`;
`V_sc` involves `π` only through the extension rounds' `exts`.)

> **Theorem 3.3 (the joint law at fixed challenges).** Fix an admissible
> public statement and a challenge vector `ρ` with `NR(ρ)`. Assume
>
> * **(H1)** the law of `V_pcs` given `w` does not depend on `w` — §4;
> * **(H2)** `Im R = C` and every fibre of `R` has the same size — Fact 2.1
>   and `c_s ≠ 0`, §2.2;
> * **(H3)** the law of `V_M` given `α` depends on `α` only through `V(α)` —
>   Lemma 3.1;
> * **(H4)** `V(α) = V_pub(V_sc, V_pcs)` on the honest support, and `V`
>   factors through `R` — Fact 3.2 and §3.2's second bullet;
> * **(H5)** `α`, `π`, `μ` are mutually independent and `α` is uniform.
>
> Then for every admissible `w`, `w′`, the joint law of
> `(V_sc, V_pcs, V_M)` is the same, and it is given explicitly by
>
> ```
> Pr[V_sc = t, V_pcs = v, V_M = m]
>     = 1[t′ ∈ C] · |Fp2|^{-560} · P_pcs(v) · Φ(m ; V_pub(t, v))
> ```
>
> where `t′` is `t` in the claimed-sum coordinates, `P_pcs` is the
> (witness-free) law of (H1) and `Φ(· ; V)` is the law of Lemma 3.1.
>
> *Proof.* Condition on `π` and sum over `α`:
> ```
> Pr[t, v, m | w] = Σ_π P(π)·1[F_pcs(w,π)=v] · Σ_α P(α)·1[F_sc(w,α,π)=t]·Pr[F_M(α,μ)=m | α].
> ```
> In the `T′` coordinates `F_sc(w,α,π) = T′(w,π) + R(α)` with `T′(w,π) ∈ C`
> the unmasked honest tuple (Lemma 2.2's proof), so the inner indicator is
> `1[R(α) = t′ − T′(w,π)]`. By (H3) the last factor is `Φ(m ; V(α))`. By (H4)
> `V` is constant on each fibre of `R`, and its value there is
> `V_pub(t, v)` — this is the identity of Fact 3.2 read at any consistent
> triple `(w, π, α)`, and it is the same constant for every `w` and `π`
> compatible with `(t, v)`. So the inner sum equals
> `Φ(m ; V_pub(t,v)) · |{α : R(α) = t′ − T′(w,π)}| / |Fp2|^{583}`, and by
> (H2) the fibre count is `|Fp2|^{23}` when `t′ − T′(w,π) ∈ C` and `0`
> otherwise — i.e. exactly `1[t′ ∈ C]`, independent of `w` and `π`, since
> `T′(w,π) ∈ C`. What is left is
> `1[t′∈C]·|Fp2|^{-560}·Φ(m;V_pub(t,v))·Pr[F_pcs(w,π)=v]`, and the last
> factor is `w`-independent by (H1). ∎
>
> **PROVED HERE**, on hypotheses (H1) [§4: PROVED HERE from the accepted
> lemma **plus** a block-diagonality fact that is RELIES ON], (H2) [RELIES
> ON], (H3) [PROVED HERE on RELIES ON inputs], (H4) [RELIES ON], (H5)
> [ASSUMED: M-3, D9].

**What the factorisation says, in words.** The sumcheck channel is uniform on
a public subspace and independent of everything else; the commitment channel
has a witness-free law of its own; and the mask commitment's opening is
sampled *conditionally on one number that the verifier itself computes from
the first two*. Nothing anywhere conditions on the witness.

**A consequence that closes item 20 at the field layer.** Theorem 3.3 does
not merely say the law is the same for two witnesses in some declared integer
class; it says the field view's law does not depend on the data rectangle
**as an `Fp`-vector at all**. So no constraint the integers place on that
rectangle can separate two witnesses at the field layer. Privacy-case item 20
("integer-range side information", OPEN, waiting on item 21) is therefore
discharged **at the field layer and on the same hypotheses** — not at the
hash layer, where an integer plane's range is not an object anyway.
**PROVED HERE, conditional on Theorem 3.3's hypotheses.**

### 3.4 O1: the conditional sampler, written out

This is the object the D8/D11 draft named **O1** and said did not exist. It
samples the **field view** — not the hash layer (§3.5). Input: the public
statement, the layout, and the challenge vector `ρ` (with `NR(ρ)`). No
witness, no pad, no mask, no salt.

```
O1(statement, layout, ρ):

 0. PUBLIC PREPARATION
    from the layout and ρ compute: the 23 slot shapes (N_s, d_s); the
    subspace C (dimension 560) defined by the verifier's sumcheck chain;
    the claim schedule and every claim's row/column weights; the public
    tables' evaluations at the slot points; θ and the 34 weight vectors
    w_i; the five opened-index lists.

 1. THE SUMCHECK CHANNEL — uniform on C
    for each slot s, in schedule order:
      draw A_s  ← Fp2 uniform                                (the claimed sum)
      claim ← A_s
      for j = 0 .. N_s-1:
        draw r_{s,j}(0), r_{s,j}(2), …, r_{s,j}(d_s) ← Fp2 uniform   (d_s values)
        set  r_{s,j}(1) ← claim − r_{s,j}(0)
        claim ← interpolate_eval(r_{s,j}, ρ_{s,j})
      fin_s ← claim
    recover the published scalars by inverting the triangular map:
      Γ_s ← A_s − Σ_{(h,κ) ∈ hosted(s)} κ·Γ_h
    (1 + N_s·d_s free Fp2 values per slot; 560 in total — exactly dim C.)

 2. THE COMMITMENT CHANNEL — the witness-free law P_pcs
    for each role r ∈ {A, H, In, Out}:
      build the row matrix with ZEROS in the data rectangle and fresh
      uniform Fp entries in every non-data row (reserved pairs, the
      proximity pair, and for H the zero-sum pair u drawn as N-1 uniform
      entries with the last set to the negated sum), and fresh uniform
      pads in all 256 pad positions of every row;
      compute the group vectors, the proximity vector and the 256 opened
      columns exactly as open_zk does.
    read the 173 terminals off as the resulting claim values, and take
    the LogUp sum claim's value to be the constant Fp2::ZERO.

 3. THE CROSS-CHANNEL VALUE — computed, never sampled
    for each slot s: vals_s ← the terminals of step 2 in the slot's
      private-table positions, public values elsewhere;
      g_val_s ← (fin_s − poly_s(vals_s))·c_s^{-1}
    values ← [ Γ_s for standalone s ] ++ [ g_val_s for all s ]
             ++ [ Γ_s for host s ]        (the declared order)
    V ← Σ_i θ^i · values_i

 4. THE MASK COMMITMENT — sampled conditionally on V
    draw the 46 a-rows' values at the distinct sampled coset positions
      ← uniform Fp (copy for repeated indices)
    draw q ← uniform on { q ∈ Fp2^1024 : 512·(q[0]+q[512]) = V }
    draw prox ← uniform on Fp2^1024
    set the b-row and u-row column entries from the verifier's own
      per-column identities:
        b(x_j)   ← q(x_j) − Σ_s a_s(x_j)·W_s(x_j)
        u(x_j)   ← prox(x_j) − Σ_row r_row · row(x_j)

 5. OUTPUT (V_sc, V_pcs, V_M).
```

> **Corollary 3.4.** Under the hypotheses of Theorem 3.3, `O1(statement,
> layout, ρ)` outputs a sample whose law is **exactly** the honest prover's
> field view at challenges `ρ`, for every admissible hidden input.
> **PROVED HERE** — it is the explicit law of Theorem 3.3 read as an
> algorithm: step 1 samples `Uniform(C)` (the free-coordinate
> parametrisation is a bijection onto `C` by the same count as §2.1), step 2
> samples `P_pcs` (legitimate because (H1) says the law is the same for
> every data rectangle, **including the all-zero one**), step 3 evaluates
> `V_pub`, step 4 samples `Φ(· ; V)` (Lemma 3.1's four bullets).

**In what sense the sampler's existence *is* the theorem.** Perfect, for
fixed non-refused challenges, in the uniform-blinding idealisation: the
output distribution *equals* the honest one, not "is close to". It is the
theorem and not merely a consequence of it, because the only way to write the
law down is to write the sampler down: there is no product form — step 4
conditions on a nonlinear function of steps 1 and 2.

**Two things step 2 is worth pausing on.** First, it puts **literal zeros**
in the data rectangle. It does *not* need the witness builder to accept the
all-zero input, and it does not need `NORM_CEPS = 1` or the pinned
exponential-table entry. Those are conditions on privacy-case step 2, which
is about a *whole receipt* (with real Merkle trees) being producible; the
field view alone needs strictly less. Second, step 2 is stated as a recipe
rather than as "uniform on the public affine subspace `Im φ_B` shifted by the
public disclosed values", which is what it is; the recipe is the efficient
form, the affine description is the meaning, and (H1) is the statement that
they agree.

### 3.5 What O1 does not do, and the residuals

* **It produces no roots, no salts and no authentication paths.** It is a
  field-view sampler. For a whole receipt the ideal-world program stays the
  one ruling D18 fixes — the honest prover on a fixed input — and what
  Theorem 3.3 adds is that *that program's field view has exactly the right
  law*, which is the part nobody had shown. The hash layer is §5.2.
* **It is conditioned on `NR(ρ)`.** The refusal channel's own
  witness-independence is §5.4 and is not proved here.
* **Residuals, with the sizes the privacy case carries** — none of them is
  introduced by this memo and this memo adds no new target:
  * the `fp()` sampler bias, **≤ 2^-77.7** per toy-block proof over 327,052
    draws at exactly `2^-96` each; accepted by ruling **D9**;
  * the PRG assumption **M-3** on `ZkRng` (whole-stream indistinguishability
    — needed in both directions because `A`'s 256 published salts leave the
    process before `H`'s pads are drawn from the same stream); computational,
    no bit count;
  * the one witness-dependent refusal, a zero LogUp denominator, at
    **2^-112.0** (`64,768/2^128`; **2^-117.4** counting distinct values,
    which a write-up should prefer);
  * the challenge-driven refusal rate, **2^-62.0 per proof** at either toy
    profile (`ZK60_GENERIC_RANK_LEMMA.md` §5) — a **liveness** cost, not a
    distinguishing one, precisely because the profile refuses and never
    resamples;
  * the hash-layer terms **M-1** and **M-2**, which are outside this memo.



## 4. Composition across slots and commitments — hypothesis (H1)

### 4.1 "Disclosed dimension zero" *is* witness-independence of a linear view

The project's tools compute a rank. Theorem 3.3 needs a distribution. The
bridge is elementary and, as far as this drafter can find, has never been
written down in the repository — the tools' docstrings assert the
consequence.

Let `X = D ⊕ B` be the unknown space of one (or several) commitments, `D` the
data rectangle (data rows × message positions) and `B` everything else
(non-data rows' messages, all pads). Let `φ : X → Fp^m` be the linear
observation map of the fixed challenges — the claim values, the group
vectors, the proximity vectors and the opened columns of §1.3. Let
`F = rowspace(φ) ⊆ X*` and let `T ⊆ X*` be the functionals supported on `D`.

> **Lemma 4.1.** Let `β` be uniform on `B` and `d ∈ D` fixed. Then:
>
> 1. the law of `φ(d, β)` is the same for every `d` **iff** `F ∩ T = 0`;
> 2. in general, the law of `φ(d, β)` depends on `d` only through the values
>    `{ψ(d) : ψ ∈ F ∩ T}`. So if those values are the same for every
>    admissible witness, the law is witness-independent even when
>    `dim(F ∩ T) > 0`.
>
> *Proof.* Write `φ(d,β) = φ_D(d) + φ_B(β)`. With `β` uniform, `φ(d,β)` is
> uniform on the coset `φ_D(d) + Im φ_B`, so the law is a function of `d`
> exactly through the coset, i.e. through `φ_D(d) mod Im φ_B`. A linear
> functional `ψ` on `Fp^m` kills `Im φ_B` iff `ψ∘φ` is supported on `D`, i.e.
> iff `ψ∘φ ∈ F ∩ T`; and `φ_D(d) ∈ Im φ_B` for all `d` iff every such `ψ`
> also kills `φ_D(d)`. Both statements follow. ∎
>
> **PROVED HERE.**

That is the whole content of the phrase "the disclosed dimension is zero", and
part 2 is what item 7 of the privacy case needs: `H`'s disclosed dimension is
`2` — the real and imaginary parts of the LogUp sum identity — and its value
is the **compile-time constant** `Fp2::ZERO` (`protocol.rs:50-62`, `:61`), so
it is the same for every witness and Lemma 4.1(2) applies. No capture is
needed for that half. **PROVED HERE**, given that the constant is the declared
value [VERIFIED IN THE CODE].

### 4.2 Which matrix must have full row rank for the joint statement

Following the tool's reduction (`zk60_native_jv_pcs.py`, restated in
`ZK60_GENERIC_RANK_LEMMA.md` §1.2), under hypotheses H-pad / H-pair / H-prox,

```
disclosed = 256·k0 + (the u-row term),
k0 = dim { p ∈ rowspace(ρ̃) : p vanishes on every non-data row }
```

and `rank(gens | non-data rows) = g` implies `k0 = 0`, where the generators
`gens` are the **real and imaginary parts** of the `G` group combinations and
of the proximity combination (lemma §1.3, PROVED HERE there).

> **The matrix for the joint statement across slots and commitments** is the
> **joint non-data block**: the
>
> ```
> g_joint × R_joint  matrix,  g_joint = 2(35+1) + 2(9+1) + 2(1+1) + 2(1+1) = 100,
>                             R_joint = 242 + 106 + 5 + 5 = 358,
> ```
>
> whose rows are all four roles' group and proximity generators and whose
> columns are the **union** of all four roles' non-data rows, with
> coordinates the protocol makes the same unknown identified.

Two things must be said about it, and they are different.

**(a) "Across slots" is not a new matrix.** All 120 `A` claim sites and all 51
`H` evaluation sites come from the 23 slots (`A_SITES`, `H_SITES`,
`layout.rs:512-513`) and are batched into `A`'s 35 and `H`'s 9 opening groups
by `group_zclaims` (`pcs.rs:807+`). So the joint-across-slots statement for
the commitment channel **is** the per-role statement, and it is exactly what
the reserved-pair-per-claim-site discipline buys: the accepted lemma's §3.2
factorises the maximal minor of one role's non-data block as
`∏_claims Norm(λ_c·cm_c) · wedge(proximity pair)`, non-zero precisely when
every `λ_c ≠ 0`, every `cm_c ≠ 0` and the proximity pair is independent — the
three quantities the prover's refusals test. **So the accepted lemma covers
the across-slots composition inside one commitment.** [RELIES ON the accepted
lemma; `audit_claims`, `protocol.rs:89-133`; `check_opening_challenges`,
`:139-152`.]

**(b) "Across commitments" is a corollary, on one hypothesis the lemma does
not prove.**

> **Proposition 4.2.** If no non-data coordinate class contains rows of two
> different roles ("block diagonality"), then the joint non-data block is
> block diagonal by role, so its rank is the sum of the four per-role ranks;
> by the accepted lemma each equals `2(G_r+1)`, so the joint rank is
> `100 = g_joint`, hence `k0_joint = 0`, hence the joint disclosed dimension
> is the `u`-row term alone, `2 Fp`, with the public value `0`.
> Identifying **data** coordinates across roles can only *lower* the joint
> disclosed dimension (it merges two columns into their sum, which can only
> shrink `F ∩ T`), so the endpoint identification is harmless.
> **PROVED HERE**, given block diagonality.

Block diagonality itself is **[RELIES ON]**, on two independent supports and
no proof:

* *the code*: every commitment draws its own pads, its own reserved mask
  pairs and its own proximity rows, from disjoint consecutive segments of at
  most three streams, and nothing is cloned or reused
  (`pcs.rs:673-674` per commitment, `protocol.rs:313-315`, `:362-374`,
  `private_seam.rs:196`; privacy-case item 22, VERIFIED IN THE CODE, with the
  caveat that `A`, `M` and `H` are **one** stream so independence is
  computational under M-3);
* *the measurement*: the repaired stage 4 of the joint-view gate
  (`zk60-native-jointview` at `14b7d20`, `ZK60_NATIVE_JOINT_VIEW.md` §12)
  builds one generator system over the union of a receipt's commitments,
  reports **0 shared non-data classes** and **4 shared data classes** (the
  two endpoint planes, which are `A[10], A[11], A[68], A[69]`), and computes
  joint `4` = sum `4` on all four captures, with a control that shares a
  blinding row across two commitments and moves the joint from 4 to 260.

**The honest reading, and the gap.** The accepted lemma
(`ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`) is explicit that all four of its
items are *per commitment* and that the joint statement is U-3(b) and "not
computed" as of its writing; ruling G-1's fix then made it computed, **on
four captures**. So the joint statement's status is: *a theorem given block
diagonality, whose hypothesis is a source reading plus four measurements.*
**GAP G-1 (this memo's numbering): no argument establishes block diagonality
for all runs; it is a structural property of the code, and the honest label
for the joint step is PROVED-CONDITIONAL on it.** What would close it: a Rust
invariant (or a test) asserting that the four PCS commitments' non-data rows
are disjoint objects drawn from disjoint stream segments, plus the same for
`M` — an assertion, not a proof, but one that cannot silently rot.

**A precision on the pad step (open question O-4 in §8).** The lemma's
disposition says "the pad halves of the group and proximity vectors are
determined by those columns, so nothing is counted twice". Read literally
that is exact only when all 256 sampled indices are distinct. The indices are
drawn **with replacement** (`transcript.rs:118-131`; `pcs.rs:1193` says so in
a test comment) and the captures record `d = 231…246` distinct, so only a
`d`-dimensional projection of each published pad half is pinned by the
columns; the remaining `256 − d ≈ 10…25` coordinates are published
independently. They are combinations of *blinding only* and so cannot add a
data functional, and the lemma's own rank is computed over the full generator
system, so this drafter believes the conclusion stands and only the prose
overstates. A checker should confirm that.

### 4.3 The masking commitment `M` inside the joint picture

`M` is the fifth commitment and it is a different animal:

* it commits **no witness data**: its 46 a-rows hold blinding (B6) and its 4
  remaining rows hold blinding (B8), so its contribution to `k0_joint` is nil
  — computed, not argued, by the repaired stage 4;
* its shape defeats the `k0 = 0` framing anyway (47 combined vectors over 4
  non-data rows), which is condition O-8 of the privacy case; the lemma
  handles it with three different source facts, `M-q`, `M-prox`, `M-cols`
  (lemma §1.4, §3.5(c));
* the object that `M`'s opening *does* disclose is not a data functional at
  all: it is one `Fp2` functional of the **mask coefficients**, which is why
  it cannot be handled by the commitment-side rank at all and needs Lemma 3.1
  and Theorem 3.3 instead.

So the correct statement of (H1) is about the **four PCS commitments only**:

> **(H1), stated precisely.** For the toy private-block layout, at any
> non-refused `ρ`, the law of `V_pcs` — the group vectors, proximity vectors,
> opened columns and 173 terminals of `A`, `H`, `In` and `Out` — is the same
> for every admissible hidden input.
>
> **PROVED HERE** from Lemma 4.1 + Proposition 4.2 + the accepted
> generic-rank lemma's items 1–3 + the `Fp2::ZERO` value of the LogUp
> identity, **conditional on**: block diagonality (GAP G-1); the lemma's own
> RELIES ON rows (`audit_claims` on every path, the refusal replay order —
> for which a Rust test is owed, the four `part_rows` assertions
> `pcs.rs:759, 768, 775, 786`, the `d+1` values per round
> `sumcheck.rs:148-150`, and the uniformity of the non-data rows'
> messages); and the two toy layouts only (ruling G-2).



## 5. From fixed challenges to the real protocol

### 5.1 What this memo discharges of the sequential-kernel lemma

The lemma (`ZK60_MVP_JOINT_VIEW.md` §1.2, branch `zk60-mvp-fable`; reviewed
`ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56`; privacy-case item 17) reads: if
each `m_j` depends only on the witness, the prover's randomness and `r_{<j}`,
and each `r_j` is any function of the public prefix, **and if for every fixed
challenge vector `ρ` the joint law of `(m_0 … m_n)` given `ρ` is the same for
`w` and `w′`**, then for every challenge function the law of the whole view
`(m, r)` is the same.

**Theorem 3.3 is that hypothesis, for the field messages, at every
non-refused `ρ`.** That is the point of this memo, and it is the first time
the hypothesis has been argued rather than measured at four challenge
vectors.

Three things it is not.

* **The message sequence includes the roots.** `m_0` is `A`'s root; `M`'s and
  `H`'s follow (`protocol.rs:320-377`). So applying the lemma to the *whole*
  view needs the joint law of (field messages **and** hash objects) at fixed
  `ρ`. Theorem 3.3 covers the first component; §5.2 is what is needed for the
  second, conditionally on the first.
* **The lemma's proof and its exhaustive tests live only on branch
  `zk60-mvp-fable`**, not in the main tree (privacy-case item 17). This memo
  uses it as stated and does not re-prove it.
* **Carve-out (i) survives unchanged**: a witness-*dependent* refusal breaks
  the conclusion, and there is exactly one (§5.4).

### 5.2 The hash layer: the one assumption, stated precisely

The hash objects are the three roots, the 5 × 256 published salts and the
5 × 256 authentication paths. They are *not* functions of the field view: the
paths carry sibling digests of leaves whose columns are never opened — about
**212.5** of them per 2,048-leaf tree, 40.4 % of the tree's nodes revealed
in all (privacy-case item 15).

> **(H6), the hash-layer assumption, in one statement.** Model the single
> untagged 64-byte BLAKE3 domain shared by `merkle::hash_pair`,
> `pcs::salt_leaf` and (on `absorb_u64`-shaped inputs)
> `Transcript::absorb` as one random oracle (M-1). Then, for every
> admissible witness and every non-refused `ρ`, the conditional law of
> (the three roots, the 5 × 256 authentication paths) **given** the field
> view and the published salts is the same fixed, witness-free function of
> (the opened column values, the published salts, and one independent
> uniform 32-byte value per never-opened leaf), except with probability at
> most `q·2^-256 + (collision terms)` against an adversary making `q` oracle
> queries.
>
> *Why that is the right statement and not more.* A leaf is
> `blake3(hash_column(col) ‖ salt)` (`pcs.rs:639-645`) with a fresh 32-byte
> salt per encoded column (`pcs.rs:674`); the salts of **unopened** columns
> are never transmitted (`pcs.rs:935-940`). In the ROM each such leaf is
> therefore a query on an input containing 256 bits the adversary does not
> have, so its answer is uniform and independent of everything else until the
> salt is guessed. Every node above is `hash_pair` of its children, hence a
> deterministic function of those uniform values and of the opened leaves,
> which are determined by the field view and the published salts. The roots
> and the 11/12 sibling digests on each path are such nodes. **PROVED HERE**
> as a derivation *inside* the model; the model itself is **ASSUMED** (M-1,
> M-2).

**Does the shared untagged domain matter to *this* step?** No, and the reason
should be recorded rather than waved at. The step needs only that a
`q`-query adversary cannot predict the image of a 64-byte input whose last 32
bytes it does not hold. A transcript absorption that lands in the same
64-byte domain — `absorb(b"log-cols", 8 bytes)` gives
`32 + 8 + 8 + 8 + 8 = 64` untagged bytes (`transcript.rs:44-52`;
`private_block/protocol.rs:41-45`) — is an extra query on an input the
adversary already knows, which does not help it guess a salt. The squeeze
function is a 47-byte input (`transcript.rs:85-94`) and so is outside the
node/leaf set entirely. Where the shared domain **does** matter is elsewhere
and stays open: composing this privacy argument in the ROM with the
*soundness* reduction over the same table (privacy-case item 16, condition
O-7), and any argument that **programs** the oracle — which under D18 none
here does (item 14). It also means `hash_column` on a commitment with exactly
8 rows would itself be a 64-byte input; none of `A` (455), `H` (384), `M`
(50) or the endpoints (7) is, but by arithmetic accident rather than by a
check (privacy-case item 16).

### 5.3 Why the known counterexample does not apply

The counterexample is `(H(mask), mask ⊕ w)`: two published values, each
uniform on its own, whose *joint* law determines `w`. The shape to hunt for
is **one blinding variable published in two places under different
encodings**. Here is every candidate in this protocol and what disposes of
it.

| # | the blinding variable | published where, twice | what disposes of it |
|---|---|---|---|
| 1 | the **CFS mask coefficients** `a_s` (B6) | in the masked rounds (`c_s·R_s(a_s)`) **and** in `M`'s `q` | Lemma 3.1: `q` reveals exactly one `Fp2` functional `V(a)`; §3.2: `V` factors through `R`, so it is *not a second, independent encoding*; and Fact 3.2: `V(a)` equals a public function of the already-published values. **This is the exact analogue of the counterexample and it is where the protocol could have failed** — see below |
| 2 | a **pad symbol** | in an opened column **and** in a group or proximity vector's pad half | the encoding identity `⟨E_j, v⟩ = Σ_i ρ[i]·col_j[i]` (`pcs.rs:1022-1031`) makes the pad half's values at the `d` distinct opened positions a function of the columns and the published message half; the residual `256 − d` coordinates are combinations of blinding only. The lemma's rank is computed over the whole generator system, so both are counted once — modulo the precision of §4.2 |
| 3 | a **reserved mask pair row** | in the masked terminal it hides **and** in the group vector that batches that claim | the block-triangular factorisation (lemma §3.2): the pair carries coefficients `(cm, cm·U)`, an `Fp`-basis of `Fp2`, no other claim touches it (`audit_claims`), and the minor's factor `Norm(λ·cm)` is exactly what the refusals keep non-zero |
| 4 | — (a shared **data** coordinate, not a blinding one) | the two endpoint planes are copies of `A[10], A[11], A[68], A[69]`, committed twice under independent blinding, and `SC_IO_IN`/`SC_IO_OUT` publish two terminals of the same values at the same `ρ` | Proposition 4.2: identifying data coordinates can only lower the joint disclosed dimension; the two terminals carry independent reserved pairs (§2.4) |
| 5 | the **zero-sum pair** `u` (B4), whose last entry is determined by the other 255 | inside `H`'s data block, and inside the LogUp sum claim | it is declared a mask row to the PCS (`protocol.rs:374`) and its disclosed contribution is exactly the 2-dimensional public identity of value `Fp2::ZERO` (Lemma 4.1(2)) |
| 6 | `A`'s 256 **published salts**, drawn from the same stream that later produces `H`'s pads | the receipt, and (secretly) `H`'s pads | **only** assumption M-3 in its two-sided, whole-stream form (ruling C-3). This is the one candidate with no structural answer |

**Row 1 deserves the emphasis.** Had `M` batched a Private slot's `Γ`
functional — whose value `G_s = (Γ_s − σ_s)/c_s` involves the *unpublished*
honest sum `σ_s` — then `V(a)` would not be a public function of the view,
the fibre argument in Theorem 3.3 would fail, and the joint law would become
witness-dependent **with every marginal still perfectly uniform**. Likewise
if one of the 34 weight vectors left `rowspace(R_s)` (lemma §3.5(b)), or if
two slots shared a mask. §7's toy enumeration exhibits all three failures.

### 5.4 Refusals, and conditioning on `NR(ρ)`

Everything above is conditioned on the prover not refusing. Three facts, all
taken from elsewhere:

* the challenge-driven refusals (`c_s = 0`; `e ∈ {0,1}`; a zero group
  coefficient; a dependent proximity pair; a zero batching challenge) are
  **functions of the transcript challenges alone**, replayed from a *cloned*
  prefix so the decision never advances the live transcript
  (`protocol.rs:157-176`, `argument.rs:274-277`, `:347-349`, `:493-494`);
  a refused attempt restarts with **fresh** pads, salts and masks, so the
  accepted transcript is uniform on the non-refused set;
* conditioning on non-refusal is free **only in the ROM** — the refusal event
  is a deterministic function of `(w, β)` once BLAKE3 is fixed, and what
  makes its *law* witness-independent is M-1 (privacy-case correction C-12;
  lemma §3.6 correction C-11). The rate is **2^-62.0 per proof** at either
  toy profile;
* **exactly one refusal is witness-dependent**: a zero LogUp denominator,
  `protocol.rs:231-234`, at **2^-112.0** (2^-117.4 counting distinct). It is
  carve-out (i) of the sequential-kernel lemma and it is an additive term,
  not a structural obstruction. The associated condition on the code — *a
  refusal string must not name a witness-dependent relation* — is
  privacy-case item 24's and is **not satisfied today** by the witness
  builder's 20 named sites (`witness.rs:79-96`).

> **Corollary 5.1 (the lift, stated with all its hypotheses).** Fix an
> admissible public statement. Under (H1)–(H5) of Theorem 3.3, (H6) of §5.2,
> the sequential-kernel lemma as stated on branch `zk60-mvp-fable`, and the
> random-oracle model M-1 for the conditioning of §5.4, the law of the whole
> view of one toy private-block proof — field messages, challenges, roots,
> salts and authentication paths — is the same for every admissible hidden
> input, up to: the `fp()` term (≤ 2^-77.7, D9), the LogUp collision event
> (2^-112.0), the PRG advantage against M-3, and the ROM/M-2 terms of (H6).
>
> **PROVED-CONDITIONAL**, on GAP G-1 (block diagonality), on Fact 3.2's
> completeness premise, on (H6)'s model, and on a lemma that is not in the
> main tree. **This is not a privacy acceptance** and must not be quoted as
> one; five of the six inputs are themselves labelled RELIES ON or ASSUMED.



## 6. What is NOT covered

Written so a status page can quote it without softening it.

1. **The hash layer, beyond the single statement (H6).** The three roots, the
   1,280 published salts and the 1,280 authentication paths are not field
   objects and nothing here is a rank, a sampler or a simulator for them.
   (H6) says what would have to be true of them; M-2 (salted-leaf and
   salted-*subtree* hiding) is an assumption, not implied by collision
   resistance. **D8/D11 — a root fixed by a third party — is untouched**, and
   under D18 it does not arise for this product today by the types
   (`private_seam.rs:142-161`), which is a statement about the product, not a
   theorem.
2. **Side channels.** Timing, memory and power are outside the model (M-5,
   awaiting an owner ruling). Refusals are **inside** the game (ruling C-2)
   and §5.4 covers their *law*; it does **not** cover the operational
   channel, and the condition *a refusal string must not name a
   witness-dependent relation* is **unmet today** — the witness builder names
   20 distinct failing relations (`witness.rs:79-96`).
3. **Many proofs, at the field layer only, and here is exactly what is
   assumed.** If `n` proofs draw mutually independent blinding — three fresh
   OS streams per proof (`protocol.rs:275`, `private_seam.rs:196` twice) and
   nothing derived from the witness — then each proof's field view is a
   function of `(w, β_i)` with `β_i` independent, so the joint law of the `n`
   field views is the product of `n` laws each witness-independent by Theorem
   3.3, hence witness-independent. **PROVED HERE, at the field layer, for any
   `n`**, conditional on Theorem 3.3 and on stream independence across proofs
   (computational, M-3). It does **not** cover the hash layer, it does not
   discharge condition O-5 (the measured evidence for two proofs, round 23),
   and history item H7 — a different commitment to the same plane — is
   covered only as a data-channel correlation at the field layer.
4. **Every other shape. The 125M profile and the development rung owe all of
   this again from the start** (ruling G-2), not as a re-check:
   `A_GROUPS` moves 35 → 36, so the certifying minor changes; the endpoints
   are re-tiled to 29 rows with three data parts per claim; a new refusal
   (the pad-zero challenge `ζ`) joins the inventory; and the `H` step of the
   generic-rank lemma is about a claim that **cannot be formed at all** until
   the lookup-summation repair (ruling P-3). The mask channel survives
   arithmetically — the worst `L` is 94 at 125M and 98 at 8B, both far below
   256 — but `n_base = 2·slots + 4` grows with the schedule and `M`'s
   geometry must be re-derived. **GAP.**
5. **Soundness, and the composition with it.** Nothing here is about
   soundness. Because the privacy argument of §5 lives in the ROM over the
   *same* untagged table the Fiat–Shamir soundness reduction uses, the two
   must eventually be composed over one table (condition O-7). **GAP.**
6. **Weight privacy.** This profile has no `W` commitment; P3 is untouched.
7. **Application-level side information** (H6 of the D8/D11 history) and
   condition **O-1**: if the 112-byte policy's context digest is a
   deterministic function of a low-entropy request, the digest *is* the
   request. That breaks the product promise, not the reduction, and no
   property proved here helps.
8. **Rejected-but-emitted receipts and retained captures** (privacy-case
   items 25 and 27). `finish` has no equality precheck, and the test-only
   capture writer publishes a receipt with its policy; both are procedural
   and outside this memo.
9. **The statistical residuals are unchanged and are not this memo's.** They
   are, with sizes: `fp()` ≤ **2^-77.7** per toy proof (D9); the LogUp
   collision at **2^-112.0** (2^-117.4 counting distinct); the refusal rate
   **2^-62.0** per proof (liveness, not distinguishing); the fallback
   generic-rank term **≈ 2^-56** over the base field *if* a structural step
   of the accepted lemma is rejected. There is **no privacy target in bits**
   (ruling C-1) and this memo does not propose one.



## 7. Evidence

Two exact-arithmetic scripts, under
`results/zk60_joint_law_composition/`, with their outputs beside them. **Both
are illustrations.** No witness value, salt or private plane from any capture
is used; every number they handle is generated inside the file. Neither
touches the Rust build, and neither proves anything about the real protocol:
the real field is `Fp2` with `|Fp2| = 2^128`, the real proof has 23 slots,
five commitments, 1,280 opened columns and adaptive challenges.

### 7.1 `mask_rank_identity.py` — the degrees-of-freedom count, re-derived

Over the prime field `2^31 − 1`, at the **23 real `(N_s, d_s)` shapes** of
the toy block and five `ρ` regimes (random, all-zero, all-one, all-equal,
small), building the round matrix from the closed form of
`sumcheck.rs:255-274`. Output: `mask_rank_identity.txt`.

* the layout arithmetic reproduces `Σ L_s = 583`, `Σ (n+ext) = 184`,
  `Σ (n+ext)(d+1) = 721`, `Σ dim C_s = 560`, `max L_s = 50 ≤ 256`;
* **`rank R_s = dim C_s = N_s d_s + 1` and `dim ker R_s = 1` on 115 of 115
  (slot, ρ) pairs** — Fact 2.1, independently recomputed;
* **`sum_weights` and `eval_weights` lie in `rowspace(R_s)` on 115 of 115** —
  the lemma's §3.5(b), independently recomputed;
* the closed-form round formula equals the brute-force partial sum of `g`
  over the hypercube on 80 of 80 checks, so the matrix analysed is the map
  the protocol applies;
* **the `a'` finding of §2.3**: dropping `a'` leaves the rank at `N d + 1` on
  115 of 115 pairs, so `a'` is a redundancy of the parametrisation;
* the `d+1`-values invariant (ruling G-3) is load-bearing: publishing only
  `d` values per round drops the rank by 1 to 12 depending on the shape and
  raises `dim ker R` to 2…13. This is the same verdict as the lemma's own
  control, not the same number (§2.3).

### 7.2 `toy_joint_law.py` — the sampler and the four load-bearing rules

A faithful miniature of **one slot** over `F_5`: one main variable, one
extension round, degree 2, one public and one private table, the CFS mask
with `L = N d + 2 = 6` uniform coefficients, the terminal mask `R`, the
published scalar `σ + c·G`, three published values per round, and the
verifier's derived `g_val = (fin − poly(terminals))·c^{-1}`. The prover's
**whole** randomness (6 coefficients and `R`) is enumerated —
`5^7 = 78,125` runs per witness per experiment, `5^8 = 390,625` for the
two-slot experiment — so the distributions are computed, not sampled. Three
witnesses with pairwise different sums *and* pairwise different multilinear
extensions at `ρ_0`. Output: `toy_joint_law.txt`.

| experiment | result |
|---|---|
| **A. honest** | the published view's law is **identical on all 3 witness pairs**, support 15,625 = `5^6` (= `dim C_s + 1` free `F_5` coordinates), and **uniform on its support** — the shape Lemma 2.2 predicts. The verifier chain equations and the identity `derived g_val == true g(ρ, e)` hold on all 78,125 × 3 runs |
| **B. the `c = 0` refusal dropped** | separates **3 of 3** pairs |
| **C. the mask's degree lowered by one**, so it no longer spans `C_s` (the distributional analogue of the `d+1` invariant) | separates **3 of 3** |
| **D. the terminal's blinding `R` published a second time through `M`** (`M` discloses `g_val + R` instead of `g_val`) | separates **3 of 3**, while every marginal is unchanged — **the counterexample shape, exhibited** |
| **E. a *Private* slot's `Γ` functional batched into `M`**, so `M`'s disclosed value stops being a public function of the view | separates **2 of 3** — exactly the two pairs whose true sums `σ` differ, which is the leak it is meant to exhibit (`σ = Γ − c·G`) |
| **F. two slots sharing one mask** | both **marginals identical**, **joint separates** — the counterexample shape again, and the distributional reason the "one reserved pair per claim site, one mask per slot" discipline is not decoration |

D and F are the two failures §5.3 has to rule out, and the memo rules them
out by Lemma 3.1 (`M` reveals one functional) and Fact 3.2 (that functional
is a public function of the view).

**Reproduce** (no build, no prover, a few seconds each):

```
python3 /home/victor/IntelligenceRegulation/results/zk60_joint_law_composition/mask_rank_identity.py
python3 /home/victor/IntelligenceRegulation/results/zk60_joint_law_composition/toy_joint_law.py
```



## 8. Open questions for the checker, most doubtful first

**Q1 — the completeness premise under Fact 3.2 is the load-bearing one, and
it is a premise in the code's own words.** The whole cancellation in Theorem
3.3 rests on `fin_s = poly_s(masked terminals) + c_s·g_s(ρ_full)` holding
**identically**, for every witness and every non-refused challenge, which
needs *"every slot polynomial has a public factor in every monomial, so
`poly(extensions) = 0`"* (`argument.rs:18-22`). The code says it is a
CONSTRUCTION PREMISE and that a violating term "would make honest proofs
fail, not leak". For *soundness* that is enough. For **this** memo it is not
obviously enough: the memo uses the identity as an algebraic fact about the
map, not as an observation about runs that happened to verify. Is a symbolic
per-slot check of `poly_s(extensions) = 0` owed — 23 closures, mechanically
checkable — before the label on Fact 3.2 can rise above RELIES ON?

**Q2 — block diagonality has no argument (GAP G-1).** Proposition 4.2 turns
the accepted lemma's four per-role ranks into the joint statement *only* if
no non-data coordinate class is shared between commitments. Today that is a
source reading plus a measurement on four captures. Two sub-questions: could
a future profile legitimately share a row (a common proximity row across the
two endpoints, say) and would anything fire? And is a Rust assertion the
right closure, or does the checker want the stronger statement that the
four commitments' non-data rows are drawn from disjoint stream segments —
which is what M-3 actually needs?

**Q3 — is Lemma 3.1's inventory of `M`'s published objects complete?** This
drafter read `mask_commit`, `mask_open` and the first lines of `mask_verify`
(`zk.rs:430-560`) and took `M-q`, `M-prox`, `M-cols` from the generic-rank
lemma. If `mask_verify` checks anything else about `q`, the proximity vector
or the columns — a degree bound, a second sum identity, a per-column
consistency that pins more than `b(x_j)` and `u(x_j)` — then "the opening
reveals exactly one `Fp2` functional of `a`" is wrong and Theorem 3.3's
(H3) fails. **This is the single source reading most worth redoing.**

**Q4 — the `a'` discrepancy (§2.3).** `sumcheck.rs:163-183` says `a'` is the
extra freedom that makes `G` and `g(ρ)` jointly uniform given the round
messages; the lemma's §3.5(a) makes `a'` the free parameter of a
one-dimensional kernel; this drafter's recomputation says dropping `a'`
leaves the rank unchanged at 115 of 115 shapes. Which reading is right, and
does the answer change anything about the mask's *design* (is `a'` needed for
something this memo has not modelled — the legacy profile, say, or a slot
with two extension rounds where the two extension challenges interact)?

**Q5 — the composition of Theorem 3.3 with (H6) into one sequential
argument.** §5.1 says the message sequence includes the roots and §5.2
supplies the hash part conditionally on the field part. The step from those
two to "the law of the whole view is witness-independent" is written here in
prose. Does the checker want it as a per-step kernel argument, with the
message at step `j` defined as the pair (field part, hash part)? And is the
sequential-kernel lemma, which lives only on branch `zk60-mvp-fable`, in a
state to carry it?

**Q6 — (H5) is false information-theoretically.** `A`, `M` and `H` come from
**one** BLAKE3 stream as disjoint consecutive segments, so `α`, `π` and `μ`
are independent only under M-3 (and `A`'s 256 salts are *published* before
`H`'s pads are drawn, which is why M-3 must be two-sided, ruling C-3).
Theorem 3.3 is stated with exact independence. The reduction — an adversary
distinguishing the two worlds yields a distinguisher against `ZkRng` — is not
written here. Is it wanted explicitly, or is the standard hybrid enough?

**Q7 — the pad-half determinacy prose (§4.2).** The lemma's disposition says
the pad halves are determined by the opened columns; indices are drawn with
replacement and the captures record 231–246 distinct, so `10…25` coordinates
of each published pad half are *not* determined by the columns. This drafter
believes the conclusion survives (the extra coordinates are blinding-only
combinations and the rank is computed over the whole generator system). Does
it?

**Q8 — conditioning on non-refusal, and the restart.** Theorem 3.3 is stated
at a fixed non-refused `ρ`. The claim that the *accepted* transcript is
uniform on the non-refused set needs a refused attempt to restart with fresh
pads, salts and masks; that restart is asserted (lemma §3.2 step 6, condition
O-5) and not modelled here. Does the restart also redraw the endpoint
commitments, and if not, does a second attempt on the same endpoints open
them twice?

**Q9 — the endpoint commitments were read at second hand.** Their geometry
(7 rows: 2 data, one reserved pair, three proximity rows of which the refusal
uses two) comes from the lemma and from `protocol.rs:184-203`, not from
`private_seam.rs`'s commit path. Does an endpoint terminal use the same
`(1−e)/e` extension mechanism, and does its single claim carry the pair the
same way?

**Q10 — is `V_pcs` really free of `α` and `μ`?** The split in §3.3 is read
off the algebra. A shared buffer, a reused NTT table with state, or a
GPU-path difference would not show up in that reading. Is there a mechanical
check?



## 9. The label table

Three labels, as the brief requires. **PROVED HERE** = a proof is written in
this document and is unconditional *given the rows it names*. **RELIES ON** =
a named, cited fact from the code or from another document, not re-derived
here. **GAP** = nobody has established it; the row says what would close it.
Where a PROVED HERE row stands on RELIES ON rows, it says so; a reader must
not read it as unconditional.

| # | statement | § | label |
|---|---|---|---|
| 1 | the inventory of published field messages and their exact forms | 1.3 | RELIES ON (a source reading at named lines) |
| 2 | the linear / nonlinear split of the view | 1.4 | PROVED HERE |
| 3 | the blinding families are uniform and mutually independent | 1.2 | RELIES ON (M-3, ruling C-3) + D9 for uniformity |
| 4 | `dim C_s = N_s d_s + 1` | 2.1 | PROVED HERE |
| 5 | `rank R_s = dim C_s`, `dim ker R_s = 1`, for every `ρ` (Fact 2.1) | 2.1 | RELIES ON `ZK60_GENERIC_RANK_LEMMA.md` §3.5(a) (which relies on `sumcheck.rs:148-150`); recomputed here at 115 (slot, ρ) pairs |
| 6 | the claimed-sum change of coordinates is triangular, hence invertible | 2.2 | PROVED HERE, on the host-order rule `layout.rs:716-723` [RELIES ON] |
| 7 | **Lemma 2.2**: the whole sumcheck channel is uniform on the public subspace `C` | 2.2 | PROVED HERE, on rows 3, 5, 6 |
| 8 | the DOF accounting: rounds consume `dim C_s`, columns 0, mask evaluation 0, mask total 0, `q` 0 additional, slack 0 | 2.3 | PROVED HERE, on rows 5 and 13 and on `M-cols` [RELIES ON] |
| 9 | `L_s + 256 ≤ 512` and `n_base = 2·slots + 4` are the same fact about `M`'s geometry | 2.3 | RELIES ON (`zk.rs:373-375`, `:434-447`; `layout.rs:519`, `:733-736`) |
| 10 | shared evaluation points never share a reserved pair; the consequence for the law | 2.4 | RELIES ON (`audit_claims`) + PROVED HERE for the consequence |
| 11 | **Lemma 3.1**: `M`'s opening depends on `a` only through `V(a)` | 3.1 | PROVED HERE, on the uniformity of `b`, `u`, `M`'s pads [RELIES ON] and `M-cols` [RELIES ON] |
| 12 | **Fact 3.2**: all 34 `M` functional values are public functions of the view | 3.2 | RELIES ON (the completeness premise `argument.rs:18-22`, plus the 82-equation capture check) — **see Q1** |
| 13 | `V` factors through `R` (`ker R ⊆ ker V`) | 3.2 | PROVED HERE, on the lemma's §3.5(b) [RELIES ON] |
| 14 | **Theorem 3.3**: the joint law of the field view at fixed non-refused `ρ` is witness-independent | 3.3 | PROVED HERE, on (H1)…(H5) = rows 3, 5, 11, 12, 13, 23 |
| 15 | **Corollary 3.4**: O1 exists and is perfect | 3.4 | PROVED HERE, on row 14 |
| 16 | integer-range side information (privacy-case item 20) is discharged at the field layer | 3.3 | PROVED HERE, conditional on row 14 |
| 17 | **Lemma 4.1**: `dim(F ∩ T) = 0` ⟺ the linear view's law is data-independent; and the general form | 4.1 | PROVED HERE |
| 18 | the matrix for the joint statement is the `100 × 358` joint non-data block | 4.2 | PROVED HERE (an identification, from the tool's reduction [RELIES ON]) |
| 19 | across slots *inside* one commitment is the same matrix, covered by the accepted lemma | 4.2 | RELIES ON (`ZK60_GENERIC_RANK_LEMMA.md` §3.2, ruling of 2026-09-20) |
| 20 | **Proposition 4.2**: block diagonality ⟹ joint rank = sum, so `k0_joint = 0` | 4.2 | PROVED HERE, given row 21 |
| 21 | **block diagonality** — no non-data coordinate class shared between commitments | 4.2 | **GAP** — a source reading (`pcs.rs:673-674`, item 22) plus four captures (`zk60-native-jointview` at `14b7d20`). Closure: a Rust invariant asserting disjointness |
| 22 | "the pad halves are determined by the opened columns" is exact only for distinct indices | 4.2 | **GAP (a precision)** — see Q7; the conclusion is believed to survive |
| 23 | **(H1)**: the four PCS commitments' field view has a witness-free law | 4.3 | PROVED HERE, on rows 17, 19, 20 and GAP 21, and on the lemma's own RELIES ON rows; **two toy layouts only** |
| 24 | **(H6)**: the conditional law of roots and paths given the field view is witness-free | 5.2 | ASSUMED (M-1, M-2); the derivation *inside* the model is PROVED HERE |
| 25 | the shared untagged 64-byte domain does not affect step (H6) | 5.2 | PROVED HERE (an argument about what the step needs) |
| 26 | the `(H(mask), mask ⊕ w)` counterexample does not apply: rows 1–5 of the table | 5.3 | PROVED HERE / RELIES ON per row; **row 6 (the shared RNG stream) is ASSUMED (M-3)** |
| 27 | conditioning on non-refusal is free, and the refusal channel carries no witness information except the LogUp collision | 5.4 | RELIES ON (lemma §3.6, correction C-11/C-12) + ASSUMED (M-1) |
| 28 | **Corollary 5.1**: the lift to the real protocol | 5.4 | PROVED-CONDITIONAL on rows 12, 14, 21, 24, and on a lemma that is only on branch `zk60-mvp-fable` |
| 29 | many proofs about the same or related inputs, at the field layer, for any `n` | 6.3 | PROVED HERE, conditional on row 14 and on cross-proof stream independence |
| 30 | the 125M profile and the development rung | 6.4 | **GAP** — owed again from the start (ruling G-2) |
| 31 | the hash layer beyond (H6); D8/D11; the ROM composition with soundness | 6.1, 6.5 | **GAP** |
| 32 | the toy enumerations | 7 | **ILLUSTRATION**, explicitly not evidence for the real statement |

**Tally, 32 rows.**

| label | count | rows |
|---|---:|---|
| **PROVED HERE** | 15 | 2, 4, 6, 7, 8, 11, 13, 14, 15, 16, 17, 18, 20, 25, 29 |
| **RELIES ON** (primary) | 7 | 1, 3, 5, 9, 12, 19, 27 |
| **mixed** (a PROVED HERE consequence on a RELIES ON / ASSUMED / GAP premise) | 5 | 10, 23, 24, 26, 28 |
| **GAP** | 4 | 21, 22, 30, 31 |
| **ILLUSTRATION** | 1 | 32 |

> **Exactly two PROVED HERE rows are unconditional**: row 4 (`dim C_s =
> N_s d_s + 1`) and row 17 (Lemma 4.1, the equivalence between "disclosed
> dimension zero" and witness-independence of a linear view). Every other
> PROVED HERE row — including Theorem 3.3 and the sampler — stands on at
> least one RELIES ON row, and Theorem 3.3 stands on a GAP (row 21).

**The four gaps, named.** (21) **block diagonality** — no blinding source
shared between commitments; a source reading plus four captures, no argument.
(22) **the pad-half determinacy precision** — the prose is exact only when all
256 sampled indices are distinct. (30) **every shape other than the two toy
layouts** — owed again from the start. (31) **the hash layer beyond (H6),
D8/D11, and the ROM composition with the soundness reduction over one table.**
Assumptions carried: **M-1** (one untagged oracle), **M-2** (salted-leaf and
salted-subtree hiding), **M-3** (whole-stream PRG, two-sided), and **D9**'s
accepted `fp()` residual.

> **Nothing in this document establishes a privacy property.** It is step 4
> of the five-step path in `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` §3,
> it has not been independently checked, and its central theorem's
> hypotheses include one GAP and four RELIES ON rows.



## Appendix A. The circularity check, step by step

Yesterday a delegated argument in this repository was refused because a
restriction restated its conclusion. The discipline is to ask of every step:
**what does this step assume that a later step concludes?** An entry in the
last column is a red flag. There are none; what there is instead is
conditionality, and §9 is where it is counted.

| step | what it assumes | which later step concludes that | circular? |
|---|---|---|---|
| §1.2 blinding families | M-3, D9 | nothing later; they are assumptions | no |
| §1.3 the message inventory | nothing | — | no |
| §1.4 the linear/nonlinear split | §1.3's forms | — | no |
| §2.1 `dim C_s` | nothing | — | no |
| §2.1 Fact 2.1 | the generic-rank lemma's §3.5(a), and through it `sumcheck.rs:148-150` | nothing here; the lemma is an input, already disposed of by the security owner | no |
| §2.2 Lemma 2.2 | Fact 2.1; `c_s ≠ 0`; uniform independent `a`; the host-order rule | Fact 2.1 is §2.1; the rest are code facts | no |
| §2.3 the DOF count | Fact 2.1, `M-cols`, §3.5(b), **and Lemma 3.1 for the "`q` consumes 0 additional" row** | **Lemma 3.1 is §3.1, which is *later*** | **no, but note it**: Lemma 3.1 does not use the DOF table, so the dependency runs one way only. The table is a summary, not a premise of anything |
| §2.4 hosts and shared points | `audit_claims`; the host-order assert | — | no |
| §3.1 Lemma 3.1 | uniformity of `b`, `u`, `M`'s pads; `M-cols` | none of these is concluded later | no |
| §3.2 Fact 3.2 | the completeness premise `argument.rs:18-22` | nothing later; it is Q1 | no |
| §3.2 `V` factors through `R` | the lemma's §3.5(b) | — | no |
| §3.3 Theorem 3.3 | (H1)…(H5) | **(H1) is §4**, which is *later in the document* but does not use Theorem 3.3 anywhere | **no** — §4 is self-contained: it uses Lemma 4.1, the accepted lemma, and block diagonality, none of which mentions §3 |
| §3.4 Corollary 3.4 | Theorem 3.3 | — | no |
| §3.3 item 20 discharged | Theorem 3.3 | — | no |
| §4.1 Lemma 4.1 | nothing | — | no |
| §4.2 the joint matrix | the tool's reduction `disclosed = 256 k0 + u-term` | nothing later; it is the lemma's row 14 [RELIES ON] | no |
| §4.2 Proposition 4.2 | block diagonality | **nothing concludes it** — it is GAP 21, declared | no; a gap, not a loop |
| §4.3 (H1) | Lemma 4.1, Proposition 4.2, the accepted lemma, `Fp2::ZERO` | — | no |
| §5.1 the lift's hypothesis | Theorem 3.3 | — | no |
| §5.2 (H6) | M-1, M-2 | nothing concludes an assumption | no |
| §5.3 the counterexample disposal | Lemma 3.1, Fact 3.2, the lemma's §3.2, Proposition 4.2, M-3 | all earlier or inputs | no |
| §5.4 conditioning | M-1; the lemma's §3.6; the restart | the restart is asserted in the lemma, not here — Q8 | no |
| §5.4 Corollary 5.1 | everything above plus the sequential-kernel lemma | — | no; it is correctly last |
| §6.3 many proofs | Theorem 3.3; cross-proof stream independence | — | no |

**The three shapes the privacy case's own check hunted for are absent here
too**: the joint hypothesis is never assumed and then concluded (Theorem 3.3
concludes it and uses only (H1)…(H5), none of which is the joint hypothesis);
"the view is witness-independent given the challenges" is never used to prove
witness-independence; "the pads are uniform given the view" appears nowhere —
§4.2's precision is about what the *columns determine*, and it is used only
to avoid double-counting, never to establish uniformity.

**The one thing to watch** is the shape §9's tally is pointed at: **thirteen
of the fifteen PROVED HERE rows stand on something that is not proved here.**
The rule this memo proposes for anyone quoting it: *no sentence may state
Theorem 3.3 or Corollary 3.4 without naming GAP 21 and the two toy layouts in
the same sentence.*

(draft complete)

