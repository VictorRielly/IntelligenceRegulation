# U-PERF2 lane L — THE GPU RUNG, step 2: the K-field lane kernels on the device (fused descent round, ixf round + fold, tree step)

Branch `uperf2-l` (worktree /home/victor/wt-uperf2-l), opened at f821485 on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 7 ... Lane L" + "Agent L
status". This continues lane K's Phase-3 GPU rung (U_PERF2_GPU_REPORT.md:
the plumbing, the one-hook discipline, the honest-framing rules): hardware
named, watts stated, every number flagged [MEASURED] / [ASSUMED] / [MODEL].

**Hardware (this box) [MEASURED, nvidia-smi 2026-08-17]:** NVIDIA GeForce RTX
4070 Laptop GPU, 8,188 MiB VRAM, sm_89 (36 SMs; idles at 210 MHz and ramps
under load), reached from WSL2 (driver 566.14, CUDA 12.7 driver API); power
limits 55 W default / 68.82 W current / 105 W max — a 55-70 W-class MOBILE
part; nothing here is a claim about the TARGET_CONTRACT's <= 450 W desktop
board. Host: Intel Core Ultra 9 185H (22 threads), 15 GB. Toolchain as lane
K's: no CUDA toolkit; `cudarc 0.13.9` (driver + NVRTC), the kernels are CUDA
C strings compiled at first use (the PTX is cached on disk under
`~/.cache/zkmatrix-gpu/`; the driver's own SASS cache covers the JIT — the
first process on a new kernel source pays ~40 s of NVRTC + ~40 s of JIT once).

Every wall-clock number below is `[WSL-BOX NT NOISY-SHARED]` — lane M built
and ran concurrently the whole session (load 1.5-6); the CPU/GPU pairs are
taken back-to-back in ONE binary (`ZK_GPU` unset vs `ZK_GPU=1`, or the
in-process bypass), so the ratios are what to read; the host-side upload
rates in particular moved 2x between repeats.

## 0. One paragraph

The three K-field lane kernels now run on the RTX 4070 Laptop through one
hook each, bit-identically: the fused masked-descent round (all three
modes) as a DEVICE-RESIDENT chain per tree layer — the layer (packed live
blocks, or the compact leaves re-encoded to 8 B per leaf + exceptions and
expanded on the device) and the b-part eq table are uploaded once, round 0
and round 1 read them on the device, round 1 writes the state-1 tables INTO
DEVICE MEMORY, rounds >= 2 fold there (out-of-place ping-pong, one launch
per live range), only the node values (a handful of u64) come back per
round, and the host tables are written ONCE at the handover (the last
device round, predicted from the plan); the claim layer's ixf round + fold
as the same kind of chain (the tables uploaded at round 0, the folds
device-only until the handover); the tree step (implemented, measured, OFF
by default: the eager copy of the output layer to the host costs what the
CPU step costs on this PCIe link). Values: every stored coefficient is the
canonical representative of the same field expression (lane J's burst
arithmetic + reductions ported to CUDA op-for-op), and every node value is
the same field element the CPU's exact planes finalize to (the products are
reduced per term instead of once per round — reduction commutes with
addition; Section 2). Evidence: `uperf-l battery` (310 legs GPU == CPU
cell by cell: whole layer chains incl. compact leaves with exceptions, pads
skipped, masks, eager and lazy; ixf chains of the three kinds; tree climbs
— 15.9M table words + every round's node values / round polys, at
ZK_THREADS 1/2/7), the existing batteries under `ZK_GPU=1` with every
eligible round on the device (uperf-a 18/18, uperf-g 22/22, uperf-h 24x8,
uperf-d 30/30, uperf-j 1,120x3, all the ledger's digests), lane A's descent
digest 47a58a27.., `uperf-pc diff-battery`, and the REAL rigs' digests.
Measured [WSL-BOX 8T NOISY-SHARED]: the fused round kernel alone 25 ns per
element pair on the device (~4-5x the 8T AVX2 body per element pair, ~16%
of the part's integer peak — occupancy-bound at ~200 registers/thread); the
whole layer chain incl. its uploads 2.9-3.5x (compact leaves) / 1.5-2.2x
(packed layer) at 2^21 elements; on THE PoC SHAPE 12x512 8T: **85.0 s ->
74.6 s (commit 5.5 / prove 60.0 / verify 7.3), accept, statement 2f8a92f8..
/ EVAL 4c259008.. / 1,509,911 B identical, 11.2 GB**: a.round-g 22.3 -> 12.0
s (1.85x), bk.descent-gkr 27.7 -> 16.4 s, the claim layer 15.9 -> 15.2 s
(cl-folds 6.8 -> 4.9, cl-rounds 3.4 -> 5.2: its 2.5 GB-per-instance uploads
cost what they save; the fold phase's remaining ~5 s is host page
management, not arithmetic — Section 5); 12x128 8T 33.6 -> 30.0 s; 3x16 8T
unchanged within noise. What limits it on THIS box: the PCIe/WSL2 host link
(5-9 GB/s measured, and the device reads freshly DMA'd pages slowly the
first time) — the descent's remaining 12 s are ~6.6 s of uploads/encodes and
~5 s of kernels; the honest next steps are structural (Section 5).

## 1. What landed (files)

- `zkmatrix-rs/src/ring/gpu/k9.rs` (NEW): the host side — the K9 device
  state (its own NVRTC module `zkgpu_k9`, compute + copy streams, pinned
  staging ring, grow-only device buffers under a VRAM budget with idle
  families released first), the descent chain (`k9_fused_round`), the ixf
  chain (`k9_ixf_round`, `kt_fold`), the tree climb (`k9_tree_climb`), the
  compact-leaf re-encoding, the handover protocol, knobs and stats.
- `zkmatrix-rs/src/ring/gpu/kernels_k9.cu` (NEW): the device code — the
  K = Z_q[Y]/(Y^16 - s) lane arithmetic on canonical u32 coefficients (lane
  J's bursts + reductions, `mul.wide.u32`/`mad.wide.u32` via inline PTX),
  `k_fold_round` / `k_extract_round[_cl]` / `k_extract_fold[_cl]` (the three
  fused modes; `_cl` = compact leaves expanded on the fly), `k_fold_table`,
  `k_tree_step[_cl]`, `k_ixf_round`; the compact-leaf decode + exception
  override; the block reduction of the node sums.
- `zkmatrix-rs/src/ring/gpu/mod.rs`: `mod k9;` + re-exports; the default
  build's stub (`k9_fused_round` returns `Err(tabs)`, the others `None`).
- `zkmatrix-rs/src/ring/gpu/cuda.rs` (lane K's, extended): `DevBuf` /
  `HostPinned` / `POOL` / env helpers made `pub(super)`; `device_handle()`;
  `set_bypass(true)` and the GEMM failure bypass assert that no descent
  chain is device-resident.
- `zkmatrix-rs/src/ring/kfield.rs`: ONE additive line at the top of
  `k9_fused_round_par` (`let tabs = match super::gpu::k9_fused_round(..,
  tabs, ..) { Ok(()) => return, Err(t) => t };` — the tabs array is moved in
  and handed back on decline), `k9_ixf_round_par`, `KField::kt_fold_par`,
  `k9_tree_climb_par` (`if super::gpu::enabled() { if
  super::gpu::<hook>(..).is_some() { return; } }`). Nothing else there.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-L]` section, `uperf-l
  battery [seed] | bench [log2_pairs] [reps] | dbench <depth> <l> [n_real]
  [dt]`, registered next to `uperf-k`.
- This report + "Agent L status" in PROGRESS_UPERF2.md.

Knobs (none changes a value): `ZK_GPU=1` (lane K's master switch),
`ZK_GPU_K9=0` (the K-field kernels off — the one-binary A/B),
`ZK_GPU_K9_MIN_PAIRS` (the smallest round output the device takes, in
pair-blocks; default 32), `ZK_GPU_K9_BUDGET_MB` (device memory the K9
buffers may hold; default = free VRAM at first use - 256 MB),
`ZK_GPU_K9_EAGER=1` (every round's state written back — the battery's
cell-by-cell mode), `ZK_GPU_K9_TREE=1` (the tree climb on the device;
default OFF), `ZK_GPU_K9_STG_MB` (staging chunk, default 32),
`ZK_GPU_VERBOSE=1` (a line per call), `ZK_GPU_PROFILE=1` (kernel-only
timing per call). Build/run recipe: lane K's (U_PERF2_GPU_REPORT.md
Section 1).

## 2. Method (why the values are identical)

### 2.1 The arithmetic (kernels_k9.cu, header)

K = Z_q[Y]/(Y^16 - s), 2^30 < q < 2^31, c31 = 2^31 mod q < 1024, c32 = 2 c31.
A product is the 16x16 schoolbook; for output coefficient t the products
a_i b_{t-i} (< 2^62) are summed in bursts of <= 4 exactly in u64, each burst
folded once by 2^32 == c32 into one u64 accumulator (acc_t < 2^45 for the
two-product wire); the reduction lands the canonical representative:
h_t = canon1(fold31(acc_{t+16})), v = acc_t + s h_t < 2^63, fold31 twice,
canon1 — exactly lane J's chain (U_PERF2_KSIMD_REPORT.md Section 3.3), whose
bounds are restated in the .cu header. So the fold t0 + r (t1 - t0) [+ c],
PL = p0 + lambda q0, the eq x E(e), the tree step's pL qR + pR qL and qL qR,
the ixf inner factors — every STORED coefficient — is the canonical
representative of the same field expression the CPU body stores; canonical
representatives are unique; identical bytes. Two orderings are used that
differ from the CPU's op sequence but not from its field values: the round-1
eq is fold(eqb) x E(e) instead of fold(eqb x E(e)) (distributivity), and the
wire is addm(red(PL Q1), red(P1 Q0)) instead of red(PL Q1 + P1 Q0)
(reduction commutes with addition).

### 2.2 The node sums (a deviation from the letter of the brief, not from the values)

The CPU accumulates the products eq x wire in exact integer planes and
finalizes once per round: per t, (sum_t + s * (sum_{t+16} mod q)) mod q. The
device reduces every term eq x wire to its canonical value (the same chain)
and sums those mod q — per thread, then a fixed-order block reduction, then
one u64 atomic add of canonical values per (node, t) (< 2^49), reduced mod q
on the host and deposited into acc_lo[t*KL] (acc_hi = 0). Because reduction
commutes with addition, the node value the caller's finalize returns is the
same field element — the round polynomial's canonical KElem, which is what
the transcript absorbs. The brief asked for the exact planes with the CPU's
reduction points; that would cost 62 u64 accumulators per node per thread
(local memory) — the register-resident formulation was chosen and its
identity argued here and asserted by the batteries (every round's node
values compared as finalized KElems, every proof byte-identical).

### 2.3 The device-resident descent chain and its handover (k9.rs header)

`masked_rounds_bulk` (gkr_masked.rs) issues, per tree layer j: round 0 =
FUSE_EXTRACT (reads layer j+1 + the b-part eq; writes nothing), round 1 =
FUSE_EXTRACT_FOLD (reads the same; writes the fresh state-1 tables), rounds
t >= 2 = FUSE_FOLD (reads state t-1, writes state t in place). The device
keeps the layer between rounds 0 and 1 (tag: the layers' host pointers /
lengths, first pairs, E(e), the eq table, the halved ranges), writes the
state-1 tables into device memory (the LIVE ranges only, packed per range),
folds out of place (ping-pong) from round 2 on, and writes the host tables
ONCE at the handover: the last round the device runs, decided at the round
itself from the plan — the successor's output below `min_pairs`, or the pad
slices about to be materialized (the live ranges' width falls under one
pair-block while pads exist). Why the host may stay stale in between (the
invariant, gkr_masked.rs at f821485): between two consecutive hooked rounds
of one layer nothing on the host reads or moves the five buffers (the
caller only truncates the Vecs — no reallocation —, finalizes, absorbs,
draws), and the successor of a round whose output is >= 2 min_pairs blocks
per table and (no pads, or >= 2 pair-blocks per instance still skipping) is
ALWAYS a hooked FUSE_FOLD on the same buffers (`bulk` holds, `tabs` and
`pending` are set, `need_mat` is false, the fusion knob is on — else no
fused call happens at all). Every hooked call checks the chain's expected
successor (mode, buffers, sizes, ranges — the extract modes list every
instance, FUSE_FOLD without pads lists one range: both accepted when they
describe the same live set) and PANICS on a mismatch — that would be a
protocol violation with stale host tables, never a value change; a decline
happens before a chain opens (size, budget) or writes the resident state
back first (`abort_to_host` on a device error / an OOM at the ping-pong).
`set_bypass(true)` (lane K's harness knob and its GEMM-failure path)
asserts no chain is alive. The ixf chain (fold.rs `ixf_sumcheck_prove_packed`
— one sequential loop on one transcript) uses the same rule at the fold:
the folded table stays device-only unless the successor round would fall
below `min_pairs` (then the CPU round / the scalar tail read the host), and
the successor round is identified by the SEQUENCE (kind, table count, the
nt folds done, n halved) — pointer identity is a diagnostic only (the loop
may `shrink_to_fit` the buffers). Under the lazy protocol the fold leaves
the host buffer's LENGTH untouched, so the caller's truncate/shrink cost
nothing (Section 5.3).

### 2.4 The compact leaves

`CompactLeaves` (lane H) is read through `expand_blocks` (its words are
private to kfield.rs and the hook discipline forbids an accessor): the
device path re-encodes the expanded blocks — 2 words per leaf (q's
coordinates 0..1, the member flag in bit 31; a zero pair = the (0, 1)
dummy), alpha's tail probed from the first blocks, everything else an
exception (index, p, q) — and the device decode + exception override
yields the same packed blocks (the battery plants exceptions and compares
cell by cell). Cost: ~24 ms per 4M leaves at 8T (Section 4); an accessor to
the words would make it a memcpy.

## 3. Differential evidence (all at HEAD of uperf2-l, the GPU feature build under `ZK_GPU=1`)

| gate | result |
|---|---|
| `uperf-l battery` (ZK_THREADS 1, 2, 7) | 310 legs GPU == CPU (bypassed) cell by cell: 14 fused layer-chain shapes (per-instance 32..8192 state-0 elements x 1..8 instances, pads skipped, packed AND compact leaves with planted exceptions, masked round 0 with its five nodes) x 5 value patterns (uniform, planted extremes, all q-1, per-lane extremes, 1/8 zeros) x {eager, lazy}: every round's node values and (eager) every round's tables / (lazy) the handover tables; ixf chains kinds rq/p3/had x degrees 2/3/4 x n 2^5..2^13 x patterns x {eager, lazy}: every round poly + the folded tables; tree climbs levels 1/2/3 packed + level 1 compact; 15,927,296 table words compared; BATTERY DIGEST cc4f8c1c.. identical at 1/2/7T |
| `uperf-a descent-battery` (`ZK_GPU_K9_MIN_PAIRS=1`: every eligible round on the device) | 18/18, f936ff79.. (lane A's value) at 1/2/7T |
| `uperf-g descent-battery` | 22/22 four ways, 6d6a3f6b.. at 1/2/7T |
| `uperf-h battery` (compact leaves, checkpoint recomputes, layer release) | 24/24 eight ways, b1e78285.. at 1/2/7T |
| `uperf-d diff-battery` | 30/30, 46471467.. at 1/2/7T |
| `uperf-j battery` | 1,120 x 3, 45dba7c7.. at 1/2/7T (the `_blocks` bodies; unaffected by the hooks) |
| `uperf-a descent-bench 20 8 5 9` (8T, ZK_GPU=1) | DESCENT DIGEST 47a58a27..dafefb (identical to the ledger's; verified true) |
| `uperf-pc diff-battery` (ZK_GPU=1, 1T and 7T) | (Section 3.1) |
| freeze-check (GPU build, ZK_GPU=1, wsl export) | (Section 3.1) |
| REAL rigs (`uperf-pc full-profile`, ZK_GPU=1) | 3x16: statement 93a98700.. / EVAL 0ae9cdae.. / 985,142 B, accept (1T and 8T); 12x128: 4a3af8c3.. / 742d88e1.. / 1,372,775 B, accept; 12x512: 2f8a92f8.. / 4c259008.. / 1,509,911 B, accept (four runs during development, every one identical) |
| default build (no feature) | builds; `uperf-l battery` / `uperf-k probe` report the stub; uperf-a f936ff79.., uperf-j 45dba7c7.., uperf-d 46471467.. unchanged |

### 3.1 The rest of the gate (final HEAD binary, `ZK_GPU=1`)

- `uperf-pc diff-battery` at ZK_THREADS 1 and 7: passed (16.0 / 15.9 s;
  O1/O2/O3/O5/E2E — the E2E leg proves the same group with the device
  chains and compares the proofs byte for byte against the in-process
  oracle flip).
- freeze-check (the GPU build, `ZK_GPU=1`, `M125_EXPORT_DIR` = the local
  wsl re-export): 98 `ok` rows IDENTICAL to lane K's capture
  (scratchpad k_freeze_new.txt), then the UAGB1-BF/BK real-data rows ran
  and passed ("freeze_check_uagb1_bk: all rows stable", "freeze-check
  passed", exit 0).
- `self-test` (the GPU build, `ZK_GPU=1`, ZK_THREADS 1): see the ledger
  section (run at close).
- `uperf-l dbench 20 8 5 9` (8T, one process, CPU then GPU): prove 0.95 ->
  0.77 s, a.round-g 0.78 -> 0.62 s, a.tree-step 0.28 -> 0.25 (CPU both, the
  device climb OFF), digest IDENTICAL; k9: 111 rounds (86 tiny ones
  declined), 17 layer uploads / 15 round-1 hits, 1.4 GB h2d, in-hook 0.60 s
  = kernel 0.25 + upload 0.27 + handover 0.01.
- `uperf-h bench 20 8 5 9` (8T; compact leaves, c = 2 — the rig's tree
  shape): masked_gkr_prove 0.98 -> 0.72 s, a.round-g 0.795 -> 0.500 s
  (1.6x), DESCENT DIGEST 0bf9d7a3.. both (lane H's value).

## 4. Measurements

### 4.1 The kernels alone — `uperf-l bench 21 [reps]` [WSL-BOX 8T NOISY-SHARED; one instance of 2^21 state-0 elements: the layer 2 x 4M elements = 537 MB, the state-1 tables 5 x 67 MB; the ixf chain 5 x 2^21 elements = 640 MB]

| chain | CPU (8T AVX2 bodies) | GPU (whole chain incl. uploads) | factor | inside the GPU chain |
|---|---:|---:|---:|---|
| fused layer chain, packed layer (18 rounds) | 259-280 ms | 123-179 ms | 1.5-2.2x | kernels 42-45 ms; upload 76-126 ms (memcpy into pinned 27-40, DMA wait 35-85; 671 MB) |
| fused layer chain, compact leaves | 264-274 ms | 78-93 ms | 2.9-3.5x | kernels 39-40 ms; encode 23-24 ms; upload 36-48 ms (168 MB) |
| ixf chain (rq, deg 3, 16 rounds + 80 folds) | rounds 0.09 s + folds 0.11 s (`uperf-d bench 21 rq`) | rounds 0.53 s (of which ~0.35 s = lane K's context/NVRTC init on the first hooked call of the process, ~0.12 s the 640 MB upload) + folds 0.016 s | ~1x excluding the init | kernel: round 24 ms at 1M pairs, folds 1.0-1.4 ms |
| tree step, packed 2^20 -> 2^19 elements | 10-11 ms | 20-38 ms | 0.27-0.5x | D2H of the 67 MB output 16-27 ms — OFF by default |
| tree step, compact leaves | 9-11 ms | 20-35 ms | 0.3-0.5x | idem |

Kernel-only (ZK_GPU_PROFILE=1, warm, 2^19 chain): EXTRACT_FOLD 3.3 ms at
131K element pairs, FOLD 1.7 / 0.9 / 0.5 ms at 65K / 32K / 16K pairs —
**25 ns per element pair per round** (a FOLD round is 10 fixed K-mults + 9
K-mults of the node loop, ~19K instructions per pair: ~0.75 T instr/s =
~16% of the part's integer peak — the kernels sit at ~200 registers/thread
and 8 warps/SM; `k_ixf_round` keeps its five-table state in shared memory
at 4 warps/SM), plus a floor of ~0.2 ms per round (launch + parameter
upload + the node-sum readback under WSL2). Per element pair the 8T AVX2
body is ~66-130 ns (memory-bound at 8T per lane J), so the device kernel
is ~4-5x the 8T CPU on the arithmetic; the chain-level factor is what the
uploads leave.

Two WSL2 findings [MEASURED]: (a) the pinned H2D DMA runs at 5-9 GB/s here
(the memcpy into pinned by the pool at ~20 GB/s is not the limit; chunk
size 4..128 MB within the noise); (b) the first device READ of freshly
DMA'd (or freshly allocated) pages is ~10x slower than the second (a fold
of a 128 MB uploaded table 20-25 ms the first time, 1.3 ms the second;
`k_touch` probes showed the cost is per byte, not per page) — the round-0/1
kernels pay it, and it is inside "kernel+sync" of the extract rounds below.

### 4.2 The REAL 12x512 rig, 8T — THE PoC SHAPE [WSL-BOX 8T NOISY-SHARED, flock, wsl-export, `/usr/bin/time -v`]

| | commit | prove | verify | wall | peak RSS | digests |
|---|---:|---:|---:|---:|---:|---|
| lane J (CPU only, hand AVX2; ledger) | 11.1 | 92.4 | 7.4 | 112.6 s | 11.00 GB | 2f8a92f8.. / 4c259008.. |
| lane K (`ZK_GPU=1`, the GEMM on the device; ledger) | 5.4 | 70.6 | 7.4 | 85.0 s | ~11 GB | identical |
| **this lane (`ZK_GPU=1`, GEMM + K-field kernels), HEAD** | **5.5** | **60.0** | **7.3** | **74.6 s** | 11.2 GB | **identical (accept)** |
| earlier in the session: eager ixf, no VRAM release (the biggest layers declined) | 5.8 | 74.1 | 7.4 | 89.1 s | 11.3 GB | identical |
| after the VRAM fixes, before the lazy-fold length fix | 6.0 / 5.7 | 65.9 / 61.8 | 7.5 / 7.6 | 81.4 / 77.1 s | 11.2 GB | identical |

Phase attribution at HEAD vs the ledger's 8T+K row (round 6): descents
bk.descent-gkr 27.7 -> **16.4 s** (a.round-g 22.3 -> **12.0**, a.tree-step
7.9 -> 8.9 (CPU; noise), trees 6.5); claim layer 15.9 -> 15.2 (cl-tables
5.0, cl-rounds 3.5 -> 5.2, cl-folds 6.8 -> 4.9); prove-group 22.9 (level-h
6.2, psi0-factored 12.1 — untouched), commit 5.5, verify 7.3. The 12.0 s of
a.round-g are 11.7 s inside the hooks (1,233 device rounds: 169 EXTRACT
7.7 s, 152 EXTRACT_FOLD 2.2 s, 912 FOLD 1.9 s): kernel+sync 5.1 s, uploads +
encodes 6.6 s (the packed layers — the checkpoints and the CPU-recomputed
depth-1 layers, ~3.2 GB live at the biggest pair — plus the eq tables and
the compact re-encoding). The claim layer's cl-rounds grew because its 5
biggest instances upload 2-2.5 GB each at round 0 (590-710 ms per instance,
of which the kernel 90-100 ms); cl-folds fell to 4.9 s of which the device
folds are 0.04 s — the rest is the caller's page management (Section 5.3).

### 4.3 The 12x128 and 3x16 rigs, 8T

| rig | CPU only (J, ledger) | K (ledger) | this lane HEAD | descent-gkr / a.round-g | claim / cl-rounds / cl-folds | digests |
|---|---:|---:|---:|---|---|---|
| 12x128 8T | 43.2 s | 33.6 s | **30.0 s** (2.9 / 22.7 / 3.7) | 5.43 / 4.10 (CPU 7.81 / 6.38) | 2.92 / 1.54 / 0.22 (CPU 3.67 / 0.87 / 1.64) | 4a3af8c3.. / 742d88e1.. identical |
| 3x16 8T | 8.1 s | 6.3 s | 6.5 s (0.9 / 4.4 / 1.1) | 0.54 / 0.36 (CPU 0.59 / 0.42) | 0.35 / 0.17 / 0.09 (CPU 0.17 / 0.04 / 0.05) | 93a98700.. / 0ae9cdae.. identical |

At 3x16 (depths 16-17, tiny tables) the device is neutral-to-slightly
negative on the claim layer (uploads and the ~0.2 ms per round floor
against sub-millisecond CPU rounds); the rig gate is the digest.

### 4.4 Lane A's descent bench (`uperf-a descent-bench 20 8 5 9`, 8T; packed leaves — the synthetic uniform values fall back to the packed builder, so this shape uploads packed layers)

| | CPU (feature build, ZK_GPU unset) | ZK_GPU=1 (early: tree climb ON, no round-1 layer hits) | ZK_GPU=1 (HEAD: climb OFF, `uperf-l dbench`) |
|---|---:|---:|---:|
| masked_gkr_prove / a.round-g / a.tree-step | 0.95-0.97 / 0.78-0.80 / 0.26-0.28 s | 1.42 / 1.07 / 1.21 s | 0.77-0.82 / 0.62 / 0.25 s |
| DESCENT DIGEST | 47a58a27.. | identical | identical |

The tree climb on the device made a.tree-step 4.6x SLOWER (the eager D2H
of every recomputed layer over the ~6 GB/s link) — hence OFF by default.

### 4.5 What the factor means, and does not

- On the ported kernels the device is ~4-5x the 8T AVX2 bodies per element
  pair [MEASURED]; on the composed layer chain 1.5-3.5x [MEASURED] because
  the layer/eq uploads (and the compact re-encoding through
  `expand_blocks`) are inside; on the PoC-shape wall -12% (85.0 -> 74.6 s)
  and -33% against the CPU-only 112.6 s [MEASURED, one run each, noisy box].
- The 4070 Laptop is a 55-70 W mobile part behind a WSL2 PCIe link measured
  at 5-9 GB/s. [MODEL, not a claim] A desktop Ada board with a x16 PCIe 4.0
  link (~25 GB/s) and ~3.5x the SMs would cut the upload half of the
  descent's 12 s by ~3x and the kernel half by ~3x — the descents' K-field
  share would land near ~4 s from 22 s at the same shape; the claim layer's
  ixf would gain only if its tables were built on the device (its uploads
  are the cost). Only a measurement on that board may label it.

## 5. What is left / honest state

1. **Structural, the biggest lever left on the descents**: the layers the
   device uploads are (a) the checkpoints (stored packed layers) and (b) the
   depth-1 layer recomputed by the CPU climb from the compact leaves — 3.2 GB
   live at the biggest 12x512 pair, ~0.7 s per pair of upload plus the CPU
   climb itself. A device-side climb whose output stays RESIDENT for round 0
   (no D2H at all) removes both; it needs a proof that no host reader ever
   touches that recomputed layer (its readers are the hooked rounds when
   `fuse_extract` holds, `flush_state`'s extract otherwise, and any
   `p_elem/q_elem` on the layer) — a small change in kfield.rs/gkr.rs's
   contract ("a layer may be device-owned"), which this lane's file
   ownership did not allow; designed, not done. Beyond that, the whole
   tree (build + descent) device-resident is the CONTINUATION Phase-3
   endgame for the descents.
2. **The kernels' efficiency (~16% of peak, register-bound)**: the fixed
   multiplies (10 of the 19 K-mults per pair) can use lane J's 16x16 matrix
   form (no h-step: ~-20% of the reduction work), the burst folds can be
   halved (seed the next burst with the low half — exact under the same
   bound), and a 2-thread coefficient split would double the occupancy at
   the cost of shuffles; each is a kernel-only change gated by `uperf-l
   battery`. Expected ~1.5-2x on the kernel half [ASSUMED].
3. **The claim layer's page management [MEASURED, a lane-D finding]**: with
   the device folds at 0.04 s, `d.cl-folds` is still ~5 s at 12x512 and
   `d.cl-tables` 5 s: the tables (5 x 512 MB per instance, 5 big instances)
   are freshly allocated (first-touch faults inside cl-tables) and given
   back (the mremap/munmap of the shrink and the drop inside cl-folds) every
   instance — ~12 GB of pages faulted in and freed. A same-size table pool
   across instances (fold.rs / the pass driver) would remove most of the
   ~10 s; the device cannot.
4. **The ixf uploads**: 2-2.5 GB per big instance (the tables are built on
   the host). Building the tables on the device (`IxfTable::scalar_table`
   / `eq` / `layer_expand` are host closures) is fold.rs's; not this lane.
5. **The compact re-encoding** through `expand_blocks` (~24 ms per 4M
   leaves at 8T, ~0.3 s per big pair): a `CompactLeaves` accessor to its
   words would make it a 32 MB memcpy — one line in kfield.rs, outside the
   one-hook rule this round.
6. **The tree climb on the device** is implemented and battery-gated but OFF
   (`ZK_GPU_K9_TREE=1`): 0.3-0.5x on this link.
7. **Not a Mac build**: CUDA-only, feature OFF elsewhere (as lane K).
8. Process costs [MEASURED]: the first process on a new kernels_k9.cu pays
   NVRTC ~40 s (then the disk cache) and the driver JIT of the ~4 MB PTX
   ~40 s (then the driver's cache); the K9 device init otherwise ~0.05 s;
   lane K's context/NVRTC init ~0.3 s lands in whichever phase first
   touches the GPU (`d.cl-rounds` in `uperf-d bench`).
