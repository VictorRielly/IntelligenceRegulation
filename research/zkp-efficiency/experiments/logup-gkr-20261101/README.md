# LogUp-GKR against the committed W16 helpers: a measurement (2026-11-01)

This experiment is the top assignment of `handoffs/20261030-deepprove-gap.md`, adapted to W16. It was run by Claude
as the standing researcher (D50).

**Verdict: NOT KILLED, but marginal.**
- The kill rule needs both of its clauses. The bytes clause holds; the time-ratio clause fails under the full
  accounting.
- On today's Metal path, the range-lookup-only variant is worth **×1.00–1.15 per block** (ESTIMATE).
- If every LogUp lookup joins the tree and `H` retires, it is worth **×1.07–1.25** (ESTIMATE).
- **No measured proving improvement.** Nothing native was built or changed.

## What was built

`src/main.rs` is a standalone Rust crate. It uses zkp-core's Goldilocks/Fp2 field, transcript, RNG and Ligero
PCS as a read-only path dependency; zkp-core is not edited. The crate holds:
- **A streamed LogUp-GKR fractional-sumcheck prover and verifier**, CPU only, on rayon.
  - **Tree.** One tree of 2^n leaves.
    - Queries: `(1, c_w − v)`, with `c_w = α − γ·w` and `v < 2^w`.
    - Widths: the W16 families 16, 15, 13, 12, 8, 7, 5, 4, 2, about 70% of them width 16.
    - Table: every `(w, t)` entry with multiplicity `m`, 111,028 entries in all.
    - Pads repeat an entry with `m = 0`.
    - Two cancelling blinding leaves.
  - **Streamed.** The leaves stay as u32 values, standing in for the `A` planes.
    - Layer n−1 is never stored; it is recomputed from the leaves.
    - Layers 1..n−2 are stored bottom-up (16 B/leaf) and freed top-down.
    - The leaf layer keeps `p ≡ 1` implicit and uses the base-field leaves directly in its first two rounds.
  - **Kernels.** Each round is fused with the previous round's fold, and the eq tables are split.
- **The helper baseline on the same leaves.** This is what native W16 does (`write_helpers_w16`):
  - per-width inverse tables;
  - one helper word per lookup, written by gather into separate re/im rows;
  - the older batch-inversion form of the same helpers;
  - zkp-core's `commit_zk_owned` of the helper words (`log_cols` 14, rate 1/4, Q = 256), as in the native `H`.
- **Tests:** 112 checks, all passing (`logs/test3.log`).
  - The optimized prover's proofs equal those of an independent textbook full-tree prover, which evaluates each
    round polynomial at X = 0..3 and interpolates. Checked at n = 4..14 under three kernel configurations.
  - Fast paths and generic paths give identical proofs at n = 4..18 (W16 widths at n = 18).
  - Every honest proof verifies.
  - The direct fractional sum `Σ p/q` is 0, and `q_root = Π q`.
  - The negative controls below are run at tiny, medium and W16 sizes.

| Control | Refused by |
|---|---|
| C1 one out-of-table leaf (`2^16 + 7` in a width-16 slot, multiplicities unchanged) | root numerator ≠ 0; the direct sum is also ≠ 0 |
| C2 the same, with a forged root | layer-1 final check |
| C3 a multiplicity off by one | root numerator |
| C4 a tampered round coefficient | the round's sum check |
| C5 tampered finals | the layer's final check |
| C6 a zero blinding denominator | root check; the direct sum's checked inversion |
| C7 a valid proof for *other* leaves | the leaf claim |
| C8 a cancelled matched pair (query `p := 0`, `m −= 1`; the identity still holds) | the leaf claim |
| C9 a `(0,0)` leaf (passes a numerator-only check) | root-denominator check |

**Not in the prototype:**
- no masks and no zero knowledge (see `ZK_DESIGN_NOTE.md`);
- no commitment. The transcript absorbs only public parameters. The verifier's leaf check is an O(N) oracle that
  stands in for the claim on the committed planes;
- no GPU.

## Measured

Shared M3 Ultra; MEASURED, diagnostic timing. Each run held the heavy lock, so Astra's chain was paused between its
jobs. Medians over n = 5 reps at 32 threads (n = 3 elsewhere). Full data: `results.json`.

| Leaves | GKR prove, 32 thr | ns/leaf | GKR, 16 thr | GKR, 1 thr | Helper gather + write | Batch-inverse + write | Helper commit, 32 thr | Commit, 1 thr |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2^20 | 0.0234 s | 22.3 | | | 0.0010 s | 0.0018 s | 0.0421 s | |
| 2^22 | 0.0472 s | 11.2 | 0.0347 s | 0.231 s (55.1 ns) | 0.0014 s | 0.0044 s | 0.0542 s | 0.456 s (109 ns) |
| 2^24 | 0.1044 s | 6.2 | 0.0944 s | 0.908 s (54.1 ns) | 0.0025 s | 0.0142 s | 0.1006 s | 1.657 s (99 ns) |
| **2^25** (one W16 block) | **0.160 s** | **4.77** | 0.166 s | | 0.0031 s | 0.0263 s | **0.180 s** | (16 thr: 0.264 s) |

**At 2^25:**
- **Build and top-down.** The bottom-up build takes 0.020 s and the top-down pass 0.137 s.
  - Layer 24 (the leaf layer, fast paths): 0.034 s.
  - Layer 23 (virtual, generic Fp2): 0.041 s. It is the largest single cost, at half the leaf layer's size.
  - Layers ≤ 18: about 0.011 s together.
- **Verifier.** Its 300 rounds take 0.1 ms. The O(N) leaf oracle takes 0.013 s.
- **Proof:** 20,800 B (300 rounds and 25 finals; unmasked).
- **Peak heap:** 16.1 B/leaf above the leaf values (4 B/leaf u32). A resident tree would need 48 B/leaf.
- **Parallel threshold.** Sweeping it (2^10, 2^12, 2^13, 2^15 pairs) moves the 2^25 prove only between 0.159 and
  0.170 s.
- **Scaling.** GKR is the cheaper of the two per thread: 54 ns/leaf against 99 ns/word for the commit alone. But it
  scales only ×8.7 from 1 to 32 threads, against ×16.5 for the commit.

**Counted per leaf:**
- 10.4 Fp2-multiplication equivalents (an Fp2 product counts 5 base products in zkp-core): 1.7 in the build and
  8.7 top-down.
- 116 B read and 64 B written, on the big arrays.
- 66 of the 300 rounds have ≥ 2^13 pairs, which is the "GPU-scale" round count.

## Kill rule (`projection.py` → `projection.json`)

Per lookup, with 32.28 M lookups per block:

| | ns/lookup | Label |
|---|---:|---|
| GKR prove (2^25 leaves) | 4.96 | MEASURED |
| + leaf-claim linear terms in the domain zero-checks (one table-equivalent per domain) | 1.4–2.8 | ESTIMATE |
| **GKR path** | **6.4–7.8** | |
| Helper gather + write | 0.09 | MEASURED |
| Helper commit | 5.37 | MEASURED |
| + `open H`, helper word share | 0.52 | ESTIMATE, native CPU row |
| + domain zero-checks, helper table share | 6.9–13.7 | ESTIMATE, native CPU rows ÷ tables per domain; low end rescaled to the 1.54 s CPU block; `TAB` excluded |
| **Helper path** | **12.9–19.7** | |

- **Ratio, full accounting:** GKR/helper is **0.32–0.60**, below 0.7, so the clause fails.
- **Ratio, measured parts only** (GKR against gather + commit): 0.91, which is ≥ 0.7.
- **Bytes**, counted the same way for both: **GKR 187 B/lookup against helper ~132 B/lookup**, so the bytes clause
  holds. The helper count is 12 for the write, 72 for the commit (8 read, 32 encoded write, 32 hash read), 40 for
  the zero-check table build and rounds, and 8 for the opening.
- **Multiplications:** GKR 10.8 Fp2-eq/lookup, against about 8.6 for the commit's NTTs alone, plus BLAKE3 and the
  helper zero-check terms.
- **Verdict.** Both clauses are needed to kill, so it is **not killed**. But the CPU advantage rests entirely on the
  attributed zero-check share. Bare GKR is only 9% cheaper than the commit, and it touches more bytes.

## Metal per-block projection (ESTIMATE)

Basis:
- the warm instrumented W16 pass (0.578 s);
- Goldilocks multiplication at 88–97 G/s (`results/zk60_metal_20261031/kbench`);
- 800 GB/s nominal bandwidth;
- the measured per-device-round floor of about 0.30–0.35 ms. The three-table 2^19 slots 00, 01 and 21 take 6–7 ms
  over 19 rounds.

**Helper path today: 0.110 s per block.**

| Part | Seconds |
|---|---:|
| Helper writes | 0.009 |
| `H` commit, helper share | 0.034 |
| `open H`, helper share | 0.016 |
| Zero-check helper tables (D 10/37, Q 3/15, Kv 3/15, S 4/19, F 4/19) | 0.043 |
| `TAB` | 0.008 |

**GKR on Metal: 0.040–0.105 s.**
- Compute: 1.74 G base products at 30–60% of the kbench rate, so 0.033–0.066 s.
- Bandwidth: 6.0 GB at 50%, so 0.015 s. That overlaps the compute.
- Rounds: 66 GPU-scale rounds at 0.30–0.35 ms each, so 0.020–0.023 s on today's driver, or 0.002 s at 30 µs/round.
- The small rounds on the CPU: 0.005–0.016 s.
- Plus the leaf-claim terms: 0.009 s.

**Net saving:**
- **Range lookups only:** −0.004 to +0.061 s per block, so **×1.00–1.15** on 0.47 s.
- **Every lookup, with `H` retired:** +0.030 to +0.095 s, so **×1.07–1.25**. The extra comes from:
  - the rest of the `H` commit and `open H` (0.016 s);
  - the exp/act inverses (0.020 s);
  - their zero-check share (0.005 s);
  - the `ZS` slot (0.002 s);
  - minus a 2^22 second tree.
- **`M`.** Its extra rows (+0.009 to +0.026 s) count only if they stay on the critical path. `M` does not depend
  on the witness.
- **RTX 5090 (low confidence).** GKR is compute- and latency-bound, while the commit is bandwidth- and hash-bound.
  With CUDA graphs (3–4 µs per launch, [zkDuel](https://arxiv.org/html/2610.37710)), the relative gain could grow
  to about ×1.1–1.2. Not measured.

## Next, if pursued

1. Make the bottom of the tree **fan-in 4**: fold layer 23 into the leaf-layer sumcheck. That layer is 26% of GKR
   time, and the change removes 12 GPU rounds.
2. Use **univariate skip / small-value** first rounds.
3. Use a **forked transcript**, so the GKR's latency-bound rounds overlap the bandwidth-bound zero-checks. This
   needs a versioned schedule; the slot-batching census found all current pairs transcript-ordered.
4. Write a minimal Metal kernel for the leaf and virtual layers, and measure it under the owner's locks.

The ZK obligations are in `ZK_DESIGN_NOTE.md`.

## Commands (all guarded, offline, no Git)

```
cargo build --release --offline --locked -j 8 --manifest-path <this dir>/Cargo.toml --target-dir <scratchpad>/target-logup-gkr   # class build
<binary> test                                                     # class cpu: logs/test3.log (112 pass)
<binary> bench --log-n 20,22,24,25 --reps 5                       # class cpu, 32 threads: logs/bench_t32.log
<binary> bench --log-n 22,24 --reps 3 --threads {1,8,16}          # logs/bench_t{1,8,16}.log
<binary> bench --log-n 25 --reps 5 --threads 16                   # logs/bench_t16_n25.log
<binary> bench --log-n 24,25 --reps 5 --no-helper --log-par-min {10,12,15}  # logs/bench_pm*.log
python3 summarize.py ; python3 projection.py                      # results.json, projection.json
```

The guard result JSONs (`logs/*.guard.json`) record waits, peak RSS (at most 2.98 GB) and exit codes; every run
exited 0.

## Pins (sha256)

| Item | sha256 |
|---|---|
| `src/main.rs` | `6f0332f3…5059` |
| `Cargo.lock` | `78539fc4…91b3` (seeded from zkp-core's lock) |
| Binary | `c884a84e…a730ca` |
| zkp-core `field.rs` | `df3eb5a6…7f13` |
| zkp-core `transcript.rs` | `cc9752d0…1967` |
| zkp-core `pcs.rs` | `856929b3…6224` |
| zkp-core `ntt.rs` | `97572d4f…0890` |
| zkp-core `rng.rs` | `f6728bd2…aa2` |
| Quoted native log `results/zk60_limb16_20261031/logs/g_phases2.log` | `018fdf4e…41c6` |

Toolchain: Homebrew cargo/rustc 1.96.0.

## Full-stack status

- New independently verified full-stack proofs, passes and proved positions: **0 / 0 / 0**.
- The complete private 8B at ≥ 50 proved tokens/s on an RTX 5090 remains **unachieved**.
