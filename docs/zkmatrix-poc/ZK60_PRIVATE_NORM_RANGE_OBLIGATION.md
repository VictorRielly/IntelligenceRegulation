# The private block's norm denominator: the half-p isqrt alias, and what must be proved before the geometry is widened

**Status: DRAFT — delegated analysis.** Lane `zk60-private-norm-range`,
worktree `../wt-zk60-normrange`, off the main tip `d399b32`. SOUNDNESS only:
nothing here claims a privacy property, and nothing in this lane changes any
prover or verifier behaviour. Tests only.

**Question put by the security owner.** Obligation R09 of
`ZK60_FABLE_SECURITY_OBLIGATIONS.md` records a soundness gap in the PUBLIC-IO
attention prover: the RMS-norm denominator `D` is never range-proved directly,
and over `p = 2^64 - 2^32 + 1` the family `D = k + (p-1)/2` satisfies every
isqrt relation for every input row. That profile escapes only because the
alias's remainders (~2^42) do not fit two 16-bit limbs; at three or more
remainder limbs — what a real model needs — the verifier accepts a wrong norm
output. **Does the newer PRIVATE module (`hashline/src/private_block/`, two
norms `norm_a` and `norm_m`) admit the same alias, at its fixed profile and at
wider ones?**

---

## 0. The answer, first

**Yes, the private module range-proves `D` DIRECTLY, and the half-p alias is
REFUSED at the fixed profile by that direct range fact — not by a width
coincidence.** `d`, `a1` and `a2` are each committed as three byte limbs in a
packed `Dom::L` plane, every limb is looked up in the 256-entry U8 table, and
`SC_TZC` carries its own zero-check term `d - dl` pinning the reconstruction
(`argument.rs:587`, `mu[1]`). `(p-1)/2 = 2^63 - 2^31` has no byte-limb
encoding at any limb count this field can express, so the alias dies on a fact
about `d` itself.

Measured, both norms, both forms a prover has (§4):

| alias form | predicted catch | measured catch |
| --- | --- | --- |
| `d = k + (p-1)/2`, `d`'s limbs left honest | `Slot(SC_TZC)` — the `d - dl` pin | `Slot(SC_TZC)` |
| the same, limbs made to RECONSTRUCT the alias | `LogUp` — `l0` has no U8 row | `LogUp` |

The catch MOVING from slot 2 to the LogUp sum claim between the two forms is
the evidence that the range fact is present and load-bearing. In the second
form every relation of all twenty-three slots holds in `F_p` — the verifier
runs them all before the `H` opening, so a LogUp catch *is* the proof that
none of them fired.

**But the margin is not where it looks.** At the fixed profile there are three
exclusions, and only the first survives widening:

1. **(R2), the byte limbs of `d`** — structural, holds at every expressible
   limb count. **Keep it.**
2. **the byte limbs of `a1`, `a2`** — a width argument. It holds at three
   limbs and **LAPSES at four**, which is exactly what an int24 residual class
   at width 4096 needs (§3, §5).
3. **the exact 29-bit remainder window** — a width argument with **1.04 bits**
   of margin at int24/4096 and **0.08 bits** at int24/8192 (§5).

So the private module is in a genuinely better position than `attention.rs`:
there the *only* exclusion was a width coincidence, here the primary one is a
range proof. But two of the three defences expire on the way to real model
shapes, and the surviving one has to be widened deliberately (§6).

---

## 1. The relations, as equations over `F_p`, with file:line

Constants (`layout.rs:52-55`): `tn = 11`, `Cn = 1024`, `Ceps = 1`,
`wrho = 29` (advertised AND proved, §5). Geometry `T = 32`, `d_model = 16`.

### 1.1 The planes

| plane | id | domain | what it holds |
| --- | --- | --- | --- |
| `A_D` / `A_DM` | `layout.rs:114`, `:117` | `Dom::T`, 5 vars | the denominator of norm_a / norm_m |
| `A_DSQ` / `A_DSQM` | `:115`, `:118` | `Dom::T` | its square |
| `A_LIMB` / `A_LIMBM` | `:123`, `:125` | `Dom::L`, 9 vars = 512 | sixteen 32-entry sub-planes; **0..3 `d`, 3..6 `a1`, 6..9 `a2`** (`:122`), nine used, seven zero |
| `A_Y` / `A_YM` | `:130`, `:141` | `Dom::D`, 9 vars | the norm output (int8 class) |
| `A_NR0..3` / `A_MR0..3` | `:131`, `:142` | `Dom::D` | four byte limbs of `rho` |
| `A_NS0..3` / `A_MS0..3` | `:132`, `:143` | `Dom::D` | four byte limbs of `sigma` |

`N_LIMBS = 9` (`layout.rs:200`) is the count of used sub-planes per site: three
values, three limbs each.

### 1.2 The isqrt block — `SC_TZC`, slot 2, 5 main rounds, degree 3

`argument.rs:558-595`. Table indices are captured from the builder
(`:570-581`); `l3(o) = v[o] + 256 v[o+1] + 65536 v[o+2]` (`:584`). Writing
`dl = l3(i_limb)`, `a1 = l3(i_limb+3)`, `a2 = l3(i_limb+6)` and the same with
`m` for norm_m, the slot's polynomial (`:583-593`) is

```
eq(tau, t) * [ mu0 (dsq  - d*d)        <- (R1)   argument.rs:587
             + mu1 (d    - dl)         <- (R2)   argument.rs:587   THE RANGE PIN
             + mu2 (2d   - a1 - a2)    <- (R3)   argument.rs:587
             + mu3 (dsqm - dm*dm)      <- (R1m)  argument.rs:588
             + mu4 (dm   - dlm)        <- (R2m)  argument.rs:588
             + mu5 (2dm  - a1m - a2m)  <- (R3m)  argument.rs:588 ]
+ nu0 eq(r_t,  t) (dsq  + a1  - Ceps)  <- (R4)   argument.rs:591
+ nu1 eq(r_t2, t) (dsqm + a1m - Ceps)  <- (R4m)  argument.rs:592
```

`SC_TZC` is a HOST slot (`layout.rs:477`, `:502`): its claimed sum is a public
zero plus the two hosted private sums `SC_SS` (`sum_i x_in^2` at `r_t`,
`argument.rs:544-549`) and `SC_SSM` (`sum_i xres1^2` at `r_t2`, `:552-557`).
So (R4) reads `dsq + a1 - Ceps = SS(r_t)`, i.e. **`dsq + a1 = SSe`** with
`SSe = Ceps + sum_i x^2`, pinned at a random row point.

### 1.3 The range lookups — `SC_LZC`, slot 3, 9 main rounds, degree 4

`layout.rs:313-316`: `Dom::L`'s two lookups are `byte(A_LIMB)` and
`byte(A_LIMBM)` — the WHOLE 512-entry plane of each, every entry into the
256-entry U8 table, through one helper (`argument.rs:598-605`). 1024 byte
lookups (`layout.rs:745`). **This is the lookup that makes (R2) a range fact.**

### 1.4 The division block — `SC_DZC`, slot 14, 9 main rounds, degree 4

`argument.rs:699-748`, with `k_num = 2 Cn`, `k_dv = 2^tn`, `k_den = 2^(tn+1)`
(`:716`) and `l4(o) = at(o) + 256 at(o+1) + 65536 at(o+2) + 2^24 at(o+3)`
(`:720`). Per element `(t, i)`, with `d` read as a 5-var slice broadcast over
`i` (`:709-710`):

```
c0 = 2 Cn gamma_a[i] x  + 2^tn d  - 2^(tn+1) y  d  - rho    = 0   argument.rs:726
c1 = sigma  + rho  + 1  - 2^(tn+1) d                        = 0   argument.rs:727
c6 = 2 Cn gamma_m[i] x1 + 2^tn dm - 2^(tn+1) nm dm - rho_m  = 0   argument.rs:733
c7 = sigma_m + rho_m + 1 - 2^(tn+1) dm                      = 0   argument.rs:734
```

with `rho = l4(A_NR0)`, `sigma = l4(A_NS0)`, `rho_m = l4(A_MR0)`,
`sigma_m = l4(A_MS0)`.

### 1.5 The remainder window is EXACT, not a limb multiple

`layout.rs:320-323` (norm_a) and `:328-331` (norm_m):

```
byte(A_NR0+k) for k = 0..4        -> every limb in [0, 256)
scaled(A_NR0+3, 1 << (32 - 29))   -> 8 * l3 in [0, 256), so l3 < 32
```

Both lookups together give `l3 in [0, 32)` and therefore
**`rho, sigma in [0, 2^29)` exactly**. Same for `sigma` and for norm_m. This
is strictly stronger than `attention.rs`, whose R10 proves only the 16-bit
chunk multiple `[0, 2^32)` while advertising `wrho = 29` — and that slack is
precisely what R09's alias lives in there.

### 1.6 The witness side (not a proof, recorded for completeness)

`witness.rs:157-208` builds both norms from one `rms_norm`. Its host-side
refusals `d >= 1<<24 || a1, a2 outside [0, 2^24)` (`:174`) and
`rho, sigma >= 2^29` (`:194`) are HOST checks; the proof obligations above are
what the verifier enforces.

---

## 2. Is `D` range-proved directly? YES — the derivation

Every limb of `A_LIMB` and `A_LIMBM` is a U8 member (§1.3), so
`l0, l1, l2 in [0, 256)` as integers. Then:

* **(R2) forces `d = l0 + 256 l1 + 65536 l2` in `[0, 2^24)` over `Z`**, because
  the right side is an integer below `2^24 < p` and the relation is an
  equality in `F_p`. Likewise `a1, a2 in [0, 2^24)`.
* `2d < 2^25` and `a1 + a2 < 2^25`, both below `p`, so **(R3) holds over `Z`**:
  `a1 + a2 = 2d`, hence `0 <= a1 <= 2d`.
* `d^2 < 2^48` and `a1 < 2^24`, so `dsq + a1 < 2^49 << p` and **(R4) holds over
  `Z`**: `SSe = d^2 + a1`.
* Therefore `d^2 <= SSe <= d^2 + 2d < (d+1)^2`, i.e. **`d = isqrt(SSe)`
  exactly**, for every row and every profile in which the three displayed
  bounds stay below `p`. `Ceps = 1` gives `SSe >= 1`, so `d >= 1` and the
  division denominator is nonzero.

This is the argument `ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md` §2.1 already
records as PROVED-BY-INSPECTION. **It is correct.** What this lane adds is
that the ALIAS had never been tested at the verifier — the only `A_D` tamper
in either module is `w.planes[A_D][2] += 1` inside a loop that accepts any
error (`private_block/tests.rs:149`, `private_attention/tests.rs:154`), which
neither reaches the alias nor names a catch — and that the derivation's
dependence on the limb counts had never been written down (§5, §6).

**The alias is excluded because `D = k + (p-1)/2` is at least `2^62` for every
`k`, and `[0, 2^24)` does not contain it.** Not because of any remainder width.

### Maximum `D`, and the limb counts each geometry needs

`Dmax = isqrt(Ceps + d_model * xmax^2)`
(`results/zk60_private_norm_range/alias_arithmetic.txt`, §4):

| geometry | max `SSe` | max `D` | byte limbs for `D` | for `a1 <= 2D` | `2^(tn+1) D` |
| --- | --- | --- | --- | --- | --- |
| **d=16, int16 (FIXED)** | 2^34 | 2^17 = 131072 | **3** | 3 | 2^29 |
| d=4096, int16 | 2^42 | 2^21 | 3 | 3 | 2^33 |
| **d=4096, int24** | 2^58 | **2^29** | **4** | **4** | 2^41 |
| d=2048, int24 | 2^57 | 2^28.5 | 4 | 4 | 2^40.5 |
| d=8192, int24 | 2^59 | 2^29.5 | 4 | 4 | 2^41.5 |

**Three byte limbs cover the fixed profile with 7 bits to spare, and even
width 4096 with an int16 residual. An int24 residual class at width 4096 needs
FOUR** — on `d`, on `a1` and on `a2`.

---

## 3. The alias, constructed for this module, and what refuses it

### 3.1 Which `d` the relations admit without (R2)

Suppose (R2) were absent. (R3) with `a1, a2` byte-limbed gives
`2d = s` over `Z` for some `s in [0, 2^25)`, so `d = s/2` in `F_p`:

* `s` even -> `d = s/2 < 2^24`, the honest branch;
* `s` odd -> `d = (s + p)/2 = k + (p-1)/2` with `k = (s+1)/2`, **the R09
  family**.

(R4) then fixes `a1 = SSe - d^2`, and since
`d^2 = k^2 - k + inv(4)` (verified in-test,
`norm_alias.rs::the_alias_satisfies_every_norm_relation_in_the_field`),

```
a1 = SSe + (p-1)/4 + k - k^2   (mod p),        (p-1)/4 = 2^62 - 2^30
```

### 3.2 What the alias does to the DIVISION — and why the remainder width is
### not what saves this module

`2^(tn+1) d = 2^tn (2k - 1)` and `2^tn d = 2^(tn-1)(2k - 1)` are **small
integers** for small `k`. So (C0)/(C1) become an exact division by
`den' = 2^(tn+1)(k - 1/2)` with the correct rounding bias: **the alias is a
norm with a half-integer denominator.** Its remainders lie in `[0, den')`, and
`den' < den <= 2^29`, so they sit **inside** the honest 29-bit window.

This is the decisive difference from `attention.rs`. There the alias's `a1`
had to fit `2^32`, which forces `k ~ 2^31`, which forces `den' ~ 2^42` and
`y = 0` on every element — and the two 16-bit remainder limbs are what refuse
it. Here `k` is free to be small, the remainders are honest-sized, and the
remainder width does nothing. Only a fact about `d` can stop it.

### 3.3 The three exclusions at the fixed profile, and their margins

`results/zk60_private_norm_range/alias_arithmetic.txt`, §2, §5, §6, §6b:

1. **(R2), the byte limbs of `d`.** `d >= 2^62` for every `k`; the widest
   expressible byte window is `2^56` (seven limbs; eight is not expressible,
   `2^64 > p`) and the no-wrap bound of §6 caps it at four anyway.
   **Refuses at every limb count. Structural.**
2. **The byte limbs of `a1`, `a2`.** (R3) bounds `k < 2^(8 na)`. With
   `na = 3`, `k < 2^24`, so `k^2 <= 2^48` is negligible against `(p-1)/4` and
   `a1 >= 2^61.999` for every admissible `k`. **Refuses at `na <= 3`.
   ADMITS at `na >= 4`:** at `k` near `isqrt((p-1)/4 + SSe) ~ 2^31` the same
   `a1` is about `2^30` and fits a four-limb window. The step
   `a1(k) - a1(k+1) = 2k ~ 2^32` equals the window, so one `k` lands inside
   for all but a `~6/2^32` fraction of `SSe`.
3. **The exact remainder window, through (C1).** `sigma + rho + 1 = 2^tn(2k-1)`
   with `rho, sigma in [0, 2^wrho)` needs `2^tn(2k-1) <= 2^(wrho+1) - 1`, i.e.
   `k <~ 2^(wrho - tn)`. The alias's `k` is pinned near `2^31` by exclusion 2,
   so this refuses iff `wrho < tn + 31`, i.e. iff `Dmax <= 2^29`:

   | geometry | honest `wrho` | alias `k` | (C1) verdict |
   | --- | --- | --- | --- |
   | d=16, int16 (FIXED) | 29 | 2^31.000 | refuses, margin **13.0 bits** |
   | d=4096, int16 | 33 | 2^31.000 | refuses, margin **9.0 bits** |
   | d=4096, int24 | 41 | 2^31.044 | refuses, margin **1.04 bits** |
   | d=8192, int24 | 42 | 2^31.085 | refuses, margin **0.08 bits** |

**At the fixed profile all three refuse. At the int24/4096 profile only (R2)
refuses with room; exclusion 2 has lapsed and exclusion 3 has one bit left.**

### 3.4 The no-wrap boundary: four byte limbs, exactly

(R4) is an integer identity only while `d^2 + a1 < p`. With `n` byte limbs on
each: `n = 3` is safe with enormous room; **`n = 4` is safe with ZERO margin**
— `(2^32-1)^2 + (2^32-1) = p - 1` exactly; `n = 5` wraps. So the widening to
int24/4096 lands on the last limb count the field allows, and anything wider
than `int24 x 4096` in the `SSe` sense needs a different construction, not
another limb.

---

## 4. The tests: predicted, then measured

`hashline/src/private_block/norm_alias.rs` (new; registered by the single line
`#[cfg(test)] mod norm_alias;` in `private_block.rs:68` — the only edit to an
existing Rust file in this lane). The harness follows `tamper.rs`: the witness
planes are edited BEFORE the `A` commitment, `prove_inner` runs to completion,
the real `verify_inner` must reject, the catch is asserted by slot INDEX or by
the `H:` prefix of the opening that carries the one value-0 LogUp sum claim,
and an honest proof through the same path is asserted beside every case.

Plane values are `i64` and reach the field through `Fp::from_i64`
(`protocol.rs:286`), so any field element is writable: `v` below `2^63`,
`v - p` above it (`norm_alias.rs::to_plane`).

**The alias witness** (`norm_alias.rs::write_alias`), on one row of one site,
with every dependent plane made as consistent as the relations allow:
`d := k + (p-1)/2` for the honest `k`, then `dsq := d^2` (R1),
`a1 := SSe - dsq` (R4), `a2 := 2d - a1` (R3), and — with the quotient `y` LEFT
HONEST, so that nothing downstream of the norm changes —
`rho := 2 Cn g x + 2^tn d - 2^(tn+1) y d` (C0) and
`sigma := 2^(tn+1) d - 1 - rho` (C1). The remainder limbs are written as
`(value, 0, 0, 0)`, the isqrt limbs as `(value, 0, 0)`.

| # | case | predicted (written before running) | measured |
| --- | --- | --- | --- |
| 1 | norm_a, `d`'s limbs left honest | `Slot(SC_TZC)` — only `mu[1]` is false in that slot | **`Slot(SC_TZC)`** |
| 2 | norm_m, `dm`'s limbs left honest | `Slot(SC_TZC)` | **`Slot(SC_TZC)`** |
| 3 | norm_a, limbs reconstruct the alias | `LogUp` — every slot relation holds; `l0` has no U8 row | **`LogUp`** |
| 4 | norm_m, limbs reconstruct the alias | `LogUp` | **`LogUp`** |

Cases 1-2 isolate the (R2) pin: `a1`, `a2`, `rho` and `sigma` all follow the
alias, so `mu[0]`, `mu[2]`, the `nu` host term and both `SC_DZC` division
terms hold; only `d - dl` is false. (Stated, not argued away: `a1`'s and
`a2`'s low limbs are out of the byte class too, but that can only be caught by
the `H` opening, which runs after all twenty-three slots — slot 2 is the first
catch, and cases 3-4 are what isolate the byte class.)

Cases 3-4 are the strongest form. `l0 = d`, `l1 = l2 = 0` satisfies (R2) in
`F_p`, so every relation of every slot now holds and the verifier reaches the
`H` opening — which is itself the measurement that none of them fired. The
only falsehood left is that `l0` has no row in the U8 table; the prover counts
the miss into entry 0 (`protocol.rs:293`) so the histogram totals still match,
and nothing but the value-0 LogUp sum claim can see it.

**Two arithmetic tests carry the paper analysis in code**, with no prover:

* `the_alias_satisfies_every_norm_relation_in_the_field` — replays (R1), (R3),
  (R4), (C0), (C1) in `F_p` for six values of `k` and asserts the alias
  satisfies every one exactly, including `2d = 2k - 1` (the odd branch),
  `d^2 = k^2 - k + inv(4)`, and `2^(tn+1) d = 2^tn(2k-1)`. **If this failed,
  cases 1-4 would be catching broken arithmetic rather than a missing range
  fact.**
* `the_denominator_range_fact_excludes_the_alias_at_every_expressible_width` —
  the alias `d >= 2^62` for every `k`; its `a1 >= 2^61` for every `k` the
  three-limb window admits; and the same `a1` is about `2^30` near
  `isqrt((p-1)/4 + SSe)` and **does** fit four byte limbs.
* `the_limb_count_the_widened_geometry_needs` — the table of §2, plus the
  `n = 4` no-wrap boundary `(2^32-1)^2 + (2^32-1) = p - 1` and the saturated
  remainder window `2^(tn+1) Dmax = 2^29`.

**THE WIDER SETTING COULD NOT BE REACHED FROM A TEST, and no production change
was made to reach it.** `N_LIMBS` (`layout.rs:200`), the three-term `l3`
reconstruction (`argument.rs:584`), `A_SITES[SC_TZC] = 22` (`layout.rs:512`),
`NORM_WRHO` and the hard-coded `1 << (32 - NORM_WRHO)` (`layout.rs:321`) are
all production constants, and widening any of them changes the prover, the
declared schedule and the schedule digest. The wider-setting leg is therefore
delivered as the arithmetic of §3.3 and the two arithmetic tests, not as a
proving run.

---

## 5. Every other place in the block where exactness rests on a width

Checked: both norms, the softmax denominator and quotient, the score
requantisation, and all six requantisations of the attention and feed-forward
halves.

**The invariant that makes the block sound, stated once.** An alias exists
exactly where a committed value enters a relation under a NON-UNIT constant
`c` and is not independently range-proved: the alias family is
`{v : c*v = small}`, and for `c = 2^j` it is the `j`-adic family whose `j = 1`
member is R09's. Auditing every such site in `argument.rs`:

| relation | non-unit coefficient on | that value's own range proof |
| --- | --- | --- |
| (R3), (C0), (C1), c6, c7 | `2 d`, `2^tn d`, `2^(tn+1) d` | **(R2), byte limbs — the subject of this memo** |
| `host_wo` `:743` | `2^7 ao` | int16: two byte limbs with the `+32768` offset (`c3` `:729`, `layout.rs:324`) |
| `host_dmm` `:744` | `2^6 z16` | int16 limbs (`c10` `:738`, `layout.rs:334`) |
| `host_g` `:782` | `2^7 g8` | the activation PAIR lookup: `g8 + 128` is a table index in `[0, 256)` (`f_act` `:777`) |
| `f0` `:774` | `2^14 h16` | int16 limbs (`f2` `:776`) |
| `rope` `:817` | `2^7 qr8 / kr8` | `sym()` in `[-127, 127]` (`layout.rs:345`, `:355`) |
| `host1/host2` `:821-825` | `2^7 q8/k8/v8`, `2^9 o8` | `sym()` |
| `host_s` `:869` | `2^6 s8` | `sym()` |
| `c2` `:860` | `2^9 mask E`, `p_soft * Sum` | `E` by the fused exp lookup; `p_soft < 2^10` by `scaled(A_PL1, 64)`; `Sum` by `c3` |
| `c3` `:861` | **coefficient 1 on `Sum`** | none needed — a unit coefficient admits no alias |

**Every committed value under a non-unit coefficient is independently
range-proved. That is the property to preserve when widening**, and the norm
denominator is the only one whose range proof is a limb decomposition rather
than a class lookup.

The width facts that are coincidences, in descending order of how close they
are to biting:

* **W1 — the norm remainder window is exactly saturated, zero margin.**
  `den = 2^(tn+1) Dmax = 2^12 * 2^17 = 2^29`, and the proved window is `2^29`.
  `D = 2^17` is attained on a saturated int16 row. Any widening breaks
  COMPLETENESS here before it breaks soundness: at d=4096/int16 `den` reaches
  `2^33`, at d=4096/int24 `2^41`.
* **W2 — a shift trap in the layout.** `scaled(A_NR0+3, 1 << (32 - NORM_WRHO))`
  (`layout.rs:321`, `:323`, `:329`, `:331`) assumes a FOUR-limb `rho` and
  `wrho <= 32`. At `wrho = 41` the subexpression `32 - NORM_WRHO` underflows
  `u32` and the shift panics in debug / is masked in release — the same shape
  as defect D-2 recorded in `witness.rs:53-63`. A widening MUST rewrite this
  as `1 << (8 * n_rho_limbs - wrho)`.
* **W3 — the softmax window is exactly saturated too.** `sr, sg in [0, 2^14)`
  exactly (`layout.rs:362-363`), honest `Sum <= T * 2^fE = 2^14`, so
  `sg = Sum - 1 - sr <= 2^14 - 1`. Zero margin. At `T = 4096`, `Sum` reaches
  `2^21` and `wrho_s` must be at least 21.
* **W4 — `Sum` is never looked up.** Its only range fact is `c3`
  (`argument.rs:861`): `Sum = sr + sg + 1`. This is the same SHAPE as `d`'s
  (R3) and `Sum` has no limb decomposition of its own — but the coefficient on
  `Sum` in `c3` is **1**, so there is no halving and no alias. It is sound for
  a reason that must not be disturbed: if a future calibration ever writes
  `c * Sum` with `c != 1` in the row-sum relation, `Sum` acquires R09's
  structure and needs its own limbs.
* **W5 — the alias exclusions 2 and 3 of §3.3**, which expire at int24/4096
  and int24/8192 respectively.
* **W6 — the isqrt no-wrap boundary at four byte limbs, zero margin** (§3.4).
* **W7 — `p_soft`'s window is `2^10` while `fP = 9` bounds it by `2^9`.** One
  bit of slack, harmless: `c2` pins `p_soft` exactly given `Sum > 0`.

**A positive finding to record beside them:** every requantisation remainder in
this module has an EXACT window (`byte(r)` plus `scaled(r, 2^(8-s))`, or two
limbs with a scaled top), never a limb multiple — `rg < 2^7`, `rd < 2^6`,
`rh < 2^14`, `rql/rkl/rvl/rqrl/rkrl < 2^7`, `rsl < 2^6`, `ro < 2^9`,
`rho/sigma < 2^29`, `sr/sg < 2^14`, `p_soft < 2^10`. **There is no R10-style
"advertised width is a label, not a proven range" slack anywhere in this
module.** That is the other structural improvement over `attention.rs`.

---

## 6. THE OBLIGATION: what must be proved before the geometry is widened

Proposed as a binding precondition on any change that widens the private
block's `d_model`, its residual class, or `T`. It is written so that the
security owner can hand it over unchanged.

### 6.1 The range facts

For each norm site `s` in `{norm_a, norm_m}`, with
`Dmax(s) = isqrt(Ceps + d_model * xmax^2)` computed from the NEW geometry's
residual class:

* **O1 (the one that must never be dropped).** `d_s` is committed as
  `nd` byte limbs, every limb looked up in U8, with the reconstruction pinned
  by its own zero-check term, and `nd = ceil(log2(Dmax(s) + 1) / 8)`.
  *This is (R2). It is the only exclusion of the half-p alias that survives
  widening.*
* **O2.** `a1_s`, `a2_s` likewise with `na = ceil(log2(2 Dmax(s) + 1) / 8)`
  limbs. *Note explicitly in the commit that at `na >= 4` this stops excluding
  the alias on its own, so O1 carries the whole exclusion.*
* **O3 (no-wrap).** `nd <= 4` AND `na <= 4`. At `n = 4` the bound
  `d^2 + a1 <= p - 1` is tight to the last unit; five limbs wrap (R4) and the
  isqrt argument collapses. A geometry with `SSe > 2^64` cannot use this
  construction at all and needs a different one.
* **O4 (the remainder window).** `rho_s`, `sigma_s` in an EXACT window
  `[0, 2^wrho)` with `wrho = ceil(log2(2^(tn+1) Dmax(s)))`, realised as
  `n_rho` byte limbs plus one `scaled` lookup on the top limb, and the
  coefficient written as `1 << (8 * n_rho - wrho)` — **not** the present
  `1 << (32 - NORM_WRHO)`, which underflows above `wrho = 32` (W2).
* **O5 (the invariant).** Re-run the audit table of §5: every committed value
  appearing under a non-unit coefficient in any relation of the new layout is
  independently range-proved. In particular, if the softmax row-sum relation
  ever acquires a coefficient on `Sum`, `Sum` needs its own limbs (W4).
* **O6 (the premise comment).** Re-derive the no-wraparound bounds of
  `layout.rs:281-309` for the new classes and update the comment in the same
  commit. At int24 the norm numerator `2 Cn g x` reaches `~2^41` and
  `y * den` `~2^48`; the product `a16 u16` reaches `~2^46`. All below `p`, but
  the comment's stated figures (`< 2^34`, `< 2^44`, `<= 2^30`) are the int16
  ones and would be false.

### 6.2 The cost, at the fixed geometry, of going 3 -> 4 limbs

Measured against the present layout (`layout.rs:512`, `:516-526`):

| item | now | with 4 limbs on `d`, `a1`, `a2` at both sites | delta |
| --- | --- | --- | --- |
| used `Dom::L` sub-planes per site | 9 of 16 | 12 of 16 | **+3, no new plane, no new row in `A`'s data block** |
| `A_SITES[SC_TZC]` | 22 | 28 | +6 claim sites |
| `A` site pairs / `A` rows | 120 / 455 | 126 / 467 | **+12 `A` rows** (mask rows only) |
| claimed evaluations on `A` | 120 | 126 | +6 terminals = **+96 proof bytes** plus their claim bookkeeping |
| U8 lookups | 61,440 | 61,440 | **0** — `Dom::L`'s two lookups already sweep all 512 entries whatever is in them |
| tables, sumchecks, slots, `M` rows, slot degrees | 3 / 23 / 23 / 50 / max 4 | unchanged | **0** |
| `A_GROUPS`, `A_DATA_ROWS`, `A_ROWS` | 35 / 213 / 455 | re-derived and re-asserted by `Layout::new` (`layout.rs:588-591`) | must be recomputed, not guessed |

So the range fact is **cheap**: no new table, no new lookup, no new sumcheck,
no degree change; twelve mask rows and about a hundred bytes. It IS a new
statement version — the schedule digest (`layout.rs:678-686`) covers the
declared counts, so the transcript and every proof byte change, and the frozen
fixtures must be re-frozen.

### 6.3 The tamper tests that must accompany the widening

The four cases of `norm_alias.rs` re-run at the new profile, each with its
catch PREDICTED in its own comment before measurement, plus:

* a case showing that the `a1`/`a2` window no longer excludes the alias at
  `na = 4`, so that the record does not carry a defence that has lapsed;
* the arithmetic tests re-parametrised on the new `Dmax`, `tn`, `wrho`, with
  the §3.3 margin table recomputed;
* a completeness case on a SATURATED row (the `Dmax` row), because W1 and W3
  show both remainder windows are exactly saturated at the present geometry
  and an off-by-one in `wrho` would refuse honest rows rather than admit false
  ones.

---

## 7. What this lane could not determine

* **The wider profile was not proved, only computed.** Nothing here exercises
  the verifier at four limbs, at `T = 4096` or at an int24 class, because
  reaching any of them requires production changes and this lane changes no
  prover behaviour. §3.3's margins and §6.2's cost are arithmetic and layout
  bookkeeping, not measurements.
* **The exact `A_GROUPS` after the widening.** The PCS column-weight grouping
  depends on `offset % 256` of each new sub-plane slice; `Layout::new`'s own
  asserts will settle it, and §6.2 deliberately does not guess a number.
* **Whether the intended widened calibration is `(tn, Cn) = (11, 1024)`.**
  The `wrho` figures of §3.3 and §5 assume `tn = 11` carried over. A different
  `tn` moves exclusion 3's margin by one bit per unit of `tn` and must be
  recomputed with `alias_arithmetic.py`.
* **Composition.** This memo is about one block's two norms. Nothing here
  addresses the seam between blocks or the composed statement.
* **Nothing about privacy.** The alias is a soundness question; the joint-view
  gate of the construction §7 is untouched by this lane.

---

## 8. Ledger

Worktree `/home/victor/wt-zk60-normrange`, branch `zk60-private-norm-range`,
off `d399b32`.

| what | command | result |
| --- | --- | --- |
| the alias arithmetic | `python3 results/zk60_private_norm_range/alias_arithmetic.py` | exit 0; 194 lines -> `alias_arithmetic.txt` |
| the new cases and the whole module | `flock -w 1800 /tmp/zk-build.lock env CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 cargo test --release --offline -j 2 --manifest-path hashline/Cargo.toml --lib private_block -- --test-threads=1` | **41 passed, 0 failed, 1 ignored**, 19.89 s -> `results/zk60_private_norm_range/test_private_block.log` |
| the five new cases alone | the same with `--lib private_block::norm_alias` | 5 passed, 0 failed, 2.07 s |
| production build unaffected | `cargo build --release --offline --lib` | exit 0 (the only change to a non-test file is one `#[cfg(test)] mod` line) |
| the python gates that read this module | `python3 -m unittest tests.test_zk60_private_block_inventory tests.test_zk60_attention_native_inventory tests.test_aggregation_freeze tests.test_zk60_mvp_security_probe` | **85 tests, OK, 1 skipped**, 64 s |

Commit: `7ab3daa` on `zk60-private-norm-range` (this document, `norm_alias.rs`,
the one registration line, and the two `results/` artefacts).

**Observed, PRE-EXISTING, not this lane's:** the block inventory tool prints
`failures: ['count/A rows', 'gate/host sum L / rank match the design']` inside
its diagnostic report while the unittest suite is green. It reads only
`layout.rs`, `argument.rs`, `protocol.rs` and `zkp-core/src/pcs.rs`
(`scripts/zk60_private_block_inventory.py:682-697`) — none of which this lane
touches — so the two are a mismatch between the layout's declared counts and
the design memo the tool compares against, present at `d399b32`. Recorded here
only so that whoever re-runs the ledger does not attribute them to this lane.

Files this lane owns and wrote:

* `docs/zkmatrix-poc/ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` (this file)
* `hashline/src/private_block/norm_alias.rs` (new, `#[cfg(test)]` only)
* `hashline/src/private_block.rs` — ONE line, `#[cfg(test)] mod norm_alias;`
* `results/zk60_private_norm_range/alias_arithmetic.py` and `.txt`,
  `test_private_block.log`, `build1.log`

No prover or verifier behaviour changed; no existing test weakened, deleted or
loosened.
