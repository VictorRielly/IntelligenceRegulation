# U-PERF3 lane R — the 8B FFN shape: what it costs, what breaks, how MVP-1 runs

Status: SKELETON (2026-08-18, lane R of U-PERF3 round 1, worktree
/home/victor/wt-uperf3-r). Sections 0-5 are filled in order and each
lands in its own commit; every number carries [MEASURED] / [COUNTED] /
[MODEL] / [ASSUMED] and, for walls, its box label.

Scope: MVP-1 of PROGRESS_UPERF3.md — the TARGET_CONTRACT FFN statement
at the 8B shape (32 layers x 512 tokens x d 4096 x f 14336, SwiGLU,
real int8-calibrated weights from an open checkpoint), proved and
verified end to end on hardware we own.

## 0. One paragraph

(to be written last)

## 1. Counted sizes: 12x512 (measured) -> 32x512 at d 4096 / f 14336

Method. The 12x512 attribution is the measured one (PROGRESS_UPERF2.md
"after round 9": 21.0 s = commit 2.5 / prove 15.5 / verify 1.7 at
ZK_THREADS 8 + the RTX 4070 Laptop, RSS 6.7 GB GPU path / 11.1 GB CPU
path, artifact 1,509,911 B; U_PERF3_OPENING_LAYER_DESIGN.md Section 1
holds the counted anatomy — reused, not recounted). Every 8B number
below comes from `scripts/m8b_scaling_model.py` (NEW, this lane): a
Python replica of the engine's own public counters — `bk_pair_specs` /
`bk_build_groups` / `bg_entry_class` (ring_matmul.rs), `pair_depth` /
`plan_pair_trees` (descent_fold.rs), `masked_transcript_totals` /
`mask_coeff_counts` (gkr_masked.rs), `plan_schedule` (eval_proof.rs),
`derive_l0` / `representable` (digits.rs). `--check` asserts that it
reproduces `table-descent expect 12 512` exactly: act n0 7,854,476
(aux 31,116), weight n0 3,538,944, the ten pairs' depth / l / bytes
(TOTAL 1,083,456 B), schedules 9 levels floor 915 e7 (act) and 8
levels floor 939 e7 (weight), zero-check tables 2^24, 579 instance
K-elements, group wire bytes 179,576 / 182,184, artifact 1,509,911 B
[COUNTED == MEASURED]. The 8B rows are therefore [COUNTED] given
their inputs; ONE input is [ASSUMED] until the Mac calibration lands:
the per-layer exponent table (eX, eGate, eA, eUp, eH, eZ, eW) of the
8B checkpoint, for which the model cycles the M125 rows over 32
layers with eW = -9 (`--exps <manifest.json>` swaps in the real one).
The exponents move the remainder widths (hence which `rem-w*` pair a
column joins) and the SiLU member set; they do NOT move the group
sizes, the tree depths, the table sizes or the schedules by more than
the l0 of the remainder classes (5-6 limbs).

### 1.1 The shape

| | 125M rig | 8B FFN (MVP-1) | factor |
|---|---:|---:|---:|
| layers L / tokens T / d / f | 12 / 512 / 768 / 2048 | 32 / 512 / 4096 / 14336 | |
| int8 MACs per pass (L x T x 3df) | 2.90e10 | 2.89e12 | **x99.6** |
| int8 weights (L x 3df) | 56.6M | 5.64G | **x99.6** |
| activation elements per pass (L x T x (10f + 4d)) | 144.7M | 2.68G | **x18.5** |
| IXF layer slots (lambda) | 16 (4) | 32 (5) | fixed-class |
| f padded to a power of two | 2048 (exact) | 16384 (14336 -> 16384: 12.5% pad in every f-shaped table/tree) | |
| accumulator classes gate-up / down (honest signed bits) | 25 / 26 (l0 13 / 14) | 27 / 29 (l0 14 / 15) | +2 / +3 bits |

The pass has TWO scaling laws: everything that touches the WEIGHTS
scales ~x100 (the weight commitment group, the level-0 CRS matrix of
that group, the matmul-instance reductions, the chain GEMM), and
everything that touches the ACTIVATIONS scales ~x19 (the act group,
the descents' leaf elements, the zero-check tables — the last x16 by
table shape). Nothing in the pass is "fixed" except the artifact's
group-proof blocks (~180-190 KB per group) and the round counts of the
lattice recursion.

### 1.2 The commitment groups (witness digit rings, level-0 rings, the CRS)

| term (scales as) | 12x512 [COUNTED, matches the rig] | 32x512 8B [COUNTED] | factor |
|---|---:|---:|---:|
| weight group n_0 (digit rings; L x 3df / 128 x l0 8) | 3,538,944 (442,368 value rings) | **352,321,536** (44,040,192 value rings) | **x99.6** (weights) |
| act group n_0 incl. BK aux (activations x l0 5-15) | 7,854,476 (aux 31,116; 1,130,496 value rings) | **145,475,764** (aux 43,188; 20,447,232 value rings) | **x18.5** (acts) |
| w0 flat i8 store, both groups (n_0 x 128 B) | 1.46 GB (measured 1.3-1.5) | **63.7 GB** (weight 45.1 + act 18.6) | x44 |
| level-0 planner r / chunk, weight | r 64 / 55,296 | r 64 / 5,505,024 | chunk x99.6 (r at the 64 cap) |
| level-0 planner r / chunk, act | r 64 / 122,727 | r 56 / 2,597,782 (r 64 / ~2.27M once split, Section 2 W-3) | chunk x21 |
| level-0 CRS matrix A_0 = kappa 11 x chunk rings (boxed 1,064 B/ring), weight | 0.65 GB | **64.4 GB** | x99.6 |
| level-0 CRS matrix A_0, act | 1.44 GB | **30.4 GB** (7.6 GB per group once split in 4) | x21 |
| level-1 witness (boxed), weight / act | 0.14 / 0.41 GB | **35.2 / 11.1 GB** | x100 / x27 |
| schedule levels / floor rings, weight | 8 / 939 e7 | 10 / 936 e7 | fixed-class (+2 levels) |
| schedule levels / floor rings, act | 9 / 915 e7 | 10 / 918 e7 (9 / 936-948 when split) | fixed-class |
| level-0 exact-digit gate headroom (gamma_z vs gamma_max = 2^22.12), weight | +3.37 bits | **+0.05 bits** (2^22.07) | the sqrt-n law: -3.3 bits |
| level-0 gate headroom, act | +1.79 bits | **-0.31 bits — FAILS** (2^22.44); +0.19 split in 2, +0.69 split in 4 | -2.1 bits |
| level-0 h cross-garbage Theta(n_0 x r), both groups (ring-mults) | 0.73e9 | 30.7e9 | **x42** |
| level-0 verifier MACs ~ n_value_rings x 16 x n_contrib | ~8.6e9 [MODEL, design memo 1.3] | ~3.5e11 [MODEL: value rings x41] | **x41** |
| CRS expansion words (Sigma kappa x chunk over levels, both groups) | ~2.1e6 rings | ~9.0e7 rings | x43 |

Reading: the weight group at the 8B shape is a 352M-digit-ring
commitment — 45 GB of level-0 witness, a 64 GB level-0 CRS matrix if
it is materialized as today, a 35 GB level-1 witness — and it is THE
SAME at every T (a 32x16 yardstick carries the whole of it: Section 3).
The act group is 4.1x smaller than the weight group at 32x512 but is
the one that fails the level-0 gate, because its base is e0 = 2 (twice
the fold norm per ring of the sign-binary weights): its cap is 94.2M
digit rings, the weight group's 376.7M [COUNTED from
`gamma_max_exact` / `OP_CONC`; the 8B weight group passes with 3.5%
of gamma to spare].

### 1.3 The claim layer (8 folded IXF instances)

| term | 12x512 | 32x512 8B | factor |
|---|---:|---:|---:|
| joint-matmul tables (slots x inner_pad; ta/tb per instance) | 16 x 1024 (gate/up), 16 x 2048 (down) | 32 x 4096, 32 x 16384 | x8-16 (small either way) |
| the A/B reduction that BUILDS them (`bg_mm_tables`: every weight element x eq weight, per instance) | 56.6M weight elements | 5.64G | **x99.6** — this is `d.cl-tables`' weight side |
| zero-check factor tables, nf instances (Had, rq-g/u/h): 2^(lr + lcp_f + lambda) | 2^24 = 1.07 GB packed each, 4-5 per instance | **2^28 = 17.2 GB packed each** | x16 (T fixed; f 2048 -> 16384; slots 16 -> 32) |
| zero-check tables, nd instance (rq-d): 2^(lr + lcp_d + lambda) | 2^23 = 0.54 GB | **2^26 = 4.3 GB** | x8 |
| K9 packed-table cap (kfield.rs:283) | 2^25 (2.15 GB) — every table under it | **2^28 and 2^26 are OVER it** (Section 2 W-1) | |
| device-built ixf VRAM (3.5 tables rotating, U_PERF2_CLAIM2_REPORT.md) | 4.06 GB at 12x512 | ~60 GB (nf) — over any consumer board | |
| instance transcript (kel) | 579 = 37,056 B | 677 = 43,328 B | x1.17 |
| round-poly evaluations (`d.cl-rounds`) | 138 rounds | 3 x (12/12/14 + 5) + 4 x (23 + 5) + (21 + 5) = 199 rounds | x1.4 (each over 8-16x more elements) |

### 1.4 The descents (the ten per-table folded pairs)

Structure is per-model, not per-size (BG-F1): the same ten pair ids
(2 SiLU members, the [0,256) narrowings nf/nd, six remainder widths)
under the cycled exponent table; the REAL 8B table will redistribute
the remainder columns among the `rem-w*` pairs (and may need widths
outside 5..=10 — Section 2 W-7) and may name a SiLU member that is not
frozen (W-6). What does not depend on that: the tree depth (max member
footprint + 2 = 25 for every pair with an f-shaped member, 23 for the
d-shaped-only pairs), the leaf work and the transcript class.

| pair (cycled exps) | 12x512: cols -> trees (l) depth / dt -> B [COUNTED = rig] | 32x512 8B: cols -> trees (l, pads) depth / dt -> B [COUNTED] | U = one packed leaf table of the real trees (8B) |
|---|---|---|---:|
| silu-m3 | 10 -> 5 (8) 22 / 9 -> 118,336 | 26 -> 13 (16, 3) 25 / 9 -> 153,088 | 27.9 GB |
| silu-m4 | 2 -> 1 (1) 22 / 9 -> 92,480 | 6 -> 3 (4, 1) 25 / 9 -> 130,560 | 6.4 GB |
| nrw-88 | 24 -> 12 (16) 22 / 9 -> 129,856 | 64 -> 32 (32, 0) 25 / 9 -> 169,472 | **68.7 GB (1.75U = 120 GB peak)** |
| nrw-z | 12 -> 6 (8) 21 / 9 -> 111,360 | 32 -> 16 (16, 0) 23 / 9 -> 137,344 | 8.6 GB |
| rem-w5..w10 (6 pairs) | 48 -> 21 (24) 21-22 -> 631,424 | 128 -> 53 (68, 23) 23-25 -> 851,136 | 2.1-42.9 GB |
| **TOTAL** | 96 cols, 45 real trees, 1,083,456 B | **256 cols, 117 real trees, 1,441,600 B** | |

| term | 12x512 | 32x512 8B | factor |
|---|---:|---:|---:|
| member columns / real trees | 96 / 45 | 256 / 117 | x2.7 / x2.6 |
| witness tree depth (max footprint 2^20 -> 2^23) | 21-22 | 23-25 | +3 |
| leaf elements = Sigma over real trees of 2^depth (the K-work driver) | 172.0M [COUNTED = design memo 1.1] | **3.42G** | **x19.9** (acts) |
| descent rounds (round-poly kernel evaluations, both sides) | 3,497 (a.round-g x2367 device + tail) | 4,659 | x1.33 |
| K-mults [MODEL: 28 ns per leaf element on the GPU chain, design memo 1.1] | ~5.5e9 (3.9 s of kernels) | ~1.1e11 (~78 s of the same kernels IF the trees fit VRAM — they do not, Section 3) | x20 |
| descent transcript bytes | 1,083,456 (71.8% of the artifact) | 1,441,600 (74% of it) | x1.33 |
| the LKP-2 per-tree multiset ceiling (N x 64 < q31) | 2-9% used | **44-81% used** — passes; T = 1024 or a denser packing would NOT | |
| peak pair footprint 1.75U (U_PERF2_DESCENT4_REPORT.md model, exact at 12x512) | 5.6 GB (nrw-88) | **120 GB** (nrw-88; rem-w8 75 GB) | x21 |
| BK aux tensors appended to T_act (m, blinders, masks) | 31,116 digit rings | 43,188 | ~fixed |

### 1.5 The artifact and the statement [COUNTED]

| block | 12x512 (measured 1,509,911) | 32x512 8B | factor |
|---|---:|---:|---:|
| statement (v4 serialized, ~ linear in layers) | 26,103 | ~69,600 [MODEL: 26,103 x 32/12] | x2.7 |
| 8 folded instances | 37,056 | 43,328 | x1.17 |
| public binding claims | 1,536 | 4,096 | x2.7 |
| descent pairs (10) | 1,083,456 | 1,441,600 | x1.33 |
| weight group (outer + rows + levels + floor) | 179,576 | 190,552 | fixed-class |
| act group(s) | 182,184 | 188,248 (x1) / 2 x 186,408 (split in 2) / 4 x 184,872 (split in 4) | fixed-class per group |
| **TOTAL, P0** | **1,509,911 B = 1.44 MiB** | **1,937,432 B = 1.85 MiB** (2.02 MiB / 2.37 MiB with the act split in 2 / 4) | **x1.28-1.65** |

Against the contract's byte lines: Tier N (P0, 262,144 B/layer x 32 =
8.4 MB per pass) — 4.3x UNDER; Tier Z (P3, frozen 1,114,112 B per
32-layer pass) — the P0 artifact is already 1.74x OVER it before the
Tier-Z surcharges (~+0.55 MB per masked floor). At the 8B shape the
descents (74%) are the byte problem exactly as at 12x512 — Stage A of
the design memo (descents -> ~0.5 MB) is what brings the 8B pass
under 1.1 MB, not any 8B-specific work.

### 1.6 The rungs, counted (the same script; act-side terms only move with T; the weight group is identical at every T)

| rung | act n_0 | weight n_0 | zc table (nf) | leaf elements | peak pair 1.75U | w0 i8 | A_0 (w / a) | BfLayer i64 | artifact |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1x16 (one 8B layer; the WSL pre-rung) | 158,170 | 11,010,048 | 2^18 | 4.7M | 0.03 GB | 1.4 GB | 2.0 / 0.1 GB | 1.4 GB | 850,159 B |
| 4x16 | 594,781 | 44,040,192 | 2^20 | 15.5M | 0.1 GB | 5.7 GB | 8.1 / 0.1 GB | 5.7 GB | ~1.1 MB |
| 8x16 | 1,161,781 | 88,080,384 | 2^21 | 27.5M | 0.9 GB | 11.4 GB | 16.1 / 0.2 GB | 11.4 GB | 1,298,714 B |
| **32x16 (yardstick)** | 4,578,225 | **352,321,536** | 2^23 | 107M | 3.8 GB | 45.7 GB | 64.4 / 0.9 GB | 45.8 GB | 1,561,528 B |
| **32x128** | 36,397,249 | 352,321,536 | **2^26 (over the K9 cap)** | 856M | 30.1 GB | 49.8 GB | 64.4 / 7.6 GB | 50.3 GB | 1,779,176 B |
| **32x512 (MVP-1)** | 145,475,764 (**gate fails unsplit**) | 352,321,536 | **2^28** | 3.42G | 120 GB | 63.7 GB | 64.4 / 30.4 GB | 66.0 GB | 1,937,432 B |
| 8x512 (an act-heavy alternative) | 36,398,387 | 88,080,384 | 2^26 | 881M | 30.1 GB | 15.9 GB | 16.1 / 7.6 GB | 16.5 GB | 1,647,050 B |

Note the two axes: T moves the act side (x8 per 8x in T, minus the
fixed aux), the layer count moves BOTH sides linearly. A 1x16 rung of
the 8B model is 1.4 GB of witness and fits the WSL box as built (no
planner panic: the weight group is 11M digit rings, under the ~37.7M
r-search threshold of Section 2 W-2 — 3x16 at 33M still passes, 4x16
at 44M panics); 32 layers at ANY T carry the 352M-ring weight group.

## 2. What breaks in the code as built (file:line, smallest fix)

(pending)

## 3. Memory and time per box

(pending)

## 4. The data: checkpoint, calibration, export, the m8b scripts

(pending)

## 5. The plan (lanes, files, gates) + the Grok RUN task text

(pending)
