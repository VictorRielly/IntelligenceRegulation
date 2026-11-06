# A23: `stack-serve`'s resident blocks shared across requests (2026-11-06)

Lane A23 of the efficiency plan (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`; it follows item A22). Rulings:
D70 (the stream form, byte-preserving per request) and D72 (CS-6 on the prover side may compare a kept digest). Built
on perf `ab7e63cb` (A21 and A22 merged).

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

The timing runs:
- shape: W16R2 8B T128, 32 blocks, N = 6 fork workers;
- settings: `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, a witness budget of 32 GiB (the Mac's default);
- forms in force: A13's window off, A19's shared blocks, A20's, A21's and A22's defaults;
- each stage was one guarded job on the shared M3 Ultra.

**Quiet GPU.** Every timing step waited for a quiet GPU (no running `ds4-bench`, matched by process name). Each step
recorded whether one ran at its end. A watcher also polled every 30 s while the step ran. Stage 2 saw no `ds4-bench`
at any point, so no clock here is POLLUTED.

The model is A22's: the D55 harness's synthetic block at the 8B geometry, served as a resident model whose startup
copies the block once per layer. That gives 32 distinct objects, as a real model has. There is no trained 8B export on
the Mac.

## 1. Plain summary

- **What was built.** Two switches.
  - **`HL_A23_SHARE`, on by default.** Every request reads the server's resident blocks themselves, by shared
    reference. Before, each request copied all 32 blocks (7.8 GB) and CS-6 hashed every copy again.
    - Each block's digest is computed once, on the object, at startup, and kept inseparably with it.
    - The prover's CS-6 compares that kept digest, as D72 permits. §9 checks the four conditions one by one.
  - **`HL_A23_CHECKED`, built and measured, off by default.** The prover's CS-1 / CS-4 check of a shared block takes
    the pass that this very object made at startup, at an equal shape. It skips a per-request scan, so it needs your
    ruling. §9a gives the equivalence argument.
- **The stream** [MEASURED, stage 2, 4 passes, alternating order]:

  | arm | steady tok/s | amortized tok/s | first request | peak footprint |
  |---|---:|---:|---:|---:|
  | `serve4`, today's code (blocks copied) | 29.49 | 25.09 | 7.39 s | 60.4 GiB |
  | **`serve4+share1`, the new default** | **31.35** | 27.02 | 6.70 s | 46.4 GiB |
  | `serve4+share1+chk1`, pending the ruling | **32.56** | 27.75 | 6.66 s | 46.1 GiB |
  | `serve8+share1+chk1` | 32.22 | 29.73 | 6.62 s | 45.7 GiB |
  | `harness4`, the D55 harness, same tree | 32.79 | 28.92 | 5.99 s | 54.6 GiB |
  | `serve1+share1+chk1` / `serve1` (one request) | | 20.17 / 18.67 | 6.35 / 6.86 s | 44.0 / 50.5 GiB |

  Paired results, steady:
  - share alone: **+6.4%** over `serve4`, 4 of 4 pairs;
  - the startup checks, on top of share: **+3.9%**, 4 of 4;
  - both together: **+10.5%** over `serve4`, 4 of 4;
  - the harness is now only +0.7% above share + checks (3 of 4 pairs), against +11.2% above `serve4`.
- **The gap to the harness is closed on the prover turn.**
  - The prove call of a later request falls from 4.343 s to 4.083 s (share), then to 3.929 s (with the checks).
  - Its preflight falls from 0.269 s to 0.097 s, then to 0.001 s.
  - The harness's period is 3.904 s (128 / 32.79).
  - **33 tok/s is not reached by default:**
    - the default reaches 31.35;
    - with the checks it reaches 32.56, 1.3% short of 33;
    - what is left is the fork run itself, 3.64 s of the 3.93 s period (§6).
- **The bytes** [MEASURED]:
  - Every request's statement identity, statement and frame list are `stack-prove`'s. A fresh `stack-verify` accepts
    the receipts, with the blocks shared, shared and checked, and copied (§4).
  - All 120 served 8B receipts of stage 2, and the cold one, are 818,728,672 B.
  - Heads replay, and interior forks equal whole forks.
  - No randomness is reused.
  - A wrong kept digest is refused by CS-6's name.
  - A refused request creates nothing, and the stream carries on.
- **Acceptance on the final tree** (§7) [MEASURED]:
  - **the suite:** 957 passed, exactly the known 3 failed;
  - **zkp-core:** 81 passed;
  - **the device and byte tests:** every one of A7 to A23 passes;
  - **golden** `96e4f0b6`, CPU = Metal; the six digests and the 8B core `90003b760eb7ad80` are present;
  - **no new warning;**
  - **the stream on the final tree:** the default `serve4` 31.75 steady, 27.16 amortized; `serve4+chk1` 32.57.
- **Footprint.** A stream's rise falls from 30.0 to 15.0 GiB, against the harness's 23.3 GiB. Two requests' block
  copies are gone [MEASURED, pass 0].
- **Startup** takes 0.868 s, against A22's 0.583 s. The startup now digests and checks each kept block once [MEASURED].

## 1a. The headline numbers, labelled

| quantity | value | label |
|---|---:|---|
| steady proved tok/s, stream of 4, the new default (`share1`) | 31.35 (30.91 to 31.76) | MEASURED, s2, 4 passes |
| steady, stream of 4, with the startup checks (`share1+chk1`, pending the ruling) | 32.56 (32.29 to 32.79) | MEASURED |
| steady, stream of 4, today's code (`serve4`, blocks copied) | 29.49 (28.62 to 29.90) | MEASURED |
| steady, the harness's stream of 4, same tree | 32.79 (32.55 to 32.98) | MEASURED |
| amortized, stream of 4: default / with checks / today / harness | 27.02 / 27.75 / 25.09 / 28.92 | MEASURED |
| amortized, stream of 8 with checks | 29.73 | MEASURED |
| one request, warm, with share and checks / today | 6.348 s = 20.17 tok/s / 6.855 s = 18.67 tok/s | MEASURED |
| the cold request | 7.363 s | MEASURED |
| startup (synthetic 8B, 32 layers) | 0.868 s, footprint 1.5 → 8.8 GiB | MEASURED |
| a stream of 4's footprint rise: today / share / harness | 30.0 / 15.0 / 23.3 GiB | MEASURED, pass 0 |
| CPU per request in a stream of 4: today / share / share + checks / harness | 60.6+17.2 / 55.8+14.3 / 54.4+13.0 / 47.2+8.5 user+sys s | MEASURED |

## 2. The interface

`stack-serve` is A22's, unchanged but for:
- **two new switches:**
  - `HL_A23_SHARE`: default 1; 0 restores A22's per-request copies, with `HL_A22_DIGEST_AHEAD` honoured;
  - `HL_A23_CHECKED`: default 0; 1 is a ruling's;
- **the `serve-start` line** gains `"shared_blocks"` and `"startup_checks"`. `"digest_ahead"` now reports whether the
  digests ahead are in force: they are moot, and not computed, while the blocks are shared.

`stack-prove`, `stack-verify` and every receipt, statement and event of theirs are unchanged.

## 3. The design

### 3.1 `HL_A23_SHARE`: the resident blocks shared, CS-6 on their startup digests (D72)

**Before** [CODE]:
- `Served::load_layer` copied each resident block for every request: 32 × 243 MB at 8B, 7.8 GB a request.
- It did so because `StackModel::load_layer` returns an owned `TrainedLayer { blk: BlockPublic }`, which `seal_chain`
  moves into `SealedBlocks`.
- The fork run's preflight then hashed every copy again for CS-6.

**Now** [CODE]:
- **`run::fork::KeptBlock`** (`run_fork.rs`): a resident block with its digest, computed on it at startup.
  - The one constructor is `KeptBlock::new(blk, shapes)`. It runs these steps:
    1. it places the block in its `Arc` allocation;
    2. it computes `BlockPublic::digest` (D2) over the block there;
    3. it runs `check_for_shape` (CS-1 / CS-4) at each of `shapes`;
    4. it writes the digest and the passed shapes into the same allocation through `Arc::get_mut`. At that point the
       `Arc` has one owner, and no other reference to it exists.
  - The block field is never written after that.
  - The fields are private to `run_fork.rs`. The methods are `block() -> &BlockPublic`, `digest()` and
    `passed_at(&Shape)`. None hands out `&mut`.
- **`run::fork::LayerBlock`**: what a load hands the sealing pass.
  - `Owned(BlockPublic)`: every load before A23, and always `stack-prove`'s.
  - `Shared(Arc<KeptBlock>)`: a resident block, by reference.
  - It is read through `Deref<Target = BlockPublic>` only, and is deliberately not `Clone`. So `.clone()` on it is a
    deep copy of the block, never a second share.
- **`SealedBlocks`** cells now hold a `LayerBlock`. `digest_of(k)` returns, in this order:
  1. A22's kept digest, when one was put (dig1);
  2. else a shared block's kept startup digest;
  3. else the block hashed now, as before.
- **The sealing pass's loads** (`seal_chain`, and A20's `LoadAhead`) now call `StackModel::seal_layer(k)`. It returns
  `trained_block::SealLayer`: the index, the manifest digest, the record and a `LayerBlock`.
  - The default implementation wraps `load_layer(k)`. So `stack-prove`, the tests' models and every other
    `StackModel` are unchanged.
  - `TrainedLayer` is unchanged. None of its other uses moved (the loader, the token-I/O load, the tests).
- **The startup** (`Resident::start`):
  1. each layer's checked load, as before;
  2. its block moved, with no copy, into `KeptBlock::new`, with the shapes {the run's base shape, the record's stage
     shape};
  3. the startup refuses unless the kept digest equals the record's `block_digest`. That is, the record the statement
     is made of must name this very object.
- **Each request** (`Served::new`, `HL_A23_SHARE=1`): `seal_layer(k)` hands over `LayerBlock::Shared(Arc::clone(..))`
  and a clone of the startup's record. Nothing is copied or hashed.
- **What is still per request:** its record list, its statement, its sealing-pass outputs, witnesses, endpoints,
  generators and run directory. The statement must still have the startup's identity before the run header, which is
  A22's check, unchanged. Only the public block object is shared.

### 3.2 `HL_A23_CHECKED` (off by default; it needs a ruling): CS-1 / CS-4 from the startup's pass

- **What it does** [CODE]:
  1. The prover's preflight, `run_fork::preflight_with(.., prover = true)`, asks its source for a startup record of
     block `k` at the stage shape it is about to check: `ForkBlocks::startup_checked`, `None` by default.
  2. `SealedBlocks` answers only when both hold:
     - the request enabled it (`with_startup_checks`, from `StackModel::startup_checks`, which `Served` sets only with
       the blocks shared);
     - the cell is a shared `KeptBlock` that passed `check_for_shape` at an EQUAL shape when it was made.
  3. The record it hands over is `protocol::CheckedPublic::of_kept`: A17's record type, for that very object.
  4. Otherwise the preflight runs `CheckedPublic::check`, as before.
- **Never on the verifier's side.** Both verifier entry points call `preflight(..)`, which is
  `preflight_with(.., false)`.
- **Unchanged:** the per-run parts of the preflight (the block count, the NTT tables, the endpoint policy's shape and
  spec) and CS-6.

### 3.3 Measured and left as they are

- **A smaller sealing pool in the stream** (`seal6`, `seal4`): under 1%, so it stays at A15's 8 (§5.2).
- **The receipt write** (0.217 s) and the statement files run after the prover turn, beside the next request's
  preflight and commit. They are not on the critical path, so they are left as they are (optional item 3).
- **`HL_A22_DIGEST_AHEAD`** and **A13's window** keep their defaults (off). With the blocks shared, the digests ahead
  are moot.

## 4. The byte evidence

**Why no byte can move** [CODE]:
- A request runs `d55_seal_and_prove` itself.
- With the blocks shared, its sealing pass and fork run read the very objects the startup's checked loads made. That
  is the same words a copy of them holds.
- Its record list is the startup's, so its statement is the same function of the same records.
- What differs between two runs is only the fresh randomness, as for `stack-prove`.

**Stage 1** (`s1.progress`) [MEASURED, CPU and Metal]:
- **`a23_cs6_and_cs1_cs4_take_a_shared_blocks_startup_record_and_a_wrong_digest_is_refused`** (suite):
  - A kept block's digest is D2 of the block.
  - Its startup pass is recorded at the run's shape. A failing shape (another gate denominator) records no pass.
  - A fork run over 3 shared kept blocks proves and verifies, with the startup checks off (0 records taken) and on
    (3 taken).
  - The verifier's preflight takes none, even from a source that offers them.
  - An owned block offers none.
  - A wrong kept digest at block 1 is refused, with the checks off and on: `private run: ruling CS-6 — block 1 handed
    to the run is not the block the run statement names (its public digest begins 0909090909090909, the statement's
    eb4e2594006e5526); refused before anything is absorbed`.
- **`a23_the_server_with_shared_blocks_proves_the_r13_export_as_stack_prove_does`** (suite, CPU; and Metal):
  - It runs A22's whole export check three times: blocks shared, shared and checked, and copied.
  - **The sealing pass:** the server's equals `stack-prove`'s word for word, at budgets everything and nothing.
  - **The stream:** A22's stream of 10 requests. It covers every refusal and failure kind: the parity refusal before
    the header, an existing run directory, the I/O failure after the header, the bad line, the reused run directory,
    and the statement-file failure.
  - **4 proved requests**, each verified by a fresh `stack-verify`:
    - statement identity `10a8fd14f6e75d8c`, `stack-prove`'s;
    - `statement.json` `stack-prove`'s, but its endpoint policy;
    - `segments.json`'s names and lengths `stack-prove`'s;
    - receipts of 62,099,008 B;
    - no two share an endpoint commitment, head, fork frame or tail;
    - startup passes taken: 4 a request when checked, 0 otherwise.
  - **Seeded lanes** at windows 0, 2 and L, with the digests ahead off and on: the heads replay, the interior forks
    equal whole forks, and the refused request leaves 0 parts alive.
- **`a23_the_resident_synthetic_rung_stream_with_shared_blocks_replays`** (suite; and Metal):
  - Shared and shared + checked, at windows 0/2/4/1 and lanes 2/2/2/3.
  - Every receipt (61,301,184 B) verifies from its run directory. The heads replay and the interior forks equal whole
    forks. The lie is refused before the run header with nothing created.
  - Startup passes taken: 4 a request when checked.
  - **At budget 0** (shared + checked, and copied for comparison): every witness is rebuilt in the fork run, 12 over 3
    requests. The rebuilds read the shared blocks while the next request's sealing pass reads the same objects, so two
    read-only views of the same pages exist at once. Same bytes.
- **`a23_the_resident_8b_stream_with_shared_blocks_replays`** (Metal, L = 4): shared, shared + checked, and budget 0.
  Each receipt is 102,772,480 B and verified. 12 witnesses are rebuilt at budget 0.
- **`a23_a_wrong_kept_digest_in_a_running_server_is_refused_by_cs6_and_the_stream_carries_on`** (suite):
  - Resident layer 1's kept digest is made wrong after the startup.
  - Shared, and shared + checked: each of 3 requests is refused with `prove_run: private run: ruling CS-6 — block 1 …;
    refused before anything is absorbed (the incomplete run directory was removed)`, and the stream carries on.
  - Copied: all 3 are proved, because CS-6 hashes each copy.
  - A resident record changed after the startup is refused before the run header, with nothing created.
- **A22's own tests** pass unchanged: its export stream, synthetic rung and 8B stream on the CPU and Metal, and its
  CS-6 test.
- **The audits** pass: R6's sealing-pass audit; s25's hash call-site census and file census; the absorb label scan;
  D60 F3 and F8; A19's, A20's and A21's suite tests. 17 passed, 0 failed.
- **No new hash entry point.** `KeptBlock::new` calls `BlockPublic::digest` through the method.

**Stage 2:**
- All 120 served 8B receipts are 818,728,672 B: 4 passes of 4+4+4+4+4+8+1+1 requests, and the cold one.
- Each arm's first pass was verified from its run directories: 31 receipts, plus the harness's 4.

## 5. The measurements [MEASURED, stage 2, `s2_table.md`, `s2_ab.log`]

- **The runs.** A22's A/B (`a22_stream_ab`), with arm words for A23 (`share0` / `share1`, `chk0` / `chk1`, `seal<t>`).
  4 passes, the arm order reversed in odd passes, quiet GPU throughout.
- **One resident model, started once:** 0.868 s, footprint 1.5 → 8.8 GiB. Then one cold request: 7.363 s.
- **The formulas.** `steady` = (R − 1) · 128 / (the last completion − the first). `amortized` = R · 128 / the last
  completion.
- **The arms' settings.** `serve4`, `serve1`: blocks copied (A22's code; `HL_A23_SHARE` was still 0 by default in
  stage 2).

### 5.1 The arms

| arm | steady tok/s, mean (min, max) | amortized tok/s, mean (min, max) | first request | mean latency from arrival | peak footprint |
|---|---:|---:|---:|---:|---:|
| `serve4` | 29.49 (28.62, 29.90) | 25.09 (24.43, 25.48) | 7.385 s | 14.018 s | 60.4 GiB |
| `serve4+share1` | 31.35 (30.91, 31.76) | 27.02 (26.62, 27.44) | 6.703 s | 12.918 s | 46.4 GiB |
| `serve4+share1+chk1` | 32.56 (32.29, 32.79) | 27.75 (27.67, 27.83) | 6.660 s | 12.623 s | 46.1 GiB |
| `serve4+share1+chk1+seal6` | 32.49 (31.69, 32.89) | 27.50 (27.12, 28.09) | 6.800 s | 12.796 s | 46.2 GiB |
| `serve4+share1+chk1+seal4` | 32.59 (32.16, 33.00) | 27.32 (27.11, 27.49) | 6.952 s | 12.874 s | 45.5 GiB |
| `serve8+share1+chk1` | 32.22 (31.87, 32.45) | 29.73 (29.51, 29.97) | 6.623 s | 16.654 s | 45.7 GiB |
| `serve1+share1+chk1` | | 20.17 (19.87, 20.46) | 6.348 s | 6.348 s | 44.0 GiB |
| `serve1` | | 18.67 (18.47, 18.77) | 6.855 s | 6.855 s | 50.5 GiB |
| `harness4` (H124d) | 32.79 (32.55, 32.98) | 28.92 (28.65, 29.14) | 5.990 s | 8.746 s* | 54.6 GiB |

\* Measured from each request's sealing start, as in A22 §5.5. The server's later requests take 7.76 s from their
sealing turn to their result (share + checks), against today's 8.60 s.

### 5.2 Paired changes (4 passes, both orders)

| comparison | steady | amortized | default decided |
|---|---|---|---|
| `serve4` → `serve4+share1` | **+6.4%** (4 of 4; +4.5% / +8.2% by order) | +7.7% (4 of 4) | **`HL_A23_SHARE` on** |
| `serve4+share1` → `+chk1` | **+3.9%** (4 of 4; +5.0% / +2.8%) | +2.7% (4 of 4) | wins by the rule; **off pending the ruling** |
| `serve4` → `serve4+share1+chk1` | +10.5% (4 of 4) | +10.6% (4 of 4) | |
| `serve4+share1+chk1` → `harness4` | +0.7% (3 of 4) | +4.2% (4 of 4) | |
| `serve4` → `harness4` | +11.2% (4 of 4) | +15.3% (4 of 4) | |
| `+chk1` → `+chk1+seal6` | −0.2% (3 of 4) | −0.9% (1 of 4) | unchanged (A15's 8) |
| `+chk1` → `+chk1+seal4` | +0.1% (2 of 4) | −1.5% (0 of 4) | unchanged |
| `serve4+share1+chk1` → `serve8+share1+chk1` | −1.1% (0 of 4) | +7.2% (4 of 4) | |
| `serve1` → `serve1+share1+chk1` | | +8.0% (4 of 4) | |

The rule: a form is on only if it wins at least 3 of 4 pairs with a mean gain above about 1%.

### 5.3 Each request's parts (means; "later" = every request of a stream but its first)

| arm | requests | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write | the sealing pass's loads, summed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `serve1` | 4 | 2.397 | 0 | 4.165 | 0.296 | 0.210 | 3.582 | 0.076 | 0.214 | 0.517 |
| `serve1+share1+chk1` | 4 | 2.179 | 0 | 3.894 | 0.002 | 0.211 | 3.604 | 0.079 | 0.227 | 0.000 |
| `serve4`, later | 12 | 3.979 | 0.321 | 4.343 | 0.269 | 0.244 | 3.754 | 0.077 | 0.240 | 0.589 |
| `serve4+share1`, later | 12 | 3.614 | 0.437 | **4.083** | 0.097 | 0.222 | 3.686 | 0.078 | 0.219 | 0.000 |
| `serve4+share1+chk1`, later | 12 | 3.593 | 0.301 | **3.929** | **0.001** | 0.213 | 3.639 | 0.076 | 0.217 | 0.000 |
| `serve8+share1+chk1`, later | 28 | 3.626 | 0.172 | 3.971 | 0.001 | 0.217 | 3.676 | 0.077 | 0.221 | 0.000 |

**What the shared blocks removed** [INFERRED]:
- **The copies.** The sealing pass's loads sum to about 0.000 s, against 0.52–0.59 s.
- **The sealing pass:** 2.40 → 2.18 s alone, and 3.98 → 3.61 s beside the forks.
- **CS-6's re-hash** (preflight 0.269 → 0.097 s).
- **Some of the forks' contention** (forks 3.754 → 3.686 s).
- **The memory and CPU** (§1a): 4.8 user and 2.9 system CPU-seconds a request, and 15 GiB of a stream of 4's rise.

**What the startup checks removed:** the CS-1 / CS-4 scan of 32 distinct objects. The preflight falls from 0.097 to
0.001 s, and the forks fall a little further (3.686 → 3.639 s), with less memory traffic beside them [INFERRED].

## 6. Where the time goes now

**The stream is still bound by the prover turn** [INFERRED]:
- A later request waits 0.17–0.44 s for the prover.
- With the checks, the period 128 / 32.56 = 3.931 s is the prove call (3.929 s).
- The harness's period is 3.904 s (128 / 32.79).

**The prove call of a later request (share + checks), 3.929 s:**

| part | seconds | what it is |
|---|---:|---|
| the preflight | 0.001 | the checks per run only |
| the commit phase | 0.213 | 31 boundary commitments; the harness's is about 0.21 (A22 §5.3) |
| the forks | 3.639 | the prover core; 3.604 for a request alone; the 0.035 s difference is the next request's sealing pass beside them |
| the join | 0.076 | |

**With the default** (share, no checks): 4.083 s, of which 0.097 s is the CS-1 / CS-4 scan.

**Production's prove call now matches the harness's.**
- Production's preflight (0.001 s) is shorter than the harness's (about 0.08 s, which re-checks its one object 32
  times).
- Its forks are about 0.06 s longer: beside them runs production's heavier sealing pass, 3.59 s against the harness's
  2.7–2.9 s.

**What is left to 33:**
1. **The fork run itself:** 3.64 s of the 3.93 s period. It is the prover core, outside this lane: W16R3, the
   per-fork kernels.
2. **The commit phase:** 0.21 s on the critical path.
   - It could run before the prover turn, beside the previous request's forks.
   - It draws the run's commit-phase randomness and absorbs into the run transcript, so it would move with the
     request, not across requests.
   - But the sealing side's slack is about 0.3 s (3.59 s of sealing against a 3.93 s period). Adding about 0.3 s of
     commit beside the forks would make the sealing side the bound.
   - [ESTIMATE] +0 to +3% steady. Not built.
3. **Amortized and one request.**
   - The first request's sealing pass is 2.12–2.18 s, against the harness's about 1.55 s. The extra is production's
     per-layer CS-3 check, the parity check and the production builder. CS-3 and parity read the private witness and
     must stay per request.
   - [ESTIMATE] Pipelining CS-3(k) beside build(k + 1), in layer order as A20 does for the loads, would cut the first
     request's latency, not the steady state. Not built.
4. **The receipt write** (0.217 s, `F_FULLFSYNC`) and the statement files are after the prover turn, beside the next
   request's preflight and commit. Not on the critical path.

## 7. Acceptance on the final tree [MEASURED]

**The run.** Stage 9 is `s9.sh`: A22's `s9.sh` list pointed at this worktree, with A23's tests added.
- It ran on the final tree (`HL_A23_SHARE` on by default) as one guarded job, 13:37–14:12 UTC, rc 0.
- The GPU was quiet (no `ds4-bench`) at the start and the end of every timing step, and at every 30 s poll while the
  stage ran.

**Builds:**
- the test build, the no-feature `cargo check --tests`, the production (non-test) library build and the CLI example
  `zk60_trained_block` all return rc 0;
- **no new warning:**
  - the non-test build's nine in `trained_statement.rs` / `trained_block.rs` / `run_fork.rs` / `protocol.rs` are A20's
    six (`recipe`, `new`, `constants_of`, `tied_of`, `table_keys_of`, `is_dd`) and three pre-existing in
    `protocol.rs` (two `mut` at lines 2303 and 2305, `pcs_params` at line 77; none is in A23's edit);
  - the test build's four in these files are pre-existing (A11's `cpu_seconds`, three of A19's / A20's).

**The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **957 passed, 3 failed, 130 ignored.**
- That is A22's 953, plus A23's 4 suite tests.
- The three failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
- **These pass in the suite:**
  - A23's 4 suite tests;
  - A22's three suite tests, which now run with the blocks shared by default;
  - A21's, A20's and A19's;
  - R6's sealing-pass audit;
  - s25's call-site, file and batch censuses;
  - the absorb-label scan;
  - D60 F3 and F8.

**zkp-core's lib tests:** 81 passed, 2 ignored.

**The device tests, all rc 0:**
- A23's: the R13 export through the server (shared, shared + checked, copied), the resident synthetic rung (shared,
  shared + checked, budget 0), and the resident 8B stack (shared + checked, and budget 0);
- A22's: the R13 export through the server, the resident synthetic rung and the resident 8B stream, at the new
  default;
- A19's planned path and production path;
- A20's production path (statement identity `10a8fd14…` under every arm) and its 8B test;
- A21's production path (the same identity, pinned) and its 8B test (102,772,480 B, verified);
- A18's rung golden, 8B block and parked forks;
- A16, A17, A15, A14, A12, A11, A8 and A7.

**The W16R2 rung golden:** CPU = Metal = `96e4f0b6f34f7876…`.

**The six post-F12 trained digests:** 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and 90003b76, all present.
**The 8B core proof `90003b760eb7ad80`** is present.

**The D55 harness on the default** (`s9_d55.log`):
- proof only: best 4.007 s = 31.94 tok/s;
- one request from its input: best 5.481 s;
- its stream of 4: 33.56 steady, 29.58 amortized.

**Production's one request** (`d55_seal_and_prove`, `stack-prove`'s path, untouched by A23; `s9_prod.log`): best
6.927 s = 18.48 tok/s.

**The server's stream on the final tree** (`s9_ab.log`, `s9_table.md`; 2 passes, both orders):

| arm | steady tok/s | amortized tok/s | first request | peak footprint |
|---|---:|---:|---:|---:|
| `serve1` (default) | | 19.88 | 6.440 s | 43.3 GiB |
| **`serve4` (default: blocks shared)** | **31.75** | 27.16 | 6.755 s | 45.5 GiB |
| `serve8` (default) | 30.82 | 28.59 | 6.745 s | 45.6 GiB |
| `serve4+share0` (A22's code) | 29.80 | 25.52 | 7.180 s | 59.3 GiB |
| `serve4+chk1` (pending the ruling) | 32.57 | 27.94 | 6.535 s | 45.2 GiB |
| `harness4` | 33.27 | 29.30 | 5.935 s | 54.4 GiB |

- **Paired, 2 of 2 each:**
  - share0 → the default: +6.5% steady;
  - the default → `+chk1`: +2.6%;
  - `+chk1` → `harness4`: +2.2%.
- **The startup** took 0.869 s.
- **Receipts.** All 42 served receipts, and the cold one, are 818,728,672 B. 22 were verified from their run
  directories, plus the harness's 4.
- **Agreement with stage 2.**
  - The default (31.75) and `chk1` (32.57) agree with stage 2 (31.35, 32.56).
  - The harness ran faster here (33.27, against 32.79 in stage 2), so its gap to `chk1` reads +2.2% here and +0.7%
    there. The 4-pass figure (§5) is the decision's.
  - `serve8` read −2.9% steady against `serve4` here (2 of 2), and −1.1% in stage 2. A longer stream does not raise
    the steady rate; it raises the amortized one.

## 8. H-1 per request (D29, D68), fresh randomness, no carry-over, the cached-record binding

**H-1** [CODE, tested]:
- **No refusal is added, moved or reworded by `HL_A23_SHARE`.**
  - Each request still runs `d55_seal_and_prove` itself, in its order:
    1. the sealing pass (`seal_chain`): the builder's refusals, CS-3, the parity check and the first-plane check;
    2. the model's statement, and A22's identity check;
    3. the endpoints and the bound statement;
    4. D60's door;
    5. `Planned::check`;
    6. then the run directory.
  - A load from the resident model is an `Arc` clone and a record clone. No input can make it fail.
- **CS-6 stays where it was:** in the fork run's preflight, after the run directory exists and before anything is
  absorbed, with the same string.
  - No input can provoke it: it compares two startup values of the public model.
  - A wrong kept digest (a corrupted resident model, here a test control) is refused there by CS-6's name.
    `fail_run` removes the run directory, and the stream carries on (tested, §4).
- **`HL_A23_CHECKED` removes no refusal.**
  - A block whose startup check did not pass at the preflight's shape is checked there as before, refused by CS-1 /
    CS-4's name.
  - A failed startup check refuses nothing at startup. It only leaves no record.
- **A refused request mid-stream** creates nothing, and the stream carries on. A22's whole export stream passes with
  the blocks shared, shared and checked, and copied (§4).
- **A changed resident record** (a test control) makes the request's statement differ from the startup's. It is
  refused before the run header, with nothing created (tested).

**Fresh randomness** [CODE, tested]:
- Unchanged from A22 §9. Nothing of a request's randomness is made at startup or kept.
- Each request draws inside its own `d55_seal_and_prove`: the endpoint commitments (`prepare_endpoints`), the boundary
  commitments, and every fork's coins (`run_fork`'s OS generators).
- In every mode, the export stream's 4 proved requests on the same input share no endpoint commitment, head, fork
  frame or tail (§4).

**No carry-over** [CODE]:
- **What a request shares:** only the resident public block objects, which it reads.
- **What stays its own:** its record list, statement, sealed planes, witnesses, endpoint owners, boundary owners,
  receipt and `SealedBlocks`. All of it is dropped with its `prove_one`.
- **The reference count.** A shared block's `Arc` count rises while a request holds it and falls when that request's
  `SealedBlocks` drops. So it is a function of how many requests are in flight, never of a hidden value.
- **Nothing private reaches a `KeptBlock`.** It is built once, at startup, from public data.
- **One data owner per process** stays the hard rule (A22 §2, decision (a)). Sharing changes nothing about it.

**The cached-record binding** (A22 §8, as it changes here) [CODE]:
- **Unchanged:**
  - A served receipt's statement binds the layer records the startup made.
  - The verifier (`stack-verify`) loads and hashes its own blocks from its copy of the export.
- **Changed, with the blocks shared:**
  - The prover proves with the very objects the startup loaded and checked.
  - Its CS-6 compares their startup digests, with no re-hash per request.
- **One consequence must be stated.**
  - A22 noted that a corruption of the resident copy in memory would be refused by the prover's CS-6, which re-hashed
    a copy per request. With the blocks shared, a corruption of a resident block after its startup digest would no
    longer be caught by the prover.
  - The receipt it produced would still be refused by `stack-verify`, which hashes its own blocks and checks the proof
    against them. So no receipt about other weights can be accepted.
  - This is the "hardware fault" residual that D72 names. The default A22 path has the same exposure between its
    preflight's hash and the forks' reads.
  - `HL_A23_CHECKED` extends it in the same way to CS-1 / CS-4.

## 9. The D72 conditions as built (`HL_A23_SHARE`)

D72 permits the prover's CS-6 to compare a kept digest when (i)–(iv) hold. As built [CODE]:

- **(i) Computed by `BlockPublic::digest` over that very object, after its last write.**
  - `KeptBlock::new` moves the loaded block into its `Arc` allocation, computes `a.blk.digest()` there, then writes
    only the `digest` and `passed` fields through `Arc::get_mut`.
  - `Arc::get_mut` would panic, by `expect`, if any other reference existed. None can: the `Arc` was made two lines
    before.
  - The block field is never written after that. No code path in the crate takes `&mut` of it (iii).
  - The startup then refuses unless this digest equals the startup record's `block_digest`. The startup's checked load
    computed that digest on the same object before the move.
- **(ii) Stored inseparably with the object.**
  - The digest is a field of the same `KeptBlock`, in the same `Arc` allocation.
  - CS-6 reads it from the very `LayerBlock::Shared` cell whose block the fork run proves with: `SealedBlocks::
    digest_of(k)` and `get(k)` read the same cell.
- **(iii) No `&mut` path, no interior mutability, no `unsafe` touching it, for the server's whole life.**
  - **`KeptBlock`.** Its fields are private to `run_fork.rs`. Its methods take `&self` and return a `&BlockPublic`, a
    copy of the digest, or a bool.
  - **`LayerBlock` and `SealedBlocks`.** `LayerBlock` gives `Deref` only, no `DerefMut`. `SealedBlocks` gives
    `&BlockPublic` only.
  - **`Resident`.** Its fields are private to `trained_block.rs`, and every production method takes `&self`.
    - The only `&mut self` methods are two `#[cfg(test)]` controls, `set_kept_digest_for_test` and
      `set_record_digest_for_test`. They are absent from every production build.
  - **`Arc::get_mut`** cannot succeed on a resident block after startup: the resident model holds one reference for
    the server's life.
    - Even with `&mut KeptBlock`, a caller outside `run_fork.rs` cannot reach its fields.
    - It could only replace the whole value with another `KeptBlock`, which only `KeptBlock::new` (digest computed) or
      a `#[cfg(test)]` constructor makes.
  - **`BlockPublic` has no interior mutability** (A22 §5.4): `Vec`s, an inline `[i16; 256]`, enums and plain structs.
    No `Cell`, `RefCell`, `OnceLock`, `Mutex`, atomic or raw pointer.
  - **`unsafe`:**
    - None in `trained_block.rs`, and none added anywhere.
    - `run_fork.rs` has two calls, both unrelated to blocks: `clock_gettime` and `pthread_set_qos_class_self_np`.
    - The one `unsafe` that reaches a block's memory is the Metal witness product's no-copy device view of a weight
      matrix (`gpu/metal.rs`, `page_view` / `weight_buffer`).
      - It is built from a `&[i8]`, bound to the kernel's `device const char *wbuf` argument, and only read.
      - It existed before A23, over each request's copy. With the blocks shared it reads the resident object.
      - Two such read-only views of the same pages can exist at once: one request's fork-run rebuild beside the next
        request's sealing pass. This was tested at budget 0 on the rung and the 8B block (§4).
- **(iv) A mismatch still refuses by CS-6's name.**
  - The preflight's comparison is unchanged (`digest_is_the_statements`).
  - Tested in a fork run over shared blocks, and in a running server. In the server, each request is refused by CS-6's
    name, its run directory is removed, and the stream carries on (§4).
- **The verifier is unchanged.** `stack-verify` loads and hashes its own blocks (`Vec<BlockPublic>`), never a
  `SealedBlocks`. Its preflight never takes a startup pass (`preflight_with(.., false)`).

## 9a. `HL_A23_CHECKED`: the equivalence argument (for your ruling)

**The proposal.** On the PROVER side only, the preflight's per-block CS-1 / CS-4 check (`check_for_shape`) of a
shared resident block may take the pass that `KeptBlock::new` ran on that very object when it was made. The pass must
be at a shape equal to the stage shape the preflight would check the block at. Four conditions, mirroring D72's:

- **(i)** The check ran on that very object, in its shared allocation, after its last write. It is the same place in
  `KeptBlock::new` as the digest.
- **(ii)** The passed shapes are stored inseparably with the object, in the same `KeptBlock`. The record is taken only
  from the cell the fork proves with.
- **(iii)** The object cannot change afterwards: D72 (iii), §9.
- **(iv)** A shape the startup did not pass is checked as before, and a failure refuses by CS-1 / CS-4's name. No
  record exists for a failed check: `KeptBlock::new` keeps only the shapes whose check returned `Ok`.

**Why it is equivalent** [CODE]:
- **The check is pure.** `BlockPublic::check_for_shape(sh)` is a pure function of the block's words and `sh`. It reads
  the block's fields and the shape's fields: geometry, accuracy registry, gate shift, DD cap.
  - It reads no environment switch and no global state. A2's parallel scan computes the same boolean as the serial one.
  - The word checks (`check_words`, `weights_vanish_off_support`, the table checks) are pure.
- **The startup's result still holds.** The words cannot change (iii), and the shape is compared for equality, with
  the same `Shape: PartialEq` comparison that A17's `CheckedPublic::covers` uses. So the startup's `Ok` is what the
  check would return again.
- **It extends an existing record.** A17 already lets each fork skip its own re-check when the preflight's record is
  for that very object at an equal shape. A23 extends the same record across the requests of one server, for objects
  that cannot change.
- **A18 is covered the same way.** A18's `covers_accuracy` (`define`'s registry re-check) holds the same: the
  startup's `check_for_shape` ran `check_accuracy_for_shape`, which runs `check_for_registry`.
- **The verifier always runs the check.**

**Tested** (§4):
- every block of every request takes its startup pass (4 of 4 on the R13 and synthetic rungs, 32 of 32 at 8B);
- a failing shape records no pass;
- an owned block and the verifier take none;
- the bytes are those with the switch off.

**What it does not cover:** a hardware fault in memory between the startup and a request's forks. The verifier
refuses such a receipt (§8).

**Measured:** +3.9% steady on the shared blocks (4 of 4), to 32.56 tok/s. **Status:** off by default
(`HL_A23_CHECKED=0`), pending the ruling.

## 10. For the privacy gate

**The production sources that moved** (SHA-256 of the file: perf `ab7e63cb` → this lane's final tree) [MEASURED]:

| file | perf ab7e63cb | A23 | what moved |
|---|---|---|---|
| `src/private_block/trained_block.rs` | `d3616df5…` | `156c4f59…` | `StackModel::seal_layer` / `startup_checks`; `SealLayer`; `SealHand::block` takes a `LayerBlock`; the loads (`TimedLoad`, `LoadAhead`, `seal_chain`'s `timed_load`) take `seal_layer`; `d55_seal_and_prove`'s `SealedBlocks::with_startup_checks`; `D55Times.startup_checked`; the `[A23]` switches; `ResidentLayer.blk` an `Arc<KeptBlock>`; `Resident::start`'s kept blocks and their check; two `#[cfg(test)]` controls; `Served::new`, `seal_layer`, `startup_checks`; the `serve-start` line's two fields |
| `src/private_block/run_fork.rs` | `a73edcfd…` | `109d1dda…` | `ForkBlocks::startup_checked`; `preflight_with` (the prover's call); `SealedBlocks`' `LayerBlock` cells, `with_startup_checks`, `startup_checked_hits`, `digest_of`'s kept digest, `startup_checked`; `KeptBlock`; `LayerBlock` |
| `src/private_block/protocol.rs` | `7b74a896…` | `f9a8c993…` | `CheckedPublic::of_kept` |

**Unchanged:**
- `run.rs`, `run_sink.rs`, `argument*.rs`, `witness*.rs`, `trained_statement.rs`, `private_block.rs`, `gpu/*`;
- zkp-core, `Cargo.toml` and `Cargo.lock`;
- the CLI example.

**No receipt, statement, record or `stack-prove` event byte moves** (§4).

**The censuses:**
- No new hash entry point: `KeptBlock::new` calls `BlockPublic::digest` through the method.
- No new absorb label, generator site or `unsafe`.
- s25's call-site and file censuses, the label scan and R6's audit pass (stage 1; the suite in stage 9).

**New threads:** none. **New pools:** none.

`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched. D63 stands.

## 11. What is left

- **The 33 tok/s target.** The default reaches 31.35 steady; with `HL_A23_CHECKED`, 32.56 [MEASURED]. The rest is
  the fork run itself (§6).
- **Rulings:**
  - **owed: `HL_A23_CHECKED`** (§9a). If ruled, its default becomes 1. It measured +3.9%, 4 of 4.
  - unchanged from A22: (a) more than one data owner per process; per-request `gpu_declines`.
- **Not built:**
  - the commit phase moved off the prover turn (§6 (2)), [ESTIMATE] +0 to +3%;
  - CS-3 pipelined in the sealing pass, for latency only (§6 (3)).
- **Not measured:**
  - a real trained 8B export's startup (no export on the Mac);
  - streams longer than 8;
  - any machine but this M3 Ultra.

## 12. Merge risks [CODE]

- **`trained_block.rs`:**
  - `StackModel` gains `seal_layer` and `startup_checks`, both with defaults, so other implementors are unaffected;
  - `SealHand::block` now takes a `run::fork::LayerBlock`;
  - `TimedLoad` and `LoadAhead` carry a `SealLayer`;
  - `D55Times` gains `startup_checked` (a struct literal elsewhere needs it);
  - `ResidentLayer.blk` is an `Arc<KeptBlock>`;
  - `Served` has two more fields and a constructor;
  - the A22 section gains the `[A23]` switches.
- **`run_fork.rs`:**
  - `SealedBlocks` cells are `OnceLock<LayerBlock>`, `put` / `put_digested` take `impl Into<LayerBlock>`, and it has
    two more fields;
  - `ForkBlocks` gains `startup_checked`, with a default;
  - `preflight` wraps `preflight_with`;
  - new: `KeptBlock`, `LayerBlock`.
  - `run_fork.rs` is a source pin of the D55 capture.
- **`protocol.rs`:** `CheckedPublic::of_kept`. It is a second constructor of A17's record, and makes a record only
  for a `KeptBlock`'s recorded pass.
- **`run_fork_tests.rs`:**
  - in A22's module, `a22_check_export_at` and `a22_check_synth_at` (budget and A23 switches), `A23Set` and
    `A23Reset`, and the A/B's arm words;
  - a new `mod a23` after A22's;
  - several A22 helpers are now `pub(super)`.
- **W16R3 or any lane that changes `seal_chain`'s loop or `SealedBlocks`** must keep `hand.block(k, cur.blk, ..)`
  moving the `LayerBlock`, and must keep the startup-pass lookup in the PROVER preflight only.

## 13. This directory

- **Stage scripts:**
  - `s1.sh`: the builds, the suite tests on the CPU, the audits, the device tests;
  - `s2.sh`: the A/B;
  - `s9.sh`: the acceptance;
  - `run_stage.py`: A22's runner, with A23's labels;
  - `stream_table.py`: A22's.
- **Records:**
  - each stage's progress file, guard record and `.done` marker;
  - stage 2: `s2_ab.log` (the A/B's lines, trimmed) and `s2_table.md`;
  - stage 9: `s9_ab.log`, `s9_table.md`, `s9_d55.log` and `s9_prod.log`.
- **History:** stage 1 ran before the default flip, and set the switch explicitly in every A23 test. Stage 2's
  `serve4` and `serve1` are therefore A22's code (blocks copied). Stage 9 ran on the final tree, with the blocks
  shared by default.
- **Raw logs** stay in `raw/`, not committed.
