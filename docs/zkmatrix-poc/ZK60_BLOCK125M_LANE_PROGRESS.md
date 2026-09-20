# Lane `zk60-private-block-125m` — progress ledger

Worktree `/home/victor/wt-zk60-block125m`, branch `zk60-private-block-125m`,
opened from the shared branch tip `73d3398` on 2026-09-20. ONE writer (this
delegated implementer). Everything else on the box is read-only for this lane.

Parts A and B were **purely additive**. Since 2026-09-20 the lane also works
the change list of `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §9 — Codex has
confirmed the lane owns it, shared constants included. Stage 1 was S1, S2,
S4, S5 (S3 is a ruling, already made). **Stage 2 (2026-09-20 01:00–02:00) is
S6 and S7, plus the PREPARATION of S8** (both windows reproduced as
failures; the change itself is not made). S8's change and S9–S15 are later.

**Running list of *shared-file changes*** (files outside
`hashline/src/private_block*` and `hashline/src/private_attention*`), for the
hand-back to the integrator:

| file | commit | what |
|---|---|---|
| `private-block-kernel/src/lib.rs`, `src/shaped.rs` (new), `src/shaped_tests.rs` (new) | `cc94698` | S6 part 1: the reference kernel generalised over a shape; the fixed entry points became thin wrappers at `Shape::toy()`. It is a **dev-dependency** of `hashline` (`Cargo.toml:37-42`), so nothing enters the library or the binary. The one behavioural note is finding **S6-F3** below (`run_block`'s stack frame). **WITHDRAWN by job K** — see the row below |
| `private-block-kernel/src/lib.rs` | `2b0ebc4` | **JOB K: restored byte for byte to its content at `11c01b2`.** The crate is compiled into the zkVM guest, so it is frozen. `src/shaped.rs` and `src/shaped_tests.rs` are no longer referenced by it and **await deletion by the orchestrator** (this lane has no delete permission) |
| `hashline/Cargo.toml`, `hashline/Cargo.lock` | `2b0ebc4` | JOB K: the new crate registered as a second **dev-dependency**. Nothing enters the library or the binary |
| `private-block-kernel-shaped/` (new crate: `Cargo.toml`, `README.md`, `src/lib.rs`, `src/tests.rs`) | `fd72f48` | JOB K: the shape-driven kernel, moved out of the frozen crate. Standalone (`[workspace]`), no dependencies, and deliberately **not** a dependent of `private-block-kernel`, so the frozen crate stays a leaf the guest compiles alone |

Nothing else outside those two trees is edited.

## JOB K — un-sharing the reference kernel (security owner's ruling, 2026-09-20)

**The ruling.** Stage 2's commit `cc94698` generalised `private-block-kernel/`
IN PLACE. That crate is a dependency of `zkvm-block/model` and
`private-model-kernel` and is compiled into the project's **zkVM guest**,
whose image identity is an approved, recorded artifact of the other proving
line — and finding **S6-F3** had already noticed one behavioural consequence
(a 117 KB stack frame) that matters only there. The crate must therefore be
**byte-identical to `11c01b2`**, and the shape-driven kernel lives in a new
crate beside it.

**What was done**, in three commits:

| # | commit | what |
|---|---|---|
| K1 | `fd72f48` | `private-block-kernel-shaped/` created: `shaped.rs`'s content plus the `calib` table, `KernelError`/`Display` and the scalar primitives it used to import (`add`, `sub`, `mul`, `shl`, `requant`, `isqrt`) — **copied**, because the new crate may not depend on the frozen one. `no_std`, `forbid(unsafe_code)`, no dependencies, no allocation. Its five tests are stage 2's five (`k1-shaped-crate.log`: **5 passed / 0 failed**) |
| K2 | `2b0ebc4` | **SHARED FILES.** `private-block-kernel/src/lib.rs` restored from `git show 11c01b2:<path>`, not re-typed; `hashline/Cargo.toml` + `Cargo.lock` register the new crate as a dev-dependency |
| K3 | `7b2f1b3` | `parity.rs`'s shaped path repointed at the new crate, and the **cross-parity tests** added |

**Acceptance, item by item.**

* `git diff --stat 11c01b2 -- private-block-kernel private-model-kernel
  zkvm-block` prints **exactly two paths, both awaiting deletion**:
  `private-block-kernel/src/shaped.rs` and
  `private-block-kernel/src/shaped_tests.rs`. The restored `lib.rs` declares
  neither module, so neither enters the build; they are inert until the
  orchestrator deletes them. Nothing under `private-model-kernel/` or
  `zkvm-block/` is touched at all.
* The frozen crate's own suite is back to its `11c01b2` counts:
  **10 passed / 0 failed**, plus the 1 ignored integration gate
  (`k2-frozen-crate.log`), against `s6-kernel-baseline.log`'s identical 10.
* `private-model-kernel`: **19 passed / 0 failed** (`k3-model-kernel.log`),
  unchanged.
* hashline `--lib private_`: **82 passed / 0 failed / 3 ignored**
  (`k4-hashline.log:165`), 9 warnings — the baseline's 9. Toy receipt
  2,816,472 B and `the_toy_schedule_digest_is_frozen` both in the pass list.

**The cross-parity gate (acceptance item 4), and why it is the load-bearing
part of the split.** The copy of `calib` and of the primitives is the one way
this split could silently change what either kernel computes. `parity.rs` is
the only file in the repository that sees BOTH crates, so the guard lives
there:

| test | what it compares |
|---|---|
| `the_shaped_kernel_equals_the_frozen_kernel_at_the_toy` | all **1,200** toy fixture cases at `Shape::toy()`: the same verdict, the same refusal STRING, and all **23 trace planes element for element** — on refused cases too, since both traces are filled progressively in the same order. **905 accepted by both crates, 295 refused identically** (`k5-crossparity-counts.log:75`), which are the memo's own S6 acceptance figures |
| `the_shaped_crate_copies_the_frozen_calibration_exactly` | 27 `calib` constants, one assertion each |
| `the_shaped_crate_copies_the_frozen_primitives_exactly` | `isqrt` on 700+ values (every power-of-two neighbourhood, both `u64` edges, the 125M-scale norm values); `requant` at ten shifts x thirteen accumulators including `i64::MIN`/`MAX`, results **and** refusal strings; both matmuls at the toy row count; `softmax_row` against `softmax_row_into` on twenty rows, accepts and refusals |

**K-F1 (what the split cost, and the one visibility widening).** Five items
are `pub` in the new crate — `matmul_out_in`, `matmul_in_out`, `requant`,
`isqrt`, `softmax_row_into` — because each has a `pub` counterpart in the
frozen crate and the cross-parity test compares them function for function,
not only end to end. `rms_norm` and `rotate` are private in the frozen crate,
have nothing to compare against, and are `pub(crate)`. Nothing else moved
visibility, and no hashline item was made `pub`.

**K-F2 (finding S6-F3 is now moot for the guest, and stands for the new
crate).** The 117 KB scratch frame S6-F3 reported was a consequence of
`run_block` delegating to the flat-buffer path. With `lib.rs` restored,
`run_block` is again the fixed-array implementation the guest has always
compiled, so **the zkVM image is unaffected and the ruling S6-F3 asked for is
no longer needed for it.** The flat-buffer cost remains a property of
`private-block-kernel-shaped::run_shaped`, which no guest compiles.

**PATHS AWAITING DELETION BY THE ORCHESTRATOR** (this lane has no delete
permission, and emptying a file was rejected as a substitute):

```
private-block-kernel/src/shaped.rs
private-block-kernel/src/shaped_tests.rs
```

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
| **S8 preparation: both windows reproduced as failures** | DONE | `…/s8-run4.log:158` — **79 passed / 0 failed / 3 ignored**; the norm and softmax windows each refuse an honest rung witness by name at the toy's setting and accept at the rung's; the deliverable is captured failing in `…/s8-ignored-test.log:82` |
| **JOB K un-share the reference kernel** | DONE | `fd72f48`, `2b0ebc4`, `7b2f1b3`; see the JOB K section below. Frozen crate back to 10/0 (+1 ignored), `private-model-kernel` 19/0, hashline **82 / 0 / 3** (`k4-hashline.log:165`), toy unmoved. TWO PATHS AWAIT DELETION |
| **S9 the pad rule (P-1)** | **PREPARED** — both acceptance tests reproduced as failures, the specification built, the TERM NOT BUILT | `f3ce0ba`; see the S9 section. `s9-pz-failing.log:83,:89`; spec `s9-pad1.log:85` 6/0/2; filter `s9-run1.log:172` **92 / 0 / 4** |
| **S9 part 1 — the head permutation (S9-F2)** | **DONE** | `2798148`; `s9b-compile2.log:203` is the deliberate failing run (2 failed: the plane the kernel disagrees with, and the rung test's own head index); `s9b-run2.log:178` **97 / 0 / 4** |
| **S9 part 2 — the profile gate (S9-F1)** | **DONE** | `2798148`; `Shape::carries_pad_rule`, tested including a shape with the TOY'S geometry under a new profile id |
| **S9 part 3 — ruling P-2, the public weights** | **DONE** | `2798148`; both §9a cases refused by name, plus the folded-vector form |
| **S9 part 3b — the indicators (S9-F3) and the slot budget** | **DONE** | `2798148`; the table is the definition, the closed forms are asserted equal to it where they exist, `L + 256 <= 512` re-asserted at all three shapes |
| **S9 part 4 — the pad-zero term itself** | **NOT BUILT** — it lives in `argument::define`, which is still toy-only; it is blocked by stage 3's step 2 (the shaped argument), not by anything in S9 | see the NEXT section |
| **Shaped argument, step A — the H plane id map** | **DONE** | `0493be3`; `s9b-hids2.log:179` **98 / 0 / 4**. Built and tested, NOT wired into `argument.rs` / `protocol.rs` |
| **Shaped argument, step B — `Layout::for_shape`** | **DONE** | `a6ed423`; `s5b-run2.log:180` **99 / 0 / 4**. The layout owns its `Shape`, `Ids` and `HIds`; `Layout::new()` is `for_shape(&Shape::toy())` plus the frozen assertions. `describe()` byte-identical FIRST TRY, its six header lines now pinned verbatim on top of the digest pin |
| **Shaped argument, step C part 1 — the shaped `define`** | **DONE** | `522b9c3`; `s5c-run2.log:181` **100 / 0 / 4**. Every toy literal gone from the 23 slot definitions; new sweep test builds all 23 at the toy AND at the rung and pins trap T-3 |
| **Shaped argument, step C part 2 — the shaped `protocol` (and `wire`)** | **DONE** | `0dfdeb4`; `s6c-run1.log:185` **104 / 0 / 4**. Every line of the inventory ticked off (checklist in the stage 6 section); `prove_inner_at` / `verify_inner_at` are the shaped pair and the old pair is each at `Shape::toy()` |
| **S10 — the rung's PCS parameters** | **DONE** (it fell out of step C part 2) | `0dfdeb4`; `pcs_params_at` is `log_cols` / `inv_rate` / `opened_cols`, asserted 8/8/256, **10/4/256**, 14/4/256 at the three shapes, with the pad count equal to the opened-column count |
| **The hash layer's code conditions C-H1 / C-H4 / C-H4′ / C-H8** | **DONE** | `dcaec94`; `s6d-run2.log:188` **107 / 0 / 4**. C-H4 is a refusal inside `Layout::for_shape` (every shape); C-H4′ scans the module's own source; finding **C2-F1** recorded |
| **S9 part 4 — the pad-zero term itself** | **DONE** | `793c943`; `s9d-run2.log:188` **109 / 0 / 2** (PZ-1 and PZ-2 un-ignored). See stage 7 |
| **S11a — the rung endpoints on the frozen seam** | **DONE** | `513a4ec`; the three ruled edits, `Shape::rung()`'s endpoint numbers corrected to 21 rows / inverse rate 8, the per-profile wire bound, receipt 4,218,264 B |
| **S12a — the rung END TO END** | **DONE** | `513a4ec`, `9a2b559`; **an honest rung proof VERIFIES FROM BYTES** — prove 0.49 s, verify 0.10 s, frame 4,218,264 B, peak RSS 74 MiB. `s12a-filter4.log:203` **116 / 0 / 2** |
| **S11b, S12b (the tamper battery's remaining arms, a rung capture)** | **NOT STARTED** | see the stage 7 NEXT |
| **S8 the change itself** | **DONE** | `7f8e549` (the ids, the lookups, the premise) and `a21ffd7` (P-5's alias cases, the parity fixture retired). The deliverable test `the_rung_at_its_own_calibration_has_an_honest_witness` is un-ignored and green; hashline **86 / 0 / 2** (`s8-run7.log:165`), toy receipt 2,816,472 B and the digest unmoved |

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
| 26 | filter `private_block::grow_tests`, the S8 preparation tests, first attempt | `…/s8-run1.log` | 3 compile errors — `Witness` has no `Debug` on purpose (its planes are secret), so `expect_err` is not available |
| 27 | the same, the two outcomes matched by hand | `…/s8-run2.log` | 16 passed, **1 failed** — the norm window test did NOT refuse: at \|x\| about 2,000 the toy's 29-bit window IS enough at width 96. The test's input, not the code, was wrong |
| 28 | the same, the input magnitude chosen and its reason written down | `…/s8-run3.log` | **17 passed, 0 failed, 1 ignored** |
| 29 | filter `…::the_rung_at_its_own_calibration_has_an_honest_witness`, `--include-ignored` (a deliberately failing run) | `…/s8-ignored-test.log:82` | **1 failed** — *"S8: the rung's own calibration must have an honest witness, got `private block: this shape's A plane list differs from the pinned one`"* |
| 30 | the Rust command, filter `private_`, after the S8 preparation | `…/s8-run4.log` | **79 passed, 0 failed, 3 ignored**, 29.43 s, 9 warnings |
| 31 | the same command shape, `--manifest-path …/private-model-kernel/Cargo.toml` — the OTHER consumer of the kernel crate, to check the shared-file change broke nothing | `…/s8-model-kernel.log` | **19 passed, 0 failed** |
| 32 | the same shape, `--manifest-path …/private-block-kernel-shaped/Cargo.toml` (JOB K, the new crate) | `…/k1-shaped-crate.log` | **5 passed, 0 failed** |
| 33 | the same shape, `--manifest-path …/private-block-kernel/Cargo.toml`, after the restore | `…/k2-frozen-crate.log` | **10 passed, 0 failed** (+1 ignored gate) — the `11c01b2` counts |
| 34 | the same shape, `--manifest-path …/private-model-kernel/Cargo.toml`, after the restore | `…/k3-model-kernel.log` | **19 passed, 0 failed** |
| 35 | the Rust command, filter `private_`, after all of JOB K | `…/k4-hashline.log` | **82 passed, 0 failed, 3 ignored**, 30.44 s, 9 warnings |
| 36 | filter `…::the_shaped_kernel`, `--nocapture`, to read the cross-parity split off the test's own line | `…/k5-crossparity-counts.log:75` | 905 accepted by both crates, 295 refused identically |
| 37 | filter `private_block::grow_tests`, first attempt at the S8 ids | `…/s8-compile1.log:109` | 16 passed, **1 failed** — the plane-table refusal no longer fires, exactly as intended; the old test had to become a test of the MAP |
| 38 | the same, the test rewritten and the deliverable un-ignored | `…/s8-compile2.log:104` | **19 passed, 0 failed, 0 ignored** |
| 39 | the Rust command, filter `private_`, after S8's ids, lookups and premise | `…/s8-run5.log:170` | **84 passed, 0 failed, 2 ignored**, 29.98 s |
| 40 | filter `private_block::norm_alias`, after the two P-5 cases | `…/s8-alias1.log:98` | **7 passed, 0 failed** (was 5) |
| 41 | filter `private_block::parity`, `--nocapture`, the sweep moved to `Shape::rung()` | `…/s8-parity-rung.log:110` | **9 passed, 0 failed**; 160 rung cases, 131 accepted by both, 29 refused identically |
| 42 | the Rust command, filter `private_`, after all of S8 (two new warnings) | `…/s8-run6.log:178` | 86 passed, 0 failed, 2 ignored, 11 warnings |
| 43 | the same, the two warnings cleared | `…/s8-run7.log:165` | **86 passed, 0 failed, 2 ignored**, 28.74 s, 9 warnings — the baseline's 9 |
| 44 | filter `private_block::pad`, the S9 specification | `…/s9-pad1.log:85` | **6 passed, 0 failed, 2 ignored** |
| 45 | filter `…::pad::tests::pz`, `--include-ignored` (a deliberately failing run) | `…/s9-pz-failing.log:83, :89` | **2 failed** — PZ-1 and PZ-2, each with its own message |
| 46 | the Rust command, filter `private_`, after the S9 preparation | `…/s9-run1.log:172` | **92 passed, 0 failed, 4 ignored**, 28.70 s, 9 warnings |
| 47 | the Rust command, filter `private_`, on the JOB-K4 tip (stage-4 baseline) | `…/s9b-baseline.log:172` | **92 passed, 0 failed, 4 ignored**, 28.91 s, **8 warnings** |
| 48 | the same, the head-permutation expectation written FIRST (a deliberately failing run) | `…/s9b-compile2.log:203` | 91 passed, **2 failed** — the rung honest-witness test at its own head index, and `parity`: *"case 0: plane q8 differs from the kernel in 90 of 2304 elements (first at index Some(48))"*, i.e. exactly the 3 of 6 query heads the permutation moves |
| 49 | the same, the permutation landed | `…/s9b-compile3.log:183` | **93 passed, 0 failed, 4 ignored**, 29.28 s |
| 50 | the same, with P-2 and the indicator/slot tests (a deliberately failing run: the folded-vector test had `Wq`'s inner axis wrong) | `…/s9b-compile4.log:207` | 96 passed, **1 failed** — *"Wq: the folded weight is nonzero at unsupported input index 48"*, which is the test asserting `Wq`'s INPUT axis is `Dom::Q`; it is `Dom::D` |
| 51 | the same, corrected | `…/s9b-run1.log:195` | **97 passed, 0 failed, 4 ignored**, 29.12 s, 9 warnings (one new unused variable) |
| 52 | the same, the warning cleared | `…/s9b-run2.log:178` | **97 passed, 0 failed, 4 ignored**, 29.09 s, **8 warnings — the baseline's 8** |
| 53 | `git --no-pager diff --stat 11c01b2 -- private-block-kernel private-model-kernel zkvm-block` | — | **empty**: JOB K's acceptance is now literally met (the orchestrator's K4 deleted the two leftover paths) |
| 54 | the Rust command, filter `private_`, with `HIds` (step A) | `…/s9b-hids1.log:187` | 98 passed, 0 failed, 4 ignored, 29.26 s, 9 warnings (one new unused `mut`) |
| 55 | the same, the warning cleared | `…/s9b-hids2.log:179` | **98 passed, 0 failed, 4 ignored**, 31.50 s, **8 warnings — the baseline's 8** |
| 56 | **stage 5 baseline**, the Rust command, filter `private_` | `…/s5-baseline.log:178` | **98 passed, 0 failed, 4 ignored**, 29.16 s, 8 warnings |
| 57 | the same, after step B (`Layout::for_shape`), before its test | `…/s5b-run1.log:200` | 98 passed, 0 failed, 4 ignored, 29.34 s; the frozen digest test in the pass list, so `describe()` was byte-identical FIRST TRY |
| 58 | the same, with step B's test | `…/s5b-run2.log:180` | **99 passed, 0 failed, 4 ignored**, 29.28 s, **8 warnings — the baseline's 8** |
| 59 | the same, after step C part 1 (the shaped `define`), before its test | `…/s5c-compile1.log:194` | 99 passed, 0 failed, 4 ignored, 29.14 s, 9 warnings (one new unused `p3`) |
| 60 | the same, with step C's slot sweep at the toy and the rung | `…/s5c-run1.log:187` | **100 passed, 0 failed, 4 ignored**, 29.30 s, 9 warnings (`causal_mask` now unused) |
| 61 | the same, the toy's literal `causal_mask` kept as an oracle and asserted | `…/s5c-run2.log:181` | **100 passed, 0 failed, 4 ignored**, 29.25 s, **8 warnings — the baseline's 8** |
| 62 | `git --no-pager diff --stat 11c01b2 -- private-block-kernel private-model-kernel zkvm-block` | — | **empty**, after step C |

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

**S8-F1 (both windows are now reproducible in a fifth of a second, and the
inventory of what is left is exact).** S6 put all three calibration windows
into the shape, so the two completeness failures of §3.8 rows 9 and 10 are
tests rather than table entries. Each is shown twice: by counting from the
shape, and in the builder, where the SAME honest input refuses by name at the
toy's setting and is accepted at the rung's.

| window | the honest rung value | the toy's setting | refusal, by name | the rung's |
|---|---:|---:|---|---:|
| norm remainder (row 9) | `den - 1 = 4096 · 321,049 − 1 ≈ 2^29.97` | `2^29` | `norm quotient/remainder` | `2^31` |
| softmax remainder (row 10) | `Sum ≤ 24 · 2^12 = 98,304 ≈ 2^16.58` | `2^14` | `softmax quotient/remainder` | `2^17` |

**What is left for S8, in the order it has to happen:**

1. the `A_*` plane ids are literal, and a third `sigma_s` limb adds **two**
   `Dom::S` planes (`Shape::rung()` and `Shape::m125()` both count 83 where
   the toy counts 81), shifting every id above `A_SG1` — `A_G8` … `A_MACT` —
   and every range in `layout::a_dom`, every `a_range(A_S8, A_SG1)` in
   `argument.rs`, and the claim-site table;
2. the third limb's own lookup, `scaled(l2, 1 << (24 − wrho_s))` = **64**
   (the toy's two-limb coefficient is `1 << (16 − 14)` = **4**);
3. the four norm coefficients `1 << (32 − NORM_WRHO)` at `layout.rs:377`,
   `:379`, `:385`, `:387`: **8** at the toy, **2** at the rung, **1** at
   125M — and at 125M `Shape::norm_top_is_full_byte()` is true, so those four
   lookups are REDUNDANT and C-6 drops them, which moves the `H` row total;
4. the module's integer premise text in `layout.rs`'s header (§3.3, §3.4,
   O-4, D16 items 1–5), which still says "rho and sigma < 2^29 exactly" and
   "rho_s and sigma_s < 2^14 exactly";
5. the norm-range lane's alias tamper tests at the new profile (D16 item 6,
   non-negotiable, ruling P-5).

The one test that states the deliverable,
`the_rung_at_its_own_calibration_has_an_honest_witness`, is left
**`#[ignore]`d with its reason** and its failure captured
(`s8-ignored-test.log:82`). It is the only ignored test this lane added.

## Stage 3 (2026-09-20, after job K): S8 done

**S8-F2 (what made the ids expressible, and why no toy byte could move).**
`layout::Ids` is built from a SEGMENT TABLE — (first toy id, toy length, this
shape's length, domain) for eighteen plane groups — and `Ids::new` refuses
unless the list it builds equals `Shape::a_plane_doms()` element for element.
Those two are independent statements of memo §2.4's plane list, written from
the memo and not from each other, so the map cannot quietly disagree with the
counted layout. Three groups have a length that is not a literal: each norm's
`rho`/`sigma` limbs (`limbs_norm`, 4 everywhere), the softmax quotient's
(`limbs_p`, 2 everywhere, fixed by `F_P`) and the softmax remainder's
(`limbs_sigma_s`, **2 at the toy, 3 at the rung and at 125M**). At two limbs
the map is the IDENTITY — asserted, and that is the whole reason the toy
cannot move — and at three it puts `A_SG*` one up, everything above `Dom::S`
two up, and **nothing below `Dom::S` anywhere**.

**S8-F3 (the one plane id still read as a literal, with its one-line fix).**
`Witness::output()` reads `A_X2`. That id sits below the `Dom::S` limb groups
but ABOVE the two norm limb groups, so it is stable exactly while
`limbs_norm == 4` — which it is at the toy (window 29), the rung (31) and
125M (32, `D_max = 908,065`, four limbs exactly, C-9's ceiling). A shape
needing a fifth norm limb is refused BY NAME at `build_shaped`
(*"this shape's norm remainder needs a different number of byte limbs"*) and
tested; the fix, when a shape needs it, is to carry the output plane's id in
the `Witness` — one field, plus the eight `Witness { planes: … }` sites in
`tamper.rs`. It was NOT done now because no shape on the roadmap reaches it
and an untested generality is worse than a named refusal.

**S8-F4 (the top-limb coefficient is one formula, and C-6 falls out of it).**
The memo states the norm coefficient as the `1 << (32 - wrho)` idiom and the
softmax one as `scaled(l2, 64)`. Both are the same rule: a window of `w` bits
held in `l` byte limbs leaves `8l - w` slack bits in the top limb, so the
lookup that forbids them is `scaled(top, 1 << (8l - w))`. It gives 8 at the
toy and 2 at the rung for the norm, and 4 / 128 / 64 for the softmax pair at
the toy / rung / 125M; and at 125M `8l == w` makes the norm coefficient 1, a
lookup that says nothing, so `lookups_at` DROPS all four — that is C-6,
derived rather than special-cased, and it moves `Dom::D` from 38 lookups per
position to 34. The counts are gated against `Shape::lookups_per_position`,
which counts the same list from §4 without building it, at all three shapes.

**S8-F5 (the rung's third limb is exercised, not merely allowed).** The
deliverable test does not stop at "a witness exists": it asserts that some
`sigma_s` on the rung's causal support needs its THIRD byte limb (a value
above 2^16, which the two-limb form could not have written at all — the
completeness failure S8 removes), that all three limb planes are byte planes,
and that `sigma_s + rho_s + 1 = Sum` closes over the integers at every causal
position inside the 17-bit window.

**S8-F6 (what P-5 got, and what it is still owed).** D16 item 6 asks that the
norm-range lane's alias tampers reject AT THE NEW PROFILE. `prove_inner` is
toy-only until S10/S11 (finding S5-F2), so the end-to-end form cannot be
built yet and is **owed again at S12**. What was built instead is the same
statement at the level where the relation is decided, in two cases: the
widening moves `wrho`, a bound on `rho`/`sigma` in `limbs_norm` limbs, while
the alias is excluded by (R2), a bound on `d` in the three isqrt limbs, and
the second does not move at any of the three shapes (`D_max` and `2 D_max`
stay inside 2^24 even at 125M, and `den_max` saturates each shape's window,
which is what makes `wrho` §3.3's completeness bound and nothing else); and
on a REAL honest rung witness, three rows, the alias satisfies (R1), (R3),
(R4) in `F_p` and the only false relation is (R2), in both of the prover's
two forms. This is recorded as the smaller claim it is.

**S8-F7 (the parity fixture is gone, and the split did not move).** The
160-case witness-vs-kernel sweep now runs at `Shape::rung()` itself — `F_E`
12, a 17-bit window, three limbs — instead of the rung geometry at the toy's
softmax calibration. The verdicts are unchanged (131 accepted by both, 29
refused identically), which is worth noting: the third limb changes what the
witness WRITES, not what either implementation DECIDES, exactly as a
completeness fix should.

**No disagreement between the memo's rules and `layout.rs` was found at the
toy shape**: every rule the memo states reproduces the Rust's own numbers.
The differences above are all at shapes that do not exist yet.

Nothing is written outside this worktree, and no witness value, salt or
private plane appears in any evidence file: counts, sizes, booleans and
digests only. A zero-witness proof that verifies is a PRECONDITION for the
privacy argument, not a privacy result.

## S9 — the pad rule of ruling P-1: PREPARED, not implemented

**What exists** (`hashline/src/private_block/pad.rs`, commit `f3ce0ba`,
`cfg(test)` only until the term is built):

| piece | state |
|---|---|
| the six (at the rung, nine) **support indicators**, over each domain's padded flat index in the convention `witness::Geom` lays planes out in | BUILT and tested: weight equals the domain's true size at all three shapes, equals the builder's own support set element for element, is 0/1, and `supp_D != supp_Q` exactly where the head axis pads |
| the **interleaved head slots** of correction C-1 | BUILT as a predicate: padded slots `{3, 7}` at the rung, `{3, 7, 11, 15}` at 125M, with a prefix mask shown to accept slot 3 |
| the **per-plane ZERO / EXEMPT table** of §3.7a | BUILT and reproduces the memo's recount at 125M EXACTLY: **64 ZERO, 35 EXEMPT, 1 with no rule, 100 planes**, the one exempt `A` plane being `A_E` by name, the `H` side counted through `Shape::h_plane_doms` (50 planes at 125M, not the toy's 51, because C-6 drops four `Dom::D` lookups). The rung's own table is **85 / 49 / 1** over all 135 committed planes |
| **PZ-1** and **PZ-2** | WRITTEN, `#[ignore]`d, and FAILING with their own messages |
| the batched **pad-zero term** `mu_pad (1 - supp) Σ ζ^j plane_j`, its `ζ` refused on zero, the support factor on the constraint groups and host terms, the P-2 construction-time weight check, the slot arithmetic with the indicator | **NOT BUILT** |

**At what level PZ-1 and PZ-2 run, and why.** The rejection ruling P-1 asks
for is a term in `argument::define`'s zero-check bracket, and `argument` is
instantiable only at the toy (finding **S5-F2**): the claim points, the RoPE
tables, the row geometry (S10) and the endpoints (S11) are still the toy's,
so **a padded shape produces no receipt at all** and a verifier-side test
cannot be written yet. Both tests are therefore written at the level where
the relation is decided — every relation the module CAN evaluate against a
real honest witness built at `Shape::rung()`: the four norm relations
(R1)..(R4) of `norm_alias.rs` on every token row of both norms with (R4)
reading the **full padded** cube exactly as `argument.rs:544-557` builds the
two claimed sums, both residual identities, and the byte class of every
plane a lookup reads. The honest witness passes all of them; each tamper
also passes all of them, and that is the failure.

* **PZ-1** writes `1` into a padded position of `A_RAL` — a ZERO-rule plane
  no claimed sum reads — and it is invisible. That is the coverage half of
  B-1.
* **PZ-2** writes `32,767` into `A_X`'s padded columns of token row 0 **with
  the byte limbs filled consistently** (the int16-fill branch, so `SC_DZC`'s
  `c2` holds on the pad too and the tamper is not decided by a limb
  relation) and recomputes `D`, `a1`, `a2`, `D^2` and the packed limb plane
  from the enlarged sum of squares. Every relation still holds, with a
  divisor the prover chose. That is B-1 itself.

**S9-F1 — RESOLVED in stage 4 (see "the profile gate" below). (the toy is
NOT a no-pad shape, and the rule must be gated by PROFILE).** The brief's standing condition is that at the toy nothing pads,
so the pad-zero machinery must be ABSENT from the toy's transcript. But
`Dom::L` pads at the toy — nine of sixteen limb sub-planes carry the isqrt
witness, 288 true of 512 (finding B-F5) — so a rule of the form "add the
term wherever `Shape::pads(dom)`" WOULD put a term in `SC_LZC` and move
every toy byte. **The gate must be the profile, not the domain**: a new
profile carries the pad rule, the frozen toy profile does not, and the toy's
`Dom::L` pad stays unconstrained exactly as it always was (D17). That is a
statement about the toy profile the security owner should see, not a defect
introduced here. Tested by
`the_toy_already_pads_one_domain_and_must_not_gain_the_term`, which also
records the toy's own would-be table: 2 ZERO, 1 EXEMPT.

**S9-F2 — RESOLVED in stage 4 (see "the head permutation" below). (a
prerequisite inside S9 that is not built: the head permutation).** `witness::build_shaped` indexes query heads CONTIGUOUSLY
(`g.dix(t, h * head_dim + i)`, `h` in `0 .. q_heads`), so today's padded head
slots are the TAIL of the head axis — `{6, 7}` at the rung — while
correction C-1 and ruling P-2 require them INTERLEAVED, `{3, 7}`, one per
key-value group. The two layouts are shown to disagree on `Dom::Q`,
`Dom::S` and `Dom::Ht` at both padded shapes and to coincide at the toy
(which is why no toy test could have seen it — the same lesson as
**S6-F1**). **The permutation has to land before the `Dom::Q` and `Dom::S`
indicators mean anything**, and it moves the witness's plane layout, the
kernel-index map `Geom::support`, the `SC_WO` folded weight order and P-2's
"head-permuted" construction refusal together.

## Stage 4 (2026-09-20, after JOB K4): S9 parts 1–3, commit `2798148`

Everything below is in ONE commit, all of it inside
`hashline/src/private_block*`. **No new shared-file change**: the table at
the top of this ledger is unchanged, and the three frozen crates still print
an empty diff against `11c01b2` (command 53).

### S9-F2, RESOLVED — the head permutation

`Shape::head_slot(h) = (h / group) * slots_per_kv_group + h % group`, with
`group = q_heads / kv_heads`. Each key-value group owns a CONTIGUOUS BLOCK of
padded head slots and its padding falls at the end of its OWN block, so

* the padded slots are `{3, 7}` at the rung and `{3, 7, 11, 15}` at 125M
  (correction C-1), never a contiguous tail;
* the key-value head is the slot's HIGH bits —
  `kv_of_slot(sl) = sl >> log_slots_per_kv_group` — which is the
  fixed-coordinate relation the ruling asks for, asserted against
  `h / group` at all three shapes;
* `Shape::new` gains a named refusal, *"the key-value heads do not divide the
  padded head count"*, because `kv_heads | q_heads` is not enough.

**Where it lands.** `Geom::support(Dom::Q)` (a new arm: `Dom::Q` no longer
shares `Dom::D`'s, which is §3.7a note 1 in code), `Geom::support(Dom::S)`,
`Geom::support(Dom::Ht)`; the score loop, the softmax loop and the PV loop of
`witness::build_shaped`; the `A_RO0` / `A_RO1` write loop, which had to move
out of the `Dom::D` loop because those two are `Dom::Q` planes; and
`parity::compare_shaped`, where `q8`, `qr8` and `o8` now compare on
`Dom::Q`'s support (they were compared on `Dom::D`'s, and at the toy the two
are the same list). At the toy the map is the identity, so no toy byte moves
and no toy test could have seen the difference — the lesson of S6-F1 again.

**The failing run that came first** is `s9b-compile2.log:203`: `q8` differs
from the kernel in **90 of 2,304** elements, which is exactly the 3 of 6 rung
query heads the permutation moves (`3 * 24 * 16 = 1,152` positions, of which
90 differ in that case's values).

### S9-F1, RESOLVED — the profile gate

`Shape::carries_pad_rule()` is `profile != TOY_PROFILE` and nothing else. The
degree accounting in `Shape::slots` is gated by it. The test builds a shape
with the TOY'S OWN GEOMETRY under a new profile id and shows it carries the
rule while the toy does not — the one case a domain-driven gate could not
tell apart, and the reason the gate cannot be "does this domain pad".

### S9-F3, RESOLVED — the indicator is the builder's support table

`pad::support_indicator(s, dom)` is now DEFINED as the 0/1 table of
`Geom::support(dom)`. A closed form is an optimisation:
`pad::closed_form_indicator` factors the predicate axis by axis into the two
forms §3.7a uses — `prod (1 - b_k)` when the true extent is a power of two,
`1 - prod b_k` when the PAD is — and `the_closed_forms_equal_the_tables`
asserts the product equals the table entry for entry at all three shapes. The
memo's own expressions come straight out of the factors at 125M: `supp_D`
top bit 9, `supp_Q` 7, `supp_S` 19, `supp_Ht` 10, and `supp_Tab` the
all-zero product over bits 8..13. **`supp_L` has no product form at any
shape** (`[k < 9]` with 9 neither a power of two nor a complement of one) —
exactly what the memo says, and the correction to the earlier reading of
S9-F3: it is not that the memo's formulas are 125M-only, it is that ONE of
them was never a product. At the rung every predicate is still a product,
because `24 = 32 − 8`, `96 = 128 − 32` and `192 = 256 − 64` are all
complements of powers of two.

**What the verifier must evaluate, and what it costs** (`indicator_costs`,
one row per padded domain: the table length, the number of SLOTS that
materialise it — `table_of` clones a public table per slot,
`argument.rs:206` — and the bytes at one `Fp2` per entry per slot):

| shape | `Dom` | length | slots | bytes |
|---|---|---:|---:|---:|
| 125M | `D` | 2^19 | 3 (`SC_SS`, `SC_SSM`, `SC_DZC`) | 25.2 MB |
| 125M | `Q` | 2^19 | 1 (`SC_QZC`) | 8.4 MB |
| 125M | `S` | 2^22 | 2 (`SC_RS`, `SC_SZC`) | **134.2 MB** |
| 125M | `Ht` | 2^13 | 0 — it rides in `SC_SZC` on `supp_S` (open question 2) | 0 |
| 125M | `L`, `Tab` | 2^14 each | 1 each | 0.26 MB each |
| **125M total** | | | | **≈ 168 MB** |
| rung (7 padded domains) | | | | **704,512 B** |

**S9-F4 (new, for the security owner).** 168 MB of materialised indicator
tables at 125M is the price of the memo's conservative "priced as tables"
choice, and it is prover memory ON TOP of §7.1's 9.6 GiB, plus a verifier
`eval_mle_ext` over 2^22 twice. Five of the six have a closed form that the
code now produces and checks; taking it would leave only `supp_L`'s 0.26 MB.
This is open question 1 of §3.7a with a number attached, and it is the kind
of thing S14's peak-RSS acceptance will notice.

### Ruling P-2 — the public weights

`AttentionPublic::new_shaped` and `FeedForwardPublic::new_shaped` now take
the **zero-padded, head-permuted** matrices: every axis is the PADDED extent
(`d_pad`, `f_pad`, and `kv_heads * head_dim`, which does not pad), and every
entry off the destination axis's support is refused BY NAME at construction.
Two strings, so §9a's two cases are told apart:

| case | refusal |
|---|---|
| a `Wq` entry at a padded WIDTH column, a `Wg` entry past the hidden width, a gain past the model width | *"private block: a public weight is nonzero at a padded width index"* |
| a `Wq` ROW at a padded head slot; **a `Wo` whose input columns are in true-head order instead of slot order** (§9a's named second case) | *"private block: a public weight is nonzero at a padded head slot"* |

The check is ENTRYWISE, which is strictly stronger than the memo's "the
folded weight vector vanishes off its support": folding is a linear
combination over the other axis, so an entrywise-zero block folds to zero at
every challenge while a folded vector could vanish at one point and not
another. `the_folded_weight_vectors_vanish_off_support` ties the two together
by folding each matrix the way its slot folds it (`fold_rows_i8` for the four
attention matrices, `fold_cols_i8` for the three feed-forward ones) and
asserting the folded vector vanishes off the INNER axis's support — with a
guard that the fold is not identically zero, so the check says something.

**The padder lives in TEST code** (`grow_tests::pad_attention_weights`,
`pad_ff_weights`, `pad_matrix`), which is the point: the library's checker is
not checking its own output. At the toy every padded extent equals its true
extent and `head_slot` is the identity, so the accepted set of statements
does not move by one word and the public `AttentionPublic::new` /
`FeedForwardPublic::new` signatures and length checks are unchanged.

**S9-F5 (a consequence worth recording).** The witness builder's matmuls now
fold over the PADDED inner index (`d_pad`, `f_pad`) rather than the true one,
because that is what the argument's matmul slots do and what trap T-2 /
`argument.rs:626` is about. At 125M the QKV/`Wo` accumulations therefore do
`1024` instead of `768` multiply-adds per output, about +33% on those four
matmuls in the WITNESS BUILDER only (the proof cost is unchanged — the
sumcheck already runs over the padded cube). Nothing on the toy moves.

### The toy-padding check the ruling asked for

**Which planes the accepted toy profile places on a padded domain, and what
constrains them.** The toy pads exactly one domain, `Dom::L` (288 true of
512, nine of sixteen limb sub-planes). Two planes sit there, `A_LIMB` and
`A_LIMBM`, and under the memo's table **both are ZERO-rule**; their shared
LogUp helper `H_L` is EXEMPT. So yes — **two ZERO-rule planes sit on a padded
domain in the accepted toy profile.**

**What constrains that pad today.** Exactly two things, both checked in
`the_toy_profiles_padded_planes_and_what_constrains_them`:

1. the two `byte` U8 lookups on those planes (`lookups_at(toy, Dom::L)` is
   precisely `[byte(A_LIMB), byte(A_LIMBM)]`, no constant, coefficient 1).
   The LogUp arm is never gated by an indicator (§3.7a is explicit that it
   must not be), so these are active on the WHOLE padded domain and prove
   every padded entry lies in `[0, 256)`;
2. nothing else. `SC_TZC` reads the nine USED sub-slices at their fixed
   offsets and never touches sub-planes 9..16; `SC_LZC` is homogeneous.

**So the toy's pad is proved to be BYTES and is not proved to be ZERO.** The
honest builder writes zeros there (asserted on a real toy witness), so no
honest toy byte moves and the frozen receipt is unaffected. A dishonest
prover could write any byte in those 224 positions: it would shift the U8
multiplicity histogram consistently and break no relation, so it is extra
prover freedom inside the committed material rather than a break of the
block's input/output statement — the padded positions feed no claimed sum and
no constraint group. **Reported, not fixed** (D17: the toy profile is
frozen). The security owner may want it on the record next to the toy
profile's other accepted deviations.

**S9-F6 (the H-side plane ids are still literals, and they MOVE).** The A
plane ids became a shape-driven map in S8 (`Ids`). The **H** side did not:
`H_L`, `H_D0`, `H_Q0`, `H_KV0`, `H_S0`, `H_SEXP`, `H_F0`, `H_FACT`,
`H_GU8`, `H_GEXP`, `H_GACT`, `H_U` and `h_dom` are literal indices into a
51-plane list, and `Shape::h_plane_doms()` already says the list is 52 at the
rung (the third `sigma_s` limb adds one `Dom::S` helper, shifting `H_F0`
upward by one) and 50 at 125M (C-6 drops four `Dom::D` lookups, so that block
holds 17 helpers, not 19). **An `Ids`-style segment map for the H planes is a
prerequisite of the shaped argument** and does not exist. It is the exact
analogue of S8-F2 and should be built the same way, with the same
construction refusal when the built list differs from
`Shape::h_plane_doms()`.

**S9-F3 (superseded by the RESOLVED entry above; kept for the record).**
§3.7a gives
`supp_D = 1 - b9 b8` and friends as closed forms on a single axis. At the
**rung the token axis pads too** (24 of 32), so no rung indicator is a
single two-bit product: `supp_D` is `[t < 24] and [i < 96]`, a product of a
prefix predicate and a two-bit term. The memo's open question 1 (table
versus closed form) therefore has a different answer at the rung than at
125M, and the tables built here are the conservative form the memo prices.

## Stage 5 (2026-09-20): steps B and C part 1, commits `a6ed423`, `522b9c3`

Both commits touch `hashline/src/private_block/` only (`layout.rs`,
`argument.rs`, `grow_tests.rs`). **No new shared-file change**, and
`git --no-pager diff --stat 11c01b2 -- private-block-kernel
private-model-kernel zkvm-block` is empty after each.

**C-F1 — the schedule digest and the profile id (a judgement call, for the
record).** The toy's first `describe()` line opens with `private-block-t32/1`,
which is NOT the toy's profile id (`hashline-zk-mr1/private-block-t32-poc/1`)
and is transcript-bound through `schedule_digest`. Normalising it would move
every toy byte, so the shape-driven `describe()` keeps it verbatim **for the
toy profile and only for it** and puts `sh.profile` there for every other
shape. Consequence worth stating: the toy's own schedule digest does not
separate two shapes of identical geometry under different profile ids — the
profile string is what separates them, and it enters the transcript
separately (`Transcript::new(PROFILE)`). For every NEW profile the digest
separates them too, which is asserted. Nothing about the toy changed; this
is a description of what was already true.

**C-F2 — two public tables had to become padded, and one of them is not yet
sound on the pad.** A slot's public table must be as long as the slot's
CUBE. At the rung the dense causal mask (`h * t * t` = 4,608) and the dense
RoPE tables (`tokens * heads * head_dim` = 2,304) are shorter than their
cubes (8,192 and 4,096), so `causal_mask_at` and `rope_tables_at` lay them
on the PADDED stride. The mask keys on `(t, j)` and so is 1 on a padded head
slot, which is M-3 as written. The RoPE tables are ZERO off the support,
like the public weights of P-2 — but the clause they enter carries
`+ 2^(SH_ROPE - 1)`, so a zeroed pad does NOT make it vanish there. **That
is exactly what the support indicator of S9 part 4 is for**, and until it
lands a rung definition is a definition, not a sound argument. The same
holds for the two `gamma` tables of `SC_DZC`, which are zero off the width's
support by P-2 but sit in inhomogeneous clauses.

**C-F3 — `Ids::at(A_SG1)` is not the last `sigma_s` limb.** The segment
table maps only the TOY's two ids of a growing group, so at a shape with
three limbs `at(A_SG1)` is the SECOND limb, not the last. Any `a_range`
that ends inside a growing group must end at the group's own accessor
(`ids.sg(ls - 1)`), and `SC_SZC` now does. A range that ended at
`ids.at(A_SG1)` would have silently dropped the third limb from the LogUp
arm at the rung. Worth a second pair of eyes if another growing group is
ever added.

**C-F4 — what step C does NOT establish.** A definition that builds at the
rung is not a proof. No rung receipt exists, `protocol.rs` is unchanged,
the pad rule is not in the argument, and no privacy statement is made at
any shape but the toy — and none there either.

## NEXT

**Where the lane stands.** JOB K, S8, **S9 parts 1, 2 and 3** (commit
`2798148`), **steps A, B and C part 1 of the shaped argument** (commits
`0493be3`, `a6ed423`, `522b9c3`) are DONE. **100 passed / 0 failed / 4
ignored** on `--lib private_` (`s5c-run2.log:181`), 8 warnings — the
baseline's 8. The toy receipt is
2,816,472 B and the pinned schedule digest has not moved at any commit of
any stage. `git --no-pager diff --stat 11c01b2 -- private-block-kernel
private-model-kernel zkvm-block` is **empty**, so JOB K's acceptance is now
literally met. The other crates were not touched in stage 4 and their last
recorded counts stand: 5 / 0 on `private-block-kernel-shaped`
(`k1-shaped-crate.log`), 10 / 0 (+1 ignored) on the frozen
`private-block-kernel` (`k2-frozen-crate.log`), 19 / 0 on
`private-model-kernel` (`k3-model-kernel.log`).

Of the four ignored tests, two are the pre-existing
`capture::native_capture_saved_receipt` gates (they need saved receipt paths)
and two are **PZ-1 and PZ-2**, still ignored ON PURPOSE (they are un-ignored
at S12, when a rung receipt exists).

**WHAT IS BLOCKING EVERYTHING ELSE, in one sentence.** `argument.rs` now
runs over a `Shape` (step C part 1), so the remaining blocker is
`protocol.rs` + `wire.rs`: `prove_inner` / `verify_inner` still build the
toy's PCS parameters, the toy's transcript, the toy's row width and the toy's
opening-group counts, so no rung receipt can be produced. S9 part 4, S10,
S11 and S12 all sit behind that one file.

### Step A — the H-side plane id map (finding S9-F6). **DONE, commit `0493be3`.**

`layout::HIds` is built and tested. It is the analogue of S8's `Ids`, with
the same construction refusal ("this shape's H plane list differs from the
pinned one") against `Shape::h_plane_doms()`. It is NOT a toy-id map,
because the H list moves in BOTH directions: the `Dom::D` helper block is
19 at the toy and the rung but **17** at 125M (C-6 drops four `Dom::D`
lookups where the norm window fills its top byte limb), so at 125M
`H_D_LAST` names a plane that does not exist; the `Dom::S` block is 7 at
the toy and **8** at the rung and 125M (the third `sigma_s` limb). `N_H` is
51 / **52** / **50**. The accessors are therefore by ROLE — `helper(dom,
k)`, `first_helper(dom)`, `sexp()`, `fact()`, `table_helpers()`, `u()`,
`dom()`, `is_table()` — which is how `argument.rs` already reads them.

`the_h_plane_ids_are_the_toys_at_the_toy_and_each_shapes_elsewhere` pins
the toy accessor by accessor and plane by plane (domain and table flag for
all 51), agrees with the old `layout::helpers(dom)` block by block, and
checks each shape's own list.

**Not wired in**: `argument.rs` and `protocol.rs` still read the literals,
which are correct at the toy and only at the toy, and `layout::helpers(dom)`
(the literal match at `layout.rs:632`) still exists. Replacing both is part
of step C.

### Step B — `Layout::for_shape`. **DONE, commit `a6ed423`.**

The layout owns its `Shape`, `Ids` and `HIds`, plus `a_sites`, `h_sites`,
`slots` and the row width `n`; `lookups(dom)` is `lookups_at`,
`a_planes`/`h_planes` are the id maps' lengths, `h_u_rows` reads
`hids.u()` and `n`, and both limb offsets read `ids.at(A_LIMB)` and
`sh.t_pad`. `Layout::new()` is `for_shape(&Shape::toy())` plus every frozen
assertion, so all 29 call sites are untouched, and construction REFUSES BY
NAME (through `Ids::new` / `HIds::new`) any shape whose plane list is not
the one the segment tables describe.

**`describe()` was byte-identical first try** (`s5b-run1.log`, taken before
its own test existed: the digest pin was already in the pass list). Its six
header lines are now pinned VERBATIM by
`the_layout_is_built_from_a_shape_and_the_toy_is_one_instance`, on top of
the literal digest, so a future edit is told WHICH line moved. One judgement
call is recorded here: the toy's first line opens with a legacy label
`private-block-t32/1` that is NOT its profile id and is transcript-bound, so
it is kept verbatim for the toy profile **and only for it**; every new
profile puts its own profile id there. That is also what makes the schedule
digest separate two shapes of identical geometry (asserted for the rung and
125M, and between them) — see finding C-F1.

### Step C part 1 — the shaped `define`. **DONE, commit `522b9c3`.**

Every item of the literal inventory below is done, in `argument.rs` only:

| item | becomes | state |
|---|---|---|
| `challenge_fp2_vec(5)` — the token axis | `lg(sh.t_pad)` | done |
| `challenge_fp2_vec(9)` — a `Dom::D` / `Dom::L` cube | `sh.log(dom)` | done |
| `challenge_fp2_vec(1)` — the head axis | `lg(sh.h_pad)` | done |
| `(3)` / `(4)` — head dim / an outer width | `lg(sh.head_dim)`, `lg(sh.d_pad)`, `lg(sh.f_pad)` | done |
| `rho(0..k)` on every `a_at` / `a_slice` | the axis's own log | done |
| `D`, `KV`, `F`, `T` as matmul widths | `d_pad`, `kv_heads*head_dim`, `f_pad`, `t_pad` | done |
| `causal_mask()`, `rope_tables()` | `causal_mask_at`, `rope_tables_at` (padded stride) | done |
| `A_*` literals | `ids.at(..)`, `ids.nr/ns/mr/ms/pl/sr/sg(k)` | done |
| `H_*` literals | `hids.first_helper/helper/sexp/fact/table_helpers/u` | done |
| `argument.rs:799`'s bare `1` (M-1) | `sh.kv_heads` | done (S7) |
| `layout::helpers(dom)`'s literal match | `Layout::helpers` = `(hids.first_helper, sh.helpers)` | done; the free `helpers(dom)` survives as the toy oracle |
| `SLOTS` / `slot_terms` inside `run_slot` and `sum_weights` | `SlotDef.sh`'s `slots()` / `slot_terms()` | done |
| `a_dom(p).log()` / `h_dom(p).log()` inside `B` | `sh.log(ids.dom(p))` / `sh.log(hids.dom(p))` | done |
| `B::endpoint`'s literal `log: 9` | `sh.log(Dom::D)` | done as far as ONE block goes; **S11 owes the multi-block seam** |

The three slots that change MEANING were taken first, and each is tested:
`SC_SCORE` / `SC_PV` read the key-value factor at the QUERY head's group
(trap T-3, C-1: the group is the top `log2(kv_heads)` entries of `r_h`);
`SC_SZC` addresses the `rho_s` / `sigma_s` groups through `Ids::sr` / `sg`
and runs its `a_range` to `ids.sg(ls - 1)`, because `Ids::at(A_SG1)` is NOT
the last limb when there are three; `SC_QZC` / `SC_KVZC` put the RoPE
partner bit at `log - log2(head_dim)` (T-8).

`the_slot_definitions_are_built_from_the_shape` builds all 23 slots at the
toy AND at the rung and checks: every definition builds (so `B::finish`'s
site-count refusal passed), every PUBLIC table is exactly the slot's cube,
every PRIVATE coordinate list is its own domain's log with free coordinates
inside the cube and a DECLARED extension round, the private terminal count
is the shape's, and the key-value claim point's group coordinate is
literally the same field element as the head challenge's first coordinate.
It also asserts the two new shape-driven public tables against the toy's
own literals entry for entry.

### Step C part 2 — the shaped `protocol.rs` (and `wire.rs`). **NOT STARTED. Do this next.**

Nothing else in the plan can move until a rung receipt can be produced.
`argument.rs` is clean; these are the toy literals that remain, all in
`protocol.rs` unless said otherwise (line numbers as of `522b9c3`):

| what | where | becomes |
|---|---|---|
| `pcs_params()` — `LOG_N`, `inv_rate: 8`, `num_col_checks: 256` | `protocol.rs:21` | `sh.log_cols`, `sh.inv_rate`, `sh.opened_cols` (this is **S10**: at the rung `log_cols` 10, rate 1/4, Q 256) |
| `Transcript::new(PROFILE)` | `:29` | `sh.profile.as_bytes()` — the new profile string, never the toy's (D17) |
| `absorb_root`'s `LOG_N`, `commitment`'s `log_cols` | `:43`, `:47` | `sh.log_cols` |
| `part_rows`'s `N` | `:105` | `lay.n()` |
| `opening_groups_at(claims, LOG_N)`, `check_opening(.., LOG_N)` | `:89`, `:188` | `sh.log_cols` |
| `A_GROUPS` / `H_GROUPS` at the two `check_opening` call sites | `:448`, `:451`, `:510`, `:516` | `sh.a_groups()` / `sh.h_groups()` |
| `ENDPOINT_ROWS = 7`, `ENDPOINT_PROX = 4` | `:204`, `:205` | `sh.endpoint_rows` and its own prox; **S11** |
| every `lay.a_off[A_*]`, `lay.h_off[H_*]` in `prove_inner` | `:341-343`, `:381-383`, `:405-407` | `ids.at(..)` / `hids.table_helpers()` / `hids.sexp()` / `hids.fact()` |
| `wit.planes.len() != N_A`, `a_dom(*p).len()` | `:298` | `ids.n_a()`, `sh.size(ids.dom(p))` |
| `a_data`/`h_data` sized `* N`, the zero-sum row loop `0..N-1` | `:309`, `:368`, `:418-423` | `lay.n()` |
| `exp_deltas`'s `% T`, `A_S8` / `A_MX` / `A_G8` literals | `:236-246` | `sh.t_pad`, `ids.at(..)` |
| `wire.rs`: `A_GROUPS`, `H_GROUPS`, `ENDPOINT_ROWS`, `HEADER`, the slot/mask sizes | `wire.rs:32-35`, `:62`, `:168` | the shape's; `Shape::receipt_bytes()` already models every part |
| `private_block.rs:98`'s `PROFILE` const | — | keep for the toy; the shaped entry points take the profile from the shape |

**Shape of the change.** `prove_inner` / `verify_inner` take a `BlockPublic`,
which carries no shape. Add `prove_inner_at(sh, ..)` / `verify_inner_at(sh, ..)`
with the current pair as `Shape::toy()` wrappers, exactly as `AttentionPublic::new`
is `new_shaped(&Shape::toy(), ..)` — that is the pattern the lane already
uses and it keeps every toy caller and every toy byte where it is. A rung
receipt then needs a rung witness (`witness::build_at`, already shaped, S6)
and rung endpoints (S11).

### Step D — S9 part 4, the pad-zero term. Writable NOW (it lives in `define`, which is shaped as of `522b9c3`).

It can be written before or after step C part 2 — `define` is already
shape-driven, so nothing blocks it, and finding C-F2 names two tables
(RoPE, `gamma`) whose inhomogeneous clauses are the reason it is owed. Two
extra obligations from the security owner's rulings this stage:

* **the toy documentation test.** Add ONE test at the TOY shape recording
  the toy-padding finding: it asserts WHICH relations read `A_LIMB` /
  `A_LIMBM` on `Dom::L` and that none of them reads a padded position, so
  that a future relation that did would fail the test. The toy is NOT
  changed; in every NEW profile those two planes are covered by the
  pad-zero term like any other plane.
* **the closed forms (S9-F4).** Use `closed_form_indicator` wherever it
  exists, so that no large indicator table is materialised at 125M,
  PROVIDED each closed form is asserted equal to the builder's support
  table at the rung, exhaustively. The definition of record stays "the
  builder's public support table". `supp_L` has no closed form, so its
  table stays.

Everything it needs already exists in `pad.rs`:
`support_indicator(shape, dom)` (the table), `closed_form_indicator`
(the optimisation), `indicator_slots(dom)` (which slots carry it),
`a_rule` / `h_rule` (the ZERO / EXEMPT table, reproducing the memo's
64 / 35 / 1 at 125M and 85 / 49 / 1 at the rung), and
`Shape::carries_pad_rule()` (the gate). What to build, per §3.7a:

1. in each hosting slot of `indicator_slots`, ONE fresh challenge `zeta`
   drawn in that slot's challenge block and **refused on zero** through the
   existing `nonzero(..)` helper (witness-independent: the refusal string
   names no relation and no plane), and one more entry of the slot's `mu`;
2. the term `mu_pad * (1 - supp(x)) * sum_j zeta^j * plane_j(x)` over the
   domain's ZERO-rule planes in plane order, EXEMPT planes excluded;
3. the support factor `supp` on the inhomogeneous constraint groups `c*` of
   `SC_DZC` / `SC_QZC` / `SC_SZC` / `SC_KVZC` / `SC_FZC`, on every host term
   in those slots, on `SC_SS` / `SC_SSM`'s summands and on `SC_RS`'s summand
   and its hosted `host_rs` — and **NOT** on the LogUp arm (`helper_sum`,
   `SC_SZC`'s `cx`), which is the one thing the pad rule must never gate;
4. gate the whole of 1–3 on `Shape::carries_pad_rule()`, never on
   `Shape::pads(dom)`;
5. re-run `every_slot_fits_the_mask_budget_with_the_indicator` — it already
   asserts the closest slot (toy 50, rung **72** at `SC_SZC` and `SC_FZC`,
   125M **117** at `SC_SZC`) and will fail loudly if a degree moves.

Then **S10** (log_cols 10, `Q` 256, the pad count and the opened columns
moving together; S4's lookup-summation repair test must stay green),
**S11** (the endpoints at `nb_d = 3` with their own `log_n` 8, C1..C8,
ADDITIVELY beside the frozen `private_seam.rs` entry points) and **S12**
(the rung end to end; un-ignore PZ-1 and PZ-2 in their END-TO-END form; the
P-5 alias tampers end to end; the zero-witness test at the rung; every toy
tamper re-run at the rung shape).

### NEXT: exactly what the next agent should do, in order

1. **Step C part 2 — `protocol.rs` + `wire.rs`** (the table above is the
   complete literal inventory). Add `prove_inner_at(sh, ..)` /
   `verify_inner_at(sh, ..)` with the current pair as `Shape::toy()`
   wrappers; the toy's code path and every toy byte stay where they are.
   **S10 falls out of it**: `pcs_params()` becomes the shape's `log_cols`,
   `inv_rate` and `opened_cols`, which at the rung is 10 / 4 / 256, and the
   S4 lookup-summation test must stay green.
2. **S9 part 4 — the pad-zero term**, with the toy documentation test and
   the closed forms (step D above). Not blocked by 1; take it first if
   `protocol.rs` looks like more than one sitting.
3. **S11 — the hidden endpoints at the rung** (C1..C8, ADDITIVELY; the tiny
   private-IO path and `private_seam.rs`'s entry points stay byte-frozen).
   `B::endpoint`'s log is already shape-driven, which is correct only while
   the endpoint fits ONE block; at `nb_d = 3` it does not.
4. **S12 — the rung end to end**: an honest rung proof verifies from bytes;
   the receipt length against the Python model's 4,173,208 B, any
   difference explained plane by plane; PZ-1 and PZ-2 un-ignored END TO END
   and rejected BY THE VERIFIER; the P-5 alias tampers end to end; the
   all-zero hidden input at the rung; every toy tamper re-run at the rung.

Standing rules for whoever picks this up: run the filter before every
commit of Rust code and record the counts here; the toy receipt is
2,816,472 B and the schedule digest is the literal pin; nothing runs at the
125M shape; `git --no-pager diff --stat 11c01b2 -- private-block-kernel
private-model-kernel zkvm-block` must print nothing.

### Still waiting on the security owner (none of them blocking)

* **S9-F4 (new)** — 168 MB of materialised indicator tables at 125M, on top
  of §7.1's 9.6 GiB, and a verifier `eval_mle_ext` over 2^22 twice. Five of
  the six padded domains have a closed form the code now produces and checks
  against the table; taking it would leave 0.26 MB. This is §3.7a open
  question 1 with a number attached.
* **The toy-padding finding (this stage)** — two ZERO-rule planes
  (`A_LIMB`, `A_LIMBM`) sit on a padded domain in the ACCEPTED toy profile,
  and what constrains their pad today is only the two `byte` U8 lookups: the
  224 padded positions are proved to be BYTES, not zero. Reported, not
  fixed (D17). Worth recording beside the toy profile's other accepted
  deviations.
* **S5-F1 / B-F3** — the 176-byte rung-receipt difference against §9a's
  table (`SC_KVZC`'s support indicator). S9's part 4 is the step that
  decides it: `indicator_slots(Dom::Kv) = [SC_KVZC]` in the code as written,
  i.e. the lane's reading is that the rung receipt is **4,173,208 B**.
* **S8-F3** — `Witness::output()` reads `A_X2` as a literal; a fifth norm
  limb is refused by name rather than supported.
* **S8-F6 / P-5** — the alias tampers are discharged at the relation level
  at the rung; the END-TO-END form is owed again at S12.
* **S1-F1** — a one-line correction to §1.3 T-1 and the §9 S1 row
  (`argument.rs:898` is `Dom::Tab.len()`, not the table size).
* **S3's decision 2** — the narrower input class; it changes the 125M
  `Dom::D` lookup list and so the `H` row total (C-6).
* **A memo correction (S9-F3)** — §3.7a's indicator table gives `supp_L` as
  "a 5-bit prefix predicate, not a product", which is right; the lane's
  earlier reading that ALL the closed forms are 125M-only is wrong and is
  corrected above. Every other predicate is a product at the rung too,
  because 24, 96 and 192 are all complements of powers of two.

Nothing is written outside this worktree, and no witness value, salt or
private plane appears in any evidence file: counts, sizes, booleans and
digests only. A rung proof that verifies would be a CORRECTNESS milestone;
the privacy checks are owed again at every new shape.

---

## Stage 6 (2026-09-20, 03:5x–04:4x): step C part 2 and the code conditions

Commits `0dfdeb4` (step C part 2 + S10) and `dcaec94` (C-H1, C-H4, C-H4′,
C-H8). Both touch `hashline/src/private_block/` only — `protocol.rs`,
`wire.rs`, `layout.rs`, `tests.rs`, `grow_tests.rs`. **No new shared-file
change**, and `git --no-pager diff --stat 11c01b2 -- private-block-kernel
private-model-kernel zkvm-block` is empty after each.

### Runs

| # | Command | Log | Result |
|---|---|---|---|
| 39 | the Rust command, before any edit of this stage | `s6c-baseline.log:180` | **100 / 0 / 4 / 67 filtered out**, 30.44 s |
| 40 | after the `protocol.rs` + `wire.rs` edit | `s6c-compile1.log` | 8 compile errors, all of them test call sites of the two widened signatures |
| 41 | after fixing the call sites | `s6c-compile2.log:181` | **100 / 0 / 4**, 8 warnings (the baseline's 8) |
| 42 | with the four step-C-part-2 tests | `s6c-run1.log:185` | **104 / 0 / 4**, 29.12 s |
| 43 | with the four code-condition tests | `s6d-run1.log:202` | **106 / 1 / 4** — the deliberate discovery run: the C-H1 test's distinctness assertion failed, 1,225 distinct salts against 1,280 columns (finding C2-F1) |
| 44 | with the C-H1 test corrected to the right property | `s6d-run2.log:188` | **107 / 0 / 4**, 29.29 s, 8 warnings |

### Step C part 2 — the inventory, line by line

Every row of stage 5's table, ticked off. All in `protocol.rs` unless said.

| what | becomes | done |
|---|---|---|
| `pcs_params()`'s `LOG_N`, `inv_rate: 8`, `num_col_checks: 256` | `pcs_params_at(sh)` = `sh.log_cols` / `sh.inv_rate` / `sh.opened_cols`; the old no-argument form is it at the toy (`native_capture.rs` calls that signature) | ✔ **S10** |
| `Transcript::new(PROFILE)` | `sh.profile.as_bytes()` | ✔ |
| the literal `"parameters"` word | `parameter_line(sh)`, FORMATTED from the shape and pinned verbatim at the toy | ✔ |
| `absorb_root`'s `LOG_N`, `commitment`'s `log_cols` | a `log_cols` argument, `sh.log_cols` at both call sites of each | ✔ |
| `part_rows`'s `N` | an `n` argument | ✔ |
| `opening_groups_at(claims, LOG_N)`, `check_opening(.., LOG_N)` | `check_opening` takes `log_n` and passes `1 << log_n` to `audit_claims` | ✔ |
| `A_GROUPS` / `H_GROUPS` at the four `check_opening` sites | `sh.a_groups()` / `sh.h_groups()` | ✔ |
| `ENDPOINT_ROWS = 7`, `ENDPOINT_PROX = 4` | `endpoint_geometry(sh)`, which REFUSES BY NAME any shape whose `endpoint_rows` is not the toy's — that is S11's, not this step's | ✔ (threaded) |
| every `lay.a_off[A_*]` / `lay.h_off[H_*]` in `prove_inner` | `ids.at(..)`, `hids.sexp()`, `hids.fact()`, `hids.table_helpers()` | ✔ |
| `wit.planes.len() != N_A`, `a_dom(*p).len()` | `ids.n_a()`, `sh.size(ids.dom(p))`; `is_multiplicity` → `ids.is_multiplicity` | ✔ |
| `a_data` / `h_data` sized `* N`, the zero-sum loop `0..N-1` | `lay.n()` | ✔ |
| `exp_deltas`'s `% T`, `A_S8` / `A_MX` / `A_G8` | `sh.t_pad` and `Dom::S`'s cube `(h * t_pad + t) * t_pad + j` (`witness.rs:193`), ids everywhere | ✔ |
| `lookup_values`'s `dom.len()` (the toy's `Dom::len`) | `sh.size(dom)` — the P-3 lift makes `Dom::L` 1024 at the rung where the toy's `Dom::len()` says 512 | ✔ (was not on the stage 5 list; found while editing) |
| `mask_specs()`, `slot_terms(s)` | `lay.mask_specs()`, `lay.slot_terms(s)`, new methods on the layout; the free functions stay for `native_capture.rs` | ✔ (not on the stage 5 list) |
| `wire.rs`: `CHECKS`, `VEC`, `ENC_COLS`, `PATH`, `A_GROUPS`, `H_GROUPS`, `ENDPOINT_ROWS`, `SLOTS`, `slot_terms` | a `Dim { checks, vec, enc_cols, path }` built once for the block commitments and once for the endpoints, which have their own PCS parameters | ✔ |
| `private_block.rs:98`'s `PROFILE` | kept for the toy; asserted equal to `Shape::toy().profile` | ✔ |

**Is a rung receipt produced? NO, and the reason is S11, not this step.**
`endpoint_geometry` refuses every shape whose `endpoint_rows` is not 7: the
rung's endpoint plane is 24 × 96 = 2,304 words, which does not fit one
`private_seam` block, and `IoSpec::seams()` still builds its two `SeamSpec`s
from the toy's `T` and `D` literals. Everything else on the prover and
verifier path is now shape-driven.

### New in this stage, beyond the inventory

* **`fits_the_ntt_tables(sh)`**. The module builds ONE `NttTables::new(12)`.
  That covers the toy (2^8 × 8 = 2^11), the development rung (2^10 × 4 =
  2^12), both endpoint encodings and the fixed 2^12 mask domain — but not
  125M, which needs 2^16. Both shaped entry points refuse a shape that does
  not fit, BY NAME, before anything public exists. A capability bound of this
  lane, not a soundness statement.
* **The codec against the model.** `wire::encoded_len(&Layout::for_shape(sh))`
  is asserted equal to `Shape::receipt_bytes(sh).total` at all three shapes.
  The toy's frozen **2,816,472 B** and the rung's modelled **4,173,208 B**
  agreed part for part FIRST TRY, which is the strongest evidence so far that
  the Python model and the Rust codec describe the same frame.

### C-F5 (new) — `native_capture.rs` is toy-only, and that is a forbidden file

The `#[cfg(test)]` capture diagnostics call `protocol::pcs_params()` (no
shape), build `Commitment { .., log_cols: 8 }` as a literal and rebuild
`Layout::new()`. They are inert unless a test arms the observer, so they cost
nothing today and nothing in this stage needed them. **But a rung CAPTURE —
the joint-view gate's input at the new shape — cannot be produced without
editing `native_capture.rs`**, which the lane may not touch. What would be
needed: `pcs_params` and the two literals taken from a shape the capture is
told about. Written down, not done (ruling asked for exactly this).

### C2-F1 (new) — the opened columns are drawn WITH REPLACEMENT

Found by writing the C-H1 test. An honest toy receipt publishes 1,280 opened
columns (Q = 256 for each of `A`, `H`, `M` and the two endpoints) at only
**1,225 distinct indices** — 55 repeats, which is the birthday count for 256
draws from 2,048 (4,096 for `M`). The repeats carry identical salts and
identical Merkle paths, so nothing is inconsistent; the test now asserts the
right property (one leaf, one salt; no two DIFFERENT columns share a salt;
no zero salt). **For the security owner:** whether the soundness analysis
counts drawn or distinct columns is a question this lane does not decide,
and the same question applies to the privacy side, where 55 repeated columns
carry no new information but also mean the verifier sees fewer independent
positions than Q suggests.

### The code conditions — where each is pinned

| condition | where | form |
|---|---|---|
| **C-H1** no leaf without a salt | `grow_tests::every_opened_column_of_an_honest_receipt_carries_its_own_salt` | a test on an honest toy receipt; the unopened half lives in `zkp-core`, untouched |
| **C-H4** no commitment with 5 or 8 rows | `layout::no_commitment_has_a_node_shaped_column`, called by `Layout::for_shape` | a REFUSAL at construction, for every shape, plus a test at the three shapes and on hand-made 5 and 8 |
| **C-H4′** no 28- or 35-byte domain label | the same test | scans the block path's seven source files through `include_str!` for byte-string literals, so it cannot go stale |
| **C-H8** pad count ≥ opened columns | `grow_tests::the_pad_count_is_at_least_the_number_of_opened_columns` and the S10 test | both the inequality and the equality `ZkOpts::standard` enforces |

### NEXT: exactly what the next agent should do, in order

1. **S9 part 4 — the pad-zero term** (stage 5's "step D" section above is the
   complete specification; nothing has changed in it). It is not blocked by
   anything now. Its two extra obligations stand: the ONE toy documentation
   test recording which relations read `A_LIMB` / `A_LIMBM` on the toy's
   padded `Dom::L`, and the closed forms asserted equal to the builder's
   support table at the rung.
2. **S11 — the hidden endpoints at the rung.** ASSESSED in the section
   below, not implemented: C1 … C8 are the FFN io path's and are not owed
   here, the rung needs NO forbidden file and no `private_seam.rs` change,
   and the three edits are named (S11-F3). **It is blocked on ONE ruling**
   (S11-F4): the padded endpoint puts the rung receipt 23,960 B over
   `MAX_WIRE_BYTES`. Get the ruling, then make the three edits.
3. **S12 — the rung end to end**, as stage 5's NEXT item 4 states it.

Standing rules unchanged: run the filter before every commit of Rust code and
record the counts here; the toy receipt is 2,816,472 B and the schedule
digest is the literal pin; nothing runs at the 125M shape; the empty-diff
check must print nothing.

### S11 assessed, NOT implemented — what the rung endpoints really need (04:5x)

The brief asks, before anything is built, whether the accepted change list
C1 … C8 of `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` needs a FORBIDDEN file. Read
against the code, the answer has two halves.

**S11-F1 — C1 … C8 are written for the FFN private-IO path, not for this
block.** C1 edits `hashline/src/zk.rs:2354, :3493`; C2 edits
`zk_ffn_fresh_wire.rs` and `zk_ffn_fresh_io.rs`; C7 and C8 build "the new io
module" beside them. All of those are forbidden on this lane, and **none of
them is on the private block's endpoint path**: the block borrows only
`private_seam::prepare`, `SeamSpec` and `PreparedPlane::into_ffn_endpoint`,
and runs its own `SC_IO_IN` / `SC_IO_OUT` slots. So C1, C2, C3, C7, C8, C9
and C10 are **not owed by this lane at all**; C4/C5 (`SeamSpecG`) and C6 (the
`mu`-batched multi-block seam) are the only two that could be, and neither is
needed at the rung — see S11-F3.

**S11-F2 — the frozen `SeamSpec` refuses the rung's TRUE endpoint shape, and
accepts its PADDED one exactly.** `SeamSpec::new` requires both axes to be
powers of two and `2 <= rows*cols <= 2^12` (`private_seam.rs:66-72`), so
`(24, 96)` is refused by name. `(t_pad, d_pad) = (32, 128)` is accepted, with
`len` **4,096 — exactly at the frozen ceiling**. Its derived geometry is
`data_rows = 4096/256 = 16`, `commitment_rows = 16 + MASK_ROWS(5) = 21`. At
the toy `(32, 16)` gives 512, 2 and 7, which is the frozen `ENDPOINT_ROWS`,
and the toy's `t_pad`/`d_pad` ARE 32 and 16, so the toy's own call does not
move by one word.

**S11-F3 — the rung endpoints need NO forbidden file and no `private_seam.rs`
change.** Committing the endpoint on the PADDED `Dom::D` cube is what makes
the rest fall out, because `B::endpoint` already asks for `log =
sh.log(Dom::D)` (`argument.rs:489`), which is 12 at the rung: a 4,096-word
endpoint is exactly the slice the slot already claims. Three edits, all in
this lane's files:

1. `private_block.rs`'s `IoSpec::seams()` builds both `SeamSpec`s from the
   toy's `T` and `D` literals; it must take them from the shape's `t_pad` and
   `d_pad` (a shaped constructor beside the existing one — the toy's values
   are unchanged).
2. `argument.rs`'s `B::endpoint` hard-codes `mask_row: 2`, the toy's terminal
   pair. It is `data_rows`, i.e. `sh.endpoint_rows - 5`.
3. `protocol.rs`'s `endpoint_geometry` (added in stage 6) generalises to
   `data = endpoint_rows - 5`, `prox = data + 2`, which reproduces the toy's
   `(7, 2, 4)`.

**S11-F4, A RULING IS NEEDED — the padded endpoint breaks the 4 MiB wire
bound at the rung, and the shape's endpoint numbers are wrong either way.**
`Shape::rung()` declares `endpoint_rows = 14` and `endpoint_inv_rate = 4`.
Neither matches the seam: 14 is the TRUE shape's row count, which
`SeamSpec::new` refuses, and the seam's `INV_RATE` is the frozen **8**
(`private_seam.rs:31`), hashed into every `SeamSpec::digest()` and therefore
not editable. With the padded endpoint the two endpoint openings cost
`2 x [(1+1)(256+256)(16) + 256(8 + 21*8 + 32 + 11*32)] = 319,488 B` against
the model's 274,432 B, so the modelled rung receipt goes from **4,173,208 B
to 4,218,264 B — 23,960 B OVER `MAX_WIRE_BYTES` (4 MiB)**. Three ways out,
for the security owner to choose:

* raise `MAX_WIRE_BYTES` for the new profile (it is nowhere absorbed, the
  same argument C2 makes for its FFN analogue) — the smallest change, and it
  is a bound, not a security property;
* keep the endpoint at the TRUE 2,304 words with C6's `mu`-batched
  multi-block claim (endpoint 14 rows, and with the seam's rate 8 the receipt
  is 4,189,592 B, 4,712 B under the bound — a margin nobody should want);
* a `SeamSpecG` (C4/C5) with a wider rate or a wider `log_cols`.

**Not a rung question but recorded: 125M cannot use the frozen seam at all.**
Its endpoint plane is 512 x 768 = 393,216 words, `log_len = 19` against
`MAX_LOG_LEN = 12`, so C4/C5's `SeamSpecG` is genuinely required there. It is
also why `Shape::m125()`'s `endpoint_rows = 29` assumes `endpoint_log_n = 14`
while the seam's `LOG_COLS` is the frozen 8.

**Consequence for S12's acceptance number.** The 4,173,208 B target now has a
known correction pending this ruling; `the_codec_length_is_the_models_at_every_shape`
pins the codec to the model, so whichever way the ruling goes, the model's
`endpoint_rows` / `endpoint_inv_rate` move together with the codec and the
test keeps them honest.

## Stage 7 (2026-09-20, 05:0x–05:5x): S9 part 4, S11a, S12a — THE RUNG PROVES

Commits `793c943` (S9 part 4), `513a4ec` (S11a + S12a), `9a2b559` (the rung
tamper battery). The headline: **an honest proof at the development rung
verifies from its bytes in a fresh verifier call** — prove **0.49 s**, verify
**0.10 s**, frame **4,218,264 B** exactly as counted, peak resident memory
**74 MiB** (a whole-process high-water mark on a shared box; diagnostic only,
not a measurement of the proof). That is a CORRECTNESS milestone for the rung
profile and nothing more: no privacy check has been run at this shape, the
rung is development grade by ruling P-7, and no receipt from it is shown to
anyone.

### Runs

| # | command | log | result |
|---|---|---|---|
| 32 | the standard filter, baseline for the stage | `s7-baseline.log:187` | **107 / 0 / 4** |
| 33 | the filter, after the pad-zero term | `s9d-compile1.log:188` | **109 / 0 / 2** — PZ-1 and PZ-2 un-ignored and passing |
| 34 | the filter, after the indicator-count test | `s9d-run2.log:188` | **109 / 0 / 2** |
| 35 | the filter, first S11a attempt | `s11a-compile1.log:216` | **107 / 2** — the two model tests, by design: the codec now says 4,218,264 B |
| 36 | `cargo build --release` (no `cfg(test)`), because `pad` left `cfg(test)` | `s11a-libbuild2.log:255` | Finished, no warning from `pad.rs` |
| 37 | the filter, after the rung receipt length and the per-profile bound | `s11a-run3.log:188` | **109 / 0 / 2** |
| 38 | `--lib private_block::rung_tests`, the first rung proof | `s12a-run1.log` | panic in `helper_sum` — **finding S12-F1** |
| 39 | the same, after S12-F1 | `s12a-run2.log:80` | `mask schedule audit: a claim does not carry exactly its own reserved pair` — **finding S12-F2** |
| 40 | the same, after S12-F2 | `s12a-run3.log:82` | `H: pcs zk: group 8: <v, c> != combined claim` — **finding S12-F3** |
| 41 | the same, with the lookup diagnostic | `s12a-run5.log:86` | `the exp pair at (head slot 0, t 24, j 0) is not a table row` |
| 42 | the same, after S12-F3 | `s12a-run7.log:90` | **5 / 0** — `prove 0.49 s, verify from bytes 0.10 s, frame 4218264 B, peak RSS 74 MiB` |
| 43 | the filter | `s12a-filter1.log:220` | **112 / 2** — the two tests that asserted an all-zero `A_E` pad |
| 44 | the filter, after those two were corrected to the memo's TABLE | `s12a-filter3.log:201` | **114 / 0 / 2** |
| 45 | the rung tamper battery | `s12a-tampers1.log` | 27 of 28 rejected by the verifier; the 28th is not expressible as a witness edit |
| 46 | the filter, final | `s12a-filter4.log:203` | **116 / 0 / 2** |

**No new shared-file change.** Everything this stage touched is inside
`hashline/src/private_block*` (`private_block.rs`, `argument.rs`, `pad.rs`,
`parity.rs`, `protocol.rs`, `shape.rs`, `wire.rs`, `witness.rs`,
`grow_tests.rs`, `norm_alias.rs`, and the new `rung_tests.rs`). The
empty-diff check `git --no-pager diff --stat 11c01b2 -- private-block-kernel
private-model-kernel zkvm-block` prints nothing.

### S9 part 4 — what the term is

Per padded domain, ONE batched term inside the host slot's `eq(tau) * (..)`
bracket:

```
mu_pad * sum_groups (1 - supp(x)) * sum_j zeta^j * plane_j(x)
```

over that domain's ZERO-rule `A` planes in plane order, EXEMPT planes never
entering a group. One fresh `zeta` per host slot, refused on zero through the
existing witness-independent `nonzero` helper (its string names no relation
and no plane), and one more entry of the slot's `mu`. The support factor goes
on the inhomogeneous clauses `c*` and on every host term of the eight
`INDICATOR_SLOT_DOMAIN` slots, and NEVER on the LogUp arm (`helper_sum`,
`SC_SZC`'s `cx`, `SC_FZC`'s `f_act`). Everything is gated on
`Shape::carries_pad_rule()`.

**No new claim site, mask pair or opening group.** Every plane the term needs
is already read by its host slot (`a_range` pushes the whole domain), so
`audit_claims`' pair-exclusivity check sees exactly the claims it saw before.

**PZ-1 and PZ-2** are un-ignored and pass at the level they are written:
ruling P-1's own relation is now part of `every_checkable_relation_holds`.
Before the term they FAILED there. END TO END (S12a) they are rejected BY THE
VERIFIER, PZ-1 at slot 14 (`SC_DZC`, the pad-zero term itself) and PZ-2 at
slot 2 (`SC_TZC`, the newly gated host term).

**The toy carries none of it**, and three things say so: the frozen 2,816,472
byte receipt and the literal schedule digest are unmoved after every commit;
`pad::tests::the_toy_profiles_padded_planes_and_what_constrains_them` asserts
`zero_rule_a_planes` and `zero_rule_h_planes` are EMPTY at the toy for every
domain; and `grow_tests::the_slot_definitions_are_built_from_the_shape` now
counts the public tables slot by slot and requires the toy's count to be
unchanged while the rung's is exactly the twelve `pad::indicator_slots`
declares.

**The toy documentation test.** The same test now also answers the ruling's
question in full: the only two slots that touch a `Dom::L` plane at the toy
are `SC_LZC` (the whole domain, but only through the ungated LogUp arm) and
`SC_TZC` (nine fixed sub-slices `[k*t_pad, k*t_pad + t_pad)`), and since
`tokens == t_pad` at the toy those nine slices are EXACTLY the support — so
**no toy relation reads a padded position**, and a future relation that did
would fail the test.

**The closed forms.** `pad::indicator_table` builds the indicator from the
closed multilinear form where one exists and from the builder's support table
otherwise; `the_closed_forms_equal_the_tables` asserts the two agree entry for
entry at all three shapes, and the table stays the definition of record. Eight
of the rung's nine padded domains have a closed form (`Dom::L` has none, as
the memo says). **S9-F4 is NOT closed**: `Tab::Pub` still holds a
materialised vector on both sides, so this is an optimisation of the
CONSTRUCTOR only.

**The closest slot is unchanged**: toy 50, rung **72** (`SC_SZC`, with
`SC_FZC` tying it), 125M **117** (`SC_SZC`), and `L + 256 <= 512` holds on
every slot of every shape. The term itself is degree 3 in every host slot and
never raises a declared degree; the support factor raises exactly the eight
slots the degree table already declared.

### S9-F7 (new) — the memo's slot map is wrong for `Dom::Ht` and `Dom::T`

`indicator_slots` listed neither as carrying a table. Both are wrong and the
code is corrected:

* **`Dom::Ht` cannot ride on `supp_S`** (§3.7a open question 2). `supp_S` is
  zero wherever the `j` axis pads, so a term `(1 - supp_S) * A_MX` would force
  a TRUE row's maximum to zero. `Dom::Ht`'s two planes get their own group in
  `SC_SZC`, on a `supp_Ht` lifted over the trailing `j` axis (a public table
  over the `Dom::S` cube, constant in `j`). `host_rs` takes the same lifted
  factor and not `supp_S`, so `per_row` stays the full `t_pad`.
* **`Dom::T` has four ZERO-rule planes** by the memo's own table and no term
  at all was planned. Its host is `SC_TZC`, whose cube IS `Dom::T`.

The rung therefore materialises **twelve** indicator tables, not ten.

### S9-F8 (new) — gating a claimed sum forces gating its host

`SC_SS` / `SC_SSM`'s summands take `supp_D` (that is where blocking item B-1
lives), so a padded token row's claimed sum becomes 0. `SC_TZC`'s two host
terms say that sum equals `dsq + a1 - NORM_CEPS`, which at a zeroed padded row
is `-NORM_CEPS != 0`. They must therefore take `supp_T`. The memo's list of
gated slots ("the inhomogeneous clauses of `SC_DZC`, `SC_QZC`, `SC_KVZC`,
`SC_SZC`, `SC_FZC`") does not include `SC_TZC` and is incomplete. Gating them
costs no degree.

The symmetric question for the six MATMUL slots resolves the other way and is
recorded here so nobody re-opens it: their host terms ARE gated, but their own
summands are NOT, because the hosted value already vanishes on the pad — the
folded weight vector is zero off the support (ruling P-2) and the input plane
is zero at a padded row, so `supp(x) * host(x)` and the matmul output agree on
the whole cube.

### C2-F1 — recorded, no change (the security owner's ruling)

The soundness count uses the DRAWS (independent uniform samples) and the
privacy count uses the DISTINCT indices against the pad count, which the code
already checks. Nothing is deduplicated.

### S11a — the rung endpoints on the frozen seam

The three edits the ruling names, all inside the lane, with no change to
`private_seam.rs`:

1. `IoSpec` carries the endpoint plane's PADDED extent and builds both
   `SeamSpec`s from it (`new_shaped` beside `new`; the toy's `(T, D)` are
   unchanged, and `prepare_endpoints` checks `t_pad * d_pad` words).
2. `B::endpoint`'s terminal pair is `endpoint_rows - 5`, not the literal 2.
3. `endpoint_geometry` is `(rows, rows - 5, rows - 3)`, with the toy's frozen
   `(7, 2, 4)` asserted.

`Shape::rung()`'s endpoint parameters are corrected to what that route
actually gives: **21 commitment rows** (the padded `(32, 128)` plane is 4,096
words, exactly the seam's ceiling; `4096 / 256 = 16` data rows plus
`MASK_ROWS = 5`) and the seam's frozen **inverse rate 8**. The declared 14 and
4 were the TRUE shape's and matched nothing.

**The rung receipt is 4,218,264 B** — the Python model's 4,173,208 plus
45,056 B, because the model priced the endpoints at the TRUE `(24, 96)` plane
that `SeamSpec::new` refuses outright. **The Python model is NOT edited**, as
the ruling directs; the difference and its cause are recorded here and in
`grow_tests::MODEL_RUNG`'s comment, and the codec, `Shape::receipt_bytes` and
the Rust expectation all agree on the new number.

**The wire bound is per profile.** `MAX_WIRE_BYTES` keeps its name and its
4 MiB value as the TOY's bound and a toy frame over it is still refused. Every
other profile is bounded by its own `Shape::receipt_bytes().total` — the
number `decode` already requires equality with — under an absolute
`MAX_WIRE_BYTES_ANY = 64 MiB` ceiling, so no shape can ask for an unbounded
frame. The rung frame is **23,960 B over** the toy constant, which is why the
bound had to move at all; `the_codec_length_is_the_models_at_every_shape` pins
all of it.

**S11b is still owed and nothing at 125M may run before it.** 125M's endpoint
plane is 512 x 768 = 393,216 words, `log_len` 19 against the seam's
`MAX_LOG_LEN` 12: the frozen seam cannot carry it at all. A generalised
endpoint (C4/C5's `SeamSpecG`) must be built ADDITIVELY beside
`private_seam.rs`, and **the rung re-run with it** before anything runs at
125M.

### S12a — three bugs no earlier test could see

Each was reproduced by the end-to-end test before it was fixed. All three had
been invisible for the same reason: the slot-definition sweep BUILDS every
slot's polynomial at the rung and never EVALUATES it, and nothing else had
ever proved at a shape that is not the toy.

* **S12-F1 — `lk_tables` resolved shaped plane ids through the toy-indexed
  map.** `Layout::lookups` names its planes by SHAPED id; `a_range`'s `idx` is
  indexed by TOY id. They coincide at the toy and at every plane below the
  first growing limb group. At the rung the third `sigma_s` limb shifts every
  `Dom::F` and `Dom::Tab` plane by one and the index ran off the end
  (`index out of bounds: the len is 30 but the index is 18446744073709551615`).
  Fixed by resolving through `B::shaped`.
* **S12-F2 — the reserved mask pair was addressed at the toy's row width.**
  `build_claim` and `mask_eval` used the module constants `N` / `LOG_N`. The
  row width is the COMMITMENT's: `log_cols` (10 at the rung) for `A` and `H`,
  the seam's frozen 8 (carried as `endpoint_log_n`) for the two endpoints.
  Both are 8 at the toy. `audit_claims`' pair-exclusivity check caught it by
  name — **it was not relaxed**, and this is a concrete instance of why that
  check is the whole defence.
* **S12-F3 — `A_E`'s padded positions must be genuine exp-table rows.** The
  LogUp arm is never gated (§3.7a), so `protocol::exp_deltas` reads the WHOLE
  padded `Dom::S` cube, and the prover's histogram folds any pair that is not
  a table row into entry 0 where only the value-0 identity notices it. At a
  padded token row `A_MX` and `A_S8` are 0, so the pair is `(delta 0, e 0)`
  while `exp[0] = 2^F_E != 0`; the proof died at `H: pcs zk: group 8`. This is
  exactly why the memo's table EXEMPTS `A_E` (`pad::a_rule`). The witness
  builder now fills `A_E` over the whole cube from the committed `A_S8` with
  `exp_deltas`' own formula, which on a true position recomputes the value it
  already wrote — so the toy does not move by one word. **The two tests that
  asserted an all-zero pad now assert the memo's TABLE**: every ZERO-rule
  plane vanishes off its support and the one EXEMPT plane does not (and is
  asserted NOT to, so a regression to zeros fails loudly).

**A new test names this obligation once and for all**:
`rung_tests::every_rung_lookup_is_a_genuine_table_row` runs the prover's own
three "hit" conditions position by position and reports which lookup left its
table, with the coordinates and whether each axis is true or padded.

### S12a — what the rung now shows

* an honest rung proof verifies in typed form AND from bytes, in a fresh
  verifier call, with a one-byte-short frame refused;
* the frame is **4,218,264 B**, the wire format's own prediction;
* the ALL-ZERO hidden input proves and verifies at the rung, at the same frame
  length;
* PZ-1 and PZ-2 are rejected BY THE VERIFIER (slots 14 and 2);
* **27 tampers, one representative of every toy tamper family, on TRUE
  support positions so the pad rule is never what catches them, are all
  rejected by the verifier from the bytes**, each at the slot its relation
  lives in (the log prints which, so a tamper caught by the wrong relation is
  visible). The three histograms are the one family that cannot be expressed
  as a witness edit — the prover derives them — and stay a toy case;
* ruling P-5's half-`p` isqrt alias is rejected end to end on two `norm_a`
  rows, in the form `norm_alias` proves is the hard one: (R1), (R3), (R4) all
  hold in `F_p` and only the byte-limb reconstruction (R2) is false;
* diagnostics (shared box, NOT a measurement): prove 0.49 s, verify from bytes
  0.10 s, peak resident memory 74 MiB.

### Visibility widened this stage (each because a step required it)

| item | from | to | why |
|---|---|---|---|
| `mod pad` | `#[cfg(test)]` | library | `argument::define` now calls it |
| `protocol::lookup_values` / `act_indices` / `exp_deltas` | private | `pub(super)` | `every_rung_lookup_is_a_genuine_table_row` runs the prover's own hit conditions |
| `norm_alias::half_p_minus_one` / `to_plane` | private | `pub(super)` | the end-to-end alias tamper at the rung |
| `Receipt::to_bytes_at` / `from_bytes_at`, `verify_bytes_at`, `IoSpec::new_shaped` | new | `pub(crate)` | a rung receipt has to round-trip through bytes |

### NEXT: exactly what the next agent should do, in order

1. **A rung CAPTURE for the joint-view gate (finding C-F5).** The privacy
   tools need a schema-3 capture at the rung, and `native_capture.rs` — a
   FORBIDDEN file — hard-codes `pcs_params()` with no shape and
   `Commitment { .., log_cols: 8 }` as a literal. **The orchestrator must ask
   the integrator for a shape-parameterised capture writer**; this lane may
   not edit it. Until then nothing at the rung has been through the rank / CFS
   / disclosure tools, and **no privacy statement may be made about the rung**.
2. **S11b — the generalised endpoint**, built ADDITIVELY beside
   `private_seam.rs` (C4/C5's `SeamSpecG`), and **the rung re-run with it**.
   Nothing runs at 125M before that: the frozen seam refuses 125M's endpoint
   by `MAX_LOG_LEN` and the layout already refuses 125M by name for lack of
   NTT tables.
3. **The remaining tamper arms at the rung**: the two endpoint families
   (`block_output_cannot_be_chosen`, `an_output_endpoint_committing_xres1`)
   and the moved-multiplicity family, which needs a prover-side hook rather
   than a witness edit.
4. **S9-F4, still open for the security owner**: the closed forms are the
   CONSTRUCTOR but `Tab::Pub` still materialises a vector on both sides. At
   125M that is 168 MB of indicator tables on top of §7.1's 9.6 GiB and a
   verifier `eval_mle_ext` over 2^22 twice. Taking the closed form all the way
   into the polynomial would leave 0.26 MB.
5. Re-read the toy freeze gate before every commit: receipt 2,816,472 B, the
   literal schedule digest, and the empty-diff check must print nothing.

## Stage 8 (2026-09-20, 05:5x–): S11b, THE GENERALISED ENDPOINT

### The design note, written BEFORE any code (step 1 of the brief)

**What the generalised endpoint is.** Exactly the frozen seam's construction
— a hiding PCS commitment to the padded endpoint plane, laid out as `data`
rows of the plane's words followed by five reserved random rows, with the
terminal pair at `(data, data + 1)`, the proximity row at `data + 2`, one
opening per commitment and the owner consumed by value — with every
PARAMETER that `private_seam.rs` fixes as a module constant taken instead
from the `Shape`. Nothing about the argument, the claim shape, the audit or
the transcript order moves.

**The parameters, and where each comes from.**

| parameter | frozen `private_seam.rs` | generalised `endpoint_g.rs` |
|---|---|---|
| plane | `(rows, cols)`, both powers of two, `2 <= rows*cols <= 2^12` | `(t_pad, d_pad)` of the shape, both powers of two by `Shape::new`, `2 <= len <= 2^24` |
| row width | `LOG_COLS = 8` | `sh.endpoint_log_n` (10 at the rung-G profile, 14 at 125M) |
| inverse rate | `INV_RATE = 8` | `sh.endpoint_inv_rate` (4) |
| opened columns / pads | `CHECKS = 256` | `sh.opened_cols` (256 at every shape today) |
| data rows | `len / 2^LOG_COLS` | `len / 2^log_n` |
| commitment rows | `data + 5` | `data + 5` (unchanged) |
| NTT table | EXACTLY `NttTables::new(12)`, pinned by `check_ntt` | any canonical table that covers `log_n + log2(inv_rate)` |

**The rate: 4, not 8.** Three reasons, in order of weight.

1. **Rate 8 does not fit at either new shape.** The encoded domain is
   `2^(log_n + log2(inv_rate))`. At the rung-G profile `log_n = 10`, so rate
   8 needs `2^13` and `protocol::fits_the_ntt_tables` refuses it against
   `NTT_LOG = 12`; at 125M `log_n = 14` and rate 8 needs `2^17` against the
   `2^16` that rate 4 already needs. Rate 8 also doubles the encoded matrix,
   which §7.1 already prices at 9.6 GiB resident for one block.
2. **At rate 4 the endpoint stops being the weakest opening.** With the
   memo's own count (§2.2: message length `n + Q`, `rho = (n+Q)/(n *
   inv_rate)`, `delta = (1 - rho)/3`, soundness `(1 - delta)^Q`), the
   generalised endpoint gives **2^-96.15 per opening at the rung-G profile**
   (`n = 1024`, `Q = 256`, `rho = 0.3125`) — the SAME figure as the rung's
   own `A` and `H` openings (§9a's 2^-96.1, message 1,280 of 4,096) — and
   **2^-105.61 at 125M** (`n = 2^14`, `rho = 0.2539`), which is the figure
   §2.2 quotes for the whole 125M proof. The frozen seam at the rung's
   declared rate 4 and `n = 256` gives §9a's **2^-67.3**, and it is the
   weakest term in that receipt by thirty bits.
3. **It is the shape's own rate.** `Shape::new` defaults
   `endpoint_inv_rate` to `inv_rate` and `endpoint_log_n` to `log_cols`, so
   the rung-G profile takes the DEFAULTS and rehearses 125M's configuration
   exactly, instead of rehearsing a second set of parameters that 125M will
   not use.

Rows and bytes of that choice: rung-G endpoint **9 commitment rows, 4 data
rows** (against the frozen seam's 21 and 16), two endpoint openings
**335,872 B** against 319,488 B, so the rung-G frame is the rung's 4,218,264
**+ 16,384 = 4,234,648 B**. At 125M the padded plane is 2^19 words, **37
commitment rows, 32 data rows**, two openings **1,499,136 B**.

**Its own digest and its own label.** `DOMAIN = b"hashline/private-block/
general-endpoint/v1"` — 42 bytes, so neither of the two forbidden
domain-label lengths (C-H4': 28 and 35; the frozen seam's own
`b"experimental-private-seam/v1"` is 28, which is one reason the new label
cannot be a variation of it). `EndpointSpecG::digest()` hashes that domain,
the context, the plane axes, the two endpoint slots, `log_n`, `inv_rate`,
`checks`, `MASK_ROWS` and the scale — the frozen seam's field list with the
four constants replaced by values. A collision with `SeamSpec::digest()` is
impossible: the domain string differs and is absorbed first.

**What stays IDENTICAL, so that the privacy analysis carries over in form.**

1. `MASK_ROWS = 5` and their roles: two terminal mask rows at `(data, data +
   1)` published as `mask_rows`, the proximity row at `data + 2` published
   as `prox_mask_row`, and two further uniformly random rows above it. All
   five are drawn from the OS stream BEFORE the commitment.
2. The pad count equals the number of opened columns, through the same
   `ZkOpts::standard(&params)` whose `q_pad` IS `num_col_checks`.
3. The claim's reserved pair has the exact shape `(cm, cm.U)` on two adjacent
   rows, and the endpoint raises exactly ONE claim with three parts — the
   data slice, the pair row and the pair row + 1. The generalised endpoint
   adds NO claim and changes no coefficient: `argument::B::endpoint` already
   takes its `mask_row` from `sh.endpoint_rows - 5`, so only the row NUMBER
   moves.
4. The claim discipline: `protocol::check_endpoint_opening` (the endpoint's
   analogue of `audit_claims`, which cannot be used directly because an
   endpoint commitment does NOT end in its proximity pair — `prox + 2 = rows
   - 1`) checks the three part row-ranges and the nonzero coefficients, then
   replays the PCS challenge prefix through `check_opening_challenges`.
   Neither is relaxed, and both are already shape-driven.
5. One opening per commitment; the owner is consumed by value on success and
   on failure; fresh OS entropy per `prepare`, no seed, no data getter, no
   `Clone`.
6. The data region: the plane's words at the front of the matrix, zero fill
   to the data-row boundary, mask rows above — byte for byte the frozen
   seam's `prepare_with_rng` layout.

**Private items of `private_seam.rs` that this needs.** None is reachable,
and none is requested. The file's `DOMAIN`, `LOG_COLS`, `INV_RATE`, `CHECKS`,
`DEGREE`, `MAX_LOG_LEN`, `MASK_ROWS`, `SeamSpec`'s fields, `data_rows`,
`commitment_rows`, `check_ntt` and `prepare_with_rng` are all private. The
new module therefore DUPLICATES two small things, each with a comment citing
the original by file and line: the five-row mask budget (already duplicated
once, as `protocol::ENDPOINT_MASK_ROWS`) and the shape of `check_ntt`
(`private_seam.rs:164-182`), generalised from "exactly `NttTables::new(12)`"
to "a canonical table that covers the needed domain". Everything else it
needs — `pcs::commit_zk_owned`, `ZkOpts::standard`, `CommittedZk`'s
`mask_rows` / `prox_mask_row` fields, `ZkRng::from_os` — is already public
in `zkp-core`. **No change to `private_seam.rs` is required or made.**

**Which profile gets which endpoint.** A shape uses the frozen seam exactly
when the frozen seam can carry its declared endpoint — plane at most 4,096
words with power-of-two axes, `endpoint_log_n = 8`, `endpoint_inv_rate = 8`
— and the generalised endpoint otherwise. The toy and the existing rung
profile satisfy all four conditions and do not move by one byte; the new
rung-G profile and 125M fail them by their declared parameters. The rule is
a derivation rather than a flag so that a shape cannot silently declare
parameters the machinery it selects does not honour.
