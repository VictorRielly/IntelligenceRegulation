# Sealed-handle independent check — code findings (read-only)

Repo: /home/victor/IntelligenceRegulation, branch `perf/zk-batch-optimizations`,
working tree as of 2026-09-19. No build, no test, no binary was run: every
statement below is from reading source.

Two near-identical copies of the private argument exist:
`hashline/src/private_block/` (the composed block, 23 slots) and
`hashline/src/private_attention/` (the earlier attention-only component).
Citations are to `private_block` unless stated; the attention copy is noted
where it differs.

---

## Q1. The `Coord` type

### Definition — CONFIRMED

`hashline/src/private_block/argument.rs:46-53`:

```rust
/// one coordinate of a plane's claim point, as a function of the slot's challenges
#[derive(Clone, Debug)]
pub(crate) enum Coord {
    Rho(usize),
    /// `1 - rho_k` (the RoPE partner half)
    Flip(usize),
    Fixed(Fp2),
}
```

A byte-identical second definition is at
`hashline/src/private_attention/argument.rs:42-49`.

**Verdict on "Coord is Rho/Flip/Fixed only": CONFIRMED.** Three variants, no
others, in both copies. `grep -rn "Coord::"` over the whole repo returns 25
hits and no fourth variant name.

### Meaning of each variant

`claim_point` (`argument.rs:151-160`) turns a plane's coord list into the point
at which the plane's MLE is claimed:

```rust
fn claim_point(p: &Priv, rho: &[Fp2]) -> Vec<Fp2> {
    p.coords.iter().map(|c| match c {
        Coord::Rho(k) => rho[*k],
        Coord::Flip(k) => Fp2::ONE.sub(rho[*k]),
        Coord::Fixed(f) => *f,
    }).collect()
}
```

`priv_table` (`argument.rs:162-196`) is the same map on the boolean cube — this
is the one that shows the index transformation explicitly:

```rust
for (j, c) in p.coords.iter().enumerate() {
    let b = (idx >> (p.log - 1 - j)) & 1;
    match c {
        Coord::Rho(k)  => x |= b       << (n_vars - 1 - *k),
        Coord::Flip(k) => x |= (1 - b) << (n_vars - 1 - *k),
        Coord::Fixed(_) => z = (z << 1) | b,
    }
}
```
(`argument.rs:176-182`)

- **`Rho(k)`** — plane index bit `j` is slot challenge variable `k`, unchanged.
  Because `k` is free, this also expresses an arbitrary **permutation** of the
  index bits (e.g. `SC_QMM` at `argument.rs:628-630` builds
  `fixed(&pts.r_q) ++ rho(0..4)`, mapping the plane's low 4 bits onto the slot's
  first 4 variables).
- **`Flip(k)`** — plane index bit `j` is the **complement** of slot variable `k`
  (`1 - rho_k`). Exactly one use site in each copy:
  `argument.rs:804-806` (`private_attention/argument.rs:668-670`):
  ```rust
  let mut cf = rho(0..log);
  cf[log - 3] = Coord::Flip(log - 3);
  let iflip = b.a_at(src, cf, 0)?;
  ```
  This is RoPE rotate-half: the partner of head-dim index `i` is `i ^ (HD/2)`,
  i.e. the top bit of the head-dim index complemented. Confirmed against the
  integer oracle `rotate` at `hashline/src/causal_oracle.rs:657-670`, which pairs
  `base + i` with `base + HD/2 + i`.
- **`Fixed(f)`** — that index bit is not a live sumcheck variable; the plane is
  **partially evaluated** (eq-folded) at the fixed field coordinate `f`.
  `priv_table:165-166` collects the fixed coords into `eq_table_msb(&fixed)` and
  folds them out. In practice `f` is a previously drawn challenge point
  (`fixed(&pts.r_q)` at `argument.rs:628`, `fixed(&r_row)` at `:686`), not a
  boolean constant — so it is "evaluate this axis at an already-committed
  point", not "index 7".

Constructors: `rho(range)` at `argument.rs:396-398`, `fixed(&[Fp2])` at
`:399-401`; `Coord::Flip` is only ever written by the one line above.

### Precisely what index of P a `Coord` can address

A `Priv` table must supply exactly one `Coord` per plane index bit — enforced at
`argument.rs:265`:

```rust
if def.tabs.iter().any(|t| matches!(t, Tab::Priv(p) if p.ext_round >= ext || p.coords.len() != p.log)) {
    return Err(format!("private block: slot {s} table shape"));
}
```

So the addressable index maps are exactly:

1. choose, per plane bit, one slot variable (a **bit permutation**, and the
   plane may use fewer variables than the slot has — `priv_table:190-195`
   **broadcasts** over unused slot variables);
2. optionally **complement** that bit (`Flip`);
3. optionally replace the bit by a **fixed evaluation coordinate** (`Fixed`),
   which removes it from the live variables.

That is the group of *signed bit permutations* (bit permutation composed with a
constant XOR mask), plus partial evaluation and broadcast.

**It is NOT an arbitrary affine map on the index bits.** There is no way to make
a plane bit depend on two slot bits (no XOR of two variables), and no carry
structure. `priv_table`'s own doc comment names the reason the restriction must
hold (`argument.rs:162-163`):

> `T(x) = plane~(point(x))` over the slot's boolean domain: multilinear in x
> because every challenge index occurs at most once among the coordinates.

Note (**observation, not a claimed defect**): the "each challenge index occurs
at most once" premise is *not checked by code* — `run_slot:265` only checks
`coords.len() == p.log`. Two coords naming the same `k` would silently OR into
the same bit of `x` in `priv_table:179-180` and produce a wrong (non-multilinear)
table. It is a construction premise held by review only.

**Additional addressing channel not in `Coord`.** A `Priv` also carries
`slices: Vec<(usize, Fp2)>` — element offsets into the committed buffer
(`argument.rs:56-58`), read as `data[*off + idx]` (`argument.rs:187`). The
offset selects which plane (and, for sub-row planes, which column window). See
Q2 for why this is the nearest thing to a shift the machinery already has.

---

## Q2. Is a shift `i -> i+1` expressible?

### Search results

`grep -rnEi "\b(shift|rotate|rotl|rotr|next_index|prev|succ|carry|prefix|running|cumsum|accum)\b"` over
`hashline/src` and `zkp-core/src` returns no index-shift relation. Every hit is
one of:

- **`shift`** = a numeric bit-shift in requantisation (`v = 2^s y + r`), e.g.
  `hashline/src/chain.rs:77-79`, `hashline/src/export_v3.rs:293`,
  `zkp-core/src/ffn_v3/statement.rs:36-96`. Not an index operation.
- **`rotate`** = RoPE rotate-half (`hashline/src/causal_oracle.rs:657`), which is
  the `i ^ (HD/2)` bit complement of Q1, handled by `Coord::Flip`.
- **`prefix`** = an O(T) *evaluation trick* for a public MLE, not a constraint.
  `hashline/src/attention.rs:1884-1895`:
  ```rust
  /// The MLE of the causal mask [j <= t] at (rt, rj) (O(T) by prefix sums).
  pub fn mask_mle(rt: &[Fp2], rj: &[Fp2]) -> Fp2 { ... pre = pre.add(ej[t]); acc = acc.add(et[t].mul(pre)); ... }
  ```
  The prover computes a public constant this way; nothing in the proof relates
  a committed plane at `t` to the same plane at `t+1`.
- **`prev`** = the previous sumcheck challenges vector (`argument.rs:294-308`) or
  the previous layer in a seam (`attention.rs:2935`). Not an index.
- **`carry`/`accum`** = field-arithmetic carry in `zkp-core/src/field.rs:108` and
  prose. Not an index.

### The four candidates named in the brief

| candidate | what it actually is |
|---|---|
| **causal mask** | a **public** table over two *independent* free variables `(t, j)`, not a shift of one plane. `argument.rs:503-506`: `causal_mask()` = `1` iff `x % T <= (x / T) % T`, pushed as `Tab::Pub` at `argument.rs:611`. |
| **norm running sums** | none. The norm proves `D = isqrt(ss)` pointwise from committed planes `A_D`, `A_A1`, `A_A2` at the *same* index (`argument.rs:584-593`); `ss` is a row sum produced by a separate slot (`SC_SS`), i.e. an all-ones sum over a whole axis, not a prefix chain. |
| **softmax sum** | `SC_RS` (`argument.rs:606-615`) sums `E * causal_mask` over the whole `j` axis under `eq(p_ht)`. An axis sum, not a running sum. |
| **byte-limb recomposition** | **across separate PLANES at the same hypercube index**, never across neighbouring indices. `argument.rs:719-721`: `let at = |p: usize| v[idx[p]]; let l4 = |o| at(o) + at(o+1)*p1 + at(o+2)*p2 + at(o+3)*p3; let l2 = |o| at(o) + at(o+1)*p1;` — `o`, `o+1` are *plane* ids (`A_XL0`, `A_XL1`, …), each its own committed plane and its own claim site. `p1,p2,p3 = pow256(1..3)` at `argument.rs:542`. |

### Can the zero-check relate a plane at `x` to the same plane at `x+1`?

**No, not with today's `Coord` machinery.** The same plane *can* be read at two
related indices in one slot — the RoPE case does exactly that
(`argument.rs:804-806`) — but only for index maps in the signed-bit-permutation
group, and it costs a **second claim site with its own reserved mask pair**
(`B::a_slice` at `argument.rs:420-424` takes a fresh `lay.a_site(slot, ak)`).
`i -> i+1` is not in that group: its multilinear extension is not a product of
per-bit functions, so no coord list produces it.

The mechanism used instead, everywhere: **a second committed plane at the same
index**. Every derived quantity (limbs, remainders, requantised outputs,
residuals, the norm's `D`) is its own row of the `A` commitment, and the
relation is a pointwise identity among planes under one `eq` factor.

### Absent by design, or merely not implemented?

**Merely not implemented — but it needs a new addressing mode and a new PCS
claim form, not a restructuring of the sumcheck.** The evidence:

1. **The sumcheck prover is fully generic over tables.**
   `zkp-core/src/sumcheck.rs:47-131` takes `tables: &mut Vec<Vec<Fp2>>` — arbitrary
   length-`2^n` evaluation tables — and an arbitrary `poly: Fn(&[Fp2]) -> Fp2`.
   The round loop (`:62-106`) never looks at where a table came from. A shifted
   table is just another `Vec<Fp2>` the prover can materialise in `O(2^n)`;
   `table_of` (`argument.rs:200-208`) would need one more arm. **Nothing in the
   evaluation loop would have to change.**

2. **The PCS's linear test already accepts arbitrary column weights.** The
   verifier's check is a plain inner product of the group's clear folded message
   vector with a weight vector — `zkp-core/src/pcs.rs:976`:
   ```rust
   let got = v[..n].iter().zip(cw.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)));
   ```
   The restriction to eq-tables is *only* in the weight constructor
   `zkey_weights` (`pcs.rs:794-805`), which builds `col_w` from `eq_table_msb(tail)`
   or all-ones, and in the `ZPart` struct, which can only carry a `point`
   (`pcs.rs:719-725`). Row weights are already an arbitrary `Vec<Fp2>`
   (`zpart_weights`, `pcs.rs:752-792`).

3. **The project's own mask commitment already does the arbitrary-functional
   thing.** `MaskFunctional` (`hashline/src/zk.rs:394-398`) carries
   `terms: Vec<(usize, Vec<Fp2>)>` — arbitrary weight vectors over a committed
   row — and `mask_verify` closes them. So the pattern exists in-tree.

4. **The nearest existing shift: slice offsets.** `Priv.slices` element offsets
   are arbitrary `usize` (`argument.rs:56-58`) and `priv_table` reads
   `data[off + idx]` (`:187`), and `ZPart`'s own doc says a sub-row slice
   "occupies columns `[offset % n, offset % n + 2^log_size)` of one row"
   (`pcs.rs:715-718`). For a plane **smaller than one PCS row**, `off + k` is
   already a legal claim: only `c0 + 2^ls <= n` is asserted
   (`pcs.rs:768`, `:786`). For a plane of **one row or larger** it is refused:
   `assert!(p.slice.offset % n == 0)` (`pcs.rs:759`, `:775`). At the tiny profile
   `LOG_N = 8` and the working domains are 8-11 vars (`layout.rs:97-105`), so in
   practice the planes that matter are row-aligned and offset shifts are blocked.
   No code uses an unaligned offset today, and there is no wrap/boundary handling
   (a shift by one would read one element of the neighbouring plane).

**Cost of adding a shift, as the code stands:** a new `Coord`-level or `Tab`-level
shifted-access mode in `priv_table`/`table_of`; a `ZPart` variant carrying an
explicit weight vector plus the matching `zkey_weights` arm (arbitrary weights
break the *grouping* optimisation at `pcs.rs:808-830`, so each shifted access
becomes its own opening group with its own mask row); and a matching arbitrary-
weight form in `mask_eval` (`argument.rs:210-219`), which today also assumes an
eq-table of a point tail. That is real work in three files, but no change to the
sumcheck, the transcript order or the commitment scheme.

---

## Q3. Degree

### (a) Per-round message length — CONFIRMED

The prover sends the round polynomial as its **values at `X = 0..=degree`**, i.e.
`degree + 1` `Fp2` elements (16 bytes each) per round.

`zkp-core/src/sumcheck.rs:44-46` (the contract):
```rust
/// `degree` is the degree of `poly` in each single table variable's
/// linear interpolation (i.e. the round-polynomial degree). Tables are
/// consumed (folded in place).
```
`zkp-core/src/sumcheck.rs:73` (the accumulator that fixes the length):
```rust
let mut acc = vec![Fp2::ZERO; degree + 1];
```
with the evaluation loop at `:79-87` walking `cur = v0 + d*dif` for `d in 1..=degree`.

Verifier side, `zkp-core/src/sumcheck.rs:147-150`:
```rust
if s.len() != degree + 1 {
    return Err(format!("sumcheck round {j}: expected degree {degree}, got {} values", s.len()));
}
```
Byte accounting agrees: `zkp-core/src/ffn_v3/proof.rs:298`
`let sc = |rounds, degree| rounds.checked_mul(degree + 1)?.checked_mul(16);`

The brief's "around lines 47 and 197": **:47** is `pub fn prove(...)` — correct;
**:197** is `CfsMask::len`, which is Q3(d), not the round length. Both located.

### (b) Hard-coded degree caps

**CPU / `zkp-core`: NONE.** `degree` is a plain runtime `usize` everywhere
(`sumcheck.rs:47`, `:137`, `:297`; `CfsMask` stores it at `:191`). No `MAX_DEG`,
no match over degrees. `grep -rnE "\bdegree\b|MAX_DEG|max_degree"` over
`zkp-core/src` returns only these parameter threadings.

**GPU / CUDA: YES, hard-coded.** `hashline/src/gpu/kernels.cu:601`:
```c
#define SC_MAX_K 16
#define SC_DEG 4
#define SC_THREADS 256
```
`SC_DEG` is compiled into register arrays and shared-memory sizes throughout:
`f2 acc[SC_DEG + 1]` (`:654`, `:763`, `:820`), `__shared__ u64 red[SC_THREADS * (SC_DEG + 1) * 2]`
(`:651`, `:757`, `:815`), the unrolled evaluation loop `for (int d = 1; d <= SC_DEG; d++)`
(`:668`, `:784`, `:839`), and the template instantiation `scg_emit<SC_DEG + 1>`
(`:809`, `:860`). The table zero-check kernel is separately pinned to degree 3:
`hashline/src/gpu/cuda.rs:3152-3160`:
```rust
/// table zero-check on the device: the same DEGREE-3 sumcheck over
    const NV: usize = 4; // degree 3
```
The polynomial itself is also hard-coded per kernel (`zc20_poly` at
`kernels.cu:614`, `zc17_poly` at `:629`, dispatched by
`sc_round_impl<K, KIND>` at `:648`, instantiated `<13,0>` and `<15,1>` at
`:694-699`).

**Scope note:** these GPU kernels serve the *public-weight FFN* path in
`hashline/src/zk.rs`. `grep -rn "gpu\|cuda"` over `hashline/src/private_block/`
returns **nothing** — the private block is CPU-only today. So a degree bump does
not break anything that runs, but any future GPU port of a degree-`d>4` private
relation would need new kernels (the arrays are register-resident by design —
see the comment at `kernels.cu:743-748` on why `K` must be a compile-time
constant).

### (c) The SLOTS table — CONFIRMED at the cited lines

`hashline/src/private_block/layout.rs:437-462`, `(main rounds, extension rounds, degree)`:

| slot | name (`SLOT_NAMES`, layout.rs:411-434) | n | e | **d** |
|---|---|---|---|---|
| 0 `SC_SS` | 01 SS row sums norm_a | 9 | 1 | 3 |
| 1 `SC_SSM` | 01m SS row sums norm_m | 9 | 1 | 3 |
| 2 `SC_TZC` | 02 norm squares zero-check (host) | 5 | 1 | 3 |
| 3 `SC_LZC` | 08 limb zero-check | 9 | 1 | **4** |
| 4 `SC_RS` | 07 masked row sums + selector | 11 | 1 | 3 |
| 5 `SC_QMM` | 09Q matmul | 4 | 1 | 2 |
| 6 `SC_KMM` | 09K matmul | 4 | 1 | 2 |
| 7 `SC_VMM` | 09V matmul | 4 | 1 | 2 |
| 8 `SC_SCORE` | 10 score matmul (bilinear) | 3 | 2 | 2 |
| 9 `SC_PV` | 11 PV matmul (bilinear) | 5 | 2 | 2 |
| 10 `SC_WO` | 12 Wo matmul | 4 | 1 | 2 |
| 11 `SC_GMM` | 13G gate matmul | 4 | 1 | 2 |
| 12 `SC_UMM` | 13U up matmul | 4 | 1 | 2 |
| 13 `SC_DMM` | 13D down matmul | 4 | 1 | 2 |
| 14 `SC_DZC` | 03 D zero-check (host) | 9 | 1 | **4** |
| 15 `SC_QZC` | 04 Q zero-check (host) | 9 | 1 | **4** |
| 16 `SC_KVZC` | 05 KV zero-check (host) | 8 | 1 | **4** |
| 17 `SC_SZC` | 06 softmax zero-check (host) | 11 | 1 | **4** |
| 18 `SC_FZC` | 14 F zero-check (host) | 9 | 1 | **4** |
| 19 `SC_TAB` | TAB table helper zero-check | 8 | 1 | 3 |
| 20 `SC_ZS` | ZS zero-sum row | 8 | 1 | 2 |
| 21 `SC_IO_IN` | IO-in endpoint equality | 9 | 1 | 2 |
| 22 `SC_IO_OUT` | IO-out endpoint equality | 9 | 1 | 2 |

**Maximum degree in use today = 4** (six slots: 3, 14, 15, 16, 17, 18).
Minimum 2, and 3 for the four sum/table slots.
Cross-checked by `layout.rs:737-738`: `sum(n) = 159`, `sum(e) = 25`.

### (d) The masked-sumcheck slot constraint — CONFIRMED, with a correction

`masked_prove` is at `hashline/src/zk.rs:972-983`; it installs the `CfsMasker`
(`:977`) and calls the generic prover. The constraint itself is **not** in
`masked_prove` — it is the assertion inside `mask_commit`,
`hashline/src/zk.rs:442`:

```rust
assert!(part.len() + MASK_Q <= m, "mask row: {} coefficients + {MASK_Q} pads > {m}", part.len());
```

with, at `hashline/src/zk.rs:373-375`:
```rust
pub const MASK_LOG_MSG: u32 = 9;  // 512 message positions per a-row
pub const MASK_LOG_DOM: u32 = 12; // 4096 evaluation positions
pub const MASK_Q: usize = 256;    // opened columns (== pads per a-row)
```

and the layout mirrors it exactly, `hashline/src/private_block/layout.rs:728-734`:
```rust
// every mask row fits the M message: L + 256 pads <= 512; the largest is SC_SZC at 50
let l = |s: usize| { let (n, e, d) = SLOTS[s]; (n + e) * d + 2 };
assert_eq!((0..N_SLOTS).map(l).max(), Some(50));
for (n, d) in mask_specs() { assert!(n * d + 2 + 256 <= 512); }
```

So, term by term:

- **L** = the number of `Fp2` coefficients of the slot's CFS masking polynomial,
  `L = CfsMask::len(n_vars, degree)`.
- **the 256** = `MASK_Q`, the random pad symbols appended to every mask row —
  equal to the number of columns opened on the mask commitment
  (`zk.rs:543`, `:566`: `tr.challenge_indices(MASK_Q, dom)`). They are what makes
  the opened columns uniform.
- **the 512** = `m = 1 << MASK_LOG_MSG`, the message length of one mask row
  before Reed-Solomon encoding onto the 4096-point coset (`zk.rs:430-431`).

**The `n_vars*d + 2` formula — CONFIRMED verbatim**,
`zkp-core/src/sumcheck.rs:197-199`:
```rust
pub fn len(n_vars: usize, degree: usize) -> usize {
    n_vars * degree + 2
}
```
Rationale in the module comment, `zkp-core/src/sumcheck.rs:166-170`:
`g(x) = a_0 + a' * prod_j x_j + sum_j sum_{e=1..d} a_{j,e} x_j^e` — `1` for `a_0`,
`1` for `a'`, `d` per variable.

**How `n_vars` depends on the slot:** it is main rounds **plus** extension rounds.
`layout.rs:533-535`:
```rust
pub(crate) fn mask_specs() -> Vec<(usize, usize)> {
    SLOTS.iter().map(|&(n, e, d)| (n + e, d)).collect()
}
```
matched by `argument.rs:251-254` (`CfsMask::sum_weights(n + e, d)`).

**CORRECTION to the brief's framing:** the 512 is **not** `2^log_cols` of the
block PCS. The mask commitment `M` is a *separate* Ligero-form matrix with its
own fixed geometry (512 message positions, 4096 coset points, 256 opened
columns), built by `zk::mask_commit` (`private_block/protocol.rs:324`) and
opened by `zk::mask_open` (`:392`) / `zk::mask_verify` (`:453`). The block's
`log_cols = 8` governs the `A`/`H`/endpoint commitments only
(`protocol.rs:21-23`, see Q3(e)). Raising `log_cols` does **not** widen a mask row.

### (e) `M_ROWS = 2*N_SLOTS + 4` and the row width — CONFIRMED

`layout.rs:519`:
```rust
pub(crate) const M_ROWS: usize = 2 * N_SLOTS + 4;
```
with `N_SLOTS = 23` (`layout.rs:386`), so **`M_ROWS = 50`**, asserted at
`layout.rs:708` (`assert_eq!(M_ROWS, 50);`) with the comment
`// 23 slots -> 46 coefficient rows + b_re, b_im, u_re, u_im`.
This matches `mask_commit` exactly: `let n_base = 2 * masks.len() + 4;`
(`hashline/src/zk.rs:435`) — two rows per slot (the `Fp2` coefficients split into
`re`, `im`) plus the blinding pair `b_re, b_im` and the proximity pair `u_re, u_im`.

`log_cols = 8` for the tiny private profile — **CONFIRMED**,
`hashline/src/private_block/protocol.rs:21-23`:
```rust
pub(crate) fn pcs_params() -> PcsParams {
    PcsParams { log_cols: LOG_N as u32, inv_rate: 8, num_col_checks: 256 }
}
```
with `LOG_N = 8`, `N = 1 << LOG_N` at `layout.rs:48-49`. Re-absorbed into the
transcript as `log_cols8` at `protocol.rs:33`.

**Mask row width: 512, fixed, independent of `log_cols`** (`zk.rs:373`, `:430`).

### Degree-7 budget arithmetic

Usable coefficient slots per mask row: `512 - 256 = 256`, so the constraint is
`n_vars * d + 2 <= 256`, i.e. `n_vars * d <= 254`.

At **d = 7**:

| n_vars | L = n_vars*7 + 2 | L + 256 | <= 512? | headroom (coeff slots) |
|---|---|---|---|---|
| 19 | 133 + 2 = **135** | 391 | **YES** | 121 |
| 20 | 140 + 2 = **142** | 398 | **YES** | 114 |
| 21 | 147 + 2 = **149** | 405 | **YES** | 107 |

**At `log_cols = 8` (256-wide A/H rows): all three fit.**
**At `log_cols = 14` (16384-wide A/H rows): all three fit, with the identical
numbers** — because the mask row is 512 wide either way (Q3(d) correction). The
block's `log_cols` changes the A/H commitment shape and hence how many *variables*
a slot has, not the mask budget per variable.

Slack in every direction: at `d = 7` the mask row admits `n_vars <= floor(254/7) = 36`;
at `n_vars = 21` it admits `d <= floor(254/21) = 12`. Today's worst case is
`SC_SZC` at `L = 12*4 + 2 = 50` (`layout.rs:733`), so the row is ~20% used.

The real costs of degree 7 are elsewhere and are **not** mask-row costs:
`degree + 1 = 8` `Fp2` values per round instead of 5 (proof bytes, Q3(a)), 8
polynomial evaluations per cube point per round in the prover loop
(`sumcheck.rs:79-87`), and no GPU kernel (`SC_DEG 4`, Q3(b)).

---

## Q4. Packing / byte decomposition

### The four citations — ALL EXIST, and say what was claimed

**`hashline/src/private_block/layout.rs:318`** — the **input** endpoint's limbs
enter the `Dom::D` U8 lookup list:
```rust
Dom::D => {
    v.extend([byte(A_XL0), byte(A_XL1)]);
```

**`hashline/src/private_block/layout.rs:332`** — the **output** endpoint's limbs
(residual 2) in the same list:
```rust
    v.extend([byte(A_X2L0), byte(A_X2L1)]);
```

**`hashline/src/private_block/argument.rs:728`** — the input endpoint's
recomposition constraint inside `SC_DZC`:
```rust
let c2 = x.add(k(32768)).sub(l2(A_XL0));
```

**`hashline/src/private_block/argument.rs:736`** — the output endpoint's:
```rust
let c8 = x2.add(k(32768)).sub(l2(A_X2L0));
```

with `let l2 = |o: usize| at(o).add(at(o + 1).mul(p1));` (`argument.rs:721`) and
`p1 = pow256(1) = 256` (`argument.rs:542`).

**Verdict on "both endpoint planes are already byte-decomposed with U8 lookups":
CONFIRMED.** The two planes are the block's declared external endpoints —
`argument.rs:905-907`:
```rust
// the block's two external endpoints: x_in and xres2 (D12 item 2)
b.a(if slot == SC_IO_IN { A_X } else { A_X2 })?;
b.endpoint(if slot == SC_IO_IN { Cm::In } else { Cm::Out });
```
Plane ids: `A_X = 8`, `A_XL0 = 9`, `A_XL1 = 10` (`layout.rs:127-129`);
`A_X2 = 37`, `A_X2L0 = 38`, `A_X2L1 = 39` (`layout.rs:146-148`).

### Signed or unsigned, and how the map is fixed

**The endpoint values are SIGNED int16.** The map to bytes is **offset binary
(excess-32768), not two's complement**:

> `x + 32768 = l0 + 256 * l1`, with `l0, l1` each range-checked into `[0, 256)`
> by a U8 lookup.

The offset is a literal in the constraint, `argument.rs:728` and `:736`
(`k(32768)`), and the limb range-checks are `byte(A_XL0)`, `byte(A_XL1)` at
`layout.rs:318` / `byte(A_X2L0)`, `byte(A_X2L1)` at `:332`. Nothing else pins
the sign; this pair of facts *is* the int16 class. Stated as such in the layout's
soundness premise, `layout.rs:288-290`:

```
/// * x, ao, xres1, xres2, u16, h16, z16 in int16 (two limbs, offset 32768);
///   y, nm, q8, k8, v8, qr8, kr8, s8, o8 in [-127, 127] (`v + 127` and
///   `127 - v` both bytes); g8 in [-128, 127] from the 256-row activation
///   table itself, never from `sym`;
```

Three distinct signed-value encodings coexist, and only the first is a byte
decomposition:

1. **int16 → 2 offset bytes** (the endpoints, and `ao`, `xres1`, `u16`, `h16`,
   `z16`): `value + 32768 = l0 + 256*l1`. Used at `argument.rs:728-730`, `:736`,
   `:738`, `:774-775`.
2. **int8 in `[-127,127]` → two U8 range checks, no decomposition**:
   `sym(p)` at `layout.rs:274-276`:
   ```rust
   fn sym(p: usize) -> [Lk; 2] {
       [Lk { terms: vec![(p, 1)], cst: 127 }, Lk { terms: vec![(p, -1)], cst: 127 }]
   }
   ```
   i.e. both `v + 127` and `127 - v` must be bytes. The value itself stays signed
   in the field; it is never split into limbs.
3. **`g8` in `[-128,127]` → offset 128, and its range comes from the activation
   table, not a lookup on the plane**: `argument.rs:777`:
   ```rust
   let f_act = v[i_fact].mul(alpha.sub(g8.add(k(128)).add(beta.mul(a16)).add(g_act))).sub(Fp2::ONE);
   ```

### Bytes per element — NOT fixed at 4

**Verdict on "4 bytes per element": CONTRADICTED for the endpoints.** The
endpoint planes use **2 bytes** each (`l2`). The limb count varies per plane:

- **2 limbs** (`l2`, `argument.rs:721`) — every int16 plane, including both endpoints.
- **3 limbs** (`l3`, `argument.rs:584`) — `D`, `a1`, `a2` (`< 2^24`), per
  `layout.rs:291-294`.
- **4 limbs** (`l4`, `argument.rs:720`) — the norm's `rho`/`sigma` (`< 2^29`), with
  the top limb further constrained by `scaled(A_NR0 + 3, 1 << (32 - NORM_WRHO))`
  (`layout.rs:321`, `:323`, `:329`, `:331`) so the class is exact, not just
  "four bytes".
- **biased fractional limbs** for requant remainders: 7-bit (`scaled(p, 2)`),
  6-bit (`scaled(p, 4)`), 9-bit (`l0 + 256*l1` with `scaled(l1, 128)`), 14-bit
  (`l0 + 256*l1` with `scaled(l1, 4)`) — `layout.rs:299-302`, realised at
  `layout.rs:324`, `:334`, `:336`, `:340`.

All limbs land in the **one** 256-entry U8 table; the "byte" is the unit, the
count is per-plane.

---

## Q5. Multi-column lookup tables

### The table constructions — CONFIRMED at `argument.rs:522-535`

```rust
pub(crate) fn table_values_u8(g_u8: Fp2) -> Vec<Fp2> {
    (0..N as i64).map(|i| k(i).add(g_u8)).collect()
}
pub(crate) fn table_values_exp(public: &AttentionPublic, beta: Fp2, g_exp: Fp2) -> Vec<Fp2> {
    (0..N).map(|i| k(i as i64).add(beta.mul(k(public.exp[i]))).add(g_exp)).collect()
}
```
(`:522-527`) and, at `:533-535`:
```rust
pub(crate) fn table_values_act(ff: &FeedForwardPublic, beta: Fp2, g_act: Fp2) -> Vec<Fp2> {
    (0..N).map(|i| k(i as i64).add(beta.mul(k(i64::from(ff.act[i])))).add(g_act)).collect()
}
```

So the activation table is `i + beta*act[i] + g_act` and the exponential table is
`i + beta*exp[i] + g_exp`, `beta` being a transcript challenge that folds two
columns into one and `g_* = gamma * TAG_*` the domain-separating tag
(`argument.rs:130-133`, `protocol.rs:16`). **Claim CONFIRMED verbatim.** The
soundness reason for binding the *pair* is stated at `argument.rs:528-532`
(T2 erratum E-22: where `u16 = 0` the product relation pins nothing about `a16`).

The brief said "around :525-535"; the exp table is at `:525-527` and the act
table at `:533-535`. Both present.

### The lookup form — CONFIRMED at both cited sites

`hashline/src/private_block/layout.rs:259-272`:
```rust
// ---- lookups (all into the 256-entry U8 table; value = cst + sum coef * plane) ----
#[derive(Clone, Debug)]
pub(crate) struct Lk {
    pub terms: Vec<(usize, i64)>,
    pub cst: i64,
}
fn byte(p: usize) -> Lk { Lk { terms: vec![(p, 1)], cst: 0 } }
/// `k * plane` in U8: with `byte(plane)` this bounds the plane below `256 / k`
fn scaled(p: usize, k: i64) -> Lk { Lk { terms: vec![(p, k)], cst: 0 } }
```

`hashline/src/private_block/argument.rs:459-472` (the same thing in table-index
space) and `:474-490` (`helper_sum`), whose denominator builder is the key line,
`argument.rs:475`:
```rust
let den = |l: &LkT| alpha.sub(l.terms.iter().fold(l.cst, |a, (i, c)| a.add(v[*i].mul_base(*c))));
```

### Is a lookup argument restricted to a linear form? — YES

**CONFIRMED.** `Lk`/`LkT` can only express `cst + sum_i coef_i * plane_i` with
`coef_i` an `i64`-derived field constant (`lk_tables`, `argument.rs:466-472`:
`Fp::from_i64(*c)`) and `cst` an `i64` plus the tag. `v[*i]` is always a *table
value* (a committed plane's fold), never a product of two. **A lookup cannot take
a nonlinear function of committed values as its input through this path.**

One qualification worth stating, because it is the only multi-column lookup in
the block: the **activation pair lookup is hand-written in the slot polynomial**,
not routed through `LkT` — `argument.rs:777`:
```rust
let f_act = v[i_fact].mul(alpha.sub(g8.add(k(128)).add(beta.mul(a16)).add(g_act))).sub(Fp2::ONE);
```
It uses a *challenge* (`beta`) as a coefficient, which `LkT` cannot. It is still
**linear in the committed planes** (`g8`, `a16`). So the restriction is "linear
in committed values", and the `LkT` struct additionally restricts the
coefficients to compile-time constants. Extending a lookup argument to a
nonlinear combination would raise the slot degree by the argument's degree in
each of the two `den` factors (see Q6) and is not expressible in `Lk` today.

### Are tables limited in size?

**Yes, at 256, and the bound is structural in the private block.**

- `LOG_N = 8`, `N = 256` (`layout.rs:48-49`) is *both* the PCS column count and
  the lookup-table length: all three `table_values_*` emit exactly `N = 256`
  entries (`argument.rs:523`, `:526`, `:534`).
- The table domain is its own `Dom` variant pinned to 8 variables —
  `layout.rs:93-94` (`/// one 256-entry table row (8 vars)` / `Tab,`) and
  `layout.rs:103` (`Dom::Kv | Dom::Tab => 8`).
- The comment at `layout.rs:259` names it: "all into the **256-entry** U8 table".
- Enforced per slot at run time, `argument.rs:280-282`:
  ```rust
  if tables.iter().any(|t| t.len() != 1usize << n) {
      return Err(format!("private block: slot {s} table length"));
  }
  ```
- Multiplicity planes `A_MU8`, `A_MEXP`, `A_MACT` and helper planes `H_GU8`,
  `H_GEXP`, `H_GACT` live on `Dom::Tab` and are consumed by `SC_TAB`
  (`argument.rs:876-894`), one `(multiplicity, helper, public values)` triple each.
- Soundness side-condition on multiplicities, `layout.rs:307-308`:
  "The LogUp multiplicities (at most 61,440) cannot wrap."

For contrast, the **public-weight FFN path** (not the private block) does use a
larger table: `hashline/src/zk.rs:1943` lists `(TAG_INT16, 1usize << 16)`. So
2^16 tables exist in the codebase; the private block's 256 is a profile choice
tied to `LOG_N`, not a hard limit of the argument system.

---

## Q6. The LogUp helper relation degree — CONFIRMED

`hashline/src/private_block/argument.rs:474-490`:

```rust
fn helper_sum(v: &[Fp2], lks: &[LkT], h0: usize, alpha: Fp2, mu: &[Fp2]) -> Fp2 {
    let den = |l: &LkT| alpha.sub(l.terms.iter().fold(l.cst, |a, (i, c)| a.add(v[*i].mul_base(*c))));
    let mut acc = Fp2::ZERO;
    for k in 0..lks.len().div_ceil(2) {
        let h = v[h0 + k];
        let d1 = den(&lks[2 * k]);
        let rel = match lks.get(2 * k + 1) {
            Some(l2) => { let d2 = den(l2); h.mul(d1).mul(d2).sub(d1.add(d2)) }
            None => h.mul(d1).sub(Fp2::ONE),
        };
        acc = acc.add(mu[k].mul(rel));
    }
    acc
}
```

The exact expression is at **`argument.rs:483`**:
`h.mul(d1).mul(d2).sub(d1.add(d2))`, i.e. `h*d1*d2 - (d1 + d2)`.

`h` is a committed helper plane (degree 1 in the round variable) and `d1`, `d2`
are `alpha - (linear form in committed planes)` (degree 1 each, by Q5), so the
product is **degree 3**. Every slot multiplies by an `eq` factor `v[0]` before
summing (e.g. `argument.rs:407`:
`b.finish(Box::new(move |v| v[0].mul(helper_sum(v, &lks, h0, alpha, &[Fp2::ONE]))), vec![])`),
giving **degree 4**. The single-lookup branch (`:485`, `h*d1 - 1`) is degree 2,
degree 3 with `eq`.

The brief cited `argument.rs:596-597`. That is not the relation — it is the
**comment that states the consequence**, immediately above `SC_LZC`
(`argument.rs:596-597`):

```rust
// two lookups now (A_LIMB and norm_m's A_LIMBM), so the single helper
// moves into the two-lookup branch and the slot's degree is 4 (T1 C.1)
```

Confirmed against the table: `SC_LZC = 3` (`layout.rs:389`) and
`SLOTS[3] = (9, 1, 4)` (`layout.rs:442`). Every other degree-4 slot
(`SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`) is degree 4 for the same
reason — each calls `helper_sum` with at least one two-lookup helper under an
`eq` factor.

**Verdict: CONFIRMED** (relation degree 3, slot degree 4 with the eq factor);
the cited line numbers point to the justifying comment rather than to the
expression, which is at `:483`.

---

## Summary of verdicts

| # | sub-claim | verdict |
|---|---|---|
| Q1 | `Coord` is `Rho`/`Flip`/`Fixed` only | **CONFIRMED** (`private_block/argument.rs:46-53`, `private_attention/argument.rs:42-49`) |
| Q1 | a `Coord` can express arbitrary affine maps on index bits | **CONTRADICTED** — signed bit permutations + bit-fixing + broadcast only |
| Q2 | any existing `i -> i+1` (or `i+k`) relation on a committed plane | **NOT FOUND** anywhere in `hashline/src` or `zkp-core/src` |
| Q2 | causal mask / norms / softmax are shifts | **CONTRADICTED** — public two-variable table, pointwise identities, whole-axis sums |
| Q2 | byte recomposition is across neighbouring indices | **CONTRADICTED** — across separate planes at the same index (`argument.rs:719-721`) |
| Q2 | a shift is absent *by design* | **CONTRADICTED** — merely not implemented; the sumcheck is table-generic and the PCS test already takes arbitrary column weights (`zkp-core/src/pcs.rs:976`) |
| Q3a | per-round message = `degree + 1` `Fp2` values | **CONFIRMED** (`zkp-core/src/sumcheck.rs:73`, `:147-150`) |
| Q3b | hard-coded degree cap on CPU | **NOT FOUND** (degree is a runtime `usize` throughout) |
| Q3b | hard-coded degree cap in CUDA | **CONFIRMED** — `#define SC_DEG 4` (`hashline/src/gpu/kernels.cu:601`), degree-3 table kernel (`gpu/cuda.rs:3160`); private block is CPU-only |
| Q3c | SLOTS at `layout.rs:438-461`, max degree today | **CONFIRMED** — 23 slots, max degree **4** (six slots) |
| Q3d | `L + 256 <= 512` with `L = n_vars*d + 2` | **CONFIRMED** (`zk.rs:442`, `zk.rs:373-375`, `zkp-core/src/sumcheck.rs:197-199`, `layout.rs:728-734`) |
| Q3d | the 512 is `2^log_cols` | **CONTRADICTED** — the mask matrix has its own fixed geometry (512 msg / 4096 coset / 256 opened), independent of `log_cols` |
| Q3e | `M_ROWS = 2*N_SLOTS + 4 = 50`, `log_cols = 8` | **CONFIRMED** (`layout.rs:519`, `:708`; `protocol.rs:21-23`, `layout.rs:48-49`) |
| Q3 | degree 7 at n_vars 19/20/21 fits the mask row | **YES at both `log_cols` 8 and 14** — L = 135 / 142 / 149 against a 256 budget |
| Q4 | `layout.rs:318`, `:332`, `argument.rs:728`, `:736` exist and byte-decompose both endpoints | **CONFIRMED** |
| Q4 | endpoint values are signed | **CONFIRMED** — int16, mapped by **offset 32768 (excess-K), not two's complement** |
| Q4 | 4 bytes per element | **CONTRADICTED** — 2 for the endpoints; 2/3/4 + biased limbs elsewhere |
| Q5 | act/exp tables are `i + beta*T[i] + tag` | **CONFIRMED** (`argument.rs:525-527`, `:533-535`) |
| Q5 | lookup argument is linear over committed planes | **CONFIRMED** (`layout.rs:259-272`, `argument.rs:475`); nonlinear inputs not expressible |
| Q5 | tables are size-limited | **CONFIRMED** — 256 (`N`/`LOG_N` at `layout.rs:48-49`, `Dom::Tab` at `:103`, checked at `argument.rs:280-282`) |
| Q6 | `h*d1*d2 - (d1+d2)` is degree 3, degree 4 with eq | **CONFIRMED** (`argument.rs:483`; the cited `:596-597` is the justifying comment) |

### Things I could not find

- No `MAX_DEG`-style constant anywhere on the CPU path — if one is assumed to
  exist, it does not.
- No code check that a slot's `Coord` list uses each challenge index at most
  once; it is a construction premise (`argument.rs:162-163`) held by review only.
  `run_slot:265` checks only the coord count.
- No wrap-around or boundary handling for an index translation, because no
  translation exists to handle.
