# Research handoff: does the app's CS-3 repeat sit under A33's precondition? (2026-11-21, claude-tick 32, queue item 52)

From Claude, the background researcher. One bounded tick; local reading and arithmetic only (no web, no run, no build, no Git).

**What was read (full text of the spans).** `ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/classify_cli.rs:495-600` (`CliSource::witness`, `seal_chain_keeping`), `witness.rs:55-135` (`build_for_block`, `build_accuracy_with`, the A16 note), `protocol.rs:618-650` (`check_lookup_misses`, `check_lookup_misses_after_public_check`), `private_block.rs:852-900` (`check_accuracy_for_shape`, `BlockPublic::check_for_shape`), `shape.rs:236-302, 836-838` (profiles, `accuracy_stack`), `trained_statement.rs:557-561` (`shape_at`), `token_io/run.rs:1138-1151` (`BlockRef`), `classify_run.rs:214-230` (`seal_check` call), `r6_tests.rs:205-280`, `run_fork_tests.rs:7440-7530`, `classify_r16_tests.rs:248-292`, A33's README sections 5, 7, 8. Same gpu-metal tree that ticks 30 and 31 used (this checkout's `hashline/` has no `token_io`); not necessarily the app's exact binary. **Triage material, not a work order;** nothing below changes a committed word, a refusal or a refusal's text.

Labels: CODE-READ (file:line), COUNTED, MEASURED (A33 record), DERIVED (arithmetic shown), ASSUMED.

## 1. Answer

**Yes. The classifier's repeat sits under A33's precondition, and more simply than in the trained path.**

A33's precondition (`protocol.rs:630-637`): the block's public check passed for THIS shape, on THIS block, with nothing changed since. At `classify_cli.rs:585` and `:591`:

- (1) **The build ran the check on the same arguments.** Line 585 is `build_for_block(&ssh, &blk, &x)`; line 591 is `check_lookup_misses(&ssh, &lay, &blk, &w)`: the same `&ssh`, the same `&blk`, the same iteration, build first (CODE-READ). In the trained path the build is handed a derived shape `local` (the data's gate shift) and A33 needed the `build_checked` rule to prove `local == ssh`; here there is no derived shape and no rule is needed.
- (2) **Every branch of `build_for_block` runs the check.** Non-Legacy: `check_accuracy_for_shape(sh)?` before the build (`witness.rs:84`). Legacy: `check_for_shape(sh)?` before `build_shaped` (`witness.rs:88`). So even if a profile were Legacy the repeat would be a repeat. W16R2 is not Legacy anyway: all three W16R2 profiles are `Stack::LowH24` (COUNTED, `shape.rs:300-302`); `accuracy_stack` returns Legacy only for an unregistered profile string (`shape.rs:836-838`). This closes the "W16R2 non-Legacy not verified" item of tick 30.
- (3) **At a non-Legacy shape `check_for_shape` IS `check_accuracy_for_shape`** (`private_block.rs:886-889`, the first statement of its non-Legacy branch).
- (4) **Nothing can change between the two calls.** Both take shared borrows; `BlockRef` is a borrowed reference or an `Arc` and dereferences to `&BlockPublic` (`run.rs:1138-1151`); `BlockPublic` holds three plain fields (`private_block.rs:833-837`, no `Cell`, `Mutex` or `RefCell`; the file's two `OnceLock`s are the A21 and A30 digest switches, unrelated). `check_accuracy_for_shape` reads only `self` and `sh` (the function body has no environment or global read; it uses a rayon scan of nine weight arrays and `dd_e_column`). Item 45 reached the same.
- **Refusals.** If the check could fail, the build (line 585) refuses first with "block k: the witness builder refuses: ... (the sealing pass, before any header)", which is today's behaviour too: the repeat in `check_lookup_misses` can only be reached after the same check passed, so it cannot refuse. A record at another gate shift (A33's `RecordGate` case) is refused by the build's step 7 (`check_accuracy_for_shape`: "folded gate denominator differs from the stage shape") in the classifier path in both before and after, because the classifier builds at `ssh` itself. The layout check `lay.check_is_for_shape(sh)` stays in A33's variant.
- **Other `check_lookup_misses` calls in the app.** `classify_run.rs:225` is the run's own `seal_check` closure; for `CliSource` the method ignores it (`classify_cli.rs:552-558`, `seal_check` returns Ok once `sealed`), so it never runs the repeat in the app. It would still run it for other sources and is not touched. `cli.rs:802` is the token CLI (Legacy-capable, `build_shaped`), not the classifier.

## 2. Tests A33 pinned that would have to be repeated for the classifier

A33's gates are bound to `trained_block::seal_chain`; none of them reads `classify_cli.rs` (grep: no `include_str!("classify_cli.rs")` in the tree).

| A33 test | Applies to `classify_cli.rs:591`? | What a change would add |
|---|---|---|
| `r6_tests.rs:263` `a33_the_sealing_pass_skips...` parts (1) and (2): `build_for_block` runs the check before it builds, in both branches; `check_for_shape` non-Legacy is `check_accuracy_for_shape` | Yes, already general: reads `witness.rs` and `private_block.rs`; no repeat | none |
| same test, part (3): `witness_for_block` hands the build the data's gate shift (`build_checked` rule) | No: the classifier has no such rule | none (the classifier passes `&ssh` to both) |
| same test, part (4): build, rule, scan in that order in `seal_chain` | Text of `trained_block.rs` only | a text gate on `seal_chain_keeping`: `build_for_block(&ssh, &blk, &x)` appears before `check_lookup_misses_after_public_check(&ssh, &lay, &blk, &w)` and the two take the same arguments (new, small) |
| `r6_tests.rs:218` (the full-form call still pinned) | trained `seal_chain` only | none |
| `run_fork_tests.rs:7471, 7480, 7490` (refusal texts, honest summary) | Drive `a20_seal_summary_for_tests`, the trained pass | a classifier analogue: refusal text for a doctored weight and for a record at another gate shift (expect the builder's text in both), and a before/after identity of `seal_chain_keeping`'s output (`x_last` and the kept witness planes) at a W16R2 rung profile. No test of that function's refusals is retained: `classify_cli_tests.rs:422` (parity) and `classify_r16_tests.rs:248-292` (the run's own path, `ClassifySource`) are the nearest |

## 3. Value

- **MEASURED (A33 README section 7):** removing the repeat saved 0.275 s of a 2.181 s solo sealing pass (12.6%) over 32 blocks at the 8B harness profile = 8.59 ms a block (DERIVED).
- **DERIVED for the app, 26 blocks a request, lane period 19.405 s (tick 30):** 0.223 s at the solo per-block cost (1.15%, x1.012); 0.358 s if hosts stretch x1.6 at six lanes as tick 30 assumed for the sealing pass (1.84%, x1.019; 12.4% of the 2.88 s window). Per-block cost at the lane's 5-thread pool against the harness's 8 is not measured; the scan is memory-bound, so thread count may matter less than contention (ASSUMED).
- **Not additive with seal-ahead or before-part-ahead** (they shorten the same lane period; tick 30 section 2).
- **A wider lead, unverified:** the build's own check also repeats on every request for resident blocks (`resident()`, `run.rs:754-758`, the A26 contract: same object, never freed or written while the source lives). A per-process memo keyed by block identity and shape would remove that one too: the ceiling is twice the above (0.72 s, x1.038, DERIVED), but soundness needs the identity contract (item 45's objection stands) and is not argued here.

## 4. Falsifiable test (not scheduled)

Pass: the classifier analogue gates above compile and pass at the W16R2 rung profile, the before/after identity of `seal_chain_keeping`'s output holds, and one app stream (or the one-lane bench of tick 30) shows a sealing window shorter by at least 0.15 s per request with the same receipts. Kill: a window gain under 0.1 s (below x1.005 on the period). Under the 5% rule the whole item is at most x1.019 (x1.038 for the wide lead): **not scheduled.**

## Expected effect

Committed words per request: 0. Proved tokens/s: +1.2% to +1.9% at most (a lane-period ceiling; no pass-through measured at six lanes; A33's own two-lane result was zero at the stream level because the prove call paced it).

## Risks and not verified

The gpu-metal tree, not the app binary's confirmed source; the per-block stretch is tick 30's ASSUMED x1.6; five-thread cost not measured; whether any test reads `classify_cli.rs` by `include_str!` under another path was searched by grep only; `HL_A26_KEPT` and `KeptResidentBlocks` (`classify_cli.rs:744`) change what is kept, not what is checked.
