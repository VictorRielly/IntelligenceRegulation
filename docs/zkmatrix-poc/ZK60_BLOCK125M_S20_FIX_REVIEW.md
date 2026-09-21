# ZK60 — independent adversarial review of stage 20 (the S19-F1 repair)

**VERDICT — soundness: NO HOLE FOUND. privacy: NO HOLE FOUND (argument and
budget only; see §2). completeness: NO HOLE FOUND.**

Reviewer: an independent agent that did not write the change and read the
construction before reading any stage-20 test. Under review: commit `5155d5b`
plus the re-pins `2f692bb` on `zk60-private-block-125m`. Review branch
`zk60-private-block-125m-review`, worktree `/home/victor/wt-zk60-block125m-review`
(merged to the lane tip; `git diff --stat zk60-private-block-125m -- hashline/src
zkp-core` prints nothing). Date: 2026-09-20. No production code was changed.

## 0. What the repair is, restated by the reviewer

`score[h,t,j] = sum_c q[t,h,c] k[j,g(h),c]` with `g(h)` the key-value group of
padded head slot `h` — its TOP `lkv = log2(kv_heads)` bits (C-1). Writing
`r_h = (r_g, r_hj)` and using that `k` does not depend on `hj` while `q` is
multilinear in it,

```
score~(r_h, r_t, r_j)
  = sum_{g in {0,1}^lkv} sum_{c} eq(r_g, g) * Q~(r_t, (g, r_hj), c) * K~(r_j, g, c)
```

and the matching `out~(r_t, r_h, r_i) = sum_{g,s} eq(r_g,g) P~((g,r_hj), r_t, s)
V~(s, g, r_i)`. I derived both on paper from `layout.rs`'s domain comments
(`Dom::Q = (t, slot, c)`, `Dom::Kv = (j, group, c)`, `Dom::S = (h, t, j)`,
MSB-first) before reading the lane's own check, and they are the identities
`argument.rs:1126-1187` builds. The group is the slot's LEADING sumcheck
variables `0 .. lkv`; the public factor is `Tab::Eq { point: r_g, start: 0 }`;
the degree is 3; `kv_heads = 1` gives `lkv = 0`, `group_eq` returns `None` and
the toy path is the old expression.

**Why the old form was wrong, in one line.** The product of two multilinear
extensions that SHARE a variable is quadratic in it, and the host's side is
multilinear, so the two are different polynomials the moment the shared
variable matters — i.e. the moment two key-value groups carry different data.

## 1. What I checked, and with what

Six new tests, all passing, in
`hashline/src/private_block/s20_review_tests.rs` (registered at
`hashline/src/private_block.rs:180`). Logs:
`results/zk60_block125m_review_s20/r1-defs.log`, `r2-cheats.log`,
`r3-private-gate.log`.

### 1.1 The identity, checked THROUGH the production definition

The lane's own independent check (`dense_tests.rs:898-1155`) deliberately does
NOT go through `argument::define`; it evaluates the paper formula with plain
loops. That leaves the other half unchecked: a correct paper identity can be
implemented with a coordinate segment in the wrong place, an `eq` at the wrong
`start`, or a factor reading the group at variables of its own. My check goes
the other way and is complementary:

`the_bilinear_slot_definitions_sum_to_the_hosts_extension` drives the REAL
`argument::define` over the whole slot order, takes the real `SlotDef` — the
real `Coord` lists, the real `Tab::Eq` point and start, the real closure — and
recomputes `sum_x poly(tables(x))` with the reviewer's own table builder
(`my_table`, written from the `Coord` semantics and sharing no code with
`argument::table_of`). It compares that to the reviewer's own multilinear
extension of the pointwise product at the slot's published claim point
(`pts.p_s()` / `pts.p_o()`). The `A` buffer is a fixed pseudo-random stream,
not a witness: the statement must hold for arbitrary plane contents, and a
degenerate witness is exactly how S19-F1 survived nineteen stages.

**Result: EQUAL at the toy, at rung-G and at a synthetic four-key-value-head
geometry, at three seeds each.** Matches the lane's verdict.

`the_pre_stage_20_formula_disagrees_exactly_where_the_defect_was` gives the
check teeth: the OLD formula differs from the host's extension on generic
planes at rung-G and at the synthetic kv=4 shape, and AGREES both at
`kv_heads = 1` and on a group-degenerate buffer. So the defect was real and
the repair is not vacuous.

`the_group_eq_carries_the_head_challenges_own_group_bits` pins the shape of
the repair off the real definition: exactly one `eq`, `start = 0`, width
`lkv`, and its point is byte for byte the head challenge's own group bits
read out of the claim point — not a point of its own; both private factors
take the group at the SAME variables `0..lkv`; the query factor's
within-group head is the challenge's `r_hj` as FIXED coordinates; and at
`lkv = 0` there is no public factor at all.

### 1.2 Soundness

* **Variable order.** Confirmed against the planes' real axis order, arm by
  arm. `SC_SCORE`: `cq = (r_t | rho(0..lkv) | r_hj | rho(lkv..lkv+ldh))` on
  `Dom::Q = (t, slot, c)` with the group in the slot's HIGH bits;
  `ck = (r_j | rho(0..lkv) | rho(lkv..lkv+ldh))` on `Dom::Kv = (j, g, c)`.
  `SC_PV`: `cp = (rho(0..lkv) | r_hj | r_t | rho(lkv..lkv+lt))` on
  `Dom::S = (slot, t, s)`; `cv = (rho(lkv..lkv+lt) | rho(0..lkv) | r_i)` on
  `Dom::Kv = (s, g, i)`. `sumcheck::prove` fixes variable `j` MSB-first
  (`zkp-core/src/sumcheck.rs:62-127`) and `priv_table` places `Rho(k)` at bit
  `n_vars-1-k` (`argument.rs:196-211`), so the group really is the first `lkv`
  rounds and `Tab::Eq { start: 0 }` really reads it. The claim points land on
  the planes their hosts read: `p_s` is consumed by `SC_SZC`
  (`argument.rs:1414`, host term `host_s` on `A_S8`) and `p_o` by `SC_QZC`
  (`argument.rs:1355`, host term on `A_O8`).
* **The public factor is the VERIFIER's own.** `argument.rs:389`:
  `Tab::Eq { point, start } => sel.mul(eq_point(point, &rho[start..start+len]))`
  — computed by the verifier from the `r_g` IT drew and the sumcheck
  challenges IT drew. It is never taken from the prover's terminal list; the
  terminal list is consumed only for `Tab::Priv` (`argument.rs:391-394`).
* **The degree.** Both sides take `(main, ext, degree)` from the same
  `Shape::slots()` (`argument.rs:302`), the prover publishes `degree + 1`
  values a round and the verifier refuses any other count
  (`zkp-core/src/sumcheck.rs:148-150`). The round polynomial really is degree
  3 (three factors, each linear in the round variable), and in the rounds
  after the group is bound it is degree 2 with a zero leading coefficient —
  over-declaring is sound (the interpolation is exact) and, for privacy, the
  published cubic coefficient is then purely `c * a_{j,3}`, a uniform mask
  coefficient. The `sc-round` absorb at degree 3 is 120 B, and
  `hash_domain.rs:123-151` builds that table from `Shape::degree_range()`
  (`shape.rs:673-677`) `= (2, 5)`, which is shape-independent and did NOT move:
  **120 B was already enumerated**, including for the legacy-rule frozen-seam
  rung (which has `kv_heads = 2` and so does newly produce degree-3 bilinear
  rounds).
* **Padded head slots.** `r_hj` is a random field point, so the identity is
  enforced on the padded slots `{3,7}` / `{3,7,11,15}` too. For an honest
  prover it still holds there because ruling P-1 gives every plane on a padded
  domain the ZERO rule with exactly one exemption BY NAME, `A_E`
  (`pad.rs:289-303`; `zero_rule_a_planes` at `:365-370`), so `A_QR8`, `A_KR8`,
  `A_P`, `A_V8`, `A_S8` and `A_O8` are all forced to zero off support and the
  product vanishes on the pad exactly where the host's `supp` gate does.
  Measured: four padded-head-slot tampers, all rejected (§1.4).
* **Was the OLD construction sound?** I re-derived it and **confirm
  sound-but-incomplete.** The host side `LHS(r_h,r_t,r_j) = sum_x eq(p_s,x)
  supp(x) score(x)` is MULTILINEAR in every coordinate; the old right-hand side
  `sum_c Q~(r_t,r_h,c) K~(r_j,r_g,c)` has degree 2 in each group coordinate.
  A pass at one random point gives, by Schwartz–Zippel over a polynomial of
  total degree `<= 2(lh + 2 lt)` in a field of about `2^124` elements,
  `LHS == RHS` as POLYNOMIALS; `LHS` is multilinear, so `RHS` must be too, and
  a multilinear `RHS` equals its own interpolation from boolean `r_g`, which is
  exactly the correct extension. So a passing old receipt implied the true
  statement. **No receipt accepted before the fix could have attested a false
  statement** on this account — and in fact the only receipts ever produced at
  `kv_heads > 1` were on group-degenerate witnesses, where the two forms
  coincide.

### 1.3 Privacy

* **`L_s`, re-derived by me from the axes** (`(main + ext) * degree + 2`), not
  copied: toy **12 / 16** (unmoved), rung and rung-G **23 / 26** (from 14 / 16),
  125M **32 / 41** (from 18 / 24), synthetic kv=4 **23 / 23**. **These are the
  lane's figures exactly.** Largest slot length over the whole block does not
  move (`SC_SZC`: 50 / 72 / 117), so the M-row budget `L_s + 256 <= 512`
  — enforced at run time by `zk.rs:493` — keeps all of its room.
* **`ext` stays 2** and the mask is `CfsMask::random(rng, main + ext, degree)`
  through `Layout::mask_specs()` (`layout.rs:1149-1151`), so the mask grows with
  the schedule automatically. The CFS freedom count is unchanged in structure:
  `N*d + 2` coefficients against `1` scalar `+ N*d` free round values `+ 1`
  terminal.
* **"One factor masked in extension round 0, the other in round 1" still
  holds.** `A_QR8` has `ext_round = 0`, `A_KR8` `ext_round = 1`; the verifier's
  coefficients are `cd = (1-e0)(1-e1)` for both and `cm = e0(1-e1)` /
  `cm = e1` (`argument.rs:409-414`), matching the prover's `masked_terminal`
  chain, and both are nonzero because `e = 0` and `e = 1` are refused
  (`argument.rs:404-406`). The new public `eq` carries the extension rounds'
  `(1-e)` factor through `sel` (`argument.rs:383, 389`) and its extension value
  is 0, so the construction premise `poly(extensions) = 0` still holds.
* **The two terminal points now SHARE the group coordinates `rho_g`.** This
  changes nothing the masking machinery depends on. `audit_claims`
  (`protocol.rs:230-274`) is structural — rows, not points — and the two
  claims still take `a_site(slot, 0)` and `a_site(slot, 1)`, two distinct
  reserved rows, one claim each. The surjection step's two real conditions
  (the pair weights are exactly `(cm, cm*U)`; no two claims and no two groups
  share a masking row — `ZK60_TERMINAL_SURJECTION_REVIEW.md` §0 item 3) are
  properties of `build_claim` and of the row schedule, not of the points. And
  the two claims are still in DIFFERENT opening groups: the PCS key is
  `(point tail, column offset, slice length)` (`protocol.rs:186-192`), the two
  tails differ in every position but the trailing `rho_c`, and — decisively —
  `check_opening` enforces the declared `sh.a_groups()` on both sides
  (`protocol.rs:795, 887`) and every honest rung-G proof passes, so the group
  count is MEASURED unmoved, not merely argued.
* **The layout model's DOF / rank conclusions carry over.** The lane's probe
  (`results/zk60_block125m_lane/v6-s20-model-probe.log`) shows `m_rows`,
  `a_sites`, `h_sites`, `a_groups`, `h_groups`, `largest_L` and the private
  terminal count all UNMOVED at all three shapes; only the round counts, the
  slot vector's bytes and the two `L_s` move. Everything the disclosure model
  is built on is therefore the same object. But see F-1 on what that probe is
  and is not.

### 1.4 Completeness and the cheating witnesses

`no_honest_case_is_rejected_by_the_verifier_at_the_rung_g` — **7 of 7 honest
cases VERIFY, 0 rejected, 0 inadmissible**: three fully dense statements with
independent random hidden inputs (so every key-value head sees different
data), a half-the-width-zero input (one group's activations driven sharply
apart), the tame fixture with one query head's word moved, **the ALL-ZERO
hidden input**, and the tame fixture itself.

`mass_in_a_padded_head_slot_or_across_a_key_value_group_is_rejected`, on the
FULLY dense witness — all five refused by the verifier:

| cheating witness | refused by |
|---|---|
| `A_QR8` at padded head slot 3 | slot 15 `04 Q zero-check`, round 0 |
| `A_P` at padded head slot 3 | slot 15 `04 Q zero-check`, round 0 |
| `A_S8` at padded head slot 3 | slot 17 `06 softmax zero-check`, round 0 |
| `A_O8` at padded head slot 3 | slot 15 `04 Q zero-check`, round 0 |
| group 0's rotated keys made to serve group 1's heads | slot 16 `05 KV zero-check`, round 0 |

### 1.5 The toy really did not move

At `lkv = 0` the only code that runs and did not run before is
`cat(&[&r_h])` (a clone), `Vec::split_off(0)`, `rho(0..0)` (an empty vector)
and `Gate(None)` — all pure value operations. `group_eq` returns `None`
WITHOUT pushing a `Tab` (`argument.rs:488-493`), so the table list, the
private-terminal count, the closure's indices, the plane list and the
terminal order are identical; no challenge is drawn; `shape.rs:650` leaves the
degree at 2. `Layout::new` asserts the shaped schedule equals the frozen
`SLOTS` literal at the toy, and the whole frozen gate is green in my tree.

### 1.6 Everything derived from the slot tables

`wire::encoded_len` / `validate` / `decode` / `segment_len`,
`shape::slot_lengths` / `receipt_bytes`, `Layout::for_shape` / `slots` /
`mask_specs` / `describe` (and so the transcript-bound `schedule_digest`),
`run_capture.rs:431-489`, `plane_index.rs:345-377` (correctly unmoved — the
new `eq` is a PUBLIC table and the plane index only lists `Tab::Priv`),
`timing.rs`, `run.rs` / `run_statement_file.rs` (no round or degree field at
all) and `hash_domain.rs`'s length table all read the schedule. I found
nothing in the Rust production path that still assumes degree 2 or the old
round counts for slots 08 / 09. The stale things are in Python (F-1) and in
one test-only capture path (F-5).

## 2. Findings

### F-1 — the independent Python model is stale, and its tests entrench it, so the rung and 125M receipt figures have lost their independent witness. (Medium; a verification gap, not a hole in the proof system.)

`scripts/zk60_private_block_layout_model.py:325` still reads
`SC_SCORE: clog2(sh.head_dim), SC_PV: clog2(sh.t_pad)` — no `lkv +` — and
`:333` reads `deg = BASE_DEGREE[s] + (1 if ind else 0)` — no group-`eq` term.
The model therefore reports the PRE-repair schedule and receipt totals at
every `kv_heads > 1` shape (336 B short at the rung, 560 B short at 125M).
`tests/test_zk60_private_block_layout_model.py:131` pins `4_173_208` and
`:176` pins `40_750_024`, i.e. the model's own stale numbers; I ran the suite
in this worktree — **25 tests, OK** — so nothing in Python would catch it, and
fixing the model would make those two tests fail. The one model-to-Rust
cross-check, `scripts/zk60_private_block_inventory.py:845-896`, reads
`LM.TOY` at `:855` and is toy-scoped, where old and new agree byte for byte.
Meanwhile `grow_tests::check_against_model` now ADJUSTS the model's
expectation by a Rust-computed `s20_bilinear_delta`
(`grow_tests.rs:389-401, 413-414`), so both sides of that comparison are the
lane's own arithmetic. The lane's probe
(`results/zk60_block125m_lane/v6-s20-model-probe.py`) monkey-patches `slots`
with a hand-written copy of the SAME rule, so it confirms the model's
downstream arithmetic — usefully, and that is what §1.3's DOF conclusion
rests on — but it is not an independent derivation of the schedule.
**Smallest repair:** the two lines in the model; re-pin the two test totals to
`4_173_544` and `40_750_584` (the probe's figures); drop the
`s20_bilinear_delta` adjustment from `check_against_model` so the model is an
oracle again; and extend `model_cross_check` past the toy.

### F-2 — the bilinear coordinate lists silently require `Dom::Q`, `Dom::Kv` and `Dom::S` not to be lifted by the P-3 rule. (Low; fail-closed.)

Both arms build lists of the NATURAL length (`lt + lkv + ldh`, `lh + 2 lt`),
while `B::a_at` takes the plane's log from `Shape::log`, which is the P-3
LIFTED log (`layout.rs:136-142`). At a shape whose `Dom::Kv` sits below the row
width the list is shorter than `p.log` and `run_slot` refuses "slot `s` table
shape" (`argument.rs:308-310`) — fail-closed, so not a hole, but the refusal
names a symptom and there is no construction-time refusal. I met it while
choosing the synthetic four-key-value-head geometry for §1.1 (it forced
`head_dim = 8` rather than 2). Pre-existing, not introduced by stage 20.
**Smallest repair:** one named refusal in `Shape::new` — a shape that lifts a
domain the bilinear slots address at its natural log is refused by name.

### F-3 — my cheating witnesses are refused, but not BY the repaired slots. (Informational; a limit on my own controls.)

Every tamper in §1.4 is caught by a zero-check's pad term or RoPE relation
(slots 15 / 16 / 17), not by `SC_SCORE` / `SC_PV`. The controls therefore
establish that the verifier refuses, which is what matters, but they do not
isolate the repaired slots as the refuser. Isolating one would need the
pad-zero term switched off, i.e. a production edit, which this review does not
make. The isolating statement I could make without touching production is
`the_pre_stage_20_formula_disagrees_exactly_where_the_defect_was`: the
bilinear slot's sum is a function of the true per-group key and value data and
changes when the group structure is substituted.

### F-4 — `native_capture.rs` replays a slot's sumcheck from the frozen TOY literal, not the shape. (Informational.)


`hashline/src/native_capture.rs:111-112`: `let (n, ext, degree) = SLOTS[s];`
then `sumcheck::verify(claimed, degree, n + ext, ...)`. `SLOTS` is
`layout.rs:815`'s toy constant. The file is `#[cfg(test)]` and is only driven
at the toy, so it is correct today; it is the one capture path that would
silently mis-replay at a grouped shape. `run_capture.rs:431` reads
`def.sh.slots()[s]` and is right. **Smallest repair:** take the triple from
the shape there too.

### F-5 — one stale pre-repair byte literal survived stage 20, in an `#[ignore]`d test. (Low; ALREADY FIXED on the lane after the tip I reviewed.)

At the tip under review (`c18981a`),
`hashline/src/private_block/rulings_tests.rs:452` still asserted
`bytes.len() == 40_782_792` — the PRE-repair 125M frame length — while every
other pin in the tree is the counted `pre-repair + s20_bilinear_delta` form.
I swept every pre-repair literal in `hashline/src`, `scripts` and `tests`
(`4_218_264`, `4_234_648`, `40_782_792`, `12_413_432`, `49_217_600`,
`484_100_736`) and this is the ONLY bare one. It could not be caught by the
stage's own gate because the test is `#[ignore]`d, and it was outside my own
sweep for the same reason. **The lane found and repaired it in `a00f831`**,
which also records the measurement that corroborates this review's
completeness verdict at the deliverable shape: one 125M block on fully dense
public weights proves and verifies from bytes at `40,783,352 B` — the counted
POST-repair length — on a generic hidden input and on the all-zero input.
**Lesson, not a defect:** a delta-counted pin should be used in ignored tests
too, or an ignored test's literals should be swept whenever a schedule moves.

### F-6 — the M-row budget is a bare `assert!` in the prover. (Informational, unreachable today.)

`zk.rs:442` and `:493`: `assert!(part.len() + MASK_Q <= m, ...)`. A panic where
this module's style elsewhere is a named `Result` refusal. Unreachable at every
shape the module can build (worst `L_s` is 117 against 256), and stage 20 did
not move the worst slot. Pre-existing.

## 3. What I could not check

* **No 125M proving and no GPU** (excluded by the brief). The 125M figures
  here are counted from the shape, not measured; the lane measured them
  separately, and its `a00f831` — one commit past the tip I reviewed — reports
  one 125M block proving and verifying from bytes at the counted post-repair
  `40,783,352 B` on a fully dense statement with a generic hidden input and
  with the all-zero input. I did not reproduce that.
* **My branch is one commit behind the lane.** The brief allowed exactly one
  merge; the lane advanced to `a00f831` afterwards. Nothing in that commit
  changes a verdict here (it repairs F-5 and adds evidence).
* **No privacy MEASUREMENT at any grouped shape.** The rank / CFS /
  disclosure tools of `ZK60_TERMINAL_SURJECTION_REVIEW.md` were run on four
  captured receipts at toy-class shapes. My privacy verdict is about the
  ARGUMENT (the masking mechanism, the reserved pairs, the opening groups) and
  about the BUDGET arithmetic. It is not a disclosure result at rung-G or
  125M, and it is not a privacy acceptance.
* **The hash layer, the sampler's own bias and the simulator** are untouched
  here, as they were in the surjection review.
* **The other twenty-one slots** were not re-audited; I reviewed what stage 20
  moved and what it is coupled to.
* **No `--ignored` test was run**, including the 125M dense-run band probe.
* Whether the honest fully dense 125M block proof completes is the lane's
  running measurement, not mine.

## 4. Tests added by this review

`hashline/src/private_block/s20_review_tests.rs` — six tests, all passing
(`r1-defs.log`, `r2-cheats.log`). The lane's whole `private_` gate re-run in
this worktree with them added: **251 passed / 0 failed / 8 ignored, 379.87 s**
(`r3-private-gate.log`), against the lane's own stage-20 figure of 245 / 0 / 8
— the six are mine. Nothing in production was changed and no existing test was
weakened. `python3 -m unittest` on
`tests/test_zk60_private_block_layout_model.py`: 25 tests, OK — with the stale
model, which is finding F-1.
