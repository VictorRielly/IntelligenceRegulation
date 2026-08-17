# U-PERF2 lane H — descent tree memory: layer release + checkpointing + compact leaves (+ the tree pool question) — toward the 12x512 rig on the 15 GB box

Branch `uperf2-h` (worktree /home/victor/wt-uperf2-h), opened at d38e9ce
(the F + G merge) on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane H" +
"Agent H status". Box: the WSL box (Intel Core Ultra 9 185H, 22 threads,
15 GB; the local m125 re-export is here, so the 3x16 / 12x64 / 12x128
real-data rigs run). Every number carries `[WSL-BOX 1T|NT,
QUIET|NOISY-SHARED]`; lane I builds and runs in its own worktree during
the session.

STATUS: SKELETON (plan + model; nothing landed yet). Baselines captured
BEFORE any code change from the untouched d38e9ce binary (scratchpad
`ring_matmul_base_d38e9ce`): freeze-check 98 `ok` rows
(`h_freeze_baseline.txt`, identical to lane I's capture of the same
build); `uperf-a descent-bench 20 8 5 9` at 8T: prove 1.67 s, trees
0.41 s, peak RSS 1,558 MiB (maxrss 1,595,876 KB), DESCENT DIGEST
47a58a27.. [WSL 8T QUIET, load 0.02].

## 0. The problem in numbers (why the brief's checkpoint model is not enough on its own)

Units: at the 12x512 rig's peak pair (nrw-88: 16 trees, 12 real, depth
22) let U = one packed leaf table of the 12 real trees = 12 x 2^22 x 64 B
= 3.2 GB. Today (lane G's HEAD): every tree keeps every layer of p AND q
(2 x 2U = 4U = 12.9 GB) for the whole descent, and the fused kernel's
five state-1 work tables at the last layer are 1.25U (4.0 GB touched):
the pair's peak is ~5.25U = 16.9 GB on a 2-5 GB floor — off the box.

The masked descent walks the layers TOP-DOWN (round j reads layer j+1 of
every real tree, once: the fused rounds 0/1 read it directly, or the
eager flush extracts it once); nothing reads a layer again after its
round. So the honest accounting of what must be resident at round j is:
the layer j+1 (2^(j+1-depth) x 2U for p+q), the work tables of that round
(2.5 x 2^(j-depth) U at state 1), plus whatever of the tree is still
kept for LATER rounds — i.e. the layers BELOW j+1 that are stored. The
peak is at the BOTTOM: round depth-2 needs layer depth-1 (U) + work
0.625U (+ the leaves, still needed by round depth-1), and round depth-1
needs the leaves (2U) + work 1.25U.

| scheme | resident at round depth-2 | at round depth-1 | pair peak |
|---|---:|---:|---:|
| today (all layers, nothing released) | 4U + 0.625U | 4U + 1.25U | **5.25U = 16.9 GB** |
| RELEASE consumed layers top-down (no checkpointing) | 2U (leaves) + U (layer depth-1) + 0.625U | 2U + 1.25U | 3.625U = 11.6 GB |
| checkpoint every c-th layer, intermediate layers recomputed transiently, no release (the brief's model + the transient it forgot) | 2U + 2U/(2^c-1) + U (transient) + 0.625U | 2U + 2U/(2^c-1) + 1.25U | 3.9U (c=3) = 12.6 GB |
| checkpointing + release | 2U + U + 0.625U | 2U + 1.25U | 3.625U = 11.6 GB (c >= 2; c=1 keeps every layer: 4U at build end) |
| + COMPACT LEAVES (the witness tree's leaves are (0,1) / (1, alpha - v) with v on K-coordinates 0..1 only / 4 blinders — 8 B per leaf instead of 128 B: 2U -> 0.12U) | 0.12U + U (transient) + 0.625U | 0.12U + 1.25U (expanded on the fly) | **1.75U = 5.6 GB** |

Checkpointing therefore buys the peak nothing beyond the release once
the leaves dominate; what it buys is the RESIDENT set through the upper
rounds and at build end (with compact leaves: c=0 keeps 2.12U at build
end vs 0.79U at c=2 — so with compact leaves c matters again: 2.12U vs
1.75U). The choice c=2 (checkpoints at depth, depth-2, depth-4, ..: every
gap is ONE layer, recomputed by one threaded tree step from the checkpoint
below — +0.67 tree builds of K-work per pair) has the same peak as c=3/4
at the least recompute. Model at 12x512 with everything: nrw-88 pair
5.6 GB (+ small) on lane F's floor (2 GB with `ZK_W0_REGEN=1
ZK_CRS_MEMO=0`, ~4.7 GB default) -> ~8-10 GB — FITS the 15 GB box with
margin, IF the model holds (the 12x64 / 12x128 rigs calibrate it first).

## 1. Plan (in order; each step: build, batteries at 1/2/7T, a-bench digest 47a58a27, commit)

1. RELEASE + CHECKPOINTS (gkr.rs / kfield.rs / gkr_masked.rs): the packed
   tree's layer store becomes per-layer `RwLock<Option<(p, q)>>` (the
   descent takes `&[FracTree]` — interior mutability is what lets it give
   a consumed layer back); `FracTree::layer(k)` hands out a stored layer
   (a read guard), or RECOMPUTES a checkpoint gap from the nearest stored
   layer below on the threaded tree-step kernel (`k9_tree_climb_par`:
   chunked, positional, m levels through per-chunk scratch — the same
   block-local arithmetic as the build, bit-identical); `release_layer(k)`
   drops it. `masked_rounds_bulk` obtains layer j+1 once, feeds the fused
   rounds 0/1 (`FusedLayer.src`) or the flush's extract, and releases it
   as soon as the state-1 tables exist. Knobs: `ZK_K9_CHECKPOINT` (c;
   default 2; 0 = keep every layer), `ZK_K9_TREE_RELEASE` (default 1),
   both off under `oracle_mode()`. Layers of <= 4096 elements are always
   stored (roots, layer-1 quadruples, the scalar-tail layers).
2. COMPACT LEAVES (`kfield::CompactLeaves`, built directly by
   `gkr::build_aligned_witness_tree` when every member value has zero
   K-coordinates 2..15 — the rig's `fuse_pair` / `embed` values; the
   synthetic bench's uniform values fall back to the packed leaves): 2 x
   u32 per leaf (q's coordinates 0..1, the member flag in a free high
   bit) + alpha's tail + the blinders as exceptions; an expander writes
   the exact packed blocks (`KTab::set`'s layout) per chunk into
   cache-resident scratch for the tree step (build + the layer depth-1
   recompute), the fused extract rounds (sub-chunked per job), the eager
   extract, and per-element decode for the scalar paths. Knob
   `ZK_K9_COMPACT_LEAVES` (default 1).
3. `uperf-h {battery, bench}`: the battery = lane A's shapes with 2-coord
   member values, proven under {today's knobs} vs {c=2 / 3 / 4, compact,
   release} — digests identical + verified, at ZK_THREADS 1/2/7; the
   bench = the a-bench with 2-coord values (its own digest) so the peak
   RSS of the rig's leaf shape can be measured at depth 20 x 8.
4. Measure: a-bench peak RSS + wall for c in {0, 2, 3, 4} (separate
   processes); the REAL 3x16 1T/8T, 12x64 8T, 12x128 8T rigs (digests +
   maxrss + walls); then the model for 12x512 and, if it fits under ~13
   GB, the ONE run.
5. Tree pool (same-size only + a release hook from bk_pass_run's descent
   loop): only if it lowers the rig peak — expected NOT to (a pool cannot
   lower a peak; it trades faults for held RSS); measure and decide.
6. Report + ledger.

## 2. What landed (filled in as steps close)

(pending)

## 3. Measurements

(pending)

## 4. Differential evidence + gates

(pending)

## 5. The 12x512 run

(pending)

## 6. What is left

(pending)
