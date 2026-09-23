# ZK60: adversarial check of the shaped refusal census (stages 38–39)

**Date:** 2026-09-22, 22:58–23:2x PDT. **Checker:** independent adversarial
agent (Claude Opus 5.5), review worktree `wt-zk60-block125m-review`, branch
`zk60-private-block-125m-review`, lane tip `27398d0` merged in (no conflict).
**Under attack:** `ZK60_SHAPED_REFUSAL_CENSUS.md`,
`hashline/src/private_block/census_shaped_tests.rs`, lane ledger stages 38–39,
fix `7472a3c` (ruling S38-F1(a)). **Context:** ruling NL-8 / gap GS-14 of
`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`.

**This is not a privacy result.** It checks completeness and statement
admissibility only. Nothing here claims or checks a privacy property.

**Line numbers.** `witness.rs`, `protocol.rs`, `argument.rs`, `layout.rs`,
`shape.rs`, `run.rs` and the shaped kernel are byte-identical between the lane
tip and this branch, so their line numbers are the lane's. `private_block.rs`
differs by review-only `cfg(test)` module lines, so its line numbers below are
the **lane's** (the refusal is at `:584`).

## 0. In plain words

The census asked one question: can an input the witness builder accepts make
an honest proof fail? Its answer holds up. I listed the refusal sites from the
code myself and found none that it missed. I re-derived every bound in exact
arithmetic, and every figure agrees. The one table problem it found (S38-F1)
is real, and it is the only one of its kind at the padded positions.

But the fix for S38-F1 leaves a gap, and the shape constructor has a second
one:

* **C-1 (the fix can be sidestepped).** The new refusal checks the activation
  table against the shape it is *built* for. The statement does not remember
  that shape, and nothing downstream checks it again. Build the feed-forward
  statement at rung-P2 (where the check passes), use it inside a rung-K4
  block (where the check would fail), and everything accepts it. The honest
  proof is then rejected by the verifier. This is reproduced, and the verifier
  rejects it.
* **C-2 (a shape the constructor should refuse).** `Shape::new` accepts an
  overridden softmax window that is too small. At such a shape the builder and
  the reference kernel accept an input whose last-row softmax remainder does
  not fit, and the honest proof is rejected. Whether the proof fails depends
  on the private input, which makes this the worse kind of failure. No
  registered shape uses the override. This is reproduced, and the verifier
  rejects it.

Neither affects the ten shapes as built today with their own statements, so
both are **latent**. Each is one cheap refusal away from closed, and each
should be closed before a production caller of the shaped path exists.

## 1. Verdict per census claim

| # | census claim | verdict |
|---|---|---|
| 1 | 34 data-dependent refusal sites × 10 shapes, bounds computed from the `Shape` | **CONFIRMED-WEAKLY.** The site list is complete: my independent enumeration (§3) found no omitted data-dependent refusal site, and every bound agrees exactly (§5). But 7 of the 34 rows have a `reach` that is typed in or defined equal to its `range`, so they cannot fail (C-3). "Computed from the shape" also holds only for the ten built shapes: at a `Shape::new`-admitted override, row 13 would call `rho_s` builder-guarded when it is not (C-2). |
| 2 | every REACHABLE site is refused by the builder first, with the same or a tighter bound | **CONFIRMED independently.** For all 12 sites plus `AO`, the builder's class equals the kernel's class (`witness.rs:485-685` against `lib.rs:726-825`, site for site and in the same order). It also equals the U8 lookup window read off `lookups_at`. The one exception is `p`, where the lookup window `2^10` is looser than the builder's `2^9`, the safe direction. |
| 3 | `AO` is reachable above width 258 and covered at `witness.rs:594` | **CONFIRMED independently.** The image is exactly ±127·width (the extreme products are ±16,256). The largest width with `127 w <= 32767` is 258, found by scanning. The four shapes named are exactly the ones above it. |
| 4 | the only finding is S38-F1: padded `Dom::F` positions look up `(128, 0)`, a table row iff `act[128] = 0` | **CONFIRMED for the pads.** It is the only public-table value an ungated arm reads at a pad (§4). **But it is not the only admissibility hole:** C-1 (in the fix) and C-2 (in `Shape::new`) lie outside the census's scope and are real. |
| 5 | S38-F1 is refused at construction (`7472a3c`), by `sh.pads(Dom::F)`, before anything is absorbed or committed | **CONFIRMED-WEAKLY.** The condition is exact: `pads(Dom::F)` holds iff some honest pair is `(128, 0)`. This is proved in general and checked on 392 admitted shapes (§6). The refusal comes before any absorb. But it is keyed on a `Shape` argument that the statement does not carry, and nothing re-checks it (C-1). |
| 6 | 37 edge proofs prove and verify, and one step past each edge is refused by name | **CONFIRMED.** I re-ran the filter myself: 37 `PROVES AND VERIFIES` lines in the lane log, 12 each at G / K4 / K8 plus 1 `AO` at C6. The census filter is green in this branch (`check-ordinary.log`). |
| 7 | challenge-only refusals at 125M: `c_s` 23, `e` 25, `ν` 12, `ζ` 5 | **CONFIRMED independently** from the code (`argument.rs:476-478, 586-587, 947-949`, with the draw sites as listed). The ζ count is 5 because 125M's padded domains `{Ht, L, D, Q, S, Tab}` share five host slots. There are two edge notes on the list (C-4, C-5). |

## 2. Findings

### C-1: the S38-F1(a) refusal is keyed on a shape the statement does not carry (ERRATUM, latent; must be closed before any production caller of the shaped path). REPRODUCED.

**What.** `FeedForwardPublic::new_shaped(sh, ..)` refuses `act[128] != 0`
when `sh.pads(Dom::F)` (lane `private_block.rs:584-586`). The resulting struct
stores the words only (`:550-556`: no shape, no shape digest). Nothing that
later uses it re-checks the table against the shape it is proved at:

* `witness::build_shaped` (`witness.rs:437`);
* `protocol::prove_core` (`protocol.rs:812`, which checks witness plane
  lengths only);
* `verify_core`;
* `run::RunStatement::new` (`run.rs:150-228`, which absorbs `b.digest()` only);
* `run::prove_run` (`run.rs:531-536`).

So any statement whose padded lengths match is admitted at a shape its
constructor never saw.

**Reproducer** (`census_check_tests.rs`):

* The attention half is built at rung-K4. The feed-forward half is rung-K4's
  own zero-padded words with `act[128] = 1`, built at **rung-P2**. The two
  shapes have the same `d_pad = 128` and `f_pad = 256`; rung-P2's `Dom::F`
  does not pad and rung-K4's pads 3,584 of 8,192 positions.
* Measured, `c1_a_statement_built_at_another_shape_bypasses_the_s38_f1_refusal`:
  asked at rung-K4, the constructor refuses by the ruling's name (the
  control). Built at rung-P2, it admits. The builder admits the input, and the
  kernel admits it with equal output. `RunStatement::new(RunShape::rung_k4(1),
  ..)` admits the block. Exactly the 3,584 padded positions look up
  `(128, 0)`.
* End to end, `c1_reproducer_…` (`#[ignore]`d): **the verifier rejects the
  honest proof, `H: pcs zk: group 8: <v, c> != combined claim`**. That is the
  same symptom as S38-F1 itself.

**Reach today.** Every shaped entry point is `pub(crate)` and has test-only
callers. The public API (`FeedForwardPublic::new`, `prove`, `verify`) is
toy-only, and the toy's `Dom::F` does not pad. So no production path reaches
C-1 today. The failure depends only on the public statement, so it leaks
nothing private; it is a liveness and admissibility hole.

**Ruling P-2 is exposed the same way.** `weights_vanish_off_support`
(`:402-418`) has the same keying. For example, `Wg` columns 192–255 are legal
at rung-P2 and padded at rung-K4. I did not build a reproducer for P-2.

**Proposed fix, cheapest first:**

* (a) At the entry of `build_shaped` and `prove_core`, and in
  `RunStatement::new` for every block, re-run the two public-only checks
  against the `sh` in hand: the S38-F1(a) row and P-2's support check.
* (b) Or carry a shape key in each half, meaning the `profile` string or
  `(t_pad, d_pad, f_pad, pads(F), pads(Q))`, and refuse a mismatch at those
  same three places.
* (c) As a second line of defence, make the three silent bucket-0 fallbacks
  of `prove_core` (`protocol.rs:434-444, 839-842, 845-848`) a named prover
  refusal BEFORE the `A` commitment. A miss on an admitted witness is always
  a completeness bug. Refusing publishes nothing, whereas a rejected receipt
  publishes a receipt.

None of the three moves a receipt byte.

### C-2: `Shape::new` admits a softmax window too small for its own tokens; the builder and kernel then admit an input the prover cannot prove (ERRATUM, latent; input-dependent). REPRODUCED.

**What.** `Shape::new` takes `wrho_s: Option<u32>` and uses
`wrho_s.unwrap_or(clog2(tokens) + f_e)` (`shape.rs:230`) without checking an
override against `tokens · 2^f_e`. The builder checks only `sigma_s < 2^wrho_s`
and `q <= 2^F_P` (`witness.rs:554`), and so does the kernel (`lib.rs:643`).
`rho_s` is never checked, yet the prover looks it up in a `2^wrho_s` window
(`layout.rs:769-770`).

On every row but the last, a causally masked position exists. There
`sigma_s = Sum − 1 >= rho_s`, so the `sigma_s` check covers `rho_s`. **The
last token row has no masked position.** There a `rho_s` above the window can
pass alongside every `sigma_s` inside it. The census's own window test states
this premise (`census_shaped_tests.rs:651-658`, "`rho_s` is not checked by the
builder"). It asserts the premise at the ten shapes only.

**Reproducer.** The shape is rung-G's geometry with `wrho_s = Some(15)`, which
`Shape::new` admits; the derivation would give 17. Public synthetic words:

* the exp table is `[4096, 1250, 0, …]`, which is legal;
* an identity RoPE;
* one-hot inputs of magnitude 1000;
* three query/key columns chosen so that rows 0–22 have ONE maximum
  (`Sum = 4096`), while row 23 has 23 tied maxima plus one position a step
  below: `Sum = 95,458`, `rho_s = 92,534 / 67,252`, `sigma_s = 2,923 / 28,205`.

Every `sigma_s` is inside `2^15` and every `rho_s` is outside it.

Measured, `c2_an_overridden_softmax_window_lets_an_admitted_input_break_the_rho_s_lookups`:

* the builder admits the input, and the kernel admits it with equal output;
* **288 U8 words fall outside `[0, 256)`**, all on token row 23: the `rho_s`
  top limb and its scaled lookup, for 6 heads × 24 positions × 2 lookups,
  with values {262, 361, 524, 722};
* the same statement and input at rung-G itself (`wrho_s` 17) are LogUp-clean.

End to end, `c2_reproducer_…` (`#[ignore]`d): the control at rung-G is
**ACCEPTED**, and at the override the **verifier rejects** it, `H: pcs zk:
group 8`.

**Why it matters more than C-1.** Whether the proof fails depends on the
PRIVATE input: the same shape and statement prove other inputs. That is
exactly the class GS-14 exists to exclude.

**The norm override (`shape.rs:228`) is the milder case.** An undersized
`norm_wrho` makes the norm remainder reachable, but the builder refuses both
`rho` and `sigma` there by name. So an UNREACHABLE site becomes
REACHABLE-BUILDER-REFUSES-FIRST, which is a data-dependent refusal rather than
a proof failure.

**Reach today.** No built shape passes either override
(`shape.rs:432-861`, `k8_tests.rs:154`).

**Proposed fix:**

* `Shape::new` refuses, by name:
  * `(tokens << f_e) > (1 << wrho_s)`;
  * `isqrt(1 + width · 32768²) << (NORM_TN + 1) > 1 << norm_wrho`. Use 32768,
    not the 32767 of `d_max`, because −32768 is a legal input.
* Or drop the two `Option` overrides; nothing uses them.
* Also split census row 13 into `rho_s` (guarded by the window premise only)
  and `sigma_s` (guarded by the builder), so that the row's class stays true
  at any shape.

### C-3: seven census rows cannot fail (ERRATUM, documentation; no correctness consequence found)

The memo says every bound is "computed from the shape by the test, not typed
in". For seven of the 34 rows, `reach` is either defined equal to `range` or
typed in. At any shape the class is therefore UNREACHABLE by construction:

* the softmax denominator (`census_shaped_tests.rs:312-320`: both are
  `(one_e, t·one_e)`);
* the softmax quotient (`:321-329`: both are `(0, one_p)`);
* the exp pair (`:378-386`) and the activation pair at a true position
  (`:387-395`): both `(0,0)` against `(0,0)`;
* the output conversion (`:365`: `I16` against `I16`);
* the U8 word at a pad (`:367-377`: `reach (0, 127)` typed, not read off
  `lookups_at`'s constants);
* causal maximum attainment (`:282-290`: an encoding that tests only
  `MASK_SCORE`).

I re-derived each premise myself, and each holds:

* `Sum ∈ [2^f_e, tokens 2^f_e]`, because `exp[0] = 2^f_e`, `arg <= t`, and
  each summand is at most `2^f_e`;
* `p <= 2^F_P`;
* the builder writes `A_E = exp[δ]` at every position including pads
  (`witness.rs:536, 633-644`, the same formula as `exp_deltas`, and δ at a pad
  is 0 or 127);
* `a16 = act[g8+128]` on the support;
* every `lookups_at` constant is 0 or 127 (`layout.rs:595-605`).

Two tests already exercise part of this: `the_unreachable_sites_premises_hold_at_every_shape`
covers the softmax rows on synthetic patterns, and `check_family`'s
`logup_misses` covers the pairs on the edge witnesses. **Fix:** say so in the
memo, or compute these rows' `reach` from the premises (for example, read the
pad constant off `lookups_at`).

### C-4: one challenge-dependent refusal is listed as structural (NOTE)

The memo §2 files `protocol.rs:323` (the opening-group count against the
schedule) as structural. The group key is the tail of a claim's challenge
point (`:186-191`). So two claims collapse into one group, and every proof of
that attempt is refused, if their tail challenges coincide as field elements.
That includes the `ρ_k = 1/2` rotary case that `shape.rs:334-338` itself
names. This belongs in §5's challenge-only list. The probability is
negligible (about `2^-128` per pair); this is liveness only.

### C-5: the zero LogUp denominator's outcome does not depend on the data (NOTE, in the census's favour)

The memo §5 calls the zero LogUp denominator "the only one whose firing
depends on the data". Its outcome does not. The table-helper inversion at
`protocol.rs:957-965` inverts EVERY table row (including the P-3 padded
copies) and refuses if any denominator is zero. Every pair an admitted witness
carries is a table row (this census's own result). So the set of challenges
that refuse is exactly the table's, whatever the input. Only the refusal's
TIMING (at `:922`/`:930`/`:932`, or at `:962`) depends on the data, and
nothing is public at either point.

### C-6: stale figures and loose ends outside the census (NOTE)

* **`layout.rs:671` gives an outdated count.** It says the 125M LogUp
  multiplicity is at most 98,582,528. The P-3-lifted `Dom::L` makes it
  **98,598,912**. That is the census's figure, and `protocol.rs:508` agrees;
  the difference is 2 lookups × 8,192. It is harmless, since both are far
  below `p`.
* **`Shape::new` does not require `width = q_heads · head_dim`.** The kernel
  does (`lib.rs:243`), so at such a shape the builder and the kernel disagree
  for every input. This is public-only, not a completeness hole in the data
  sense.
* **`Shape::new` does not bound `f_e`.** `AttentionPublic::new_shaped`
  shifts `1i64 << sh.f_e` (lane `private_block.rs:489`), which overflows for
  `f_e >= 63`; the kernel refuses `f_e >= 32`. This is public-only.

## 3. Independent site enumeration

I searched `witness.rs`, `protocol.rs`, `argument.rs`, `layout.rs`, `pad.rs`,
`run.rs`, `boundary.rs`, `endpoint_g.rs`, `shape.rs`, `private_block.rs`,
`private-block-kernel-shaped/src/lib.rs`, `hashline/src/zk.rs` and
`hashline/src/pcs.rs`. The search terms were `Err(`, `?`, `assert*`,
`expect`, `unwrap`, `panic!`, `checked_*`, `try_from`/`try_into`, `.inv()`,
`nonzero(`, and the histogram, bucket and pair sites.

**Data-dependent refusal sites of the builder.** There are 25 distinct code
sites: `witness.rs:58, 373, 385, 393, 485, 486, 487, 490, 492, 507, 525, 533,
541, 554, 590, 594, 599, 639, 667, 671, 678, 679, 683, 685, 707`. With the
norm run twice (`:460`, `:649`) that is **28 site instances**. The census's
28 builder rows cover them exactly. It splits `:393` and `:554` into
quotient and remainder, and merges `:373 + :385` (the norm denominator) and
`:678 + :679` (the activation index, both named "FFN gate").

**Kernel.** Each builder site has a counterpart at the same site and in the
same order (`lib.rs:721-825`). The kernel adds only the `Overflow` sites
(`:124-158`) and `:557` (`ss` negative). Both are unreachable (§5); the
largest intermediate is 8.25e11 against `2^63`. The builder has one
builder-only site, the limb window at `:373`, which is unreachable because
`2 D_max <= 1,816,186 < 2^24`.

**Prover and verifier on an admitted witness** (6 census rows):

* U8 word, bucket 0 (`protocol.rs:434-444`);
* exp pair (`:839-842`);
* activation pair (`:845-848`), true positions and pads;
* multiplicity wrap (`:849-853`);
* kernel overflow.

Everything else on the path is either challenge-only or structural:

* zero LogUp denominators (`:922, 930, 932, 962`) are challenge-only
  (see C-5);
* `argument.rs:450-494, 558, 781-812, 1182, 1711, 1849, 1879` are
  structural;
* `argument.rs:476-478, 586-587, 947-949` and `protocol.rs:246, 300, 309`
  are challenge-only, and `:323` is challenge-dependent (C-4);
* the `zk.rs` asserts `1068/1081/1093` repeat the `c_s` check that
  `argument.rs:477` makes first;
* the `zk.rs:442/493` mask-size asserts are structural, and ruling C-4
  refuses first;
* `endpoint_g`, `boundary`, `pcs` and `wire` are structural. The
  noncanonical-word check cannot fire on `i16`.

**Result: 34 of 34.** My count matches the census's, and no data-dependent
refusal site is omitted. The two holes found are not code sites the census
missed. They are **admissibility gaps**: C-1 in the statement–shape binding,
and C-2 in `Shape::new`.

## 4. Public-statement admissibility (siblings of S38-F1)

The question is whether any other public value is consumed at a padded
position by an arm that is not gated, or relied on there by a relation that
is not gated. I went through them one by one:

* **U8 lookups at pads.** Every looked plane is ZERO-rule on a padded domain
  (`pad.rs:289-303`; only `A_E` is EXEMPT, and it is not U8-looked). Every
  `Lk` constant is 0 (`byte`, `scaled`) or 127 (`sym`) (`layout.rs:595-605`),
  so a pad's word is a byte at every shape. The toy's unconstrained `Dom::L`
  pad is also zero from the builder. **Not a sibling.**
* **The exp pair at pads.** `A_E` is EXEMPT, and the builder's pad pass
  writes `exp[δ]` with `δ` computed by `exp_deltas`' own formula. At a padded
  row δ is 0 or 127; at a true row with padded `j` it is `mx + 127 ∈
  [0, 254]`. So the pair is a table row for EVERY admissible exp table. No
  relation needs `E` at a masked or padded position: `SC_SZC`'s clauses force
  `p = rho_s = 0` off the causal support whatever `E` is
  (`argument.rs:1757-1758`), and `SC_RS` is gated by `supp_S`. **Not a
  sibling.**
* **The activation pair.** This is S38-F1: `(128, 0)` at exactly the padded
  `Dom::F` positions. It is the only one.
* **Weights and gains at padded indices.** Ruling P-2 checks them entrywise
  on both axes of every matrix, including `gamma_a` and `gamma_m`
  (lane `private_block.rs:480-484, 573-576`). The axes are right: `Wg`/`Wu` are
  (D, F), `Wd` is (F, D), `Wq` is (Q, D) and `Wo` is (D, Q). Exposed only
  through C-1.
* **RoPE at padded tokens and head slots.** `rope_tables_at` zero-fills them
  (`argument.rs:1002-1020`). The rope clause is inhomogeneous but gated by
  `supp_Q` / `supp_Kv`. **Not a sibling.**
* **Tables at the lifted `Dom::Tab` rows.** Entry `i` repeats `i mod 256`
  (`argument.rs:1046-1065`), and the multiplicities and table helpers there
  are ZERO-rule and written zero. **Not a sibling.**
* **Endpoint and run scales, and the calibration identity.** They are pinned
  to `(0, 0)` and to one digest (lane `private_block.rs:708-709`, `run.rs:193-200`),
  and have no arithmetic effect.
* **Shapes `Shape::new` accepts.** This is **C-2**. There are also the public
  loose ends of C-6.

**Conclusion.** At the padded positions, S38-F1 is the unique
public-statement hole. Beyond the pads there are two admissibility holes:
C-1 (the binding between statement and shape) and C-2 (the constructor's
windows).

## 5. Bounds re-derived

`results/zk60_census_check/bounds.py` (output `bounds.log`) re-derives every
figure from the code: `witness.rs`, the shaped kernel, `layout::lookups_at`,
`Shape::new` and `domain_log_at`. It does not use the census test. It uses
exact integer arithmetic and asserts the memo's figures at all ten shapes.
Result: **every figure agrees.**

* **Norm output `y`.** The exact image over `|x| <= D` and `g in [-128, 127]`,
  enumerated, is **[-64, 64]**. Both ends are hit: `x = D, g = 127` gives 64,
  `x = -D, g = -128` gives 64, and `x = D, g = -128` gives -64. The census's
  `(128 + 1) / 2 = 64` is right.
* **Q/K/V image** `requant(width * 64 * 128, 7) = 64 width`: toy 1,024; rungs
  6,144; rung-K8 8,192; rung-C6 24,576; W14 / E32 / 125M 49,152. This agrees
  with the memo.
* **AO image.** The extreme products are `(-127)(-128) = +16,256` and
  `(127)(-128) = -16,256`, so the image is **exactly ±127 · width**: toy
  2,032; rungs 12,192; K8 16,256; C6 48,768; W14 / E32 / 125M 97,536. The
  largest width with `127 w <= 32767` is **258**, computed by scanning widths.
  So `AO` is reachable exactly at C6, W14, E32 and 125M.
* **FFN down** `requant(hidden * 32768 * 128, 6)`: 1,048,576 at the toy up to
  134,217,728 at 125M. The **product** image is [-65,534, 65,536]. The census
  states only `+65,536`, which is the side that matters.
* **Norm windows.** `D_max` over the int16 class (−32768 is legal) is 131,072 /
  321,059 / 370,727 / 642,119 / 908,093. That gives `den_max = D_max · 2^12
  <= 2^norm_wrho` at every shape. The toy sits exactly on its window (ratio
  1.0). The margin at 125M is **0.2075 bits**, matching layout's "0.21". The
  isqrt witness satisfies `2 D_max < 2^24` everywhere.
* **Softmax window.** `tokens · 2^f_e <= 2^wrho_s` holds at all ten shapes
  with the DERIVED `wrho_s`. This premise is the one C-2 breaks with an
  override.
* **Largest LogUp multiplicity.** This is the U8 looked-word total over the
  lifted cubes: toy **61,440**, rung-G 419,840, K8 555,008, C6 1,214,464,
  W14 4,882,432, 125M **98,598,912**. All match the memo.
* **Largest kernel intermediate.** `1 + width · 2^30` wins at every shape:
  toy **1.72e10**, 125M **8.25e11**. Both are far below `2^63`.
* **Padded `Dom::F` positions.** Rung, rung-G, K4 and K8 each have **3,584 of
  8,192**; the other six shapes have 0.

**Do the census tests read these off the shape?** Yes for the rows that carry
a real bound: norm, Q/K/V, QR/KR, score, O, AO, residuals, FFN, multiplicity
and kernel. Each computes `reach` from the `Shape` and the calibration
constants. A changed width would move AO's class, and the test would fail,
because it asserts that class against a named shape list. **Seven rows cannot
fail, whatever the shape** (C-3).

## 6. The fix `7472a3c`

* **Is `sh.pads(Dom::F)` exactly the condition?** Yes. The builder writes
  `(g8, a16)` only on `Geom::support(Dom::F)`, whose index `t · f_pad + j`
  (`t < tokens`, `j < hidden`) is injective and inside the lifted cube.
  Every other position stays `(0, 0)`. `act_indices` and `m_act` read the
  whole plane (`protocol.rs:475-477, 843-848`), and the arm is never gated.
  So some honest pair is `(128, 0)` iff `size(F) > tokens · hidden`, and
  `Shape::pads` is exactly that condition (`shape.rs:1016-1018`, which
  counts the P-3 lift too).
  * Measured on **392 `Shape::new`-admitted shapes** (264 of them pad
    `Dom::F`), not only the ten:
    `the_s38_f1_condition_is_exactly_the_padded_feed_forward_positions_on_a_grid_of_admitted_shapes`.
  * No shape pads `Dom::F` without carrying the pad rule. Only the frozen
    toy profile lacks the rule, and the toy does not pad `F`. In any case the
    refusal is geometric, so it applies either way.
* **Can a `FeedForwardPublic` be built without `new_shaped`?** No:
  * there is no struct literal or field mutation outside `cfg(test)`, and
    there is no byte parser (grep over `hashline/src`);
  * `run_statement_file.rs` is `cfg(test)`;
  * the census's own bypass (`statement_bypassing_the_s38_f1_refusal`,
    `Clone` + `ff.act[128] =`) is in a test module.

  But `new_shaped` at ANOTHER shape is the bypass: **C-1**.
* **Is the refusal reached before anything is absorbed or committed?** Yes.
  It is in the constructor, before `BlockPublic`, the endpoint owners, the
  transcript or any commitment exists. Nothing new is absorbed; `absorb_into`
  is unchanged, so no receipt byte moves. This holds only as long as the
  statement is built at the shape it is proved at (C-1).
* **Did the census's control run end to end?** Yes. The census's reproducer
  control and my C-1 reproducer both fail at the verifier with the same
  symptom (`H: pcs zk: group 8`), so the refusal guards a real failure.

## 7. What this check did NOT cover

* **Soundness,** including the field-wrap premise (`layout.rs:639-648`),
  which the brief put out of scope. The hash layer, the PCS internals and the
  mask commitment were covered only for refusal sites; their soundness is not
  checked.
* **No proof at 125M.** The 125M rows were re-derived arithmetically only. No
  125M witness was built.
* **The slot relations were not re-derived symbolically** for every
  admissible witness. Like the census, I rely on the edge witnesses, the 37
  proofs and my two controls.
* **P-2's exposure through C-1 was not reproduced.** A padded-weight
  cross-shape case would need its own reproducer.
* **The lower edges of the reachable sites** (other than the gate's −128)
  were not driven, just as in the census.
* **Runs.** I checked only that `RunStatement::new` admits a cross-shape
  block (C-1). I proved no run.
* **No memory cap on the test run.** `systemd-run --user` failed on this box
  (no user bus: `Failed to connect to bus`). The runs therefore went detached
  under `setsid nohup` and the build lock without a memory cap. They are
  small-rung only, the ordinary filter took 9 s and the reproducers 1 s.
* **No privacy property** of any shape.

## 8. Evidence

All runs were measured on the shared box. It was not quiesced, so the timings
are indicative only.

| run | log | result |
|---|---|---|
| bounds, Python | `results/zk60_census_check/bounds.log` | exit 0, `ALL CENSUS FIGURES RE-DERIVED: OK` |
| `--lib census_` (the lane's census plus my ordinary tests plus 3 unrelated `census`-named tests) | `check-ordinary.log` (`.done` = 0) | **17 passed / 0 failed / 2 ignored**, 8.95 s |
| my ordinary tests, `--nocapture` | `check-ordinary-nocapture.log` (`.done` = 0) | 3 / 0 / 2. Printed: the C-1 line (3,584 of 8,192 misses; every constructor, builder, kernel and `RunStatement` step admits), the C-2 line (288 misses, values {262, 361, 524, 722}; control clean), and the grid (392 shapes, 264 padded) |
| my reproducers, `--ignored` | `check-reproducers.log` (`.done` = 101) | **both FAIL, as reproducers must.** C-1: `verifier rejected: H: pcs zk: group 8: <v, c> != combined claim`. C-2: control rung-G `ACCEPTED`, then `wrho_s = 15` `verifier rejected: H: pcs zk: group 8` |

Test file: `hashline/src/private_block/census_check_tests.rs`. It is wired by
one `#[cfg(test)] mod census_check_tests;` line in `private_block.rs` and is
review-branch only. No production line changed.
