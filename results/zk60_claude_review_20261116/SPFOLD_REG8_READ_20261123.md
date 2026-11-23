# Read of agy/spfold-byvec (774adb18..ddfeb5eb): the register-only sparse fold

Reviewer: Claude (fresh read, read-only, nothing built or run). Date: 2026-11-23.
Scope: `git diff 774adb18 ddfeb5eb` (two code commits, dfb2c7f4 and ddfeb5eb), five files
under `ops/zkp-mvp/gpu-metal/hashline/`. All line numbers are at ddfeb5eb. `hl/` means
`ops/zkp-mvp/gpu-metal/hashline/`.

Labels: READ = I read the lines. INFERRED = my reasoning from what I read.

## Verdict

**Merge with named changes.** I found no well-formed input on which
`fold_rows_sparse_reg8_device` returns different field elements from the existing sparse
fold or the host reference, no out-of-bounds access, no write-write race, and no pooled
buffer returned before its command buffer completes (READ, with the arithmetic argument
INFERRED). The new kernel uses the same `gl_mul` / `gl_add` as the old one, per term, and
field addition is exact, so the change of summation order and grouping cannot change a
value. With `HL_METAL_SPARSE_FOLD_REG8` unset, the only behaviour change on existing paths
is a new stderr line when the old sparse fold errors (READ). The one finding that matters
before anyone turns the switch on: **there is no run-level byte test for the new path**
(M1). The parity evidence is kernel-level only, the call counter is shared with the old
kernel, and the stream A/B verifies receipts but compares no bytes.

## Findings

### High

None found.

### Medium

**M1. No run-level byte test pins the new path, and the call counter cannot tell the two
kernels apart.** READ: `hl/src/gpu/metal.rs:2545` increments `SPARSE_FOLD_CALLS`, the same
counter the old kernel increments at `metal.rs:2059`; there is no reg8-specific counter.
The existing run-level gate `sparse_fold_w16r2_rung_golden`
(`hl/src/private_block/w16r2_tests.rs:4116-4185`, seeded digest equal to CPU and to
`W16R2_RUNG_GOLDEN`) does not set the reg8 override (`w16r2_tests.rs:4135-4147`), so it
tests reg8 only if someone happens to export `HL_METAL_SPARSE_FOLD_REG8=1`, and even then
its `sf_delta` assertion passes for either kernel. The new `r81` arm of the stream A/B
(`hl/src/private_block/run_fork_tests.rs:7110`, `7145`) verifies receipts on pass 0 only
(`run_fork_tests.rs:7092-7098`) and compares no bytes across arms (receipts are randomised
per request, so it could not). What exists for the new path: kernel-level parity against
the host reference (22 cases, `w16r2_tests.rs:4544-4736`) and the real 8B A and H captures
compared to the reference in the ignored timing test (`w16r2_tests.rs:4518-4519`).
Concrete state: a bug that only appears when the fold is called from inside `prove_core`
(for example a capture/argument mismatch between `fold_rows_with_pads` and the kernel's
`n`/`nn`/`ir` reading for the plain form) would not be caught by any assertion today.
What would settle it: (a) add a `reg8` arm to `sparse_fold_w16r2_rung_golden` with the
override pinned `Some(true)` in both queue modes, asserting digest == CPU == golden;
(b) add a `SPARSE_FOLD_REG8_CALLS` counter and assert its delta equals the capture count
in that arm and zero in the existing arms; (c) record a green run of the new gates (all
are `#[ignore]`, so none runs in the default suite; I have no green log at ddfeb5eb).

### Low

**L1. The old kernel's tests do not pin the reg8 switch off.** READ:
`sparse_fold_device_equals_per_term_fold_word_for_word` (`w16r2_tests.rs:3937-4106`)
asserts that `k = 65` falls back (`w16r2_tests.rs:4095-4101`) and the rung golden
(`w16r2_tests.rs:4136`) pins only `HL_METAL_SPARSE_FOLD`. With
`HL_METAL_SPARSE_FOLD_REG8=1` in the environment, `fold_rows_sparse_device` delegates
first (`metal.rs:1890-1892`), so the k = 65 assertion fails and the other cases silently
test reg8 instead of the old kernel. Settle: pin `metal_set_sparse_fold_reg8_for_test(Some(false))`
in those two tests' guards, as the tick41 test already does (`w16r2_tests.rs:4345`).

**L2. A shared-code edit reaches the old path's error handling.** READ: `metal.rs:1559`,
`1614`, `1910` now call `log_sparse_fold_err` (`metal.rs:1846-1848`), an unconditional
`eprintln!` per failed fold. Before this diff the old path counted the fallback silently.
The strings are sizes and Metal status names, no field values (READ: every `Err` text in
`metal.rs:2158-2575` and `shared_buffer`/`run_tagged`). It changes no proof byte, but if
the pipeline fails to compile, every fold of every block prints a line (the reg8 path
returns `Err` from a cached `OnceLock` failure at `metal.rs:2201`, so it repeats per
call). Settle: log once per process (a `OnceLock` or `AtomicBool` gate), keep the counter.

**L3. The new kernels are compiled with the whole library even with the switch off.**
INFERRED from `metal.rs:177-190` (lazy pipelines from `c.lib`): the new MSL is part of the
single source compiled at context start, so a compiler that rejects it would turn off every
Metal path, not only reg8. It compiled on the author's M3 Ultra (stated, not checked by
me). Settle: nothing beyond noting it; the same holds for every earlier kernel addition.

**L4. Multi-block chunks with a partial last chunk are covered, but the budget-limited
block count is not.** READ: shapes at `w16r2_tests.rs:4626-4643` cover multi-block chunks
with `ck = 1` (`k=1 rows=180`), `ck = 7` (`k=7 rows=200`) and `ck = 8`; nothing drives
`max_by_mem` below `target` (`metal.rs:2332-2343`) or `total_cols >= 262144` (target 1).
INFERRED: the block count only changes the row partition, and the sum is exact under any
partition, so the risk is low. Settle: one case with large `total_cols` if cheap.

**L5. The test switches are public in non-test builds.** READ: `set_sparse_fold_reg8_for_test`
(`metal.rs:1828`) and its re-export (`hl/src/gpu/mod.rs:52-59`) are not `cfg(test)`, same
pattern as the existing `set_sparse_fold_for_test`. No non-test caller exists at ddfeb5eb
(READ: `git grep`). Settle: none required.

## Answers

| # | Question | Answer |
|---|---|---|
| 1 | Same output | Yes for every well-formed input I could construct (READ + INFERRED). Same `gl_mul`/`gl_add` as the old kernel (`metal_kernels.metal:22-64`, used at `1068-1079`), canonical out of both; zero rho and zero data words skipped in both; `g_map` built from the sorted order (`metal.rs:2262-2267`) and output read back by original index `g` (`metal.rs:2547-2568`); per-chunk CSR offsets are chunk-relative (`local_terms` reset per chunk, `metal.rs:2273`) and every section, including `term_r` after ddfeb5eb, is 256-byte aligned (`metal.rs:2383-2394`); `blocks == 1` writes `out[g_map[lg]]` directly, `blocks > 1` writes `part[b][lg]` and reduce writes `out[g_map[lg]]` (`metal_kernels.metal:1084-1103`, `1106-1124`); vectors with no terms are zero on the host (`metal.rs:2548-2549`); pads read as column `j - n` with stride `q` (`metal_kernels.metal:1054-1056`), same as the old kernel. Only difference: `k > 64` now runs on the GPU instead of falling back to the host fold, which gives the same values. |
| 2 | Memory safety | Sound (READ). `meta_alloc` and `part_alloc` are always >= the required bytes (`.min(max_buf.max(req))` never goes below `req`; above `max_buf`, `shared_buffer` returns `Err`); copies land at 256-aligned offsets inside `meta_cursor`; `set_len` follows exactly `total_cols` writes from `chunks_exact(2)` over `2 * total_cols` words. Row indices are `i < rows` built on the host (`metal.rs:2274-2291`), term and block indices are built in the same function; `rows`, `total_cols` bounded by `u32` checks (`metal.rs:2186`). Data-column reads rely on `j*ir + row*nn` being inside the store, the same unchecked assumption as the old kernel. No two threads write the same word: distinct `(j, b)` per thread, distinct `g` per chunk. |
| 3 | Pooled buffers | Claim holds (READ). Every `out` word of an active vector and every `part` word of a multi-block chunk is written before it is read (empty row blocks write zeros); inactive vectors are never read from `out_buf`. All four `PBuf`s are locals of the closure and drop after `run_tagged` has waited (`metal.rs:965-986`, `wait_done` returns only on Completed or Error) and after the copy-out; every early `?` happens before commit. |
| 4 | Privacy | No new exposure (READ). Timing statics and their stores are all `cfg(test)` (`metal.rs:2117-2136` and each store). `trace_detail` prints counts only, as the old path did. The old path also put pads (`upload`, `metal.rs:2001`), rho terms and block partials in pooled buffers; the new path does the same (`metal.rs:2440-2462`), with `term_r` moved into `meta_buf`. The ignored tick41 test prints the zero-word share of the synthetic data matrix (`w16r2_tests.rs:4386-4393`); test-only, synthetic input. |
| 5 | Failure | Safe (READ). Every `Err` and `Ok(None)` goes to the host fold (`fold_rows_host_by_form` or `fold_segments_a8_opts`), which is the byte reference; the fallback is counted once (`metal.rs:1560`, `1615`, or inside reg8 for `Ok(None)`) and now logged (L2). No partial result escapes: output is built only after `run_tagged` returns `Ok`. |
| 6 | Switch and default | Read once per process through a `OnceLock` (`metal.rs:1816-1825`), default off, reached only when `HL_METAL_SPARSE_FOLD` is on; test override checked first. With it off, no byte changes; edits to shared code are the log line (L2), the timing label and a `cfg(test)` TG-memory floor whose default 0 leaves `tg_bytes` unchanged (`metal.rs:1916-1919`). Parity tests call the reg8 function directly or force the override, so they are not vacuous; the call counter is shared, so no test can show which kernel ran inside a proof (M1). |
| 7 | Coverage | Kernel parity, 22 cases (`w16r2_tests.rs:4544-4736`): k = 0, 1, 7, 8, 9, 16, 37, 70; q absent, 0, 1, 7, 280; ir 1 and 3; rows 0 and 1; active rows 0, 127 (one block), 128 (two blocks); mixed zero vectors; scrambled `g_map` with two multi-block chunks plus a one-row chunk; delegation at k = 70. Plus real 8B A (k = 37) and H (k = 10) captures vs reference in the ignored tick41 test. No largest-k case beyond 70 (there is no cap). No run-level byte test with the switch on vs off (M1). All `#[ignore]`; only `a22_arm_parses_r80_and_r81` runs by default. |

## Not read or not established

- I built and ran nothing; I have no green log of the 22-case test, the tick41 test or the
  stream A/B at ddfeb5eb. The author's "22 of 22" matches the case count I read.
- I did not read `a8_reference` or the host Fp/Fp2 code; I took as given that host field
  values are canonical and that `a8_reference` is the per-term fold (it is the reference
  the merged old-kernel tests already use).
- I did not check Metal's ordering guarantee beyond the encoder being serial with default
  hazard tracking (`metal.rs:970`, `680`); the old kernel relies on the same partial then
  reduce order inside one encoder.
- I did not read `upload_words`, the fork scheduler, or how six prover threads reach the
  pool beyond `pool_take`/`pool_put` (`metal.rs:641-661`, mutex-protected).
- I did not compare timings or check the measured 5.530 to 1.401 ms figures.
