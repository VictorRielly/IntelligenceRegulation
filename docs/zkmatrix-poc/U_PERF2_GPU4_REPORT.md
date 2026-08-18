# U-PERF2 lane P — THE GPU RUNG, step 4: the descent kernels + the per-round floor

Branch `uperf2-p` (worktree /home/victor/wt-uperf2-p), opened at 151edc9 (=
main after round 8) on 2026-08-18. Ledger: PROGRESS_UPERF2.md "Round 9 ...
Lane P" + "Agent P status". This continues lane L's GPU step 2
(U_PERF2_GPU2_REPORT.md: the fused round / ixf chains on the device, Section
5.2 = the kernel levers) and lane N's GPU step 3 (U_PERF2_GPU3_REPORT.md: the
device tree store, Section 5 = what was left: the kernels, the eq uploads /
per-round floor, the build's step kernel). Hardware as lane L's report states
it (RTX 4070 Laptop, 8,188 MiB, sm_89, WSL2, a 55-70 W-class mobile part;
host Core Ultra 9 185H, 15 GB). Every number carries [MEASURED] / [ASSUMED] /
[MODEL] and a [WSL-BOX NT QUIET|NOISY-SHARED] label — lane Q worked
concurrently in /home/victor/wt-uperf2-q the whole session (load 1.3-3.1
during my rigs), so every wall below is NOISY-SHARED unless marked; the rig
rows are read against the untouched phases (prove-group, commit, claim
layer, CRS: all within +5% of the baseline capture in the same runs).

## 0. One paragraph

The descent phase of the 12x512 statement (8T + the RTX 4070 Laptop) went
from 10.8 s to 6.4 s [MEASURED, WSL-BOX 8T NOISY-SHARED] — the wall from
34.1 s to 30.1 s (commit 5.1 / prove 20.7 / verify 2.8), peak RSS 6.70 GB,
every digest identical (statement 2f8a92f8.. / EVAL 4c259008.., 1,509,911
B, accept) — by removing what surrounded the kernels rather than by making
the kernels faster: (1) ONE launch per fused round over a device range table
instead of one launch per live range (the rig's rounds have 12 live ranges;
under WSL2 each launch costs ~0.15 ms, so a small round cost 2 ms instead of
0.2 ms), (2) the eq b-part table built ON THE DEVICE from two tiny host-built
halves (`k_eq_outer`: eq[i] = lo[i mod 2^lb] x hi[i >> lb] — the same
canonical field products as the host doubling, so identical bytes; the host
image materialized lazily and only for CPU readers) — no host build
(a.eq-table 0.67 -> 0.08 s), no per-layer upload, no cold DMA'd pages in
round 0/1, (3) a slab/buddy device allocator (256 MiB slabs, per-piece state
chunks — every buffer of the descents and the tree store is a power of two
of bytes) so that bytes change roles — a released checkpoint becomes a
climbed layer becomes a state chunk becomes the next pair's leaf layer —
with NO new allocation after warm-up: measured on this box, cuMemAlloc of
multi-GB buffers costs 50-100 ms per GB and a kernel's first touch of fresh
pages runs 2-3x slower (lane L's finding, quantified here: the biggest
round-0 hooks spent 100-250 ms outside the kernels and their kernels 2x),
which was ~2 s of the 7.1 s a.round-g at 12x512 and most of the tree store's
42-45 ms per build (now 17 ms average, 45 builds 0.78 s). Values: bit-
identical everywhere (`uperf-p battery` 182 legs at ZK_THREADS 1/2/7 —
lane L's layer chains at the rig's 16-slot layouts CPU == per-range launches
== one launch, kernel variants 0 and 1, the device eq == the host doubling
cell by cell, descent pairs with pads under 6 knob combinations; the
existing batteries under ZK_GPU=1: uperf-l 310 legs cc4f8c1c.., uperf-n 30
legs 8c3f8ca1.., uperf-h b1e78285.., uperf-a f936ff79.., uperf-g 6d6a3f6b..,
uperf-j 45dba7c7.., uperf-pc diff-battery, freeze-check exit 0 with the wsl
export; the default build's batteries unchanged; the three rigs' digests).
The kernels themselves: lane L's "~16% of the part's peak" was against a
nominal instruction rate; a standalone probe (`uperf-p kprobe`) puts the
REGISTER-ONLY K-mult (the round kernels' schoolbook + burst folds +
reduction, nothing else) at 1.7 G kmul/s on this part (21 ns per kmul per
SM; more ILP per thread does not help; 16 warps/SM), and the round kernels
run at 70-88% of THAT ceiling at the rig's shapes (FOLD 1.19, EXTRACT 1.38,
masked EXTRACT 1.49 G kmul/s) — so the arithmetic itself, not the kernels'
structure, is the wall; a variant with the node loop distributed and
unrolled (registers instead of local memory) was built and MEASURED slower
(Section 4.5, kept behind `ZK_GPU_K9_KVAR=1`); with ~10 minutes of NVRTC +
JIT per source change of the K9 module and at most ~1.3x left in theory,
further kernel work is not this lane's best use — the descent's remaining
4.6 s of a.round-g are ~3.9 s of kernels at the arithmetic's ceiling
(Section 5).

## 1. Design (what changes, why the values are identical)

### 1.1 One launch per round (k9.rs `fused_round`, kernels_k9.cu `k_*_m`)

The plan's live ranges (one per real instance while the pads are skipped —
12 at the rig — or one when nothing is skipped) used to be one launch each
(lane L). Now the host writes a RANGE TABLE (`K9Range` == `struct K9R`:
per piece the five input / output pointers, the layer source and eq
pointer of the extract modes, the thread prefix, the parameter slot, the
flags) right after the parameter slots in the same pinned/device pair (one
copy per round), and launches ONE kernel whose grid strides over the SUM
of the pieces' threads; a thread finds its piece by a linear scan of the
table (<= 64 entries, cached) and runs exactly lane L's per-pair body
(`fold_round_pair`, `extract_round_pair<COMPACT>`, `extract_fold_pair<
COMPACT>` — the loop bodies of L's kernels, factored out unchanged). The
node sums: every piece's block sums add into the same partials with u64
atomics of canonical values — modular addition in any order gives the same
sum mod q, exactly as L's per-range launches did. `ZK_GPU_K9_MULTI=0`
launches L's kernels per piece from the same table (the one-binary A/B).

### 1.2 The eq b-part on the device (kfield.rs `EqTab`, k9.rs `k9_eq_build`, `k_eq_outer`)

The b-part eq table of layer j (eq over zeta[..j], 2^j entries) is a handle
now: `EqTab::new(kf, &zeta[..j])` asks the device first — the host builds
the two small halves lo = eq(zeta[..lb]) and hi = eq(zeta[lb..]) (lb =
j/2; 2^10 + 2^11 entries at j = 21) with `kt_eq_table_par`, uploads them
(192 KB), and one kernel computes eq[i] = lo[i mod 2^lb] x hi[i >> lb] with
the K-mult of the round kernels. Why identical: eq[i] is the field product
of j factors (z_k or 1 - z_k by the bits of i); the host doubling multiplies
them in index order, the device multiplies the two partial products — the
same field element, and every stored coefficient is its canonical
representative, which is unique. `FusedPlan.eq_tab` carries the handle:
the hook binds the resident device table in place (no upload); a CPU
reader (the hook declined, `build_eq_table`, the fused CPU body) gets
`EqTab::host()` — the host doubling, built once, never downloaded (the
same bytes by the argument above; the battery asserts the device table
against it cell by cell). Without the device (default build, oracle mode,
j < 10, budget) `new` builds the host table eagerly — lane G's path.
Dropping the handle frees the device table. `ZK_GPU_K9_EQ_DEV=0` = the
host build + L's upload.

### 1.3 The slab/buddy allocator (k9.rs `Buddy`, `Chunk`, `Piece`)

Every device buffer of the descents and the tree store — a state table of
one piece, a climbed layer of one tree, a store checkpoint, the compact
leaves' words, the eq table, the climb scratch — is a power of two of bytes
(per-instance sizes are 2^k elements x 64 B). They are carved out of 256
MiB slabs (cuMemAlloc'd on demand within the VRAM budget, kept for the
process, wholly free slabs trimmed only when the budget needs it) by a
buddy allocator (levels 64 KiB .. 256 MiB, free sets per level, buddies
merged on free; a request above a slab — none in the descents — gets a
dedicated buffer). States are laid out per PIECE (a live range, split at
2^16 pair-blocks = 64 MiB per table); the range table carries the pieces'
pointers, so nothing needs to be contiguous across ranges: the FOLD round's
input pieces are the intersections of the output pieces' [2a, 2b) with the
previous state's pieces (asserted contiguous, as before). The chain owns
its pieces (freed when the successor is complete — every round ends with a
sync), the layer binding owns its uploaded/climbed chunks and the climb
scratch (freed after round 1), the eq its chunk, the store its layers.
`used()` = the slabs + the remaining dedicated buffers (lane L's ixf tables
and off-by-default device-climb buffers) against the budget; a shortfall
frees the idle dedicated families and free slabs, then declines (the CPU
path — never a value change; the tree build's estimate counts the free
bytes inside the slabs). Values: unchanged — pointers only. `ZK_GPU_K9_
SLAB_MB=0` = one cuMemAlloc per chunk (lane N's allocation pattern; the
A/B); `ZK_GPU_K9_WARM=1` = memset each fresh allocation once (MEASURED a
net loss: the fill engine pays the cold pages slower than the kernels'
first touch — off).

### 1.4 The kernel variant 1 (kernels_k9.cu, `k_*_m1`, `ZK_GPU_K9_KVAR=1`)

The node loop distributed over the wire's two products — accn[x] +=
red(EQ(x) red(PL(x) Q1(x))) + red(EQ(x) red(P1(x) Q0(x))) — the same field
element as red(EQ(x)(PL Q1 + P1 Q0)) by distributivity (canonical
representatives unique; the node sum is a sum mod q of the same terms), at
one more K-mult per node, so that no w[node] stays live across the passes
and the node loops unroll (NN in {3, 5} as a template; the per-node
accumulators stay registers instead of lane L's runtime-indexed local
arrays). Built, battery-gated, MEASURED slower (Section 4.5); default 0.

## 2. What landed (files)

- `zkmatrix-rs/src/ring/gpu/kernels_k9.cu`: `struct K9R` + `find_range`,
  the per-pair bodies factored out of L's kernels (`fold_round_pair`,
  `extract_round_pair<COMPACT>`, `extract_fold_pair<COMPACT>` — L's kernels
  call them, unchanged values), the one-launch kernels `k_fold_round_m`,
  `k_extract_round[_cl]_m`, `k_extract_fold[_cl]_m`, `k_eq_outer`, the
  variant-1 kernels `k_*_m1` (`node_terms<NN>`, `reduce_nodes_t<NN>`).
- `zkmatrix-rs/src/ring/gpu/k9.rs`: `K9Range`, `upload_prm_ranges` (slots +
  range table in one copy), the one-launch / per-piece launch paths of
  `fused_round` (all three modes), `Buddy` / `Chunk` / `Piece` / `pieces_of`
  / `alloc` / `free` / `make_room` / `alloc_state`, the chain / layer
  binding / eq owning chunks (`Chain.pieces`, `LayerRes.owned`, `EqRes`),
  the tree store on chunks (`tree_alloc/free`, `climb_layer` with explicit
  scratch, `tree_fetch` with temporary chunks), `k9_eq_build/drop/fetch`,
  the knobs (`ZK_GPU_K9_MULTI`, `ZK_GPU_K9_EQ_DEV`, `ZK_GPU_K9_SLAB_MB`,
  `ZK_GPU_K9_WARM`, `ZK_GPU_K9_KVAR`, harness setters), `K9PStats` /
  `k9p_stats[_reset]`, `k9_kprobe` (its own NVRTC module `zkgpu_k9probe`).
  Removed: the grow-only `st/lay_p/lay_q/cl_w/cl_meta/eqb/climb_scr`
  DevBufs, `Region`, `layout`, `input_offset`, `release_idle[_all]` (the
  ixf tables and L's device-climb buffers stay dedicated `grow_dev`
  buffers).
- `zkmatrix-rs/src/ring/gpu/mod.rs`: `// [UPERF2-P]` re-export line + the
  stub block (`k9_eq_build/drop/fetch`, `k9_set_multi/eq_dev/kvar`,
  `k9p_stats[_reset]`, `K9PStats`, `k9_kprobe`).
- `zkmatrix-rs/src/ring/kfield.rs`: `EqTab` (+ `K9_EQ_DEV_MIN_BITS`),
  `FusedPlan.eq_tab`, the CPU body's resolution of an empty `eq_src`
  through the handle.
- `zkmatrix-rs/src/ring/gkr_masked.rs`: `masked_rounds_bulk` builds
  `EqTab` (device first) and passes it in the plan; `EqSrc.eqb` is the
  handle; `build_eq_table` reads `host()`.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-P]` section, `uperf-p
  battery [seed] | bench <depth> <l> [n_real] [dt] | kprobe [iters]`,
  registered next to `uperf-o`; ONE line in lane L's `uperf_l_run_layer`
  (`eq_tab: None` in its `FusedPlan { .. }` literal — the plan grew a
  field; flagged for the orchestrator, merge-safe: lane Q does not touch
  it).
- `zkmatrix-rs/src/ring/ct_engine.rs`: NOT touched (prof ids 70-79 stay
  reserved — the lane's attribution went into `K9PStats`, printed by
  `uperf-p bench`; nothing new needed a phase row).
- This report + "Agent P status" in PROGRESS_UPERF2.md.

Knobs (none changes a value; defaults in bold): `ZK_GPU_K9_MULTI` (**1**
one launch per round / 0 lane L's launch per piece), `ZK_GPU_K9_EQ_DEV`
(**1** device eq / 0 host build + upload), `ZK_GPU_K9_SLAB_MB` (**256**; 0
= one cuMemAlloc per chunk), `ZK_GPU_K9_WARM` (**0**; 1 = memset fresh
allocations), `ZK_GPU_K9_KVAR` (**0** lane L's bodies / 1 the distributed
node loop). Lane L's / N's knobs as before (`ZK_GPU_K9`, `_MIN_PAIRS`,
`_BUDGET_MB`, `_EAGER`, `_TREE`, `_TREE_STORE`, `_STG_MB`, `ZK_GPU_VERBOSE`,
`ZK_GPU_PROFILE`).

## 3. Differential evidence (HEAD of uperf2-p; the GPU build under `ZK_GPU=1` unless stated)

| gate | result |
|---|---|
| `uperf-p battery` (ZK_THREADS 1, 2, 7) | 182 legs: (1) lane L's fused layer chains at 12 shapes incl. the rig's 16-slot / 4-pad layouts (per 128..1024 x 16 instances, packed and compact leaves with planted exceptions, masked round 0), 3 value patterns, eager + lazy: CPU (bypassed) == GPU launch-per-piece (KVAR 0) == GPU one launch KVAR 0 == GPU one launch KVAR 1 — every round's node values and the (eager: every round's / lazy: the handover's) tables cell by cell; (2) the device eq b-part at j = 10/11/13/16/18/20 == the host doubling cell by cell and == the handle's host image; (3) descent pairs (13x8/5, 14x16/12, 15x4/3, 16x16/12; masks and zero masks): bypass == multi+eq (v1) == multi+eq (v0) == split+eq == multi+host eq == split+host eq, every proof verified with pins; 41,699,840 table words compared; **BATTERY DIGEST 43fa6363..1ee87** identical at 1/2/7T (8-12 s); the default build (not live) runs the 8 descent legs: 0ce14f3c.. |
| `uperf-l battery` (7T) | 310 legs, cc4f8c1c.. (lane L's value) — through the one-launch path and the buddy |
| `uperf-n battery` (7T) | 30 legs, 8c3f8ca1.. (lane N's value); default build identical |
| `uperf-h battery` (7T) | 24/24 eight ways, b1e78285.. (both builds) |
| `uperf-a descent-battery` / `uperf-g descent-battery` (7T) | 18/18 f936ff79.. / 22/22 6d6a3f6b.. (both builds) |
| `uperf-j battery` (7T) | 1,120 x 3, 45dba7c7.. (both builds) |
| `uperf-pc diff-battery` (7T, `ZK_GPU=1`) | passed (17.1 s; O1/O2/O3/O5/E2E) |
| freeze-check (GPU build, `ZK_GPU=1`, `M125_EXPORT_DIR` = the wsl re-export, 8T) | 98 `ok` rows, "freeze_check_uagb1_bk: all rows stable", "freeze-check passed", exit 0 |
| REAL rigs (`uperf-pc full-profile`, `ZK_GPU=1`, 8T, flock, final HEAD binary) | 3x16: statement 93a98700.. / EVAL 0ae9cdae.., accept, 4.6 s; 12x128: 4a3af8c3.. / 742d88e1.., accept, 14.5 s; **12x512: 2f8a92f8.. / 4c259008.., accept, 30.1 s, 1,509,911 B, maxrss 6,700,500 KB** — every digest the ledger's (four 12x512 runs during the session, every one identical) |

## 4. Measurements

### 4.1 THE PoC SHAPE — 12x512 8T (`uperf-pc full-profile 12 512`, `ZK_GPU=1`, wsl export, flock, `/usr/bin/time`) [WSL-BOX 8T NOISY-SHARED — lane Q active; the untouched phases within +5% of the baseline capture]

| | commit | prove | verify | wall | peak RSS | digests |
|---|---:|---:|---:|---:|---:|---|
| round 8 (N + O, the orchestrator's QUIET capture `fp_12x512_NO_gpu.txt`) | 5.0 | 24.9 | 2.6 | 34.1 s | 6.70 GB | 2f8a92f8.. / 4c259008.. |
| step 1 (97725ef: one launch, device eq, exact-size pool) | 5.0 | 22.7 | 2.6 | 32.2 s | 6.70 GB | identical |
| step 2 (buddy allocator) | 5.3 | 21.2 | 2.8 | 31.0 s | 6.70 GB | identical |
| **HEAD (final binary)** | **5.1** | **20.7** | **2.8** | **30.1 s** | **6.70 GB** | **identical (accept)** |

Phase rows (seconds; the baseline capture -> HEAD): `bk.descent-trees`
2.63 -> **1.53** (a.tree-pack 0.72 -> 0.71 host compact fill, a.tree-step
1.91 -> **0.82**: 45 device builds 0.78 s, 17.3 ms average / 42 max, the
first of each size cold), `bk.descent-gkr` 8.13 -> **4.88** (a.round-g 7.14
-> **4.60**: 1,233 device rounds, 4.32 s inside the hooks = kernel+sync 3.88
+ 0.44 s of eq binds / climb enqueues / range tables / the ~0.2 ms floor;
a.eq-table 0.67 -> **0.08**: 119 device eq builds in 87 ms), `e.tree-
witness` 2.62 -> 1.53 (contains the builds); the descent phase **10.8 ->
6.4 s**. The rest: bg.prove-group 12.30 -> 12.34, commit 5.02 -> 5.08, claim
layer 1.69 -> 1.76, CRS 2.76 -> 2.68, transport 1.95 -> 1.99, verify 2.6 ->
2.8 (untouched; the box's noise). VRAM: 25 slabs (6.7 GB) at the biggest
pair (the pair-shape bench's `held peak 6.71 GB`); the rig's K9 budget was
6.83 GB (lane K's GEMM context holds ~0.3 GB more than at the bench), no
decline, no slab trim.

### 4.2 The other rigs, 8T [NOISY-SHARED]

| rig | round 8 (ledger) | HEAD | descent phase (trees / gkr; a.round-g, a.tree-step) | digests |
|---|---:|---:|---|---|
| 12x128 | 15.6 s | **14.5 s** (2.7 / 9.8 / 1.4), 3.49 GB | 0.53 / 1.99 (1.75, 0.30) | 4a3af8c3.. / 742d88e1.. identical |
| 3x16 | 4.3 s | 4.6 s (0.9 / 3.0 / 0.6), 1.34 GB | 0.07 / 0.37 (0.23, 0.05) | 93a98700.. / 0ae9cdae.. identical |

(3x16 is within the box's noise; the rig gate is the digest.)

### 4.3 Per item, the same command before / after (`uperf-p bench 22 16 12 9` = lane H's pair shape: 12 real depth-22 trees + 4 pads, dt 9; one process each; 8T) [WSL-BOX 8T NOISY-SHARED]

| binary / knobs | trees | masked_gkr_prove | a.tree-step | a.round-g | in-hook = kernel+sync + upload + handover | k9p |
|---|---:|---:|---:|---:|---|---|
| baseline (all knobs off in the step-1 binary: MULTI 0, EQ_DEV 0, POOL 0) == lane N's HEAD (`uperf-h bench`: prove 2.48, a.round-g 2.34, a.tree-step 1.44 in a fresh process) | 0.92 | 2.44 | 0.52 | 2.31 | 2.24 = 1.77 + 0.07 + 0.04 | 1,956 launches; 12 tree builds 0.51 s |
| + one launch per round + device eq | 0.94 | 2.14 | 0.54 | 2.07 | 2.00 = 1.57 + 0.03 + 0.03 | 163 launches; eq builds 12 (0.025 s), 0 host images |
| + the exact-size pool (step 1) | 0.69 | 2.16 | 0.28 | 2.11 | 2.04 = 1.52 + 0.18 + 0.04 | pool hits 110 / misses 212 / trims 106 — the pool thrashed against the budget |
| + WARM=1 (memset fresh buffers) | 0.87 | 2.34 | 0.43 | 2.27 | 2.20 = 1.03 + 0.39 + 0.05 (+ 1.23 s inside the allocations) | kernels warm (-0.5 s) but the memsets cost 1.2 s — a net loss |
| **HEAD: the buddy allocator (256 MiB slabs)** | **0.72** | **1.32** | **0.30** | **1.29** | **1.22 = 1.09 + 0.01 + 0.03** | 25 slabs (6.71 GB peak), 9,164 chunk allocations from the free lists, 0 trims; 12 tree builds 0.29 s |

DESCENT DIGEST b527b531.. on every row (lane N's value).

### 4.4 Where the descent's time went, before and after (the 12x512 rig with `ZK_GPU_VERBOSE=1`, one run each) [NOISY-SHARED]

| | step 1 (one launch, pool) | HEAD (buddy) |
|---|---|---|
| in-hook total / kernel+sync (1,233 rounds) | 6.29 / 4.87 s | **4.32 / 3.88 s** |
| mode 0 FOLD (912) | 1.70 / 1.50 | 1.27 / 1.15 |
| mode 1 EXTRACT (169; the climbs inside) | 2.48 / 1.39 | 1.66 / 1.39 |
| mode 2 EXTRACT_FOLD (152) | 2.12 / 1.98 | 1.38 / 1.35 |
| the biggest rounds (ms, total / kernel): EXTRACT 2^21 pairs x 12 ranges | 250 / 162 | 158 / 158 |
| masked EXTRACT 2^20 x 12 (the climb of layer 21 inside: 3.2 GB) | 358 / 114 | 168 / 114 |
| EXTRACT_FOLD 2^20 x 12 (writes 4 GB of state-1) | 333 / 314 | 140 / 140 |
| FOLD 2^19 x 12 (first fold: writes 2 GB) | 157 / 147 | 99 / 94 |
| FOLD 2^18 x 12 | 80 / 75 | 32 / 32 |
| tree builds (45) | 23-54 ms each (avg 26) | 0.78 s, avg 17.3 ms |

The step-1 column's non-kernel time at the biggest layers is cuMemAlloc /
cuMemFree of multi-GB buffers as the budget forced releases and regrowth
(3.2 GB of layer buffers at j = 20, 4 + 2 GB of state at j = 21 — "released
6.38 GB of idle device buffers" then regrown), and its kernel column
carries the first-touch penalty of the fresh pages (2.2-2.4x on the writes:
EXTRACT_FOLD 314 vs 140 ms, FOLD 147 vs 94 ms). With the slabs both are
paid once per process (the first pass through each size); the same
sequence at HEAD allocates 25 slabs at the first big pair and nothing after
(0 trims, 0 declines at the 6.83 GB budget).

### 4.5 The kernels: the arithmetic's ceiling and where the round kernels sit [MEASURED, WSL-BOX, one process]

`uperf-p kprobe 256` — a separate module measuring the register-only K-mult
(exactly the round kernels' `kmac` schoolbook with burst folds + `kred`
reduction, a dependent chain per thread, no memory) at 1/2/4 independent
chains per thread and 1-16 blocks per SM:

| blocks/SM x 64 threads | chains 1 | chains 2 | chains 4 | driver occupancy (warps/SM) |
|---:|---:|---:|---:|---|
| 1 | 0.4 G kmul/s | 0.5 | 0.5 | 16 / 12 / 8 |
| 2 | 1.0 | 1.1 | 1.0 | |
| 4 | 1.5 | 1.5 | 1.5 | |
| 8 | 1.6 | 1.5 | 1.5 | |
| 16 | **1.7** | 1.7 | 1.5 | |

The ceiling is ~1.7 G kmul/s = 21 ns per K-mult per SM (~42 cycles at 2
GHz for ~963 issue slots per K-mult: 363 `mad.wide.u32` + the folds /
adds / selects — 36-49% of the nominal 64 INT32 ops/clk/SM depending on
whether the wide MAC counts one or two slots), reached at 16 warps/SM;
more ILP per thread does NOT raise it (register pressure). The round
kernels at the rig's shapes (kernel+sync of single rounds, HEAD): FOLD at
2^19 pair-blocks: 4.2M pairs x 19 K-mults / 67 ms = **1.19 G kmul/s
(70%)**; EXTRACT (nn 3) at 2^21: 16.8M x 13 / 158 ms = **1.38 (81%)**;
masked EXTRACT (nn 5) at 2^20: 8.4M x 19 / 107 ms = **1.49 (88%)**;
EXTRACT_FOLD at 2^20: 8.4M x 23 / 140 ms = 1.38 (81%). Lane L's "~16% of
the part's peak" and "~25 ns per element pair" hold at 2^15 pair-blocks
(`uperf-l bench 21`: FOLD 6.1 ms = 0.82 G kmul/s, 48% — the small grids'
tail waves); at the shapes that carry the rig's time the kernels are within
12-30% of what this arithmetic can do on this part.

What did NOT work: variant 1 (Section 1.4; `ZK_GPU_K9_KVAR=1`): FOLD at
2^15 pair-blocks 6.9 vs 6.1 ms, EXTRACT_FOLD 16.4 vs 16.2, EXTRACT 19.2 vs
13.7 ms — the extra K-mult per node costs exactly its share (+23% on the
extract) and the register savings do not raise the occupancy (still 4
blocks/SM = 8 warps for every round kernel per the driver's report): the
runtime-indexed local arrays were not the limiter. Also: the memset warm-up
(Section 4.3), and the exact-size pool alone (its trims against the budget
re-created the churn it was meant to remove — the buddy is what works).
Cost of a kernel-source iteration on this box: the K9 module's NVRTC
compile 464 s + driver JIT 99 s the first time a process sees a new source
(the disk / driver caches cover the next processes).

### 4.6 The per-round floor [MEASURED, `uperf-l bench 21` / `uperf-h bench 22 16 12 9` verbose]

One range: 0.20-0.25 ms per round (launch + partial memset + sync +
readback under WSL2). Twelve ranges: 1.8-2.0 ms per round with a launch per
range (85 of the pair shape's 163 device rounds are that small: 0.17 s of
its 2.26 s), 0.25-0.3 ms with one launch. At the rig: 1,233 rounds; the
non-kernel time inside the hooks 1.42 s (step 1) -> 0.44 s (HEAD), of which
the floor ~0.25 s.

## 5. What is left / honest state

1. **The descent is 6.4 s at 12x512 [NOISY-SHARED]** against the round's
   <= 6 s [ASSUMED]: bk.descent-gkr 4.88 (a.round-g 4.60 = 3.9 s of kernels
   at 70-88% of the K-mult ceiling + 0.44 s of hook overhead + 0.3 s of the
   1,134 tiny CPU tail rounds), bk.descent-trees 1.53 (a.tree-pack 0.71 =
   the host compact fill at 3.7 ns per leaf over 8T — the value closures;
   a.tree-step 0.82 = 45 device builds at 17 ms + the small-layer host
   loops). A QUIET measurement would likely read ~6.2 s.
2. **The kernels are at the arithmetic's ceiling on this part** (Section
   4.5). What could still move them is the ARITHMETIC per K-mult, not the
   kernels' structure: lane J's matrix form for the ten fixed multiplies of
   a FOLD pair (no h-step: ~-10% of those K-mults' ops, ~5% of the round)
   with the 1 KB R matrix in the constant bank (kernel parameters — 32 KB
   allowed on sm_70+ with CUDA >= 12.1, which this NVRTC/driver pair is);
   a lazy double-product reduction per node (one `kred` for PL Q1 + P1 Q0
   instead of two: ~2.6%); a 16-bit-limb formulation on the tensor cores
   (exact int32 accumulation of byte products — a research item, not a
   round). Each is a ~10-minute compile per iteration here. Expected total
   ~10-15% [ASSUMED]; not done.
3. **The first pass through each size is still cold** (the 25 slabs are
   allocated and first-touched during the biggest pair's climb; ~0.5 s once
   per process at 12x512 [MODEL from Section 4.4]). Pre-allocating the
   slabs at K9 init (the budget is known) would move it to init; not done
   (it would also hold VRAM the claim layer's device chain (lane O's, 4 GB)
   needs at the same time — the phases are sequential, but the budget
   accounting between the K9 slabs and O's `ixf.rs` buffers is by free-VRAM
   probing at first use, so a pre-allocation must be sized against O's
   peak; designed, not done).
4. **`ZK_GPU_K9_SLAB_MB=0` (dedicated buffers) is the A/B**, not a
   supported production mode: it re-creates lane N's allocation churn.
5. **`a.tree-pack` (0.71 s)** is the aligned witness's value closures over
   the compact fill (already threaded); overlapping it with the previous
   tree's device build needs the build to be asynchronous (it is: enqueue
   + one 2 MB download) — a small restructuring of `build_tree_from`'s
   loop over trees in the pass driver; not this lane's file (the loop is
   the bin's).
6. **Not a Mac build**: CUDA-only, feature OFF elsewhere (as K/L/N/O); the
   `EqTab` handle and the plan field are plain Rust and land on every path
   (the host build when the device declines).
7. Prof ids 70-79 stay reserved (unused by this lane).
