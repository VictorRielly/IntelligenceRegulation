# A20: production's per-request host work, the sealing pass's loads and the receipt write (2026-11-06)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A20. Byte-preserving. It follows A19
(`../a19/README.md`, §4.5 and §9) on perf `3fc8cf92` (A19 merged).

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

All timing runs: W16R2 8B T128, 32 blocks, N = 6 fork workers, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, the
witness budget the Mac's default (32 GiB), A13's window off and the blocks shared (A19's defaults), on the shared M3
Ultra. Every stage was one guarded job (the shared heavy lock). Every timing step waited for a quiet GPU (no running
`ds4-bench`) and recorded that none ran at its end. The one exception is stage 1's two `sample` runs, which are
marked POLLUTED in `s1.progress` and decide nothing. The model is the D55 harness's synthetic block (diagonal public
weights at the 8B geometry) loaded as A19's `A19Synth` loads it: a fresh copy of the block, its layer record hashed. There
is no trained 8B export on the Mac, so production's real load (which also reads and hashes the export's files) was
not measured at 8B.

## 1. Plain summary

- **Production's one request is now half as long** [MEASURED, through `trained_block::d55_seal_and_prove`, the
  function `stack-prove --d55-workers` runs, 6 passes, both orders, on the final tree]. The defaults against every
  A20 form off: **−50.6%, 15.49 → 7.65 s (8.26 → 16.73 proved tok/s; best 15.27 → 7.59 s = 16.88), 6 of 6 pairs**.
  - The sealing pass falls 9.26 → 3.13 s and the receipt write 1.97 → 0.32 s.
  - The prove call does not move, and neither does the peak footprint (43.5 GiB).
  - Production's path on the default, best 7.725 s = 16.57 tok/s (A19's acceptance: 15.452 s = 8.28).
- **No byte moves** (§4, §6): records, block digests, statement identity, the sealing pass's planes and kept
  witnesses, every refusal string and its layer, the receipt's files and frame list. This holds under every setting,
  on the CPU and on Metal, at the R13 rung and on the 8B synthetic block. All 120 production A/B receipts are
  818,728,672 B.
- **What the profile found** (§2) [MEASURED]:
  - **SHA-256 runs in software, at about 0.5 GB/s.** `sha2 0.10.9` uses the Arm SHA instructions only with its
    `asm` feature (crate `sha2-asm`), which this build does not enable.
  - **Each 8B layer record took 252 ms.** That is the nine word SHA-256s in parallel (146 ms; the 67 MB `wg_t`
    alone 132 ms), *then* the block's BLAKE3 digest on one thread (115 ms).
  - **The receipt write's 1.94 s was 1.62 s of frame SHA-256s**, one after another.
  - **A19's "the loads slow the builds about 5×" is a clock artifact.** In `seal_chain`'s `rayon::join`, the worker
    that waits for the build in the sealing pool runs the queued load itself, so the build's clock reads the load's
    258 ms. The build itself takes 40 ms beside a load (37 ms alone). The pass was load-bound: one 258 ms load per
    40 ms build.
- **Three forms, on by default** (§3, §5), each restored by its switch at `0`:
  - `HL_A20_RECPAR`: the block digest beside the SHA-256s. Alone, one request −23.3% (6 of 6); inside the
    defaults, −11.4% (6 of 6, stage 9).
  - `HL_A20_LOADS` (default **4**): the sealing pass's loads on threads of their own, up to `n` layers ahead of the
    build, taken in layer order where the pass always took them. At 3 alone, one request −29.8% (6 of 6).
  - `HL_A20_WRITE` (default **16**): the receipt's frames written, flushed and hashed by 16 threads. Alone, one
    request −10.2% (6 of 6); the write 1.95 → 0.33 s.
- **One form measured and removed:** the words hashed in place instead of from their `i8_bytes` copies. The copies
  cost 4 ms a layer, and one request moved +0.6%. It would have added an `unsafe` block.
- **H-1 holds** (§8). The loads ahead are consumed in layer order at the old place, so the earliest layer's refusal
  comes back, with the same string, under every setting. This was tested with a parity failure at layer 1 *and*
  load failures at layers 2 and 3. The loads read public data, create nothing and are joined before the pass returns.

## 2. The profile (stage 1; `s1_profile.log`, `s1_sample_a20old_top.txt`)

`a20_profile_of_the_sealing_pass_loads_and_the_receipt_write` (ignored): the 8B block, medians of 6 repetitions, each
part alone unless stated. The block's nine padded words are 243,277,824 B (the largest, `wg_t` / `wu_t` / `wd_t`,
67,108,864 B each). The sealing pool has 8 threads, the global pool 32.

### 2.1 One layer's load [MEASURED]

| part | median |
|---|---:|
| the block's copy (the synthetic load's `clone`) | 3.9 ms |
| the nine `i8_bytes` copies, one after another | 4.3 ms |
| SHA-256 of `wq` (16.8 MB), from its copy / in place | 33.4 / 33.2 ms |
| SHA-256 of `wg_t` (67.1 MB), from its copy / in place | 134.3 / 132.4 ms (0.51 GB/s) |
| the nine SHA-256s one after another, from copies / in place | 483.9 / 479.9 ms |
| **the nine SHA-256s in parallel** (the record before A20), from copies / in place | **146.5** / 138.8 ms |
| the three table SHA-256s | 0.6 ms |
| **`BlockPublic::digest`** (one BLAKE3 pass on one thread, its own copies included) | **114.8 ms** |
| **`LayerRecord::of_block` before A20** (SHA-256s, then the digest) | **251.8 ms** |
| `of_block`, the digest beside the SHA-256s (`HL_A20_RECPAR`) | 138.5 ms |
| `of_block`, words in place, digest after (the removed form) | 252.4 ms |
| the synthetic load (copy + record), before A20 / with RECPAR | 257.3 / 144.4 ms |
| the witness build alone (the sealing pool) | 37.3 ms |

SHA-256 is software at about 0.5 GB/s (`sha2 0.10.9`, `src/sha256.rs`: the `aarch64` backend is compiled only with
feature `asm`, which pulls the `sha2-asm` crate; neither is in this build or in the offline registry) [MEASURED, CODE].

### 2.2 The build beside the loads [MEASURED]

| step (before A20's record / with RECPAR) | wall | the build's clock | the build's own end | each load |
|---|---:|---:|---:|---:|
| `seal_chain`'s step before A20: `rayon::join(build, next load)` | 258.7 / 141.6 ms | **257.7** / 43.2 ms (as `seal_chain` read it) | **40.2** / 39.9 ms | 258.6 / 141.6 ms |
| the build beside 1 load on its own thread | 257.4 / 142.9 ms | 39.8 / 39.5 ms | | 257.3 / 142.9 ms |
| the build beside 2 loads at once | 270.9 / 151.8 ms | 46.7 / 42.4 ms | | 268.5 / 148.7 ms |
| the build beside 3 loads at once | 274.8 / 159.7 ms | 53.0 / 53.9 ms | | 273.2 / 157.6 ms |

- **The artifact** [MEASURED, CODE]. `seal_chain` called `rayon::join(build, load)` from outside any pool. Closure A
  (the build) runs `pool.install` from a global-pool worker. That worker waits in `wait_until`, which runs local jobs
  first, and its local deque holds closure B (the next load), so it runs the whole load before it sees the build's
  latch. The build ends at 40 ms; its clock reads 258 ms. A19's "witnesses 8.13 s" was therefore the loads' 8.36 s
  seen twice.
- **Loads in parallel scale** [MEASURED]. Three at once take 273 ms each instead of 257 (with RECPAR, 158 ms instead
  of 143). The build beside them takes 53 ms instead of 40. At three loads ahead with RECPAR, the pass has
  158 / 3 ≈ 53 ms of load per 54 ms build [INFERRED].

### 2.3 The receipt write (an 818,728,672 B receipt: head 1,072 B, 32 forks of 24,539,240 B, tail 33,471,920 B) [MEASURED]

| part | median |
|---|---:|
| `write_fork_receipt` before A20 (one frame after another) | **1,939 ms** |
| … its 34 frames' `create` / `write_all` / `sync_all` (F_FULLFSYNC) / `rename`, summed | 2.5 / 82.6 / 279.9 / 3.5 ms |
| … **its 34 frames' SHA-256 (`digest_hex`), summed** | **1,615.7 ms** |
| the frames' SHA-256s in parallel (the global pool) | 120.1 ms |
| `write_fork_receipt` with 2 / 4 / 8 / **16** / 34 writers | 1,028 / 603 / 446 / **321** / 265 ms |

### 2.4 The sample [MEASURED, POLLUTED clocks]

`/usr/bin/sample` of production's request with every A20 form off, 12 s from 26 s into the run (`raw/`, top of stack in
`s1_sample_a20old_top.txt`; a `ds4-bench` started during this run, so its clocks decide nothing). Of the busy frames,
`sha2::sha256::compress256` leads with 14,045 one-millisecond samples across threads, then rayon's producer helpers
(the builds and the forks), then `blake3_hash_many_neon` with 3,278. This is the profile's picture: the per-request
host work is SHA-256-bound.

## 3. The forms, and what changed

### 3.1 `trained_statement.rs`: `HL_A20_RECPAR` (default on)

`LayerRecord::of_block` computes the nine word SHA-256s and the three table SHA-256s in one closure. With RECPAR on,
it computes the block digest (`BlockPublic::digest`) in a `rayon::join` beside them; off, in the order before A20
(words, tables, digest). Every field is a pure function of the block, so no value can move [CODE]. The file also holds
`a20_switch`, the switches' common reader: the environment once, with a test override.

### 3.2 `trained_block.rs`: `HL_A20_LOADS` (default 4) in `seal_chain`

- **`LoadAhead`** has `n` loader threads, each taking the next layer in order. A loader may start layer `j` only
  while `j < taken + n`, so at most `n` layers are loaded or loading beyond the one being built. Each result is kept
  in its layer's slot.
- The pass takes layer `k`'s slot at the top of iteration `k`, the place it always looked at layer `k`'s load
  (`cur?`). It then builds the witness on the sealing pool directly; the loads are already running.
- `n = 0` is the path before A20, unchanged: one load in a `rayon::join` beside the build.
- The loop runs inside `std::thread::scope`. A guard (`StopLoads`) stops the loaders when the pass returns, however it
  returns, and the scope joins them before `seal_chain` returns. A loader that panics marks the loads lost, so the
  pass never waits forever (a test build only: the release profile aborts on a panic).
- `SealTimes` gains `loads_ahead` and `load_wait_s`, and `D55Times` gains `seal_loads_ahead`, `seal_load_wait_s`,
  `write_s` (the receipt write, timed around `write_fork_receipt`) and `writers`. The CLI's events are unchanged.
- **Memory**: the layer being built and up to `n` loaded ahead are resident (before A20, two). On the D55 path all
  blocks stay resident anyway (A19's shared blocks). At 8B, `n = 4` adds at most about 0.7 GB of transient blocks on
  D12a's path [INFERRED]. The peak footprint did not move in any A/B (§5).
- Test builds only: `a20_seal_summary_for_tests` (everything `seal_chain` returns but its clocks, as one line) and
  `a20_export_seal_summary_for_tests` (the same over a trained export).

### 3.3 `run_fork.rs`: `HL_A20_WRITE` (default 16) in `write_fork_receipt`

The loop body moved, unchanged, into `write_fork_frame`: create `<name>.partial`, `write_all`, `sync_all`, rename,
then the length and SHA-256. With `w ≤ 1` the frames are written one after another, as before. With `w > 1`, `w`
scoped threads take the next frame from a counter, and every frame is attempted. The list comes back in file order,
and the first failure in file order is returned. The directory checks (it exists, it is empty) come first, as before.

### 3.4 Removed: the words hashed in place

The nine SHA-256s were also measured over each word's bytes in place (an `unsafe` reinterpretation of `&[i8]` as
`&[u8]`, the same bytes) instead of over their `i8_bytes` copies. The copies cost 4.3 ms a layer (§2.1), and alone
the form moved one request +0.6% and the sealing pass +1.1% (§5.1). The form and its `unsafe` block were removed. Its
A/B word `cast0` is kept as a no-op, so that stage 2's arms still parse.

### 3.5 Tests (`run_fork_tests.rs`, the `[A20]` block at the end)

- In the suite:
  - `a20_layer_records_and_the_statement_identity_are_the_same_under_every_record_setting`;
  - `a20_the_sealing_pass_is_the_same_under_every_load_setting_and_refuses_with_the_earliest_layer`;
  - `a20_the_receipt_write_is_the_same_files_bytes_list_and_refusals_at_every_writer_count`;
  - `a20_production_d55_path_under_the_forms_off_and_on_at_the_r13_rung`.
- Ignored:
  - `…_on_the_device` (Metal);
  - `a20_the_8b_records_sealing_pass_and_production_path_under_every_setting` (Metal);
  - `a20_profile_of_the_sealing_pass_loads_and_the_receipt_write`.
- A19's production A/B (`a19_production_d55_ab`) takes A20's words: `a20old` (every form off), `recpar0/1`,
  `loads<n>` and `write<n>`. Its PROD line gains the forms in force, the pass's wait for its loads and the receipt
  write's seconds.
- `a20_knobs()` serializes the suite's tests that set A20's switches.

## 4. The byte evidence [MEASURED]

**Why no byte can move** [CODE]:
- **RECPAR** computes the same pure functions of the same block.
- **LOADS** runs the same `m.load_layer(k)` calls on the same model, each layer once. The pass reads their results
  in layer order at the old place, with the same checks after them. Which thread ran a load, and when, changes no
  value: a load reads only public data, and the builder's pool is the same.
- **WRITE** writes the same bytes under the same names by the same steps, and returns the list in file order.

Stage 1 (`s1.progress`; stage 9 repeats all of it on the final tree, §6):
- **Records.** One record under every record setting at four blocks: the W16R2 rung block, a legacy (non-R13)
  synthetic block, every layer of a 4-layer R13 export through the real loader, and the 8B block. Each word's SHA-256
  was also checked against an independent SHA-256 of that word's bytes, and the block digest against
  `blk.digest()`. The R13 export's statement identity (`10a8fd14…`) is the same under every setting.
- **The sealing pass.** Everything `seal_chain` returns but its clocks: the statement identity, the block digests,
  every record, every sealed plane, the endpoints, the stage shapes, and which witnesses were kept with every plane of
  each. These are identical under seven settings, `(loads, record form)` = (0, off), (0, on), (1, off), (1, on),
  (2, on), (3, on) and (8, on), at budgets of everything and nothing. That holds on the R13 export and on A19's
  synthetic 8B stack (L = 4; every load hashes its record, and the model refuses records that are not the fixture's).
- **The refusals.** Each case gives one string under all seven settings:
  - a parity failure at layer 1: `layer 1: parity: … (before the run header; ruling H-1)`;
  - a load failure at layer 2: `layer 2: array \`wq\`: SHA-256 mismatch: …`;
  - load failures at layers 1 and 3: layer 1's;
  - **a parity failure at layer 1 with load failures at layers 2 and 3: layer 1's parity refusal**, though the loads
    of layers 2 and 3 failed first.
- **The receipt write.** Frames of distinct contents, written at counts 0, 1, 2, 3, 4, 7, 8 and 64:
  - the same list of lengths and SHA-256s, equal to the frames' own;
  - exactly the frames' names in the directory, each file the frame's bytes;
  - three refusals, each the same string at every count: no directory; a directory not empty; a directory not
    writable (the head frame's create error, and nothing left in the directory).
- **Production's path at the R13 rung** (`stack-prove --d55-workers` on a 4-layer R13 export). Each arm ran A19's
  whole check: a fresh `stack-verify` passes; the head is the replayed commit phase's; every interior fork equals
  that fork proved whole; the refused chain gives window 0's string at windows 0, 1 and L, creates nothing and keeps
  no part alive. Beside it, each arm gave the same statement identity and the same refusal for a chain whose layer 1
  fails parity and whose layers 2 and 3 fail their loads.
  - CPU (the suite test): `a20old` and `recpar1+loads3+write8`, each with A19's arms (window 0 and window 2, N 2).
  - Metal: `a20old`, `recpar1+loads1+write2`, the defaults and `recpar1+loads3+write8`, each with A19's arms (window
    0 at N 3, shared and reloaded; window 4 at N 6).
  - Stage 1 ran these arms with the since-removed in-place form on as well (`cast1+…`). Stage 9 runs the final arms.
- **Production's path at 8B on Metal** (`d55_seal_and_prove` on the synthetic 8B stack, L = 4, seeded generators),
  under `a20old`, every form on and the defaults: the receipt (102,772,480 B) verifies from its run directory, its
  head is the replayed commit phase's, and both interior forks equal those forks proved whole.
- **Every A/B call** (§5): 91 calls, every receipt 818,728,672 B; each A/B's cold call and each arm's first pass
  verified from its run directory (21 receipts).
- **The suites the forms touch** (stage 1): the D55 fork-run suite (32 passed, A20's four included), the trained-block
  tests, R6's sealing-pass audit, s25's census (the hash call sites unchanged) all pass; the trained-stack tests pass
  but for the known one.

## 5. The A/Bs through production's function [MEASURED]

`a19_production_d55_ab` (stage 2, `s2.progress`), each a 2-arm A/B: 6 passes after one cold call, the order reversed
in odd passes. Cells read "mean change (pairs, pairs where the test arm was lower)". The tables come from
`../a11/pairs.py --alternate --n 6`, `../a15/seal_pairs.py`, `prod_pairs.py` and `../a19/prod_table.py`
(`s2<x>_*.md`). The sealing pass's "witnesses" before A20 carry the artifact of §2.2.

### 5.1 Each form alone, against every form off (`a20old`)

| form (stage) | one request | means, off / on | its sealing pass | its receipt write | sys CPU |
|---|---|---|---|---|---|
| words in place, `cast1` (2a) | **+0.6%** (+0.5% (3, 1), +0.7% (3, 0)) | 15.391 / 15.477 s | +1.1% (0 of 6 lower) | −0.6% | −2.2% |
| **RECPAR** (2b) | **−23.3%** (−23.0% (3, 3), −23.6% (3, 3)) | 15.415 / 11.825 s | −39.4% (6 of 6): 9.136 / 5.533 s | −0.4% | −3.0% |
| **LOADS 3** (2c) | **−29.8%** (−30.1% (3, 3), −29.5% (3, 3)) | 15.444 / 10.841 s | −50.4% (6 of 6): 9.151 / 4.540 s | −0.1% | −11.9% |
| **WRITE 16** (2d) | **−10.2%** (−9.5% (3, 3), −10.8% (3, 3)) | 15.359 / 13.797 s | +0.6% | **−83.0%** (6 of 6): 1.952 / 0.332 s | −0.4% |

- **RECPAR alone**: each load 261 → 149 ms (the loads, summed, 8.36 → 4.76 s). The prove call +0.5% (noise), peak
  footprint 43.1 / 43.2 GiB.
- **LOADS 3 alone**:
  - three loads at once take 338 ms each (summed 8.36 → 10.82 s), but the pass waits only 2.17 s for them in all;
  - the builds, read without the artifact, are 1.69 s;
  - the sealing pass's sys CPU −17.4% and involuntary switches −16.5%: no global-pool worker blocks in `install`;
  - peak footprint 43.2 / 43.4 GiB.
- **WRITE 16 alone**: directory to receipt written 6.18 → 4.58 s; the prove call +0.6% (noise).

### 5.2 Every paying form together (2e): `a20old` against `recpar1+loads3+write16`

| clock | base first | test first | order bias solved out | means, off / on |
|---|---|---|---|---|
| **one request from its input** | −49.3% (3, 3) | −48.5% (3, 3) | **−48.9%** | 15.503 / 7.926 s |
| its sealing pass | −64.4% (3, 3) | −63.7% (3, 3) | −64.0% | 9.219 / 3.317 s |
| the loads, summed | | | −14.8% | 8.453 / 7.199 s |
| the builds, summed (before: the artifact) | | | −79.0% | 8.185 / 1.716 s |
| the pass's wait for its loads | | | | 0 / 0.957 s |
| its prove call | −0.7% (3, 2) | +0.3% (3, 1) | −0.2% | 4.240 / 4.230 s |
| its forks phase | | | −0.2% | 3.625 / 3.618 s |
| the receipt write | −84.0% (3, 3) | −83.5% (3, 3) | −83.8% | 1.964 / 0.319 s |
| directory to receipt written | | | −26.7% | 6.224 / 4.562 s |
| request user / sys CPU | | | +0.7% / −12.7% | |
| peak footprint | | | −0.1% | 43.08 / 43.05 GiB |

One request: best 15.384 → 7.819 s (8.32 → 16.37 proved tok/s), mean 8.26 → 16.15 tok/s.

### 5.3 The loads' width, every other form on (`recpar1+write16`)

| comparison (stage) | one request | means | its sealing pass | the pass's wait for its loads | sys CPU |
|---|---|---|---|---|---|
| loads 2 → 3 (2g) | **−6.1%** (−6.3% (3, 3), −5.9% (3, 3)) | 8.586 / 8.063 s | −14.3% (6 of 6): 3.907 / 3.348 s | −36.2%: 1.520 / 0.970 s | −1.6% |
| loads 3 → 4 (2f) | **−2.0%** (−1.2% (3, 2), −2.8% (3, 3)) | 8.095 / 7.931 s | −3.8% (6 of 6): 3.389 / 3.260 s | −15.2%: 0.932 / 0.789 s | −5.1% |

The peak footprint is 43.4 / 43.2 GiB (2g) and 43.6 / 43.6 GiB (2f). Where one request now goes (2f, loads 4, means):
- the sealing pass, 3.26 s: the builds 1.76 s, the wait for loads 0.79 s, the rest the first loads and the checks;
- the prove call, 4.28 s, of which the forks 3.63 s;
- the receipt write, 0.33 s.

## 6. Acceptance on the final tree [MEASURED]

Stage 9 is `s9.sh`: A19's `s9.sh` pointed at this worktree, with A20's tests, production's path on the default and two
confirmation A/Bs (`s9.progress`). It ran as one guarded job, 07:21–07:49 UTC, with no `ds4-bench` running at the
start or the end of any timing step.

- **Builds:**
  - the test binary rc 0, no warning in this lane's A20 code;
  - the no-feature `cargo check --tests` rc 0;
  - the production (non-test) library build rc 0. Its six dead-code warnings in these files (`recipe`, `new`,
    `constants_of`, `tied_of`, `table_keys_of`, `is_dd`) are the ones A19's final build had; none is new.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **945 passed, 3 failed, 119 ignored**. The three
  are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.

  A19's final tree had 941 / 3 / 116. A20 adds four suite tests and three ignored ones, and all four suite tests pass.
  So do R6's sealing-pass audit, s25's hash call-site census, `hash_domain`'s label scan, A19's suite tests and D60's
  F3 and F8 tests.
- **zkp-core's lib tests:** 81 passed, 2 ignored.
- **The device tests:**
  - A19's planned path and its controls; A19's production path;
  - A20's production path at the R13 rung under `a20old`, `recpar1+loads1+write2`, the defaults
    (`recpar true loads 4 writers 16`) and `recpar1+loads3+write8`. These gave one statement identity, `10a8fd14…`,
    and one refusal (layer 1's parity, with layers 2 and 3's loads failing);
  - A20's 8B test: one record under both settings, the same sealing pass at all seven settings and two budgets, and
    production's path under `a20old`, every form on and the defaults. Each receipt (102,772,480 B) verifies; its head
    is the replayed commit phase's; both interior forks equal the whole forks.
  - All pass.
- **Every earlier lane's byte test passes:**
  - A18: the rung golden under every setting, the 8B block, the parked forks on the device;
  - A16: the 8B witness planes in every form;
  - A17: the rung golden and the 8B block;
  - A15: the 8B chain in every pool;
  - A14: the 8B private tables, the rung golden and the 8B block;
  - A8's rung test; A12's census and rung modes; A11's pool tests (CPU and Metal); A7's queue test.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests:** 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and 90003b76 are all present.
  **The 8B core proof `90003b760eb7ad80`** is present.
- **The D55 harness on the default** (`s9_d55.log`; its sealing pass loads nothing, so A20 does not reach it; for
  reference only):

| W16R2 8B T128, 32 blocks, N = 6 | this run | A19's acceptance |
|---|---:|---:|
| proof only, best | 3.954 s = 32.37 tok/s | 4.006 s = 31.95 |
| one request from its input, best | 5.413 s = 23.65 tok/s | 5.577 s = 22.95 |
| stream of 4, steady / amortized | 32.10 / 28.48 tok/s | 32.63 / 28.92 |
| serial D12a, best | 9.056 s | 9.333 s |

- **Production's path on the default** (`s9_prod.log`, 2 passes): one request **7.725 s best = 16.57 proved tok/s**,
  7.736 s mean. A19's acceptance had 15.452 s = 8.28 tok/s. Pass 0 broke down as:
  - the sealing pass, 3.180 s (it waited 0.820 s for its loads, 4 ahead);
  - the prove call, 4.155 s (forks 3.566 s);
  - the receipt write, 0.328 s (16 writers);
  - peak footprint 42.6 GiB.
- **The confirmation A/Bs on this tree** (6 passes, both orders; `s9a_*`, `s9b_*`):

| comparison | one request | means | its sealing pass | its receipt write | its prove call | peak footprint |
|---|---|---|---|---|---|---|
| every A20 form off → the defaults (s9a) | **−50.6%** (−50.7% (3, 3), −50.5% (3, 3)) | 15.493 / 7.652 s | −66.2%: 9.258 / 3.127 s | −83.7%: 1.974 / 0.322 s | −0.9% | 43.45 / 43.47 GiB |
| the defaults with RECPAR off → the defaults (s9b) | **−11.4%** (−11.4% (3, 3), −11.4% (3, 3)) | 8.780 / 7.781 s | −22.2%: 4.122 / 3.207 s | −6.2% | −1.5% | 43.32 / 43.42 GiB |

  In s9a, one request's best went 15.266 → 7.585 s (8.38 → 16.88 proved tok/s). In s9b, the pass's wait for its loads
  went 1.727 → 0.799 s: RECPAR still pays with the loads ahead.
- **Receipts:** stage 9's 29 A/B calls are each 818,728,672 B, and 8 were verified from their run directories. With
  stage 2's 91, that is 120 production calls in all.

## 7. The default decisions

- **`HL_A20_RECPAR` on.** Alone −23.3% in every pair. With the loads ahead and the writers on (the defaults), turning
  it off costs +12.8% (s9b: the defaults −11.4% against the defaults with RECPAR off, 6 of 6). It is pure reordering
  of pure functions.
- **`HL_A20_LOADS` 4.**
  - Against none, −29.8% alone (at 3) and −48.9% with the others (at 3), in every pair. On the final tree, the
    defaults (at 4) are −50.6% against every form off (s9a).
  - The width: 2 → 3 −6.1% (6 of 6), 3 → 4 −2.0% (5 of 6; the sealing pass −3.8% in 6 of 6, sys CPU −5.1%).
    Four is the best width measured. Its cost is at most `n` blocks resident (§3.2), and the peak footprint did not
    move.
  - Production's real load also reads and SHA-256s the export's eleven arrays (another 218 MB of software SHA-256)
    and pads them, so it is heavier than the synthetic load, and loads ahead pay at least as much there [INFERRED].
- **`HL_A20_WRITE` 16.** −10.2% of one request alone in every pair. 34 writers were 56 ms faster in the profile
  (§2.3); 16 bounds the threads on a smaller machine. `0` or `1` restores the loop.
- **The words in place: removed** (+0.6%; §3.4).

## 8. H-1 (rulings D29, D68) under the forms: the argument

**The claim.** Under every A20 setting, every refusal of an inadmissible chain still happens in the sealing pass (or
in the statement checks after it), before the run header exists and before anything of the run is created. It
comes with the same string, from the same layer, in the same order.

1. **The refusals and their order are the old ones** [CODE, tested].
   - `seal_chain`'s body is R5b's, in the same order: layer `k`'s load result (`cur?`), its stage shape, the
     builder's refusal, CS-3's lookup-miss check, the parity check; then layer `k + 1`; then the first-plane check,
     the model's statement, and so on. The strings are unchanged.
   - Under LOADS a load may *run* earlier, but its result is looked at only at the top of its own iteration, after
     every check of every earlier layer has passed. A later layer's failed load is held in its slot. If an earlier
     layer refuses, the held result is dropped unseen.
   - Before A20, layer `k + 1`'s load already ran beside layer `k`'s build and was dropped the same way: A20 extends
     that look-ahead from one layer to `n`.
   - Tested at seven settings with a parity failure at layer 1 and load failures at layers 2 and 3: layer 1's parity
     refusal comes back, the same string as for a parity failure alone. Production's CLI was tested the same way
     (§4).
2. **No new refusal, none moved later** [CODE].
   - `LoadAhead` adds no check that input can reach. Its one assertion (`a loader thread ended in a panic`) fires
     only after a panic in a load, which is a bug, not a refusal, and the release profile aborts on a panic anyway.
   - RECPAR adds nothing. WRITE's failures are I/O errors of the run directory, after the header, as before; the
     caller removes the directory, as before. Every frame is attempted and the first failure in file order is
     returned, so a failure that is a function of the frame gives the loop's string.
3. **Nothing of the run exists earlier, and nothing outlives a refused chain** [CODE].
   - A load reads the public export (or, in the tests, the public synthetic block) and builds a public block and its
     record. It writes nothing and prints nothing.
   - The pass's return, refusal or not, stops the loaders (`StopLoads`: they start nothing new). The scope joins
     them, and every loaded-ahead block with them, before `seal_chain` returns: before any statement, header or run
     directory.
4. **Residual** [CODE]. A load that *panics* (a loader bug) on a layer ahead now aborts the process before an
   earlier layer's refusal would have been reported. Before A20 the same held for layer `k + 1` against layer `k`.
   No input-provokable refusal is affected.
5. **No schedule reads a hidden value** [CODE].
   - Which layers load when depends on `n` and on how far the pass has got.
   - The builds' times already depended on the hidden input (which layer refuses); the loads add only public work
     beside them.
   - The receipt write's work is fixed by the shape (the frame sizes).

## 9. For the privacy gate

- **Production digests that moved** (source pins):
  - `private_block/run_fork.rs`: `write_fork_receipt`, the new `write_fork_frame` and the `[A20]` switch
    (`a20_writers`). It is a source pin of the D55 capture.
  - `private_block/trained_block.rs`: `seal_chain` (inside a thread scope, with `LoadAhead`, `StopLoads` and
    `LoaderGuard`), `SealTimes`, `D55Times`, `d55_seal_and_prove`'s timing of the receipt write, `a20_loads`.
  - `private_block/trained_statement.rs`: `LayerRecord::of_block`'s order, `a20_switch` and `a20_recpar`.
- **Unchanged:** `protocol.rs`, `argument*.rs`, `witness*.rs`, `run.rs`, `private_block.rs` (`BlockPublic::digest`),
  `gpu/*`, zkp-core, `Cargo.toml` and `Cargo.lock`.
- **No byte of any receipt, statement, record or event moves** (§4). The CLI's events are unchanged.
- **No new path whose time depends on a hidden value** (§8.5).
- **Hashing, `unsafe` and labels.**
  - No new hash call site of s25's census: the record keeps `Sha256::digest`, the frames keep `digest_hex`.
  - No `unsafe` in production text: the in-place form was removed.
  - No new absorb label, generator or byte-string literal is on the block path. s25's census, s24 and `hash_domain`
    pass in the suite.
- **New threads.** Up to 4 loader threads (in a scope, joined before the pass returns) and up to 16 writer threads
  (in a scope, joined before the write returns). They hold only public blocks and receipt bytes. No witness and no
  private value is on a loader or writer thread: the private sequence (`m.seq`) is still read on the pass's own
  thread.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## 10. What is left

- **Software SHA-256 is now the largest host cost left in the sealing pass and the verifier's digest pass**
  [MEASURED, ESTIMATE].
  - `sha2 0.10.9` hashes at about 0.5 GB/s because its Arm SHA path needs the `asm` feature (crate `sha2-asm`, not
    in the offline registry). A hardware SHA-256 (the `asm` feature, a later `sha2` with stable aarch64 intrinsics,
    or a reviewed in-crate one) would cut each word hash about 4× [ESTIMATE: the Arm SHA-2 instructions' usual
    throughput]. That covers the record's 132 ms floor (one 67 MB word), production's array SHA-256s, the frame
    SHA-256s and the verifier's.
  - This needs a dependency ruling (`Cargo.toml` / `Cargo.lock`), outside this lane.
- **The block digest** (`BlockPublic::digest`, 115 ms, one BLAKE3 thread with its own copies) could hash in parallel
  with BLAKE3's own tree mode (`update_rayon`, the `rayon` feature: a `Cargo.lock` change) and without the copies. It
  is in `private_block.rs`, outside this lane. The digest would be the same, because BLAKE3's tree mode is the same
  hash.
- **Production's real load** (`load_layer_mode`) was not measured at 8B (no export on the Mac). It reads and SHA-256s
  the export's arrays, converts them (`i8s()`), pads and copies them again in the constructors. A synthetic 8B export
  would let the loads' width be tuned there.
- **The record kept per manifest digest for a resident model** (the digest pass done once, not per request) needs a
  ruling, as A19 said. With the loads ahead, the sealing pass is now within about 1.4 s of its builds (3.13 s against
  1.69 s, s9a).
- **The preflight's CS-6 re-hash of 32 blocks** (0.30 s; A19 §9) needs a ruling.
- **The receipt write could overlap the join, or each frame could be written as its fork finishes.** That is in
  `prove_forks_inner`, outside this lane. About 0.3 s is left.
- **The prove call (4.2 s, forks 3.6 s) is now more than half of production's 7.7 s request.** Its sealing pass
  (3.1 s) is 1.7 s of builds, 0.8 s of waiting for loads and the rest the first loads and the checks.
- **Not measured:** a trained 8B export, any machine but this one, a stream form of production.

## 11. Merge-conflict risks against perf

- **`trained_block.rs`:**
  - `seal_chain`'s loop now sits inside `std::thread::scope(|scope| { … })`: the same body, its `return`s and `?`s now
    the closure's. A lane editing the sealing pass must make its change inside the scope.
  - R6's source audit still finds `super::protocol::check_lookup_misses(&ssh, lay, &cur.blk, &w)` in `fn seal_chain(`
    and passes (stage 1).
  - `SealTimes` and `D55Times` gained fields (a struct literal elsewhere needs them).
  - `d55_seal_and_prove`'s proving closure returns one more value (the write's seconds).
- **`run_fork.rs`:** `write_fork_receipt`'s loop body is now `write_fork_frame`.
- **`trained_statement.rs`:** `of_block`'s body is restructured (two closures and a `join`).
- **`run_fork_tests.rs`:**
  - the `[A20]` block is appended;
  - `a19_production_d55_ab`'s `parse` returns an `A20Arm` too, and its PROD line gains fields at its end (the A19 and
    A11 parsers still read it).
- No file outside the lane's was edited.

## 12. This directory

- **Stage scripts:** `s1.sh` (byte evidence, suites, the profile, the sample); `s2.sh` (the A/Bs); `s9.sh` (the
  acceptance); `run_stage.py` (A19's runner, A20's labels); `prod_pairs.py` (paired changes of the PROD lines' clocks).
- **Records:** the progress files, guard records and `.done` markers; `s1_profile.log`, `s1_sample_a20old_top.txt`;
  `s2<a-g>_*` (`_prod_ab.log` trimmed, `_pairs.md`, `_seal.md`, `_prod_pairs.md`, `_table.md`); stage 9's.
- **Stage 1 was stopped by the agent after its measurements** (SIGTERM to its script, not the guard). Its quiet check
  (`pgrep -f ds4-bench`) also matched a guard wrapper queued behind this job's heavy lock with `ds4-bench` on its
  command line, and each waited for the other. The second sample and a smoke A/B did not run; stage 2 supersedes them.
  Stages 2 and 9 match a *running* `ds4-bench` by process name.
- **Raw logs** stay in `raw/` (not committed).
