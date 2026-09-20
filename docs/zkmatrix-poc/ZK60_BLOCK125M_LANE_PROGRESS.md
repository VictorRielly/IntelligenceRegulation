# Lane `zk60-private-block-125m` — progress ledger

Worktree `/home/victor/wt-zk60-block125m`, branch `zk60-private-block-125m`,
opened from the shared branch tip `73d3398` on 2026-09-20. ONE writer (this
delegated implementer). Everything else on the box is read-only for this lane.

Parts A and B were **purely additive**. Since 2026-09-20 the lane also works
the change list of `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §9 — Codex has
confirmed the lane owns it, shared constants included. Stage 1 was S1, S2,
S4, S5 (S3 is a ruling, already made). **Stage 2 (2026-09-20 01:00–02:00) is
S6 and S7**; S8–S15 are later.

**Running list of *shared-file changes*** (files outside
`hashline/src/private_block*` and `hashline/src/private_attention*`), for the
hand-back to the integrator:

| file | commit | what |
|---|---|---|
| `private-block-kernel/src/lib.rs`, `src/shaped.rs` (new), `src/shaped_tests.rs` (new) | `cc94698` | S6 part 1: the reference kernel generalised over a shape; the fixed entry points became thin wrappers at `Shape::toy()`. It is a **dev-dependency** of `hashline` (`Cargo.toml:37-42`), so nothing enters the library or the binary. The one behavioural note is finding **S6-F3** below (`run_block`'s stack frame) |

Nothing else outside those two trees is edited.

## The two parts

| Part | What | Files |
|---|---|---|
| **A** (project id **U-4**) | the zero-witness acceptance test on the TOY profile as it is: the all-zero hidden input proves and the receipt verifies from bytes; the constants and the two range boundaries the paper trace rests on are asserted so a calibration change fails loudly | `hashline/src/private_block/zero_witness_tests.rs` (new) + ONE `mod` line in `hashline/src/private_block.rs` |
| **B** | an independent, shape-driven layout model in pure Python: padded domains, plane list, A/H/M totals, opening groups, slots and receipt bytes from a shape; reproduces the toy EXACTLY or it means nothing; then the rung and the 125M shape beside the memo's [COUNTED] figures | `scripts/zk60_private_block_layout_model.py`, `tests/test_zk60_private_block_layout_model.py` (both new) |

## Status

| Step | State | Evidence |
|---|---|---|
| A0 skeleton + ledger | DONE | this file, commit 1 |
| A1 zero-witness proves and verifies from bytes | DONE | `results/zk60_block125m_lane/partA-run1.log:113` |
| A2 constants + boundary assertions | DONE | `…partA-run1.log:114` |
| A3 receipt length equal; two proofs differ | DONE | `…partA-run1.log:115-116` |
| A4 whole module filter green, before and after | DONE | before: `partA-baseline.log:116` 36 passed / 0 failed / 1 ignored; after: `partA-run1.log:118` 40 passed / 0 failed / 1 ignored |
| B1 model module | DONE | `scripts/zk60_private_block_layout_model.py` |
| B2 toy reproduces exactly | DONE | `results/zk60_block125m_lane/pytests.log` (25 tests, OK); all 23 Rust-asserted toy numbers reproduced |
| B3 rung + 125M beside the memo | DONE | `results/zk60_block125m_lane/model_report.txt`, `model_{toy,rung,m125}.json` |
| B4 pad-table recount | DONE | `results/zk60_block125m_lane/pad_table_recount.json` |
| **S0 baseline on the merged tree** | DONE | `results/zk60_block125m_lane/s-baseline.log:138` — **58 passed / 0 failed / 2 ignored / 67 filtered out**, 27.74 s. The two ignored are the two `capture::native_capture_saved_receipt` gates (they need saved receipt paths). Toy receipt 2,816,472 B asserted by `private_block/tests.rs:108` and `zero_witness_tests.rs:172`, both in the pass list |
| **S1 split `U8_LEN` from `N`** | DONE | `…/s1-run2.log:140` — **61 passed / 0 failed / 2 ignored**; toy receipt still 2,816,472 B |
| **S2 free the witness and lookup buffers** | DONE | `…/s2-run1.log:140` — **61 passed / 0 failed / 2 ignored**; toy receipt still 2,816,472 B; digest gate held |
| **S4 lookup-summation repair** | DONE | failing first: `…/s4-failing-test.log:158-159` (the refusal, by name); repaired: `…/s4-run2-repaired.log:145` — **66 passed / 0 failed / 2 ignored**; toy receipt 2,816,472 B, digest gate held |
| **S5 shape-driven layout** | DONE | `…/s5-run2.log:151` — **72 passed / 0 failed / 2 ignored**; toy receipt 2,816,472 B, digest gate held; toy, rung and 125M totals all equal the Python model's |
| **S6 the reference kernel over a shape** | DONE | `…/s6-kernel-run2.log:22` — kernel crate **15 passed / 0 failed** (was 10); `…/s6-run1.log:152` — hashline **72 passed / 0 failed / 2 ignored**, toy unmoved |
| **S6 the witness builder over the same shape** | DONE | `…/s6-run3.log:160` — **72 passed / 0 failed / 2 ignored**; toy receipt 2,816,472 B, digest gate held |
| **S6 acceptance: witness parity AT THE RUNG** | DONE | `…/s7-run3.log:155` — **76 passed / 0 failed / 2 ignored**; 160 rung cases, **131 accepted by both, 29 refused identically**, 21 planes element for element on every true coordinate |
| **S7 grouped-query attention (group 3)** | DONE | failing first: `…/s7-failing-test.log:123` (`kr8` differs from the kernel in 14 of 768 elements) and `:103` (the grouping property); after: `…/s7-run1.log:118` — **6 passed / 0 failed** in the parity module |
| **S8 the two integer windows** | NOT STARTED | the boundary is named by the `check_plane_table` refusal (finding S6-F2) |

## The toy freeze gate this stage added

`Layout::new().schedule_digest()` is absorbed into the transcript, so if it
moves every toy receipt moves — and the only existing check on it
(`tests.rs:462`) compares the layout against a freshly built layout, so BOTH
sides move together and it cannot see a change. The lane therefore pins the
digest as a LITERAL, captured on the merged tree before any S-step edit:

```
70 38 84 a8 78 02 38 8a 24 6b 27 c8 d2 39 54 67
72 c1 e8 d3 a3 9b 59 2b b8 b0 0f 8b e2 1f 8b 8d
```

`grow_tests::the_toy_schedule_digest_is_frozen`. Every step S1..S15 must leave
it untouched; a new shape is a NEW profile beside the toy (D17), never an edit
of it.

## Commands run (every one, with its log)

The Rust command, in full, is always this one (one call, output appended to a
log under `results/zk60_block125m_lane/`, read narrowly afterwards):

```
flock -w 540 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target \
  CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 \
  /home/victor/.cargo/bin/cargo test --release --offline -j 2 \
  --manifest-path /home/victor/wt-zk60-block125m/hashline/Cargo.toml --lib private_block -- --test-threads=1
```

| # | Command | Log | Result |
|---|---|---|---|
| 1 | the Rust command above, BEFORE any edit (baseline) | `results/zk60_block125m_lane/partA-baseline.log` | 36 passed, 0 failed, 1 ignored, 81 filtered out, 18.31 s |
| 2 | the same, with `zero_witness_tests.rs` registered | `results/zk60_block125m_lane/partA-run1.log` | 40 passed, 0 failed, 1 ignored, 81 filtered out, 19.81 s — compiled and passed on the first attempt, no fix needed |
| 3 | `python3 -m unittest discover -s /home/victor/wt-zk60-block125m/tests -p 'test_zk60_private_block_layout_model.py' -v` | `results/zk60_block125m_lane/pytests.log` | 25 tests, OK (one earlier failure was the TEST's assumption, not the model — see B-F5) |
| 4 | `python3 /home/victor/wt-zk60-block125m/scripts/zk60_private_block_layout_model.py --all --out /home/victor/wt-zk60-block125m/results/zk60_block125m_lane` | `results/zk60_block125m_lane/model_report.txt` | the three shapes' JSON + the pad recount |
| 5 | the Rust command, filter `private_`, on the MERGED tree (S0 baseline) | `…/s-baseline.log` | 58 passed, 0 failed, 2 ignored, 67 filtered out, 27.74 s |
| 6 | the same, after S1 | `…/s1-run1.log` | 60 passed, 0 failed, 2 ignored, 27.77 s |
| 7 | filter `private_block::grow_tests`, to CAPTURE the toy schedule digest (a deliberately failing assertion) | `…/s1-digest-capture.log:86` | 2 passed, 1 failed — the digest read off the failure message |
| 8 | the Rust command, filter `private_`, after S1 + the digest pin | `…/s1-run2.log` | **61 passed, 0 failed, 2 ignored**, 27.87 s |
| 9 | the Rust command, filter `private_`, after S2 | `…/s2-run1.log` | **61 passed, 0 failed, 2 ignored**, 27.93 s |
| 10 | the Rust command with `--include-ignored <the S4 test>`, BEFORE the repair | `…/s4-failing-test.log` | the S4 test FAILS at `grow_tests.rs:163` with `"private block: claim parts with different column weights"`; the two other failures are the two `capture` gates that `--include-ignored` also runs |
| 11 | the Rust command, filter `private_`, with the S4 test still ignored | `…/s4-run1-ignored.log` | 63 passed, 0 failed, 3 ignored, 29.36 s |
| 12 | the Rust command, filter `private_`, after the S4 repair | `…/s4-run2-repaired.log` | **66 passed, 0 failed, 2 ignored**, 27.83 s |
| 13 | the Rust command, filter `private_`, after S5 | `…/s5-run1.log` | 71 passed, 1 failed — ONE difference against the Python model, `D_max` at 125M; the model is right (908,065) and the Rust test's literal was a typo. The layout itself agreed everywhere |
| 14 | the same, literal corrected | `…/s5-run2.log` | **72 passed, 0 failed, 2 ignored**, 27.90 s; 8 warnings, the same 8 the baseline had |
| 15 | the Rust command, filter `private_`, stage-2 baseline | `…/s6-baseline.log` | 72 passed, 0 failed, 2 ignored, 28.10 s |
| 16 | the kernel crate's own suite, same command shape, `--manifest-path …/private-block-kernel/Cargo.toml`, stage-2 baseline | `…/s6-kernel-baseline.log` | 10 passed, 0 failed (+1 ignored integration gate) |
| 17 | the kernel suite, after the `shaped` module | `…/s6-kernel-run1.log` | 10 passed, 0 failed — compiled and passed first attempt |
| 18 | the kernel suite, with the five new shaped tests | `…/s6-kernel-run2.log` | **15 passed, 0 failed** |
| 19 | the Rust command, filter `private_`, after the kernel change | `…/s6-run1.log` | **72 passed, 0 failed, 2 ignored**, 28.12 s |
| 20 | the same, after the shape-driven witness | `…/s6-run2.log` | 72 passed, 0 failed, 2 ignored, 30.08 s (one new unused-import warning, fixed next) |
| 21 | the same, import trimmed, grouping deliberately NOT yet applied | `…/s6-run3.log` | **72 passed, 0 failed, 2 ignored**, 28.19 s, 9 warnings — the baseline's 9 |
| 22 | filter `private_block::parity`, the rung tests BEFORE S7 (a deliberately failing run) | `…/s7-failing-test.log` | 3 passed, **2 failed** — `kr8` differs from the kernel in 14 of 768 elements; the grouping property fails on the first head |
| 23 | the same, after S7 | `…/s7-run1.log` | **6 passed, 0 failed**; 160 rung cases, 131 accepted / 29 refused by both |
| 24 | the Rust command, filter `private_`, after S7 | `…/s7-run2.log` | 76 passed, 0 failed, 2 ignored, 28.86 s (one new unused-variable warning, fixed next) |
| 25 | the same, warning cleared | `…/s7-run3.log` | **76 passed, 0 failed, 2 ignored**, 28.46 s, 9 warnings — the baseline's 9 |

## Findings

**A-F1 (PART A, the headline).** The all-zero hidden input is a valid witness
of the toy profile IN THE CODE, not only on paper: `witness::build` accepts
it, the honest prover produces a receipt, and that receipt verifies typed,
after a byte round trip, and through `verify_bytes`. **No refusal, nothing to
report as a failure.** The block output of the zero input is itself zero
(every stage annihilates), so the output endpoint commits a zero plane.

**A-F2.** The two boundary values the check found are reproduced exactly by
the module's own witness, and are now asserted with their limits:

| fact | plane(s) | value at the zero input | the limit it sits against | headroom |
|---|---|---:|---|---:|
| softmax remainder complement `sigma_s` | `A_SG0 + 256·A_SG1` | **16,383** | `sigma < 1 << WRHO_S = 16,384`, EXCLUSIVE (`witness.rs:298`) | **0** |
| softmax quotient `p` | `A_P` | **512** | `0 ..= 1 << F_P = 512`, INCLUSIVE (`witness.rs:298`) | **0** |

Both are asserted twice over: the value equals the boundary, and one more
would fall outside — so a one-bit change in `WRHO_S` or `F_E`, or turning the
inclusive quotient bound exclusive, fails this test rather than silently
invalidating the fixed input of the privacy argument.

**A-F3.** The two constants are asserted at their sources: `NORM_CEPS == 1`
(`layout.rs:54`), with `isqrt(NORM_CEPS) == 1` and the norm denominator
positive; and `exp[0] == 2^F_E` — not merely for this fixture, but as a
CONSTRUCTOR REFUSAL: `AttentionPublic::new` is shown to reject a statement
whose `exp[0]` is 0 (`private_block.rs:138`), which is what stops an
adversarially chosen public statement from destroying the fixed input.

**A-F4.** The receipt length does not move with the hidden input: the zero
witness's frame and the fixture witness's frame are both exactly 2,816,472 B,
and two proofs of the same zero witness differ in their bytes while both
verify (fresh OS randomness per attempt; the endpoint roots differ too, and
neither receipt verifies under the other attempt's endpoint policy).

**B-F1 (the model earns the right to be believed).** The model reproduces the
toy EXACTLY — all 23 numbers the Rust asserts about itself, none imported from
the crate: `A` data 213 / rows 455, `H` data 280 / rows 384, `M` 50, sites
120 / 51, opening groups 35 / 9, 23 slots and 34 functionals, 81 `A` planes
and 51 `H` planes, the per-domain U8 totals `[1024, 19456, 4608, 6656, 3072,
26624]` summing to 61,440, 2,048 exp and 512 act pairs, largest `L` 50, 159
main and 25 extension rounds, and a **2,816,472-byte** receipt. It also
reproduces the Rust's slot table `(main, ext, degree)` slot for slot and its
`A_SITES` / `H_SITES` arrays element for element.

**B-F2 (125M: no difference at all).** Every [COUNTED] figure of §2.4, §4,
§5 and §7.1 is reproduced: `A` 5,681 (5,435 data + 244 + 2), `H` 7,120
(7,018 + 100 + 2), `M` 50, sites 122 / 50, groups **36 / 9**, 98,598,912 U8
lookups (the memo's rider (a), i.e. the post-lift figure, not the 98,582,528
in its table body), largest `L` 117, and the receipt **part by part** —
`A` 21,626,880 + `H` 17,385,472 + endpoints 1,466,368 + `M` 243,712 + slots
27,456 + 136 = **40,750,024 B**, the memo's final figure. The memo's
alternative 40,747,256 B is its pre-lift, pre-support-factor variant (it
differs by exactly 752 + 2,016 B in the slot line) and the model does not
produce it.

**B-F3 (the rung: ONE difference, +176 B, diagnosed).** Every rung total of
§9a is reproduced — 83 / 52 planes, 377 / 470 data rows, 122 / 52 sites,
**623 / 576 / 50** rows, groups 36 / 9, 419,840 U8 lookups, 8,192 exp and
8,192 act pairs, largest `L` 72 at `SC_SZC` and `SC_FZC` — **except the
receipt: the model gives 4,173,208 B against the memo's 4,173,032 B.** The
whole difference is 176 B in the slot line, and its cause is named: the model
gives **`SC_KVZC` the support indicator**, because `Dom::Kv` pads at the rung
(768 true of 1,024) and §9a's own domain paragraph says it does — "the pad
rule of §3.7a is exercised on `Kv` and `F` as well (their indicators are
`supp_Kv` and `supp_F`)". An indicator is one more degree, i.e. one more
`Fp2` in each of that slot's 11 round messages: 11 × 16 B = 176 B. The memo
prices `SC_FZC`'s indicator and not `SC_KVZC`'s, and its open question 2
mentions only `SC_FZC`. **Either the rung receipt is 4,173,208 B, or `supp_Kv`
does not gate `SC_KVZC`'s inhomogeneous RoPE constraint and the domain
paragraph is wrong.** Nothing else moves: `SC_KVZC`'s `L` is 57 with the
indicator, far under the rung's largest 72, so the mask budget is untouched.
This is the only undiscussed difference the model found at any shape.

**B-F4 (the pad table of §3.7a, recounted from its own 40 rows).** The table
classifies **100 planes: 64 ZERO, 35 EXEMPT, 1 with no pad rule** (`H_U`, the
zero-sum masking pair, excluded by name). The editor's summary figures are
each true of a DIFFERENT population, which is why they do not add up:

| figure | what it actually counts | recount |
|---|---|---:|
| "62 planes" | `A` planes on the six padded domains | **62** ✓ |
| "61 proved zero" | those `A` planes ruled ZERO (the exception is `A_E`) | **61** ✓ |
| "35 exempt" | EXEMPT planes across BOTH commitments (`A_E` + 34 helpers) | **35** ✓ |

So `61 + 35 = 96 ≠ 62`: the three are not one tally. The `H` side is 38
planes (34 EXEMPT helpers, 3 ZERO table helpers, `H_U`). The table's own
claim "planes not classified here: none" CHECKS OUT: its per-domain,
per-commitment counts equal the model's 125M plane list exactly. **No plane
is missing and none is classified twice; only the summary sentence's
arithmetic is wrong.** Suggested replacement: "100 planes on six padded
domains — 64 proved zero, 35 exempt by name (the exponential pair and the 34
lookup reciprocals), and `H_U`, which carries no pad rule."

**B-F5 (a small memo/code fact worth recording).** `Dom::L` already pads AT
THE TOY: nine of its sixteen limb sub-planes carry the isqrt witness and
seven are empty (true 288 of a padded 512). The memo says so in passing
(§2.3, "its pad is not new"), but it means the toy is not a no-pad shape and
the pad rule of P-1 would apply to it the day it is written. `SC_LZC` is
homogeneous and takes no indicator, so no toy byte moves.

**B-F6 (B-3 reproduced independently).** Without the P-3 lift the LogUp sum
claim raises **three** distinct column-weight keys at both the rung —
`([],0,256)`, `([],0,512)`, `([],0,1024)`, exactly the three §9a predicts —
and at 125M (`([],0,256)`, `([],0,8192)`, `([],0,16384)`); with the lift,
one. At the toy it is one either way, so the lift is a no-op there, which is
what P-8's byte-identity gate needs. The model reports this as a separate
boolean, `logup_sum_claim_instantiable`.

**S1-F1 (one site of the memo's S1 list is classified wrongly, and the memo
contradicts itself about it).** §1.3 T-1 and the §9 S1 row both put
`argument.rs:898` — `SC_ZS`'s all-ones public vector — among the sites whose
`N` means "the size of the 256-entry lookup tables", i.e. they ask for
`U8_LEN`. **It is neither the table size nor the row width: it is the length
of `SC_ZS`'s own cube, `h_dom(H_U) = Dom::Tab`** (`layout.rs:242-251`, the
`_ =>` arm), and `run_slot`'s table-length check (`argument.rs:281-283`)
compares it against `1 << SLOTS[SC_ZS].0`. The memo's own §4.1 says so: with
the P-3 lift "`SC_TAB`'s and `SC_ZS`'s [main rounds go] 8 -> 14", which only
happens if that vector follows `Dom::Tab`, not a frozen 256. Written as
`U8_LEN` it would refuse the first proof at any shape where the lift moves
`Dom::Tab`. **Implemented as `Dom::Tab.len()`**, which is 256 at the toy — so
no byte moves — and grows with the lift at S4. The other ten sites are as the
memo lists them. Worth a one-line correction in §1.3 T-1 and the §9 S1 row.

**S1-F2 (what "byte-identical" can and cannot mean here).** A toy proof's
bytes differ run to run: `ZkRng::from_os` draws fresh randomness per attempt
(finding A-F4). The enforceable freeze is therefore *length* +
*schedule digest* + the whole test filter, and the only one of those three
that was not actually checked was the digest — `tests.rs:462` compares a
layout against a freshly built layout, so both sides move together. The lane
pinned it as a literal (above). That gate is what S4 and S5 are measured
against.

**S2-F1 (the drop had to change the signature, and that is the point).**
`prove_inner` took `wit: &Witness`. A borrowed witness cannot be released —
the memory stays alive in the CALLER's frame for the whole proof — so the
memo's "free the witness planes" is not expressible without taking the
witness BY VALUE. It now does; the six call sites (`private_block.rs`,
`tests.rs`, `norm_alias.rs`, three in `tamper.rs`) all pass `w` instead of
`&w` and none of them reads the witness afterwards, so nothing else moved.
Four buffers are released at the point C-11 identifies (after the `H_FACT`
helper column, the last read of both): `looked`, the witness planes, and also
`deltas` and `act_idx`, which die at the same line and are the +42 MB of pins
C-12 and M-7. Nothing new is allocated, so the peak can only fall.

**S2-F2 (the acceptance test the memo asks for is better served by the
compiler).** §9's S2 row wants "an assertion that both buffers are gone before
the first slot" and "a test that must fail if the drop is moved too early". In
Rust both are structural: the buffers are MOVED, so a read after the drop
point does not compile, and a drop moved earlier does not compile either. A
runtime assertion could only observe a pointer, not a release. This is
recorded as a deliberate substitution, not an omission. The remaining part of
the acceptance — "peak RSS of the toy example does not rise" — is not
measured here: at the toy the four buffers total about 2 MB, which is below
the run-to-run noise of this box, and the figure that matters (9.6 GiB against
11.0 GiB) is S14's, on a quiesced box.

**S4-F1 (the failure, reproduced before the fix, and how).** The module cannot
be instantiated at any geometry but the toy's until S5, so — as the brief
allows — B-3 is reproduced at the level of the claim-building and the opening
check, with a constructed layout. Three things make that honest rather than a
private re-implementation:

1. `part_key_at` and `opening_groups_at` are the REAL functions, now taking
   the row-width log as a parameter; `check_opening` calls them at `LOG_N`.
2. The claim reconstruction (`sum_claim_from_logs`) is shown to reproduce the
   module's own `logup_sum_claim(&Layout::new())` at the toy, part for part,
   in its own test.
3. The rung's nine natural domain logs come from §9a's own domain paragraph.

Before the repair the test failed with exactly
`"private block: claim parts with different column weights"`; after it, one
group. A second test, `the_unlifted_rung_sum_claim_raises_three_keys_and_is_refused`,
keeps the bug on the record permanently: the three keys are `([], 0, 256)`,
`([], 0, 512)`, `([], 0, 1024)` — §9a's three, and the Python model's (B-F6).

**S4-F2 (the repair's own risk is closed in one place).** Condition 1 of §4.1
— padded table positions must REPEAT an existing entry, or the byte range
proof admits `1 << LOG_N` values instead of 256 — is now a single rule shared
by all three tables: entry `i` is built from `i % U8_LEN`. It is tested at
three lengths (256, the rung's 1,024, 125M's 16,384) by the SET of values
each table proves, not by its length: the set must be the same 256 the
unlifted table proves, and 300 must not be in it. Condition 2 (padded
multiplicities are zero) holds structurally — `prove_inner` writes only
`0..U8_LEN` into a zero-initialised commitment — and the test pins the three
multiplicity planes to `Dom::Tab` so that a plane moved to another domain
would fail here.

**S5-F1 (the Rust and the Python agree at all three shapes, with ONE
exception that is the PYTHON's finding, not a new one).** The Rust
`shape::Shape` and the Python model were written from the same memo, three
weeks and one agent apart, and not from each other. Every total agrees:

| quantity | toy | rung | 125M |
|---|---:|---:|---:|
| `A` planes / `H` planes | 81 / 51 | 83 / 52 | 83 / 50 |
| `A` data rows / `A` rows | 213 / 455 | 377 / 623 | 5,435 / 5,681 |
| `H` data rows / `H` rows | 280 / 384 | 470 / 576 | 7,018 / 7,120 |
| claim sites `A` / `H` | 120 / 51 | 122 / 52 | 122 / 50 |
| opening groups `A` / `H` | 35 / 9 | 36 / 9 | 36 / 9 |
| largest slot `L` | 50 | 72 | 117 |
| main / extension rounds | 159 / 25 | 215 / 25 | 332 / 25 |
| U8 lookups | 61,440 | 419,840 | 98,598,912 |
| exp / act pairs | 2,048 / 512 | 8,192 / 8,192 | 4,194,304 / 1,048,576 |
| **receipt** | **2,816,472** | **4,173,208** | **40,750,024** |

The one exception is the RUNG RECEIPT, and it is finding B-F3 unchanged: the
Rust gives 4,173,208 B where §9a's table says 4,173,032 B, for exactly the
same reason the Python did — `SC_KVZC` carries a support indicator because
`Dom::Kv` pads at the rung, which §9a's own domain paragraph requires and its
table does not price. **Two independent implementations now say the memo's
rung receipt line is 176 B light.** That remains a question for the security
owner, not a defect: either the rung receipt is 4,173,208 B, or `supp_Kv`
does not gate `SC_KVZC`'s inhomogeneous RoPE constraint. The 125M receipt is
reproduced PART BY PART against §7.1 — `A` 21,626,880 + `H` 17,385,472 +
endpoints 1,466,368 + `M` 243,712 + slots 27,456 + 136.

One literal in the Rust TEST was wrong on the first run (`D_max` at 125M,
908,079 instead of 908,065) and the model caught it. That is the oracle
working: the disagreement was in the transcription, not in either layout.

**S5-F2 (what S5 did NOT do, so the next agent does not assume it).**
`Layout::new` now builds the toy's row geometry from `Shape::toy()` and
asserts the result against every frozen toy constant, so the two cannot
drift. But **only the LAYOUT is shape-driven.** The argument is not: the
witness builder, the claim points, the RoPE tables, the causal mask, the
`limb_off` stride and `h_u_rows` still read the toy's `T`, `D`, `N` literals,
and `describe()` (whose digest is transcript-bound) is still the toy's text.
There is deliberately NO `Layout::for_shape(&other)`, because a half-general
`Layout` would be a trap. Making the argument shape-driven is S6..S11.
`Shape::rung()` and `Shape::m125()` exist as counted layouts and as distinct
profile ids; nothing is proved at either.

**S5-F3 (the construction refusals trap T-2 asks for now exist, by name).**
`Shape::new` refuses a zero axis, a head dimension that is not a power of two
(T-8's `cf[log - log2(dh)]`), a padded width that is not a power of two
(T-2), `d_pad != h_pad * head_dim` (the `Q`/`D` coincidence) and query heads
that do not divide into the key-value heads. Each is a named `Err`, tested by
its string. The prover panic T-2 describes (`fold_rows_i8`'s
`assert_eq!(w.len(), rows)`) is not yet replaced at the call site — that is
S5's construction-time half done and S7's argument-side half still open.

**S6-F1 (the kernel already had the group; the witness did not — and only a
real second key-value head could tell).** `private-block-kernel::run_block`
has carried `let group = H / HKV; let kvo = (h / group) * DH;` since it was
written, so its grouped-query attention was correct all along. The witness
builder did NOT: it called `rotate(&k8, 1, ..)` and indexed `kr8[j * KV + i]`
and `v8[j * KV + i]` with no key-value offset. At the toy `HKV = 1` makes the
two identical, which is why 1,200 parity cases never saw it. The rung is the
first shape at which they differ, and they differ at the FIRST plane the
key-value rotation touches: `kr8`, 14 of 768 elements on case 0
(`s7-failing-test.log:123`). **The lesson for the remaining steps: a literal
that happens to equal 1 at the toy is invisible to every toy test, however
many cases it runs.** The memo's pin list is the only inventory of them.

**S6-F2 (what S6 deliberately does NOT generalise, and the refusal that says
so).** The `A_*` plane ids of `layout.rs` are LITERAL indices, and the plane
LIST moves with two of the shape's windows: `limbs_norm` (the norm remainder,
four bytes at the toy, the rung and 125M) and `limbs_sigma_s` (the softmax
remainder, TWO at the toy and at the S6 rung fixture, **three** at
`Shape::rung()`'s `F_E = 12` and at 125M). A third `sigma_s` limb adds two
planes to `Dom::S` and so shifts every id above `A_SG1`. Rather than let a
shape silently write the wrong planes, `witness::check_plane_table` refuses by
name — *"private block: this shape's A plane list differs from the pinned
one"* — and the rung parity fixture therefore uses the rung's GEOMETRY at the
toy's softmax calibration (`F_E = 9`, at which `Sum <= 24 * 512 = 12,288`
still fits `2^14`). **Moving that refusal is the first thing S8 has to do**;
the geometry work S6 and S7 are about is orthogonal to it and is complete.
Note the rung fixture's own profile id
(`hashline-zk-mr1/private-block-rung-t24-parity/1`) is distinct from
`Shape::rung()`'s, as D17 requires; neither proves anything.

**S6-F3 (a real, small cost to the kernel, for the security owner and for
whoever owns the zkVM image).** Making the kernel shape-driven without
allocating means the general path takes ONE flat scratch buffer, and
`run_block` — the fixed toy entry point — puts that buffer plus the trace
buffer in its own stack frame. Before, the compiler could overlap the dozen
fixed arrays whose lifetimes do not overlap; a flat buffer cannot be
overlapped. The toy scratch is 14,624 `i64` = **117 KB**, and the trace a
further 8,928 `i64` = 71 KB when a trace is asked for. Natively this is
nothing. In a RISC Zero guest it is not nothing, and the crate's stated
purpose is to run unchanged there. **Mitigation is already in the API and
costs no work:** a guest calls `shaped::run_shaped` with buffers of its own
(a `static mut`, a heap block, or a reused arena) instead of `run_block`, and
the two sizes are exported as `TOY_SCRATCH_I64` / `TOY_TRACE_I64`. No caller
in this repository is affected — `hashline` takes the crate as a
DEV-dependency and every use is a native test — but `private-model-kernel`
and `zkvm-block/model` reference the crate in their own documentation and
should be told. **This is the one thing in stage 2 that is worth a ruling.**

**S6-F4 (the pad is zero, and that is a fact, not an argument).** Every
witness plane is now exactly its padded domain's length, and every position
outside the true support is left at ZERO — including `A_E`, which memo
§3.7a's table lists as EXEMPT from the pad-zero rule. The rung parity test
asserts the all-zero pad on all seven padded domains as a *description of
today's builder*, so that S9 either keeps it or changes it deliberately. It
is **not** a claim that a zero pad is sound: nothing yet CONSTRAINS the pad,
which is exactly blocking item B-1, and it is why no receipt can be produced
at a padded shape before S9.

**S6-F5 (what can and cannot be exercised at the rung today).** CAN: the
integer witness, element for element against the reference kernel, on every
true coordinate of 21 planes; the refusal sites and their order; the
no-wraparound bounds of §3; the layout totals (S5); the grouping, as a
property. CANNOT, and no test pretends otherwise: an honest rung PROOF,
because the pad is unconstrained (S9), the row geometry is still the toy's
`log_cols = 8` (S10) and the endpoints are one-block (S11). The argument is
still instantiable only at the toy (S5-F2 unchanged) — the one S7 site that
reaches it, `rope_tables`, is now shape-driven and is tested as a pure
function at both shapes. **No `#[ignore]`d end-to-end rung test was left
behind**, deliberately: an ignored test that cannot even be constructed is a
worse marker than this paragraph and the `check_plane_table` refusal. The
next agent adds the end-to-end rung gate when S9–S11 make it constructible.

**S6-F6 (the rung sweep's own numbers, for whoever tunes it next).** 160
cases on a 8 x 4 x 5 band/gain/input grid with an independent feed-forward
band: **131 accepted by both, 29 refused identically by both**, across six
sites (`Q` 3, `K` 1, `QR` 1, `FFN gate` 2, `residual 1` 3, `residual 2` 19).
The band is narrower than the toy's ([0, 1, 2, 4, 8, 16, 48, 127] against the
toy's thirteen values up to 127) for a counted reason: at 96 inputs per
accumulation instead of 16, a full off-diagonal band leaves the int8 class
six times sooner, and a wider band would turn the whole sweep into `score`
refusals and prove nothing about the accepted path.

**No disagreement between the memo's rules and `layout.rs` was found at the
toy shape**: every rule the memo states reproduces the Rust's own numbers.
The differences above are all at shapes that do not exist yet.

Nothing is written outside this worktree, and no witness value, salt or
private plane appears in any evidence file: counts, sizes, booleans and
digests only. A zero-witness proof that verifies is a PRECONDITION for the
privacy argument, not a privacy result.

## NEXT

**S1, S2, S4, S5, S6 and S7 are done and green: 76 passed / 0 failed / 2
ignored on `--lib private_` (`s7-run3.log:155`) and 15 passed / 0 failed on
the kernel crate (`s6-kernel-run2.log:22`). The toy receipt is 2,816,472 B
and the pinned schedule digest has not moved at any commit of either
stage.**

The next agent takes **S8, the two integer windows**, and the FIRST thing it
does is read **S6-F2**: the `A_*` plane ids are literal, the plane list moves
with `limbs_sigma_s`, and `witness::check_plane_table` refuses any shape whose
list differs from the pinned one. S8 has to move that boundary, in this
order:

1. **The softmax window** (`WRHO_S 14 -> 18`, memo §3.8 row 10): a third
   `sigma_s` limb is **+2 planes on `Dom::S`**, which shifts every `A_*` id
   above `A_SG1` (`A_G8` .. `A_MACT`) and every range in `layout::a_dom`.
   Make the ids shape-derived (or add the two planes and re-pin), then
   `check_plane_table` can accept `Shape::rung()` itself and the rung parity
   fixture `parity::rung_parity_shape()` can be retired in favour of it. The
   failing test to write first is the honest rung witness at `F_E = 12`,
   which refuses today with *"softmax quotient/remainder"* because
   `Sum <= 24 * 2^12 = 98,304 > 2^14`. Also needs `scaled(l2, 64)`.
2. **The norm window** (`NORM_WRHO 29 -> 32`, row 9) with the norm-range
   lane's direct byte-limb pins in `private_block/norm_alias.rs` and ruling
   P-5 (`wrho` 29, THREE limbs for `D`). The witness and the kernel ALREADY
   take `norm_wrho` from the shape (S6), and the rung's honest 31 is asserted
   by `the_memo_section_three_bounds_hold_at_the_rung`; what is left is the
   ARGUMENT side — the four `1 << (32 - wrho)` coefficient rewrites
   (`layout.rs:344`, `:346`, `:348`, `:352`-`:363`), dropping the four
   redundant `scaled` lookups when the top limb is full (C-6,
   `Shape::norm_top_is_full_byte`), and the module's integer premise text.
   Note row 9's margin is **0.21 bits** at 125M.
3. The norm-range lane `zk60-private-norm-range` is a PREREQUISITE of the
   norm half (P-5) and its alias tamper tests are the non-negotiable
   acceptance (D16 item 6).

Then S9 (the pad rule — and see **S6-F4**: the pad is zero today and nothing
constrains it), S10 (the column count), S11 (the endpoints), after which
S12's end-to-end rung gate becomes constructible for the first time (**S6-F5**
says exactly what is and is not exercisable before then).

**One ruling is waiting on the security owner from this stage: S6-F3** — the
kernel's fixed `run_block` now carries a 117 KB scratch buffer (plus 71 KB
for a trace) in its stack frame, where the compiler used to overlap the
fixed arrays. It is nothing natively and not nothing in a zkVM guest; the
mitigation is already in the API (`shaped::run_shaped` with caller buffers,
sizes exported as `TOY_SCRATCH_I64` / `TOY_TRACE_I64`) and no caller in this
repository is affected, but `private-model-kernel` and `zkvm-block/model`
name the crate and their owners should hear it.

Four items from stage 1 are still waiting and none of them blocks S8:
S1-F1 (a one-line correction to §1.3 T-1 and the §9 S1 row: `argument.rs:898`
is `Dom::Tab.len()`, not the table size), S5-F1 / B-F3 (the 176-byte
rung-receipt difference two independent implementations report against §9a's
table), S3's decision 2 (it changes the 125M `Dom::D` lookup list and so the
`H` row total, C-6 — `Shape::lookups_per_position` is where it lands), and
**S6-F3** above.
