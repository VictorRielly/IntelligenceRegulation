# Independent review of the terminal-surjection step (Q0 / ruling J-2)

**Status: INDEPENDENT REVIEW of one step supplied by an earlier check —
delegated Opus agent, 2026-09-20. Paper and Python only; NOT a privacy
acceptance.**

## 0. Plain words first

The proof publishes 173 numbers called *terminals*. Each one is the value a
hidden plane takes at a random point the protocol picked. The privacy
argument needs those 173 numbers to be pure noise — to look exactly the same
whatever the private input was. Until now nobody had shown that. The
composition memo assumed it; the accepted rank lemma proved it only for the
*combinations* of terminals the proof also publishes, not for the terminals
one by one; the independent check noticed the hole, wrote a short proof of
its own, and the security owner imported that proof with a label saying "no
one has reviewed this". I am that review.

**The short answer: the step is right, and I could not break it — but as
written it names the wrong conditions, and it is not by itself enough.**

Four things came out of the recomputation.

1. **The step is true, and I proved it in a stronger form.** Not just "each
   terminal is noise on its own", which would be weak, but "all of a group's
   terminals, together with the group's published combination, are noise
   jointly, with exactly one public relation between them and nothing more".
   I verified it on every one of the real groups of all four captured
   receipts — 120 terminals on the A commitment, 51 on H, one on each
   endpoint — at the real sizes (up to 35 terminals in one group, 256
   columns), by an exact whole-number rank computation written for this
   review. Nothing is disclosed. Then I did it again at 2,040 fresh and
   deliberately nasty challenge vectors. Still nothing.
2. **The loose end — is `cw ≠ 0` refused anywhere? — has a better answer
   than a refusal.** `cw` is a public vector of column weights. It is an
   "equality tensor", and the entries of an equality tensor always add up to
   exactly 1, so the vector can never be the zero vector, at any challenge,
   with no refusal needed. It is a theorem, not a check. So there is no
   residual to list and no refusal to add. (And even the impossible case
   would not leak: if `cw` were zero the terminals would be identically
   zero.)
3. **One of the three conditions the memo cites is not needed, and two
   conditions it does not cite are.** `λ_c ≠ 0` can be dropped: I set it to
   zero on a real group and nothing leaked. What the step really needs and
   does not say is (a) that each claim's reserved pair carries the two
   weights `(cm, cm·U)` — not merely `cm ≠ 0`; with `cm ≠ 0` but the two
   weights dependent, a singleton group leaks **256 field elements** — and
   (b) that no two claims, *and no two groups*, share a masking row.
4. **On the H commitment the step's per-group form is not valid, and nobody
   had noticed.** Two of H's opening groups share the zero-sum pair. I
   redid H as one joint system: the answer is unchanged (2 field elements
   disclosed, and they are exactly the public LogUp identity that the
   statement already announces), but the per-group argument does not reach
   it and must carry the exception.

**Verdict on the label.** The step may be relabelled **"independently
reviewed"** — but only in a corrected and widened form, with the four items
above written into it. The label change is conditional on the eight changes
in §5. **None of this is a privacy acceptance.** Everything here is a rank
of an explicitly stated linear model at four captured receipts' real
challenges; the hash layer, the sampler's own bias and every shape but the
toy block and the toy attention component are untouched.

## 1. The step, stated exactly, and what the theorem needs from it

### 1.1 What is published, per commitment

From `pcs.rs::open_zk:915-944` and my own walk of the four captures
(`ts_review.py` stage 1), one hiding commitment publishes, at fixed
challenges:

| object | count on `A` / `H` / each endpoint | shape |
|---|---|---|
| a group vector `v_g` per opening group | 35 / 9 / 1 | `n + Q = 256 + 256` `Fp2` entries: the **message half** `Σ_i ρ_g[i] msg_i` and the **pad half** `Σ_i ρ_g[i] pad_i` |
| the proximity vector `v_prox` | 1 / 1 / 1 | the same 512 entries, with `ρ_prox` a fresh challenge on **every** row |
| one claim value `y_c` per claim | 120 / 52 / 1 | one `Fp2` each |
| the opened columns | 256 indices (246 / 242 / 246 and 241 distinct) | for each row, its codeword entry, plus a salt and a Merkle path |

The claim count 120 + 52 + 1 + 1 = 174 and the terminal count 173 differ by
exactly one: H's LogUp sum claim carries the compile-time value `Fp2::ZERO`
(`protocol.rs:52-62`) and is not a published terminal. That reproduces the
memo's `120 + 51 + 2 = 173`.

Claims are grouped by **column-weight key** — first occurrence of
`(point tail, column offset c0, length len)` — by `group_zclaims`
(`pcs.rs:809-833`), whose key type is `ZKey` (`:745-750`) and whose
per-part rule is `zpart_weights` (`:752-791`); the block's own pre-check
recomputes the same key with `part_key` (`private_block/protocol.rs:67-72`)
and refuses a claim whose parts disagree (`:161-163`). The group's shared
column-weight vector is `cw = zkey_weights(key)` (`pcs.rs:794-807`). The
batching coefficients `λ` and the proximity `ρ_prox` are drawn in
`zk_rhos` (`:835-856`).

The verifier's own check on a group (`verify_zk`, `pcs.rs:970-979`) is

```
  <v_g[..256], cw_g>  ==  Σ_{c in g} λ_c · y_c .
```

### 1.2 The step, as the check supplied it

> Fix one group `g` with members `c = 1..m`, shared column weights
> `cw ≠ 0`, and each claim's own reserved pair contributing
> `P_c := msg_{r_c} + U·msg_{r_c+1} ∈ Fp2^256`. The published objects that
> touch those pairs are `v = D + Σ_c λ_c cm_c P_c` and
> `y_c = d_c + cm_c⟨P_c, cw⟩`, and the verifier's check forces
> `⟨v, cw⟩ = Σ_c λ_c y_c`. Then `(P_c)_c ↦ (v, y_1..y_m)` is **onto** that
> consistency subspace whenever every `λ_c ≠ 0`, every `cm_c ≠ 0` and
> `cw ≠ 0`.

`D` and `d_c` are the data contributions; `cm_c` is the claim's mask
coefficient (§2). Surjectivity is the right currency: the observation
`O = A·b + B·d` (blinding `b`, data `d`) has a law independent of `d`
exactly when `col(B) ⊆ col(A)`, and the data contributions `(D, d_c)`
automatically satisfy the same public identity, so **if** the blinding
image is the whole consistency subspace, the data cannot move the law.
That is the sense in which the step is what the sampler's step 2 needs.

### 1.3 Is that the JOINT statement the theorem needs? Not on its own

The theorem needs the law of `V_pcs` — *all* group vectors (both halves),
the proximity vector, the 256 opened columns and *all* 173 terminals of the
four commitments, jointly — to be data-free. The supplied step is strictly
weaker in four ways, each of which I had to close separately:

* **(a) it is one group at a time.** The decomposition over groups needs
  the reserved pairs to be disjoint *across groups*, not only across claims.
  True on `A`, `Input`, `Output`; **false on `H`** (§3.4).
* **(b) it drops the proximity vector**, which `ρ_prox` puts on *every* row
  including every claim's pair. The check says it "is handled the same
  way", correctly, but that is a separate argument, not part of the
  surjection (§3.3).
* **(c) it drops the pad halves and the opened columns.** Those are the
  accepted lemma's `H-pad`; the reduction of the full view to the
  message-half system is a genuine step, and my own small-model control
  shows it is load-bearing: one opened position more than the pad budget and
  the full view discloses 2 `Fp` while the per-group reduction still says 0
  (§3.5).
* **(d) it is stated per claim ("each is uniform given the rest")**, which
  as literally written is a marginal statement. The joint statement is what
  matters, and the shared-pair counterexample is exactly a case where every
  marginal is uniform and the joint is not (§3.6).

With (a)–(d) closed the supplied step does give the joint statement for the
toy block's four PCS commitments — conditional on the lemma's `H-pad`,
`H-prox` and the corrected `H-pair`, and with H's public LogUp identity as
the single documented exception.

### 1.4 A stronger and shorter proof than the induction

The check proves the case `m = 2` and asserts "the general case is the same
induction". The induction is not needed, and the annihilator form is
sharper because it also tells you exactly what survives when a condition
fails.

> **Proposition.** With `P_c` ranging over `Fp2^256` (which is what the two
> `Fp` rows give when the pair weights are `(cm_c, cm_c·U)` and
> `cm_c ≠ 0`), the image of `(P_c)_c ↦ (v, y)` is spanned by the vectors
> `T_{c,j} = λ_c cm_c · e_{v_j} + cw_j cm_c · e_{y_c}`, one per member `c`
> and column `j`. Each has at most two non-zero coordinates. A functional
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
> construction makes `⟨D, cw⟩ = Σ_c λ_c d_c`. ∎

Three consequences the memo's version does not state: the rank is exactly
`2(256 + m) − 2` over `Fp` for **every** `m` and every `cw ≠ 0`; `λ_c ≠ 0`
is **not** needed for data-independence; and the whole argument fails if the
two rows of a pair are `Fp`-dependent, because then `P_c` does not range
over `Fp2^256`.

## 2. The step against the Rust: what `lambda_c`, `cm_c` and `cw` are, and what refuses each

Every line below was read in this repository as of 2026-09-20. The
attention component carries the same opening logic at shifted line numbers
(`private_attention/protocol.rs:62` `part_key`, `:84` `audit_claims`,
`:136` `check_opening_challenges`), and its two captures give the same
verdicts throughout §3.

### 2.1 The reserved pair and `cm_c`

`build_claim` (`argument.rs:223-236`) builds one `ZClaim` per private table
of a slot. Its last two parts are the reserved pair:

```rust
for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
    parts.push(ZPart { slice: Slice { offset: (p.mask_row + k) * N + c0,
                                      log_size: logm as u32 },
                       coef: cm.mul(u), point: tail.clone() });
}                                                   // argument.rs:232-234
```

so the two weights are **exactly** `(cm, cm·U)` — the lemma's Step 2 — and
they carry the same column key as the data parts (`tail`, `c0`), which is
why the pair sits inside the claim's own group.

`cm` itself is a product of extension challenges
(`argument.rs:356`):

```rust
let cm = es[p.ext_round + 1..].iter()
            .fold(es[p.ext_round], |a, e| a.mul(Fp2::ONE.sub(*e)));
```

i.e. `cm = e_{ext_round} · Π_{j > ext_round} (1 − e_j)` over the slot's
extension challenges `es`, which are sumcheck challenges derived from the
transcript.

**Refusal, both sides.** `argument.rs:346-349`

```rust
if es.iter().any(|e| e.is_zero() || *e == Fp2::ONE) {
    return Err("degenerate terminal mask challenge; discard attempt".into());
}
```

makes every factor of `cm` non-zero, hence `cm ≠ 0`; `run_slot` is the same
function on the prove and the verify path (`Side::Prove` / `Side::Verify`
inside it), and `argument` is called from `prove_inner`
(`protocol.rs:384`) and from `verify_inner` (`protocol.rs:450`).
Independently, the schedule audit refuses a zero coefficient on a site row
structurally (`protocol.rs:103-108`):

```rust
for r in pr.filter(|r| is_site(*r)) {
    if part.coef.is_zero() {
        return fail("zero terminal mask coefficient; discard attempt");
    }
```

and it is `check_opening` (`protocol.rs:155-175`) that calls `audit_claims`,
from the prover at `:396, :399` and from the **verifier** at `:458, :464`
(endpoints: `check_endpoint_opening:191-203`, called at `:402, :405` and
`:471`). So `cm ≠ 0` has two independent refusals, each on both sides.

`audit_claims` also gives the two structural facts the step needs and does
not state: exactly one adjacent pair per claim (`:118-122`), and that pair
used by no other claim (`:129-131`).

### 2.2 `λ_c`

`λ` is drawn per group member inside `zk_rhos` (`pcs.rs:839`,
`tr.challenge_fp2_vec(members.len())`), immediately before the proximity
challenges (`:853`). It is a Fiat–Shamir challenge, not a constant.

**Refusal, both sides.** `check_opening` replays a **cloned** transcript
prefix and draws the same sequence (`protocol.rs:173-174`), and
`check_opening_challenges` (`:141-152`) refuses:

```rust
for &count in groups {
    if (0..count).map(|_| draw()).any(|c| c.is_zero()) {
        return Err("zero group member coefficient; discard attempt".into());
    }
}
```

with the proximity determinant refused four lines later (`:147-150`,
`determinant` at `:135-137`). Same call sites as above, so prover and
verifier both enforce it.

**But it is not a condition of this step.** Control C3 (a real 35-member A
group with `λ_1 = 0`) and control A4 (a real singleton group with `λ = 0`)
both disclose **0 `Fp`** (`ts_review.json`, `ts_addendum.json`). The
refusal is there to stop a prover *discarding* a claim from the batch —
the error string says so — which is a soundness property. Citing it as one
of three privacy conditions overstates what it buys.

### 2.3 `cw` — the loose end, and why no refusal is needed

`cw` is **not** a challenge and **not** a product of challenges: it is the
public column-weight vector of the group, computed from the group's key by
`zkey_weights` (`pcs.rs:794-807`):

```rust
if k.tail.is_empty() {
    for c in col_w[k.c0..k.c0 + k.len].iter_mut() { *c = Fp2::ONE; }
} else {
    let eq_c = eq_table_msb(&k.tail);
    col_w[k.c0..k.c0 + k.len].copy_from_slice(&eq_c);
}
```

Two cases, and **in both `cw ≠ 0` is a theorem, not a check**:

* **empty tail** (a sum claim): `cw` is all-ones on `len ≥ 1` positions, so
  `Σ_j cw_j = len`, an integer between 1 and 256 and therefore non-zero in
  `Fp` (`p = 2^64 − 2^32 + 1`).
* **non-empty tail** (every evaluation claim): `cw` is the equality tensor
  `eq_table_msb(tail)` (`mle.rs:48-51`, built by `eq_table`, `:13-45`).
  `eq_table` starts from the single entry `1` and repeatedly splits each
  entry `e` into `(e(1−r), e·r)`; that operation preserves the total. So
  `Σ_j cw_j = Π_i ((1 − r_i) + r_i) = 1` **for every point whatsoever**.
  A vector summing to 1 is not the zero vector.

So there is no refusal to cite because none is needed, and there is no
event to bound: `cw = 0` has probability **exactly zero**, not
`2^{-something}`. Measured on all sixteen role-captures
(`ts_review.py` stage 1): every group's `cw` sums to `1` (eq groups) or to
`len` (all-ones groups) — `cw_sums_to_one_or_len: true` — with support
between **32 and 256** entries and never 0.

Two boundary readings, for completeness:

* **the worst admissible `cw`.** Nothing refuses a sumcheck *main-round*
  challenge equal to 0 or 1 (only the *extension* challenges are refused,
  `argument.rs:346-349`). A tail whose coordinates all land in `{0, 1}`
  makes `cw` a single 1 — support 1 out of 256. The step survives:
  control C6 and the `delta_cw` family of stage 4 (408 draws across the 8
  real group shapes) are all surjective, because the proof needs only "some
  `cw_j ≠ 0`". Probability of reaching it by chance is about
  `(2/p²)^k ≈ 2^{-127k}` per group with `k` tail coordinates — not a
  residual worth listing.
* **the impossible `cw = 0`.** Even then nothing is disclosed: control C5
  drops the rank from 580 to 512 but the disclosure stays **0**, because a
  zero `cw` zeroes the claim's *data* part too — the terminal becomes
  identically zero. The receipt would be rejected (the sumcheck's masked
  terminal is not zero), so this is a completeness failure, not a leak.

**Conclusion on the loose end: `cw ≠ 0` is neither a privacy residual nor a
missing refusal. It is an unconditional public fact and should be recorded
as one** (change R-2 in §5).

### 2.4 The blinding rows really are uniform

The step assumes the mask rows are uniform over all 256 message positions
and the pads uniform. Read, not assumed:
`protocol.rs:313-315` fills `a_data` from `lay.a_mask_base * N` to the end
with `rng.fp()`; `:361-363` does the same for `h_data`; `:364-372`
then overwrites H's two zero-sum rows with `N − 1` uniform values and the
negated sum, which is exactly the `Σ_j msg_j = 0` constraint my model
carries; `pcs.rs:673` draws `rows * q` pad symbols. The randomness source
is one `ZkRng::from_os` per proof (`protocol.rs:275`).

## 3. The recomputation

Evidence: `results/zk60_terminal_surjection_review/` — `ts_field.py`
(Goldilocks / `Fp2` arithmetic, an exact sparse eliminator and an
independent dense one), `ts_review.py` (stages 0–5, output
`ts_review.json`, log `ts_review.log`), `ts_addendum.py` (A1–A5, output
`ts_addendum.json`), `ts_components.py` (output `ts_components.json`).
Nothing is imported from `scripts/zk60_native_*`: `zpart_weights`,
`zkey_weights`, `group_zclaims`, `eq_table_msb` and the coset encoding
functional were re-derived from the Rust for this review, and the four
captures were parsed directly. No witness value, salt or private plane is
copied anywhere; the captures contain none.

**The model**, stated once. Row `i` holds `msg_i ∈ Fp^256` and
`pad_i ∈ Fp^256`; `msg_i` is data on the data rows and uniform on the mask
and proximity rows (uniform subject to a zero row sum on H's two `u` rows);
`pad_i` is uniform on every row. The observation is affine,
`O = A·b + B·d`, and I report

```
rank(A)                 the blinding rank
rank([A|B]) − rank(A)   = dim(F ∩ T) = "disclosed", in Fp
```

Everything is over `Fp` (not `Fp2`): the unknowns are `Fp` entries, which is
what makes the `(cm, cm·U)` pair shape load-bearing rather than cosmetic.

**Predictions, recorded before the runs.** honest groups: rank
`2(256+m) − 2`, disclosed 0 on `A`, `Input`, `Output`; H: 2 `Fp` somewhere,
being the public LogUp identity. Shared pair: fires, 2 `Fp`. `cm = 0`:
fires. `λ = 0`: **does not** fire (my prediction, against the memo's list).
`cw = 0`: does not fire (terminal identically zero). Equal `λ`: does not
fire. All six were borne out.

### 3.1 Stage 0 — the tools

The sparse eliminator is checked against the dense one on 60 random sparse
systems: **0 disagreements** (`stage0_eliminator_selftest`).

### 3.2 Stage 1 — the real schedule satisfies every hypothesis

All sixteen role-captures (four receipts × four commitments), full scale,
`findings: []` on every one:

| | `A` (block) | `H` (block) | endpoints |
|---|---|---|---|
| rows / data rows | 455 / 213 | 384 / 278 | 7 / 2 |
| claims / groups | 120 / 35 | 52 / 9 | 1 / 1 |
| group sizes | 1×17, 2×11, 3, 6, 7, 8, 11×2, **35** | 1×3, 3, 6×2, 7, 8, **19** | 1 |
| recomputed grouping = capture's | yes | yes | yes |
| `cw` non-zero, sums to 1 (or `len`) | yes, support 32…256 | yes, support 256 | yes |
| `λ` zero | 0 of 120 | 0 of 52 | 0 of 1 |
| reserved pairs used / exclusive | 120 / yes | 52 / yes | 1 / yes |
| pair weights **exactly** `(cm, cm·U)` | 120 | 52 | 1 |
| `cm ≠ 0`, `Norm(cm) ≠ 0` | yes | yes | yes |
| proximity pair `wedge ≠ 0` | yes | yes | yes |
| `⟨v, cw⟩ = Σ λ y` failures | 0 | 0 | 0 |
| `ρ_g = Σ_c λ_c rw_c` failures (all rows) | 0 | 0 | 0 |

The last row matters: it is the identity that makes the *data* satisfy the
same public relation as the blinding, and it is the whole reason the
annihilator argument closes.

### 3.3 Stage 2 — the surjection, at the real schedule

For every group of every role of all four captures I built the `Fp`-linear
system of §1.4 (observations: all 256 message entries of the group vector,
plus the group's individual claim values; generators: one per
`(row, column)` unit of `msg`), and computed the exact rank.

* **`A`, `Input`, `Output`, all four captures: every group surjective**,
  rank `2(256+m) − 2` exactly, **disclosed 0 `Fp`**. 35 groups on the
  block's `A` (largest 35 members), 30 on attention's `A`.
* **`H`: eight of nine groups surjective, disclosed 0.** The ninth (the
  LogUp sum claim on the zero-sum pair) has rank 510 instead of 512 and
  **discloses 2 `Fp`**.
* The exhibited annihilator — the verifier's own identity — kills **every**
  blinding generator and **every** data generator of every group, on all
  four captures. Where the blinding rank attains `2(256+m) − 2` that is a
  two-sided certificate: the identity is the *whole* left null space, so the
  blinding image is exactly its kernel and the data lies inside it. On H's
  one short group the identity is only part of the left null space, which is
  why that group needs the separate treatment of §3.4.

Dense cross-check (stage 2b), on five real groups (`A` m=1 and m=35, `H`
m=1 and m=19, `Input` m=1): the dense rank of a sufficient subset equals the
sparse rank of all generators equals `2(256+m) − 2` in every case. Upper
bound from the annihilator plus lower bound from the dense minor pins the
rank exactly without reducing 17,920 dense rows.

The proximity vector was handled separately, as the check says it should be
(addendum A2): **no claim and no group combination touches a proximity row**
on any of the sixteen role-captures, and the proximity pair **alone** has
rank 512 on the proximity vector — i.e. it maps onto `Fp2^256`. Conditional
on everything else, the proximity vector is therefore uniform and drops out.
That is a proof, not an appeal.

### 3.4 The finding the per-group form misses: H's two groups share a pair

Addendum A2 asked whether the groups' non-data supports are pairwise
disjoint, which is what licenses treating one group at a time.

* `A`, `Input`, `Output`: **disjoint**, every capture.
* **`H`: not disjoint.** Two opening groups both touch the zero-sum rows —
  the `zsum` slot's claim *evaluates* them, and the LogUp sum claim is
  *masked* by them. The per-group decomposition is therefore invalid on H,
  and no document had said so.

I redid H as connected components of "two groups share a non-data row"
(`ts_components.py`). The component `{7, 8}` (block) / `{6, 7}`
(attention) as **one** system: 1,028 `Fp` observations, blinding rank 1,022,
with data 1,024 — **disclosed 2 `Fp`**, the same as the per-group sum. So
the number is unchanged and the earlier gate's `H = 2` stands; but it stands
because of this joint computation, not because of the per-group argument.

And addendum A1 settles what those 2 `Fp` are: I computed the left null
space of the component's blinding block, pushed it through the data block,
and compared the span with the span of the sum claim's own data-row weights
— the public LogUp identity. `rank(disclosed) = rank(public identity) =
rank(both together) = 2` on **all four captures**. The disclosure is the
identity the public statement already announces, not a new channel.

### 3.5 Stage 5 and addendum A5 — the columns and the pad halves

The per-group system uses only the message half. The reduction that
licenses this is:

> Because the group vectors' pad halves and the opened columns enter only
> through the same per-row encoding, any functional that vanishes on all
> blinding coordinates must put, on each row `i`, the column coefficients
> `α_{·,i} = −ρ[i]·w` for one common `w` solving `Σ_j w_j E_j^{pad} = δ`
> (the functional's pad-half part). Then
> `Σ_j α_{j,i} E_j^{msg} = −ρ[i]·u` for a single vector `u`, and the whole
> system collapses to the message-half system with the group functional
> shifted by `u`. The solvability and uniqueness of `w` is exactly
> **H-pad**: the pad block must have rank equal to the number of **distinct**
> opened positions.

Checked, at the real captures (stage 5):

* the fold identity `Σ_i ρ[i]·col_j[i] = ⟨v, E_j⟩` — my own re-derivation of
  `encode_row_zk` (`pcs.rs:617-637`) — **200 identities checked across the
  four roles, 0 failures**, so the model of `E_j` is the verifier's;
* the pad block at `A`'s real opened positions: **246 distinct positions ×
  256 pads, exact rank 246, full**. (`H` 242, endpoints 246 / 241
  distinct, all within the 256-pad budget.)

And the reduction itself is validated against brute force on my own small
model (addendum A5): `n = 4` message columns, `q = 4` pads, 16 encoded
positions, 12 rows, **a group with three members and a group with one** —
the multi-member case the project's own small model
(`zk60_native_jv_smallmodel`, one group per claim) has never carried. 8
seeds × 5 modes:

| mode | disclosed, full brute force | disclosed, my per-group reduction | agree |
|---|---|---|---|
| honest | 0 | 0 | yes |
| shared pair | 2 | 2 | yes |
| `cm = 0` | 2 | 2 | yes |
| `λ = 0` | 0 | 0 | yes |
| **one opened position more than pads** | **2** | 0 | **no** |

The last row is a control against **my own** reduction and it fires: the
message-half reduction is only valid inside the pad budget. On the real
captures the budget holds with margin (246 ≤ 256), and `pcs.rs:670`
(commit) / `pcs.rs:963-965` (verify) refuse fewer pads than column checks
— but the reduction's dependence on it should be stated, not assumed.

### 3.6 Stage 3 and addendum A3/A4 — the controls, at the real schedule

Each control is the real A (or H) group with one thing changed.

| control | group | blinding rank | disclosed `Fp` | fires? |
|---|---|---|---|---|
| honest, m = 2 | A g3 | 514 | 0 | — |
| honest, m = 35 | A g23 | 580 | 0 | — |
| **C1 two claims share one pair** | A g3 | 512 | **2** | yes |
| **C1 same, in the 35-member group** | A g23 | 578 | **2** | yes |
| **C2 `cm = 0`** (pair removed), m = 35 | A g23 | 578 | **2** | yes |
| C3 `λ_c = 0`, m = 35 | A g23 | 580 | 0 | **no** |
| C4 all `λ` equal | A g23 | 580 | 0 | no |
| C5 `cw = 0` (impossible) | A g23 | 512 | 0 | no |
| C6 `cw` a single 1 | A g23 | 580 | 0 | no |
| C8 pair weights `Fp`-dependent, m = 35 | A g23 | 580 | 0 | no |
| **A3 pair weights `Fp`-dependent, singleton** | A g0 | 256 | **256** | yes |
| **A4 `cm = 0`, singleton** | A g0 | 0 | **512** | yes |
| A4 `λ = 0`, singleton | A g0 | 2 | 0 | no |

Three readings:

* **the shared-pair counterexample reproduced at the real scale.** With
  claims 5 and 16 of A moved onto one pair: each terminal's **marginal** is
  still fully blinded (rank 2 on each one alone), but the **joint** rank of
  the two terminals drops from 4 to 2 and rises back to 4 once the data is
  added — the joint law moves with the witness while both marginals do not.
  That is exactly the project's counterexample, and it is why "each is
  uniform given the rest" must be stated jointly.
* **`cm ≠ 0` is not the right condition; `(cm, cm·U)` is.** Control C8
  keeps `cm ≠ 0` but makes the pair's two weights `Fp`-dependent. In a
  35-member group the other members cover the loss and nothing leaks — but
  in a **singleton** group the same change discloses **256 `Fp`**, and
  removing the pair entirely discloses **512 `Fp`** (the whole message half
  of the group vector; the earlier check's singleton control reported the
  same 512). The condition that has to be in the statement is the pair
  shape, which `build_claim:232-234` gives and `audit_claims` +
  `_check_pair_schedule` check by a determinant.
* **`λ_c ≠ 0` does not belong in the list**, as predicted.

### 3.7 Stage 4 — fresh and adversarial challenges

The eight distinct real group shapes of the block's `A`
(m = 1, 2, 3, 6, 7, 8, 11, 35), five challenge families each — uniform
`λ` with a uniform eq tail, all `λ` equal, `λ` the powers of one challenge,
a `{0,1}` tail (so `cw` is a single 1), and a half-`{0,1}` tail — at the
group's real column geometry:

**2,040 challenge vectors, 0 non-surjective.** No family is refused
anywhere in the protocol, and none of them breaks the step.

## 4. Verdict on the label

**The step may be relabelled from "supplied by the independent check;
verified by its script; not independently reviewed" to "independently
reviewed and corrected (2026-09-20); proved for every group of the four
captured receipts; conditions restated" — once the changes of §5 are
made, and not before.** The relabelling is conditional, in this order:

1. the corrected condition list replaces the three the memo carries
   (`(cm_c, cm_c·U)` in, `λ_c ≠ 0` out, `cw ≠ 0` proved rather than
   refused) — R-1, R-2, R-3;
2. the statement is joint, not per claim, and its scope names the three
   things it does **not** cover on its own (the proximity vector, the pad
   halves and the opened columns, and cross-group disjointness) — R-4;
3. H's exception is written down — R-5.

Without those, the label should stay as it is: the sentence in the memo is
not, as written, a theorem I can sign — it names a condition that is not
needed, omits one whose failure costs 256 `Fp`, and asserts a per-group
decomposition that is false on one of the two big commitments.

What I can sign, positively:

* the step's **conclusion** is correct and holds at the real schedule, in
  the strong joint form, at every group of all four captures and at 2,040
  further challenge vectors, with disclosure exactly 0 except for H's 2
  `Fp`, which are the public LogUp identity;
* the check's own script's numbers (`rank = 2·ncol + 2m − 2`, and the
  singleton `cm = 0` control collapsing to 0 / 512 `Fp`) **reproduce** at
  the real sizes, which its synthetic `ncol = 5`, `m ∈ {1, 2, 4}` instance
  could not show;
* the annihilator proof of §1.4 replaces the `m = 2` induction and is
  shorter, exact for every `m`, and diagnostic when a condition fails.

**Should the accepted generic-rank lemma's statement be widened?** Yes.
`ZK60_GENERIC_RANK_LEMMA.md` §1.1 puts "each claim value" in the functional
space `F`, §1.2 asserts as part of the reduction that under `H-pair` the
claim values collapse into the group combinations, and §1.3/§3.2 then prove
the good event **only** for the `2(G+1)` group and proximity generators.
The collapse is the missing link, and it is a one-paragraph proof (§1.4
here). It belongs in §3.2 as a Step 6, with the exception of §3.4 here. I
would not widen the *good event* (the `g × g` minor) — that is fine as it
is; I would widen the *reduction's* proof.

## 5. Required changes

| # | where | change |
|---|---|---|
| **R-1** | `ZK60_JOINT_LAW_COMPOSITION.md` §4.3, the quoted block | Replace the three conditions. Required: **`cm_c ≠ 0` and the pair weights exactly `(cm_c, cm_c·U)`** (an `Fp`-basis of `Fp2`; `build_claim` `argument.rs:232-234`, refused by `audit_claims` `protocol.rs:103-108` and by the determinant check of the gate), **the reserved pair exclusive to that claim and to that group** (`audit_claims:118-122, :129-131`), and **`cw ≠ 0`**. Drop `λ_c ≠ 0` from the conditions and note in one line that the refusal `protocol.rs:142-146` exists for soundness (it stops a claim being discarded from the batch) and that the conclusion survives `λ_c = 0` — verified, disclosure 0. |
| **R-2** | same block, the `cw ≠ 0` sentence | Delete "the check records this one as given by a refusal too, but does not pin it to a line". Replace with the proof: `cw = zkey_weights(key)` (`pcs.rs:794-807`) is either all-ones on `1 ≤ len ≤ 256` positions (sum `= len ≠ 0`) or the equality tensor `eq_table_msb(tail)` (`mle.rs:13-51`), whose entries sum to exactly 1 at **every** point because `eq_table` splits each entry `e` into `(e(1−r), e·r)`. **No refusal is needed, and `cw = 0` has probability zero, not `2^{-k}`.** There is no new privacy residual. Measured on all sixteen role-captures: support 32…256, sum 1 or `len`. |
| **R-3** | same block, the proof | Replace the `m = 2` induction with the annihilator proof (§1.4 here): the image is spanned by two-support vectors `λ_c cm_c e_{v_j} + cw_j cm_c e_{y_c}`, whose common annihilator is exactly the verifier's identity line, so the image is that identity's kernel for **every** `m`. State the rank as `2(256 + m) − 2` over `Fp`. |
| **R-4** | same block, a new sentence before the label | Say what the step does **not** give on its own: it is one group's message half. The joint statement additionally needs (i) reserved pairs disjoint **across groups**, (ii) the proximity pair exclusive with `wedge ≠ 0`, which makes the proximity functional vanish identically, and (iii) the lemma's **`H-pad`**, which is what lets the pad halves and the opened columns be dropped — load-bearing: one opened position beyond the pad budget discloses 2 `Fp` that the message-half reduction does not see. |
| **R-5** | same block, and `ZK60_GENERIC_RANK_LEMMA.md` §3.3 | Record H's exception: **two of H's opening groups share the zero-sum pair**, so the per-group decomposition is invalid there. Computed jointly the disclosure is 2 `Fp` and equals the public LogUp identity (independently re-verified here on all four captures by span equality). Cite the joint computation, not the per-group one. |
| **R-6** | `ZK60_GENERIC_RANK_LEMMA.md` §3.2 | Add **Step 6**: under Steps 1–4, the individual claim values add nothing to `F ∩ T` beyond the group combinations and one public identity per group — with the §1.4 proof — and note the exception of R-5. This turns the reduction's silent assumption into a proved step and removes one RELIES-ON. |
| **R-7** | `ZK60_JOINT_LAW_COMPOSITION.md` §9 row 33, §8 Q0, and the errata table | Relabel row 33 to "**independently reviewed** (2026-09-20), corrected: conditions restated, joint form, H exception; proved for every group of the four captures and 2,040 further challenge vectors", cite `docs/zkmatrix-poc/ZK60_TERMINAL_SURJECTION_REVIEW.md` and `results/zk60_terminal_surjection_review/`, and close Q0 with the three answers (the `cw` proof, the `λ` demotion, the `(cm, cm·U)` promotion). Keep "not a privacy acceptance". |
| **R-8** | the joint-view gate (owner's call, code change — **not** made here) | The gate's own small model (`zk60_native_jv_smallmodel`) validates the reduction only with **one group per claim**, so the `λ`-batched multi-member case — the whole subject of this step — has never been machine-validated inside the gate. Add a multi-member group (and a group sharing a pair with another group) to it. The toy profile is byte-frozen and this changes no proof bytes: it is a test-side addition only. |

Two notes on scope of R-1…R-8: none of them changes a byte of any accepted
receipt, and none of them is a new refusal. The only candidate for a new
refusal — `cw ≠ 0` — turns out to need none.

## 6. What I could not check

* **The hash layer.** Salts, Merkle paths, leaf digests and the
  Fiat–Shamir lift are outside this review, as they are outside the memo's
  own claim. Everything here is a statement about field values at fixed
  challenges.
* **The masking commitment `M`.** Its opening (`q`, `prox`, its own
  columns) is Lemma 3.1 / Theorem 3.3 territory and a different shape; I
  did not touch it. The step under review concerns the four PCS
  commitments only.
* **Cross-role independence.** That `A`, `H` and the two endpoints draw
  disjoint randomness is condition O-2 of the composition memo, verified in
  the code there and not re-verified here; my per-commitment computations
  assume it.
* **Any shape but the toy block and the toy attention component.** The
  structural facts (one exclusive pair per claim, the `(cm, cm·U)` shape)
  are enforced by code that runs on every profile, but the numbers are the
  four captures of 2026-09-19 at those receipts' challenges.
* **The captured challenges themselves.** I took `λ` and `ρ_prox` from the
  capture rather than replaying BLAKE3. That is not blind trust: the
  captured `λ`, `cw`, group vectors and claim values are tied together by
  the verifier's identity `⟨v, cw⟩ = Σ λ y`, which I recomputed and which
  fails for wrong values — 0 failures on all sixteen role-captures. A
  transcript replay would additionally show they are the challenges the
  transcript produces; `scripts/zk60_native_joint_view.py` stage 1 does
  that and I did not repeat it.
* **Whether the sampler as printed now computes the right `θ`-order.**
  Correction C-1 of the earlier check; not in scope here.
* **`k0 = 0` on the group generators.** That is the accepted lemma's
  result; I verified the pieces the terminals step needs, not the lemma.

## 7. Evidence

Under `results/zk60_terminal_surjection_review/`. Re-runnable with no
arguments; ~2 minutes for the first, seconds for the others.

| file | what it holds |
|---|---|
| `ts_field.py` | Goldilocks / `Fp2` arithmetic, `eq_table_msb`, an exact sparse eliminator and an independent dense one |
| `ts_review.py`, `ts_review.json`, `ts_review.log` | stage 0 eliminator self-test (60 random systems, 0 disagreements); stage 1 the structural audit of all sixteen role-captures; stage 2 the per-group surjection with its annihilator certificate; stage 2b the dense cross-check on five real groups; stage 3 the controls; stage 4 the 2,040 fresh and adversarial challenge vectors; stage 5 the fold identity (200 checked, 0 failures) and the pad block (246 × 256, exact rank 246) |
| `ts_addendum.py`, `ts_addendum.json` | A1 H's 2 `Fp` = the public LogUp identity, all four captures; A2 the assembly premises (cross-group disjointness, proximity exclusivity, the proximity pair onto `Fp2^256`); A3/A4 the singleton controls (256 `Fp` and 512 `Fp`); A5 my own small model, full view by brute force vs the reduction, 40 instances |
| `ts_components.py`, `ts_components.json` | H's two groups that share the zero-sum pair, ranked as one system |

Inputs, read-only: the four captures of
`results/zk60_native_captures_20260919/captures/` (source commit
`2b5c65c3c430d6d6dd7ac24ab0c115181e36ca75`, `fully_verified: true`,
`privacy_review_complete: false`). Nothing outside the evidence directory
and this document was written.

**(review complete)**
