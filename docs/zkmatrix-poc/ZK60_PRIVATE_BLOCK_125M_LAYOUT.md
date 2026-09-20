# The complete private block at the 125M shape: the pins, the layout, the arithmetic and what it costs

DRAFT for the security owner's review — NOT ACCEPTED. Delegated Opus draft,
2026-09-19. Paper only: every figure is counted or modelled, none measured by
this memo.

## 0. What this memo is, and how to read it

**The one-paragraph version.** The project has exactly one complete private
transformer block that works — `hashline/src/private_block/` — and it exists
only at a toy size: 32 tokens, width 16, feed-forward width 16. The security
owner's working plan is to grow that same module (form S: one prover, one
commitment set, everything on the host CPU) to the smallest real shape the
project cares about — the 125M model, 12 layers of width 768 — measure it,
and let the measurement decide whether the more complicated two-prover design
("form E") is worth building. This memo is the paper work that has to happen
before a line of that code is written: what in the module is nailed to the
toy size, what the grown layout looks like, whether the integer arithmetic
still fits in a 64-bit field at real width, what it costs in memory and time,
and whether twelve of these can be chained. **Nothing here was run.** Every
number is either counted from the module's own source (marked `[COUNTED]`,
with the arithmetic shown) or modelled from someone else's measurement
(marked `[MODEL]`, with the assumption named).

**The four findings that matter**, for a reader who stops here:

1. **The module has 60 size pins, and eleven of them are design decisions in
   disguise.** The worst is that one constant, `N`, means two different
   things in the same code — the width of a committed row *and* the size of
   the 256-entry lookup table (`layout.rs:49` against `argument.rs:523`,
   `:526`, `:534`, `:898` and `protocol.rs:288`, `:293`, `:308`). The row
   width has to change at real scale; the table size must not. §1.3.
2. **Two integer windows that are exactly full at the toy size overflow at
   width 768**, and one of them lands on the very last value the present
   construction can express. The norm's remainder window has to go from
   `2^29` to `2^32`; `2^32` is the ceiling (`layout.rs:321` underflows above
   it), and the honest requirement at width 768 with the module's declared
   int16 input class is `2^31.79` — **0.21 bits of margin**. The softmax
   window has to go from `2^14` to `2^18`, which costs two new planes on the
   largest domain in the proof. §3.3, §3.4.
3. **The attention half is about 80% of the block and the feed-forward half
   about 20%** (79.4% / 20.5% of committed rows, `[COUNTED]` §7.4). This
   reproduces, from a completely different calculation, the figure the form-E
   check reached (`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3, C-10). Form
   E's whole value is that it keeps the feed-forward on the GPU, so **the
   most it can save at this shape is about 17% of one block's time** — which
   supports the security owner's working ruling: grow form S first.
4. **One block fits this laptop; twelve blocks under one transcript do
   not, as the design stands.** One block is about 7.9 GiB of committed
   material plus a 1.9 GiB peak inside the largest sumcheck. Chaining needs
   two consecutive blocks' commitments alive at the same time (§8), which is
   about 15.7 GiB against the box's 15 GB. So the first deliverable should be
   **one** private block of the real 125M model, and the chaining question
   should be reopened with two named cheap fixes (§8, decisions 7 and 8).

**Reading order for a non-cryptographer.** §0, then §7, §8 and §10. §1–§6 are
for whoever writes the code.

**Vocabulary used throughout.** A *plane* is one rectangular array of numbers
the proof talks about (for example "the query vectors for every token"). A
*domain* is the index set a plane lives on (tokens × width, head × token ×
token, …); the proof requires every domain to be a power of two in size, so
planes get *padded* with zeros or with filler that satisfies the equations.
A *commitment* is a cryptographic summary of a big table of numbers that lets
the prover later be held to individual values without revealing the rest;
this project's commitment (`A` for the witness, `H` for the lookup helpers,
`M` for the masks) arranges the numbers in *rows* of a fixed width and
encodes each row redundantly. A *slot* is one masked sumcheck — one
interactive argument about one equation, made non-interactive. A *claim site*
is one place where the proof opens a committed plane at one point; each gets
its own two reserved random *mask pair* rows so the opened value reveals
nothing. *LogUp* is the lookup argument: to show a value is a byte, the
prover commits the reciprocal `1/(α − value)` in a *helper* column and proves
one summation identity. *int8* means the range [−127, 127] here, *int16*
means [−32768, 32767].

## 1. The pin inventory

### 1.1 The classification rule

A **pin** is a source site whose value, shape or assumption must be revisited
when the geometry moves off `T32 / d16 / H2 / KV1 / dh8 / F16`. Three classes,
following the classification the endpoints-at-scale draft used
(`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §2.1):

* **(a) mechanical** — a number that a shape-driven generator would compute.
  Changing it is bookkeeping; getting it wrong makes the module fail loudly
  (an assert, a shape check, a length mismatch).
* **(b) derived** — a count that is currently a literal but is a *consequence*
  of the geometry (row totals, group counts, site counts). Same as (a), except
  that these are also the module's own tripwires: `Layout::new` asserts four of
  them (`layout.rs:588–591`), so they must be recomputed deliberately, not
  deleted.
* **(c) a design decision in disguise** — a site whose *correctness* silently
  relies on a property of the toy shape (a power of two, a single block, a
  table covering the whole range, a sum with few terms, one KV head). Changing
  the geometry mechanically here produces something that compiles, runs, and is
  either unsound or quietly wrong.

The precedent is D17: in the hiding endpoints, eleven size pins were found and
**one of them hid an unsoundness** — the seam binds a single `d`-block, so a
mechanical widening lets a prover commit `(honest block ‖ junk ‖ junk)` and
nothing rejects it (`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_DISPOSITION.md` §1.1).
Width 768 is exactly such a width. This section looks for the same kind of
thing elsewhere in the block module.

### 1.2 The count

**60 pin sites**, across seven files. By class: **38 (a) mechanical**,
**11 (b) derived**, **11 (c) design decisions in disguise**. By file:
`private_block/layout.rs` 20, `private_block/argument.rs` 11,
`private_block/protocol.rs` 8, `private_block/witness.rs` 9,
`private_block.rs` 7, `private_block/wire.rs` 1, `private_seam.rs` 2,
`zk.rs` 2. (`private_attention/*` carries the same pins one generation
earlier — `private_attention/layout.rs:29–36` is the identical constant block
with `N_SLOTS = 18` and `H_GROUPS = 8`; it is a frozen, accepted component and
this memo does not propose touching it.)

### 1.3 The traps: the eleven class-(c) sites

These are the ones worth a security owner's attention. The other 49 are in the
table of §1.4.

**T-1. `N` means two different things.** `layout.rs:48–49` defines
`LOG_N = 8`, `N = 1 << LOG_N`. `N` is then used as **the width of a committed
row** (`layout.rs:537–539` `rows_of`, `:563` `a_off.push(row * N)`,
`protocol.rs:69` `part_key`, `:366–371` the zero-sum row) **and** as **the size
of the 256-entry lookup tables** (`argument.rs:523` `table_values_u8`, `:526`
`table_values_exp`, `:534` `table_values_act`, `:898` `SC_ZS`'s all-ones
vector, `protocol.rs:288/293/297/303/308` the three multiplicity histograms).
The row width has to move to 16,384 at real scale (§2.2); the table size must
stay 256. Three of the eight conflated sites fail loudly if `N` moves
(`ff.act[i]` at `argument.rs:534` panics past index 255; the slot table-length
check at `argument.rs:282` rejects `SC_ZS`), but **`protocol.rs:293` changes
meaning silently**: `(0..N as i64).contains(v)` is the test "is this lookup
value inside the table", and at `N = 16384` a value of 300 — which is *not* a
byte — is counted into histogram entry 300 instead of the out-of-range
bucket 0. The LogUp identity would then have to catch it downstream. This is a
one-line fix (`const U8_LEN: usize = 256;`) that must happen **before** any
row-width change, not after.

**T-2. `outer.trailing_zeros()` assumes the matmul output width is a power of
two.** `argument.rs:626`:
`let r_j = tr.challenge_fp2_vec(outer.trailing_zeros() as usize);` with
`outer ∈ {D, KV}`. At `D = 16` this is 4 and correct. At `d = 768` it is **8**,
not 10 — `768 = 2^8 · 3` — so the slot would draw an 8-variable point over a
1024-column output and bind only a 256-column slice of it. This is the same
shape of hole as D17's: it compiles, it runs, the honest prover and verifier
agree, and the statement proved is weaker than the statement claimed. The fix
is to carry the *padded* width and use `log2(d_pad)` explicitly, with a
construction-time refusal if `d_pad` is not a power of two.

**T-3. `KV` is a width, not a head count, and the module has one KV head.**
`layout.rs:45` `KV = 8` is `HKV · DH` with `HKV = 1`; `Dom::Kv` is `(t, i')`
(`layout.rs:85`) and the score loop is
`qr8[t*D + h*DH + i] * kr8[j*KV + i]` (`witness.rs:250`) — every query head
reads the *same* key row. The 125M model is grouped-query with **12 query
heads over 4 KV heads** (`ATTENTION_INTEGER_SPEC.md:102–105`), so `Dom::Kv`
becomes `(t, kv, i')` and the score slot must tie the query head's *group*
bits to the key's `kv` bits. That is expressible in the present machinery —
`Coord::Fixed` (`argument.rs:52`) lets `A_KR8`'s claim point take the `kv`
coordinates from the same challenge vector that `A_QR8`'s head coordinates
come from — but it is a new relation between two claim points, not a constant
edit, and it is the one place where the head layout has to be chosen (§2.3
adopts the project's own precedent: re-index the heads so the KV group is the
**high** bits, `results/hashline_attn_fulllayer.md:146–148`).

**T-4. Every domain is a power of two at the toy shape, so no relation is ever
evaluated off-support.** `Dom::log()` (`layout.rs:98–106`) returns a literal
log per domain and `Dom::len()` is `1 << log`; the sumcheck requires it
(`sumcheck.rs:54–57`, cited in
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.3). At the toy shape every domain is
*exactly* a power of two — `T·D = 512`, `H·T·T = 2048`, `T·F = 512` — so the
padded region is empty and the question never arises. At 125M five of the nine
domains are padded (§2.3), and **the inhomogeneous constraints are violated on
the pad**: `c1 = σ + ρ + 1 − 2^{tn+1}·D` (`argument.rs:727`) evaluates to
`1 − 2^{tn+1}·D_t ≠ 0` at a padded width index, and `c3` (`:861`) likewise on
padded heads. Nothing in the module notices, because the pad does not exist
today. §3.7 works out what the pad must contain, constraint by constraint; the
alternative (a public support indicator multiplying each constraint) costs a
`2^19`-entry public table and one degree.

**T-5. The endpoint reads exactly two rows.** `protocol.rs:194–196` requires
the endpoint claim's three parts to be rows `0..2`, `2..3`, `3..4` — two data
rows of 256 columns, i.e. exactly `T·D = 512` words — and `argument.rs:449`
hard-codes `log: 9, mask_row: 2` for the endpoint plane. This **is** the D17
hole, in this module, one generation later: at any shape where the endpoint
plane is more than one contiguous block, the single-slice form binds only the
first block. At 125M the endpoint plane is 393,216 words in three blocks
(`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.3). D17 rules that the whole plane is
bound at every width by the batched multi-block seam, unconditionally; §6 says
which of its change-list items this module needs.

**T-6. The remainder windows are encoded as lookup coefficients, and two of
them are exactly full.** `layout.rs:310–368` expresses "this remainder is
`s` bits" as a pair `byte(r_top)` plus `scaled(r_top, 1 << (8 − s_top))`.
Nine such coefficients exist (`:321`, `:323`, `:329`, `:331`, `:334`, `:340`,
`:344`, `:346`, `:348`, `:352`, `:354`, `:356`, `:360`, `:361`, `:362`,
`:363`). Two of them are **exactly saturated at the toy shape** and therefore
break at any widening — the norm's `2^29` and the softmax's `2^14`
(independently established as W1 and W3 in
`ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` §5, branch
`zk60-private-norm-range`). `layout.rs:321`'s `1 << (32 - NORM_WRHO)`
**underflows above `NORM_WRHO = 32`**, which is a hard ceiling on the
construction, and §3.3 shows that width 768 with the module's declared int16
input class needs `NORM_WRHO = 32` with 0.21 bits to spare. This is class (c)
and not (a) because the failure at the wrong value is a *completeness* failure
that looks like a data-dependent refusal, and because one of the two possible
repairs (declaring a narrower input class) is a product decision.

**T-7. `Dom::L` packs sixteen sub-planes into one cube.**
`layout.rs:644–649`: `limb_off(k) = a_off[A_LIMB] + k*T`, nine of sixteen
sub-planes used, and `Dom::L`'s log is `9 = log2(16·32)`. This is correct only
while `16·T` is a power of two **and** the nine used sub-planes are addressed
by a 4-bit index; at `T = 512` it is `16·512 = 2^13` and still works, but the
claim slices become sub-row (512 of 16,384 columns) and each of the eighteen
sub-plane claim sites burns a **whole** pair of 16,384-wide mask rows (§2.4).
Mechanical to keep, expensive to keep.

**T-8. The RoPE partner bit is addressed from the end of the index.**
`argument.rs:805`: `cf[log - 3] = Coord::Flip(log - 3)`. The `3` is
`log2(DH) = 3`; at `dh = 64` it must be `log - 6`. Loud if wrong at the toy
(the honest proof fails), silent at a new shape only if the head-dimension
constant and this literal are changed inconsistently — which is exactly what a
search-and-replace on `DH` would do.

**T-9. `sym()` proves the int8 subset with two lookups, and the gate does not
use it.** `layout.rs:274–276` proves `v ∈ [−127, 127]` as "`v + 127` and
`127 − v` are both bytes". The feed-forward gate deliberately does **not** use
it (`witness.rs:369–372`: the activation table has 256 rows, so the gate's
class is `[−128, 127]` and the table itself is the range proof). Any new
int8-class plane at the new shape has to make the same choice explicitly.
Class (c) because the wrong choice is silent: `sym` on a gate value of −128
refuses an honest witness, and the table-only form on a non-table plane proves
no range at all.

**T-10. The causal-mask and RoPE public tables are materialised in full.**
`argument.rs:505` builds `H·T·T` field elements and `:509–520` builds
`T·heads·DH`. At the toy that is 2,048 and 512 values. At 125M the causal mask
is `2^22` `Fp2` values = **67 MB, built twice** (`SC_RS` and `SC_SZC`). Not a
correctness pin; it is a memory pin that the present code makes invisible.

**T-11. The shift constants are a calibration, and the calibration is a
different kernel.** `layout.rs:56–70` pins nine requantisation shifts and
`private_block.rs:94` pins the calibration identity digest into the
transcript. Every shift is width-dependent: the same relative precision at
inner dimension 768 instead of 16 needs about `log2(768/16) = 5.6` more bits
of shift on the QKV projections. Class (c) not because the arithmetic is
subtle but because **each shift is welded to a remainder-window lookup
coefficient** (T-6): changing `SH_QKV` without changing `scaled(A_RQL, 2)`
gives a prover that refuses honest inputs, and changing the coefficient
without the shift gives a window wider than the remainder, which is a
soundness slack. The 125M shifts must come from the existing calibration study
(`results/m125_int8_calibration.json`, real checkpoint), not be invented.

### 1.4 The full table

Class: (a) mechanical, (b) derived count, (c) design decision in disguise.

| # | site | what it pins | class |
|---|---|---|---|
| 1 | `layout.rs:40–47` | `T 32, D 16, H 2, DH 8, HALF 4, KV 8, F 16` — the whole geometry (7 constants) | (a), `KV` is **(c)** → T-3 |
| 2 | `layout.rs:48–49` | `LOG_N 8`, `N 256` — committed row width, *and* table size | **(c)** → T-1 |
| 3 | `layout.rs:52–70` | 17 calibration constants (`NORM_TN/CN/CEPS/WRHO`, `SH_QKV/ROPE/S/O/AO/G/H_PROD/Z`, `F_E/F_P/F_RO`, `WRHO_S`, `MASK_SCORE`) | **(c)** → T-11, T-6 |
| 4 | `layout.rs:98–106` | `Dom::log()`: the nine domain logs as literals; every domain a power of two | **(c)** → T-4 |
| 5 | `layout.rs:114–199` | the 81 `A` plane ids and `N_A = 81` | (b) |
| 6 | `layout.rs:200` | `N_LIMBS = 9` (three limbs each for `D`, `a1`, `a2`) | (a), D16-governed |
| 7 | `layout.rs:202–214` | `a_dom`: the plane-index run per domain (contiguity is an obligation, T2 C.2) | (b) |
| 8 | `layout.rs:223–240` | the 51 `H` plane ids, `N_H = 51`, helper counts per domain baked into the ranges | (b) |
| 9 | `layout.rs:266–276` | `byte` / `scaled` / `sym` — the three range idioms | **(c)** → T-9 |
| 10 | `layout.rs:310–368` | the 85 lookups and their window coefficients | **(c)** → T-6 |
| 11 | `layout.rs:371–381` | `helpers()`: (first plane, count) per domain | (b) |
| 12 | `layout.rs:383` | `LOOKUP_DOMS`: six lookup domains | (a) |
| 13 | `layout.rs:386–435` | `N_SLOTS = 23`, slot ids, slot names | (a) |
| 14 | `layout.rs:438–462` | `SLOTS`: (main rounds, ext rounds, degree); main rounds **are** the domain logs | (b) |
| 15 | `layout.rs:474–508` | slot kinds and the six host groups | (a) |
| 16 | `layout.rs:512–513` | `A_SITES` / `H_SITES`: 46 literals summing to 120 / 51 | (b) |
| 17 | `layout.rs:516–518` | `A_GROUPS 35`, `H_GROUPS 9`, `N_FUNCTIONALS 34` | (b) |
| 18 | `layout.rs:519` | `M_ROWS = 2·N_SLOTS + 4` | (a) |
| 19 | `layout.rs:523–526`, asserted `:588–591` | `A_ROWS 455`, `H_ROWS 384`, `A_DATA_ROWS 213`, `H_DATA_ROWS 280` | (b) |
| 20 | `layout.rs:537–539` | `rows_of`: `(1 << log).div_ceil(N)` | (a) |
| 21 | `layout.rs:644–649` | `limb_off`: sixteen sub-planes of `T` inside one `Dom::L` cube | **(c)** → T-7 |
| 22 | `layout.rs:654–663` | the `describe()` literal `T32 d16 … n=256 inv_rate=8 Q=256`, hashed into `schedule_digest` (`:678–686`) and absorbed (`protocol.rs:36`) | (a), but it **moves every proof byte** |
| 23 | `layout.rs:690–692` | `pow256(k)`, `k < 4` | (a) |
| 24 | `layout.rs:703–748` | the self-consistency test's 17 hard-coded expectations, incl. the per-domain U8 totals `[1024, 19456, 4608, 6656, 3072, 26624]` and `61,440` | (b) |
| 25 | `private_block.rs:84` | `PROFILE = "hashline-zk-mr1/private-block-t32-poc/1"` | (a) |
| 26 | `private_block.rs:86` | `EXPECTED_BYTES = 8 + 32 + 4 + 4 + 64` | (a) |
| 27 | `private_block.rs:100` | `ENDPOINT_SCALES = (0, 0)`, enforced at `:294–297` | (a), calibration-tied (D12 item 5) |
| 28 | `private_block.rs:124–127` | weight/table shape checks `D·D`, `KV·D`, `D`, `T·HALF`, `exp 256` | (a) |
| 29 | `private_block.rs:202–205` | feed-forward shape checks `D·F`, `F·D`, `[i16; 256]` | (a) |
| 30 | `private_block.rs:312` | `SeamSpec::new(ctx, T, D, scale, 41, 42/43, 44)` — endpoint slots and shape | **(c)** → T-5 |
| 31 | `private_block.rs:377` | `input.len() != T·D` | (a) |
| 32 | `private_block.rs:380` | `NttTables::new(12)` in `prepare_endpoints` | (a) |
| 33 | `witness.rs:99–107` | `matmul` over `T × inner × outer` | (a) |
| 34 | `witness.rs:111–119` | `matmul_in_out`, the feed-forward orientation | (a) |
| 35 | `witness.rs:122–137` | `rotate`: half-split RoPE over `heads·DH` | (a) |
| 36 | `witness.rs:139–141` | `limbs(v, count)`, top limb unmasked | (a) |
| 37 | `witness.rs:174` | `d >= 1<<24`, `a1, a2 ∈ [0, 2^24)` — the three-limb pin (D16 item 1) | **(c)** → T-6 |
| 38 | `witness.rs:194` | `q ∈ [−127,127]`, `ρ, σ < 2^NORM_WRHO` | **(c)** → T-6 |
| 39 | `witness.rs:250` | the score inner loop: `kr8[j*KV + i]`, one KV head | **(c)** → T-3 |
| 40 | `witness.rs:286` | `total ∈ [2^F_E, T·2^F_E]` — scales with `T` | (a) |
| 41 | `witness.rs:298–308` | `σ_s < 2^WRHO_S`, `q ≤ 2^F_P`, two limbs for `p`, `ρ_s`, `σ_s` | **(c)** → T-6 |
| 42 | `argument.rs:449` | `endpoint()`: `log: 9`, `mask_row: 2` | **(c)** → T-5 |
| 43 | `argument.rs:505` | `causal_mask()` over `H·T·T` | **(c)** → T-10 |
| 44 | `argument.rs:509–520` | `rope_tables` over `T·heads·DH`, `i % HALF` | (a) |
| 45 | `argument.rs:522–535` | `table_values_u8/exp/act` indexed `0..N` | **(c)** → T-1 |
| 46 | `argument.rs:626` | `outer.trailing_zeros()` | **(c)** → T-2 |
| 47 | `argument.rs:629`, `:687` | `rho(0..4)` — the matmul inner variable count | (a) |
| 48 | `argument.rs:545`, `:553`, `:559`, `:599`, `:607`, `:618`, `:642–644`, `:656–658`, `:676`, `:679–680`, `:700–701`, `:754–755`, `:793–794`, `:832–834`, `:877–878`, `:903` | 26 challenge-vector lengths, each equal to a domain log or a `mu` count | (b) |
| 49 | `argument.rs:706–707` | `gamma_a[x % D]`, `gamma_m[x % D]` — the gain broadcast | (a), pad-sensitive (§3.7) |
| 50 | `argument.rs:805` | `cf[log - 3] = Flip(log - 3)` — the RoPE partner bit | **(c)** → T-8 |
| 51 | `argument.rs:851` | `nu[0].mul(k(T as i64))` — the row-sum host factor | (a) |
| 52 | `argument.rs:898` | `vec![Fp2::ONE; N]` in `SC_ZS` | **(c)** → T-1 |
| 53 | `protocol.rs:22` | `PcsParams { log_cols: LOG_N, inv_rate: 8, num_col_checks: 256 }` | **(c)** → §2.2 |
| 54 | `protocol.rs:33` | the absorbed parameter literal `T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/…` | (a), **moves every proof byte** |
| 55 | `protocol.rs:69` | `part_key`: `LOG_N` as the column-weight width | (a) |
| 56 | `protocol.rs:184–196` | `ENDPOINT_ROWS 7`, `ENDPOINT_PROX 4`, and the `(0..2)/(2..3)/(3..4)` row shape | **(c)** → T-5 |
| 57 | `protocol.rs:276`, `:435` | `NttTables::new(12)` — max encoded length 4,096 | (a), must become `new(16)` at `log_cols 14 / inv_rate 4` |
| 58 | `protocol.rs:288–311` | `N` as the histogram length and as the in-table test | **(c)** → T-1 |
| 59 | `wire.rs:19–25` | `VEC 512`, `ENC_COLS 2048`, `PATH 11`, `MASK_VEC 1024`, `MASK_DOM 4096`, `MASK_PATH 12`, `MAX_WIRE_BYTES 4 MiB` | (a) |
| 60 | `private_seam.rs:28–36`, `:64–72` | `LOG_COLS 8`, `INV_RATE 8`, `CHECKS 256`, `MAX_LOG_LEN 12`, `MASK_ROWS 5`; power-of-two axes and `len ≤ 4096` | **(c)** → T-5; **frozen by D17/R-2**, additive only |

Two sites in `zk.rs` are read but not owned by this module and are listed for
completeness: `zk.rs:373–375` (`MASK_LOG_MSG 9`, `MASK_LOG_DOM 12`,
`MASK_Q 256`) and `zk.rs:435`/`:444` (`n_base = 2·slots + 4`, and the assert
`L + 256 ≤ 512`). Neither is geometry-dependent; §5 shows there is room in
both at this shape and at 8B.

## 2. The layout at the 125M shape

### 2.1 The shape, and where it is recorded

The head geometry **is** recorded; it did not have to be assumed.

| parameter | value | source |
|---|---|---|
| layers | 12 | `LLM_POC_ROADMAP.md:28–32`, `M125_CALIBRATION_STUDY.md:20–23` |
| tokens `T` | 512 | `ATTENTION_INTEGER_SPEC.md:102–106` ("T = 512 contract workload") |
| width `d` | 768 | same |
| query heads `H` | **12** | same |
| KV heads `H_kv` | **4** (grouped-query, group 3) | same; `scripts/attention_spec_spike.py:46–54` |
| head dimension `d_h` | **64** | same; `results/hashline_attn_cost_125m.json:3–10` |
| feed-forward `f` | 2048 | `M125_CALIBRATION_STUDY.md:23` (resolves from `((8·768//3)+127)//128·128`) |
| RoPE | rotate-half, base 10000, non-interleaved | `ATTENTION_INTEGER_SPEC.md:103–105` |
| norm | RMSNorm, eps 1e-5, no biases | same |

So: **grouped-query attention, 12 heads of 64 over 4 KV heads.** This is *not*
what the toy module does (one KV head, `layout.rs:45`), which is trap T-3.
For contrast the 8B class is 32/8 heads of 128 at `d = 4096`, `f = 14336`
(`ATTENTION_INTEGER_SPEC.md:106–108`, `TARGET_CONTRACT.md:23–25`).

### 2.2 The row geometry: which `log_cols`, and why the toy's is not usable

The commitment lays the witness out as rows of `n = 2^log_cols` field
elements, encodes each row to `n · inv_rate` columns, Merkle-commits the
columns and opens `num_col_checks = 256` of them. Two things scale with the
row width: the **receipt** carries one column of *every* row for each of the
256 opened columns, so bytes go as `rows × 256 × 8`; and the encoded matrix
costs `rows × n × inv_rate × 8` bytes.

The block module uses `log_cols = 8, inv_rate = 8` (`protocol.rs:22`) — rows
of 256 words. Every other model-scale run in this repository uses
`log_cols = 14, inv_rate = 4, col checks 256`
(`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.1, from `hashline.rs:59`), and the
measured private feed-forward at exactly this shape ran at
`log_cols 14, inv_rate 4, col checks 256`
[MEASURED, `ZK60_FSP_MR1_PROGRESS.md` stage 4b, `probe-cpu-repaired-1.log:6–7`].

**Keeping `log_cols = 8` at the 125M shape is not an option.** The same
witness needs the same number of elements either way, so the *row count* goes
up by 64× as the row gets 64× narrower, and the receipt term
`256 × rows × 8 B` goes up with it:

| `log_cols` | A rows | A opening column data | H rows | H opening column data |
|---:|---:|---:|---:|---:|
| 8 (the toy's) | 347,521 | **712 MB** | 456,882 | **936 MB** |
| 14 (the layer prover's) | 5,681 | 11.6 MB | 7,186 | 14.7 MB |

[COUNTED: `256 · rows · 8 B`; row counts from §2.5.] A 1.6 GB receipt per
block is not a receipt. **The rest of this memo assumes `log_cols = 14`,
`inv_rate = 4`, `Q = 256`** — the layer prover's parameters, which also means
one set of PCS parameters for the whole private line instead of two (the same
recommendation the endpoints draft made and the security owner accepted,
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_DISPOSITION.md` §1.5). Consequences: `PATH`
becomes 16 (`log2(16384·4)`), `NttTables::new(12)` becomes `new(16)`
(`protocol.rs:276`, `:435`), and trap T-1 must be fixed first.

One soundness note, not a free change: `inv_rate 8 → 4` halves the code
distance and therefore changes the per-opening soundness figure. D15 says
every model-scale statement quotes the whole-proof figure, and the
whole-proof figure at 8B is dominated by the lookup term, not the commitment
term; the endpoints draft measured the analogous change as 2^-106.25 →
2^-105.61 per opening (`..._DISPOSITION.md` §1.5). **This memo does not
re-derive the soundness figure at the new parameters** — see §10.3.

### 2.3 The nine domains, padded

Every domain must be a power of two (T-4). Two axes of the 125M shape are
not: `d = 768` and `H = 12`. The project has already chosen how to handle
exactly this, on the public line: **`d 768 → 1024`, `12 heads → 16 slots`,
re-indexed so the KV group is the high bits, so the grouped-query map costs
nothing** (`results/hashline_attn_fulllayer.md:146–148`), at a measured cost
of "1.33× on the two dominant domains"
(`PROGRESS_UPERF3.md:11054–11055`). This memo adopts that, unchanged.

With `d_pad = 1024` and `H_pad = 16`:

| domain | meaning | true size | padded | log | waste |
|---|---|---:|---:|---:|---:|
| `T` | per token (norm denominators) | 512 | 512 | 9 | 1.00× |
| `Ht` | (head, token): row max and row sum | 6,144 | 8,192 | 13 | 1.33× |
| `L` | 16 packed limb sub-planes of `T` | 4,608 | 8,192 | 13 | 1.78× |
| `D` | (token, width) | 393,216 | 524,288 | 19 | 1.33× |
| `Q` | (token, head, head-dim) | 393,216 | 524,288 | 19 | 1.33× |
| `Kv` | (token, kv-head, head-dim) | 131,072 | 131,072 | 17 | 1.00× |
| `S` | (head, token, token): scores | 3,145,728 | 4,194,304 | 22 | 1.33× |
| `F` | (token, feed-forward) | 1,048,576 | 1,048,576 | 20 | 1.00× |
| `Tab` | the three 256-entry tables | 256 | 256 | 8 | 1.00× |

[COUNTED.] Three remarks.

* **`Q` and `D` coincide again**, by luck: `d_pad = 1024 = H_pad · d_h =
  16 · 64`. At the toy they coincide for the same reason (`T·D = T·H·DH`).
  The `Wo` matmul reads an `A_O8` laid out on `Dom::Q` and produces a claim
  on `Dom::D` (`argument.rs:624`, `:717`); that still lines up at 125M with
  no re-tiling, and it lines up at 8B too (`32 · 128 = 4096 = d`). It would
  fail at any model where `H · d_h ≠ d` after padding — Gemma-class shapes
  with a separate global head dimension are the example
  (`PROGRESS_UPERF3.md:362–370`) — so the equality deserves a
  construction-time assert rather than a comment.
* **`Kv` needs no padding**: `4 · 64 = 256` and `T · 256 = 2^17`.
* **`L` is the worst-padded domain** (1.78×) but is also the smallest, at one
  row. Leave it.

### 2.4 Plane by plane

Plane identities, integer classes and commitment assignment are unchanged
from the toy (`layout.rs:114–199` for `A`, `:223–240` for `H`); what changes
is the domain size under each and two new planes. Rows are
`padded size / 16,384`, floored at 1.

**`A` — the witness commitment.** 83 planes (81 today, plus two forced by the
widened softmax window, §3.4).

| domain | planes | what they are | rows each | rows total |
|---|---:|---|---:|---:|
| `T` | 4 | `D`, `D²` for each norm | 1 | 4 |
| `Ht` | 2 | masked row max, masked row sum | 1 | 2 |
| `L` | 2 | the byte limbs of `D`, `a1`, `a2` for each norm | 1 | 2 |
| `D` | 35 | input, its limbs, `y`, ρ/σ (4+4), attention out and limbs, residual 1, `nm`, ρ/σ (4+4), `z16`, residual 2 and limbs, down remainder | 32 | 1,120 |
| `Q` | 7 | `q8`, its remainder, rotated `q`, its remainder, `o8`, two `o` remainder limbs | 32 | 224 |
| `Kv` | 6 | `k8`, `v8`, rotated `k`, and three remainders | 8 | 48 |
| `S` | **13** | `s8`, its remainder, the selector, `exp`, `p`, `p`'s 2 limbs, ρ_s **3**, σ_s **3** | 256 | 3,328 |
| `F` | 11 | gate, gate remainder, activation, up and limbs, product and limbs, 2 product-remainder limbs | 64 | 704 |
| `Tab` | 3 | the three lookup multiplicity histograms | 1 | 3 |
| | | | **A data rows** | **5,435** |

**`H` — the LogUp helper commitment.** Every helper is `Fp2`-valued, so each
plane is two rows of the same length (`layout.rs:576–582`). **51 planes, the
same count as today** — `Dom::S` gains a helper and `Dom::D` loses one (§4).

| domain | planes | rows each (×2) | rows total |
|---|---:|---:|---:|
| `L` | 1 | 1 | 2 |
| `D` | **18** | 32 | 1,152 |
| `Q` | 7 | 32 | 448 |
| `Kv` | 6 | 8 | 96 |
| `S` | **9** | 256 | 4,608 |
| `F` | 6 | 64 | 768 |
| `Tab` | 4 | 1 | 8 |
| | | **H data rows** | **7,082** |

**`M` — the mask commitment.** Shape-independent: `2 · N_SLOTS + 4` base rows
of 4,096 encoded positions (`zk.rs:435`, `:373–375`). **50 rows**, exactly as
at the toy, because the slot count does not change. §5.

**Claim sites and mask rows.** Each claim site gets two reserved rows on its
commitment. The site counts move only with the two new `Dom::S` planes and the
two lookup changes of §4: `A` sites **120 → 122**, `H` sites **51 → 51**
(`SC_SZC` gains one helper, `SC_DZC` loses one). Mask-pair rows: `A` 244,
`H` 102; plus one proximity pair each.

* `A` rows = 5,435 + 244 + 2 = **5,681**
* `H` rows = 7,082 + 102 + 2 = **7,186**
* `M` rows = **50**

[COUNTED; the same arithmetic reproduces the toy's 213 / 455 / 280 / 384 and
the toy's per-domain lookup totals exactly — that reproduction is the check
that these counts are computed the module's way and not a guess.]

**The waste worth knowing about.** 244 + 102 = 346 mask-pair rows are full
16,384-wide rows of fresh randomness = **45 MB systematic, 182 MB encoded**,
and many of them serve claims on sub-row planes (the eighteen `Dom::L`
sub-slices use 512 of 16,384 columns each, T-7). That is 2.9% of the
commitment; not worth a redesign, worth knowing before someone is surprised
by it.

### 2.5 Totals, against the toy and against the private feed-forward

| | toy block (T32/d16/f16) | **125M complete private block** | private feed-forward at 12×512 |
|---|---:|---:|---:|
| `A` rows | 455 | **5,681** | 585 per layer |
| `H` rows | 384 | **7,186** | 486 per layer |
| `M` rows | 50 | **50** | 16 per layer |
| `W` rows (public weights) | — (weights not committed) | — | 288 per layer |
| row width | 256 | **16,384** | 16,384 |
| `inv_rate` | 8 | **4** | 4 |
| `A` systematic / encoded | 0.93 MB / 7.5 MB | **710 MiB / 2,840 MiB** | 76.7 MB / 307 MB |
| `H` systematic / encoded | 0.79 MB / 6.3 MB | **898 MiB / 3,593 MiB** | 63.7 MB / 255 MB |
| receipt | 2,816,472 B | **≈ 38.7 MiB** (§7) | 7,363,039 B per layer |

The toy and the feed-forward columns are facts
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md` §3 for 2,816,472 B;
`ZK60_FSP_MR1_PROGRESS.md` stage 4 for 585/486/16 and 88,356,464 B over 12
layers). The middle column is this memo's count.

**The one-line comparison the security owner asked for.** Per 12 layers, the
private feed-forward is 585 + 486 = 1,071 rows *per layer*, 12,852 rows for
the pass. One complete private *block* at the same shape is 5,681 + 7,186 =
12,867 rows — **for one layer**. A complete private block is therefore
about **twelve times** the committed material of the private feed-forward of
the same layer, and a 12-block pass is about twelve times the whole measured
feed-forward pass. That ratio, not any subtlety, is the cost of hiding the
attention half.

**Where the material actually is.** `Dom::S` — the score/softmax cube — is
3,328 of 5,435 `A` data rows and 4,608 of 7,082 `H` data rows: **63% of the
whole block's committed material sits on one domain**, which exists only
because attention compares every token with every token. Any future cost
lever should start there (§10.1, decision 9).

## 3. The arithmetic at real width

### 3.1 The rule every bound must satisfy

The proof works over the field of integers modulo
`p = 2^64 − 2^32 + 1 = 18,446,744,069,414,584,321`. The module's relations are
*integer* identities embedded in that field, so every one of them must be
argued not to wrap — the module states this premise in prose and leaves it to
the reviewer (`layout.rs:281–309`, "CONSTRUCTION PREMISE (integer soundness;
to be re-derived by the reviewer, not checked by code)"). **D16 item 5
requires that premise to be re-derived on any widened layout.** This section
does that.

Three thresholds matter, in increasing severity:

* **`2^49`** — the informal comfort limit the module's own premise uses
  (`D² + a1 < 2^49`). Crossing it is not an error; it means the argument has
  to be written out rather than waved at.
* **`2^63`** — beyond this, a *signed* intermediate in the witness builder
  (which computes in `i64`) can overflow before it ever reaches the field.
* **`p`** — beyond this the field identity stops being an integer identity
  and the relation is unsound.

A fourth threshold is not about wrapping at all: each declared **class**
(int8, int16) and each declared **window** (a remainder in `[0, 2^s)`) is
enforced by lookups, and if the honest value exceeds it the *prover refuses*.
That is a completeness failure, and it is the one that actually bites at
width 768.

### 3.2 The matmul accumulations

| accumulation | terms | operands | worst case | vs `2^49` | forced change |
|---|---:|---|---:|---|---|
| Q, K, V projections | 768 | int8 × int8 | 12,387,072 = 2^23.56 | 2^-25 | none |
| output projection `Wo` | 768 | int8 × int8 | 12,387,072 = 2^23.56 | 2^-25 | none |
| gate, up | 768 | int8 × int8 | 12,387,072 = 2^23.56 | 2^-25 | none |
| down | 2048 | int16 × int8 | 8,522,565,632 = 2^32.99 | 2^-16 | none |
| scores | 64 | int8 × int8 | 1,032,256 = 2^19.98 | 2^-29 | none |
| value mixing (PV) | 512 | `p ≤ 2^9` × int8 | 33,292,288 = 2^24.99 | 2^-24 | none |

[COUNTED; the 768 and 2048 figures agree with the recorded accumulator study
`results/m125_int8_calibration.json` → `accumulators/768 max_abs_acc
12,387,072, signed_bits 25` and `accumulators/2048 max_abs_acc 33,032,192`
(that entry is int8×int8; the int16×int8 form above is the private block's
`down`, which the study does not cover).] The toy's figures are 2^18, 2^17,
2^21 and 2^26. **No accumulation comes near `2^49`, let alone `p`. No new
limb plane is forced by any matmul.** The widening of the matmuls is
genuinely mechanical.

What *is* forced is a new **calibration**. Each accumulation is
requantised by a right shift, and at 48× the inner dimension the shifts move:
a saturated worst case would need `SH_QKV ≈ 17` (today 7), `SH_S ≈ 13`
(today 6), `SH_Z ≈ 18` (today 6). Real shifts come from the measured
calibration of the real checkpoint (`results/m125_int8_calibration.json`
records `eX −2, eGate −3, eUp −3, eA −3, eH 0, eZ 1, eW −9` per layer, from
`frugal-lm/runs/125m-baseline/ckpt-00009536`), not from the saturated bound.
**Each shift is welded to a remainder-window lookup coefficient** (trap
T-6, `layout.rs:344`, `:346`, `:348`, `:352`–`:363`), so the calibration and
the lookup list must be changed in one step, and the module's own
`the_endpoint_scales_and_calibration_are_the_approved_ones` test extended.

### 3.3 The two norms (D16's precondition, checked at d = 768)

The relation, unchanged from the toy (`witness.rs:157–208`,
`argument.rs:583–593` and `:726–734`): for each token row `x`,

```
ss  = Ceps + Σ_i x_i²           D = isqrt(ss)      a1 = ss − D²    a2 = 2D − a1
y_i = floor( (2·x_i·γ_i·Cn + D·2^tn) / (D·2^{tn+1}) )
ρ_i = the remainder,  σ_i = den − 1 − ρ_i,  den = D·2^{tn+1} = 4096·D
```

with `Ceps = 1`, `Cn = 1024`, `tn = 11`. `D`, `a1`, `a2` are range-proved by
three byte limbs each; `ρ`, `σ` by four byte limbs each, the top one
additionally under `scaled(l3, 1 << (32 − NORM_WRHO))` so the window is
exactly `2^NORM_WRHO`.

**D16's five items, checked at `d = 768`:**

| D16 item | requirement | at `d = 768`, input class int16 | verdict |
|---|---|---|---|
| 1 | `D` keeps a direct byte-limb pin with `⌈log256(Dmax+1)⌉` limbs | `ss ≤ 1 + 768·32767² = 2^39.58`; `Dmax = 908,065 = 2^19.79`; **3 limbs** | **holds, unchanged** |
| 2 | `a1`, `a2` the same, and their exclusion lapses at four limbs | `a1 ≤ 2·Dmax = 1,816,130 = 2^20.79`; **3 limbs** | **holds**; the alias exclusion does **not** lapse |
| 3 | never more than four limbs (the square relation wraps at five) | `D² + a1 = 2^39.58`, far below `p` | **holds with 24 bits to spare** |
| 4 | the remainder window stays exact, its coefficient rewritten | `den ≤ 4096·908,065 = 3,719,434,240 = 2^31.79` → **`NORM_WRHO` must go 29 → 32** | **holds, but at the ceiling** |
| 5 | the wraparound premise re-derived | this section | done |

[COUNTED, all of it.] Item 4 is the finding.

**The window is 0.21 bits from the end of the construction.** The layout
writes the window coefficient as `1 << (32 − NORM_WRHO)` (`layout.rs:321`,
`:323`, `:329`, `:331`), which **underflows for any `NORM_WRHO > 32`** — W2 of
`ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` §5, and D16 item 4 says so. At
`NORM_WRHO = 32` the coefficient is `1`, so the `scaled` lookup becomes a
duplicate of its own `byte` lookup and is dropped (that is the −2 lookups and
−1 helper of §4). The honest requirement at width 768 with an int16 input is
`2^31.79`; the ceiling is `2^32`; **the margin is a factor 1.155, or 0.208
bits.** For comparison:

| geometry | `Dmax` | `den = 2^{tn+1}·D` | honest `wrho` | expressible? |
|---|---:|---:|---:|---|
| toy `d 16`, int16 | 131,068 | 2^29.00 | 29 | yes, exactly saturated (W1) |
| **125M `d 768`, int16** | **908,065** | **2^31.79** | **32** | **yes, 0.21 bits left** |
| 125M `d 768`, int8 input | 3,519 | 2^23.78 | 24 | yes, 8.2 bits left; `D` needs only 2 limbs |
| 8B `d 4096`, int16 | 2,097,088 | 2^33.00 | 33 | **no** — the construction cannot express it |

Two consequences, one now and one later.

* **Now (decision 2 of §10.1).** The block's declared input class is int16
  (`witness.rs:314`, `:322`), but the real 125M residual stream is not
  int16-wide: the calibration study records `x absmax ≈ 20.6` at `eX = −2`,
  i.e. `|x_int| ≲ 83` — inside int8
  (`results/m125_int8_calibration.json`, `calibration[1].stats.x.absmax`
  and `eX`). If the profile **declares** a narrower input class than int16 —
  and it must declare *something*, because D12 item 4 makes the second norm's
  int8 range proof mandatory precisely because the feed-forward proves no
  range on its input — then `Dmax` collapses and the window has eight bits of
  margin instead of a fifth of one. The declaration is a product decision
  (it is a refusal on real inputs if the model ever exceeds it), which is why
  it is a decision and not a note.
* **Later.** At 8B the present remainder construction does not reach. That is
  independent of this memo's recommendation and independent of form S versus
  form E; it is a piece of work the 8B private block needs whatever else is
  decided (§10.2).

**The half-`p` isqrt alias stays excluded.** The alias `D → k + (p−1)/2` is
refused by three independent facts at the toy; the norm-range lane computed
that exclusion 3 "refuses iff `wrho < tn + 31`", i.e. iff `wrho < 42`
(`ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` §3.3). At `wrho = 32` it refuses
with **10 bits of margin**, and exclusion 2 (three limbs on `a1`) refuses
structurally. [COUNTED from that lane's rule; not re-derived here.]

### 3.4 The attention scores, the causal mask and the integer softmax

Exactly how the module does softmax, since the brief asks for it stated
precisely (`witness.rs:256–309`, `argument.rs:831–872`):

1. **Masked maximum.** For each (head, token) row, the masked score is `s8[j]`
   for `j ≤ t` and the constant `MASK_SCORE = −127` otherwise. The prover
   commits the row maximum `mx` (`A_MX`, on `Dom::Ht`) and a one-hot selector
   `zsel` (`A_ZSEL`, on `Dom::S`) marking one position attaining it. The
   argument proves `zsel² = zsel` and `zsel · (mx − masked) = 0`
   (`argument.rs:858–859`), plus a row-sum claim that `Σ_j zsel = 1`
   (`SC_RS`, `:614`, batched with the exp row sum by a challenge `λ`).
2. **The exponential table.** `delta = mx − masked ∈ [0, 256)` indexes a
   public 256-entry table, and the pair `(delta, E)` is proved to be a table
   row by a LogUp lookup under its own tag (`argument.rs:863`,
   `table_values_exp` `:526`). `delta < 256` holds because scores are int8
   and the mask constant is `−127`: `delta ≤ 127 + 127 = 254`, **independent
   of `T` and of the width**.
3. **The normaliser.** `Sum = Σ_{j ≤ t} E[j]`, committed on `Dom::Ht`
   (`A_SUM`) and tied to the exp plane by the same `SC_RS` row-sum claim.
4. **The division.** `p[j] = floor(E[j]·2^{F_P} / Sum)` with remainder `ρ_s`
   and complement `σ_s = Sum − 1 − ρ_s`; the argument proves
   `2^{F_P}·mask·E − p·Sum − ρ_s = 0` and `σ_s + ρ_s + 1 − Sum = 0`
   (`argument.rs:860–861`). Off the causal support this forces `p = ρ_s = 0`
   because `Sum ≥ 2^{F_E} > 0`.

**What changes at `T = 512`, `H = 12`, `d_h = 64`:**

| quantity | toy bound | 125M bound | window today | forced change |
|---|---:|---:|---|---|
| score accumulation | 2^17 | 2^19.98 | — | calibration only (§3.2) |
| `delta` | < 256 | **< 256** | 256-entry table | **none** |
| `Sum` | `T·2^{F_E} = 2^14` | `T·2^{F_E} = 2^18` | `WRHO_S = 14` | **`WRHO_S 14 → 18`** |
| `ρ_s`, `σ_s` | `< 2^14`, two limbs with `scaled(l1, 4)` | `< 2^18` | two limbs | **three limbs, `scaled(l2, 64)`** |
| `p` | `≤ 2^{F_P} = 512`, two limbs with `scaled(l1, 64)` | unchanged | `2^10` | none (the window is one bit loose today — W7 of the norm lane) |
| `p·Sum + ρ_s` | 2^25 | **2^27.00** | — | none |
| causal mask | public, `H·T·T` | public, `2^22` | — | memory only (T-10) |

[COUNTED.] **The softmax window is the second exactly-saturated window** (W3
of `ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` §5: `Sum ≤ 2^14` at `T = 32` and
the proved window is `2^14`). Because `Sum` scales linearly with the token
count, this window breaks at *every* token count above 32, independent of
width. The repair is a third byte limb on each of `ρ_s` and `σ_s`, which is
why §2.4 carries **two new `A` planes on `Dom::S`** — and `Dom::S` is the
most expensive domain in the proof, so this one-bit-of-bookkeeping repair
costs **512 committed rows** (2 planes × 256 rows) and 8.4 MB systematic /
33.6 MB encoded. That is the single most expensive consequence of a range
window in the whole memo, and it is worth stating plainly: *the softmax
remainder is proved on the score cube, so anything the score cube needs is
multiplied by four million.*

An alternative exists and should be recorded rather than adopted here: prove
`ρ_s` and `σ_s` against `Sum` (which is on `Dom::Ht`, 8,192 entries) instead
of by absolute limbs, using the existing `c3` identity plus a single
comparison. It saves the two planes but adds a cross-domain claim; §10.1
decision 6.

### 3.5 The value mixing, the output projection and the two residuals

* **PV.** `o_acc[t, h, i] = Σ_{j ≤ t} p[h,t,j] · v8[j, kv(h), i]` over up to
  512 positions: `≤ 512 · 512 · 127 = 33,292,288 = 2^24.99` [COUNTED]. No
  change. Under grouped-query the `v8` index gains the `kv` coordinate
  (T-3); in the `SC_PV` slot that is a change to the claim point of `A_V8`
  (`argument.rs:663–665`), from `rho(0..5) ++ fixed(r_i)` to
  `rho(0..9) ++ fixed(r_kv) ++ fixed(r_i)`, not a new mechanism.
* **Residual 1 and residual 2.** `xres1 = x + ao`, `xres2 = xres1 + z16`,
  both with all three shifts zero, both proved as `c5`/`c9`
  (`argument.rs:731`, `:737`) with an int16 class on each side. Unchanged at
  any width: the bound is the class, not the dimension. The int16 class on
  `xres2` is what makes the residual stream int16 and therefore what drives
  §3.3's `Dmax`; narrowing the class (decision 2) narrows both.
* **Output projection requantisation.** `host_wo = 2^{SH_AO}·ao + ral −
  2^{SH_AO−1}` (`argument.rs:743`) with `ral` a single byte limb under
  `byte` + `scaled(·, 2)` — i.e. a 7-bit window welded to `SH_AO = 7`. At the
  new calibration `SH_AO` moves and this pair must move with it (T-6, T-11).

### 3.6 The feed-forward

This half is the one that is already measured at this shape, and its
arithmetic is the least affected by the widening because its inner dimensions
(`d = 768` for gate/up, `f = 2048` for down) enter only the accumulations of
§3.2.

| relation | expression | worst case | change |
|---|---|---:|---|
| gate class | `g8 ∈ [−128, 127]`, from the 256-row activation table itself | — | none (T-9) |
| activation pair lookup | `(g8 + 128, a16)` a row of the public table | — | none |
| up | `u16` int16, `SH_U = 0` so no remainder plane | 2^15 | none |
| product | `a16 · u16 − 2^{SH_H}·h16 − rh + 2^{SH_H−1} = 0` | `a16·u16 ≤ 2^30.00`, whole term `≤ 2^30.58` | none |
| down | `2^{SH_Z}·z16 + rd − 2^{SH_Z−1}` against a 2048-term accumulation | 2^32.99 | calibration only |

[COUNTED.] The product bound `2^30` is width-independent (it is int16 ×
int16). **Nothing in the feed-forward half forces a new plane, a new limb or a
wider table at the 125M shape.** That is consistent with the fact that the
feed-forward at exactly this shape already proves, publicly and privately, on
this box (`ZK60_FSP_MR1_PROGRESS.md` stage 4b).

One erratum of the toy travels unchanged and should be re-checked at the new
calibration: wherever `u16 = 0` the product relation says nothing about
`a16`, and only the pair lookup pins it (E-22, and the implementation
disposition's "test I asked for above all others"). That test must be
regenerated at the new shape, because the public fixture that makes a zero
`up` column is shape-specific.

### 3.7 What the pad must contain, constraint by constraint

This is trap T-4 made concrete, and it is the part of the widening a
generator cannot do by itself. At the toy shape no domain is padded, so the
question has never been asked. At 125M, `Dom::D`, `Dom::Q`, `Dom::S` and
`Dom::Ht` carry padded positions (a width index in `[768, 1024)`, or a head
index in `[12, 16)`), and **every constraint that is not homogeneous in the
witness is violated there unless the prover fills the pad deliberately.**

Going through `SC_DZC`'s eleven constraints (`argument.rs:726–738`) and
`SC_SZC`'s five (`:858–862`) at a padded position:

| constraint | at the pad with all-zero planes | fill that satisfies it |
|---|---|---|
| `c0` norm numerator `2·Cn·γ·x + 2^tn·D − 2^{tn+1}·y·D − ρ` | `2^tn·D_t ≠ 0` — **fails** | `γ_pad = 0`, `y = 0`, **`ρ = 2^tn·D_t`** |
| `c1` `σ + ρ + 1 − 2^{tn+1}·D` | `1 − 2^{tn+1}·D_t ≠ 0` — **fails** | **`σ = 2^tn·D_t − 1`** (then `c1` closes exactly) |
| `c2`, `c4`, `c8`, `c10` int16 limb decompositions `v + 32768 − (l0 + 256·l1)` | `32768 ≠ 0` — **fails** | limbs of `32768`: `l0 = 0`, `l1 = 128` |
| `c3` `ao + 32768 − limbs` | as above | as above |
| `c5`, `c9` residuals `x1 − x − ao` | `0` — holds | zeros |
| `c6`, `c7` norm_m | as `c0`, `c1` | as `c0`, `c1` |
| host `2^{SH}·v + r − 2^{SH−1}` (four of them) | `−2^{SH−1} ≠ 0` — **fails** | `r = 2^{SH−1}` (a legal biased remainder) |
| `SC_SZC c0`, `c1` selector | `0` — holds | zeros |
| `SC_SZC c2` `2^{F_P}·mask·E − p·Sum − ρ_s` | `0` — holds | zeros |
| `SC_SZC c3` `σ_s + ρ_s + 1 − Sum` | `1 ≠ 0` — **fails** | `Sum_pad = 1`, `ρ_s = 0`, `σ_s = 0` (or a public support factor) |
| `SC_SZC c4` `p − limbs(p)` | `0` — holds | zeros |
| LogUp helper relations | hold — the helper is computed from whatever value is there | — |
| `sym` lookups `v + 127`, `127 − v` | hold at `v = 0` | — |

Two checks on the proposed fill. First, **is it in range?** `ρ = 2^tn·D_t`
needs `2^tn·Dmax = 2048 · 908,065 = 2^30.79 < 2^32` — yes, inside the
`NORM_WRHO = 32` window, with the same 1.2 bits the honest values have.
Second, **does it disturb any claimed sum?** The row-sum slots `SC_SS` /
`SC_SSM` sum `eq(r_t, t)·x²` over `Dom::D`, and the pad has `x = 0`
(`argument.rs:548`); the `Dom::Ht` row sums are over `Dom::S` with a padded
`Sum = 1` contributing to `SC_RS`'s host term
`nu[0]·T·(Sum + λ)` (`:851`, `:868`) — **this one does not vanish**, so
either the padded heads must be excluded from that host term by a public
factor, or `Sum_pad` must be chosen so the host term still closes. That is
one genuine open item in the fill, and it is why the honest recommendation is
the other option:

**Recommendation: a public support indicator, not a clever fill** (§10.1,
decision 3). Multiply each inhomogeneous constraint group by a public 0/1
table `supp(x)` that is 1 on the real positions. Cost: one public `Fp2` table
per padded domain (`Dom::D` 8 MB, `Dom::S` 67 MB, built once per slot), and
**degree +1 on `SC_DZC` and `SC_SZC`** (4 → 5), which moves their `L` from
82/94 to 102/117 — still far inside the 256 budget (§5). Benefit: the pad
holds zeros, the fill needs no per-constraint derivation, the "what does the
pad contain" question stops being a soundness question, and the prover cannot
smuggle anything into the pad because the whole pad is multiplied by zero in
every constraint and by zero in every claimed sum. The causal mask
(`argument.rs:505`) is already exactly this device, so the pattern is in the
module.

### 3.8 Summary table of the bounds

| # | quantity | toy | 125M | limit | margin | forced change |
|---|---|---:|---:|---:|---|---|
| 1 | QKV / `Wo` / gate / up accumulation | 2^18 | 2^23.56 | 2^49 | 2^25 | none |
| 2 | down accumulation | 2^26 | 2^32.99 | 2^49 | 2^16 | none |
| 3 | score accumulation | 2^17 | 2^19.98 | 2^49 | 2^29 | none |
| 4 | PV accumulation | 2^21 | 2^24.99 | 2^49 | 2^24 | none |
| 5 | `a16·u16` | 2^30 | 2^30.00 | 2^49 | 2^19 | none |
| 6 | `D² + a1` | 2^34 | 2^39.58 | `p` | 2^24 | none |
| 7 | `D` limbs | 3 | **3** | 4 (D16 item 3) | 1 | none |
| 8 | `a1`, `a2` limbs | 3 | **3** | 4 | 1 | none |
| 9 | norm remainder window | 2^29 (full) | **2^31.79** | **2^32** (construction) | **0.21 bits** | `NORM_WRHO 29 → 32`, drop 2 lookups |
| 10 | softmax `Sum` | 2^14 (full) | **2^18** | limbs | — | `WRHO_S 14 → 18`, **+2 planes on `Dom::S`** |
| 11 | `p·Sum + ρ_s` | 2^25 | 2^27.00 | 2^49 | 2^22 | none |
| 12 | `delta` | < 256 | **< 256** | 256 | — | none |
| 13 | LogUp multiplicity | ≤ 61,440 | ≤ 99,631,104 | `p` | 2^37 | none |
| 14 | the pad | does not exist | 5 domains padded | — | — | **support indicator** (§3.7) |

**Two windows fail; nothing wraps; no accumulation needs a new limb.** The
widening is arithmetically safe and bookkeeping-heavy — with the single
caveat that item 9 is 0.21 bits from the end of the road.

## 4. The lookup tables

**The question the plan poses — "one U8 table versus the declared table set at
width ≫ 16" — was already answered when the block module was built, and the
answer survives the widening.** The private attention construction's declared
table set had two 65,536-entry range tables, which were the largest single
cost item in that construction (about 77 MB). The block module **replaced
them with byte limbs through a single 256-entry table**, and records it as a
deviation from the schedule file:

> "This component ranges every value through the single 256-entry `U8` table
> by byte limbs (the lever section 6 of the construction records), so every
> table is ONE row and no block mask exists." — `layout.rs:30–36`

There are exactly three tables, all 256 entries, all one committed row of
multiplicities each (`A_MU8`, `A_MEXP`, `A_MACT`, `layout.rs:195–197`) and
one helper row-pair each (`H_GU8`, `H_GEXP`, `H_GACT`, `:235–237`), all three
under distinct tags (`TAG_U8`, `TAG_EXP`, `TAG_ACT`, `protocol.rs:333–335`).

| table | entries | what it proves | at 125M |
|---|---:|---|---|
| `U8` | 256 | every byte limb and every `sym` half is in `[0, 256)` | **unchanged** |
| `exp` | 256 | the pair `(delta, E)` is a row of the public exponential table | **unchanged** — `delta < 256` is width- and token-independent (§3.4) |
| `act` | 256 | the pair `(g8 + 128, a16)` is a row of the public activation table | **unchanged** — the gate is int8 by construction |

**So the table set does not change at all.** What changes is the number of
lookups into it, and the helper planes that carry them.

| domain | lookups per position | positions (padded) | total lookups | helper planes |
|---|---:|---:|---:|---:|
| `L` | 2 | 8,192 | 16,384 | 1 |
| `D` | **36** (38 today, −2) | 524,288 | 18,874,368 | **18** (19 today) |
| `F` | 9 | 1,048,576 | 9,437,184 | 5 |
| `Q` | 13 | 524,288 | 6,815,744 | 7 |
| `Kv` | 12 | 131,072 | 1,572,864 | 6 |
| `S` | **15** (13 today, +2) | 4,194,304 | 62,914,560 | **8** (7 today) |
| | | | **99,631,104** | **45** |
| `exp` pair | 1 | 4,194,304 | 4,194,304 | 1 (`H_SEXP`) |
| `act` pair | 1 | 1,048,576 | 1,048,576 | 1 (`H_FACT`) |

[COUNTED, the module's own rule `lookups(dom).len() × dom.len()` and
`helpers = ⌈lookups/2⌉`; the same arithmetic reproduces the toy's declared
`[1024, 19456, 4608, 6656, 3072, 26624]` and 61,440 exactly
(`layout.rs:744–746`).]

**61,440 → 99,631,104 U8 lookups, a factor of 1,621.** Three observations.

1. **Multiplicities cannot wrap.** The largest histogram entry is bounded by
   the total, `< 2^27`, against a field of `2^64`. The module's premise
   ("The LogUp multiplicities (at most 61,440) cannot wrap",
   `layout.rs:308–309`) is re-derived, with a 2^37 margin.
2. **Two lookup-list changes, both consequences of §3:** `Dom::D` loses the
   two now-redundant `scaled(ρ_top, 1 << (32 − NORM_WRHO))` lookups when
   `NORM_WRHO` reaches 32 (the coefficient becomes 1, duplicating the `byte`
   lookup), and `Dom::S` gains two, for the third limb of `ρ_s` and `σ_s`.
   Net: helper planes 51 → 51, but `Dom::S`'s helpers each cost 512 rows and
   `Dom::D`'s each cost 64, so the swap is **+448 `H` rows**.
3. **63% of all lookups are on the score cube.** 62.9M of 99.6M, plus the
   4.2M exp pairs. Every lookup costs one field inverse in the helper
   computation and one `H` element; §7 shows that is where the helper phase's
   time goes.

**Should the table set change?** No — not at this shape and not for this
reason. Two levers exist if the helper cost ever needs cutting, both recorded
and neither recommended now: a 16-bit table would halve the limb count on
int16 planes (2 limbs → 1 lookup) but reintroduces the 65,536-entry table the
module deliberately removed, and its multiplicity plane becomes 4 rows rather
than 1; and the `sym` idiom (two lookups per int8 value, `layout.rs:274–276`)
could become one lookup into a dedicated 255-entry signed table, saving about
**11 million** lookups at 125M (the `sym` pairs on `Dom::Q`, `Dom::Kv`,
`Dom::S` and `Dom::D`) at the cost of a fourth table and a fourth tag. The
second is the better one if it is ever needed; §10.1 decision 9 names the
measurement that would justify it.

## 5. The masked sumchecks

**What the machinery is.** Each of the 23 slots is a sumcheck whose round
polynomials are blinded by a committed masking polynomial: the prover
publishes `s + c·G` instead of the true sum `s`, and every round message is
offset by the mask's corresponding coefficient. The masks live in their own
commitment `M`, two base rows per slot (real and imaginary parts) plus four
(`b_re, b_im, u_re, u_im`), i.e. `n_base = 2·slots + 4` (`zk.rs:435`). Each
mask row carries `L` coefficients followed by **`Q = 256` random pads** in a
message of **512** positions, and `mask_commit` asserts
`L + 256 ≤ 512` (`zk.rs:444`). `L = (main rounds + extension rounds) ·
degree + 2` (`layout.rs:730–733`).

**Every slot at the 125M shape.** Main rounds are the domain log (or the
matmul's inner-index log); the degree is unchanged except where §3.7's support
indicator adds one.

| slot | rounds (toy → 125M) | ext | deg | `L` toy | `L` 125M | `L` + 256 | with support factor |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01 `SS` row sums norm_a | 9 → 19 | 1 | 3 | 32 | 62 | 318 | — |
| 01m `SS` norm_m | 9 → 19 | 1 | 3 | 32 | 62 | 318 | — |
| 02 norm squares zero-check | 5 → 9 | 1 | 3 | 20 | 32 | 288 | — |
| 08 limb zero-check | 9 → 13 | 1 | 4 | 42 | 58 | 314 | — |
| 07 masked row sums | 11 → 22 | 1 | 3 | 38 | 71 | 327 | 94 |
| 09Q / 09K / 09V matmul | 4 → 10 | 1 | 2 | 12 | 24 | 280 | — |
| 10 score matmul | 3 → 6 | 2 | 2 | 12 | 18 | 274 | — |
| 11 PV matmul | 5 → 9 | 2 | 2 | 16 | 24 | 280 | — |
| 12 `Wo` matmul | 4 → 10 | 1 | 2 | 12 | 24 | 280 | — |
| 13G / 13U matmul | 4 → 10 | 1 | 2 | 12 | 24 | 280 | — |
| 13D matmul | 4 → 11 | 1 | 2 | 12 | 26 | 282 | — |
| 03 `D` zero-check | 9 → 19 | 1 | 4 | 42 | 82 | 338 | **102** |
| 04 `Q` zero-check | 9 → 19 | 1 | 4 | 42 | 82 | 338 | 102 |
| 05 `KV` zero-check | 8 → 17 | 1 | 4 | 38 | 74 | 330 | — |
| **06 softmax zero-check** | 11 → **22** | 1 | 4 | 50 | **94** | **350** | **117** |
| 14 `F` zero-check | 9 → 20 | 1 | 4 | 42 | 86 | 342 | — |
| TAB table helpers | 8 → 8 | 1 | 3 | 29 | 29 | 285 | — |
| ZS zero-sum row | 8 → 8 | 1 | 2 | 20 | 20 | 276 | — |
| IO-in / IO-out | 9 → 19 | 1 | 2 | 22 | 42 | 298 | — |

[COUNTED.] **The closest slot to the limit is `SC_SZC`, the softmax
zero-check, at `L = 94` of a 256 budget — 37% used, or 46% if it carries the
support factor.** Nothing is close. The other requested figures:

* `n_base = 2 · 23 + 4 = **50**` — `M` has **50 rows**, exactly as at the toy,
  because the slot count does not change. `M`'s cost is shape-independent:
  50 rows × 4,096 coset positions × 8 B = **1.6 MB**, and its opening is
  238 KiB (§7).
* **Reserved mask pairs:** one per claim site, 122 on `A` and 51 on `H`
  (§2.4), each two rows, audited by `audit_claims` (`protocol.rs:89–133`):
  every reserved pair touched by exactly one claim, every evaluation claim
  touching exactly its own adjacent pair, only the LogUp sum claim pairless.
  That audit is shape-general already and needs no change.
* **Pads:** `q_pad = Q = 256` per mask row, unchanged (`zk.rs:375`).

**At 8B, for the record.** The largest domain becomes `H·T·T = 32·512·512 =
2^23`, so `SC_SZC` would run 23 + 1 rounds at degree 4: `L = 98`, or 122 with
a support factor — still 38% / 48% of the budget. The masking commitment is
**not** a scaling problem on this line at any shape the project has named;
the real ceiling is the 64-bit shift inside `CfsMask` at 63 variables
(`sumcheck.rs:223–224`, `:266`), which corresponds to a domain of `2^63`
entries. The masking machinery is the one part of this construction that
needs nothing at all.

## 6. The hidden endpoints at width 768

**Nothing here is redesigned.** `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` is
accepted as the design to build, with 19 errata binding and the five rulings
of its disposition (D17). This section says which of its change-list items
C1…C10 the *block* module needs, and what the block adds on top.

**The block's endpoints are the same object at the same size.** Both external
planes are `T · d = 512 × 768 = 393,216` int16 words
(`private_block.rs:377`, `:312`), which is exactly the plane the endpoints
draft costed at the 125M shape: three `d`-blocks of `2^17`, **not a power of
two**, so `SeamSpec::new` refuses it outright (`private_seam.rs:64–72`) and a
mechanical widening of the single-slice form would bind only the first block
(finding P14, `..._DISPOSITION.md` §1.1).

**Which change-list items the block needs.**

| item | what it is | does the block need it? |
|---|---|---|
| **C1** | pass the prover's `t_rows` in instead of reading it from the witness | **No.** That is a `zk.rs` feed-forward-path item; the block's shape comes from its own layout. |
| **C2** | replace the fixed `MAX_WIRE_BYTES` with a statement-derived exact length plus an absolute ceiling evaluated before any allocation, with checked arithmetic | **Yes, in the block's own wire.** `wire.rs:25` is a 4 MiB constant and the 125M receipt is ~38.7 MiB (§7); `encoded_len` (`wire.rs:31–36`) already derives the exact length from the layout, so this is: raise/derive the bound, keep the exact-equality check primary, and evaluate the ceiling before allocating. |
| **C3** | derive the witness plane lengths and the endpoint plane shape from the statement | **Yes**, for the new profile only. |
| **C4** | `SeamSpecG`: the plane bound becomes the two real ones (`L + 256 ≤ 512`, `log2 N ≤ 62`, the guard inside `CfsMask`), `MASK_ROWS = 2·claim_sites + 3`, the data region pinned to exactly `nb_d · tdb` | **Yes, verbatim.** This is what replaces `MAX_LOG_LEN = 12`. |
| **C5** | a **new** `SeamSpecG` carrying the enclosing parameters and its own digest domain, beside the frozen `SeamSpec` | **Yes, and it is the one that matters most here**, because §2.2 moves the block to `log_cols 14 / inv_rate 4` and the frozen `SeamSpec::params()` is `8 / 8 / 256`. Under D17/R-2 the four constants, `params()`, `digest()` and `check_ntt` stay byte-identical; the block gets a new spec beside them. |
| **C6** | the `mu`-batched multi-block seam, **unconditional at every width** | **Yes** — this is the soundness item and R-1 admits no width exemption. It replaces `protocol.rs:194–196`'s `(0..2)/(2..3)/(3..4)` row shape and `argument.rs:449`'s `log: 9, mask_row: 2` (trap T-5). Its four binding conditions travel: `mu` is `nb_d` fresh draws taken where `tau` is drawn and **not** refused on zero; the data region is exactly `nb_d · tdb`; `audit_claims` covers the endpoint claims; `log_n` is per commitment. |
| **C7** | derive the policy shape, the opening bytes, the frame lengths and every receipt shape check from the statement; parameterise `log_n` per commitment | **Yes.** In the block, `A`/`H` and the endpoints would share `log_cols 14`, so the per-commitment `log_n` case is not exercised — which is a reason to keep the parameterisation and a test for it, not a reason to skip it. |
| **C8** | the new entry pair and the new profile tag | **Yes**: a new `PROFILE`, a new absorbed parameter literal, and new `prepare_endpoints` / `prove` / `verify` / `verify_bytes`. |
| **C9** | three new phase lines | **Yes** (cheap, and §7's model needs them to be checkable). |
| **C10** | offer the endpoint commitments to the device | Not needed for a CPU-only form-S block; keep for later. |

**What the block adds on top of C1…C8.**

1. **Two endpoints, not one pair on one commitment.** The block binds `x_in`
   *and* `xres2` (D12 item 2), on two independent hiding commitments
   (`protocol.rs:243–254`, `:402–407`). Everything in C6 therefore happens
   twice, with two independent `mu` vectors drawn at their own slots. The
   seam slots are `SC_IO_IN` and `SC_IO_OUT` (`argument.rs:902–909`), and
   each already has its own reserved pair on `A` and its own endpoint claim;
   what changes is that each claim gains `nb_d = 3` data parts instead of
   one.
2. **The block already has `audit_claims`** (`protocol.rs:89–133`), which is
   what R-3 says the io path is missing. C6's condition 3 is therefore
   *already met inside this module* and only has to be extended to cover the
   three-part endpoint claim — one of the few places where the block module
   is ahead of the feed-forward path.
3. **Under D18 the prover seals the endpoints at proof time.** For the first
   MVP the prover itself is the party that fixes the commitments to `x_in`
   and `xres2` (D18, decided by Victor 2026-09-19). In code that is what
   `prepare_endpoints` (`private_block.rs:375–386`) already does, and the
   owners are consumed by value. Two consequences for this widening: the
   endpoint commitment cost is the prover's cost, counted in §7; and the
   "who fixes the root" scenario that D8/D11 worry about does not yet
   physically arise in this module, exactly as its own header says
   (`private_block.rs:35–39`). **That is not a discharge of D8 or D11** —
   the sealed-handle end state is a recorded todo.
4. **Endpoint geometry at this shape, from the accepted draft**
   (`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §3.3, form 2): plane words 393,216;
   endpoint **data rows 24**, **commitment rows 29**; seam variables
   `17 + 1 = 18`, degree 2, `L = 38` (`38 + 256 = 294 ≤ 512`); one claim
   site, one opening group, one reserved pair per endpoint at every width;
   **endpoint opening 733,184 B each**. The block pays this twice:
   **1.40 MiB of receipt and 58 committed rows.**
5. **`ENDPOINT_ROWS = 7` becomes 29**, and `ENDPOINT_PROX = 4` becomes 26 —
   `protocol.rs:184–185` and the three `part_rows` equalities at `:194–196`
   are the exact sites.

**The soundness cost of the batched form, restated for this module:** one
extra `1/|Fp2| ≈ 2^-128` term per endpoint per block, so `24 · 2^-128 =
2^-123.4` over a 12-block pass — below every other term
(`..._AT_SCALE.md` §3.3). The hiding cost: none identified; the claim's
coefficients on the non-data rows are still exactly `(e, e·U)` on one
reserved pair.

## 7. Memory and time

### 7.1 Bytes resident, one block

The commitment keeps two copies of everything: the **systematic** matrix (the
witness laid out in rows, which the argument reads directly —
`protocol.rs:382` hands `a.data.as_slice()` to the slots) and the **encoded**
matrix (each row expanded by `inv_rate = 4`, which the column openings read).
So committed material costs `rows × 16,384 × 8 B × 5`.

| buffer | bytes | when it is alive |
|---|---:|---|
| witness planes (`Vec<Vec<i64>>`, 88.9M values) | 711 MB | `witness::build` → end of `prove_inner` |
| `A` systematic | 745 MB | commit → end |
| `A` encoded | 2,978 MB | commit → after `A`'s opening |
| `H` systematic | 942 MB | commit → end |
| `H` encoded | 3,767 MB | commit → after `H`'s opening |
| lookup values (`looked`, 99.6M `i64`) | 797 MB | before commit `A` → end of scope |
| two endpoint commitments (29 rows each) | 38 MB | prepare → their openings |
| `M` (50 × 4,096) | 1.6 MB | commit → mask opening |
| **committed material, total** | **8.47 GB = 7.89 GiB** | |
| peak transient: `SC_SZC`'s ~30 tables × `2^22` × 16 B | **2,013 MB = 1.88 GiB** | inside one slot |

[COUNTED, from §2.4's row counts and the module's own allocation sites.]

**Peak resident ≈ 12.0 GB (11.2 GiB)** — committed material plus the witness,
the lookup values and the largest slot's tables, which as the code is written
today are all alive at the same time. Against **15 GB of system memory** that
fits, with about 3 GB of headroom, and against the **8 GB card** it does not
fit at all (the GPU question does not arise for form S anyway: there is no
device path for the attention half).

**1.5 GB of that peak is avoidable and cheap to avoid**, and at the toy shape
it is 2 MB so nobody has had a reason to: the witness planes (711 MB) can be
dropped after `a_data` is filled (`protocol.rs:287`) and `looked` (797 MB)
after the helper columns are written (`:347`); each slot's tables are already
dropped at the end of its slot. Two `drop`s bring the peak to about
**10.5 GB (9.8 GiB)**. §9 makes it step S2, and §8 shows it is what makes a
chain fit.

**Receipt bytes.** Using the module's own `encoded_len` formula
(`wire.rs:28–36`) at `n = 16,384`, `VEC = n + Q = 16,640`, `PATH = 16`:

| part | bytes | arithmetic |
|---|---:|---|
| `A` opening | 21.4 MB | `36 × 16,640 × 16 + 256 × (8 + 5,681×8 + 32 + 512)` |
| `H` opening | 17.5 MB | `10 × 16,640 × 16 + 256 × (8 + 7,186×8 + 32 + 512)` |
| two endpoint openings | 1.47 MB | `2 × 733,184` (§6) |
| `M` opening | 244 KB | `2 × 1,024 × 16 + 256 × (8 + 50×8 + 32 + 384)` |
| 23 slots (scalars, rounds, terminals) | 25 KB | |
| **one block** | **40.6 MB = 38.7 MiB** | |

Against the toy's 2,816,472 B and the private feed-forward's 7,363,039 B per
layer [both MEASURED]. **Twelve blocks: 487 MB (465 MiB).** For scale, the
public 12-layer feed-forward receipt at this shape is 70,758,084 B, so a
complete private 12-block pass is about **6.9×** the public feed-forward
receipt.

### 7.2 Bytes resident, twelve blocks

This depends entirely on the chaining answer and is worked out in §8. The two
ends of the range:

* **All twelve blocks' commitments alive at once** (the naive reading of "one
  transcript end to end"): `12 × 7.89 GiB = 94.7 GiB`. Not possible on any
  machine the project has.
* **One block at a time, opened and dropped before the next is committed:**
  peak stays at §7.1's 10.5–12.0 GB. Possible — but **not available**, because
  D12 forbids opening a commitment twice and the boundary between two blocks
  has to be proved before either side is opened.
* **What D12 actually forces:** two consecutive blocks' `A` commitments alive
  at the same moment. Whether that lands at 9.9 GiB or at 14.9 GiB is decided
  by the transcript order, not by the geometry. §8.

### 7.3 A CPU prove-time model, and why it is weak

**The anchors** [all MEASURED, `ZK60_FSP_MR1_PROGRESS.md` stage 4b, the quiet
box, 12 layers × 512 tokens, `log_cols 14 / inv_rate 4 / Q 256`, 2 threads;
the phases sum to 35.416 s against a measured 35.417 s]:

| phase | measured, 12 layers | per layer | derived rate |
|---|---:|---:|---|
| commit `A` (585 rows/layer) | 9.637 s | 0.803 s | **1.373 ms per row** |
| commit `W` (288 rows/layer) | 4.575 s | 0.381 s | **1.324 ms per row** (control) |
| helpers + commit `H` (486 rows) | 10.769 s | 0.897 s | helpers ≈ **57.8 ns per `Fp2` helper value** |
| zero-check `F` | 6.865 s | 0.572 s | see below |
| PCS openings | 1.741 s | 0.145 s | **0.135 ms per row** |

The two independent commit rates agree to 4%, which is what makes the commit
term trustworthy: it is a rate, measured twice, on the same box, at the same
parameters, on the same shape.

**The scaling rule.** Commit and opening cost scale with **rows** (both the
NTT and the column hashing are `rows × encoded columns`); helper cost scales
with **helper values**; sumcheck cost scales with **table-points**, the sum
over slots of `tables_s × 2^{n_s}`, because every table is materialised once
and then folded (total fold work is another `2 × 2^n` per table).

| term | quantity at 125M | rate | model |
|---|---:|---|---:|
| commit `A` + `H` + endpoints + `M` | 12,987 row-equivalents | 1.35 ms/row | **17.5 s** |
| helpers | 58.0M `Fp2` values | 57.8 ns | **3.4 s** |
| 23 sumchecks | 212.7M table-points | 13.6 ns | **2.9 s** |
| openings | 12,925 rows | 0.135 ms/row | **1.7 s** |
| | | **one block** | **≈ 25.5 s** |
| | | **twelve blocks** | **≈ 5.1 minutes** |

[MODEL. Assumptions: the commit and opening rates carry over unchanged from
the feed-forward prover to this module at the same PCS parameters; the helper
rate is derived by subtracting the modelled commit-`H` time from the measured
"helpers + commit H" phase; the sumcheck rate is derived from the single
`zero-check F` phase **on the assumption that that slot carries about 40
tables over `2^20` points**, which this memo did not verify in `zk.rs`.]

**Why the model is weak, stated plainly.** A cruder check disagrees with it:
the measured feed-forward pass is 35.417 s for 12,852 committed rows, i.e.
**2.76 ms per row all-in**, and one block has 12,925 rows — which gives
**35.6 s**, 40% above the phase model. The difference is entirely in the
non-commit phases, which the phase model may be underestimating. And the
project's own recent experience is worse than that: **three counted speed
estimates on this project were off by three to seven times when they were
finally measured, this week.** So:

* **the honest reading is 25–36 s per block, 5–7 minutes for twelve**, if the
  model's *structure* is right;
* **plan for up to 2–4 minutes per block (25–50 minutes for twelve)** until
  someone measures it;
* the sumcheck term is the one to distrust: it is 11% of the model and it
  rests on one unverified table count. If table *construction* (`table_of`,
  `argument.rs:199–209`, which allocates a full `2^n` `Fp2` vector per table)
  is not already inside the feed-forward's measured zero-check, the term
  could be several times larger. The cheap way to find out is the
  intermediate rung of §9, which runs in seconds.

### 7.4 The Amdahl question: what form E could save here

Form E's entire value is that it keeps the **feed-forward** half on the
existing GPU prover while the attention half runs on the host. So the
question is: what fraction of a form-S block is the feed-forward half?

**Counted, by committed rows:**

| half | `A` data rows | `H` data rows | total | share |
|---|---:|---:|---:|---:|
| attention (norm_a, QKV, RoPE, scores, softmax, PV, `Wo`, residual 1) | 4,213 | 5,730 | 9,943 | **79.4%** |
| feed-forward (norm_m, gate, activation, up, product, down, residual 2) | 1,219 | 1,344 | 2,563 | **20.5%** |
| shared tables | 3 | 8 | 11 | 0.1% |

[COUNTED, by assigning each plane of §2.4 to a half: `Dom::S`, `Dom::Q`,
`Dom::Kv`, `Dom::Ht` and 19 of the 35 `Dom::D` planes to attention;
`Dom::F`, the other 16 `Dom::D` planes, `A_DM`/`A_DSQM` and `A_LIMBM` to the
feed-forward.] **This reproduces, from a completely independent count, the
form-E check's figure that "the attention half is about 80% of the private
material" (`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3, C-10).** By
sumcheck table-points the split is 16.6% / 83.4%, close enough that 20% is
the number to use.

**What form E could therefore save.** The measured private feed-forward at
this exact shape is **4.649 s on the GPU against 35.417 s on the CPU**
[MEASURED], a factor of 7.62. Moving 20.5% of a block's work to a path 7.62×
faster leaves 2.7%, so:

> **Form E's ceiling at the 125M shape is a 17.8% saving on one block —
> before any of its own costs.** [MODEL, from the counted 20.5% share and the
> measured 7.62× GPU factor.]

And it has its own costs, priced by the form-E check at exactly this width:
768 is one of the widths where the block count is not a power of two, so
**the whole `Dom::D` family re-tiles together — 35 `A` planes, 19 helpers, the
public `gamma` vectors (so the public-statement digest moves) and the
zero-check — at about +70 claim sites and +140 rows at three blocks** (R-3,
"costs nothing is withdrawn"). Plus a second masking commitment (16 → 20 base
rows), two seams, a second `mask_open` with its own `θ`, and the transcript
reordering of R-1.

**The plain conclusion.** At this shape form E buys at most a sixth of one
block and costs a second prover, a second masking commitment, two seams, a
re-tiling and a moved public digest. The security owner's working ruling —
grow form S, measure it, and let the measurement decide — is **supported by
this count**. The measurement that would reverse it is named in §10.1
(decision 10): if the attention half ever gets a device path, the ratio
inverts and form E becomes necessary, which is exactly what the form-E
disposition already says about 8B.

## 8. Chaining twelve blocks

**The constraints.** D12 item 1: no commitment is opened more than once
anywhere in a composed block. D12 item 3: hidden intermediates never get a
caller-fixed endpoint commitment shared by two proofs. Today's disposition:
"a private run is one transcript end to end" — separately finished private
proofs cannot be joined through a commitment root, because the upstream
receipt already contains a full opening of that root, so a downstream proof
consuming it is a second opening **and** prior history
(`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3.1, from
`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §2.5). Joining runs needs the sealed
handle of D18's option B, which is a recorded todo.

**Where the boundary plane lives.** Block `k`'s output is plane `A_X2` on its
own commitment `A_k` (`layout.rs:146`); block `k+1`'s input is plane `A_X` on
`A_{k+1}` (`:127`). They are two different planes on two different
commitments holding the same 393,216 numbers. Three ways to tie them, and
only one is allowed:

| | mechanism | verdict |
|---|---|---|
| (i) | one caller-fixed endpoint root shared by both blocks | **Forbidden.** D12 items 1 and 3, and it is exactly the configuration D11 records as broken (two openings of a 7-row endpoint recover all its words). |
| (ii) | block `k` ends at an external endpoint and block `k+1` starts at another, proved equal | **Allowed but wrong shape.** It makes every internal boundary an external endpoint carrying D8/D11 in full — 22 extra roots for a 12-block run — and D17's naming rule is explicit that internal boundaries are hidden intermediates, not endpoints (C-8). |
| (iii) | **a masked equality sumcheck between `A_k` and `A_{k+1}`**, both the prover's own commitments, the seam claim riding each side's single opening | **The one to build.** It satisfies D12 items 1 and 3 by construction, and it is the same object the form-E check attacked: "a seam between two commitments discloses nothing in the small model — predicted 0 before the run, measured joint 0 with parts 0 + 0" (`..._FORM_E_DISPOSITION.md` §1). That is a small linear model, not a privacy acceptance. |

**Openings, under (iii).** Each commitment is opened exactly once. `A_k` gets
its block's own 122 claim sites plus **one** extra claim site for the
boundary seam (with its own reserved pair, R-5 of the endpoints disposition
and the block's own `audit_claims` rule), so `A_k` carries 123 sites and
`A_{k+1}` 123 as well (one for the seam below it, one above it — the first
and last blocks carry one each plus their external endpoint). `H_k` is
untouched by seams. `M_k` is opened once. Total openings for a 12-block run:
12 `A`, 12 `H`, 12 `M`, and **two** external endpoints for the whole run —
`x_in` of block 1 and `xres2` of block 12. That last point is a
**generalisation of D12 item 2** and needs the amendment C-8 names
(§10.2).

**Transcript order, and why the order decides whether it fits.** Under (iii)
`A_k` cannot be opened until the seam that touches it has run, and that seam
cannot run until `A_{k+1}` exists. So `A_k` and `A_{k+1}` are alive at the
same moment, unavoidably. What is *avoidable* is everything else being alive
with them.

*Naive order* — all 12 blocks' arguments, then all the openings:

```
hdr │ [A₁ M₁ βγα₁ H₁ slots₁] … [A₁₂ M₁₂ βγα₁₂ H₁₂ slots₁₂] │ seams │ openings
```
peak = 12 × 7.89 GiB = **94.7 GiB**. Impossible.

*Block-sequential, seam late* — open block `k` after block `k+1`'s `H` is
committed: peak = `A_k` (3.55) + `A_{k+1}` (3.55) + `H_{k+1}` (4.49) +
transients = **14.9 GiB** as the code stands, **13.5 GiB** with step S2's two
`drop`s. Over the box, or within a gigabyte of it — either way, no.

*Block-sequential, seam early* — **the one that fits:**

```
per block k+1:  commit A_{k+1}, commit M_{k+1}
                seam slot (A_k, A_{k+1})        <- A_k still alive
                open A_k, drop A_k
                draw (β,γ,α)_{k+1}, commit H_{k+1}
                block k+1's 23 slots
                open M_{k+1}, open H_{k+1}, drop both
```
Peak = `A_k` (3.55 GiB) + `A_{k+1}` (3.55) at the seam; after `A_k` is
dropped, `A_{k+1}` (3.55) + `H_{k+1}` (4.49) = 8.04 GiB, plus the largest
slot's 1.88 GiB of tables. **Peak ≈ 9.9 GiB with step S2 applied**, 11.3 GiB
without it — fits the 15 GB box with room either way. [COUNTED from §7.1.]

Two conditions on that order, both checkable: the seam's challenges (`τ`, and
the `nb_d` batching coefficients `μ`) must be drawn **after** both `A` roots
are absorbed — they are, by construction — and the LogUp triple
`(β, γ, α)_{k+1}` must still be drawn after `A_{k+1}` and `M_{k+1}` and
before `H_{k+1}`, which the order above preserves. Note that this ordering is
available **because this module writes its own transcript explicitly**
(`protocol.rs:320–378`); the frozen feed-forward prover has no insertion
point, which is what forced ruling R-1 on form E.

**Time and bytes for 12 blocks:** 5–7 minutes modelled, up to 25–50 minutes
on the pessimistic reading (§7.3); **487 MB of receipt**; one transcript.

**So: is a 12-block run under one transcript feasible on this laptop?**
**Yes on memory and yes on time — but only with a deliberate transcript order
that does not exist yet, and behind a seam that has never been built in this
module.** That is two new mechanisms and a decision register amendment on top
of a widening that is itself large. The honest sequencing is therefore:

> **The first deliverable is ONE complete private block of the real 125M
> model**, at the real shape with real weights, measured. The 12-block chain
> is the second deliverable, after the seam exists, after the D12 amendment,
> and after the one-block measurement has replaced §7.3's model with a
> number.

**What a one-block deliverable's public statement would say**, in plain
words, so that nobody over-reads it:

> For the approved 125M model's layer-ℓ weights, the approved calibration and
> the three approved public tables — all public and all inside one
> transcript-bound digest — and for two hiding commitments to a 512 × 768
> plane of integers, this receipt shows that **there exists** an input plane
> matching the first commitment whose complete transformer block output,
> under the fixed integer semantics of `private-block-kernel` (RMSNorm,
> grouped-query attention with RoPE and integer softmax, SiLU feed-forward,
> both residuals), matches the second commitment — and the receipt contains
> no plaintext input, output, activation, histogram, helper sum or claimed
> scalar sum.

and, attached to it, unchanged: *this is not a privacy acceptance*; D8 and
D11 are open for both endpoint roots; under D18 the prover is the party that
fixed those commitments; and one block is not a model — D13 says the hidden
transformer **blocks** are what the first MVP must prove.

## 9. The ordered change list

**The standing condition, from D17: everything is additive.** The toy profile
`hashline-zk-mr1/private-block-t32-poc/1` stays **byte-frozen** — its
2,816,472-byte receipt, its 46 tests and its `schedule_digest` do not move —
and the 125M shape is a **new profile id beside it**. The frozen
`private_seam.rs` constants, `params()`, `digest()` and `check_ntt` are not
edited (D17/R-2); the general path gets a new spec beside them.

**The reference computation, before anything else.** The module's parity
contract is against `private-block-kernel::run_block`
(`private_block/parity.rs:1–20`), and **that crate is pinned to the same toy
shape** (`private-block-kernel/src/lib.rs:42–48`: `T 32, D 16, F 16, H 2,
HKV 1, DH 8`). So the reference does not exist at the new shape either. The
alternatives, and the recommendation:

* **`private-block-kernel`, generalised over a shape struct** —
  *recommended*. It is the declared reference, it owns the refusal **order**
  and the refusal **strings** that parity compares, and it is a small crate
  not on the do-not-touch list.
* `scripts/attention_spec_spike.py` — already a complete integer forward at
  the real 125M shape (`D_MODEL 768, N_HEADS 12, N_KV 4, HEAD_DIM 64,
  T 512`, `:46–54`), checked against the real calibration. **Not a drop-in
  reference**: it uses *floor* requantisation with a non-negative remainder
  (`:23–26`) where the block uses *round to nearest, ties toward +∞*
  (`witness.rs:72–77`). Use it as an independent cross-check on one case,
  with the rounding difference written down, not as the parity oracle.
* `scripts/m125_attn_gate.py` and `results/hashline_attn_cost_125m.json` —
  shape and cost references, not semantics.

**The intermediate rung.** Before the real shape, one small shape that
exercises *every* new mechanism and runs in seconds:

> **T = 64, d = 48, f = 64, 6 query heads of 8 over 3 KV heads (group 2).**

Why these numbers: `d = 48` is **not** a power of two (pads to 64) and
`trailing_zeros(48) = 4`, so the endpoint plane has `nb_d = 3` blocks —
**the same block count as the real 125M shape**, which is what exercises the
multi-block seam that D17 exists for; 6 heads is not a power of two (pads to
8); 3 KV heads is not a power of two (pads to 4) and the group factor is 2,
so grouped-query is real; `Dom::S = 8·64·64 = 2^15` and `Dom::D = 2^12`, so
everything proves in seconds. Every padded domain, every re-tiled claim
point, the GQA map, the pad rule and the three-block endpoint are all live at
a size where a failing test is debuggable.

**The steps.** "SO" = needs a security-owner ruling before it is written.

| # | step | mechanical? | acceptance check that can FAIL |
|---|---|---|---|
| **S1** | Separate the lookup-table size from the row width: a new `U8_LEN = 256`, used at `argument.rs:523`, `:526`, `:534`, `:898` and `protocol.rs:288`, `:293`, `:297`, `:303`, `:308`; `N` keeps only its row-width meaning (T-1) | mechanical | the toy example still produces a **byte-identical 2,816,472-byte receipt** and all 46 `private_` tests pass. Any moved byte is a bug in the change |
| **S2** | Free the three long-lived buffers early: witness planes after `a_data` is filled, `looked` after the helper columns are written (§7.1) | mechanical | toy receipt byte-identical; peak RSS of the toy example does not rise; a debug assertion that the buffers are gone before the first slot |
| **S3** | **SO:** rule on the input class (decision 2), the pad rule (decision 3), the head padding (decision 4) and the softmax remainder form (decision 5) | ruling | — |
| **S4** | Make the layout shape-driven: a `Shape { T, d, f, H, Hkv, dh }` with derived `d_pad`, `H_pad`; `Dom::log()`, `rows_of`, the challenge-vector lengths, `rho(0..k)`, `cf[log − log2(dh)]` and the matmul `log2(outer)` all computed from it (traps T-2, T-8; pins 1, 4, 14, 20, 47, 48, 50) | mechanical, but T-2 is a soundness fix | instantiating the shape-driven layout **with the toy shape** reproduces `213 / 455 / 280 / 384`, `120 / 51` sites, `35 / 9` groups, 34 functionals, `M_ROWS 50` and the per-domain U8 totals `[1024, 19456, 4608, 6656, 3072, 26624]` **exactly**, and the toy profile's receipt is still byte-identical. A shape whose `d_pad ≠ H_pad · d_h` is **refused at construction** |
| **S5** | Generalise `private-block-kernel` over the same shape | mechanical | the existing 1,200-case parity run at the toy shape reproduces **exactly**: 905 accept, 295 refuse, same site, same string, every plane element for element |
| **S6** | Grouped-query attention: `Dom::Kv = (t, kv, i')`, the head index re-indexed with the KV group in the high bits, the `SC_SCORE` and `SC_PV` claim points taking their `kv` coordinates from the query head's challenge (T-3) | **SO-adjacent** — the head layout is a choice | at the rung shape: witness equals the generalised kernel element for element; **a tamper that swaps two KV heads is rejected by the verifier**; a tamper that makes one query head read the wrong KV group is rejected |
| **S7** | The two windows: `NORM_WRHO 29 → 32` (or the narrower input class of decision 2), `WRHO_S 14 → 18` with a third limb on `ρ_s`, `σ_s`, and the matching lookup-coefficient rewrites (§3.3, §3.4; D16 items 1–5) | **SO** (decision 2) | **the norm-range lane's alias tamper tests reject at the new profile** (D16 item 6, non-negotiable); a witness with `ρ` at the window boundary accepts and `ρ` one above refuses; the re-derived premise is written into `layout.rs`'s header comment |
| **S8** | The pad: a public support indicator on every inhomogeneous constraint group (§3.7) | **SO** (decision 3) | at the rung shape, **a prover that writes a nonzero value into a padded position produces a receipt the VERIFIER rejects** — that is the test that catches a missing support factor — and the honest padded proof verifies |
| **S9** | Row geometry: `log_cols 14`, `inv_rate 4`, `NttTables::new(16)`, `PATH 16`, and the derived wire length replacing `MAX_WIRE_BYTES` (C2) | mechanical | the receipt length equals `encoded_len` **exactly**; a frame one byte long and one byte short is refused **before any allocation**; a `MAX_DIM`-boundary case is refused |
| **S10** | The hidden endpoints: C3, C4, C5, C6, C7, C8 of `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md`, the batched multi-block seam unconditional (D17/R-1), `ENDPOINT_ROWS 7 → 29`, `audit_claims` extended to the three-part endpoint claim (§6) | mechanical given the accepted design | at the rung shape (`nb_d = 3`): a tamper in **block 0**, in **block 1** and in the **last block** each **rejected by the verifier** — the block-1 and block-2 cases are the ones today's code would accept; a proof against a different root rejected; a second use of an owner refused; a spec with the wrong data region refused at construction |
| **S11** | The rung end to end: T 64 / d 48 / f 64 / 6 heads of 8 over 3 | — | honest proof verifies **in a fresh process**; **every** existing verifier-side tamper rejects (the 23 in `tamper.rs`, plus S6's, S8's and S10's); `scripts/zk60_private_block_inventory.py` on the grown layout reports **every opening group and both endpoints disclose 0, H's residual exactly the public identity, every host group kernel 3 and leaked 0, every slot within `L + 256 ≤ 512`, and all 22 negative controls firing** — the same verdicts it reports on the toy; `scripts/zk60_native_joint_view.py` on a captured rung receipt reports `Input 0 / Output 0` and `k0 = 0` with every negative control firing |
| **S12** | The 125M shape itself: the new profile id, the new parameter literal, the calibration from `results/m125_int8_calibration.json`, the row totals of §2.4 asserted in `Layout::new` | mechanical | `Layout::new` asserts `A 5,681 / H 7,186 / M 50` and the data totals `5,435 / 7,082`; witness equals the generalised kernel element for element on the real layer-0 weights; honest proof verifies in a fresh process; every tamper rejects; both leak tools report what they report on the toy |
| **S13** | Measure: one block, quiesced box, detached with `setsid nohup … flock /tmp/zk-heavy.lock … .done` | mechanical | the eleven phase lines sum to the total to within 1 ms, as the mr1 lane's attribution did; rows and receipt bytes are **exactly** §2.4's and §7.1's and are load-independent |
| **S14** | **SO:** chaining — the `A_k`↔`A_{k+1}` boundary seam, the transcript order of §8, the D12 amendment (C-8), two blocks before twelve | ruling + build | two blocks under one transcript verify; a tamper in the boundary plane on either side rejects; the joint-view gate on a two-block capture reports 0; peak RSS ≤ 10 GB |

**Steps needing the security owner: S3, S6 (the head layout), S7, S8, S14.**
Everything else is mechanical, and each mechanical step has a check that
fails loudly if it is not.

## 10. Decisions, open obligations, and what I did not check

### 10.1 Decisions for the security owner

**1. Adopt `log_cols 14 / inv_rate 4 / Q 256` for the new profile.**
*Recommend yes.* The toy's `8 / 8` would put 1.6 GB of column data in every
receipt (§2.2), and matching the layer prover gives the private line one set
of PCS parameters instead of two — the same recommendation already accepted
for the endpoints.

**2. Declare a narrower class for the two norm inputs than int16.**
*Recommend yes: pin `x_in` and `xres1` below `2^12` with one extra
`scaled(l1, 16)` lookup each (+2 lookups on `Dom::D`, no new plane).* At
int16 the norm's remainder window needs `NORM_WRHO = 32`, which is the last
value the construction can express, with **0.21 bits** of margin (§3.3); at
`2^12` it needs 27, with 5 bits of margin, and `D` drops to two limbs. The
measured 125M residual is `|x_int| ≲ 83`
(`results/m125_int8_calibration.json`), so `2^12` is 24× headroom. It is a
decision and not a note because a declared class is a **refusal** on any real
input that exceeds it.

**3. Handle the pad with a public support indicator, not a witness fill.**
*Recommend the indicator.* Cost: one public `Fp2` table per padded domain
(`Dom::D` 8 MB, `Dom::S` 67 MB) and degree 4 → 5 on `SC_DZC` and `SC_SZC`,
which stays far inside the CFS budget (§5). Benefit: the pad holds zeros, no
per-constraint derivation is needed, one item of the fill alternative
(`SC_RS`'s host term over padded heads, §3.7) has no clean answer, and the
causal mask already is this device.

**4. Pad `d 768 → 1024` and `12 heads → 16 slots` with the KV group in the
high bits.** *Recommend yes* — it is the public line's own already-measured
choice (1.33× on the two dominant domains), it makes the grouped-query map
free, and it keeps `d_pad = H_pad · d_h` so the `Q` and `D` cubes still
coincide. Add a construction-time assert on that equality.

**5. Widen the softmax remainder with a third byte limb** (+2 planes on
`Dom::S`, +512 committed rows, 8.4 MB systematic / 33.6 MB encoded).
*Recommend yes, now* — simplest first. Record the alternative (prove `ρ_s`,
`σ_s` relative to `Sum` on `Dom::Ht` instead of by absolute limbs) with the
measurement that would justify it: if `Dom::S` turns out to dominate the
measured prove time by more than the counted 63%, revisit.

**6. The first deliverable is ONE complete private block of the real 125M
model, not a 12-block chain.** *Recommend yes.* Twelve blocks need a boundary
seam that does not exist in this module, a transcript order that does not
exist, and an amendment to D12 (§8). One block needs none of those and turns
§7.3's model into a number.

**7. When chaining comes, fix the transcript order now: the boundary seam
runs immediately after the next block's `A` is committed and before its
`H`.** *Recommend recording it as a construction rule.* It is the difference
between a 9.9 GiB peak and a 14.9 GiB one on a 15 GB box (§8), and it is free
to choose now and expensive to retrofit.

**8. Free the witness planes and the lookup-value buffer early.**
*Recommend yes* — 3.3 GB of a 12.0 GB peak, two `drop`s, byte-identical
receipts (§7.1).

**9. Do not change the table set.** *Recommend no change.* The block already
took the lever that mattered — one 256-entry table by byte limbs instead of
the attention construction's two 65,536-entry tables (§4). The remaining
lever (a signed 255-entry table replacing the `sym` idiom, worth about 11
million of the 99.6 million lookups) should be taken **only if** the measured
helper phase exceeds about a quarter of the block's prove time; the model
puts it at 13%.

**10. Do not build form E at this shape.** *Recommend deferring it, which is
what the working ruling says.* Counted ceiling: **17.8%** of one block, before
its own costs, which at width 768 include the whole `Dom::D` family re-tiling
(+70 claim sites, +140 rows), a second masking commitment, two seams and a
moved public digest (§7.4). The measurement that would reverse this: **a
device path for the attention half.** The moment the 80% can go to the GPU,
the 20% has to go with it and form E becomes necessary — exactly what the
form-E disposition says about 8B.

**11. Re-derive the soundness figure before any published number.** The new
profile changes `inv_rate` from 8 to 4 and adds one `2^-128` batching term
per endpoint per block. D15 requires model-scale statements to quote the
whole-proof figure. *Recommend: a short soundness note lands with S12, before
any receipt from the new profile is shown to anyone.*

### 10.2 Open obligations

1. **D8 and D11 are untouched by this memo.** Simulation against
   caller-fixed endpoint roots with prior public history is not established,
   at any shape. Widening the endpoints does not change that, and under D18
   the first MVP has the prover sealing its own endpoints, which is a
   different scenario, not a discharge.
2. **No privacy property is established here.** The block is accepted as an
   **experimental component** only
   (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md`), and every figure in
   this memo is about cost and correctness, not about what is hidden.
3. **The joint-view gate is owed on the grown layout** — steps S11 and S12.
   The tools' verdicts at the toy shape say nothing about the grown one;
   D17/R-3 makes the analogous gate a hard gate on the io path, and the same
   standard applies here.
4. **A written simulator** for the block's transcript is still owed (the
   construction's §7), as is the `fp()` reduction-bias term (D9, accepted as
   stated).
5. **D12 needs an amendment before a multi-block run**: item 2's "exactly two
   external endpoints" must be stated for a **run** rather than a block, and
   internal boundary planes named as hidden intermediates under item 3
   (C-8 of the form-E check).
6. **The 8B norm window is unreachable by the present construction**
   (`wrho = 33 > 32`, §3.3). That is owed whatever else is decided, and it is
   not on the 125M critical path.
7. **The toy profile must stay byte-frozen** through every step (D17). Steps
   S1, S2 and S4 each carry that as their acceptance check.
8. **Who writes this is settled with Codex first** for anything touching
   `private_seam.rs`'s neighbourhood — the endpoints disposition's next-step
   3 says so explicitly, and the same applies to the block's endpoint half.

### 10.3 What I did not check

* **I ran nothing.** No build, no test, no prover, no benchmark. Every number
  is counted from source or modelled from someone else's measurement.
* **The sumcheck rate.** §7.3's 13.6 ns per table-point rests on an assumed
  ~40 tables in the feed-forward's `zero-check F` slot, which I did not
  verify in `zk.rs`. It is 11% of the model and the most likely place for the
  model to be wrong by a multiple.
* **`A_GROUPS` and `H_GROUPS` at the new shape.** I kept 35 and 9 for the
  receipt arithmetic. The opening-group count is a first-occurrence grouping
  over `(tail point, column offset, length)` (`protocol.rs:158–168`) and
  **will** change when the domain logs change; it must be recounted by the
  implementation and asserted. The receipt figure moves by about 0.3 MB per
  group.
* **The soundness figure at `inv_rate 4`** (decision 11) — not re-derived.
* **The calibration.** I used the recorded study's existence and its
  accumulator maxima; I did not derive the 125M shift values, and the
  saturated shifts in §3.2 are bounds, not proposals.
* **`zk.rs`'s layer layout in detail**, beyond the mask machinery
  (`:352–470`) and the two constants of pin 60; the feed-forward prover's own
  row formation is quoted from the mr1 ledger, not re-derived.
* **The GPU path.** Form S is host-only by construction and there is no
  device path for the attention half; I did not look at what one would cost.
* **`private_attention/*` beyond its constant block.** It is a frozen,
  accepted component and nothing here proposes touching it.
* **`priv_table`'s broadcast** (`argument.rs:191–195`) at padded coordinates:
  the "broadcast over the variables the plane does not depend on" step is
  correct at the toy shape; I did not convince myself it is still correct
  when a plane's real extent is smaller than its padded cube. **That is a
  specific thing for the independent checker to attack**, because it is
  exactly the shape of bug that a padded domain introduces silently.
* **The wire codec's bounded-decode arithmetic** at 38.7 MiB frames
  (`wire.rs:38–60`), beyond noting that C2 applies.
* **Whether 12 layers of the 125M model is the right first target at all**,
  as against one layer: D13 says the hidden transformer *blocks* are what the
  first MVP must prove, and §8 recommends one block first. That sequencing
  is a recommendation, not a ruling.

(draft complete)
