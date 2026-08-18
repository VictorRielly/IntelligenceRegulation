# U-PERF2 lane H — descent tree memory: layer release + checkpointing + compact leaves — the 12x512 rig RUNS on the 15 GB box

Branch `uperf2-h` (worktree /home/victor/wt-uperf2-h), opened at d38e9ce
(the F + G merge) on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane H" +
"Agent H status". Box: the WSL box (Intel Core Ultra 9 185H, 22 threads,
15 GB; the local m125 re-export is here, so the real-data rigs run).
Every number carries `[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`; lane I built
and ran in its own worktree during the whole session (load 1-7), so every
wall below is NOISY-SHARED unless marked QUIET; the RSS rows are
load-independent. Commits: 50d87ca plan, fd646f1 the code (items 1-3),
9466dfb interim ledger, + the report/ledger commit.

## 0. One paragraph

The masked descent reads every tree layer ONCE, top-down (round j reads
layer j+1 through the fused rounds 0/1 or the eager extract, and never
again), so a packed tree does not have to keep its layers resident for the
whole descent — and the honest peak of a descent pair is at the BOTTOM
rounds: layer depth-1 + the last rounds' work tables + THE LEAVES. Three
things landed, all bit-identical by construction and asserted eight ways:
(1) the packed tree's layers live in a per-layer `RwLock` store and the
descent gives each layer back as soon as its round has its state-1 tables
(`FracTree::layer` / `release_layer`); (2) the build stores the leaves,
every c-th layer above them and the small top layers (`ZK_K9_CHECKPOINT`,
default 2) and a gap layer is recomputed on demand by the threaded tree
step from the checkpoint below (`k9_tree_climb_par`); (3) the aligned
witness trees keep their leaves COMPACT — (0, 1) dummies, (1, alpha - v)
members with v on K-coordinates 0..1 (the rig's `fuse_pair` / `embed`
values), four blinders — as two u32 per leaf instead of 128 B, expanded
chunkwise into cache-resident scratch exactly as `KTab::set` would have
written them wherever a kernel reads the leaf layer (`kfield::CompactLeaves`).
The pair's peak footprint drops from ~5.25U to **1.75U** (U = one packed
leaf table of the pair's real trees; 3.2 GB at the 12x512 nrw-88 pair):
`uperf-h bench 20 8 5 9` peak RSS **1,557 -> 665 MiB** at 8T (digest
identical on every knob variant); the REAL 12x64 rig **4.03 -> 2.95 GB**,
12x128 **6.4-7.4 -> 4.15 GB**, and — for the first time on this box —
**12x256 (accept, 95.9 s @ 6.6 GB) and 12x512, THE PoC SHAPE: accept,
statement digest 2f8a92f8.., 1,509,911 B counted, EVAL-PROOF DIGEST
4c259008.., wall 166.4 s (commit 13.4 / prove 142.6 / verify 8.7) at
ZK_THREADS 8, maxrss 10.9 GB with the default knobs (9.5 GB with
`ZK_W0_REGEN=1`; same digests)** — the pass's peak is now lane D's claim
layer (5.65 GB transient), not the descents (the nrw-88 pair 5.6 GB = the
model's 1.75U exactly). Cost: the c=2 recompute adds ~0.7 tree builds of
K-work per pair (`bk.descent-gkr` +1.0 s of 43.8 at 12x64 8T; the compact
fill gives 0.85 s back on `bk.descent-trees`); `ZK_K9_CHECKPOINT=0` keeps
every layer (no recompute) at +0.37U of pair peak. What did NOT land: the
same-size tree pool — measured with lane G's arena on the new bench (+70
MiB / +600 MiB peak at 256 MB / 1 GB pools, prove within noise): a pool
cannot lower a peak, and the descent is no longer the pass's peak, so it
has no target; not built (item 2's decision, Section 4).

## 1. The model (why the brief's checkpoint arithmetic was not enough)

Units: at the 12x512 rig's peak pair (nrw-88: 16 trees, 12 real, depth 22)
let U = one packed leaf table of the 12 real trees = 12 x 2^22 x 64 B = 3.2
GB. Before this lane every tree kept every layer of p AND q (4U) for the
whole descent, and the fused kernel's five state-1 work tables at the last
layer are 1.25U: the pair's peak was ~5.25U = 16.9 GB on a ~5 GB floor.

Resident at round j (top-down): the layer j+1 it reads (2^(j+1-depth) x 2U
for p+q), that round's work tables (2.5 x 2^(j-depth) U at state 1), plus
whatever of the tree is still kept for LATER rounds — the stored layers
BELOW j+1. Hence the bottom rounds set the peak: round depth-2 needs layer
depth-1 (U) + work 0.625U (+ the leaves, still needed by round depth-1);
round depth-1 needs the leaves + 1.25U.

| scheme | at round depth-2 | at round depth-1 | pair peak (12x512) |
|---|---:|---:|---:|
| before (all layers, nothing released) | 4U + 0.625U | 4U + 1.25U | **5.25U = 16.9 GB** |
| release consumed layers top-down, no checkpointing | 2U + U + 0.625U | 2U + 1.25U | 3.625U = 11.6 GB |
| checkpoint every c-th layer, gaps recomputed transiently, no release (the brief's model + the transient it forgot) | 2U + 2U/(2^c-1) + U + 0.625U | 2U + 2U/(2^c-1) + 1.25U | 3.9U (c=3) = 12.6 GB |
| checkpointing + release | 2U + U + 0.625U | 2U + 1.25U | 3.625U (c >= 2) |
| + COMPACT LEAVES (2U -> 0.12U) | 0.12U + U + 0.625U | 0.12U + 1.25U | **1.75U = 5.6 GB** (c=2; c=0 keeps 2.12U at build end) |

Checkpointing buys the peak nothing beyond the release once the leaves
dominate; what it buys is the resident set through the upper rounds and
at build end — with compact leaves c matters again (2.12U vs 1.75U). c=2
(checkpoints at depth, depth-2, depth-4, ..: every gap is ONE layer,
recomputed by one threaded tree step from the checkpoint below) has the
same peak as c=3/4 at the least recompute (+0.67 tree builds of K-work per
pair; c=3 +1.43, c=4 +2.27). Measured on the bench (Section 3.1) and on
the rigs (3.2): the model is exact — nrw-88 at 12x128 1.5 GB (model 1.4),
12x256 3.0 (2.8), 12x512 5.6 (5.6).

## 2. What landed (all at fd646f1)

| item | where | how | oracle / knob | status |
|---|---|---|---|---|
| per-layer store + release | gkr.rs `PackedTree { layers: Vec<RwLock<Option<(KTab, KTab)>>>, compact, kern }`, `FracTree::layer(k) -> LayerSrc` (Stored guard / Owned recompute / Compact), `release_layer(k)`, `resident_bytes()`; gkr_masked.rs `masked_rounds_bulk` obtains layer j+1 once (`lay_src`), feeds `FusedLayer.src` (rounds 0/1) or `flush_state`'s extract, and releases it as soon as `tabs` exist; `extract_children[_par]` read through handles | the descent holds only `&[FracTree]` — interior mutability is what lets it give a consumed layer back; small layers (<= 4096 elements: roots, layer-1 quadruples, scalar-tail layers) are always stored, never released | `ZK_K9_TREE_RELEASE` (default on; off under `oracle_mode()`); a layer read after its release is recomputed from below when a stored layer exists there (correct, slow) and panics otherwise | LANDED |
| checkpointed build + recompute | gkr.rs `build_tree_from(kf, LeafStore)` (every layer computed from the one below exactly as before — `k9_tree_step_par`, or the serial step under `oracle_mode()` — but only the leaves, layers depth - m*c and the small top layers STORED); kfield.rs `k9_tree_climb_par(kern, BlkSrc, levels, ..)` (chunked, positional, m levels through per-chunk ping-pong scratch; levels == 1 over a packed source IS the build's own threaded step) | every output block is `tree_step_body`'s block-local arithmetic on the same source blocks the layered build reads — the same integers | `ZK_K9_CHECKPOINT` (c; default 2; 0 or 1 = every layer stored = the pre-change layout; always 0 under `oracle_mode()`); `k9_set_checkpoint_stride` in process | LANDED |
| compact leaves | kfield.rs `CompactLeaves` (n, 2 u32 per leaf: q's canonical coordinates 0..1 with the member flag in the free bit 31 of the second word — a zero pair is the (0, 1) dummy; alpha's tail; exceptions (index, p, q) sorted), `expand_blocks` (the exact packed-block bytes), `BlkSrc { Packed, Compact }` + `blocks(blk0, nblk, scratch)`; gkr.rs `build_compact_leaves` (probes each block's value(0) tail, fills member pairs in parallel per row chunk with `Zq::sub` = `KField::sub`'s per-coordinate arithmetic, asserts every tail on the way, falls back to the packed builder otherwise — the closures are pure); consumers: the tree step (build + recompute) through `BlkSrc::blocks`, the fused extract rounds (`FusedJob.compact`: per-job sub-chunks of 32 pair-blocks expanded into 128 KB scratch, the same kernel per sub-chunk — per-pair-block state only, exact-integer planes: any sub-chunking is identical), the eager `extract_children_par` (per chunk), `get_p/get_q` for the scalar paths | the same packed blocks reach the same kernels; the synthetic a-bench's uniform values fall back to the packed leaves (its digest 47a58a27.. proves the release/checkpoint half alone) | `ZK_K9_COMPACT_LEAVES` (default on; off under `oracle_mode()`); needs n >= 16 | LANDED |
| `uperf-h {battery, bench}` | bin `// [UPERF2-H]`: `uperf_h_descent_pair` = lane A's pair with 2-coordinate member values (SiLU-shaped (u0, u1) and range-shaped embed(u)); the battery proves 12 shapes x {masked, zero masks} EIGHT ways (boxed scalar oracle == pre-change layout (c=0, packed leaves, no release) == c2 == c3 == c4 == c0+compact+release == c2 alone == c2 with fusion OFF), every proof verified, and prints the trees' resident bytes per variant | — | LANDED |
| same-size tree pool + release hook | not built (Section 4) | — | lane G's `ZK_K9_ARENA_MB` + `k9_arena_clear` remain the experiment path | DECIDED NEGATIVE |

Bin edits: the `uperf-h` arm in `main` + the appended section only;
`bk_pass_run`'s descent loop needed no change (the release happens inside
`masked_gkr_prove`). No transcript absorption, mask sampling, tree/leaf
layout on the wire, or RNG order changed.

## 3. Measurements

### 3.1 The benches (depth 20 x 8, 5 real + 3 pads, dt 9) [WSL 8T; the baseline row QUIET (load 0.02), the rest load 1-3]

`uperf-h bench 20 8 5 9` (2-coordinate member values — the rig's leaf
shape; DESCENT DIGEST 0bf9d7a3.. on every row):

| knobs (ckpt / release / compact) | peak RSS | witness trees resident after build | prove 8T | a.tree-step |
|---|---:|---:|---:|---:|
| 0 / off / off (the pre-change layout) | 1,557 MiB | 1,280 MiB | 1.75 s | 0.31 s x10 |
| 0 / on / off (release alone) | 1,162 | 1,280 | 1.74 | 0.29 |
| 0 / on / on (+ compact leaves) | 733 | 680 | 1.74 | 0.28 |
| **2 / on / on (default)** | **665** | 255 | 1.97 | 0.47 x30 (the recompute) |
| 3 / on / on | 696 | 135 | 2.11 | 0.65 x35 |
| 4 / on / on | 635 | 85 | 2.26 | 0.85 x40 |
| 2 / off / on | 868 | 255 | 1.90 | 0.47 |

The model at this shape: U = 5 x 2^20 x 64 B = 320 MiB, 1.75U = 560 MiB +
the table side and the process baseline (~100 MiB) = ~660: the measured
665. c=3/c=4 do not lower the bottom-round peak (they trade resident set
above it for K-work); c=2 is the default.

`uperf-a descent-bench 20 8 5 9` (lane A's bench, uniform values -> packed
leaves; DESCENT DIGEST 47a58a27.. on every row): peak 1,558 (baseline
QUIET) -> 1,162 (c=0) / 1,100 (c=2) / 1,098 (c=3) / 1,055 (c=4) MiB; prove
1.67 (baseline) / 1.71 / 1.91 / 2.13 / 2.28 s at 8T.

Lane G's arena on the new bench (`ZK_K9_ARENA_MB`, default knobs,
[NOISY]): 0 MB peak 666 MiB / prove 2.20 s; 256 MB 734 / 2.15; 1 GB 1,272
/ 2.18 — the pool's held set is RSS and the faults it saves are ~2%
(noise) — Section 4.

### 3.2 The REAL rigs [WSL 8T NOISY-SHARED unless marked; digests identical to the ledger on every run]

| rig | before (d38e9ce merge row / same-day baseline) | HEAD fd646f1 | notes |
|---|---|---|---|
| 3x16 8T | 9.35 s @ 1,031 MB (same-day, QUIET) | 9.8 s @ 1,033 MB (load 1.7) | bk.descent-gkr 0.91 -> 1.02, bk.descent-trees 0.24 -> 0.16, pair-nrw-88 hwm 657 -> 587 MiB; the process peak is not in the descent phase |
| 3x16 1T | 28.6 s (merge row, QUIET) | 34.1 s @ 962 MB (load ~6: lane I + this lane's self-test) | accept, digests identical; wall NOISY |
| 12x64 8T | 42.1 s @ 4,034 MB (same-day) | 43.8 s @ **2,948 MB** (load 2) | pair-nrw-88 hwm 3,940 -> 2,879 MiB (transient 1.9 -> 0.8 GB); bk.descent-gkr 7.87 -> 8.89 (a.tree-step 1.77 -> 2.46: the recompute), bk.descent-trees 2.57 -> 1.73 (a.tree-pack 0.79 -> 0.13: the compact fill) |
| 12x128 8T | 58.3 s @ 6.4 GB (merge row) / 66.2 s @ 7.44 GB (lane F) | 59.7 s @ **4,153 MB** (load 3) | pair-nrw-88 hwm 6,245-7,438 -> 4,056 MiB (transient 4.9 -> 1.5 GB); bk.descent-gkr 14.5 -> 16.1, bk.descent-trees 4.5 -> 3.1 |
| **12x256 8T (FIRST on this box)** | not attempted (lane F: ~14 GB [MODEL]) | **accept, statement digest 889c0f1298c7892385f953b8a2d4052b4cf42a6a68747e0af5233982c05c231d, 1,439,719 B counted, EVAL-PROOF DIGEST 97a59ac3b99fd6c8c380d466413e54ff32e628e4dd31eecdc9ee7837207b3736, wall 95.9 s (commit 8.4 / prove 80.8 / verify 5.7), maxrss 6,608 MB** | claim-layer-end hwm 6,243 (transient 2.8 GB on rss 3,409), pair-nrw-88 hwm 6,453 (3.0 GB on 3,445); bk.descent-gkr 33.1, bk.descent-trees 6.2, bg.level-h 15.8, bg.claim-layer 12.3 |
| **12x512 8T (THE PoC SHAPE, FIRST on this box)** | not attempted (~40 GB before lane F, ~20-24 GB after) | see Section 5 | |

RSS rows per phase at 12x64 8T (hwm / rss in MiB, before -> after):
bk.claim-layer-end 2,746 / 2,027 -> 2,746 / 2,027; bk.pair-nrw-88 3,940 /
2,066 -> **2,879 / 2,066**; bg.weight.level1 3,940 / 2,328 -> 2,879 /
2,328; maxrss 4,034,500 -> 2,948,300 KB.

### 3.3 The cost of the recompute (c=2) and where the time went

Per pair the c=2 policy recomputes layer depth-1 from the leaves (0.5 tree
builds of K-work) and every second layer above (geometric, 0.17 builds):
+0.67 builds; the compact leaves make the first step (leaves -> layer
depth-1) cheaper (no 64 MB-per-tree page-faulting leaf tables to read)
and the compact fill replaces the packed fill: at 12x64 8T a.tree-step
1.77 -> 2.46 s (+0.69) against a.tree-pack 0.79 -> 0.13 (-0.66) and
e.tree-witness 2.56 -> 1.72 (-0.84) — the descent phase (`bk.descent-trees`
+ `bk.descent-gkr`) 10.44 -> 10.62 s, i.e. neutral within the box's noise;
at 12x512 8T bk.descent-gkr 61.4 s (a.round-g 52.3, a.tree-step 15.9 —
of which the recompute ~6-7 s [MODEL from the c=0 bench ratio]) and
bk.descent-trees 10.8 s. `ZK_K9_CHECKPOINT=0` removes the recompute
(bench prove 1.74 vs 1.97 s at 8T) for +0.37U of pair peak (12x512: +1.2
GB — the pass would still fit this box at ~11.9 GB [MODEL], the claim
layer being 10.7 GB); the Mac's T1 run can take it. The 1T ratio is the
same (the recompute is the same fraction of the descent's K-work).

## 4. Item 2 — the same-size tree pool: decided NOT to build

The brief asked for a same-size pool across a pair's trees and across
pairs plus a release hook from `bk_pass_run`, "only if it lowers the rig
peak". It cannot: a pool never lowers a peak (it trades page faults for
held RSS); with the layers now released as they are consumed and the
leaves compact, the buffers a pair allocates fresh are the recomputed
layer depth-1 (U, all 12 trees at once — no two of them ever free while
another is needed), the five state-1 tables (sizes halving per layer — no
exact match within a pair) and the top layers (small); across pairs only
same-depth pairs could reuse (nrw-88 is the only depth-22 pair at 12x512),
and the held set would sit resident through the next pair's peak. Lane G
measured its arena negative on the packed-leaf bench; on the new bench
(2-coord leaves, c=2) it is negative again: 256 MB pool +70 MiB peak, 1 GB
pool +600 MiB, prove within noise (Section 3.1). And the pass's peak is no
longer in the descent phase (Section 5). Not built; lane G's opt-in arena
+ `k9_arena_clear()` stay as the experiment path.

## 5. The 12x512 run — the PoC number on the reference box [WSL 8T NOISY-SHARED, lane I active, load 3-7]

`M125_EXPORT_DIR=results/m125_ffn_export_wsl ZK_THREADS=8 uperf-pc
full-profile 12 512` under the flock, `free -g` 13 GB available before
each run. Model before the run: floor (rss before the pairs) 2.05 (T=64) ->
2.53 (128) -> 3.45 (256) => ~5.3 GB at 512 [linear in T]; the claim
layer's transient 0.72 -> 1.43 -> 2.83 => 5.7 GB; the nrw-88 pair 0.8 ->
1.5 -> 3.0 => 6.0 GB (1.75U = 5.6): peak ~11.3 GB.

| run | accept | statement digest | bytes | EVAL-PROOF DIGEST | wall (commit / prove / verify) | maxrss |
|---|---|---|---:|---|---|---:|
| default knobs | **true** | 2f8a92f853c1813b4d87e30dc9a43a9cb65b0e009c994fffa67e14a6132b81ab | 1,509,911 | 4c259008c8e0cac2cf654471d37f937c4d1fd3dea51730520aa4256782ddf9dd | **166.4 s (13.4 / 142.6 / 8.7)** | **10,945,192 KB (10.7 GB hwm)** |
| `ZK_W0_REGEN=1` (lane F's knob) | true | same | same | same | 178.3 s (13.6 / 154.1 / 8.7) | 9,535,284 KB (9.3 GB hwm) |

RSS rows (default knobs, hwm / rss MiB): bk.layers-loaded 1,550 / 1,550;
bk.witness-built 2,942; bk.precommit 6,297 / 5,037; bk.commit-end 6,297 /
5,039; **bk.claim-layer-end 10,689 / 5,043 (the pass's peak: lane D's
packed claim tables, 5.65 GB transient)**; bk.pair-nrw-88 10,689 / 5,099
(the pair's 5.6 GB fits under it: 5,099 + 5,600 = 10,699); bk.groups-start
10,689 / 5,218; bg.weight.level1 10,689 / 5,460; bk.verify-act-end 10,689 /
5,701. With `ZK_W0_REGEN=1`: bk.w0-freed rss 3,647; claim-layer-end hwm
9,298; pair-nrw-88 hwm 9,312 / rss 3,708 (the pair 5.6 GB); w0-rebuilt rss
5,218.

Phase table (default knobs, 8T, seconds; process-global prof rows):

| phase | s | | phase | s |
|---|---:|---|---|---:|
| bg.commit-phase | 13.4 | | bk.descent-trees (x20) | 10.8 |
| d.precommit-u0 (x2) | 11.6 | | bk.descent-gkr (x20) | 61.4 |
| d.chain-derive (x12) | 1.5 | | a.round-g (x2367) | 52.3 |
| d.digit-witness (x2) | 1.3 | | a.tree-step (x307, build + recompute) | 15.9 |
| bg.claim-layer | 25.4 | | a.eq-table (x265) | 1.6 |
| d.cl-tables (x8) | 6.9 | | a.tree-pack (x90) | 0.8 |
| d.cl-rounds (x138) | 7.3 | | e.tree-witness (x55) | 10.8 |
| d.cl-folds (x138) | 11.3 | | bg.prove-group (x2) | 44.7 |
| bg.level-h (x17) | 25.6 | | ep.psi0-factored (x4) | 12.8 |
| bg.matvec-chunks (x17) | 9.4 | | ep.matvec (x40) | 9.7 |
| bg.fold (x17) | 5.0 | | ep.transport (x30) | 3.3 |
| bg.kernel-rows (x2) | 3.6 | | ep.crs-expand (x36) | 3.4 |
| bg.verify-group (x2) | 8.5 | | e.kpass/psi0-smallcols | 0.5 |

Reading: prove 142.6 s = claim layer 25.4 + descents 72.2 + the two group
proofs 44.7; the descents are 43% of the prove at 8T on this box (a.round-g
52.3 s — lane G's fused kernel), the claim layer 18%, the group proofs
31%. The verify is 8.7 s. Both runs [WSL 8T NOISY-SHARED — lane I's legs
overlapped: load 3.2 at the first run's start, 6.9 at the second's].

## 6. Differential evidence + gates (all at fd646f1)

- `uperf-h battery` 24 legs (12 shapes: depths 4-17, l 1-16, pads 0-7, cols
  768 in a 1024 stride so dummies sit inside member rows) x {masked, zero
  masks}, EIGHT ways: boxed scalar oracle == pre-change layout (c=0,
  packed leaves, no release) == c2 == c3 == c4 == c0 + compact + release
  == c2 alone == c2 with fusion OFF (the eager extract over compact
  leaves) — every digest identical, every proof verified with pins;
  BATTERY DIGEST b1e78285762350514edbe1ddb8b852dc07c3210160546e1c937ddb944bc76e5c
  identical at ZK_THREADS 1, 2, 7.
- `uperf-a descent-battery` 18/18 (f936ff79.., unchanged) at 1/2/7T;
  `uperf-g descent-battery` 22/22 four-way (6d6a3f6b.., unchanged) at
  1/2/7T.
- `uperf-a descent-bench 20 8 5 9`: DESCENT DIGEST 47a58a27.. at c = 0, 2,
  3, 4 (8T) and 1T; `uperf-h bench`: 0bf9d7a3.. on all seven knob variants
  and with the arena on.
- `uperf-pc diff-battery`: O1 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2 at
  ZK_THREADS 1 (and 7 — see the ledger's close entry).
- freeze-check: 98 `ok` rows identical to the pre-change capture
  (scratchpad h_freeze_baseline.txt = lane I's capture of the same build;
  then the expected BF panic).
- REAL 3x16 at ZK_THREADS 1 and 8: accept, statement digest 93a98700..,
  985,142 B, EVAL-PROOF DIGEST 0ae9cdae..; REAL 12x64 8T: 80763ea5.. /
  63f4a3a4..; REAL 12x128 8T: 4a3af8c3.. / 742d88e1.., 1,372,775 B; the
  new shapes 12x256 and 12x512 twice each (Section 3.2 / 5) — every digest
  identical on every run.
- `self-test`: see the ledger's close entry.

## 7. What is left (honest state at close)

1. **The pass's peak is now the CLAIM LAYER** (lane D's packed tables:
   5.65 GB transient at 12x512 on a 5.0 GB floor -> 10.7 GB); the descent
   pair is under it (5.6 GB). The next memory lever is there (per-instance
   streaming of the ixf tables, or a smaller table batch), not in the
   descents; after it the floor (lays 1.5 GB as i64, w0 i8 1.4 GB, the CRS
   memo ~1.9 GB — lane F's Section 6) is what remains.
2. The c=2 recompute (+0.67 tree builds per pair, ~+1 s of the 12x64 pass
   at 8T, ~+7 s at 12x512 [MODEL]) is the price of 0.37U of pair peak; a
   time-first box sets `ZK_K9_CHECKPOINT=0`. A one-line variant (checkpoints
   at depth-1, depth-3, ..) would halve the recompute for +0.18U — not
   built (the pair is no longer the peak).
3. Compact leaves apply to the aligned witness trees (the rig's); the
   table trees (`blinded_table_tree`, dt <= 11) and the generic builders
   keep packed leaves — nothing to gain there. A tree whose member values
   have nonzero K-coordinates 2..15 (the synthetic a-bench) takes the
   packed leaves automatically.
4. The pool question is closed negative (Section 4).
5. Not measured here: the Mac (TASK_BOARD T1) — every number above is this
   box, 8T, with lane I running; the 3x16 1T row is NOISY (34.1 s vs the
   28.6 s merge row) and should be re-taken quiet.
