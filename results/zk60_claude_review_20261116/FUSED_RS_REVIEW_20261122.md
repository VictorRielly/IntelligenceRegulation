# Second read: fused RS encoder (f3bd2646 on f323bb82), 2026-11-22 00:16Z

Source reading (READ) unless marked VERIFIED. Paths under ops/zkp-mvp/gpu-metal/hashline/, lines at f3bd2646. No build, test or GPU run.

## Verdict

- Merge with the switch off by default: **yes with conditions** (M1 to M3 below, all small).
- On by default later: **not yet**. Close the test gaps first. The arithmetic reads correct.

## Answers

1. **Switch off (READ).** Order of GPU work, bytes and trace text are unchanged. Edits outside the switch:
   - `KERNELS` 23 to 28 (src/gpu/metal.rs:32). `ctx()` (~85-95) compiles the longer source and builds all pipelines eagerly, so a failure in a new kernel would disable the GPU path even when off, and first use is slower.
   - `use_fused_rs` (line 2230) returns false at `fused_rs_on()` before any pipeline lookup. The trace suffix is empty when off (VERIFIED: off-leg trace has no `frs=1`).
   - Timing branch, old arm: same calls, re-indented.
   - Rest is inert (structs, counter, public setters).
2. **Dispatch (READ; VERIFIED on traces).** One place: `can_encode_fused_rs`, line 401, called once at 2230. Needs: env exactly "1", not `HL_METAL_STAGED`, log_n 12 to 14, rate_log 1 or 2, q <= n, fused pipeline allows 512 threads. Else the old path, no error. At rate 2, q > n never arrives (the `n + q > nn` error at ~2218 comes first). At rate 4, q == n takes the fused path; the tests' "q == n" is rate 2 only, where it is just the maximum.
3. **Data dependence (READ).** None new. Branches are `idx0 < q`, `idx1 < q` (public index, public q), the mode word, and fixed-trip loops with uniform barriers. The kernels reuse `gl_add`, `gl_mul`, `gl_mul_pow2` (value-dependent selects, same as the old path). Whether the compiler predicates them: not verified, not new.
4. **Coverage** (traces VERIFIED; 8B READ):

| shape | fused? | parity test |
|---|---|---|
| 2504, 2606 rows; 14, 2, 280 | yes | exact |
| 38 rows; 14, 2, 280 (trace, 1458 per run) | yes | same kernels, row count not tested |
| 38, 41, 76 rows; 12, 4, 256 | yes | (12,4,256,130) |
| 6 rows; log_n 8, ir 8 | no | log_n < 12 fallbacks (10 and 3) |
| 8B W16 A, 2504 x 2^14 | yes | the 2504 test |
| 8B bench, log_n 15 | no | (15,2) fallback |

   - The classifier test's "boundary" shape (38 rows, 14/4/256) is not what the trace shows (38 rows at 14/2/280). 14/4/256 is covered by (14,4,256,5).
   - No fused shape lacks a parity test.
   - Gaps: q == n at rate 4; `HL_METAL_HEAD_TW=0` and `HL_A27_NTT=0` (kernel arms `use_hw=0`, `pow2=0` never run).
5. **Anti-vacuity.** `FUSED_RS_CALLS` (metal.rs:143) is bumped at the decision. Asserted in the zk direct-commit section and both classifier sections. **Not** asserted in the plain-RS section (4 shapes) nor in the commit_zk/open_zk section of the large test; those can pass with the fused path off, though they also compare to the CPU.
6. **Arithmetic (READ, consistent).**
   - Pass 1 twiddles `k << (max_log - s)` with k = 2048*i + lo: right.
   - Pass 2: stage 11, then pairs (10,9) to (4,3), then (2,1). 1/n applied once, and the tail has `apply_scale 0`.
   - Sub-tile mapping (rate 2: p0 = 2048b + 1024h + 2tid; rate 4: 2048b + 512h + tid) matches the register stash, and each output tile (b << r) + h is written once.
   - Pads enter at coefficient n + idx, coset pows by coefficient (idx, n + idx). This matches `head_input` mode 2 for q <= n (the old `pad[j] - pad[ns+j]` term needs q > n).
   - `idx1 = idx0 + n/2` is right for even p0. Plain mode has no coset shift, as before.
   - Struct layouts and buffer slots 6-9 match.
7. **Metal.**
   - 16 KiB `sh[2048]` matches the existing `k_ntt_head_t` (READ).
   - Barriers are in uniform control flow, and the barrier after the register stash guards the rewrite (READ).
   - Indices bounded; large offsets are ulong; `max_log - 12` cannot underflow (READ).
   - Not verified against Apple documentation: the 32 KiB limit, and 512 threads under this register load (the host falls back if refused).
8. **run_fork_tests.rs (READ).** Adds `frs0`/`frs1` words, a parse test, and `set_fused_rs_for_test(a.frs)` in apply and reset. With no word it passes None (environment decides, off). The settings log line gains ", fused rs {}"; check any parser of it.

## Findings

**High**: none.

**Medium**
- M1. Global override and counter are shared; the two new tests use separate mutexes (zk60_metal_commit.rs:233, :404), and other tests in the file run unlocked. Races can give a spurious failure or a satisfied `> before`. Fix: one shared lock or `--test-threads=1`, exact deltas.
- M2. Counter not asserted in the plain and commit_zk sections; q == n at rate 4 untested. Fix: assert there; add (12,4,4096).
- M3. Eager pipeline creation when off (metal.rs:32, ~89): "nothing changes" holds for results, not start-up or failure mode. Fix: lazy creation, or state it in the write-up with a cold-start timing.

**Low**
- L1. Classifier "boundary" shape differs from the traced 38-row shape.
- L2. `use_hw=0` and `pow2=0` kernel arms untested.
- L3. Setters and counter are public library API, not test-only.
- L4. Stream gain +2.95 percent is under its own +3 bar (performance, not safety).

## Not checked

Compilation and test runs; Apple documentation limits; GPU timing side channels; the source-hash pins in ops/zkp-mvp/gate-tinyllama/staging_v25 (zk60_native_rg_r26readings.py), whether still live gates; transform re-derivation; the write-up's performance tables.
