# ZK60 native private attention — review R-2 (arithmetic)

| | |
|---|---|
| Reviewer | Claude Opus 5 (1M), arithmetic review lane, 2026-09-18 |
| Worktree | `/home/victor/wt-zk60-attention-compile` (read-only review; no `git`, no `cargo`, no proof run) |
| Request answered | R-2 of `ZK60_PRIVATE_ATTENTION_NATIVE.md` §6: re-derive the no-wraparound bounds of §2, the isqrt / softmax exactness arguments, and check that every slot polynomial has a public factor in every monomial |
| Sources read | `hashline/src/private_attention/{layout,witness,argument,protocol}.rs`, `hashline/src/private_attention.rs`, `hashline/src/causal_oracle.rs`, `hashline/src/norm.rs`, `hashline/src/export_v3.rs`, `hashline/src/tables_attn.rs`, `hashline/src/private_seam.rs`, `zkp-core/src/{sumcheck,mle,field}.rs`, `hashline/src/zk.rs`, `private-block-kernel/src/lib.rs` |
| Evidence | `results/zk60_private_attention_native_evidence/r2_review/` (five Python scripts + their outputs) |
| Not in scope | R-1 (pair-schedule rank, CFS slot check), privacy/simulation (D8/D11, the joint-view gate), performance, the PCS and sumcheck machinery themselves, composition with `norm_m` / the FFN |

**Scope caveat, stated once.** This is a review of the source as written; I ran
no `cargo`, no proof and no `git`, and modified nothing outside my two lane
paths. The note's header says the delivery was never compiled — that is no
longer true of this worktree: a sibling compile lane has since built it and run
its tests, recording the result at
`results/zk60_private_attention_native_evidence/compile/report.json` (compiled
on the first invocation with zero source changes; 11 unit + 4 integration + 1
doc test and the example's prove/verify pair all passed). I read that evidence
but did not produce it, and nothing in my three parts depends on it; where it
bears on a conclusion (§2.6) it is cited as the other lane's result.

**Verdicts.**

| Part | Verdict |
|---|---|
| 1. No-wraparound | **HOLDS.** Every constrained integer expression is bounded by 2⁴⁹ from the enforced ranges alone; the note's "< 2⁵²" claim is true with ≥ 2³ slack on the worst expression and 2¹⁴ slack to p/2. Every byte-limb decomposition is *exact* (representable set = claimed window), including the signed windows. Four documentation-level imprecisions flagged (F1, F2, F7, F8); no soundness gap found. |
| 2. isqrt / softmax exactness | **HOLDS for every committed value.** `D = isqrt(ss)` is pinned uniquely; the causal softmax's `max`, `E`, `Sum`, `p`, `ρ`, `σ` are pinned exactly, ties included, and the off-support `p = ρ = 0` case is forced. **One documented relaxation:** the *position* of the one-hot selector is pinned only to "some attainer of the max", not to the kernel's first attainer; no committed value depends on it. Witness builder vs `FixedCausalOracle`: six items compared, none divergent — four cosmetic, two unreachable (§2.6). |
| 3. Extension-round premise | **HOLDS for all 18 slots, mechanically verified.** Every monomial of every slot polynomial contains a factor that is zero in the round's extension vector; the two bilinear slots (score, PV) are exactly the two that need the second extension variable, and they have it. Max degree equals the declared degree in all 18 slots. |

---

## 0. Method: what "enforced" means, and why the bound has to be taken that way

A no-wraparound argument is only worth anything if it is taken over the ranges
the **verifier enforces**, not the ranges an honest prover happens to produce.
Every bound in Part 1 is therefore the maximum of |expression| over the ranges
the relation itself pins, so it holds for any witness the verifier accepts,
honest or not.

Two structural facts make that framing legitimate, and I checked both:

1. **Every relation reduces to a per-entry integer equation.** Each constraint
   is either (a) a zero-check `Σ_x eq(τ, x)·zc(x)` with τ a fresh challenge
   (`argument.rs:526, 543, 615, 654, 695, 735, 756`), which gives `zc(x) = 0` at
   every boolean `x` with high probability, or (b) a host relation in which a
   hosted private slot's claimed sum and the host's own term are both the
   multilinear extension *of the same function of the same free indices*,
   evaluated at one fresh random point. I verified case (b) for all six hosted
   slots by writing out both sides:
   * `01 SS` ↔ `02 TZC` at `r_t` — `S_SS = (Σ_i x(t,i)²)~(r_t)` against
     `(D² + a1 − ceps)~(r_t)`, κ = 1 (`argument.rs:537`, `HOSTS` `layout.rs:372`);
   * `09Q/09K/09V` ↔ `04 QZC`/`05 KVZC` at `pq`/`pk`/`pv` — `S = acc~(point)`
     because `fold_rows_i8(w, outer, D, eq(r_j))[i] = Σ_j eq(r_j,j)·W[j,i]`
     (`zkp-core/src/mle.rs:116-131`), so `Σ_i y~(r_q,i)·Wfold(i)` is exactly
     the MLE of `acc(t,j) = Σ_i y(t,i)W[j,i]` at `(r_q, r_j)`;
   * `10 score` ↔ `06 SZC` at `p_s`, `11 PV` ↔ `04 QZC` at `p_o`,
     `12 Wo` ↔ `03 DZC` at `p_a` — same bilinear factorisation;
   * `07 row sums` ↔ `06 SZC` at `p_ht` with **κ = 32** because the host term
     `Sum + λ` is constant in `j` and the host domain sums over all 32 `j`
     (`argument.rs:708`; declared in `NATIVE.md:55`). I checked the factor: the host side
     sums to `T·(Sum~(p_ht) + λ)`, and `hosted = [(SC_RS, ν₀·T), …]` supplies
     exactly that `T`. **Correct.**
   Since the batching coefficients `ν` are fresh and refused when zero
   (`argument.rs:471-477`), the zero-check part and each host part separate with
   high probability. — PROVED-BY-INSPECTION.

2. **Every plane that enters an integer expression has an enforced bound.**
   `layout_counts.py` lists the twelve planes with no direct range lookup;
   each one is pinned by a relation instead, and I traced each chain
   (§1.2). None of the chains is circular: the two that go through lookups
   (`A_E`, and `A_MX` through the exp lookup) rely on the LogUp argument, which
   is a pure field argument and does not itself need an integer bound.

**LogUp premise (assumed, standard).** Everything that rests on a lookup
assumes the usual Haböck soundness: multiplicities are committed before the
challenge. I checked the ordering structurally — `m_u8`/`m_exp` are written
into `A` (`protocol.rs:275-291`) and `A`'s root is absorbed
(`protocol.rs:300`) **before** `β, γ, α` are drawn (`protocol.rs:310-312`), and
`H` is committed after. The single value-0 sum claim covers every helper plane
with `+1` and the two table helpers with `−1`, plus the zero-sum pair `u`
(`protocol.rs:47-58`), and slot `ZS` proves `Σ u = 0` (`argument.rs:748-753`).
The degenerate branch — `α` equal to a lookup tag makes `h·d1·d2 = d1 + d2`
satisfiable with `d1 = d2 = 0` and arbitrary `h` — has probability
≤ 47104/|Fp2| ≈ 2⁻¹¹², and the prover refuses it outright
(`protocol.rs:221-225`). — PROVED-BY-INSPECTION (structure), premise cited not
re-proved.

---

## 1. No-wraparound

### 1.1 The byte-limb range decompositions are exact

The note's rule is "a `b`-bit value is byte limbs plus `2^(8 − b mod 8)·top ∈ U8`;
`[−127,127]` is `v+127 ∈ U8 ∧ 127−v ∈ U8`" (`NATIVE.md:48`, implemented by
`layout.rs:185-195` and `layout.rs:221-260`). I enumerated the **full
representable set** of each pattern and compared it with the claimed window.

| pattern | source | representable | claimed | verdict |
|---|---|---:|---:|---|
| int16 = `l0 + 256·l1 − 32768` | `lookups(Dom::D)` `layout.rs:226, 232` | `[−32768, 32767]` | same | EXACT |
| `sym()`: `v+127, 127−v ∈ U8` | `layout.rs:193-195` | `[−127, 127]` (255 values) | same | EXACT |
| norm `ρ, σ`: 4 limbs, `8·l3 ∈ U8` | `layout.rs:229, 231` | `[0, 2²⁹)` | `[0, 2²⁹)` | EXACT |
| `D, a1, a2`: 3 plain byte limbs | `witness.rs:123-127`, `argument.rs:534-535` | `[0, 2²⁴)` | `[0, 2²⁴)` | EXACT |
| requant `sh=7`: `l, 2l ∈ U8`, `r = l − 64` | `layout.rs:232, 236, 238, 245, 247, 248` | **`[−64, 64)`** | `[−64, 64)` | EXACT |
| requant `sh=6`: `l, 4l ∈ U8`, `r = l − 32` | `layout.rs:252` | `[−32, 32)` | `[−32, 32)` | EXACT |
| requant `sh=9`: `l0, l1, 128·l1 ∈ U8`, `r = l0 + 256l1 − 256` | `layout.rs:240` | `[−256, 256)` | `[−256, 256)` | EXACT |
| softmax `ρ_s, σ_s`: `l0, l1, 4·l1 ∈ U8` | `layout.rs:254-255` | `[0, 2¹⁴)` | `[0, 2¹⁴)` | EXACT |
| softmax `p`: `l0, l1, 64·l1 ∈ U8` | `layout.rs:253` | `[0, 2¹⁰)` | `[0, 2¹⁰)` | EXACT |
| plain byte (`A_LIMB`) | `layout.rs:224` | `[0, 256)` | `[0, 256)` | EXACT |

— COMPUTED, `limb_windows.py` → `limb_windows.out` ("ALL DECOMPOSITIONS EXACT").
"Exact" here is set equality in both directions: nothing inside the window is
unrepresentable and nothing outside it is representable. The signed windows the
request singled out (`r ∈ [−64, 64)`) are exact, brute-forced.

One arithmetic detail that the pattern depends on and that holds: `scaled(p, k)`
constrains `k·v` **in Fp**, but with `v ∈ [0,256)` already forced by the
companion `byte(p)` lookup, `k·v ≤ 255·128 = 32640 ≪ p`, so the field constraint
is the integer constraint. — PROVED-BY-INSPECTION.

### 1.2 The twelve planes with no direct lookup, and what pins them

| plane | pinned by | resulting bound |
|---|---|---|
| `A_X`, `A_AO`, `A_X1` | `c2`, `c3`, `c4` of `03 DZC` (`argument.rs:634-636`) | int16, exact |
| `A_D` | `mu1` of `02 TZC`, `d = l0+256l1+65536l2` (`argument.rs:536`) | `[0, 2²⁴)`, exact |
| `A_DSQ` | `mu0`, `dsq = d·d` (`argument.rs:536`) | `< 2⁴⁸` |
| `A_SUM` | `c3` of `06 SZC`, `Sum = σ + ρ + 1` (`argument.rs:719`) | `[1, 2¹⁵−1]` locally; `≤ 2¹⁴` through §2.4 |
| `A_P` | `c4` of `06 SZC` (`argument.rs:720`) + the `PL` limbs | `[0, 2¹⁰)`, exact |
| `A_ZSEL` | `c0 = zsel² − zsel` (`argument.rs:716`) | `{0,1}` in Fp, exact |
| `A_E` | the two-column exp lookup `cx` (`argument.rs:721`) + the public table validation (`private_attention.rs:98-100`) | `[0, 2⁹]` |
| `A_MX` | **derived**: the exp lookup forces `δ = MX − masked_j ∈ [0,256)` for every `j` (`argument.rs:715, 721`) | `[−127, 382]` |
| `A_MU8`, `A_MEXP` | nothing (multiplicities) | field elements; enter only field relations |

The `A_MX` entry is the only bound in the whole relation that is not local: it
comes out of a lookup rather than a limb decomposition. It is sound (LogUp does
not need `MX` bounded to work), but it means the no-wraparound argument cannot
be read off the lookup table alone. Flagged F7 below. — PROVED-BY-INSPECTION.

### 1.3 The bound of every constrained integer expression

`wraparound_bounds.py` → `wraparound_bounds.out` computes, term by term, the
maximum of |expression| over the enforced ranges. Abridged (full table in the
output file):

| expression | where | bound | vs 2⁵² |
|---|---|---:|---|
| `D² + a1 − ceps − Σ_i x_i²` | `argument.rs:536-537` | `2.81·10¹⁴ < 2⁴⁹` | OK |
| `Dsq − D·D` | `argument.rs:536` | `5.63·10¹⁴ < 2⁴⁹` | **worst case** |
| `D − (l0+256l1+65536l2)` | `argument.rs:536` | `< 2²⁵` | OK |
| `2D − a1 − a2` | `argument.rs:536` | `< 2²⁶` | OK |
| `2·cn·γ·x + 2^tn·D − 2^(tn+1)·y·D − ρ` | `argument.rs:632` | `8.77·10¹² < 2⁴³` | OK |
| `σ + ρ + 1 − 2^(tn+1)·D` | `argument.rs:633` | `< 2³⁷` | OK |
| `v + 32768 − (l0+256l1)` (x, ao, xres1) | `argument.rs:634-636` | `< 2¹⁷` | OK |
| `xres1 − x − ao` | `argument.rs:637` | `< 2¹⁷` | OK |
| QKV accumulator `Σ_i y·W` | `witness.rs:160-162` | `260096 < 2¹⁸` | OK |
| QKV host `acc − (2⁷q8 + rql − 64)` | `argument.rs:679, 683` | `< 2¹⁹` | OK |
| RoPE `C·x + S'·x_partner − 2⁷·xr − r` | `argument.rs:675` | `48832 < 2¹⁶` | OK |
| score accumulator `Σ_{i<8} qr8·kr8` | `witness.rs:171` | `129032 < 2¹⁷` | OK |
| score host `acc − (2⁶s8 + rsl − 32)` | `argument.rs:727` | `< 2¹⁸` | OK |
| softmax `δ = MX − mask(s8+127) + 127` | `argument.rs:715` | `763 < 2¹⁰` | OK |
| softmax `c2 = 2⁹·mask·E − p·Sum − ρ_s` | `argument.rs:718` | `33 799 168 < 2²⁶` | OK |
| softmax `c3 = σ + ρ + 1 − Sum` | `argument.rs:719` | `< 2¹⁶` | OK |
| PV accumulator `Σ_j p·v8` | `witness.rs:233` | `4 157 472 < 2²²` | OK |
| PV host `acc − (2⁹o8 + ro − 256)` | `argument.rs:680` | `< 2²³` | OK |
| Wo accumulator, Wo host | `witness.rs:238`, `argument.rs:642` | `< 2²³` | OK |
| IO equality `x − endpoint` | `argument.rs:759` | `< 2¹⁷` | OK |
| LogUp multiplicities | `protocol.rs:275-288` | `47104`, `2048` | OK |

**Worst case over all expressions: 562 949 886 312 450 < 2⁴⁹**, i.e. 2³ below
the note's 2⁵² claim and 2¹⁴ below p/2. Nothing exceeds the claim; nothing was
left unbounded. — COMPUTED.

The note's two stated intermediate bounds check out as well:
`D² + a1 ≤ 281 474 959 933 440 < 2⁴⁸` (the comment says `< 2⁴⁹` — true, one bit
loose) and `Σx² + ceps ≤ 17 179 869 185 < 2³⁵` (the comment says `< 2³⁵` —
tight). `|2·cn·γ·x| ≤ 2³³` (the comment says `< 2³⁴` — true).
`y·D·2^(tn+1) < 2⁴³` (the comment says `< 2⁴⁴` — true). The comment's "the
matmul accumulators are below 2²⁵" is true with room: the largest is PV at
`< 2²²`. — COMPUTED.

**The one tight spot.** `layout.rs:213` claims `p·Sum + ρ < 2²⁵`. From the
*local* limb bounds alone (`p ≤ 1023`, `Sum = σ+ρ+1 ≤ 32767`, `ρ ≤ 16383`) the
maximum is `33 537 024` against `2²⁵ = 33 554 432` — it holds, with a margin of
**17 408**, i.e. 0.05 %. This is the only place in the relation where the
declared bound is not comfortable, and it is comfortable enough only because
`Sum` is capped twice over (§2.4 shows `Sum ≤ 2¹⁴` is in fact enforced, which
restores a factor of 2). Not a defect; worth knowing before anyone widens
`WRHO_S` or the `p` window. — COMPUTED.

**A bound the note does not claim but the relation gives for free:** `c1`
(`argument.rs:633`) forces `D·2^(tn+1) = σ + ρ + 1 ≤ 2³⁰ − 1`, so
`D ≤ 262 143 < 2¹⁸`, far tighter than the 2²⁴ limb bound. (This holds per `(t,i)`
and there are 16 entries per row, so it binds every row.) — COMPUTED.

### 1.4 Supporting counts

`layout_counts.py` reproduces, from the declared geometry, the note's §5
numbers: **47 104 U8 lookups** and **2 048 exp lookups** (both match), helper
counts per domain 1/10/7/6/7 (all match `layout::helpers`), A data rows **154**
and A rows **306**, H data rows **218** and H rows **290** (all match both the
note and `layout.rs`'s own test). — COMPUTED.

### 1.5 Part 1 verdict

**The no-wraparound premise of `NATIVE.md` §2 and `layout.rs:200-220` holds.**
Every constrained integer expression stays below 2⁴⁹ ≪ 2⁵² ≪ p/2 under the
enforced ranges, and every byte-limb decomposition is exact. No expression was
left unbounded, and none exceeds the claim.

---

## 2. isqrt and softmax exactness

### 2.1 `D = isqrt(ss)` is pinned uniquely

The three constraints are `Dsq = D·D` (`mu0`), `a1 = ss − Dsq ≥ 0` (through the
host identity `dsq + a1 − ceps = Σx²`, `argument.rs:537`) and
`a2 = 2D − a1 ≥ 0` (`mu2`), with `D, a1, a2` all three-byte-limbed and hence
non-negative integers below 2²⁴.

Argument: `a1 ≥ 0` gives `D² ≤ ss`; `a2 ≥ 0` gives `ss − D² ≤ 2D`, i.e.
`ss ≤ D² + 2D < (D+1)²`. The intervals `[D², (D+1)²)` for `D = 0, 1, 2, …`
partition the non-negative integers, so exactly one `D` satisfies both, and it
is `floor(sqrt(ss))`. `ceps = 1` makes `ss ≥ 1` (every `x` is an integer by
§1.1, so `Σx² ≥ 0`), which rules out `D = 0` and therefore makes the norm
denominator `D·2^(tn+1)` nonzero — the fact the division identity needs.
— PROVED-BY-INSPECTION, and exhaustively confirmed for `ss ∈ [0, 200000]`:
zero rows where `{D : D² ≤ ss ≤ D² + 2D} ≠ {isqrt(ss)}` (COMPUTED,
`isqrt_softmax.py` (b)).

All three quantities stay integral: `D < 2²⁴` so `D² < 2⁴⁸`, and
`D² + a1 < 2⁴⁹ ≪ p`, so the field equations are integer equations (§1.3).

Separately, the *builder's* `isqrt` (`witness.rs:26-43`) is character-identical
to `private-block-kernel/src/lib.rs:324-343`, and both agree with an exact
integer square root on 663 222 test values spanning the whole reachable range
`[0, 16·32768² + 1]` — all of `0..70000`, every perfect square and its two
neighbours, and 200 000 random values — as does `norm.rs:156-169`, the float-seeded
variant the oracle uses. Zero disagreements. — COMPUTED,
`isqrt_softmax.py` (a).

### 2.2 The rounded-division identity pins `y`

`c0` (`argument.rs:632`) is `2·cn·γ·x + D·2^tn − y·D·2^(tn+1) − ρ = 0` and `c1`
(`argument.rs:633`) is `σ + ρ + 1 = D·2^(tn+1)`. With `ρ, σ ≥ 0` (limbs), `c1`
gives `0 ≤ ρ ≤ den − 1` where `den = D·2^(tn+1) > 0`, so `y` is the unique
floor quotient of `num = 2·cn·γ·x + D·2^tn` by `den` — which, since `num` is
the numerator shifted by half the denominator, is round-to-nearest-ties-up.
This is exactly `witness.rs:135-137` (`div_euclid`/`rem_euclid`),
`causal_oracle.rs:619-624` and `norm.rs:141-147`. The separate
`y ∈ [−127, 127]` is the `sym()` lookup. — PROVED-BY-INSPECTION.

The requantisation identity is the same shape: `acc = 2^sh·q + r` with
`r ∈ [−2^(sh−1), 2^(sh−1))` pins `q = floor((acc + 2^(sh−1))/2^sh)` uniquely,
which is `requant` (`witness.rs:45-49`, `export_v3.rs:296-305`,
kernel `lib.rs:298-309`). The biased-limb windows are exact (§1.1), so the
constraint window is exactly the kernel's. — PROVED-BY-INSPECTION.

### 2.3 The causal softmax: what is pinned

Working from the `06 SZC` polynomial (`argument.rs:710-729`) and the `07` row-sum
slot (`argument.rs:548-557`):

1. **`δ ∈ [0, 256)` and `E = exp[δ]`.** The single-lookup helper `cx`
   (`argument.rs:721`) forces the tag `δ + β·E + g_exp` to be a value of the
   two-column exp table `i + β·exp[i] + g_exp` (`argument.rs:502-506`). `δ` and
   `E` are functions of planes committed in `A` before `β` is drawn
   (`protocol.rs:296-302`), so `δ = i` and `E = exp[i]` separately, with high
   probability over `β`. Hence `δ` is an integer in `[0,256)` and `E` is a table
   entry, which the public validation constrains to `[0, 2⁹]` with `exp[0] = 2⁹`
   and monotone (`private_attention.rs:98-100`).
2. **`zsel` is one-hot.** `c0` makes it a field root of `X² − X`, i.e. `{0,1}`;
   the row-sum slot's `λ`-term plus the host relation forces `Σ_j zsel = 1` per
   `(h,t)`. Specifically the host identity at `(p_ht, λ)` reads
   `Sum~(p_ht) + λ = (Σ_j mask·E)~(p_ht) + λ·(Σ_j zsel)~(p_ht)`; `λ = lam_z` is a
   fresh challenge drawn at slot 03 (`argument.rs:550`) before `p_ht` is used
   anywhere else, so the two `λ`-coefficients separate and give both
   `Sum = Σ_{j≤t} E` **and** `Σ_j zsel = 1`, for every `(h,t)`.
3. **`MX` is the masked maximum.** `δ_j = MX − masked_j ≥ 0` for every `j` (from
   1), so `MX ≥ masked_j` for all `j`; `c1 = zsel·δ = 0` with `zsel` one-hot
   puts `δ = 0` at the selected position, so `MX = masked_{j*}`. Therefore
   `MX = max_j masked_j` exactly, where `masked_j = mask·(s8+127) − 127` is
   `s8_j` on the support and `−127` off it (`argument.rs:715`; `MASK_SCORE = −127`,
   `layout.rs:52`). **Ties:** any attainer gives the same `MX`, hence the same
   `δ`, `E`, `Sum` and `p`.
4. **`Sum > 0`.** `c3` gives `Sum = σ + ρ + 1` with `σ, ρ ≥ 0`, so `Sum ≥ 1`.
   (The layout comment's route — some supported position has `δ = 0`, so
   `E = exp[0] = 2⁹` and `Sum ≥ 2⁹` — is also valid, and I checked its awkward
   case: if the selector sits on a *masked* position then `MX = −127` and every
   supported score equals `−127`, so `δ = 0` there too.)
5. **The division.** `c2 = 2⁹·mask·E − p·Sum − ρ = 0` with `0 ≤ ρ ≤ Sum − 1`
   (from `c3` and `σ ≥ 0`) pins `p = floor(2⁹·E/Sum)` and `ρ` uniquely on the
   support. 200 000 random `(E, Sum)` pairs: zero rows where the pair is not the
   unique floor quotient. — COMPUTED, `isqrt_softmax.py` (c).
6. **Off the causal support** `mask = 0`, so `c2` becomes `p·Sum + ρ = 0` with
   `p, ρ ≥ 0` and `Sum ≥ 1`, forcing `p = ρ = 0`; `c3` then gives `σ = Sum − 1`,
   matching the witness (`witness.rs:214-219`) and the oracle's `sigma_fact`
   (`causal_oracle.rs:357`). Zero counterexamples over the same 200 000 rows.
   — COMPUTED. This is what makes the PV slot's sum over **all** `j`
   (`argument.rs:586-596`) equal the kernel's sum over `j ≤ t`.

**What is NOT pinned: the selector's position.** The constraints require `zsel`
to sit on *some* attainer of the maximum; the kernel picks the *first*
(strict `>` in `lib.rs:456-462`, `causal_oracle.rs:317-324`, `witness.rs:184-190`).
In the tie case a different attainer satisfies the relation equally, and when
every supported score is `−127` the selector may legally sit on a masked
position `j > t` — which the kernel's builder would never produce, and whose
own `arg > t` refusal is in fact unreachable (see F4a). `layout.rs:214-217`
already records this. **No committed value changes**: `MX`, `E`, `Sum`, `p`, `ρ`,
`σ`, `o8` and `xres1` are identical for any choice of attainer, verified over
20 000 random rows (COMPUTED, `isqrt_softmax.py` (d)). So the relation proven is
"the causal softmax of the committed scores", output-identical to the kernel's;
only the witness's selector index is under-determined, and it feeds nothing but
`c0`, `c1` and the row-sum `λ` term.

### 2.4 `Sum ≤ 2¹⁴` is enforced (with a longer chain than the note implies)

`layout.rs:213` asserts `Sum ≤ 2¹⁴` when bounding `p·Sum + ρ`. Locally — from the
`σ`/`ρ` limbs and `c3` alone — only `Sum ≤ 2¹⁵ − 1` follows. The 2¹⁴ bound *is*
enforced, but through a different route: the row-sum host relation gives
`Sum = Σ_{j≤t} E`, at most 32 terms; the exp lookup plus the public table
validation puts each `E ∈ [0, 2⁹]`; `32·2⁹ = 2¹⁴ < p`, so the field sum is the
integer sum and `Sum ≤ 2¹⁴`. Worth stating in the comment because the weaker
local bound is what a reader checking `p·Sum + ρ < 2²⁵` will reach for, and it
leaves only 0.05 % margin (§1.3). — PROVED-BY-INSPECTION + COMPUTED.

### 2.5 The `p` window is one bit wider than the kernel's, necessarily

The constraint admits `p < 2¹⁰`; the kernel and oracle refuse `p > 2⁹`
(`lib.rs:491`, `causal_oracle.rs:359`). This is not slack that a prover can
exploit: on the support `Sum = Σ_{j≤t} E ≥ E_j` (all `E ≥ 0`), so
`p = floor(2⁹E/Sum) ≤ 2⁹` always. Nor is it fixable by tightening the limb
pattern: `p = 512` is *attained* (any row with a single supported position,
e.g. every `t = 0` row, has `E = Sum`), so the window must contain 512, and the
next tighter byte-limb cap (`128·l1 ∈ U8` → `l1 ≤ 1` → `p ≤ 511`) would break
completeness. `64·l1` is the correct choice. Recording it so nobody "fixes" it.
— PROVED-BY-INSPECTION.

### 2.6 Witness builder vs `FixedCausalOracle` / the kernel — the differences

I compared `witness.rs:103-273` line by line against `causal_oracle.rs:271-400`
and `private-block-kernel/src/lib.rs:382-612`. The arithmetic is a faithful
transcription: `isqrt` is character-identical to the kernel's; `requant` matches
`export_v3::requant_round` for `sh > 0` and the `sh = 0` residual path
(`requant_round` returns `acc·1` with zero remainder, which is exactly
`x1 = x + ao`); `rotate`, `matmul_out_in`, the score loop, `softmax_row` and every
refusal window and site string line up; and all calibration constants agree
(`layout.rs:39-52` vs the registration at `causal_oracle.rs:84-158` and
`lib.rs:61-89`). The `kvo = (h/group)·DH` offset in the kernel is 0 at
`H = 2, HKV = 1`, so `kr[j·KV + kvo + i]` is the witness's `kr8[j·KV + i]`.
Differences found:

| # | difference | consequence | severity |
|---|---|---|---|
| a | `witness.rs:118` adds a refusal `D ≥ 2²⁴ ∨ a1 ∉ [0,2²⁴) ∨ a2 ∉ [0,2²⁴)` that neither the oracle nor the kernel has | **unreachable**: for any i16 input, `ss ≤ 2³⁴+1` so `D ≤ 131 072`, `a1 ≤ 2D ≤ 262 144`, `a2 ∈ [0, 2D]` (COMPUTED) | cosmetic |
| b | `witness.rs:231-237` quantises `oacc` in `(t,h,i)` order; the oracle/kernel use `(h,t,i)` then scatter | a different element is reported first when several are out of range; same site string `"O"`, same accept/refuse verdict | cosmetic |
| c | the oracle leaves `sig_s = 0` off the causal support while the witness stores `σ = Sum − 1` there | the oracle's own comment (`causal_oracle.rs:352-354`) says `attention::pack` reconstructs `Sum−1−ρ` on all positions, and its range check computes `sigma_fact` for all `j` — the two agree at the level the proof uses | none (documented equivalence) |
| d | `Witness::output()` (`witness.rs:20-22`) re-checks the i16 range with a different message | dead check; `witness.rs:243-245` already refused | cosmetic |
| e | the rope and exp tables come from the caller (`AttentionPublic`), structurally validated (`private_attention.rs:88-101`) but never tied to `rope_tables_generate(T, DH, 10000.0, 7)` / `exp_member(0, DH, 9)` | "same semantics as the oracle" holds only for a caller supplying the oracle's tables; the statement digest binds them, and the module states that structure is not provenance (`private_attention.rs:64-67`) | cosmetic (by design) |
| f | `witness.rs:192` refuses `arg > t` ("causal maximum attainment"), inherited from the kernel | **unreachable in all three**: `s8 ∈ [−127,127]` is enforced before the softmax, so `masked(0) ≥ −127` and no masked position can beat it | cosmetic |

The unit test `witness_equals_the_independent_fixed_causal_oracle`
(`tests.rs:29-64`) compares sixteen planes plus three remainder-limb
reconstructions against the oracle. It is well chosen, and the compile lane
reports it **passing** on the public synthetic fixture
(`results/zk60_private_attention_native_evidence/compile/unit1.log`) — which is
empirical confirmation, on one input, that differences (a)-(f) are
non-divergent. It is one fixture, not a proof of parity over all inputs; the
arguments above are what cover the rest.

### 2.7 Part 2 verdict

**Both exactness arguments hold.** `D = isqrt(ss)` is uniquely pinned; the
causal softmax is pinned exactly for every committed value including ties and
the off-support case; the witness builder is a faithful transcription of the
kernel's semantics with no reachable divergence. The single relaxation — the
selector position — is documented, harmless, and named above.

---

## 3. The extension-round premise

### 3.1 What exactly has to vanish

From `zkp-core/src/sumcheck.rs:297-314` and `hashline/src/zk.rs:984-999`: after
the `n` main rounds, extension round `m` sends
`s(X) = poly((1−X)·finals + X·exts) + c·g(X)`, where `exts[t]` is the reserved
pair's evaluation for a private table with `ext_round == m` and **zero for every
other table**, public tables included (`argument.rs:280-287`). The verifier's
check `s(0) + s(1) = (previous round at its challenge)` splits into a mask half,
consistent by construction because `mask_specs()` builds `g` over `n + ext`
variables (`layout.rs:395-397`, `CfsMask::sum_weights` `sumcheck.rs:222-227`), and
a data half that requires

> **`poly(exts) = 0`** — every monomial of the slot polynomial must contain at
> least one table that is zero in the round-`m` extension vector: a public table
> (`Tab::Eq` / `Tab::Pub`), or a private table in a *different* extension round.

A monomial made only of round-`m` private tables, or a bare constant, breaks it.
This is precisely the premise stated at `argument.rs:17-22`, and it matches the
construction's rule (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:47`: one extension
round where the public factor extends to zero, two for the bilinear slots).

I also confirmed the bookkeeping that follows from it: the folded data
coefficient is `cd = Π_m (1−e_m)` and the mask coefficient for a round-`r` table
is `e_r·Π_{m>r}(1−e_m)`, which is exactly `argument.rs:336-340`; and the
verifier multiplies every public table by `sel = Π(1−e_m)` (`argument.rs:310-318`),
consistent with folding against a zero extension.

### 3.2 The eighteen slots

Transcribed all eighteen polynomials of `argument::define` into an exact
multivariate polynomial over the table indices (each challenge/constant given
its own random field value so nothing cancels by accident), expanded them, and
tested every monomial against every extension round.

| slot | tables (public → private) | monomials | deg | zeroing factor | premise |
|---|---|---:|---:|---|---|
| 00 `01 SS` | `eq(r_t)` → `A_X` | 1 | 3 | `eq(r_t)` | VANISHES |
| 01 `02 TZC` | `eq(τ)`, `eq(r_t)` → `A_D`, `A_DSQ`, 9×`A_LIMB` | 17 | 3 | `eq(τ)` on the zero-check, `eq(r_t)` on the host term | VANISHES |
| 02 `08 LZC` | `eq(τ)` → `A_LIMB`, `H_L` | 3 | 3 | `eq(τ)` (incl. the `−1` constant of the helper relation) | VANISHES |
| 03 `07 row sums` | `eq(p_ht)`, causal mask → `A_E`, `A_ZSEL` | 2 | 3 | `eq(p_ht)` | VANISHES |
| 04/05/06 `09Q/K/V` | folded `W` → `A_Y` | 1 | 2 | the folded public weight | VANISHES |
| 07 `10 score` | **none** → `A_QR8`(r0), `A_KR8`(r1) | 1 | 2 | round 0: `A_KR8 = 0`; round 1: `A_QR8 = 0` | VANISHES |
| 08 `11 PV` | **none** → `A_P`(r0), `A_V8`(r1) | 1 | 2 | round 0: `A_V8 = 0`; round 1: `A_P = 0` | VANISHES |
| 09 `12 Wo` | folded `Wo` → `A_O8` | 1 | 2 | the folded public weight | VANISHES |
| 10 `03 DZC` | `eq(τ)`, `eq(p_a)`, γ table → 20 A + 10 H | 63 | 4 | `eq(τ)` / `eq(p_a)` | VANISHES |
| 11 `04 QZC` | `eq(τ)`, `eq(pq)`, `eq(p_o)`, C, S' → 8 A + 7 H | 38 | 4 | `eq(τ)` / `eq(pq)` / `eq(p_o)` | VANISHES |
| 12 `05 KVZC` | `eq(τ)`, `eq(pk)`, `eq(pv)`, C, S' → 7 A + 6 H | 33 | 4 | as above | VANISHES |
| 13 `06 SZC` | `eq(τ)`, `eq(p_ht)`, `eq(p_s)`, causal mask → 13 A + 8 H | 51 | 4 | `eq(τ)` / `eq(p_ht)` / `eq(p_s)` | VANISHES |
| 14 `TAB` | `eq(τ)`, U8 table, exp table → 2 A + 2 H | 6 | 3 | `eq(τ)` | VANISHES |
| 15 `ZS` | all-ones → `H_U` | 1 | 2 | the all-ones table | VANISHES |
| 16/17 `IO` | `eq(τ)` → `A_X`/`A_X1`, endpoint | 2 | 2 | `eq(τ)` | VANISHES |

**No monomial anywhere is a product of private factors only, and no slot has a
bare constant term.** The two slots with no public factor at all — `10 score`
and `11 PV`, exactly the two the construction flags because `eq_g ≡ 1` at
KV-heads = 1 leaves nothing to extend — are exactly the two carrying a second
extension variable (`layout.rs:326-327`: `(3,2,2)` and `(5,2,2)`), and the
assignment is the right one: the two private factors sit in *different* rounds
(`argument.rs:570, 573` and `argument.rs:589, 593`), so each round's extension
vector zeroes one of the two. — COMPUTED, `extension_premise.py` →
`extension_premise.out` ("PREMISE HOLDS FOR ALL 18 SLOTS").

Two by-products of the same script, both clean:
* **Degree.** The expanded maximum degree equals the declared sumcheck degree in
  all eighteen slots (`layout.rs:319-338`). A polynomial exceeding its declared
  degree would silently break the sumcheck; none does. The degree-4 slots reach
  4 only through `eq · h · d1 · d2` in the LogUp helper relation (and, in
  `06 SZC`, `eq · h_exp · mask · s8`), as intended.
* **Site counts.** The number of private tables per slot equals
  `A_SITES[s] + H_SITES[s]` (+1 endpoint for the two IO slots) in all eighteen
  — the same invariant `run_slot` checks at runtime (`argument.rs:248-250`) and
  `B::finish` checks at build time (`argument.rs:431-437`).

### 3.3 Part 3 verdict

**The premise stated at the top of `argument.rs` holds for every slot and every
extension round**, by construction of `define` rather than by accident: every
zero-check slot wraps its whole constraint bundle in `v[0] = eq(τ)` and each
host term in its own `eq`, and the four matmul slots carry the folded public
weight. The one structural risk the premise warns about — "a new term without a
public factor" — is real for the two bilinear slots and is handled by the second
extension variable, not by luck.

---

## 4. Flagged items

| id | item | location | severity | note |
|---|---|---|---|---|
| F1 | `Sum ≤ 2¹⁴` is asserted as if local; the local limb bounds only give `Sum ≤ 2¹⁵−1`. The claim is true but needs the row-sum host relation plus the public exp-table validation | `layout.rs:213` | cosmetic | `p·Sum + ρ < 2²⁵` holds either way; margin 17 408 under the weaker bound (§1.3, §2.4) |
| F2 | The enforced `p` window `[0, 2¹⁰)` is one bit wider than the kernel's `p ≤ 2⁹` | `layout.rs:253` vs `lib.rs:491` | cosmetic | not exploitable (`Sum ≥ E` forces `p ≤ 2⁹`) and not tightenable: `p = 512` is attained at `t = 0` (§2.5). Do not "fix" |
| F3 | The one-hot selector is pinned to *an* attainer of the max, not the kernel's first attainer; in the all-tied-at-`−127` case it may legally sit at `j > t` | `argument.rs:716-717`, documented `layout.rs:214-217` | cosmetic | no committed value depends on it (§2.3, COMPUTED over 20 000 rows) |
| F4a | Extra refusal in the witness with no kernel counterpart | `witness.rs:118` | cosmetic | unreachable for i16 inputs |
| F4b | `arg > t` refusal is unreachable in all three implementations | `witness.rs:192`, `causal_oracle.rs:326`, `lib.rs:463` | cosmetic | dead branch, harmless |
| F5 | O-requantisation iterates in a different element order from the oracle/kernel | `witness.rs:231-237` | cosmetic | changes only which element is named first on a refusal |
| F6 | Rope/exp tables are caller-supplied and only structurally validated | `private_attention.rs:88-101` | cosmetic (by design) | kernel-semantics parity is conditional on the caller's tables; already stated at `private_attention.rs:64-67` |
| F7 | `A_MX` is the only value whose integer bound comes from a lookup rather than a limb decomposition, so the no-wraparound argument is not purely local | `layout.rs` has no `Dom::Ht` lookups; bound via `argument.rs:715, 721` | cosmetic | sound but worth one line in the `layout::lookups` comment |
| F8 | `layout.rs:206-207` states `D² + a1 < 2⁴⁹`; the true bound is `< 2⁴⁸`, and `c1` independently forces `D < 2¹⁸` | `layout.rs:206-213` | cosmetic | the comment is conservative, not wrong |

**No item is blocking soundness. No item is blocking privacy.** Privacy was out
of scope for R-2 and nothing in the arithmetic touched it.

## 5. What this review did NOT check

- R-1's questions: the pair-schedule rank check and the CFS slot check for this
  layout. Untouched.
- The soundness of the underlying machinery: the sumcheck protocol, the PCS,
  `masked_prove`/`CfsMask`, `audit_claims`, the opening refusals. Assumed.
- Whether `A_GROUPS = 30` / `H_GROUPS = 8` are right (the note flags them as
  hand-counted; the prover checks them at runtime).
- The LogUp soundness theorem itself (standard result; I checked only that the
  commitment/challenge ordering and the sum-claim structure support it).
- Anything requiring execution. I ran no build and no proof. The compile
  lane's separate evidence (§ scope caveat) is cited, not reproduced.

## 6. Scripts run

All under `results/zk60_private_attention_native_evidence/r2_review/`, each with
its captured output alongside:

| script | what it computes | output |
|---|---|---|
| `limb_windows.py` | the exact representable set of each byte-limb pattern vs its claimed window (brute-forced where the space allows) | `limb_windows.out` — ALL DECOMPOSITIONS EXACT |
| `wraparound_bounds.py` | the worst-case magnitude of all 26 constrained integer expressions from the enforced ranges, vs 2⁵² and p | `wraparound_bounds.out` — worst case `< 2⁴⁹`, none over |
| `isqrt_softmax.py` | isqrt agreement (663 222 values, three implementations), `D` uniqueness (exhaustive to 200 000), the softmax division and off-support cases (200 000 rows), first-attainer equivalence (20 000 rows) | `isqrt_softmax.out` — zero disagreements in every section |
| `extension_premise.py` | all 18 slot polynomials expanded; every monomial tested against every extension round; degree and site-count cross-checks | `extension_premise.out` — PREMISE HOLDS FOR ALL 18 SLOTS |
| `layout_counts.py` | lookup/helper counts per domain, planes with no direct lookup, A/H row counts | `layout_counts.out` — 47 104 / 2 048 / 154 / 306 / 218 / 290, all match |
