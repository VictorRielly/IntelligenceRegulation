# Masked, streamed LogUp-GKR for the W16 block: zero-knowledge design note

2026-11-01. For Claude (coordinator) and the security owner. **Every statement here is UNREVIEWED.** It is a
list of design obligations, not a privacy or soundness property. P1 is unchanged and is not reopened: inputs,
outputs and activations stay hidden, and weights stay public.

## The tree being hidden

One tree per block, 2^25 leaves (`p`, `q`):
- **Queries:** `(1, c_w − v)`. Here `v` is the W16 query's linear form `Σ c_i·plane_i + cst` over committed `A`
  planes, and `c_w = α − γ·w`.
- **Table entries:** `(−m, c_w − t)`. `m` comes from the histogram sub-planes, already committed in `A` before
  `α` (B-2).
- **Pads:** `(0, c_w − t)`. A pad repeats a `(width, value)` entry with multiplicity 0, as P-3 requires.
- **Two blinding leaves** (§1).

Every layer value is private, and so are the root, every layer's finals and the final leaf claim.

## 1. Root and layer 1: blinding leaves (candidate)

- One blinding leaf goes in each half of the tree, so one under each child of the root: `(s·r1, r1)` in the left
  half and `(−s·r2, r2)` in the right half.
  - `s` is uniform in Fp2; `r1` and `r2` are independent and uniform in Fp2\{0}.
  - All four values are committed in `A` before `α`.
- The layer-1 message is `(f·a, −f·b, a, b)`:
  - `a = Q_L·r1` and `b = Q_R·r2` are uniform in Fp2\{0};
  - `f = P_L/Q_L + s` is uniform.
  - The root is `(0, a·b)`.
  - In the marginal, the message is a function of three uniform values. That is not a joint-view proof.
- **Prior negatives respected.** Nothing is disclosed or reused, and the two scales are never shared:
  - a single shared `r` leaks the quadratic character of `D` (H109);
  - a shared `δ` across two trees leaks `d_a/d_t`, as an independent project found
    ([tessera PR #325](https://github.com/AbdelStark/tessera/pull/325), unreviewed).
- **Soundness.** The blinding values are fixed before `α`, so a cheating prover cannot choose them to cancel a
  wrong identity, except with probability about `(N + T + 2)/|Fp2|` (to be recounted).
- The verifier checks `q_root ≠ 0`. That check covers every denominator, including unused table entries and the
  blinding leaves. Controls C6 and C9 show this; C9 is a `(0,0)` leaf that passes a numerator-only check.
- **Alternative.** tessera's RFC-0032 uses a forest of at least two trees and a masked root-identity sumcheck. It
  doubles a lone tree's leaves, which is ×2 work here.

## 2. Layer claims, k ≥ 2: Libra masks with Z over the parent coordinates only

- **The leak.** Plain GKR reveals `p_{k+1}(ρ, c)` and `q_{k+1}(ρ, c)` at the child bit `c ∈ {0,1}`.
  - Libra masks with `V' = V + Z·R`.
  - With `Z` taken over every coordinate, `Z` vanishes at the Boolean child bit and hides nothing.
  - tessera found the same leak.
- **The fix.** Use `Z_k(x) = Π_{j ∈ parent coords} x_j(1 − x_j)`, and
  `p'_{k+1}(c, x) = p_{k+1}(c, x) + Z_k(x)·R^p_{k+1}(c, x_last)`. `q` is masked the same way.
  - `R` is small: multilinear in `c` and degree ≤ 2 in one parent coordinate, so about 6 coefficients.
  - The relation holds on the hypercube.
  - Only the last round of each layer sumcheck sees `Z ≠ 0`. That round's degree rises from 3 to 7, which adds
    O(1) prover work per layer.
  - The verifier's next claim includes `Z_k(ρ)·R(μ, ρ_last)`, which is one `M` functional per function per layer.
- **Round messages.** Every layer's round messages carry a CFS mask `g_k`, as in `zk.rs` (b)(i). It has `k`
  variables and degree ≥ 7, because of the last round, and comes with its `Γ` correction.
- **Layer 1** has no parent coordinate, so it is covered by §1 instead.
- **The leaf layer** needs the same mask, because its finals reveal four leaf-MLE values. Two alternatives:
  - `R^p_n` and `R^q_n` in `M`;
  - CFS last-round-extension mask rows on the leaf tables: two to four `A` rows (one base-field row for `v`, one for
    `m`).

## 3. Leaf claim sites: no new opening points (proposal)

- **The claim is linear in committed data.**
  - `Q_n(z) = Σ_seg eq(z_hi, seg)·(c_w(seg) − L̃_seg(z_lo))`, plus table and blinding terms.
  - `P_n(z)` is a public eq-sum over the query segments, plus `−m̃` terms and blinding terms.
- **Proposal.**
  - Run each domain zero-check (D, Q, Kv, S, F, L, Tab) after the GKR.
  - Take its eq point `τ_dom` as `z` restricted to that domain's coordinates.
  - Add one β-weighted linear term `Σ_x eq(z_lo, x)·Σ_seg w_seg·L_seg(x)`. Its claimed sum is the domain's share of
    the leaf claim, sent masked like any zero-check claimed sum (`S'' = S + c·G`).
  - The verifier checks that the shares plus the public part equal the masked leaf claim.
- **Openings.** Planes stay opened only at the zero-checks' existing terminal points, under their existing mask
  pairs. D12 (one opening per commitment) is unchanged.
- **What is removed.** The range helper planes, the table-helper part of `TAB`, and every helper constraint term in
  the domain zero-checks. The exp/act helpers stay in `H` unless they also join the tree; that variant retires `H`.

## 4. Extra rows and receipt bytes

COUNTED, for 2^25 leaves: 24 sumcheck layers plus layer 1. The receipt total itself is not measured here.

| Item | Change |
|---|---|
| `M` masks: per layer `g_k` (≤ 7k + 2 ≤ 170 coefficients) plus `R^p`, `R^q` (≤ 12) | **+144 rows** unpacked (3 masks × 2 rows × 24); **+48 rows** packed, one spec per layer of ≤ 182 + 256 pads ≤ 512. Today: 50 |
| `M` commit time | +0.009 to +0.026 s if linear in rows (today 0.009 s for 50 rows). `M` does not depend on the witness, so it can be committed off the critical path |
| Functionals | about +96 (4 per layer) |
| `A` | +1 small block for the 4 blinding values; +2 to 4 rows if the leaf layer uses CFS extension rows |
| `H` | **−1,970 rows** (32,276,480 helper words / 16,384) |
| Receipt: `H` opened columns | 1,970 × 256 × 8 B = **−4.03 MB** |
| Receipt: retired `H` claim groups (D, Q, Kv, L, table helpers) | about 5 × (16,384 + 256) × 16 B = **−1.33 MB** |
| Receipt: GKR messages | 300 rounds × 64 B, + 24 × 64 B extra last-round coefficients, + 25 × 64 B finals: about **+22 KB** |
| Receipt: `M` rows | 48 to 144 × 256 × 8 B = **+98 to +295 KB** |
| **Net** | about **−5.0 to −5.2 MB per block** |

## 5. Main risks (all open)

1. **Joint-view simulation.**
   - The simulator must cover, jointly: 25 layers of masked finals, the CFS-masked rounds, the zero-check shares, the
     PCS openings, salts, and repeated attempts.
   - Each `R` must have more degrees of freedom than the evaluations it reveals.
   - Nothing here is proven.
2. **The split leaf claim.** It adds linear relations among masked values. It must not reveal a domain's
   `Σ_seg L̃_seg(z)`.
3. **The blinding scalars.** They enter a final check with public eq coefficients; tessera flags this as an open
   accounting issue. They must stay inside the masked shares.
4. **Prior negatives (binding).**
   - No root and no subgroup sum is serialized.
   - No whole-tree residency. Measured: 16.1 B/leaf of heap above the leaf values, against 48 B/leaf for a resident
     tree. Layer n−1 is never stored.
   - No mask row per intermediate node: the masks are O(k) coefficients per layer in `M`, not 2^k rows.
5. **Schedule.** The GKR must run after `H` and before the domain zero-checks.
   - That reorders the slots, so it needs a new profile string (D17).
   - The DD variants need the same treatment.
   - The `TAB` and `ZS` slots change.
6. **Mask degree.** The CFS mask degree must cover the degree-7 last rounds.
7. **Soundness accounting (re-derive).**
   - LogUp `(N + T)/|Fp2|`;
   - the GKR sumchecks, `≤ Σ_k (3(k−1) + 7)/|Fp2|`;
   - the Libra masks;
   - the tag fold `γ`, unchanged from W16.

None of this is a privacy acceptance. The native owner and the security owner decide whether the construction is
worth a versioned profile. On this experiment's numbers, the range-lookup-only variant buys ×1.00–1.15 per block at
most (see README); it is ruled worthwhile only together with retiring `H`.
