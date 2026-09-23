# The non-linear channel at the shaped layouts (gap GS-13)

**Status: DRAFT, UNCHECKED.** Written by one delegated Opus agent on
2026-09-22 (started 19:41 PDT). Not attacked by anyone yet. **Not a privacy
acceptance** — only the security owner rules, and nothing here has been ruled
on.

## 0. Plain words first

(pending — written last, in the final commit)

## 1. What the toy's non-linear argument claims, and what it rests on

### 1.1 The claim

The toy block's privacy argument (`ZK60_JOINT_LAW_COMPOSITION.md`, accepted
core, disposition J-1 … J-5) splits the published field view into

* the **linear channel** `V_pcs` — every PCS object of `A`, `H` and the two
  endpoints, *including the 173 terminals* — and the masking commitment's
  opening `V_M`; both affine in the hidden data and the blinding;
* the **sumcheck channel** `V_sc` — the 23 published scalars `Γ_s` and the
  721 masked round values — which is a polynomial of degree up to `d_s` in
  the hidden data, and whose extension rounds are in addition non-linear in
  the reserved mask pairs (§1.4 of the composition memo).

"The non-linear channel" (privacy case item 21; GS-13 at the shaped layouts)
is everything in Theorem 3.3 of the composition memo **except** hypothesis
(H1): the argument that `V_sc` and the one cross-channel link through `M`
add nothing to what `V_pcs` already shows. Stated as the claim this memo
tests, at fixed non-refused challenges `ρ` and in the uniform-blinding
idealisation:

> **(NL)** For every hidden input `w` and every value `π` of the PCS
> blinding on the honest support:
>
> 1. **(Lemma 2.2)** in the claimed-sum coordinates `T′`, the sumcheck
>    channel is `T′(w, π) + R(a)` with `T′(w, π) ∈ C` and `R(a)` uniform on
>    the public subspace `C` — so `V_sc` is uniform on `C` and independent of
>    `(w, π)`;
> 2. **(Lemma 3.1)** `M`'s opening depends on the mask coefficients `a`
>    only through one `Fp2` value `V(a)`;
> 3. **(Fact 3.2 and its second bullet)** on the honest support
>    `V(a) = V_pub(V_sc, V_pcs)`, a fixed public polynomial (degree `≤ d_s`
>    in the terminals), and `V` is constant on the fibres of `R`.
>
> Hence `(V_sc, V_M)` given `V_pcs` has a law that does not depend on
> `(w, π)`, and Theorem 3.3 follows from (H1).

**The terminals are where the two channels meet.** A terminal is
`term_k = cd·T̃_k(point_k) + cm_k·(R_re + U·R_im)(tail_k)`. Its joint law
with the PCS openings is (H1) — the linear channel, the terminal-surjection
review, the shaped lemma — and **not** this memo's subject. What (NL) needs
of the terminals is narrower: that the value the verifier plugs into the
slot polynomial is exactly what the prover's extension rounds produce (the
verifier's `vals`), and — by (NL.1) — that conditioning on `V_sc` does not
change their law.

### 1.2 The dependencies, each testable at a shape

Toy citations are the composition memo's (toy tree); lane citations were
read by me at the lane worktree `zk60-private-block-125m`, head `d597a1d`
(argument.rs last changed at `9e11312`, stage 35). The last column says how
§2 tests each one.

| # | Dependency | Used by | At the toy | Where it lives at the lane (`d597a1d`) | Tested in §2 by |
|---|---|---|---|---|---|
| **D1** | exactly `d_s + 1` values per round, one declared degree for all `N_s = main + ext` rounds | Fact 2.1 step 2 | ruling G-3 invariant | `zkp-core/src/sumcheck.rs:148-150` (verify); `hashline/src/zk.rs:1094` (extension round asserts `degree == mask.degree`) | S3 (control C6) |
| **D2** | the CFS mask has `L_s = N_s d_s + 2` coefficients over **all** `N_s` variables, per-variable degree `d_s` = the declared degree | Fact 2.1 | PROVED, shape-free | `sumcheck.rs:189-274`; `layout.rs:1183-1185` (`mask_specs` = `(main + ext, d)`); `zk.rs:1096` (the extension round uses `mask.round(prev.len())`) | S3 at every `(N, d)` |
| **D3** | `c_s ≠ 0`, refused, never redrawn | Lemma 2.2 (ii) | VERIFIED | `argument.rs:476-479` | shape-free code |
| **D4** | the honest round polynomials fit degree `d_s`: per-variable degree of the slot polynomial `≤ d_s` in the main rounds, product degree `≤ d_s` in the extension rounds (every table is affine in `X` there) | `T′(w, π) ∈ C` | declared `≤ 4`, read | declared degree = `BASE_DEGREE + indicator + group_eq`, `shape.rs:1139-1188` | S1 (walk), S4, control C5 |
| **D5** | **the construction premise**: `poly(exts_m) ≡ 0` for each extension round `m`, *identically* in the extension values — every table that is not a private table of round `m` is hard-zeroed | `T′(w, π) ∈ C` for every `π`; Fact 3.2 | VERIFIED by reading 23 closures: 21 by a public factor, slots 08/09 by different extension rounds | `argument.rs:18-22` (premise), `:534-541` (`exts`); the lane's Rust test `s24_tests.rs:749-835` (ruling C-7) | S1 (exact + syntactic), S4, controls C1-C4 |
| **D6** | **semantic completeness**: the claimed sum equals the true sum for every admissible witness (Private: by construction, `argument.rs:523`; Standalone and Host: because the relations hold) | `T′(w, 0) ∈ C` | "admissible" + measured proofs | not a structural fact — this is GS-14's territory | **not testable from the IR** (§3.3, GN-1) |
| **D7** | `T ↦ T′` invertible: every hosted slot runs before its host | Lemma 2.2 | VERIFIED | `layout.rs:912-919` (`HOSTS`), prover `argument.rs:525`, verifier `:561` | S2 (source parse) |
| **D8** | `M`'s geometry: `L_s + 256 ≤ 512`, `2·23 + 4` rows, `b[m] = −b[0]`, functional weights on the first `L_s` positions, `mask_verify`'s check inventory | Lemma 3.1 | PROVED on M-3 | `zk.rs:373-375`, `:481-514` (assert `:493`, `b` `:505`), `combined_weights :521`, `mask_verify_tagged :648-685`; `M_ROWS` `layout.rs:930`; shape refusal C-4 `shape.rs:415-426` | S2 (budget) |
| **D9** | a Private slot contributes **no** `Γ` functional; Standalone and Host `Γ` values are the published scalars | Fact 3.2 part 2 | VERIFIED | `argument.rs:603-614` | S2 (kinds, 34 functionals), S4 in-test control |
| **D10** | every non-private `vals` entry is public: `sel·eq_point` for an `eq` table (the group `eq` included), `sel·eval_mle_ext` for a public table (the support indicator included) | Fact 3.2 part 1 | VERIFIED | `argument.rs:565-579` | S1 (table kinds), S4 |
| **D11** | `eval_weights` and `sum_weights` lie in `rowspace(R_s)` (they annihilate the kernel line) | `V` factors through `R` | PROVED | `sumcheck.rs:222-243` | S3 |
| **D12** | mask coefficients uniform and independent of `(w, π, μ)` | Lemma 2.2 (iii) | ASSUMED (M-3, D9) | `zk.rs:485` (`CfsMask::random`) | assumption, not tested |
| **D13** | terminal = `cd·T̃ + cm·(R_re + U R_im)(tail)`, `cd = Π(1 − e_m)`, `cm = e_r Π_{m>r}(1 − e_m)`; `e ∉ {0, 1}` refused; pair weights `(cm, cm·U)` | the `vals` formula; (H1) | VERIFIED | `argument.rs:543-545`, `:586-597`, `build_claim :373-387` | S4 (formula), terminal-pair model, controls C7/C8 |
| **D14** | *(this memo's method only)* the slot IR is the closure | — | — | the lane's IR oracle tests (`slot_ir_tests.rs`); stage 35's three commits report the IR leg "576 points, every one equal" after the last change to `argument.rs` | CITED, not re-run |

### 1.3 What already existed at the shaped layouts, and what this memo adds

GS-13 was written into `ZK60_GENERIC_RANK_LEMMA_SHAPED.md` (§7) as "worse at
a shaped layout: degrees reach 5, the bilinear closures carry a public `eq`,
eight slots carry a support indicator; G-R2 untouched **here**". Parts of
it had been worked elsewhere, and this memo builds on them rather than
repeating them:

* `ZK60_JOINT_LAW_COMPOSITION_RUN.md` §2.1 proved (H2) shape-free (D1, D2,
  D11) and §2.8 reduced (H3) (D8); its count table is **stale** (§3.4 below).
* `ZK60_SLOT_CLOSURES_SHAPED.md` and its disposition (2026-09-21 01:22)
  narrowed G-R2 = (H4): the premise as the zero polynomial at 92 of 92
  slot-shape pairs, mask tightness on 1,120 checks, on **hand ports**; ruling
  C-7 put a Rust test on the lane (`s24_tests.rs:749-835`).

What this memo adds: (a) every dependency re-derived from the lane's
**canonical slot-IR exports** — a third source, neither hand port nor
closure — at all nine exported shapes; (b) the Theorem 3.3 **fibre
construction** executed slot by slot (two worlds, different witnesses,
identical published view, identical `M` value); (c) where each of GS-13's
three new objects enters, factor by factor; (d) a dependency-by-dependency
verdict and the list of what is still owed.

## 2. The dependencies, tested slot by slot at the shaped layouts

(pending)

## 3. Verdicts: lifts unchanged / needs a new argument / gap or counterexample

(pending)

## 4. What this memo does NOT establish

(pending)

## 5. Evidence

(pending)

## 6. What an independent checker should attack first

(pending)
