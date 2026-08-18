# U-PERF2 lane N — THE GPU RUNG, step 3: the descent tree DEVICE-RESIDENT end to end

Branch `uperf2-n` (worktree /home/victor/wt-uperf2-n), opened at 50aea3e on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 8 ... Lane N" + "Agent N
status". This continues lane L's GPU step 2 (U_PERF2_GPU2_REPORT.md: the
device-resident layer chain, the handover protocol, the honest-framing rules)
and lane H's tree memory work (U_PERF2_DESCENT4_REPORT.md: the per-layer
store, the checkpointed build, the compact leaves). Hardware as lane L's
report states it (RTX 4070 Laptop, 8,188 MiB, sm_89, WSL2, a 55-70 W-class
mobile part; host Core Ultra 9 185H, 15 GB). Every number carries
[MEASURED] / [ASSUMED] / [MODEL] and a [WSL-BOX NT QUIET|NOISY-SHARED]
label — lane O built and ran concurrently the whole session, and my own
batteries overlapped the small rigs, so every wall below is NOISY-SHARED
unless marked.

## 0. One paragraph

The descent tree is now built, kept and read ON THE DEVICE when the GPU is
live: `gkr::build_tree_from` hands the leaves to the new device tree store
(`gpu/k9.rs`) — the compact words go up as they are (a memcpy, 8 B per
leaf + the exceptions; the packed leaf tables of a general tree go up as
packed blocks) — the bottom-up steps run on the device (`k_tree_step[_cl]`),
the checkpointed layers (stride max(`ZK_K9_CHECKPOINT`, 2)) stay RESIDENT,
the gap layers are freed as soon as the layer above exists, and only the
smallest big layer (8192 elements, 2 MB) comes back so that the host loop
builds the small top layers exactly as before; the FracTree keeps NO host
copy of a big layer. The masked descent is unchanged: `FracTree::layer(k)`
answers a `LayerSrc::Device` descriptor for a device tree's big layers, the
fused rounds 0/1 carry `BlkSrc::Device` into lane L's hook, whose layer
binding reads a resident checkpoint or the compact leaves IN PLACE and
CLIMBS a gap layer on the device from the nearest resident layer below into
L's layer buffers (freed after round 1) — no per-layer host upload, no host
layer store, no CPU tree step on the GPU path; `release_layer(k)` frees the
device checkpoint top-down (lane H's discipline; the leaves stay), `Drop`
frees the tree. Every CPU reader of a device layer (fusion off, a declined
hook, the oracle routing / the bypass, `p_elem/q_elem`, the harness)
materializes it on demand (`k9_tree_fetch`: a download, or a device climb +
download; the compact leaves' host copy is read directly) — the same
integers, so the same tree on every path. Evidence: `uperf-n battery` (the
device build vs the CPU tree cell by cell — 55.1M words over every layer of
12 tree shapes at depths 13-18 incl. compact leaves with exceptions, packed
and sparse general trees, strides 2/3/4, reads under the GPU bypass; 18
descent legs — lane H's 2-coordinate pairs and lane A's packed pairs — proven
with the store OFF and ON under {default, fusion off, every hook declined,
stride 3, release off}: every digest identical, every proof verified;
BATTERY DIGEST 8c3f8ca1.. at ZK_THREADS 1/2/7 and on the default build), the
existing batteries under `ZK_GPU=1` (uperf-a 18/18, uperf-g 22/22, uperf-h
24x8, uperf-l 310 legs at 1/2/7T, the ledger's digests), the descent-bench
digest 47a58a27.., freeze rows, and the REAL rigs' digests. Measured
[WSL-BOX 8T NOISY-SHARED]: **12x512 8T+GPU (THE PoC SHAPE) 60.2 s -> 52.0 s
(commit 5.0 / prove 42.2 / verify 3.0), accept, statement 2f8a92f8.. / EVAL
4c259008.. identical, 1233 device rounds, no decline; the descent phase 22.6
-> 11.2 s (bk.descent-trees 6.2 -> 2.8, bk.descent-gkr 16.4 -> 8.4:
a.round-g 12.0 -> 7.3 of which the kernels 5.2 s, a.tree-step 8.5 -> 2.1)**;
12x128 21.2 -> 19.9 s (descents 7.2 -> 4.2 s); `uperf-h bench 20 8 5 9`
prove 0.72 -> 0.42 s at peak RSS 665 -> 297 MiB; `uperf-a descent-bench 20 8
5 9` prove 0.77 -> 0.42 s at 1,100 -> 365 MiB. What is left is the kernels
themselves (~5 s of a.round-g at 12x512, ~16% of the part's peak — lane L's
Section 5.2), the eq uploads / parameter syncs (~1.4 s), and the tree
build's step kernel (~2 s for 45 trees) — Section 5.

## 1. Design (what changes, why the values are identical)

### 1.1 The store (k9.rs, `[UPERF2-N]` section)

`DevTree { depth, kern, layers[k]: Option<(DevBuf p, DevBuf q)>, compact:
Option<(words, meta, n_exc)>, bytes }` per tree id. `k9_tree_build(kern,
&TreeLeaves, depth)`:

1. Declines (`None` -> the CPU build) when the GPU is not live, the store is
   off (`ZK_GPU_K9_TREE_STORE=0` / `k9_set_tree_store`), under
   `oracle_mode()`, when depth <= 13 (2^13 = the smallest "big" layer: the
   small top layers <= 4096 elements are always the host's — the roots, the
   layer-1 quadruples and the scalar-tail layers are read element by
   element), or when the VRAM budget cannot hold the leaves + the kept
   layers + one transient layer pair (idle families are released first; a
   shortfall MID-build frees what it allocated and declines).
2. Uploads the leaves ONCE: `CompactLeaves::words()` (2 u32 per leaf — q's
   coordinates 0..1 with the member flag in bit 31; a zero pair = the (0, 1)
   dummy) + `alpha_words()` + `exceptions()` (idx, p, q) — exactly the
   encoding lane L's device decode `cl_get` reads (L re-derived it from
   `expand_blocks` at ~24 ms per 4M leaves; the accessors make it a memcpy
   into the pinned staging); a general tree's packed leaf tables go up as
   they are.
3. Bottom-up on the device: layer k = `k_tree_step` over layer k+1 (or
   `k_tree_step_cl` over the compact leaves), k = depth-1 .. 13; the source
   layer is freed (after a stream sync) unless it is a checkpoint (`(depth
   - k) % stride == 0`, stride = max(`ZK_K9_CHECKPOINT`, 2) — a "keep every
   layer" request cannot be honored in 8 GB at the rig's depths and the
   values do not depend on the policy). Layer 13 is downloaded (2 MB) and
   returned as `DevTreeBuilt { id, top_k: 13, top_p, top_q }`; the host loop
   in `build_tree_from` continues from it for the small layers as before
   (`keep_h(k) = k < top_k` on the device path). The transient of a build is
   one layer pair beyond the resident set (~0.4 GB per depth-22 tree).
4. The store's bytes are counted in L's `held` / the VRAM budget, released
   never by `release_idle` and never by the device-error path (`release_all`
   keeps the store: it is the only copy of the big layers of the trees the
   host still holds, and `k9_tree_fetch` — a plain download — must keep
   answering).

### 1.2 The contract change (kfield.rs / gkr.rs — SMALL, additive)

- `kfield::DevLayer { tree, k, n }` (a Copy descriptor), `TreeLeaves`,
  `DevTreeBuilt`; `BlkSrc::Device { dev, host: &OnceLock<(KTab, KTab)>,
  compact: Option<&CompactLeaves> }` with `host_tabs()` (materialize once per
  handle through `gpu::k9_tree_fetch`), `compact()`, and `get_p/get_q/blocks`
  answering through the compact leaves' host copy or the host image.
- `gkr::PackedTree.dev: Option<u64>`; `LayerSrc::Device { dev, host:
  OnceLock, compact }`; `PackedTree::layer(k)`: a host-stored layer ->
  `Stored` (as before), else a device tree's big layer -> `Device` (the
  descriptor; the compact leaves' host copy attached for k == depth), else
  the compact leaves / the host recompute (a host tree, as before);
  `p_elem/q_elem` bring a device layer into the HOST store first
  (`ensure_host`, once) so that the element readers of the ref/scalar/
  harness paths never materialize per element; `release(k)` frees the host
  copy AND the device checkpoint (`k9_tree_release`; a later read climbs it
  from below — the leaves are never released); `Drop for PackedTree` ->
  `k9_tree_drop`; `device_bytes()`, `is_device_resident()`,
  `harness_layer_words(k)` (the battery's accessor: the same handles the
  descent uses).
- `k9_fused_round_par`'s CPU body reads a Device layer through
  `compact()`/`host_tabs()` (only when the hook declined);
  `extract_children_par` and `k9_tree_climb_par` materialize a device
  layer on the CALLING thread before their jobs; `extract_children` /
  `LayerSrc::tabs()` materialize once per handle.
- gkr_masked.rs is UNCHANGED (the descent obtains `trees[e].layer(j+1)`
  once, feeds the fused rounds or the flush, releases after round 1 —
  exactly lane H's flow; the descriptor flows through `FusedLayer.src`).

### 1.3 The binding in the hook (`K9::upload_layer`, now "bind")

Per live range: `Packed` -> upload (as L), `Compact` -> upload the words +
meta (as L, memcpy), `Device { dev }` -> if `trees[dev.tree].layers[k]` is
resident -> `LayerDev::Packed { p, q }` = its device pointers, in place; if
k == depth and compact -> `LayerDev::Compact { w, meta, n_exc }`, in place;
else CLIMB: `climb_layer(tree, k, src_k)` — src_k = the nearest resident
layer below (or the leaves), `levels = src_k - k` device steps
(`dev_step`: `k_tree_step` / `k_tree_step_cl`), the intermediate levels
through a climb scratch (two buffers, each holding both tables of the
largest intermediate level; descent family, freed with the layer buffers),
the last level into L's `lay_p/lay_q` at the range's slot — the whole layer
of that tree, 2^k elements. Round 1 hits the same `LayerRes` (`LayerId::
Device { tree, k }`) and reads it again; `release_layer_bufs` after round 1
frees the climbed layer as before. `LayerDev` now carries ABSOLUTE device
pointers (the tree store's, or the layer buffers') — the launch code is
otherwise L's. `k9_tree_release/drop` invalidate a `LayerRes` that
references the tree (its pointers must not survive), after a stream sync.

### 1.4 Why the values are identical

The device tree step is lane L's `k_tree_step[_cl]` (battery-gated by
`uperf-l`, values = `tree_step_body`'s canonical representatives), applied
level by level to the same leaf blocks the layered CPU build reads: every
layer word is the canonical representative of the same field expression, so
the trees are bit-identical whatever the checkpoint policy or the climb
schedule (the climb is block-local and positional — lane H's argument for
`k9_tree_climb_par`). The fused rounds read the same layer words wherever
they sit; the CPU readers get the same words back through the fetch. Hence
the same fractional sums in the same order: the batteries assert it cell by
cell (Section 3).

### 1.5 The VRAM model at the 12x512 nrw-88 pair (12 real trees, depth 22) [MODEL, then measured: no decline]

Store after the 12 builds: leaves 12 x 33.5 MB = 0.4 GB + checkpoints
(layers 20 / 18 / 16 / 14: 134 + 33 + 8 + 2 MB per tree) = 2.1 GB -> 2.5 GB,
falling as the descent passes (layer 20 released after j = 19). Peaks: j =
20 reads layer 21 climbed into the layer buffers (3.2 GB) with the state-1
tables (2.0) + the leaves (0.4) + eq (0.07) = 5.7 GB; j = 21 reads the
leaves in place with state-1 4.0 + ping-pong 2.0 + leaves 0.4 + eq 0.13 =
6.5 GB — inside the 6.84 GB budget the run had (free VRAM at first use minus
256 MB; lane K's GEMM context holds ~1.5 GB before it). Measured: the
12x512 run declined nothing (1,233 device rounds, `ZK_GPU_VERBOSE=1`
grep) and built all 45 big trees on the device (37 at depth 22, 8 at depth
21; 42-105 ms each). A shortfall declines to the CPU path — never a value
change. `ZK_K9_TREE_RELEASE=0` (release off) would keep the 2.1 GB of
checkpoints through j = 21 and decline that layer's state on this part
(correct, slower).

## 2. What landed (files)

- `zkmatrix-rs/src/ring/gpu/k9.rs` (lane L's, extended; `[UPERF2-N]`): the
  device tree store (`DevTree`, `k9_tree_build/fetch/release/drop/bytes`,
  `tree_alloc/free`, `dev_step`, `climb_layer`, `tree_build_into`,
  `release_idle_all`), the Device arms of the layer binding (`upload_layer`),
  absolute-pointer `LayerDev`, `LayerId::Device`, the compact words uploaded
  through the accessors (`cl_encode` is a view + the exception list), the
  climb scratch (`DevSel::ClimbScr`), stats (`tree_builds/declined`,
  `secs_tree_build`, `bytes_tree_leaves`, `layer_resident`, `dev_climbs`,
  `secs_dev_climb`, `tree_fetches`, `secs_tree_fetch`, `tree_bytes_peak`,
  `held_peak`), the knob `ZK_GPU_K9_TREE_STORE` / `k9_set_tree_store`, the
  label. Two protocol fixes found by the batteries: the staging memcpy stays
  serial inside a rayon worker (`in_rayon_worker`: a nested `POOL.install`
  from a worker of another pool makes that worker steal and run its own
  pool's pending jobs while it waits — a job that re-enters this module
  dead-locks on the K9 mutex / the layer's once-cell it is itself
  initializing; hit under fusion-off), and release/drop bind the CUDA context
  (any thread may drop a FracTree). kernels_k9.cu: unchanged (the tree step
  kernels are lane L's).
- `zkmatrix-rs/src/ring/gpu/mod.rs`: re-exports + the default build's stubs.
- `zkmatrix-rs/src/ring/kfield.rs`: `DevLayer`, `TreeLeaves`, `DevTreeBuilt`,
  `BlkSrc::Device` + `host_tabs/compact`, the Device arms of `get_p/get_q/
  blocks`, `CompactLeaves::{words, alpha_words, exceptions}`, the fused CPU
  body's Device arm, `k9_tree_climb_par`'s pre-materialization.
- `zkmatrix-rs/src/ring/gkr.rs`: `PackedTree.dev` + `Drop`, `LayerSrc::
  Device`, `layer/ensure_host/release/device_bytes`, the device build in
  `build_tree_from`, `p_elem/q_elem`, `FracTree::{device_bytes,
  is_device_resident, harness_layer_words}`, `extract_children_par`'s
  pre-materialization.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-N]` section, `uperf-n
  {battery [seed], bench <depth> <l> [n_real] [dt]}`, registered next to
  `uperf-l`.
- This report + "Agent N status" in PROGRESS_UPERF2.md.

Knobs (none changes a value): `ZK_GPU_K9_TREE_STORE=0` (the store off — the
CPU build + lane L's per-layer uploads; the one-binary A/B), lane L's knobs
as before (`ZK_GPU_K9_BUDGET_MB` bounds the store too), lane H's
`ZK_K9_CHECKPOINT` (>= 2 honored by the store; 0/1 -> 2 on the device),
`ZK_K9_TREE_RELEASE`, `ZK_K9_COMPACT_LEAVES`. Not touched: eval_proof.rs,
fold.rs, sumcheck.rs, cuda.rs, kernels.cu, kernels_k9.cu, gkr_masked.rs,
descent_fold.rs, the bin's pass drivers; no transcript / mask / RNG /
planner / wire-layout change.

## 3. Differential evidence (HEAD of uperf2-n, the GPU build under `ZK_GPU=1` unless stated)

| gate | result |
|---|---|
| `uperf-n battery` (ZK_THREADS 1, 2, 7) | 30 legs: 12 tree legs (device build vs CPU tree, EVERY layer of every tree materialized through the descent's handles — the checkpoints downloaded, the gap layers climbed on the device — + roots + a re-read; depths 13 (host: below the store's floor, asserted not resident) / 14 (2-coord + general values) / 15 (2-coord; stride 3; a sparse general tree) / 16 (strides 2, 4; read under the GPU bypass after the build) / 17 (2-coord; general stride 3) / 18: 55,056,384 words compared, all identical) + 18 descent legs (9 shapes x {masks, zero masks}: lane H's 2-coordinate pairs at depths 14-17 with pads, lane A's packed pairs at 14/16/17: store OFF == store ON == store + fusion OFF == store + every hook declined == store + stride 3 == store + release OFF, every proof verified with pins); k9: 241 device builds (1 declined by shape), 405 device climbs, 248 in-place bindings, 303 host fetches; **BATTERY DIGEST 8c3f8ca1d5e3313ddc8c20aff913945a696ce521eb4ad25fe7a22b40891cc774** at 1/2/7T (12.3 s at 7T); the DEFAULT build (no feature, 1T) reports "not live" and produces the same digest |
| `uperf-a descent-battery` | 18/18, f936ff79.. at 1/2/7T (GPU build) and 1T (default build) |
| `uperf-g descent-battery` | 22/22 four ways, 6d6a3f6b.. at 1/2/7T |
| `uperf-h battery` (compact leaves, checkpoints, release, fusion off — 8 ways) | 24/24, b1e78285.. at 1/2/7T (GPU build) and 2T (default build) — the "base"/"c0+compact" variants build packed-leaf device trees, "c2-nofuse" reads them through the flush's extract |
| `uperf-l battery` | 310 legs, cc4f8c1c.. at 1/2/7T (the kernels' cell-by-cell legs, unchanged) |
| `uperf-a descent-bench 20 8 5 9` (8T) | DESCENT DIGEST 47a58a27..dafefb (identical); `uperf-h bench 20 8 5 9` 0bf9d7a3.. (identical); `uperf-l dbench 20 8 5 9` CPU == GPU digest 16deff07..; `uperf-n bench 20 8 5 9` store OFF == ON 0bf9d7a3.. |
| `uperf-pc diff-battery` (ZK_GPU=1, 1T and 7T) | (Section 3.1) |
| freeze-check | default build: 98 `ok` rows identical to the pre-change capture (scratchpad/n_freeze_baseline.txt), then the expected BF panic; GPU build with the wsl export: (Section 3.1) |
| `self-test` (GPU build, ZK_GPU=1, 1T) | (Section 3.1) |
| REAL rigs (`uperf-pc full-profile`, ZK_GPU=1, 8T, flock) | 3x16: statement 93a98700.. / EVAL 0ae9cdae.., accept; 12x128: 4a3af8c3.. / 742d88e1.., accept; **12x512: 2f8a92f8.. / 4c259008.., accept, 1,509,911 B** — every digest the ledger's |
| default build (no feature) | builds; `uperf-n battery` / `uperf-a` / `uperf-h` as above; freeze rows identical |

### 3.1 The rest of the gate (final HEAD binary)

- `uperf-pc diff-battery` (`ZK_GPU=1`) at ZK_THREADS 1 and 7: passed (16.7
  / 16.0 s; O1 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2 — the E2E leg
  proves the same group with the device chains and the store).
- freeze-check (the GPU build, `ZK_GPU=1`, `M125_EXPORT_DIR` = the local wsl
  re-export, 8T): 98 `ok` rows IDENTICAL to the pre-change capture, then
  the UAGB1-BF/BK real-data rows ran and passed ("freeze_check_uagb1_bk: all
  rows stable", "freeze-check passed", exit 0). Default build: 98 rows
  identical, then the expected BF panic.
- `self-test` (the GPU build, `ZK_GPU=1`, ZK_THREADS 1): passed in 240.6 s
  (328 `ok` rows, exit 0) — every descent inside it ran on device trees.

## 4. Measurements

### 4.1 THE PoC SHAPE — 12x512 8T, `M125_EXPORT_DIR` = the wsl re-export, flock, `/usr/bin/time -v` [WSL-BOX 8T NOISY-SHARED, lane O active; ONE run]

| | commit | prove | verify | wall | peak RSS | digests |
|---|---:|---:|---:|---:|---:|---|
| round 7 (L + M, ledger; `ZK_GPU=1`) | 4.9 | 50.9 | 2.6 | 60.2 s | ~11 GB | 2f8a92f8.. / 4c259008.. |
| **this lane, HEAD (`ZK_GPU=1`, the tree store)** | **5.0** | **42.2** | **3.0** | **52.0 s** | 11.2 GB | **identical (accept)** |

Phase rows (seconds; the ledger's round-7 attribution -> HEAD):
`bk.descent-trees` 6.2 -> **2.80** (a.tree-pack 0.68 = the compact fill on
the host, a.tree-step 2.12 = the 45 device builds incl. the leaf uploads and
the small-layer host loop), `bk.descent-gkr` 16.4 -> **8.43** (a.round-g
12.0 -> **7.34**: 1,233 device rounds, 7.04 s inside the hooks = kernels +
sync 5.24 (FOLD 912 rounds 1.81 s, EXTRACT 169 rounds 1.49 s incl. the
climbs, EXTRACT_FOLD 152 rounds 1.95 s) + 1.80 s of eq uploads / parameter
syncs / node readbacks; a.tree-step's recompute share is gone — the gap
layers are climbed on the device inside the hooks), `e.tree-witness` 2.79;
the descent phase 22.6 -> **11.2 s**. The rest: `bg.claim-layer` 17.9
(cl-tables 6.1, cl-rounds 5.5, cl-folds 6.3 — lane O's territory; noise vs
15.5), `bg.prove-group` 12.9 (level-h 4.8), commit 5.0, verify 3.0.
`bk.descent-gkr` no longer contains any tree step: the host never sees a big
layer (no upload, no CPU climb); the peak RSS is unchanged at 11.2 GB
because the pass's peak is the claim layer (lane H's finding).

### 4.2 12x128 and 3x16, 8T [NOISY-SHARED — my batteries ran concurrently]

| rig | before (this session, pre-change binary) | HEAD | descent phase (trees / gkr; a.round-g, a.tree-step, e.tree-witness) | digests |
|---|---:|---:|---|---|
| 12x128 8T | 21.2 s (2.5 / 16.6 / 1.3), 4.18 GB | **19.9 s** (3.0 / 14.8 / 1.6), 4.18 GB | 1.88 / 5.36 (4.03, 2.55, 1.87) -> **0.96 / 3.26** (2.77, 0.71, 0.95) | 4a3af8c3.. / 742d88e1.. identical |
| 3x16 8T | 4.5 s (ledger) | 4.7 s (0.9 / 3.1 / 0.6), 1.26 GB | 0.08 / 0.49 (0.33, 0.07, 0.08) | 93a98700.. / 0ae9cdae.. identical |

At 3x16 (depths 16-17, 3 real trees) the store engages (depth >= 14) and is
neutral within noise (the rig gate is the digest).

### 4.3 The benches, 8T [NOISY-SHARED]

| bench | before (L, ledger) | HEAD | notes |
|---|---|---|---|
| `uperf-h bench 20 8 5 9` (compact leaves, c = 2 — the rig's tree shape) | prove 0.72 s, a.round-g 0.500, a.tree-step 0.47 (x30), peak RSS 665 MiB, trees resident 255 MiB | **prove 0.42 s, a.round-g 0.368, a.tree-step 0.433 (x10: the device builds; the K9 init 0.3 s lands here in a fresh process), peak RSS 297 MiB, host-resident 45 MiB** | DESCENT DIGEST 0bf9d7a3.. |
| `uperf-n bench 20 8 5 9` (one process, store OFF then ON) | OFF: trees 0.224 / prove 0.666 (a.round-g 0.485; in-hook 0.46 = kernel 0.25 + upload 0.15; h2d 781 MB) | ON: trees 0.139 / prove 0.345 (a.round-g 0.292; in-hook 0.27 = kernel 0.20 + bind 0.02; h2d 115 MB of which the leaves 42 MB; 20 in-place bindings, 20 device climbs, 5 device builds 0.073 s, 0 host fetches; VRAM store peak 0.32 GB, K9 held peak 1.04 GB) | digest identical; host-resident 255 -> 45 MiB |
| `uperf-a descent-bench 20 8 5 9` (packed leaves) | prove 0.77-0.82 s, peak 1,100 MiB | **prove 0.39-0.42 s, peak 365 MiB** | 47a58a27.. |
| `uperf-l dbench 20 8 5 9` (CPU vs GPU in one process) | GPU prove 0.77, a.round-g 0.62, a.tree-step 0.25 | GPU prove 0.44, a.round-g 0.384, a.tree-step 0.225 (the packed leaves' 671 MB go up once as the tree's leaves: h2d 744 MB) | identical |
| `uperf-h bench 22 16 12 9` (THE PAIR SHAPE: 12 real depth-22 trees) | (Section 4.4) | | |

### 4.4 The pair shape (depth 22 x 16, 12 real, 4 pads; `uperf-h bench 22 16 12 9` as separate processes under `/usr/bin/time -v`, and `uperf-n bench 22 16 12 9` in one process) [WSL-BOX 8T NOISY-SHARED, flock]

| | trees | masked_gkr_prove | a.tree-step | a.round-g | h2d | witness trees resident after build | peak RSS (process) | VRAM |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| store OFF (`ZK_GPU_K9_TREE_STORE=0`: the CPU build + L's uploads) | 2.21 s | 4.16 s | 2.58 (x84: build + CPU recompute) | 3.10 | 7.1 GB | 2,436 MiB (host) | **4,212 MiB** | L's chains only |
| **store ON (default)** | **1.38 s** | **2.43 s** | **0.88** (x24: 12 device builds 0.59 s + the small-layer host loop) | **2.30** (in-hook 2.29 = kernels 1.83 + bind 0.13 + handover 0.03; 60 in-place bindings, 60 device climbs, 0 host fetches) | **0.69 GB** (the leaves 403 MB) | 396 MiB (the compact leaves' host copy) | **664 MiB** | store peak 2.77 GB, K9 held peak **6.82 GB** (model 6.5 + L's grow-only slack; budget 7.12 in this process; no decline) |

DESCENT DIGEST b527b531.. both ways. The pair's host footprint fell from
lane H's 1.75U (4.2 GB here) to the compact leaves + the state tables'
untouched calloc pages (0.66 GB); on the rig the pass's peak stays the claim
layer's (11.2 GB), so the maxrss does not move — the descents are no longer
a memory term on the host at all.

## 5. What is left / honest state

1. **The kernels are what remains of the descent** [MEASURED]: at 12x512
   the 7.3 s of a.round-g are 5.2 s of kernels (~16% of the part's peak,
   register-bound — lane L's Section 5.2: matrix-form fixed multiplies,
   halved burst folds, a 2-thread coefficient split, ~1.5-2x [ASSUMED]) and
   ~1.8 s of eq uploads (the b-part table per layer, 2^j x 64 B), parameter
   syncs and node readbacks (a ~0.2 ms floor per round x 1,233). The tree
   store removed the uploads/encodes and the CPU climbs; nothing of the tree
   travels the link any more except the compact leaves (33 MB per depth-22
   tree) and 2 MB per tree of top layer.
2. **The build's step kernel** (`k_tree_step[_cl]`, lane L's): ~42-45 ms per
   depth-22 tree, ~2 s per 12x512 pass in a.tree-step (45 trees). It is a
   3-K-mult-per-thread elementwise kernel with the 31-word u64 accumulator
   in registers; a per-warp coefficient split or the matrix form would cut it
   [ASSUMED]; not done (the descent's rounds are the bigger term).
3. **The eq table** is still built on the host (`kt_eq_table_par`, a.eq-table
   ~1.6 s at 12x512 CPU-side) and uploaded per layer; a device doubling from
   zeta would remove the upload and the CPU build (small; not done).
4. **VRAM headroom at 12x512 is ~0.3 GB** on this 8 GB part (6.5 GB modelled
   at j = 21 vs the 6.84 GB budget); a concurrent GPU user (lane O's
   batteries hold ~1 GB) can push a layer to the CPU path (correct, slower —
   the rigs run under the flock for that reason). The streaming-by-tree
   variant of the recomputed layer 21 (climb per range inside rounds 0 and 1
   instead of holding 3.2 GB between them) is designed, not built: it would
   trade 2x the climb work (~0.2 s) for 3.2 GB of peak.
5. **The store's checkpoint policy honors stride >= 2 only**; c = 0/1 (keep
   every layer) is 6.4 GB per 12x512 pair and stays a host-only knob.
6. **A device error while device trees are alive is fatal for their
   readers**: `k9_tree_fetch` panics with the tree/layer named if the store
   cannot answer (the host has no copy). Lane L's error path (fall back to
   the CPU for later calls) still holds for everything else; the store is
   kept across it.
7. **Not a Mac build**: CUDA-only, feature OFF elsewhere (as K/L).
8. The uperf-pc `full-profile` prints no k9 stats (not this lane's arm); the
   VRAM peaks are reported by `uperf-n bench` and the model above.
