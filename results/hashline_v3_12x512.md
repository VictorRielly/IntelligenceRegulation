# hashline `--profile v3` — the widened-stack statement on the hash line (U-PERF3 lane ZB, 2026-09-02)

The measured record behind the v3 rows, in the form of lane XX's
results/hashline_gpu_12x512.md (the v2 GPU row) and lane UU's
results/hashline_pass_12x512.md (the v2 CPU row). Every number here is
[MEASURED] on the WSL laptop (Core Ultra 9 185H, 22 threads, 15 GB;
RTX 4070 Laptop GPU, sm_89, 36 SMs, 8 GB), 8 rayon threads (+ the
device where marked), label [WSL-BOX 8T NOISY-SHARED] (lane ZA's
worktree present on the box; no concurrent build during the pass
walls; the GPU tamper legs ran alongside the v2 CPU gate). Commits:
a40b338 (rungs 0-2), 54a4558 / 5fb1f43 (rung 3), e37cd1a (rung 4),
the rung-5 commit (this file).

## What was proven

THE WIDENED-STACK STATEMENT (TARGET_CONTRACT section 2, the v3
amendment adopted 2026-08-26; what `ring_matmul uperf-v3` proves on the
lattice line), on the hash line, per FFN layer, for any (T, d, f):

- int8 X and int8 weights, as v2;
- the gate activation as a LOOKUP into the layer's frozen int16-out
  member (256 rows over the int8 gate domain, int16 outputs; the
  member's spec digest, the family name, (d, f) and the four SIGNED
  shifts are absorbed into the statement) — v2 looked up an int8-out
  SiLU;
- u16 / h16 / z16 in ONE 2^16-row INT16 class table [-32768, 32767]
  (v2's classes were int8; the class the engine's v3 statement proves,
  its honest-witness assert of +-32767 being a subset);
- ROUND-to-nearest requant as the exact identity acc = 2^sh y + r with
  the BALANCED remainder r in [-2^(sh-1), 2^(sh-1)) (v2 was floor with
  r in [0, 2^sh)); the identities stay linear with no constant term and
  fold into the evaluation claims exactly as v2's, so lane XX's zero-
  check kernels apply unchanged at the 125M block shape;
- negative sh_u (the exact public up-scaling branch, present in both
  real exports: 125M layers 3-4, Mistral layers 3+) as uacc = 2^-k u16
  with the field inverse of 2^k as the public coefficient and an all-
  zero remainder column over the one-row window {0};
- block structure on both axes instead of zero padding: d = nb_d x
  2^log_db and f = nb_f x 2^log_fb (125M: 768 = 3 x 256, 2048 = 1 x
  2048; Mistral: 4096 = 1 x 4096, 14336 = 7 x 2048).

The same three Ligero commitments (W: the weight blocks; A: the seven
f-planes g8/rg/a16/u16/ru/h16/rh and the three d-planes X/z16/rd per
block; H: the LogUp helper columns), the same two matmul sumchecks, the
same two zero-checks with every pending claim folded in (A and H open
at two points), LogUp with committed helpers, blake3 Fiat-Shamir, one
transcript per pass (domain "hashline-pass-v3"). The multiplicity
tables ride in the proof (256 + 65,536 + one window per distinct
shift), which is the whole size delta against v2. Same soundness
bookkeeping as v2 (~100-bit hash-only + ROM), NOT zero-knowledge (lane
ZA's form), FFN-only, no seams.

THE WITNESS is the export, bit for bit: `check-export --profile v3`
reproduces 96/96 tensor sha256s of the 125M v3 export
(results/m8b_test/m125_v3_export, frugal-125m, 12 x 512, T 512 d 768 f
2048) and 256/256 of the real Mistral-7B v3 export
(results/m8b_mistral_v3_export, 32 x 512, d 4096 f 14336, 7.0 GB of
bins); `chain --profile v3` re-executes every layer from X and the int8
weights and reproduces the a16/u16/h16/z16 planes on 12/12 (125M,
2.0 s) and 32/32 (Mistral, 127.6 s at 8T) layers; every range fact
holds on both. The proof's witness columns are derived by that chain
and asserted equal to the export's planes before proving.

THE GATE: the proof bytes are BYTE-IDENTICAL between the CPU-only
binary and the gpu-cuda binary with `HL_GPU=1`. The flat encoding of
the 12 layer proofs (`--proof-out`, 70,758,084 B) has

    sha256 5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d

from the CPU binary (3 runs) AND from the GPU binary (2 runs; `cmp` of
the written files agrees). The v2 gate is unchanged in this tree:
`pass 12 512 --threads 8 --proof-out` prints PROOF sha256
50cf7bdfd6b5b182.. (66,844,928 B) on both binaries.

## The 12 x 512 runs (`hashline pass 12 512 --profile v3 --export results/m8b_test/m125_v3_export --threads 8 --proof-out`, /usr/bin/time -v, under flock /tmp/zk-heavy.lock)

| run | PROVE (incl. the 3 commitments) | VERIFY | proof bytes | peak RSS | VRAM peak | proven MAC/s |
|---|---:|---:|---:|---:|---:|---:|
| v3 CPU run 1 | **17.40 s** | 0.27 s | 70,758,084 B | 1.58 GB | — | 1.67e9 |
| v3 CPU run 2 (after the one-witness-at-a-time `pass` edit) | 17.18 s | 0.31 s | same | — | — | 1.69e9 |
| v3 GPU run 1 (`HL_GPU=1`) | **2.74 s** | 0.26 s | same | 0.78 GB | 2.43 GB | 1.06e10 |
| v3 GPU run 2 (after the `pass` edit) | 2.78 s | 0.25 s | same | 0.43 GB | 2.43 GB | 1.04e10 |
| v2 CPU, this tree (the floor taken at the lane's opening, box quiet) | 16.81 s | 0.27 s | 66,844,928 B | 1.56 GB | — | 1.72e9 |
| v2 GPU, this tree (same) | 2.88 s | 0.27 s | same | 0.78 GB | 2.43 GB | 1.01e10 |
| v2 GPU, XX's record (p50 of 4, noisier box) | 3.40 s | 0.42 s | same | 0.78 GB | 2.43 GB | 8.5e9 |

Witness load + the exact integer chain (not in the prover clock):
1.5-1.8 s. Total wall of the GPU process: 4.7-4.8 s (/usr/bin/time
elapsed 6.6-6.7 s with process start, the NVRTC compile and the
device teardown).

Reading. The widened statement costs +3.5% CPU prove and +5.9% proof
bytes against v2 on the same box, and nothing measurable on the GPU
(-5%, inside the noise). The int16 classes are a 2^16-entry
multiplicity vector, not a wider commitment; the round-nearest
remainder is the same column as v2's floor remainder with a different
window table; the block structure removes zero padding rather than
adding work. So the v3 semantics are free at the hash line.

## Prover phases, summed over the 12 layers

| phase | v2 CPU (XX's tree, run 1) | **v3 CPU (run 1)** | v2 GPU (XX's run 2) | **v3 GPU (run 1)** |
|---|---:|---:|---:|---:|
| commit W | 1.98 s | 2.13 s | 0.43 s | 0.45 s |
| commit A | 3.64 s | 3.86 s | 0.95 s | 0.77 s |
| helpers + commit H | 4.18 s | 4.55 s | 0.50 s | 0.40 s |
| matmul g/u | 0.37 s | 0.40 s | 0.39 s | 0.30 s |
| matmul d | 0.22 s | 0.23 s | 0.27 s | 0.17 s |
| zero-check F (v2: "20") | 3.76 s | 3.61 s | 0.35 s | 0.33 s |
| zero-check D (v2: "17") | 1.75 s | 1.72 s | 0.10 s | 0.09 s |
| PCS openings | 1.43 s | 0.89 s | 0.35 s | 0.22 s |
| **PROVE** | **17.36 s** | **17.40 s** | **3.38 s** | **2.74 s** |

v3 GPU device-side sums (run 1): H2D 0.21 s for 1.27 GB, NTT 0.42 s,
blake3 leaves 0.10 s, zero-checks 0.43 s, row-combinations + eval_many
0.15 s, helpers 0.08 s, D2H 0.14 GB; about 1.4 s of the 2.74 s is
device time, the rest the same host remainder XX described.

## Tamper legs (all REJECT; `hashline layer L 512 --profile v3 --all-tampers --threads 8`, CPU and `HL_GPU=1`, at layer 0 (shifts 9/1/14/10) and layer 3 (8/-1/14/9: the up-scaling branch))

| leg | what the witness does | rejected by |
|---|---|---|
| flipped X entry | X[777] += 1 | g/u matmul sumcheck round 0: s(0) + s(1) != claim |
| flipped Wg entry | WgT[4242] += 1 | g/u matmul sumcheck round 0 |
| out-of-range remainder | rg += 2^sh_g, g8 -= 1 (identity kept; the remainder leaves its window) | LogUp identity fails (a lookup is not in its table) |
| wrong int16 table entry | a16 += 1, h16/rh and the down row recomputed consistently | LogUp identity fails |
| wrong requant | h16 += 1, rh unchanged | zero-check F round 0 |
| wrong z | z16 += 1 | d matmul sumcheck round 0 |
| WRONG ROUNDING | floor instead of round at the first gate element that rounds up, carried through the chain (a16 from the table, h16/rh/z16/rd recomputed): only the remainder window breaks | LogUp identity fails |
| out-of-range int16 | z16 += 65536 with rd compensated (identity kept; z16 leaves the int16 class) | LogUp identity fails |
| pass-level: wrong requant in layer 6 of the 12-layer chained transcript (`pass 12 512 --profile v3 --tamper requant`) | | layer 6: REJECT: sumcheck round 0 |

The same rejection sites through the CPU and the GPU prover. The
"wrong rounding" and "out-of-range int16" legs are the two the v3
statement adds over v2: a floor-rounded witness satisfies every linear
identity and is caught only by the balanced window; an int17 value
satisfies the requant identity and is caught only by the 2^16-row
class.

## The first 8B-width layer on the hash line (Mistral-7B layer 0, `hashline layer 0 T --profile v3 --export results/m8b_mistral_v3_export --threads 8`, CPU, 8T, under the heavy lock)

Counted before running: W = 3 x 4096 x 14336 = 176,160,768 Fp =
1.41 GB, its Ligero encoding at log_cols 14 = 10,752 rows x 65,536
cols x 8 B = 5.64 GB, A/H at T=16 under 0.1 GB, the int8 weights 0.18
GB: ~7.5 GB against `free -g` 14 GB available.

| T | PROVE | of which commit W | VERIFY | proof bytes | peak RSS |
|---|---:|---:|---:|---:|---:|
| 16 | **10.53 s** | 8.58 s | 0.029 s | 25,863,324 B | **7.48 GB** |
| 128 | 11.67 s | 7.92 s | 0.034 s | 28,759,676 B | 8.78 GB |
| 256 | 14.51 s | 9.37 s | 0.031 s | 32,069,404 B | 10.28 GB |
| 16, `--log-cols 16` | 9.47 s | 7.76 s | 0.066 s | 13,368,476 B | 7.46 GB |
| 16, `HL_GPU=1` | 10.62 s | 8.72 s | 0.034 s | 25,863,324 B | 7.54 GB |

ACCEPT at every row; the wrong-int16-table-entry leg at T=16 REJECTs
(LogUp, 9.0 s). Statement: shifts 11/2/15/6, member
silu-int16out-table-v3 (-3,-12) 859344ba5ed57bd3.. (the sidecar's,
regenerated and digest-checked by the reader).

Reading. (1) The T-scaling split, read off the three rows: the WEIGHT
part (commit W + its opening: ~9 s and ~7.0 GB per layer, the same at
any T) and the ACTIVATION part (~13.5 ms and 11.7 MB per token row);
a 7B layer at T=512 therefore models to ~18 s / ~13.3 GB on this box
[MODEL], 13.3 of the 14 GB available, which is why T=512 at 7B is a
Mac run (MAC_RUNBOOK item M9), not a laptop run. (2) The proof is 22
MB of W column openings (256 checks x 10,752 rows x 8 B); `--log-cols
16` (2,688 rows) halves it at the same wall and is the parameter to
prefer at 7B once a row is chosen (the byte-identity gate is per
parameter set). (3) `HL_GPU=1` at the 7B shape DECLINES the W commit
(cuMemAlloc 5376 MB: CUDA_ERROR_OUT_OF_MEMORY on the 8 GB part with
the 1.4 GB data already resident) and falls back to the CPU path with
the CPU bytes — the 7B GPU proof needs a chunked/streamed W encoding
(a future lane). The zero-checks at this shape (nb_f 7, nb_d 1: 73
and 7 tables) run on the host by design.

## Side by side

| | lattice line (`uperf-v3`, the same statement) | hashline v2 (UU / XX) | **hashline v3 (this record)** |
|---|---|---|---|
| statement | widened-stack v3, 125M 12x512 | int8 v2, 125M 12x512 | widened-stack v3, 125M 12x512 (and any (T, d, f)) |
| prove, CPU 8T | (see PROGRESS_UPERF3 round 10) | 17.4-20.9 s | **17.4 s** |
| prove, GPU | 18.0 s (2026-08-18 reference, int8) | 3.4 s p50 / 2.88 s quiet | **2.74 s** |
| verify | 1.7 s | 0.3-0.4 s | 0.26-0.31 s |
| proof bytes | 1.51 MB | 66.8 MB | 70.8 MB |
| peak RSS | 6.7 GB | 1.56 GB / 0.78 GB | 1.58 GB / 0.43 GB (+ 2.43 GB VRAM) |
| 7B layer, T=16 | minutes-class [MODEL], never measured (M4) | — | **10.5 s, 7.5 GB, measured** |

What the row does NOT say: anything about the Mac's numbers (M9 takes
them), anything about a 7B proof on this GPU (declined at the W
commit), or the 32-layer 7B pass (modelled at ~18 s x 32 ≈ 10 min and
~13.5 GB peak on this box with one witness resident at a time; the
Mac's run).
