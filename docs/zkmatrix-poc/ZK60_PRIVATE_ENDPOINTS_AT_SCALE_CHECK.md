# ZK60 — adversarial check of the hiding-endpoints-at-scale draft

**Status: COMPLETE — 2 BLOCKING, 13 CORRECTIONS, 9 NOTES; 19 numbered
errata and conditions. P14 is CONFIRMED in substance — the seam binds
exactly one d-block and a `tdb`-widening leaves `nb_d − 1` blocks of the
hidden plane bound to nothing — but both its stated mechanism and its
stated scope are wrong. `nb_d = 1` at Mistral width `d = 4096`, confirmed
from `statement.rs:153-156`, but `nb_d > 1` at `d = 5120, 6144, 8192,
12288`, so the draft's exemption would authorise the unsound widening at
four real widths. The `mu`-batched fix survives my attack with the
soundness term the draft gives, one claim site and one reserved pair per
side at every width, and no unused hypercube positions — under four
conditions it does not state. Its soundness and hiding conclusions hold;
the lookup term dominates and the endpoint openings cost 0.03 bits.
No privacy property is established here and D8/D11 is not touched.**

| | |
|---|---|
| Document under check | `docs/zkmatrix-poc/ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` (1,286 lines), DRAFT of 2026-09-19 |
| Sections checked | all of §0–§8, every source citation opened, every COUNTED figure recomputed |
| Rulings read | D1, D8, D9, D11, D12, D13, D15, D16 (`ZK60_DECISIONS.md`) |
| Evidence written | `results/zk60_private_endpoints_check/recompute.py` and `recompute.out` (§9.1) |
| Model for method | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` on `zk60-attention-compile` |
| Checker | independent Opus agent, adversarial brief, 2026-09-19 |

## 0. Scope, method, and what a verdict here means

**Method.** Nothing in the draft was taken on trust. The layout's block
decomposition, the seam's claim structure, the CFS slot arithmetic, the PCS
grouping rule, the pad/coset structure and every frame constant were
re-derived from the source before the draft's statement of them was read
back. Every `[COUNTED]` figure in the draft was recomputed independently
(`results/zk60_private_endpoints_check/recompute.py`); every `file:line` the
draft cites in §1–§5 and §7 was opened.

**No build, no run.** No `cargo`, no proof, no test, no benchmark, no GPU,
no git write. Python was used only for arithmetic. Nothing outside this
document and `results/zk60_private_endpoints_check/` was created or changed;
no file that `git status --short` showed as modified or untracked was
touched (`zkp-core/src/mle.rs` is one of those — it was read only, and
§10 records that what I read there may be mid-edit).

**What a verdict here is not.** No privacy property is established by
anything below. D8/D11 stays open and is not touched. Where I confirm a
hiding statement I am confirming that a *hypothesis of a linear model*
survives a change of size — not that anything hides.

**Headline.** The draft's gravest claim, P14, is **correct in substance**:
the seam binds exactly one d-block, and a widening that keeps the single
`tdb`-wide slice leaves `nb_d − 1` blocks of the hidden plane tied to
nothing. But **both halves of the way P14 is stated are wrong** — its
mechanism (it does *not* "read past `x[0]` into `z[0]` and `rd[0]`") and its
scope (`nb_d = 1` is not "Mistral"; it is "`d` a power of two and
`d ≤ 4096`", and `nb_d > 1` at `d = 5120, 6144, 8192, 12288`). The
`mu`-batched fix survives my attack, with the soundness term the draft
gives, one claim site per side and one reserved pair at every width — but
it needs four conditions the draft does not state. Its soundness figures
reproduce, with one internal inconsistency; the lookup term dominates and
the endpoint openings really are nearly free. Its hiding argument carries
to the larger domain, and the precondition it leans on is enforced by a
runtime `assert!` I found that the draft does not cite. C5 of the change
list, as written, breaks the draft's own standing condition.

## 1. Findings, ranked

**2 BLOCKING, 13 CORRECTIONS, 9 NOTES.** The design decisions the draft
recommends (form 2; the endpoint at the layer's `LayerParams`; a
statement-derived wire bound; "not P1") all survive. What does not survive
is the wording of P14, the specification of C5, and a handful of numbers.

### BLOCKING

**C-B1 — the P14 exemption, as written, would authorise the unsound
widening at four real model widths.** Draft §0 headline 4 (line 59),
§2.3 P14 (lines 406-409) and decision 2 (line 1163) all say Mistral has
`nb_d = 1` "and is unaffected". `nb_d = d / 2^min(trailing_zeros(d), 12)`
(`zkp-core/src/ffn_v3/statement.rs:139`, `:153-156`), so `nb_d = 1`
**iff `d` is a power of two and `d ≤ 4096`** — true at `d = 4096`, false
at `d = 5120` (`nb_d = 5`), `6144` (3), `8192` (2), `12288` (3), `16384`
(4), `2560` (5), `3072` (3), `768` (3). §8.2 item 7 states the obligation
correctly; §0, §2.3 and decision 2 do not, and those are the sentences a
reader building "the 8B shape" would carry. Required: replace every
"Mistral / `nb_d = 1` is unaffected" with the rule, and state that C6 is
unconditional for any general entry point — not an option that the 8B
width happens to avoid. §2.4.

**C-B2 — C5 as specified edits the frozen tiny seam path and its verifier
boundary; its "moves a proof byte? No for existing paths" is false.**
C5 (line 1100) names `private_seam.rs:28-36` (the module constants),
`:99-105` (`params()`) and `:164-181` (`check_ntt`) as the files it
changes, and its test asks that "`check_ntt` accepts the 2^16 table".
`LOG_COLS`, `INV_RATE`, `CHECKS` and `MASK_ROWS` are **hashed into
`SeamSpec::digest()`** (`private_seam.rs:119-133`), which is absorbed by
the standalone seam transcript (`:246`) and compared by
`into_ffn_endpoint` (`:157`); `params()` fixes the endpoint root itself,
and the `/2` verifier hard-codes the resulting geometry
(`ExpectedIo::from_roots`, `zk_ffn_fresh_io.rs:58-68`). Editing any of
them moves the existing profile. Widening `check_ntt` in place also
relaxes a boundary the module exists to keep narrow. Required: C5 becomes
a **new** `SeamSpecG` + `check_ntt_for(domain)` beside the existing ones,
exactly the way C4 is written, and C5's "moves a byte? No" cell is
qualified accordingly. §5.4.

### CORRECTIONS (short form; the errata table carries the full text)

C-C1 P14's mechanism ("reads past `x[0]` into `z[0]` and `rd[0]`") is
wrong — the `x` blocks are contiguous. C-C2 the three candidate widenings
must be distinguished; only the `tdb` one is silently unsound. C-C3 A12 is
a prover-side divergence, not a soundness bug. C-C4 P12's consequence is a
refusal, not a verifier checking a different geometry. C-C5 the 125M
`log_cols` sweep figures are not reproducible. C-C6 the whole-proof
arithmetic mixes two per-opening conventions. C-C7 the 125M seam error is
`2^-122.3`, not `2^-122.4`. C-C8 `3 × 2^21 × 16 B` is 96 MiB, not
100.7 MiB. C-C9 the 32-layer total is 1.27 GiB, not 1.28 GiB. C-C10 the
C6 tamper-test sentence ("a naive widening passes 1 and 2") is
unreadable and, on either reading, wrong. C-C11 the §1.1 row table
mislabels endpoint row 5, which is half the H-prox pair. C-C12 the draft
reports D15's deployment per-opening figure as reproduced when it is in
fact corrected by 0.64 bits. C-C13 §4.2's "~256 openings" understates the
count its own §4.2 arithmetic uses (192 + 64).

### NOTES

C-N1 the seam's CFS slot at `zk.rs:2172` is *already* the right arity for
form 2 and needs no change — a point in form 2's favour the draft does not
make. C-N2 the `1u64 <<` overflow is in two places, not one. C-N3 H-pair's
"one pair, unshared" is enforced nowhere on the io path (`audit_claims`
exists only in `private_block/protocol.rs:89`). C-N4 the reduction's
leverage is `n·k0`, and `n` grows 64×. C-N5 the "u-row term" the draft
inherits is undefined in its source. C-N6 `coset_powers` asserts the
H-pad precondition at runtime at every width. C-N7 a general endpoint may
need a different `log_n` from A's. C-N8 decision 1 must clamp with
`pcs_for(log_t + log_db)` or `check_masks` refuses the claim. C-N9 the
D9 bias is soundness-negligible but the draft's reason for saying so is
a privacy argument.

## 2. P14 — the draft's gravest claim, re-derived from the layout

### 2.1 How the layout decomposes the planes, from the source

`Layout::new` (`zkp-core/src/ffn_v3/statement.rs:148-179`) is the only
place the block structure is fixed:

```
log_db = d.trailing_zeros().min(12)                      :153
db     = 1 << log_db;  nb_d = d / db                     :155-156
tdb    = t_rows * db                                     :158
let mut off = 0; let mut vecn = |n, sz| (0..n).map(|_| { let o = off; off += sz; o })…   :159-160
g8,rg,a16,u16,ru,h16,rh = vecn(nb_f, tfb)   (seven)      :161-162
x = vecn(nb_d, tdb); z = vecn(nb_d, tdb); rd = vecn(nb_d, tdb)                            :163
```

Three facts follow, and all three matter below.

1. **`nb_d` is decided by the 2-adic valuation of `d`, capped at 12.**
   `nb_d = 1` **iff `d` is a power of two and `d ≤ 4096`**. Recomputed
   (`recompute.py` §1, and the same rule by hand):

   | `d` | 768 | 1024 | 2048 | 2560 | 3072 | 4096 | 5120 | 6144 | 8192 | 12288 | 16384 |
   |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
   | `log_db` | 8 | 10 | 11 | 9 | 10 | **12** | 10 | 11 | 12 | 12 | 12 |
   | `nb_d` | 3 | 1 | 1 | 5 | 3 | **1** | 5 | 3 | 2 | 3 | 4 |

   **At Mistral width `d = 4096` the rule gives `log_db = 12`, `db = 4096`,
   `nb_d = 1`.** The draft is right about Mistral, and I checked it from
   `statement.rs:153-156` rather than from the draft; the committed test
   `assert_eq!((big.nb_d, big.nb_f, big.log_db, big.log_fb), (3, 1, 8, 11))`
   for `Layout::new(512, 768, 2048)` (`statement.rs:230-232`) corroborates
   the rule at the 125M shape. But `nb_d = 1` is a property of *powers of
   two up to 4096*, not of "model scale": see C-B1.

2. **The `nb_d` x-blocks are contiguous and exactly fill `T·d`.** `vecn`
   is a single running offset (`:159-160`), so
   `x[c] = x[0] + c·tdb` and `x[nb_d-1] + tdb = z[0]`. Since
   `nb_d·tdb = nb_d·t_rows·db = t_rows·d = T·d`, the half-open range
   `[x[0], x[0] + T·d)` is **exactly** the input plane. This is the
   sentence P14 gets wrong (C-C1).

3. **Every block boundary is a commitment row boundary.**
   `log_n = params.log_cols.min(lay.log_a_min)` (`hashline/src/zk.rs:2005`)
   with `log_a_min = log_t + min(log_db, log_fb)` (`statement.rs:176`), so
   `n = 2^log_n ≤ 2^(log_t+log_db) = tdb` and `n | tdb`, and `n | x[0]`
   because every earlier allocation is a multiple of `tfb` (also a
   multiple of `n`). This is what makes form 2 expressible at all (§3.3).

### 2.2 What the endpoint path actually reads

The seam's offsets and tables, prover side
(`hashline/src/zk_ffn_fresh_io.rs`):

```
:284   let offsets = [self.pending.zl.lay.x[0], self.pending.zl.lay.z[0]];
:301   self.pending.a.data[offsets[i]..offsets[i] + 512]      <- table 1
:306   endpoints[i].data[..512]                               <- table 2
:292   let tau = self.tr.challenge_fp2_vec(9);
```

verifier side `:378` (`let offsets = [zl.lay.x[0], zl.lay.z[0]];`) and
`:389` (`sumcheck::verify(a.gamma, 2, 10, &a.sc, tr)`).

The literal `512` is **`tdb` at the tiny shape** (`t_rows·db = 32·16`), and
also `T·d` there, because `nb_d = 1`. The `9` at `:292` is
`log_t + log_db`, and the `log_size: 9` of the claim's data part
(`claim`, `:204-216`) is the same thing.

**What the seam's equality ranges over.** `masked_prove`
(`zk.rs:972-981`) runs `sumcheck::prove` over three tables of `2^9`
entries — `eq_table_msb(tau)`, the A slice, the endpoint slice — with
`poly(v) = v[0]·(v[1] − v[2])` (`:198-200`). The claimed sum is
`Σ_x eq(tau, x)·(A(x) − B(x))` over the `2^(log_t+log_db)` cube **of that
one slice**, and nothing else. The extension round (`zk.rs:984-996`) adds
one variable; the verifier's terminal identity is `:395-401`. The PCS then
binds the two terminals: the A-side claim's data part is
`Slice { offset: offsets[i], log_size: 9 }` (`:209-210`) and the endpoint
side's is `Slice { offset: 0, log_size: 9 }` (`:346` → `:208-216`).

**So the relation proved is: the multilinear extension of (A's slice at
`lay.x[0]` of length `tdb`) − (the endpoint's first `tdb` words) vanishes
at `tau`.** Not one word more.

### 2.3 Is the binding complete at `nb_d = 1`?

**Yes, and I could not break it.** At `nb_d = 1` the slice at `lay.x[0]`
of length `tdb = T·d` is the whole input plane, and the endpoint's
`data[..tdb]` is its whole plane: `prepare_with_rng` allocates
`commitment_rows·n` words, copies `values` (length `spec.len()`, checked
at `private_seam.rs:193`) into the front, and fills everything from
`data_rows·n` on with `rng.fp()` (`:209-213`), with
`data_rows = len.div_ceil(n)` (`:106-108`). With `len = tdb` a multiple of
`n`, `data[..tdb]` is exactly the plane and the first mask row starts at
`tdb`. Three things close the remaining gaps:

* the prover cannot commit *more* data rows: `ExpectedIo::from_roots`
  hard-codes `rows: 7, log_cols: 8` (`zk_ffn_fresh_io.rs:58-68`), that
  policy is absorbed (`:140`), and `verify_zk` refuses a `log_cols`
  mismatch (`zkp-core/src/pcs.rs:961`) while `Reader::hiding(1, 7)`
  (`:581`, `zk_ffn_fresh_wire.rs:389-400`) parses exactly 7 rows per
  column;
* the root is the owner's own: `check_endpoints` recomputes both roots
  from the consumed owners and compares them to the policy (`:258-271`);
* a wrong plane *does* reach the verifier and fails the identity — the
  committed negative `wrong_plane` recommits the tampered plane and uses
  its **real** root, and the refusal is `IO {side} sumcheck:`
  (`zk_ffn_fresh_io_tests.rs:108-129`).

At Mistral width (`nb_d = 1`) the same holds with `tdb = 2^21`.

### 2.4 The concrete attack at `nb_d > 1`

Take the 125M shape, `T = 512, d = 768, f = 2048`: `log_t = 9`,
`log_db = 8`, **`nb_d = 3`**, `tdb = 131,072`, plane `393,216` words.
Suppose A1 is relaxed and the literal `512` is replaced by `tdb` — the
substitution the draft's own A10 analysis implies ("512 is `tdb`, *one
d-block*", line 363), and the one a careful engineer would make because
`log_size: 9` is `log_t + log_db`.

**The prover's move.** Let `x` be the true input plane. The endpoint
owner (who may be the prover) commits
`B = (x_0 ‖ w_1 ‖ w_2)` where `x_0` is block 0 of `x` and `w_1, w_2` are
**arbitrary**: zeros, another request's plane, or whatever makes a
downstream consumer accept. The policy carries `B`'s real root. The FFN is
proved honestly on the true `x`.

**Which check rejects it? None.**

| check | what it does | why it passes |
|---|---|---|
| `check_endpoints` (`:258-271`) | recomputes roots from the owners, compares to policy | the root *is* `B`'s root |
| the seam sumcheck (`:299-319`, verified `:389-401`) | `Σ eq(tau,x)(A_{x[0]} − B_{[0,tdb)})` | both sides are block 0; the identity holds exactly |
| the endpoint PCS opening (`:361`, `:462-471`) | binds `Slice{offset: 0, log_size: log_t+log_db}` plus the reserved pair | touches only `B`'s first `tdb` words |
| the A-side PCS opening (`zk.rs:2323`) | binds `Slice{offset: x[0], …}` | `A` is honest anyway |
| the receipt shape check (`:536-548`) / `io_shape` (`zk_ffn_fresh_wire.rs:226-234`) | pins rows, groups, column count, depth | `B` has the right number of rows — `w_1, w_2` sit *inside* the data rectangle |
| `check_masks` (`:360`, `:459`) | per-claim Fp2 span on the mask rows | unaffected by data content |

Two thirds of the plane behind the published root is bound to nothing.
The statement the product needs — "the plane behind this root is the plane
the feed-forward consumed" — is false for `(nb_d − 1)/nb_d` of it. **P14 is
confirmed.**

Note which way the damage runs. `A`'s own `x` blocks 1 and 2 are still
fully constrained by the layer's own zero-checks; what is unbound is the
*endpoint*, i.e. precisely the object D1/P1 relies on. And the existing
tamper test would not catch it: `wrong_plane` perturbs position 271
(`zk_ffn_fresh_io_tests.rs:111-114`), which is inside block 0 at any
`nb_d`.

### 2.5 Three candidate widenings, distinguished (C-C1, C-C2)

The draft treats "a mechanical widening" as one thing. It is three, with
three different outcomes. Recomputed offsets at 125M
(`recompute.py` §2): `x` at 7,340,032 / 7,471,104 / 7,602,176; `z` at
7,733,248 / 7,864,320 / 7,995,392; `rd` at 8,126,464 / …

| widening of the literal `512` | covers | outcome |
|---|---|---|
| **to `tdb`** (= 131,072) | `[7,340,032, 7,471,104)` = `x[0]` only | **silently unsound** — §2.4. This is the real P14. |
| **to `T·d`** (= 393,216) | `[7,340,032, 7,733,248)` = `x[0..2]` **exactly**, ending where `z[0]` begins | **sound where expressible**: binds the whole plane. Expressible only when `nb_d` is a power of two, because `Slice.log_size` is a power-of-two size (`pcs.rs:56-60`) and `masked_prove` folds a power-of-two table (`sumcheck.rs:~90-128`). At `d = 8192` (`nb_d = 2`) it *is* expressible and *is* correct; at `d = 768` (`nb_d = 3`) it is not. |
| **to `2^ceil(log2(T·d))`** (= 524,288) | `[7,340,032, 7,864,320)` = `x[0..2]` **plus `z[0]`** | loud failure, and worse than under-binding: on the A side it mixes the *output* plane into the input equality; on the endpoint side the slice runs past `data_rows·n` into the reserved terminal pair (`private_seam.rs:216`), which breaks H-pair's "the claim's non-data-row weights are exactly `(e, e·U)` on one pair". |

**C-C1.** Draft line 782 says a mechanical widening "to `T·d` would read
past `x[0]` into `z[0]` and `rd[0]`". Both halves are wrong: `T·d` reads
*exactly* `x[0..nb_d−1]` and stops at `z[0]`; it is the round-up-to-2^19
variant that reaches `z[0]`, and even that never reaches `rd[0]`
(`rd[0] = 8,126,464 > 7,864,320`). Source: `statement.rs:159-163`, the
single running `off`.

**C-C2.** The draft must name which widening it means. Its headline
("a mechanical widening is UNSOUND when `nb_d > 1`") is true of the `tdb`
variant only; the `T·d` variant is sound at every power-of-two `nb_d`. The
distinction is load-bearing because `d = 8192` is a real width.

**One more thing that saves the `tdb` variant from being *silently*
broken in the mask channel, and one that does not.** `mask_specs_v3`
already derives the io slots as `((lay.log_t + lay.log_db) + 1, 2)` twice
(`zk.rs:2172`) — the **d-block** arity, not the plane's. So a `tdb`
widening gets a slot of the right size and runs clean; nothing complains.
A `T·d` widening at `nb_d = 2` would run `log_t+log_db+1` rounds against a
mask of `n_vars = log_t+log_db+1`… one short: `CfsMask::round` indexes
`coeffs[2 + j·degree + e − 1]` for `j` up to the round count
(`sumcheck.rs:264-273`) and `CfsMask::eval` asserts
`rho.len() == n_vars` (`:251`), so it panics rather than under-binding.
**That asymmetry is the reason P14 is dangerous: the unsound variant is
the quiet one.** The draft does not say this, and it is the strongest
argument for C6's tamper test.

## 3. The mu-batched multi-block seam (C6), attacked

The draft's fix is §3.3 form 2 (lines 521-548) and change C6 (line 1101).
Its soundness argument is three lines (lines 534-536) and its hiding claim
is one (lines 538-541). **It survives my attack** — with four conditions
the draft does not state. Everything below is what the draft would have to
say for me to call C6 accepted.

### 3.1 The relation, written out

For side `i ∈ {0,1}` with offsets `o_i = lay.x[0]` / `lay.z[0]`, write
`A_c(·)` for the multilinear extension of
`a.data[o_i + c·tdb .. o_i + (c+1)·tdb]` and `B_c(·)` for that of
`endpoint_i.data[c·tdb .. (c+1)·tdb]`, `c = 0..nb_d−1`, each on the
`m = log_t + log_db` cube. With `mu ∈ Fp2^{nb_d}` and
`tau ∈ Fp2^m` from the transcript, the prover runs the existing
three-table masked sumcheck (`zk.rs:972-981`) on

```
T0 = eq_table_msb(tau)      T1 = Σ_c mu_c · A_c      T2 = Σ_c mu_c · B_c
poly(v) = v0 · (v1 − v2)            degree 2,  m rounds
claimed sum = gamma = c · g_s.total()        (masked; zk_ffn_fresh_io.rs:295)
```

then the one extension round (`zk.rs:984-996`, `:336-338` refuses `e = 0`),
and the verifier checks
`fin == (1−e)·eq(tau, rho[..m])·(terminals[0] − terminals[1]) + c·mask_eval`
(`zk_ffn_fresh_io.rs:395-401`). The A-side claim becomes

```
part c (c = 0..nb_d-1):  Slice{ offset: o_i + c·tdb, log_size: m },  coef mu_c·(1−e),  point rho
part nb_d:               Slice{ offset: row·n,       log_size: log_n}, coef e,         point rho[m−log_n..]
part nb_d+1:             Slice{ offset: (row+1)·n,   log_size: log_n}, coef e·U,       point rho[m−log_n..]
```

and the endpoint-side claim the same with `o_i` replaced by 0 and `row` by
`data_rows`. This is the existing `claim()` (`:204-235`) with the single
data part replaced by `nb_d` of them. **The statement proved is
`Σ_c mu_c (A_c − B_c) ≡ 0` as a polynomial, tested at `tau`.**

### 3.2 Order: is `mu` drawn late enough? (condition 1)

The draft says only "after both roots are absorbed" (line 522). That is
satisfied at transcript construction and is **not the binding
requirement**. What the argument needs is that `mu` be drawn after every
object the differences `δ_c = A_c − B_c` depend on. Checked against the
live order:

| absorbed / drawn | where |
|---|---|
| `PROFILE`, then `expected-IO` = context ‖ scales ‖ **both endpoint roots** | `zk_ffn_fresh_io.rs:139-140`, `:76-85` |
| the parameter literal | `:141-144` |
| statement, W, **A's root** (`absorb_com(tr, b"A", …)`) | `zk.rs:2471`, **`:2542`** |
| **M's root** (the CFS masks, incl. the two reserved io slots) | `zk.rs:2545`, slots at `:2172` |
| `io-side = i`, then `tau` | `zk_ffn_fresh_io.rs:291-292` (verifier `:385-386`) |
| `c` (mask challenge, `c = 0` discards) | `:293` (verifier `:387`) |
| the sumcheck's own `rho` | inside `masked_prove` / `sumcheck::verify` |

So **drawing `mu` at `:292`, beside `tau`, is correct**: A's root
(`zk.rs:2542`) and both endpoint roots (`:140`) precede it, so `δ` is
fixed before `mu` exists. The order of `mu` against `tau` is immaterial;
what is not immaterial and is not stated is that **`mu` must be drawn at
the identical point by the verifier (`:386`), must be `nb_d` fresh
transcript draws, and must never be re-derived from `rho` or from the
terminals.** C6 must say this. (`mu` is independent of the sumcheck's
challenges by construction: `rho` is produced inside `sumcheck::prove`
after the round messages are absorbed, `sumcheck.rs:109-111`.)

Drawing one `mu` per side (inside the existing loop, after
`absorb_u64(b"io-side", i)`) versus one shared across both sides: I could
not build an attack on the shared form — the two sides are separate
equalities at independent `tau`, so there is no cross-cancellation — but
per-side is free and is what the loop structure gives.

### 3.3 Soundness error

Three terms, by union bound, **per proof attempt**:

* **batching.** If some `δ_c ≢ 0`, pick `x0` with `δ_c(x0) ≠ 0`. Then
  `mu ↦ Σ_c mu_c δ_c(x0)` is a nonzero **linear** form in `nb_d`
  variables, so it vanishes on at most `|Fp2|^{nb_d−1}` of `|Fp2|^{nb_d}`
  points: `Pr ≤ 1/|Fp2|`. **The error does not grow with `nb_d`** — the
  draft's figure is right and its one-line reason is right; the brief's
  suggestion of "a Schwartz–Zippel term in the number of blocks" would be
  the bound for a *powers-of-one-challenge* batching (`mu_c = μ^c`), which
  would cost `(nb_d−1)/|Fp2|`. Either is negligible; the vector form is
  the cheaper and is what the draft proposes.
* **the evaluation point.** `Δ = Σ mu_c δ_c` is multilinear in `m`
  variables, total degree ≤ `m`: `Pr[Δ(tau) = 0 | Δ ≢ 0] ≤ m/|Fp2|`.
* **the sumcheck.** `m + 1` rounds of degree 2: `≤ 2(m+1)/|Fp2|`.

Total `(1 + m + 2(m+1))/|Fp2| = (3m + 3)/|Fp2|`. Recomputed
(`recompute.py` §6, `|Fp2| = p²`, `p = 2^64 − 2^32 + 1`):

| shape | `m` | seam only `(m+2(m+1))/|Fp2|` | with the `mu` term |
|---|---:|---:|---:|
| tiny | 9 | `2^-123.14` | — (`nb_d = 1`) |
| **125M block** | **17** | **`2^-122.27`** | `2^-122.24` |
| Mistral | 21 | `2^-121.98` | — (`nb_d = 1`) |
| 64 seams over a 32-layer pass at `m = 21` | — | `2^-115.98` | — |

**C-C7:** the draft's table (line 703) gives `2^-122.4` at `m = 17`; the
value is `2^-122.27` (`53/|Fp2|`, `log2 53 = 5.728`). `2^-122.4` is what
`m = 16` gives. The tiny and Mistral rows reproduce exactly.

The draft's "one extra term of `2^-128` per side per layer, i.e.
`64 · 2^-128 = 2^-122` over a 32-layer pass" (line 535) reproduces
(`2^-122.000`), with the caveat that at `nb_d = 1` there is no `mu` at all,
so the pass-level figure applies only to a shape that needs batching.

**C-N9.** `mu` is drawn by `Transcript::challenge_fp2`, which D9 records
as within `2^-96` of uniform per word. The draft (line 684) dismisses this
as "a privacy term, not a soundness one, per D9's wording correction", and
D9's stated reason — "the verifier reduces identically in both worlds" —
is a *simulation* argument that does not by itself bound a Schwartz–Zippel
term. The magnitude does: a max point mass of `1/p + 2^-96` inflates
`1/|Fp2|` by a factor `(1 + 2^-32)²`, invisible at this precision. Say
that, rather than citing a privacy ruling for a soundness claim.

### 3.4 Claim sites, groups and reserved pairs (condition 2)

The brief's question — "a batched claim over `nb_d` blocks of A evaluates
A at how many points?" — has two answers, and only one of them is the one
H-pair counts.

* **Evaluation points: `nb_d`.** The claim is a linear functional that
  reads `A` at `nb_d` distinct slice-points (same `rho`, different
  offsets).
* **Claim sites: 1 per side per commitment.** A `ZClaim` is one member of
  one group. `group_zclaims` (`pcs.rs:809-831`) folds a claim's parts into
  **one** row-weight vector and **asserts** all its parts share one column
  key (`:816`, "zk claim: parts with different column weights").

That assertion is exactly the condition form 2 must meet, and it does:
`zpart_weights` (`pcs.rs:752-792`) gives a part with `log_size ≥ log_cols`
the key `ZKey{ tail: point[ls−log_cols..], c0: 0, len: n }`. All `nb_d`
data parts carry the same `rho`, so the same tail; the two mask parts
carry `rho[m−log_n..]`, the same tail again. **One key, one group, one
group vector per endpoint opening, two new groups on A (one per side) at
every width** — unchanged from today's `assert_eq!(…a_open.group_vecs.len(), 7)`
(`zk_ffn_fresh_io_tests.rs:83`) and `group_vecs.len() == 1`
(`zk_ffn_fresh_io.rs:537`). This requires `offset % n == 0`, which §2.1
fact 3 guarantees, and `check_masks` independently refuses otherwise
(`zk_ffn_fresh_poc.rs:268-272`).

**H-pair therefore still needs one reserved pair per side.** Its text is
"every claim's row weights, **restricted to the non-data rows**, sit on
exactly one adjacent reserved pair" (`ZK60_NATIVE_JOINT_VIEW.md` §2.2).
The `nb_d` data parts land entirely on data rows
(`offset/n + weights.len() ≤ data_rows`), so the restriction to non-data
rows is still `(e, e·U)` on one pair, `e ≠ 0` refused at `:336-338` and
`:392-394`. **The draft's "one pair at every width" is right**, and
`MASK_ROWS = 5` suffices under form 2. Under form 1 it would not:
`nb_d` claims per side need `nb_d` disjoint pairs, hence
`MASK_ROWS = 2·nb_d + 3`, which the draft says.

**C-N3 — and this is the condition.** Nothing on the io path checks the
"one pair, **used by no other claim**" half of H-pair. `check_masks`
(`zk_ffn_fresh_poc.rs:253-321`) checks only that each claim's coefficients
on the mask rows *span Fp2*; it does not check disjointness across claims,
and it does not check that the claim is zero on the proximity rows. The
refusal that does check it — `audit_claims`, with its committed negative
`"a pair shared by two claims"` — exists **only** in
`hashline/src/private_block/protocol.rs:89` (`private_block/tests.rs:325`).
So on the io path H-pair is a construction property, not a checked one, at
every width. That is fine for form 2 (one claim, one pair, by
construction) and is a live hazard for form 1. C6/C4 must either port
`audit_claims` to the io path or state that form 1 is forbidden.

**D12 rule 1 — "each commitment opened exactly once".** Unchanged by
batching: the two seam claims on A join the FFN's *single* `open_zk`
(`zk.rs:2323`, claims accumulated at `zk_ffn_fresh_io.rs:343-345`), and
each endpoint is opened once at `:361`. Form 2 adds parts, not openings.
✓

### 3.5 Can the batched equality hold while blocks differ?

Beyond the `1/|Fp2|` above, I looked for structure:

* **Adaptive choice of a plane.** Both roots precede `mu` (§3.2), and
  `check_endpoints` (`:258-271`) ties the owner to the absorbed policy, so
  neither `A_c` nor `B_c` can move after `mu`. A colluding owner+prover
  still must fix both before.
* **Choosing `mu`.** `mu` comes from the transcript; the only lever is
  re-running the attempt. Because the io profile draws fresh OS entropy
  every attempt (`:164`, `private_seam.rs:196`), A's and M's roots — and
  hence `tau`, `c`, `e`, `mu` — are re-randomised on each try at no cost
  to the endpoint planes. That is ordinary Fiat–Shamir grinding: `k`
  attempts cost `k·2^-122`. Worth one word in §4.1 ("per attempt"); not a
  finding.
* **Cancellation across blocks.** `Σ_c mu_c δ_c ≡ 0` with some `δ_c ≠ 0`
  requires the `mu` to lie in a fixed hyperplane determined by the `δ`s —
  measure `1/|Fp2|`. No sub-structure helps: the `δ_c` are arbitrary and
  independent of `mu`.
* **Cancellation across the two sides.** Impossible: separate claims,
  separate `tau`, separate reserved pairs, separate group vectors.
* **Degenerate `mu`.** If some `mu_c = 0`, block `c` is unbound in *that
  attempt*. Probability `nb_d/|Fp2|`; it is absorbed in the `1/|Fp2|` above
  (a zero `mu_c` is one way to land in the bad hyperplane). It needs no
  extra refusal, and adding one would be a *hiding* hazard, not a help:
  the profile's rule is "record a refusal and stop, never resample"
  (draft line 1115). C6 should say explicitly that `mu` is **not**
  refused on zero, unlike `c` and `e`, and why.

**Nothing found.** Form 2's soundness sketch is correct.

### 3.6 Non-power-of-two planes: what is constrained on both sides
(condition 3)

This is the brief's sharpest question, and the draft answers it only
implicitly (via P13, line 396: "the correct general form is per-d-block
… not per-plane"). Written out:

**Under form 2 there are no unused hypercube positions on either side.**
Each of the `nb_d` sumcheck-side tables is exactly `2^m = tdb` long —
`sumcheck::prove` asserts `n_total.is_power_of_two()` and takes
`n_rounds = n_total.trailing_zeros()` (`sumcheck.rs:54-57`), so a
non-power-of-two cube is not merely unwise, it is inexpressible. On the
endpoint side the committed data region is `nb_d·tdb` words, a multiple of
`n` (§2.1 fact 3), so `data_rows = nb_d·tdb/n` exactly and the claim's
`nb_d` slices tile it with nothing left over. On the A side the `nb_d`
slices tile `[x[0], x[0] + T·d)` exactly. **Both sides are fully covered,
and the equality is over the plane, not over a padded superset.**

**What the draft must state, because it is not automatic.** The endpoint
commitment's data region must be *exactly* the `nb_d` blocks — no padding
row between the plane and the reserved pair. If a general `SeamSpecG` kept
`SeamSpec`'s power-of-two axis rule by rounding the plane up (the obvious
way to reuse `private_seam.rs:67-72`), then:

* `prepare_with_rng` zero-fills `data` and overwrites from `data_rows·n`
  on with `rng.fp()` (`:209-213`), so the rounded-up region is **zero**
  while A's corresponding region holds `z[0]` — the equality fails
  honestly (a completeness break), *and*
* the rounded-up slice reaches from `data_rows·n` into
  `committed.mask_rows = [data_rows, data_rows+1]` (`:216`), putting a
  data-part coefficient on a reserved mask row. That breaks H-pair's
  "restricted to the non-data rows, exactly one adjacent pair" and is a
  **hiding** break, not a soundness one — and `check_masks` would not
  catch it, because the pair's coefficient would still span Fp2 (§3.4).

So: **condition 3 — C6 must pin `SeamSpecG`'s data region to
`nb_d · tdb` with `n | tdb`, forbid any padded row between the plane and
`mask_rows`, and assert `data_rows·n == nb_d·tdb`.** The tiny profile
satisfies this by accident (`512 = 2·256`); a general one must do it on
purpose.

**Condition 4 — the two commitments may need different `log_n`.** The
draft's A10 (line 363) treats "every `8` / `256` as `log_n` / `a_n`",
singular. A's column count is `min(log_cols, log_t + min(log_db, log_fb))`
(`zk.rs:2005`); the endpoint's, under decision 1, should be
`min(log_cols, log_t + log_db)`. These differ whenever `log_fb < log_db`
**and** the minimum is below `log_cols` — e.g. `T = 512, d = 16` gives A
`log_n = 14` and the endpoint 13. No real model width reaches it
(`T = 512` and `d ≥ 32` put both at 14), but `claim()` and `mask_value`
are shared between the two sites (`:345`, `:346`, `:201-203`) and
hard-code one width. C7 must parameterise them per commitment.

**C-N8, and it follows from the same place.** Decision 1 ("use the
enclosing `LayerParams`") must clamp with `pcs_for(log_t + log_db)`, not
with the raw `log_cols`. If `log_cols` exceeded the plane's bit width the
data part would become a *sub-row* slice (`log_size < log_cols`), and
`check_masks` refuses that outright — `"unsupported repaired claim
mapping"` at `zk_ffn_fresh_poc.rs:268` — so the profile would not run at
all.

**C-N1, in form 2's favour and unstated by the draft.** The two io CFS
slots are already derived as `((lay.log_t + lay.log_db) + 1, 2)`
(`zk.rs:2172`) — the **d-block** arity. That is exactly form 2's round
count (`m + 1`) at every width, so **C6 needs no change to
`mask_specs_v3`**, and the `L` figures of §4 fall out of the existing
code. Form 1 would need `2·nb_d` slots there, i.e. an edit to a function
shared with the frozen tiny path (byte-neutral at `nb_d = 1`, but an edit).

## 4. The slot arithmetic: L, the two ceilings, and MASK_ROWS

### 4.1 `L` from the source

Two lines fix it:

```
CfsMask::len(n_vars, degree) = n_vars * degree + 2          zkp-core/src/sumcheck.rs:197-199
io slots = [((lay.log_t + lay.log_db) + 1, 2); 2]           hashline/src/zk.rs:2172
```

so with `m = log_t + log_db` the seam's slot is `(m + 1, 2)` and
`L = 2(m + 1) + 2 = 2m + 4`. The draft's closed form (line 579,
`L = 2·log2 N + 4`) is this with `log2 N` read as **the cube's** bit
width, which is `m`, not the plane's `log2(nb_d·tdb)`. At `nb_d = 1` they
coincide; at 125M form 2 they do not, and the draft's §3.4 table correctly
labels that row "125M **block**" while its prose (line 42, "A Mistral
endpoint plane is `log2 N = 21`") reads as if it were the plane. Harmless
at `nb_d = 1`; worth one word.

Recomputed (`recompute.py` §3), and all four of the draft's rows
reproduce:

| shape | `m` | `n_vars` | **`L`** | `L + 256` | headroom |
|---|---:|---:|---:|---:|---:|
| tiny T32/d16 | 9 | 10 | **22** | 278 | 234 |
| 125M block (form 2) | 17 | 18 | **38** | 294 | 218 |
| Mistral T512/d4096 | 21 | 22 | **46** | 302 | 210 |
| a 2^40 cube | 40 | 41 | **84** | 340 | 172 |
| the binding case | 126 | 127 | **256** | 512 | 0 |

**`L = 22` at the tiny shape is pinned by a committed assertion**, not
only by arithmetic: `assert_eq!(&held.mc.specs[6..], &[(10, 2); 2])`
(`zk_ffn_fresh_io_tests.rs:51`), with `CfsMask::len(10,2) = 22`. The
neighbouring assertion `held.mc.encoded.len() == 20 * 4096` (`:52`) pins
the M row count that §4.3 re-derives.

### 4.2 The bound, and which ceiling really binds

The assert is in `mask_commit`:

```
assert!(part.len() + MASK_Q <= m, "mask row: {} coefficients + {MASK_Q} pads > {m}", …)
                                                        hashline/src/zk.rs:442
m = 1usize << MASK_LOG_MSG (= 512)   :373, :431        MASK_Q = 256   :375
```

`part` is the real or imaginary half of one mask's coefficient vector, so
`part.len() = L`. Hence `L + 256 ≤ 512`, `L ≤ 256`, `n_vars ≤ 127`,
`m ≤ 126`. The draft's derivation is exact and its "the worry is real in
form and empty in magnitude" is right: a plane of `2^126` words.

The draft's caveat that the **real** ceiling is a `1u64 << n_vars`
overflow is also right, and tighter: `CfsMask::sum_weights` builds
`Fp2::from_u64(1u64 << (n_vars − 1))` and `w[0] = Fp2::from_u64(1u64 << n_vars)`
(`sumcheck.rs:223-224`), so `n_vars ≤ 63`, i.e. `m ≤ 62`. In release
builds the shift is masked rather than trapped, so it is silent, as the
draft says.

**C-N2 — it is in two places, and C4's assert must guard the type, not the
call site.** `CfsMask::round` computes `let scale = Fp2::from_u64(1u64 << (n − 1 − j))`
(`sumcheck.rs:266`), the same pattern with the same failure at
`n_vars ≥ 65` (`j = 0`). `sum_weights` binds first (63), so the draft's
number is right, but an assert placed only where `sum_weights` is called
from the seam (`zk_ffn_fresh_io.rs:241`) would leave `round` unguarded.
Put it in `CfsMask::random` / `CfsMask::len`, or debug-assert
`n_vars < 64` in both.

Two further ceilings nobody has to worry about but which should be in the
record because C4 is where they belong: `MASK_LOG_DOM = 12` fixes M's own
evaluation domain at 4,096 independent of the layer (`zk.rs:374`), and
`with_masks` asserts `log_n <= 16` (`zk.rs:2006`).

### 4.3 `MASK_ROWS` — two different quantities, both `2·something + k`

The draft uses two formulas and they are for different commitments.

**M (the layer's masking commitment): `2·slots + 4`.**
`let n_base = 2 * masks.len() + 4` (`zk.rs:435`) — two base rows per slot
(re, im) plus `b_re, b_im, u_re, u_im` (`:452-457`). With the two io slots
the layer goes from 6 to 8 slots, `16 → 20`, which the committed
`held.mc.encoded.len() == 20 * 4096` (`zk_ffn_fresh_io_tests.rs:52`) and
the wire's `mask_rows: 2 * specs.len() + 4` / `shape.mask_rows += 4`
(`zk_ffn_fresh_wire.rs:41`, `:232`) both pin. ✓ draft.

**The endpoint commitment: `MASK_ROWS = 5 = 2·sites + 3`.**
`commitment_rows = data_rows + MASK_ROWS` (`private_seam.rs:109-111`),
`MASK_ROWS = 5` (`:36`), with
`committed.mask_rows = [first_mask, first_mask + 1]` and
`prox_mask_row = Some(first_mask + 2)` (`:216-217`). The generalisation
`2·sites + 3` (C4) is **sound and slightly generous**, and the reason is
not the one the draft's §1.1 row table gives.

**C-C11.** The draft's table (lines 118-121) reads "row 4: the proximity
mask row; rows 5, 6: two further uniform rows, used only by the proximity
combination". Row 5 is not spare: `check_opening_challenges` requires
`prox + 1 < rows` and `determinant(rho[prox], rho[prox+1]) ≠ 0`
(`zk_ffn_fresh_poc.rs:336-339`), so rows `(4, 5)` are the **proximity
pair** and H-prox is a statement about both. The true budget is
`2 (terminal pair) + 2 (proximity pair) + 1 slack = 5`, so the minimum
general form is `2·sites + 2` and C4's `2·sites + 3` keeps today's one row
of slack. Say that, so that a later reader does not economise the wrong
row. (The draft's own §5.1 H-prox paragraph uses the pair correctly —
`prox = 130`, `131 < 133` — so only the §1.1 table is loose.)

`assert_mask_sites` adds the other standing requirement, and it is
shape-free: every group's `rho` must be nonzero on at least one mask row
(`pcs.rs:885-887`), which the group's own `λ·e` provides, `λ = 0` being
refused by `check_opening_challenges` (`zk_ffn_fresh_poc.rs:331-335`).

## 5. The eleven pins and the four new ones, re-classified

I agree with the draft's classification of nine of the twelve rows. Three
move, and two of the four new pins have a weaker consequence than stated.

### 5.1 Hunting a security consequence in each CAPACITY pin

The draft calls **A2, A6, A8, A11** capacity (plus A5's numeric half). The
test the brief sets is: a length the attacker controls, an allocation
driven by an untrusted header, a frame parser that trusts a size field.

**A2 — witness plane lengths (`zk_ffn_fresh_poc.rs:123-144`).** Prover
side only: `check_witness` runs on the prover's own `V3Witness`, and no
verifier path reads it. The verifier's lengths come from `st`. **Capacity
confirmed.**

**A6 — `SeamSpec::new(context, 32, 16, …)` (`zk_ffn_fresh_io.rs:40-41`).**
`(rows, cols)` feed `len = rows.checked_mul(cols)` (`private_seam.rs:66`,
checked) and the refusal at `:67-72`, and they are hashed into
`spec.digest()` (`:119-133`), which is compared only prover-side
(`into_ffn_endpoint`, `:157`). The verifier's binding to the geometry runs
through the *absorbed* parameter literal (`:141-144`) and the policy's
`rows: 7, log_cols: 8` (`:58-68`) — i.e. through A4 and A7, not A6.
**Capacity confirmed, conditional on A7/C7 carrying the derived shape
into the absorbed policy.** If a general profile derived `(T, d)` from the
statement but left the policy's `rows`/`log_cols` unbound, a verifier
would accept an endpoint of a different geometry — the draft says this at
A7 and its C7 test row ("add a policy whose `rows`/`log_cols` differ from
the statement's derived shape") is the right one.

**A8 — `ENDPOINT_OPEN_BYTES` (`:15`, used at `:505-511`).** The defence
here is not the constant, it is the *order*: `Receipt::from_bytes` checks
`bytes.len() != encoded_len(st, weights)?` **before** the first read
(`:558-560`), and `encoded_len` is computed from `st` alone. Then
`Reader::hiding(1, 7)` (`:581`) reads fixed counts — 512-entry vectors,
256 columns, 7 rows, depth 11 — from `zk_ffn_fresh_wire.rs:389-400`, never
from the frame; `Reader::column` refuses `j >= 1 << depth` (`:366-370`)
and `Reader::fp` refuses non-canonical words (`:327-333`). **No
attacker-supplied length reaches an allocation. Capacity confirmed.**
A wrong closed form is a completeness bug (an honest frame is rejected),
not a vulnerability.

**A11 — `MAX_WIRE_BYTES = 32 MiB` (`zk_ffn_fresh_wire.rs:11`).** Confirmed
not absorbed anywhere (the io transcript absorbs `PROFILE`, `expected-IO`
and the parameter literal only, `:139-144`). Confirmed that one Mistral
layer already exceeds it: **38,688,700 B** public
(`results/hashline_hostwall_r4.log:291`, the `PASS-V3 ACCEPT: 1 x 512
(d 4096 f 14336)` line) and **40,186,228 B** private
(`ZK60_CLAUDE_GPU.md:261`), against `33,554,432`. Both draft citations are
exact.

**But A11 is the one capacity pin with a live security job, and the
draft's C2 must keep it.** `encoded_len` is what stands between a
caller-supplied statement and `Vec::with_capacity(encoded_len(st, …)?)`
(`zk_ffn_fresh_io.rs:521`). Today the tiny `preflight` makes that moot.
Once A1 is relaxed, the domain is `Statement::check` → `Layout::check`,
which permits `t_rows, d, f ≤ 2^24` (`statement.rs:45`, `:132-146`):
`a_len` reaches ~`10·2^48` words and the derived frame length ~`2^48`
bytes. So:

> **Condition on C2.** The absolute ceiling must be evaluated *inside* the
> derived-length function and *before* any allocation — exactly where
> `MAX_WIRE_BYTES` sits now (`zk_ffn_fresh_io.rs:507-510`,
> `zk_ffn_fresh_wire.rs:69-71`) — and the exact-equality check
> (`:558-560`) stays the primary defence, with the ceiling second.
> `Shape::len` (`zk_ffn_fresh_wire.rs:47-70`) does its arithmetic in
> unchecked `usize`; `Layout::new`'s no-overflow argument
> (`statement.rs:41-45`) covers the *offsets*, not the frame length, so
> C2 owes either checked arithmetic or the same argument extended, plus a
> test at the `MAX_DIM` boundary.

With that, the draft's answer to the brief's question is **yes**: a
statement-derived exact length plus a ceiling refuses an oversized *and*
an undersized frame before allocating, because the equality is checked
first and every subsequent count is a constant. The precedent the draft
cites is real and there is a stronger one: `private_block/wire.rs:145` and
`private_attention/wire.rs:145` already do
`bytes.len() != encoded_len(lay) || bytes.len() > MAX_WIRE_BYTES`.

### 5.2 The PROTOCOL pins: does the change list leave the frozen bytes alone?

**A4** (the absorbed literal `T32/d16/f16/log_cols8/inv_rate8/Q256/two-private-seams`,
`:141-144`) and **A7** (the policy's `rows: 7, log_cols: 8`, `:58-68`).
The draft's standing condition (line 1084) is that `PROFILE`
(`:12`), the literal, `IoSpec::seams`'s `(32, 16)` (`:40-41`) and
`ExpectedIo::from_roots` stay unedited, with everything general in a new
entry pair (C8, `PROFILE …/3`). Checked against each change:

| change | touches a frozen path? | verdict |
|---|---|---|
| C1 (`t_rows` into `with_io`) | yes — `zk.rs:2354`, shared | **byte-neutral**: in the io branch `preflight` forces `w.t_rows == 32` and the caller passes 32 (`:168`), so the value is identical. Adding a refusal changes no bytes. ✓ |
| C2 (`MAX_WIRE_BYTES`) | the constant only; nowhere absorbed | ✓ |
| C3, C6, C7, C8, C9 | new module / new profile | ✓ |
| C4 (`SeamSpecG`) | explicitly "the existing `SeamSpec` is untouched" | ✓ as written |
| **C5** (endpoint takes `LayerParams`) | **yes, and it is specified as an in-place edit** | **✗ — C-B2** |
| C10 (offer endpoints to the device) | `private_seam.rs:215` already calls `pcs::commit_zk`; examples | ✓ (fresh randomness, no byte to move) — but see §5.4 |

**C-B2, in full.** C5's file list is
`private_seam.rs:28-36, :99-105, :164-181; zk_ffn_fresh_io.rs:115, :456`,
and its "moves a proof byte or a frozen digest?" cell says "**No** for
existing paths". That is false three times over:

* `LOG_COLS`, `INV_RATE`, `CHECKS` and `MASK_ROWS` are hashed into
  `SeamSpec::digest()` (`private_seam.rs:119-133`). The digest is absorbed
  by the standalone seam transcript (`tr.absorb(b"spec", &spec.digest())`,
  `:246`) and compared by `into_ffn_endpoint` (`:157`). Changing any of
  them changes every `SeamSpec`'s digest.
* `params()` (`:99-105`) determines the endpoint commitment itself, so it
  determines the root the `/2` policy carries and the `rows: 7,
  log_cols: 8` the `/2` verifier hard-codes (`zk_ffn_fresh_io.rs:58-68`)
  and `verify_zk` enforces (`pcs.rs:961`).
* `check_ntt` (`:164-181`) is a *deliberate narrowing* — "exact small
  table size keeps this opt-in prototype bounded and removes
  caller-selected/malformed public root tables from its verifier
  boundary" (`:165-166`). C5's test row asks that it "accepts the 2^16
  table"; done in place, that relaxes the tiny profile's boundary for no
  reason.

**Required:** C5 becomes additive — a `SeamSpecG` carrying the enclosing
`Params`, its own digest domain, and a `check_ntt_for(max_log)` — with
`SeamSpec`, its four constants, `params()`, `digest()` and `check_ntt`
byte-identical. C4 already has the right shape; C5 must copy it. The
*intent* of C5 (one source of truth for the general path) is right and I
support it.

### 5.3 Where I disagree with the draft's class

**C-C3 — A12 is a prover-side divergence, not a soundness bug.** The
draft (line 365) says "the committed slice offsets and the proven rows
would disagree, which is a soundness bug, not a size pin". The prover's
io branch builds its layout from the witness,
`ZkLayoutV3::with_io(&fresh_poc::statement(w), params)` (`zk.rs:2354`,
`statement(w)` uses `w.t_rows`), while the absorbed statement uses the
caller's `t_rows` (`zk.rs:2363`) and `assert!(t_rows <= w.t_rows)` at
`:2345` permits them to differ. But **the verifier derives its layout
wholly from `st`** — `ZkLayoutV3::with_io(st, params)` (`zk.rs:3493`) —
and rebuilds every claim, offset and row count from it, with the wire's
`Shape::validate` refusing a commitment whose `rows` differ
(`zk_ffn_fresh_wire.rs:77-82`). A prover who diverges produces a proof the
verifier rejects (or panics on its own side). Reclassify as **(a)
robustness / completeness**; keep C1 unchanged, including "fix it before
A1 is relaxed", and keep its test.

**C-C4 — P12's consequence is a refusal, not a silent mismatch.** The
draft (lines 378-388) says "move the FFN to `log_cols 14 / inv_rate 4` and
the verifier would check a `14/4/256` commitment the prover built at
`8/8/256`". It would not: `verify_zk` refuses
`cm.log_cols != params.log_cols` (`pcs.rs:959-962`), and an `inv_rate`
divergence changes `enc_cols`, the coset powers and the Merkle depth, so
the column identity and the paths fail. P12 is a real two-sources-of-truth
hazard worth fixing (C5's intent), but its class is **(a)/(b)**, not (c):
it costs a debugging afternoon, not a false accept.

**A5, A9, A10, A1, A3 — agreed as classed.** In particular A9's own
sentence, "a generalisation that replaces a constant with a value read
from the frame would be a real vulnerability" (line 362), is exactly
right and is the single most important line of §2.2.

### 5.4 The four new pins

**P12 — confirmed as a fact, downgraded in consequence.** See C-C4. The
two sources are `SeamSpec::params()` (`private_seam.rs:99-105`) and
`parameters().pcs_for(8)` (`zk_ffn_fresh_io.rs:456`); both are `8/8/256`
today.

**P13 — confirmed exactly.** `SeamSpec::new` refuses unless `rows` and
`cols` are each a power of two and `2 ≤ len ≤ 4096`
(`private_seam.rs:67-72`). At 125M the call would be
`SeamSpec::new(ctx, 512, 768, …)`: 768 is not a power of two **and**
`len = 393,216 > 4096`, so it fails twice. The draft's per-d-block remedy
is the right one and is the same object form 2 needs.

**P14 — confirmed in substance, corrected in statement.** §2.

**P15 — confirmed, and it is the pin C5 must not break.**
`check_ntt` requires `ntt.max_log == zk::MASK_LOG_DOM` (= 12),
13 roots, 2,048-entry twiddles and every root re-derived
(`private_seam.rs:164-181`), while `prepare_endpoints` builds
`NttTables::new(12)` (`zk_ffn_fresh_io.rs:115`) and the FFN uses
`NttTables::new(16)` (`:169`, `:278`). At `log_cols 14 / inv_rate 4` the
encoded domain is 65,536 and a 16-table is required. The draft's
"parameterise by the encoded domain, not delete" is right; C-B2 is about
*where*.

**One pin the draft does not list, and it belongs beside A10.** The
`private_seam` module's own frame and its `terminal_mask` /
`terminal_claim` are already written generally — `log_mask =
spec.log_len.min(LOG_COLS)` (`private_seam.rs:264`, `:274`) — whereas the
io adapter's `mask_value` hard-codes `rho[rho.len()-8..]` and `256`
(`zk_ffn_fresh_io.rs:201-203`). The general path should lift the
`private_seam` form rather than re-derive the io one.

## 6. Soundness figures (D15), recomputed

### 6.1 The formula, and which rate goes in it

`zkp-core/src/pcs.rs:17-19` states the code's own conservative bound:

> "with RS relative distance `delta = 1 - 1/inv_rate` the column test
> fails to catch a far matrix with probability `(1 - delta/3)^Q`; at
> inv_rate 4, Q = 256: `(3/4)^256 = 2^-106`."

For the **hiding** form the message is `n + Q`, not `n`: the row encodes
`f_data + Z_n·g_pad` on the coset, "the code is RS(n + Q, nn) on the
coset: distance `1 − (n + Q)/nn`" (`pcs.rs:520-527`), and
`ZK60_FABLE_SECURITY_OBLIGATIONS.md:377` says the same
("rows become RS(n + Q = 512, 2048), rate 1/4"). So `delta = 1 − (n+Q)/nn`
is the right input, and the draft uses it. Recomputed
(`recompute.py` §4):

| commitment | `n` | `nn` | `(n+Q)/nn` | per opening |
|---|---:|---:|---:|---:|
| tiny endpoint, `8 / 8 / 256` | 256 | 2,048 | exactly 1/4 | **`2^-106.250`** |
| A, H **and** the scaled endpoint, `14 / 4 / 256` | 16,384 | 65,536 | 0.253906 | **`2^-105.609`** |

Both of the draft's figures reproduce to three decimals
(`2^-106.25`, `2^-105.61`). ✓

**C-C12.** The draft (line 732) says this "reproduces D15's 'about
`2^-106`, from 256 opened columns at encoding rate 1/4'". It reproduces it
at the tiny geometry and **corrects** it at the deployment one:
`ZK60_FABLE_SECURITY_OBLIGATIONS.md:406` lists the deployment row's
per-opening column term as `2^-106.2`, reusing the exact-1/4 figure and
ignoring the `+Q`. At `14/4` the true value is `2^-105.61`, 0.64 bits
worse. The draft should say it is correcting its source, because the next
paragraph's arithmetic depends on which convention is in force.

### 6.2 The whole proof

D15's projection: commitment term `2^-98.7`, lookup term `2^-94.2`,
combining to "about 94 bits"
(`ZK60_DECISIONS.md:421-437`; `ZK60_FABLE_SECURITY_OBLIGATIONS.md:406-408`).
The io profile adds 2 openings per layer, 64 over a 32-layer pass.
Reproducing the draft's block exactly (`recompute.py` §5):

```
D15 as published      2^-98.700 + 2^-94.200                    = 2^-94.138
64 endpoint openings  2^6 · 2^-105.609                         = 2^-99.609
new commitment term   2^-98.700 + 2^-99.609                    = 2^-98.084
new whole proof       2^-98.084 + 2^-94.200                    = 2^-94.105
loss                                                             0.033 bits
```

**Every line of the draft's §4.2 block reproduces.** ✓

**C-C6 — but it mixes two conventions, and the mixture is exactly the
size of the effect being reported.** D15's `2^-98.7` *is*
`192 × 2^-106.25` (recomputed: `2^-98.665`) — i.e. it is built from the
tiny-geometry per-opening figure. The draft then adds its 64 new openings
at the corrected `2^-105.609` while leaving the existing 192 at the
uncorrected rate. Applied consistently:

```
192 existing openings at 2^-105.609                            = 2^-98.024
whole proof before endpoints  2^-98.024 + 2^-94.200            = 2^-94.102
whole proof after  endpoints  2^-97.609 + 2^-94.200            = 2^-94.070
loss                                                             0.031 bits
```

So the honest pair is **`2^-94.102 → 2^-94.070`**, not
`2^-94.138 → 2^-94.105`. The *loss* is the same to two decimals (0.03
bits) and no conclusion changes — but a page that corrects a per-opening
figure and then quotes a whole-proof figure built from the uncorrected one
invites the next reader to add them again. Either recompute the base or
label both numbers as D15's convention.

### 6.3 Which term dominates — the brief's question, answered

**The lookup term, by a factor of 10 to 16.**

| | commitment term | lookup term | ratio |
|---|---:|---:|---:|
| draft's convention, with endpoints | `2^-98.084` | `2^-94.2` | 0.068 |
| consistent convention, with endpoints | `2^-97.609` | `2^-94.2` | 0.094 |

On either convention the whole-proof figure sits within 0.10 bits of the
lookup term alone. **Confirmed: the endpoint openings barely matter.**
Concretely, adding 64 openings at `2^-105.6` costs 0.03 bits; *doubling*
the entire commitment budget would cost about 0.09 bits. Nothing about
the endpoint half of this construction is a soundness decision at model
scale — which is also why the draft's decision 9 (is the product's target
per-opening or whole-proof?) is the only ruling here that matters, and it
is Victor's, not the security owner's.

**C-C13.** Line 756 says "each of its ~256 openings is about `2^-105.6`".
Its own arithmetic uses 192 + 64 = **256** openings, so the figure is
right but the "~" is misplaced; and the 192 is D15's "about six openings
per layer" (`ZK60_DECISIONS.md:430`), which is itself a projection. Write
"192 existing (D15's projected six per layer over 32 layers) plus 64 new".

### 6.4 The seam's own error, and where it sits

Reproduced in §3.3: `2^-123.14` tiny, `2^-122.27` at 125M (draft says
`2^-122.4`, **C-C7**), `2^-121.98` at Mistral, `2^-115.98` for all 64
seams of a pass, `2^-122.000` for 64 `mu` terms. All of these are 20+
bits below the commitment term and 21+ below the lookup term, so the
draft's "the seam's soundness is field-limited … nowhere near the binding
term" stands. Two refusals inside the argument (`c = 0` at
`zk_ffn_fresh_poc.rs:221-233` via `:293`/`:387`; `e = 0` at `:336-338`/
`:392-394`) are hiding conditions and are shape-free, as the draft says —
both confirmed in the source. Add "per attempt" (§3.5).

## 7. Hiding at the larger evaluation domain

Reference: `ZK60_NATIVE_JOINT_VIEW.md` §2 and §9b on
`zk60-native-jointview`. **Nothing below establishes a privacy property**;
it checks whether three *hypotheses of a linear model* survive the change
of size.

### 7.1 H-pad at `log_cols 14` — and the assert the draft does not cite

H-pad is: "the `d` **distinct** sampled columns satisfy `d ≤ Q = 256`, the
nodes `x_j` are distinct and `x_j^256 − 1 ≠ 0`. The pad block is then a
Vandermonde of rank `d`" (§2.2). Four things to check at `nn = 65,536`:

1. **`d ≤ Q` still by construction.** `q_pad = num_col_checks`
   (`ZkOpts::standard`, `pcs.rs:542-543`), `commit_zk_owned_with` refuses
   `q_pad < num_col_checks` (`:670`), `verify_zk` refuses it again
   (`:963-965`), and exactly `num_col_checks` indices are drawn
   (`open_zk:928`, `verify_zk:990`). `challenge_indices` samples **with
   replacement** (`transcript.rs:119-131`, no dedup), so the distinct
   count is at most 256 at any `nn`. **`q_pad = Q = 256` is exactly
   sufficient at every width.** ✓
2. **Pads are per row, so more data rows do not dilute them.**
   `let pads = rng.fp_vec(rows * q)` (`pcs.rs:673`) and each row is
   encoded with its own `q` pads (`:679-681` → `encode_row_zk`). The
   128-data-row endpoint has 128 independent 256-pad blocks, not one
   shared block. ✓ This is the fact that makes the draft's "nothing here
   depends on 128 data rows rather than 2" true, and it is worth citing
   because it is the only thing standing between 2 and 128.
3. **`x_j^n − 1 ≠ 0` at the larger domain — checked, and asserted at
   runtime.** The draft argues it in prose. The code proves it:
   `coset_powers` builds `h^0 … h^{nn-1}` and then
   `assert!(x != Fp::ONE, "pcs zk: the coset generator has order dividing
   nn (the coset would meet the subgroup)")` (`pcs.rs:605-614`) — i.e.
   it checks `h^nn ≠ 1` on **every** commitment, at every `nn`. With
   `h = 7`, `7 ∉ G_nn`, so `7·G_nn ∩ G_nn = ∅`; since `n | nn` gives
   `G_n ⊆ G_nn`, every sampled `x_j = 7·ω_nn^j` satisfies `x_j^n ≠ 1`.
   `ZkOpts::standard`'s own comment says it (`pcs.rs:540-541`: "7 … a
   generator of `F_p^*`, so `7^nn != 1` for every `nn < p - 1` and
   `7 G_nn` is disjoint from `G_n`"). **The coset shift keeps the
   codeword domain disjoint from the message domain at `log_cols 14`
   exactly as at 8, and it is enforced, not assumed.** ✓ (C-N6 — the
   draft should cite `pcs.rs:612` here; it is a stronger citation than
   the one it uses.)
4. **The Vandermonde itself.** `encode_row_zk` subtracts `pad[i]` at
   coefficient `i` and adds it at `n + i` (`pcs.rs:618-635`), so the pad
   half of the column functional is `E_j[pad k] = (x_j^n − 1)·x_j^k` —
   `diag(x_j^n − 1)` times a Vandermonde in distinct nodes, full **row**
   rank for every `d ≤ q_pad` including `d = q_pad`
   (`ZK60_NATIVE_JOINT_VIEW.md` §9b). The structure is `n`-independent, so
   the argument carries verbatim. ✓

**The birthday arithmetic.** At `nn = 2,048`, 256 draws leave 231–247
distinct (measured, §2.3) and a surplus of 9–25. At `nn = 65,536`,
`E[distinct] = nn(1 − (1 − 1/nn)^256) = 255.50`, so the surplus is
typically 0–2 — the draft's figures are right. §9b measured the boundary
directly ("256 pads against **256 distinct** opened positions of the real
encoded domain … exact Gaussian rank **256 of 256**"), and the control
`q_pad = distinct − 1` discloses 3. **A zero margin is sufficient; the
widening removes a surplus that was never doing work** — the draft's
sentence is supported by its source. Its decision 7 ("still no" to
`q_pad = num_col_checks + 1`) follows.

### 7.2 H-pair and H-prox: does the data-row count enter?

**No, and I checked both statements word by word.**

* H-pair quantifies over *claims* and over the **non-data** rows: "every
  claim's row weights, restricted to the non-data rows, sit on exactly one
  adjacent reserved pair, that pair is used by no other claim, its two
  coefficients are an Fp-basis of Fp2, and no claim touches the proximity
  pair" (§2.2). The endpoint's one claim has `(e, e·U)` on
  `(data_rows, data_rows+1)`, `e ≠ 0` refused
  (`zk_ffn_fresh_io.rs:336-338`, `:392-394`); `{e, e·U}` is an Fp-basis of
  Fp2 for every `e ≠ 0`. Nothing names the data-row count. At the scaled
  endpoint the pair is `(128, 129)` and the claim is the same object.
* H-prox is `det(rho_prox[prox], rho_prox[prox+1]) ≠ 0` with
  `prox + 1 < rows` (`zk_ffn_fresh_poc.rs:336-339`): `131 < 133` ✓.
  Shape-free.

So the draft's headline 3 ("nothing in the hiding argument depends on the
plane length or on the number of data rows") survives, with the one
exception it names (claim sites, §3.4) and with two qualifications:

**C-N3 (repeated here because it is a hiding matter).** The "used by no
other claim" clause is enforced by nothing on the io path — `check_masks`
checks span, not disjointness, and `audit_claims` lives only in
`private_block/protocol.rs:89`. Under form 2 it holds by construction (one
claim per commitment per side; `a_io = [first, first+2]` are disjoint by
construction, `zk.rs:2059`). Under form 1 it would be one refactor away
from silently breaking, and the joint-view control for exactly that
configuration ("two claims sharing one mask pair") brute-force discloses
**8** (`ZK60_NATIVE_JOINT_VIEW.md` §6). This is the strongest argument in
the draft's own material for form 2 and for its decision 6, and the draft
does not make it.

**C-N4 — the reduction's leverage grows 64×.** The formula is
`disclosed = 256·k0 + (u-row term)` (`ZK60_NATIVE_JOINT_VIEW.md:125`),
where the 256 is `n`. The draft writes it as `n·k0` (line 883), correctly.
At the scaled endpoint `n = 16,384`, so a `k0` that slipped from 0 to 1
would disclose 16,384 Fp rather than 256. `k0 = 0` is still the expected
value and the draft's derivation of it is sound — `b = 0` because
`rho_prox` is uniform on the prox rows while `rho_g` is zero there, then
`a·(e, e·U) = 0` forces `a = 0` — but the *cost of being wrong* is 64×
larger, which is the real argument for making the capture gate (decision
6) binding rather than advisory.

**C-N5 — an undefined term is being carried forward.** `disclosed =
n·k0 + (u-row term)` is the only place `ZK60_NATIVE_JOINT_VIEW.md`
mentions a "u-row term"; the document never defines it, and the draft
reproduces the formula and then reasons only about `k0` (line 892: "so
`k0 = 0`, and the expected disclosed dimension … is 0"). The measured
endpoint rows do report 0, so the term is evidently 0 there, but the
draft's §5.2 derivation does not cover it. Say "`k0 = 0`, and the u-row
term is 0 on the measured endpoint captures and is assumed to remain so",
or get it defined.

### 7.3 The A side

The draft's §5.2 A-side paragraph is right as far as it goes: the seam
adds 2 claims and 2 groups, `rank(rho)` goes `2·5+2 = 12 → 2·7+2 = 16`,
and the new claim parts land on the two reserved pairs that `with_io`
allocates and `a_mask_rows()` reports (`zk.rs:2057-2062`, `:2090`), so
`k0` on A should stay 0. Two things to add:

* the io pairs *are* covered by the repaired rank refusal: `a_mask_rows()`
  extends with `self.a_io` pairs (`zk.rs:2090`) and `PendingV3::finish`
  runs `check_masks(&self.ac, …, &zl.a_mask_rows(), zl.a_prox, tr)` when
  `mr1` (`zk.rs:2320`). ✓ as the draft says at line 234.
* under form 2 the A-side claim's *data* weights spread over `nb_d`
  disjoint row ranges instead of one. That adds columns to the data
  rectangle, which §2.2's reduction quotients out, and it leaves the
  non-data restriction untouched. I could not make it matter. ✓

### 7.4 What the capture gate would have to do

The draft's §5.2 list (a capture emitter on the io path in the
`native-all-slots-v1` schema, a run at the target shape, no new analysis
cost) is right and I have nothing to add except that the gate is the
**only** mechanical check of H-pair anywhere on this path (C-N3), so
decision 6 should read "hard gate", not "recommend yes".

## 8. The conceptual claim (draft item 6) against D8, D11, D12, D13

The claim: *32 feed-forward layers are 64 caller-fixed endpoint roots, not
a chain; each carries the open D8/D11 obligation; therefore a
feed-forward-only private pass is a cost vehicle and must not be called
P1.* **I agree with all three parts.**

### 8.1 Is there any reading under which consecutive feed-forward layers
share an endpoint?

**No.** Three independent reasons:

1. **The transformer's own shape.** Between layer `k`'s feed-forward
   output and layer `k+1`'s feed-forward input sit the second residual
   add, the next block's attention, and the next block's norms. The
   repository's own obligation list says exactly this by naming the
   residual seam at *block* granularity and nowhere at feed-forward
   granularity: R26 is "**block 0's `xres2` equals block 1's `x_in`**"
   (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:235`), and R24/R25 are the seams
   *inside* one block (`xm8` ↔ the FFN's X plane, `z16c` ↔ the FFN's Z,
   `:219`, `:227`). There is no relation of the form "layer `k`'s `z16`
   equals layer `k+1`'s `x`" anywhere.
2. **The witness.** Each layer's `x` and `z16` are independent exported
   planes (`hashline/src/export_v3.rs`), and the 32-layer pass proves 32
   independent statements with 32 transcripts — there is no cross-layer
   relation in `zk.rs` at all.
3. **It would be forbidden even if it were true.** Sharing one root
   between two proofs is two openings of one hiding commitment, which is
   the configuration `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:5`
   reproduces natively — "**two native PCS openings at the actual
   seven-row, 256-column endpoint geometry recover all 512 data words**" —
   and which D12 rule 1 forbids outright ("No commitment is opened more
   than once, anywhere in a composed block").

**So the draft's correction of `ZK60_PRIVATE_FFN_COST_PROBE.md:884-885`
stands.** That page records, as a modelling choice, "in a chained 32-layer
proof, layer k's *output* endpoint is layer k+1's *input* endpoint, so a
chain needs **33 endpoint commitments, not 64** … a naive ×32
double-counts". It is wrong about a transformer; **64 is right, the naive
×32 is right**, and the draft's parenthetical (it would also have collided
with D12 rule 1) is right. This correction should be propagated to the
cost probe, not left only in the draft.

One thing to add, because it makes the point sharper: the chain is not
available at *block* granularity either. D11 records that "the block
profile's input/output roles are distinct, so its roots cannot be equated
directly across blocks" (`ZK60_DECISIONS.md:299-301`). So a 32-block MVP
faces the same 33-versus-64 question, unresolved, one level up.

### 8.2 Does the pass carry D8/D11, 64 times?

**Yes.** D8's standing obligation is that "a proof on the custom line must
be simulatable for endpoint roots the caller fixed, with the distinguisher
allowed to keep prior public history"
(`ZK60_DECISIONS.md:259-261`). The io profile's endpoints are exactly
that: `ExpectedIo` is built by the owner before proving
(`prepare_endpoints`, `zk_ffn_fresh_io.rs:109-120`) and handed to the
verifier out of band (`verify(st, weights, expected, receipt)`, `:412`);
the module's own doc says "the caller supplies the expected roots" and
"merely accepting roots supplied by the prover proves equality of those
planes, not that either plane belongs to the intended model execution"
(`private_seam.rs:5-7`). D8's proposed closure by two programmed points is
"**retracted for any root with a prior public opening**" (`:271-272`), and
D11 adds that one-use ownership does not reduce the experiment to unopened
roots because "an ordinary authentication path or root-child hash query
can precede the sole accepted `finish`" (`:286-288`). Widening multiplies
instances and touches none of it. ✓ The draft's §5.3 and §6 state this
correctly and claim nothing.

### 8.3 D13 — does "blocks" permit a feed-forward-only MVP?

The ruling, quoted in full from `ZK60_DECISIONS.md:500-517`:

> **"Ruling (Victor, Telegram, 2026-09-19 11:50): the hidden transformer
> blocks are enough for the first MVP; generating a token is the next
> milestone."** In plain words: the first MVP is a private proof that the
> **blocks** of a model were computed correctly on hidden inputs, with
> hidden outputs. It does not have to go all the way to an emitted word —
> **the embedding, the final norm, the output head and the token selection
> are the milestone after.** … Why this was the moment: **the target
> contract's clock covers only the feed-forward blocks** …

**My reading: "blocks" means complete transformer blocks, and a
feed-forward-only statement is not the MVP.** The ruling's own list of
what moves to the next milestone is embedding, final norm, output head,
token selection — **attention is conspicuously not on it**, and a ruling
that meant "feed-forward only" would have had to drop attention there. And
"block" is a defined term in this register: D12 fixes it as "one proof
under one transcript with exactly two external endpoints: its hidden input
`x_in` and its hidden output `xres2`", built from attention followed by
the feed-forward part with `xres1`, `nm` and `z16` hidden inside
(`ZK60_DECISIONS.md:317-330`). A 32-layer feed-forward-only pass is 32
proofs, 32 transcripts and 64 external endpoints — the draft's
"**It is not a block and must not be called one**" is right.

**The one sentence that could be misread, and the draft handles it well.**
"The target contract's clock covers only the feed-forward blocks" is
given as a *reason the ruling could be made now*, not as a definition of
the deliverable. The draft's formulation — "*the feed-forward pass is what
we speed up and measure; the composed block is what we claim privacy
for*" (line 1062) — is the correct reconciliation and I would make it
binding wording.

### 8.4 D12's two conditions that bite the statement

The draft's §6 closing bullets are both correct and both checked:

* **Rule 4.** "The feed-forward prover proves **no range on its own
  input**" is D12's own verified code fact
  (`ZK60_DECISIONS.md:332-336`, "verified in `hashline/src/layer.rs`: the
  lookup list covers the activation, the two int16 planes and the output,
  never the input plane"), and `multiplicities_zk_v3` bears it out — the
  histograms cover `g8`, `u16v`/`h16`/`z16` and the four remainder
  columns, never `w.x` (`zk.rs:2178-2200`). With a **hidden** input the
  statement admits an out-of-class input plane. ✓
* **Rule 5.** `IoSpec`'s `input_scale` / `output_scale` are absorbed
  through `expected.to_bytes()` (`zk_ffn_fresh_io.rs:76-85`, `:140`) and
  are checked for range only (`-31..=31`, `private_seam.rs:73-75`); the
  module says so itself ("range/representation facts are owed by the
  enclosing arguments, even though their declared scale is
  transcript-bound", `private_seam.rs:41-42`). ✓

### 8.5 Decision 4 of the draft

"Does a 32-layer feed-forward-only pass with hiding endpoints get to be
described as P1? *Recommend no.*" **Concur, and I would strengthen the
reason.** It is not only that D8/D11 is open. Under D1 a component that
leaves part of the hidden set unprotected is not P1 either, and at
`nb_d > 1` a mechanically widened pass would leave `(nb_d − 1)/nb_d` of
every hidden plane tied to no root at all (§2.4). The honest label the
draft proposes — "feed-forward blocks only, endpoints caller-fixed,
D8/D11 open" — should also carry "and, until C6 lands, only at widths
where `d` is a power of two ≤ 4096".

## 9. The cost figures: what is counted, what is measured, what is a guess

### 9.1 The counted ones, recomputed

`results/zk60_private_endpoints_check/recompute.py` rebuilds the layout
from `statement.rs:139-179`, the opening size from
`OpeningZk::size_bytes`'s own shape (`pcs.rs:576-580`) and the per-layer
delta from the five objects the draft lists. Output in `recompute.out`.

**Everything in the draft's §1.6, §3.2, §3.3 and §3.5 reproduces
exactly**, including the parts I expected to have to argue with:

| draft figure | line | my value | ✓/✗ |
|---|---|---|---|
| tiny A/H/W data rows 20 / 16 / 3; A 702, H 1326 with io | 302-314 | same (and the committed asserts at `zk_ffn_fresh_io_tests.rs:41,52,77,78,83`) | ✓ |
| 125M `nb_d=3`, `log_db=8`, `nb_f=1`, `log_fb=11`; A data 520 | 503 | same (and `statement.rs:232`) | ✓ |
| Mistral `log_t 9, log_db 12, nb_d 1, log_fb 11, nb_f 7, log_a_min 20, log_n 14` | 471 | same | ✓ |
| Mistral A 3,520 data / W 10,752 / H 2,944 | 320-321 | same | ✓ |
| endpoint rows 133 (Mistral) / 29 (125M form 2) / 33 (form 1) | 481, 555 | same | ✓ |
| endpoint opening 946,176 B (Mistral) / 733,184 B (125M) | 492, 559 | same | ✓ |
| `8/8` Mistral endpoint = 16.1 MiB; 8,197 rows; 134.3 MB encoded | 449-454 | 16,904,192 B = 16.121 MiB; 8,197; 134,299,648 B | ✓ |
| per-layer delta 2,443,456 B = 2.33 MiB; 274 rows | 624 | same | ✓ |
| 6.08% of 40,174,324 B; 266/3,669 = 7.25%; 274/17,451 = 1.57% | 626-630 | 6.082% / 7.249% / 1.570% | ✓ |
| 32-layer +78.2 MB, +8,768 rows | 632-633 | 78,190,592 B; 8,768 | ✓ |
| 125M form 2 = 2,017,088 B = 1.92 MiB = +27.4% | 546, 1135 | 2,017,088 B, 1.9236 MiB, 27.39% | ✓ |
| 125M form 1 = 4.01 MiB = +57.0%, M base 28, A groups 11 | 519 | 4,199,872 B = 4.005 MiB, 57.04% | ✓ |
| "a 125M probe would overstate them by 4.5×" | 565 | 27.39/6.08 = 4.50 | ✓ |
| frame constants 131,072 / 544 / 263,272 / 112 | 272-275 | same | ✓ |
| Mistral sweep: optimum `log_cols` 13 at 0.895 MiB, within 0.8% of 14 | 457 | 0.8945 vs 0.9023 MiB, 0.87% | ✓ |

That the form-1 figure reproduces to the byte (4,199,872) is the best
evidence I have that the draft's counting is careful rather than lucky.

**Three counted figures do not reproduce.**

**C-C5 — the 125M `log_cols` sweep.** Line 458: "At 125M the optimum is 12
(0.59 MiB) against 1.22 MiB at 14; matching the layer costs ~0.6 MiB per
endpoint there." My sweep over the same object (plane `3·2^17`,
`inv_rate 4`, `Q = 256`, `MASK_ROWS = 5`, 256 checks, one group):

| `log_cols` | rows | depth | bytes | MiB |
|---:|---:|---:|---:|---:|
| 11 | 197 | 13 | 593,920 | 0.566 |
| **12** | 101 | 14 | **471,040** | **0.449** |
| 13 | 53 | 15 | 512,000 | 0.488 |
| 14 | 29 | 16 | 733,184 | 0.699 |

The optimum is at 12 as the draft says, but at **0.449 MiB**, against
**0.699 MiB** at 14 — so matching the layer costs **0.25 MiB per
endpoint** (0.50 MiB for the pair), not 0.6. I cannot reconstruct 0.59 /
1.22 from any variant I tried (pair, `inv_rate 8`, form 1 groups). The
recommendation is unaffected — the draft's decision 1 rests on P12 and on
the Mistral figures, where 14 is within 0.9% of the optimum — but the
125M sentence must be corrected. Note also the tiny shape for the record:
there `8/8` (0.125 MiB) beats every `14/4` option, so decision 1 is a
*scaled-path* recommendation, which is how the draft's C5 scopes it.

**C-C8 — the transient memory unit.** Line 658: "`3 × 2^21 × 16 B =
100.7 MiB`". `3 × 2,097,152 × 16 = 100,663,296 B` = **96.0 MiB** =
100.7 M**B**. The draft mixes MB and MiB in one line; elsewhere (17.4 MB /
69.7 MB encoded, line 483) it uses decimal MB consistently and correctly.

**C-C9 — the pass total.** Line 632: "+78.2 MB of proof (1.20 GiB →
1.28 GiB)". `1,285,578,368 + 78,190,592 = 1,363,768,960 B` = **1.270
GiB**, from 1.197 GiB. Write 1.20 → 1.27 GiB.

Two figures I could not check and flag as such: the draft's "A groups
5 → 7" at Mistral (line 489) takes the base 5 from the tiny wire constant
(`zk_ffn_fresh_wire.rs:43`), and the number of FFN column-weight groups at
a different shape is not obviously 5. The **delta** (+2, one new group per
side, because each side's `rho` tail is fresh) is what the byte count
uses and that is right at every width. Likewise the Mistral A row total
3,665 depends on the 8B statement's four remainder-table sizes
(`rem_rows(sh)`, `statement.rs:50-52`), which I did not obtain; the
arithmetic is consistent with four one-row tables and reproduces the mr1
lane's measured 125M deltas, so I have no reason to doubt it.

### 9.2 Which seconds rest on a measured phase split, and which on a guess

The brief's question. The draft's `[MODEL]` total is **+0.15 s on a
3.453 s Mistral layer, +4.3%**, and **+4.8 s over a 32-layer pass**
(lines 661-663). Its four components are not of one kind:

| term | draft's value | what it actually rests on |
|---|---:|---|
| 1. two endpoint commitments | +0.048 s | **measured phase line, transferred.** `commit A` = 1.278 s over 12 layers × 585 rows at 125M (`ZK60_FSP_MR1_PROGRESS.md` stage 4 GPU table, confirmed at its line 416; A rows 520/559/585 at line 394) → 1.8205e-4 s/row, × 266 rows. The per-row transfer is legitimate: 125M and Mistral both run `n = 16,384` (`log_n = min(14, log_a_min)`), so a row is the same width. The draft's own caveat is right and material: two extra Merkle trees of 65,536 leaves each are **not** row-proportional, so this term is a floor. |
| 2. the two seam sumchecks | **+0.1 s, ±2×** | **a guess.** No phase line for a 2^21 host sumcheck exists anywhere in the repository, and none is cited; the figure is `6 × 2^21` Fp2 multiply-adds divided by an unnamed throughput. This is **two thirds of the +0.15 s headline**, and its own stated band (±2×) spans +0.10 s to +0.25 s, i.e. **+2.9% to +7.2%** rather than +4.3%. It is also the only large **host** arithmetic in a GPU layer, which is the regime where this project's estimates have moved most. |
| 3. two extra `open_zk` passes | "small" | **qualitative**, leaning on an aggregate (`pcs openings` 0.361 s over 12 layers at 125M, `ZK60_FSP_MR1_PROGRESS.md:425`). Not costed at all. |
| 4. transient memory | 96 MiB/argument | **counted** (C-C8 on the unit). |

**So: one of four is measured-derived, one is a pure model that dominates
the total, one is not costed, one is arithmetic.** The draft is honest
about this in its labels and in its "this is the number most likely to
move" (line 635), and its §0 warning — that three counted speed estimates
in this project shrank three- to seven-fold when measured the same day —
applies most sharply to term 2. The right way to quote the headline is
**"+0.10 to +0.25 s per Mistral layer, dominated by an unmeasured host
sumcheck"**, and the run that settles it is the draft's own C9 (the three
new phase lines) inside rung R5.

The **rows and bytes need no quiesced box** and are exact — the draft says
so and the mr1 lane's 30 runs under load producing identical rows and
bytes supports it. Only the seconds need the quiesced box, and the
standing rule (`CLAUDE.md`: the Mac's multi-week training pollutes timing
ladders) applies to them.

### 9.3 The acceptance gate

The draft's §7 gate (lines 1117-1145) is well-formed and I would add
nothing except two items and one correction.

**C-C10 — the C6 tamper-test sentence is wrong on either reading.**
Line 1101: "tamper one word in block 0, then block 1, then block 2, and
require rejection in all three. **A naive widening passes 1 and 2.**" A
`tdb`-widening rejects only the block-0 tamper and **accepts** the block-1
and block-2 tampers. Rewrite: "a `tdb`-widening rejects the block-0 tamper
and *accepts* the other two — which is the whole of P14". Note also that
the existing tiny negative would not have caught it: `wrong_plane`
perturbs position 271 (`zk_ffn_fresh_io_tests.rs:111-114`), inside block 0.

**Two additions.** (i) The gate should include a *negative* on the
endpoint's data region — a `SeamSpecG` whose `data_rows·n != nb_d·tdb` is
refused at construction (§3.6, condition 3). (ii) Gate item 6 (the
joint-view capture) should be worded as a hard gate, per §7.4 and C-N3.

## 10. What I did not check

* **I ran nothing.** No build, no cargo, no test, no proof, no benchmark,
  no GPU, no git write. Every figure here is arithmetic over the source
  or a citation to a measurement someone else took.
* **Bodies I read only in part.** I read `sumcheck::prove` and
  `sumcheck::verify` in full (`sumcheck.rs:48-131`, `:135-160`),
  `masked_prove` / `extension` / `extension_round` / `CfsMask` in full,
  `commit_zk_owned_with`, `encode_row_zk`, `coset_powers`,
  `zpart_weights`, `group_zclaims`, `zk_rhos`, `assert_mask_sites`,
  `open_zk` and the head of `verify_zk`. I did **not** read
  `mask_open` / `mask_verify` (`zk.rs:512`, `:552`) or the CFS
  combined-weights path, the Merkle implementation, the GPU backend, or
  `Transcript::challenge_fp2`'s internals beyond `challenge_indices`.
  A size assumption inside `mask_verify` would be missed here as in the
  draft.
* **`zkp-core/src/mle.rs` is uncommitted in Codex's live tree.**
  `eq_table_msb` and `eq_point` are on the seam's path and I read them
  only through their call sites; the working copy may be mid-edit, and I
  did not diff it. If the draft's §4.1 Schwartz–Zippel argument depends
  on `eq_table_msb`'s exact convention, that is unverified here.
* **The 8B statement's shifts**, hence the exact Mistral A row total
  (§9.1), and the base A group count at model scale.
* **D15's underlying projection** (`2^-98.7` commitment, `2^-94.2`
  lookup): I recomputed the *combination* and the per-opening inputs, not
  the lookup term or the six-openings-per-layer count, which
  `ZK60_FABLE_SECURITY_OBLIGATIONS.md:406-408` labels a PROJECTION.
* **Form 2 is still paper.** My attack on it is analytic. There is no
  code, no test and no receipt; §3 says what would have to be true, not
  that it is.
* **Nothing about the hash layer**, the adaptive lift (U-3), the
  PCS↔CFS nonlinear link, integer-range side information, timing, or the
  `ZkRng` PRG assumption — all listed as open by the draft's §5.3 and all
  untouched here.
* **I did not price the alternative** the draft also declines to price
  (leaving the endpoints tiny and reaching P1 through the composed block).
* **I did not re-verify the mr1 lane's measurements**, only that the
  cited lines say what the draft says they say
  (`ZK60_FSP_MR1_PROGRESS.md:394`, `:416`, `:425`;
  `ZK60_CLAUDE_GPU.md:261`; `results/hashline_hostwall_r4.log:291`).

## ERRATA AND CONDITIONS FOR ACCEPTANCE

One numbered, de-duplicated table for the security owner. **D** =
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` (1,286 lines). E-1 and E-2 are
BLOCKING; E-3 … E-15 are CORRECTIONS; E-16 … E-19 are the four conditions
on C6 and C2 that are not errors in the draft but are missing from it and
must travel with the change list. Notes that carry no required change are
left in the body.

| # | Rank | Draft line | Source (`file:line`) | What must change, and to what |
|---|---|---|---|---|
| **E-1** | **BLOCKING** | D §0 headline 4 line 59; §2.3 P14 lines 406-409; decision 2 line 1163; §4.3 item 1 lines 779-785 | `zkp-core/src/ffn_v3/statement.rs:139`, `:153-156`; committed `:230-232` | **"Mistral has `nb_d = 1` and is unaffected" must not stand as the exemption.** `nb_d = d / 2^min(trailing_zeros(d), 12)`, so `nb_d = 1` **iff `d` is a power of two and `d ≤ 4096`**: 4096 → 1, but 5120 → 5, 6144 → 3, 8192 → 2, 12288 → 3, 16384 → 4, 2560 → 5, 3072 → 3, 768 → 3. As written the draft licenses a mechanical widening at four real model widths that is exactly the unsound one. Replace every "Mistral / model scale is unaffected" with the rule, and state that **C6 is unconditional for any general entry point**, not an option the 8B width happens to avoid. §8.2 item 7 already says this correctly; §0, §2.3 and decision 2 must match it. |
| **E-2** | **BLOCKING** | D C5, line 1100 (change, files and the "moves a proof byte? **No** for existing paths" cell; its `check_ntt` test) | `private_seam.rs:119-133` (`digest()` hashes `LOG_COLS/INV_RATE/CHECKS/MASK_ROWS`), `:246` (absorbed), `:157` (compared), `:99-105` (`params()` fixes the root), `:164-181` + `:165-166` (`check_ntt`'s stated purpose); `zk_ffn_fresh_io.rs:58-68`; `zkp-core/src/pcs.rs:961` | **C5 as specified edits the frozen tiny path and relaxes its verifier boundary; its "no byte moves" cell is false.** The four module constants are hashed into every `SeamSpec::digest()`, which the standalone seam transcript absorbs and `into_ffn_endpoint` compares; `params()` determines the endpoint root the `/2` policy carries and the `rows: 7, log_cols: 8` the `/2` verifier hard-codes; widening `check_ntt` in place discards a deliberate narrowing. Required: C5 becomes **additive** — a `SeamSpecG` carrying the enclosing `Params` with its own digest domain, plus `check_ntt_for(max_log)` — leaving `SeamSpec`, its constants, `params()`, `digest()` and `check_ntt` byte-identical, exactly as C4 is written. C5's intent (one source of truth on the general path) is right and is supported. |
| E-3 | CORRECTION | D line 782 (§4.3 item 1) | `statement.rs:159-163` (one running `off`); offsets recomputed in `results/zk60_private_endpoints_check/recompute.out` §2 | "Mechanically widening the 512 to `T·d` would read past `x[0]` into `z[0]` and `rd[0]`" — **both halves wrong.** `x = vecn(nb_d, tdb)` allocates the blocks contiguously, so `[x[0], x[0] + T·d)` is **exactly** the input plane and ends where `z[0]` begins (at 125M: 7,340,032 → 7,733,248 = `z[0]`). It is the *round-up-to-`2^19`* variant that reaches `z[0]`, and even that stops at 7,864,320, short of `rd[0] = 8,126,464`. Strike the sentence. |
| E-4 | CORRECTION | D §2.3 P14 lines 400-413; §4.3 item 1; decision 2 | `pcs.rs:56-60` (`Slice.log_size`); `sumcheck.rs:54-57` (`assert!(n_total.is_power_of_two())`, `n_rounds = trailing_zeros`); `zk.rs:2172`; `sumcheck.rs:251`, `:264-273` | **Name which widening.** Three candidates behave differently: to `tdb` → **silently unsound** at every `nb_d > 1` (this is P14, and the CFS slot at `zk.rs:2172` is already `(log_t+log_db+1, 2)`, so nothing complains); to `T·d` → **sound wherever expressible**, i.e. whenever `nb_d` is a power of two (`d = 8192`), inexpressible otherwise; to `2^ceil(log2(T·d))` → loud failure that also puts a data coefficient on the endpoint's reserved mask pair. The headline must be "the single-slice form binds only its slice; the `tdb` form under-binds at every `nb_d > 1` and is the quiet one". |
| E-5 | CORRECTION | D §2.2 A12, line 365 ("which is a soundness bug") | prover `zk.rs:2354` + `:2345` + `:2363`; **verifier `zk.rs:3493`** (layout wholly from `st`); `zk_ffn_fresh_wire.rs:77-82` (`Shape::validate` refuses a row mismatch) | A12 is a **prover-side divergence, not a soundness bug**: the verifier derives its layout, every offset and every claim from `st` alone, so a witness with `w.t_rows != t_rows` yields a proof that is rejected (or a prover-side panic), never an accepted false statement. Reclassify (c) → (a) robustness/completeness. **Keep C1 unchanged**, including "fix it before A1 is relaxed" and its test. |
| E-6 | CORRECTION | D §2.3 P12, lines 378-388 ("the verifier would check a `14/4/256` commitment the prover built at `8/8/256`") | `zkp-core/src/pcs.rs:959-962` (`"pcs zk: log_cols mismatch"`); `enc_cols`/coset/depth divergence fails the column identity | P12's consequence is a **refusal**, not a silent geometry mismatch. It is a genuine two-sources-of-truth hazard (`private_seam.rs:99-105` vs `zk_ffn_fresh_io.rs:456`) worth fixing, but its class is (a)/(b), not (c). |
| E-7 | CORRECTION | D §3.1 line 458 | `recompute.out` §7/§7b (plane `3·2^17`, `inv_rate 4`, `Q 256`, `MASK_ROWS 5`, 256 checks, 1 group) | "At 125M the optimum is 12 (**0.59 MiB**) against **1.22 MiB** at 14; matching the layer costs **~0.6 MiB** per endpoint" → **0.449 MiB at 12, 0.699 MiB at 14, cost 0.25 MiB per endpoint** (0.50 MiB for the pair). The optimum is at 12 as stated; only the magnitudes are wrong. The Mistral sweep (13 at 0.8945 MiB vs 0.9023 at 14) reproduces and decision 1 is unaffected. |
| E-8 | CORRECTION | D §4.2 lines 744-749 and line 756 | `ZK60_FABLE_SECURITY_OBLIGATIONS.md:406-408`; `recompute.out` §5 | The whole-proof block **mixes two per-opening conventions**: D15's `2^-98.7` is `192 × 2^-106.25` (the tiny-geometry figure), while the 64 new openings are added at the corrected `2^-105.609`. Applied consistently the pair is **`2^-94.102 → 2^-94.070`**, not `2^-94.138 → 2^-94.105`. The loss is 0.03 bits either way and nothing downstream changes — but state which convention is in force, or recompute the base. |
| E-9 | CORRECTION | D §4.2 line 732 ("This reproduces D15's 'about `2^-106`'") | `ZK60_FABLE_SECURITY_OBLIGATIONS.md:377`, `:406`; `pcs.rs:520-527`; `recompute.out` §4 | At the deployment geometry the draft does not *reproduce* its source, it **corrects** it by 0.64 bits: §5's deployment row quotes `2^-106.2` (the exact-1/4 figure, ignoring the `+Q`), while `(n+Q)/nn = 16640/65536` gives `2^-105.609`. Say "corrects", and say so before the whole-proof arithmetic that depends on it. |
| E-10 | CORRECTION | D §4.1 table, line 703 | `recompute.out` §6, `53/|Fp2|`, `log2 53 = 5.728` | 125M block, `m = 17`: `2^-122.4` → **`2^-122.27`** (`2^-122.4` is the `m = 16` value). The `m = 9`, `m = 21` and 64-seam rows reproduce exactly. |
| E-11 | CORRECTION | D §3.5 item 4, line 658 | `3 × 2,097,152 × 16 = 100,663,296 B` | "`3 × 2^21 × 16 B = 100.7 MiB`" → **96.0 MiB** (= 100.7 M**B**). Elsewhere the page uses decimal MB correctly; this line mixes the units. |
| E-12 | CORRECTION | D §3.5, line 632 | `1,285,578,368 + 32 × 2,443,456 = 1,363,768,960` | "1.20 GiB → **1.28 GiB**" → **1.197 GiB → 1.270 GiB**. |
| E-13 | CORRECTION | D C6 test cell, line 1101 | `zk_ffn_fresh_io_tests.rs:111-114` (`wrong_plane` perturbs position 271, inside block 0) | "A naive widening **passes 1 and 2**" is unreadable and wrong on either reading. Rewrite: "a `tdb`-widening rejects the block-0 tamper and **accepts** the block-1 and block-2 tampers — which is the whole of P14"; add that the existing tiny negative would not have caught it, because 271 lies in block 0 at every `nb_d`. |
| E-14 | CORRECTION | D §1.1 row table, lines 118-121 | `zk_ffn_fresh_poc.rs:336-339` (`prox + 1 >= rows` and `det(rho[prox], rho[prox+1])`) | Endpoint row 5 is **not** a spare "further uniform row": rows `(4, 5)` are the **proximity pair** and H-prox is a statement about both. The real budget is 2 (terminal pair) + 2 (proximity pair) + 1 slack = 5, so the general minimum is `2·sites + 2` and C4's `2·sites + 3` keeps one row of slack. (D's own §5.1 H-prox paragraph uses the pair correctly; only the §1.1 table is loose.) |
| E-15 | CORRECTION | D §4.2 line 756; D §3.4 line 42 and line 579 | `ZK60_DECISIONS.md:430`; `zk.rs:2172` | Two wording fixes. (a) "each of its **~256** openings" — the arithmetic uses exactly 192 + 64; write "192 existing (D15's projected six per layer over 32 layers) plus 64 new". (b) `L = 2·log2 N + 4` reads `log2 N` as the **cube's** bit width `log_t + log_db`, not the plane's `log2(nb_d·tdb)`; identical at `nb_d = 1`, different under form 2. The §3.4 table labels the row "125M **block**" correctly; the prose at line 42 does not. |
| E-16 | CONDITION on C6 | D §3.3 line 522 ("After both roots are absorbed, draw `mu`") | `zk_ffn_fresh_io.rs:139-140`, `:291-292`, `:385-386`; **`zk.rs:2542`** (A's root), `:2545` (M) | "After both roots are absorbed" is satisfied at transcript construction and is not the binding condition. C6 must say: **`mu` is `nb_d` fresh transcript draws taken at the point `tau` is drawn (`:292`), hence after `expected-IO` (`:140`), after `absorb_com(A)` (`zk.rs:2542`) and after `M` (`:2545`); the verifier draws it at the identical point (`:386`); it is never re-derived from `rho` or the terminals; and it is NOT refused on zero** (unlike `c` and `e`), because a zero `mu_c` is already inside the `1/|Fp2|` term and a refusal-plus-retry would be the resampling the profile forbids. |
| E-17 | CONDITION on C6 | D §3.3 lines 521-541 and P13 line 396 (the padding question is answered only implicitly) | `private_seam.rs:106-111`, `:209-213`, `:216`; `sumcheck.rs:54-57`; §2.1 fact 3 | C6 must **pin the endpoint's committed data region to exactly `nb_d · tdb`, with `n \| tdb`, and assert `data_rows·n == nb_d·tdb`** — no padded row between the plane and `mask_rows`. Under form 2 as intended there are no unused hypercube positions on either side (each table is exactly `2^(log_t+log_db)`; a non-power-of-two cube is inexpressible, `sumcheck.rs:54`). If a general `SeamSpecG` instead kept the power-of-two axis rule by rounding the plane up, the rounded region is **zero** on the endpoint side (`:209-210`) against real data on the A side (completeness break) **and** the slice reaches from `data_rows·n` into the reserved pair at `:216` — a **hiding** break that `check_masks` would not catch, because the pair's coefficients would still span Fp2. Add a negative test that a `SeamSpecG` with `data_rows·n != nb_d·tdb` is refused at construction. |
| E-18 | CONDITION on C6 / C4 / decision 6 | D §5.1 lines 864-871; decision 6 line 1187 | `zk_ffn_fresh_poc.rs:253-321` (`check_masks` checks span, not disjointness, and never checks the prox rows); **`hashline/src/private_block/protocol.rs:89`** (`audit_claims`, the only implementation) with its negative `private_block/tests.rs:325`; `ZK60_NATIVE_JOINT_VIEW.md` §6 (two claims sharing one pair → disclosed **8**) | H-pair's "**that pair is used by no other claim**" is enforced **nowhere on the io path**, at any width. Under form 2 it holds by construction (one claim per commitment per side; `a_io = [first, first+2]`, `zk.rs:2059`); under form 1 one refactor would break it silently into a measured 8-dimension disclosure. C6/C4 must either port `audit_claims` to the io path or state that form 1 is forbidden — and decision 6 becomes a **hard gate**, not a recommendation, since the joint-view capture is the only mechanical check of H-pair that exists. |
| E-19 | CONDITION on C2 / C7 / decision 1 | D C2 line 1097; C7 line 1102; decision 1 lines 1151-1156; A10 line 363 | `zk_ffn_fresh_io.rs:507-510`, `:521`, `:558-560`; `zk_ffn_fresh_wire.rs:47-70` (unchecked `usize`), `:389-400`; `statement.rs:41-45`, `:45`, `:132-146`; `zk.rs:2005`; `zk_ffn_fresh_poc.rs:268` | Four things the change list needs. (a) **C2's absolute ceiling is load-bearing**: it must be evaluated inside the derived-length function and before any allocation — where `MAX_WIRE_BYTES` sits now — with the exact-equality check (`:558-560`) staying the primary defence; once A1 is relaxed the domain is `Layout::check`'s `2^24` per dimension, and `Shape::len` does unchecked `usize` arithmetic whose no-overflow argument (`statement.rs:41-45`) covers offsets, not frame lengths. Owe checked arithmetic or the extended argument, plus a `MAX_DIM`-boundary test. (b) **Decision 1 must clamp with `pcs_for(log_t + log_db)`**, not the raw `log_cols`: a sub-row data slice (`log_size < log_cols`) is refused outright by `check_masks` (`zk_ffn_fresh_poc.rs:268`). (c) **A's and the endpoint's `log_n` can differ** (whenever `log_fb < log_db` and the minimum falls below `log_cols`; no real model width reaches it, but `claim()` and `mask_value` are shared between the two sites and hard-code one width) — C7 must parameterise them per commitment. (d) **C4's `1u64 <<` assert must guard the type, not one call site**: the overflow is in `CfsMask::sum_weights` (`sumcheck.rs:223-224`, binds at `n_vars ≤ 63`) **and** in `CfsMask::round` (`:266`, binds at 64); put it in `CfsMask::random`/`len`. |

**What is accepted.** Subject to E-1 … E-19: P14 is a real soundness gap
in a mechanical widening and C6 is the right fix; form 2 over form 1;
the endpoint at the enclosing `LayerParams` on the general path only; a
statement-derived wire bound with a ceiling; `q_pad = num_col_checks`
unchanged; the joint-view capture as a gate; and "a feed-forward-only
private pass is a cost vehicle, not P1, with D8/D11 open". The slot
arithmetic, the whole-proof soundness conclusion (the lookup term
dominates; the endpoints cost 0.03 bits), the hiding conclusion at the
larger domain, and every counted row and byte except the three in E-7,
E-11 and E-12 reproduce from source.
