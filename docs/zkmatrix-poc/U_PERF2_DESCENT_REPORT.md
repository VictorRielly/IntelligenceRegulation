# U-PERF2 lane A — the descents (masked fractional-GKR prove) on synthetic packed trees

Branch `uperf2-a` (worktree /home/victor/wt-uperf2-a), opened at c46483a
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane A — DESCENTS" + "Agent A
status". Box: the WSL box (Intel Core Ultra 9 185H — 6 P + 8 E + 2 LP-E
cores presented to WSL as 11 x 2 threads, 15 GB, no m125 export). Every
number carries a label: `[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`.
NOISY-SHARED = lane C was building or running its batteries at the same
time (it was, for every run below — the load stayed at 1.1-1.4; the 1T
numbers moved by < 5% between repeats, the 8T ones by ~10%).

## 0. One paragraph

The masked descent (`masked_gkr_prove`) was profiled for the first time
at real depth on synthetic packed trees that mirror `bk_pass_run`'s
descent phase (aligned blinded witness trees + neutral pads + the masked
table side), and three transcript-identical changes landed behind
`ring::eval_proof::oracle_mode()` with the pre-change bodies kept as
`*_ref`: (1) a five-table round kernel that carries PL := p0 +
lambda*q0 instead of p0 and lambda*q0 (one MAC less per node, one fold
less per round, one table less of memory); (2) deterministic
`ZK_THREADS` parallelism over independent block ranges in every packed
kernel of the descent (round kernel with per-chunk exact-integer lazy
planes summed in index order, out-of-place scratch folds, eq build,
extraction, tree steps, pack) — bit-identical for any thread count by
construction and by battery; (3) neutral pad instances are never
materialized nor computed — a compact `FracTree::Neutral` and a closed
form for the pads' share of every round-polynomial node. At the largest
shape this box admits (depth 20 x 8 instances, 5 real + 3 pads, 8.4M
witness leaf elements) `masked_gkr_prove` goes **15.72 s -> 7.59 s at
1T (2.07x) -> 2.2-2.4 s at 8T (6.6-7.2x)** with the descent digest
identical at every step and every thread count, and the bench's peak RSS
falls 3.6 GB -> 2.4 GB [WSL-BOX NOISY-SHARED; a back-to-back repeat at
HEAD under a busier box gave 18.16 -> 9.66 -> 2.51 s, the same ratios].
The whole tree-build + prove wall of the pair goes 23.2 s -> 13.4 s (1T)
-> 5.4 s (8T) in that repeat. The
rig's shape (depth 21-22 x up to 16, ~218M leaf elements by the pair
table) does NOT fit this box; extrapolating linearly in real leaf
elements the rig's witness-descent prove is ~410 s -> ~250 s (1T) ->
~70 s (8T) at this box's rates, before the Mac's own core speed and
thread scaling are measured (TASK_BOARD T1). What did not land: the
caller-side boxed-leaf churn of `aligned_witness_tree`/`neutral_tree`
(descent_fold.rs, not this lane's file) — now the largest term of the
tree phase at 8T — for which the drop-in builders `gkr::build_tree_sparse`
and `gkr::build_neutral_tree` are provided; and the fold-into-next-round
fusion (memory traffic), left as a design note.

## 1. The bench (`uperf-a descent-bench <depth> <l> [n_real] [dt] [noverify]`)

Mirrors one pair of `bk_pass_run`'s descent phase at fixed test seeds
(`XofReader "uperf2-a-leaves"`, `ProverRng::from_test_seed
"uperf2-a-masks"`, transcript `"uperf2-a-descent"`):
alpha from the transcript; `n_real` aligned blinded witness trees
(`descent_fold::aligned_witness_tree` with two synthetic members per
tree at bases 0 and n/2 — footprint 2^(depth-2) each, 768-wide rows once
the footprint allows, uniform K-element leaves) plus `l - n_real`
`neutral_tree` pads; `draw_masks(depth, e_bits)`; `masked_gkr_prove`;
then the table side (`blinded_table_tree` at `dt` with 2^(dt-1) fused
rows and multiplicities, pads, masks, prove); optionally
`masked_gkr_verify` of both with pins on a fresh transcript (state
equality asserted). Prints wall (tree build excluding the synthetic leaf
generation), the a.* attribution (observation-only `prof::timer`
phases: a.tree-pack, a.tree-step, a.eq-table, a.extract, a.round-g,
a.fold, a.scalar-tail, a.gkr-prove, a.gkr-verify; a.glue = prove minus
the sum), `[UPERF2-A] DESCENT DIGEST` = SHA-256 over both
MaskedDescentProofs + both DescentEnds + the final transcript state, and
peak RSS (VmHWM). `ZK_UPERF_ORACLE=1` runs the same bench on the
pre-change path (one-binary A/B).

## 2. Attribution at depth 20 x 8 (5 real, 3 pads; 8.4M witness leaf elements) — the pre-change path

`ZK_UPERF_ORACLE=1 ring_matmul uperf-a descent-bench 20 8 5 9`
[WSL-BOX 1T, NOISY-SHARED], digest 47a58a27..dafefb:

| phase | seconds | share of prove |
|---|---:|---:|
| a.round-g (bulk round-poly kernel, all rounds, both sides) | 7.16 | 46% |
| a.fold (six folds per round) | 4.74 | 30% |
| a.extract (child tables + lambda*q0) | 2.37 | 15% |
| a.eq-table (joint doubling per layer) | 1.45 | 9% |
| a.scalar-tail + glue (sub-block rounds, w-rounds, transcript, masks) | 0.01 | < 0.1% |
| **masked_gkr_prove** (witness + table side) | **15.72** | 100% (1,874 ns per leaf element) |
| trees (aligned/neutral/table builds: pack 0.44 + steps 2.19 + the callers' boxed-leaf alloc/fill/drop ~1.3) | 3.92 (repeat at HEAD, leaf generation excluded) | |
| masked_gkr_verify (both sides) | 0.004 | |
| wall (trees + prove + verify) | 20.47 | |

Repeat of the same run at HEAD under a busier box (load 2.4-2.9, lane
C's heavy legs): prove 18.16 s (round-g 8.60, fold 5.59, extract 2.23,
eq 1.72) — the +15% is the noise band of this shared box; every ratio
below reproduces within it.

Peak RSS 3,589 MiB: 8 packed trees at depth 20 (256 MB each incl. the
pads) + six work tables of 4M elements (256 MB each) at the last layer +
the transient boxed leaves of the tree being built. This is TASK_BOARD
T9's descent-tree memory question in numbers: at the rig the same
accounting is 16 trees x 1 GB + 6 x 2 GB at nrw-88, i.e. the pass peak
IS the descent phase.

## 3. Optimizations, one line each (before / after, byte-identical)

All at depth 20 x 8 (5 real, 3 pads), `masked_gkr_prove` seconds,
[WSL-BOX NOISY-SHARED]; the digest 47a58a27..dafefb is identical on
every line; the battery (Section 6) proves the identity three ways.

| item | before | after | speedup | evidence |
|---|---:|---:|---:|---|
| (a) five-table round kernel PL := p0 + lambda*q0 (`round_g5_body`, `mul_fixed_add`, boundary p0 = PL - lambda*Q0) + block-copy extract | 1T 15.72 (round-g 7.16, fold 4.74, extract 2.37) | 1T 12.82 (round-g 5.85, fold 3.78, extract 1.76) | 1.23x | oracle vs fast, same binary |
| (b) deterministic ZK_THREADS splits (round kernel per-chunk planes, scratch folds, eq doubling, extract, tree steps, pack) | 1T 12.82 | 8T 3.37 | 3.8x (a+b: 4.7x) | digest identical at 1/2/4/6/8/12/16/22 threads |
| (c) neutral pads skipped analytically (`FracTree::Neutral`, real-range kernels, closed-form pad term, eq as b-part x E(e) per real slice) | 1T 12.82 / 8T 3.37 | 1T 7.59 / 8T 2.17-2.38 | 1.69x / 1.5x (a+b+c: 2.07x at 1T, 6.6-7.2x at 8T) | digest identical; peak RSS 3,589 -> 2,419 MiB |
| (d) sparse packed builders for `blinded_witness_tree`/`blinded_table_tree` (no boxed leaf pair) + deferred boxed-leaf drop in `build_tree` at threads > 1 | trees 8T 1.69 | trees 8T 1.54 | — | tree phase; the rig's witness trees come from `aligned_witness_tree` (not this lane's file — Section 7) |
| ALL, one binary at HEAD, back-to-back under the busier box (load 2.4-2.9) | prove 18.16 / trees 3.92 / wall 23.2 (oracle 1T) | prove 9.66 / trees 2.68 / wall 13.4 (fast 1T); prove 2.51 / trees 1.68 / wall 5.4 (fast 8T) | 1.88x at 1T, 7.2x at 8T (wall 1.7x / 4.3x) | digest 47a58a27..dafefb on all three |

Smaller shapes, prove seconds [WSL-BOX NOISY-SHARED], digests identical:
depth 18 x 4 (3 real): oracle 1.83 -> fast 1T 1.08 -> 8T ~0.30;
depth 19 x 4 (3 real): oracle 3.86 -> fast(a+b) 1T 3.28 -> 8T 0.80.

Why the 1T gain of (a) is 18-20% and not the 25% MAC count suggests: the
round kernel's per-node cost is two products + one deferred reduction
(`red_block`, ~25% of the node) + the eq MAC; the reduction and the
extrapolation adds do not shrink. The fold gain (6 -> 5 tables) shows as
20%.

## 4. Thread scaling (depth 20 x 8, fast path, `masked_gkr_prove` seconds) [WSL-BOX NOISY-SHARED]

| ZK_THREADS | 1 | 2 | 4 | 6 | 8 | 12 | 16 | 22 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| prove | 7.70 | 5.13 | 2.85 | 2.46 | 2.38 | 2.62 | 2.50 | 2.71 |
| a.round-g | 3.74 | 2.36 | 1.27 | 1.03 | 0.97 | 1.01 | 0.93 | 1.03 |
| a.fold | 2.39 | 1.56 | 0.95 | 0.88 | 0.91 | 1.06 | 1.05 | 1.19 |
| a.extract | 0.93 | 0.78 | 0.37 | 0.32 | 0.29 | 0.30 | 0.29 | 0.26 |
| a.eq-table | 0.62 | 0.41 | 0.24 | 0.20 | 0.18 | 0.22 | 0.20 | 0.20 |
| a.tree-step | 1.06 | 0.69 | 0.44 | 0.36 | 0.33 | 0.32 | 0.32 | 0.33 |

The digest is identical on every column. Scaling saturates at 6-8
threads at ~3.2-4x (round-g 4.0x, fold 2.7x) on this hybrid, virtualized
box: the round kernel is compute-bound at 1T (~0.6 cycles per 32x32 MAC
in the AVX2 lane loop, ~1,200 cycles per pair-term-block), the folds are
closer to memory-bound (each fold streams 1.5 x table bytes per round),
and WSL's flattened topology puts threads on E-cores/HT siblings past ~6.
The Mac's uniform performance cores measured 8.7-9.1x on the commit
kernel (PROGRESS_UPERF); the descent kernels are the same class of work,
so the Mac number is the expectation, not this box's ceiling — to be
measured by TASK_BOARD T1 with `ZK_THREADS`.

## 5. Extrapolation to the rig (depth 21-22, l up to 16)

The rig's shape does not fit this box (a single depth-22 x 16 pair
holds 16 GB of packed trees + 12 GB of work tables on the pre-change
path); this is a LINEAR extrapolation in leaf elements from the depth
20 x 8 rates and says so. Leaf-element count from
UAGB1_TABLE_DESCENT_REPORT Section 1.1's pair table:
sum over pairs of l x 2^depth = (8+1+16+2+4+4+8+4) x 2^22 + (8+2) x 2^21
= 218.1M, of which REAL trees (61) = 37 x 2^22 + 8 x 2^21 = 172.0M and
pads (11) = 46.1M. (The brief's "~208M" is the same table counted
slightly differently; the ratios below do not depend on it.)

| | rate at depth 20 x 8 | rig witness-descent prove |
|---|---|---:|
| pre-change, 1T | 1,874 ns per leaf element (all 218.1M) | ~409 s |
| fast (a+b+c), 1T | 1,448 ns per REAL leaf element (172.0M; pads are O(1)) | ~249 s |
| fast, 8T on this box | 414 ns per real leaf element | ~71 s |
| fast, Mac at ~9x (expectation, unmeasured) | | ~28 s |

The ledger's "~630 s" for the descents on the Mac at 1T covers trees +
both sides + the Mac's own core speed; the pre-change ~409 s here is
the witness prove alone, so the box rates are consistent with it.
Table-side descents (dt 6-11) are < 1% of a pair here and are ignored.
Memory at the rig: the 11 pads are no longer materialized (-10 x 1 GB
- 2 x 0.5 GB of packed layers) and their slices of the work tables stay
unmapped (zero pages never touched): the peak pair (nrw-88, 16 trees, 12
real) goes from 16 + 12 = 28 GB to 12 + ~9 = ~21 GB of descent-phase
footprint. The deferred boxed-leaf drop at threads > 1 adds up to one
boxed pair (~1.4 GB at depth 22) of transient overlap per tree build.

## 6. Battery + gates

`uperf-a descent-battery`: 9 shapes x {masked, zero masks} = 18 legs
(depths 4/8/10/12/13/14, l 1/2/4/8/16, with pads 0-5), each proven THREE
ways in one process — `KField::harness_scalar` (the boxed U-K9 oracle),
the packed field under `set_oracle_mode(true)` (the pre-change bulk
path), the packed field on the fast path — digests identical and every
proof verified with pins; the BATTERY DIGEST
f936ff790966b563607bac218e5852365f024a6ddb54e0d2ea8b91c16e9e32e0 is
identical at ZK_THREADS 1, 2 and 7 (three runs). Gates at HEAD on this
box: `self-test` (incl. the [U-K9] battery) green; `bh-verifier battery`
green (17.4 s); `uperf-pc diff-battery` green (O1 4/4, O2 35/35, O3 63/63,
O5 12/12, E2E 2/2; 21.5 s); `freeze-check` 98 `ok` rows identical to the
pre-change capture (full pre-panic text identical), then the expected
UAGB1-BF panic (no m125 export on this box).

## 7. What is left (in the order of the remaining share)

1. Caller-side tree churn (descent_fold.rs — NOT this lane's file):
   `aligned_witness_tree` and `neutral_tree` allocate 2 x 2^depth boxed
   `Vec<u64>` leaves per tree before `build_tree` packs/scans them. At
   8T that is now the largest single term of the pair (trees 1.5 s of
   4.8 s wall at depth 20 x 8; ~0.2 s per real tree and ~0.15 s per pad
   at depth 20; x4 at depth 22, x72 trees at the rig = ~1 minute).
   Drop-ins are in gkr.rs: `build_tree_sparse(kf, n, default, entries)`
   (aligned leaves as (index, p, q) entries — same leaf sequence,
   bit-identical tree) and `build_neutral_tree(kf, depth)` (the compact
   pad; no allocation at all). One-line changes for the file's owner.
2. Fold-into-next-round fusion: per table per round the fast path
   streams 2.5 x table bytes (kernel read S, fold read S + write S/2);
   folding round t's tables on the fly inside round t+1's kernel pass
   (and writing the folded blocks as a side effect) is 1.5 x — a 40%
   traffic cut on the memory-bound share (the folds scale 2.7x at 8T
   here vs 4x for the compute-bound round kernel). Same arithmetic,
   identical values; needs the previous round's r inside the kernel
   and the t == 0 masked add-constants folded into the on-the-fly
   values. Not attempted (a box that cannot show its value cleanly).
3. Extract fusion into round 0 (read the tree layers with a 4-way
   deinterleave instead of materializing p0/p1/q0/q1): -0.95 s of 7.6
   at 1T here (12%).
4. Thread scaling past 6-8 on the Mac's cores — measure (T1); the
   kernels split any range deterministically, no code change needed.
5. The verifier: `masked_gkr_verify` costs 3-5 ms per pair here (all
   shapes); the ledger's "~36 s descents verify" on the rig must sit in
   the pair-claim builders / eq tables around it, not in the descent
   verify itself — untouched.
6. GPU rung: the round kernel is a fixed-shape 16x16-coefficient x 8-lane
   MAC with one deferred reduction per node — the natural first GPU
   kernel of the descent; the CPU-side chunking (independent block
   ranges, exact-integer partial planes) is the same decomposition.
