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

**S9-F1 (the toy is NOT a no-pad shape, and the rule must be gated by
PROFILE).** The brief's standing condition is that at the toy nothing pads,
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

**S9-F2 (a prerequisite inside S9 that is not built: the head
permutation).** `witness::build_shaped` indexes query heads CONTIGUOUSLY
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

**S9-F3 (the memo's indicator formulas are 125M-only).** §3.7a gives
`supp_D = 1 - b9 b8` and friends as closed forms on a single axis. At the
**rung the token axis pads too** (24 of 32), so no rung indicator is a
single two-bit product: `supp_D` is `[t < 24] and [i < 96]`, a product of a
prefix predicate and a two-bit term. The memo's open question 1 (table
versus closed form) therefore has a different answer at the rung than at
125M, and the tables built here are the conservative form the memo prices.

## NEXT

**JOB K and S8 are DONE; S9 is PREPARED test-first and its term is NOT
built. 92 passed / 0 failed / 4 ignored on `--lib private_`
(`s9-run1.log:172`), 5 / 0 on the new
`private-block-kernel-shaped` crate, 10 / 0 (+1 ignored) on the frozen
`private-block-kernel` — its `11c01b2` counts — and 19 / 0 on
`private-model-kernel`. The toy receipt is 2,816,472 B and the pinned
schedule digest has not moved at any commit of any stage. Of the four
ignored tests, two are the pre-existing `capture::native_capture_saved_receipt`
gates (they need saved receipt paths) and two are **PZ-1 and PZ-2**, left
ignored ON PURPOSE with their failure captured at `s9-pz-failing.log:83`
and `:89`.**

**FIRST, for the orchestrator:** delete
`private-block-kernel/src/shaped.rs` and
`private-block-kernel/src/shaped_tests.rs`. They are unreferenced and do not
enter any build, but until they are gone
`git diff --stat 11c01b2 -- private-block-kernel private-model-kernel
zkvm-block` is not empty and job K's acceptance is not literally met.

The next agent **finishes S9**. The S9 section above says exactly what
exists. In order:

1. **The head permutation (finding S9-F2), first** — nothing in the
   `Dom::Q` / `Dom::S` indicators is correct until the builder's head
   layout is the interleaved one. It moves `witness::build_shaped`'s head
   indexing, `Geom::support(Dom::Q | Dom::S | Dom::Ht)`, the parity
   comparison's map, `SC_WO`'s folded weight order and P-2's
   "not head-permuted" construction refusal together. The failing test is
   already written: `pad::tests::the_memos_head_layout_is_not_yet_the_builders`
   asserts the two DISAGREE, so it must be inverted when the permutation
   lands.
2. **The profile gate (finding S9-F1)** — the pad rule is carried by a
   profile, never by "does this domain pad", or `Dom::L` puts a term in the
   toy's `SC_LZC` and every toy byte moves.
3. **P-2, the public weights**, which is buildable TODAY and needs no
   receipt: a construction-time check in `AttentionPublic::new_shaped` /
   `FeedForwardPublic::new_shaped` that every folded weight vector vanishes
   off the DESTINATION axis's support, plus the second case (a matrix that
   is not head-permuted) refused by name.
4. **The term itself** in `argument::define`, with its `mu_pad`, its one
   fresh `ζ` refused on zero (witness-independently), the support factor on
   the inhomogeneous groups, the host terms, `SC_SS` / `SC_SSM` and
   `SC_RS`, and the exemptions excluded from those summations. Then
   re-check `L + 256 <= 512` on every slot and ASSERT what you get (the
   memo counts the closest at `L = 117`).
5. Un-ignore **PZ-1** and **PZ-2** at S12, when S10 (the column count) and
   S11 (the hidden endpoints) make a rung receipt constructible — finding
   **S6-F5** says exactly what is and is not exercisable before then.

Still waiting on the security owner, none of them blocking S9:

* **S8-F3** — `Witness::output()` reads `A_X2` as a literal; a fifth norm
  limb is refused by name rather than supported. Fix is one field when a
  shape needs it.
* **S8-F6 / P-5** — the alias tampers are discharged at the relation level
  at the rung; the END-TO-END form at a new profile is owed again at S12.
* **S5-F1 / B-F3** — the 176-byte rung-receipt difference two independent
  implementations report against §9a's table (`SC_KVZC`'s support
  indicator). S9 is the step that decides it: if `supp_Kv` gates
  `SC_KVZC`'s inhomogeneous RoPE constraint, the rung receipt is
  4,173,208 B.
* **S1-F1** — a one-line correction to §1.3 T-1 and the §9 S1 row
  (`argument.rs:898` is `Dom::Tab.len()`, not the table size).
* **S3's decision 2** — the narrower input class; it changes the 125M
  `Dom::D` lookup list and so the `H` row total (C-6).
* **K-F2** — finding S6-F3 no longer needs a ruling for the zkVM image.

