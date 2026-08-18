# U-PERF2 lane K — THE GPU RUNG, step 1 (CONTINUATION Phase 3: CUDA on the reference box)

Branch `uperf2-k` (worktree /home/victor/wt-uperf2-k), opened at bd5e0dd on
2026-08-17. Ledger: PROGRESS_UPERF2.md "Round 6 ... Lane K" + "Agent K
status". This is the Phase-3 GPU rung report of CONTINUATION.md Section 4:
hardware named, watts stated, every number flagged [MEASURED] / [ASSUMED] /
[MODEL], what is bit-identical, what is left.

**Hardware (this box) [MEASURED, nvidia-smi 2026-08-17]:** NVIDIA GeForce RTX
4070 Laptop GPU, 8,188 MiB VRAM, sm_89 (Ada, 36 SMs, boost 3,105 MHz; idles
at 210 MHz and ramps under load), reached from WSL2 (driver 566.14, CUDA
12.7 driver API). Power: default limit 55.00 W, current limit 68.82 W, max
105 W (a 55-70 W-class MOBILE part — the TARGET_CONTRACT board is a <= 450 W
desktop card; nothing here is a claim about that board). Host: Intel Core
Ultra 9 185H (6P + 8E + 2 LP-E, 22 threads), 15 GB. Toolchain: NO CUDA
toolkit; `cudarc 0.13.9` (driver + nvrtc, dynamic linking) against the WSL
libcuda and the pip-wheel NVRTC 12.x runtime (`/home/victor/cuda-root`);
the kernels are CUDA C strings compiled at first use by NVRTC
(`src/ring/gpu/kernels.cu`, ~0.2-0.4 s once per process).

Every wall-clock number below is `[WSL-BOX 8T NOISY-SHARED]` — lane J
built and ran its batteries and rigs concurrently the whole session (load
1-6); the CPU/GPU pairs are taken back-to-back in ONE binary (the feature
build with `ZK_GPU` unset vs `ZK_GPU=1`), so the ratios are trustworthy
while the absolute seconds move by ~10%. The differential evidence
(Section 3) does not depend on the box state.

## 0. One paragraph

The GPU rung exists: `ntt_gemm_modq_small` — the D = 128 batched
integer GEMM in the Goldilocks NTT domain that carries the level-h
cross-garbage and every matvec of the eval proofs (U_PERF_WAVE_REPORT.md
Section 3) — now runs on the RTX 4070 Laptop through ONE hook, behind a
default-OFF cargo feature (`gpu-cuda`) and a runtime switch (`ZK_GPU=1`),
and produces BIT-IDENTICAL output to the CPU kernel by construction (exact
integer windows recovered from Z_p; the same window boundaries; canonical
Goldilocks arithmetic ported op-for-op) — asserted by `uperf-k battery`
(185 GEMM legs cell-by-cell at both moduli, transforms on planted
extremes), by `uperf-pc diff-battery` with every GEMM on the device, and by
the REAL rigs' digests (3x16, 12x128, 12x512 identical to the ledger's).
Measured on THIS box at 8 threads: the kernel itself 8-10x over the 8T CPU
body (64x64x1024: 142 -> 17 ms; 64x64x8192: 964 -> 102 ms; 11x64x8192:
494 -> 48 ms), the composed passes 3x16 9.2 -> 7.3 s, 12x128 58.0 -> 45.0 s
(level-h 10.3 -> 3.0 s, matvec 4.4 -> 1.1 s, commit 6.3 -> 2.9 s), and
THE PoC SHAPE 12x512 8T: **141.5 s = commit 5.5 + prove 126.8 + verify 7.5
(accept, digests identical, 10.9 GB) vs the ledger's quiet 155.6 s** —
level-h 22.2 -> 6.3 s, matvec 7.8 -> 1.7 s, commit 11.7 -> 5.5 s, in a
run whose untouched phases were 5-10% slower than the quiet reference
(NOISY-SHARED; ~135 s [MODEL] quiet). What the GPU does not touch is now
the wall: the descents
(a.round-g) and the claim layer — the next kernel (step 4 of the brief,
not reached this round; design note in Section 5). The 4070 Laptop is a
55-70 W mobile part: the factor is a lower bound for the contract's desktop
board only in the [MODEL] sense stated in Section 4.5, not a claim.

## 1. What landed (files)

- `zkmatrix-rs/Cargo.toml`: feature `gpu-cuda` (default OFF) + optional
  `cudarc = { version = "0.13", default-features = false, features =
  ["driver", "nvrtc", "cuda-12040", "dynamic-linking", "std"], optional =
  true }`. The default build has no cudarc in its object (Cargo.lock lists
  the optional crates cudarc / libloading / windows-link, as any optional
  dependency does; they are not compiled without the feature).
- `zkmatrix-rs/src/ring/gpu/mod.rs`: the module — feature-gated re-exports
  of the CUDA implementation, or a stub whose `enabled()` is a constant
  `false` (default build) with the same API surface (the harness arms
  compile either way).
- `zkmatrix-rs/src/ring/gpu/cuda.rs`: device + NVRTC-compile-once
  singleton (`OnceLock<Option<Mutex<Gpu>>>`; PTX targeted at the device's
  compute capability, generic retry), `enabled()` = feature AND `ZK_GPU=1`
  AND a device initialized AND not bypassed, the mulmod probe, `ntt_batch`
  (transforms for the battery), the ported `ntt_gemm_modq_small` (the
  pipelined execution model of Section 2.3), the harness knobs
  (`set_bypass`, `set_block_mb`), stats.
- `zkmatrix-rs/src/ring/gpu/kernels.cu`: Goldilocks primitives, the length-128
  psi-twisted negacyclic forward / inverse NTTs (batched, shared-memory,
  transposed t-major store, device-side lifts from u32/u64 mod-q and
  i8/i64 small formats), the D = 128 batched split-K GEMM (64x64 and 16x64
  output tiles, 4x4 / 1x4 register tiles, 32-deep K tiles) with the
  split-halves accumulation as two 128-bit integers per cell (u64 lane +
  carry count, `add.cc`/`addc`), the window flush (128-bit sums over the
  splits, `gl_reduce128(acc_lo + EPS*acc_hi)`, inverse NTT, center, mod q,
  add).
- `zkmatrix-rs/src/ring/mod.rs`: `pub mod gpu;`.
- `zkmatrix-rs/src/ring/eval_proof.rs`: ONE hook at the top of
  `ntt_gemm_modq_small_gen` (after the shape asserts / empty return):
  `if super::gpu::enabled() { if let Some(o) = super::gpu::ntt_gemm_modq_small(ctx, a, b, len) { return o } }`.
  Nothing else in that file. `None` (declined: below the minimum work,
  over capacity, no device, or a device error reported once) runs the CPU
  body — which is therefore always the fallback AND the oracle.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-K]` section, `uperf-k
  probe | battery | bench <na> <nb> <len> [reps]`, registered in `main`
  next to the other `uperf-*` arms.
- This report + "Agent K status" in PROGRESS_UPERF2.md.

Runtime knobs (none changes a value): `ZK_GPU=1` (on), `ZK_GPU_MIN_MACS`
(decline GEMMs below this many D-domain MACs; default 2^22 — a launch
costs ~0.1-0.3 ms of fixed overhead), `ZK_GPU_BLOCK_MB` (device budget
per u-block, default 256 MB), `ZK_GPU_STAGES` (sub-blocks per call the
pipeline aims for, default 4), `ZK_GPU_VERBOSE=1` (a timing line per
call), `ZK_GPU_PROFILE=1` (per-kernel attribution; serializes),
`ZK_GPU_RFWD/TFWD/MAXRREG` (NVRTC-time kernel-shape experiments).
Build: `CARGO_TARGET_DIR=<...>/target-gpu cargo build --release --features
gpu-cuda --manifest-path <...>/zkmatrix-rs/Cargo.toml` with
`CUDA_ROOT=/home/victor/cuda-root
LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib`
(the same LD_LIBRARY_PATH at run time; a separate target dir keeps the
default build's incremental state).

## 2. Method (why the values are identical)

### 2.1 The exact-integer window argument (unchanged from U_PERF_WAVE_REPORT.md Section 3)

`ntt_gemm_modq_small` computes out[ia][ib] = sum_u a[ia][u] * b[ib][u] over
R_q by (i) lifting each ring to Z_p (a: balanced mod q; b: the small
integers), (ii) transforming, (iii) accumulating pointwise products over
a WINDOW of at most `ntt_window_terms(q, s_max)` positions — the largest
count under the single-prime contract n * D * (q-1)/2 * s_max <= (p-1)/2,
so every accumulated coefficient is an exact integer with |value| <
(p-1)/2 and Z_p determines it uniquely — (iv) recovering it
(`gl_reduce128`, inverse NTT, `center_from_p`), reducing mod q and adding
into the output. The output of a window is therefore a FUNCTION of the
exact integer partial sums, and those are functions of the operands only.
Two implementations agree bit-for-bit iff they (a) use the same window
boundaries, (b) compute the same field elements (the transforms and the
pointwise sums are field expressions; every op returns the canonical
representative in [0, p), so equal field elements are equal u64s), (c)
apply the same recovery. The GPU port does exactly that:

- (a) the hook receives the same (ctx, a, b, len); the port calls the same
  `ntt_window_terms(q, s_max)` with s_max computed from the same
  coefficients (per ring, over every ring of every slice — the same set
  `SmallRings::max_abs` scans); windows are `[u0, min(u0 + window, len))`
  as in the CPU body; over capacity (window == 0) the port declines and
  the CPU body runs its exact oracle.
- (b) `kernels.cu` ports `reduce128` / `add_p` / `sub_p` / `mul_p`
  branch-for-branch (`__umul64hi` for the high product half — NVRTC has
  no __int128), and the transforms are the CPU's DIT forward / GS inverse
  with the CPU's twiddle tables (`psi_brv` / `ipsi_brv` / `n_inv` copied
  from `aux::build_tables()`), the same (stage, group, j) structure and
  output order. The lifts are the CPU's (`lift_to_p(balanced_mod_q(x, q))`,
  `lift_to_p(v)`) evaluated on the device from the packed formats (u32 for
  q < 2^32 — every canonical mod-q value fits; u64 otherwise; i8 for s_max
  <= 127, i64 otherwise) — the same integers reach the same formulas. The
  pointwise accumulation keeps the CPU's split-halves integers: the low
  and high u64 halves of every 64 x 64 product are summed as two 128-bit
  integers per cell (a u64 lane plus a carry count each — `add.cc.u64` /
  `addc.u32`), per split of the K range and per u-block; the flush adds
  the splits' 128-bit pairs and computes `gl_reduce128(acc_lo + EPS *
  acc_hi)` on the SAME u128 the CPU reduces (`dot_split_halves` sums the
  same halves; the u128 cannot overflow under the window bound: both sums
  < 2^95, EPS * acc_hi < 2^127). Even where an implementation detail
  differs (the order of the additions; the split-K partial sums), the
  quantities are exact integers, so the value is the same.
- (c) the inverse transform, `center_from_p`, `mod_q_centered` (|x| % q,
  q - r when negative and non-zero) and `zq.add` are ported as written.

The CPU body's zero-ring shortcut (skip the transform of an all-zero
ring) is a pure speed shortcut — the transform of the zero ring is the
zero vector — so the GPU transforming every ring changes nothing.

### 2.2 What is asserted, not argued

`uperf-k battery` (Section 3) checks the transforms on planted extremes
(all-constant rings at 0, 1, 2, p-1, p-2, p/2, p/2+1, EPS, EPS+1, 2^32,
2^32-1, 2^63, p-2^32; unit vectors of those at positions 0/1/63/64/127;
3,000 random rings), and the whole GEMM cell-by-cell against the CPU body
(bypassed) at q31 AND q46 with s_max in {1, 2, 64, 2^20} (q31: windows
2^26 / 2^25 / 2^20 / 64 terms — the last crosses inside every len >= 65
and rides the i64 b-format) and {1, 64, 2^40} (q46: 2048 / 32-term
windows / OVER CAPACITY — declined by both), 14 shapes crossing the 64x64
tiles (65x70, 130x3, 1x129), the 16-row tile (na <= 16), the u-blocks
(`set_block_mb(1)` forces 1 MB u-blocks so a window spans many device
round trips and the split count changes on the tail), zero rings and
whole-zero slices, planted mod-q extremes (0, 1, q-1, q/2, q/2+1) and
+-s_max, both small-ring stores (boxed `Vec<i64>` and the flat i8
`DigitCols`), plus the level-h and matvec entry points through the hook
(GPU-live vs bypassed).

### 2.3 Execution model (where the time goes)

Per call: the positions [0, len) are cut into the CPU's windows, each
window into u-blocks of `ublk` positions — within a device budget
(default 256 MB of transformed + staged data) and at least
`ZK_GPU_STAGES` (4) sub-blocks per call so the stages overlap. Per
u-block the host PACKS the operands into pinned staging (parallel over
positions on a `ZK_THREADS`-sized pool; u32 / i8 when they fit), the copy
stream UPLOADS them (`cuMemcpyHtoDAsync`), the compute stream TRANSFORMS
them (32 rings per block in shared memory, t-major store `A_t[t][ub][ia]`)
and runs the split-K GEMM (grid = 64-column tiles x row tiles x (128 t x
ks splits); each block owns its accumulator cells); two staging/source
buffers ping-pong with events (`ev_h2d` = staging reusable, `ev_fwd` =
device source reusable), so pack(i+1) and h2d(i+1) overlap gpu(i). A
window ends with the flush kernels; the mod-q output is copied back once
per call (pinned). Device scratch and pinned staging stay resident
between calls (grown on demand; ~0.35 GB device + ~0.15 GB pinned at the
rig's shapes; the 12x128 rig's peak RSS moved 4,100 -> 4,263 MiB).

Steady-state attribution at the level-h block shape 64x64x1024 (0.54 G
MACs; ZK_THREADS 8; `ZK_GPU_PROFILE=1` serializes the kernels)
[MEASURED, NOISY-SHARED]: s_max scan 2.4 ms (host; the CPU body pays the
same scan) + pack 8.4 ms (host, overlapped) + h2d 3.6 ms (42 MB = 11.7
GB/s pinned) + fwd 3.0 ms (128K rings) + gemm 7.2 ms (74 G MAC/s) +
flush 1.2 ms + d2h 1.0 ms; overlapped wall 17.2 ms (the CPU body: 142 ms
at 8T). The GEMM kernel is at ~30% of the IMAD-bound peak of this part
(a 64 x 64 -> 128 product costs ~10 IMAD-class instructions on sm_89;
the u32-limb formulation of Section 5 is the known lever); the
transfers, the host pack and the fixed per-call costs are the rest.

## 3. Differential evidence (all at HEAD of uperf2-k, feature build)

| gate | result |
|---|---|
| `uperf-k probe` | RTX 4070 Laptop GPU: mulmod 0 mismatches of 1,048,576 (100 launches x 2^20); 18.07 G mulmod/s (the orchestrator's probe: 14.75) |
| `uperf-k battery` (ZK_THREADS 1, 2, 7) | transforms: 3,078 rings (78 planted extremes + 3,000 random) fwd == CPU, inv == CPU; GEMM: 185 legs byte-identical GPU vs CPU (69,839 output rings compared; q31 + q46; s_max 1/2/64/2^20 and 1/64; tiles / u-blocks / windows crossing; i8 and i64 stores; zero rings) + 15 over-capacity legs declined by both; hook: 8 level-h/matvec legs identical GPU-live vs bypassed. Passed at 1T, 2T, 7T. |
| `uperf-pc diff-battery` with `ZK_GPU=1 ZK_GPU_MIN_MACS=0` (every GEMM on the device; 270 device calls) | O1 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2 (proofs identical oracle vs fast + accept) at 1T, 2T, 7T |
| REAL rigs, `uperf-pc full-profile` under `ZK_GPU=1` | 3x16: statement 93a98700…, EVAL-PROOF DIGEST 0ae9cdae…, 985,142 B, accept; 12x128: 4a3af8c3… / 742d88e1… / 1,372,775 B, accept; 12x512: Section 4.4 — all identical to the ledger's acceptance digests |
| default build (no feature) | builds; `uperf-k probe` reports the stub; the hook compiles to a constant-false test; no behavior change |

## 4. Measurements

### 4.1 The kernel alone — `uperf-k bench <na> <nb> <len>` [WSL-BOX 8T NOISY-SHARED], best of 3-5, warm (the GPU clock ramps from 210 MHz idle; a cold first call also pays ~0.2-0.4 s of NVRTC + context + pinned allocations once per process)

| shape (na x nb x len, q31, digits |w| <= 2) | D-domain MACs | CPU body 8T | GPU | factor |
|---|---:|---:|---:|---:|
| 64 x 64 x 1024 (the level-h block: `LEVELH_BLOCK` = 1024) | 0.54 G | 142-152 ms | 17.2-19.8 ms | 7.7-8.3x |
| 64 x 64 x 8192 (kernel-bench's level-h shape) | 4.3 G | 964 ms | 102 ms | 9.4x |
| 11 x 64 x 8192 (the level-0 matvec: KAPPA_AGG rows) | 0.74 G | 494 ms | 84 ms (64-row tile) -> 48 ms (16-row tile) | 5.9x -> 10.4x |

`uperf-pc kernel-bench 64 8192 noref` (one shot, COLD — the GPU line
includes device init + NVRTC + first allocations inside the timed call):
level-h 1.002 s (8T CPU) -> 0.467 s; matvec 0.467 s -> 0.101 s (before the
16-row tile).

### 4.2 The 3x16 REAL rig, 8T (`uperf-pc full-profile 3 16`, wsl-export, flock)

| | commit | prove | verify | wall | level-h (ep) | matvec (ep) | precommit-u0 | digests |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| CPU (feature build, ZK_GPU unset) | 1.3 s | 6.6 s | 1.2 s | 9.2 s | 2.03 s | 1.06 s | 1.18 s | 93a98700… / 0ae9cdae… / 985,142 B |
| `ZK_GPU=1` (31 device calls) | 1.0 s | 5.1 s | 1.2 s | **7.3 s** | 0.48 s | 0.68 s | 0.84 s | identical |

### 4.3 The 12x128 REAL rig, 8T

| | commit | prove | verify | wall | level-h | matvec | precommit-u0 | peak RSS | digests |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| CPU | 6.3 s | 47.3 s | 3.6 s | 58.0 s | 10.33 s | 4.38 s | 5.47 s | 4,100 MiB | 4a3af8c3… / 742d88e1… / 1,372,775 B |
| `ZK_GPU=1` (109 device calls, 5.2 GB uploaded) | 2.9 s | 37.8 s | 3.7 s | **45.0 s** | 3.00 s | 1.12 s | 2.20 s | 4,263 MiB | identical |

Untouched by the GPU and now the wall: descents 16.2 s (a.round-g 13.8),
psi0-factored 5.8 s (verifier), fold 2.1 s, transport 1.2 s, the claim
layer.

### 4.4 The 12x512 REAL rig, 8T — THE PoC SHAPE, ONE run [WSL-BOX 8T NOISY-SHARED, flock, wsl-export]

| | commit | prove | verify | wall | peak RSS | digests |
|---|---:|---:|---:|---:|---:|---|
| ledger reference (96559ee, QUIET; the 20-run series: p50 153.1 / p95 155.9 s) | 11.7 s | 134.9 s | 7.3 s | 155.6 s | 10.98 GB | 2f8a92f8… / 4c259008… / 1,509,911 B |
| `ZK_GPU=1`, this run (194 device calls, 10.6 GB uploaded; lane J active, load ~5) | **5.5 s** | **126.8 s** | 7.5 s | **141.5 s** | 10,929 MiB | **identical** (accept) |

Phase attribution of the GPU run vs the ledger's quiet 12x512 8T
attribution: level-h 22.2 -> **6.3 s** (174 calls of 64x64x1024: 3.3 s
inside the device path = 19 ms per call; the remainder is the host-side
phi fill of `level_h_pairs_with_block` and the s_max scans), matvec 7.8
-> **1.7 s**, commit 11.7 -> **5.5 s** (the precommit-u0 matvecs),
prove-group 38.7 -> 23.4 s. The phases the GPU does not touch ran 5-10%
SLOWER than the quiet reference in this shared run (descents 72 -> 76.9 s
= bk.descent-gkr 65.5 + trees 11.4, a.round-g 52.5 -> 55.7; claim layer
23.9 -> 26.2; psi0-factored 12.2 s across prover + verifier) — the box
was not quiet (lane J's rig ran concurrently outside the flock's window
at the start; load average 4.5-5). Net: -14.1 s (-9%) on the wall in a
noisy run; summing the GPU-touched phase deltas (-28.2 s) against the
quiet reference gives ~135 s [MODEL from the phase sums — a QUIET
ZK_GPU=1 run is queued behind the merge; do not cite 135 s as measured].
What is now the wall: descents ~72-77 s (a.round-g 52-56 + tree-step
16-17 + trees 11), the claim layer 24-26 s (cl-folds 11.5, cl-rounds 7.5,
cl-tables 7.2), psi0-factored, fold 4.0, CRS 3.5, kernel-rows 3.5.

### 4.5 What the factor means, and does not

- The GPU factor over the 8T CPU on THIS box, at the ported kernel: 8-10x
  at the rig's shapes [MEASURED]. On the composed pass it is bounded by
  the kernel's share: 12x128 prove 47.3 -> 37.8 s (-20%), wall 58.0 -> 45.0
  s (-22%); the descents and the claim layer are the remaining wall.
- [MODEL, not a claim] A desktop Ada board (e.g. a 4090-class part at 450 W:
  128 SMs vs 36, ~1 TB/s VRAM, x16 PCIe 4.0 host link ~25 GB/s vs the
  ~12 GB/s pinned h2d measured here) would move the device-side kernels
  by ~3.5x and the uploads by ~2x; the host-side pack / s_max scan and
  the un-overlapped first stage would not move, so the ported kernel's
  wall would land near ~5-6 ms per level-h block (from 17) — a ~2.5-3x
  further factor on the ported share, NOT on the composed pass. The
  TARGET_CONTRACT's 5-15 s line is a statement about the WHOLE pass; the
  next kernels (Section 5) decide it, and only a measurement on that
  board over >= 20 warm idle runs may label it.

## 5. What is left / honest state

- LANDED: the plumbing (feature, device/NVRTC singleton, probe), the port
  of `ntt_gemm_modq_small` (bit-identical, batteries + rig digests), the
  pipelined execution model, the harness arms, the measurements above.
- NOT reached: step 4 of the brief, the descent round kernel
  (`k9_fused_round_par` / the packed K-field lane kernels of
  gkr_masked.rs / kfield.rs; a.round-g = 52.5 s of the 12x512 8T pass).
  Design note for the next round: the round kernel is a streaming
  five-table fused pass over K-field elements packed as u32 lanes with
  lazy u64 planes — a bandwidth-bound map over ~2^21-2^22 blocks per
  layer with a per-block reduction into a handful of K-field
  accumulators; a GPU port is ONE kernel per round (blocks over the lane
  range, per-block partial planes reduced in a fixed order), the same
  one-hook discipline at the top of the round function, and the tree
  layers resident on the device across the descent (they are read once,
  top-down — the h2d of a layer is amortized over its round). The
  exact-integer planes are order-independent, so any block partition is
  bit-identical; lane J's AVX2 work this round owns the CPU side of the
  same kernels — coordinate the hook placement with its final form.
- GEMM kernel headroom [ASSUMED from instruction counts]: a u32-limb
  formulation (three 21/22-bit limbs per operand, nine `mad.wide.u32`
  partial products accumulated in u64 lanes with 2^20 terms of headroom,
  2x2 register tiles) removes the emulated 64 x 64 -> 128 products and
  the carry chains; expected ~2.5-3x on the GEMM kernel (7.2 -> ~2.5 ms
  at 64x64x1024), after which the call is transfer/pack-bound (~12 ms).
  Also open: fusing the phi fill (`Phi0Source::fill`, the host-side
  producer of the level-0 a operand — a per-ring `poly_scale`) into the
  device pack would remove ~half the host work of level-h; the
  `SmallRings` i8 store is widened to i64 per ring and narrowed back by
  the pack (the trait exposes only the i64 view — an i8 fast path needs
  a trait addition in eval_proof.rs, not this lane's file).
- Not a Mac build: the NEON/Metal question is untouched (the feature is
  OFF there; cudarc is not compiled). CUDA-only by design of this round.
