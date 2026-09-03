# The 8B FFN proof on the laptop GPU — the 32x512 row (U-PERF3 lane AC, 2026-09-03)

The measured record behind the 8B-GPU row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3, in the form of
lane XX's results/hashline_gpu_12x512.md (the 12x512 GPU row) and next
to the 8B CPU row it beats (results/hashline_mistral_32x512.log,
2026-09-03). Every number is [MEASURED] on the WSL laptop (Core Ultra 9
185H, 15 GB; RTX 4070 Laptop GPU, sm_89, 36 SMs, 8,188 MB, 55-70 W), 8
rayon threads + the device, under `flock /tmp/zk-heavy.lock` and
`/usr/bin/time -v`; label **[WSL-BOX 8T GPU NOISY-SHARED]** (three other
round-12 lanes shared the box; see "the noise" below). Commits: rungs
0-5 of "Agent AC status" in PROGRESS_UPERF3.md, 04cf05d .. the rung-5
commit.

## What was proven, and the one gate

**Mistral-7B's 32 FFN layers at T = 512 tokens**, `--profile v3` (d
4096, f 14336, SwiGLU with the int16-output tables), the export
results/m8b_mistral_v3_export (lane AA/BB, 6.8 GB), exact int8
semantics, one blake3 Fiat-Shamir transcript over the 32 layers,
Ligero/Brakedown PCS at RS rate 1/4 with n = 2^14 columns and Q = 256
column checks, ~100-bit hash-only + ROM soundness, **NOT** zero
knowledge (mode P0), **2.886e12 MACs per pass**. THE SAME statement and
THE SAME witness as the CPU row.

What it is NOT (unchanged from every earlier row, and from the round-12
ruling): FFN-only — no attention, no norms, no embeddings, no layer
seams (each layer's X is committed fresh); X and weight ranges are
declared, not range-proven; the witness derivation (130-138 s of
loading and chaining 6.8 GB of export) is outside the prover clock.

THE GATE — the proof is the same 1.23 GB file on both machines and in
every cache state:

    sha256 dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c
           (1,234,936,956 B)

from (1) the CPU-only binary, no cache (the merged reference run), (2)
the gpu-cuda binary with `HL_GPU=1` and a COLD weight cache (32 misses,
134.2 MB written), and (3) the same binary with a WARM cache (32 hits,
each Merkle tree re-verified level by level on load). Checked by hand,
not assumed: `sha256sum` over the three written files gives one digest.
So at 8B the proof bytes are invariant under device vs host, under
chunked vs resident commitment, and under cached vs freshly committed
weights. (The fourth configuration, *cached CPU at 32x512*, is posted
as an ORCHESTRATOR-RUN — it is ~575 s of wall, over this lane's ceiling.
The cached CPU form is byte-identical at 12x512 in both profiles and at
one Mistral layer, 179ec2fb..; the cache never enters the transcript,
it only skips recomputing a tree whose root is already what the
transcript absorbs.)

## The runs (`HL_GPU=1 hashline pass 32 512 --profile v3 --export ... --threads 8 --wcache DIR --proof-out F`)

| run | witness load+chain | PROVE | VERIFY | process wall | proof | peak RSS | VRAM peak | proven MAC/s | tok/s (prover clock) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| CPU only, no cache (the reference) | 136.37 s | **510.38 s** | 1.21 s | 650.15 s | 1,234.9 MB | 13.99 GB | — | 5.655e9 | 1.00 |
| **GPU, cache cold** | 130.75 s | **175.09 s** | 1.09 s | 308.82 s | 1,234.9 MB (same bytes) | **5.33 GB** | **4,175 MB** | **1.648e10** | **2.92** |
| **GPU, cache warm** | 138.02 s | 193.29 s | 1.24 s | 334.93 s | 1,234.9 MB (same bytes) | 5.33 GB | 4,175 MB | 1.493e10 | 2.65 |

**The 8B FFN pass proves in 175 s on a 55-70 W laptop GPU instead of 510
s on 8 CPU threads — 2.92x — in 5.33 GB of host RSS instead of 13.99
(2.6x less) and 4,175 MB of the part's 8,188 (51%).** The verifier is
unchanged (CPU, ~1.1-1.2 s for a 1.23 GB proof).

THE NOISE, stated: the cold run had the GPU to itself (other lanes were
compiling on the CPU); during the warm run lane AF's `pass 12 512` gates
and a lane-AE python held 5-6 CPU threads. The per-layer walls show it
exactly — cold: mean **5.472 s**, min 5.314, max 5.661 (32 layers inside
+/-3.5%); warm: mean 6.040, min **5.446**, max **8.855**. The warm run's
tightest layers are the cold run's class; its mean is the box. **The
warm-vs-cold wall comparison at pass scale is therefore not evidence
about the cache** — the cache's effect is read below from the internal
accounting, which is immune to it, and from rung 3's single-layer
measurement on a quieter box (5.56 s cold -> 4.94 s warm).

## Per-layer anatomy (cold run; the same 8 phases as the 12x512 record, summed over 32 layers)

| phase | CPU (reference) | GPU cold | GPU warm | factor (cold) | where it runs at this width |
|---|---:|---:|---:|---:|---|
| commit W | 224.97 s | 38.85 s | 34.66 s | **5.8x** | device: chunked RS encode + streaming blake3; host: i8 -> Fp, Merkle levels |
| commit A | 81.77 s | 13.53 s | 16.51 s | **6.0x** | same, i32 -> Fp |
| helpers + commit H | 102.74 s | 35.24 s | 45.16 s | 2.9x | HOST helper columns (the device helper kernel is off at this shape) + device commit |
| matmul g/u | 6.58 s | 5.38 s | 6.12 s | 1.2x | device eval_many; host folds + the small sumchecks |
| matmul d | 3.52 s | 2.86 s | 3.40 s | 1.2x | same |
| zero-check F | 50.82 s | 46.64 s | 53.36 s | **1.1x — HOST** | host: 73 tables at this width (7 f-blocks x 10 + 3 eq) |
| zero-check D | 7.75 s | 7.48 s | 8.30 s | 1.0x — HOST | host |
| pcs openings | 31.68 s | 24.61 s | 25.25 s | 1.3x | device: chunked re-encode 15.73 s + gather; host: claim grouping, paths, 1.23 GB of serialization |
| **PROVE** | **510.38 s** | **175.09 s** | **193.29 s** | **2.92x** | |

Read down the "factor" column: **the device won where the work is a
commitment or an opening — 441.16 s of CPU work becomes 112.23 s (3.9x)
— and won nothing anywhere else**, because everything else is still on
the host at this width. That is the whole shape of the 8B GPU row.

Device-side accounting (cold, the crate's own counters; wall seconds
around asynchronous launches): **h2d 15.72 s for 72,209 MB** (the
witness planes as field elements, pageable ~4.6 GB/s), chunked encode +
streaming hash 15.63 s, opening re-encode 15.73 s, folds 6.75 s, d2h
1,413 MB; **96 chunked commits** — at this width W (10,752 rows), A
(3,520) and H (2,944) ALL exceed the 1 GiB resident limit, so every
commitment in the pass goes through rung 2's chunked path and nothing
larger than ~0.65 GB of scratch is ever resident. The `hash`,
`sumcheck` and `helpers` counters read 0.000 for two different reasons:
the chunked path folds its hash time into the encode counter unless
`--verbose` (so hashing did NOT leave the device), while the zero-check
and helper counters are genuinely zero because those kernels never ran.
Device-accounted total: **53.8 s of the 175.09 (31%)**.

VRAM peak 4,175 MB is the same number as one layer (rung 3): the pass
holds one layer's working set at a time. It is 51% of the part, so the
same code has room for the chunk-size and pinned-staging levers below —
and this is the shape that `HL_GPU=1` DECLINED before this lane (the
5.4 GB single allocation for W's encoding).

## The weight cache at 8B: what it removes, and what it cannot

[MEASURED, internal accounting] Cold: `commit(miss) 21.02 s + key 0.49 +
save 0.06`, 134.2 MB written (4,194,372 B per layer — the 17-level tree
of 2^16 leaves + a 100-byte header). Warm: `load+verify 0.49 s +
re-encode 11.53 + key 0.52`, 134.2 MB read, every tree re-hashed level
by level before use. **The cache removes 9.0 s of the 32-layer GPU
prove** (corroborated by the device encode counter, 15.63 -> 8.23 s) —
about 5% of the pass. On the CPU path the same cache removes ~2.1 s per
layer, **~67 s of the 510 s** [COUNTED from rung 1's measured 8.51 ->
6.43 s on one Mistral layer].

Why it is not the lever the round expected: of the 224.97 s the CPU
spends committing weights, the cache can only remove the hashing, the
tree and the allocation. **The Reed-Solomon re-encoding must be paid on
every proof** because the Q = 256 opened columns are chosen by the
transcript AFTER the root is absorbed, and pcs.rs serves them from a
materialized encoding — ~176 s of the CPU's W phase [COUNTED from rung
1's 5.49 s/layer] and 11.5 s of the GPU's. The two ways to remove that
remainder are recorded, not built: persist the encoded rows (5.6 GB per
7B layer, 180 GB per model — the host store would still have to hold
one layer's 5.6 GB, so it trades an NTT for a disk read of the same
size), or serve the opening's columns without the matrix through a new
`Store` variant (a direct rows x n x Q evaluation; pcs.rs is outside
this lane). What the cache DOES buy, beyond the seconds: 134 MB of
verified Merkle trees per model that any later pass, profile run or
tamper battery reuses, keyed by blake3 over the actual int8 planes, so
a tampered weight can never reuse an honest tree (asserted: a flipped
leaf byte is REJECTED at level 0 and re-committed, and the proof bytes
are unchanged).

## The host remainder, and what would move it

Of the 175.09 s, **121.3 s is host work** and the two zero-checks are
the biggest single piece:

| host item | cold s | why it is on the host | the lever [MODEL] |
|---|---:|---|---|
| zero-check F + D | **54.12** | lane ZB's `dev_shape` gate in layer.rs (`nb_f == 1 && nb_d == 3`) keeps XX's zero-check kernels — templated on 13/15 tables — to the 125M block shape; Mistral's F-side check has 73 tables | a block-looping kernel (one f-block at a time, same register footprint): **-49 s** |
| helper columns (inside "helpers + H") | ~22 | the same gate: the batched-inverse helper kernel is 125M-shaped | the same fix: **-20 s** |
| i8/i32 -> Fp conversion + pageable upload | ~20 | the planes are converted host-side and uploaded pageable (15.72 s of h2d for 72.2 GB) | upload the raw planes and convert on the device; pinned staging: **-10 to -15 s** |
| Merkle levels (3 commitments x 2^16 leaves x 32 layers) | ~12 | the device returns leaves; the levels are host | a device tree-build: -8 s |
| claim bookkeeping, paths, serializing 1.23 GB | ~13 | inherently host | the compact PCS (lane AF) changes this term's size |

Applying only the first two (the `dev_shape` fix, which is ZB's file,
not this lane's) takes the pass to **~105-125 s, 4.1-4.9x the CPU and
~4.1-4.9 tok/s** [MODEL]. Everything in this table is byte-preserving:
none of it changes the transcript.

## Tokens per second at 8B on this laptop GPU, against lane YY's model

[MEASURED] prefill (T = 512 per proof), mode P0, FFN-only tokens:

| cell | YY's model (U_PERF3_ROUTE_B_THROUGHPUT.md section 6.2) | MEASURED here |
|---|---|---:|
| 8B prefill P0, laptop CPU 8T | **1.0** tok/s [MODEL] | **1.00** tok/s (512 / 510.38) |
| 8B prefill P0, laptop GPU | **5.2-16** tok/s [MODEL] | **2.92** tok/s (512 / 175.09); 1.66 on the process wall |
| 8B prefill P0, laptop GPU, proven MAC/s (section 6.5) | 2.9e10-8.8e10 [MODEL] | **1.648e10** |

**The verdict: the CPU cell was exactly right and the laptop-GPU cell is
NOT — the measurement lands 1.8x BELOW the bottom of YY's [5.2, 16]
band.** The reason is section 3.3's premise, stated there as "Route B's
work is entirely device-shaped": at the 125M shape it is (XX measured
5.3x), but at Mistral's width the prover falls off the device for the
two zero-checks and the helper columns (76 s, 44% of the pass) because
the kernels are shape-gated, and another ~42 s is host conversion,
Merkle and serialization work. The hardware factor the pass actually
realized is **2.92x**, not 5-15x. With the shape gate fixed the same
box models to 4.1-4.9 tok/s — still under the band; the band's low end
needs the conversion/upload and Merkle items too. Nothing here bears on
the H100 columns except as a caution: they are built on the same
"entirely device-shaped" premise, and this is the first measurement of
that premise at a real model width. Decode (T = 1) was not run.

## Side by side (the honest comparison)

| | hashline CPU, 8B (2026-09-03) | **hashline GPU, 8B (this record)** | hashline GPU, 125M 12x512 (XX) |
|---|---|---|---|
| statement | Mistral-7B 32 FFN layers x 512 tokens, exact int8, v3 | THE SAME (byte-identical proof) | 125M FFN 12x512 |
| prove | 510.38 s | **175.09 s** | 3.40 s p50 |
| verify | 1.21 s | 1.09 s | 0.42 s |
| proof | 1,234.9 MB | 1,234.9 MB (dc980e81..) | 66.8 MB |
| peak RSS | 13.99 GB | **5.33 GB** (+ 4,175 MB VRAM) | 0.78 GB (+ 2.43 GB VRAM) |
| proven MAC/s | 5.655e9 | **1.648e10** | 8.5e9 |
| tok/s (FFN-only, prefill) | 1.00 | **2.92** | 150 (of a 125M model) |
| device share of the prove | — | 31% accounted; 44% of the pass is host-gated work | ~44% |
| ZK | no (P0) | no (P0) | no |

Reading. The first 8B proof in this repository ran on the CPU in 8.5
minutes; the same proof now runs on the laptop's GPU in 2.9 minutes,
byte for byte, inside 5.3 GB of RAM and half the part's VRAM — which
means the 8 GB consumer part is no longer the binding constraint on
model width for this prover (rung 2's chunked commitment is what
removed it: nothing at any width need be resident). The speedup is
**2.92x, not the modelled 5-15x**, and the record above says precisely
where the missing factor is: 76 s of shape-gated zero-check and helper
work that never reached the device, in a file this lane does not own.
That is the next lever on this line, and it is worth ~1.5x of pass
time. The row carries every caveat of its CPU parent (FFN-only, no
seams, declared ranges, no ZK, a sqrt-size 1.23 GB proof) and adds
none of its own.
