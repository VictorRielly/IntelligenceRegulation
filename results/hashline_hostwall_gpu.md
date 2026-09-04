# The host wall of the 8B GPU pass — lane AJ, round 14 (lever L2)

Status: LIVE. WSL box (Core Ultra 9 185H, 8 threads used, 15 GB) +
RTX 4070 Laptop GPU (8.19 GB, sm_89), `flock /tmp/zk-heavy.lock`,
NOISY-SHARED by convention (lanes AI and AK were on the box; the GPU
was exclusive under the lock). Every number below is [MEASURED] unless
labelled otherwise. The unit of measurement is **one real Mistral-7B
feed-forward layer at T = 512 on the GPU**, which lane AH established
as the 8B pass in miniature:

    HL_GPU=1 hashline pass 1 512 --profile v3 \
      --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
      --threads 8 --proof-out F

**The gate on every row: `PROOF sha256
179ec2fb8f99d0d622dc2f868167c67c0ba2822c676b826fa1b01bdb3882a79b`
(38,688,700 B)** — AH's, AC's and the CPU prover's digest. Every arm in
every table below produced it.

## 1. What the 95.5 s 8B pass is actually made of

The plan (`U_PERF3_SIXTY_TOKENS_PLAN.md` §3, Track B) lists four host
items worth 56-63 s of the 95.5 s pass. Measuring them first changed two
of the four descriptions:

| item | the plan's description | what the counters say |
|---|---|---|
| B1 plane -> Fp + pageable upload | ~13-20 s | the UPLOAD is 13.05 s of device counter; the CONVERSION is host work in `prove_layer_v3` (layer.rs), read-only for this lane |
| B2 the encode NTT | "on the device" | it is ALREADY on the device; `secs_ntt` even absorbs the chunked hash when `HL_GPU_VERBOSE` is off. A kernel-quality item |
| B3 the opening's chunked re-encode | "on the device" | ALREADY on the device (`secs_reenc`). An algorithm/occupancy item |
| B4 Merkle + serializing 1.23 GB | ~13 s | the serialization runs OUTSIDE the prove clock (bin/hashline.rs: `to_bytes` + sha256 + `fs::write` follow the per-layer `t_prove`); measured at one layer it is 0.05 s, so ~1.6 s of the 225 s WALL, not 13 s of the prove |

The rung-0 baseline, one layer, all switches at their pre-lane values
[MEASURED, 2026-09-03]: **PROVE 3.134 s**, RSS 2.47 GB, VRAM 5,651 MB.

| phase | s | device counters inside it |
|---|---:|---|
| commit W | 1.402 | h2d(W) ~0.379, chunked encode+hash 0.331 |
| commit A | 0.461 | h2d(A) ~0.124, chunked 0.105 |
| helpers + commit H | 0.267 | device helpers 0.103, chunked 0.087 |
| matmul g/u + d | 0.255 | host folds over `w_data` (layer.rs) |
| zero-check F + D | 0.169 | device (lane AH) |
| pcs openings | 0.573 | chunked re-encode 0.442, device fold 0.084 |

Device counters summed: h2d 0.504 (1,871 MB) + ntt 0.450 + hash 0.073 +
sumcheck 0.169 + fold 0.091 + helpers 0.103 + re-encode 0.442 = **1.832
s**. The other **1.302 s (41.6%) is host time inside the prove**, and
**1.17 s of that 1.30 is in layer.rs** — the `Fp::from_i64` conversion
and 1.4 GB allocation of `w_data` (~0.69 s), the same for `a_data`
(~0.23 s), and the host matmul folds (0.255 s). layer.rs is READ-ONLY
for this lane, so the ceiling on what this lane can move is
h2d + ntt + re-encode = **1.47 s of the 3.13 (47%)**.

## 2. Rung 1 — pinned, double-buffered, interleaved uploads

What landed in `hashline/src/gpu/cuda.rs`:

- `PinBuf` — a page-locked host buffer (`cuMemHostAlloc`, write-combined:
  the host only ever writes it, the DMA engine only ever reads it).
- `Uploader` — two staging buffers, a non-blocking copy stream
  (`fork_default_stream`), one event per buffer. `send` fills a buffer and
  hands it to the DMA without waiting; `wait` is the only synchronization.
- `Gpu::upload_sync` — the drop-in for `htod_sync_copy_into` at the block
  upload sites (`dev_commit`'s resident class, `dev_encode_only`, the ZK
  commit), declining to the built pageable call on any error.
- `Gpu::commit_chunked_upload` — the chunked commit with the upload
  INTERLEAVED: chunk k+1's bytes ride the copy stream while chunk k
  encodes and hashes on the default stream.

Switches for the A/B: `HL_GPU_PIN_MB=0`, `HL_GPU_STREAM_COMMIT=0`.

**The probe that shaped everything after it** (`HL_GPU_BENCH_H2D=1
hashline gpu-probe`, 1.07 GB x 3) [MEASURED]:

| form | s | GB/s |
|---|---:|---:|
| pageable `htod_sync_copy_into` (the built path) | 0.1932 | **5.56** |
| host fill of a pinned write-combined buffer (8 threads) | 0.0369 | 29.13 |
| pinned, staged serially (fill then DMA) | 0.2076 | 5.17 |
| pinned, double-buffered on a copy stream | 0.1975 | **5.44** |

**Page-locked staging does not raise the host-to-device rate on this
box.** WSL2's paravirtualized GPU path already stages every copy through
the driver, so the wire is capped near 5.5-6.3 GB/s whatever the source.
That leaves exactly two levers on the 13.05 s of h2d in the 8B pass:
overlap it with compute (this rung) and put fewer bytes on it (rung 3).

## 3. Rung 2 — the column gather fused into the last NTT stage group

`k_ntt_p2_gather` (kernels.cu) is `k_ntt_p2` with one difference: instead
of writing the whole encoded row back to global memory it stores only the
sampled columns, straight into the opening's output. The separate
`k_gather_cols_off` read then disappears too. At the Mistral W shape that
is 1.07 GB of the 2.82 GB a 1024-row chunk moves [COUNTED]. Duplicate
column indices — `challenge_indices` draws 256 of 65,536, so about half
of all openings contain one — get a single device slot each and are
expanded on the host, which is what the old gather kernel did implicitly.
Switch: `HL_GPU_FUSE_GATHER=0`.

## 4. The A/B, one Mistral-7B layer at T = 512 [MEASURED]

Every arm produced `179ec2fb..`, 38,688,700 B.

| arm | PROVE s | re-encode s | commit W s |
|---|---:|---:|---:|
| rung-0 baseline (separate session) | 3.134 | 0.442 | 1.402 (phase) |
| base: rungs 1-2 off | 2.97 | 0.444 | ~0.72 (upload+encode) |
| fused gather only | 3.00 | 0.442 | ~0.72 |
| interleaved upload only | **2.76** | 0.449 | 0.569 |
| both | 2.79 / 2.86 | 0.442 / 0.444 | 0.636 / 0.545 |
| chunk 256 rows | 2.87 | 0.457 | 0.640 |
| chunk 128 rows | 2.81 | 0.461 | 0.567 |
| 512 NTT threads | 2.85 | 0.432 | 0.723 |
| 1024 NTT threads | 2.83 | 0.536 | 0.588 |
| **chunk 128 rows + 512 NTT threads** | **2.46** | 0.440 | **0.385** |

Three verdicts:

1. **The interleaved upload is worth ~0.2 s of 3.0 (7%)** — real but far
   from the 13 s the plan attributed to B1, because the plan counted the
   host-side conversion (layer.rs) in the same item.
2. **The fused gather is parity** (0.442 vs 0.444 s). The opening's
   re-encode is therefore NOT bandwidth-bound at this shape — which rules
   out the whole "move fewer bytes" family for B3 and points at occupancy
   and launch structure instead. The kernel is kept on (strictly less
   traffic, strictly less output memory, switchable) but it is not a
   speedup and is not counted as one.
3. **The two free parameters nobody had swept are worth more than either
   rung**: a 128-row chunk (encoded scratch 537 MB -> 67 MB) together with
   512 threads per NTT block (32 KB of shared memory per block, so 3
   blocks x 512 threads = 1,536 = the sm_89 limit, against 50% occupancy
   at 256) give **3.134 -> 2.46 s, 1.27x**. Neither alone moves anything:
   the chunk size only pays once the kernels have the occupancy to use the
   smaller working set, and the occupancy only pays once the working set
   is small enough to stay near cache.

## 5. Rung 3 — the narrow (int8/int16/int32) upload

`Fp::from_i64` maps x >= 0 to x and x < 0 to P + x, so a witness plane's
field elements are exactly the two ends of the field: every value of an
int8 plane is < 2^7 or >= P - 2^7. The upload therefore does not need 64
bits per element. `Uploader::send_packed` packs w bytes per element
(w = 1, 2 or 4, chosen by a strided sample and then VERIFIED on every
element during packing) straight into the page-locked staging buffer, and
`k_widen` restores the identical 64-bit image on the device. At the
Mistral shape the sample picks **1 byte for W (1,409 -> 176 MB) and 2
bytes for A (461 -> 115 MB)**. If any element does not fit, the pack
fails and the destination is untouched, so the caller falls back to the
64-bit upload with nothing to undo. Switch: `HL_GPU_NARROW=0`.

## 6. The rung-3 sweep — ten arms, all byte-identical [MEASURED]

| arm | PROVE s | commit W: h2d visible / total s | B/elem on the wire |
|---|---:|---|---:|
| r0base (everything off, chunk 1024, 256 threads) | 3.03 | — | 8 |
| chunk 128 + 512 threads, narrow OFF | 2.51 | 0.299 / 0.388 | 8 |
| **chunk 128 + 512 threads (defaults)** | **2.50** | 0.265 / 0.399 | **1 (W), 2 (A)** |
| the same, repeated | 2.66 | 0.300 / 0.585 | 1 |
| chunk 256 + 512 threads | 2.73 | 0.275 / 0.650 | 1 |
| chunk 512 + 512 threads | 2.60 | 0.257 / 0.520 | 1 |
| chunk 128 + 256 threads | 2.68 | 0.286 / 0.565 | 1 |
| chunk 128 + 1024 threads | 2.85 | 0.282 / 0.613 | 1 |
| chunk 128 + 512 threads, fused gather OFF | 2.67 | 0.286 / 0.593 | 1 |
| chunk 128 + 512 threads, 32 MB staging | 2.82 | 0.377 / 0.638 | 1 |

The two repeats of the same configuration (2.50 and 2.66, and a `commit
W` total of 0.399 against 0.585) fix the noise floor of this box at
about **+/-6% on the prove and much worse on a single phase** — lanes AI
and AK were running on the CPU throughout. Differences below ~0.15 s are
not real. What survives that:

- **chunk 128 + 512 threads is the winning configuration** and is now the
  default (`HL_GPU_CHUNK_ROWS`, `HL_GPU_NTT_THREADS`). 3.03 -> 2.50 s.
- **The narrow upload is PARITY on this box** (2.50 vs 2.51). Once the
  chunk is small enough for the interleaving to hide the DMA behind the
  encode, moving 8x fewer bytes only trades bus time for host packing
  time. It is kept on because the structure is right where the device is
  faster than the bus — which is exactly the RTX 5090 case — and because
  it costs nothing here; it is switchable and byte-gated either way.
- 1024 threads per NTT block is worse than 512 (1 block per SM instead of
  3), and a 32 MB staging buffer is worse than 64 MB.

## 7. What this lane did NOT do, and why

- **The plane -> Fp conversion itself (B1a).** `prove_layer_v3` builds
  `w_data` (1.4 GB at the Mistral shape) and `a_data` element by element
  with `Fp::from_i64` before any of this lane's code sees them; measured
  at ~0.92 s of the 3.13 s baseline layer. That code is in `layer.rs`,
  which the round-14 lane brief makes READ-ONLY for AJ. **It is the
  single largest host item in the pass and it is not assigned to anyone
  in round 14.** The device side is now ready for it: `k_widen` already
  reconstructs field elements from packed signed integers on the device,
  so the fix is to hand `pcs::commit` the int8 planes instead of a
  converted 64-bit vector, and give the two host matmul folds
  (`fold_cols_base` over `w_data`, another 0.26 s/layer) a device form.
  Counted at the 8B pass: **~29 s of the 95.5 s** [COUNTED from the
  one-layer phases].
- **The proof serialization (B4b).** The plan attributes ~13 s to
  "Merkle levels + serialization of a 1.23 GB proof". Measured: the
  serialization runs OUTSIDE the prove clock and costs **0.03 s per
  layer** (wall 6.61 minus load 3.39, prove 3.13, verify 0.04), i.e.
  ~1 s of the 225 s pass wall — not 13 s. Parallelizing
  `Opening::write_bytes` was therefore dropped as not worth the change to
  a file whose only other job is byte-identity.
- **A deeper NTT redesign.** At the winning configuration the opening's
  re-encode is ~0.44 s of a 2.50 s layer and is neither ALU- nor
  bandwidth-bound: 6.87e9 butterflies in 0.44 s is 1.6e10 Goldilocks
  multiplies per second against a ~4.6e11 ALU ceiling [COUNTED], and
  66 GB/s against 256 GB/s of bandwidth. It is a latency/launch-structure
  problem — output pruning (only 256 of 65,536 columns are wanted, worth
  ~1.6x on the forward transform [COUNTED]), a fused DIF/DIT, or a
  radix-4 stage. That is a kernel project, not a rung, and it is the
  right next item for whoever continues this lane.

## 8. Where the time actually moved (device counters, one Mistral layer)

| | r0base (chunk 1024, 256 thr) | chunk 128 + 512 thr, narrow OFF | chunk 128 + 512 thr, narrow ON |
|---|---:|---:|---:|
| commit W | 1.296 | **0.876** | 0.898 |
| commit A | 0.408 | 0.317 | 0.310 |
| helpers + commit H | 0.266 | 0.268 | 0.269 |
| matmul g/u + d | 0.283 | 0.248 | 0.244 |
| zero-check F + D | 0.171 | 0.182 | 0.172 |
| pcs openings | 0.592 | 0.605 | 0.593 |
| **PROVE** | **3.03** | **2.51** | **2.50** |
| device h2d | 0.532 s (1,871 MB) | 0.412 s (1,871 MB) | **0.365 s (292 MB)** |
| device ntt (encode + chunked hash) | 0.446 | **0.179** | 0.238 |
| device opening re-encode | 0.444 | 0.451 | 0.441 |
| **VRAM peak** | **5,651 MB** | **5,047 MB** | 5,249 MB |

The whole of this lane's win is in the two commitments, and inside them
it is the **encode: 0.446 -> 0.179 s, 2.5x**, from occupancy plus a
working set the cache can hold. The upload is a second-order term once
it is interleaved. The narrow form puts **292 MB on the bus instead of
1,871 MB (6.4x)** and costs 0.06 s of host packing, which on this box
is exactly a wash — and 202 MB of device memory for the packing scratch,
against the 604 MB the smaller chunk gives back, so the tree is 402 MB
lighter on VRAM than before this lane either way.

**What this means for the RTX 5090 measurement** [MODEL]: the parts a
faster device shrinks are now 0.179 (encode) + 0.441 (re-encode) + 0.172
(zero-checks) + 0.091 (fold) + 0.115 (helpers) = ~1.0 s of the 2.50; the
parts it does not touch are the ~1.2 s of layer.rs host conversion and
folds plus whatever the bus costs. On a device 4x faster the host share
becomes ~70% of a ~1.6 s layer, and the bus term stops being hidden —
which is why the narrow upload is kept on and why the layer.rs item in
§7 is the one that decides whether the 5090 buys 1.4x or 4x.
