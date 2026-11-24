# Host-fast wave 2, fix read: `9f70ff137` against `83d784b26` (base `da938ecaf`)

Written 2026-11-24T08:58:59Z. READ: everything below comes from reading the source through git.
Nothing was built, run or timed. Line numbers are at `9f70ff137`. Paths are under
`ops/zkp-mvp/gpu-metal/hashline/src/`.

## Verdict

No High finding. Fix (1) (the verifier never takes a switch-dependent path) is complete in the
code, for `HL_HOST_FAST` too. Fix (2) (the histograms are bound to the witness by ownership) is
complete for the witness. The block is still matched by address. Fix (4) (the dropper) is
documented but not bounded. With every switch unset, the code does what the base does. With the
switches set, I found nothing that changes proof bytes, transcript order or random draws compared
with `83d784b26`. Two Medium findings concern the requested tests, which are weaker than asked.

## Findings

### M1. The verifier-isolation gate does not cover an R13-stack proof and does not go through a receipt door
- Where: `private_block/w16r2_tests.rs:7012` `host_fast_all_three_switches_verifier_isolation_gate`.
- The "R13 / classifier stack" half builds `Shape::rung_tc` blocks with `BlockPublic::new(p, f)`
  and no `with_accuracy`. So `define` never reaches `accuracy_fold::fold_checked` in that half: it
  is a Legacy-stack classifier, not an R13 stack. The half asserts only `CHF_C1_DIGESTS` on the
  prover, not `HF_H4_ACC_FOLD` or `HF_W2_FOLD_TILED`. Only the W16R2 (`W16R2_RUNG_H24`) half
  exercises the accuracy fold on the verifier, and it does assert that the prover hit both fold
  counters.
- Both halves call `verify_core`, `verify_run_with_forks` and `verify_classify_run` in-process.
  None verifies a receipt through the `verify`, `check-serve` or `input-owner` doors. The
  process is fresh only when the runner runs the test alone; the test checks that the three
  variables are set (`:7016`) but does not start a process of its own.
- The good part: the test asserts on both hits and fall-backs of all three switches (six
  arrays, `:7031-7038`).
- How it goes wrong: a later switch read on a verifier path specific to the R13 stack, or one
  in the receipt-level code, would pass this gate.
- What settles it: add a case on an R13 accuracy stack (for example the Shieldstral R13
  profile), assert that the prover hits the fold counters there, and verify through the
  receipt or check-serve door.

### M2. The refusal test does not go through the sealing pass
- The request was for a refusal through the sealing pass with the switch set. The commit adds
  only direct calls to `protocol::check_lookup_misses_sealed`:
  - `protocol.rs` test `host_fast_w2_sealed_hists_twoterm_exp_and_flat_w16_parity`, part (d)
    (around `:5004`), with W2 off and on and interior indices;
  - `w16r2_tests.rs` `host_fast_w2_rung_golden` (around `:6503`).
- No test drives a lookup miss through `seal_chain_keeping`, `seal_chain_keeping_fast`
  (`token_io/classify_cli.rs:605`, `:731`) or trained `seal_chain` (`trained_block.rs:3087`)
  with W2 on, so the wrapped refusal text is not checked on those paths.
- What settles it: one test per sealing pass with a planted miss and the exact expected string.

### L1. The block is still matched by address
- Where: `protocol.rs:2584-2600` (`blk_sig`: the heap addresses of `exp`, `wq`, `wg_t` and the
  accuracy group and table vectors, plus `act` by value); used by `matches_block` (`:2617`).
- Failure case: a `SealedWitness` outlives its `BlockPublic`, and a different block is allocated
  at the same addresses. The proof then hits with stale `m_exp` / `m_act` and skips the CS-3
  refusals that depend on the block. The result is a proof the verifier rejects instead of the
  named refusal. Soundness is not affected.
- In the callers I read, the blocks outlive the sealed witnesses: D55 shared mode moves them
  into `SealedBlocks`, and the classifier keeps resident blocks. So the case is latent.
- What settles it: carry a block digest in the histograms, or tie the borrow to the block's
  lifetime.

### L2. More unannounced changes on the set path (bytes unchanged in my reading)
- `w2_is_static_cpu_slot` (`argument.rs:4018`) now uses the real `def.tabs.len()` instead of the
  fixed counts 26, 2 and 3.
- The slot IR is now built after `define`, from a transcript snapshot taken before it
  (`argument.rs:4117-4136`).
- `range_table_helper_flat` now checks all `1 << log_cols` entries (`protocol.rs:2812`).
- The pub-gen kinds 7 and 8 moved into their own shader and pipeline (`gpu/metal.rs:4106-4150`,
  `:4258`, `:4437`, `:4685-4713`).
- Effect: which slots run on the device versus the CPU, and the refusal-only edge cases, can
  differ from `83d784b26`. Under the M4k "same words" contract, no bytes change.

### L3. The trained-block byte test is narrower than its doc comment
- Where: `run_fork_tests.rs:7656`.
- The doc says the test writes byte-identical run-directory frames for a 2-block run. The code
  uses `l = 3` and compares only the interior forks, that is one fork (`k = 1`), against an
  `hw0` re-proof (`a19_interior_forks_whole`).
- Also, the classifier test with W2 alone (`classify_serve_tests.rs:628`) checks counters and
  acceptance only. It has no comparison of the bytes with the switch on and off.

### L4. A test is mislabelled
- Where: `protocol.rs` part (c), around `:4992-4999`.
- The assertion says "upper bound base + len <= inv.len()". But the truncated table
  (`len < 1 << width`) is always refused by the width guard (`:2813`), so the per-index bound
  is never tested.

### L5. Every W2 entry point is now `#[cold]`
- This includes `fold_w2`, the tiled folds, `compute_histograms_w2`, the flat W16 writer,
  `mask_eval_eq_w2`, `measure_per_eval_w2` and `slot_pipes_get_or_compile`.
- The attribute tells LLVM these calls are unlikely, which changes code layout on the path
  where the switch is set. The risk is to speed only.
- What settles it: a timing run on a quiet machine with `HL_HOST_FAST_W2=1`, before and after
  this commit.

## Answers

**Q1. Verifier isolation.** Fix (1) is complete for both switches. The verifier now reaches the
fold as follows:
- `argument_with` sets `pts.prove_side = matches!(side, Side::Prove{..})` (`argument.rs:4073-4074`);
- `define` passes it to `fold_checked` (`:3212`, `:3353`);
- with `!prove_side`, `fold_checked` returns the base `fold_with_mode(.., false)` before any
  switch is read (`accuracy_fold.rs:1149-1150`);
- `fold` (`:1171`) passes `false`;
- every other `define` caller (Lean, IR and accuracy tests) uses `Points::default()`, where the
  flag is `false`.

The remaining reads in non-test code:

| Group | Sites | Reached by a verifier? |
|---|---|---|
| Accuracy fold, prover side | `accuracy_fold.rs:1108`, `:1152`, `:1155` | No |
| Prover tables and terms (take `ProverData` or the private planes) | `argument.rs:732`, `:772` (`priv_table_fill`); `:1177`, `:1190`, `:1250`, `:1271` (`build_tables_*`); `:1698` (`mask_eval_eq`); `:2186` (the `Side::Prove` arm of `run_slot_with`) | No |
| Public-table generator | `:2401`, `:2410`: behind `self.pub_gen_on`, which comes from `pts.pub_gen_prove = prove_side && host_fast_on()` (`:4080`) | No |
| `argument_with` itself | `:4076`, `:4080`: short-circuited by `prove_side`; `:4122`, `:4145`: inside `twin_before`, which needs `metal_on = prove_side && gpu` | No |
| Prover core | `protocol.rs:763` (sealing scan); `:3161`, `:3178`, `:3239`, `:3482`, `:3583`, `:3663`, `:3887`, `:3919`, `:4105`, `:4270`, `:4282`, `:4293` | No |
| Range table inverses | `range16.rs:248`, called only from `prove_core_after_with` and from tests | No |
| Mask commit and opening | `zk.rs:809` (`mask_commit_tagged`), `:1112` (`mask_open`): prover only | No |
| Metal | `gpu/metal.rs:1726`, `:1912`, `:2177`, `:2822`, `:5073`: the device commit, open and rounds, prover only | No |
| Merged classifier switch | `boundary.rs:393`; `classify.rs:1035` (via `new_chunk_prover`); `:1613` (`check_tables_prover`); `classify_batch.rs:231`; `classify_cli.rs:841` (`prove_with_public`); `classify_run.rs:452`, `:492`, `:853`; `classify_serve.rs:522`; `stage_in_c.rs:320`, `:342` | No; all are prove or serve paths |
| Sealing passes | `classify_cli.rs:605`, `:731`; `trained_block.rs:3087` | No |

Cached forms: `zk.rs:290-291` (atomics), the `Points` flags, `B::pub_gen_on` and
`CoreAhead.twoterm_deferred`. All are prover-only.

**Q2. Sealed histograms.**
- The type is `SealedWitness { wit, hists: Option<Box<SealedHistograms>> }` with private fields
  (`protocol.rs:2641`). `SealedHistograms` is private (`:2606`).
- Construction:
  - histograms are created only by `check_lookup_misses_sealed` (`:738-751`), which takes the
    witness by value after `scan_lookup_misses` has refused any miss and recorded
    `zero_misses`;
  - `unsealed()` makes one without histograms;
  - nothing else constructs one, apart from a field read in the `protocol.rs` tests.
- Accessors: `witness()` gives a shared reference only; `into_witness()` drops the histograms.
  There is no `Clone`.
- Consumption: only `prove_core_before_sealed` (`:3226`) and `prove_core_sealed` (`:3038`)
  consume one. A hit needs `dd_cap == 0`, no cheating hook, `zero_misses` and an equal
  `(Shape, BlkSig)` (`:3141-3158`).
- No caller can pair a histogram with another witness. A reused histogram skips CS-3 only
  where the same scan already ran on that same owned witness.
- Address comparisons remain for the block: `blk_sig` (L1), and the base A13 `block_at`
  check (`:3112`, `:3893`).

**Q3. The unset path.** It matches the base: the same transcript order, the same draws and the
same refusals, in the same order (`protocol.rs:3292-3331` against the base hunk). Work the base
does not do:
- a few relaxed atomic switch loads per block, per slot, per table and per extension round. One
  is in `mask_eval_eq`, once per call and not per element. There are none in element loops;
- the `SealedWitness` move wrapper;
- in `CoreAhead`: the `twoterm_deferred` flag, an `Option<Box>` for timing, and the `w16_missed`
  field (added in `83d784b26`);
- the `deltas.is_empty()` test (`:3946`);
- `lookup_words` is computed from the layout;
- the views are built after the challenges instead of before; same words, no transcript use;
- on Metal, the slot IR is built after `define` from the snapshot;
- `seal_chain` computes `witness_bytes` earlier.

There are no new allocations or scans. Removed from the unset path compared with `83d784b26`:
- the `LookedCol::TwoTerm` arms (now in `LookedColW2`);
- the `ExpSource` dispatch;
- the inline W2 blocks in `priv_table_fill`, `mask_eval_eq`, `run_slot_with` (`n_active_priv`),
  `rope_tables` and `fold_with_opts`;
- the `covers_ctx` evaluation for `weights_checked`;
- the `twoterm_on` read in `looked_built`;
- the unboxed `PubGen::Rope` and `metal_cached`;
- the generic `async_drop`.

**Q4. The set path.** I found no change to bytes, transcript order or draws. Each moved block:

| Moved block | Result of the comparison |
|---|---|
| `priv_table_fill_w2` (`argument.rs:620`) | Pure move |
| `mask_eval_eq_w2` (`:1635`) | Pure move |
| `eval_ext_round_w2` (`:1664`) | Pure move: the same serial or parallel choice |
| `try_rope_pub_gen` (`:2354`) | Pure move, with `Rope` boxed |
| `try_attach_cached_metal_slot` (`:4034`) | Pure move |
| `w16_bin_chunk_w2`, `w16_histograms_cols_w2`, `..._flat_w2`, `looked_built_w2`, `looked_cols_w2` | The base function plus the old `TwoTerm` arms; checked by normalised diff |
| `fill_exp_helpers_direct_w2` (`protocol.rs:3464`) | The old `ExpSource::Direct` arm, verbatim |
| `compute_histograms_w2` (`:3123`) | The old W2 branch, with ownership in place of the address and sample check |
| `fold_w2` (`accuracy_fold.rs:1089`) | The same as the old `fold_with_opts` under W2, with the same counters |
| `cached_pads_ref_w2`, `read_gather_cols_w2`, `read_sparse_fold_out_w2`, `measure_per_eval_w2` (`gpu/metal.rs`) | Pure moves |
| `k_tab_pub_gen_w2` | The same MSL as the old kinds 7 and 8 |

Changed, not moved: L2, plus `ensure_twoterm_built` (`protocol.rs:2142`), which turns the
two-term columns into ordinary built columns before a fall-back to the base writer (the same
wrapping sums).

**Q5. Device code.**
- No new panic: pipeline failures return `Err`, or are declined per kind (`metal.rs:4685-4713`).
- No new wait.
- Cache keys: `GatherArgs` is unchanged. The `tail_per_eval` key `(topo_key, n_vars)` is
  unchanged. The W2 pipeline is a single `OnceLock` with no key.
- The MSL `TabPubGenArgs` matches the Rust `#[repr(C)]` struct (`:4110-4123` against
  `:4184-4197`).
- The read-backs still happen after completion, at the same point in the code.
- The base shader's code is the same as at the base; only its comments differ.

**Q6. The async dropper.** It is documented, not bounded:
- `zk.rs:343-352`, `protocol.rs:2482-2492` and `trained_block.rs:3076-3078` document it;
- behaviour is unchanged: at most two payloads in flight in the process (`sync_channel(1)`
  plus one worker), and they are not counted in the budget;
- `HL_HOST_FAST_ASYNC_DROP` defaults to off. It is read once in `host_fast_async_drop_env_init`
  (`zk.rs:337`) through `host_fast_async_drop_on` (`:353`), which is false unless
  `host_fast_w2_on()`;
- it is called at `protocol.rs:4105`, `:4270` and `:4282`.

**Q7. Tests.**

| Test | Ignored? | Environment and gate | Covers |
|---|---|---|---|
| `private_block::w16r2_tests::host_fast_all_three_switches_verifier_isolation_gate` (`:7012`, new) | Yes | `HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1 HL_HOST_FAST_W2=1 -- --ignored --exact --test-threads=1` | (1); weaker than asked (M1) |
| `private_block::token_io::classify_serve::tests::host_fast_w2_alone_classify_serve_gate` (`:628`, new) | Yes | `HL_HOST_FAST_W2=1`, `HL_CLASSIFY_HOST_FAST` unset | (3a); counters only, no byte check |
| `private_block::run::fork::tests::host_fast_w2_trained_block_d55_sealing_byte_identical` (`:7656`, new) | Yes | in-process toggles, holds `host_fast_test_lock` | (3b); interior fork only (L3) |
| `...classify_serve::tests::classify_host_fast_plus_w2_serve_gate` (`:562`, changed) | Yes | all three switches | now also asserts the `HL_HOST_FAST` counters during check-serve |
| `private_block::w16r2_tests::host_fast_w2_rung_golden` (`:6266`, changed) | Yes | GPU | (2): a block-mismatch fall-back that cannot flake, and a refusal on an interior word |
| `private_block::w16r2_tests::host_fast_w2_all_call_sites_byte_identical` (`:6522`, changed) | Yes | GPU | moved to `SealedWitness` |
| `private_block::w16r2_tests::host_fast_w2_rope_and_const_pub_gen_gpu` (`:6157`, changed) | Yes | GPU | `Rope` boxing |
| `private_block::protocol::tests::host_fast_w2_sealed_hists_twoterm_exp_and_flat_w16_parity` (`:4794`, changed) | No | normal suite | (2) and part of (3c); see M2 and L4 |
| `private_block::accuracy_fold::tests::w2_tiled_4row_neon_matches_baseline_and_refuses_i8_min` (`:1471`, changed) | No | normal suite | (1) at unit level: `prove_side=false` with both switches on equals the base |

The `run_fork_tests.rs` helpers `a18_check_direct`, `a18_recompute_interior` and
`a19_interior_forks_whole` changed signature only.

Missing or weaker than asked:
- no R13-stack case and no receipt door (M1);
- no refusal through a sealing pass (M2);
- no byte comparison for the classifier with W2 alone, and only the interior fork for the
  trained block (L3).

**Q8. Unannounced changes.** All look safe in my reading:
- `seal_chain` was restructured (`trained_block.rs:3074-3125`):
  - `will_hand` and `will_keep` are computed before the CS-3 check;
  - `hand.witness` is called only when `takes_window(k)`;
  - histograms are collected only when `shares_blocks && will_keep`;
  - this matches `plan_hand_over`'s own `k >= window` return (`run_fork.rs:2690-2702`), since both
    windows are `ahead_window().min(l)`;
  - when the plan is filtered out, the witness comes back and is kept without histograms:
    speed only.
- `SealHand::shares_blocks` and `takes_window`, and `D55Hand.window`, are new.
- `prove_at_turn_with_hists` is removed. `prove_forks_inner` now calls `src.witness_sealed(k)`,
  whose default wraps `witness(k)`, so tamper sources are unchanged.
- `RunWitnessSource::witness_sealed` (`run.rs:1076`) and `ClassifyRunSource::witness_sealed` are
  new.
- `classify_cli.rs` and `classify_run.rs`: mechanical changes to `SealedWitness`.
- `zk.rs`: the cached `OnceLock` became `AtomicU8`, with the same semantics. The race on first
  initialisation is benign.
- Plus the items in L2.

## Not read
- The `gpu/metal.rs` regions outside this commit's hunks: `commit_impl` around `:2822`, the full
  `MetalRounds` and `MetalTables::build_planned`, and the bodies of the W2 helpers that only got
  `#[cold]`.
- The bodies of `fold_rows_fast_w2` and `fold_cols_fast_w2`, `exp_histogram_direct`,
  `write_helpers_w16_cols_flat` and `slot_topo_key` / `extract_coefs`. In this commit they got
  only attributes and renames.
- `misfile_range_misses_cols` against `misfile_range_misses_cols_w2` (test-only hooks).
- The helpers that the new tests use (`rung_case`, `RungRun`, `A18Fix`, `A19Synth`, `Cc` and
  `Post`), and the classifier half of `host_fast_w2_all_call_sites_byte_identical` beyond its
  changed hunk.
- The `83d784b26` W2 code that this commit did not touch (read by reviewers A and B), and the
  base-to-commit hunks in `gpu/mod.rs`, `argument_accuracy.rs` and `classify_cli_tests.rs`.
