# Independent adversarial check of the generic-rank lemma (U-3a)

**Status: INDEPENDENT ADVERSARIAL CHECK of a delegated draft lemma —
delegated Opus agent, 2026-09-20. Paper and Python only; NOT a privacy
acceptance.**

Target: `docs/zkmatrix-poc/ZK60_GENERIC_RANK_LEMMA.md` (commit 8556f08) with
its evidence `results/zk60_generic_rank_lemma/`.
Own evidence: `results/zk60_generic_rank_lemma_check/` —
`check_pair_factorisation.py` / `factorisation_smoke.txt`,
`check_adversarial_challenges.py` / `adversarial.txt`,
`check_channels_and_numbers.py` / `channels_and_numbers.txt`,
`check_u_row_term.py` / `u_row_term.txt`.
No witness value, salt or private plane is reproduced anywhere; only
dimensions, row indices, ranks, counters and locally drawn challenges.

Labels, kept sharp: **VERIFIED IN THE CODE** (file:line I read myself),
**RECOMPUTED** (my own script), **MY OWN ARGUMENT** (paper, mine, labelled),
**COULD NOT VERIFY**.

**Headline.** The draft's central claim survives, and survives on stronger
evidence than the draft itself offers: I rebuilt the factorisation from the
**real** captured claim schedules (not a synthetic model) at fresh
challenges and found no mismatch. Four things in the draft are wrong or
under-supported: one negative-control reading that is false at the real
schedule, two missing load-bearing citations (the `assert!`s that make
`part_rows` correct, and the `d+1`-values-per-round check that makes
`dim ker R = 1`), one uncited enabling hypothesis for §3.3 that fails at
125M, and a rhetorical overstatement of the Schwartz–Zippel fallback. The
scope section is the weakest part of the document.

---

## 1. The good event: what `k0` is, and whether `k0 = 0` means what the lemma needs

### 1.1 What the tool actually computes — the draft's §1.3 is accurate

**VERIFIED IN THE CODE.** `_p1_rows`
(`/home/victor/wt-zk60-jointview/scripts/zk60_native_jv_pcs.py:419-426`)
returns, for each of the `G` group combinations `rho_g` and for
`prox_rho`, the two Fp vectors `[v[0] for v in rho]` and
`[v[1] for v in rho]` — the real and imaginary parts. `_disclosed`
(`:427-432`) then sets

```
r1      = rank_Fp(gens, rows)
r_other = rank_Fp(gens restricted to other_rows, len(other_rows))
k0      = r1 - r_other
```

so `k0` is an **Fp** rank difference of the realification of `2(G+1)`
generators. The draft's §1.3 statement, and its implication
"`rank(gens | non-data) = g` implies `k0 = 0`", are correct: restriction
cannot raise a rank, `rank(gens) <= g` by row count, so both equal `g`.
**The draft is right here.**

`other_rows` is `[r for r in range(rows) if kinds[r] != "data"]`
(`:209`), and `u_rows` comes from the capture's
`public_linear_constraints` (`:211-213`). **RECOMPUTED** from the
captures: H is `278` data / `104` mask / `2` prox, and the layout's `u`
pair `(278, 279)` is inside the `mask` class, so the draft's
"278 data / 106 non-data" for H is right even though
`Layout::h_data_rows` is `280`
(`hashline/src/private_block/layout.rs:525, 583-586`). Worth a footnote in
the draft: the tool's "data rows" and the Rust `h_data_rows` are two
different numbers.

### 1.2 Does `k0 = 0` mean what the privacy argument needs?

Here is the exact linear-algebra fact, and I could not find it stated
anywhere in the draft, so I state and prove it. **MY OWN ARGUMENT.**

Let `L : X -> V` be the whole field-valued observation map on
`X = Fp^{rows x 512}`, split `X = D (+) R` into the data rectangle and the
rest, `L = L_D + L_R`. Let `F = rowspace(L)` (functionals on `X`) and `T`
the functionals supported on `D`. Then

> `F ∩ T = {0}`  ⟺  `Im(L_D) ⊆ Im(L_R)`  ⟺  for `r` uniform on `R`, the
> law of `L(d, r)` is the **same** for every `d`.

*Proof.* `psi L_R = 0` says `psi L` vanishes on `R`, i.e. `psi L ∈ F ∩ T`;
`F ∩ T = 0` then forces `psi L = 0`, hence `psi L_D = 0`. So every
functional killing `Im(L_R)` kills `Im(L_D)`, i.e. `Im(L_D) ⊆ Im(L_R)`.
Conversely if `phi = psi L ∈ F ∩ T` is nonzero then `psi L_R = 0` while
`psi L_D ≠ 0`, and `psi(L(d,·))` is the constant `psi L_D d`, which moves
with `d`. And for `r` uniform on all of `R`, `L(d,r)` is uniform on the
coset `L_D d + Im(L_R)`, which is independent of `d` exactly when
`Im(L_D) ⊆ Im(L_R)`. ∎

So the tool's `disclosed = dim_Fp(F ∩ T)` **is** the right quantity: zero
means the view's conditional law is identical for every data vector. That
is uniformity, not merely a rank equality. Good.

But three riders, and the draft states only the first:

1. **The reduction is the load-bearing step, not the rank.** What the
   lemma proves is `k0 = 0`; `disclosed = 256 k0 + u-term` is the tool's
   *reduction*, and the draft labels it RELIES ON (label 14). Since the
   whole privacy meaning lives in the reduction and not in `k0`, that
   label should be promoted to a top-level caveat in §3.1, not buried in a
   table row. **I did re-derive the reduction** (see 4.4 below) and it
   holds under H-pad; the draft should say so or cite a derivation rather
   than leaning on a docstring and a small-model cross-check.
2. **`r` is not uniform on all of `R`.** H's two `u` rows are drawn as
   255 fresh Fp plus a pinned last entry
   (`hashline/src/private_block/protocol.rs:364-372`, **VERIFIED IN THE
   CODE**: `for j in 0..N-1 { h_data[r*N+j] = rng.fp() }` then
   `h_data[r*N+N-1] = sum.neg()`). That is exactly why the u-row term
   exists. Every other non-data row IS fully uniform (`:361`,
   `for x in &mut h_data[lay.h_mask_base*N..] { *x = rng.fp(); }`). The
   draft never states the uniformity source; it should cite these two
   lines, because the whole argument is vacuous without them.
3. **The statement is per commitment, not joint.** The fact above is about
   one `L`. Applying it four times gives four marginal statements, not one
   joint statement. The draft is honest about this (gap 17, §4 item 3) but
   the plain-words §0 says "the same answer holds for essentially all
   draws" without the word "per commitment". A reader will over-read it.

### 1.3 Verdict on attack 1

The good event is correctly identified and correctly shown to imply
`k0 = 0`. The *meaning* of `k0 = 0` is genuinely uniformity-of-the-view,
but that is my derivation, not the draft's; the draft proves the rank fact
and points at a docstring for the rest.

---

## 2. The factorisation

### 2a. Do a claim's data weights ever reach a non-data row? (`part_rows`, `div_ceil`)

This is the attack the draft itself flags first (§6 item 1). **The answer
is no, and the reason is not the one the draft gives.**

**VERIFIED IN THE CODE.** `zpart_weights`
(`zkp-core/src/pcs.rs:752-792`) writes row weights in exactly two shapes:

* `ls >= log_cols`: `assert!(p.slice.offset % n == 0)` then
  `row_w[r0 + i]` for `i in 0..2^(ls-log_cols)`;
* `ls < log_cols`: `assert!(c0 + (1usize << ls) <= n)` then `row_w[r0]`
  only.

`part_rows` (`hashline/src/private_block/protocol.rs:74-77`) returns
`r0 .. r0 + (1<<ls).div_ceil(N)`, which is `2^(ls-log_cols)` rows in the
first case and exactly one row in the second. **So `part_rows` is
*exactly* the support of `zpart_weights`, and the `div_ceil` rounding is
correct — but only because of those two `assert!`s.** A straddling slice
(`offset % n + 2^ls > n`) would make `part_rows` under-report by one row,
and `audit_claims` would then miss a spill; what saves the code is that
`zpart_weights` **panics** in that case rather than silently spilling.
Rust `assert!` is unconditional in release builds, so this is a real
guard, not a debug one.

**This is a missing citation in the draft.** §2.2 and label 2 say the
weights are where they are "read off `zpart_weights:752-792`" but never
mention that `part_rows`' correctness is conditional on the two asserts;
§6 item 1 tells the checker to "attack `part_rows` and the `div_ceil`
rounding first" without saying what makes it safe. Correction C-1.

**RECOMPUTED** (`check_pair_factorisation.py`, `factorisation_smoke.txt`),
plane by plane and part by part, on all **16 role-captures** — that is,
every part of every claim, not a sample:

| role | parts checked | `part_rows` exact | over | under | straddling |
|---|---:|---:|---:|---:|---:|
| block A | 360 | 360 | 0 | 0 | 0 |
| block H | 306 | 306 | 0 | 0 | 0 |
| block Input / Output | 3 / 3 | 3 / 3 | 0 | 0 | 0 |
| attention A | 225 | 225 | 0 | 0 | 0 |
| attention H | 210 | 210 | 0 | 0 | 0 |
| attention Input / Output | 3 / 3 | 3 / 3 | 0 | 0 | 0 |

and `claims_touching_prox_or_bad = 0`, `pairs_shared = 0` everywhere.

**VERIFIED IN THE CODE**, independently of the captures, that no
straddle is constructible at the toy layout: every A plane offset is
`row * N` and every H plane offset is `(row*N, (row+r)*N)`
(`layout.rs:563-585`); the only sub-row offsets come from
`a_slice(...)`, whose five call sites are `limb_off(kk)` and
`limb_off_m(kk)` with `k < 9` and `T = 32` (`argument.rs:574,580`,
`layout.rs:644-649`), and `a_off[A_D] / a_off[A_DM] / a_off[A_MX] /
a_off[A_SUM]` (`argument.rs:709,710,842,843`). `limb_off(k) % 256 = 32k`
with `32k + 32 <= 256` for `k <= 7`, and `k = 8` lands on `c0 = 0` of the
plane's second row. No straddle.

**One residual the draft does NOT cover, and neither does
`audit_claims`.** `audit_claims` only counts rows that satisfy
`is_site(r)` — i.e. rows of `site_rows`. For H, `check_opening` passes
`lay.h_site_rows()` (rows 280..381) as `site_rows` and the `u` pair
(278, 279) separately as `sum_rows`
(`protocol.rs:399` prover, `:464` verifier). **A data part landing on rows 278-279 is
therefore invisible to `audit_claims`.** And such a claim exists: plane
`H_U` is evaluated as an ordinary claim at `argument.rs:899` (`b.h(H_U)`).
**RECOMPUTED**: `claims_evaluating_u = 2` on every H capture (the sum
claim plus that one). This is exactly the draft's own open question 7,
and the draft leaves it unresolved ("I did not verify that no *other*
plane ... adds to those weights"). The honest answers are:

* **no other *plane* does** — `h_off` is built by a strictly increasing
  cursor and `H_U = 50` is the last of `N_H = 51`, `h_dom(H_U) = Dom::Tab`
  with `log = 8`, hence exactly rows 278 and 279
  (`layout.rs:239, 241-252, 91-99, 576-583`) — **VERIFIED IN THE CODE**;
* **but another *claim* does**, and it does not break anything: that claim
  sits in a group with a non-empty key, and §3.3 step 3 forces that
  group's coefficients to zero before the u-row equation is reached.
  **RECOMPUTED** (`u_row_term.txt`): at fresh challenges the solved u-row
  combination uses **only** generators `{16,17}` on block H and
  `{14,15}` on attention H — precisely the Re/Im pair of the sum claim's
  own group, which is a **singleton** on all four captures.

So the conclusion stands, but the draft's reasoning route is wrong and
its own doubt is left open when it is cheaply closable. Correction C-2.
The tool, incidentally, already handles this explicitly and says so in a
comment (`zk60_native_jv_pcs.py:377-380`) — the draft did not read it.

### 2b. `U`, the reserved pair, and the 2x2 determinant

**VERIFIED IN THE CODE.** `U = Fp2::U = (0,1)` with `u^2 = 7`
(`zkp-core/src/field.rs:10-15, 131-141, 163, 177`); `NONRESIDUE = 7`, and the
same constant is the coset shift and the multiplicative generator of Fp*.
`build_claim` (`hashline/src/private_block/argument.rs:223-236`) pushes
exactly two mask parts,

```
for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
    parts.push(ZPart { slice: Slice { offset: (p.mask_row + k) * N + c0,
                       log_size: logm as u32 }, coef: cm.mul(u), point: tail });
}
```

with `logm = min(p.log, LOG_N)` and `c0 = slices[0].0 % N` when
`p.log < LOG_N`, else 0. Both parts have `ls <= LOG_N`, so each writes
**one** row weight. `U` is therefore a single fixed public constant, the
same for every pair, in every profile, nonzero, with `Im(U) = 1`.

**MY OWN ARGUMENT, by hand, in the code's representation.** For
`x = (c0, c1)`, `xU = (c0 + c1 u)u = 7c1 + c0 u = (7c1, c0)`, so

```
wedge(x, xU) = c0 * c0 - c1 * 7c1 = c0^2 - 7 c1^2 = Norm(x).
```

Multiplication by `lambda = (l0, l1)` is the Fp-linear map with matrix
`[[l0, 7 l1], [l1, l0]]` in the basis `(1, u)`, of determinant
`l0^2 - 7 l1^2 = Norm(lambda)`; `wedge(a, b) = det[[a0,b0],[a1,b1]]`, and
applying one matrix to both columns multiplies the determinant by its
own. Hence `wedge(lambda x, lambda x U) = Norm(lambda) Norm(x)`. Because
Fp2 is a field, `Norm(y) = 0` iff `y = 0`. **The 2x2 block therefore
vanishes only when `lambda cm = 0`; there is no `Im(U)` factor, no
degenerate `U`, and no extra bad set.** The draft's §3.2 step 4 is
correct.

`determinant` in the code is exactly this wedge
(`private_block/protocol.rs:135-137`,
`private_attention/protocol.rs:130-132`).

For the standalone endpoint path, `private_seam.rs::terminal_claim` gives
`(e, e U)` — **VERIFIED IN THE CODE** only through the capture: the
endpoint claim has three parts with `part_rows` `0..2`, `2..3`, `3..4` and
`check_endpoint_opening` (`protocol.rs:191-203`) pins exactly that shape;
my script confirms `rw[pair1] == rw[pair0] * U` on both endpoints of all
four captures.

**RECOMPUTED, all 16 role-captures:** `pair_weights_are_cm_cmU` equals the
claim count in every case — 120/52/1/1 (block) and 75/36/1/1 (attention).
Every claim, not a sample.

### 2c. Independent determinant re-derivation

I did not reuse `pair_block_identity.py`. The draft's script builds a
**synthetic** commitment whose combinatorics it invents (member counts
`[4]*25 + [2]*10` for block A, which is not the real grouping) and then
tests the structure it has itself imposed — a weak design for this
question. Mine instead takes the **real** claim schedule out of the four
captures (offsets, `log_size`, coefficients, points), re-implements
`zpart_weights` from the Rust, re-derives the first-occurrence grouping
from `part_key`, and then resamples the **challenge** side.

**RECOMPUTED** (`check_pair_factorisation.py`):

* my grouping is **identical, element by element**, to the Rust
  `group_zclaims` grouping recorded in the capture — same number of
  groups, same member index lists, same per-group lambda counts — on all
  16 role-captures (35/9/1/1 and 30/8/1/1);
* at **3 fresh uniform challenge vectors per role-capture (48 vectors
  in all)**, `det(chosen 2(G+1) minor) == prod_g Norm(lambda_g cm_g) *
  wedge(prox pair)` with **0 mismatches** and **0 zero determinants**;
* the full ranks reproduce `rank(gens) = rank(gens|non-data) = 2(G+1)` =
  72 / 20 / 4 / 4 and 62 / 18 / 4 / 4, `k0 = 0` in every case.

**RECOMPUTED** (`check_adversarial_challenges.py`, block A and block H,
3 draws per regime, 26 regime-role combinations): the identity holds and
the determinant is nonzero for lambdas in the base field, lambdas purely
imaginary, all lambdas equal, all lambdas `= U`, `cm` in the base field,
`cm` with zero real part, `cm = U`, `cm` a tiny integer pair, and the
base-base and imag-imag combinations. **There is no adversarial value of
`lambda` or `cm`, short of zero, that kills the minor.** The only regimes
that zero it are `prox` pair Fp-dependent and `prox` drawn in the base
field — both refused (and the second would also refuse every honest run,
which is the draft's own completeness observation, confirmed).

**One negative-control reading in the draft is FALSE at the real
schedule.** The draft's §3.2 "Where this is conservative" says one zero
`cm` "kills the minor taken at THAT member's pair but not `k0`: another
member of the same group still carries the group". **RECOMPUTED**: on the
real block A and block H schedules, setting **one** `cm` to zero (claim 0)
already gives `k0 = 2`, because group 0 is a **singleton** — and
singleton groups are common here (the LogUp sum claim's group is a
singleton on all four captures; A has 35 groups over 120 claims and H has
9 over 52, with singletons among them). The refusal on `cm ≠ 0` is
therefore **not** conservative at this schedule: for every singleton
group it is exactly necessary. That strengthens the lemma's dependence on
`argument.rs:347-349` and `audit_claims:103-108`, and the draft's prose
understates it. Correction C-3.

The draft's other two readings do survive: one zero `lambda` gives
`det = 0` but `k0 = 0` (the group vector goes to zero, which discloses
nothing), and a dependent proximity pair gives `det = 0` with `k0 = 0` at
these shapes.

### 2d. Do the refusals cover every factor? Replay order; verifier side

**Every factor is refused, at these sites** — VERIFIED IN THE CODE:

| factor | refusal | file:line |
|---|---|---|
| `cm = e_r prod_{k>r}(1-e_k)` | `es.iter().any(\|e\| e.is_zero() \|\| *e == Fp2::ONE)` → "degenerate terminal mask challenge; discard attempt" | `private_block/argument.rs:347-348`, evaluated **before** `cd`/`cm` are formed at `:352,356` |
| same, re-tested from the built claim | `part.coef.is_zero()` → "zero terminal mask coefficient; discard attempt" | `private_block/protocol.rs:103-108` |
| `lambda_{g,j} = 0` | "zero group member coefficient; discard attempt" | `protocol.rs:141-146` |
| `wedge(rho_prox[prox], rho_prox[prox+1]) = 0` | "dependent proximity mask coefficients; discard attempt" | `protocol.rs:147-150` |
| `c_s = 0` (CFS multiplier) | "zero CFS mask challenge; discard attempt" | `argument.rs:275-276` |

**The replay order matches, element by element. VERIFIED IN THE CODE plus
RECOMPUTED.** The chain is:

1. `check_opening` (`protocol.rs:155-175`) rebuilds the groups by
   first-occurrence over `part_key` (`:67-71`) on the **same** `claims`
   slice that `open_zk` will use, refuses if the count differs from
   `A_GROUPS`/`H_GROUPS`, then `Transcript::clone_state(tr)` and one
   `challenge_fp2()` per member per group followed by `rows` more.
2. `open_zk` (`zkp-core/src/pcs.rs:915-921`) does `group_zclaims` then
   `zk_rhos`, and **touches the transcript for the first time inside
   `zk_rhos`** — nothing is absorbed between the clone and the draws.
3. `zk_rhos` (`:835-856`) draws `tr.challenge_fp2_vec(members.len())` per
   group in `group_zclaims` order, then `challenge_fp2_vec(rows)`;
   `challenge_fp2_vec(n)` is literally `n` successive `challenge_fp2()`
   (`transcript.rs:114-116`).
4. `part_key` and `ZKey` agree branch by branch (I compared all four
   branches; note `ls.saturating_sub(LOG_N)` equals `lr` in one branch and
   `0` in the other, which is what `zpart_weights` uses).
5. `clone_state` (`transcript.rs:139-142`) copies `state` **and**
   `counter` and asserts no masker is installed, so the byte stream is
   identical.

**RECOMPUTED**, as machine evidence for step 4: my independent
`part_key`-based grouping equals the Rust `group_zclaims` output recorded
in every capture, member list by member list, on all 16 role-captures.
That is the strongest available check short of a Rust test.

**There is still no Rust test pinning the order.** `tests.rs:295-315`
(`opening_refusals_are_functions_of_the_challenges_only`) injects a
hand-written draw iterator; it exercises the refusal predicate, never the
agreement with `zk_rhos`. The attention twin
(`private_attention/tests.rs:289`) is the same. **The draft's §6 item 2 is
correct and remains open.** Condition O-1.

**The verifier also rejects a receipt built on a refused challenge.**
VERIFIED IN THE CODE: `verify_inner` calls `check_opening` at
`protocol.rs:458` (A) and `:464` (H) and `check_endpoint_opening` at
`:471`, each *before* the corresponding `pcs::verify_zk`. The same holds
on the attention path (`private_attention/protocol.rs:443,449,…`). So a
modified prover cannot publish a receipt whose challenges the honest
prover would have refused; a receipt in the wild implies the refusal
predicate held. The draft asserts the prover side and never checks the
verifier side — it happens to be true. Correction C-4 (add the citation).

### 2e. Verdict on attack 2

The factorisation holds. I could not break it at any challenge value, on
the real schedules, and no claim's weights reach a non-data row outside
its own pair (plus, for two H claims, the `u` pair, harmlessly). The
draft's conclusion "the bad set is contained in the refusal set" is
**sustained for the four commitments of both toy profiles**, subject to
C-1..C-4 and O-1.

---

## 3. H and the mask channel

### 3.1 `dim ker R = 1`, including at degree 2

**RECOMPUTED** (`check_channels_and_numbers.py`, section 3). I
re-implemented `R` from `CfsMask::round`
(`zkp-core/src/sumcheck.rs:255-274`) by differentiating in each
coefficient, and computed `L - rank R` at the **actual** `(N_s, d_s)` of
all 23 block slots — `N = n + e` from `mask_specs()`
(`layout.rs:533-535`), `L = N d + 2` (`sumcheck.rs:196-198`) — under five
`rho` regimes:

| rho regime | slots with `dim ker R != 1` | `sum_weights` outside the span | `eval_weights` outside |
|---|---:|---:|---:|
| uniform | 0 / 23 | 0 | 0 |
| all zero | 0 / 23 | 0 | 0 |
| all one | 0 / 23 | 0 | 0 |
| all equal | 0 / 23 | 0 | 0 |
| small integers | 0 / 23 | 0 | 0 |

`dim ker R = 1` in all 115 cases, including the eleven-or-twelve `d = 2`
slots and the smallest slot (`N = 5`, `d = 2`, `L = 12`). The draft's §3.5
is confirmed, and its §6 item 6 doubt is answered. **Two negative
controls fire** as predicted: dropping the last round takes `eval_weights`
out of the span while `sum_weights` stays in; and publishing only `d`
values per round instead of `d+1` raises `dim ker R` to 2 at both slot 8
and slot 17.

**That second control is a missing citation, and it is load-bearing.**
The draft's argument runs "`s_j` has degree at most `d` in `X` and
`0..d` are `d+1` distinct points, so it must vanish identically". That
premise is the protocol publishing `d+1` values per round, which is
enforced at `zkp-core/src/sumcheck.rs:148-150`
(`if s.len() != degree + 1 { return Err(...) }`) and nowhere else. The
draft never cites it. Without it the identity is false by a factor of two
in the kernel. Correction C-5.

**Small numerical error.** §6 item 6 says "Eleven of the block's 23 slots
have `d = 2`". **RECOMPUTED** from `SLOTS` (`layout.rs:438-462`): twelve —
slots 5, 6, 7, 8, 9, 10, 11, 12, 13, 20, 21, 22. Correction C-6.

### 3.2 The published functionals

**MY OWN ARGUMENT**, checked against the code and recomputed. From
`CfsMask::round`, `s_0(0) + s_0(1) = 2^N a_0 + a' + 2^{N-1} sum_i u_i(1)`,
which is exactly `sum_weights` (`sumcheck.rs:222-227`); and
`s_{N-1}(rho_{N-1}) = a_0 + sum_i u_i(rho_i) + a' prod rho = g(rho)`,
which is `eval_weights` (`:230-243`) and is the Lagrange combination of
the `d+1` published values of round `N-1`. Both are identities in the
coefficients, for every `rho`. Confirmed numerically above.

### 3.3 Is H's "disclosed 2" a PUBLIC quantity? — yes, and here are the two functionals

The draft proves existence, uniqueness and span-equality (§3.3 steps 1-5)
but never says **what the two functionals are** or checks that they are
public. I do both.

**MY OWN ARGUMENT.** The observer learns, for the combination `c` with
`c·gens|non-data = e_u`, the vector `w = sum_i (c·gens)[i] z_i =
z_u + sum_{data i} xi[i] z_i`. The `u` row's message is uniform on the
hyperplane `sum_t msg_u[t] = 0` (`protocol.rs:364-372`), so summing `w`'s
256 message entries kills the `u` row and leaves
`sum_{data i} xi[i] * rowsum_i(data)` — one Fp value per `u` row, two in
all. By §3.3 step 5, `span{xi} = span_Fp{Re(rw_sum)|data, Im(rw_sum)|data}`,
and `rw_sum` is the LogUp sum claim's weight vector: `sign_p` on each H
plane's `re` rows and `sign_p·U` on its `im` rows, with
`sign_p = -1` exactly for `H_GU8, H_GEXP, H_GACT`
(`protocol.rs:52-62`, `h_is_table:255-257`). So the two functionals are

```
phi_re = sum_{H planes p} sign_p * (sum of all entries of p's re rows)
phi_im = sum_{H planes p} sign_p * (sum of all entries of p's im rows)
```

i.e. the real and imaginary parts of the **value-0 LogUp identity**. The
sum claim's declared value is `Fp2::ZERO` (`protocol.rs:62`), so both
functionals evaluate to `0` on every witness the constructors admit. They
are public: a function of the statement alone. **This answers the brief's
question in the affirmative and pins what "2" means.**

**RECOMPUTED** (`check_u_row_term.py`, 3 fresh challenge vectors on each
of the four H captures): both `u` indicators are admissible; the solving
combination uses only the sum claim's own two generators; and
`rank(xi) = rank(logup) = rank(xi + logup) = 2` in all 12 trials — the
spans are equal, not merely of equal dimension. The sum claim's group is a
singleton on all four captures, which is §3.3 step 1 verified rather than
argued. The declared value is `[0, 0]`.

**Remaining gap the draft does not name.** The tool adds `u_dim` (2), not
`256 * u_dim`, to `disclosed` (`_disclosed:459, 484`). That is right —
only the all-ones column direction escapes a hyperplane-uniform row — but
it is a *step of the reduction*, not of the rank computation, and it is
nowhere argued in the draft. I give the argument above; it should be in
the lemma. Condition O-2.

---

## 4. The opened columns and the pad budget

### 4.1 What the pad structure actually is

**VERIFIED IN THE CODE.** `encode_row_zk`
(`zkp-core/src/pcs.rs:618-637`) builds the coefficient vector
`c = ifft(msg)` of length `n`, subtracts `pad[i]` at `i < q`, writes
`pad[i]` at `n + i`, multiplies by `pows[i] = coset^i` and forward-NTTs
over `nn`. So the encoded row is `f(x)` evaluated at `x_j = 7 w_nn^j`, and
the pad contributes `pad_k (x^{n+k} - x^k) = pad_k x^k (x^n - 1)`.
`E_j[pad k] = Z_n(x_j) x_j^k` — the tool's closed form is right.
`ZkOpts::standard` sets `q_pad = params.num_col_checks` (`:542-544`) and
`coset = 7`; `pcs_params()` sets `log_cols = 8, inv_rate = 8,
num_col_checks = 256` (`private_block/protocol.rs:21-23`), so
`n = 256, nn = 2048, Q = 256`.

**There is no systematic part.** `coset_powers` asserts the coset
generator's order does not divide `nn` (`pcs.rs:612`), so the evaluation domain
is disjoint from the size-`n` subgroup: no encoded position ever exposes
a message symbol. **RECOMPUTED**: **0 of 2048** coset nodes lie in the
size-256 subgroup. This answers the brief's "could an opened column be a
systematic position" — no.

### 4.2 Distinctness, `Z_n`, and the ranks

**RECOMPUTED** (`check_channels_and_numbers.py`, section 4a), exhaustive
over the whole encoded domain:

* `7^2048 != 1` and `7^4096 != 1`; 7 has order `p-1`;
* all **2048** nodes `x_j = 7 w_2048^j` distinct;
* `Z_n(x_j) = x_j^256 - 1` nonzero at **all 2048** positions;
* on the **real captured index sets** (which contain repeats), the pad
  block's rank equals the number of distinct indices, every time:
  block A 246/246, H 242/242, Input 246/246, Output 241/241, with
  `q_pad = 256` and slack 10/14/10/15;
* at the collision-free boundary, 256 distinct positions give rank
  **256 of 256**;
* negative control: one repeated index drops the rank to 255;
* negative control: **257** distinct positions against 256 pads give rank
  256 — i.e. the budget is exactly spent and one more distinct opened
  position would break H-pad.

**Sampling is with replacement.** `challenge_indices`
(`transcript.rs:119-131`) masks squeezed bytes into `[0, bound)` and
pushes them without a distinctness check; repeats are normal (the
captures show 241-246 distinct of 256). A repeat is *good* for hiding: it
consumes one fewer pad degree of freedom. The 257-row control above shows
there is **no slack at all** in the other direction: `q_pad == Q ==
num_col_checks` exactly, and `commit_zk_owned_with` (`pcs.rs:670`) asserts
`q_pad >= num_col_checks`, so equality is the design point. Any future
profile that raises `num_col_checks` without raising `q_pad` in lockstep
breaks the argument at the first collision-free draw. Condition O-3.

### 4.3 M's Cauchy block

**VERIFIED IN THE CODE** (`hashline/src/zk.rs:373-375, 430-467`):
`MASK_LOG_MSG = 9` (m = 512), `MASK_LOG_DOM = 12` (dom = 4096),
`MASK_Q = 256`, and an `a` row's message is `L = N d + 2 <= 50` mask
coefficients at positions `[0, L)`, **256 pads at `[L, L + 256)`**, zeros
after; it is then inverse-NTT'd and encoded on the coset. So the pad block
is the Lagrange matrix `L_t(y_j) = z_j m^{-1} w^t / (y_j - w^t)` — a
Cauchy matrix scaled on both sides.

**RECOMPUTED**: all 4096 nodes `y_j` distinct; `z_j = y_j^512 - 1` nonzero
at all 4096; no `y_j` coincides with a message node; and the Cauchy block
has rank 256 of 256 on 256 random opened columns, **both** at pad
positions `[0,256)` and at the real `[50, 306)`.

**A small defect in the tool, not in the lemma.** `m_pad_block_rank`
(`zk60_native_jv_cfs.py:564-586`) builds the Cauchy block at positions
`t in range(MASK_Q)`, i.e. `[0,256)`, with the comment "any 256
consecutive message positions" — but the real pads sit at `[L, L+256)`
with `L` varying per row. The mathematics is unaffected (Cauchy matrices
on distinct nodes are totally non-singular, which I confirmed at both
ranges), but the tool is checking a matrix the protocol does not use.
Condition O-4.

### 4.4 The pad budget against **everything** revealed — the brief's real question

The brief asks whether revealing the group and proximity vectors *in
addition to* 256 columns consumes pad entropy that "256 pads against 256
columns" ignores. **The draft never asks this.** Here is the answer.

**MY OWN ARGUMENT.** What is revealed about one commitment is: the `G`
group vectors and the proximity vector, each **512** Fp2 entries — `n`
message-combination entries and `Q` pad-combination entries — plus, for
each of the `d` distinct opened positions `j`, the whole column
`(<E_j, z_i>)_{i<rows}`.

Write `F^msg` and `F^pad` for the `d x n` and `d x Q` blocks of `{E_j}`,
and `c_i = F^msg msg_i + F^pad pad_i` for row `i`'s opened values. `F^pad`
has rank `d` (4.2), so `p'_i := F^pad pad_i` is uniform on `Fp^d` and
independent of `msg_i`; hence **`c_i` is uniform and independent of the
data, row by row**. And the pad half of a group vector,
`sum_i rho_g[i] pad_i`, satisfies

```
F^pad ( sum_i rho_g[i] pad_i ) = sum_i rho_g[i] c_i  -  F^msg ( sum_i rho_g[i] msg_i ),
```

whose right-hand side is a function of the columns and of the group
vector's **message** half, both already revealed. So the pad halves of the
group and proximity vectors add nothing: they are (partly) determined by
the rest of the view, and whatever is not determined is free pad
randomness. **No pad entropy is double-counted, and none is missing.**

What is left is: for each message position `t`, the values
`(sum_i rho_g[i] msg_i[t])_{g, prox}`. With `msg_i[t]` uniform and
independent for every non-data row `i` (2 above), the functionals of the
data that this determines are exactly
`{p|data : p ∈ rowspace_Fp(realified rho), p|non-data = 0}` — dimension
`k0` — per position, so `256 k0` in all; plus the `u`-row escape of
3.3, which contributes 2. **This re-derives the tool's reduction
`disclosed = 256 k0 + u-term`** and it is the piece the draft labels
RELIES ON (label 14). It holds for any `d <= Q` with `F^pad` of rank `d`;
it does not need `d = Q`.

Caveats on my own derivation, stated so it is not over-read: it treats
the hash layer (roots, salts, authentication paths) as outside the view,
exactly as the tool does; it is per commitment; and it assumes the
proximity/combination rows' messages are uniform, which
`protocol.rs:361` gives for A, H and (via `private_seam.rs`) the
endpoints.

### 4.5 Verdict on attack 4

The draft's "no union bound is needed" is **correct and well evidenced**,
and I reproduced it exhaustively and independently, including the
negative controls the draft ran and one it did not (257 distinct
positions). The pad budget is exactly spent, with zero slack, and that
should be recorded as a standing condition rather than a passing remark.

---

## 5. The numbers

All **RECOMPUTED** in `check_channels_and_numbers.py`, section 5, with
exact integer arithmetic.

**(B) Refusal probability.** Every figure in the draft's table reproduces
to the printed digit:

| term | block (draft / mine) | attention (draft / mine) |
|---|---|---|
| `e ∈ {0,1}`, 25 (20) draws | `2^-122.36` / `2^-122.36` | `2^-122.68` / `2^-122.68` |
| `lambda = 0`, 174 (113) draws | `2^-120.56` / `2^-120.56` | `2^-121.18` / `2^-121.18` |
| `c_s = 0`, 23 (18) draws | `2^-123.48` / `2^-123.48` | `2^-123.83` / `2^-123.83` |
| proximity wedge, 4 openings | `2^-62.000` / `2^-62.0000` | `2^-62.000` / `2^-62.0000` |
| total | `2^-62.000` / `2^-62.0000` | `2^-62.000` / `2^-62.0000` |

One opening's wedge probability is exactly
`(p^2 + (p^2-1)p)/p^4 = 2^-64.000000`, i.e. "two uniform vectors of
`Fp^2` are Fp-dependent". The draw counts 174 / 853 / 25 / 23 are
independently confirmed: `sum(A_SITES) = 120`, `sum(H_SITES) = 51`
(+1 sum claim), `455 + 384 + 7 + 7 = 853` rows, `SLOTS` has 25 extension
rounds over 23 slots (`layout.rs:438-462`).

**(C) The Schwartz–Zippel backstop, and who is right.** The draft's
`2^-55.85` / `2^-56.05` reproduce exactly (degrees 212/56/8/8 and
182/50/8/8 over `p = 2^64`). I also reproduced the CHECK's own sketch
(degree 3 per entry, a `G_sketch x G_sketch` minor with
`G_sketch = groups + prox`, over `Fp2`): `2^-120.77` block, `2^-120.96`
attention — which is the check's stated `≈ 2^-120.8`. So both arithmetics
are internally correct; the whole disagreement is **which event, in which
ring**.

**The draft is right, and I can prove it with a two-row counterexample.
RECOMPUTED.** Take one Fp2 generator `rho = [1, u]` with non-data row 0
and data row 1. Its Fp2 row rank restricted to the non-data rows is 1,
i.e. FULL — yet the tool's `k0 = rank_Fp(gens) - rank_Fp(gens|non-data)
= 2 - 1 = 1`, not 0. **Full Fp2 rank on the non-data rows does not imply
`k0 = 0`.** The realified Fp rank is `2(G+1)` iff `{rho_g}` *together
with their conjugates* are Fp2-independent, and conjugation is `x -> x^p`,
so a Schwartz–Zippel bound taken over `Fp2` on the `(G+1)`-sized minor
bounds a different event from the one the tool measures.

Two qualifications the draft should carry, because its rhetoric overruns
its evidence:

* the draft says that if the structural argument is rejected "the project
  … falls back to `2^-56` and has a problem". `2^-55.85` is a *bound*
  from a generic tool applied to a polynomial we know is a product of
  norm forms; the true probability is `4/p^2`-ish per group factor, i.e.
  vastly smaller. A loose bound is not a finding. The honest statement is
  "the generic bound, taken generically, is weak here, which is one more
  reason to argue structurally" — not "the project has a problem".
  Correction C-7.
* the draft's §2.2 "correction 1" says the sketch used a
  `(G+1) x (G+1)` minor. The sketch's literal words are `G x G` of an
  `R x G` matrix with `G` counting "groups plus the proximity vector"
  (`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md:329-337`), which is the same
  thing said differently. The substance of the correction is right; the
  quotation is not. Correction C-8.

**Base-field challenges: there are none, so D15 is untouched.**
**VERIFIED IN THE CODE**: `challenge_fp` (`transcript.rs:97-100`) is
called nowhere in `hashline/src/` or `zkp-core/src/` outside a self-test
at `transcript.rs:166` — I grepped both trees. Every challenge on these
paths is `challenge_fp2` / `challenge_fp2_vec`. Moreover D15's soundness
figure is `(3/4)^256 ≈ 2^-106` per opening, a function of the **opened
column count and rate**, not of the field size
(`ZK60_DECISIONS.md:439-467`), so the Fp/Fp2 question in §2.2 has **no
bearing on any quoted soundness number**. Flagged, as the brief asks, and
not re-derived.

**(B') sampler residual on this lemma's draws**: `2^-85.93` (1,075 draws)
and `2^-86.43` (761), both reproduce. Note these sit inside the privacy
case's `2^-77.7` total for one toy block proof, which itself is the
project's recount of D9's `2^-96` per draw — D9 itself records `2^-75`
at the toy shape (`ZK60_DECISIONS.md:371-409`). The draft cites
"`2^-77.7` sampler bias" against D9 without saying the figure is the
privacy case's, not D9's. Correction C-9 (cosmetic).

**The `2^-62` coincidence.** The draft suggests the errata pass check
whether its `2^-62` refusal probability is the same item as "the larger
residual of about `2^-62`" D9 records. It is almost certainly **not**:
D9's is described as a **privacy** residual in the indistinguishability
bound, while the draft's is a **completeness/liveness** probability
(`4/p`, the chance of discarding a run). Identifying them would be a
category error, and the draft's phrasing ("the coincidence is close
enough") invites it. Correction C-10: state the category, then ask the
errata pass to look.

---

## 6. Refusal witness-independence

Condition by condition, **VERIFIED IN THE CODE**:

* `es.iter().any(|e| e.is_zero() || *e == Fp2::ONE)` — `es` are transcript
  draws from the extension rounds; challenges only.
* `c.is_zero()` — one `challenge_fp2` per slot; challenges only.
* `check_opening_challenges` — reads only the group member counts (a
  function of the claim **shapes** and the layout), `rows`, `prox`, and
  replayed challenges; no witness value enters
  (`protocol.rs:141-152, 155-175`).
* `audit_claims`'s `part.coef.is_zero()` — the coefficients are
  `coef * cd` for data parts (with `coef ∈ {1, U, -1, -U}`, layout
  constants) and `cm * {1, U}` for mask parts; all challenge-derived.
* The structural clauses of `audit_claims` are functions of the layout
  only.

So the refusal predicate the lemma relies on is a function of the
transcript challenges and public shapes. **The draft's §3.6 conclusion is
right, and its "RELIES ON the ROM" is the correct label** — but the draft
presents it in one sentence and does not press the subtlety the brief
asks about, so I will.

**MY OWN ARGUMENT on the ROM point.** The challenges are BLAKE3 images of
a prefix containing the Merkle roots, which are functions of the witness
*and* the pads/salts. The refusal event is therefore, for a fixed
(witness, randomness) pair, deterministic and witness-dependent. What
makes it harmless is only that in the random-oracle model each fresh
prefix's challenge is uniform and independent of the prefix, so the
refusal *law* is the same for every witness. This is used **as more than
a bookkeeping convenience**: it is the only reason the conditional
distribution of challenges given "not refused" is identical in the two
worlds, and hence the only reason conditioning on non-refusal is free.
The check of 2026-09-19 already made this correction (its C-12:
"equidistributed in the two worlds **under M-1 (the random-oracle
model)**, not unconditionally") and the draft does not carry it. The
lemma should say, in its own §3.6, that the whole "probability 1 on
non-refused runs" framing is a statement **inside** the ROM, because the
conditioning event is defined by the oracle's outputs. Correction C-11.

Two further points the draft misses:

* **The number of openings and the row counts must be witness-independent
  too**, or `Pr[refused]` would be. They are: `A_ROWS`, `H_ROWS`,
  `ENDPOINT_ROWS`, `A_GROUPS`, `H_GROUPS` are compile-time constants and
  `Layout::new` asserts them (`layout.rs:588-591`), and the verifier
  refuses a different group count (`protocol.rs:169-171`). The draft's
  §6 item 4 raises this and leaves it as "one sentence"; it is closable by
  those citations. I close it here. **VERIFIED IN THE CODE.**
* **Restart semantics.** "Never resampled on the same transcript"
  (`argument.rs:272-273`) means a refused attempt is discarded whole.
  For the privacy argument what matters is that the restart draws **fresh
  pads, salts and masks** (they come from a per-call `ZkRng`,
  `protocol.rs` creates and drops every owner inside one `prove_inner`,
  `:5-8`), so the restarts are i.i.d. and the accepted transcript is
  uniform on the non-refused set. The draft does not say this; it should,
  because a restart that reused the pads would correlate the two worlds.
  Condition O-5.

The witness-**dependent** refusals (zero LogUp denominator at `2^-112.0`,
the 20 witness-builder sites) are outside this lemma and correctly taken
as an input from the earlier check.

---

## 7. The five gaps and five relies-on

Going down the draft's §3.8 table.

**Labelled PROVED HERE but actually resting on an unverified code fact:**

* **Row 2** ("the eq-tensors never reach the non-data rows; pair weights
  are `(cm, cm U)`") — PROVED HERE is defensible for the *pair weights*,
  but the "never reach" half rests on the two `assert!`s in
  `zpart_weights` that the draft never cites (C-1). Downgrade to
  PROVED HERE **given** `pcs.rs:759, 768, 775, 786`.
* **Row 11** (`uncovered_s = 0` identically) — rests on
  `sumcheck.rs:148-150` publishing `d+1` values, uncited (C-5).
* **Row 9** (the u-row solution) — its step 1 ("the sum claim is alone in
  its group") is proved from "every evaluation claim's point is
  non-empty"; that is true at the toy (every `Priv` has `log >= 5`) but
  the draft's own §6 item 3 admits the enumeration was not done. I did it:
  the three `Priv` constructors are `argument.rs:423, 445, 449`, with
  `log` from `a_dom`/`h_dom` (minimum 5) or literal 5/6/9, so
  `p.log >= 5 > 0` always. **Closed for the toy** — and **it fails at
  125M**, see §8. Row 9 should carry that condition.
* **Row 10** (H-pad / M-cols for every column set) — PROVED HERE is fair;
  I reproduced it exhaustively and add the 257-position boundary control
  and the `q_pad == num_col_checks` condition (O-3).
* **Rows 1, 3, 4, 12** — PROVED HERE, and I agree; row 3 I re-derived by
  hand and row 4 I re-derived on the real schedules.

**The RELIES ON rows are honestly labelled**, with two adjustments:

* **Row 8** (replay order) says "order checked by reading, not by
  machine". I checked it by machine as far as is possible without Rust:
  my independent grouping equals the Rust grouping element by element on
  16 role-captures (2d). The residual is the *draw order*, which still has
  no test (O-1).
* **Row 14** (the reduction) can be promoted from RELIES ON to
  PROVED-CONDITIONAL: I derive it in 4.4 under H-pad. The draft should
  either carry a derivation or cite one; leaning on a docstring for the
  step that carries all the meaning is the weakest link in the document.

**The GAP rows.**

* **Row 16** (the tool cannot name a certifying minor) — confirmed:
  `_disclosed` records `rank_P1` and `rank_P1_on_non_data_rows` and
  nothing else (`zk60_native_jv_pcs.py:432`). Real, cheap, and worth
  doing; my `check_pair_factorisation.py` shows the minor can also be
  named *a priori* from the layout (one member claim per group plus the
  prox pair), which is cheaper than extracting pivots.
* **Row 17 — "the tool hard-codes `joint == sum` as True". CONFIRMED,
  and it is worse than the draft says.** `zk60_native_joint_view.py:245`
  is `"joint_equals_sum_of_parts": True` inside a dict literal, never
  computed; and `stage4` also returns `{"per_capture": rows, "ok": True}`
  at `:248` — the stage's **pass flag is a constant too**. So stage 4 of
  the joint-view gate can never fail. **What rests on it:** the
  headline number "joint disclosed = 4 Fp" is `sum(pcs.values()) +
  cfs` — an arithmetic sum of four independently computed marginals,
  with the *claim* that the joint equals the sum unbacked. Any document
  that quotes "the joint view discloses 4 Fp" is quoting an assumption
  about composition plus four measurements, not a measurement of the
  joint. That is U-3(b), and it is open. The draft's label is right;
  the additional finding (`ok: True` hard-coded) is mine. Correction
  C-12.
* **Rows 18, 19, 20** — out of scope and correctly named.

**One label the draft does not have and should.** Nothing in the table
covers "the non-data rows are uniform", which the entire argument needs
(1.2 rider 2). Add a row citing `protocol.rs:361` and `:364-372` and
`private_seam.rs`. Condition O-6.

---

## 8. Scope: what breaks at the development rung and 125M

The draft's §4 item 6 lists four things 125M owes. It is **incomplete in a
way that matters**, and one of its four items is aimed at the fallback
rather than the structure. From `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md`:

1. **BLOCKING, and not in the draft: at 125M and at the rung the LogUp
   sum claim has parts under three different column-weight keys, so
   §3.3 step 1 does not merely need re-checking — the claim cannot be
   formed at all.** At `LOG_N = 14` the H domains straddle the row width
   (`Tab` 8, `L` 13 below; `Kv` 17, `D`/`Q` 19, `F` 20, `S` 22 at or
   above), `check_opening` returns "claim parts with different column
   weights" and `pcs.rs:817` asserts below it (layout memo §2.2
   :494-503, §4.1 :1396-1408). The rung reproduces the same three keys
   deliberately (`([],0,256)`, `([],0,512)`, `([],0,1024)`, §9a :2003,
   :2026). After the P-3 repair (lift `Dom::L` and `Dom::Tab` to
   `log = LOG_N`, zero extra rows) every H part is back to key
   `([],0,N)` and §3.3 step 1 is restored. **The lemma's §3.3 silently
   assumes "every H plane's `log >= LOG_N`", which is true at the toy and
   false at both larger profiles until the repair lands.** That
   hypothesis is nowhere stated.
2. **`A_GROUPS` moves 35 → 36** at 125M *and* at the rung (the nine
   `Dom::L` sub-slices sit at nine distinct `c0 = 512k`, where the toy's
   `32k mod 256` wraps at `k = 8` and gives eight). So `g = 2(G+1)` goes
   `72 → 74` and the backstop degree `6G+2` goes `212 → 218` for A;
   H stays 9 / 20 / 56. The draft's item 6(iv) mentions only "if any slot
   gains a third extension round" — no slot does; what moves is the
   group count, which the draft does not mention.
3. **The endpoints are re-tiled and the lemma's endpoint case is
   re-shaped.** `ENDPOINT_ROWS` 7 → **29** and `ENDPOINT_PROX` 4 → **26**
   at 125M (9 / 14 at the rung), the endpoint plane is **three** `d`-blocks
   not one, and each endpoint claim gains `nb_d = 3` data parts instead
   of one (§6 :1522-1581). `check_endpoint_opening`'s three hard-coded
   `part_rows` equalities (`protocol.rs:194-196`) are exactly the sites
   that change. The good news for the lemma: the memo states the claim's
   non-data coefficients "are still exactly `(e, e·U)` on one reserved
   pair" (§6 :1587), so the factorisation shape survives — but that is a
   design intention in another document, not a verified fact, and the
   draft asserts endpoint coverage with no caveat at all. Also, at the
   rung `n ∤ tdb` forces a **per-commitment `log_n`** (§9a :2004), so
   §2.3's pad arithmetic must be redone at a second `(n, nn)` pair, not
   one.
4. **The pad-zero term adds a refusal the lemma's inventory does not
   have.** Each padded domain's term carries one fresh challenge `ζ`
   **refused on zero** plus one more `mu` entry (§3.7a :1077-1085). It
   adds no rows, no planes and no claim sites, so `audit_claims` and the
   pair structure are untouched — but the refusal list in §3.2 step 6
   and the probability table in §5 both grow. The draft's item 6 does not
   mention it.
5. **`audit_claims` exclusivity under padding is asserted, not argued.**
   The layout memo says "that audit is shape-general already and needs no
   change" (§5 :1505) and relies structurally on the term adding no
   claims. Nothing there re-examines exclusivity once relations are gated
   by `supp`. The draft's item 6(ii) points at this correctly but
   attributes it to ruling P-1 and "padded columns that nothing forces to
   zero", a phrase that is not in the layout memo; the corresponding text
   is §3.7's B-1 and §3.7a's rule. Cosmetic.
6. **What the draft has right**: the pad arithmetic must be recomputed at
   the new `n`, `nn` and coset (item 6(iii)) — and at the rung
   `inv_rate` drops to 4 with `n = 1024`, so `nn = 4096` and the
   `Z_n(x_j) != 0` / node-distinctness checks must be rerun there; the
   layout memo already prices the resulting PCS soundness at `2^-96.1`
   per A/H opening and `2^-67.3` per endpoint opening (§9a :2056), which
   is a separate matter from hiding but shows the geometry really does
   change.

**Nothing in this lemma transfers by itself** — the draft says so, and it
is right; but the list of what breaks is materially longer than the one it
gives, and item 1 is blocking rather than a re-check.

---

## Verdict

**In plain words.** The lemma's headline survives: for the two toy
profiles, on every run the prover does not throw away, the tool's answer
"nothing about the hidden data is pinned down by the verifier's linear
view of A, of H beyond one public identity, or of either endpoint" is
**forced by the construction, not merely likely** — the quantity that has
to be nonzero really does factor into one small piece per opening group
plus one for the proximity pair, and every piece is something the prover
already refuses on. I rebuilt that factorisation from the real claim
schedules of all four captured receipts at fresh random challenges (48
challenge vectors for the identity, plus 26 adversarial regimes) and
found no mismatch, no claim whose weights touch a non-data row outside its
own pair, and no value of the challenges short of zero that breaks it. The
one thing the verifier does learn about H is exactly the public
"LogUp sum is zero" identity, and I have written down the two functionals
and checked their span at fresh challenges. What the lemma does **not**
give, and what a reader must not take from it, is any statement about the
four commitments **together**: the tool hard-codes both "joint = sum of
the parts" and stage 4's own pass flag to `True`, so the often-quoted
"joint disclosed dimension 4" is four separate measurements plus an
unproved composition assumption. To make the surviving claim checkable by
machine the project needs three cheap additions: a Rust test asserting
that `check_opening`'s replayed challenge vector is byte-for-byte the one
`zk_rhos` consumes; the certifying minor emitted by the tool (or, better,
named a priori from the layout, which my script does); and a computed —
not hard-coded — `joint_equals_sum_of_parts`. And the lemma must not be
copied to the next profile: at 125M and at the development rung the LogUp
sum claim cannot even be formed until the P-3 repair lands, `A_GROUPS`
becomes 36, and the endpoints grow from 7 rows to 29.

**Disposition.** The lemma is **not accepted as written**. Its central
argument is accepted in substance, subject to the twelve corrections and
six conditions below. This is **not a privacy acceptance** and nothing
here establishes a privacy property.

---

## ERRATA AND CONDITIONS FOR ACCEPTANCE

### BLOCKING

| # | Item | Why it blocks | What closes it |
|---|---|---|---|
| **B-1** | §3.3's step 1 rests on an unstated hypothesis: **every H plane's `log_size` is on the same side of `LOG_N`**, so the LogUp sum claim has one column key. True at both toy profiles, **false at 125M and at the development rung** until the P-3 lift. | The lemma's §4 item 6 presents 125M as needing "re-checks"; in fact the sum claim cannot be constructed there, and §3.3 would be about a claim that does not exist. A reader planning the next profile is misled about what is owed. | State the hypothesis in §3.3 and in §4 item 6, with the citation (`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §2.2 :494-503, §4.1 :1396-1429) and the refusal string. |
| **B-2** | §2.2 / label 2 assert that a claim's data weights never reach a non-data row **without citing the two `assert!`s** (`zkp-core/src/pcs.rs:759, 768, 775, 786`) that make `part_rows`' `div_ceil` exact. The draft instead tells the checker to attack `div_ceil` and leaves it there. | The correctness of `audit_claims` — and hence of the whole block-triangular structure — is conditional on those asserts. Without them `part_rows` under-reports a straddling slice by one row and the audit misses a spill. | Cite them, and record that the failure mode is a **panic in the PCS**, not a silent spill (which also means a straddle is a liveness bug, not a leak). |
| **B-3** | §3.5a's proof of `dim ker R = 1` needs the protocol to publish **`d+1` values per round**; the enforcement (`zkp-core/src/sumcheck.rs:148-150`) is never cited. **RECOMPUTED negative control**: with only `d` values per round, `dim ker R = 2` at slots 8 and 17. | The identity, hence `uncovered_s = 0`, hence the mask channel's whole claim, is false without it. | Cite `sumcheck.rs:148-150` in §3.5a and in label 11. |
| **B-4** | §3.2's "Where this is conservative" claims one zero `cm` does not move `k0`. **RECOMPUTED on the real block A and block H schedules: `k0 = 2`** — group 0 is a singleton, and singletons are common (the sum claim's group is one on all four captures). | The draft tells the reader the `cm` refusal is stronger than necessary. At the real schedule it is exactly necessary for every singleton group. An implementer who read this could weaken the refusal. | Replace the paragraph with the measured behaviour, and say that the refusal is necessary wherever a group has one member. |

### CORRECTIONS

| # | Correction |
|---|---|
| C-1 | (= B-2) Cite `pcs.rs:757,764,776,785`; say `part_rows` is exact **because** of them. |
| C-2 | §6 item 7 ("no other plane lands on rows 278-279") is closable and should be closed: `h_off` is a strictly increasing cursor and `H_U = 50` is the last of `N_H = 51` with `Dom::Tab`, `log = 8` (`layout.rs:239, 241-252, 576-583`). Separately, a second claim **does** evaluate rows 278-279 (`argument.rs:899`, `b.h(H_U)`; `claims_evaluating_u = 2` on every capture) — harmlessly, because §3.3 step 3 zeroes its group's coefficients first. The tool already documents this (`zk60_native_jv_pcs.py:377-380`). |
| C-3 | (= B-4) the singleton-group reading. |
| C-4 | §3.2 step 6 cites only the prover-side refusals. The **verifier** runs the same `check_opening` / `check_endpoint_opening` before each `verify_zk` (`protocol.rs:458, 464, 469`), so a receipt in the wild implies the refusal predicate held. Add it. |
| C-5 | (= B-3) cite `sumcheck.rs:148-150`. |
| C-6 | §6 item 6: **twelve** of the 23 block slots have `d = 2` (5-13, 20-22), not eleven. |
| C-7 | §0 and §3.7: "the project falls back to `2^-56` and has a problem" overstates. `2^-55.85` is a generic bound on a polynomial known to be a product of norm forms; it is not an estimate of the probability. Say "the generic tool is weak here", not "the project has a problem". |
| C-8 | §2.2 correction 1 misquotes the sketch: it says `G x G` of an `R x G` matrix with `G` = groups **plus** the proximity vector (`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md:329-337`). The substance of the correction (realification doubles it) is right; fix the quotation. Also: my two-row counterexample (`channels_and_numbers.txt`) settles §6 item 5 — full Fp2 rank on the non-data rows does **not** imply `k0 = 0`, so there is no "standard device" recovering `D/p^2` without handling the conjugates. |
| C-9 | §5 attributes "`fp()` bias `2^-77.7`" loosely; `2^-77.7` is the **privacy case's** recount for one toy block proof, D9's own figures are `2^-96` per draw and `2^-75` at the toy shape (`ZK60_DECISIONS.md:371-409`). |
| C-10 | §5's note for ruling C-1: the draft's `2^-62` is a **completeness/liveness** probability; D9's `2^-62` is described as a **privacy** residual. Say so before inviting the errata pass to identify them. |
| C-11 | §3.6 must state that "probability 1 on non-refused runs" is a claim **inside** the random-oracle model, because the conditioning event is defined by oracle outputs (the earlier check's C-12 already ruled this and the draft does not carry it). |
| C-12 | §1.5 and label 17: `zk60_native_joint_view.py:245` hard-codes `joint_equals_sum_of_parts: True`, **and** `:248` hard-codes stage 4's `"ok": True`. Stage 4 cannot fail. Say both. |

### OMITTED CONDITIONS

| # | Condition |
|---|---|
| O-1 | **A Rust test must pin the replay order.** `tests.rs:295-315` injects a draw iterator and never compares with `zk_rhos`. Until such a test exists, label 8 stays RELIES ON. (My machine evidence covers the *grouping*: my independent `part_key` grouping equals the Rust `group_zclaims` output element by element on 16 role-captures. It does not cover the transcript byte stream.) |
| O-2 | The tool adds `u_dim`, not `256 * u_dim`, to `disclosed`. That is correct — only the all-ones column direction escapes a hyperplane-uniform row — but it is a step of the **reduction** and must be argued (see §3.3 of this check), not assumed. |
| O-3 | `q_pad == num_col_checks == 256` **exactly**; `commit_zk_owned_with` (`pcs.rs:670`) only asserts `>=`. My 257-position control shows one more distinct opened position breaks H-pad. Any profile change to `num_col_checks` must move `q_pad` with it, and the lemma should say so. |
| O-4 | `m_pad_block_rank` (`zk60_native_jv_cfs.py:564-586`) checks the Cauchy block at message positions `[0,256)`, but the real pads sit at `[L, L+256)`. Harmless (I checked both), but the tool should check the positions the protocol uses. |
| O-5 | The lemma needs a **restart** after a refusal to redraw pads, salts and masks, so the accepted transcript is uniform on the non-refused set. True here (every owner is created and dropped inside one `prove_inner`, `protocol.rs:5-8`), but unstated. |
| O-6 | The label table has no row for "the non-data rows' messages are uniform", which the whole argument needs. Cite `protocol.rs:361` (mask and proximity rows) and `:364-372` (the `u` rows, uniform on a hyperplane). |

### What I could not verify

* The **attention** profile's Rust was read only by grep (`protocol.rs:130-132, 136, 168-169, 196-197, 308-309, 362-363, 443, 449`); its claim schedule I checked only through the captures, which is the same evidence quality as for the block but with less source reading.
* `M-q` and `M-prox` (label 13) — the `b` and `u` rows' masking of `q` and of the proximity vector. I verified the **structure** of `mask_commit` (`zk.rs:430-467`: `b_re[m] = b_re[0].neg()`, two `u` rows of `2m` uniform coefficients, 48 proximity draws for `2*23+2` rows) but did not re-derive the hiding claim. RELIES ON stands.
* The tool's small-model brute-force cross-check (`zk60_native_jv_smallmodel.py`) — not run. My re-derivation of the reduction (§4.4) is an independent paper substitute, not a replacement for it.
* Anything about the hash layer, the non-linear terminal identity, or U-3(b). Out of scope here as in the draft.
* No Rust was compiled or run, per the brief.

(check complete)
