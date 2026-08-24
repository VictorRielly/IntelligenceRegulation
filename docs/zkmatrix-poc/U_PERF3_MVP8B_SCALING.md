# U-PERF3 lane R — the 8B FFN shape: what it costs, what breaks, how MVP-1 runs

Status: COMPLETE (opened 2026-08-18, finished 2026-08-23; lane R of
U-PERF3 round 1, worktree /home/victor/wt-uperf3-r). Every number
carries [MEASURED] / [COUNTED] / [MODEL] / [ASSUMED] and, for walls,
its box label.

Scope: MVP-1 of PROGRESS_UPERF3.md — the TARGET_CONTRACT FFN statement
at the 8B shape (32 layers x 512 tokens x d 4096 x f 14336, SwiGLU,
real int8-calibrated weights from an open checkpoint), proved and
verified end to end on hardware we own.

## 0. One paragraph

The 8B FFN statement (32 x 512 x 4096 x 14336, real Mistral-7B-v0.1
weights) is TWO scalings of the measured 12x512 pass — everything
touching the weights x99.6, everything touching the activations
x18.5 — and the counted result is a 352M-digit-ring weight
commitment, 2^28 zero-check tables, a 120 GB peak descent pair and a
1.94 MB artifact (Section 1). Eleven things break on the way
(Section 2): five hard code fixes (the 125M-shaped loader W-5, the
acc classes W-4, the planner's r-search W-2, the K9 table cap W-1,
the act-group gate W-3), two calibration-dependent ones (W-6 SiLU
member — a Victor ruling; W-7 width band) and the memory work W-8.
With ONE memory fix (W-8a) the pass fits the Mac's 256 GB at ~184 GB
peak; it never fits the WSL box at 32 layers (Section 3) — the WSL
box is the 1x16/3x16 dev rung, the Mac is the MVP box, and the
honest walls are ~15-30 min (32x16 yardstick) and ~35-75 min (32x512)
Mac CPU [MODEL], verify ~1-2 min, with the weight group 60-70% of
every 32-layer wall (lane T's target). The witness pipeline EXISTS
and is validated (Section 4): m8b_int8_calibration.py +
m8b_export_ffn.py stream any-size safetensors at < 4 GB RSS and
reproduce the m125 references on this box 12/12 (weight export
byte-identical, val loss to 4 decimals); what remains before the
first real-8B proof is Victor's download go-ahead (T12, Section 5.2),
then two small code rungs (W-5+W-4, W-2) to the 1x16 pre-rung, then
the split work (W-1, W-3) to the Mac ladder (Section 5.1).

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

Ordered by where the rig dies first when pointed at an 8B export.
"HARD" = a panic / reject / a box that cannot hold it; "SOFT" = wrong
numbers or a needless cost. Sizes are [ASSUMED] lane-days.
Lines are at HEAD d1d1963 (`zkmatrix-rs/src/...`).

| id | what breaks | where (file:line) | at which rung | smallest fix | size |
|---|---|---|---|---|---:|
| **W-5** HARD | the rig IS the 125M model: exponents from a 12-row const, shapes from three consts, eW = -9 inline | `bin/ring_matmul.rs:19658` `M125_EXP: [..; 12]` (indexed `M125_EXP[l]` at :24652 — out of bounds at l >= 12); `:24557-24559` `BF_T/BF_D/BF_F`; `bf_load_layer` :24654-24657 (`+ 9` = -eW), :24666-24669 (byte-size asserts at BF_T x BF_D etc.); `bf_entry_shape` :24851; `bf_entry_typing` :24876 (`t(-9, ..)`); `bk_pair_specs` :33053-33054 (nf/nd shapes); `m125_build_statement` :24922; `BkOpts::default` :33702 (layers 12); `bf_export_path` :24544 (`M125_EXPORT_DIR`) | every 8B rung, at load | a `BfModel { layers, t, d, f, e_w, exps: Vec<(i32,i32,i32,i32,i32,i32)>, tag }` read from the export directory (the m8b export writes `NN exps ..` and `NN dims ..` lines into the SAME `digests.txt` the loader already parses — `bf_sidecar` :24599 keys on (layer, name), extra names are inert), selected by `ZK_MODEL_EXPORT_DIR` (else the M125 const path: freeze rows unmoved); thread it through the ~8 functions above | 1-2 d |
| **W-4** HARD | accumulator classes hard-coded to the 125M inner dims: Gacc/Uacc 25 bits, Dacc 26 bits; the honest rows at inner 4096 / 14336 are 27 / 29 (the contract's own §2 rows) — the v4 validator's interval arithmetic REJECTS the statement (the same check that rejects the asymmetric 26-bit row in M125_PASS_REPORT §2), and past it the digit decomposition would panic on out-of-class values (digits.rs "class table guarantees representability") | `bin/ring_matmul.rs:24877` `q(25, true)`, `:24886` `q(26, true)`; consumed by `bg_entry_class` :29051 (l0 13/14 -> must become 14/15) | 1x16 | `acc_bits(inner) = floor(log2(inner * 127^2)) + 2` from the model's d / f (two lines); `bf_matmul_i64`'s i32 fast path (:24755) still holds at 14336 (2.31e8 < 2^31) | 0.2 d |
| **W-2** HARD | the eval-proof PLANNER panics inside its r search: `plan_schedule` tries every r in 2..=64 and `plan_level` / `adaptive_base` ASSERT (instead of declining) when the r = 2 candidate's next witness (2.5 x n_in) exceeds the exact-digit gate — for any group over ~37.7M digit rings, although r = 56-64 is feasible; the weight group of >= 4 layers of the 8B model (44M) trips it | `ring/eval_proof.rs:323-328` (the loop), `:283-284` `assert!(e_ok >= 2, "interior witness too large for a balanced base")`, `:235-238` (adaptive_base's `assert!(gamma_e <= gmax ..)`) | 4x16 and up (3x16 = 33M passes; 1x16 passes) | `plan_level -> Option<LevelPlan>` (None where it asserts today), skip None in the search; schedules identical wherever every candidate was feasible — freeze rows UAGB1-BG-1a/1b pin the 125M schedules both directions and prove it moves nothing at 12x512; add a planner leg at n0 = 44M / 352M (e0 1) and 36M / 73M (e0 2) | 0.5 d |
| **W-1** HARD | the audited K9 packed-table cap 2^25: the claim layer's stacked zero-check tables are 2^(lr + lcp + lambda) K-elements = 2^28 (f-shaped: Had, rq-g/u/h) and 2^26 (d-shaped: rq-d) at 32x512, 2^26 / 2^24 at 32x128 (and 8x512) — over the cap; also 17.2 GB packed per table x 4-5 tables (CPU pool) / x 3.5 (device) | `ring/kfield.rs:283` `K9_MAX_LEAVES = 1 << 25` (audited; :280-284 "raise only with a new integer-bound proof and tests"), `:334` `KTab::words_for` assert "K9 packed-table cap exceeded", `ring/fold.rs:490` `IxfTable::eq` "K9 eq table cap exceeded", `ring/gpu/ixf.rs:725,740` (`n as u32` element counts); the instance builder `bg_zc_prove` :30284 called at :34235 with `n_pos = lr + lcp` (:34208) | 8x512, 32x128, 32x512 (32x16 = 2^23 fits) | split each zero-check instance over its COLUMN space into windows of <= 2^(25 - lr - lambda) columns (2048 at T = 512 / 32 layers -> 7 sub-instances for f = 14336, 2 for d = 4096; 1024 columns = the 12x512 table size keeps the device path inside its 4 GB); each sub-instance is the same instance kind over a column window (`bf_entry_shape` cols -> a col range; the eq_pc factor per window; terminal claims are ClaimContribs over the window — the same product form); k = 1 at 12x512 -> bytes identical; +~3.4 KB per extra instance (~+30 KB at 8B). NOT the smallest: raising the cap to 2^28 (the header's plane bound is stated to hold to 2^28 pair terms, but the audit asks for a proof, u32 counts change, and the tables would still be 17 GB) | 2-3 d |
| **W-3** HARD | the level-0 exact-digit gate (row H-gate-ed): gamma_z = OP_CONC 2^(e0-1) sqrt(n_0 D) must stay <= gamma_max = 2^22.12; the act group (e0 = 2) is capped at 94.2M digit rings and has 145.5M at 32x512 (-0.31 bits) — derive-time panic; the weight group passes at +0.05 bits (Section 1.2) | `ring/eval_proof.rs:312-314` (`assert!(gamma <= gmax, "gamma_z .. exceeds the exact-digit gate (row H-gate-ed)")`, `ring/digits.rs:185-196` (`gamma_max_exact`, `OP_CONC`) | 32x512 only (32x128 +0.69 bits, 32x16 +2.18) | split the ACT commitment group into k >= 2 groups by layer range (k = 4: +0.69 bits, 36M rings each; k = 2: +0.19): `bk_build_groups` :33123 (two groups -> a Vec; the map's `in_weight: bool` :33111 -> a group index), `bk_map_bytes` :33175, h0 :34074-34080 (every u_0 inside), the `[gw, ga]` pairs in `bk_pass_run` (:33993-34010 schedules/precommit, the group proof + verify calls) -> loops over the Vec; E-O2-BB stays one opening PER group; +~185 KB artifact per extra group. Alternatives: the slack constants (PARAMS 3.2/3.4 rows) — an R-row for Victor, not code | 2-3 d |
| **W-6** RULING | the SiLU table family is FROZEN at two members (-3,-3) / (-4,-4): `silu_v2_member` returns None otherwise; `bk_pair_specs` maps every eGate != -3 into the m4 pair; if the 8B calibration names another (eGate, eA) the prover panics "frozen family member" and no valid v4 statement exists | `ring/lookup.rs` (`silu_v2_member` / the frozen bytes + pins), `src/manifest.rs:723` `v4_table_registry() = [v1, m3, m4]` (READ-ONLY per protocol; the duplicated-constant discipline lookup.rs == manifest.rs, freeze row UAGB1-BF-2a), `bin/ring_matmul.rs:33063` (`pid = if e_gate == -3 {0} else {1}`), `:32984` `BK_PAIR_IDS` (two SiLU slots) | first rung, IF the calibrated gate exponent leaves {-3, -4} (Section 4 says why it may) | freeze the new member(s) in lookup.rs AND manifest.rs (both, with UAGB1-BF-1a/2a-style rows; the existing digests do not move), generalize the SiLU pair id to "one pair per distinct member" — Victor's ruling because manifest.rs moves | 0.5 d + ruling |
| **W-7** SOFT/HARD | remainder width band 5..=10 asserted; the 8B shifts (sh = e_out - e_in - eW; eW likely -7..-9, Section 4) may fall in 3..14 | `bin/ring_matmul.rs:33078` (`assert!((5..=10).contains(&w) ..)`), `:32984-33003` (`BK_PAIR_IDS`, aux name tables), `:33058` (`trows`) | first rung, calibration-dependent | widen the statement-derived id space to w = 3..=14 (table rows 2^w; verifier derives the same inventory) | 0.5 d |
| **W-8** HARD (box) | memory as built (no assert; Section 3 has the per-phase picture): (a) `BfLayer` as i64 = 66 GB at 32x512 / 45.8 GB at 32x16 (weights alone 45 GB) and it lives to the end of `bk_pass_run`; (b) the level-0 CRS matrices A_0 = kappa x chunk_0 boxed rings materialized and held in `BgPre` into level 1's transport: 64.4 GB (weight) + 30.4 GB (act) at 8B; (c) the level-1 witness boxed 35 GB (weight); (d) w0 both groups 63.7 GB (i8); (e) the claim tables (W-1); (f) the peak descent pair 1.75U = 120 GB (32x512), 30 GB (32x128), 3.8 GB (32x16) | (a) `:24569-24585` `BfLayer` fields, `bf_entry_values` :24894 (`&[i64]`); (b) `bg_precommit` :29471 (`expand_level_matrix_arc(.., 0, "A", KAPPA_AGG, chunk0, q)`), `BgPre` :29420-29429, `bg_prove_group` :29735 (`prev_a_mat = a0_mat`); (c) `:29721` `w_cur: Vec<Vec<i64>>`; (d) `ring/eval_proof.rs` `DigitCols`; (f) `ring/gkr.rs` PackedTree store | 32x16 on the Mac needs (a) or a >190 GB box; 32x512 on the Mac needs (a)+(b)+(f) or Stage A; the WSL box needs all of them AND streaming (Section 3) | (a) drop `lays` before the group proofs (they read w0 + Phi0Source, not lays) — 66 -> 0 GB during the group phase — or int8/i32 storage per class (9.9 GB); (b) expand A_0 per column block inside the three consumers (`bg_matvec_chunks`, the level-h GEMM stage fill, the level-1 transport) from `expand_level_matrix_raw` :610 — the CRS is seed-expanded, blocks are independent; ~25 s per full 8B expansion [MODEL from 0.5 s at 12x512], paid ~3x; (c) a flat i8/i16 store for the deeper witnesses (`DigitCols` exists); (d) `ZK_W0_REGEN=1` (exists); (f) Stage A of the design memo, or per-pair tree streaming | (a) 0.5 d, (b) 2-3 d, (c) 1-2 d |
| **W-9** SOFT | VRAM: the K9 budget is free - 256 MB (6.8 GB at the rig); depth-25 pairs (state-1 tables 1.25U = 86 GB) and 17 GB ixf tables DECLINE to the CPU path (correct, slow) at 32x512; at 32x16 (depth 20, U 2.1 GB; tables 2^23) both device paths fit | `ring/gpu/k9.rs:1052-1054`, `ring/gpu/ixf.rs` (4 rotating buffers) | 32x128 / 32x512 on the WSL box | none needed for correctness; W-1's 1024-column windows keep ixf on the device; the descents need Stage A or a streamed pair to be GPU-resident at depth 25 | — |
| **W-10** SOFT | conventions: new shape = new statement digest / EVAL-PROOF DIGEST rows; freeze rows UAGB1-BF/BK are 125M-only | `TASK_BOARD.md` §2.3 / §4; `freeze_check_uagb1_bf/bk` | first rung | record 8B rows keyed by (model tag, layers, T, mode); a `freeze_check_m8b` once the Mac export digests are pinned; the model identity digest already binds the export digests (M125_PASS_REPORT §3.3) | 0.2 d |
| **W-11** RUN | data: the checkpoint (14.5 GB bf16 on disk) + a forward pass for X; the WSL box cannot hold a whole 7B bf16 model in RAM | Section 4 | before any rung | the m8b scripts read safetensors per tensor (seek, never the whole shard) and walk the model block by block (< 4 GB RSS), so EITHER box can calibrate/export; the download is a network action that needs Victor's go | — |

Checked and NOT breaking (for the record): the LKP-2 per-tree
ceiling `ceiling_gate_ok` (ring/gkr.rs:1401; asserted per tree at
:33990) is at 44-81% at 32x512 (T = 1024 or a denser packer would
break it); `ixf_layout` (fold.rs:79) gives lambda 5, no pads;
`descent_fold::block_pow` (descent_fold.rs:62) needs T a power of two
(512, 128, 16 all are); `fill_pool_u32` (eval_proof.rs:5800) indexes
value rings as u32 (44M fits); `rows_t_rings_avx2`'s rows < 2^20
guard (:4264) holds (max tensor rows 14336); the T_cap resampling
(:487) and `PSI_MAC_MAX_TERMS` (:3675) are far from their limits;
`bf_floor_requant` (:24627) shift < 63; the v4 class caps CLS_ACC
bits <= 31 (29 needed) and CLS_REM bits <= 16 (<= 14 needed)
(manifest.rs:666-680); no timeouts exist in the rig; the 4096 and
14336 dims are multiples of D = 128 (every `cols % D` fast path in
eval_proof.rs :2300/:2581/:2822/:4115/:5667 stays aligned — the
`no-tail discipline` assert at :165 holds for every entry: T x d, d x
f, f x d, T x f are all multiples of 128 for T >= 1); the K9 eq/table
caps for the MATMUL instances (lk + lambda = 17 / 19 variables) are
fine.

Order of the fixes for the smallest first rung (1x16 on the WSL box,
Section 5): W-5, W-4, W-6/W-7 as the calibration dictates. For 32x16
on the Mac: + W-2, W-8(a). For 32x512: + W-1, W-3, W-8(b)(c) — and
Stage A of the design memo for the descents' 120 GB (or accept it on
the Mac's 256 GB with W-8(a)(b) done: Section 3).

## 3. Memory and time per box

Baselines [MEASURED, PROGRESS_UPERF2 after round 9, WSL-BOX QUIET]:
12x512 8T+GPU 21.0 s (commit 2.5 / prove 15.5 / verify 1.7; prove =
groups 7.1 + descents 6.5 + claim 1.75 + transport 1.4 + CRS 1.3),
RSS 6.7 GB; CPU-only 8T 81.5 s (7.2 / 70.2 / 2.6), RSS 11.1 GB;
12x128 8T+GPU 10.5 s (3.9 GB); 3x16 3.4 s. Every 8B size below is
[COUNTED] (Section 1); every peak and wall is [MODEL] on top of them
(liveness and throughput assumed as stated).

### 3.1 What is resident when (32x512, the components from W-8)

Phase order of `bk_pass_run`: derive chain -> commit w0 -> claim layer
-> descents -> group proofs (levels 0..h, transport). Components:
L = BfLayer i64 66.0 GB (as built lives to the END); W = w0 i8 both
groups 63.7 GB; C = claim zc tables (4-5 x 17.2 GB unfixed; 1.07 GB
windows after W-1); D = peak descent pair 120 GB (nrw-88);
A_w/A_a = level-0 CRS 64.4 / 30.4 GB; V1 = level-1 witness 35.2 (w) +
11.1 (a) GB.

| phase peak (GB) | as built | + W-8(a) (drop L) | + (a)+(b) (stream A_0) | + Stage A (descents replaced) |
|---|---:|---:|---:|---:|
| derive + commit | L+W = 130 | 130 (L alive until groups... (a) drops it after derive: 74) | 74 | 74 |
| claim (W-1 windows) | L+W+C = 135 | 69 | 69 | 69 |
| descents | **L+W+D = 250** | **W+D = 184** | 184 | ~70 [MODEL: Stage A trees gone] |
| group proofs | L+W+A_w+V1 = 229 | **W+A_w+V1 = 163** | ~103 (A_0 in blocks) | ~103 |
| **pass peak** | **~250 — DOES NOT FIT 256 GB** | **~184 — fits the Mac** | **~184 (descents) / 103 (groups)** | **~103** |

[MODEL from COUNTED parts; liveness assumed as the code reads today —
W is alive to the end of the group proofs (`ZK_W0_REGEN=1` trades it
for recompute), L to the end unless (a) drops it.]

Reading: the Mac (256 GB) runs 32x512 with W-8(a) ALONE (~184 GB peak,
28% headroom); (b) is the margin/robustness fix (down to ~103 GB
outside the descents), not a gate. Stage A removes the descent peak
entirely (the design memo's motivation restated in GB). Without (a)
the pass does NOT fit even the Mac.

Per rung on the Mac, same construction [MODEL]:

| rung | as built peak | with (a) | mandatory before it runs (Section 2) |
|---|---:|---:|---|
| 1x16 | ~6 GB | ~4 GB | W-5, W-4 (+W-6/W-7 per calibration) |
| 32x16 | ~191 GB (L 45.8 + W 45.7 + A_w 64.4 + V1 35.2) | **~145 GB** | + W-2 |
| 32x128 | ~205 GB | ~160 GB | + W-1 (2^26 table over the cap) |
| 32x512 | ~250 GB | **~184 GB** | + W-3 (act gate), W-1 |

### 3.2 The WSL box (15 GB + 8 GB VRAM): the dev box, not the MVP box

The weight group alone (w0 45.7 GB, A_0 64.4 GB, V1 35.2 GB) is 3-7x
the box at ANY 32-layer rung: no fix short of full streaming — (a) +
int8/i32 layer store, (d) `ZK_W0_REGEN`, (b) A_0 in column blocks, (c)
flat i8/i16 deep witnesses, W-3-style splitting of BOTH groups into
per-layer-range groups (k ~ 8-16 of 2-4 layers, which also clears the
act gate), and for the descents Stage A is not optional here: the
nrw-88 pair's 120 GB (32x512) / 30 GB (32x128) has no windowed form
as built (W-9: the GPU declines it too). With ALL of that the
streamed peak is plausibly ~8-12 GB [MODEL, coarse — dominated by one
A_0 block + one w0 regen slice + the claim window + level-h pools] at
8T CPU ~1-2 h [MODEL] — a build tranche of its own, NOT the MVP path.
What the WSL box IS for: the 1x16 / 2x16 / 3x16 pre-rungs (Section
1.6: 1.4 GB witness, planner passes at <= 33M rings, both device
paths fit at depth <= 20) — every W-5/W-4/W-6/W-7 fix and the m8b
export format get their first green here, 8T+GPU, in seconds-to-
minutes, before any Mac time is spent.

### 3.3 Honest time projections [MODEL]

Method: each measured 12x512 phase scaled by its counted driver
(commit ~ total n_0 rings x43.7; groups ~ the level-0 h cross-garbage
and level GEMMs x42; descents ~ leaf elements x19.9; claim ~ mm-table
weight reduction x99.6 on its build share + zc rounds x16; transport/
CRS ~ x43; verify ~ verifier MACs x41). Two big unknowns, stated:
(i) the CPU-only per-phase split at 12x512 was not recorded (only the
7.2/70.2/2.6 top split) — the prove-phase scaling is bracketed
[x19.9 .. x43.7]; (ii) Mac CPU throughput at 16-24T vs this box's 8T
is [ASSUMED 1.5-2.5x] (never measured on the proof code; the Mac also
runs F2 training today — a quiesced Mac is part of the RUN task).

| rung, box | commit | prove | verify | total [MODEL] |
|---|---:|---:|---:|---:|
| 1x16, WSL 8T+GPU | ~2.5 s (n_0 x0.98 of 12x512) | ~4-8 s (descents x0.03, groups ~x1, claim small) | ~1.5 s | **~10-15 s** — the pre-rung is CHEAP |
| 32x16, Mac CPU | 7.2 x31.3 / mac | 70.2 x[25-35] x(group share) / mac | ~45-75 s | **~15-30 min** |
| 32x128, Mac CPU | x34.1 | + descents x5.0 | | **~20-40 min** |
| 32x512, Mac CPU | 7.2 x43.7 / mac ~ 2-3.5 min | 70.2 x[19.9-43.7] / mac ~ 12-50 min | ~1-2 min (x41 on 2.6 s) | **~35-75 min; Stage A shaves the descent share -> ~25-55 min** |
| 32x512, the 12x512 reference rig IF the memory existed and the trees fit VRAM (they do not: W-9) | 2.5 x43.7 = 109 s | 298 (groups) + 129 (descents) + ~70 (claim) + 116 (transport+CRS) | ~70 s | **~11-13 min** — the number that says the STREAMING+GPU build (3.2) and Stage A are worth a tranche AFTER the MVP exists |

The MVP-1 headline is therefore an HOURISH-not-minutes Mac number
(~0.5-1.25 h prover, ~1-2 min verifier, 1.94 MB artifact) unless
Stage A lands first; Victor's ruling ("even if the proof currently
takes 1-3 minutes") should be read with this table in hand — the
1-3-minute class at 8B needs the 11-13 min rig column's memory work
plus Stage A plus a ~2-4x kernel/GPU step (lane T's territory), not
just the MVP fixes. The weight group, identical at every T, is
~60-70% of every 32-layer wall in this table: whatever folds or
amortizes the 32 layers' weight commitment (lane T (ii)/(iii)) moves
the 8B clock more than anything else in the design space.

## 4. The data: checkpoint, calibration, export, the m8b scripts

### 4.1 The checkpoint

**Mistral-7B-v0.1** (default): d 4096, f 14336, 32 layers, SwiGLU,
heads 32 / kv 8 (GQA), vocab 32000, rope 10000, bf16, 14.5 GB in two
safetensors shards + index — **Apache-2.0, UNGATED** (no license
acceptance, no HF token). Its FFN shape is IDENTICAL to
Llama-3-8B's — 32 x (3 x 4096 x 14336) — which is what the statement
proves; the honest words for the headline are "the 8B FFN shape, real
Mistral-7B weights" (7.24B params). **Llama-3.1-8B** (Victor's call):
same FFN dims AND the same HF tensor naming, so the scripts run
unchanged — but gated (Meta license acceptance + HF token). Default is
Mistral unless Victor prefers the Llama name on the headline.

Calibration data: a **FineWeb-Edu sample retokenized with the model's
own tokenizer** (the m125 val shard is SmolLM2-tokenized, vocab 49152
— wrong ids for a 32000-vocab model; FineWeb-Edu itself is the same
distribution the 125M calibrated on). The window sampler is the m125
construction VERBATIM (seed 1337, sorted disjoint aligned windows of
T+1; first 8 calibration, next 8 held-out; the export's X window =
the FIRST held-out window).

### 4.2 The scripts (NEW files; the m125 scripts are imported, never edited)

**`scripts/m8b_int8_calibration.py`** — the m125 calibration study
generalized to checkpoints that do not fit RAM:
- safetensors read **PER TENSOR** (seek to the data_offsets window,
  read exactly those bytes; bf16 widened exactly), sharded index
  resolved; the model walked **BLOCK BY BLOCK** (one layer's weights
  resident, then freed) — peak RSS at the 7B shape < 4 GB by
  construction, **1.11 GB [MEASURED WSL-BOX] at the 125M shape**, so
  EITHER box can run it (the 7B download is the Mac's, Section 5);
- the reference forward is a **numpy fp32 re-implementation** of the
  standard pre-norm decoder (RMSNorm, RoPE rotate-half, GQA, SwiGLU)
  with two arch adapters: `--arch hf` (Mistral/Llama naming,
  config.json-driven) and `--arch frugal` (the 125M — the validation
  oracle, 4.3);
- the int8 simulation carries exact integers in float64 BLAS (every
  |acc| <= f x 127^2 = 2.31e8 << 2^53: exact in any summation order;
  numpy int64 matmul has no BLAS path and would be ~50x slower);
- the SiLU table is the **FROZEN v2 family formula** (round_half_up,
  via m125_export_ffn's pinned generator) in the simulation too — the
  m125 study simulated with np.round; the m8b verdict is for the exact
  table the prover uses. New (eGate, eA) members are FLAGGED with
  their digests (the W-6 ruling input), not asserted away;
- per-tensor weight exponents eWg/eWu/eWd per layer (m125 asserted a
  uniform -9; the 7B is not assumed to oblige); variant A (the
  statement's floor semantics) + weights-only attribution; `--variants`
  adds round-to-nearest; JSON out with the SAME calibration-row keys
  as the m125 JSON (either JSON drives the export).

**`scripts/m8b_export_ffn.py`** — the witness export in the EXACT rig
layout (`bf_export_path` / `bf_sidecar` / `bf_load_layer`,
ring_matmul.rs :24544/:24599/:24647):
- `layerNN_X.bin` (T x d), `layerNN_WgT.bin` (d x f), `WuT` (d x f),
  `WdT` (f x d), int8 row-major; `digests.txt` with the m125 lines
  (`NN X|WgT|WuT|WdT|z <sha256>`, `NN shifts g u h z`) **plus the W-5
  loader's rows** (`00 model`, `00 dims T d f layers`,
  `NN exps eX eGate eA eUp eH eZ eWg eWu eWd`) — verified inert to
  today's parser (bf_sidecar keys on (layer, name)); `manifest.json`
  adds shapes, per-tensor digests, acc maxima, **checkpoint shard
  sha256s** (the model-identity input for the W-10 freeze rows);
- X is the QUANTIZED end-to-end model's own mlp_norm output (variant
  A feeds z forward — the m125 lesson: a fp-walk X is a hybrid that
  neither calibrates nor is claimed); the chain **re-reads the int8
  weight BYTES just written to disk**, so the digests bind the very
  tensors the chain used; 0 range-fact violations asserted;
- flags at run time: new SiLU members (W-6), shifts outside the rig's
  asserted 5..=10 remainder band (W-7), negative shifts (a
  calibration the contract chain cannot express — hard error);
- `--weights-only` re-derives the 96 weight digests from a checkpoint
  and compares to an existing manifest (the freeze-side check);
  streamed like everything else.

**`scripts/m8b_verify_125m.py`** — the validation harness (4.3), run
green on this box before any Mac time is spent.

### 4.3 What was validated HERE, and exactly what was not

`python3 scripts/m8b_verify_125m.py` — **12/12 checks PASS
[MEASURED WSL-BOX 2026-08-23]**, evidence in results/m8b_test/:
1. **reader**: the streaming seek-reader reproduces the m125
   whole-file reader on all 110 tensors of the real 125M checkpoint,
   byte-equal as fp32.
2. **synth**: a synthetic SHARDED HF-format checkpoint (2 shards +
   index.json, BF16, Mistral naming, GQA untied head) runs the full
   hf pipeline calibration -> export; digests.txt carries the rig rows
   + the W-5 model/dims/exps rows; bin sizes are the rig's T*d / d*f /
   f*d int8.
3. **export** (the byte-identity test the resume brief asked for):
   m8b_export_ffn --arch frugal on the REAL 125M checkpoint with the
   COMMITTED m125 calibration JSON — **all 36 weight digests
   BYTE-IDENTICAL to results/m125_ffn_export_wsl (= the Mac export
   for weights), all 12 shifts lines identical, 0 range-fact
   violations**. The X/z digests differ from the mlx reference as
   EXPECTED: layer-0 X differs in 2 of 393,216 elements (max delta 1
   — the attention/norm conventions are right), later layers amplify
   through the quantized residual chain to ~50-60% of elements at
   max |delta| <= 9 int8 steps — the same mechanism as the documented
   Mac-mlx-vs-WSL-mlx delta, larger seed. A valid honest witness of
   the same statement class; **whichever machine runs the 7B export
   is the digest authority** (the Mac, once — W-10 pins those).
4. **cal**: m8b_int8_calibration --arch frugal on the real 125M —
   **all 108 calibrated exponents equal the committed m125 table; the
   bf16 reference val loss reproduces to 4 decimals (3.2287 vs
   3.2287)** — the strongest single fact here: the numpy walk
   (embedding, RoPE, GQA, RMSNorm, SwiGLU, loss) is numerically
   faithful to the mlx model end to end; variant A: 0 violations,
   loss delta +4.9717 vs the study's +4.9807 (the frozen-table vs
   np.round difference, documented).

**NOT exercised here** (honest list): (i) a real 7B checkpoint — the
sharded-index + hf-naming path ran only on the synthetic checkpoint;
(ii) the hf attention against a reference implementation — validated
TRANSITIVELY (the identical walk code reproduces the 125M mlx model
exactly; the hf adapter differs only in naming, config parsing, and
the untied head, all exercised synthetically), plus the RUN task's
greedy-decode sanity ("The capital of France is" must complete
" Paris") on the Mac before anything else; (iii) the tokenizer paths
(`tokenizers`/`sentencepiece`) — no tokenizer.json exists on this
box; the RUN task's decode step exercises them first and cheaply;
(iv) Mac RSS at the true 7B shape — < 4 GB by construction (largest
single resident: one fp32 layer ~0.9 GB + one f64 widening ~0.5 GB +
batch activations ~1.2 GB), to be CONFIRMED by the script's printed
peak-RSS line in the RUN task.

### 4.4 The exponent picture the 7B will produce [ASSUMED until the Mac calibration lands]

The 125M calibrated to eW -9 uniform, eX -3..-2, eGate/eA -3 and -4,
shifts 5..10. A 7B trained model has (a) smaller per-weight magnitudes
(wider layers) but (b) the famous activation OUTLIER channels at this
scale — eX may sit at 0..+2 on some layers, and eGate/eA may leave
{-3, -4}: that is exactly W-6 (a new frozen family member — Victor
ruling, manifest.rs moves) and possibly W-7 (shift outside 5..=10).
The calibration JSON + the script's W-6/W-7 flag lines are the FIRST
artifact to read when T12 completes; the W-6/W-7 code work (0.5 d
each) is scheduled AFTER that read, not speculatively (Section 5).
If variant A's range facts do NOT hold at 7B (outliers), the
model-side branch is per-channel/clipped calibration — a statement
design choice to bring to Victor with the measured violation table,
NOT a proof-system change (the m125 study's risk-5 branch, unchanged).

## 5. The plan (lanes, files, gates) + the Grok RUN task text

### 5.1 The order (smallest rung first; sizes are Section 2's [ASSUMED] lane-days)

**M0 = T12 (Grok, Mac, RUN — the task text is 5.2; needs Victor's
go).** The data first, because its outputs (the exponent table, the
W-6/W-7 flags, the violation count) decide two of the code items and
nothing in it blocks on code. Runs alongside F2 (correctness, < 4 GB
RSS, no timing).

**M1 (WSL, CODE, 1-2 d) — W-5**: the `BfModel` loader (dims/exps read
from the export's digests.txt, selected by `ZK_MODEL_EXPORT_DIR`; the
M125 const path untouched otherwise) **+ W-4** (acc classes from
d/f). Gates: default-path bytes identical (freeze rows, diff-battery);
the SYNTHETIC export in results/m8b_test/synth_export is the loader
fixture (any-dims, already on disk here); a battery leg.

**M2 (WSL, CODE, 0.5 d) — W-2**: `plan_level -> Option`, skip
infeasible r candidates; planner legs at n0 = 44M/352M (e0 1),
36M/73M (e0 2). Gate: freeze rows UAGB1-BG-1a/1b identical (the 125M
schedules move nothing).

**M3 (WSL + Mac, RUN) — the 1x16 pre-rung, THE first real-8B-weights
proof**: sync layer 0 of the Mac export (~180 MB: 4 bins +
digests.txt + manifest — same channel as the 125M tarball, Victor's
call), run the rig at 1x16 (and 3x16) on the WSL box 8T+GPU. Gates:
the Rust chain digests match the Mac manifest (X/W byte-pinned, z
re-derived equal); statement accepted, proved, verified (~10-15 s
[MODEL]); artifact counted vs Section 1.6 (850,159 B at 1x16).

**M4 (per the T12 calibration) — W-6/W-7**: IF flagged — the W-6
freeze ruling request to Victor (new SiLU member digests in both
lookup.rs and manifest.rs, UAGB1-BF-style rows), the W-7 width-band
widening (0.5 d each). Not started speculatively.

**M5 (WSL, CODE, 2-3 d) — W-1**: zero-check column windows (<= 2^25
K-elements per sub-instance). Gate: k = 1 at 12x512 -> bytes
IDENTICAL (freeze rows); battery at split shapes; the device ixf path
stays under 4 GB via 1024-column windows.

**M6 (WSL, CODE, 2-3 d) — W-3**: the act commitment group split by
layer ranges (k = 2 first, k = 4 if the gate headroom says so).
Gate: batteries both routings; the +~185 KB/group artifact delta
counted and recorded.

**M7 (WSL, CODE, 0.5-1 d) — W-8(a)+(d)** (drop `lays` before the
group proofs; `ZK_W0_REGEN` defaulted for 32-layer rungs) **+ W-10**
(a `freeze_check_m8b` scaffold keyed by (model tag, layers, T, mode),
pinned once the Mac digests exist).

**M8 (Mac, RUN) — the ladder**: 32x16 yardstick (needs M1+M2; M7
recommended — ~145 GB peak [MODEL]; walls recorded honestly with
[MAC-BOX nT NOISY-SHARED] if F2 still runs, a QUIET window only for
the headline numbers), then 32x128 (needs M5), then **32x512 =
MVP-1** (needs M5+M6; W-8(b) only if the real headroom demands it).
MVP-1 acceptance: the TARGET_CONTRACT FFN statement at 32x512 with
the real Mistral weights proved AND verified end to end on the Mac,
digests pinned (W-10 rows), artifact bytes counted (~1.94 MB,
Section 1.5), prover/verifier walls recorded with labels. Stage A
(lane S) arrives as protocol v-next alongside, never as an edit of
the frozen pass.

**What needs Victor** (consolidated): (1) the T12 go-ahead — network
download on the Mac (~17 GB: 14.5 ckpt + 2.2 data) + ~30 GB disk; no
license/token for Mistral-7B-v0.1; (2) the checkpoint-name call —
Mistral-7B-v0.1 (default, ungated) vs Llama-3.1-8B (identical FFN
dims and naming, gated: Meta license + HF token); (3) the W-6 ruling
IF the calibration flags a new SiLU member (manifest.rs moves); (4)
the export-slice transport Mac -> WSL for M3; (5) Mac windows for M8
(the 32-layer rungs want ~145-184 GB RSS and, for headline timings
only, a quiesced box — F2 coexistence is Victor's call).

### 5.2 T12 — the Grok RUN task (verbatim, for TASK_BOARD §3)

### T12 — the 8B FFN calibration + export on the Mac  `OPEN (scripts on the lane-R branch/main)`  WHO: MAC  KIND: RUN
WHY: MVP-1 (PROGRESS_UPERF3.md) proves the 8B FFN shape with REAL
int8-calibrated weights; this produces the witness in the rig's
layout. Gates M3/M8. Needs Victor's go for the download (~17 GB
network, ~30 GB disk). RAM < 4 GB RSS (streamed) — F2 training may
keep running; nothing here is timed.
PREREQS (one-time): a python3 with numpy;
`pip install huggingface_hub tokenizers pyarrow` (network — part of
the same go-ahead). All commands from the repo root.
STEPS:
1. Download Mistral-7B-v0.1 (Apache-2.0, UNGATED — no token; ~14.5 GB):
   `python3 -c "import os; from huggingface_hub import snapshot_download; snapshot_download('mistralai/Mistral-7B-v0.1', local_dir=os.path.expanduser('~/models/Mistral-7B-v0.1'), allow_patterns=['*.safetensors','*.json','tokenizer.model'])"`
   Check: `~/models/Mistral-7B-v0.1/` has model-00001/2-of-00002.safetensors,
   model.safetensors.index.json, config.json, tokenizer.json.
2. FineWeb-Edu sample (one parquet ~2.2 GB) and a text file from it:
   `python3 -c "import os; from huggingface_hub import hf_hub_download; print(hf_hub_download('HuggingFaceFW/fineweb-edu', 'sample/10BT/000_00000.parquet', repo_type='dataset', local_dir=os.path.expanduser('~/models/fineweb-edu')))"`
   then extract the first 4000 documents as text (paste as one block):
   ```
   python3 - <<'EOF'
   import os
   import pyarrow.parquet as pq
   pf = pq.ParquetFile(os.path.expanduser(
       "~/models/fineweb-edu/sample/10BT/000_00000.parquet"))
   out = open(os.path.expanduser(
       "~/models/fineweb-edu/sample_text.txt"), "w")
   n = 0
   for b in pf.iter_batches(columns=["text"], batch_size=256):
       for s in b.column(0).to_pylist():
           out.write(s + "\n\n")
           n += 1
       if n >= 4000:
           break
   out.close()
   print(n, "docs")
   EOF
   ```
   (~10-20 MB of text, ~2-5M tokens — the sampler needs >= ~20k.)
3. Forward sanity BEFORE anything long (~2-5 min):
   `python3 scripts/m8b_int8_calibration.py --ckpt ~/models/Mistral-7B-v0.1 --decode "The chemical symbol for gold is"`
   ACCEPT: the completion contains " Au". If not: STOP, paste the
   output (that is a bug report on the hf adapter, not a data problem).
   (GATE REVISED 2026-08-24 [WSL-BOX]: the original France prompt is a
   FALSE FAIL in exact fp32 — " Paris" lands rank 3, 0.85 logits
   behind "a"; the " Paris" lore is bf16 arithmetic. The adapter was
   validated instead by next-token rank on five factual prompts:
   " Au" / " oxygen" / " Shakespeare" / "4" at rank 0, "J"(upiter)
   rank 1 gap 0.03 — grounding this sharp rules out a RoPE/GQA/mask
   bug. The gold prompt's rank-0 margin makes it a stable greedy
   gate.)
4. Calibration (~20-45 min [MODEL], < 4 GB RSS — the script prints
   its peak at the end):
   `python3 scripts/m8b_int8_calibration.py --ckpt ~/models/Mistral-7B-v0.1 --text ~/models/fineweb-edu/sample_text.txt`
   PASTE into the log: the per-layer exponent table, every
   `silu-int8-table-v2 member` line (W-6 flags), the variant-A
   violation count and loss delta, the VERDICT block, peak RSS.
   COMMIT: results/m8b_int8_calibration.json.
5. Export (~10-25 min [MODEL]; writes ~5.7 GB of .bin, gitignored):
   `python3 scripts/m8b_export_ffn.py --ckpt ~/models/Mistral-7B-v0.1 --text ~/models/fineweb-edu/sample_text.txt`
   ACCEPT: "range-fact violations across the pass: 0" and no
   `** remainder widths outside ... **` surprise (if either fails:
   STOP, paste — that is the W-6/W-7/model-side branch, Victor reads
   it before anything else happens).
   COMMIT: results/m8b_ffn_export/digests.txt + manifest.json (+ the
   .gitignore the script wrote). The .bin files stay on the Mac.
6. Re-derivation check (~5-10 min): 
   `python3 scripts/m8b_export_ffn.py --ckpt ~/models/Mistral-7B-v0.1 --weights-only`
   ACCEPT: "96/96 weight digests match the manifest".
7. The rig does NOT run yet: the 32x16 rung is GATED on M1+M2 (W-5/
   W-4/W-2 — the rig is hard-coded to the 125M shape today and will
   panic). When M1 lands, the board gets the exact command (shape:
   `ZK_MODEL_EXPORT_DIR=results/m8b_ffn_export ring_matmul uperf-pc full-profile 32 16`
   — the final arm name comes with M1).
8. For M3: keep `layer00_*.bin` handy for the WSL sync (~180 MB).
ACCEPT (whole task): steps 3-6 green; the JSON + manifest + digests
committed; the paste in the log.
RECORD: TASK_BOARD §4 + a PROGRESS_UPERF3.md log line ("T12 done:
eW range …, silu members …, violations 0/…, RSS … GB").

### 5.3 Files this lane added (for the record)

`docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md` (this memo),
`scripts/m8b_scaling_model.py` (Section 1's counter, `--check` green
vs the rig), `scripts/m8b_int8_calibration.py`,
`scripts/m8b_export_ffn.py`, `scripts/m8b_verify_125m.py` (12/12
PASS on this box), `results/m8b_test/` (evidence: the 125M reexport
digests + manifest). The m125 scripts, the rig, the manifest, the
task board: untouched.
