# A12: the device slots' tables, built on the device (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A12. Byte-preserving. It builds on A11
(`../a11/README.md` §2.4 and §5–§7: after the per-fork pools, the largest host region each fork waits on was the
device slots' table builds) and on A7's timeline (`../a7/README.md`).

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers; [ESTIMATE] a
judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, shared Metal
queue, spin wait, per-fork rayon pools (the A11 default), on the shared M3 Ultra.

## Plain summary

- **The tables of the device slots (14–19, 21, 22) are now built on the GPU, and that is the default.** No byte
  moves: every word of every table equals the host builder's, and every golden, digest and receipt holds (§4, §6).
- **It pays, in both arm orders, in every pair** [MEASURED, `s3`, in one process, 6 passes, the order reversed in
  every odd pass]:
  - **proof-only fork run: −6.9%, 4.596 → 4.279 s** (27.9 → 29.9 tok/s); the forks phase −7.3%;
  - **one request from its input: −3.5%, 8.778 → 8.470 s** (14.6 → 15.1 tok/s);
  - **the 4-request stream: steady state +6.4%, 22.9 → 24.3 tok/s**; amortized +4.8%, 19.7 → 20.7 tok/s;
  - CPU: user −15%, system −16% per proof-only call.
- **What made it pay was where the work goes, not the kernels.** The first form (the build in a command buffer of
  its own, reading the committed rows through fresh no-copy views of the host matrices) LOST about 9% at N = 6
  [MEASURED, `s1`]. The kernels were cheap (about 1.5 ms of GPU per slot), but each build's command buffer waited
  4.7 ms (N = 1) to 15 ms (N = 6) between commit and GPU start: the residency of two 330 MB views, then the queue
  behind the other forks. The form now in the tree:
  - reads `A`'s and `H`'s rows from the commitments' own device copies (already resident, uploaded once for the
    commit and folded by the openings), registered for the slots by `prove_core`;
  - encodes the build ahead of the slot's first round, in its own encoder of that round's (or batch's) command
    buffer: no command buffer and no queue wait of its own.
- **The GPU did not get busier in the forks phase** (2.73–2.76 s against 2.80–2.85 s with host builds) [MEASURED,
  `s2`]. The table time a fork spends on the host fell from about 60 to about 19 ms per block (what is left: the
  public tables' copies, the private slots 00–13, the plan) [MEASURED, `s2`].
- **Kept as switches:** `HL_METAL_DEVICE_TABLES=0` restores the host build (the pre-A12 path); `=sync` is the
  build in its own command buffer (now also with resident rows; it paid less, §3).

## 1. The map [MEASURED]

**What the device slots build** (`s2_census.log`, the census test; per block, W16R2 8B T128):

| slot | tables | words | kinds |
|---|---|---:|---|
| 14 D zero-check | 2^19 × 36 | 18.9 M (302 MB) | 3 eq, 2 public, 21 A planes (2 broadcast), 10 H planes (re + u im) |
| 15 Q zero-check | 2^19 × 15 | 7.9 M (126 MB) | 3 eq, 2 public, 7 A, 3 H |
| 16 KV zero-check | 2^17 × 15 | 2.0 M (31 MB) | 3 eq, 2 public, 7 A, 3 H |
| 17 softmax zero-check | 2^19 × 19 | 10.0 M (159 MB) | 3 eq, 1 public, 10 A (2 broadcast), 5 H |
| 18 F zero-check | 2^21 × 19 | 39.9 M (638 MB) | 3 eq, 2 public, 9 A, 5 H |
| 19 table helper | 2^14 × 58 | 0.95 M (15 MB) | 1 eq, 25 public, 16 A, 16 H |
| 21 / 22 endpoints | 2^19 × 3 each | 1.6 M each | 1 eq, 1 A, 1 endpoint plane |
| **all** | | **82.6 M (1.32 GB)** | 168 tables: 18 eq, 34 public, 116 committed planes |

- Each eq table is `eq(point, x)` over the whole cube; each plane table is a committed plane read through a bit
  map of the slot's challenge coordinates (a plain gather: none of the device slots' planes has a fixed
  coordinate; the matmul slots 05–13, which have, are not device-built). The public tables are host vectors made by
  `define`.
- The device slots' tables are 95% of the words the block's tables write (87.0 M over all 23 slots).

**What the host build cost, per block, summed over the forks** (`s1_d55_map.log`, `s2_d55_map.log`, the
`D55-AB A12 TABLES` lines of the `hosttab` arm, 2 calls each):

| slot | N = 1 | N = 6 |
|---|---:|---:|
| 18 | 6.7–6.8 ms | 22.7–22.8 ms |
| 14 | 3.6–3.7 | 9.5–10.0 |
| 17 | 2.4–3.1 | 6.0–6.3 |
| 15 | 2.0–2.3 | 3.8–3.9 |
| 16, 19, 21, 22 | 1.0–1.5 each | 0.5–1.6 each |
| **the device slots** | **19.3–20.5 ms** | **45.8–47.4 ms** |
| all 23 slots | 35.4–37.5 | 59.9–62.6 |

At N = 6 a fork's device-slot table builds took 2.3x as long as alone (slot 18: 3.4x), in its pool of 6 threads
while five other forks run. Uncontended, in a single process, the same builds take 18–20 ms on the 32-thread
global pool and 35 ms in a pool of 6 (`s1_census.log`, `s2_census.log`).

## 2. What changed

**The kernels** (`gpu/metal.rs`, `[A12]`, the source string `TAB_SRC`, compiled with the field code of the commit
and round kernels; `metal_kernels.metal` is unchanged):
- `k_tab_eq`: entry `x` is `hi[y >> p_lo] * lo[y & (2^p_lo − 1)]`, `y = (x >> shift) & (2^p − 1)`, with `hi`, `lo`
  the eq tables of the point's two halves. This is the host's own `eq_cube_split_into`.
- `k_tab_plane`: entry `x` is `sum_z eqf[z] * v(inv(x & used) | zbits[z])`, `v(idx) = sum_s coef_s * data[off_s +
  idx]`, a plain store `v(inv(x & used))` when no coordinate is fixed. This is the host's `priv_table_fill`; the
  inverse bit map, the fixed-point bits and weights are built on the host by `argument::plane_plan`, exactly as
  `priv_table_fill` builds them.
- Every planned table is checked against its slot and its data's bounds before anything is encoded.

**The build** (`MetalTables::build_planned`; `argument::build_tables_device`, called by `run_slot` for a direct
device slot):
- The public tables (and any plane `plane_plan` declines: one whose challenge index repeats; none in this
  schedule) are written by the host builder first, into the same buffer.
- The committed rows are read where they are: `A`'s and `H`'s from their commitments' device copies
  (`MetalCommit::resident_rows`, registered by `protocol::prove_core` around its slots; `argument::resident_rows`);
  a small slice (the endpoints, about 5 MB) through a no-copy view of its pages. A build that would need to map a
  slice over 2^22 words that is not resident is left to the host (`Ok(false)`, the pre-A12 path, no decline), so a
  caller that registers nothing (the token-I/O stages) keeps the host build.
- **Deferred (the default):** the build is encoded ahead of the slot's first round, in its own concurrent encoder
  of that round's or batch's command buffer (`MetalRounds::prelude`, `run_tagged_pre`); the rounds' encoder after
  it sees its writes (hazard-tracked buffers). If the host takes the first round, or the slot leaves the device, the
  build runs alone first (`into_host`, `MetalTables::flush`).
- **`sync`:** the build in a command buffer of its own, waited for before the rounds.

**The base-field check** that `metal_rounds_owned` makes on the host (a table round 0 keeps as one word must have
`c1 = 0` everywhere): for the host's tables, on the host; for a deferred device table, by construction (an eq cube
whose half tables are base-field, a plane whose slice coefficients and fixed-point weights are), and the device
flags any such word it writes (a flagged word refuses the attempt; it cannot happen). A build whose flagged table
is not base-field by construction runs in its own command buffer instead, and the device's flag is the answer.

**Diagnostics, test builds only:** the per-slot table-build clock (`argument::A12_TABLE_NS`, the `D55-AB A12
TABLES` line of every fork call), the A/B words `hosttab` / `devtab` / `devtabsync` (`run_fork_tests.rs`). Always
on, counts only: `MetalTables::build_stats` (builds, tables, views, resident reads, deferrals).

## 3. The measurements [MEASURED]

**The first form: the build in its own command buffer, rows through fresh no-copy views** (`s1_d55_map.log`,
2 passes each order, `summarize.py` → per call):

| N | host build: wall, the two calls | device build: wall, the two calls | table time per block, host / device | `tables` command buffers: GPU / commit → GPU start, per call |
|---|---|---|---|---|
| 1 | 10.73, 11.06 s | 11.86, 11.85 s | 36.6–38.4 / 60.9–63.2 ms | 0.12 s / 1.19–1.20 s (256 buffers) |
| 6 | 4.66, 4.59 s | 4.99, 5.10 s | 58.6–66.5 / 162–181 ms | 0.38 s / 3.63–3.95 s |

- About 1.5 ms of GPU per build, but 4.7 ms (N = 1) and 14–15 ms (N = 6) from commit to GPU start, per build.
- The census, alone in one process, gave the same picture (`s1_census.log`): a device build cost at least 2.4 ms
  even for a slot of 3,200 words, and about 2.2 ms more for every 330 MB matrix viewed [INFERRED from the slots
  that view one matrix, 2.4–2.5 ms, and two, 4.7–5.0 ms]: the residency of the fresh view. Fourteen such views
  per block (six slots read both matrices, the two endpoint slots one) is about 30 ms per block [INFERRED], the size
  of the host build itself.

**The second form, three arms** (`s2_d55_map.log`; 2 passes, the three arms in reverse order in the second, so
`devtab` ran in the middle both times):

| | `hosttab` | `devtab` (deferred, resident) | `devtabsync` (own command buffer, resident) |
|---|---:|---:|---:|
| N = 1, mean wall | 10.798 s | **10.098 s** | 10.243 s |
| N = 6, mean wall | 4.517 s | **4.249 s** | 4.316 s |
| N = 6, table time per block on the forks' threads | 59.9 ms | 18.7 ms | 117.1 ms |
| N = 6, GPU busy in the forks phase | 2.80–2.85 s | 2.73–2.76 s | 2.93–2.98 s |
| `tables` command buffers, N = 1 / N = 6: commit → GPU start, per call | — | — | 0.10 / 0.72–1.74 s |

- With resident rows the per-buffer wait at N = 1 fell from 4.7 to 0.4 ms (residency gone); at N = 6 it is still
  3–7 ms (the queue), which is why the deferred form is the better one.
- `devtab`'s table time is only the host part (public tables, the private slots, the plan); its GPU work runs
  inside the rounds' command buffers.

**The A/B, `hosttab` against `devtab`, both orders** (`s3`, N = 6, 6 passes; `s3_pairs.md` from
`../a11/pairs.py`; n pairs, n favouring `devtab`):

| metric | host first | device first | order bias solved out | means, host / device |
|---|---|---|---|---|
| proof-only wall | −7.0% (3, 3) | −6.8% (3, 3) | **−6.9%** | 4.596 / 4.279 s = 27.9 / 29.9 tok/s |
| forks phase | −7.5% (3, 3) | −7.1% (3, 3) | **−7.3%** | 4.226 / 3.917 s |
| one request from its input (sealed) | −3.8% (3, 3) | −3.1% (3, 3) | **−3.5%** | 8.778 / 8.470 s = 14.6 / 15.1 tok/s |
| stream of 4, steady state | +4.4% (3, 3) | +8.3% (3, 3) | **+6.4%** | 22.87 / 24.31 tok/s |
| stream of 4, amortized | +3.3% (3, 3) | +6.3% (3, 3) | **+4.8%** | 19.71 / 20.65 tok/s |
| user CPU (proof-only call) | −15.5% | −15.3% | −15.4% | 56.0 / 47.4 s |
| system CPU (proof-only call) | −13.9% | −17.7% | −15.8% | 7.6 / 6.3 s |

- Every pair of every timing metric favours the device build, in both orders.
- Every stream receipt (48) verified after its clock, and each arm's first proof-only and sealed receipt; fork
  receipts 818,728,672 B in every call (`s3_d55_ab.log`).
- **The forks phase fell by more than the table time a fork saved** [INFERRED]: the forks' table time fell by
  about 43 ms per block (62.1 → 18.6 ms, `s3_summary.md`), about 0.23 s per fork per call (5.3 blocks each), and
  the forks phase fell 0.31 s. The rest is plausibly the fork's other host work, with 8.6 CPU-seconds less work in
  the process per call (user CPU −15%); the build's own GPU work (about 1.5–2 ms per slot) now sits inside the
  rounds' command buffers.
- N = 1 was not A/B'd in both orders; the three-arm map gives −6.5% there (`s2`, indicative only).

## 4. Why no byte can move

- **The same words.** Each table word is the canonical Goldilocks representative of the same field element: the
  same formula over the same inputs (the half tables, bit maps, eq weights and slice coefficients are the host's own,
  made on the host), the same exact field operations as the commit and round kernels (`gl_header`, `SC_PRELUDE`).
  Only the order of exact additions can differ.
- **The same rows.** The resident copy is the copy the commitment encoded and its openings fold, of the very slice
  `ProverData` hands the host builder; the registration borrows the slice and its commitment, so neither can change
  or be freed while it lives, and it is per thread, matched by the slice's address and length, and not `Send`.
- **Nothing read early.** No table word is read before the command buffer that wrote it completed: the rounds read
  it in the same command buffer after the build's encoder; the host only after `flush` or `into_host`.
- **Tested, word for word** (§6): `a12_the_device_table_formula_equals_the_host_builders_at_every_slot_of_the_w16r2_rung`
  (CPU, in the suite: the kernels' formula on the host, every word of the rung's 189 device-formula tables against
  both host builders); `a12_census_and_the_device_tables_equal_the_host_tables_word_for_word` (Metal: every word of
  every table of every slot at W16R2 8B (228 tables, 87.0 M words) and the rung (238 tables), built on the device in
  both forms, in the global pool and a pool of six; the device's base check against the host's; a control that flags
  every table base-field and must be refused wherever an extension word exists);
  `a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device` (the rung golden `96e4f0b6` in
  all three modes, alone and as three concurrent proofs in pools of 1, 2 and 6 threads, the device arms reading only
  resident rows).

## 5. Acceptance [MEASURED]

**Stage 4** (`s4.sh`, `s4.progress`, `s4_*.log`, `s4.guard.json`) is the final tree, the device build the default.
One guarded job (16:01–16:11 UTC):
- **build:** rc 0. **The no-feature `cargo check --tests`** (no `gpu-metal`): rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **923 passed, 3 failed, 101 ignored**. The
  three failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 923 is A11's 922 plus `a12_the_device_table_formula_equals_the_host_builders_at_every_slot_of_the_w16r2_rung`;
    101 ignored is A11's 99 plus the two A12 device tests below.
- **The A12 byte tests:**
  - the census, word for word (Metal): every word of 228 tables (87.0 M words) at W16R2 8B and of 238 tables at the
    rung equal the host's, in both forms (all 23 slots deferrable: their base-field tables are base by
    construction); the base checks agree; the all-base control refuses; without resident rows the prover's form
    leaves every slot that reads a large slice to the host (23 at 8B, 22 at the rung);
  - the rung golden in every mode (`HL_GPU_REQUIRED=1`): `96e4f0b6` with the tables on the host, on the device
    ahead of the first round and in their own command buffer, alone and as three concurrent proofs in pools of 1, 2
    and 6; the device arms read only resident rows (40 resident reads, no views, no copies, nothing left to the host).
- **The A11 pool byte tests:** the seeded rung in pools of 1, 2, 3 threads and the global pool (CPU), and three
  concurrent Metal proofs in pools of 1, 2 and 6: `96e4f0b6` every time.
- **The A7 queue byte test** (`HL_GPU_REQUIRED=1`): `96e4f0b6` six times on the shared queue and six times on
  per-thread queues (six concurrent proofs, now with device-built tables).
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the final default** (`s4_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1
  HL_D55_PIPE=4`):

| W16R2 8B T128, 32 blocks, N = 6 | final tree (`s4_d55.log`) | A11's final tree, for reference (`../a11/s10_d55.log`) |
|---|---:|---:|
| proof only, the two calls | 4.462, 4.248 s | 4.418, 4.335 s |
| proof only, best / mean | 30.13 / 29.39 tok/s | 29.53 / 29.25 |
| one request from its input (sealed), best / mean | 8.356 s = 15.32 / 14.88 tok/s | 8.088 s = 15.83 / 15.59 |
| stream of 4, steady / amortized | 23.95 / 20.53 tok/s | 23.90 / 20.68 |
| serial D12a, best / mean | 9.937 / 10.105 s | 10.414 / 10.485 |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, all 4 stream receipts after the clock). Fork receipts
  818,728,672 B and D12a receipts 818,728,480 B, unchanged.
- In that process the device built 1,536 slot table sets (25,728 tables), all deferred, every `A` and `H` read
  from its resident copy (2,688), the endpoints through 384 small views, no copies, none left to the host.
- The A11 column is another process on another hour's box state (and A8's jobs ran between them); separate
  processes cannot resolve a few percent, which is why §3's in-process A/B is the measurement. The two agree on
  proof-only and the stream; this run's sealed calls (8.36, 8.84 s) came out slower than A11's, inside the
  run-to-run spread of the sealed arm (8.36–8.84 s here; the A/B's means were 8.78 host / 8.47 device).

## 6. What was not done

- **The private slots (00, 01, 04, 05–13).** Their tables are still built on the host and copied (their claimed sum
  reads the tables on the host). Together about 10 ms per block per fork at N = 6 (`s2`, the `hosttab` rows).
- **The public tables** of the device slots are still made by `define` and copied on the host (34 per block, 2 of
  them 2^21 long in slot 18). They are the bulk of `devtab`'s remaining 18.7 ms per block.
- **A6** (slot 18's top round point follows from the others) was not taken up; with the host side cut further, its
  about 5 ms of GPU per block is worth more than when A7 measured it.
- **N = 1 and N = 8** were not A/B'd in both orders.
- **The GPU timeline of the deferred form** cannot separate the build from the rounds (they share a command
  buffer); the census and the `sync` arm give its GPU cost, about 1.5–2 ms per slot.

## 7. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs` [pinned]: `[A12]` the table kernels (`TAB_SRC`), `TabJob`,
  `TabBuild`, `run_tagged_pre`, the resident-row registry (`MetalCommit::resident_rows`), `MetalTables`' plan,
  `build_planned`, `flush`, `deferred`, `base_checked`, `build_stats`; `MetalTables` and `metal_rounds_owned`
  carry the pending build and its base check into `MetalRounds` (`prelude`), whose first command buffer (or
  `into_host`) runs it. The store folds (`fold_rows_host_lazy`, `fold_rows_host`) are untouched.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/argument.rs`: `[A12]` the switch (`HL_METAL_DEVICE_TABLES`,
  default device), `plane_plan`, `build_tables_device`, `resident_rows`, the `run_slot` hook; test-only clock.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/protocol.rs`: one scoped statement in `prove_core` registering
  `A`'s and `H`'s rows for the slots.
- Tests: `range16_tests.rs` (the formula test, the census and word-for-word test), `w16r2_tests.rs` (the rung golden
  in every mode), `run_fork_tests.rs` (the A/B words, the A12 line).
- This directory: `s1.sh`–`s4.sh`, their logs, progress files and guard records; `run_stage.py`, `summarize.py`
  (`s2_summary.md`, `s3_summary.md`), `s3_pairs.md` (from `../a11/pairs.py`).

**For the privacy gate.** Changed digests (production): `gpu/metal.rs`, `private_block/argument.rs`,
`private_block/protocol.rs`. `metal_kernels.metal`, `gpu/mod.rs` and `metal_slot.rs` did **not** change. The new
device code reads the same committed rows the host builder read, writes only the slot's own pooled table buffer,
prints nothing and keeps no value past the slot (the registry holds references to the commitments' existing copies
for the slots' duration only). The diagnostics count builds and time them; no value is printed or kept.
`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
