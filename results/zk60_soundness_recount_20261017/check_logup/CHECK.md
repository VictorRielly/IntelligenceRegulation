# Independent check: the private block's LogUp soundness bound

Checker lane, 2026-10-17, about 19:56–20:10 UTC. **Paper and one-thread Python only.**
Nothing was built, proved or measured, and nothing in git was written. I did not
write the claim checked here.

**The claim** (soundness-accounting lane, `../MEMO_G02.md` §3.1 and `../RECOUNT.md`
§3): the private block's lookup (LogUp) argument fails to catch a cheat with
probability at most **(N + 2303)/|F| per block**. Here N is the number of looked-up
entries in one block and |F| = |Fp2| = p² ≈ 2^128, with p = 2^64 − 2^32 + 1. The claim
says this replaces the project's older convention **R14 = 4N/|F|**.

Labels: **[COUNTED]** means exact arithmetic, reproduced by `check_logup.py`. The
bound in §2 is a paper proof written from the native code. No ruling is made here:
the accounting change belongs to the security owner, and targets are Victor's.

---

## 1. Verdict in plain words

* **The number is right. (N + 2303)/|F| is a correct upper bound** for the LogUp
  argument the native code implements, at every profile.
  * N is far below p in every block, so field-element multiplicities are safe.
  * No challenge is drawn before a commitment it must bind.
* **One of the memo's four reasons is wrong, but the total still holds.**
  * Item 4 of the memo says that if α hits a query value, the helper relation
    becomes unsatisfiable, so that event costs nothing. That is true for a helper
    that covers one lookup.
  * But most byte lookups share a helper in pairs. Each pair's helper satisfies
    `h·(α − f₁)(α − f₂) = (α − f₁) + (α − f₂)` (`argument.rs:894-909`).
  * If both members of a pair equal α, the relation reads 0 = 0, and h can take any
    value. A free helper can balance the whole value-0 sum, whatever else is wrong.
  * This is a real way to cheat. A prover can raise its odds by making many pairs
    have two equal members, each pair with a different value.
  * The total survives because of a counting fact. Every such "equal pair" value
    is looked up at least twice. So the number of distinct looked-up values plus
    the number of equal-pair values is at most N (§2.3). The obligations doc's R13
    had already named this "both zero" case.
* **R14's 4N/|F| is a valid upper bound, about 2.0 bits looser** at every profile.
  * Its derivation does not fit this variant. R14 assumed whole-number multiplicities
    with a checked total, as in the public-IO prover. Here the multiplicities are
    free field elements, committed with no range or total check.
  * Even so, 4N/|F| sits above every bound derived here, including a cruder one that
    charges every pole (2N + 2303)/|F|.
* **The bound is not loose by more than about 3.3–3.9 bits.** An explicit cheating
  strategy, the equal-pair trick on the norm-remainder limbs, succeeds with
  probability at least:
  * 2^-103.0 per block at 8B T512, where the bound says 2^-99.73;
  * 2^-108.0 at 8B T32, where the bound says 2^-104.45.

  So the bound is not too optimistic. It is also not overly loose for the block
  as a whole.
* **The helper relations are enforced by separate sumchecks, and those terms are
  small.** Their error is about 2^-117.5 per block, already inside the recount's
  sumcheck term.

**Figures** [COUNTED]. The derived bound and the memo's (N + 2303)/|F| are the same
formula, so they share a column.

| profile | N per block | per block: derived = memo | per block: R14 | per run (union): derived = memo | per run (union): R14 |
|---|---:|---:|---:|---:|---:|
| TinyLlama T32 (22 blocks) | 6,266,880 | 2^-105.42 | 2^-103.42 | 2^-100.96 | 2^-98.96 |
| TinyLlama T128 (22 blocks) | 30,572,544 | 2^-103.13 | 2^-101.13 | 2^-98.67 | 2^-96.67 |
| Llama-3-8B T32 (32 blocks) | 12,271,616 | 2^-104.45 | 2^-102.45 | 2^-99.45 | 2^-97.45 |
| Llama-3-8B T512, row 2^15 (32 blocks, unregistered) | 323,026,944 | 2^-99.73 | 2^-97.73 | 2^-94.73 | 2^-92.73 |

These reproduce the recount lane's figures to 0.01 bit at all four registered
profiles, and the memo's figures at 8B T512 (§4).

---

## 2. What the code implements (item 1)

All sources are read-only, under `ops/zkp-mvp/trained-1b/`.

**Tables.** There are three tables, of 256 rows each.
* The rows are public values, computed by the verifier from the public statement:
  * the byte table: `i + g_u8`;
  * the exponential table: `i + β·exp[i] + g_exp`;
  * the activation table: `i + β·act[i] + g_act`.
  * Source: `argument.rs:1086-1105`.
* The tags are `g_* = γ·TAG`, with TAG_EXP 129, TAG_U8 133, TAG_ACT 134
  (`tables_attn.rs:49,70,77`; `protocol.rs:1004-1006`). They are distinct mod p.
* The exp and act tables are bound to the transcript. In a single block, the header
  absorbs one digest over the attention and feed-forward words (`protocol.rs:113-127`).
  In a run, the run header absorbs the block digests (`run.rs:527-532`).

**Padding.** At every trained profile the table domain is lifted to the row width
(the P-3 lift, `layout.rs:110-171`; `shape.rs:1767`). The table is then 2^12 to 2^16
entries long.
* Padded entries repeat entry `i mod 256` (`argument.rs:1086-1105`). The set of
  distinct table values is still exactly 768.
* With the pad rule on, the pad-zero term of `SC_TAB` forces both the multiplicity
  and the table helper to zero above index 255 (`argument.rs:1879-1900`).
* If the pad rule were off, a padded multiplicity would only add weight to an
  existing value. That would not affect soundness either.

**Queries.** Every lookup is a linear function of committed `A` planes, plus a tag.
* **Byte lookups:** `cst + Σ coef·plane + g_u8` (`argument.rs:869-891`).
  * There are six lookup domains: L, D, F, Q, Kv and S (`layout.rs:701-784`).
  * Lookups 2k and 2k+1 of a domain share helper k. An odd last lookup gets a helper
    of its own (`layout.rs:607-608`).
* **Exponential pairs:** `δ + β·E + g_exp`, one at each S position, with a
  single-lookup helper (`argument.rs:1837`).
* **Activation pairs:** `(g8 + 128) + β·a16 + g_act`, one at each F position, also
  with a single-lookup helper (`argument.rs:1642`).
* N counts every position of each padded or lifted domain, because the LogUp side
  is never gated off (`argument.rs:973-980`).

**Multiplicities.** These are three base-field `A` planes, `A_MU8`, `A_MEXP` and
`A_MACT` (`layout.rs:284-310`).
* They are **free field elements**. The only constraints on them are `SC_TAB` and
  the pad-zero term. They have no range check, no total check and no lookup of their
  own (searched: `argument.rs:1869-1897` is the only use).

**Order of the transcript.** Prover: `protocol.rs:979-1104`. Verifier:
`protocol.rs:1199-1207`.
1. The header.
2. The `A` root, which includes the multiplicities and every looked-up plane, then
   the `M` root.
3. **β, γ, α**, drawn in that order (`challenge_fp2`: two 128-bit draws reduced mod
   p, so the bias is at most 2^-64 per limb; `zkp-core/src/transcript.rs:113-129`).
4. The `H` root.
5. The 23 slots. Each zero-check draws its own τ and μ after `H`.

**One challenge set per block.** All eight families (six byte domains, exp and act)
in a block share one (β, γ, α) and one sum. A run draws fresh challenges in every
block from the running transcript.

**Helpers.** These are committed, not virtual. Every helper is an Fp2 plane on `H`
(re and im slices).
* There is one helper per pair or single, three table helpers, and the zero-sum
  pair `u` (`layout.rs:440-585`).

**Where each relation is checked.**

| relation | where it is enforced |
|---|---|
| pair: `h·d₁·d₂ − (d₁ + d₂) = 0`; single: `h·d − 1 = 0`, with `d = α − f` | the zero-checks `SC_LZC`, `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`, batched by independent μ under eq(τ) and never gated (`argument.rs:894-909`, :1590, :1644, :1706, :1848, :1266) |
| table: `g_t·(α − τ_t) − m_t = 0` | `SC_TAB`, a standalone zero-check with a public zero sum (`argument.rs:1862-1909`) |
| `Σ` every helper plane − `Σ` table helpers + `Σ u` = 0 | one PCS sum claim of value 0 on `H` (`protocol.rs:171-182`, :313-318, checked in `pcs::verify_zk_tagged`) |
| `Σ u = 0` | `SC_ZS`, a standalone slot with a public zero sum (`argument.rs:1910-1919`; `layout.rs:884-905`) |

Every `H` plane enters exactly one of these relations and the sum claim, so none is
left unconstrained.

---

## 3. The bound from first principles (item 2)

### 3.1 Setting

Fix one block. Before (β, γ, α) are drawn, the prover has fixed `A`, and so:
* every query tuple q₁…q_N, each with its family tag and its helper (pair or single);
* every multiplicity m_t.

The table tuples are public. β, γ and α are independent and uniform in Fp2, in the
random-oracle model, up to the 2^-64 per-limb bias, which is negligible. The prover
chooses `H`, meaning the helpers h, the table helpers g and u, after it sees α.

The compressed values are f_i = c(q_i; β, γ) and τ_t = c(T_t; β, γ). Let T_d = 768,
the number of distinct table tuples.

Here I assume the checks in the table of §2 are exact. Their own errors are the
zero-check and PCS terms (§3.5), and the union adds them separately.

**Claim.** If some query tuple q_{i0} is not in its family's table, then:

```
Pr[ some H satisfies all four relations ] ≤ (N + 3·T_d − 1)/|F| = (N + 2303)/|F|.
```

### 3.2 The three bad events

**B1, compression collision.** f_{i0} equals some τ_t.
* Each case is a nonzero affine polynomial of degree 1 in (β, γ):
  * a bad byte query w against the byte table: w − j, a nonzero constant, so it
    never collides;
  * a bad byte query against the exp or act table: the γ coefficient is
    TAG_U8 − TAG_*, which is nonzero;
  * a bad exp or act query against its own table: (δ − j) + β(E − e_j), with
    (δ, E) ≠ (j, e_j);
  * a bad exp or act query against a different table: the γ coefficient is a
    difference of distinct tags.
* So Pr[B1] ≤ T_d/|F|.
* Only the **first** bad query has to avoid collision. Without B1, its compressed
  value is not a table value.

**Assume not B1 and fix (β, γ).** Let:
* V = the distinct compressed query values;
* W = the distinct table values, with |W| ≤ T_d;
* PP = the values v for which some pair helper has f_a = f_b = v (the "equal pairs").

**B2, a pole that frees a helper.** α ∈ PP ∪ W.
* If α ∈ PP, that pair's helper is free.
* If α ∈ W, a table helper is free wherever m_t = 0. Where m_t ≠ 0 the relation is
  unsatisfiable.
* So Pr[B2] ≤ (|PP| + T_d)/|F|.

**Every other pole is a refusal.** Suppose α ∈ V but α ∉ PP ∪ W.
* A single helper reads 0 = 1.
* A pair whose other member differs reads 0 = (α − f_b) ≠ 0.
* No `H` satisfies the zero-check, so the zero-check rejects, up to its own error
  (§3.5). Here the memo's item 4 is right.

**B3, the α identity.** α ∉ V ∪ W, so every helper is forced:
* h = 1/(α − f_a) + 1/(α − f_b) for a pair;
* h = 1/(α − f_a) for a single;
* g_t = m_t/(α − τ_t) for a table entry.

The sum claim then says R(α) = 0, where:

```
R(X) = Σ_i 1/(X − f_i) − Σ_t m_t/(X − τ_t)   in Fp2(X).
```

* R has a pole at f_{i0} ∉ W, with residue n_{i0} = #{i : f_i = f_{i0}}, and
  1 ≤ n_{i0} ≤ N.
* **This is where p > N is used.** Since N < p, n_{i0} ≠ 0 in Fp2, so R ≠ 0.
  * The multiplicities cannot cancel this pole, because the table side has no pole
    at f_{i0}. That holds whatever field values the m_t take.
  * This is Haböck's logarithmic-derivative criterion (ePrint 2022/1530): over a
    field of characteristic greater than the multiplicities, the sum identity holds
    only if every query is a table value.
* Clearing denominators gives R = P(X)/∏_{v ∈ V ∪ W}(X − v), with P ≠ 0 and
  deg P ≤ |V ∪ W| − 1 ≤ |V| + T_d − 1.
* By Schwartz–Zippel in α alone, Pr[B3] ≤ (|V| + T_d − 1)/|F|.

### 3.3 The total, and the counting step

```
Pr ≤ [ T_d  +  (|PP| + T_d)  +  (|V| + T_d − 1) ] / |F|.
```

Every value in PP is looked up at least twice: it is both members of one pair. So
counting with multiplicity:

```
N = Σ_v n_v ≥ |V| + |PP|.
```

Therefore Pr ≤ (N + 3·T_d − 1)/|F| = **(N + 2303)/|F|**. ∎

Without this counting step, the honest bound is |PP| ≤ N, that is (2N + 2303)/|F|.
That is one bit worse, and still one bit better than R14.

### 3.4 Lower bound: the bound is within a few bits of tight

Take two limbs that meet the relations only through their weighted sum and share one
pair helper.
* Example: limbs 0 and 1 of a norm remainder, ρ = Σ 256^k ρ_k
  (`argument.rs:1492-1493`, `:1561-1567`; `layout.rs:720-747`).
* The prover sets both limbs to the same value w. The other two limbs absorb the sum,
  so pairs (0, 1) and (2, 3) are both equal pairs, with one free parameter per
  remainder.

Every relation other than the lookup still holds. If α lands on any one w, the free
helper balances the sum, so every out-of-range value, including a forged output,
passes.

Counted only where the code makes this freedom certain:
* eight equal pairs at each D position (ρ and σ of both norms);
* plus two at each S position when σ_s has three limbs.

This gives |PP| = 8|D| (+ 2|S|), which is 0.07–0.10 N. The cheating chance is then at
least:

| profile | strategy, at least | derived bound | gap |
|---|---:|---:|---:|
| TinyLlama T32 | 2^-109.0 | 2^-105.42 | 3.6 bits |
| TinyLlama T128 | 2^-107.0 | 2^-103.13 | 3.9 bits |
| 8B T32 | 2^-108.0 | 2^-104.45 | 3.6 bits |
| 8B T512 | 2^-103.0 | 2^-99.73 | 3.3 bits |

This is a lower bound for one block. The strategy needs its own block to be hit,
because its out-of-range limbs fail the lookup otherwise. So its whole-run figure is
the best single block, not 32 times it.

### 3.5 The sumchecks that enforce the helper relations (separate terms)

Each helper, table or zero-sum relation is enforced by a zero-check over its domain
cube.
* The domain cube has ℓ = log(domain) variables. The relation is MLE-tested at a
  random τ, giving ℓ/|F|.
* It is batched by independent μ (1/|F|), plus the pad term's ζ powers and μ_pad
  (at most 64/|F|, charged generously).
* The sumcheck itself has ℓ rounds and one extension round, at degree at most 5
  (`shape.rs` `BASE_DEGREE`, plus 1 for the pad indicator, charged everywhere).
* A host slot's ν batching adds 1/|F| for each hosted claim. The hosted scalars are
  absorbed before ν.

Summed over the eight slots that carry LogUp relations (`SC_LZC`, `SC_DZC`, `SC_QZC`,
`SC_KVZC`, `SC_SZC`, `SC_FZC`, `SC_TAB`, `SC_ZS`):
* **2^-117.8 to 2^-117.5 per block**;
* 2^-113.3 to 2^-112.5 per run.

That is 12 to 18 bits below the LogUp term. It is part of the recount's per-block
sumcheck term, 2^-117.2 at 8B T512, so it is **not to be added again**.

The value-0 sum claim's own error is in the PCS terms: the λ batching and the
proximity test of `H`.

### 3.6 R14, read against this variant

R14 (`docs/zkmatrix-poc/ZK60_FABLE_SECURITY_OBLIGATIONS.md:138-144`) has three parts:
* It takes P = ∏(α − φ_j) and Q = ∏(α − ψ_i)^{m_i}, which are monic of equal degree
  because the integer histograms are public and their totals checked (R12).
* It applies Schwartz–Zippel to P′Q − PQ′, of degree at most 2N − 1.
* It adds 2N/|F| for pole avoidance, giving (4N − 1)/|F| ≈ 4N/|F|.

The private block has neither condition: its histograms are hidden field elements,
with no total. So Q is not even a polynomial there, and R14's derivation does not
apply literally.

Numerically, though, 4N ≥ N + 2303 whenever N ≥ 768, which holds for every profile.
So **R14 is a valid upper bound for this variant, 2.00 bits looser** than §3.3, and
1.00 bit looser than the crude (2N + 2303)/|F|.

---

## 4. Figures per profile [COUNTED]

* N counts the byte lookups over the padded or lifted domains, plus |S| exp pairs,
  plus |F| act pairs.
* My byte count equals the Rust count at all five Rust-counted geometries:
  * TinyLlama T32, T64, T128 and T512 (`results/zk60_1b_native_20261017/r3-ladder-count.log`);
  * 8B T32 (`r4-fast.log:131`).
* "Run" means the union over the blocks, which is D15's reading.

| profile | N | pair share of N | per block: derived = memo | per block: crude 2N | per block: R14 4N | per run: derived = memo | per run: crude | per run: R14 | helper zero-checks, block / run |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| TinyLlama T32, row 2^12, 22 blocks | 6,266,880 | 0.448 | 2^-105.42 | 2^-104.42 | 2^-103.42 | 2^-100.96 | 2^-99.96 | 2^-98.96 | 2^-117.77 / 2^-113.32 |
| TinyLlama T64, row 2^13, 22 blocks | 13,451,264 | 0.446 | 2^-104.32 | 2^-103.32 | 2^-102.32 | 2^-99.86 | 2^-98.86 | 2^-97.86 | 2^-117.71 / 2^-113.26 |
| TinyLlama T128, row 2^14, 22 blocks | 30,572,544 | 0.444 | 2^-103.13 | 2^-102.13 | 2^-101.13 | 2^-98.67 | 2^-97.67 | 2^-96.67 | 2^-117.66 / 2^-113.20 |
| Llama-3-8B T32, row 2^13, 32 blocks | 12,271,616 | 0.449 | 2^-104.45 | 2^-103.45 | 2^-102.45 | 2^-99.45 | 2^-98.45 | 2^-97.45 | 2^-117.72 / 2^-112.72 |
| Llama-3-8B T512, row 2^15, 32 blocks (speed plan layout; unregistered) | 323,026,944 | 0.445 | 2^-99.73 | 2^-98.73 | 2^-97.73 | 2^-94.73 | 2^-93.73 | 2^-92.73 | 2^-117.53 / 2^-112.53 |
| Llama-3-8B T512, row 2^16, 32 blocks (recount's projection) | 323,092,480 | 0.445 | 2^-99.73 | 2^-98.73 | 2^-97.73 | 2^-94.73 | 2^-93.73 | 2^-92.73 | 2^-117.52 / 2^-112.52 |

The largest p/N, at 8B T512, is 5.7 × 10^10. The condition p > N holds with a wide
margin in every block, and it would still hold for a whole 32-block run counted as
one block.

---

## 5. Holes looked for (item 3)

| possible hole | finding |
|---|---|
| A challenge drawn before a commitment it must bind | **None.** β, γ and α come after `A`, which holds the multiplicities and every looked-up plane, and after `M`. `H` comes after α. Every τ and μ comes after `H`. This is the same order on both sides (`protocol.rs:979-1104`, :1199-1207). |
| A multiplicity column that absorbs a cheat | **None.** The multiplicities are free, but a bad query's pole has no table pole to cancel it (§3.2, B3). |
| p ≤ N for some family | **None.** The largest N in a block is 3.2 × 10^8, against p ≈ 1.8 × 10^19. |
| The padded table admitting extra values | **None.** Entries repeat `i mod 256`, and the pad-zero term zeroes padded m and g. |
| An `H` plane in the sum with no constraint | **None.** Each plane is in exactly one relation (§2). |
| Table tags colliding | **None.** 129, 133 and 134 are distinct. γ = 0 is inside B1's 768/\|F\|. |
| A pair helper freed by a double pole | **Real**, and missed by the memo's item 4. It is absorbed by the counting step (§3.3), and it sets the lower bound (§3.4). |
| A zero-multiplicity table pole | Real, and counted by the memo: T_d/\|F\|. |
| Lookups gated off on padded positions | Not done (`argument.rs:973-980`). Padded positions are looked up and counted in N. |

Nothing found breaks the bound.

---

## 6. Corrections to the checked text (wording only; no number moves)

1. **MEMO_G02 §3.1, item 4.** "Query-side poles are not a soundness term" holds only
   for single-lookup helpers. Suggested replacement:

   > A query-side pole is a refusal for a single helper and for a pair with unequal
   > members. For a pair with two equal members it frees the helper (R13's "both
   > zero" case). That event is charged at |PP|/|F| and absorbed by the
   > distinct-pole count, since |V| + |PP| ≤ N.

2. **The constant is written three ways.**
   * MEMO_G02 §3.1 gives N + 2303.
   * The memo's §2 table and `g02_levers.py` give N + 2304 (3·768).
   * `RECOUNT.md` §3 and `recount.py` give N + 1536. That form leaves out the
     zero-multiplicity table pole.

   The correct constant is 3·768 − 1 = 2303. Every printed figure is unchanged to
   0.01 bit, since 2303/N < 4 × 10^-4.

3. **RECOUNT §3's wording** that "the derivation gives N plus 1,536" should name all
   three terms.

---

## 7. Two remarks outside the claim (for the security owner; not adopted)

* **Composition across blocks.** The per-run figures above use D15's union over
  blocks.
  * For the LogUp term specifically, a forger must get past the LogUp check of the
    first block where it cheats.
  * Another block's α gives no second chance to rescue that block's bad lookups.
  * A sequential-composition argument in the interactive model would therefore
    bound this term's run contribution near the largest single block. That is about
    5 bits better than the union at 32 blocks.
  * I have not written that argument out against the run's cross-block openings,
    where B_k is opened in block k+1. I flag it only.
* **Fiat–Shamir.** Every figure here is for the interactive protocol.
  * After Fiat–Shamir, a prover can grind the `A` mask randomness to get fresh
    (β, γ, α), one full `A` commitment per try. So the per-block term is also the
    per-try success rate (the memo's "work-factor reading").
  * The obligations doc §4.6 notes that the multi-round loss is not quantified
    anywhere.

---

## 8. Reproduction

* `python3 -B results/zk60_soundness_recount_20261017/check_logup/check_logup.py`
  * It prints every figure (copy in `check_logup.out.txt`) and writes
    `check_logup.json`.
  * One thread, under 0.1 s.
  * It was written from `shape.rs` and `layout.rs`, not from the recount lane's
    scripts. It only compares against their printed figures at the end: all OK.
* Ledger: `PROGRESS.md` in this directory.
