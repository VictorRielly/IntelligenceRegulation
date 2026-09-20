# The complete private block at the 125M shape — independent adversarial check

INDEPENDENT ADVERSARIAL CHECK of a delegated draft — delegated Opus agent,
2026-09-19. Paper and Python only; not a privacy acceptance.

Target: `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` (1,570 lines,
commit 30f2533). Evidence under
`results/zk60_private_block_125m_check/`.

Every statement below is labelled **VERIFIED IN THE CODE** (with file:line),
**RECOMPUTED** (my own arithmetic, script named), or **COULD NOT VERIFY**.

## 0. How to read this

**The short version for the security owner.** The draft is unusually good
work: its shape, its row totals, its receipt formula, its window arithmetic
and its per-opening soundness figure all survive an independent
recomputation, and its central recommendation — grow the built single-prover
form first, do not build form E at this shape — is **strengthened**, not
weakened, by my own numbers. But it has **three defects that would have
produced a broken or unsound implementation** if the change list had been
executed as written, and a handful of smaller arithmetic errors:

1. **The pad fix is unsound as specified.** The draft's recommended "public
   support indicator on every inhomogeneous constraint" leaves the two
   row-sum slots (`SC_SS`, `SC_SSM`) summing `x²` over the *padded* width.
   Nothing then forces the padded columns of the hidden input to zero, and a
   cheating prover chooses the norm's denominator — which chooses the whole
   block's output. The alternative the draft compares against (a deliberate
   witness fill) has the **same** hole. §2.4.
2. **The construction does not instantiate at `log_cols = 14`.** The single
   LogUp sum claim spans `H` planes whose domains straddle the row width, so
   its parts no longer share one column-weight key and the module's own
   `check_opening` refuses the proof before a single byte is produced (and
   the PCS below it asserts). This is a real, cheap-to-fix blocker the draft
   does not mention at all. §3.2.
3. **The opening-group count is not 35.** It is 36, for a reason the draft
   could have found: nine limb sub-slices that collide at the toy's row
   width stop colliding at 16,384. The draft listed the group count as
   "not checked"; I checked it, and my model reproduces the toy's declared
   35 and 9 exactly first. §3.2.

The smaller errors are: the draft drops **two** redundant norm lookups where
the code has **four** (so its `H` rows, helper count and lookup total are all
slightly high); its "narrower input class" decision quotes a window of `2^27`
and two `D` limbs where the exact arithmetic gives `2^29` and three; and its
"the 8B window is unreachable" is a property of one four-limb idiom, not of
the construction. §4.

**What I did not attack.** I ran nothing: no cargo, no test, no prover, no
benchmark (the box is shared and memory-constrained). Everything below is
either read out of the source with a line number, or recomputed in exact
integer arithmetic in
`results/zk60_private_block_125m_check/recompute.py`. My predictions were
written before the arithmetic and are kept in `predictions.md`; two of them
were wrong and both are recorded where they fall (§3.3 and §2.5).

## 1. Attack on the shape (grouped-query attention)

**The draft's shape is right, source by source. VERIFIED IN THE CODE.**

* `docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md:102–106` states verbatim:
  "frugal-lm 125M (n_layers 12, d = 768, H = 12 query heads, H_kv = 4 (GQA
  group 3), d_h = 64, mlp 2048 … RMSNorm eps 1e-5, non-interleaved RoPE …
  T = 512 contract workload."
* `scripts/attention_spec_spike.py:46–54` sets `D_MODEL 768, N_HEADS 12,
  N_KV 4, HEAD_DIM 64, GQA_GROUP = 3, T 512, MLP_HIDDEN 2048`.
* `M125_CALIBRATION_STUDY.md:20–23` confirms 12 layers, d 768, 12 heads,
  4 KV heads, and that `mlp_hidden = 2048` resolves from
  `((8*768//3)+127)//128*128` — exactly as the draft says.

So the draft did not invent the head geometry, and the contrast it draws
with the toy module is real.

**Does the toy module support grouped KV heads? No — three sites, not two.
VERIFIED IN THE CODE.** `layout.rs:45` is `KV = 8` = `HKV · DH` with
`HKV = 1`; `Dom::Kv` is `(t, i')` (`layout.rs:85`); the score loop
`qr8[t*D + h*DH + i] * kr8[j*KV + i]` (`witness.rs:250`) gives every query
head the same key row. The draft names those two. It **misses a third**:
`argument.rs:799`,

```rust
let (ct, st) = rope_tables(ctx.public, if q { H } else { 1 });
```

That bare `1` is the KV head count. At 125M it must become `HKV = 4`, or
the public RoPE table for `SC_KVZC` has `T · 1 · 64 = 32,768` entries
against a `Dom::Kv` of `2^17`, and the slot's table-length check
(`argument.rs:281–283`) refuses. A search-and-replace on the symbol `KV`
would not find it. It is the same class-(c) assumption as T-3 in a place
T-3 does not point at. **MISSED PIN, see §2.6.**

**Did the draft price what grouped KV heads need? Substantially yes, with
one omission.** Its §2.3 adopts the public line's re-indexing (KV group in
the high bits) and its §9 step S6 prices the work as "a new relation between
two claim points", which matches the code: `Coord::Fixed` (`argument.rs:52`)
does let `A_KR8`'s claim point take its `kv` coordinates from the query
head's challenge vector, and `SC_PV`'s `A_V8` point (`argument.rs:663–665`)
gains the same coordinate. RECOMPUTED: with `H_pad = 16` and `HKV = 4`, the
padded head index splits as `h = kv·4 + g`, `kv` the top two bits, `g` the
bottom two — so the grouped-query map really is free, and `d_pad =
H_pad · d_h = 1024` really does keep `Dom::Q` and `Dom::D` the same size.
`Dom::Kv = 512 · 4 · 64 = 2^17` needs no padding, as the draft says.

**The omission that matters for the pad rule.** The real group is **3**, not
4. Under the high-bits re-indexing the padded head slots are
`h ∈ {3, 7, 11, 15}` — **one padded slot inside each KV group**, not the
contiguous block `[12, 16)` that the draft's §3.7 assumes ("a head index in
`[12, 16)`"). Whoever builds the support indicator will build the wrong
table if they read §3.7 literally. CORRECTION C-1.

## 2. Attack on the pin inventory

### 2.1 The eleven class-(c) sites, one by one

I opened every one of the eleven and twelve more of the other forty-nine
(pins 1, 5, 6, 8, 11, 13, 14, 16, 17, 18, 19, 20, 22, 24, 26, 28, 29, 31,
32, 33, 40, 44, 47, 48, 51, 55, 57, 59). Verdicts on the eleven:

| trap | the draft's claim | my verdict |
|---|---|---|
| **T-1** `N` is row width *and* table size | 8 (really 9) conflated sites, `protocol.rs:293` changes meaning silently | **Confirmed as a pin, severity overstated.** Every consequence is caught; nothing is unsound. §2.2 |
| **T-2** `outer.trailing_zeros()` | "the same shape of hole as D17 … the statement proved is weaker than the statement claimed" | **WRONG. It is a panic.** `fold_rows_i8` asserts `w.len() == rows` (`zkp-core/src/mle.rs:118`). §2.3 |
| **T-3** `KV` is a width, one KV head | correct; two sites | **Confirmed; a third site missed** (`argument.rs:799`). §1 |
| **T-4** every domain is a power of two, so nothing is evaluated on a pad | correct; the fix is a public support indicator | **Confirmed as a trap; the FIX IS UNSOUND as specified.** §2.4 |
| **T-5** the endpoint reads exactly two rows | "this **is** the D17 hole, in this module" | **Confirmed**, and `audit_claims` (`protocol.rs:99–102`) makes a mechanical widening loud, not silent: a 19-variable endpoint claim would span rows 0..32 on a 29-row commitment and be refused with "a claim reaches the proximity pair or leaves the commitment". The soundness requirement (C6, the batched multi-block seam) stands regardless. |
| **T-6** two remainder windows exactly full; `1 << (32 - NORM_WRHO)` underflows above 32 | correct in direction | **Confirmed, with three corrections**: four sites not two, the failure above 32 is a *compile-time* one, and the "ceiling" is the idiom's, not the construction's. §4 |
| **T-7** `Dom::L` packs sixteen sub-planes | correct | **Confirmed, and it is the cause of the group-count change** the draft could not settle: `limb_off(k) = a_off + k·T`, so `c0 = 512k` at 125M, nine distinct column offsets where the toy had eight. §3.2 |
| **T-8** RoPE partner bit `cf[log - 3]` | correct, must become `log - 6` | **Confirmed** (`argument.rs:805`, `3 = log2(DH)`), and loud at the toy. Class (c) is the right call: the failure mode is a wrong-but-valid claim point if `DH` and the literal drift apart. |
| **T-9** `sym()` vs the table-only gate class | correct | **Confirmed** (`layout.rs:274–276` against `witness.rs:369–372`); the asymmetry `[-127,127]` vs `[-128,127]` is real and the wrong choice is silent in both directions. |
| **T-10** public tables materialised in full | "67 MB, built twice" | **Confirmed and understated.** `causal_mask()` is called at `argument.rs:611` and `:840`; `table_of` then **clones** it (`:206`), so **two** 67 MB copies are live inside each of the two slots, i.e. 134 MB, twice. |
| **T-11** the shift constants are a calibration from a different kernel | correct | **Confirmed.** Each shift is welded to a window coefficient (`layout.rs:344,346,348,352–363`) and `private_block.rs:94` binds the calibration digest into the transcript, so the two must move together. The recorded 125M shifts do exist (`results/m125_int8_calibration.json`), but the draft **misquotes them**: it writes "eGate −3, eA −3, eZ 1" where layer 1 records `eGate −4, eA −4, eZ −1`. CORRECTION C-2. |

**Net on the classification: ten of eleven survive as class (c); T-2 is
class (a).** One additional site deserves class (c) and the draft filed it
as (b): `argument.rs:680`'s `tr.challenge_fp2_vec(4)` and `:687`'s
`rho(0..4)` serve all three feed-forward matmuls with one literal, which is
only correct because `D == F == 16` at the toy. At 125M the gate/up matmuls
need inner 10 / outer 11 and `SC_DMM` needs inner 11 / outer 10 — the single
literal has to become **four different numbers**. That is precisely the
"a coincidence of the toy shape" pattern the draft says class (c) is for.

### 2.2 `N` means two things (T-1)

**The conflation is real. VERIFIED IN THE CODE**, nine sites not eight:
`argument.rs:523` (`table_values_u8` over `0..N`), `:526`
(`table_values_exp`), `:534` (`table_values_act`), `:898` (`vec![Fp2::ONE;
N]` in `SC_ZS`); `protocol.rs:288`, `:293`, `:297`, `:303`, `:308`.

**What actually happens if `N` moves to 16,384 without splitting `U8_LEN`:**

| site | consequence |
|---|---|
| `argument.rs:523`, `:526`, `:534`, `:898` | the public table is 16,384 long against `SC_TAB`/`SC_ZS`'s 8 main rounds, so the slot's own length check refuses: `"private block: slot {s} table length"` (`argument.rs:281–283`). **Four loud failures**, not the "three" the draft counts. `:526` and `:534` would in fact panic first on `public.exp[i]` / `ff.act[i]` past index 255 (`[i16; 256]`, `private_block.rs:197`). |
| `protocol.rs:288`, `:297`, `:303`, `:308` | `vec![0u64; N]` is merely a bigger histogram; `:308`'s write loop fills one whole 16,384-wide row, which is exactly the row `A_MU8` owns. **No failure.** |
| `protocol.rs:299`, `:305` | the guard `(0..N as i64).contains(..)` widens, so an out-of-class witness value of, say, 1,128 now **indexes a 256-element array out of bounds and panics the prover** instead of falling into bucket 0. The draft flags the analogous `argument.rs:534` but not these two. |
| `protocol.rs:293` | the draft's headline: a non-byte value 300 is counted into `m_u8[300]` instead of bucket 0. |

**Is `protocol.rs:293` a soundness hole? No.** RECOMPUTED from the
identity: the witness side contributes `1/(α − 300 − g_u8)` and the table
side only ever sums `m[i]/(α − i − g_u8)` over the log-8 `Dom::Tab` claim
(`argument.rs:876–895`), so the 300-term has no partner and the value-0
LogUp sum claim (`protocol.rs:52–62`) cannot close for generic `α`. The
code's own comment says so: *"a value outside the table counts into entry 0:
only the LogUp identity can catch it"* (`protocol.rs:292`). At `N = 256` the
same value lands in bucket 0 and the identity fails in the same way. So the
change of meaning is real but the outcome is identical: **an honest prover
whose witness is out of class cannot produce a verifying proof either way.**

**Verdict on T-1.** Confirmed as a pin, and `S1` (split `U8_LEN` from `N`)
is the right first step and does keep the toy byte-frozen (all nine sites
are `256` at the toy, so the constant substitution is textually
value-preserving — see §10). But the draft's framing, "this is a one-line
fix that must happen **before** any row-width change, not after", should
not be read as "otherwise it is unsound". It is: otherwise the module does
not build, does not prove, or panics. CORRECTION C-3.

### 2.3 `argument.rs:626` — soundness hole, completeness failure, or panic?

**PANIC. The draft is wrong, and wrong in the direction that matters (it
claims a silent soundness hole where the code has a hard assertion).**

The site, VERIFIED IN THE CODE:

```rust
let r_j = tr.challenge_fp2_vec(outer.trailing_zeros() as usize);   // :626
...
b.public(fold_rows_i8(w, outer, D, &eq_table_msb(&r_j)));          // :632
```

and the callee, `zkp-core/src/mle.rs:116–118`:

```rust
pub fn fold_rows_i8(m: &[i8], rows: usize, cols: usize, w: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(w.len(), rows);
```

`eq_table_msb(&r_j)` has length `2^|r_j| = 2^trailing_zeros(outer)`, and
that equals `outer` **if and only if `outer` is a power of two**. So for
`outer = 768` the second assertion is `assert_eq!(256, 768)` and the prover
aborts. There is no configuration in which a short `r_j` reaches the
verifier: either the weight matrix is stored `768 × cols` and the second
assert fires, or it is stored padded `1024 × cols` and the *first* assert
fires. RECOMPUTED, `recompute.py` is not needed for this one — it is two
lines of code.

**And the padded case is simply correct.** Everything else in the module
forces `D` to be the *padded* width anyway: `(0..T * D)` builds the public
gain vectors at `argument.rs:706–707` and those must have length `2^19` or
the same slot table-length check refuses; `rows_of` and `Dom::D.log()`
assume `T · D` is a power of two. With `D = d_pad = 1024`,
`trailing_zeros(1024) = 10 = log2(1024)` and the site is exactly right.

**Verdict.** `argument.rs:626` is **class (a) mechanical**, not class (c).
The draft's fix ("carry the padded width and use `log2(d_pad)` explicitly,
with a construction-time refusal if `d_pad` is not a power of two") is still
the right code to write — it turns an assertion deep in a numeric helper
into a named refusal at construction — but it is hygiene, not a soundness
repair, and step S4's note "T-2 is a soundness fix" should be struck.
CORRECTION C-4. (Prediction P14 said panic; recorded as such in
`predictions.md` before I read `mle.rs`.)

### 2.4 The pad: every relation that reads a padded plane

**This is the finding. The draft's recommended pad fix (decision 3, a public
support indicator on every inhomogeneous constraint) is NOT SOUND, and
neither is the witness fill it is compared against. Both leave a prover free
to choose the norm's denominator, and therefore the block's whole output,
while matching the committed input on every real column.**

#### What is padded

RECOMPUTED (`recompute.py` §1): at 125M five of the nine domains pad —
`Ht` 6,144 → 8,192, `L` 4,608 → 8,192, `D` 393,216 → 524,288, `Q` 393,216 →
524,288, `S` 3,145,728 → 4,194,304. `Kv` and `F` are exact. The draft's
§2.3 table is correct.

#### The catalogue the draft asks for: every relation that reads a pad

I walked all twenty-three slots in `argument.rs:538–912`. The question for
each is not "is the constraint satisfiable on the pad" (it always is) but
**"does the pad enter a claimed SUM whose value the honest statement
depends on"** — because a constraint can be switched off by an indicator,
but a sum cannot.

| slot | reads a padded plane? | is the pad *summed*? | what forces the pad harmless |
|---|---|---|---|
| `SC_SS` / `SC_SSM` (`:544`, `:552`) | `A_X`, `A_X1` on `Dom::D` | **YES — `Σ_{t,i} eq(r_t,t)·x[t,i]²` runs over the padded `i`** | **NOTHING.** See below. |
| `SC_TZC` (`:558`) | `Dom::T` only, unpadded | no | — |
| `SC_LZC` (`:598`) | `Dom::L` pad | no (zero-check at a random `τ`) | homogeneous; the prover fills the helper |
| `SC_RS` (`:606`) | `A_E`, `A_ZSEL` on padded heads | summed over `j` (tokens, unpadded); padded heads enter through `eq(p_ht)` at a fixed point | the causal mask (`:505`) is **1** on padded heads — it keys only on `t` and `j` — so the padded heads must be filled, or the mask must be extended to a head-support indicator |
| `SC_QMM/KMM/VMM/WO/GMM/UMM/DMM` | `A_Y`, `A_O8`, `A_YM`, `A_H16` on padded axes | **YES**, the inner index is summed | **the zero-padded public weight** (`fold_rows_i8`/`fold_cols_i8` folds a zero row/column at every padded index). Sound — but it is an obligation on how the weights are padded, and the draft never states it. |
| `SC_SCORE` (`:641`) | `A_QR8`, `A_KR8` | sum over `i' ∈ [0,64)`, unpadded | — |
| `SC_PV` (`:655`) | `A_P`, `A_V8` | sum over `j` (tokens), unpadded | the padded-head identity must hold pointwise, but gives no leverage |
| `SC_DZC` / `SC_QZC` / `SC_KVZC` / `SC_SZC` / `SC_FZC` | all their planes | zero-checks at a random `τ`; the *host* terms sum over padded cubes | host terms are safe under an indicator (see below); the `c`-constraints are what the indicator switches off |
| `SC_TAB` / `SC_ZS` | `Dom::Tab`, unpadded | no | — |
| `SC_IO_IN` / `SC_IO_OUT` (`:902`) | `A_X`, `A_X2` over the whole padded cube | equality against the endpoint plane | the endpoint plane at 125M is **393,216 words, 24 data rows** (`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.3, quoted by the draft's §6 item 4) — i.e. **the true plane, not the padded cube**, so the seam covers no padded column at all |
| the value-0 LogUp sum claim (`protocol.rs:52–62`) | every `H` plane over its full padded domain | **YES**, but self-consistently | the pad's lookup values must still be table rows, so every *lookup-covered* plane is byte-bounded on the pad — **unless the indicator removes the constraint that ties the plane to its limbs** |

#### Why the support indicator breaks it

The indicator is fine where the draft uses the word "constraint". It is
even fine on the host terms, which I checked because they looked like the
risk: `SC_DZC`'s host term is
`ν₀·eq(p_a,x)·(2^{SH_AO}·ao + ral − 2^{SH_AO−1})` (`argument.rs:743`) and
the hosted `SC_WO` sum is already supported (the public weight is zero on
the pad), so multiplying the host term by `supp` turns the identity
`host = acc` into `supp·host = supp·acc`, which is exactly the wanted
statement. **That part of decision 3 is sound.**

The two slots the indicator does *not* reach are `SC_SS` and `SC_SSM`.
Their polynomial is `v[0]·v[1]·v[1]` with `v[0] = eq(r_t)` and
`v[1] = A_X` over the **full** `Dom::D` cube (`argument.rs:544–549`), and
`SC_TZC` hosts them with
`ν₀·eq(r_t)·(D² + a1 − C_eps)` (`argument.rs:591`). As a polynomial
identity in `r_t` that says, for every token row `t`:

```
D_t² + a1_t − 1  =  Σ_{i = 0}^{1023} x[t,i]²        ← the padded range
```

The draft's §3.7 disposes of this in one clause — *"the pad has `x = 0`
(`argument.rs:548`)"* — but `argument.rs:548` is the honest prover's
polynomial, not a constraint. Nothing in the verifier's view forces
`x[t,i] = 0` for `i ≥ 768`:

* **Under the indicator**: `c2` (`x + 32768 − (l0 + 256·l1)`,
  `argument.rs:728`) is switched off on the pad, so `A_X`'s padded entries
  are unconstrained **field elements**. `A_XL0`/`A_XL1` are still bytes
  (the LogUp sum is not indicator-guarded) but they are no longer tied to
  `x`. The prover therefore chooses `Σ_i x²` freely; the only remaining
  bound is `D < 2^24` and `a1 < 2^24` from the byte limbs
  (`layout.rs:314–315`, three limbs each). **`D` becomes freely choosable
  in `[1, 2^24)`.**
* **Under the fill** (the alternative the draft rejects for other reasons):
  `c2` is active, so `x_pad ∈ [−32768, 32767]`, and the prover can add up
  to `256 · 32767² = 2.75 × 10¹¹` to `ss`. RECOMPUTED: against the real
  checkpoint's honest `ss ≈ 768 · 83² = 5.3 × 10⁶` (`D = 2,300`), that lets
  the prover push `D` to `524,357` — a factor of 228.

Either way `D` is the divisor of the RMSNorm. Choosing `D` rescales `y` for
**every real column**, so the proved statement is no longer "this output is
the block applied to this input". It is "this output is the block applied
to this input *under a scale the prover picked*". The input commitment does
not save it: at 125M the endpoint plane is the true 393,216 words (§6 item
4 of the draft, from the accepted endpoints design), so the seam binds no
padded column at all, and under D18 the prover seals it anyway.

**This is D17's hole one generation later, in a different place.** D17:
a mechanical widening let a prover commit `(honest block ‖ junk ‖ junk)`
because the seam bound one `d`-block. Here a mechanical *padding* lets a
prover write junk into columns 768–1023 because the only relation that
reads them as a sum was assumed to see zeros.

#### The fix, and its cost

**BLOCKING B-1.** Every slot whose *sum* runs over a padded axis must carry
the support indicator too, not only the inhomogeneous constraints. That is:

1. `SC_SS` and `SC_SSM`: multiply by `supp_D`, degree 3 → 4, `L` 62 → 82
   (RECOMPUTED, still far inside the 256 budget, §6).
2. `SC_RS` and `SC_SZC`'s `host_rs`: either extend `causal_mask()` to be
   zero on padded heads (the cheapest — it is already a public table on
   exactly the right domain) or carry `supp_Ht`. Note the interaction with
   pin 40: `witness.rs:286` refuses `total < 2^{F_E}`, so a padded head
   whose `Sum` is forced to zero fails the *prover's own* check unless the
   head support is applied there too.
3. `SC_IO_IN`/`SC_IO_OUT`: under C6's batched multi-block seam these
   already become per-`d`-block equalities over the true plane, so no
   padded column is asserted. State it as a condition rather than leaving
   it implicit.
4. The public weight matrices must be **zero-padded** at every padded input
   and output index. This is what makes the seven matmul slots safe and the
   draft never says it. **BLOCKING B-2** (a one-line construction-time
   check: the folded weight vector is zero at every non-support index).

**And the indicator is needed on more domains than the draft prices.**
Decision 3 costs "one public `Fp2` table per padded domain (`Dom::D` 8 MB,
`Dom::S` 67 MB)". RECOMPUTED, the set is `Dom::D` (8.4 MB), `Dom::Q`
(8.4 MB, for `SC_QZC`'s RoPE and requant constraints on padded head slots),
`Dom::S` (67.1 MB) and `Dom::Ht` (0.13 MB); `Dom::L` needs none (its only
relation is homogeneous). And the `Dom::D` table is needed in **four**
slots (`SC_SS`, `SC_SSM`, `SC_DZC`, and `SC_QZC` reuses `Dom::Q`'s), each
of which materialises its own copy through `table_of`. CORRECTION C-5.

**A cheaper alternative the draft does not consider, and I recommend it be
priced before the indicator is adopted:** constrain the pad to zero
directly, with one extra degree-2 term per padded plane inside the existing
zero-check — `(1 − supp(x))·x = 0`. That is one `mu` coefficient and no
change of degree on `SC_SS`/`SC_SSM`, and it makes "the pad holds zeros" a
*proved* fact rather than an assumption, which is what the rest of the
memo's reasoning (including §3.7's own "does it disturb any claimed sum?")
silently relies on. It has to be applied to `A_X` and `A_X1` at minimum.

### 2.5 `priv_table`'s broadcast at padded coordinates

The drafter flagged this as "a specific thing for the independent checker to
attack". I attacked it. **It is correct. Prediction P16 held.**

`argument.rs:164–197` builds `T(x) = plane~(point(x))` over the slot's
`n_vars` boolean cube and then broadcasts:

```rust
for x in 0..out.len() {
    if x & !used != 0 { out[x] = out[x & used]; }
}
```

Three things make this safe at a padded shape, VERIFIED IN THE CODE:

1. **`p.log` is always the *padded* log**, never the true extent:
   `a_at` takes it from `a_dom(plane).log()` (`argument.rs:426`), the `h`
   builder from `h_dom(plane).log()` (`:444`), and the loop at `:174` runs
   `idx` over `0..1 << p.log`. So it never reads past the plane and never
   under-reads it.
2. **The witness is required to be the padded length.**
   `protocol.rs:271` refuses unless `wit.planes[p].len() == a_dom(p).len()`
   for every committed plane, and `witness.rs:215` allocates exactly that.
   So the padded entries are real committed values, not uninitialised
   memory, and the broadcast copies a value that exists.
3. **The broadcast source is always already final**: `x & used < x`
   whenever `x & !used != 0`, and the loop runs upward.

The broadcast is the correct multilinear extension of a function that does
not depend on the unused variables — which is exactly what a sub-domain
plane (e.g. `A_MX` on `Dom::Ht` read inside `SC_SZC`'s `Dom::S` cube) is.
At 125M `A_MX` has `p.log = 13` inside `n_vars = 22`, `used` is the top 13
bits, and the broadcast over the 9 `j` bits is right.

**What is *not* safe is the thing next door**, and it is worth recording
because the drafter's instinct pointed at the right area: `mask_eval`
(`:212–220`) and `build_claim` (`:223–236`) compute
`c0 = p.slices[0].0 % N` for sub-row planes, and at `N = 16,384` the nine
limb sub-slices land at `c0 = 512k`, `k = 0..8`. That is inside the row
(`4096 + 512 ≤ 16384`, so the PCS's `assert!(c0 + (1 << ls) <= n)` at
`zkp-core/src/pcs.rs:786` holds) — but the nine offsets no longer collide
the way they do at the toy, and that is what moves the opening-group count.
§3.2.

### 2.6 Pins the draft missed

Class (c) or class-(c)-adjacent, all VERIFIED IN THE CODE:

| # | site | what it pins | why the draft's table misses it |
|---|---|---|---|
| M-1 | `argument.rs:799` `if q { H } else { 1 }` | the KV **head count** inside `rope_tables` | the draft's T-3 names `layout.rs:45` and `witness.rs:250`; this bare `1` is neither, and a rename of `KV` will not find it |
| M-2 | `argument.rs:680` `challenge_fp2_vec(4)` and `:687` `rho(0..4)` | one literal for three matmuls' **two different** output widths and **two different** inner widths; correct only because `D == F == 16` | filed inside pin 47/48 as class (b) "derived" |
| M-3 | `argument.rs:505` `causal_mask()` | it is a **token**-support table, not a head-support one: `x % T <= (x / T) % T` ignores `h`, so it is 1 on every padded head | the draft cites it as the precedent for the support indicator ("the causal mask already is this device") without noticing it does not cover the axis that pads |
| M-4 | `protocol.rs:299`, `:305` | `(0..N).contains(..)` guards an index into a fixed `[i64;256]` / `[i16;256]`; widening `N` turns a graceful bucket-0 into an **out-of-bounds panic** | the draft flags the twin at `argument.rs:534` only |
| M-5 | `protocol.rs:52–62` `logup_sum_claim` | every `H` plane's `log_size` must sit on the **same side of `LOG_N`**, or the claim's parts have different column-weight keys | absent from the draft; it is the §3.2 blocker |
| M-6 | `witness.rs:286` `total ∈ [2^{F_E}, T·2^{F_E}]` | the **lower** bound interacts with the pad rule: a padded head with `Sum = 0` fails the prover's own check | filed as pin 40 class (a) "scales with `T`" |
| M-7 | `protocol.rs:223` `(0..H * T * T)` in `exp_deltas` | a second full materialisation of the `2^22` cube as `Vec<i64>` (33.6 MB), plus `act_indices` at `2^20` (8.4 MB) | the draft's T-10 lists `argument.rs:505` and `:509–520` only |

`debug_assert`: **none in either module** (grep over `private_block/*.rs`,
`private_block.rs`, `private_attention/*.rs`). Every guard is a real
`assert!`, a typed check or a `Result`. That is a point in the module's
favour and the draft could have said so.

`as u8` / `as u16` on a dimension: **none**. The two `as u8` sites
(`private_block.rs:156`, `:222`) are digest serialisation of `i8` weights,
not dimensions. `next_power_of_two`: **absent from the module** — every
domain size is a hand-written log (`layout.rs:98–106`), which is the whole
substance of T-4.

## 3. Attack on the totals (rows, bytes, receipt, soundness)

### 3.1 Rows, recomputed from the module's own rule

RECOMPUTED (`recompute.py` §2). I implemented `rows_of(log) =
(1 << log).div_ceil(N)` (`layout.rs:537–539`) and the per-domain plane
counts from `layout.rs:114–214`, and **checked the model against the toy
first**: it reproduces `A_DATA_ROWS 213`, `A_ROWS 455`, `H_DATA_ROWS 280`,
`H_ROWS 384`, `A_SITES` summing to 120, `H_SITES` to 51, the per-domain
lookup totals `[1024, 19456, 4608, 6656, 3072, 26624]` and the 61,440 —
all exactly (the script asserts each). Only then did I run it at 125M.

| | draft | checked | difference |
|---|---:|---:|---|
| `A` data rows | 5,435 | **5,435** | — |
| `A` claim sites | 122 | **122** | — |
| `A` rows | 5,681 | **5,681** | — |
| `H` data rows | 7,082 | **7,018** | −64 |
| `H` claim sites | 51 | **50** | −1 |
| `H` rows | 7,186 | **7,120** | −66 |
| `M` rows | 50 | **50** | — |

**The `A` column is exactly right.** The `H` column is one helper plane too
high, and the cause is §4's lookup miscount: the draft drops two redundant
`scaled(ρ_top, 1 << (32 − NORM_WRHO))` lookups where `layout.rs` has
**four** of them (`:321`, `:323`, `:329`, `:331` — `ρ` and `σ` of `norm_a`
*and* of `norm_m`). `Dom::D` therefore goes 38 → **34** lookups, not 36,
and its helpers 19 → **17**, not 18. One `Dom::D` helper plane is 2 × 32 =
64 rows. CORRECTION C-6.

Caveat: if the security owner takes the draft's **decision 2** (a narrower
input class) the arithmetic changes again — the window no longer reaches 32
so the four `scaled` lookups stay, and two class lookups are added, giving
`Dom::D` **40** lookups, **20** helpers, `H` data 7,210 and `H` rows
**7,318**. The draft's 36/18/7,186 corresponds to neither branch. Whoever
implements this must recompute `H` *after* the ruling on decision 2, not
before. RECOMPUTED, both branches, in `recompute.py` §2b.

**`M` rows are shape-independent and the draft is right.** VERIFIED IN THE
CODE: `mask_commit` sets `n_base = 2 * masks.len() + 4`
(`hashline/src/zk.rs`, the `mask_commit` body) over a **fixed** geometry —
`MASK_LOG_MSG 9` (512 message positions), `MASK_LOG_DOM 12` (4,096
evaluation positions), `MASK_Q 256`. None of the three moves with the
block's `log_cols`, so `M` is 50 rows × 4,096 × 8 B = 1,638,400 B at both
shapes. The orchestrator's question ("are M's rows a function of the row
WIDTH?") answers **no**.

### 3.2 Opening groups — and a blocker the draft did not see

The draft left `A_GROUPS`/`H_GROUPS` as "did not check". I checked, using
the grouping rule the code itself states (`protocol.rs:67–71` `part_key`,
matching `zkp-core/src/pcs.rs:752–792` `zpart_weights`): a claim's group key
is `(point tail, c0, len)`, where for `log_size ≥ LOG_N` the key is
`(point[log−LOG_N..], 0, N)` and below it `(whole point, offset % N,
1 << log)`.

**Model validated on the toy first.** Enumerating the claims slot by slot
from `argument.rs:538–912` gives 1+1+8+1+1+1+1+1+2+2+1+1+1+1+2+2+2+2+1+1+
0+1+1 = **35 `A` groups** and 1+1+1+1+1+1+1+1+1 = **9 `H` groups**, which
are exactly `A_GROUPS = 35` and `H_GROUPS = 9` (`layout.rs:516–517`).

**At 125M, `A_GROUPS` becomes 36.** The one slot that moves is `SC_TZC`.
Its 22 `A` sites are `A_D`, `A_DSQ`, nine limb sub-slices, `A_DM`, `A_DSQM`
and nine more, all at `log = log2(T)` and therefore sub-row. Their column
offsets are `c0 = limb_off(k) % N = (k · T) % N`:

* toy: `k · 32 mod 256` for `k = 0..8` → `{0,32,…,224, 0}` — **`k = 8`
  wraps onto `k = 0`**, eight distinct keys;
* 125M: `k · 512 mod 16384` → `{0, 512, …, 4096}` — **nine distinct keys**.

That is trap T-7 cashing out. RECOMPUTED: `A_GROUPS = 36`. Each group costs
one more opened vector, `VEC × 16 = 16,640 × 16 = 266,240 B`, so the receipt
grows by 0.27 MB. CORRECTION C-7.

**`H_GROUPS` never gets computed, because the construction refuses first.
BLOCKING B-3.** The value-0 LogUp sum claim (`protocol.rs:52–62`) is one
`ZClaim` with **one part per `H` plane**, each `ZPart` carrying
`log_size = h_dom(p).log()` and an empty point. At the toy every `H` domain
has `log ≥ LOG_N = 8`, so every part's key is `([], 0, 256)` and they agree.
At 125M with `LOG_N = 14` the `H` domains are `L 13`, `D 19`, `Q 19`,
`Kv 17`, `S 22`, `F 20`, `Tab 8` — three different sides of the row width,
giving three different keys `([], 0, 8192)`, `([], 0, 16384)`,
`([], 0, 256)`. Then:

* `check_opening` (`protocol.rs:161–163`) returns
  `"private block: claim parts with different column weights"`, on the
  prover **and** on the verifier; and
* one level down, `zkp-core/src/pcs.rs:817` is a hard
  `assert!(key2 == key, "zk claim: parts with different column weights")`.

So the module as designed **cannot produce a proof at `log_cols = 14`**.
This is not a count the implementer will rediscover from the draft; it is a
refusal on the first run of step S9.

Two repairs, both cheap, neither in the draft:

* **Lift the two small `H` domains to `log = LOG_N`.** `rows_of(13)` and
  `rows_of(8)` are both already 1 at `N = 16,384`, so this costs **zero
  rows**. But it is not free of thought: padding `Dom::Tab` to 16,384
  widens the *table*, and the padded table values must be chosen so the
  proved set is still the 256 bytes (e.g. `tv[i] = (i mod 256) + g_u8`,
  with the padded multiplicities free to be zero). Get that wrong and the
  byte range proof admits 16,384 values instead of 256 — a soundness hole
  created by the fix for a shape bug.
* **Split the sum claim** — not available as the code stands:
  `audit_claims` (`protocol.rs:110–124`) permits exactly **one** pairless
  sum claim and only as the **last** claim; a second one is refused with
  "unexpected sum claim".

With either repair, `H_GROUPS` stays **9** (RECOMPUTED slot by slot).

### 3.3 Bytes and receipt

RECOMPUTED from the module's own `encoded_len` (`wire.rs:28–36`) with
`VEC = n + Q = 16,640`, `PATH = log2(16,384 · 4) = 16`, `CHECKS = 256`.
The draft's arithmetic form is right — I reproduce its `A` and `H` figures
digit for digit from its own inputs, and its endpoint figure of 733,184 B
each falls out of `opening_len(1, 29)` exactly.

| part | draft | checked (wrho 32 branch) |
|---|---:|---:|
| `A` opening | 21,360,640 | **21,626,880** (36 groups) |
| `H` opening | 17,520,640 | **17,385,472** (7,120 rows) |
| two endpoint openings | 1,466,368 | 1,466,368 |
| `M` opening | 243,712 | 243,712 |
| 23 slots | ~24,704 | 24,688 |
| **one block** | **40,616,200 B = 38.73 MiB** | **40,747,256 B = 38.86 MiB** |
| twelve blocks | 487 MB | **489 MB (466 MiB)** |

So the draft's headline receipt figure is **right to 0.3%** — the two
errors (one group too few, 66 rows too many) very nearly cancel. Under
decision 2's branch it is 41,152,808 B. Committed material:
`A` 710.1 MiB systematic / 2,840.5 MiB encoded (draft: 710 / 2,840 —
exact); `H` 890.0 / 3,560.0 MiB against the draft's 898 / 3,593.

### 3.4 Soundness at the new geometry

**Prediction P6 was wrong and the draft is right.** I expected the move
from `inv_rate 8` to `inv_rate 4` to cost about 21 bits per opening, on the
reasoning that the proximity bound is `(1 − δ/3)^Q` with `δ = 1 − 1/inv_rate`
(`zkp-core/src/pcs.rs:16–19`). It does not, because **the hiding form's
rows are `n + Q` long, not `n`** — `commit_zk_owned` pads every row with
`q_pad = 256` fresh values (`pcs.rs:672–673`), which is what
`ZK60_FABLE_SECURITY_OBLIGATIONS.md:377` records ("rows become
RS(n + Q = 512, 2048), rate 1/4"). RECOMPUTED with exact fractions:

| geometry | message | encoded | rate | `(1 − δ/3)` | per opening |
|---|---:|---:|---:|---:|---:|
| toy block, `log_cols 8 / inv_rate 8` | 512 | 2,048 | 1/4 | 0.750000 | **2^-106.25** |
| 125M, `log_cols 14 / inv_rate 4` | 16,640 | 65,536 | 0.253906 | 0.751302 | **2^-105.61** |

Exactly the draft's `2^-106.25 → 2^-105.61`. The *non-hiding* control from
the obligations doc, `(17/24)^256 = 2^-127.4`, confirms the formula is
being applied the same way. **VERIFIED.** The block loses 0.64 bits per
opening, not 21.

**How many openings, and the whole-proof figure the draft declined to give
(and which D15 requires before any published number).** RECOMPUTED:

* one block makes **four** PCS openings (`A`, `H`, input endpoint, output
  endpoint — `protocol.rs:397`, `:400`, `:403`, `:406`) plus one mask
  opening whose fixed geometry gives `(17/24)^256 = 2^-127.4`.
  Union: `4 × 2^-105.61 = 2^-103.61`.
* the LogUp term, counted D15's way (a rational identity of degree `N` in
  `α ∈ F_{p²}`): `N = 98.6M U8 + 4.19M exp + 1.05M act = 103,825,408`, so
  `N/|F_{p²}| = 2^-101.37` per block.
* **one block ≈ 2^-101.1**, dominated by the lookup term.
* a 12-block chain under the draft's §8 option (iii): 12 `A` + 12 `H` + 2
  external endpoints = **26** PCS openings = `2^-100.9`, plus twelve
  independent LogUp arguments = `2^-97.79`. **Whole 12-block private 125M
  pass ≈ 2^-97.5.**

That is comfortably in the same place as the rest of the line (D15's
projected 8B figure is about 2^-94; the zkVM line's conjectured level is
97 bits, D3) and **below the 128-bit target**, so decision 11 ("re-derive
the soundness figure before any published number") is right and can now be
answered: about **97 bits for the twelve-block pass, about 101 for one
block**, both projections of the same relation set, neither measured.

## 4. Attack on the arithmetic (the two windows)

All of this is RECOMPUTED with Python integers (`recompute.py` §4–§6);
nothing is floating point except the printed `log2`.

### 4.1 The accumulations: the draft is right

| accumulation | draft | checked | headroom to 2^49 |
|---|---:|---:|---:|
| QKV / `Wo` / gate / up, 768 terms int8×int8 | 12,387,072 = 2^23.56 | **12,387,072** | 2^25.44 |
| down, 2048 terms int16×int8 | 8,522,565,632 = 2^32.99 | **8,522,565,632** | 2^16.01 |
| scores, 64 terms | 1,032,256 = 2^19.98 | **1,032,256** | 2^29.02 |
| PV, 512 terms | 33,292,288 = 2^24.99 | **33,292,288** honest | 2^24.01 |
| `a16·u16` | 2^30.00 | **1,073,676,289** | 2^19.00 |
| `D² + a1` | 2^39.58 | **824,583,389,953** | far below `p` |

and the 768/2048 figures do match the recorded study
(`results/m125_int8_calibration.json` → `accumulators.768.max_abs_acc =
12,387,072`, `accumulators.2048.max_abs_acc = 33,032,192`) exactly.
**Nothing wraps, nothing approaches 2^49, no matmul forces a new limb.**
Confirmed.

One nit: the PV row uses the *honest* bound `p ≤ 2^9`. The bound the proof
actually enforces is `p < 2^10` (two limbs with `scaled(A_PL1, 64)` gives
`l1 < 4`), so the sound worst case is 66,519,552 = 2^25.99 and
`p·Sum + ρ_s` is 2^28.00, not the draft's 2^27.00. Both are still 2^21
below 2^49, so nothing changes; but a premise table should quote proved
bounds. CORRECTION C-8.

### 4.2 The norm window: 0.21 bits is right

RECOMPUTED exactly, with `ss = C_eps + Σ x²`, `D = isqrt(ss)`,
`den = D · 2^{tn+1} = 4096·D` (`witness.rs:157–208`):

| geometry | `Dmax` | `D` limbs | `den` | smallest exact window |
|---|---:|---:|---:|---:|
| toy `d 16`, int16 | 131,068 | 3 | 536,854,528 = 2^29.000 | 29 (saturated) |
| **125M `d 768`, int16** | **908,065** | **3** | **3,719,434,240 = 2^31.792** | **32** |
| 125M `d 768`, `\|x\| < 2^12` | 113,483 | **3** | 464,826,368 = 2^28.792 | **29** |
| 125M `d 768`, int8 (127) | 3,519 | 2 | 14,413,824 = 2^23.781 | 24 |
| 125M `d 768`, real (83) | 2,300 | 2 | 9,420,800 = 2^23.167 | 24 |
| 8B `d 4096`, int16 | 2,097,088 | 3 | 8,589,672,448 = 2^33.000 | 33 |

`2^32 / den = 1.154737`, i.e. **0.2076 bits**. The draft's 0.21 is right,
`Dmax = 908,065` is right, `2^31.79` is right, and D16 items 1–3 hold
(`Dmax < 2^24`, `a1max = 1,345,728 < 2^24`, three limbs each,
`D² + a1 = 2^39.58`). `witness.rs:174`'s literal `1 << 24` still passes.
**§3.3 of the draft is VERIFIED.**

### 4.3 What `layout.rs:321` actually does above 32 bits

The draft says it "underflows"; the orchestrator asked for exactly what.
VERIFIED IN THE CODE, `layout.rs:321`:

```rust
v.push(scaled(A_NR0 + 3, 1 << (32 - NORM_WRHO)));
```

`NORM_WRHO` is a `const u32` and `scaled(p: usize, k: i64)`, so
`32 - NORM_WRHO` is a **`u32` subtraction of two compile-time constants**.
With `NORM_WRHO = 33` it is `32u32 - 33u32`, which rustc's const
propagation evaluates and the deny-by-default `arithmetic_overflow` lint
rejects: **the crate does not compile.** If it ever escaped const-prop, a
debug build panics ("attempt to subtract with overflow") and a release
build would compute `1i64 << (4,294,967,295 mod 64) = 1i64 << 63`, i.e. the
shift itself overflows `i64` and the coefficient becomes `i64::MIN` — a
nonsense negative lookup coefficient. **So the failure is loud at every
stage; it is not a silent wrong answer.** That is better than the draft
implies, and worth recording in the errata because a reader planning the 8B
work would otherwise expect a subtle bug rather than a build error.

### 4.4 "The construction cannot express 8B" — overstated

The ceiling is not the construction's. It is the conjunction of two local
choices: **four** byte limbs on `ρ`/`σ`, and the **`1 << (32 − wrho)`**
idiom for the top limb's scale. A fifth limb gives `wrho` up to 40 with the
coefficient `1 << (40 − wrho)`, and RECOMPUTED, nothing wraps at 8B with
it: the largest norm term is `y·D·2^{tn+1} ≤ 127 · 2,097,088 · 4,096 =
2^40.0`, and `D² + a1 = 2^42.0` — both far below `p`. D16 item 3's "never
more than four limbs" is a statement about the **square** relation
(`D`, `a1`, `a2`), which is what can wrap at five; `ρ` and `σ` appear only
linearly in `c0`/`c1` and are not covered by it. So the honest statement is:
*the 8B norm needs a fifth `ρ`/`σ` limb (four more `Dom::D` planes,
+128 rows at 125M-class geometry) and a rewritten coefficient — not a new
construction.* CORRECTION C-9. This matters because the draft files it as
open obligation 6, "owed whatever else is decided", which reads much larger
than it is.

### 4.5 Decision 2 (a narrower input class): the arithmetic is wrong, the
product answer is right

The draft: *"pin `x_in` and `xres1` below `2^12` … at `2^12` it needs 27,
with 5 bits of margin, and `D` drops to two limbs."*

RECOMPUTED (row 3 of the table in §4.2): at `|x| < 2^12`, `Dmax = 113,483`,
`den = 2^28.79`, so the window needs **`wrho = 29`, not 27** — 3.2 bits of
margin, not 5 — and `D = 113,483 > 65,535` needs **three limbs, not two**.
To get `wrho = 27` the class would have to be about `2^10`; to get `D` to
two limbs it would have to be about `2^11`. CORRECTION C-10.

**Does the real 125M checkpoint fit? Yes, with a very large margin.**
VERIFIED in `results/m125_int8_calibration.json`: layer 1 records
`stats.x.absmax = 20.5977` at `eX = −2`, i.e. `|x_int| ≤ 20.60 × 4 = 82.4`,
so 83 — the draft's figure is right. A `2^12` declared class is **49×**
that; even a `2^10` class (which would buy `wrho 27` and 5 bits of margin,
what the draft thought `2^12` bought) is 12× the measured absmax. So the
proposed pin is a convenience with real headroom, **not** something that
would make the proof refuse the real model — provided two things the draft
does not say:

1. The class must be declared for `xres1` (norm_m's input) as well as
   `x_in`, and `xres1 = x + ao` is **not** in the calibration study. It is
   the post-attention residual, bounded by the same family but not
   measured. **OMITTED CONDITION O-1**: measure `|xres1_int|` on the real
   checkpoint before fixing the class.
2. A declared class is a **refusal** on any real input that exceeds it, and
   the study is one checkpoint at one seed on one corpus. A class at `2^12`
   with 49× headroom is a reasonable bet; a class at `2^10` with 12× is a
   thinner one. The draft is right that this is a product decision.

**My recommendation differs from the draft's in one respect.** With the
pad hole of §2.4 repaired, the `2^12` class buys `wrho 29` and 3 bits — but
*without* that repair, narrowing the class makes the pad attack **worse**,
not better: the honest `ss` shrinks by 49² while the attacker's budget
(256 padded columns at the declared class) shrinks only by the same factor
per column, so the ratio of forgeable `D` to honest `D` goes from 228× at
int16 to 28× at `2^12` — still total. Decision 2 is not a substitute for
B-1, and the draft nowhere says it is, but the two are discussed far apart
and the reader may connect them wrongly.

### 4.6 The softmax window: right, and its cost is right

RECOMPUTED: `Sum ≤ T · 2^{F_E} = 512 · 512 = 2^18` exactly
(`witness.rs:286`), `σ_s < Sum` so `WRHO_S = 18`, and 18 bits needs
**three** byte limbs with `scaled(l2, 64)`. The draft's `14 → 18`, the two
new `Dom::S` planes, the +2 lookups on `Dom::S` (13 → 15) and the extra
`Dom::S` helper (7 → 8) are all confirmed, as is the arithmetic that makes
this the most expensive line in the memo: 2 planes × 256 rows = **512
committed rows**, 8.4 MB systematic / 33.6 MB encoded.

`delta = mx − masked ≤ 127 + 127 = 254 < 256` independent of `T` and `d`
(`witness.rs:277–280`, `MASK_SCORE = −127`): **confirmed**, the exp table
does not change.

## 5. Attack on the tables and lookups

**The table set is what the draft says. VERIFIED IN THE CODE.** Exactly
three tables, all 256 entries, all one committed multiplicity row
(`A_MU8`, `A_MEXP`, `A_MACT`, `layout.rs:195–197`), all one helper pair
(`H_GU8`, `H_GEXP`, `H_GACT`, `:235–237`), all under distinct tags
(`TAG_U8`, `TAG_EXP`, `TAG_ACT`, `protocol.rs:333–335`). The header comment
at `layout.rs:30–36` records the deviation the draft quotes, and the
byte-limb lever really did remove the two 65,536-entry tables. **Nothing
about the table set changes at 125M**, for the reasons the draft gives
(`delta < 256` is `T`- and `d`-independent; the gate is int8 by
construction). Confirmed.

**The lookup count is 1.1% too high.** RECOMPUTED (`recompute.py` §3),
with the `Dom::D` correction of §3.1:

| domain | lookups/position | positions | draft total | checked total |
|---|---:|---:|---:|---:|
| `L` | 2 | 8,192 | 16,384 | 16,384 |
| `D` | 36 → **34** | 524,288 | 18,874,368 | **17,825,792** |
| `F` | 9 | 1,048,576 | 9,437,184 | 9,437,184 |
| `Q` | 13 | 524,288 | 6,815,744 | 6,815,744 |
| `Kv` | 12 | 131,072 | 1,572,864 | 1,572,864 |
| `S` | 15 | 4,194,304 | 62,914,560 | 62,914,560 |
| | | | **99,631,104** | **98,582,528** |

plus 4,194,304 exp pairs and 1,048,576 act pairs. Under decision 2's branch
it is **101,728,256**. The draft's "63% on the score cube" is confirmed
(62.9M of 98.6M = 63.8%), and so is "a factor of about 1,600".

**Multiplicities cannot wrap, and nothing range-checks them.** The
orchestrator's question was whether a multiplicity is byte-limbed anywhere.
VERIFIED IN THE CODE: **no.** `protocol.rs:309–311` writes the histogram
directly as `Fp::new(m_u8[i])` into `A_MU8`/`A_MEXP`/`A_MACT`, those three
planes are excluded from the committed-plane list by `is_multiplicity`
(`layout.rs:218–220`), `lookups(Dom::Tab)` is empty (`layout.rs:365`), and
`SC_TAB` (`argument.rs:876–895`) reads them only as the numerator of
`m/(α − t)`. So a multiplicity is an unconstrained field element bounded
only by the identity it must satisfy. At 98.6M it is 2^26.6 against a 2^64
base field — 2^37 of headroom, exactly as the draft says. The module's own
premise text at `layout.rs:308–309` ("at most 61,440") must be rewritten
for the new profile (it is part of D16 item 5's re-derivation).

**The LogUp soundness term at 10^8 lookups**, counted D15's way:
`N/|F_{p²}| = 103,825,408 / 2^128 = 2^-101.37` per block, and it is the
**dominant** term of the whole proof — larger than the four PCS openings'
`2^-103.61` combined. The draft does not give this number anywhere. §3.4.

**The two recorded levers.** The draft's arithmetic on the `sym` lever is
high. The `sym` pairs are 2 on `Dom::D` (`A_Y`, `A_YM`), 3 on `Dom::Q`,
3 on `Dom::Kv`, 1 on `Dom::S` (`layout.rs:319,327,343,345,347,351,353,355,
359`). Replacing each pair by one signed-table lookup saves one lookup per
pair per position: RECOMPUTED `2·524,288 + 3·524,288 + 3·131,072 +
1·4,194,304 = 7,208,960` — **7.2 million saved**, not "about 11 million".
Still the better of the two levers if one is ever needed, still not worth
taking now. Agreed with the recommendation, CORRECTION C-15 on the figure.

## 6. Attack on the slots

RECOMPUTED (`recompute.py` §7) with the code's own formula,
`L = (main + ext) · degree + 2` (`zkp-core/src/sumcheck.rs:197–198`,
`CfsMask::len`), and checked against the toy's declared maximum of 50
(`layout.rs:733`) first — my table reproduces every toy `L` in the draft's
§5 table exactly.

**At 125M the closest slot is `SC_SZC` at `L = 94`, exactly as the draft
says**, and `94 + 256 = 350 ≤ 512`. With the support factor it is 117
(`350 → 373`). Every other slot is lower. The draft's whole §5 table
reproduces line for line under my independent computation, including the
`SC_RS` 71/94 and `SC_DZC` 82/102 entries. **VERIFIED.**

Two additions:

* If B-1 is applied, `SC_SS` and `SC_SSM` also gain a degree (3 → 4),
  taking their `L` from 62 to **82** (`338 ≤ 512`). Still nowhere near.
* The 8B figure: `SC_SZC` at 23 + 1 rounds, degree 4 → `L = 98`, degree 5 →
  `L = 122`. Confirmed. The real ceiling really is the `1u64 << n_vars` in
  `CfsMask::sum_weights` (`zkp-core/src/sumcheck.rs:223–224`) at 63
  variables. **The masking machinery needs nothing at any shape the project
  has named.** Confirmed.

`M` rows stay 50 — see §3.1; `n_base` is a function of the slot count only
and the mask geometry (512 / 4,096 / 256) does not move with `log_cols`.
The `assert!(part.len() + MASK_Q <= m)` inside `mask_commit` is the real
enforcement of `L + 256 ≤ 512`, and it is a hard assert, so a slot that
outgrew the budget would abort the prover rather than weaken anything.

## 7. Attack on memory and time

### 7.1 Peak residency, rebuilt from the allocation sites

I traced every allocation in `protocol.rs::prove_inner` and the commit
path. RECOMPUTED (`recompute.py` §10):

| buffer | where it is allocated | where it dies | bytes |
|---|---|---|---:|
| `wit.planes` (88,901,632 `i64`) | `witness::build`, owned by the caller | after `prove` returns | 711 MB |
| `looked` (98,582,528 `i64`) | `protocol.rs:289` | end of `prove_inner` | 789 MB |
| `A` systematic (`a.data`) | `:282`, moved into `commit_zk_owned` | `drop(a)` at `:398` | 745 MB |
| `A` encoded | `pcs.rs:681` | `drop(a)` | 2,978 MB |
| `H` systematic | `:336` | `drop(h)` at `:401` | 933 MB |
| `H` encoded | `pcs.rs:681` | `drop(h)` | 3,733 MB |
| per-commitment extras (`pads`, `salts`, leaves, tree) | `pcs.rs:673–690` | with the commitment | 39 MB |
| two endpoints (29 rows each, sys + enc) | `prepare_endpoints` | their openings | 38 MB |
| `M` | `:324` | `drop(mc)` at `:393` | 1.6 MB |
| **largest slot's tables** (`SC_SZC`, 28 tables × 2^22 × 16 B) | `table_of` at `argument.rs:280` | end of that slot | **1,879 MB** |
| **peak** | | | **11.81 GB = 11.00 GiB** |
| after step S2's two `drop`s | | | **10.31 GB = 9.60 GiB** |

**Two things I checked that could have broken the model, and did not.**
`commit_zk_owned` does **not** build a transposed copy — `hash_columns`
reads the encoded matrix in place (`pcs.rs:685`) — and the sumcheck folds
tables **in place** with `split_at_mut` + `truncate`
(`zkp-core/src/sumcheck.rs:114–126`), so there is no 1.5× fold peak.
Prediction P12 held.

**Two things the draft's model misses**, both small but both in the wrong
direction: `causal_mask()` is cloned by `table_of` (`argument.rs:206`), so
`SC_RS` and `SC_SZC` each hold **two** 67 MB copies; and `exp_deltas`
(`protocol.rs:221–229`) materialises a third `2^22` `Vec<i64>` (33.6 MB)
plus `act_indices` at 8.4 MB. Call it +110 MB.

**Is "one block fits this laptop" safe? No, as stated.** The box has
15,762 MB total and 14,176 MB available right now with nothing running
(`free -m`, 2026-09-19). An 11.0 GiB process leaves about 2.9 GiB for
everything else on a machine that, by this repository's own record, **OOMs
under concurrent suite and bench runs** and whose standing rule caps
domains at 2^22 — and `Dom::S` at 125M *is* exactly 2^22. The draft's
"fits, with about 3 GB of headroom" is arithmetically right and
operationally wrong: it is only true if the heavy lock is held and no other
agent is building. **OMITTED CONDITION O-2**: the one-block measurement
must run detached under `flock /tmp/zk-heavy.lock` with step S2 already
applied (9.6 GiB, not 11.0), and the acceptance check should include peak
RSS, not only time. The draft's step S13 asks for phase lines but not for
RSS; step S14 does ask for `peak RSS ≤ 10 GB` and should say so for S13
too.

### 7.2 Time

The draft's anchors are real. VERIFIED against
`git show fsp-mr1:docs/zkmatrix-poc/ZK60_FSP_MR1_PROGRESS.md` (quiet box,
12 layers × 512, `log_cols 14 / inv_rate 4 / Q 256`): PROVE 35.417 s,
commit A 9.637, commit W 4.575, helpers + commit H 10.769, zero-check F
6.865, PCS openings 1.741, and rows 585 `A` / 486 `H` / 288 `W` / 16 `M`
per layer with 88,356,464 proof bytes over twelve layers.

RECOMPUTED rates: commit A **1.3728 ms/row**, commit W **1.3238 ms/row**
(they agree to 3.7%, which is the draft's point and it is a fair one:
the same row width, the same parameters, the same box). Blended
**1.3566 ms/row**.

Two corrections to the model:

* the opening rate. The draft divides 1.741 s by `A + H` rows only
  (0.1355 ms/row). The phase opens `W` and `M` too, so the honest rate is
  1.741 / 16,500 = **0.1055 ms/row**, and the block's opening term is
  **1.4 s**, not 1.7.
* the sumcheck term. The draft's 13.6 ns per table-point rests on an
  assumed ~40 tables over `2^20` in the FFN's `zero-check F`, which it did
  not verify and neither did I (I did not read `zk.rs`'s layer layout).
  What I *can* give is the block's own table-point total, counted table by
  table from `argument.rs`: **204,276,352**, against the draft's 212.7M.
  The term is 4% smaller than the draft's and rests on the same unverified
  rate.

**My band.** Two models, deliberately kept apart:

* **phase model**: commit 1.3566 × 12,909 = 17.5 s, helpers ≈ 3.3 s,
  sumchecks 204.3M × 13.6 ns ≈ 2.8 s, openings 1.4 s → **≈ 25 s**;
* **crude all-in rate**: the measured 35.417 s over 12,852 committed rows
  is 2.756 ms/row all-in, and one block has 12,801 `A + H` rows →
  **≈ 35 s**.

So I get the draft's **25–36 s**, from the same anchors, with slightly
different intermediate numbers. I would not narrow it. The draft's advice
to "plan for 2–4 minutes per block until someone measures it" is the right
posture given this week's base rate (three counted estimates off by three
to seven times), and I would add one structural reason the phase model may
be low that the draft does not name: **the block's sumchecks run on
domains up to 2^22 where the measured FFN's largest is 2^20**, and
`priv_table` (`argument.rs:164–197`) rebuilds a full `2^{n_vars}` table for
every private plane in every slot — 28 of them at `2^22` in `SC_SZC` alone.
The measured `zero-check F` phase may not contain an analogous cost at
anything like that scale.

## 8. Attack on the form-E Amdahl figure

RECOMPUTED (`recompute.py` §13), assigning planes to halves the same way
the draft says it did:

| half | `A` data rows | `H` data rows | total | share |
|---|---:|---:|---:|---:|
| attention | 4,213 | 5,730 | 9,943 | **79.9%** |
| feed-forward | 1,219 | 1,280 | 2,499 | **20.1%** |
| shared tables | 3 | 8 | 11 | 0.1% |

which is the draft's 79.4 / 20.5 to within my `H` correction. Amdahl with
the measured GPU factor of 7.62× (4.649 s against 35.417 s):
`0.201 × (1 − 1/7.62) = ` **17.4%**, against the draft's 17.8%.

**But the draft's 20.1% is the wrong numerator, and the true ceiling is
lower.** Form E's value is that the feed-forward half runs on **the
existing GPU prover**, and the existing GPU prover is the `zk.rs` FFN path,
which proves gate / activation / up / product / down. It does **not** prove
`norm_m` — D12 item 4 exists precisely because "the feed-forward prover
proves no range on its own input" — and it does not prove residual 2. Both
therefore stay on the host in form E. Stripping them, the movable material
is `Dom::F`'s 11 `A` planes (704 rows) and 6 helper planes (768 rows) =
**1,472 rows = 11.8%**, giving `0.118 × (1 − 1/7.62) = ` **10.2%**.

By sumcheck table-points the picture is the same or worse for form E: the
five feed-forward slots are 22.0M of 204.3M = **10.8%**.

**My band for what form E could save at this shape: 10–17%, before any of
its own costs.** That is *narrower and lower* than the draft's single
17.8%, so the draft's conclusion — and the security owner's working ruling
— is **strengthened**, not merely confirmed. The costs the draft prices
against it (the whole `Dom::D` family re-tiling at three blocks, +70 claim
sites, a second masking commitment, two seams, a moved public digest, R-1's
transcript reordering) are unchanged by anything I found. **Do not build
form E at this shape.**

The one measurement that would reverse it is the one the draft names: a
device path for the attention half. I would add the precise trigger:
**form E becomes necessary the moment `Dom::S`'s sumcheck (117M table-points,
57% of the block's total) has a device path**, because at that point the
20% that cannot move becomes the whole critical path.

## 9. Attack on the chaining story

**Where the boundary plane lives: confirmed.** VERIFIED IN THE CODE: block
`k`'s output is `A_X2` (`layout.rs:146`) on its own `A`; block `k+1`'s
input is `A_X` (`layout.rs:127`) on its own `A`. Two planes, two
commitments, the same 393,216 numbers. The draft's three-way table (a
shared caller-fixed root — forbidden by D12 items 1 and 3; an external
endpoint per boundary — allowed but contrary to D17's naming rule; a masked
equality sumcheck between the two provers' own commitments — the one to
build) is a correct reading of D12 and D17.

**Is anything opened twice? No.** VERIFIED: `prove_inner` opens each of
`M`, `A`, `H` and the two endpoints exactly once and drops each owner
immediately after its opening (`protocol.rs:392–407`), and the module's
header states the invariant. Under the draft's option (iii), `A_k` gains
**one** extra claim site for the seam, taking it from 122 to 123, and it is
still one opening. The draft's count — 12 `A`, 12 `H`, 12 `M` and **two**
external endpoints for the whole run — is consistent with D12 items 1–3
and is the count I used for the soundness figure in §3.4.

**The D12 amendment the draft asks for is genuinely needed.** D12 item 2
says "a block is one proof under one transcript with **exactly two external
endpoints**". A twelve-block run under one transcript has two external
endpoints *for the run* and none for the ten interior boundaries. Read
literally, item 2 forbids the very thing option (iii) builds. The draft's
open obligation 5 states this correctly and it should be filed as a pending
ruling in `ZK60_DECISIONS.md`, not left in a memo.

**Is "one block first" consistent with D13? Yes, and the draft says so
itself.** D13 (`ZK60_DECISIONS.md:619`) scopes the first MVP to the hidden
transformer **blocks**; the draft's decision 6 is explicitly a *sequencing*
recommendation ("the first deliverable … the 12-block chain is the second
deliverable"), and its §8 closes with "one block is not a model — D13 says
the hidden transformer **blocks** are what the first MVP must prove". No
conflict. **Confirmed.**

**Transcript order and the memory claim.** The draft's "seam early" order
is available because this module writes its own transcript explicitly
(`protocol.rs:320–378`) — VERIFIED, there is an insertion point after the
`A` root absorb and before the `(β, γ, α)` draw, and the LogUp triple would
still be drawn after `A_{k+1}` and `M_{k+1}` and before `H_{k+1}`, which is
what soundness requires. RECOMPUTED, the peak under that order is
`A_k` (3.47 GiB) + `A_{k+1}` (3.47) at the seam, then `A_{k+1}` +
`H_{k+1}` (4.35) + the largest slot's 1.75 GiB ≈ **9.6 GiB with step S2
applied**, against the draft's 9.9. Same conclusion; and the same caveat as
§7.1 applies — it is only safe with the heavy lock held.

**One thing the draft does not check, and I could not either.** Opening
`A_k` in the middle of the run absorbs its 36 group vectors and 256 columns
into the shared transcript *before* block `k+1`'s challenges are drawn.
That is harmless for soundness (it only adds entropy to later challenges)
but it is a **new hiding surface**: the opened vectors of block `k` are
now public before block `k+1`'s masks are used. The construction's §7
joint-view gate has never been run on a two-block capture, and the
form-E disposition's "a seam between two commitments discloses nothing"
result is a small linear model, not a privacy acceptance. **OMITTED
CONDITION O-3**: the joint-view gate on a two-block capture is a
precondition of step S14, and the draft's S14 acceptance list does include
it — good — but §8's prose ("Yes on memory and yes on time") reads as a
feasibility verdict and should carry the privacy caveat in the same
sentence.

## 10. Attack on the change list and the eleven decisions

### 10.1 Is every step additive under D17, with the toy byte-frozen?

**S1 (split `U8_LEN` from `N`): yes, and I can say why.** All nine
conflated sites evaluate to `256` at the toy because `LOG_N = 8`. Replacing
`N` by a new `U8_LEN = 256` at those nine sites is a textual substitution
with an identical value, so no committed value, no transcript absorb, no
`describe()` line and no `schedule_digest` input changes — **the toy's
2,816,472-byte receipt cannot move**. The acceptance check the draft names
(byte-identical receipt, 46 tests) is the right one and it *can* fail (any
site the editor touches that is genuinely the row width would move
`a_off`). **Confirmed.**

**S2 (free the witness planes and `looked` early): yes, with one
correction.** `looked` can be dropped after `protocol.rs:347` as the draft
says. The witness planes **cannot** be dropped at `protocol.rs:287`: they
are read again at `:296` (`exp_deltas` reads `A_S8`, `A_MX`), `:299`
(`A_E`), `:302` (`A_G8`), `:305` (`A_A16`), and `lookup_values` at `:289`
reads all of them. The earliest safe drop is after `:351`. CORRECTION
C-11 — the step is still right, the line number is not.

**S4 (shape-driven layout): the acceptance check is the strongest thing in
the draft** and I want to say so. "Instantiate the shape-driven layout with
the toy shape and reproduce 213 / 455 / 280 / 384, 120 / 51 sites, 35 / 9
groups, 34 functionals, `M_ROWS 50` and `[1024, 19456, 4608, 6656, 3072,
26624]` exactly" is precisely the check I used to validate my own model
before trusting it at 125M, and it caught nothing for me only because I
built the model that way from the start.

### 10.2 Do the acceptance checks actually fail when the thing is wrong?

Mostly yes. Three do not, as written:

* **S8** ("a prover that writes a nonzero value into a padded position
  produces a receipt the VERIFIER rejects"). Under the draft's own
  recommended fix this check **cannot fire on the plane that matters**: the
  support indicator's entire purpose is to make padded positions
  unconstrained, so writing a nonzero value there is *accepted by design*.
  The test as written would pass trivially while the hole of §2.4 is wide
  open. It must be rewritten as: **a prover that writes a nonzero value
  into `A_X`'s pad and adjusts `D`, `a1`, `a2`, `y`, `ρ`, `σ` consistently
  produces a receipt the verifier REJECTS** — that is the test that catches
  B-1, and it is the "test I ask for above all others" here. **BLOCKING
  B-4** (the check, not just the fix).
* **S9** ("the receipt length equals `encoded_len` exactly"). It will not,
  until B-3 is fixed, because no receipt is produced at all. Reorder: the
  LogUp-sum-claim repair must precede S9.
* **S13** (measure): asks for the phase lines and the byte/row identities
  but not for peak RSS. Add it (O-2).

**Is anything that is a security ruling filed as engineering?** Two:

1. **The weight padding** (§2.4's B-2) is filed nowhere; it is what makes
   seven matmul slots safe on a padded axis and it is a soundness
   condition, not a data-layout convenience.
2. **S4's parenthetical "T-2 is a soundness fix"** is the reverse error:
   an engineering item labelled security (§2.3).

### 10.3 The eleven decisions

| # | the draft's recommendation | my position |
|---|---|---|
| 1 | `log_cols 14 / inv_rate 4 / Q 256` | **agree**, and the soundness cost is now quantified: 0.64 bits per opening, 2^-105.61, whole-block 2^-101.1, twelve-block 2^-97.5 (§3.4). Conditional on B-3. |
| 2 | narrow the input class to `2^12` | **agree in direction, the arithmetic is wrong** (`wrho 29` not 27, three `D` limbs not two) and it needs `xres1` measured (§4.5, O-1). Not a substitute for B-1. |
| 3 | public support indicator for the pad | **agree only as amended by B-1 and B-2**; as written it is unsound, and it needs indicators on four domains, not two (§2.4). |
| 4 | pad `d 768 → 1024`, `12 → 16` heads, KV group high | **agree**; the map really is free and `d_pad = H_pad · d_h` holds. The construction-time assert on that equality is worth having. Note the padded head slots are `{3,7,11,15}`, not `[12,16)` (C-1). |
| 5 | third byte limb on `ρ_s`, `σ_s` | **agree**, arithmetic confirmed (§4.6). |
| 6 | one block first, not twelve | **agree**, consistent with D13 (§9). |
| 7 | fix the seam-early transcript order now | **agree**; it is free now and expensive later, and my own residency numbers reproduce the 9.6 vs 13.5 GiB gap. |
| 8 | free the witness planes and `looked` early | **agree**, with C-11 on where. |
| 9 | do not change the table set | **agree**; the `sym` lever saves ~9M not ~11M lookups and is still not worth taking. |
| 10 | do not build form E at this shape | **agree, more strongly**: the ceiling is 10–17%, not 17.8% (§8). |
| 11 | re-derive the soundness figure before any published number | **agree, and §3.4 does it**: about 101 bits for one block, about 97 for a twelve-block pass, both projections. |

### 10.4 What is still missing after this check

The draft's own "did not check" list is honest and mostly discharged here
(opening groups: §3.2; soundness at the new rate: §3.4; the sumcheck rate:
still open). What remains:

* **The sumcheck rate.** Neither the draft nor I verified the table count
  inside the FFN's measured `zero-check F`. It is ~11% of the time model.
* **`zk.rs`'s layer layout** beyond the mask machinery. Not read.
* **The wire codec's bounded decode at 38.9 MiB frames**
  (`wire.rs:38–60`, `MAX_WIRE_BYTES = 4 MiB` today). C2 of the endpoints
  change list applies; I did not audit the arithmetic.
* **`private-block-kernel`'s generalisation.** The draft recommends
  generalising the declared reference over a shape struct and I agree, but
  I did not read that crate.
* **The whole privacy question.** Nothing here touches it.

## 11. Verdict

In plain words: **most of this draft is right, and the one place it is
badly wrong would have shipped a proof that a cheating prover could beat.**
Its shape is taken from the project's own records and checks out; its row
totals reproduce the module's assertions at the toy and then give 5,681 `A`
rows at the real shape, which I get too; its receipt figure of about 40.6 MB
is right to within a third of a percent; its two integer-window findings —
the norm's 0.21 bits of margin and the softmax's four-fold jump — are right
to the last digit; and its recommendation not to build the two-prover
"form E" at this size survives, with a tighter and lower number than it
gives (10–17% saving, not 17.8%). What falls is the fix it proposes for
padding. When the real width 768 is rounded up to 1,024, the extra 256
columns of the hidden input are read by one relation the draft treats as
harmless — the sum of squares inside the norm — and neither of the two
fixes it discusses forces those columns to zero. A prover can put junk
there, get any divisor it likes for the norm, and so produce a "correct"
block output that is not the block applied to the committed input. Two
smaller blockers sit beside it: the construction as designed **cannot
produce a proof at all** at the wider row size, because the single
lookup-summation claim then spans planes of three different widths and the
module's own audit refuses it; and the weight matrices must be
zero-padded, which nothing in the draft says. All three are cheap to fix and
none of them changes the plan. **The security owner's working ruling —
generalise the built single-prover form first, measure it, let the
measurement decide on form E — still stands, and this check strengthens
it.** What should change is the order of the change list (the
lookup-claim repair before the row-geometry step), the content of decision
3 (the support indicator must cover the two row-sum slots and the weight
padding), and one acceptance test that as written cannot fail.

## 12. ERRATA AND CONDITIONS FOR ACCEPTANCE

### BLOCKING

| # | what | evidence | what must happen |
|---|---|---|---|
| **B-1** | The pad fix is unsound. `SC_SS`/`SC_SSM` sum `x²`/`x1²` over the **padded** `Dom::D` (`argument.rs:544–549`, `:552–557`), hosted by `SC_TZC`'s `D² + a1 − C_eps` (`:591–592`). Neither the support indicator (which switches `c2` off, leaving `A_X`'s pad an unconstrained field element) nor the witness fill (which leaves it free in int16) forces those columns to zero. RECOMPUTED: under the fill the prover can move `D` from 2,300 to 524,357 on the real checkpoint; under the indicator, anywhere below 2^24. The endpoint does not help — at 125M it binds the true 393,216 words only (draft §6 item 4). | §2.4 | Either carry the support indicator on `SC_SS`, `SC_SSM`, `SC_RS` and the IO slots as well as on the constraint groups, **or** add an explicit degree-2 pad-zero term `(1 − supp(x))·x = 0` on `A_X` and `A_X1`. Redo §3.7 of the draft with "the pad holds zeros" as a *proved* fact. |
| **B-2** | The seven matmul slots are safe on a padded axis **only because the public weight is zero at every padded index** (`fold_rows_i8` / `fold_cols_i8`, `zkp-core/src/mle.rs:116,140`). The draft never states this. | §2.4 | State the zero-padding of every weight matrix (both axes) as a construction obligation, with a construction-time check that the folded weight vector vanishes off the support. |
| **B-3** | The construction **cannot produce a proof at `log_cols = 14`**. `logup_sum_claim` (`protocol.rs:52–62`) has one part per `H` plane; at `LOG_N = 14` the `H` domains are 8, 13, 17, 19, 20 and 22, straddling the row width, so `part_key` yields three different column-weight keys and `check_opening` (`protocol.rs:161–163`) refuses — with `zkp-core/src/pcs.rs:817` asserting below it. Absent from the draft. | §3.2 | Lift `Dom::L` and `Dom::Tab` to `log = LOG_N` (zero extra rows), and define the padded `U8` table values so the proved set is still the 256 bytes. Sequence this **before** step S9. |
| **B-4** | Step S8's acceptance check cannot fire. "A prover that writes a nonzero value into a padded position produces a receipt the VERIFIER rejects" is exactly what the support indicator is designed to permit. | §10.2 | Rewrite as: a prover that writes nonzero values into `A_X`'s pad **and adjusts `D`, `a1`, `a2`, `y`, `ρ`, `σ` consistently** must be rejected. This is the one test that catches B-1. |

### CORRECTIONS

| # | the draft says | the evidence | it must say |
|---|---|---|---|
| **C-1** | §3.7: the padded heads are "a head index in `[12, 16)`" | GQA group is 3 (`ATTENTION_INTEGER_SPEC.md:102–106`), and §2.3 puts the KV group in the **high** bits | the padded head slots are `{3, 7, 11, 15}` — one per KV group, not a contiguous tail. The support table is not a prefix mask. |
| **C-2** | §3.2: the study records "eGate −3, eUp −3, eA −3, eH 0, eZ 1" | `results/m125_int8_calibration.json`, layer 1: `eGate −4, eUp −3, eA −4, eH 0, eZ −1` | quote the recorded values, per layer |
| **C-3** | T-1: `protocol.rs:293` "changes meaning silently"; "three of the eight conflated sites fail loudly" | there are **nine** sites; four fail loudly on the slot table-length check (`argument.rs:281–283`), two of those panic first on a 256-element array, and `:293`'s mis-bucketing is caught by the LogUp identity (the code says so at `:292`) | nine sites; the widening breaks the build/prover loudly; `:293` is a completeness matter, not a soundness one |
| **C-4** | T-2 / S4: `argument.rs:626` is "the same shape of hole as D17"; "T-2 is a soundness fix" | `assert_eq!(w.len(), rows)` at `zkp-core/src/mle.rs:118` fires for every non-power-of-two `outer`; and `D` must be the padded width anyway or the public gain tables (`argument.rs:706–707`) fail the same length check | class (a) mechanical: a prover-side **panic**, not a weakened statement. The named refusal at construction is still worth writing, as hygiene. |
| **C-5** | decision 3: "one public `Fp2` table per padded domain (`Dom::D` 8 MB, `Dom::S` 67 MB)" | four domains pad and carry inhomogeneous relations: `Dom::D` 8.4 MB, `Dom::Q` 8.4 MB, `Dom::S` 67.1 MB, `Dom::Ht` 0.13 MB; and `table_of` clones each per slot | price four tables and their per-slot copies; `causal_mask` is a **token**-support table and does not cover the head axis (M-3) |
| **C-6** | §3.8 / §4: "`NORM_WRHO 29 → 32`, drop **2** lookups"; `Dom::D` 36 lookups, 18 helpers; `H` 7,082 data / 7,186 rows / 51 sites | `layout.rs:321`, `:323`, `:329`, `:331` — **four** sites (`ρ`,`σ` of `norm_a` *and* `norm_m`) | drop **4** lookups: `Dom::D` 34 lookups, 17 helpers, `H` 7,018 data / **7,120** rows / **50** sites; U8 lookups **98,582,528**. Under decision 2's branch instead: 40 / 20 / 7,210 / **7,318** / 101,728,256. Recompute after the ruling, not before. |
| **C-7** | §10.3: `A_GROUPS` "kept at 35", unchecked | `limb_off(k) % N` is `32k mod 256` at the toy (eight distinct, `k=8` wraps) and `512k mod 16384` at 125M (**nine** distinct); model validated against the declared 35/9 at the toy | `A_GROUPS = 36`, `H_GROUPS = 9` (after B-3). Receipt: `A` opening 21,626,880 B, one block **40,747,256 B = 38.86 MiB**, twelve blocks 489 MB |
| **C-8** | §3.4 table: `p ≤ 2^{F_P} = 512`; `p·Sum + ρ_s = 2^27.00` | the **proved** bound is `p < 2^10` (`scaled(A_PL1, 64)`, `layout.rs:361`) | proved bounds: PV 2^25.99, `p·Sum + ρ_s` 2^28.00. Still 2^21 below 2^49; a premise table must quote what is proved |
| **C-9** | §3.3 / obligation 6: at 8B "the construction cannot express it" | the ceiling is the four-limb + `1 << (32 − wrho)` idiom; D16 item 3's four-limb rule governs the **square** relation (`D`,`a1`,`a2`), not `ρ`/`σ`, which appear only linearly. RECOMPUTED: a fifth `ρ`/`σ` limb reaches `wrho 40` with nothing wrapping at 8B (`y·D·2^{tn+1} = 2^40.0`, `D² + a1 = 2^42.0`) | the 8B norm needs **a fifth `ρ`/`σ` limb and a rewritten coefficient** (four more `Dom::D` planes), not a new construction |
| **C-10** | decision 2: at `2^12`, "`wrho` 27, 5 bits of margin, `D` two limbs" | exact: `Dmax = 113,483`, `den = 2^28.792` | `wrho 29`, **3.2 bits**, `D` **three** limbs. `wrho 27` needs a class near `2^10`; two `D` limbs need a class near `2^11` |
| **C-11** | S2: drop the witness planes "after `a_data` is filled (`protocol.rs:287`)" | the planes are read again at `:289` (`lookup_values`), `:296`, `:299`, `:302`, `:305` | the earliest safe drop is after `protocol.rs:351` |
| **C-12** | T-10: the causal mask is "built twice" | `causal_mask()` at `argument.rs:611` and `:840`, each **cloned** by `table_of` (`:206`); plus `exp_deltas` materialises a third `2^22` `Vec<i64>` (`protocol.rs:221–229`) | two 67 MB copies live inside each of two slots, plus 42 MB of `Vec<i64>` cubes: about +110 MB on the peak |
| **C-13** | §7.3: opening rate 0.135 ms/row | 1.741 s covers `A + H + W + M` = 16,500 rows | 0.1055 ms/row; the block's opening term is 1.4 s. Table-points 204.3M, not 212.7M |
| **C-14** | §7.4: form E's ceiling is 17.8% | the existing GPU prover does not prove `norm_m` (D12 item 4) or residual 2, so only `Dom::F`'s 1,472 rows (11.8%) move; by table-points 10.8% | **10–17%**, band not point |
| **C-15** | §4: the `sym` lever is worth "about 11 million" lookups | 9 `sym` pairs over their domains; one lookup saved per pair per position | **7,208,960** saved. Recommendation unchanged |

### OMITTED CONDITIONS

| # | condition |
|---|---|
| **O-1** | Decision 2 must declare a class for `xres1` (norm_m's input) as well as `x_in`, and `xres1` is **not** in the calibration study. Measure `\|xres1_int\|` on the real checkpoint before fixing the class. (`x` itself is fine: absmax 20.60 at `eX = −2` → `\|x_int\| ≤ 83`, 49× inside a `2^12` class.) |
| **O-2** | The one-block measurement (S13) must run detached under `flock /tmp/zk-heavy.lock`, with step S2 already applied, and must record **peak RSS** as an acceptance figure. 11.0 GiB unmitigated / 9.6 GiB with S2, on a box with 14.2 GiB available and a recorded history of OOM under concurrent runs: "fits with 3 GB of headroom" is true only if nothing else is running. |
| **O-3** | §8's "yes on memory and yes on time" must carry the privacy caveat in the same sentence: opening `A_k` mid-run publishes its opened vectors before block `k+1`'s masks are used, and the joint-view gate has never been run on a two-block capture. (S14's acceptance list already asks for it; §8's prose does not.) |
| **O-4** | The module's own integer premise text (`layout.rs:281–309`, including "The LogUp multiplicities (at most 61,440) cannot wrap") must be rewritten for the new profile as part of D16 item 5, with the bounds of §4 of this check. |
| **O-5** | A pending ruling, not a note: D12 item 2's "exactly two external endpoints" must be restated for a **run** rather than a block before any multi-block work, and filed in `ZK60_DECISIONS.md` the day it is made. |
| **O-6** | Multiplicities are never range-checked (`is_multiplicity` excludes the three planes from every lookup list). That is sound at 98.6M against a 2^64 field, but it is a property the new profile's premise should state explicitly rather than inherit. |

(check complete)
