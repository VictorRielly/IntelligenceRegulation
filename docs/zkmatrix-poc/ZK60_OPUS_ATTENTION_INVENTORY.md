# O4 — the attention argument's source inventory (FA8 blockers A1–A4)

| | |
|---|---|
| Reviewer | **Opus 5**, independent reviewer, 2026-09-08 session |
| Task | `ZK60_OPUS_QUEUE.md` **O4 — attention inventory** (priority 0, read-only): "Continue FA6 A1–A4 as a source inventory: list every attention CFS slot, private terminal, mask allocation, proximity mask and proposed block seam endpoint. Give exact file/line references and distinguish implemented sites from design notes. Identify where a scalar base-field mask remains. Do not invent a repair or mark a privacy blocker closed; hand the table to Codex." |
| Continues | Fable's **FA6 §4** ("the attention-side seam terminals … **not counted — flagged for FA7/FA8**") and Fable's **FA8 §C.4** items A1–A4. FA1–FA9 remain Fable's work and keep their attribution; this document is Opus 5's continuation, not a re-issue of any Fable result. |
| Source pin | `b41d036c4c1eb1ed9272494815d742d0ccf29934`; worktree `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`, HEAD `a8a1bc7` |
| Profile | the fixed A00/B3 block: T = 32, d = 16, f = 16, H = 2, KV heads = 1, head_dim = 8, INT16 classes, 2 norm limbs, `log_cols` 8, inverse rate 8, Q = 256 (`causal_oracle.rs:20-24`, `:94-147`) |
| Tool / tests | `scripts/zk60_opus_attention_inventory.py`, `tests/test_zk60_opus_attention_inventory.py` (34 tests, OK) |
| Record | `results/zk60_opus_attention_inventory.json` |

**Status: inventory delivered. No repair is designed, no privacy blocker is
closed, and no attention privacy result is claimed.** Attention at this pin is
a **public / P0** argument: `pcs::commit` + `pcs::open`, no hiding commitment,
no mask row, no pad, no salt, no CFS mask anywhere. Everything below marked
*design-note* is the shape a private attention **would** need; Codex owns the
protocol decision.

---

## 0. The verdict in plain words

FA8 left the private block blocked on four attention items. This document
supplies the *source* half of all four and says exactly what is still missing.

The attention half-layer raises **133 claimed evaluations** (135 on the B4
receipt path) across **12 sumchecks** and **4 claim-collapse sumchecks**, opens
**three non-hiding commitments** (W 4 rows, A 108 rows, H 106 rows) in
**39 + 6 + 6 = 51 opening groups** (41 + 6 + 6 = 53 on the receipt path), and
publishes **10 multiplicity histograms** totalling 26,624 lookups. Every one of
those values is in the clear today.

Three findings the reader should not miss:

1. **Seventeen of the 39 A opening groups are singletons** (one claim at one
   point) — FA2 §14.1's worst shape, where a single base mask row discloses the
   *whole* plane per column. The FFN had three such singletons (X@p2, h16@p5,
   Wd@p6) and FA1/FA2 recovered all three. Attention has seventeen, plus six on
   W (every W claim is its own group) and one on H, and two more from the
   receipt's I/O binding.
2. **Six of the twelve sumchecks have a *private* claimed sum** — SS row sums,
   row sums, and all four matmuls compute their claimed sum from evaluation
   claims raised earlier in the same argument. Under any hiding profile those
   inputs are *masked* values, so the verifier's reconstructed claimed sum is
   masked too and the sumcheck relation no longer closes on the honest data.
   The FFN avoids this by sending `gu_claim = s_gu + c_gu·G_gu` as its own
   field. Attention has **six** such sums and **no** field to send them in.
   This is a design item for Codex, not something this inventory settles.
3. **The score and PV matmuls multiply two private factors with no vanishing
   public factor at this profile.** `ZK60_PRIVATE_BLOCK.md` suggests using "the
   existing equality factor's zero extension", but at KV heads = 1 the factor
   `eq(r_hi, rg)` is the **constant 1** (`log_kp = 0`; FA5 R22 says so
   explicitly), so there is nothing to extend to zero. The FFN's answer to a
   bilinear round is a *second* extension variable (`zk.rs:2138-2147`); these
   two attention slots need it **already under P1**, not only under P3.

A fourth, quieter one: attention raises **19** LogUp helper-sum claims
(`Cc::hsum`, one per helper column pair, all in a single opening group). The
FFN raises exactly **one**, masked by FA2 §14.5's zero-sum pair plus a fresh
pair. Nineteen independent zero-sum-style observations over five different
domains have no row in FA2's enumeration and no rule in FA3's schedule.

Every number in this document is produced by a tool whose model of
`attn_argument` is pinned to constants the Rust source fixes independently.
**Twenty-two such cross-checks pass** (§9.2): the ATTN_SC round/degree table,
the four collapse block sizes, the 4/108/106 commitment rows, 133 and 135, and
A01's executed event counts (89 A / 6 W / 19 H eval / 19 H sum / 99 terminal
descriptors / 10 tables), plus FA5 §4.3's lookup total 26,624.

---

## 1. What exists in source, and what does not

| Object | Status | Where |
|---|---|---|
| The 13-section public attention argument | **implemented** | `hashline/src/attention.rs:2211-2793` (`attn_argument`) |
| Metadata-only execution recorder | **implemented** | `hashline/src/attention_schedule.rs` (A01, `ZK60_ATTENTION_SCHEDULE.md`) |
| Internal FFN seam (`xm8` = X, `z16c` = z16) | **implemented, public** | `attention.rs:2899-2917`; `public_block_oracle.rs:104-118`, `:235-251` |
| Cross-layer seam gadget (`layer_seam`) | **implemented, public, unused on the receipt path** | `attention.rs:2935-2952`; FA5 R26 |
| Claim collapse (L5) | **implemented, public** | `attention.rs:2984-3155` |
| Short-W adapter | **implemented** | `public_block_oracle.rs:181-224` |
| Standalone hiding seam gadget (A02/S2) | **implemented, not on the attention path** | `hashline/src/private_seam.rs`; only consumer `hashline/tests/zk60_private_seam.rs` |
| Repaired paired-mask FFN (`ffn-v3-mr1-fresh-poc/1`) | **implemented** | `hashline/src/zk_ffn_fresh_poc.rs`, `zk.rs` mr1 branches (`b41d036`) |
| **Any private attention path** | **does not exist** | a `grep` for `attn` / `attention` over `hashline/src/zk.rs` returns no hit |
| **Any attention CFS mask slot** | **does not exist** | `mask_specs`/`mask_specs_v3` are FFN-only (`zk.rs:721`, `:2138`) |
| **Any attention mask row, pad or salt** | **does not exist** | attention commits with `pcs::commit` (`attention.rs:2866`, `:2871`, `:2880`) and opens with `pcs::open` (`:3216`, `:3220`, `:3234`) — the non-hiding path |

Consequence for the whole document: **every "mask" row below is a design note.**
The implemented column of every table is "no mask".

---

## 2. A1 — the attention schedule

### 2.1 The twelve sumcheck slots, in transcript order

`n_vars` here is the **executed** (public, P0) round count; §4 adds the
extension round a masked profile would need. `degree` is `ctx.sc`'s degree
argument; `public_block_wire.rs:21-35` stores `(rounds, degree + 1)` and the
tool reproduces that list exactly.

| # | Section / role | `ctx.sc` | n_vars | deg | Claimed sum, as the verifier forms it | Batching inside the slot | Terminal relation | Terminals (Pub / A / W / H) |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 norm row facts and SS sums | `attention.rs:2257` | 9 | 3 | **private**: `ss[0] + λ_ss·ss[1]`, each a linear form in the **16** `claim_sub` values raised at `:2241-2247` | λ_ss (1) | `eq(r_t,ρ)·(X(ρ)² + λ_ss·xres1(ρ)²)` | 1 / 2 (both `ACls`) / 0 / 0 |
| 2 | 2 norm squares | `:2281` | 5 | 3 | **public ZERO** | τ₁ (5), μ₁ (2) | `eq(τ₁,ρ)·Σ_k μ₁ₖ(Dsq−D²)` | 1 / 4 / 0 / 0 |
| 3 | 3 D ranges, norm, residuals | `:2334` | 9 | 4 | **public ZERO** | τ_d (9), μ_d (11) | `ZcPlan`: 9 `hcon` lookup pairs + 2 `Extra::NormDiv` | 1 / 20 / 2 / 9 |
| 4 | 4 Q ranges and RoPE | `:2398` | 9 | 4 | **public ZERO** | τ_q (9), μ_q (4) | `ZcPlan`: 3 `hcon` pairs + `Extra::Rope` | 3 / 7 / 0 / 3 |
| 5 | 5 KV ranges and RoPE | `:2438` | 8 | 4 | **public ZERO** | τ_kv (8), μ_kv (4) | as #4 | 3 / 7 / 0 / 3 |
| 6 | 6 softmax identities and ranges | `:2471` | 11 | 5 | **public ZERO** | τ_s (11), μ_s (6) | `SPlan::eval` (`:1689-1710`): c0..c5 | 2 / 8 / 0 / 3 |
| 7 | 7 masked row sums and selector | `:2513` | 11 | 3 | **private**: `sum_cl + λ_z`, `sum_cl` = the `claim_sub` at `:2509` | λ_z (1) | `eq(p_ht,ρ)·(mask·E + λ_z·zsel)` | 2 / 2 / 0 / 0 |
| 8 | 8 packed norm limb ranges | `:2540` | 8 | 4 | **public ZERO** | τ_l (8), μ_l (1) | `ZcPlan`: 1 `hcon` pair | 1 / 2 / 0 / 1 |
| 9 | 9 QKV projections | `:2578` | 4 | 2 | **private**: `acc_q + λ_k·acc_k + λ_v·acc_v` from the **6** `claim_at` values at `:2569-2574` | λ_k, λ_v | `xn8(ρ)·(Wq + λ_k Wk + λ_v Wv)(ρ)` | 0 / 1 / 3 / 0 |
| 10 | 10 GQA score product | `:2608` | 3 | 3 | **private**: `cs8·2^{sh_s} + crs` from the 2 `claim_at` at `:2601-2602` | — | `eq(r_hi,rg)·qr8(ρ)·kr8(ρ)` | 1 / 2 / 0 / 0 |
| 11 | 11 probability × value | `:2660` | 5 | 3 | **private**: `co8·2^{sh_o} + cro` from the 2 `claim_at` at `:2654-2655` | — | `eq(r_ohi,rg)·pp(ρ)·v8(ρ)` | 1 / 2 / 0 / 0 |
| 12 | 12 output projection | `:2714` | 4 | 2 | **private**: `ao_v·2^{sh_ao} + crao` from the `ao` class limbs + `rao` at `:2707-2710` | — | `o8(ρ)·Wo(ρ)` | 0 / 1 / 1 / 0 |

**How the twelve are batched.** They are **not** ν-batched with each other.
Unlike the FFN, where ZC20's claimed sum is `ν0·gu_claim + Γ20` and ZC17's is
`ν_z·d_claim + Γ17` (FA6 §2.3), each attention sumcheck stands alone with its
own claimed sum. What is batched inside a slot is a μ/λ combination of
relations over one domain (column 6 above). **The only ν combination in the
attention argument is the claim collapse** (`attention.rs:3013`:
`let nu = tr.challenge_fp2_vec(sel.len())`).

Consequently there are **no batched CFS pairs** to model on the attention side:
each of §4's twelve slots is FA6's *single-slot* system.

**Section 13** (`:2729-2788`) runs **no sumcheck**: it registers the 19 helper
sums and checks the LogUp identity `Σ helper sums = Σ_rows m_i/(α − t_i)` in
the clear. `AttnProof.helper_sums` is unused and must be empty
(`attention.rs:3242-3245`; `public_block_wire.rs:100-103`); the actual helper
sums travel through `Cc::hsum` into `vals`
(`ZK60_PRIVATE_BLOCK.md` exposure item 3).

### 2.2 The terminal values each slot exposes

Terminal descriptors are built by `terms` (`attention.rs:1846-1882`), which
walks a `TabDesc` list and calls `Cc::a1 / w1 / h1`. **99 descriptors** in
total, of which **83 raise a claim** (58 A + 6 W + 19 H). The other **16** are
`TabDesc::Pub`: values the verifier recomputes, which expose nothing — one `eq`
factor per sumcheck (9), the two RoPE `C`/`S'` MLEs of each RoPE zero-check
(`:2417-2418`, `:2457-2458` — 4), the causal-mask MLE in sections 6 and 7
(`:2497`, `:2523` — 2), and the GQA `eq_g` factor of the score and PV matmuls
(`:2641`, `:2693` — 2, both the constant 1 at KV heads = 1).

The remaining 50 of the 133 claims are raised *outside* `terms`: 29
pre-sumcheck `claim_sub`/`claim_at` values (16 in section 1, 1 in section 7,
6 + 2 + 2 + 2 in sections 9–12), the 19 `Cc::hsum` sums of section 13, and the
2 seam claims.

The per-claim table (commitment, site, slice offset, `log_size`, data rows,
full symbolic point, opening-group key, source line) is
`results/zk60_opus_attention_inventory.json` → `A1_schedule.claims`. Summary:

| Commitment | rows | eval claims | sum claims | opening groups (block / receipt) | singleton groups |
|---|---|---|---|---|---|
| W (`Wa`) | 4 | 6 | 0 | 6 / 6 | **6 (all)** |
| A (`Aa`) | 108 | 89 | 0 | 39 / 41 | **17 / 19** |
| H (`Ha`) | 106 | 19 | 19 | 6 / 6 | 1 |

"Single-row or multi-row" is the number of *committed rows* the claim's slice
spans (`2^{log_size − 8}`): a D/Q-domain plane is 2 rows, a KV-domain plane
1 row, an S-domain plane 8 rows, the packed `sm`/`lm` slices 2 rows each, a
W row 1 row. `row_weights` (`zkp-core/src/pcs.rs:204-228`) turns the leading
`log_size − 8` point coordinates into `eq` row weights.

### 2.3 The A opening groups (the unit FA2's model keys on)

`pcs::group_claims` (`zkp-core/src/pcs.rs:252-267`) keys a group by
`col_key` = the last 8 point coordinates (`None` — the all-ones weights — for
every `sum` claim). The 39 A groups, from the tool:

| Group(s) | m | Sites | Section |
|---|---|---|---|
| g0–g7 | 2 each | `sm[D/Dsq/a1/a2 site s]` **paired with** `lm[limb k site 1−s]` (the sub-block indices collide in the tail) | 1 |
| g8 | 2 | `x_in`, `xres1` class reconstructions at ρ_SS | 1 |
| **g9–g12** | **1** | `sm[D site 0]`, `sm[Dsq site 0]`, `sm[D site 1]`, `sm[Dsq site 1]` | 2 |
| g13 | **18** | the whole D-domain lookup list: `x_in, xn8, rho_a[0..1], sig_a[0..1], xm8, rho_m[0..1], sig_m[0..1], ao, rao, xres1, rr1, xres2, rr2, z16c` | 3 |
| **g14, g15** | **1** | `sm[D site 0/1]` (broadcast row) | 3 |
| g16 | 6 | `q8, rq, qr8, rqr, o8, ro` | 4 |
| **g17** | **1** | `q8` at the **flipped** rotate-half point | 4 |
| g18 | 6 | `k8, rk, v8, rv, kr8, rkr` | 5 |
| **g19** | **1** | `k8` at the **flipped** point | 5 |
| g20 | 6 | `s8, rs, zsel, et, pp, rho_s` | 6 |
| **g21, g22** | **1** | `sm[m]`, `sm[Sum]` (broadcast rows) | 6 |
| **g23** | **1** | `sm[Sum]` at p_ht | 7 |
| g24 | 2 | `et`, `zsel` at ρ_rowsum | 7 |
| g25 | 2 | `lm` lower/upper halves | 8 |
| g26–g28 | 2 each | `(q8, rq)`, `(k8, rk)`, `(v8, rv)` | 9 |
| **g29** | **1** | `xn8` | 9 |
| g30 | 2 | `s8`, `rs` at p_s | 10 |
| **g31, g32** | **1** | `qr8`, `kr8` | 10 |
| g33 | 2 | `o8`, `ro` at p_o | 11 |
| **g34, g35** | **1** | `pp` (8 rows), `v8` | 11 |
| g36 | 2 | `ao` limb 0, `rao` | 12 |
| **g37** | **1** | `o8` | 12 |
| g38 | 2 | `xm8` (`SeamXm8[0]`), `z16c` (`SeamZ16c[0]`) — **the seam** | seam |
| +2 (receipt) | **1** each | `x_in`, `xres2` class reconstructions at the two `bind_endpoints` points | B4 |

The bold rows are the **seventeen (nineteen) singleton groups** of §7.

**H:** 5 evaluation groups (`h_d` ×9 at ρ_D, `h_q` ×3, `h_kv` ×3, `h_s` ×3,
`h_lm` ×1 — the last a singleton) plus **one** sum group holding all 19
`Cc::hsum` claims.
**W:** 6 groups, one per claim — `gpack[γ_A]`, `gpack[γ_M]`, `Wq`, `Wk`, `Wv`,
`Wo`. `Wk`/`Wv` are 7-variable claims on the two halves of one 256-word row,
lifted to 8 variables by `lift_public_weight_claims`
(`public_block_oracle.rs:181-224`) **before** grouping; the tool applies the
lift where the source applies it and reports both forms.

### 2.4 The four collapse proofs (L5)

`collapse_plan` (`attention.rs:3097-3126`) in its **default** mode is the binary
decomposition of `[0, a_len = 27648)`; `collapse_range` (`:2984-3067`) then
folds every single-part, unit-coefficient claim inside a block into one claim.

| # | base | `base_log` | rounds | degree | Claimed sum | What it exposes |
|---|---|---|---|---|---|---|
| C1 | 0 | 14 | 14 | 2 | `Σ_c ν_c·claims[c].value` (`:3014-3017`) | the folded terminal `aval` = one raw A evaluation at ρ, `tr.absorb_fp2(b"collapse", &[aval])` (`:3040`, `:3054`) and stored in `proof.collapse` |
| C2 | 16384 | 13 | 13 | 2 | as above | as above |
| C3 | 24576 | 11 | 11 | 2 | as above | as above |
| C4 | 26624 | 10 | 10 | 2 | as above | as above |

Matches `public_block_wire.rs:114` (`[14, 13, 11, 10]`, width 3) exactly. Every
A claim is single-part with coefficient 1 (`Cc::a1`, `attention.rs:1806-1810`)
and every plane is allocated aligned to its own size, so **all 89 collapse**:
the A commitment opens at **4** points instead of 39. **W and H are not
collapsed** — `collapse_a` runs only on `cc.aw` (`:3129-3153`), and
`attn_open_wh` closes W and H first (`:3207-3221`), so their 6 + 6 groups
survive to the opening. `HL_NO_FOLD=1` disables the lever (`:3134-3136`);
`HL_FOLD=small|nos` are the two alternative plans. The B4 receipt refuses any
of those env settings (`public_block_receipt.rs:158-172`).

**Design note (A03 / `ZK60_PRIVATE_BLOCK.md` exposure item 5):** the first
private profile must use an explicit **no-collapse** policy; `aval` is a raw A
evaluation and `collapse_range` emits ordinary sumcheck rounds. §4 lists the
collapse slots anyway, in case Codex keeps the lever.

### 2.5 LogUp helper rows, zero-sum rows, and the histograms

- **Helper columns.** `build_helpers` (`:2073-2142`) writes 19 `(re, im)` Fp2
  column pairs into H: 9 over the D domain, 3 over Q, 3 over KV, 3 over S,
  1 over the packed-limb half. Each is claimed **twice**: once as an evaluation
  in its domain's zero-check terminal, once as a **sum** in section 13.
- **The 19 sum claims** (`Cc::hsum`, `:1823-1829`, called at `:2745-2747`) carry
  `point: vec![]`, `sum: true`, so `col_key` is `None` and all 19 land in one
  opening group with all-ones column weights.
- **There is no attention analogue of the FFN's `h_u` / `h_up` zero-sum pair.**
  The FFN commits a zero-sum row `u` (`Σ_j u[j] = 0`) and masks it with a fresh
  unconstrained pair; attention's LogUp identity is checked directly in the
  clear against the published histograms (`:2755-2787`).
- **Histograms.** `AttnProof.mults` (`:1770-1776`) is absorbed in full by
  `absorb_mults_a` (`:2831-2843`). Ten distinct tables at this profile,
  26,624 lookups (the tool reproduces FA5 §4.3's number):

| Table | table rows | required total | mask block rows if hidden (`max(size, n)/n`) | FA3 kind that would follow |
|---|---:|---:|---:|---|
| `Int8` | 256 | 5376 | 1 | **pair** (single-row slot, FA2 U10) |
| `Int16` | 65536 | 2560 | 256 | block |
| `U16` | 65536 | 4608 | 256 | block |
| `Exp` | 256 | 2048 | 1 | **pair** |
| `Prob` (2^9+1) | 513 | 2048 | 2 | block (ragged) |
| `Srem(14)` | 16384 | 4096 | 64 | block |
| `Win(0)` | 1 | 1024 | 1 | **pair** |
| `Win(6)` | 64 | 2048 | 1 | **pair** |
| `Win(7)` | 128 | 2304 | 1 | **pair** |
| `Win(9)` | 512 | 512 | 2 | block |

Five of the ten would be single-row slots — exactly FA2 U10 / FA3 §2.2's
"pair if `rows_i = 1`" case.

### 2.6 Proximity rows, pads and columns

| Item | Attention today | A hiding attention would need |
|---|---|---|
| proximity vector | **none** — `pcs::open` has no proximity row (`zkp-core/src/pcs.rs:42-...`); the ZK path's `zk_rhos` (`:835-856`) is not reached | one `prox_mask_row` per commitment (`:563`); FA3 §2.4 requires a prox **pair**, and `assert_mask_sites` (`:881-897`) checks only the single named row |
| pads | **none**; `q_pad = 0` | `q_pad ≥ Q = 256` per row (`pcs.rs:625`, `:947`), turning every row into RS(n + Q = 512, 2048); FA5 §4.3 records the resulting `(3/4)^256 = 2^-106.2` column term |
| salts | **none** | one `bytes32` salt per Merkle leaf |
| opened columns | 256 per opening, index < 2048, 11-digest paths (`public_block_wire.rs:20-23`, `:82-91`) | unchanged count; the pads are what hide them (FA6 §3) |
| commitments opened | 3 (W, A, H) | 3, each exactly once (FA3 §4.3) |
| commitment rows | W 4, A 108, H 106 | + the pair rows of §7; FA3 §8's accounting method applies, its numbers do not (they are the FFN's) |

---

## 3. A2 — the CFS slot table a private attention would need

**This whole section is a derivation, not a specification.** No attention CFS
slot exists in source. `n_vars = main rounds + extension rounds`, following
FA6 §1.1; the extension count follows `mask_specs_v3`'s rule
(`zk.rs:2138-2147`): an extension round is an identity only when
`poly(exts) = 0`, so a round with **one** private factor family (the rest
public, extending to 0) needs one extension round, and a round that multiplies
**two** private factors needs two — one per side.

### 3.1 The twelve slots (P1)

| Slot | Relation | main | ext | ext rationale | **n_vars** | **degree** | `L = N·d + 2` | Claimed-sum form |
|---|---|---:|---:|---|---:|---:|---:|---|
| `SC_ATTN_00` | SS row sums | 9 | 1 | `eq(r_t)` extends to 0 | **10** | **3** | 32 | private sum + `c·G` |
| `SC_ATTN_01` | D² | 5 | 1 | `eq(τ₁)` | **6** | **3** | 20 | public 0 + Γ |
| `SC_ATTN_02` | zero-check D | 9 | 1 | `eq(τ_d)` | **10** | **4** | 42 | public 0 + Γ |
| `SC_ATTN_03` | zero-check Q | 9 | 1 | `eq(τ_q)` | **10** | **4** | 42 | public 0 + Γ |
| `SC_ATTN_04` | zero-check KV | 8 | 1 | `eq(τ_kv)` | **9** | **4** | 38 | public 0 + Γ |
| `SC_ATTN_05` | zero-check S | 11 | 1 | `eq(τ_s)` | **12** | **5** | **62** | public 0 + Γ |
| `SC_ATTN_06` | row sums | 11 | 1 | `eq(p_ht)` × causal mask | **12** | **3** | 38 | private sum + `c·G` |
| `SC_ATTN_07` | zero-check LM | 8 | 1 | `eq(τ_l)` | **9** | **4** | 38 | public 0 + Γ |
| `SC_ATTN_08` | QKV matmul | 4 | 1 | activation private, W public (P1) | **5** | **2** | 12 | private sum + `c·G` |
| `SC_ATTN_09` | score matmul | 3 | **2** | **two private factors; `eq_g ≡ 1` at KV=1** | **5** | **3** | 17 | private sum + `c·G` |
| `SC_ATTN_10` | PV matmul | 5 | **2** | **two private factors; `eq_g ≡ 1`** | **7** | **3** | 23 | private sum + `c·G` |
| `SC_ATTN_11` | Wo matmul | 4 | 1 | activation private, W public (P1) | **5** | **2** | 12 | private sum + `c·G` |

Under **P3** (private weights) `SC_ATTN_08` and `SC_ATTN_11` gain a second
extension round → `(6, 2)`, `L = 14`, exactly as `mask_specs_v3`'s `x = 1`
does for the FFN's two matmuls.

If the collapse lever is kept (A03 says it should not be, first time round):
`SC_ATTN_COLLAPSE_{0..3}` at `(15, 2)`, `(14, 2)`, `(12, 2)`, `(11, 2)`,
`L = 32, 30, 26, 24`, claimed sum `Σ_c ν_c·value_c`.

**The seam slots are the FFN M's, not the attention M's.** FA6 §6 (i) is
explicit: `SC_SEAM_X` and `SC_SEAM_Z` at `(log_t + log_db + 1, 2) = (10, 2)`,
`L = 22`, are slots 7 and 8 of the **FFN** mask commitment; the attention M
carries none for the seams. That remains true here.

### 3.2 FA6's criterion applied per slot

FA6's algebra is **imported, not re-derived**: the tool loads
`scripts/zk60_fable_cfs_channel.py` by path (sha256
`ba05f0d1…120066437`, unchanged at this pin) and calls its `Channel`,
`system_single` and `analyze_system`. The criterion is FA6 §2.2: the map from
mask coefficients to the verifier's view is surjective onto the consistency
subspace `S` iff `rank(map) = dim S` with `image ⊆ S`.

| Mode | slots | `rank_map = dim S` | `image ⊆ S` | `leaked_dim_fp2` | kernel | Γ / `g(ρ)` / θ-combination in the view's span |
|---|---:|---|---|---:|---:|---|
| P1 | 12 | yes, all | yes, all | **0**, all | 1 each (`a'`) | yes, all |
| P3 | 12 | yes, all | yes, all | **0**, all | 1 each | yes, all |
| collapse (if kept) | 4 | yes, all | yes, all | **0**, all | 1 each | yes, all |

`dim S = N·d + 1` holds for every slot (asserted by test). Per-slot numbers are
in `results/zk60_opus_attention_inventory.json` →
`A2_cfs_slots.rank_verdicts`. A negative control (`c = 0`) is still detected by
the same code path, so the test is not vacuous.

**What this does and does not mean.** It says the *derived* `(n_vars, degree)`
systems, batched the way §3.1 says they would be, satisfy FA6's criterion — the
same structural fact FA6 established for the FFN's slots and for the two seam
slots. It says nothing about an implementation that does not exist, nothing
about the PCS side, and nothing about the simulator (FA8 B2). Stand-in
challenges, exact modular arithmetic; numerical rank is not a simulation proof
(FA2 §13, FA6 §9).

### 3.3 The mask-commitment layout constraint

`mask_commit` asserts `part.len() + MASK_Q ≤ m` with `MASK_Q = 256` and
`m = 512` message positions per coefficient row (`zk.rs:374-375`, `:442`), i.e.
`L_s + 256 ≤ 512`, i.e. `L_s ≤ 256`.

**The largest attention slot is `SC_ATTN_05` (zero-check S) at
`(12, 5)`, `L = 62`.** `62 + 256 = 318 ≤ 512`: **it fits, with 194 coefficient
positions of headroom.** No attention slot, in any of the three modes, comes
close to the bound; the largest FFN slot at 8B is `SC_ZC17` at `(18, 4)`,
`L = 74` (FA6 §1.3), so attention is not the binding case at this profile
either. Nothing would have to change.

**Caveat on scaling:** `L` grows with `n_vars·degree`, and `n_vars` for the
S-domain slots grows as `log_hp + 2·log_t`. At T = 512 with 32 heads,
`log_s = 5 + 18 = 23`, so `SC_ATTN_05` would be `(24, 5)`, `L = 122` — still
inside 256, but the head-room is a shape-dependent fact that Codex should
re-check for a deployment profile rather than inherit from this row.

### 3.4 The M-commitment shape

An attention M with the twelve slots of §3.1 would hold `2 × 12 = 24`
coefficient rows plus `b_re, b_im, u_re, u_im` = **28 rows** (36 with the four
collapse slots), each row `[L_s coefficients ‖ 256 pads ‖ zeros]` on `G_512`,
opened **once** at one θ (FA6 I5). `mask_functionals`' order would need to be
fixed in the same document that fixes the slot order — it is not fixed anywhere
today.

---

## 4. A3 — the seam-terminal pairs

### 4.1 The internal FFN seam, as implemented (public)

`attn_seam` (`attention.rs:2899-2917`) raises, for each of the `nb_d = 1`
d-blocks, two `claim_at`s on the attention A commitment at the **FFN's**
zero-check-D challenge `ρ_d` — replayed by `layer::v3_zcd_point` on a cloned
transcript state, which absorbs nothing (FA5 §4.5) — and compares them in the
clear with the FFN's `zcd_term` values.

| Endpoint (FA3 §12 notation) | Attention row set | offset | `log_size` | data rows | Point | FFN counterpart | Source | Today |
|---|---|---:|---:|---:|---|---|---|---|
| `SeamXm8[0]` | `xm8` | 22528 | 9 | 2 | ρ_d (`seam_points`, `public_block_oracle.rs:235-251`) | `ffn.zcd_term[..nb_d]` = the FFN's X at ρ_d | `attention.rs:2905`, `:2909-2914` | **public value in `AttnProof.vals`** |
| `SeamZ16c[0]` | `z16c` | 26112 | 9 | 2 | the same ρ_d | `ffn.zcd_term[nb_d..2nb_d]` | `attention.rs:2906`, `:2909-2915` | **public value in `AttnProof.vals`** |

Both land in **one** opening group (g38): the two points are identical, so the
column tails coincide.

**The mask kind FA3's rule assigns.** FA3 §2.2 reserves `a_sx[c]` and `a_sz[c]`
as **pair** roles on the *FFN* A; §12.1 says the attention manifest reserves
the mirror roles `SeamXm8[c]` and `SeamZ16c[c]`. Under FA3 §1's rule these are
single-row mask sites → **pair each**. Row cost at this profile: **+4 A rows**
(2 roles × 2 rows × nb_d = 1), matching FA3 §8's "+4" seam column for the A00
shape — but on the attention A, which FA3 §8 does not count.

**Aliasing this creates (FA3 §2.3 item 4, FA2 U12).** `xm8` and `z16c` are each
opened **twice**: once as a D-domain zero-check terminal at ρ_D (group g13) and
once at the seam point (g38). Under FA3's rule that is two independent pairs on
the same rows — the attention analogue of "X under three pairs at three tails"
(`whole_A_n4_*_seams`). The tool asserts the aliasing structurally.

**One-shot consumption.** `attn_open_a` takes `AttnPending` **by value**
(`attention.rs:3223`) and drops `a_cm` and `a_data`, so the A commitment is
opened once and the seam claims must be appended before it — the ordering
`prove_attn → attn_seam → [bind_endpoints] → lift_public_weight_claims →
attn_open` in `public_block_oracle.rs:104-121` and
`public_block_receipt.rs:222-246`. **But nothing marks a seam role as consumed
exactly once.** There is no manifest, no role set, no `Discarded` state and no
refusal for a missing or duplicated seam claim on the attention side; FA3
§4.1's `bind_internal_seams` contract has no counterpart in `attention.rs`.

### 4.2 The standalone hiding seam gadget (design reference, not on this path)

`hashline/src/private_seam.rs` implements A02/S2's equality of two
*independently hiding* committed planes. It is **not** used by attention (only
consumer: `hashline/tests/zk60_private_seam.rs`), but it is the closest
existing model of what an attention-side seam terminal would look like:

| Item | Value | Source |
|---|---|---|
| mask rows per plane | **5** = 2 terminal mask rows (re, im — an Fp2 **pair**) + 1 declared `prox_mask_row` + 2 further reserved rows | `private_seam.rs:33-35`, `:211-212` |
| CFS slot | `(log_len + 1, 2)` | `:112-114` |
| terminal claim | 3 parts: `(data, 1−e, ρ)`, `(R_re, e, tail ρ)`, `(R_im, e·u, tail ρ)` — exactly FA3's pair form | `:257-283` |
| terminal relation | `(1−e)·eq(τ, ρ)·(term_L − term_R) + c·mask_eval` | `:456-462` |
| refusals | `c = 0` (`:358-360`, `:443-445`), `e = 0` (`:394-396`, `:452-454`) | |
| one-shot | `prove` consumes both `PreparedPlane`s by value; "opening the same hiding commitment in multiple receipts is deliberately not supported" | `:11-13`, `:322-324` |
| entropy | `ZkRng::from_os` on every call; **no deterministic-seed option is exposed** | `:174-181` |

FA3 §9's `negative_control_seam_only_pairs_on_legacy_A` is the warning that
belongs beside this table: **appending seam pairs to an otherwise unrepaired
commitment repairs nothing.** The attention-side seam pairs are necessary for
the block and are not a substitute for §7's schedule.

### 4.3 What is still missing for A3

FA6 §4's last row and FA8 §C.4 item 3 ask for the attention-side seam terminals
to be *inventoried jointly with the attention's own openings of the `xm8` and
`z16c` rows*, and for a place in FA7's schema-2 capture. This document supplies
the **first half** (the endpoints, rows, points, aliasing, row cost and the
one-shot gap, above). The second half — running FA2/FA7's rank tool in
`repair` form over the whole attention A with those pairs — **cannot be done
from source**: there is no attention layout with mask rows to feed it, and no
capture. It stays open (§8, O-3).

---

## 5. A4 — the residual seam and the chain

### 5.1 What ships today: a public tensor, not an MLE equality

| | |
|---|---|
| Mechanism | block 0's expected **output** tensor and block 1's expected **input** tensor are the *same* 512 public INT16 words; each block binds its own end with `bind_endpoints` |
| Source | `public_chain_receipt.rs:127-148` (`block_expectations`), `public_block_receipt.rs:255-284` (`bind_endpoints`), `:118-125` (per-block context derive-key) |
| Per-block exposure | the full 512-word public input tensor and 512-word output tensor (`ExpectedPublicBlock`, `public_block_receipt.rs:28-34`); **2 extra A claims** (`x_in` and `xres2` class reconstruction at 2 fresh points, `:266-278`) → **135** vals instead of 133; **2 extra singleton A opening groups** |
| Two-block exposure | the intermediate 512-word tensor **in the clear** (`PublicChainReceipt.intermediate`, `public_chain_receipt.rs:153-158`); both blocks' complete P0 proofs; the per-block context digest chain |
| FA5's row | R26: "P0 only. The committed-to-committed private seam (A02/S2, `private_seam.rs`) is experimental and not integrated; the two-block private chain is UNPROVED." |

### 5.2 The cross-layer seam gadget in `attention.rs` (implemented, unused here)

`layer_seam` (`attention.rs:2935-2952`) proves layer *l*'s `xres2` MLE equals
layer *l+1*'s `x_in` MLE at one point drawn after **both** layers' A
commitments, via `cls_claim` (`:2920-2932`). It exposes one claim **per class
limb per side** (2 at this profile, 4 under `Cls::Int24`), each a raw
evaluation in `vals`, plus one clear equality check. It is not on the B5 chain
path (FA5 R26).

### 5.3 `chain.rs`

`chain.rs` is the **exact-integer FFN witness derivation** (`chain.rs:1-15`),
not a cross-block proof object: it produces the planes the FFN proof consumes
and the `z` digest the export gate compares. The attention analogue is
`witness_digests` / `chain_from_export` / `verify_export`
(`attention.rs:661-732`, `:734-737`, `:740-786`), which emit 64 per-tensor
SHA-256 digests plus one CHAIN digest of the whole witness.
`ZK60_PRIVATE_BLOCK.md` exposure item 9 is the relevant warning: witness
digests permit dictionary testing and must stay out of public artifacts.

### 5.4 What a private profile would have to change (design note)

1. The intermediate tensor cannot be published. The residual becomes an MLE
   equality between block *k*'s attention A and block *k+1*'s attention A —
   `layer_seam`'s relation under a masked-equality gadget of `private_seam.rs`'s
   form, with its own CFS slot and its own reserved pair rows on **both**
   attention commitments.
2. Block *k*'s attention A may not finalize before block *k+1* has bound the
   residual seam (FA3 §4.5), so a chain holds two `AttnPending` objects at once.
   Nothing in `attention.rs` enforces or even expresses that ordering today.
3. `bind_endpoints`' external I/O binding stays public **only** for the declared
   boundary of the whole chain; every intermediate binding must move inside the
   seam.
4. The chain-level transcript order (block headers, per-block roots, the seam's
   position) is unwritten — FA8 §C.4 item 4 / FA4 H7.

---

## 6. Where a scalar base-field mask remains

FA2 §14's rule: a mask is **Fp2-effective** per column if its per-column
contribution ranges over all of Fp2 — an `(re, im)` pair, or a base mask block
spanning ≥ 2 rows with Fp-independent row weights. **A single base row is not**:
its contribution is the line `Fp·(λc)`, and that is the one cause of every leak
FA1/FA2 found in the FFN.

### 6.1 Today

**There is no mask at all.** Attention commits with `pcs::commit` and opens
with `pcs::open`. Every one of the 133 (135) claimed values, every group
vector, every opened column and every histogram bin is in the clear. This is
not a "scalar mask" situation; it is the un-masked situation, and it is what
the P0 label means (`public_block_oracle.rs:1-6`).

### 6.2 Under the obvious port of the FFN repair

The FFN's legacy allocation gives **one base row per (plane, point) claim**
(`ZkLayoutV3::with_masks(.., mr1 = false)`, `zk.rs:1998`, width 1); the shipped
repair sets `width = 2` and `pair_claim` appends the `im` part with coefficient
`×u` (`zk.rs:2059-2067`). Ported naively to attention, **every one of the 51
(53) opening groups is a single-row/scalar mask site** under the legacy width
and a pair under `mr1`. Ranked by what FA2's model says each would leak:

| Class | Count (block / receipt) | FA2 verdict if scalar | Sites |
|---|---:|---|---|
| **Singleton A groups** | **17 / 19** | **FA2 §14.1: n functionals per column — the whole plane** | g9–g12, g14, g15, g17, g19, g21–g23, g29, g31, g32, g34, g35, g37 (+2 receipt) |
| **Singleton W groups** | **6 / 6** | as above (this is FA1 item 5's `Wd` singleton shape, six times) | `gpack[γ_A]`, `gpack[γ_M]`, `Wq`, `Wk`, `Wv`, `Wo` |
| **Singleton H group** | 1 | as above | `h_lm` |
| Multi-member A groups | 22 / 22 | FA2 §14.2: 2 base functionals per group | g0–g8, g13, g16, g18, g20, g24–g28, g30, g33, g36, g38 |
| Multi-member H groups | 4 | as above (but H's planes are Fp2-valued and already pair-shaped, FA2's H rows) | `h_d`, `h_q`, `h_kv`, `h_s` |
| H sum group | 1 (19 members) | FA2 §14.5's territory; see below | all 19 `Cc::hsum` claims |

Under **P1** the six W groups are *public weights* — `W1.plain` in FA2's
enumeration, no privacy claim, the approved-root boundary (FA4 §2) is the
identity mechanism. Under **P3** they are exactly FA2 U11's `W3.vec.*` rows and
each one is a singleton.

### 6.3 Sites that stay scalar even after a naive `mr1`-style port

These are the ones Codex should look at first, because applying
`pair_claim` mechanically does **not** fix them:

1. **The proximity mask row.** `CommittedZk::prox_mask_row` is a single
   `Option<usize>` (`zkp-core/src/pcs.rs:563`) and `assert_mask_sites` checks
   only that one row is touched (`:889-891`). The FFN's mr1 path fills a 2-row
   range (`zk.rs:2469` via `mask_range`) so the two rows do get independent
   ρ's from `zk_rhos`' `challenge_fp2_vec(rows)` — but the **assertion** still
   names one row, which is exactly the extension FA3 §2.4 asks for. FA3 §9's
   `negative_control_one_pairmask_claim_single_prox_row` leaks 1 functional per
   column; `one_pairmask_claim_prox_pair` leaks 0.
2. **The 19 LogUp helper-sum claims** (`Cc::hsum`, `attention.rs:1823-1829`,
   `:2745-2747`). All 19 share one opening group with all-ones column weights.
   The FFN has **one** such claim and masks it with a zero-sum pair `h_u` plus
   a fresh unconstrained pair `h_up` (FA2 §14.5, FA3 §2.2). Nineteen
   independent sums over five different domains have **no row in FA2's
   enumeration and no rule in FA3's schedule**. Whether one shared zero-sum
   construction covers all 19, or each helper pair needs its own, is an open
   question this inventory cannot answer (§8, O-1).
3. **The four collapse terminals `aval`** (`attention.rs:3040`, `:3054`,
   `:3063-3065`): a raw A evaluation absorbed in the clear and stored in
   `proof.collapse`. A03 / `ZK60_PRIVATE_BLOCK.md` item 5 requires
   **no-collapse** in the first private profile; if the lever is kept, each
   `aval` is one more single-row site with its own point.
4. **Class-reconstruction limbs** (`TabDesc::ACls`, `attention.rs:1868-1878`;
   `cls_claim`, `:2920-2932`). Each limb is its own claim, so each needs its
   own mask row: one shared mask over a reconstructed value would leave the
   limb **differences** in the clear — the same reasoning `zk.rs:1974-1977`
   gives for "ONE mask row per W BLOCK terminal". Latent at this profile
   (`Cls::Int16` → 1 limb, so `ACls`/`cls_claim` degenerate to a single claim);
   it bites at `Cls::Int24` (2 limbs), which `ZK60_PRIVATE_BLOCK.md` names as
   an untested branch.
5. **The two flipped-point RoPE claims** (`q8` at `:2413-2416`, `k8` at
   `:2453-2456`). FA3 §2.3 item 6 says a flipped-point claim is a separate group
   with its own reserved pair — "A1's RoPE row". Both are **singleton** groups
   here (g17, g19), i.e. the worst shape.
6. **The two seam claims** `SeamXm8[0]`, `SeamZ16c[0]` (§4.1) — pair each under
   FA3, and they alias rows already opened at ρ_D.
7. **The two `bind_endpoints` claims** on the receipt path
   (`public_block_receipt.rs:266-278`): two more singleton groups, one per
   external role. These bind against *public* tensors, so they may be exempt by
   statement — but that is a product ruling about what the boundary discloses,
   not a masking fact.
8. **The histograms are not a mask site at all** — they are published
   (`AttnProof.mults`, `absorb_mults_a`). A private profile needs the FFN's
   committed-table construction, and §2.5's table shows **five of ten** slots
   would be single-row (`Int8`, `Exp`, `Win(0)`, `Win(6)`, `Win(7)`) — FA2 U10 /
   FA3 §2.2's "pair if `rows_i = 1`" case.

---

## 7. Requirements for Codex (numbered, testable)

Each row states what an implementation must satisfy and how to check it.
These are **derived from FA3/FA6/FA7/FA8's accepted rules applied to the
attention sites this inventory found**; they are not a new protocol and they do
not close FA8's A1–A4.

| # | Requirement | Test that would demonstrate it |
|---|---|---|
| **R1** | Every attention claim site of §2.3 has a **reserved role** with a fixed row index in an attention layout, a declared mask kind ∈ {pair, block, zero_sum_pair, prox_pair}, and a group key — a table in FA3 §2.2's exact columns. | A `describe()`-style layout string, hashed into a `layout_digest`, plus a test that role row ranges are pairwise disjoint and cover every claim (the `zk60_pending_layout.rs` pattern). |
| **R2** | **Every single-row mask site is a pair.** In particular all 17 (19) singleton A groups, all 6 W groups under P3, the `h_lm` group, both flipped-point RoPE claims, both seam terminals, and every single-row table slot of §2.5. | FA2's rank tool in `repair` form over the whole attention A / H / (P3) W: `disclosed_dim = 0` per group **and** on the whole commitment; the FA1 `mask_diagnostic` extractor must refuse ("requires exactly data plus one base mask") on every claim. |
| **R3** | The **proximity row of every attention commitment is a pair**, and `assert_mask_sites` is extended to assert that the prox ρ touches **both** prox rows and that every group vector touches **both** rows of at least one pair (FA3 §2.4). | The negative control `negative_control_one_pairmask_claim_single_prox_row` (leaks 1/column) against `one_pairmask_claim_prox_pair` (leaks 0), run on the attention layout. |
| **R4** | A rule for the **19 helper-sum claims**: either one zero-sum construction covering all 19, or one per helper pair, with the residual identified explicitly and shown equal to the public LogUp identity. | FA2 §14.5's model extended to 19 sums: `rank F = rank I = rank(F ∪ I) = 2` (the public identity) and nothing more. |
| **R5** | A **CFS slot list and order** for the attention M: §3.1's `(n_vars, degree)` table (or Codex's own), with **extension degree = mask degree in every round** (FA6 I1), the claimed-sum form per slot, and a fixed `mask_functionals` order. | FA6's tool run on the implemented slot list: `rank = dim S`, `image ⊆ S`, `leaked_dim = 0` per slot and per batched pair; `L_s + 256 ≤ 512` asserted by `mask_commit`. |
| **R6** | A decision and a mechanism for the **six private claimed sums** (§0 finding 2): a masked claimed sum must be *sent*, as `gu_claim`/`d_claim` are, or the claim must be re-derived so the sumcheck's claimed sum is public. Reconstructing it from masked terminal values does not close the relation. | A CPU test that the prover's own `s0 == claim` assertion (`attention.rs:1961`) still holds under masking, and a verifier refusal when the sent masked sum is inconsistent. |
| **R7** | A decision on the **two bilinear matmuls** (score, PV): two extension rounds, or a vanishing public factor that actually vanishes at KV heads = 1 (`eq_g ≡ 1` today). | The `poly(exts) = 0` identity checked per slot, as `hashline/tests/zk60_fable_cfs_channel.rs` does for the FFN, including the private × private failure case. |
| **R8** | **Fresh OS randomness, no caller seed.** One `ZkRng` per component per attempt from OS entropy under a domain naming profile, layer **and attempt nonce**; an explicit seed unreachable outside `cfg(test)`; a discarded attempt's masks never reused (FA3 §3, FA6 I4, FA8 S1/S2). `private_seam.rs:174-181` is the existing shape to copy. | Two attempts on the same witness produce different A, M and H roots (FA3 AM13/P1); the production entry point takes no seed (compile-time or typed error). |
| **R9** | **One mask opening per commitment.** `mask_open` once per M and one θ (FA6 I5); `open_zk` once per `CommittedZk`, on an owned value dropped immediately (FA3 §4.3). Attention's `attn_open_a` already consumes `AttnPending` by value (`attention.rs:3223`) — keep that. | A compile-fail for a second use; FA6's `nc_qprime_two_openings_same_M` as the negative control. |
| **R10** | **Seams consumed exactly once.** The attention manifest reserves `SeamXm8[c]`, `SeamZ16c[c]` and the residual-seam role; binding marks them; finalization refuses a consumed-role set ≠ the manifest role set (FA3 §4.1, §4.5). Nothing on the attention side does this today. | FA3 AM11 (Z seam omitted), AM17 (finalize before binding), AM19 (block k+1 binds to a block-k A that never reserved the role), AM23 (duplicate/unknown/missing role). |
| **R11** | **No copied-plane substitute.** A seam terminal is always a claim on the layout's own `xm8` / `z16c` slice of the attention A the block owns; no parameter admits a third commitment (FA3 §12.1, AM10). | A seam opening against any other root refused at the root comparison, before any Merkle work. |
| **R12** | **Transcript order** fixed and recorded: every masked claim and terminal absorbed before the next challenge, in A01's 13-section order, with the seam and the openings where FA3 §12.2 puts them. | A test that the recorded prover **and** verifier absorb sequences equal a committed `transcript_order` list label by label (FA8 §H item 1's acceptance). |
| **R13** | **Exact counts everywhere**: claim values, sumchecks, collapse proofs, group vectors, prox lengths, columns, CFS spec count. Extra data refused as well as missing data (FA5 R32). `public_block_wire.rs` is the existing shape; the private profile needs its own framed envelope. | A refusal test per field, as B4/B5 already have for the P0 wire. |
| **R14** | **No-collapse in the first private profile** (A03 / `ZK60_PRIVATE_BLOCK.md` item 5), or a masked collapse with its own slots (§3.1) and its own cost accounting. | The proof carries `collapse.len() == 0` and the verifier refuses a non-empty collapse vector under the private profile id. |
| **R15** | **Capture schema fields for attention**, the analogue of FA7 §10's schema 2: per role `row_roles` with attention site ids (`a_mf`-style names for the 39/6/6 groups, `attn_prox.re/.im`, `SeamXm8[c].re/.im`, `SeamZ16c[c].re/.im`, `attn_resid.re/.im`), `public_linear_constraints` listing the 19 helper-sum relations, pair claims in the three-part form, the seam slices so the aliasing of `xm8`/`z16c` is visible, and the histogram-slot rows. | FA7's parser extended to the attention coverage id; a legacy attention capture presented with a repaired coverage refused by the layout recomputation. |
| **R16** | **Degenerate challenges refused, never resampled** on the attention side too: `k1 ≠ 0`, `λ ≠ 0`, prox ρ's Fp-independent, block row bits outside Fp, `c_s ≠ 0`, `e ≠ 0` (FA3 §6.5, FA6 I3). `private_seam.rs:358-360`, `:394-396`, `:443-445`, `:452-454` already do this for the standalone gadget. | FA3 AM14, AM15, AM22 with the corresponding hooks. |

---

## 8. Open items — what this inventory could **not** derive from source

| id | Item | Why it is open |
|---|---|---|
| **O-1** | Whether one zero-sum construction covers all **19** helper-sum claims, or each helper pair needs its own. | FA2 §14.5 models **one** constrained zero-sum row `u` with a fresh mask `u'`. Nineteen simultaneous sums over five domains, all in one opening group, is a different algebraic object. Deriving it requires FA2's rank model, not source reading. |
| **O-2** | The rank verdict of the **whole attention A / H / W** under any proposed pair schedule. | There is no attention layout with mask rows, so FA2/FA3's `repair` machinery has nothing to consume. This is FA8 §C.4 item 1's "FA2's tool run in `repair` form", and it needs the layout first. |
| **O-3** | Confirmation of the seam aliasing on **real** claims. | No capture of any attention proof's coefficients exists (FA7's twelve captures are FFN-only, coverage `ffn-v3-function-1`). FA8 §C.4 item 3's "a place in FA7's schema-2 capture" is R15 above; the capture itself does not exist. |
| **O-4** | Whether the six private claimed sums (§0 finding 2, R6) can be sent as masked sums without changing the terminal relations of slots 1, 7, 9, 10, 11, 12. | This is a protocol design question. Answering it *is* designing the repair, which the queue forbids for this task. |
| **O-5** | The extension-round count for the **collapse** slots if the lever is kept, when the folded claims are themselves masked. | `collapse_range`'s `G(x)` is public and extends to 0, so §3.1 assigns one extension round; but the folded claim values would be masked terminals, which is O-4 again. |
| **O-6** | Whether the two `bind_endpoints` claims need masks at all. | They bind against *public* tensors declared by the statement. Whether the declared boundary discloses them is a product ruling (FA4 M13's request-binding obligation), not a masking fact. |
| **O-7** | Row/byte cost of a paired attention schedule at deployment shapes. | FA3 §8's counting method applies, but its numbers are the FFN's. The attention row count is a function of the group count (51 today), which is shape-dependent; the tool computes it only at the fixed profile. |
| **O-8** | The head-room of `L_s + 256 ≤ 512` at a deployment profile. | §3.3 checks the fixed profile (largest `L = 62`, head-room 194) and estimates T = 512/H = 32 at `L = 122`; a real deployment layout was not built. |
| **O-9** | Whether `Trace::check_fixed_reference`'s three frozen fingerprints (A01) would change under a private profile. | They pin the *public* execution shape; a private profile is a different schedule and would need its own reviewed reference. Not derivable here. |

---

## 9. Evidence

### 9.1 Files

| File | Role | SHA-256 |
|---|---|---|
| `docs/zkmatrix-poc/ZK60_OPUS_ATTENTION_INVENTORY.md` | this document (new) | recorded at commit (a file cannot contain its own hash) |
| `results/zk60_opus_attention_inventory.json` | the same tables machine-readably (new) | `81e634bee7ed04c49e8f5b0890ff211aff9fcbc049112a6fd370cf26994b1439` |
| `scripts/zk60_opus_attention_inventory.py` | the inventory tool (new) | `dd0b8cde98a2bf0d52a0184a83e68c42f6f9207c1cda3f9c51d9edd743689bd5` |
| `tests/test_zk60_opus_attention_inventory.py` | 34 tests (new) | `0cfa67b52cad1f16eaafcc76c1fd02d6422e228a49f0246ab57602007c149892` |

The JSON records the tool's own sha256 and the sha256 of every source file it
read; `test_committed_record_is_bound_to_this_tool_and_this_source` fails if
either drifts.

Read, not changed: every source file in §9.3, and
`ZK60_FABLE_MASK_REPAIR.md`, `ZK60_FABLE_CFS_CHANNEL.md`,
`ZK60_FABLE_PRIVACY_REVIEW.md`, `ZK60_FABLE_SECURITY_OBLIGATIONS.md`,
`ZK60_FABLE_CAPTURE_REVIEW.md`, `ZK60_FABLE_TRANSCRIPT_REVIEW.md`,
`ZK60_ATTENTION_SCHEDULE.md`, `ZK60_PRIVATE_BLOCK.md`,
`ZK60_BLOCK_CONTRACT.md`, `ZK60_CAUSAL_ORACLE.md`, `ZK60_PENDING_FFN.md`.
Nothing under `hashline/`, `zkp-core/`, `codex-audit-*`, no `ZK60_FABLE_*` file
and no `scripts/zk60_fable_*.py` was modified;
`scripts/zk60_fable_cfs_channel.py` is imported read-only and its sha256 is
asserted by test.

### 9.2 The twenty-two cross-checks (all PASS)

| Check | Pinned against |
|---|---|
| commitment rows (W 4, A 108, H 106) | `public_block_wire.rs:117-121` |
| the twelve `(rounds, degree + 1)` pairs | `public_block_wire.rs:21-35` (`ATTN_SC`) |
| collapse block rounds `[14, 13, 11, 10]` | `public_block_wire.rs:114` |
| block claim count 133 | `public_block_wire.rs:106` |
| receipt claim count 135 | `public_block_receipt.rs:300` |
| A / W / H-eval / H-sum claims 89 / 6 / 19 / 19 | `ZK60_ATTENTION_SCHEDULE.md` executed counts |
| terminal descriptors 99 | same |
| sumchecks 12, collapses 4 | same |
| distinct LogUp tables 10 | same |
| total attention lookups 26,624 | `ZK60_FABLE_SECURITY_OBLIGATIONS.md` §4.3 |
| short-W claims lifted = 2; adapter preconditions (8, 7, 256, 384, 1024) | `public_block_oracle.rs:196-205` |
| FA6 criterion surjective, P1 / P3 / collapse | `scripts/zk60_fable_cfs_channel.py` |
| `L + 256 ≤ 512`, P1 / P3 / collapse | `zk.rs:442` |

### 9.3 Source files inspected (SHA-256 at `a8a1bc7`)

| File | SHA-256 |
|---|---|
| `hashline/src/attention.rs` | `c5ae80ddc909aae40b9ec6b9766e5634cf3dc13172e8902f8f2dc33c77cdf979` |
| `hashline/src/attention_schedule.rs` | `e6f818d784587fa02ea9c3d189b0294e6cf2a69e0127de460b4a4002ab877bb9` |
| `hashline/src/public_block_wire.rs` | `2ad6d8276a7f8c7fbd580835e8d3b101bda12be2ea0123162a838a4c0ca6d3cc` |
| `hashline/src/public_block_receipt.rs` | `2f99ae965d0efb5a12579b4668573798c3d1b109f3b38d13cceeea624b0ba9e0` |
| `hashline/src/public_block_oracle.rs` | `0cc821e8c8c30bf842ea11442845d3156a522fc3d8f3e82d6f9fdfa55a58a83f` |
| `hashline/src/public_chain_receipt.rs` | `2d7c224756acf7439c52d12a80d5d70010f4c087bf7022b2617db3b4929544a1` |
| `hashline/src/private_seam.rs` | `ae539c9cb7799d67e60d05e98377e64b701eae20e569df4f42f7f4fa0edcb435` |
| `hashline/src/chain.rs` | `dd6a902a91edf5ba878c9ad987e6c6750c46e2b919238487f17f65621e807180` |
| `hashline/src/norm.rs` | `60e3f9b33564c8027e80e250326ea2ac8d2f14c443a348eafc3e365bc5d8eb58` |
| `hashline/src/tables_attn.rs` | `6654e31badcfe577eeece52c7b7bbd903bf687e2bb9e7fb145051cafc665ffa7` |
| `hashline/src/causal_oracle.rs` | `758bd3401cc726dd621ff0b04b9d7b09a50decc773f03f4a21ddbc031921d85a` |
| `hashline/src/zk.rs` | `d80755acf7e47cc04f570942820332535420d90af3e597176081acea3041ecba` |
| `hashline/src/pcs.rs` | `6d27f3a5bc28fb7bb57ab14ddb395f4c6911db2b8541876af73344125520d8a8` |
| `zkp-core/src/pcs.rs` | `2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d` |
| `zkp-core/src/sumcheck.rs` | `56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19` |
| `scripts/zk60_fable_cfs_channel.py` | `ba05f0d140d72f67d69bbf48f4336d08a83cd99fbd01d2c49c417ec120066437` |
| `scripts/zk60_fable_joint_rank.py` | `ad5e4e483c6dd8c5f73a87ddb0af1d06c3084576e82428e9c2ada6a764ffbb5b` |

`hashline/src/attention.rs`'s hash is byte-identical to A01's frozen source
guard (`ZK60_ATTENTION_SCHEDULE.md`), so the schedule this inventory models is
the schedule A01 executed. `zk.rs` differs from FA6's pin `cfa46f6`
(`c4442534…`) because `b41d036` added the `mr1` fresh-poc branches; the FA6
*tool* is byte-identical, which is what the imported criterion depends on.

### 9.4 Commands and exit codes

| Command | Exit |
|---|---|
| `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -3` (HEAD `a8a1bc7`) | 0 |
| `sha256sum` of the seventeen files of §9.3 | 0 |
| `sed -n` / `grep -n` reads of `attention.rs` (655-790, 790-1210, 1533-2212, 2211-2810, 2810-3320, 3310-3420), `attention_schedule.rs`, `public_block_wire.rs`, `public_block_receipt.rs`, `public_block_oracle.rs`, `public_chain_receipt.rs`, `private_seam.rs`, `chain.rs`, `causal_oracle.rs`, `zk.rs`, `zkp-core/src/pcs.rs`, `zkp-core/src/ffn_v3/statement.rs`, and the eleven docs of §9.1 | 0 |
| `python3 /home/victor/wt-zk60-fa/scripts/zk60_opus_attention_inventory.py --out /home/victor/wt-zk60-fa/results/zk60_opus_attention_inventory.json` — **22 checks, all PASS** | 0 |
| `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_opus_attention_inventory.py' -v` — **34 tests, OK**, 2.3 s | 0 |
| `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_fable_*.py'` (Fable's FA2/FA3 + FA6 + FA7 + FA8 suites; detached with `setsid nohup` + a `.done` marker per the no-hangup protocol, log `/tmp/zk60-opus-fable-suite.log`) — **`Ran 94 tests in 136.495s`, `OK`**, marker `0` | 0 |

No cargo, no Rust build, no GPU, no proof executed. Python 3, stdlib only,
single-threaded.

The sha256 of this document is recorded by the orchestrator at commit time
(a file cannot contain its own hash); the other three are in §9.1.

## 10. Limits

- **Design input only.** Attention at `b41d036` is a **public / P0** argument.
  Nothing here is a privacy result about attention, and **no privacy blocker is
  closed**: FA8's A1, A2, A3 and A4 all remain open. This document supplies the
  source half of each and names what is still missing (§8).
- **No repair is invented.** The mask kinds are FA3's, applied as a
  *classification* of attention sites so Codex can see the shape of the problem.
  Where a design choice would be required (R6, R7, O-1, O-4) the question is
  stated and left to Codex.
- **§3's CFS slot table is derived, not specified.** No attention CFS slot
  exists. The FA6 rank verdicts certify the derived `(n_vars, degree)` systems,
  not an implementation. Extension-round counts follow `mask_specs_v3`'s stated
  rule; a different construction changes them.
- **The rank evidence is FA6's model with FA6's caveat**: exact modular
  arithmetic over the observation structure, stand-in challenge values;
  **numerical rank is not a simulation proof** (FA2 §13, FA6 §9). The PCS-side
  rank (FA2/FA3/FA7's model) is **not** run here — there is no attention layout
  with mask rows to feed it (O-2).
- **One shape only.** Every count is at the fixed A00/B3 profile
  (T32/d16/f16/H2/KV1). Group counts, singleton counts and row costs are
  shape-dependent; nothing was computed at 125M, 8B or T = 512 (O-7, O-8).
- **`Cls::Int24`, non-power-of-two head maps, dummy heads, GQA ratios other
  than 2, and the `HL_FOLD` alternative plans are outside this inventory** —
  the fixed profile does not exercise them, and `ZK60_PRIVATE_BLOCK.md` already
  asks for a separate audit of the head mapping.
- **Attribution.** FA1–FA9 are Claude Fable 5.1's independent reviews and keep
  their results, scope and caveats. This document is Opus 5's continuation of
  the FA6 §4 / FA8 §C.4 handoff and claims nothing on Fable's behalf.
- **Codex retains the judgment.** This is a table handed to the source owner,
  not an acceptance of anything.
