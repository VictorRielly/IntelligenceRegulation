# Host wave 2, read B: device, lifetime, integration, tests

Branch `agy/host-wave2` at `83d784b26`, base `da938ecaf`. Source reading only: nothing was built or run.
Reviewer: Claude (independent read B). Line numbers are at `83d784b26`; paths are under
`ops/zkp-mvp/gpu-metal/hashline/src/`.

## Verdict in one paragraph

I found **no H-grade defect** in the scope I read. The structural pipeline cache key covers everything
I could find that shapes the generated MSL. The pads buffer belongs to one commitment and is compared
word by word before it is reused. The parallel readbacks read only after the command buffer has
completed, and they keep result order. The async dropper is bounded and frees nothing early. In every
switch combination the lookup-miss refusal runs at least once per block.

There are **three M findings**:
1. The switch does reach verifier code on R13 profiles.
2. The sealed-histogram identity is pointer-based, so it is latent rather than content-checked.
3. Integration paths that can fail have no test.

There are also nine L items.

## Findings

### M1. `HL_HOST_FAST_W2` reaches the verifier on accuracy (R13) profiles
- `private_block/argument.rs:3160` (SC_QMM..SC_WO) and `:3301` (SC_GMM..SC_DMM) call
  `accuracy_fold::fold_checked` from `define`, which both sides share (Side::Prove and Side::Verify).
- `private_block/accuracy_fold.rs:1118-1120` reads `crate::zk::host_fast_w2_on()` with no side gate and
  passes `w2` into `fold_with_opts`; `:1129-1130` then records `HF_W2_FOLD_TILED`. Only
  `skip_pad_i8_scan` is limited to the prover, through `pts.weights_checked` (`argument.rs:3976`).
- **Trigger.** A process with `HL_HOST_FAST_W2=1` in its environment that verifies an R13-stack proof
  (`verify`, `check-serve`, `input-owner` on Shieldstral R13, or the D55 run verifier). The verifier
  then evaluates the folded public weights with the W2 tiled NEON fold instead of the base fold.
- **Consequence.** The claim "the verifier is never affected" does not hold as a code property. The
  verifier's accept or reject now depends on W2-6 being exactly equal to the base fold (reader A's
  area). A W2-6 bug would show up as a verifier divergence, not only as a bad proof.
- **Precedent.** Wave 1's `HL_HOST_FAST` (`fast`, H4) already reaches the same verifier path.
- **Test gap.** The isolation gate `classify_host_fast_plus_w2_serve_gate`
  (`token_io/classify_serve_tests.rs:562`) asserts that `check-serve` moves no W2 counter. It can only
  catch this if its classifier fixture is an R13-stack profile; I could not confirm which stack that
  fixture uses.
- **Fix.** Pass the side (or `weights_checked`-style prover knowledge) into `fold_checked`, and use
  `w2 = host_fast_w2_on() && prove`.

### M2. Sealed-histogram reuse skips the CS-3 scan on a pointer-identity match, not a content match
- `private_block/protocol.rs:2367-2380`, `wit_sig`: per plane, `(ptr, len, first, mid, last)`.
  `blk_sig` (`:2349`) compares pointers and `act`. `SealedHistograms::matches` (`:2399`) is what
  `prove_core_before_with` uses (`:2898-2925`). On a hit it takes the sealed histograms with
  `w16_missed = exp_missed = act_missed = 0` and runs no scan of its own on the witness being proved.
- **Today this is safe.** The sealing-pass scan (`check_lookup_misses_collecting`) ran on the same
  allocation. I found no code path that mutates a kept witness between the seal and the proof:
  - `CliSource::witness_inner` and `CliSourceFast::witness_inner`
    (`token_io/classify_cli.rs:519-541`) only read it;
  - trained_block moves it;
  - `Witness` and `CommittedZk` have no `Drop`.
- **Latent trigger.** Any future code that edits a kept witness's planes in place (a repair pass, a
  reuse of buffers, a test helper) while keeping the first, middle and last words. The proof would
  then use the old histograms and skip the CS-3 refusal for the new content: zero scans of the actual
  data, and an invalid proof instead of a refusal. The ABA case (a freed allocation reused at the same
  address) is harmless today, because a rebuilt witness for the same block has the same content.
- **Fix.** Use a content digest (BLAKE3 over the planes, which is cheap next to the scan it saves) or
  a sealed generation id carried inside `Witness`.

### M3. Integration paths without a test
- **Classifier with `HL_HOST_FAST_W2=1` alone** (`HL_CLASSIFY_HOST_FAST` unset) has no test. This is
  the path `seal_chain_keeping` → `CliSource::witness_with_hists` → `prove_classify_run_with`
  (`token_io/classify_run.rs:557-566`). The only classifier W2 tests are:
  - the combined serve gate (both switches; hit counters plus accepted == 2, with no
    on-versus-off byte comparison);
  - the classifier part of `host_fast_w2_all_call_sites_byte_identical`
    (`private_block/w16r2_tests.rs:6508`), which hand-rolls the block loop and calls `prove_core_with`
    directly. It never goes through `seal_chain_keeping[_fast]`, `KeptWitness` or either run loop.
- **D55 trained path.** `trained_block::seal_chain`'s W2 collection (`trained_block.rs:3057-3071`,
  `:3104-3112`) and the `d55_seal_and_prove` plumbing (`:3536-3579`) are exercised only by the A22
  timing harness arms `hw1`/`ad1` (`private_block/run_fork_tests.rs:6861+`). I saw no byte gate there;
  the harness verifies only its cold request. The run_fork case in `all_call_sites` calls
  `prove_at_turn_with_hists` with histograms it builds itself.
- **Refusals.** In the files I read, no test makes a lookup miss under W2 and checks the refusal (and
  its string) through the sealing-pass collecting path, in either `seal_chain_keeping[_fast]` or
  trained_block `seal_chain`.

## L items

- **L1. Caches never shrink.** `gpu/metal.rs:106-108`: `slot_pipe_cache` and `tail_per_eval` have no
  eviction. Entries are added per distinct (topology, sc_fast) and (topology, n_vars). Every compile
  also inserts into the old `sc_pipes`, so each library is held twice. They are bounded by the number
  of shapes a process serves, which is fine for a fixed-profile server.
- **L2. The host-tail timing is frozen per process.** `gpu/metal.rs:4962-4983`: the host-tail
  `per_eval` is measured once per (topology, n_vars) and kept for the life of the process. A first
  measurement taken while the box is loaded fixes the device/host switch round permanently. This
  affects time only; by the M4k contract the bytes are the same.
- **L3. Eager compile at cold start.** `private_block/argument.rs:4046-4079`: under W2,
  `metal_slot_pipes_get_or_compile` compiles the slot library during `argument()` for every slot that
  passes the guard. That includes slots that `run_slot` later keeps on the CPU
  (`tables << n < METAL_MIN_TERMS` and not `small_slot_pays`); the base path compiled only inside
  `metal_rounds*`. This adds compile time to a cold one-shot `prove` at small shapes (toy, rung). It
  happens once per server process.
- **L4. W2-7a pads reuse saves little.** `gpu/metal.rs:1726-1742`: before each reuse,
  `as_u64s(pb, plen) == pw` reads `2 * rows * q` words, which costs about as much as the upload it
  replaces (a pooled allocation plus a copy). The retained `PBuf` stays out of the pool for the
  commitment's lifetime (about 11.5 MB per A or H store). Correctness is fine:
  - the buffer is owned by one `MetalCommit`, never shared between commitments or lanes;
  - it is compared in full against the very pads of this call;
  - the fold kernel only reads it (the base path already passed `data` as the dummy pads binding);
  - a later commit gets a fresh upload, so an open commitment's pads cannot be overwritten.
- **L5. One counter for three paths.** `HF_W2_PAR_OPEN` is incremented by `mask_open_w2`
  (`zk.rs` W2 block), the gather readback (`gpu/metal.rs:1878-1892`) and the sparse-fold readback
  (`gpu/metal.rs:2152-2167`). A counter test therefore cannot show that the gather or fold path ran.
  Their bytes are covered indirectly by the sf1 arms of `host_fast_w2_rung_golden`.
- **L6. W2-4a uses hard-coded table counts and leaves IR points unset.**
  `private_block/argument.rs:3957-3969`: the static CPU list assumes table counts 26, 2 and 3. A
  profile with more tables in those slots would stay on the CPU where the base path used the GPU
  (slower, same bytes). Skipped slots also leave their `IrPoints` lengths at their defaults, so later
  IRs carry wrong `eq` `point_len` metadata. That metadata is never used for typing.
  - `a_fixed`'s field kind depends on `pts.r_q` / `pts.r_tf`. It stays consistent only because
    QMM/KMM/VMM and GMM/UMM have equal `n` and are skipped together. This coupling is fragile.
  - A mistyped table can only fall back to the CPU (device c1 check, key includes base flags).
- **L7. Sealed histograms sit outside the witness budget.** They are not counted in the kept-witness
  budget (`classify_cli.rs:602-622`, `trained_block.rs:3104`). They hold several 2^16-entry `m_rng`
  vectors per block at W16, about MB per block, and live until the end of the run.
  `trained_block::seal_chain` collects them for every block, even ones that are not kept and even
  when `!shared` (where they are then never used), which adds memory and some scan work.
- **L8. Async dropper (`private_block/protocol.rs:2256-2288`).**
  - It is bounded: `sync_channel(1)` plus one worker, so at most two payloads are in flight across
    the process; anything else is dropped synchronously.
  - It cannot free memory early: payloads are owned values moved in after their borrowers (`views`)
    and GPU users (`drop(a)` / `drop(h)` before `a.data` / `h.data`, `:3853-3871`) are gone.
  - Costs: under memory pressure, deferred frees raise the peak by up to two payloads (about 1.5 GB
    at 125M; more at 8B). At process exit, queued payloads are never dropped; no `Drop` side effects
    exist, so nothing is lost.
  - The doc comment in `run_fork_tests.rs` (a22 `ad`) says the dropper "defaults to
    `host_fast_w2_on()`"; the code (`zk.rs:324-343`) defaults it to off.
- **L9. Test interference.** The non-ignored W2 unit tests (`zk.rs:2603`; protocol, accuracy_fold,
  range16 and argument tests) flip the process-wide W2/AD overrides. They hold `host_fast_test_lock`,
  but unrelated parallel tests do not, so those run partly with W2 on. A W2 defect would then show as
  a flaky failure in an unrelated test.
  - The non-ignored protocol test asserts an `HF_W2_ASYNC_DROP` hit, which needs `try_send` to
    succeed. If another test is draining a payload, the channel may be full and the test flakes. The
    risk is small.

## Answers by question

**1. Pipe cache (W2-4).**
- Key: `slot_topo_key` (`metal_slot.rs:223`) plus `req_sc_fast`, with `k`, `degree` and `cf_len`
  checked on a hit (`gpu/metal.rs:3181-3236`).
- I compared it with everything that `msl_round_kernels` / `node_pass` / `gen_kernel` /
  `gen_mat_kernel` / `lin_plan` / `evaluated_degree` read:
  - degree; `pad_on`; A27 switches;
  - table count and base flags;
  - node ids, bodies, factors and subterm structure;
  - term wrappers and inner factors;
  - coefficient class (One/NegOne/Base/other), which drives `coef_cost` and NegOne elision;
  - `c1.is_zero()` for base typing;
  - SC_K, SC_D and SC_SIMD_SOA, which come from `k`, `degree` and sc_fast.
- **Nothing that shapes the IR or MSL is missing.** The header comment (slot, name, profile) is not
  part of the key and has no semantics. `extract_coefs` pushes in the same order as `node_pass`, and
  a test checks this at three shapes (`w16r2_tests.rs:6037`). Coefficient VALUES always come from
  the current IR.
- Collisions: the encoding is length-prefixed and lossless, so equal keys mean equal structure. A
  metadata mismatch on a hit returns `Ok(None)` and the base path runs.
- Safety across threads and requests:
  - the read lock is released before the compile; inserts use `or_insert_with`, so two lanes racing
    compile twice and the first insert wins;
  - `ComputePipelineState` is Send/Sync and is shared the same way as in the base `sc_pipes`;
  - requests with different shapes get different keys.
- It is unbounded (L1).

**2. PUB_GEN_ROPE, SC_ZS, and skipping the CPU-slot IR.**
- The Rope descriptor (`argument.rs:2308-2356`) and its kernel (`gpu/metal.rs` kind 7) reproduce
  `rope_tables_at` exactly, including `slot_is_true_head` = `sl % per < group`, the `x < t_pad*heads*dh`
  bound (which the precondition `len == t_pad*heads*dh` enforces), and sin negation as `P - w`. The
  validators match.
- ConstOne fills the full cube; `materialize_into` asserts `len == out.len()`. Both are proving-only
  (`pub_gen_on` is `pts.pub_gen_prove`).
- The skip only removes `build_slot_ir`/MSL work for slots that would otherwise stay on the CPU
  (L6). Every slot gets a fresh transcript clone, so skipping draws nothing.
- A stale source cannot be used: there is no cached string, and the cached pipelines are
  structure-keyed.

**3. Pads reuse.** Per commitment and owned by it; verified in full before use; read-only; freed when
the commitment is dropped. No overwrite by a later commit is possible (L4).

**4. Parallel readbacks.**
- Gather (`gpu/metal.rs:1878-1892`) and fold (`gpu/metal.rs:2152-2167`) read shared memory only after
  `run_tagged` has waited for completion. They use the same raw pointer as the base `as_u64s`, and the
  layout asserts are sound.
- No Metal call is made on a rayon worker, the indexed `par_chunks_exact().collect()` keeps the
  order, and no lock is held during the readback.
- `mask_open_w2` is CPU only. It equals the base for every input: `combined_weights` always yields
  length-512 rows, so the base's reused buffers carry no stale data, and the field sums are
  order-free.
- No race found.

**5. Async drop.** See L8: bounded, safe on panic (the worker dies and later sends drop
synchronously), no early free.

**6. Device errors.**
- No new `expect`/`unwrap` on a Metal result and no new untimed wait. `metal_rounds_owned_cached`
  repeats the base `fail` panic on a deferred-build error under the same condition.
- The new `expect`s in `argument.rs:1878,2005,2040` and `protocol.rs:740` hold by construction.
- The branch does not make the known serve hang more likely.

**7. Classifier integration.**
- `KeptWitness` carries the histogram in the same tuple as its witness (`classify_cli.rs:511`), and
  `witness_inner` hands it on only when the kept witness itself is used. A rebuilt witness gets
  `None`.
- The miss check runs at the seal for every block in all four combinations, always with the same
  checks as before:
  - `collecting(false)` equals `check_lookup_misses`;
  - `collecting(true)` equals `_after_public_check`.
- In `prove_core` the check runs again unless there is a matching sealed hit. So it runs once or twice
  per block, never zero times, within the limit of M2.
- Both run loops pass `sealed_hists.as_ref()`.
- The budget ignores histogram bytes (L7). Untested combinations: M3.

**8. Verifier reach.** Yes, through `fold_checked` on R13 profiles (M1). I found no other route: the
rope/ConstOne, mask_open, seal-hist, async-drop and Metal paths are all proving-only.

**9. Tests.**
- **Byte or digest tests that would fail on a wrong byte:**
  - `host_fast_w2_rung_golden` (`w16r2_tests.rs:6266`, ignored, GPU) covers:
    - CPU hw1;
    - Metal arms with sf/sc/frs/ad and both queue modes, which exercise the warm pipe-cache hit,
      pads reuse, rope pub-gen and the readbacks;
    - sealed histograms, and the stale-histogram fallback.
  - `host_fast_w2_all_call_sites_byte_identical` (`w16r2_tests.rs:6508`, ignored) covers rung_g
    receipt bytes, run_fork L=2 and a hand-rolled classifier.
  - `host_fast_w2_rope_and_const_pub_gen_gpu` (`w16r2_tests.rs:6157`, ignored): GPU equals CPU equals
    `rope_tables_at`.
  - Non-ignored unit tests:
    - `host_fast_w2_par_mask_open_matches_baseline` (`zk.rs:2603`): bytes, transcript and
      `mask_verify`;
    - `w2_extract_coefs_matches_msl_round_kernels_and_topo_key_discriminates`.
- **Hit counters only:** `classify_host_fast_plus_w2_serve_gate` (with acceptance), and the A22 `hw`
  and `ad` arms.
- **No test:** W2-alone classifier run loops; trained_block seal/D55 plumbing as a byte gate; refusal
  under W2 through the sealing pass (M3).
- **Fallback triggers exercised:** a stale or mismatched sealed histogram (cloned witness, block or
  shape). Not exercised: the pipe-cache metadata mismatch, the `HL_METAL_DUMP` bypass, the
  pads-mismatch fallback, a rope precondition or plan decline, and the async-drop channel being full
  or disconnected.
- **Counter equalities:** strict equalities (`== 0`, `== 1`, `== 2`, `[1,0,0,0,0]`) appear only in
  `#[ignore]` fresh-process gates. The non-ignored tests use `>` deltas under `host_fast_test_lock`
  (see L9 for the remaining interference).

## What I did not read
- `protocol.rs`, `argument.rs`, `accuracy_fold.rs` and `range16.rs` beyond the call sites cited
  (reader A's area). That includes the W2 fast paths at `argument.rs:656`, `:1614` and `:2125`,
  `exp_histogram_direct`, flat W16, and the tiled fold itself. M1's soundness depends on that last one.
- `zk.rs` outside the switch/counter block and `mask_open`/`mask_open_w2`.
- The full bodies of `host_fast_w2_all_call_sites_byte_identical` (skimmed) and the C1..C5 gate in
  `classify_cli_tests.rs` (skimmed: Wave-1 classifier content only).
- The A22 harness's verification behaviour per arm.
- Which accuracy stack the classifier serve fixture uses.
