# The complete private block at the 125M shape: the pins, the layout, the arithmetic and what it costs

**Status: REVISED AFTER INDEPENDENT CHECK — accepted as the plan for the next build subject to `ZK60_PRIVATE_BLOCK_125M_LAYOUT_DISPOSITION.md` (security owner, 2026-09-19). Blocking items B-1 … B-4, the corrections and conditions of `ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md` and rulings P-1 … P-8 applied. Paper only: every figure is counted or modelled, none measured. Not a privacy acceptance; a grown layout owes the joint-view gate again from the start. Drafted by a delegated Opus agent.**

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
   disguise** (plus the seven sites and re-classifications the independent
   check added, §1.5). The worst is that one constant, `N`, means two
   different things in the same code — the width of a committed row *and* the
   size of the 256-entry lookup table (`layout.rs:49` against
   `argument.rs:523`, `:526`, `:534`, `:898` and `protocol.rs:288`, `:293`,
   `:297`, `:303`, `:308` — **nine** sites, not eight, C-3). The row width has
   to change at real scale; the table size must not. Widening `N` without
   splitting the two meanings does not produce a silent unsoundness: four
   sites fail the slot's own table-length check, two of those panic first on a
   256-element array, and the one site that changes meaning quietly
   (`protocol.rs:293`) is caught downstream by the LogUp identity — it is a
   completeness matter. §1.3.
2. **Two integer windows that are exactly full at the toy size overflow at
   width 768**, and one of them lands on the very last value the present
   *coefficient idiom* can express. The norm's remainder window has to go from
   `2^29` to `2^32`; `2^32` is the ceiling of the four-limb `1 << (32 − wrho)`
   idiom (above it `layout.rs:321` is a const-evaluated `u32` subtraction that
   **does not compile** — loud at every stage, C-9), and the honest
   requirement at width 768 with the module's declared int16 input class is
   `2^31.79` — **0.21 bits of margin**. The softmax window has to go from
   `2^14` to `2^18`, which costs two new planes on the largest domain in the
   proof. §3.3, §3.4.
3. **The attention half is about 80% of the block and the feed-forward half
   about 20%** (79.9% / 20.1% of committed rows, `[COUNTED]` §7.4). This
   reproduces, from a completely different calculation, the figure the form-E
   check reached (`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3, C-10). Form
   E's whole value is that it keeps the feed-forward on the GPU — but the
   existing GPU prover proves neither `norm_m` (D12 item 4) nor residual 2, so
   only `Dom::F`'s 1,472 rows (11.8%) actually move and **the most it can save
   at this shape is 10–17% of one block's time** (C-14) — which supports the
   security owner's working ruling: grow form S first.
4. **One block is a heavy run on this laptop; twelve blocks under one
   transcript do not fit as the design stands.** One block is about 7.8 GiB of
   committed material plus a 1.75 GiB peak inside the largest sumcheck:
   **11.00 GiB modelled peak, 9.60 GiB after step S2's two frees**, on a box
   with about 14.2 GiB available and a recorded history of out-of-memory
   failures under concurrent runs. Under P-6 the measurement is therefore a
   detached heavy run under the heavy lock, with a memory ceiling that kills
   the process rather than the machine and peak resident memory recorded as an
   acceptance figure. Chaining needs two consecutive blocks' commitments alive
   at the same time (§8). So the first deliverable is **one** private block of
   the 125M shape on synthetic weights (P-8), and the chaining question is
   reopened with two named cheap fixes (§8, decisions 7 and 8).

**Reading order for a non-cryptographer.** §0, then §7, §8 and §10. §1–§6 are
for whoever writes the code, and the two pieces they build from first are
**§3.7a** (the pad rule, plane by plane) and **§9a** (the development rung).
The revision record at the end says what changed after the independent check
and where.

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
**11 (b) derived**, **11 (c) design decisions in disguise**. The class totals
survive the independent check, but two entries swap places: `argument.rs:626`
is class **(a)** — a prover-side panic, not a weakened statement (C-4) — and
`argument.rs:629`/`:687`'s single `rho(0..4)` literal is class **(c)**,
because it serves three matmuls with two different inner and two different
outer widths and is correct only while `D == F == 16` (M-2). The check adds
seven further sites and re-classifications, listed in §1.5. By file:
`private_block/layout.rs` 20, `private_block/argument.rs` 11,
`private_block/protocol.rs` 8, `private_block/witness.rs` 9,
`private_block.rs` 7, `private_block/wire.rs` 1, `private_seam.rs` 2,
`zk.rs` 2. (`private_attention/*` carries the same pins one generation
earlier — `private_attention/layout.rs:29–36` is the identical constant block
with `N_SLOTS = 18` and `H_GROUPS = 8`; it is a frozen, accepted component and
this memo does not propose touching it.)

### 1.3 The traps: the eleven sites this memo filed as class (c)

These are the ones worth a security owner's attention. The other 49 are in the
table of §1.4. **Ten of the eleven survive the independent check as class
(c); T-2 does not** — it is class (a), a prover panic (C-4) — and its place
in the count is taken by `argument.rs:629`/`:687` (M-2, §1.5), which this
memo had filed as derived.

**T-1. `N` means two different things.** `layout.rs:48–49` defines
`LOG_N = 8`, `N = 1 << LOG_N`. `N` is then used as **the width of a committed
row** (`layout.rs:537–539` `rows_of`, `:563` `a_off.push(row * N)`,
`protocol.rs:69` `part_key`, `:366–371` the zero-sum row) **and** as **the size
of the 256-entry lookup tables** (`argument.rs:523` `table_values_u8`, `:526`
`table_values_exp`, `:534` `table_values_act`, `:898` `SC_ZS`'s all-ones
vector, `protocol.rs:288/293/297/303/308` the three multiplicity histograms).
The row width has to move to 16,384 at real scale (§2.2); the table size must
stay 256. **Nine conflated sites, not eight** (C-3). Four fail loudly if `N`
moves — the slot table-length check at `argument.rs:281–283` rejects the three
`SC_TAB` tables and `SC_ZS`'s all-ones vector, and two of those (`ff.act[i]`
at `:534`, `public.exp[i]` at `:526`) panic first past index 255 — and two
more (`protocol.rs:299`, `:305`, missed pin M-4 of §1.5) turn a graceful
bucket-0 fallback into an **out-of-bounds panic** on a fixed `[i64; 256]` /
`[i16; 256]`. **`protocol.rs:293` is the one that changes meaning quietly**:
`(0..N as i64).contains(v)` is the test "is this lookup value inside the
table", and at `N = 16384` a value of 300 — which is *not* a byte — is counted
into histogram entry 300 instead of the out-of-range bucket 0. That is a
**completeness** matter, not a soundness one (C-3): the witness side then
contributes `1/(α − 300 − g_u8)` with no partner on the table side, so the
value-0 LogUp sum cannot close for generic `α` — which is exactly what the
code's own comment at `:292` says, and it is the same outcome as at
`N = 256`. So the honest framing is: widening `N` without splitting the two
meanings breaks the build, the prover or the proof, **loudly**. It is still a
one-line fix (`const U8_LEN: usize = 256;`) that must happen **before** any
row-width change, not after.

**T-2. `outer.trailing_zeros()` assumes the matmul output width is a power of
two — and it is class (a), a PANIC, not a hole (C-4).** `argument.rs:626`:
`let r_j = tr.challenge_fp2_vec(outer.trailing_zeros() as usize);` with
`outer ∈ {D, KV}`. At `D = 16` this is 4 and correct. At `outer = 768` it is
**8**, not 10 — `768 = 2^8 · 3`. The draft of this memo called that "the same
shape of hole as D17's"; **that is withdrawn.** `eq_table_msb(&r_j)` then has
length 256 while `fold_rows_i8` asserts `w.len() == rows`
(`zkp-core/src/mle.rs:118`), so the prover aborts: `assert_eq!(256, 768)`.
There is no configuration in which a short `r_j` reaches the verifier — either
the weight matrix is stored `768 × cols` and that assertion fires, or it is
stored padded `1024 × cols` and the *first* assertion (`m.len() == rows*cols`)
fires. And the padded case is simply correct: everything else in the module
forces `D` to be the **padded** width anyway (`(0..T * D)` builds the public
gain vectors at `argument.rs:706–707`, and those must be `2^19` long or the
same slot table-length check refuses), and `trailing_zeros(1024) = 10`. The
fix is still the right code to write — carry the padded width and use
`log2(d_pad)` explicitly, with a construction-time refusal if `d_pad` is not a
power of two — but it is **hygiene, turning an assertion deep in a numeric
helper into a named refusal at construction, not a soundness repair**.

**T-3. `KV` is a width, not a head count, and the module has one KV head —
three sites, not two.** `layout.rs:45` `KV = 8` is `HKV · DH` with `HKV = 1`;
`Dom::Kv` is `(t, i')` (`layout.rs:85`) and the score loop is
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
**A third site, missed by this memo's draft (M-1):** `argument.rs:799`,
`let (ct, st) = rope_tables(ctx.public, if q { H } else { 1 });` — that bare
`1` **is** the KV head count. At 125M it must become `HKV = 4`, or the public
RoPE table for `SC_KVZC` has `T · 1 · 64 = 32,768` entries against a `Dom::Kv`
of `2^17` and the slot's table-length check (`argument.rs:281–283`) refuses. A
search-and-replace on the symbol `KV` would not find it.
**And the group is 3, not 4** (C-1): under the high-bit re-indexing the padded
head slots are `h ∈ {3, 7, 11, 15}` — one inside each KV group — not the
contiguous block `[12, 16)`. Every support table on a head axis is therefore
**not** a prefix mask. §3.7a.

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
today. **This is the trap that turned out to hide an unsoundness** (B-1):
switching the constraints off on the pad with a public support indicator, or
filling the pad with values that satisfy them, both leave the two row-sum
slots summing `x²` over the *padded* width, and a prover that writes junk
there chooses the norm's divisor and so the block's whole output. §3.7 states
the finding and §3.7a gives the rule that P-1 imposes instead: **every hidden
plane on a padded domain is PROVED zero off its support**, by an explicit
batched pad-zero term, with exemptions by name only.

**T-5. The endpoint reads exactly two rows.** (Confirmed by the check, with
one comfort: `audit_claims` (`protocol.rs:99–102`) makes a *mechanical*
widening loud rather than silent — a 19-variable endpoint claim would span
rows 0..32 on a 29-row commitment and be refused with "a claim reaches the
proximity pair or leaves the commitment". The soundness requirement, C6's
batched multi-block seam, stands regardless.) `protocol.rs:194–196` requires
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
`zk60-private-norm-range`). The idiom `1 << (32 - NORM_WRHO)` appears at
**four** sites — `layout.rs:321`, `:323`, `:329`, `:331`, the `ρ` and `σ` top
limbs of `norm_a` *and* of `norm_m` (C-6) — and **fails above
`NORM_WRHO = 32`**: `32 - NORM_WRHO` is a `u32` subtraction of two
compile-time constants, so `NORM_WRHO = 33` is rejected by the
deny-by-default `arithmetic_overflow` lint and **the crate does not compile**
(C-9; if it ever escaped const-propagation a debug build panics and a release
build would shift by 63 and produce `i64::MIN` as a lookup coefficient). The
failure is loud at every stage, and the ceiling is **this four-limb idiom's,
not the construction's** — §3.3 and §4 record what a fifth limb buys. §3.3
shows that width 768 with the module's declared int16 input class needs
`NORM_WRHO = 32` with 0.21 bits to spare. This is class (c)
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
is `2^22` `Fp2` values = **67 MB, built twice** (`SC_RS` at `argument.rs:611`
and `SC_SZC` at `:840`) — and **`table_of` then clones each**
(`argument.rs:206`), so **two** 67 MB copies are live inside each of the two
slots, i.e. 134 MB, twice (C-12). Add `exp_deltas` (`protocol.rs:221–229`),
which materialises a third `2^22` cube as `Vec<i64>` (33.6 MB), and
`act_indices` at `2^20` (8.4 MB, M-7): about **+110 MB** on the peak beyond
this memo's original model. Not a correctness pin; it is a memory pin that the
present code makes invisible.

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
(`results/m125_int8_calibration.json`, real checkpoint), not be invented —
**and must be quoted per layer from the recorded file, not from memory**: this
memo's draft misquoted them (C-2, §3.2).

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
| 17 | `layout.rs:516–518` | `A_GROUPS 35`, `H_GROUPS 9`, `N_FUNCTIONALS 34`; **`A_GROUPS` becomes 36 at 125M** (C-7, §3.2 of the check) | (b) |
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
| 40 | `witness.rs:286` | `total ∈ [2^F_E, T·2^F_E]` — scales with `T`; the **lower** bound interacts with the pad rule (M-6): the builder's head loop must stay on the true heads, or a padded head with `Sum = 0` fails the prover's own check (§3.7a) | (a) |
| 41 | `witness.rs:298–308` | `σ_s < 2^WRHO_S`, `q ≤ 2^F_P`, two limbs for `p`, `ρ_s`, `σ_s` | **(c)** → T-6 |
| 42 | `argument.rs:449` | `endpoint()`: `log: 9`, `mask_row: 2` | **(c)** → T-5 |
| 43 | `argument.rs:505` | `causal_mask()` over `H·T·T` | **(c)** → T-10 |
| 44 | `argument.rs:509–520` | `rope_tables` over `T·heads·DH`, `i % HALF` | (a) |
| 45 | `argument.rs:522–535` | `table_values_u8/exp/act` indexed `0..N` | **(c)** → T-1 |
| 46 | `argument.rs:626` | `outer.trailing_zeros()` | **(a)** → T-2 (a prover panic, C-4) |
| 47 | `argument.rs:629`, `:680`, `:687` | `rho(0..4)` and `challenge_fp2_vec(4)` — **one literal for three matmuls' two different inner and two different outer widths**, correct only because `D == F == 16` (M-2) | **(c)** |
| 48 | `argument.rs:545`, `:553`, `:559`, `:599`, `:607`, `:618`, `:642–644`, `:656–658`, `:676`, `:679–680`, `:700–701`, `:754–755`, `:793–794`, `:832–834`, `:877–878`, `:903` | 26 challenge-vector lengths, each equal to a domain log or a `mu` count | (b) |
| 49 | `argument.rs:706–707` | `gamma_a[x % D]`, `gamma_m[x % D]` — the gain broadcast; a public weight vector on the `Dom::D` axis, so B-2 applies to it (zero at every padded width index) | (a), pad-sensitive (§3.7a) |
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

### 1.5 The sites the independent check added

All VERIFIED IN THE CODE by the check (§2.6 and §1 of
`ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md`). Five are sites this table missed;
two are re-classifications of entries it already carries.

| # | site | what it pins | disposition here |
|---|---|---|---|
| M-1 | `argument.rs:799` `if q { H } else { 1 }` | the KV **head count** inside `rope_tables` | new site, class (c), folded into T-3 |
| M-2 | `argument.rs:680` `challenge_fp2_vec(4)`, `:687` `rho(0..4)` | one literal for three matmuls' two inner and two outer widths | re-classification: pin 47 moves (a) → **(c)** |
| M-3 | `argument.rs:505` `causal_mask()` | it is a **token**-support table (`x % T <= (x / T) % T` ignores `h`), so it is 1 on every padded head — it does **not** cover the axis that pads | new reading of pin 43; the head support is a separate table (§3.7a) |
| M-4 | `protocol.rs:299`, `:305` | `(0..N).contains(..)` guards an index into a fixed `[i64; 256]` / `[i16; 256]`: widening `N` turns bucket-0 into an out-of-bounds **panic** | new sites, folded into T-1 |
| M-5 | `protocol.rs:52–62` `logup_sum_claim` | every `H` plane's `log_size` must sit on the **same side of `LOG_N`** | new site, class (c); this is blocking item **B-3**, §4.1 |
| M-6 | `witness.rs:286` `total ∈ [2^{F_E}, T·2^{F_E}]` | the lower bound against a padded head's `Sum = 0` | re-reading of pin 40; a condition of the pad rule (§3.7a) |
| M-7 | `protocol.rs:223` `(0..H * T * T)` in `exp_deltas` | a second full `2^22` cube as `Vec<i64>` (33.6 MB) plus `act_indices` at `2^20` (8.4 MB) | new site, memory pin, folded into T-10 |

Two facts in the module's favour that this memo's draft did not state, both
from the check's grep: there is **no `debug_assert` anywhere** in
`private_block*`/`private_attention*` — every guard is a real `assert!`, a
typed check or a `Result` — and there is **no `as u8` / `as u16` on a
dimension** and no `next_power_of_two`: every domain size is a hand-written
log (`layout.rs:98–106`), which is the whole substance of T-4.

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
| 8 (the toy's) | 347,521 | **712 MB** | ~452,700 | **927 MB** |
| 14 (the layer prover's) | 5,681 | 11.6 MB | **7,120** | 14.6 MB |

[COUNTED: `256 · rows · 8 B`; row counts from §2.5, `H` corrected by C-6. The
`log_cols 8` row is the same plane list laid out 64× narrower; it is an
order-of-magnitude figure and nothing depends on its last digits.] A 1.6 GB
receipt per block is not a receipt. **The rest of this memo assumes
`log_cols = 14`,
`inv_rate = 4`, `Q = 256`** — the layer prover's parameters, which also means
one set of PCS parameters for the whole private line instead of two (the same
recommendation the endpoints draft made and the security owner accepted,
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_DISPOSITION.md` §1.5). Consequences: `PATH`
becomes 16 (`log2(16384·4)`), `NttTables::new(12)` becomes `new(16)`
(`protocol.rs:276`, `:435`), and trap T-1 must be fixed first.

**And the lookup-summation repair must be fixed first too (B-3 / P-3).** At
`LOG_N = 14` the `H` domains straddle the row width — `Tab` 8, `L` 13 below
it; `Kv` 17, `D` 19, `Q` 19, `F` 20, `S` 22 at or above it — so the single
value-0 LogUp sum claim (`protocol.rs:52–62`, one part per `H` plane) has
parts under three different column-weight keys, `check_opening`
(`protocol.rs:161–163`) returns *"claim parts with different column weights"*
on **both** sides and `zkp-core/src/pcs.rs:817` asserts below it. **The
module as designed cannot produce a proof at `log_cols = 14` at all.** The
repair is §4.1's, and it is sequenced before this geometry change (P-3).

One soundness note, not a free change: `inv_rate 8 → 4` halves the code
distance and therefore changes the per-opening soundness figure. D15 says
every model-scale statement quotes the whole-proof figure. The check now
derives it: **2^-105.61 per opening** at `log_cols 14 / inv_rate 4 / Q 256`
against 2^-106.25 at the toy's `8 / 8` (the hiding form's rows are `n + Q`
long, so the rate is 0.2539, not 0.125 — the loss is 0.64 bits, not 21),
**about 2^-101.1 for one block** (four PCS openings at 2^-103.61 union, plus
the dominant LogUp term `N/|F_{p²}| = 2^-101.37` at 103.8M lookups), and
**about 2^-97.5 for a twelve-block pass** [all COUNTED by the check's
`recompute.py` §11; below the 128-bit target, and D15's ruling that every
model-scale statement quotes the whole-proof figure applies]. Decision 11
therefore has an answer; see §10.1.

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
| `L` | 16 packed limb sub-planes of `T` | 4,608 | **16,384** | **14** | 3.56× |
| `D` | (token, width) | 393,216 | 524,288 | 19 | 1.33× |
| `Q` | (token, head, head-dim) | 393,216 | 524,288 | 19 | 1.33× |
| `Kv` | (token, kv-head, head-dim) | 131,072 | 131,072 | 17 | 1.00× |
| `S` | (head, token, token): scores | 3,145,728 | 4,194,304 | 22 | 1.33× |
| `F` | (token, feed-forward) | 1,048,576 | 1,048,576 | 20 | 1.00× |
| `Tab` | the three 256-entry tables | 256 | **16,384** | **14** | 64× |

[COUNTED.] `L` and `Tab` are lifted to the row width by the B-3 / P-3 repair
(§4.1), not by the shape: both are one row either way (`rows_of(13)`,
`rows_of(8)` and `rows_of(14)` are all 1 at `N = 16,384`), so the lift costs
**zero rows**, and it is what makes the single LogUp sum claim instantiable
at all. So **five domains pad because of the shape** (`Ht`, `L`, `D`, `Q`,
`S`) and a sixth, `Tab`, is padded by the repair; `T`, `Kv` and `F` are
exact. Every one of the six is governed by the pad rule of §3.7a. Three
further remarks.

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
* **`L` is the worst-padded domain** (3.56× after the lift) but is also the
  smallest, at one row. Leave it — and note that its pad is not new: the toy
  already leaves seven of sixteen limb sub-planes empty, and the honest
  prover already writes zeros there.
* **The padded head slots are `{3, 7, 11, 15}`** (C-1), one inside each KV
  group, because the group is 3 and the KV index is in the high bits:
  `h = kv·4 + g` with `g ∈ {0,1,2}` real and `g = 3` padded. Anything that
  treats the head pad as the contiguous tail `[12, 16)` is wrong.

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
plane is two rows of the same length (`layout.rs:576–582`). **50 planes**
(51 today): `Dom::S` gains a helper and `Dom::D` loses **two**, because the
`NORM_WRHO = 32` coefficient makes **four** `scaled` lookups redundant, not
two — `ρ` and `σ` of `norm_a` *and* of `norm_m`, `layout.rs:321`, `:323`,
`:329`, `:331` (C-6, §4).

| domain | planes | rows each (×2) | rows total |
|---|---:|---:|---:|
| `L` | 1 | 1 | 2 |
| `D` | **17** | 32 | 1,088 |
| `Q` | 7 | 32 | 448 |
| `Kv` | 6 | 8 | 96 |
| `S` | **9** | 256 | 4,608 |
| `F` | 6 | 64 | 768 |
| `Tab` | 4 | 1 | 8 |
| | | **H data rows** | **7,018** |

**This count is conditional on decision 2** (§10.1). If the security owner
takes the narrower input class, the window no longer reaches 32, the four
`scaled` lookups stay and two class lookups are added: `Dom::D` 40 lookups,
20 helpers, `H` data 7,210, `H` rows **7,318** (C-6). Recompute `H` **after**
that ruling, not before.

**`M` — the mask commitment.** Shape-independent: `2 · N_SLOTS + 4` base rows
of 4,096 encoded positions (`zk.rs:435`, `:373–375`). **50 rows**, exactly as
at the toy, because the slot count does not change. §5.

**Claim sites and mask rows.** Each claim site gets two reserved rows on its
commitment. The site counts move only with the two new `Dom::S` planes and the
lookup changes of §4: `A` sites **120 → 122**, `H` sites **51 → 50**
(`SC_SZC` gains one helper, `SC_DZC` loses two). Mask-pair rows: `A` 244,
`H` 100; plus one proximity pair each. The pad-zero term of §3.7a adds **no
claim site and no row**: every plane it combines is already a site in the
slot that hosts it.

* `A` rows = 5,435 + 244 + 2 = **5,681**
* `H` rows = 7,018 + 100 + 2 = **7,120**
* `M` rows = **50** (shape-independent, `n_base = 2·N_SLOTS + 4` over a fixed
  512 / 4,096 / 256 mask geometry that does not move with `log_cols` —
  verified in the code by the check, §3.1)

[COUNTED; the same arithmetic reproduces the toy's 213 / 455 / 280 / 384 and
the toy's per-domain lookup totals exactly — that reproduction is the check
that these counts are computed the module's way and not a guess.]

**The waste worth knowing about.** 244 + 100 = 344 mask-pair rows are full
16,384-wide rows of fresh randomness = **45.1 MB systematic, 180 MB encoded**
[COUNTED], and many of them serve claims on sub-row planes (the eighteen
`Dom::L` sub-slices use 512 of 16,384 columns each, T-7). That is 2.7% of the
commitment; not worth a redesign, worth knowing before someone is surprised
by it. Those eighteen sub-slices are also what moves the opening-group count:
their column offsets are `limb_off(k) % N = 512k`, nine distinct values at
`N = 16,384` where the toy's `32k mod 256` wraps at `k = 8` and gives eight —
so **`A_GROUPS` is 36 at 125M, not 35** (C-7), one more opened vector
(`VEC × 16 = 266,240 B`) in the receipt.

### 2.5 Totals, against the toy and against the private feed-forward

| | toy block (T32/d16/f16) | **125M complete private block** | private feed-forward at 12×512 |
|---|---:|---:|---:|
| `A` rows | 455 | **5,681** | 585 per layer |
| `H` rows | 384 | **7,120** | 486 per layer |
| `M` rows | 50 | **50** | 16 per layer |
| `W` rows (public weights) | — (weights not committed) | — | 288 per layer |
| row width | 256 | **16,384** | 16,384 |
| `inv_rate` | 8 | **4** | 4 |
| `A` systematic / encoded | 0.93 MB / 7.5 MB | **710 MiB / 2,840 MiB** | 76.7 MB / 307 MB |
| `H` systematic / encoded | 0.79 MB / 6.3 MB | **890 MiB / 3,560 MiB** | 63.7 MB / 255 MB |
| receipt | 2,816,472 B | **40,747,256 B = 38.86 MiB** (§7) | 7,363,039 B per layer |

The toy and the feed-forward columns are facts
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md` §3 for 2,816,472 B;
`ZK60_FSP_MR1_PROGRESS.md` stage 4 for 585/486/16 and 88,356,464 B over 12
layers). The middle column is this memo's count.

**The one-line comparison the security owner asked for.** Per 12 layers, the
private feed-forward is 585 + 486 = 1,071 rows *per layer*, 12,852 rows for
the pass. One complete private *block* at the same shape is 5,681 + 7,120 =
12,801 rows — **for one layer**. A complete private block is therefore
about **twelve times** the committed material of the private feed-forward of
the same layer, and a 12-block pass is about twelve times the whole measured
feed-forward pass. That ratio, not any subtlety, is the cost of hiding the
attention half.

**Where the material actually is.** `Dom::S` — the score/softmax cube — is
3,328 of 5,435 `A` data rows and 4,608 of 7,018 `H` data rows: **64% of the
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
| value mixing (PV) | 512 | `p < 2^10` × int8 | 66,519,552 = 2^25.99 | 2^-23 | none |

[COUNTED; the 768 and 2048 figures agree with the recorded accumulator study
`results/m125_int8_calibration.json` → `accumulators/768 max_abs_acc
12,387,072, signed_bits 25` and `accumulators/2048 max_abs_acc 33,032,192`
(that entry is int8×int8; the int16×int8 form above is the private block's
`down`, which the study does not cover). The PV row quotes the **proved**
bound `p < 2^10` (two limbs with `scaled(A_PL1, 64)`, `layout.rs:361`), not
the honest `p ≤ 2^9`: a premise table must quote what the proof enforces
(C-8).] The toy's figures are 2^18, 2^17, 2^21 and 2^26. **No accumulation
comes near `2^49`, let alone `p`. No new limb plane is forced by any
matmul.** The widening of the matmuls is genuinely mechanical.

What *is* forced is a new **calibration**. Each accumulation is
requantised by a right shift, and at 48× the inner dimension the shifts move:
a saturated worst case would need `SH_QKV ≈ 17` (today 7), `SH_S ≈ 13`
(today 6), `SH_Z ≈ 18` (today 6). Real shifts come from the measured
calibration of the real checkpoint (`results/m125_int8_calibration.json`
records, **for layer 1**, `eX −2, eGate −4, eUp −3, eA −4, eH 0, eZ −1,
eW −9` — the values must be quoted per layer from the recorded file; this
memo's draft misquoted `eGate`, `eA` and `eZ`, C-2 — from
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

**The window is 0.21 bits from the end of the four-limb idiom.** The layout
writes the window coefficient as `1 << (32 − NORM_WRHO)` at **four** sites
(`layout.rs:321`, `:323`, `:329`, `:331` — `ρ` and `σ` of both norms), and
any `NORM_WRHO > 32` **fails to compile** (a const-evaluated `u32`
subtraction; C-9, §1.3 T-6) — W2 of
`ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` §5, and D16 item 4 says so. At
`NORM_WRHO = 32` the coefficient is `1`, so each `scaled` lookup becomes a
duplicate of its own `byte` lookup and is dropped: that is **−4 lookups and
−2 helpers** on `Dom::D` (C-6, §4), not the −2 and −1 this memo's draft
counted. The honest requirement at width 768 with an int16 input is
`2^31.79`; the ceiling is `2^32`; **the margin is a factor 1.155, or 0.208
bits.** For comparison:

| geometry | `Dmax` | `den = 2^{tn+1}·D` | honest `wrho` | expressible? |
|---|---:|---:|---:|---|
| toy `d 16`, int16 | 131,068 | 2^29.00 | 29 | yes, exactly saturated (W1) |
| **125M `d 768`, int16** | **908,065** | **2^31.79** | **32** | **yes, 0.21 bits left** |
| 125M `d 768`, int8 input | 3,519 | 2^23.78 | 24 | yes, 8.2 bits left; `D` needs only 2 limbs |
| 125M `d 768`, `\|x\| < 2^12` | 113,483 | 2^28.79 | **29** | yes, 3.2 bits left; `D` still needs **3** limbs (C-10) |
| 8B `d 4096`, int16 | 2,097,088 | 2^33.00 | 33 | **not with four `ρ`/`σ` limbs**; a fifth limb and a `1 << (40 − wrho)` coefficient reach it with nothing wrapping (C-9) |

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
* **Later.** At 8B the present remainder *idiom* does not reach, and the
  repair is small and known (C-9): **a fifth `ρ`/`σ` byte limb and a
  `1 << (40 − wrho)` coefficient**, four more `Dom::D` planes (+128 rows at
  125M-class geometry). Nothing wraps at 8B with it — `y·D·2^{tn+1} ≤
  127 · 2,097,088 · 4,096 = 2^40.0` and `D² + a1 = 2^42.0`, both far below
  `p` — and D16 item 3's "never more than four limbs" governs the **square**
  relation (`D`, `a1`, `a2`), which is what wraps at five, not `ρ` and `σ`,
  which appear only linearly in `c0`/`c1`. So this is a rewritten
  coefficient and four planes, **not a new construction** (§10.2).

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
| `p` | `≤ 2^{F_P} = 512` honest, **`< 2^10` proved**, two limbs with `scaled(l1, 64)` | unchanged | `2^10` | none (the window is one bit loose today — W7 of the norm lane) |
| `p·Sum + ρ_s` | 2^25 | **2^28.00** (at the proved `p < 2^10`, C-8) | — | none |
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

### 3.7 What the pad must contain, constraint by constraint — and the hole

This is trap T-4 made concrete, and it is the part of the widening a
generator cannot do by itself. At the toy shape no domain is padded, so the
question has never been asked. At 125M, `Dom::D`, `Dom::Q`, `Dom::S` and
`Dom::Ht` carry padded positions (a width index in `[768, 1024)`, or a head
slot in `{3, 7, 11, 15}` — **not** the contiguous block `[12, 16)` this
memo's draft assumed, C-1), and **every constraint that is not homogeneous in
the witness is violated there unless the prover fills the pad deliberately.**

**BLOCKING B-1: both fixes this section originally weighed are unsound.**
The table below is still the right catalogue of which constraints fail on the
pad, and therefore of which constraint groups must carry the support factor.
What it gets wrong is the last column and the conclusion drawn from it. Two
slots are not constraints at all but **claimed sums**: `SC_SS` and `SC_SSM`
(`argument.rs:544–549`, `:552–557`) sum `eq(r_t, t)·x²` and `eq(r_t2, t)·x1²`
over the **full padded** `Dom::D` cube, and `SC_TZC` hosts them with
`ν₀·eq(r_t)·(D² + a1 − C_eps)` (`:591`). As a polynomial identity in `r_t`
that says, for every token row `t`,
`D_t² + a1_t − 1 = Σ_{i=0}^{1023} x[t,i]²` — **over the padded range**. A
constraint can be switched off by an indicator; a sum cannot.

* **Under the public support indicator alone**, `c2` (`x + 32768 − (l0 +
  256·l1)`, `argument.rs:728`) is switched off on the pad, so `A_X`'s padded
  entries are unconstrained field elements: `A_XL0`/`A_XL1` are still bytes
  but no longer tied to `x`. The prover chooses `Σ_i x²` freely and hence
  **`D` anywhere below `2^24`**.
* **Under the deliberate fill**, `c2` is active, so `x_pad ∈ [−32768, 32767]`
  and the prover can add up to `256 · 32767² = 2.75 × 10¹¹` to `ss`. Against
  the real checkpoint's honest `ss ≈ 768 · 83² = 5.3 × 10⁶` (`D = 2,300`)
  that moves `D` to **524,357**, a factor of 228 [RECOMPUTED by the check].

`D` is the divisor of the RMSNorm, so choosing `D` rescales `y` for **every
real column**: the proved statement stops being "this output is the block
applied to this input" and becomes "…under a scale the prover picked". The
input commitment does not save it — at 125M the endpoint plane is the true
393,216 words (§6 item 4), so the seam binds no padded column at all, and
under D18 the prover seals it anyway. **This is D17's hole one generation
later, in a different place**: there a mechanical widening let a prover
commit `(honest block ‖ junk ‖ junk)`; here a mechanical padding lets a
prover write junk into columns 768–1023 because the only relation that reads
them as a sum was assumed to see zeros.

**Ruling P-1 replaces both.** Every hidden plane on a padded domain is
**PROVED** zero off its support by an explicit batched pad-zero term
`(1 − supp)·plane = 0`, over *every* committed plane on that domain and not
only the two the hole was found in; exemptions are by name, with a stated
reason, and an exempted plane is excluded from every summation by the support
indicator. §3.7a is that rule, plane by plane. The support factor on the
inhomogeneous constraint groups and on the host terms stays — it is sound and
necessary there, including on the host terms (multiplying `host = acc` by
`supp` gives `supp·host = supp·acc`, exactly the wanted statement, because
the hosted accumulation is already supported by the zero-padded public
weight) — but it is no longer the *whole* fix, and used alone it points the
wrong way: it *removes* constraints from the pad.

Going through `SC_DZC`'s eleven constraints (`argument.rs:726–738`) and
`SC_SZC`'s five (`:858–862`) at a padded position — the "fill" column is
**WITHDRAWN** by B-1 and is kept only to show what each constraint does on
the pad, i.e. which groups must carry the support factor:

| constraint | at the pad with all-zero planes | fill that satisfies it — WITHDRAWN (B-1) |
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

Three things that table settles, and one it got wrong.

1. **The two claimed sums were mis-disposed.** This memo's draft wrote
   *"the pad has `x = 0` (`argument.rs:548`)"* — but `argument.rs:548` is the
   **honest prover's polynomial, not a constraint**. Nothing in the
   verifier's view forced it. That single clause is B-1.
2. **`SC_RS`'s host term does not vanish on a padded head, and the causal
   mask does not help.** `causal_mask()` keys only on `(t, j)`
   (`argument.rs:505`: `x % T <= (x / T) % T`), so it is **1 on every padded
   head** (M-3): it is a *token*-support table and the axis that pads is the
   head axis. The row-sum claim `Σ_j zsel = 1` would therefore be demanded on
   padded head rows, where the planes are zero. The fix is in §3.7a: `SC_RS`'s
   summand and the matching host term carry the head support.
3. **`witness.rs:286` interacts with it** (M-6): `total ∈ [2^{F_E},
   T·2^{F_E}]` is the prover's own check, and a padded head with `Sum = 0`
   fails it — unless the witness builder's head loop stays on the **true**
   heads, which is the rule §3.7a states.

**Cost of the support factor**, unchanged by B-1 and corrected by C-5: one
public `Fp2` indicator table per padded domain — `Dom::D` 8.4 MB, `Dom::Q`
8.4 MB, `Dom::S` 67.1 MB, `Dom::Ht` 0.13 MB, four domains and not two, plus
the small `Dom::L` and `Dom::Tab` tables the lift needs — and `table_of`
**clones** each one per slot (`argument.rs:206`), so `Dom::D`'s is
materialised in three slots and `Dom::S`'s in two. Degree +1 on every slot
that carries it, which moves `SC_SS`/`SC_SSM` from `L = 62` to 82,
`SC_RS` from 71 to 94, `SC_DZC`/`SC_QZC` from 82 to 102 and `SC_SZC` from 94
to 117 — all far inside the 256 budget (§5).

### 3.7a The pad rule, plane by plane (ruling P-1)

**The rule.** On every padded domain, *every* committed plane is **PROVED**
zero off its support unless it is exempted **by name** in the table below.
The proof is one batched **pad-zero term** per padded domain, added to that
domain's existing zero-check. An exempted plane is named with its reason, and
the summations it must be excluded from by the support indicator are listed
in its row. This replaces the draft's "public support indicator" as *the*
pad fix; the indicator stays, but only as the factor that switches
inhomogeneous constraints and host terms off on the pad — it is the pad-zero
term, not the indicator, that says what the pad contains.

#### The support indicators

One public 0/1 table per padded domain, `1` on the true positions. Index bits
are numbered from the least significant bit of the domain's flat index.

| domain | flat index | support | indicator, as a multilinear polynomial | table size |
|---|---|---|---|---:|
| `D` | `t·1024 + i` (19 bits) | `i < 768` | `supp_D = 1 − b₉·b₈` | 2^19 × 16 B = **8.4 MB** |
| `Q` | `t·1024 + h·64 + i'` (19 bits) | `h mod 4 ≠ 3` | `supp_Q = 1 − b₇·b₆` | 2^19 × 16 B = **8.4 MB** |
| `S` | `h·262144 + t·512 + j` (22 bits) | `h mod 4 ≠ 3` | `supp_S = 1 − b₁₉·b₁₈` | 2^22 × 16 B = **67.1 MB** |
| `Ht` | `h·512 + t` (13 bits) | `h mod 4 ≠ 3` | `supp_Ht = 1 − b₁₀·b₉` | 2^13 × 16 B = **0.13 MB** |
| `L` | `k·512 + t` (14 bits, after the P-3 lift) | `k < 9` | `supp_L = [k < 9]`, a 5-bit prefix predicate, not a product | 2^14 × 16 B = 0.26 MB |
| `Tab` | `i` (14 bits, after the P-3 lift) | `i < 256` | `supp_Tab = Π_{k=8}^{13}(1 − b_k)` | 2^14 × 16 B = 0.26 MB |

Four things to note. **(1)** `supp_D` and `supp_Q` are *different* tables on
cubes of the same size: `D` pads at the top quarter of each token's row,
`Q` pads at one head slot in four, i.e. at `i ∈ [192,256) ∪ [448,512) ∪
[704,768) ∪ [960,1024)`. **(2)** No head indicator is a prefix mask — the
padded slots are `{3, 7, 11, 15}` (C-1). **(3)** `causal_mask()` is **not**
one of these: it keys on `(t, j)` and is 1 on every padded head (M-3), so it
covers the axis that does not pad. **(4)** `table_of` clones each table per
slot (`argument.rs:206`), so `supp_D` is materialised in `SC_SS`, `SC_SSM`
and `SC_DZC`, and `supp_S` in `SC_RS` and `SC_SZC`; the verifier evaluates
each one with `eval_mle_ext` over the whole cube
(`argument.rs:333`), so a 2^22 indicator is verifier work as well as prover
memory.

#### The pad-zero term

For a padded domain `dom` with indicator `supp`, hosting zero-check slot `Z`,
and declared ZERO-rule plane list `p₀ … p_{m−1}`, add to `Z`'s batched
zero-check bracket exactly one term:

```
mu_pad · (1 − supp(x)) · Σ_{j<m} ζ^j · plane_{p_j}(x)
```

* `ζ` is **one** fresh challenge drawn in the slot's challenge block and
  **refused on zero** (`nonzero`, as `nu` already is); `mu_pad` is one more
  entry of the slot's existing `mu` vector.
* **Degree 3** in the slot's table accounting — `eq(τ)` × the public
  `(1 − supp)` × one private plane — which sits *inside* the degree the slot
  already has once it carries the indicator (4 → 5 on `SC_DZC`, `SC_QZC`,
  `SC_SZC`; `SC_LZC` and `SC_TAB` keep degree 4 and 3 and gain nothing).
* **Hosts:** `Dom::D` → `SC_DZC`; `Dom::Q` → `SC_QZC`; `Dom::S` → `SC_SZC`;
  `Dom::Ht` → `SC_SZC` (the head indicator is constant in `j`, so the
  `Dom::S` table serves and `A_MX`/`A_SUM` are already read there as
  broadcast slices); `Dom::L` → `SC_LZC`; `Dom::Tab` → `SC_TAB`.
* **Claim sites: none.** Every plane the term combines is already a claim
  site in its hosting slot (`a_range` covers all of `Dom::D`'s 35, `Dom::Q`'s
  7, `Dom::S`'s 13 and `Dom::F`'s 11; `SC_SZC` already reads `A_MX` and
  `A_SUM`; `SC_LZC` reads both limb planes; `SC_TAB` reads all three
  multiplicity planes and all three table helpers). **Rows: none.** **Planes:
  none.**
* **Slot arithmetic:** the term changes no `L` by itself. With the indicator
  the constraint `L + 256 ≤ 512` (`zk.rs:444`, a hard assert) is worst at
  `SC_SZC`: `L = 117`, `117 + 256 = 373 ≤ 512` (§5).
* **Soundness cost:** one Schwartz–Zippel term per padded domain, at most
  `(m − 1)/|F_{p²}|` for `m` planes. Over the six padded domains that is at
  most `(34 + 6 + 11 + 1 + 1 + 5)/2^128 = 58/2^128 = 2^-122.1` [COUNTED],
  far below every other term of §2.2's figure.
* **Receipt cost:** nothing beyond the degree rise, which lengthens the round
  messages of the six slots that carry the indicator by one `Fp2` each:
  +2,016 B on one block's receipt [COUNTED, §7.1].

What the indicator `supp` gates, and what it must **not** gate: it multiplies
(i) the inhomogeneous constraint groups `c*` of `SC_DZC`, `SC_QZC`, `SC_SZC`,
(ii) every host term in those slots, (iii) the two row-sum summands of
`SC_SS` and `SC_SSM`, and (iv) `SC_RS`'s summand and its hosted `host_rs`.
It must **not** gate the LogUp arm (`helper_sum`, and `SC_SZC`'s exp-pair
term `cx`): those relations are what pin the helper planes, and the helper
planes enter the value-0 sum claim (`protocol.rs:52–62`) **additively over
the full padded domain**. A helper left unpinned on the pad would let a
prover add an arbitrary amount to that sum and break the lookup argument
outright.

#### The table

`ZERO` = covered by the domain's pad-zero term. `EXEMPT` = named here, with
the reason and the summations the indicator must exclude it from. "gated"
means the relation carries `supp` and so says nothing on the pad.

**`Dom::D` — 393,216 true / 524,288 padded. 35 planes, all ZERO.**

| plane | what it is | read on the pad by | rule |
|---|---|---|---|
| `A_X` | `x_in`, int16 | **`SC_SS`'s claimed sum `Σ eq(r_t)·x²` — the B-1 hole**; `SC_DZC` `c0`, `c2`, `c5` (gated); `SC_IO_IN`'s seam, which under C6 binds the true 393,216 words only and asserts nothing at a padded column | ZERO |
| `A_XL0`, `A_XL1` | byte limbs of `x + 32768` | `c2` (gated); two `byte` U8 lookups, which stay active and are satisfied at 0 | ZERO |
| `A_Y` | `norm_a` output, int8 via `sym` | `SC_QMM`/`SC_KMM`/`SC_VMM`'s folded weight sums over the padded inner index — safe only by **B-2**; `c0` (gated); `sym` lookups (`0 ↦ (127, 127)`, both bytes) | ZERO |
| `A_NR0 … A_NR3` (4) | `ρ` limbs of `norm_a` | `c0` (gated); four `byte` lookups (the top limb's `scaled` lookup is dropped at `NORM_WRHO = 32`, C-6) | ZERO |
| `A_NS0 … A_NS3` (4) | `σ` limbs of `norm_a` | `c1` (gated); lookups | ZERO |
| `A_AO` | attention output, int16 | `c3`, `c5`, `host_wo` (all gated) | ZERO |
| `A_AL0`, `A_AL1` | its limbs | `c3` (gated); lookups | ZERO |
| `A_RAL` | `Wo` biased remainder | `host_wo` (gated); `byte` + `scaled(·,2)` | ZERO |
| `A_X1` | `xres1`, int16 | **`SC_SSM`'s claimed sum `Σ eq(r_t2)·x1²` — the second B-1 hole**; `c4`, `c5`, `c6` (gated) | ZERO |
| `A_X1L0`, `A_X1L1` | its limbs | `c4` (gated); lookups | ZERO |
| `A_YM` | `nm` = `norm_m` output, int8 via `sym` | `SC_GMM`/`SC_UMM`'s folded weight sums (B-2); `c6` (gated); `sym` lookups | ZERO |
| `A_MR0 … A_MR3`, `A_MS0 … A_MS3` (8) | `norm_m`'s `ρ`/`σ` limbs | `c6`, `c7` (gated); lookups | ZERO |
| `A_Z16` | feed-forward output, int16 | `c9`, `c10`, `host_dmm` (gated) | ZERO |
| `A_X2` | `xres2`, int16 | `c8`, `c9` (gated); `SC_IO_OUT`'s seam (true plane only, as `A_X`) | ZERO |
| `A_X2L0`, `A_X2L1`, `A_ZL0`, `A_ZL1` (4) | their limbs | `c8`, `c10` (gated); lookups | ZERO |
| `A_RDL` | `down` biased remainder | `host_dmm` (gated); `byte` + `scaled(·,4)` | ZERO |

**`Dom::Q` — 393,216 true / 524,288 padded; the pad is head slots
`{3,7,11,15}`. 7 planes, all ZERO.**

| plane | what it is | read on the pad by | rule |
|---|---|---|---|
| `A_Q8` | `q8`, int8 | `SC_QZC`'s RoPE relation as `src` and as the flipped partner `iflip` — the flip is the top bit of `i'`, so it never leaves the head slot — and `host1` (both gated); `sym` lookups | ZERO |
| `A_RQL` | `q` requant remainder | `host1` (gated); lookups | ZERO |
| `A_QR8` | rotated `q`, int8 | `SC_SCORE`'s inner sum over `i'` at a padded head, whose claimed value is 0 once `A_QR8` is 0 there; the RoPE relation (gated); `sym` lookups | ZERO |
| `A_RQRL` | RoPE remainder | the RoPE relation (gated); lookups | ZERO |
| `A_O8` | per-head attention output, int8 | **`SC_WO`'s folded weight sum over the padded, head-major inner index** — this is the axis where B-2's zero columns sit at `{3,7,11,15}`, *not* at `[768,1024)`; `host2` (gated); `sym` lookups | ZERO |
| `A_RO0`, `A_RO1` | `o` remainder limbs | `host2` (gated); lookups | ZERO |

**`Dom::S` — 3,145,728 true / 4,194,304 padded; the pad is head slots
`{3,7,11,15}`. 13 planes, 12 ZERO and one EXEMPT.**

| plane | what it is | read on the pad by | rule |
|---|---|---|---|
| `A_S8` | score, int8 | `SC_SZC`'s `delta` in `c1` and `host_s` (gated); `sym` lookups | ZERO |
| `A_RSL` | score requant remainder | `host_s` (gated); lookups | ZERO |
| `A_ZSEL` | one-hot row selector | **`SC_RS`'s claimed row sum `Σ_j zsel = 1`**, which on a padded head would demand a one-hot that is not there (M-3); `c0`, `c1` (gated) | ZERO. Excluded from: `SC_RS`'s summand and the hosted `host_rs`, by `supp_Ht` |
| `A_E` | `exp[delta]` | **`SC_RS`'s claimed row sum `Σ_j mask·E = Sum`**; `c2` (gated); **the exp-pair lookup `(delta, E)`, which stays active** | **EXEMPT.** Reason: at the pad `delta = 0` for `j ≤ t` (and 127 above it, where the causal mask is 0), and the table row at `delta = 0` carries `E = exp[0] = 2^{F_E} ≠ 0` (`layout.rs:298–301`) — a zero is not a table row, so the pair lookup would refuse. Filled with `exp[delta]`; that value is fully **pinned** by the pair lookup once `A_MX` and `A_S8` are proved zero, so the exemption adds no freedom. Excluded from: `SC_RS`'s summand and the hosted `host_rs`, by `supp_Ht` |
| `A_P` | softmax probability | `SC_PV`'s sum over `j` at a padded head (0 once `A_P` is 0); `c2`, `c4` (gated) | ZERO |
| `A_PL0`, `A_PL1` | its limbs | `c4` (gated); lookups | ZERO |
| `A_SR0 … A_SR2` (3) | `ρ_s` limbs (three after §3.4) | `c2`, `c3` (gated); lookups | ZERO |
| `A_SG0 … A_SG2` (3) | `σ_s` limbs | `c3` (gated); lookups | ZERO |

**`Dom::Ht` — 6,144 true / 8,192 padded; the pad is head slots
`{3,7,11,15}`. 2 planes, both ZERO.**

| plane | what it is | read on the pad by | rule |
|---|---|---|---|
| `A_MX` | masked row maximum | `SC_SZC`'s `delta` (gated), as a slice broadcast over `j` | ZERO |
| `A_SUM` | masked row sum | `SC_SZC` `c2`, `c3` and `host_rs` (gated by `supp_S`, which is `supp_Ht` broadcast over `j`) | ZERO — **condition (M-6):** the builder's head loop must stay on the true heads, or `witness.rs:286`'s lower bound `total ≥ 2^{F_E}` refuses the prover's own padded row |

**`Dom::L` — 4,608 true / 16,384 after the P-3 lift. 2 planes, both ZERO.**

| plane | what it is | read on the pad by | rule |
|---|---|---|---|
| `A_LIMB`, `A_LIMBM` | the packed byte limbs of `D`, `a1`, `a2` for each norm | nothing reads the pad: `SC_TZC` reads the nine used sub-slices at their fixed offsets, `SC_LZC` is homogeneous, and the two `byte` lookups stay active and are satisfied at 0 | ZERO — already true at the toy, where seven of sixteen sub-planes are empty, so this is the uniform rule of P-1 applied for free (one `mu`, no degree change) |

**`Dom::Tab` — 256 true / 16,384 after the P-3 lift. 3 `A` planes ZERO,
3 table helpers ZERO, `H_U` has no pad.**

| plane | what it is | read on the pad by | rule |
|---|---|---|---|
| `A_MU8`, `A_MEXP`, `A_MACT` | the three multiplicity histograms | `SC_TAB`'s `h·(α − tv) − m` relation, which is satisfied at `(m, h) = (0, 0)` | ZERO. **This is what makes the lift safe:** with the padded multiplicities *proved* zero, the padded table positions are never used and the proved set is exactly the 256 real byte values, whatever the padded `tv` repeats — B-3's stated risk ("a soundness hole created by the fix for a shape bug") is closed by the same rule |
| `H_GU8`, `H_GEXP`, `H_GACT` | the table helpers | `SC_TAB`'s relation, which forces `h = m/(α − tv)` and hence `h = 0` wherever `m = 0` | ZERO |
| `H_U` | the zero-sum masking pair | `SC_ZS`'s all-ones sum | **no pad**: after the lift `H_U`'s length is exactly the row width, and it is not a witness plane but the random zero-sum pair — a pad-zero rule on it would remove masking randomness |

**The helper planes on padded domains — `H_L` (1), `H_D*` (17), `H_Q*` (7),
`H_S*` and `H_SEXP` (9): 34 planes, ALL EXEMPT.**

| plane group | reason for the exemption | excluded from which summations |
|---|---|---|
| every LogUp helper on `L`, `D`, `Q`, `S` | a helper is `1/(α − v)` or a sum of two such, and it is **never zero** for a value in the table; at the pad the value is `0 + g_u8`, so the helper is `1/(α − g_u8) ≠ 0` | **None, and deliberately so.** Its pad entries are pinned by the helper relation, which stays active on the pad, and the pad's lookups are counted into the multiplicity histogram exactly as the toy already counts the empty `Dom::L` sub-planes. The value-0 sum claim then closes term by term. Gating the helper arm off on the pad instead would leave these planes unpinned inside an additive sum claim — the one thing the pad rule must never do |
| `H_SEXP` (the exp-pair helper) | same, and it is the reason `A_E` is exempt | none, as above |

**Planes not classified here:** none. Every committed plane on a padded
domain at the 125M shape appears above; `Dom::T`, `Dom::Kv` and `Dom::F` do
not pad at this shape and their planes carry no pad rule (at the development
rung of §9a, `F` and `Kv` do pad, and the same rule applies to them with
`supp_F` and `supp_Kv`).

#### The prover side, in three conditions

1. **Loop bounds.** Every witness loop runs over the **true** extent and the
   allocation is the **padded** length; `protocol.rs:271` already refuses a
   plane that is not the padded length, so the pad is real committed zeros,
   not uninitialised memory. In particular `rms_norm`'s `ss` sums the true
   width only, and the head loops of the softmax section run over the true
   heads — that is condition M-6 above.
2. **Multiplicity counting.** The histograms count every position of the
   padded lookup domains, as they do today; the pad's lookups are lookups of
   the value 0 and their counts land in bucket 0. The three `Dom::Tab`
   histograms are the exception: they are zero above index 255 (the rule in
   the table).
3. **B-2, the public weights.** Every weight matrix is zero-padded on both
   axes, with a construction-time check that the folded weight vector
   vanishes off the support, and — the part that is easy to get wrong — the
   support is the *destination axis's*: `[0,768)` on a `Dom::D` axis, and the
   head-major `{3,7,11,15}`-excluded set on a `Dom::Q` axis. `Wq`, `Wk`, `Wv`
   read a `Dom::D` input axis and write a `Dom::Q`/`Dom::Kv` output axis;
   `Wo` reads a `Dom::Q` input axis and writes `Dom::D`; `Wg`, `Wu` read
   `Dom::D` and write `Dom::F`; `Wd` reads `Dom::F` and writes `Dom::D`. The
   approved model root commits to the zero-padded, head-permuted matrices
   (P-2).

#### The two acceptance tests (P-1), written so that each can fail

**PZ-1 — a lone nonzero value in a pad is rejected.** At the rung shape
(§9a), in `tamper.rs`'s harness (`expect_rejection(name, catch, edit)`, which
edits the built witness and then proves): write `1` into one padded position
of each of three planes **that no claimed sum reads** — `A_RAL` at a padded
width index, `A_SR0` at a padded head slot, and `A_LIMB` inside an unused
limb sub-plane — one case each. Each case asserts: (a) the **prover still
produces a receipt** (the edit is after `witness::build`, so no prover-side
range check fires; if the prover refuses, the test has passed for the wrong
reason and must be rewritten), and (b) `verify` returns `Err` naming the
slot that hosts that domain's pad-zero term (`slot 14` for `Dom::D`,
`slot 17` for `Dom::S`, `slot 3` for `Dom::L`). **It fails today and it fails
under the indicator alone**, because nothing reads those positions — which
is exactly what makes it a test of the pad-zero term and not of the sums.
It also fails if the indicator table is built as a prefix mask instead of
`{3,7,11,15}` (C-1), because the tampered head slot is then inside the
"support".

**PZ-2 (B-4) — a consistently adjusted pad is rejected.** At the rung, write
nonzero values into `A_X`'s padded columns of one token row **and recompute
that row's `D`, `a1`, `a2`, `y`, `ρ`, `σ` and their limbs from the enlarged
`ss`** — the analogue of `tamper.rs`'s existing `recompute_norm_m_row` /
`shift_norm_m_denominator` helpers, which already do this arithmetic for
`norm_m`. Assert: the prover produces a receipt and **`verify` REJECTS it**.
**Before the fix this receipt verifies** — every constraint, every sum and
every lookup is satisfied, with a divisor the prover chose; that is B-1, and
this is the one test that catches it. After the fix the `Dom::D` pad-zero
term rejects it at `slot 14`. A variant with the pad values inside int16 (the
"fill" branch) and a variant with them arbitrary field elements (the
"indicator alone" branch) are both required, because the two unsound designs
fail differently.

#### Open questions

1. **Table or closed form.** Each width/head indicator's multilinear
   extension is `1 − b·b'`, a product of two of the sumcheck's own variables,
   so both sides could evaluate it without materialising anything — saving
   67.1 MB per `Dom::S` slot, the per-slot clones, and the verifier's
   `eval_mle_ext` over 2^22. That needs a new `Tab` variant (a closed-form
   public factor) and its own degree accounting. Priced here as tables, the
   conservative way; not decided.
2. **Where `Dom::Ht`'s pad-zero term rides.** Hosting it in `SC_SZC` reuses
   `supp_S` and costs nothing; a separate `Dom::Ht`-shaped claim would cost
   the 0.13 MB table of C-5. There is no slot whose cube is `Dom::Ht`, so
   this cannot be settled from the code as it stands; both are priced.
3. **`A_E`'s exemption is a property of the public exp table.** It holds
   because `exp[0] = 2^{F_E} ≠ 0`. A construction-time check that the pad's
   `(delta, E)` pairs are genuine table rows would make the exemption
   mechanical rather than a reasoned one; it is not written here.
4. **A future padded endpoint.** The rule above says nothing about the
   endpoint commitments because at 125M they hold the true plane only. If a
   later profile pads an endpoint plane, the same rule has to extend to it,
   and the seam then has to say which positions it binds.

### 3.8 Summary table of the bounds

| # | quantity | toy | 125M | limit | margin | forced change |
|---|---|---:|---:|---:|---|---|
| 1 | QKV / `Wo` / gate / up accumulation | 2^18 | 2^23.56 | 2^49 | 2^25 | none |
| 2 | down accumulation | 2^26 | 2^32.99 | 2^49 | 2^16 | none |
| 3 | score accumulation | 2^17 | 2^19.98 | 2^49 | 2^29 | none |
| 4 | PV accumulation (at the **proved** `p < 2^10`) | 2^21 | 2^25.99 | 2^49 | 2^23 | none |
| 5 | `a16·u16` | 2^30 | 2^30.00 | 2^49 | 2^19 | none |
| 6 | `D² + a1` | 2^34 | 2^39.58 | `p` | 2^24 | none |
| 7 | `D` limbs | 3 | **3** | 4 (D16 item 3) | 1 | none |
| 8 | `a1`, `a2` limbs | 3 | **3** | 4 | 1 | none |
| 9 | norm remainder window | 2^29 (full) | **2^31.79** | **2^32** (the four-limb `1 << (32 − wrho)` idiom, not the construction — C-9) | **0.21 bits** | `NORM_WRHO 29 → 32`, drop **4** lookups (C-6) |
| 10 | softmax `Sum` | 2^14 (full) | **2^18** | limbs | — | `WRHO_S 14 → 18`, **+2 planes on `Dom::S`** |
| 11 | `p·Sum + ρ_s` | 2^25 | 2^28.00 | 2^49 | 2^21 | none |
| 12 | `delta` | < 256 | **< 256** | 256 | — | none |
| 13 | LogUp multiplicity (never range-checked — O-6) | ≤ 61,440 | ≤ 98,582,528 = 2^26.55 | `p` | 2^37 | none |
| 14 | the pad | does not exist | 5 domains padded by the shape, a 6th by the P-3 lift | — | — | **a proved pad-zero invariant plus the support indicator** (§3.7, §3.7a) |

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
| `D` | **34** (38 today, −4) | 524,288 | 17,825,792 | **17** (19 today) |
| `F` | 9 | 1,048,576 | 9,437,184 | 5 |
| `Q` | 13 | 524,288 | 6,815,744 | 7 |
| `Kv` | 12 | 131,072 | 1,572,864 | 6 |
| `S` | **15** (13 today, +2) | 4,194,304 | 62,914,560 | **8** (7 today) |
| | | | **98,582,528** | **44** |
| `exp` pair | 1 | 4,194,304 | 4,194,304 | 1 (`H_SEXP`) |
| `act` pair | 1 | 1,048,576 | 1,048,576 | 1 (`H_FACT`) |

[COUNTED, the module's own rule `lookups(dom).len() × dom.len()` and
`helpers = ⌈lookups/2⌉`; the same arithmetic reproduces the toy's declared
`[1024, 19456, 4608, 6656, 3072, 26624]` and 61,440 exactly
(`layout.rs:744–746`). Two riders. **(a)** The P-3 lift takes `Dom::L`'s
positions from 8,192 to 16,384 and so adds 16,384 U8 lookups (98,598,912 in
total); it changes no row and moves no soundness figure at two decimals.
**(b)** These counts are conditional on decision 2: under the narrower input
class the four `scaled` lookups stay and two class lookups are added, giving
`Dom::D` 40 lookups, 20 helpers and **101,728,256** U8 lookups (C-6).]

**61,440 → 98,582,528 U8 lookups, a factor of about 1,600.** Four
observations.

1. **Multiplicities cannot wrap, and nothing range-checks them.** The largest
   histogram entry is bounded by the total, `2^26.55`, against a field of
   `2^64`. The module's premise ("The LogUp multiplicities (at most 61,440)
   cannot wrap", `layout.rs:308–309`) is re-derived, with a 2^37 margin. But
   a multiplicity is an **unconstrained field element**: `is_multiplicity`
   excludes the three planes from every lookup list (`layout.rs:218–220`),
   `lookups(Dom::Tab)` is empty, and `SC_TAB` reads them only as the
   numerator of `m/(α − t)`. That is sound at this scale and it is a property
   the new profile's premise text must **state**, not inherit (O-6).
2. **Two lookup-list changes, both consequences of §3:** `Dom::D` loses the
   **four** now-redundant `scaled(ρ_top, 1 << (32 − NORM_WRHO))` lookups when
   `NORM_WRHO` reaches 32 — `ρ` and `σ` of `norm_a` *and* of `norm_m`,
   `layout.rs:321`, `:323`, `:329`, `:331` (C-6) — and `Dom::S` gains two,
   for the third limb of `ρ_s` and `σ_s`. Net: helper planes 51 → **50**, and
   because `Dom::S`'s helpers cost 512 rows each and `Dom::D`'s 64, the swap
   is **+384 `H` rows**.
3. **64% of all lookups are on the score cube.** 62.9M of 98.6M, plus the
   4.2M exp pairs. Every lookup costs one field inverse in the helper
   computation and one `H` element; §7 shows that is where the helper phase's
   time goes.
4. **The module's own integer premise text must be rewritten** for the new
   profile (`layout.rs:281–309`), with the bounds of §3 and §4 — it is part
   of D16 item 5 and it currently states the toy's numbers as facts (O-4).

### 4.1 The lookup-summation repair (BLOCKING B-3, ruling P-3)

**As designed, the construction cannot produce a proof at `log_cols = 14` at
all** — this is not a cost, it is a refusal on the first run. The value-0
LogUp sum claim is one `ZClaim` with **one part per `H` plane**
(`protocol.rs:52–62`), each part carrying `log_size = h_dom(p).log()` and an
empty point. `part_key` (`protocol.rs:67–71`) keys a part by
`(point tail, c0, len)`, which is `([], 0, N)` for `log_size ≥ LOG_N` and
`([], offset % N, 1 << log_size)` below it. At the toy every `H` domain has
`log ≥ LOG_N = 8`, so every part agrees. At 125M with `LOG_N = 14` the `H`
domains are `Tab` 8, `L` 13, `Kv` 17, `D` 19, `Q` 19, `F` 20, `S` 22 — three
different keys — and `check_opening` (`protocol.rs:161–163`) returns *"claim
parts with different column weights"* on the prover **and** the verifier,
with `zkp-core/src/pcs.rs:817` asserting below it.

**The accepted repair (P-3):** lift `Dom::L` and `Dom::Tab` to
`log = LOG_N`. `rows_of(13)`, `rows_of(8)` and `rows_of(14)` are all 1 at
`N = 16,384`, so this costs **zero rows**. Three conditions travel with it:

1. The padded **table** positions must repeat an existing entry —
   `tv[i] = (i mod 256) + g_u8` for `U8`, and the same construction for the
   `exp` and `act` pair tables — so that the proved set is still exactly the
   256 byte values. Get this wrong and the byte range proof admits 16,384
   values: *a soundness hole created by the fix for a shape bug.*
2. The padded **multiplicities** are proved zero by the pad rule (§3.7a),
   which closes that risk independently of condition 1.
3. Splitting the sum claim instead is **not available**: `audit_claims`
   (`protocol.rs:110–124`) permits exactly one pairless sum claim, and only
   as the last claim; a second is refused with "unexpected sum claim".

Consequences to carry: `SC_LZC`'s main rounds go 13 → 14 (`L = 62`),
`SC_TAB`'s and `SC_ZS`'s 8 → 14 (`L = 47` and 32), and `H_U`'s plane becomes
exactly one row wide (§5). With the repair, `H_GROUPS` stays **9** and
`A_GROUPS` is **36** [both RECOMPUTED by the check, slot by slot, its model
validated against the toy's declared 35 / 9 first]. **This step is sequenced
before the row-geometry step** (P-3, step S4 of §9): until it is done, the
row-geometry step's acceptance check cannot even run, because no receipt is
produced at all.

**Should the table set change?** No — not at this shape and not for this
reason. Two levers exist if the helper cost ever needs cutting, both recorded
and neither recommended now: a 16-bit table would halve the limb count on
int16 planes (2 limbs → 1 lookup) but reintroduces the 65,536-entry table the
module deliberately removed, and its multiplicity plane becomes 4 rows rather
than 1; and the `sym` idiom (two lookups per int8 value, `layout.rs:274–276`)
could become one lookup into a dedicated 255-entry signed table, saving
**7,208,960** lookups at 125M (C-15: nine `sym` pairs — 2 on `Dom::D`, 3 on
`Dom::Q`, 3 on `Dom::Kv`, 1 on `Dom::S` — one lookup saved per pair per
position, `2·524,288 + 3·524,288 + 3·131,072 + 1·4,194,304`; this memo's
draft said "about 11 million") at the cost of a fourth table and a fourth
tag. The second is the better one if it is ever needed; §10.1 decision 9
names the measurement that would justify it.

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
| 01 `SS` row sums norm_a | 9 → 19 | 1 | 3 | 32 | 62 | 318 | **82** (B-1) |
| 01m `SS` norm_m | 9 → 19 | 1 | 3 | 32 | 62 | 318 | **82** (B-1) |
| 02 norm squares zero-check | 5 → 9 | 1 | 3 | 20 | 32 | 288 | — |
| 08 limb zero-check | 9 → **14** (P-3 lift) | 1 | 4 | 42 | **62** | 318 | — |
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
| 14 `F` zero-check | 9 → 20 | 1 | 4 | 42 | 86 | 342 | — (`Dom::F` does not pad at 125M) |
| TAB table helpers | 8 → **14** (P-3 lift) | 1 | 3 | 29 | **47** | 303 | — |
| ZS zero-sum row | 8 → **14** (P-3 lift) | 1 | 2 | 20 | **32** | 288 | — |
| IO-in / IO-out | 9 → 19 | 1 | 2 | 22 | 42 | 298 | — |

[COUNTED; this table reproduces line for line under the check's independent
computation, and the `L` values in the last column are the adjudicated ones.]
**The closest slot to the limit is `SC_SZC`, the softmax zero-check, at
`L = 94` of a 256 budget — 37% used, or 46% (`L = 117`, `117 + 256 = 373 ≤
512`) once it carries the support factor.** Nothing is close. The pad-zero
term of §3.7a adds no further degree and no further `L`. The other requested
figures:

* `n_base = 2 · 23 + 4 = **50**` — `M` has **50 rows**, exactly as at the toy,
  because the slot count does not change. `M`'s cost is shape-independent
  (the mask geometry `MASK_LOG_MSG 9` / `MASK_LOG_DOM 12` / `MASK_Q 256` does
  not move with `log_cols`, verified in the code by the check):
  50 rows × 4,096 coset positions × 8 B = **1.6 MB**, and its opening is
  238 KiB (§7).
* **Reserved mask pairs:** one per claim site, 122 on `A` and 50 on `H`
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
| **C2** | replace the fixed `MAX_WIRE_BYTES` with a statement-derived exact length plus an absolute ceiling evaluated before any allocation, with checked arithmetic | **Yes, in the block's own wire.** `wire.rs:25` is a 4 MiB constant and the 125M receipt is 38.86 MiB (§7); `encoded_len` (`wire.rs:31–36`) already derives the exact length from the layout, so this is: raise/derive the bound, keep the exact-equality check primary, and evaluate the ceiling before allocating. |
| **C3** | derive the witness plane lengths and the endpoint plane shape from the statement | **Yes**, for the new profile only. |
| **C4** | `SeamSpecG`: the plane bound becomes the two real ones (`L + 256 ≤ 512`, `log2 N ≤ 62`, the guard inside `CfsMask`), `MASK_ROWS = 2·claim_sites + 3`, the data region pinned to exactly `nb_d · tdb` | **Yes, verbatim.** This is what replaces `MAX_LOG_LEN = 12`. |
| **C5** | a **new** `SeamSpecG` carrying the enclosing parameters and its own digest domain, beside the frozen `SeamSpec` | **Yes, and it is the one that matters most here**, because §2.2 moves the block to `log_cols 14 / inv_rate 4` and the frozen `SeamSpec::params()` is `8 / 8 / 256`. Under D17/R-2 the four constants, `params()`, `digest()` and `check_ntt` stay byte-identical; the block gets a new spec beside them. |
| **C6** | the `mu`-batched multi-block seam, **unconditional at every width** | **Yes** — this is the soundness item and R-1 admits no width exemption. It replaces `protocol.rs:194–196`'s `(0..2)/(2..3)/(3..4)` row shape and `argument.rs:449`'s `log: 9, mask_row: 2` (trap T-5). Its four binding conditions travel: `mu` is `nb_d` fresh draws taken where `tau` is drawn and **not** refused on zero; the data region is exactly `nb_d · tdb`; `audit_claims` covers the endpoint claims; `log_n` is per commitment. **Stated condition (B-1 item 3):** the batched seam is a set of per-`d`-block equalities over the **true** plane, so it asserts nothing at a padded column — the padded columns of `A_X` and `A_X2` are bound by the pad-zero term of §3.7a and by nothing else. That must be written down, not left implicit. |
| **C7** | derive the policy shape, the opening bytes, the frame lengths and every receipt shape check from the statement; parameterise `log_n` per commitment | **Yes.** In the block at 125M, `A`/`H` and the endpoints share `log_cols 14`, so the per-commitment `log_n` case is not exercised there — which is a reason to keep the parameterisation and a test for it, not a reason to skip it. **The development rung of §9a does exercise it** (there `n` does not divide `tdb`, which forces the endpoints to their own `log_n`), and that is the cheapest place to find out whether the parameterisation is real. |
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
| `A` systematic | 745 MB | commit → `drop(a)` after `A`'s opening |
| `A` encoded | 2,978 MB | commit → `drop(a)` |
| `H` systematic | 933 MB | commit → `drop(h)` after `H`'s opening |
| `H` encoded | 3,733 MB | commit → `drop(h)` |
| lookup values (`looked`, 98.6M `i64`) | 789 MB | before commit `A` → end of scope |
| per-commitment extras (pads, salts, leaves, tree) | 39 MB | with the commitment |
| two endpoint commitments (29 rows each, sys + enc) | 38 MB | prepare → their openings |
| `M` (50 × 4,096) | 1.6 MB | commit → mask opening |
| **committed material, total** | **8.43 GB = 7.85 GiB** | |
| peak transient: `SC_SZC`'s 28 tables × `2^22` × 16 B | **1,879 MB = 1.75 GiB** | inside one slot |
| C-12: the cloned `causal_mask` copies and the `exp_deltas` / `act_indices` `Vec<i64>` cubes | **+110 MB** | inside `SC_RS`, `SC_SZC` and the helper phase |

[COUNTED/MODEL, from §2.4's row counts and the check's own trace of every
allocation site in `prove_inner` and the commit path
(`recompute.py` §10). Two things that could have broken the model and did
not: `commit_zk_owned` builds no transposed copy (`hash_columns` reads the
encoded matrix in place), and the sumcheck folds tables in place with
`split_at_mut` + `truncate`, so there is no 1.5× fold peak.]

**Peak resident 11.81 GB = 11.00 GiB** [MODEL] — committed material plus the
witness, the lookup values and the largest slot's tables, which as the code
is written today are all alive at the same moment; about 11.1 GiB with
C-12's +110 MB. The box has 15,762 MB total and about 14,176 MB available
with nothing running. **That fits arithmetically and is wrong operationally**
(O-2): this repository's own record is of out-of-memory failures under
concurrent suite and bench runs, its standing rule caps domains at 2^22 — and
`Dom::S` at 125M *is* exactly 2^22 — and another agent's builds may be
running. Hence P-6: the one-block run is **detached, under
`flock /tmp/zk-heavy.lock`, after step S2, with a memory ceiling that kills
the process rather than the machine, and with peak resident memory recorded
as an acceptance figure beside the wall clock**; it is not run while a GPU
job or a release build is active. Against the **8 GB card** none of this
fits, but the GPU question does not arise for form S: there is no device path
for the attention half.

**1.5 GB of that peak is avoidable and cheap to avoid**, and at the toy shape
it is 2 MB so nobody has had a reason to: the witness planes (711 MB) and
`looked` (789 MB) can both be dropped once the helper columns are written.
**The earliest safe drop is after `protocol.rs:351`, not `:287`** (C-11): the
witness planes are read again at `:289` (`lookup_values`), `:296`
(`exp_deltas`), `:299`, `:302` and `:305`, and `looked` at `:337–347`. Two
`drop`s bring the peak to **10.31 GB (9.60 GiB)**. §9 makes it step S2, and
§8 shows it is what makes a chain fit.

**Receipt bytes.** Using the module's own `encoded_len` formula
(`wire.rs:28–36`) at `n = 16,384`, `VEC = n + Q = 16,640`, `PATH = 16`:

| part | bytes | arithmetic |
|---|---:|---|
| `A` opening | 21,626,880 | `(36 + 1) × 16,640 × 16 + 256 × (8 + 5,681×8 + 32 + 16×32)` |
| `H` opening | 17,385,472 | `(9 + 1) × 16,640 × 16 + 256 × (8 + 7,120×8 + 32 + 16×32)` |
| two endpoint openings | 1,466,368 | `2 × 733,184` (§6) |
| `M` opening | 243,712 | `2 × 1,024 × 16 + 256 × (8 + 50×8 + 32 + 12×32)` |
| 23 slots (scalars, rounds, terminals) | 24,688 | `Σ_s (1 + (main+ext)(deg+1) + terms) × 16` |
| header + three roots | 136 | |
| **one block** | **40,747,256 B = 38.86 MiB** | |

[COUNTED, and each line reproduced digit for digit by the check. The
`groups + 1` term is the opened group vectors plus the proximity vector
(`wire.rs:28–30`). Two adjustments this revision carries, both inside the
slot line and both [COUNTED] here: the P-3 lift adds 752 B (`SC_LZC` +1
round, `SC_TAB` and `SC_ZS` +6 each) and B-1's support factors add 2,016 B
(one more coefficient per round in the six slots that gain a degree), so the
final figure is **40,750,024 B = 38.86 MiB**. The implementation asserts
`encoded_len` exactly, so the last digits follow from the final slot table,
not from this memo.]

Against the toy's 2,816,472 B and the private feed-forward's 7,363,039 B per
layer [both MEASURED]. **Twelve blocks: 489 MB (466 MiB).** For scale, the
public 12-layer feed-forward receipt at this shape is 70,758,084 B, so a
complete private 12-block pass is about **6.9×** the public feed-forward
receipt.

### 7.2 Bytes resident, twelve blocks

This depends entirely on the chaining answer and is worked out in §8. The two
ends of the range:

* **All twelve blocks' commitments alive at once** (the naive reading of "one
  transcript end to end"): `12 × 7.85 GiB = 94.2 GiB`. Not possible on any
  machine the project has.
* **One block at a time, opened and dropped before the next is committed:**
  peak stays at §7.1's 10.3–11.8 GB. Possible — but **not available**, because
  D12 forbids opening a commitment twice and the boundary between two blocks
  has to be proved before either side is opened.
* **What D12 actually forces:** two consecutive blocks' `A` commitments alive
  at the same moment. Whether that lands at 9.6 GiB or at 14.4 GiB is decided
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
| PCS openings | 1.741 s | 0.145 s | **0.1055 ms per row** (C-13: the phase opens `W` and `M` too, so the divisor is all 16,500 opened rows, not `A + H`) |

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
| commit `A` + `H` + endpoints + `M` | 12,909 row-equivalents | 1.3566 ms/row | **17.5 s** |
| helpers | 57.5M `Fp2` values | 57.8 ns | **3.3 s** |
| 23 sumchecks | **204,276,352** table-points (C-13, counted table by table from `argument.rs`, not 212.7M) | 13.6 ns | **2.8 s** |
| openings | 12,909 rows | 0.1055 ms/row | **1.4 s** |
| | | **one block** | **≈ 25 s** |
| | | **twelve blocks** | **≈ 5 minutes** |

[MODEL. Assumptions: the commit and opening rates carry over unchanged from
the feed-forward prover to this module at the same PCS parameters; the helper
rate is derived by subtracting the modelled commit-`H` time from the measured
"helpers + commit H" phase; the sumcheck rate is derived from the single
`zero-check F` phase **on the assumption that that slot carries about 40
tables over `2^20` points**, which this memo did not verify in `zk.rs`.]

**Why the model is weak, stated plainly.** A cruder check disagrees with it:
the measured feed-forward pass is 35.417 s for 12,852 committed rows, i.e.
**2.756 ms per row all-in**, and one block has 12,801 `A + H` rows — which
gives **35 s**, 40% above the phase model. The difference is entirely in the
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
  development rung of §9a, which runs in seconds.
* one structural reason the phase model may be low, which the independent
  check adds: **the block's sumchecks run on domains up to `2^22` where the
  measured feed-forward's largest is `2^20`**, and `priv_table`
  (`argument.rs:164–197`) rebuilds a full `2^{n_vars}` table for every
  private plane in every slot — 28 of them at `2^22` in `SC_SZC` alone. The
  measured `zero-check F` phase may contain no analogous cost at that scale.

### 7.4 The Amdahl question: what form E could save here

Form E's entire value is that it keeps the **feed-forward** half on the
existing GPU prover while the attention half runs on the host. So the
question is: what fraction of a form-S block is the feed-forward half?

**Counted, by committed rows:**

| half | `A` data rows | `H` data rows | total | share |
|---|---:|---:|---:|---:|
| attention (norm_a, QKV, RoPE, scores, softmax, PV, `Wo`, residual 1) | 4,213 | 5,730 | 9,943 | **79.9%** |
| feed-forward (norm_m, gate, activation, up, product, down, residual 2) | 1,219 | 1,280 | 2,499 | **20.1%** |
| shared tables | 3 | 8 | 11 | 0.1% |

[COUNTED, by assigning each plane of §2.4 to a half: `Dom::S`, `Dom::Q`,
`Dom::Kv`, `Dom::Ht` and 19 of the 35 `Dom::D` planes to attention;
`Dom::F`, the other 16 `Dom::D` planes, `A_DM`/`A_DSQM` and `A_LIMBM` to the
feed-forward.] **This reproduces, from a completely independent count, the
form-E check's figure that "the attention half is about 80% of the private
material" (`ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3, C-10).** By
sumcheck table-points the feed-forward's five slots are 22.0M of 204.3M =
10.8%.

**But 20.1% is the wrong numerator (C-14).** Form E's value is that the
feed-forward half runs on **the existing GPU prover**, and the existing GPU
prover is the `zk.rs` FFN path: gate, activation, up, product, down. It does
**not** prove `norm_m` — D12 item 4 exists precisely because the
feed-forward prover proves no range on its own input — and it does not prove
residual 2. Both stay on the host in form E. The movable material is
therefore `Dom::F`'s 11 `A` planes (704 rows) and 6 helper planes (768
rows) = **1,472 rows = 11.8%**.

**What form E could therefore save.** The measured private feed-forward at
this exact shape is **4.649 s on the GPU against 35.417 s on the CPU**
[MEASURED], a factor of 7.62. Amdahl on the two numerators: `0.201 × (1 −
1/7.62) = 17.4%` on the whole feed-forward half, `0.118 × (1 − 1/7.62) =
10.2%` on the material that can actually move, and 10.8% by table-points.

> **Form E's ceiling at the 125M shape is a 10–17% saving on one block, a
> band and not a point — before any of its own costs.** [MODEL, from the
> counted 11.8% / 20.1% shares and the measured 7.62× GPU factor. This memo's
> draft said 17.8%; that single figure is withdrawn (C-14).]

And it has its own costs, priced by the form-E check at exactly this width:
768 is one of the widths where the block count is not a power of two, so
**the whole `Dom::D` family re-tiles together — 35 `A` planes, 19 helpers, the
public `gamma` vectors (so the public-statement digest moves) and the
zero-check — at about +70 claim sites and +140 rows at three blocks** (R-3,
"costs nothing is withdrawn"). Plus a second masking commitment (16 → 20 base
rows), two seams, a second `mask_open` with its own `θ`, and the transcript
reordering of R-1.

**The plain conclusion.** At this shape form E buys at most a sixth, and
plausibly a tenth, of one block, and costs a second prover, a second masking
commitment, two seams, a re-tiling and a moved public digest. The security
owner's working ruling — grow form S, measure it, and let the measurement
decide — is **strengthened** by this count, not merely supported: the
corrected band is lower and narrower than the draft's single figure. The
measurement that would reverse it is named in §10.1 (decision 10), and the
check sharpens the trigger: **form E becomes necessary the moment `Dom::S`'s
sumcheck (117M table-points, 57% of the block's total) has a device path**,
because at that point the 20% that cannot move becomes the whole critical
path — which is exactly what the form-E disposition already says about 8B.

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
peak = 12 × 7.85 GiB = **94.2 GiB**. Impossible.

*Block-sequential, seam late* — open block `k` after block `k+1`'s `H` is
committed: peak = `A_k` (3.47) + `A_{k+1}` (3.47) + `H_{k+1}` (4.35) +
transients = **14.4 GiB** as the code stands, **13.0 GiB** with step S2's two
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
Peak = `A_k` (3.47 GiB) + `A_{k+1}` (3.47) at the seam; after `A_k` is
dropped, `A_{k+1}` (3.47) + `H_{k+1}` (4.35) = 7.82 GiB, plus the largest
slot's 1.75 GiB of tables. **Peak ≈ 9.6 GiB with step S2 applied**, 11.0 GiB
without it. [COUNTED from §7.1; the check reproduces 9.6 GiB independently.]
It "fits" the 15 GB box only under P-6's conditions — heavy lock held,
nothing else building, a memory ceiling on the process (§7.1, O-2).

Two conditions on that order, both checkable: the seam's challenges (`τ`, and
the `nb_d` batching coefficients `μ`) must be drawn **after** both `A` roots
are absorbed — they are, by construction — and the LogUp triple
`(β, γ, α)_{k+1}` must still be drawn after `A_{k+1}` and `M_{k+1}` and
before `H_{k+1}`, which the order above preserves. Note that this ordering is
available **because this module writes its own transcript explicitly**
(`protocol.rs:320–378`); the frozen feed-forward prover has no insertion
point, which is what forced ruling R-1 on form E.

**Time and bytes for 12 blocks:** 5–7 minutes modelled, up to 25–50 minutes
on the pessimistic reading (§7.3); **489 MB of receipt**; one transcript.

**One thing that order changes and nobody has checked** (O-3): opening `A_k`
in the middle of the run absorbs its 36 group vectors and 256 columns into
the shared transcript **before** block `k+1`'s challenges are drawn. That is
harmless for soundness — it only adds entropy to later challenges — but it is
a **new hiding surface**: the opened vectors of block `k` are public before
block `k+1`'s masks are used, and the construction's §7 joint-view gate has
never been run on a two-block capture. The form-E disposition's "a seam
between two commitments discloses nothing" result is a small linear model,
not a privacy acceptance.

**So: is a 12-block run under one transcript feasible on this laptop?**
**Yes on memory and yes on time — under P-6's heavy-run conditions, only
with a deliberate transcript order that does not exist yet, behind a seam
that has never been built in this module, and with no privacy claim
whatever: the joint-view gate on a two-block capture is a precondition, not a
formality** (O-3). That is two new mechanisms, a decision-register amendment
and an unrun gate on top of a widening that is itself large. The honest
sequencing is therefore:

> **The first deliverable is ONE complete private block of the 125M shape on
> SYNTHETIC weights**, measured (P-8). The real checkpoint, the 12-block
> chain and form E are later and separately ruled. The chain waits on the
> seam, on the D12 amendment, and on the one-block measurement having
> replaced §7.3's model with a number.

**What a one-block deliverable's public statement would say**, in plain
words, so that nobody over-reads it:

> For the approved 125M-shaped weights of the deliverable — **synthetic, not
> the real checkpoint** (P-8) — the approved calibration and
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

**The development rung comes before the 125M shape** (P-7), and it is
specified in §9a. This memo's draft proposed `T 64 / d 48 / f 64 / 6 heads of
8 over 3 KV heads`; that is **superseded** — the group there is 2, so the
padded head slots do not interleave as they do at 125M, the token count and
the feed-forward width do not pad, and the column count does not make the
helper domains straddle the row width, so B-3 is not reproduced.

### 9a. The development rung (ruling P-7)

**Every hole the independent check found must be reproducible as a failing
test at this rung before it is fixed.** The 125M run is then a measurement,
not a debugging session.

**Parameters.**

| parameter | rung | why (P-7's requirement it satisfies) |
|---|---|---|
| tokens `T` | **24** → `T_pad` 32 | a token count that pads |
| width `d` | **96** → `d_pad` 128 | a width that pads, and `96 = 2^5·3` gives `nb_d = 3` |
| query heads `H` | **6** → `H_pad` 8 | heads pad; padded slots `{3, 7}` |
| KV heads `H_kv` | **2**, group **3** | the padded slot sits inside each KV group, interleaved exactly as at 125M |
| head dim `d_h` | **16** | `d_pad = H_pad · d_h = 128`, so the `Q`/`D` coincidence holds and its construction-time assert is exercised |
| feed-forward `f` | **192** → `f_pad` 256 | a hidden width that pads — `Dom::F` then pads too, which 125M does not do, so `SC_FZC` also carries an indicator |
| `log_cols` | **10** (`n = 1024`), `inv_rate 4`, `Q 256`, `PATH 12` | the helper domains **straddle**: `Tab` 8 and `L` 9 below, `Kv` 10 at, `D`/`Q` 12 and `S`/`F` 13 above — **three distinct column-weight keys, exactly the 125M pattern**, so B-3's refusal is reproduced |
| endpoints | plane `T·d = 2,304` words, `nb_d = 3`, `tdb = 768`, own `log_n = 8` (`n_e = 256`), 9 data rows, 14 commitment rows | endpoints wider than one block (D17's multi-block seam), **and** `n ∤ tdb` forces the per-commitment `log_n` of C7, which 125M does not exercise |
| calibration | `F_E = 12` (rung-only) | makes `Sum ≤ T·2^{F_E} = 98,304`, so `WRHO_S = 17` needs a **third** `ρ_s`/`σ_s` limb, as at 125M. With the toy's `F_E = 9` the softmax window would not break at `T = 24` and the second integer window would not be reproduced |
| norm window | honest `NORM_WRHO = 31` | `Dmax = isqrt(1 + 96·32767²) = 321,049`, `den = 4096·Dmax = 2^30.29`, so the toy's 29 **refuses** — the first integer window is reproduced, with `D` still on three limbs as at 125M |

**Domains at the rung**, as true/padded (log) [COUNTED]: `T` 24/32 (5),
`Ht` 144/256 (8), `L` 216/1,024 after the lift (10), `D` 2,304/4,096 (12),
`Q` 2,304/4,096 (12), `Kv` 768/1,024 (10, from the token axis — no lift
needed, it already sits at the row width), `S` 3,456/8,192 (13), `F`
4,608/8,192 (13), `Tab` 256/1,024 after the lift (10).
**Every one of the nine domains pads**, so the pad rule of §3.7a is
exercised on `Kv` and `F` as well (their indicators are `supp_Kv` and
`supp_F`); 125M's set of padded domains is a subset of the rung's.

**What the rung reproduces, test by test.** Each row names a test at the
rung, what it asserts, why it fails today, and what makes it pass. "Today"
means the module as it stands, instantiated at the rung shape.

| item | test | asserts | why it fails before the fix | passes when |
|---|---|---|---|---|
| **B-1** (the pad hole) | `PZ-2`, §3.7a | a receipt with nonzero `A_X` pad columns **and** `D`, `a1`, `a2`, `y`, `ρ`, `σ` recomputed consistently is **rejected** | it verifies: every constraint, sum and lookup is satisfied under a divisor the prover chose | the `Dom::D` pad-zero term rejects it at slot 14 |
| **B-1** (coverage) | `PZ-1`, §3.7a | a lone nonzero value in `A_RAL`'s, `A_SR0`'s or `A_LIMB`'s pad is **rejected** | nothing reads those positions, so the receipt verifies | the pad-zero terms of `Dom::D`, `Dom::S`, `Dom::L` reject at slots 14, 17, 3 |
| **B-2** (weights) | `a_weight_nonzero_off_its_support_is_refused_at_construction` | building a statement whose folded weight vector is nonzero at a padded input or output index is refused, by name | there is no such check | the construction-time check of §3.7a exists. A second case: a weight matrix that is **not head-permuted** (its `Wo` input columns in true-head order) is refused |
| **B-3** (the sum claim) | `the_logup_sum_claim_has_one_column_weight_key` | enumerating the sum claim's parts at the rung yields exactly one `part_key` | three keys — `([],0,256)`, `([],0,512)`, `([],0,1024)` — and `check_opening` refuses with *"claim parts with different column weights"* before any byte is produced | `Dom::L` and `Dom::Tab` are lifted to `LOG_N` (§4.1) |
| **B-3** (the repair's own risk) | `the_lifted_u8_table_proves_exactly_256_values` | a witness value of 300 is still rejected after the lift | — (the test guards the fix, not the bug) | padded table entries repeat `i mod 256` **and** padded multiplicities are proved zero |
| **B-4** | = `PZ-2` | see above | see above | see above |
| **`argument.rs:626`** | `a_non_power_of_two_matmul_width_is_refused_at_construction` | constructing at a shape whose matmul width is not a power of two gives a **named refusal**, not a panic | the prover panics inside `fold_rows_i8`'s `assert_eq!(w.len(), rows)` — a test that only asserts "no receipt" passes for the wrong reason, so the test must assert the **refusal string** | the shape-driven layout carries `d_pad` and refuses at construction |
| **M-1** (`rope_tables`' `1`) | `the_kv_rope_table_has_hkv_heads` | `SC_KVZC`'s public RoPE table has `T·H_kv·d_h` entries | it has `T·1·d_h` and the slot's table-length check refuses — loud, at the rung, in one second | the literal becomes `H_kv` |
| **M-2** (`rho(0..4)`) | `each_matmul_draws_its_own_inner_and_outer_widths` | the four matmul families draw inner/outer 7/7 (`SC_QMM`, `SC_WO`), 7/5 (`SC_KMM`, `SC_VMM`), 7/8 (`SC_GMM`, `SC_UMM`) and 8/7 (`SC_DMM`) variables at the rung | one literal `4` everywhere: the slot's own shape check (`coords.len() != p.log`, `argument.rs:265`) or its table-length check refuses | the four numbers come from the shape |
| **M-3** (the causal mask) | `a_padded_head_row_does_not_demand_a_one_hot` | an honest proof at the rung **verifies** with `A_ZSEL` zero on the padded head slots | `SC_RS`'s row sum demands `Σ_j zsel = 1` on padded heads (the mask is 1 there), so the honest prover cannot produce a verifying receipt | `SC_RS`'s summand and `host_rs` carry `supp_Ht` |
| **M-4** (`(0..N).contains`) | `an_out_of_class_value_is_refused_not_panicking` | a witness value of 1,128 gives a **refusal**, not an out-of-bounds panic | at `N = 1024` it indexes a 256-element array | `U8_LEN` is split from `N` (S1) |
| **M-5** | = B-3 | | | |
| **M-6** (`witness.rs:286`) | `the_softmax_denominator_check_runs_on_true_heads_only` | the builder produces a witness at the rung | if the head loop is lifted to `H_pad`, the prover refuses its own padded row with "softmax denominator" | the loop bounds rule of §3.7a |
| **M-7** (`exp_deltas`) | covered by the peak-RSS acceptance of S14 | — | — | — |
| **window 1** (norm) | `the_norm_window_is_exact_at_the_rung` | a `ρ` at the window boundary is accepted and one above is refused, at `NORM_WRHO = 31` | at the toy's 29 the honest prover refuses ("norm quotient/remainder") on ordinary inputs | `NORM_WRHO` comes from the shape and the four `scaled` coefficients move with it |
| **window 2** (softmax) | `the_softmax_window_needs_three_limbs_at_the_rung` | an honest proof exists and a `σ_s` one above `2^17` is refused | at two limbs the honest prover refuses ("softmax quotient/remainder") because `Sum ≤ 98,304 > 2^14` | the third limb and `scaled(l2, 64)` |
| **C-1** (head slots) | inside `PZ-1` | the tampered head slot is `{3}` or `{7}`, not a contiguous tail | a prefix-mask indicator treats slot 3 as supported and accepts the tamper | the indicator is `1 − b·b'` on the two low head bits |
| **D17 seam** | the three-block tamper of step S11 | a tamper in block 0, block 1 and the last block are **each** rejected | a `tdb`-widening accepts blocks 1 and 2 | C6's batched seam |

**The rung's own totals** [COUNTED, with the formulas of §2.4, §4 and §7.1;
`python3` arithmetic, nothing run]:

| quantity | rung |
|---|---:|
| `A` planes / data rows | 83 / **377** |
| `H` planes / data rows | 52 / **470** (the rung keeps the four `scaled` norm lookups, since `NORM_WRHO = 31 < 32`, so `Dom::D` has 38 lookups and 19 helpers) |
| claim sites `A` / `H` | 122 / 52 |
| `A` rows / `H` rows / `M` rows | **623** / **576** / 50 |
| opening groups `A` / `H` | **36** / **9** — the same as 125M, and for the same reason: the nine limb sub-slices sit at `c0 = 32k`, nine distinct keys where the toy's wrap at `k = 8` |
| U8 lookups / exp / act | 419,840 / 8,192 / 8,192 |
| largest `L` | 72 (`SC_SZC` and `SC_FZC`, both with the indicator), `72 + 256 = 328 ≤ 512` |
| `A` + `H` committed material | 46.8 MiB systematic + encoded |
| **receipt** | **4,173,032 B = 3.98 MiB** (`A` 2,142,208 + `H` 1,492,992 + two endpoints 2 × 137,216 + `M` 243,712 + slots 19,552 + 136) |

**The rung is development-grade and is never a deliverable.** Its PCS
parameters give `2^-96.1` per `A`/`H` opening (message 1,280 of 4,096
encoded) and `2^-67.3` per endpoint opening (`n_e = 256`, rate 1/2), against
125M's `2^-105.61`. No receipt from the rung is shown to anyone and no
soundness or privacy statement is made from it; it exists so that a failing
test costs a second instead of half an hour.

**Open questions on the rung.**

1. **`F_E = 12` is a rung-only calibration**, chosen to reproduce the softmax
   window. It is a legitimate choice for a synthetic fixture, but it means
   the rung's exp table is not the 125M one; anything that depends on the
   *values* in that table (E-22's zero-`up` case) must be regenerated for the
   rung rather than copied.
2. **`Dom::Kv` and `Dom::F` pad at the rung and not at 125M**, so the rung
   exercises two pad rules the deliverable does not need (and `SC_FZC`
   carries an indicator there that it does not carry at 125M). That is
   coverage, not divergence — but a `Kv`- or `F`-specific bug found at the
   rung may have no 125M analogue and should not be allowed to hold up the
   125M step.
3. **The rung does not exercise `NttTables::new(16)`**: at `n = 1024`,
   `inv_rate 4`, the encoded length is 4,096 and `new(12)` still serves. The
   NTT table bound is therefore a 125M-only change and needs its own unit
   test at S10.
4. Whether the endpoints' separate `log_n` should be avoided by choosing a
   rung whose `tdb` is a multiple of `n`. It cannot be, at a shape this size,
   without giving up either the padding token count or the three-block
   endpoint; exercising C7's parameterisation is the better trade, but it is
   a choice and it is recorded here as one.

**The steps.** "SO" = needs a security-owner ruling before it is written.
The order below is the one ruled in the disposition: the lookup-summation
repair before the column count (P-3), the buffer frees before any 125M run
(P-6), the rung before 125M (P-7), and **the toy profile's byte-identical
2,816,472-byte receipt asserted at every step, not at the end** (P-8) — the
first steps touch shared constants, so a step that moves a toy byte is a bug
in that step. Old step labels are given in brackets.

| # | step | mechanical? | acceptance check that can FAIL |
|---|---|---|---|
| **S1** [S1] | Separate the lookup-table size from the row width: a new `U8_LEN = 256`, used at `argument.rs:523`, `:526`, `:534`, `:898` and `protocol.rs:288`, `:293`, `:297`, `:299`, `:303`, `:305`, `:308` — **nine sites plus M-4's two guards**; `N` keeps only its row-width meaning (T-1) | mechanical | the toy example still produces a **byte-identical 2,816,472-byte receipt** and all 46 `private_` tests pass (all nine sites are `256` at the toy, so the substitution is value-preserving; any moved byte means a site was touched that is genuinely the row width). Plus M-4's test: an out-of-class witness value gives a refusal, not an out-of-bounds panic |
| **S2** [S2] | Free the two long-lived buffers early — witness planes and `looked`, **both after `protocol.rs:351`, not `:287`** (C-11: the planes are read again at `:289`, `:296`, `:299`, `:302`, `:305`). **This is a prerequisite of any 125M run** (P-6): it is the difference between an 11.0 GiB and a 9.6 GiB peak (§7.1) | mechanical | toy receipt byte-identical; peak RSS of the toy example does not rise; an assertion that both buffers are gone before the first slot; and a test that the helper columns are still correct (a drop at `:287` would break them — the test must fail if the drop is moved too early) |
| **S3** [S3] | **SO:** what is left to rule after the disposition — **decision 2** (the narrower input class) with its two conditions, and the two P-5 conditions on the norm pin. P-1 (the pad rule), P-2 (weight padding), P-3 (the lookup repair), P-4 (geometry), P-6 (the heavy run), P-7 (the rung) and P-8 (scope) are already ruled | ruling | — |
| **S4** [NEW, B-3/P-3] | **The lookup-summation repair**: lift every `H` domain whose log is below `LOG_N` to `LOG_N` — `Dom::L` and `Dom::Tab` at both the rung and 125M — with the padded table values repeating `i mod 256` and the padded multiplicities proved zero (§4.1, §3.7a). **Sequenced before the column count changes** (P-3) | mechanical | at the toy this is a **no-op** (`Tab` is already `LOG_N` and `L` is above it), so the toy receipt is byte-identical; a unit test that enumerates the sum claim's parts at the rung shape and asserts **one** `part_key` — it fails today with three; a unit test that a value of 300 is still refused after the lift (the lifted table must not admit 16,384 values) |
| **S5** [S4] | Make the layout shape-driven: a `Shape { T, d, f, H, Hkv, dh }` with derived `d_pad`, `H_pad`; `Dom::log()`, `rows_of`, the challenge-vector lengths, `rho(0..k)`, `cf[log − log2(dh)]` and **the four distinct matmul inner/outer widths of M-2** all computed from it (traps T-2 — hygiene, not a soundness fix — and T-8; pins 1, 4, 14, 20, 47, 48, 50) | mechanical | instantiating the shape-driven layout **with the toy shape** reproduces `213 / 455 / 280 / 384`, `120 / 51` sites, `35 / 9` groups, 34 functionals, `M_ROWS 50` and the per-domain U8 totals `[1024, 19456, 4608, 6656, 3072, 26624]` **exactly**, and the toy profile's receipt is still byte-identical. A shape whose `d_pad ≠ H_pad · d_h` is **refused at construction**, by name; and a non-power-of-two matmul width gives a **named refusal**, not `fold_rows_i8`'s panic (the test asserts the string) |
| **S6** [S5] | Generalise `private-block-kernel` over the same shape | mechanical | the existing 1,200-case parity run at the toy shape reproduces **exactly**: 905 accept, 295 refuse, same site, same string, every plane element for element; toy receipt byte-identical |
| **S7** [S6] | Grouped-query attention: `Dom::Kv = (t, kv, i')`, the head index re-indexed with the KV group in the high bits, the `SC_SCORE` and `SC_PV` claim points taking their `kv` coordinates from the query head's challenge (T-3), **and `argument.rs:799`'s bare `1` becoming `H_kv`** (M-1) | **SO-adjacent** — the head layout is a choice | at the rung: witness equals the generalised kernel element for element; **a tamper that swaps two KV heads is rejected by the verifier**; a tamper that makes one query head read the wrong KV group is rejected; `SC_KVZC`'s RoPE table has `T·H_kv·d_h` entries (M-1's test); toy receipt byte-identical |
| **S8** [S7] | The two windows: `NORM_WRHO 29 → 32` (or the narrower class of decision 2), `WRHO_S 14 → 18` with a third limb on `ρ_s`, `σ_s`, the **four** matching `1 << (32 − wrho)` coefficient rewrites, and the module's integer premise text rewritten for the new profile (§3.3, §3.4, O-4; D16 items 1–5). **Prerequisite: the norm-range lane `zk60-private-norm-range`, which is pushed and NOT yet in the integration branch** (P-5) — its alias exclusions and its W1…W7 window inventory are what this step is checked against, so it is integrated first | **SO** (decision 2) | **the norm-range lane's alias tamper tests reject at the new profile** (D16 item 6, non-negotiable); at the rung, a witness with `ρ` at the window boundary accepts and one above refuses, and the toy's `NORM_WRHO = 29` **refuses an honest rung witness** before the change; the re-derived premise is in `layout.rs`'s header; toy receipt byte-identical |
| **S9** [S8, rewritten per B-4 and P-1] | **The pad rule of §3.7a**: the six support indicators, the batched pad-zero term in each padded domain's zero-check, the support factor on the constraint groups, the host terms, `SC_SS`/`SC_SSM` and `SC_RS`, the named exemptions (`A_E`, the helpers), the three prover-side conditions, and **B-2's construction-time check that every folded weight vector vanishes off its support on both axes, in the destination axis's index order** | **SO** — ruled by P-1/P-2; the plane table is the specification | at the rung: **`PZ-2`** — a receipt with nonzero `A_X` pad columns and `D`, `a1`, `a2`, `y`, `ρ`, `σ` **adjusted consistently** is REJECTED (it verifies before this step: that is B-1, and this is the one test that catches it), in both the int16-fill and the free-field-element variants; **`PZ-1`** — a lone nonzero value in a pad position that no sum reads (`A_RAL`, `A_SR0` on a padded head slot, `A_LIMB` in an unused sub-plane) is REJECTED, naming the hosting slot; the honest padded proof verifies; B-2's two construction refusals fire; M-3's honest padded-head proof verifies. Toy receipt byte-identical |
| **S10** [S9] | Row geometry: `log_cols 14`, `inv_rate 4`, `NttTables::new(16)`, `PATH 16`, and the derived wire length replacing `MAX_WIRE_BYTES` (C2). **After S4** — before it, no receipt is produced at all | mechanical | the receipt length equals `encoded_len` **exactly**; a frame one byte long and one byte short is refused **before any allocation**; a `MAX_DIM`-boundary case is refused; a unit test of the NTT bound at encoded length 65,536, which the rung does not reach |
| **S11** [S10] | The hidden endpoints: C3, C4, C5, C6, C7, C8 of `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md`, the batched multi-block seam unconditional (D17/R-1), `ENDPOINT_ROWS 7 → 29`, `ENDPOINT_PROX 4 → 26`, `audit_claims` extended to the three-part endpoint claim, and the stated condition that the seam binds the **true** plane only (§6, B-1 item 3) | mechanical given the accepted design | at the rung (`nb_d = 3`): a tamper in **block 0**, in **block 1** and in the **last block** each **rejected by the verifier** — the block-1 and block-2 cases are the ones today's code would accept; a proof against a different root rejected; a second use of an owner refused; a spec with the wrong data region refused at construction; the per-commitment `log_n` path exercised (the rung's endpoints use `log_n = 8` against the block's 10) |
| **S12** [S11] | **The rung end to end**, at the parameters of §9a (`T 24 / d 96 / f 192 / 6 heads of 16 over 2 KV heads / log_cols 10`) | — | honest proof verifies **in a fresh process**; **every** existing verifier-side tamper rejects (the 23 in `tamper.rs`, plus S7's, S9's and S11's); the counted totals of §9a are reproduced exactly by `Layout::new` (`A` 623 / `H` 576 / `M` 50, sites 122 / 52, groups 36 / 9) and the receipt is exactly 4,173,032 B up to the final slot table; `scripts/zk60_private_block_inventory.py` on the grown layout reports **every opening group and both endpoints disclose 0, `H`'s residual exactly the public identity, every host group kernel 3 and leaked 0, every slot within `L + 256 ≤ 512`, and all 22 negative controls firing** — the same verdicts it reports on the toy; `scripts/zk60_native_joint_view.py` on a captured rung receipt reports `Input 0 / Output 0` and `k0 = 0` with every negative control firing |
| **S13** [S12] | The 125M shape itself, **on synthetic weights** (P-8): the new profile id, the new parameter literal, the calibration constants, the row totals of §2.4 asserted in `Layout::new`. The real checkpoint is a later, separately ruled step | mechanical | `Layout::new` asserts `A 5,681 / H 7,120 / M 50`, data totals `5,435 / 7,018`, sites `122 / 50`, groups `36 / 9` — **recomputed after the decision-2 ruling, not before** (C-6: the narrow-class branch is `H` 7,318 rows / 7,210 data / 40 `Dom::D` lookups / 20 helpers); witness equals the generalised kernel element for element on the synthetic weights; honest proof verifies in a fresh process; every tamper rejects; both leak tools report what they report on the toy; toy receipt byte-identical |
| **S14** [S13] | **Measure: one block, as a heavy run** (P-6) — detached, `setsid nohup … flock /tmp/zk-heavy.lock … .done`, **after S2**, under a memory ceiling that kills the process rather than the machine (a `MemoryMax` wrap), not while a GPU job or a release build is running, on a quiesced box | mechanical | the eleven phase lines sum to the total to within 1 ms, as the mr1 lane's attribution did; rows and receipt bytes are **exactly** §2.4's and §7.1's and are load-independent; **peak resident memory is recorded as an acceptance figure beside the wall clock** and is at or below the modelled 9.6 GiB (O-2) |
| **S15** [S14] | **SO:** chaining — the `A_k`↔`A_{k+1}` boundary seam, the transcript order of §8, the D12 amendment (O-5), two blocks before twelve | ruling + build | two blocks under one transcript verify; a tamper in the boundary plane on either side rejects; **the joint-view gate on a two-block capture reports 0** (O-3, a precondition and not a formality); peak RSS ≤ 10 GB, recorded |

**Steps needing the security owner: S3, S7 (the head layout), S8, S9,
S15.** Everything else is mechanical, and each mechanical step has a check
that fails loudly if it is not. **Every step asserts the toy profile's
byte-identical 2,816,472-byte receipt** (P-8).

## 10. Decisions, open obligations, and what I did not check

### 10.1 Decisions for the security owner

**1. Adopt `log_cols 14 / inv_rate 4 / Q 256` for the new profile.**
**Ruled: yes** (P-4), and conditional on the B-3 repair of §4.1. The toy's
`8 / 8` would put 1.6 GB of column data in every receipt (§2.2), and matching
the layer prover gives the private line one set of PCS parameters instead of
two — the same recommendation already accepted for the endpoints. The
soundness cost is now quantified and must be quoted in every status line
that mentions this geometry: **2^-105.61 per opening, about 2^-101.1 for one
block, about 2^-97.5 for a twelve-block pass** (§2.2). Whether a whole-proof
figure near 2^-97 is acceptable is a question the security owner puts to the
project owner with D15's; it is not settled here.

**2. Declare a narrower class for the two norm inputs than int16.**
*Recommend yes in direction — but the draft's arithmetic was wrong and two
conditions attach.* Pinning `x_in` and `xres1` below `2^12` needs
**`wrho = 29`, not 27** — `Dmax = 113,483`, `den = 2^28.792` — giving
**3.2 bits** of margin, not 5, and `D` still needs **three** limbs, not two
(C-10: `wrho 27` would need a class near `2^10`, and two `D` limbs a class
near `2^11`). The real checkpoint's recorded input is `|x_int| ≤ 83`
(`results/m125_int8_calibration.json`, layer 1: `absmax 20.5977` at
`eX = −2`), **49×** inside a `2^12` class. P-5 accepts the pin in principle
on two conditions: **(a)** this corrected arithmetic, and **(b)** the
first-residual stream's range, which has never been measured, is measured on
the real checkpoint before any proof about the real model (O-1: `xres1` is
not in the calibration study) — until then the pin is a property of the
synthetic fixture only. It is a decision and not a note because a declared
class is a **refusal** on any real input that exceeds it. **It is not a
substitute for B-1:** without the pad repair, narrowing the class makes the
pad attack *worse* in relative terms (the forgeable-to-honest `D` ratio goes
from 228× to 28×, still total).

**3. Handle the pad with a PROVED pad-zero invariant, and the support
indicator with it.** **Ruled** (P-1, P-2): the indicator alone is unsound
(B-1) and so is the fill; every hidden plane on a padded domain is proved
zero off its support by a batched pad-zero term, exemptions by name only,
and the public weights are zero off their support as a stated construction
obligation with a construction-time check (B-2). §3.7a is the specification.
Cost: **four** indicator tables and not two (C-5) — `Dom::D` 8.4 MB,
`Dom::Q` 8.4 MB, `Dom::S` 67.1 MB, `Dom::Ht` 0.13 MB, plus the small `L` and
`Tab` tables of the lift — each **cloned per slot** by `table_of`; degree
+1 on the six slots that carry the factor; **no rows, no planes, no claim
sites** for the pad-zero term itself; 2,016 B of receipt; `2^-122.1` of
soundness. The causal mask is *not* an instance of this device: it is a
token-support table and is 1 on every padded head (M-3).

**4. Pad `d 768 → 1024` and `12 heads → 16 slots` with the KV group in the
high bits.** *Recommend yes* — it is the public line's own already-measured
choice (1.33× on the two dominant domains), it makes the grouped-query map
free, and it keeps `d_pad = H_pad · d_h` so the `Q` and `D` cubes still
coincide. Add a construction-time assert on that equality. **With the group
at 3, the padded head slots are `{3, 7, 11, 15}`** — one per KV group, not
the contiguous tail `[12, 16)` (C-1) — and every head-axis support table and
every weight permutation follows that layout.

**5. Widen the softmax remainder with a third byte limb** (+2 planes on
`Dom::S`, +512 committed rows, 8.4 MB systematic / 33.6 MB encoded).
*Recommend yes, now* — simplest first. Record the alternative (prove `ρ_s`,
`σ_s` relative to `Sum` on `Dom::Ht` instead of by absolute limbs) with the
measurement that would justify it: if `Dom::S` turns out to dominate the
measured prove time by more than the counted 64%, revisit.

**6. The first deliverable is ONE complete private block of the 125M shape
on SYNTHETIC weights, not a 12-block chain and not the real checkpoint.**
**Ruled: yes** (P-8). Twelve blocks need a boundary seam that does not exist
in this module, a transcript order that does not exist, an amendment to D12
and an unrun joint-view gate (§8). One block needs none of those and turns
§7.3's model into a number. Consistent with D13, which scopes the first MVP
to the hidden transformer *blocks*: this is a sequencing recommendation
inside that scope, not a narrowing of it.

**7. When chaining comes, fix the transcript order now: the boundary seam
runs immediately after the next block's `A` is committed and before its
`H`.** *Recommend recording it as a construction rule.* It is the difference
between a 9.6 GiB peak and a 14.4 GiB one on a 15 GB box (§8), and it is free
to choose now and expensive to retrofit.

**8. Free the witness planes and the lookup-value buffer early.**
*Recommend yes* — 1.5 GB of an 11.8 GB peak, two `drop`s **after
`protocol.rs:351`** (C-11), byte-identical receipts (§7.1). Under P-6 this
is a **prerequisite** of the 125M run, not an optimisation.

**9. Do not change the table set.** *Recommend no change.* The block already
took the lever that mattered — one 256-entry table by byte limbs instead of
the attention construction's two 65,536-entry tables (§4). The remaining
lever (a signed 255-entry table replacing the `sym` idiom, worth
**7,208,960** of the 98,582,528 lookups, C-15) should be taken **only if**
the measured helper phase exceeds about a quarter of the block's prove time;
the model puts it at 13%.

**10. Do not build form E at this shape.** *Recommend deferring it, which is
what the working ruling says.* Counted ceiling: **10–17%** of one block
(C-14 — the draft's single 17.8% is withdrawn, because the existing GPU
prover proves neither `norm_m` nor residual 2, so only `Dom::F`'s 1,472 rows
move), before its own costs, which at width 768 include the whole `Dom::D`
family re-tiling (+70 claim sites, +140 rows), a second masking commitment,
two seams and a moved public digest (§7.4). The measurement that would
reverse this: **a device path for the attention half** — precisely, the
moment `Dom::S`'s sumcheck (117M table-points, 57% of the block's total) has
one, because then the 20% that cannot move becomes the whole critical path.
Exactly what the form-E disposition says about 8B.

**11. Re-derive the soundness figure before any published number.**
**Now derived** (§2.2, from the check's `recompute.py` §11): `2^-105.61` per
opening at `log_cols 14 / inv_rate 4` (a loss of 0.64 bits against the toy,
not 21, because the hiding rows are `n + Q` long), four PCS openings and one
mask opening per block, the LogUp term `2^-101.37` dominating, **one block
about 2^-101.1** and **a twelve-block pass about 2^-97.5**, plus one
`2^-128` batching term per endpoint per block. D15 requires model-scale
statements to quote the whole-proof figure. *Recommend: a short soundness
note lands with S13, before any receipt from the new profile is shown to
anyone, and every status line that quotes this geometry carries the two
figures.*

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
3. **The joint-view gate is owed on the grown layout** — steps S12 and S13 —
   and **again on a two-block capture** before any chain (O-3, step S15).
   The tools' verdicts at the toy shape say nothing about the grown one;
   D17/R-3 makes the analogous gate a hard gate on the io path, and the same
   standard applies here.
4. **A written simulator** for the block's transcript is still owed (the
   construction's §7), as is the `fp()` reduction-bias term (D9, accepted as
   stated).
5. **D12 needs an amendment before a multi-block run**, and it is a *pending
   ruling to be filed in `ZK60_DECISIONS.md`*, not a note in a memo (O-5):
   item 2's "exactly two external endpoints" must be stated for a **run**
   rather than a block, and internal boundary planes named as hidden
   intermediates under item 3 (C-8 of the form-E check).
6. **The 8B norm window needs a fifth `ρ`/`σ` limb and a rewritten
   coefficient** — four more `Dom::D` planes, +128 rows at 125M-class
   geometry — **not a new construction** (C-9, §3.3). That is owed whatever
   else is decided, and it is not on the 125M critical path.
7. **The toy profile must stay byte-frozen** through every step (D17, P-8).
   **Every** step of §9 carries that as an acceptance check, not only the
   first few: the early steps touch shared constants.
8. **Who writes this is settled with Codex first** for anything touching
   `private_seam.rs`'s neighbourhood — the endpoints disposition's next-step
   3 says so explicitly, and the same applies to the block's endpoint half.
9. **`xres1`'s range has never been measured** on the real checkpoint
   (O-1). Decision 2 cannot be fixed for the real model until it is, and the
   norm pin is until then a property of the synthetic fixture only (P-5).
10. **The one-block run is a heavy run** (O-2, P-6): detached, heavy lock,
    after S2, memory ceiling, peak resident memory recorded as an acceptance
    figure. "Fits with 3 GB of headroom" is true only if nothing else is
    running, on a box with a recorded history of out-of-memory failures.
11. **The module's own integer premise text** (`layout.rs:281–309`,
    including "The LogUp multiplicities (at most 61,440) cannot wrap") must
    be rewritten for the new profile with the bounds of §3 and §4 (O-4,
    D16 item 5).
12. **Multiplicities are never range-checked** — `is_multiplicity` excludes
    the three planes from every lookup list. Sound at 98.6M against a 2^64
    field, but the new profile's premise must **state** it rather than
    inherit it (O-6).
13. **The norm-range lane `zk60-private-norm-range` is pushed and not yet in
    the integration branch** (P-5). Step S8 depends on it.

### 10.3 What I did not check

* **I ran nothing.** No build, no test, no prover, no benchmark. Every number
  is counted from source or modelled from someone else's measurement.
* **The sumcheck rate.** §7.3's 13.6 ns per table-point rests on an assumed
  ~40 tables in the feed-forward's `zero-check F` slot, which I did not
  verify in `zk.rs`. It is 11% of the model and the most likely place for the
  model to be wrong by a multiple.
* **`A_GROUPS` and `H_GROUPS` at the new shape** — **now checked** (C-7):
  **36 and 9**, by the first-occurrence grouping over `(tail point, column
  offset, length)` (`protocol.rs:158–168`), with the model validated against
  the toy's declared 35 / 9 first. The one slot that moves is `SC_TZC`,
  whose nine limb sub-slices stop colliding at `N = 16,384`. The
  implementation must still recount and assert them. The receipt figure
  moves by 266,240 B per group.
* **The soundness figure at `inv_rate 4`** (decision 11) — **now derived**:
  §2.2 and §10.1 decision 11.
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
* **`priv_table`'s broadcast** (`argument.rs:191–195`) at padded
  coordinates — **attacked by the independent check and found correct**:
  `p.log` is always the *padded* log (`a_dom`/`h_dom`), the witness is
  required to be the padded length (`protocol.rs:271`), and the broadcast
  source `x & used < x` is always already final. What is *not* invariant
  next door is `mask_eval`/`build_claim`'s `c0 = p.slices[0].0 % N`, which
  is what moves the opening-group count at `N = 16,384` (C-7).
* **The wire codec's bounded-decode arithmetic** at 38.86 MiB frames
  (`wire.rs:38–60`), beyond noting that C2 applies. The independent check
  did not audit it either.
* **`private-block-kernel`'s generalisation** (step S6) — neither this memo
  nor the check read that crate.
* **Whether 12 layers of the 125M model is the right first target at all**,
  as against one layer: D13 says the hidden transformer *blocks* are what the
  first MVP must prove, and §8 recommends one block first. That sequencing
  is a recommendation, not a ruling.

## Revision record (2026-09-19)

Every item of `ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md` §12 and every ruling
of `ZK60_PRIVATE_BLOCK_125M_LAYOUT_DISPOSITION.md` §2, with the sections
changed and what changed. Where the check offered alternatives, the ruling
chose and this revision follows the ruling.

| item | sections | what changed |
|---|---|---|
| **B-1** the pad fix is unsound | §0 finding 4 context, §1.3 T-4, **§3.7 rewritten**, **§3.7a new**, §3.8 item 14, §5, §6 C6, §9 S9, §10.1 decision 3 | The claim that the pad "has `x = 0`" is withdrawn with its evidence (`D` movable to 524,357, or anywhere below 2^24 under the indicator alone); the fill column of §3.7's table is marked WITHDRAWN; the rule is now P-1's proved pad-zero invariant, specified plane by plane in the new §3.7a, with the support factor kept for the constraint groups, host terms, `SC_SS`/`SC_SSM` and `SC_RS` |
| **B-2** weights zero off their support | §3.7a (prover-side condition 3), §9 S9, §10.1 decision 3 | Stated as a construction obligation with a construction-time check, and — the part the check did not have to spell out — in the *destination axis's* index order, so `Wo`'s input columns are zeroed at the head slots `{3,7,11,15}` and not at `[768,1024)` |
| **B-3** the construction does not instantiate at `log_cols 14` | §2.2, §2.3, **§4.1 new**, §5 (three slot rows), §9 S4 (new step, before S10), §9a | The refusal is stated with its two call sites; the repair (lift `L` and `Tab` to `LOG_N`, padded table values repeating, zero extra rows) is a new subsection and a new change-list step sequenced before the geometry change; the three consequent slot round counts and `L` values are corrected |
| **B-4** S8's acceptance test cannot fire | §3.7a (tests PZ-1, PZ-2), §9 S9, §9a | Rewritten as the two tests of P-1: a lone nonzero pad value in a plane no sum reads, and the consistently adjusted pad; each written so it fails before the fix, with the "prover still produces a receipt" clause that stops it passing for the wrong reason |
| **C-1** padded head slots | §1.3 T-3, §2.3, §3.7, §3.7a, §10.1 decision 4, §9a | `[12, 16)` replaced by `{3, 7, 11, 15}` everywhere, with the reason (group 3, KV in the high bits) and the consequence (no support table is a prefix mask) |
| **C-2** calibration values | §1.3 T-11, §3.2 | Layer 1's recorded `eGate −4, eA −4, eZ −1` replace the draft's `−3, −3, 1`, with the instruction to quote per layer from the file |
| **C-3** nine `N` sites | §0 finding 1, §1.3 T-1 | Eight → nine sites; the four loud failures, the two panics (M-4) and `:293` as a completeness matter, not a silent soundness one |
| **C-4** `argument.rs:626` | §0 finding 1 (implicitly), §1.2, §1.3 T-2, §1.4 pin 46, §9 S5 | Re-classified (c) → (a); "the same shape of hole as D17" withdrawn; it is `fold_rows_i8`'s assertion; "T-2 is a soundness fix" struck from the step and replaced by "hygiene" with a named-refusal test |
| **C-5** four indicator tables | §3.7, §3.7a, §10.1 decision 3 | Two → four (`D`, `Q`, `S`, `Ht`) plus the lift's two, with the per-slot `table_of` clones and the verifier's own evaluation cost named |
| **C-6** four redundant lookups | §2.4, §3.3, §3.8 item 13, §4, §9 S13 | `Dom::D` 36 → 34 lookups, 18 → 17 helpers, `H` 7,082 → 7,018 data and 7,186 → 7,120 rows, `H` sites 51 → 50, U8 total 99,631,104 → 98,582,528, the swap +448 → +384 rows; the decision-2 branch (40 / 20 / 7,210 / 7,318 / 101,728,256) recorded with "recompute after the ruling" |
| **C-7** `A_GROUPS = 36` | §1.4 pin 17, §2.4, §7.1, §10.3 | 35 → 36 with the `limb_off(k) % N` reason; the receipt arithmetic redone; the "did not check" bullet replaced by the checked value |
| **C-8** proved `p` bound | §3.2, §3.4, §3.8 items 4 and 11 | PV 2^24.99 → 2^25.99 and `p·Sum + ρ_s` 2^27.00 → 2^28.00, with the reason (a premise table quotes what is proved) |
| **C-9** the 8B ceiling | §0 finding 2, §1.3 T-6, §3.3 (table row and "Later"), §3.8 item 9, §10.2 item 6 | "the construction cannot express it" replaced by "a fifth `ρ`/`σ` limb and a rewritten coefficient"; the failure above 32 stated as a compile error at four sites |
| **C-10** decision 2's arithmetic | §3.3 table (new row), §10.1 decision 2 | `wrho` 27 → 29, 5 bits → 3.2, two `D` limbs → three; the classes that *would* buy 27 and two limbs named |
| **C-11** where S2 drops | §7.1, §9 S2, §10.1 decision 8 | `protocol.rs:287` → after `:351`, with the five re-reads listed and a test that fails if the drop moves earlier |
| **C-12** the cloned masks | §1.3 T-10, §7.1 | Two 67 MB copies per slot in two slots, plus `exp_deltas` and `act_indices`: +110 MB, as a named line |
| **C-13** opening rate and table-points | §7.3 | 0.135 → 0.1055 ms/row (the phase opens `W` and `M` too), opening term 1.7 → 1.4 s, table-points 212.7M → 204,276,352, and the check's structural caution about 2^22 domains added |
| **C-14** form E's ceiling | §0 finding 3, §7.4, §10.1 decision 10 | 17.8% → a 10–17% band, with the numerator corrected to `Dom::F`'s 1,472 rows (11.8%) because the GPU prover proves neither `norm_m` nor residual 2; the reversing trigger sharpened to `Dom::S` getting a device path |
| **C-15** the `sym` lever | §4, §10.1 decision 9 | "about 11 million" → 7,208,960, with the nine pairs enumerated |
| **O-1** `xres1` unmeasured | §10.1 decision 2, §10.2 item 9 | Stated as a precondition of fixing the input class for the real model |
| **O-2** the one-block run | §0 finding 4, §7.1, §8, §9 S14, §10.2 item 10 | Detached, heavy lock, after S2, memory ceiling, **peak RSS as an acceptance figure**; "fits with 3 GB of headroom" qualified |
| **O-3** the privacy caveat in §8 | §8 | The caveat is now in the same sentence as "yes on memory and yes on time", together with the new hiding surface (block `k`'s opened vectors public before block `k+1`'s masks) and the two-block joint-view gate as a precondition |
| **O-4** the module's premise text | §4 observation 4, §9 S8, §10.2 item 11 | Named as part of D16 item 5, with the new bounds |
| **O-5** D12 item 2 | §8, §10.2 item 5 | Restated as a *pending ruling to be filed in `ZK60_DECISIONS.md`*, not a memo note |
| **O-6** multiplicities unchecked | §3.8 item 13, §4 observation 1, §10.2 item 12 | Stated explicitly as a property the new profile's premise must assert |
| **P-1** proved pad invariant | §3.7, **§3.7a**, §9 S9, §10.1 decision 3 | The new subsection is the specification: six indicators with their closed forms, the batched pad-zero term with its degree/host/costs, the plane table (ZERO or EXEMPT by name), three prover-side conditions, two acceptance tests, four open questions |
| **P-2** public weights | §3.7a, §9 S9 | As B-2, plus the head-permutation obligation on the model root |
| **P-3** the lookup repair first | **§4.1 new**, §2.2, §5, §9 (S4 before S10) | Sequenced ahead of the column-count step; the three conditions of the repair stated |
| **P-4** geometry | §2.2, §10.1 decision 1 | `log_cols 14 / inv_rate 4` kept, with the soundness figures now quoted wherever the geometry is mentioned |
| **P-5** the norm pin | §10.1 decision 2, §9 S8, §10.2 items 9 and 13 | Accepted in principle on the two conditions; the norm-range lane named as a **prerequisite that is pushed and not yet integrated** |
| **P-6** memory and the box | §0 finding 4, §7.1, §8, §9 S2 and S14 | The 125M run is a heavy run with the four conditions; S2 is a prerequisite |
| **P-7** the rung | **§9a new**, §9 (the old rung paragraph superseded) | Concrete parameters (`T 24 / d 96 / f 192 / 6 heads of 16 over 2 KV / log_cols 10 / F_E 12`), the requirement-by-requirement justification, a test map covering B-1 … B-4, the `argument.rs:626` panic, M-1 … M-7 and both windows, counted totals and receipt, the development-grade soundness caveat, and four open questions |
| **P-8** scope | status line, §0 finding 4, §8, §9 (S13, and the standing receipt-identity line), §10.1 decision 6, §10.2 item 7 | One block on **synthetic** weights is the deliverable; receipt identity asserted at every step |
| **new §3.7a** | §3 | See P-1 |
| **new §9a** | §9 | See P-7 |
| **new §1.5** | §1 | The check's added sites M-1 … M-7, plus the two facts in the module's favour (no `debug_assert`, no `as u8` on a dimension) |
| **new §4.1** | §4 | See B-3 / P-3 |

**Items that needed no change.** The shape table of §2.1 (verified source by
source). The `A` column of §2.5 — 5,435 data rows, 122 sites, 5,681 rows —
which reproduced exactly. `M_ROWS = 50` and its shape-independence. §3.2's
accumulation table apart from the PV row. §3.3's `Dmax = 908,065`, `2^31.79`
and the 0.21 bits. §3.4's softmax repair and its 512-row price. §4's table
set. §5's slot table apart from the three lifted rows and the support
column. §6's endpoint geometry (24 data rows, 29 commitment rows, 733,184 B
each). §7.3's 25–36 s band and its "plan for 2–4 minutes" posture. §8's
three-way chaining table and the seam-early order. Decisions 5 and 7.

**One thing this revision did not do:** it does not re-argue any ruling, and
where the check and the ruling differ on a remedy (the pad, above all) the
ruling is what is written down.

(revision complete)
