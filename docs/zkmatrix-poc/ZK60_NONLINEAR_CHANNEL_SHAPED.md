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

(pending)

## 4. What this memo does NOT establish

(pending)

## 5. Evidence

(pending)

## 6. What an independent checker should attack first

(pending)
