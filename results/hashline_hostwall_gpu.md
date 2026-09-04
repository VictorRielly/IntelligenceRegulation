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
