# U-PERF2 lane E — descent callers, descent VERIFY attribution, small-cols aux tensors

Branch `uperf2-e` (worktree /home/victor/wt-uperf2-e), opened at d3a4602
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane E" + "Agent E status".
Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB; the local
m125 re-export IS here, so the 3-layer x 16-token FULL-STATEMENT rig
runs). Every number carries a label `[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`
(NOISY-SHARED = lane D was building or running at the same time; the
load stayed at 1.0-1.9 through most of the session, so most rig numbers
below are NOISY-SHARED and repeat within ~5% at 1T).

## 0. One paragraph

Three things landed, all transcript-identical (the 3x16 real-data rig
prints the same statement digest 93a98700.., 985,142 B, EVAL-PROOF
DIGEST 0ae9cdae.. and `accept = true` at ZK_THREADS 1 and 8, fast and
under `ZK_UPERF_ORACLE=1`; `uperf-a descent-battery` 18/18 three-way at
1/2/7 threads; `uperf-pc diff-battery` E2E; freeze-check's 98 rows
identical to the pre-change capture). (1) The descent-tree callers ride
lane A's drop-ins and one step further: `descent_fold::aligned_witness_tree`
now runs a STREAMED, threaded packed builder (`gkr::build_aligned_witness_tree`
— member values generated on the fly by closures over the bin's integer
layer data, positional fill per member over row chunks of whole lane
blocks, the q table filled blockwise in parallel and the p table left
calloc-zero) and `neutral_tree` is lane A's compact `FracTree::Neutral`;
the boxed leaf pair AND the boxed member columns of `bk_tree_slots` no
longer exist on the fast path. The tree phase of the depth-20 x 8 pair
bench goes **1.68 s -> 0.40 s at 8T** (a.tree-pack 0.44 -> 0.05 s; trees
2.68 -> ~1.7 s at 1T), digest 47a58a27..dafefb identical. (2) The descent
VERIFY was attributed with `e.*` timers: on the 3x16 rig the verifier's
whole pair loop (mask shells, `masked_gkr_verify`, root cross-checks,
`bk_pair_claims`) costs **0.06 s** — the "descents verify" term is NOT
there; it is the misaligned aux tensors' K-weight rows inside
`bg_verify_group` (psi generic branch: 3.51 s of the 6.9 s verify) plus
the same rows in the prover's kernel passes (7.33 s of the 31.9 s prove).
(3) Those rows are now HOISTED (`kw_hoist` / `kw_row_hoisted`: per kernel
the scaled column kernel scale *_K col once and the nonzero row-kernel
bounds; per value ring one K-mult per nonzero (kernel, c1) instead of two
per (kernel, c1) for every kernel): the term goes **7.33 -> 0.38 s (prove)
and 3.51 -> 0.19 s (verify)** — the 3x16 rig at 1T **43.3 -> 36.3 s wall
(prove 31.9 -> 27.5, verify 6.9 -> 3.7)**, at 8T 16.6 -> 15.7 s (verify
1.9 -> 1.3) [WSL NOISY-SHARED], byte-identical (`uperf-e diff-battery`:
24 tensors' K-weight rows three ways, 8 kernel passes fast == oracle ==
`bg_kernel_pass`, 8 psi0 legs; BATTERY DIGEST 59117121.. identical at
ZK_THREADS 1/2/7). What did not land: the K-basis (rows-inside-the-ring)
form of the small-cols pass — measured unnecessary after the hoist (the
whole term is 0.57 s at 3x16, ~1.5 s [MODEL] at 12x512); the descent
kernels themselves (fold/extract fusion) sit in kfield.rs, lane D's file
this round.

## 1. Item 1 — the descent-tree callers on lane A's drop-ins (and one step further)

What the callers did before: `descent_fold::aligned_witness_tree`
allocated 2 x 2^depth boxed `Vec<u64>` leaves, wrote the members and
blinders into them, and `gkr::build_tree` packed and freed them (~1.4 GB
of transient heap and ~1 s of malloc/free per depth-22 tree — lane A's
Section 7 item 1); `neutral_tree` did the same for the pads before
`build_tree` detected the all-neutral leaves; and the bin's
`bk_tree_slots` materialized every member column as boxed K-elements
first (up to 2^(depth-1) small allocations per tree at the rig).

What they do now (fast packed path; scalar field / `ZK_UPERF_ORACLE=1`
keep the pre-change boxed bodies, bit-identically):

- `gkr::build_aligned_witness_tree(kf, alpha, depth, blocks, blinders)`
  (NEW): `AlignedBlock { base, rows, cols, cols_pad, value: &dyn Fn(f) ->
  KElem }` per member; the packed leaf tables are `KTab::zeroed` (p —
  the zero element IS the calloc fill, no page touched) and a blockwise
  PARALLEL fill of `one` (q), then per member a `par_chunks_mut` over row
  chunks (~4096 leaves) — each chunk is a contiguous range of whole
  KL-lane blocks whenever `base` and `cols_pad` are multiples of KL (the
  planner's aligned bases and power-of-two strides; a block that is not
  is written serially) — writing (1, alpha - value(f)) positionally, the
  blinders last, then lane A's threaded `build_tree_packed`.
- `descent_fold::aligned_witness_tree_fn` (NEW: slots = (shape, base,
  &dyn Fn(f) -> KElem)) and `aligned_witness_tree` (same signature as
  before, now a wrapper reading its columns in place).
- `descent_fold::neutral_tree` -> `gkr::build_neutral_tree`.
- bin: `bk_tree_slot_fns` (closures over `bk_member_vals`: fuse_pair /
  embed(prim + offset) per element) feed `aligned_witness_tree_fn`;
  under `oracle_mode()` the pre-change `bk_tree_slots` +
  `aligned_witness_tree` run.
- `gkr::build_tree_sparse` (lane A's; used by blinded_witness_tree /
  blinded_table_tree): zero defaults calloc-untouched, nonzero defaults
  parallel blockwise fill (same bytes as `KTab::filled`).

`uperf-a descent-bench 20 8 5 9` (5 real depth-20 witness trees + 3 pads
+ the dt-9 table side; digest 47a58a2742f9e656ec07f7b14ff696d1ff8092333fb3f6883d7aa95224dafefb
on EVERY line) [WSL-BOX NOISY-SHARED]:

| step | trees 1T | trees 8T | a.tree-pack 1T / 8T | a.tree-step 1T / 8T | peak RSS |
|---|---:|---:|---:|---:|---:|
| lane A HEAD (a450b1f; its report's repeat) | 2.68 s | 1.54-1.68 s | 0.44 / — | 1.06-1.27 / 0.33 | 2,419 MiB |
| + drop-ins wired (`build_tree_sparse` entries, `build_neutral_tree`) | 1.59 s | 0.69 s | 0.29 / 0.35 | 1.27 / 0.32 | 2,276 MiB |
| + streamed threaded builder (values on the fly, parallel q fill, calloc p) | 1.74 s (noisier box) | **0.40 s** | 0.19 / **0.05** | 1.52 / 0.31 | 2,087 MiB |

Where the pack time went (temporary probe, then removed): at depth 20
`KTab::filled` x2 cost 35-50 ms per tree — the page faults + memset of
two fresh 64 MB tables — and the streamed leaf loop 5 ms (8T) / 12 ms
(1T); the sparse builder's serial entry loop was ~50 ms. So the leaf
tables' allocation was the pack, not the leaves: the p table now stays
calloc-zero (its pages are faulted in by the threaded tree step) and the
q fill runs in parallel. What remains of the tree phase is `a.tree-step`
(lane A's threaded k9 step, kfield.rs — lane D's file this round) and
~0.05 s of glue.

Rig (3x16, T = 16 — trees at depth ~16-17 are tiny here):
`bk.descent-trees` 0.46 -> 0.48 s at 1T (noise; 0.22 s at 8T),
`e.tree-slots` 0.01 -> 0.00 s, `e.tree-witness` 0.44-0.48 s.

At the rig's shape [MODEL, linear in leaves from the depth-20 rates]:
61 real trees at depth 21-22 (x2-4 the leaves): the callers' pack + slot
churn ~1 s x 61 = ~1 minute pre-change (lane A's estimate) -> ~0.03 s x
4 x 61 = ~7 s at 1T, ~1.5 s at 8T; the threaded tree steps (~1 s per
depth-22 tree at 1T, ~0.25 s at 8T on this box) are now the tree phase.

## 2. Item 2 — where the descent VERIFY goes (attribution)

`e.*` phases (observation-only `prof::timer`s; ct_engine::prof ids 40-49)
around the verifier's pair loop and inside `bk_pair_claims`, plus the
prover's descent-phase pieces and the two generic kernel branches. The
3x16 rig at 1T (verify 6.9 s, 9 pairs = 18 masked descents at witness
depths ~16-17 / table depths 6-11) [WSL NOISY-SHARED]:

| phase | seconds | calls | what |
|---|---:|---:|---|
| e.verify-shells | 0.00 | 18 | `zero_masks` shells |
| a.gkr-verify | 0.02 | 18 | `masked_gkr_verify` (both sides, all pairs) |
| e.verify-cross | 0.00 | 9 | root cross-checks + pad layer-1 checks |
| e.claims-mask | 0.02 | 18 | `bk_pair_claims` mask-opening claims (~4 x depth per side) |
| e.claims-witness | 0.01 | 18 | witness publics (eq tables over cols_pad/rows bits, block prefixes, blinder rows) |
| e.claims-table | 0.01 | 18 | table publics |
| **pair loop total** | **0.06** | | the descent verify proper |
| e.psi0-smallcols | **3.51** | 27 | `psi_level0_factored_multi`'s generic branch on the 27 misaligned aux tensors (bl / wm / tm, cols = 16) — INSIDE bg.verify-group |
| ep.psi0-factored (all) | 5.25 | 2 | of which the aligned tensors 1.74 |
| bg.verify-group | 6.86 | 2 | |

Finding (E-F1): the "descents verify" is not a descent-verify cost. Every
piece of the pair loop is O(depth) or O(2^lcp + 2^lr) K-field work (a
few ms per pair at any depth: `masked_gkr_verify` runs ~(depth+e)^2/2
rounds of a handful of K-mults each; the mask claims allocate ~4 x depth
rows of n_kel K-elements; the witness publics build eq tables of
cols_pad = 1024 and rows <= 512 entries) — at 12x512 that is well under 1 s
in total. What the descent pairs add to the verify is the 40 aux tensors
(m aligned; bl / wm / tm misaligned with cols = 16 and l0 = 16 q-range
limbs) and their ~90 claim kernels per pair inside `bg_verify_group`:
per value ring the generic branch built the K-weight row with 128 x
n_kernels x 2 K-mults (n_kernels ~4 x depth), i.e. ~10-20 ms per value
ring x ~50-160 value rings x 27 tensors. On the Mac's 12x512 run that
share was measured before d3ec01f (which stopped recomputing the row per
DIGIT ring — 137 of the 142 s verify at 3x16 on this box); what remained
after d3ec01f is exactly the term item 3 removes. Nothing in the pair
loop needed a change; the fix is item 3.

Prover side of the same phase (3x16, 1T): bk.descent-trees 0.46 s,
bk.descent-gkr 2.51 s (a.round-g 1.14, a.fold 0.76, a.eq-table 0.26,
a.extract 0.25, scalar tail 0.03, glue ~0.1) — the T = 16 descents are
small here; the depth-20 bench is the right instrument for them and its
numbers are in Section 1.

## 3. Item 3 — the small-cols aux tensors (cols = 16, l0 = 16)

The BK aux tensors `bk-bl-*` (n_real x 16 rows), `bk-wm-*` / `bk-tm-*`
(the mask coefficient tensors, ~4 x depth kernels each) have cols = 16
(K_DEG) — misaligned for the O5 factored path — and their claim kernels
are the mask-opening pins: each row kernel is nonzero on ONE
coefficient block (a layer's g coefficients, or 6 R coefficients), the
col kernel is the shared [Y^0 .. Y^15]. Both generic branches
(`kernel_pass_factored`'s `if t.cols % D != 0` and
`psi_level0_multi_impl`'s `if !aligned`) built each value ring's
K-weight row as kw[c1] = sum_k scale_k *_K row_k[f/cols] *_K
col_k[f%cols] over EVERY kernel — 128 x n_kernels x 2 K-mults per value
ring; the bench at 1040 x 16 with 80 block-row kernels: 4,489 us per
value ring.

The hoisted form (`kw_hoist` once per tensor: scol_k[c] = scale_k *_K
col_k[c] for c < cols, plus the nonzero row bounds [lo, hi) of row_k;
`kw_row_hoisted` per value ring: for the kernels whose row bounds meet
the ring's rows, one K-mult row_k[f/cols] *_K scol_k[f%cols] per c1 whose
row factor is nonzero, summed in kernel order): 106 us per value ring
(42x). Identity: K is a field — scale *_K (row *_K col) = row *_K (scale
*_K col) with canonical coordinates — and every skipped term is an exact
zero, so the K-weight row is bit-identical (asserted three ways per
value ring by the battery: `kw_value_row_ref` == the pre-change
`kw_value_row_sync_ref` == `kw_value_row_hoisted`); everything
downstream (bpolys, the 16 alpha ring-mults per value ring, the radix
scaling per limb, the c_k product per k-run) is unchanged. `kw_row_sync`
is kept verbatim as the pre-change body; `ZK_UPERF_ORACLE=1` runs the
per-digit-ring reference (`bg_kernel_pass` arithmetic / `phi0_ring_multi`),
as before.

The K-basis (rows-inside-the-ring) form the brief described — per kernel
the alpha-contracted G[d1] rings and CQ0 slices of the 16-entry col
kernel once, per value ring 8 x 16 x n_k scalar-x-ring MACs against the
negacyclically rotated cached rings — was worked out (the identities are
the O5 ones with PHI_vr = sum_rr X^{-rr*cols} sum_k sum_d1
sr_k[8vr+rr][d1] G_k[d1] and T_k[d1] = sum_(vr,rr) sr_k[..][d1]
X^{-rr*cols} V_vr) but NOT built: its per-kernel setup is 256 ring
products (~0.4 ms) x ~80 kernels x 27 tensors ~ 0.9 s per pass at 3x16 —
MORE than the hoisted form's whole remaining cost — because the mask
kernels' rows are sparse blocks (2-3 kernels touch a value ring), which
is exactly what the hoist exploits. Left as a note.

`uperf-e bench 1040 16 80` (e0 2, l0 16: 130 value rings, 2,080 digit
rings; 80 block-row kernels on the ypow col) [WSL 1T NOISY-SHARED]:

| | fast | oracle | speedup |
|---|---:|---:|---:|
| K-weight row per value ring | 106 us (one hoist per tensor) | 4,489 us (`kw_row_multi`); 8,226 us (`kw_row_sync` incl. its per-call Sync copy) | 42x |
| kernel pass rows | 0.034 s (16.3 us / digit ring) | 0.749 s (per-digit-ring reference) | 22x (83x at 8T) |
| kernel pass phi | 0.024 s (11.6 us / digit ring) | 0.856 s | 35x (89x at 8T) |
| psi0 (verify) | 0.026 s (12.5 us / digit ring) | 25.6 s (pre-O5 per-digit-ring reference) | 985x |

The 3x16 rig (1T, [WSL NOISY-SHARED]; digests identical on every line):

| | before (d3a4602 + timers) | after (hoisted rows) |
|---|---:|---:|
| e.kpass-smallcols (54 tensor-passes) | 7.33 s | **0.38 s** |
| bg.kernel-rows + bg.kernel-phi | 6.03 + 4.99 = 11.0 s | 2.64 + 1.79 = 4.4 s |
| e.psi0-smallcols (27 tensors, verify) | 3.51 s | **0.19 s** |
| ep.psi0-factored (verify) | 5.25 s | 2.09 s |
| commit / prove / verify / wall | 4.4 / 31.9 / 6.9 / **43.3 s** | 4.9 / 27.5 / 3.7 / **36.3 s** |
| 8T: commit / prove / verify / wall | 2.6 / 12.0 / 1.9 / 16.6 s (ledger baseline) | 2.9 / 11.3 / 1.3 / **15.7 s** |

## 4. Differential evidence + gates (all at HEAD of uperf2-e)

- `uperf-e diff-battery` (6 tensors per seed: wm-like 528 x 16 with 40
  block-row kernels on ypow + random cols, bl-like 96 x 16 dense rows,
  dense 208 x 8, odd 16 x 24, dense 64 x 96, no-kernel; zero scales;
  q31 x 3 seeds + q46): K-weight rows 24/24 tensors three-way identical
  per value ring; kernel passes rows + phi 8/8 fast == `oracle_mode` ==
  `bg_kernel_pass`; psi0 8/8 fast == compute_psi(reference Phi_0) ==
  pre_o5 at 2 chunk splits — BATTERY DIGEST
  59117121070e4d16d8ecef75b8ae1aade7440182626e0964e33633da1df17ddc
  identical at ZK_THREADS 1, 2, 7 (82-91 s each; the oracle legs are the
  cost).
- `uperf-a descent-battery`: 18/18 three-way identical + verified,
  BATTERY DIGEST f936ff790966b563607bac218e5852365f024a6ddb54e0d2ea8b91c16e9e32e0
  (lane A's value) at ZK_THREADS 1, 2, 7 after every tree-builder step.
- `uperf-a descent-bench 20 8 5 9`: DESCENT DIGEST 47a58a27..dafefb at 1T
  and 8T after every step.
- `uperf-pc diff-battery`: O1 4/4, O2 35/35, O3 63/63, O5 12/12 (incl. its
  misaligned tensor), E2E 2/2 at ZK_THREADS 1 and 7.
- freeze-check: 98 `ok` rows, the full pre-panic text identical to the
  capture taken from the untouched build at d3a4602 (then the expected
  "cannot read results/m125_ffn_export/layer00_X.bin" panic — the frozen
  export's X files are not on this box).
- The 3x16 REAL-DATA rig (`uperf-pc full-profile 3 16`,
  M125_EXPORT_DIR=results/m125_ffn_export_wsl): `accept = true`, statement
  digest 93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790,
  985,142 B, EVAL-PROOF DIGEST
  0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be at
  ZK_THREADS 1 and 8 (fast) after every step, and under
  `ZK_UPERF_ORACLE=1` at 1T at close (Section 4.1).
- `self-test` at close (Section 4.1).

### 4.1 Close runs

(filled at close)

## 5. Projected 12x512 deltas [MODEL — from the 3x16 ratios and the depth-20 bench; not a rig number]

- Small-cols aux tensors: the mask tensors grow ~(22/16.5)^2 ~ 1.8x in
  K-elements and ~1.3x in kernels from 3x16 to 12x512 (depth 16-17 ->
  21-22), the bl tensors with n_real (up to 12): the pre-change term
  ~2.5 x (7.33 + 3.51) ~ 27 s at 1T -> ~1.5 s (prove ~1.0, verify ~0.5).
  On the Mac's verify that is the "descents verify" share after d3ec01f;
  the pair loop itself stays < 1 s.
- Descent trees: the callers' boxed churn ~1 min (lane A's estimate) ->
  ~7 s at 1T / ~1.5 s at 8T; the phase is now the threaded tree steps
  (~61 s at 1T / ~15 s at 8T on this box's rates — kfield.rs).
- Both are behind ZK_THREADS-scaling paths; TASK_BOARD T1's one-binary
  A/B remains the honest test.

## 6. What is left

1. The K-basis form of the small-cols passes (Section 3): only if a
   future shape has DENSE row kernels on a small-cols tensor; for the
   mask tensors the hoist is the better algorithm.
2. `masked_gkr_verify` / the pair loop: nothing to do (0.06 s at 3x16;
   < 1 s at 12x512 [MODEL]).
3. Descent kernels (fold-into-next-round fusion, extract fusion into
   round 0 — lane A's Section 7 items 2-3): kfield.rs kernels, lane D's
   file this round; the callers in gkr_masked.rs are ready for them.
4. The remaining pack cost is the leaf tables' page-faulting (calloc'd
   pages first touched by the tree step) — inherent to fresh allocation;
   a per-pair leaf-table arena would remove it (~0.02 s per depth-22
   tree at 8T).
5. `bk_table_for` / `bk_pair_claims`: negligible at every scale measured.
