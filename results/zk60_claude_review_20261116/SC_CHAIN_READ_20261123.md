# Read of agy/sc-chain-opt (7ed1278b4..6fd27ebfe): the fast sumcheck round chain

Reviewer: Claude (fresh read, read-only, nothing built or run). Date: 2026-11-23.
Scope: `git diff 7ed1278b4 6fd27ebfe` (one commit), six files under
`ops/zkp-mvp/gpu-metal/hashline/`. All line numbers are at 6fd27ebfe. `hl/` means
`ops/zkp-mvp/gpu-metal/hashline/`; `k.metal` means `hl/src/gpu/metal_kernels.metal`.

Labels: READ = I read the lines. INFERRED = my reasoning from what I read.

## Verdict

**Merge with named changes (M1 and M2 before anyone turns the switch on in a run that
matters).** The transcript step is right: for every d1 in 2..=8, keyed or not, with or
without claim recovery, `k_sc_fs_step_v3` feeds BLAKE3 the same 16-word blocks, block
lengths, flags, counter and chaining values as `k_sc_fs_step`. It takes the challenge the
same way and writes the same `fs` and `out` words (READ, with the field arithmetic
INFERRED). And even if it did not, the host replays every device round through the real
transcript and refuses the attempt when a challenge differs (`hl/src/gpu/metal.rs:4875`,
`4878`). So a transcript bug in this kernel can crash a proof but cannot change its
Fiat-Shamir. With the switch unset, the old chain runs unchanged (READ, question 4). The
two problems are in the parts the replay does not check: the evaluated partial sums and
the tables. **M1:** the in-kernel SIMD sum assumes that 32 consecutive global thread
indices form one hardware SIMD group. Nothing on the host checks this, and with
`HL_METAL_SC_TG` set to a value that is not a multiple of 32 the round sums come out
wrong with no error. **M2:** the skipped "dead" xtabs fold at `j == nd` is only dead
while `HL_METAL_TAIL_BUDGET_US >= HL_METAL_BATCH_TAIL_US`. With the two budget knobs set
the other way, the next device round reads tables that were never folded. Both give
silently wrong sums, and so a proof the verifier rejects. Soundness is not affected. The
old chain had neither problem.

## Findings

### High

None found.

### Medium

**M1. The SIMD reduction in the round kernel trusts an unchecked threadgroup shape; a
non-multiple-of-32 `HL_METAL_SC_TG` gives wrong sums silently.**
READ: under `SC_SIMD_SOA` the generated kernel (`hl/src/private_block/metal_slot.rs:448-457`,
`481-495`) takes the point and the SIMD-group index from the GLOBAL index
(`grp = tid >> 5`, `sg = grp / np`, `lane = tid & 31`), then sums with
`simd_shuffle_down`, which works over the HARDWARE SIMD group. Lane 0 writes the group's
sum to `part[(d * n_sg + sg) * 2]`. The two coincide only if every threadgroup size is a
multiple of 32 and the SIMD width is 32. The round dispatch uses
`tg = pipe.max_total_threads_per_threadgroup().min(self.tg).min(grid)`
(`metal.rs:4767` batched, `4213` unbatched), with `self.tg` from `HL_METAL_SC_TG`, which
is only clamped to 32..=1024 (`metal.rs:3348`). `sc_chain_fast_ready` (`metal.rs:238-246`)
checks only `fs_step_v3.max_total_threads_per_threadgroup() >= 256`. It checks neither
`thread_execution_width() == 32` (the same file checks it for another kernel at
`metal.rs:5295`) nor the round pipelines' shape.
Concrete state: `HL_METAL_SC_TG=48`. Threadgroup 1 covers global threads 48..95, so its
first hardware SIMD group is threads 48..79. It mixes points or groups `grp` 1 and 2, and
its lane 0 (thread 48) writes a mixed sum to the slot that belongs to `grp` 1. Threads
64..79 shuffle with the wrong partners, and their own lane-0 positions are never
written. Every reader (`k_sc_fs_step_v3`, the batched host reader, `SumcheckRounds::round`
at `metal.rs:4227-4242`) then sums wrong entries (INFERRED). The host replay does not
catch it. It recomputes only s(1) and the extrapolated points from the device's own s(0)
(`metal.rs:4870-4875`), so a wrong s(0) passes and the proof is inconsistent (INFERRED).
The old AoS layout indexes by `gid`, not by the hardware SIMD group, so any `HL_METAL_SC_TG`
was safe there.
What would settle it: in `sc_chain_fast_ready`, or where `sc_fast` is decided, require
`self.tg % 32 == 0` and `thread_execution_width() == 32` for pipe0, pipe and
`fs_step_v3`, falling back to the old chain otherwise. Or force `tg` to a multiple of 32
under `sc_fast`. A test that runs the rung golden with `HL_METAL_SC_TG=48` and the switch
on would show the failure today.

**M2. The xtabs fold skipped at `j == nd` is read again when the host-tail budgets are
overridden.**
READ: under the fast chain, `batched_rounds` folds xtabs only for `j < nd`. At `j == nd`
it folds tabs alone (`metal.rs:4720-4740`). The old chain also folded xtabs there
(`metal.rs:4746`). After the batch, `masked_prove` runs round `nd` through
`TailedRounds::round` (`metal.rs:4890-4891`). That goes to the DEVICE (`d.round`, which
reads xtabs through buffer 4, `metal.rs:4204`) when
`half * points * per_eval > tail_round_budget_s()` (`metal.rs:4488`). `batched_round_count`
stops at the first round with `half * points * per_eval <= batch_tail_budget_s()`
(`metal.rs:4834`). With the defaults (tail 250 us, batch 25 us) such a round always goes
to the host, which reads only tabs (`into_host`, `metal.rs:4406`). So the fold is dead
there, and also when `nd == n_vars`, because `finals_inner` reads only tabs
(`metal.rs:4152-4156`). Both knobs can be set from the environment, though
(`HL_METAL_TAIL_BUDGET_US` at `metal.rs:4349-4351`, `HL_METAL_BATCH_TAIL_US` at
`metal.rs:4543-4545`), and both are documented as "changes no byte".
Concrete state: `HL_METAL_TAIL_BUDGET_US=0` (or `HL_METAL_BATCH_TAIL_US=1000`) with the
switch on, on a slot with materialized tables (`m > 0`, `HL_A27_LIN` default on). Round
`nd` runs on the device against xtabs one fold behind. Its round kernel reads
`xtabs[i]` and `xtabs[i + half]` from the unfolded table, so the sums are wrong. Every
later `fold_r` then folds the stale xtabs (INFERRED). As in M1, the replay cannot see it.
What would settle it: fold xtabs at `j == nd` whenever `nd < n_vars` (one dispatch per
sumcheck), or skip only when `nd == n_vars`, or assert that the tail budget is at least
the batch budget when `sc_fast` is on.

### Low

**L1. Test coverage of the transcript step has gaps that the generic code makes
unlikely to matter.** READ: the 52 cases (`metal.rs:5627-5724`) cover d1 2..=8,
`de` in {d1-1, d1-2} only (`metal.rs:5629`), and four fixed (count, first eval_one,
recover, keyed) tuples (`metal.rs:5650-5653`). All three production combinations of
eval_one and recover are present: recover off with eval_one 1 throughout; recover on
with the claim known; recover on with the claim unknown at j = 0. Missing are: `de`
below d1-2, which `kernel_de` admits for any attained degree 1..D-1
(`metal.rs:3151-3158`, `metal_slot.rs:242-249`), for example d1=8 with de=3; unkeyed
together with recover; and counts matching the production `n_sg` (at most 1024 at the
default thread cap). INFERRED: the kernel's branches depend only on `np <= 4` versus
`np > 4` and on `lane > de`, which the matrix reaches, so I expect no difference. A
divergence would still be refused by the replay. It is cheap to add de = 1 for every d1.

**L2. The fast kernel ignores the scale's imaginary word.** READ: `k.metal:1811` uses
`mk[rec]` alone, where the old kernel multiplied by the full `q2_at(mk, rec)`. This is
equal today because the host pushes `Fp2::from_u64(1 << (n-1-j))` (`metal.rs:4660`), and
the test hard-codes `mk[off + 1] = 0` (`metal.rs:5644`). If the mask layout changes, the
replay would turn this into a refused attempt, not a wrong proof. Add a comment or a
debug assertion.

**L3. Ordering of device memory inside the transcript step.** READ: lanes read
`fs[19..25]` in phase 2 (`k.metal:1794`, `1812-1813`). Lane 0 writes them in phase 4
(`k.metal:1863`, `1872-1875`) after `simdgroup_barrier(mem_flags::mem_threadgroup)`, which
orders threadgroup memory only. INFERRED: this is safe, because each read value feeds a
threadgroup write that comes before the barrier. Using `mem_device | mem_threadgroup` on
the barrier at `k.metal:1824` would make it formally clear.

**L4. The fused fold does not honour `HL_A27_FOLD=0`.** READ: `k_fold_tables_dev3_xy`
always uses `a27_fold_pair` (`k.metal:1597-1612`). The tabs-only branches still use
`fold_kernels().1`. INFERRED: the same canonical words come out either way (every
operation returns canonical words), so no bytes change. Only an A/B of that switch with
the fast chain on would be measuring the wrong kernel.

**L5. The test override is process-wide.** READ: `SC_CHAIN_FAST_TEST` is one static
(`metal.rs:195`). The golden test is `#[ignore]` and documented to run alone by name
(`w16r2_tests.rs:4194`). Run in parallel with other GPU tests, its `sc_delta` counts
could include other tests' batches. Low because of the ignore.

## Answers

| # | Question | Answer |
|---|---|---|
| 1 | Transcript step | READ: same bytes for every admitted combination. Block 0 is state, le64(8), "sc-round" as `0x722D6373 0x646E756F`, le64(16 d1), first value. Value words go in at `m_sm[k] = vals[k]`. The last absorb block length is `(2 d1 - 1) * 8` for d1 <= 4 and `(2 d1 - 9) * 8` for d1 >= 5, both equal to `56 + 16 d1 - 64 b`. Flags are CHUNK_START, then none, then CHUNK_END or ROOT. The counter is 0, unused words are zero, and the key is the IV under KEYED_HASH. The squeeze is a 47-byte single block with the 8-byte counter split as `<<24`, `>>8`, `>>40`. The challenge is `gl_reduce128` of the same words. `sc_b3_compress_reg` matches `b3_compress`: IV, the G rotations 16/12/8/7, the column and diagonal order, all seven message schedules (checked against `B3_PERM` applied 0..6 times), and the final XOR. Mask, s(1) recovery, extrapolation, interpolation and the Horner form of u_j(r) are the same field values (INFERRED: canonical arithmetic). A mismatch would be refused by the host replay (`metal.rs:4875`, `4878`). |
| 2 | SIMD reduction | Assumes 32-wide SIMD groups and threadgroups that are multiples of 32. Neither is checked, so a failure gives silently wrong sums (M1). The grid is padded to `n_sg * 32 * np`, and inactive lanes add zero, so the last partial group is correct. The sum is canonical (`gl_add`). All three readers use `d * n_sg + g` with `n_sg = ceil(nthreads / 32)`, including the `nthreads == 1` case. The part buffer is sized from round 0's count, which is the largest because `sc_threads` is monotone (READ `metal.rs:3268-3270`, `3350`). |
| 3 | Fused fold | Word for word the same as two `k_fold_tables_dev3` dispatches: the same `a27_fold_pair` and indices, and the buffers are disjoint (READ). The skipped fold is dead with the default budgets and when `nd == n_vars`, but not under the budget overrides (M2). Slots without xtabs use the old tabs-only fold. |
| 4 | Default path | Unchanged with the switch off (READ). The edits: a new OnceLock field; `sc_def = ""`, so the source string and cache keys are byte-identical; `entries = t0n`; the old host reader moved verbatim into `else`; `fs_pipe`/`tgw` and the fold and part-reduce branches are identical; `part2` is now an `Option`, still allocated; the generated source gains `#ifdef`/`#else`/`#endif` around the old lines, so it preprocesses to the same kernel (the text differs; nothing I read hashes it). The environment is read once per process (OnceLock). The test override (an atomic) takes precedence. `sc_fast` is fixed per slot at construction, so threads cannot disagree within a slot. |
| 5 | Failure | If the fast pipelines fail to build, `sc_chain_fast_ready` returns false and the slot uses the old chain, decided before any transcript use (READ). A failed round-library compile with the define returns `Err` like any compile failure, with no retry without it (READ). A failed command buffer causes the `.expect` panic in `masked_prove`, as before, with `tr` untouched until the replay. A slot cannot mix the chains. |
| 6 | Private data | Nothing new is printed or kept. The 272 B of threadgroup memory lives for one dispatch. `part` is the slot's own buffer, now smaller, and `part2` is not allocated. The tests print only digest prefixes (READ). |
| 7 | Tests | The kernel tests: 52 exactness cases comparing all `out` and `fs` words over 5 chained rounds (L1); fused fold against separate folds for three shapes. Golden: the W16R2 rung digest equals the CPU digest and `96e4f0b6` for `sc0`, `sc1` and `frs1+sf1+sc1` in both queue modes, with a fast-batch counter equal to 0 on `sc0` and above 0 otherwise. It is `#[ignore]`. There is no arm with `HL_METAL_BATCH=0` (a OnceLock that cannot be toggled in-process), so the unbatched SoA reader is covered only where the rung has sumchecks with `nd < 2` (not established). The fork-run A/B arm (`sc0`/`sc1`) verifies receipts on pass 0 and compares no bytes. There is no switch-on against switch-off byte test for the fork run or the classifier stages. |

## Not read or not established

- I built and ran nothing, so I have not established that the Metal compiler accepts the
  generated source with the define, or that the tests pass.
- I did not read `SC_PRELUDE`, `f2_add`, `ln_base`/`ln_ext` or the generated body, beyond
  noting that `acc` is canonical by construction (INFERRED).
- `crate::zk::masked_prove_rounds` and whether the prover checks its final sumcheck claim
  before emitting a receipt. This decides whether M1 and M2 surface as a prover panic or
  only as a verifier rejection.
- Whether Apple ever reports a `max_total_threads_per_threadgroup` that is not a multiple
  of 32 for the round pipelines. I assumed not, so M1 rests on the environment knob.
- The classifier input and output stages, and whether they construct `MetalRounds`
  through the same two constructors (I found only `metal_rounds` and
  `metal_rounds_owned` in `metal.rs`).
- The timings and the 8B stream set.
