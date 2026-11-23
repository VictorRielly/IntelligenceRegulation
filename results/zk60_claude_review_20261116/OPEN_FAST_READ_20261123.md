# Read of agy/open-zk-fast (774adb18..8023c46d): the opt-in fast opening

Reviewer: Claude (fresh read, read-only, nothing built or run). Date: 2026-11-23.
Scope: `git diff 774adb18 8023c46d` (two commits, 68c87af3 and 8023c46d), all under
`ops/zkp-mvp/gpu-metal/hashline/`, compared against the core `open_zk` in
`ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs` (the path dependency named in
`hashline/Cargo.toml:33`). All line numbers are at 8023c46d. Paths below are short:
`hl/` means `ops/zkp-mvp/gpu-metal/hashline/`, `core/` means `ops/zkp-mvp/gpu-metal/zkp-core/`.

Labels: READ = I read the code. ARGUED = my inference from what I read. NOT CHECKED = I did not look.

## Verdict

**Merge with named changes.** I found no way for the fast path to emit different bytes
from the core path on any well-formed input, and no new read, log or retention of a
private value (ARGUED from READ code). The opening draws no prover randomness at all:
pads and salts are drawn at commit time, which this branch does not touch (READ). The
transcript order, the claim grouping, the row weights and the outputs match the core
step for step (READ). The skipped tables (`cw`, dense `row_w`, `wants`) are never read
by the core prover (READ). The host gather reads a shared buffer whose only writer is
the commit's command buffer, which is waited on and status-checked before the
`MetalCommit` exists (READ). The changes I ask for are small and none blocks safety
with the switches off: (1) the source-pin test that guards the opening's soundness
order pins only the core `open_zk`, not the new prover body, so a future core change
(W16R3) would leave the fast path on the old protocol with only a Metal-only test to
notice; (2) one stray non-swap edit in `run_fork.rs`; (3) misleading doc comments.
Before anyone turns the switches on in production, add a run-level byte test for the
call sites that no test covers today (endpoints, token stages, boundary, fork run).

## Findings

### High

None found.

### Medium

**M1. The soundness pin does not cover the new prover body.** READ:
`hl/src/private_block/w16r2_tests.rs:1554-1565` (`w16r2_the_lemmas_load_bearing_invariants_are_pinned`)
checks, by reading source text, that `core/src/pcs.rs` `pub fn open_zk<` absorbs
`pcs-vec`, then `pcs-prox`, then draws the column indices, and that `zk_rhos` draws the
proximity rho as `rows` independent challenges. With `HL_METAL_OPEN_SKIP_TABLES=1` the
prover at nine call sites is instead `open_zk_fast_metal` (`hl/src/pcs.rs:290-382`),
which re-implements that order (lines 326, 338, 366-370). It is correct today (READ),
but nothing pins it. ARGUED: if the core opening changes (the W16R3 bundle is planned to
change protocol pieces together), the fast path keeps the old order and silently
produces proofs the new verifier rejects, or worse, proofs whose mask or order
invariants differ from what the Lean statements describe. The only catch is
`m1_open_zk_fast_matches_core_open_zk_byte_for_byte` (`hl/tests/zk60_metal_commit.rs:856`),
which needs a Metal device and is not part of the CPU suite. What would settle it: extend
the pin test to `fn open_zk_fast_metal(` in `hl/src/pcs.rs` (same three-position check plus
`tr.challenge_fp2_vec(rows)`), and add a drift guard, for example a pinned hash of the
bodies of core `open_zk`, `zpart_weights`, `group_zclaims`, `zk_rhos` and
`fold_rows_multi_zk` (`core/src/pcs.rs:869-1069`), so any core edit forces a revisit of
the fast copy.

**M2. Most changed call sites have no byte test with the switches on.** READ: the only
end-to-end test, `open_fast_w16r2_rung_golden` (`hl/src/private_block/w16r2_tests.rs:367-442`,
ignored, run by name), calls `seeded_digest` (`w16r2_tests.rs:153-169`), which runs
`prove_core` only and asserts exactly 2 fast openings (A and H). The swapped call sites
at `hl/src/private_block/protocol.rs:2162,2166` (endpoints in `prove_inner_at`),
`run_fork.rs:1875,1879`, `boundary.rs:280`, `token_io/stage_in_c.rs:385,388,391` and
`token_io/stage_out_c.rs:644,647` are not exercised with `of1`/`st1` by any test in this
diff (READ). ARGUED: the function-level parity test makes a difference unlikely, because
each call site passes the same arguments to a function that is byte-identical in
isolation. It is still a gap for a change that touches the prover of every block. What
would settle it: one test per path (fork run with boundaries, token in/out stages) that
compares full proof bytes with `of0` and `of1`, with the fast-call counter asserted
to equal the number of device-stored openings on that path. The speed bench passes
(12 of 12) show completeness, not byte identity (ARGUED).

### Low

**L1. Stray non-swap edit.** READ: `hl/src/private_block/run_fork.rs:1878` changes
`protocol::check_endpoint_opening(oc, sh, &tr)` to `(oc, sh, &mut tr)`. The callee takes
`tr: &Transcript` (`protocol.rs:385`), so this coerces and has no effect (ARGUED), but
it is not a pure call-site swap and may draw a clippy `unnecessary_mut_passed` warning
(NOT CHECKED). Revert it.

**L2. The host-gather switch has a wider reach than described.** READ: the switch is
checked inside `MetalCommit::columns` (`hl/src/gpu/metal.rs:1741`), the `EncodedStore`
method every opening of a Metal store uses (`hl/src/gpu/mod.rs:923-925`). So `hg1`
also changes the gathers of core `open_zk` at the unswapped call sites in `hl/src/zk.rs`
(1889, 1892, 2842, 2852, 2860) and of the non-hiding `pcs::open`. ARGUED: this is safe
if the gather is correct, and the gather parity test covers the non-hiding form
(`zk60_metal_commit.rs:688`, which uses `metal_commit`). Say so in the description so a
later bisect knows where to look.

**L3. Doc comments say the wrong switch.** READ: `hl/src/pcs.rs:144-149` says the core
path is taken "when `HL_METAL_OPEN_FAST` is off", but the gate at `pcs.rs:166` is
`open_skip_tables_on()`; with `HL_METAL_OPEN_SKIP_TABLES=1` alone the fast body runs.
`pcs.rs:160-162` says "still enforces the identical assert_mask_sites invariants" (true,
line 341) but does not say that `LAST_SITES` is not written, so `last_mask_sites()` after a
fast opening returns the previous opening's sites on that thread. ARGUED harmless today:
the only readers are in `zk.rs` (1890, 1893, 2843, 2853, 2861), each right after a core
`open_zk`. The phase labels at `protocol.rs:2164,2168,2872,2877` still say `pcs::open_zk`.

**L4. Panic-versus-wrap divergence on absurd claims.** READ: `zpart_key_and_check`
uses `checked_shl` (`hl/src/pcs.rs:193,212`) where the core uses `1usize << (ls - log_cols)`
(`core/src/pcs.rs:878`). The release profile has no overflow checks
(`hl/Cargo.toml:59-64`), so for `ls - log_cols >= 64` with an empty point the core wraps the
shift and the fast path panics. ARGUED: no real claim has a slice of 2^64 rows; this is
the only input I found where the two differ, and the fast path is the stricter one.

**L5. Duplicated fold chunking.** READ: the fallback at `hl/src/pcs.rs:353` calls
`dc.fold_rows(&rhos)` once, where the core chunks by `dc.fold_batch()`
(`core/src/pcs.rs:992`). For `MetalCommit`, `fold_batch()` is `usize::MAX`
(`hl/src/gpu/mod.rs:926-928`), so it is one chunk either way (ARGUED identical). It is a
hidden coupling; a comment or an assert on `fold_batch()` would make it explicit.

**L6. The new diagnostic line is also live outside the new switches.** READ:
`log_sparse_fold_err` (`hl/src/gpu/metal.rs:217-221`) is called on sparse-fold error
fallbacks at `metal.rs:1673,1727,2114`, which run whenever `HL_METAL_SPARSE_FOLD=1`
(default off, `metal.rs:2041-2050`), independent of the opening switches. It prints once
per process: a site name and the error string. READ the error sources
(`metal.rs:155-160,2106,2201-2258`, plus `shared_buffer`, `upload` and `run_tagged`
messages): they carry kernel names, Metal error text, byte counts, row counts and `q`.
ARGUED: all public shape data, no witness value. Whether any tool parses stderr lines
that start with `[ZK60-METAL]` is NOT CHECKED.

**L7. Gather edge cases differ from the device path only where unreachable.** READ:
with `rows == 0` the host gather returns empty columns (`metal.rs:1945-1947`) where the
device path fails in `shared_buffer` (`metal.rs:783-785`). ARGUED unreachable: a
`MetalCommit` cannot be built with zero rows, because `commit_impl` allocates the
encoding through the same `shared_buffer` (`metal.rs:2884`).

## Answers to questions 1 to 5

| # | Question | One-line answer |
|---|---|---|
| 1 | Byte identity with core `open_zk` | Identical on all well-formed inputs (READ step by step: no rng draws in either; lambdas per group then the prox rho at `hl/src/pcs.rs:326,338` against `core/src/pcs.rs:956,970`; same `assert_mask_sites`; same fold call; `pcs-vec`, `pcs-prox`, indices at `pcs.rs:366-370` against `core:1049-1053`; same grouping by first appearance; row weights equal by exact, canonical Goldilocks arithmetic, `core/src/field.rs` lines 45-115). Skipped `cw` (`core:942`), dense `row_w` and `wants` are unread on every core prover path, including empty claims, multi-part claims and the device-fold fallback; no default-build oracle reads them (READ). Only differing input: shift amounts of 64 or more (L4). |
| 2 | Host gather | (a) Safe: the encoding's only writer is the commit command buffer, waited on and status-checked in `run_tagged` (`metal.rs:1089-1098`) before `MetalCommit` is built (`metal.rs:2923,3036`); after that `enc` is only read (`metal.rs:1647,1744,1753,1770`); the `&self` borrow keeps the pooled buffer alive; concurrent lanes and sumcheck batching do not touch it (READ, ARGUED). (b) No new unsafe beyond the existing `as_u64s` (`metal.rs:815-819`); the gather itself is safe Rust with slice bounds checks, an asserted `enc.len() >= rows*nn`, and an asserted index range; transcript indices are checked to be below `nn` and return `Err` before the gather (`metal.rs:1766-1768`) (READ). (c) Same order and layout as `k_gather_cols` (`metal_kernels.metal:1082`, raw word copy, column-major output in `idx` order, duplicates by slot); a host-stored commitment never reaches it (READ). (d) Out of range gives `Err`, then the same `expect` panic as the device path; the buffer is always `StorageModeShared` (`metal.rs:794`), so no not-host-visible case exists (READ). |
| 3 | Zero knowledge | No new read, log or retention of private values: the fast path reads the same buffers, the gathered columns and fold vectors are published in the proof anyway, the skipped tables are functions of public points and coefficients, and the new eprintln prints only public shape and Metal error text (READ, ARGUED; L6). |
| 4 | Switches | Each env var is read once per process into a `OnceLock` (`metal.rs:385-388,401-403,440-442`); test overrides are process-global atomics checked first, per call; commit is unaffected by these switches, so commit and opening cannot disagree; different threads can only differ while a test flips an override, and outputs are byte-identical either way (READ, ARGUED). With all switches off the five files are pure swaps to a function that delegates to core `open_zk`, except the stray `&mut` at `run_fork.rs:1878` (L1). |
| 5 | Tests | The parity test compares full `write_bytes` output, transcript state, counter and the next challenge against the CPU core path for of0, st1+hg0, st0+hg1, of1, empty claims, the device-fold fallback (real: `device_fold_on` is read per call, `metal.rs:2011-2016`) and `Store::Host`, with exact counter deltas asserted (READ `zk60_metal_commit.rs:856-1072`). Overrides beat the cached env, so the in-process tests are not vacuous (READ). Not covered: the call sites in M2, sparse fold on (`sf1`) with `of1` at function level, the A8 `M11` form, concurrent openings with `hg1`, the parallel gather branch inside the opening test (rows 32 and 38 only; covered by the gather test at 2504 and 2606 and by the rung test), the CPU-only build of the stubs. |

## What I did not read or do

- I did not build, run any test, or check that the branch compiles (NOT CHECKED). I
  did not verify the author's reported test passes or the bench numbers.
- I did not read the bodies of `fold_rows_sparse_device`, `fold_segments_a8_opts` or
  `fold_rows_device`; they are called identically by both paths, so they do not affect
  the comparison (ARGUED).
- I did not read `pool_take` (buffer pool sizing) or check for asynchronous command
  buffers that might still use a pooled buffer after it is returned; that is a
  pre-existing question that applies equally to the device gather (NOT CHECKED).
- I did not trace whether the endpoint commitments in `prove_inner_at` and `run_fork`
  are device-stored, so I do not know how many of the M2 call sites actually take the
  fast body when the switch is on (NOT CHECKED).
- I did not read the a22 bench code beyond the switch plumbing in
  `run_fork_tests.rs` (6854-6898, 7111-7153).
- I did not check whether stderr `[ZK60-METAL]` lines are parsed by any tool (L6).
- I did not compare against the Lean statements' text beyond a search for `open_zk`
  in `ZK60_LEAN_PRODUCTION_STATEMENTS.md` (no hit).
