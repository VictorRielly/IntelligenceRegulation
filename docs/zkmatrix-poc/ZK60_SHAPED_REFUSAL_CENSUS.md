# ZK60 — the shaped refusal census (GS-14's first item), stage 38

**Date:** 2026-09-22, 20:49–21:2x PDT. **Lane:** `zk60-private-block-125m`
(worktree `wt-zk60-block125m`), opened on `bacc274`. **Asked for by:** ruling
NL-8 of `ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md` and finding N-9 of
`ZK60_NONLINEAR_CHANNEL_SHAPED_CHECK.md`. **Code:**
`hashline/src/private_block/census_shaped_tests.rs` (test-only; one
`#[cfg(test)] mod` line in `private_block.rs`). **Evidence:**
`results/zk60_block125m_lane/s38-census.log` (the census filter) and
`s38-f1-reproducer.log` (the finding's reproducer).

**Not a privacy result.** This is a completeness census: it asks whether an
input the witness builder ADMITS can make the honest prover or verifier
refuse. It makes no claim about what a receipt reveals.

## 1. In plain words

A proof that fails on a legal input is a problem twice over: the honest user
gets no proof, and if the failure depends on the private input, the fact that
it failed tells an observer something about that input. The toy block has a
census (`refusals.rs`) proving that every place the builder, the reference
kernel or the prover could refuse is either impossible to reach or is refused
first, by name, by the builder. That census was written with the toy's own
numbers and does not carry over: at 125M the output projection sums 768 terms
instead of 16 and can overflow int16 (finding N-9).

This stage redoes the census at **every registered shape** (the toy, the
frozen-seam rung, rung-G, rung-K4, rung-P2, rung-C6, rung-W14, rung-E32,
125M) and at stage 37's test-only rung-K8, with every bound **computed from
the shape** by the test, not typed in. Result:

* **12 sites are reachable at every shape and the builder refuses each first,
  by name, with exactly the class the kernel and the prover's lookups use**;
  `AO` joins them at the four shapes wider than 258 (rung-C6, rung-W14,
  rung-E32, 125M). All other data-dependent sites are unreachable.
* At each of the 13 reachable sites a test builds an input **exactly on the
  edge** (the value equals the class limit) that **proves and verifies**, and
  one step past it that the builder and the reference kernel both refuse with
  the same message — at rung-G, rung-K4 and rung-K8 (and `AO` at rung-C6).
  37 honest edge proofs, all accepted. MEASURED.
* **One finding, S38-F1 (first rank):** at the shapes whose feed-forward
  domain has padding (the rung, rung-G, rung-K4, rung-K8 — **not 125M**), a
  public activation table with `act[128] != 0` is accepted by the statement
  constructor and by the builder, yet **every** honest proof then fails. It
  depends only on the public table, not on the private input, so it leaks
  nothing private; it is a gap in what the public statement is allowed to be.
  Not fixed here (production file); an `#[ignore]`d reproducer records it.

## 2. What was enumerated

Every refusal on the proving path, sorted by what it depends on.

**Data-dependent** (the census rows; section 3): every range and relation
site of the witness builder `witness.rs` and of the shaped reference kernel
`private-block-kernel-shaped/src/lib.rs` (the same sites, in the same order,
plus the kernel's checked-arithmetic `Overflow` sites and the builder-only
norm limb window and `A_E` pad pass), and the three ways the PROVER can be
handed an admitted witness it cannot prove: a looked-up U8 word outside
`[0, 256)` (the histogram files it in bucket 0, `protocol.rs:434-444`, and
only the LogUp identity notices), an exp or activation pair that is not a
table row (`protocol.rs:835-848`), and a LogUp multiplicity that wraps the
field.

**Challenge-only** (liveness, not completeness; section 5): refused if a
Fiat–Shamir draw lands in a set of negligible size.

**Structural** (not in the census): refusals that are functions of the public
shape and schedule only — the named `Shape::new` refusals (F-2, S-1, S-3,
S-6, C-4), `Ids::new`, the pinned norm-limb count (`witness.rs:429-434`),
`fits_the_ntt_tables` (`protocol.rs:62`), the schedule checks of `run_slot`
(`argument.rs:451, 454, 463, 494, 558, 781, 797, 809, 812, 1182, 1711, 1849,
1879`), the `eq_cube` precondition assert (`argument.rs:285`), the opening
audit and group count (`protocol.rs:205, 231-273, 323`), the endpoint
geometry (`protocol.rs:359, 367, 386, 666, 669`), the witness shape
(`protocol.rs:813`), the statement constructors' length and pad-support checks
(`private_block.rs:385-387, 474, 486, 571, 577`), and the kernel's `Shape` /
`Table` refusals. The endpoint preparation's "noncanonical input words"
(`endpoint_g.rs:262`) cannot fire on an `i16` plane. The three `assert!`s at
`protocol.rs:866, 867, 980` belong to a `#[cfg(test)]` hook and are not in a
production build.

## 3. The site table

**The admissible class** (what the TYPES and the statement constructors
enforce): the hidden input is `i16` (so `-32768` is legal — the census uses
`|x| <= 32768`, not the 32,767 of `Shape::new`'s `d_max`); every weight and
gain is `i8` (`|w| <= 128`); RoPE entries lie in `[-128, 128]` with position
0 the identity; the exp table has `E[0] = 2^fE`, entries in `[0, 2^fE]`,
non-increasing; the activation table is any `[i16; 256]`.

**The classes.** UNREACHABLE: the worst case over the admissible class stays
inside the class the site tests. REACHABLE-BUILDER-REFUSES-FIRST: it can leave
it, and the builder refuses at this site, by name, before the value reaches
anything downstream, with exactly the class the kernel and the lookups use.
FINDING: reachable and not covered.

| # | site | builder / kernel / downstream | worst case (from the shape) | class |
|---|---|---|---|---|
| 1 | norm denominator (norm_a, norm_m) | `witness.rs:373-375, 385-387` / `lib.rs:557, 561-562` / 3 byte limbs of D, a1, a2 | `1 <= D`, `a2 <= 2 D_max`, `D_max = isqrt(1 + width * 32768^2)` | U at every shape (`2 D_max <= 1,816,186 < 2^24`) |
| 2 | norm quotient (both) | `witness.rs:393-395` / `lib.rs:569-570` / `sym(A_Y)`, `sym(A_YM)` | `|q| <= floor(128/2 + 1/2) = 64` because `|x_i| <= D` | U |
| 3 | norm remainder window (both) | same / `A_NR*`, `A_NS*`, `A_MR*`, `A_MS*` | `rho, sigma <= D_max 2^12 - 1` against `2^norm_wrho` | U (the toy sits exactly on it: `D_max = 2^17`, `den - 1 = 2^29 - 1`) |
| 4–6 | Q, K, V | `witness.rs:485-487` / `lib.rs:726-728` / `sym` | `requant(width * 64 * 128, 7) = 64 width` | R-B at every shape |
| 7–8 | QR, KR | `witness.rs:490, 492` / `lib.rs:732-733` / `sym` | `requant(2 * 128 * 127, 7) = 254` | R-B |
| 9 | score | `witness.rs:507` / `lib.rs:749` / `sym(A_S8)` | `requant(head_dim * 127^2, 6)` | R-B |
| 10 | causal maximum attainment | `witness.rs:525-527` / `lib.rs:618-619` | `MASK = -127` is the score class's minimum; first strict max | U |
| 11 | exp difference (+ the builder's `A_E` pad pass, `witness.rs:639-641`) | `witness.rs:533-535` / `lib.rs:624-625` / exp pair | `delta in [0, 254]`; on a pad `delta in {0, 127}` | U |
| 12 | softmax denominator | `witness.rs:541-543` / `lib.rs:632-633` | `Sum in [2^fE, tokens 2^fE]` (the statement's exp rules) | U |
| 13 | softmax quotient / remainder window | `witness.rs:554-556` / `lib.rs:643-644` / `A_PL*`, `A_SR*`, `A_SG*` | `p <= 2^9`; `sigma_s <= tokens 2^fE - 1 <= 2^wrho_s - 1` | U (tight at power-of-two token counts, by construction) |
| 14 | O | `witness.rs:590` / `lib.rs:783` / `sym(A_O8)` | `sum_j p_j <= 2^9`, so `requant(512 * 127, 9) = 127` | U at every shape |
| 15 | **AO** | `witness.rs:594` / `lib.rs:793` / `A_AL0/1` | `requant(width * 127 * 128, 7) = 127 width` | **U for width <= 258** (toy 2,032; rungs 12,192; rung-K8 16,256); **R-B at rung-C6 (48,768), rung-W14 / rung-E32 / 125M (97,536)** |
| 16 | residual 1 | `witness.rs:599-601` / `lib.rs:796-798` / `A_X1L0/1` | `x + ao` over int16 plus AO's admitted image | R-B |
| 17 | FFN gate | `witness.rs:667` / `lib.rs:808` / the activation pair's index | `requant(width * 64 * 128, 7)` against `[-128, 127]` | R-B |
| 18 | FFN gate (activation index) | `witness.rs:678-679` / `lib.rs:812-813` | `g8 + 128 in [0, 255]` after 17 | U |
| 19 | FFN up | `witness.rs:671-673` / `lib.rs:810` / `A_UL0/1` | `width * 64 * 128` (no requant, `SH_U = 0`) | R-B |
| 20 | FFN product | `witness.rs:683` / `lib.rs:818` / `A_HL0/1` | `requant(32768^2, 14) = 65,536` | R-B |
| 21 | FFN down | `witness.rs:685` / `lib.rs:820` / `A_ZL0/1` | `requant(hidden * 32768 * 128, 6)` | R-B |
| 22 | residual 2 (+ the output conversion, `witness.rs:58` / `lib.rs:828`) | `witness.rs:707-709` / `lib.rs:823-825` / `A_X2L0/1` | `xres1 + z16` over int16 | R-B (the conversion: U) |
| 23 | U8 word at a padded position | `protocol.rs:396-417, 434-444` | every ZERO-rule plane is 0 on the pad, so a word is its lookup's constant, 0 or 127 | U |
| 24 | exp pair not a table row | `protocol.rs:837-841` | the builder writes `A_E = exp[delta]` at every position, pads included | U |
| 25 | activation pair not a row, true position | `protocol.rs:843-847` | the builder writes `a16 = act[g8 + 128]` | U |
| 26 | **activation pair not a row, padded `Dom::F` position** | `protocol.rs:843-847`; the LogUp arm is never gated (`argument.rs:1567-1570`) | the pad carries `(g8, a16) = (0, 0)`, so the pair is `(128, 0)`, a row iff `act[128] == 0`; `FeedForwardPublic::new_shaped` admits any `act[128]` | **FINDING S38-F1 where `Dom::F` pads** (rung, rung-G, rung-K4, rung-K8); U elsewhere (no such position) |
| 27 | LogUp multiplicity wraps the field | `protocol.rs:835-853` | the largest count is the U8 looked-word total: 61,440 (toy) … 98,598,912 (125M) | U |
| 28 | kernel checked-arithmetic overflow (every `Overflow` site) | `lib.rs:124-158` via `:508, 525, 555-565, 592-593, 623-637, 743, 768, 796, 816, 823` | the largest intermediate: 1.7e10 (toy) … 8.2e11 (125M), against `2^63 - 1` | U; the builder's unchecked `i64` works on the same bounds |

U = UNREACHABLE, R-B = REACHABLE-BUILDER-REFUSES-FIRST. The test prints the
34 rows (the three norm rows twice) with numbers at each of the ten shapes
(`S38 CENSUS` lines of the log). COUNTED, per shape:

| shape | width / hidden / head_dim | U | R-B | FINDING | AO image | Q image | FFN down image |
|---|---|---:|---:|---:|---:|---:|---:|
| toy | 16 / 16 / 8 | 22 | 12 | 0 | 2,032 | 1,024 | 1,048,576 |
| rung (frozen seam) | 96 / 192 / 16 | 21 | 12 | 1 | 12,192 | 6,144 | 12,582,912 |
| rung-G | 96 / 192 / 16 | 21 | 12 | 1 | 12,192 | 6,144 | 12,582,912 |
| rung-K4 | 96 / 192 / 8 | 21 | 12 | 1 | 12,192 | 6,144 | 12,582,912 |
| rung-K8 (test-only) | 128 / 192 / 8 | 21 | 12 | 1 | 16,256 | 8,192 | 12,582,912 |
| rung-P2 | 96 / 256 / 8 | 22 | 12 | 0 | 12,192 | 6,144 | 16,777,216 |
| rung-C6 | 384 / 512 / 32 | 21 | 13 | 0 | **48,768** | 24,576 | 33,554,432 |
| rung-W14 | 768 / 1024 / 64 | 21 | 13 | 0 | **97,536** | 49,152 | 67,108,864 |
| rung-E32 | 768 / 1024 / 64 | 21 | 13 | 0 | **97,536** | 49,152 | 67,108,864 |
| 125M | 768 / 2048 / 64 | 21 | 13 | 0 | **97,536** | 49,152 | 134,217,728 |

These figures were also computed independently in Python from the same
formulas before the Rust ran, and agree (not retained; a cross-check only).

## 4. Why "the builder refuses first" is enough — the order check

For a reachable site the implication needed is: every witness the builder
admits has the value inside the class the kernel refuses outside of, and
inside the set the prover's lookups accept. Three tests establish it.

1. **The class the lookups accept, read off the production list.**
   `the_builder_class_of_every_looked_plane_is_the_lookup_window_at_every_shape`
   scans `lookups_at` at every shape and derives, plane by plane, the set of
   values the U8 lookups admit: the nine `sym` planes admit exactly
   `[-127, 127]`; the seven int16 limb pairs exactly `2^16` values; the eleven
   requantization remainders exactly `2^sh`; both norms' `rho` / `sigma`
   exactly `2^norm_wrho` (with and without correction C-6's dropped lookups);
   `rho_s` / `sigma_s` exactly `2^wrho_s`; the isqrt limbs exactly `2^24`. Each
   equals the builder's own class. The one inequality is the softmax quotient
   `p`, whose window `2^10` is LOOSER than the builder's `p <= 2^9` — the safe
   direction. The gate `g8` carries no U8 lookup at all, so its class
   `[-128, 127]` is the activation table's 256 rows, which the builder's check
   equals. Every plane any lookup narrows is accounted for (60 planes at the
   toy, 62 elsewhere). MEASURED (the test is green at all ten shapes).
2. **The edges, end to end.** For each of the 13 reachable sites a family of
   hand-built public synthetic statements puts the value EXACTLY on the class
   edge (the witness plane's extreme equals 127, -128 for the gate, or 32767),
   and moves one knob by the smallest step to leave it. Inside: the builder
   admits, every checkable relation holds, every word the prover would look up
   is a table row, the reference kernel accepts with the same block output,
   and the proof is ACCEPTED by the verifier. Just past: the builder refuses
   with `fixed oracle range refusal: <site>` and the kernel with the identical
   string. MEASURED at rung-G (12 sites), rung-K4 (12), rung-K8 (12) and
   rung-C6 (`AO`): 37 edge proofs, each 0.54–1.54 s. The `AO` family cannot be
   built at rung-G at all (its solver cannot reach the edge), which is the
   census row's "unreachable at width <= 258" seen from the other side.
3. **The unreachable rows' premises, exercised.** The norm quotient closed
   form over each shape's own `D_max` and the extreme gains, the softmax row
   sum over each shape's token count and `F_E`, the `O` bound, and the
   statement rules the softmax rows rest on (a broken `E[0]`, range,
   monotonicity or RoPE range is refused by `AttentionPublic::new_shaped`).

The refusal ORDER is the kernel's: the builder runs the same sites in the same
sequence (`witness.rs` follows `lib.rs:721-825` step for step); the two
builder-only checks (the norm limb window and the `A_E` pad pass) and the
kernel-only `Overflow` sites are all unreachable, so neither side can refuse
at a site the other never visits.

## 5. The challenge-only refusals (liveness, listed per NL-6)

COUNTED per block, at every shape (`S38 CHALLENGE-ONLY` lines):

| refusal | where | count per block |
|---|---|---|
| CFS mask multiplier `c_s = 0` | `argument.rs:478` | 23 |
| a terminal challenge `e in {0, 1}` | `argument.rs:587` | 25 |
| a host arm's hosted-claim weight `nu = 0` | `argument.rs:949` via `:1142` (SC_TZC), `:1405` (SC_DZC), `:1552` (SC_FZC), `:1605` (SC_QZC and SC_KVZC), `:1663` (SC_SZC) | **12** (six hosts x 2) |
| a pad-zero weight `zeta = 0` | `argument.rs:949` via `:1143, 1210, 1406, 1553, 1606, 1664, 1786` | 0 (toy), 8 (rung, rung-G, K4, K8), 5 (P2, C6, W14, E32, **125M** — GN-8's five) |
| a zero opening-group member coefficient | `protocol.rs:300` | one per claim, over 44 (toy) / 45 groups |
| dependent proximity coefficients | `protocol.rs:309` | 4 (A, H, two endpoints) |
| a zero terminal mask coefficient in the audit | `protocol.rs:246` | per reserved-pair part |
| a zero LogUp denominator | `protocol.rs:494, 569-574` | the only one whose firing depends on the data (it fires iff `alpha` equals a denominator the witness carries), at most 256 byte values + one pair per exp / activation position against `|Fp2| ~ 2^128` |

Each is refused, never resampled on the same transcript, and none is a
function of the private input except the last, whose chance is negligible.

## 6. Finding S38-F1 (first rank)

**What.** On a shape whose `Dom::F` pads, the padded positions of `A_G8` and
`A_A16` are ZERO (the pad rule proves them zero). The activation LogUp arm is
deliberately NOT gated (`argument.rs:1567-1570`: gating it would drop the pads
out of the value-0 identity), so every padded position looks up the pair
`(g8 + 128, a16) = (128, 0)`. That is a row of the table only when
`act[128] == 0`. `FeedForwardPublic::new_shaped` (`private_block.rs:568-579`)
accepts any `[i16; 256]` and the builder admits every input under it. With
`act[128] != 0` the prover files those pairs in bucket 0
(`protocol.rs:846-847`) and the identity cannot balance.

**Where.** The frozen-seam rung, rung-G, rung-K4 and rung-K8 (24 tokens:
`Dom::F` = 32 x 256 cube around 24 x 192 true — 3,584 of 8,192 positions are
pads). NOT the toy, rung-P2, rung-C6, rung-W14, rung-E32 or **125M**, whose
`Dom::F` does not pad. MEASURED by
`s38_f1_the_padded_feed_forward_positions_look_up_a_pair_that_is_not_a_row_when_act_128_is_nonzero`:
with `act[128] = 1` exactly the 3,584 padded positions miss the table at
rung-G, rung-K4 and rung-K8, and the same statement is LogUp-clean at rung-P2
and rung-C6.

**End to end.** `s38_f1_reproducer_an_honest_proof_with_a_nonzero_gate_zero_activation_is_accepted_at_rung_g`
(`#[ignore]`d) builds that statement at rung-G with all-zero weights and the
all-ones input: builder and kernel admit it, and the honest proof is
**rejected by the verifier** (`H: pcs zk: group 8: <v, c> != combined
claim`). MEASURED (section 8).

**Why it has not been seen.** Every table the lane has ever proved with is the
frozen SiLU member, and `SiLU(0) = 0`, so `act[128] = 0`. The toy census's
constant `act = 32767` fixture runs at the toy, whose `Dom::F` does not pad.

**What it leaks.** Nothing private: the failure depends on the public table
and the shape only, identically for every input. It is a completeness hole in
the public-statement admissibility, not an input-dependent one.

**The fix belongs to the owner of `private_block.rs` / `witness.rs`,** one of:
(a) refuse `act[128] != 0` in `FeedForwardPublic::new_shaped` at a shape whose
`Dom::F` pads (cheapest; every SiLU-family table already satisfies it); or
(b) write the pad's `A16` as `act[128]` and move `A_A16` from ZERO to EXEMPT,
as `A_E` is (S12-F3) — which changes the pad table, the gate and every shaped
receipt's commitments. **What would justify (b) over (a):** an approved
activation whose value at gate 0 is not 0.

## 7. What this census does NOT cover

* **Soundness.** The field-wrap premise (`layout.rs:639-648`: every integer
  relation stays below `p`) is a soundness statement and is not re-derived.
  Completeness needs only that each relation holds over the integers, which
  implies it holds mod `p`.
* **The relations beyond the lookups.** The 23 slot relations are checked on
  the edge witnesses by `pad::every_checkable_relation_holds` and, end to end,
  by the 37 accepted proofs; they are not re-derived symbolically for every
  admissible witness.
* **The hash layer, the PCS and the mask commitment**: no data-dependent
  refusal was found there beyond the challenge-only ones of section 5; the
  Merkle and Reed–Solomon code is not censused.
* **Runs.** A run's block `k + 1` reads block `k`'s `xres2`, which is int16
  by row 22, so every block of a run is inside the admissible class; the run
  layer's own refusals (`run.rs`) are structural.
* **Only the edges tested.** Each reachable site was driven to one edge (the
  upper edge, and the lower edge `-128` for the gate), not both.
* **125M is COUNTED, not proved.** No 125M witness was built in this stage.
* **No privacy property** of any shape.

## 8. Evidence

All MEASURED on the shared box (not quiesced; timings are indicative only).

| run | log | result |
|---|---|---|
| the census filter `--lib census_shaped` | `s38-census.log` (`.done` = 0) | **9 passed / 0 failed / 1 ignored** (the reproducer), 28.16 s; no compiler warning in the new file. The one `panicked at ...:848` line in the log is the EXPECTED panic `the_output_projection_...` catches: the `AO` family's solver cannot reach the edge at rung-G |
| the S38-F1 reproducer, `--ignored` | `s38-f1-reproducer.log` (`.done` = 101) | **FAILS, as a reproducer must**: the builder and the kernel admit the statement, the prover produces a receipt, and the **VERIFIER rejects** it — `H: pcs zk: group 8: <v, c> != combined claim` (the same symptom S12-F3's unfilled `A_E` pad produced) |

Source digests at this stage: `census_shaped_tests.rs` SHA-256
`04d4d1bb...ae873e56`; `private_block.rs` moves from `7a9b31ac...ee00dc82` to
`b6728273...652a3456` (the two `cfg(test)` lines only; full digests in the
lane ledger, stage 38).
