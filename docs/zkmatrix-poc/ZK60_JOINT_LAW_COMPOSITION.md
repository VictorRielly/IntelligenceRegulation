# The joint law of the field view (U-3b), and the nonlinear link between the two channels (item 21)

**Status: REVISED AFTER INDEPENDENT CHECK — the theorem's core is accepted
for the toy block, per `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md` (security
owner, 2026-09-20): at fixed challenges the prover does not refuse on, in the
uniform-blinding idealisation, the joint law of the published field values is
the same for every admissible hidden input. Blocking items B-1 … B-4, the
corrections and conditions of `ZK60_JOINT_LAW_COMPOSITION_CHECK.md` and
rulings J-1 … J-5 applied. NOT a privacy acceptance: the hash layer and every
other shape are gaps, and one step (the individual terminals) was supplied by
the check and has since been independently reviewed and corrected. Drafted by
a delegated Opus agent.**

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

**What is shown.** At fixed, non-refused challenges, **and in the
uniform-blinding idealisation**, the joint law of every field value a
private-block receipt publishes is the same for every hidden input the
constructors admit — *provided* five named inputs hold, of which **only two
((H2) and (H5)) are accepted elsewhere**: (H1) is this memo's own §4, (H3) is
proved here, and (H4) rests on a construction premise that the independent
check settled by reading (correction C-8). The argument has a concrete form:
an algorithm, written out in §3.4, that samples the whole field view from
public data alone, with exactly the honest prover's distribution in that
idealisation. The earlier drafts called that object **O1** and said it did not
exist. It does — **conditionally on (H1)–(H5), and for the field view only**
(§3.5) — and its θ-batching step is corrected here per blocking item B-1.

**What the argument turns on.** One identity does almost all the work. The
mask commitment `M` — the one place where the blinding of the 23 sumchecks is
published a second time — reveals exactly one field value beyond what is
already public, and that value is *computed by the verifier* from the rounds
and the terminals it already has. So the blinding variable that appears in two
places is not, in fact, published twice: the second publication is a function
of the first. That is why the counterexample does not apply, and it is the
answer to the question the project has been calling "the nonlinear link"
(item 21), because the function in question is the degree-≤4 slot polynomial.

**What it rests on.** (i) The generic-rank lemma, whose **core** was accepted
2026-09-20 for the two toy layouts — the draft of that lemma was explicitly
*not* accepted as written and went back for an errata pass (correction C-9) —
for the commitment side. (ii) **Cross-role blinding independence**: no
blinding source is shared between two commitments. The independent check
settled this family by family by reading (its A5.1), and showed that the
block-diagonality statement earlier drafts leaned on is not the hypothesis
the joint statement needs (its A5.2); independence is computational (M-3) for
the three commitments that share one BLAKE3 stream and information-theoretic
for the two endpoints. (iii) The mask channel's two identities from that
lemma's §3.5 — one of which (Fact 2.1) the check proved outright (§2.1).
(iv) The standard assumption that the prover's BLAKE3 stream is
indistinguishable from uniform. (v) For the lift to real challenges, the
random-oracle model for one untagged hash table, and salted-leaf hiding for
the part of the Merkle tree that is never opened. (vi) **One step supplied by
the independent check and since independently reviewed and corrected**: the
per-group surjection that makes the 173 individual terminals safe (§4.3,
ruling J-2 as resolved 2026-09-20, `ZK60_TERMINAL_SURJECTION_REVIEW.md`).

**What is still missing.** Three things, and they are named in §6 and §8.
The hash layer is not covered by anything here — this memo is about field
values, and the roots and authentication paths are not field values; it
**remains a gap**, and what is owed under it is (H6) written as one
random-oracle lemma with its query budget, and the sequential lift composed
with it into a single argument (§5.2, condition O-4). The 125M profile and
the development rung owe the whole argument again from the start. And the
step from "the law is the same for each fixed challenge vector" to "the law
is the same when the challenges are hashes of the messages" is the
sequential-kernel lemma, whose hypothesis this memo is written to discharge —
for the field messages only, which is all that lemma ever asked for, but the
lemma itself lives on a branch and not in the main tree.

**What must not be read into it.** Nothing here establishes a privacy
property. It is one of the five steps of the path in
`ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` §3 (step 4). It **has** now been
independently checked (`ZK60_JOINT_LAW_COMPOSITION_CHECK.md`) and the
theorem's core accepted by the security owner
(`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`) — but the acceptance is of the
core in the uniform-blinding idealisation, not of a privacy property; its
central theorem is stated with hypotheses one of which is an assumption
((H5): M-3, D9) and one of which ((H1)) stands on the accepted lemma's own
"relies on" rows; and one step of the argument was supplied by the check
itself and has since been independently reviewed and corrected
(`ZK60_TERMINAL_SURJECTION_REVIEW.md`, 2026-09-20). A checker should start at
§8, whose first item is what that review left open about that step.



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
  ruling C-3), and "uniform" carries the `fp()` residual of D9. **Correction
  C-11: this is not uniform across the five families.** `A`, `M` and `H`
  (B1–B8) are three disjoint segments of **one** stream
  (`protocol.rs:275` then `:313, 316, 324, 361, 373`), so for those the
  independence is computational; the two endpoints (B9) are built by
  `private_seam::prepare` from **their own** `ZkRng::from_os`
  (`private_seam.rs:196`), so their independence of the block's stream is
  **information-theoretic**, not an M-3 consequence.
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

**The declared order of the 34 `M` functionals (correction C-1).** The
functionals that `M` batches are pushed **interleaved, per slot in schedule
order** — a Standalone slot's `Γ` functional immediately before that slot's
own `eval` functional — with the six Host `Γ`s appended **last**
(`private_block/argument.rs:361-376`, `:924-925`). That order is public data
and is part of what any sampler of the field view needs (§3.1, §3.4 step 3);
a layout change must not reorder it silently.

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
> **PROVED (unconditional), over any field of odd characteristic.** The proof
> below is the independent check's (its A3.2), reproduced here with credit;
> the draft's earlier label **RELIES ON** `ZK60_GENERIC_RANK_LEMMA.md`
> §3.5(a) is withdrawn — the fact does not need the lemma. Fix any `ρ`.
>
> 1. `Im R_s ⊆ C_s`: the mask's own round messages are an honest sumcheck of
>    `g_s`, so `r_0(0) + r_0(1) = G_s` and `r_j(0) + r_j(1) =
>    interpolate_eval(r_{j-1}, ρ_{j-1})`. (The Rust test
>    `cfs_mask_rounds_match_brute_force`, `sumcheck.rs:363-365`, asserts
>    exactly these two equalities.)
> 2. `R_s` restricted to `{a′ = 0}` is **injective**. Suppose `R_s(a) = 0`
>    with `a′ = 0`. Round `j`'s message is `2^{N-1-j}(base_j + u_j(X))`, a
>    polynomial of degree `≤ d` in `X` vanishing at the `d+1` nodes `0..d`,
>    hence identically zero; `u_j(0) = 0` forces `base_j = 0` and `u_j ≡ 0`,
>    i.e. every `a_{j,e} = 0`; then `base_0 = a_0 = 0`. So `a = 0`.
> 3. Hence `rank R_s ≥ L_s − 1 = N_s d_s + 1 = dim C_s ≥ rank R_s`, so
>    **`Im R_s = C_s` and `dim ker R_s = 1`, for every `ρ`**. ∎
>
> The kernel is explicit: `a′ = 1`, `a_{j,1} = −2^{j+1−N} ∏_{i<j} ρ_i`,
> `a_{j,e≥2} = 0`, `a_0 = −½ Σ_{i>0} a_{i,1}`. The `d+1`-published-values
> invariant (`sumcheck.rs:148-150`, ruling G-3) is exactly what step 2
> consumes, so it keeps its load-bearing status — for **this** reason, and
> not for the reason §7.1's RESULT 4 gave (correction C-2). The image
> identification uses in addition `G_s = Σ_x g_s(x) = r_0(0)+r_0(1)` of the
> mask's own rounds (`sum_weights`, `sumcheck.rs:222-227`), so `G_s` is a
> coordinate of `R_s(a_s)` rather than an extra output.
>
> The recomputations are now confirmations rather than supports: this
> drafter's 115 (slot, ρ) pairs over a prime field (§7.1,
> `mask_rank_identity.py`), and the check's independent 276 (slot, ρ) pairs
> over two fields, with the closed-form round map validated against genuine
> brute force (`results/zk60_joint_law_composition_check/check_mask_dof.txt`).
> **Condition O-3 of the independent check**: `ZK60_GENERIC_RANK_LEMMA.md`
> §3.5(a) should likewise carry this as a proved identity rather than a
> sampled rank.

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
> **PROVED HERE**, given Fact 2.1 [now **PROVED**, §2.1], `c_s ≠ 0` [RELIES
> ON `argument.rs:274-277`], and uniform independent `a` [RELIES ON M-3, D9].

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
challenges.** `Im(R_s) = C_s` holds for every `ρ`, by the proof of Fact 2.1
in §2.1; the captures confirm it but do not carry it.

**The table itself is a mnemonic, not a theorem — ruling J-5 demotes it to
ILLUSTRATION** (the check's A3.5). Its four "consumed 0" rows live in four
different spaces — `M`'s pads, the mask coefficients, `rowspace(R_s)`, the
`b`/`u` rows — and nothing in the proof of Theorem 3.3 ever adds them up. The
substantive content is Fact 2.1 (§2.1), Lemma 3.1 (§3.1) and the factoring of
`V` through `R` (§3.2), all of which stand. What the check did settle, on the
question the table was written to answer, is that there is **no double
count**: `q`'s law given `a` does not depend on `M`'s pads, because the
weight vectors vanish on the 256 pad positions (`zk.rs:476-481`), so `q` and
the a-columns are conditionally independent given `a` and each is counted
once.

**The `a'` discrepancy, resolved (was open question Q4; correction C-10).**
The code's own comment says `a'` is *"the extra freedom that makes the total
`G` AND the terminal `g(rho)` jointly uniform given the round messages"*
(`sumcheck.rs:163-183`). **That comment is wrong about what the extra
coefficient is for.** `G` *is* `r_0(0) + r_0(1)` of the mask's own rounds and
`g(ρ)` *is* the chain's terminal value, so both are **determined** by the
mask's round messages; no coefficient can make a determined quantity uniform.
Correspondingly `sum_weights` and `eval_weights` lie in `rowspace(R_s)` —
recomputed here on 115 of 115 (slot, ρ) pairs and independently by the check
on 276 of 276. The comment is **harmless**: `dim ker R_s = 1` and no
coefficient is special, so **nothing in the code changes because of it**
(security owner's disposition, 2026-09-20).

Two things this draft had over-personalised, corrected per C-10. First, the
content is "**the kernel is one-dimensional**", not "`a'` is special": any
coordinate on which the kernel vector is non-zero can be deleted without
changing the image, and the check's control shows `a_0` is equally droppable
at 5 of the 6 `ρ` regimes it tried — it fails only in the all-zero regime,
where the kernel's `a_0` component vanishes. (Dropping `a'` itself leaves the
rank at `N d + 1` on 115 of 115 pairs here, and on 138 of 138 per field in
the check.) Second, whether the cited CFS/Libra literature needs that
coefficient for a statement **this profile does not use** is **NOT
VERIFIED** — the check could not verify it either. Removing `a'` would be a
protocol change and a byte-changing re-freeze, and nothing here recommends
it: fix the comment, leave the coefficient. Nothing in this memo depends on
the coefficient either way, because §2.2 uses only `Im(R_s) ⊇ C_s`.

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
zero-check. **Correction C-14**: the assertion `n*d + 2 + 256 <= 512` for
every slot at `layout.rs:733-736` is inside `mod tests` (from `:695`) and is
therefore **test-only**; the load-bearing runtime assert is the one displayed
above, `zk.rs:442`, which fires inside `mask_commit` on the shipped path.
This draft cited the test as if it were an invariant of that path.
And `n_base = 2·masks.len() + 4 = 2·23 + 4 = 50` rows
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
(`argument.rs:262-264`). Without `hosted(s) ⊂ {0..s-1}` the change of
coordinates `T ↦ T'` need not be triangular, and the mask map need not be
written as a direct sum in those coordinates.

**Correction C-6: "Lemma 2.2 is exactly where that rule earns its keep"
overstated it, and is withdrawn.** What the proof uses is that `T ↦ T'` is
**invertible**; triangularity is a convenient sufficient condition, not the
property the proof needs. The check's control G6 puts a hosted slot *before*
its host with `κ_0κ_1 ≠ 1` and the law does **not** separate — any invertible
claimed-sum change of coordinates preserves "uniform on `C`" — while at
`κ_0κ_1 = 1` the scalar system `M(Γ_0, Γ_1) = (A_0, A_1)` is singular and for
a generic witness **no honest prover exists at all** (control G6′, §7.3). So
what the ordering rule buys is that the claimed-sum map is implementable and
invertible, and a cycle's failure mode is a completeness failure, not a leak.
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

**The index order `i` is the declared one, and it is interleaved
(correction C-1).** `argument.rs:361-376` pushes, per slot in schedule order,
a Standalone slot's `Γ` functional *then* that slot's `eval` functional,
sending a Host slot's `Γ` to a separate list; `argument.rs:924-925` appends
the six host `Γ`s at the end. So

```
[ (Γ_s if s standalone) , eval_s ]  for s = 0..22 , interleaved
++ [ Γ_s for the six hosts, in slot order ]
```

is the order in which `θ` batches them. The draft wrote three concatenated
blocks, which is wrong; §3.4 step 3 is corrected accordingly.

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
> **PROVED HERE, now on M-3 only** (ruling J-5 promotes row 11 in part),
> given: uniformity and mutual independence of `b`, `u` and `M`'s pads
> [RELIES ON `zk.rs:443-457` and M-3]; and `M-cols`, which the independent
> check **proves** rather than relies on (its A3.5): the pad block at the
> `d ≤ 256` distinct sampled positions factors as
> `diag((x_j^m−1)/m) · Cauchy(x_j; ω^{t_k}) · diag(ω^{t_k})`, of rank
> `min(d, 256)` for distinct `x_j` off the subgroup, and the same
> factorisation gives `H-pad` for the four PCS commitments. The generic-rank
> lemma's §3.4 remains the prior statement of the same fact.

**The inventory is complete — open question Q3 is closed.** This drafter had
read only `mask_commit`, `mask_open` and the first lines of `mask_verify`.
The check re-read `mask_verify` end to end — it is `hashline/src/zk.rs:552-590`,
**not** in `sumcheck.rs` — and its complete list of checks is: `q.len() == 2m`
(`:558`); `512·(q[0] + q[512]) == v` with `v` the θ-batched *declared*
functional values the verifier computes itself (`:560-561`); absorb `q`, draw
the `2S+2 = 48` proximity coefficients (`:562-563`); `prox.len() == 2m`,
absorb `prox`, draw the 256 indices (`:564-566`); and per opened column the
index match, `col.len() == 50`, the Merkle path, and the two identities
`b(x_j) + Σ_s a_s(x_j)·W_s(x_j) == q(x_j)` and
`u(x_j) + Σ_row r_row·row(x_j) == prox(x_j)` (`:573-588`). **Nothing else** —
no degree bound on `q` beyond its 1,024 transmitted coefficients, no second
sum identity, no per-column check pinning more than the `b` and `u` entries.
Row 1 of the label table (the inventory of published field messages) is
promoted to VERIFIED IN THE CODE on that reading, with the θ-order correction
above.

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
> **VERIFIED IN THE CODE for the 23 toy-block closures** (ruling J-5 promotes
> this row); **RELIES ON for every other schedule.** The identity needs
> completeness of the masked sumcheck with extension rounds — the honest
> `fin_s` really equals `poly_s(masked terminals) + c_s·g_s(ρ_full)` — and
> that needs the CONSTRUCTION PREMISE *"every slot polynomial has a public
> factor in every monomial, so `poly(extensions) = 0`"*
> (`argument.rs:18-22`, stated there as a premise). **The independent check
> settled the premise by reading all 23 closures** (`argument.rs:543-911`),
> and found exactly two mechanisms: in 21 slots (SC_SS, SC_SSM, SC_TZC,
> SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM,
> SC_DZC, SC_FZC, SC_QZC, SC_KVZC, SC_SZC, SC_TAB, SC_ZS, SC_IO_IN,
> SC_IO_OUT) every monomial carries an `eq` or public table as a factor,
> which is `0` in `exts`; in the two softmax slots (SC_SCORE, SC_PV) the two
> private factors are extended in **different** rounds (`ext_round` 0 and 1,
> `:649, 652` and `:662, 665`), so one of them is `0` in each round's `exts`.
> The numerical confirmation of the same identity on all 82 slot equations of
> the four captures with two negative controls (privacy case item 13,
> `ZK60_NATIVE_JOINT_VIEW.md` §11) stands as a second and weaker support.
>
> Two consequences the draft did not draw. The identity is **structural and
> witness-independent** — a statement about which table slots can be non-zero
> in `exts`, not about values — which is exactly the form Theorem 3.3 needs,
> because its proof requires `T′(w, π) ∈ C` for **every** `π`, not only for
> the `π` that arise on runs that verified. And **no symbolic check and no
> Python port is owed**: the port `scripts/zk60_native_terminal_polys.py` is
> itself an unverified transcription, so a check run through it would be
> weaker evidence than this reading. **Condition O-1 of the independent
> check** is what is owed
> instead: a Rust test that, for each slot, evaluates `def.poly` on a vector
> supported on that extension round's private tables and asserts zero, so the
> reading cannot rot at the next schedule edit.

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
  functional `V̂` on `C` with `V(a) = V̂(R(a))`. **PROVED** (ruling J-5
  promotes this row): it follows from the same argument that proves Fact 2.1
  in §2.1 — the kernel of `R_s` is the explicit one-dimensional line, and
  `sum_weights` and `eval_weights` annihilate it — and it is recomputed on
  276 of 276 (slot, ρ) pairs by the check and 115 of 115 here. This is used
  in the next proof and is not the same statement as Fact 3.2.

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

**`V_sc` is not a product across roles (correction C-12).** One extension
round mixes reserved-pair evaluations from `A`, `H` and an endpoint inside a
single slot (SC_DZC, SC_IO_IN, SC_IO_OUT), so the per-role factorisation of
§4.2 covers `V_pcs` **only**. That is why (H1) is stated for `V_pcs` rather
than for the whole view, and why the theorem below conditions on the whole of
`π` instead of splitting it by role.

> **Theorem 3.3 (the joint law at fixed challenges, in the uniform-blinding
> idealisation).** Fix an admissible public statement and a challenge vector
> `ρ` with `NR(ρ)`. Assume
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
> `(V_sc, V_pcs, V_M)` is the same — an exact equality of laws **in the
> uniform-blinding idealisation of (H5)** — and it is given explicitly by
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
> **PROVED HERE, in the uniform-blinding idealisation**, on hypotheses (H1)
> [§4: mixed — from the accepted lemma's core, the cross-role blinding
> independence the check settled by reading, and the terminals step the check
> supplied], (H2) [now **PROVED**, §2.1], (H3) [PROVED HERE on M-3], (H4)
> [**VERIFIED IN THE CODE** for the 23 toy-block closures, §3.2], (H5)
> [ASSUMED: M-3, D9].
>
> **Remark — the real prover (blocking item B-3, ruling J-3).** The equality
> above is exact only in the idealisation where the prover's blinding is
> uniform and independent, which is (H5). Stated once here, and not repeated
> elsewhere in this memo: against the **real** prover the two laws are within
> **2^-77.7** in statistical distance for one toy-block proof — the sampler
> residual of decision **D9, accepted**: 327,052 `fp()` draws at exactly
> `2^-96` each — and beyond that they are indistinguishable only up to the
> advantage against the **named generator**, the keyed BLAKE3 stream with a
> counter (`zkp-core/src/rng.rs`), i.e. assumption M-3 in its two-sided
> whole-stream form. Every later use of "perfect" or "exactly" in this memo
> carries this idealisation.

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
    values ← [ ]                          THE DECLARED ORDER, INTERLEAVED:
    for s = 0 .. 22, in schedule order:
      if s is Standalone: push Γ_s          (a Standalone's Γ functional
      push g_val_s                           immediately before that slot's
                                             own eval functional)
    for each Host slot s, in slot order:
      push Γ_s                              (the six host Γs, appended last)
    V ← Σ_i θ^i · values_i
    -- argument.rs:361-376 for the interleaved part, :924-925 for the hosts

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

**The functional order is part of the public data O1 needs (blocking item
B-1, ruling J-1).** The draft printed step 3 as three concatenated blocks,
`[Γ_s for standalone s] ++ [g_val_s for all s] ++ [Γ_s for host s]`. The
first two are **not** concatenated, they are interleaved, as above
(`private_block/argument.rs:361-376`, `:924-925`). As printed, the sampler
computed the wrong `θ`-batch and therefore sampled `q` on the wrong coset.
Theorem 3.3 is untouched — it never fixes an order — but the algorithm was
wrong, and the order is hereby recorded as **part of the public data the
sampler needs**, on the same footing as the layout, `ρ` and the 34 weight
vectors. A layout change must not reorder the functionals silently: the
sampler and `combined_weights` have to move together.

> **Corollary 3.4.** Under the hypotheses of Theorem 3.3, and **in the
> uniform-blinding idealisation**, `O1(statement, layout, ρ)` outputs a
> sample whose law is **exactly** the honest prover's field view at
> challenges `ρ`, for every admissible hidden input.
> **PROVED HERE** — it is the explicit law of Theorem 3.3 read as an
> algorithm: step 1 samples `Uniform(C)` (the free-coordinate
> parametrisation is a bijection onto `C` by the same count as §2.1), step 2
> samples `P_pcs` (legitimate because (H1) says the law is the same for
> every data rectangle, **including the all-zero one**; that the 173
> individual terminals it reads off are themselves uniform given the rest is
> the step imported in §4.3, supplied by the independent check), step 3
> evaluates `V_pub` **in the declared order**, step 4 samples `Φ(· ; V)`
> (Lemma 3.1's four bullets).

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
    resamples: a refusal is terminal for that statement and those endpoints
    (§5.4, blocking item B-4);
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
>
> **This identification is demoted to an illustration and is unnecessary
> (ruling J-5, row 18).** The independent check showed that the joint
> statement does not need this matrix at all (its A5.2, imported as
> Proposition 4.2′ below): mutual independence of the roles' blinding gives
> the product law directly. The block is kept here only to show what the
> earlier route would have had to prove.

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
`:139-152`.] **One thing that reduction does *not* cover** is the 173
individual terminals: its generators are only the `2(G+1)` real and
imaginary parts of the group and proximity combinations, and each terminal is
published separately rather than as a `λ`-combination. That is blocking item
B-2, and the step that fills it is imported in §4.3.

**(b) "Across commitments" follows from the roles' blinding being
independent — not from a joint rank.**

> **Proposition 4.2′ (the product law).** **Supplied by the independent
> check (its A5.2)**, and adopted here as the route the joint statement
> actually takes. Each role `r ∈ {A, H, In, Out}` publishes objects that are
> a function of the shared data `d` and of that role's **own** blinding
> `β_r`, and the `β_r` are mutually independent. Then
>
> ```
> law(V_A, V_H, V_In, V_Out | d) = ⊗_r law(φ_r(d, β_r)) = ⊗_r P_r ,
> ```
>
> so the four **per-role** witness-free statements give the joint one
> directly: no rank computation, no block-diagonality lemma, and nothing
> that has to be said about shared **data** coordinates. The endpoint
> question then answers itself: the two endpoint planes commit the same
> hidden values as `A[10], A[11], A[68], A[69]` under independent pads, and
> since `law(φ_A(d, β_A))` is data-free for *every* `d` and `β_A ⊥ β_E`, the
> pair (`A`'s view, the endpoint's view) is jointly data-free. The two IO
> terminals being evaluations of the same plane at the same point is
> likewise harmless: they carry independent reserved pairs, one in each
> commitment. The hypothesis it needs — cross-role blinding independence —
> is settled by reading immediately below.

The draft's own route is kept for the record and is **superseded** (ruling
J-5, row 20):

> **Proposition 4.2 (superseded by 4.2′).** If no non-data coordinate class contains rows of two
> different roles ("block diagonality"), then the joint non-data block is
> block diagonal by role, so its rank is the sum of the four per-role ranks;
> by the accepted lemma each equals `2(G_r+1)`, so the joint rank is
> `100 = g_joint`, hence `k0_joint = 0`, hence the joint disclosed dimension
> is the `u`-row term alone, `2 Fp`, with the public value `0`.
> Identifying **data** coordinates across roles can only *lower* the joint
> disclosed dimension (it merges two columns into their sum, which can only
> shrink `F ∩ T`), so the endpoint identification is harmless.
> **PROVED HERE**, given block diagonality — but **superseded**, and §9 row
> 20 labels it ILLUSTRATION accordingly: Proposition 4.2′ reaches the same
> conclusion without the rank and without that hypothesis.

**Cross-role blinding independence, settled family by family by reading
(ruling J-5 restates this row and promotes it; the draft's GAP G-1 is closed
in this form).** The hypothesis the argument needs is not block diagonality
of a matrix but this: *no blinding variable enters two commitments.* The
independent check read every family and where it is drawn (its A5.1):

| family | drawn where | enters |
|---|---|---|
| `A`'s 242 non-data rows (120 reserved pairs + the proximity pair) | `protocol.rs:313-315` | `A` only |
| `A`'s 455 × 256 pads and 2,048 salts | `pcs.rs:673-674` inside `commit_zk_owned` (`protocol.rs:316`) | `A` only |
| the 23 CFS coefficient vectors, `M`'s 46 × 256 pads, `b_re/b_im/u_re/u_im`, `M`'s 4,096 salts | `zk.rs:434, 445, 452-457, 462` inside `mask_commit` (`protocol.rs:324`) | `M` only |
| `H`'s 104 non-data rows | `protocol.rs:361-363` | `H` only |
| `H`'s zero-sum pair `u` | `protocol.rs:364-372` | `H` only |
| `H`'s 384 × 256 pads and salts | `commit_zk_owned` (`protocol.rs:373`) | `H` only |
| each endpoint's 5 non-data rows, 7 × 256 pads, salts | `private_seam.rs:196, 211-217` — its **own** `ZkRng::from_os` | that endpoint only |

Every write to `a_data` and `h_data` (`protocol.rs:282-316`, `:336-373`) was
grepped: nothing is copied from one commitment's blinding into another's, no
blinding value is read back, and `commit_zk_owned_with` draws `pads` then
`salts` from the passed rng and nothing else (`pcs.rs:673-674`). So the
hypothesis holds for the toy block **by reading**: computational under M-3
for `A`, `M` and `H`, which are consecutive disjoint segments of one stream,
and **information-theoretic** for the two endpoints. **VERIFIED IN THE CODE
for the toy block — and still not machine-asserted**, which is **condition
O-2 of the independent check**: a Rust assertion (or a stream-segment
accounting test) that no
blinding value enters two commitments. What remains is that guard, not an
argument.

*The measurement, quoted with its blind spot (correction C-3).* The repaired
stage 4 of the joint-view gate (`zk60-native-jointview` at `14b7d20`,
`ZK60_NATIVE_JOINT_VIEW.md` §12) builds one generator system over the union
of a receipt's commitments, reports **0 shared non-data classes** and **4
shared data classes** (the two endpoint planes, which are `A[10], A[11],
A[68], A[69]`), and computes joint `4` = sum `4` on all four captures, with a
control that shares a blinding row across two commitments and moves the joint
from 4 to 260. **That control has a recorded blind spot**
(`ZK60_NATIVE_JOINT_VIEW.md` §12.5): the joint rank sees a shared blinding
row only at a *tight* position — a singleton opening group's pair, two
generators against exactly two columns. `A` has 17 singleton groups out of 35
and `H` 2 out of 9, so a sharing at a slack position would change no rank at
all. The draft quoted the control without the blind spot; the source reading
above, and not the control, is what carries the hypothesis.

**A precision on the pad step, resolved (was open question Q7).** The lemma's
disposition says "the pad halves of the group and proximity vectors are
determined by those columns, so nothing is counted twice". Read literally
that is exact only when all 256 sampled indices are distinct. The indices are
drawn **with replacement** (`transcript.rs:118-131`; `pcs.rs:1193` says so in
a test comment) and the captures record `d = 231…246` distinct, so only a
`d`-dimensional projection of each published pad half is pinned by the
columns; the remaining `256 − d ≈ 10…25` coordinates are published
independently. **The check confirmed the reading** (its row 22): those
undetermined coordinates are supported on **pad** coordinates only, so they
carry no data coordinate and cannot by themselves put a functional into
`F ∩ T`; the lemma's own rank is computed over the full generator system.
The prose overstated, the conclusion stands, and this is a correction of the
prose rather than a gap. The correctness of the reduction
`disclosed = 256·k0 + (the u-row term)` **as a whole** is unchanged and
remains one of the **generic-rank lemma's** RELIES ON rows, not this memo's.

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

**The 173 individual terminals — a step the argument needs that was in
neither document (blocking item B-2, ruling J-2).** The receipt publishes
each claim's terminal separately. Those terminals are inside the accepted
lemma's functional space, but they are **not** among the generators of its
reduction (`_p1_rows` holds only the `2(G+1)` real and imaginary parts of the
group and proximity combinations), and they are not in the span of those: a
group vector gives only the `λ`-combination `Σ_c λ_c value_c`, whereas the
receipt publishes each `value_c`. So the sampler's step 2, which reads the
terminals off the all-zero rectangle, was unjustified in both documents. The
independent check supplied the missing step; the independent review of
2026-09-20 (`ZK60_TERMINAL_SURJECTION_REVIEW.md`) found it correct in its
conclusion but wrong in the conditions it named and too weak in the form it
was stated, and corrected it. It enters here in that corrected form, with its
provenance stated.

> **The per-group surjection, in the corrected form.** Fix one opening group
> `g` with member claims `c = 1..m`, shared column weights `cw`, and each
> claim's own reserved pair contributing
> `P_c := msg_{r_c} + U·msg_{r_c+1} ∈ Fp2^{256}`, uniform and independent
> across claims (`audit_claims` gives one pair per claim, used by no other
> claim). The published objects that touch those pairs are the group vector's
> message half `v = D + Σ_c λ_c cm_c P_c` and the `m` terminals
> `y_c = d_c + cm_c⟨P_c, cw⟩`, and the verifier's own check forces
> `⟨v, cw⟩ = Σ_c λ_c y_c`. Then the blinding map `(P_c)_c ↦ (v, y_1..y_m)`
> is **onto** that consistency subspace — **jointly** in the group vector and
> all `m` terminals at once, which is the statement that is needed, and not
> the per-claim marginal one — under the conditions restated next. So the
> individual terminals add **exactly nothing** beyond the group vector and
> that one public identity.
>
> **The conditions, restated (change R-1 of the review).** (i) Each claim's
> reserved pair carries the two weights **exactly `(cm_c, cm_c·U)`** — an
> `Fp`-basis of `Fp2`, which is what makes `P_c` range over the whole of
> `Fp2^{256}` — with `cm_c ≠ 0` (`build_claim`,
> `private_block/argument.rs:232-234`). **This shape, and not `cm_c ≠ 0`
> alone, is the condition that carries the conclusion**: with `cm_c ≠ 0` but
> the pair's two weights `Fp`-dependent a **singleton** group discloses
> **256 `Fp`**, and with the pair removed altogether **512 `Fp`**
> (recomputed by the review, its controls A3 and A4). `cm_c ≠ 0` is what the
> code refuses on, and it is refused twice over on **both** sides: the
> degenerate extension-challenge refusal (`argument.rs:346-349`, inside
> `run_slot`, the same function on `Side::Prove` and `Side::Verify`, reached
> from `prove_inner` `protocol.rs:384` and `verify_inner` `:450`) and the
> zero-coefficient refusal of `audit_claims` (`protocol.rs:103-108`, called
> through `check_opening` from the prover at `protocol.rs:396, :399` and from
> the verifier at `:458, :464`; endpoints `check_endpoint_opening:191-203`,
> called at `:402, :405` and `:471`). (ii) The reserved pair is exclusive to
> that claim **and to that group** (`audit_claims:118-122`, `:129-131`).
> (iii) `cw ≠ 0`, which is a theorem and not a refusal (next paragraph).
> **`λ_c ≠ 0` is not a condition of this step**, and the memo's earlier list
> of three overstated what it buys: the zero group-coefficient refusal
> (`check_opening_challenges`, `protocol.rs:141-152`, the loop at `:142-146`)
> is a **soundness** refusal — it stops a prover discarding a claim from the
> batch, which is what its error string says — and the conclusion survives
> `λ_c = 0`, disclosure staying 0 `Fp` on a real 35-member group and on a
> real singleton (controls C3 and A4).
>
> **`cw ≠ 0` is an unconditional public fact, not a refusal (change R-2).**
> The earlier text recorded this condition as "given by a refusal too, but
> not pinned to a line", and that reading is withdrawn: `cw` is not a
> challenge at all. `cw = zkey_weights(key)`
> (`zkp-core/src/pcs.rs:794-807`) is either all-ones on `1 ≤ len ≤ 256`
> positions, so `Σ_j cw_j = len`, an integer between 1 and 256 and therefore
> non-zero in `Fp`; or it is the equality tensor `eq_table_msb(tail)`
> (`mle.rs:13-51`), whose construction starts from the single entry `1` and
> repeatedly splits an entry `e` into `(e(1−r), e·r)`, an operation that
> preserves the total, so `Σ_j cw_j = 1` at **every** point whatsoever. A
> vector whose entries sum to 1, or to `len`, is not the zero vector.
> **No refusal is needed, `cw = 0` has probability exactly zero rather than
> `2^{-k}`, and there is no new privacy residual to list.** Measured on all
> sixteen role-captures: every group's `cw` sums to 1 or to `len`, with
> support between 32 and 256 entries.
>
> **Proof (change R-3): the annihilator form, exact for every `m`.** With
> `P_c` ranging over `Fp2^{256}` — which is what condition (i) gives — the
> image of `(P_c)_c ↦ (v, y)` is spanned by the vectors
> `T_{c,j} = λ_c cm_c · e_{v_j} + cw_j cm_c · e_{y_c}`, one per member `c`
> and column `j`, each with at most two non-zero coordinates. A functional
> `φ` kills all of them iff `λ_c φ(v_j) + cw_j φ(y_c) = 0` for every `c, j`
> (dividing by `cm_c ≠ 0`). Pick any `j` with `cw_j ≠ 0` — one exists
> because `cw ≠ 0`: then `φ(y_c) = −λ_c φ(v_j)/cw_j`; comparing two such
> `j, j′` forces `φ(v_j)/cw_j = φ(v_{j′})/cw_{j′}`; and at a `j` with
> `cw_j = 0` the relation is `λ_c φ(v_j) = 0`. Hence, as soon as some
> `λ_c ≠ 0`, the annihilator is the single line
> `φ = t·(cw_j on v_j, −λ_c on y_c)` — the verifier's own identity — and the
> image is precisely its kernel, the consistency subspace. If every
> `λ_c = 0` then `ρ_g = 0`, the group vector is identically zero, and the
> image is all of `Fp2^m` in the terminals. In both cases the data
> contributions lie in the image, because `ρ_g = Σ_c λ_c rw_c` by
> construction makes `⟨D, cw⟩ = Σ_c λ_c d_c`. ∎ The rank is exactly
> `2(256 + m) − 2` over `Fp` for **every** `m` and every `cw ≠ 0`. This
> replaces the `m = 2` induction the check supplied: no induction is needed,
> and the annihilator form also says what survives when a condition fails.
>
> The proximity vector is handled separately, as the check said it should be
> — `ρ_prox` is non-zero on the reserved proximity pair and a dependent pair
> is refused (`protocol.rs:141-151`), so `(a, b) ↦ ρ_p a + ρ_{p+1} b` is onto
> `Fp2^{256}`; the review confirmed that no claim and no group combination
> touches a proximity row on any of the sixteen role-captures, and that the
> proximity pair alone has rank 512 on the proximity vector.
>
> **What the step does NOT give on its own (change R-4).** It is **one
> group's message half**, at fixed challenges. The joint statement the
> theorem needs additionally requires: (i) the reserved pairs disjoint
> **across groups**, not only across claims — true on `A`, `Input` and
> `Output`, and **false on `H`** (the exception below); (ii) the proximity
> pair exclusive and with `wedge ≠ 0`, which is what makes the proximity
> functional vanish identically (previous paragraph); and (iii) the accepted
> lemma's **`H-pad`**, which is what licenses dropping the pad halves and the
> opened columns in favour of the message-half system. `H-pad` is
> load-bearing here and not decorative: in the review's own small model one
> opened position beyond the pad budget discloses **2 `Fp`** that the
> message-half reduction does not see. Beyond those, the step says nothing
> about the hash layer, nothing about the masking commitment `M` (the top of
> this section, Lemma 3.1 and Theorem 3.3 territory), nothing about cross-role
> independence (it is assumed, condition O-2), and nothing about any shape
> but the toy block and the toy attention component.
>
> **`H`'s exception, recorded (change R-5).** Two of `H`'s opening groups
> share the zero-sum pair — the `zsum` slot's claim *evaluates* those rows
> and the LogUp sum claim is *masked* by them — so on `H` the per-group
> decomposition is **invalid as written**, and no document had said so. The
> two groups must be ranked as **one** system: done jointly (1,028 `Fp`
> observations, blinding rank 1,022, with the data 1,024) the disclosure is
> **2 `Fp`**, the same number as before, and it is exactly the public LogUp
> identity — `rank(disclosed) = rank(public identity) = rank(both together)
> = 2` on all four captures, by span equality
> (`ts_addendum.py` A1, `ts_components.py`). **The number stands because of
> that joint computation, not because of the per-group argument.** This is
> the one deliberate exception to "one reserved pair per claim site", and it
> is sound **only** because the two groups' claims are tied by the public
> identity the statement already announces. Sharing a pair between two
> **ordinary** terminals is not sound, and the review reproduced the
> counterexample at the real scale: with two claims of `A` moved onto one
> pair, each terminal's **marginal** is still fully blinded (rank 2 on each
> alone), while the **joint** rank of the two drops from 4 to 2 and rises
> back to 4 once the data is added — the joint law moves with the witness
> although neither marginal does. That is why the statement above must be
> joint and not per claim.
>
> **Label: independently reviewed and corrected (2026-09-20),
> `ZK60_TERMINAL_SURJECTION_REVIEW.md`** — conditions restated, joint form,
> `H` exception. **Not a privacy acceptance.** The review wrote its **own**
> exact rank code, importing nothing from the project's tools
> (`results/zk60_terminal_surjection_review/`: `ts_field.py`, `ts_review.py`,
> `ts_addendum.py`, `ts_components.py`), and computed the system at the real
> schedule: **every group of `A`, `H`, `Input` and `Output` on all four
> captures**, group sizes up to 35 members at 256 columns, blinding rank
> exactly `2(256 + m) − 2`, **disclosed 0 `Fp` — except the one `H` group at
> 2 `Fp`, the public lookup identity**; then **2,040 fresh and adversarial
> challenge vectors with no failure**; the fold identity behind the
> message-half reduction checked 200 times with 0 failures; and `A`'s pad
> block at its real opened positions **246 × 256 of exact rank 246**, inside
> the 256-pad budget (`H` 242, endpoints 246 and 241). One control fired
> against the reviewer's **own** reduction: one opened position beyond the
> pad budget discloses 2 `Fp` that the message-half reduction misses — from
> which the ruling draws the standing consequence that **the pad count and
> the number of opened columns move together** (ruling J-2 as resolved,
> 03:49, 2026-09-20). **What this still leans on**: the accepted
> generic-rank lemma's *reduction* (`disclosed = 256·k0 + u-term`, with
> generators `_p1_rows`), whose correctness is one of **that lemma's own
> RELIES-ON rows** — the individual claims are now a proved step of that
> reduction (`ZK60_GENERIC_RANK_LEMMA.md` §3.2, change R-6), and the gate's
> own small model still validates the reduction with one group per claim
> only, which is change R-8 (test-side, made elsewhere). **What the review
> did not check** is listed in §8, under the closure of Q0.

So the correct statement of (H1) is about the **four PCS commitments only**:

> **(H1), stated precisely.** For the toy private-block layout, at any
> non-refused `ρ`, the law of `V_pcs` — the group vectors, proximity vectors,
> opened columns and 173 terminals of `A`, `H`, `In` and `Out` — is the same
> for every admissible hidden input.
>
> **MIXED** (ruling J-5): proved here from Lemma 4.1 + Proposition 4.2′ (the
> product law) + the accepted generic-rank lemma's core items 1–3 + the
> `Fp2::ZERO` value of the LogUp identity + the terminals step above,
> **conditional on**: cross-role blinding independence (VERIFIED IN THE CODE
> for the toy block, not machine-asserted — condition O-2); the imported
> terminals step, now independently reviewed and corrected (2026-09-20),
> with the `H` exception and the `H-pad` dependence it names; the lemma's own
> RELIES ON rows (`audit_claims` on every path, the refusal replay order —
> for which a Rust test is owed, the four `part_rows` assertions
> `pcs.rs:759, 768, 775, 786`, the `d+1` values per round
> `sumcheck.rs:148-150`, and the uniformity of the non-data rows'
> messages); and the two toy layouts only (ruling G-2, condition O-5).

**The invariants of this section that an implementer must not weaken.** Four,
and the first is new with the review of 2026-09-20. (1) **The reserved pair's
weight shape `(cm_c, cm_c·U)`** (`private_block/argument.rs:232-234`): an
`Fp`-basis of `Fp2`, not merely a non-zero `cm_c`. Keeping `cm_c ≠ 0` while
making the two weights `Fp`-dependent discloses 256 `Fp` on a singleton
group, and dropping the pair discloses 512. (2) **One reserved pair per
claim, exclusive to that claim and to its group** (`audit_claims:118-122`,
`:129-131`) — with `H`'s zero-sum pair as the single documented exception,
sound only because the two claims that share it are tied by the public LogUp
identity. (3) **`cm_c ≠ 0`, refused on both sides twice over**
(`argument.rs:346-349`; `audit_claims:103-108`, reached from the prover at
`protocol.rs:396, :399` and the verifier at `:458, :464`). (4) **The pad
budget**: the pad count and the number of opened columns move together, since
one opened position beyond the budget puts 2 `Fp` into the view that the
message-half reduction does not see. `λ_c ≠ 0` is *not* on this list for
privacy; its refusal stays, for soundness.



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

**Condition O-4 of the independent check: the lift is still owed as a
per-step kernel argument.** This
memo supplies the field part (Theorem 3.3) and §5.2 supplies the hash part
conditionally on it, but the step from those two to "the law of the whole
view is witness-independent" is written in prose. The check answered the
draft's Q5 with **yes**: what is owed is a per-step kernel argument over
messages that are **pairs** (field part, hash part), discharging the
bad-event list of §5.2. Until that is written, the composition of Theorem
3.3 with (H6) is prose, not a proof.

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

**Does the shared untagged domain matter to *this* step? (correction C-5.)**
No — but the draft's reason covers only one direction, and one term was
missing. The draft argued that a transcript absorption landing in the same
64-byte domain is an extra query on an input the adversary already knows,
which does not help it guess a salt. True, and it answers the salt-guessing
direction only. The check supplied the argument that closes the other
direction, by input length:

| query | input length |
|---|---|
| `Transcript::squeeze_bytes` (**every challenge**) | `32 + 7 + 8 = 47` (`transcript.rs:85-94`) |
| `Transcript::absorb` | `48 + len(label) + len(data) ≥ 49` (`:44-52`) |
| `merkle::hash_pair`, `pcs::salt_leaf` | `64` |
| `hash_column` | `rows·8` ∈ {3640, 3072, 400, 56} for `A` / `H` / `M` / an endpoint |

47 bytes is a length nothing else in the system uses, so **no
challenge-producing query can coincide with a node, leaf or absorb query**,
and the sequential lift's "each challenge is fresh uniform given the past"
needs no separate argument about the shared domain. (Challenges *are*
functions of leaf digests through the absorbed roots; that is by design and
is what the sequential-kernel lemma allows.)

**The one genuine overlap, and where it belongs.** Enumerating the labels on
this path, only `absorb_u64(b"log-cols", 8)` gives
`32 + 8 + 8 + 8 + 8 = 64` bytes (`private_block/protocol.rs:43`); `b"rows"`
gives 60 and `b"pb-slot"` 63. Its last 32 bytes are the **fixed constant**
`le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)`, so it collides with
`hash_pair(a, b)` only if `b` equals that constant, and with
`salt_leaf(d, s)` only if the salt does: `2^-256` per node or salt, about
**2^-241.42** (first written as 2^-243; corrected 2026-09-20 by
`ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`) over one proof's objects. That
term belongs **inside** (H6)'s
"(collision terms)" above, where this draft did not put it. With the length
argument and this term the dismissal stands.

Where the shared domain **does** matter is elsewhere and stays open:
composing this privacy argument in the ROM with the *soundness* reduction
over the same table (privacy-case item 16, condition O-7), and any argument
that **programs** the oracle — which under D18 none here does (item 14). It
also means `hash_column` on a commitment with exactly 8 rows would itself be
a 64-byte input; none of `A` (455), `H` (384), `M` (50) or the endpoints (7)
is — the endpoints by one row — but by arithmetic accident rather than by a
check (privacy-case item 16).

**The hash layer remains a GAP, and here is what is owed.** Nothing above
turns (H6) into a theorem: it is a statement inside an assumed model. Two
things are owed before the hash layer can be called done — (i) **(H6)
written as one random-oracle lemma with its query budget**, absorbing the
2^-241.42 (first written as 2^-243; corrected 2026-09-20 by
`ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`) term above and the `q·2^-256` salt
term, and (ii) **the sequential
lift composed with it into a single argument** (condition O-4), whose bad
events are: two distinct `squeeze` inputs colliding (the challenge chain
repeating), `2^-256` per pair and unreachable from any other table by the
length argument; two distinct `absorb` inputs colliding (the transcript's
binding); a `hash_pair`/`salt_leaf` input coinciding with a 64-byte `absorb`
input, ≈ 2^-241.42 (first written as 2^-243; corrected 2026-09-20 by
`ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`); and the prover's own oracle
queries colliding with the
transcript's, subsumed by the first three.

### 5.3 Why the known counterexample does not apply

The counterexample is `(H(mask), mask ⊕ w)`: two published values, each
uniform on its own, whose *joint* law determines `w`. The shape to hunt for
is **one blinding variable published in two places under different
encodings**. Here is every candidate in this protocol and what disposes of
it.

| # | the blinding variable | published where, twice | what disposes of it |
|---|---|---|---|
| 1 | the **CFS mask coefficients** `a_s` (B6) | in the masked rounds (`c_s·R_s(a_s)`) **and** in `M`'s `q` | Lemma 3.1: `q` reveals exactly one `Fp2` functional `V(a)`; §3.2: `V` factors through `R`, so it is *not a second, independent encoding*; and Fact 3.2: `V(a)` equals a public function of the already-published values. **This is the exact analogue of the counterexample and it is where the protocol could have failed** — see below |
| 2 | a **pad symbol** | in an opened column **and** in a group or proximity vector's pad half | the encoding identity `⟨E_j, v⟩ = Σ_i ρ[i]·col_j[i]` (`pcs.rs:1022-1031`) makes the pad half's values at the `d` distinct opened positions a function of the columns and the published message half; the residual `256 − d` coordinates are combinations of blinding only. The lemma's rank is computed over the whole generator system, so both are counted once; the precision of §4.2 is now **resolved** — those residual coordinates are supported on pad coordinates only and carry no data coordinate |
| 3 | a **reserved mask pair row** | in the masked terminal it hides **and** in the group vector that batches that claim | the block-triangular factorisation (lemma §3.2): the pair carries coefficients `(cm, cm·U)`, an `Fp`-basis of `Fp2`, no other claim touches it (`audit_claims`), and the minor's factor `Norm(λ·cm)` is exactly what the refusals keep non-zero |
| 4 | — (a shared **data** coordinate, not a blinding one) | the two endpoint planes are copies of `A[10], A[11], A[68], A[69]`, committed twice under independent blinding, and `SC_IO_IN`/`SC_IO_OUT` publish two terminals of the same values at the same `ρ` | Proposition 4.2′ (§4.2), which replaces the draft's reason: the four roles' blinding families are independent, so the joint law is the product of the per-role laws and a shared *data* coordinate cannot couple them — the endpoint planes are `A`'s own values committed under independent pads; the two terminals also carry independent reserved pairs (§2.4) |
| 5 | the **zero-sum pair** `u` (B4), whose last entry is determined by the other 255 | inside `H`'s data block, and inside the LogUp sum claim | it is declared a mask row to the PCS (`protocol.rs:374`) and its disclosed contribution is exactly the 2-dimensional public identity of value `Fp2::ZERO` (Lemma 4.1(2)) |
| 6 | `A`'s 256 **published salts**, drawn from the same stream that later produces `H`'s pads | the receipt, and (secretly) `H`'s pads | **only** assumption M-3 in its two-sided, whole-stream form (ruling C-3). This is the one candidate with no structural answer |

**Row 1 deserves the emphasis.** Had `M` batched a Private slot's `Γ`
functional — whose value `G_s = (Γ_s − σ_s)/c_s` involves the *unpublished*
honest sum `σ_s` — then `V(a)` would not be a public function of the view,
the fibre argument in Theorem 3.3 would fail, and the joint law would become
witness-dependent **with every marginal still exactly uniform in the
uniform-blinding idealisation**. Likewise
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
  **there is no restart** — see immediately below;
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

**There is no restart: the single-attempt reading (blocking item B-4, ruling
J-4).** The draft asserted that a refused attempt restarts with fresh pads,
salts and masks, and conditioned on that. **That mechanism does not exist in
this profile**; the sentence is withdrawn, and the correction makes the
argument cleaner rather than weaker.

* `private_block::prove_with_stats` calls `prove_inner` **once**
  (`private_block.rs:431-435`); there is no retry loop anywhere in the
  module.
* The two endpoint commitments are **not** created by the prover. They are
  caller-supplied `PreparedPlane`s made by `private_seam::prepare` with
  their own OS entropy, and **their roots are part of the public statement**
  (`ExpectedIo`, absorbed first at `protocol.rs:31`, re-checked at
  `:247-249`); a fresh endpoint has a different root and fails
  `check_endpoints`.
* `PreparedPlane` is documented and typed as *"No Clone, data getter, or
  repeated-opening method"* (`private_seam.rs:142-147`), and `Endpoints`
  carries a compile-fail doctest showing that the owners are consumed
  (`private_block.rs:360-370`).

So **a refusal is terminal for that `(statement, endpoints)` pair**, and
**"opened twice" is prevented by the type system** — which answers the
draft's Q8 outright, and makes the `2^-62.0` rate a liveness cost with no
retry available at the same statement. Conditioning on non-refusal is then
conditioning on `NR(ρ)`, a function of the challenges alone, which is
precisely what Theorem 3.3 does; no i.i.d.-attempts argument is needed, and
none is available.

*The operational consequence, recorded with the rulings.* A service that
retries after a refusal does so with **fresh endpoints**. The refusal event
is challenge-only, at about `2^-62` per proof, and it is visible as a changed
root; it carries no information about the input.

> **Corollary 5.1 (the lift, stated with all its hypotheses).** Fix an
> admissible public statement. Under (H1)–(H5) of Theorem 3.3, (H6) of §5.2,
> the sequential-kernel lemma as stated on branch `zk60-mvp-fable`, and the
> random-oracle model M-1 for the conditioning of §5.4, the law of the whole
> view of one toy private-block proof — field messages, challenges, roots,
> salts and authentication paths — is the same for every admissible hidden
> input, up to: the `fp()` term (≤ 2^-77.7, D9), the LogUp collision event
> (2^-112.0), the PRG advantage against M-3, and the ROM/M-2 terms of (H6).
>
> **PROVED-CONDITIONAL**, on cross-role blinding independence (VERIFIED IN
> THE CODE for the toy block, not machine-asserted — condition O-2), on the
> terminals step supplied by the independent check and since independently
> reviewed and corrected (§4.3, 2026-09-20),
> on (H6)'s model, and on a lemma that is not in the main tree. **This is
> not a privacy acceptance** and must not be quoted as one; its inputs still
> include two assumptions (M-1/M-2 and M-3), one imported step whose review
> left its own list of unchecked items (§8, Q0), and a lemma on a branch.



## 6. What is NOT covered

Written so a status page can quote it without softening it.

1. **The hash layer, beyond the single statement (H6).** The three roots, the
   1,280 published salts and the 1,280 authentication paths are not field
   objects and nothing here is a rank, a sampler or a simulator for them.
   (H6) says what would have to be true of them; M-2 (salted-leaf and
   salted-*subtree* hiding) is an assumption, not implied by collision
   resistance. What is owed here is named in §5.2: (H6) written as one
   random-oracle lemma with its query budget (including the ≈ 2^-241.42
   (first written as 2^-243; corrected 2026-09-20 by
   `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`) domain-overlap term), and the
   sequential lift composed with it into a single argument (condition O-4).
   **D8/D11 — a root fixed by a third party — is untouched**, and
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
   (computational, M-3). For the **endpoints** that premise is now
   *structural* rather than assumed: two proofs about the same input
   necessarily use different endpoint commitments, because the owners are
   consumed and `PreparedPlane` has no `Clone` (§5.4). It does **not** cover
   the hash layer, it does not
   discharge condition O-5 (the measured evidence for two proofs, round 23),
   and history item H7 — a different commitment to the same plane — is
   covered only as a data-channel correlation at the field layer.
4. **Every other shape. The 125M profile and the development rung owe all of
   this again from the start** (ruling G-2, and **condition O-5** of the
   independent check: the scope is unchanged, the two toy layouts only), not
   as a re-check:
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
* **RESULT 4 is withdrawn as an argument (correction C-2).** The script
  reports that publishing only `d` values per round drops the rank and raises
  `dim ker R` to 2…13, and the draft concluded that the `d+1`-values
  invariant (ruling G-3) is load-bearing. The numbers reproduce — the check
  gets the same set — but the conclusion does not follow: the comparison is
  against `N d + 1`, which is `dim C_s` for the **`d+1`-value** protocol,
  and with `d` values per round the *observation* shrinks too; a smaller
  observation cannot leak more. The check's control G2 publishes only `d`
  values in the distributional toy and the law **does not separate** on any
  witness pair (§7.3). The privacy-relevant invariant is *the mask's
  per-variable degree equals the round degree* — experiment C of §7.2, which
  does separate 3 of 3 — and the `d+1` length check
  (`sumcheck.rs:148-150`) is load-bearing in the **other** direction: it
  stops a prover sending *more* than `d+1` values, which the mask could not
  cover. It is also the step the proof of Fact 2.1 consumes (§2.1), which is
  where it now earns its keep.

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

**What this enumeration does not exercise (correction C-13).** Experiment
A's view contains **no `M` object at all**, and F runs only the broken
variant, never the honest two-slot case. So on its own the enumeration never
exercises the composition it is offered as evidence for; the check's controls
G1 and G7 supply exactly that, and both come out SAME (§7.3). The check also
sorts the controls by what they test: **B** (`argument.rs:275`) and **E**
(`:374`) are faithful rules of the real protocol, and **F** is a real rule
(`mask_commit` draws one mask per spec); **C** is a *distributional
analogue* — the real protocol fixes the mask's degree to the slot's degree by
construction (`mask_specs()`), so no edit could lower it — and **D** is
synthetic: no functional in `N_FUNCTIONALS` has that shape. D is the
counterexample *shape*, which is its purpose.

**Reproduce** (no build, no prover, a few seconds each):

```
python3 /home/victor/IntelligenceRegulation/results/zk60_joint_law_composition/mask_rank_identity.py
python3 /home/victor/IntelligenceRegulation/results/zk60_joint_law_composition/toy_joint_law.py
```

### 7.3 The independent check's added controls

`results/zk60_joint_law_composition_check/check_toy_controls.py`, with its
recorded output `check_toy_controls.txt`: the model was re-coded from the
Rust rather than imported, and every prediction was written down before the
run. The check also re-ran the draft's own script and reproduced its recorded
output **byte for byte** (`rerun_draft_toy_joint_law.txt`, `diff` clean).
These are **illustrations**, exactly as §7.1 and §7.2 are. This drafter has
neither re-run them nor edited the evidence.

| control | what it publishes | result |
|---|---|---|
| **G1** | the single-slot view **plus** the derived `g_val` — i.e. `M` disclosing exactly `V`: the honest form of Lemma 3.1 + Fact 3.2 | **SAME**, 0 of 3 pairs separate (supports 15,625) |
| **G7** | honest **two slots**, independent masks and reserved pairs, plus the θ-batched `V` | **SAME** — both marginals and the JOINT (support 531,441) |
| **G4** | two slots whose terminals share **ONE reserved pair** (what `audit_claims:118-131` forbids), plus `V` | **marginals SAME, JOINT DIFFERENT** |
| **G5** | the same sharing, without `V` | **marginals SAME, JOINT DIFFERENT** — the sharing, not the batching, is the fault |
| **G2** | only `d` values per round | **SAME** — the control that refutes §7.1's RESULT 4 reading |
| **G3** | `d + 2` values per round | **SAME** — the extra value is determined |
| **G6** | **cyclic hosting**: a hosted slot placed *before* its host, `κ_0κ_1 ≠ 1` | **SAME** — any invertible claimed-sum change of coordinates preserves "uniform on `C`" |
| **G6′** | the same with `κ_0κ_1 = 1` | **no honest prover exists**: `M(Γ_0, Γ_1) = (A_0, A_1)` is singular for a generic witness — a completeness failure, not a leak |

**G4 and G5 are the check's most useful new result.** They exhibit the
`(H(mask), mask ⊕ w)` shape on the *commitment* side: two terminals sharing
one reserved pair, each marginal untouched, the joint separating. §5.3's
table asserts that the accepted lemma's §3.2 disposes of that case but never
showed what breaking it would cost; there is now an exact enumeration that
does, and it is **a new instance of the marginal-versus-joint trap and the
counterexample behind the rule "one reserved pair per claim site"**. It
matches, by a second and independent route, the lemma's own finding that
"two claims share one reserved pair" gives `k0 = 16`.



## 8. Open questions for the next reviewer, most doubtful first

The independent check of 2026-09-20 answered Q1, Q2, Q3, Q4, Q6, Q7 and Q8;
each is kept below with the answer recorded, because the answer is now part
of the argument. Q5 it confirmed as still owed, and Q9 and Q10 stand. **Q0
asked for an independent review of the terminals step; that review has been
done (2026-09-20) and Q0 is closed — what the review itself did not check is
kept in its place, and is still the first thing the next reviewer should look
at.**

**Q0 [CLOSED by the independent review of the terminals step,
`ZK60_TERMINAL_SURJECTION_REVIEW.md`, evidence
`results/zk60_terminal_surjection_review/`; ruling J-2 as resolved, 03:49,
2026-09-20]** — the per-group surjection of §4.3 was supplied by the check
itself and, when Q0 was written, verified only by the check's own script.
The review re-derived it with its own exact rank code and answered the three
things Q0 asked: (a) **`cw ≠ 0` needs no refusal** — it is an unconditional
public fact, `cw` summing to 1 or to `len` at every point, so `cw = 0` has
probability zero (§4.3, change R-2); (b) **`λ_c ≠ 0` is demoted** — it is not
a condition of the step at all, and its refusal is a soundness refusal
(change R-1); (c) **the pair shape `(cm_c, cm_c·U)` is promoted** — it, and
not `cm_c ≠ 0` alone, is the condition that carries the conclusion (change
R-1). The `m = 2` induction is replaced by an annihilator proof exact for
every `m` (R-3), the statement is now joint rather than per claim (R-4), and
`H`'s shared zero-sum pair is recorded as an exception (R-5). The step still
leans on the lemma's reduction, whose correctness is one of **that** lemma's
RELIES-ON rows — with the individual claims now added to it as a proved step
(`ZK60_GENERIC_RANK_LEMMA.md` §3.2, R-6).

**Q0′ — what that review did not check, and is owed next.** In the review's
own words: **the hash layer** (salts, Merkle paths, leaf digests, the
Fiat–Shamir lift — everything there is a statement about field values at
fixed challenges); **the masking commitment `M`**, whose opening is Lemma 3.1
/ Theorem 3.3 territory and a different shape; **cross-role independence**,
which it assumed as condition O-2 rather than re-verifying; **every shape but
the toy block and the toy attention component** — the structural facts are
enforced by code that runs on every profile, but the numbers are the four
captures of 2026-09-19 at those receipts' challenges; **the captured
challenges themselves**, taken from the captures rather than replayed through
BLAKE3 (they are tied together by the verifier's identity
`⟨v, cw⟩ = Σ λ y`, recomputed with 0 failures on all sixteen role-captures, and
a transcript replay is what `scripts/zk60_native_joint_view.py` stage 1 does);
**whether the sampler as printed computes the right `θ`-order** (correction
C-1, out of that review's scope); and **`k0 = 0` on the group generators**,
which is the accepted lemma's own result. The gate-side item is change R-8:
the joint-view gate's small model has one group per claim, so the
`λ`-batched multi-member case has never been machine-validated inside the
gate.

**Q1 [CLOSED by the check — settled by reading all 23 closures; no symbolic
check is owed, condition O-1's Rust guard is] — the completeness premise
under Fact 3.2 is the load-bearing one, and
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

**Q2 [CLOSED by the check, and restated: block diagonality is not the
hypothesis that is needed — cross-role blinding independence is, and it is
settled family by family by reading (§4.2). What remains is condition O-2,
the Rust guard] — block diagonality had no argument (the draft's GAP G-1).**
Proposition 4.2 turned the accepted lemma's four per-role ranks into the
joint statement *only* if no non-data coordinate class is shared between
commitments; Proposition 4.2′ now gets the joint statement from independence
alone. Two sub-questions survive for the guard: could a future profile
legitimately share a row (a common proximity row across the two endpoints,
say) and would anything fire? And is a Rust assertion the right closure, or
does the reviewer want the stronger statement that the four commitments'
non-data rows are drawn from disjoint stream segments — which is what M-3
actually needs?

**Q3 [ANSWERED by the check: yes, the inventory is complete —
`mask_verify` is `hashline/src/zk.rs:552-590` and its five checks are
exactly the ones §3.1 lists] — is Lemma 3.1's inventory of `M`'s published
objects complete?** This
drafter read `mask_commit`, `mask_open` and the first lines of `mask_verify`
(`zk.rs:430-560`) and took `M-q`, `M-prox`, `M-cols` from the generic-rank
lemma. If `mask_verify` checks anything else about `q`, the proximity vector
or the columns — a degree bound, a second sum identity, a per-column
consistency that pins more than `b(x_j)` and `u(x_j)` — then "the opening
reveals exactly one `Fp2` functional of `a`" is wrong and Theorem 3.3's
(H3) fails. **This is the single source reading most worth redoing.**

**Q4 [RESOLVED: the code comment is wrong about what the extra coefficient
is for, harmlessly; nothing in the code changes because of it; the content
is `dim ker R_s = 1`, not that `a'` is special — §2.3] — the `a'`
discrepancy.** One sub-question is recorded as **not verified**, by this
drafter and by the check alike: whether the cited CFS/Libra literature needs
that coefficient for a statement **this profile does not use** (the legacy
profile, say, or a slot with two extension rounds whose extension challenges
interact). Removing it would be a protocol change and a byte-changing
re-freeze, and nothing recommends it.

**Q5 [ANSWERED "yes", and STILL OWED — condition O-4; the bad events are
listed in §5.2] — the composition of Theorem 3.3 with (H6) into one
sequential argument.** §5.1 says the message sequence includes the roots and §5.2
supplies the hash part conditionally on the field part. The step from those
two to "the law of the whole view is witness-independent" is written here in
prose. Does the checker want it as a per-step kernel argument, with the
message at step `j` defined as the pair (field part, hash part)? And is the
sequential-kernel lemma, which lives only on branch `zk60-mvp-fable`, in a
state to carry it?

**Q6 [ANSWERED: the standard hybrid is enough; what was owed is the
real-prover sentence, now stated once in §3.3's remark. And correction
C-11: the two endpoints' blinding is independent of the block stream
*information-theoretically*, not under M-3 — §1.2] — (H5) is false
information-theoretically for `A`, `M` and `H`.** Those three come from
**one** BLAKE3 stream as disjoint consecutive segments, so `α`, `π` and `μ`
are independent only under M-3 (and `A`'s 256 salts are *published* before
`H`'s pads are drawn, which is why M-3 must be two-sided, ruling C-3).
Theorem 3.3 is stated with exact independence. The reduction — an adversary
distinguishing the two worlds yields a distinguisher against `ZkRng` — is not
written here. Is it wanted explicitly, or is the standard hybrid enough?

**Q7 [RESOLVED as to its own worry: yes, the conclusion survives — the
undetermined coordinates are supported on pad coordinates only and carry no
data coordinate, so this is a correction of the prose, not a gap (§4.2). The
correctness of the reduction as a whole stays the generic-rank lemma's
RELIES-ON row] — the pad-half determinacy prose.** The lemma's disposition
says the pad halves are determined by the opened columns; indices are drawn
with replacement and the captures record 231–246 distinct, so `10…25`
coordinates of each published pad half are *not* determined by the columns.

**Q8 [ANSWERED by the check, and the question's premise was false: there is
no restart in this profile] — conditioning on non-refusal.** The draft asked
whether a second attempt on the same endpoints could open them twice. It
cannot: `prove` is called once (`private_block.rs:431-435`), the endpoint
owners are consumed, `PreparedPlane` has no `Clone`
(`private_seam.rs:142-147`, `private_block.rs:360-370`), and the endpoint
roots are in the public statement (`protocol.rs:31`, `:247-249`), so a
refusal is terminal for that `(statement, endpoints)` pair and "opened
twice" is prevented by the type system. Theorem 3.3 conditions on `NR(ρ)`, a
function of the challenges, which is exactly what a single attempt supports
(§5.4). The same correction is owed upstream and has been made in
`ZK60_GENERIC_RANK_LEMMA.md` §3.2 (its condition O-5).

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

**The labels below are the independent check's, adopted whole by ruling
J-5; nothing here is strengthened beyond what the check assigns.** The
check re-labelled the draft's 32 rows and added three of its own, under the
rule *never strengthen without a proof written down, and mark as mixed any
row that stands on a RELIES ON, ASSUMED or GAP row*. **PROVED / PROVED HERE
(unconditional)** = a proof is written down and needs nothing outside it.
**VERIFIED IN THE CODE** = established by reading named lines.
**PROVED HERE on named rows** = proved given rows that are themselves relied
on or assumed. **RELIES ON** = a named, cited fact not re-derived here.
**ASSUMED** = a model assumption. **GAP** = nobody has established it.
**ILLUSTRATION** = it illustrates; it does not establish.

| # | statement | § | label (the check's, per ruling J-5) |
|---|---|---|---|
| 1 | the inventory of published field messages and their exact forms | 1.3 | **VERIFIED IN THE CODE** (promotion): re-read end to end by the check — with correction C-1, the θ-order |
| 2 | the linear / nonlinear split of the view | 1.4 | PROVED HERE |
| 3 | the blinding families are uniform and mutually independent | 1.2 | RELIES ON (M-3, ruling C-3) + D9 for uniformity; **information-theoretic for the two endpoints** (C-11) |
| 4 | `dim C_s = N_s d_s + 1` | 2.1 | PROVED HERE (unconditional) |
| 5 | `rank R_s = dim C_s`, `dim ker R_s = 1`, for every `ρ` (Fact 2.1) | 2.1 | **PROVED (unconditional)** (promotion): the check's five-line proof, §2.1; recomputed 276/276 |
| 6 | the claimed-sum change of coordinates is invertible | 2.2 | PROVED HERE, on the order rule; *triangularity is sufficient, invertibility is what the proof needs* (C-6) |
| 7 | **Lemma 2.2**: the whole sumcheck channel is uniform on the public subspace `C` | 2.2 | PROVED HERE, on rows 3, 5, 6 — now standing on a **proved** row 5 |
| 8 | the DOF accounting: rounds consume `dim C_s`, columns 0, mask evaluation 0, mask total 0, `q` 0 additional, slack 0 | 2.3 | **ILLUSTRATION** (demotion): four different spaces, never summed in any proof |
| 9 | `L_s + 256 ≤ 512` and `n_base = 2·slots + 4` are the same fact about `M`'s geometry | 2.3 | **VERIFIED IN THE CODE** (promotion): `zk.rs:373-375`, `:431-447`; the load-bearing runtime assert is `zk.rs:442`, **not** `layout.rs:735`, which is inside `mod tests` (C-14) |
| 10 | shared evaluation points never share a reserved pair; the consequence for the law | 2.4 | RELIES ON (`audit_claims`) + PROVED HERE for the consequence; controls G4/G5 (§7.3) exhibit the cost of breaking it |
| 11 | **Lemma 3.1**: `M`'s opening depends on `a` only through `V(a)` | 3.1 | PROVED HERE on **M-3 only** (partial promotion): `M-cols` proved in the check's A3.5, `mask_verify` re-read in its A2.2 |
| 12 | **Fact 3.2**: all 34 `M` functional values are public functions of the view | 3.2 | **VERIFIED IN THE CODE** for the 23 toy-block closures (promotion); RELIES ON for every other schedule |
| 13 | `V` factors through `R` (`ker R ⊆ ker V`) | 3.2 | **PROVED** (promotion): the same argument as row 5; recomputed 276/276 |
| 14 | **Theorem 3.3**: the joint law of the field view at fixed non-refused `ρ` is witness-independent | 3.3 | PROVED HERE, on (H1)…(H5), **in the uniform-blinding idealisation** (B-3 / C-7) |
| 15 | **Corollary 3.4**: O1 exists and is perfect *in the uniform-blinding idealisation* | 3.4 | PROVED HERE on row 14; **the printed algorithm was wrong** and is corrected (B-1) |
| 16 | integer-range side information (privacy-case item 20) is discharged at the field layer | 3.3 | mixed — conditional on the whole stack; the field layer only |
| 17 | **Lemma 4.1**: `dim(F ∩ T) = 0` ⟺ the linear view's law is data-independent; and the general form | 4.1 | PROVED HERE (unconditional) |
| 18 | the matrix for the joint statement is the `100 × 358` joint non-data block | 4.2 | **ILLUSTRATION / unnecessary** (demotion): the joint statement follows from independence, not from that rank |
| 19 | across slots *inside* one commitment is the same matrix, covered by the accepted lemma | 4.2 | RELIES ON (`ZK60_GENERIC_RANK_LEMMA.md` §3.2, whose reduction now includes the individual claims as its Step 7, added 2026-09-20 from the independent review; the step is also written out in §4.3 here) — label unchanged, wording corrected by the security owner |
| 20 | **Proposition 4.2**: block diagonality ⟹ joint rank = sum, so `k0_joint = 0` | 4.2 | PROVED HERE given row 21, **superseded** by Proposition 4.2′ |
| 21 | **cross-role blinding independence** — no blinding source shared between commitments (the draft's "block diagonality", restated) | 4.2 | **RESTATED and promoted from GAP**: **VERIFIED IN THE CODE** for the toy block + M-3; still not machine-asserted (condition O-2) |
| 22 | "the pad halves are determined by the opened columns" is exact only for distinct indices | 4.2 | **RESOLVED as to Q7's own worry → a correction of the prose** (promotion); the reduction's correctness as a whole stays the **lemma's** RELIES ON row |
| 23 | **(H1)**: the four PCS commitments' field view has a witness-free law | 4.3 | mixed — on rows 17, 19 (with the imported terminals step), 20/21 as restated, and **two toy layouts only** |
| 24 | **(H6)**: the conditional law of roots and paths given the field view is witness-free | 5.2 | ASSUMED (M-1, M-2) + PROVED HERE inside the model, with the ≈ 2^-241.42 (first written as 2^-243; corrected 2026-09-20 by `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`) collision term of C-5 added |
| 25 | the shared untagged 64-byte domain does not affect step (H6) | 5.2 | **mixed** (demotion): the draft's reason covers one direction only; it stands with the length argument and the ≈ 2^-241.42 (first written as 2^-243; corrected 2026-09-20 by `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`) term |
| 26 | the `(H(mask), mask ⊕ w)` counterexample does not apply: rows 1–5 of the table | 5.3 | mixed, per row; row 4's reason replaced by Proposition 4.2′, row 2's completed by row 22; **row 6 (the shared RNG stream) is ASSUMED (M-3)** |
| 27 | conditioning on non-refusal is free, and the refusal channel carries no witness information except the LogUp collision | 5.4 | RELIES ON (lemma §3.6) + ASSUMED (M-1) — **the restart the draft cited does not exist**; the single-attempt reading replaces it (B-4) |
| 28 | **Corollary 5.1**: the lift to the real protocol | 5.4 | PROVED-CONDITIONAL, on rows 12, 14, 21 as restated, 24, the imported step of row 33, and a lemma that is only on branch `zk60-mvp-fable` |
| 29 | many proofs about the same or related inputs, at the field layer, for any `n` | 6.3 | PROVED HERE conditional on row 14 and cross-proof stream independence — and the endpoint premise is now *structural* (owners consumed, no `Clone`) |
| 30 | the 125M profile and the development rung | 6.4 | **GAP** — owed again from the start (ruling G-2) |
| 31 | the hash layer beyond (H6); D8/D11; the ROM composition with soundness | 6.1, 6.5 | **GAP** |
| 32 | the toy enumerations | 7 | **ILLUSTRATION** — and experiment A contains no `M` object, so it does not illustrate the composition; the check's G1 and G7 supply it (§7.3) |
| 33 | *(new)* the 173 individual terminals add nothing beyond the group vector and one public identity | 4.3 | **PROVED**, on the pair shape `(cm, cm·U)` with `cm ≠ 0`, the pair exclusive to its claim and its group, and `cw ≠ 0` (a theorem, not a refusal) — **independently reviewed and corrected (2026-09-20), `ZK60_TERMINAL_SURJECTION_REVIEW.md`**: conditions restated, joint form, `H` exception; proved for every group of the four captures and 2,040 further challenge vectors (`results/zk60_terminal_surjection_review/`). Not a privacy acceptance |
| 34 | *(new)* no restart exists; the endpoints cannot be opened twice | 5.4 | **VERIFIED IN THE CODE** |
| 35 | *(new)* no challenge query can coincide with a node, leaf or absorb query | 5.2 | **PROVED** (the check's, by input length) |

**Tally, 35 rows — the check's, adopted by ruling J-5.**

| label | count | rows |
|---|---:|---|
| **PROVED / PROVED HERE (unconditional)** | 6 | 4, 5, 13, 17, 33, 35 |
| **VERIFIED IN THE CODE** | 5 | 1, 9, 12, 21 (restated), 34 |
| **PROVED HERE on named RELIES ON / ASSUMED rows** | 6 | 2, 6, 7, 11, 14, 15 |
| **mixed** | 6 | 16, 19, 23, 24, 25, 26 |
| **RELIES ON** (primary) | 4 | 3, 10, 27, 28 |
| **GAP** | 2 | 30, 31 |
| **ILLUSTRATION / superseded** | 6 | 8, 18, 20, 22, 29, 32 |

**The three demotions**, with the check's reasons: row 8 (the DOF table is a
mnemonic, not a theorem — its four rows live in four spaces that no proof
adds up); row 18 (the `100 × 358` block is not the matrix the joint
statement needs); row 25 (the untagged-domain argument as written covers one
direction and omits a collision term). Row 32 is additionally re-labelled
with the observation that its central experiment omits `M`. **The
promotions**, each with a proof or a reading written above: rows 1, 5, 9,
12, 13, 21, 22, and the three new rows 33–35.

> **Exactly six rows are unconditional**: 4, 5, 13, 17, 33 and 35 — and two
> of those (33 and 35) are the independent check's rather than this memo's,
> with **33 independently reviewed and corrected on 2026-09-20** (its
> conditions restated, its proof replaced, `H`'s exception recorded). Every
> other proved row stands on at least one row that is relied on, assumed, or
> established only by reading.

**The two gaps, named.** (30) **every shape other than the two toy
layouts** — owed again from the start (ruling G-2, condition O-5). (31)
**the hash layer beyond (H6), D8/D11, and the ROM composition with the
soundness reduction over one table.** Assumptions carried: **M-1** (one
untagged oracle), **M-2** (salted-leaf and salted-subtree hiding), **M-3**
(whole-stream PRG, two-sided), and **D9**'s accepted `fp()` residual. Two
things that are not gaps but are not closed either, both of them guards that
stop a reading from rotting: **condition O-1** (a per-slot
`poly(extensions) = 0` Rust test) and **condition O-2** (a cross-role
blinding-disjointness assertion).

> **Nothing in this document establishes a privacy property.** It is step 4
> of the five-step path in `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` §3.
> It has now been independently checked and the theorem's **core** accepted
> for the toy block in the uniform-blinding idealisation — which is not a
> privacy acceptance: two gaps remain (the hash layer and every other
> shape), one step was supplied by the check and has since been
> independently reviewed and corrected, with its own list of unchecked items
> (§8, Q0′), and the real prover is not the idealised one (§3.3's remark).



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
| §2.3 the DOF count | Fact 2.1, `M-cols`, §3.5(b), **and Lemma 3.1 for the "`q` consumes 0 additional" row** | **Lemma 3.1 is §3.1, which is *later*** | **no, but note it**: Lemma 3.1 does not use the DOF table, so the dependency runs one way only. The check confirmed this and demoted the table to an ILLUSTRATION (row 8): it is a mnemonic, not a premise of anything |
| §2.4 hosts and shared points | `audit_claims`; the host-order assert | — | no |
| §3.1 Lemma 3.1 | uniformity of `b`, `u`, `M`'s pads; `M-cols` | none of these is concluded later | no |
| §3.2 Fact 3.2 | the completeness premise `argument.rs:18-22` | nothing later; it is Q1 | no |
| §3.2 `V` factors through `R` | the lemma's §3.5(b) | — | no |
| §3.3 Theorem 3.3 | (H1)…(H5) | **(H1) is §4**, which is *later in the document* but does not use Theorem 3.3 anywhere | **no** — §4 is self-contained: it uses Lemma 4.1, the accepted lemma, cross-role blinding independence and the imported terminals step, none of which mentions §3. The independent check re-derived this acyclicity itself (its A1.1) and found no circularity |
| §3.4 Corollary 3.4 | Theorem 3.3 | — | no |
| §3.3 item 20 discharged | Theorem 3.3 | — | no |
| §4.1 Lemma 4.1 | nothing | — | no |
| §4.2 the joint matrix | the tool's reduction `disclosed = 256 k0 + u-term` | nothing later; it is the lemma's row 14 [RELIES ON] | no |
| §4.2 Propositions 4.2 and 4.2′ | 4.2: block diagonality; 4.2′: cross-role blinding independence | nothing in this memo concludes either — 4.2′'s hypothesis is settled by the check's source reading (row 21 restated) and 4.2 is superseded | no |
| §4.3 (H1) | Lemma 4.1, Proposition 4.2, the accepted lemma, `Fp2::ZERO` | — | no |
| §5.1 the lift's hypothesis | Theorem 3.3 | — | no |
| §5.2 (H6) | M-1, M-2 | nothing concludes an assumption | no |
| §5.3 the counterexample disposal | Lemma 3.1, Fact 3.2, the lemma's §3.2, Proposition 4.2, M-3 | all earlier or inputs | no |
| §5.4 conditioning | M-1; the lemma's §3.6; a **single** prove attempt (there is no restart — row 34, VERIFIED IN THE CODE) | nothing later concludes it; the single-attempt facts are source readings | no |
| §5.4 Corollary 5.1 | everything above plus the sequential-kernel lemma | — | no; it is correctly last |
| §6.3 many proofs | Theorem 3.3; cross-proof stream independence | — | no |

**The three shapes the privacy case's own check hunted for are absent here
too**: the joint hypothesis is never assumed and then concluded (Theorem 3.3
concludes it and uses only (H1)…(H5), none of which is the joint hypothesis);
"the view is witness-independent given the challenges" is never used to prove
witness-independence; "the pads are uniform given the view" appears nowhere —
§4.2's precision is about what the *columns determine*, and it is used only
to avoid double-counting, never to establish uniformity.

**The one thing to watch** is the shape §9's tally is pointed at: **of the 35
rows, only six are unconditional, and two of those six are the independent
check's rather than this memo's** — everything else stands on a row that is
relied on, assumed, or established by reading.

**The quoting rule, as condition O-6 amends it**: *no sentence may state
Theorem 3.3 or Corollary 3.4 without naming, in the same sentence, the
uniform-blinding idealisation, the cross-role blinding-independence
hypothesis (the restatement of what the draft called GAP 21) and the two toy
layouts.*

## Revision record (2026-09-20)

One row per adjudicated item: the blocking items B-1 … B-4, the corrections
C-1 … C-14 and the conditions O-1 … O-7 of
`ZK60_JOINT_LAW_COMPOSITION_CHECK.md`, and the rulings J-1 … J-5 of
`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`. No claim was added beyond what
those two documents establish, no label was strengthened beyond the check's,
and no evidence file was edited.

A **second pass, later on 2026-09-20**, applied changes R-1 … R-7 of
`ZK60_TERMINAL_SURJECTION_REVIEW.md` — the independent review of the
terminals step — as accepted by ruling J-2 as resolved (03:49) in
`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`. Those rows are at the end of the
table. R-8 is a test-side change to the joint-view gate's small model and is
not made in this memo. No proof byte changes and no new refusal follows from
any of them.

A **third pass, later on 2026-09-20**, corrects **one number** in place —
the 64-byte absorb's overlap with the node format, from ≈ 2^-243 to
2^-241.42 — on correction C-1 of `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`.
Its row is the last of the table. No other text was touched in that pass.

| Item | Section(s) changed | What changed |
|---|---|---|
| B-1 / C-1 / J-1 | §1.3, §3.1, §3.4 step 3, §9 rows 1 and 15 | the declared functional order written out — interleaved per slot, a Standalone's `Γ` immediately before that slot's `eval`, the six host `Γ`s last (`private_block/argument.rs:361-376`, `:924-925`) — the sampler's step 3 rewritten in it, and the order recorded as part of the public data the sampler needs and as something a layout change must not reorder silently |
| B-2 / J-2 | §4.2(a), §4.3 (new block before the (H1) statement), §3.4 (Corollary 3.4), §8 Q0, §9 row 33 | the check's per-group surjection for the 173 individual terminals imported with its three non-vanishing conditions and the refusal that gives each, labelled "supplied by the independent check; verified by its script; not independently reviewed"; the accepted lemma's reduction named as the thing leaned on and its correctness as one of that lemma's own RELIES-ON rows; added as the first item for the next reviewer |
| B-3 / C-7 / J-3 | status line, §0 "What is shown", §3.3 (theorem statement and a new remark), §3.4, §5.3, §9 rows 14 and 15 | every "perfect"/"exactly" now carries "in the uniform-blinding idealisation"; the real-prover form is stated **once**, in the theorem's remark: within D9's accepted 2^-77.7 for one toy proof, and otherwise up to the advantage against the named generator, the keyed BLAKE3 stream with a counter (`zkp-core/src/rng.rs`, M-3) |
| B-4 / C-4 / J-4 | §3.5, §5.4 (bullet 1 and a new passage), §6 item 3, §8 Q8, Appendix A, §9 rows 27, 29, 34 | the restart sentence withdrawn and replaced by the single-attempt reading with the check's citations (`private_block.rs:431-435`, `:360-370`, `private_seam.rs:142-147`, `protocol.rs:31`, `:247-249`): a refusal is terminal for that statement and those endpoints, and "opened twice" is prevented by the type system; the operational consequence recorded — a service that retries uses fresh endpoints, and the refusal is challenge-only, about 2^-62, visible as a changed root |
| J-5 | §9 (table, tally, notes), and the label lines in §2.1, §2.2, §2.3, §3.1, §3.2, §4.2, §4.3, §5.4 | the check's 35-row table and tally adopted whole — 6 proved unconditionally, 5 verified in the code, 6 proved on named rows, 6 mixed, 4 relying on cited facts, 2 gaps, 6 illustrations — with its three demotions (rows 8, 18, 25) and its promotions; nothing strengthened beyond it |
| C-2 | §2.1, §7.1 | RESULT 4's reading withdrawn: the comparison was against the `d+1`-value protocol's `dim C_s`, publishing less cannot leak more, and the check's control G2 does not separate; the privacy-relevant invariant is mask degree = round degree (experiment C), and the `d+1` length check is load-bearing against *more* than `d+1` values and as the step Fact 2.1's proof consumes |
| C-3 | §4.2 | the joint-view gate's shared-blinding control is now quoted with its recorded blind spot (it fires only at tight, singleton-group positions — `A` 17 of 35 groups, `H` 2 of 9) |
| C-5 | §5.2, §9 rows 24, 25, 35 | the check's length argument added (challenges are 47-byte queries, a length nothing else uses, so no challenge query can coincide with a node, leaf or absorb query) together with the one real overlap — `absorb_u64(b"log-cols", 8)`, the protocol's only 64-byte absorb, fixed last 32 bytes, about 2^-241.42 (first written as 2^-243; corrected 2026-09-20 by `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`) per proof — folded into (H6)'s collision terms |
| C-6 | §2.4 | "Lemma 2.2 is exactly where that rule earns its keep" withdrawn: invertibility, not triangularity, is what the proof uses, and a hosting cycle's failure mode is a completeness failure (controls G6 and G6′) |
| C-8 | §0 "What is shown" | "four of them already accepted elsewhere" corrected to two ((H2) and (H5)); O1's existence stated as conditional on (H1)–(H5) and for the field view only |
| C-9 | §0 "What it rests on" | the generic-rank lemma's **core** was accepted; its draft was explicitly not accepted as written |
| C-10 | §2.3, §8 Q4 | the comment at `zkp-core/src/sumcheck.rs:163-183` stated plainly as wrong about what the extra coefficient is for, and harmless — nothing in the code changes because of it; the content is `dim ker R_s = 1`, not that `a'` is special (`a_0` is equally droppable at 5 of 6 `ρ` regimes); whether the cited literature needs the coefficient for a statement this profile does not use is recorded as NOT VERIFIED |
| C-11 | §1.2, §8 Q6 | the two endpoints' blinding recorded as independent of the block's stream **information-theoretically** (their own `ZkRng::from_os`), not merely under M-3 |
| C-12 | §3.3 | `V_sc` recorded as **not** a product across roles (one extension round mixes `A`'s, `H`'s and an endpoint's reserved pairs), which is why (H1) is stated for `V_pcs` only and the conditioning is on the whole of `π` |
| C-13 | §7.2, new §7.3 | experiment A's missing `M` object and F's missing honest two-slot case recorded, with the check's G1 and G7 (both SAME) cited; the draft's controls sorted into real rules, a distributional analogue (C) and a synthetic shape (D) |
| C-14 | §2.3, §9 row 9 | `layout.rs:733-736` marked test-only (inside `mod tests` from `:695`); the load-bearing runtime assert is `zk.rs:442` |
| O-1 | §3.2 | the per-slot `poly(extensions) = 0` Rust guard recorded as what is owed, in place of a symbolic check or a run through the unverified Python port |
| O-2 | §4.2, §9 (the two-gaps paragraph) | the cross-role blinding-disjointness assertion recorded as the closure still owed |
| O-3 | §2.1 | Fact 2.1 restated as a proved identity here, with the same recommended for `ZK60_GENERIC_RANK_LEMMA.md` §3.5(a) |
| O-4 | §5.1, §5.2, §6 item 1, §8 Q5 | the lift recorded as owed in the form of a per-step kernel argument over messages that are (field part, hash part) pairs, with the bad-event list written out |
| O-5 | §4.3, §6 item 4 | scope unchanged and restated: the two toy layouts only |
| O-6 | Appendix A | the quoting rule amended — the uniform-blinding idealisation, the cross-role independence hypothesis and the two toy layouts must be named in the same sentence as Theorem 3.3 or Corollary 3.4 |
| O-7 | §8 Q8, §4.3, and `ZK60_GENERIC_RANK_LEMMA.md` §3.2 | the restart correction routed to the lemma and made there in this pass (with a row in that memo's revision record); the terminals step recorded here as the lemma's, imported with its provenance |
| Promotion: the degrees-of-freedom fact | §2.1, §2.2, §3.2, §9 rows 5 and 13 | Fact 2.1 is now PROVED unconditionally, with the check's five-line proof written out and credited and the explicit kernel given; the 115 and 276 recomputations become confirmations rather than supports |
| Promotion: the completeness premise | §3.2, §8 Q1 | recorded as settled by reading all 23 closures — 21 by a public factor in every monomial, the two softmax slots by different extension rounds — and as structural and witness-independent, which is the form Theorem 3.3 needs |
| Promotion: block diagonality | §0, §4.2, §8 Q2, §9 rows 18, 20, 21 | recorded as settled family by family by reading **and** unnecessary: independent per-role blinding gives the product law directly (Proposition 4.2′), which also disposes of the endpoint planes being `A`'s own planes; the draft's GAP G-1 is closed in that restated form, leaving condition O-2 |
| The hash layer | §0, §5.2, §6 item 1 | the check's finding added; the layer **remains a gap**, and what is owed is named: (H6) written as one random-oracle lemma with its query budget, and the sequential lift composed with it into a single argument |
| The toy enumeration | new §7.3 | the check's controls and their results added — G1 and G7 (SAME), G4/G5 (identical marginals, different joint law: the new instance of the marginal-versus-joint trap and the counterexample behind "one reserved pair per claim site"), G2 (refuting RESULT 4), G3, and G6/G6′ (cyclic hosting). No evidence file was edited |
| Status line | header | replaced with the text ruling J-5's disposition requires |
| §0 and §9 prose | §0 "What must not be read into it", §9 closing paragraph | "it has not been independently checked" corrected — it has been, the theorem's core is accepted in the uniform-blinding idealisation, and one step was supplied by the check and reviewed by nobody |
| R-1 | §4.3, the quoted block (the conditions), §9 row 33 | the three conditions replaced: the reserved pair's weight **shape** `(cm_c, cm_c·U)` with `cm_c ≠ 0` (`argument.rs:232-234`) and pair exclusivity across claims *and* groups (`audit_claims:118-122`, `:129-131`) are what the step needs; `cm_c ≠ 0` is kept as what the code refuses on, with both refusal sites cited on both the prover and the verifier path; `λ_c ≠ 0` is dropped from the conditions and re-filed as a **soundness** refusal, with the recomputed disclosure of 0 `Fp` at `λ_c = 0` |
| R-2 | §4.3, the `cw ≠ 0` sentence | "the check records this one as given by a refusal too, but does not pin it to a line" withdrawn and replaced by the proof: `zkey_weights` (`pcs.rs:794-807`) gives all-ones (sum `len`) or the equality tensor `eq_table_msb` (`mle.rs:13-51`, sum exactly 1 at every point), so `cw = 0` has probability zero — no refusal, no residual |
| R-3 | §4.3, the proof | the `m = 2` induction replaced by the review's annihilator proof, exact for every group size `m`, with the rank stated as `2(256 + m) − 2` over `Fp` |
| R-4 | §4.3, new paragraph before the label | what the step does **not** give on its own written down: one group's message half only; the joint statement additionally needs cross-group pair disjointness, the exclusive proximity pair with `wedge ≠ 0`, and the lemma's `H-pad` (load-bearing: one opened position beyond the pad budget discloses 2 `Fp` the message-half reduction misses); and it covers neither the hash layer, nor `M`, nor cross-role independence, nor any shape but the two toy ones |
| R-5 | §4.3, new paragraph before the label (and `ZK60_GENERIC_RANK_LEMMA.md` §3.3) | `H`'s exception recorded: two opening groups share the zero-sum pair, so the per-group decomposition is invalid there; ranked jointly the disclosure is 2 `Fp` and equals the public LogUp identity by span equality on all four captures; why this one sharing is sound (the claims are tied by the public identity) while sharing a pair between two ordinary terminals is not — the reproduced counterexample, marginals rank 2 each, the joint dropping 4 to 2 and moving with the data |
| R-7 | §4.3 label, §8 Q0 (and new Q0′), §9 row 33 and tally note, §0, status line, Corollary 5.1 | the step's label relabelled to "independently reviewed and corrected (2026-09-20), `ZK60_TERMINAL_SURJECTION_REVIEW.md`" with the evidence directory cited and "not a privacy acceptance" kept; Q0 closed with its three answers (the `cw` proof, the `λ` demotion, the `(cm, cm·U)` promotion) and replaced by Q0′, the review's own "not checked" list; the numerical confirmation recorded where the step's evidence is cited (own rank code importing nothing from the project's tools; every group of `A`, `H`, `Input`, `Output` on all four captures; rank `2(256 + m) − 2`; disclosed 0 `Fp` except the one `H` group at 2 `Fp`; 2,040 fresh and adversarial challenge vectors, no failure; the pad block 246 × 256 of rank 246; and the control that fired against the reviewer's own reduction, from which the pad count and the number of opened columns move together) |
| Invariants of §4 | §4.3, end | a short list added of what an implementer must not weaken in this section — the pair-shape condition first, then pair exclusivity with `H`'s documented exception, the two `cm ≠ 0` refusals, and the pad budget; `λ_c ≠ 0` explicitly not on it for privacy |
| C-1 of `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md` (**third pass**, 2026-09-20) | §5.2 (three places), §6 item 1, §9 rows 24 and 25, and the C-5 row of this record | the 64-byte transcript absorb's overlap with the node and salted-leaf formats corrected in place from ≈ 2^-243 to **2^-241.42**: the earlier figure counted about 8,200 objects — the salted leaves of the four 2,048-leaf trees alone — leaving out `M`'s 4,096 leaves and all 12,283 internal nodes, whereas the candidates are 12,283 node inputs plus 12,288 salted-leaf inputs = 24,571, and `24,571 · 2^-256 = 2^-241.4153` [RECOMPUTED by that check, evidence `results/zk60_hash_layer_fs_lift_check/`]. Nothing else in this memo changes: the term sits about 130 bits below the dominant residual |

Items that needed no change: none of the adjudicated items was left
unapplied. Remarks of the check that are not in its errata tables were not
acted on, with one exception required by a ruling: its observation that the
completeness premise bites at the `π`-uniformity step is recorded in §3.2,
because it is the reason the reading discharges (H4) in the form Theorem 3.3
needs.

(revision complete)

