# A21: production's hashing on this Mac, SHA-256 on the Arm SHA-2 instructions and the block digest by BLAKE3's tree (2026-11-06)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A21. Byte-preserving. It follows A20
(`../a20/README.md`, §2, §8, §9 and §10) on perf `e4a887e0` (A20 merged).

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

All timing runs: W16R2 8B T128, 32 blocks, N = 6 fork workers, `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, the
witness budget the Mac's default (32 GiB), A13's window off, the blocks shared and A20's forms at their defaults
(RECPAR on, loads 4 ahead, 16 writers), on the shared M3 Ultra. Every stage was one guarded job (the shared heavy
lock). Every timing step waited for a quiet GPU (no RUNNING `ds4-bench`, matched by process name) and recorded that
none ran at its end: no clock in this directory is POLLUTED. The model is the D55 harness's synthetic block loaded as
A19's `A19Synth` loads it (a fresh copy of the block, its layer record hashed). There is no trained 8B export on the
Mac, so production's real load (which also reads and SHA-256s the export's files, now on the instructions too) was not
measured at 8B.

## 1. Plain summary

- **Production's one request is 10.5% shorter** [MEASURED, through `trained_block::d55_seal_and_prove`, the function
  `stack-prove --d55-workers` runs, 6 passes, both orders]. Both A21 forms against neither (A20's defaults):
  **−10.5%, 7.873 → 7.045 s (16.26 → 18.17 proved tok/s; best 7.740 → 6.981 s = 18.33), 6 of 6 pairs** (s2c).
  - The sealing pass falls 3.245 → 2.597 s (−20.0%): its wait for its loads 0.795 → 0.070 s. It is now build-bound.
  - The prove call −1.6% (its preflight's CS-6 re-hash −16.1%), the receipt write 0.326 → 0.217 s (−33.1%).
  - The peak footprint falls 43.3 → 42.0 GiB (the block digest's 218 MB of copies are gone).
  - The acceptance's confirmation A/B on the final tree: −10.4%, 7.833 → 7.019 s, 6 of 6 (§6). Production's path on
    the default, best 6.942 s = 18.44 proved tok/s (A20's acceptance: 7.725 s = 16.57).
- **The verifier is 30% shorter** [MEASURED, `verify_run_with_forks_from_dir` on an 8B 32-block receipt, every block
  digest recomputed, 4 passes, both orders]: **−30.3%, 4.998 → 3.462 s, 4 of 4 pairs**; reading the receipt's 818 MB
  of frames and SHA-256ing them 1.757 → 0.469 s.
- **No byte moves** (§4): SHA-256 against `sha2` on the NIST vectors, every length 0..=1100 at eight offsets, lengths
  to 16 MB and the 8B words; the block digest against `blake3::hash` of its input written out independently, on four
  kinds of real block and 48 random ones at six leaf sizes; records, statement identity (`10a8fd14…`, pinned), the
  sealing pass, every refusal string, production's path at the R13 rung on the CPU and on Metal, and at 8B on Metal.
  All production A/B receipts are 818,728,672 B.
- **What the profile found** (§2) [MEASURED]: SHA-256 on the instructions runs at **2.31 GB/s against `sha2`'s 0.51**
  (4.5×); the block digest by the tree takes **5.9 ms against the one pass's 115.3** (19.5×). **A layer record falls
  138.7 → 32.2 ms**, and a load (copy and record) 143 → 36 ms, below one witness build (45 ms).
- **Two forms, both on by default** (§3, §5), each restored by its switch at `0`:
  - `HL_A21_SHA`: production's SHA-256s on the Arm SHA-2 instructions, in-tree (`run_sink::a21_sha`, no crate, no
    `Cargo.toml` / `Cargo.lock` change; `sha2` on every other target). Taken out of the defaults, one request +12.0%:
    with it **−10.7% (6 of 6)** (s2d).
  - `HL_A21_B3PAR`: `BlockPublic::digest` by BLAKE3's own tree, its subtrees in rayon tasks (blake3's public `hazmat`
    API, no crate feature). With it, inside the defaults, **−6.3% (6 of 6)** (s2e).
  - **They pay together**: alone, SHA −2.2% (s2a) and B3PAR −0.0% (s2b), because the record waits for the slower of
    its two halves (the nine word SHA-256s and the block digest run side by side under A20's RECPAR).
- **One optional form not built**: the receipt's frames written as their forks finish (§3.3). The write is now
  0.22 s and the join 0.08 s; the gain is at most about 0.2 s [ESTIMATE], for a change inside `prove_forks_inner`.
- **H-1 holds** (§8): both forms compute the same pure functions of the same public bytes; no refusal is added, moved
  or reworded (tested at every setting: a parity failure, a SHA-256 mismatch, both).
- **Acceptance passes** (§6): no new warning; the full suite 950 / the known 3 / 123; zkp-core 81; every device and
  earlier-lane byte test; the rung golden `96e4f0b6` CPU = Metal; the six digests and the 8B core `90003b760eb7ad80`.

## 2. The profile (stage 1; `s1_profile.log`)

`a21_profile_of_production_hashing` (ignored): the 8B block, medians of 6 repetitions, each part alone. Quiet GPU.

### 2.1 One word, one block, one layer [MEASURED]

| part | `sha2` / the one pass | A21 |
|---|---:|---:|
| SHA-256 of `wg_t` (67,108,864 B), the largest word | 132.7 ms = 0.51 GB/s | **29.0 ms = 2.31 GB/s** |
| SHA-256 of 16 MB of random bytes | 32.8 ms = 0.51 GB/s | 7.1 ms = 2.37 GB/s |
| SHA-256 of 1 MB of random bytes | 2.1 ms = 0.50 GB/s | 0.5 ms = 2.21 GB/s |
| the nine word SHA-256s in parallel (from their copies) | 144.3 ms | 31.9 ms |
| `BlockPublic::digest` | 115.3 ms (one pass, one thread) | **5.9 ms** (the tree, 1 MiB leaf) |
| … the tree at leaf 32 KiB / 128 KiB / 4 MiB | | 6.5 / 5.7 / 6.3 ms |
| the witness build alone (the sealing pool), for scale | 45.2 ms | |

| `LayerRecord::of_block` (and the synthetic load, copy + record) | record | load |
|---|---:|---:|
| A20's forms off (RECPAR off), A21's off | 254.0 ms | 256.7 ms |
| A20's default (RECPAR on), A21's off (`a21old`) | 138.7 ms | 143.1 ms |
| … SHA on, B3PAR off | 113.5 ms | 121.3 ms |
| … SHA off, B3PAR on | 138.5 ms | 143.4 ms |
| **… both on (the defaults)** | **32.2 ms** | **36.3 ms** |

The record runs the nine word SHA-256s (bound by `wg_t`, 132.7 → 29.0 ms) BESIDE the block digest (115.3 → 5.9 ms)
under RECPAR, so it takes the longer of the two: with one form alone the other half still dominates [INFERRED].

### 2.2 The preflight and the receipt [MEASURED]

| part (an 818,728,672 B receipt: head 1,072 B, 32 forks of 24,539,240 B, tail 33,471,920 B) | before | A21 |
|---|---:|---:|
| the preflight's CS-6 re-hash: 32 block digests, one rayon task a block | 188.9 ms | 152.3 ms |
| the frames' SHA-256s one after another (the verifier's `read_fork_receipt`) | 1,618 ms | 352 ms |
| the frames' SHA-256s in parallel (the global pool) | 116.4 ms | 25.9 ms |
| `write_fork_receipt`, 16 writers | 320.2 ms | 218.7 ms |

The preflight already hashed its 32 blocks in parallel, so the tree helps it less there (memory traffic, and the
copies gone) than inside one record.

### 2.3 Where production's request goes now [MEASURED, s2c means, the defaults]

- **The sealing pass, 2.60 s**: the witness builds 1.82 s summed; the wait for its loads 0.07 s (A20: 0.80 s); the
  rest (about 0.7 s) is the first layer's load, the per-layer checks (stage shape, CS-3, parity) and the statement.
  The loads beside it, summed, are 1.67 s (A20: 8.61 s). The pass is build-bound [INFERRED].
- **The prove call, 4.17 s**: preflight 0.32 s, commit 0.21 s, **forks 3.57 s**, join 0.08 s. The forks are now more
  than half of the request.
- **The receipt write, 0.22 s** (16 writers; now mostly `F_FULLFSYNC`, the SHA-256s 26 ms in parallel).
- Stage 1's `sample` of the defaults did not run (its process search found no test process 20 s in), so there is no
  stack profile of the A21 defaults; the clocks above come from the A/B's own lines.

## 3. The forms, and what changed

### 3.1 `run_sink.rs`: `HL_A21_SHA` (default on), the in-tree SHA-256

- **Why not `sha2`'s `asm` feature** [CODE]: `sha2 0.10.9`'s aarch64 backend is compiled only with feature `asm`,
  which pulls `sha2-asm`, not in the offline registry; on x86_64 the same feature would REPLACE the SHA-NI intrinsics
  path with plain assembly (a regression on the RTX 5090 box). It is not enabled.
- **The module** (`run_sink::a21_sha`, an inline module, so no new file on the module graph and no change to the
  capture's source-pin list):
  - FIPS 180-4 SHA-256. The compression function is on the stable `core::arch::aarch64` intrinsics `vsha256hq_u32`,
    `vsha256h2q_u32`, `vsha256su0q_u32`, `vsha256su1q_u32` (stable on `rustc 1.96`), in `#[target_feature(enable =
    "sha2")]` functions: four rounds per SHA256H / SHA256H2 pair, the schedule by SHA256SU0 / SHA256SU1.
  - The whole blocks are hashed in place; the last partial block and the padding (§5.1.1) go through a 128-byte
    stack buffer, one or two blocks. The code branches on the length only.
  - `instructions()` is taken only after `is_aarch64_feature_detected!("sha2")`; on every other target, on a CPU
    without the extension and with `HL_A21_SHA=0`, the wrapper is `sha2::Sha256::digest`, exactly as before.
  - **`unsafe`, all in this module, each with a SAFETY comment**: the one call of the `#[target_feature]` function
    (after the detection), and the `vld1q_u8` / `vld1q_u32` / `vst1q_u32` loads and stores, each over a
    fixed-size array reference (`&[u8; 16]`, `&[u32; 4]`) of exactly the bytes the intrinsic reads or writes.
- **One wrapper, `a21_sha::sha256`**, the switch covering all of production's request path: `trained_statement::sha`
  (the record's nine word and three table SHA-256s), `trained_block::sha256` (the export loader's per-array checks in
  `load_array_checked`, the manifests, the profile, the rotation file, the sequence files) and `run_sink::digest_hex`
  (each receipt frame's SHA-256, written by `write_fork_receipt` and verified by `read_fork_receipt`; D12a's segment
  digests too). The `sha2` imports of `trained_statement.rs` and `trained_block.rs` went with their one use.
- The switch is A20's `a20_switch` (the environment once, a test override).

### 3.2 `private_block.rs`: `HL_A21_B3PAR` (default on), the block digest by BLAKE3's tree

- **What** [CODE]: `BlockPublic::digest` (D2) with B3PAR on returns `a21_digest_tree(1 MiB)`. Its input is the one
  pass's, in its order, as pieces (`a21_pieces`): the domain literal, each word's length and its int8 words (by
  reference), each table's length and its little-endian encoding, the activation table, and the accuracy data's
  label, length and encoding. The pieces form one virtual stream; the tree splits it as BLAKE3 splits any input
  (`hazmat::left_subtree_len`), each subtree of at most 1 MiB is hashed by one `Hasher` at its offset
  (`set_input_offset`, `finalize_non_root`) in a rayon task, and the chaining values are merged as BLAKE3's parent
  nodes (`merge_subtrees_non_root`, the top one `merge_subtrees_root`). BLAKE3's hash IS this tree, so the 32 bytes
  are `blake3::hash` of the input. zkp-core's transcript (A14) walks the same tree the same way.
- **No copies, no `unsafe`**: the int8 words are fed through a 16 KiB stack buffer of their `*v as u8` bytes, so the
  one pass's 218 MB of `collect::<Vec<u8>>()` copies are gone.
- **No crate feature and no `Cargo.lock` change**: `blake3::hazmat` is public in 1.8.7 without features; the
  `rayon` feature (`update_rayon`) was not needed.
- At `HL_A21_B3PAR=0` the one pass runs, its text unchanged.

### 3.3 Not built: the receipt's frames written as their forks finish

The write is now 0.217 s (s2c) and the join 0.08 s, so overlapping the write with the join gains nothing measurable;
writing each fork's frame as it finishes would hide at most about 0.2 s behind the forks [ESTIMATE], but needs a
frame writer inside `prove_forks_inner` (its callers, its error order and A19's test hooks). Left for a later lane.

### 3.4 s25's census (`s25_tests.rs`)

`every_hash_call_site_in_the_lanes_own_sources_is_classified` now also looks for six entry points: the four
`hazmat` calls (`set_input_offset(`, `finalize_non_root(`, `merge_subtrees_non_root(`, `merge_subtrees_root(`), the
round instruction `vsha256hq_u32(` and the wrapper `a21_sha::sha256(`. `private_block.rs`'s `blake3::Hasher::new(`
row is 2 (the one pass and the tree's subtree hasher), and eight rows are new, each with its kind: the four hazmat
calls in `private_block.rs` (D2's tree form), the round instruction and `digest_hex`'s wrapper call in `run_sink.rs`,
and the wrapper calls in `trained_statement.rs` and `trained_block.rs`. Nothing is removed or relaxed.
`Sha256::digest(` was never an entry point of this table and still is not.

### 3.5 Tests (`run_fork_tests.rs`, the `[A21]` block at the end)

- In the suite:
  - `a21_sha256_is_sha2s_on_the_nist_vectors_every_length_to_1100_random_lengths_to_16_mb_and_unaligned_slices`;
  - `a21_block_digests_are_the_same_by_blake3s_tree_and_by_the_one_pass`;
  - `a21_layer_records_and_the_statement_identity_are_the_same_under_every_setting`;
  - `a21_the_sealing_pass_and_its_refusals_are_the_same_under_every_setting`;
  - `a21_production_d55_path_under_the_forms_off_and_on_at_the_r13_rung`.
- Ignored: `…_on_the_device` (Metal), `a21_the_8b_words_digest_record_sealing_pass_and_production_path_under_every_setting`
  (Metal), `a21_profile_of_production_hashing`, `a21_verifier_ab`.
- A19's production A/B (`a19_production_d55_ab`) takes A21's words: `a21old` (both off), `sha0/1`, `b3par0/1`. Its
  PROD line ends with the A21 forms in force (and whether the instructions are in use).
- The tests that set A21's switches take A20's `a20_knobs()` lock.

## 4. The byte evidence [MEASURED]

**Why no byte can move** [CODE]:
- **SHA**: SHA-256 is a function; the instruction path computes FIPS 180-4's (the same rounds, constants and
  padding), the fallback is `sha2`'s. Every digest a check compares, a record holds or a refusal prints is the same.
- **B3PAR**: the input is the one pass's byte for byte (the same fields, framings and order), and BLAKE3's hash of an
  input is the root of its tree however the tree is computed.

Stage 0 and stage 1 (`s0.progress`, `s1.progress`; stage 9 repeats all of it on the final tree, §6):
- **SHA-256** (suite): the five FIPS 180-4 examples (empty, `abc`, the 448- and 896-bit messages, one million `a`)
  against their published digests; every length 0..=1100 at offsets 0..=7 of one buffer (every padding case,
  unaligned sub-slices); 16 lengths to 16 MB at random offsets (16 MB itself and around 1 MB + 56). Each on the
  instructions alone, through the wrapper at both settings and through `digest_hex` at both, against `sha2`. On the
  device (8B test): the nine 8B words, each also from its second byte.
- **The block digest** (suite): the W16R2 rung block (`eb4e2594…`), a legacy block (`fdddc744…`), every layer of a
  4-layer R13 export through the loader (`98d82e8a…`, pinned), 48 random blocks (7,055 B to 4.8 MB, words and tables
  of random lengths, some empty, with and without accuracy data) and, on the device, the 8B block (`04c8bd7c…`):
  `digest()` at both settings and the tree at leaves 1, 2, 4, 32 KiB, 1 and 4 MiB all equal `blake3::hash` of the
  input written out field by field in the test.
- **Records**: one record under all eight settings (A21's four × RECPAR's two) at the rung, legacy and 8B blocks
  (its block digest that `blake3::hash`, its word SHA-256s `sha2`'s); the R13 export's records through the loader
  under all four A21 settings, and its statement identity **`10a8fd14f6e75d8c70866fd315f9e8a0834de167a023b5deec4a8010e51c0960`**
  (pinned) under each.
- **The sealing pass**: everything `seal_chain` returns but its clocks (A20's summary), the same under all four A21
  settings at loads 0 and 4 and budgets of everything and nothing, on the R13 export and on A19's synthetic 8B stack
  (L = 4, identity `05ea9df9…`).
- **The refusals**, each one string under all eight (setting, loads) pairs:
  - a parity failure at layer 1: `layer 1: parity: … (before the run header; ruling H-1)`;
  - a SHA-256 mismatch at layer 2: `layer 2: array \`wq\`: SHA-256 mismatch: the manifest says 19224214…, the file is
    d0baf382…` (the printed digest is the instructions' and `sha2`'s alike);
  - a parity failure at layer 1 with SHA-256 mismatches at layers 2 and 3: layer 1's parity refusal.
- **Production's path at the R13 rung** (`stack-prove --d55-workers` on the 4-layer R13 export), A19's whole check
  under each arm (a fresh `stack-verify` passes, the head is the replayed commit phase's, every interior fork equals
  that fork proved whole, the refused chain gives window 0's string, creates nothing, keeps no part alive), and beside
  it the pinned statement identity and the same refusal of a chain whose layer 1 fails parity and layers 2-3 their
  SHA-256 checks:
  - CPU (suite): `a21old` and `default`, A19's arms (window 0 and 2, N 2);
  - Metal: `a20old+a21old`, `a21old`, `sha1+b3par0`, `sha0+b3par1` and `default`, A19's arms (window 0 at N 3, shared
    and reloaded; window 4 at N 6).
- **Production's path at 8B on Metal** (`d55_seal_and_prove` on the synthetic 8B stack, L = 4, seeded generators),
  under `a21old`, `sha1+b3par0`, `sha0+b3par1` and the defaults: each receipt (102,772,480 B, 6 frames) verifies from
  its run directory under the same arm (over a `Vec` of the blocks, so the verifier recomputes every block digest),
  its head is the replayed commit phase's and both interior forks equal those forks proved whole. (Stage 1's run of
  this test ended in a wrong final assertion, that the four calls' frames have the same SHA-256s: each call draws its
  endpoint commitments afresh in `prepare_endpoints`, so no two calls' receipts are the same bytes. It now compares
  the frame lengths; commit `44d9e466`. Every check before it had passed.)
- **The verifier's A/B** (§5.3): the same frame list (lengths and SHA-256s) verified under all four arms.
- **Every production A/B call** (§5): 65 calls, every receipt 818,728,672 B; each A/B's cold call and each arm's first
  pass verified from its run directory (15 receipts).
- **The suites the forms touch** (stage 0): the D55 fork-run suite (37 passed, A21's five included), s25's census
  (20), R6's sealing-pass audit (6), `hash_domain`'s label scan (15, stage 1).

## 5. The A/Bs through production's function [MEASURED]

`a19_production_d55_ab` (stage 2, `s2.progress`), each a 2-arm A/B: 6 passes after one cold call, the order reversed
in odd passes. Cells read "mean change (pairs, pairs where the test arm was lower)"; "order bias solved out" is the
mean of the two orders' means. Tables: `../a11/pairs.py --alternate --n 6`, `../a15/seal_pairs.py`, `prod_pairs.py`
(A20's with the preflight and commit clocks and a pair count) and `../a19/prod_table.py` (`s2<x>_*.md`).

### 5.1 Both forms against neither (s2c): `a21old` → the defaults

| clock | base first | test first | order bias solved out | means, off / on | test lower in |
|---|---|---|---|---|---|
| **one request from its input** | −10.3% (3, 3) | −10.7% (3, 3) | **−10.5%** | 7.873 / 7.045 s | 6 of 6 |
| its sealing pass | −20.2% (3, 3) | −19.7% (3, 3) | −20.0% | 3.245 / 2.597 s | 6 of 6 |
| the loads beside it, summed | | | −80.6% | 8.609 / 1.669 s | 6 of 6 |
| the witness builds, summed | | | +1.7% | 1.790 / 1.819 s | 1 of 6 |
| the pass's wait for its loads | | | −91.2% | 0.795 / 0.070 s | 6 of 6 |
| its prove call | −1.1% (3, 2) | −2.1% (3, 2) | −1.6% | 4.241 / 4.171 s | 4 of 6 |
| … its preflight (CS-6 re-hash) | | | −16.1% | 0.382 / 0.319 s | 6 of 6 |
| … its forks phase | | | −0.1% | 3.573 / 3.568 s | 3 of 6 |
| the receipt write | −31.9% (3, 3) | −34.4% (3, 3) | −33.1% | 0.326 / 0.217 s | 6 of 6 |
| directory to receipt written | | | −3.9% | 4.580 / 4.400 s | 6 of 6 |
| request user / sys CPU | | | −17.0% / +5.4% | 80.3 / 66.6, 16.8 / 17.7 s | |
| peak footprint | | | −3.0% | 43.30 / 42.00 GiB | 6 of 6 |

One request: best 7.740 → 6.981 s (16.54 → 18.33 proved tok/s), mean 16.26 → 18.17 tok/s. The sealing pass's sys CPU
rises +19.7% and its involuntary switches +28.2%: the loads now end inside a build, and their rayon tasks share the
cores with the sealing pool [INFERRED].

### 5.2 Each form alone, and each taken out of the defaults

| comparison (stage) | one request | means | its sealing pass | its preflight | its receipt write | peak footprint |
|---|---|---|---|---|---|---|
| SHA alone: `a21old` → `+sha1` (s2a) | **−2.2%** (−1.9% (3, 3), −2.5% (3, 3)), 6 of 6 | 8.246 / 8.063 s | −3.0% (5 of 6) | −1.2% | −33.7% | +0.0% |
| B3PAR alone: `a21old` → `+b3par1` (s2b) | **−0.0%** (+0.3% (3, 1), −0.3% (3, 1)), 2 of 6 | 8.248 / 8.247 s | +2.7% (0 of 6) | −16.5% | −3.4% | −3.6% |
| SHA in the defaults: `default+sha0` → `default` (s2d) | **−10.7%** (−12.0% (3, 3), −9.5% (3, 3)), 6 of 6 | 7.937 / 7.083 s | −21.9% (6 of 6) | −6.1% | −30.2% | −0.2% |
| B3PAR in the defaults: `default+b3par0` → `default` (s2e) | **−6.3%** (−5.9% (3, 3), −6.7% (3, 3)), 6 of 6 | 7.520 / 7.049 s | −13.6% (6 of 6) | −19.0% | +1.1% | −3.2% |

- **SHA alone** shortens each load (the loads summed −8.6%) but the record still waits for the one-pass block digest
  (115 ms), so the pass's wait for its loads falls only 0.64 → 0.45 s.
- **B3PAR alone** shortens the preflight (−16.5%) and the peak footprint (−3.6%), and moves one request by nothing:
  the record waits for its software SHA-256s; the pass is +2.7% (its builds beside 32-way digest tasks +6.3%).
- **Inside the defaults each pays**: without SHA the pass waits 0.80 s for its loads (s2d), without B3PAR 0.61 s
  (s2e); with both 0.07 s.

### 5.3 The verifier (stage 1; `s1_verify_ab.log`, `s1_verify_pairs.md`)

`a21_verifier_ab`: one 8B 32-block receipt proved once (the defaults), then verified from its run directory by
`verify_run_with_forks_from_dir` over a `Vec` of the 32 blocks (6 workers; the preflight recomputes every block
digest, as `stack-verify` does), 4 passes, the arm order reversed in odd passes.

| arm against `a21old` (4.998 s; `read_fork_receipt` 1.757 s) | verify | `read_fork_receipt` alone |
|---|---|---|
| **both (the defaults)** | **−30.3%**, 3.462 s, 4 of 4 | −73.3%, 0.469 s, 4 of 4 |
| SHA alone (`sha1+b3par0`) | −27.2%, 3.607 s, 4 of 4 | −73.4%, 0.468 s, 4 of 4 |
| B3PAR alone (`sha0+b3par1`) | −5.1%, 4.718 s, 2 of 4 | −1.6%, 1.730 s, 4 of 4 |

The verifier's frame digests run one after another (`read_fork_receipt`), so SHA pays there by itself.

## 6. Acceptance on the final tree [MEASURED]

Stage 9 is `s9.sh`: A20's `s9.sh` pointed at this worktree, with A21's tests, production's path on the default and a
confirmation A/B (`s9.progress`). It ran as one guarded job, 09:55–10:18 UTC, on the tree of `44d9e466` (the commits
after it add records only), with no `ds4-bench` running at the start or the end of any timing step.

- **Builds**:
  - the test binary rc 0, **no new warning**: 28 located warnings, the same (message, file) pairs as A20's stage-9
    test build (`warn_diff.py`);
  - the no-feature `cargo check --tests` rc 0;
  - the production (non-test) library build rc 0, **no new warning**: 101 located warnings, the same as A20's.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures): **950 passed, 3 failed, 123 ignored**. The
  three are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.

  A20's final tree had 945 / 3 / 119. A21 adds five suite tests and four ignored ones, and all five pass. So do s25's
  census, `hash_domain`'s label scan, R6's sealing-pass audit, A19's and A20's suite tests and D60's F3 and F8 tests.
- **zkp-core's lib tests**: 81 passed, 2 ignored.
- **The device tests**, all pass:
  - A19's planned path and its controls; A19's production path;
  - A20's production path at the R13 rung (its four arms: one statement identity, `10a8fd14…`, one refusal) and its
    8B test;
  - A21's production path at the R13 rung on Metal under `a20old+a21old`, `a21old`, `sha1+b3par0`, `sha0+b3par1` and
    `default` (the pinned identity, the same refusal);
  - A21's 8B test, its final check corrected (§4): the nine words, the digest at every leaf, one record under eight
    settings, the same sealing pass under every A21 setting at loads 0 and 4 and two budgets, and production's path
    under four arms, each receipt verified, its head replayed, its interior forks whole, the same six frame lengths
    (102,772,480 B) under every arm.
- **Every earlier lane's byte test passes**: A18 (the rung golden under every setting, the 8B block, the parked
  forks on the device); A16 (the 8B witness planes in every form); A17 (the rung golden and the 8B block); A15 (the 8B
  chain in every pool); A14 (the 8B private tables, the rung golden and the 8B block); A8's rung test; A12's census
  and rung modes; A11's pool tests (CPU and Metal); A7's queue test.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests**: 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and 90003b76 are all present.
  **The 8B core proof `90003b760eb7ad80`** is present.
- **The D55 harness on the default** (`s9_d55.log`; its sealing pass loads nothing and its blocks' digests are held
  once, so A21 barely reaches it; for reference only):

| W16R2 8B T128, 32 blocks, N = 6 | this run | A20's acceptance |
|---|---:|---:|
| proof only, best | 3.843 s = 33.30 tok/s | 3.954 s = 32.37 |
| one request from its input, best | 5.521 s = 23.18 tok/s | 5.413 s = 23.65 |
| stream of 4, steady / amortized | 32.61 / 28.98 tok/s | 32.10 / 28.48 |
| serial D12a, best | 9.156 s | 9.056 s |

- **Production's path on the default** (`s9_prod.log`, 2 passes): one request **6.942 s best = 18.44 proved tok/s**,
  7.024 s mean (A20's acceptance: 7.725 s best = 16.57). Pass 1: the sealing pass 2.595 s (the builds 1.759 s); the
  prove call 4.036 s (preflight 0.259, commit 0.226, forks 3.481, join 0.070 s); the receipt 818,728,672 B; peak
  footprint 41.9 GiB.
- **The confirmation A/B on this tree** (6 passes, both orders; `s9a_*`): the defaults against both forms off
  (`a21old`):

| clock | base first | test first | order bias solved out | means, off / on | test lower in |
|---|---|---|---|---|---|
| **one request from its input** | −9.8% (3, 3) | −10.9% (3, 3) | **−10.4%** | 7.833 / 7.019 s | 6 of 6 |
| its sealing pass | −18.6% (3, 3) | −19.8% (3, 3) | −19.2% | 3.199 / 2.584 s | 6 of 6 |
| the pass's wait for its loads | | | −92.1% | 0.807 / 0.064 s | 6 of 6 |
| its prove call | −1.6% (3, 3) | −2.7% (3, 3) | −2.2% | 4.250 / 4.158 s | 6 of 6 |
| … its preflight | | | −12.8% | 0.355 / 0.309 s | 6 of 6 |
| the receipt write | | | −32.0% | 0.320 / 0.217 s | 6 of 6 |
| request user / sys CPU | | | −16.9% / +5.9% | 80.3 / 66.7, 16.7 / 17.7 s | |
| peak footprint | | | −3.2% | 43.17 / 41.80 GiB | 6 of 6 |

  One request's best went 7.783 → 6.913 s (16.45 → 18.51 proved tok/s).
- **Receipts**: stage 9's 16 production calls are each 818,728,672 B, and 5 were verified from their run directories.
  With stage 2's 65 and stage 1's 4, that is 85 production calls in all.

## 7. The default decisions

- **`HL_A21_SHA` on.** Inside the defaults −10.7% of one request in every pair (s2d), the sealing pass −21.9%, the
  receipt write −30.2%; the verifier −27.2% alone (4 of 4). It is the same function. `0` restores `sha2`.
- **`HL_A21_B3PAR` on, leaf 1 MiB.** Inside the defaults −6.3% in every pair (s2e), the sealing pass −13.6%, the
  preflight −19.0%, the peak footprint −3.2%. Alone it moves one request by nothing (s2b), because the record then
  waits for its SHA-256s; with SHA on it removes the record's other half. The leaf size does not matter between 32 KiB
  and 4 MiB (5.7–6.5 ms, §2.1); 1 MiB keeps about 200 tasks a block. `0` restores the one pass.
- **The receipt write's overlap: not built** (§3.3).
- Both forms together against neither: −10.5%, 6 of 6 (s2c), and the verifier −30.3%, 4 of 4.

## 8. H-1 (rulings D29, D68) under the forms: the argument

**The claim.** Under every A21 setting, every refusal of an inadmissible chain still happens in the sealing pass (or
in the statement checks after it), before the run header exists and before anything of the run is created, with the
same string, from the same layer, in the same order.

1. **Only pure functions are accelerated** [CODE]. The record's SHA-256s and block digest, the loader's per-array
   SHA-256s and the frames' SHA-256s are each computed by another implementation of the same function, on the same
   bytes, at the same place in the same order. No check is added, skipped or moved; no string changes, and a string
   that prints a digest prints the same digest (tested: the layer-2 SHA-256 mismatch).
2. **No new refusal** [CODE]. `instructions()` returning `None` is a fallback to `sha2`, not a refusal. The new code's
   assertions (`compress`'s whole-block length, the fixed-size `try_into`s, `set_input_offset`'s chunk alignment and
   `finalize_non_root`'s non-empty subtree inside blake3) hold by construction: the whole blocks are a multiple of 64
   and the last one or two are 64 or 128 bytes; every subtree offset is a sum of `left_subtree_len` values, each a
   power of two of at least one 1 KiB chunk, and every subtree is non-empty. They are bugs if they fire, not
   input-provokable refusals, and the release profile aborts on a panic, as before.
3. **Tested** at every setting: a parity failure at layer 1, a SHA-256 mismatch at layer 2, and a parity failure at
   layer 1 with mismatches at layers 2 and 3 (layer 1's parity refusal, though the later loads failed first), through
   `seal_chain` and through `stack-prove`, at loads 0 and 4 (§4).
4. **Nothing of the run exists earlier** [CODE]. Both forms create no file and print nothing. The tree's rayon tasks
   hold only public block words and are joined before `digest` returns; the SHA-256 holds its state and the last
   block on its own stack.
5. **No schedule reads a hidden value** [CODE]. The SHA-256's instructions are data-independent and its code branches
   on the length only; the tree's split depends on the input's length only, a function of the public shape.

## 9. For the privacy gate

- **Production digests that moved** (source pins of the D55 capture):
  - `private_block/run_sink.rs`: `digest_hex` and the new inline module `a21_sha` (the switch, the wrapper, the
    detection and `arm`: the compression function and the padding);
  - `private_block.rs`: `BlockPublic::digest`'s first lines (the switch), the new `a21_pieces` and `a21_digest_tree`,
    and the `[A21]` section after `impl BlockPublic` (`A21_LEAF`, `a21_b3par`, `A21Piece`, `A21Stream`);
  - `private_block/trained_statement.rs`: `sha` (through the wrapper) and the removed `sha2` import;
  - `private_block/trained_block.rs`: `sha256` (through the wrapper) and the removed `sha2` import.
- **Unchanged**: `protocol.rs`, `argument*.rs`, `witness*.rs`, `run.rs`, `run_fork.rs`, `run_fork_wire.rs`, `gpu/*`,
  zkp-core, `Cargo.toml` and `Cargo.lock`.
- **New `unsafe`, all in `run_sink::a21_sha`**, each site with a SAFETY comment: the call of the
  `#[target_feature(enable = "sha2")]` function after `is_aarch64_feature_detected!("sha2")`, and the NEON loads and
  stores (`vld1q_u8` over a `&[u8; 16]`, `vld1q_u32` over a `&[u32; 4]` of the state or the constants, `vst1q_u32`
  into a `&mut [u32]` of four). The block digest's tree has no `unsafe`.
- **Private data through the new code**: the SHA-256 wrapper also hashes the prover-private sequence files where a
  sequence manifest is given (`load_seq_dir`'s `load_array`, ruling K-2's refusal unchanged). Its time depends on the
  file's length only (data-independent instructions, length-only branches); the last block is copied to a stack
  buffer that is not zeroed, as `sha2`'s own block buffer is not. No hidden value reaches the block digest (it is of
  the public statement).
- **No byte of any receipt, statement, record or event moves** (§4). The CLI's events are unchanged.
- **Hashing and labels**: s25's census counts the new implementation and its call sites (§3.4); no absorb label,
  generator or new domain literal is added (the tree repeats D2's own two literals, for the same input). s25's census,
  `hash_domain`'s label scan and R6's audit pass.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## 10. What is left

- **The forks (3.57 s) are now more than half of production's 7.05 s request**; the sealing pass (2.60 s) is
  build-bound (1.82 s of builds), the rest the first load, the checks and the statement [MEASURED, s2c].
- **The receipt's frames written as their forks finish** (§3.3): at most about 0.2 s [ESTIMATE].
- **The verifier's frame digests in parallel**: `read_fork_receipt` hashes its 34 frames one after another, 352 ms on
  the instructions; in parallel 26 ms (§2.2) [MEASURED, profile]. A small change in `run_fork.rs`; not on the prover's
  path.
- **A resident model** (the records kept per manifest digest, the digest pass done once) still needs a ruling (A19,
  A20); with A21 the per-request record is 32 ms a layer.
- **Production's real load** (`load_layer_mode`) at 8B is not measured (no export on the Mac); its eleven array
  SHA-256s now run on the instructions too.
- **x86_64 (the RTX 5090 box)**: unchanged by design, `sha2`'s SHA-NI path. The block digest's tree applies there too.
- **Not measured:** a trained 8B export, any machine but this one, a stream form of production.

## 11. Merge-conflict risks against perf

- **`run_sink.rs`**: `digest_hex`'s body and the new `a21_sha` module after it.
- **`private_block.rs`**: `BlockPublic::digest`'s first lines; `a21_pieces` and `a21_digest_tree` after it; the `[A21]`
  section between `impl BlockPublic` and `IoSpec`.
- **`trained_statement.rs` / `trained_block.rs`**: the one-line SHA helpers and their removed `use sha2::…` lines. A
  lane adding a `Sha256` use in either file must import it again.
- **`s25_tests.rs`**: `CALL_SITES` (32 rows) and `ENTRY_POINTS` (22). A lane adding a hash call in a scanned file edits
  the same arrays.
- **`run_fork_tests.rs`**: the `[A21]` block is appended; `a19_production_d55_ab`'s `parse` returns an `A21Arm` too,
  and its PROD line gains `; A21: …` at its end (A20's, A19's and A11's parsers still read it).
- No other file was edited.

## 12. This directory

- **Stage scripts**: `s0.sh` (build, A21's suite tests, the touched suites, the no-feature check, the production
  build); `s1.sh` (A21's device tests, the profile, the verifier A/B); `s2.sh` (the production A/Bs); `s9.sh` (the
  acceptance); `run_stage.py` (A20's runner, A21's labels); `prod_pairs.py` (A20's pairs with the preflight and commit
  clocks and a pair count); `verify_pairs.py` (the verifier's pairs); `warn_diff.py` (a build's warnings against A20's
  stage-9 build, by message and file).
- **Records**: the progress files, guard records and `.done` markers; `s1_profile.log`, `s1_verify_ab.log`,
  `s1_verify_pairs.md`; `s2<a-e>_*` (`_prod_ab.log` trimmed, `_pairs.md`, `_seal.md`, `_prod_pairs.md`, `_table.md`);
  stage 9's.
- **Raw logs** stay in `raw/` (not committed), with copies of A20's stage-9 build logs, the warning baseline.
