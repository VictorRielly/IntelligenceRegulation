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
| S3a | REFUSAL-SITE PARITY: a hand-built forcing case for every reachable kernel refusal site; the arithmetic and a premise test for every unreachable one | DONE |
| S3b | ARGUMENT: the new define arms, slots, sites; the module moves to the whole-block layout | DONE |
| S3c | TAMPER TESTS at the verifier (T2 section G as corrected by E-18 … E-20), by slot INDEX | DONE |
| S4 | The block profile `hashline-zk-mr1/private-block-t32-poc/1`, `BlockPublic` with the E-2 activation-table range check, the output endpoint moved to `xres2`, the tripwire `block_output_cannot_be_chosen` (T1-check section 11.3) | DONE |
| S5 | The checking tools re-run on the real Rust source (disposition condition 4) | DONE — new driver `scripts/zk60_private_block_inventory.py`, evidence under `results/zk60_private_block_tools/`. 46/46 derived counts equal the design, 11/11 verdict gates pass, 22/22 negative controls fire (including the two owed ones), no difference against the paper whole-block run. Four parser adapters were needed (B-1…B-4). This is NOT a privacy acceptance: the verdicts are about a linear-algebra model, and the captured-receipt joint-view gate stays unmet. |

Condition 1 of the disposition (errata E-1) BOUND every stage before S4:
nothing in this module could carry the block profile string, a type named
`BlockPublic`, or an output endpoint on `xres2`, until the feed-forward
relations of T2 were proved in the same commit. It is MET: S3b landed the
relations, and S4 landed all five guarded things plus the tripwire in one
commit on a green tree.

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

### Answers from the security owner (2026-09-19 04:06)

Before answering I re-checked S0–S2 myself: the accepted attention files,
`zk.rs`, `layer.rs`, `zk_ffn_fresh_io.rs`, `private_seam.rs`, `scripts/` and
the Python suite are byte-identical to `zk60-attention-compile`; the lane
changed only new files plus one line of `lib.rs` and the dev-dependency; and
my own run of `cargo test --release --lib private_` gave 27 passed, 0 failed.

1. **Yes — add the hand-built refusal cases, in S3, before the argument
   arms.** For every refusal site that is reachable, build the smallest
   public synthetic input that forces it and assert "same site, same
   message" against the kernel. For every site you believe unreachable at
   this calibration, do **not** force it by bypassing the generator: write
   the bound that makes it unreachable next to a test that asserts the
   bound's premise where that is cheap (for the norm sites, `|y| ≤ 63`), and
   list the site in this ledger as "unreachable at this calibration" with the
   arithmetic. Why it matters although it is not a soundness question (the
   range proofs refuse an out-of-class witness regardless): a site where the
   witness builder accepts what the kernel refuses, or the reverse, is a
   place where the proof would speak about a computation the reference does
   not define, and condition 6 of the disposition asks for parity including
   the refusal site and string.
2. **Confirmed, and it is a requirement rather than a preference.** Keep the
   activation table as `[i16; 256]`: a type cannot be forgotten by a second
   constructor, a runtime check can. When S4 folds it into `BlockPublic` the
   table's words **must** enter the public-statement digest (little-endian
   `i16` words under the block's own digest domain), together with `gamma_m`
   and the three feed-forward weight matrices; until they do, the statement
   does not bind the table the lookup is proved against, which is one more
   reason the block profile string may not appear before S4. If
   `BlockPublic` is ever parsed from bytes, the parser refuses any word that
   does not fit `i16` rather than truncating it.

### Security owner's check of S3a–S4 and ruling on the calibration literal (2026-09-19 05:14)

Verified by my own runs, recorded in
`results/zk60_private_block_evidence/README.md`: accepted files byte-identical;
the lane's only edits to existing files are the module export, the
dev-dependency and the one constant `TAG_ACT = 134`; 38 unit, parity and
tamper tests and 4 integration tests pass; the example proves the whole block
under the final profile and a fresh process verifies the 2,816,472-byte
receipt, exactly the design's figure, and refuses three corruptions. I read the
tripwire's source: it is the strong form condition 1 asks for.

**Ruling on deviation (d), the calibration digest as a literal: accepted for
this proof of concept.** The literal is absorbed under the `"calibration"`
label before any challenge, so the statement is bound to that calibration, and
the test pinning it to `causal_oracle::public_synthetic_registration` must
stay. It becomes wrong the day a second calibration or registration exists:
from then the digest is a field of the public statement taken from the
caller's approved contract, not a module constant. Record that as a follow-up,
not as work for S5.

The other findings are accepted as reported: the two layouts collapsing to
one; the attention-half parity test subsumed by the whole-block test, which
compares every plane; and T-z1 re-homed as the endpoint test with the class
tested by the `(+256, −1)` limb shift on all four feed-forward limb pairs,
which isolates where the memo's row did not.

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

### 2026-09-19 — S3a REFUSAL-SITE PARITY (done)

The security owner's answer 1, discharged. New file
`hashline/src/private_block/refusals.rs` (`#[cfg(test)]`, reached by one added
line in `private_block.rs`); nothing else changed.

**What it is.** A `Forced` case is a PUBLIC SYNTHETIC statement in which every
weight matrix is a CONSTANT fill, the RoPE pair is a constant at every position
`t >= 1` (position 0 stays `(2^fRo, 0)`, which both constructors require), the
activation table is a constant, and the input is a constant. That makes the
value arriving at the target site a one-line product, so each case carries the
arithmetic that forces it in a `why` field rather than being found by search.
Shared background: a constant row gives `ss = 1 + 16 x^2`, `D = 4|x|`,
`y_i = floor((x gamma + D) / (2 D))`; so `(x, gamma) = (1, 127)` gives `y = 16`,
`(-1, 127)` gives `y = -16`, and `gamma_a = 0` gives `y = 0`, which switches the
attention half off and drives the feed-forward straight from `xres1 = x`.

**Twelve reachable sites forced, each matching the kernel's message exactly**
(`fixed oracle range refusal: <site>`), and a case that ACCEPTS fails the test
too, so a case cannot silently stop testing anything:

| site | the forcing arithmetic |
|---|---|
| `Q` | `y = 16`, `qacc = 16·16·127 = 32,512`, `requant(·,7) = 254` |
| `K` | `wq = 0`, `kacc = 32,512` |
| `V` | `wq = wk = 0`, `vacc = 32,512` |
| `QR` | `wq = 63` gives `q8 = 126` (in class); rope `(128, -128)` at `t >= 1` gives `c·a − s·b = 32,256 -> 252` |
| `KR` | `wq = 0` so `qr8 = 0`; `k8 = 126` with the same rope pair |
| `score` | identity rope keeps `qr8 = kr8 = 126`; `sacc = 8·126² = 127,008 -> 1,984` |
| `residual 1` | `x = 32,767`, `v8 = 126`, `sum_j p[j] <= 512` so `o8 = 126`; `aoacc = 256,032 -> ao = 2,000`; `32,767 + 2,000` leaves int16 |
| `FFN gate` | `gamma_a = 0` so `xres1 = 1`, `nm = 16`; `gacc = 32,512 -> 254` leaves `[-128, 127]` |
| `FFN up` | `xres1 = -1`, `nm = -16`, `wu = -128`: `uacc = +32,768`, ONE above int16 — the tightest case in the set, and the reason `SH_U = 0` still owes a class proof |
| `FFN product` | `u16 = -32,512`, `a16 = 32,767`: `hacc = -1,065,320,704`, `requant(·,14) = -65,023` |
| `FFN down` | `u16 = 16,384`, `a16 = 32,767` gives `h16 = 32,767` exactly; `zacc = 66,582,544 -> 1,040,352` |
| `residual 2` | `xres1 = 32,767`, `h16 = 1`, `z16 = 1`: `32,768` leaves int16 |

**Eight sites are UNREACHABLE at this calibration**, and the test asserts each
bound's premise instead of bypassing the builder to force it:

| site | the bound |
|---|---|
| `norm denominator` (both norms) | over the int16 class the VERIFIER enforces on `x_in` (`c2`) and on `xres1` (`c4`) — not over the prover's `&[i16]`, which R-2's method does not admit — `ss <= 1 + 16·2^30 < 2^35`, so `ss > 0`, `D = isqrt(ss) <= 2^17` and `den = 2·D·2^11 >= 2^12 > 0`. The witness's own limb window also holds: `a1 = ss − D² <= 2D` and `a2 = 2D − a1 <= 2D`, both `<= 2^18 < 2^24` |
| `norm quotient/remainder` (both norms) | `|x_i| <= D` (since `D = isqrt(ceps + sum x²) >= isqrt(x_i²)`) and `|gamma| <= 128`, so `q = floor((x_i·gamma + D)/(2D))` is in `[-64, 64]`, inside `[-127, 127]`; and `rho, sigma < den = D·2^12 <= 2^29` |
| `causal maximum attainment` | the score class is `[-127, 127]`, `MASK = -127` is its minimum, and the masked max takes the FIRST strict maximum, so index 0 (always `<= t`) wins any tie against a masked position |
| `exp difference` | `delta <= 127 − (−127) = 254 < 256`, and `delta >= 0` because `max` is the maximum |
| `softmax denominator` | `exp[0] = 2^9` at `j = arg` and every entry is in `[0, 2^9]`, so `2^9 <= total <= 32·2^9` |
| `softmax quotient/remainder` | `q = floor(e_j·2^9/total) <= 2^9` since `e_j <= 2^9 <= total`; `sigma = total − 1 − rho` with `rho < total <= 2^14` |
| `O` | `sum_j p[j] = sum_j floor(e_j·2^9/total) <= 2^9` (asserted in its own test) and `|v8| <= 127`, so `|oacc| <= 65,024` and `requant(·,9)` lands in `[-127, 127]` |
| `AO` | `|aoacc| <= 16·127·128 = 260,096`, so `requant(·,7)` lands in `[-2032, 2032]`, well inside int16 |

The premises are asserted, not asserted-about: `d_max` is computed with the
module's own `isqrt`, the quotient bound is checked over the extremes of
`|x| <= D` and the i8 gain for nine values of `D` up to `d_max`, and
`sum_j p[j] <= 2^fP` has a test of its own over four row shapes and four
lengths.

**Commands** (all `flock -w 540 /tmp/zk-build.lock`, offline, `-j 2`, the warm
target dir, release overrides):

1. `cargo test --release --lib private_block::refusals -- --test-threads=1
   --nocapture` -> **3 passed, 0 failed**, build 41.09 s, tests 0.00 s. Every
   case reached its site on the first run; no arithmetic needed correcting.
2. `cargo test --release --lib private_ -- --test-threads=1` -> **30 passed,
   0 failed**, 10.12 s (27 before + the 3 new).

No deviation from the brief in S3a. `witness::isqrt` was already
`pub(crate)`; nothing in the module changed but the one `mod refusals;` line.

*(superseded; S3b is done — see below)* **Next step (S3b):** the argument's new arms.

### 2026-09-19 — S3b THE ARGUMENT (done)

**The whole block is proved.** The argument now runs twenty-three slots over
one `A`, one `H` and one `M`, and the chain
`x_in -> norm_a -> QKV/RoPE/softmax/PV/Wo -> xres1 -> norm_m -> nm ->
(g8, u16) -> a16 -> h16 -> z16 -> xres2` is closed link by link. An honest
proof on the public synthetic fixture VERIFIES, in the unit tests, in the
integration test (a fresh verifier from public data and receipt bytes only)
and in the example's separate verify process.

**ONE LAYOUT (the previous agent's planned collapse, carried out).**
`Layout::new()` IS the whole-block layout; `new_block`, the `block` flag,
`a_in_wip` / `h_in_wip`, `ABSENT` and the work-in-progress slot tables are
gone, and the `*_BLOCK` constants took the plain names. That is why
`wire.rs` needed **no edit at all** and `run_slot` / `sum_weights` /
`slot_terms` needed none either: they read `SLOTS`, `SLOT_KINDS`,
`SLOT_NAMES`, `A_SITES`, `H_SITES`, `M_ROWS`, `A_GROUPS`, `H_GROUPS` by name
and those names now carry the block's values.

**The new and changed arms** (`argument.rs`), each against its design text:

| slot | arm | design |
|---|---|---|
| 01 `SC_SSM` | `eq(r_t2) * A_X1^2`, a second private claimed sum at its own row point | T1 C.1 |
| 02 `SC_TZC` | `mu(6)`, `nu(2)`, tables `eq(tau), eq(r_t), eq(r_t2)`, then `A_D, A_DSQ`, nine `A_LIMB` sub-slices, `A_DM, A_DSQM`, nine `A_LIMBM` sub-slices; three new zero-check terms and a SECOND host term `nu1 eq(r_t2) (Dsqm + a1m - ceps)`. 22 A sites, shape unchanged `(5,1,3)` | T1 C.1, decision 6 |
| 03 `SC_LZC` | `a_range(A_LIMB, A_LIMBM)`: the single `Dom::L` helper moves into the TWO-lookup branch, so the slot is degree 4, `L = 42` | T1 C.1, decision 7 |
| 11/12/13 `SC_GMM`/`SC_UMM`/`SC_DMM` | `(4,1,2)` private matmuls, `v[0]*v[1]`; the gate and up share `r_tf` and read `A_YM`, the down draws `r_td` and reads `A_H16`; the public factor is `fold_cols_i8` (the `(input, output)` fold), NOT `fold_rows_i8` | T2 C.1, decisions 9, 10 |
| 14 `SC_DZC` | `mu(11 + 19)`, `nu(2)`, a third `eq(p_z)` table, a second broadcast gain table `gamma_m`, `a_range(A_X, A_RDL)` (35 planes), the `A_DM` sub-row beside `A_D`, 19 helpers; terms `c6, c7` (norm_m), `c8, c9` (residual 2), `c10` (`z16` int16) and the second host term `2^6 z16 + rd - 2^5`. 37 A / 19 H sites, shape unchanged `(9,1,4)` | T1 C.1-C.2, T2 C.2 |
| 18 `SC_FZC` | new host `(9,1,4)`: `a_range(A_G8, A_RH1)` (11 planes), five `Dom::F` helpers and `H_FACT`; `f0` (the product), `f1`, `f2` (the two int16 decompositions), `f_act` (the activation PAIR lookup), host terms `2^7 g8 + rg - 2^6` and bare `u16` | T2 C.1 |
| 19 `SC_TAB` | a third `(multiplicity, helper, public values)` triple `(A_MACT, H_GACT, table_values_act)` under `mu[2]`; shape unchanged `(8,1,3)` | T2 C.1, A.7 |

Erratum **E-17** is honoured literally: `f_act` reads `v[i_fact]` where
`let i_fact = b.h(H_FACT)?;` returns the TABLE index, never the plane
constant. Erratum **E-22** is why `f_act` binds the pair
`(g8 + 128) + beta*a16 + g_act` rather than two class lookups: wherever
`u16 = 0`, `f0` pins nothing about `a16`.

**Every count the module asserts, against the design.** All are asserted in
code, not just observed:

| quantity | design | asserted where |
|---|---:|---|
| `A` rows / data / site-pairs / prox | 455 / 213 / 240 / 2 | `Layout::new` itself, plus the layout test |
| `H` rows / data / site-pairs / prox | 384 / 280 / 102 / 2 | same |
| claim sites `A` / `H` | 120 / 51 | layout test |
| slots; private / standalone / host | 23; 12 / 5 / 6 | layout test |
| host groups | 6 | `HOSTS` |
| `M` rows / functionals | 50 / 34 | layout test, and `argument()` refuses a functional-count mismatch |
| opening groups `A` / `H` | 35 / 9 | **derived at run time**: `check_opening` rebuilds the grouping from the claim list by the PCS column key and refuses a mismatch on BOTH sides, so the honest proof verifying IS the check |
| largest slot `L`; `L + 256 <= 512` | 50; all | layout test |
| main / extension rounds | 159 / 25 | layout test |
| U8 / exp / act lookups | 61,440 / 2,048 / 512 | `ProveStats`, asserted in the unit test |
| host runs after every slot it hosts | yes | layout test |
| **receipt length** | **2,816,472 bytes** | asserted in the unit test AND the integration test; the example prints it |

The 35 `A` groups came out on the first run, which is the strongest single
confirmation of the whole schedule: the grouping is a function of every claim
point the twenty-three arms draw.

**DEVIATIONS, each with its reason.**
1. **One layout, not two** (above). T1 and T2 assume one grown layout; the two
   were a scaffold the brief allowed and the previous agent planned to remove.
2. **Two layout tests rewritten, none weakened.**
   `declared_counts_are_self_consistent` now asserts the WHOLE-BLOCK counts
   (it asserted the accepted component's 75/35/154/218, which the accepted
   `private_attention` module's own identical test still covers, untouched and
   green). `the_two_layouts_share_one_plane_numbering` became
   `planes_are_row_aligned_and_contiguous_per_domain`: it keeps every
   substantive assertion (plane order, distinct offsets, row alignment) and
   ADDS the contiguity obligation T2 section C.2 puts on the implementer,
   which the two `a_range` sweeps depend on.
3. **The attention-half parity test is gone; the whole-block one subsumes it
   strictly.** It compares every attention plane the removed test compared,
   plus every block plane, and allows no one-sided outcome at all — the
   `WITNESS_COVERS_BLOCK` allowance and `BLOCK_HALF_SITES` are deleted with
   it. `witness::build` is now the whole-block builder; `build_block` and the
   `Witness::block` flag are gone.
4. **The feed-forward words are absorbed under their own transcript label**
   `"feed-forward-statement"` instead of being folded into the one
   public-statement digest, because `BlockPublic` belongs to the S4 commit
   (disposition condition 1). They ARE bound — a receipt does not verify under
   any other `gamma_m`, `Wg`, `Wu`, `Wd` or activation word, and a test
   asserts that on all five — but as a SECOND absorb, which T2 section F says
   should not survive: S4 folds them into one digest and drops this label.
5. **ONE EDIT TO AN EXISTING FILE**, the one the brief permits:
   `pub const TAG_ACT: u64 = 134;` in `hashline/src/tables_attn.rs` (T2
   decision 4 allocates it there; it is the next free scalar after
   `TAG_U8 = 133` and must not reuse the FFN statement's `TAG_ACT16 = 3`).
   Nothing else in that file changed; `git diff --stat` against
   `zk60-attention-compile` shows 7 added lines and no deletion.
6. `ProveStats` gained `act_lookups`; the `"parameters"` payload became T2
   section F's self-describing string
   `T32/d16/f16/.../sh-g7-u0-h14-z6/...` (still `/block-wip`); the public API
   (`prove`, `prove_with_stats`, `verify`, `verify_bytes`, `compute_output`,
   `Receipt::to_bytes` / `from_bytes`) takes `&FeedForwardPublic`;
   `block_schedule()` is gone because there is one schedule now;
   `FeedForwardPublic::synthetic_fixture()` was added beside
   `AttentionPublic::synthetic_fixture()`.

**E-1 is still respected.** `hashline-zk-mr1/private-block-t32-poc/1` appears
nowhere, there is no `BlockPublic`, `SC_IO_OUT` still binds `A_X1`, the
endpoint scales are still the fixtures' `(-3, -3)` and no calibration digest
is absorbed. Those five, with the tripwire, are S4's single commit.

**Commands** (all `flock -w 540 /tmp/zk-build.lock`, offline, `-j 2`, the warm
target dir, release overrides):

1. `cargo check --lib --tests --examples` -> exit 0; the only warnings are the
   8 pre-existing `src/attention.rs` ones, `private_block` produces none.
2. `cargo test --release --lib private_ -- --test-threads=1` -> **28 passed,
   0 failed**, 11.52 s (11 accepted-component + 17 block).
3. `cargo test --release --lib -- --test-threads=1` (the WHOLE library) ->
   **95 passed, 0 failed**, 59.83 s.
4. `cargo test --release --test zk60_private_block --test
   zk60_private_attention -- --test-threads=1` -> **4 + 4 passed, 0 failed**.
5. `cargo test --release --doc private_` -> **2 passed** (both `compile_fail`
   one-use-endpoint doctests still fail to compile, as claimed).
6. The example: `prove` 0.097 s, frame **2,816,472 bytes** = the design's
   derived figure exactly; `verify` in a fresh process ACCEPT in 0.039 s with
   all three negative controls refused. Run under the session scratchpad;
   nothing written into the repository.
7. Byte-identity gate: `git --no-pager diff --stat zk60-attention-compile --
   hashline/src/private_attention.rs hashline/src/private_attention
   hashline/examples/zk60_private_attention.rs
   hashline/tests/zk60_private_attention.rs` printed NOTHING.

*(superseded; S3c is done — see below)* **Next step (S3c):** the tamper tests at the VERIFIER.

### 2026-09-19 — S3c TAMPER TESTS AT THE VERIFIER (done)

New file `hashline/src/private_block/tamper.rs` (`#[cfg(test)]`, one added
`mod` line). Every case edits the witness planes BEFORE the `A` commitment,
lets `prove_inner` run to completion, and asserts `verify_inner` is an error.
**No prover-side assertion catches any of them**, so no test-only receipt path
was needed and none was added: the prover pre-checks no relation, an
out-of-table lookup value is bucketed into entry 0 of the histogram, and the
LogUp helpers are computed from whatever the witness holds.

**Each case names ONE relation and recomputes the chain downstream of the
tamper**, so that every OTHER relation, class proof and byte lookup still
holds — which is what erratum E-19 says four of T2's own rows fail to do. The
helpers `recompute_from_product` and `recompute_from_h16` redo `h16`, `rh`,
`z16`, `rd`, `xres2` and every limb exactly as the witness builder does, and
REFUSE (so the test picks another index) if any value would leave its class,
because a tamper that needs an out-of-class plane would be caught by a range
relation rather than by the one the case names.

**The catch is asserted by slot INDEX, never by name** (erratum E-20:
`SLOT_NAMES[SC_DZC]` is a string this very stage changed), or by the `H:`
prefix where the catch is the one value-0 LogUp sum claim. Each test also
asserts that the HONEST proof through the same path verifies.

| tamper (what is kept consistent) | catch, asserted | what it shows |
|---|---|---|
| `z16 += 1`, `xres2` and both limb pairs recomputed — `c8`, `c9`, `c10` and every lookup still hold | **slot 14** (`SC_DZC`) | T2 section G.1: the block's output cannot be chosen. Under Tier 1 alone this receipt verified |
| `g8 += 1`, `a16` re-read from the table, the WHOLE chain recomputed | **slot 18** (`SC_FZC`) | `g` is bound to `nm` through `SC_GMM`'s claim at `p_g` |
| `a16 += 1`, the chain recomputed | **LogUp sum claim on `H`** | the pair `(g8 + 128, a16)` must be a row of `act`. The prover CAN satisfy `f_act` pointwise (it commits `H` after alpha); the multiplicity side is what fails — exactly T2's reading, and the relation E-22 makes a soundness requirement |
| `u16 += 1`, limbs and the chain recomputed | **slot 18** | `u` is bound to `nm`; `host2` carries no coefficient and no constant (`SH_U = 0`) |
| `h16 += 1`, limbs recomputed, `rh` left alone, everything BELOW recomputed so `SC_DMM` and `SC_DZC` still agree | **slot 18** | the product is pinned from both sides (`f0`) |
| `rg` rotated inside `[0, 2^7)` | **slot 18** | the gate requantization identity |
| `rh` rotated inside `[0, 2^14)`, limbs recomputed | **slot 18** | the product requantization identity |
| `rd` rotated inside `[0, 2^6)` | **slot 14** | the down requantization identity |
| `z16 += 2^16` with `rd` "compensated" and the limbs pushed out of `[0, 256)` | **LogUp sum claim on `H`** | T2 row T-z1, the int16 CLASS test. Kept with its TWO catches and labelled as such (E-19): it shows the class is enforced, not that one relation is present |

Rotating a remainder inside its own window is what makes those three cases
isolating: every byte lookup still has a row, so the only relation that can
notice is the requantization identity the remainder appears in.

**Commands:** `cargo test --release --lib private_block::tamper --
--test-threads=1` -> **7 passed, 0 failed**, 3.04 s;
`cargo test --release --lib private_ -- --test-threads=1` -> **35 passed,
0 failed**, 14.59 s. Byte-identity gate against `zk60-attention-compile`:
empty.

**Two tamper checks T2 section G names that are NOT here, and where they go.**
(a) The D12 item-3 boundary test — present an honest receipt against an output
endpoint committing `xres1` instead of `xres2` — only becomes meaningful once
the output endpoint IS `xres2`, so it belongs to S4 beside the tripwire.
(b) The pair-sharing negative control (`A_H16`'s site sharing `A_U16`'s
reserved mask pair) is a rank-tool control: `audit_claims` already refuses a
shared pair positionally, and the disclosed-dimension half of it is S5's
re-run on the real source. Both are recorded here so they are not lost.

*(superseded; S4 is done — see below)* **Next step (S4), in ONE commit and only from this green tree:**
(a) `BlockPublic` wrapping the attention and feed-forward words with ONE
digest under `hashline/private-block-public/1`, the activation table held as
`[i16; 256]`, and the `"feed-forward-statement"` absorb of S3b DROPPED;
(b) the profile string `hashline-zk-mr1/private-block-t32-poc/1` with its own
parameters payload, schedule domain, wire magic and expected-policy magic,
replacing every work-in-progress string;
(c) `SC_IO_OUT` moves from `A_X1` to `A_X2` and `Witness::output` with it;
(d) `IoSpec::new` refuses anything but the approved calibration's
`(e_r, e_r2) = (0, 0)`, and the calibration identity digest is absorbed under
a new `"calibration"` label at step 5 of T1 section D (between `"parameters"`
and `"schedule"`);
(e) the tripwire `block_output_cannot_be_chosen` exactly as T1-check section
11.3 specifies, with the honest-proof assertion beside it;
(f) whole-block kernel parity still green through the public API's output.

### 2026-09-19 — S4 THE BLOCK PROFILE (done, one commit)

All six things condition 1 holds together landed in this single commit, on the
green tree S3c left.

**(a) `BlockPublic`.** A new type holding the `AttentionPublic` and
`FeedForwardPublic` halves, with ONE `digest()` over
`b"hashline/private-block-public/1"` followed by both halves' words: the four
attention matrices, `gamma_a`, the rope pair, the exp table, then `gamma_m`,
`Wg`, `Wu`, `Wd` and the 256 activation words as little-endian `i16`. The two
halves' own `digest()` methods are GONE, replaced by private `absorb_into`,
so there is exactly one statement digest and the `"feed-forward-statement"`
absorb S3b used is dropped (T2 section F: a second absorb of the same words is
a second thing to keep in sync). A test drives one word of each of the six
public tensors and requires the receipt to be refused and the frame to fail to
parse, so every one of them is demonstrably IN the digest.

**E-2 by the TYPE, as the security owner's answer 2 requires.** `act` is now
`[i16; 256]`, not `Vec<i16>`: `FeedForwardPublic::new` is the only way in, it
refuses any other length through `try_into`, and there is no byte parser for
these words at all — so there is nothing that could truncate one, and no
second constructor that could forget a range check.

**(b) Every work-in-progress string replaced**, and a grep for `wip` over the
module, the example and the integration test now returns nothing:

| what | was | is |
|---|---|---|
| `PROFILE` (Fiat-Shamir domain, `ZkRng::from_os`) | `hashline-zk-mr1/private-block-t32-wip/0` | `hashline-zk-mr1/private-block-t32-poc/1` |
| public-statement digest domain | `hashline/private-block-wip-public/0` | `hashline/private-block-public/1` |
| feed-forward digest domain | `hashline/private-block-wip-feedforward/0` | **removed** (folded into the one digest) |
| schedule digest domain | `hashline/private-block-wip-schedule/0` | `hashline/private-block-schedule/1` |
| `describe()` line 0 (hashed into the schedule digest) | `private-block-t32-wip/0: ...` | `private-block-t32/1: ...` |
| expected-policy frame magic | `HPBWEXP0` | `HBLKEXP1` (T1 section D step 2) |
| receipt wire magic | `HLPBWIP0` | `HLPBLOK1` |
| absorbed `"parameters"` payload | `.../block-wip` | T1 section D step 4 / T2 section F: `T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript` |
| endpoint slot tags | 21/22 and 23/24 — the ATTENTION profile's | **41/42 and 43/44**, the block's own (T1 section F.2). Reusing 21–24 would have left the scale field as the only separation, which T1 calls separation by accident |

**(c) The output endpoint is `xres2`.** `SC_IO_OUT` binds `A_X2`;
`Witness::output()` returns `A_X2` and `block_output()` is gone;
`compute_output` returns the block output. The two external endpoints are now
exactly D12 item 2's `x_in` and `xres2`.

**(d) Scale pinning and the calibration.** `IoSpec::new` REFUSES any pair but
`(0, 0)` — including the `(-3, -3)` the accepted attention component's
fixtures declare, which T1 section F.1 names as the test that would fail
today. `input_scale()` / `output_scale()` accessors were added because T1's
own test sketch needs them. The calibration identity digest is absorbed under
the new label `"calibration"` at step 5 of T1 section D, between
`"parameters"` and `"schedule"`. The identity is a module function
`calibration_identity()`; a test asserts it equals
`causal_oracle::public_synthetic_registration(..).calibration_identity` and
that `(0, 0)` equals that registration's `attention.e_r` and
`residual.e_r2`, so the literal is pinned to its source rather than trusted.
*(DEVIATION, small: the digest is a literal here with a test pinning it,
rather than read from the registration at proving time — building a
`BlockRegistration` needs two weight commitments the prover does not have.
If the security owner prefers, the next stage can take the digest from the
approved contract the caller already holds.)*

**(e) The tripwire `block_output_cannot_be_chosen`**, under exactly that name,
in `tamper.rs`: `z16` tampered consistently, both limb pairs recomputed, the
attention half and `norm_m` untouched, and the endpoint owner committing the
CHOSEN `xres2'` (T1-check section 11.3 item 4's stronger form). The verifier
rejects at slot **14**, and the honest proof is asserted to verify beside it.
The whole tamper harness now commits the TAMPERED output, which makes every
case in the suite strictly harder: `SC_IO_OUT` cannot be what rejects, so each
case is left with the one relation it names.

**A FINDING from making that change.** T2's row T-z1 (`z16 + 2^16` with `rd`
compensated) no longer reaches a lookup at all: `xres2` leaves int16 too, so
no endpoint can carry it, and the measured first catch is the OUTPUT ENDPOINT
at slot 22. It is kept under an honest name
(`a_z16_outside_int16_cannot_reach_the_output_endpoint`) and the class is now
tested the way the module already tests it for `x_in`: shift a two-limb
decomposition by `(+256, -1)`, which leaves the decomposition relation exactly
satisfied and breaks only the byte lookup. That form isolates, and it is run
on all four feed-forward limb pairs (`z16`, `u16`, `h16`, `rh`), each caught by
the one value-0 LogUp sum claim. The D12 item-3 boundary test T2 section G
also lands here: an honest receipt against an output endpoint committing
`xres1` is refused at slot 22.

**(f) Kernel parity through the public API's output.** The whole-block parity
test compares `Witness::output()` — now `xres2` — against
`kern::run_block_slice`'s return value on all 1,200 generated cases, and the
oracle test compares the plane against `FixedCausalOracle::build`'s own
`residual.xres2`.

**Commands** (all `flock -w 540 /tmp/zk-build.lock`, offline, `-j 2`, warm
target dir, release overrides):

1. `cargo check --lib --tests --examples` -> exit 0, only the 8 pre-existing
   `src/attention.rs` warnings.
2. `cargo test --release --lib -- --test-threads=1` (the WHOLE library) ->
   **105 passed, 0 failed**, 65.12 s.
3. `cargo test --release --test zk60_private_block --test
   zk60_private_attention -- --test-threads=1` -> **4 + 4 passed, 0 failed**.
4. `cargo test --release --doc private_` -> **2 passed**.
5. The example: `prove` 0.093 s, frame **2,816,472 bytes**; `verify` in a
   fresh process ACCEPT in 0.042 s, all three negative controls refused. The
   printed profile is `hashline-zk-mr1/private-block-t32-poc/1`.
6. `python3 -m unittest discover -s tests` (run after S3b, the only commit
   that touches a shared file) -> **exit 0**.
7. Byte-identity gate against `zk60-attention-compile` on the accepted
   attention files: EMPTY. Over `zk.rs`, `layer.rs`, `zk_ffn_fresh_io.rs`,
   `private_seam.rs`, `causal_oracle.rs`, `scripts/` and `tests/`: EMPTY. The
   ONLY changed pre-existing file in the whole lane is
   `hashline/src/tables_attn.rs`, +7 lines, the `TAG_ACT = 134` constant T2
   decision 4 allocates there.

**Next step (S5, the next agent):** the checking tools on the real Rust source
(disposition condition 4). `scripts/zk60_attention_native_inventory.py` must
take the MODULE PATH as a parameter (ruling R-A) and re-derive every count of
disposition section 1.2 from `hashline/src/private_block/*`; `NOTE_EXPECT`
becomes `A 455/213/240`, `H 384/280/102`, `A_sites 120`, `H_sites 51`,
`A_GROUPS 35`, `H_GROUPS 9`, `M_ROWS 50`, `N_FUNCTIONALS 34`, `largest_L 50`,
`U8 61,440`, `exp 2,048`, `act 512`, `main 159`, `ext 25`, the twenty-three
`SLOTS` triples and
`hosts_by_index {2:[0,1], 14:[10,13], 15:[5,9], 16:[6,7], 17:[4,8], 18:[11,12]}`.
Two things to know before starting. (i) The parser understands a Rust subset;
the new arms were written inside it (`b.a`, `b.a_at`, `b.a_slice`,
`b.a_range`, `b.h`, `rho`, `fixed`, `cat`, one `for` loop, `match slot`) with
ONE new form to check: `let i_fact = b.h(H_FACT)?;` binds a `b.h` result, which
E-17 requires and the parser may need taught. (ii) Two negative controls are
owed and are not in the Rust suite: `A_YM` sharing `A_Y`'s reserved pair (T1
section G.2) and `A_H16` sharing `A_U16`'s (T2 section G); `audit_claims`
already refuses a shared pair positionally, and the disclosed-dimension half
is the tool's. Also owed by the design and NOT done here: the R-2 re-run of
`limb_windows.py` / `wraparound_bounds.py` over the grown expression list with
the multiplicity bound re-checked at 61,440.

### 2026-09-19 — S5 THE CHECKING TOOLS ON THE REAL RUST (done)

Disposition section 3, condition 4. Until today the three leak-checking tools
had only ever seen the block as a **memo**: the two paper drivers
`results/zk60_private_block_construction/grow_and_run{,_whole_block}.py` hand-built
a `Layout` object and a site list from the T1/T2 text and fed those to the
tools. This stage points the same tools at the **source** — the tool now
parses `hashline/src/private_block/{layout,argument,protocol}.rs` and derives
every count, every group and every slot from the code that proves.

**New files (this lane's only writes this stage).**

- `scripts/zk60_private_block_inventory.py` — the new driver. It imports the
  committed `scripts/zk60_attention_native_inventory.py` **by file path** and
  uses that module's own `Layout`, `DefineParser`, `parse_logup_sum`,
  `build_inventory`, `run_rank_tool` and `run_cfs_tool`, so the accepted
  adaptations R-1…R-9 (rank) and C-1…C-4 (CFS) are exactly the accepted ones.
  **No committed script was edited and no Rust file was touched.**
- `tests/test_zk60_private_block_inventory.py` — 29 tests, four layers.
- `results/zk60_private_block_tools/` — the evidence (six JSON records, the
  log, the `.done` marker, and `accepted_selfcheck/` holding the committed
  tool's own six records on the ACCEPTED attention layout).

**Commands, and what works.** No cargo, no proof, no GPU; the whole stage is
Python and takes well under a minute, so nothing needed the detached-run
protocol.

1. `python3 /home/victor/wt-zk60-private-block/scripts/zk60_private_block_inventory.py
   --repo /home/victor/wt-zk60-private-block
   --out-dir /home/victor/wt-zk60-private-block/results/zk60_private_block_tools`
   → exit **0** in **24.3 s**, peak RSS 46 MB. `zk60_private_block_inventory.done`
   holds `0`.
2. `python3 -m unittest tests.test_zk60_private_block_inventory` from
   `/home/victor/wt-zk60-private-block` → **29 tests, OK, 39.3 s**.
3. `python3 -m unittest discover -s /home/victor/wt-zk60-private-block/tests
   -p "test_zk60_private_block_inventory.py"` → **29 tests, OK**, and this form
   works from ANY working directory (the test resolves the repo root from
   `__file__`); form 2 needs the worktree root as the working directory.
4. `python3 -m unittest tests.test_zk60_attention_native_inventory` → **39
   tests, OK** (the committed inventory tool's own suite, untouched).
5. `python3 -m unittest tests.test_zk60_attention_pair_schedule` → 33 tests,
   **1 pre-existing failure**, see "two pre-existing red tests" below.
6. `python3 -m unittest tests.test_zk60_attention_cfs_slots` → 14 tests,
   **1 pre-existing error**, same note.

**Step 1, the self-check (the control that the rebinding broke nothing).**
The driver first runs the committed tool, completely unmodified, on
`hashline/src/private_attention/` through its own `build_all`:
**29 of 29 cross-checks pass, `failures: []`, `all_pass: true`**, A sites 75,
H sites 35, A groups 30, H groups 8 — the accepted verdict, reproduced. The
five records are written to
`results/zk60_private_block_tools/accepted_selfcheck/`.

**Step 2, the counts, derived from the source and compared with the design**
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` section 5.2). **46 of 46
agree; there is no disagreement to report.** `A` 455 rows = 213 data + 240
site-pair + 2 proximity; `H` 384 = 280 + 102 + 2; `A` sites 120 and `H` sites
51 both from `layout.rs`'s arrays AND from counting the sites
`argument.rs::define` actually creates; opening groups **A 35 / H 9 derived
from the PCS key rule** and equal to the constants `layout.rs` declares;
23 slots, kinds 12 private / 5 standalone / 6 host; `M_ROWS` 50 = 2·23 + 4;
`N_FUNCTIONALS` 34 = 23 + 5 + 6; largest `L` 50 at `SC_SZC`, headroom 206;
main 159, ext 25, `Σ(m+e)(d+1)` 721, terminals 173; lookups **U8 61,440 /
exp 2,048 / act 512**; `hosts_by_index {2:[0,1], 14:[10,13], 15:[5,9],
16:[6,7], 17:[4,8], 18:[11,12]}` with every host after everything it hosts;
`SC_DZC` 37/19, `SC_FZC` 11/6, `SC_TAB` 3/3; and the reserved-pair first rows
the parse produces are exactly `layout.rs`'s `a_site(slot, k)` /
`h_site(slot, k)` ranges. Source hashes are in the summary
(`layout.rs 6cc8f6fe…`, `argument.rs bb6971c3…`, `protocol.rs db2757a3…`).

**Step 3, the rank tool on the real source.** `failures: []`, coverage checks
all pass. `whole_A_per_column` **0**, `whole_A_with_values_n4` **0**,
`whole_H_per_column` **0**; all **35** `group_A_*` and all **7** modelled
`group_H_*` **0** each (the tool models 7 of the 9 derived H groups because it
builds the `SC_ZS` site and the sum group itself — committed adaptation R-4,
the same offset of 2 the paper runs had); both endpoints **0**;
`whole_H_with_values` **2** at n = 4 and n = 8 with
`residual_is_exactly_the_public_identity: true`, i.e. **the residual is
exactly the public LogUp identity and nothing more**. FA2 14.3's
`rank_mask = 2m + 2n − 2 + 2n` holds on all 35 all-pair `A` groups. Singleton
groups A 17 / H 2.

**Step 4, the CFS tool on the real source.** `all_checks_pass: true`. All six
host groups pass `rank = dim S = ΣL − (k+1)` with **kernel 3 and leaked 0**:
`SC_TZC` 84/81, `SC_DZC` 66/63, `SC_QZC` 70/67, `SC_KVZC` 62/59, `SC_SZC`
100/97, `SC_FZC` 66/63, and every host's hosted slots precede it. All 23
standalone slots pass `rank = dim S = N·d + 1`, leaked 0, kernel 1, at exactly
the design's dimensions. **Every slot satisfies `L + 256 ≤ 512`**; largest
`SC_SZC` at 306.

**Step 5, the negative controls — 22 of 22 fire.** Eleven rank controls:
`no_mask_A_per_column` 49, `no_mask_A_with_values_n4` 304,
`single_base_row_per_claim_A_per_column` 16 (equals the derived expectation,
not "grows" — the C-5 erratum's rubric),
`single_prox_row_singleton_pair_claim_per_column` 1,
`prox_pair_…` 0, `helper_sums_published_n4` 100,
`zero_sum_row_without_fresh_pair_n4` 8, the two
`flipped_rope_*_sharing_pair` 2 each and the two `*_own_pair` 0 each. Seven
CFS controls all pass (`nc_hosted_c_zero`, `nc_host_nu_zero`,
`nc_extension_degree_exceeds_mask`, `nc_qkv_unsplit`, `nc_row_budget_exceeded`,
and the two `nc_sigma_functional_for_*`).

**THE TWO OWED CONTROLS ARE NOW IMPLEMENTED AND BOTH FIRE.** They are
mutations of the DERIVED claim list inside the rank model, not edits to the
Rust: `share_mask` is handed the two roles and the tool re-runs.

| owed control | disclosed dim | required |
|---|---:|---|
| `A_H16_shares_A_U16_pair_with_values_n4` (T2 section G) | **2** | ≥ 2 |
| `A_YM_shares_A_Y_pair_with_values_n4` (T1 section G.2, lines 1210-1214) | **2** | ≥ 2 |
| `A_H16_own_pair_not_A_U16_pair_with_values_n4` *(positive)* | **0** | 0 |
| `A_YM_own_pair_not_A_Y_pair_with_values_n4` *(positive)* | **0** | 0 |

**Step 6, against the PAPER whole-block run.** 74 comparable items — every
count, every disclosed dimension, every group, every endpoint, every singleton
count, every host group, every standalone slot, the largest slot, `M` rows,
functionals, and every shared negative control — and **74 of 74 agree. There is
no difference between what the paper schedule said and what the real source
says.** The only four items present here and absent there are the two owed
controls and their two positive counterparts, which the paper drivers could not
wire; they are reported under `only_in_this_run`, not as differences.

**ADAPTERS THE PARSER NEEDED** (design decision 14's warning, realised). The
committed parser, unmodified, **fails** on the block's Rust — the test module
asserts that it does, so no adapter here is decoration. Each is a subclass or a
source-level normalisation inside the new driver; no committed script and no
Rust file changed.

| id | construct, with Rust file:line | why the committed tool cannot read it | what the adapter does |
|---|---|---|---|
| **B-1** | `hashline/src/private_block/argument.rs:570` `b.a_slice(lay.limb_off_m(kk), 5, rho(0..5), 0)?;`, and the method `hashline/src/private_block/layout.rs:647` `fn limb_off_m` | the Python `Layout` has `limb_off` only; `_int` substitutes only `lay.limb_off(..)`, so the expression is unevaluable | `BlockLayout` adds `limb_off_m` with layout.rs's own arithmetic (`a_off[A_LIMBM] + k·T`, both read from the parsed consts) and `_int` substitutes it |
| **B-2** | receiver-qualified `lay.helpers(..)` at `argument.rs:690, :701, :743, :783, :797, :822` (the accepted source calls the free function `helpers(..)`, `private_attention/argument.rs:613, :621, :652, :666, :691`) | the committed regexes are anchored on the free-function spelling; with the `lay.` prefix the substitution leaves `lay.19` and the parse dies | the exact token `lay.helpers(` is rewritten to `helpers(` in each statement/expression before delegating; nothing else named `lay.` is touched |
| **B-3** | `argument.rs:668` `let r_row = if slot == SC_DMM { tr.challenge_fp2_vec(5) } else { pts.r_tf.clone() };` | the committed parser handles only the TUPLE form `let (a, b) = if flag {…} else {…}`, and only with a bool local as the condition | `_statement` evaluates the condition with the committed `_cond`, takes the live branch, and binds a challenge vector or a `pts.X[.clone()]` vector; anything else falls through unchanged. The symbols are `SC_DMM.r_row[i]`, the Rust local's own name, distinct from `SC_GMM.r_tf[i]` — which is what the PCS grouping keys on |
| **B-4** | `hashline/src/private_block/protocol.rs:54-55` `for p in lay.h_planes()` and `let sign = if h_is_table(p)` (the accepted source says `for p in 0..N_H` and `if p == H_GU8 \|\| p == H_GEXP`) | `parse_logup_sum` **refuses** the first outright, and reads an **EMPTY** negated set from the second — it would have silently lost all three table signs | `normalise_logup_source` resolves both indirections out of `layout.rs` itself — `fn h_planes` must read `(0..N_H).collect()` (`layout.rs:615-617`) and `fn h_is_table` must read `matches!(plane, …)` (`layout.rs:255-257`), both asserted, an unexpected body is a hard error — and rewrites the two lines into the spelling the committed parser understands, so all of ITS assertions (`point: vec![]`, `value: Fp2::ZERO`, loop range == `N_H`) still run. Derived negated planes: `H_GU8, H_GEXP, H_GACT` |
| **B-5** | the two owed controls | `run_rank_tool` does not expose the schedule it built | after it returns, the already-rebound tool instance is taken from `sys.modules` and its own `build_schedule` / `a_model_groups(share_mask=…)` / `build_model` / `analyze_fast` are called again. No constant is rebound twice and no tool function is redefined |
| **B-6** | the third LogUp table | the committed `lookup_total` knows U8 and exp only | `act = 1 << Dom::F.log() = 512` is added by exactly the committed function's own convention for exp (`argument.rs:766`, the `f_act` term, one activation lookup per `Dom::F` element) |

Adapter fire counts on this source: B-1 ×9 (the nine limb iterations), B-2 ×8,
B-3 ×3 (one arm, three slots). **Nothing needed an edit to a committed tool or
to the Rust**, so the stage did not have to stop.

**A correction to S4's prediction.** The previous entry's "ONE new form to
check", `let i_fact = b.h(H_FACT)?;`, turned out to need **no** adapter — the
committed `_maybe_site` already strips a `let X =` prefix. The three forms that
did need one (B-1, B-2, B-3) were not predicted, and the fourth (B-4) would
have been the dangerous one: it does not crash, it silently returns a LogUp
record with no negated planes.

**Two pre-existing red tests in the wider Python suite**, neither touched by
and neither caused by this stage (both fail identically with this stage's files
removed from the run):
`tests.test_zk60_attention_cfs_slots.MLayout.test_rows_and_functionals`
errors with `FileNotFoundError: scripts/zk60_joint_cfs_view.py` — that script
exists nowhere in the repo, including the main tree; and
`tests.test_zk60_attention_pair_schedule.Schedule.test_committed_schedule_record_is_this_tools_output`
fails because the committed record
`docs/zkmatrix-poc/zk60_private_attention_schedule.json` embeds the absolute
path of the worktree it was produced in
(`/home/victor/wt-zk60-mvp-fable/results/…`) and the regenerated record embeds
this one. Both are for whoever owns those files; this lane owns neither.

**WHAT IS NOT ESTABLISHED.** Said plainly, because the numbers above are easy
to over-read.

- **No privacy property.** Every verdict is about a linear-algebra model at
  seeded stand-in challenges. The models exclude the sampled columns, the
  salted Merkle paths, the CFS channel, transcript conditioning, integer-range
  side information and `A ↔ H` correlation. The change this stage makes is that
  the model is now read out of CODE instead of out of a MEMO — nothing else.
- The construction's own gate — a zero-witness preimage with the same free
  dimension as the real witness on every channel, **on captured real
  receipts** — is still unmet.
- **D8 and D11 stay open** for the block's two external endpoints `x_in` and
  `xres2`; D9 stays pending.
- **No soundness claim.** These tools model what an opening DISCLOSES, not what
  it BINDS. The tamper tests and the `block_output_cannot_be_chosen` tripwire
  are the source's own (S3c, S4).
- The runtime refusal `audit_claims` ("a reserved pair is unused or shared
  between claims") is **not** exercised by the two owed controls: they mutate
  the model, not the prover. A Rust test that forces a shared pair through the
  real `audit_claims` is still owed.
- Still owed by the design and NOT done here: the R-2 re-run of
  `limb_windows.py` / `wraparound_bounds.py` over the grown expression list
  with the multiplicity bound re-checked at 61,440.

**Precise next step.** Nothing in S5 blocks; the stage table is complete. The
open items for whoever picks the lane up are the three in the list above (the
`audit_claims` Rust test, the R-2 limb/wraparound re-run, and the captured-
receipt joint-view gate), plus the security owner's own reading of whether
condition 4 is now discharged.

### 2026-09-19 — S6 THE CODE REVIEW'S TWO DEFECTS AND ITS TEST GAPS (done, one item not reachable)

Closing `ZK60_PRIVATE_BLOCK_CODE_REVIEW.md` D-1, D-2, H-1, H-2, H-3 and the
S5 entry's owed `audit_claims` test. **No protocol behaviour, constant, label
or count changed**, no accepted file touched, no script, Python test or design
document touched. Four files, all inside the module: `argument.rs` (D-1),
`witness.rs` (D-2), `tamper.rs`, `tests.rs`. Nothing here is a privacy
acceptance and nothing here is a speed claim.

**D-1 — the `SC_TZC` table-index comment. FIXED, structurally.** The comment
that said `5..14 A_LIMB's nine sub-slices, 14 A_DM` (giving table 14 to two
different things) is gone, and with it every hand-written index in the arm:
`i_tau`, `i_rt`, `i_rt2`, `i_d`, `i_dsq`, `i_dm`, `i_dsqm` are now CAPTURED
from `b.eq` / `b.a`, and the two nine-slice limb blocks are addressed as
`i_dsq + 1` and `i_dsqm + 1`, the index the loop that immediately follows
starts at. The polynomial reads `v[i_*]` instead of `v[3]`, `v[14]`, `l3(16)`.
The two `b.a_slice` loop statements are left exactly as they were, so the
inventory driver's adapter B-1 still matches (it does; see the commands
below). Every index resolves to the same number it did before
(0, 1, 2, 3, 4, 5, 14, 15, 16), which the cross-verification below measures
rather than asserts.

**D-2 — `requant` shift-underflows at `sh = 0`. FIXED.** `witness.rs` now has
one `half(sh)` helper — `0` at `sh = 0`, `1 << (sh - 1)` above it — and both
users call it: `requant`, where `1i64 << (sh - 1)` underflowed `u32` at
`sh = 0`, and `quantize`'s biased-remainder line one screen below, which had
the identical expression and the identical trap. At `sh = 0` `requant` is now
the identity `(acc, 0)`, which is the kernel's own `sh <= 0` rule (exact
up-scaling by `2^0`) rather than a new convention. `tamper.rs`'s copy of
`requant` (the review's "the same underflow is duplicated") no longer
duplicates anything: it calls `witness::requant` and adds `witness::half`, so
the two cannot drift. `requant` and `half` are `pub(super)` so the test can
see them; nothing outside `private_block` can.

New test `requant_is_the_identity_at_shift_zero_and_the_kernels_rounding_above_it`
(`tests.rs`): `requant(v, 0) == (v, 0)` for thirteen `v` including negatives
and `±2^40`, and for `sh` in `1..=14` a sweep of `acc` over four full periods
each side of zero (every residue, both rounding ties, both signs) asserting
`acc = y·2^sh + r`, `r ∈ [-2^(sh-1), 2^(sh-1))`, the committed biased limb
`r + 2^(sh-1) ∈ [0, 2^sh)`, and `y` equal to `private_block_kernel::requant`'s
own value at that shift.

**Test gap A (H-1) — the `norm_m` family now has verifier-side tamper tests.**
Four cases, each in `tamper.rs`, each building a real receipt from a tampered
witness, each requiring the VERIFIER to reject at a named slot index or at the
LogUp sum claim, each with the honest proof asserted beside it. The catch was
worked out from `argument.rs` and written into the test's doc comment BEFORE
it was run; **predicted equals measured in all four**, so there is no finding
to report here.

| Case | What is tampered, and what is recomputed | Predicted | Measured |
|---|---|---|---|
| (a) `a_norm_m_output_not_derived_from_xres1_is_rejected` | `nm += 1` with the WHOLE feed-forward half recomputed honestly from it (gate, `rg`, activation lookup, up, product, `rh`, down, `rd`, residual 2, every limb) and the endpoint owner committing the resulting output | `Slot(SC_DZC)` — only `c6` is left | `Slot(SC_DZC)` |
| (b1) `the_norm_m_denominator_is_pinned_by_its_isqrt_witness` | `dsqm += 1` alone | `Slot(SC_TZC)` (`mu[3]` and the `nu[1]` host term) | `Slot(SC_TZC)` |
| (b2) same test | `dm += 1` with `dsqm` and `dm`'s three byte limbs recomputed | `Slot(SC_TZC)` (`mu[5]` and the host term; `SC_DZC`'s `c6`/`c7` break too and slot 2 runs before slot 14 — stated in the test, not argued away) | `Slot(SC_TZC)` |
| (b3) same test | `dm += 1` made consistent everywhere the integers allow: `dsqm = dm²`, the limbs, `a1m = ss + Ceps − dsqm`, `a2m = 2dm − a1m`, then `nm`, `rho_m`, `sigma_m` and the whole feed-forward half recomputed, so all four `SC_TZC` relations, the host term and all of `SC_DZC` hold | `LogUp` — `a1m < 0` because `a1m ≤ 2dm` honestly, and a negative value's top byte limb leaves `[0, 256)` | `LogUp` |
| (c) `a_norm_m_limb_outside_its_byte_range_is_rejected_by_the_lookups` | one limb pair of each of `dm`, `a1m`, `a2m` shifted `(+256, −1)`: the value is unchanged, only the byte class is broken | `LogUp` | `LogUp` |
| (d) `the_norm_m_quotient_is_pinned_by_its_remainder_windows` | `(nm, rho_m, sigma_m) → (nm − 1, rho_m + den, sigma_m − den)` with `den = 2^12·dm`, so `c6` and `c7` still hold over the integers exactly, plus the whole feed-forward half recomputed from `nm − 1` | `LogUp` — `sigma_m − den < 0` leaves its window | `LogUp` |

(b3) and (d) are the two worth reading: together they say that neither the
isqrt witness nor the division identity pins `norm_m` by arithmetic alone —
the byte windows on `a1m`, `a2m`, `rho_m`, `sigma_m` are load-bearing, and the
tests now fail if they stop being enforced. The accepted attention component
has no verifier-side `norm_a` tamper to mirror (`private_attention/tests.rs`
moves `A_D` and `A_Y` only inside the loop that accepts any error), so these
were written from the argument rather than copied.

**Test gap C (H-3, erratum E-22) — the `u16 = 0` case. THE VERIFIER REJECTS;
this is NOT a blocking finding.**
`an_activation_value_at_a_zero_up_output_is_rejected_by_the_pair_lookup`.
MEASURED: the public synthetic fixture has **no** index with `u16 = 0`, so the
case is built from public synthetic weights by zeroing **column 0 of `Wu`**
(`u16[t, 0] = Σ_i nm[t,i]·Wu[i,0] = 0` for every row, whatever `nm` is);
everything else — the attention half, `gamma_m`, `Wg`, `Wd`, the activation
table, the input — is the fixture's own, the statement stays public and
digested, and the prover and the verifier get the same one. The test asserts
which of the two constructions it used, so a later fixture change cannot
silently downgrade it to the easy case. At that index `a16` is moved to
another legal int16 that is not `act[g8 + 128]` and **nothing else is
recomputed**, because nothing else changes: the test asserts `h16` and both
`rh` limbs are untouched, and `f0 = a16·0 − 2^14·0 − 2^13 + 2^13 = 0` still
holds. PREDICTED `LogUp` (the pair lookup is the only other relation `a16`
appears in), MEASURED `LogUp`. The honest proof under the same statement
verifies beside it.

**Test gap B (H-2) — `A_MACT`. PARTLY DONE, and the part that is missing is
not reachable from a test.** `a_moved_activation_multiplicity_is_rejected_by_the_logup_sum_claim`
moves one unit of multiplicity from a table row to entry 0 with the TOTAL
preserved, through the prover's own bucketing rule (an activation use whose
pair is off its row is counted into entry 0, `protocol.rs:306`), asserts from
`ProveStats` that `act_lookups` is still 512 and that the row it moved off is
not entry 0, and requires `LogUp`. PREDICTED `LogUp`, MEASURED `LogUp`.
What is NOT done: setting a multiplicity DIRECTLY (zeroing a count, or moving
one with every denominator left honest). `A_MACT` is not a witness plane —
`is_multiplicity` (`layout.rs:218-220`) keeps it out of the committed planes
the witness fills and `prove_inner` derives the whole row from the witness
(`:302-312`) — so no witness edit can reach it, and the histogram and the
denominators it is checked against are always computed from the same witness
in the same pass. Only a modified prover can choose the row freely; giving a
test that power means a hook inside `protocol.rs`, i.e. a release-reachable
path, which is worse than the gap. Recorded as an open item, not as done.

**OWED (S5) — the claim audit on the list the argument really builds. DONE for
`A`.** `the_real_claim_list_is_refused_when_a_reserved_pair_is_shared_or_unconsumed`
(`tests.rs`) runs the VERIFIER's own `argument()` over an honest receipt —
the same call `verify_inner` makes at `protocol.rs:448`, after the same header
absorbs, the same `beta/gamma/alpha` and the same `M` verification — and puts
the resulting real claim list through `check_opening` with the exact arguments
both sides pass (`prove_inner:396`, `verify_inner:452`). The honest list
passes; pointing the second claim's pair parts at the first claim's rows, and
dropping a claim so its pair is consumed by nobody, are both refused with
"a reserved pair is unused or shared between claims". What this does NOT do:
force a degenerate list through `prove_inner`/`verify_inner` end to end. Which
pair a site gets is `lay.a_site(slot, k)`, a function of the fixed layout
alone, so no witness, receipt or public word can make the real list share or
orphan a pair; the prover's list is built by the same `run_slot`/`build_claim`
code from the same `p.mask_row` and audited by the same function with the same
arguments, and the transcript-order test already pins that the two sides walk
the same slots in the same order.

**Commands and counts** (WSL box, `flock /tmp/zk-build.lock`, shared release
target dir, no heavy lock, no GPU, nothing over a minute).

1. `cargo check --lib --tests --examples` → exit 0, **8 warnings before and 8
   after, all eight pre-existing and all in `src/attention.rs`**; zero in
   `private_block`.
2. `cargo test --release --lib private_ -- --test-threads=1` → **38 passed
   before, 46 passed after** (private_block 27 → 35, private_attention 11
   unchanged), 21.0 s.
3. `cargo test --release --test zk60_private_block -- --test-threads=1` →
   **4 passed**, 4.0 s. `--test zk60_private_attention` → **4 passed**, 3.0 s.
4. `python3 -m unittest discover -s …/tests -p "test_zk60_private_block_inventory.py"`
   → **29 tests, OK**, 39 s, from the worktree root and from another working
   directory alike. The D-1 change did not disturb the parser's adapters.
5. `git --no-pager diff --stat zk60-attention-compile -- hashline/src/private_attention.rs
   hashline/src/private_attention hashline/examples/zk60_private_attention.rs
   hashline/tests/zk60_private_attention.rs` → **prints nothing**.

**The proof is unchanged — measured, not argued.** The receipt written by the
example BEFORE these edits (2,816,472 bytes) was **verified by a fresh process
running the code AFTER them**: `ACCEPT: 2816472 bytes verified in 0.044 s`,
with the three corruption controls still refused. That single check covers
everything the receipt is bound to: the profile, the expected-IO policy, the
public-statement digest, the `"parameters"` payload, the calibration digest
and the **schedule digest** are byte-identical (they form the 32-byte frame
binding the parser re-derives), and every slot definition, challenge draw,
table index and polynomial of `argument()` is unchanged (the verifier re-runs
all twenty-three of them against the old frame). A fresh prove/verify after
the change gives the same 2,816,472 bytes, the same six printed schedule
lines and the same row and lookup counts.

**What is still owed after this stage** (unchanged by it, and nothing here
closes any of it): the direct `A_MACT` multiplicity tamper described above;
the R-2 re-run of `limb_windows.py` / `wraparound_bounds.py` over the grown
expression list; the captured-receipt joint-view gate; D8 / D11. The review's
hardening items H-4 (the 18-case loop in `tests.rs` still accepts any error),
H-5 (`Catch::LogUp` matches the whole `H` opening, not the sum claim alone),
H-6, H-7 and H-8 were outside this brief's scope and were not touched.
