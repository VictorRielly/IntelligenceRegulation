# Host-fast wave 2, read A: the proof core (`agy/host-wave2` at `83d784b26`, base `da938ecaf`)

Independent source read, 2026-11-24. Nothing was built or run. All line numbers are at `83d784b26`.
Paths are under `ops/zkp-mvp/gpu-metal/hashline/src/`.

Scope read: the whole diff of `private_block/protocol.rs` (code hunks; only the headers and first part of the
new tests), `private_block/argument.rs` (code hunks; the new test only to its setup), `private_block/argument_accuracy.rs`,
`private_block/accuracy_fold.rs` (code hunks; the new test only to its loop header), `private_block/range16.rs`,
and the switch, counter and `mask_open_w2` code in `zk.rs`. For context only: `trained_block.rs:3040-3115`
(the sealing caller), `w16r2_tests.rs:6436-6497` (the stale-histogram test), `slot_ir.rs` (the `IrPoints`
writers and readers), `metal_slot.rs:185-290, 660-696`, `private_block.rs:852-874`.

## Summary

| Grade | Count | Items |
|---|---|---|
| H | 0 | none found |
| M | 3 | M1 histogram identity is pointer plus 3 samples and a hit skips the CS-3 refusal; M2 the stale-witness test can flake and does not test the dangerous case; M3 async drop keeps up to two large buffers past the budgeted release |
| L | 5 | doc comments attached to the wrong functions; W2-4a skip leaves `IrPoints` lengths at 0; hard-coded slot table counts; fallback log keeps only the first reason; `range_table_helper_flat` checks fewer entries |

I found no case in the code I read where the switch set produces different proof bytes, a different
transcript order or different random draws from the unset path for an honest, unmodified witness.

## Findings

### M1. Sealed-histogram reuse checks identity by heap address plus three sampled words, and a hit skips the CS-3 refusal

- Where: `private_block/protocol.rs:2349-2380` (`blk_sig`, `wit_sig`), `:2399-2401` (`matches`), `:2898-2925`
  (the hit path), compared with `:2964-2971` (the refusals on the other path).
- What is compared: the full `Shape` (`==`), `zero_misses`, and two signatures.
  - The block: the heap addresses of `exp`, `wq`, `wg_t`, the accuracy `group_ids` and `scaled_tables`, the
    length of `exp`, and the 256-entry `act` array by value. No other block content is compared.
  - The witness: for every plane, its address, its length, and the words at index 0, `len/2` and `len-1`.
  - There is no content hash and no full comparison.
- What a hit skips: `refuse_lookup_misses` (u8/range, exp and act misses) and the `w16_missed`, `exp_missed`
  and `act_missed` values (all forced to 0 at `:2925`). The dictionary check is not affected because the
  hit requires `dd_cap == 0`. The seal-time scan ran the same checks and the hit requires
  `zero_misses`, so for the same content nothing is lost.
- Trigger: a `SealedHistograms` is handed with a witness that has the same plane addresses, lengths and
  first/middle/last words as the sealed one but different interior words. This can happen in two ways:
  (a) the planes are modified in place between `check_lookup_misses_collecting` and `prove_core_before_with`;
  (b) the sealed witness is freed and a different witness is allocated at the same addresses (an ABA reuse).
- Effect: the committed multiplicity rows (`A_MU8`, `A_MEXP`, `A_MACT`, range sub-planes) belong to the old
  witness, and the named refusal does not run. The helper fill then assumes zero misses. Under
  `HL_HOST_FAST=1` the `ExpSource::Direct` fill indexes `exp_inv[d as usize]` without a range check
  (`:3180-3214`), which panics on an out-of-range delta. Otherwise the prover produces a proof that the
  verifier rejects, because the LogUp sums do not balance. The verifier is not affected and soundness holds.
  The failure is that a refusal is skipped (a crash or a rejected proof instead of the named refusal).
- Reachability: in the callers I read, each histogram is stored at the index of the witness it was
  computed from (`trained_block.rs:3057-3111`; the histogram is dropped when the witness is not kept). I found
  no path that changes a kept witness in place or puts a different witness for the same block at the same
  addresses. A deterministic rebuild of the same block's witness at the same addresses would match, but its
  content is identical. I did not read `run_fork.rs` or the classifier sources, so this is graded M, not H.
- Fix options: tie the histograms to the witness by ownership (move them into the kept slot together with the
  witness), or compare a digest of the looked planes (`A_S8`, `A_MX`, `A_E`, `A_G8`, `A_A16` and the lookup
  planes), or keep the reuse for the histogram counts but still run `refuse_lookup_misses` from counts
  recomputed cheaply. The current check is a fingerprint, so the doc comments' phrase "the exact same /
  this exact `(Shape, BlockPublic, Witness)`" (`:2384`, `:2404-2407`) claims more than the code checks.

### M2. The stale-witness test can flake, and it does not test the dangerous case

- Where: `private_block/w16r2_tests.rs:6470-6496`.
- `w_run` is moved into `prove_core_with` and dropped there. `w_stale = copy(&w)` then allocates planes of the
  same sizes in the same order. If the allocator reuses the same addresses (likely with LIFO small-size free
  lists and the large-allocation cache on macOS), `matches` returns true: the content is identical, so all
  three samples match. The asserts `sd[HF_W2_SEAL_HIST] == 0` and `sfd == [1,0,0,0,0]` then fail
  intermittently, even though the proof is correct.
- The case that matters for M1, the same allocation with one interior word changed (not at index 0, `len/2`
  or `len-1`), has no test. Add one: mutate an interior `A_E` or lookup word of the sealed witness in place and
  assert the CS-3 refusal (or a fallback).

### M3. `HL_HOST_FAST_ASYNC_DROP=1` holds up to two large buffers past the point the memory budget assumes they are freed

- Where: `private_block/protocol.rs:2256-2290` (`async_drop`), `:3688-3690` (the witness, `looked`, `built`,
  `deltas` and `act_idx`), and the `a.data` / `h.data` drops after `open_zk` (diff hunk at old `:3093`).
- `sync_channel(1)` plus one item the worker is still dropping allows two buffers in flight. At 125M each item
  is about 1.5 GB (the code's own note), and an 8B block's buffers are larger. The A19 window and budget in
  `trained_block.rs` count a buffer as released when it is dropped.
- Off by default and off unless set explicitly even with `HL_HOST_FAST_W2=1`. No proof bytes are affected.
  Graded M because this box has frozen under memory pressure before. If the sub-switch is kept, it needs a
  bounded wait before the next block's allocation, or the budget must count the in-flight bytes.

### L1. Two new functions took the doc comments of existing functions

- `exp_histogram_direct` (`protocol.rs:629`) is inserted under `check_lookup_misses`'s doc
  (`:615-623`, "ruling CS-3's lookup-miss refusal ... a cheating prover skips it in test builds"), with
  `check_lookup_misses` itself at `:711`. Rustdoc now attaches that text to `exp_histogram_direct`.
- `try_write_helpers_w16_flat` (`:3378`) is inserted between `prove_core_after_with`'s doc (`:3369-3375`:
  "returned for this very block object ... any other state is refused before anything is absorbed") and
  `prove_core_after_with` (`:3432`). That doc, which states a protocol rule, now documents the helper, and
  `prove_core_after_with` has none.

### L2. The W2-4a IR skip leaves `IrPoints` lengths at 0 for later slots

- Where: `argument.rs:3957-3969`, `:4018-4034`. A skipped slot (`SC_QMM..SC_DMM`, `SC_SCORE`, `SC_PV`, `SC_TZC`,
  `SC_ZS`) never runs `build_slot_ir`, so `ipts.r_q, pq, pk, pv, p_a, p_s, p_o, r_tf, p_g, p_u, p_z` stay at 0
  (`slot_ir.rs:1086-1154`). Later IRs read them (`slot_ir.rs:1276, 1344-1345, 1427`;
  `slot_ir_accuracy.rs:137-138, 211-212, 279-280, 352, ...`).
- Today the only use of these values is `TableKind::Eq { point_len }`, which is used only for display and the Lean
  export tests (`slot_ir.rs:542`). It is not part of `slot_topo_key`, not part of the kernels, and not part of
  `ir_matches_closure`. So no bytes change. `lam_z` (a value used in coefficients) is set by `SC_RS`, which is not
  skipped. Trace text and any future consumer of these lengths would be wrong without any warning. Add a comment
  or a debug assertion.
- The skip predicate hard-codes table counts (26, 2, 3) instead of using the real `def.tabs.len()`. It also
  bypasses `small_slot_pays`. If a profile has more tables, a slot the unset path would send to the GPU stays on
  the CPU. This affects speed only.

### L3. The fallback log keeps only the first reason per counter

`zk.rs:369-374`: `HOST_FAST_W2_FB_LOGGED[idx]` is set on the first fallback. A later fallback for a
different reason under the same counter (for example `HF_W2_FB_SEAL_HIST`: `dd_cap`, cheat hook or
mismatch) is counted but never printed.

### L4. `range_table_helper_flat` checks fewer entries than the unset path

`protocol.rs:2542-2554` checks table membership only for `i < sup`. `range_table_helper` checks it for all
`1 << log_cols` entries (`:2520-2536`) and returns `None` (the direct inversion, which can refuse) if a padded
copy's value is outside the table. Its own comment says this never happens at a registered shape, so the
practical effect is nil.

## Answers to the eight questions

1. **Sealed histograms.** See M1 for what is compared. A full shape compare, pointer signatures for the block and
   for each witness plane, and three sampled words per plane. This is a fingerprint, not a hash or a full
   compare. A stale entry and an ABA collision are both possible in principle. On a hit the skipped checks are
   `refuse_lookup_misses` (all three families). The DD check is never skipped (`dd_cap > 0` falls back), and
   the cheat hooks fall back in test builds (`:2894-2896`). I found no current caller that reaches a stale
   entry.
2. **The two-term views and `exp_deltas` on the fly.** `LookedCol::TwoTerm` (`:1715-1724`, `:1883-1892`,
   `:2146-2160`) computes `cst + c0*p0 + c1*p1` with `wrapping_*`. The unset `word` fold
   in `looked_built` (`:1744-1770`) computes the same value in the same ring Z/2^64, and the special case `c0 = 1, cst = 0` is
   algebraically equal. `looked_cols` (`:1786`) picks `TwoTerm` from `built` and the term count only, so the
   before and after halves agree even if the switch were read differently. `exp_histogram_direct`
   (`:629-710`) equals `exp_histogram(exp_deltas(..))` (`:484-520`, `:1116-1126`). Unmasked entries use
   `mx - s8[x]`; masked entries use the constant `mx - MASK_SCORE`, exactly as `exp_deltas`. The integer counts
   and the miss total are equal, and the parallel reduce sums `u64`. The `ExpSource::Direct` fill
   (`:3180-3210`) writes the same `exp_inv[d]` at the same offsets (head-major, `t*tp + j`). Its fallback rebuilds
   the identical deltas (`:3234-3245`). No transcript absorb happens in these functions. I found no signedness
   difference: the unchecked `d as usize` index matches the unset code and relies on `exp_missed == 0` (see M1).
   The fill is at `:3180-3214` and the fallback's rebuilt deltas at `:3230-3244`.
3. **Flat W16 writer.** There is no `unsafe` in the W2-3 path. `write_helpers_w16_cols_flat` (`:2170-2249`)
   repeats the unset path's malformed-job and overlap checks with the same strings and carves `H` with
   `split_at_mut`, so the regions are disjoint and Rust checks the bounds. The tables from
   `denominator_inverses_flat` (`range16.rs:304-360`) are `1/((alpha-g)-v)`, equal to the unset table, and the
   function returns `None` if any entry is zero. The values written are `va + vb` per component, equal to
   `helper_one_any(a) + helper_one_any(b)`. Padding rows outside the jobs stay zero in both paths. On `Ok(false)`
   the unset writer rewrites every job word with `=` (`:2047-2068`), so no partly written state survives.
   The `gu8` table helper using `flat_u8_inv * m` equals `table_helper`'s 256-entry periodic result.
4. **`accuracy_fold`.** The 4-row kernels (`accuracy_fold.rs:210-313`, `:704-846`) compute the same signed
   `i64` limb sums as the unset kernels. Integer addition commutes, and the bound of at most 2^20 terms of at most
   2^38 is checked in the comment at `:58-60`. The lane mapping (`vmlal_s32` lanes 0-1 and `vmlal_high_s32` lanes
   2-3) is correct. The column tail beyond a multiple of 16 and the row remainders are handled by scalar loops
   (`:389` the rows-axis quad tail, `:431` the rows-axis remainder rows, `:824` the columns-axis tail,
   `:922` the columns-axis remainder rows). `COL_TILE = 1024` is a multiple of 16. The pad-scan skip
   (`fold_checked`, `:1119`) applies only when `pts.weights_checked`. That needs `CheckedPublic::covers_ctx`:
   the same shape, an accuracy stack, and pointer-equal `attention`, `feed_forward` and accuracy data
   (`protocol.rs:2490-2494`). It is never true on `Side::Verify` (`argument.rs:3976`). The record's check scans
   all seven matrices for `i8::MIN` (`private_block.rs:867-871`), and the folded matrices are exactly
   `ctx.public.w*` / `ctx.ff.w*_t` (`argument.rs:3141-3146`, `:3285-3289`). So the skip cannot be taken for an
   unchecked matrix. Active rows and columns are still scanned. I found nothing wrong here.
5. **`mask_eval_eq`, two rows fused** (`argument.rs:1614-1639`). This gives the same `LazyDot` integer sums
   (order-free), split into even and odd accumulators. The odd last element goes to the even accumulator. The
   result is the same as `row(mask_row) + U*row(mask_row+1)`. The sequential `eqs`/`exts` (`:2125-2155`) are
   pure functions, collected in order. I found no shared mutable state other than the atomic hit counters.
6. **Draws and transcript.** `mask_open_w2` (`zk.rs:951-1066`): `theta` is drawn before the branch, then come
   absorb `mask-q`, `challenge_fp2_vec`, absorb `mask-prox` and `challenge_indices`, in the unset order. Only pure
   work runs in parallel, and `prox` adds the same terms per coefficient. The W2-4a skip affects only the twin
   transcript clone. The histogram reuse and fast histograms run before the `A` mask draws, as before. All other
   changed code (helpers, folds, table fills, flat tables) is pure. I found no RNG draw that was moved.
7. **Unset path.** The changed shared functions are: `scan_lookup_misses` (a new `collect=false`, the same work),
   `looked_built`/`looked_cols` (a switch read only), `prove_core_before_with` (`views` built inside the else
   branch and dropped earlier, `lookup_words` from the layout, which is the same number), `prove_core_after_with`
   (restructured, the same calls in the same order), `fill_exp_helpers` -> `fill_exp_helpers_with`
   (`Deltas`; `Direct` only when `deltas` is empty, which the unset path never produces for a non-empty `Dom::S`),
   `mask_open` (one branch), `priv_table_fill`/`mask_eval_eq`/`run_slot_with` (branch checks; `has_metal`
   reduces to `def.metal.is_some()`), `fold` -> `fold_checked(.., false)` (the same as `fold_with_mode`), and
   `rope_tables`/`const_one` (`b.public` as before). The only new work on the unset path is switch reads and
   `covers_ctx`. I found no behaviour change.
8. **Fallbacks.** `SEAL_HIST` (dd_cap, cheat hook, mismatch) falls back to the full histogram path with its
   refusals. That path is the W2 non-reuse path, which is equivalent. `FLAT_W16` (misses, a zero denominator,
   an out-of-range word) falls back to the complete unset writer, which overwrites all job words. `ROPE_GEN`
   (a shape precondition in `argument.rs:2308-2361`) falls back to the unset `rope_tables_at`. The CPU
   generator equals it (the live test equals `slot_is_true_head`, and the sign follows `k(-v) = -k(v)`).
   `PIPE_CACHE` (`argument.rs:4046-4077`) falls back to `msl_round_kernels` exactly as unset. `PADS_REUSE` is
   device code and I did not read it.

## Not read

`gpu/metal.rs`, `gpu/mod.rs`, `metal_slot.rs` beyond the lines above (including `metal_slot_pipes_get_or_compile`
and the cached round entry points), `run_fork.rs`, `run_fork_tests.rs`, `token_io/classify_*`, most of
`trained_block.rs`, and test bodies in `w16r2_tests.rs`, `protocol.rs`, `argument.rs` and `accuracy_fold.rs` beyond
the parts named above. The device side of `PUB_GEN_ROPE`/`CONST_ONE` and `HF_W2_PADS_REUSE`/`PAR_OPEN` readback
is outside this read.
