# Lane stages 39–43: independent adversarial code review

Reviewer: Claude (Opus 5.5). Review branch `zk60-private-block-125m-review`,
worktree `/home/victor/wt-zk60-block125m-review`. Started 2026-09-23 01:59
PDT; findings written 02:12 PDT; the gate recorded 02:21 PDT. Under review: lane `zk60-private-block-125m`,
delta `a9d6d4c..f486e6f` (stages 39–43 plus the `timing.rs` comment fix),
merged into this branch at `5fd5a69`. The merge had one conflict, in the
test-module list of `private_block.rs`; I kept both sides, as the coordinator
directed. **No production line was changed on this branch.**

Scope: the eight production files the delta touches (`private_block.rs`,
`private_block/{shape,protocol,witness,run,layout,timing}.rs`, and
`run_statement_file.rs`, a reader that exists only in test builds). Every
hunk was read. Test edits were read where they could weaken a soundness
harness (`review_tests`, `tamper`, `norm_alias`, `rung_tests`, `run_tests`,
`hash_tag_tests`, `grow_tests`, `s35_tests`). The lane's own
`s40`–`s43` tests were read where a finding depends on them.

**Not a privacy acceptance of anything.**

## Summary

**No soundness regression and no completeness regression was found.**

- Every verifier-side hunk either adds a refusal or replaces a check with
  one that refuses strictly more.
- Every new refusal admits every registered shape with its own statement.
- Each new refusal fires before the first draw, commitment or absorb on its
  path, except where the ruling accepted otherwise: CS-3 fires inside a run,
  as ruling M-9 allowed.
- The test-only switches are compiled out of the release library.

Four findings are recorded, and none blocks the lane:

- **K-1 (erratum, reproduced).** CS-3's refusal text says nothing of the
  block was drawn, absorbed or committed. Inside a run that is false.
- **K-2 (erratum).** CS-3's refusal text prints three counts computed from
  the hidden witness.
- **K-3 (note, reproduced).** The declaration pin that replaced the deleted
  tests is a real guard, but a narrow one.
- **K-4 (note, reproduced; pre-existing and outside the delta).** A block
  profile string is bound to no geometry. The toy's profile string at
  rung-G's geometry passes every CS-8 check, and the verifier then rejects
  its honest proofs.

Four further observations (O-1 to O-4) close the review: the run layer is
dead code in a release build, the layout re-check does not compare the IO
pair rows, the unmeasured exp scales 2 and 3 are refused by name, and CS-3
adds one pass over the looked words.

## 1. Findings

### K-1 — erratum, reproduced: CS-3's refusal text is false inside a run

`protocol.rs:511`: *"(refused before the A commitment; nothing of this
block was drawn, absorbed or committed)"*.

- **In a run.** For stage `k`, `prove_run` does the following before it
  reaches `prove_core`:
  - absorbs `pb-run-stage` and `pb-run-block` (`run.rs:746-747`);
  - asks the witness source for boundary `k`'s plane, commits it with draws
    from the run's stream (`boundary::prepare`, `run.rs:756`), and absorbs
    its root (`:757`).

  Only after that does `prove_core` (`run.rs:774`) reach the refusal
  (`protocol.rs:965`). The disposition accepted this ordering (§5, ruling
  M-9); the text contradicts it.
- **In a single block** the text is loosely false too. The OS stream is
  opened at `protocol.rs:802` and the transcript header is absorbed at
  `:806`, both before `prove_core`. The accurate statement is "before this
  block's first draw, its `A` commitment and any challenge".

**Reproducer:** `rv_k1_the_cs3_refusal_text_is_false_in_a_run`, `#[ignore]`d.

- Setup: a rung-G run with `L = 2`, block 0's witness tampered by one
  activation word (a lookup miss), the honest run prover with CS-3 on.
- The prover asked for `["boundary_plane(0)", "witness(0)"]` in that order
  and sank 0 segments.
- It then refused with CS-3's text, including the "nothing … committed"
  clause.
- The run exits with code 101, as a reproducer must
  (`results/zk60_s39_s43_review/rv-k1-reproducer.log`, `reproducers.log`).

**Fix:** a text-only change, with no behaviour change. Either drop the
parenthetical, or say "before this block's `A` commitment; in a run, after
the stage header and the block's outgoing boundary (ruling M-9)". The lane's
`s40_tests.rs:73` (`cs3()`) pins the text and moves with it.

### K-2 — erratum: CS-3's refusal message prints values derived from the hidden witness

The same message ends with `{u8} U8 words outside the byte table, {exp} exp
pairs and {act} activation pairs not rows of the statement's tables`. These
are three counts computed from the hidden witness.

**Why this is not a lapse today:**

- D21 makes every refusal reason prover-private, and the message goes only
  to the prover's caller.
- For every witness the builder admits, the refusal cannot fire. This rests
  on the census, and is supported here by 11 toy and 18 padded-shape honest
  inputs, none refused by CS-3 (§2, Q2).

**Why it should still change:**

- CS-3 exists for the case where it does fire: a future admissibility gap,
  that is, some hidden inputs the builder wrongly admits.
- In that case the message tells a reader how many of the hidden witness's
  words miss. That is more than the bare refusal, which D21 already treats
  as a disclosure.
- The R1d review raised "secret-derived failure messages" as a reason not
  to land that candidate. The same rule applies here.

**Fix:** drop the three counts; the ruling's name is enough. Otherwise,
record the message under ruling P-2's operating rule (prover-private output,
never kept in a bundle or a published log). Pinned by `s40_tests.rs:73`.

### K-3 — note, reproduced: the stage-43 declaration pin is real but narrow

`s43_tests.rs:389` replaced two tests that no longer compile: the S42-N1
note test and the four-route measurement. The replacement reads six struct
declarations and fails when a field carries a visibility modifier.

- **What it catches:** a field made visible again. Mutation (d) —
  `pub sh: Shape` — is caught.
- **What it misses** (`rv_q7_the_declaration_pin_misses_a_new_constructor_and_an_uncfgd_escape_hatch`,
  measured on `run.rs`'s own text):
  - (b) a second `pub(crate)` constructor inside `impl RunShape` that builds
    a literal and skips CS-7. This is S42-N1 again, reachable from every
    file of the crate. The pin sees 0 visible fields.
  - (c) `#[cfg(test)]` removed from `RunStatement::with_run_shape`. That
    gives production a way to swap a statement's run shape past every check
    `RunStatement::new` makes. The pin sees 0 visible fields.
- **A stronger guard, in the same file, which passes the source as it
  stands and catches both (b) and (c):**
  - exactly one `RunShape` literal, inside `RunShape::new`;
  - exactly one `RunStatement` literal, inside `RunStatement::new`;
  - `with_run_shape` and `with_calibration` each directly under
    `#[cfg(test)]`;
  - no `&mut` accessor to the sealed fields.

**Recommendation:** add the stronger guard beside the pin at the lane's next
stage. On why a `compile_fail` doctest would not work, the lane is right: it
would pass vacuously, because the module is private.

### K-4 — note, reproduced: a block profile string is bound to no geometry (pre-existing, outside the delta)

Ruling CS-7 binds a **run** profile to exactly one block shape, because
"privacy statements and hash keys are per profile". Nothing binds a
**block** profile string to its geometry:

- `Shape::new` accepts any profile string.
- CS-8's `check_constructed` admits exactly what `Shape::new` admits.
- The pad rule and the legacy hash rule are both keyed on the profile
  string (`shape.rs:1054-1083`).

**Measured** (`rv_k4_the_toy_profile_string_at_another_geometry_passes_every_cs8_check`):
the frozen toy's profile string at rung-G's geometry.

- **Admitted by** `Shape::new`, CS-8, `Layout::for_shape`, CS-1/CS-4 (with
  rung-G's dense statement), a policy made for it, and the builder.
- **Its settings:** it is `is_frozen_toy()`, it carries **no pad rule**
  although `Dom::F` and `Dom::D` pad, and it hashes under the legacy rule.
- **What happens to its honest proofs:** the honest prover (CS-3 on)
  proves.
  - The encoder refuses the receipt: *"frame exceeds bound"*.
  - The in-memory verifier **rejects** it at slot 2, the norm-squares
    zero-check: *"sumcheck round 0: s(0) + s(1) != claim"*.

  The ignored reproducer
  `rv_k4_an_admitted_toy_profile_shape_at_another_geometry_fails_its_honest_proofs`
  fails on the dense, tame and all-zero inputs (`reproducers.log`).

**Why it matters:** this is the class stages 38–43 refuse by name at
construction — an admitted shape whose honest proofs fail (C-6, CS-2) —
reached through the one parameter the sweep did not bind.

**Reach:** no production path reaches it. Every shaped entry is
`pub(crate)`, and the toy's public API always uses `Shape::toy()`. It is not
a regression. It bears on whether CS-8's sweep is complete: the sweep asked
what `Shape::new` admits, not what a profile string names.

**Recommendation (a ruling for the security owner):**
- A block-profile registry, parallel to CS-7: `check_constructed` (or
  `Shape::new`) refuses the toy's and the frozen-seam rung's legacy profile
  strings at any geometry but their own, and each registered profile at any
  shape but its registered one.
- Alternatively, record that shaped entries trust the caller's shape for its
  profile.

## 2. Verdicts per question

### Q1 — soundness regressions: NONE

The verifier-side hunks, all read:

| hunk | what it does to the verifier |
|---|---|
| `verify_bytes_at` (`private_block.rs:1176-1181`) | +CS-8, +CS-1/CS-4, +the policy check |
| `verify_bytes` (`:1192-1193`) | +CS-1/CS-4 at the toy, +the policy check |
| `verify_inner_at` (`protocol.rs:1317-1323`) | the same additions |
| `verify_core` (`:1190-1194`) | the same additions |
| `IoSpec::new_shaped`, `check_for_shape`, `validate` | +the scales check, +the checks of the fields derived from the shape |
| `Shape::new` | +C-6, +CS-5, +CS-2 |
| `RunShape::new` | +CS-7 |
| `RunStatement::new` | +CS-1/CS-4 |
| `RunVerifier::start` | the count check becomes a strict superset, +CS-1/CS-4, +CS-6 |
| `verify_run` and `verify_run_from_dir` | the count check becomes a strict superset |

- **Removed lines.** All 41 were listed. Each is a move (the two statement
  constructors, the `act` conversion), a strict-superset replacement (four
  `blocks.len() != l` checks become `as_many_blocks_as_the_statement`),
  a visibility change, or text.
- **No early `Ok`** was added on any verifier path.
- **CS-3 is prover-only by design.** The verifier's LogUp identity is
  unchanged.
- **The verifier never consults the switch:** `RunVerifier::start` calls
  `blocks_are_the_statements` directly (`run.rs:864`).
- **The weakened test harnesses.** `review_tests::outcome`,
  `rung_tests::assert_verifier_rejects`, `tamper`, `norm_alias` and one run
  test now prove under `CheatingProver`. That switch turns off CS-3 (and the
  run prover's CS-6) only. Each harness still asserts a verifier rejection,
  and still fails when the prover refuses.
- **`hash_tag_tests`** now hands each verifier its own rule's policy. The
  test still reaches the hashing layer, and it asserts that the refusal is
  not CS-4's.

### Q2 — completeness regressions: NONE on registered inputs

- **`check_constructed` is exact for every registered shape**
  (`rv_every_registered_shape_and_its_own_statement_pass_every_new_recheck`).
  The shapes checked: the toy, rung, rung-G, K4, P2, C6, W14, E32, 125M, and
  the test-only K8.
  - No registered shape passes a window override. The rung's endpoint
    overrides `Some(8), Some(8)` come back unchanged.
  - A no-override shape re-checked with `Some(norm_wrho)` could only fail if
    the derivation `12 + bits(isqrt(1 + w·32767²))` fell below CS-2's
    minimum. In exact arithmetic over every width `1 … 2^20`, it falls below
    at 21 widths. The first is 16,385; none is at or below 16,384, which is
    CS-5's cap (`norm_window_check.{py,txt}`).
  - It is never above the minimum, so equality is exact.
  - The `wrho_s` derivation and CS-2's minimum are the same expression.
  - The fields that could differ are all compared: the derived ones and
    `opened_cols`.
- **The other re-checks admit every registered shape:**
  `Layout::check_is_for_shape` (also for a run-stage layout with moved IO
  rows), `IoSpec::check_for_shape` and `validate`, `BlockPublic::check_for_shape`
  on each shape's tame and dense statements, and CS-7's `RunShape::new` for
  all eight run profiles at `L = 1, 2, 12`.
- **CS-3 on honest inputs.**
  - Toy, through the public `prove_with_stats`: of 16 inputs, including the
    int16 extremes and 8 seeded full-range inputs, **11 proved at
    2,816,472 B and were accepted, 5 were refused by the builder by name**
    (`fixed oracle range refusal`), and **0 were refused by CS-3**.
  - Rung-G and rung-K4, dense statement, honest `prove_inner_at`: **18
    proved and were accepted**. The rest were refused by the builder by name.
    **0 were refused by CS-3 and 0 rejected** (`rv-tests.log`).
  - A structural argument covers the rest. CS-3 fires exactly when the old
    code filed a word into bucket 0, because the `hit` predicates at
    `protocol.rs:945` and `:953` are unchanged and `u8_misses_of` uses the
    same predicate as `bin`.
  - For any witness whose looked words are the integers the committed planes
    encode (every admitted witness, by the no-wrap premise), a word outside
    the table fails the verifier's LogUp identity, except with the LogUp
    soundness error. So CS-3 can only replace a receipt the verifier would
    reject with a refusal. It can never refuse one the verifier would accept.
- **Note C-6's unmeasured lower edge** (stage 40 skipped `f_e` 2 and 3): see
  O-3. They are refused by name.
- **Outside the registered set:** K-4.

### Q3 — ordering: each refusal fires before the first absorb, commitment or draw on its path, with CS-3-in-a-run as the one accepted exception (the text of which is K-1)

| path | the new checks, in order | they precede |
|---|---|---|
| single-block prover `prove_inner_at` | CS-8 shape `:783`, blk `:789`, policy `:790` | owners opened `:791`, OS stream `:802`, header `:806` |
| `prove_core` (shared) | CS-8 shape `:906`, layout `:907`, blk `:912` | the first `rng.fp()` `:990`, commit `:996`, absorb `:1000` |
| CS-3 | `:965` | the first `A` mask draw `:990`. After the header (`:806`) in a block; after the stage header and `B_k` (`run.rs:746-757`) in a run (K-1) |
| single-block verifier `verify_bytes_at` | CS-8, blk, policy (`private_block.rs:1176-1181`) | `Receipt::from_bytes_at` (the first header digest) |
| `verify_bytes` (toy) | blk, policy (`:1192-1193`) | `Receipt::from_bytes` |
| `verify_inner_at` | CS-8 `:1317`, blk `:1322`, policy `:1323` | path checks, `wire::validate`, header `:1336` |
| `verify_core` | CS-8 shape and layout `:1190-1191`, blk `:1194` | the first `absorb_root` and `challenge_fp2` |
| run prover `prove_run` | count `:703`, CS-1/CS-4 `:708-709`, CS-6 `:713` | `validate`, owners `:715`, OS stream `:727`, header `:731` |
| run verifier `RunVerifier::start` | count `:855`, CS-1/CS-4 `:859-860`, CS-6 `:864` | `validate`, header `:869`; `verify_run_from_dir` lists the directory (`segment_paths`) but reads no segment first |
| `RunStatement::new` | count, CS-1/CS-4 `:220-221` | the block digests `:270` |
| constructors | `Shape::new` (C-6, CS-5, CS-2), `RunShape::new` (CS-7), `IoSpec::new_shaped`, `prepare_endpoints` (scales before the owner's OS draw), `build_shaped` (before the input is read) | nothing to absorb |

The checks inside `prove_core` and `verify_core` come after the caller's
header, but at every production caller they are unreachable: the entry has
already made the same check on the same values, and the run builds its
layouts from its own statement.

### Q4 — the test-only switch: GATED; absent from the release library

**By reading.** `CHEATING_PROVER`, `CheatingProver`, its `on` and `Drop`,
and `cheating_prover_is_on` are each under `#[cfg(test)]` (`protocol.rs:503`,
`:523`, `:531`, `:540`, `:545`, `:552`). So are:
- the two consultations of the switch (`protocol.rs:503`, `run.rs:681`);
- the K8 registry arm (`run.rs:107`);
- `with_run_shape` (`:319`) and `with_calibration` (`:301`).

**By the release build.** `cargo build --release --lib` (no tests) succeeds
in 49.65 s (`release-lib.log`), so no code outside the tests references a
`cfg(test)` item.

**By scanning the library** (`release-lib-scan.txt`):
- `nm` finds **no** symbol containing `cheating`, `Cheating`,
  `with_run_shape`, `k8_tests` or `rung_k8`.
- The control symbols are present: `refuse_lookup_misses`, `u8_misses_of`,
  `check_constructed`, `check_is_for_shape`.
- The K8 profile strings and the thread-local `CHEATING_PROVER` are absent.
- The control texts (CS-3, CS-4, CS-8) are present.
- The identifiers `CheatingProver` and `cheating_prover_is_on` do occur
  once each. They sit in the library metadata's identifier table, beside
  three pre-existing `cfg(test)` items (`rung_witness`,
  `every_checkable_relation_holds`, `set_moved_multiplicity`). The compiler
  records those names while reading the source, before test-only code is
  stripped. They are names, not compiled code.
- One caveat: the whole run layer is dead code in release (O-1), so the
  absence of the K8 registry arm there is trivially true.

### Q5 — do the new checks depend on the hidden input?

| check | reads | depends on the hidden input? | message prints |
|---|---|---|---|
| CS-1 / CS-4 (statement halves, policy) | the statement's words, the policy's fields, the shape | no | public text (no weight values) |
| CS-2, CS-5, C-6 | `Shape::new`'s parameters | no | parameters |
| CS-6 | the public block digests | no | 8 bytes of two public digests |
| CS-7 | the profile string and the shape | no | names and profile strings |
| CS-8 (shape, layout, scales) | shape, layout, policy fields | no | names, field names, the policy's scales |
| **CS-3** | **the witness** | **yes, by design**; it cannot fire on an admitted witness (Q2) | **three counts from the witness — K-2** |

The builder's re-check (`witness.rs:443-444`) now runs before `input.len()`
is checked. That changes which of two public refusals a malformed call sees,
and nothing else.

### Q6 — D22 condition 7: see §3

No hunk changes the toy's behaviour for an admitted toy input.

### Q7 — the deleted tests' replacement: a real guard for what it pins, and blind to two ways of reopening S42-N1 (K-3)

## 3. D22 condition-7 hunk table (the toy's pin set plus the six files P-1 adds)

**Which files are in play.** Of the 43 paths, the delta moves six:
`private_block.rs`, `protocol.rs`, `layout.rs` and `witness.rs` (pinned), and
`shape.rs` and `timing.rs` (added by P-1).
- `git diff a9d6d4c f486e6f` on the other 37 paths is empty.
- `run.rs` is off the toy path, and `run_statement_file.rs` exists only in
  test builds.

**Digests.** `layout.rs`, `witness.rs`, `shape.rs` and `timing.rs` at
`a9d6d4c` are exactly the snapshot digests the D22 pre-read read and P-1 /
Part A name (`14758039…`, `b9b66c02…`, `dbf4e2bc…`, `f3d0befd…`). So for
those four files this table is the whole step from the pre-read's reading
to the lane tip. `protocol.rs` (`e0e617be…`) and `private_block.rs`
(`b6728273…`) at `a9d6d4c` already differ from the snapshot by stages
36–38, which this review does not cover. Old → new SHA-256 values are in
`sha256-a9d6d4c-f486e6f.txt`.

**Classes:**
- **(i)** off the toy path, or test-only;
- **(ii)** on the path and the same for every admitted toy input;
- **(iii)** changes behaviour.

| file | hunk (new lines) | what | class | why |
|---|---|---|---|---|
| `private_block.rs` | `+304,16` | 4 test-only `mod` lines | (i) | `cfg(test)` |
| | `+488,33` / `+548,12` / `+587,10` | `AttentionPublic::new_shaped` → `check_words` + `check_for_shape` | (ii) | the same checks, the same order, the same messages, then the same struct; `new` = `new_shaped(toy)` |
| | `+630,21` / `+659,23` | `FeedForwardPublic` → `check_words` (adds S38-F1(a)) | (ii) | `act.len() != 256` gives the same message as the old `try_into`; S38-F1(a) needs `pads(Dom::F)`, which is false at the toy (`f = f_pad = 16`) |
| | `+733,12` | `BlockPublic::check_for_shape` | (ii) | always passes for halves built by the public constructors at the toy (their fields are private to the crate) |
| | `+830,5` / `+839,61` / `+906,3` | policy check in `new_shaped`, `check_for_shape`, the scales re-check in `validate` | (ii) | `IoSpec::new` and `ExpectedIo::from_bytes` pin `(0,0)` and derive every field from `Shape::toy()`; `prepare_endpoints` runs `validate` before the owner's OS draw, and the new check passes |
| | `+1175,7` | `verify_bytes_at` checks | (i) | the shaped entry; the toy's public API never calls it (dead in release) |
| | `+1189,5` | `verify_bytes`: the toy re-check before `from_bytes` | (ii) | passes for every toy statement and policy the public API can build; the accepted frames are unchanged |
| `protocol.rs` | `+432,3` | doc comment | (i) | text |
| | `+476,83` | `u8_misses_of`, `LOOKUP_MISS_REFUSAL`, `refuse_lookup_misses`, `CheatingProver` machinery | (ii) / (i) | the functions are called on the toy path (next row); the switch is `cfg(test)` |
| | `+781,3` / `+786,5` | `prove_inner_at`: CS-8, blk, policy | (ii) | `Shape::toy()` passes (Q2); the statement and policy pass as above |
| | `+902,11` | `prove_core`: CS-8 shape, layout, blk | (ii) | the layout is `Layout::for_shape(toy)` from the entry. It re-runs `for_shape` — legacy T-3 lengths, no key derivation — with no draw or absorb |
| | `+943…+957` (5 hunks) | CS-3: two counters, one refusal before the `A` mask draw | (ii) for admitted inputs | no draw, absorb or commit is added or moved. It fires only when the pre-existing bucket-0 filing did, which admitted toy witnesses never do (census; 11 of 11 admitted toy inputs here, all at 2,816,472 B). It adds a new refusal site whose firing depends on the input but is unreachable for admitted witnesses, so D22 §9 item 10's refusal clause is unchanged but should list it at the re-pin. One extra pass over the looked words (O-4, timing, out of scope under D20) |
| | `+1188,7` | `verify_core`: CS-8, blk | (ii) | as above |
| | `+1315,3` / `+1320,4` | `verify_inner_at`: CS-8, blk, policy | (ii) | as above |
| `layout.rs` | `671` | comment 98,582,528 → 98,598,912 | (i) | text |
| | `+1163,43` | `Layout::check_is_for_shape` | (ii) | the toy layout equals itself |
| `witness.rs` | `+440,5` | `build_shaped`: CS-4 / CS-1 re-checks | (ii) | toy statements pass; only the order of two public refusals moves |
| `shape.rs` | `+48,10` | constants | (ii) | inert |
| | `+206,39` | C-6 `f_e > 31`, CS-5 `width > 16,384` | (ii) | toy `f_e = 9`, width 16 |
| | `+246,43` | CS-2 override minima | (ii) | the toy passes no override |
| | `+522,57` | `check_constructed` | (ii) | `Shape::toy()` passes: windows `29` / `14` equal CS-2's minima; runs pure arithmetic |
| `timing.rs` | `332` | comment corrected (P-2) | (i) | text; **the digest moves** (`f3d0befd…` → `a91cbff1…`), so P-1's pin must be taken at the tip, not the snapshot's |

**Verdict:** every class (ii) hunk is the same for every admitted toy input.
There is no class (iii) hunk. At the re-pin, the D22 statement should:
1. list CS-3 as a refusal site that is unreachable for admitted witnesses
   (K-1 / K-2 text fixes first);
2. take `shape.rs` and `timing.rs` at the lane-tip digests.

K-4 does not touch D22: the toy's public API always builds `Shape::toy()`.

## 4. Further observations (not findings)

- **O-1: the run layer is dead code in a release build.** The release build
  warns "never used" for `RunShape`, `RunStatement`, `registered_block_shape`,
  `prove_run`, `RunVerifier::start`, `verify_run(_from_dir)`,
  `blocks_are_the_statements` and `verify_bytes_at`. So CS-6, CS-7 and the
  run-side CS-1/CS-4 exist only in test builds today. Their "fires before
  anything is absorbed" measurements are facts about test builds, which is
  the only place a run exists. Not a defect; recorded so that no one reads
  them as protections already shipped.
- **O-2: CS-8's layout re-check does not compare `io_mask_row`**
  (`layout.rs:1178`; this is documented). Any caller inside the crate can
  set it with `with_io_mask_rows` (`pub(crate)`). Every production caller
  derives it itself: `verify_inner_at` takes the default, and a run takes it
  from its statement.
- **O-3: note C-6's lower edge.** `f_e` 0–3 at rung-G's geometry are all
  admitted by `Shape::new` and CS-8, then refused by name by
  `Layout::for_shape` (*"this shape's A plane list is shorter than the
  pinned one"*). `f_e = 4` proves and is accepted. So 2 and 3, which stage
  40 never measured, produce no failing honest proof
  (`rv_c6_the_exp_scales_below_four_prove_or_are_refused_by_name`).
- **O-4: cost.** CS-3 adds a second pass over every looked word
  (`u8_misses_of`, about 98.6 M words at 125M, running in parallel above
  2^17). It could be folded into `byte_histogram_at`'s bin-0 filing at no
  cost. Not measured here; it is small beside the commitments. The
  statement re-checks, one per entry and one per shared body, re-run the
  P-2 support check over each block's weights: about 15 MB at 125M, a few
  milliseconds each, estimated.

## 5. What was NOT checked

- No 125M proof (by the box rule). 125M was covered by construction-level
  checks only.
- No quiesced timing; O-4 is an estimate.
- Stages 36–38 (`protocol.rs` and `private_block.rs` from the snapshot to
  `a9d6d4c`) are outside this delta.
- Not re-derived: the census's site list (checked on this branch at
  `cda7d05`). CS-3's "unreachable for admitted witnesses" rests on it plus
  the inputs sampled here.
- K-4's soundness side was not probed. Whether a cheating prover gains
  anything from the pad rule being off at a toy-profile-string shape was not
  tested. Only honest completeness was measured.
- The lane's failing-first logs were not re-run. Its `s40`–`s43` tests pass
  here as part of the gate below.
- The GPU feature build was not built.

## 6. Evidence

All under `results/zk60_s39_s43_review/`:

- `release-lib.log` / `.done` (0): the release library build without tests.
- `release-lib-scan.txt`: the scan of the release library (strings and `nm`).
- `rv-first.log`, `rv-tests.log` / `.done` (0): the review tests.
- `rv-k1-reproducer.log` / `.done` (101): K-1 alone.
- `reproducers.log` / `.done`: both ignored reproducers (K-1 and K-4).
- `gate-private.log` / `.done` (101): the first whole-filter run, with the
  two superseded census-check measurements failing.
- `gate-private2.log` / `.done` (0): the gate below.
- `gate-list.txt`: the 515 tests the filter selects.
- `census-check-ignored.log` / `.done` (101): the census check's ignored
  tests after the merge.
- `norm_window_check.{py,txt}`: the exact norm-window check.
- `sha256-a9d6d4c-f486e6f.txt`: the digests of the eight production files
  at both ends of the delta.

Attack tests: `hashline/src/private_block/s39_s43_review_tests.rs`, wired
by one `#[cfg(test)] mod` line: 6 ordinary tests and 2 ignored reproducers
(K-1, K-4).

**The gate on the merged review branch** (`gate-private2.log`, `.done` = 0):
`--lib private_`, 6 threads, **490 passed / 0 failed / 25 ignored**, 140.78 s
(3:35.67 wall with the build), peak RSS 4.28 GB.

- **The lane's own tests:** 479 / 0 / 18. This is exactly the lane's stage-43
  gate, and every name in it is present.
- **The review-branch-only tests:** 11 passed and 7 ignored —
  - this file: 6 passed, 2 ignored;
  - `census_check_tests`: 1 passed, 4 ignored;
  - `stage05_commit_split`: 4 passed, 1 ignored.

**The first gate run** (`gate-private.log`) failed 2 tests, both mine from
the census check (`cda7d05`): `c1_a_statement_built_at_another_shape_…` and
`c2_an_overridden_softmax_window_…`. These were written as "MEASURED, passes
today" records of the open C-1 and C-2 holes, and they now fail **because
the lane closed them**:
- the builder refuses C-1's statement by CS-1's name;
- `Shape::new` refuses `wrho_s = 15` by CS-2's name.

On this branch only, I marked both `#[ignore]`d as superseded; this is the
one edit outside the new file, and it is test-only. Run with `--ignored`
(`census-check-ignored.log`, 1 passed and 3 failed, as expected):
- **The C-1 reproducer now PASSES:** the statement is refused before any
  receipt exists, by CS-1 over S38-F1(a).
- **The C-2 reproducer** stops at its first line, because its premise — that
  `Shape::new` admits `wrho_s = 15` — is gone. CS-2 closes it the same way.
- **The two measurements** fail as described above.

`reproducers.log` (`.done` = 101): K-1 and K-4 fail as reproducers must.
