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

**Status: `LANDED`.** The security owner's ruling on finding S19-F1 is
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
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0 env MALLOC_MMAP_THRESHOLD_=131072 HL_PB_TIMING=1 HL_PB_WEIGHTS=dense-ff <BIN> --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block >> results/zk60_block125m_lane/m125-one-block-dense-ff.log 2>&1; echo $? > results/zk60_block125m_lane/m125-one-block-dense-ff.done' >/dev/null 2>&1 &
```

The FULLY DENSE one-block 125M run — **newly possible**: S19-F1 is what made
`HL_PB_WEIGHTS=dense` un-runnable at 125M (four key-value heads carrying
different activations), and the witness was already known admissible there:

```
... HL_PB_TIMING=1 HL_PB_WEIGHTS=dense <BIN> --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block ...
```

The ALL-ZERO-input one-block 125M run (task 9(b)):

```
... HL_PB_TIMING=1 HL_PB_INPUT=zero <BIN> --ignored --exact --nocapture --test-threads=1 private_block::rulings_tests::private_block_125m_one_block ...
```

All three take the HEAVY lock, so enqueuing them together is right: each
blocks on the lock and self-starts.

**Does a fully dense admissible RUN recipe exist?** At **rung-G, YES, and it
is measured**: `first_admissible_dense_run_band` searches the
down-projection band DOWNWARDS from the recipe's own and takes the first at
which the witness builder accepts all three blocks, with every other band —
attention included — left at the recipe's. The band is printed by the test.
A run needs a smaller down band than a block because block `k+1`'s hidden
input IS block `k`'s `xres2 = xres1 + z16`, so `z16`'s spread compounds and
the residual leaves `int16`. **At 125M it is NOT determined here**: the same
search costs up to twelve 125M witness builds (~11 s and 725 MiB each), which
is a heavy run. It is left as one ignored command:

```
... <BIN> --ignored --exact --nocapture --test-threads=1 private_block::run_tests::the_first_admissible_fully_dense_run_band_at_125m
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

| command | log | result |
|---|---|---|
| `--lib private_block::grow_tests::the_slot_definitions` (the first build) | `v1-s20-defs.log` | 1 passed, exit 0 |
| `--lib --no-run` | `v3-s20-build.log` | exit 0, **13 warnings** (the baseline's 13) |
| the structural filter (grow / pad / layout / hash-domain / rulings) | `v4-s20-struct.log` | the two stale pins found and corrected |
| **the gate**: `--lib private_` | `v5-s20-private.log`, `v7-s20-private.log` | see below |
| the Python layout model | — | 25 passed |
| the Python inventory driver | `v8-s20-inventory.log` | 40 passed |
| the model probe with the repaired schedule | `v6-s20-model-probe.log` | the deltas reproduce the Rust's |

