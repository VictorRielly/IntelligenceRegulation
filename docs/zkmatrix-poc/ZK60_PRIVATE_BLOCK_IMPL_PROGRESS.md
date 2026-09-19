# ZK60 private block — implementation progress (lane `zk60-private-block`)

Worktree `/home/victor/wt-zk60-private-block`, branch `zk60-private-block`,
opened from the design lane tip `58f6150`. SOLE WRITER: one implementation
agent at a time. This file is the hand-off record: any later agent reads the
stage table, then the log from the bottom, and continues at "precise next
step".

**What is being built.** A COPY of the accepted native private attention
component (`hashline/src/private_attention*`), grown into a complete private
transformer block (attention, `norm_m`, SiLU feed-forward, residual 2) in one
proof with no seam, per
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` (rulings
R-A, R-B and the six conditions of section 3), `..._CONSTRUCTION.md` (T1) and
`..._CONSTRUCTION_TIER2.md` (T2), with the 22 errata already applied to both
memos. The accepted attention files are NEVER edited: byte identity against
`zk60-attention-compile` is an acceptance gate of every stage.

**This is not a privacy acceptance and carries no speed claim.** Nothing here
establishes a privacy property; D8/D11 stay open (disposition section 5).

## Stages

| Stage | What | Status |
|---|---|---|
| S0 | SCAFFOLD: `private_block` module as a faithful copy under new names, WIP profile `hashline-zk-mr1/private-block-t32-wip/0`, all digest/magic/parameter strings forked | DONE |
| S1 | TESTS FIRST: `private-block-kernel` as a dev-dependency; deterministic generator of public synthetic inputs/weights; witness-vs-kernel parity for the attention half (up to `xres1`) over >= 1,000 inputs including refusals | DONE |
| S2 | WITNESS AND LAYOUT GROWTH: whole-block layout (A 455 / H 384 rows) and witness (`norm_m`, `g8`, `a16`, `u16`, `h16`, `z16`, remainders, residual 2) with kernel semantics; parity extended to `xres2` and every intermediate | DONE |
| S3 | ARGUMENT: the new define arms, slots, sites; the tamper tests of T2-check section 8 | not started (next agent) |
| S4 | The block profile `hashline-zk-mr1/private-block-t32-poc/1`, `BlockPublic` with the E-2 activation-table range check, the output endpoint moved to `xres2`, the tripwire `block_output_cannot_be_chosen` (T1-check section 11.3) | not started (next agent) |
| S5 | The checking tools re-run on the real Rust source (disposition condition 4) | not started (next agent) |

Condition 1 of the disposition (errata E-1) BINDS every stage before S4:
nothing in this module may carry the block profile string, a type named
`BlockPublic`, or an output endpoint on `xres2`, until the feed-forward
relations of T2 are proved in the same commit.

## QUESTIONS FOR THE SECURITY OWNER

Neither of these blocked S0-S2; both are recorded because a later reader
should not mistake a green test for more than it covers.

1. **Refusal-site coverage of the parity sweep.** The 1,200 generated cases
   reach nine of the kernel's refusal sites (`Q`, `K`, `V`, `QR`, `score`,
   `residual 1`, `FFN gate`, `FFN down`, `residual 2`). They never reach
   `KR`, `O`, `AO`, `FFN up`, `FFN product`, `exp difference`,
   `softmax denominator`, `softmax quotient/remainder`,
   `causal maximum attainment`, or either `norm` site. Some of those look
   close to unreachable at this calibration by arithmetic rather than by
   luck (`|y| <= gamma/2 <= 63` always, so the norm quotient cannot leave
   its class; `o8` is a weighted average of `v8`, so `O` cannot); others are
   reachable and the generator simply refuses earlier. Should the next stage
   add hand-built witnesses that force each remaining site, so that
   "same site, same message" is tested at every site rather than at nine of
   them? It is cheap; I did not do it because the brief fixed the scope at a
   generated sweep.
2. **Where E-2 lives.** The activation table is held as `i16`, which the
   erratum allows in place of a range check ("or holds it as `[i16; 256]`"),
   but it is held today by `FeedForwardPublic`, which is NOT part of the
   proved statement and is absorbed nowhere. When the next stage folds those
   words into `BlockPublic`, the `i16` type should be kept rather than
   replaced by `Vec<i64>` plus a check, and the table must then enter the
   public-statement digest. Confirm that reading of E-2 before that commit.

## Log

### 2026-09-19 — S0 SCAFFOLD (done)

New files, each a copy of the accepted attention file with the renames below
and nothing else changed:

| new | from |
|---|---|
| `hashline/src/private_block.rs` | `src/private_attention.rs` |
| `hashline/src/private_block/{layout,witness,argument,protocol,wire,tests}.rs` | `src/private_attention/*` |
| `hashline/examples/zk60_private_block.rs` | `examples/zk60_private_attention.rs` |
| `hashline/tests/zk60_private_block.rs` | `tests/zk60_private_attention.rs` |

`src/private_attention/tests.rs` had to be copied too (it is `mod tests` of the
module; without it the copied unit tests would not exist). The only edit to an
existing Rust file is the single line `pub mod private_block;` in
`hashline/src/lib.rs`, next to the attention export.

The copy was produced by a deterministic, re-runnable script, kept at
`/tmp/.../scratchpad/s0_copy.py` (a scratch file, not committed); the
replacement list below IS the record.

**Every string changed** (explicit replacements first, so that the profile
never passes through the forbidden final string; then the three generic
renames `private_attention`->`private_block`, `private attention`->`private
block`, `Private attention`->`Private block`, which cover module paths, doc
text and the `"private attention: ..."` error-message prefixes):

| kind | accepted attention value | WIP block value |
|---|---|---|
| profile / Fiat-Shamir domain (`PROFILE`, `Transcript::new`, `ZkRng::from_os`) | `hashline-zk-mr1/private-attention-t32-poc/1` | `hashline-zk-mr1/private-block-t32-wip/0` |
| public-statement digest domain | `hashline/private-attention-public/1` | `hashline/private-block-wip-public/0` |
| schedule digest domain | `hashline/private-attention-schedule/1` | `hashline/private-block-wip-schedule/0` |
| `describe()` line 0 (hashed into the schedule digest) | `private-attention-t32/1: ...` | `private-block-t32-wip/0: ...` |
| expected-policy frame magic | `HATTEXP1` | `HPBWEXP0` |
| receipt wire magic | `HLPATTN\x01` | `HLPBWIP0` |
| absorbed `"parameters"` payload | `T32/d16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/two-private-endpoints` | same + `/block-wip` |
| per-slot transcript labels | `pa-slot`, `pa-scalar`, `pa-term` | `pb-slot`, `pb-scalar`, `pb-term` |
| example artifact names | `attention_receipt.bin`, `attention_expected.bin` | `block_receipt.bin`, `block_expected.bin` |
| test / example context strings | `... private attention ...` | `... private block ...` (generic rename; the three contexts therefore differ from the attention ones) |

So no transcript, digest or wire magic is shared with the accepted profile.
The generic rename also forked the `IoSpec` context strings used by the tests
and the example, which are hashed into `ExpectedIo`.

**Deliberately NOT changed (condition 1 / E-1 of the disposition).** The final
block profile string `hashline-zk-mr1/private-block-t32-poc/1` appears nowhere
(the copy script asserts its absence). The public-statement type is still
called `AttentionPublic`, not `BlockPublic`, and still covers exactly the
attention weights and tables; the output endpoint still carries `xres1`. The
module, example and test headers were hand-edited to say plainly that this
profile proves the ATTENTION HALF ONLY and that no block statement follows
from a receipt. Per ruling R-B the per-slot labels were not renamed to `pb-*`
inside `SLOT_NAMES` (not required once R-A removed the shared code path); only
the three transcript labels above carry the `pb-` prefix.

**Commands and results** (all under `flock -w 540 /tmp/zk-build.lock`, offline,
`-j 2`, `CARGO_TARGET_DIR` = the design lane's warm target, release overrides
`LTO=false CODEGEN_UNITS=8`, exactly as the accepted delivery's own evidence
`results/zk60_private_attention_native_evidence/compile/report.json` used):

1. `cargo check --lib --tests --examples` -> exit 0, 4.71 s. Only the 8
   pre-existing `src/attention.rs` warnings; `private_block` produced none.
2. `cargo test --release --lib private_ -- --test-threads=1` -> **22 passed,
   0 failed**, 9.73 s (11 pre-existing `private_attention::*` + the 11 copies
   `private_block::*`, including `layout::tests::declared_counts_are_self_consistent`).
3. `cargo test --release --test zk60_private_block -- --test-threads=1` ->
   **4 passed, 0 failed**, 3.05 s.
4. `cargo test --release --test zk60_private_attention -- --test-threads=1` ->
   **4 passed, 0 failed**, 3.00 s (the accepted component is unaffected).
5. `cargo test --release --doc private_block` -> **1 passed** (the
   `compile_fail` one-use-endpoints doctest still fails to compile, as claimed).
6. Byte-identity gate: `git --no-pager diff --stat zk60-attention-compile --
   hashline/src/private_attention.rs hashline/src/private_attention
   hashline/examples/zk60_private_attention.rs
   hashline/tests/zk60_private_attention.rs` printed NOTHING.

No deviation from the brief in S0.

**Next step:** S1 — add `private-block-kernel` as a path dev-dependency of
hashline, check that `--offline` still resolves, and write the fixed-seed
public synthetic generator plus the witness-vs-kernel parity harness for the
attention half in `hashline/tests/zk60_private_block.rs`.

### 2026-09-19 — S1 TESTS FIRST (done)

**Dev-dependency.** `hashline/Cargo.toml` gained

```
[dev-dependencies]
private-block-kernel = { path = "../private-block-kernel" }
```

`cargo check --offline` resolved it with no network: `Locking 1 package …
Adding private-block-kernel v0.1.0 (/home/victor/wt-zk60-private-block/private-block-kernel)`,
then `Finished dev profile in 3.44s`. `hashline/Cargo.lock` gained the one
entry. The kernel crate is standalone (`[workspace]` in its own manifest, no
dependencies), so nothing enters the library or the binary — it is linked into
test binaries only.

**DEVIATION (location of the harness), with the reason.** The brief says to
write the parity harness "in the new test file". A witness-LEVEL harness has
to read `witness::Witness::planes`, which is `pub(crate)`; an integration test
under `hashline/tests/` sees only the public API (`compute_output`, i.e.
`xres1` alone) and could not compare one intermediate plane. The harness is
therefore a new crate-internal test module,
`hashline/src/private_block/parity.rs`, reached by one added line
`#[cfg(test)] mod parity;` in `hashline/src/private_block.rs`. It is a new
file in the new module, so it breaks no rule about accepted files, and
`cargo test --lib` runs it. `hashline/tests/zk60_private_block.rs` is
unchanged from S0. No existing test was weakened or deleted.

**What the harness is** (`parity.rs`, 260 lines):

* `Rng` — SplitMix64 seeded by a fixed lane constant mixed with the case
  index. No OS randomness, no clock, no hashing of addresses: case `i` gives
  the same bytes in every process. A test asserts that directly.
* `case(idx)` — one PUBLIC SYNTHETIC statement: `wq, wk, wv, wo` and the two
  gains, plus `wg_t, wu_t, wd_t` for the kernel, as diagonal-64 matrices with
  a signed random band; the three fixed public tables (rope pair and exp from
  `tables_attn`, the frozen int16-out SiLU member `(-3, -11)` from
  `tables_v3`, i.e. the fixture's activation table); and a random i16 input.
  Four knobs sweep the cases: the attention band (13 values, 0..127), the norm
  gain (4), the input amplitude (7 values, 1..32767) on a 13 x 4 x 7 grid that
  1,200 cases cover completely, and the feed-forward band swept independently
  at stride 11 (coprime with 364, so all 1,200 four-tuples are distinct). The
  large amplitudes are what pushes a case into a refusal.
* `witness_equals_the_reference_kernel_over_the_generated_sweep` — for each of
  1,200 cases it runs `kern::run_block_slice` with a `Trace` and
  `witness::build`, and sorts the outcome into three buckets: both accept
  (every attention plane compared element for element), both refuse (the two
  refusal STRINGS must be equal — same site, same text), or the kernel refuses
  where this witness accepts. The fourth combination (the witness refusing
  where the kernel accepts) panics.
* Bucket 3 exists only because this witness stops at `xres1` while the kernel
  runs the whole block. It is not a loophole: entering it requires that the
  kernel finished the attention half (every `na_dd` >= 1, which `ceps = 1`
  guarantees for an honest run, so a refusal inside `norm_a` cannot hide
  here), that every plane the kernel traced still agrees element for element,
  and that the refusal site is one of the seven block-half sites. A constant
  `WITNESS_COVERS_BLOCK` (false today) turns the whole bucket into a hard
  failure the moment the witness grows to the block, so S2 cannot quietly
  inherit the allowance.
* Values are never printed: `eq()` reports only the differing count and the
  first differing index, as the kernel's own `Trace` documentation requires.

**Planes compared when both accept** (element for element, 1,200 cases):
`norm_a D` (`A_D` vs `na_dd`), `norm_a y`, `q8`, `k8`, `v8`, `qr8`, `kr8`,
`s8`, `row max`, `row sum`, `softmax p`, `o8`, `ao`, `xres1`, plus two planes
the kernel does not carry directly: `A_DSQ` against `na_dd^2` and the one-hot
`A_ZSEL` against the kernel's `arg`. The committed output plane
(`Witness::output()`) is compared against `tr.xres1` too.

**Result of the sweep** (release, 1,200 cases, 0.28 s):

```
905 accepted by both, 201 refused identically by both,
 94 refused by the kernel in the block half only
  Q 4, K 4, V 6, QR 3, score 168, residual 1 16          (identical refusals)
  FFN gate 2, FFN down 8, residual 2 84                  (block half, no witness counterpart yet)
```

No plane mismatch and no refusal-message mismatch anywhere. Six distinct
attention-half refusal sites are exercised. Sites the sweep does NOT reach
(recorded so the next agent does not read the green test as more than it is):
`KR`, `O`, `AO`, `exp difference`, `softmax denominator`,
`softmax quotient/remainder`, `causal maximum attainment`, and both `norm`
sites — for the last of these the arithmetic says they are close to
unreachable at this calibration (`|y| <= gamma/2 <= 63` always, and
`rho < den = D 2^12 < 2^29` unless every input word is near 32767).

**Commands** (all `flock -w 540 /tmp/zk-build.lock`, offline, `-j 2`, the warm
target dir, release overrides):

1. `cargo check --lib --tests --examples` -> exit 0, 3.44 s (the resolve above).
2. `cargo test --release --lib private_block -- --test-threads=1 --nocapture`
   -> **13 passed, 0 failed**, 5.09 s (11 copied + the 2 new parity tests).
3. `cargo test --release --lib private_ -- --test-threads=1` -> **24 passed,
   0 failed**, 9.84 s (the 11 accepted-component unit tests included).
4. Byte-identity gate against `zk60-attention-compile`: empty.

*(superseded; S2 is done — see below)* **Next step:** S2 — read T1 sections C.1-C.2 and T2 sections A-B, grow
`layout.rs` (the whole-block planes, limb/helper planes, the activation
multiplicity row, `Dom::F`, the derived counts A 455 / H 384 asserted in code)
and `witness.rs` (`norm_m`, `g8`, `a16`, `u16`, `h16`, `z16`, the remainders
`rg`, `rh`, `rd` with the kernel's BIASED requantization identity, residual 2,
every refusal), then set `WITNESS_COVERS_BLOCK = true` and extend the harness
to `xres2` and every new intermediate.

### 2026-09-19 — S2 WITNESS AND LAYOUT GROWTH (done)

**HOW THE MODULE WAS KEPT CONSISTENT (the brief's escape hatch, used).**
Growing one `Layout` would have changed `a_rows` from 306 to something that is
neither 306 nor 455 — the argument still declares eighteen slots and 75 `A`
sites, so the grown planes alone give 365 rows — and would have broken the
copied tests, the receipt size and the module's own site/group assertions. So
layout.rs now builds **two layouts over ONE plane numbering**:

* `Layout::new()` — the WORK-IN-PROGRESS layout the argument proves: the
  accepted component's 50 `A` planes and 35 `H` planes, eighteen slots, 154 /
  306 `A` rows, 218 / 290 `H` rows, 40 `M` rows, 30 / 8 opening groups. Byte
  for byte the same statement as before; only the plane ids moved.
* `Layout::new_block()` — the grown whole-block layout: all 81 `A` planes and
  51 `H` planes, 23 slots, **213 / 455 `A` rows, 280 / 384 `H` rows, 50 `M`
  rows, 34 functionals, 120 / 51 claim sites, 35 / 9 opening groups, 61,440
  U8 lookups**. Those are the disposition section 1.2 / T2 section D.2 numbers
  and `new_block` ASSERTS the four row totals itself, so a layout edit that
  breaks them cannot ship.

The single numbering is the block's, laid out **contiguously per domain**
(`Dom::T`, `Ht`, `L`, `D`, `Q`, `Kv`, `S`, `F`, `Tab`) because T2 section C.2
makes contiguity a layout-ordering obligation on the implementer: `SC_DZC`'s
`a_range` must sweep one plane block. `Layout::new()` simply omits the
block-only planes and packs the rest in plane order, so the relative order of
the attention planes — and therefore the PCS grouping, which keys on
`(point tail, offset % 256, len)` with every plane row-aligned — is unchanged.
A plane a layout does not hold carries the offset `ABSENT = usize::MAX`, and a
test asserts exactly which planes that is on both sides. `lookups`, `helpers`
and `LOOKUP_DOMS` became layout methods, since the lists differ (`Dom::D`: 20
lookups in the WIP layout, 38 in the block; `Dom::L`: 1 vs 2; `Dom::F`: 0 vs
9), and `argument.rs` / `protocol.rs` now read them off the layout they were
given, which makes the WIP argument correct by construction rather than by
convention.

**Planes added** (T1 C.1-C.2, T2 B.2), 31 on `A` and 16 on `H`:

* `Dom::T`: `A_DM`, `A_DSQM`. `Dom::L`: `A_LIMBM` (nine of sixteen sub-planes,
  the faithful mirror of `A_LIMB`).
* `Dom::D`: `A_YM` (= `nm`), `A_MR0..3`, `A_MS0..3`, `A_Z16`, `A_X2`,
  `A_X2L0/L1`, `A_ZL0/L1`, `A_RDL` — 16 planes.
* `Dom::F` (new variant, `log = 9`): `A_G8`, `A_RGL`, `A_A16`, `A_U16`,
  `A_UL0/L1`, `A_H16`, `A_HL0/L1`, `A_RH0/RH1` — 11 planes, 22 rows. There is
  NO `up` remainder plane: `SH_U = 0` (T2 A.4).
* `Dom::Tab`: `A_MACT`.
* `H`: `H_D0+10..+18` (Tier 1's 7 plus Tier 2's 2, taking `Dom::D` to 19
  helpers), `H_F0..+4`, `H_FACT`, `H_GACT`.

**Witness.** `witness::build` (attention half, what the argument proves) and
`witness::build_block` (the whole block) share one `build_inner`; the two
RMSNorm sites share one `rms_norm` helper, which is T1 C.1's point that
`norm_m` is the IDENTICAL relation with `gamma_m` for `gamma_a` and `xres1`
for `x_in`. `Witness::planes` is now `N_A` long with an EMPTY vector (never a
zero plane) for a plane this build does not fill. The block half follows the
kernel's order exactly, so the FIRST refusal is the same one: `norm_m`, gate
matmul + requant (`FFN gate`), up matmul + int16 class (`FFN up`), activation
lookup, product + requant (`FFN product`), down matmul + requant
(`FFN down`), residual 2 (`residual 2`). Every remainder is the BIASED one
(`r' = r + 2^(sh-1)`), the module's idiom. The gate class is the kernel's
`I8 = [-128, 127]`, NOT the attention subset — using `sym()` there would be a
completeness bug (T2 A.2), and the code says so at the site.

**New public surface** (deliberately small, and none of it a block claim):
`FeedForwardPublic` (gamma_m, Wg, Wu, Wd as the kernel stores them, and the
activation table as `Vec<i16>` — erratum E-2 discharged by the TYPE rather
than a check, ready to move into `BlockPublic`), `compute_block_output`
(a reference value, documented as not a proof artifact) and `block_schedule()`
(the grown layout's declared description; tagged `private-block-t32/whole-block`,
which is NOT a profile string and is absorbed nowhere).

**E-1 is respected.** The argument, the profile string, the wire magic, the
transcript and the output endpoint are untouched: `SC_IO_OUT` still binds
`A_X1`, there is no `BlockPublic`, and `hashline-zk-mr1/private-block-t32-poc/1`
appears nowhere. The block planes carry no relation, which is exactly why this
commit proves nothing new — it is layout and arithmetic only.

**Parity, extended.** `parity.rs` gained
`the_whole_block_witness_equals_the_reference_kernel`, the same 1,200
generated cases through `witness::build_block`, with only TWO outcomes
allowed: both accept or both refuse identically. It compares, element for
element: every attention plane as before, plus `norm_m D`, `norm_m D^2`,
`nm`, `g8`, `a16`, `u16`, `h16`, `z16`, `xres2`, the four two-limb int16
decompositions (and that every limb is a byte), the three BIASED
requantization identities recomputed from the kernel's own `nm`/`a16`/`h16`
(`gacc = 2^7 g8 + rg - 2^6`, `hacc = 2^14 h16 + rh - 2^13`,
`zacc = 2^6 z16 + rd - 2^5`) with each remainder in its exact window,
`xres2 = xres1 + z16`, the classes of `g8` and `nm`, and that every plane the
grown layout declares is filled at its declared length. The block output is
compared with `run_block`'s return value.

```
whole-block parity: 1200 cases — 905 accepted by both, 295 refused identically
  Q 4, K 4, V 6, QR 3, score 168, residual 1 16,
  FFN gate 2, FFN down 8, residual 2 84            (nine distinct sites)
```

No mismatch anywhere. The attention-half harness still runs beside it (905 /
201 / 94), which is what keeps the WIP argument's own witness honest.

**DEVIATIONS from the design, recorded.**
1. `Layout::new_block()` is a second constructor rather than a grown
   `Layout::new()`, for the reason above. The brief explicitly allows this;
   T1 and T2 assume one grown layout, which becomes true when the argument
   moves over in the next stage (delete `a_in_wip` / `h_in_wip`, the `block`
   flag and the WIP slot tables, and the two collapse into one).
2. The whole-block `describe()` is tagged `private-block-t32/whole-block` and
   its digest still uses the WIP digest domain, because nothing absorbs it.
   The stage that absorbs it must give it the final domain with the final
   profile string.
3. `SLOT_NAMES` was not renamed to `pb-*` (ruling R-B leaves that optional).
4. Five `BC_*` slot indices and `Layout::limb_off_m` carry
   `#[allow(dead_code)]` with a reason: they are the handles the next stage's
   argument arms use. No other new item is unused; `private_block` compiles
   with zero warnings.

**Commands** (all `flock -w 540 /tmp/zk-build.lock`, offline, `-j 2`, warm
target dir, release overrides):

1. `cargo check --lib --tests --examples` -> exit 0, no `private_block`
   warning (the only 8 warnings are the pre-existing `attention.rs` ones).
2. `cargo test --release --lib private_block -- --test-threads=1 --nocapture`
   -> **16 passed, 0 failed**, 5.31 s.
3. `cargo test --release --lib private_ -- --test-threads=1` -> **27 passed,
   0 failed**, 10.11 s (the 11 accepted-component unit tests included).
4. `cargo test --release --test zk60_private_block --test zk60_private_attention`
   -> **4 + 4 passed, 0 failed**.
5. `cargo test --release --doc private_` -> **2 passed**.
6. The example still proves and verifies: `prove` 0.083 s, frame 2,245,800
   bytes (unchanged, as the WIP geometry is unchanged), `verify` in a fresh
   process ACCEPT in 0.035 s with all three negative controls refused. Run
   under the session scratchpad, nothing written into the repository.
7. Byte-identity gate against `zk60-attention-compile`: empty.

**Next step (S3, the next agent):** the argument's new arms. In order:
`SC_SSM` and the extended `SC_TZC` (T1 C.1), the extended `SC_DZC` terms
`c6..c10` and its second host (T1 C.1-C.2, T2 C.2), `SC_GMM` / `SC_UMM` /
`SC_DMM` and the new `SC_FZC` (T2 C.1), the third `SC_TAB` triple with
`TAG_ACT = 134` and `table_values_act` (T2 A.7), and `fold_cols_i8` added to
this module's `argument.rs` imports for the `(input, output)` feed-forward
matrices. Switch `argument.rs` and `protocol.rs` to `Layout::new_block()` in
the same commit, then delete the WIP slot tables and the `a_in_wip` /
`h_in_wip` filters. The tamper tests of T2-check section 8 belong to that
commit. S4 then lands the block profile, `BlockPublic` (fold
`FeedForwardPublic` in, keep the `i16` activation table), the output endpoint
move to `A_X2` and the tripwire `block_output_cannot_be_chosen` — all three
together, never before, and with the honest-proof assertion beside it.
