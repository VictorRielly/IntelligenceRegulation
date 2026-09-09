# FA6 — the CFS masking channel: exact model, verdicts, approved specification

| | |
|---|---|
| Reviewer | Claude Fable 5.1, independent privacy reviewer (2026-09-08 session) |
| Task | `ZK60_FABLE_QUEUE.md` round 11, **FA6 — CFS masking channel**, priority 0: "Review FA3 B1 against the actual CFS round messages, claimed sums, terminals and product-form mask opening together. Derive the conditional distribution or a concrete counterexample, enumerate every shared coefficient/function, and state precisely which mask specification is approved. Include both new seam slots and negative controls. A rank test of PCS vectors alone cannot close this task." |
| Source pin | `cfa46f6` (worktree `wt-zk60-fa`, branch `zk60-fable-review`) |
| `zkp-core/src/sumcheck.rs` SHA-256 | `56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19` |
| `hashline/src/zk.rs` SHA-256 | `c44425347e3d5648e3c8664e540ec724bb9c8740c538b0559f2c28bc99b7715e` |
| Tool | `scripts/zk60_fable_cfs_channel.py` (exact modular arithmetic imported by path from FA2's `zk60_fable_joint_rank.py`; nothing duplicated) |
| Tests | `tests/test_zk60_fable_cfs_channel.py` (21 tests), `hashline/tests/zk60_fable_cfs_channel.rs` (2 tests, CPU, tiny shape) |
| Record | `results/zk60_fable_fa6_cfs_channel.json` (+ `.log`), `results/zk60_fable_fa6_rust_crosscheck.log` |
| Limits (queue) | No private-block, deployment or throughput acceptance follows from this review. Shared production edits remain with the source owner. Nothing in `hashline/src/`, `zkp-core/` or FA7's files was changed. |

## 0. The verdict in plain words

FA3 §11 named the CFS channel blocker B1 because "the round messages are
products of data MLEs, so the linear row model does not apply". That is true
of the *data* part of a round message and irrelevant to the *mask* part: the
mask's contribution to every value the verifier sees is an exact **linear**
function of the mask coefficients, and the data part only has to lie in the
same consistency subspace as the mask part does. So the right question is a
rank question after all — but over the mask coefficients and the sumcheck
messages, not over PCS vectors (which is what the queue's last sentence
means). I built that model from the source and ran it on every slot.

**Result.** At `cfa46f6`, for every CFS-masked sumcheck slot — v2's six, v3's
six plus the function-2 predicate, the P3 matmul slots with their second
extension round, and FA3's two seam slots — the map from the mask
coefficients to the verifier's view of the mask channel (the g-parts of all
round messages including the extension round(s), the sent masked claimed
sums and Γ's exactly as the code batches them, and the derived `g(ρ)`) is
**surjective onto the consistency subspace S**, and this holds for *every*
challenge sequence, not only generic ones. Therefore the masked view is
uniform on S and **independent of the private data**, conditioned only on
the public constants and the masked terminal values (which are the PCS
side's observations, FA2/FA7's territory). The M opening reveals exactly one
value V that the verifier already computes from the transcript — this part
is information-theoretic for `q'`, `prox` and the opened columns, and rests on
the salted-hash assumption only for the unopened columns. **No
counterexample exists in the construction as coded.** The negative controls
show what each invariant buys (a shortened mask, a reused mask, a second M
opening, an extension round the mask does not cover, more opened columns
than pads — each leaks, with the leaked functional exhibited).

B1 is therefore closed as a *construction* statement, under the five
invariants of §7.2, with the mask specification of §7.3 approved. What it
does not close is B2 (the simulator that programs the Fiat-Shamir challenges
and equivocates the M root), B3 and B4 — those are FA8's, and §7.4 says
precisely what this review hands them.

Two findings worth a sentence each, neither a leak: the `a'` coefficient
("the extra freedom that makes the total and the terminal jointly uniform",
`sumcheck.rs` 168–171) is **redundant** — the Libra form `a_0 + Σ_j u_j(x_j)`
is already surjective with kernel 0, and `a'` is exactly the one kernel
direction of the map (harmless, one wasted coefficient per slot); and
`zk.rs::extension` masks the extension round through a `zip`, which would
leave the top value(s) of a higher-degree extension message in the clear —
today every slot's extension degree equals its mask degree, so nothing
leaks, but the equality is not asserted (§7.2, I1).

## 1. Inventory of the CFS-masked slots (a)

### 1.1 What every slot has in common (`sumcheck.rs` 185–314, `zk.rs` 960–985)

A slot is one masked sumcheck with `n_vars = N` rounds in the transcript:
the `N − ext` main rounds run through `masked_prove` (the `CfsMasker`
installed on the transcript adds `c·g_j(X)` to every `sc-round` absorb and
records each challenge), then `ext` extension round(s) run through
`extension` (`s_k(X) = poly((1−X)·fin + X·ext)` plus `c·g_k(X)` for
`k = N − ext .. N − 1`). The mask is
`g(x) = a_0 + a'·Π_j x_j + Σ_{j<N} Σ_{e=1..d} a_{j,e} x_j^e` with
`N·d + 2` coefficients in the layout `[a_0, a', a_{0,1..d}, …, a_{N−1,1..d}]`
(`CfsMask::len`), degree `d` = the round degree. Round j's g-part, from
`CfsMask::round`:

    g_j(X) = 2^(N−1−j) · ( a_0 + Σ_{i<j} u_i(r_i) + Σ_{i>j} u_i(1)/2 + u_j(X) ) + a'·(Π_{i<j} r_i)·X,     u_i(X) = Σ_e a_{i,e} X^e.

The terminal relation is `fin = h_{N−1}(r_{N−1}) = want(terminals, public) + c·g(ρ)`,
`ρ = (r_0, …, r_{N−1})`; the verifier **derives** `g(ρ) = (fin − want)/c`
(`div`, which refuses `c = 0`) and never receives it. `mask_open` then proves,
in one product-form test under `θ`, every derived `g_s(ρ_s)`
(`CfsMask::eval_weights`) and every sent Γ (`CfsMask::sum_weights` scaled by
the c's and ν's) — `mask_functionals` (`zk.rs` 1071–1082),
`push_pred_functionals` (1098–1103).

### 1.2 The slots

| Slot | Claimed sum as sent / computed (f-part total; g-part) | Extension round(s): what they mask | Terminal relation (verifier) | Functionals of this slot's mask the verifier learns | Transcript order (v2 = v3 unless noted) |
|---|---|---|---|---|---|
| **SC_GU** (matmul g/u) | `gu_claim = s_gu + c_gu·G_gu` sent; `s_gu` is private (the folded X × W evaluation at `p1`) | P1: round k masks the activation blocks (`a_mgu[c]`), weight ext 0. P3: round k+1 masks the weight blocks (`w_mgu`), activation ext 0 (`mask_specs_v3` comment: a bilinear round needs two extensions) | `fin = Σ_c m_c·(1−e)·Σ_b λ_f[b](wg_cb + λ_gu·wu_cb) + c_gu·g(ρ)` (P1; P3 with the `(1−e2)` factors) | `g_gu(ρ_gu)` derived; `G_gu` inside `gu_claim` (with `s_gu`) and inside `Γ20` (mixed) | M root → β, γ, α → H root → `r_i, r_j, λ_gu, [λ_f]` → **c_gu** → `gu_claim` absorbed → N rounds (challenges after each) → `gu-term` absorbed |
| **SC_D** (matmul d) | `d_claim = s_d + c_d·G_d` sent; `s_d` private | P1: round k masks the h16/h8 blocks (`a_mdd`/`a_md`), weight ext 0. P3: round k+1 masks `w_mdd` | `fin = Σ_b m_b·(1−e)·Σ_c λ_d[c]·wd_bc + c_d·g(ρ)` | `g_d(ρ_d)` derived; `G_d` inside `d_claim` and `Γ17` | `r_ip, r_jp, λ_d` → **c_d** → `d_claim` → rounds → `d-term` |
| **SC_ZC20** (zero-check F) | computed by the verifier: `ν0·gu_claim + Γ20`; sent: `Γ20 = c20·G20 − ν0·c_gu·G_gu`. f-part total `= ν0·s_gu` (the `eq(p1)·fold1` term; the zero-check terms sum to 0; `nu[2] = 0` kills the `eq(p5)·h` term) | round k masks the 7·nb_f A planes (`a_mf`/`a_m20`) and 3·nb_f H planes (`h_mf`/`h_m20`); the three eq tables ext 0 | `fin = (1−e)·[eq(τ,ρ)·zc(m) + eq(p1,ρ)·fold1(m) + eq(p5,ρ)·ν2·h16(m)] + c20·g(ρ)` | `g20(ρ20)` derived; `c20·G20` only through `Γ20` (mixed with `G_gu`) | `τ, μ, ν0` → **c20** → `Γ20` absorbed → rounds → `zc20-term` |
| **SC_ZC17** (zero-check D) | `ν_z·d_claim + Γ17`, `Γ17 = c17·G17 − ν_z·c_d·G_d` sent; f-part total `= ν_z·s_d` | round k masks 3·nb_d A planes (`a_md`/`a_m17`) and nb_d H planes (`h_md`/`h_m17`) | `fin = (1−e)·[eq(τ2,ρ)·zc + eq(p4,ρ)·fz] + c17·g(ρ)` | `g17(ρ17)` derived; `c17·G17` through `Γ17` | `τ2, μ2, ν_z` → **c17** → `Γ17` → rounds → `zc17-term` |
| **SC_TAB** (table zero-check) | `Γ_tab = c_tab·G_tab` sent; f-part total public 0 | round k masks the six multiplicity slots (`a_mask` blocks, `ext_coef`-scaled in v3) and the table helpers (`h_mre/h_mim`) | `fin = (1−e)·eq(τ3,ρ)·Σ_i μ3_i·(h_i·(α − (1−e)·tv_i(ρ)) − m_i) + c_tab·g(ρ)` | `g_tab(ρ_tab)` derived; `c_tab·G_tab` = `Γ_tab` | `τ3, μ3` → **c_tab** → `Γ_tab` → rounds → `tab-term` (after the second zero-check, before zsum, in v2 and v3 alike) |
| **SC_ZSUM** (LogUp zero-sum row) | `Γ_zs = c_zs·G_zs` sent; f-part total 0 (u is zero-sum) | round k masks u by `u'` (`h_up`); the all-ones table ext 0 | `fin = (1−e)·zs_term + c_zs·g(ρ)` | `g_zs(ρ_zs)` derived; `Γ_zs` | **c_zs** → `Γ_zs` → rounds → `zs-term` (after tab; the last slot in v2, followed by `[pred]` in v3) |
| **SC_PRED** (v3, function 2) | `τ + Γ_pred`, `Γ_pred = c_pred·G_pred` sent; f-part total = the PUBLIC threshold τ | round k masks the z block (`a_pmz`) and the bit row (`a_pmb`, × `ext_coef`); eq/weight tables ext 0 | `fin = (1−e)·[eq(pt,ρ)·zt − w(ρ)·bt + ν_p·eq(τ_p,ρ)·(bt² − bt)] + c_pred·g(ρ)` | `g_pred(ρ_p)` derived; `Γ_pred` | `τ_p, ν_p` → **c_pred** → `Γ_pred` → rounds → `pred-term` (after zsum) |
| **SC_SEAM_X / SC_SEAM_Z** (FA3 block profile, §12) | `Γ_s = c_s·G_s` sent; f-part total public 0 (the seam identity `Σ_x eq(τ,x)·Σ_c λ_c (X_c − xm8_c)(x) = 0`) | round k masks the FFN-side pair `a_sx[c]` / `a_sz[c]` and the attention-side pair; eq ext 0 | `fin = (1−e)·eq(τ_s,ρ)·Σ_c λ_c·(m^ffn_c − m^attn_c) + c_s·g(ρ)` | `g_s(ρ_s)` derived; `Γ_s` | after `[pred]`: `τ_sx, c_sx` → `Γ_sx` → rounds → both sides' terminals → `e_sx`; Z likewise (FA3 §12.2 step 5) |
| **M opening** (all slots) | — | — | `512·(q'_0 + q'_512) = V = Σ_i θ^i F_i` | nothing beyond V (§3) | after the last sumcheck: **θ** → `q'` absorbed → `rs` (2·n_masks + 2) → `prox` absorbed → 256 indices → columns |

In both v2 and v3 the M root is absorbed **before** β, γ, α (`zk.rs` 1196,
2428; verifiers 1648, 3403) and every `c_s`, `ν`, `θ` is drawn after it.

### 1.3 `(n_vars, degree)` at the review shapes (`mask_specs` 721, `mask_specs_v3` 2095; reproduced by the tool)

| Slot | v2 T32, log_cols 14 | v3 T2/d16/f16 lc 5 | v3 T32/d16/f16 lc 8 | v3 125M T32/d768/f2048 lc 14 | v3 8B T32/d4096/f14336 lc 14 (FA3 block profile) | v3 8B lc 16 |
|---|---|---|---|---|---|---|
| SC_GU | (9, 2) | (5, 2); P3 (6, 2) | (5, 2); P3 (6, 2) | (9, 2); P3 (10, 2) | (13, 2); P3 (14, 2) | (13, 2) |
| SC_D | (12, 2) | (5, 2); P3 (6, 2) | (5, 2); P3 (6, 2) | (12, 2); P3 (13, 2) | (12, 2); P3 (13, 2) | (12, 2) |
| SC_ZC20 | (17, 4) | (6, 4) | (10, 4) | (17, 4) | (17, 4) | (17, 4) |
| SC_ZC17 | (14, 4) | (6, 4) | (10, 4) | (14, 4) | (18, 4) — 74 coefficients, the largest row | (18, 4) |
| SC_ZSUM | (14, 2) | (6, 2) | (9, 2) | (14, 2) | (15, 2) | (17, 2) |
| SC_TAB | (14, 3) | (17, 3) | (17, 3) | (17, 3) | (17, 3) | (17, 3) |
| SC_PRED | — | (6, 3) | (10, 3) | (14, 3) | (18, 3) | (18, 3) |
| SC_SEAM_X, _Z | — | (6, 2) | (10, 2) | (14, 2) | (18, 2) | (18, 2) |

v2: `log_tf = log_t + 11`, `log_tb = log_t + 8`, `a_log_cols = min(log_cols, log_tb)`
(`layer.rs` 92, `zk.rs` 1182). v3: `layout_v3` of FA2's tool for `log_t, log_db,
log_fb, log_n`, and `log_s = max(log_n, 16)` (`ZkLayoutV3::new`, 1983). Every
row satisfies `len + 256 ≤ 512` (the `mask_commit` assert; checked by test).

## 2. The linear model of the message channel and its derivation (b)

### 2.1 View, unknowns, consistency subspace

Fix one slot (or a batched pair, §2.3). Unknowns: the `L = N·d + 2` mask
coefficients `a ∈ F_{p²}^L`. The verifier's view of the sumcheck is the
vector of field elements

    v = ( claim ; h_0(0..d) ; h_1(0..d) ; … ; h_{N−1}(0..d) ),      h_j = f_j + c·g_j,

where `claim` is the sent masked claimed sum (or the sent Γ, or — for the
batched zero-checks — the pair `(gu_claim, Γ20)` the verifier combines). It
splits as `v = f + L·a`: the **f-part** (`s`, the honest round polynomials of
the data, 0 for the Γ's) and the **g-part** `L·a`, with `L` the
`(1 + N(d+1)) × L` matrix whose rows are `c·sum_weights` (the claim) and
`c·W_j[x]` (the round weights of §1.1). The verifier checks

    h_0(0) + h_0(1) = claim,        h_j(0) + h_j(1) = interp(h_{j−1})(r_{j−1})   (j ≥ 1),

`N` homogeneous linear relations among the view's coordinates. They hold for
the f-part alone (an honest sumcheck) and for the g-part alone (`g` is itself
a polynomial summed over the cube: `zk_tests::cfs_mask_rounds_match_brute_force`,
re-checked by my brute-force test). Call `S` the subspace they cut out:

    dim S = (1 + N(d+1)) − N = N·d + 1.

The derived terminal `g(ρ) = interp(h_{N−1})(r_{N−1})/c − (f-part)` is a
linear function of the view, so it adds nothing to the model; likewise the
extension message's f-value at `X = 1`, `poly(exts) = 0` (the Rust test
checks this identity), is hidden inside `h_k(1)`.

### 2.2 The criterion and the derivation

Since `f ∈ S`, if `image(L) = S` then `v = f + L·a` with `a` uniform is
**uniform on S, whatever f is**. Conversely, if `image(L) = S' ⊊ S`, any
functional `φ` with `φ(S') = 0` but `φ(S) ≠ 0` satisfies `φ(v) = φ(f)` for
every mask — a data-dependent value in the clear, and two data sets
`f_1, f_2 ∈ S` with `φ(f_1) ≠ φ(f_2)` are a concrete counterexample. The tool
computes `rank L`, `dim S`, checks `image(L) ⊆ S` exactly, and for a
deficiency exhibits `φ` and the pair (`Channel.analyze / witness`).

Why the map is surjective, by hand (the tool confirms the numbers): use the
free coordinates of S, `(G, Δ_j(x) = h_j(x) − h_j(0) for x = 1..d)`; every
other coordinate is determined by the relations. In those coordinates

    G      = 2^N·a_0 + a' + 2^(N−1)·Σ_j u_j(1),
    Δ_j(x) = 2^(N−1−j)·u_j(x) + a'·(Π_{i<j} r_i)·x.

For each `j`, `a_{j,1..d} ↦ (u_j(1), …, u_j(d))` is a Vandermonde bijection
(nodes `1..d`, `d ≤ 4 < p`), so `a_{j,·}` covers `Δ_j` whatever `a'` and the
challenges are; then `a_0` covers `G` (weight `2^N ≠ 0`). The map is
**triangular** and surjective for *every* challenge vector (`pc_full_mask_all_zero_challenges`,
`pc_full_mask_all_one_challenges` in the record), which is the round-by-round
form a Fiat-Shamir simulator needs: given everything absorbed before round j,
`h_j` is uniform on its `d`-dimensional fibre. The kernel is one-dimensional:
`a' = t, a_{j,1} = −t·(Π_{i<j} r_i)/2^(N−1−j), a_0 = −t·(1 − Σ_j 2^j Π_{i<j} r_i)/2^N`.

### 2.3 The batched pairs as coded

The code does not run ZC20 as an independent sumcheck: its claimed sum is
`ν0·gu_claim + Γ20`, and `Γ20 = c20·G20 − ν0·c_gu·G_gu` is what is sent.
Modelled jointly (unknowns `(a_gu, a_20)`; view `(gu_claim, h^gu, Γ20, h^20)`;
round-0 relation of ZC20 against `ν0·gu_claim + Γ20`):

    dim S_joint = (1 + N_gu(d_gu+1)) + (1 + N_20(d_20+1)) − N_gu − N_20 = L_gu + L_20 − 2,

`rank L_joint = L_gu + L_20 − 2`, kernel 2 (one `a'` per mask). The mixing is
harmless because `Γ20`'s g-part is a relabeling of `c20·G20` by a quantity
(`c_gu·G_gu`) already in the view's span, and the f-part `(s_gu, f^gu, 0, f^20)`
satisfies the same homogeneous relations (`f^20_0(0)+f^20_0(1) = ν0·s_gu`).
Identically for (SC_D, SC_ZC17) with `ν_z`. The function-2 slot's public `τ`
makes its round-0 relation inhomogeneous by a public constant; the coset
`f + S` is then determined by `τ` alone — same conclusion.

### 2.4 The ranks (record: `slot_table`, 21 shape/mode entries, 240 systems — 99 batched-pair/single systems and 141 standalone slots)

Every system at every shape: `rank_map = dim S`, `image_inside_subspace =
true`, `leaked_dim_fp2 = 0`; every standalone slot `kernel = 1`; every
batched pair `kernel = 2`; every functional `mask_functionals` /
`push_pred_functionals` sends to `mask_open` (the derived `g_s(ρ_s)`, the
Γ's) lies in the view's row space, and so does their θ-combination
(`m_functionals_in_view_span`, `theta_combination_in_view_span`). The
largest instance, the block profile's SC_ZC17 (18, 4): 74 unknowns, 91 view
coordinates, 18 relations, `dim S = rank = 73`.

**What is conditioned on.** The statement "the view is uniform on S,
independent of f" conditions on: the public constants (`β, γ, α, τ's, μ's,
ν's, λ's`, the c's, the challenges `ρ`, the public W evaluations under P1,
the table values `tv`, the threshold `τ`) and the **masked terminal values**
`m_t` (`*_term` fields), because `want(m_t)` is what closes the terminal
relation. It does *not* condition on any unmasked data value. The
distribution of the `m_t` themselves is the PCS side (FA2 rows `A.value.*`,
`H.value.*`, `W3.value.*`; FA3's pair repair; FA7's joint rank) — and since
the CFS coefficients are independent of the PCS mask rows, the joint
distribution of (CFS view, `m_t`) is the product of the two.

**Conclusion of (b).** Surjective in every slot, so: perfect simulation of the
message channel given the public constants and the masked terminals. No
leaked direction, hence no counterexample to exhibit — the counterexamples
of §5 are for the negative controls.

## 3. The M-opening channel (c) — `mask_commit` (`zk.rs` 430), `mask_open` (512), `mask_verify` (552)

Rows on `G_512` per mask `s`: `a_{s,re}` and `a_{s,im}` = `[L_s coefficients ‖ 256 pads ‖ zeros]`
(the Fp parts of the F_{p²} coefficients, each row with its **own** 256 pads
from the layer RNG); `b_re, b_im` (1024 coefficients each, `b[512] = −b[0]`);
`u_re, u_im` (1024 each). Everything is RS-encoded on the coset `7·G_4096`,
salted per column (`bytes32` salt), Merkle-committed. The opening under θ
sends `q'` (1024 F_{p²} coefficients), `prox` (1024), and 256 sampled columns.

| Value | What hides it | Information-theoretic? | Result (tool, toy size `m = 8`, 3 coefficients, 3 pads, 3 columns) |
|---|---|---|---|
| `q' = Σ_s p_{a_s}·p_{W_s} + p_b` | `b`, uniform on the hyperplane `b_0 + b_512 = 0`; `q'` is uniform on `{Σ_{G_512} q' = V}` i.e. `512(q'_0 + q'_512) = V` | yes | `pc_qprime_one_opening`: disclosed = 1 F_{p²} functional = V; `nc_qprime_without_blinding`: all coefficients |
| the 256 opened values of each a-row | the row's 256 pads: at ≤ 256 distinct coset points `x_j`, `pad ↦ (Σ_y pad(y)·Lagr_y(x_j))_j` is a Cauchy-type bijection, `Lagr_y(x) = (x^512 − 1)·y/(512(x − y))`, because `x^512 ≠ 1` on the coset (7 generates F_p^*: `7^((p−1)/ℓ) ≠ 1` for ℓ ∈ {2,3,5,17,257,65537}, checked) and the `x_j − y` are distinct | yes | `pc_columns_q_distinct_under_q_pads`: 0; duplicate indices only reduce the distinct count (`pc_columns_duplicate_indices`: 0); `nc_columns_exceed_pads` (q+1 distinct): 1; `nc_columns_without_pads`: all |
| `prox = Σ_row r_row·p_row + u` | `u`, a full one-time pad of 1024 F_{p²} coefficients | yes | joint model below |
| `b(x_j)`, `u(x_j)` in the opened columns | determined by `q'(x_j) − Σ_s a_s(x_j)W_s(x_j)` and by `prox(x_j) − Σ r_row·row(x_j)`: consistency checks, no new observation | yes | joint model below |
| the 3840 unopened columns | the per-column salts inside the leaves and the Merkle paths | **no** — hiding of a salted blake3 leaf (random-oracle model) | out of scope of an exact model; FA8 states the assumption |

The **joint** exact model (`m_joint_model`: `q'`, `prox`, and every opened
column with `b`, the pads and `u` shared across the three channels, 74 Fp
unknowns, 100 Fp observations) discloses exactly **2 Fp = one F_{p²} value**,
i.e. V and nothing else — nothing about `b`, `u` or the pads beyond V
(`pc_joint_qprime_prox_columns_one_opening`). V itself is
`Σ_i θ^i F_i` over values the verifier already holds (the derived `g_s(ρ_s)`
and the sent Γ's), so the M channel adds **no information** to the message
channel. The zero tail of the a-rows (positions `L_s + 256 .. 511`) is public
structure and does not weaken the pad bijection (the pads' Lagrange columns
are still a full-rank Cauchy block). The one condition on which this rests
that the code does **not** enforce is that `M` is opened **once**: a second
`mask_open` of the same commitment under a fresh θ discloses every
coefficient of every a-row (`nc_qprime_two_openings_same_M`,
`nc_joint_two_openings_same_M`: `q'_1 − q'_2 = Σ_s p_{a_s}(p_{W_s,1} − p_{W_s,2})`
is a polynomial identity in the a-rows with the b cancelled; with the a-rows
known, `f_j = h_j − c·g_j` is in the clear). At this pin each prover calls
`mask_open` exactly once per layer (`zk.rs` 1597, 3136), and FA3's block
order (§12.2 step 6) opens each component's M once.

## 4. Shared coefficients and functions (d)

| Shared object | Where | Effect on the channel |
|---|---|---|
| `G_gu` inside both `gu_claim` and `Γ20` (`= c20·G20 − ν0·c_gu·G_gu`); `G_d` inside `d_claim` and `Γ17` | `zk.rs` 1329/1409, 1371/1478 (v2); 2611/2773, 2700/2870 (v3) | none: §2.3, joint rank = dim S_joint; the verifier can form `c20·G20` only as `h^20_0(0)+h^20_0(1) − ν0·s_gu`, which needs the private `s_gu` |
| `a'` shared by all rounds of one slot **including its extension round(s)** (`a'·Π_{i<j} r_i·X`, and `Π ρ` in `eval_weights`) | `CfsMask::round`, `eval_weights` | one kernel direction; redundant. Dropping `a'` keeps surjectivity with kernel 0 (`pc_no_aprime_libra_form`); dropping `a_0` instead keeps it only off the challenge hyperplane `Σ_{j≥1} 2^j Π_{i<j} r_i = 0` (`pc_no_constant_a0_generic_challenges` vs `nc_no_constant_a0_degenerate_challenge`, leaked 1 at `r_0 = 0`); dropping both leaks 1 (`nc_no_a0_no_aprime`). `a_0` is the unconditional cover of the claimed sum's direction |
| coefficients across slots | `mask_commit`: `specs.iter().map(…CfsMask::random(rng, n, d))` — one fresh vector per slot | none shared. Sharing one vector between two slots leaks `N·d` functionals of the two data's messages (`nc_mask_reuse_fresh_challenges`, 12 of 13 at (4, 3)) |
| `b`, `u` across all functionals of one opening; `θ` combining all slots into V; `rs` over the `2·n_masks + 2` rows (a-rows and `b_re, b_im`; `u` unscaled) | `mask_open` | none, given the single opening (§3) |
| pads across the re/im rows of one mask and across masks | `rng.fp_vec(MASK_Q)` per row | independent per row; the joint bijection is block-diagonal |
| derived versus sent | derived: 6 (+1 pred, +2 seams) `g_s(ρ_s)`; sent: `gu_claim, d_claim, Γ20, Γ17, Γ_tab, Γ_zs` (+`Γ_pred`, +`Γ_sx, Γ_sz`); computed: V | every derived value is a function of sent values; nothing is sent twice |
| the c's | `c_s` drawn after the M root, before the slot's claimed sum / Γ; `c = 0` refused by the verifier's `div` | the prover emits before it can refuse: `c = 0` (probability 2^−128 per slot) would put `f` in the clear (`nc_mask_challenge_zero`, leaked = dim S). Invariant I3 |

**Every terminal value the CFS terminal relations reveal, against FA2/FA3's inventory:**

| Terminal field | Slot | Inventory row | Counted? |
|---|---|---|---|
| `gu_term[c]` (c < nb_d) | GU | FA2 §12 `A.vec.p2` / `A.value.*` (line 573/578), FA3 role `a_mgu[c]` pair | yes |
| `gu_term[nb_d ..]` (W evaluations) | GU | P1: public weights, plain PCS (round-11 note "P1 W remains explicitly public/plain PCS"); P3: `W3.vec.p3` / `W3.value.*` (588/591), FA3 `w_mgu` pairs | yes |
| `d_term[b]`, `d_term[nb_f ..]` | D | `A.vec.p5` / `A.value` (574/578); W as above (`W3.vec.p6`, 589) | yes |
| `zc20_term[10b + i]`, i < 7 / 7..10 | ZC20 | `A.vec.rho_f` (571) / `H.vec.rho_f`, `H.value` (581/587) | yes |
| `zc17_term[..3nb_d]` / `[3nb_d ..]` | ZC17 | `A.vec.rho_d` (572) / `H.vec.rho_d` (582) | yes |
| `tab_term[2i]` / `[2i+1]` | TAB | `A.vec.tab` (575) / `H.vec.tab` (584) | yes |
| `zs_term` | ZSUM | `H.value.*` (587), FA3 `h_u` / `h_up` | yes |
| `pred.term[0..2]` | PRED | `A.vec.pred` (576), FA3 `a_pmz, a_pmb` | yes (no function-2 proof captured — FA2 U9) |
| `seam_x.term_ffn[c]`, `seam_z.term_ffn[c]` | seams | FA3 schedule roles `a_sx[c]`, `a_sz[c]` | yes (designed, not built) |
| the attention-side seam terminals (`SeamXm8[c]`, `SeamZ16c[c]`) | seams | **none** — FA3 §14: "the attention side … not reviewed here; every attention claim will need its own row" | **not counted — flagged for FA7/FA8** |
| `gu_claim`, `d_claim`, the Γ's, the masked rounds, `q'`, `prox`, the M columns | all | FA2 `M.cfs` (593) "outside linear model" | now modelled here (§2, §3) |

## 5. Failure, retry and repeats (e)

`layer_rng(cfg, l) = cfg.rng("layer-{l}")` (v2, `zk.rs` 1114) and
`cfg.rng("layer-v3-{l}")` (v3, 2252) with `ZkConfig::rng` (334–340):
`seed: None → ZkRng::from_os(domain)` (32 fresh bytes from `/dev/urandom`
keyed into blake3, fails closed on any error), `seed: Some(s) →
ZkRng::new(s, domain)` (a public deterministic stream — the doc comment says
so: "a public deterministic test fixture, not a privacy mode"). One instance
feeds, in order, the A mask rows, A's pads and salts, **M** (per slot the
coefficients, then 256 pads per re/im row, then `b`, `u`, salts), H's mask
rows, pads and salts.

- **A retried attempt** (`seed = None`): every call of `prove_layer_zk{,_v3}`
  draws a new OS-keyed stream, so a retry after a panic (the device path's
  `expect`s abort the process; there is no in-process retry of a masked
  sumcheck) never reuses a mask. The device attempts (`clone_state` sites
  2823, 2906, 2990) run the same mask on a cloned transcript; on a decline
  "nothing is absorbed" and the host body re-runs the same deterministic
  sumcheck on the same state — the abandoned attempt's messages would have
  been identical and never leave the process. No reuse.
- **A re-proof of different data under the same explicit seed** at the same
  layer index (or the same data with any change of statement): every mask —
  CFS coefficients, pads, `b`, `u`, salts, and the PCS mask rows — repeats.
  The CFS channel then leaks `N·d` F_{p²} functionals of the two data's
  round messages per slot (`nc_mask_reuse_fresh_challenges`), the whole
  difference `f_1 − f_2` if the transcript prefix coincides
  (`nc_mask_reuse_same_challenges`), and the second M opening discloses the
  a-rows outright (§3). Two different models or chains proved at the same
  layer index under one explicit seed collide the same way — the domain
  carries only the layer index.
- **Per-layer domains**: `layer-{l}` and `layer-v3-{l}` separate layers and
  the v2/v3 paths (blake3-keyed domain separation); nothing separates
  attempts, models or profiles.
- **Bias**: `ZkRng::fp` reduces a 128-bit draw (bias `2^−64` per Fp element,
  stated in the source); the uniformity claims of §2–3 hold up to it.

**The exact freshness requirement for the repaired profile** (consistent with
FA3's `rng` rule, made precise for the CFS channel): (1) one `ZkRng` per
component per proof attempt, from OS entropy, with a domain that names the
profile, the layer **and an attempt nonce** (`ffn-mr1/layer-{l}/attempt-{nonce}`),
consumed once and dropped with the attempt; (2) an explicit seed is refused
outside `cfg(test)`; (3) no CFS coefficient vector serves two sumchecks
(two slots, two attempts, two proofs); (4) each `MaskCommit` is opened exactly
once; (5) the seeded CPU/GPU parity fixtures never carry private data. The
negative controls above are the demonstration of what each clause prevents.

## 6. The two seam slots (f)

FA3 §12 specifies `SC_SEAM_X (log_t + log_db + 1, 2)` and `SC_SEAM_Z (log_t +
log_db + 1, 2)`, the X seam as "one S2-form sumcheck over `eq(τ, x)·Σ_c λ_c
(X_c(x) − xm8_c(x))` with the masked extension; terminals on BOTH actual A
roots", Z likewise, with the transcript order `τ_sx, c_sx → γ_sx → masked
rounds → masked terminals (FFN side, attention side) → e_sx`.

Applying the criterion: the polynomial is `eq × (linear in private tables)`,
degree 2 in each variable; the extension round has degree 2 (`eq`'s
extension is 0, the tables' are their pair masks) with `poly(exts) = 0`; the
transcript has `log_t + log_db` main rounds plus one extension = `n_vars`;
the claimed sum is the public 0 with `Γ_s = c_s·G_s` sent after `c_s` (drawn
after both M roots, FA3 step 2/5); the terminal relation reveals the derived
`g_s(ρ_s)` only. Rank at every review shape (6/10/14/18 variables): `= dim S
= 2·n_vars + 1`, kernel 1 (record `SC_SEAM_X`, `SC_SEAM_Z`).

**Verdict: the slot specification is approved as-is** — `(log_t + log_db + 1,
2)` for both seams, zero-claimed form, Γ sent. Three things FA3's text leaves
implicit must be written into the schedule when Codex implements it (not
amendments to the numbers): (i) the seam masks are two further `CfsMask`
slots of the **FFN** M (slots 7 and 8 in the order FA3 lists; the attention M
carries none for the seams) and `mask_functionals` gains their two derived
values and two Γ's; (ii) the mask degree equals the round degree in the
extension round too (2 = 2; see I1); (iii) the attention-side seam terminals
are observations that no inventory yet counts (§4) — they need FA3-style
pair rows and a place in FA7's joint model before the block's privacy can be
argued.

## 7. Verdicts (g)

### 7.1 Per slot

| Slot | Verdict | Basis |
|---|---|---|
| SC_GU (P1, and P3 with two extension rounds) | **approved** | §2.2, §2.3; batched with ZC20 as coded; extension degree = mask degree = 2 |
| SC_D (P1, P3) | **approved** | as GU, batched with ZC17 |
| SC_ZC20 / zero-check F | **approved** | Γ mixing accounted (§2.3); f-part total `ν0·s_gu` inside S |
| SC_ZC17 / zero-check D | **approved** | as ZC20 with `ν_z` |
| SC_TAB | **approved** | public 0; degree 3 incl. extension; `log_s + 1` variables in v3 |
| SC_ZSUM | **approved** | public 0; degree 2 |
| SC_PRED (function 2) | **approved** | public `τ` (inhomogeneous by a public constant only); degree 3; no function-2 proof captured (FA2 U9 stands for the PCS side) |
| SC_SEAM_X, SC_SEAM_Z (FA3) | **approved as specified** | §6; three clarifications to write down, none to the numbers |
| The M opening | **approved** under I5 (single opening) | §3; salted-hash assumption for unopened columns |

Counterexamples found in the construction: **none**. Counterexamples
exhibited for the negative controls: `nc_mask_challenge_zero` (13/13),
`nc_no_constant_a0_degenerate_challenge` (1), `nc_no_a0_no_aprime` (1),
`nc_extension_degree_exceeds_mask` (1: exactly the clear top value `h_3(4)`),
`nc_mask_reuse_same_challenges` (13), `nc_mask_reuse_fresh_challenges` (12),
`nc_batched_pair_without_zero_check_mask` (17), and on the M side
`nc_columns_exceed_pads`, `nc_columns_without_pads`, `nc_qprime_two_openings_same_M`,
`nc_qprime_without_blinding`, `nc_joint_two_openings_same_M` — each with the
leaked functional's support and a two-data pair in the record.

### 7.2 The invariants the verdict rests on (what Codex must keep, and two one-line hardenings)

- **I1 — degree.** In every round, including every extension round, the mask
  degree equals the round-message degree. `CfsMasker::mask_round` asserts
  it for the main rounds; `zk.rs::extension` does **not** — it zips `s_k`
  with `g_k` and would leave `s_k(X)` for `X > d_mask` unmasked. Today equal
  in all 9 slot kinds by construction. Proposed hardening (source owner):
  `assert_eq!(sk.len(), gk.len())` in `extension`.
- **I2 — variables.** `n_vars` = main rounds + extension rounds.
  `CfsMask::eval` asserts `rho.len() == n_vars`, so a mismatch panics before
  the opening rather than leaking.
- **I3 — `c ≠ 0`.** The verifier's `div` rejects; the prover has already
  emitted. Proposed hardening: the prover aborts the attempt when a mask
  challenge is zero (2^−128 per slot; the same class as FA3's
  "refusal-not-resample" rule).
- **I4 — freshness** (§5): one OS-entropy stream per attempt with an attempt
  nonce; no coefficient vector used twice.
- **I5 — one opening per `MaskCommit`**, and one θ.
- **I6 — row budget.** `L_s + 256 ≤ 512` (asserted) and ≤ 256 distinct opened
  columns (256 draws).

### 7.3 The approved mask specification (precise statement)

> For every masked sumcheck slot *s* with *N_s* rounds in the transcript
> (its main rounds plus every extension round) and round degree *d_s*, the
> CFS mask is a fresh, uniformly random polynomial
> `g_s(x) = a_0 + a'·Π_{j<N_s} x_j + Σ_{j<N_s} Σ_{e≤d_s} a_{j,e} x_j^e`
> over F_{p²} with `N_s·d_s + 2` coefficients (the `a'` term may be dropped;
> `a_0` may not), drawn once per proof attempt from an OS-entropy stream
> and committed in M before any challenge of the layer. The prover adds
> `c_s·g_{s,j}(X)` to round *j* for a challenge `c_s` drawn after the M root
> and before the slot's masked claimed sum or Γ is absorbed. The claimed sum
> is sent as `(private sum) + c_s·G_s` for the two matmul slots, formed by the
> verifier as `ν·(matmul masked claim) + Γ` with `Γ = c_s·G_s − ν·c_a·G_a`
> sent for the two batched zero-checks, and sent as `(public constant) +
> c_s·G_s` for every zero-claimed slot (table, zero-sum, predicate, the two
> seams). The verifier derives `g_s(ρ_s)` from the terminal relation, and M
> is opened exactly once, at the θ-combination of all derived `g_s(ρ_s)` and
> all sent Γ's, with ≥ 256 pads per coefficient row (`L_s + 256 ≤ 512`), a
> zero-sum blinding `b` and a proximity mask `u` used in that single opening.
> With this specification — which is what `cfa46f6` implements for v2's six
> slots, v3's six plus the predicate slot and the P3 matmul slots with their
> second extension round, and what FA3 §12 specifies for `SC_SEAM_X` and
> `SC_SEAM_Z` at `(log_t + log_db + 1, 2)` — the mask channel reveals nothing
> beyond the public constants and the masked terminal values.

### 7.4 What remains for FA8 (not claimed here)

- **B2 — simulator / transcript conditioning.** This review supplies the
  two facts a simulator needs and does not write it: (1) round-by-round, for
  *every* challenge sequence (hence for Fiat-Shamir-derived ones), the masked
  message `h_j` is uniform on its consistency fibre given everything absorbed
  before it, and the claimed sums / Γ's are uniform given the same; (2) the M
  view is a deterministic function of V plus independent uniform pads. The
  simulator must still (a) program the random oracle so that its chosen
  challenges are the hash outputs, (b) equivocate the M root — its committed
  a-rows cannot satisfy the functionals that are fixed only after M, which
  is the salted-leaf / programmable-RO step, and (c) compose with the PCS
  side's masked terminals through the terminal relation (the `want(m_t)`
  value), i.e. with FA7's joint distribution of the `m_t`.
- **B3 — ranges.** The CFS channel leaves a zero residual (uniform on S), so
  integer ranges have nothing of it to amplify; B3 reduces to what B2 and
  the PCS side leave.
- **B4 — repeats.** Under I4 the CFS views of different proofs are
  independent uniform; the cross-proof question is entirely the PCS side's
  (FA4's k-slot W).
- **FA7:** add the attention-side seam terminals to the observation
  inventory (§4, last rows); the seam sumcheck itself is approved.
- **Codex (source owner):** the two hardenings of §7.2 (I1 assert, I3 prover
  abort); the seam slots as FFN-M slots 7 and 8 with their functionals in
  `mask_functionals`' order; optionally drop `a'` (saves one coefficient per
  slot; not required).

## 8. Commands run (all from the worktree, absolute paths) and exit codes

| Command | Exit |
|---|---|
| `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -3` (head `cfa46f6`) | 0 |
| `sha256sum` of `zkp-core/src/sumcheck.rs`, `hashline/src/zk.rs` (header) | 0 |
| `sed -n` / `grep -n` / `cat` reads of `sumcheck.rs`, `zk.rs` (348–600, 700–760, 940–1120, 1120–1830, 2080–2130, 2425–2470, 2600–2800, 2810–2850, 2975–3140, 3400–3445, 3560–3640), `transcript.rs`, `rng.rs`, `field.rs`, `mle.rs`, `layer.rs`, `export.rs`, `hashline/src/{sumcheck,mle,lib}.rs`, `Cargo.toml`, FA2/FA3 docs, `ZK60_ROUND11.md`, the queue, `results/zk60_fable_fa3_mask_schedule.json`, FA2's tool and test | 0 |
| `python3 /home/victor/wt-zk60-fa/scripts/zk60_fable_cfs_channel.py --out /home/victor/wt-zk60-fa/results/zk60_fable_fa6_cfs_channel.json` (final run logged to `results/zk60_fable_fa6_cfs_channel.log`, ~52 s single-threaded) | 0 |
| `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_fable_cfs_channel.py' -v` — 21 tests, 114 s (a first run had one failure: the kernel count of the "dropped coefficient" controls counted the dropped unknown; fixed by reporting the kernel over active coefficients) | 0 |
| `env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 flock /tmp/zk-heavy.lock cargo test --release --offline --manifest-path /home/victor/wt-zk60-fa/hashline/Cargo.toml --test zk60_fable_cfs_channel -- --nocapture --test-threads=2` → `results/zk60_fable_fa6_rust_crosscheck.log` | see §8.1 |
| `sha256sum` of the four FA6 files (§8.2) | 0 |

### 8.1 The Rust cross-check

Fixture: `n_vars 3, degree 2`, coefficients `(p − 3, 1), (p − 5, 2), (p − 7, 3),
(p − 11, 4), (p − 13, 5), (p − 17, 6), (p − 20, 7), (p − 23, 9)`, challenges
`(2, 1), (5, p − 3), (7, 4)`. Expected (from the Python model, embedded as
constants in both tests): rounds
`[(18446744069414584163, 58), (18446744069414584086, 88), (18446744069414583921, 150)]`,
`[(18446744069414584268, 16), (18446744069414584212, 37), (18446744069414584088, 82)]`,
`[(18446744069414581390, 1102), (18446744069414581388, 1101), (18446744069414581340, 1118)]`;
total `(18446744069414583928, 146)`; eval `(18446744069414581082, 1277)`. The
Rust test asserts `CfsMask::round / total / eval / sum_weights / eval_weights`
against them and the verifier's chain (`interpolate_eval`), and checks the
extension-round identity `s_k(1) = poly(exts) = 0` with a public factor and
its failure for a private × private round (the P3 rationale).

**Result** (`results/zk60_fable_fa6_rust_crosscheck.log`, SHA-256
`49126bc65eb9310cbc6cfeb205ebff5dffb1f60949078f81d7fd60ad891a59f6`; the run
waited its turn on `/tmp/zk-heavy.lock` behind two other agents' builds,
then built in 49 s): `running 2 tests` — the `[FA6] round 0/1/2`, `total`
and `eval` values printed by the Rust code equal the constants above
exactly; `test cfs_mask_rounds_total_and_eval_match_the_python_model ... ok`,
`test extension_round_vanishes_at_one_only_with_a_public_factor ... ok`;
`test result: ok. 2 passed; 0 failed`; **exit 0**. The Python model of §2 is
therefore the actual `CfsMask` of `cfa46f6`, coefficient for coefficient.

### 8.2 File hashes

| File | SHA-256 |
|---|---|
| `scripts/zk60_fable_cfs_channel.py` | `ba05f0d140d72f67d69bbf48f4336d08a83cd99fbd01d2c49c417ec120066437` |
| `tests/test_zk60_fable_cfs_channel.py` | `512593d20c907c79e96dc146961c94892032171fb9c6aabd1ec9e2ee49c82c64` |
| `hashline/tests/zk60_fable_cfs_channel.rs` | `bb68f46dcf01894ac3d3784d06fa8aa8a74f37811ba2908960eeeb6485cf6674` |
| `results/zk60_fable_fa6_cfs_channel.json` | `3018cae282776b01b135adbd2afcbd0ba82443721dbeecdc8b7b9bef2783f4d0` |

## 9. Limits

- **Exact, but a model.** The ranks are exact modular arithmetic over the
  observation structure read from the source at `cfa46f6`; the challenge
  values are stand-ins (FA2's `Rng`), and the challenge-independence claim
  is the structural argument of §2.2 plus the two degenerate-challenge
  controls, not an exhaustive check. No proof bytes were consumed; the Rust
  cross-check pins the round formula, not a full masked layer.
- **Perfect hiding of the mask channel is not zero-knowledge of the
  protocol.** The verdict is conditional on the PCS side (the masked
  terminals' distribution — FA2/FA3/FA7) and on the simulator (B2 — FA8);
  §7.4 lists exactly what is handed over.
- **The M channel's information-theoretic part** covers `q'`, `prox` and the
  opened columns; the unopened columns are computationally hidden (salted
  blake3 leaves). The toy sizes (`m = 8`, 3 pads, 3 columns) carry the same
  algebra as `(512, 256, 256)`; the counts scale, the argument does not
  change.
- **Assumptions stated, not measured:** `2^−64` reduction bias of `fp()`;
  `2^−128` per-slot zero-challenge event (I3); duplicates among the 256
  indices only shrink the distinct-column count.
- **No source changed.** Nothing under `hashline/src/`, `zkp-core/`, FA7's
  files or FA3's document was edited; the hardenings of §7.2 are proposals
  to the source owner. No GPU, no full-model shape was run; synthetic
  fixtures only; no recovered value is reported (hashes only).
- The block-profile seam slots are reviewed **as specified by FA3**, not as
  implemented — no code exists for them at this pin.
