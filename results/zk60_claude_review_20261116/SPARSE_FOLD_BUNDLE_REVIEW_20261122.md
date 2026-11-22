# Second read: sparse fold bundle (`651abb96..5afee227`, branch `agy/composed-frs-sf`)

Read-only review. Nothing was built, run or timed. All line numbers are at commit `5afee227`.
Paths are under `ops/zkp-mvp/gpu-metal/hashline/src/` unless stated.

## (a) Verdict

- **Whole commit, with `HL_METAL_SPARSE_FOLD` off by default: yes, with conditions.**
  The conditions are M1 (re-run the gates on this composed commit) and M2 (build the two new
  pipelines lazily, or accept the eager build in writing). Neither is a correctness defect.
- **Part 2, stride-4 `mask_open` (always on): yes.** It equals the old code for every input
  that can reach it. The geometry is fixed by constants, so no profile can take another path.
  The identity is exact in the field. It draws no randomness and reads no secret-dependent
  index. A differential test against a verbatim copy of the old body runs in the default suite.
- **Part 3, `w16_histograms_cols` (always on): yes.** It equals the old code for every input.
  The u32 bins cannot overflow because of a guard on the total word count. Misses, U8 versus
  Range, `Term` forms, wrapping, multi-chunk and empty columns are handled like before. A
  differential test against the still-live reference runs in the default suite.
- **Turning the sparse fold ON (not part of this merge): not yet.** First M3, M4 and M5 must
  be settled.

## (b) Findings

### High

None.

### Medium

**M1. The gate evidence is for another tree.** The write-up says the branch started from
`f323bb82`. This commit puts the change on top of `651abb96`, which already holds the fused RS
encoder. The 11/11 parity table and the A/B were measured on the old base. The write-up
(`results/zk60_c2c3_sparse_fold_20261120/README.md`) is not in the commit or in any branch
(`git log --all` finds nothing), so its guard run IDs cannot be checked from the repository.
*Fix:* on `5afee227`, run the default lib suite (this covers both always-on parts through
`zk_f12_tests.rs:232`, `w16r2_tests.rs:4155` and the pinned W16R2 rung golden at
`w16r2_tests.rs:322`). Run the two ignored sparse tests by name. Commit the write-up next to
the record.

**M2. With the switch off, start-up still changes.** `gpu/metal.rs:46-47` adds
`k_fold_sparse_partial` and `k_fold_sparse_reduce` to the eager `KERNELS` list. `ctx()` builds
every listed pipeline (`metal.rs:100-104`), and one failure makes the whole Metal context fail.
Under `HL_GPU_REQUIRED=1` that is a panic (`metal.rs:155-156`); otherwise every user drops to
the CPU. The sibling fused encoder keeps its pipelines in a lazy `OnceLock`
(`metal.rs:81`, `122-140`) for exactly this reason. Note that a *compile* error in the new MSL
would break everyone in both designs, because all kernels share one source (`metal.rs:98`).
Only the pipeline-creation step differs. The risk is small, but "switch off means the old code
runs" is not literally true. *Fix:* move the two pipelines into a `OnceLock<Result<..>>` like
`fused_rs_pipes`, and let a build failure return `Ok(None)` from `fold_rows_sparse_device`.

**M3. A device error does not fall back. It panics the prover.** The write-up says
"automatic fallback". That holds only for the limit checks (`k > 64`, threadgroup memory, u32
ceilings: `metal.rs:1763-1765`, `1778-1780`, `1799-1801`). Any `Err` (buffer allocation, a failed
command buffer, a pad-length mismatch) is returned by `?` at `metal.rs:1485` (plain path) and
`Some(Err(e))` at `metal.rs:1540` (hiding path). zkp-core then calls `expect` on it
(`zkp-core/src/pcs.rs:332`, `983`), so the whole proof panics where the old host fold could
not fail. This fails closed, so soundness is unaffected. It only matters with the switch on.
*Fix:* map `Err` from the sparse path to the host fold, and count it, or state "fail closed" in
the write-up and the switch's doc comment.

**M4. No proof that the sparse path ran inside a proof.** Unlike `FUSED_RS_CALLS`
(`metal.rs:183`), the sparse fold has no call counter. Inside a proof, the rung golden test
(`w16r2_tests.rs:4097`) checks only that the digest equals the CPU digest. A run that silently
fell back on every fold would also pass. The test replays the captured folds through
`fold_rows_sparse_for_test` and panics on `None` (`w16r2_tests.rs:4131-4143`), and the limit
checks are deterministic, so for the rung this is good indirect evidence. The `m1_*` tests in
`tests/zk60_metal_commit.rs` take the sparse path only when the environment variable is set,
and they cannot tell either. *Fix:* add `SPARSE_FOLD_CALLS` and `SPARSE_FOLD_FALLBACKS`
counters, and assert exact deltas in the rung test and in the `m1_*` tests under
`set_sparse_fold_for_test(Some(true))`, holding `METAL_TEST_LOCK`, as the fused encoder's
tests do.

**M5. The installed profile's shapes are not in the kernel parity test.** The shapes at
`w16r2_tests.rs:4019-4035` (the `shapes` array) reach n = 1024 and at most 512 rows. None
has n = 2^14 with 38, 2,504 or 2,606 rows and q = 280, or n = 2^12 with 76, 41 or 38 rows and
q = 256, or n = 2^8 with 6 rows and q = 256. Those shapes choose other block counts: for
2,606 rows at n + q = 16,664, the code picks up to 16 blocks, capped by 128 MiB
(`metal.rs:1812-1816`). The write-up's A/B at `W16R2_8B_T128_H24` is a throughput run. I did
not verify that it compares proof bytes across arms. *Fix:* add those seven
(rows, n, q, ir) shapes, with a realistic k from a capture, to
`sparse_fold_device_equals_per_term_fold_word_for_word`. Or capture folds from one
`W16R2_SHIELD_T128_H24` proof and replay them as the rung test does.

### Low

- **L1.** `sparse_fold_on()` reads the environment on every fold (`metal.rs:1704-1709`). The
  fused switch caches it in a `OnceLock` (`metal.rs:292`). This is cheap, but it is an extra
  read on the switch-off path, and it can race with `set_var` in tests. Cache it.
- **L2.** The u64 instantiation of the histogram (`private_block/protocol.rs:1803`) is never
  executed by a test, because it needs more than 2^32 words. The generic body is shared, so
  the risk is nil. A test-only override that forces `u64` would make it executed code.
- **L3.** In the histogram, `position(..).expect(..)` now runs for every lookup, including
  empty columns (`protocol.rs:1791`). Before, it ran only for non-empty chunks (old body; the
  same check in the reference at `protocol.rs:865`). This differs only for a layout whose
  lookup width is not a range family, which `Layout` does not produce. No action needed.
- **L4.** `mask_open` now reads the a-rows from `mc.encoded` (`zk.rs:676-677`), not from
  `mc.a_coefs`. It relies on `encoded` being the coset-7 encoding of `a_coefs`. That holds for
  all three constructors (`zk.rs:484`, `535`, `zk_f12_tests.rs:53`), and `git grep` finds no
  other construction, but the fields are `pub`. *Fix:* one sentence on `MaskCommit` stating the
  invariant, or a `debug_assert` that compares one point.
- **L5.** New `assert!(ntt.max_log >= MASK_LOG_DOM)` in `mask_open` (`zk.rs:640`). The new body
  needs only 2^10. Every caller passes the same table that `mask_commit` already needed at
  2^12, and `private_seam.rs:167` pins 12. Harmless, but it is a new panic on the prover path.
- **L6.** With the switch on, `pads_buf` (a copy of the ZK pads), `part_buf` (per-block partial
  folds, never published) and `out_buf` go back to the process-wide buffer pool on drop
  without clearing (`metal.rs:1852`, `1870`; pool at `metal.rs:537-597`). This matches the
  existing M4f policy, where commitment data buffers are pooled the same way. It stays inside
  the process and never enters a proof. Mention it in the privacy notes when the pool is next
  reviewed.
- **L7.** The two new GPU tests are `#[ignore]` and change process-wide state (`HL_GPU`, the
  queue mode, the sparse override) without a lock (`w16r2_tests.rs:3936`, `4096`; their ignore
  text says "run alone by name"). `METAL_TEST_LOCK` lives in the integration test binary
  (`tests/zk60_metal_commit.rs:44`) and cannot be shared with in-crate tests. This is
  acceptable, but the rung test's `Reset` guard is the only protection.
- **L8.** No test or A/B covers both switches on together (`frs1+sf1`). The arm parser test
  only parses the words (`run_fork_tests.rs`, the `a22_arm("harness4+ba1+frs1+sf1")` check).
  The two touch different steps (encoding versus opening fold), so I expect no interaction,
  but nothing measured shows it.
- **L9.** The README's "0 new .rs files" and "0 zkp-core edits" are true for this diff. Its
  "100% proof-byte-identical" is shown for the rung and the unit shapes, not for the installed
  profile (see M5).

## (c) Answers

### Q1. Equality for every input

**`mask_open` [READ + ARGUED].**
- *When the stride-4 path runs:* always. There is no condition, because `m = 2^9`, `m2 = 2^10`
  and `dom = 2^12` are constants (`zk.rs:391-392`), and no profile, rate or Q moves them. The
  mask geometry does not depend on the PCS rate (W16R2 rate 1/2, W16R3 rate 1/3) or on the
  blinding count. Those belong to the regular commitments, not to `M`. The mask length is
  bounded by `part.len() + MASK_Q <= m`, asserted in `mask_commit` (`zk.rs:460`, `511`).
  `ws[s]` always has exactly 512 entries (`combined_weights`, `zk.rs:553`). The old body
  survives only as `#[cfg(test)] poly_mul_512` (`zk.rs:605-606`) and its copy in
  `zk_f12_tests.rs:183`.
- *The identity:* `a(X)` and `w(X)` have degree at most 511, so `P = a·w` has degree at most
  1022, which is below 1024. `mc.encoded[r*4096 + i]` is `a_r(7·ω_4096^i)`
  (`encode_coeffs_coset`, `zk.rs:442-446`). The NTT is in natural order and takes every size's
  root as a power of the largest table's root (`zkp-core/src/ntt.rs:53-57`, `88-99`), so
  `ω_4096^4 = ω_1024` for any `max_log` of 12 or more. So `encoded[4j] = a(7·ω_1024^j)`. The new
  code evaluates `w(7X)` on G_1024 (`zk.rs:665-675`), multiplies pointwise with the Fp2 rule
  `U^2 = 7` (`zk.rs:678-685`), sums over `s`, runs one inverse 1024-NTT, giving the
  coefficients of `P(7X)` (exact, because the degree is below 1024), and multiplies coefficient
  `i` by `7^-i` (`zk.rs:688-694`). Every operation is linear, and the result is the exact
  polynomial `sum_s a_s·w_s`, which the old code formed by four cyclic 1024-products per mask
  (exact for the same degree reason).
- *Byte equality, not just field equality:* `Fp::add`, `sub`, `mul` and `neg` return canonical
  words for canonical inputs (`zkp-core/src/field.rs:27-58`, `103-116`). `b` comes from
  `ZkRng::fp_vec` (canonical, `zkp-core/src/rng.rs:328-344`) and `neg`. In the branch where all
  weights are zero (`zk.rs:696`), `q = b` with no `add`, while the old code did `b + 0`. These
  agree for canonical `b`, which every constructor gives.
- *Skipped masks:* when `ws[s]` is all zero (`zk.rs:657`), the old code added
  `poly_mul(a, 0) = 0`. Same result.
- *Tables:* `mask_coset_tables` (`zk.rs:621-634`) holds `7^i` and `7^-i`, public constants
  only, built once in a `OnceLock`.
- *Region not shown:* none for honest inputs. A `MaskCommit` with an `encoded` that does not
  match its `a_coefs` would give a different `q` (L4). Only tests could build one, and none does.

**Histograms [READ + ARGUED].**
- *Overflow:* each word bumps at most one bin of the one local histogram that holds it. Locals
  are reused and keep accumulating (`protocol.rs:1735-1739`, Drop at `1677-1686`), so one bin
  counts at most `total_words`. u32 is used only when `total_words <= u32::MAX`
  (`protocol.rs:1800`). `total_words` sums `c.len()` over all columns, which equals the words
  put into chunks. The merged totals are u64 (`protocol.rs:1752-1767`), the same type as
  before. `missed` stays `usize`, as before.
- *Indices:* `u = v as u64` reinterprets the i64 (`protocol.rs:1694`). A negative `v` becomes
  at least 2^63, above any `lim` (2^w or 256), so it is a miss, as in the old
  `(0..n).contains(v)`. Non-negative values compare the same way. `slice[u]` is indexed only
  after `u < lim`.
- *U8 versus Range:* a U8 miss bumps `slice[0]` (the U8 bins start at 0) and `missed`
  (`protocol.rs:1697-1702`). A Range miss bumps only `missed`. Same as the old body and the
  reference (`protocol.rs:854-873`). Pinned by step 4 of the new test.
- *`Term` forms:* `c = 1, cst = 0` gives `v`, `c = 1` gives `cst.wrapping_add(v)`, and other
  `c` give `cst.wrapping_add(c.wrapping_mul(v))`. Identical to `LookedCol::fill`
  (`protocol.rs:1581-1588`).
- *Multi-chunk and empty columns:* chunk bounds as before (`step_by(1 << 16)`). An empty input
  gives zero vectors of the same shapes.
- *Duplicate widths:* `position` takes the first family, as before.
- *Region not shown:* the `u64` instantiation above 2^32 words is not executed (L2).

### Q2. The old path and the differential tests [READ]

- `mask_open`: the old body is kept as `poly_mul_512` (`#[cfg(test)]`, `zk.rs:605`) plus the
  verbatim reference `mask_open_poly_mul_reference` (`zk_f12_tests.rs:183`). The test
  `mask_open_stride4_matches_poly_mul_reference_byte_for_byte` (`zk_f12_tests.rs:232`) is a
  plain `#[test]` in the default suite. It covers 0, 1, 2 and 23 masks, empty and all-zero
  functionals, untouched rows, multi-row functionals, and tables of 2^12 and 2^16. It compares
  `q`, `prox`, `columns`, serialized bytes and the transcript state, then runs `mask_verify`.
  The mask geometry is constant, so the profile list does not apply to this part. The 23-mask
  case matches the W16R2 slot count. Every pinned golden digest in the default suite also
  exercises the new body end to end.
- Histograms: the reference `w16_histograms` (`protocol.rs:840`) is still production code. It
  runs under `HL_A17_LOOKED=0` and for non-view W16 shapes (`protocol.rs:663`, `2409`). The
  test `w16_histograms_cols_u32_matches_reference_with_and_without_misses`
  (`w16r2_tests.rs:4155`) is a plain `#[test]`. It covers the W16R2 rung witness, a mutated
  witness, all `LookedCol` variants, a column longer than 2^16, empty columns, U8 versus Range
  semantics, and an empty input.
- Sparse fold: the old path is the default. The kernel test (`w16r2_tests.rs:3937`) and the
  rung test (`w16r2_tests.rs:4097`) are `#[ignore]`. The `m1_*` tests take the sparse path only
  under the environment variable. None of the listed installed-profile commitment shapes is in
  the kernel test (M5).

### Q3. Zero-knowledge [READ + ARGUED]

- `mask_open` draws only transcript challenges (`theta`, the `rs` vector, the column indices),
  in the same order and with the same absorbed labels and values (`zk.rs:642`, `699`, then the
  unchanged tail). No `ZkRng` is involved.
- Static or shared state: only the public power tables (`zk.rs:621-634`). The scratch vectors
  in `mask_open` are locals. The histogram pool is a local `Mutex` that is dropped when the
  call returns (`protocol.rs:1736`, `1755`). Nothing secret outlives either call. Sparse fold
  (switch on only): pooled Metal buffers keep pads and partial folds after the call (L6).
- Secret-dependent control flow: `mask_open` branches on `ws[s]` being zero, which comes from
  public functionals and `theta`. Its stride-4 reads use fixed public indices. The histogram's
  bin index and miss branch depend on witness values, exactly as before. In the sparse kernel,
  `if (v == 0UL) continue;` (`metal_kernels.metal:973`) skips zero data words. The host fold it
  replaces does the same (`metal.rs:2472`), and so do the existing device kernels
  (`metal_kernels.metal:858`, `892`). The active-row list is built from the `rho` vectors,
  which are verifier challenges.

### Q4. The switch [READ]

- *Switch unset:* the fold paths call `sparse_fold_on()` (one environment read, L1) and then
  run the old code unchanged (`metal.rs:1484-1492`, `1531-1544`). The one other switch-off
  difference is the eager pipeline build (M2).
- *Fallback:* `k > 64`, `rows > u32::MAX`, `nnz > u32::MAX`, too little threadgroup memory, or
  under 32 threads per group all give `Ok(None)`, and the old path runs. Device errors do not
  fall back (M3).
- *Precedence:* `HL_METAL_DEVICE_FOLD=1` runs first on the plain path (`metal.rs:1475-1477`).
  `A8Form::M11` and the device fold return `None` on the hiding path before the sparse check
  (`metal.rs:1508-1516`).
- *Threads and queues:* no new shared mutable state beyond the existing buffer pool (a mutex)
  and the read-only `Ctx`. `run_tagged` waits on its own command buffer on either queue mode
  (`metal.rs:901-922`). The partial and reduce dispatches share one serial encoder, the same
  pattern as the existing `k_fold_partial`/`k_fold_reduce` (`metal.rs:1621-1625`).
- *Scratch memory:* the partial buffer is capped at about 128 MiB per call (`metal.rs:1814`),
  plus the output (k × (n+q) × 16 bytes, about 17 MiB at k = 64, n + q = 16,664), the pad copy
  and small metadata. The cap is per call. Concurrent fork workers each hold their own.
- *Pool invariant:* every word the kernels or the host read is written in the same call: the
  meta sections, `term_r`, every `part[b][g][j]` (blocks with no rows write zeros), and every
  `out[g][j]`.
- *Both switches on:* they touch different steps. No test covers them together (L8).

### Q5. Verifier and transcript [READ]

| Hunk | Class |
|---|---|
| `zk.rs:605` `#[cfg(test)]` on `poly_mul_512` | prover-only helper, now test-only; the verifier never called it (`mask_verify` uses `weight_polys` and `encode_coeffs_coset`, unchanged, `zk.rs:718+`) |
| `zk.rs:619-634` `mask_coset_tables` | prover-only |
| `zk.rs:636-698` `mask_open` body | prover-only; absorbs `mask-q` with the same `q` (`zk.rs:699`); the tail is unchanged |
| `protocol.rs:1641-1804` histogram types and `w16_histograms_cols` | prover-only (the sealing preflight `protocol.rs:661` and `prove_inner` `protocol.rs:2407`); the verifier has no witness |

There is no change to `mask_verify`, `mask_verify_tagged`, `combined_weights`, transcript
labels, serialization (`MaskOpening::write_bytes` is untouched) or zkp-core.

### Q6. Tests [READ]

- The CPU tests for parts 2 and 3 are not vacuous. They compare against the old code, and step
  3 asserts `missed > 0` so that the miss branches are exercised.
- The kernel test cannot pass by falling back: it panics on `None` except in the deliberate
  `k = 65` case. On a machine without Metal, `ctx()` returns `Err` and the test panics rather
  than skipping.
- The rung test is vacuous on one point only (M4): it cannot tell whether the folds inside the
  proof took the sparse path.
- None of the new Metal tests takes `METAL_TEST_LOCK` (L7).

### Q7. Hygiene [READ]

- New `unsafe`: three `copy_nonoverlapping` calls into freshly sized shared buffers
  (`metal.rs:1856-1867`), with SAFETY comments that hold (the offsets are 256-aligned and
  disjoint, and `meta_bytes` covers the last section). There are also two test-only slice
  reinterpretations of `u64` as `Fp` (repr transparent).
- Casts: `k as u32` (k ≤ 64), `blocks as u32` (≤ 16), row and term indices after their u32
  checks, and `i64 as u64` used on purpose in the histogram. I found none that can truncate.
- Prover-path panics: `zk.rs:640` (L5) and `protocol.rs:1755` (pool poisoned; it can only
  follow another panic).
- Debug output: `eprintln!` only under `HL_METAL_TIMING=1` or in tests. `trace_detail` is the
  existing trace hook.
- Public repository: no keys, personal data or absolute paths in the diff.

## (d) What I read and what I did not

**Read:** the full diff of all eight files. In full at `5afee227`: `mask_commit`,
`mask_commit_tagged`, `combined_weights`, `weight_polys`, `mask_open` and `mask_verify` in
`zk.rs`; `zkp-core` `ntt.rs`, the `Fp` arithmetic in `field.rs`, `ZkRng::fp`/`fp_vec`,
`pcs::coset_powers`, `fold_rows_multi_zk` and the external-store `expect` sites; `LookedCol`,
`looked_built`, `looked_cols`, the reference `w16_histograms` and both histogram call sites in
`protocol.rs`; `Ctx`/`ctx()`, the fused-RS lazy pipelines, the buffer pool, `run_tagged`, both
`MetalCommit` fold paths and the host `fold_rows_host` in `metal.rs`; the Metal `gl_add`/`gl_mul`
helpers; the `METAL_TEST_LOCK` and `SHAPES` in `tests/zk60_metal_commit.rs`; `a8_reference`; the
F12 test commit helper; all `MaskCommit` constructions and `mask_open`/`mask_commit` call sites.

**Not read or not done:** I ran nothing (no build, no test, no timing). I did not check
`gl_reduce128` (it is existing code under the M0 field test), the rest of
`tests/zk60_metal_commit.rs`, the a22 stream harness beyond the diff, or whether its A/B
compares proof bytes. I did not reproduce any number in the write-up, and did not look under
`.agy-worktrees/`.
