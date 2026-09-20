# The lane's shaped private block at the development rung: an independent adversarial code review

**Status: INDEPENDENT ADVERSARIAL CODE REVIEW — delegated Opus agent,
2026-09-20. Soundness of the lane's change at the development rung; not a
privacy review.**

Worktree `/home/victor/wt-zk60-block125m-review`, branch
`zk60-private-block-125m-review`, taken from the tip of
`zk60-private-block-125m` (`3f762d0`). Base for every diff: `73d3398`.
Everything else on the machine was read-only. The reviewer's own tests are in
`hashline/src/private_block/review_tests.rs` (one `#[cfg(test)] mod` line in
`private_block.rs`); the logs are in `results/zk60_block125m_review/`. Nothing
in the lane's code was changed and nothing was fixed.

Every case below was decided END TO END: a witness is edited, the honest
prover is run on it, the frame is encoded, and a fresh `verify_bytes_at` call
is given the bytes. "Rejected" always means the VERIFIER rejected; a refusal
by the prover's own consistency checks is recorded separately and counted as
a failure of the test, because a cheating prover does not run them.

## 0. Verdict

**No hole. I could not make the verifier accept a false statement at the
development rung, in any of the nine attacks I ran.** The pad rule of ruling
P-1 is real and it is complete over the planes the memo declares: a nonzero
value written into a padded position of any one of the 79 editable ZERO-rule
`A` planes, at 145 padded positions across all nine padded domains, is
rejected by the verifier every time (151 cases); so is a perturbation of any
one of the 80 committed `A` planes on its true support. **The most important single
result is that four toy receipts produced BEFORE this lane still verify,
byte for byte as they stand, under the lane's verifier** — which is a much
stronger statement about the frozen toy than the lane's own length-and-digest
freeze gate can make. What I did find is nine items of the
weakness-and-coverage kind, four of which are about tests that cannot fail
rather than code that is wrong; the two that matter most are a guard that the
release profile compiles out (F-1) and a rung fixture on which every
head-permuting tamper is a no-op (F-3).

## 1. The pad-zero term

**(a) Coverage — is every ZERO-rule plane really in some slot's sum?**
Exhaustively, at the rung: `review_tests::every_zero_rule_plane_has_its_pad_
proved_zero_at_the_rung` enumerates `pad::zero_rule_a_planes` for every domain
of `ALL_DOMS`, writes `1` into one to three padded positions and requires the
verifier to reject. **79 of the 82 ZERO-rule `A` planes, 151 cases over all
nine padded domains, 0 accepted, 0 caught by the prover only.** The three not
covered are the lookup histograms `A_MU8` / `A_MEXP` / `A_MACT`, which the
PROVER derives (`protocol.rs:418-441`) and which a witness edit cannot express
at all — see F-4.

The catching slot is printed for every case:

| slot | | cases |
|---|---|---:|
| 14 | `SC_DZC` | 71 |
| 17 | `SC_SZC` | 29 |
| 18 | `SC_FZC` | 21 |
| 16 | `SC_KVZC` | 12 |
| 15 | `SC_QZC` | 8 |
| 2 | `SC_TZC` | 5 |
| 3 | `SC_LZC` | 4 |

Six of the seven pad-zero host slots therefore fire; `SC_TAB` (slot 22) is
the one that does not, and cannot from a witness edit (F-4). `Dom::T`'s five
cases land at slot 2, which is its own host; `Dom::L`'s four land at slot 3
only in the two UNUSED limb sub-planes, because inside a used sub-slice
`SC_TZC`'s ungated limb reconstruction gets there first (F-7).

Structurally, a plane the term forgot could not hide: each host slot resolves
its planes through `B::tab` (`argument.rs:492`), which returns `usize::MAX`
for a plane outside the slot's `a_range`, and `PadTerm::eval` would index
`v[usize::MAX]` — a panic in both the prover and the verifier, not a silent
omission. `SC_TZC` (`:902-911`) and `SC_SZC` (`:1288`) additionally refuse by
name if their domain's declared plane list is not the one they push;
`SC_TAB` does not (F-2).

**(b) When are the challenges drawn, and in what field?** `zeta` is
`nonzero(tr.challenge_fp2_vec(1))?[0]` and `mu_pad` is one more entry of the
slot's existing `mu` vector (`argument.rs:870, 936, 1063, 1096, 1138, 1160,
1191, 1223, 1249, 1287, 1324, 1349`) — both `Fp2`, the quadratic extension,
both drawn inside `define` during the slot loop, which runs after
`absorb_root(b"A", ...)` (`protocol.rs:450`), `absorb(b"M", ...)` (`:456`),
the LogUp triple, and `absorb_root(b"H", ...)` (`:528`). So both are drawn
after every commitment they test is absorbed. `zeta` is refused on zero by
the pre-existing witness-independent `nonzero` helper, whose string
("zero batching challenge; discard attempt") names no relation and no plane.

**(c) Is the term inside a zero-check at every padded position?** Yes, in all
seven host slots: the term is added inside the `eq(tau) * (..)` bracket, never
to a bare sum — `argument.rs:922-923` (`SC_TZC`), `:950` (`SC_LZC`), `:1120`
and `:1126` (`SC_DZC`), `:1172` and `:1179` (`SC_FZC`), `:1231` and `:1240`
(`SC_QZC`/`SC_KVZC`), `:1308` and `:1314` (`SC_SZC`), `:1357` (`SC_TAB`).
`tau` is a fresh challenge vector of the domain's own log, drawn in that slot,
so the check is at a random point of the whole cube and cannot cancel across
positions. Within one slot the `zeta` powers continue ACROSS the groups
(`PadTerm::add`, `:633`), so no two planes share a power — the memo asks for
one `zeta` per padded domain and the code uses one per host slot, which is
the same statement and one challenge cheaper.

**(d) Who evaluates `(1 − supp)`, and do the closed forms equal the tables?**
`B::supp` pushes a `Tab::Pub` vector built by `pad::indicator_table`, a
function of the `Shape` alone; the verifier evaluates it itself with
`eval_mle_ext` over the whole cube (`argument.rs:360`). Nothing from the
receipt enters it. `pad::tests::the_closed_forms_equal_the_tables` is
exhaustive and I checked that it is: line 542 asserts
`indicator_table == support_indicator` for **all nine domains at all three
shapes**, not only for the eight that have a product form, so the ninth
(`Dom::L`, which has none and falls back to the builder's table) is covered
by the same assertion. `support_indicator` is in turn tied to `Geom::support`
— the builder's own support — and its weight is checked against
`Shape::true_size` for every domain, and against an independently written
memo oracle for `Dom::Q`, `Dom::S`, `Dom::Ht`.

**(e) More cases than PZ-1 and PZ-2.** Delivered as the sweep above: a padded
head slot at a true token (`Dom::Q`, `Dom::S`, `Dom::Ht` — the position a
prefix-mask indicator would call supported, correction C-1), a padded token
row (`Dom::D`, `Dom::F`, `Dom::Ht`), a padded key index `j` of a true row
(`Dom::S`), a padded width column (`Dom::D`), a padded hidden column
(`Dom::F`), the key-value planes (`Dom::Kv`, two positions), an unused limb
sub-plane and the last position of the lifted domain (`Dom::L`).

The EXEMPT plane gets its own two tests. `the_exempt_planes_pad_is_still_
pinned_to_its_table_row_at_the_rung` writes into `A_E`'s pad (i) a value that
is no table row and (ii) a value that IS a genuine `exp` row but the wrong one
for that position's `delta`; both are rejected (`H: pcs zk: group 8`), because
`delta` is pinned by `A_MX` and `A_S8`, which are both ZERO-rule. So the
exemption buys a cheating prover nothing. One correction to the memo's
reasoning, found here: at a TRUE row every padded `j` is above `t`, where this
rung's exp table has already decayed to **zero**, so a zero there is a genuine
table row; the position where the exemption actually bites is a padded HEAD
SLOT, where the causal mask is 1 and `A_E` carries `exp[0] = 4096`.
`the_exempt_pads_entries_are_outside_the_softmax_row_sum_at_the_rung` shows
the consequence: a padded head slot's causal triangle sums to 16,384 while its
`A_SUM` is 0, so `SC_RS`'s summand MUST carry `supp_S` or no honest proof
exists (correction M-3) — and on a true row it is the causal mask, not
`supp_S`, that excludes the pad of the `j` axis.

## 2. Relations that sum over a padded index

- **The seven matmuls.** `pad::tests::a_weight_nonzero_off_its_support_is_
  refused_at_construction` already covers ruling P-2's construction refusal in
  both directions (padded width index, padded head slot) and for a `Wo` in
  true-head column order, and `the_folded_weight_vectors_vanish_off_support`
  ties it to the memo's folded-vector wording. Both constructors
  (`AttentionPublic::new_shaped`, `FeedForwardPublic::new_shaped`) carry it, so
  the prover's and the verifier's statements are refused alike — the verifier
  builds its own `BlockPublic`. I found nothing to add.
- **The two sums of squares.** Gated by `supp_D` (`argument.rs:854, 863`), with
  `SC_TZC`'s matching host terms gated by `supp_T` (`:899, 924-925`) — finding
  S9-F8, which the lane found itself and which is correct: without it a padded
  token row's claimed sum is 0 against a host term of `−NORM_CEPS`.
- **The softmax row sums.** `SC_RS`'s summand takes `supp_S` (`:964`),
  `SC_SZC`'s `host_rs` takes the LIFTED `supp_Ht` (`:1283, 1314`) and
  `per_row` stays the full `t_pad`. I checked the arithmetic of the hosted
  claim by hand and it closes: the lifted indicator is constant in `j`, so the
  host term sums to `t_pad · (A_SUM + lam)` per `(h, t)`, against the hosted
  coefficient `nu[0]·per_row` — consistent.
- **The LogUp sums and multiplicities.** The LogUp arm is never gated
  (`helper_sum`, `SC_SZC`'s `cx`, `SC_FZC`'s `f_act`), which is right, and is
  the reason for finding S12-F3. A prover cannot shift multiplicity onto a
  padded TABLE position because `Dom::Tab`'s three histograms AND three table
  helpers are proved zero above index 255 — but that term is exercised by no
  test (F-4).
- **The residual adds** are ordinary `Dom::D` constraints, gated, with both
  operands proved zero on the pad.
- **The endpoints.** `SC_IO_IN` / `SC_IO_OUT` are `eq(tau)·(A_X − endpoint)`
  over the FULL padded `(32, 128)` `Dom::D` cube, so the endpoint equals `A_X`
  at every one of the 4,096 positions, pad included; `A_X` and `A_X2` are
  ZERO-rule planes of `Dom::D`, so the endpoint's pad is zero too —
  transitively, not by a rule of its own. Tested:
  `an_endpoint_with_a_nonzero_pad_is_rejected_at_the_rung` hands
  `prepare_endpoints` a plane that differs from the witness's only at a padded
  column and the verifier rejects at slot 21. A verifier who later opens the
  endpoint therefore sees the true plane and zeros. Note that this makes memo
  §3.7a open question 4 ("a future padded endpoint") LIVE already at the rung,
  not future: the seam commits the padded cube (F-9).

## 3. Grouped-query attention

Two halves.

**Structural.** `the_key_value_group_is_the_high_bits_of_the_head_slot_at_
every_shape` re-derives, at the toy, the rung and 125M, that the top
`log2(kv_heads)` bits of the `log2(h_pad)`-bit head slot ARE
`Shape::kv_of_slot` and ARE `h / (q_heads / kv_heads)`, which is what
`argument.rs:1008` (`ck.extend(fixed(&r_h[..lkv]))`) and `:1022` select. The
key-value coordinate is a FIXED function of the query head's own challenge, so
a prover cannot choose it — trap T-3 is closed in the code.

**Witness.** The lane has no tamper test here, and on its fixture it could not
have one (F-3). I built a rung statement whose two key-value heads are not
interchangeable (`distinct_kv_case`: `Wk` and `Wv` weight the second group's
rows differently), proved it honestly, then exchanged the two groups' slices
in every `Dom::Kv` plane — 2,213 positions differ — so that every relation
inside `SC_KVZC` still holds (it is per position and its RoPE table does not
depend on the head). **Rejected by the verifier at slot 15.**

## 4. The two integer windows and the norm alias

`a_remainder_above_its_window_is_rejected_at_the_rung` sets the top limb of
each of the six remainders (`norm_a` ρ and σ, `norm_m` ρ and σ, `sigma_s` ρ
and σ) to the first value OUTSIDE its window but INSIDE the byte class, so the
plain `byte` lookup cannot be what catches it and only the
`scaled(top, 1 << (8·limbs − wrho))` lookup can. All six rejected — four at
slot 14, two at slot 17. The rung's windows are `NORM_WRHO = 31` on four limbs
and `WRHO_S = 17` on three, asserted in the test. The half-`p` isqrt alias of
ruling P-5 is already covered end to end by
`rung_tests::the_norm_range_alias_is_rejected_end_to_end_at_the_rung`, which I
re-ran green; I had nothing sharper to add to it.

## 5. Shape confusion

The verifier takes its shape from its CALLER and the frame chooses nothing:
`wire::decode` checks `bytes.len() != encoded_len(lay)` first and every count
it reads comes from `lay`. Everything a shape is, is absorbed before the first
challenge — the profile string opens the transcript
(`Transcript::new(sh.profile)`), then `expected-IO`, then the
`public-statement` digest over every weight and table, then a `parameters`
line carrying `T/d/f/H/KV/dh/log_cols/inv_rate/Q`, then the calibration
identity, then the schedule digest, which carries the profile tag again and
also `wrho`, `fE`, `wrhoS`, the whole slot table and both site arrays. So the
two integer windows and the exp calibration, which the parameter line omits,
are bound by the schedule digest.

`a_receipt_does_not_verify_under_another_shape_at_the_rung` shows three cases:
a rung frame read by a verifier at 5 query heads over 1 key-value head with
the SAME profile id and every padded size identical (refused at the codec,
`"private block wire: expected statement mismatch"` — the 32-byte frame
binding separates them before the transcript is opened); the rung frame under
the frozen toy verifier; and the toy frame under the rung verifier. All three
refused.

## 6. Is the toy really untouched?

**Yes, and not by the lane's own gate.** The freeze gate pins the receipt
LENGTH, a literal schedule digest and header lines; none of those would move
if a claim point, a challenge order, a constraint coefficient or the codec's
field order changed. `a_toy_receipt_made_before_the_lane_still_verifies` takes
four toy receipts that are IN THE REPOSITORY and were produced by builds from
before this lane touched a shared constant —

| archive | produced at |
|---|---|
| `results/zk60_rowfold_20260919/integration/native-block-0` | `4bf1fa0`, before the lane's first shared-file commit `bce1d7c` (S1) |
| `results/zk60_rowfold_20260919/integration/native-block-1` | the same |
| `results/zk60_private_block_evidence/owner_run1` | before the review base `73d3398` |
| `results/zk60_attention_integration_20260919/block_public` | before the review base `73d3398` |

— reads each `block_receipt.bin` (2,816,472 B) with its `block_expected.bin`,
rebuilds the public statement itself from `BlockPublic::synthetic_fixture()`,
and calls today's `verify_bytes`. **All four verify, `Ok(())`**, and a
one-bit change to each is still refused. The toy verifier is bit-compatible
with what it was before the lane.

## 7. `audit_claims`

**Not relaxed.** Diffed against `73d3398`: the body is character-for-character
the same except that `part_rows(part)` became `part_rows(part, n)` and the
function took an `n` parameter — the S12-F2 fix, which is what makes the check
apply at the COMMITMENT's row width instead of the module's `N` literal. Every
refusal, every condition and the final `uses[*r] != 1` sweep are unchanged.
`the_mask_schedule_audit_still_refuses_every_case_at_the_rungs_row_width`
re-runs the six refusals at both `n = 256` (the endpoints') and `n = 1024`
(the rung's); all six fire at both, so the parameterisation did not make them
vacuous at the new width.

The claims the lane ADDED: the pad-zero terms add **none** — I verified this
rather than taking it: the term reads only table indices already pushed by the
slot's `a_range` / `a_slice`, and the indicator is a `Tab::Pub`, which is not a
claim site; `B::finish` still checks `ak == lay.a_sites()[slot]`. The third
limb's planes enter through `Ids::sr` / `sg` and are ordinary `a_range`
members. The endpoints keep their bespoke `check_endpoint_opening` (they do
not satisfy `audit_claims`' `prox + 2 == rows`, as at the toy), now driven by
`endpoint_geometry(sh)` and `sh.endpoint_log_n`; I checked its three part-row
ranges against `B::endpoint`'s `mask_row = endpoint_rows − 5` and they agree
at the rung's 21 rows.

## 8. Refusal strings and verifier-reachable panics

`argument.rs` contains **no** `panic!`, `unwrap`, `expect` or `assert!`
outside test code — only two `debug_assert`s (F-1). `wire.rs` contains none.
`shape.rs` has `assert!(v > 0)` in `clog2`, one `unreachable!()` in the matmul
inner-width map and `.unwrap()` on the max of a fixed-size array; all three are
shape-driven and unreachable from a frame. `layout.rs`'s asserts are the toy
freeze gate in `Layout::new`, also shape-driven.

Nothing a malformed RECEIPT can reach: `a_corrupted_rung_frame_is_refused_and_
never_panics` flips one bit at 56 positions spread over the header, the three
roots, the slot block, the mask opening and all four PCS openings, and adds a
one-byte-short and a one-byte-long frame; all 58 return `Err`, none panics,
none verifies. The one verifier-side index I could find that is not bounded by
`wire::validate` is a public table whose length is not the slot's cube —
unreachable from a frame, shape-driven only (F-6).

New refusal strings introduced by the lane, checked for witness dependence:
`"zero batching challenge; discard attempt"` (challenge only),
`"private block: a public weight is nonzero at a padded width index"` /
`"... at a padded head slot"` (public statement only),
`"private block: Dom::T plane {q} is outside SC_TZC's pad-zero group"`,
`"... a Dom::Ht plane is outside SC_SZC's pad-zero group"`,
`"... a Dom::Tab helper is outside SC_TAB's pad-zero group"`,
`"private block shape: ..."` (nine, shape only),
`"private block: this shape's evaluation domain ... exceeds the module's NTT
tables"`. **None is witness-dependent.** The witness builder's own refusals
are input-dependent, as the module header already records; the lane added no
new one that I could find.

## 9. The class of bug an honest proof would not have caught

All three of the lane's end-of-stage bugs (S12-F1, S12-F2, S12-F3) were found
by a FAILING honest proof. The class that would NOT fail one is an
unconstrained plane, or a relation evaluated on a plane id that happens to be
right for honest data. I hunted it directly:
`every_committed_plane_is_constrained_on_its_true_support_at_the_rung`
perturbs each of the **80** committed `A` planes by one at a true-support
position and requires rejection. **80 of 80 rejected by the verifier, 0
accepted, 0 caught by the prover only.** This is the lane's 27-case family
battery made exhaustive, so a plane that no relation reads cannot hide behind
a family that has a representative.

On the brief's "23 slots" framing: the six ZERO-CHECK slots are the only ones
that ever appear as the catcher — 14 `SC_DZC` (35 planes), 17 `SC_SZC` (14),
18 `SC_FZC` (10), 15 `SC_QZC` (8), 2 `SC_TZC` (8), 16 `SC_KVZC` (5). That is
the design, not a gap: the matmul, row-sum and score/PV slots publish a CLAIM
that its host zero-check re-derives, so a violated claim surfaces at the host.
The endpoint slot 21 appears as the catcher in the endpoint case of §2. What
this sweep does establish is the thing the brief asked for: **no committed
plane at the rung is unconstrained.**

Two things the lane's own battery does that mine does not, and vice versa: the
lane's tampers are the named semantic families and are worth keeping; mine are
exhaustive but single-position. Neither reaches the moved-multiplicity family
(F-4).

## 10. Findings

`HOLE` = a false statement is accepted. `WEAKNESS` = a defence that is thinner
than it reads, or a test that cannot fail. `NOTE` = a documentation or
robustness point.

| # | sev | what | where | shown by | what must change |
|---|---|---|---|---|---|
| **F-1** | WEAKNESS | The guard that an indicator TILES its host slot's cube is a `debug_assert_eq!`, and the release profile sets no `debug-assertions` — release is the only profile the rung and the 125M shape are built in. If a future slot hosted an indicator that does not tile, release would build the public factor as `t[x / rep]` with a truncated `rep`: the prover and the verifier would agree on a WRONG `(1 − supp)` and the proof would verify while meaning something else. (`t.len() > cube_len` gives `rep = 0` and a divide-by-zero panic instead.) It holds today at all three shapes. | `hashline/src/private_block/argument.rs:533`; `hashline/Cargo.toml:49` | `review_tests::the_pad_terms_unstated_invariants_hold_at_every_shape` (passing — it checks for real what release does not) | make `B::supp` return `Result` and refuse by name (`"private block: an indicator that does not tile its slot's cube"`); every caller is already in a `Result` context |
| **F-2** | WEAKNESS | `SC_TAB` batches its three `Dom::Tab` `A` planes by hard-coded table indices `[1, 4, 7]` and never checks them against `pad::zero_rule_a_planes(Dom::Tab)`, although it DOES check the helper list against `zero_rule_h_planes` on the line above, and although `SC_TZC` and `SC_SZC` both check theirs. A fourth `Dom::Tab` `A` plane would be silently outside the pad-zero term — the exact class of hole ruling P-1 exists to close. | `argument.rs:1344-1351` (check at `:1346`, unchecked list at `:1350`) | `review_tests::the_pad_terms_unstated_invariants_hold_at_every_shape` | add the same `!=` refusal for the `A` list that `:1346` does for the helpers |
| **F-3** | WEAKNESS | `grow_tests::tame_case`, the ONLY fixture the rung is proved at, gives every head identical data: its input alternates with period two in the width index and `head_dim` is even, and `Wk`/`Wv` are one diagonal for both key-value groups. So at the rung **every head-permuting tamper is a no-op on the witness**, and memo §9a's two S7 acceptance tests ("a tamper that swaps two key-value heads is rejected"; "a tamper that makes one query head read the wrong key-value group is rejected") are ABSENT from the lane and could not have been written on this fixture. The head permutation of the QUERY slots is likewise untested by any tamper. | `hashline/src/private_block/grow_tests.rs:566-590` | `review_tests::the_tame_rung_fixture_cannot_tell_the_two_key_value_heads_apart` (passing, pins the limitation) and `review_tests::a_query_head_reading_the_other_key_value_head_is_rejected_at_the_rung` (passing, on a fixture that CAN) | adopt `review_tests::distinct_kv_case` (or break the period-two input) as the rung fixture, and add the query-slot permutation tamper |
| **F-4** | WEAKNESS | Two of the nine pad-zero terms had no end-to-end test before this review. `Dom::Tab`'s term in `SC_TAB` still has none and cannot have one from a witness edit: its six planes (three histograms, three table helpers) are DERIVED by the prover, so that arm needs a prover-side hook — the same gap the ledger already records for the moved-multiplicity tamper family. It is the term the P-3 lift's safety rests on. | `argument.rs:1343-1352`; `protocol.rs:418-441` | not testable as a witness edit; recorded, not fixed | a prover-side injection point (a `#[cfg(test)]` hook on the three histogram buffers) would close both this and the moved-multiplicity family at once |
| **F-5** | WEAKNESS | The lane's rung PZ-1 tests one of the memo's three named cases (`A_RAL` on `Dom::D`, slot 14). The other two (`A_SR0` at a padded head slot, `A_LIMB` in an unused limb sub-plane — the only case in which `Dom::L`'s own term in `SC_LZC` can be the catcher) were not there. | `hashline/src/private_block/rung_tests.rs:118-126` | `review_tests::every_zero_rule_plane_has_its_pad_proved_zero_at_the_rung` covers all three and 148 more | keep the sweep, or add the memo's two missing cases by name |
| **F-6** | NOTE | The verifier has no named refusal for a public table whose length is not the slot's cube: the length check lives inside the `Side::Prove` arm only, so on the verify path a mis-sized `Tab::Pub` reaches `eval_mle_ext`'s `assert_eq!` — a panic, not a refusal. Unreachable from a frame (public tables are shape-driven), so this is the same class as the `argument.rs:626` panic the disposition already recorded, not a denial of service. | `argument.rs:308` (prover only); `zkp-core/src/mle.rs:73` | read, not tested | move the table-length check out of the `Prove` arm |
| **F-7** | NOTE | At any shape with `tokens < t_pad`, `SC_TZC`'s limb reconstruction READS padded positions of `Dom::L` — the nine sub-slices `[k·t_pad, k·t_pad + t_pad)` include the padded token indices — and reads them UNGATED. Memo §3.7a's `Dom::L` row says "nothing reads the pad", and `pad.rs`'s toy documentation test says so correctly for the toy (where `tokens == t_pad`); neither is true at the rung. It is SOUND (the `Dom::T` term forces `d = dsq = 0` there, and `d − dl = 0` with `2d − a1 − a2 = 0` plus the byte lookups then force the limbs to zero), but it means the `Dom::L` pad-zero term is not what catches a tamper inside a used sub-slice — slot 2 gets there first. | `argument.rs:882-890`; memo §3.7a, `Dom::L` row | the sweep's `Dom::L` cases: inside a used sub-slice → slot 2; in an unused sub-plane → `SC_LZC` | correct the memo's `Dom::L` row for shapes where the token axis pads |
| **F-8** | NOTE | `rung_tests::assert_rejected` counts a refusal by the PROVER as a pass. A prover refusal is not a soundness statement. Nothing is hidden today — every one of the lane's 27 rung tamper cases is verifier-rejected, and my 231 are too — but the helper would hide a regression. | `rung_tests.rs:282-291` | the review's 231 sweep cases separate the two and fail on prover-only | assert the verifier path, or record the split in the test's own assertion |
| **F-9** | NOTE | Memo §3.7a open question 4 ("a future padded endpoint … the seam then has to say which positions it binds") is LIVE at the rung, not future: the frozen seam already commits the PADDED `(32, 128)` cube. The answer is that `SC_IO_IN`/`SC_IO_OUT` bind the whole padded cube to `A_X`/`A_X2`, whose pads are ZERO-rule, so the endpoint's pad is zero transitively. Worth writing into the memo before S11b generalises the endpoint, because a generalised endpoint that binds only the true plane would LOSE this. | `argument.rs:510-513, 1372-1379`; memo §3.7a open question 4 | `review_tests::an_endpoint_with_a_nonzero_pad_is_rejected_at_the_rung` | state it in §3.7a and carry it as a condition on S11b |

## 11. What I could not check

- **Privacy.** Out of scope by the brief, and nothing here is a privacy
  statement. No capture, rank, CFS or disclosure tool was run; finding C-F5
  (no shape-parameterised capture writer) still blocks that.
- **The 125M shape.** Nothing was run at it — the module refuses it by name
  for lack of NTT tables, and S11b (the generalised endpoint) is owed. Every
  end-to-end result here is the rung's.
- **The moved-multiplicity family at the rung** (F-4), for want of a
  prover-side hook.
- **A cheating prover that is not the honest prover.** Every attack here edits
  a witness and then runs the HONEST prover. Attacks that require the prover to
  deviate from its own algorithm — a hand-built receipt, a chosen mask row, a
  second opening — are outside what a witness edit can express; the module's
  own structural checks (`audit_claims`, `check_opening`, `wire::validate`) are
  what stand there, and I checked they are unchanged rather than re-derived
  them.
- **The soundness ARITHMETIC** (the Schwartz–Zippel accounting of §3.7a's
  `2^-122.1`, the per-opening figures) was read, not re-derived.
- **`zkp-core`** beyond `eval_mle_ext` and the two fold helpers: the PCS, the
  sumcheck and the CFS mask are pre-existing and were not reviewed.

## 12. Tests added

All in `hashline/src/private_block/review_tests.rs`, registered by one
`#[cfg(test)] mod review_tests;` line in `private_block.rs`. **14 tests, 14
passing, 0 ignored-failing** — no test demonstrates a hole, because I found
none. Runtime about 2.5 minutes in release, `--test-threads=1`, no GPU,
nothing at the 125M shape.

| test | what it decides |
|---|---|
| `every_zero_rule_plane_has_its_pad_proved_zero_at_the_rung` | attack 1(a)(e), 151 cases, nine domains |
| `the_pad_terms_unstated_invariants_hold_at_every_shape` | F-1 and F-2, at all three shapes |
| `the_exempt_planes_pad_is_still_pinned_to_its_table_row_at_the_rung` | attack 1(e), the exempt plane, two junk kinds |
| `the_exempt_pads_entries_are_outside_the_softmax_row_sum_at_the_rung` | attack 1(e), the exclusion, correction M-3 |
| `every_committed_plane_is_constrained_on_its_true_support_at_the_rung` | attack 9, 80 planes |
| `the_key_value_group_is_the_high_bits_of_the_head_slot_at_every_shape` | attack 3, structural, trap T-3 |
| `the_tame_rung_fixture_cannot_tell_the_two_key_value_heads_apart` | F-3, pins the limitation |
| `a_query_head_reading_the_other_key_value_head_is_rejected_at_the_rung` | attack 3, witness, on a fixture that can tell them apart |
| `a_remainder_above_its_window_is_rejected_at_the_rung` | attack 4, six remainders |
| `a_receipt_does_not_verify_under_another_shape_at_the_rung` | attack 5, three cases |
| `a_toy_receipt_made_before_the_lane_still_verifies` | attack 6, four archived receipts |
| `a_corrupted_rung_frame_is_refused_and_never_panics` | attack 8, 58 malformed frames |
| `an_endpoint_with_a_nonzero_pad_is_rejected_at_the_rung` | attack 2, the endpoints |
| `the_mask_schedule_audit_still_refuses_every_case_at_the_rungs_row_width` | attack 7, six refusals at two widths |

Logs: `results/zk60_block125m_review/baseline.log` (the lane's own filter in
this worktree, 103 passed / 0 failed / 1 ignored),
`review-run1.log` … `review-run3.log`.
