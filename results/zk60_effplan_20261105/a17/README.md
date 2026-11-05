# A17: the forks' host work, after A15 (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A17. Byte-preserving. It follows A14 (`../a14/README.md`,
§1 the ranking and §6 "What is left") on the tree after A15 (`../a15/README.md`, the sealing pass in its own pool).

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run at N = 6 (A11's per-fork pools of 6), `HL_GPU=1 HL_PB_ORACLE=0
HL_METAL_TIMING=0`, on the shared M3 Ultra, every stage one guarded job (class gpu, the shared heavy lock). The base is
perf `910c2ac4` (A15 merged). The timing fixture's public weights are synthetic and diagonal at the 8B geometry; neither
form below depends on the weights' values (§2).

## Plain summary

- **The result** [MEASURED, §4.3, 6 passes, both arm orders, order bias removed; the A17 default against the code
  before A17]:
  - **proof only −2.7%**, 4.101 → 3.990 s (31.2 → 32.1 tok/s; best 3.944 s = 32.5 tok/s), 6 of 6 pairs; the forks
    phase −3.2%;
  - **one request from its input −2.0%**, 7.488 → 7.338 s (17.1 → 17.4 tok/s; best 17.8), 5 of 6 pairs; its prove
    call −4.0% (6 of 6); its sealing pass unchanged (+0.4%, noise);
  - **the 4-request stream +2.4% steady** (28.6 → 29.3 tok/s, 5 of 6) and **+2.3% amortized** (24.1 → 24.6 tok/s,
    6 of 6);
  - user CPU −3.7%, system CPU −33%, minor page faults −40% (1.13 M → 0.67 M per call).
- **What changed** (`protocol.rs`, `run_fork.rs`; each form behind a switch that restores the code before it):
  - **the looked columns read from their planes** (`HL_A17_LOOKED`, on): at a W16 profile every lookup but one is
    a single term `cst + c * plane[x]`, yet each was first copied into its own column (`lookup_values`; about 220
    MB of fresh pages per block [INFERRED from the 436,000 faults per call the views removed, at 16 KiB a page])
    before the histograms and the LogUp helpers read it. They now read the witness plane directly;
    only the one two-term column (`word24`'s low limb) is still built. Alone: proof only −1.1%, forks phase −1.7%,
    system CPU −25%, faults −38% (§4.1).
  - **the preflight's record of a block's public checks** (`HL_A17_CHECKED`, on): the fork run's preflight already
    runs rulings CS-1 / CS-4 on every block; each fork re-ran them on its block (about 220 MB of int8 weights scanned
    per block: 0.032 s per fork per call on the main line and about 0.6 CPU-s per call in the pools, sampled). A fork
    now skips its re-check only when the preflight's record is for THAT block object at THAT shape; anything else
    checks, so a different or modified block is refused as before (§3.2). Its own wall effect is within noise (proof
    only −0.6% and −1.8% in two A/Bs, one request +0.8%, the stream +1.9%; §4.1, §4.4); it is kept on because it only
    removes work, takes 0.4–1.4% of the user CPU off and the measured default includes it.
- **Measured and dropped: each fork worker keeping its `A` and `H` from block to block** (`HL_A17_REUSE` in the
  work-in-progress commit): every word rewritten, faults −20%, but proof only **+3.6%** and the forks phase +4.4%,
  in 0 of 8 pairs (§4.1). It is the third form of the A/H zero-fill to lose (A11's pool +2.8%, A8's `calloc` +5.6%);
  the code is removed and kept as a record in this lane's work-in-progress commit `53a758c7` (§2.3).
- **No byte moves** (§3): the W16R2 rung golden `96e4f0b6` under every setting on the CPU and on Metal; the R13
  rung's digest under both settings; one W16R2 8B T128 block's seeded core proof `90003b76…` under every setting
  (the same digest as the post-F12 trained-digest gate); every D55 receipt of every A/B call verified at
  818,728,672 B (D12a 818,728,480 B). A modified block beside an honest block's record, and a block source that
  hands a fork another block than its preflight checked, are both refused by CS-1 / CS-4's own words.
- **What is left** (§6): the A/H zero-fill and free stay (three forms lost), the openings' store fold (A8's), the
  public weight folds in `define`, the helper inverses, the randomness, and `define`'s per-slot registry re-check
  (`argument_accuracy.rs`, not this lane's).

## 1. The profile, before (stage 1) [MEASURED]

**Method** (`s1.sh`): A14's. The tree at perf `910c2ac4`. One process with the phase clock and the GPU timeline in
every fork (`phases`, 2 proof-only calls; `s1_d55_phases.log`); then a second process with A11's sampler window: 3
proof-only fork calls between two handshakes with `/usr/bin/sample` (2 ms; `s1_d55_sample.log`). The ranking is A14's
`rank.py` and `rank_detail.py` (on A11's `sample_summary.py` parser), plus this lane's `leaf_detail.py`, which splits a
bucket by its leaf frame (system frames included). The raw call graph (30 MB) is not committed.

**The window:** the forks phase 3.63–3.99 s outside the sampler, 4.03–4.23 s inside it; the GPU busy 2.73–2.78 s of
the forks phase (70–75%). Each fork's main line waits on the GPU 49.9% of its samples; the rest, 1.27 s per fork per
call (sampled), is host work or waits on its own parallel regions.

**The ranking** (`s1_rank.md`; per bucket `s1_rank_detail.txt`, `s1_leaf_detail.txt`), per fork per call, sampled,
beside A14's (`../a14/s1_rank.md`, the tree before A14 and A15):

| bucket | whose file | main line, % of non-GPU | main line, s | pool busy, CPU-s per call | A14's main line, s |
|---|---|---:|---:|---:|---:|
| A/H zero-fill and free (`vec!`, `__bzero`, `vm_deallocate`) | `protocol.rs` | 14.5% | 0.184 | 0.08 | 0.176 |
| the openings' store fold (A8's) | `gpu/metal.rs` | 12.8% | 0.162 | 4.99 | 0.144 |
| lookup values and histograms | `protocol.rs` | 10.9% | 0.138 | 3.35 | 0.126 |
| public weight folds and public tables (`define`) | `argument.rs` calls; `accuracy_fold.rs`, `mle.rs`, `pad.rs` | 9.9% | 0.126 | 2.04 | 0.120 |
| LogUp helper inverses | `protocol.rs` | 9.6% | 0.122 | 2.64 | 0.117 |
| the randomness (`fill_fp`, `next_u64`, the XOF) | zkp-core `rng.rs` | 8.5% | 0.107 | 2.59 | 0.097 |
| commit host parts (uploads, host NTT, Merkle, salts) | `pcs.rs`, `metal.rs` | 6.2% | 0.079 | 1.83 | 0.076 |
| other | — | 4.2% | 0.053 | 0.35 | 0.049 |
| per-block public checks (`check_for_shape`, `check_for_registry`) | `prove_core`'s call; `private_block.rs` code | 4.0% | 0.051 | 2.69 | 0.050 |
| the witness planes into `A` (`write_planes`) | `protocol.rs` | 4.0% | 0.051 | 1.50 | 0.050 |
| the extension rounds | `argument.rs`, `mle.rs` | 3.1% | 0.039 | 0.17 | 0.048 |
| the transcript absorb | `transcript.rs` | 3.0% | 0.038 | 0.00 | 0.035 |
| the private slots' tables | `argument.rs` | 2.7% | 0.034 | 0.69 | 0.063 |
| the claimed sums | `argument.rs` | 2.6% | 0.033 | 0.91 | 0.035 |

**What the buckets in this lane's files hold** (`s1_leaf_detail.txt`, `s1_rank_detail.txt`):
- **The zero-fill and free** (0.184 s): `SpecFromElem::from_elem` in `prove_core` 0.093 s (the `vec![Fp::ZERO; ..]` of
  `A` and `H`, 328 + 341 MB per block: the fill and its first-touch faults), `mach_vm_deallocate` in `prove_core`
  0.034 s (the frees of `A`, `H`, the looked columns and the witness), `__bzero` in `prove_core` 0.032 s; the rest
  small and elsewhere.
- **The lookups** (0.138 s): the looked columns' construction, `lookup_values_at`, 0.069 s on the main line with its
  waits and 1.6 CPU-s per call in the pool; the W16 histograms 0.055 s and 1.4 CPU-s.
- **The per-block checks** (0.051 s): `prove_core`'s own CS-1 / CS-4 check (`check_accuracy_for_shape`: the parallel
  `i8::MIN` scan and `weights_vanish_off_support` over the block's weights, plus one registry recomputation) about
  two thirds; the other third is `define`'s registry re-check, which `argument_accuracy.rs`'s `define_changed` runs
  for every slot of every block. The bucket's 2.7 CPU-s in the pools are mostly the preflight's own scans of the 32
  blocks on the global pool (2.1 CPU-s remain there after A17, §6) [INFERRED]; the forks' re-checks were about 0.6.
- **The phase clock** (`s1_d55_phases.log`, ms per block summed over the forks, two calls): `A` allocate + planes
  32–33, the lookup values + histograms 30–32, the `H` LogUp helpers 30–34 (with `H`'s allocation), the S2 drops
  10.5–11.5, `A`'s commit 48–61, `H`'s 47–50; all phases 638–668.

## 2. What changed

### 2.1 The looked columns read from their planes (`protocol.rs`; the default, `HL_A17_LOOKED=0` restores)

[CODE] A W16 profile's lookups (`accuracy_layout.rs`, `lookups_w16`; `range16.rs`): `word16` is `plane + bias`,
`rem_lookups` and `direct` are `plane`, the softmax byte lookups `±plane + 127`: one term each. Only `word24`'s low
limb (`word - 2^16 top + bias mod 2^16`, the `Dom::F` domain at an h24 stack) has two. `lookup_values_at` built every
one of them into its own `Vec<i64>` over the domain's padded extent, then `w16_histograms` binned them and
`write_helpers_w16` read them again for the LogUp helpers.

**The form** (the block marked `[A17]`):
- `LookedCol`: `Term { plane, c, cst }` (a one-term lookup, the plane sliced to the domain's padded extent) or
  `Words(&[i64])` (a built column). Word `x` of a `Term` is `cst.wrapping_add(c.wrapping_mul(plane[x]))`, which is
  `lookup_values_at`'s fold over its one term.
- `looked_built` builds only the columns that are not one term (in parallel over the column's words, an indexed
  map); `looked_cols` borrows the rest.
- `w16_histograms_cols` and `write_helpers_w16_cols` are `w16_histograms` and `write_helpers_w16` over the views: the
  same chunks (2^16 words; `HELPER_CHUNK` words), the same checks and carving, the same refusal; each chunk reads its
  words a sub-block of 1,024 at a time into an L1-resident buffer.
- In `prove_core` and in `check_lookup_misses` (the CS-3 miss check that the trained stack's production sealing
  pass, `trained_block::seal_and_record`, runs on every sealed witness), at a W16 profile. Every other profile, and
  `HL_A17_LOOKED=0`, takes the code before A17 unchanged (`lookup_values`, `w16_histograms`, `write_helpers_w16` are
  untouched and still used). The D55 harness seals with `build_accuracy`, which does not run the miss check, so the
  harness's sealing pass does not see this; production's sealing pass does a little less work [CODE; not measured].
- The cheating prover's misfiled-range hook (test builds) builds the columns from the views and calls the old hook.

### 2.2 The preflight's record of a block's public checks (`protocol.rs`, `run_fork.rs`; the default, `HL_A17_CHECKED=0` restores)

- `CheckedPublic { blk: &BlockPublic, sh: Shape }`: its one constructor, `CheckedPublic::check`, runs
  `blk.check_for_shape(sh)` and returns a record only if it passed. `covers(blk, sh)` is true only for the same
  block object (`std::ptr::eq`) at an equal shape.
- `run_fork.rs`'s `preflight` makes one record per block (in its existing parallel loop, the same refusals in the
  same order) and returns them; `prove_forks_inner` hands block `k`'s to fork `k` (`ForkCtx::checked`). The
  verifier's preflight discards them.
- `protocol::prove_core_with(.., CoreHints { checked })`: `prove_core` with the record. It skips its own CS-1 / CS-4
  re-check only when `HL_A17_CHECKED` is on and the record covers this block at this shape. `prove_core` (every
  other caller: D12a, the single block, the tests) is `prove_core_with` with no record, and checks as before.
- `define`'s per-slot `check_for_registry` (`argument_accuracy.rs`) and the verifier's checks are unchanged.

### 2.3 Measured and dropped: each fork worker's kept `A` and `H` (`HL_A17_REUSE`)

In the work-in-progress commit `53a758c7` (the code is there as a record; removed in `886e316b`): each D55
fork worker kept its `A` and `H` host matrices from one block to the next it proved (`HostMats`), and every word was
rewritten: `A` by `write_planes_over` (the planes and zero everywhere else below the mask rows, one parallel
region) and `fill_fp`, `H` by the W16 helper region's own zeros between the helper columns (or a parallel zero
below the mask rows) and the writers after it. Byte-identical (the rung golden and the 8B block under all eight
settings with new, kept and `p − 1`-filled matrices, `s2_a17rung.log`, `s2_a17_8b.log`), but it lost (§4.1), so it
was removed, with `write_planes_over`, `zero_par` and the helper region's zeros.

Why it lost is not established [ESTIMATE]: the faults fell 20% and the frees left the main line, yet user CPU rose
2.8% and system CPU 7.3%. The kept matrices are cold in the caches when they are rewritten, while a fresh page is
written right after the kernel zeroes it; and on top of the views the reuse form still cost about 0.6% (§4.1,
`a17new` against `looked1`).

### 2.4 Not changed

- The salts' bulk draw (A14's item, about 0.01 s per fork per call): not done; it needs zkp-core's `pcs.rs`, which
  Sol's W16R3 build will rework.
- `define`'s per-slot registry re-check (about a third of the per-block bucket): in `argument_accuracy.rs`, not
  this lane's file.
- `witness_accuracy.rs`, `witness.rs`, `trained_block.rs`, `private_block.rs` (lane A16's and the check bodies),
  zkp-core, `gpu/*`, `argument.rs`: untouched.

### 2.5 Test-only

- `run_fork_tests.rs`, the block marked `[A17]`: the arm words `looked0` / `looked1`, `checked0` / `checked1`,
  `a17old` / `a17new` (joinable with every other word), `A17Turncoat` and the test of §3.2; hooks in `GpuArm`,
  `gpu_arm` and the A/B loop.
- `w16r2_tests.rs`, the block marked `[A17]`: the four settings, `a17_seeded_digest`, `a17_two`, the two suite tests
  and the two ignored tests of §3.
- `protocol.rs`: `set_a17_for_test`, `LookedCol::to_vec`, `misfile_range_misses_cols` (`#[cfg(test)]`).

## 3. Why no byte can move, and the byte evidence

### 3.1 The looked columns

- **The words.** A one-term column's word `x` is `cst.wrapping_add(c.wrapping_mul(plane[x]))` in both forms (the old
  fold over one term starts at `cst` and adds `c * plane[x]`, wrapping). The built columns are built by the same
  fold. So every histogram bin (an integer count), every miss count and every helper word
  (`helper_one_any(v, ..)` of the same `v`) is the old one; the helper words land in the same places (the same
  carving), and a refusal is the same string under the same condition (some word's denominator zero).
- **The order of everything else is untouched**: no randomness is drawn and nothing is absorbed in these steps; the
  draws and absorbs before and after them are the same calls.
- **Timing (privacy).** The same operations run for every value: which columns are borrowed is decided by the
  layout's lookups (public), and the sub-block reads are fixed-length copies.

### 3.2 The record

- **A skipped check is one that passed on this very object.** The record holds `&BlockPublic`: while it lives the
  block cannot be changed, moved or freed (Rust's borrow rules; `BlockPublic` has no interior mutability), and
  `covers` asks for the same address and an equal `Shape`. A different block, a copy, another shape, no record or the
  switch off runs the check. A record exists only for a block that passed (its one constructor runs the check), and
  the preflight runs before anything is absorbed, as before.
- **A source that changes its answer is caught**: the fork asks `blocks.get(k)` again, and if that is another
  object than the preflight's, its record does not cover it and the fork checks it.
- **A skipped check moves no byte**: the check reads public words and returns `Ok` or a refusal; it draws, absorbs
  and writes nothing.

### 3.3 The evidence [MEASURED]

- **The W16R2 rung, every setting, CPU and Metal** (`w16r2_tests::a17_w16r2_rung_golden_under_every_a17_setting`;
  stage 2 on the work-in-progress tree with all eight settings of three forms and new, kept and `p − 1`-filled
  matrices, `s2_a17rung.log`; the acceptance on the final tree, `s4_a17rung.log`): every digest `96e4f0b6`, through
  `prove_core` and through `prove_core_with` beside the block's record.
- **The rungs in the suite** (`a17_the_rung_digests_under_a17_forms`, CPU): the W16R2 rung (`96e4f0b6`) and the R13
  rung (`ddd29ae0`, a profile that is not W16), both forms off and on, through both entries: one digest each.
- **One W16R2 8B T128 block** (`a17_the_8b_block_proves_the_same_under_every_a17_setting`, Metal, `HL_PB_ORACLE=0`;
  `s2_a17_8b.log`, `s4_a17_8b.log`): the seeded core proof's digest `90003b760eb7ad80` through `prove_core` with
  both forms off, then under every setting (twice each in the acceptance) through both entries: equal in all.
- **A modified block is refused beside an honest block's record**
  (`a17_a_record_covers_only_its_own_block_and_a_modified_block_is_refused`, CPU): a record covers its block, not a
  copy and not another shape; the block without its accuracy data and the block with one weight at `i8::MIN` are
  refused with CS-1 / CS-4's own words ("R13 profile is missing its public accuracy data"; "R13 public
  weights/gains must be symmetric int8"), with the record form on and off; no record can be made for either.
- **Through the fork run** (`run_fork_tests::a17_a_fork_refuses_a_block_its_preflight_did_not_check`, the R13 rung,
  `L = 3`, two workers): the honest run with the records proves and verifies; a block source that hands each fork
  another block than its preflight checked is refused at the fork ("D55: fork 0: R13 profile is missing its public
  accuracy data"), with the record form on and off.
- **The D55 fork-run suite tests** (25, the tamper families and the controls) pass with the work-in-progress
  forms all on (`s2_fork_suite.log`), and on the final tree in the full suite of the acceptance (§5).

## 4. The A/Bs, in-process, both arm orders [MEASURED]

N = 6. "Base first" and "test first" are the passes in which that arm ran first (the whole arm order reversed in
every odd pass, `HL_D55_AB_ALTERNATE=1`); the bias-solved column is their mean, which cancels the order bias (the
second arm of a pass runs about 4.5% faster, A7). (n pairs, n favouring the test.) From `../a11/pairs.py ... --alternate
--n 6`, `../a13/seal_pairs.py`, `../a15/seal_pairs.py`. Every fork receipt 818,728,672 B; every stream receipt
verified after its clock; each arm's first proof-only and sealed receipt verified.

### 4.1 Stage 3: each form alone, proof only, 8 passes, five arms in one process (`s3_pairs_singles_*.md`, `s3_singles_d55_ab.log`)

The work-in-progress tree (three forms). Arms `a17old`, `a17old+looked1`, `a17old+checked1`, `a17old+reuse1`,
`a17new` (all three on).

| against `a17old` | proof wall, bias solved out | base first | test first | forks phase | user CPU | system CPU | minor faults |
|---|---|---|---|---|---|---|---|
| **`looked1`** (the views) | **−1.1%** | +0.2% (4, 2) | −2.4% (4, 3) | **−1.7%** | +0.2% | **−25.5%** | **−37.9%** |
| `checked1` (the record) | −0.6% | −1.4% (4, 3) | +0.3% (4, 2) | +0.2% | −1.4% | +0.9% | +1.4% |
| `reuse1` (the kept matrices) | **+3.6%** | +4.2% (4, 0) | +3.1% (4, 1) | **+4.4%** | +2.8% | +7.3% | −20.2% |
| all three | −0.5% | −0.1% (4, 3) | −1.0% (4, 3) | +0.1% | −0.7% | −22.3% | −58.1% |

Means (proof wall): `a17old` 4.120 s, `looked1` 4.067, `checked1` 4.091, `reuse1` 4.264, all three 4.094 s.

### 4.2 Stage 3: all three against the code before A17 (`s3_pairs_whole.md`, `s3_seal*_whole.md`, `s3_whole_d55_ab.log`)

6 passes, each a proof-only call, one request from its input and a 4-request stream; the kept matrices still in:

| metric | order bias solved out | means, before / all three |
|---|---|---|
| proof wall | +0.2% | 4.085 / 4.092 s |
| one request from its input | +0.4% | 7.481 / 7.511 s |
| its prove call | −0.5% | 4.093 / 4.070 s |
| stream steady / amortized | −1.9% / −1.2% | 28.53 / 27.98; 24.03 / 23.73 tok/s |
| user / system CPU, faults | −1.4% / −26.0% / −59.0% | |

With the kept matrices in, the views' gain is gone; this run and §4.1 are why the kept matrices were removed.

### 4.3 Stage 5: the A17 default against the code before A17 (`s5_pairs_default.md`, `s5_seal*_default.md`, `s5_default_d55_ab.log`)

`a17old` against `a17new` (the views and the record; the final tree), 6 passes:

| metric | base first | test first | order bias solved out | means, before A17 / A17 |
|---|---|---|---|---|
| **proof only** | −3.5% (3, 3) | −1.9% (3, 3) | **−2.7%** | 4.101 / 3.990 s = 31.21 / 32.08 tok/s |
| forks phase | −4.3% (3, 3) | −2.0% (3, 3) | **−3.2%** | 3.730 / 3.611 s |
| **one request from its input** | −2.4% (3, 3) | −1.7% (3, 2) | **−2.0%** | 7.488 / 7.338 s = 17.09 / 17.44 tok/s |
| its prove call | −4.1% (3, 3) | −3.9% (3, 3) | **−4.0%** | 4.123 / 3.959 s |
| its forks phase | −4.2% (3, 3) | −4.2% (3, 3) | −4.2% | 3.743 / 3.586 s |
| its sealing pass | −0.2% (3, 2) | +1.1% (3, 2) | +0.4% | 3.365 / 3.380 s |
| **the stream, steady** | +2.3% (3, 3) | +2.4% (3, 2) | **+2.4%** | 28.64 / 29.31 tok/s |
| **the stream, amortized** | +1.9% (3, 3) | +2.7% (3, 3) | **+2.3%** | 24.08 / 24.64 tok/s |
| the stream's sealing passes beside the forks | −1.8% (3, 3) | −2.5% (3, 3) | −2.1% | 4.623 / 4.523 s |
| user CPU (proof-only call) | −4.7% (3, 3) | −2.7% (3, 3) | **−3.7%** | 41.3 / 39.8 s |
| system CPU | −30.8% (3, 3) | −35.8% (3, 3) | **−33.3%** | 7.78 / 5.18 s |
| minor faults | −40.4% (3, 3) | −40.6% (3, 3) | −40.5% | 1.13 M / 0.67 M |

- **Proof only, the prove call and the amortized stream favour A17 in every pair, in both orders**; one request and
  the steady stream in 5 of 6.
- Bests: proof only 4.068 → 3.944 s (31.5 → 32.5 tok/s); one request 7.432 → 7.198 s (17.2 → 17.8 tok/s); the
  stream steady 29.15 → 29.70 tok/s.
- The sealing pass does not move (the harness seals with `build_accuracy`, which runs neither form); the stream gains
  from the proof side and from the CPU the forks no longer take beside the next request's sealing pass (its sealing
  passes beside the forks −2.1%) [INFERRED].

### 4.4 Stage 5: the record on top of the views (`s5_pairs_checked.md`, `s5_seal*_checked.md`, `s5_checked_d55_ab.log`)

`looked1` against `looked1+checked1`, 6 passes:

| metric | base first | test first | order bias solved out | means |
|---|---|---|---|---|
| proof only | −1.1% (3, 1) | −2.5% (3, 2) | −1.8% | 4.011 / 3.936 s |
| one request from its input | +0.2% (3, 1) | +1.5% (3, 1) | +0.8% | 7.283 / 7.342 s |
| the stream, steady | +2.6% (3, 2) | +1.2% (3, 3) | +1.9% | 29.06 / 29.61 tok/s |
| the stream, amortized | +1.0% (3, 2) | +0.8% (3, 2) | +0.9% | 24.57 / 24.79 tok/s |
| user CPU | +0.3% | −1.0% | −0.4% | 39.9 / 39.8 s |

The record's own effect is within the run-to-run spread on every clock (and so in §4.1). It is on by default because
it only removes work (the public scans the preflight already made), it is fail-closed (§3.2), and the default of §4.3,
which includes it, is measured. `HL_A17_CHECKED=0` turns it off with no other change.

## 5. Acceptance [MEASURED]

**Stage 4** (`s4.sh`, `s4.progress`, `s4_*.log`, `s4.guard.json`) is the final tree (perf `910c2ac4` + A17, both forms
on by default), A15's `s4.sh` pointed at this worktree plus A17's tests. One guarded job (22:44–22:52 UTC), on the
same build as stage 5's A/Bs:
- **build:** rc 0. **The no-feature `cargo check --tests`** (no `gpu-metal`): rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures; `s4_full.log`): **929 passed, 3 failed, 109
  ignored**. The three failures are exactly the known ones, at the same panic sites as A15's acceptance
  (`review_tests.rs:738:5`, `trained_accuracy.rs:515:96`, `trained_stack_tests.rs:553:44`):
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 929 is A15's 926 plus A17's three suite tests (`a17_the_rung_digests_under_a17_forms`,
    `a17_a_record_covers_only_its_own_block_and_a_modified_block_is_refused`,
    `a17_a_fork_refuses_a_block_its_preflight_did_not_check`); 109 ignored is A15's 107 plus A17's two. The D55
    fork-run suite tests (honest runs at every worker count, the tamper families, the controls) run with both
    forms on, and the source audits (s24, s25, `hash_domain`, C-H4') pass.
- **zkp-core's lib tests:** 81 passed, 2 ignored.
- **A17's byte tests:** the W16R2 rung golden `96e4f0b6` under all four settings, CPU and Metal, through both entries
  (`s4_a17rung.log`); the 8B block's core proof `90003b760eb7ad80` under every setting twice, through both entries
  (`s4_a17_8b.log`).
- **A15's 8B chain in every pool** (CPU and device products), **A14's** 8B private tables under both sums, rung golden
  under every A14 setting and 8B block under every A14 setting (`a32cb0dd0fc2ec46`), **A8's** rung test, **A12's**
  census and rung-mode tests, **A11's** pool tests (CPU and Metal), **A7's** queue test: all pass.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the default** (`s4_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1
  HL_D55_PIPE=4`):

| W16R2 8B T128, 32 blocks, N = 6 | this run (`s4_d55.log`) | A15's acceptance (`../a15/s4_d55.log`), for reference |
|---|---:|---:|
| proof only, the two calls | 4.082, 3.784 s | 4.061, 4.044 s |
| proof only, best | **33.83 tok/s** | 31.65 |
| one request from its input, the two calls | 7.174, 7.077 s (sealing passes 3.140, 3.236 s) | 7.213, 7.205 s |
| one request from its input, best | **7.077 s = 18.09 tok/s** | 7.205 s = 17.76 |
| stream of 4, steady / amortized | 28.65 / 24.57 tok/s | 28.60 / 24.49 |
| the stream's sealing passes | 3.19 s alone; 4.59, 4.51, 4.57 s beside the forks | 3.28; 4.42, 4.47, 4.79 |
| serial D12a, best | 9.300 s = 13.76 tok/s | 9.574 s = 13.37 |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, all 4 stream receipts after the clock). Fork receipts
  818,728,672 B and D12a receipts 818,728,480 B, unchanged (and in every call of every A/B of stages 3 and 5).
- The A15 column is another process on another state of the box; the in-process A/Bs of §4 are the measurement.

## 6. What is left

**The profile after** (stage 6, `s6.sh`: the final tree, the same method as §1; `s6_rank.md`, `s6_rank_detail.txt`,
`s6_leaf_detail.txt`, `s6_d55_phases.log`) [MEASURED]:
- each fork's main line now waits on the GPU 53.3% of its samples (49.9% before); its host time is **1.141 s per fork
  per call** (1.268 before, −10%, sampled); the GPU is busy 75–77% of the forks phase (70–75% before);
- the lookups' bucket **0.138 → 0.073 s** per fork per call (the histograms are what is left), the per-block checks'
  **0.051 → 0.019 s** (all of it `define`'s per-slot registry re-check; the CS-1 / CS-4 scans now run once per block,
  in the preflight, on the global pool);
- the phase clock (ms per block, two calls): the lookups 30–32 → 15–16; the S2 drops 10.5–11.5 → 4.3–4.9; `A`'s
  allocate + planes 32–33 → 26–27 (that phase's clock starts with `prove_core_with`'s own check); all phases 638–668
  → 615–649.

The ranking after, per fork per call, main line: **A/H zero-fill and free 0.163 s (14.3%)**, the openings' store fold
0.163 s (14.3%), the LogUp helper inverses 0.127 s (11.1%), the public weight folds in `define` 0.126 s (11.0%), the
randomness 0.108 s (9.5%), commit host parts 0.080 s (7.0%), the lookups (now the histograms) 0.073 s (6.4%), the
witness planes into `A` 0.051 s (4.4%).

**In this lane's files:**
- **The A/H zero-fill and free** (14.3%, now the largest with the store fold). Three forms have lost: A11's pool
  (+2.8%), A8's `calloc` (+5.6%) and this lane's per-worker kept matrices (+3.6%, §2.3). What is left untried: an
  `A` allocated directly as the device's shared buffer (no host matrix, no upload copy: `gpu/metal.rs` and zkp-core
  `pcs.rs`, not this lane's), and handing the frees to another thread (the S2 drops are now 4–5 ms per block, so
  small).
- **The LogUp helper inverses** (11.1%): the exp and activation helpers' batch inversions (`inverses`, one element
  per `Dom::S` and `Dom::F` position) and the range families' table helpers, whose 2^16-entry inverse tables are built
  twice (once by `range16::denominator_inverses` for the helpers, once by `inverses` of the same denominators for the
  table helpers; reusing the first would take a few ms per block [ESTIMATE]; `range16.rs` is not this lane's, the
  call site is).
- **The W16 histograms** (the lookups' 0.073 s): integer bins over about 220 MB per block; a per-family split or
  fewer accumulators might take part of it [ESTIMATE].
- **The salts** (A14's item, about 0.01 s per fork per call): needs zkp-core `pcs.rs`; left for after Sol's W16R3
  rework.

**In other lanes' files:**
- **`define`'s per-slot registry re-check** (`argument_accuracy.rs`, `define_changed` runs `check_for_registry` for
  every one of the 23 slots of every block: 0.019 s per fork per call). The same record (§2.2) could stand in for it:
  `check_accuracy_for_shape` already runs `check_for_registry` with the same arguments.
- **The openings' store fold** (`gpu/metal.rs`, A8's): 14.3%.
- **The public weight folds in `define`** (`accuracy_fold.rs`, zkp-core `mle.rs`): 11.0%; their cost is the dense scan
  of the public int8 weights, not the diagonal fixture's values, so a device fold would carry over to trained
  weights [ESTIMATE].
- **The randomness** (zkp-core `rng.rs`): 9.5%; A14's lane XOF is opt-in.

**Not measured:** a trained 8B export (no trained 8B export is on the Mac; the synthetic diagonal block is the
model, as in A3–A15), and any machine but this one (the RTX 5090 box's CPU limits differently).

## 7. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/protocol.rs` (production): the block marked `[A17]` after
  `write_h` (`a17_switch`, `HL_A17_LOOKED`, `HL_A17_CHECKED`, `LookedCol`, `looked_built`, `looked_cols`,
  `w16_histograms_cols`, `TaggedCol`, `HelperJobCols`, `tagged_col`, `write_helpers_w16_cols`, `CheckedPublic`,
  `CoreHints`); `prove_core` is now `prove_core_with` with no hints, and `prove_core_with` takes the views and the
  record; `check_lookup_misses` takes the views. Test-only: `set_a17_for_test`, `LookedCol::to_vec`,
  `misfile_range_misses_cols`.
- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_fork.rs` (production): `preflight` returns each block's
  record; `ForkCtx::checked`; `prove_one` calls `prove_core_with` with its block's record.
- Tests: `run_fork_tests.rs` (the `[A17]` block: `A17Arm`, `a17_word`, `a17_apply`, `A17Turncoat`,
  `a17_a_fork_refuses_a_block_its_preflight_did_not_check`; hooks in `GpuArm`, `gpu_arm` and the A/B loop);
  `w16r2_tests.rs` (the `[A17]` block at the end: `A17_SETTINGS`, `a17_seeded_digest`, `a17_two`,
  `a17_the_rung_digests_under_a17_forms`, `a17_a_record_covers_only_its_own_block_and_a_modified_block_is_refused`,
  the ignored `a17_w16r2_rung_golden_under_every_a17_setting` and
  `a17_the_8b_block_proves_the_same_under_every_a17_setting`).
- No new module, no new generator, no new absorb label and no new byte-string literal on the block path (the s24 /
  s25 / `hash_domain` / C-H4' source audits are unchanged and pass in the suite).
- This directory: `s1.sh` (the profile before), `s2.sh` (the byte evidence on the work-in-progress tree), `s3.sh`
  (the singles and the three forms together), `s5.sh` (the A/Bs of the final forms), `s4.sh` (the acceptance),
  `s6.sh` (the profile after); their progress files, guard records and trimmed logs; `leaf_detail.py` (on A14's
  `rank.py`), `run_stage.py`, `watch.py`, `wait_line.py`; the tables `s1_rank.md`, `s1_rank_detail.txt`,
  `s1_leaf_detail.txt`, `s3_pairs_*.md`, `s3_seal*_whole.md`, `s5_pairs_*.md`, `s5_seal*_*.md`, and `s6_*` likewise.
  The raw sample call graphs (30 MB each) stay in `raw/`, not committed.

**For the privacy gate.**
- **Production digests that moved: `private_block/protocol.rs` (a `SHARED_SOURCE_FILES` pin of the run capture)
  and `private_block/run_fork.rs` (a source pin of the D55 capture).** `argument.rs`, `witness.rs`,
  `witness_accuracy.rs`, `trained_block.rs`, `private_block.rs`, `run.rs`, `gpu/*`, `metal_kernels.metal` and
  zkp-core are unchanged by A17.
- The views read the same witness words the old columns copied, in the same order of operations, and keep nothing
  past their call; the record holds a reference to a public block and a copy of a public shape and prints only the
  shape's name (`Debug`). Nothing new is printed, and no dependency is added.
- **Timing:** no path whose running time depends on a hidden value is added: which columns are borrowed follows the
  layout's public lookups; whether a fork re-checks follows the block's address and the shape (public). (A8's
  small-word fold remains the one known value-dependent path.)
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
