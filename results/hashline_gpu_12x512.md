# hashline on the GPU — the 12x512 row (U-PERF3 lane XX, 2026-09-02)

The measured record behind the GPU row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3, in the form of
lane UU's results/hashline_pass_12x512.md (the CPU row it sits next
to). Every number here is [MEASURED] on the WSL laptop (Core Ultra 9
185H, 22 threads, 15 GB; RTX 4070 Laptop GPU, sm_89, 36 SMs, 8 GB,
55-70 W), 8 rayon threads + the device, label [WSL-BOX 8T GPU
NOISY-SHARED] (other lanes built and ran on the box during the runs;
load average 2-4 during the four GPU runs, 3.5-7 during the CPU
reference runs). Commits: see the status section (rungs 0-5,
7352e3d .. the rung-5 commit).

## What was proven, and the one gate

THE SAME statement and THE SAME witness as lane UU's CPU row: the 125M
FFN pass, 12 layers x 512 tokens (T 512, d 768, f 2048), exact int8
semantics (TARGET_CONTRACT.md section 2), the WSL re-export
results/m125_ffn_export_wsl/ (48/48 tensor sha256s and 12/12 z
digests reproduced), 2.899e10 MACs per pass. The same protocol, the
same parameters (Goldilocks + F_{p^2} challenges; Ligero/Brakedown PCS
at RS rate 1/4, n = 2^14 columns, Q = 256 column checks; the matmul
sumchecks; LogUp with committed helpers; the two zero-checks; blake3
Fiat-Shamir, one transcript over the 12 layers), the same soundness
bookkeeping (~100-bit hash-only + ROM), NOT zero-knowledge, the same
caveats (FFN-only, no seams, X/W ranges declared).

THE GATE: the proof bytes are BYTE-IDENTICAL to the CPU prover's. The
transcript is deterministic, every device kernel computes the
canonical representative of the same field quantity (an NTT is the
evaluation map, a sumcheck round sum is a field sum, a row-combination
a linear map, an inverse is unique; blake3 is a function), so the
Merkle roots, the sumcheck messages and the openings are the same
bytes. Checked, not assumed: the flat little-endian encoding of the 12
layer proofs (`--proof-out`, 66,844,928 B) has

    sha256 50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d

from the CPU-only binary (3 runs) AND from the gpu-cuda binary with
`HL_GPU=1` (4 runs; `sha256sum` of the written files agrees), and
596b9c79f086d6f1.. (7,365,588 B) at 3x16 from both. The gpu-cuda
binary with `HL_GPU` unset produces the CPU bytes too. Every rung
(0-4d) re-ran this gate before it was committed.

## The runs (12 x 512, `HL_GPU=1 hashline pass 12 512 --threads 8`, /usr/bin/time -v, alone on the device, under flock /tmp/zk-heavy.lock)

| run | PROVE (incl. the 3 commitments) | VERIFY | proof bytes | peak RSS | VRAM peak (held) | proven MAC/s |
|---|---:|---:|---:|---:|---:|---:|
| GPU run 1 | 3.43 s | 0.44 s | 66,844,928 B | 775 MB | 2.43 GB | 8.44e9 |
| GPU run 2 | 3.38 s | 0.41 s | same | 775 MB | 2.43 GB | 8.58e9 |
| GPU run 3 | 3.38 s | 0.41 s | same | 775 MB | 2.43 GB | 8.59e9 |
| GPU run 4 | 3.49 s | 0.43 s | same | 775 MB | 2.43 GB | 8.31e9 |
| **GPU p50 of 4** | **3.40 s** | **0.42 s** | **66.8 MB** | **0.78 GB** | **2.43 GB** | **8.5e9** |
| CPU-only binary, this tree, run 1 | 17.36 s | 0.73 s | same | 1.56 GB | — | 1.67e9 |
| CPU-only binary, this tree, run 2 (load 3.6-6.9) | 20.38 s | 0.38 s | same | 1.56 GB | — | 1.42e9 |
| CPU-only binary, this tree, run 3 (load 3.6-6.9) | 20.90 s | 0.33 s | same | 1.56 GB | — | 1.39e9 |
| **CPU p50 of 3 (this tree)** | **20.4 s** | **0.4 s** | **66.8 MB** | **1.56 GB** | — | **1.4e9** |
| UU's CPU row (2026-09-02, untuned) | 23.0 s p50 | 2.8 s | same | 1.56 GB | — | 1.26e9 |

Witness load + the plain integer chain (not in the prover clock):
1.2-1.4 s. Total wall of the GPU process (load + prove + verify +
serialize): 5.3 s; /usr/bin/time elapsed 7.7-7.8 s (adds process
start, the NVRTC compile of kernels.cu ~0.5-0.8 s, and the device
teardown). "VRAM peak" is cuMemGetInfo's total - free sampled after
the allocations (the pool holds the three commitments' data +
encodings, ~1.1 GB, plus the zero-check tables 0.25 GB and scratch;
the driver's own context ~0.3 GB is inside the number).

Two notes on the CPU column. (1) The CPU prover moved from UU's 23.0
s to 17.4-20.9 s in this tree through two byte-identical changes found
while profiling the GPU path — `mle::eq_table` no longer opens a rayon
region per doubling step below 4096 entries, and `pcs::group_claims`
builds each column-weight table once per group — and the CPU
VERIFIER moved from 2.8 s to 0.3-0.7 s for the same reason (the
verifier calls group_claims too). UU's 23.0 s row stands as the
round-11 record of the untuned prototype; the CPU number to compare
the GPU row with is this tree's. (2) The CPU reference runs were
taken under a heavier load (another lane's `ring_matmul` at 400% CPU
for part of them; load average up to 6.9); run 1 (17.36 s) had load
2-3.

## Prover phases, summed over the 12 layers (GPU run 2 vs the CPU reference)

| phase | CPU (UU's row) | CPU (this tree, run 1) | GPU (run 2) | what runs on the device |
|---|---:|---:|---:|---|
| commit W | 2.19 s | 1.98 s | 0.43 s | H2D 37 MB, RS encode (NTT), blake3 leaves; host: i8 -> Fp, Merkle levels |
| commit A | 3.98 s | 3.64 s | 0.95 s | H2D 68 MB, encode, leaves; host: i32 -> Fp |
| helpers + commit H | 4.58 s | 4.18 s | 0.50 s | helper columns (batched inverses), encode, leaves, helper sums |
| matmul g/u | 0.77 s | 0.37 s | 0.39 s | eval_many; host: the eq tables and the folds of X / Wg / Wu, the 2^8 sumcheck |
| matmul d | 0.60 s | 0.22 s | 0.27 s | eval_many; host: the folds of h8 / Wd, the 2^11 sumcheck |
| zero-check 20 | 4.50 s | 3.76 s | 0.35 s | tables built on the device, 20 rounds + folds; host: the transcript |
| zero-check 17 | 2.30 s | 1.75 s | 0.10 s | same |
| PCS openings | 3.96 s | 1.43 s | 0.35 s | row-combinations, column gather; host: claim grouping, paths, absorbs |
| **PROVE** | **23.0 s** | **17.36 s** | **3.38 s** | |

Device-side sums (run 2, from the crate's own accounting; the
kernels' launches are asynchronous, so these are wall seconds around
the device phases, not kernel time): H2D 0.25 s for 1.27 GB (~5 GB/s,
pageable), NTT 0.43 s (36 commitments: the inverse 2^14 DIF ~3 ms and
the forward 2^16 DIT ~11 ms for the 520-row A), blake3 leaves 0.12 s,
zero-checks 0.45 s, row-combinations + eval_many 0.17 s, helpers
0.10 s, D2H 0.14 GB. About 1.5 s of the 3.4 s is device time; the
rest is host work around it (the witness planes to Fp for W and A
~0.35 s, the matmul folds and the 2^8/2^11 sumchecks ~0.5 s, the
Merkle levels 3 x 2^16 leaves per layer, the transcript, claim
grouping, serialization) and the per-round syncs.

## The GPU port, in one paragraph each

- Rung 0: cudarc 0.13.9 + NVRTC (zkmatrix-rs's toolchain), `gpu-cuda`
  feature, `HL_GPU=1` toggle; the Goldilocks reduction is the CPU's
  reduce128 with the same borrow/carry adjustments; probe: 2^20 pairs
  (81 edge pairs first) mul/add/sub 0 mismatches.
- Rung 1: the batched row NTT (12 shared-memory radix-2 stages on
  4096-element blocks + the strided tail stages on closed tiles; the
  CPU twiddle tables, stage-major); device-resident commitments;
  gpu-probe encodes random rows at 7 (log_cols, inv_rate, rows)
  shapes with 0 mismatches vs the CPU encoder.
- Rung 2: blake3 per column on the device (the reference algorithm:
  chunks, the lazy CV-stack merge, the root roll-up), checked at 322
  row counts x 64 columns against `blake3::hash`; the host copies
  back only the 2^16 leaves and builds the Merkle levels. A/B against
  host hashing at 12x512: D2H 3.17 s / 7.8 GB + 1.0 s host hash vs
  0.3 s device — decided.
- Rung 3: the two zero-check sumchecks (13 x 2^20 and 15 x 2^17
  tables) with the tables built on the device from the resident A / H
  data and device eq tables; round kernel templated on the table
  count (registers, not local memory); the round loop and the
  transcript on the host. The matmul sumchecks stay on the host by
  design (2^8 / 2^11 tables).
- Rung 4: the opening's row-combinations (2-4 weight vectors at once)
  and the column gather on the device; then (4b) the LogUp helper
  columns (Montgomery-batched Fp2 inverses per 8-element chunk) into
  a device H buffer committed without an upload, (4c) eval_many and
  eq tables by the two-half join, and (4d) a device buffer pool (a
  fresh allocation paid ~12 ms per 68 MB on first touch here) and a
  gather-free encode (DIF inverse -> bit-reversed coefficients -> DIT
  forward with a contiguous zero-padded load).

## Tamper legs through the GPU prover (all REJECT; `HL_GPU=1 hashline layer 0 512 --all-tampers --threads 8`, and the pass-level leg)

| leg (GPU prover) | rejected by |
|---|---|
| flipped X entry | g/u matmul sumcheck round 0: s(0) + s(1) != claim |
| flipped Wg entry | g/u matmul sumcheck round 0 |
| out-of-range remainder (rg += 2^sh_g, g8 -= 1, multiplicities padded) | LogUp identity fails (a lookup is not in its table) |
| wrong table entry (a8 += 1, downstream chain recomputed) | LogUp identity fails |
| wrong requant (h8 += 1) | zero-check 20 round 0 |
| wrong z | d matmul sumcheck round 0 |
| pass-level: wrong requant in layer 6 of the 12-layer chained transcript (`pass 12 512 --tamper requant`) | layer 6: REJECT: sumcheck round 0 |

The same seven legs, the same rejection sites as through the CPU
prover (UU's table): the device prover produces the honest prover's
proof of the tampered witness and the verifier (CPU, as before)
rejects it at the same check. (The tamper pass, run right after the
CPU reference runs had freed the box, proved its 12 layers in 2.75 s
— the fastest 12x512 prove seen in this lane; it is not in the p50
because it is not an ACCEPT run, but it bounds the NOISY-SHARED
penalty on the 3.4 s row at ~20%.)

## Side by side (the honest comparison)

| | lattice line (zkmatrix-rs, 2026-08-18 reference) | hashline CPU (UU / this tree) | hashline GPU (this record) |
|---|---|---|---|
| statement | 125M FFN 12x512 exact int8 | THE SAME | THE SAME (byte-identical proofs) |
| box / device | WSL laptop, 8T + RTX 4070 Laptop, QUIET | WSL laptop, 8T CPU, NOISY-SHARED | WSL laptop, 8T + RTX 4070 Laptop, NOISY-SHARED |
| prove (incl. commit) | 18.0 s (2.5 commit + 15.5 prove) [GPU] | 23.0 s / 20.4 s p50 (17.4 best) | **3.40 s p50 (3.38-3.49)** |
| verify | 1.7 s | 2.8 s / 0.4 s | 0.42 s |
| proof bytes | 1.51 MB | 66.8 MB | 66.8 MB (identical bytes) |
| peak RSS | 6.7 GB | 1.56 GB | 0.78 GB (+ 2.43 GB VRAM) |
| proven MAC/s | 1.4e9 [GPU + 8T] | 1.26e9 / 1.4e9 | **8.5e9** |
| assumptions | MLWE/MSIS, ZK yes | hash-only + ROM ~100-bit, ZK NO | same as CPU |

Reading. The hash-based prover of the same statement, ported to the
laptop's GPU in one lane-day on top of UU's lane-day, proves the
12x512 pass in 3.4 s — 6.1x the lattice line's 1.4e9 proven MAC/s on
the same device, 5.3x its own CPU form in this tree, and inside the
contract's 5-15 s band at 125M on a 55-70 W part. It is NOT the
[MODEL] 1.5-2.5 s UU estimated for the port: the Amdahl estimate
assumed 10-30x per-kernel factors over the whole prover; what was
measured is that the device phases (encode, hash, zero-checks,
openings, helpers) did move 8-30x, but ~1.9 s of host work around
them — witness planes to field elements and their upload, the matmul
folds and small sumchecks, Merkle levels, transcript and claim
bookkeeping, per-round syncs — now sets the floor, and the NTT itself
runs at a fraction of the part's arithmetic ceiling (the 520-row
forward 2^16 transform takes ~11 ms, about 34 G butterflies/s). Those
are engineering items with known fixes (upload the i8/i32 planes and
convert on the device; the folds on the device; pinned staging; a
radix-4 / bank-conflict-free NTT), none of which changes a byte. What
the row does NOT say: anything about 30B / H100 throughput (lane YY's
model owns that), and it still carries every caveat of UU's row
(FFN-only, no seams, declared X/W ranges, no ZK, sqrt-size proofs).
