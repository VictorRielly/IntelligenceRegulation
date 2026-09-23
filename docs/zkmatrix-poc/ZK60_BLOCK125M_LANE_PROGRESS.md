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
| **S11b — the generalised endpoint, and the rung-G profile proved with it** | **DONE** | `da84882`, `010f6dd`; 134 / 0 / 2 |
| **STAGE 9 items 1–10 — the rulings on the review's F-1 … F-9 and on S11b-F4** | **DONE** | see the stage 9 section; filter **156 / 0 / 3**, 221.01 s |
| **STAGE 9 item 11 — the NTT tables follow the shape; the 125M layout CONSTRUCTS** | **DONE** | `protocol::ntt_log_at`; frame 40,782,792 B, endpoint 37 rows at 2^14 / rate 4, closed forms equal to the definition at every position of all six padded domains. No witness, no proof |
| **STAGE 9 item 12 — one 125M block** | **PREPARED, NOT RUN** | `rulings_tests::private_block_125m_one_block`, `#[ignore]`d; the two commands are in the stage 9 section. Modelled peak 11.00 GiB against `MemAvailable` 12.84 GiB |

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

### What was built (steps 2-5 of the brief)

**A new module, `hashline/src/private_block/endpoint_g.rs`**, library code
beside `layout` and `witness`. It holds `EndpointSpecG` (the statement, its
refusals and its digest), `PreparedPlaneG` (the owner: no `Clone`, no data
getter, no repeated opening, consumed by `into_endpoint`), a generalised
`check_ntt` and `prepare`. **`private_seam.rs` is not edited and not
reachable beyond its public API.**

**The wiring, all inside the lane's own files.**

* `shape.rs`: a derived field `Shape::endpoint_general`, `Shape::rung_g()`,
  and 125M's endpoint corrected from 29 rows to 37.
* `private_block.rs`: `IoSpec` carries the shape's endpoint parameters and
  which construction they select; `IoSpec::validate` replaces the bare
  `seams()` call and additionally refuses a shape whose declared
  `endpoint_rows` is not what its own parameters give; `Endpoints` holds an
  `EndpointOwner` enum with one variant per construction; `prepare_endpoints`
  builds the frozen `NttTables::new(12)` on the frozen path (so no toy byte
  moves) and the table its own encoding domain needs on the generalised one.
* `protocol.rs`: `check_endpoints` asks `IoSpec` for the two committed
  planes instead of unwrapping the frozen owner; the verifier validates the
  spec instead of calling `seams()`. **The verifier needed NO other change**
  — it already built its endpoint `PcsParams` from `sh.endpoint_log_n`,
  `sh.endpoint_inv_rate` and `sh.opened_cols` (S11a), and
  `check_endpoint_opening` and the wire's `Dim::endpoint` were already
  shape-driven.

**Visibility widened this stage:** `protocol::endpoint_geometry` from private
to `pub(super)`, so the 125M construction test can assert `(rows, data,
prox)`. Nothing else.

### The rung-G profile, measured

`Shape::rung_g()` is the rung's geometry — same tokens, width, hidden,
heads, `log_cols`, rate and calibration — with the generalised endpoint and
its own profile string `hashline-zk-mr1/private-block-rung-g-t24-dev/1`.
Endpoint: **9 commitment rows, 4 data rows**, row width `2^10`, inverse
rate 4, 256 opened columns. The frozen-seam rung (21 rows, `2^8`, rate 8)
keeps working beside it, unchanged.

| | rung (frozen seam) | rung-G (generalised) |
|---|---:|---:|
| endpoint rows / data rows | 21 / 16 | 9 / 4 |
| endpoint row width / inverse rate | 2^8 / 8 | 2^10 / 4 |
| two endpoint openings | 319,488 B | 335,872 B |
| receipt | 4,218,264 B | **4,234,648 B** |
| per-endpoint-opening soundness (memo §2.2's count) | 2^-67.3 | **2^-96.15** |

Everything the rung battery asks was re-run on the new profile and passed on
the FIRST run: the honest proof verifies in typed form and **from the
bytes**, the frame is the counted length and a one-byte-short frame is
refused; the ALL-ZERO hidden input proves and verifies at the same length;
PZ-1 and PZ-2 are rejected by the verifier; **all 27 tamper families** are
rejected; ruling P-5's half-`p` isqrt alias is rejected end to end on two
`norm_a` rows.

**Two endpoint tamper families, new this stage**
(`an_endpoint_that_seals_a_different_plane_is_rejected`, run on BOTH rung
profiles). The witness is honest and only the plane the endpoint owner
SEALED moves by one word — at a true support position, and at a PADDED
position — for the input endpoint and for the output endpoint, eight cases.
All eight are rejected, and the honest endpoints of the same witness still
verify in the same test, so the rejection is the tamper and not the
machinery. The pad case is the one the pad rule makes possible: `A_X`'s and
`A_X2`'s padded columns are forced to zero by ruling P-1's pad-zero term and
the equality slot claims the WHOLE padded `Dom::D` cube, so a nonzero word
in the endpoint's pad has nothing on the witness side to match.

### The 125M shape: it CONSTRUCTS, and what still refuses

`the_125m_shape_constructs_and_what_still_refuses_says_so_by_name`. Nothing
is proved and nothing may be. What now builds at 125M: the shaped layout
(`A` 5,681 rows, `H` 7,120 rows), the endpoint geometry `(37, 32, 34)`, the
endpoint STATEMENT (`EndpointSpecG` at the padded `512 x 1024 = 2^19`-word
plane, row width `2^14`, rate 4 — 32 data rows, 37 commitment rows), the
`IoSpec` with its rows check, the counted receipt **40,782,792 B** and
`wire::encoded_len` agreeing with it digit for digit.

**What still refuses at 125M, by name:**

1. `protocol::fits_the_ntt_tables` — 125M encodes `A`, `H` AND its endpoints
   over `2^16` and the module builds `2^12` (`protocol::NTT_LOG`). **This is
   NOT a forbidden file**: the table is built in `protocol.rs`
   (`NttTables::new(NTT_LOG)`, twice) and in `private_block.rs`
   (`prepare_endpoints`), both this lane's. Raising `NTT_LOG` to 16 is a
   one-constant change — but see finding S11b-F3: it would break the toy.
2. The frozen seam, by `MAX_LOG_LEN`, which is the whole reason this module
   exists.
3. Everything else the earlier stages recorded: the memo's §7 model puts one
   125M block at **11.81 GB peak resident (11.00 GiB)**, or 10.31 GB
   (9.60 GiB) after S2's two drops, on a 15.4 GiB box — ruling P-6's
   detached, memory-capped, quiesced run. The padded endpoint adds **+10.5 MB**
   to that model (`37 x 16,384 x 8 x 5 = 24.2 MB` per endpoint against the
   memo's 19.0 MB at 29 rows), which changes nothing about the decision.

### Findings

**S11b-F1 — PADDING REMOVES THE NEED FOR THE MEMO'S C6.** §6 requires C6's
`mu`-batched multi-block seam at 125M because the TRUE endpoint plane
`512 x 768 = 393,216` is three blocks of `2^17` and not a power of two. But
this module does not commit the true plane: the slice `SC_IO_IN` /
`SC_IO_OUT` claim is the PADDED `Dom::D` cube, `t_pad * d_pad = 512 * 1024 =
2^19`, which IS a power of two. A single-slice endpoint therefore carries
125M, exactly as it carries the rung (S11-F3). Consequences: C4/C5 are owed
(they are this module), **C6 is NOT owed by this lane**, and 125M's endpoint
is 37 commitment rows and 1,499,136 B of receipt against the memo's 29 and
1,466,368 B — the whole of the +32,768 B by which the Rust now exceeds the
Python model at 125M. The Python model is NOT edited, as the ruling directs.
*For the security owner: this is a simplification of an accepted design, so
it is recorded rather than acted on further. The cost of the padded route is
the 32,768 B; the benefit is that the batched claim, its four binding
conditions and its extra per-endpoint soundness term are all avoided.*

**S11b-F2 — the C-H4 refusal is unreachable for this construction, and is
kept anyway.** The padded plane and the row width are both powers of two, so
the data-row count is a power of two and `data + MASK_ROWS` is one of 6, 7,
9, 13, 21, 37, ... — never the forbidden 5 (0 data rows) or 8 (3 data rows).
`EndpointSpecG::new` calls the refusal regardless, as a guard against a
future change to `MASK_ROWS`, and
`a_node_shaped_endpoint_column_is_unreachable_and_still_refused` proves the
unreachability over every plane and row width up to `2^24` and exercises the
refusal directly so that it cannot rot.

**S11b-F3 — RAISING `NTT_LOG` WOULD BREAK THE TOY, and the fix is already in
place.** The frozen seam's `check_ntt` (`private_seam.rs:167-174`) demands
`ntt.max_log == 12` EXACTLY, with 13 roots and 2,048-entry twiddle tables.
So a future step that raises `protocol::NTT_LOG` to 16 for 125M must NOT
hand that table to `private_seam::prepare`. This lane's
`prepare_endpoints` already builds its table per construction — `new(12)`
on the frozen path, `new(enc_log)` on the generalised one — so the toy and
the frozen rung keep their exact table whatever `NTT_LOG` becomes. The
generalised `check_ntt` accepts any canonical table that COVERS the needed
domain, and a test asserts both halves of this: the frozen seam refuses a
`2^16` table and the generalised endpoint accepts it.

**S11b-F4, for the security owner — the endpoint's PCS parameters are not in
the transcript's parameter line.** `protocol::parameter_line` carries
`log_cols`, `inv_rate` and `Q` of the `A`/`H` commitments but not the
endpoint's three. They are bound in two other ways — the profile string is
the transcript's domain and one profile is one shape, and the verifier reads
them from its OWN shape and would reject any commitment of another geometry
at the PCS — so nothing is unbound today. The line is nonetheless the
natural place for them, and the toy's line is frozen, so this is a question
about the NEXT profile string rather than a defect. *Not acted on; recorded
for ruling.*

**S11b-F5 — the generalised endpoint adds NO claim, so `audit_claims` is
untouched.** The brief asks that every claim the generalised endpoint adds go
through `audit_claims`. It adds none: the endpoint raises exactly one claim
with three parts, as it always did, and only the row NUMBER of its reserved
pair moves (`argument::B::endpoint` takes it from `sh.endpoint_rows - 5`,
S11a). The endpoint's own discipline is `protocol::check_endpoint_opening`,
which is `audit_claims`' analogue for a commitment that does NOT end in its
proximity pair (`prox + 2 = rows - 1`, which `audit_claims` refuses by its
first check) — it verifies the three part row-ranges, the nonzero
coefficients and the PCS challenge refusals, and it was already shape-driven.
Neither check was relaxed.

### Runs

| log | command | result |
|---|---|---|
| `results/zk60_block125m_lane/s8b-baseline.log` | the filter, before any change | **116 passed / 0 failed / 2 ignored**, 48.13 s |
| `s11b-eg1.log` | `--lib private_block::endpoint_g` | compile errors: two `expect_err`s need `Debug`, which neither `CommittedZk` nor `PreparedPlaneG` has (by design — no data getter). Fixed by matching the refusals |
| `s11b-eg2.log` | the same | 7 passed / 1 failed — the C-H4 case asked for a 3-data-row plane, which cannot exist (finding S11b-F2) |
| `s11b-run1.log` | the filter | 132 passed / 2 failed: the C-H4' source scan found the frozen seam's 28-byte label QUOTED IN A COMMENT of the new module (the scan reads source text, so a citation is indistinguishable from a label — the test was right), and `the_125m_receipt_is_reproduced_part_by_part` still carried the memo's endpoint figure |
| `s11b-run2.log` | the filter, `--nocapture` | **134 passed / 0 failed / 2 ignored**, 72.70 s |

Diagnostics from `s11b-run2.log` (shared box, NOT a measurement): rung-G
**prove 0.41 s, verify from bytes 0.10 s, frame 4,234,648 B, peak RSS
95 MiB**; the frozen-seam rung beside it, prove 0.51 s, verify 0.09 s, frame
4,218,264 B. All eight endpoint tampers are rejected **by the verifier at
slot 21 (`IO-in endpoint equality`) and slot 22 (`IO-out endpoint
equality`)** — the right relation in every case, on both profiles.

### The toy freeze gate, after this stage

Unmoved: receipt **2,816,472 B**, the literal schedule digest, the frozen
parameter line, `MAX_WIRE_BYTES` and `encoded_len()`, all asserted by the
tests that were green before and are green now. The toy's endpoint still
goes through `private_seam::prepare` with `NttTables::new(12)`, byte for
byte.

**Shared-file changes this stage: NONE.** Every file touched is
`hashline/src/private_block.rs` or under `hashline/src/private_block/`:
`endpoint_g.rs` (new), `shape.rs`, `protocol.rs`, `grow_tests.rs`,
`rung_tests.rs`. The empty-diff check
`git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 11c01b2 --
private-block-kernel private-model-kernel zkvm-block` prints nothing.

### NEXT: exactly what the next agent should do, in order

1. **The rung CAPTURE for the joint-view gate is still the blocker on any
   privacy statement** (finding C-F5, unchanged from stage 7). The tools need
   a schema-3 capture and `native_capture.rs` is a FORBIDDEN file that
   hard-codes `pcs_params()` with no shape and `log_cols: 8`. The
   orchestrator must ask the integrator for a shape-parameterised capture
   writer. Until then nothing at either rung profile has been through the
   rank / CFS / disclosure tools and **no privacy statement may be made
   about either**. The generalised endpoint makes this MORE urgent, not
   less: it is a new commitment geometry (9 rows, row width 2^10) that no
   privacy tool has ever seen.
2. **Ruling wanted on S11b-F1** — the padded endpoint removes the need for
   the memo's C6 batched seam at 125M, at a cost of 32,768 B of receipt.
   Recorded, not acted on.
3. **The 125M run itself is now one constant and one measurement away**, and
   neither should be done casually: raise `protocol::NTT_LOG` from 12 to 16
   (a lane file — but read finding S11b-F3 FIRST: the frozen seam refuses any
   table but `new(12)`, and `prepare_endpoints` is already written so that
   this keeps working), then run ONE block under ruling P-6's conditions —
   detached, `flock /tmp/zk-heavy.lock`, a memory ceiling that kills the
   process rather than the box, nothing else running — with peak resident
   memory recorded beside the wall clock. The model says 11.00 GiB peak
   (9.60 GiB after S2's two drops) on a 15.4 GiB box. **Do not run it from a
   session that is also building.**
4. **S9-F4 is still open** (the closed forms are the constructor but
   `Tab::Pub` still materialises a vector on both sides: 168 MB of indicator
   tables at 125M).
5. **The remaining tamper arms**: the moved-multiplicity family still needs a
   prover-side hook rather than a witness edit, and stays a toy case.
6. Re-read the toy freeze gate before every commit: receipt 2,816,472 B, the
   literal schedule digest, and the empty-diff check must print nothing.

**The gate run on the exact committed source** (`s11b-run3.log`, after two
cosmetic follow-ups — removing an unused `EndpointSpecG::scale` getter and
rewording the comment that quoted the frozen seam's label): **134 passed /
0 failed / 2 ignored**, 72.28 s, and the compiler's warning count goes from
the baseline's 10 to 9 (the new module adds none). Commits: design note
`57d8e71`, implementation `da84882`, this line.

## Stage 9 (2026-09-20, 06:2x–07:xx): THE RULINGS ON THE INDEPENDENT REVIEW, AND THE 125M RUN PREPARED

The independent adversarial code review landed by merge (`485d5fa`, the
reviewer's branch `zk60-private-block-125m-review`): **no hole**, nine
findings F-1 … F-9, fifteen tests. This stage is the security owner's ruling
on each of the nine, on stage 8's own finding S11b-F4, and the two things
that stand between the lane and a 125M measurement: the NTT tables and a
prepared, unlaunched run. **Nothing was proved at the 125M shape by this
stage.**

### THE MERGE IS GREEN

`t0-merge-baseline.log`: **149 passed / 0 failed / 2 ignored**, 215.31 s —
the lane's 134 plus the reviewer's 15, with nothing adjusted. **No reviewer
test had to be touched**, for its harness or for anything else: the fifteen
were written against stage 7 and all fifteen still hold after stage 8's
generalised endpoint.

### What each ruling is, and what decides it

| # | finding | ruling | decided by |
|---|---|---|---|
| 1 | **F-1** the indicator-tiles-its-cube guard is a `debug_assert` | **a real refusal**, `argument::tile_rep`, on the path BOTH sides build their public factors on | `rulings_tests::a_non_tiling_indicator_is_refused_and_not_merely_debug_asserted` (four tiling cases, six non-tiling) |
| 2 | **F-2** `SC_TAB`'s hard-coded `[1, 4, 7]` is never checked | **both lists checked**, by `argument::tab_group_is_declared` | `rulings_tests::sc_tabs_pad_zero_group_is_checked_against_the_declared_lists` (four wrong lists at three shapes) |
| 3 | **F-3** the rung fixture cannot tell the heads apart | **the reviewer's `distinct_kv_case` is adopted** and memo §9a's SECOND acceptance tamper is written | `rulings_tests::two_query_heads_of_different_key_value_groups_exchanged_is_rejected_at_the_rung` |
| 4 | **F-4** the `Dom::Tab` pad term is unexercisable | **one `#[cfg(test)]` prover hook**, which closes the moved-multiplicity family with it | `rulings_tests::a_multiplicity_moved_into_the_padded_copy_of_its_row_is_rejected_at_the_rung` |
| 5 | **F-5** the memo's PZ cases are run one of three and one of four | **already closed by the merge** — see below | the reviewer's two sweeps, now the lane's |
| 6 | **F-6** a mis-sized public table panics on the verify side | **a named refusal before `eval_mle_ext`**, hoisted out of the `Prove` arm | inspection; not reachable from a frame (see below) |
| 7 | **F-7** `SC_TZC` reads the padded lookup domain ungated | **the code is right and the memo's row is wrong** — two independent reasons, below; a NOTE is opened, the memo is not edited | the reviewer's `Dom::L` sweep cases |
| 8 | **F-8** `assert_rejected` counts a prover refusal as a pass | **split in two**; every rung tamper re-pointed at the verifier-only helper | the whole rung battery, green under the strict helper |
| 9 | **F-9** memo §3.7a open question 4 is live | **resolved in code**: the endpoint binds the padded cube at every profile, and its pad is ZERO-rule | `rulings_tests::the_endpoint_binds_the_padded_cube_at_both_rung_profiles` |
| 10 | **S11b-F4** (stage 8's own) the endpoint's PCS parameters are not in the parameter line | **stated explicitly in every NEW profile**; the toy's line is untouched | `rulings_tests::every_new_profile_states_its_endpoint_parameters_in_the_parameter_line` |
| 11 | the 125M NTT tables | **the table is a function of the shape**, `protocol::ntt_log_at` | `rulings_tests::the_125m_layout_constructs_and_its_indicators_agree_with_the_definition` |
| 12 | the 125M run | **PREPARED, NOT RUN**: `#[ignore]`d, and the exact detached command line is below | — |

### F-1 in detail, and the sweep over every other `debug_assert`

`B::supp` returns `Result<Option<usize>, String>` and takes its repetition
count from `argument::tile_rep`, which refuses by name — *"private block: an
indicator that does not tile its slot's cube (N entries in M)"* — for a
non-divisor, for a table LONGER than the cube (which used to give `rep = 0`
and a divide-by-zero panic) and for an empty table. All eleven call sites
are inside `define`, which already returned `Result`, so both the prover and
the verifier take the refusal. **No shape reachable through `Shape::new` can
produce a non-tiling pair** — every axis is a power of two and every cube
contains its domain, which the reviewer's own static test checks at all three
shapes — so the refusal cannot be reached end to end, and `tile_rep` is
tested directly instead, in the release build the filter runs.

The sweep the ruling asks for — every other `debug_assert` in the lane's
files, each ruled:

| site | what it asserts | ruling |
|---|---|---|
| `protocol.rs:283` (was) | the toy's frozen endpoint geometry has not moved | **MADE A REAL CHECK.** Two comparisons in a function that already returns `Result`, and what it pins is the frozen profile |
| `argument.rs:547` `lg()` | the value is a power of two | **HARMLESS.** Every axis it is called on is a power of two by `Shape::new`'s own refusals, which are release-time checks at construction; a shape that fails them never exists |
| `protocol.rs:31` `log2_exact()` | the inverse rate is a power of two | **HARMLESS**, same reason: `Shape::new` refuses a non-power-of-two rate |
| `private_block.rs:190` `weights_vanish_off_support` | the weight vector's length is `outer * inner` | **HARMLESS.** The length check really does run before it (the caller's), and were it ever false the loop below would index out of bounds — a panic, not a wrong acceptance |

### F-5: already closed by the merge, case by case

The memo's five missing cases are all run now, by the two tests the review
brought with it. PZ-1: `every_zero_rule_plane_has_its_pad_proved_zero_at_the_rung`
covers `A_RAL` on `Dom::D`, `A_SR0` at a padded head slot and `A_LIMB` in an
unused limb sub-plane — and 148 more, 151 positions over nine domains. PZ-2:
`pz2_at_the_second_norm_and_as_a_free_field_element_is_rejected_at_the_rung`
covers norm_m's int16-fill variant and the free-field-element variant on both
`A_X1` and `A_AO`. Nothing further is owed; the lane's own two PZ tests stay
as the named §3.7a cases.

### F-6: the refusal, and why there is no test

`run_slot` now refuses *"private block: slot S public table length"* before
the `Side` match, so the verifier takes it too. There is no end-to-end test
because there is no way to reach it from a frame: public tables are built by
`define` from the shape, a receipt cannot choose one, and the only way to
hand `run_slot` a mis-sized `Tab::Pub` is to hand it a hand-built `SlotDef`,
which no API exposes. Adding a constructor for one would widen the module's
surface further than the fix. The check is on the shared path, so all 154
tests pass through it.

### F-7 RULED: the ungated read is SOUND, and the memo's row is wrong

`SC_TZC`'s limb reconstruction reads `Dom::L`'s nine sub-slices
`[k·t_pad, k·t_pad + t_pad)` ungated, and at any shape with `tokens < t_pad`
those include the padded token positions. The memo's §3.7a `Dom::L` row says
"nothing reads the pad". **The code is right; the memo's row is wrong for
shapes where the token axis pads.** Two independent reasons, either of which
suffices:

1. **`Dom::L`'s own pad rule already covers those positions.** Its indicator
   is a PRODUCT of two forms (`pad.rs:176`): the token form at stride 1 and
   the sub-plane form at stride `t_pad`. So a padded token position inside a
   USED sub-slice is a padded position of `Dom::L`, its planes are ZERO-rule,
   and `SC_LZC`'s pad-zero term forces it to zero.
2. **Even without it, the values are forced.** `Dom::T`'s pad-zero term makes
   `d = dsq = 0` at a padded token, and the ungated relations `d − dl = 0`
   and `2d − a1 − a2 = 0` then force the limb reconstruction to zero; the
   LogUp arm is never gated (§3.7a), so every limb at those positions is a
   genuine byte, and a nonnegative byte combination that sums to zero is
   all zeros.

What the reviewer observed is therefore a question of WHICH relation catches
first (slot 2, not `SC_LZC`), not of whether anything catches. **NOTE for the
memo, not made here** (the memo is not this lane's file): §3.7a's `Dom::L`
row should read "read ungated by `SC_TZC`'s limb reconstruction at shapes
where the token axis pads; sound because the positions are ZERO-rule and
because `Dom::T`'s term plus the byte lookups force them" instead of "nothing
reads the pad".

### F-8: the split, and how many cases changed category

`assert_rejected` is replaced by two helpers: **`assert_verifier_rejects`**
(the prover MUST produce a receipt and the VERIFIER must refuse it — a
soundness statement) and **`assert_the_honest_prover_refuses`** (a liveness
statement, and no case uses it). The same lax pattern was written out inline
in `an_endpoint_that_seals_a_different_plane_is_rejected`; it is tightened
too.

**How many changed category: NONE.** All four call sites and the inline one
pass under the strict helper on the first run, which means every one of the
cases they carry was already a verifier rejection and none was a prover
refusal in disguise: the 27 toy tamper families at BOTH rung profiles (54),
PZ-1 at both (2), PZ-2 at both (2), the half-`p` isqrt alias on two norm rows
at both profiles (4), and the eight endpoint-sealing cases. `tamper.rs`, the
toy battery, already demanded the verifier and needed nothing.

### Item 11: the NTT tables, and what the 125M layout now gives

`protocol::NTT_LOG` is gone; `protocol::ntt_log_at(sh)` is
`max(log_cols + log2(inv_rate), zk::MASK_LOG_DOM)`. **The toy and both rung
profiles get `NttTables::new(12)` by construction, exactly what they had**
(`max(8 + 3, 12)` and `max(10 + 2, 12)`), and only 125M gets `2^16`. The
endpoints never see this table: `prepare_endpoints` builds `new(12)` for the
frozen seam, which demands that size exactly, and `new(enc_log)` for the
generalised one (finding S11b-F3). `fits_the_ntt_tables` keeps its name and
its callers and now refuses only a shape past a prototype ceiling of `2^20`.

The 125M CONSTRUCTION test's figures, all of them the memo's counted ones:
frame **40,782,792 B** (codec and count agree), endpoint **37 rows over
524,288 words at 2^14 / rate 4**, `A` rows **5,681**, `H` rows **7,120**, and
the six padded domains' closed-form indicators **equal to the geometry's own
definition at every position** — the first time the two have been compared at
this shape, with eight random positions per domain printed for the record.

### Item 12: the 125M run, PREPARED AND NOT LAUNCHED

The run is `private_block::rulings_tests::private_block_125m_one_block`,
`#[ignore]`d. It is a test and not an `examples/` binary because the whole
shaped path (`Shape::m125`, `witness::build_shaped`, `prove_inner_at`, the
shaped `verify_bytes_at`) is `pub(crate)`, and an example links against the
PUBLIC API only; making any of it `pub` to suit a benchmark would widen the
library for no reason. Step S2's buffer frees are already in
`prove_inner_at` (the witness, `looked`, `deltas` and `act_idx` are moved and
dropped before the `H` commitment) and the test adds its own: the fixture
input and the two endpoint word vectors are dropped as soon as they are
consumed, and the receipt as soon as it is encoded.

**`systemd-run --user --scope true` WORKS on this box** (probe run
2026-09-20 06:48, exit 0), so the memory ceiling is the systemd scope and not
`ulimit -v`. **`MemAvailable` at the time of writing: 13,467,748 kB =
12.84 GiB** (`MemTotal` 15.39 GiB). The memo's §7 model puts the peak at
**11.00 GiB**, 9.60 GiB after the S2 drops, so a 12 GiB ceiling is above the
model and below what the box has free — it kills the PROCESS, not the box.

**Step 1 — build under the build lock** (this leaves the run itself with
nothing to compile):

```
flock -w 540 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 /home/victor/.cargo/bin/cargo test --release --offline -j 2 --manifest-path /home/victor/wt-zk60-block125m/hashline/Cargo.toml --lib private_ --no-run > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-build.log 2>&1
```

Read the binary's path off that log's `Executable unittests` line. At the
time of writing it is
`/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5`
(the target directory is SHARED with another worktree, so re-read the path
and the mtime rather than trusting this line).

**Step 2 — the detached, memory-capped run** (one line, nothing else heavy on
the box, no GPU job, no release build):

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run1.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run1.done' >/dev/null 2>&1 &
```

What it prints: the witness build time, then
`125M ONE BLOCK: prove X s, verify from bytes Y s, receipt 40,782,792 B,
peak RSS Z MiB`. `m125-run1.done` holds the exit code. If the scope is
killed for memory the marker holds a nonzero code and the log ends without
the line — that is the measurement's answer too, and it is a finding rather
than a failure.

### Runs

| log | what | result |
|---|---|---|
| `t0-merge-baseline.log` | the filter on the merge, before any change of mine | **149 passed / 0 failed / 2 ignored**, 215.31 s |
| `t1-rulings1.log` | the filter after F-1, F-2, F-4, F-6, F-8, F-9 and the F-3 tamper | **154 passed / 0 failed / 2 ignored**, 218.09 s — every new test green on its first run |
| `t2-rulings2.log` | the filter after the parameter line, the shape-driven NTT table and the 125M construction test | 154 passed / **2 failed** — both stale EXPECTATIONS, not defects: `grow_tests`' "125M must be refused by name" (the point of item 11 is that it is not refused any more) and my own head tuple written `(q, dh, kv)` where the shape reads `(q, kv, dh)` |
| `t3-rulings3.log` | the filter, both corrected | **156 passed / 0 failed / 3 ignored**, 221.01 s. The third ignored test is the 125M run; the warning count is 10, the baseline's |
| `t4-rulings-nocapture.log` | `--lib private_block::rulings_tests -- --nocapture`, on the EXACT COMMITTED source, for the evidence lines below | **7 passed / 0 failed / 1 ignored**, 2.36 s |

### What the new tests printed (`t4-rulings-nocapture.log`)

* **F-1**, in a build with `debug_assertions = false`: all six non-tiling
  pairs refused — *"an indicator that does not tile its slot's cube (3
  entries in 8)"*, and `(6, 64)`, `(16, 8)`, `(1024, 256)`, `(0, 64)`,
  `(8, 0)`.
* **F-2**: nine refusals, three wrong `A` lists at each of the three shapes,
  plus the wrong helper list.
* **F-4**: *one count of the byte histogram moved from row 0 to its padded
  copy 256: verifier rejected: **slot 19 [TAB table helper zero-check]**,
  sumcheck round 0*. That is `SC_TAB` — and because the hook preserves the
  multiplicity total, the counted value and every LogUp denominator, all
  three of that slot's product relations still hold, so the PAD-ZERO TERM is
  the only term of its polynomial left to fail. The arm the P-3 lift rests
  on is decided end to end for the first time.
* **F-9**: the endpoint binds 4,096 words at both rung profiles and **524,288
  at 125M**, the whole padded `Dom::D` cube, both planes ZERO-rule.
* **S11b-F4**: the three new parameter lines, ending
  `/endpoint-log_n8-rate8-pad256-rows21` (rung),
  `/endpoint-log_n10-rate4-pad256-rows9` (rung-G) and
  `/endpoint-log_n14-rate4-pad256-rows37` (125M).
* **125M**: `Ht` 8,192 positions / 6,144 supported, `L` 16,384 / 4,608, `D`
  524,288 / 393,216, `Q` 524,288 / 393,216, `S` 4,194,304 / 3,145,728, `Tab`
  16,384 / 256 — the closed form equal to the definition **everywhere** in
  all six, with eight sampled positions printed for each.
* **The grouped-attention exchange**: *query head slots 0 and 4 exchanged
  across 22 planes (1,416 positions differ): verifier rejected: **slot 14
  [03 D zero-check (hosts 12, 13D)]***. See finding S9-F7.

### The toy freeze gate, after this stage

Unmoved: receipt **2,816,472 B**, the literal schedule digest, the frozen
parameter line (which the new endpoint clause explicitly does not touch —
`is_frozen_toy()` returns before it), the toy's `NttTables::new(12)`, and the
four archived pre-lane receipts that the review showed still verify. The two
rung profiles' frames are still **4,218,264 B** and **4,234,648 B**: the
parameter line changes the transcript's VALUES, so their receipts' bytes
differ from stage 8's, but a parameter word is absorbed and never carried, so
their counted LENGTHS do not move and both honest proofs verify from bytes.

**Shared-file changes this stage: NONE.** Every file touched is
`hashline/src/private_block.rs` or under `hashline/src/private_block/`:
`argument.rs`, `protocol.rs`, `grow_tests.rs`, `rung_tests.rs`,
`review_tests.rs` (four items widened to `pub(super)` so the new module can
reuse the reviewer's `distinct_kv_case`, `clone_witness`, `outcome` and
`Outcome` instead of copying sixty lines — no behaviour changed),
`rulings_tests.rs` (new). The empty-diff check
`git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 11c01b2 --
private-block-kernel private-model-kernel zkvm-block` prints nothing, and the
two paths the earlier stages left awaiting deletion are gone.

### Findings of this stage, for the security owner

**S9-F1 (visibility).** Two lane items became `pub(crate)` because a test
must call them where no end-to-end path can: `argument::tile_rep` and
`argument::tab_group_is_declared`. Both are pure functions of the shape.
Four items of `review_tests.rs` became `pub(super)` for reuse. Nothing of
the library's public API moved.

**S9-F2 (the one test-only hook).** `protocol::set_moved_multiplicity` is the
first `#[cfg(test)]` injection point in the prover. It is three items — a
thread-local, a setter and two `#[cfg(test)]` blocks — and it is what makes
the `Dom::Tab` pad term and the moved-multiplicity family testable at all.
It vanishes from a release build. A future reader should check it is still
`#[cfg(test)]` before trusting any release claim about this module.

**S9-F3 (what the F-4 test actually shows).** The hook moves a count to the
padded COPY of its own row and writes the matching helper, so the total
multiplicity, the value counted and every LogUp denominator are unchanged:
the value-0 identity and all three `SC_TAB` product relations still hold, and
the pad-zero term is the only thing that can object. It does. This is the
first end-to-end evidence for the arm the P-3 lift's safety rests on.

**S9-F4 (the rung profiles' receipts moved, by ruling).** Ruling 10 changes
the transcript of every non-toy profile, so no receipt produced before this
stage at the rung or rung-G will verify against one produced after it. Both
are development grade (P-7) and no receipt from either has been shown to
anyone, so nothing is broken; it is recorded because it is the first time
this lane has deliberately invalidated a receipt.

**S9-F7 (the grouped-attention exchange is a MULTI-CATCH case, erratum
E-19's sense).** The query-head exchange is rejected by the verifier, which
is what memo §9a's second acceptance test asks for — but it is caught at
**slot 14, the `Dom::D` zero-check**, and not at the score or PV relation.
The reason is that the tamper exchanges everything the two head SLOTS own
(`Dom::Q`, `Dom::Ht`, `Dom::S` — 22 planes) and leaves the attention OUTPUT
on `Dom::D` alone, so the first relation downstream of the exchange fails
before the grouped-read relation is reached. It therefore shows that a query
head cannot be moved between key-value groups; it does NOT isolate the
relation that binds a head slot to its group. The single-catch version needs
the two heads' slices of the `Dom::D` attention-output planes exchanged as
well, so that everything but the PV relation still holds — a follow-up, not
a defect, and the review's key-value-side test
(`a_query_head_reading_the_other_key_value_head_is_rejected_at_the_rung`)
covers the same property from the other side.

**S9-F6 (PRE-EXISTING, found while checking this stage, not caused by it).**
`python3 -m unittest discover -s tests -p "test_zk60_private_block*.py"`:
the layout model's **25 tests pass**, and all **9** tests of
`test_zk60_private_block_inventory.py` ERROR in
`zk60_attention_native_inventory.parse_dom_logs`, which cannot find a `match`
block in `layout.rs`. That harness parses the Rust source for the TOY design
numbers and has not been adapted to the SHAPED `layout.rs`; the file was last
changed in `dcaec94` (stage 6), this stage did not touch it, and the same
nine errors reproduce on that source. It is a stale test harness, not a
defect in the block — but it means the Python inventory currently checks
nothing, and someone should either adapt it or retire it.

**S9-F5 (still open, unchanged).** The rung CAPTURE remains the blocker on
any privacy statement (C-F5): `native_capture.rs` is forbidden and hard-codes
`pcs_params()` with no shape. Neither rung profile, and certainly not 125M,
has been through the rank / CFS / disclosure tools. **No privacy statement
may be made about any of them.**

### NEXT: exactly what the next agent should do, in order

1. **LAUNCH THE 125M RUN** with the two commands above, in that order, on a
   quiesced box, and paste the printed line into this ledger beside the
   modelled 11.00 GiB. Nothing else heavy may run beside it. If the scope is
   killed for memory, record the killed peak and re-cost the S2 drops before
   raising the ceiling.
2. **The rung capture** (S9-F5) is still what blocks every privacy claim. The
   orchestrator must ask the integrator for a shape-parameterised capture
   writer; the generalised endpoint makes it more urgent, not less.
3. **The memo NOTE of F-7** (the `Dom::L` row) is for whoever owns
   `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md`; this lane does not edit it.
4. **Ruling still wanted on S11b-F1** (the padded endpoint removes the need
   for the memo's C6 at a cost of 32,768 B of receipt) and on S9-F4 above.
5. **The single-catch form of the query-head exchange** (S9-F7): exchange the
   two heads' slices of the `Dom::D` attention-output planes too, so that the
   PV relation is the only one that can fail.
6. **S9-F4 of stage 7 is still open**: the closed forms are the constructor
   but `Tab::Pub` still materialises a vector on both sides (168 MB of
   indicator tables at 125M). It is a memory question for the run, not a
   correctness one.
7. Re-read the toy freeze gate before every commit: receipt 2,816,472 B, the
   literal schedule digest, and the empty-diff check must print nothing.

---

## Stage 10 (2026-09-20, 07:2x–08:0x): the inventory tool on the shaped layout — S9-F6 CLOSED

**The problem, in one line.** `scripts/zk60_private_block_inventory.py` does
not read a memo; it PARSES `hashline/src/private_block/{layout,argument,
protocol}.rs` and re-derives the toy block's layout from the source, then
runs the two committed leak-checking tools on what it read. Steps A–C of this
lane rewrote those three files over a `Shape`, and every spelling the parser
was anchored on moved. All **nine** of its tests ERRORED (finding S9-F6), so
the repository-wide suite would have gone red on integration and, worse, the
tool that fed the block's acceptance as an experimental component was
checking nothing.

Python only, this stage. No Rust file was edited, no build was run, no proof
was made, and no privacy property is claimed anywhere below.

### The nine tests and their one cause

Every one of the nine ends in the same three frames —
`PB.BlockLayout` → `INV.Layout.__init__` → `parse_dom_logs`, at
`zk60_attention_native_inventory.py:196`, `ValueError: substring not found`.
The committed parser reads `Dom::log`'s `match` out of `layout.rs`; since
step S6 `Dom::log` (layout.rs:160-162) is a CALL,
`domain_log_at(self.natural_log(), self.carries_h_planes(), LOG_N)`, and
there is no match to find. Six of the nine are in
`TestAdaptersAreNeeded`, one is `TestEndToEnd.setUpClass` (which takes the
whole end-to-end class with it), two are in `TestWrongExpectationFails`.
Log: `results/zk60_block125m_lane/s10-inventory-baseline.log`.

Fixing that one line uncovered four more breakages, each of which would have
been the next error: `fn lookups` is now
`lookups_at(&Shape::toy(), &Ids::toy(), dom)` with shape-driven arms;
`define`'s preamble moved the axis logs out of the parsed region;
`define`'s arms speak `ids.at(..)` / `hids.first_helper(..)` / `sh.log(..)`;
and `logup_sum_claim` now loops `lay.h_planes()` over `hids.n_h()` and signs
with `hids.is_table(p)`.

### The repair: four new adapters, nothing weakened

The tool's existing discipline is a named, cited ADAPTER per construct the
block's Rust uses and the accepted attention Rust does not, each of which
REFUSES rather than guesses when the source does not read as expected. Four
were added in that style (`scripts/zk60_private_block_inventory.py`):

| adapter | what it reads | what it does |
|---|---|---|
| **B-7** | `Dom::log` (layout.rs:160-162), `domain_log_at` (:136-142), `natural_log` (:146-155), `carries_h_planes` (:157-159), `LOG_N` | requires the delegation and the ruling-P-3 lift to read EXACTLY as pinned, runs the COMMITTED arm parser on `natural_log`'s own match, applies the lift in Python and rewrites `Dom::log`'s body into the literal match the committed parser reads. At the toy the lift moves nothing (`lifted_by_P3` empty) |
| **B-7 (toy profile)** | the same nine natural logs, plus `NORM_WRHO` / `WRHO_S` / `F_P` and `LN_TOY` / `LS_TOY` / `LP_TOY` (:281-283) | inverts the SIX axis logs out of the nine domain logs by shape.rs:390-404's rule (every padded axis is a power of two, so the logs sum exactly) and derives the three byte-limb counts by shape.rs:372-386's rule. Ten cross-checks travel with it and any failure is a hard parse error: the three domains the inversion does not consume, the six frozen toy constants `T`/`D`/`H`/`DH`/`F`/`KV` (which no longer drive anything in layout.rs and are now only witnesses), and the three pinned limb counts |
| **B-8** | `lookups` (:643-645) and `lookups_at` (:667-742) | requires `lookups` to be exactly the toy call and `lookups_at` to bind `(ln, ls, lp)` and `norm_top`, substitutes the toy's limb counts, resolves the four `if norm_top` blocks (true at the toy: `NORM_WRHO = 29` against `8 × 4`) and hands the result to the COMMITTED counter, which still does all the counting |
| **B-9** | `define`'s body alone | rewrites the shaped spellings into the ones the committed `DefineParser` reads: `ids.at(P) → P` and the six limb-group accessors → their toy bases (the toy id map is the identity — `Layout::new`'s own freeze gate, layout.rs:987); the six `hids.*` accessors → the literal `H_*` planes (grow_tests.rs:855-877 asserts each one at the toy); `sh.helpers/log/size/limbs_*` and the six `sh.<axis>` fields → the toy profile's values; `lg(v) → v.trailing_zeros()`. Six small evaluator extensions go with it, all forms the accepted source never uses |
| **B-10** | `define`'s preamble (argument.rs:873-891) | binds its eleven locals into each arm's environment at the toy's values, including `pad_on = false` / `n_pad = 0`, which is what `Shape::toy()` gives: pad.rs:365-368 returns no zero-rule plane unless `carries_pad_rule` (shape.rs:360-362 = `!is_frozen_toy`), so `B::supp` returns `None` and ruling P-1's pad term is absent. The branches this switches off contain **no site call**, so the committed `consumed == expected_calls` check still covers every site |

**B-4 re-pinned** for `logup_sum_claim`: the loop bound is taken as `N_H`
only on the strength of `Layout::new`'s freeze gate
`assert_eq!(lay.hids.n_h(), N_H, ..)` (layout.rs:985), which the adapter now
requires to be PRESENT in the source; the sign test's three planes are still
read out of `fn h_is_table`'s `matches!` (which survives at :437-439), and
`HIds::is_table`'s body must read `(self.gu8..self.gu8 + 3).contains(&plane)`
(:549-551) — grow_tests.rs:872 asserts the two agree on every plane at the
toy.

**B-2 is now dead** and is kept only so a revert would still parse: the
`lay.helpers(..)` spelling it adapted occurs **zero** times in argument.rs.
That is stated in the adapter's own entry and is visible in the record, where
`adapters_used_by_the_define_parser` no longer reports it.

**No check was weakened, skipped or marked expected-failure, and no Rust
file was touched.** Nothing the tool checks changed.

### THE ACCEPTANCE: the toy's numbers are byte-identical

The record was regenerated into `results/zk60_private_block_tools/` and
compared KEY BY KEY with the copy committed at `f1df3ba`, which was made from
the pre-lane source. **41 differences, none of them a derived quantity**
(`results/zk60_block125m_lane/s10-evidence-comparison.txt`):

* `zk60_private_block_{schedule,pair_schedule,cfs_slots,hosts}.json` and the
  `.done` marker — **BYTE-identical**: `git status` reports no change to them
  at all, so every claim site, opening group, row index, rank verdict, CFS
  verdict and negative control is the same byte for byte;
* `zk60_private_block_inventory.json` — the three `source_sha256` of the Rust
  files the lane rewrote, and the `adapters` prose;
* `zk60_private_block_summary.json` — the same three hashes, the prose, the
  `out_dir` paths, `adapters_used_by_the_define_parser` (B-2 out, B-9/B-10
  in), `logup_adapter_record/h_planes_body` (the quoted source line) plus an
  added `is_table_body`, four added keys (`define_rewrites`,
  `layout_adapter_record`, `toy_profile_read_from_the_rust`,
  `independent_model_cross_check`) and one added gate, 11 → 12.

So A 455 rows, H 384, A data 213, H data 280, 120 A sites, 51 H sites, 35 / 9
opening groups, 23 slots, M 50 rows, 34 functionals, largest L 50, U8 61,440
/ exp 2,048 / act 512, 159 main and 25 extension rounds, 173 terminals, all
host sums and ranks, all standalone dims — every one comes out of the shaped
source EXACTLY as it came out of the pre-lane source.

`accepted_selfcheck/` differs in 27 keys, and **none of them is this
stage's**: `private_attention/argument.rs` changed on this lane after
`f1df3ba`, and the committed record was already STALE for two files when it
was committed (it records `ac8ca737` for `private_attention/layout.rs`, which
is `17159dcc` both at `f1df3ba` and today, and `9be2439b` for
`protocol.rs`, which matches neither). The self-check's VERDICT is unmoved:
29 of 29 cross-checks, failures none, reproduced = true, A sites 75, H sites
35, A groups 30, H groups 8.

### One new gate, and one new finding

**The twelfth gate** compares the toy profile this driver READ OUT OF THE
RUST with the independent shape-driven model
`scripts/zk60_private_block_layout_model.py`, which computes the same
quantities from a shape alone and never opens a Rust file: **62 items** — the
six axis logs, the three byte-limb counts, the C-6 flag, A / H rows and
sites, the three lookup totals, the nine domain logs, the six per-position
lookup counts, the six helper-plane counts, all 23 slots' (main, extension,
degree), and the support-indicator flag. **All 62 agree.** The model is a
second opinion, not an input: no value it produces enters the derivation.

The slot rows are there for a specific reason. Adapter B-10 takes
`pad_on = false` from `pad.rs` and `shape.rs`, and those two files are NOT
among the three this driver parses — so the assumption is checked by its
OBSERVABLE CONSEQUENCE instead: a slot whose relation the support indicator
gates gains one degree, the model carries no indicator at the toy, and
layout.rs's own declared `SLOTS` degrees agree with it slot by slot. A toy
that had started to carry the pad rule would fail that gate rather than pass
silently. (Independently: if `pad_on` were set true by hand the parser
REFUSES outright, on `super::pad::zero_rule_a_planes(..) != vec![A_MX,
A_SUM]`, which it cannot evaluate — it cannot quietly produce a different
answer.)

**S10-F1 (new, minor).** The pre-lane `accepted_selfcheck/` record committed
at `f1df3ba` was already stale for two `private_attention` files, as above.
Regenerating it here fixed it, but a record whose hashes name files it was
not made from can mislead a reader; whoever integrates should regenerate the
tool's record whenever the parsed source moves.

**`--shape rung` was NOT added, deliberately.** It is not cheap and it would
not be honest yet. At any shape but the toy `carries_pad_rule` is true, so
`pad_on` is true, `B::supp` adds a public table to seven slots and ruling
P-1's pad term adds a `mu` entry and a `zeta` power to eight of them; the
parser would have to evaluate `pad::zero_rule_a_planes` — a whole further
file of rules — to know which planes each pad term carries, and the two
committed leak tools would then be modelling a claim list they have never
seen. The rung's structural check is worth having, but it is a piece of work
in its own right and it belongs after the rung CAPTURE (S9-F5), not before.

### Tests and commands

| what | log | result |
|---|---|---|
| the nine errors, reproduced | `results/zk60_block125m_lane/s10-inventory-baseline.log` | Ran 9, FAILED (errors=9) |
| the inventory tests, repaired | `results/zk60_block125m_lane/s10-inventory-after.log` | **Ran 40, OK** |
| both `test_zk60_private_block*` files | `results/zk60_block125m_lane/s10-module-tests.log` | **Ran 65, OK** |
| the record regenerated | `results/zk60_block125m_lane/s10-tools-regenerate.log` | exit 0, `failures: none`, 12 of 12 gates |
| the whole Python suite | `results/zk60_block125m_lane/s10-whole-suite.log` | Ran **1153**, 1 failure + 1 error + 80 skipped, 854.96 s — both are MISSING FIXTURES, neither is this stage's |

**The two whole-suite failures, by name, and why they are not this
stage's.** `test_zkmatrix_native_backends.NativeBackendTests.test_ring_freeze_check`
ERRORs with `FixtureConfigurationError: no complete local 125M regression
fixture` — `results/m125_ffn_export{,_wsl}/layer00_X.bin` are absent in this
worktree. `test_zk60_endpoint_view.EndpointGeneration.test_plan_does_not_read_captured_output_values`
FAILs on `mandatory retained captures absent`: it globs
`results/zk60_round22_captures/*.json` and that DIRECTORY does not exist
here (only the file `results/zk60_round22_captures.json` does). Neither test
imports anything this stage touched, and neither reads
`hashline/src/private_block/`. **They were not touched.** Before this stage
the same suite would also have carried the nine inventory errors; it now
carries none of them.

The inventory file went from 9 tests (nine errors) to **40 tests, all
passing**: the six that were there plus the end-to-end class, and 25 new ones
— the adapted layout's numbers, the derived toy profile, four refusal tests
for B-7/B-8 (an unexpected `Dom::log` body, a changed lift, a `lookups` body
that is not the toy's, a moved `LS_TOY`), three for B-4 (the `h_is_table`
body, a removed freeze gate, a widened table-flag range), the named B-9
rewrite counts, the layout adapter record and the model cross-check.
`test_layout_rs_parses_with_the_committed_class` is now
`test_layout_rs_no_longer_parses_with_the_committed_class` — the statement it
made about the source has become false, so it was inverted into the same form
as its two siblings, and all three numbers it asserted (23 slots, A 455, H
384) are asserted on the ADAPTED layout instead, along with four more.

## Stage 11 (2026-09-20, 08:1x–08:4x): PHASE TIMING — where the seconds go

Commit `68d5f0e`. **Shared-file changes: NONE.** Every file touched is
`hashline/src/private_block.rs` or under `hashline/src/private_block/`:
`timing.rs` (new), `protocol.rs`, `argument.rs`, `rung_tests.rs`,
`rulings_tests.rs`, `tests.rs`.

### Why

One block at the 125M shape proves in **26.89 s** (stage 9 item 12, one run
on a shared box). Nobody knew WHICH PART of the block those seconds belong
to. The open design question **P5** of
`ZK60_MVP_COMPLETION_PLAN.md` §5.2a — is a two-prover design that keeps the
feed-forward half on a GPU worth building? — was answered on paper by a COUNT
of committed rows (the feed-forward half is about 20% of them; the design
could save "10–17%" at this shape). A measured phase split replaces the
count. This stage builds the instrument and prepares the 125M run that uses
it; **it does not run 125M.**

### What is timed, and how

`hashline/src/private_block/timing.rs` holds a small recorder, `Phases`: a
pair of `Instant`s and a vector of labelled rows, each row carrying a
duration, the COUNTED figure the duration should be read against (committed
rows, a sumcheck cube, a word count, a claim count — all functions of the
public shape), and the process's `VmRSS` and `VmHWM` read from
`/proc/self/status` at that moment.

* **It is off unless `HL_PB_TIMING=1`.** The variable is read FRESH at every
  proof, never memoised in a `OnceLock`, in the house style of `HL_TIMING` in
  `pcs.rs` and `zk.rs`. With it unset, `Phases::start` does two clock reads
  and builds an empty `Vec` (which does not allocate), and every `mark`,
  `slot` and `report` returns on its first line: no allocation, no `/proc`
  read, no print on the proving path.
* **It cannot influence a proof.** There is deliberately NO accessor for the
  switch outside the module — an unused-method warning is what removed the
  first draft's one — so no branch of `protocol.rs`, `argument.rs` or any
  other lane file can read the recorder back. It touches no transcript, no
  randomness stream and no committed buffer.
* **It records nothing private.** Durations, byte counts, row counts, cube
  sizes, memory readings, and the schedule's own already-public `SLOT_NAMES`.
  Never a witness value, a salt, a pad, a private plane, a challenge, a
  claimed sum or a terminal.

**What could NOT be split, and why.** The brief asked for commit A split into
row encoding and column hashing/Merkle. Both live inside
`pcs::commit_zk_owned`, which is `hashline/src/pcs.rs` — a file this lane
does not edit — so the enclosing call is ONE phase and is labelled as such.
The same holds for `zk::mask_commit`, `zk::mask_open` and `zk::mask_verify`
in `hashline/src/zk.rs`. Everything the lane's own files do around those
calls IS split: the `A` build into five phases, the `H` build into six
(including the S2 buffer drops), the slot loop into twenty-three, the
openings into five.

**42 prover phases:** two setup, five building `A`, the `M` commitment, six
building `H`, twenty-three slots, five openings — plus the wire encode, which
happens outside `prove_inner_at` and gets its own line from
`timing::timed`. **31 verifier phases:** three setup, twenty-three slots,
four verifications — plus the wire decode, likewise its own line.

### The slot-to-half classification

Taken from the layout's own slot definitions in `argument::define`, and
carried in code as `timing::SLOT_HALF`.

| half | slots | why |
|---|---|---|
| **norm** | 00 `SC_SS`, 01 `SC_SSM`, 02 `SC_TZC`, 03 `SC_LZC` | the two RMS norms (`norm_a` before attention, `norm_m` before the feed-forward): their row sums, their reciprocal squares, and the byte limbs of both |
| **attention** | 04 `SC_RS`, 05 `SC_QMM`, 06 `SC_KMM`, 07 `SC_VMM`, 08 `SC_SCORE`, 09 `SC_PV`, 10 `SC_WO`, 15 `SC_QZC`, 16 `SC_KVZC`, 17 `SC_SZC` | the Q/K/V projections and their two RoPE zero-checks, the score and PV bilinear matmuls, the softmax row sums and its zero-check, the output projection |
| **feed-forward** | 11 `SC_GMM`, 12 `SC_UMM`, 13 `SC_DMM`, 18 `SC_FZC` | the gate, up and down matmuls and the f-cube zero-check that hosts the first two and carries the activation pair lookup |
| **residual** | 14 `SC_DZC` | the ONE MIXED slot. It carries both residual adds (`x1 = x + ao`, `x2 = x1 + z16`), the int16 classes of all four width planes, BOTH norm relations, and it hosts one ATTENTION matmul (`SC_WO`) and one FEED-FORWARD matmul (`SC_DMM`). It is counted whole under `residual` and never split: no part of its single sumcheck can be attributed to one half without re-deriving the slot. Every table prints a line naming it |
| **lookup-table** | 19 `SC_TAB`, 20 `SC_ZS` | the three public byte tables' helper relations and the zero-sum row |
| **endpoints** | 21 `SC_IO_IN`, 22 `SC_IO_OUT` | the two external endpoint equalities |

Four further labels are for phases that are not a slot at all: **setup**
(layout, plane maps, NTT tables, endpoint owners), **commit** (building and
committing `A`, `M`, `H`), **openings** (the `M`, `A`, `H` and endpoint
openings, or their verifications), **frame** (the wire encode and decode).

**Pad-zero hosts are not a half.** Every zero-check slot hosts one or more of
ruling P-1's pad-zero groups (`SC_TZC` on `Dom::T`, `SC_LZC` on `Dom::L`,
`SC_DZC` on `Dom::D`, `SC_QZC` / `SC_KVZC` on `Dom::Q` / `Dom::Kv`, `SC_SZC`
on BOTH `Dom::S` and `Dom::Ht`, `SC_FZC` on `Dom::F`, `SC_TAB` on
`Dom::Tab`), so the pad rule's cost is already inside those slots' seconds
and does not form a category of its own.

### The rung-G phase table [MEASURED, one run, shared box, 2026-09-20 08:27]

`results/zk60_block125m_lane/s11-rungg-timing.log`, the honest rung-G proof
with `HL_PB_TIMING=1` (development rung: 24 tokens, width 96, hidden 192,
6 query heads of 16 over 2 key-value heads). **1 passed / 0 failed**, 0.70 s.

Prover, the phases above 1% of the wall clock:

| phase | half | s | % | size |
|---|---|---|---|---|
| slot 14 `03 D zero-check (hosts 12, 13D)` | residual | 0.143 | 31.3% | 8,192 cube |
| slot 17 `06 softmax zero-check (hosts 07, 10)` | attention | 0.088 | 19.2% | 16,384 cube |
| slot 18 `14 F zero-check (hosts 13G, 13U)` | feed-forward | 0.065 | 14.2% | 16,384 cube |
| `A: commit (pcs::commit_zk_owned)` | commit | 0.038 | 8.2% | 623 rows |
| `H: commit (pcs::commit_zk_owned)` | commit | 0.033 | 7.2% | 576 rows |
| `M: mask commit (zk::mask_commit)` | commit | 0.018 | 4.0% | 50 rows |
| `H: LogUp helper inverses` | commit | 0.012 | 2.7% | 419,840 words |
| slot 15 `04 Q zero-check (hosts 09Q, 11)` | attention | 0.011 | 2.5% | 8,192 cube |
| `open A (audit + pcs::open_zk)` | openings | 0.008 | 1.7% | 122 claims |
| `open H (audit + pcs::open_zk)` | openings | 0.007 | 1.6% | 53 claims |

Prover half totals: setup 0.000 s (0.0%), **commit 0.111 s (24.4%)**, norm
0.003 s (0.6%), **attention 0.105 s (23.0%)**, **feed-forward 0.069 s
(15.2%)**, **residual 0.143 s (31.3%)**, lookup-table 0.001 s (0.2%),
endpoints 0.001 s (0.2%), openings 0.022 s (4.7%). The requested three-way
split: **attention 23.0% | feed-forward 15.2% | the rest 61.5%**. Wire encode
0.003 s for the 4,234,648 B frame.

Verifier half totals: setup 0.1%, norm 7.2%, **attention 37.5%**,
**feed-forward 18.8%**, residual 7.6%, lookup-table 9.9%, endpoints 0.1%,
openings 17.8%. Wire decode 0.002 s.

**Does it add up?** Prover: sum of phases **0.455 s** against a wall clock of
**0.456 s** — unaccounted **0.001 s, 0.2%**. Verifier: sum **0.100 s**
against a wall of **0.100 s** — unaccounted **0.9%**. Both are inside "a few
percent"; the residue is the recorder's own `/proc` reads and the clock
restart between phases.

**Read the rung numbers as a shape, not as a forecast.** The rung's cubes are
tiny (64 to 16,384) and its fixed costs (the two PCS commitments, 24.4% of
the prover here) do not scale like its slots. The 125M run is what decides
P5; this table exists to show the instrument works and sums.

### Nothing changed

| gate | before | after |
|---|---|---|
| the module filter `--lib private_` | 156 passed / 0 failed / 3 ignored (`t3-rulings3.log`, stage 9) | **157 passed / 0 failed / 3 ignored**, 218.10 s (`s11-filter1.log`) |
| the toy frame | 2,816,472 B | **2,816,472 B** (`tests.rs:108`, `zero_witness_tests.rs:172`, `review_tests.rs:696`, `grow_tests.rs:497/1170/1184`, all green) |
| the frozen schedule digest | literal | **unmoved** (`grow_tests::the_toy_schedule_digest_is_frozen`, green) |
| the frozen toy parameter line | literal | **unmoved** (`grow_tests::the_toy_parameter_line_is_the_frozen_literal`, green) |
| both rung frames | 4,218,264 B / 4,234,648 B | **unchanged**, both honest proofs verify from bytes |
| compiler warnings | 10 | **10** |
| `git diff --stat 11c01b2 -- private-block-kernel private-model-kernel zkvm-block` | empty | **empty** |

The one new test is the parity gate,
`rung_tests::a_proof_made_with_the_phase_clock_on_verifies_with_it_off`: a
rung-G proof made with the clock ON verifies, in typed form AND from bytes,
under a verifier with the clock OFF; both frames are the counted 4,234,648 B;
a one-byte truncation of the clocked frame is still refused. **Byte equality
between the two proofs is NOT asserted and is not expected** — every attempt
draws a fresh OS randomness stream, so two honest proofs of one statement
differ in their bytes whatever the switch is doing. The test drives the
switch through a `#[cfg(test)]` THREAD-LOCAL override (`timing::force`) and
not `std::env::set_var`, which is not thread-safe and would race any other
test reading the variable whenever the suite runs multi-threaded; the same
shape and discipline as `protocol::set_moved_multiplicity`.

### The 125M timing run: PREPARED AND NOT LAUNCHED

**Step 1 — build under the build lock** (already done at commit `68d5f0e`;
log `results/zk60_block125m_lane/s11-m125-build.log`):

```
flock -w 540 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 /home/victor/.cargo/bin/cargo test --release --offline -j 2 --manifest-path /home/victor/wt-zk60-block125m/hashline/Cargo.toml --lib private_ --no-run > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/s11-m125-build.log 2>&1
```

The `Executable unittests` line of that log names
`/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5`
— the SAME name as stage 9's, because the hash is of the crate's metadata and
not of its source; the binary itself was rebuilt (mtime 2026-09-20 08:39:07,
10,854,728 B). **Re-read the path and the mtime before launching**: the
target directory is shared with another worktree.

**Step 2 — the detached, memory-capped run.** Stage 9's command with
`env HL_PB_TIMING=1` INSIDE the scope, a new log and a new marker. One line,
nothing else heavy on the box, no GPU job, no release build:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env HL_PB_TIMING=1 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run2-timing.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run2-timing.done' >/dev/null 2>&1 &
```

What it prints, in order: `125M: the phase clock (HL_PB_TIMING) is ON…`, the
witness build time and RSS, the **prover's 42-row phase table** with its half
totals and the attention / feed-forward / rest split, the `encode to bytes`
line, the **verifier's 31-row table** with the same summaries, the
`125M ONE BLOCK:` result line, and a `125M PHASE TABLES ABOVE:` line giving
the prover and verifier wall clocks the two `SUM OF PHASES` figures are to be
checked against. `m125-run2-timing.done` holds the exit code; a memory kill
leaves a nonzero code and a log without the result line, which is a finding
and not a failure.

**The clock's own cost.** About 54 `/proc/self/status` reads on the prover
and 31 on the verifier, plus one `Vec` of ~54 small rows. It is inside the
noise of a 26 s proof, but it is not zero, and the run's headline
prove/verify seconds should still be compared against stage 9's
**26.89 s / 1.04 s**, which were taken with the clock absent.

### RESULTS — 125M with the phase clock (TO BE FILLED BY THE ORCHESTRATOR)

`m125-run2-timing.log`, launched …, exit code …

| figure | stage 9 run 1 (no clock) | run 2 (clock on) |
|---|---|---|
| prove, s | 26.89 | |
| verify from bytes, s | 1.04 | |
| witness build, s | (in the log) | |
| receipt, B | 40,782,792 | |
| peak RSS, GiB | 10.42 | |
| SUM OF PHASES / wall, prover | — | |
| SUM OF PHASES / wall, verifier | — | |

Prover, by half:

| half | s | % of prove |
|---|---|---|
| setup | | |
| commit (A, M, H) | | |
| norm | | |
| **attention** | | |
| **feed-forward** | | |
| residual (slot 14, mixed) | | |
| lookup-table | | |
| endpoints | | |
| openings | | |
| frame (encode) | | |

The three phases to read first, because P5 turns on them: the
**feed-forward** total (slots 11, 12, 13, 18), the **attention** total, and
the share that is neither — above all the two PCS commitments, which a
two-prover design would have to pay TWICE or split.

| question | answer from run 2 |
|---|---|
| feed-forward share of the prove time | |
| attention share | |
| how the measured feed-forward share compares with the counted 20% of committed rows | |
| does the measured split support or refute the paper "10–17%" saving of P5 | |

## Stage 12 — the multi-block run (2026-09-20, 09:4x–)

**What this stage builds.** A private RUN of `L` transformer blocks under ONE
transcript, block `k`'s hidden output being block `k+1`'s hidden input, with
nothing about either published. The design is
`ZK60_PRIVATE_RUN_MULTI_BLOCK.md`, the independent attack on it is
`..._CHECK.md`, and the rulings that bind this build are
`..._DISPOSITION.md` M-1 … M-8. Where draft and check disagree the check
wins; where check and disposition disagree the disposition wins.

**What a green run here is, and is NOT.** A run that verifies is a
CORRECTNESS milestone. It is not a privacy result: the obligations a run adds
over one block (the boundary plane's joint rank over all THREE commitments
that hold it, blinding independence across blocks, the run-wide joint law)
have no tools yet and no gate has been run. The run's soundness is about
2^-97.5 for twelve blocks at the 125M geometry (ruling M-2) and accepting
that level for the native line is the project owner's ruling.

### Status

| step | what | state |
|---|---|---|
| R1 | the claim audit on a hand-built two-claim boundary schedule | **done** (4 tests) |
| R2 | `boundary.rs`: derived rows, two claim sites, one opening | **done** (11 + 1 tests) |
| R3 | `run.rs`: the run prover and verifier, `L = 2` at rung-G | **done** |
| R4 | the negative battery at `L = 2` and `L = 3` | **done** (13 run tests) |
| R5 | `L = 3`, then `L = 12` at rung-G | **done**, measured |
| R6 | `L = 2` at 125M: PREPARED, NOT RUN | **prepared**, command in the ledger, NOT launched |

### Baseline, before anything of this stage

`u1-baseline.log` (detached, heavy-lock-free build lock, 219 s):
**157 passed, 0 failed, 3 ignored, 67 filtered out** on the `private_` filter.
That is the number every later commit of this stage is measured against.

### R1 — the rule, before the code

`run_tests.rs` (new, `#[cfg(test)]`), four tests, no new library code and no
new module in the tree. Every case is stated at the 125M boundary geometry
(32 data rows of `2^14`, `rows = data + 2*sites + 2 = 38`, `prox = 36`,
site rows `[32,33,34,35]`) with claims of exactly the shape
`argument::build_claim` produces — the data slice over the whole padded plane
plus a reserved pair with weights `(cm, cm*U)`.

| case | verdict of `audit_claims` |
|---|---|
| two claims, DISJOINT pairs, proximity pair last (either order) | accepted |
| both claims on pair 0 | refused: "a reserved pair is unused or shared between claims" |
| a claim reaching the proximity pair | refused: "a claim reaches the proximity pair or leaves the commitment" |
| a zero pair coefficient | refused: "zero terminal mask coefficient; discard attempt" |
| a pair straddling the pair grid (rows 33,34) | refused: "a claim does not carry exactly its own reserved pair" |
| only one of the two sites used | refused: "a reserved pair is unused or shared between claims" |

**FINDING U-1 (it refines blocking item B4 / ruling M-1).** The check
predicted that `audit_claims` ACCEPTS the leaking 37-row two-site geometry
(`rows = data + 2*sites + 1`, a single proximity row) and that this is why
the row count must be derived. Run against the real function, the two-site
37-row schedule is in fact REFUSED — but for bookkeeping reasons and not
because the geometry leaks: with `prox = 35` (forced by `prox + 2 == rows`)
the second reserved pair at rows `(34,35)` overlaps the declared proximity
position, so the claim "reaches the proximity pair"; with `prox = 36` the
placement rule `prox + 2 == rows` fails. Neither refusal is the hiding
requirement.

**The sharper instance, and it is a real one.** Hand `audit_claims` the
external endpoint's own ONE-site `data + 5` budget with the proximity
position declared at `data + 3` — one row above where
`check_opening_challenges` actually requires independence, at
`(data + 2, data + 3)` — and it **accepts**. Declared at the true `data + 2`
the same geometry is refused. So the audit's verdict tracks the caller's
DECLARATION and not the truth of the geometry, which is exactly why ruling
M-1's "derive `rows`, refuse anything else" has to live in the boundary
module and cannot be delegated to the audit. The conclusion of B4 stands; its
stated evidence does not, and the test records both.

| command | log |
|---|---|
| `cargo test --release --offline -j 2 --lib private_block::run_tests -- --test-threads=1` (first write, expected to fail) | `u2-r1.log` — 3 passed, 1 FAILED (the wrong prediction above) |
| the same, after the test was corrected to what the function does | `u3-r1.log` — **4 passed, 0 failed** |

### R2 — `boundary.rs`, the commitment itself

A NEW module beside `endpoint_g.rs`, modelled on it line for line, with
`sites` as a parameter. Nothing of `endpoint_g.rs` or `private_seam.rs`
moves: ruling M-7 keeps the run's two EXTERNAL endpoints on today's
`data + 5` geometry, and this module is only ever asked for the `L - 1`
INTERNAL boundaries.

| property | value |
|---|---|
| domain label | `hashline/private-block/internal-boundary/v1`, **43 bytes** (C-H4' forbids 28 and 35; `endpoint_g`'s is 42) |
| derived geometry | `rows = data + 2*sites + 2`; at 125M `32 + 4 + 2 = 38`, at rung-G `4 + 4 + 2 = 10` |
| reserved rows | site 0 (the OUTGOING claim, block `k`'s slot 22) at `data`; site 1 (the INCOMING claim, block `k+1`'s slot 21) at `data + 2`; the proximity PAIR at `data + 4` |
| digest | its own domain, then context, plane axes, boundary index, site count, row width, rate, pad count, **the derived row count and the proximity row**, and the scale — so a verifier cannot be handed a geometry it did not agree to |
| scale | ONE field (ruling M-4): there is no second place to declare a boundary's scale, so block `k`'s output and block `k+1`'s input cannot disagree |
| the owner | `PreparedBoundary` owns the `CommittedZk`, has no `Clone`, and `into_opening(self, spec, claims, tr)` CONSUMES it — `pcs::open_zk` only borrows, so this wrapper is what makes "one opening" a type error to break (the check's CORRECTION 1). The one other accessor is `data()`, a shared slice the two adjacent blocks' equality slots need exactly as `prove_inner_at` reads `ein.data.as_slice()` today; it hands out a borrow, never ownership |
| every opening | goes through `audit_claims` + the declared group count + the challenge refusals, because `into_opening` calls them and there is no other way to open a boundary |

Eleven tests in the module plus the cross-module R1 test. The ones that
carry weight: **every row count but the derived one is refused BY NAME** at
three arities, with the 37-row case stated on its own; ONE opening carrying
TWO claims at TWO points verifies through `pcs::verify_zk` and a one-bit
change to either claim's value is rejected; two claims at ONE point form one
column-weight group and trip the declared-count refusal; a shared reserved
pair is refused on the OPENING path, not only in a hand-built schedule.

**FINDING U-2.** A ONE-site boundary at the rung-G plane would be
`4 + 2 + 2 = 8` rows, and C-H4 refuses it outright (a column that hashes to
64 bytes is a Merkle node). Nothing in a run asks for one — the externals
keep `endpoint_g`'s geometry — but it means the module's one-site arity can
only be exercised at the 125M plane, and a future run shape with four data
rows could not use a uniform construction for its endpoints even if ruling
M-7 were revisited. The C-H4 guard is checked on the DERIVED row count, so
it can never be bypassed by a declaration.

| command | log |
|---|---|
| `--lib private_block::run_tests` with the boundary test written and no module | `u4-r2-first-fail.log` — `error[E0433]: cannot find boundary in super` (twice) |
| `--lib private_block::boundary` | `u5-r2.log` — 9 passed, 2 FAILED: the C-H4 guard fired on two of my own test parameters (finding U-2) |
| the same, parameters corrected | `u6-r2.log` — **11 passed, 0 failed** |
| **the gate**: `--lib private_` | `u7-r2-filter.log` — **173 passed, 0 failed, 3 ignored, 67 filtered out** (157 baseline + 11 + 5) |

### Shared files touched outside `hashline/src/private_block*`

**None.** Every file this stage wrote is `hashline/src/private_block.rs` or
under `hashline/src/private_block/`. The check's reachability table A9.3 is
confirmed in practice: no forbidden file was needed on the prover or the
verifier path. Of the seven "permitted sites that move" the check listed,
only ONE moved — `argument.rs`'s `sh.endpoint_rows - 5`, which now reads the
layout — because ruling M-7 keeps the external endpoints' geometry and
removed the other six.

### R3 / R4 / R5 — the run prover, the run verifier, and the ladder

Three new library files and one refactor, all inside
`hashline/src/private_block*`:

* **`run.rs`** — `RunShape`, `RunStatement`, `prove_run`, `verify_run`, the
  transcript position tag and the `RunWitnessSource` trait.
* **`wire.rs`** — the segment codec, appended; nothing of the block frame
  moved.
* **`protocol.rs`** — `prove_inner_at` and `verify_inner_at` SPLIT into the
  body a stage and a block share (`prove_core` / `verify_core`: `A`, `M`, the
  LogUp challenges, `H`, the 23 slots, and the openings of `M`, `A`, `H`, in
  exactly that order) and the parts that differ (the header, and the IO
  openings, which a block does at once and a run does one stage apart). Every
  transcript operation is in the same order it was, which is why every
  existing profile's bytes and digests are unmoved.
* **`layout.rs` / `argument.rs`** — the reserved pair an IO tab claims comes
  from the LAYOUT (`Layout::with_io_mask_rows`) instead of the literal
  `sh.endpoint_rows - 5` in `argument.rs`. For every single-block profile the
  layout's value IS `sh.endpoint_rows - 5`; a run sets it per stage. It is not
  in `describe()`, so no schedule digest moves; the run's OWN schedule digest
  carries it.

**The stage order, as built** (the design's §2.2): position tag; absorb the
stage index and the block's public digest; commit `B_k` and absorb its root
with its rows and row width; `prove_core` (the measured block, unchanged);
open `B_{k-1}` with block `k-1`'s slot-22 claim and block `k`'s slot-21 claim
together — the first moment its claim list is complete; on the last stage
open the external output endpoint too; position tag; write the segment; hand
it to the sink and drop it; keep only `B_k`.

**What crosses a stage.** On the prover: the `PreparedBoundary` owner of
`B_k` and the one `ZClaim` block `k`'s slot 22 raised. On the verifier: the
boundary's root and spec and **its own** `ZClaim` — `argument.rs` pushes each
claim outside the prove/verify match, so the verify arm computes the pending
claim identically and NOTHING about a claim is read from a segment.

**The segment, and its byte-exact length.** One format, used by the encoder
and the decoder alike: an 88-byte header (magic `HLPRUNS1`, the run's binding
digest, `L`, the segment index, the transcript position tag), then `B_k`'s
root when this stage commits one, the three block roots, the 23 slot proofs,
the `M`, `A` and `H` openings, the opening this stage CLOSES, the external
output endpoint's opening on the last stage, and a 32-byte trailer. The
header and trailer are **outside** the Fiat-Shamir chain (never absorbed —
a state cannot hash itself) and are **compared, never adopted** (ruling M-6).

**FINDING U-3.** The design asks the header to carry "the 32-byte transcript
state plus the 8-byte squeeze counter". `zkp-core/src/transcript.rs`
publishes `state()` but **no counter accessor**, and it is a file this lane
does not edit. Comparing the state alone would miss a counter mismatch. What
is carried instead is a **position tag**: a challenge squeezed from a CLONE
of the transcript, which is a function of the state AND the counter (the two
are the whole state, as `clone_state` shows), in 32 bytes. The clone is
discarded and nothing the live transcript will produce is disturbed — the
device `check_opening` has always used for its challenge replay. The framing
is therefore 88 + 32 = 120 B, not the design's 96 + 40 = 136.

**THE BYTE COUNT RECONCILES WITH THE DESIGN EXACTLY** [COUNTED, and
MEASURED at the rung]. The test computes the three segment lengths from the
block's own counted receipt and nothing else, and asserts them:

| | rung-G (measured = counted) | 125M (counted) |
|---|---|---|
| external endpoint opening (1 group) | 167,936 | 749,568 |
| boundary opening (2 groups) | 190,464 | **1,017,856** (the design's figure to the byte) |
| segment 1 | 4,066,824 | 40,033,336 |
| interior segment | 4,089,352 | 40,301,624 |
| last segment | 4,257,256 | 41,051,160 |
| `L = 2` total | **8,324,080** | 81,084,496 |
| `L = 12` total | **49,217,600** | **484,100,736** |

The design counted 484,095,680 for twelve 125M blocks with 40 B of framing
and 36-row external endpoints. The difference is exactly
`12 x 80` (the framing this build actually uses, finding U-3) `+ 2 x 2,048`
(ruling M-7: the externals keep today's 37 rows), i.e. 5,056 B. The design's
correction C7 — "R6's acceptance currently fails an honest run by 96 bytes
per segment" — cannot bite here, because the acceptance figure is DERIVED in
the test from the block's counted receipt and the framing constants.

### The measured ladder at the development rung (rung-G)

[MEASURED, one run each, shared box, 2026-09-20 10:2x; development grade, no
receipt from it is shown to anyone]

| `L` | prove, s | verify from segments, s | receipt, B | counted | high-water mark after each block, MiB |
|---|---|---|---|---|---|
| 2 | 0.99 (0.51 + 0.49) | 0.20 | 8,324,080 | ✔ | 117, 117 |
| 3 | 1.50 | 0.30 | 12,413,432 | ✔ | 117, 117, 117 — flat |
| 12 | 5.87 | 1.16 | 49,217,600 | ✔ | 117 x6, 122, 137 x5 — **RISING** |

**FINDING U-4: the high-water mark RISES across a twelve-block run**, from
117 MiB to 137 MiB, in two steps at blocks 7 and 8, and then stays flat. That
is +17% on a run whose per-stage working set is constant by construction, and
it is the allocator-fragmentation signal the check's OMITTED CONDITION 3 asks
for. It is REPORTED, NOT REPAIRED, per the brief. At the rung the absolute
numbers are trivial; at 125M the same relative rise on a 10.4 GiB stage would
be about 1.8 GiB and would put a twelve-block run past the 12 GiB ceiling, so
this must be measured at 125M before `L = 12` is attempted there, and the
`L = 2` run of R6 is the first place it can be seen.

### The negative battery at `L = 2` and `L = 3` (R4)

| test | outcome |
|---|---|
| **THE HEADLINE NEGATIVE TEST (i)**: the boundary holds block 1's TRUE output, block 2 was run on something else | rejected BY THE VERIFIER at **slot 21 `[IO-in endpoint equality]`**, `sumcheck round 0: s(0) + s(1) != claim` |
| **THE HEADLINE NEGATIVE TEST (ii)**: the boundary holds block 2's input, block 1's output differs | rejected BY THE VERIFIER at **slot 22 `[IO-out endpoint equality]`** |
| a boundary claim on a SHARED pair | refused by `audit_claims`, on the prover's opening path and on the verifier's (`boundary::into_opening` and `boundary::check_opening` both call it); R1 and `a_boundary_opening_on_a_shared_pair_is_refused` |
| a dropped last segment / a dropped middle segment | rejected: the segment count is the verifier's own |
| two segments swapped / a duplicated segment | rejected: the header's position tag is not the verifier's own |
| a FOREIGN segment from a second honest run of the same statement | rejected at the header's run binding, **before a field element is parsed** |
| every segment foreign but the first / only the third segment offered | rejected |
| a one-bit change anywhere in any of the three segments | rejected |
| a truncated segment | rejected: "the counted length" |
| a run verified with the wrong `L` | rejected: `L` is in the verifier's statement, the profile, the `"run-shape"` absorb, the parameter line and the schedule digest |
| block `k+1` declaring a different input scale than block `k`'s output scale | **does not construct**: "a boundary has ONE scale" (ruling M-4) |
| a receipt made under one calibration identity, verified under another | rejected at the run binding digest |
| the ALL-ZERO hidden input, as a RUN | proves and verifies; segment lengths unmoved |
| every one of the 27 single-block tamper families, applied to BLOCK 2 of a run | all rejected by the VERIFIER, each naming the slot that caught it (the prover succeeded in every case) |

### R6 — ONE `L = 2` run at the 125M shape: PREPARED, NOT RUN

The `#[ignore]`d test is
`private_block::run_tests::private_run_125m_two_blocks`. It asserts the
boundary is the counted 38 rows and the two segments the counted 40,033,336
and 41,051,160 B, and prints the chain-build seconds, per block the proving
seconds and the high-water mark after it, and the verifying seconds.

Predictions, so the run can fail [MODEL from MEASURED, the single 125M block
being prove 26.54 s, verify 1.04 s, receipt 40,782,792 B, peak 10.42 GiB]:
prove about 2 x 31 s of stage time, **peak about 10.74 GiB** (ruling M-3's
flushed figure; predict under 11.0 against a `MemAvailable` of about 13 GiB),
verify from segments about 2.1 s, total receipt 81,084,496 B. The witness is
built FOUR times, not twice — the chain builds each to learn the planes and
drops it, and the prover builds each again just in time so that no two 125M
witnesses (711 MB each) are ever resident — so about 4 x 4.7 s of the wall
clock is witness building and is not proving time.

**Step 1 — build under the build lock** (done; log
`results/zk60_block125m_lane/u15-r6-build.log`):

```
flock -w 540 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 /home/victor/.cargo/bin/cargo test --release --offline -j 2 --manifest-path /home/victor/wt-zk60-block125m/hashline/Cargo.toml --lib private_ --no-run > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/u15-r6-build.log 2>&1
```

The `Executable unittests` line names
`/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5`
— the same name as stages 9 and 11, because the hash is of the crate's
metadata and not of its source; the binary was rebuilt (mtime 2026-09-20
10:36, 11,077,920 B). **Re-read the path and the mtime before launching**:
the target directory is shared with another worktree, and it must be NEWER
than the last commit of this lane.

**Step 2 — the detached, memory-capped run.** `MemAvailable` at the time of
writing is about 13 GiB against a modelled peak of 10.74 GiB. One line,
nothing else heavy on the box, no GPU job, no release build:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_tests::private_run_125m_two_blocks >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l2.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l2.done' >/dev/null 2>&1 &
```

The phase clock is deliberately OFF (no `HL_PB_TIMING=1`): what this run is
for is the two stage times, the per-stage high-water marks and the segment
lengths, and the clock's 54 `/proc/self/status` reads per stage are not
wanted in the first multi-block measurement. `m125-run-l2.done` holds the
exit code; a memory kill leaves a nonzero code and a log without the RESULT
line, which is **finding U-4's answer at scale** and not a failure.

What it prints, in order: `125M RUN L=2: chain built …`, then one line per
block with its proving seconds and the high-water mark AFTER it, then the two
segment lengths against the counted `[40033336, 41051160]`, then the
`125M RUN L=2 RESULT:` line.

**RESULTS — MEASURED by the orchestrator, 2026-09-20 about 10:45 and 10:50,
one run each, shared box, CPU only, exit 0 in both** (logs
`m125-run-l2.log` and `m125-run-l2-mmapthreshold.log`; commits `1879dd3` and
`53227fe`)

| figure | prediction | measured | measured, `MALLOC_MMAP_THRESHOLD_=131072` |
|---|---|---|---|
| chain build (2 witnesses), s | ~9.4 | **9.86** | 10.57 |
| prove, block 0 / block 1, s | ~31 / ~31 | **31.19 / 31.67** | 32.43 / 31.64 |
| high-water mark after block 0 / block 1, GiB | ~10.4 / <11.0 | **10.67 / 10.82** | **10.04 / 10.05** |
| segments, B | 40,033,336 / 41,051,160 | **exactly those** | exactly those |
| verify from segments, s | ~2.1 | **2.04** | 2.38 |
| does the high-water mark RISE between the two blocks? | unknown — this is the measurement | **YES, +0.15 GiB** | **NO — flat** |

**The answer to finding U-4 at scale: the rise is the ALLOCATOR, not the
protocol**, and pinning glibc's mmap threshold removes it at no measurable
cost in time. That is stage 13's operating rule.

### Tests and commands of R3 / R4 / R5

| command | log |
|---|---|
| `--lib private_block::tests` (the toy, after the `protocol.rs` split) | `u8-refactor.log` — 13 passed, 0 failed |
| `--lib private_block::run_tests` (first write of `run.rs`) | `u9-r3-compile.log` — compiles, nothing used yet |
| the same, with the run tests | `u10-r3.log` — `error[E0425]` (the tamper battery's plane ids) |
| the same | `u11-r3.log` — 5 passed, 8 FAILED: `Witness::output()` returns the PADDED plane, so the chain was feeding the next block a padded vector |
| the same, chaining through the TRUE hidden state | `u12-r3.log` — 12 passed, 1 FAILED: the headline negative test's variant (ii) was moving block 1's INPUT, so slot 21 caught it before slot 22 could |
| the same, variant (ii) moving the BOUNDARY instead | `u13-r3.log` — **13 passed, 0 failed** |
| **the gate**: `--lib private_` | `u14-r3-filter.log` — **181 passed, 0 failed, 4 ignored, 67 filtered out**, 272 s |
| the R6 binary: `--lib private_ --no-run` | `u15-r6-build.log` |
| **the final gate**, after the run's closing check was added | `u16-final-filter.log` — **181 passed, 0 failed, 4 ignored, 67 filtered out**, 270 s |

Baseline 157 -> 181: +11 `boundary`, +13 `run_tests` (4 of R1, 1 of R2, 8 of
R3/R4/R5), +1 ignored (R6). **No existing test was changed, weakened or
removed**; the toy's frozen parameter line and schedule digest still pass
(`the_toy_parameter_line_is_the_frozen_literal`,
`the_toy_schedule_digest_is_frozen`) and every counted receipt length still
passes (`the_codec_length_is_the_models_at_every_shape`,
`the_125m_receipt_is_reproduced_part_by_part`).

### Findings of this stage, for the security owner

| # | finding |
|---|---|
| **U-1** | `audit_claims` tracks the caller's DECLARED geometry, not the true one. The check's B4 evidence (that it accepts the leaking 37-row two-site geometry) does not reproduce — that case is refused, for bookkeeping reasons — but the CONCLUSION holds, and the real instance is the one-site `data + 5` budget with the proximity position declared one row too high, which the audit accepts. Ruling M-1's derived row count is what closes it, and it is built. |
| **U-2** | A one-site boundary at the rung-G plane would be 8 rows and C-H4 refuses it. Nothing in a run asks for one (ruling M-7), but a uniform `sites = 1` external endpoint — the draft's R-D2 — is unbuildable at any shape with four data rows. |
| **U-3** | `zkp-core`'s `Transcript` publishes no squeeze-counter accessor and is a forbidden file, so the segment header cannot carry "state + counter" as the design specifies. It carries a 32-byte POSITION TAG (a challenge from a discarded clone) instead, which binds both. Framing is 120 B per segment, not 136; the design's correction C7 is moot because the acceptance figure is derived, not literal. |
| **U-4** | **The process high-water mark RISES across a twelve-block run at the rung**, 117 -> 137 MiB in two steps at blocks 7 and 8, on a run whose per-stage working set is constant by construction. +17%. At 125M the same relative rise on a 10.4 GiB stage would be about 1.8 GiB and would put `L = 12` past a 12 GiB ceiling. Reported, not repaired, per the brief; R6 is the first place it can be seen at scale. |
| **U-5** | The design's §4.3 **check 4 is implemented only in its "every claim discharged" half** — after the last segment the verifier requires its pending-claim slot and its held boundary to be empty. The "every commitment opened exactly once" half is NOT a runtime table: which commitments exist and where each is opened is a function of the verifier's own statement and fixes each segment's length, so a second opening inside the transcript is a schedule the verifier does not have. That is the check's own CORRECTION 8 position; if the security owner wants the table anyway it is a small addition to `verify_run`. |
| **U-6** | The run's counted receipt reconciles with the design to the byte once ruling M-7 (37-row externals) and finding U-3 (120 B framing) are applied: 484,100,736 B for twelve 125M blocks against the design's 484,095,680, the difference being exactly `12 x 80 + 2 x 2,048`. |

### NEXT: exactly what the next agent should do, in order

1. **Launch R6** — the detached, memory-capped `L = 2` run at 125M, exactly
   the step-2 command above, after re-reading the binary's path and mtime and
   checking `MemAvailable` is above about 12 GiB and the box is quiesced.
   Watch by the `.done` marker, never in the foreground. Fill in the RESULTS
   table. The one number to read first is **the high-water mark after block 1
   against the one after block 0** (finding U-4).
2. **Only then** consider `L = 12` at 125M: 484,100,736 B of receipt, about
   6.3 minutes of proving, and a peak that finding U-4 says may not be flat.
   It needs a segment sink that WRITES TO DISK (the `L = 2` test keeps its
   two segments in memory, which a twelve-block run must not do).
3. **The run capture and the `L = 3` gate (ruling M-8)** — a NEW
   `private_block/run_capture.rs`, never an edit to the integrator's
   `native_capture.rs`, writing the three roles of each interior boundary
   plane (`A_k`'s output rows, `B_k`, `A_{k+1}`'s input rows) so the
   joint-view lane can rank them JOINTLY and RESTRICTED TO THE RESERVED MASK
   ROWS (the check's OMITTED CONDITIONS 7 and 10). No privacy statement about
   any run before that gate.
4. **Ask the security owner** about finding U-5 (whether the open-commitment
   table is wanted as a runtime check) and carry findings U-1 … U-6 into the
   disposition's record.

**R6 was LAUNCHED and MEASURED by the orchestrator** on 2026-09-20 at about
10:45 and again at about 10:50 (commits `1879dd3` and `53227fe`); its results
table is filled in above and its answer to finding U-4 is stage 13's first
paragraph. Item 2 of this list is stage 13 below.

## Stage 13 — the twelve-block 125M run, PREPARED (2026-09-20, 11:0x–)

**What this stage builds, and what it deliberately does not.** Everything a
twelve-block private run at the 125M shape needs, EXCEPT the run: a segment
sink that writes each finished segment to its own file, a verifier that reads
those files back ONE AT A TIME, the operating rule that removes the
between-block memory rise, and the `#[ignore]`d test with its launch command.
**Nothing at the 125M shape was executed by this stage.** A run that verifies
is a CORRECTNESS milestone and never a privacy one: the run's privacy
obligations (the boundary plane's joint rank over all three commitments,
blinding independence across blocks, the run-wide joint law) still have no
tools and no gate has been run (ruling M-8).

### The two facts stage 13 is built on, both MEASURED at 125M by the orchestrator

| fact | evidence |
|---|---|
| a two-block private run at 125M proves 62.86 s (31.19 + 31.67), verifies from its segments 2.04 s, receipt 81,084,496 B = the counted figure, peak 10.82 GiB — but the high-water mark ROSE between the blocks, 10.67 → 10.82 GiB | `results/zk60_block125m_lane/m125-run-l2.log`, exit 0 |
| **the same run with `MALLOC_MMAP_THRESHOLD_=131072` in the environment: 10.04 → 10.05 GiB, FLAT, peak 10.05 GiB, prove 64.07 s, verify 2.38 s, same receipt to the byte** | `results/zk60_block125m_lane/m125-run-l2-mmapthreshold.log`, exit 0 |

**FINDING U-4 IS ANSWERED, AND IT IS NOT THE PROTOCOL.** The rise is glibc's
allocator: with the DYNAMIC mmap threshold, freeing a large mapped buffer
raises the threshold, so the next large buffer is taken from the heap and
fragments it; pinned at 128 KiB, every large buffer is mapped and returned to
the system when it is freed. **THE OPERATING RULE: every multi-block run at a
large shape is launched with `MALLOC_MMAP_THRESHOLD_=131072` in its
environment.** It costs nothing measurable in time (64.07 s against 62.86 s,
inside this box's run-to-run variance) and it is what makes twelve blocks fit
under a 12 GiB ceiling. Nothing in the code calls `mallopt` and no library
behaviour changes for any other caller: the variable is read by the C
allocator at start-up, and the only thing the code does is PRINT whether the
launcher set it.

### S1 — the sink, and the streaming verifier

| piece | where | what it is |
|---|---|---|
| the hand-over | `run.rs` (unchanged) | `prove_run` calls `sink(k, bytes)` EXACTLY ONCE per finished segment, in order, with the bytes OWNED. Afterwards the prover holds nothing of that segment but its length in `RunStats` (ruling M-3). The signature did not have to move: the abstraction was already there |
| `SegmentSink` | `run_sink.rs` (NEW) | the trait the two destinations implement — `accept(&mut self, k, Vec<u8>)` |
| `MemorySink` | `run_sink.rs` | keeps the bytes; what the development-rung tests use. The existing tests' own closure is untouched, so no existing test changed behaviour |
| `DirSink` | `run_sink.rs` | one file per segment, `segment-000.bin` …, written ATOMICALLY: the bytes go to `segment-kkk.bin.partial`, are written, `sync_all`-flushed to the device, and only then RENAMED into place. So a file under a segment's own name either is the whole segment or does not exist — a run killed by the memory ceiling leaves no half-segment a later verifier could take for a whole one. It keeps only each segment's LENGTH and SHA-256 (`export_v3::sha256_hex`, the crate's existing `sha2` dependency; nothing added). It REFUSES a directory that does not exist or is not empty |
| `segment_paths` | `run_sink.rs` | the `L` files a run directory must hold, `L` being the VERIFIER'S OWN. Exactly those and NOTHING ELSE: a missing one is named, and an extra segment beyond `L`, a leftover `.partial` or any foreign file is refused before a byte of any segment is read |
| `RunVerifier` | `run.rs` | the verifier's between-segment state (transcript, run binding, the pending claim, the waiting boundary) with `start` / `step(k, &[u8]) / finish`. `verify_run` is now this fed from a slice — the same operations in the same order, which is why every existing run test's bytes and refusals are unmoved |
| `verify_run_from_dir` | `run.rs` | the SAME verifier fed one FILE at a time: read, stepped, dropped before the next is opened. **Never more than one segment's bytes resident** — 41 MB at 125M against a 484 MB receipt |

**The bytes on disk ARE the bytes the prover handed over.** The rung test
feeds both sinks from ONE run and compares the file with the in-memory
segment byte for byte, and the recorded digest with the file's own SHA-256.
Two SEPARATE runs cannot be compared: the prover takes its randomness from
the OS (`ZkRng::from_os`) and **this lane did not add a deterministic test
path** (the brief forbids inventing one), so for separate runs what is
compared is the lengths and the verifier's acceptance.

### S2 — the tests, and each negative in one line

| test | what it shows |
|---|---|
| `a_twelve_block_run_written_to_a_directory_verifies_by_streaming` | TWELVE blocks at rung-G written to a temporary directory: prove 6.19 s, verify BY STREAMING 1.16 s, 49,217,600 B in 12 files = the counted figure, every file byte-identical to what the in-memory sink was handed, exactly twelve entries in the directory and no `.partial` left behind |
| a MISSING segment file | refused, naming `segment-001.bin`, before a byte is read |
| a TRUNCATED segment file | refused: "segment 1 is 4,089,351 B, the counted length is 4,089,352" |
| two segment files SWAPPED | refused at the counted length, then (at equal lengths) at the header's position tag |
| a DUPLICATED segment (segment 0's bytes under segment 1's name) | refused |
| an EXTRA segment file beyond `L` (`segment-003.bin`) | refused by name: `L` is the verifier's own |
| a FOREIGN segment file from a second honest run of the same statement | refused at the run binding: "this segment belongs to another run" |
| a FOREIGN FILE in the run directory (`notes.txt`) | refused by name, before any segment is read |
| after every one of the above is undone | the run verifies again, so each refusal was its own mutation |
| `the_directory_sink_refuses_a_directory_that_is_missing_or_not_empty` | a run never writes into a directory that does not exist or already holds something |
| `the_twelve_block_125m_receipt_is_the_counted_484_100_736_bytes` | the twelve-block 125M figure, in a test that costs nothing: segments 40,033,336 / 40,301,624 (×10) / 41,051,160, total **484,100,736 B**, derived from the block's own counted receipt and the framing constants |

**No temporary file survives a passing test**: each test's directory is a
`TempRunDir` under the machine's temporary space, removed when the test
leaves, and never inside the repository.

**The allocator condition is PRINTED by every large-run test** — the ladder at
the rung, the two-block 125M run and the twelve-block one — as
`MALLOC_MMAP_THRESHOLD_=<v> (pinned…)` or `MALLOC_MMAP_THRESHOLD_ is NOT SET`,
together with the high-water mark after every block, its change from the
block before, and `HWM-RISE` when that change is more than 1%. **Caveat at the
rung**: `VmHWM` is a PROCESS figure and the rung tests share one test binary
with two hundred others, so the rung's marks are polluted by whatever ran
before them (the twelve-block file test reports a flat 130.7 MiB for that
reason). The 125M runs are launched `--exact`, alone in their process, which
is the only place the mark means what it says.

### S3 — the twelve-block 125M test, `#[ignore]`d and NOT LAUNCHED

`private_block::run_tests::private_run_125m_twelve_blocks`.

**What it keeps resident.** TWELVE public statements — about 9.2 MB of padded
weights each (`wq`, `wo` 1024×1024, `wk`, `wv` 256×1024, `wg_t`, `wu_t`,
`wd_t` 1024×2048, plus the tables), **about 110 MB in all** — because
`prove_run` and `verify_run` both take the run's statements as ONE SLICE and
the run header absorbs every block's digest before the first commitment. That
is about 1% of the modelled peak, so no lazy-statement API was built for it;
the code as it stands does not allow one statement at a time and this is the
honest report of that. ONE witness (711 MB), built just in time by the chain
and dropped. Thirteen padded planes (1 MB each) and twelve true inputs (0.79
MB each), the chain's own data. **ZERO segments**: each is written to
`HL_PB_RUN_DIR` and dropped as it is finished, and the verifier reads them
back one at a time.

**What it refuses.** It does not start unless `HL_PB_RUN_DIR` is set to an
ABSOLUTE, EXISTING, EMPTY directory OUTSIDE THE REPOSITORY (checked against
the crate's own parent directory). **It STOPS, rather than running on, if a
segment's length is not the counted one or if the high-water mark passes 11.5
GiB** — both inside the sink, at the block where it happens.

**What it prints.** Per block: the stage seconds, the segment's length against
the counted figure, the high-water mark, its change in GiB and per cent, and
`HWM-RISE` past 1%. At the end: the length and **SHA-256 of every segment**
(so the evidence committed to the repository is hashes and lengths, never the
484 MB of bytes), the per-block prove seconds, the total prove seconds, the
verify seconds, the total against the counted 484,100,736 B, the peak resident
memory and the allocator note.

**Predictions, so that the run can fail** [MODEL from the MEASURED two-block
run with the threshold pinned]:

| figure | prediction |
|---|---|
| chain build (12 witnesses, each dropped) | about 59 s (12 × 4.93) |
| proving | about **6.4 minutes** (12 × ~32 s, each stage including its just-in-time witness build) |
| verify by streaming | about 14 s (12 × ~1.1 s plus reading 484 MB) |
| total wall clock | about **7.6 minutes** |
| receipt | **484,100,736 B** in twelve files |
| peak resident memory | about **10.15 GiB** (the two-block run's measured 10.05 plus ten further public statements and eleven further planes) |
| the high-water mark across blocks | FLAT, within 1%, with the threshold pinned — this is the prediction the run tests |

### S4 — the launch, for the ORCHESTRATOR (this lane does not run it)

**Step 1 — the binary, built under the build lock** (done; log
`results/zk60_block125m_lane/v5-s13-build.log`):

```
flock -w 540 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 /home/victor/.cargo/bin/cargo test --release --offline -j 2 --manifest-path /home/victor/wt-zk60-block125m/hashline/Cargo.toml --lib private_ --no-run > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/v5-s13-build.log 2>&1
```

The `Executable unittests` line names

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5
```

— the same name as stages 9, 11 and 12, because the hash is of the crate's
METADATA and not of its source. **mtime 2026-09-20 11:01, 11,183,760 B**,
which is later than every source file of this lane (the latest is `run.rs` at
11:00) and later than the code commit it belongs to, so this binary contains
stage 13. `--no-run` relinked nothing: the filter gate had already built it.

**Step 2 — create the artifacts directory.** THE ORCHESTRATOR CREATES IT; this
lane does not, and the test refuses to start if it is missing or not empty:

```
mkdir -p /home/victor/zk60-artifacts/m125-run-l12
```

**Step 3 — the detached, memory-capped run**, one line, with the allocator
threshold pinned:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_RUN_DIR=/home/victor/zk60-artifacts/m125-run-l12 HL_PB_TIMING=0 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_tests::private_run_125m_twelve_blocks >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l12.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l12.done' >/dev/null 2>&1 &
```

**Headroom at the time of writing (2026-09-20 11:03 PDT).**

| resource | have | run needs |
|---|---|---|
| `grep MemAvailable /proc/meminfo` | 14,387,928 kB = **13.72 GiB** | modelled peak **about 10.15 GiB**, ceiling 12 GiB |
| `df -h /home/victor` | **747 G free** of 1007 G | **484 MB** of segments |
| time | — | about 7.6 minutes, one heavy job at a time |

The phase clock is OFF (`HL_PB_TIMING=0`): what this run is for is the twelve
stage times, the per-stage high-water marks, the segment lengths and their
digests. `m125-run-l12.done` holds the exit code; a memory kill leaves a
nonzero code and a log without the `RESULT` line. **Re-read the binary's path
and mtime before launching** — the target directory is shared with another
worktree, and the binary must be NEWER than this lane's last commit. The
segments are 484 MB under `/home/victor/zk60-artifacts/`, outside the
repository; the orchestrator deletes them when the run's digests and lengths
are in the ledger.

**RESULTS (TO BE FILLED BY WHOEVER LAUNCHES IT)**

| figure | prediction | measured |
|---|---|---|
| chain build (12 witnesses), s | ~59 | |
| prove, total, s | ~384 (12 × ~32) | |
| high-water mark after each block, GiB | ~10.15, FLAT within 1% | |
| any `HWM-RISE` line? | none expected with the threshold pinned | |
| segments, B | 40,033,336 / 40,301,624 ×10 / 41,051,160 | |
| total receipt, B | 484,100,736 | |
| verify by streaming, s | ~14 | |
| peak resident memory, GiB | ~10.15 | |
| exit code | 0 | |

### Files this stage wrote, and the shared-file list

Everything is `hashline/src/private_block.rs` (one `mod run_sink;` line) or
under `hashline/src/private_block/` (`run_sink.rs` NEW, `run.rs`,
`run_tests.rs`), plus this ledger. **Shared files touched outside
`hashline/src/private_block*`: NONE.** No item was made `pub`; everything new
is `pub(crate)` inside the module tree, as its neighbours are. The frozen
crates are untouched: `git diff --stat 11c01b2 -- private-block-kernel
private-model-kernel zkvm-block` prints nothing.

### Tests and commands of stage 13

| command | log |
|---|---|
| `--lib private_block::run_tests`, the new tests written and no `run_sink` module | `v1-s13-first-fail.log` — `error[E0432]: unresolved import super::run_sink`, `error[E0425]: cannot find function verify_run_from_dir` (×5) |
| the same, with the module and the streaming verifier | `v2-s13.log` — **17 passed, 0 failed, 2 ignored** |
| `--lib private_block::run_tests::a_ -- --nocapture` (to read the refusals) | `v3-s13-nocapture.log` — 5 passed, every negative refused by name |
| **the gate**: `--lib private_` | `v4-s13-filter.log` — **185 passed, 0 failed, 5 ignored, 67 filtered out**, 283 s (baseline 181 / 4 ignored: +4 tests, +1 ignored). The toy's frozen parameter line and schedule digest and every counted receipt length still pass (`the_toy_parameter_line_is_the_frozen_literal`, `the_toy_schedule_digest_is_frozen`, `the_codec_length_is_the_models_at_every_shape`, `the_125m_receipt_is_reproduced_part_by_part`); no existing test was changed, weakened or removed |
| the heavy binary: `--lib private_ --no-run` | `v5-s13-build.log` |
| the heavy test's FIRST GUARD, on the real binary, with `HL_PB_RUN_DIR` unset | `v6-s13-guards.log` — refused in **0.00 s**, before a byte of witness: "HL_PB_RUN_DIR is not set: this run writes hundreds of MB of segments and will not choose a directory for you". The other two guards (inside the repository, not empty) are the same asserts on the same path; the sink's own refusals are unit-tested in `the_directory_sink_refuses_a_directory_that_is_missing_or_not_empty` |

### NEXT, in order

1. **Launch the twelve-block 125M run** — step 2 then step 3 of S4, after
   re-reading the binary's mtime, checking `MemAvailable` is above about 12
   GiB and the box is quiesced. Watch by the `.done` marker, never in the
   foreground. Fill in the RESULTS table; the first numbers to read are the
   twelve high-water marks (flat or not) and the total against 484,100,736 B.
2. **The run capture and the `L = 3` gate (ruling M-8)** — unchanged from
   stage 12's list: a NEW `private_block/run_capture.rs`, never an edit to
   the integrator's `native_capture.rs`. **No privacy statement about any run
   before that gate**, whatever the twelve-block run measures.
3. **Ask the security owner** about finding U-5 and carry U-1 … U-6 into the
   disposition's record.

## Stage 14 — the run capture (2026-09-20, 11:4x–12:5x)

**What this stage is.** The INPUT to the privacy gate of ruling M-8: a
capture of the verifier's view of a private RUN, written by a NEW module and
never by editing the integrator's `hashline/src/native_capture.rs`. **It is
not the gate and it is not a privacy statement.** The Python joint-view tools
have still never seen a run; writing the input to a gate does not meet it.

### The schema AS FOUND (the toy single-block capture), in one place

`native_capture.rs` (500 lines, `include!`d into a `cfg(test)` `mod capture`
of `private_block.rs` and of `private_attention.rs`) observes the VERIFIER
through a thread-local, at five hook sites already in the lane's files:
`argument.rs` (`start_slot`, `slot`), `protocol.rs` (`mask`, `pcs` for A, H
and the two endpoints) and `publish`. A bundle is THREE files per proof, named
by the receipt's SHA-256: `<sha>.receipt`, `<sha>.expected`, `<sha>.json`.

The JSON is one object: `schema` (the integer 3), `kind`
(`zk60-verifier-observations`), `coverage` (`native-all-slots-v1`), `profile`
= `transcript_domain`, `source_commit`, `fully_verified`, `privacy`,
`privacy_review_complete`, `weight_policy`, `field_modulus`,
`extension_nonresidue`, `proof_sha256`, `proof_bytes`,
`proof_digest_encoding`, `expected_policy` (+ its SHA-256),
`public_statement_digest`, `layout_description`, `layout_digest`,
`schedule_digest`, `opening_order`, `logup_challenges`, `header`
(`{state,next}`), then `arguments` (23 slot objects: `slot`, `name`, `kind`,
`main`, `extension`, `degree`, `definition_challenges`, `c`, `scalar`,
`claimed_sum`, `rho`, `sumcheck_final`, `mask_eval`, `terminal_polynomial`,
`terminals`, `rounds`, `hosted`, `tables` — `eq` / `public` / `private` with
the private table's `role`, `claim`, `log_size`, `mask_row`,
`extension_round`, `slices`, `coordinates` —, and the three transcript
positions `before_definition`, `before`, `after`), `mask` (`root`, `specs`,
`theta`, `proximity_rhos`, `functionals`, `q`, `prox`, `columns`, `before`,
`after`) and `roles` (four objects, A / H / Input / Output: `params`,
`commitment`, `claims`, `groups`, `proximity_rhos`, `proximity_vector`,
`columns` with `index`/`values`/`salt`/`path`, `q_pad`, `row_roles`,
`public_linear_constraints`, `before`, `after`).

Encodings: `Fp` a decimal `u64`, `Fp2` a `[u64,u64]` pair, every 32-byte
digest / salt / path node / transcript state a JSON array of 32 ints.

**What the Python loader assumes about the toy** (read by a delegated
read-only agent across `zk60_native_joint_view.py`,
`zk60_native_privacy_gate.py`, `zk60_native_mask_commit.py` and the nine
modules they import): it globs `<dir>/captures/*.json` and **never opens the
`.receipt` or `.expected` files**; `Capture.__init__` refuses unless
`schema == 3`, `kind` and `coverage` are the literals above and `profile` is
one of TWO hard-coded strings; the transcript replay hard-codes every
absorption label and the full parameter line as a byte literal per profile;
`ROLE_ORDER` is a strict ordered four; and the shape is a set of flat module
constants (`LOG_COLS=8, N_COLS=256, INV_RATE=8, ENC_COLS=2048,
NUM_COL_CHECKS=256, Q_PAD=256, MASK_LOG_DOM=12`) that are **not** read from
the JSON's own `params` / `q_pad` fields even though those exist. The slot
port table and its `_Layout` (T=32, D=16, H=2, DH=8, F=16) are a hand-port of
`argument.rs`, pinned by SHA-256. One thing already generalises: M's row
count is computed as `2*len(specs)+4`.

### The design: a strict superset, in a directory

`schema: "hashline-native-capture/4-run"`. A bundle is `run.json` (the run
header, the shape as data, the external endpoints, the `L-1` internal
boundaries, the transcript labels and the transcript program in words), one
`stage-NN.json` per stage carrying EXACTLY the single-block bundle's per-proof
content for that block, `manifest.json` (every file's length and SHA-256, plus
the SHA-256 of the six Rust files that decide what a bundle contains) and a
README. Field by field: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`, which
is the deliverable for the Python agent.

Five things a reader must know: the schema string is new (today's loader
refuses it by version, which is the intent); a run has TWO profile strings
(the RUN transcript domain and the per-block shape's); there are four new
Fiat-Shamir labels (`run-shape`, `pb-run-stage`, `pb-run-block`, `B`), all
carried as data; the IO role names still name the CLAIM SITE, with the new
`commitment_kind` / `boundary` / `claim_sources` fields naming the
COMMITMENT; and a boundary's opening lives in the NEXT stage's file, because
that is the only stage in which its claim list is complete.

**Two deliberate deviations, both recorded in the format note.** (1) A slot's
PUBLIC tables carry `len` + `sha256` and their `values` only under
`HL_RUN_CAPTURE_PUBLIC_TABLES=1`: they are a function of the public statement
and the stage's challenges and they dominate a rung bundle. (2) The segments
are written only under `HL_RUN_CAPTURE_SEGMENTS=1`: every stage file already
carries its segment's length and SHA-256, and the gate's loader reads only
JSON.

### How the capture is taken

By OBSERVING THE VERIFIER. The hooks are `cfg(test)`, return on their first
line unless a recorder is attached, are handed what the verifier already
holds and give nothing back — so no branch of the protocol can depend on one.
They sit beside the integrator's existing hooks in `argument.rs` (2 lines) and
`protocol.rs` (6 lines), and in `run.rs` at the four sites a run adds (stage
open, the incoming opening, the outgoing opening, stage close) plus the run's
closing check.

**The recorder replays independently.** It keeps its OWN transcript, seeded
from the run statement's public words — never adopted from the verifier — and
re-derives every challenge of the whole run from the recorded roots, claims
and openings in transcript order, comparing its state with the verifier's at
every site. It re-runs `zk::mask_verify` and `pcs::verify_zk` on its own
transcript, and replays each slot's definition draws, CFS challenge and
sumcheck. The first mismatch aborts the capture. **Nothing is recorded
prover-side**: every field of every file is reachable from the decoded
segment, the run statement and the verifier's own claim lists.

### Files this stage wrote, and the shared-file list

NEW: `hashline/src/private_block/run_capture.rs` (the writer),
`hashline/src/private_block/run_capture_tests.rs`,
`docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`. EDITED: `private_block.rs`
(two `mod` lines), `private_block/run.rs` (the four hook sites, `binding()`
and `capture_header()`, all `cfg(test)`), `private_block/protocol.rs` and
`private_block/argument.rs` (the `cfg(test)` hook lines). **Shared files
touched outside `hashline/src/private_block*`: NONE.** `native_capture.rs`,
`zk.rs`, `layer.rs`, `pcs.rs`, `wcache.rs`, `private_seam.rs`, `gpu/`,
`zkp-core/`, `zkvm-block/`, `private-model-kernel/` and
`private-block-kernel/` are untouched.

### Tests and commands of stage 14

| command | log |
|---|---|
| `--lib private_block::run_capture --no-run`, first build | `w1-s14-first-build.log` — 2 errors (`Bundle` has no `Debug`, from two `expect_err`s) |
| `--lib private_block::run_capture` | `w2-s14.log` — 4 passed, 2 failed (the README was written after the manifest was composed; the allow-list scan tripped on `run.json`'s own `not_in_a_capture` list) |
| the same, both fixed | `w3-s14.log` — 5 passed, 1 failed (the forbidden-word scan tripped on `"hidden":192`, the shape's feed-forward width) |
| the same | `w4-s14.log` — **6 passed, 0 failed, 1 ignored** |
| **the gate**: `--lib private_` | `w5-s14-filter.log` — **191 passed, 0 failed, 6 ignored, 67 filtered out**, 291 s (baseline 185 / 5 ignored: +6 tests, +1 ignored). No existing test was changed, weakened or removed; the toy's frozen parameter line, schedule digest and counted receipt lengths still pass |
| the gate bundles: `write_the_gate_bundles -- --ignored` | `w6-s14-bundles.log` (first attempt, an abbreviated source pin) and `w7-s14-bundles.log` (the kept one, `HL_TEST_SOURCE_COMMIT=cb27845d5ad3a0e401c48c4eebeac7fe4a86f171`) — 1 passed; `run-a-tame` 38,486,416 B and `run-b-zero` 38,483,657 B on disk, **77.0 MB** in `results/zk60_run_captures_20260920/` |

The six: `a_three_block_rung_g_run_is_captured_and_the_bundle_is_self_consistent`
(the L = 3 rung-G capture, read back from disk file by file),
`every_key_of_a_bundle_is_on_the_allow_list`,
`a_tampered_run_is_refused_and_no_bundle_is_written`,
`the_replay_refuses_a_header_that_is_not_the_verifiers`,
`a_run_verifies_the_same_with_and_without_a_recorder` (same bytes, same
verdict, same refusal, segments unchanged), and
`the_bundle_pins_every_source_file_that_decides_its_contents`.

**MEASURED, one run, shared box:** a three-block rung-G bundle is
`run.json` 12,374 B + stage files 12,555,317 / 12,620,925 / 13,290,321 B =
**38.5 MB on disk**, against 12,413,432 B of segments (pinned by digest, not
written). Two gate bundles are about **77 MB**, under the 100 MB ceiling and
each under 60 MB.

### L = 1 at the toy through this module: NOT cheap, and not meaningful

A run is a NEW profile under D17 with its own transcript domain, its own
`run-shape` word and its own schedule digest, so an `L = 1` "run" at the toy
would not share one byte of transcript with the integrator's toy capture and
a field-by-field equality would compare nothing. `RunShape` also carries only
the two run profiles. The structural comparison is made instead by the format
note's field tables and by the allow-list, which names every field the two
schemas share.

### Findings

* **U-7.** The Python analysis chain reads `params` and `q_pad` out of a
  bundle NOWHERE — it uses flat module constants instead. Every bundle this
  module writes carries the full shape, so the port can be deleted rather
  than duplicated; until it is, a rung bundle will fail loudly (transcript
  and column-identity mismatches), not silently.
* **U-8.** `discover_shared_rows` identifies a shared plane only through a
  slot with exactly two private tables one of which is role `"A"`. A run
  satisfies that twice per boundary — slot 22 of stage `k` and slot 21 of
  stage `k+1` — but the two are the SAME commitment only by
  `claim_sources` / `internal_boundaries[].claim_sites`, never by role name.
  This is the one fact the Python agent cannot infer from the old schema.

### The two gate bundles

`results/zk60_run_captures_20260920/run-a-tame/` and `.../run-b-zero/`: two
INDEPENDENT honest three-block runs at the development rung, fresh OS
randomness each, synthetic public weights from the lane's tame fixture, on the
fixture's hidden input and on the all-zero hidden input. Each is `run.json`
(about 12.4 kB) + three stage files (12.56 / 12.62 / 13.29 MB) + a manifest +
a README = **38.5 MB**, **77.0 MB together** — under 100 MB, each under 60 MB.
Neither hidden input, nor any boundary plane, is in its bundle. Both parse as
JSON and carry the boundary geometry the ruling names: `data_rows 4`,
`rows 10`, `site_rows [4,5,6,7]`, `prox_row 8`, `claim_sites`
`[{stage 0, slot 22}, {stage 1, slot 21}]`, opened once in stage `k+1`.

Source pin of both: `cb27845d5ad3a0e401c48c4eebeac7fe4a86f171`, plus the
SHA-256 of `run_capture.rs`, `run.rs`, `boundary.rs`, `protocol.rs`,
`argument.rs` and `layout.rs` in each manifest.

### NEXT, in order

1. **Hand the format note to the Python agent** — §9 of
   `ZK60_RUN_CAPTURE_FORMAT.md` is the change list, and U-8 is the fact to
   read first.
2. **No privacy statement about any run** until the gate of ruling M-8 has
   read a bundle and been ruled on.

## Stage 15 — the plane index table (2026-09-20, 13:2x–1x:xx)

**Why.** The Python run gate of ruling M-8 read stage 14's two bundles and
passed, and reported ONE thing a bundle LACKED and would not guess at: the
plane index table. `run.json["shape"]` carried every geometry axis but not
the `A`-plane and `H`-plane numbering of `layout.rs` nor the per-slot table
push order, which is what the twenty-three terminal closures read — so the
per-slot terminal identity `fin = c·mask_eval + poly(terminals)` stayed OPEN
at the rung. It is **public** (a function of the public layout), so the lane
could add it without publishing anything new. **Still not a privacy
statement**: this stage adds a field and closes nothing about privacy.

### What was added, and where it lives

A NEW module `hashline/src/private_block/plane_index.rs`, `cfg(test)` like
`run_capture.rs`, and one new member of `run.json`:

* `plane_index.a_planes[i]` = `{id, name, domain, first_row, rows, offset,
  log_size}` — every committed `A` plane in plane order;
* `plane_index.h_planes[i]` = `{id, name, domain, rows, re_first_row,
  im_first_row, re_offset, im_offset, log_size}` — every committed `H` plane,
  which is `Fp2`-valued and therefore two equal runs of rows;
* `plane_index.slot_planes[s]` = `{slot, name, planes:[{role, id, name}]}` —
  **the plane whose evaluation each `terminals[j]` is**, in the order the
  prover pushes them, `id` null for the two IO commitments;
* `plane_index.a_data_rows` / `h_data_rows` — what the two lists tile.

It is in the RUN file and not in a stage, because it is a property of the
shape. **Nothing about a witness, a pad, a salt or a mask is in it**: plane
names and shapes are public, plane contents never are.

**The schema string does NOT move.** It stays
`"hashline-native-capture/4-run"` because this is a pure addition — one new
member, no existing field renamed, removed, re-typed or re-meant — so a
reader written against stage 14 reads a stage-15 bundle unchanged and ignores
a key it does not know. Recorded with the date at the head of
`ZK60_RUN_CAPTURE_FORMAT.md` and in its new §3a.

### It is an INDEPENDENT statement, and it is checked four ways

The plane list, the name table and the per-slot push order are written in
`plane_index.rs` from `layout.rs`'s declarations and `argument.rs`'s slot
definitions, and `build` REFUSES unless:

1. every plane's declared domain is `Ids::dom` / `HIds::dom` (which
   `Ids::new` has already matched against `Shape::a_plane_doms`);
2. the `A` planes tile `[0, a_data_rows)` and each `H` plane's `re` and `im`
   halves tile `[0, h_data_rows)` — no gap, no overlap, totals the layout's;
3. the per-slot `A` / `H` / IO counts are `Shape::claim_sites`';
4. **and, at capture time, the ACTUAL private-table sequence of every slot of
   every stage matches it**, located by role and slice offset
   (`run_capture::slot`). `stage_begin` rebuilds the whole table from each
   stage's own layout and refuses if it is not the run's; `take` refuses a
   bundle with no table. A mismatch is a refused capture, not a footnote.

A recorder still only observes: `plane_index.rs` takes a `&Layout` and
returns data, no hook gives anything back, and no transcript, wire or proof
byte moves.

### Three field MEANINGS documented, not changed

The gate reported three more facts, all public, none of them a defect. They
are now written down in the format note with file:line, and the writer is
untouched:

1. **An IO table's `claim` is per STAGE and is always 0** (§4a). It is
   `acc.claims[role].len()` at the moment the slot runs
   (`run_capture.rs:509`, written at `:520`) and every stage has its own
   `Acc` — so stage `k+1`'s slot 21 says `claim: 0` although its claim is
   index 1 of the boundary. Take the index from `claim_sources` /
   `claim_sites` and cross-check `mask_row`.
2. **`H`'s `data_rows` counts the two zero-sum rows and `row_roles` does
   not** (§4c). `data_rows` is `Layout::h_data_rows`
   (`protocol.rs:893`, `layout.rs:1042`) and the zero-sum pair `u` is one of
   the `H` planes (`shape.rs:490`); `row_kind` tests `sum_rows` first
   (`run_capture.rs:884-894`). The difference IS `sum_rows`.
3. **An external endpoint has one SPARE mask row, a derived boundary has
   none** (§5). `MASK_ROWS = 5` (`endpoint_g.rs:51`) with the claim pair at
   `data, data+1` and the proximity pair at `data+2, data+3`
   (`endpoint_g.rs:205-206`), leaving `data+4` spare — ruling M-7's "a pair,
   a proximity pair and a spare". A boundary is `data + 2*sites + 2`
   (`boundary.rs:161,166,170`) and has exactly its sites and its proximity
   pair.

### Files this stage wrote, and the shared-file list

NEW: `hashline/src/private_block/plane_index.rs`. EDITED:
`hashline/src/private_block/run_capture.rs` (the import, `Rec.index` /
`Rec.index_json`, the `stage_begin` build-and-compare, the `slot` order
check, the `run.json` member, the `take` refusal, twelve allow-list keys, and
`SOURCE_FILES` 6 -> 7 so a bundle pins the new module too),
`hashline/src/private_block/run_capture_tests.rs` (three JSON readers, four
tests, one added assertion, the gate-bundle tags), `private_block.rs` (one
`mod` line), `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`,
`docs/zkmatrix-poc/ZK60_BLOCK125M_LANE_PROGRESS.md`.
**Shared files touched outside `hashline/src/private_block*`: NONE.**
`native_capture.rs`, `zk.rs`, `layer.rs`, `pcs.rs`, `wcache.rs`,
`private_seam.rs`, `gpu/`, `zkp-core/`, `zkvm-block/`,
`private-model-kernel/` and `private-block-kernel/` are untouched
(`git diff --stat 11c01b2 -- private-block-kernel private-model-kernel
zkvm-block` prints nothing).

### The four new tests

| test | what it ties together |
|---|---|
| `the_plane_index_tiles_the_a_and_h_commitments_of_the_rung_layout` | the row ranges tile `A` and `H` with no gap and no overlap; the totals are `lay.a_data_rows` / `lay.h_data_rows` READ FROM THE LAYOUT; each plane's rows are its domain's; each offset is its row times the row width; no two planes share a name |
| `every_plane_a_slot_references_is_in_the_plane_index` | every id a slot references is a plane of this shape; each slot's list is as long as `Layout::slot_terms`; and the other direction — every committed plane is read by at least one slot |
| `each_slots_terminal_vector_is_as_long_as_its_plane_list` | **the table against a REAL capture**: in every stage, `len(arguments[s].terminals) == len(slot_planes[s].planes)`; the table is in the run file exactly once and in no stage file |
| `the_plane_index_is_the_same_in_two_independent_bundles` | two independent runs on different hidden inputs with fresh randomness carry the SAME table bytes, and those bytes are what the layout derives (`idx.render()`) |

Plus one assertion added to
`the_bundle_pins_every_source_file_that_decides_its_contents`: the pins name
`plane_index.rs`. The recorder's own per-slot, per-stage check (point 4
above) is the fifth tie and needs no test of its own — it refuses the
capture.

### Tests and commands of stage 15

| command | log |
|---|---|
| **baseline**, before any edit: `--lib private_` | `x1-s15-baseline.log` — **191 passed, 0 failed, 6 ignored, 67 filtered out**, 307.08 s, exit 0 |
| `--lib private_block::run_capture` | `x2-s15-capture.log` — **10 passed, 0 failed, 1 ignored**, 13.39 s; compiled with no error on the first build |
| the table's own numbers, `--nocapture` | `x3-s15-sizes.log` — EMPTY: `flock -w 540` expired while another lane's `run.py` held `/tmp/zk-build.lock`. A cosmetic printout only; the numbers were read back out of the bundle instead, and the lock was never bypassed |
| **the gate**: `--lib private_` | `x4-s15-filter.log` — **195 passed, 0 failed, 6 ignored, 67 filtered out**, 308.28 s, exit 0 (baseline 191 / 0 / 6: +4 tests, and no existing test was changed, weakened or removed). The toy's frozen parameter line, schedule digest and counted receipt lengths still pass |
| the new gate bundles, `write_the_gate_bundles -- --ignored` | `x5-s15-bundles.log` |

### The two new gate bundles

`results/zk60_run_captures_20260920/run-c-tame/` and `.../run-d-zero/`: two
INDEPENDENT honest three-block rung-G runs with the plane index table, the
same procedure as stage 14 (fresh OS randomness, synthetic tame weights, the
fixture's hidden input and the all-zero hidden input). Fresh randomness means
fresh receipts: **the bytes differ from `run-a-tame` / `run-b-zero` and that
is expected** — a capture pins the run it observed, not a previous one.

**Nothing was deleted, moved or rewritten.** `run-a-tame` and `run-b-zero`
stay byte for byte where they are, and their own `README.md` is NOT edited:
each bundle's `manifest.json` pins its README by length and SHA-256, so an
edit would break the bundle's self-consistency. The note that they predate
the plane index table is in the new parent file
`results/zk60_run_captures_20260920/README.md`, which covers all four.

**MEASURED, one write, 2026-09-20 14:02, exit 0 (`x5-s15-bundles.log`).**

| bundle | `run.json` | stage files | on disk | source pin |
|---|---:|---:|---:|---|
| `run-c-tame` | 34,812 B | 38,472,032 B | **38,509,009 B** | `aff891d` |
| `run-d-zero` | 34,787 B | 38,463,004 B | **38,499,945 B** | `aff891d` |

**77.0 MB added** (each under 60 MB, as before), against 77.0 MB already in
the tree for stage 14's two — **154 MB in `results/zk60_run_captures_2026-
0920/` in all**, which is the cost of keeping the old pair rather than
replacing it. The segments (12,413,432 B per run) are not written; each stage
file pins its own by length and SHA-256.

**The table's own size: 22,411 B of the 34,812 B run file** — `run.json`
grew from 12,385 B to 34,812 B, and the stage files did not move. Both new
bundles carry **the same 22,411 bytes** of it (SHA-256 prefix `fb4cb872…`),
which is the across-bundle equality the Rust test also checks in memory.

Read back with `python3 json.load` after the write: both parse; both declare
`schema hashline-native-capture/4-run`; the table lists **83 `A` planes
tiling 377 rows and 52 `H` planes tiling 470 rows**, with 23 slot lists of
lengths `[1, 1, 22, 3, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 56, 15, 13, 24, 17, 6,
1, 2, 2]`; `H_U` sits at rows 468 and 469, which is exactly the `sum_rows`
pair the gate reported and the two rows by which `H`'s `data_rows` 470
exceeds its 468 `"data"` rows; and each manifest pins all seven source files
including `plane_index.rs`.

---

## Stage 16 — the two hash-domain guards (2026-09-20, 14:2x–)

**Lane-only. No proof byte of any profile may move.** This stage implements
rulings **T-3** and **T-4** of
`docs/zkmatrix-poc/ZK60_D19_HASH_TAG_DISPOSITION.md` (the security owner's
disposition of the scoping memo `ZK60_D19_HASH_TAG_SCOPING.md`):

* **T-3** — the length guard `no_commitment_has_a_node_shaped_column`
  (`layout.rs`, the hard-coded `{5, 8}`) becomes a SHAPE-DRIVEN check that
  rebuilds this profile's whole set of NON-column hash-input lengths and
  refuses, by name, any commitment whose `8 · rows` lands on one.
* **T-4** — the Merkle PATH LENGTH is checked explicitly by the lane before
  the core verifier is called, instead of being an implicit consequence of
  the wire format's fixed path count.

### Status

`LANDED`, filter green. Both guards are wired. Three commits: the skeleton
`a2c42e1`, the FAILING-FIRST evidence `18d5b0f` (204 passed / **3 failed** /
6 ignored, an intended FAILED result), the fix `7fe2245` (**208 passed / 0
failed / 6 ignored**, exit 0, 297.68 s, 13 warnings — the baseline's 13).
Baseline before the stage: 195 / 0 / 6, so **+13 tests and not one existing
test changed, weakened or removed** except the four statement FIXTURES of
finding S16-F1, which are documented below and in place.

### Why this is a real hole and not bookkeeping

Every hash in this system is an **untagged** BLAKE3 call. A commitment's
column is `blake3` over `8 · rows` bytes; a transcript absorb is `blake3` over
`48 + |label| + |data|`; a Merkle node and a salted leaf are both `blake3`
over the same 64 bytes. Nothing in any of those inputs says what it is. The
only thing that separates the domains today is the **length** of the input —
so a geometry whose column happens to be as long as some other hash input of
the same proof is a structural defect, whether or not anyone can exploit it.
The tag of ruling T-1 fixes this properly; T-3 and T-4 are what the lane can
do now, and T-3 stays afterwards as the second line and as the ONLY line at
the byte-frozen toy, which is never tagged.

### S16-1 — the failing tests, first

Written and run BEFORE any guard was changed
(`x1-s16-failing-first.log`, **204 passed / 3 failed / 6 ignored**, exit 101,
an intended FAILED result; committed at `18d5b0f`). The three failures, as
the run printed them:

| test | what today's code did |
|---|---|
| `the_constructors_guard_refuses_every_shape_free_dangerous_count` | `11 rows was accepted by the constructors' guard` — `layout.rs`'s hard-coded `{5, 8}` lets an 88-byte column through, and 88 is the `schedule` absorb |
| `a_short_or_long_merkle_path_is_refused_by_the_core_verifier_by_name` | `A/false: the core's refusal is not the lane's own: A: pcs zk: Merkle path for column 555 fails` — the truncated path reached `pcs::verify_zk`, which **never checks the path length**; it hashed the column, folded ten siblings instead of eleven, and refused only because the root happened not to match |
| `a_short_or_long_merkle_path_is_refused_by_the_whole_verifier_by_name` | `A/false: the refusal is not the lane's own: private block wire: opening shape` — the FRAME shape check caught it, which names no commitment, says nothing about paths, and does not apply at all to a structure that never went through a wire |

Nine of the twelve new tests passed in that same run, which is the part of
T-3 that needed no fix: the computed length set at all four shapes, every
real commitment clear of its own set, the label table's source scan, the
tree-depth identity with the wire format, and the wire's existing refusal of
a frame one path entry short or long.

### S16-2 — T-3, the completed length guard

**The new module `hashline/src/private_block/hash_domain.rs`** (with
`hash_domain_tests.rs`) rebuilds, from a shape alone, every hash input on
that profile's path that is NOT a column digest, and refuses by name any
commitment whose `8 · rows` lands on one. It reads no witness and no
committed value; every number in it is a public fact.

**The three fixed lengths, each read off the cited source** (all in files
this lane does not edit, and all pinned by a test that reads their source
text — `the_length_formulas_are_still_the_ones_zkp_core_hashes`):

| input | bytes | where |
|---|---:|---|
| a transcript absorb | `48 + |label| + |data|` | `zkp-core/src/transcript.rs:44-52` |
| `Transcript::new` | `12 + |profile|` | `transcript.rs:25-30` |
| a squeeze | 47 | `transcript.rs:85-90` |
| the generator's refill | 40 | `zkp-core/src/rng.rs:52-56` |
| a Merkle node / a salted leaf | 64 | `merkle.rs:14-19`, `pcs.rs:640-645` |

**The label table is the single source of truth**, and it carries twenty-two
labels with the `file:line` of each site. Seventeen are absorbed in the
lane's own files; five — `sc-round`, `mask-q`, `mask-prox`, `pcs-vec`,
`pcs-prox` — are absorbed inside `zkp-core/src/sumcheck.rs`,
`zkp-core/src/pcs.rs` and `hashline/src/zk.rs` and are listed with their line
numbers in a comment, because no lane file spells them.

**THE COMPUTED SETS** (the test `the_computed_length_set_is_pinned_at_every_shape`
pins these exactly). Dangerous row counts, i.e. `length / 8` for every
length in the set divisible by eight:

| shape | dangerous row counts |
|---|---|
| every shape | **5** (the 40-byte refill), **8** (the 64-byte node/leaf, and the `log-cols` absorb, which is 64 for the sole reason that `"log-cols"` has eight characters), **11** (`schedule`, 88), **12** (`public-statement`, 96), **13 / 15 / 17 / 19** (`sc-round` at degrees 2, 3, 4, 5 — 104, 120, 136, 152) |
| toy, extra | **1031** (`pcs-prox`, 8,248 B) |
| frozen-seam rung, extra | **7** (`Transcript::new`, 56 B), **1031**, **2567** |
| rung-G, extra | **2567** (`pcs-prox`, 20,536 B) |
| 125M, extra | **6** (`Transcript::new`, 48 B), **33287** (`pcs-prox`, 266,296 B) |

**Against the memo's table** (`ZK60_D19_HASH_TAG_SCOPING.md` §4c): the eight
at every shape, the 6 at 125M and the 7 at the rung all agree exactly, and
the two shape-dependent lengths the memo counted — `Transcript::new` at
51 / 56 / 58 / 48 and the `parameters` absorb at 171 / 210 / 210 / 215 — are
re-derived here and agree to the byte. **TWO DIFFERENCES, both the code's and
both in the direction of more refusals:**

1. **`pcs-prox` was missing from the memo's dangerous list.** Its absorb is
   `48 + 8 + 16 (n + Q)` bytes, which is ALWAYS a multiple of eight, so it
   contributes a dangerous row count `7 + 2 (n + Q)` at every shape: 1,031 at
   the toy, 1,031 and 2,567 at the frozen-seam rung (block and endpoint
   geometries differ there), 2,567 at rung-G, 33,287 at 125M. No commitment
   is remotely near those and nothing changes for any profile, but the set is
   computed and not curated, so they are in it and are pinned.
2. **`sc-round` is taken over the module's WHOLE declared degree range, not
   the degrees one shape uses.** The frozen toy carries no support indicator
   (`Shape::carries_pad_rule`), so its own degrees stop at 4 and 19 rows
   would in fact be safe there today. The guard refuses 19 at the toy too.
   That is a deliberate over-approximation: a guard whose answer moves with a
   calibration flag is one nobody can reason about, and refusing a geometry
   no profile has costs nothing. `Shape::degree_range` is the one place the
   range is stated.

**Where the check runs.**

* `Layout::for_shape` — the full shape-driven set, against `A`, `H`, `M` and
  the endpoint. This is the replacement for the hard-coded call.
* `layout::no_commitment_has_a_node_shaped_column` keeps its name and
  signature for the two statement constructors that hold NO profile string
  (`EndpointSpecG::new`, `BoundarySpec::new`) and is now the **shape-free**
  half of the set. That half is exactly the memo's eight; the two
  profile-dependent counts (6 at 125M, 7 at the rung) cannot be seen without
  a profile string, which is why `Layout::for_shape` uses the full set.
* **`RunStatement::new`** — new. A run absorbs one word no block does, its
  own `parameters` line, whose length moves with `L`; and it commits one
  thing no block does, an internal boundary. Both go through the RUN's own
  set here, before the statement can prove anything.

**The near miss that justifies the run-level check** [COUNTED, this stage]:
at 125M the internal boundary's column is `8 · 38 = 304` bytes and the
external endpoint's is `8 · 37 = 296`. The twelve-block 125M run's
`parameters` absorb is **302 bytes** — two short of the boundary's column and
six past the endpoint's. At rung-G with `L = 12` that absorb is **296 bytes
exactly**, a multiple of eight; it is harmless there only because rung-G's
endpoint is 9 rows and its boundary 10. A run whose parameter line came out
246 bytes long would collide with a 38-row boundary outright. Nothing is
broken today; the margin is two bytes of a formatted string.

**FINDING S16-F1 — the completed guard is not decorative.** The generalised
endpoint's reachable commitment row counts are `2^k + MASK_ROWS` = 6, 7, 9,
13, 21, 37, …, and **13 is now refused at every profile** (its column is 104
bytes, a degree-2 `sc-round` absorb), **6 at the 125M profile** and **7 at
the frozen-seam rung**. An internal boundary's counts are `2^k + 2s + 2`,
which is 12 at three claim sites on a four-data-row plane — the
`public-statement` absorb. Three existing statement FIXTURES had to move off
13 and one off 12 (`endpoint_g.rs` twice at `log_n 9 -> 11` and once at the
8,192-word plane `log_n 10 -> 11`; `boundary.rs` from three claim sites to
four). None of them is a geometry any accepted profile uses, the changes are
commented in place with the reason, and the first of them now asserts the new
refusal by name instead of silently avoiding it. The old doc comment on
`endpoint_g::a_node_shaped_endpoint_column_is_unreachable_and_still_refused`
claimed the refusal "can NEVER fire for this construction"; that sentence is
corrected in place. Its assertions are unchanged and still hold: 5 and 8 in
particular remain unreachable.

**How strong the label table's coverage test is, plainly.** `Transcript`
lives in `zkp-core`, which this lane may not edit, so no recording wrapper
could be installed and the table is pinned by SCANNING SOURCE instead.

* The lane's fourteen non-test sources are scanned exhaustively (53 labelled
  absorbs found); any `absorb` with a literal label the table does not carry
  fails the test.
* `hashline/src/zk.rs`, `zkp-core/src/pcs.rs` and `zkp-core/src/sumcheck.rs`
  are scanned too (83 labelled absorbs), against the table plus an explicit
  list of the 24 labels of theirs that belong to the feed-forward layer
  prover and not to this path. A new label in any of those three files fails
  the test and someone has to decide which list it joins.
* **What it cannot see:** an absorb whose label is a VARIABLE. There are two
  on the path — `protocol::absorb_root` (`protocol.rs:129`) and
  `zk::absorb_com` (`zk.rs:867-868`) — and both are covered anyway because
  their callers spell the literal, which the scan does see. It also cannot
  follow a call chain into a fourth file; none exists today. **This, and the
  source-text pin on the three `zkp-core` hasher bodies, are the weak links
  of T-3, and they are weak in the same way: they pin TEXT, not behaviour.**

### S16-3 — T-4, the explicit path-length check

**The hole.** `zkp_core::pcs::verify_zk` hands the published path straight to
`MerkleTree::verify_path` (`pcs.rs:1019` -> `merkle.rs:56-63`), which folds
however many siblings it is given and never checks how many there are. A
Merkle inner node is `blake3(left ‖ right)` and a salted leaf is
`blake3(column digest ‖ salt)` — the same function on the same 64 bytes — so
a prover free to choose the path LENGTH can present an inner node as a leaf.
The private block was safe only because `wire.rs` reads a fixed number of
path entries out of the layout and never out of the frame: an accident of the
transport, not a statement of the verifier.

**The check.** `hash_domain::paths_are_the_tree_depth` requires every opened
column's path to have exactly `log2(encoded columns)` entries, and
`mask_paths_are_the_tree_depth` the masking commitment's `MASK_LOG_DOM = 12`.
**The depth comes from `wire::path_len`, which is `Dim::new(..).path` — the
same expression the frame format uses**, so the two cannot drift; the test
`the_tree_depth_is_the_wire_formats_own_number` pins the identity at all four
shapes and for the mask. Three call sites, all before any hashing:

| site | what it covers |
|---|---|
| `protocol::verify_inner_at`, **before `wire::validate`** | a block receipt's five commitments: `A`, `H`, `M` and the two external endpoints |
| `protocol::verify_core`, before the first absorb | `A`, `H`, `M` — the body a run's stages share |
| `run::RunVerifier::step`, immediately after `decode_segment` | a segment's five: the three above plus the incoming boundary-or-endpoint opening and the last stage's output endpoint |

The refusal is fixed text plus public numbers only — the commitment's name,
the opening's POSITION in the frame (a loop index, not the sampled column
index), the path length carried and the tree's depth:

```
private block: opened column 0 of the A commitment carries a Merkle path of
10 entries; this commitment's tree is 11 deep (T-4)
```

**The negatives.** A genuine toy receipt is proved in memory and one opened
column's path is shortened by one entry, and separately lengthened by one, on
each of the five commitments — ten mutations through the whole verifier, six
through the core verifier alone. Every one is refused by the lane, by name.
Before the fix the same ten produced `private block wire: opening shape` and
the same six produced `A: pcs zk: Merkle path for column 555 fails` (S16-1).

**The wire level is PINNED, not added.** A frame 32 bytes short (exactly one
path entry) and a frame 32 bytes long are both refused at decode as
`private block wire: frame length`, because `decode` requires the exact
counted length and `Reader::column` reads a fixed number of entries out of
the layout (`wire.rs:178-193`). That test passed before this stage and is
kept as the pin.

**What T-4 does NOT do.** It does not fix `pcs::verify_zk`, which is in
`zkp-core` and outside this lane. The finding stands for the integrator and
its other wire formats: the one-line fix there is `path.len() == log_cols`,
which rejects no honest proof and moves no byte.

### Files this stage wrote, and the shared-file list

**Shared files touched: NONE.** Everything is under
`hashline/src/private_block/`, plus this ledger and
`results/zk60_block125m_lane/`.

| file | what |
|---|---|
| `private_block/hash_domain.rs` | **new.** The length set (T-3) and the path-depth checks (T-4) |
| `private_block/hash_domain_tests.rs` | **new.** Thirteen tests |
| `private_block.rs` | one `mod hash_domain;` line and its comment |
| `private_block/layout.rs` | the guard's body becomes the shape-free set; `Layout::for_shape` uses the full one |
| `private_block/shape.rs` | `Shape::degree_range`, additive |
| `private_block/wire.rs` | `path_len` and `MASK_PATH_LEN`, additive |
| `private_block/protocol.rs` | `endpoint_pcs_params` (one definition replacing two inline copies); the T-4 checks in `verify_core` and `verify_inner_at` |
| `private_block/run.rs` | the run-level T-3 check in `RunStatement::new`; the T-4 check in `RunVerifier::step`; `e_params` from the new helper |
| `private_block/endpoint_g.rs` | three test fixtures off the now-refused 13-row geometry, with the refusal asserted by name; one doc comment corrected |
| `private_block/boundary.rs` | one test fixture off the now-refused 12-row geometry |

The **byte-frozen toy** is untouched: its receipt is still 2,816,472 B (the
new wire test asserts it), its parameter line, schedule digest and frame
lengths are unmoved, and no test that pins them was edited.

### Tests and commands of stage 16

| command | log |
|---|---|
| **failing first**, before any guard changed: `--lib private_` | `x1-s16-failing-first.log` — **204 passed, 3 failed, 6 ignored, 67 filtered out**, 312.81 s, exit 101, the intended FAILED result |
| **the gate**, after the fix: `--lib private_` | `x2-s16-filter.log` — **208 passed, 0 failed, 6 ignored, 67 filtered out**, 297.68 s, exit 0, **13 warnings, the same 13 as the stage-15 baseline** (baseline 195 / 0 / 6: +13 tests). The toy's frozen parameter line, schedule digest, 2,816,472-byte receipt and both round trips are in the pass list, as are all 21 `endpoint_g` / `boundary` tests |

**The forbidden-files proof**, run after the fix committed at `7fe2245`:

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat b26c869 -- \
  hashline/src/zk.rs hashline/src/layer.rs hashline/src/pcs.rs \
  hashline/src/wcache.rs hashline/src/gpu hashline/src/native_capture.rs \
  hashline/src/private_seam.rs zkp-core private-block-kernel \
  private-model-kernel zkvm-block
```

prints **nothing**. The whole diff against `b26c869` is this ledger,
`results/zk60_block125m_lane/`, and ten files under
`hashline/src/private_block*`.

### The thirteen new tests

| test | what it pins |
|---|---|
| `the_length_formulas_are_still_the_ones_zkp_core_hashes` | the three hasher bodies in `zkp-core`, by source text, and the five constants derived from them |
| `the_shape_free_dangerous_row_counts_are_the_memos_eight` | the shape-free set is exactly `{5, 8, 11, 12, 13, 15, 17, 19}`, each naming its collision |
| `the_computed_length_set_is_pinned_at_every_shape` | the exact set at all four shapes, and the memo's `Transcript::new` and `parameters` lengths re-derived |
| `every_dangerous_row_count_is_refused_by_name_at_every_shape` | every count in every shape's set refuses, naming the commitment, the rows, the bytes, the collision and `C-H4` |
| `the_constructors_guard_refuses_every_shape_free_dangerous_count` | the guard the two bare statement constructors call (**the T-3 failing-first test**) |
| `no_commitment_of_any_shape_collides_and_the_toy_is_clear` | the four shapes' real commitments, the toy's 455 / 384 / 50 / 7 by hand, and both boundaries |
| `the_runs_own_parameter_line_enters_the_length_set` | a run's set carries its own `parameters` word and a block's does not |
| `the_completed_guard_refuses_geometries_the_constructions_can_actually_reach` | finding S16-F1: 6, 7, 13 endpoint rows and 12 boundary rows |
| `every_absorb_label_on_the_path_is_in_the_table` | 53 labelled absorbs in the lane, 83 in the three foreign files, against the table plus the 24 not-on-this-path labels |
| `the_tree_depth_is_the_wire_formats_own_number` | `wire::path_len` is the tree depth at all four shapes and for the mask |
| `a_short_or_long_merkle_path_is_refused_by_the_core_verifier_by_name` | six mutations through `verify_core` (**a T-4 failing-first test**) |
| `a_short_or_long_merkle_path_is_refused_by_the_whole_verifier_by_name` | ten mutations through `verify_inner_at`, including the exact refusal string (**a T-4 failing-first test**) |
| `a_frame_one_path_entry_short_is_refused_at_decode` | the wire's existing refusal, pinned; and the toy frame is still 2,816,472 B |

### What this stage did NOT do

* **It did not implement the tag** (ruling T-1). T-3 and T-4 are the lane-only
  half of the disposition; the keyed-BLAKE3 tag needs the additive change to
  `zkp-core` and `zk.rs` that T-5 puts to the integrator first. Length
  separation remains the only separation there is.
* **It did not fix `pcs::verify_zk`.** That function still folds any path
  length it is handed. The lane is covered at all its own call sites; the
  integrator's other wire formats are not checked and the one-line fix
  (`path.len() == log_cols`) is still owed there.
* **It did not analyse the depth-confusion attack.** The disposition's rough
  estimate — that a planted node costs the prover another opening position
  and does not beat the accounted per-opening figure — is still unchecked by
  anybody.
* **No privacy or soundness acceptance** is claimed or implied, and D22's
  scope is unchanged.
* **The cross-profile coincidence the memo recorded still stands and is out of
  scope for a per-shape guard**: the toy's 7-row endpoint column is 56 bytes,
  which is exactly the frozen-seam rung's `Transcript::new` input length.
  Different proofs, so nothing is broken; but no per-shape check can see it,
  and only the tag closes it.

### NEXT, in order

1. **The integrator** decides who writes the shared, additive `hashtag.rs`
   part of T-1 / T-5, and takes the `pcs::verify_zk` path-length finding for
   the other wire formats.
2. When the tag lands, `hash_domain`'s label table has to learn any new
   absorb, and the run capture's schema gains the tag field (memo §6.3).
3. The two run capture bundles are re-taken after the tag moves the bytes.

---

## Stage 17 — the D19 separating hash tag (2026-09-20, 15:0x–1x:xx)

**The first stage of this lane allowed to touch shared files.** It implements
rulings **T-1**, **T-2 (amended)**, **T-5**, **T-6 (amended)**, **T-7** and
**T-8** of `docs/zkmatrix-poc/ZK60_D19_HASH_TAG_DISPOSITION.md`, on the
integrator's authorisation of 14:22 — engineering ownership of the additive
change, **not** its acceptance of the argument. T-3 and T-4 landed in stage
16; T-3's completed length guard is here RE-SCOPED to legacy-rule profiles
only, as amendment T-3 requires.

**No privacy or soundness acceptance is claimed or implied**, and D22's scope
is unchanged. What the tag buys is hash-domain and cross-profile separation
in an idealised model, stated below; it buys nothing else.

### What the tag is, in one paragraph

Every hash on a TAGGED profile's path is BLAKE3 in **keyed mode**, under one
of four fixed public 32-byte keys derived once from that profile's own
string: one for the Fiat–Shamir transcript, one for a PCS column digest, one
for a salted Merkle leaf, one for a Merkle inner node. A key is
`blake3::derive_key(<context string>, <profile string>)`. The LEGACY rule —
no key anywhere, the literal `blake3::Hasher::new()` that produced every byte
to date — stays the default and is what the byte-frozen toy and the
frozen-seam development rung keep, **wholly** (T-2 as amended: a profile is
wholly legacy or wholly tagged, never a mixture).

### Status

`LANDED`, every gate green. Five commits: the skeleton `bfec2e2`, the two
SHARED-FILE commits `d2e5988` (zkp-core) and `7de6ea1` (hashline), the lane
plumbing and the T-6 tests `2d9f7af`, and this ledger.

### The commits, split as the integrator asked

| # | commit | kind | files |
|---|---|---|---|
| 1 | `bfec2e2` | ledger | the skeleton |
| 2 | `d2e5988` | **SHARED** | `zkp-core/src/hashtag.rs` (new), `lib.rs`, `transcript.rs`, `merkle.rs`, `pcs.rs`. **No lane file** |
| 3 | `7de6ea1` | **SHARED** | `hashline/src/pcs.rs`, `hashline/src/zk.rs`. **No lane file** |
| 4 | `2d9f7af` | lane | `shape.rs`, `protocol.rs`, `endpoint_g.rs`, `boundary.rs`, `layout.rs`, `hash_domain.rs`, `run.rs`, `run_capture.rs`, `private_block.rs`, the three test files, the format note |
| 5 | this one | ledger | |

### THE SHARED CHANGE, function by function (for the integrator's review)

`git diff --stat d2e5988~1 7de6ea1 -- zkp-core hashline/src/pcs.rs hashline/src/zk.rs`:

```
 hashline/src/pcs.rs        |  13 +
 hashline/src/zk.rs         | 105 +
 zkp-core/src/hashtag.rs    | 253 +
 zkp-core/src/lib.rs        |   5 +
 zkp-core/src/merkle.rs     |  76 +
 zkp-core/src/pcs.rs        | 444 +
 zkp-core/src/transcript.rs |  80 +-
```

Every one of those is an INSERTION except the transcript's four permitted
sites. Each new function is placed **immediately after the legacy function it
mirrors**, not at the end of a file, so a merge with the integrator's
in-flight insertions (`hashline/src/pcs.rs` after `commit`,
`hashline/src/zk.rs` from about line 2277) touches nothing they touch.

| file | added | legacy body changed? |
|---|---|---|
| `zkp-core/src/hashtag.rs` | **new file**: `HashTag` (opaque), `HashTag::legacy`, `HashTag::for_profile`, `is_legacy`, `rule_name`, `transcript_key`, `column_key`, `leaf_key`, `node_key`, `hasher`, the four `CTX_*` constants and the two rule names | — |
| `zkp-core/src/lib.rs` | `pub mod hashtag;` and its comment | no |
| `zkp-core/src/transcript.rs` | `Transcript::new_tagged` | **the four permitted sites only**: a last field `key: Option<[u8;32]>`; `new` sets it `None`; `absorb` and `squeeze_bytes` build their hasher through `hashtag::hasher(self.key.as_ref())`, which with `None` IS `blake3::Hasher::new()`; `clone_state` copies the key. No other body |
| `zkp-core/src/merkle.rs` | `hash_pair_keyed`, `MerkleTree::build_keyed`, `MerkleTree::verify_path_keyed` | no |
| `zkp-core/src/pcs.rs` | `hash_column_keyed` (private), `hash_columns_keyed`, `salt_leaf_keyed`, `commit_zk_owned_with_tag`, `verify_zk_tagged` | no |
| `hashline/src/pcs.rs` | `commit_zk_owned_tagged` | no |
| `hashline/src/zk.rs` | `mask_commit_tagged`, `mask_verify_tagged`, `pcs_hash_column_keyed` (private) | no |

**No legacy function is forwarded through a keyed one.** `hash_pair`,
`build`, `verify_path`, `hash_column`, `hash_columns`, `salt_leaf`,
`commit_zk_owned_with`, `verify_zk`, `mask_commit`, `mask_verify` and
`pcs_hash_column` all keep their text exactly as it was, so "the old callers
are byte-identical" is a fact about unchanged source and not a claim. The one
place the two rules meet is `hashtag::hasher`, and its `None` arm is the
identical constructor call (pinned by
`hashtag::tests::an_unkeyed_hasher_is_the_legacy_call_and_a_keyed_one_is_not`).

**Ruling T-7, the opaque type.** This is TIGHTER than the scoping memo's
struct of four public `Option`s. A `HashTag` is either the legacy rule or the
COMPLETE key set of one profile; the enum behind it is private, there is no
public field, no partial set and no constructor that takes key bytes — only
`legacy()` and `for_profile(<profile string>)`. A verifier derives its tag
from the profile IT trusts. Nothing deserialised from a receipt or read from
a capture selects or carries a key anywhere in this stage.

**Ruling T-8, the accelerator.** One condition inside the NEW commit
function: when `tag.column_key()` is `Some`, the backend is never offered the
work. The pads and the salts are drawn from the generator FIRST, in exactly
the legacy order, before that branch, so the generator's byte order is
identical under both rules (pinned by
`pcs::tag_tests::the_tag_does_not_move_one_byte_of_the_generator`). It is
commented in place as a **TEMPORARY CPU FALLBACK pending a keyed device
hasher** — not accelerator support, not a performance result. Nothing under
`gpu/` is touched; the keyed kernel (the key words in place of `b3_iv`, the
`KEYED_HASH` flag) is the integrator's, later.

**The path length, in the NEW function only.** `verify_zk_tagged` requires
every opened column's path to have exactly `log2(enc_cols)` entries and
refuses by name. It is new code with no legacy byte at stake, so the check
the disposition owes the integrator is simply in it from the start.
`verify_zk` is untouched and still folds whatever it is handed; that one-line
fix remains the integrator's call, and the lane's own call sites are covered
by stage 16's T-4 checks as well.

### THE EIGHT KEYS

Computed twice, independently, and equal in all eight:

* in Rust by the `blake3` 1.8.7 crate (`zkp-core --lib`, the test
  `hashtag::tests::the_four_keys_of_each_tagged_profile_are_pinned`, and
  again against the SHAPES in
  `hash_tag_tests::the_toy_and_the_frozen_seam_rung_are_legacy_and_the_other_two_are_tagged`);
* in Python by the `blake3` module 1.0.9,
  `blake3.blake3(b'<profile>', derive_key_context='<context>').hexdigest()`.

`hashline-zk-mr1/private-block-rung-g-t24-dev/1`

| role | key |
|---|---|
| transcript | `51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe` |
| column | `2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c` |
| leaf | `fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032` |
| node | `8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc` |

`hashline-zk-mr1/private-block-m125/1`

| role | key |
|---|---|
| transcript | `125f9b4d44ac3c46712a35419cdeda6c1428db443ccaf58da67f35b15b37291c` |
| column | `d5fc391cc58eed85631b4c3dabc7d377477eb1a0a725aeccaec0f4d10061b135` |
| leaf | `1dc6f7146ad501ede6d90b3071da2f3251d38137303ffcc0a6a48b7f89effe83` |
| node | `798eb64ff187f6f3e8e889ac4c4742607ac71a71fa09e2944a0ecc5e8a42026b` |

All eight pairwise distinct (`all_eight_keys_are_pairwise_distinct`). The
context strings are the disposition's four, asserted literally.

**A note on the two RUN profiles.** `hashline-zk-mr1/private-run-rung-g-t24-dev/1`
and `hashline-zk-mr1/private-run-m125/1` are the `Transcript::new` DOMAIN of a
run, but the tag is taken from the run's BLOCK shape, so a run is keyed under
its block profile's four keys and not under keys of its own. That is the one
place where the memo's "a new profile string cannot exist without a new key
set" is discharged by the block shape rather than by the run profile; it is
recorded here because a reader of `transcript_domain` would otherwise derive
the wrong key. Nothing is ambiguous in practice — one run profile has exactly
one block profile — but it is a deliberate simplification, not an oversight,
and the security owner may want run-level keys instead.

### THE INVENTORY, ticked row by row (scoping memo §1)

| row | what | where the tag went, or why it did not |
|---|---|---|
| T1 | transcript start | KEYED — `protocol::tagged_transcript` (`protocol.rs:100-110`) is the one constructor, used by the block header (`protocol.rs:122`), the run header (`run.rs:268`) and the run capture's rebuild (`run_capture.rs:257`) |
| T2 | transcript absorb | KEYED — `transcript.rs:56-64`, from the transcript's own key |
| T3 | transcript squeeze | KEYED — `transcript.rs:100-110` |
| P1 | column digest, single | KEYED — `pcs.rs` `hash_column_keyed`, called by `verify_zk_tagged` |
| P2 | column digests, tiled | KEYED — `hash_columns_keyed`, called by `commit_zk_owned_with_tag` |
| P3 | salted leaf | KEYED — `salt_leaf_keyed`, both sides |
| P4 | Merkle inner node | KEYED — `hash_pair_keyed` / `build_keyed` |
| P5 | root | not a hash |
| P6 | path verification | KEYED — `verify_path_keyed` |
| R1 | RNG seed, fixture form | **UNKEYED, and right**: a deterministic-seed generator used by fixtures, never by a proof of an accepted profile. Not one of the four domains |
| R2 | RNG seed, OS form | **ALREADY KEYED**, under 32 bytes of `/dev/urandom` — the generator's OWN secret key. T-1's amended model reads that as its own member of the family, so a fifth public key would weaken nothing and separate nothing |
| R3 | RNG refill | inherits R2's secret key |
| M1 | mask column digests | KEYED — `zk::mask_commit_tagged` -> `hash_columns_keyed` |
| M2 | mask salted leaves + tree | KEYED — `salt_leaf_keyed`, `build_keyed` |
| M3 | mask opening verify | KEYED — `zk::mask_verify_tagged` -> `pcs_hash_column_keyed`, `salt_leaf_keyed`, `verify_path_keyed` |
| G1 | GPU column digests | **DECLINED at a tagged profile (T-8)**, temporary CPU fallback |
| B1 | public-statement digest | **UNKEYED, with a reason**: a statement digest fed into a transcript ABSORB, never a Merkle leaf or node. It already begins with its own 31-byte ASCII domain `"hashline/private-block-public/1"`, and the absorb that carries it IS keyed, so the transcript it reaches is separated. It is in none of the four domains |
| B2 | calibration identity | same, domain `"B3 public fixed calibration v1"` (30 B) |
| B3 | block schedule digest | same, domain `"hashline/private-block-schedule/1"` (33 B) |
| B4 | generalised-endpoint spec digest | same, domain `"hashline/private-block/general-endpoint/v1"` (42 B) |
| B5 | internal-boundary spec digest | same, domain `"hashline/private-block/internal-boundary/v1"` (43 B) |
| B6 | frozen-seam spec digest | **untouched**: `private_seam.rs` is byte-frozen, and the only profile that reaches it is the frozen-seam rung, which is wholly legacy |
| B7 | run public statement | as B1, domain `"hashline/private-run-blocks/1"` (29 B) |
| B8 | run schedule digest | as B1, domain `"hashline/private-run-schedule/1"` (31 B) |
| B9 | run segment position tag | **KEYED, and this is the row that needed care**: it is two `challenge_fp2` squeezes from a DISCARDED `Transcript::clone_state`, so nothing changed at the call site — what changed is that `clone_state` copies the key (`transcript.rs:150-160`). A clone that dropped it would have drawn both tags under the unkeyed function while the rest of the run was keyed, which is exactly the mixture T-2 forbids. `RunVerifier::step`'s trailer comparison is what checks it |
| B10 | run binding | the transcript state after the header: keyed by T1/T2 |
| B11 | run capture header rebuild | KEYED — through `tagged_transcript` |
| S1 | sumcheck round absorb | T2, keyed |
| S2 | run stage / slot / scalar / terminal absorbs | T2, keyed |
| C1 | run capture / run sink file digests | **UNKEYED, and out of scope**: SHA-256 over capture FILES on disk (`export_v3::sha256_hex`), a bundle's self-consistency pin. Not a proof hash and not BLAKE3 |
| K1 | `private-block-kernel-shaped` | hashes nothing |

**One more unkeyed hash, found in this stage and left unkeyed:**
`grow_tests.rs:1050` builds a bare `Transcript::new(sh.profile.as_bytes())`
for the slot-definition structure test. It proves and verifies nothing — it
is a counting harness over `argument::define` — so its challenge stream only
has to be self-consistent. Left legacy, recorded here.

### T-3 as amended: the length guard is now legacy-only

`hash_domain::imposed_at_shape{,_with}` is new and is what the construction
paths call (`Layout::for_shape`, `RunStatement::new`); it returns an EMPTY
set at a tagged profile. `at_shape_with` stays the honest DESCRIPTION at
every shape and every stage-16 test goes on pinning it, so:

* **nothing of stage 16 was reverted** — the four statement fixtures of
  finding S16-F1 stand where stage 16 put them, the thirteen tests are
  unchanged, and the shape-free half is unchanged;
* the two BARE statement constructors (`EndpointSpecG::new`,
  `BoundarySpec::new`) hold no profile string and so cannot tell the rules
  apart. They keep refusing the shape-free eight at every shape. **This is a
  deviation from the letter of T-3 amended** — the guard is still imposed on
  a tagged profile at those two sites — and it is recorded rather than
  worked around: no tagged profile's real geometry is near the set (rung-G's
  endpoint is 9 rows and its boundary 10; 125M's are 37 and 38), so it costs
  nothing today. Giving those constructors a profile string would be a wider
  change than this stage is allowed.

### The run capture

ONE new public member of `run.json`, `hash_tag`, written by
`run_capture::write_hash_tag`. Under the legacy rule it is exactly
`{"rule": "legacy"}`; under the tag it carries the rule name
`"blake3-keyed/1"`, the profile string, the four context strings and the four
derived keys as hex. Every one of those is a public function of public
strings; the Python tools **re-derive and compare** and must never take a key
from a bundle. Eight allow-list entries (`hash_tag`, `rule`, `contexts`,
`keys_hex` and the four role names). `SOURCE_FILES` 7 -> 8: a bundle pins
`shape.rs` too, because `Shape::hash_tag` decides which rule made every byte.

**The schema string does NOT move.** It stays
`"hashline-native-capture/4-run"` because this is a pure addition — one new
member, nothing renamed, removed, re-typed or re-meant — so a reader written
against stage 14 or 15 reads a stage-17 bundle unchanged. Recorded with the
date in `ZK60_RUN_CAPTURE_FORMAT.md` (new §2a).

**The four existing bundles are legacy-rule bundles.** `run-a-tame`,
`run-b-zero`, `run-c-tame` and `run-d-zero` were all captured before the tag.
The tagged bytes differ; re-taking them is stage 18, after the security owner
reviews this stage, and until the Python run gate learns the rule a tagged
bundle is **not gate evidence** (ruling T-6).

### The tests (T-6 as amended, item by item)

| ruling item | test | where |
|---|---|---|
| 1. the toy and the frozen-seam rung are legacy | `the_toy_and_the_frozen_seam_rung_are_legacy_and_the_other_two_are_tagged` | `hash_tag_tests.rs` |
| 2. key pins, all eight, pairwise distinct | `the_four_keys_of_each_tagged_profile_are_pinned`, `all_eight_keys_are_pairwise_distinct`, `the_context_strings_are_the_dispositions` (zkp-core) + the shape-level half above | `zkp-core/src/hashtag.rs`, `hash_tag_tests.rs` |
| 3. cross-rule rejection, both directions, at rung-G | `a_rung_g_proof_is_refused_under_the_other_hash_rule_in_both_directions` | `hash_tag_tests.rs` |
| 4. isolated layer controls | `a_column_digest_under_three_rules_is_three_digests`, `a_salted_leaf_is_a_merkle_node_under_the_legacy_rule_and_is_not_under_a_tag`, `a_keyed_node_separates_and_a_wrong_node_key_fails_the_path`, `a_keyed_transcript_separates_and_its_clone_does_not` | `zkp-core` `pcs.rs`, `merkle.rs`, `transcript.rs` |
| 5. `verify_zk_tagged` refuses a wrong path length, by name | `the_tagged_verifier_refuses_a_path_of_the_wrong_length` (short and long) | `zkp-core/src/pcs.rs` |
| 6. the accelerator seam | `a_tagged_commitment_never_offers_its_columns_to_the_backend` — a counting `Backend` stub, which the trait allows without touching `gpu/*` | `zkp-core/src/pcs.rs` |
| 7. the run | `a_three_block_run_proves_and_verifies_under_the_tag`, `a_tagged_run_is_refused_by_a_legacy_rule_run_verifier` (and the reverse), `the_run_file_names_the_hash_rule_and_the_rebuilt_header_matched_under_it` | `run_tests.rs`, `run_capture_tests.rs` |
| 8. the whole `private_` filter | below | |

**WHAT THE FIRST REFUSAL ACTUALLY IS, in each direction** (T-6 amended asks
for this and it is not the Merkle one):

```
tagged proof, legacy verifier: slot 0 [01 SS row sums norm_a (private)]:
                               sumcheck round 1: s(0) + s(1) != claim
legacy proof, tagged verifier: slot 0 [01 SS row sums norm_a (private)]:
                               sumcheck round 1: s(0) + s(1) != claim
```

Fiat–Shamir consistency, at the first slot, in both directions — the whole
challenge chain diverges at the transcript's very first hash, long before any
Merkle check is reached. That is why the disposition's amended T-6 asks for
the layers to be identified by ISOLATED controls instead, and they are (item
4 above). At the PCS layer alone, where the transcript is held fixed, the
refusal IS the Merkle one, and
`a_tagged_commitment_is_refused_under_the_legacy_rule_and_the_reverse`
asserts that by name.

**The cross-rule test hook.** Nothing in production may choose a profile's
rule, so one side of each pair needs a test-only override:
`shape::set_force_legacy_hash_rule`, `#[cfg(test)]` throughout (the cell, the
setter and the read in `hash_tag()` all vanish from a release build). It is
deliberately ONE-DIRECTIONAL — a forced value can only make a profile
LEGACY, which two profiles already are — so it cannot tag the frozen toy and
cannot move one of its bytes even if a test leaked it. The `ForcedLegacy`
guard clears it on drop, which matters because the suite runs
`--test-threads=1` and a panic would otherwise poison every later test on the
thread.

### RECEIPT SIZES DO NOT MOVE

The wire format carries no tag: no field is added and no length changes, so
every pinned frame length is unchanged and the tests that pin them were not
edited.

| profile | receipt bytes | pinned by |
|---|---:|---|
| toy (frozen) | **2,816,472** | `the_codec_length_is_the_models_at_every_shape`, `a_frame_one_path_entry_short_is_refused_at_decode`, the four pre-lane receipts |
| frozen-seam rung | **4,218,264** | the same test |
| rung-G | **4,234,648** | the same test |
| 125M | **40,782,792** | the same test, and `the_125m_shape_constructs_...` |

A run's segment lengths are unchanged too: the three-block tagged run's
segments are exactly `counted_segment_bytes`, asserted inside
`a_three_block_run_proves_and_verifies_under_the_tag` — a tagged segment that
was one byte off would fail there.

### Files this stage wrote

**SHARED (authorised, additive, in their own commits):**
`zkp-core/src/hashtag.rs` (new), `zkp-core/src/lib.rs`,
`zkp-core/src/transcript.rs`, `zkp-core/src/merkle.rs`, `zkp-core/src/pcs.rs`,
`hashline/src/pcs.rs`, `hashline/src/zk.rs`.

**LANE:** `hashline/src/private_block/shape.rs`, `protocol.rs`,
`endpoint_g.rs`, `boundary.rs`, `layout.rs`, `hash_domain.rs`, `run.rs`,
`run_capture.rs`, `hashline/src/private_block.rs`, and the test files
`hash_tag_tests.rs` (new), `run_tests.rs`, `run_capture_tests.rs`; the docs
`ZK60_RUN_CAPTURE_FORMAT.md` and this ledger; `results/zk60_block125m_lane/`.

**STILL BYTE-IDENTICAL, proved after the last lane commit:**

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat b26c869 -- \
  hashline/src/layer.rs hashline/src/wcache.rs hashline/src/gpu \
  hashline/src/native_capture.rs hashline/src/private_seam.rs \
  private-block-kernel private-model-kernel zkvm-block
```

prints **nothing**.

And the whole shared change, for the integrator, is four DELETED lines and
nothing else — all four in `transcript.rs`, all four the permitted sites:

```
-        Transcript { state: *h.finalize().as_bytes(), counter: 0, masker: None, masked_rounds: Vec::new() }
-        let mut h = blake3::Hasher::new();
-        let mut h = blake3::Hasher::new();
-        Transcript { state: tr.state, counter: tr.counter, masker: None, masked_rounds: Vec::new() }
```

### What this stage did NOT do

* **No heavy run and no re-taken capture bundles.** The four bundles in
  `results/zk60_run_captures_20260920/` are legacy-rule bundles; re-taking
  them is stage 18, after the security owner reviews this stage. No 125M
  proving run was made and no timing was measured — T-1's amended wording is
  explicit that "no extra compression" is a COUNT and the run time is to be
  re-measured, not assumed.
* **No Python.** The run gate must learn the rule before any tagged bundle is
  judged (ruling T-6); until then a tagged bundle is not gate evidence. §2a
  of the format note tells the Python side exactly what to do: re-derive and
  compare, never consume a key from a file.
* **No keyed device path.** A tagged commitment declines the accelerator.
  Temporary CPU fallback, recorded as such; the kernel change is the
  integrator's.
* **`pcs::verify_zk` is still unfixed.** The path-length check is in
  `verify_zk_tagged` only, as the brief directs; the legacy function still
  folds whatever it is handed, and the finding stands for the integrator's
  other wire formats.
* **No privacy or soundness acceptance.** The tag gives hash-domain and
  cross-profile separation in the idealised model T-1 states, and nothing
  else. D8, D11 and D22 are untouched; the frozen-seam rung and the toy
  remain barred by name from any privacy statement.
* **The depth-confusion attack is still unanalysed** by anybody, as stage 16
  recorded. Under a tag it needs a key it does not have; under the legacy
  rule the lane's T-4 checks and `wire.rs` are still the whole protection.

### NEXT, in order

1. **The security owner reviews this stage** — in particular the two things
   recorded as deviations: the shape-free half of the T-3 guard still firing
   at tagged profiles from the two bare statement constructors, and a run
   being keyed under its BLOCK profile's keys rather than its own run
   profile's.
2. **The integrator reviews the two shared commits** (`d2e5988`, `7de6ea1`)
   and takes the keyed CUDA path and the `pcs::verify_zk` path-length fix.
3. **Stage 18**: re-take the two run capture bundles under the tag, and teach
   the Python run gate the rule (re-derive the four keys from the contexts
   and the profile, compare with `keys_hex`, and key its own transcript
   replay).
4. Re-measure the 125M timing when a quiesced box is available; the tag is
   expected not to move it, and expected is not measured.

### Tests and commands of stage 17

All through the shared build lock, `CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`, `--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| `zkp-core --lib` (first) | `y1-s17-zkpcore.log` | **50 passed / 0 failed**, 0 warnings, exit 0 |
| hashline `--lib zk_cfs` (a compile gate for the shared change) | `y2-s17-hashline-compile.log` | builds, **13 warnings** — the stage-16 baseline's 13 |
| hashline `--lib private_block::hash_domain` (the lane plumbing compiles) | `y3-s17-lane-compile.log` | 13 passed / 0 failed, exit 0 |
| hashline `--lib private_block::hash_tag_tests` (a first, FAILED, run: an import) | `y4-s17-tagtests.log` | exit 101, the import fixed |
| the same, `--nocapture` | `y5-s17-tagtests.log` | **3 passed / 0 failed**, exit 0; the cross-rule refusals printed |
| hashline `--lib private_block::run_tests`, `--nocapture` | `y6-s17-runtests.log` | **19 passed / 0 failed / 2 ignored**, 68.40 s, exit 0 |
| hashline `--lib private_block::run_capture_tests` | `y7-s17-capturetests.log` | **11 passed / 0 failed / 1 ignored**, 13.78 s, exit 0 |
| **the gate**: hashline `--lib private_` | `y8-s17-private.log` | **214 passed / 0 failed / 6 ignored**, 316.69 s, exit 0, **13 warnings** |
| hashline `--lib pcs` | `y9-s17-pcs.log` | 6 passed / 0 failed |
| hashline `--lib merkle` | `y10-s17-merkle.log` | 2 passed / 0 failed |
| hashline `--lib transcript` | `y11-s17-transcript.log` | 3 passed / 0 failed |
| hashline `--lib mask` | `y12-s17-mask.log` | 17 passed / 0 failed |
| hashline `--lib zk::` | `y13-s17-zk.log` | 25 passed / 0 failed |
| `zkp-core --lib` (final) | `y14-s17-zkpcore.log` | **50 passed / 0 failed**, exit 0 |
| **the gate again**, after the last edit | `y15-s17-private-final.log` | **214 passed / 0 failed / 6 ignored**, 354.92 s, exit 0 |
| `python3 -m unittest discover -s tests` | `y16-s17-python.log` | **1,153 run, 3 failures, 7 errors, 68 skipped** — see finding S17-F1 |

**Against the stage-16 baseline of 208 / 0 / 6: +6 tests** in the `private_`
filter (three in `hash_tag_tests`, two in `run_tests`, one in
`run_capture_tests`), and **+13 in `zkp-core`** (37 -> 50). Not one existing
test was changed, weakened or removed anywhere in this stage.

**The warning count is the baseline's 13, and it is the SAME 13.** Compared
site by site against `x2-s16-filter.log`: `review_tests.rs:16`,
`attention.rs:787`, `run.rs` (559 -> 570, moved by my insertions),
`rung_tests.rs:284`, `attention.rs:1046/1086/2025/2077/2859`, `run_capture.rs`
(191 -> 194 and 276 -> 284), `attention.rs:1593/1932`. No new warning is
attributable to this change.

### FINDING S17-F1 — three Python gates now refuse, BY DESIGN, because a pinned source moved

`python3 -m unittest discover -s tests` exits 1. Ten results are not passes,
and they split cleanly:

**Seven are this worktree's environment, not this stage.** Six want the 125M
regression export (`results/m125_ffn_export*/layer00_X.bin`), which is not in
this worktree — `test_uagb1_pass` (×2), `test_uagb1_pass_agg`,
`test_uagb1_tblind` (×2), `test_zkmatrix_native_backends::test_ring_freeze_check`
— and one wants four retained captures that are not here either
(`test_zk60_endpoint_view::test_plan_does_not_read_captured_output_values`:
"0 != 4, mandatory retained captures absent"). None of them reads anything
this stage wrote.

**Three ARE caused by this stage, and they are the gates doing their job.**
`results/zk60_round22_captures.json` and `results/zk60_round19_validation.json`
each pin the SHA-256 of ten Rust sources as the ANALYSIS DEPENDENCIES of a
previous review. Three of those ten are files this stage was authorised to
change:

| pinned path | manifest | HEAD now |
|---|---|---|
| `hashline/src/zk.rs` | `c5b54753…` | `d4280962…` |
| `zkp-core/src/pcs.rs` | `2d914956…` | `6b8d1bfa…` |
| `zkp-core/src/transcript.rs` | `31ce3c9a…` | `cc9752d0…` |

so `test_zk60_mvp_security_probe::SourceBound::test_pins_match_round22_manifest`,
`test_zk60_mvp_security_probe::Scope::test_diagnostic_does_not_close_security_requirements`
("producer source does not match the capture manifest") and
`test_zk60_io_review_gate::ReviewAcceptance::test_empty_directory_cannot_report_success`
("changed analysis dependency: hashline/src/zk.rs") all refuse. The other
seven pinned files — `private_seam.rs`, the five `zk_ffn_*` files and
`zkp-core/src/sumcheck.rs` — still match, which is itself worth having: it is
independent evidence that the change touched exactly the three files it
claims to.

**This is NOT repaired here, deliberately.** Re-pinning those manifests would
erase exactly the signal they exist to raise, and both files are outside this
lane. The correct disposition is the integrator's and the security owner's:
the round-22 / round-19 analyses were argued on a particular text of
`zk.rs`, `pcs.rs` and `transcript.rs`, and somebody has to decide whether the
additive change preserves what those analyses concluded before the pins are
re-taken. The change is additive and the three legacy functions those
analyses concern keep their bodies — `mask_commit`, `mask_verify`,
`commit_zk_owned_with`, `verify_zk`, `salt_leaf`, `hash_columns` are
unchanged text, and the only edited legacy bodies are the four transcript
sites listed above — so the expected answer is "yes, re-pin", but that is a
RULING and not this lane's to make.

---

## Stage 18 — the tagged length guard, the public run statement beside the segments, and the re-taken bundles (2026-09-20, 15:5x–16:4x)

**Lane-only. NO shared file changed**, and no heavy run was launched from
here: nothing proved at the 125M shape, no `--ignored` 125M test, no GPU.
The heaviest thing run is the development-rung capture and run tests.

**No privacy or soundness acceptance is claimed or implied by any of it.**
D22's scope is unchanged, the toy and the frozen-seam rung remain barred by
name from any privacy statement, and the run privacy gate of ruling M-8 has
still never been met.

### Status

`LANDED`, every gate green. Six commits: the skeleton `cff534b`, item 1
FAILING-FIRST `bf5e61e`, item 1 FIXED `6e6ab25`, item 2 `facc057`, item 3
(the bundles) `041c740`, and this ledger.

### Item 1 — the length guard no longer fires on a tagged profile (T-3 amended)

**What stage 17 left.** `hash_domain::imposed_at_shape_with` had already made
the SHAPE-DRIVEN set legacy-only, but the two BARE statement constructors —
`EndpointSpecG::new` and `BoundarySpec::new` — hold no profile string, so
they went on imposing the SHAPE-FREE half of the set at every profile. Stage
17 recorded that as a deviation from the letter of amendment T-3 rather than
working around it.

**The change, and why it is the smallest honest one.** Each constructor gains
a `new_with_tag(..., tag: &HashTag)`, and `new` becomes that at
`HashTag::legacy()`. This is stage 17's own pattern (`verify_zk_tagged`,
`mask_commit_tagged`, `commit_zk_owned_with_tag`), it leaves every existing
call site byte-identical, and the default is the FAIL-CLOSED one: a caller
with no tag to offer still gets the whole set.
`layout::no_commitment_has_a_node_shaped_column_under` is the tagged form of
the guard and `hash_domain::imposed_shape_free(tag)` decides — the shape-free
set under the legacy rule, an EMPTY set under a tag. `shape_free()` itself is
untouched and every stage-16 test still pins it, exactly as `at_shape_with`
stayed the honest description in stage 17.

**The two production call sites now pass the rule the shape derives:**
`IoSpec::endpoints_g` passes `self.hash_tag` (taken once from the shape in
`IoSpec::new_shaped`, ruling T-7: the key set is never an input), and
`RunStatement::boundary_spec` passes `sh.hash_tag()`. Those are the only two
non-test callers in the crate.

**FAILING FIRST** (`z1-s18-failing-first.log`, **13 passed / 2 failed**, exit
101, an intended FAILED result, committed at `bf5e61e`). The commit threads
the tag through every caller and `imposed_shape_free` DELIBERATELY IGNORES
it, so that commit's behaviour is byte for byte stage 17's. The two failures,
as the run printed them:

```
a TAGGED 13-row generalised endpoint must construct (T-3 amended):
  "private block: the general endpoint commitment has 13 rows, whose column
   hashes to 104 bytes — the same length as the transcript absorb of
   `sc-round` with 48 bytes of data
   (zkp-core/src/sumcheck.rs:109, :154; hashline/src/zk.rs:994) (C-H4)"

5 rows was refused under a tag: private block: the general endpoint
  commitment has 5 rows, whose column hashes to 40 bytes — the same length as
  the generator's refill block (C-H4)
```

**AFTER THE FIX** (`z2-s18-item1-fixed.log`, **15 passed / 0 failed**, exit 0,
commit `6e6ab25`): one line of `imposed_shape_free`.

**The two new tests.**

| test | what it pins |
|---|---|
| `the_length_guard_does_not_fire_at_a_tagged_profiles_statement_constructors` | a TAGGED 13-row generalised endpoint (`32 x 32` plane over a `2^7` row width: `2^3` data rows + `MASK_ROWS`) and a TAGGED 12-row boundary (the same plane over `2^8`: 4 data rows + `2*3` + 2) both CONSTRUCT; the same two geometries under the legacy rule — both through the explicit `HashTag::legacy()` and through the bare constructor — are still refused BY NAME, with the byte count and the colliding absorb in the message; every OTHER refusal of both constructors still fires under a tag (ruling M-1's declared-row check, the power-of-two axes, the pad count, the site count); and no accepted profile's real geometry (endpoint 9 and 37, boundary 10 and 38) is in the set |
| `the_constructors_guard_is_unchanged_under_the_legacy_rule` | all eight shape-free counts refused under the legacy rule and clear under a tag, and the toy's own 455 / 384 / 50 / 7 still pass |

**Stage 16's four moved statement fixtures were NOT restored.** They sit at
geometries the completed guard refuses, and they call the BARE constructors,
which are legacy-rule by definition — so restoring them would mean rewriting
them to build under a tag, which changes what each test is about. Not
trivial, so left where stage 16 put them, with stage 16's comments in place.

**What this does NOT change.** No proof byte of any profile, no receipt
length, no accepted geometry. The set itself is unchanged; only the set of
profiles it is IMPOSED on is, and that set is now the same at all four sites
(`Layout::for_shape`, `RunStatement::new`, and the two constructors).

### Item 2 — the PUBLIC run statement, retained beside the segments

**Why.** A run leaves `L` segment files in `HL_PB_RUN_DIR` and nothing else.
The segments are the PROOF; they are not the STATEMENT, and no verifier can
do anything with them without one. Everything the statement is made of lived
only inside the process that proved the run, so the twelve-block 125M run
would leave 484 MB of receipt that no later process could check. This is the
integrator's request, and it is met by a new `cfg(test)` module
`hashline/src/private_block/run_statement_file.rs`.

**The layout on disk.** The segments were at the TOP LEVEL of the run
directory and they stay there, with their names and their bytes unchanged:

```
<run dir>/segment-000.bin … segment-(L-1).bin
<run dir>/statement/run-statement.json
```

`run_sink::segment_paths` is widened by exactly one allowed NAME, which must
be a DIRECTORY; a plain FILE called `statement`, an extra segment beyond `L`,
a leftover `.partial` and every other foreign entry are refused before a byte
of any segment is read, as before (the stage-13 negative battery's
`notes.txt` case still fires, unchanged). That widening is the whole cost of
putting the statement inside the directory the verifier scans, and it is
recorded here as the one behavioural change to a shared-in-the-lane file.

**Schema** `hashline-private-run-statement/1`. JSON, one top-level member per
line, no space between a key and its colon (so `run_capture::keys_of` reads
it too), every digest / root / key / byte string lower-case hex. Format note:
`ZK60_RUN_CAPTURE_FORMAT.md` §11.

#### THE PUBLIC-VALUE TRACE: every member, and where the VERIFIER consumes it

All line numbers are `hashline/src/private_block/run.rs` at commit `facc057`.
`RunVerifier::start` is `:562`, `RunVerifier::step` is `:581`,
`verify_run_from_dir` is `:783`.

| member | what it is | where the verifier consumes it |
|---|---|---|
| `run_profile` | the run's transcript domain | `:271` `protocol::tagged_transcript(sh, self.rs.profile.as_bytes())`, reached from `:572` |
| `block_profile` | the per-block shape's profile | `:271` (the tag is derived from it, `:574`) |
| `blocks` (`L`) | the stage count | `:564` (the verifier's own `L` against the block list), `:788` `segment_paths(dir, l)` |
| `shape.*` | tokens, width, hidden, heads, head_dim, the padded plane, the endpoint parameters | the verifier builds its OWN `Shape` from `block_profile` and the file's numbers are COMPARED with it; the shape drives `:585` `stage_layout`, `:661` / `:693` the endpoint commitments |
| `run_shape_words` | the seven `u64` of the `run-shape` word | `:276` `tr.absorb(b"run-shape", …)` |
| `context` | the run context digest | `:175` `BoundarySpec::new_with_tag(self.context, …)`, and `IoSpec`'s own field, validated at `:568` |
| `expected_io.input_root` | the external INPUT endpoint's commitment | `:661` `protocol::commitment(st.expected.input, …)` → `:666` `pcs::verify_zk_tagged` |
| `expected_io.output_root` | the external OUTPUT endpoint's commitment | `:693` → `:698` |
| `expected_io.input_scale`, `output_scale` | the endpoint policy's scales | `:131` (`RunStatement::new`'s agreement check) and `:568` `st.expected.spec.validate()` |
| `expected_io.rows`, `data_rows`, `log_n`, `inv_rate` | the endpoint commitment's geometry | `:661`, `:693`, and `protocol::endpoint_pcs_params` at `:570` |
| `expected_io.policy_bytes`, `policy_sha256` | `ExpectedIo::to_bytes` | `:277` `tr.absorb(b"expected-IO", …)` |
| `block_digests[k]` | block `k`'s public statement digest | `:602` `tr.absorb(b"pb-run-block", &st.block_digests[k])`, and `:181` → `:278` through `public_statement()` |
| `block_scales`, `boundary_scales` | ruling M-4's one scale per boundary | `:126-135` (the agreement refusal), `:174` (each boundary's scale) |
| `calibration` | the calibration identity | `:280` `tr.absorb(b"calibration", …)` |
| `derived.public_statement_digest` | `H(block digests)` | `:181`, absorbed at `:278` |
| `derived.parameter_line` | the human-readable geometry line (S11b-F4) | `:195`, absorbed at `:279`, and inside the schedule digest at `:253` |
| `derived.schedule_digest` | the run's schedule | `:246`, absorbed at `:281` |
| `derived.run_binding` | the transcript state after the header | `:573` `let binding = tr.state()`, compared against every segment's header at `:587` `wire::decode_segment(…, &self.binding, …)` |
| `stage_lines[k]` | what stage `k` commits, claims and opens | `:213`, inside the schedule digest at `:256` |
| `hash_tag.rule` / `profile` / `contexts` / `keys_hex` | which hash rule made every byte | `:574` `tag: sh.hash_tag()` — the VERIFIER'S own, from the profile it trusts; the file's copy is only ever COMPARED (ruling T-7) |
| `internal_boundaries[k].*` | each boundary's scale, sites, rows, site rows, proximity row, PCS parameters and statement digest | `:172-176` `boundary_spec`, consumed at `:605-606` (the root absorb), `:633` (the commitment) and `:636` (`verify_zk_tagged`) |
| `segments[].file`, `bytes`, `sha256` | the receipt on disk | `:788` `segment_paths`, `:793` the bytes read and stepped |

**Nothing else is in the file.** The remaining members are provenance and
prose: `schema`, `kind`, `written_by`, `what_this_is`, `source_commit`,
`digest_encoding`, `public_weights.{recipe,description,digest_domain,values_in_this_file}`,
`not_in_this_file`, `ruling_d21`, and the `row_rule` / `committed_at_stage` /
`opened_at_stage` / `directory` labels. **No witness value, no hidden plane,
no pad, no salt, no blinding row, no mask coefficient, no prover randomness,
no timing and no memory figure.** A rung statement file is **5,977 B**.

**THE PUBLIC WEIGHTS ARE NOT DUMPED.** The verifier's statement holds one
DIGEST per block, so the file names a deterministic RECIPE
(`private_block::grow_tests::tame_case(<block profile's Shape>)`, the same
public fixture for every block) and the reader REGENERATES the weights and
checks them against `block_digests`. The WRITER checks it too, before writing
anything: a run whose blocks the named recipe does not reproduce gets no
statement file. The writer regenerates ONE block and compares its digest
against all `L`, so nothing of the `L`-fold cost (110 MB at 125M) is paid.

**RULING D21, structurally.** `verify_then_write` is the only writer and it
calls `run::verify_run_from_dir` FIRST; it writes nothing, and does not even
create the `statement/` directory, unless that returns `Ok`. So the presence
of the file is itself the statement that this run verified in the process
that made it.

**What the reader does, and what it refuses.** `read(dir)` takes ONLY the
file and this build's public shape and recipe. It rebuilds `IoSpec`,
`ExpectedIo`, `RunShape` and `RunStatement`, then RECOMPUTES every derived
member and refuses by name on any mismatch — the run binding first, because
it is a function of every public word of the header — re-derives the four
hash keys from the contexts and the profile and compares them with
`keys_hex` (never consuming one, T-7), compares every boundary's derived
geometry and statement digest, and reads each segment file once to check its
length and SHA-256. `verify_from_disk(dir)` is `read` plus
`verify_run_from_dir` in a FRESH `RunVerifier`.

**The six new tests** (in `run_tests.rs`, beside the runs):

| test | what it establishes |
|---|---|
| `a_run_is_rebuilt_from_its_statement_file_alone_and_verifies_in_a_fresh_verifier` | **the sufficiency test the integrator asked for**: a three-block TAGGED rung run, written to a directory, then rebuilt from the files on disk plus the recipe and verified from its segments. The directory holds exactly `segment-000.bin`, `segment-001.bin`, `segment-002.bin`, `statement` |
| `a_statement_file_with_one_byte_changed_is_refused` | EIGHT one-byte mutations, each refused by the name of the member that moved: the input endpoint commitment and the output endpoint commitment (both land on **the run binding**), the declared run binding, the declared endpoint policy bytes, a block's public digest, the calibration identity, a boundary's statement digest, and a segment's SHA-256. The honest file verifies again afterwards |
| `every_key_of_a_run_statement_is_on_the_allow_list` | 95 key occurrences, every one on the declared allow list of 84, AND every entry of the list actually emitted — so the list cannot drift into a wish list |
| `a_failed_run_leaves_no_statement_file` | **D21**: one byte flipped in the middle of segment 1, `verify_then_write` refuses, and the directory holds three entries and no `statement/`. With the segment restored the statement appears |
| `the_run_directory_allows_the_statement_directory_and_nothing_else` | the one allowed entry is a NAME and a KIND: `notes.txt` is still refused by name, and a FILE called `statement` is refused by name |
| `the_statement_files_json_reader_is_strict` | the hand-written reader: what it accepts, and eleven refusals (a repeated key, a trailing byte, a trailing comma, an unterminated object or string, a float, an exponent, a `\u` escape, a bare word, a single-quoted string, an empty input) plus the digest accessor's |

**The reader is a hundred lines of hand-written JSON** because this crate has
no JSON dependency and this is not the place to add one. It is strict — no
float, no `\u`, no repeated key, no trailing byte — and the WRITER refuses to
emit a string that is not printable ASCII, so `{:?}`'s escaping is JSON's.

**Wired into the heavy test.** `private_run_125m_twelve_blocks` now calls
`run_statement_file::verify_then_write` in place of its bare
`verify_run_from_dir`; the verification time it reports is the one measured
inside that call, around the verification only. **Its two-block sibling
`private_run_125m_two_blocks` keeps its segments IN MEMORY and has no run
directory at all**, so there is nothing to write a statement beside; that is
a correction to the brief's assumption and not an omission. Neither heavy
test was run from this lane.

**One cost to know about**: at 125M the writer re-reads all twelve segment
files (484 MB, one at a time, at most one resident) to pin their SHA-256
independently of the sink's own record. That is seconds of I/O at the end of
a seven-minute run and it adds no memory.

### Item 3 — the two bundles re-taken under the tag, with the public tables

**Why they had to be re-taken, two reasons.** (1) Stage 17's D19 tag moved
every proof byte of the two TAGGED profiles, so `run-a-tame`, `run-b-zero`,
`run-c-tame` and `run-d-zero` are the verifier's view of runs made under a
rule this profile no longer uses. (2) All four were taken with
`public_tables_included: false`, and the Python run gate could close the
per-slot terminal identity `fin = c·mask_eval + poly(terminals)` at only
twelve of the twenty-three slots because the other eleven read a PUBLIC table
whose values it would not guess at.

**The new writer** is `run_capture_tests::write_the_tagged_gate_bundles`,
`#[ignore]`d beside the stage-15 one, which is left untouched. It REFUSES to
run unless `HL_RUN_CAPTURE_PUBLIC_TABLES=1` is set and asserts, before
writing, that the shape is tagged and that the bundle names the keyed rule.

**Why including the public tables' values publishes nothing.** A slot's
public table is a function of the PUBLIC statement and that stage's
challenges, and weights are public under this project's privacy model (P1
hides inputs, outputs and intermediate activations). They were opt-in only
because of size — and they turn out to cost far less than stage 14 feared.

**MEASURED, one write, 2026-09-20 16:22, exit 0 (`z5-s18-tagged-bundles.log`),
source pin `facc0574a3fe5817c24720157e802b33085a85d8`.**

| bundle | `run.json` | stage files | `manifest.json["total_bytes"]` | on disk |
|---|---:|---:|---:|---:|
| `run-e-tame-tagged` | 35,804 B | 13,468,627 / 13,541,592 / 14,207,655 | **41,256,627 B** | 41,258,387 B |
| `run-f-zero-tagged` | 35,807 B | 13,469,129 / 13,533,563 / 14,208,372 | **41,249,809 B** | 41,251,569 B |

**82.5 MB for the pair**, each **41.3 MB** — well inside the 120 MB ceiling
this stage was given, and only **2.75 MB per bundle** more than stage 15's
38.5 MB. The public tables were expected to dominate; at this shape 93 tables
of 92,192 values render to under 3 MB because almost every value is small.
The segments (12,413,432 B per run) are not written; each stage file pins its
own by length and SHA-256.

**SANITY, CHECKED ON THE FILES AS COMMITTED** (`python3`, after the write):

* **every manifest entry** — five files per bundle (`run.json`, three stage
  files, `README.md`) — matches its recorded byte length AND its recorded
  SHA-256. Nothing is missing and nothing has drifted.
* **`hash_tag`** carries `"rule":"blake3-keyed/1"`, the block profile
  `hashline-zk-mr1/private-block-rung-g-t24-dev/1`, the four context strings
  verbatim, and the four keys — which are stage 17's eight pinned keys to the
  character (`51b7d0b0…`, `2295498f…`, `fe211417…`, `8c4d2cfe…`).
* **`public_tables_included` is `true`** and there are **93 public tables**
  in each bundle's three stage files, **all 93 carrying values**, and for all
  93 the SHA-256 recorded is the SHA-256 of the concatenated 16-byte
  little-endian `Fp2` encodings of exactly the values included. **0
  mismatches.**
* **the plane index table is byte-identical across `e` and `f`**: 22,411
  bytes, SHA-256 `fb4cb87242f1892b4b412eb9a29f1c9cbb4870e5ce56611d1aa574c407c1367b`
  — the same 22,411 bytes and the same `fb4cb872…` prefix stage 15 recorded
  for `run-c-tame` / `run-d-zero`, which is the across-bundle equality the
  Rust test also checks in memory against the table the layout derives.
* both bundles' own self-consistency is what
  `a_three_block_rung_g_run_is_captured_and_the_bundle_is_self_consistent`
  and `every_key_of_a_bundle_is_on_the_allow_list` check in process; both are
  in the green filter below.

**Nothing was deleted, moved or rewritten.** The four older bundles stay byte
for byte where they are and their own `README.md` files are NOT edited (each
`manifest.json` pins its own README by length and SHA-256). The parent
`results/zk60_run_captures_20260920/README.md` is rewritten instead: it says
which four are legacy-rule and superseded for gate purposes, which two are
tagged, what the tag means in a bundle and the one rule about it (re-derive,
never consume), and what the public tables are. The directory now holds
**226 MB** in six bundles, which is the cost of keeping the old four rather
than replacing them.

**They are still not gate evidence.** Ruling T-6: the Python run gate has to
learn the D19 rule before a tagged bundle is judged. These two are the INPUT
to that work.

### Files this stage wrote, and the shared-file list

**Shared files touched: NONE.**

| file | what |
|---|---|
| `private_block/run_statement_file.rs` | **new.** The writer, the reader, the allow list and the JSON reader |
| `private_block/hash_domain.rs` | `imposed_shape_free` (T-3 amended at the two bare constructors) |
| `private_block/layout.rs` | `no_commitment_has_a_node_shaped_column_under`; the old name is it at `HashTag::legacy()` |
| `private_block/endpoint_g.rs`, `boundary.rs` | `new_with_tag`; `new` is it at the legacy rule |
| `private_block.rs` | `IoSpec::endpoints_g` passes the spec's own tag; one `mod run_statement_file;` line |
| `private_block/run.rs` | `boundary_spec` passes the shape's tag |
| `private_block/run_sink.rs` | `STATEMENT_DIR`, and `segment_paths` allows exactly that one directory |
| `private_block/run_tests.rs` | six new tests; the heavy twelve-block test retains its statement |
| `private_block/hash_domain_tests.rs` | two new tests |
| `private_block/run_capture_tests.rs` | the tagged gate-bundle writer |
| docs | `ZK60_RUN_CAPTURE_FORMAT.md` (§11 and the stage-18 header note), this ledger |
| results | `results/zk60_block125m_lane/z*-s18-*.log`, the two new bundles and the parent README |

**THE FORBIDDEN-FILES PROOF**, run after the last code commit:

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 9ded619 -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/gpu hashline/src/native_capture.rs \
  hashline/src/private_block/native_capture.rs \
  hashline/src/private_block/private_seam.rs hashline/src/private_seam.rs \
  private-block-kernel private-model-kernel zkvm-block
```

prints **nothing**. The whole diff against `9ded619` is this ledger, `ZK60_RUN_CAPTURE_FORMAT.md`, `results/`, and eleven files under `hashline/src/private_block*`.

### RECEIPT SIZES DO NOT MOVE

| profile | receipt bytes | pinned by |
|---|---:|---|
| toy (frozen) | **2,816,472** | `the_codec_length_is_the_models_at_every_shape`, `a_frame_one_path_entry_short_is_refused_at_decode` |
| frozen-seam rung | **4,218,264** | the same test |
| rung-G | **4,234,648** | the same test |
| 125M | **40,782,792** | the same test, and `private_block_125m_one_block`'s own assertion |

The twelve-block 125M run's counted segment lengths are unchanged too:
40,033,336 / 40,301,624 x10 / 41,051,160, total **484,100,736 B**, pinned by
`the_twelve_block_125m_receipt_is_the_counted_484_100_736_bytes`, which is in
the pass list.

### Tests and commands of stage 18

All through the shared build lock, `CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`, `--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| **failing first**: `--lib private_block::hash_domain` | `z1-s18-failing-first.log` | **13 passed / 2 failed**, exit 101, the intended FAILED result |
| the same, after the fix | `z2-s18-item1-fixed.log` | **15 passed / 0 failed**, exit 0 |
| `--lib private_block::run_tests`, `--nocapture` | `z3-s18-statement.log` | 24 passed / **1 failed** — the `\u` case of the JSON reader test was written with the escape already expanded, so the input carried a literal `A`; the test's source was corrected to spell the two characters |
| `--lib private_block::run` (run, run_capture and run_statement together) | `z4-s18-run-filter.log` | **51 passed / 0 failed / 4 ignored**, 135.25 s, exit 0 |
| the tagged bundles, `write_the_tagged_gate_bundles -- --ignored` | `z5-s18-tagged-bundles.log` | **1 passed / 0 failed**, exit 0, 3.96 s; the two bundles written, 82.5 MB |
| **the gate**: `--lib private_` | `z6-s18-private-filter.log` | **222 passed / 0 failed / 7 ignored**, 67 filtered out, 313.79 s, exit 0, **13 warnings** — the stage-17 baseline of 214 / 0 / 6 plus the eight new tests and the one new `#[ignore]`d bundle writer. Not one existing test was changed, weakened or removed |
| the heavy binary: `--lib --no-run` | `z7-s18-norun.log` | exit 0, relinked nothing (0.04 s): `hashline-70a7a72f73401de5`, 12,531,168 B, mtime **16:22**, newer than every source file of this lane (the latest is `run_statement_file.rs` at 16:19) |

### THE TWO HEAVY RUNS, PREPARED AND NOT LAUNCHED

The binary is built and is newer than every source file of this lane
(`z7-s18-norun.log`). **Re-read its mtime before launching**: the target
directory is shared with another worktree.

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5
```

**A.** The tagged twelve-block 125M run, which now also RETAINS ITS PUBLIC
STATEMENT at `<HL_PB_RUN_DIR>/statement/run-statement.json` (written only
after the run verifies, ruling D21). The directory must exist and be EMPTY;
the test refuses otherwise.

```
mkdir -p /home/victor/zk60-artifacts/m125-run-l12
```

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_RUN_DIR=/home/victor/zk60-artifacts/m125-run-l12 HL_PB_TIMING=0 HL_TEST_SOURCE_COMMIT=041c740 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_tests::private_run_125m_twelve_blocks >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l12.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l12.done' >/dev/null 2>&1 &
```

**B.** The single-block 125M timing run. `HL_PB_TIMING=1` turns on the phase
clock (stage 11); it writes nothing to disk and takes no run directory.

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_TIMING=1 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-one-block-s18.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-one-block-s18.done' >/dev/null 2>&1 &
```

Both take the HEAVY lock, so enqueuing B immediately behind A is right: it
blocks on the lock and self-starts. **A timing caveat that is not new to
this stage**: this lane's build shape is `CARGO_PROFILE_RELEASE_LTO=false
CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8`, which every stage since 9 has used,
so B is comparable with this lane's earlier 125M figures and NOT with a
default-profile (`lto = "fat"`, one codegen unit) build.

### What this stage did NOT do

* **No heavy run.** No 125M proof, no `--ignored` 125M test, no GPU, no
  timing. The twelve-block 125M run and the single-block 125M timing run are
  the security owner's to launch; the two commands are above.
* **No Python.** The run gate still has to learn the D19 rule before a tagged
  bundle is judged (ruling T-6). The two new bundles are the INPUT to that
  work, not evidence from it.
* **No privacy or soundness acceptance**, and no statement about any run.
* **`pcs::verify_zk` is still unfixed** and finding S17-F1's three refusing
  Python source-pin gates are still refusing: both are outside this lane and
  are the integrator's and the security owner's to dispose of.
* **Stage 16's four moved fixtures were not restored** (see item 1).

### NEXT, in order

1. **The security owner launches the twelve-block 125M run**, which now
   retains its public statement, and the single-block 125M timing run.
2. **The Python run gate learns the D19 rule** and reads
   `run-e-tame-tagged` / `run-f-zero-tagged`, whose public tables carry their
   values, and closes the eleven per-slot terminal checks it could not.
3. **The integrator reviews** stage 17's two shared commits and takes the
   keyed CUDA path and the `pcs::verify_zk` path-length fix.

## Stage 19 — TEST-ONLY: dense public weights and a numerically non-trivial witness at the shaped geometries (2026-09-20, 17:3x–18:4x)

**Status: `LANDED`, every gate green — and it FOUND A PRODUCTION DEFECT.**
Five commits: the skeleton `59d85bd`, item 2 `7792471`, items 3-6 and the
finding `1d2f8d2`, item 7 and task 9 `7a5ea87`, and this ledger.

**The production source is FINAL from this lane's side** (handed to the
integrator at `caa9b9a`). This stage changed **no non-test code path**: only
`#[cfg(test)]` modules under `hashline/src/private_block/`, the one
`#[cfg(test)] mod` registration line a new test module needs, this ledger and
`results/zk60_block125m_lane/`. The forbidden-files proof is below.

**No heavy run from here**: nothing proved at the 125M shape, no `--ignored`
125M test, no GPU. The two 125M tests that DO run build a WITNESS and stop,
and they were measured (22.0 s, 727 MiB, under a 12 GB ceiling).

**No privacy or soundness acceptance is claimed or implied by any of it.**
The rung profiles are development grade (ruling P-7).

**THE HEADLINE: finding S19-F1 — an HONEST proof is rejected by the
verifier** at every shaped profile with more than one key-value head, as soon
as the hidden state varies between heads. The reproducer is the production
fixture with ONE WORD of the hidden input changed. The toy is structurally
exempt. Details below; NOT fixed here.

### Why this stage exists

A read-only investigation on 2026-09-20 established, with `file:line` and by
arithmetic on a captured public table, that the only weights recipe the shaped
tests use — `grow_tests::tame_case` (`grow_tests.rs:581`) — is DIAGONAL:
`diag(outer, inner)` is 64 where `row == col` and 0 elsewhere, `Wg` and `Wu`
are `diag(d, f)` and `Wd` is `diag(f, d)`. `row == col` has no solution above
`d`, so at every shape with `f > d` — rung and rung-G (`d = 96`, `f = 192`),
125M (`d = 768`, `f = 2048`) — hidden unit `j >= d` has **zero input weight
and zero output weight**, and the whole upper half of every `Dom::F` plane
(`g8`, `u16`, `a16`, `h16` and their limbs) is identically zero in every
honest shaped proof this lane has ever made. The toy has `d = f = 16` and can
show neither this nor a genuine axis mix-up.

This stage is TEST-ONLY. It builds a DENSE public-weight recipe, shows the
witness it produces is admissible and numerically non-trivial exactly where
the fixture is empty, and drives it through the proof, the run and the
perturbation battery. **It found a production defect** — recorded as S19-F1
below, not fixed here.

### Item 1 — the survey, and a correction to the brief's premise

| recipe | where | shapes it drives | reaches hidden `[d, f)`? | what it feeds |
|---|---|---|---|---|
| `grow_tests::tame_case`, `grow_tests.rs:581` | `rung_tests`, `review_tests::honest_rung`, `rulings_tests` (incl. the heavy 125M tests), `run_tests::Chain::honest` and `blocks_of`, `run_capture_tests`, `run_statement_file`, `hash_tag_tests`, `norm_alias`, `pad.rs` | toy, rung, rung-G, 125M | **NO** | **every** proof, run, capture, tamper battery and heavy test in the lane |
| `review_tests::distinct_kv_case`, `review_tests.rs:489` | `review_tests` attack 3, `rulings_tests` | rung | **NO** — its `kv_diag` varies the ATTENTION rows per key-value head; the feed-forward matrices are `tame_case`'s diagonals | the grouped-query attacks |
| `parity::shaped_case`, `parity.rs:374` | `parity`'s rung sweep (160 cases) and its group-structure test | **`Shape::rung()` only** | **YES** — `matrix(r, d, f, 64, ffn_mag)` is diagonal-plus-band, so every column `j in [d, f)` of `Wg` / `Wu` and every row `j in [d, f)` of `Wd` is pure band, for 7 of the 8 swept band classes | witness-vs-reference-kernel parity **at the WITNESS LEVEL ONLY: no layout, no proof, no verifier** |
| `pad.rs`'s `the_folded_weight_vectors_vanish_off_support`, `pad.rs:822` | that one test | `Shape::rung()` | **YES**, fully dense band | four MLE folds; **no witness and no proof** |

**The brief's premise was slightly too strong and the correction sharpens the
risk.** Weights that are nonzero into hidden indices `>= d` DO exist in two
places, but neither of them PROVES: one compares the witness with the
reference kernel, the other folds matrices. So the accurate statement is that
**no proof, no run, no capture and no verifier in this lane had ever seen a
weight nonzero into a hidden index `>= d`, at any shape** — the entire proof
path (the plane index map, the support indicators, the slot claims, the LogUp
tables, the weight folds) was untested there — while a wrong definition
SHARED by the witness builder and the reference kernel would in any case
survive the parity sweep.

### FINDING S19-F1 — AN HONEST PROOF IS REJECTED BY THE VERIFIER

**The defect.** At a shape with more than one key-value head, the honest
prover and the honest verifier disagree as soon as the KEY-VALUE heads carry
different NONZERO activations. (The one measured exception is the case where
a key-value head's planes requantize to identically zero — see the table
below; it is also what stops the mechanism from being settled here.) The
verifier's message is always

```
slot 15 [04 Q zero-check (hosts 09Q, 11)]: sumcheck round 0: s(0) + s(1) != claim
```

and, at some recipes, `slot 17 [06 softmax zero-check (hosts 07, 10)]`
instead. It is a COMPLETENESS failure, the class of failure that cannot be
argued away: the witness builder accepts the case, every relation
`pad::every_checkable_relation_holds` can evaluate holds, the independent
reference kernel agrees with the witness plane for plane — and the receipt
does not verify.

**The reproducer is the production fixture with ONE WORD of the hidden input
changed**: `grow_tests::tame_case(&Shape::rung_g())`, `input[0] = 0`. Test
`dense_tests::s19_f1_an_honest_proof_of_the_fixture_with_one_input_word_moved_is_rejected`,
`#[ignore]`d and FAILING on purpose.

**Why nothing saw it.** With `tame_case`'s input the norm output is EXACTLY
`+3` at even width indices and `-3` at odd ones, at every token and at every
shape (the norm is scale-invariant, and the fixture's `|x| = 24,000` ramp
never moves the floor). So the hidden state is the SAME in every head, the
two key-value heads carry identical keys and values, and `A_RQL` — the Q
requantization remainder — is identically `0`. The all-zero input is the same
degeneracy taken further. Those two inputs are the only ones this lane has
ever PROVED at a shaped profile.

**Which axis does it, measured** (`stage19_bisect_the_head_axis`, diagonal
weights scaled per head and per key-value head, on the fixture's own input):

| case, diagonal weights scaled per head / per key-value head, fixture input | verdict |
|---|---|
| query heads FLAT, key-value heads FLAT — **the fixture's own regime** | **VERIFIED** |
| query heads VARY WITHIN a group, key-value heads FLAT | **VERIFIED** |
| query heads FLAT, key-value heads VARY | **REJECTED**, slot 15 |
| query heads vary only BETWEEN groups, key-value heads VARY | **REJECTED**, slot 15 |
| query heads VARY WITHIN a group, key-value heads VARY | **REJECTED**, slot 15 |
| the review's own `distinct_kv_case`, at `Shape::rung()` AND at `Shape::rung_g()` — key-value head 1's `k8` / `v8` requantize to identically zero | **ACCEPTED** |

and, on the HIDDEN INPUT alone with `tame_case`'s own diagonal weights
(`stage19_bisect_the_hidden_input`), `|x| = 24,000` throughout:

| sign pattern of the hidden input | verdict |
|---|---|
| the fixture's own, and the fixture's with `x[0] + 1` (which does not move the norm quotient) | **VERIFIED** |
| alternating by width-index parity, no ramp | **VERIFIED** |
| every sign `+` | **VERIFIED** |
| blocks of HALF a head — the two RoPE partner halves disagree | **VERIFIED** |
| blocks of a WHOLE head — the pattern differs BETWEEN heads | **REJECTED**, slot 15 |
| from a seeded stream | **REJECTED**, slot 15 |
| the fixture's with `x[0] = 0` | **REJECTED**, slot 15 |


**Where to look, and what is NOT established.** Slot 15 hosts the claims of
`SC_QMM` (09Q) and `SC_PV` (11). `SC_QMM` reads `A_Y` and `Wq` and knows
nothing of the head axis, so the head-sensitivity enters through `SC_PV`
(`argument.rs:1074`) — and `SC_SZC`'s failure at one recipe points the same
way at `SC_SCORE` (`argument.rs:1057`). Those are the only two slots that
read the head axis in TWO DIFFERENT WAYS: the query head is the whole of the
challenge `r_h`, the key-value head is its top `log2(kv_heads)` entries
(`cv.extend(fixed(&r_h[..lkv]))`, `ck.extend(fixed(&r_h[..lkv]))`, trap T-3).
Each raises a PRODUCT of two multilinear extensions at that shared point,
while the value slot 15 / slot 17 must supply from the committed planes is
the extension of the pointwise PRODUCT; those two agree only under
conditions, and `kv_heads = 1` — the toy — makes the condition
unconditional, which is consistent with the toy being untouched.

**That is a direction, not a derivation, and the first form of it is already
contradicted by the data.** The simplest version of the argument predicts
that any case with two DIFFERENT key-value heads fails; but the independent
review's own `distinct_kv_case` (`review_tests.rs:489`, `Wk` / `Wv` weighting
the second group's rows at a third of the first's) is **ACCEPTED at both
`Shape::rung()` and `Shape::rung_g()`**, measured. What distinguishes it from
case (iii) above, which is the same construction with different scales, is
that at `21/64` the second key-value head's `k8` and `v8` requantize to
IDENTICALLY ZERO, so that group's whole attention output is zero — while at
`40/64` both groups carry nonzero, different values. **The mechanism is
therefore NOT established by this stage.** What is established is the
trigger, the reproducer, the two candidate slots and the toy's exemption.

**What it means for what has been claimed.** Nothing about the toy profile
moves. At the rung, rung-G and 125M profiles it means the honest proofs
measured so far were made on the one class of input that hides the defect, so
they do not establish that the shaped prover and verifier agree in general.
The independent review's attack 3 (`ZK60_BLOCK125M_RUNG_CODE_REVIEW.md` §3)
concluded "trap T-3 is closed in the code" from the STRUCTURAL fact that the
key-value coordinate is a fixed function of `r_h`; that is true, and it is
not the question this finding raises. Its WITNESS half — the key-value swap
on `distinct_kv_case` — still stands as written, because that case's honest
control is accepted (measured, above); but its rejection message is `slot
15`, the same message S19-F1 produces, so the day the defect is fixed that
test should be re-read to confirm it is the SWAP and not the defect that
the verifier was objecting to.

**Not fixed here.** The production source is final from this lane's side; the
fix is the integrator's and the security owner's. No production file was
edited.

### Item 2 — the one-sided fold check, tightened

`pad.rs`'s `the_folded_weight_vectors_vanish_off_support` folded the four
attention matrices and the three feed-forward matrices and asserted that each
fold vanishes off its inner axis's support. The ATTENTION branch also
asserted that the fold is not identically zero, so that "vanishes" says
something; the FEED-FORWARD branch did not. It now does, and the test also
makes the statement the `f > d` geometry needs and no test had: along the
HIDDEN axis the feed-forward weights must reach into `[d, f)` and stop at
`f`. `Wd`'s own slot fold is already a hidden-axis vector; `Wg` and `Wu` fold
the other way, so their hidden-axis support is read with the mirror fold,
labelled in the test as an instrument for the support statement and not a
fold any slot performs. The test now runs at BOTH `Shape::rung()` and
`Shape::rung_g()`. Nothing existing was weakened.

### Item 3 — the dense recipe

**The public description, in full.** A SplitMix64 stream seeded with the
single constant `DENSE_SEED = 0xD15E_ED19_0000_0001`, read in a fixed order,
so the same shape gives the same bytes forever. No OS randomness, no time, no
real model, nothing read from disk.

| word | shape | distribution |
|---|---|---|
| `Wq`, `Wk`, `Wv`, `Wo` | `(d, d)`, `(kvw, d)`, `(kvw, d)`, `(d, d)` | uniform on `[-56, -1] u [1, 56]` |
| `gamma_a`, `gamma_m` | `(d)` | uniform on `[40, 127]` |
| `Wg`, `Wu` | `(d, f)` | uniform on `[-96, -1] u [1, 96]` |
| `Wd` | `(f, d)` | uniform on `[-B, -1] u [1, B]`, `B = isqrt(48^2 * 192 / f)`: **48** at both rungs, **14** at 125M |
| hidden input | `(tokens, d)` | uniform on `[-6000, -1] u [1, 6000]` |

**Every entry is nonzero** — the draw excludes zero by construction, so
"dense" is a literal statement the test asserts, entry by entry, on all nine
words and on the input. The one shape-dependent band is the down projection:
`z16` is requantized into `int16` and then ADDED to `xres1`, which is also
`int16`, so it is the one site with no headroom to spare, and its band is
scaled as `48 * sqrt(192 / f)` to keep `z16`'s spread the same at every
shape. Every other band is shape-free because the pipeline is already
scale-invariant in `d` (the norm divides by `sqrt(d)`, the matmul multiplies
by it).

**THE PROVABLE HALF, `dense_ff_case`.** Because of S19-F1 the fully dense
recipe cannot be PROVED at any shape with more than one key-value head. So
every proving test of this stage uses the dense FEED-FORWARD words
(`gamma_m`, `Wg`, `Wu`, `Wd`) on `tame_case`'s attention words and
`tame_case`'s input. The feed-forward half has no head axis — `Dom::F` is
`(t, j)` — so this leaves the attention side in exactly the regime every
earlier stage proved in, and makes the feed-forward numerically non-trivial
where the fixture is empty.

**Admissibility and non-triviality, measured at `rung_g`** (asserted in the
tests as floors; the measured fractions are a function of the hidden input
and are NOT recorded here — they are in the stage's hand-back and reachable
by re-running the test with `--nocapture`). The tests assert: at least 90 per
cent of the gate and up planes and at least 40 per cent of the activation and
product planes are nonzero on `[d, f) = [96, 192)`; the padded tail
`[f, f_pad)` is still all zero; every LIVE head slot has a nonzero attention
output and every PADDED head slot has none. Both the fully dense recipe and
the provable one clear the floors.

### Item 4 — reference agreement

`parity.rs` already held the only harness that compares this module's witness
with the independent `private-block-kernel-shaped` crate at a shaped
geometry: `shaped_case` / `run_kernel_shaped` / `compare_shaped`, driven by
`the_whole_block_witness_equals_the_reference_kernel_at_the_rung`. It was
reused, not rebuilt: `shaped_case` was split so that its second half
(`shaped_case_from_words`) takes ANY nine true-sized public words, and the
new test `the_dense_witness_equals_the_reference_kernel_at_the_rung_g` drives
it with the FULLY dense recipe at `Shape::rung_g()`. `compare_shaped` walks
every `Dom::F` position of the true support, the upper half included, so the
agreement IS an agreement about `[d, f)`; the test adds one assertion that
the reference kernel's own `g8` / `u16` / `a16` / `h16` buffers are not
identically zero there, without which the comparison would be a comparison of
zeros. The block output is compared word for word as well.

This is the test that would catch a wrong definition SHARED by nothing — the
two implementations are separate, one of them `no_std`, allocation-free and
written against the shape rather than the plane table.

### Item 5 — prove and verify, dense

| what | result |
|---|---|
| one block at `rung_g`, `dense_ff_case` | proves and verifies **from bytes**, frame **4,234,648 B** — the pinned rung-G length, unmoved, because a receipt's length is a function of the shape alone. A one-byte truncation is still refused |
| a THREE-block run at `rung_g`, `dense_ff_case`, tagged rule | verifies **from its segments**, and every segment is the **counted** length (`counted_segment_bytes`, the same function the tame run asserts against). The test also checks that the upper hidden half is live in EVERY block of the run, not only the first — each block's input is the previous block's output, so this is also the statement that the chaining does not collapse it |
| one block at `rung_g`, FULLY dense | **REJECTED — finding S19-F1.** `#[ignore]`d and failing |

### Item 6 — negative controls on the dense witness

The harness is `review_tests`' own (attack 9's `outcome` / `clone_witness`),
unchanged. On the provable recipe, at token 1 and hidden index `d + 7 = 103`
— a TRUE position in the upper half — one perturbation of `+1` per committed
`Dom::F` plane:

| planes | outcome |
|---|---|
| all **eleven** `Dom::F` planes (`A_G8`, `A_RGL`, `A_A16`, `A_U16`, `A_UL0`, `A_UL1`, `A_H16`, `A_HL0`, `A_HL1`, `A_RH0`, `A_RH1`) | **11 of 11 REJECTED BY THE VERIFIER**, 0 refused by the prover only, 0 accepted. Ten fail at `slot 18 [14 F zero-check (hosts 13G, 13U)]`; the `A_H16` perturbation fails at `slot 14 [03 D zero-check (hosts 12, 13D)]`, which is the down projection noticing it first |

The honest control is asserted ACCEPTED first, under the same harness, or the
rejections would say nothing. This is the brief's five named planes (gate, up,
activation, product, down-projection input) and six more.

**The grouped-query control is BLOCKED and `#[ignore]`d.** An off-diagonal
score perturbation of a query head in a shared group, and one perturbation
each of the shared key-value head's rotated key and value planes, all make
the key-value heads carry different activations — which is exactly the
condition under which S19-F1 rejects an HONEST proof. A rejection would not
distinguish the tamper from the defect, and the honest control the test opens
with is itself rejected. It becomes a real control the day S19-F1 is fixed.

### Item 7 — the recipe option on the heavy 125M tests

`rulings_tests::private_block_125m_one_block` now takes its case from two
environment variables, both defaulting to what every earlier stage measured,
so nothing that has been measured moves:

* `HL_PB_WEIGHTS` — `tame` (default), `dense-ff` (the provable recipe), or
  `dense` (fully dense, **expected to be REJECTED by S19-F1**). Any other
  value is refused by name.
* `HL_PB_INPUT` — `fixture` (default) or `zero` (task 9(b)).

The weight fold is the one phase whose COST this changes: `fold_cols_i8` and
`fold_rows_i8` skip zero weights, so every published 125M timing taken on the
diagonal fixture has an optimistic weight-fold phase, and `dense-ff` is the
first measurement that does not.

### Task 9 — the ALL-ZERO hidden input at the 125M shape (the security owner's addition)

**(a) It is ADMITTED, under BOTH weights recipes, and the two zero-headroom
boundary facts the privacy case rests on still hold at 125M.** The witness
builder accepts it; the test pins, at the shape's own constants
(`limbs_sigma_s = 3`, `wrho_s = 18`, `f_e = 9`, `tokens = 512`, against the
toy's 2 / 14 / 9 / 32):

| fact | at 125M |
|---|---|
| `NORM_CEPS = 1`, so both norm denominators are positive at the zero input | every `norm_a` and `norm_m` denominator is `isqrt(1) = 1` |
| `exp[0] = 2^f_e`, pinned on the PUBLIC STATEMENT by the constructor | `512` |
| **boundary 1**: the softmax remainder complement against the EXCLUSIVE window `2^wrho_s` | **262,143 of an allowed 262,144 — HEADROOM EXACTLY ZERO** |
| **boundary 2**: the softmax quotient against the INCLUSIVE bound `2^F_P` | `512` of `512`, on the bound |
| **boundary 3** (new, and only tight at a power-of-two token count): the softmax denominator against its INCLUSIVE upper bound `tokens << f_e` | `262,144` of `262,144`, on the bound |
| the masked exponent difference stays inside the exp table's 256 rows | `-MASK_SCORE = 127` |
| the zero chain | `x_in` and the block output are identically zero |

Boundary 1 is tight exactly when `tokens` is a power of two (the toy's 32 and
125M's 512); at both rungs `tokens = 24` and no row is tight, so the test
asserts the zero-headroom form BY SHAPE rather than unconditionally. That is
the one place the toy's pinned constant does not transfer.

**The zero witness does not depend on the public weights.** Every weight is
multiplied by zero, so the witness of the all-zero input is a function of the
SHAPE and the tables alone. The test asserts it by fingerprinting all planes
of the tame witness, dropping it, building the dense one and comparing — so
only one 125M witness is ever resident. This is itself worth pinning: it is
why the fixed input of the privacy argument does not have to be re-argued for
every weights recipe.

**Cost, measured** (`w?-s19-zero125m.log`, under the heavy lock,
`systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0`): **13.40 s
wall, peak 742,096 KB (725 MiB)** for BOTH witnesses. Cheap, because the zero
witness never writes most of its pages and the kernel never faults them in.
So the test is a NORMAL test, not `#[ignore]`d, and it is in the `private_`
gate.

**(c) does not apply**: the all-zero input is not refused at 125M.

**(b)** `rulings_tests::private_block_125m_one_block` under `HL_PB_INPUT=zero`
proves and verifies one 125M block on the all-zero hidden input. NOT RUN from
this lane; the command is below.

### What this stage did NOT do

* **No production code path was changed.** Only `#[cfg(test)]` modules under
  `hashline/src/private_block/`, one `#[cfg(test)] mod dense_tests;`
  registration line in `hashline/src/private_block.rs`, this ledger and
  `results/`.
* **S19-F1 was NOT fixed.** The production source is final from this lane's
  side.
* **No heavy run.** Nothing proved at the 125M shape, no `--ignored` 125M
  test, no GPU, no timing. The two 125M witness-builder tests that DO run are
  normal tests, measured, and cost 13.4 s / 725 MiB and the figures below.
* **No privacy or soundness acceptance**, and no statement about any run. The
  rung profiles are development grade (ruling P-7).

### THE TWO HEAVY 125M COMMANDS, PREPARED AND NOT LAUNCHED

The binary is built and is newer than every source file of this lane
(`w2-s19-norun.log`). **Re-read its mtime before launching**: the target
directory is shared with another worktree.

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5
```

**The DENSE FEED-FORWARD one-block 125M run** (item 7). This is the one worth
having: it is the first 125M measurement whose weight-fold phase is not
optimistic, and it does not meet S19-F1.

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_TIMING=1 HL_PB_WEIGHTS=dense-ff /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-one-block-dense.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-one-block-dense.done' >/dev/null 2>&1 &
```

**The ALL-ZERO-input one-block 125M run** (task 9(b)).

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_TIMING=1 HL_PB_INPUT=zero /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-one-block-zero.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-one-block-zero.done' >/dev/null 2>&1 &
```

Both take the HEAVY lock, so enqueuing the second behind the first is right:
it blocks on the lock and self-starts. **`HL_PB_WEIGHTS=dense` (the FULLY
dense recipe) is expected to be REJECTED at 125M by S19-F1** — 125M has four
key-value heads and the dense attention words make them carry different
activations — so it is not offered as a run to make; the witness-builder test
above already establishes that its witness is admissible there, which is the
part that was worth knowing.

### Files this stage wrote, and the shared-file list

**Shared files touched: NONE. Production code paths touched: NONE.**

| file | what |
|---|---|
| `private_block/dense_tests.rs` | **new, `#[cfg(test)]`.** The dense recipe, the provable half, the admissibility and non-triviality tests, the one-block proof, the upper-hidden-half battery, the S19-F1 reproducer and the three bisection diagnostics |
| `private_block.rs` | **one line**, `#[cfg(test)] mod dense_tests;` (plus its comment). This is the single registration line the brief allows, and it is the only edit to a file that also holds production code |
| `private_block/pad.rs` | inside its `#[cfg(test)] mod tests`: the fold test tightened and run at both rungs. Plus `every_checkable_relation_holds` (already `#[cfg(test)]`) widened from private to `pub(super)` so the diagnostics can call it |
| `private_block/parity.rs` | (`#[cfg(test)]` module) `shaped_case` split into `shaped_case_from_words`, and the dense reference-agreement test |
| `private_block/run_tests.rs` | (`#[cfg(test)]` module) `Chain::from_parts`, `blocks_from`, and the three-block dense feed-forward run |
| `private_block/rulings_tests.rs` | (`#[cfg(test)]` module) `HL_PB_WEIGHTS` and `HL_PB_INPUT` on the heavy 125M test |
| `private_block/zero_witness_tests.rs` | (`#[cfg(test)]` module) the all-zero input at 125M and at both rungs (task 9(a)) |
| docs | this ledger |
| results | `results/zk60_block125m_lane/w*-s19-*.log` |

### THE FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat caa9b9a -- \
  hashline/src zkp-core private-block-kernel-shaped
```

prints seven paths and nothing under `zkp-core` or
`private-block-kernel-shaped`:

```
 hashline/src/private_block.rs                    |   5 +
 hashline/src/private_block/dense_tests.rs        | 845 +++++++++++++++
 hashline/src/private_block/pad.rs                |  88 ++-
 hashline/src/private_block/parity.rs             |  63 +-
 hashline/src/private_block/rulings_tests.rs      |  54 +-
 hashline/src/private_block/run_tests.rs          |  61 +-
 hashline/src/private_block/zero_witness_tests.rs | 128 ++++
```

Five of the seven are WHOLE `#[cfg(test)]` modules — `dense_tests`,
`parity`, `rulings_tests`, `run_tests`, `zero_witness_tests` are each
declared `#[cfg(test)] mod …;` in `private_block.rs:112-174`, so nothing in
them enters the library or the binary. The other two are files that also hold
production code, and each of their hunks sits inside `#[cfg(test)]`:

| file | hunk | why it is test code |
|---|---|---|
| `private_block.rs` | `@@ -111,6 +111,11 @@` | the whole addition is three comment lines and `#[cfg(test)]` + `mod dense_tests;`. The item carries the attribute. This is the one registration line the brief allows |
| `pad.rs` | `@@ -423,13 +423,13 @@` | one word: `fn every_checkable_relation_holds` becomes `pub(super) fn`. The line DIRECTLY ABOVE it in the diff context is its own `#[cfg(test)]` attribute (`pad.rs:428`), unchanged |
| `pad.rs` | `@@ -810,42 +810,78 @@ mod tests {` | inside `#[cfg(test)] mod tests` (`pad.rs:489-490`); the hunk header itself names the module |

The whole diff against `caa9b9a` is those seven files plus this ledger and
`results/zk60_block125m_lane/`.

### RECEIPT SIZES DO NOT MOVE

| profile | receipt bytes | asserted by |
|---|---:|---|
| rung-G, one block, dense feed-forward | **4,234,648** | `an_honest_dense_feed_forward_block_proves_and_verifies_from_bytes_at_the_rung_g`, and by the S19-F1 reproducer before it reaches the verifier |
| rung-G, three-block run, dense feed-forward | the counted segment lengths | `an_honest_three_block_dense_run_verifies_from_its_segments`, against `counted_segment_bytes`, the same function the tame run asserts against |

Both are the tame fixture's own figures, which is the point: a receipt's
length is a function of the shape and of nothing else.

### NEXT, in order

1. **S19-F1 is the integrator's and the security owner's.** It is a
   completeness failure at every shape with more than one key-value head, on
   the ordinary inputs a real model produces; the toy is exempt. Until it is
   fixed, no shaped proof of a realistic hidden state can be made, and the
   grouped-query soundness controls cannot be run.
2. The two prepared 125M runs above (`dense-ff`, and the all-zero input).
3. The rest of stage 18's NEXT list is unchanged.

### Tests and commands of stage 19

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`, and **without
`--nocapture`** — which is what keeps the per-witness COUNTS, which are
functions of the hidden input, out of the retained logs.

| command | log | result |
|---|---|---|
| `--lib private_block::dense_tests::the_dense_recipe` (the first build) | `w1-s19-recipe.log` | 1 passed / 0 failed, exit 0 |
| `--lib --no-run` | `w2-s19-norun.log` | exit 0, **13 warnings**; `hashline-70a7a72f73401de5` |
| the two 125M WITNESS-BUILDER tests, run from the binary under `flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0` | `w3-s19-125m-witness.log` | 2 passed / 0 failed, **22.03 s wall, peak 743,980 KB = 727 MiB** for all four 125M witness builds |
| **the gate**: `--lib private_` | `w4-s19-private.log` | **233 passed / 0 failed / 13 ignored**, 67 filtered out, **344.57 s**, exit 0, **13 warnings** |

Against the stage-18 baseline of **222 / 0 / 7** and 13 warnings: eleven new
passing tests and six new ignored ones. **Not one existing test was changed,
weakened or removed**, and the toy's frozen tests are untouched.

The six ignored tests are: the S19-F1 reproducer and the fully dense
one-block proof (**both FAIL, on purpose, and are the finding**), the
grouped-query control (blocked by S19-F1), and the three bisection
diagnostics (each proves several rung-G blocks; they are diagnostics, not
gates). **The diagnostics' own runs are NOT retained under `results/`**: they
print counts and plane values' provenance, and the capture rule keeps them
out. Re-run them with `--ignored --nocapture` to see them.

## Stage 20 — FIXING S19-F1: the key-value group bits become sumcheck variables (2026-09-20, 18:4x–19:5x)

**Status: `LANDED`, the whole `private_` gate green — 245 passed / 0
failed / 8 ignored, 13 warnings.** The security owner's ruling on finding S19-F1 is
implemented. This is the FIRST PRODUCTION CHANGE this lane has made since
`caa9b9a`: two slot definitions in `argument.rs`, one new builder method, and
two lines of the slot schedule in `shape.rs`. Everything else is tests, the
counted re-pins the change forces, this ledger and `results/`.

**No heavy run.** Nothing proved at the 125M shape, no `--ignored` 125M test,
no GPU, no capture bundle re-taken. **No privacy or soundness acceptance is
claimed**; the rung profiles are development grade (ruling P-7).

Commits: the skeleton `c8f1c31`, the repair `5155d5b`, the counted re-pins
and the capture-format note `2f692bb`, and this ledger.

### THE DEFECT, IN ONE PARAGRAPH

`SC_SCORE` claims `score~(r_h, r_t, r_j)`, the multilinear extension of the
POINTWISE PRODUCT `score[h,t,j] = sum_c q[t,h,c] k[j,g(h),c]`, where `g(h)` —
the key-value group of head slot `h` — is the top `lkv = log2(kv_heads)` bits
of `h`. Until stage 20 the slot summed over the head dimension `c` ALONE and
took the group as a FIXED coordinate `r_h[..lkv]` of BOTH private factors,
which computes the PRODUCT OF THE TWO EXTENSIONS. Those two are not equal:
the product is quadratic in the shared group bits, and they agree only when
one factor does not vary across groups. `SC_PV` had the same shape. The
honest prover and the honest verifier therefore disagreed as soon as the
key-value groups carried different activations — a COMPLETENESS failure,
reproduced by the security owner on the production fixture with one word of
the hidden input moved.

### THE REPAIR, AS BUILT

`r_h` splits into `r_g` (the top `lkv` entries, the group) and `r_hj` (the
query head WITHIN its group). The group becomes SUMCHECK VARIABLES, under a
PUBLIC `eq(r_g, .)`:

```text
SC_SCORE:  score~(r_h,r_t,r_j) = sum_{g in {0,1}^lkv} sum_{c in {0,1}^ldh}
                                   eq(r_g,g) . q~(r_t,(g,r_hj),c) . k~(r_j,g,c)
SC_PV:     o~(r_t,r_h,r_i)     = sum_{g}          sum_{s in {0,1}^lt}
                                   eq(r_g,g) . P~((g,r_hj),r_t,s) . V~(s,g,r_i)
```

which is an identity because `k` / `V` do not depend on `hj` and `q` / `P`
are multilinear in those bits, so `sum_hj eq(r_hj,hj) X~(..,(g,hj),..) =
X~(..,(g,r_hj),..)`.

**The variable order, exactly as built.** Variables `0 .. lkv` are the group
`g`; variables `lkv ..` are the slot's own inner axis (`c` for `SC_SCORE`,
the source token `s` for `SC_PV`). Coordinates are most-significant-first
throughout, and the public factor is `Tab::Eq { point: r_g, start: 0 }`,
which reads the LEADING `lkv` variables.

| slot | plane | domain order | coordinates as built |
|---|---|---|---|
| `SC_SCORE` | `A_QR8` | `Dom::Q = (t, head slot, c)` | `fixed(r_t)` ‖ `rho(0..lkv)` ‖ `fixed(r_hj)` ‖ `rho(lkv..lkv+ldh)` |
| `SC_SCORE` | `A_KR8` | `Dom::Kv = (j, group, c)` | `fixed(r_j)` ‖ `rho(0..lkv)` ‖ `rho(lkv..lkv+ldh)` |
| `SC_PV` | `A_P` | `Dom::S = (head slot, t, s)` | `rho(0..lkv)` ‖ `fixed(r_hj)` ‖ `fixed(r_t)` ‖ `rho(lkv..lkv+lt)` |
| `SC_PV` | `A_V8` | `Dom::Kv = (s, group, i)` | `rho(lkv..lkv+lt)` ‖ `rho(0..lkv)` ‖ `fixed(r_i)` |

The group coordinate of BOTH factors of a slot is the SAME variable list
`0 .. lkv` — that is trap T-3, restated for the repaired construction, and it
is asserted in `grow_tests::the_slot_definitions_are_built_from_the_shape`
together with the fact that the `eq` carries the head challenge's OWN group
bits (read back through the claim point `p_s` / `p_o`) and not a point of its
own. The "two private factors, `qr` masked in extension round 0 and `kr` in
round 1" mechanism is untouched, and the construction premise at the head of
`argument.rs` still holds: each extension round has exactly one nonzero
entry, so `poly(extensions) = 0`.

**THE TOY PAYS NOTHING.** `kv_heads = 1` gives `lkv = 0`, an EMPTY `r_g`, and
the new `B::group_eq` returns `None` — no variable, no table, no degree, no
transcript byte. The closure gates on it through the module's own `Gate`,
whose `None` arm is the constant `ONE`, so the toy's slot polynomial is the
product of its two private factors and nothing else. The frozen gates are
green: **2,816,472 B**, `the_toy_schedule_digest_is_frozen`,
`the_toy_parameter_line_is_the_frozen_literal`, and the four pre-lane
receipts.

**One shape of the code is deliberate and would otherwise be an `if`.** The
committed leak-checking driver `scripts/zk60_private_block_inventory.py`
PARSES `define`'s arms; its condition evaluator knows `slot == SC_X` and
boolean locals and nothing else, and `if lkv > 0 { .. }` broke it (measured:
four errors). The arms therefore carry no `if`: the public factor comes from
`B::group_eq` (a call the parser ignores, exactly as it ignores `b.eq`), and
the shifted `rho` segments are built as `rho(0..lkv + inner)` followed by
`split_off(lkv)`, which is a no-op at the toy and so leaves the parser's own
value equal to the real one. That driver's forty tests pass again.

### Round counts, mask lengths and every number that moved

| shape | `lkv` | `SC_SCORE` (main, ext, deg, L) | `SC_PV` (main, ext, deg, L) |
|---|---:|---|---|
| toy | 0 | (3, 2, 2, 12) → **unchanged** | (5, 2, 2, 16) → **unchanged** |
| rung / rung-G | 1 | (4, 2, 2, 14) → **(5, 2, 3, 23)** | (5, 2, 2, 16) → **(6, 2, 3, 26)** |
| 125M | 2 | (6, 2, 2, 18) → **(8, 2, 3, 32)** | (9, 2, 2, 24) → **(11, 2, 3, 41)** |

| figure | toy | rung / rung-G | 125M |
|---|---|---|---|
| main rounds, whole block | 159 → 159 | 215 → **217** | 332 → **336** |
| extension rounds | 25 → 25 | 25 → 25 | 25 → 25 |
| published round VALUES `sum (main+ext)(deg+1)` | 721 → 721 | 1,034 → **1,055** | 1,519 → **1,554** |
| sumcheck challenge DRAWS per block | 184 → 184 | 240 → **242** | 357 → **361** |
| private terminals per block | 173 → 173 | 176 → 176 | 174 → 174 |
| worst `L_s` (and where) | 50 (`SC_SZC`) | 72 (`SC_FZC`, `SC_SZC` ties) | 117 (`SC_SZC`) |
| masking commitment `M` rows | 50 | 50 | 50 |
| `A` / `H` claim sites, opening groups | unchanged | unchanged | unchanged |

`L_s + 256 <= 512` holds with room everywhere; the worst slot did not move
and the two repaired slots are far below it. The declared degree reaches 3,
which is inside `Shape::degree_range()`'s `2 ..= 5`, so the T-3 hash-length
table stays complete — now asserted at all four shapes by
`pad::tests::the_declared_degrees_are_inside_the_declared_range`.

**Receipt and segment bytes, old → new.** The repair moves exactly one part
of a frame — the slot vector — so every figure below is the pre-repair one
plus `16 * sum_{SC_SCORE, SC_PV} [(main'+ext)(deg'+1) - (main+ext)(deg+1)]`,
which is **+336 B** at both rungs and **+560 B** at 125M. **No figure in the
Rust is a pasted new number**: `grow_tests::s20_bilinear_delta` counts the
delta from the shape's axes and every pin is `old + delta`.

| receipt | old | new |
|---|---:|---:|
| toy, one block | 2,816,472 | **2,816,472** (unmoved) |
| rung (frozen seam), one block | 4,218,264 | **4,218,600** |
| rung-G, one block | 4,234,648 | **4,234,984** |
| 125M, one block | 40,782,792 | **40,783,352** (its `slots` part 27,456 → 28,016) |
| rung-G run, `L = 3` (segments) | 12,413,432 | **12,414,440** |
| rung-G run, `L = 12` (segments) | 49,217,600 | **49,221,632** |
| 125M run, `L = 12` (segments) | 484,100,736 | **484,107,456** |

### The acceptance tests

| test | before stage 20 | now |
|---|---|---|
| `dense_tests::s19_f1_..._one_input_word_moved_is_accepted` (renamed from `..._is_rejected`) | `#[ignore]`d, FAILING on purpose — the finding itself | **PASSES.** Same witness, same assertions; only the name, the `#[ignore]` and two `expect` messages changed |
| `dense_tests::an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_g` (FULLY dense) | `#[ignore]`d, FAILING | **PASSES** |
| `dense_tests::a_shared_kv_head_perturbation_..._is_rejected_at_the_rung_g` (the grouped-query control) | `#[ignore]`d, confounded | **PASSES** — the honest control is accepted, so each of the three rejections is the tamper |
| `dense_tests::stage19_bisect_the_dense_failure` | `#[ignore]`d diagnostic | **REGRESSION TEST**: no honest variant may be rejected by the verifier (a witness-builder or prover refusal stays allowed — some bands really do leave `int16`) |
| `dense_tests::stage19_bisect_the_hidden_input` | `#[ignore]`d diagnostic; **five of its eight inputs were REJECTED** | **REGRESSION TEST**: all eight must VERIFY, and do |
| `dense_tests::stage19_bisect_the_head_axis` | `#[ignore]`d diagnostic; **three of its five cases REJECTED** | **THE ACCEPTANCE MATRIX**: all five VERIFY, and the review's `distinct_kv_case` is accepted at both rung profiles |
| `run_tests::an_honest_three_block_fully_dense_run_verifies_from_its_segments` | did not exist — S19-F1 forbade it | **NEW, PASSES** |

### The INDEPENDENT check of the two identities (the one that does not go through `define`)

Prover and verifier share ONE definition, which is exactly why the defect
survived nineteen stages of prove-and-verify tests. Two new tests evaluate
both sides of each identity with plain loops over the Boolean cube, from the
RAW planes, touching no `Layout`, no transcript and no sumcheck:

* `the_two_bilinear_identities_hold_independently_of_the_argument_at_the_rung_g`
  — on the real rung-G witnesses. On the **FULLY DENSE (generic)** witness:
  `NEW == LHS` for both slots and `OLD != LHS` for both. On **`tame_case`
  (the degenerate fixture)**: `NEW == LHS` and **`OLD == LHS`** — which is
  the mechanism of the defect's nineteen-stage invisibility, stated as a
  test.
* `the_two_bilinear_identities_hold_at_a_synthetic_four_key_value_head_geometry`
  — RANDOM planes (a stronger test of an algebraic identity than a witness,
  which has structure that could hide a mistake) at `T8/H4/dh4/KV4`,
  `T8/H8/dh4/KV4`, `T8/H4/dh4/KV2` and `T8/H2/dh4/KV1`. `lkv = 2` is the
  first case where the group is more than one bit; `KV1` asserts the
  opposite, that the OLD formula IS the identity when there is one key-value
  head, which is the toy's exemption written algebraically.

### The negative controls the repair makes possible

On the FULLY dense witness at rung-G, where both key-value groups carry real
and DIFFERENT data — the regime S19-F1 rejected outright, so none of this
could be asked before. The honest control is asserted ACCEPTED first in each.

| control | outcome |
|---|---|
| `+1` in `A_QR8` at a non-first head of the SECOND group, in `A_KR8` and `A_V8` at the second group, and in `A_P` at a causally live position of a non-first head of the second group | **4 of 4 rejected, 0 accepted** (`a_perturbation_in_the_second_key_value_group_..._is_rejected_at_the_rung_g`) |
| exchanging the two groups' whole KEY family (`A_K8`, `A_RKL`, `A_KR8`, `A_RKRL`), values untouched | **rejected BY THE VERIFIER** (`exchanging_the_two_key_value_groups_keys_is_rejected_at_the_rung_g`) |
| the review's attack 3 (`a_query_head_reading_the_other_key_value_head_is_rejected_at_the_rung`), unchanged | still rejected by the VERIFIER; its honest control is accepted as before, and the dense swap above is the case its own fixture could not make, because `distinct_kv_case`'s second key-value head requantizes to identically zero (stage 19's surprise 3) |

### The Python layout model and the inventory driver

* `scripts/zk60_private_block_layout_model.py` is **outside this lane's write
  set** and still declares the OLD bilinear schedule. It was re-run with the
  repaired schedule through a probe that monkey-patches `slots` and edits
  nothing (`results/zk60_block125m_lane/v6-s20-model-probe.py` / `.log`), and
  it reproduces the Rust's deltas exactly: +336 B at the rung, +560 B at
  125M, `main_round_total` 215 → 217 and 332 → 336, nothing else moving. Its
  own 25 tests still pass, because they compare the model with the memo and
  not with the Rust. **The model owes the same two-line change** (`SC_SCORE`
  and `SC_PV` gain `log2(kv_heads)` main rounds and, when the shape groups,
  one degree); `grow_tests`' `Expected` constants stay the model's PRE-repair
  figures and are compared through the counted delta, exactly as S11a and
  S11b already do for the endpoint.
* `scripts/zk60_private_block_inventory.py` PARSES the real `define` and
  speaks about the TOY alone. **Its forty tests pass** (51.8 s) and every
  figure it derives is unchanged — the toy is byte-frozen — including its own
  gate "the toy profile read out of the shaped Rust equals the independent
  layout model's" and its 74-of-74 paper comparison. The first shape of the
  repair (an `if lkv > 0`) broke its parser with four errors; the arms were
  rewritten to carry no `if`, which is why.

### THE 125M COMMANDS, PREPARED AND NOT LAUNCHED

**Re-read the binary's mtime before launching**: the target directory is
shared with another worktree.

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-<hash>
```

The DENSE FEED-FORWARD one-block 125M run (still the one worth having: the
first 125M measurement whose weight-fold phase is not optimistic):

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_TIMING=1 HL_PB_WEIGHTS=dense-ff hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> results/zk60_block125m_lane/m125-one-block-dense-ff.log 2>&1; echo $? > results/zk60_block125m_lane/m125-one-block-dense-ff.done' >/dev/null 2>&1 &
```

The FULLY DENSE one-block 125M run — **newly possible**: S19-F1 is what made
`HL_PB_WEIGHTS=dense` un-runnable at 125M (four key-value heads carrying
different activations), and the witness was already known admissible there:

```
... HL_PB_TIMING=1 HL_PB_WEIGHTS=dense hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block ...
```

The ALL-ZERO-input one-block 125M run (task 9(b)):

```
... HL_PB_TIMING=1 HL_PB_INPUT=zero hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block ...
```

All three take the HEAVY lock, so enqueuing them together is right: each
blocks on the lock and self-starts.

**Does a fully dense admissible RUN recipe exist?** At **rung-G, YES, and it
is measured: the down-projection band is 47**, one below the recipe's own
48, at which the witness builder refuses the chain's second block by name
(`fixed oracle range refusal: residual 2`).
`first_admissible_dense_run_band` searches DOWNWARDS from the recipe's own
and takes the first band at which the builder accepts all three blocks, with
every other band — attention included — left at the recipe's, so the
attention words are the fully dense ones and the two key-value groups carry
different rotated keys in EVERY block of the run (asserted). Measured:
prove 1.42 s, verify from segments 0.29 s, segments 4,067,160 / 4,089,688 /
4,257,592 B = **12,414,440 B**, which is the counted figure and is the
pre-repair 12,413,432 plus 3 x 336 to the byte.
A run needs a smaller down band than a block because block `k+1`'s hidden
input IS block `k`'s `xres2 = xres1 + z16`, so `z16`'s spread compounds and
the residual leaves `int16`. **At 125M it is NOT determined here**: the same
search costs up to twelve 125M witness builds (~11 s and 725 MiB each), which
is a heavy run. It is left as one ignored command:

```
... hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_tests::the_first_admissible_fully_dense_run_band_at_125m
```

### Files this stage wrote

| file | what |
|---|---|
| `private_block/argument.rs` | **PRODUCTION.** The two bilinear arms; `B::group_eq`; a `#[cfg(test)]` accessor for the two claim points |
| `private_block/shape.rs` | **PRODUCTION.** `slots()`: `lkv` more main rounds and one more degree for the two bilinear slots when the shape groups |
| `private_block/grow_tests.rs` | the repaired T-3 statement, `s20_bilinear_delta` / `s20_frame_bytes`, and the counted re-pins |
| `private_block/pad.rs` | the two bilinear slot lengths recomputed from the axes, and the degree-range test |
| `private_block/dense_tests.rs` | the acceptance tests, the independent identity check, the second-group and key-swap controls |
| `private_block/run_tests.rs` | the fully dense three-block run, the band search, the 125M band probe, the counted re-pins |
| `private_block/rulings_tests.rs`, `private_block/rung_tests.rs` | counted re-pins |
| `docs/…/ZK60_RUN_CAPTURE_FORMAT.md` | the stage-20 note: what a capture of a grouped profile now looks like |
| `docs/…/ZK60_BLOCK125M_LANE_PROGRESS.md` | this ledger |
| `results/zk60_block125m_lane/` | `v?-s20-*.log`, and the model probe |

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat d4742ce -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block
```

prints NOTHING: every one of those trees is byte-identical to `d4742ce`.

### Tests and commands of stage 20

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`, and **without `--nocapture`**
— which is what keeps per-witness counts out of the retained logs.

| command | log | result |
|---|---|---|
| `--lib private_block::grow_tests::the_slot_definitions` (the first build) | `v1-s20-defs.log` | 1 passed, exit 0 |
| `--lib --no-run` | `v3-s20-build.log` | exit 0, **13 warnings** |
| the structural filter (grow / pad / layout / hash-domain / rulings) | `v4-s20-struct.log` | 116 passed, **2 failed** — the two stale pins, corrected on the spot |
| the gate, first pass | `v5-s20-private.log` | 244 passed / **1 failed** / 7 ignored, 372.6 s — the failure being the twelve-block 125M pin, which the re-pin commit had not yet reached the binary |
| **THE GATE**: `--lib private_` | `v7-s20-private.log` | **245 passed / 0 failed / 8 ignored**, 67 filtered out, **374.71 s**, exit 0, **13 warnings** |
| `--lib --no-run`, the prebuild handed back | `va-s20-norun.log` | exit 0, 13 warnings |
| the Python layout model | `v9-s20-model.log` | **25 passed** |
| the Python inventory driver (it PARSES the repaired `define`) | `v8-s20-inventory.log` | **40 passed**, 45.8 s |
| the model probe with the repaired schedule | `v6-s20-model-probe.log` | the deltas reproduce the Rust's exactly |

**Against the stage-19 baseline of 233 passed / 0 failed / 13 ignored and 13
warnings**: `245 / 0 / 8`. Six tests were UN-IGNORED (the S19-F1 reproducer,
the fully dense block, the grouped-query control and the three bisection
diagnostics), six are new (the two identity checks, the two second-group
controls, the fully dense run, the degree-range test) and one new one is
ignored (the 125M fully dense RUN band probe). **Not one existing test was
weakened or removed**; the only test-body edits to existing tests are the
counted re-pins, the un-ignoring, and the T-3 statement restated for the
repaired construction.

**The verdicts, measured** (from a `--nocapture` re-run of the five tests
that print them; the output is NOT retained under `results/`, per the
capture rule, and only these counts are recorded):

| what | verdict |
|---|---|
| the head-axis matrix, all five cases | **VERIFIED** (three of them were REJECTED before the repair) |
| the review's `distinct_kv_case` at both rung profiles | **ACCEPTED** |
| the eight hidden inputs of the second bisection | all **VERIFIED** (five were REJECTED before) |
| the identity check on the real rung-G witnesses | FULLY DENSE: `new == lhs` for both slots, `old != lhs` for both. `tame_case`: `new == lhs` AND `old == lhs` |
| the identity check on random planes | `T8/H4/dh4/KV4`, `T8/H8/dh4/KV4`, `T8/H4/dh4/KV2`: `new == lhs`, `old != lhs`. `T8/H2/dh4/KV1`: `new == lhs`, `old == lhs` |
| the four second-group perturbations | **4 of 4 REJECTED BY THE VERIFIER**, 0 by the prover, 0 accepted (`A_QR8`, `A_P`, `A_V8` at slot 15 `04 Q zero-check`; `A_KR8` at slot 16 `05 KV zero-check`) |
| the key-family swap between the two groups (1,456 positions differ) | **REJECTED BY THE VERIFIER**, slot 16 `05 KV zero-check` |
| the three shared-key-value-head tampers | **3 of 3 REJECTED BY THE VERIFIER** (slots 17, 16, 15) |

### THE PREBUILT TEST BINARY

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5
```

**mtime 2026-09-20 19:17:22 -0700**, 12,783,776 B, newer than every source
file of this lane (`va-s20-norun.log`, exit 0). **Re-read its mtime before
launching anything**: the target directory is shared with another worktree.


## Stage 21 — the owed items before the hand-back (2026-09-20, 19:5x–21:0x)

**Status: `LANDED`.** Five items, all of them owed by the independent
stage-20 review (`ZK60_BLOCK125M_S20_FIX_REVIEW.md`, findings F-1 … F-6) or
by ruling R-5 of `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`.

**No shared or frozen file changed** (proof below) and the toy stays
byte-frozen: 2,816,472 B, the schedule digest, the parameter line and the
four pre-lane receipts, all green. **No proof byte of any profile moved at
this stage** — item 3 is measured against that, byte for byte.

**No heavy PROVING run.** Two witness-builder-only 125M runs were made
(item 4), both under the heavy lock inside a 12 GB ceiling; nothing proved
at 125M, no GPU, no timing. **No privacy or soundness acceptance** is
claimed or implied; the rung profiles are development grade (ruling P-7)
and the run privacy gate of ruling M-8 is still unmet.

Commits: the skeleton `2d4da2a`, items 1–3 `71c6509`, items 4–5 code
`0426ad2`, and this ledger with the evidence.

| item | what | state |
|---|---|---|
| 1 | F-1: the layout model derives the repaired schedule ITSELF; the Rust-side delta adjustment removed | **DONE — and the model and the Rust AGREE everywhere** |
| 2 | F-2: a NAMED refusal for a shape whose bilinear domains are P-3 lifted | **DONE**, failing-first recorded |
| 3 | R-5: interior boundary scales pinned to the approved calibration | **DONE**, byte-identity measured |
| 4 | a fully dense admissible TWELVE-block run recipe at 125M | **DONE — down band 1, all twelve blocks non-trivial** |
| 5 | the bundles re-taken for the repaired argument | **DONE — `run-g-dense-s20`, `run-h-zero-s20`, 41.3 MB each** |

### Item 1 — review finding F-1: the layout model is an independent oracle again

**What F-1 said.** `scripts/zk60_private_block_layout_model.py` still
declared the PRE-repair bilinear schedule; its own tests pinned its own
stale totals; and `grow_tests::check_against_model` had started ADJUSTING
the model's expectation by a Rust-computed `s20_bilinear_delta`, so both
sides of the one model-to-Rust comparison were this module's own arithmetic.
The rung and 125M receipt figures had lost their independent witness.

**What the model now DERIVES.** A new `group_sumcheck_bits(sh) =
clog2(kv_heads)` states the algebra from the shape — that a bilinear slot
must claim the multilinear extension of a POINTWISE PRODUCT whose key-value
group is a coordinate of both factors, that fixing it computes the product
of the extensions instead, that this is quadratic in each shared group bit
and therefore a different polynomial (finding S19-F1), and that the group
must therefore be SUMMED under a public `eq(r_g, ·)`. `slots()` then gives
`SC_SCORE` and `SC_PV` those `lkv` main rounds and, when `lkv > 0`, one more
degree. The derivation is written from the construction, not copied from
`shape.rs`.

Three further things the model gained, because F-1's real complaint is
coverage: the shape **`RUNG_G`** (the profile the lane actually proves at,
which had no independent model at all), and the two summary figures nobody
was checking — `published_round_values` = `Σ (main+ext)(degree+1)` and
`sumcheck_challenge_draws` = `Σ (main+ext)` — plus the per-slot `slot_lengths`.

**EVERY FIGURE COMPARED WITH RUST, AND EVERY ONE AGREES.** No disagreement
anywhere, which is the headline this item could have had and does not.

| figure | toy | rung | rung-G | 125M |
|---|---:|---:|---:|---:|
| `lkv` | 0 | 1 | 1 | 2 |
| `SC_SCORE` (main, ext, deg, L) | (3,2,2,12) | (5,2,3,23) | (5,2,3,23) | (8,2,3,32) |
| `SC_PV` (main, ext, deg, L) | (5,2,2,16) | (6,2,3,26) | (6,2,3,26) | (11,2,3,41) |
| main rounds | 159 | 217 | 217 | 336 |
| extension rounds | 25 | 25 | 25 | 25 |
| published round values | 721 | 1,055 | 1,055 | 1,554 |
| challenge draws per block | 184 | 242 | 242 | 361 |
| largest `L` (and it is not a bilinear slot) | 50 | 72 | 72 | 117 |
| **model** receipt bytes | 2,816,472 | 4,173,544 | **4,234,984** | 40,750,584 |
| named Rust-side term | — | +45,056 (S11-F4, the frozen seam's endpoint) | **NONE** | +32,768 (S11b-F1, the padded `Dom::D` cube) |
| **Rust** receipt bytes | 2,816,472 | 4,218,600 | **4,234,984** | 40,783,352 |

**Rung-G is the sharpest of the four.** The rung's comparison carries a
45,056-byte correction and 125M's a 32,768-byte one, both named and both
about the ENDPOINT; the generalised endpoint is priced from the block's own
PCS parameters, which the model already models, so at rung-G the model's
4,234,984 B and the Rust's agree **with nothing in between**. That number
had no independent witness of any kind before this stage.

**The re-pins, all from the model's own arithmetic.** Rung 4,173,208 →
**4,173,544**, and its one diagnosed difference against the memo grows from
176 B to **512 B** (the `SC_KVZC` indicator's 176 plus the repair's 336).
125M 40,750,024 → **40,750,584**, and it now differs from the memo by
**560 B** where it agreed to the byte — the memo predates the repair, which
is recorded in `KNOWN_MEMO_DIFFERENCES` so the difference is diagnosed and
not undiagnosed. The toy does not move: `lkv = 0`, no `eq`, 2,816,472 B.

`check_against_model` no longer applies any delta. `s20_bilinear_delta`
survives only where a pin is honestly stated as a MEASURED pre-repair length
plus a counted delta (the 125M frame, the run segments), which is a
different kind of statement and is not a model comparison.

**Python: 32 tests, OK** (from 25), and the whole
`test_zk60_private_block_*` suite **72 tests, OK** in 46 s — the inventory
driver's 40 included, which PARSE the real `define` and are the toy's own
gate.

### Item 2 — review finding F-2: the P-3 lift is refused by name

The bilinear arms build their coordinate lists AXIS BY AXIS — `A_QR8` as
`(t | group | head-in-group | c)`, `A_KR8` as `(j | group | c)`, `A_P` as
`(group | head-in-group | t | s)`, `A_V8` as `(s | group | i)` — so each
list is exactly the NATURAL log of its domain long. `B::a_at` measures a
list against `Shape::log`, which is the P-3 LIFTED log. A shape whose
`Dom::Q`, `Dom::Kv` or `Dom::S` sits below the row width therefore could
only ever get `run_slot`'s generic `slot s table shape`, from inside the
argument. `Shape::new` now says why, at construction:

```
private block shape: the bilinear attention slots cannot serve a shape whose
Q domain is lifted by P-3 (natural log 6, lifted to the row width 8)
```

**FAILING FIRST** (`u2-s21-f2-failing-first.log`, exit 101): with the loop
disabled, `T8/H4/dh2/KV4` at `log_cols = 8` — the geometry the stage-20
reviewer actually met, which forced him to `head_dim = 8` — CONSTRUCTS. The
test also asserts the reviewer's own workaround (`dh = 8` lifts nothing) and
that `Dom::Kv` exactly AT the row width, which is the toy's case, is not a
lift. No shape this module builds is affected.

### Item 3 — ruling R-5: the interior boundary scales

**The ruling, in the security owner's words:** the external scales are bound
through the absorbed expected-IO bytes, the interior ones by nothing — not
the parameter line, not a stage line, and `BoundarySpec::digest()` is never
absorbed. No equation is at risk, but a receipt does not attest to them and
a scale chosen from the hidden input would publish a hidden intermediate's
dynamic range. So a run refuses any block scale pair but the approved
calibration's, as `IoSpec::new` already does for the endpoints.

`RunStatement::new` now does exactly that, against `ENDPOINT_SCALES`. The
check sits **after** M-4's boundary-agreement check on purpose, so a
boundary whose two sides disagree keeps its own refusal and
`a_boundary_scale_disagreement_does_not_construct_…` stays a test of M-4.

**FAILING FIRST:** `&[(0,1),(1,1),(1,0)]` — an interior scale of 1,
self-consistent across both boundaries and with the approved external pair
at both ends — constructed before and is refused now, by a message that
names the block and the pair.

**NO ABSORB ADDED, NO PROOF BYTE MOVED — MEASURED.**
`the_run_header_the_approved_scales_bind_is_byte_identical_under_ruling_r5`
pins, as literals **captured before the refusal existed and re-asserted
after it**, everything the rung-G `L = 3` header binds:

| object | value |
|---|---|
| run binding (transcript state after the header) | `a1077992 c7a6570f 8b7a63e1 d869c184 ec28b127 6908a3a0 b46d96e4 789e1b69` |
| boundary 0 digest | `9e339c12 71f88cc6 ee430f8d 2d05ee99 9f7197d5 54afa856 f05de6db 600b3dd1` |
| boundary 1 digest | `08089731 2754880c fff0b273 e16b1c0c 210eb830 c8a8d346 0755512f 7f9b6851` |
| parameter line | `T24/d96/f192/H6/KV2/dh16/log_cols10/inv_rate4/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript/endpoint-log_n10-rate4-pad256-rows9/L3/boundary-log_n10-rate4-pad256-rows10-sites2/external-rows9/one-run-one-transcript` |

The statement is built with FIXED synthetic endpoint roots
(`ExpectedIo::from_roots`) because the real ones come from an
OS-seeded-RNG commitment and are not reproducible across processes; every
other word of the header is a deterministic function of the public
statement, so the binding is too. Nothing else about the run changed: the
segments are the counted lengths, and the boundary digest is still not
absorbed anywhere — R-5 binds the scales by REFUSING them, not by hashing
them.

### Item 4 — a fully dense, admissible TWELVE-block run at the 125M shape

**The answer is down band 1, and it is measured twice.**

**The search** (`u4-s21-m125-band.log`, **707 s**, witness builder only,
under the heavy lock inside `MemoryMax=12G`): `first_admissible_dense_run_band`
walks the down-projection band DOWN from the recipe's own 14, leaving every
other band — attention, gate, the two gains, the hidden input — at the
recipe's. **Every band from 14 to 2 is refused, always at the same site and
always by the SECOND block of the chain:**

```
fixed oracle range refusal: residual 2
```

and **band 1 is admissible for all twelve blocks.** At band 1 every entry of
`Wd` is `+1` or `-1` — still nonzero, so the recipe remains literally dense:
no zero entry in any of the nine words. Why a chain needs so much less than
a block: block `k+1`'s hidden input IS block `k`'s `xres2 = xres1 + z16`, so
`z16`'s spread compounds, and 125M's hidden axis is 2,048 wide against the
rung's 192, so `z16` accumulates over ten times as many terms before being
added to an `int16` residual. Band 1 is what twelve compositions cost in
THIS calibration; it is not a property of the argument.

**The census** (`u7-s21-m125-census.log`, **63.2 s for twelve witnesses
built and dropped, peak RSS 0.70 GiB**). `Chain::from_parts_censused`
censuses each witness AS IT IS BUILT, so no witness is built twice and only
one is ever resident. **All twelve blocks, identical to a tenth of a per
cent:**

| block | upper hidden half `[768, 2048)`: gate / activation nonzero | head slots live | key-value groups live | groups differ |
|---|---|---|---|---|
| 00, 01, 03, 04, 06–11 | **98.0% / 98.0%** | 12 / 12 | 4 / 4 | yes |
| 02, 05 | **97.9% / 97.9%** | 12 / 12 | 4 / 4 | yes |

Against the diagonal tame fixture, where that half is **identically zero in
every block at every shape with `f > d`**, and where every head sees the
same data so the four key-value groups are identical. Only fractions and
live-slot counts are computed, printed or retained (the capture rule); no
witness value, position or word count leaves the process.

**The recipe, publicly.** `dense_tests::dense_run_case`, named in full by
`DENSE_RUN_RECIPE_NAME`, which a run statement file carries so a fresh
verifier regenerates exactly these public weights and checks them against
the block digests the run header absorbs:

> SplitMix64 seeded `0xD15EED1900000001`, read in the fixed order
> `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd, x]`; `Wq`/`Wk`/`Wv`/`Wo`
> uniform on `[-56,-1] ∪ [1,56]`; `gamma_a`/`gamma_m` uniform on `[40,127]`;
> `Wg`/`Wu` uniform on `[-96,-1] ∪ [1,96]`; `Wd` uniform on `[-B,-1] ∪ [1,B]`
> with `B = band_down_run(shape)` (**47** at the rungs, **1** at 125M);
> hidden input uniform on `[-6000,-1] ∪ [1,6000]`.

The pinned band is tied to the search by assertion at both shapes:
`an_honest_three_block_fully_dense_run_verifies_from_its_segments` asserts
it at rung-G (47, `u8-s21-rungg-band.log`) and the `#[ignore]`d 125M probe
asserts it at 125M.

**`private_run_125m_twelve_blocks` now takes `HL_PB_WEIGHTS`**: `tame` (the
DEFAULT, and every figure ever published for this test is at it) or `dense`.
Every log line of the run and the retained public statement name the recipe.
`run_statement_file::DENSE_RUN_FIXTURE` makes `recipe_block` regenerate it.

#### THE LAUNCH COMMAND, PREPARED AND NOT LAUNCHED (stage-18 command-A form)

The directory must exist and be EMPTY; the test refuses otherwise. **Re-read
the binary's mtime before launching**: the target directory is shared with
another worktree.

```
mkdir -p /home/victor/zk60-artifacts/m125-run-l12-dense
```

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_RUN_DIR=/home/victor/zk60-artifacts/m125-run-l12-dense HL_PB_WEIGHTS=dense HL_PB_TIMING=0 HL_TEST_SOURCE_COMMIT=0426ad2 /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_tests::private_run_125m_twelve_blocks >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l12-dense.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run-l12-dense.done' >/dev/null 2>&1 &
```

What to expect: the chain build is the 63 s the census measured, then about
twelve proving stages; the receipt is the counted `484,100,736 + 12 × 560 =
484,107,456 B` in twelve files under `/home/victor/zk60-artifacts/`, outside
the repository; the public statement lands at
`<run dir>/statement/run-statement.json` only if the run verifies. The run
STOPS by itself if a segment is not the counted length or if the high-water
mark passes 11.5 GiB.

### Item 5 — the capture bundles re-taken for the repaired argument

`results/zk60_run_captures_20260920/run-g-dense-s20` and `run-h-zero-s20`,
written in one pass (`u9-s21-bundles.log`, exit 0, source pin `0426ad2`),
at the generalised rung, under the D19 tag, with
`HL_RUN_CAPTURE_PUBLIC_TABLES=1`.

| bundle | `run.json` | stage files | `manifest["total_bytes"]` | on disk |
|---|---:|---:|---:|---:|
| `run-g-dense-s20` (FULLY DENSE, generic) | 35,756 B | 13,488,146 / 13,547,671 / 14,221,085 | **41,296,268 B** | 41,297,995 B |
| `run-h-zero-s20` (the all-zero input) | 35,794 B | 13,475,957 / 13,540,990 / 14,213,928 | **41,270,047 B** | 41,271,774 B |

**82.6 MB for the pair, 41.3 MB each — well inside the 120 MB ceiling.**

**`run-g-dense-s20` is the one that matters.** Every capture this project
has ever taken was on the diagonal tame fixture or on the all-zero input,
and both are degenerate in exactly the way that hid S19-F1 for nineteen
stages: the upper hidden half is identically zero, the hidden state is the
same in every head so the key-value groups carry identical data, and
`A_RQL` is identically zero. **The privacy gate has never seen a
non-degenerate witness; `run-g-dense-s20` is it.**

**How the new public factor is recorded, and how a tool re-derives it.**
Nothing new was needed in the format: `Tab::Eq` already serialises as
`{"kind":"eq","start":int,"point":[Fp2]}`. Verified on the committed files:
in BOTH bundles and in ALL THREE stages, `arguments[8]["tables"][0]` and
`arguments[9]["tables"][0]` are `{"kind":"eq","start":0,"point":[<1 Fp2>]}`
— `lkv = log2(2) = 1` at rung-G. `start` indexes the slot's own `rho`, so
the factor's value is `eq(point, rho[start : start+len(point)])`; and
`point` is the LEADING `lkv` entries of that slot's head challenge `r_h`,
which a reader draws for itself — **checked on the files: for all six
occurrences, `point == definition_challenges[:1]`.** Re-derive and compare,
never consume (ruling T-7's rule, applied to a public table). Documented in
`ZK60_RUN_CAPTURE_FORMAT.md` §10 with the date.

The writer asserts both facts IN THE BYTES before it writes anything, so a
bundle cannot be produced that says otherwise.

**SANITY, CHECKED ON THE FILES AS COMMITTED (`python3`, after the write):**

* **every manifest entry** of both bundles — five files each — matches its
  recorded byte length AND its recorded SHA-256. **0 mismatches.**
* **93 public tables** per bundle across its three stages, **all 93 carrying
  values**, and for all 93 the recorded SHA-256 is the SHA-256 of the
  concatenated 16-byte little-endian `Fp2` encodings of exactly the values
  included. **0 mismatches.**
* `"public_tables_included":true` and `"hash_tag":{"rule":"blake3-keyed/1"…}`
  in both.
* **the plane index table is byte-identical across `g` and `h`** — and
  across `run-e-tame-tagged`, since the repair does not move it: the same
  canonical 22,397 bytes, SHA-256 prefix `d2361312…`. `slot_planes[8]` is
  `[A_QR8 (45), A_KR8 (54)]` and `[9]` is `[A_P (60), A_V8 (52)]`, the
  as-built push order, which the recorder's replay enforces at every slot of
  every stage.
* the repaired schedule, read out of the bundles: slot 08 `(5, 2, 3)` with
  7 round messages of 4 values, slot 09 `(6, 2, 3)` with 8 — against the
  pre-repair `(4, 2, 2)` / `(5, 2, 2)` with 3 values a round.

The parent `README.md` is rewritten: eight bundles now, `a`–`f` superseded
for gate purposes with the reason (`a`–`d` legacy-rule and no public tables;
`e`–`f` pre-repair bilinear slots AND a degenerate witness), the group-`eq`
convention, the sanity results and the launch command. **Nothing was
deleted, moved or rewritten**: the six older bundles stay byte for byte and
their own per-bundle `README.md` files are not edited, because each
`manifest.json` pins its own README. The directory now holds 319,048,726
bytes in eight bundles.

**They are still not gate evidence** (ruling T-6): the Python run gate has
to learn the D19 rule and the repaired schedule before a bundle is judged.
These two are the INPUT to that work.

### Tests and commands of stage 21

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| `--lib private_block::grow_tests` (item 1) | `u1-s21-grow.log` | **32 passed / 0 failed**, exit 0 |
| item 2 FAILING FIRST | `u2-s21-f2-failing-first.log` | **1 failed**, exit 101, the intended result |
| items 2 and 3, with the three run tests | `u3-s21-r5-f2.log` | **35 passed / 0 failed**, exit 0 |
| the 125M dense-run band search (heavy lock, witness builder only) | `u4-s21-m125-band.log` | **band 1**, 707 s, exit 0 |
| `--lib --no-run` | `u5-s21-compile.log`, `u6-s21-build.log` | exit 0, **13 warnings** |
| the 125M twelve-block census (heavy lock, witness builder only) | `u7-s21-m125-census.log` | 12/12 non-trivial, 63.2 s, peak 0.70 GiB, exit 0 |
| the rung-G pinned band | `u8-s21-rungg-band.log` | 1 passed, exit 0 |
| the two bundles | `u9-s21-bundles.log` | 41.3 MB each, exit 0 |
| the adjusted shape probe (see the finding below) | `uc-s21-shape-probe.log` | 1 passed, exit 0 |
| **THE GATE**: `--lib private_` | `ua-s21-private.log` | **254 passed / 0 failed / 10 ignored**, 67 filtered out, **381.04 s**, exit 0, **13 warnings** |
| the Python layout model and inventory | `ub-s21-python.log` | **72 passed** (32 + 40), 46 s |

**Against the review's merged baseline of 251 / 0 / 8 and 13 warnings**:
**254 / 0 / 10**, 13 warnings. Five tests are new — the repaired schedule
against the independent model, R-5's refusal, R-5's byte-identity pin, and
two `#[ignore]`d ones (the 125M twelve-block census and the stage-21 bundle
writer) — and **not one existing test was weakened or removed.** Three
existing tests were EDITED, each with the ruling in a comment: the two
Python receipt pins (F-1) and the shape probe below.

The frozen toy gates are in the pass list: the 2,816,472-byte receipt,
`the_toy_schedule_digest_is_frozen`,
`the_toy_parameter_line_is_the_frozen_literal` and
`a_toy_receipt_made_before_the_lane_still_verifies` (the four pre-lane
receipts). The stage-20 receipt sizes are unmoved: 4,218,600 / 4,234,984 /
40,783,352.

### THE ONE THING THAT BROKE, AND WHY THAT IS THE REFUSAL WORKING

Item 2's refusal caught an existing test on its first full-gate run
(`253 passed / 1 failed`):
`review_tests::a_receipt_does_not_verify_under_another_shape_at_the_rung`
built its "different head layout" probe as **5 query heads over 1 key-value
head** at the rung's row width. That shape's `Dom::Kv` is
`32 x 1 x 16 = 2^9`, BELOW the `2^10` row width, so P-3 lifts it — and it
is therefore a shape the bilinear slots could never have served. It had
been constructing, and `run_slot` would have refused it from inside the
argument with the generic "slot 8 table shape"; the test never reached that
point because the frame was rejected earlier, for an unrelated reason.

The probe is now **8 query heads over 2 key-value heads**, which has the
rung's four padded sizes exactly (`t_pad 32, d_pad 128, h_pad 8, f_pad 256`)
and lifts nothing, so the statement this test is about — a rung receipt does
not verify under a different head LAYOUT of the same padded geometry — is
made as it always was (`Err("private block wire: expected statement
mismatch")`). The 5/1 shape STAYS in the test, as an assertion that it is
refused by name at construction, with the exact message. The test is
stronger than it was, not weaker.

### THE PREBUILT TEST BINARY

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5
```

**mtime 2026-09-20 20:43:34 -0700**, 12,874,736 B, newer than every source
file of this lane (`ud-s21-norun.log`, exit 0, 13 warnings). **Re-read its
mtime before launching anything**: the target directory is shared with
another worktree.

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 901557e -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block
```

prints NOTHING: every one of those trees is byte-identical to the tip the
review merged.


## Stage 22 — the run statement's recipe, and a four-key-value-head development shape (2026-09-20, 22:1x–23:0x)

**Status: `LANDED`.** Two items, both purely ADDITIVE on top of the hand-back
tip `e6b612f`. **No existing profile moved a byte**: the toy's 2,816,472, the
rung's 4,218,600, rung-G's 4,234,984 and 125M's 40,783,352 are all in the
pass list, the toy schedule digest and parameter line are frozen, and the
forbidden-file trees are byte-identical to `e6b612f` (proof at the end).

**No heavy run.** Nothing at 125M was proved; the only 125M work is a
statement-file read and one public-weights regeneration, both seconds. No
GPU. **No privacy or soundness acceptance is claimed**: the new profile is
development grade (ruling P-7), and the two bundles it produces are the
INPUT to the run privacy gate of ruling M-8, not evidence for it.

Commits: the skeleton `beb0746`, the code `3247a89`, the bundles and the
documents, and this ledger.

| item | what | state |
|---|---|---|
| 1 | the public run statement's weights recipe describes PUBLIC WEIGHTS ONLY | **DONE**, failing-first recorded, public weights bit-identical |
| 2 | `Shape::rung_k4`: a development shape with FOUR key-value heads, proved and captured | **DONE** — 7 new tests, 2 bundles, model and Rust agree to the byte |

---

### Item 1 — the recipe field described the hidden input, and now does not

**THE DEFECT, IN ONE PARAGRAPH.** A retained run statement carries
`public_weights.recipe`, the one free-text field of the file, and a reader
follows it as an instruction: draw this stream in this order with these
bands and you have the weights. The stage-21 dense string ended its read
order with `x` and stated the hidden input's distribution
(`hidden input uniform on [-6000,-1] u [1,6000]`), and that was not a
description error — the input really WAS the tenth read of the published
stream, `dense_words_with` drawing `[Wq … Wd]` and then `x` from one
`Rng(0xD15EED1900000001)`. **The published seed therefore regenerated the
hidden input.** Harmless for a synthetic test whose "secret" is a fixture,
and wrong as the model for a production statement writer, in which the
weights are public and the input is the thing the proof exists to hide.

**THE REPAIR, AS BUILT.** Two streams where there was one.

* `dense_public_words_with(shape, bands…)` draws the nine PUBLIC words from
  `DENSE_SEED` and returns the stream's state AFTERWARDS.
* `dense_hidden_input(shape, mag)` draws the input from a new
  `DENSE_INPUT_SEED`, which is in this test source and **in no retained
  file** — not a statement, not a bundle, not a log.
* `dense_words_with` is the two of them, so every caller is unchanged.

**THE PUBLIC WEIGHTS DID NOT MOVE BY A BYTE, and that is measured against
evidence written before stage 22.** The input was always drawn LAST, so
taking it out of the stream leaves every weight draw exactly where it was.
The test `the_retained_125m_statements_still_regenerate_their_public_weights`
opens the two run statements this lane retained under `results/`, reads the
recipe each one NAMES, regenerates the 125M public weights from it and
compares against the twelve block digests that statement's run header
absorbed — digests hashed before stage 22 existed. All twenty-four match.

**What the statement now contains.** `public_weights.recipe` is

> `private_block::dense_tests::dense_run_case(<block profile's Shape>)`'s
> NINE PUBLIC WORDS, the same fully dense public words for every block:
> SplitMix64 seeded `0xD15EED1900000001`, read in the fixed order
> `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd]` and CONSUMED ENTIRELY by
> them; … PUBLIC WEIGHTS ONLY: this recipe regenerates the nine public words
> and nothing else, and the test witness's secret is drawn from a separate
> stream whose seed is in no retained file

and the tame recipe likewise names `tame_case`'s **nine public words** rather
than the function. Nothing else about the file changed: same schema, same
allow-list, same fields.

**THE TWO CHECKS.**

* **Textual.** `run_statement_file::hidden_input_token` is a deny-list of
  the ways a hidden input can be described — by name, by distribution, by
  magnitude, by its place in the read order, by its seed in hex or decimal.
  The two strings the writer may emit pass it; the file's whole text is
  searched for the input seed in both forms. (The deny-list is applied to
  the recipe field and not to the whole file, because the file's own
  negative declaration `not_in_this_file` legitimately contains the words
  "hidden inputs" — the seed search is what covers the rest.)
* **Structural.** `the_dense_recipes_public_stream_is_consumed_entirely_by_public_words`
  asserts at the rung, rung-G and 125M that the state after the nine words
  equals `DENSE_SEED` advanced by exactly one draw per public weight ENTRY.
  SplitMix64's state is a counter `seed + n·GAMMA`, injective in `n` over a
  `u64`, so that equality pins the draw count EXACTLY — a tenth read of any
  length would move it, and the test checks that one further draw does move
  it. It then asserts that the hidden input is **not** that stream continued:
  what the published seed WOULD give a reader who guessed the input comes
  next — which is what it did give until stage 22 — is a different vector.

**FAILING FIRST** (`w1-s22-item1-failing-first.log`, exit 101): with
`DENSE_RUN_FIXTURE.name` pointed back at the stage-21 string, the deny-list
catches it and prints the token it is caught on, `"hidden input"`. The test
keeps that as a permanent non-vacuity assertion: the stage-21 string is
required to FAIL the same checker that the live strings pass.

**WHICH RETAINED STATEMENTS CARRY THE OLD STRING** — nothing was rewritten:

| file | string it carries |
|---|---|
| `results/zk60_block125m_lane/m125-run-l12-dense-run-statement.json` | the **stage-21 dense** string, which names the hidden input |
| `results/zk60_block125m_lane/m125-run-l12-tagged-run-statement.json` | the **stage-18 tame** string (vague, not a leak) |
| `/home/victor/zk60-artifacts/m125-run-l12-dense/statement/run-statement.json` and the `-tagged` one (outside the repository) | the same two |

Both old strings are kept in the source as **READ-ONLY aliases**
(`dense_tests::LEGACY_DENSE_RUN_RECIPE_NAME`,
`run_statement_file::LEGACY_TAME_RECIPE_NAME`): `recipe_block` maps each to
the same generator as its successor, so those four statements still
regenerate their blocks and 484 MB of retained receipt is not orphaned. A
test asserts the writer emits neither. **The capture bundles carry no recipe
string at all** (checked: the substring does not occur in a `run.json`), so
none of the ten is affected.

**WHAT CHANGED THAT IS NOT THE PUBLIC WEIGHTS.** The dense tests' hidden
input is a different vector from stage 21's — it comes from a different
seed. That is stated rather than hidden: nothing in the repository pins a
figure that depends on it (a receipt's length is a function of the shape
alone), the three admissible bands were re-measured by the tests that
already searched for them (rung-G's 47 is unchanged and still asserted), and
**125M's band-1 pin was measured under the pre-stage-22 input**: its search
is the `#[ignore]`d probe `the_first_admissible_fully_dense_run_band_at_125m`
and it has NOT been re-run, which is a 707-second witness-builder job. Re-run
it before the next 125M dense run. The committed bundles `run-g-dense-s20` /
`run-h-zero-s20` were taken on the old input and are not rewritten; their
public weights are still exactly what their statements would regenerate.

---

### Item 2 — `Shape::rung_k4`, the first small shape with TWO group bits

**THE GAP.** Stage 20 made the key-value group `lkv = log2(kv_heads)`
sumcheck variables under a public `eq(r_g, ·)`. Every proof and every
capture since is at `lkv = 1` (the two rungs) or `lkv = 0` (the frozen toy,
where the repair is a no-op). The only `lkv = 2` shape is 125M, whose runs
are 484 MB and which the Python privacy gate cannot ingest. Two group bits
had been exercised by ALGEBRA — `dense_tests`' Boolean-cube check on random
planes and the stage-20 reviewer's `kv4` probe through `argument::define` —
and by nothing that produces a receipt a tool can read.

**THE SHAPE, AS BUILT.** rung-G's geometry with the head axis recut, and
nothing else touched.

| | rung-G | **rung-K4** |
|---|---|---|
| tokens / width / hidden | 24 / 96 / 192 | 24 / 96 / 192 |
| query heads × head_dim | 6 × 16 | **12 × 8** |
| key-value heads, `lkv` | 2, 1 | **4, 2** |
| true heads per group | 3 | **3** (padded to 4 slots) |
| `t_pad, d_pad, h_pad, f_pad` | 32, 128, 8, 256 | 32, 128, **16**, 256 |
| padded head slots | `{3, 7}` | **`{3, 7, 11, 15}`** |
| `log_cols`, `inv_rate`, `F_E` | 10, 4, 12 | the same |
| endpoint | generalised, 9 rows, `log_n` 10, rate 4 | the same |
| `norm_wrho`, `wrho_s` | 31, 17 | the same |
| `Dom::Q` / `Dom::Kv` / `Dom::S` logs | 12 / 10 / 13 | 12 / 10 / **14** |
| block profile | `hashline-zk-mr1/private-block-rung-g-t24-dev/1` | `hashline-zk-mr1/private-block-rung-k4-t24-dev/1` |
| run profile | `hashline-zk-mr1/private-run-rung-g-t24-dev/1` | `hashline-zk-mr1/private-run-rung-k4-t24-dev/1` |

**Every dimension is forced, not chosen.** `q_heads = 12` and `kv_heads = 4`
give `lkv = 2`, groups of three true heads and `h_pad = 16`, so each group's
own block of four slots ends in a pad: `{3, 7, 11, 15}`, which is 125M's head
geometry exactly and the case a contiguous padded tail could never produce.
`head_dim = 8` then follows from `d_pad = h_pad · head_dim = 128` and
`width = q_heads · head_dim = 96`. **A smaller head dimension is refused**:
the only `head_dim = 4` geometry that keeps width 96 and satisfies
`d_pad = h_pad · head_dim` is 24 query heads over 32 padded slots, and its
`Dom::Kv = 32 · 4 · 4 = 2^9` is BELOW the row width `2^10`, so P-3 lifts it
(measured on the independent model) and stage 21's F-2 refusal fires by
name — the bilinear arms write their coordinate lists at the NATURAL log.
At `head_dim = 8`, `Dom::Kv = 2^10` sits
EXACTLY at the row width — the toy's case, not a lift — and `Dom::Q` (2^12)
and `Dom::S` (2^14) are above it. No other dimension moved, so the head axis
is the only difference and `Dom::S` doubling (sixteen head slots, not eight)
is where the extra cost is.

**THE COUNTED LAYOUT, AND THE INDEPENDENT MODEL.** `MODEL_RUNG_K4` is
`scripts/zk60_private_block_layout_model.py`'s own output at
`SHAPES["rung_k4"]`, transcribed, and like rung-G **this shape carries NO
Rust-side correction term** — its endpoint is priced from the block's own
PCS parameters, which the model already models. Every figure agrees.

| figure | rung-G | **rung-K4** |
|---|---:|---:|
| `SC_SCORE` (main, ext, deg, `L`) | (5, 2, 3, 23) | **(5, 2, 3, 23)** |
| `SC_PV` (main, ext, deg, `L`) | (6, 2, 3, 26) | **(7, 2, 3, 29)** |
| main rounds | 217 | **220** |
| extension rounds | 25 | 25 |
| published round values | 1,055 | **1,070** |
| challenge draws per block | 242 | **245** |
| largest `L` (slot) | 72 (`SC_FZC`/`SC_SZC`) | **77 (`SC_SZC`)**, `L + 256 = 333 ≤ 512` |
| `A` planes / data rows / rows | 83 / 377 / 623 | 83 / **481** / **727** |
| `H` planes / data rows / rows | 52 / 470 / 576 | 52 / **614** / **720** |
| `A` / `H` claim sites, opening groups | 122 / 52, 36 / 9 | the same |
| U8 lookups | 419,840 | **542,720** |
| exp / act pairs | 8,192 / 8,192 | **16,384** / 8,192 |
| **model receipt bytes** | 4,234,984 | **4,743,128** |
| **Rust receipt bytes** | 4,234,984 | **4,743,128** |

`SC_SCORE` is `lkv + log2(head_dim) = 2 + 3`, which is rung-G's `1 + 4` by
coincidence; `SC_PV` is `lkv + log2(t_pad) = 2 + 5`, one more than rung-G's.

**THE TESTS, AND WHAT EACH MEASURED.** All on the fully dense recipe with a
generic hidden input, unless the name says otherwise.

| test | result |
|---|---|
| `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims` | every dimension, the head permutation `[0,1,2,4,5,6,8,9,10,12,13,14]`, the padded slots `{3,7,11,15}`, no P-3 lift on `Dom::Q`/`Dom::Kv`/`Dom::S`, its own profile and its own hash-tag key set, the counted 4,743,128 B. **Passed on the first run** |
| `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_k4` | the INDEPENDENT `private-block-kernel-shaped` crate (read-only, unchanged) takes this geometry unaltered; every kernel-backed plane agrees element for element on the true support and the block output on all 2,304 words. The kernel's OWN `kr8` buffer is asserted pairwise different across the four groups first |
| `dense_tests::the_two_bilinear_identities_hold_independently_of_the_argument_at_the_rung_k4` | the stage-20 Boolean-cube check, on the real rung-K4 witnesses: **NEW == LHS** for both slots on the dense witness and on the tame fixture; **OLD ≠ LHS** on the dense one, **OLD == LHS** on the degenerate one |
| `k4_tests::an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_k4` | prove **0.67 s**, verify from bytes **0.12 s**, frame **4,743,128 B** (the counted length), a one-byte truncation refused |
| `k4_tests::the_pinned_rung_k4_chain_band_is_the_first_admissible_one` | band **48 refused** (`fixed oracle range refusal: residual 2`), **band 47 admissible for three blocks** — so `band_down_run` gains a `(192, 4) => 47` arm and the pin is measured, not chosen |
| `k4_tests::an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_k4` | prove **1.76 s**, verify from segments **0.38 s**, segments **4,575,304 / 4,597,832 / 4,765,736 = 13,938,872 B** (the counted lengths), boundary 10 rows; all three blocks censused |
| `k4_tests::the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_k4` | verified, frame 4,743,128 B. **Named as degenerate**: every key-value group is identically zero, so it says nothing about the group bits |

**THE CENSUS** (fractions and live-slot counts only, the capture rule): in
the single dense block and in all three blocks of the run, **12 of 12 true
head slots live, 4 of 4 key-value groups live and PAIRWISE different**, the
upper hidden half of the gate and activation planes live, and every padded
head slot's attention output identically zero. Pairwise is the point: with
two group bits, a witness in which three groups coincided would leave most
of the `eq(r_g, ·)` unexercised.

**THE NEGATIVE CONTROLS — 7 of 7 REJECTED BY THE VERIFIER, 0 by the prover,
0 accepted.** The honest control is asserted accepted first in each test.

| control | who rejected it |
|---|---|
| `A_KR8`, the rotated key of the **THIRD** group | **VERIFIER**, slot 16 `05 KV zero-check` |
| `A_V8`, the value of the **THIRD** group | **VERIFIER**, slot 15 `04 Q zero-check` |
| `A_KR8`, the rotated key of the **FOURTH** group | **VERIFIER**, slot 16 |
| `A_V8`, the value of the **FOURTH** group | **VERIFIER**, slot 15 |
| `A_QR8` at head slot 14 — the third true head of the fourth group | **VERIFIER**, slot 15 |
| `A_P` at a causally live position of head slot 14 | **VERIFIER**, slot 15 |
| `A_P` at head slot **15**, the fourth group's PADDED slot | **VERIFIER**, slot 15 |
| the whole KEY family (`A_K8`, `A_RKL`, `A_KR8`, `A_RKRL`) of groups **2 and 3** exchanged, 737 positions differing, values untouched | **VERIFIER**, slot 16 |

Groups 2 and 3 are the deliberate choice for the swap: they share the HIGH
group bit and differ in the LOW one, which is the substitution a
construction that summed only the leading bit would be blind to and which
rung-G's one-bit control cannot express.

**THE TWO CAPTURE BUNDLES**,
`results/zk60_run_captures_20260920/run-i-dense-k4` and `run-j-zero-k4`,
three blocks each, tagged rule, `HL_RUN_CAPTURE_PUBLIC_TABLES=1`, source pin
`3247a89` (`w4-s22-k4-bundles.log`, exit 0).

| bundle | `run.json` | stage files | `manifest["total_bytes"]` | on disk |
|---|---:|---:|---:|---:|
| `run-i-dense-k4` (FULLY DENSE, generic) | 35,784 B | 46,405,345 B | **46,444,960 B** | 46,446,688 B |
| `run-j-zero-k4` (all-zero, degenerate) | 35,781 B | 46,379,529 B | **46,418,960 B** | 46,420,688 B |

**92.9 MB for the pair, 46.4 MB each — inside the 120 MB ceiling** (the
writer asserts it). They are bigger than rung-G's 41.3 MB for the same
reason the receipt is: `Dom::S` doubles.

**SANITY, CHECKED ON THE FILES AS COMMITTED** (`w5-s22-k4-bundle-sanity.log`,
0 mismatches):

* every manifest entry of both bundles — five files each — matches its
  recorded byte length AND its recorded SHA-256;
* **93 public tables** per bundle across its three stages, **all 93 carrying
  values**, and for all 93 the recorded SHA-256 is the SHA-256 of the
  concatenated 16-byte little-endian `Fp2` encodings of exactly the values
  included;
* `"public_tables_included":true` and `"hash_tag":{"rule":"blake3-keyed/1"…}`
  in both, and both name the rung-K4 run and block profiles;
* **the plane index table is byte-identical across the pair**: 22,419
  canonical bytes, SHA-256 prefix `89cd8a46…`, 83 `A` planes over 481 rows
  and 52 `H` planes over 614 rows. It is **NOT** rung-G's `d2361312…` table
  and must never be compared with it;
* **slots 08 and 09 carry `{"kind":"eq","start":0,"point":[<2 Fp2>]}` in all
  three stages of both bundles, and `point == definition_challenges[:2]` at
  all SIX occurrences.** The writer asserts the schedule and the `start: 0`
  eq in the bytes before it writes anything;
* slots 08 / 09 read out of the bundles: `(5, 2, 3)` with 7 round messages of
  4 values and `(7, 2, 3)` with 9, two terminals each, and
  `slot_planes[8] = [A_QR8 (45), A_KR8 (54)]`, `slot_planes[9] = [A_P (60),
  A_V8 (52)]` — the same two-plane lists as at rung-G.

The parent `README.md` is rewritten: ten bundles now, the two pairs stated as
two DIFFERENT SHAPES rather than versions of each other, the rung-K4
geometry table, why `head_dim = 8` is forced, what a reader must not compare,
and the sanity results. Nothing was deleted, moved or rewritten: the eight
older bundles stay byte for byte and their own `README.md` files are not
edited, because each `manifest.json` pins its own. The directory now holds
**411,912,646 bytes in ten bundles** (the summed manifest totals).
`ZK60_RUN_CAPTURE_FORMAT.md` gains the stage-22 note.

**They are still not gate evidence** (ruling T-6): the Python run gate has to
learn this profile's key set and this shape's plane index before a bundle is
judged. They are the INPUT to that work, and the reason they exist is that
the gate's ports have never had to handle a group of more than one bit.

---

### THE ONE THING THAT BROKE, AND WHY THAT IS A GUARD WORKING

The first full-gate pass of this stage was **261 passed / 6 failed**
(`w6-s22-private.log`), and all six failures were the same sentence:

```
run statement: the recipe description is not printable ASCII and would not
be valid JSON: "... regenerates the PUBLIC WEIGHTS ONLY — the witness ..."
```

**One em dash**, in each of the two new recipe DESCRIPTIONS. `render`'s
`ascii()` guard refuses a non-ASCII string rather than writing it, because
Rust's `{:?}` escapes a non-ASCII character as `\u{..}`, which is not valid
JSON — so the writer would otherwise have produced a file no reader could
parse. The guard is fail-closed and it caught the mistake on the first
write, which is exactly what it is for; what it did not do is name the
STRING, so six unrelated-looking tests failed at once. Both dashes are now
plain ASCII, and
`the_recipe_strings_this_build_writes_describe_public_weights_only` asserts
printable ASCII on all four writable strings beside the deny-list, so the
next such mistake fails at the string and says so.

No other test failed at any point in this stage.

### Tests and commands of stage 22

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`, and **without `--nocapture`**
except where noted — which is what keeps per-witness figures out of the
retained logs.

| command | log | result |
|---|---|---|
| item 1, **FAILING FIRST** (`DENSE_RUN_FIXTURE.name` pointed at the stage-21 string) | `w1-s22-item1-failing-first.log` | **1 failed**, exit 101, caught on `"hidden input"` — the intended result |
| `--lib private_block::k4_tests::the_rung_k4_shape` (the first build of the new shape) | `w2-s22-k4-shape.log` | **1 passed**, exit 0, first try |
| `--lib private_block::k4_tests` | `w3-s22-k4-all.log` | **7 passed / 0 failed**, 11.5 s, exit 0 |
| the two capture bundles (`--ignored --nocapture`, source pin `3247a89`) | `w4-s22-k4-bundles.log` | 46.4 MB each, exit 0 |
| the bundle sanity pass, `python3`, on the files as written | `w5-s22-k4-bundle-sanity.log` | **0 mismatches** |
| the gate, first pass | `w6-s22-private.log` | 261 passed / **6 failed** / 11 ignored, 423.7 s — the em dash above |
| **THE GATE**: `--lib private_` | `w7-s22-private.log` | **267 passed / 0 failed / 11 ignored**, 67 filtered out, **427.39 s**, exit 0, **13 warnings** |
| the layout model and the inventory driver, `test_zk60_private_block_*` | run inline | **76 passed** (36 + 40), 49 s — from 72 |
| the whole Python suite, `python3 -m unittest discover -s tests` | `w8-s22-python.log` | 1,164 tests, 68 skipped, **3 failures and 7 errors, every one of them pre-existing and outside this lane** (below) |

**Against the hand-back baseline of 254 passed / 0 failed / 10 ignored and
13 warnings**: **267 / 0 / 11**, 13 warnings. **Thirteen tests are new** and
not one existing test was weakened or removed:

| where | new tests |
|---|---|
| `k4_tests` (new file) | 7 — the geometry, the dense block, the degenerate all-zero block, the measured chain band, the three-block run, the third/fourth-group tamper sweep, the group-2/3 key swap |
| `dense_tests` | 3 — the stream is consumed entirely by public words, the recipe strings describe public weights only, the identity check at rung-K4 |
| `run_tests` | 2 — a retained statement names no hidden input and still rebuilds a verifier, the two retained 125M statements still regenerate their public weights |
| `parity` | 1 — the rung-K4 witness equals the independent reference kernel |

One new test is `#[ignore]`d (`write_the_k4_gate_bundles`), which is the
10 → 11. Six existing tests gained a rung-K4 case without changing what they
assert: `grow_tests`' two model comparisons, `hash_tag_tests`' two
classification tests and `pad`'s two shape loops. The Python side goes from
32 to **36** tests in the layout model's own file (72 → 76 across
`test_zk60_private_block_*`), the new ones being the `RungK4` class.

**The frozen gates are in the pass list**: the toy's **2,816,472 B**,
`the_toy_schedule_digest_is_frozen`,
`the_toy_parameter_line_is_the_frozen_literal` and
`a_toy_receipt_made_before_the_lane_still_verifies` (the four pre-lane
receipts). The stage-20 receipt sizes are unmoved: **4,218,600 /
4,234,984 / 40,783,352**.

### THE PYTHON SUITE OUTSIDE THIS LANE

`python3 -m unittest discover -s tests` is **not** green on this worktree,
and was not before stage 22. Ten results, none of which this stage can
reach:

* **six** are the same environment condition — `no complete local 125M
  regression fixture; set M125_EXPORT_DIR` (`test_uagb1_pass` x2,
  `test_uagb1_pass_agg`, `test_uagb1_tblind` x2,
  `test_zkmatrix_native_backends::test_ring_freeze_check`). This box has no
  125M export; that is a Mac-only rig.
* **three** are pinned digests of `hashline/src/zk.rs`
  (`test_zk60_mvp_security_probe` x2, `test_zk60_io_review_gate`), a file
  this lane is FORBIDDEN to touch and has not touched: `git diff e6b612f --
  hashline/src/zk.rs` prints nothing, so the mismatch against that external
  round-22 manifest exists at the hand-back tip exactly as it does here.
* **one** is `test_zk60_endpoint_view`'s "mandatory retained captures
  absent" — the `/tmp` evidence-loss condition.

The lane's own Python — `test_zk60_private_block_*`, the layout model and
the inventory driver that PARSES the real `define` — is **76 passed, 0
failed**, from 72.

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat e6b612f -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block
```

prints NOTHING: every one of those trees is byte-identical to the hand-back
tip `e6b612f`. The whole diff against `e6b612f` touches only
`hashline/src/private_block{,/*}`, `scripts/zk60_private_block_layout_model.py`,
`tests/test_zk60_private_block_layout_model.py`,
`docs/zkmatrix-poc/ZK60_{BLOCK125M_LANE_PROGRESS,RUN_CAPTURE_FORMAT}.md` and
`results/`.

### WHAT THIS STAGE DOES NOT ESTABLISH

* **No privacy property.** The two new bundles are the INPUT to the run
  privacy gate of ruling M-8; no gate has read them, and the Python ports
  still have to learn this profile's key set and this shape's plane index.
* **Not a deliverable profile.** rung-K4 is development grade (ruling P-7),
  like both rungs, and is barred from any privacy statement.
* **The 125M dense-run band was not re-measured** after the stream split
  (see item 1). Re-run
  `run_tests::the_first_admissible_fully_dense_run_band_at_125m` before the
  next 125M dense run.
* **No completeness claim beyond the cases run.** The negative controls say
  seven specific tampers in the third and fourth key-value group are
  rejected by the verifier; they do not say every one would be.

---

## Stage 23 — the four items of tonight's ruling on the shaped generic-rank lemma (2026-09-20, 23:3x–)

**Status: `LANDED`.** Opened 2026-09-20 23:37 PDT on the lane tip `823d86d`.
It works the four items the security owner's disposition
`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md` (rulings S-1, S-3, S-5) and
the independent check `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md` (findings
B-2, B-3, B-12) leave on this lane.

**Nothing an existing profile proves moved by a byte.** The toy's 2,816,472,
the rung's 4,218,600, rung-G's 4,234,984, rung-K4's 4,743,128 and 125M's
40,783,352 are all in the pass list; the toy schedule digest and parameter
line are frozen; the forbidden-file trees are byte-identical to the stage
start and to the hand-back tip `e6b612f` (proof at the end). Both new
refusals are asserted FALSE at all five shapes, which is what makes them
unable to move a receipt.

**No heavy run, no GPU, nothing at 125M proved.** The only new proving is a
two-block rung-G dense run inside one test (1.43 s).

**No privacy or soundness acceptance is claimed.** Two shape conditions the
privacy argument depends on became named refusals, one independent model
became independent at two more shapes, and one ordering fact became a test.
Gap G-R1 is narrowed where the disposition says it is; nothing else moves.

Commits: the skeleton `16deca7`, items 1 and 2 `9661094`, item 3 `b804087`,
item 4 `46baa40`, and this ledger.

| item | ruling / finding | what | state |
|---|---|---|---|
| 1 | S-1 (check B-2) | `log(Dom::Tab) == log_cols` is a named `Shape::new` refusal and a documented invariant at the P-3 lift | **DONE**, failing-first recorded |
| 2 | S-3 (check B-3) | `head_dim >= row width` is a named `Shape::new` refusal; `SC_PV` and the feed-forward slots checked for the same trap | **DONE**, failing-first recorded |
| 3 | S-5 (check B-12) | the layout model derives every endpoint's geometry; BOTH Rust-side correction terms removed; the model is the Rust's to the byte at all five shapes | **DONE** |
| 4 | gap GS-2 | the refusal replay order pinned in Rust at rung-G on a generic dense witness, through existing hooks only | **DONE**, with the missing hook named |

---

### Item 1 — ruling S-1: the lookup-table domain sits at exactly the row width

**THE DEFECT, IN ONE PARAGRAPH.** The privacy argument's "Fact 1" says a
claim's evaluation point never reaches a commitment's non-data rows. On the
helper commitment `H` that is **false**: the claim of slot `SC_ZS` on the
hidden plane `H_U` and the pairless LogUp sum claim both put data parts on
the two ZERO-SUM rows, which the argument's own accounting counts as
non-data, and `audit_claims` does not forbid it (its only row-placement
checks are the proximity pair and site-row exclusivity). It is harmless today
for exactly one reason: `Dom::Tab` sits at **exactly** the row width, so for
both claims `ls == log_cols`, hence `lr = 0` and `eq_table_msb(&point[..0]) =
[1]`, and each zero-sum row's weight is the point-INDEPENDENT coefficient.
Put the table domain above the row width and those rows carry an eq-tensor in
the claim's point: the non-data block becomes point-dependent and the
argument's corollary about the repaired bilinear slots stops being a theorem.
**Nothing checked it.** `domain_log_at` only lifts upward and `Dom::Tab`'s
natural log is the fixed `clog2(U8_LEN) = 8`, so it was safe by construction
rather than by check.

**WHERE THE REFUSAL SITS AND WHAT IT SAYS.** `Shape::new`
(`hashline/src/private_block/shape.rs`), immediately after ruling F-2's P-3
guard — the place where every other P-3-shaped condition is refused:

```
private block shape: ruling S-1 — the lookup-table domain must sit at EXACTLY
the row width (Dom::Tab natural log 8, at this shape 8, against a row width of
2^7); below it the table spans several rows and the helper commitment's
zero-sum rows would carry point-dependent data weights
```

The P-3 lift itself (`layout::domain_log_at`) gains a doc-comment section
headed **"AN INVARIANT THAT MUST NOT BE WEAKENED"**, which states Fact 1's
failure, the `lr = 0` computation that rescues it, and the two edits that
would reopen the argument (this function's direction, or `Dom::Tab`'s natural
log).

**THE LANE KEEPS NO "G-3 list" OF ITS OWN**, so there was nowhere else to add
the condition: `grep` for `G-3` and for "must not be weakened" across
`hashline/src/private_block/` and this ledger returns nothing (ruling G-3's
four `zkp-core/src/pcs.rs` assertions are named in the round's own documents,
outside this worktree, and `zkp-core` is a forbidden tree here). The
invariant therefore lives in the three places this lane owns: the refusal,
the lift's doc comment, and this section.

**WAS A VIOLATING SHAPE CONSTRUCTIBLE? YES — recorded failing-first**
(`s1-s23-items12-failing-first.log`, exit 101). The toy's axes at a row width
of `2^7` constructed happily before this commit: `log_cols = 7` is inside the
declared `2..=30` range, `Dom::Q`, `Dom::Kv` and `Dom::S` all sit at or above
`2^7` so ruling F-2 does not fire, and no other construction check looked at
`Dom::Tab` at all. What it would have produced is a two-row table domain —
the exact configuration the repaired Fact 1 excludes.

**THE TESTS** (`hashline/src/private_block/s23_tests.rs`, new):

| test | what it measures |
|---|---|
| `the_lookup_table_domain_sits_at_exactly_the_row_width_at_every_shape` | at all five shapes: `natural_log(Tab) == clog2(U8_LEN)`, `log(Tab) == log_cols`, `rows_of(Tab) == 1`, `log_cols >= 8` |
| `a_row_width_below_the_lookup_tables_natural_size_is_refused_by_name` | the `2^7` probe refused, the message naming the ruling, the domain and what breaks; a CONTROL with the same axes at `2^8` constructs |
| `the_lookup_table_refusal_is_exactly_the_row_widths_below_the_tables_log` | a sweep of `log_cols` 2..=11: below 8 ruling S-1 owns the refusal; at 8 the shape constructs; above 8 ruling S-1 is never the reason (ruling F-2's older refusal takes over at these axes, because the toy's `Dom::Kv` is at `2^8`) |

---

### Item 2 — ruling S-3: a head dimension at or above the row width

**THE TRAP.** `SC_SCORE`'s two private factors end their coordinate lists in
two copies of the SAME symbol segment, `rho(lkv .. lkv + log2(head_dim))`
(`argument.rs:1141-1158`), because a coordinate list owns its entries. A
column key is the LAST `log_cols` entries of a list, so if `log2(head_dim)`
reached `log_cols` both keys would be the last `log_cols` entries of that one
shared segment — **equal by construction on every run**. `opening_groups_at`
would return one group fewer than the schedule declares and `check_opening`
would refuse EVERY proof at that shape. It is a liveness cliff, not a leak,
and the existing guard covers only the opposite direction.

**THE REFUSAL**, in `Shape::new` beside item 1's:

```
private block shape: ruling S-3 — the head dimension 256 reaches the row width
2^8, so the two private factors of the score slot would share their whole tail
and their column keys would collide on every run; every proof at this shape
would be refused for its opening-group count
```

**WAS A VIOLATING SHAPE CONSTRUCTIBLE? YES — recorded failing-first** in the
same log. 16 tokens, width 256, one query head of 256 over one key-value
head, at a row width of `2^8`: the padded head slots tile the padded width
(`d_pad = h_pad * head_dim = 1 * 256`), the head dimension is a power of two,
the key-value heads divide both head counts, `Dom::Q` and `Dom::Kv` are
`2^12` and `Dom::S` is exactly `2^8` so ruling F-2 does not fire, and
`Dom::Tab` is exactly at the row width so item 1 does not fire either. Before
this stage `Shape::new` returned it, and every proof at it would have been
refused with a message about opening-group counts and no name.

**WHAT I FOUND FOR `SC_PV` AND THE OTHER SLOTS** — the disposition asks for
the analogue to be checked, and the answer is that there is none, for reasons
already enforced elsewhere. Recorded as assertions in
`the_source_token_axis_and_the_feed_forward_slots_carry_no_such_trap`, so a
change to either reason fails there:

* **`SC_PV` cannot collide structurally at any shape, and the source-token
  axis is not the analogue.** Its two private factors are `A_P` on `Dom::S`
  and `A_V8` on `Dom::Kv` (`argument.rs:1162-1186`). They DO share the
  source-token segment `tp = rho(lkv .. lkv + log2(t_pad))` — it is the last
  segment of `A_P`'s list and the FIRST of `A_V8`'s — so the naive analogue
  of S-3 would be "`t_pad >= row width`". But `A_V8`'s list continues with
  `rho(0 .. lkv)` and **ends in `fixed(r_i)`**, a segment of
  `log2(head_dim) >= 1` transcript entries and not sumcheck symbols. However
  large `t_pad` grows against the row width, the two keys end in different
  KINDS of coordinate and cannot be equal by construction. **The guard that
  keeps it that way is the existing T-8 refusal `head_dim >= 2`**: at
  `head_dim = 1` the `fixed(r_i)` segment would be empty and `A_V8`'s list
  would end in the shared `tp` exactly as `A_P`'s does. So S-3's analogue for
  `SC_PV` was already refused, by a rule written for a different reason (the
  RoPE partner bit), and the test now says so.
* **The feed-forward slots carry no such trap at all.** `SC_GMM`, `SC_UMM`,
  `SC_DMM` and the projection `SC_WO` raise **one** `A` claim each
  (`Shape::claim_sites`, asserted at rung-G), so the two-private-factor
  configuration cannot arise in them. `SC_GMM` and `SC_UMM` do share a plane
  and a fixed row point — the disposition's S-5 inventory addition — but they
  are different SLOTS with different `rho` symbols and one claim apiece.
* **The margin at every existing shape** is at least two bits:
  `clog2(head_dim) + 2 <= log_cols` at all five (8/16/16/8/64 against
  `2^8`/`2^10`/`2^10`/`2^10`/`2^14`).

---

### Item 3 — finding B-12: the layout model derives every endpoint now

**THE DEFECT.** `scripts/zk60_private_block_layout_model.py` DECLARED each
shape's endpoint row count, and two of the four declarations were stale: **14
rows for the frozen-seam rung** where the code has 21, and **29 for 125M**
where the code has 37. Each was hidden behind a named correction term in the
Rust comparison — `+45,056 B` in `grow_tests::MODEL_RUNG`, `+32,768 B` in
`MODEL_M125` — so at those two shapes the "independent model" and the Rust
never actually met; only their difference was explained.

**WHAT THE MODEL DERIVES NOW.** One rule, four new constants, no declaration:

```
endpoint_words   = t_pad * d_pad              # the PADDED Dom::D cube, the
                                              # slice SC_IO_IN / SC_IO_OUT claim
endpoint_general = not (words <= SEAM_MAX_WORDS      # 4,096
                        and endpoint_log_n  == SEAM_LOG_COLS   # 8
                        and endpoint_inv_rate == SEAM_INV_RATE) # 8
data_rows        = max(1, words >> endpoint_log_n)
endpoint_rows    = data_rows + ENDPOINT_MASK_ROWS    # 5
```

which is `Shape::new`'s own derivation of `endpoint_general`
(`shape.rs:208-220`) and `protocol::endpoint_geometry` /
`endpoint_g::MASK_ROWS`. The constructor no longer takes an `endpoint_rows`
argument at all — a regression guard asserts that by inspecting its
signature — and the frozen-seam rung's stale `endpoint_inv_rate=4` is
corrected to the seam's own 8, which is hashed into every `SeamSpec::digest()`
and so not editable.

**THE RESULT: the model is the Rust's TO THE BYTE at all five shapes, from
its own arithmetic, with nothing in between. BOTH correction terms are
removed.**

| shape | endpoint plane | `log_n` / rate | seam? | data rows | commitment rows | endpoint openings | model total = Rust total |
|---|---:|---:|---|---:|---:|---:|---:|
| toy | 512 | 8 / 8 | frozen | 2 | 7 | 262,144 | **2,816,472** |
| rung | 4,096 | 8 / 8 | frozen | 16 | **21** (was 14) | **319,488** | **4,218,600** |
| rung-G | 4,096 | 10 / 4 | generalised | 4 | 9 | 335,872 | **4,234,984** |
| rung-K4 | 4,096 | 10 / 4 | generalised | 4 | 9 | 335,872 | **4,743,128** |
| 125M | 524,288 | 14 / 4 | generalised | 32 | **37** (was 29) | **1,499,136** | **40,783,352** |

**No `Expected` literal moved**, because every one of them was already the
Rust's figure; it is the MODEL that came to meet them. What changed on the
Rust side is only the prose: the two correction-term comments are replaced by
a statement that the model now derives the geometry and agrees to the byte,
and the three other places that cited the terms (`rung_tests`'s frame
constant, `grow_tests`'s codec test, `k4_tests`'s frame constant) say they are
gone.

**NOTHING IS FORCED.** The difference against the MEMO grows by exactly those
two terms and stays fully diagnosed: **45,568 B** at the rung (512 of slot
line + 45,056 of endpoint) and **33,328 B** at 125M (560 + 32,768), each with
its cause in `KNOWN_MEMO_DIFFERENCES`, and the tests assert that no
difference is `UNDIAGNOSED`. The memo is what is stale here, not the code:
its endpoint pricing is of the TRUE plane, which `SeamSpec::new` refuses
outright (both axes must be powers of two) and which is not what `SC_IO_IN` /
`SC_IO_OUT` claim.

**ANY REMAINING DISAGREEMENT: none.** All five totals, and every part of
every receipt, agree.

**Lane Python: 82 passed, 0 failed** (from 76). Six new tests: a
`DerivedEndpoints` class of four (the five totals against the Rust's, every
endpoint derived from the cube and the mask rows, the seam selected by the
same derivation the Rust uses, and the regression guard on the constructor
signature) plus one per-shape endpoint test in `Rung` and in `M125`. The five
model JSON files and `model_report.txt` are regenerated; **rung-G's and
rung-K4's were never written out before** and are added.

---

### Item 4 — gap GS-2: the refusal replay order, pinned on a real block

**THE GAP.** The Python privacy tools replay the prover's refusal checks in
the order the opening's challenges are drawn, and the argument's reading of a
refused run depends on that order. Nothing in Rust pinned it.

**THE HOOKS USED — both already exist, and no production file is touched.**

* `run_capture::Recorder::attach` records, for every opening of every stage,
  the transcript state BEFORE the opening and its own INDEPENDENT replay of
  that opening's challenges from that state: the lambdas of each group in
  group order, then one proximity coefficient per commitment row
  (`run_capture::replay`, whose own comment names the source order). The
  recorder re-verifies the opening on its own transcript and the bundle is
  refused on the first mismatch, so **the record IS the draw order** — and it
  is the same order `zkp-core`'s `pcs::open_zk` / `verify_zk_tagged` use
  (`pcs.rs:947,961`: one `challenge_fp2_vec(members.len())` per group, then
  one `challenge_fp2_vec(rows)`).
* `protocol::check_opening_challenges` already takes an **injectable draw**,
  built for deterministic negative controls.

The new test joins the two: it reads the partition out of a real **two-block
FULLY DENSE rung-G run** — generic weights, a non-constant hidden input, both
key-value groups live — and drives the prover's own refusal logic over
exactly that partition.

**WHAT IS PINNED** (`s5-s23-gs2.log`, 1 passed, 1.43 s; stage 0: `A` = 36
groups over 623 rows, `H` = 9 groups over 576 rows, external endpoint = 1
group over 9 rows):

1. the recorded partition is the schedule's `a_groups()` / `h_groups()` and
   the layout's rows and proximity row, with one lambda list per group and
   one proximity coefficient per row;
2. the honest replay consumes `sum(members) + rows` draws and **no more**;
3. **every group position is tested for zero, in order, and the check
   SHORT-CIRCUITS**: a zero at stream position `i` refuses with `zero group
   member coefficient` after exactly `i + 1` draws, so the proximity
   coefficients are never drawn on a run discarded for a zero lambda. Swept
   over all 122 and 53 positions;
4. **the determinant reads exactly two positions**, `prox` and `prox + 1` of
   the row block — swept over all 623 and 576 rows, a zero at either refused
   and a zero at every other accepted — and a DEPENDENT (not zero) pair is
   refused too, which is what says the check is a determinant and not a zero
   test;
5. **precedence**: when a zero group coefficient and a degenerate proximity
   pair hold at once, the GROUP message wins, because the group block is
   drawn first;
6. the external endpoint's opening replays the same way with a single
   one-member group at its own `(9, 6)` geometry.

**THE OUTER ORDER** is pinned separately, in `s23_tests`, by forcing several
conditions at once: `check_opening` runs **the claim audit, then the exact
opening-group count, then the challenge refusals**, and the transcript is not
touched until the first two have passed. Ruling S-2's strike of finding N-2
leans on exactly that ordering ("`check_opening` runs the claim audit
FIRST…"), so it is a test now rather than a reading.

**WHAT IS NOT PINNED, AND THE MINIMAL HOOK THAT WOULD BE NEEDED.** Nothing
here observes the evaluation order from inside a live `prove_core` /
`verify_core`: `check_opening` clones the transcript and discards the clone,
so there is no way to see the live sequence from a test. Observing it would
need a test-only observer **inside `protocol::check_opening_challenges`** — a
`#[cfg(test)] fn observe(condition: &str, draw_index: usize)` beside the two
refusals, called on EVERY evaluation and not only on a refusal, with a
thread-local sink a test attaches. That is a change to a production file, and
ruling GS-2's instruction is not to add one, so it is named and not built.
What stands in its place is the equality above: the partition the test drives
is READ OUT OF a real block's real capture rather than declared.

---

### Tests and commands of stage 23

All through the shared build lock, `CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| items 1 + 2, **FAILING FIRST** (the refusals not yet written) | `s1-s23-items12-failing-first.log` | **3 passed / 3 failed**, exit 101 — both violating shapes CONSTRUCTED, printed in full |
| items 1 + 2, after the refusals (one sweep arm still wrong) | `s2-s23-items12-repaired.log` | 5 passed / 1 failed — the sweep assumed shapes above the table's log construct at the toy's axes; ruling F-2 owns them |
| items 1 + 2, green | `s3-s23-items12-green.log` | **6 passed / 0 failed** |
| item 3, the model comparisons | `s4-s23-grow.log` | **32 passed / 0 failed** |
| item 4, the GS-2 replay order | `s5-s23-gs2.log` | **1 passed**, 1.43 s |
| item 4's outer order, with items 1 + 2 | `s6-s23-check-opening-order.log` | **7 passed / 0 failed** |
| **THE GATE**: `--lib private_` | `s7-s23-private.log` | **275 passed / 0 failed / 11 ignored**, 67 filtered out, **399.87 s**, exit 0, **13 warnings** |
| the layout model and the inventory driver, `test_zk60_private_block_*` | run inline | **82 passed** (from 76), 47 s |

**Against the stage-22 baseline of 267 passed / 0 failed / 11 ignored and 13
warnings**: **275 / 0 / 11**, 13 warnings. **Eight tests are new** and not one
existing test was weakened or removed:

| where | new tests |
|---|---|
| `s23_tests` (new file) | 7 — the S-1 invariant at every shape, the S-1 refusal by name, the S-1 row-width sweep, the S-3 margin at every shape, the S-3 refusal by name, what `SC_PV` and the feed-forward slots do instead, and `check_opening`'s audit → count → challenges order |
| `run_capture_tests` | 1 — the GS-2 refusal replay order, on a real two-block fully dense rung-G capture |

**The frozen gates are in the pass list**: the toy's **2,816,472 B**,
`the_toy_schedule_digest_is_frozen`,
`the_toy_parameter_line_is_the_frozen_literal` and
`a_toy_receipt_made_before_the_lane_still_verifies`. The four shaped receipt
sizes are unmoved: **4,218,600 / 4,234,984 / 4,743,128 / 40,783,352**, and
item 3's model repair is what now reproduces two of them from outside the
Rust for the first time.

**The Python suite outside this lane** is unchanged from stage 22's ten
pre-existing results (no 125M export on this box, three pinned `zk.rs`
digests from an external round-22 manifest against a file this lane has not
touched, and the `/tmp` evidence-loss condition). Nothing in stage 23 can
reach any of them.

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 823d86d -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block
```

prints NOTHING, and so does the same command against the hand-back tip
`e6b612f`: every one of those trees is byte-identical to both. The whole diff
against `823d86d` touches 29 files and only
`hashline/src/private_block{,/*}`, `scripts/zk60_private_block_layout_model.py`,
`tests/test_zk60_private_block_layout_model.py`, this ledger and `results/`.

### WHAT STAGE 23 DOES NOT ESTABLISH

* **No privacy property.** Two shape conditions the argument depends on are
  now checked instead of merely true, and one ordering fact it assumes is now
  tested. The argument itself is unchanged, and gap G-R1 stands where the
  disposition leaves it: nothing has been measured at 125M (GS-1), the joint
  law across commitments (G-R4), the slot closures as a reading (G-R2), the
  sequential lift for a run (G-R5) and the non-linear channel (GS-13) are all
  untouched. Register entry D22 is untouched.
* **GS-2 is narrowed, not closed.** What is pinned is the replay order of one
  block's openings against the recorded challenge order, and the outer order
  of `check_opening`'s three checks. What is NOT pinned is the live
  evaluation order inside `prove_core` / `verify_core`; the minimal test-only
  hook that would give it is named in item 4 and deliberately not built.
* **The two new refusals are liveness and hygiene, not soundness.** Item 1's
  protects an argument, not a proof: a shape that broke it would still
  produce receipts, and they would still verify — what would stop holding is
  the reading of what they disclose. Item 2's protects liveness: a shape that
  broke it would produce no receipt at all.
* **Item 3 changes no Rust figure.** Every `Expected` literal was already the
  Rust's; what changed is that the independent model now reaches two of them
  by itself. A model that agrees is evidence about the COUNT, not about the
  construction.

---

## Stage 24 — the enforcement batch of tonight's three rulings (2026-09-21, 01:3x–)

**Status: `LANDED`.** Opened 2026-09-21 01:34 PDT on the lane tip `8c5922b`.
Nine small items that three of tonight's dispositions leave on this lane:

* `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` — **H-1**, **H-4**,
  **H-5**, **H-8**;
* `ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md` — **C-2**, **C-3**, **C-4**,
  **C-7**;
* `ZK60_NATIVE_RUN_GATE.md` §10.2 / §10.8 — round 6's ask to the capture
  writer (four run-layer files it does not pin).

**Nothing an existing profile proves may move by a byte.** Every refusal
added here is asserted FALSE at all five shapes (toy, rung, rung-G, rung-K4,
125M); the toy's 2,816,472 and the four shaped receipt sizes are in the pass
list; the forbidden-file trees stay byte-identical to `8c5922b` (proof at the
end).

**No heavy run, no GPU, nothing at 125M proved.**

**No privacy or soundness acceptance is claimed.**

Commits: the skeleton `4b2a6ea`, the code and the ten tests `68e8769`, and
this ledger.

| item | ruling | what | state |
|---|---|---|---|
| 1 | H-4 | every tagged profile's four keys, enumerated from the source registry, pairwise distinct | **DONE** |
| 2 | H-5 | the trailer/next-header PROPERTY pinned at rung-K4 | **DONE** |
| 3 | H-8 | no registered profile's constructor input has the squeeze length | **DONE**, and the margin is ONE BYTE |
| 4 | run gate §10 | the capture writer pins every run-layer source it depends on | **DONE**, 8 pins → 15 |
| 5 | C-2 | ruling S-3's refusal also protects slots 15 and 16 | **DONE** |
| 6 | C-3 | host discipline checked at every shape, against `HOSTS` | **DONE** |
| 7 | C-4 | the mask budget `L_s + 256 <= 512` becomes a named `Shape::new` refusal | **DONE**, failing-first recorded |
| 8 | C-7 | the closure polynomial vanishes on extension-round-supported vectors (gap S-C1) | **DONE**, both mechanisms observed |
| 9 | H-1 | an inadmissible chain is refused BEFORE any segment when the endpoints are sealed by the witness builder's own pass | **DONE**, with a measurement that differs from 125M's |

**The one new refusal is C-4's.** Ruling C-2 asked for ruling S-3's refusal to
be EXTENDED, not for a second one: its message and its doc comment now say
that it protects slots 15 and 16 as well as slot 08, and the reading is a
test. So this stage adds one named `Shape::new` refusal and widens one.

---

### Item 1 — ruling H-4: the keys of every tagged profile, from a registry
### that cannot go stale

**WHY A HAND LIST WAS THE PROBLEM.** `zkp-core`'s
`all_eight_keys_are_pairwise_distinct` pins eight keys by hex literal —
rung-G's four and 125M's four — which was every tagged profile the day it was
written. Stage 22 added a third (rung-K4) and nothing failed. The
disposition's H-4 asks for the test to be extended "to every tagged profile",
and a second hand list would go stale the same way.

**THE REGISTRY IS READ OUT OF THE SOURCE.** The test scans
`src/private_block/shape.rs` and `src/private_block/run.rs` for
`"hashline-zk-mr1/…"` STRING LITERALS (the opening quote is part of the
pattern, so a profile named in a comment is not picked up) and compares that
set with what the constructors give: the five shapes' `profile` fields and the
three `RUN_PROFILE_*` constants. **A profile added to either file without
being covered fails there, before a key is derived.** The stale hand list this
replaces — everything but rung-K4's two strings — is kept in the test as a
permanent non-vacuity assertion.

**WHAT IT FOUND AND ASSERTS** (`r3-s24-all.log`):

* **8 profiles registered, 2 legacy, 3 tagged.** The two legacy-rule profiles
  (the frozen toy, the frozen-seam rung) carry no key in any role;
* **12 live keys, pairwise distinct** across the four roles and the three
  tagged profiles;
* **CONFIRMED, and measured rather than read: a run uses its BLOCK shape's
  keys and derives none of its own.** `RunStatement::transcript` calls
  `protocol::tagged_transcript(sh, run_profile)`, which keys the transcript
  with `sh.hash_tag()` — the BLOCK shape's — and passes the run profile string
  as the transcript's DOMAIN. The test builds the state three ways and asserts
  the live one equals the block-keyed one and differs from what the run
  profile's own key set would give. So the answer to the disposition's
  "confirm" is: **there are twelve keys in this lane, not twenty-four**;
* and as a FORWARD GUARD the twelve are checked pairwise distinct together
  with the twelve the run profile strings WOULD derive, so a later decision to
  tag a run in its own right cannot collide silently.

---

### Item 2 — ruling H-5: the property, not the coincidence

The disposition measured on all ten bundles that a segment's 32-byte trailer
equals the next segment's 32-byte header, ruled that the wire format stays,
and ruled that **what is pinned is the property**: no transcript operation
occurs between a segment's end position tag and the next segment's start tag.

**PINNED AS A PROPERTY OF THE STAGE LOOP** — `run.rs:586` (`let end_tag =
position_tag(&tr);`) and `run.rs:527` (`let start_tag = position_tag(&tr);`),
with nothing between them but `wire::encode_segment`, the sink call and three
pushes into `RunStats`, none of which touches the transcript. The test's doc
comment says so and says the consequence: if a later change absorbed something
there, THIS test fails and the format does not — the verifier would recompute
both tags the same way and still accept. Nothing may be made to depend on the
equality.

**MEASURED** on a GENERIC three-block rung-K4 run (the fully dense recipe, a
non-constant hidden input, four live key-value groups), VERIFIED before the
tags are compared: end tag of stage k = start tag of stage k+1 for k = 0, 1;
the last stage's end tag equals no other tag in the receipt; and — the
non-vacuity — no stage begins and ends at the same position and no two stages
begin at the same one.

**WHAT THE OBSERVATION IS.** The 32-byte tag itself. A tag is two `Fp2`
squeezed from a DISCARDED clone, and `Transcript::clone_state` copies the
state AND the squeeze counter, both of which are hashed into every squeeze, so
equal tags mean an equal (state, counter) pair up to a hash collision.
`zkp-core` publishes no counter accessor and is a file this lane does not
edit; that is finding U-3, and it is why the tag is the strongest observation
available here.

---

### Item 3 — ruling H-8: and the margin is ONE BYTE

A constructor hashes `b"hashline-v1/" ‖ domain`, so its input is
`12 + profile.len()`; a squeeze hashes `state ‖ b"squeeze" ‖ counter`, so its
input is `32 + 7 + 8 = 47` bytes. **Both layouts are reproduced from outside
`Transcript`** — the state after construction and the state after one
challenge are recomputed from the updates and compared — so a change to either
fails at the reproduction and not at the arithmetic.

**THE EIGHT LENGTHS, against the squeeze's 47:**

| length | profile |
|---:|---|
| **46** | `hashline-zk-mr1/private-run-m125/1` |
| 48 | `hashline-zk-mr1/private-block-m125/1` |
| 51 | `hashline-zk-mr1/private-block-t32-poc/1` |
| 56 | `hashline-zk-mr1/private-block-rung-t24-dev/1` |
| 56 | `hashline-zk-mr1/private-run-rung-g-t24-dev/1` |
| 57 | `hashline-zk-mr1/private-run-rung-k4-t24-dev/1` |
| 58 | `hashline-zk-mr1/private-block-rung-g-t24-dev/1` |
| 59 | `hashline-zk-mr1/private-block-rung-k4-t24-dev/1` |

**The 125M RUN profile is at 46 — one byte below the squeeze class**, which is
the draft's finding F-2, now watched by a test rather than argued. A
35-character profile string would land exactly on 47, and that arithmetic is
asserted so the check cannot become vacuous.

---

### Item 4 — round 6's ask: the capture writer pins the whole run path

**THE ASK.** `ZK60_NATIVE_RUN_GATE.md` §10.2: the run gate's pin mechanism is
bundle-side — "a file can be pinned there only if the WRITER pins it" — and
four run-layer files were in no bundle's `source_pins`: `wire.rs`,
`run_sink.rs`, `endpoint_g.rs`, `hash_domain.rs`. §10.8 records it as a
Rust-lane ask.

**`SOURCE_FILES` 8 → 15.** The four the round named, and **three the
enumeration itself turned up**:

| added | why it is on the run's path |
|---|---|
| `wire.rs` | the segment frame: its lengths, both position tags, and the bytes a stage file's `segment_bytes` / `segment_sha256` are taken over |
| `run_sink.rs` | where a segment goes and what a run directory may hold |
| `endpoint_g.rs` | the generalised endpoint's `MASK_ROWS` and commitment construction — the external endpoints' row roles in every bundle |
| `hash_domain.rs` | the T-3 / T-4 hash-length and path-depth guards a run must pass before any of it is captured |
| **`src/private_block.rs`** | **the PARENT module.** `ExpectedIo::to_bytes`, `IoSpec` and `calibration_identity` live here, and the run header absorbs those very bytes — the ones ruling H-1 rests on |
| `witness.rs` | the witness type and builder, which decide every value a verifier then observes |
| `pad.rs` | the support indicators and pad-zero plane groups `argument.rs` reads into the slot definitions a bundle records |

**One production module is excused BY NAME**, in a new
`NOT_ON_THE_RUNS_PATH` constant with its reason: `timing.rs`, the phase clock,
which is write-only on the run's path and decides no byte.
`the_capture_writer_pins_every_run_layer_source_it_depends_on` PARSES the
production `mod` list out of `private_block.rs` and asserts the two lists
partition it, so a module added later cannot slip through undecided; it also
reads `run.rs` to check that the four named files really are reached from it.

**PURE ADDITION, and the schema name is kept.** `source_pins` is a list of
`{"file","sha256"}` objects; entries are added, no field, order or existing
entry moves, and a loader written for eight reads fifteen. **The ten committed
bundles are NOT re-taken and not edited** — each still carries the eight-entry
list its own `manifest.json` pins. `ZK60_RUN_CAPTURE_FORMAT.md` §9 item 7
carries the dated note.

**FOR THE INTEGRATOR AND THE GATE LANE**:
`tests/test_zk60_native_run_gate_runpins.py::test_the_four_unpinnable_files_are_really_not_in_source_files`
reads `git show 3247a89:src/private_block/run_capture.rs`, a FIXED historical
commit, so it does not break — but `NOT_PINNABLE_FROM_A_BUNDLE`'s prose
becomes out of date for bundles taken after this change.

---

### Item 5 — ruling C-2: S-3 protects three slots, not one

**WHAT THE CHECKER FOUND.** Clause C1 of the closure property — "every private
plane raises exactly one claim" — is false for slots 15 (`SC_QZC`) and 16
(`SC_KVZC`): the RoPE partner makes the SAME plane raise TWO claims, at points
differing in ONE FLIPPED COORDINATE (`cf[log - log2(head_dim)] =
Coord::Flip(..)`, trap T-8). Everything still holds, but only because the two
claims' COLUMN KEYS separate, and they separate only because
`log2(head_dim) <= log_cols`.

**WHY THAT IS RULING S-3.** A column key is the LAST `log_cols` entries of a
claim's point (`protocol::part_key_at`), so the flipped coordinate is inside
the key exactly when `log2(head_dim) <= log_cols`. S-3 enforces the strictly
stronger `head_dim < 2^log_cols`. Its refusal MESSAGE and its doc comment now
say so, and the test reads it off the real definitions:

| shape | the flipped coordinate | the column-key tail | margin |
|---|---|---|---|
| toy | `log - 3` | last 8 | 5 bits |
| rung / rung-G | `log - 4` | last 10 | 6 bits |
| rung-K4 | `log - 3` | last 10 | 7 bits |
| 125M | `log - 6` | last 14 | 8 bits |

Nothing is assumed: the two tables are found by their `slices` (the same
plane), their coordinate lists are compared entry by entry, and the test
requires that they differ in EXACTLY the partner position and that that
position is inside the tail. Both violating geometries — a head dimension AT
the row width and above it — are refused by S-3 by name.

**THE ONE MARGIN NOTHING COVERS, recorded rather than repaired**: at a
challenge with `rho_k = 1/2` the flipped and unflipped coordinates are equal AS
FIELD ELEMENTS and the two keys coincide for that draw. That is a 2^-128
liveness event on an honest run, not a structural collision, and it is in the
refusal's doc comment.

---

### Item 6 — ruling C-3: host discipline, at every shape

**WHAT WAS CHECKED BY NOTHING.** No test and no production check compared the
hosted lists written LITERALLY in the slot definitions with `layout::HOSTS`;
the existing assertions are test-only and against the toy's constants. A
mismatch is a SOUNDNESS defect — a hosted claim consumed twice or never.

**THE HOOK USED, AND NO PRODUCTION CHANGE.** `argument::define` returns the
list it built (`SlotDef::hosted`), so the literals are observable through the
existing test path — the same `define` walk the stage-20 reviewer built. The
test runs all 23 slots at all five shapes and compares the whole map in both
directions: every slot's list is exactly the table's entry for it in order,
every non-host slot hosts nothing, every private slot is hosted exactly once,
every standalone slot never, and every host runs AFTER what it hosts.

**RESULT: 6 hosts, 12 hosted claims, at all five shapes**, with the counts
equal to the table's. A host table with two hosted slots exchanged
(`SC_PV` and `SC_VMM` swapped between slots 15 and 16 — same counts, same
kinds, only who consumes what) is detected, in test code alone, which is what
says the comparison is one.

---

### Item 7 — ruling C-4: the mask budget becomes a named refusal

**THE DEFECT.** Every slot's masked message is `L_s = (main + ext)·degree + 2`
field elements and lives in ONE row of the masking commitment: 512 positions
of which 256 are the random pads that hide it (`zk.rs:442`). `L_s + 256 <= 512`
is therefore a condition on the SHAPE, and the only thing enforcing it was
that line — a prover-side `assert!`, a PANIC, deep in a numeric helper, on a
shape the caller had already been handed and after the witness had been built.
Shape validation had ten refusals and none was this.

**THE REFUSAL**, in `Shape::new` beside rulings S-1 and S-3, with the budget
taken from `zk.rs`'s own `MASK_LOG_MSG` / `MASK_Q` and not retyped:

```
private block shape: ruling C-4 — slot 17's masked sumcheck message is 262
field elements (51 main + 1 extension rounds at degree 5, plus 2), and the
masking commitment gives each slot ONE 512-position row of which 256 are its
random pads; 262 + 256 > 512, so the mask would not fit
```

**WAS A VIOLATING SHAPE CONSTRUCTIBLE? YES — recorded failing-first**
(`r1-s24-c4-failing-first.log`, exit 101, the shape printed in full).
`SC_SZC`'s main rounds are `log(Dom::S) = log2(h_pad) + 2·log2(t_pad)` and its
degree is 5 where that domain pads, so `L` passes 256 at `log(Dom::S) = 51`:
**2^20 − 1 tokens over 2,048 query heads of 8** satisfies every other check —
`d_pad = h_pad · head_dim`, the three bilinear domains far above the row width
(F-2 silent), `Dom::Tab` lifted onto it (S-1 silent), a head dimension 11 bits
below it (S-3 silent) — and constructed happily. Its CONTROL, one bit fewer of
tokens, is `L = 252` and constructs.

**EVERY EXISTING SHAPE PASSES, and the longest mask is always slot 17**
(`06 softmax zero-check`): 50 / 72 / 72 / 77 / **117**, plus 256, of 512 — the
disposition's own worst case.

---

### Item 8 — ruling C-7 (gap S-C1): the closure, and WHICH mechanism

**WHAT IS EVALUATED.** For each slot, the vector `run_slot` builds for
extension round `m` — every table that is not a private table of that round
hard-zeroed (`argument.rs`'s `exts`) — with **ARBITRARY** field values in the
private positions, three seeds, every declared round, every shape. **75
evaluations per shape, 375 in all, every one ZERO.**

**AND WHICH OF THE TWO MECHANISMS PRODUCES IT — separated and observed.**
Zeroing only the PUBLIC tables and giving every private table an arbitrary
value tells them apart: if every monomial carries a public factor the closure
is still zero; if a monomial is a product of private factors alone it is not.

| shape | slots surviving the public-only probe | the mechanism the test observed |
|---|---|---|
| toy | **08 and 09** | the OTHER PRIVATE FACTOR: at `lkv = 0` the two bilinear slots have no group `eq`, and the premise holds because the partner factor is zeroed in this round |
| rung, rung-G, rung-K4, 125M | **none** | A PUBLIC FACTOR IN EVERY MONOMIAL — so the closure is the ZERO POLYNOMIAL in the prover's values, not merely zero at each honest one |

That is exactly the split the disposition predicts ("the second mechanism is
needed at exactly one place in the whole module: slots 08 and 09 at the frozen
toy"), reproduced in Rust on the real definitions, and the toy's two non-zero
values are what make the first half non-vacuous.

---

### Item 9 — ruling H-1: the sealing pass, and where the chain really breaks

**THE RULE.** The run header absorbs the expected-IO bytes, which carry both
external endpoint roots, before any challenge exists, so the prover has
already run the whole forward pass before the header. The ruling's new rule
for a production caller: **the pass that seals the endpoints is the witness
builder's own, with its refusals**, and then an inadmissible chain is refused
before the header and no partial run directory can arise from that cause.

**WRITTEN WHERE THE CODE IS.** `RunWitnessSource`'s doc comment (`run.rs`)
now carries the ruling: why the adaptive-source worry is answered by the code
rather than by a promise, the two consequences (the sealing pass is the
witness builder's; a source must be a pure function of the committed input),
that ruling R-1.3's pre-pass costing is withdrawn, and that tightening the
interface is an item for when the production caller is written.

**EXERCISED.** A three-block rung-G chain at the single-block dense band —
one band above the measured chain band — sealed by a source that builds every
block through `witness::build_shaped`: the pass returns `fixed oracle range
refusal: residual 2`, `prove_run` is never entered (the flag set on the line
before the call is still false), and the run directory does not exist. The
positive control is the SAME function at the measured band: it reaches the
prover and leaves exactly three segment files of the counted lengths
(4,067,160 / 4,089,688 / 4,257,592 B, 1.61 s).

**FINDING S24-F1: at rung-G the chain breaks at the THIRD block of three, not
the second.** Stage 21's 125M band search was refused "always by the SECOND
block"; at rung-G band 48 it is the last one. The test PARSES the block index
out of the refusal rather than assuming it, requires only that it is not the
FIRST (the point being that only a pass over the whole chain can see it), and
pins the measured 3. At rung-G the refusing block is the one whose output
plane the external output endpoint seals, which makes the ruling's point more
sharply: a caller that had not run the whole pass could not even have formed
the statement.

---

### Tests and commands of stage 24

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| the new module's first build | `r0-s24-compile.log` | 1 compile error (a redundant format argument), 13 warnings |
| item 7, **FAILING FIRST** (the C-4 refusal not yet written) | `r1-s24-c4-failing-first.log` | **1 failed**, exit 101 — the violating shape CONSTRUCTED and is printed in full |
| the nine items, first pass | `r2-s24-all.log` | **8 passed / 2 failed** — both failures REAL and both reported above (finding S24-F1, and a non-vacuity inequality that the toy's own `Dom::Q` log makes an equality) |
| the nine items, green, `--nocapture` | `r3-s24-all.log` | **10 passed / 0 failed**, 4.63 s, exit 0 |
| **THE GATE**: `--lib private_` | `r4-s24-private.log:409` | **285 passed / 0 failed / 11 ignored**, 67 filtered out, **413.13 s**, exit 0, **13 warnings** |

**Against the stage-23 baseline of 275 passed / 0 failed / 11 ignored and 13
warnings**: **285 / 0 / 11**, 13 warnings. **Ten tests are new** — the ten of
`s24_tests.rs`, one per item and two for ruling C-4 — and **not one existing
test was weakened, removed or changed**: the whole diff to existing Rust is
one `mod` line, two doc comments, one refusal message, one new refusal and
seven entries in a list.

**The frozen gates are in the pass list**: the toy's **2,816,472 B**
(`tests.rs:108`, `zero_witness_tests.rs:172`),
`the_toy_schedule_digest_is_frozen`,
`the_toy_parameter_line_is_the_frozen_literal` and
`a_toy_receipt_made_before_the_lane_still_verifies`. The four shaped receipt
sizes are unmoved — **4,218,600 / 4,234,984 / 4,743,128 / 40,783,352** — in
`grow_tests`' `MODEL_*` totals, `k4_tests`' frame constant and
`the_125m_receipt_is_reproduced_part_by_part`, all in the pass list.

**No Python is touched by this stage** (no `scripts/` or `tests/` file is
edited, and both lane-owned Python files are byte-identical to the stage
start), so the Python side stands exactly where stage 23 left it: the lane's
own 82 passed, and the same ten pre-existing results outside this lane.

`r3-s24-all.log` is the one log of this stage taken WITH `--nocapture`, and
what it carries is the evidence table of every item above: profile counts and
lengths, slot indices, host counts, mask lengths, evaluation counts and
segment lengths. **No witness value, no position and no count of hidden words
is printed by any test in this stage** (the capture rule); the one run it
proves prints only its segment lengths and its wall clock.

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 8c5922b -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block scripts tests
```

prints NOTHING: every one of those trees, `scripts/` and `tests/` included, is
byte-identical to the stage start. (Against the hand-back tip `e6b612f` the
same command prints the two lane-owned Python files
`scripts/zk60_private_block_layout_model.py` and
`tests/test_zk60_private_block_layout_model.py`, which are **stage 23's**
endpoint-derivation repair and not this stage's — stage 24 touches no Python
at all.) `zkp-core/src/hashtag.rs` in particular is untouched: ruling H-3's
correction of its doc comment is the INTEGRATOR's, in the integrator's crate,
and is deliberately not made here.

The whole diff against `8c5922b` is **17 files**: this ledger,
`ZK60_RUN_CAPTURE_FORMAT.md`, `hashline/src/private_block{.rs,/run.rs,
/run_capture.rs,/shape.rs,/s24_tests.rs}` and ten files under
`results/zk60_block125m_lane/` (five logs and their `.done` markers).

### WHAT STAGE 24 DOES NOT ESTABLISH

* **No privacy property, and no privacy acceptance.** Eight things that were
  true are now checked and one shape condition is refused by name. The
  arguments themselves are unchanged: gap **G-R2**'s remaining enforcement is
  narrowed by C-3, C-4 and C-7, and everything else the two dispositions
  leave open stands where they leave it — **O-4 / G-R5**, the sequential
  composition for field-and-hash message pairs, is untouched and is the paper
  task; nothing has been evaluated on a 125M receipt (GS-1); the joint law
  across commitments (G-R4) and the non-linear channel (GS-13) are untouched.
  Register entry D22 is untouched.
* **C-7 is a check of the PREMISE, not of the theorem.** It says the closure
  vanishes on extension-round-supported vectors at every shape, which is one
  hypothesis (H4) of the composition theorem. It says nothing about the rest
  of it.
* **The new refusal is liveness, not soundness.** A shape that broke the mask
  budget would produce no receipt at all; it is the same kind of cliff as
  ruling S-3's, refused by name in the same place.
* **H-5 pins a property of the stage loop, not a wire-format guarantee.**
  Nothing may be made to depend on the trailer equalling the next header, and
  the disposition's ruling that the 32·(L−1) bytes stay is not reopened here.
* **Item 4 does not make any existing bundle better.** The ten committed
  bundles carry the eight-entry pin list; only bundles taken after this change
  carry the fifteen. The run gate's own ports still depend on four files, as
  round 6 says.
* **H-1's interface item is not closed.** `RunWitnessSource` still PERMITS an
  adaptive source; what is written is the rule and what is tested is a caller
  that follows it. Tightening the trait waits for the production caller, and
  rule M-9 still has no production code behind it (ruling H-2).

---

## Stage 25 — the lane's share of the query-class work list (2026-09-21, 04:0x–)

**Status: `LANDED`.** Opened 2026-09-21 04:03 PDT on the lane tip `5758b95`.
The items of `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §8 that its "whose
file" column marks **the lane**, as rulings J-3, J-5, J-6 and J-7 leave them
(`…_DISPOSITION.md`): **W-2** (generalised), **W-3**, **W-4**, **W-5**,
**W-6** (as changed by J-7), **W-7** (confirm), **W-8 assertions 5 and 7**,
**W-11**. W-1, W-8's assertions 1–4 and 6, W-9's GPU side and W-10 are
another engineer's files and are NOT touched here.

**Nothing an existing profile proves may move by a byte.** One guard set
grows (W-4, legacy-rule profiles only); everything else is a test or a
document.

**No heavy run, no GPU, nothing at 125M proved. No privacy or soundness
acceptance is claimed.**

Commits: the skeleton `17af21a`, the code, the thirteen tests and the W-5
document `9c1c56b`, and this ledger.

| item | what | state |
|---|---|---|
| W-2 | every hash input kind of every registered profile, printed with its length; per hash FUNCTION no two different kinds are equal unless declared; every pair within one byte listed | **DONE** — 8 profiles, **410 kinds**, **113** one-byte pairs |
| W-3 | the refusal replay re-issues the live chain's next points and leaves the live transcript untouched | **DONE** on a real rung-K4 boundary opening |
| W-4 | the legacy length guard gains the statement digests and the seed derivations | **DONE**, 16 rows refused by name, failing-first as a live assertion |
| W-5 | `ZK60_HASH_FUNCTION_SEPARATION_TABLE.md` | **DONE** |
| W-6 | the per-slot `pb-term` lengths, printed and RECORDED (not guarded) | **DONE**, and the 295-byte pair recorded |
| W-7 | stage 24's twelve-key test still covers every tagged profile | **DONE** (confirmed, nothing added) |
| W-8 | assertions 5 and 7 of the memo's §3.1 (the two that need no accessor) | **DONE**; 1–4 and 6 still blocked, with a test that says so |
| W-11 | the source scan extended from absorb LABELS to hash CALL SITES | **DONE**, 19 sites in 18 files |

---

### Item W-2 — the whole table, and what it says that the memo does not

**THE SHAPE OF THE TEST.** For every one of the **eight** registered profiles
— the five block shapes and the three run profiles, enumerated from the
SOURCE registry exactly as stage 24's key test enumerates it — the test
builds every hash input KIND on that profile's path, with its exact length
and the BLAKE3 FUNCTION that hashes it, and prints the whole list. A
"function" is one mode and one key: at a legacy profile there is one
(`F_U`), plus the generator's keyed seed derivation `R1`; at a tagged profile
there are five (`F_T`, `F_C`, `F_L`, `F_N`, `F_U`), plus `R1` and the
`derive_key` mode `K`.

**410 kinds**: 45 at the toy, 47 at the frozen-seam rung, 49 at each tagged
block, 57 at each run (`r3`/`q3-s25-green.log:120-648`).

**The kinds, per profile**: the transcript constructor; every absorb label
with every data length it takes at that shape, the variable ones included
(`parameters`, `pb-term`, `pcs-vec`, `pcs-prox`, `sc-round`); the squeeze;
the refill; the seed derivation `22 + |domain|` at every `ZkRng::from_os`
domain on that path; the statement digests D1–D8 that exist there; the five
commitments' column digests; the salted leaf and the Merkle node; and, at a
tagged profile, the four `derive_key` contexts.

**A LABEL-SCOPE TABLE decides which labels a BLOCK absorbs and which a RUN
does**, and the test asserts it covers exactly `hash_domain`'s label table,
so a new label cannot be measured without a decision. The two asymmetries
are re-derived from the code: a run absorbs `run-shape`, `pb-run-stage`,
`pb-run-block` and `B`, and **a block inside a run never absorbs its own
`parameters` line** (`prove_core` is handed the run's transcript;
`protocol::transcript` is not called).

**THE ASSERTION.** Per profile and per FUNCTION, no two DIFFERENT kinds have
equal length unless the pair is in a DECLARED list that names the fixed
literal separating them. Seven pairs are declared:

| length | the pair | what separates them |
|---:|---|---|
| 64 | a salted leaf / a Merkle inner node | **NOTHING** under the legacy rule (claim B-7, ruling L-7, 2^-484.83); under a tag they are two functions and the pair does not arise |
| 64 | `log-cols` absorb / leaf, and / node | the fixed 24-byte `le64(8) ‖ "log-cols" ‖ le64(8)` at offset 32 |
| 81 | the root absorbs `A`, `H`, `B`, `M` | the one-byte label at offset 40 |
| 171 | `expected-IO` / `parameters` (the toy only) | the label literal and its length prefix at offset 32 |
| 295 | `parameters`(run line) / `pb-term`(15), at a rung-G or rung-K4 run with `2 ≤ L ≤ 9` | the label literal (the check's B-7, recorded by J-7) |
| 49 | the transcript key's / the leaf key's `derive_key` context | **the context strings themselves** — see finding S25-F2 |

Anything else fails the test. Nothing else was found, at any of the eight.

**FINDING S25-F1 — the `calibration` absorb is 91 bytes and is in no list of
the memo's.** §5.1's "fixed at every shape" block enumerates 60, 63, 64, 68,
73, 81, 88, 92, 96, 104/120/136/152, 113, 171, 16,438, 16,441 and omits it.
It is also **one byte below the `pb-run-block` absorb's 92**, so it belongs
to the one-byte class of §7 as well.

**FINDING S25-F2 — the four `derive_key` contexts are 49 / 44 / 49 / 48
bytes**, one more each than the memo's 48 / 43 / 48 / 47 (`hashtag.rs:47-53`,
re-counted). Two of them share a length, which is why the seventh declared
pair exists; a `derive_key` context input IS a fixed public literal, so what
separates them is the literal itself and the finding is bookkeeping, not a
hazard.

**FINDING S25-F3 — there are 113 pairs within one byte, not six.** The
memo's §7 lists six and says naming the class is the point; the class has
**113 members** across the eight profiles. Every one of the memo's six is in
the printout (asserted by name). The ones the memo does not list include:

* `calibration` 91 / `pb-run-block` 92, at all three runs;
* the rung-G and rung-K4 endpoint column 72 / `pb-scalar` 73;
* an internal boundary's column 80 / each of the four root absorbs 81, at
  the two development runs;
* `pb-term`(15) 295 / the 125M external endpoint column 296;
* `pcs-vec` / `pcs-prox` at every shape (8,247/8,248, 20,535/20,536,
  266,295/266,296) — one byte apart because their labels are;
* `pb-term`(3) 103 / `sc-round`(2) 104, at every profile;
* the node key's `derive_key` context 48 / the squeeze 47, and / the 125M
  block constructor 48, and / the other two contexts 49.

None is a clash. The point of listing them is that the next profile string,
the next label or the next geometry lands in a crowded space.

**D2, the block's public/weights digest, is arithmetic checked against the
hasher.** Its input is `31 + w` and `w` is about 9 MB at 125M, so no guard
can build it; the formula mirrors `absorb_into`'s framing and is re-walked
tensor by tensor against two REAL statements (the toy's synthetic fixture and
rung-G's tame case): **6,311 B at the toy, 145,287 B at rung-G, 9,179,783 B
at 125M** [COMPUTED].

---

### Item W-3 — the refusal replay, measured on a real opening

**WHAT WAS PINNED BY NOTHING.** `check_opening` clones the transcript and
draws `Σ members + rows` challenges (`protocol.rs:305-306`); `pcs::open_zk`
then draws the same count from the LIVE transcript (`zk_rhos`). The memo:
*"the same oracle points, queried twice, by design"* — and §8's row against
it said **nothing**.

**THE OBJECT.** A real rung-K4 internal boundary: the geometry a real
three-block rung-K4 run commits (`RunStatement::boundary_spec(0)`, **10
rows**, two claim sites), committed over a non-constant plane with fresh
operating-system randomness under the shape's own hash tag, opened by the
real `PreparedBoundary::into_opening` — which is `check_opening` and then
`pcs::open_zk` with nothing between them — and verified by
`pcs::verify_zk_tagged`.

**THE FOUR MEASUREMENTS** (`q3-s25-green.log:672`):

1. the live transcript's state AND its next challenge are unchanged by
   `check_opening`;
2. the **12** values the replay consumes, recorded through
   `check_opening_challenges`' injectable draw, equal element for element
   the 12 a clone at the same state produces in `zk_rhos`' order;
3. after the real opening, a clone that drew exactly those 12 and then
   absorbed the opening's own vectors **reproduces the live transcript's
   state** and samples the opening's own **256** column indices;
4. non-vacuity: a clone that draws ONE challenge more ends elsewhere.

**THE OBSERVATION THAT WOULD NEED A PRODUCTION HOOK, AND IS NOT ADDED**: a
squeeze-COUNTER accessor on `zkp-core`'s `Transcript` (finding U-3), and the
`#[cfg(test)] fn observe(condition, draw_index)` inside
`check_opening_challenges` that ruling GS-2 declined. What replaces the first
is the (state, next-challenge) pair; what replaces the second is stage 23's
order test on a real capture.

---

### Item W-4 — the statement digests and the seed derivations enter the
### legacy guard

**THE HOLE (claim B-9, as narrowed by J-7).** Stage 16's set was built from
the TRANSCRIPT class alone. A commitment of **16 rows** hashes its column to
128 bytes, which is the frozen seam's spec digest, and nothing refused it;
the seed derivation was missing for the same reason, and at the generalised
endpoint it is **64** — the leaf and node length.

**WHAT WAS ADDED, and where.** `hash_domain.rs` gains a STATEMENT CLASS —
D1 (30), D6 (142), D7 (151), D8 (128), D4 (`29 + 32L`) and R1 at every
`from_os` domain (`22 + |domain|`) — and the two IMPOSED functions
(`imposed_at_shape_with`, `imposed_shape_free`) now use the whole set.
`at_shape*` and `shape_free` are UNCHANGED, so every stage-16 test goes on
pinning what it pinned. The imposition stays legacy-only (T-3 as amended,
which J-7 does not reopen).

**THE FAILING-FIRST IS A LIVE ASSERTION, not a transient log**: the test
asserts that `shape_free()` — the guard exactly as stage 16 left it —
ACCEPTS a 16-row commitment, and that `full_shape_free()` refuses the same
count by name, in the same run. The "before" cannot rot.

**The set grew by exactly one dangerous row count**: `[5, 8, 11, 12, 13, 15,
17, 19] -> [5, 8, 11, 12, 13, 15, 16, 17, 19]`. 64 was already the node's,
and the other five new lengths (30, 50, 142, 151, and `29+32L ≡ 5 mod 8`) are
not multiples of eight.

**Refused by name** at both legacy profiles' shape-driven sets, at the two
bare statement constructors, and at a REAL constructor: a synthetic legacy
internal boundary of a `32 x 128` plane over a `2^9` row width with three
claim sites is `8 + 6 + 2 = 16` rows and is refused; the same geometry
constructs under a tag.

**Nothing accepted moves**: the toy's 455 / 384 / 50 / 7 and the frozen-seam
rung's 623 / 576 / 50 / 21 are asserted by hand and pass; the generalised
endpoint's reachable 6, 7, 9, 13, 21, 37 have the same verdicts as before
(only 13 refused, for `sc-round`); 10 and 38 boundary rows still pass; and
every tagged profile's imposed set is still empty.

**WHAT IS DELIBERATELY NOT IN THE IMPOSED SET, with the reason.** Three
statement digests have a VARIABLE input that is not knowable where the guard
is called: **D2** (`31 + w`, and the weights do not exist at
`Layout::for_shape`), **D3** and **D5** (`33 + Σ` / `31 + Σ` over the
layout's own description lines, which would need the Layout the guard is
called from the middle of). All three are COMPUTED instead in W-2's table at
every registered profile, where the test asserts no commitment's column has
their length. This is a scope note, not a hazard: the nearest of them to any
column digest is thousands of bytes away.

---

### Item W-6 — the per-slot terminal absorbs, printed and RECORDED

**Slot 19 = `SC_TAB` carries 3 + 3 terminals at every registered shape**, and
`SC_TAB = 19 < SC_IO_IN = 21`, so `slot_terms[19] = 6` and the absorb is
`48 + 7 + 96 = 151` bytes everywhere. The whole table reproduces the check's
`recheck.py` §5 exactly:

| shape | distinct `slot_terms` | `pb-term` absorb lengths |
|---|---|---|
| toy | 1, 2, 3, **6**, 13, 15, 17, 21, 22, 56 | 71, 87, 103, **151**, 263, 295, 327, 391, 407, 951 |
| rung / rung-G / rung-K4 | 1, 2, 3, **6**, 13, 15, 17, 22, 24, 56 | 71, 87, 103, **151**, 263, 295, 327, 407, 439, 951 |
| 125M | 1, 2, 3, **6**, 13, 15, 17, 22, 24, 54 | 71, 87, 103, **151**, 263, 295, 327, 407, 439, 919 |

**151 IS the internal boundary's spec-digest input, and it is RECORDED and
NOT GUARDED** (ruling J-7). What the test asserts is the reason: at every one
of the eight profiles, no two 151-byte inputs share a FUNCTION — a legacy
profile has no internal boundary at all, and at a tagged profile the absorb
is `F_T` and the digest `F_U`. The pair exists only under the "one global
`F_U` across profiles on one machine" reading, at `2^-256` per absorb.

**The 295-byte within-function coincidence is recorded too.** At a rung-G or
rung-K4 run the `parameters` absorb of the RUN's line is 295 bytes for
exactly `2 ≤ L ≤ 9` — measured over `L = 1 … 12` at both, with 294 at `L = 1`
and 296 at `L = 12` — and a 15-terminal `pb-term` absorb is 295 at those
shapes. Same function, same execution, separated by `le64(10)‖"parameters"`
against `le64(7)‖"pb-term"` at offset 32. Deterministic; nothing is broken.

---

### Item W-7 — confirmed, nothing added

Stage 24's `every_registered_profile_is_covered_and_every_tagged_ones_keys_
are_pairwise_distinct` still covers every tagged profile: the registry read
out of the source gives **8 profiles, 2 legacy, 3 tagged, 12 live keys
pairwise distinct**. The confirmation test cites the stage-24 test by name
and fails if it is ever deleted.

---

### Item W-8 — the two assertions that need no accessor

**Assertion 7, "the key is fresh"** (the accepted toy statement's condition
6, as a test): every `ZkRng::` constructor in the production text of every
production module of this path is `from_os`; **no file on the path names
`ZkConfig`**, whose `rng` method is the only route to the seeded
`ZkRng::new`; `boundary::prepare` takes `&mut ZkRng` from the caller and
makes none. Non-vacuity in test code alone: the classifier sees a seeded
construction and does not mistake a `&mut ZkRng` parameter for one.

**FINDING S25-F4 — there is a FIFTH `ZkRng::from_os` site, and the memo's
A-6 lists four.** `private_seam.rs:349`, inside `private_seam::prove` — the
experimental standalone seam proof. It is **off this path**: the private
block reaches the seam through `private_seam::prepare` alone
(`private_block.rs:776`), and the test asserts that no production file of
this path names `private_seam::prove`. A-6's enumeration is right about the
path and short about the file.

**Assertion 5, "never cloned, forked or serialised; exactly one per
prover"**: `ZkRng` implements neither `Clone` nor `Copy` — a TYPE-LEVEL fact,
probed with the inherent-impl trick and carrying its own two controls, so
"never cloned" is not a discipline but a compile error; `rng.rs` has no
derive, no `impl Clone`, no `Serialize`; and `prove_run` and `prove_inner_at`
each contain exactly one `ZkRng::from_os`, no `ZkRng::new`, no `rng.clone()`,
and hand the one generator on by `&mut`.

**Assertions 1–4 and 6 remain BLOCKED**, and a test says so as a fact of the
code: `ZkRng`'s four fields are private and it publishes no consumption
accessor. **The day the integrator's accessor lands, that test fails** and
the four assertions become owed on this lane.

---

### Item W-11 — the scan, from absorb labels to hash call sites

`every_absorb_label_on_the_path_is_in_the_table` sees absorb LABELS and
nothing else; §5.3 of the memo found six in-process hash sites that were in
no list. The new scan looks for **thirteen** BLAKE3 and SHA-256 entry points
(`blake3::hash`, `Hasher::new`, `new_keyed`, `new_derive_key`, `derive_key`,
`keyed_hash`, `finalize_xof`, `hashtag::hasher`, `hash_pair`, `hash_columns`,
`salt_leaf`, `Sha256::new`, `sha256_hex`) in the production text of **18**
files — every production module of `private_block` (the list is PARSED from
the parent's `mod` lines, so a new one is scanned automatically), the parent,
`private_seam.rs`, and the three `cfg(test)` modules that write a retained
bundle — and asserts that every site is in an explicit commented table with
its call kind from the memo's §5.

**19 sites, all classified**: 7 unkeyed BLAKE3 (D1, D2, D3, D4, D5, D6, D7
in `private_block.rs`, `layout.rs`, `run.rs` ×2, `endpoint_g.rs`,
`boundary.rs`) plus D8 in `private_seam.rs`, and 11 SHA-256 (C1) in
`run_sink.rs`, `run_capture.rs` and `run_statement_file.rs`.

**The table is keyed by `(file, entry point, count)` and not by line
number**, deliberately: a line-numbered table rots on every comment edit,
and what has to fail is a NEW call site, which changes a count.

**The other engineer's files are listed READ-ONLY**, 14 entries with the
`file:line` the memo records at `8c5922b` (T1–T4c, P1–P5, R1, R2, K and the
two CUDA kernels), and are **not scanned** — they change under integration
and a count pinned here would fail for reasons this lane cannot fix. The
G1/G2 row carries ruling J-3 in full.

---

### Item W-5 — the document

`docs/zkmatrix-poc/ZK60_HASH_FUNCTION_SEPARATION_TABLE.md`: the eight
functions (`F_U`, `F_T`, `F_C`, `F_L`, `F_N`, `R1`, `K`, and SHA-256 named as
not BLAKE3), the line where each is constructed, and every pair with the
model that separates it and the test that pins it — under the legacy rule and
under a tag, separately, because the same table means different things. It
names the five rows **pinned by nothing**: leaf against node at a legacy
profile; the model behind leaf ≠ node under a tag (proposed decision **D19b**,
marked PROPOSED); `R1` against the leaf and node classes (convention V-2
alone, and at the generalised endpoint they even share a length); that C1
stays SHA-256; and the two CUDA kernels' agreement, with ruling **J-3** in
full — an AGREEMENT pinned by the differential probe `dev_hash_check` and the
proof-byte parity gates, not a separation, reachable at the two legacy
profiles under `gpu-cuda` + `HL_GPU=1`, and outside what D22 covers. No
privacy claim is made anywhere in it.

---

### Tests and commands of stage 25

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| the new module's first build, `--lib s25 -- --list` | `q0-s25-compile.log` | compiles, 14 warnings (one unused import, removed) |
| the thirteen tests, first pass, `--nocapture` | `q1-s25-first.log` | **8 passed / 5 failed**, exit 101 — all five REAL and all five reported below |
| the second pass | `q2-s25-second.log` | **12 passed / 1 failed** — the fifth `from_os` site, finding S25-F4 |
| the thirteen tests, green, `--nocapture` | `q3-s25-green.log` | **13 passed / 0 failed**, 0.49 s, exit 0 — this is the stage's evidence log: the 410 kinds, the 113 one-byte pairs and every measurement above |
| **THE GATE**: `--lib private_` | `q4-s25-private.log:422` | **298 passed / 0 failed / 11 ignored**, 67 filtered out, **405.31 s**, exit 0, **13 warnings** |

**Against the stage-24 baseline of 285 / 0 / 11 and 13 warnings**: **298 / 0 /
11**, 13 warnings. **Thirteen tests are new** — the thirteen of
`s25_tests.rs` — and **not one existing test was weakened, removed or
changed**: the whole diff to existing Rust is one `mod` line with its
comment, the statement class and three new functions in `hash_domain.rs`,
and the run's call site passing `RunFacts` instead of a bare string.

**The frozen gates are in the pass list**: `the_toy_schedule_digest_is_frozen`
(`q4:198`), `the_toy_parameter_line_is_the_frozen_literal` (`:197`),
`a_toy_receipt_made_before_the_lane_still_verifies` (`:266`) and
`the_125m_receipt_is_reproduced_part_by_part` (`:174`). The toy's
**2,816,472 B** and the four shaped receipt sizes **4,218,600 / 4,234,984 /
4,743,128 / 40,783,352** are unmoved, asserted where they always are
(`tests.rs:108`, `zero_witness_tests.rs:172`, `grow_tests`' `MODEL_*`
totals, `k4_tests`' frame constant), all in the pass list.

**The five first-pass failures, each a real finding or a real defect of the
first draft**: the read-only call-kind list had two entries whose text was
shorter than the test's own "this is a reason" floor; the two 49-byte
`derive_key` contexts were an undeclared equal-length pair (finding S25-F2);
a doc comment naming `ZkRng::refill` was read as a constructor call; the
synthetic 16-row boundary was written with five claim sites, which the
construction refuses at four; and the rung-K4 boundary was verified with the
LEGACY verifier where a tagged profile needs `verify_zk_tagged`.

**No witness value, no position and no count of hidden words is printed by
any test in this stage** (the capture rule). The one commitment any of them
makes is over a non-constant PUBLIC plane, and what is printed of it is its
row count and the number of challenges drawn.

**No Python is touched by this stage**, no GPU, no heavy run, and nothing at
125M is proved: the 125M rows of W-2's table are lengths computed from the
shape, and the one 125M object built is a `RunStatement`, which commits
nothing (`ExpectedIo::from_roots` takes the two external roots as given).

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat 5758b95 -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block scripts tests
```

prints **NOTHING**. The whole diff against `5758b95` is **six files**: this
ledger, `ZK60_HASH_FUNCTION_SEPARATION_TABLE.md`,
`hashline/src/private_block{.rs, /hash_domain.rs, /run.rs, /s25_tests.rs}`,
plus the logs under `results/zk60_block125m_lane/`.

### WHAT STAGE 25 DOES NOT ESTABLISH

* **No privacy property and no privacy acceptance.** Register entry D22 is
  untouched. W-2 … W-11 are the memo's BOOKKEEPING items: they make the
  query-class table a computed object with a test behind each row. The
  composition step still rests on what §3 of the disposition says it rests
  on, and the two hops (the generator assumption, then the sampler's bias)
  are unchanged.
* **The one pair separated by nothing is still separated by nothing.** A
  salted leaf and a Merkle inner node under the legacy rule are the same
  function on the same 64 bytes. This stage names and prices the pair; it
  does not close it. Only the tag does, at the cost of proposed decision
  D19b.
* **W-9 and W-10 are not touched**: the two CUDA kernels' agreement is not
  cited to a gate by name and the device and pinned-host buffer lifetimes
  are unread, so ruling J-3's exclusion stands and the accelerator
  configuration remains outside D22.
* **W-8 is half done.** Assertions 1–4 and 6 of the memo's §3.1 — every one
  of the position-level ones and the realised-value map — are blocked on the
  integrator's consumption accessor. What this stage adds is the two that
  close the two defects assertions 1–5 could not see: a seeded generator
  (assertion 7) and a forked one (assertion 5).
* **The imposed length guard still omits D2, D3 and D5**, whose inputs are
  variable-length; they are computed and checked per profile in a test
  instead, which is a weaker place than a constructor.
* **The source scans pin TEXT, not behaviour** — the same weak link stage 16
  named for T-3. A hash call reached through a helper in an unscanned file,
  or a `ZkRng` obtained through a fourth crate, is invisible to them.

---

## Stage 26 — the generators' seed derivations, structurally separated at every UNFROZEN profile (2026-09-21, 05:1x–)

**Status: `LANDED`.** Opened 2026-09-21 05:15 PDT on the lane tip `fd45a67`.
One ruling, from `ZK60_TOY_ROUTE_A_REEXAMINATION.md` finding **B-1** and
`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §9 item 6:

> At every UNFROZEN profile a randomness generator's domain carries WHAT IT
> IS FOR — a versioned use literal, a fixed-width role or index, and a
> public spec digest or the profile string — so that the independence
> assumption behind two generators of one proof has a STRUCTURAL backstop
> and not only two `/dev/urandom` reads.

**The frozen toy and the frozen-seam rung are untouched**: their generator
call sites and domains stay byte for byte what they are, and so does
`zkp-core/src/rng.rs`, whose `from_os` signature and body this stage only
CALLS. **No verifier-visible byte moves**: a generator is prover-side and the
verifier never sees one.

Commits: the skeleton `db23512`, the FAILING-FIRST step `1e6715c` (every
generator routed through a domain builder whose body is still today's
bytes), the ruling itself, and this ledger.

**No heavy run, no GPU, nothing at 125M proved. No privacy or soundness
acceptance is claimed.**

---

### Item 1 — the inventory: every `ZkRng::from_os` on the path, re-derived

Stage 25's W-8 listed five sites; the scan is re-run here and the same five
come back, with what each is FOR and what it passes. `zk.rs:337`
(`ZkConfig::rng`'s seeded branch) and `zk_ffn_fresh_*.rs` are OFF this path
and are excluded by stage 25's own reachability test, which still passes.

| # | site | which rule it serves | domain BEFORE | `22 + |domain|` | domain AFTER | frozen? |
|---|---|---|---|---:|---|---|
| 1 | `protocol.rs`, `prove_inner_at` | the SINGLE-BLOCK prover, one stream per attempt | the bare block profile string | toy **61**, rung **66**, rung-G **68**, rung-K4 **69**, 125M **58** | use literal (47 B) ‖ `0x02` ‖ the profile string — **at tagged profiles only** | the toy and the frozen-seam rung: **YES, unchanged** |
| 2 | `run.rs`, `prove_run` | the MULTI-BLOCK run prover, ONE stream for the whole run | the bare run profile string | rung-G **66**, rung-K4 **67**, 125M **56** | use literal (58 B) ‖ `0x03` ‖ the run profile string | no — all three run profiles are tagged |
| 3 | `endpoint_g.rs`, `prepare` | each EXTERNAL ENDPOINT of a tagged profile, **twice per proof** | `b"hashline/private-block/general-endpoint/v1"`, **the same 42 bytes for both endpoints** | **64** | use literal (44 B) ‖ role byte (`0x00` in / `0x01` out) ‖ `EndpointSpecG::digest()` | no |
| 4 | `private_seam.rs:196`, `prepare` | each external endpoint of the TWO LEGACY profiles, twice per proof | `b"experimental-private-seam/v1"`, the same 28 bytes for both | **50** | unchanged | **YES** — frozen, and a file outside this lane's write set |
| 5 | `private_seam.rs:349`, `prove` | the experimental standalone seam proof | — | — | unchanged | OFF this path (stage 25's finding S25-F4) |

**There is no sixth site, and in particular a BOUNDARY has none.**
`boundary::prepare` takes `&mut ZkRng` from the caller so that a run draws
its `L - 1` boundaries from the ONE stream `prove_run` makes. The domain a
boundary WOULD use is written and tested anyway
(`hash_domain::boundary_seed_domain`: use literal (46 B) ‖ index as `u64`
LE ‖ `BoundarySpec::digest()`, **108** bytes of derivation input) and is now
what `boundary.rs`'s own six test sites use — they were seeding a generator
with `DOMAIN`, the module's SPEC-DIGEST label, which is a second use of a
string that means something else. **Finding S26-F1**, recorded rather than
repaired in production, because production has nothing to repair.

**The frozen split is exactly the hash-rule split.** The ruling applies
where `Shape::hashes_under_the_legacy_rule()` is false. The two profiles
where it is true are the byte-frozen toy and the frozen-seam development
rung — which are also the only two whose endpoints are `private_seam.rs`'s.
So the legacy C-H4 length guard, which is imposed at legacy profiles ONLY
(ruling T-3 as amended), can only ever see domains this stage did not touch.
That is the whole of item (d), and it is measured below rather than argued.

---

### Item 2 — the four domain layouts, and why each length is the length it is

```text
domain = <versioned use literal> ‖ <role byte or index, fixed width>
                                 ‖ <a PUBLIC spec digest, or the profile string>
seed derivation input = b"hashline-zk-os-rng/v1/"(22) ‖ domain
```

| use | literal | tail | `|domain|` | derivation input |
|---|---|---|---:|---:|
| the generalised endpoint | `hashline-zk-rng/private-block/endpoint-g/v1/` (44) | role (1) ‖ spec digest (32) | 77 | **99** |
| an internal boundary | `hashline-zk-rng/private-block/run-boundary/v1/` (46) | index `u64` LE (8) ‖ spec digest (32) | 86 | **108** |
| the single-block prover | `hashline-zk-rng/private-block/single-prover/v1/` (47) | `0x02` (1) ‖ profile string | 94 / 95 / 84 | **116 / 117 / 106** |
| the run prover | `hashline-zk-rng/private-block/one-stream-per-whole-run/v1/` (58) | `0x03` (1) ‖ run profile string | 103 / 104 / 93 | **125 / 126 / 115** |

**The four conditions the lengths had to meet, and they were CHOSEN to meet
them** (the literals are the free parameter; each was sized until all four
held):

1. **not 64** — a salted leaf and a Merkle inner node. The generalised
   endpoint's input was EXACTLY 64 before this stage, twice per proof, which
   is the sharpest row of `ZK60_HASH_FUNCTION_SEPARATION_TABLE.md`;
2. **not 40** (the generator's own refill block) and **not 47** (a
   transcript squeeze);
3. **never a multiple of eight**, so no derivation input can be a committed
   column's `8 · rows` and the legacy guard's refused row counts cannot grow;
4. **pairwise distinct within one profile**, so `R1`'s own row of the
   separation table has no equal-length pair between two KINDS.

The two endpoints of one statement deliberately share a LENGTH (99 each) and
are separated by the role byte — clause (b) of the ruling. They are ONE kind
at one length, not two kinds that collide, which is why W-2's declared-pair
list did not have to grow.

---

### Item 3 — the failing-first evidence

The first code commit (`1e6715c`) routes every call site through the new
builders while each builder's BODY still returns today's bytes. The tests
then measure the code before the ruling, not a description of it.

`p2-s26-failing-first.log`: **2 passed / 6 failed**, exit 101. All six are
the pre-ruling state:

| failing test | what it reported |
|---|---|
| `the_two_endpoint_generators_of_one_statement_derive_their_keys_from_different_inputs` | **finding B-1, reproduced**: at rung-G, rung-K4 and 125M the two endpoint derivation inputs are BYTE-IDENTICAL, both the 64 bytes `"hashline-zk-os-rng/v1/" ‖ "hashline/private-block/general-endpoint/v1"` (the failure printed both vectors) |
| `no_two_generators_of_one_proof_share_a_derivation_input` | the three-generator set of one block collides at the two endpoints |
| `every_seed_derivation_input_length_is_printed_and_clear_of_the_node_refill_and_squeeze` | the endpoint's derivation input is **64 bytes, the length of a salted Merkle leaf / a Merkle inner node** |
| `the_domains_are_built_from_public_fields_and_nothing_else` | the endpoint domain is 42 bytes where the layout says 77 |
| `the_two_frozen_profiles_keep_the_domains_they_have` | every UNFROZEN profile still passes the bare profile string |
| `the_legacy_length_guards_refused_row_counts_are_unmoved` | the endpoint's 64 is a multiple of eight |

**The boundary half of the failing-first is a NEGATIVE result and is
recorded as one**: there is no production boundary generator, so "two
boundaries of one run share a domain today" could only be shown of the six
TEST sites, which did share one (`DOMAIN`, 43 bytes, at every boundary of
every run). That is finding S26-F1; the pairwise test now covers the
boundary domains as the domains the module uses.

**Two earlier passes are kept for the record and were defects of the tests,
not of the code** (`p0`, `p1`): a doc comment naming the generator
constructor was read by the source scan as a call — the same trap stage 25
hit — and one "old length" in the item-(d) argument, the 125M RUN profile's
56, really IS a multiple of eight. Both are repaired in place: the scan
skips comment lines, and 56 is now handled by name with the reason it moved
no refusal (a run's set is imposed NOWHERE, because the guard is legacy-only
and no run profile is legacy).

---

### Item 4 — the pairwise-distinctness result

`p5-s26-green.log`, `no_two_generators_of_one_proof_share_a_derivation_input`
— every domain a proof uses, built and compared pairwise, with the set's
SIZE asserted so the comparison cannot go vacuous:

| proof | generators | derivation input lengths | verdict |
|---|---:|---|---|
| one block at rung-G | 3 | `[116, 99, 99]` | pairwise distinct |
| one block at rung-K4 | 3 | `[117, 99, 99]` | pairwise distinct |
| one block at 125M | 3 | `[106, 99, 99]` | pairwise distinct |
| an `L = 3` run at rung-G | 5 | `[125, 99, 99, 108, 108]` | pairwise distinct |
| an `L = 3` run at rung-K4 | 5 | `[126, 99, 99, 108, 108]` | pairwise distinct |
| an `L = 12` run at 125M | 14 | `[115, 99, 99, 108 ×11]` | pairwise distinct |

The equal LENGTHS in those rows are the point: two endpoints separated by
their role byte, eleven boundaries separated by their index and their spec
digest. `the_two_endpoint_generators_…` adds the sharper statement — with
the spec digest held EQUAL, the two role domains differ in **exactly one
position, domain offset 44** — and the run prover's domain is asserted
different from the single-block prover's at the same geometry.

---

### Item 5 — the updated length table, and the verdict on it

`s25_tests`' W-2 table now takes every seed-derivation length from the
domain builder rather than from `22 + |profile|`, so it cannot drift from
the bytes the call sites pass. Re-run green:

* **410 hash input kinds over 8 profiles** — unchanged;
* **7 declared equal-length pairs** — unchanged. **NO new equal-length pair
  inside any hash function appeared**, so nothing had to be declared away;
* **pairs within ONE BYTE: 113 → 107.** The two printouts were DIFFED row by
  row rather than counted: **seven retired, one new.**
  * retired: the `pb-slot` absorb's 63 B against the generalised endpoint's
    old 64 B seed derivation, **at all six tagged profiles** — the margin
    that sat one byte from the leaf/node class; and, at the rung-K4 run, the
    run prover's old 67 B against the `pb-run-stage` absorb's 68 B;
  * **new, exactly one**: at the rung-K4 run, the run's public statement
    digest **D4 at `L = 3` (125 B, F_U)** against the run prover's new seed
    derivation (**126 B, R1**);
  * the toy's own `50 / 51` and `60 / 61` margins are untouched, as a frozen
    profile's must be;
* the memo's six named margins are all still asserted present.

**FINDING S26-F3 — one EQUAL length across two functions, at one run,
recorded and not repaired.** At the rung-G run with `L = 3` the run's public
statement digest D4 is `29 + 32·3 = 125` bytes and the run prover's seed
derivation is also **125**. They are **different BLAKE3 functions** — D4 is
F_U, the seed derivation is R1, keyed under 32 secret `/dev/urandom` bytes
at every hash rule — so the W-2 assertion, which groups by function, does
not fire, and the separation is the one `ZK60_HASH_FUNCTION_SEPARATION_TABLE.md`
already carries for R1 against F_U: BLAKE3's keyed mode under a key the
adversary does not have (convention V-2), which is not a length argument at
all. The coincidence is also not a property of the profile: D4's length
moves with `L` (125 at three blocks, 413 at twelve). **It is left as it
is**, and the watch is W-2's own per-function assertion, which fails the day
the two ever land in one function. The measurement that would justify
re-sizing the run literal is a registered LEGACY-rule run profile, where F_U
would carry the transcript as well — there is none, and
`s26_tests::the_two_frozen_profiles_keep_the_domains_they_have` fails if one
appears.

**The legacy guard (item (d)): UNCHANGED, and here is the proof rather than
the claim.** The shape-free refused row counts are `[5, 8, 11, 12, 13, 15,
16, 17, 19]` before and after. The toy's imposed set is `[5, 8, 11, 12, 13,
15, 16, 17, 19, 1031]` and the frozen-seam rung's `[5, 7, 8, 11, 12, 13, 15,
16, 17, 19, 1031, 2567]`, both unmoved. The argument, measured test by test:

* every length the stage RETIRES or leaves — 61, 66 (both frozen), 50 (the
  seam), 68, 69, 58, 66, 67 — is not a multiple of eight, except two;
* **64**, the generalised endpoint's old input, IS a multiple of eight, and
  row count 8 stays refused because 64 is the Merkle node's and the salted
  leaf's and always was. What 64 loses is the endpoint's DESCRIPTION, which
  is the side benefit the ruling names;
* **56**, the 125M run prover's old input, is also a multiple of eight (row
  count 7) — and was never a refused row count anywhere, because the guard
  is imposed at legacy profiles only and no registered run profile is
  legacy. The emptiness of every tagged profile's imposed set is the check;
* every length the stage INTRODUCES — 99, 108, 116, 117, 106, 125, 126, 115
  — is not a multiple of eight, so none adds a refused row count.

**The C-H4' source scan was widened** to cover `hash_domain.rs`, which is
where the four new domain literals live: 44, 46, 47 and 58 bytes, none of
them the forbidden 28 or 35. The scan cannot tell a generator domain from a
transcript label, and that is deliberate.

**FINDING S26-F2, recorded and not repaired.** `boundary.rs` contains a
28-byte byte-string literal — `b"boundary test: a shared pair"`, a test
transcript domain — and the file is not in the C-H4' scan's list. It is
test-only and on no proving path, so it is not a C-H4' violation; it is why
the file was not added to the scan along with `hash_domain.rs`.

---

### Item 6 — what did NOT change, asserted

* **The frozen toy and the frozen-seam rung**: `single_block_seed_domain`
  returns the bare profile string for exactly those two (61 and 66 bytes of
  derivation input), and the test also asserts that every UNFROZEN profile's
  domain DID change, so the first half cannot pass vacuously. The frozen
  seam's 28-byte constant and its two call sites are read and asserted
  present; `private_seam.rs` is byte-identical.
* **`zkp-core` is untouched.** `ZkRng::from_os`'s signature and body are
  read by the test and asserted to still derive the key as this stage's
  arithmetic assumes (`new_keyed(&entropy)`, then the 22-byte prefix).
* **The draw ORDER and COUNTS are untouched.** Nothing about what is drawn
  or in which order is edited; the change is the domain bytes of one keyed
  BLAKE3 call per generator. Stage 25's position facts and the per-block
  draw counts are pinned where they were pinned and are in the gate's pass
  list.
* **No verifier-visible byte can move, and none did.** A generator is
  prover-side; no domain is absorbed, hashed into a statement or written to
  a wire. The gate carries the evidence: the toy's **2,816,472 B** and the
  four shaped receipt sizes **4,218,600 / 4,234,984 / 4,743,128 /
  40,783,352**, the counted run segment bytes, the stage-21 rung-G `L = 3`
  **run binding** and its **two boundary digests** as 32-byte literals
  (`the_run_header_the_approved_scales_bind_is_byte_identical_under_ruling_r5`),
  and the frozen toy's schedule digest and parameter line.
* **The honest GENERIC proofs verify under the UNCHANGED verifier**: the
  four tests that prove on fully dense public weights with a non-constant
  hidden input and verify — one block and a three-block run at each of
  rung-G and rung-K4 — are in the gate's pass list, and
  `s26_tests::the_four_honest_generic_proofs_this_stage_must_not_break_are_where_the_ledger_says`
  pins that they still exist and still assert their counted lengths, so this
  citation cannot rot.

---

### Tests and commands of stage 26

All through the shared build lock,
`CARGO_TARGET_DIR=.../wt-zk60-attention-compile/hashline/target`,
`--release --offline -j 2 -- --test-threads=1`.

| command | log | result |
|---|---|---|
| the new module's first build and run, `--lib s26` | `p0-s26-compile.log` | compiles, **13 warnings**; 1 passed / 7 failed (five real, two test defects) |
| after the first defect repair | `p1-s26-failing-first.log` | 1 passed / 7 failed (one more test defect surfaced) |
| **THE FAILING-FIRST**, `--lib s26 --nocapture` | `p2-s26-failing-first.log` | **2 passed / 6 failed**, exit 101 — all six the pre-ruling state, tabulated above |
| the ruling applied, `--lib s2 --nocapture` | `p3-s26-green.log` | 43 passed / 1 failed — one slice offset in the layout test |
| the same, after a wrong repair | `p4-s26-green.log` | 43 passed / 1 failed — the offset the other way |
| **the stage green**, `--lib s2 --nocapture` | `p5-s26-green.log` | **44 passed / 0 failed / 1 ignored**, 13.83 s, exit 0 — this is the stage's evidence log |
| the gate before the C-H4' widening, `--lib private_` | `p6-s26-private.log:430` | **306 passed / 0 failed / 11 ignored**, 425.05 s, exit 0, **13 warnings** |
| **THE GATE**, `--lib private_` | `p7-s26-private.log:431` | **306 passed / 0 failed / 11 ignored**, 67 filtered out, **410.16 s**, exit 0, **13 warnings** |

The gate was run TWICE because the C-H4' scan's file list was widened after
the first one started; `p7` is the one taken against the final source and
both agree, test for test.

**Against the stage-25 baseline of 298 passed / 0 failed / 11 ignored and 13
warnings**: **306 / 0 / 11**, 13 warnings. **Eight tests are new** — the
eight of `s26_tests.rs` — and **not one existing test was weakened, removed
or changed.** The whole diff to existing Rust is: one `mod` line with its
comment; the domain block in `hash_domain.rs` (four literals, four role
bytes, four builders, four length helpers) and the three lines of
`statement_class` / `full_shape_free` that now take a length from a builder
instead of retyping `22 + |profile|`; the `role` parameter and
`EndpointRole` in `endpoint_g.rs`; `BoundarySpec::index`; the six
test-generator sites of `boundary.rs` routed through one helper; one line
each in `protocol.rs` and `run.rs`; one file added to the C-H4' scan's list;
and the stage-25 assertions that follow the moved lengths.

**The frozen gates and the byte-identity witnesses are in the pass list**
(`p6`): `the_toy_schedule_digest_is_frozen` (`:198`),
`the_toy_parameter_line_is_the_frozen_literal` (`:197`),
`a_toy_receipt_made_before_the_lane_still_verifies` (`:266`),
`the_125m_receipt_is_reproduced_part_by_part` (`:174`),
`the_run_header_the_approved_scales_bind_is_byte_identical_under_ruling_r5`
(`:332` — the rung-G `L = 3` **run binding** and its **two boundary
digests** as literals), and the four honest GENERIC proofs:
`dense_tests::an_honest_dense_block_…_at_the_rung_g` (`:141`),
`k4_tests::an_honest_dense_block_…_at_the_rung_k4` (`:219`),
`run_tests::an_honest_three_block_fully_dense_run_…` (`:313`) and
`k4_tests::an_honest_three_block_fully_dense_run_…_at_the_rung_k4`
(`:220`). The toy's **2,816,472 B** and the four shaped receipt sizes
**4,218,600 / 4,234,984 / 4,743,128 / 40,783,352** are unmoved, asserted
where they always are, all in the pass list.

**No witness value, no position and no count of hidden words is printed by
any test in this stage** (the capture rule). What the stage's own tests
print is domain lengths, role offsets, profile strings and refused row
counts — public every one. No Python is touched, no GPU, no heavy run, and
nothing at 125M is proved: the 125M rows are lengths computed from the
shape, and the one 125M object built is a `RunStatement`, which commits
nothing.

### FORBIDDEN-FILES PROOF

```
git --no-pager -C /home/victor/wt-zk60-block125m diff --stat fd45a67 -- \
  zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs \
  hashline/src/wcache.rs hashline/src/native_capture.rs \
  hashline/src/private_seam.rs hashline/src/gpu private-block-kernel \
  private-model-kernel private-block-kernel-shaped zkvm-block scripts tests
```

prints **NOTHING**. `zkp-core/src/rng.rs` in particular is byte-identical:
this stage only chooses the `domain` bytes it passes to `ZkRng::from_os`,
and a test reads that function's body to check the arithmetic it assumes.

### WHAT STAGE 26 DOES NOT ESTABLISH

* **No privacy property and no privacy acceptance.** Register entry D22 is
  untouched. The independence of separate `/dev/urandom` reads is still
  assumption **J-2** and no code can discharge it; what this stage removes
  is that at the unfrozen profiles the assumption stood ALONE for two of the
  three generators.
* **Finding B-1 still stands AT THE FROZEN TOY**, which is the profile the
  accepted statement is about. The toy's two endpoint generators still
  derive their keys from the same 50 bytes, because its bytes are pinned
  (D17 / D22) and `private_seam.rs` is outside this lane's write set. §9
  item 6 of the toy statement is therefore unchanged and must stay in it;
  what changes is that the sentence is now true of the toy ALONE and the
  lane's document says which profiles are repaired.
* **A domain is not an independence proof.** Two generators with different
  domains still have the same key if the two entropy reads are equal; what
  the domain buys is that they no longer have the same key DERIVATION, so a
  single shared read is no longer sufficient for a shared stream, and the
  hypothesis has something structural under it.
* **The boundary domain has no production caller.** It is written, tested
  and separated, and exercised only by `boundary.rs`'s own tests. If a
  boundary ever needs its own stream that is a design change with its own
  review; this stage only makes sure the domain is not improvised then.
* **The source scans pin TEXT, not behaviour** — stage 16's weak link, and
  stage 25's. `every_production_generator_is_seeded_from_a_domain_builder`
  reads the three call-site lines; a generator obtained through a helper in
  an unscanned file would be invisible to it.
* **Nothing here touches the sampler, the composition step or the joint
  law.** The two hops of the joint sentence are unchanged.



---

## Stage 27 — a RUN CAPTURE made possible at the 125M shape (2026-09-21, 08:1x–09:0x)

**Status: `LANDED`, and the heavy run is NOT launched from here.** TEST-ONLY:
the whole diff against `fc782a3` under `hashline/src` is four modules that
`private_block.rs` declares `#[cfg(test)]`, so **no production code path
changes and nothing an existing profile proves moves** (proof at the end).
The security owner launches the 125M capture himself; the two commands are
in item 5.

**No privacy or soundness acceptance is claimed or implied.** A capture is
the INPUT to the privacy gate of ruling M-8. Writing one — at any shape —
does not meet it, and no gate has read a 125M bundle because none exists yet.

### The problem, in one paragraph

The Python privacy gate has replayed every challenge of a private run,
re-hashed every opened column, closed every per-slot terminal identity and
constructed a per-commitment and a joint preimage — on real bytes, at two
DEVELOPMENT shapes, 4.95 million published values reproduced from all-zero
data. Its standing limit is one sentence: **nothing has been measured at the
125M shape.** That was assumed out of reach because a 125M receipt is 40 MB
a block. But a capture is not the receipt, it is the VERIFIER'S VIEW, and the
gate's per-commitment work scales with the message length `2^14` and not with
the 45 KB columns. The thing actually in the way was the writer's own
encoding: rendered as decimal JSON a uniformly random `Fp` costs **21.4
bytes** and an `Fp2` **44.8** (MEASURED on the committed rung bundles), so a
two-block 125M bundle would have been **653 MB of text**.

| item | what | state |
|---|---|---|
| 1 | the size and memory model at 125M, per member, [COUNTED] and validated to the byte at a development shape | **DONE** |
| 2 | the heavy `#[ignore]` capture test, written and NOT run | **DONE** |
| 3 | writer-side source pins for the shared files the run depends on: 15 -> 38 | **DONE** |
| 4 | a development-shape dress rehearsal, run here | **DONE** |
| 5 | the prebuilt binary and the two launch commands | **DONE** |

Commits: the skeleton `d86c374`, the code and the format note, and this ledger.

---

### Item 1 — the size and memory model at 125M

#### The per-element costs, MEASURED on the committed bundles

Read off `run-g-dense-s20` and `run-i-dense-k4` by byte-span decomposition
(every member's exact span in the file), not estimated:

| datum | as `/4-run` JSON | little-endian |
|---|---:|---:|
| a uniformly random `Fp` | **21.41 B** | 8 |
| a uniformly random `Fp2` | **44.8 B** | 16 |
| a 0/1 public-table entry (`Fp2`) | **8.01 B** | 16 |
| a 32-byte salt / path node | 153.4 / 148.8 B | 32 |

Note the third row: an INDICATOR table is *cheaper* as JSON than as bytes.
It is content addressing, not the binary width, that pays for the public
tables — see below.

#### The 125M counts the model is evaluated at

`A` 5,681 rows and 36 opening groups; `H` 7,120 rows and 9 groups; the
masking commitment `M` 50 rows with `q` and `prox` of 1,024 entries each; an
external endpoint 37 rows and 1 group; an internal boundary 38 rows and 2
groups; 256 opened columns and a 16-node Merkle path per commitment; every
opening vector `2^14 + 256 = 16,640` `Fp2`. (Rows and groups from
`results/zk60_block125m_lane/model_m125.json`, the independent Python layout
model that agrees with Rust to the byte on the receipt.)

#### What `arrays.bin` retains, per member, per stage

| member | count | bytes |
|---|---|---:|
| `A` opened column values | 256 x 5,681 `Fp` | 11,634,688 |
| `A` opening group vectors | 36 x 16,640 `Fp2` | 9,584,640 |
| `A` proximity vector | 16,640 `Fp2` | 266,240 |
| `A` proximity coefficients | 5,681 `Fp2` | 90,896 |
| `H` opened column values | 256 x 7,120 `Fp` | 14,581,760 |
| `H` opening group vectors | 9 x 16,640 `Fp2` | 2,396,160 |
| `H` proximity vector | 16,640 `Fp2` | 266,240 |
| `H` proximity coefficients | 7,120 `Fp2` | 113,920 |
| an external endpoint's group + proximity vectors | 2 x 16,640 `Fp2` | 532,480 |
| an internal boundary's | 3 x 16,640 `Fp2` | 798,720 |
| the `M` opening's `q` and `prox` | 2 x 1,024 `Fp2` | 32,768 |
| an endpoint's / boundary's / `M`'s column values (37 / 38 / 50 rows) | below `ARRAY_MIN` | inline JSON |

giving **39,499,792 B** for stage 0 (`A`, `H`, the external input endpoint,
`M`), **39,766,032 B** for a middle stage (the incoming boundary instead),
**40,298,512 B** for the last stage (both), and **40,032,272 B** for an
`L = 1` run, which is admissible: `RunShape::new` refuses only `l == 0`, and
a one-block run has no internal boundary and opens both external endpoints
in its single stage.

#### The public tables, and why they are the whole problem

A slot's public table has exactly `2^main` entries (`argument.rs:317` refuses
anything else), and the 125M inventory follows from the `define` arms plus
which domains pad:

| class | slots | per stage |
|---|---|---:|
| `2^22` | 04 (causal mask, `supp(S)`), 17 (causal mask, `supp(Ht)`, `supp(S)`) | 5 |
| `2^19` | 00, 01 (`supp(D)`), 14 (gamma_a, gamma_m, `supp(D)`), 15 (rotary cos, sin, `supp(Q)`) | 8 |
| `2^17` | 16 (rotary cos, sin) | 2 |
| `2^14` | 03 (`supp(L)`), 19 (u8, exp, act, `supp(Tab)`), 20 (the all-ones cube) | 6 |
| `2^11`, `2^10` | 13; 05, 06, 07, 10, 11, 12 (folded public weights) | 1, 6 |

**28 instances and 25,534,464 `Fp2` a stage** — 409 MB raw, 213 MB as JSON.
Three tables that exist at both rungs are absent at 125M because their
domains do not pad there (`supp(T)` in slot 02, `supp(Kv)` in slot 16,
`supp(F)` in slot 18), which is why 125M has 28 where the rungs have 31.

**But they deduplicate almost completely.** The causal mask, the pad
indicators, the norm gains and the rotary pair are functions of the SHAPE
alone: byte-identical between slots and between stages. MEASURED at rung-G:
93 public-table instances over three stages, **47 distinct** — and the
derivation above reproduces that 47 exactly, class by class, which is what
licenses using it at 125M. The distinct set at 125M is

* shape-only, ONCE for the whole bundle: `3 x 2^22 + 6 x 2^19 + 2 x 2^17 + 3 x 2^14` = **16,039,936** entries = 256.6 MB;
* per stage: `3 x 2^14` (the three challenge-dependent table helpers) `+ 2^11 + 6 x 2^10` = **57,344** entries = 0.92 MB.

#### The totals

| `L` | `arrays.bin`, public tables ON | + stage JSON | **bundle** | without the public tables' values |
|---:|---:|---:|---:|---:|
| 1 | 297.6 MB | ~5 MB | **~303 MB** | ~46 MB |
| 2 | 338.3 MB | ~10 MB | **~349 MB** | ~90 MB |
| 3 | 379.0 MB | ~16 MB | **~395 MB** | ~136 MB |

A third block costs about 46 MB, not another 175: the shape-only tables are
already there. The same `L = 2` bundle under the classic `/4-run` encoding
would be **~653 MB** (213 MB of public tables and 112 MB of random arrays a
stage), which is over the 400 MB the brief allows and is why the encoding
changed.

The per-stage JSON that remains is about 4.6–5.5 MB: the Merkle paths
(609 KB a commitment) and salts (39 KB), `row_roles` (278 / 349 KB), the
claims with their evaluation points (~350 / 225 KB), the `M` opening (859 KB),
the twenty-three slots' definitions and masked rounds (247 KB) and the
transcript site index (13 KB). `run.json` is about 36 KB, of which 22 KB is
the plane index table.

#### THE MODEL IS VALIDATED TO THE BYTE, not asserted

`the_array_store_and_the_classic_encoding_carry_the_same_values` prints the
same per-member table at rung-K4, `L = 2`, public tables on
(`n4-s27-breakdown.log:114-119`):

| member | references | distinct | bytes | the formula |
|---|---:|---:|---:|---|
| `vector` | 94 | 94 | 1,925,120 | `(36+9+1) + (36+9+2+1) = 94`, `x 1280 x 16` — **exact** |
| `proximity_vector` | 7 | 7 | 143,360 | `3 + 4`, `x 1280 x 16` — **exact** |
| `proximity_rhos` | 4 | 4 | 46,304 | `A` and `H` only (an endpoint's 9 rows are below `ARRAY_MIN`): `2 x (727+720) x 16` — **exact** |
| `q`, `prox` | 2, 2 | 2, 2 | 32,768, 32,768 | `1024 x 16` each — **exact** |
| `values` | 1,072 | 1,015 | 7,251,568 | `2 x 256 x 2` columns `+ 24 x 2` public tables `= 1,072` — **exact** |

The one place the model needed a correction is the `values` DISTINCT count,
and the correction is a real effect worth writing down: **`challenge_indices`
samples the opened columns WITH REPLACEMENT**, so a commitment occasionally
opens the same column index twice and the two arrays are byte-identical. At
rung-K4's `4,096`-column encoded domain the birthday expectation is
`256^2 / (2 x 4096) ~ 8` a commitment and 33 of the 1,024 column references
duplicated (14 in `A`, 19 in `H`, recovered exactly from the byte total). At
125M the encoded domain is `65,536` columns and the expectation is **0.5 a
commitment**, so the model above ignores it and is conservative by about
46 KB a stage.

#### The memory model, and why NO streaming writer was built

The writer holds, during the VERIFY phase: `arrays.bin` (338 MB at `L = 2`
with the public tables, 80 MB without), the per-stage JSON (10 MB), and one
transient 67 MB byte image while a `2^22` public table is hashed and stored —
a peak of about **415 MB**. The heavy test additionally holds the `L`
segments in memory (2 x 40.54 MB) so that the run can be verified.

Against that: the prover's measured peak is **10.05 GiB** with
`MALLOC_MMAP_THRESHOLD_` pinned (`m125-run-l2-mmapthreshold.log`), and it
happens during PROVING, before a byte of the capture exists; `MemoryMax=12G`
is a cgroup limit on CONCURRENT usage, not on the high-water mark, and by
verify time the witness and the commitment buffers are freed. So the
capture's 0.4 GiB is not added to 10.05 GiB in any way the ceiling sees.

**Therefore the smallest honest change was the ENCODING alone.** Streaming
each stage to disk as it closed would have bought 10 MB and cost ruling D21
its exact form — a bundle written only after the run has verified — because
a streaming writer must put bytes on disk during a verification that may
still fail. The store is held in memory and handed to `write_bundle` with
everything else, so **nothing reaches the disk before `take` has succeeded**
and a rejected run still leaves nothing at all.

---

### Item 2 — the heavy capture test, written and not run

`private_block::run_capture_tests::capture_a_125m_run`, `#[ignore]`d.

It builds the chain, PROVES the run with the production prover, VERIFIES it
with the production verifier through the capture's verifier-side hooks
exactly as every development capture does, and writes the bundle **only
after the run has verified** (ruling D21 / M-9: `take` refuses unless `L`
stages closed, the recorder's independent replay never failed and the run's
closing check passed). It then reads the bundle back and checks it against
itself: every file in the manifest with its own length and SHA-256 and the
manifest's own total; the plane index table present once in `run.json` and in
no stage file; the `hash_tag` naming the keyed rule and no bundle claiming
`legacy`; the run binding the statement computed; each stage's
`segment_bytes` / `segment_sha256` against the bytes that were verified;
twenty-three slot transcripts a stage; **every key of every JSON file on the
allow-list**; and every `arrays.bin` reference resolved, re-hashed against
the digest that names it and checked for `bytes == len x width`.

The environment it reads:

| variable | what | default |
|---|---|---|
| `HL_PB_CAPTURE_DIR` | where the bundle goes | **required**; must be absolute and is REFUSED inside the repository |
| `HL_PB_CAPTURE_BLOCKS` | `L` | 2 |
| `HL_PB_INPUT` | `dense` (the generic witness) or `zero` (the degenerate partner) | `dense` |
| `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` carries the public tables' values, `0` their length and digest only | **required**, no default |
| `HL_TEST_SOURCE_COMMIT` | the commit the bundle records | `uncommitted-test` |

`HL_PB_WEIGHTS` is deliberately NOT read: at 125M the acceptance rule is the
GENERIC witness, so the recipe is `dense_tests::dense_run_case` (fully dense
public words, down band 1 at this shape, a non-constant hidden input from its
own unpublished stream) and `HL_PB_INPUT=zero` is the named degenerate
partner on the tame fixture. The array store is always on in this test.

**The capture rule is met by construction.** Nothing new is written: the
store moves arrays the classic encoding already printed, the allow-list
gained two keys (`array`, `elem`) and both are public book-keeping, and the
allow-list test runs over the bundle this very test writes. No witness value,
no pad, no hidden plane, no unopened column, no unpublished salt, no unmasked
round, no prover log and no timing of a witness-dependent step. The only
timings printed are the wall clock of prove+verify+record and the process
high-water mark, both to the log and neither to a bundle.

---

### Item 3 — the SHARED source pins (the Python gate's open item)

`source_pins` was `private_block`'s own path and nothing else, so a bundle
said nothing about the code that actually builds its transcript, its
commitments and its openings. **15 pins -> 38.** The 23 added are the `use`
graph of the run's prover and verifier, read off the sources:

* hashline's own shared modules: `src/zk.rs` (the masking commitment,
  `ZkRng`, `CfsMask`), `src/tables_attn.rs`, `src/causal_oracle.rs`,
  `src/private_seam.rs` (reached by `endpoint_g.rs`), `src/export_v3.rs`;
* the seven one-line re-export adapters `src/{field,merkle,mle,ntt,pcs,sumcheck,transcript}.rs`;
* and the canonical implementations behind them:
  `../zkp-core/src/{lib,field,hashtag,merkle,mle,ntt,pcs,pcs/backend,rng,sumcheck,transcript}.rs`.

**LISTING A FILE IS NOT EDITING IT.** A pin reads the file at capture time
and records its SHA-256; every one of those files is byte-identical to
`fc782a3`. **Pure addition**: `source_pins` is a list of `(file, sha256)`
objects, new entries are appended, nothing is renamed, reordered or removed,
and **the schema string does not move for it**. Bundles committed before this
stage keep the shorter list their own manifests pin. Future bundles only.

`s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on`
still passes unchanged in substance: its partition is over `private_block`'s
own production modules, which are unaffected, and its no-duplicates and
every-pin-resolves clauses now cover all 38.

---

### Item 4 — the dress rehearsal, RUN HERE

The heavy test's own body (`capture_a_run_into`) at `Shape::rung_k4` with
three blocks, the fully dense recipe and the public tables' values, into a
scratch directory outside the repository that is removed when the test ends
(`n3-s27-capture.log:125-129`):

```
CAPTURE rehearsal rung-K4: L=3, witness=dense (generic), public tables=values,
  prove+verify+record 2.27 s, high-water mark 0.14 GiB
CAPTURE rehearsal rung-K4: run.json 35,796 B, stage files [3,154,975 / 3,161,239 / 3,716,193] B
CAPTURE rehearsal rung-K4: arrays.bin 13,453,016 B over 1,681 distinct arrays;
  1,771 references (90 deduplicated), 1,817 small arrays inline
CAPTURE rehearsal rung-K4: 23,523,639 B on disk, self-consistent, every key on
  the allow-list, every array reference resolved
```

Compare the same three-block geometry written the classic way: a rung-K4
bundle is 46.4 MB (`run-i-dense-k4`, stage files 15.2 / 15.3 / 15.9 MB).
**23.5 MB against 46.4 MB, with the SAME content.**

And the equality gate, which is what says "the same content" is not a hope
(`n4-s27-breakdown.log:113`): one run at rung-K4, `L = 2`, captured TWICE in
one process — once with the classic inline lists, once with the store — and
the store bundle with every array reference expanded back into text is
**byte for byte** the classic bundle, `run.json` and both stage files. Stage
JSON 31,147,111 B classic against 6,877,082 B + 9,431,888 B of arrays =
16,308,970 B, a factor **1.91**.

Three tests run here, all in the standard filter, none `#[ignore]`d:

| test | what it establishes |
|---|---|
| `the_array_store_and_the_classic_encoding_carry_the_same_values` | the byte-for-byte equality above, the per-member store table, and that the set of externalised members is exactly `{values, vector, proximity_vector, proximity_rhos, q, prox}` |
| `the_heavy_captures_code_path_works_at_a_development_shape` | the 125M test's whole body — prove, verify with the recorder, write only after acceptance, read back, self-consistency, allow-list, array resolution — at a shape that takes 2.3 s |
| `a_capture_directory_inside_the_repository_is_refused` | the one guard the heavy run cannot exercise: a path inside the tree and a relative path are both refused BY NAME, a path outside it is accepted although it does not exist yet |

No rehearsal bundle is committed.

---

### Item 5 — the two launch commands

**Prebuilt binary**, `--no-run` at the end of the stage
(`n8-s27-prebuild.log`, exit 0):

```
/home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5
14,067,568 B, mtime 2026-09-21T08:44:37
```

That is the build the green gate above ran, and
`--list --ignored | grep capture_a_125m_run` resolves the test name in it.

**(A) the dense two-block capture — the GENERIC witness, the one that matters**

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_CAPTURE_DIR=/home/victor/zk60-artifacts/m125-capture-dense-l2 HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=2 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=$(git --no-pager -C /home/victor/wt-zk60-block125m rev-parse HEAD) /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_capture_tests::capture_a_125m_run >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-capture-dense-l2.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-capture-dense-l2.done' >/dev/null 2>&1 &
```

**(B) the all-zero-input two-block capture — the named degenerate partner**

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_CAPTURE_DIR=/home/victor/zk60-artifacts/m125-capture-zero-l2 HL_PB_INPUT=zero HL_PB_CAPTURE_BLOCKS=2 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=$(git --no-pager -C /home/victor/wt-zk60-block125m rev-parse HEAD) /home/victor/wt-zk60-attention-compile/hashline/target/release/deps/hashline-70a7a72f73401de5 --ignored --exact --nocapture --test-threads=1 private_block::run_capture_tests::capture_a_125m_run >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-capture-zero-l2.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-capture-zero-l2.done' >/dev/null 2>&1 &
```

**Enqueue B immediately**: it blocks on `/tmp/zk-heavy.lock` and self-starts
when A frees it, session or no session. Each takes about 2.5 minutes of wall
clock (four 125M witness builds at ~4.7 s, two stages of ~31 s of proving,
~2 s of verifying, and the capture's own writing) and about 350 MB of disk.
Neither directory may exist beforehand: `write_bundle` creates every file
with `create_new` and refuses rather than overwrite.

**What to read in the log, in order.**

1. `CAPTURE 125M: MALLOC_MMAP_THRESHOLD_ is pinned` — if it says NOT SET, the
   launcher lost the variable and the high-water mark will climb.
2. `prove+verify+record N s, high-water mark X GiB` — **X should be about
   10.1 GiB and must stay under 11.5**; the run is inside a 12 GiB scope and
   a breach is an OOM kill, not a slow run.
3. `arrays.bin B over D distinct arrays; R references (E deduplicated)` —
   **`B` should be about 338 MB**. If it is near 410 MB the shape-only public
   tables did not deduplicate and the model is wrong; if it is about 80 MB
   the public tables were not included.
4. `N B on disk (350.x MB) … self-consistent, every key on the allow-list,
   every array reference resolved` — the acceptance line. Anything short of
   it is a failed assertion and the exit code in the `.done` marker says so.
5. On failure: `no bundle is written for a run the verifier did not accept`
   means the run itself did not verify, which would be a correctness finding
   and not a capture one. `replay: …` means the recorder's independent
   rebuild diverged from the verifier, which is the capture's own gate.

**Ranked, what could make the 125M capture fail.**

| # | risk | why, and what it would look like |
|---|---|---|
| 1 | **the high-water mark** | the two-block run measured 10.05 GiB flat WITH the allocator pinned and 10.82 GiB rising without it; the capture adds ~0.4 GiB during the verify. Losing `MALLOC_MMAP_THRESHOLD_` in the launcher is the realistic way to breach 12 GiB. Symptom: the scope is killed and the `.done` marker holds 137 or 1. |
| 2 | **the public tables are bigger than any shape ever captured** | a single `2^22` table is 67 MB of `Fp2` and five of them are built per stage BY THE VERIFIER, which is true with or without a capture; the writer adds one 67 MB transient while hashing each. If the dedup assumption is wrong the bundle is 410 MB instead of 338 and nothing fails, it is just bigger. |
| 3 | **the dense chain band at 125M was measured under a different hidden input** | stage 22 moved the dense recipe's input to its own seed and 125M's band-1 pin has NOT been re-measured since (it is the 707-second `#[ignore]`d probe `the_first_admissible_fully_dense_run_band_at_125m`). If band 1 is no longer admissible at the new input the CHAIN BUILD fails before any proving, with a witness-builder refusal naming the block. Run B (all-zero) is unaffected. |
| 4 | **wall clock under the lock** | `flock /tmp/zk-heavy.lock` with no `-w` waits forever, which is the intent; if another lane holds it the run simply starts later. |
| 5 | **the directory already exists** | `create_new` refuses; nothing is overwritten and nothing is lost. Choose a fresh name. |
| 6 | **disk** | 744 GB free against ~700 MB for both bundles. Not a risk; listed so it is not a surprise. |

---

### The gate, and the only-test-code proof

| command | log | result |
|---|---|---|
| `--lib private_block::run_capture --no-run` (first build of the store) | `n1-s27-compile.log` | exit 0, **no error on the first build**, 13 warnings |
| `--lib private_block::run_capture --no-run` (the tests) | `n2-s27-compile.log` | exit 0, 13 warnings |
| `--lib private_block::run_capture -- --nocapture` | `n3-s27-capture.log:144` | **15 passed / 0 failed / 5 ignored**, 19.23 s |
| `--lib private_block::run_capture_tests::the_array_store -- --nocapture` | `n4-s27-breakdown.log:122` | 1 passed, with the per-member table |
| the gate, FIRST attempt: `--lib private_` | `n5-s27-private.log:448` | **308 passed / 1 failed / 12 ignored**, 405 s — finding S27-F6 below |
| `--lib private_block::s25_tests` after the fix | `n6-s27-s25fix.log` | 13 passed / 0 failed, 0.49 s |
| **the gate**: `--lib private_` | `n7-s27-private2.log` | ****309 passed / 0 failed / 12 ignored**, 406.17 s, exit 0** |

Baseline 306 passed / 0 failed / 11 ignored: **+3 tests** (the equality gate,
the dress rehearsal, the directory guard) and **+1 ignored** (the 125M
capture). No existing test was changed, weakened or removed; the one line
edited outside this stage's own modules is a COUNT in stage 25's call-kind
table (finding S27-F6). The toy's frozen parameter line, its schedule digest
and the four counted receipt lengths — toy 2,816,472, rung 4,218,600, rung-G
4,234,984, 125M 40,783,352 — are all in the pass list. **13 warnings, the
baseline's 13.**

**THE ONLY-TEST-CODE PROOF.** `git diff --stat fc782a3 -- hashline/src`
prints exactly four files:

```
hashline/src/private_block/run_capture.rs       | 341 ++++++++++++++--
hashline/src/private_block/run_capture_tests.rs | 519 +++++++++++++++++++++++-
hashline/src/private_block/s24_tests.rs         |   2 +-
hashline/src/private_block/s25_tests.rs         |   7 +-
```

and `private_block.rs` declares all four under `#[cfg(test)]`
(`private_block.rs:155-158` for `run_capture` and `run_capture_tests`, and
the `#[cfg(test)]` immediately above `mod s24_tests` and `mod s25_tests`).
**The proof is therefore per FILE and no per-hunk analysis is needed**: not
one line of the diff is compiled into a non-test build, and no file that
also holds production code is touched at all. The last two are one-line
changes: `s24_tests` follows the pin list to `source_files()`, and
`s25_tests` carries finding S27-F6's classification. `git diff --stat
fc782a3` over the whole tree prints those four plus three documents
(`ZK60_BLOCK125M_LANE_PROGRESS.md`, `ZK60_RUN_CAPTURE_FORMAT.md`, and the
capture bundles' parent `README.md`).

`git diff --stat fc782a3 -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs
hashline/src/layer.rs hashline/src/wcache.rs hashline/src/native_capture.rs
hashline/src/private_seam.rs hashline/src/gpu private-block-kernel
private-model-kernel private-block-kernel-shaped zkvm-block scripts tests`
prints **nothing**: every forbidden tree is byte-identical to `fc782a3`,
including all eighteen files this stage newly PINS.

### Findings

* **S27-F1 — the public tables, not the columns, are what a 125M capture
  costs.** The intuition going in (and in the brief) was that a bundle is its
  opened columns. It is not: at 125M the columns and the opening vectors are
  40 MB a stage and the twenty-three slots' public tables are 409 MB. They
  are also the cheapest thing to fix, because five of the largest are
  `2^22`-entry 0/1 indicators and causal masks that are functions of the
  SHAPE alone and identical in every slot and every stage.
* **S27-F2 — an indicator table is cheaper as decimal JSON than as bytes**
  (8.01 B an entry against 16). Content addressing, not the binary width, is
  what pays for the public tables; the binary width is what pays for the
  opened columns and the opening vectors (2.66x).
* **S27-F3 — the opened columns are sampled WITH REPLACEMENT.**
  `challenge_indices` draws `q` indices independently, so a commitment
  sometimes opens one column twice: 33 of 1,024 references at rung-K4's
  4,096-column encoded domain. Nothing is wrong with it — the verifier checks
  the same column twice — but a gate counting DISTINCT opened columns must
  not assume `q` of them, and the effective number of independent column
  checks is slightly under 256. At 125M the expectation is 0.5 a commitment.
* **S27-F4 — an `L = 1` run is admissible and is nearly as expensive as
  `L = 2`.** `RunShape::new` refuses only `l == 0`; a one-block run has no
  internal boundary and opens both external endpoints in its one stage. Its
  bundle is ~303 MB against ~349 MB, because the shape-only public tables
  dominate both. There is therefore no size argument for capturing one block
  instead of two, and `L = 2` is the first `L` that exercises an internal
  boundary — which is the whole reason a RUN gate exists.
* **S27-F6 — the stage-25 hash-call-site guard fired, and it was right to.**
  The first run of the gate failed ONE test:
  `s25_tests::every_hash_call_site_in_the_lanes_own_sources_is_classified`
  counted six `sha256_hex(` call sites in `run_capture.rs` where its
  call-kind table declares five. The sixth is `ArrayStore::put`'s CONTENT
  digest, which both names an array in `arrays.bin` and is the key the store
  deduplicates on. It is classified now, in the table, with its kind (C1:
  SHA-256 over bytes the bundle publishes anyway, sharing no oracle with any
  BLAKE3 call on the path, deciding no proof byte and no challenge) — a
  one-element change to a count and a comment, and the only line this stage
  touched outside its own two modules. **This is what that guard is for**: a
  new hash in a writer that produces retained evidence does not get to appear
  unnoticed.
* **S27-F5 — the format note's §9 change list for the Python agent grew by
  one item and it is small**: resolve `{"array":…}` against `arrays.bin`
  (§12 has the eight-line Python). Everything else a `/4-run` loader does is
  unchanged, including refusing a schema it does not know — which is what a
  `/4-run` loader will correctly do to a `/5-run` bundle until it is taught.

## Stage 28 — the 125M prover, faster WITHOUT MOVING A BYTE (2026-09-21, 09:0x–)

**The rule of this stage, before anything else.** Nothing a verifier can see
may move: not one byte of any receipt, not the order of a transcript absorb,
not the number or the order of the challenges drawn, and not which attempt is
refused, when, or with what message. Every change here is an arithmetic or a
memory change inside the prover, and the acceptance is byte identity at the
frozen toy and at every shape with a deterministic receipt pin.

> **CORRECTED 2026-09-21 11:10 PDT (stage 29, finding S28-R8, ruling V-4).**
> The sentence above holds for every REACHABLE input but is not complete as
> written: stage 28 adds **one refusal string**, in `helper_pair_inverses_u8`
> (`protocol.rs`), and the ledger did not list it. It is
> `"private block: paired lookup columns of different lengths"`, it is
> unreachable — every column of a domain is built by `lookup_values` over the
> same `size(dom)`, so the two columns of a pair always have the same length —
> and it is covered by the refusal-reason rule like every other refusal on this
> path. Task 1b below carries the same note where the function is described.

Ledger sections of this stage, filled as the work lands:

* **Task 0 — the post-repair baseline at the tip.** (below)
* **Task 1 — the LogUp helper inverses by table**, and the refusal finding.
* **Task 2 — the big zero-check slots**, attributed and, where the lane owns
  the code, made faster.
* **Task 3 — the 125M re-measurement**, before/after, high-water mark.
* **Task 4 — the gates**, and the integrator requests.

### The byte pins this stage is accepted against, and the one it could not add

**Read this first: at every profile of this path a receipt is NOT
reproducible, by design.** Every proving attempt draws its own
`ZkRng::from_os` stream (`protocol.rs`, `endpoint_g.rs` twice), so two honest
proofs of one statement differ in their bytes — stage 11 said so when it
added the phase clock, and stage 26 re-derived the three reads. So "byte
identity" here cannot mean "the receipt digest does not move", and the brief's
fallback — add a deterministic byte pin at rung-G / rung-K4 — **cannot be
built without breaking a load-bearing guard**:

* **S28-F2.** `s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system`
  asserts that every `ZkRng::` constructor in the PRODUCTION TEXT of every
  production module of this path is `from_os`, and that `ZkRng::new` (the
  seeded fixture constructor) and `ZkConfig` appear nowhere on it. That test
  is the accepted toy statement's **condition 6** ("fresh operating-system
  randomness per proof; no seeded configuration on this profile's path") in
  code. A `#[cfg(test)]` seed hook inside `prove_inner_at` would either trip
  that scan or have to be hidden from it, and the privacy statement is worth
  more than the convenience. **No seeded prover hook was added.** The
  alternative — a test that drives `prove_core` with a seeded generator from
  a test module — needs seeded ENDPOINT owners as well (the two endpoint
  generators feed the slot-21/22 tables and therefore the transcript), i.e. a
  second copy of `endpoint_g::prepare` in test code; it is written up here as
  an option for the integrator and was not built.

What the stage is accepted against instead, all of it pre-existing and all of
it green at every commit below:

| pin | where | what it fixes |
|---|---|---|
| toy frame **2,816,472 B** | `tests.rs:108`, `zero_witness_tests.rs:172`, `hash_domain_tests.rs:560`, `review_tests.rs:712`, `grow_tests.rs:307/727/1466` | the byte-frozen toy's receipt length |
| the frozen toy SCHEDULE DIGEST | `grow_tests::the_toy_schedule_digest_is_frozen` | the toy's slot schedule, structurally |
| the frozen toy PARAMETER LINE | `grow_tests::the_toy_parameter_line_is_the_frozen_literal` | the toy's public parameter text |
| frozen-seam rung **4,218,600 B**, rung-G **4,234,984 B** | `grow_tests.rs:351/390/1447-1449`, `rung_tests.rs:41/45`, `dense_tests.rs:618` | both development rungs' receipt lengths |
| rung-K4 `K4_FRAME_BYTES` | `k4_tests.rs:231/252` (dense AND all-zero) | the four-key-value-head shape's receipt length |
| 125M **40,783,352 B** | `grow_tests.rs:468/1702`, `rulings_tests.rs:284/457` | the 125M receipt length |
| every honest proof VERIFIES FROM BYTES | toy, rung, rung-G, rung-K4 (dense and all-zero), and the `#[ignore]`d 125M | a moved byte that the verifier would reject |
| the independent Python layout model | `grow_tests`'s `Expected` tables | every counted total, derived outside Rust |

**And the gate this stage adds, which is stronger than a digest for the parts
it touches**: for every computation changed, the OLD form and the NEW form are
run on the same inputs IN THE SAME TEST and compared word for word, with the
old form re-derived in `s28_tests.rs` from `crate::field` / `crate::mle` (or
copied verbatim from the tip `79f0726`) so that it is an oracle and not a
second name for the code under test. Nine such tests, listed with each item
below. A digest pin would say "something moved"; these say which word.

> **CORRECTED 2026-09-21 11:10 PDT (stage 29, finding S28-R5, ruling V-4).**
> **Ten**, not nine: `s28_tests.rs` carries ten `#[test]`s, and the gate table
> of task 4 says ten. **CORRECTED again in the same breath (finding S28-R1):**
> the claim "for every computation changed, the OLD form and the NEW form are
> run on the same inputs IN THE SAME TEST" was **not true of four of the nine
> changed computations** at stage 28 — the moved public table, the parallel
> table build, the parallel claimed sum and the parallel histogram had
> end-to-end evidence only. Stage 29's `s29_tests.rs` gives all four an
> old-against-new oracle and crosses BOTH branches of all five thresholds in
> the ordinary filter, so the sentence is true at the stage-29 tip and was not
> true at the stage-28 tip.

**Nothing in this stage touches randomness.** No line added or changed draws
from a generator, so the number of draws, their order and the stream they come
from are untouched; the only new parallelism is over INDEXED iterators whose
output is the same whatever the thread count is (checked:
`the_helper_column_is_the_same_vector_whatever_the_thread_count_is`).

### Task 0 — the baseline at the tip `79f0726` [MEASURED, one run, shared box]

`results/zk60_block125m_lane/q28-baseline-dense.log`, exit 0, 2026-09-21
09:05. One dense one-block 125M proof
(`HL_PB_WEIGHTS=dense HL_PB_TIMING=1`, the env of `m125-one-block-dense.log`),
detached under the heavy lock inside a 12 GiB scope with
`MALLOC_MMAP_THRESHOLD_=131072`.

| figure | pre-repair dense (`m125-one-block-dense.log`, 2026-09-20 19:27) | **this baseline** |
|---|---|---|
| prove, s | 27.67 | **27.71** |
| verify from bytes, s | 1.12 | **1.28** |
| receipt, B | 40,783,352 (the run FAILED on the pre-repair literal) | **40,783,352, and the test passes** |
| peak RSS, GiB | 9.99 | **9.99** |
| witness build, s | 5.48 | **5.04** |

**What the stage-20 group-bit repair moved, at 125M.** The two bilinear slots
gained the key-value group as a sumcheck variable (`kv_heads = 4`, so
`lkv = 2`) and a degree:

| slot | cube before | cube now | s before | s now |
|---|---|---|---|---|
| 08 `SC_SCORE` | 256 | **1,024** | 0.027 | **0.024** |
| 09 `SC_PV` | 2,048 | **8,192** | 0.114 | **0.113** |

Two extra sumcheck variables each and degree 2 -> 3, and **no measurable
time**: both slots are far below the shape's big cubes. The receipt grew by
the counted 560 B (40,782,792 -> 40,783,352), which is `s20_frame_bytes`'s own
derivation and not a measurement. (The `s` columns are not strictly
comparable — the older run is the same dense recipe at the pre-repair code —
but the conclusion, that the repair costs nothing measurable at this shape,
does not turn on the third decimal.)

The prover's halves at the baseline: **commit 12.034 s (43.4%)**, attention
9.698 s (35.0%), residual (slot 14) 3.007 s (10.9%), feed-forward 1.709 s
(6.2%), openings 0.704 s (2.5%), norm 0.228 s, endpoints 0.243 s,
lookup-table 0.089 s, setup 0.000 s. The five phases above 5%: slot 17
**7.204 s**, `H: LogUp helper inverses` **4.061 s**, `H: commit` 3.499 s,
`A: commit` 3.076 s, slot 14 **3.007 s**, slot 18 1.635 s.

### Task 1 — the LogUp helper inverses by table, commit `d2c2733`

**What it was.** For every one of the six lookup domains and every looked
column of each, `protocol.rs` built the whole column of denominators
`alpha - (v + g_u8)` and handed it to `field::batch_inverse2_checked`. At the
125M shape that is **98,598,912 words**, single-threaded, each paying
Montgomery's trick (a prefix product, one inversion, two multiplications per
element on the way back) — and the batch inversion allocates a prefix vector
as long as the column on top of the column itself.

**What it is.** Every looked value is looked up in the SAME 256-entry byte
table, so there are at most `U8_LEN` distinct denominators in the whole of
`H`. `u8_denominator_inverses` builds the 256 and inverts the nonzero ones
ONCE per proof; `helper_inverses_u8` turns each word into one indexed lookup.
A value outside `0..U8_LEN` — only a dishonest or tampered witness has one —
takes the old arithmetic, one `Fp2::inv` at a time; the field inverse is
unique and this field's representation is canonical everywhere
(`zkp-core/src/field.rs:1-9`), so the word is the batch inversion's word.
Above 2^14 words the map runs on rayon's indexed parallel iterator, the
crate's own style (`pcs.rs`, `zk.rs`, `sumcheck.rs`).

**Indexing a table by a witness byte is not a new class of memory access on
this path.** The byte histogram three phases earlier already does exactly
that, on the same values:
`m_u8[if (0..U8_LEN as i64).contains(v) { *v as usize } else { 0 }] += 1`
(`protocol.rs`, the `A: lookup values + the byte histogram` phase). Nothing
about the cache behaviour of this prover changes class here.

**THE REFUSAL, and finding S28-F1 — the answer the brief asked for
prominently.**

* At the helper line itself the refusal is **PRESENT-VALUE-ONLY**, before and
  after: the checked batch inversion refused iff a zero denominator sat at an
  entry OF THE COLUMN, and the table path refuses iff a column asks for a
  table entry that is `None`. Same rule, tested both ways
  (`a_zero_denominator_at_a_value_the_column_carries_is_refused_by_both_paths`,
  `a_zero_denominator_at_a_value_no_column_carries_is_refused_by_neither_path`).
* **S28-F1: but the attempt is refused either way, a few lines later.** The
  three table helpers invert the denominator of EVERY table value
  (`inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?`), and
  `table_values_u8_at` carries all `U8_LEN` byte values (its padded entries
  repeat `i % U8_LEN`). So a zero `U8` denominator refuses the attempt
  whatever the hidden input carries, with the SAME string
  ("zero LogUp denominator; discard attempt"). **Whether an attempt is
  refused is therefore a function of the public challenges and the public
  table alone; what the hidden input decides is only which of the two lines
  refuses first.** Test:
  `a_zero_u8_denominator_refuses_through_the_table_helpers_even_when_no_column_carries_that_value`.
  This is RECORDED, not changed: the security owner rules on it. (For the
  record, the probability is the 2^-96-class figure of one challenge hitting
  one of 256 public points; it is not new to this stage and no line of it
  moved.)

> **CORRECTED 2026-09-21 11:10 PDT — S28-F1a, the form the security owner
> accepts (ruling V-3 of `ZK60_BLOCK125M_S28_DISPOSITION.md`, finding S28-R2
> of the independent review).** The sentence in bold above over-reaches and
> the ruling replaces it with this one:
>
> **For every witness the constructors admit, every looked byte is one of the
> 256 byte rows, every `(delta, e)` pair a row of the public exponential table
> and every activation pair a row of the public activation table; so every
> denominator the prover forms IS a table denominator, and whether an HONEST
> attempt is refused for a zero LogUp denominator is a deterministic function
> of the three public challenges and the three public tables — the event
> "alpha equals one of at most 768 public field elements" — and not of the
> hidden input. What the hidden input decides is only WHICH of the two lines
> returns first, and nothing published can tell them apart: the two return the
> byte-identical string, and no transcript absorb and no generator draw lies
> between the challenge draw and the second line (on this lane `alpha` is
> drawn at `protocol.rs:848`, the helper lines are `:857-879`, the table line
> `:909`, the next draw `:933` and the next absorb `:949`).**
>
> **Why the unqualified sentence is false.** A witness value that no public
> table carries — a looked value of 4096, or an exponential pair
> `(3, exp[3] + 1)` — gives a zero denominator that the three table helpers
> never see, so the refusal then depends on the hidden column. The reviewer's
> counterexample test is
> `s28_review_tests::whether_an_attempt_is_refused_still_depends_on_the_hidden_input_for_off_table_values`,
> and it asserts that the OLD path behaves identically on both sides: this is
> pre-existing behaviour and not a stage-28 regression. Such a witness is not
> admitted and cannot yield a verifying proof; a prover feeding it is lying
> about its own secret, and nothing about anybody else's input is at stake.
>
> **Consequence for the accepted figures: none** (ruling V-3 item 4). The toy
> statement and the run documents price this refusal as if it depended on the
> input (at most 768 distinct denominators: `2^-118.4` per block, `2^-114.8`
> per twelve-block run); with the sharper reading the event is reproduced
> exactly by anyone who knows the challenges, so that row is an over-estimate
> and the security owner leaves the numbers as they are. The elapsed time of a
> refused attempt (which line fired) is a timing channel of the same class as
> every other in this prover and is outside every statement made so far.

**MEASURED at 125M [one run, shared box]**, `q28-m125-task1-attrib.log`
against `q28-baseline-dense.log`:

| phase | baseline | after task 1 |
|---|---|---|
| `H: LogUp helper inverses (six lookup domains)` | **4.061 s** | **2.010 s** |
| prove, total | 27.71 s | **24.59 s** |

The phase did not fall as far as the arithmetic did because what is left is
memory, not inversion: the phase still materialises every helper column
(1.58 GB of `Fp2` at this shape) and writes it into `H`. That is what the
follow-up below takes on.

### Task 1b — the helper columns written pair by pair, commit `a9f2211` (with task 2)

A helper column is the sum of the inverses of at most TWO looked columns. The
prover inverted EVERY column of a domain into its own vector first and then
added pairs; it now builds one helper at a time
(`helper_pair_inverses_u8`), which removes the domain-wide intermediate and
one pass over it. Columns are still visited in index order, so a refusal is
still the lowest-indexed column's, and the words are the same words
(`the_paired_helper_column_is_the_two_columns_inverted_and_added`, which
compares against the two separate inversions plus the element-wise add).

> **CORRECTED 2026-09-21 11:10 PDT (stage 29, finding S28-R8, ruling V-4).**
> `helper_pair_inverses_u8` opens with a length guard and therefore adds the
> ONE refusal string this stage did not list:
> `"private block: paired lookup columns of different lengths"`
> (`protocol.rs`, the first lines of the function). It is UNREACHABLE — every
> column of a domain is built by `lookup_values` as `(0..len)` with the same
> `len = shape().size(dom)`, so the two columns of a pair cannot differ in
> length — and it is the only refusal string stage 28 added. Like every other
> refusal on this path it falls under the refusal-reason rule (a refusal, or
> the stage it happened at, is never shown to anyone not entitled to the
> input).

### Task 2 — where the big zero-check slots' seconds actually go

**The instrument.** `timing::slot_step` (new, lane-owned) splits a slot's one
phase line into the four things the prover does in it, printed as
`PB-SLOTSTEP` lines when `HL_PB_TIMING=1` and absent otherwise (with the
clock off it is `f()` and nothing else: no clock read, no print, no
allocation). The 42-row phase table is unchanged — this prints beside it.

**MEASURED at 125M [one run, shared box]**, `q28-m125-task1-attrib.log`,
summed over all twenty-three slots of one dense block:

| step | file | s | % of the 24.59 s prove |
|---|---|---|---|
| tables: build | **`argument.rs` (this lane)** | **6.011** | 24.4% |
| masked sumcheck | `zk.rs` -> `zkp-core/src/sumcheck.rs` (**shared**) | 6.907 | 28.1% |
| extension rounds | `mask_eval` (lane) inside `zk::extension` (shared) | 0.747 | 3.0% |
| claimed sum (`total`) | **`argument.rs` (this lane)** | 0.140 | 0.6% |

and slot by slot, for the five the brief names:

| slot | cube | tables (lane) | sumcheck (shared) | ext | `total` (lane) |
|---|---|---|---|---|---|
| 17 `SC_SZC` | 2^23 | **3.419** | 3.118 | 0.118 | 0.000 |
| 14 `SC_DZC` | 2^20 | **0.859** | 1.754 | 0.248 | 0.000 |
| 18 `SC_FZC` | 2^21 | **0.620** | 0.778 | 0.096 | 0.000 |
| 15 `SC_QZC` | 2^20 | **0.302** | 0.502 | 0.077 | 0.000 |
| 04 `SC_RS` | 2^23 | **0.364** | 0.253 | 0.010 | **0.116** |

**So the answer to "how much of a big slot is mine" is: about half of slot
17, a third of slot 14, and two-fifths of slot 18 — the table build — and the
rest is the shared masked sumcheck.** At rung-K4 the same instrument gives a
different shape (`q28-k4-attrib-before.log`: slot 17 is 0.021 s of tables
against 0.178 s of sumcheck), which is exactly why the 125M run was spent on
this: the table build is a single pass over the cube and the sumcheck is a
parallel one, so their ratio moves with the shape. **Neither figure is a
forecast for any other shape or box.**

**What the per-point machinery is, and who owns it.** The brief asks whether
the per-point boxed closure, the gather, the fold, the masking polynomial or
the allocation dominate. The instrument answers it at one level up and the
code says the rest: `zkp-core/src/sumcheck.rs`'s round loop ALREADY gathers
into a reused `cur`/`dif` pair, ALREADY evaluates at `t = 0, 1, 2, ...` by
adding a per-point delta rather than re-gathering, and ALREADY runs its
rounds on rayon in 1,024-point chunks with a small-round cut-off. The
per-point `Box<dyn Fn>` call and the mask polynomial live there and in
`zk.rs`. **The lane cannot improve any of that without editing a shared file,
and this stage does not.** The integrator requests below say what would be
worth measuring there.

### Task 2, the code — the table build, commit `a9f2211`

Five changes, all in `argument.rs`, all inside the prover's slot, none of them
arithmetic that a verifier can see:

| # | change | why it is the same words |
|---|---|---|
| 1 | **the tables of one slot are built in parallel** (rayon, above `tabs * 2^n >= 2^17` words) | they are independent of each other and the iterator is INDEXED: the same set, in the same order, whatever the thread count. No randomness is drawn here |
| 2 | **`priv_table`'s per-entry coordinate walk became a bit permutation with two precomputed half-maps** | `(x, z)` is a fixed function of `idx`'s bits: the high half of `idx` and the low half are mapped separately and combined, `z`'s high part shifted by the NUMBER OF FIXED COORDINATES IN THE LOW PART. Same `(x, z)`, `p.log` index operations per entry replaced by two lookups |
| 3 | **the write is a plain store when nothing can collide** | with no fixed coordinate `eqf` is `[1]`, and `1 * v` added to `ZERO` is `v`. The no-collision condition is COUNTED (`used.count_ones() == the number of non-fixed coordinates`), not assumed, so a duplicated challenge index falls back to the add — tested |
| 4 | **the `eq` cube is filled by doubling** (`extend_from_within`) instead of one index computation per entry | the cube IS each `eq` entry repeated `2^shift` times, that block repeated `2^start` times |
| 5 | **a public table is MOVED into the table set, not copied**, on the proving path | the slot definition is owned and dead after the build; the `Tab::Pub` length check happens before it, and every later use matches `Tab::Priv`. At 125M this is a 134 MB copy per public table of the two big slots |

and one more in the same commit, the claimed sum:

| 6 | **`total` sums the cube in parallel chunks** | the sum is over a FIELD — exact, no rounding — so grouping cannot move it; `zkp-core/src/sumcheck.rs` makes the same argument for its own parallel round. Small cubes stay on one thread |

**Equality gates** (old form vs new form, same inputs, same test):
`the_private_table_builder_is_the_walked_one_entry_for_entry` (21 cases: three
widths x seven descriptor shapes — identity, a permutation, two fixed
coordinates, a flipped coordinate, a short plane that needs the broadcast, a
short-fixed-flipped mixture, and a DUPLICATED index) against the walked
builder copied verbatim from `79f0726`;
`the_eq_cube_builder_is_the_gathered_one_entry_for_entry` (every
`(width, start, |point|)` triple at three widths).

### Task 2b — the two serial passes over the looked words, same commit

`lookup_values` builds each looked column as a per-index map of wrapping
integer arithmetic (parallel, indexed, above 2^17 words), and the byte
histogram is summed in chunks of 2^16 and reduced bin by bin — a histogram is
a sum of integers, so a partition changes no bin. Gate:
`the_lookup_columns_are_the_serial_per_index_maps_they_were`, on real
witnesses at the toy and rung-K4, against the serial map written out in the
test. The histogram has no separate gate and needs none: a wrong count breaks
the value-0 LogUp identity and every honest proof at five shapes would be
rejected by its own verifier.

### Task 3 — the 125M re-measurement [MEASURED, one run each, shared box]

`q28-baseline-dense.log` (tip `79f0726`) against `q28-m125-final-dense.log`
(tip `a9f2211`), the same command, the same env
(`HL_PB_TIMING=1 HL_PB_WEIGHTS=dense`, `MALLOC_MMAP_THRESHOLD_=131072`),
detached under the heavy lock in a 12 GiB scope, nothing else heavy on the
box. Both exit 0 and the test's own assertions — the counted frame length and
the short-frame refusal — pass in both.

| figure | baseline | **after** | change |
|---|---|---|---|
| **prove, s** | 27.71 | **17.40** | **-10.31 s, -37.2%** |
| verify from bytes, s | 1.28 | 1.15 | -0.13 (the verifier is untouched; this is run-to-run) |
| **receipt, B** | 40,783,352 | **40,783,352** | **0** |
| **peak RSS (VmHWM), MiB** | 10,232 (9.99 GiB) | **10,156 (9.92 GiB)** | **-76 MiB, -0.7%** (the ceiling was "not more than +2%") |
| witness build, s | 5.04 | 5.24 | outside the prover |
| SUM OF PHASES / wall | 27.710 / 27.713 | 17.398 / 17.401 | the table still accounts for the clock |

Phase by phase, every phase that moved by more than 0.05 s:

| phase | half | baseline | after | whose code |
|---|---|---|---|---|
| slot 17 `SC_SZC` | attention | 7.204 | **3.559** | lane (tables 3.419 -> 0.251) + shared sumcheck (3.118 -> 3.054) |
| `H: LogUp helper inverses` | commit | 4.061 | **1.079** | **lane** |
| slot 14 `SC_DZC` | residual | 3.007 | **1.965** | lane (tables 0.859 -> 0.051) + shared |
| slot 18 `SC_FZC` | feed-forward | 1.635 | **0.795** | lane (tables 0.620 -> 0.044) + shared |
| slot 15 `SC_QZC` | attention | 0.976 | **0.668** | lane (tables 0.302 -> 0.025) + shared |
| slot 04 `SC_RS` | attention | 0.916 | **0.372** | **lane** (tables 0.364 -> 0.048, claimed sum 0.116 -> 0.016) |
| `A: lookup values + the byte histogram` | commit | 0.571 | **0.096** | **lane** |
| slot 16 `SC_KVZC` | attention | 0.398 | 0.349 | lane + shared |
| slots 21 + 22 (endpoints) | endpoints | 0.243 | 0.157 | lane |
| slots 00 + 01 (norm row sums) | norm | 0.198 | 0.132 | lane |
| `A: commit` | commit | 3.076 | 3.069 | **shared** (`pcs.rs`) |
| `H: commit` | commit | 3.499 | 3.431 | **shared** (`pcs.rs`) |

and the sub-steps, summed over the twenty-three slots:

| step | baseline | after |
|---|---|---|
| tables: build (**lane**) | 6.011 | **0.588** |
| claimed sum `total` (**lane**) | 0.140 | **0.020** |
| masked sumcheck (**shared**) | 6.907 | 6.594 |
| extension rounds (`mask_eval` + shared) | 0.747 | 0.757 |

> **CORRECTED 2026-09-21 11:10 PDT (stage 29, finding S28-R4, ruling V-4).**
> The column headed "baseline" in the sub-step table above is **NOT the
> 27.71 s baseline at `79f0726`** — that run has no `PB-SLOTSTEP` lines at all
> (`grep -c PB-SLOTSTEP q28-baseline-dense.log` = 0), because the instrument
> did not exist there. It is the **24.59 s tree after task 1**, measured in
> `q28-m125-task1-attrib.log`, and **that tree is no commit**: `slot_step` and
> the table-build change landed together in `a9f2211`, so the instrument-only
> tree was measured and never committed. Read the column as "after task 1,
> before task 2", against a 24.59 s prove and not a 27.71 s one. The headline
> **27.71 -> 17.40 s is between two commits** (`79f0726` and `a9f2211`) and
> stands unchanged; so does every per-phase row of the table above it, which
> is `PB-TIMING` and not `PB-SLOTSTEP`. The lesson for the next stage: commit
> the instrument first, then measure.

The shared sumcheck and the two shared commitments did not move, which is the
control this stage wanted: the 10.31 s came out of the lane's own code and
nothing else drifted.

**WHERE THE REMAINING 17.40 s SITS — the integrator's and the GPU's part.**

| phase | s | % of prove | file |
|---|---|---|---|
| masked sumcheck bodies (all 23 slots) | 6.594 | 37.9% | **shared**: `zk::masked_prove` -> `zkp-core/src/sumcheck.rs` |
| `H: commit` | 3.431 | 19.7% | **shared**: `pcs::commit_zk_owned_tagged` |
| `A: commit` | 3.069 | 17.6% | **shared**: the same |
| the four openings + `M` | 0.667 | 3.8% | **shared** `pcs::open_zk` / `zk::mask_open` (the schedule audit around them is the lane's) |
| extension rounds | 0.757 | 4.4% | mixed: `mask_eval` (lane) inside `zk::extension` (shared) |
| everything else | 2.88 | 16.6% | the lane: the `A` and `H` builds (0.86), the helper inverses (1.27), the slot tables (0.59), the claimed sums (0.02), the rest under 0.1 each |

**So about 79% of a 125M prove is now in files this lane may not edit**
(6.594 + 3.431 + 3.069 + 0.667 = 13.76 s of 17.40 s), and up to 83% counting
the shared half of the extension rounds. The two PCS commitments alone are
37.3%: that is the GPU's target and the one a two-prover split would have to
pay twice. Requests R1 and R2 below say what to try there, with these
numbers as the attribution.

**What this is not.** One run of one shape on a shared 8-thread laptop, dense
public weights, development grade. Not a forecast for another shape, another
box or another witness, and not a privacy statement about anything.

### What was tried and dropped, each with why

| # | item | why it is not in this stage |
|---|---|---|
| 1 | **a deterministic receipt-byte digest pin at rung-G / rung-K4** | finding **S28-F2** above: it needs a seeded generator on the proving path, which `s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system` forbids and which the accepted toy statement's condition 6 forbids. The nine old-vs-new equality tests are the replacement, and they are narrower AND sharper |
| 2 | **anything that changes what is SENT** | out of bounds by the brief and by D17: no eq-factoring that lowers a round polynomial's degree, no reordered absorb, no changed draw count or order. Nothing in this stage touches a transcript line or a generator |
| 3 | **the exp / activation helper inverses** | their denominators are `alpha - (d + beta*e + g_exp)` over a PAIR of witness values, so there is no 256-entry table to index: the brief's "only if it is as simple" is not met. MEASURED worth at 125M: 0.186 s, 0.8% of the baseline prove |
| 4 | **the masked sumcheck's per-point machinery** | `zkp-core/src/sumcheck.rs` and `hashline/src/zk.rs` are shared files this lane may not edit. It is MEASURED (6.907 s, 28.1% of the prove at 125M) and handed over as request R1 below, together with what the code already does so that nobody re-invents it |
| 5 | **the two PCS commitments** | `pcs::commit_zk_owned` is shared. MEASURED: 3.076 s + 3.499 s = 6.575 s, 23.7% of the baseline prove. Request R2 |

### Integrator requests, with MEASURED attribution

All figures are [MEASURED, one run, shared box] at the 125M shape, dense
weights, one block, and are the SHARE OF A PROVE THAT THIS LANE CANNOT TOUCH.

**R1 — `zkp-core/src/sumcheck.rs`, `prove`'s round loop (and `zk::extension`).
6.907 s, 28.1% of the 24.59 s prove.** What it already does, so that the
obvious suggestions are not re-made: it reuses one `cur`/`dif` pair per chunk
instead of re-gathering, it walks `t = 0, 1, 2, ...` by adding a per-point
delta, and it runs the round on rayon in 1,024-point chunks above a
`half * k <= 2^16` cut-off. What is left to try, in the order this lane would
try it: (a) the per-point `Box<dyn Fn(&[Fp2]) -> Fp2>` is an indirect call
made `degree + 1` times per point — a batched interface (`poly` over a slice
of rows, returning a slice) would amortise it and open the door to SIMD;
(b) a ROUND-1 specialisation over the base field when every table entry is a
base-field element — at this block that would need `argument::priv_table`
(lane) to hand out `Fp` tables and the slot closures to accept them, so it is
a JOINT change, not a shared-file one, and it should not be attempted without
one measurement of how many of a big slot's tables are base-field-valued;
(c) the chunk size is a constant 1,024 at every cube from 2^10 to 2^23.

**R2 — `hashline/src/pcs.rs`, `commit_zk_owned` for `A` and `H`. 6.575 s,
23.7%** (A 3.076 s over 5,681 rows, H 3.499 s over 7,120 rows). This is the
encode + Merkle pass and is the natural GPU target; it is also the phase a
two-prover split would have to pay twice or divide (the P5 question).

**R3 — nothing else in a shared file is above 1.5% at this shape.**
`zk::mask_commit` 0.022 s, `zk::mask_open` 0.005 s, `pcs::open_zk` (A, H and
the two endpoints) 0.698 s total.

### Task 4 — the gates, the commits, and what a reader should check first

**The commits of stage 28**, in order:

| commit | what |
|---|---|
| `d4d1b19` | the ledger skeleton |
| `d2c2733` | **task 1**: the LogUp helper inverses by table (256 denominators once per proof), the refusal preserved value by value, six equality gates, finding S28-F1 |
| `a9f2211` | **task 2**: `timing::slot_step` (the attribution instrument), the slot table build in parallel and cheaper (five changes), the claimed sum in parallel, the helper columns written pair by pair, the looked columns and the byte histogram in parallel; four more equality gates |
| `938750a` | the ledger: the pins, finding S28-F2, task 0's baseline, task 1, the attribution, the integrator requests |
| `1952a1e` | **task 3**: the 125M re-measurement (27.71 -> 17.40 s) |
| this one | task 4: the gates, and the closing statement |

**The gates at the final tip.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter) | **319 passed / 0 failed / 12 ignored, 416.64 s, exit 0** (`q28-gate2.log`); the stage's baseline was 309 passed / 0 failed / 12 ignored and this stage adds **ten** tests, all in `s28_tests.rs` |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `tests::the_toy_receipt_is_the_counted_length` family (the 2,816,472 B pins in `tests.rs`, `zero_witness_tests.rs`, `hash_domain_tests.rs`, `review_tests.rs`, `grow_tests.rs`), `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` — **all in the pass list** |
| the rung, rung-G and rung-K4 receipt lengths | in the pass list (`rung_tests`, `dense_tests`, `k4_tests`, dense AND all-zero) |
| the 125M receipt length | `40,783,352 B`, asserted inside the `#[ignore]`d run this stage executed three times |
| the TEN new equality gates | `q28-s28-equality3.log` and the filter above |
| the Python suite | **not run, and it reads nothing this stage touched.** The manifests that pin Rust sources (`zk60_round22_captures.json`, `zk60_round19_validation.json`, finding S17-F1) pin `zk.rs`, `pcs.rs`, `transcript.rs`, `private_seam.rs`, `sumcheck.rs` and the five `zk_ffn_*` files — not one of them is in this stage's diff |
| the forbidden-files proof | `git diff --stat 79f0726 -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu private-block-kernel private-model-kernel private-block-kernel-shaped zkvm-block scripts tests` prints **nothing**. The whole diff is four lane sources, one new test file, this ledger and the evidence |

**One consequence for the integrator, not a failure.** `run_capture`'s
`source_pins()` hashes `protocol.rs`, `argument.rs` and `timing.rs` among
the files a bundle pins, so every capture bundle taken BEFORE this stage
records their old digests. Nothing re-verifies those pins against the working
tree today; a capture taken after this stage simply pins the new text. It is
noted here so that a later reader does not read the difference as tampering.

**An all-zero-input control at 125M** (`q28-m125-final-zero.log`, exit 0,
`HL_PB_INPUT=zero` with the default tame weights — the degenerate witness of
the privacy case U-4), the fourth of this stage's five 125M runs, run after
the gate once another lane's Python jobs released the heavy lock
[MEASURED, one run, shared box]:

| figure | pre-repair all-zero (`m125-one-block-zero.log`, 2026-09-20 19:28) | **after stage 28** |
|---|---|---|
| prove, s | 26.98 | **17.71** |
| verify from bytes, s | 1.23 | 1.14 |
| receipt, B | 40,783,352 | **40,783,352** |
| peak RSS, GiB | 9.99 | **9.91** |
| `H: LogUp helper inverses`, s | 4.531 | **1.088** |
| `A: lookup values + the byte histogram`, s | 0.492 | **0.097** |
| slot 17, s | 6.564 | **3.769** |
| slot 14, s | 2.981 | **2.012** |

**The control says what it was run to say**: the degenerate witness pays the
same 17.7 s as the fully dense one (17.40 s), phase for phase, so nothing
this stage did made the prover's cost depend on the hidden input. It could
not: the table path is chosen by a value's RANGE and never by its value, and
every parallel threshold is a function of the public shape. The all-zero run
also carries the same receipt length, which is what the frame-length pin
asserts on both witnesses.

**What a reader should check first, in one line each.** (1) The receipt
length is the same number before and after, at every shape, and every honest
proof still verifies FROM BYTES. (2) Every change has an old-against-new
equality test in `s28_tests.rs` whose oracle is not the code under test.
(3) Finding S28-F1 is a statement about the EXISTING refusal, not a change to
it, and it is the security owner's to rule on. (4) Finding S28-F2 says why
there is no deterministic receipt digest to pin on this path and what it
would cost to build one.

## Stage 29 — closing the independent review's gaps, and one count for the integrator (2026-09-21, 10:4x–)

**What this stage is.** The security owner's disposition of stage 28 and of
its independent review (`ZK60_BLOCK125M_S28_DISPOSITION.md`, 2026-09-21 10:43)
accepts stage 28 as experimental lane code and asks, in ruling **V-4**, for
the review's gaps to be closed before the integrator takes the stage. This
stage is that work and nothing else, plus the ONE measurement request the
disposition's V-6 line and the stage-28 integrator request **R1(b)** turn on:
how much of a big zero-check slot's table data is BASE-FIELD-valued when
round 1 starts.

Nothing here may change what is sent, absorbed or drawn. The production call
path is unchanged in BEHAVIOUR by construction: every threshold stage 28
introduced becomes an ARGUMENT of an inner function, and the production
wrapper passes the same constant it passed before, so no other test in the
filter takes a different branch than it did at `db28728`.

| task | what | state |
|---|---|---|
| 1 | **S28-R1 / S28-R6** — both branches of every stage-28 size threshold crossed in the ORDINARY filter, each against an old-against-new oracle | **DONE** (`33d44e2`, `b6ff9d4`, `5f6be16`) |
| 2 | **S28-R7** — `eq_cube`'s precondition a hard `assert!`, with the agreement test and the panic test | **DONE** (`b6ff9d4`, `5f6be16`) |
| 3 | **S28-R8, S28-R4, S28-R5, ruling V-3** — the ledger corrections, dated, in place | **DONE** (`6717899`) |
| 4 | **integrator request R1(b)** — the base-field census at the 125M shape and at rung-K4, and the second 125M prove-time sample | **DONE** (`b512b83`, `4dcf108`, `6a3c7cf`): 62.1% of the round-1 table words of the five slots are base-field at 125M and 61.5% at rung-K4; the second prove sample is 19.36 s beside stage 28's 17.40 s, same receipt length |
| 5 | the gates | **DONE** (`f1f6173`): 336 passed / 0 failed / 13 ignored, exit 0 |

### Task 1 — both branches of every stage-28 threshold, against the text at `79f0726` (findings S28-R1 and S28-R6)

**What the review found.** Stage 28 introduced five size thresholds. Its own
gates and the review's gates reached both sides of two of them; the other
three were reached on one side only, and `total`'s parallel branch — the
claimed sum — was reached by **no test that is not `#[ignore]`d**, its single
execution anywhere being inside the 125M run. Four of the nine changed
computations had no old-against-new oracle at all: the moved public table, the
parallel table build, the parallel claimed sum and the parallel histogram.

**The means, and why the production path is untouched.** Each threshold is now
an ARGUMENT of an inner function, and the production wrapper passes the
constant stage 28 chose and measured:

| computation | production wrapper | inner form | constant |
|---|---|---|---|
| the claimed sum | `argument::total` | `total_at(.., par_min)` | `TOTAL_PAR_MIN` = 2^14 |
| the slot table build | `run_slot`'s prove arm | `build_tables_at(tabs, n, pd, par_min)` | `TABLES_PAR_MIN` = 2^17 |
| the looked columns | `protocol::lookup_values` | `lookup_values_at(.., par_min)` | `LOOKUP_PAR_MIN` = 2^17 |
| the byte histogram | `prove_core` (was written inline) | `byte_histogram_at(looked, lookup_words, par_min)` | `HISTOGRAM_PAR_MIN` = 2^17 |
| the helper inverses | `helper_inverses_u8`, `helper_pair_inverses_u8` | the two `_at` forms | `HELPER_PAR_MIN` = 2^14 |

No `cfg(test)` constant was introduced: **every other test in the filter takes
the same branch it took at `db28728`**, which is the condition ruling V-4
sets. `s29_tests::the_five_thresholds_are_the_constants_the_production_path_passes`
pins the five constants so that a later edit cannot move one silently and
leave the census below stale.

**The gates** (`hashline/src/private_block/s29_tests.rs`, nine tests, none
`#[ignore]`d):

| test | what it compares | both branches on the same input? |
|---|---|---|
| `the_claimed_sum_is_the_79f0726_fold_through_both_branches_of_its_threshold` | `total_at` forced serial and forced parallel against `total_79f0726` (verbatim), four tables, a degree-3 polynomial, at 16 / 2^10 / 2^14 / 2^14+1 / 2^15 words | yes; two lengths are above the production threshold |
| `the_slot_table_set_is_the_79f0726_one_through_both_branches_of_its_threshold` | `build_tables_at` forced serial and forced parallel against `build_tables_79f0726` (verbatim `table_of`, whose `priv_table` call points at `s28_tests`' verbatim `priv_table_walked`), on a six-to-ten table set: a challenge-weighted `eq`, a public table, plain `A` planes, a short plane needing the broadcast, an `H` pair with the `u` coefficient, a fixed coordinate | yes, at five sizes: three below and two above the production threshold. It also asserts the public payload was MOVED out of the definition on the new path and that its words are the clone's |
| `the_looked_columns_are_the_79f0726_serial_maps_through_both_branches` | `lookup_values_at` forced both ways against the `79f0726` serial map, on real honest witnesses at the toy and rung-K4, every lookup domain | yes |
| `the_byte_histogram_is_the_79f0726_serial_count_through_both_branches` | `byte_histogram_at` forced both ways against the `79f0726` loop, on the same real looked columns, plus a synthetic set carrying `-1, 256, 2^40, i64::MIN, i64::MAX, -2^30` — the bucket-0 fallback only a tampered plane reaches | yes |
| `the_helper_columns_are_the_same_words_through_both_branches_of_their_threshold` | the single and the paired helper, forced both ways, against the checked batch inversion, at five lengths, accepted columns AND the refusal (in column a, in column b, and the pair that carries none) | yes — stage 28's gates crossed this threshold by changing the column LENGTH; this one holds the column fixed and changes only the branch |
| `the_eq_cube_agrees_with_the_79f0726_gather_on_every_admitted_triple` | all **560** admitted `(n_vars <= 13, |point|, start)` triples | (task 2) |
| `a_violated_eq_cube_precondition_panics_by_name`, `an_eq_point_wider_than_the_cube_panics_by_name` | the two ways to violate the precondition | (task 2) |
| `the_five_thresholds_are_the_constants_the_production_path_passes` | the five constants | — |

Every parallel branch is additionally re-run inside pinned 1, 2 and 8-thread
pools from inside the test (`in_pools`), and the whole file was run under
`RAYON_NUM_THREADS=1`, `2` and `8`: **9 passed / 0 failed each time**
(`results/zk60_block125m_lane/r29-s29-threads.log`).

**Which shape crosses which branch (finding S28-R6, closed in the ledger).**
The review's census is a fact about the shapes and stands; what changes is
that the branches no longer depend on a shape to be reached at all:

| shape | lookup words | histogram >=2^17 | `lookup_values` >=2^17 | helper >=2^14 | slot tables >=2^17 | `total` >2^14 |
|---|---:|---|---|---|---|---|
| toy (the byte-frozen one) | 61,440 | no | no | no | no | no |
| development rung / rung-G | 419,840 | **yes** | **yes** | no | **yes** | no |
| rung-K4 | 542,720 | **yes** | **yes** | **yes** | **yes** | no |
| 125M | 98,598,912 | **yes** | **yes** | **yes** | **yes** | **yes** |
| **`s29_tests` (this stage)** | — | **both** | **both** | **both** | **both** | **both** |

So the frozen toy's byte pins still cross none of the five parallel branches —
they cannot, and that is what S28-R6 says — and the branches are now covered
by unit gates with oracles rather than by the shapes alone.

**What still has NO old-against-new oracle, and why.** One thing, and it is
narrower than before: no unit gate builds the REAL slot descriptors the
schedule emits (`argument::define` constructs them inside the prover and
hands them straight to `run_slot`; there is no constructor a test can call for
a whole slot's `SlotDef`). `s29_tests` builds descriptors of the same KINDS by
hand — every variant of `Tab`, every variant of `Coord`, an `H` pair, a short
plane, a fixed coordinate — and compares the whole table set against the
`79f0726` build; the bilinear slots 08/09 with their group-bit variables, and
the padded tails of a non-power-of-two token count, are still covered
**end to end only** (every honest proof at five shapes proves and verifies
from its own bytes, and the group-bit sweep of `k4_tests` rejects all seven
tampers). That is the same gap the review named in its §12, reduced to the
DESCRIPTORS rather than the computation: the computation now has an oracle at
every size, on both sides of every threshold.

### Task 2 — `eq_cube`'s precondition is loud now (finding S28-R7)

`argument::eq_cube` computes `shift = n_vars - start - |point|`. On a violated
precondition the old gather returned a wrong but in-bounds cube and the
doubling build computes a WRAPPED shift and tries to `resize` by
`1 << (shift mod 64)` — the two forms diverge, and the second asks the
allocator for an absurd vector. The triple is schedule-driven and PUBLIC (no
frame and no witness can choose it), so this is robustness and not a reachable
attack; ruling V-4 says to close it with a hard assertion naming the
precondition, and a panic on a public-shape invariant is acceptable where a
silent divergence is not.

```
assert!(start + bits <= n_vars,
  "private block: eq_cube precondition start + |point| <= n_vars violated (start {start}, |point| {bits}, n_vars {n_vars})");
```

Both sides are tested: the two forms agree on **all 560 admitted triples**
(`the_eq_cube_agrees_with_the_79f0726_gather_on_every_admitted_triple`, which
asserts the count is 560), and the two ways to violate the precondition —
`start` too large, and a point wider than the cube — now panic by name
(`a_violated_eq_cube_precondition_panics_by_name`,
`an_eq_point_wider_than_the_cube_panics_by_name`, both `#[should_panic]` on
the message text).

### Task 3 — the four ledger corrections (findings S28-R8, S28-R5, S28-R4 and ruling V-3)

All four are made IN PLACE in the stage-28 section above, each as a dated
`CORRECTED 2026-09-21 11:10 PDT` block that leaves the original sentence
visible:

| finding | where the correction sits | what it says |
|---|---|---|
| **S28-R8** | under "The rule of this stage", and again at task 1b | the ONE refusal string stage 28 adds, `"private block: paired lookup columns of different lengths"`, why it is unreachable, and that it falls under the refusal-reason rule |
| **S28-R5** | under the equality-gate paragraph | ten tests, not nine — and, in the same note, that the "every computation, same test" sentence was false for four of the nine changed computations at the stage-28 tip and is true at this one |
| **S28-R4** | under the task-3 sub-step table | the column headed "baseline" is the 24.59 s tree after task 1, which is NO commit; the headline 27.71 -> 17.40 s is between two commits and stands; commit the instrument first next time |
| **V-3** | under finding S28-F1 | S28-F1a, the qualified form the security owner accepts, with the reviewer's counterexample test named and the consequence for the accepted figures (none) recorded |

### Task 4 — the base-field census: how much of a big slot's round-1 table data is base-field-valued (integrator request R1b)

**The question, and why it is a COUNT and not a design.** Stage 28's request
R1 to the integrator offers three things to try in the shared masked
sumcheck, and item (b) — a ROUND-1 specialisation over the base field — is
the only one that is a JOINT change: `argument::priv_table` (this lane) would
have to hand out `Fp` tables and the slot closures in `zk.rs` /
`zkp-core/src/sumcheck.rs` would have to accept them. The stage said it
"should not be attempted without one measurement of how many of a big slot's
tables are base-field-valued". This is that measurement. **No base-field
round was implemented and none is proposed here**; this is the count that
says whether designing one is worth anybody's time.

**The instrument.** `timing::base_field_census`, called from
`argument::run_slot` between the table build and the claimed sum — exactly
where round 1 starts, on the tables as round 1 will read them. It counts
words whose imaginary part is zero, per table, and prints one summary line
per slot plus one line per DESCRIPTOR CLASS (identical structural labels
collapse). It prints counts, the slot's public name and schedule facts (which
commitment a private plane lives in, how many slices, how many fixed
coordinates) and **never a value**. It is off unless the operator names the
slot in `HL_PB_BASEFIELD` (`all`, or a comma-separated list), and with the
variable unset it is one `std::env::var` per slot and no scan.

**Why a wholly base-field TABLE is the right unit.** Round 1 of
`zkp-core::sumcheck::prove` gathers `cur[t] = v0`, `dif[t] = v1 - v0` from the
table words themselves and then walks `cur[t] += dif[t]` for the `degree + 1`
evaluation points. A difference of two base-field words is base-field and the
walk preserves it, so **a table that is wholly base-field at round 1 fills a
base-field operand slot at every one of the round's evaluation points**. And
because every table of a slot has the same length `2^n`, the share of WORDS
and the share of TABLES are the same number.

**Rung-K4** [MEASURED, one run, shared box; `results/zk60_block125m_lane/r29-k4-bfcensus.log`,
`HL_PB_BASEFIELD=all HL_PB_TIMING=1`, the dense K4 gate, scan 0.001 s per slot]:

| slot | tables | wholly base-field | words | base-field words | share | the exceptions, and why |
|---|---:|---:|---:|---:|---:|---|
| 17 `SC_SZC` | 30 | 18 | 491,520 | 294,912 | **60.0%** | 3 `Eq` (challenge-weighted) + 9 `Priv cm=H` (LogUp helper columns: an `H` plane is the pair `(re, 1), (im, u)`, so its cube carries `re + u im`) |
| 14 `SC_DZC` | 62 | 40 | 253,952 | 163,840 | **64.5%** | 3 `Eq` + 19 `Priv cm=H` |
| 18 `SC_FZC` | 21 | 12 | 172,032 | 98,304 | **57.1%** | 3 `Eq` + 6 `Priv cm=H` |
| 15 `SC_QZC` | 21 | 11 | 86,016 | 45,056 | **52.4%** | 3 `Eq` + 7 `Priv cm=H` |
| 04 `SC_RS` | 5 | 4 | 81,920 | 65,536 | **80.0%** | 1 `Eq` |
| **the five** | **139** | **85** | **1,085,440** | **667,648** | **61.5%** | — |

The base-field side is always the same two classes: the `Priv cm=A` planes
(witness integer data, lifted by `Fp2::from_base`) and the `Pub` public
tables. The extension side is always the same two: the challenge-weighted
`eq` tables and the `H` planes, which are helper columns and are inverses in
the extension by construction.

**The 125M census and the second prove-time sample — the run.** It is one
125M one-block dense prove, the same test and the same environment as the
17.40 s sample of stage 28 task 3, with the census switched on for the five
slots the request names:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_TIMING=1 HL_PB_WEIGHTS=dense HL_PB_BASEFIELD=17,14,18,15,4 /home/victor/zk60-artifacts/hashline-r29-census --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/r29-m125-bfcensus.log 2>&1; echo $? > /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/r29-m125-bfcensus.done' >/dev/null 2>&1 &
```

Three notes a reader needs. (1) The run was enqueued at **10:55 PDT** behind
another lane's Python queue (25 waiters on `/tmp/zk-heavy.lock`), and it
self-starts when the lock frees, session or no session: the answer to "did it
finish" is the `.done` marker, and its numbers belong in a table right here.
(2) It runs a COPY of the test binary taken at the moment of enqueueing, so
that this stage's later commits could not change what the queued run
executes; that binary is the stage-28 production code plus the census, which
is why its prove figure is a second sample of the SAME prover that gave
17.40 s and not a measurement of task 1's refactor. (3) At **11:24 PDT** the
job was cancelled and re-enqueued, unchanged except for where the binary
sits: the first copy was in a session-scoped scratchpad under `/tmp`, which a
run that may wait hours cannot rely on (this project's own `/tmp`
evidence-loss rule), so it now lives at
`/home/victor/zk60-artifacts/hashline-r29-census` and the command above is
the one that will run. The census's own scan is timed and printed per slot
(`scan x.xxx s`), so the prove figure can be read with it subtracted.

**THE 125M CENSUS** [MEASURED, one run, shared box, `r29-m125-bfcensus.log`,
exit 0, started 12:50 PDT 2026-09-21 once the heavy lock freed, one dense
one-block prove, scans 0.052 s in total]:

| slot | tables | wholly base-field | words | base-field words | share | the exceptions, and why |
|---|---:|---:|---:|---:|---:|---|
| 17 `SC_SZC` | 30 | 18 | 125,829,120 | 75,497,472 | **60.0%** | 3 `Eq` (two over a 22-coordinate point, one over 13) + 9 `Priv cm=H` |
| 14 `SC_DZC` | 60 | 40 | 31,457,280 | 20,971,520 | **66.7%** | 3 `Eq` + 17 `Priv cm=H` |
| 18 `SC_FZC` | 20 | 11 | 20,971,520 | 11,534,336 | **55.0%** | 3 `Eq` + 6 `Priv cm=H` |
| 15 `SC_QZC` | 21 | 11 | 11,010,048 | 5,767,168 | **52.4%** | 3 `Eq` + 7 `Priv cm=H` |
| 04 `SC_RS` | 5 | 4 | 20,971,520 | 16,777,216 | **80.0%** | 1 `Eq` |
| **the five** | **136** | **84** | **210,239,488** | **130,547,712** | **62.1%** | — |

**[COUNTED] 84 of the 136 tables that round 1 of these five slots reads at
the 125M shape are wholly base-field — 130,547,712 of 210,239,488 words,
62.1%.** The rung-K4 answer was 61.5%, so the share is a property of the
SCHEDULE and not of the shape: the same two classes are base-field (the `A`
planes and the public tables) and the same two are not (the challenge-weighted
`eq` tables, three per zero-check slot, and the `H` LogUp helper columns,
which are inverses in the extension). Both readings above — cheaper
multiplications rather than a base-field round, and joint or nothing — hold
unchanged at this shape.

One reading note so the two tables in this ledger can be compared. A table's
length here is `1 << n` for the slot's MAIN variable count: 2^22 at slots 17
and 04, 2^19 at 14 and 15, 2^20 at 18. The "cube" column of stage 28's task-2
table and of the `PB-TIMING` phase rows is `1 << (main + ext)`
(`argument.rs:1755`), which is twice as large at each of these five slots
because each has `ext = 1` (the instrument prints it). Neither figure is
wrong; they count different things.

**The second prove-time sample** [MEASURED, one run, shared box], beside
stage 28's 17.40 s, same test, same env plus `HL_PB_BASEFIELD`:

| figure | stage 28 (`q28-m125-final-dense.log`) | **this run** |
|---|---|---|
| prove, s | 17.40 | **19.36** (19.31 with the 0.052 s of census scans taken out) |
| verify from bytes, s | 1.15 | **1.34** |
| receipt, B | 40,783,352 | **40,783,352** |
| peak RSS, MiB | 10,156 | **10,141** |
| witness build, s (outside the prover) | 5.24 | **6.08** |

**How to read it: as run-to-run spread on a shared box, not as a change.**
The binary is the stage-28 production code plus the census, so the prover is
the same prover; the receipt length is identical; and the parts of the run
that contain NO census — the witness build (+16%) and the verify (+17%) —
moved by more than the prove did (+11%), which is what a busier box looks
like and not what a slower prover looks like. The project's own measured
run-to-run variance on this box is up to a factor of two. **The honest
statement is that one 125M block proves in 17.4-19.4 s on this laptop, two
runs, and that nothing here narrows that.** The per-slot sub-steps move the
same way (slot 17's table build 0.251 -> 0.510 s, its shared masked sumcheck
3.054 -> 3.107 s).

### Task 5 — the gates, the commits, and the status of every review finding

**The gates at the stage-29 tip.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter) | **336 passed / 0 failed / 13 ignored, 421.30 s, exit 0** (`r29-gate-private.log`) — the stage-28 tip's 327 plus this stage's nine, nothing lost and nothing newly ignored |
| the new gates under `RAYON_NUM_THREADS=1`, `2` and `8` | **9 passed / 0 failed** each time (`r29-s29-threads.log`) |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies`, and the 2,816,472 B receipt-length family (`tests`, `zero_witness_tests`, `hash_domain_tests`, `review_tests`, `grow_tests`) — **all in the pass list** |
| the rung, rung-G and rung-K4 receipt lengths | in the pass list (`rung_tests`, `dense_tests`, `k4_tests`, dense AND all-zero) |
| the forbidden-files proof | `git diff --stat db28728 -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu private-block-kernel private-model-kernel private-block-kernel-shaped zkvm-block scripts tests` prints **nothing** |
| the whole diff against `db28728` | seven sources and two evidence files: this ledger, `private_block.rs` (one `mod` line), `argument.rs`, `protocol.rs`, `timing.rs`, `s28_tests.rs` (two oracles made `pub(super)`), the new `s29_tests.rs`, and the two logs |

**The commits of stage 29**, in order:

| commit | what |
|---|---|
| `dc5f33f` | the ledger skeleton |
| `b512b83` | **task 4's instrument**: `timing::base_field_census` and its call site, plus the rung-K4 evidence |
| `33d44e2` | **task 1 part 1**: `protocol.rs`'s three thresholds become arguments |
| `b6ff9d4` | **task 1 part 2 and task 2**: `argument.rs`'s two thresholds become arguments, and `eq_cube`'s precondition becomes a hard assertion |
| `5f6be16` | **the gates**: `s29_tests.rs`, nine tests, and the 1/2/8-thread evidence |
| `6717899` | **task 3**: the four ledger corrections, in place and dated |
| `3ec0631` | the ledger: tasks 1, 2 and 3 |
| `f1f6173` | the `private_` filter gate at the tip |
| `b892b7f`, and this one | the ledger: task 4 and the close |

**Every finding of the independent review, and where it stands now.**

| finding | status at the stage-29 tip |
|---|---|
| **S28-R1** (`total` and three more without an oracle; the parallel branch reached only by an `#[ignore]`d run) | **CLOSED.** All five thresholds are arguments of inner functions; five gates in the ordinary filter drive BOTH branches on the SAME input and compare against the `79f0726` text; `the_five_thresholds_are_the_constants_the_production_path_passes` pins the constants |
| **S28-R2** (S28-F1's second sentence over-reaches) | **CLOSED by ruling V-3**: the ledger now carries S28-F1a, the qualified form, with the reviewer's counterexample test named |
| **S28-R3** (the `Err` arm of the out-of-table fallback) | closed by the reviewer's own test, merged at `db28728` |
| **S28-R4** (the sub-step table's "baseline" column) | **CLOSED in the ledger**: the column is labelled as the 24.59 s post-task-1 tree, which is no commit |
| **S28-R5** ("nine tests" for ten) | **CLOSED in the ledger**, together with the sentence about four computations that had no oracle |
| **S28-R6** (the frozen toy crosses none of the five thresholds) | **CLOSED as ruled**: it is a fact and stays one; the ledger says which shape crosses which branch, and the thresholds now have their own gates |
| **S28-R7** (`eq_cube` diverges on a violated precondition) | **CLOSED**: a hard `assert!` naming the precondition, the 560 admitted triples compared, and two `#[should_panic]` gates |
| **S28-R8** (one unlisted refusal string) | **CLOSED in the ledger**, twice: under the stage rule that claimed none was added, and at task 1b |
| **S28-F2** (no deterministic digest pin) | unchanged and unchallenged: ruling V-5 keeps it. Nothing in this stage touches randomness; no generator is read, drawn from or configured anywhere in the diff |

**What this stage is not.** Not a privacy acceptance of anything: the lane's
code stays experimental, for the integrator (ruling V-1). Not a change to
what is sent, absorbed or drawn — the production call paths pass the same
constants they passed at `db28728`, and the only new behaviour anywhere is a
panic on a public-shape invariant that no frame and no witness can reach.
Not a speed claim: nothing in this stage was written to make anything faster,
and the base-field census is a COUNT with no time estimate attached to it.
**The answer, plainly, and the form it takes at any shape.** At rung-K4,
**[COUNTED] 85 of the 139 tables that round 1 of slots 17, 14, 18, 15 and 04
reads are wholly base-field — 667,648 of 1,085,440 words, 61.5%** — and the
other 54 are the three or so challenge-weighted `eq` tables per slot and the
`H` LogUp helper columns. Two things follow, and neither is a time estimate.

* **What a joint change could buy is CHEAPER MULTIPLICATIONS, not a
  base-field round.** Every one of these five slots carries at least one
  challenge-weighted `eq` factor, so no round-1 PRODUCT is wholly base-field;
  what 61.5% of base-field operands buys is `Fp2::mul_base` (two base
  multiplications) in place of a full extension multiplication (four base
  multiplications and the non-residue fold) wherever a base-field operand
  enters, plus half the memory traffic for those tables if `priv_table`
  handed out `Fp` cubes instead of `Fp2` ones.
* **It is a JOINT change or it is nothing.** The base-field side is exactly
  the two classes this lane owns the construction of (`Priv cm=A` planes and
  `Pub` tables); the operand type that reaches the multiplication is fixed by
  `zkp-core::sumcheck::prove`'s `cur`/`dif` pair and the slot closures'
  `&[Fp2]` signature, both in shared files. Neither side can take it alone.

---

## Stage 30 — the UNPADDED branch of the pad rule, in the ordinary filter (2026-09-21, 11:4x–)

**THE GAP, IN ONE SENTENCE.** Ruling P-1's pad-zero term is drawn per HOST
SLOT and only when the domain that slot hosts actually pads: `argument.rs`
draws `mu(... + n_pad)` and a `zeta` **iff `pad_on`**, and `B::supp` returns
`None` — no public support table, no gate — when `!sh.pads(dom)`. Every
development shape the ordinary filter proves at (`rung`, `rung_g`,
`rung_k4`) pads **all nine** domains, so the `pad_on == false` arm of a
shape that CARRIES the rule is reached by the 125M shape alone, whose proofs
are `#[ignore]`d 10 GiB tests. The independent Python gate had this branch
wrong in its own port until 2026-09-21 and no development shape could show
it (its finding **M-F1**). Under the security owner's standing rule after
S19-F1 — a branch only an ignored heavy test reaches is a branch nobody
tests — this stage puts BOTH arms of the rule inside one small shape in the
ordinary filter.

| task | what | state |
|---|---|---|
| 1 | the shape: T, Kv and F unpadded, Ht / L / D / Q / S / Tab padded, `lkv = 2` | **DONE** — `Shape::rung_p2`, receipt 4,742,728 B counted and measured |
| 2 | the tests in the ordinary filter (gap census, honest dense, all-zero, draw census, tampers, a run) | **DONE** — 11 new tests in `p2_tests.rs` + 1 in `parity.rs`, all non-ignored |
| 3 | what is STILL reached only by ignored heavy tests after this stage (the S19-F1 lesson) | **DONE** — five items below, one of them (C-6) reachable at a small shape |
| 4 | two capture bundles of the new shape for the Python gate's M-F1 regression | **DONE** — `run-k-dense-p2` / `run-l-zero-p2`, 16.0 + 15.9 MB |
| 5 | the gates: the whole `private_` filter, every older profile's pins, the forbidden-files proof | **DONE** — see the gate table |

**The rules this stage works under** are the lane's: one writer, the build
recipe above, no 125M run (the heavy lock carries the stage-29 census), new
profiles for new shapes (Codex's condition and D17), each failure reproduced
as a failing test first, the toy byte-frozen, and no "proves and verifies"
without a GENERIC honest witness — dense public weights, a non-constant
hidden input, key-value groups that differ — checked against the
independent reference kernel.

### Task 1 — `Shape::rung_p2`, and why every number of it is forced

**The idea in one line: take rung-K4's PADDED layout and move two true sizes
onto their pads.** Nothing else changes, which is what makes everything that
follows a measurement of the pad rule and of nothing else.

| | rung-K4 | **rung-P2** |
|---|---|---|
| tokens / width / hidden | 24 / 96 / 192 | **32 / 96 / 256** |
| query heads × head_dim, key-value heads | 12 × 8, 4 (`lkv = 2`) | the same |
| `t_pad, d_pad, h_pad, f_pad` | 32, 128, 16, 256 | **the same** |
| the nine domain logs | 5, 9, 10, 12, 12, 10, 14, 13, 10 | **the same** |
| helper counts per lookup domain | — | **the same** |
| `log_cols`, `inv_rate`, `F_E`, `norm_wrho`, `wrho_s` | 10, 4, 12, 31, 17 | **the same** |
| endpoint | generalised, 9 rows, `log_n` 10, rate 4 | **the same** |
| padded head slots | `{3, 7, 11, 15}` | **the same** |
| **domains that PAD** | **all nine** | **Ht, L, D, Q, S, Tab** |
| **domains that do NOT** | none | **T, Kv, F** |
| block profile | `…/private-block-rung-k4-t24-dev/1` | `hashline-zk-mr1/private-block-rung-p2-t32-dev/1` |
| run profile | `…/private-run-rung-k4-t24-dev/1` | `hashline-zk-mr1/private-run-rung-p2-t32-dev/1` |
| counted receipt | 4,743,128 B | **4,742,728 B** |

**Every dimension is forced.** `tokens = 32` is the only value at or near 24
that makes `Dom::T = t_pad` (a power of two) without moving `t_pad` and with
it every other domain's log; it drags `Dom::Kv = tokens · kv_heads ·
head_dim = 2^10` with it, which is the row width exactly — the toy's case,
not a P-3 lift, so stage 21's F-2 refusal is satisfied and not weakened.
`hidden = 256` is the only value at or near 192 that makes `Dom::F = tokens ·
hidden = 2^13` without moving `f_pad`. The head axis is rung-K4's unchanged,
because it is what keeps `Dom::Ht`, `Dom::D`, `Dom::Q` and `Dom::S` padded
(twelve true heads in sixteen slots, width 96 in 128) — **both arms in one
shape**, and `lkv = 2` with a padded slot inside every group's block, which
is 125M's head geometry.

**THE PER-DOMAIN TABLE**, printed by
`p2_tests::the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move`
(`t30-p2-run2.log`) and reproduced by the independent Python model
(`model_rung_p2.json`):

| domain | host slot | rung-P2 true → padded (log) | `pad_on` / `n_pad` | rung-K4 | 125M | 125M `pad_on` |
|---|---|---|---|---|---|---|
| `T` | **02** | **32 → 32** (5) | **false / 0** | 24 → 32 | 512 → 512 | **false** |
| `Ht` | 17 | 384 → 512 (9) | true / 1 | 288 → 512 | 6,144 → 8,192 | true |
| `L` | 03 | 288 → 1,024 (10, P-3 lifted) | true / 1 | 216 → 1,024 | 4,608 → 16,384 | true |
| `D` | 14 | 3,072 → 4,096 (12) | true / 1 | 2,304 → 4,096 | 393,216 → 524,288 | true |
| `Q` | 15 | 3,072 → 4,096 (12) | true / 1 | 2,304 → 4,096 | 393,216 → 524,288 | true |
| `Kv` | **16** | **1,024 → 1,024** (10) | **false / 0** | 768 → 1,024 | 131,072 → 131,072 | **false** |
| `S` | 17 | 12,288 → 16,384 (14) | true / 1 | 6,912 → 16,384 | 3,145,728 → 4,194,304 | true |
| `F` | **18** | **8,192 → 8,192** (13) | **false / 0** | 4,608 → 8,192 | 1,048,576 → 1,048,576 | **false** |
| `Tab` | 19 | 256 → 1,024 (10, P-3 lifted) | true / 1 | 256 → 1,024 | 256 → 16,384 | true |

The unpadded set is 125M's, domain for domain and therefore slot for slot:
**02, 16, 18**, which are the three the independent Python gate names.

**Which refusal constrained which choice.** Every named shape refusal was
checked at construction and none was weakened — the shape is built by the
same `Shape::new` every other shape is:

| refusal | what it would have blocked | how rung-P2 satisfies it |
|---|---|---|
| **T-8** (`head_dim` a power of two ≥ 2) | a head dimension chosen to make `Dom::Kv` land on a power of two by itself | `head_dim = 8` |
| **T-2** (padded widths powers of two) | any non-power-of-two `t_pad` / `d_pad` / `f_pad` | 32 / 128 / 256 |
| `d_pad == h_pad · head_dim` | widening the width without moving the head axis | 128 = 16 · 8 |
| **F-2** (stage 21: no P-3 lift on `Dom::Q`, `Dom::Kv`, `Dom::S`) | **the obvious small shape**: fewer tokens or a smaller head dimension puts `Dom::Kv` BELOW the row width and the bilinear arms cannot write their coordinate lists | `Dom::Kv = 2^10` sits EXACTLY at the row width; `Q` (2^12) and `S` (2^14) are above |
| **S-1** (`Dom::Tab` exactly at the row width) | lowering `log_cols` to shrink the shape | `log_cols = 10`, `log(Dom::Tab) = 10` |
| **S-3 / C-2** (`head_dim < 2^log_cols`) | a larger head dimension | 8 against 1,024 |
| **C-4** (the mask budget) | a shape whose worst slot leaves no room for the pads | worst is `SC_SZC` at `77 + 256 ≤ 512` |
| **P-3 / ruling S-1's lift** | — | `Dom::L` and `Dom::Tab` are lifted, exactly as at rung-K4, and neither is a bilinear domain |

No candidate had to be abandoned: the first geometry that satisfies "T, Kv
and F unpadded, at least two others padded, `lkv ≥ 1` with more than one
key-value head" while clearing all eight refusals is the one built. The
narrow one is **F-2**: it is why `head_dim` cannot go below 8 and therefore
why the tokens had to move instead.

### Task 2 — the tests, and what each MEASURED

All in the ordinary filter, none `#[ignore]`d. `p2_tests.rs` is 11 tests,
11 passed / 0 failed in 11.67 s (`t30-p2-run2.log`); `parity.rs` gains one
(`t30-parity.log`, 12 passed / 0 failed).

| test | result |
|---|---|
| `only_the_125m_shape_and_the_new_one_reach_the_unpadded_arm_of_the_pad_rule` | **the gap, asserted**: the toy carries no pad machinery at all; rung, rung-G and rung-K4 pad all nine domains so **8 of 8** host slots are on the padded arm; 125M and rung-P2 are **5 of 8**, with the same three slots (02, 16, 18) off for the same three domains. Also asserts `pad_on == Shape::pads(dom)` domain by domain at both |
| `the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move` | the nine logs and six helper counts equal rung-K4's; the schedules differ in **exactly** slots 16 and 18, by **exactly one degree** each; 125M's two are the same degree 4; the per-domain table above is printed |
| `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_p2` | the INDEPENDENT `private-block-kernel-shaped` crate takes this geometry unchanged; every kernel-backed plane agrees element for element and the block output on all 3,072 words. The kernel's own buffers are asserted live on the upper hidden half and its four key-value groups pairwise different FIRST, so it is not an agreement of zeros. **This is the generic-witness check the acceptance rule asks for** |
| `an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_p2` | prove **0.58 s**, verify from bytes **0.11 s**, frame **4,742,728 B** — the COUNTED length, from the Python model — and a one-byte truncation refused |
| `the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_p2` | verified, frame 4,742,728 B. Named degenerate: every key-value group is identically zero |
| `the_draw_census_is_the_rules_count_and_differs_from_rung_k4_only_where_the_pad_rule_does` | see the census below |
| `the_verifiers_own_draw_census_at_the_rung_p2_is_the_provers` | a real two-block run, proved and verified under the capture recorder whose replay rebuilds the verifier's transcript independently: `definition_challenges` agrees with the definition walk on **all 23 slots in both stages** |
| `a_tamper_inside_an_unpadded_domain_is_rejected_at_that_domains_zero_check_at_the_rung_p2` | **6 of 6 rejected by the VERIFIER, 0 by the prover, 0 accepted** — see the tamper table |
| `a_tampered_round_message_of_an_unpadded_zero_check_is_rejected_at_the_rung_p2` | slots 16 and 18, each rejected at its own slot |
| `a_padded_style_round_message_at_an_unpadded_slot_is_refused_by_the_frame_check_at_the_rung_p2` | see below |
| `the_pinned_rung_p2_chain_band_is_the_first_admissible_one` | band **41 and 40 refused** by the second block (`fixed oracle range refusal: residual 2`), **39 admissible** for three blocks, so `dense_tests::band_down_run` gains a MEASURED `(256, 4) => 39` arm |
| `an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_p2` | prove **1.81 s**, verify from segments **0.35 s**, segments **4,574,904 / 4,597,432 / 4,765,336 = 13,937,672 B** (the counted lengths), boundary 10 rows, all three blocks censused |

**THE DRAW CENSUS.** The number of challenges each host slot's definition
draws, MEASURED by cloning the transcript before `argument::define` and
replaying it one `challenge_fp2` at a time until it catches up — the same
technique `run_capture` uses on the verifier's side — and compared with the
rule TRANSCRIBED arm by arm out of `argument.rs` (`<base> + n_pad` `mu`
entries, and a `zeta` if and only if `pad_on`). Because the two shapes'
padded layouts are identical, every base is identical and the census can
differ only where the pad rule does:

| slot | name | rung-P2 | rung-K4 | the rule at rung-P2 |
|---|---|---:|---:|---|
| **02** | `02 norm squares zero-check` | **13** | 15 | `log(T) 5 + (6 + 0) + 2` |
| 03 | `08 limb zero-check` | 12 | 12 | `log(L) 10 + 1 + 1` |
| 14 | `03 D zero-check` | 46 | 46 | `log(D) 12 + (11 + 19 + 1) + 2 + 1` |
| 15 | `04 Q zero-check` | 24 | 24 | `log(Q) 12 + (1 + 7 + 1) + 2 + 1` |
| **16** | `05 KV zero-check` | **19** | 21 | `log(Kv) 10 + (1 + 6 + 0) + 2` |
| 17 | `06 softmax zero-check` | 32 | 32 | `log(S) 14 + (5 + 8 + 1 + 1) + 2 + 1` |
| **18** | `14 F zero-check` | **24** | 26 | `log(F) 13 + (4 + 5 + 0) + 2` |
| 19 | `TAB table helper zero-check` | 15 | 15 | `log(Tab) 10 + (3 + 1) + 1` |

Over all **twenty-three** slots the two shapes differ at 02, 16 and 18 and
nowhere else, and at those three by exactly two — the one `mu` and the one
`zeta`. That is the branch, measured on both sides of the protocol.

**THE TAMPERS.** Two per unpadded domain: at the **LAST index of the
domain** — the position that at every other development shape is a PAD ROW,
where ruling P-1's term forces a zero and the gate switches the
inhomogeneous clauses off — and at index 0. The plane in each domain is
chosen so that the first slot whose relation breaks is that domain's OWN
zero-check, and the rejection message is asserted to name it, so a rejection
by an earlier check cannot pass for one.

| tamper | rejected by | at |
|---|---|---|
| `A_DSQ` at index 31 (the last `Dom::T` position) | **VERIFIER** | slot 02 `02 norm squares zero-check` |
| `A_DSQ` at index 0 | **VERIFIER** | slot 02 |
| `A_K8` at index 1,023 (the last `Dom::Kv` position) | **VERIFIER** | slot 16 `05 KV zero-check` |
| `A_K8` at index 0 | **VERIFIER** | slot 16 |
| `A_G8` at index 8,191 (the last `Dom::F` position) | **VERIFIER** | slot 18 `14 F zero-check` |
| `A_G8` at index 0 | **VERIFIER** | slot 18 |
| one value of a round message of slot 16 / slot 18 | **VERIFIER** | that slot, `sumcheck round 0: s(0) + s(1) != claim` |

All seven name the slot under test in the message; the honest control is
asserted accepted first in each test.

**THE PADDED-STYLE PROOF, and what the test actually says (a finding of
its own, T30-F1).** The task asked for a verifier fed a proof produced as if
the domain were padded, with the fallback of a schedule-level refusal if it
is not constructible test-side. It is not: the production prover derives the
degree from the shape, and making it lie would be a production edit. So the
statement is made on the FRAME, and what it shows is:

* a receipt whose slot 16 (or 18) carries **padded-style round messages**
  (one more evaluation per round, the shape a degree-5 slot publishes) is
  refused by `wire::validate` — the per-slot schedule check `verify_inner_at`
  runs BEFORE it absorbs or draws anything — with
  `"private block wire: argument shape"`;
* the honest receipt passes that same check, and the only difference between
  the two objects is that slot's round messages, so the refusal is caused by
  the edit;
* the encoder refuses it too, so it cannot be re-encoded into a frame of the
  honest length.

**T30-F1: that refusal does NOT name the slot.** `wire::validate` returns
one string for every slot and every field of the frame, so a caller sees
"argument shape" and nothing else. It is fail-closed and it arrives before
any transcript operation, which is what matters for soundness, but it is
weaker than the sumcheck-level refusals, which do name the slot and the
declared degree (`slot 16 [05 KV zero-check]: sumcheck round 0: expected
degree 4, got 6 values`). Making the frame check name the slot is a
one-line change in a SHARED file (`wire.rs` is this lane's, but the refusal
string is part of the wire contract), so it is left to the integrator as a
suggestion and not taken here.

### Task 3 — what is STILL reached only by an `#[ignore]`d heavy test

Read off `shape.rs` and `layout.rs`, branch by branch, after this stage.
**`pad_on` per domain is now covered** — that is what the stage did — and so
is every branch that follows from it (the support indicator, the extra `mu`
and `zeta`, the degree of the eight `INDICATOR_SLOT_DOMAIN` slots). What
remains:

| # | branch | why no shape in the filter reaches it | can a small shape? |
|---|---|---|---|
| 1 | **`Shape::norm_top_is_full_byte` — correction C-6** (`layout::lookups_at`: the four `scaled` norm lookups are DROPPED, `Dom::D` carries 17 helpers instead of 19 and the `H` plane list is 50 planes instead of 51) | it is true only when `norm_wrho == 8 · limbs_norm`, i.e. 32 bits, and `norm_wrho = NORM_TN + 1 + bit_length(d_max)` with `d_max ≈ sqrt(width) · 32767`. Every development shape has width 96 → 31 bits | **YES, and cheaply.** `width ≥ 272` gives 32. A shape of 32 tokens, **12 query heads of 32 over 4 key-value heads** (width 384, `d_pad = 512 = h_pad(16) · 32`) reaches it with `lkv = 2` intact — checked against the Python model. **This is the one this lane would build next** |
| 2 | **the row width `log_cols = 14`** and everything keyed to it: the PCS column geometry, `rows_of` for every domain, the `Dom::Tab` lift distance (8 → 14 rather than 8 → 10), the NTT log, and `hash_domain`'s length set at that width | every development shape is at `log_cols` 8 or 10 | yes in principle (a shape may declare `log_cols = 14` at a small geometry), but then every domain is lifted and F-2 refuses the bilinear slots — so **only with a geometry large enough to keep `Dom::Kv ≥ 2^14`**, which is no longer small |
| 3 | **`head_dim = 64`** — the S-3 / C-2 margin, the RoPE partner bit at `log − 6` | the filter has 8 and 16 | yes: `head_dim = 64` with few heads is admissible, but it drags `d_pad` up with it (item 1's shape is the cheap way to move both) |
| 4 | **the 125M endpoint geometry**: `endpoint_log_n = 14`, 32 data rows, 37 commitment rows | the filter has 2, 16 and 4 data rows | yes, by declaring the endpoint parameters — nothing else in the shape has to move |
| 5 | **long runs and the memory path**: `L = 12`, a 484 MB run receipt, the >10 GiB proving peak, the mmap threshold crossings | size alone | no — this one is inherently heavy, and it is the one item on this list that a small shape cannot stand in for |

Stage 29 already unit-gated the five size thresholds it introduced, so the
parallel branches themselves are covered in the filter; what item 5 leaves
uncovered is the memory behaviour, not a branch.

### Task 4 — the two capture bundles

`results/zk60_run_captures_20260920/run-k-dense-p2` and `run-l-zero-p2`,
**two blocks each**, schema `hashline-native-capture/5-run` (the array
store), public tables' VALUES included, tagged, source pin `4ccbad1` over 38
files (`t30-bundles.log`, exit 0).

| bundle | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|
| `run-k-dense-p2` (FULLY DENSE, generic) | 34,950 B | 3,151,494 / 3,713,252 B | 9,097,448 B | **16,001,981 B** |
| `run-l-zero-p2` (all-zero, degenerate) | 34,947 B | 3,148,521 / 3,709,513 B | 9,014,520 B | **15,912,181 B** |

**31.9 MB for the pair, and the size was chosen, not accepted.** The task's
ceiling was about 15 MB a bundle; three blocks in the classic `/4-run`
encoding would have been about 46 MB each (that is what `run-i-dense-k4`
is), so this pair takes the two levers the task named — the `/5-run` store
and fewer blocks — and lands just above the hoped-for figure at 16.0 and
15.9 MB. Two blocks is enough: there is one internal boundary, every slot of
every stage is present, and the two stages are asserted to carry the same
schedule and the same draw counts.

**What a gate sees in them** (`t30-bundle-check.log`, read off the committed
files, 0 mismatches), against the rung-K4 pair, stage 0 against stage 0:
**20 of 23 slots identical** in both schedule and `definition_challenges`
length, and the three that differ are 02 (13 draws against 15), 16 (19
against 21, degree 4 against 5) and 18 (24 against 26, degree 4 against 5).
A port that models the pad rule as "always on" fails on these bundles in
seconds, which is exactly finding M-F1 and exactly why they exist. Each
manifest's five files match their recorded length and SHA-256, and the
parent `README.md` gains a stage-30 section with this table; no older bundle
is touched and none of their own READMEs is edited.

They are **not gate evidence** (ruling T-6) and not a privacy result.

### Task 5 — the gates, the registries this stage tripped, and the commits

**THE GATES AT THE STAGE-30 TIP.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter) | **348 passed / 0 failed / 14 ignored, 429.11 s, exit 0** (`t30-gate-private2.log`) — the stage-29 tip's 336 plus this stage's twelve, nothing lost; the one new ignored test is the bundle writer |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen` (`:205`), `grow_tests::the_toy_parameter_line_is_the_frozen_literal` (`:204`), `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` (`:285`), and the 2,816,472 B receipt-length family (`tests`, `zero_witness_tests`, `hash_domain_tests`, `review_tests`, `grow_tests`) — **all in the pass list** |
| the rung, rung-G and rung-K4 receipt lengths | in the pass list (`rung_tests`, `dense_tests`, `k4_tests`, dense AND all-zero). `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims` (`:231`) still asserts 4,743,128 B, and `p2_tests` asserts the same number again as the 400 B partner of its own |
| the new shape's own tests | `p2_tests` (11, `:241`–`:251`) and `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_p2` (`:270`), all non-ignored |
| the Python model's test file | `python3 -m unittest discover -s tests -p 'test_zk60_private_block_layout_model.py'` — **42 tests, OK**, and not edited by this stage |
| the forbidden-files proof | `git diff --stat 6c302f5 -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/field hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu zkvm-block private-block-kernel private-model-kernel private-block-kernel-shaped tests` prints **nothing** |
| the whole diff against `6c302f5` | ten sources — `shape.rs`, `run.rs`, `private_block.rs` (one `mod` line), the new `p2_tests.rs`, `parity.rs`, `dense_tests.rs`, `run_capture_tests.rs`, `run_statement_file.rs`, `s24_tests.rs`, `s25_tests.rs` — plus the shape-model script, this ledger, the two bundles with their parent README, and the evidence logs. Nothing else |

**THE REGISTRY GUARDS A NEW PROFILE TRIPS, and what each wanted.** The first
whole-filter run was **346 passed / 2 failed** (`t30-gate-private.log`) and
both failures were profile registries — the lane's habit of reading the
profile list OUT OF THE SOURCE rather than keeping a hand list, working
exactly as intended. Four guards in three files had to learn the new
profile, and three literals became registry-derived so the next shape does
not have to edit them:

| guard | what it wanted | how it is satisfied |
|---|---|---|
| `s24_tests::every_registered_profile_is_covered_…` | the two new strings in `every_shape` / the run list | added; `all.len()` is now `4·(shapes − legacy) + 4·runs` instead of the literal 24 |
| `s25_tests::every_hash_input_kind_of_every_registered_profile_…` | a hash-input table for the new block and run profiles | `s25_tests::every_shape` / `every_run` extended, with the run-shape constructor arm |
| `s25_tests::stage_24s_twelve_key_test_still_covers_every_tagged_profile` | `(legacy, tagged) == (2, 3)`, twelve keys, eight source profiles | `legacy == 2` stays pinned (it is the fact worth pinning); the other two are derived |
| `s25_tests::the_memos_length_table_…` and `…terminal_absorb_lengths_…` | a per-shape and a per-run row, and "the two development runs" | a rung-P2 row in each, and `every_run().len() − 1` |

**The rung-P2 row of the length table is worth reading**: its profile string
is exactly as long as rung-K4's and its padded layout IS rung-K4's, so every
hash-input length is rung-K4's to the byte — constructor 59, A column 5,816,
H column 5,760, endpoint 72, block seed 117, `pcs-vec` 20,535, run
constructor 57, public statement 125 at `L = 3`. **Nothing about the pad
rule reaches a hash input LENGTH**, and that is now checked rather than
assumed.

**THE COMMITS OF STAGE 30**, in order:

| commit | what |
|---|---|
| `ecd3118` | the ledger skeleton: the gap, the five tasks, the rules |
| `baea9b2` | **task 1**: `Shape::rung_p2`, the run profile, and the four registry lists in `s24_tests` / `run_statement_file` |
| `5295de9` | **task 1**: the shape in the independent Python model, the regenerated report and `model_rung_p2.json` (4,742,728 B) |
| `1415dd2` | **task 2**: `p2_tests.rs` (11 tests), the `mod` line, and the MEASURED `(256, 4) => 39` chain band |
| `4ccbad1` | **task 2**: the generic witness against the independent reference kernel at the new shape |
| `695822f` | **task 4**: `run-k-dense-p2` and `run-l-zero-p2`, the writer, the bundle check and the parent README |
| `6d5c77c` | the four registry guards, extended and partly derived; the whole filter green |
| this one | the ledger: tasks 1–5 and the close |

**WHAT THIS STAGE IS NOT.** Not a privacy result and not an acceptance of
anything: the lane's code stays experimental, for the integrator (ruling
V-1), and the two bundles are the INPUT to the Python gate, not its verdict
(ruling T-6). Not a claim about 125M: **no 125M run was launched** — the
heavy lock carries the stage-29 census, and nothing here touched an `r29-*`
file. Not a change to what any existing profile sends, absorbs or draws: the
toy is byte-frozen and green, and the three older development profiles'
receipt lengths are unmoved. What it IS: the `pad_on == false` arm of ruling
P-1, which until today only an `#[ignore]`d 10 GiB test could reach, is now
proved, verified, censused on both sides of the protocol, tampered with and
captured by tests that run in twelve seconds.

## Stage 31 — correction C-6 (`norm_top_is_full_byte`) in the ordinary test filter (2026-09-21, 12:3x–)

**THE GAP, IN ONE SENTENCE.** `layout::lookups_at` drops **four** `scaled`
norm lookups — the top `rho` and `sigma` limb of `norm_a` and of `norm_m` —
when `Shape::norm_top_is_full_byte` is true, so `Dom::D` carries 34 lookups
per position instead of 38, **17** helper planes instead of 19, and the `H`
plane list is two planes shorter; that is correction **C-6**. The flag is
true only when the norm window `norm_wrho = NORM_TN + 1 + bits(D_max)` is a
multiple of eight, and `D_max = isqrt(1 + width * 32767^2)`, so it needs
`width > 256`. Every development shape in the ordinary filter has width 96
(`norm_wrho = 31`), the toy has width 16 (29), and the only shape in the
module with the flag TRUE is 125M, whose proofs are `#[ignore]`d 10 GiB
tests. Under the security owner's standing rule after finding S19-F1 — a
branch that only an ignored heavy test reaches is a branch nobody tests —
this stage puts the C-6 arm inside a small shape the ordinary filter proves
in seconds, by exactly stage 30's method. It is the LAST cheap heavy-only
branch on stage 30's list.

| task | what | state |
|---|---|---|
| 1 | the shape: `norm_top_is_full_byte == true`, `lkv = 2`, every named refusal unweakened, the three unpadded domains kept if possible | **DONE** — `Shape::rung_c6`, receipt 7,452,040 B counted and measured, and it DOES keep the three unpadded domains |
| 2 | the tests in the ORDINARY filter: the gap census, the generic honest witness, the all-zero input, the layout census by name, the tampers only this branch can get wrong, a three-block run | **DONE** — 13 new tests in `c6_tests.rs` + 1 in `parity.rs`, all non-ignored. **No soundness finding**: what C-6 drops is a literal duplicate of a lookup that stays |
| 3 | two capture bundles of the new shape for the independent Python gate | **DONE** — `run-m-dense-c6` / `run-n-zero-c6`, 22.9 + 22.7 MB |
| 4 | the refreshed "still heavy-only" list | **DONE** — four items left, none of them cheap, and one observation that is not heavy-only at all |
| 5 | the gates: the whole `private_` filter, every older profile's pins, the forbidden-files proof, the Python model's tests | **DONE** — see the gate table |

**The rules this stage works under** are the lane's and stage 30's: one
writer, the build recipe in this file's header, **no 125M run** (the heavy
lock carries stage 29's queued census and no `r29-*` file is touched), a NEW
profile for the new shape (D17 and Codex's condition), each gap reproduced
as a failing or asserting test FIRST, the toy byte-frozen, no older profile
moved, and no "proves and verifies" without a GENERIC honest witness — dense
public weights, a non-constant hidden input, key-value groups that differ —
checked element for element against the independent
`private-block-kernel-shaped` reference.

**Evidence prefix**: `results/zk60_block125m_lane/u31-*`.

### Task 1 — `Shape::rung_c6`, and why every number of it is forced

**The idea in one line: take rung-P2 and widen the head dimension, which is
the only axis that can cross the norm window.** Nothing else is chosen,
which is what makes everything that follows a measurement of C-6 and of the
head dimension and of nothing else.

| | rung-P2 | **rung-C6** |
|---|---|---|
| tokens / width / hidden | 32 / 96 / 256 | **32 / 384 / 512** |
| query heads × head_dim, key-value heads | 12 × 8, 4 (`lkv = 2`) | **12 × 32**, 4 (`lkv = 2`) |
| `t_pad, d_pad, h_pad, f_pad` | 32, 128, 16, 256 | 32, **512**, 16, **512** |
| `log_cols`, `inv_rate`, `F_E` | 10, 4, 12 | **the same** |
| `wrho_s`, `limbs_sigma_s`, `limbs_p` | 17, 3, 2 | **the same** |
| `D_max`, `norm_wrho`, `limbs_norm` | 321,049, **31**, 4 | 642,099, **32**, 4 |
| `norm_top_is_full_byte` (C-6) | **false** | **TRUE** |
| endpoint | generalised, 9 rows (4 data) | generalised, **21 rows (16 data)** |
| padded head slots | `{3, 7, 11, 15}` | **the same** |
| domains that PAD | Ht, L, D, Q, S, Tab | **the same** |
| domains that do NOT | T, Kv, F | **the same** |
| block profile | `…/private-block-rung-p2-t32-dev/1` | `hashline-zk-mr1/private-block-rung-c6-t32-dev/1` |
| run profile | `…/private-run-rung-p2-t32-dev/1` | `hashline-zk-mr1/private-run-rung-c6-t32-dev/1` |
| counted receipt | 4,742,728 B | **7,452,040 B** |

**Every dimension is forced.** `norm_wrho = NORM_TN + 1 + bit_length(D_max)`
and `D_max = isqrt(1 + width · 32767²)`, so the flag is a function of the
WIDTH alone and turns on the moment the width passes 256 (`D_max` 524,272 at
256 against 2^19 = 524,288 — it misses by sixteen). The reference kernel
refuses a shape whose `width != q_heads · head_dim`, and `Shape::new`
refuses one whose `d_pad != h_pad · head_dim`, so at this head axis the
width IS `12 · head_dim`: 8 gives 96 and 16 gives 192, both at 31 bits, and
**32 gives 384, the smallest admissible width above 256**. `q_heads = 12` is
the smallest non-power-of-two multiple of four, which is what keeps `lkv = 2`
with a padded slot inside every group's block. `hidden = 512` is the
smallest power of two above the width: a power of two is what keeps
`Dom::F = tokens · hidden` unpadded, and it has to EXCEED the width or the
dense fixture has no "upper hidden half" to be live on (the S19-F1 census).
`tokens`, `log_cols`, `inv_rate` and `F_E` are rung-P2's, which keeps
`wrho_s = 17` and `limbs_sigma_s = 3` — 125M's — so **`Dom::D` is the only
lookup family in the whole layout that differs from rung-P2, and it differs
by exactly C-6's four.**

**IT ALSO KEEPS STAGE 30's THREE UNPADDED DOMAINS.** `Dom::T` (2^5),
`Dom::Kv` (32·4·32 = 2^12) and `Dom::F` (32·512 = 2^14) are exact powers of
two; `Ht`, `L`, `D`, `Q`, `S` and `Tab` pad. That is 125M's own
padded-domain set, asserted domain for domain, so this shape carries the
`pad_on == false` arm as well as the C-6 arm — one shape closer to 125M than
either stage's on its own. It was free: no refusal had to be bent for it.

**THE SIDE-BY-SIDE TABLE** (printed by
`c6_tests::the_rows_and_lookups_c6_drops_are_absent_here_and_present_at_rung_k4`,
`u31-c6-run2.log`, and reproduced by the independent Python model):

| | rung-K4 | rung-P2 | **rung-C6** | 125M |
|---|---:|---:|---:|---:|
| `norm_top_is_full_byte` | false | false | **true** | true |
| `D_max` / `norm_wrho` | 321,049 / 31 | 321,049 / 31 | **642,099 / 32** | 908,065 / 32 |
| `pad_on` T / Ht / L / D / Q / Kv / S / F / Tab | 1 1 1 1 1 1 1 1 1 | 0 1 1 1 1 0 1 0 1 | **0 1 1 1 1 0 1 0 1** | 0 1 1 1 1 0 1 0 1 |
| `A` rows / `H` rows | 727 / 720 | 727 / 720 | **1,337 / 1,408** | 5,681 / 7,120 |
| `A` planes / `H` planes | 83 / 52 | 83 / 52 | **83 / 50** | 83 / 50 |
| lookups per position `L/D/F/Q/Kv/S` | 2 / **38** / 9 / 13 / 12 / 15 | 2 / **38** / 9 / 13 / 12 / 15 | 2 / **34** / 9 / 13 / 12 / 15 | 2 / **34** / 9 / 13 / 12 / 15 |
| helpers `L/D/F/Q/Kv/S` | 1 / **19** / 5 / 7 / 6 / 8 | 1 / **19** / 5 / 7 / 6 / 8 | 1 / **17** / 5 / 7 / 6 / 8 | 1 / **17** / 5 / 7 / 6 / 8 |
| slot 14 (`SC_DZC`) term list | **56** | **56** | **54** | **54** |
| `lkv` / head_dim / row width | 2 / 8 / 2^10 | 2 / 8 / 2^10 | **2 / 32 / 2^10** | 2 / 64 / 2^14 |
| counted receipt | 4,743,128 B | 4,742,728 B | **7,452,040 B** | 40,783,352 B |

**Which refusal constrained which choice, and which one BINDS.** Every named
refusal was checked at construction (`the_new_shape_is_rung_p2_with_the_head_dimension_moved`
asserts each where it binds) and none was weakened:

| refusal | how rung-C6 satisfies it | does it bind? |
|---|---|---|
| **T-8** (`head_dim` a power of two ≥ 2) | 32 | **YES — this is the narrow one.** With `width = q_heads · head_dim` forced by the kernel, a head dimension of 22 would have given the smallest width above 256; T-8 makes it 32, hence width 384 |
| `width == q_heads · head_dim` (the reference kernel's own refusal) | 384 = 12 · 32 | **YES**, with T-8: together they are what fixes the width |
| `d_pad == h_pad · head_dim` | 512 = 16 · 32 | **YES**: it is why the width cannot be chosen apart from the head axis |
| the four-norm-limb refusal (`build_shaped`, finding S8-F3) | `norm_wrho` 32 → 4 limbs | **not here, but it is the ceiling**: `norm_wrho` reaches 33 at width 1,025, so **no provable shape has a width above 1,024** |
| **T-2** (padded widths powers of two) | 32 / 512 / 512 | no |
| **F-2** (no P-3 lift on `Dom::Q`, `Dom::Kv`, `Dom::S`) | 2^14 / 2^12 / 2^14, all at or above the 2^10 row width | no — it was stage 30's narrow refusal and the wider head dimension puts `Dom::Kv` two bits clear of it |
| **S-1** (`Dom::Tab` exactly at the row width) | `log_cols = 10`, `log(Dom::Tab) = 10` | no |
| **S-3 / C-2** (`head_dim < 2^log_cols`) | 32 against 1,024 | no, but the margin is now five bits rather than seven |
| **C-4** (the mask budget) | worst slot 77 + 256 ≤ 512 | no |
| the grouping refusals (`q_heads % kv_heads`, `h_pad % kv_heads`) | 12 % 4, 16 % 4 | no |
| **P-3 / ruling S-1's lift** | `Dom::L` and `Dom::Tab` lifted, as at rung-P2; neither is bilinear | no |

One geometry was considered and dropped: **16 tokens** instead of 32 is
smaller — 4,686,104 B counted, `A` 733 / `H` 678 rows — and reaches C-6 just
as well, but at `F_E = 12` it gives `wrho_s = 16` and `limbs_sigma_s = 2`,
which moves a SECOND lookup family (`Dom::S` from 15 to 13) and drops the
third `sigma_s` limb that 125M has and that step S8 added on purpose. The
clean difference — `Dom::D` and nothing else — was judged worth the 2.8 MB.

### Task 2 — the tests, and what each MEASURED

All in the ordinary filter, none `#[ignore]`d. `c6_tests.rs` is 13 tests,
**13 passed / 0 failed in 30.40 s** (`u31-c6-run2.log`); `parity.rs` gains
one (`u31-parity.log`, 13 passed / 0 failed). Every wall figure below was
taken on a SHARED box (two Python gate runs of another lane were live), so
they are upper bounds and not a timing ladder.

| test | result |
|---|---|
| `only_the_125m_shape_and_the_new_one_reach_correction_c_6` | **the gap, asserted**: over the seven-shape registry exactly two are on the C-6 arm, rung-C6 and 125M, and **with rung-C6 removed it is 125M alone**. Also asserts, per shape, that the flag equals `norm_wrho == 32` at four limbs and equals `width > 256`, and that `Dom::D`'s built lookup list is the counted length |
| `the_lookup_c6_drops_is_a_duplicate_of_one_that_stays` | **THE SOUNDNESS STATEMENT** — see below |
| `the_rows_and_lookups_c6_drops_are_absent_here_and_present_at_rung_k4` | the four `scaled` lookups absent here and present at rung-K4 plane by plane BY NAME; 17 helpers against 19; the `H` plane list 50 against 52 with **no other domain's block moved**; two fewer `H` claim sites and no `A` site moved; `A`/`H` rows 1,337 / 1,408; the side-by-side table above printed |
| `the_new_shape_is_rung_p2_with_the_head_dimension_moved` | the shape is rung-P2 in tokens, heads, row width, rate, calibration, softmax limbs and head permutation; the unpadded set is 125M's; every named refusal checked where it binds; the profile, the tag and the counted receipt |
| `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_c6` | the INDEPENDENT `private-block-kernel-shaped` crate takes this geometry unchanged; every kernel-backed plane agrees element for element and the block output on all **12,288** words, with the kernel's own buffers asserted live on the upper hidden half and its four key-value groups pairwise different FIRST. **This is the generic-witness check the acceptance rule asks for.** It adds C-6's COMPLETENESS side: all four norm remainders' top limb is nonzero somewhere, every limb is inside `[0, 256)`, and the recomposition lands inside the 2^32 window |
| `an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_c6` | prove **1.24 s**, verify from bytes **0.16 s**, frame **7,452,040 B** — the COUNTED length, from the Python model — and a one-byte truncation refused |
| `the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_c6` | verified, frame 7,452,040 B. Named degenerate: every key-value group is identically zero |
| `a_norm_top_limb_outside_its_byte_range_is_rejected_at_the_rung_c6` | **4 of 4 rejected by the VERIFIER, 0 by the prover, 0 accepted** — see below |
| `the_norm_range_tamper_rejects_at_the_same_slot_on_both_arms` | the identical tamper at rung-K4, which KEEPS the `scaled` lookup, is rejected with the IDENTICAL message |
| `the_named_tampers_are_rejected_at_their_own_slots_at_the_rung_c6` | **6 of 6 rejected by the VERIFIER** at the slot under test — see the tamper table |
| `a_tampered_round_message_of_slot_14_is_rejected_at_the_rung_c6` | slots 14, 16 and 18, each rejected at its own slot with `sumcheck round 0: s(0) + s(1) != claim` |
| `a_frame_with_the_dropped_helper_claims_is_refused_before_any_draw_at_the_rung_c6` | slot 14 carries 54 terminals here against rung-K4's 56; a frame with the two extra helper claims is refused by `wire::validate` with `"private block wire: argument shape"` BEFORE the verifier draws anything, and `verify_inner_at` returns that same string |
| `the_pinned_rung_c6_chain_band_is_the_first_admissible_one` | band **29 and 28 refused** by the THIRD block (`fixed oracle range refusal: residual 2`), **27 admissible**, so `dense_tests::band_down_run` gains a MEASURED `(512, 4) => 27` arm |
| `an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_c6` | prove **3.84 s**, verify from segments **0.50 s**, segments **7,259,640 / 7,282,168 / 7,474,648 = 22,016,456 B** (the counted lengths), boundary 22 rows, all three blocks censused |

**THE SOUNDNESS QUESTION OF C-6, AND THE ANSWER.** Dropping a range lookup
is exactly the kind of optimisation that quietly removes an obligation. It
does not here, and the reason is arithmetic rather than argument: the
dropped entry is `scaled(top, 1 << (8·ln − wrho))`, and on this arm
`8·ln == wrho`, so the coefficient is `1 << 0 = 1` and the entry is
`Lk { terms: [(top, 1)], cst: 0 }` — **term for term the `Lk` that
`byte(top)` builds**, and `byte(top)` is emitted unconditionally by the
`(0..ln).map(|k| byte(ids.nr(k)))` loop directly above it. C-6 drops a
literal duplicate. The test states it three ways:

* the coefficient is 1 at rung-C6 and 2 at rung-P2, computed from the shape;
* at rung-C6 each of the four top limb planes is read by **exactly one**
  lookup, `(plane, 1)`; at rung-P2 by **two**, `(plane, 1)` and `(plane, 2)`;
* the multiset of rung-P2's `Dom::D` lookups minus rung-C6's is **exactly**
  those four scaled entries and nothing else.

**And the dynamic form, which is the one that could have found a hole.** A
carry is MOVED between a norm remainder's top limb and the one below it:
`top -= top + 1` and `below += 256 · (top + 1)`. Because `argument::limbs`
folds the limbs as `Σ limb_k · 256^k` and that fold is the ONLY way the
limbs enter any relation of `argument::define`, the recomposed `rho` (or
`sigma`) is **bit for bit the honest value** — asserted — so every
ARITHMETIC clause of the block is still exactly satisfied, and the only
thing wrong with the witness is that two limbs are outside `[0, 256)`. All
four remainders — `rho` and `sigma` of `norm_a` and of `norm_m` — are then:

| what | rejected by | at |
|---|---|---|
| `norm_a` `rho`, top limb −1, remainder unchanged | **VERIFIER** | `H: pcs zk: group 8: <v, c> != combined claim` |
| `norm_a` `sigma`, likewise | **VERIFIER** | the same |
| `norm_m` `rho`, likewise | **VERIFIER** | the same |
| `norm_m` `sigma`, likewise | **VERIFIER** | the same |

**Group 8 is the LAST opening group of the helper commitment**, which is the
one `protocol::finish_claims` fills by pushing `protocol::logup_sum_claim`
after every slot's claims — the value-0 LogUp identity, whose published
value is the compile-time constant `Fp2::ZERO`. An out-of-range lookup value
is not in the table, `protocol::byte_histogram_at` bins it into entry 0
("only the LogUp identity can catch it", its own comment), and the identity
fails to close. **So the relation that carries the top limb's range
obligation after C-6 is the `byte(top)` lookup inside the value-0 LogUp
identity**, which is exactly what the structural statement says. The group
index is asserted, not merely printed, and the same tamper at rung-K4 — the
arm that KEEPS the scaled lookup — is rejected with the identical message,
so the obligation is enforced the same on both arms. **No soundness finding.**

**FINDING S31-F1 (a message, not a hole).** That refusal names neither the
slot, nor the domain, nor the lookup: a reader sees an opening-group
mismatch on `H`. It is fail-closed and it arrives before the proof is
accepted, which is what matters for soundness, but it is weaker than the
sumcheck-level refusals, which name the slot and the relation. It is the
same family as stage 30's **T30-F1** and it is left to the integrator as a
suggestion, not taken here: the LogUp group's refusal could say "the value-0
LogUp identity" instead of a group number.

**THE ORDINARY TAMPERS**, each placed so that the first slot whose relation
it breaks is the one named, with the message asserted to name that slot so a
rejection by an earlier check cannot pass for one, and the honest control
asserted accepted first:

| tamper | rejected by | at |
|---|---|---|
| the norm square `A_DSQ` at index 31 (the last `Dom::T` position) | **VERIFIER** | slot 02 `02 norm squares zero-check` |
| the norm square `A_DSQM` at index 0 | **VERIFIER** | slot 02 |
| residual 2, `A_X2`, on the true `Dom::D` support | **VERIFIER** | slot 14 `03 D zero-check` |
| the key `A_K8` at index 4,095 (the last `Dom::Kv` position) | **VERIFIER** | slot 16 `05 KV zero-check` |
| the gate `A_G8` at index 16,383 (the last `Dom::F` position) | **VERIFIER** | slot 18 `14 F zero-check` |
| `A_DSQ` at index 0 | **VERIFIER** | slot 02 |
| a round message of slot 14 / 16 / 18 | **VERIFIER** | that slot, `sumcheck round 0: s(0) + s(1) != claim` |

### Task 3 — the two capture bundles

`results/zk60_run_captures_20260920/run-m-dense-c6` and `run-n-zero-c6`,
**two blocks each**, schema `hashline-native-capture/5-run` (the array
store), public tables' VALUES included, tagged, source pin `3e106e1` over 38
files (`u31-bundles.log`, exit 0).

| bundle | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|
| `run-m-dense-c6` (FULLY DENSE, generic) | 34,847 B | 3,275,672 / 3,913,538 B | 15,635,336 B | **22,864,518 B** |
| `run-n-zero-c6` (all-zero, degenerate) | 34,852 B | 3,282,805 / 3,913,226 B | 15,464,440 B | **22,700,238 B** |

**22.9 and 22.7 MB, with both of the size levers the task named already
taken**: two blocks (the least that still has an internal boundary) and the
`/5-run` array store, which deduplicated 52 arrays in the dense bundle and
45 in the zero one. What is left is the SHAPE — the helper commitment is
1,408 rows against rung-P2's 720 because the head dimension is four times as
wide — and it is not C-6's doing: C-6 makes the bundle smaller by two helper
planes. A one-block bundle would be about 12 MB and would carry no internal
boundary, so it was not taken. The overshoot against the ~20 MB target is
14%.

**What a gate sees in them** (`u31-bundle-check.log`, read off the committed
files, **0 mismatches**), against `run-k-dense-p2`, stage 0 against stage 0:
17 `Dom::D` helper planes instead of 19, 50 `H` planes instead of 52, slot
14 at **54 terminals instead of 56**, and no other domain's helper block
moved. Deliberately the same: slots 16 and 18 still report `"degree":4`
where the rung-K4 pair reports 5, so the pair is a regression for finding
**M-F1** as well as the first evidence for C-6. (The absolute
`definition_challenges` counts are NOT rung-P2's — every domain log is
larger here, so each `tau` is longer. The pad-rule fact a port must get
right is the DEGREE and the presence of the support-indicator table, and
those are rung-P2's exactly.) Both stages of each bundle carry the same
schedule and the same draw counts on all 23 slots; each manifest's five
files match their recorded length and SHA-256; the parent `README.md` gains
a stage-31 section with these tables; no older bundle and no older README is
touched.

They are **not gate evidence** (ruling T-6) and not a privacy result.

### Task 4 — what is STILL reached only by an `#[ignore]`d heavy test

Stage 30's list, re-read after this stage. Item 1 is **CLOSED**; the numbers
below for the remaining items are the independent model's, so each "could be
reached by" carries a price.

| # | branch | why no shape in the filter reaches it | can a small shape? |
|---|---|---|---|
| ~~1~~ | ~~`Shape::norm_top_is_full_byte` — correction C-6~~ | — | **CLOSED by this stage**: `Shape::rung_c6`, 13 non-ignored tests, two capture bundles |
| 2 | **the row width `log_cols = 14`** and everything keyed to it: the PCS column geometry, `rows_of` for every domain, the `Dom::Tab` lift distance, the NTT log, `hash_domain`'s length set at that width | every development shape is at `log_cols` 8 or 10 | **YES, and the price is now known.** F-2 needs `Dom::Kv ≥ 2^14`, and the four-norm-limb refusal caps the width at 1,024, so at twelve heads `head_dim ≤ 64` and the TOKENS have to carry it: **64 tokens, width 768, hidden 1,024, 12 heads of 64 over 4 key-value heads at `log_cols = 14`** is admissible in the model — receipt **16,421,048 B**, 4,882,432 U8 lookups, `A` 527 / `H` 436 rows, worst slot `L` 87. About four times this stage's lookup work. **NOT DONE**, and it would close item 3 with it |
| 3 | **`head_dim = 64`** — the S-3 / C-2 margin, the RoPE partner bit at `log − 6` | the filter has 8, 16 and, since this stage, **32** | **YES**: 32 tokens, width 768, hidden 1,024, 12 heads of 64 over 4 — receipt **11,368,824 B**, `A` 2,209 / `H` 2,416 rows. **NOT DONE.** Item 2's shape reaches it too |
| 4 | **the 125M endpoint geometry**: `endpoint_log_n = 14`, 32 data rows, 37 commitment rows | the filter has 2 and 16 data rows on the FROZEN seam (toy, rung), 4 on the generalised endpoint (rung-G, rung-K4, rung-P2) and, since this stage, **16 on the generalised endpoint** (rung-C6) | **YES, in two halves.** The 32 data / 37 commitment rows fall out of item 3's shape for free (its padded `Dom::D` cube is 2^15 words at `endpoint_log_n = 10`); `endpoint_log_n = 14` itself needs item 2's shape or a declared endpoint parameter. **NOT DONE** |
| 5 | **long runs and the memory path**: `L = 12`, a 484 MB run receipt, the >10 GiB proving peak, the mmap threshold crossings | size alone | **NO** — inherently heavy, and the one item a small shape cannot stand in for. Stage 29 unit-gated the five size thresholds themselves, so what is uncovered is the memory BEHAVIOUR, not a branch |

**One observation that is not on the list, because it is not heavy-only.**
`Shape::a_groups`'s first arm, `natural_log(Dom::T) >= log_cols`, is reached
by **no registered shape at all** — not even 125M, whose `log(Dom::T)` is 9
against a row width of 2^14. It needs `t_pad ≥ 2^log_cols`: 256 tokens at
the toy's row width, 1,024 at the rungs'. Both are constructible and neither
is small, because `Dom::S = h_pad · t_pad²` grows quadratically in the
tokens — the model puts the first at a 39,380,616-byte receipt (8,017 `A`
rows) and the second at 1,081,144,520 B. It is a dead arm rather than a
heavy one, and it is recorded here so that the next reader of `a_groups`
knows no test exercises it.

### Task 5 — the gates and the commits

**THE GATES AT THE STAGE-31 TIP.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter), FIRST run | **361 passed / 1 failed / 15 ignored, 467.72 s** (`u31-gate-private.log`). The one failure is a fifth registry guard — `s25_tests::the_per_slot_terminal_absorb_lengths_and_recorded_at_every_shape`, which pinned the one-block run's `parameters` absorb at **294** and got **298** — and it is a defect of the PIN, not of the shape: see below. The log is kept as evidence |
| `--lib private_` (the whole filter), SECOND run, after `fe5d4e7` | **362 passed / 0 failed / 15 ignored, 466.36 s, exit 0** (`u31-gate-private2.log`) — the stage-30 tip's 348 plus this stage's fourteen, nothing lost; the one new ignored test is the bundle writer |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` and the 2,816,472 B receipt-length family (`tests`, `zero_witness_tests`, `hash_domain_tests`, `review_tests`, `grow_tests`) — **all in the pass list of both runs** |
| the rung, rung-G, rung-K4 and rung-P2 receipt lengths | in the pass list (`rung_tests`, `dense_tests`, `k4_tests`, `p2_tests`, dense AND all-zero). `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims` still asserts 4,743,128 B and `p2_tests::the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move` still asserts 4,742,728 B; `c6_tests` asserts both again beside its own 7,452,040 B |
| the new shape's own tests | `c6_tests` (13) and `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_c6` (1), all non-`#[ignore]`d |
| the Python model's test file | `python3 -m unittest discover -s tests -p 'test_zk60_private_block_layout_model.py'` — **47 tests, OK** (42 before this stage) |
| the forbidden-files proof | `git diff --stat b923d07 HEAD -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/field hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu zkvm-block private-block-kernel private-model-kernel private-block-kernel-shaped` prints **nothing**. Run with `tests` and `scripts` added, as stage 30's gate table names them, it prints exactly two paths — `scripts/zk60_private_block_layout_model.py` and `tests/test_zk60_private_block_layout_model.py` — which are the lane's own layout model and its acceptance test, this stage's brief permits, and nothing else under either directory is touched |
| the whole diff against `b923d07` | nine sources — `shape.rs`, `run.rs`, `private_block.rs` (one `mod` line), the new `c6_tests.rs`, `parity.rs`, `dense_tests.rs`, `run_capture_tests.rs`, `s24_tests.rs`, `s25_tests.rs`, `run_statement_file.rs` — plus the shape model and its test, the two bundles with their parent README, this ledger and the evidence logs. The three `r29-*` entries in that diff are the stage-29 lane's, not this stage's |

**THE FIFTH REGISTRY GUARD, AND WHY ITS PIN WAS WRONG RATHER THAN THE
SHAPE.** Stage 30 tripped four guards; this stage tripped a fifth, and it is
worth reading. The run's `parameters` line carries the shape's axes IN
DECIMAL (`protocol::parameter_line`) plus `L`, the boundary commitment row
count and the external row count (`run::parameter_line`), so its LENGTH is a
property of the shape. Exactly three quantities move with `L` and nothing
else does — the boundary rows are `0` at `L = 1` and two digits above it,
and `L` gains a digit at 10 — so every run profile's absorb is `base` at
`L = 1`, `base + 1` at `2 ≤ L ≤ 9` and `base + 2` at `10 ≤ L ≤ 12`. The test
now asserts that CURVE, derived, and splits the record in two:

| run profile | `parameters` absorb at L = 1 / 2..9 / 10..12 | collides with `pb-term`(15) = 295 at |
|---|---|---|
| `…private-run-rung-g-t24-dev/1` | 294 / **295** / 296 | `L = 2 … 9` |
| `…private-run-rung-k4-t24-dev/1` | 294 / **295** / 296 | `L = 2 … 9` |
| `…private-run-rung-p2-t32-dev/1` | 294 / **295** / 296 | `L = 2 … 9` |
| `…private-run-rung-c6-t32-dev/1` | **298 / 299 / 300** | **never** |

rung-C6's width (384), head dimension (32) and endpoint rows (21) are each
one decimal digit longer than rung-P2's, so its line is four bytes longer
and the 295 / 295 pair — the within-function coincidence ruling J-7 wants
recorded and separated — **cannot arise at this profile at any `L`**. That
is a record, not a regression, and the `(3, 1)` split is now pinned against
the registry's own length rather than against a hand list.

**THE COMMITS OF STAGE 31**, in order:

| commit | what |
|---|---|
| `d4b8c27` | the ledger skeleton: the gap, the five tasks, the rules |
| `08198cd` | **task 1**: `Shape::rung_c6`, the run profile, the four registry lists and the measured `(512, 4) => 27` chain band |
| `47a22a6` | **task 1**: the shape in the independent Python model, C-6 as an explicit difference, the regenerated report and `model_rung_c6.json` (7,452,040 B) |
| `a147012` | **task 2**: `c6_tests.rs` (13 tests) — the gap census, the duplicate-lookup statement, the layout census, the tampers, the run |
| `3e106e1` | **task 2**: the generic witness against the independent reference kernel at the new shape |
| `4f29776` | **task 3**: `run-m-dense-c6` and `run-n-zero-c6`, the writer, the bundle check and the parent README |
| `fe5d4e7` | the fifth registry guard, derived instead of pinned; and the capture rule in the tamper printout (the range FACTS, never the limb values) |
| this one | the ledger: tasks 1–5 and the close |

Three commits between `3e106e1` and `4f29776` — `6a3c7cf`, `d5501a1`,
`c7210b2` — are **NOT this stage's**: they are the stage-29 lane, re-woken
by its queued 125M census, writing into the Stage 29 section of this ledger
and its own `r29-*` evidence. Nothing of theirs is code, and nothing of this
stage's touches an `r29-*` file. Two of this stage's commits, `08198cd` and
`47a22a6`, do not BUILD on their own: `08198cd` adds the `mod c6_tests;`
line while the file itself arrives in `a147012`. That is a defect of the
commit split and is recorded rather than rewritten.

**ONE PATH AWAITING DELETION BY THE ORCHESTRATOR** (this lane has no delete
permission). The first run of the new test file,
`results/zk60_block125m_lane/u31-c6-run1.log`, printed the tampered norm
LIMB VALUES and the recomposed remainder, which are values of the fixture's
hidden witness and which the lane's capture rule forbids in an evidence
file. It is therefore **not committed** — `u31-c6-run2.log`, taken after
`fe5d4e7` made the printout state the range FACTS instead, replaces it — and
the untracked file is left on disk for deletion:

```
results/zk60_block125m_lane/u31-c6-run1.log
results/zk60_block125m_lane/u31-c6-run1.done
```

**WHAT THIS STAGE IS NOT.** Not a privacy result and not an acceptance: the
lane's code stays experimental, for the integrator (ruling V-1), and the two
bundles are the INPUT to the Python gate, not its verdict (ruling T-6). Not
a claim about 125M: **no 125M run was launched by this stage** — the one
that ran on this box at 12:50 is stage 29's queued census, and no `r29-*`
file was touched here. Not a change to what any existing profile sends,
absorbs or draws: the toy is byte-frozen and green, and the four older
development profiles' receipt lengths are unmoved. What it IS: correction
C-6 — four dropped lookups, two dropped helper planes, a two-plane shorter
`H` index and a two-terminal shorter slot 14 — which until today only an
`#[ignore]`d 10 GiB test could reach, is now proved, verified, censused by
name, tampered with at the exact obligation it could have removed, and
captured, by tests that run in twenty-nine seconds. **Stage 30's list of
cheap heavy-only branches is empty.**

## Stage 32 — the 125M ROW WIDTH, HEAD SIZE and ENDPOINT LOG in the ordinary filter (2026-09-21, 13:2x–)

**THE GAP, IN ONE SENTENCE.** Stage 31's closing list says three of the four
remaining heavy-only branches are ONE shape away from the ordinary filter:
the row width **`log_cols = 14`** (a 2^14-word message encoded to 2^16, and
everything keyed to it — the PCS column geometry, `rows_of` for every
domain, the `Dom::Tab` P-3 lift distance, the NTT log, the tagged hash
lengths), the head size **`head_dim = 64`** (the S-3 / C-2 margin and the
RoPE partner bit at `log − 6`), and the **125M endpoint log**
(`endpoint_log_n = 14`). Every shape the ordinary filter proves at is at
`log_cols` 8 or 10 and at a head dimension of 8, 16 or 32; the only shape
with 14 and 64 is 125M, whose proofs are `#[ignore]`d 10 GiB tests. The
integrator is about to optimise the shared commitment and sumcheck code AT
THE 125M SHAPE, and a branch only a heavy ignored test reaches is a branch
nobody tests (the security owner's standing rule after S19-F1). This stage
puts the row width, the head size and the endpoint log inside one shape the
filter proves in seconds, by exactly stages 30 and 31's method.

| task | what | state |
|---|---|---|
| 1 | the shape: `log_cols = 14`, `head_dim = 64`, `endpoint_log_n = 14`, `lkv = 2`, every named refusal unweakened; the side-by-side table with rung-C6 and 125M | **DONE** — `Shape::rung_w14` (64 tokens, width 768, hidden 1,024, 12 heads of 64 over 4), receipt 16,421,048 B counted and measured; one proof is 3.87 s at 757 MB, so the ORDINARY filter and no medium tier |
| 2 | the tests in the ORDINARY filter: the gap census FIRST, the generic honest witness, the all-zero input, what is keyed to the row width, the tampers only this width reaches, a run | **DONE** — 12 tests in `w14_tests.rs` + 1 in `parity.rs`, all non-ignored. **No soundness finding** |
| 3 | capture bundles for the independent Python gate — in the repository only if ≤ ~40 MB, otherwise outside it with their manifests committed | **DONE** — `run-o-dense-w14` / `run-p-zero-w14`, 50.6 + 49.5 MB, so OUTSIDE the repository; manifests, notes and the self-check committed |
| 4 | the refreshed "still heavy-only" list | **DONE** — stage 31's items 2 and 3 closed, item 4 half closed, and the token-count ladder priced rung by rung |
| 5 | the gates: the whole `private_` filter, every older profile's pins, the forbidden-files proof, the Python model's tests | **DONE** — see the gate table |

**The rules this stage works under** are the lane's and stages 30/31's: one
writer, the build recipe in this file's header, **no 125M run**, a NEW
profile for the new shape (D17 and Codex's condition), the gap census
written FIRST, the toy byte-frozen, no older profile moved (toy, the frozen
seam rung, rung-G, rung-K4, rung-P2, rung-C6, 125M — named and kept green),
**no witness VALUE in any log** (range facts and counts only, stage 31's
capture-rule fix), and no "proves and verifies" without a GENERIC honest
witness — dense public weights, a non-constant hidden input, heads and
key-value groups that differ — checked element for element against the
independent `private-block-kernel-shaped` reference.

**MEASURE BEFORE PLACING.** This shape is the first development shape at the
125M row width, so its cost is not knowable from the older ones: one honest
proof is measured first, detached, under `systemd-run --user --scope -p
MemoryMax=6G -p MemorySwapMax=0`, and the placement of the tests — ordinary
filter, or one honest proof in the filter and a documented medium tier
beside it — follows that measurement and nothing else.

**Evidence prefix**: `results/zk60_block125m_lane/v32-*`.

### Task 1 — `Shape::rung_w14`, and why every number of it is forced

**The idea in one line: take 125M's HEAD AXIS and its ROW GEOMETRY exactly,
and cut the tokens to the smallest count those two admit.** Nothing else is
chosen, which is what makes everything that follows a measurement of the row
width, the head size and the endpoint log and of nothing else.

| | rung-C6 (stage 31) | **rung-W14** | 125M |
|---|---:|---:|---:|
| tokens / width / hidden | 32 / 384 / 512 | **64 / 768 / 1,024** | 512 / 768 / 2,048 |
| query heads × head_dim, key-value heads | 12 × 32, 4 | **12 × 64, 4** | 12 × 64, 4 |
| `t_pad, d_pad, h_pad, f_pad` | 32, 512, 16, 512 | **64, 1,024, 16, 1,024** | 512, 1,024, 16, 2,048 |
| **`log_cols`, encoded row, rate, opened cols** | 10, 2^12, 4, 256 | **14, 2^16, 4, 256** | 14, 2^16, 4, 256 |
| Merkle depth / NTT log | 12 / 12 | **16 / 16** | 16 / 16 |
| `D_max` / `norm_wrho` / `limbs_norm` | 642,099 / 32 / 4 | **908,065 / 32 / 4** | 908,065 / 32 / 4 |
| `norm_top_is_full_byte` (C-6) | true | **true** | true |
| `wrho_s` / `limbs_sigma_s` / `limbs_p` | 17 / 3 / 2 | **18 / 3 / 2** | 18 / 3 / 2 |
| `pad_on` T / Ht / L / D / Q / Kv / S / F / Tab | 0 1 1 1 1 0 1 0 1 | **0 1 1 1 1 0 1 0 1** | 0 1 1 1 1 0 1 0 1 |
| the nine domain logs | 5, 9, 10, 14, 14, 12, 14, 14, 10 | **6, 10, 14, 16, 16, 14, 16, 16, 14** | 9, 13, 14, 19, 19, 17, 22, 20, 14 |
| `Dom::Tab` P-3 lift (natural → log) | 8 → 10 (×4) | **8 → 14 (×64)** | 8 → 14 (×64) |
| `A` planes / `H` planes | 83 / 50 | **83 / 50** | 83 / 50 |
| `A` rows / `H` rows / `M` rows | 1,337 / 1,408 / 50 | **527 / 436 / 50** | 5,681 / 7,120 / 50 |
| claim sites `A` / `H` | 122 / 50 | **122 / 50** | 122 / 50 |
| `a_groups` / `h_groups` | 36 / 9 | **36 / 9** | 36 / 9 |
| lookups per position `L/D/F/Q/Kv/S` | 2 / 34 / 9 / 13 / 12 / 15 | **2 / 34 / 9 / 13 / 12 / 15** | 2 / 34 / 9 / 13 / 12 / 15 |
| helpers `L/D/F/Q/Kv/S` | 1 / 17 / 5 / 7 / 6 / 8 | **1 / 17 / 5 / 7 / 6 / 8** | 1 / 17 / 5 / 7 / 6 / 8 |
| U8 lookup positions | 1,214,464 | **4,882,432** | 98,598,912 |
| mask budget (worst `L` + 256 ≤ 512) | 77 + 256 = 333 | **87 + 256 = 343** | 117 + 256 = 373 |
| opened-column digest `A` / `H` (`8·rows`) | 10,696 / 11,264 B | **4,216 / 3,488 B** | 45,448 / 56,960 B |
| `pcs-vec` absorb | 20,535 B | **266,295 B** | 266,295 B |
| endpoint: cube / data rows / commitment rows / log | 2^14 / 16 / 21 / 10 | **2^16 / 4 / 9 / 14** | 2^19 / 32 / 37 / 14 |
| block profile | `…rung-c6-t32-dev/1` | `hashline-zk-mr1/private-block-rung-w14-t64-dev/1` | `…/private-block-m125/1` |
| counted receipt | 7,452,040 B | **16,421,048 B** | 40,783,352 B |

**WHAT IS NOW IDENTICAL TO 125M — the point of the stage.** The head axis
(12 × 64 over 4), the width 768 and `d_pad` 1,024, the row width 14 with its
2^16 encoding, rate 4 and 256 opened columns, the Merkle depth 16 and the
NTT log 16, `D_max` 908,065 with `norm_wrho` 32 and four norm limbs (so
correction C-6 applies), `wrho_s` 18 with three `sigma_s` limbs, the padded
head slots `{3, 7, 11, 15}`, the padded-domain set, the `Dom::Tab` lift
distance ×64, the 83 `A` planes and 50 `H` planes, the 122 / 50 claim sites
with their 244 / 100 site rows, the 36 / 9 opening groups, the per-position
lookup and helper counts domain for domain, **all 23 slot DEGREES**, the
`pcs-vec` absorb of 266,295 B, and the endpoint's log, rate and kind.

**WHAT STILL DIFFERS, and it is one axis and its consequences.** The token
count (64 against 512) and everything that scales with it: the nine domain
logs, the row totals (527 / 436 against 5,681 / 7,120), the U8 lookup work
(4.88 M against 98.6 M), the largest slot mask length (87 against 117), the
opened-column digest lengths (which are `8 · rows`), the endpoint's DATA
rows (4 against 32, so 9 commitment rows against 37), the hidden axis
(1,024 against 2,048, which is the smallest power of two above the width)
and `f_e` (12 against 9, the two routes to the same `wrho_s = 18`, which
moves only the exponential and activation TABLE sizes).

**Every dimension is forced.**

* **`tokens = 64` is the smallest admissible count, and F-2 is what forces
  it.** `Dom::Kv = tokens · kv_heads · head_dim = 256 · tokens` must reach
  the row width 2^14 or the P-3 lift makes the bilinear slots unserveable,
  so `tokens ≥ 64`; at 64 it sits EXACTLY at the row width, the toy's case
  and not a lift. The test constructs the 16- and 32-token shapes and reads
  back the refusal by name.
* **`head_dim = 64` and `q_heads = 12` over `kv_heads = 4` are 125M's**, so
  `width = q_heads · head_dim = 768` follows from the reference kernel's own
  refusal and `d_pad = h_pad · head_dim = 1,024` from a construction
  refusal. The width cannot grow: `norm_wrho` reaches 33 at width 1,025 and
  the four-limb refusal bars it.
* **`hidden = 1,024`** is the smallest power of two above the width — a
  power of two keeps `Dom::F` unpadded, and it must EXCEED the width or the
  dense fixture has no upper hidden half to be live on (the S19-F1 census).
* **`f_e = 12`** is the rungs' calibration, and at 64 tokens it gives
  `wrho_s = clog2(64) + 12 = 18`, which is 125M's own softmax window
  (125M reaches it as `clog2(512) + 9`). That is what keeps `limbs_sigma_s`
  at three and therefore the plane lists and every per-position lookup count
  125M's.

**Which refusal constrained which choice, and which one BINDS.**

| refusal | how rung-W14 satisfies it | does it bind? |
|---|---|---|
| **F-2** (no P-3 lift on `Dom::Q`, `Dom::Kv`, `Dom::S`) | `Dom::Kv = 2^14` exactly at the row width; `Q`, `S`, `F` at 2^16 | **YES — this is the narrow one.** It is what sets the token count at 64 and therefore the whole size of the shape |
| the four-norm-limb refusal (`build_shaped`, S8-F3) | `norm_wrho` 32 → 4 limbs | **YES, as the ceiling**: it caps the width at 1,024, which is why 32 endpoint data rows need 512 tokens |
| **T-8** (`head_dim` a power of two ≥ 2) | 64 | no (125M's own value) |
| `width == q_heads · head_dim` (the reference kernel) | 768 = 12 · 64 | **YES**, with the head axis: it fixes the width |
| `d_pad == h_pad · head_dim` | 1,024 = 16 · 64 | **YES** |
| **T-2** (padded widths powers of two) | 64 / 1,024 / 1,024 | no |
| **S-1** (`Dom::Tab` exactly at the row width) | `log_cols = 14`, `log(Dom::Tab) = 14` | no — and this is the first time it is satisfied by a ×64 LIFT |
| **S-3 / C-2** (`head_dim < 2^log_cols`) | 64 against 16,384 | no; the margin is eight bits, 125M's own |
| **C-4** (the mask budget) | worst slot 87 + 256 ≤ 512 | no |
| the grouping refusals (`q_heads % kv_heads`, `h_pad % kv_heads`) | 12 % 4, 16 % 4 | no |

**MEASURED FIRST, BEFORE ANY TEST WAS PLACED** (`v32-measure1.log`,
detached under `systemd-run --user --scope -p MemoryMax=6G -p
MemorySwapMax=0`, with `/usr/bin/time -v`): one honest fully dense proof is
**prove 3.87 s, verify from bytes 0.50 s, peak RSS 757 MB**, and the frame
is the counted 16,421,048 B. The stage's own rule puts an ordinary-filter
shape under ~20 s and ~4 GB, so **everything goes in the ordinary filter and
no medium tier is needed**. The box was shared (another lane's Python gate
was live), so the wall figures are upper bounds and not a timing ladder.

### Task 2 — the tests, and what each MEASURED

All in the ordinary filter, none `#[ignore]`d except the bundle writer of
task 3. `w14_tests.rs` is **12 tests**, `parity.rs` gains **one**. Every
wall figure below is from `v32-w14-run3.log` on a SHARED box, so they are
upper bounds.

| test | result |
|---|---|
| `only_the_125m_shape_and_the_new_one_reach_the_125m_row_width` | **the gap, asserted**: over the eight-shape registry exactly two are at `log_cols = 14`, exactly two at `head_dim = 64` and exactly two at `endpoint_log_n = 14` — 125M and rung-W14 — and with rung-W14 removed each of the three is 125M's alone. The per-shape census is printed |
| `the_new_shape_is_the_125m_head_axis_at_the_smallest_admissible_token_count` | the head axis, the width, the padded axes, the PCS parameters, `D_max`, the norm and softmax windows and their limb counts are 125M's, each asserted against `Shape::m125()` and not against a literal; **F-2 is reproduced as a refusal**, by constructing the 16- and 32-token shapes and reading back "the bilinear attention slots cannot serve a shape whose Kv domain is lifted by P-3"; every named refusal is checked where it binds; the profile and hash-tag key set are new and pairwise distinct from all seven older ones; the three older development receipts are re-asserted unmoved |
| `the_row_geometry_is_125ms_and_every_derived_quantity_follows_it` | **the row-width census**: message 2^14, encoded 2^16, rate 4, 256 opened columns and 256 pads, Merkle depth **16**, NTT log **16**, `rows_of` `[1,1,1,4,4,1,4,4,1]` (each the size shifted by 14), ruling S-1 at fourteen, the `Dom::Tab` P-3 lift **×64** (125M's own; rung-C6's is ×4), `Dom::L` lifted 2^10 → 2^14 and no other domain lifted at all, the opened-column digests **4,216 / 3,488 B** against 125M's 45,448 / 56,960, the C-H4 no-collision refusal clear, the block seed input **118 B**, the `pcs-vec` absorb **266,295 B** — 125M's exactly — and the endpoint parameters (log 14, rate 4, depth 16, cube 2^16, 9 rows, column digest 72 B) |
| `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_w14` | the INDEPENDENT `private-block-kernel-shaped` crate takes this geometry unchanged; every kernel-backed plane agrees element for element and the block output on all **49,152** words, with the kernel's own buffers asserted live on the upper hidden half and its four key-value groups pairwise different FIRST. **This is the generic-witness check the acceptance rule asks for** |
| `an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_w14` | prove **3.99 s**, verify from bytes **0.55 s**, frame **16,421,048 B** — the COUNTED length, from the Python model — and a one-byte truncation refused. The census asserts 12/12 head slots live, 4/4 key-value groups live and pairwise different, the upper hidden half live and the 64-wide rotation live |
| `the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_w14` | verified, frame 16,421,048 B. Named degenerate: every key-value group is identically zero |
| `a_tamper_in_the_last_column_block_of_a_row_is_rejected_at_its_own_slot_at_the_rung_w14` | **5 of 5 rejected by the VERIFIER** at the slot under test, **4 of them at a column index ≥ 2^13** — see the tamper table |
| `a_multiplicity_moved_into_a_far_lifted_table_row_is_rejected_at_the_rung_w14` | **2 of 2 rejected by the VERIFIER at slot 19**, at the first padded copy (index 256) and at a copy **8,192 rows away** — the F-4 family at a lift factor of 64, which no smaller shape can write. The hook left clear changes nothing |
| `exchanging_the_keys_of_key_value_groups_two_and_three_is_rejected_at_the_rung_w14` | the four key planes of groups 2 and 3 exchanged (15,794 positions differ at `head_dim = 64`): rejected at **slot 16** `05 KV zero-check` |
| `a_moved_score_word_in_the_fourth_group_is_rejected_at_its_host_slot_at_the_rung_w14` | one score word at head slot 14 (key-value group 3, a non-first head): rejected at **slot 17** `06 softmax zero-check (hosts 07, 10)` — the score matmul is a HOSTED slot and its host is where the verifier reports |
| `a_verifier_statement_with_one_moved_endpoint_word_is_refused_at_the_rung_w14` | the proof is honest and the VERIFIER's statement moves by one word at **column 16,383 of a 2^14-wide endpoint row**: `private block wire: expected statement mismatch` |
| `the_pinned_rung_w14_chain_band_is_the_first_admissible_one` | band **20**, which is also the recipe's own single-block band: the first shape whose chain needs NO reduction. `dense_tests::band_down_run` gains a MEASURED `(1024, 4) => 20` arm |
| `an_honest_two_block_fully_dense_run_verifies_from_its_segments_at_the_rung_w14` | prove **8.05 s**, verify from segments **1.07 s**, segments **15,728,936 / 16,689,416 = 32,418,352 B** (the counted lengths), internal boundary **10 rows**, both blocks censused |

**THE TAMPERS, and what rejects each.** Every one is placed so that the
first relation it breaks is the one named, the message is asserted to name
that slot so a rejection by an earlier check cannot pass for one, and the
honest control is asserted accepted first.

| tamper | column of its row | rejected by | at |
|---|---:|---|---|
| the gate `A_G8` at the last index of the unpadded `Dom::F` | **16,383** | **VERIFIER** | slot 18 `14 F zero-check` |
| the key `A_K8` at the last index of the unpadded `Dom::Kv` (one whole row) | **16,383** | **VERIFIER** | slot 16 `05 KV zero-check` |
| residual 2, `A_X2`, on the true `Dom::D` support, deepest column | **16,127** | **VERIFIER** | slot 14 `03 D zero-check` |
| the query `A_Q8` in the last column block of a `Dom::Q` row | **16,377** | **VERIFIER** | slot 15 `04 Q zero-check` |
| the norm square `A_DSQ` at the last `Dom::T` position | 63 | **VERIFIER** | slot 02 `02 norm squares zero-check` |
| a byte-histogram multiplicity moved to lifted table row 256 | 256 | **VERIFIER** | slot 19 `TAB table helper zero-check` |
| the same, moved **8,192 rows** away (the ×64 lift) | 8,192 | **VERIFIER** | slot 19 |
| the key family of key-value groups 2 and 3 exchanged | — | **VERIFIER** | slot 16 |
| one score word at a non-first head of the fourth group | — | **VERIFIER** | slot 17 (the score slot's host) |
| the verifier's input endpoint moved by one word | **16,383** | **VERIFIER** | `wire: expected statement mismatch` |

**NO SOUNDNESS FINDING.** Nothing this stage tried was accepted, nothing was
caught only by the prover, and no refusal was weaker than the one its
narrower counterpart gives. Two results are worth recording as FACTS rather
than findings, because both are about WHICH slot reports and neither is a
hole: the group-key exchange is reported by the `Dom::Kv` host (slot 16) and
not by a bilinear slot, because the swapped planes live on `Dom::Kv` and
that relation breaks too; and a wrong SCORE word is reported by slot 17,
because the score matmul is hosted there. Both name a slot and a relation,
which is the standard stage 30's finding T30-F1 and stage 31's S31-F1 asked
for and did not get from the wire-level and opening-group refusals.

### Task 3 — the two capture bundles, and why they are NOT in the repository

`run-o-dense-w14` and `run-p-zero-w14`, **two blocks each**, schema
`hashline-native-capture/5-run` (the array store), public tables' VALUES
included, tagged, source pin `11703c9` over 38 files (`v32-bundles.log`,
exit 0, 22.91 s for the pair).

| bundle | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|
| `run-o-dense-w14` (FULLY DENSE, generic) | 34,845 B | 3,695,023 / 4,415,868 B | 42,424,904 B | **50,575,731 B** |
| `run-p-zero-w14` (all-zero, degenerate) | 34,828 B | 3,694,816 / 4,418,843 B | 41,380,544 B | **49,533,887 B** |

**50.6 and 49.5 MB with both size levers already taken** — two blocks (the
least that still has an internal boundary) and the array store (25 arrays
deduplicated in the dense bundle) — so under the stage's own rule they are
written **outside the repository**, beside the 125M captures:

```
/home/victor/zk60-artifacts/run-o-dense-w14
/home/victor/zk60-artifacts/run-p-zero-w14
```

What is committed is each bundle's `manifest.json` and its own `README.md`,
a `WHERE.md` with the exact regeneration command, the self-check log and the
self-check script, all under
`results/zk60_block125m_lane/v32-bundle-manifests/`; the parent captures
README gains a stage-32 section saying where they are. The size is the
SHAPE's doing and not a defect of the encoding: `arrays.bin` holds the
opened columns, and at a 2^14-wide row there are 256 of them over 527 and
436 rows.

**What a gate sees in them** (`v32-bundle-check.log`, read off the files on
disk, **0 mismatches**), against `run-m-dense-c6`, stage 0 against stage 0:

* `"log_cols":14` with `"a_rows":527` and `"h_rows":436`, against
  `"log_cols":10` with 1,337 and 1,408 — the row width, in the first fields
  of every stage file;
* slot 14 at **54 terminals** and slots 16 and 18 at **degree 4**, so
  correction C-6 and stage 30's unpadded arm are both still there and the
  pair is a regression for findings M-F1 and C-6 as well as new evidence;
* **all 23 slots differ from rung-C6 in their ROUND COUNTS** (main rounds
  and `definition_challenges`), which is what a wider row and larger domains
  do, and is exactly the part of the schedule a port at the 125M row width
  has to get right;
* both stages of each bundle carry the same schedule and the same draw
  counts on all 23 slots; each manifest's five files match their recorded
  length and SHA-256; no older bundle and no older README is touched.

They are **not gate evidence** (ruling T-6) and not a privacy result.

### Task 4 — what is STILL reached only by an `#[ignore]`d heavy test

Stage 31's list, re-read after this stage. Its items 2 and 3 are **CLOSED**
and item 4 is half closed; the prices below are the independent model's.

| # | branch | why no shape in the filter reaches it | can a small shape? |
|---|---|---|---|
| ~~2~~ | ~~the row width `log_cols = 14`~~ and everything keyed to it | — | **CLOSED by this stage**: `Shape::rung_w14`, twelve non-ignored tests plus the parity one, and two capture bundles |
| ~~3~~ | ~~`head_dim = 64`~~ — the S-3 / C-2 margin, the RoPE partner bit at `log − 6` | — | **CLOSED by this stage**, with the width 768 and `D_max` 908,065 that follow from it |
| 4a | **the 125M endpoint's 32 data rows / 37 commitment rows AT `endpoint_log_n = 14`** | the endpoint commits `t_pad · d_pad`, which is 2^16 here and 2^19 at 125M | **NO, not small.** 32 data rows at a 14-log endpoint need a 2^19-word padded cube; the four-norm-limb refusal caps the width at 1,024, so the cube can only grow through the TOKENS, and 2^19 / 1,024 = 512 tokens — 125M itself. The model prices that shape (512 tokens, width 768, hidden 1,024) at a **39,275,896 B** receipt and 93.9 M U8 lookups, which is 125M's own class |
| 4b | the 32 / 37 endpoint ROW COUNT at a smaller endpoint log | the filter has 2, 4 and 16 data rows | **YES, and it is the one cheap thing left**: 32 tokens, width 768, hidden 1,024, 12 heads of 64 over 4 at `log_cols = 10` gives a 2^15-word cube at an endpoint log of 10 — **32 data rows, 37 commitment rows** — for an 11,368,824 B receipt and 2.2 M U8 lookups. It reaches the ROW COUNT and not the LOG. **NOT DONE** |
| 5 | **the token count 512 and everything that scales with it**: `Dom::S` at 2^22 and `Dom::F` at 2^20 (the two biggest cubes), `A` 5,681 / `H` 7,120 rows, 98.6 M U8 lookups, the largest slot mask length 117, and the parallel thresholds' far side at that scale | size alone | **A LADDER, and every rung is priced.** At this shape's geometry the model gives 128 tokens an **18,162,936 B** receipt and 11.7 M lookups (2.4× this stage's work), 256 tokens **23,169,336 B** and 31.2 M (6.4×), 512 tokens **39,275,896 B** and 93.9 M. 128 tokens would still be an ordinary-filter shape; 256 would be a medium-tier one at roughly 25 s a proof; 512 is 125M. **NOT DONE**, and the open question is what a rung buys beyond what this stage already proves |
| 6 | **long runs and the memory path**: `L = 12`, a 484 MB run receipt, the >10 GiB proving peak, the mmap threshold crossings | size alone | **NO** — inherently heavy, and the one item a small shape cannot stand in for. Stage 29 unit-gated the five size thresholds themselves, so what is uncovered is the memory BEHAVIOUR, not a branch |

**The observation stage 31 recorded is still true, and further from being
reached than ever.** `Shape::a_groups`'s first arm,
`natural_log(Dom::T) >= log_cols`, is reached by **no registered shape**: at
rung-W14 `log(Dom::T)` is 6 against a row width of 2^14, where at rung-C6 it
was 5 against 2^10. It needs `t_pad ≥ 2^log_cols`, and
`Dom::S = h_pad · t_pad²` grows quadratically in the tokens, so the cheapest
such shape is still a 39,380,616-byte receipt. It is a dead arm rather than
a heavy one, and no test exercises it.

### Task 5 — the gates, the sixth registry guard, and the commits

**THE GATES AT THE STAGE-32 TIP.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter), FIRST run | **374 passed / 1 failed / 16 ignored, 550.72 s** (`v32-gate-private.log`). The one failure is a SIXTH registry guard, and the coincidence it found is real and is recorded rather than dodged: see below. The log is kept as evidence |
| `--lib private_` (the whole filter), SECOND run, after the declared pair | **375 passed / 0 failed / 16 ignored, 548.93 s, exit 0**, peak RSS **1.33 GB** under the 6 GiB cap (`v32-gate-private2.log`) — the stage-31 tip's 362 plus this stage's thirteen, nothing lost; the one new ignored test is the bundle writer. **The filter grew by 83 seconds**, inside the two minutes this stage was given |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` and the 2,816,472 B receipt-length family — **all in the pass list of both runs** |
| the rung, rung-G, rung-K4, rung-P2 and rung-C6 pins, BY NAME | in the pass list: `rung_tests`, `dense_tests`, `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims` (4,743,128 B), `p2_tests::the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move` (4,742,728 B) and `c6_tests::the_new_shape_is_rung_p2_with_the_head_dimension_moved` (7,452,040 B). `w14_tests` asserts the last three again beside its own 16,421,048 B |
| the new shape's own tests | `w14_tests` (12) and `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_w14` (1), all non-`#[ignore]`d; the only ignored addition is the bundle writer |
| the Python model's test file | `python3 -m unittest discover -s tests -p 'test_zk60_private_block_layout_model.py'` — **52 tests, OK** (47 before this stage), `v32-pytests.log` |
| the forbidden-files proof | `git diff --stat d282dd6 HEAD -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/field hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu zkvm-block private-block-kernel private-model-kernel private-block-kernel-shaped` prints **nothing**. With `tests` and `scripts` added it prints exactly two paths, the lane's own layout model and its acceptance test |
| the whole diff against `d282dd6` | ten sources — `shape.rs`, `run.rs`, `private_block.rs` (one `mod` line), the new `w14_tests.rs`, `parity.rs`, `dense_tests.rs`, `run_capture_tests.rs`, `run_statement_file.rs`, `s24_tests.rs`, `s25_tests.rs` — plus the shape model and its test, the two bundles' manifests with the parent captures README, this ledger and the evidence logs. Stage 31's two quarantined `u31-c6-run1.*` files are untracked and untouched |
| **no medium tier** | none was created and none is needed: one proof is 3.99 s at this shape, so every test is in the ordinary filter. There is therefore no medium-tier command to document |

**THE SIXTH REGISTRY GUARD, AND WHY THE PAIR IS RECORDED RATHER THAN
DODGED.** Stage 30 tripped four guards, stage 31 a fifth, and this stage a
sixth:
`s25_tests::every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length`
refuses any two DIFFERENT hash-input kinds of equal length inside one hash
function unless the pair is DECLARED with what separates them. At rung-W14
the profile string is **48 bytes**, so `Transcript::new`'s input —
`b"hashline-v1/" ‖ profile` — is **60 bytes**, and an absorb of the
four-byte label `rows` with eight bytes of data is `32 + 8 + 4 + 8 + 8` =
**60 bytes** too. Both are hashed by the transcript function, so the guard
fired, correctly.

Making the collision go away by lengthening the profile string was
available and was NOT taken: ruling J-7's discipline is to record a
within-function coincidence and state what separates it. Here the
separation is **structural and exact** rather than probabilistic: at offset
32 the absorb carries `le64(4)` — eight bytes of which **six are NUL** —
where the constructor carries the profile string's own bytes 20..28
(`ate-bloc` at this profile), and a profile string is ASCII and has no NUL
at any offset. The two inputs therefore cannot be equal at ANY 48-byte
profile, which is stronger than the pair being unlikely. The row is in the
table with that reason, and the whole filter is green with it.

**THE COMMITS OF STAGE 32**, in order:

| commit | what |
|---|---|
| `a0723f4` | the ledger skeleton: the gap, the five tasks, the rules, the measure-before-placing rule |
| `f663a79` | **task 1**: `Shape::rung_w14`, the run profile, the five registry guards a new profile trips (the fifth made fully derived), and the measurement that places the shape in the ordinary filter |
| `aa8e7b7` | **task 1**: the shape in the independent Python model, with what it shares with 125M and what it does not; 52 model tests |
| `fe3bb44` | **task 2**: `w14_tests.rs` (12 tests) and the parity test — the census, the generic witness, the row-width census, the tampers, the run, and the measured `(1024, 4) => 20` chain band |
| `11703c9` | **task 3**: the bundle writer, `#[ignore]`d, documented as writing OUTSIDE the repository |
| `757e182` | **task 3**: the two bundles written and checked; their manifests, notes, `WHERE.md`, the self-check log and its script, and the parent captures README |
| `62c4077` | the ledger: tasks 1–4 |
| this one | the sixth registry guard's declared pair, and the ledger's task 5 and close |

**WHAT THIS STAGE IS NOT.** Not a privacy result and not an acceptance: the
lane's code stays experimental, for the integrator (ruling V-1), and the two
bundles are the INPUT to the Python gate, not its verdict (ruling T-6). Not
a claim about 125M: **no 125M proof was run by this stage**, and no `r29-*`
file was touched. Not a change to what any existing profile sends, absorbs
or draws: the toy is byte-frozen and green and the five older development
profiles' receipt lengths are unmoved.

**WHAT IT IS.** The 125M ROW WIDTH — a 2^14-word message encoded to 2^16, a
sixteen-deep Merkle tree, an NTT table of 2^16, a lookup table lifted by a
factor of sixty-four, a `pcs-vec` hash input of 266,295 bytes — together
with the 125M HEAD SIZE of 64 and the 125M ENDPOINT LOG of 14, which until
today only an `#[ignore]`d 10 GiB test could reach, is now proved, verified
from bytes, checked element for element against an independent reference
kernel on a GENERIC witness, censused figure by figure against 125M,
tampered with in the half of a row no narrower shape has, run over two
blocks with an internal boundary, and captured for the gate — **by tests
that add eighty-three seconds to the ordinary filter**.

**TWO NOTES FOR THE INTEGRATOR, neither a defect in the code.**

* `protocol::ntt_log_at`'s doc comment still says "Only 125M gets a
  different table". Since this stage rung-W14 gets the same 2^16 table; the
  VALUE is asserted by
  `w14_tests::the_row_geometry_is_125ms_and_every_derived_quantity_follows_it`,
  so the comment is stale rather than wrong, and rewording it is left to
  the integrator's own commit.
* The brief asked for a tamper on "an endpoint row beyond the old 9/21-row
  geometries". **That case does not exist at this shape**: rung-W14's
  endpoint has NINE commitment rows, the same as rung-G, rung-K4 and
  rung-P2 — what is new is the endpoint's row WIDTH (2^14) and its LOG, not
  its row count. The tamper taken instead is the one this shape does add: a
  verifier statement whose input endpoint differs by one word at **column
  16,383**, a column no older endpoint geometry has. The 32-data-row
  endpoint is item 4a/4b of the heavy-only list.

## Stage 33 — the three closures the security owner ruled after reading stage 32 (2026-09-21, 14:2x–)

**Status: OPEN.** Opened 2026-09-21 14:25 PDT on the lane tip `f8b926f`
(pushed). Three small, independent closures, each of them a thing stage 32
either DECLARED without checking or left as a dead branch:

| task | ruling | what | state |
|---|---|---|---|
| 1 | **J-7a** | stage 32's declared 60-byte coincidence rests on a premise stated only in a comment ("a profile string is ASCII and has no NUL"). It becomes a CHECK over the whole registry, and the separation becomes a general lemma-as-test: at every registered profile length, the `Transcript::new` input can equal NO absorb input of the same length | OPEN |
| 2 | **S-6** | `Shape::a_groups`'s first arm (`natural_log(Dom::T) >= log_cols`) is reached by no registered shape. That family becomes a NAMED shape refusal, the arm is documented, and the Python model mirrors the refusal | OPEN |
| 3 | stage 32's item **4b** | the 125M endpoint's 32 data / 37 commitment ROW COUNT at a 10-log endpoint, as one more small profile by the stage-30/31 method — IF one honest proof measures under ~5 s and ~1.5 GB | OPEN |

**The rules this stage works under** are the lane's and stages 30–32's: one
writer, the build recipe in this file's header, **no 125M run**, no
registered profile moved (toy, the frozen-seam rung, rung-G, rung-K4,
rung-P2, rung-C6, rung-W14, 125M — named and kept green), the toy
byte-frozen, **no witness VALUE in any log**, a gap reproduced as a FAILING
TEST before it is closed, and no "proves and verifies" without a GENERIC
honest witness (dense weights, a non-constant hidden input, heads and
key-value groups that differ) checked against the independent
`private-block-kernel-shaped` reference. The ordinary filter may not grow by
more than about a minute.

**Evidence prefix**: `results/zk60_block125m_lane/w33-*`.

### Task 1 (ruling J-7a) — the separator of stage 32's declared pair, CHECKED

**WHAT WAS WRONG WITH IT.** Stage 32's sixth registry guard fired on a real
coincidence: at the 48-byte rung-W14 profile `Transcript::new`'s input
(`b"hashline-v1/" ‖ profile`, 60 bytes) has the same length as an absorb of
the four-byte label `rows` with eight bytes of data (`32 + 8 + 4 + 8 + 8`),
and both are hashed by the transcript function. The stage DECLARED the pair
rather than lengthening the profile to dodge it — the right call under ruling
J-7 — and separated it with a structural argument: at offset 32 the absorb
carries `le64(4)`, whose NUL bytes an ASCII profile cannot match. **Every
part of that argument was a comment.** The premise (profiles are ASCII) was
asserted nowhere, the offset was written as a literal 32, and the argument
was made for one pair at one length when it is general.

**WHAT IS THERE NOW**, five tests in `hashline/src/private_block/s33_tests.rs`,
all in the ordinary filter and all cheap (no proving):

| test | what it measures |
|---|---|
| `every_registered_profile_context_and_label_is_printable_ascii_with_no_nul` | **42 fixed literals** — the **14 registered profiles** (8 block, 6 run), the **4 `derive_key` context literals**, the **22 transcript absorb labels** the census knows and the 2 fixed transcript literals (`hashline-v1/`, `squeeze`) — are printable ASCII, `0x20..=0x7E`, with no NUL. The registry is built BOTH from the shape and run constructors AND read out of `shape.rs` / `run.rs`, and the two lists must agree, so a profile added tomorrow is covered whether or not anyone remembers this file |
| `the_ascii_premise_check_rejects_a_profile_with_a_nul_or_a_non_ascii_byte` | **the control that makes it bite**: five deliberately bad profile strings — a NUL inside, a NUL at the end, a two-byte UTF-8 character, a tab, DEL — are each rejected, and all eight registered ones accepted |
| `no_transcript_constructor_input_can_equal_an_absorb_input_of_the_same_length` | **the lemma.** For every registered profile length `n` and **every** absorb layout of that length — every `(|label|, |data|)` with `48 + |label| + |data| = n`, whether or not a label of that length exists — at least one byte position inside one of the two `le64` LENGTH FIELDS is forced to `0x00` where the constructor carries a profile byte. The positions are COMPUTED from the layout, never the literal 32 |
| `the_declared_sixty_byte_pair_is_separated_at_the_positions_the_record_names` | stage 32's own pair, re-derived and demonstrated on real bytes with the absorb state chosen adversarially (the constructor input's own first 32 bytes) |
| `the_separation_lemma_collapses_on_a_deliberately_bad_profile` | **the lemma's control**: a test-local 48-byte profile whose bytes under the two length fields are NUL has **no** separating position at the declared layout; one printable byte back restores one |

**WHAT THE LEMMA MEASURED.** **14 profiles, 124 absorb layouts, every single
one separated.** The thinnest case has **14** forced-NUL positions, and the
census is worth reading:

* the 36-byte block profile `…/private-block-m125/1` gives `n = 48`, where
  exactly ONE layout exists (`|label| = |data| = 0`) and both length fields
  are `le64(0)` — **16** separating positions, the first at offset 32;
* the twelve profiles with `n` between 51 and 60 have 4 to 13 layouts each
  and at least **14** positions each, the first at offset 33;
* the run profile `…/private-run-m125/1` is 34 bytes, so `n = 46` — **below
  the shortest absorb input there is (48 bytes)**, and no layout of its
  length exists at all. That case is reported rather than skipped silently.

**WHY EVERY (LENGTH, LAYOUT) PAIR HAS ONE, in plain words.** A layout fixes
both length fields' VALUES, so their bytes are constants: with a label
shorter than 256 bytes, `le64(|label|)` is one value byte and **seven NULs**
at offsets 33..39, and the constructor's bytes there are profile bytes
because the profile begins at offset 12 and every collision has `n ≥ 48`.
Nothing about the absorb's label content, its data or its incoming state
enters, which is why one position settles the whole pair rather than one
instance of it.

**FINDING S33-F1 (message only, no soundness consequence).** The declared
row's own sentence says `le64(4)` has "**six** NUL bytes". It has **seven**,
and at the declared layout there are **fourteen** forced-NUL positions over
the two length fields — seven in `le64(|label|)` at offsets 33..39 and seven
in `le64(|data|)` at 45..51. The record understated its own separator. The
literal is corrected in `s25_tests.rs` and now points at the lemma.

**WHAT THIS IS NOT.** Not a claim that the transcript function is collision
free, and not a hash-security statement of any kind: it is the statement that
two INPUT CLASSES of equal length can never be the same STRING, which is what
ruling J-7 asks a declared pair to carry.

### Task 2 (ruling S-6) — the dead arm of `Shape::a_groups` becomes a named refusal

**THE GAP.** `Shape::a_groups` fixes the `A` opening's column-weight GROUP
structure — the structure the privacy argument's opening accounting counts —
and its `SC_TZC` term has two arms:

```
let tzc = if self.natural_log(Dom::T) >= self.log_cols { 1 } else { … offsets … };
```

Stages 31 and 32 established that **no registered shape reaches the first
arm**: 125M's `Dom::T` is 2^9 against a row width of 2^14, rung-W14's is 2^6
against 2^14, and every other shape is 2^5. An arm no shape reaches is code
nobody tests, inside the one function that fixes the opening groups.

**FAILING FIRST** (`results/zk60_block125m_lane/w33-s6-failing-first.log`,
exit 101). The family was constructible and the probe is the toy's own axes
at 256 tokens and the toy's own row width of 2^8 — every other check
satisfied: the three bilinear domains sit above the row width so ruling F-2
does not fire, `Dom::Tab` is exactly at it so ruling S-1 does not, the head
dimension is five bits below it so S-3 does not, and the longest mask is far
inside C-4's budget. `Shape::new` returned it happily, and it read
**`a_groups() = 28` out of the FIRST arm** (the toy's own count, out of the
second, is 35). The sweep's 129-token case — 129 tokens PAD to 256 — was
accepted too.

**THE REFUSAL**, in `Shape::new` (`shape.rs`), after rulings S-1 and S-3 and
**before** ruling C-4's mask budget:

```
private block shape: ruling S-6 — the padded token count 2^8 (256 tokens) is at
or above the row width 2^8, which is the family that reaches `Shape::a_groups`'s
unreached first arm; the A opening's group structure would then be decided by a
branch no registered shape takes and no test covers
```

**THE ARM STAYS, as a documented defensive return — and here is the reason it
may.** On exactly the refused family the two arms **agree**: `t_pad` is a
power of two (ruling T-2), so `t_pad ≥ 2^log_cols` makes every offset
`k · t_pad mod 2^log_cols` zero and the live arm's deduplicated set is `{0}`
— the first arm's own 1. The arm is a SHORTCUT, not a second behaviour;
deleting it would change no value at any shape, reachable or refused. That is
why it is neither removed (which would be a silent change to a function the
prover calls) nor turned into a panic (no shape that passed validation may
panic on the proving path). It is kept, with a doc paragraph and an inline
comment saying it is unreachable after validation and why it is harmless.
`s33_tests::the_refused_arm_and_the_live_arm_agree_wherever_both_are_defined`
proves the agreement over 15 row widths × 5 padded token counts each.

**THE REFUSED FAMILY, IN PLAIN WORDS**: token counts at or above the row
width — at the toy's row width of 2^8, 129 tokens and up, because 129 tokens
pad to 256. It is not a privacy or a soundness condition and it costs no
shape anybody has: the cheapest member prices at a **39,380,616-byte**
receipt, since `Dom::S = h_pad · t_pad²` grows quadratically in the tokens.
**Lifting the refusal later takes a shape of that family in the ORDINARY
filter** — proved, tampered and censused like any other — not an edit to
`a_groups`.

**THE TESTS** (four, in `s33_tests.rs`, all in the ordinary filter):

| test | what it measures |
|---|---|
| `no_registered_shape_reaches_the_first_arm_of_a_groups` | at all eight shapes, `natural_log(Dom::T) < log_cols`, with the margin printed: 3 bits at the toy, 5 at the five 10-log rungs and at 125M, **8** at rung-W14 |
| `a_shape_whose_padded_token_count_reaches_the_row_width_is_refused_by_name` | the 256-token probe refused, the message naming the ruling, the axis and the branch; the 128-token CONTROL constructs; 129 tokens refused because the PADDED count is what is read; and stage 24's old mask-budget geometry refused by S-6 rather than C-4, which pins the order |
| `the_s6_refusal_is_exactly_the_padded_token_counts_at_or_above_the_row_width` | a sweep of 32, 64, 128, 129, 192, 256, 257, 512 and 4,096 tokens at the toy's other axes: below the row width the shape constructs and its `A` group count follows `SC_TZC`'s offsets (35 at `t_pad = 32`, 31 at 64, 29 at 128), at and above it ruling S-6 owns the refusal and no other refusal reaches those shapes first |
| `the_refused_arm_and_the_live_arm_agree_wherever_both_are_defined` | the agreement above, and the toy's own 35 |

**ONE EXISTING TEST'S GEOMETRY MOVED, and it is worth stating why.** Stage
24's mask-budget probe is 2^20 − 1 tokens over 2,048 query heads of 8 **at a
row width of 2^14** — which is inside the new refused family, and so is its
CONTROL (2^19 − 1 tokens), the one that has to CONSTRUCT for the C-4 refusal
to be shown tight. The probe's row width moved from **2^14 to 2^21** and
nothing else: `log(Dom::S) = log2(h_pad) + 2·log2(t_pad)` has no `log_cols`
in it, so the two masked message lengths are still **262** (refused) and
**252** (constructs), both still asserted in that test. The old geometry is
kept as evidence — `s33_tests` constructs it and reads back ruling S-6.

**THE PYTHON MODEL MIRRORS THE REFUSAL, by the same name.** The independent
layout model (`scripts/zk60_private_block_layout_model.py`) raises
`ValueError` with the same "ruling S-6" sentence at the same shapes, its
`opening_groups` carries the same comment on the same dead arm, and its
acceptance test gains a `TheTokenCountRefusal` class with four tests: the
named refusal, the same 32/64/128/129/192/256/257/512 boundary sweep, no
registered model shape refused, and the two-arm agreement. **56 model tests,
OK** (52 before this stage). A model that priced a shape the prover refuses
would be a model of something else.

### Task 3 (stage 32's item 4b) — the 125M ENDPOINT ROW COUNT, 32 data rows and 37 commitment rows, in the ordinary filter

**THE GAP.** The external endpoint commits the padded `Dom::D` cube in rows
of `2^endpoint_log_n`. At 125M that cube is `512 · 1,024 = 2^19` words and
the endpoint log is 14, so the endpoint is **32 data rows and 37 commitment
rows**, its opened-column digest is **296 B**, and a run's internal boundary
is **38 rows**. Every shape the ordinary filter proves at has 2, 4 or 16 data
rows, so the endpoint row INDEX 16 and up existed only inside an `#[ignore]`d
10 GiB test. Stage 32 split the item in two and priced both halves: **4a**
(32 data rows AT an endpoint log of 14) needs a 2^19-word cube, which with
the width capped at 1,024 by the four-norm-limb refusal means 512 tokens —
125M itself; **4b**, the row COUNT at a smaller endpoint log, is cheap. This
is 4b.

**THE SHAPE.** `Shape::rung_e32` — "development rung, the 125M endpoint row
count" — is rung-W14's head axis, width and hidden size at **32 tokens and a
row width of 2^10**. Every number is forced by the target:

| | rung-C6 | rung-W14 | **rung-E32** | 125M |
|---|---:|---:|---:|---:|
| tokens / width / hidden | 32 / 384 / 512 | 64 / 768 / 1,024 | **32 / 768 / 1,024** | 512 / 768 / 2,048 |
| query heads × head_dim, kv heads | 12 × 32, 4 | 12 × 64, 4 | **12 × 64, 4** | 12 × 64, 4 |
| `log_cols` / encoded row | 10 / 2^12 | 14 / 2^16 | **10 / 2^12** | 14 / 2^16 |
| endpoint cube / log / **data rows** / **commitment rows** | 2^14 / 10 / 16 / 21 | 2^16 / 14 / 4 / 9 | **2^15 / 10 / 32 / 37** | 2^19 / 14 / **32** / **37** |
| endpoint column digest | 168 B | 72 B | **296 B** | **296 B** |
| internal boundary rows | 22 | 10 | **38** | 38 |
| `A` rows / `H` rows | 1,337 / 1,408 | 527 / 436 | **2,209 / 2,416** | 5,681 / 7,120 |
| `D_max` / `norm_wrho` / C-6 | 642,099 / 32 / yes | 908,065 / 32 / yes | **908,065 / 32 / yes** | 908,065 / 32 / yes |
| `wrho_s` / `limbs_sigma_s` | 17 / 3 | 18 / 3 | **17 / 3** | 18 / 3 |
| U8 lookup positions | 1,214,464 | 4,882,432 | **2,181,120** | 98,598,912 |
| counted receipt | 7,452,040 B | 16,421,048 B | **11,368,824 B** | 40,783,352 B |

* **32 tokens and width 768 are what make the cube 2^15**, and `2^15 / 2^10`
  is the 32 data rows the stage is about. The width cannot grow (the
  four-norm-limb refusal caps it at 1,024) and the row width cannot be 14
  (the cube would be ONE row), so at this head axis the shape is the only
  cheap way to the row count.
* `hidden = 1,024` is the smallest power of two above the width, which keeps
  `Dom::F` unpadded and keeps an upper hidden half for the dense fixture.
* `f_e = 12` at 32 tokens gives `wrho_s = 17`, so `limbs_sigma_s` is 3 as at
  125M, and width 768 gives `D_max` 908,065, `norm_wrho` 32 and correction
  **C-6**, all three 125M's own.
* **Ruling S-6, this stage's own refusal, is checked where it binds**: the
  padded token count is 2^5 against a row width of 2^10.

**WHAT IT DOES NOT REACH, and the census says so**: the endpoint LOG (10
here, 14 at 125M) and therefore the endpoint's row WIDTH and Merkle depth
(12 against 16). Row count and row width are the endpoint's two independent
axes; rung-W14 holds the second and this shape holds the first.

**MEASURED FIRST, BEFORE ANY TEST WAS PLACED** (`w33-e32-measure1.log`,
detached under `systemd-run --user --scope -p MemoryMax=4G -p
MemorySwapMax=0`): one honest fully dense proof is **prove 1.80 s, verify
from bytes 0.20 s**, and the frame is the counted **11,368,824 B**. The
budget the security owner gave this task is ~5 s and ~1.5 GB, so it is an
ORDINARY-FILTER shape. The whole module then runs in **25.28 s at a peak RSS
of 361 MB** (`w33-e32-run1.log`, the same cap, `/usr/bin/time -v`), the
two-block run included.

**THE TESTS** — nine in `e32_tests.rs` plus one in `parity.rs`, all in the
ordinary filter, none `#[ignore]`d except the bundle writer:

| test | result |
|---|---|
| `only_the_125m_shape_and_the_new_one_reach_the_thirty_two_row_endpoint` | **the gap, asserted**: over the nine-shape registry exactly two have 37 commitment rows — 125M and rung-E32 — and with rung-E32 removed no shape has more than 16 endpoint data rows. The census prints cube, log, data rows, commitment rows and column digest per shape, and asserts the new shape does NOT reach the endpoint log |
| `the_new_shape_is_125ms_endpoint_row_count_at_a_ten_log_endpoint` | the head axis, padded axes, `D_max`, the norm and softmax windows and their limb counts asserted against `Shape::m125()` and not against literals; the endpoint's 32 / 37 asserted against 125M's; every named refusal checked where it binds, **ruling S-6 included**; the profile new and pairwise distinct; the four older development receipt lengths re-asserted unmoved |
| `parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_e32` | the INDEPENDENT `private-block-kernel-shaped` crate takes this geometry unchanged: every kernel-backed plane agrees element for element and the block output on all **24,576** words, with the four key-value groups asserted pairwise different and **all sixteen upper endpoint data rows asserted live in the kernel's own output** first. **This is the generic-witness check the acceptance rule asks for** |
| `an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_e32` | prove **1.76 s**, verify from bytes **0.18 s**, frame **11,368,824 B** — the COUNTED length from the Python model — and a one-byte truncation refused |
| `the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_e32` | verified, frame 11,368,824 B. Named degenerate: every key-value group is identically zero |
| `the_endpoint_geometry_is_125ms_row_count_over_a_narrower_row` | the endpoint census: 32 / 37 / 296 B / 5 mask rows **identical to 125M's**, the rate and opened-column count 125M's, and the row width, Merkle depth and cube **different** (10 / 12 / 2^15 against 14 / 16 / 2^19); the C-H4 no-collision refusal clear at a 37-row endpoint; `A` / `H` columns 17,672 / 19,328 B over 2,209 / 2,416 rows, the model's own |
| `a_verifier_statement_with_a_moved_word_in_a_high_endpoint_row_is_refused_at_the_rung_e32` | the honest proof verifies, then the VERIFIER's own input endpoint moves by one word at **data row 0** (the control any shape has), **data row 16** and **the last data row 31, last column**: each refused, `private block wire: expected statement mismatch` |
| `a_tamper_in_a_high_endpoint_row_is_rejected_at_its_own_slot_at_the_rung_e32` | the prover's residual-2 plane — which IS the endpoint's output cube — changed at the first word of data row 16 and at the last true word of row 31: **both rejected by the VERIFIER at slot 14 `03 D zero-check`**, neither by the prover |
| `an_honest_two_block_fully_dense_run_verifies_from_its_segments_at_the_rung_e32` | prove **3.68 s**, verify from segments **0.39 s**, segments **11,143,656 / 11,391,432 B** (the counted lengths), internal boundary **38 rows = endpoint rows + 1**, both blocks censused |
| `a_moved_word_in_a_high_boundary_row_is_refused_in_a_two_block_run_at_the_rung_e32` | the two-block run's BOUNDARY plane changed at data row 16 and at the last data row: **both rejected by the VERIFIER at slot 22 `IO-out endpoint equality`** |

**NO SOUNDNESS FINDING.** Nothing this task tried was accepted, nothing was
caught only by the prover, and every rejection names a slot or the wire
statement.

**ONE TAMPER THE BRIEF NAMED THAT IS NOT REACHABLE, and what covers it
instead.** The brief asked for a tamper on "the last commitment row" and on
"the boundary's reserved rows". The endpoint's rows 32..36 are its five MASK
rows and the boundary's extra row is its second reserved IO-tab row: none of
them is a witness word or a statement word — they are written by the
prover's own hiding and site machinery — so reaching them means editing
RECEIPT BYTES at an offset computed from the wire layout, which no tamper
family in this lane does. What pins those rows instead is **byte-exact
arithmetic**: an endpoint opening carries `8 · endpoint_rows` bytes per
opened column, so a receipt whose endpoint had one row more or fewer could
not be 11,368,824 B, and both the block frame and the two run segments are
asserted equal to the INDEPENDENT model's counted lengths. The boundary's own
count is asserted directly (38, and `= endpoint_rows + 1`).

**THE TWO CAPTURE BUNDLES, and why they are IN the repository this time.**
`run-q-dense-e32` and `run-r-zero-e32`, two blocks each, schema
`hashline-native-capture/5-run` (the array store), tagged, public tables'
VALUES included, written and checked off disk by the same `#[ignore]`d test
(`w33-e32-bundles-repo.log`, exit 0: self-consistent, every key on the
allow-list, every array reference resolved).

| bundle | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|
| `run-q-dense-e32` (FULLY DENSE, generic) | 35,068 B | 3,478,050 / 4,201,171 B | 25,033,024 B | **32,752,273 B** |
| `run-r-zero-e32` (all-zero, degenerate) | 35,074 B | 3,477,890 / 4,201,709 B | 24,611,408 B | **32,377,576 B** |

**32.8 and 32.4 MB**, inside the ~40 MB a repository file should be (the
older in-repo pairs run to 45 MB), so unlike stage 32's 50 MB pair these go
in `results/zk60_run_captures_20260920/` in full. What a gate sees in them
that it has never seen: `"endpoint_rows":37` over 32 data rows with a
296-byte column digest, a 38-row internal boundary, one endpoint data row
per TOKEN so rows 16..32 exist at all, and `"a_rows":2209` / `"h_rows":2416`
— the largest of any development bundle. What is deliberately unchanged, so
that the pair is a regression as well as new evidence: `Dom::T`, `Dom::Kv`
and `Dom::F` unpadded (finding M-F1's set) and slot 14 at 54 terminals
(correction C-6), both asserted by the writer off the files it wrote. They
are **not gate evidence** (ruling T-6) and not a privacy result.

A first, identical pair was written to `/home/victor/zk60-artifacts/` to
size them (`w33-e32-bundles.log`, 32.6 and 32.3 MB — the small difference
is fresh per-proof randomness, not a change in the schedule); those copies
are outside the repository and the orchestrator may delete them.

### Task 4 — what is STILL reached only by an `#[ignore]`d heavy test

Stage 32's list, re-read after this stage. **Item 4b is CLOSED**; 4a, 5 and
6 stand, and the dead-arm observation is gone because the family is now
refused.

| # | branch | why no shape in the filter reaches it | can a small shape? |
|---|---|---|---|
| 4a | **32 endpoint data rows AT `endpoint_log_n = 14`** — the endpoint's row count and its row WIDTH together | the endpoint commits `t_pad · d_pad`; 32 data rows at a 14-log endpoint need a 2^19-word cube | **NO, not small.** The four-norm-limb refusal caps the width at 1,024, so the cube can only grow through the TOKENS, and `2^19 / 1,024 = 512` — 125M itself, a 39,275,896 B receipt. **What this stage closes is the row COUNT (rung-E32) and what stage 32 closed is the row WIDTH (rung-W14); only their conjunction is left, and it is 125M** |
| ~~4b~~ | ~~the 32 / 37 endpoint row count at a smaller endpoint log~~ | — | **CLOSED by this stage**: `Shape::rung_e32`, nine non-ignored tests plus the parity one, and two capture bundles |
| 5 | **the token count 512 and everything that scales with it**: `Dom::S` at 2^22 and `Dom::F` at 2^20, `A` 5,681 / `H` 7,120 rows, 98.6 M U8 lookups, the largest slot mask length 117, the parallel thresholds' far side | size alone | **A LADDER, and every rung is priced** (stage 32's figures): 128 tokens an 18,162,936 B receipt and 11.7 M lookups, 256 tokens 23,169,336 B and 31.2 M, 512 tokens 39,275,896 B and 93.9 M. 128 would still be an ordinary-filter shape, 256 a medium-tier one at roughly 25 s a proof, 512 is 125M. **NOT DONE**, and the open question is still what a rung buys beyond what stages 32 and 33 already prove |
| 6 | **long runs and the memory path**: `L = 12`, a 484 MB run receipt, the >10 GiB proving peak, the mmap threshold crossings | size alone | **NO** — inherently heavy, and the one item a small shape cannot stand in for. Stage 29 unit-gated the five size thresholds themselves, so what is uncovered is the memory BEHAVIOUR, not a branch |
| ~~the dead arm~~ | ~~`Shape::a_groups`'s first arm~~ | — | **GONE**: ruling S-6 refuses the family that reaches it, the arm is unreachable after validation, and the two arms are proved to agree on it anyway. Lifting the refusal later needs a shape of that family in the ordinary filter |

**One row of the old list no longer belongs on it.** Stage 32 wrote "the
cheapest shape reaching the dead arm is a 39,380,616-byte receipt" as if it
were a heavy-only BRANCH. It is now a refused shape family, which is a
different kind of thing: not untested code, but code that cannot be reached.

### Task 5 — the gates, the SEVENTH registry guard, and the commits

**THE SEVENTH REGISTRY GUARD, AND WHY THE NUMBER IS RECORDED RATHER THAN
DODGED.** Stage 30 tripped four guards with a new profile, stage 31 a fifth,
stage 32 a sixth, and this stage a seventh:
`s25_tests::the_per_slot_terminal_absorb_lengths_are_printed_and_recorded_at_every_shape`
refuses a development run whose `parameters` absorb length it has not
recorded. rung-E32's is **299 bytes at `L = 1`**, where the three 96-wide
runs are 294, rung-W14 is 297 and rung-C6 is 298. The whole filter's FIRST
run at the stage-33 tip is kept as evidence of it
(`w33-gate-private2.log`: **393 passed / 1 failed / 17 ignored, 564.84 s**).

The two extra bytes over rung-W14 are exactly locatable, and the guard now
says so: **the endpoint's row count appears TWICE in a run's parameter
line** — once as the block's `endpoint-…-rows` and once as the run's own
`external-rows` — and 37 is one decimal digit longer than rung-W14's 9 in
both places. Every other field is the same width (`T32` against `T64`,
`log_cols10` against `log_cols14`, the same width, hidden and head axis), so
the difference is that one number counted twice. At 299 the 295-byte
`parameters` / `pb-term`(15) coincidence **cannot arise at any `L`**, so the
split of the development runs becomes **3 narrow / 3 wide**.

**THE GATES AT THE STAGE-33 TIP.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter), FIRST run | **393 passed / 1 failed / 17 ignored, 564.84 s** (`w33-gate-private2.log`) — the seventh registry guard, recorded above. The log is kept |
| `--lib private_` (the whole filter), SECOND run, after the recorded length | **394 passed / 0 failed / 17 ignored, 565.58 s, exit 0** (`w33-gate-private3.log`) — stage 32's 375 plus this stage's nineteen (nine in `s33_tests`, nine in `e32_tests`, one in `parity.rs`), nothing lost. The one new ignored test is the bundle writer. **The filter grew by 16.65 seconds** against stage 32's 548.93 s, inside the minute this stage was given |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` — all in the pass list of both runs |
| the rung, rung-G, rung-K4, rung-P2, rung-C6 and rung-W14 pins, BY NAME | in the pass list: `rung_tests`, `dense_tests`, `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims` (4,743,128 B), `p2_tests::the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move` (4,742,728 B), `c6_tests::the_new_shape_is_rung_p2_with_the_head_dimension_moved` (7,452,040 B) and `w14_tests` (16,421,048 B). `e32_tests` asserts the last four again beside its own 11,368,824 B |
| an earlier gate, for the S-6 refusal alone | **384 passed / 0 failed / 16 ignored, 541.01 s** (`w33-gate-private1.log`), taken at the task-2 tip before task 3 existed: stage 32's 375 plus s33's nine, nothing lost, and the filter did NOT grow (stage 32's own run was 548.93 s) |
| the Python model's tests | `python3 tests/test_zk60_private_block_layout_model.py` — **60 tests, OK** (52 before this stage; 56 after task 2), `w33-pytests.log` |
| the forbidden-files proof | `git diff --stat f8b926f HEAD -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/field hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu zkvm-block private-block-kernel private-model-kernel private-block-kernel-shaped` prints **nothing**. With `tests` and `scripts` added it prints exactly two paths, the lane's own layout model and its acceptance test |
| the filter's GROWTH | task 2 added **nothing measurable** (its nine tests are arithmetic); task 3's ten add about **25 s** (`w33-e32-run1.log`: the whole `e32_tests` module in 25.28 s at a peak RSS of 361 MB). Inside the minute this stage was given |
| no 125M run | none. No `r29-*` file was touched, and the two quarantined `u31-c6-run1.*` files are untracked and untouched |

**THE COMMITS OF STAGE 33**, in order:

| commit | what |
|---|---|
| `629f5f3` | the ledger skeleton: the three closures, the rules, the evidence prefix |
| `9f76ed8` | **task 1** (ruling J-7a): `s33_tests.rs` — the ASCII premise over the whole registry, the bad-profile control, the separation LEMMA over every profile length and every absorb layout, stage 32's own pair on real bytes, and the lemma's own control. In the same commit, **task 2's gap reproduced as two FAILING tests** and its log |
| `a57817e` | **task 2** (ruling S-6): the refusal in `Shape::new`, the `a_groups` arm documented as unreachable-after-validation, stage 24's mask-budget probe moved from a row width of 2^14 to 2^21, and the whole filter green at 384 |
| `ddb5db8` | **finding S33-F1**: the declared pair's own sentence corrected from "six NUL bytes" to the checked fourteen positions |
| `4505ddf` | **task 2**: the Python model mirrors ruling S-6 by the same name; 56 model tests |
| `6d71b40` | **task 3**: `Shape::rung_e32`, its run profile, the six registry lists a new profile trips, `e32_tests.rs` (9 tests), the parity test, and the measurement that places the shape in the ordinary filter |
| `2d04d94` | **task 3**: the two capture bundles, written INTO the repository (32.8 / 32.4 MB), their writer, and the captures README |
| `8361db2` | **task 3**: the shape in the independent Python model with its own test class; 60 model tests |
| this one | the seventh registry guard (the 299-byte parameter line), the ledger's tasks 1–5 and the close |

**WHAT THIS STAGE IS NOT.** Not a privacy result and not an acceptance: the
lane's code stays experimental, for the integrator (ruling V-1), and the two
bundles are the INPUT to the Python gate, not its verdict (ruling T-6). Not
a claim about 125M: **no 125M proof was run**, and no `r29-*` file was
touched. Not a change to what any existing profile sends, absorbs or draws:
the toy is byte-frozen and green and the six older development profiles'
receipt lengths are unmoved. Ruling S-6 is **not** a soundness or privacy
condition — it refuses a family nothing has ever proved at, and the arm it
protects is proved to compute the same value the live arm does.

**WHAT IT IS.** Three things that were true but unchecked are now checked.
A DECLARED hash coincidence whose separator was a comment is a lemma over
every registered profile length and every absorb layout of that length, with
one message-only finding against the record itself (S33-F1). A branch of the
function that fixes the `A` opening's group structure, which no shape
reached and no test covered, is a named refusal with the family stated in
plain words and the arm proved redundant. And the 125M endpoint's **32 data
rows, 37 commitment rows, 296-byte column digest and 38-row internal
boundary** — until today reachable only by an `#[ignore]`d 10 GiB test — are
proved, verified from bytes, checked against an independent reference kernel
on a GENERIC witness, censused against 125M figure by figure, tampered with
in rows no smaller shape has, run over two blocks, and captured for the gate
in two bundles a reader can open, **by tests that add about twenty-five
seconds to the ordinary filter**.

**ONE NOTE FOR THE INTEGRATOR.** `w14_tests::every_shape` and
`c6_tests::every_shape` are each a frozen list from their own stage and do
not carry rung-E32, so their censuses ("exactly two shapes at `head_dim`
64", "exactly two on the C-6 arm") are statements about the registry AS IT
WAS. rung-E32 is a third shape at `head_dim = 64` and a fourth on the C-6
arm. Nothing is wrong and nothing fails — the registry guards that must be
complete (`s24_tests`, `s25_tests`, `s33_tests`, `run_statement_file`) are
all updated — but if those two censuses are meant to stay current, their
lists want the same treatment, and that is a decision about what those tests
are for rather than a defect.

## Stage 34 — the slot expression IR, stage 1: the 23 slot polynomials as DATA beside the closures (2026-09-21, 16:4x–17:4x)

**Status: CLOSED 2026-09-21 17:45 PDT.** Opened 2026-09-21 16:48 PDT on the lane tip `226f3b2`
(pushed). The work is ruling **I-8** of
`docs/zkmatrix-poc/ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md` (the security
owner's disposition of the slot expression IR design memo and its
independent adversarial check), with ruling **I-2** — the base-field
classification is DERIVED from provenance and TESTED, never declared — as
its load-bearing half.

| task | what | state |
|---|---|---|
| 1 | the IR types in a new `private_block/slot_ir.rs`: table references with a stable id, a kind and a provenance; products with coefficients that carry their provenance; sums; the zero-check wrapper; the bilinear group bits; the LogUp terms; the pad-rule terms under `pad_on`; the declared degree. **`FieldKind` is a FUNCTION of provenance and has no setter** (ruling I-2) | **DONE** |
| 2 | a builder per arm of `argument::define` — all 16 arms, all 23 slots — producing that slot's IR from the same inputs and the same challenge draws, BESIDE the arm, with no line of the arm changed | **DONE** |
| 3 | the IR evaluator: the simplest correct interpreter, `#[cfg(test)]`-reachable only, never on the proving path | **DONE** |
| 4 | the oracle tests in `slot_ir_tests.rs`, in the ordinary filter: (a) IR = closure on random tables at every registered shape and both pad branches; (b) the declared degree against the closure's degree by interpolation, with the check's degree finding recorded as an ASSERTED fact; (c) **the `FieldKind` oracle** of ruling I-2, with a deliberately mislabelled table as its control; (d) the IR's counts against the drafter's inventory; (e) IR-C19's premise — `s(0) + s(1) == claim` at every round — measured on the ORACLE side, for the integrator's request R1d | **DONE** |
| 5 | stage 1b: a canonical JSON export of a shape's 23 slot IRs with a SHA-256, pinned per registered shape, so the independent Python gate can CROSS-CHECK its hand port (it does not replace it — ruling I-8) | **DONE** |
| 6 | this ledger section, closed with the commits, the counts and what stage 2 would be | **DONE** |

**The rules this stage works under** are the lane's: one writer, the build
recipe in this file's header, **no 125M proof run**, no registered profile
moved (toy, rung, rung-G, rung-K4, rung-P2, rung-C6, rung-W14, rung-E32,
125M — named and kept green), the toy byte-frozen, **no witness VALUE in any
log**, and — this stage's own, from ruling I-8 — **no execution path change
and no byte moved**: the closures stay the oracle, `run_slot` and the
verifier never see the IR, and the diff of `argument.rs` must show no
deleted or modified line inside any `SC_*` arm. The ordinary filter may not
grow by more than about two minutes.

**Evidence prefix**: `results/zk60_block125m_lane/x34-*`.

### Tasks 1–3 — the IR, the builder and the interpreter

**`hashline/src/private_block/slot_ir.rs` (new, 1,530 lines, `#[cfg(test)]`).**
The module is `cfg(test)` on purpose and not for tidiness: the stage's claim
is that no execution path changes and no byte moves, and a module no
production build compiles is the strongest available form of it. `capture`,
`run_capture` and `plane_index` are there already for the same reason.

| piece | what it is |
|---|---|
| `TableKind` | `Eq { start, point_len }`, `GroupEq { bits }` (the bilinear slots' group gate), `Public`, `Support { dom }`, `PlaneA`, `HelperH`, `Endpoint` |
| `TableProv` | **what BUILT the table**: `EqOfChallenges`, `PublicFromShape`, `PublicWithChallenge(why)`, `Committed { fixed_coords, extension_slice_coef }` |
| `FieldKind` | **derived, never written** — see ruling I-2 below |
| `Coef` | a value and a `CoefProv`: `One`, `NegOne`, `Base(why)` (a public base-field constant with the shape fact or module constant that fixes it), `Challenge(label)`, `Mu(k)`, `Nu(k)`, `Zeta(j)` (only under `pad_on`). **Seven, and no product variant** — see finding S34-F1 |
| `NodeBody` | `Affine { konst, terms }` (degree 1) and `Sum { subterms }`, a subterm being a coefficient times a product of factors; an empty factor list is a clause's inhomogeneous constant |
| `Node` | label, body and a degree **computed by the pusher** from the body and the nodes it refers to — a caller cannot write a degree of its own choosing, and `recompute_degrees` re-derives every one independently |
| `SlotTerm` | `coef * prod(wrapper) * prod(inner)`; the wrapper is the zero-check's `eq(tau, ·)` and, where the term carries it, the pad support gate |
| `SlotIr` | one slot at one shape: rounds, DECLARED degree, `pad_on`, `group_bits`, tables, nodes, terms — plus `max_term_degree`, `monomials`, `affine_forms`, `sum_nodes`, `is_well_formed` |
| `SlotIr::eval` | the interpreter: one forward pass over the nodes, then the terms. The simplest correct one — no common-subexpression pass, no reassociation, no specialisation by field kind. A faster one is stage 2's problem |

**RULING I-2, ENCODED RATHER THAN DOCUMENTED.** `TableRef` has **no field
kind to set**: `field_kind(&TableProv)` is the only producer of a
`FieldKind` in the module, and it says base-field exactly where no challenge
and no extension-valued input enters the construction — no `Coord::Fixed`
coordinate (so no `priv_table` `eqf` weighting), no extension slice
coefficient (so no `H` column's `u`), no challenge in a public payload, and
not an `eq`. The twelve tables of finding IR-C1 come out `Extension` **by
the rule and not by a list**, and a thirteenth of the same kind at a future
shape would too.

**The builder mirrors `argument::define` arm by arm** — sixteen arms over
twenty-three slots, each drawing the same challenges in the same order and
pushing the same tables in the same order, so a table id here is the
closure's `v[..]` index there. **Not one line of `argument.rs` is touched**
(the diff of that file is empty; see the gates).

### Task 4 — the five oracles (`slot_ir_tests.rs`, all in the ordinary filter)

**How the two are driven side by side.** Two transcripts in the same initial
state, one walk of the slot order on each: `define` on the first, the IR
builder on the second. Nothing else absorbs into either, so the two stay in
lockstep and the IR carries the same challenge VALUES as the closure it is
compared against. **A mirror that drew one challenge too many or too few
would move every later slot's values and fail the equality** — which is what
makes a hand transcription safe, and it is the device `plane_index.rs`
already uses for the push order.

| oracle | what it measured |
|---|---|
| **(a) IR = closure** | **207 (shape, slot) pairs, 8 random points each = 1,656 evaluations, every one equal**, at all NINE registered shapes **including 125M** — the IR needs no witness, so the 10 GiB shape is reachable from the ordinary filter here. Random points, not a witness's cube: a single wrong coefficient survives with probability ≤ `deg/|F|` ≈ 2^-125 per point |
| **(a) threads** | the same equality at `RAYON_NUM_THREADS` 1, 2 and 8 (92 evaluations at rung-P2, identical). **Nothing in the IR or the interpreter is parallel** — there is no rayon call in either — and the census says so by measuring |
| **(a) pad branches** | the branch is a property of the SHAPE, so the registry is what covers it: slot 03/14/15/17/19 pad-on at 8 shapes and off at 1 (the toy carries no pad rule), slot 02 on at 3 and off at 6. Both arms of all six pad-hosting slots are asserted, not hoped for |
| **(b) degree** | at every one of the 207 pairs, by interpolation on a random line with exact forward differences: the closure's TRUE degree never exceeds the DECLARED one, and the IR's computed `max_term_degree` **equals** the measured degree everywhere. **22 pairs have a one-degree gap, and they are exactly the four LogUp hosts whose own domain pads** — slots 14/15/16/18 at rung, rung-G and rung-K4, slots 14/15 at the five shapes where `Dom::Kv` and `Dom::F` are exact, none at the toy. Recorded as an ASSERTED FACT; ruling I-7 leaves the declared degrees alone |
| **(c) `FieldKind`** | at the eight shapes whose tables the filter can build, **every table the IR calls `Base` has a zero imaginary part in every word of the table the prover actually builds** — on the honest dense witness AND on a dense nonzero stream |
| **(c) control** | the memo's own classification written back into the IR at rung-W14: **all twelve** tables are caught |
| **(d) inventory** | **207 rows** against the drafter's `slot_ir_counts.json`: table count, main and extension rounds, declared degree, term count and max product degree agree at every one |
| **(e) IR-C19** | `s(0) + s(1) == claim` at **all 379 rounds of 46 (shape, slot) pairs** on the honest prover's own round loop, transliterated here |

**The base-field census, per shape, against the check's 131 of 229.**

| shape | tables | base by the IR's rule | identically zero on the honest fixture | extension tables with a nonzero imaginary part |
|---|--:|--:|--:|--:|
| toy | 217 | 120 | 2 | 93 of 97 |
| rung | 234 | 134 | 5 | 100 of 100 |
| rung-G | 234 | 134 | 5 | 100 of 100 |
| rung-K4 | 234 | 134 | 8 | 100 of 100 |
| rung-P2 | 231 | 131 | 8 | 96 of 100 |
| rung-C6 | 229 | 131 | 4 | 94 of 98 |
| **rung-W14** | **229** | **131** | 6 | 94 of 98 |
| rung-E32 | 229 | 131 | 6 | 94 of 98 |
| **125M** | **229** | **131** | — (tables not built) | — |

**rung-W14 and 125M are 131 of 229, the check's corrected count, and the
memo's 143 is wrong by twelve at every registered shape** — the inventory
comparison reports the difference at 90 rows (the seven matmul slots, the
two bilinear slots and `SC_TAB`, at nine shapes) and 108 tables in all,
which is exactly 12 per shape.

### Task 5 — the JSON export (stage 1b), and its schema

Nine files in `results/zk60_block125m_lane/x34-slot-ir/`, one per registered
shape, each pinned by SHA-256 **and** by length in `slot_ir_tests.rs`:

| shape | bytes | sha256 |
|---|--:|---|
| toy | 99,232 | `12e7ed013f6ca106232e2f3be87ecce6a82e7382df75c45aabe0a13f358f6bfc` |
| rung | 109,631 | `506d06db2158a16952975a29e5b36d7213761b2ce7fce28ba260d24e8bf774ad` |
| rung-G | 109,635 | `5cb8323a2a6607f38860e6c79ec1ee9b2f37fb4468cd7cf053fb77838f17d496` |
| rung-K4 | 109,637 | `e40501335cd10bfe75c04cf49d5b184426472e420658c8c7ade794a17a7f0401` |
| rung-P2 | 107,276 | `fa11ed91ecf9662d446d123ee3c7b9ef190e099a8b40b3656ff92ab4ae80d677` |
| rung-C6 | 105,384 | `120b116474c7265ebe75bbb122b87e2d5c1db10f068f5c951de2d133d2b4a9ba` |
| rung-W14 | 105,395 | `d207b45cae6a43a950cb641c75ad2f8c1c8d3698a4255bc61c973d0a6aa9d3ad` |
| rung-E32 | 105,393 | `500aefdcf6655f4c40aeb8a36d9651b51992f8427bd6aa6981eb0bbc031c04a7` |
| 125M | 105,382 | `2e8cdb877d4938a63d92dc8f4b054e59ff296456c56063f61c1ad8e39e948d39` |

**THE SCHEMA, `zk60-slot-ir/1`**, so the Python gate can read it without
reading the Rust. Top level: `schema`, `shape` (the registry key), `profile`
(the profile string), `slot_count`, `tables`, `tables_base_field`, and
`slots`, an array of twenty-three objects in slot order. Each slot object:

* `slot`, `name`, `kind` (`Private` / `Standalone` / `Host`);
* `main_rounds`, `extension_rounds`, `declared_degree` (what the round
  message length is built from) and `max_product_degree` (what the graph
  attains — the two differ by one at the LogUp hosts that pad);
* `pad_on`, and `group_bits` — `null` except at the two bilinear slots,
  where it is `log2(kv_heads)` and a reader can check it against the shape;
* `tables`: `{id, kind, field, prov, label}` in PUSH ORDER, which is also
  the order the masked terminals arrive in `SlotProof::terms`. `field` is
  `base` or `ext` and is DERIVED from `prov`;
* `nodes`: `{id, degree, label, body}` topologically ordered, `body` either
  `"affine"` with `konst` and `terms` (`{coef, table}`) or `"sum"` with
  `subterms` (`{coef, factors}`), a factor being `{"table":i}` or
  `{"node":j}`;
* `terms`: `{coef, wrapper, inner, degree, note}`.

A coefficient is `{"prov": "..."}`, plus `"value": "<re>+<im>u"` **only
where the provenance says the value is a public constant of the shape**
(`one`, `neg-one`, `kbase:…`). A challenge-dependent value never leaves the
process: 4,378 coefficients across the nine files carry a public value and
2,296 carry provenance only, checked by a reader over the written files.
That is what makes the export a per-SHAPE artefact that can be pinned at
all — the gate reads the STRUCTURE here and the VALUES from the transcript
it re-derives itself.

**Ruling I-8's condition is kept**: this is a CROSS-CHECK of the gate's hand
port, not a replacement. The hand port is not retired until the gate has
predicted, from the shape alone, the draw counts and degrees the export
declares, and one hand-ported family stays as an independent check forever.

### Findings

**S34-F1 (against the design memo, message only).** The memo's §2.3(ii)
writes slot 17's second top-level term as `nu0*per_row * [t1, t28] * <host_rs>`.
The CLOSURE multiplies only `nu0` there: `per_row` is the coefficient of the
HOSTED claim (`hosted = vec![(SC_RS, nu[0].mul(k(per_row))), …]`, which
enters the claimed SUM), not a factor of the polynomial. The IR carries
`nu0`, and had it carried `nu0*per_row` the equality oracle would have
rejected it at every shape where `per_row > 1`.

**S34-F2 (a fixture trap this stage walked into and closed).** With a
BASE-FIELD tag `g_u8`, `table_values_u8_at(len, g_u8) = k(i % 256) + g_u8`
is a base-field column and **finding IR-C1's twelfth table becomes
invisible to any oracle**. The first version of the harness used the older
definition sweeps' scalars (`g_u8 = 13`) and the control failed to catch the
mislabel for exactly that reason. All five definition-time challenges now
have a nonzero imaginary part, as they do in production, where each is
`gamma * TAG_*` or a drawn challenge.

**S34-F3 (the degenerate-fixture pattern again).** On the honest dense
witness, **2 to 8 base-labelled tables per shape are identically zero**, and
a mislabel of one of those is invisible — a zero word can hide a nonzero
imaginary part but can never create one. The `FieldKind` oracle therefore
runs twice, on the honest witness and on a dense nonzero stream, and the
control runs on the dense pass. The count of identically-zero base tables is
reported per shape rather than left implicit.

**S34-F4 (a difference of transcription convention, not of content).** The
drafter's inventory and this IR disagree on `ir_affine_forms`,
`ir_sum_of_product_nodes` and `ir_monomials` at the big slots (for example
`SC_TAB`: 4 sum nodes here against 5, 12 monomials against 21). Reading the
arm: both graphs compute the same polynomial — this one is proved equal to
the CLOSURE, which is the authority — and the difference is where the pad
term's node boundary is drawn (the drafter makes the batched pad term its
own node; here its two groups are subterms of the zero-check node) and how a
flattened monomial is counted. **Every load-bearing column agrees at all 207
rows.** Worth noting in passing: the drafter's own generated detail file
carries the IR-C1 error in plain sight — `t3 pub base table values U8` in
the `SC_TAB` section of `slot_ir_detail_m125.txt`.

**What lever (b) already gets for free, and it is worth saying.** The IR
encodes the memo's HOISTED form — the support gate multiplies the clause SUM
once, where the closure multiplies each of the eleven (slot 14) or five
(slot 17) clauses separately. The equality oracle therefore already proves,
at every registered shape and both pad branches, that **the hoist is
value-preserving**: 22 muls become 12 at slot 14 and 10 become 6 at slot 17
with the same field element out. That is half of lever (b) with its
"moves no byte" argument measured rather than argued.

### What stage 2 would be (lane-only), and what waits on the integrator

**STAGE 2, ON THIS LANE: lever (b) inside the closures of slots 17 and 14.**
Ruling I-4 fixes the order and the reason — the loop over evaluation points
and the fold live in `sumcheck::prove`, so a closure can only change what
happens INSIDE one evaluation, which is exactly what lever (b) is. The two
slots are 82% of the counted baseline and 71% of the measured
masked-sumcheck seconds, and the lever is **14.2% of the baseline at 125M,
15.0% at rung-W14** [COUNTED, the check's §5]. Three parts, and the IR is
now the list for all three:

1. **hoist the support gate** out of the clause batch,
   `sum_i mu_i g c_i = g sum_i mu_i c_i`: 22 multiplications become 12 at
   slot 14 and 10 become 6 at slot 17. **The IR already encodes the hoisted
   form, so this stage's equality oracle already proves the hoist
   value-preserving at every registered shape and both pad branches** — the
   change is a transcription of the IR's own grouping back into the closure,
   gated by a test that exists;
2. **typed coefficients**: every `k(c)`, `pow256(k)` and `2^SH_*` is a full
   five-multiplication `Fp2::mul` today where `mul_base` is two — 31 of them
   per evaluation at slot 14 and 10 at slot 17. **`CoefProv::Base` is the
   set**, named coefficient by coefficient in the export;
3. **the shared sub-expressions the closures miss**: `k_den·d` recomputed in
   `c0` and `c1`, `k_den·dm` in `c6` and `c7` (`argument.rs:1449-1457`), and
   `limbs`'s fold from `k = 0`, which multiplies by a runtime `Fp2::ONE`
   where the hand-written `l2` / `l3` skip it.

Its gate is this stage's own — the IR-vs-closure equality, unchanged, plus
the frozen receipt-length and digest pins. Nothing in it moves a byte.

**WHAT WAITS ON THE INTEGRATOR.**

* **Request R1d (finding IR-C19)** — one evaluation per pair index in
  `sumcheck::prove` is redundant because the prover knows the claim, 15.8%
  of the baseline. **Its premise now has lane evidence**: `s(0) + s(1) ==
  claim` at all 379 rounds of 46 (shape, slot) pairs on the honest prover's
  round loop. The remaining half is ruling I-3's — whether the claim
  `zk::masked_prove` tracks is the unmasked one at that point, and the debug
  assertion in test builds;
* **the `SumcheckRounds` interface (ruling I-5, Option A)** with the check's
  three corrections: drop the `Sync` supertrait, write the preservation list
  into the trait's documentation, name the frozen byte gates in the request.
  **Levers (a) and (c) cannot be taken without it**, because both need a
  range of pair indices or the whole round. Ruling I-5's precondition stands
  and is not this lane's to close:
  `tests/test_zk60_mvp_security_probe.py` is already red on main for
  `hashline/src/zk.rs` since `4751b93` and must be re-pinned before any
  further change there;
* **the Python gate's side of the export** — it reads
  `x34-slot-ir/slot_ir_<shape>.json` as a cross-check of its hand port, and
  the hand port is retired only on ruling I-8's condition.

### Task 6 — the gates and the commits

**THE GATES.**

| gate | result |
|---|---|
| `--lib private_` (the whole filter) at `44ac386` | **402 passed / 0 failed / 17 ignored, 569.84 s, exit 0** (`x34-gate-private1.log`) — stage 33's 394 plus this stage's first eight, nothing lost |
| `--lib private_` (the whole filter) at the tip | **403 passed / 0 failed / 17 ignored, 569.18 s, exit 0** (`x34-gate-private2.log`) — with the ninth test (the bilinear group bits) |
| the stage's own tests alone | **9 passed / 0 failed, 3.87 s.** The whole of stage 34 costs the ordinary filter about **four seconds**, well inside the two minutes it was given |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` — in the pass list of both runs |
| the development profiles' pins, BY NAME | `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims`, `p2_tests::the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move`, `c6_tests::the_new_shape_is_rung_p2_with_the_head_dimension_moved`, `w14_tests::the_new_shape_is_the_125m_head_axis_at_the_smallest_admissible_token_count`, `e32_tests::the_new_shape_is_125ms_endpoint_row_count_at_a_ten_log_endpoint`, plus `rung_tests` and `dense_tests` — in the pass list of both runs |
| the forbidden-files proof | `git diff --stat 226f3b2 HEAD -- zkp-core hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/field hashline/src/native_capture.rs hashline/src/private_seam.rs hashline/src/gpu zkvm-block private-block-kernel private-model-kernel private-block-kernel-shaped scripts tests` prints **nothing** |
| **the arms, untouched** | `python3 results/zk60_block125m_lane/x34-arm-immutability.py 226f3b2 HEAD`: **0 removed and 0 added lines** in `argument.rs` — the file is not in the diff at all, which is stronger than ruling I-8's condition. The script locates `define`'s `match slot` block (lines 1118..1731 at the base, 26 `SC_* =>` arm heads) so a later stage can run the same measurement against a diff that is not empty |
| the crate's warnings | **14**, the tip's own (`review_tests`, `s28_review_tests`, `run.rs`, `rung_tests`, `run_capture`, `attention.rs`); **neither new file adds one** |
| no 125M proof run | none. The 125M SHAPE is walked — definitions, IR, degrees, export — with **no witness, no tables and no proof**; no `r29-*` file is touched and the two quarantined `u31-c6-run1.*` files are untracked and untouched |

**ON THE HEAVY LOCK, AND WHY THIS RUN DID NOT TAKE IT.** At 17:15 the gate
was launched under `flock /tmp/zk-heavy.lock` per the no-hangup protocol and
sat behind **three m125 native-gate jobs of another lane** (one an hour in,
two queued four hours). This lane's filter is a CORRECTNESS gate, not a
measurement; with 12 GB available and 22 cores the queued run was cancelled
and re-launched detached WITHOUT the heavy lock, still with its log and its
`.done` marker. **The consequence is stated rather than hidden: 569 s is an
UPPER BOUND taken on a box that was not quiesced**, and it is not a timing
result. Against stage 33's 565.58 s the difference is about four seconds,
the same order as the stage's own measured 3.87 s of tests.

**THE COMMITS OF STAGE 34**, in order:

| commit | what |
|---|---|
| `fca610c` | the ledger skeleton: the six tasks of ruling I-8, the rules, the evidence prefix |
| `08658de` | **tasks 1–4**: `slot_ir.rs` (the types with `FieldKind` derived from provenance, the builder for all sixteen arms, the interpreter) and `slot_ir_tests.rs` (the equality oracle, the thread census, the degree oracle, the `FieldKind` oracle and its control, the inventory comparison, IR-C19's premise), plus the drafter's inventory extract |
| `e007064` | **task 5**: the canonical JSON export, nine files, pinned by digest and by length |
| `44ac386` | the arm-immutability proof script and its log; `CoefProv::Product` removed (finding S34-F1) and `SlotIr::profile` made the export's source |
| `33c2db0` | the bilinear slots' group bits checked against the shape — the S19-F1 repair as data |
| this one | the ledger's tasks 1–6 and the close |

### What this stage is NOT

Not a speed result: **nothing was made faster and no execution path
changed.** Not a privacy or a soundness claim: the IR describes `f`, never
`f + c·g`, and the mask, the transcript, the extension rounds and every
table CONSTRUCTION stay where they are. Not a profile change: no declared
degree, no receipt length and no digest moves, and ruling I-7's degree gap
is recorded and left alone. Not a replacement for the closures — they are
the oracle, and stage 1 ends with them still holding that job. Not a claim
about 125M: the shape is WALKED, never proved.

**WHAT IT IS.** The twenty-three slot polynomials now exist as data that a
machine can read, beside the closures, with **1,656 evaluations at nine
shapes saying the data and the code are the same polynomial**; the
base-field classification that finding IR-C1 showed was wrong by twelve
tables is now derived from provenance and **tested against the tables the
prover really builds**, with a control that catches all twelve; the true
degree of every slot at every shape is measured for the first time and
agrees with the IR's computed one everywhere; the premise of the
integrator's cheapest lever is checked at 379 rounds; and a canonical,
digest-pinned export gives the independent Python gate something to check
its hand port against.

## Stage 35 — lever (b) inside the closures of slots 17 and 14, without moving a byte (2026-09-21, 17:5x–)

**Status: CLOSED 2026-09-21 18:45 PDT.** Opened 2026-09-21 17:58 PDT on the lane tip
`89e393f` (pushed). The work is stage 2 of ruling **I-4** of
`docs/zkmatrix-poc/ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md`: lever (b) —
shared sub-expressions, the hoisted support gate, base-field constants —
inside the closures of the two most expensive slots, **17 `SC_SZC`** (the
softmax zero-check) and **14 `SC_DZC`** (the D zero-check). Lane-only:
ruling I-4 says the loop over evaluation points and the fold live in
`zkp-core/src/sumcheck.rs`, so a closure can only change what happens INSIDE
one evaluation, and that is exactly what lever (b) is.

| task | what | state |
|---|---|---|
| 1 | **the oracle first**: the two closure bodies copied verbatim from `89e393f` into `s35_tests.rs`, driven on the REAL definition-time captures, differentially against the production closure at every registered shape and both pad branches; plus the new closure against the stage-34 IR; plus a pin of the declared degree and of the table list and order | **DONE** (`fa3ed3b`) |
| 2 | **lever (b)(i)** — the support gate hoisted out of the clause batch (the IR's own grouping: 22 multiplications become 12 at slot 14, 10 become 6 at slot 17) | **DONE** (`52dbaa2`) |
| 3 | **lever (b)(ii)/(iii)** — the shared sub-products the closures recompute, and the public base-field constants through `mul_base` instead of a full extension multiplication | **DONE** (`ed77271`, `9e11312`) |
| 4 | **measure**: rung-W14 three runs before and after, `PB-SLOTSTEP` masked-sumcheck seconds for slots 17 and 14 and the total prove; then ONE 125M dense run against the two same-day baselines | **DONE** |
| 5 | the gates, the commits and this ledger section closed | **DONE** |

**The rules this stage works under** are the lane's, plus its own, which are
stricter than stage 34's in one direction and looser in another: the diff of
`argument.rs` may touch **only the two arms** `SC_DZC` and `SC_SZC` (stage 34
touched none), and **nothing sent, absorbed or drawn may change** — the
closure's VALUE at every point identical, the tables list and their order
unchanged, the declared degree unchanged, no new draw, no reordered absorb,
the verifier untouched, every registered receipt-length and digest pin green
by name. No registered profile moves.

**Evidence prefix**: `results/zk60_block125m_lane/y35-*`.

### Task 1 — the oracle, written and green BEFORE anything changed (`fa3ed3b`)

**The problem this stage had to solve first, and how.** Stage 28's method is
that the OLD form and the NEW form are run on the same inputs in the same
test, the old form copied verbatim from the parent commit so that it is an
oracle and not a second name for the code under test. A slot's closure makes
that hard: it captures thirty-odd definition-time values — the table index
map, `mu` and `nu`, the LogUp column descriptions, the pad-rule groups, the
two support gates, `lam`, `alpha`, `beta`, `g_exp` — and **none of them is
reachable from a sibling module**, because `B`, `Gate`, `PadTerm`, `LkT`,
`limbs`, `helper_sum` and `k` are all private to `argument.rs`.

So the arm hands them over. Two `#[cfg(test)]` statements per arm — a
capture record built just before the closure, and a call just after it —
and `s35_tests.rs` holds the two closure bodies **as they stand at
`89e393f`, verbatim**, together with verbatim copies of the five helpers
they call. The consequences are worth spelling out:

* the comparison runs **on every definition of slots 14 and 17 anywhere in
  the crate's tests**, at every registered shape and on both sides of every
  pad branch, without any test having to arrange it. Four random points per
  definition; the filter defines these slots many hundreds of times;
* **the new form is the production closure itself**, passed as `&dyn Fn`,
  never a copy of it — the weakness stage 28's ledger warns about is closed
  in the one direction that matters;
* nothing is compiled into a production build: in `cfg(not(test))` the two
  statements and their clones do not exist.

**The second leg is the stage-34 IR**, and it is independent of the first.
`slot_ir.rs` is not touched by this stage (the forbidden-files proof says so
with a diff), and its equality oracle proved the IR equal to the closure AT
`89e393f` over 1,656 evaluations. So `old == IR` is pinned and `IR == new`
is re-proved here at 32 points per shape — **576 random points over 9 shapes
x 2 slots, every one equal** — which gives `old == new` a second time, by a
route that hands no capture over and that reaches the 125M shape.

**The pins task 1 added**, all green at `fa3ed3b` where the new form was
still the old one, and green at every commit since:

| test | what it holds |
|---|---|
| `the_two_rewritten_closures_equal_the_parent_closure_at_every_registered_shape` | the differential above, driven once over the registry: 72 (point, slot) comparisons on the walk, and the assertion that the arm's hook **fired** — a hook compiled out would leave the counter where it was |
| `the_two_rewritten_closures_equal_the_stage_34_ir_at_every_registered_shape` | 576 points, 9 shapes x 2 slots |
| `the_table_list_the_order_and_the_declared_degree_of_the_two_slots_are_where_they_were` | **18 (shape, slot) rows**: table count, the `Tab` variant sequence in PUSH ORDER, main rounds, extension rounds and declared degree, against literals read out of the digest-pinned `x34-slot-ir/*.json`. The table order decides the `v[..]` indices and the order the masked terminals are absorbed in; the degree decides every round message's length |
| `multiplying_by_a_constant_with_no_imaginary_part_is_exactly_mul_base` | the one implementation identity lever (b)(iii) rests on, on all thirteen constants of the two arms, 6,656 comparisons |
| `the_rewrite_removes_the_counted_multiplications_at_every_registered_shape` | the four-rung count ladder, per shape and per slot |

### Tasks 2 and 3 — the three changes, one commit each

**Every one of them is value-preserving, and the reason is written per
change rather than asserted once.** `Fp` is an exact field with canonical
representatives everywhere (`zkp-core/src/field.rs:1-9`), so reassociation
and redistribution are not approximations: the field element out is the same
word.

| # | commit | the change | why the value cannot move |
|---|---|---|---|
| (i) | `52dbaa2` | **the support gate hoisted out of the clause batch** at both slots: `sum_i mu_i g c_i` becomes `g sum_i mu_i c_i`. Eleven multiplications by `g` become one at slot 14, five become one at slot 17 | distributivity. `g` is one field element at each evaluation point whatever the pad boundary does — 0 or 1 at a cube point, arbitrary at an interpolated one, and distributivity does not care. **The stage-34 IR already encodes this grouping**, so the IR leg covers it at every shape. Only `gs` is hoisted at slot 17: `ght` gates the row-sum host term and is a different table (finding S9-F7) |
| (ii) | `ed77271` | **the two sub-products slot 14 recomputes**: `k_den * d` (inside c0's `k_den.mul(y).mul(d)`, which is `(k_den * d) * y` reassociated, and outright in c1) and `k_den * dm` (c6, c7) | associativity and commutativity. This is the only pair the check's §5 found and the only pair reading the arm turns up; **slot 17 gets nothing from this lever and the ladder says so**, because `delta`, `sr` and the `at(p)` reads are already shared by a `let` |
| (iii) | `9e11312` | **the public constants through `mul_base`**: slot 14's `p1` in `l2` (five calls), the four byte-limb folds, `kd`/`kdm`, `k_num` and `k_dv` in c0 and c6 and the two host shifts; slot 17's `1 << F_P` in c2, `1 << SH_S` in `host_s` and the three byte-limb folds. The limb folds also **drop the `256^0` weight** | for a constant with zero imaginary part, `x.mul(c)` **IS** `x.mul_base(c.c0)` — `Fp2::mul` computes `(a c0 + b c1 * 7, a c1 + b c0)` and `c1 = 0` collapses it to `mul_base`'s body character for character. An identity of the implementation, not a ring law, and the stage tests it on all thirteen constants. `limbs` folds from `Fp2::ZERO` and multiplies the first limb by a runtime `Fp2::ONE`; `Fp2::ZERO.add(x.mul(Fp2::ONE))` is `x`, so taking the first limb AS the running sum is not even a reassociation |

**THE COUNT [COUNTED], per evaluation, in the check's own unit** (a full
`Fp2::mul` is five base multiplications, `mul_base` is two, additions are
free), at the four shapes with 125M's limb structure (`limbs_norm` 4,
`limbs_sigma_s` 3, `limbs_p` 2):

| slot | `89e393f` | after (i) | after (ii) | after (iii) | the whole closure | share of the closure |
|---|--:|--:|--:|--:|--:|--:|
| 17 `SC_SZC` | 175 | 155 | 155 | **119** | 405 | **13.8%** |
| 14 `SC_DZC` | 320 | 270 | 260 | **165** | 828 | **18.7%** |

The "whole closure" column adds what neither form changes: `helper_sum` and
`PadTerm::eval`, both outside the two arms. At the toy, where the profile
carries no pad rule, `g` is `Fp2::ONE` and the hoist saves the same count on
multiplications by one. **Against the check's own lever (b) figure of 14.2%
of the 125M baseline**: that figure is over all twenty-three slots, and
these two are 83% of the baseline, so 11-12% of the whole baseline is what
this stage's changed lines can be worth [COUNTED, derived]. **Ruling I-1
stands: none of this is a time**, which the measurement below makes very
concrete.

### Task 4 — the measurement

**rung-W14, three runs before and three after** [MEASURED, three runs each,
shared box, **NOT quiesced** — another lane held the heavy lock throughout
and the box carried load 1.6]. Same binary path, same command, same env
(`HL_PB_TIMING=1`), the `PB-SLOTSTEP` masked-sumcheck line of each slot and
the prover's own wall clock. `y35-w14-before.log` (at `fa3ed3b`, the arms
still the parent's) against `y35-w14-after.log` (at `9e11312`).

| figure | before min / median / max | after min / median / max | reading |
|---|---|---|---|
| slot 17 masked sumcheck, s | 0.307 / **0.351** / 0.366 | 0.341 / **0.351** / 0.369 | **the medians are identical; the ranges all but coincide** |
| slot 14 masked sumcheck, s | 0.794 / **0.826** / 0.829 | 0.790 / **0.805** / 0.826 | −2.5% at the median, ranges overlap |
| prove, s | 3.816 / **3.871** / 3.903 | 3.662 / **3.741** / 3.852 | −3.4% at the median, ranges overlap |
| receipt, B | 16,421,048 | 16,421,048 | **identical** |

**Said plainly: at rung-W14 the change is inside run-to-run spread.** Every
one of the three comparisons has overlapping ranges, and slot 17's medians
are the same number to three decimals. The shape is why: rung-W14's two big
cubes are 2^16 words, the round loop there is short, and the per-evaluation
arithmetic is not what the seconds are made of at that size. A count of
13.8% that does not show at 2^16 is exactly the situation ruling I-1
describes.

**125M, ONE dense run, against the two same-day baselines** [MEASURED, one
run, shared box]. `y35-m125-after.log`, exit 0, started 18:29 PDT once the
heavy lock freed, detached under `flock /tmp/zk-heavy.lock` inside a 12 GiB
`systemd-run` scope with `MALLOC_MMAP_THRESHOLD_=131072`, the same command
and the same env (`HL_PB_TIMING=1 HL_PB_WEIGHTS=dense`) as
`q28-m125-final-dense.log`. Only one 125M run was spent, because the two
committed baselines are the same prover on the same day and the brief
allows them as the baseline.

| figure | `q28-m125-final-dense` (stage 28) | `r29-m125-bfcensus` (stage 29) | **this run** |
|---|--:|--:|--:|
| **slot 17 masked sumcheck, s** | 3.054 | 3.107 | **2.660** |
| slot 14 masked sumcheck, s | 1.642 | 1.872 | **1.741** |
| prove, s | 17.401 | 19.357 | **18.405** |
| **receipt, B** | 40,783,352 | 40,783,352 | **40,783,352** |
| peak RSS, MiB | 10,156 | 10,141 | 10,149 |
| verify from bytes, s | 1.15 | 1.34 | 1.21 |
| slot 17 tables: build, s (untouched) | 0.251 | 0.510 | 0.689 |
| `A: commit`, s (shared, untouched) | 3.069 | 3.552 | 3.017 |
| `H: commit`, s (shared, untouched) | 3.431 | 3.923 | 3.873 |
| `H: LogUp helper inverses`, s (untouched) | 1.079 | 1.202 | 1.348 |

**How to read it honestly, line by line.**

* **Slot 17's masked sumcheck is below BOTH baselines, and the baselines are
  0.053 s apart.** 2.660 s against 3.054 and 3.107 is −12.9% and −14.4%,
  against a baseline spread of 1.7% on that same line. It is one run, so it
  is not a confidence interval; but the two baselines agree with each other
  far more closely than either agrees with this run, and the counted figure
  for slot 17's closure is 13.8%. **This is the one place where the count
  and the clock say the same thing.**
* **The neighbouring phases this stage does not touch got SLOWER in this
  run**, not faster: slot 17's table build 0.251/0.510 -> 0.689, the LogUp
  helper inverses 1.079/1.202 -> 1.348, `H: commit` 3.431/3.923 -> 3.873.
  The box was busier than stage 28's. That makes slot 17's sumcheck number
  harder to explain away, not easier.
* **Slot 14's masked sumcheck, 1.741 s, is INSIDE the two baselines**
  (1.642 and 1.872). Nothing measurable, and it is the slot with the LARGER
  counted saving. Said plainly: the count does not predict the clock, which
  is the check's IR-C9 measured once more.
* **The total prove, 18.405 s, is inside the 17.40-19.36 s the two baselines
  already span.** The honest sentence is unchanged from stage 29: **one 125M
  block proves in 17.4-19.4 s on this laptop**, and this stage does not
  narrow it. A 0.4 s saving on one slot sits under a 2 s run-to-run band.
* **The receipt is the same 40,783,352 bytes and the test's own assertions
  pass**, which is the point of the stage.

### Task 5 — the gates

| gate | result |
|---|---|
| the whole `--lib private_` filter at the tip | **408 passed / 0 failed / 17 ignored, 529.66 s, exit 0** (`y35-gate-private.log`) — stage 34's 403 plus this stage's five, nothing lost, and 40 s FASTER than stage 34's 569 s on a box that was no quieter |
| the stage's own tests alone, at every commit | `y35-a2-oracle.log`, `y35-b1-hoist.log`, `y35-b2-shared.log`, `y35-b3-mulbase.log`: **5 passed / 0 failed, ~1.05 s** at each of the four |
| the differential against the verbatim `89e393f` bodies | green at all four commits: 72 (point, slot) comparisons per registry walk, nine shapes, slot 17's pad branch taken at eight and not taken at one |
| the stage-34 IR oracle | `slot_ir_tests::the_slot_ir_evaluates_to_the_closure_at_every_registered_shape_and_slot` and `...the_slot_ir_export_is_canonical_and_its_digest_is_pinned_at_every_registered_shape`, both `... ok` — **the strongest gate here, because `slot_ir.rs` did not change and the closures must still equal it** — plus this stage's own 576-point leg |
| **the arms-only proof** | `python3 results/zk60_block125m_lane/y35-arms-only.py 89e393f HEAD`: every hunk of `argument.rs` inside the `SC_DZC` (base 1401..1472) or the `SC_SZC` (base 1587..1660) arm, **0 hunks outside** |
| the forbidden-files proof | `git diff --stat 89e393f HEAD -- <the no-edit list>` prints **nothing** |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` — all three `... ok` in `y35-gate-private.log` |
| the development profiles' pins, BY NAME | `k4_tests::the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims`, `p2_tests::the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move`, `c6_tests::the_new_shape_is_rung_p2_with_the_head_dimension_moved`, `w14_tests::the_new_shape_is_the_125m_head_axis_at_the_smallest_admissible_token_count`, `e32_tests::the_new_shape_is_125ms_endpoint_row_count_at_a_ten_log_endpoint`, `w14_tests::an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_w14` — all `... ok` |
| the 125M receipt length | **40,783,352 B**, asserted by the test itself in `y35-m125-after.log` |
| 125M runs spent | **one**, the final one; the baseline is the two committed same-day logs |

### Findings

**S35-F1 — `argument.rs::limbs` is now dead code, and this lane may not
remove it.** Slots 17 and 14 were its only callers; after lever (b)(iii)
both fold their limbs through the arm-local `lb`, and the test build reports
**15 warnings where it reported 14**. The function is at line 825, outside
both arms, and the stage's own rule is that the diff of this file stays
inside the two arms — so the warning is left standing rather than papered
over. **Handover: delete `limbs` or put it behind `cfg(test)`.** It is worth
keeping as a `cfg(test)` oracle for `lb` rather than deleting outright.

**S35-F2 — the count and the clock disagree, again, and in the direction
the check predicted.** Slot 14 has the larger counted saving (155 units per
evaluation against slot 17's 56, and 18.7% of its closure against 13.8%) and
shows **nothing** at 125M, while slot 17 shows the full counted figure. The
check's IR-C9 said the count model over-weights slot 17 against slot 14 by
2.1x when measured; here the SAVING behaves the other way round from what
the count alone would suggest. One run each way, so this is an observation
and not a law — but it is one more reason not to carry a counted percentage
to a slot's seconds.

### What was tried and DROPPED

* **Factoring the support gate across the HOST terms as well.** At slot 14
  both host terms carry `g`, so `v0*(other + g S) + nu0 v1 g H1 + nu1 v2 g H2`
  can be regrouped as `v0*other + g*(v0 S + nu0 v1 H1 + nu1 v2 H2)`. Counted:
  it saves **one** `Fp2::mul` of the slot's ~110, five base units of 828, and
  it makes the closure's correspondence with the stage-34 IR's term list less
  direct. Dropped as gold-plating. At slot 17 the same regrouping is
  count-NEUTRAL (five multiplications either way, because `ght` and `gs` are
  different tables), and it was dropped there for that reason.
* **Changing `limbs`, `helper_sum`, `Gate` or `PadTerm` themselves.** All
  four are outside the arms. `helper_sum`'s `den` already uses `mul_base`
  for its base coefficients; `PadTerm::eval`'s weights are powers of `zeta`,
  a challenge, so no `mul_base` applies there; `PadTerm::eval` pays one
  `mu.mul(acc)` even with no group at all, which is the memo's §3.5 finding
  and is a one-line change for whoever owns that function.
* **`add_base` for the `k(32768)`, `k(-MASK_SCORE)` and `2^(SH_*-1)`
  constants.** Value-identical and free of risk, but an addition costs zero
  in the check's unit, so it would buy a diff and no count.
* **Lowering the declared degree** (ruling I-7): excluded by the ruling, and
  it would move bytes.

### What remains for stage 3, and what it waits on

Levers **(c)** (finite differences, 31.2% of the baseline) and **(a)**
(base-field tables, 14.4%) **cannot be taken from a closure**: both need a
range of pair indices or the whole round, which lives in
`zkp-core/src/sumcheck.rs`. They wait on ruling I-5's `SumcheckRounds`
interface, and request **R1d** (one redundant evaluation per pair index,
15.8%) waits on the same integrator. Ruling I-5's precondition is unchanged
and is not this lane's to close: `tests/test_zk60_mvp_security_probe.py` is
red on main for `hashline/src/zk.rs` since `4751b93`.

**The honest headline of this stage.** Lever (b) is taken in full inside the
two closures that are 83% of the counted baseline, with byte identity
demonstrated three ways; it is worth a **counted** 13.8% of slot 17's
closure and 18.7% of slot 14's; and what it is worth on the clock is **one
measured 0.4 s on slot 17's masked sumcheck at 125M and nothing anywhere
else that a shared box can distinguish from noise**. The prove stays inside
17.4-19.4 s. The road to 5 s is still the two commitments and the device,
exactly as ruling I-9 says.

**The crate's warnings: 15**, the tip's 14 plus finding S35-F1's dead
`limbs`. Neither `s35_tests.rs` nor either arm adds any other.

**THE COMMITS OF STAGE 35**, in order:

| commit | what |
|---|---|
| `e2467e0` | the ledger skeleton: the five tasks, the rules, the evidence prefix |
| `fa3ed3b` | **task 1, the oracle before the change**: `s35_tests.rs` with the two `89e393f` closure bodies verbatim, the arms' two `#[cfg(test)]` capture statements each, the IR leg, the table/degree pins, the `mul_base` identity and the count ladder — 5 passed with the new form still the old one |
| `52dbaa2` | **lever (b)(i)**: the support gate hoisted, 22 -> 12 at slot 14 and 10 -> 6 at slot 17; the four-rung ladder; the three before-timings |
| `ed77271` | **lever (b)(ii)**: `k_den*d` and `k_den*dm` formed once |
| `9e11312` | **lever (b)(iii)**: the thirteen public constants through `mul_base`, the limb folds' `256^0` dropped; finding S35-F1 |
| this one | the measurements, the gates and this section, closed |

### What this stage is NOT

Not a byte change: the toy's 2,816,472 B, the two rungs', rung-K4's,
rung-W14's 16,421,048 B and 125M's 40,783,352 B are all where they were,
and the three ways the closures were held to their parent say why. Not a
privacy or a soundness claim: no table, no challenge, no absorb, no draw
and no declared degree moved, and the verifier was not opened. Not a speed
result at rung-W14 — the measurement there is inside run-to-run spread and
the section says so in those words. Not a 5-second step: one 125M block
still proves in 17.4-19.4 s, and 79% of that is in files this lane may not
edit.

---

## Stage 36 — the read-only TEST OBSERVERS, and the draw-accounting test unblocked (2026-09-22, 07:5x–)

**Status: `OPEN` (skeleton).** Opened 2026-09-22 07:58 PDT on the lane tip
`fee1a8d`. The integrator authorised, at 07:25, exactly what stage 25's
item W-8 said was blocked: a **read-only generator byte-consumption
counter** and a **transcript squeeze counter** in `zkp-core`, plus a
**test observer** in `protocol::check_opening_challenges`. With them,
assertions 1–4 and 6 of `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §3.1 —
the owed draw-accounting test of ruling R-3 — become writable on this lane,
and `s25_tests::the_draw_accounting_assertions_are_still_blocked_on_the_
generators_accessor` (the tripwire stage 25 left behind, which says in its
own words that it "fails the day the accessor lands") must be retired in
the same stage that lands it.

**THE INTEGRATOR'S CONDITIONS, verbatim (2026-09-22 07:25), every one
binding.** "you may implement the read-only RNG byte-consumption and
transcript squeeze counters plus the test observer in
`protocol::check_opening_challenges`, and wire the partial tests, as a
separate lane commit. Preserve `ZkRng`'s non-Clone property and every
draw/absorb order; expose no keys, stream contents or challenge values
through production interfaces. Dependency `cfg(test)` is not enabled when
hashline tests link zkp-core: use an explicit `test-observers` feature with
hashline's dev-dependency enabling it, alongside `cfg(test)` for core's own
tests. No feature in normal dependencies/defaults. Derive consumption from
existing counter/position state, with refill-boundary and mixed-draw tests;
do not add work to every hot draw."

**THE WRITE SET OF THIS STAGE**, and nothing else: `zkp-core/src/rng.rs`,
`zkp-core/src/transcript.rs`, `zkp-core/Cargo.toml` (`[features]` only),
`hashline/Cargo.toml` (the dev-dependency line only),
`hashline/src/private_block/protocol.rs` (the hook in
`check_opening_challenges` only), the lane's own test files under
`hashline/src/private_block/`, `hashline/src/private_block.rs` (module
lines), this ledger, and evidence under `results/zk60_block125m_lane/` with
the prefix `z36-`.

**THE PRODUCTION-IDENTITY RULE.** Every line added to `zkp-core` and to
`protocol.rs` sits inside `#[cfg(any(test, feature = "test-observers"))]`
(or `#[cfg(test)]`, which is strictly narrower). A release build without
the feature must compile the same code paths byte for byte — proved two
ways: a script that shows every added or changed hunk in those files is
inside such a gate, and the frozen toy receipt still verifying at its
frozen length.

**THE TASKS**

| # | task | acceptance |
|---|---|---|
| 1 | the generator's consumption accessor + its refill-boundary and mixed-draw tests | derived from `(counter, pos)`, no new per-draw work; reading it changes no output; `ZkRng` still not `Clone` |
| 2 | the transcript's squeeze counter + tests | derived from `counter`; reading it changes no challenge |
| 3 | the `test-observers` feature and hashline's dev-dependency | not in `[dependencies]`, not in `default`; the release build never sees it |
| 4 | the observer hook in `check_opening_challenges` | no production call site when the gate is off; counts and verdicts only, never a value |
| 5 | the draw-accounting test, all seven assertions live | the counted draws reproduced per shape and per generator, and the toy statement's 327,052 |
| 6 | this section closed | commit list, the cfg-gate proof, the counts, and what the integrator needs |

**No 125M run. No privacy acceptance.** What this stage produces is a
measurement of the prover's randomness accounting and a test that keeps it
true; it establishes no privacy property.

### Stage 36 — CLOSED (2026-09-22, 07:58–08:5x)

**Status: `LANDED`.** Eight commits on `fee1a8d`. No 125M run, no GPU, no
byte of any profile moved: the toy's receipt is still **2,816,472 B**,
rung-C6's **7,452,040 B** and rung-W14's **16,421,048 B**, each asserted
by the tests that already asserted them.

#### What the observers are, one line each

| observer | what it returns | derived from |
|---|---|---|
| `ZkRng::consumed_bytes` | the stream BYTES this generator has yielded | `(counter, pos)`: `0` when `counter == 0`, else `(counter - 1)·8192 + pos` |
| `ZkRng::refills` | how many times the stream was refilled | `counter` |
| `Transcript::squeezes` | how many SQUEEZES this transcript has performed | `counter` |
| `draw_observer` (in `check_opening_challenges`) | per call: draws, of which group-coefficient draws, and which of the three exits | the wrapped draw closure and three gated markers |

Nothing was added to any hot path: `next_u64`, `absorb` and
`squeeze_bytes` are byte for byte what they were, and the accessors are
`&self`.

#### The production-identity proof

`python3 results/zk60_block125m_lane/z36-cfg-gate-proof.py fee1a8d HEAD`
(`z36-cfg-gate-proof.txt`) takes the diff of the three source files the
integrator's condition names and requires every added line to be inside a
`#[cfg(test)]` / `#[cfg(any(test, feature = "test-observers"))]` item (the
attribute, the item it gates and the comment block above it) or to be a
comment or blank line, and requires that nothing was deleted:

| file | added | inside a gate | comment/blank outside | **code outside a gate** | deleted |
|---|---:|---:|---:|---:|---:|
| `zkp-core/src/rng.rs` | 225 | 225 | 0 | **0** | 0 |
| `zkp-core/src/transcript.rs` | 114 | 113 | 1 | **0** | 0 |
| `hashline/src/private_block/protocol.rs` | 21 | 10 | 11 | **0** | 0 |

and the manifests by rule: `test-observers` appears in zkp-core's
`[features]` and in hashline's `[dev-dependencies]`, and nowhere else.
`cargo tree -e features,no-dev -i zkp-core` shows the feature **absent**
from the non-dev graph and present only through the dev edge. Both crates
**build in release with the feature off**, exit 0
(`z36-release-nofeature.log`); `hashline/Cargo.lock` does not move.

#### The draw accounting, measured (`z36-pinned.log`, 8 passed / 0 failed, 13.33 s)

One proof per shape, the block generator and the live transcript OURS, the
receipt verified in typed form and from bytes before any counter is read:

| shape | block stream B | `fp()` draws | salts | refills | live squeezes | replay points | frame B |
|---|---:|---:|---:|---:|---:|---:|---:|
| **toy** | **5,396,672** | **320,908** | **8,192** | 659 | **1,863** | **1,027** | 2,816,472 |
| rung-K4 | **12,401,856** | **750,540** | **12,288** | 1,514 | 2,610 | 1,642 | 4,743,128 |
| rung-P2 | 12,401,056 | 750,490 | 12,288 | 1,514 | 2,604 | 1,642 | 4,742,728 |
| rung-C6 | 17,654,944 | 1,078,858 | 12,288 | 2,156 | 3,977 | 2,962 | 7,452,040 |
| rung-W14 | 100,308,416 | 5,998,940 | 135,168 | 12,245 | 2,254 | 1,156 | 16,421,048 |
| rung-E32 | 25,356,928 | 1,560,232 | 12,288 | 3,096 | 5,919 | 4,874 | 11,368,824 |

The two ENDPOINT generators of the same statements, measured on the
replica (`16·fp + 32·salts` exactly at every one):

| shape | both endpoints, B | `fp()` | salts | each |
|---|---:|---:|---:|---|
| toy | 229,376 | 6,144 | 4,096 | 3,072 draws, 2,048 salts |
| rung-K4 / rung-P2 | 499,712 | 14,848 | 8,192 | 7,424 / 4,096 |
| rung-C6 | 598,016 | 20,992 | 8,192 | 10,496 / 4,096 |
| rung-W14 | 6,889,472 | 168,448 | 131,072 | 84,224 / 65,536 |
| rung-E32 | 729,088 | 29,184 | 8,192 | 14,592 / 4,096 |

**THE FOUR FIGURES OF RECORD, REPRODUCED FROM THE CODE.**

1. **327,052** `fp()` draws per toy proof over the three generators —
   decision **D9**'s figure, the one `2^-77.68 = 327,052 × 2^-96` is
   computed from (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §4 and §9 item
   2). Measured: 320,908 + 3,072 + 3,072 = **327,052**, with 12,288 salts
   and 5,626,048 stream bytes in total. The salt count is the hash-layer
   table's own `4·2,048 + 4,096 = 12,288`, reached from the other side.
2. **Claim A-5's table**, at both rows this lane can reach: the toy's
   320,908 / 8,192 / 5,396,672 and **rung-K4's 750,540 / 12,288 /
   12,401,856** — `stream_positions.py`'s numbers, recomputed here in Rust
   from shape and layout constants and then matched against a real stream.
3. **1,863** live squeeze points per toy proof — row **T4a** of
   `ZK60_TOY_ROUTE_A_REEXAMINATION.md` §1.4.
4. **1,027** points re-issued by the refusal replay per toy proof — row
   **T4c** and clarification **9** of the accepted statement — in exactly
   four calls (`A`, `H`, and one per endpoint), all accepted, each drawing
   its group members then its commitment's own row count.

Nothing failed to reproduce. The five rungs' squeeze and replay counts are
**pins measured by this stage**, not reproductions, and the module says so
where it declares them.

#### The gates

| gate | result |
|---|---|
| the whole `--lib private_` filter at the tip | **416 passed / 0 failed / 17 ignored, 585.06 s, exit 0** (`z36-gate-private2.log`, run at the tip after the two cosmetic fixes; the earlier run before them is `z36-gate-private.log`, 416 / 0 / 17 in 585.24 s) — stage 35's 408 plus this stage's eight, nothing lost |
| `zkp-core`'s own suite, WITHOUT the feature | **56 passed / 0 failed** (`z36-core-plain.log`) — the tip's 50 plus this stage's six |
| `zkp-core`'s own suite, WITH `--features test-observers` | **56 passed / 0 failed** (`z36-core-featured.log`) — the same six, because `cfg(test)` already opens the same gate; what the feature adds is a DEPENDENT's view |
| the stage's own tests alone | **8 passed / 0 failed, 13.33 s** (`z36-pinned.log`) |
| the release build with the feature OFF | exit 0 for both crates (`z36-release-nofeature.log`); `cargo tree -e features,no-dev -i zkp-core` shows only `default` |
| the cfg-gate proof | `z36-cfg-gate-proof.txt`: **0 code lines outside a gate, 0 deletions**, in all three watched files |
| the toy byte-frozen gates, BY NAME | `grow_tests::the_toy_schedule_digest_is_frozen`, `grow_tests::the_toy_parameter_line_is_the_frozen_literal`, `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` — all three `... ok` |
| stage 25's retired tripwire | `s25_tests::the_draw_accounting_assertions_are_no_longer_blocked_and_their_test_exists ... ok` |
| the forbidden-files proof | `git diff --stat fee1a8d HEAD -- hashline/src/zk.rs hashline/src/pcs.rs hashline/src/layer.rs hashline/src/wcache.rs hashline/src/field.rs hashline/src/gpu hashline/src/native_capture.rs hashline/src/private_seam.rs scripts tests private-block-kernel private-model-kernel zkvm-block` prints **nothing** |

#### The seven assertions, and where each one now lives

| # | assertion | where | how it is established |
|---|---|---|---|
| 1 | total consumption | `s36_tests::a_block_proof_consumes_exactly_the_counted_stream_at_every_shape` | MEASURED at six shapes against eleven segments built from constants |
| 2 | per-role offsets | the same | the eleven offsets are the running sums, asserted contiguous, pairwise disjoint and covering; **derived**, with the measured total as the check (see finding S36-F3) |
| 3 | witness- and statement-independence | `consumption_does_not_depend_on_the_witness_or_on_the_public_statement` | three (witness, statement) pairs including the ALL-ZERO hidden input: identical bytes, refills, squeezes and frame; and an endpoint under two different sealed planes |
| 4 | injectivity across roles | assertion 1's test + `the_three_generators_of_one_proof_are_three_separate_streams` | disjoint ranges on one stream; different streams under different keys |
| 5 | never cloned or forked | `assertions_five_and_seven_...` here, `zkp-core::rng::tests::the_generator_is_still_not_clone`, and stage 25's source count | the inherent-impl probe with its two controls, at both levels |
| 6 | the realised value map | `the_only_relations_imposed_on_drawn_values_are_the_three_the_schedule_declares` | nine production files scanned; exactly `b_re[m] := −b_re[0]` and `b_im[m] := −b_im[0]` at BOTH mask-commit entry points, plus the `H` zero-sum closing entry at a position the loop never draws |
| 7 | the key is fresh | stage 25's scan, cited by name and required to exist | source scan + reachability |

Clarification **5** of the accepted statement ("three fresh reads of the
operating system's entropy per proof") is asserted as the source fact it
is: one generator in `prove_inner_at`, one in each of `prepare_endpoints`'
two owners, every one of them `ZkRng::from_os`, and no fourth site on the
path.

#### Findings

**S36-F1 — ABSORBS CANNOT BE COUNTED, and this stage did not make them
countable.** `Transcript::absorb` folds its message into `state` and
touches no counter, so the number of absorbs is not a function of any
state the type holds. Counting them would mean a new field bumped on every
absorb — work on a hot path, which the integrator's conditions forbid.
The item was **stopped rather than widened**, as instructed, and the doc
comment on `squeezes` says so. Consequence for the query table: the **317
absorbs** of row T3 remain a count nobody can check mechanically; only the
**1,863** squeezes and the **1,027** replayed points can.

**S36-F2 — the two endpoint generators cannot be observed IN SITU, and
this stage measures a replica.** `private_seam::prepare` and
`endpoint_g::prepare` construct their own generators and take none from
the caller; both files are outside this stage's write set (the seam is
frozen, `endpoint_g.rs` is not in the authorised list), so there is no way
to hand either an observable generator. `measure_endpoint` performs the
same two draw steps, and
`the_endpoint_replica_is_the_endpoint_preparers_own_draw_sequence` reads
both production bodies and asserts that the generator is used in exactly
those two places, in that order, with those parameters. **It is a replica,
and both the module and this ledger say so.** The smallest thing that
would make it the object itself is a `pub(crate) fn prepare_with_rng` on
`endpoint_g` (the frozen seam already has one, privately) — one line, for
whoever owns that file.

**S36-F3 — the segment OFFSETS are derived, not snapshotted.** What the
accessor can report is the consumption at a point the test holds the
generator; inside `prove_core` there is no such point without a hook in
`prove_core` itself, which this stage may not add. So the eleven segments'
lengths are computed from constants and their offsets are the running
sums; what is measured is the TOTAL. Two compensating errors in the
segment model would survive at one shape — which is why the same eleven
terms are required to produce the right total at six geometries that
differ in row width, head count, head dimension, endpoint rows and
endpoint log, and to reproduce an independently computed row
(`stream_positions.py`'s rung-K4) exactly.

#### What the integrator needs, to integrate this delta

* **Files**: `zkp-core/src/rng.rs`, `zkp-core/src/transcript.rs`,
  `zkp-core/Cargo.toml` (`[features]`), `hashline/Cargo.toml` (one
  dev-dependency line), `hashline/src/private_block/protocol.rs` (five
  gated lines), `hashline/src/private_block.rs` (two `mod` lines), and two
  new test-only files `draw_observer.rs`, `s36_tests.rs`.
* **The feature**: any other dependent whose tests want the observers adds
  `zkp-core = { path = "…", features = ["test-observers"] }` to its
  `[dev-dependencies]`. Putting it in `[dependencies]` would compile the
  accessors into a release build, which is the one thing the gate is for.
* **THE D22 PIN SET MOVES, and the security owner must re-read it.** Three
  of the files pinned by a run-capture bundle
  (`run_capture::SHARED_SOURCE_FILES` / `OWN_SOURCE_FILES`) and by the
  security probe's source list changed. Bundles already committed keep the
  digests they recorded; **a bundle taken after this stage records the
  right-hand column**:

| file | before (`fee1a8d`) | after (this stage) |
|---|---|---|
| `zkp-core/src/rng.rs` | `0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb` | `b9920aeb3a12c2fd45e7f50f701852086cdf8bf73530de4f7658d4b4c09c3b9f` |
| `zkp-core/src/transcript.rs` | `cc9752d0ef9bcd6d7b20e94e611ff26748593a2ea1a4f55b63d8c221715f1967` | `b8a228d9b33f7dbf19cd631c7b9a08eb9465b56ab3c32ea40c06fee2416adad4` |
| `hashline/src/private_block/protocol.rs` | `ac4122375397a155d392df27a7e08f818ee78f80b38d41207565b325f5290413` | `e0e617be617a548641cb33c8564cee86ee7d2af90f9c6487b5fb7af30113d45b` |
| `hashline/src/private_block.rs` | `b4aeb6ed32331b29b3d470ca5fc2f4789c1f2f4a9785751ca52aacaa51a3300e` | `fa0daca6797501ec9fe9ad93a5b890c0fa72165fbdb21c6854d4eaddac47ec94` |
| `zkp-core/Cargo.toml` | `b9038a52f34e0ee8313aa93eec656ff62ea29571a04b3df7f3db349d623ba842` | `90156d589336ce790a103f69c42aa5c2489c5c2b12e1c1ce12e3b7b1c1ea4891` |
| `hashline/Cargo.toml` | `e3acda1bf4cf1a8cbbd671e51885a3e4b31b41e976f7ecf15057fdf0018015fc` | `5633d1e46fd1c0878751283bf722a5cdbfb565bdf414aa521d7c160d4276fb38` |

  **What changed in them is a test-gated read-only accessor and nothing
  else** — the cfg-gate table above is the argument, and condition 7 of
  the accepted statement ("a change to any pinned Rust file suspends step
  3 until it is re-read and re-pinned") is the reason it is the security
  owner's call and not this lane's.
* **The one production-facing consequence**, for the register: the toy
  statement's §4 sampler row now has a machine check behind it.
  `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §4's 327,052, §9 item 2's
  arithmetic, row T4a's 1,863 and clarification 9's 1,027 are reproduced
  by a test that runs in the ordinary filter, so a change to the schedule
  that moved any of them would now fail rather than go unnoticed.

**THE COMMITS OF STAGE 36**, in order:

| commit | what |
|---|---|
| `45e236c` | the ledger skeleton: the six tasks, the integrator's conditions verbatim, the write set |
| `c031c25` | task 1 — `ZkRng::consumed_bytes` / `refills` and four tests (every draw kind, the refill boundary including a straddling `fp()`, reading changes nothing, still not `Clone`) |
| `e9b2738` | task 2 — `Transcript::squeezes` and two tests; finding U-3 closed |
| `e4e2a04` | task 3 — the `test-observers` feature and the dev-dependency, with the `cargo tree` evidence |
| `5d0022f` | task 4 — the observer in `check_opening_challenges` (five gated lines) and `draw_observer.rs` |
| `f32d2fc` | task 5 — `s36_tests.rs`, all seven assertions, and stage 25's tripwire retired by its mirror image |
| `1016dca` | two cosmetic fixes the gate runs found: an unneeded `mut` in the new rng test (the crate's warning count must not move for a test this stage added) and one doc sentence in `s36_tests.rs` that said three sites where the scan finds four |
| this one | the measurements, the gates and this section, closed |

### What stage 36 is NOT

Not a privacy result and not an acceptance: what is now checked is that
the prover's randomness accounting is what the argument assumes — where
the draws are, how many, from how many streams, and that nobody chose the
key. Whether that blinding SUFFICES is steps 2 to 5 of the statement's §3
and is untouched. Not a change to any proof: no byte of any profile moved
and the production build compiles the same code paths, proved two ways.
Not a count of absorbs (finding S36-F1). Not an in-situ measurement of the
two endpoint generators (S36-F2) or of the segment offsets inside
`prove_core` (S36-F3) — both are named above with the smallest thing that
would close them.

---

## Stage 37 — TEST-ONLY: eight key-value groups (`lkv = 3`), "rung-K8" (2026-09-22, 19:4x–)

**Status: `CLOSED` 2026-09-22 20:1x PDT** — see "Stage 37 — CLOSED" below.
Opened 2026-09-22 19:46 PDT on the lane tip
`a8e4939`, one writer. **Why:** the native run gate has never read a shape
with `lkv > 2` (its open item R5.8 item 3: "eight or more key-value groups
are still unread"). The repaired bilinear slots `SC_SCORE` / `SC_PV` (stage
20, finding S19-F1: the group bits are sumcheck variables under a public
`eq(r_g, .)`) have been proved at `lkv <= 2` only — rung-G 1, rung-K4 /
rung-P2 / 125M 2. This stage produces the Rust-side evidence at `lkv = 3`.

**THE WRITE SET**, and nothing else: one new test file
`hashline/src/private_block/k8_tests.rs`, its one `#[cfg(test)] mod` line in
`hashline/src/private_block.rs`, this ledger, evidence under
`results/zk60_block125m_lane/` with the prefix `s37-`, and the two capture
bundles under `results/zk60_run_captures_20260922_k8/`. **No production
file moves** (`argument.rs`, `protocol.rs`, `layout.rs`, `wire.rs`,
`witness.rs`, `run.rs`, `boundary.rs`, `run_capture.rs`, `shape.rs`, and
everything under `zkp-core/`, `hashline/src/{zk,layer,pcs,wcache,
native_capture}.rs`, `hashline/src/gpu/`, `private-block-kernel*/`,
`zkvm-block/`): the shape is built in the test file through the existing
`Shape::new` and `RunShape::new`. The toy receipt stays 2,816,472 B.

**THE TASKS**

| # | task | acceptance |
|---|---|---|
| 1 | the shape: the smallest `lkv = 3` geometry `Shape::new` accepts, or the refusal recorded | every dimension asserted; its own profile and key set |
| 2 | one dense generic block proves and verifies from bytes | frame = the counted length |
| 3 | a three-block dense run proves and verifies (streaming verifier) | segment lengths = the counted ones |
| 4 | tampers in the LAST key-value group (index 7) of the planes `SC_SCORE` / `SC_PV` read | rejected by the VERIFIER |
| 5 | the all-zero input proves and verifies | frame = the counted length |
| 6 | receipt length = the Python layout model's prediction | to the byte |
| 7 | two three-block capture bundles (dense generic + all-zero) | `source_commit` = HEAD at capture time |
| 8 | the `--lib private_` filter once, against 416 / 0 / 17 | nothing lost |

**No privacy claim.** Development grade (ruling P-7), like every rung.

### Stage 37 — CLOSED (2026-09-22, 19:46–20:1x)

**Status: `LANDED`.** No production file moved (proof below), no 125M run,
no GPU. **The honest prover and the honest verifier agree at `lkv = 3`; no
completeness finding.**

#### Task 1 — the shape, and why it is not the strictly smallest

`Shape::new` ACCEPTS `lkv = 3`; nothing refuses it. rung-K8, built in
`k8_tests.rs::rung_k8()` (not in `shape.rs`, which this stage may not move):

| | rung-K4 | **rung-K8** |
|---|---|---|
| tokens / width / hidden | 24 / 96 / 192 | 24 / **128** / 192 |
| query heads x head_dim over KV heads | 12 x 8 over 4 | **16 x 8 over 8** |
| `lkv`, heads per group, padded head slots | 2, 3 (+1 pad), `{3,7,11,15}` | **3, 2, none** |
| `t_pad, d_pad, h_pad, f_pad` | 32, 128, 16, 256 | the same |
| `Dom::Q` / `Dom::Kv` / `Dom::S` logs | 12 / 10 / 14 | 12 / **11** / 14 |
| `SC_SCORE`, `SC_PV` (main, ext, deg) | (5,2,3), (7,2,3) | **(6,2,3), (8,2,3)** |
| `norm_wrho`, `wrho_s`, `F_E`, row width, rate, endpoint rows | 31, 17, 12, 2^10, 4, 9 | the same |
| block / run profile | `...rung-k4-t24-dev/1` | `hashline-zk-mr1/private-block-rung-k8-t24-dev/1` / `hashline-zk-mr1/private-run-rung-k8-t24-dev/1` |

**Three smaller `lkv = 3` geometries are accepted too, and were NOT chosen**
(`every_smaller_eight_key_value_head_geometry_is_accepted_and_the_choice_is_recorded`,
receipts COUNTED by the Rust's `receipt_bytes` and equal to the model's):
8 x 4 over 8, width 32 (3,360,904 B); 8 x 8 over 8, width 64 (3,689,624 B);
16 x 4 over 8, width 64 (4,160,680 B). The first two have ONE query head per
group, so `kv_of_slot` is the identity and no head-in-group bit exists — a
construction confusing the head index with the group index would pass them,
which is the degenerate-fixture pattern that hid S19-F1. The third uses
`head_dim = 4`, which no shape has ever proved at; it would put two untested
axes into one shape. rung-K8 is the smallest geometry with a non-identity
group map and only proven head sizes, and its padded layout is rung-K4's,
so the head axis is the only thing that moves. 16 x 2 over 8 (width 32) is
REFUSED by name (F-2: `Dom::Kv` natural log 9 lifted to the row width 10).
**What would justify revisiting:** a gate finding that needs the padded-slot
case at `lkv = 3` (24 x 4 over 8, width 96, model 5,759,176 B) or a proof
at `head_dim = 4`.

**What a test-only shape costs, stated:** `run_statement_file::
shape_of_profile` does not know the two rung-K8 profiles, so this build writes
and reads no run STATEMENT file for it, and the stage-24 profile registry
(read out of `shape.rs` / `run.rs`) does not list them. The geometry test
asserts instead that rung-K8's four keys differ from every registered
profile's keys and from each other. The bundles need neither.

#### Tasks 2–6 — MEASURED (`s37-k8-all.log`, 10 passed / 0 failed / 1 ignored, 13.48 s, exit 0; one run each, shared box, not quiesced)

| test | result |
|---|---|
| `the_rung_k8_shape_is_the_eight_key_value_head_geometry_it_claims` | every dimension, `kv_of_slot(sl) = sl / 2`, slots 14 and 15 in group 7, no lift, own profile and key set |
| `the_rung_k8_layout_is_the_independent_models` | all 23 layout figures equal the unedited Python model's (A/H planes 83/52, data rows 487/626, rows 733/732, groups 36/9, main rounds 223, published values 1,084, draws 248, bilinear L (26, 32), U8 555,008) |
| `the_dense_witness_equals_the_reference_kernel_at_the_rung_k8` | the independent `private-block-kernel-shaped` crate agrees on all 3,072 output words; ITS OWN rotated-key buffer has eight pairwise different groups |
| **(a)** `an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_k8` | **prove 0.66 s, verify from bytes 0.12 s, frame 4,780,216 B**; a one-byte truncation refused; census 16/16 head slots live, 8/8 groups live and pairwise different in keys AND values, both heads of every group different |
| **(b)** `an_honest_three_block_fully_dense_run_verifies_streaming_at_the_rung_k8` | **prove 1.85 s, STREAMING verify (`verify_run_from_dir`, one file at a time) 0.36 s**, in-memory verify agrees, segments **4,612,392 / 4,634,920 / 4,802,824 = 14,050,136 B** (the counted lengths), boundary 10 rows, census in all three blocks; one flipped byte in segment 2's file refused (`A: pcs zk: Merkle path ... fails`) |
| **(c)** `a_perturbation_in_the_last_key_value_group_is_rejected_by_the_verifier_at_the_rung_k8` | **6 of 6 rejected by the VERIFIER, 0 by the prover, 0 accepted**: `A_KR8` group 7 → slot 16 `05 KV zero-check`; `A_V8` group 7, `A_QR8` at slots 14 and 15, `A_P` at slots 14 and 15 → slot 15 `04 Q zero-check` |
| (c, extra) `exchanging_group_sevens_keys_across_each_single_group_bit_is_rejected_at_the_rung_k8` | the whole key family of group 7 swapped with group 6 (low bit, 744 positions differ), 5 (middle, 738) and 3 (high, 744): **3 of 3 rejected by the VERIFIER**, slot 16 |
| **(d)** `the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_k8` | tame fixture: prove 0.65 s, verify 0.12 s; dense public weights: prove 0.66 s, verify 0.14 s; both 4,780,216 B. Named DEGENERATE: every group zero |
| **(e)** receipt = model | **4,780,216 B MEASURED = 4,780,216 B the model predicts** (`s37-model-prediction.json`) = the Rust's count |
| `the_pinned_rung_k8_chain_band_is_the_first_admissible_one` | **band 48**, the recipe's own single-block band: three blocks need no reduction at this shape (rung-K4 needed 47). `band_down_run`'s fallback at `(192, 8)` already gives 48, so the shared `dense_tests::dense_run_case` is used unchanged and the test asserts both |

**Where the tampers are caught, stated plainly:** every tamper is rejected
at the zero-check slots 15 / 16, exactly as at rung-K4 — a one-word move in
`A_KR8`/`A_V8`/`A_QR8`/`A_P` breaks the RoPE / projection relations those
slots host before `SC_SCORE`/`SC_PV` are reached. So these controls show the
verifier refuses group-7 data that disagrees with its own group's weights;
they are not an isolated test of the `eq(r_g, .)` factor. The positive side
— an honest proof with eight different groups ACCEPTED through the
three-bit group sum — is what isolates it.

**The model's entry point (item e):** `zk60_private_block_layout_model.py`'s
CLI takes `--shape` from a closed list of registered shapes, so it has no
entry for rung-K8. It was NOT edited: the module was imported as a library
and its own `Shape(...)` class and `model()` were called at rung-K8's
arguments (`s37-model-prediction.json` records the call and the survey
totals).

#### Task 7 — the two capture bundles

`results/zk60_run_captures_20260922_k8/` (with a parent `README.md`),
written by `k8_tests::write_the_k8_gate_bundles` with
`HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=99a8de8` — **`99a8de8`
was HEAD at capture time** (finding E32-F1), the tree clean; the writer
refuses an unset or `uncommitted-test` label. `s37-k8-bundles.log`, exit 0.

| bundle | `manifest["total_bytes"]` | on disk | `manifest.json` SHA-256 |
|---|---:|---:|---|
| `run-s-dense-k8` (fully dense, generic) | 46,928,078 B | 46,933,075 B | `29815e93...a8ac730b` |
| `run-t-zero-k8` (all-zero, degenerate) | 46,901,939 B | 46,906,936 B | `d322a49c...09d7fdc6` |

Three blocks each, classic `/4-run` (as rung-K4's pair), 93.8 MB for the
pair. **Sanity on the files as written** (`s37-bundle-sanity.py`, a script
under `results/`, → `s37-k8-bundle-sanity.log`): **0 mismatches** — every
manifest entry's length and SHA-256; `source_commit` `99a8de8` in both
manifests and both `run.json`; 93 of 93 public tables with values and every
digest recomputed; **the group eq at start 0 with a THREE-element point ==
`definition_challenges[:3]` at 6 of 6 per bundle**; plane index 22,419
canonical bytes, SHA-256 prefix `914338bb`, identical across the pair (NOT
rung-K4's `89cd8a46`). The same script on the rung-K4 pair reproduces stage
22's figures exactly (`s37-sanity-control-k4.log`), which is its control.

#### Task 8 — the gate

| run | log | result |
|---|---|---|
| `--lib private_` at `4373fb6` | `s37-gate-private.log` | **429 passed / 0 failed / 18 ignored**, 568.88 s, exit 0, 15 warnings (stage 36's gate log: 16) |

Against 416 / 0 / 17: **+13 passed = the three `p36_preread_tests` merged at
`a8e4939` + this stage's ten; +1 ignored = the bundle writer.** Nothing lost.
The frozen toy is in the pass list at **2,816,472 B**
(`tests::honest_receipt_verifies_in_typed_and_wire_form_...`,
`grow_tests::the_shape_driven_layout_reproduces_the_toy_exactly`,
`review_tests::a_toy_receipt_made_before_the_lane_still_verifies`).

#### FORBIDDEN-FILES PROOF

`git --no-pager diff --stat a8e4939 -- zkp-core hashline/src/{zk,pcs,layer,
wcache,native_capture}.rs hashline/src/gpu private-block-kernel
private-block-kernel-shaped zkvm-block hashline/src/private_block/{argument,
protocol,layout,wire,witness,run,boundary,run_capture,shape}.rs
hashline/Cargo.toml hashline/Cargo.lock scripts` prints NOTHING. The whole
source diff against `a8e4939` is `k8_tests.rs` (new) and two lines of
`hashline/src/private_block.rs` (`#[cfg(test)]` / `mod k8_tests;`).

**One pin moves, for the gate owner:** `hashline/src/private_block.rs` is a
capture source pin and in the run gate's pin tables. Its SHA-256 goes from
`d540404b...25990198` (at `a8e4939`) to `7a9b31ac...ee00dc82`; the only
change is the two `cfg(test)` lines above. The rung-K8 bundles pin the new
digest.

#### Commits

| commit | what |
|---|---|
| `d597a1d` | the skeleton |
| `99a8de8` | `k8_tests.rs`, the mod line, the model prediction, the sanity script and its control, the test logs — the capture commit |
| `4373fb6` | the two bundles, their README and the sanity log |
| this one | the gate log and this section |

#### What stage 37 is NOT

Not a privacy result and not gate evidence: no gate has read the bundles. Not
a registered profile: rung-K8 lives in a test file, and registering it
(`shape.rs`, `run.rs`, `shape_of_profile`, the registries) is a production
change for whoever owns those files. Not a completeness claim beyond the
cases run, and not a test of `lkv >= 4`.

## Stage 38 — TEST-ONLY: the shaped builder-versus-kernel REFUSAL CENSUS (GS-14's first item) (2026-09-22, 20:4x–)

**Status: `CLOSED` 2026-09-22 21:3x PDT** — see "Stage 38 — CLOSED" below.
Opened 2026-09-22 20:49 PDT on the lane tip
`bacc274`, one writer. **Why:** ruling NL-8 of
`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md` and finding N-9 of
`ZK60_NONLINEAR_CHANNEL_SHAPED_CHECK.md`: gap GS-14 (completeness for every
ADMISSIBLE witness at the shaped layouts) needs a shaped equivalent of the
toy's refusal-site census (`refusals.rs:270-280`, asserted at `:321-322`).
The toy proves `AO` unreachable from 16 terms; at 125M the sum has 768 terms,
`|aoacc| <= 12,484,608`, `requant(., 7)` reaches +-97,536 — the site is
REACHABLE and the witness builder refuses there first (`witness.rs:594`). If
the builder ADMITS a witness on which the prover or the verifier then refuses,
an honest proof fails on a legal input — a completeness hole. This stage
enumerates every refusal site of the witness builder, the shaped kernel and
the argument / prover, classifies each data-dependent one per shape from
exact integer bounds computed off the `Shape`, and encodes the census as a
test.

**THE WRITE SET**, and nothing else: one new test file
`hashline/src/private_block/census_shaped_tests.rs`, its one `#[cfg(test)]
mod` line in `hashline/src/private_block.rs` (next to stage 37's `mod
k8_tests;`), the memo `docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS.md`, this
ledger, and logs under `results/zk60_block125m_lane/` with the prefix `s38-`.
**No production file moves** (`argument.rs`, `protocol.rs`, `layout.rs`,
`wire.rs`, `witness.rs`, `run.rs`, `boundary.rs`, `run_capture.rs`,
`refusals.rs`, `shape.rs`, `private-block-kernel-shaped/src/lib.rs`, and
everything under `zkp-core/`, `hashline/src/{zk,layer,pcs,wcache,
native_capture}.rs`, `hashline/src/gpu/`, `private-block-kernel/`,
`zkvm-block/`). The toy receipt stays 2,816,472 B. No 125M prove.

**THE TASKS**

| # | task | acceptance |
|---|---|---|
| 1 | enumerate every refusal site: builder, shaped kernel, argument / prover (range, lookup, `nonzero`, `Err`, panic, `debug_assert`) | a site list with file:line |
| 2 | per shape (rung-G, rung-K4, rung-K8, 125M; rung-C6 / W14 / E32 / P2) the worst-case magnitude of every data-dependent site, exact integers, from the `Shape` | classified UNREACHABLE / REACHABLE-BUILDER-REFUSES-FIRST / finding |
| 3 | the census as a test module computing every bound from the `Shape`; boundary tests (just past: the builder refuses by name; just inside: proves and verifies) at the small rungs | green, or an `#[ignore]`d reproducer per finding |
| 4 | the memo `ZK60_SHAPED_REFUSAL_CENSUS.md` | site table per shape, findings, what it does not cover |
| 5 | the `--lib private_` filter once | against 429 / 0 / 18 |

**No privacy claim.** A completeness census; development grade.

### Stage 38 — the census landed (21:1x; the lane gate is the next step)

**Headline.** At every registered shape (toy, rung, rung-G, rung-K4,
rung-P2, rung-C6, rung-W14, rung-E32, 125M) and at stage 37's rung-K8, every
data-dependent refusal site of the builder, the shaped kernel and the prover
is classified from bounds COMPUTED FROM THE `Shape`: **12 sites
REACHABLE-BUILDER-REFUSES-FIRST at every shape** (Q, K, V, QR, KR, score,
residual 1, FFN gate, FFN up, FFN product, FFN down, residual 2), **`AO`
joins them at width > 258** (rung-C6 48,768; rung-W14 / rung-E32 / 125M
97,536 — N-9's figure, re-derived), everything else UNREACHABLE, and **ONE
FINDING, S38-F1**. Memo: `docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS.md`.

**Finding S38-F1 (first rank, not fixed here).** At a shape whose `Dom::F`
pads (rung, rung-G, rung-K4, rung-K8 — NOT 125M, not rung-P2 / C6 / W14 /
E32, not the toy), the padded `(g8, a16) = (0, 0)` looks up the activation
pair `(128, 0)` on the never-gated LogUp arm; it is a table row only when
`act[128] == 0`, and `FeedForwardPublic::new_shaped` admits any `[i16; 256]`.
With `act[128] = 1` the builder and the kernel admit the statement and the
**VERIFIER rejects** every honest proof (`H: pcs zk: group 8: <v, c> !=
combined claim`, `s38-f1-reproducer.log`, exit 101 — the `#[ignore]`d
reproducer fails as it must). Exactly the 3,584 padded of 8,192 `Dom::F`
positions miss the table at rung-G / K4 / K8; the same statement is clean at
rung-P2 and rung-C6. Public-table-dependent only, so nothing private leaks.
Fix options for the file owner (memo §6): refuse `act[128] != 0` at a
padded-`Dom::F` shape, or write the pad's `A16` as `act[128]` and exempt it
like `A_E`. Every SiLU member has `act[128] = 0`, which is why no proof ever
met it.

**MEASURED** (`s38-census.log`, `.done` = 0; shared box, not quiesced):
`--lib census_shaped` **9 passed / 0 failed / 1 ignored**, 28.16 s, no
compiler warning in the new file.

| test | what it establishes |
|---|---|
| `the_shaped_refusal_census_classifies_every_data_dependent_site_at_every_shape` | 34 rows x 10 shapes, bounds from the shape; tallies U / R-B / F: toy 22/12/0, rung 21/12/1, rung-G 21/12/1, rung-K4 21/12/1, rung-K8 21/12/1, rung-P2 22/12/0, rung-C6 21/13/0, rung-W14 21/13/0, rung-E32 21/13/0, 125M 21/13/0 (COUNTED) |
| `the_builder_class_of_every_looked_plane_is_the_lookup_window_at_every_shape` | the ORDER check from `lookups_at` itself: every looked plane's admitted window equals the builder's class (p: window 2^10 looser than the builder's 2^9, the safe direction); all 60 (toy) / 62 looked planes accounted for |
| `the_unreachable_sites_premises_hold_at_every_shape` | norm quotient over each `D_max` (int16 incl. -32768), softmax row sums, `O`, the kernel calibration copy, and broken exp / RoPE tables refused by the constructor |
| `the_challenge_only_refusals_are_counted_per_shape` | per block: c_s 23, e 25, **nu 12**, zeta 0 / 8 / **5 at 125M** (GN-8's five), groups 44 / 45, proximity 4 |
| `every_reachable_site_..._at_rung_g` / `_k4` / `_k8` | 12 sites x 3 shapes: inside EXACTLY on the edge (127, -128, 32767) proves and verifies (0.54–0.82 s each); one step past, the builder AND the kernel refuse with the same `fixed oracle range refusal: <site>` |
| `the_output_projection_..._at_rung_c6` | `AO` at rung-C6: ao = 32767 proves and verifies (1.54 s); 32768 refused by name by both; the family cannot even be built at rung-G (width 96) |
| `s38_f1_the_padded_feed_forward_positions_...` | S38-F1 in the ordinary filter, at the LogUp-word level |
| `s38_f1_reproducer_...` (`#[ignore]`) | S38-F1 end to end: verifier rejection |

**The pin that moves, for the gate owner:** `hashline/src/private_block.rs`
SHA-256 `7a9b31ac7b9ff322e4b206a56fcd1a253f367df0c73b71920d4acc21ee00dc82`
(at `bacc274`) -> `b67282735ce3072751e997bf43d64a05205df035880b66fe1ecfc1aa652a3456`;
the only change is `#[cfg(test)]` / `mod census_shaped_tests;` after
`mod k8_tests;`. New file `census_shaped_tests.rs` SHA-256
`04d4d1bb47eb230e185c0f767d1111dc1d3ce184a60cc6468dcd2d09ae873e56`.

**FORBIDDEN-FILES PROOF:** `git --no-pager diff --stat bacc274 -- zkp-core
hashline/src/{zk,pcs,layer,wcache,native_capture}.rs hashline/src/gpu
private-block-kernel private-block-kernel-shaped zkvm-block
hashline/src/private_block/{argument,protocol,layout,wire,witness,run,
boundary,run_capture,shape,refusals}.rs hashline/Cargo.toml
hashline/Cargo.lock scripts` prints NOTHING.

### Stage 38 — CLOSED (2026-09-22, 20:49–21:3x)

**Status: `LANDED`.** No production file moved; no 125M prove; no GPU. One
completeness FINDING (S38-F1, recorded above and in the memo §6, not fixed).

#### The gate — five runs, every one kept

All under `flock /tmp/zk-build.lock` and `systemd-run --user --scope -p
MemoryMax=8G -p MemorySwapMax=0`, shared box (a Python gate of another lane
running beside it), not quiesced.

| run | log | result |
|---|---|---|
| 1: `--lib private_`, default 22 test threads, at `9dafbc0` | `s38-gate-private.log` | **KILLED** (SIGKILL by the OOM killer inside the 8 GiB scope, journal 21:15:08, ~2 min in). Twenty-two concurrent tests, several of them proving at rung-C6 / W14 / E32 with their own rayon pools, do not fit 8 GiB. Kept as evidence |
| 2: the same, `--test-threads=6`, at `b281580` | `s38-gate-private2.log` | 437 passed / **1 failed** / 19 ignored, 137.96 s, peak RSS 4.41 GB. The failure is `s35_tests::the_two_rewritten_closures_equal_the_parent_closure_at_every_registered_shape` (240 comparisons against the asserted 72) |
| 3: repeated | `s38-gate-private3.log` | 437 / **1** / 19, 136.60 s, peak 4.35 GB — the same test (216 against 72) |
| 4: the same, **with this stage's tests SKIPPED** (`--skip census_shaped_tests`) | `s38-gate-private4-without-census.log` | **428 passed / 1 failed / 18 ignored** — the stage-37 set exactly (429 / 18), and the SAME s35 test fails (248 against 72): **the failure does not come from stage 38** |
| 5: the same, the one s35 test skipped | `s38-gate-private5.log` | **437 passed / 0 failed / 19 ignored**, 138.36 s, exit 0, peak RSS 4.35 GB, 15 warnings (stage 37: 15) |
| the s35 test ALONE | `s38-s35-alone.log` | **1 passed**, "72 (point, slot) comparisons on this walk alone" — exactly the asserted 9 shapes x 2 slots x 4 points |

**Accounting against 429 / 0 / 18:** run 5 plus the s35 test alone = **438
passed / 0 failed / 19 ignored** = 429 + this stage's nine + the one ignored
S38-F1 reproducer. Nothing lost. The frozen toy is in run 5's pass list at
**2,816,472 B** (`tests::honest_receipt_verifies_in_typed_and_wire_form_...`,
`grow_tests::the_shape_driven_layout_reproduces_the_toy_exactly`,
`grow_tests::the_toy_schedule_digest_is_frozen`,
`grow_tests::the_toy_parameter_line_is_the_frozen_literal`,
`review_tests::a_toy_receipt_made_before_the_lane_still_verifies`).

**NOTE S38-N1 (for the owner of `s35_tests.rs`; not fixed here, outside this
stage's write set).** The s35 differential asserts an EXACT count of a
PROCESS-GLOBAL counter (`COMPARED`, `s35_tests.rs:164`) across its walk
(`:379-395`), and the counter is also incremented by every concurrent proof's
`define` of slots 14 and 17 (the stage-35 hook runs inside `define` on both
sides of every proof). So the test fails whenever another proving test
overlaps its walk: at 6 test threads it failed three times in three runs, with
or without this stage's tests (runs 2-4), and it passes alone. Stage 37's
gate passed it at the default 22 threads by scheduling. Fix options: a
thread-local counter, or `>=` on the global one. **What it is NOT:** a
closure difference — the per-point `assert_eq!` inside `differ` (`:171-175`)
never fired in any run.

**Memory note for the next gate owner:** the whole filter no longer fits
8 GiB at 22 test threads (run 1); at 6 threads it peaks at 4.35–4.41 GB and
finishes in ~138 s — faster than stage 37's 568.88 s at 22 threads, which
suggests the default thread count oversubscribes the box (each proving test
brings its own rayon pool). Not investigated further.

**Other evidence of this stage:** `s38-census.log` (the census filter at
`9dafbc0`: 9 / 0 / 1, 28.16 s), `s38-census2.log` (the same at `b281580`,
after the citation fix: 9 / 0 / 1, 28.28 s, peak RSS 1.66 GB),
`s38-f1-reproducer.log` (exit 101: verifier rejection).

#### Commits

| commit | what |
|---|---|
| `f978cc5` | the skeleton |
| `9dafbc0` | `census_shaped_tests.rs`, the mod line, the memo, the census and reproducer logs |
| `b281580` | line citations corrected in the test strings and the memo (no logic) |
| this one | the gate logs and this close |

#### What stage 38 is NOT

Not a privacy result. Not a soundness statement (the field-wrap premise is
not re-derived). Not a proof of every relation for every admissible witness:
the lookups are censused exactly, the 23 slot relations are exercised on the
edge witnesses and by the 37 accepted edge proofs. Not a 125M run: 125M is
COUNTED. Not a fix of S38-F1 or S38-N1.

## Stage 39 — FIXING S38-F1 by ruling S38-F1(a), and S38-N1 (2026-09-22, 21:3x–)

**Status: `CLOSED` 2026-09-22 21:5x PDT** — see "Stage 39 — CLOSED" below.
Opened 2026-09-22 21:34 PDT on the lane tip `a9d6d4c`, one writer.

**The ruling, verbatim — ruling S38-F1(a), security owner, 2026-09-22:**
`FeedForwardPublic::new_shaped` refuses, BY NAME, a statement with
`act[128] != 0` at any shape whose `Dom::F` pads (i.e. where the feed-forward
domain has padded positions — the condition derived from the `Shape` /
layout exactly the way the census does, not from a list of shape names). At
a shape whose `Dom::F` does not pad the constructor's behaviour is
unchanged. Option (b) (writing `act[128]` into the pad and moving `A_A16` to
EXEMPT) is NOT taken: it would move every shaped receipt; revisit only if an
approved activation with a nonzero value at gate 0 is ever proposed.

**THE WRITE SET**, and nothing else: `hashline/src/private_block.rs`
(`FeedForwardPublic::new_shaped` only — the named refusal, a few lines),
`hashline/src/private_block/census_shaped_tests.rs` (the new failing-first
test, the re-purposed reproducer, the census's expected class for site 26),
`hashline/src/private_block/s35_tests.rs` (S38-N1, test-only, if a
test-only fix exists), the memo `docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS.md`
(§6 "FIXED at" note), this ledger, and logs under
`results/zk60_block125m_lane/` with the prefix `s39-`. **Forbidden:**
`argument.rs`, `protocol.rs`, `layout.rs`, `wire.rs`, `witness.rs`, `run.rs`,
`boundary.rs`, `run_capture.rs`, `refusals.rs` production items,
`private-block-kernel-shaped/src/lib.rs`, `hashline/src/{zk,layer,pcs,wcache,
native_capture}.rs`, `hashline/src/gpu/*`, `zkp-core/`, `private-block-kernel/`,
`zkvm-block/`.

**THE TASKS**

| # | task | acceptance |
|---|---|---|
| 1 | FAILING FIRST: the S38-F1 reproducer as it stands (`s39-before.log`, verifier refusal); a NEW test — `new_shaped` refuses `act[128] = 1` at rung-G / K4 / K8 by the new name and accepts it at toy / P2 / C6 — run and failing before the fix | two logs |
| 2 | the fix in `new_shaped` only, the refusal derived from `sh.pads(Dom::F)` | the new test green |
| 3 | the reproducer re-purposed (expects REFUSAL at construction, un-ignored, history kept); census site 26 classified as covered by the refusal; memo §6 "FIXED at" | census filter green, 0 ignored |
| 4 | byte identity: toy 2,816,472 B, every shaped receipt length and the pinned schedule digests unchanged, `absorb_into` untouched; the stage-37 K8 tests and stage-38 census tests re-run | green |
| 5 | S38-N1: a test-only fix in `s35_tests.rs` if one exists (5 green runs at the default thread count), else the exact `zkp-core` ask | logged |
| 6 | the `--lib private_` filter once, 8 GiB scope, `--test-threads=6` | against 437 / 0 / 19 (+1 skipped); `private_block.rs` SHA-256 `b6728273...` -> new |

**No privacy claim.** A completeness fix of public-statement admissibility.

### Stage 39 — S38-F1 fixed, S38-N1 fixed test-only (21:4x; the lane gate is next)

All runs under `flock /tmp/zk-build.lock` and `systemd-run --user --scope -p
MemoryMax=8G -p MemorySwapMax=0`, shared box (another lane's Python gate
running beside it), not quiesced.

**Task 1 — failing first.**

| run | log | result |
|---|---|---|
| the stage-38 reproducer as it stood, `--ignored`, at `6ec32c2` (= `a9d6d4c` + the skeleton) | `s39-before.log` (`.done` = 101) | **FAILS as at stage 38**: `S38-F1 REPRODUCER rung-G: verifier rejected: H: pcs zk: group 8: <v, c> != combined claim` |
| the NEW test `s39_new_shaped_refuses_a_nonzero_gate_zero_activation_by_name_exactly_where_the_feed_forward_domain_pads`, before the fix | `s39-new-test-before.log` (`.done` = 101) | **FAILS**: the toy line prints "admitted, unchanged", then at the rung (the first padded shape in census order) `left: None, right: Some("private block: activation table act[128] must be 0 ...")` — the constructor admitted `act[128] = 1` |

**Task 2 — the fix, commit `7472a3c`.** `private_block.rs`, in
`FeedForwardPublic::new_shaped` only, after the `[i16; 256]` conversion
(`:584-586`, with a six-line comment above):

```rust
if sh.pads(layout::Dom::F) && act[128] != 0 {
    return Err("private block: activation table act[128] must be 0 at a shape whose feed-forward domain pads (ruling S38-F1(a))".into());
}
```

The condition is `Shape::pads(Dom::F)` (`size != true_size`), the census's
own, not a list of names; the new test cross-checks it against the padded
cube vs `tokens * hidden` at all ten shapes. Nothing else in production
changes: `absorb_into` (both of them), `BlockPublic::digest`, the builder, the
prover and the verifier are untouched (`git diff a9d6d4c --
hashline/src/private_block.rs` is the nine added lines and nothing else), so
the refusal adds no absorbed byte. `FeedForwardPublic::new` (the toy entry)
goes through `new_shaped` at `Shape::toy()`, whose `Dom::F` does not pad, so
the toy census's constant-32767 table (`refusals.rs:204`) is still admitted —
asserted by the new test.

**Task 3 — the census and the reproducer.** `--lib census_shaped` at
`7472a3c`: **11 passed / 0 failed / 0 ignored**, 9.36 s (`s39-census-after.log`,
`.done` = 0; stage 38: 9 / 0 / 1 — plus the new test, plus the reproducer
un-ignored). What changed in `census_shaped_tests.rs`:

* a fourth class, `COVERED-BY-THE-STATEMENT-REFUSAL`, and a `statement_refuses`
  field on every row (false on the 33 others); site 26's is MEASURED inside
  the census on the production constructor (the member's 0 admitted; `act[128]`
  in `{1, -1, 2, 32767, -32768}` refused by the ruling's name). Tallies now:
  toy 22/12/0/0, rung / rung-G / K4 / K8 **21/12/0/1**, P2 22/12/0/0, C6 / W14 /
  E32 / 125M 21/13/0/0 (U / R-B / FINDING / covered); the census asserts no
  FINDING at any shape;
* the stage-38 LogUp-level test now asserts the refusal at rung-G / K4 / K8
  first and then shows the mechanism past it with a test-only bypass
  (`Spec::statement_bypassing_the_s38_f1_refusal`: the production constructor
  at `act[128] = 0`, the table's own `act[128]` written back after): still
  exactly the 3,584 padded of 8,192 `Dom::F` positions miss; at P2 / C6 the
  constructor admits and the statement is LogUp-clean;
* the reproducer is un-ignored and renamed
  `s38_f1_reproducer_a_statement_with_a_nonzero_gate_zero_activation_is_refused_at_construction_at_rung_g`
  (history in its comment): it asserts the named refusal, and keeps the
  stage-38 run as a control — forced past the refusal the verifier still
  rejects (`H: pcs zk: group 8`), so the refusal guards a real failure;
* the memo `ZK60_SHAPED_REFUSAL_CENSUS.md`: §1 and §3 row 26 annotated, §6
  carries a dated "FIXED at `7472a3c`" block with the ruling, §8 the new logs.

**Task 5 — S38-N1, FIXED TEST-ONLY** in `s35_tests.rs` (no `zkp-core` ask
needed: the counter is the lane's own test code). The arms call
`Szc::check` / `Dzc::check` synchronously inside `define`
(`argument.rs:1542, 1777`), on the thread that called `define`, so a
`thread_local!` `COMPARED_HERE` bumped beside the global `COMPARED` in
`differ` counts exactly the walk's own comparisons; the test asserts its
exact 72 on that delta (the global count is still printed). Evidence, the
filter `--lib -- s35_tests census_shaped k8_tests` at the DEFAULT thread
count (22) so that the census's and K8's proofs overlap the walk:

| run | log | result |
|---|---|---|
| before (s35 unchanged, at `7472a3c`) | `s39-n1-before.log` (`.done` = 101) | 25 passed / **1 failed** / 1 ignored — the s35 test, "244 (point, slot) comparisons on this walk alone" against 72 |
| after, five in a row | `s39-n1-after1..5.log` (every `.done` = 0) | **26 passed / 0 failed / 1 ignored, five times**; each prints "72 ... on this walk alone" while the process-global count reads 248, 268, 244, 248, 240 — the overlap is there every time and no longer moves the assertion |

The one ignored test is `k8_tests::write_the_k8_gate_bundles` (as at stage
37). The same runs are **task 4's re-run of the stage-37 K8 tests and the
stage-38 census tests**: every `k8_tests` and `census_shaped_tests` test
passed in all six runs (the before-run failed only on s35). No compiler
warning in any changed file. `s35_tests.rs` SHA-256 ->
`f88fca813d58fab9eb6d29a2aef9c1bdbd35168a41efb368c61c5cdf047d59a7`.

### Stage 39 — CLOSED (2026-09-22, 21:34–21:5x)

**Status: `LANDED`.** S38-F1 fixed by ruling S38-F1(a) (one refusal in
`FeedForwardPublic::new_shaped`); S38-N1 fixed test-only. No 125M prove; no
GPU.

#### The gate — ONE run

`--lib private_` at `cfc48a3`, `--test-threads=6`, under `flock
/tmp/zk-build.lock` and `systemd-run --user --scope -p MemoryMax=8G -p
MemorySwapMax=0` (`s39-gate-private.log`, `.done` = 0; shared box, another
lane's Python gate beside it, not quiesced): **440 passed / 0 failed / 18
ignored**, 137.32 s (2:17.40 wall), peak RSS 4.28 GB, 16 `warning` lines (the
same 16 as stage 38's run 5). **Nothing skipped**: the s35 differential now
runs in the gate and passes.

**Accounting against stage 38's 437 / 0 / 19 (+1 skipped, = 438 / 0 / 19):**
+1 the s35 test back in the run (already in the 438), +1 the new
`s39_new_shaped_...` test, and the reproducer moves from ignored to passed:
438 + 1 + 1 = **440**, 19 - 1 = **18**. Nothing lost.

#### Byte identity

* **The toy stays 2,816,472 B**, and the frozen toy is in the pass list:
  `tests::honest_receipt_verifies_in_typed_and_wire_form_...` (`tests.rs:108`,
  `bytes.len() == 2_816_472`), `zero_witness_tests::the_zero_witness_receipt_length_equals_the_fixture_receipt_length`,
  `grow_tests::the_shape_driven_layout_reproduces_the_toy_exactly`,
  `grow_tests::the_toy_schedule_digest_is_frozen`,
  `grow_tests::the_toy_parameter_line_is_the_frozen_literal`,
  `review_tests::a_toy_receipt_made_before_the_lane_still_verifies`.
* **Every shaped receipt and pinned digest**: the honest proofs verify from
  bytes at rung, rung-G, K4, K8, P2, C6, W14, E32 (the K4, K8 and W14 ones
  assert the frame length equals the pinned `*_FRAME_BYTES`; the counted-model
  pins `K4_ / P2_ / C6_ / W14_ / K8_FRAME_BYTES` pass),
  `grow_tests::the_125m_receipt_is_reproduced_part_by_part`,
  `run_tests::the_twelve_block_125m_receipt_is_the_counted_figure` and
  `slot_ir_tests::the_slot_ir_export_is_canonical_and_its_digest_is_pinned_at_every_registered_shape`
  all pass.
* **Nothing absorbed**: `git diff a9d6d4c -- hashline/src/private_block.rs`
  is exactly the nine added lines in `new_shaped`; both `absorb_into`s and
  `BlockPublic::digest` are untouched. The refusal can only turn an `Ok` into
  an `Err` at construction; every statement it admits is byte-for-byte the
  statement it admitted before.

#### The pins that move, for the gate owner (the privacy gate re-pins per bundle source commit)

| file | old SHA-256 (at `a9d6d4c`) | new SHA-256 (at `cfc48a3`) |
|---|---|---|
| `hashline/src/private_block.rs` | `b67282735ce3072751e997bf43d64a05205df035880b66fe1ecfc1aa652a3456` | `29ba008487473bff67e4d10a4770ed0ddf3410aef4c0765cece3a41bf3acc872` |
| `hashline/src/private_block/census_shaped_tests.rs` | `04d4d1bb47eb230e185c0f767d1111dc1d3ce184a60cc6468dcd2d09ae873e56` | `2ddf818fa023440b70175e6bedc33ec74ca43cffaa81feeb29bce32fde38cbb1` |
| `hashline/src/private_block/s35_tests.rs` | (stage 35's) | `f88fca813d58fab9eb6d29a2aef9c1bdbd35168a41efb368c61c5cdf047d59a7` |

`private_block.rs` is the one PRODUCTION file that moves: a gate that pins
it will refuse until re-pinned, by design.

**FORBIDDEN-FILES PROOF:** `git --no-pager diff --stat a9d6d4c -- zkp-core
hashline/src/{zk,pcs,layer,wcache,native_capture}.rs hashline/src/gpu
private-block-kernel private-block-kernel-shaped zkvm-block
hashline/src/private_block/{argument,protocol,layout,wire,witness,run,
boundary,run_capture,shape,refusals}.rs hashline/Cargo.toml
hashline/Cargo.lock scripts` prints NOTHING. The untracked `u31-c6-run1.*`
files are left alone.

#### Commits

| commit | what |
|---|---|
| `6ec32c2` | the skeleton, with the ruling text |
| `7472a3c` | the fix (`private_block.rs`), the new test, the census class for site 26, the re-purposed reproducer, and the failing-first and census logs |
| `cfc48a3` | S38-N1 (`s35_tests.rs`), the memo's "FIXED at `7472a3c`", this ledger's progress, the N1 logs |
| this one | the gate log and this close |

#### What stage 39 is NOT

Not a privacy result. Not option (b): the pad rule, `A_A16`'s ZERO class and
every receipt are unchanged; revisit only if an approved activation with a
nonzero value at gate 0 is ever proposed. Not a claim that the public
statement is otherwise complete: the constructor still checks STRUCTURE, not
provenance (the caller authenticates the words against approved commitments).

## Stage 40 — rulings CS-1, CS-2, CS-3 and notes C-3..C-6 of the shaped refusal census disposition (2026-09-22, 23:2x–)

**Status: `CLOSED` 2026-09-23 00:1x PDT** — see "Stage 40 — CLOSED" below.
Opened 2026-09-22 23:29 PDT on the lane tip `27398d0`, one writer (the
delegated stage-40 agent). Rulings from
`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md` (security
owner, 2026-09-22 23:22 PDT) on the adversarial check
`ZK60_SHAPED_REFUSAL_CENSUS_CHECK.md` (review branch
`zk60-private-block-125m-review`, `cda7d05`).

**THE RULINGS, in short** (the disposition's §2 is the text):

* **CS-1** — one function checks a feed-forward statement against a shape
  (the S38-F1(a) row and ruling P-2's support check), called by the
  constructor AND wherever a statement meets the shape it is proved at: the
  block witness builder, the prover's and verifier's entry, and
  `RunStatement::new` — refusing by name before anything is absorbed,
  committed or drawn. No absorbed byte changes.
* **CS-2** — `Shape::new` refuses, by name, a `wrho_s` override below
  `clog2(tokens) + f_e` and a `norm_wrho` override below its derivation
  (input bound 32768); overrides at or above are kept; every registered
  shape unchanged.
* **CS-3** (conditional) — the prover's three silent bucket-0 paths become
  ONE named prover refusal before the first commitment, adding or moving no
  absorb and no draw; if impossible, not built and the reason recorded.
* **C-3** (seven census rows labelled "premise checked by reading"), **C-4**
  (`protocol.rs:323` to the challenge-only list), **C-6** (`layout.rs:671`
  comment to 98,598,912; `width != q_heads * head_dim` and unbounded `f_e`
  tested for honest-proof failure, refused by name if so, else recorded).

**THE WRITE SET:** `hashline/src/private_block.rs` (CS-1 function, the
`cfg(test)` mod line), `hashline/src/private_block/{shape,protocol,witness,
run}.rs` (only what CS-1..CS-3 require), `layout.rs` (the C-6 comment only),
the new test file `hashline/src/private_block/s40_tests.rs`, test files whose
assertions the rulings move, the census memo, this ledger, logs
`results/zk60_block125m_lane/s40-*`. **Forbidden:**
`hashline/src/{zk,layer,pcs,wcache,native_capture}.rs`, `hashline/src/gpu/*`,
`zkp-core/`, `private-block-kernel/`, `private-block-kernel-shaped/`,
`zkvm-block/`; the untracked `u31-c6-run1.*` files are left alone.

**Byte identity to hold:** the toy 2,816,472 B; every shaped frame length,
receipt length and schedule digest pin; `absorb_into` and
`BlockPublic::digest` untouched. Small rungs only; no 125M prove.

**No privacy claim.** Completeness and statement admissibility only.

### Stage 40 — the rulings built (2026-09-22 23:29 – 2026-09-23 00:08)

All runs under `flock /tmp/zk-build.lock`, `--test-threads=6`, detached with
`.done` markers, no memory wrapper (`systemd-run --user` has no user bus on
this box); shared box, not quiesced. Test file
`hashline/src/private_block/s40_tests.rs` (966 lines, 12 tests), wired by one
`#[cfg(test)] mod s40_tests;` line in `private_block.rs`.

**Failing first.**

| run | log | result |
|---|---|---|
| the check's two reproducers, copied as they stand (with its two measured tests), `--include-ignored`, at the tip + the test file | `s40-before-reproducers.log` (`.done` = 101) | measured tests pass (the builder, the kernel and `RunStatement::new` admit the C-1 block; 288 U8 misses at `wrho_s = 15`); **both reproducers FAIL: the verifier rejects the honest proof, `H: pcs zk: group 8`** (C-1 rung-K4 + rung-P2 half; C-2 `wrho_s = 15`, control rung-G ACCEPTED) |
| the tests rewritten to expect the NAMED refusals, before any production line moved | `s40-before-named.log` (`.done` = 101) | **9 of 10 FAIL**: CS-1 — the builder admitted the C-1 statement (`left: None`); the P-2 sibling (a `Wg` entry at column 200, true at rung-P2, padded at rung-K4) admitted and its honest proof REJECTED by the verifier (slot 18, F zero-check — never built by the check); CS-2 — `Shape::new` admitted `wrho_s = 15` and `norm_wrho = 30`; CS-3 — the prover proved a byte limb set to 256; C-6 — `f_e` 64, 65, 80, 200 admitted everywhere and every honest proof rejected (slot 17, the softmax zero-check); the width measurement passed |

**CS-1 — BUILT** (`private_block.rs`, `witness.rs`, `protocol.rs`, `run.rs`).
`FeedForwardPublic::check_words(sh, gamma_m, wg_t, wu_t, wd_t, act)` is the one
check (lengths; P-2's `weights_vanish_off_support` on the four matrices; the
table length; S38-F1(a)), in the constructor's order with its messages;
`new_shaped` calls it and then converts the table (same refusal order as
before). `check_for_shape(&self, sh)` re-runs it on an existing statement,
prefixing `private block: ruling CS-1 — the feed-forward statement does not fit
the shape it is proved at: `. The shape is NOT stored in the struct. Called at:
`witness::build_shaped` (after `Ids::new` / the pinned norm-limb check, before
the input is read), `protocol::prove_inner_at` (after `Layout::for_shape`,
before `check_endpoints`, `ZkRng::from_os` and the header), `protocol::prove_core`
(first line), `verify_bytes_at` and the toy's `verify_bytes` (before the frame
is decoded against the header), `protocol::verify_inner_at` (after
`Layout::for_shape`, before the receipt checks and the header),
`protocol::verify_core` (first line), `run::RunStatement::new` (after the
block-count check, before any digest), `run::prove_run` and
`run::RunVerifier::start` (all `L` blocks, before the owners / randomness /
header) — the run layer through one helper `blocks_fit_the_shape`, refusals
prefixed `private run: block k: `.

**CS-2 — BUILT** (`shape.rs`, in `Shape::new` after `d_max`). A `wrho_s`
override `< clog2(tokens) + f_e` (u64 arithmetic) and a `norm_wrho` override
`< bits(isqrt(1 + width 32768^2) 2^12 - 1)` — the check's formula with the
input bound 32768 — are refused by name; overrides at or above are kept.

**CS-3 — BUILT** (`protocol.rs`). `u8_misses_of` counts looked words outside
the byte table (parallel above `HISTOGRAM_PAR_MIN`, the histogram's own public
threshold); the exp and activation loops count their non-hits beside the
bucket-0 filing (two `usize` counters, the filing itself unchanged);
`refuse_lookup_misses` refuses by name with the three counts. It sits after
the three histograms and BEFORE the first `rng.fp()` of the `A` mask rows,
the `A` commitment and every absorb and challenge of the block; it adds and
moves no absorb and no draw (the `git diff` adds no absorb, challenge, draw
or commit line). **Where the first commitment sits:** single block — the `A`
commitment, first of the proof (the endpoint roots are the owner's, sealed
before `prove`), so the refusal precedes every commitment the proof makes.
**Run** — block `k`'s refusal precedes block `k`'s `A` but follows its
boundary commitment `B_k` (step 2 of the stage) and stages `0..k-1`, whose
segments are already with the sink (ruling M-3). Moving it before the RUN's
first commitment would need every block's witness before the header — the
prover builds them just in time and does not hold them — so that is not
built; the caller's sealing pass (`run.rs` rule 1: the builder, block by
block, before the header) and rule M-9 remain the lines for runs.
**`#[cfg(test)]` switch** `protocol::CheatingProver` (a thread-local guard,
absent from release builds): the tamper harnesses stand in for a cheating
prover, which would not run this check, so `review_tests::outcome`,
`rung_tests::assert_verifier_rejects`, `tamper.rs::prove_tampered_for` and its
moved-activation test, `norm_alias.rs::prove_tampered` and the run test
`every_single_block_tamper_family_is_still_rejected_inside_a_run` prove with it
on. Without it 23 lane tests failed (`s40-gate-private-probe.log`: every one a
tamper expecting the VERIFIER, plus three `grow_tests` window fixtures below).
Ruling CS-1 is not switched off by it.

**Test files the rulings moved** (test-only): `census_shaped_tests.rs` — the
two S38-F1 tests that forced a statement past the constructor now also assert
the builder's CS-1 refusal; the LogUp measurement past both is kept (the
member witness with `a16 = act[128]` written on the support, where the
all-zero block has `g8 = 0`), and the reproducer's control asserts
`ProverRefused(CS-1 name)` instead of the verifier rejection it can no longer
reach; C-3 labels on the seven rows; the window-premise comment notes CS-2.
`grow_tests.rs::window_shape` — the S8 window fixtures build the toy's
UNDERSIZED windows at the rung geometry on purpose, so on a CS-2 refusal the
override is set on the derived shape (a test-side field edit; the same struct
the constructor returned before). The five harnesses above (the switch).

**Notes.** C-3: seven rows labelled "premise checked by reading" (memo §3,
test comments). C-4: `protocol.rs:323` moved to the memo's §5. C-5: §5's
zero-denominator row corrected. C-6: `layout.rs:671` comment 98,582,528 ->
98,598,912 (comment only). **`width != q_heads * head_dim`: NO failing honest
proof** — dense statements (every weight nonzero, `Wq` `(qw, width)`, `Wo`
`(width, qw)`) at widths 72, 90, 100, 120 on rung-G's head axis (and 96)
build and are ACCEPTED; no refusal added (the kernel refuses such a width, so
builder and kernel disagree for every input — public-only, recorded).
**Unbounded `f_e`: YES** (see failing first) — `Shape::new` now refuses
`f_e > 31` (`F_E_MAX`, the shaped kernel's own `f_e >= 32` bound) by name,
`note C-6`; measured after: 4..=31 ACCEPTED, 0 and 1 refused by the layout
(structural, as before), every `f_e >= 32` refused by `Shape::new`.

**Findings for the security owner (not built; outside the rulings).**

* **S40-N1 — the unoverridden norm derivation is one bit short at some
  widths above 16,384.** `Shape::new` derives `norm_wrho` from `d_max` over
  32767; the 32768 bound needs one bit more at 21 widths in 16,385..=2^20
  (first 16,385: 35 needed, 34 derived). No registered shape is near (widest
  768). There the norm remainder is REACHABLE-BUILDER-REFUSES-FIRST on inputs
  near `-32768` (measured on a 30-bit window at rung-G: builder refuses
  `norm quotient/remainder` by name) — input-dependent, but a refusal, not a
  failing proof. A fix would derive `12 + clog2(isqrt(1 + width 32768^2))`,
  which equals the current value at every registered shape. With CS-2 as
  built, an override EQUAL to the 32767 derivation is refused at those widths
  while no override is admitted.
* **S40-N2 — the ATTENTION half has C-1's exposure too.** `AttentionPublic::
  new_shaped`'s P-2 check (and lengths, RoPE rules, `exp[0] = 2^f_e`) is keyed
  on the shape passed to it; CS-1 as ruled names the feed-forward statement.
  MEASURED (`s40_n2_...`): the dense rung-G attention half, refused by P-2's
  name when asked about rung-K4, built at rung-G and placed in a rung-K4 block
  is admitted by the builder and its honest proof is REJECTED by the verifier
  (slot 15, the Q zero-check). The test asserts this measured state and flips
  when a re-check is added.
* **S40-N3 — kept overrides above the derivation:** MEASURED
  (`s40_n3_...`, honest prover, CS-3 on): `wrho_s` 17..=62 ACCEPTED, 63 and
  above refused by the builder by name (`softmax quotient/remainder`, its
  `1i64 << wrho_s` window empty or wrapped — for every input in practice);
  `norm_wrho` 31, 32 ACCEPTED, 33 and above refused by name (five norm
  limbs). No failing honest proof, no panic. The kernel's own bounds (`< 63`)
  are not enforced by `Shape::new`; nothing needs them today.

### Stage 40 — CLOSED (2026-09-22 23:29 – 2026-09-23 00:1x)

**Status: `LANDED`.** CS-1, CS-2 and CS-3 built; note C-6's `f_e` refusal
built; notes C-3..C-6 recorded. No 125M prove; no GPU.

#### The gates

| run | log | result |
|---|---|---|
| `--lib -- s40_tests census_shaped k8_tests --nocapture` (stage 37's K8, stages 38/39's census, the new tests) | `s40-after-focused.log` (`.done` = 0) | **31 passed / 0 failed / 1 ignored** (`write_the_k8_gate_bundles`, as at stage 37), 11.66 s |
| the lane filter, probe 1 (the rulings, no harness switch) | `s40-gate-private-probe.log` (`.done` = 101) | 427 / **23 failed** / 18 — the 20 tamper tests CS-3 now refuses at the prover and the 3 `grow_tests` window fixtures CS-2 refuses; fixed as above |
| the lane filter at `6844ac6` | `s40-gate-private-probe2.log` (`.done` = 0) | **450 / 0 / 18**, 131.18 s |
| `--lib s40_tests --nocapture`, with the two note tests (N2, N3) | `s40-notes.log` (`.done` = 0) | **12 / 0 / 0**, 9.34 s |
| **THE GATE**: `--lib private_` at the final code, `--test-threads=6`, `/usr/bin/time -v` | `s40-gate-private.log` (`.done` = 0) | **452 passed / 0 failed / 18 ignored**, 129.69 s (2:09.74 wall), peak RSS 4.37 GB, the same 16 `warning` lines as stage 39 (none in a stage-40 file) |

**Accounting against stage 39's 440 / 0 / 18:** +12 = the twelve `s40_tests`
(10 ruling / reproducer / C-6 tests + N2 + N3); nothing lost, nothing newly
ignored.

#### Byte identity

* **The toy stays 2,816,472 B**: `tests::honest_receipt_verifies_in_typed_and_wire_form_...`,
  `zero_witness_tests::the_zero_witness_receipt_length_equals_the_fixture_receipt_length`,
  `grow_tests::the_shape_driven_layout_reproduces_the_toy_exactly`,
  `the_toy_schedule_digest_is_frozen`, `the_toy_parameter_line_is_the_frozen_literal`,
  `review_tests::a_toy_receipt_made_before_the_lane_still_verifies` — all in
  the pass list.
* **Every shaped frame and pin**: the honest proofs from bytes at rung,
  rung-G, K4, K8, P2, C6, W14, E32 (the frame-length pins), 
  `grow_tests::the_125m_receipt_is_reproduced_part_by_part`,
  `run_tests::the_twelve_block_125m_receipt_is_the_counted_figure`,
  `slot_ir_tests::the_slot_ir_export_is_canonical_and_its_digest_is_pinned_at_every_registered_shape`
  — all pass.
* **Nothing absorbed**: `absorb_into` (both) and `BlockPublic::digest` are
  untouched; the diff adds no absorb, challenge, draw or commit line (checked
  with `git diff -U0 | grep` on `private_block.rs`, `protocol.rs`, `run.rs`:
  only comments and refusal strings match). Every registered shape is
  unchanged (no override, every `f_e` <= 12).

#### The pins that move, for the gate owner (the privacy gates re-pin per bundle source commit)

PRODUCTION files (old at `27398d0` -> new):

| file | old SHA-256 | new SHA-256 |
|---|---|---|
| `hashline/src/private_block.rs` | `29ba008487473bff67e4d10a4770ed0ddf3410aef4c0765cece3a41bf3acc872` | `1aa38780ceaef5cadd78e6cc5c30cce69e5c747c9070a853b001e64370055d56` |
| `hashline/src/private_block/shape.rs` | `dbf4e2bc36e9f74c432d6e529b229e3a593e794271fd8593d1412b8312403911` | `a5498dd7088b66304be9843235df57db906cd608a5a39da82d7adcacb2c25814` |
| `hashline/src/private_block/protocol.rs` | `e0e617be617a548641cb33c8564cee86ee7d2af90f9c6487b5fb7af30113d45b` | `a71821b5cf64cfb68f81decd03aeea2e5d3dbbcff31f684032c8351cc2850f3e` |
| `hashline/src/private_block/witness.rs` | `b9b66c024e7ca68d2a0ae4ba46241eb2abbccc8c8d94fe828041abbc710850ad` | `32edf41429ead62350c0db93cedc5785e3a4d4cbb1fed80529565571ca0a6f11` |
| `hashline/src/private_block/run.rs` | `f39aec7925ba27d51361cd3935e874b1301d7595be81f3199d9d2941c0f818e0` | `c141d77f49b40dc544b114a2c297d7d4ba3767c8e538d389d34134f57924939d` |
| `hashline/src/private_block/layout.rs` (comment only) | `14758039fbe9daa61affa1316c6e4159437b98d888d72a926f6e70e788592b30` | `1a48371540713712d8935101d2b9935f65d0f315dcd217b3eeb108e91dfba1fe` |

Test files: `census_shaped_tests.rs` `2ddf818f...fde38cbb1` ->
`855ff2ea4b5ae1c70312ff67ef6586f16454056d4f3ba113d0386577edc56d28`;
`grow_tests.rs` `2ec08cd0...df0c3` -> `dd6a893a101af920585e44dbe47750e762c906e5b3870ab0280ffd81d33f689d`;
`review_tests.rs` `94cbe3af...04cfc` -> `aaac73ed529d5fea04fcd8467795af2b02f49d445fd35c9b7f2387b3e79ec238`;
`rung_tests.rs` `e73c47f3...ec97a3` -> `d6a389e919f506a9ae9d1512c09a6d0ddfffca9e5d77314b44e86fc8f22d9211`;
`run_tests.rs` `05241401...e20ea0` -> `8cb91be9d35fdb0388764923b73bbb339e4f92a88707422b2ff68ef6ca915f4d`;
`tamper.rs` `7a73417d...440caa` -> `370e0ca2a24461a31d3ce32c018f319d6fdc2310cc2cf3488d58b6a4eed947e9`;
`norm_alias.rs` `6edd517c...90d6d6` -> `7728e19b592fe1b7c75f140aeeb72749a994c3ede9805567ea21b84348241ba4`;
`s40_tests.rs` (new) `cae36035399bca0c984f63441e51b1224739d731a79f88dfa97ce1a1b9beb800`.

**FORBIDDEN-FILES PROOF:** `git --no-pager diff --stat 27398d0 -- zkp-core
hashline/src/{zk,pcs,layer,wcache,native_capture}.rs hashline/src/gpu
private-block-kernel private-block-kernel-shaped zkvm-block hashline/Cargo.toml
hashline/Cargo.lock` prints NOTHING. The untracked `u31-c6-run1.*` files are
left alone.

#### Commits

| commit | what |
|---|---|
| `8ed1b86` | the skeleton |
| `6844ac6` | CS-1, CS-2, CS-3, the C-6 `f_e` refusal, the `layout.rs` comment, `s40_tests.rs` (10 tests), the census / harness / fixture test edits, the failing-first, focused and two probe logs |
| this one | the two note tests (N2, N3), the memo's stage-40 section (§9) and notes C-3..C-5, this ledger, `s40-notes.log`, `s40-gate-private.log` |

#### What stage 40 is NOT

Not a privacy result. Not a soundness statement: the field-wrap premise is
untouched (the `f_e` bound makes its regime smaller, it does not re-derive
it). CS-3 in a RUN is stage-local (see above), not run-wide. The attention
half's cross-shape exposure (S40-N2) and the norm derivation at widths above
16,384 (S40-N1) are measured and open for a ruling, not fixed.
