# ZK60 — adversarial CODE review of the private block module

**Status: COMPLETE — 0 BLOCKING, 2 DEFECTS, 8 HARDENING, 8 NOTES. Every plane
the new half commits is pinned in the code; every relation equals the integer
kernel's, sign by sign; the public-statement digest covers every public word the
argument reads, including the 256 activation words (E-2 discharged by the
`[i16; 256]` type); the Fiat–Shamir order has no difference from T1 §D / T2 §F;
the accepted attention module is byte-identical to `zk60-attention-compile`.
I could not construct a false witness the verifier accepts. The two defects are
a wrong index comment and an unreachable shift underflow. The real gap is
evidence, not code: the whole `norm_m` relation family has no verifier-side
tamper test, and the tools of disposition condition 4 have not been run on the
Rust.**

| | |
|---|---|
| Under review | `hashline/src/private_block.rs`, `hashline/src/private_block/{layout,witness,argument,protocol,wire,parity,refusals,tamper,tests}.rs`, `hashline/examples/zk60_private_block.rs`, `hashline/tests/zk60_private_block.rs` |
| Worktree / branch | `/home/victor/wt-zk60-private-block`, `zk60-private-block` @ `a5e8010` |
| Design it must implement | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` §3, `…_CONSTRUCTION.md` (T1), `…_CONSTRUCTION_TIER2.md` (T2), `…_TIER2_CHECK.md` §2.3 |
| Integer reference | `private-block-kernel/src/lib.rs` |
| Reviewer | independent Opus agent, adversarial brief, read-only, 2026-09-19 |

## 0. Scope, method, and what a verdict here is not

**Method.** Nothing was taken on trust. Every file of `hashline/src/private_block/`
was read in full. Every changed and added line of `argument.rs`, `protocol.rs`,
`layout.rs` and `private_block.rs` was isolated with `diff` against the accepted
attention module and read against the design; `witness.rs` was read in full for
completeness and kernel parity. Each of the five feed-forward relations and the
two Tier-1 relations (`norm_m`, residual 2) was re-derived from
`private-block-kernel/src/lib.rs` before the code's statement of it was read
back. Every table index in every new slot arm was counted by hand against the
order in which `B::push` appends, because an off-by-one in a table index is
exactly the kind of bug that an honest witness still satisfies at some indices
but not others — in fact here it would break the honest proof, and the arms I
checked are all consistent.

**No build, no run.** No `cargo`, no test, no proof, no git write. Nothing
outside this document was created or changed. The counts and the 2,816,472-byte
frame length below were recomputed by hand from `wire.rs`, not observed.

**What this is not.** This is a review of soundness, plane coverage, relation
fidelity and exposure in the code. **It establishes no privacy property of
anything.** The construction's own gate (a zero-witness preimage with the same
free dimension on captured receipts) is unmet and out of scope here, as
`…_DISPOSITION.md` §5 says. A "no false witness found" verdict in §10 is a
statement about what I could construct in one pass, not a soundness proof.

## 1. Findings, ranked

### BLOCKING

**None found.** Every plane the new half declares and commits is read by a term
with a challenge coefficient that is either refused when zero or random; every
new relation is the kernel's, sign by sign and constant by constant; the three
statement-digest gaps T2 worried about are closed; and I could not construct a
false witness the verifier accepts (§10). That is a negative result from one
adversarial pass, not a proof.

### DEFECT

**D-1 — the hand-written table-index comment in `SC_TZC` contradicts the code it
documents.** `argument.rs:556-558`:

```
// tables: 0 eq(tau), 1 eq(r_t), 2 eq(r_t2), 3 A_D, 4 A_DSQ,
// 5..14 A_LIMB's nine sub-slices, 14 A_DM, 15 A_DSQM,
// 16..25 A_LIMBM's nine sub-slices
```

The nine `A_LIMB` sub-slices occupy table indices **5..=13**, not `5..14`, and
`A_DM` is 14 — the comment gives 14 to both. The nine `A_LIMBM` sub-slices are
**16..=24**, not `16..25`; there is no table 25 (the slot has 25 tables, 0..=24).
The **code is right**: `l3(5)`, `l3(8)`, `l3(11)`, `v[14]`, `v[15]`, `l3(16)`,
`l3(19)`, `l3(22)` (`:574-576`) index exactly the right slices, and
`A_SITES[SC_TZC] = 22 = 2 + 9 + 2 + 9` (`layout.rs:512`) is consistent. But this
is the one arm in the module where table indices are written as literals rather
than captured from `B::push`'s return value, so a reader who trusts the comment
and inserts a table will mis-index silently — the honest proof would then fail,
but only after a debugging session.
*Fix:* correct the comment to `5..=13`, `14`, `15`, `16..=24`, or better, bind
the returns (`let i_d = b.a(A_D)?;` …) as every other arm does and drop the
literals.
*Test that would have caught it:* none can — it is a comment. The structural
alternative is to make `SC_TZC` use captured indices like `SC_DZC`'s `id`/`idm`,
after which the comment cannot drift.

**D-2 — `witness::requant` shift-underflows at `sh = 0`.** `witness.rs:54-57`:

```rust
fn requant(acc: i64, sh: u32) -> (i64, i64) {
    let y = (acc + (1i64 << (sh - 1))) >> sh;
```

With `sh: u32` and `sh == 0`, `sh - 1` underflows to `u32::MAX`; the shift then
panics in debug and is masked to a wrong value in release. It is **not reachable
today** — `quantize` is called only with 7, 7, 7, 7, 7, 6, 9, 7, 7, 14, 6
(`:219-223`, `:234`, `:296-297`, `:352`, `:370`, `:372`) and the up matmul
deliberately bypasses it (`:355-358`, the right call, and T2 §A.4's point). But
`SH_U = 0` is a shift *of this module's own calibration*, so the trap is one
constant away, and the same underflow is duplicated in `tamper.rs:67-70`.
T2-check T-N6 raised it against the accepted module's witness and it was carried
over unchanged.
*Fix:* `if sh == 0 { return (acc, 0); }` at the head of `requant`, or make the
parameter a `NonZeroU32`.
*Test that would have caught it:* a unit test `requant(v, 0) == (v, 0)`, or a
`quantize(&[1], 0, …)` case in `refusals.rs`.

### HARDENING

**H-1 — the whole `norm_m` relation family has no verifier-side tamper test.**
Neither `tamper.rs` (which is feed-forward only) nor
`tests.rs:144-176` touches `A_YM`, `A_DM`, `A_DSQM`, `A_LIMBM`, `A_MR0..3` or
`A_MS0..3` (verified by grep over both files: zero hits). So T1 §C.1's new
material — `c6`, `c7` (`argument.rs:722-723`), `SC_TZC`'s `mu[3..6]` and its
second host term (`:578`, `:581`), `SC_SSM` (`:546-551`) and `sym(A_YM)`
(`layout.rs:327`) — is covered only by "the honest proof verifies" and by
witness/kernel parity. Those two together would not catch a *vacuous* relation
(one batched under a coefficient that is never drawn, or a term whose plane is
read at the wrong site). I checked the batching indices by hand and they are
correct (§3), but the evidence should not rest on a reviewer's reading.
*Add:* `+1` on `A_YM[k]` with the feed-forward chain recomputed →
`Catch::Slot(SC_FZC)` or `Catch::Slot(SC_DZC)`; `+1` on `A_DM[t]` →
`Catch::Slot(SC_TZC)`; `+1` on `A_DSQM[t]` → `Catch::Slot(SC_TZC)`; a rotation
inside its window on one `A_MR0` limb → `Catch::Slot(SC_DZC)`; a `(+256, −1)`
limb shift on an `A_LIMBM` sub-plane → `Catch::LogUp`.

**H-2 — no tamper on `A_MACT`.** The activation histogram is a committed `A`
plane the prover chooses freely (`protocol.rs:303-311`). Zeroing it, or moving
one count, must fail the value-0 LogUp sum claim. Nothing tests that, and
`A_MACT` is the plane that carries E-22's other half.

**H-3 — E-22's actual scenario is not exercised.**
`an_activation_value_off_its_table_row_is_rejected` (`tamper.rs:204-218`) picks
the first index where `recompute_from_product` succeeds, which will in practice
be an index with `u16 ≠ 0`, where `f0` already constrains `a16` given `h16`. The
erratum's point is the index where **`u16 = 0`** and `f0` says nothing at all.
*Add:* `pick` an index with `w.planes[A_U16][k] == 0` and move `a16` there
(nothing downstream changes: `h16 = requant(0, 14) = 0` either way), expecting
`Catch::LogUp`. If the public synthetic fixture has no such index, the test
should say so in its message rather than silently testing the easy case.

**H-4 — `tests.rs`'s 18-case tamper loop accepts any error.**
`tests.rs:170-173` asserts only `got.is_err()`, and `prove_tampered`
(`:133-141`) propagates the **prover's** errors with `?`. A case that made the
prover refuse would pass the test while proving nothing about the verifier.
`tamper.rs`'s `Catch` matcher is the right standard (its `"slot {s} ["` prefix is
produced only at `argument.rs:321`, inside the `Side::Verify` arm, and `"H: "`
only at `protocol.rs:455`, so a prover-side error cannot satisfy it). Apply it to
these 18 too, in particular the new
`("residual 2 / output endpoint", A_X2[0] += 1)` case, which breaks `c8`, `c9`
and `SC_IO_OUT` at once.

**H-5 — `Catch::LogUp` is looser than its name.** `tamper.rs:52` matches
`err.starts_with("H: ")`, which is the whole `H` opening
(`protocol.rs:455`), covering every `H` evaluation claim as well as the value-0
sum claim. Four of the nine tamper tests rely on it. Tighten by having
`verify_inner` distinguish the sum claim, or at least assert that the same
tamper with the sum claim removed would *not* reject (not cheap), or state the
looseness in the test's comment.

**H-6 — an unset `Points` field degrades silently, not loudly.** `Points`
derives `Default` (`argument.rs:128-147`), so every point is an empty `Vec`. If a
future edit moved a slot before the one that publishes its point,
`b.eq(&empty, 0)` produces `Tab::Eq { point: [], start: 0 }`, and `table_of`
(`:201-205`) expands it to the all-ones table — the eq factor disappears and the
host term becomes a plain sum. Honest proofs would fail, so it is not a live
hole, but the failure mode is an arithmetic mismatch rather than a named error.
*Add:* a length check in `B::eq`, e.g. `if point.is_empty() { return Err(...) }`.

**H-7 — `mu` batching vectors are not `nonzero`-checked.** `nu` is
(`argument.rs:486-491`, used at `:555`, `:691`, `:745`, `:784`, `:824`) but `mu`
is not (`:554`, `:690`, `:744`, `:783`, `:823`, `:867`). A zero `mu_i` silently
drops one relation from the batch. Grinding a zero `Fp2` challenge costs ~2^128,
and the accepted component has the same shape, so this is not exploitable; a
one-line `nonzero(...)` on `mu` would remove the reasoning step entirely.

**H-8 — the transcript-order gate covers only the slot loop.** `acc.order`
records three coarse strings per slot (`argument.rs:269`, `:342`, `:349`) and
nothing about the six header absorbs, the three roots, `β/γ/α`, or the four
openings — exactly the limitation T1 §D:810-817 predicted and asked to be fixed
if the order is to be *enforced* at the granularity the design lists. Prover and
verifier run the same `argument()`, so they cannot diverge; but
`honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_transcript_order`
(`tests.rs:90-107`) proves less than its name suggests.

### NOTE

**N-1 — disposition condition 4 is not met by this commit.** The tools have not
been re-run on the real Rust (that work is in flight on the Python lane, which I
was told to ignore). Until then, the row/site/slot/group/lookup counts are
confirmed by the module's own asserts (`layout.rs:588-591`, `:701-749`,
`:754-781`), by the runtime group check (`protocol.rs:169-171`, `:396`, `:399`)
and by my hand recomputation (§2) — not by the committed inventory tool, and
`NOTE_EXPECT` is not updated.

**N-2 — T2 §G.2's two owed rank controls** (`A_H16` sharing `A_U16`'s pair;
`A_YM` sharing `A_Y`'s pair) are still not implemented anywhere.

**N-3 — seven of the sixteen `A_LIMB` / `A_LIMBM` sub-planes are unused.**
`rms_norm` fills sub-planes 0..=8 (`witness.rs:159-163`) and leaves 9..=15 zero;
`Dom::L`'s two byte lookups (`layout.rs:313-316`) range all 512 entries, and no
relation reads the unused ones. Sound (an unread plane constrains nothing), but
it puts 224 known-zero committed field elements per plane into `A`. Inherited
from the accepted component; the disclosed-dimension models are where this
belongs, not here.

**N-4 — `Layout::new()` panics rather than erroring** (`layout.rs:588-591`).
It is on the verifier's path (`protocol.rs:430`, `private_block.rs:449`, `:454`),
but it depends only on compile-time constants, so untrusted bytes cannot reach
it.

**N-5 — `compute_output` is `pub` and returns the secret `xres2`**
(`private_block.rs:390-392`). That is deliberate: the endpoint owner needs the
value to commit it. The doc comment says so, and the example drops it
immediately after `prepare_endpoints` (`examples/zk60_private_block.rs:42-44`)
and never prints it.

**N-6 — `FeedForwardPublic::new` checks shape only, beyond the `i16` type**
(`private_block.rs:199-205`): no monotonicity, no anchor value, unlike the exp
table (`:136`). That matches the kernel (`private-block-kernel/src/lib.rs:191`,
which also only shape-checks `act`) and E-2 asked only for the range, which the
type supplies. Structure is not provenance either way.

**N-7 — the frame length is derivable and correct.** Recomputing `wire.rs:28-36`
by hand: slot words `Σ (1 + (n+e)(d+1) + slot_terms(s)) = 917`, `×16 = 14,672`;
mask `32,768 + 256·824 = 243,712`; `opening_len(35,455) = 1,327,104`;
`opening_len(9,384) = 968,704`; `2·opening_len(1,7) = 262,144`; header+roots
`136`. Total **2,816,472**, the design's figure and the one
`tests.rs:106` and `tests/zk60_private_block.rs:105` assert.

**N-8 — `describe()`'s attention calibration line still ends "tables U8 + exp"**
(`layout.rs:659`) while the module now has three. The following line
(`:661-663`) names `U8 + exp + act`, so the schedule digest is complete; the
first line is merely stale prose inside a digested string, and changing it would
change the digest, so it is only worth doing if the string changes anyway.

## 2. The diff that matters

`diff -u hashline/src/private_attention/<f>.rs hashline/src/private_block/<f>.rs`
for each of the six shared files, plus the two top-level modules.

| File | What actually changed |
|---|---|
| `wire.rs` | **strings only**: `MAGIC` `HLPATTN\x01` → `HLPBLOK1`, ten error prefixes. Every constant, bound and parse step is byte-identical. |
| `protocol.rs` | the `"calibration"` absorb and the new `"parameters"` payload; `AttentionPublic` → `BlockPublic` (`public`/`ff` split); `TAG_ACT` / `g_act`; the `m_act` histogram and `H_FACT` / `H_GACT` columns; `logup_sum_claim` now keyed by `h_is_table` and `lay.h_planes()` instead of two literals; `N_WITNESS` replaced by the `committed` filter. `audit_claims`, `part_key`, `part_rows`, `check_opening`, `check_opening_challenges`, `check_endpoint_opening`, `finish_claims`, the ownership/drop order and the opening order are **unchanged apart from message text**. No assertion weakened. |
| `argument.rs` | `run_slot`, `priv_table`, `claim_point`, `mask_eval`, `build_claim`, `total`, `sum_weights`, `B`, `helper_sum`, `lk_tables`, `nonzero` are **unchanged apart from message text and `pa-*` → `pb-*`**. Two things became instance methods (`self.lay.a_sites()`, `lay.lookups`), which is a no-op. New: `Points` gains `r_t2`, `r_tf`, `p_g`, `p_u`, `p_z` (T2-check T-N7's request, met); `table_values_act`; slot arms `SC_SSM`, `SC_GMM|SC_UMM|SC_DMM`, `SC_FZC`; extended arms `SC_TZC`, `SC_LZC`, `SC_DZC`, `SC_TAB`; `SC_IO_OUT` moved from `A_X1` to `A_X2`. |
| `layout.rs` | `Dom::F`; 28 new `A` planes (15 Tier-1, 11 Tier-2, `A_MACT`); 10 new `H` planes; `is_multiplicity`, `h_is_table`, `limb_off_m`; the `Dom::D` lookup list grows 20 → 38, a new `Dom::F` list of 9; helper counts 19 / 5; 5 new slots, 2 new host groups; `A_GROUPS`/`H_GROUPS`/`N_FUNCTIONALS`/`A_ROWS`/`H_ROWS`/`A_DATA_ROWS`/`H_DATA_ROWS` as constants asserted by `Layout::new`; a sixth `describe()` line for the feed-forward. |
| `witness.rs` | `matmul_in_out`; `rms_norm` factored out into `NormPlanes` and called twice; the feed-forward block; `output()` moved from `A_X1` to `A_X2`; multiplicity planes left empty. |
| `private_block.rs` | new `FeedForwardPublic` (with `act: [i16; 256]`) and `BlockPublic`; `calibration_identity`; `ENDPOINT_SCALES` and the `IoSpec::new` refusal; seam slots 21/22/23/24 → 41/42/43/44; `EXPECTED_BYTES` magic `HATTEXP1` → `HBLKEXP1`. |

Two edits outside the new module, both permitted and both inspected:
`hashline/src/lib.rs` (+1 line, `pub mod private_block;`) and
`hashline/src/tables_attn.rs` (+7 lines, `pub const TAG_ACT: u64 = 134;` with a
comment). `hashline/Cargo.toml` gains `private-block-kernel` as a
**dev-dependency** only, so the reference kernel does not enter the library.

`git --no-pager diff --stat zk60-attention-compile --
hashline/src/private_attention.rs hashline/src/private_attention` **prints
nothing**: the accepted component is byte-identical (disposition ruling R-A and
condition 7 of the brief, satisfied).

## 3. Every plane pinned — in the code

T2-check §2.3 is the checklist; this is the same question asked of the Rust.
For each plane the new half adds: the define arm and the **exact term**, and the
lookup that gives its class. All `argument.rs` unless stated.

### 3.1 The Tier-1 planes (`norm_m`, residual 2)

| Plane | Define arm / term | Class lookup |
|---|---|---|
| `A_DM` (2) | `SC_TZC` `:578` `mu[4]·(dm − dlm)` and `mu[3]·(dsqm − dm·dm)`; `:581` host `nu[1]·eq(r_t2)·(dsqm + a1m − Ceps)` against `SC_SSM`'s claim `:550` | via `A_LIMBM`'s three low limbs: `dm < 2^24` |
| `A_DSQM` (3) | `SC_TZC` `:578` `mu[3]·(dsqm − dm·dm)`; `:581` | derived from `dm` |
| `A_LIMBM` (7) | `SC_TZC` `:578` `mu[4]`, `mu[5]·(2dm − a1m − a2m)`; sub-slices claimed at `:569-571` | `byte(A_LIMBM)` `layout.rs:315`, helper `H_L`, arm `SC_LZC` `:590-593` |
| `A_YM` = `nm` (27) | `SC_DZC` `:722` `c6 = 2·Cn·γm·x1 + 2^11·dm − 2^12·nm·dm − mr` under `mu[6]`; read again by `SC_GMM`/`SC_UMM` `:671-677` | `sym(A_YM)` `layout.rs:327` ⇒ `[−127, 127]` |
| `A_MR0..3` (28-31) | `SC_DZC` `:714` `mr = l4(A_MR0)`, used in `c6` `:722` and `c7` `:723` | `byte(A_MR0+k)` ×4 and `scaled(A_MR0+3, 8)` `layout.rs:328-329` ⇒ `ρ < 2^29` |
| `A_MS0..3` (32-35) | `SC_DZC` `:723` `c7 = ms + mr + 1 − 2^12·dm` under `mu[7]` | `byte` ×4 + `scaled(·,8)` `layout.rs:330-331` |
| `A_X2` (37) | `SC_DZC` `:725` `c8` (limbs) under `mu[8]`, `:726` `c9 = x2 − x1 − z16` under `mu[9]`; `SC_IO_OUT` `:895-897` | `byte(A_X2L0)`, `byte(A_X2L1)` `layout.rs:332` + `c8` ⇒ int16 |
| `A_X2L0/L1` (38-39) | `SC_DZC` `:725` | `layout.rs:332` |

### 3.2 The Tier-2 (feed-forward) planes

| Plane | Define arm / term | Class lookup |
|---|---|---|
| `A_G8` (67) | `SC_FZC` `:766` `f_act` (pair) under `mu[3]`; `:771` `host_g = 2^7·g8 + rg − 2^6` under `nu[0]·eq(p_g)` against `SC_GMM`'s claim `:686` | the **pair** lookup itself: `g8 + 128 = i ∈ [0,256)` ⇒ `[−128, 127]`, never `sym` |
| `A_RGL` (68) | `SC_FZC` `:771` `host_g` | `byte(A_RGL)`, `scaled(A_RGL, 2)` `layout.rs:337` ⇒ `[0, 2^7)` |
| `A_A16` (69) | `SC_FZC` `:763` `f0 = a16·u16 − 2^14·h16 − rh + 2^13` under `mu[0]`; **and** `:766` `f_act = v[i_fact]·(α − (g8 + 128 + β·a16 + g_act)) − 1` under `mu[3]` | the pair lookup. E-22 **is implemented**: `table_values_act` `:527-529` builds rows `i + β·act[i] + g_act`, `H_FACT` `protocol.rs:350-351`, `H_GACT` + `A_MACT` `:355`, closed by the sum claim `protocol.rs:52-62`. Class = the table's value set = int16 by the `[i16; 256]` type |
| `A_U16` (70) | `SC_FZC` `:763` `f0`; `:764` `f1` under `mu[1]`; `:773` `host_u = u16` under `nu[1]·eq(p_u)` against `SC_UMM`'s claim `:686` — **no coefficient, no constant**, which is `SH_U = 0` | `f1` + `byte(A_UL0)`, `byte(A_UL1)` `layout.rs:338` ⇒ int16 |
| `A_UL0/L1` (71-72) | `SC_FZC` `:764` | `layout.rs:338` |
| `A_H16` (73) | `SC_FZC` `:763` `f0`; `:765` `f2` under `mu[2]`; read by `SC_DMM` `:673`, `:677` | `f2` + `byte(A_HL0)`, `byte(A_HL1)` `layout.rs:339` |
| `A_HL0/L1` (74-75) | `SC_FZC` `:765` | `layout.rs:339` |
| `A_RH0/RH1` (76-77) | `SC_FZC` `:763`, via `l2(A_RH0)` | `byte(A_RH0)`, `byte(A_RH1)`, `scaled(A_RH1, 4)` `layout.rs:340` ⇒ `[0, 2^14)` |
| `A_Z16` (36) | `SC_DZC` `:726` `c9`, `:727` `c10` under `mu[10]`, `:733` `host_dmm = 2^6·z16 + rd − 2^5` under `nu[1]·eq(p_z)` against `SC_DMM`'s claim | `c10` + `byte(A_ZL0)`, `byte(A_ZL1)` `layout.rs:334` |
| `A_ZL0/L1` (40-41) | `SC_DZC` `:727` | `layout.rs:334` |
| `A_RDL` (42) | `SC_DZC` `:733` `host_dmm` | `byte(A_RDL)`, `scaled(A_RDL, 4)` `layout.rs:334` ⇒ `[0, 2^6)` |
| `A_MACT` (80) | `SC_TAB` `:875-877`, `:881` `r2 = v[8]·(α − v[9]) − v[7]` under `mu[2]`; enters the value-0 sum claim through `H_GACT` with sign −1 (`h_is_table` `layout.rs:255-257`, `protocol.rs:55`) | field multiplicities, no class needed |
| `H_F0..H_F0+4` (41-45) | `SC_FZC` `:750-753`, `helper_sum(v, &lks, h0, α, &mu[4..])` `:767` | in the sum claim: `logup_sum_claim` walks `lay.h_planes()` = **all 51** `protocol.rs:54` |
| `H_FACT` (46) | `SC_FZC` `:756` (captured index), used at `:766` | sum claim, sign +1 |
| `H_GACT` (49) | `SC_TAB` `:876`, `:881` | sum claim, sign −1 |

**No free plane, and no term whose coefficient can be zero by the prover's
choice.** The `mu` used by the relations and the `mu` slice used by `helper_sum`
are disjoint in every arm — I counted them: `SC_DZC` draws `11 + 19 = 30`
(`:690`), uses `mu[0..11]` for `c0..c10` (`:729`) and `mu[11..30]` for the 19
helpers (`:728`); `SC_FZC` draws `4 + 5 = 9` (`:744`), uses `mu[0..4]`
(`:768`) and `mu[4..9]` (`:767`); `SC_TZC` draws 6 and uses all six (`:577-578`);
`SC_SZC` draws `5 + 7 + 1` and uses `mu[0..5]`, `mu[5..12]`, `mu[12]` (`:853-854`).
`nu` is refused when zero (`:486-491`).

**E-17 is honoured.** `SC_FZC` binds the activation helper by the index the
builder returns — `let i_fact = b.h(H_FACT)?;` (`:756`) then `v[i_fact]`
(`:766`) — never by the plane constant, and the push order matters and is right:
the five `U8` helpers are pushed first (`:750-753`, table indices 14..18), so
`helper_sum`'s `v[h0 + k]` never reaches `i_fact` at 19. The same pattern holds
for `ihx = b.h(H_SEXP)?` (`:837`).

**One structural obligation T2 §C.2 puts on the implementer is met and
enforced.** Planes are contiguous per domain (`a_dom` `layout.rs:202-214`,
`h_dom` `:242-252`), and `planes_are_row_aligned_and_contiguous_per_domain`
(`layout.rs:753-781`) asserts it for all nine `A` domains and seven `H` domains,
which is what the two `a_range` sweeps (`:697`, `:749`) depend on. A plane that
strayed out of its run would make `idx[p] == usize::MAX` and panic the prover —
loud, not silent.

## 4. The relations are the kernel's

The rounding convention first, because everything hangs on it.
`private-block-kernel/src/lib.rs:298-308`: for `sh > 0`,
`y = (acc + 2^(sh−1)) >> sh` with `>>` an arithmetic shift, so writing
`r' = acc + 2^(sh−1) − y·2^sh ∈ [0, 2^sh)`,

```
acc = 2^sh·y + r' − 2^(sh−1)          EXACT over Z, the BIASED form
```

`witness.rs:54-57` computes `y` identically and `:73` pushes
`rem + (1i64 << (sh - 1))` = `r'`, i.e. it commits the **biased** remainder.
`argument.rs` writes the identity in exactly that form everywhere
(`k(1 << SH)·y + r − k(1 << (SH−1))`). **Witness helper and argument identity
are the same identity, and both are the kernel's.** For `sh ≤ 0` the kernel
returns `acc·2^{−sh}` with no remainder at all (`lib.rs:299-300`), which at
`SH_U = 0` is the identity map — and the code has no `up` remainder plane, no
coefficient and no constant (`argument.rs:773`).

| Relation | Kernel | Code | Verdict |
|---|---|---|---|
| `norm_m` isqrt | `lib.rs:382-411` via `rms_norm(&x1, &w.gamma_m, …)` `:618`; `D = isqrt(Σx² + Ceps)` | `SC_TZC` `:578`: `dsqm = dm·dm`, `dm = dlm`, `2dm = a1m + a2m`; `:581` host `dsqm + a1m − Ceps = Σ_i x1²`. With `a1m, a2m ≥ 0` (bytes) this is `dm² ≤ ss ≤ dm² + 2dm` | **EXACT**, the `norm_a` relation verbatim with `A_X1`/`A_DM`/`A_LIMBM` |
| `norm_m` quotient | `lib.rs:399-405`: `num = 2·x·g·Cn + D·2^tn`, `den = D·2^(tn+1)`, `q = num div den`, `ρ = num rem den`, `σ = den − 1 − ρ`, `q ∈ [−127,127]`, `ρ, σ < 2^29` | `c6` `:722` = `2·Cn·γm·x1 + 2^11·dm − 2^12·nm·dm − mr` (i.e. `num − q·den − ρ = 0`), `c7` `:723` = `ms + mr + 1 − 2^12·dm` (i.e. `σ + ρ + 1 = den`), `sym(A_YM)`, `scaled(A_MR0+3, 8)` / `scaled(A_MS0+3, 8)` | **EXACT.** `NORM_TN=11`, `NORM_CN=1024`, `NORM_CEPS=1`, `NORM_WRHO=29` (`layout.rs:52-55`) equal `calib` (`lib.rs:61-64`) |
| R1 gate | `lib.rs:627-629`: `matmul_in_out(nm, wg_t, D, F)` then `requant_all(·, SH_G=7, I8=(-128,127))` | `SC_GMM` `:671`, `:679` `fold_cols_i8(wg_t, D, F, eq(r_j))`; `SC_FZC` `:771` `host_g = 2^7·g8 + rg − 2^6` | **EXACT**, incl. the `(input, output)` storage and the **asymmetric** class: the code uses no `sym(A_G8)` and gets `[−128,127]` from the 256-row table (`layout.rs:336-341` has no `A_G8` entry; the premise comment `:286-287` says so) |
| R2 activation | `lib.rs:633-637`: `a[idx] = act[g[idx] + 128]` | `f_act` `:766` binds the **pair** `(g8+128, a16)` against `table_values_act` `:527-529` | **EXACT**, and the pair form is the one E-22 requires |
| R3 up | `lib.rs:630-632`: `requant_all(·, SH_U=0, I16)` = identity + class | `host_u = u16` `:773`, `f1` `:764`, `byte(A_UL0/L1)` | **EXACT.** No `A_RU` plane exists; `witness.rs:355-358` does **not** route through `quantize` (avoiding D-2) |
| R4 product | `lib.rs:638-642`: `hh = a·u` then `requant_all(·, SH_H=14, I16)` | `f0` `:763` = `a16·u16 − 2^14·h16 − l2(A_RH0) + 2^13` | **EXACT**: `−2^14·h16 − rh + 2^13`, i.e. `hacc = 2^14·h16 + rh − 2^13` |
| R5 down | `lib.rs:643-645`: `matmul_in_out(hh, wd_t, F, D)` then `requant_all(·, SH_Z=6, I16)` | `SC_DMM` `:673`, `:679` `fold_cols_i8(wd_t, F, D, eq(r_j))`; `SC_DZC` `:733` `host_dmm = 2^6·z16 + rd − 2^5` | **EXACT** |
| residual 2 | `lib.rs:647-651`: `x2 = x1·2^0 + z·2^0`, `requant_all(·, SH_R2=0, I16)` | `c9` `:726` = `x2 − x1 − z16`; `c8` `:725` int16 limbs | **EXACT**, all three shifts zero |

`fold_cols_i8(m, rows, cols, c)` is `out[i] = Σ_j m[i·cols + j]·c[j]`
(`zkp-core/src/mle.rs:136-149`), i.e. it folds an `(input, output)` matrix over
its **output** index — which is what all three feed-forward matrices need and
what `matmul_in_out` computes. The orientations are right in all three arms:
`SC_GMM`/`SC_UMM` fold `(D, F)` down to length `D` and pair it with `nm~(r_tf, i)`
over the `i`-cube; `SC_DMM` folds `(F, D)` down to length `F` and pairs it with
`h16~(r_td, j)` over the `j`-cube. The index conventions agree: `Coord::Rho(k)`
maps bit `k` of the plane index to bit `n_vars−1−k` of the sumcheck variable
(`:179-180`), and `eq_table_msb` is msb-first, so both sides see the same `i`.

The shift constants in `layout.rs:68-70` (`SH_G = 7`, `SH_H_PROD = 14`,
`SH_Z = 6`) equal `calib::SH_G/SH_H/SH_Z` (`lib.rs:81-84`), and `SH_U` has no
constant at all because there is nothing to multiply by.

**Witness/kernel parity is independently tested and the test is strong.**
`parity.rs:237-279` runs 1,200 deterministic generated cases and allows exactly
two outcomes per case — both accept with every plane compared element for
element (`compare_attention_half` `:156-173`, `compare_block_half` `:182-235`),
or both refuse with the **same string** (`:262`). `compare_block_half` checks the
three biased requantization identities against the kernel's own accumulators
recomputed from `tr.nm_y` / `tr.a16` / `tr.u16` / `tr.h16` — so the witness's
remainder convention is checked against the kernel, not against itself.
`refusals.rs` forces twelve refusal sites by hand and states the bound for each
unreachable one. This is the strongest part of the test suite.

## 5. Range proofs — is each class the class needed?

| Quantity | Needed | Coded | OK |
|---|---|---|---|
| `rg` | `[0, 2^7)` | `byte(A_RGL)`, `scaled(A_RGL, 2)` `layout.rs:337` | yes: `v < 256` and `2v < 256` ⇒ `v < 128` |
| `rd` | `[0, 2^6)` | `byte(A_RDL)`, `scaled(A_RDL, 4)` `layout.rs:334` | yes |
| `rh` | `[0, 2^14)` | `byte(A_RH0)`, `byte(A_RH1)`, `scaled(A_RH1, 4)` `layout.rs:340`, combined as `l2(A_RH0)` `:763` | yes: `rh = l0 + 256·l1`, `l0 < 256`, `l1 < 64` |
| `u16`, `h16`, `z16`, `x2` | int16 | two byte limbs + the `+32768` decomposition (`f1` `:764`, `f2` `:765`, `c10` `:727`, `c8` `:725`) | yes |
| `nm` | `[−127, 127]` | `sym(A_YM)` `layout.rs:327` | yes |
| `g8` | `[−128, 127]` | the activation pair lookup only | yes, and deliberately **not** `sym`, which would prove `[−127,127]` and make an honest `g8 = −128` unprovable |
| `a16` | int16 | the pair lookup + `act: [i16; 256]` | yes (§6) |
| `ρ_m`, `σ_m` | `< 2^29` | four bytes + `scaled(·, 2^(32−29)=8)` on the top limb `layout.rs:329`, `:331` | yes |

The `scaled` soundness step is R-2's: `byte(p)` forces `v ∈ [0,256)` as an
integer, after which `k·v ≤ 255·4 = 1,020 ≪ p`, so the field constraint on
`k·v` **is** the integer constraint. The largest `scaled` multiplier in the new
lists is 8 (the norm top limb, `1 << (32 - NORM_WRHO)`), giving `2,040`. No new
pattern is invented, so no new brute force is owed.

**Every declared lookup's helper column is in the sum claim, at the right size
and under the right tag.** `logup_sum_claim` (`protocol.rs:52-62`) walks
`lay.h_planes()` — literally `0..N_H` (`layout.rs:615-617`) — so no helper can be
left out by construction; it takes `log_size` from `h_dom(p)`, which is the same
function the helper columns were written with (`protocol.rs:337-360`), and it
negates exactly the three table helpers via `h_is_table` (`layout.rs:255-257`).
The zero-sum pair `u` (`H_U`, plane 50, `Dom::Tab` by the `_` fallback) enters
with `+1` and is forced to sum to zero by `SC_ZS` (`argument.rs:886-890`, a
standalone slot with public claimed sum 0 over the all-ones table).

**No `Dom::F` / `Dom::D` cross-wiring.** `lookups(Dom::F)` names only planes
67-77 (`layout.rs:336-341`), all inside `SC_FZC`'s `a_range(A_G8, A_RH1)`
(`:749`); `lookups(Dom::D)` names only planes 9-42, all inside `SC_DZC`'s
`a_range(A_X, A_RDL)` (`:697`). A stray plane would give `idx[p] == usize::MAX`
and panic, so this cannot fail silently. `helpers(Dom::F) = (H_F0, 5)` →
planes 41-45, and `h_dom` puts 41..=46 in `Dom::F` (`layout.rs:249`), with
`H_FACT = 46` the sixth — the `H_S0..=H_SEXP` pattern, exactly (T2-check T-N4's
requirement, met). The three tags are distinct multiples of one `γ`:
`TAG_U8 = 133`, `TAG_EXP = 129`, `TAG_ACT = 134` (`tables_attn.rs:60`, `:49`,
`:71`), folded in at `protocol.rs:333-335` (prover) and `:442-444` (verifier),
identically.

Counts I re-derived by hand and that the module asserts:
`|lookups(D)| = 38`, `|lookups(F)| = 9`, helpers 19 and 5
(`layout.rs:741`); per-domain `U8` totals `1,024 / 19,456 / 4,608 / 6,656 /
3,072 / 26,624 = 61,440` (`:745-746`); `A` data rows 213, `H` data rows 280,
`A` rows 455, `H` rows 384 (`:588-591`). All agree with T2-check §5.1.

## 6. No-wraparound, and the public statement the bounds rest on

Method: R-2's (`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md:33-39`) — bound each
constrained expression over the ranges the **verifier enforces**, never over
what an honest prover produces, and compare against that review's limit
`562,949,886,312,450 < 2^49`. Batching coefficients do not enter: a fresh `τ`
makes each zero-check term a per-entry integer equation and each host part
separates through a nonzero-refused `ν` (`argument.rs:486-491`).

Enforced windows used, and only these: `nm ∈ [−127,127]` (`sym`);
`x1, x2, u16, h16, z16 ∈ int16` (limbs); `g8 ∈ [−128,127]`, `a16 ∈ int16`
(the pair lookup + the `[i16; 256]` type); `rg < 2^7`, `rh < 2^14`, `rd < 2^6`;
`dm < 2^24` (three byte limbs); `|Wg|, |Wu|, |Wd|, |γm| ≤ 128` (i8).

| Term | `argument.rs` | Bound |
|---|---|---|
| `gacc`, `uacc` = `Σ_{i<16} nm·W` | `:679` | `16·127·128 = 260,096 < 2^18` |
| `host_g − gacc` | `:771` | `260,096 + 2^7·128 + 127 + 64 = 276,671 < 2^19` |
| `host_u − uacc` | `:773` | `260,096 + 32,768 = 292,864 < 2^19` |
| `f0` | `:763` | `2^30 + 2^14·32,768 + 16,383 + 8,192 = 1,610,637,311 < 2^31` — the **worst new** term |
| `f1`, `f2` | `:764-765` | `131,071 < 2^17` |
| `zacc` | `:679` | `16·32,768·128 = 2^26` |
| `host_dmm − zacc` | `:733` | `2^26 + 2^6·32,768 + 63 + 32 = 69,206,111 < 2^27` |
| `c8`, `c9`, `c10` | `:725-727` | `≤ 3·32,768 < 2^17` |
| `c6` | `:722` | `2·1024·127·32,768 + 2^11·2^24 + 2^12·127·2^24 + 2^29 ≈ 2^43` |
| `c7` | `:723` | `2^12·2^24 = 2^36` |
| `SC_TZC` `mu[3]`: `dsqm − dm²` | `:578` | `< 2^48`, the same worst case as `norm_a` |
| `SC_TZC` `nu[1]` host: `Σ_i x1² ` | `:581` | `16·2^30 = 2^34` |
| `U8` / act multiplicities | `protocol.rs:309-311` | `61,440` / `512` |

Worst new term `1,610,637,311 < 2^31`, well below `2^49`; the whole-block worst
case is unchanged at the `norm` `dsq − d·d` term. Every figure reproduces T2 §E
and T2-check §6.2. The one premise that whole table rests on is `|a16| ≤ 32768`,
and **in the code it is enforced**, not promised.

**Erratum E-2 / T-B1, discharged by the type.**
`FeedForwardPublic::act: [i16; 256]` (`private_block.rs:195`), built only by
`new` (`:199-205`) through `act.try_into()` which refuses any other length;
there is no byte parser for these words, no second constructor, and the field is
private. `table_values_act` reads `i64::from(ff.act[i])` (`argument.rs:528`), so
the table's value set is `[−32768, 32767]` by construction. This is stronger
than the runtime check E-2 allowed as the alternative.

**The public-statement digest.** `BlockPublic::digest` (`private_block.rs:256-262`)
absorbs, in this exact order, with a `u64` little-endian length before each run
of words:

1. domain `b"hashline/private-block-public/1"`
2. `wq` (256 i8-as-u8), `wk` (128), `wv` (128), `wo` (256), `gamma_a` (16) — `:151-155`
3. `rope_cos` (128 × i64 LE), `rope_sin` (128), `exp` (256) — `:156-161`
4. `gamma_m` (16 i8), `wg_t` (256), `wu_t` (256), `wd_t` (256) — `:217-221`
5. `act` — length then **256 × i16 little-endian** — `:222-226`

Cross-checked against every public value the argument reads:
`public.wq/wk/wv/wo` (`argument.rs:610-613`), `public.gamma_a` (`:695`),
`public.rope_cos/rope_sin` (`:510-511`), `public.exp` (`:520`),
`ff.gamma_m` (`:696`), `ff.wg_t/wu_t/wd_t` (`:671-673`), `ff.act` (`:528`).
**Every one is covered, and nothing else is public data**: `causal_mask()`
(`:498-500`) and `table_values_u8` (`:516-518`) are functions of the geometry,
and `TAG_U8/TAG_EXP/TAG_ACT` are compile-time constants of both sides. The
digest is absorbed once, under `"public-statement"` (`protocol.rs:32`); there is
no second absorb of the feed-forward words (the S3b deviation
`"feed-forward-statement"` recorded in the ledger at line 598-604 was removed in
S4, as T2 §F required — I checked, the label does not appear in the tree).
Each field has a fixed length enforced by its constructor, so the
length-prefixed concatenation cannot be re-partitioned.
`receipt_field_tampers_and_statement_mismatches_are_refused`
(`tests.rs:230-248`) exercises one changed word in each of `wq`, `gamma_m`,
`wg_t`, `wu_t`, `wd_t` and `act`, and requires both `verify` and `from_bytes`
to refuse.

## 7. Fiat–Shamir order

The built order, read off `protocol.rs:29-38`, `:320`, `:326`, `:330-332`,
`:377`, `argument.rs:904-917`, `:268`, `:273`, `:288`, `:348`,
`protocol.rs:392-407`, against T1 §D steps 1-16 and T2 §F:

| # | Design | Code | Same? |
|---|---|---|---|
| 1 | `Transcript::new(PROFILE)` | `:30` | yes |
| 2 | `"expected-IO"` ← magic `HBLKEXP1`, context, both scales, **both endpoint roots** | `:31`, payload `private_block.rs:334-343` | yes |
| 3 | `"public-statement"` ← `BlockPublic::digest()` | `:32` | yes |
| 4 | `"parameters"` (+ T2's `sh-g7-u0-h14-z6`) | `:33` — `T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript` | yes |
| 5 | **new** `"calibration"` ← the calibration identity | `:35` | yes |
| 6 | `"schedule"` ← `schedule_digest()` | `:36` | yes |
| 7 | `"A"` root + `"rows"` + `"log-cols"` | `:320` via `absorb_root` `:40-44` | yes |
| 8 | `"M"` root | `:326` | yes |
| 9 | `β`, `γ`, `α` in that order | `:330-332` | yes |
| 10 | `"H"` root + rows + log-cols | `:377` | yes |
| 11 | 23 slots: `define` draws `τ`, `μ`, `ν`, points → absorb slot index → draw `c` (refuse zero) → absorb the one scalar → rounds → extension → absorb terminals | `argument.rs:907-909`, then `:268`, `:273-275`, `:288`/`:319`, `:290-307`, `:348` | yes |
| 12 | one `M` opening | `protocol.rs:392` | yes |
| 13-16 | `A`, `H`, In, Out, each preceded by its refusal replay from a cloned transcript, each owner dropped | `:396-407` | yes |

**No differences.** The two liberties the design grants were taken: the
per-slot labels are `pb-slot` / `pb-scalar` / `pb-term` (ruling R-B leaves this
to the implementer), and the `"parameters"` payload carries the feed-forward
shifts (T2 §F asks for it). Verifier mirror `:436-445` absorbs the same
sequence, and the slot loop is literally the same `argument()` function driven
with `Side::Verify`, so prover and verifier cannot build different lists.

**The activation challenges are late enough.** `A_MACT` is written into `a_data`
in the same block as `m_u8`/`m_exp` (`:308-312`), *before*
`commit_zk_owned` (`:316`) and the `"A"` absorb (`:320`); `g8` and `a16` are
committed there too (`:283-287`). `β`, `γ`, `α` are drawn at `:330-332`, after
the `A` root and the `M` root. `g_act = γ·TAG_ACT` (`:335`) is derived, not
absorbed — the same status as `g_u8` and `g_exp`. The `H` columns that invert
the activation denominators (`:350-351`, `:355`) are written after `α` and
before the `H` commitment (`:373`), which is where `H_SEXP`/`H_GEXP` already
live. So the LogUp premise holds for the third table exactly as for the first
two, and the E-22 pair binding is under a `β` the prover could not see when it
chose `g8` and `a16`.

**One thing the design flagged and the code did not fix:** the transcript-order
*gate* (`acc.order`) still records three coarse strings per slot and nothing
outside the slot loop (H-8). T1 §D:810-817 predicted exactly this.

## 8. Domain separation from the accepted component

Every string, magic, digest domain and label in the new module, beside the
accepted one's. Found by grepping both trees for `Transcript::new`, `absorb`,
`b"H`, `hashline-zk-mr1`, `hashline/private`, `const MAGIC`, `SeamSpec::new`.

| Kind | Private attention | Private block | Distinct |
|---|---|---|---|
| Fiat–Shamir profile | `hashline-zk-mr1/private-attention-t32-poc/1` (`private_attention.rs:59`) | `hashline-zk-mr1/private-block-t32-poc/1` (`private_block.rs:82`) | yes |
| statement digest domain | `hashline/private-attention-public/1` (`:114`) | `hashline/private-block-public/1` (`:258`) | yes |
| schedule digest domain | `hashline/private-attention-schedule/1` (`private_attention/layout.rs:504`) | `hashline/private-block-schedule/1` (`private_block/layout.rs:680`) | yes |
| wire magic | `HLPATTN\x01` (`…/wire.rs:16`) | `HLPBLOK1` (`…/wire.rs:16`) | yes |
| expected-policy magic | `HATTEXP1` (`private_attention.rs:183`, `:192`) | `HBLKEXP1` (`private_block.rs:336`, `:345`) | yes |
| `"parameters"` payload | `T32/d16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/two-private-endpoints` | the `f16`/`sh-g7-u0-h14-z6`/`one-proof-one-transcript` string | yes |
| `"calibration"` absorb | absent | present (`protocol.rs:35`) | new label |
| per-slot labels | `pa-slot` / `pa-scalar` / `pa-term` | `pb-slot` / `pb-scalar` / `pb-term` | yes |
| `private_seam` slot tags | 21, 22, 23, 24 (`private_attention.rs:157`) | 41, 42, 43, 44 (`private_block.rs:310`) | yes, and disjoint from the FFN-IO profile's 1-4 (`zk_ffn_fresh_io.rs:40-41`) |
| LogUp tags | `TAG_U8 133`, `TAG_EXP 129` | plus `TAG_ACT 134` (`tables_attn.rs:71`) | 134 is free repo-wide; it is explicitly **not** the FFN statement's `TAG_ACT16 = 3`, which lives in a deliberately disjoint namespace |

The shared labels `"expected-IO"`, `"public-statement"`, `"parameters"`,
`"schedule"`, `"A"`, `"M"`, `"H"`, `"rows"`, `"log-cols"` are reused with new
payloads, which is what the design says to do; the profile string at step 1
separates the domains before any of them.

**Byte-identity of the accepted component confirmed.**
`git --no-pager diff --stat zk60-attention-compile -- hashline/src/private_attention.rs hashline/src/private_attention`
prints nothing. The full diff against that branch is 20 files, all additions:
the new module, its example and integration test, the ledger, the evidence
directory, `+1` line in `lib.rs`, `+7` in `tables_attn.rs`, `+7` in
`Cargo.toml` (the dev-dependency). I read all three of those edits; none can
change the accepted component's behaviour (a new `pub const`, a new `pub mod`,
a dev-only path dependency).

## 9. Endpoints and D12

**Exactly two external endpoints.** `Cm` has four members but only `In` and
`Out` are endpoint commitments (`argument.rs:38-44`), and `B::endpoint` is
called from exactly one arm: `SC_IO_IN | SC_IO_OUT` (`:891-898`), binding
`A_X` and `A_X2` respectively. `prepare_endpoints` (`private_block.rs:373-384`)
commits two planes; `Endpoints` holds two; `Receipt.io_open` is `[OpeningZk; 2]`;
`ExpectedIo` carries two roots. There is no third.

**Nothing exposes a hidden plane.** I looked for every way a value could leave:

- *Public struct fields:* `Witness.planes` is `pub` but the struct is
  `pub(crate)` inside a private module (`witness.rs:18-23`); `Receipt`'s fields
  are private and hold only roots, masked scalars, round messages, masked
  terminals and openings (`private_block.rs:396-406`).
- *`Debug`:* derived on `Receipt` (`:396`), `SlotProof` (`argument.rs:84`),
  `ProveStats` (`:411`), `IoSpec` (`:277`), `ExpectedIo` (`:317`) — all public
  receipt/policy data. **`Witness` has no `Debug`**, and neither does
  `Endpoints`, `AttentionPublic`, `FeedForwardPublic` or `BlockPublic`.
- *Log lines:* none in the module. The example prints the profile, six schedule
  lines, the frame length, row and lookup counts and phase timings
  (`examples/zk60_private_block.rs:52-62`) — all geometry constants — and drops
  the computed output immediately (`:42-44`).
- *Error messages:* every refusal carries a static site name
  (`witness.rs:59-61`, `:29`) or a slot index (`argument.rs:321`); I found no
  `format!` that interpolates a plane value.
- *`ProveStats`:* `u8_lookups`/`exp_lookups`/`act_lookups` are fixed by the
  geometry (61,440 / 2,048 / 512, asserted at `tests.rs:105`), and
  `transcript_order` is the three-strings-per-slot list.
- *`xres1`, `nm`, `z16` and the feed-forward planes* appear only as `A` planes
  and in the `A` opening, never as an endpoint, a getter or a printed value.
  `compute_output` (`private_block.rs:390-392`) returns `xres2` only (N-5).
- A smoke test backs this: `no_published_word_is_a_small_integer`
  (`tests.rs:111-131`) walks >200,000 published words and requires none within
  `2^24` of `0` or `p`.

**Endpoint scales pinned.** `IoSpec::new` refuses any pair but `(0, 0)`
(`private_block.rs:292-299`, `ENDPOINT_SCALES` `:98`), and
`the_endpoint_scales_and_calibration_are_the_approved_ones` (`tests.rs:33-49`)
refuses `(-3,-3)` — the accepted attention fixtures' value — plus four
near-misses.

**The calibration digest and its pinning test.** `calibration_identity()` is the
literal `blake3("B3 public fixed calibration v1")` (`:92-94`), the recorded
deviation (d) the security owner accepted for the PoC. The pinning test is
real: `tests.rs:43-48` builds
`causal_oracle::public_synthetic_registration(dummy, dummy)` and asserts
`calibration_identity() == reg.calibration_identity` — and
`causal_oracle.rs:194` is `*blake3::hash(b"B3 public fixed calibration v1")…`,
so the test compares against the registration's own field, not against a second
copy of the literal. The same test also pins `(0, 0)` to
`reg.attention.e_r` (`causal_oracle.rs:116`) and `reg.residual.e_r2`
(`:146`). **The pinning is genuine**; it becomes wrong the day a second
calibration exists, as the owner's ruling says.

**D12 is not closed by any of this.** D8/D11 (simulation against caller-fixed
endpoint roots with prior public history) remain open and the module says so
(`private_block.rs:34-38`). Nothing here establishes a privacy property.

## 10. The tamper tests, and my attempt to build a false accepted witness

### 10.1 The `Catch` matcher, first

`Catch::Slot(s)` matches `err.starts_with("slot {s} [")` (`tamper.rs:51`). That
string is produced at exactly one place, `argument.rs:321`, inside the
`Side::Verify` arm. `Catch::LogUp` matches `"H: "`, produced only at
`protocol.rs:455`, in `verify_inner`. **So neither can be satisfied by a
prover-side error**, even though `prove_tampered` (`:128-139`) propagates prover
errors with `?` — which is the right design, and I checked it rather than
assuming it. `expect_rejection` (`:141-144`) then requires the *specific* catch,
not merely an error. Slot indices cannot alias (`"slot 1 ["` is not a prefix of
`"slot 14 ["`). Six of the nine tests also re-run the honest proof through the
same path (E-20), so the suite cannot pass on a build that is broken generally.

### 10.2 Case by case

| Test | Consistent? | Catch demanded | Could it pass for the wrong reason? |
|---|---|---|---|
| `block_output_cannot_be_chosen` `:163-174` | **yes, the strong form**: `z16 +1`, `xres2` recomputed, `A_ZL*` and `A_X2L*` both recomputed, and the endpoint owner commits the **chosen** `xres2'` (`:133-134`), so `SC_IO_OUT` cannot be what rejects | `Slot(SC_DZC)` | no. This is the tripwire disposition condition 1 demands, in the form it demands |
| `a_gate_output_not_derived_from_nm_is_rejected` `:180-196` | yes: `g8 +1`, `a16` re-looked-up, the whole chain recomputed and checked in-class by a probe first | `Slot(SC_FZC)` | no — every class, lookup and downstream identity still holds, so only `host_g` vs `SC_GMM` is left |
| `an_activation_value_off_its_table_row_is_rejected` `:204-218` | yes: `a16 +1`, chain recomputed | `LogUp` | partly — see H-3 and H-5: it tests the pair lookup at an index where `u16 ≠ 0`, which is not E-22's case, and `"H: "` is the whole `H` opening |
| `an_up_output_not_derived_from_nm_is_rejected` `:224-239` | yes | `Slot(SC_FZC)` | no |
| `a_product_output_not_equal_to_a16_times_u16_is_rejected` `:245-260` | yes: `h16 +1`, limbs and **everything below** recomputed so `SC_DMM` and `SC_DZC` still agree | `Slot(SC_FZC)` | no — `f0` is genuinely the only relation left |
| `every_biased_remainder_is_pinned_by_its_requantization_identity` `:267-283` | yes — each remainder is rotated **inside its own window**, so the byte lookups still hold and the multiplicity histogram is recomputed by the prover from the tampered witness | `Slot(SC_FZC)` ×2, `Slot(SC_DZC)` | no. The cleanest three in the suite |
| `a_limb_outside_its_byte_range_is_rejected_by_the_lookups` `:301-316` | yes: `(+256, −1)` keeps `l0 + 256·l1` exactly, so `c10`/`f1`/`f2`/`f0` all still hold | `LogUp` | H-5's looseness; otherwise sound, and it is the right way to isolate a class lookup |
| `a_z16_outside_int16_cannot_reach_the_output_endpoint` `:321-331` | **no, by design**: three independent catches (the test says so) | `Slot(SC_IO_OUT)` | yes in principle — it asserts which catch fires *first*, which is a measurement, not an argument. Honestly labelled |
| `an_output_endpoint_committing_xres1_is_refused` `:337-349` | yes, and it first asserts the fixture's two residuals differ so the test is not vacuous | `Slot(SC_IO_OUT)` | no |

**Weakest:** `a_z16_outside_int16_cannot_reach_the_output_endpoint` — it admits
three catches and pins the first, so a change in slot order or an earlier
refusal turns a real regression into a red test for the wrong reason. It is
documented as such. The weakest *in what it demonstrates* is
`an_activation_value_off_its_table_row_is_rejected`, for H-3's reason.

**Missing:** the entire `norm_m` family, `A_MACT`, and the `u16 = 0` case
(H-1, H-2, H-3).

### 10.3 Trying to build a false accepted witness

I tried the following and failed on each; the reason is recorded so a later
reader can check my reasoning rather than my conclusion.

1. **Move `xres2` (the tripwire, generalised).** `x2` is forced by `c9` from
   `x1` and `z16`; `z16` is forced by `host_dmm` against `SC_DMM`'s claim
   `Σ_j h16~(r_td, j)·Wdfold(j)` at a point drawn *after* `A` is committed;
   `h16` is forced by `f0` from `a16·u16` with `rh` a complete residue system
   mod `2^14`, so `(h16, rh)` is unique; `a16` is forced onto a table row by
   `f_act` + the sum claim; `u16` is forced by `host_u` against `SC_UMM`;
   `g8` is forced by `host_g` against `SC_GMM` with `rg` a complete residue
   system mod `2^7`; `nm` is forced by `c6`/`c7` from `x1` and `dm`; `dm` is
   forced by `SC_TZC` from `x1`; `x1` by `c5` from `x` and `ao`; `x` by
   `SC_IO_IN`. **Every link closes**, each at a point drawn after commitment.
2. **Exploit `u16 = 0`.** At such an index `f0` reads `0 − 2^14·h16 − rh + 2^13`
   and says nothing about `a16` — but `f_act` does, and it is present
   (`:766`). Without it this would be a free plane at those indices, and with
   `a16` free, `h16` is still forced to 0 there, so the *immediate* damage is
   nil; the damage is that `a16`'s class would then be unenforced and item 5 of
   §6's bound (`|a16·u16| ≤ 2^30`) would be unfounded at *every* index, because
   a class is a property of the plane, not of an index. The pair lookup closes
   it.
3. **Make a zero-check term vanish.** `Σ_x eq(τ,x)·zc(x) + C = 0` with `τ`
   drawn fresh inside the slot forces the multilinear `zc~` to be the constant
   `−C`; with `μ` drawn after commitment, `zc(x) = Σ_i μ_i c_i(x) + helper_sum`
   being a fixed constant for all `x` requires every `c_i(x) = 0` unless a
   random linear form hits a value determined by independent `ν` draws. Not
   reachable.
4. **Free-ride on a shared point.** `SC_GMM` and `SC_UMM` share `r_tf` but draw
   their own `r_j` and their own `ρ`, so the two `A_YM` claims have different
   points, different PCS group keys and their own reserved pairs
   (`B::a_at` → `lay.a_site(slot, ak)` `:415`). The `check_opening` group count
   (35) is recomputed from the actual claim points and refused if it differs
   (`protocol.rs:169-171`), so a collision would be caught, not exploited.
5. **Forge the activation histogram.** `m_act` is committed in `A` before `β`,
   `γ`, `α`; the LogUp identity is one rational function of `α` with ≈63,500
   poles, so a mismatch survives a random `α` with probability ≈`2^{-110}`.
6. **Use a plane the layout commits but no arm reads.** The only such planes are
   the seven unused `A_LIMB`/`A_LIMBM` sub-planes (N-3); they appear in no
   relation, so they cannot move any other value.
7. **Cross a `Dom::F` plane into a `Dom::D` term** (the same cube size makes it
   arithmetically possible). `a_range` returns `usize::MAX` for planes outside
   the sweep, so a mis-wired read panics the prover rather than proving
   something false; and the two lookup lists name only their own planes.

**Result: I could not construct a false witness the verifier accepts.** That is
one pass by one reviewer, not a proof, and the enumeration of `SC_DZC`'s and
`SC_FZC`'s full degree-4 monomial expansion — which the disposition §5 already
lists as not done — is still not done.

## 11. Anything else

- **Dead code:** none. There is no `#[allow(dead_code)]` anywhere in the module
  (grep over all nine files), and no `#[cfg(feature = …)]` path. Every
  `Layout` accessor, every constant and every helper I traced is used.
- **Test-only code reachable in release:** none. `parity`, `refusals`, `tamper`
  and `tests` are all behind `#[cfg(test)]` (`private_block.rs:65-72`), and
  `private-block-kernel` is a **dev-dependency**, so the reference kernel is not
  linked into the library.
- **`unsafe`:** none in the module; the kernel crate is `#![forbid(unsafe_code)]`.
- **Panics on untrusted receipt bytes:** none found. `wire::decode`
  (`wire.rs:144-175`) checks the exact length first, reads through
  `Reader::take` which is `checked_add`-guarded (`:107-112`), rejects
  non-canonical field words (`:113-119`) and out-of-domain column indices
  (`:126-135`), and rejects trailing bytes. Every count comes from the layout,
  never from the frame. The only `expect`s on a parse path are
  `ExpectedIo::from_bytes`'s `try_into().expect("32 bytes")` /
  `expect("4 bytes")` (`private_block.rs:348-349`), both preceded by the exact
  `b.len() != EXPECTED_BYTES` check at `:345`, so the slices `b[8..40]`,
  `b[40..44]`, `b[44..48]`, `b[48..80]`, `b[80..112]` are always in bounds for
  `EXPECTED_BYTES = 112`. They cannot fire.
- **Integer overflow in wire-length arithmetic:** `encoded_len`
  (`wire.rs:32-36`) is a sum of compile-time-bounded terms (917 slot words ×16,
  243,712, 1,327,104, 968,704, 262,144) totalling 2,816,472, checked against
  `MAX_WIRE_BYTES = 4 MiB` (67.1 % of it) at both `:74` and `:145`. No product
  depends on frame content.
- **Assertions weakened relative to the accepted module:** none that I found.
  `audit_claims`, `check_opening`, `check_opening_challenges` and
  `check_endpoint_opening` are unchanged apart from message text; `run_slot`'s
  three shape guards (`:262`, `:265`, `:279`) and `B::finish`'s site-count guard
  (`:446-448`) are unchanged in substance. The two layout tests were rewritten
  (ledger deviation 2): `declared_counts_are_self_consistent` now asserts the
  whole-block counts and **added** the `Dom::F` plane counts and the per-domain
  lookup totals; `the_two_layouts_share_one_plane_numbering` became
  `planes_are_row_aligned_and_contiguous_per_domain`, which keeps plane order,
  distinct offsets and row alignment and **adds** the per-domain contiguity
  obligation. Both are strictly stronger for this module.
- **Prover-side "helpfulness" that could mask a bug:** `prove_inner` buckets an
  out-of-table lookup value into entry 0 (`protocol.rs:293`) and an
  exp/act miss into entry 0 (`:300`, `:306`) rather than refusing. That is the
  right choice — it means only the LogUp identity can catch such a value, so
  the tamper tests exercise the verifier and not a prover assertion, as
  `tamper.rs:1-11` claims. I confirmed there is no prover-side relation check
  anywhere in `prove_inner`.
- **`lookup_values` uses `wrapping_add`/`wrapping_mul`** (`protocol.rs:211`)
  while the argument computes the same expression in `Fp2`. For a malicious
  witness with huge `i64` plane values the two disagree and the slot relation
  fails — a completeness issue for dishonest provers only, not a soundness
  hole. Honest values are far below the wrap point.
- **Witness arithmetic is unchecked `i64`** (`witness.rs:79-99`, `:150`, `:170`)
  where the kernel uses `checked_*`. I bounded each site over the classes
  already enforced upstream (`ss ≤ 1 + 16·2^30`, `num ≤ 2^34`, `zacc ≤ 2^26`,
  `hacc ≤ 2^30`) and none can overflow, which is also why the kernel's
  `Overflow` refusals are listed unreachable in `refusals.rs:263-279`. The
  1,200-case parity sweep would catch a divergence.
- **`witness::rms_norm` adds refusals the kernel does not have**
  (`witness.rs:154-156`, the `< 2^24` limb window). `refusals.rs:283-285`
  asserts the premise that makes them unreachable (`D ≤ 2^17`, `a1, a2 ≤ 2^18`),
  so parity is preserved. Correct handling.

## 12. What I did not read, and what this review does not establish

Said plainly, because a green review is worth only what it covered.

- **The proof machinery underneath.** `crate::sumcheck` (including
  `sumcheck::verify`, `masked_prove`, `masked_terminal`, `CfsMask`),
  `crate::zk` (`mask_commit`, `mask_open`, `mask_verify`, `MaskFunctional`,
  `ZkRng`), `crate::pcs` (`commit_zk_owned`, `open_zk`, `verify_zk`, the
  grouping rule `part_key` mirrors), `crate::private_seam`,
  `crate::transcript` and `crate::merkle` were **not** reviewed. The block
  module uses them exactly as the accepted attention component does, and R-1 /
  R-2 reviewed them there; I verified only that the *usage* is unchanged.
- **`crate::mle`** — I read `fold_cols_i8` and `fold_rows_i8`
  (`zkp-core/src/mle.rs:116-149`) because the new matmul arms turn on their
  orientation. `eq_table_msb`, `eq_point`, `eval_mle_ext` I took on trust from
  the accepted component's use of them.
- **`causal_oracle.rs`** — I read only `public_synthetic_registration`'s
  `calibration_identity`, `e_r` and `e_r2` (lines 116, 146, 194), to check the
  pinning test. I did not review `FixedCausalOracle::build`, which
  `witness_equals_the_independent_fixed_causal_oracle` compares against.
- **`tables_v3::int16out_member`** (the frozen SiLU member `(-3, -11)`) and
  `tables_attn::{rope_tables_generate, exp_member}` — the fixtures' table
  generators. They are public test data by construction.
- **I ran nothing.** No `cargo`, no test, no example, no proof. The "38 unit +
  4 integration tests pass", the 0.09 s prove time and the observed receipt
  bytes are the implementers' and the security owner's measurements, not mine;
  I re-derived the 2,816,472 figure arithmetically (N-7) and checked that the
  test asserts it, which is not the same as seeing it.
- **The Python tool lane** (`scripts/zk60_private_block_inventory.py`,
  `tests/test_zk60_private_block_inventory.py`,
  `results/zk60_private_block_tools/`) was excluded from my brief and I did not
  open it. Disposition condition 4 therefore stands unmet as far as this
  review can tell (N-1).
- **`results/zk60_private_block_evidence/`** — I noted the two committed
  binaries exist (a 2,816,472-byte receipt and a 112-byte policy) but did not
  parse them.
- **Completeness in general.** I checked that each new class is provable by the
  honest witness (§5) and that `SH_U = 0` is routed around the shared
  requantizer, but I did not prove that an honest witness always exists inside
  every range. The disposition already records that as unchecked.
- **No privacy property is established here.** Not by §9's exposure survey, not
  by the smoke test it cites, not by anything else in this document. The
  joint-view gate on captured receipts, D8, D9 and D11 are all untouched.
