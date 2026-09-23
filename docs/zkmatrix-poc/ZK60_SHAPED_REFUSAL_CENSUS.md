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
  **FIXED at `7472a3c` (stage 39, 2026-09-22), by ruling S38-F1(a): the
  statement constructor now refuses such a table by name at those shapes —
  see §6.**
* **Stage 40 (2026-09-22/23), the disposition's rulings CS-1, CS-2, CS-3 on
  the adversarial check:** the S38-F1(a) and P-2 checks are re-run, by name,
  wherever a feed-forward statement meets the shape it is proved at (CS-1);
  `Shape::new` refuses undersized window overrides (CS-2) and, by note C-6,
  `f_e > 31`; a lookup miss is one named prover refusal before the `A`
  commitment (CS-3) — see §9.

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
audit (`protocol.rs:205, 231-273`; the group COUNT at `:323` is
challenge-dependent and is listed in §5 since stage 40, note C-4), the endpoint
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
| 26 | **activation pair not a row, padded `Dom::F` position** | `protocol.rs:843-847`; the LogUp arm is never gated (`argument.rs:1567-1570`) | the pad carries `(g8, a16) = (0, 0)`, so the pair is `(128, 0)`, a row iff `act[128] == 0`; `FeedForwardPublic::new_shaped` admits any `act[128]` | **FINDING S38-F1 where `Dom::F` pads** (rung, rung-G, rung-K4, rung-K8); U elsewhere (no such position). **Since `7472a3c` (stage 39): COVERED-BY-THE-STATEMENT-REFUSAL where `Dom::F` pads** (§6) |
| 27 | LogUp multiplicity wraps the field | `protocol.rs:835-853` | the largest count is the U8 looked-word total: 61,440 (toy) … 98,598,912 (125M) | U |
| 28 | kernel checked-arithmetic overflow (every `Overflow` site) | `lib.rs:124-158` via `:508, 525, 555-565, 592-593, 623-637, 743, 768, 796, 816, 823` | the largest intermediate: 1.7e10 (toy) … 8.2e11 (125M), against `2^63 - 1` | U; the builder's unchecked `i64` works on the same bounds |

U = UNREACHABLE, R-B = REACHABLE-BUILDER-REFUSES-FIRST.

**Seven rows are PREMISES CHECKED BY READING, not tests (note C-3 of the
check, labelled at stage 40).** Their `reach` is typed in or defined equal to
their `range`, so they cannot fail at any shape: row 10 (causal maximum
attainment: an encoding that tests only `MASK_SCORE`), row 12 (softmax
denominator: `reach = range = [2^fE, tokens 2^fE]`), the QUOTIENT half of row
13 (`reach = range = [0, 2^F_P]`), row 22's output conversion (`I16` against
`I16`), row 23 (the pad word's `reach (0, 127)` is typed, not read off
`lookups_at`), and rows 24 and 25 (`(0, 0)` against `(0, 0)`). The checker
re-derived each premise by hand (`Sum in [2^fE, tokens 2^fE]`, `p <= 2^F_P`,
`A_E = exp[delta]` written everywhere, `a16 = act[g8 + 128]` on the support,
every `lookups_at` constant 0 or 127) and each holds; the test source carries
the same label at each of the seven. Two tests exercise part of them
(`the_unreachable_sites_premises_hold_at_every_shape`, `check_family`'s
`logup_misses`). **Row 13's remainder half** (`rho_s` against `2^wrho_s`) is
guarded by the window premise `tokens 2^fE <= 2^wrho_s` alone on the last
token row; since stage 40 `Shape::new` enforces that premise at every shape it
admits (ruling CS-2, §9).

The test prints the
34 rows (the three norm rows twice) with numbers at each of the ten shapes
(`S38 CENSUS` lines of the log). COUNTED, per shape (as at stage 38; since
stage 39 the FINDING column is 0 everywhere and the rung, rung-G, rung-K4
and rung-K8 carry one row COVERED-BY-THE-STATEMENT-REFUSAL instead — §6):

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
| a zero LogUp denominator | `protocol.rs:494, 569-574` | at most 256 byte values + one pair per exp / activation position against `|Fp2| ~ 2^128`. **Corrected at stage 40 (note C-5 of the check):** WHETHER it refuses does not depend on the data — the table-helper inversion (`protocol.rs:957-965` at stage 38) inverts every table row, and every pair an admitted witness carries is a table row, so the set of refusing challenges is the table's; only WHEN (at the helper columns or at the table helpers) depends on the data, and nothing is public at either point |
| the opening-group count against the schedule (**moved here from §2 at stage 40, note C-4**) | `protocol.rs:323` | a group key is the tail of a claim's challenge point (`:186-191`), so two claims whose tail challenges coincide as field elements — including the `rho_k = 1/2` rotary case `shape.rs` names — collapse into one group and every proof of that attempt is refused; about `2^-128` per pair; liveness only |

Each is refused, never resampled on the same transcript, and none is a
function of the private input (the zero LogUp denominator's timing is, its
outcome is not — note C-5), and each chance is negligible.

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

**FIXED at `7472a3c` (stage 39, 2026-09-22 21:4x PDT) — ruling S38-F1(a),
security owner, 2026-09-22.** Option (a) was taken; option (b) was not (it
would move every shaped receipt; revisit only if an approved activation with
a nonzero value at gate 0 is ever proposed). `FeedForwardPublic::new_shaped`
(`private_block.rs:584-586`) now returns
`"private block: activation table act[128] must be 0 at a shape whose
feed-forward domain pads (ruling S38-F1(a))"` when `sh.pads(Dom::F)` and
`act[128] != 0` — the condition read off the `Shape`, exactly the census's,
not a list of names. Where `Dom::F` does not pad nothing changes, and the
statement digest (`absorb_into`) is untouched, so no receipt byte moves.
MEASURED (`s39-census-after.log`, `--lib census_shaped` 11 passed / 0 failed
/ 0 ignored):

* `s39_new_shaped_refuses_a_nonzero_gate_zero_activation_by_name_exactly_where_the_feed_forward_domain_pads`
  — at all ten census shapes, `act[128]` in `{1, -1, 32767, -32768}` is
  refused by that name at the rung, rung-G, rung-K4, rung-K8 (3,584 of 8,192
  `Dom::F` positions padded) and admitted at the toy, rung-P2, rung-C6,
  rung-W14, rung-E32 and 125M (0 padded); the SiLU member and a table
  differing off row 128 are admitted everywhere; the toy's `new` still admits
  the toy census's constant-32767 table. Run FAILING before the fix
  (`s39-new-test-before.log`: at the rung, the constructor returned `Ok`).
* site 26 of the census is now **COVERED-BY-THE-STATEMENT-REFUSAL** at the
  four padded shapes, the refusal MEASURED on the production constructor
  inside the census; no row is a FINDING at any shape.
* the reproducer is un-ignored and renamed
  `s38_f1_reproducer_a_statement_with_a_nonzero_gate_zero_activation_is_refused_at_construction_at_rung_g`:
  it asserts the named refusal, and keeps the stage-38 end-to-end run as a
  control — forced past that one check, the honest proof is still rejected by
  the verifier (`H: pcs zk: group 8`), so the refusal guards a real failure.
  Before the fix, at the lane tip, the old form still failed exactly as at
  stage 38 (`s39-before.log`, exit 101).

**Since stage 40 (ruling CS-1, check finding C-1):** the refusal above was
keyed on the shape PASSED TO the constructor, which the statement does not
carry, so a half built at another shape sidestepped it. The same check (and
P-2's) is now re-run by name at the builder, the prover's and verifier's
entries and the run layer (§9); the reproducer's control asserts those
refusals instead of the verifier rejection it can no longer reach.

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

| the lane filter `--lib private_`, 6 test threads, the s35 differential skipped | `s38-gate-private5.log` | **437 / 0 / 19**; with that test run alone (`s38-s35-alone.log`, passes) **438 / 0 / 19** = stage 37's 429 / 0 / 18 + these nine + the reproducer. The skipped test fails whenever a concurrent proof bumps its process-global counter, with or without this stage's tests (note S38-N1 in the lane ledger) |

Source digests at this stage: `census_shaped_tests.rs` SHA-256
`04d4d1bb...ae873e56`; `private_block.rs` moves from `7a9b31ac...ee00dc82` to
`b6728273...652a3456` (the two `cfg(test)` lines only; full digests in the
lane ledger, stage 38).

**Stage 39 (the fix, `7472a3c`):** `s39-before.log` (the old reproducer at
`a9d6d4c`, exit 101, verifier rejection), `s39-new-test-before.log` (the new
test before the fix, exit 101), `s39-census-after.log` (after: 11 / 0 / 0).
`private_block.rs` moves `b6728273...652a3456` -> `29ba0084...f3acc872`
(the refusal only); full digests and the lane gate in the lane ledger,
stage 39.

## 9. Stage 40 — rulings CS-1, CS-2, CS-3 as built (2026-09-22 23:29 – 2026-09-23 00:1x PDT)

The disposition `ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md` (security owner,
2026-09-22 23:22) ruled on the adversarial check
`ZK60_SHAPED_REFUSAL_CENSUS_CHECK.md` (review branch, `cda7d05`). Built on
the lane at `6844ac6`. Test file `hashline/src/private_block/s40_tests.rs`
(12 tests: 10 for the rulings, the reproducers and note C-6; 2 measuring the
open notes S40-N2 and S40-N3 of the lane ledger). **Not a privacy result.**

**Failing first.** The check's two reproducers, copied as they stand and run
at the lane tip: both honest proofs REJECTED by the verifier, `H: pcs zk:
group 8` (`s40-before-reproducers.log`, exit 101). Rewritten to expect the
named refusals and run before any production line moved: 9 of 10 failed —
the builder, the prover and the verifier admitted the C-1 statement,
`Shape::new` admitted `wrho_s = 15` and `norm_wrho = 30`, the prover proved a
tampered lookup, and `f_e` 64, 65, 80 and 200 gave honest proofs the verifier
rejected (`s40-before-named.log`, exit 101). The tenth (the width
measurement) passed before and after.

**CS-1 — BUILT.** `FeedForwardPublic::check_words` (`private_block.rs`) is
the one check of a feed-forward statement against a shape: the padded
lengths, ruling P-2's entrywise support check on `gamma_m`, `Wg`, `Wu`, `Wd`,
the table length and S38-F1(a), in the constructor's order with its
messages. `new_shaped` calls it; `check_for_shape(&self, sh)` re-runs it on a
statement that exists and prefixes the refusal with `private block: ruling
CS-1 — the feed-forward statement does not fit the shape it is proved at`.
The shape is NOT stored in the statement (`absorb_into` and
`BlockPublic::digest` are byte-identical). Re-check sites, each before any
absorb, commitment or draw of what it guards:

| where | when |
|---|---|
| `witness::build_shaped` | after the two structural shape checks, before the input is read |
| `protocol::prove_inner_at` (single-block prover entry) | before the endpoint owners are opened, the randomness is seeded or the header absorbed |
| `protocol::prove_core` (shared body) | first line |
| `verify_bytes_at`, `verify_bytes` (bytes entries) | before the frame is decoded against the header |
| `protocol::verify_inner_at` (verifier entry) | before the receipt is looked at or the header absorbed |
| `protocol::verify_core` (shared body) | first line |
| `run::RunStatement::new` | after the block-count check, before any digest; refusal prefixed `private run: block k:` |
| `run::prove_run` | all `L` blocks, before the owners, the randomness and the header |
| `run::RunVerifier::start` (`verify_run`, `verify_run_from_dir`) | all `L` blocks, before the header |

MEASURED (`s40_cs1_...`): the C-1 statement is refused by that name at the
builder, the prover's entry, `prove_core` called directly (0 bytes drawn from
the generator, 0 squeezes, transcript state unmoved — `zkp-core`'s stage-36
observers), both verifier entries, `RunStatement::new`, the run prover (0
segments sunk) and the run verifier. P-2's sibling (a `Wg` entry at column
200, true at rung-P2 and padded at rung-K4 — the check named it and did not
build it) was ALSO verifier-rejected before (slot 18, the F zero-check) and
is refused with CS-1 + P-2's name at the builder, prover and verifier since.

**CS-2 — BUILT.** `Shape::new` refuses, by name, a `wrho_s` override below
`clog2(tokens) + f_e` (exactly `tokens 2^f_e > 2^wrho_s`), and a `norm_wrho`
override below `bits(isqrt(1 + width 32768^2) 2^12 - 1)` — the check's
formula with the input bound 32768. Overrides at or above are kept; no
registered shape passes an override. MEASURED: at rung-G's geometry 15 and
16 refused, 17 builds rung-G's windows, **18 kept and the C-2 input PROVES
there (accepted)**; over 48 admitted grid geometries the derivation is
admitted and one bit below refused at every one; `norm_wrho` 30 refused, 31
and 32 kept. **The norm case, and why it needed care:** the 32768-bound
window equals `Shape::new`'s own (32767-based) derivation at every width up
to 16,384 and at every registered shape (the widest is 768), but NOT beyond:
from width 16,385 on it is one bit short at 21 widths up to 2^20. There the
unoverridden derivation leaves the norm remainder reachable on inputs near
`-32768` — builder-refuses-first by name, not a failing proof (measured on a
30-bit window set past `Shape::new`: the full-scale input refused by the
builder as `norm quotient/remainder`, the dense input admitted). That is
outside this ruling (about overrides) and is recorded for the security owner
(ledger, stage 40, finding S40-N1). The softmax case is input-dependent
COMPLETENESS and is closed.

**CS-3 — BUILT.** The three silent bucket-0 paths (`byte_histogram_at`, the
exp loop and the activation loop of `prove_core`) are counted —
`u8_misses_of` over the looked columns, and a counter inside each of the two
loops — and `refuse_lookup_misses` refuses by name (`private block: ruling
CS-3 — the witness looks up a value that is not a row of its table ...` with
the three counts) right after the three histograms, from values
`prove_core` already holds, BEFORE the first draw of the block's `A` mask
rows and the `A` commitment. No absorb or draw is added or moved (the diff
adds no absorb, challenge, draw or commit line). MEASURED (`s40_cs3_...`):
one U8 word, one exp pair and one activation pair moved off their tables
each give that refusal with the independently counted misses; `prove_core`
called directly refuses with 0 bytes drawn, 0 squeezes, transcript unmoved,
while the honest witness through the same call draws, squeezes and absorbs.
**Where the first commitment sits:** for a single block, the `A` commitment
is the proof's first, so the refusal precedes every commitment of the proof
(the endpoint roots are the owner's, sealed before proving). **For a run**
the refusal of block `k` precedes block `k`'s `A` commitment but follows its
boundary commitment `B_k` and the earlier stages, whose segments have gone to
the sink; placing it before the RUN's first commitment would need every
block's witness before the header, which the just-in-time prover does not
hold (ruling M-3's memory) — there the caller's sealing pass (the builder,
`run.rs` rule 1) and rule M-9 (publish only after the whole run verifies)
stay the lines. **The soundness tests**: a tamper test hands the honest
prover a false witness to stand in for a CHEATING prover, which would not run
this check; a `#[cfg(test)]` thread-local switch (`protocol::CheatingProver`,
absent from a release build) turns it off inside the tamper harnesses
(`review_tests::outcome`, `rung_tests::assert_verifier_rejects`, `tamper.rs`,
`norm_alias.rs`, one run test), so every one of them still reaches the
verifier; 23 of them failed without it (`s40-gate-private-probe.log`). With
the switch on, each of the three single misses is rejected by the verifier.

**Notes.** C-3: the seven rows are labelled PREMISES CHECKED BY READING in §3
and in `census_shaped_tests.rs`. C-4: the group count moved to §5. C-5: §5's
zero-denominator row corrected. C-6: `layout.rs:671` now reads 98,598,912
(comment only); `width != q_heads * head_dim` admits NO failing honest proof
— dense proofs ACCEPTED at widths 72, 90, 100 and 120 on rung-G's head axis
(and 96), so no refusal; **an unbounded `f_e` DID** — before stage 40, `f_e`
64, 65, 80, 200 were admitted by `Shape::new`, the constructor (its `1i64 <<
f_e` wraps) and the builder, and every honest proof was rejected (slot 17);
`Shape::new` now refuses `f_e > 31`, the shaped reference kernel's own bound,
by name (`note C-6`); 4..=31 still prove (0 and 1 refused by the layout, as
before).

**Open, measured, not built (outside the rulings; lane ledger stage 40):**
S40-N1 — above width 16,384 `Shape::new`'s own norm derivation can be one bit
short of the 32768 bound (builder-refuses-first there, no registered shape
near); S40-N2 — the ATTENTION half's constructor checks are keyed on the
shape passed to them exactly as C-1 found for the feed-forward half: a dense
rung-G attention half in a rung-K4 block is admitted by the builder and its
honest proof is rejected by the verifier (slot 15, the Q zero-check);
S40-N3 — every window override `Shape::new` keeps proves or is refused by
name (no failing proof).

**Byte identity.** The toy 2,816,472 B, every shaped frame / receipt length
and schedule-digest pin, the slot-IR digests and the 125M counted receipts
are green in the lane filter (**452 / 0 / 18** at 6 threads = stage 39's 440
+ the 12 new tests, `s40-gate-private.log`); `absorb_into` and
`BlockPublic::digest` are untouched; the forbidden files' diff against
`27398d0` is empty.

## 10. Stage 41 — rulings CS-4 and CS-5 as built (2026-09-23 00:20 – 00:4x PDT)

The disposition's §5 ruled stage 40's two open notes: **CS-4** (S40-N2) —
ruling CS-1 extends to every part of a block or run statement; **CS-5**
(S40-N1) — `Shape::new` refuses a width above 16,384 by name. Built on the
lane at `d5dd00e`. Test file `hashline/src/private_block/s41_tests.rs` (11
tests: 5 reproducers, 4 named-refusal tests, 2 measured notes). **Not a
privacy result.**

**The parts, enumerated from the code.** Everything a block statement
(`BlockPublic`) or a run statement (`RunStatement`) is assembled from, and
whether it is keyed on a shape:

| part | what in it depends on a shape | the one check (called by the constructor) |
|---|---|---|
| attention half: `Wq`, `Wk`, `Wv`, `Wo` | padded lengths; P-2 support (`Dom::D`, the head-permuted `Dom::Q`) | `AttentionPublic::check_words` (new) |
| attention half: the first norm gain `gamma_a` | length `d_pad`; P-2 support on the width | the same |
| attention half: rotary tables `rope_cos`, `rope_sin` | length `tokens x head_dim/2`; position 0 the identity over `head_dim/2` | the same |
| attention half: exp table | length 256; `exp[0] = 2^f_e`, range `[0, 2^f_e]` | the same |
| feed-forward half: `gamma_m`, `Wg`, `Wu`, `Wd`, activation table | lengths, P-2, S38-F1(a) | `FeedForwardPublic::check_words` (CS-1, stage 40) |
| endpoint policy `ExpectedIo`: its `IoSpec` | padded plane `(t_pad, d_pad)`, endpoint construction, commitment parameters `(log_n, rate, rows, Q)`, hash tag — all DERIVED from a shape and none absorbed | `IoSpec::check_for_shape` (new) |
| endpoint policy: context, the two scales, the two roots | none (scales pinned to `(0, 0)`) | — |
| calibration identity | none (one constant) | — |
| run: interior boundary scales | none (pinned by ruling R-5) | — |
| run: `RunShape` (shape, `L`, run profile) | carries its own shape; the profile/shape pairing is note S41-N1 below | — |
| run: block digests | the blocks themselves, checked as above | via `BlockPublic::check_for_shape` |

**Failing first** (`s41-before-*.log`, run at `718ec01` + the test file,
before any production line moved). S40-N2 re-measured as stage 40 described
(`s41-before-n2.log`: the builder admits, `verifier rejected: slot 15 [04 Q
zero-check]`). The reproducers, all on the HONEST path (every prover refusal
on), 5 of 5 FAIL (`s41-before-reproducers.log`, exit 101):

| part | cross-shape case | before stage 41 |
|---|---|---|
| attention `Wq` (P-2) | dense rung-G attention in a rung-K4 block (S40-N2) | builder admits; **verifier rejects** the honest proof (slot 15) |
| attention `gamma_a` (P-2) | nonzero at width 96..99, built at width 100, in a rung-G block | builder admits; proof **ACCEPTED** (admitted, not failing) |
| attention rotary tables | 192-entry tables (rung-K4's head axis at 48 tokens; the first 96 are rung-K4's own) in a rung-K4 block | builder admits; proof **ACCEPTED** (the statement digests 192 entries the shape does not declare) |
| attention exp table | a `2^12` table at `f_e = 9`, and a `2^9` table at `f_e = 12` | the builder refuses, but only as `softmax denominator` on both inputs tried (dense, all-zero) — a witness refusal, not a statement one; by the builder's own bound (`2^f_e <= total <= tokens 2^f_e`, read from `witness.rs`, not measured) the `2^12`-in-9 direction admits any input whose every row denominator stays within `24 x 2^9`, so whether it is refused depends on the input; the `2^9`-in-12 direction fails row 0 for every input |
| endpoint policy | a rung-G spec (the same plane, construction and parameters as rung-K4; another profile's hash tag) committing a rung-K4 witness's planes, in a rung-K4 proof | prover admits; **verifier rejects** the honest proof (`endpoint 0: pcs zk: Merkle path for column 151 fails`) |

The named tests, 4 of 4 FAIL (`s41-before-named.log`): the builder admitted
the S40-N2 block (`left: None`) and the `gamma_a` block; the prover admitted
the rung-G policy; `Shape::new` ADMITTED widths 16,385, 20,000, 32,768 and
65,536 (derived norm windows 34, 35, 35, 35; the 32768 bound needs 35 at
16,385).

**CS-4 — BUILT.** `AttentionPublic::check_words(sh, wq, wk, wv, wo,
gamma_a, rope_cos, rope_sin, exp)` is the constructor's whole rule set in
its own order and with its own messages; `new_shaped` calls it;
`AttentionPublic::check_for_shape(&self, sh)` re-runs it prefixed `private
block: ruling CS-4 — the attention statement does not fit the shape it is
proved at`. `IoSpec::check_for_shape(&self, sh)` compares the four derived
fields with the shape's, naming the first that differs, prefixed `private
block: ruling CS-4 — the endpoint policy does not fit the shape it is proved
at`; `IoSpec::new_shaped` calls it. `BlockPublic::check_for_shape` runs the
attention half's check then the feed-forward half's (block order). Neither
statement stores a shape; `absorb_into`, `BlockPublic::digest` and
`ExpectedIo::to_bytes` are untouched. Re-check sites — stage 40's, each
before any absorb, commitment or draw of what it guards:

| where | block statement | endpoint policy |
|---|---|---|
| `witness::build_shaped` | attention, then feed-forward | (takes none) |
| `protocol::prove_inner_at` | yes | yes, before the owners are opened |
| `protocol::prove_core` (first line) | yes | (takes none) |
| `verify_bytes_at`, the toy's `verify_bytes` | yes | yes, before the frame is decoded |
| `protocol::verify_inner_at` | yes | yes, before the receipt is looked at |
| `protocol::verify_core` (first line) | yes | (takes none) |
| `run::RunStatement::new` | every block, `private run: block k:` | yes, `private run:` |
| `run::prove_run`, `run::RunVerifier::start` | every block | yes (the statement's `rs` is a visible field, so it is not trusted from construction) |

MEASURED after (`s41-after-focused.log`, 47 / 0 / 1): the S40-N2 block is
refused by CS-4's name at the builder, the prover's entry, `prove_core`
called directly (0 bytes drawn, 0 squeezes, transcript unmoved), both
verifier entries, `verify_core` called directly after a real header (0
squeezes, transcript unmoved; the honest block through the same call
squeezes and absorbs), `RunStatement::new`, the run prover (0 segments
sunk) and the run verifier. The `gamma_a`, rotary and both exp cases are
refused by CS-4 + the constructor's own name at the builder, the prover's
entry and the verifier's entry, and every reproducer now ends in a CS-4
refusal before a receipt exists — the exp table by ONE name on every input.
The rung-G policy is refused at the prover's entry, both verifier entries
(an honest rung-K4 receipt with a policy of the same two roots declared for
rung-G — byte-identical absorbed policy), the toy's bytes entry (`its padded
endpoint plane is (32, 128), this shape's is (32, 16)`), `RunStatement::new`,
the run prover (0 sunk) and the run verifier (before a segment is read).
Across the registered shapes (the test skips any whose spec does not
construct), each shape's own spec fits its own shape and no other.

**CS-5 — BUILT.** `Shape::new` refuses `width > 16384` (`WIDTH_MAX`) by name,
before the norm window is derived: `private block shape: ruling CS-5 — width
<w> is above 16384; ...`. MEASURED: width 16,384 admitted at two head
geometries (128 of 128, 256 of 64; norm window 34, which is what the 32768
bound needs there), 16,385 / 20,000 / 32,768 / 65,536 refused by that name;
every registered shape (widest 768) unchanged. With it, every admitted width
has a norm window that holds every int16 input (`s40_tests` checks widths
1..=16,384 one by one), so S40-N1 has no admitted instance.

**Test edits the rulings moved.** `s40_tests.rs`: the S40-N2 measurement
test asserted the verifier rejection and now asserts the builder's CS-4
refusal (renamed `..._is_refused_by_ruling_cs4_before_a_receipt_exists`).
`hash_tag_tests.rs`: the stage-17 cross-rule test handed a verifier of one
hash rule the policy made under the other; the policy check would now stop it
by name before any hashing, so each verifier is handed its OWN rule's policy
over the same two roots (identical absorbed bytes) and the test asserts the
refusal is not CS-4's (it is still `slot 0 ... sumcheck round 1` in both
directions), plus the other-rule policy refused by CS-4's name.

**Two notes MEASURED, not built (outside CS-4 as ruled; lane ledger stage
41).** **S41-N1** — `RunShape::new` pairs any run profile with any shape: a
one-block run under rung-G's REGISTERED run profile over the rung-K4 shape is
admitted and verifies (the pairing travels in one struct, so no honest proof
fails; a D17 naming question). **S41-N2** — the run prover and verifier
check the blocks they are HANDED, not the digests the run statement holds: a
statement over block X, proved with block Y, is ACCEPTED by the run verifier
handed Y (the transcript absorbs X's digest; every slot is checked against
Y) and rejected handed X. Nothing on the in-memory path compares
`blocks[k].digest()` with the statement's `block_digests[k]`; the
run-statement file reader does.

**Byte identity.** The lane filter `--lib private_` at 6 threads: **463 / 0
/ 18** (stage 40's 452 + the 11 new tests), `s41-gate-private.log`, 131.18 s,
peak RSS 4.39 GB, the same 16 warning lines. The toy 2,816,472 B, every
shaped frame / receipt length and schedule-digest pin, the slot-IR digests,
the 125M counted receipts and the R-5 run-header literal pin are green; the
diff adds no absorb, challenge, draw or commit line (only comments and
refusal strings match); the forbidden files' diff against `c735d77` is
empty.
