# A14: the forks' remaining host work (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A14. Byte-preserving. It follows A11, A12 and A8
(`../a11/README.md`, `../a12/README.md`, `../a8/README.md`): the fork run is still host-bound, the GPU busy about
2.78 s of a 3.8 s forks phase.

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers; [ESTIMATE] a
judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run at N = 6 (A11's per-fork pools of 6), `HL_GPU=1 HL_PB_ORACLE=0
HL_METAL_TIMING=0`, on the shared M3 Ultra, every stage one guarded job (class gpu, the shared heavy lock).

## Plain summary

- **A fresh profile of the forks phase** (macOS `sample`, N = 6, the tree at `76e9b280`) [MEASURED, §1]: each fork's
  main line waits on the GPU 48% of the time; the rest, about 1.2 s per fork per call, is host work. The largest
  host items are in other lanes' files: the A/H zero-fill and free (14%, A13's `protocol.rs`), A8's store fold
  (12%), the lookups and histograms (10%) and the helper inverses (10%). In this lane's files: the randomness (8%),
  the private slots' tables (5%), the extension rounds' mask sums (about 2%) and the transcript absorb (3%).
- **What changed** (all byte-preserving, each with a switch back):
  - **the lazy sums** (`argument.rs`, the default): the private tables' accumulating entries and the extension
    rounds' mask sums are summed exactly in 128-bit integers and reduced once, instead of a field multiply and add
    per term. Alone it took **3.5%** off the proof-only fork run, in every pair, both orders.
  - **the randomness in NEON lanes** (`zkp-core/src/rng.rs`, the default): `fill_fp`'s blocks of blake3's XOF are
    computed eight output blocks at a time in NEON registers (2.7x faster alone). It takes about **4% of the user
    CPU** off, in every pair; the wall moves only within noise (−1.0%, −0.2%) at N = 6 on the Mac.
  - **the parallel transcript absorb** (`zkp-core/src/transcript.rs`, **opt-in**): BLAKE3's own tree of an
    opening's clear vector hashed on rayon. Same digest, but it did not pay (+1.0%, system CPU +15%), so it is off
    unless `HL_TRANSCRIPT_PAR=1`.
- **The A14 default against the tree before A14** [MEASURED, §4.2, 6 passes, both orders]:
  - **proof-only fork run −3.9%** (4.190 → 4.025 s, 30.6 → 31.8 tok/s), every pair;
  - **one request from its input −1.1%** (8.54 → 8.45 s, 15.0 → 15.2 tok/s), every pair;
  - **the 4-request stream: no change** (steady −0.7%, 24.7 / 24.5 tok/s, 2 of 6 pairs favour the default);
  - user CPU −7.4%.
- **No byte moves** (§3, §5): every new form's words equal the old form's in word-for-word tests (4,000 XOF blocks,
  330 absorbs, every table of the rung and of the 8B private slots, 33 dot products at the field's edges); the rung
  golden `96e4f0b6` holds on the CPU and on Metal under all six settings of the three forms; one 8B block's seeded
  core proof has one digest under all six; the six trained digests and the receipt sizes are unchanged.
- **What is left** (§6) is mostly in A13's `protocol.rs` (the zero-fill, the lookups, the per-block public checks)
  and in device work for `define`'s public weight folds.

## 1. The profile [MEASURED, stage 1]

**Method** (`s1.sh`): the tree at perf `76e9b280`. One process with the phase clock and the GPU timeline in every fork
(`phases`, 2 proof-only calls); then a second process with A11's sampler window: 3 proof-only fork calls between two
handshakes with `/usr/bin/sample` (2 ms), as A11 stage 6 did. The raw call graph (29 MB) is not committed.

**The window:** the forks phase 3.77–3.94 s outside the sampler, 3.93–4.36 s inside it (the sampler slows the
process about 10%). The GPU is busy 2.77–2.80 s of the forks phase (70–73%) [MEASURED, `s1_d55_phases.log`].

**The ranking** (`rank.py`, `s1_rank.md`; detail per bucket `rank_detail.py`, `s1_rank_detail.txt`). Each fork's
main line (any stack holding `prove_core`) is the critical path of its blocks: 48% of its samples wait on the GPU,
52% (1.24 s per fork per call, sampled) are host work or waits on its own parallel regions. Each non-GPU main-line
sample is put in the first bucket whose frames match; a rayon worker's busy sample is traced to the region that
spawned it (the inlined `bridge_producer_consumer::helper` monomorphizations are mapped back to their callers on
the main lines). Per fork per call, sampled:

| bucket | whose file | main line, % of non-GPU | main line, s | pool busy, CPU-s per call |
|---|---|---:|---:|---:|
| A/H zero-fill and free (`vec!`, `__bzero`, `vm_deallocate`) | `protocol.rs` (A13) | 14.2% | 0.176 | 0.05 |
| the openings' store fold (A8's) | `gpu/metal.rs` fold region | 11.7% | 0.144 | 4.34 |
| lookup values and histograms | `protocol.rs` (A13) | 10.2% | 0.126 | 3.17 |
| the public weight folds and public tables in `define` (`fold_cols_i8`, `fold_rows_i8`, pads, RoPE, SiLU) | `argument.rs` calls; `accuracy_fold.rs`, zkp-core `mle.rs`, `pad.rs` code | 9.7% | 0.120 | 1.87 |
| LogUp helper inverses | `protocol.rs` (A13) | 9.5% | 0.117 | 2.49 |
| **the randomness** (`fill_fp`, `next_u64`, blake3's XOF) | **`rng.rs` (A14)** | 7.8% | 0.097 | 2.41 |
| commit host parts (uploads, the mask commit's host NTT, Merkle) | `pcs.rs`, `zk.rs`, `metal.rs` | 6.2% | 0.076 | 1.61 |
| **the private slots' tables** (`priv_table_fill`) | **`argument.rs` (A14)** | 5.1% | 0.063 | 1.41 |
| the per-block public checks (`check_for_shape`, `check_for_registry`) | `prove_core`'s call (A13); `private_block.rs` code | 4.1% | 0.050 | 2.58 |
| the witness planes into `A` | `protocol.rs` (A13) | 4.0% | 0.050 | 1.47 |
| other | — | 4.0% | 0.049 | 0.31 |
| **the extension rounds** (`mask_eval_eq`; `open_zk`'s `group_zclaims` eq tables) | **`argument.rs` (A14)**; zkp-core `pcs.rs` | 3.9% | 0.048 | 0.36 |
| the claimed sums (`total_at`) | `argument.rs` | 2.9% | 0.035 | 0.89 |
| **the transcript absorb** (the openings' clear vectors) | **`transcript.rs` (A14)** | 2.8% | 0.035 | 0.00 |
| A12's host part of the device tables (public tables, plans) | `argument.rs`, `metal.rs` tables | 2.0% | 0.024 | 0.10 |
| openings, the rest | zkp-core `pcs.rs` | 1.4% | 0.018 | 0.00 |

**What it says.**
- The largest host items are in other lanes' files: the A/H zero-fill (A13's `protocol.rs`; two forms already lost),
  A8's store fold, the lookups and the helper inverses (`protocol.rs`).
- In this lane's files, by measured cost: the randomness (0.097 s per fork per call, and 2.4 CPU-seconds per call in
  the pools, almost all blake3's one-block-at-a-time XOF), the private slots' tables (0.063 s; 1.4 CPU-s), the
  extension rounds' mask sums (`mask_eval_eq`, about 0.028 s of the 0.048 s), the transcript absorb (0.035 s).
- The private slots' tables are 12 small slots of about 1 ms each (A12's census): 56 tables at 8B, the matmul planes
  folded by 7 fixed coordinates. Their claimed sums read them on the host. Moving them to the device would also need
  the claimed sum on the device; a faster host build is the better step (§2.1).

## 2. What changed

### 2.1 The lazy sums (`argument.rs`; the default, `HL_ARG_LAZY=0` restores the per-term form)

Two host dot products of the prover, both `sum_i e_i * x_i` with `e_i` in `Fp2` and `x_i` in `Fp`:
- **an accumulating private table** (`priv_table_fill`'s parallel M9 form, one plain slice): entry `x` is
  `sum_z eqf[z] * v(idx(x, z))`, 128 terms per entry for the matmul planes (7 fixed coordinates). The old form made
  `v` an `Fp2` and used the full `Fp2` multiply (five field multiplies) and an `Fp2` add per term.
- **a table's reserved mask pair at its claim tail** (`mask_eval_eq`, the extension rounds): two rows of up to
  2^14 terms per private table, a field multiply and add per term (`mul_base`).

The new form, `LazyDot`: each component's products `e.c * x` are summed as 128-bit integers, every wrap past 2^128
counted, and the integer `lo + wraps * 2^128` is reduced ONCE (`Fp::from_u128(lo) + wraps * (2^128 mod p)`, with
`2^128 = -2^32 mod p`). Two 64 x 64-bit multiplies and two 128-bit adds per term instead of up to five reductions.
Multi-slice planes (`H`'s re/im pairs) keep the old form. No branch depends on a value.

### 2.2 The randomness in NEON lanes (`zkp-core/src/rng.rs`; the default, `HL_RNG_XOF=blake3` restores blake3's XOF)

`fill_fp` (the mask rows of `A` and `H`, the pads) draws counter-mode blocks: block `c` is the first 8 KiB of the XOF
of `blake3(key || c)`. On aarch64 blake3 has no many-block XOF, so it makes the 128 output blocks of each 8 KiB one
64-byte compression at a time (the profile's `Platform::compress_xof` leaf).
- **The input is one 40-byte block**, so every output block `t` is the compression of the same root node (the IV,
  the block zero-padded, block length 40, flags CHUNK_START | CHUNK_END | ROOT) with counter `t`.
- **`lanes::block`** computes eight such blocks at once: BLAKE3's compression (7 rounds of G, the specification's
  message schedule) in two NEON register sets of four lanes, one counter per lane, then a 4 x 4 transpose per
  quarter. Wrapping adds, xors and fixed rotations only: no branch or address depends on the key or the counter.
- **Alone, one thread:** 2.5 us per 8 KiB block against blake3's 6.7 us, x2.7 (3.3 against 1.2 GB/s) [MEASURED, a
  scratch bench of the same code, not committed].
- **Where it is used:** `fill_fp`'s parallel chunks and its final state rebuild. `refill` (the one-draw path: the
  salts' `bytes32`, short fills) still calls `block_bytes`, whose text three source audits pin
  (`hash_domain_tests`, `s25_tests`); the file still has exactly one `finalize_xof(`.
- `XofForm`, `xof_form`, `set_xof_form` are new public items of zkp-core's `rng` module (free functions, not
  `ZkRng` members; `ZkRng`'s four fields are unchanged, as `s25_tests` pins).

### 2.3 The parallel absorb (`zkp-core/src/transcript.rs`; OPT-IN, `HL_TRANSCRIPT_PAR=1`)

An absorb of at least 64 KiB of data (the openings' clear vectors: 266,624 bytes each, 37 for `A` and 10 for `H` per
block) hashes BLAKE3's own tree of the same message on rayon (`par_absorb`, through `blake3::hazmat`: subtrees at
their input offsets split by `left_subtree_len`, leaves of 32 KiB, the chaining values merged as parent nodes, the
root under the transcript's mode, keyed or not). `absorb_fp2` then also writes a long vector's bytes in parallel.
`absorb`'s pinned five-`update` body is unchanged and is the path whenever this is off. No lockfile change (blake3's
`rayon` feature is not used). **It did not pay (§4), so it is off by default.**

### 2.4 Not changed

- **The private slots' tables were not moved to the device.** Each is about 1 ms (12 small slots at 8B), their
  claimed sums read them on the host, and the lazy sum takes most of their arithmetic off (§4).
- `protocol.rs`, `run_fork.rs` (A13's), `gpu/metal.rs`, `gpu/mod.rs`, `metal_kernels.metal` and zkp-core's `pcs.rs`
  are untouched.

### 2.5 Test-only

- The harness words (`run_fork_tests.rs`, the block marked `[A14]`): `xofb3` / `xof8`, `trser` / `trpar`, `lazy0` /
  `lazy1`, `a14old` (all three off), `a14new` (all three on), `a14def` (the default: `xof8+trser+lazy1`).
- `argument::set_lazy_for_test`, `argument::a14_dot_forms`.

## 3. Why no byte can move

- **The lazy sums** give the residue of the same integer as the per-term form: `sum (e.c * x)` over the integers
  equals `lo + wraps * 2^128` exactly (each product of canonical words is below 2^128, and every wrap of the 128-bit
  sum is counted in a 64-bit counter that cannot overflow at these lengths); `Fp::from_u128` is exact for every
  128-bit input (A11's test against `v % p`); field results are canonical words. In the old table form,
  `eqf.mul(Fp2::from_base(v))` is `(e0 v + 7 e1 * 0, e0 * 0 + e1 v) = (e0 v, e1 v)`, the same element.
- **The lane XOF** computes the bytes `block_bytes` computes (§2.2's derivation from BLAKE3's specification), and the
  test compares them: every byte of 4,000 blocks (random keys and counters, the counter edges 0, 1, 2^32 - 1, 2^32,
  2^64 - 1, all-zero and all-one keys, 512 B to 8 KiB), 13.8 MB.
- **The parallel absorb** hashes the same message in BLAKE3's own tree shape (blake3's `hazmat` contract); the test
  compares 330 digests over every length around the chunk, leaf, threshold and split boundaries, three label
  lengths, keyed and unkeyed.
- **The words, not only the reasoning, are tested** (stage 2, and again in the acceptance, §5):
  - zkp-core: `a14_the_lane_xof_equals_block_bytes_word_for_word`; `a14_fill_fp_in_either_xof_form_equals_the_draw_loop`
    (the draws AND the stream's state, `buf`, `pos`, `counter`, from every alignment, then later draws of every
    kind); `a14_the_parallel_absorb_equals_the_serial_digest` (and whole transcripts equal in pools of 1, 2, 6
    threads and the global pool);
  - hashline, CPU, in the suite: `a14_the_lazy_sums_equal_the_per_term_sums_word_for_word` (33 dot products over the
    whole field, all-`(p - 1)` vectors, lengths to 2^16 + 3; then every table of every slot of the W16R2 rung with
    the lazy sums off and on, at the production threshold and with every table forced onto its parallel form: 476
    tables, 7.46 M words, dense full-field data with a tenth of the words `p - 1`);
  - hashline, ignored: `a14_the_8b_private_slots_tables_equal_under_both_sums` (56 tables, 8.56 M words);
    `a14_w16r2_rung_golden_under_every_a14_setting` (the rung golden `96e4f0b6` on the CPU under `a14old`, `a14new`
    and `a14def`, and on Metal under all six settings); `a14_the_8b_block_proves_the_same_under_every_a14_setting`
    (one W16R2 8B T128 block's seeded core proof on Metal under every setting, each twice: one digest,
    `a32cb0dd0fc2ec46`).
- **Privacy (timing).** None of the three forms adds a path whose time depends on a hidden value: the lazy sums do
  the same operations for every value; the lane XOF is branch-free ARX with fixed addresses; the parallel absorb
  splits by the message length only, which is public. (A8's small-word fold remains the one known value-dependent
  path.)

## 4. The A/Bs, in-process, both arm orders [MEASURED]

N = 6. "Base first" and "test first" are the passes in which that arm ran first (the arm order reversed in every odd
pass, `HL_D55_AB_ALTERNATE=1`); the bias-solved column is their mean, which cancels the order bias (the second arm
of a pass runs about 4.5% faster, A7). (n pairs, n favouring the test.) From `../a11/pairs.py ... --alternate --n 6`.

### 4.1 Stage 3: each form alone on the tree before A14, proof only, 8 passes (`s3_pairs_singles_*.md`, `s3_singles_d55_ab.log`)

Five arms in one process: `a14old`, `a14old+xof8`, `a14old+trpar`, `a14old+lazy1`, `a14new` (all three on).

| against `a14old` | proof wall, bias solved out | base first | test first | forks phase | user CPU | system CPU |
|---|---|---|---|---|---|---|
| **`lazy1`** (the lazy sums) | **−3.5%** | −3.5% (4, 4) | −3.4% (4, 4) | −3.2% | −3.5% | −0.5% |
| `xof8` (the lane XOF) | −1.0% | −1.1% (4, 2) | −0.8% (4, 2) | −0.7% | −4.1% | +7.3% |
| `trpar` (the parallel absorb) | **+1.0%** | +2.6% (4, 1) | −0.6% (4, 3) | −0.7% | +1.1% | **+15.2%** |
| `a14new` (all three) | −1.4% | −0.0% (4, 2) | −2.7% (4, 4) | −2.4% | −6.1% | +16.9% |

Means (proof wall): `a14old` 4.160 s, `xof8` 4.115, `trpar` 4.194, `lazy1` 4.012, `a14new` 4.098 s.
- The lazy sums pay in every pair, in both orders.
- The parallel absorb does not: the wall is +1.0%, and system CPU rises 15% (the rayon wake-ups of 47 short
  parallel hashes per block) [INFERRED from the system CPU]. It is opt-in since.
- The lane XOF saves user CPU in every pair (−4%) but the wall only within noise.

**Stage 3, second part: all three on, against the tree before A14** (`s3_pairs.md`, `s3_d55_ab.log`; 6 passes, each a
proof-only call, a sealed request and a 4-request stream):

| metric | base first | test first | order bias solved out | means, before / all three |
|---|---|---|---|---|
| proof wall | +2.6% (3, 0) | −0.7% (3, 2) | +0.9% | 4.059 / 4.096 s |
| forks phase | +1.1% (3, 1) | −1.8% (3, 2) | −0.4% | 3.696 / 3.683 s |
| sealed wall | +0.5% (3, 1) | −0.8% (3, 2) | −0.1% | 8.414 / 8.399 s |
| stream, steady | +1.1% (3, 3) | +1.7% (3, 3) | +1.4% | 24.53 / 24.87 tok/s |
| user CPU | −5.0% | −6.4% | −5.7% | 42.3 / 39.9 s |
| system CPU | +14.5% | +9.7% | +12.1% | 6.85 / 7.67 s |

With the parallel absorb in, the proof-only gain of the lazy sums disappears; this run is what moved the absorb to
opt-in.

### 4.2 Stage 5: the default (`a14def` = `xof8+trser+lazy1`)

**The lane XOF on top of the lazy sums,** proof only, 8 passes (`s5_pairs_xof_given_lazy.md`, `s5_xof_d55_ab.log`):

| metric | base first | test first | order bias solved out | means, `lazy1` / `lazy1+xof8` |
|---|---|---|---|---|
| proof wall | +0.2% (4, 1) | −0.6% (4, 3) | −0.2% | 4.048 / 4.040 s |
| forks phase | +0.2% (4, 1) | −0.2% (4, 1) | +0.0% | 3.678 / 3.678 s |
| user CPU | −3.6% (4, 4) | −4.1% (4, 4) | **−3.9%** | 41.1 / 39.5 s |
| system CPU | +8.1% | +0.8% | +4.4% | 6.40 / 6.65 s |

**The tree before A14 against the A14 default** (`s5_pairs.md`, `s5_d55_ab.log`; 6 passes, each a proof-only call, a
sealed request and a 4-request stream; all 48 stream receipts verified after their clocks, each arm's first
proof-only and sealed receipt verified; fork receipts 818,728,672 B in every call):

| metric | base first | test first | order bias solved out | means, before A14 / A14 default |
|---|---|---|---|---|
| proof-only wall | −5.9% (3, 3) | −1.9% (3, 3) | **−3.9%** | 4.190 / 4.025 s = 30.55 / 31.80 tok/s |
| forks phase | −5.7% (3, 3) | −1.7% (3, 3) | **−3.7%** | 3.796 / 3.654 s |
| one request from its input (sealed) | −1.2% (3, 3) | −0.9% (3, 3) | **−1.1%** | 8.537 / 8.445 s = 14.99 / 15.16 tok/s |
| stream of 4, steady | −0.7% (3, 1) | −0.7% (3, 1) | −0.7% | 24.69 / 24.52 tok/s |
| stream of 4, amortized | −0.4% (3, 1) | +0.2% (3, 2) | −0.1% | 20.95 / 20.93 tok/s |
| user CPU (proof-only call) | −7.7% | −7.0% | **−7.4%** | 42.5 / 39.4 s |
| system CPU | −5.7% | −0.8% | −3.3% | 7.43 / 7.15 s |

- **Proof only and one request from its input favour the default in every pair, in both orders.**
- **The stream does not move** (−0.7%, 2 of 6 pairs favour the default; within its run-to-run spread). The stream
  is limited by the sealing pass and the forks sharing the machine, not by the forks' own host path [INFERRED: A8's
  stream gain was +2.2% for a −2.9% proof-only gain; here −3.9% proof only gives no stream gain].
- Bests: proof only 4.129 → 3.911 s (31.0 → 32.7 tok/s); sealed 8.469 → 8.353 s (15.1 → 15.3 tok/s).
- **Why the lane XOF stays in the default:** it is byte-identical, every mean favours it (−1.0%, −0.2%) and it takes
  4% of the user CPU off in every pair; the wall effect alone is within noise at N = 6 on the Mac.

## 5. Acceptance [MEASURED]

**Stage 4** (`s4.sh`, `s4.progress`, `s4_*.log`, `s4.guard.json`) is the final tree, the A14 default in force (the
lazy sums and the lane XOF on, the parallel absorb off). One guarded job (19:00–19:10 UTC):
- **build:** rc 0. **The no-feature `cargo check --tests`** (no `gpu-metal`): rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures; `s4_full.log`): **925 passed, 3 failed, 106
  ignored**. The three failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 925 is A8's 924 plus `a14_the_lazy_sums_equal_the_per_term_sums_word_for_word`; 106 ignored is A8's 103 plus the
    three ignored A14 tests.
- **zkp-core's lib tests:** 81 passed, 2 ignored (A8's 78 plus the three A14 tests).
- **The A14 byte tests:** the 8B private tables under both sums (56 tables, 8.56 M words, equal); the rung golden
  `96e4f0b6` on the CPU under `a14old`, `a14new`, `a14def` and on Metal under all six settings; the 8B block's core
  proof under all six settings, twice each, one digest (`a32cb0dd0fc2ec46`).
- **The A8 rung test** (every store fold form), **the A12 census and rung-mode tests, the A11 pool tests (CPU and
  Metal), the A7 queue test:** all pass, `96e4f0b6` throughout.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the default** (`s4_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4`):

| W16R2 8B T128, 32 blocks, N = 6 | this run (`s4_d55.log`) | the first acceptance attempt (`s4_first_attempt.progress`) | A8's merged tree, for reference |
|---|---:|---:|---:|
| proof only, the two calls | 4.288, 4.181 s | 4.102, 4.232 s | 3.932 s best |
| proof only, best | 30.61 tok/s | 31.21 | 32.55 |
| one request from its input (sealed), best | 8.676 s = 14.75 tok/s | 8.419 s = 15.20 | 8.255 s = 15.51 |
| stream of 4, steady / amortized | 24.21 / 20.62 tok/s | 24.71 / 21.09 | 24.17 / 20.93 |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, all 4 stream receipts after the clock). Fork receipts
  818,728,672 B and D12a receipts 818,728,480 B, unchanged (and in every call of every A/B).
- **These single-process figures are not the measurement of A14.** They vary by several percent from process to
  process with the box's state (A13's jobs ran between ours); both runs here are below A8's acceptance run while the
  in-process A/Bs of §4 favour the default in every proof-only and sealed pair. The A/Bs are the measurement.
- **The first acceptance attempt** (the same tree but for `XofForm`'s derive) failed one audit beside the known three:
  `s25_tests::the_generator_is_never_cloned_and_each_prover_constructs_exactly_one` forbids the text `derive(Clone`
  anywhere in `rng.rs` (so that `ZkRng` can never quietly gain it), and `XofForm` derived it. `XofForm` now has
  `Clone` and `Copy` by hand; the audit passes. Everything else in that attempt passed as above.

## 6. What is left

**In this lane's files:**
- **The salts.** `commit_zk_owned_with_tag` (zkp-core `pcs.rs`, not this lane's) draws 2^15 salts with `bytes32`, one
  sequential `next_u64` at a time through `refill` (about 1 MB of XOF per commitment, three commitments per block,
  on the fork's main line: about 0.01 s per fork per call, sampled). A bulk draw (a `ZkRng::fill_bytes32` in
  `rng.rs` on the lanes, called from `pcs.rs`) would take most of it off. It needs a `pcs.rs` change, and `refill`'s
  pinned text means the lanes cannot serve the one-draw path.
- **The claimed sums** (`total_at`, 0.035 s per fork per call, 0.9 CPU-s per call) evaluate a slot's closure per
  entry; not changed.
- **The device slots' public tables** are still written by the host (A12's remainder, 0.024 s).
- **The lane XOF's CPU saving does not show in the wall at N = 6 on the Mac** (§4). It should matter where the host
  limits harder, the RTX 5090 box [ESTIMATE].

**In other lanes' files (from the ranking, largest first):**
- **The A/H zero-fill and free** (`protocol.rs`, A13): 14% of the main line's host time. A reuse pool (A11) and
  `calloc` (A8) lost. Untried: the first touch inside the parallel `write_planes` / `write_helpers` (the pages
  faulted in by the threads that write them, zeros only where nothing writes).
- **The lookups and histograms, the helper inverses, the witness planes** (`protocol.rs`, A13): 24% together.
- **The per-block public checks** in `prove_core` (`blk.check_for_shape`: `check_accuracy_for_shape`,
  `weights_vanish_off_support`, `check_for_registry`): 0.050 s per fork per call and 2.6 CPU-seconds per call,
  repeated for every block although preflight (A2) already checks every block's public data. Caching a checked
  block per resident model (A2's H122 idea, applied to the forks) needs `protocol.rs` (A13).
- **`define`'s public weight folds** (`accuracy_fold::fold` calling zkp-core's `fold_cols_i8` / `fold_rows_i8`): 0.12
  s per fork per call, 1.9 CPU-s per call. The weights are public: a device fold over resident int8 weights is the
  next device candidate (a new kernel; `accuracy_fold.rs`, `mle.rs`).
- **A8's store fold** (`gpu/metal.rs` fold region): 12% of the main line.
- **The parallel absorb, tuned:** coarser leaves or a fixed fan-out of four might keep its saving without the
  wake-ups; at about 1% of the main line it is not worth much.

## 7. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/argument.rs` (production): `[A14]` `LazyDot`, `lazy_on`
  (`HL_ARG_LAZY`), `TWO_128_MOD_P`, the lazy form in `priv_table_fill`'s parallel accumulating path and in
  `mask_eval_eq`; test-only `set_lazy_for_test`, `a14_dot_forms`.
- `ops/zkp-mvp/gpu-metal/zkp-core/src/rng.rs` (production): `[A14]` `XofForm`, `xof_form` (`HL_RNG_XOF`),
  `set_xof_form`, `block_bytes_in`, `mod lanes` (aarch64); `fill_fp` takes its blocks through `block_bytes_in`;
  the two tests.
- `ops/zkp-mvp/gpu-metal/zkp-core/src/transcript.rs` (production): `[A14]` `ABSORB_PAR_MIN`, `par_absorb`,
  `absorb_par_on` (`HL_TRANSCRIPT_PAR`, off by default), `set_absorb_parallel`, the guarded branches in `absorb` and
  `absorb_fp2`; the test.
- Tests: `range16_tests.rs` (the block at the end: `a14_data`, `a14_copy_tab`, `a14_tables_equal_under_both_sums`,
  the CPU test and the ignored 8B test), `w16r2_tests.rs` (the block at the end: `A14_SETTINGS`, `a14_set`, the rung
  golden and the 8B block under every setting), `run_fork_tests.rs` (the `[A14]` block: `A14Arm`, `a14_word`,
  `a14_apply`; and three hook lines, in `GpuArm`, `gpu_arm` and the A/B loop).
- This directory: `s1.sh` (the profile), `s2.sh` (the byte evidence), `s3.sh` and `s5.sh` (the A/Bs), `s4.sh` (the
  acceptance), their progress files, guard records and trimmed logs; `rank.py` and `rank_detail.py` (the ranking,
  on A11's `sample_summary.py` parser), `s1_rank.md`, `s1_rank_detail.txt`, `s1_sample_N6.summary.txt` (A11's
  summary of the same window); the pairs tables `s3_pairs*.md`, `s5_pairs*.md` (from `../a11/pairs.py`);
  `run_stage.py`, `watch.py` (A11's). The raw call graph and the full D55 and suite logs stay in `raw/`, not
  committed.

**For the privacy gate.** Production digests that moved: hashline `private_block/argument.rs`, zkp-core `rng.rs` and
`transcript.rs` (both listed in the run capture's `SHARED_SOURCE_FILES`). `protocol.rs`, `run_fork.rs`,
`private_block.rs`, `gpu/metal.rs`, `gpu/mod.rs`, `metal_kernels.metal`, `metal_slot.rs`, zkp-core `pcs.rs`,
`pcs/backend.rs` and `field.rs` did **not** change. The new code reads the same words as before and returns the
same words; it keeps nothing past its call, prints nothing and adds no dependency. The generator's key and blocks
now also pass through NEON registers (the lane XOF). `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
