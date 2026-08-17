# U-PERF2 lane G — descents, round 2: fold/extract/eq fusion, the table arena, thread scaling

Branch `uperf2-g` (worktree /home/victor/wt-uperf2-g), opened at f512ba1
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane G" + "Agent G status".
Box: the WSL box (Intel Core Ultra 9 185H — 6 P + 8 E + 2 LP-E cores as
22 threads, 15 GB; the local m125 re-export is here, so the 3x16 and
12x64 real-data rigs run). Every number carries a label
`[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]`. Lane F was building and running
its rigs/batteries during the whole session (load 0.7-3.8): EVERY number
below is NOISY-SHARED; the fusion OFF/ON pairs are taken back-to-back in
ONE process (`uperf-g bench`), so the ratios are trustworthy while the
absolute seconds moved by up to 20% between repeats.

## 0. One paragraph

The packed masked-descent kernel now does its work in ONE pass per
round instead of three: round t+1's kernel folds round t's five work
tables (eq, PL, p1, q0, q1) on the fly — reads the state-t tables once,
writes the state-(t+1) tables IN PLACE (a rung-ordered schedule makes the
in-place fold thread-safe with no scratch), and runs the node loop on
what it just produced; rounds 0 and 1 read the tree's layer j+1 and the
b-part eq table directly (the extract deinterleave, PL = p0 + lambda q0
and eq = eq_b(b) x E(e) formed on the fly), so the first materialized
work tables of a layer are state 1. Table traffic per layer drops from
~37 S to ~18 S (S = the layer's table size), the work-table footprint
from 5.5 S to 2.5 S. Every stored element is the canonical value of the
same field expression the eager path stores and the node planes are the
same exact-integer sums, so the round polynomials, boundaries, openings
and challenges are byte-identical: `uperf-g descent-battery` proves it
FOUR ways (boxed scalar oracle == bulk-ref == fast-with-fusion-off ==
fast-fused, 22/22 legs at ZK_THREADS 1/2/7, digest 6d6a3f6b..), lane
A's `uperf-a descent-battery` stays 18/18 (f936ff79..), the depth-20 x 8
bench's DESCENT DIGEST 47a58a27.. is unchanged, and the REAL rigs print
their exact digests (3x16: 93a98700.. / 0ae9cdae.. at 1T and 8T; 12x64:
80763ea5.. / 63f4a3a4.. at 8T). Numbers: depth 20 x 8 `masked_gkr_prove`
**2.15-2.33 s -> 1.66-1.78 s at 8T (-22..-28%)**, 1T -8..-15% (the box's
noise band), peak RSS **2,087 -> 1,557 MiB**; the fused kernel scales to
**5.0x at 16 threads** where lane A's saturated at 3.2x; the REAL 12x64
rig's `bk.descent-gkr` **10.3 -> 7.4 s at 8T (-29%)**, the 3x16 rig's
1.19 -> 0.88 s (8T). What did NOT land: the per-pair table arena — built,
measured NEGATIVE on this box (after lane E's calloc trick the page
faults are ~5% of the descent CPU, the pool's held set costs RSS and
glibc's realloc copies heap chunks: +0.5 GB peak, prove +10%), so it is
committed OPT-IN (`ZK_K9_ARENA_MB`, default off) with the finding; a THP
(MADV_HUGEPAGE) probe cut the bench's minor faults 9x with no wall change
and was removed. Thread scaling past ~5x is the hybrid box (turbo-1T vs
all-core clocks, E-cores), not the kernel split — the Mac's uniform cores
are the expectation (TASK_BOARD T1).

## 1. Baseline (untouched build at f512ba1)

`uperf-a descent-bench 20 8 5 9` (5 real depth-20 witness trees + 3 pads +
the dt-9 table side; DESCENT DIGEST 47a58a27..dafefb) [WSL-BOX, load 0.7,
lane F building]:

| | 1T | 8T |
|---|---:|---:|
| trees | 1.63 s | 0.39 s |
| masked_gkr_prove | 8.12 s | 2.24 s |
| a.round-g | 3.66 | 0.93 |
| a.fold | 2.54 | 0.89 |
| a.extract | 1.22 | 0.21 |
| a.eq-table | 0.67 | 0.19 |
| a.tree-step | 1.34 | 0.29 |
| peak RSS | 2,086 MiB | 2,087 MiB |

Freeze-check baseline: 98 `ok` rows (scratchpad g_freeze_baseline.txt),
identical to lane F's capture of the same build. REAL rigs at the
untouched build [8T NOISY-SHARED]: 3x16 wall 9.5 s, `bk.descent-gkr`
1.19 s (a.round-g 0.45, a.fold 0.41, a.extract 0.12, a.eq-table 0.12);
1T wall 29.0 s, `bk.descent-gkr` 2.36 s (1.09 / 0.67 / 0.24 / 0.26).
12x64 8T (ledger row at 4dcaea6): `bk.descent-gkr` 10.3 s (a.round-g 4.2,
a.fold 3.8, a.tree-step 1.4, a.extract 1.3, a.eq-table 0.9),
`bk.descent-trees` 1.8 s, wall 46.0 s, peak RSS 12.2 GB.

## 2. Item 1 — fold-into-next-round + extract fusion + eq fusion

### 2.1 What the kernel does now (kfield.rs `fused_round_body`, `k9_fused_round_par`; gkr_masked.rs `masked_rounds_bulk`)

Lane A's fast path streamed, per b-round t of a layer, the five packed
work tables through the round kernel (read S each) and then through five
out-of-place folds (read S, write S/2 each): 2.5 S per table per round,
plus at round 0 the extract (read the tree layer 4 S, write 4 S, PL read
2 S write S) and the eq build (write S). Now:

- **FUSE_FOLD (rounds t >= 2, and t = 1 when the extract is not fused)**:
  round t's kernel reads the STATE-(t-1) tables (4 blocks per output
  pair-block), computes the two state-t blocks of each table by
  `fold_oop_body`'s arithmetic (`fold_pair_blocks`: deinterleave, d = t1
  - t0, one fixed MAC + one reduction, add t0, then the masked t == 0
  add-constant by `addc_body`'s add), WRITES them back into the same
  buffer, deinterleaves the pair it just wrote into the (even, odd)
  staging blocks and runs `round_g5_pair` — the node loop of lane A's
  `round_g5_body`, hoisted out as a shared `#[inline(always)]` fn (a code
  motion; `round_g5_body` calls it too, so the plain path is unchanged).
  1.5 S per table per round, no fold scratch. The pending fold's
  challenge r_{t-1} and add-constants travel in a `PendingFold`.
- **FUSE_EXTRACT (round 0)**: reads the tree's layer j+1 (p, q) blocks
  directly — deinterleave (4m, 4m+1) and (4m+2, 4m+3) into the state-0
  p0/p1/q0/q1 blocks, PL = p0 + lambda q0 by `mul_fixed_add_body`'s
  arithmetic — and the b-part eq table times E(e) (`mul_fixed_block` =
  `mul_fixed_body`'s per-block arithmetic; skipped when E(e) = 1). No
  writes: nothing is materialized at state 0.
- **FUSE_EXTRACT_FOLD (round 1)**: reads the tree layer (8 blocks per
  output pair-block) and the b-part eq table again, extracts + folds
  with r_0 (+ the masked add-constants on p0/p1/q0/q1) and forms PL_1 =
  (fold(p0)+c_p0) + lambda (fold(q0)+c_q0), writes the five STATE-1
  tables into fresh buffers (S/2 each), runs the node loop. Field
  identity: fold(PL_0) + c_pl == PL(fold(p0)+c_p0, fold(q0)+c_q0), and
  every stored value is canonical, so the bytes are the same.
- The rounds loop (`masked_rounds_bulk`): the fold after round t is
  PENDING; the next round consumes it in a fused kernel, or FLUSHES it
  (`flush_state` = lane A's eq build / block-copy extract + PL /
  out-of-place folds + add-constants, verbatim) when it cannot fuse: the
  scalar tail (n < 2 KL), the w-round, the pad materialization
  (`!materialized && !skipping`). Extract/eq fusion needs every state-1
  pair-block inside one instance's slice and any pads skipped (per >= 4
  KL and (no pads || skip)); tiny layers take the eager path. With
  `ZK_UPERF_G_NOFUSE=1` (or `k9_set_fuse_off(true)` in process) every
  fold is flushed right after its challenge — lane A's HEAD loop, the
  one-binary A/B; `ZK_UPERF_G_NOXFUSE=1` keeps the fold fusion but
  extracts eagerly (the attribution knob); `oracle_mode()` still routes to
  `masked_rounds_bulk_ref` (the U-K9 body).

### 2.2 The in-place hazard and the rung schedule (`k9_fused_round_par`)

Output pair-block m' writes state-t blocks [2m', 2m'+2) and reads
state-(t-1) blocks [4m', 4m'+4) of the SAME buffer, so a range [A, 2A) of
pair-blocks writes [2A, 4A) — exactly what the range [A/2, A) reads — and
reads [4A, 8A) — what [2A, 4A) writes. Hence: the prefix [0, A0) (A0 =
64 pair-blocks) is folded through a tiny scratch and copied back, then
the rungs [A0, 2A0), [2A0, 4A0), .., [P/2, P) run in that order, each
fully parallel over its live (real) pair-blocks (a rung's reads never
meet its own writes: it reads beyond 4A while it writes below 4A —
`split_at_mut` at block 4A hands the jobs disjoint &mut write pieces and
shared read slices; no unsafe). Per rung the live sub-ranges are cut into
~ZK_THREADS x 8 jobs (`ZK_K9_JOBS_PER_THREAD`, any value bit-identical),
each with its own lazy node planes in a 128 B-padded slot (no shared
cache line between jobs); the planes are exact non-negative integer sums
bounded by the serial total (< 2^64 under K9_MAX_PAIR_TERMS), so summing
them in any order gives the same integers — bit-identical for any thread
count and job partition. Rounds 0/1 write only fresh tables (or nothing)
and take one parallel pass. Dispatch cost: ~log2(P/64) pool barriers per
fused round (< 30 ms per side at depth 20).

Memory: no S/2 fold scratch (the prefix scratch is 5 x 128 blocks); the
state-0 tables and the state-0 joint eq are never materialized: peak
work-table footprint 5.5 S -> 2.5 S (eq_1 + four state-1 tables).

### 2.3 Measurements — depth 20 x 8 (5 real, 3 pads), `uperf-g bench 20 8 5 9` (fusion OFF then ON in one process; digest 47a58a27.. on every line)

| step | 8T OFF -> ON (prove s) | 1T OFF -> ON (prove s) | notes |
|---|---:|---:|---|
| fold + extract fusion (501d76e), run 1 | 2.13 -> 1.68 | 7.61 -> 8.09 | 1T run under load 1.35 |
| same, run 2 | 2.15 -> 1.71 | 7.95 -> 6.79 | 1T run under load ~1.0 |
| same, run 3 | 2.30 -> 1.66 | 8.05 -> 7.59 (`NOXFUSE`: fold fusion only) | |
| + eq fusion (756ae7f) | 2.33 -> 1.78 | 9.20 -> 8.45 | load 1.6-1.9 (OFF itself +8-15% vs the runs above) |
| ratio ON/OFF | **0.72-0.80** | **0.85-0.92** (one run 1.06 under load) | |

Attribution at 8T (fused, HEAD, [NOISY-SHARED]): a.round-g 1.46-1.80
(it now contains the folds, the extract and the eq scale), a.eq-table
0.06 (was 0.17-0.19: only the b-part table), a.extract 0.00, a.fold 0.02
(the flushes of the sub-block tails), a.tree-step 0.28-0.31; peak RSS
2,087 -> 1,637 (fold + extract fusion) -> **1,557 MiB** (eq fusion). At
1T the fusion is compute-neutral by construction (same MACs and
reductions, three deinterleaves per pair-block either way, PL formed once
per state) and gains only the memory-traffic share, ~8-15% here; the eq
fusion adds one fixed MAC + reduction per state-0 eq block at rounds 0
and 1 (~+4% of the layer's MACs) against 3 S of traffic — neutral at 1T,
a small gain at 8T, and -0.5 S of footprint.

Smaller shapes (`uperf-g descent-battery`, fast prove seconds nofuse ->
fused at 1T): depth 12 x 8 (5 real) 0.058 -> 0.041; depth 15 x 2 0.093
-> 0.096; depth 14 x 4 0.081 -> 0.090 — below ~2^14 leaves the rung
dispatch and the flushes cost what the traffic saves (the shapes the
rig cares about are 2^21-22).

### 2.4 The REAL rigs [WSL NOISY-SHARED; digests exact on every run]

| rig | metric | untouched f512ba1 | HEAD (fused) |
|---|---|---:|---:|
| 3x16, 8T | wall / bk.descent-gkr / a.round-g / a.eq-table | 9.5 s / 1.19 / 0.45 (+fold 0.41, extract 0.12) / 0.12 | 9.3 s / **0.88** / 0.69 / 0.09 |
| 3x16, 1T | wall / bk.descent-gkr | 29.0 s / 2.36 | 28.7 s / 2.26 |
| 12x64, 8T | wall / bk.descent-gkr / a.round-g / a.eq-table / a.tree-step / maxrss | 46.0 s / 10.3 / 4.2 (+fold 3.8, extract 1.3) / 0.9 / 1.4 / 12.2 GB (ledger row) | 42.3-44.1 s / **7.36** / 6.87 / 0.27 / 1.27 / 12.19 GB |

3x16 (T = 16, depths 16-17) is small for the descents; 12x64 (depths
~18-19, up to 16 trees) shows the -29% on the descent-gkr phase; the
process peak RSS is not in the descent phase at 12x64 (lane F's
territory), so the -3 S of work tables do not show in maxrss there.

## 3. Item 2 — the per-pair table arena (built, measured, OPT-IN)

Design (kfield.rs `k9_arena_take/give/clear/stats`, `KTab::recycled`,
`impl Drop for KTab`): a process-global LIFO free list of u32 buffers >=
256 KB, capped at `ZK_K9_ARENA_MB` of held capacity; `KTab::zeroed`
memsets a recycled buffer, `KTab::recycled` (tables every element of
which is written before it is read: tree layers, q leaves, eq tables, the
fused state-1 tables) takes it dirty; a take is served by the smallest
pooled buffer within 2x of the request. Every FracTree layer / work
table returns its buffer on drop.

Measured on the depth-20 bench at 8T [NOISY-SHARED, same-process OFF/ON
pairs] — the pool did NOT pay for itself on this box:

| variant | 8T prove OFF/ON | peak RSS | minor faults | why |
|---|---:|---:|---:|---|
| no arena | 2.17 / 1.70 | 2,087 MiB | 1.32M | — |
| pool cap 1 GB, best fit + grow-largest (Vec::reserve_exact) | 2.87 / 1.94 | 2,567 MiB | 1.07M | glibc realloc COPIES heap chunks (the dynamic mmap threshold puts <= 32 MB tables on the brk heap); a bigger pooled buffer under a small table keeps its pages resident |
| pool cap 1 GB, best fit within 2x, no growth | 2.40 / 1.91 | 2,759 MiB | 1.14M | size classes double per layer, so within a side nothing fits; the held set is RSS; LIFO eviction churns munmap/mmap |
| THP probe: MADV_HUGEPAGE on fresh buffers >= 4 MB (removed) | 2.29 / 1.82 vs 2.41 / 1.86 | 2,129 MiB | **142K** | 9x fewer faults, wall unchanged; 1T sys 0.75 -> 0.57 s of 11.7 s |

The standalone probe (scratchpad g_thp_probe: 512 MB first touch) says
what the faults cost here: 135 ms at 1T / 30-46 ms at 8T per 512 MB
(0.26 ms/MB serial), a resident memset 42 ms; the bench touches ~2.3 GB
-> ~0.6 s of 1T CPU (5-6%), ~0.2 s at 8T (5%). Lane E's calloc-p /
parallel-q fill already removed the visible part; what is left is spread
over the first touch of every table and is bounded at ~5%. A pool that
pays would need (a) size-class-exact reuse (the trees of consecutive
pairs are the same shape — that is the one place a same-size pool is
free of the RSS problem), (b) mmap-backed buffers (no realloc copies) and
(c) a release call from the pass driver after the descent phase (the
bin's `bk_pass_run` — lane F's file this round; the held set is resident
RSS until then, unacceptable for the 12x512 memory diet). The code is in
(default `ZK_K9_ARENA_MB=0` = off; batteries pass with it on and off);
`k9_arena_clear()` is public for the driver. Left as an experiment for a
box with memory to spare; not a lever on this one.

## 4. Item 3 — thread scaling

`uperf-a descent-bench 20 8 5 9` at HEAD-1 (fold + extract fusion,
before the eq fusion) [WSL NOISY-SHARED, load 1.0-1.8], `masked_gkr_prove`
seconds:

| ZK_THREADS | 1 | 2 | 4 | 6 | 8 | 12 | 16 |
|---|---:|---:|---:|---:|---:|---:|---:|
| prove | 7.07 | 4.29 | 2.51 | 1.89 | 1.68 | 1.58 | **1.47** |
| a.round-g (fused) | 6.37 | 3.88 | 2.25 | 1.69 | 1.48 | 1.38 | 1.28 |
| a.tree-step | 1.31 | 0.75 | 0.43 | 0.31 | 0.29 | 0.26 | 0.26 |
| speedup (prove) | 1 | 1.65 | 2.8 | 3.7 | 4.2 | 4.5 | **4.8** |

Lane A's unfused table saturated at 3.2x (2.38 s at 8T, 2.50 s at 16T);
the fused kernel keeps gaining to 16 threads (5.0x on round-g). What is
left is the box: a single thread runs at the 185H's turbo clock while 6+
threads run at the all-core clock (~0.75x), threads 7-8 land on E-cores
or HT siblings (~0.4-0.5x of a P-core for the AVX2 MAC loop), so the
ideal on this topology is ~4.5x at 6T / ~5.4x at 8T / ~7x at 16T — the
kernels reach 82% / 78% / 65% of that. Two deterministic knobs were
tried: (1) the per-job plane slots are now padded by 128 B (no two jobs'
persistent accumulators share a cache line) — no measurable change, kept
as hygiene; (2) jobs per thread per rung `ZK_K9_JOBS_PER_THREAD` 2/4/8/16
-> round-g 1.72/1.62/1.60/1.56 s at 8T, 1.38/1.38/1.36/1.35 s at 16T
(default now 8; smaller jobs shorten the barrier tail an E-core's job
leaves). Thread affinity to P-cores would need sched_setaffinity (FFI,
not attempted). The tree step is positional (no barrier but per layer)
and shows the same 4.6-5x — the split is not the limit. TASK_BOARD T1's
Mac measurement remains the honest test of the kernels' scaling.

## 5. Differential evidence + gates (all at HEAD of uperf2-g)

- `uperf-g descent-battery` (11 shapes x {masked, zero masks} = 22 legs:
  depths 4-15, l 1-16, pads 0-7): boxed scalar oracle == bulk-ref
  (`set_oracle_mode(true)`) == fast with fusion OFF == fast FUSED, every
  proof verified with pins; BATTERY DIGEST
  6d6a3f6b18254d0f45cf3d8e86a80f3ba83afe5f9685780e08273b24172d0d9f
  identical at ZK_THREADS 1, 2, 7 (and with the arena on).
- `uperf-a descent-battery`: 18/18, BATTERY DIGEST f936ff79.. (lane A's
  value) at ZK_THREADS 1, 2, 7 after every step.
- `uperf-a descent-bench 20 8 5 9` / `uperf-g bench 20 8 5 9`: DESCENT
  DIGEST 47a58a2742f9e656ec07f7b14ff696d1ff8092333fb3f6883d7aa95224dafefb
  at 1T and 8T after every step, fused == unfused in one process.
- `uperf-pc diff-battery`: O1 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2
  at ZK_THREADS 1 and 7.
- freeze-check: 98 `ok` rows identical to the pre-change capture (only the
  trailing panic's relative path differs — the run's cwd, not code).
- REAL 3x16 rig (`uperf-pc full-profile 3 16`,
  M125_EXPORT_DIR=results/m125_ffn_export_wsl): accept = true, statement
  digest 93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790,
  985,142 B, EVAL-PROOF DIGEST
  0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be at
  ZK_THREADS 1 (wall 28.7 s: 3.8 / 21.3 / 3.5) and 8 (9.3 s: 1.8 / 6.1 /
  1.2); the `ZK_UPERF_ORACLE=1` 1T run at close (every fast path routed to
  its oracle, this lane's `masked_rounds_bulk_ref` included): accept, the
  same digests, wall 602.2 s (44.7 / 417.9 / 139.3).
- REAL 12x64 rig at 8T (flock, `/usr/bin/time`): accept = true, statement
  digest 80763ea537e77cd9cb5c538397af2622044447d654b8e9a34cae3ccad8f3f115,
  EVAL-PROOF DIGEST
  63f4a3a4320a47260ab8ae3d52cfa3656b626fc367af671c6c317300454dec89, wall
  42.3 / 44.1 s (commit 7.6-8.6 / prove 30.6-31.0 / verify 3.7-4.0),
  maxrss 12,183,284-12,185,184 KB (two runs).
- `self-test` at close: passed, 234.0 s.

## 6. Projection to the rig (depth 22 x 16 pairs) + what is left

[MODEL — linear in real leaf elements from the depth-20 rates; the rig
does not fit this box.] Lane A's extrapolation put the rig's witness-
descent prove at ~249 s (1T) / ~71 s (8T) on this box's rates; the fused
kernel's ratios (0.85-0.92 at 1T, 0.72-0.80 at 8T, 0.65 at 16T vs lane
A's 8T-saturated numbers) give ~215-230 s at 1T, ~52-57 s at 8T, ~46 s
at 16T here — the Mac's uniform cores should scale further (the kernel
now keeps gaining to 16 threads). Memory at the peak pair (nrw-88, 16
trees, 12 real, depth 22: S = 2 GB nominal, 1.5 GB touched): work tables
5.5 S -> 2.5 S = ~8.3 GB -> ~3.8 GB touched, on top of the ~12 GB of
packed trees — the descent phase's own peak ~21 GB -> ~16 GB (lane F's
memory report owns the process peak).

Left, in order of value:
1. The tree step + descent at rig depth on the Mac (T1) — the kernels
   are ready; nothing to change for more threads.
2. A same-size tree-buffer pool across pairs (the one arena shape that is
   RSS-neutral) once the pass driver can release it after the descent
   phase — ~5% of the descent CPU at most on this box.
3. The eq for rounds >= 2 is a folded table like the others; the round-0
   eq is now eq_b x E(e) on the fly — the b-part doubling itself
   (a.eq-table 0.06 s at 8T) is what remains.
4. The tail rounds (n < 2 KL) and the w-round run the boxed scalar path
   (a.scalar-tail 0.005 s) — nothing to gain.
5. GPU rung: the fused kernel is still a fixed-shape 16x16 x 8-lane MAC
   pipeline per pair-block with one write of the folded blocks — the
   natural first descent GPU kernel; the rung schedule maps to a
   grid-sync per rung.
