# The non-linear channel at the shaped layouts (gap GS-13)

**Status: DRAFT, UNCHECKED.** Written by one delegated Opus agent on
2026-09-22 (started 19:41 PDT). Not attacked by anyone yet. **Not a privacy
acceptance** — only the security owner rules, and nothing here has been ruled
on.

> **Status update, 2026-09-22 evening: CHECKED and RULED.** Attacked by
> `ZK60_NONLINEAR_CHANNEL_SHAPED_CHECK.md` (independent monomial expansion,
> own field library, own parser); ruled in
> `ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md` (NL-1..NL-9). No
> counterexample; core accepted as an algebraic reading. **Errata that
> override the text below:** (N-1) the fibre test "207 of 207" is a test
> only for the 108 Private-slot rows; at the 11 Standalone and Host slots its
> worlds were not the protocol's — the check's re-run with the real slot
> kinds (4 Standalone at the full rung-G cube, 18 host runs, 4 full-size
> 125M runs of slots 08/09) is the evidence there, all pass; (N-2) the
> in-test D9 control cannot fail — D9 stands from `argument.rs:613` (a
> Private slot pushes no Γ functional; read by the security owner), and the
> check's host-run control (18/18) replaces it; (N-3) the run memo's stale
> totals sat in four places, all now corrected with a dated note; (N-4)
> rung-G's largest `L` 72 is a tie of slots 17 and 18; (N-5) the "69 / 69"
> terminal rank and controls C7/C8 are illustrations that cannot fail, not
> tests — they leave the headline figures.

> **Headline: no counterexample.** At rung-G, rung-K4 and 125M (and five
> further development shapes) every one of the 23 slots satisfies every
> dependency of the toy's non-linear argument that can be tested from the
> slot polynomials; the argument lifts **unchanged in its proof**. One
> dependency — completeness for every admissible witness (GS-14) — cannot be
> tested this way and stays open (§3.4, GN-1). The linear channel (H1) is
> not this memo's subject and stays open at the shaped layouts.

## 0. Plain words first

**What was asked.** The toy block's privacy argument has two halves. The
*linear* half shows that the commitments' openings give nothing away. The
*non-linear* half — this memo — shows that the curved part of the proof (the
sumcheck messages, whose values are polynomials in the hidden data, and the
one number the mask commitment reveals about them) gives nothing away either.
At the big shapes three things changed that the toy never had: some
polynomials are one degree higher (5 instead of 4); the two attention-score
steps now multiply by a public "which key-value group" factor, because of
the completeness repair of finding S19-F1 (2026-09-20); and eight steps multiply by a
public padding indicator. Gap GS-13 asked whether the non-linear half
survives that.

**The answer: yes, as far as it can be checked without a receipt, and I
could not break it.** I wrote down the toy argument's fourteen dependencies
(§1.2) and tested each one on the lane's own machine-readable description of
the 23 polynomials — not a hand copy — in exact field arithmetic:

* the masking "just covers" every step at every size the shapes use —
  **210 of 210** exact rank computations at full size;
* every step's polynomial vanishes where the protocol needs it to, and now
  for the stronger of the two possible reasons — a public factor in every
  term — at **184 of 184** step-and-shape pairs (the toy needed the weaker
  reason at two steps);
* for every step at every shape, I built **two worlds with different hidden
  data that publish exactly the same numbers**, and checked that the one
  value the mask commitment reveals is the same in both — **207 of 207**
  (on small stand-in tables);
* twelve deliberate breakages were each caught (or, where they should not
  matter, correctly not caught).

**Why the three changes do not hurt.** The masking grows with the degree
automatically, so degree 5 costs bytes, not privacy (the tightest step uses
117 of its 256 slots). The group factor is public and zero exactly where the
argument needs a zero — it makes the attention steps *more* robust than at
the toy. Every padding indicator is public and always sits next to another
public factor.

**What is still owed.** (1) Completeness for every admissible hidden input:
if some legal input made an honest proof fail, the *failure itself* would
leak; no algebra check can see that, and the evidence at 125M is dense
test runs, not a proof (GN-1). (2) The linear half at the big shapes. (3) The
hash layer and runs. Also three wording fixes to the toy argument (§3.3), a
stale count in the run memo corrected (§3.5), and one design note for the
future weights-hidden version: there, the seven matrix-multiply steps would
lose their public factor and need a design change (§3.3, C9).

**This is a draft by one agent, unchecked, and not a privacy acceptance.**

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

### 2.1 Method, and the labels

Everything below is produced by `results/zk60_nonlinear_channel_shaped/nl_check.py`
(Python, `python3`, no Rust built or run, ~30 s), with its own Goldilocks
`Fp2` arithmetic (`nl_field.py`: `p = 2^64 − 2^32 + 1`, `u² = 7`, 7 checked
to be a non-residue). It reads the lane's **canonical slot-IR exports**
(`results/zk60_block125m_lane/x34-slot-ir/slot_ir_*.json`, schema
`zk60-slot-ir/1`, nine shapes: `m125`, `rung_g`, `rung_k4`, and the
development shapes `rung`, `rung_p2`, `rung_c6`, `rung_w14`, `rung_e32`,
plus `toy` as the anchor), and parses three lane sources for constants only
(`HOSTS`, `SLOT_KINDS`, the extension-round argument of every private push
in `define`). Input SHA-256 digests are pinned in `nl_check.json`.

A challenge-valued coefficient never leaves the Rust process (the export
carries its provenance, not its value, `slot_ir.rs:515-527`), so the check
gives every challenge coefficient a random value: `ζ^j` as powers of one
random `ζ`, `mu[k]` / `nu[k]` one per label, every other challenge
coefficient independently **per occurrence** — so no identity below can hold
by an accidental relation between coefficients.

Labels used for figures in this memo:

* **COUNTED** — read or counted from the IR exports or the sources.
* **MEASURED** — computed by this check, in exact arithmetic, on the **real**
  object at its real size: the real slot polynomial (the IR), or the real
  `(N, d)` of a mask. "Measured" here never means a receipt; nothing in this
  memo reads a capture.
* **MODEL** — computed on a stand-in: the miniature cube runs of §2.5 (real
  polynomial, real extension structure, real declared degree; random tables
  on 3 main variables), the terminal-pair model of §2.6, the P3 probe.
* **CITED** — another document's or the lane's figure, not recomputed here.

**The toy export reproduces the toy memo's counts** [COUNTED]: 159 main + 25
extension rounds, 721 round values, 173 terminals (120 `A`, 51 `H`, 2
endpoint), `Σ L_s = 583`, `Σ dim C_s = 560`, largest `L` 50. **And the
rung-K4 export reproduces the slot-closures check's measured word count**:
23 scalars + 1,070 round values + 176 terminals = **1,269** `Fp2` words per
stage, the figure that disposition records for the real four-group bundle
[COUNTED here; the 1,269 is CITED from `ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md` §1].
At 125M the same count is 23 + 1,554 + 174 = **1,751** `Fp2` words per block
[COUNTED].

### 2.2 The 23 slots at 125M

Columns: `(main, ext, d)` is the slot's schedule; "max / per-var" is the
product degree walked from the IR bodies and the per-variable upper bound
(eq-type tables counted only on their own variables, every other table on
all); `L` the mask length; "public factors" the public tables and where
GS-13's two new objects enter (`W` = a term wrapper, `F` = a plain factor
of a product, `1−supp` = inside the pad rule's affine node); "premise" is
D5's mechanism. Every figure is COUNTED from `slot_ir_m125.json` except the
premise column (MEASURED: exact evaluation of the real polynomial at three
seeds per extension round, plus the mechanism probe with every public table
zeroed and every private table random) and the last column (MODEL, §2.5).

| slot | name (kind) | `(main, ext, d)` | max / per-var | `L` | public factors, and where the new ones enter | private | premise, mechanism | §2.5 |
|---|---|---|---|---:|---|---:|---|---|
| 00 | SS row sums `norm_a` (Private) | (19, 1, 4) | 4 / 3–4 | 82 | `eq(r_t)`; **`supp(D)` W** | 1 | holds; public factor | pass |
| 01 | SS row sums `norm_m` (Private) | (19, 1, 4) | 4 / 3–4 | 82 | `eq(r_t2)`; **`supp(D)` W** | 1 | holds; public factor | pass |
| 02 | norm squares ZC, hosts 00, 01 (Host) | (9, 1, 3) | 3 / 3 | 32 | `eq(tau)`, `eq(r_t)`, `eq(r_t2)` | 22 | holds; public factor | pass |
| 03 | limb ZC (Standalone) | (14, 1, 4) | 4 / 4 | 62 | `eq(tau)` W; **`supp(L)` only as `1−supp`**, under `eq(tau)` | 3 | holds; public factor | pass |
| 04 | masked row sums + selector (Private) | (22, 1, 4) | 4 / 3–4 | 94 | `eq(p_ht)`, causal mask; **`supp(S)` W** | 2 | holds; public factor | pass |
| 05 | Q matmul (Private) | (10, 1, 2) | 2 / 2 | 24 | folded `W_q` | 1 | holds; public factor | pass |
| 06 | K matmul (Private) | (10, 1, 2) | 2 / 2 | 24 | folded `W_k` | 1 | holds; public factor | pass |
| 07 | V matmul (Private) | (10, 1, 2) | 2 / 2 | 24 | folded `W_v` | 1 | holds; public factor | pass |
| 08 | score, bilinear (Private) | (8, **2**, 3) | 3 / **3 on the 2 group bits, 2 elsewhere** | 32 | **`eq(r_g)` W over the leading 2 variables** | 2 (rounds 0, 1) | holds; public factor **and** different rounds | pass |
| 09 | PV, bilinear (Private) | (11, **2**, 3) | 3 / 3 on group bits, 2 elsewhere | 41 | **`eq(r_g)` W** | 2 (rounds 0, 1) | holds; public factor **and** different rounds | pass |
| 10 | Wo matmul (Private) | (10, 1, 2) | 2 / 2 | 24 | folded `W_o` | 1 | holds; public factor | pass |
| 11 | gate matmul (Private) | (10, 1, 2) | 2 / 2 | 24 | folded `W_g` | 1 | holds; public factor | pass |
| 12 | up matmul (Private) | (10, 1, 2) | 2 / 2 | 24 | folded `W_u` | 1 | holds; public factor | pass |
| 13 | down matmul (Private) | (11, 1, 2) | 2 / 2 | 26 | folded `W_d` | 1 | holds; public factor | pass |
| 14 | D ZC, hosts 10, 13 (Host) | (19, 1, **5**) | **4** / 4 | 102 | `eq(tau)`, `eq(p_a)`, `eq(p_z)`, `gamma_a`, `gamma_m`; **`supp(D)`: W ×2 (host terms), F ×1 (inside the zero-check), `1−supp` ×1** | 54 | holds; public factor | pass |
| 15 | Q ZC, hosts 05, 09 (Host) | (19, 1, **5**) | **4** / 4 | 102 | three `eq`, RoPE cos / sin; **`supp(Q)`: W ×2, F ×1, `1−supp` ×1** | 15 | holds; public factor | pass |
| 16 | KV ZC, hosts 06, 07 (Host) | (17, 1, 4) | 4 / 4 | 74 | three `eq`, RoPE cos / sin (no indicator: `Dom::Kv` does not pad at 125M) | 13 | holds; public factor | pass |
| 17 | softmax ZC, hosts 04, 08 (Host) | (22, 1, **5**) | **5** / 5 | **117** | three `eq`, causal mask; **`supp(Ht)` W ×1, `1−supp` ×1; `supp(S)` W ×1, F ×1, `1−supp` ×1** | 24 | holds; public factor | pass |
| 18 | F ZC, hosts 11, 12 (Host) | (20, 1, 4) | 4 / 4 | 86 | three `eq` (no indicator: `Dom::F` does not pad at 125M) | 17 | holds; public factor | pass |
| 19 | table-helper ZC (Standalone) | (14, 1, 3) | 3 / 3 | 47 | `eq(tau)` W, three value columns; **`supp(Tab)` only as `1−supp` ×2**, under `eq(tau)` | 6 | holds; public factor | pass |
| 20 | zero-sum row (Standalone) | (14, 1, 2) | 2 / 2 | 32 | the all-ones vector, as an inner factor (no wrapper) | 1 | holds; public factor | pass |
| 21 | IO-in equality (Standalone) | (19, 1, 2) | 2 / 2 | 42 | `eq(tau)` W | 2 | holds; public factor | pass |
| 22 | IO-out equality (Standalone) | (19, 1, 2) | 2 / 2 | 42 | `eq(tau)` W | 2 | holds; public factor | pass |

Totals at 125M [COUNTED]: 336 main + 25 extension rounds; `Σ L_s = 1,239`,
`Σ dim C_s = 1,216`, kernel 23 (one per slot); largest `L` 117 at slot 17
(budget `117 + 256 ≤ 512`); 174 terminals (122 `A`, 50 `H`, 2 endpoint);
declared degree 5 at three slots (14, 15 over-declared by one — ruling C-1 —
and 17 tight); **eight** slots carry a support-indicator table
(00, 01, 03, 04, 14, 15, 17, 19) and two a group `eq` (08, 09).

"Eight support-indicator slots" is the IR's count of slots that **contain**
an indicator table. It is **not** the same set as `shape.rs`'s
`INDICATOR_SLOT_DOMAIN` (`shape.rs:71-72`), which lists the eight slots whose
degree **rises** when their domain pads: at 125M six of those rise
(00, 01, 04, 14, 15, 17; `Dom::Kv` and `Dom::F` do not pad), and the other
two indicator-bearing slots (03, 19) carry the pad rule's `1 − supp` term
without a degree rise, being homogeneous. Both counts are 8 at 125M by
coincidence [COUNTED].

### 2.3 rung-G and rung-K4, where they differ from 125M

Same 23 polynomials by kind and structure; what differs [COUNTED]:

* **group bits** 1 at rung-G, 2 at rung-K4 (2 at 125M); slots 08 and 09
  are degree 3 with the group `eq` wrapper at both.
* **eleven** indicator-bearing slots, not eight: `Dom::T`, `Dom::Kv` and
  `Dom::F` pad there, so 02 (`supp(T)`, W ×2 and `1−supp`), 16 (`supp(Kv)`)
  and 18 (`supp(F)`) join, and 16 and 18 declare degree 5 with product
  degree 4 (over-declared, as 14 and 15).
* `Σ L_s / Σ dim C_s`: **859 / 836** at rung-G, **871 / 848** at rung-K4;
  largest `L` 72 (rung-G) and 77 (rung-K4), both at slot 17. 176 terminals
  (122 `A`, 52 `H`, 2 endpoint) at both.
* Premise 23 / 23, public factor in every monomial 23 / 23, degree fits
  23 / 23, miniature 23 / 23 — at both [MEASURED / MODEL as in §2.2].

The five further development exports (`rung`, `rung_p2`, `rung_c6`,
`rung_w14`, `rung_e32`) give the same four verdicts, 23 / 23 each; the
figures are in `nl_check.log`. **Over all eight shaped exports: 184 of 184
slot-shape pairs hold the premise with a public factor in every monomial;
the toy export gives 23 of 23 premise with 21 by a public factor and slots
08 and 09 by the second mechanism** — which reproduces the toy reading and
the lane's Rust test `s24_tests.rs:749-835` (the same split, computed there
from the closures) [MEASURED on the IR].

### 2.4 Fact 2.1 at every `(N, d)` the shapes use (D1, D2, D11)

The nine exports use **42 distinct `(N, d)` pairs**, `N` from 5 to 23 and
`d` from 2 to 5 [COUNTED]. For each pair, at five challenge regimes —
uniform `Fp2`, all zero, all one, alternating 0 / 1, all equal (0 and 1 are
admissible main-round challenges; only extension challenges are refused) —
the check builds the full mask map `R` from the closed-form round messages
(a port of `CfsMask::round`, `sumcheck.rs:255-274`, itself checked against
a brute-force sum over the cube on **310** values for `N ≤ 5`, `d ≤ 5`) and
computes exactly:

* `rank R = N d + 1`;
* `dim C = N d + 1` from the verifier's own chain equations, and every
  column of `R` satisfies them (`Im R ⊆ C`);
* the explicit kernel line of the composition memo §2.1 (`a′ = 1`,
  `a_{j,1} = −2^{j+1−N} Π_{i<j} ρ_i`, `a_0 = −½ Σ_{i>0} a_{i,1}`) is killed
  by `R`, and **both** `sum_weights` and `eval_weights(ρ_full)` annihilate
  it — so both lie in `rowspace(R)` (D11).

**210 of 210 (pair, regime) triples are exactly tight** [MEASURED at full
size], including `(23, 5)` (`L = 117`, the 125M softmax zero-check) and
`(13, 3)` (`L = 41`, the 125M PV slot, which the slot-closures disposition
also records). Control C6: a mask one degree short of the `d + 1` published
values at `(23, 5)` covers only **93 of 116** dimensions [MEASURED].

This is a confirmation, not a support: Fact 2.1's proof is unconditional for
every `N`, `d` and `ρ` over odd characteristic.

### 2.5 The fibre construction of Theorem 3.3, slot by slot (D4, D5, D9, D10, D13)

For each slot of each export, a **miniature** honest masked run [MODEL]: the
slot's real polynomial (compiled from the IR), its real extension-round count
and assignment (both private factors of 08 / 09 in rounds 0 and 1, every
other private table in round 0 — read from `define`, §2.7), its real declared
degree and the real CFS mask map, on a cube of **3** main variables with
random tables and random fixed challenges. Per slot:

1. the verifier's chain accepts the masked transcript;
2. the verifier-derived mask value `(fin − poly(vals))·c⁻¹` equals
   `g(ρ_full)` computed from the mask coefficients — Fact 3.2's identity,
   with `vals` built exactly as `argument.rs:565-579` builds it (`sel·T` for
   every public table, the published terminal for every private one);
3. every terminal equals `cd·T̃(ρ) + cm·R` with `cm = e_r Π_{m>r}(1 − e_m)`;
4. `rank R = N d + 1` and the **unmasked** honest transcript `T′(w, π)` lies
   in `Im R = C` (exact rank of the augmented matrix);
5. **the fibre test.** A second world is built with *independent* private
   tables (the public tables are kept — they are the statement), its
   reserved-pair values chosen so that its terminals equal world 1's
   (possible because `cm ≠ 0`), and its mask `a₂ = a₁ + Δ` with
   `R(Δ) = T′(w₁, π₁) − T′(w₂, π₂)` (possible exactly when the difference is
   in `C`). The check then confirms that the two worlds publish the
   **identical** scalar, round values and terminals, that their hidden data
   differ, and that `g(a₂; ρ_full) = g(a₁; ρ_full)` — **the one value `M`
   reveals is the same**. By Lemma 3.1 (D8, shape-free geometry) `M`'s whole
   opening then has the same law in both worlds.
6. an in-test control on D9: the slot's own mask total `c·G` differs between
   the two worlds by exactly `σ₁ − σ₂`. Had a Private slot's `Γ` been one of
   `M`'s functionals, `q` would separate the two worlds.

**23 of 23 slots pass all of 1–5 at every one of the nine exports (207 of
207), and the control of item 6 fires at 207 of 207** [MODEL].

What the fibre test does and does not show. It executes, at one slot and one
challenge vector, the bijection `a₁ ↦ a₂` that the proof of Theorem 3.3 uses:
a translation of the uniform mask, which carries world 1's sumcheck channel
and `M` value onto world 2's. It **also** shifts the reserved-pair values
(`π₁ ↦ π₂`) to align the terminals, and whether that shift is absorbed by the
rest of the PCS view is exactly (H1) — not tested here.

### 2.6 The terminals' own masking (D13)

Per slot, the map from the reserved pairs `(R_re, R_im)` to the slot's
terminals, `cm·(⟨eq(tail), R_re⟩ + U·⟨eq(tail), R_im⟩)`, has `Fp`-rank
`2m` (onto `Fp2^m`) for every slot at 125M, rung-G and rung-K4 — at random
`Fp2` tails **and** at one shared tail drawn from `{0, 1}` (admissible: the
main-round challenges 0 and 1 are not refused, so `eq(tail)` can be a unit
vector of the base field) [MODEL; the slot's real terminal count `m`, up to
54 at slot 14]. Controls: with weights `(cm, cm)` instead of `(cm, cm·U)` at
a boolean tail the rank is **1**, not 2 (C7) — the `U` in the pair shape is
what keeps a terminal onto `Fp2` when the tail's `eq` vector is base-field;
two terminals at one tail sharing one pair have rank **2**, not 4 (C8). Two
terminals sharing a pair at *different* tails still have rank 4 on the
terminals alone — the known marginal-versus-joint trap needs the PCS group
vectors to show, which is (H1), not this memo.

### 2.7 Structure read from the sources (D7, D9, D8)

[COUNTED, parsed from the lane at `d597a1d`]

* `SLOT_KINDS` (`layout.rs:885`): **12 Private, 5 Standalone, 6 Host** — a
  compile-time constant, the same at every shape; the IR's per-slot kind
  agrees at all nine exports.
* `M` functionals: `23 + 5 + 6 = 34` (`N_FUNCTIONALS`, `layout.rs:929`);
  `M_ROWS = 2·23 + 4 = 50` (`layout.rs:930`).
* `HOSTS` (`layout.rs:912-919`): six hosts, every hosted slot is Private,
  runs **before** its host, and every Private slot is hosted exactly once —
  so `T ↦ T′` is unit-lower-triangular at every shape (D7).
* Of the private pushes in `define`, exactly **two** carry extension round 1:
  `argument.rs:1341` (`A_KR8`, slot 08) and `:1367` (`A_V8`, slot 09); the
  helpers `a_range` (`:695`), `h()` (`:727`) and `endpoint()` (`:749`)
  hard-code round 0.
* `L_s + 256 ≤ 512` at every slot of every export; worst 117 (125M slot 17)
  [COUNTED], enforced as a named shape refusal (C-4, `shape.rs:415-426`).

### 2.8 The controls

Each control changes one thing in a real slot's IR (or in a model) and must
fire; two must **not** fire, to show which mechanism is carrying the premise.

| # | change | expected | result |
|---|---|---|---|
| C1 | slot 08 at 125M, both private factors moved to extension round 0, group `eq` **kept** | premise still holds (the public factor is enough) | holds — does not fire [MEASURED] |
| C2 | slot 08 at 125M, group `eq` **dropped**, rounds 0 / 1 kept | premise holds by the toy's second mechanism | holds — does not fire [MEASURED] |
| C3 | slot 08 at 125M, group `eq` dropped **and** both factors in round 0 | premise fails; chain rejects; offset outside `C` | **fires**: premise false, chain rejects, `T′ ∉ Im R` [MEASURED / MODEL] |
| C4 | slot 17 at 125M, one pad-rule subterm `mu·(1 − supp)·Σ ζ^j plane_j` moved **outside** the `eq(tau)` wrapper | premise fails | **fires**: premise false, chain rejects, `T′ ∉ Im R` |
| C5 | slot 17 at 125M declared at degree 4 (its product degree is 5) | chain rejects | **fires** [MODEL] |
| C6 | a mask one degree short at `(23, 5)` | does not cover `C` | **fires**: rank 93 of 116 [MEASURED] |
| C7 | pair weights `(cm, cm)`, boolean tail | terminal not onto | **fires**: rank 1 of 2 (honest shape: 2) [MODEL] |
| C8 | two terminals at one tail sharing one pair | not jointly onto | **fires**: rank 2 of 4 (distinct pairs: 4) [MODEL] |
| C9 | *scope probe*: the seven folded weight tables and the two norm gains treated as **private** (as under P3) | — | the premise fails at exactly the seven matmul slots 05, 06, 07, 10, 11, 12, 13; slot 14 survives (its gains sit under `eq` wrappers) [MODEL] |
| anchor | the toy export | 23 premise / 21 public factor / second mechanism at 08, 09 | as expected |

**12 of 12 control verdicts as expected** [`nl_check.log`, section S5].

## 3. Verdicts: lifts unchanged / needs a new argument / gap or counterexample

### 3.1 Counterexamples: none

**No slot, at any of the nine exports, fails any dependency this memo can
test.** No construction was found in which two admissible witnesses give
different laws of the non-linear channel at fixed challenges. The
controls show the checks have teeth (§2.8).

### 3.2 Lifts unchanged — all 23 slots, by group

The toy's non-linear argument (NL) lifts to rung-G, rung-K4 and 125M
**unchanged in its proof**, with the dependencies below re-established
[MEASURED / COUNTED / MODEL as labelled in §2]:

| group | slots | what is new at a shaped layout | where the new factor enters | verdict |
|---|---|---|---|---|
| **plain matmuls** | 05, 06, 07, 10, 11, 12, 13 | sizes only | the folded public weight table is the monomial's public factor, as at the toy | lifts verbatim |
| **bilinear pair** | 08, 09 | the group `eq(r_g, ·)` over the key-value group bits (now sumcheck variables, S19-F1's repair); degree 2 → 3 | a **public wrapper** on the single monomial `eq_g·Q·K` (resp. `eq_g·P·V`); its verifier value `sel·eq_point(r_g, ρ_g)` is public (D10) | lifts; the premise now holds by a public factor **and**, redundantly, by the toy's different-rounds mechanism (C1, C2) |
| **row-sum Private slots** | 00, 01, 04 | a support indicator; degree 3 → 4 | a **public wrapper** (`supp·eq·…`) | lifts |
| **zero-check hosts** | 02, 14, 15, 16, 17, 18 | indicators (at 125M on 14, 15, 17; at rung-G / K4 also 02, 16, 18), the pad-zero term, degree up to 5 | the indicator as a wrapper on the hosted-claim terms, as a plain factor inside the zero-check node, and inside `1 − supp` of the pad term — **every** one of them under an `eq` wrapper | lifts; 14, 15 (and 16, 18 at the rungs) over-declare their degree by one, which is harmless for the law (ruling C-1) |
| **Standalone** | 03, 19, 20, 21, 22 | the pad-zero term at 03 and 19 | `1 − supp` under the `eq(tau)` wrapper (03, 19); 20's public factor is the all-ones vector, as at the toy | lifts |

Dependency by dependency: D1, D2, D11 — confirmed at every `(N, d)`
(210 / 210); D3, D9, D10, D13 — the same code at every shape, and exercised
by the miniature (207 / 207); D4 — every slot's product degree `≤` its
declared degree, so every honest round fits `d + 1` values (184 / 184 shaped
slot-shape pairs); D5 — the premise holds as the **zero polynomial** at 184 /
184 shaped pairs; D7 — `HOSTS` triangular; D8 — worst `L` 117 of 256.

**The three things GS-13 named, answered.**

1. *"Slot degrees reach 5."* Nothing in (NL) uses a degree bound: Fact 2.1
   is degree-free and `L_s` and `dim C_s` move together through the same
   `d` (run memo §2.1). What the degree does touch is the `M`-row budget
   (worst 117 + 256 of 512) and `V_pub`'s degree (now `≤ 5` in up to 54
   terminals of one slot, against the toy's `≤ 4` in up to 56), and neither
   enters the law: Theorem 3.3 is exact for any public polynomial `V_pub`.
2. *"The bilinear closures carry a public `eq` factor."* It is a **public
   table in wrapper position**; it is zero on every extension vector, so it
   makes the premise hold for the pair more robustly than at the toy, and the
   verifier computes its terminal value from challenges alone. The group bits
   being sumcheck variables raises the per-variable degree on those bits to
   3, which is what the declared 3 covers.
3. *"Eight slots carry a support indicator."* Every indicator is a
   public-from-shape 0/1 table evaluated by the verifier (`sel·eval_mle_ext`),
   and it appears in exactly three positions — wrapper, plain factor, and
   `1 − supp` — each inside a monomial that also carries an `eq` table. It
   publishes nothing and adds no terminal (run memo §2.2).

**"Is the terminal still a uniform function of the masking randomness,
given the public transcript?"** Per terminal, yes: each is onto `Fp2`
through its own reserved pair with `cm ≠ 0` (§2.6), and — because the
sumcheck channel is independent of `(w, π)` (NL.1; `T′ ∈ C` at every slot
for independent witnesses and pair values, §2.5 item 4) — conditioning on the
published rounds and scalars does not change that. **Jointly, given the whole
public transcript, the terminals are *not* uniform, and were not at the toy:**
they satisfy the verifier's own identities — the one `Fp2` equation
`512·(q[0] + q[512]) = Σ_i θ^i·value_i` through `M` (degree `≤ d_s` in the
terminals via `V_pub`) and (H1)'s linear identities. Those relations are
public and the same for every witness; Theorem 3.3 is what says the
conditional law is witness-free, and at a shaped layout it does so on (H1).
**There is no slot where this fails.**

### 3.3 Needs a new argument: none for P1 — three restatements, one design note

No slot needs a new argument for the law under P1. The toy argument's
**wording** needs three restatements before it is true at the shaped layouts
(proposed, not made — the composition memo is not this lane's file):

* **R-a (the mechanism).** "21 slots by a public factor, 08 and 09 by
  different extension rounds" becomes, at every shape with more than one
  key-value head, "all 23 by a public factor; 08 and 09 also by different
  extension rounds". The second mechanism is now a backup, not the reason.
* **R-b ("public factor" means a public *table*).** The premise's "public
  factor in every monomial" is true only if "factor" means a table that the
  extension vector hard-zeroes. A public **affine expression with a non-zero
  constant** — `1 − supp`, a LogUp denominator `α − (cst + Σ c·plane)`, a
  host term `sum + λ_z` or `2^{SH}·s + r − 2^{SH−1}` — is **not** such a
  factor: on the extension vector it is the constant, not zero. At every
  shape every such expression sits inside a monomial that also carries an
  `eq` table (the mechanism probe, 184 / 184), and control C4 shows the
  placement is load-bearing. The slot-closures check found the same (its C4)
  and its disposition records it; the wording of the premise in
  `argument.rs:18-22` ("an eq, a public table, or the other side's zero
  extension") is already right, but nothing states the negative, and a
  future edit that moves a `1 − supp` term out of its `eq` bracket would
  break completeness (not privacy — see C4: the honest proof is rejected).
* **R-c (degree).** "Degree up to 4" becomes "up to 5", with the note that
  the law does not depend on it (§3.2 item 1).
* **Design note for P3, not a P1 finding (C9).** Under hidden weights the
  seven folded weight tables become private factors, and the seven matmul
  slots (05, 06, 07, 10, 11, 12, 13) then have **no** public factor in their
  one monomial `A·W`: with both extended in round 0 the premise fails. P3
  will need a second extension round per matmul (the bilinear slots'
  mechanism) or a public wrapper there. Slot 14's norm gains survive (they
  sit under `eq` wrappers). Recorded because P3's requirement is already
  decided (`ZK60_PRIVACY_REQUIREMENTS.md`: the full version also hides
  weights), not because anything here is in scope for it.

### 3.4 Gaps

| # | Gap | Size / nature |
|---|---|---|
| **GN-1** | **Semantic completeness for every admissible witness (D6) is not established at any shaped layout, and cannot be from the IR.** (NL.1) needs `T′(w, 0) ∈ C` for every admissible `w`: the Private slots have it by construction, but a Standalone or Host slot has it only if its relation truly holds on every admissible witness. A defect there (S19-F1 was one) is **not** a leak in an accepted receipt's field view — the honest proof is rejected — but an **input-dependent abort**, which the toy statement's second sentence ("whether the prover refuses is … a function of the challenges alone") would then be false about. The evidence at 125M is the lane's generic-witness runs — the fully dense twelve-block run (its log: every block "4/4 key-value groups live, groups differ true") and the dense two-block capture both prove and verify (`results/zk60_block125m_lane/m125-run-l12-dense.done` = 0, `m125-capture-dense-l2.done` = 0) [CITED, not re-run]; that is evidence on particular witnesses, not a proof for all. This is GS-14 inherited, and it is the one dependency of (NL) that no algebraic check here can reach. | open; owner: construction |
| **GN-2** | The IR is the closure (D14) — the lane's oracle tests, not this memo. The IR export is stage 34; `argument.rs` changed three times at stage 35, each reporting the IR leg equal (576 of 576 points). | CITED |
| **GN-3** | The miniature (§2.5) is a model: 3 main variables, random tables standing in for `eq`, public and private tables alike, one challenge vector per slot. It exercises the real polynomial, the real extension structure and the real declared degree, not real cube sizes, real `eq` tables or real claim points. The premise (§2.2) and Fact 2.1 (§2.4) are on the real objects. | MODEL |
| **GN-4** | Cross-slot coupling — the host claimed-sum map and the `θ`-batch of the 34 functionals — is checked **structurally only** (source parse: triangular `HOSTS`, 34 functionals). No multi-slot fibre construction was run. The coupling code is shape-independent. | COUNTED only |
| **GN-5** | (H1) at the shaped layouts (G-R1, the shaped lemma) and the joint law across commitments (G-R4 / GS-6) are untouched; §2.6's per-slot terminal rank is **not** (H1). | out of scope |
| **GN-6** | The Fiat–Shamir lift and the hash layer (G-R5, D19): everything here is at fixed challenges. | out of scope |
| **GN-7** | A run (boundary commitments; slots 21 / 22 across blocks): per block only. Each block has its own mask commitment and fresh CFS masks, so (NL) is per block, but the run theorem's own conditions (run memo §3) are not re-examined. | out of scope |
| **GN-8** | The refusal inventory of the non-linear channel at a shape (`c_s = 0`: 23; `e ∈ {0, 1}`: 25; `ζ = 0`: 5 at 125M) is challenge-only by the code; I did not recount it beyond the extension-round count (25 at every export) [COUNTED]. | liveness, not distance |

### 3.5 A stale figure, corrected in passing

`ZK60_JOINT_LAW_COMPOSITION_RUN.md` §2.1's count table gives
`Σ L_s / Σ dim C_s` as **840 / 817** at rung-G and **1,208 / 1,185** at 125M.
Both **predate the S19-F1 repair** (lane stage 20), which added `lkv` main
rounds and one degree to slots 08 and 09. The exports give **859 / 836**
(rung-G) and **1,239 / 1,216** (125M) [COUNTED]; the differences, +19 and
+31, are exactly the repair's: at 125M slot 08 goes from `(6, 2, 2)`,
`L = 18`, to `(8, 2, 3)`, `L = 32`, and slot 09 from `(9, 2, 2)`, `L = 24`,
to `(11, 2, 3)`, `L = 41`. The kernel total (23), the worst `L` (72, 117)
and every verdict of that section are unchanged. Rung-K4, which the table
predates, is 871 / 848.

## 4. What this memo does NOT establish

1. **Not a privacy acceptance, and not a privacy property.** It re-tests,
   at the shaped layouts, the hypotheses (H2)–(H4) of the toy's Theorem 3.3
   and the proof's fibre step, per slot, at fixed challenges, in the
   uniform-blinding idealisation. Only the security owner rules.
2. **Not (H1).** The linear channel at the shaped layouts — the generic-rank
   lemma, the terminal surjection jointly with the PCS openings, the joint
   law across commitments (G-R1, G-R4, GS-6) — is untouched. Theorem 3.3 at
   a shaped layout remains conditional on it.
3. **Not completeness for every admissible witness** (GN-1). The one
   dependency of (NL) that an algebraic check of the slot polynomials cannot
   reach; a defect there would surface as an input-dependent abort.
4. **Nothing was measured on a receipt or a capture.** Every figure is from
   the IR exports, the sources, or a model built from them. "MEASURED" in
   this memo means exact arithmetic on the real polynomial or the real mask
   map, never a proof byte.
5. **Not an independent check that the IR is the closure** (GN-2) — the
   lane's oracle tests are cited, not re-run.
6. **Not the hash layer, the Fiat–Shamir lift, a run, the GPU path, timing
   or P3.** The P3 note of §3.3 is a design observation, not an analysis.
7. **Not checked by anyone.** One delegated agent drafted the argument,
   wrote the check and ran it, in one sitting. The draft has not been
   attacked; §6 says where to start.

## 5. Evidence

`results/zk60_nonlinear_channel_shaped/` — re-runnable with no arguments,
about 30 s, CPU only, no Rust:

```
python3 results/zk60_nonlinear_channel_shaped/nl_check.py
```

| file | what it holds |
|---|---|
| `nl_field.py` | Goldilocks `Fp` / `Fp2` (`u² = 7`), exact rank and solve over `Fp2`, rank over `Fp`; a self-test (non-residue, 200 inverses, 30 random solve / rank systems) |
| `nl_check.py` | stages S0–S5: S0 field self-test; S1 per slot and shape the degree walk, per-variable bound, public-factor entry points, the premise per extension round (exact, three seeds) with its mechanism and a syntactic liveness walk; S2 budgets and the structure parsed from `layout.rs` / `argument.rs`; S3 Fact 2.1 at 42 `(N, d)` pairs × 5 regimes and the closed-form round map against brute force; S4 the miniature runs and the fibre test, and the terminal-pair model; S5 the controls |
| `nl_check.json` | every per-slot, per-shape row; the input digests; the summary |
| `nl_check.log` | the run's own log, one line per verdict |

Inputs, read-only, SHA-256 pinned in `nl_check.json` (first 8 hex digits):
`slot_ir_m125.json` `2e8cdb87`, `slot_ir_rung_g.json` `5cb8323a`,
`slot_ir_rung_k4.json` `e4050133`, `slot_ir_toy.json` `12e7ed01`, and the
five development exports; lane sources `argument.rs` `f7fa2ad4`,
`layout.rs` `14758039`, `shape.rs` `dbf4e2bc`, `zk.rs` `d4280962`,
`zkp-core/src/sumcheck.rs` `56dbb8c7`, `slot_ir.rs` `734cd0e0` — all at the
lane worktree `/home/victor/wt-zk60-block125m`, head `d597a1d`.

Headline figures, with their labels:

| figure | value | label |
|---|---|---|
| premise holds, shaped exports | 184 / 184 slot-shape pairs, all with a public factor in every monomial | MEASURED (on the IR) |
| premise holds, toy | 23 / 23; 21 by a public factor, 08 and 09 by different rounds | MEASURED (on the IR) |
| product degree `≤` declared | 207 / 207 | COUNTED |
| Fact 2.1 exactly tight | 210 / 210 (42 pairs × 5 regimes) | MEASURED |
| closed-form round map = brute force | 310 values | MEASURED |
| miniature runs, all five checks | 207 / 207 | MODEL |
| per-slot terminal maps onto `Fp2^m` (125M, rung-G, rung-K4) | 69 / 69 | MODEL |
| control verdicts as expected | 12 / 12 | MEASURED / MODEL |
| `Σ L_s / Σ dim C_s` | toy 583 / 560; rung-G 859 / 836; rung-K4 871 / 848; 125M 1,239 / 1,216 | COUNTED |
| worst `L_s` (budget 256) | toy 50; rung-G 72; rung-K4 77; 125M 117 | COUNTED |
| non-linear-channel words per block | toy 917; rung-K4 1,269; 125M 1,751 `Fp2` | COUNTED |

## 6. What an independent checker should attack first

In the order I trust them least:

1. **GN-1, semantic completeness.** Look for an admissible witness at a
   shaped layout on which a Standalone or Host relation fails — the padded
   head slots, the causal mask on padded tokens, an exempt plane (`A_E`,
   the helper planes) non-zero on the pad, a limb that overflows only at
   width 768 or hidden width 2,048. That is where S19-F1 lived, and no algebra in this memo can see
   it.
2. **The extension-round assignment.** The check reads it from `define` by
   a regular expression (every `b.a_at` / `b.a_slice` last argument) and
   assumes the IR's private tables come in push order (the IR's own contract,
   `slot_ir.rs:55-57`). A mis-assignment would make the 08 / 09 rows
   meaningless; C1/C2 show the pair survives either way at a shaped layout,
   but not at the toy.
3. **The coefficient model.** Challenge coefficients get independent random
   values (§2.1). Argue whether some real identity could hold only for the
   real, related values (it would show up here as a false failure — none
   occurred) or whether the per-label choice for `mu` / `nu` / `ζ` hides one.
4. **R-b.** Search the 184 shaped pairs for a monomial whose only public
   factor is an affine expression with a constant. The mechanism probe says
   there is none; attack the probe's notion of "public" (the four IR kinds
   `eq`, `group_eq`, `pub`, `supp`) against the table provenance.
5. **The miniature's faithfulness** (GN-3): three main variables, random
   stand-ins for `eq` and public tables, one challenge vector per slot.
   Re-run with real `eq` tables at the real point lengths, or with main-round
   challenges 0 and 1.
6. **§3.2's "nothing in (NL) uses a degree bound".** Check that no step of
   Lemma 2.2, Lemma 3.1 or Fact 3.2 silently assumes `d ≤ 4` — for instance
   in the `M` weight layout or the hash-length guard.
7. **The fibre step's hand-off to (H1).** The construction shifts the
   reserved-pair values to align the terminals. Check that (H1) as the shaped
   lemma states it really absorbs that shift at the shaped layouts, and that
   nothing in (NL) needs more from (H1) than the toy did.
