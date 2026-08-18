# U-PERF2 lane Q — the prover's CPU-side blocks: the level-h device session, the combine family, the chain GEMM, the digit witness, the CRS SHA-NI core

Status: LANDED 2026-08-18 (every item below is committed on `uperf2-q`;
the final binary is 6a4c700 + this report's commit). Written by lane Q
of the U-PERF2 round 9 (ledger: PROGRESS_UPERF2.md "Lane Q" + "Agent Q
status"). Worktree /home/victor/wt-uperf2-q, branch uperf2-q, opened at
151edc9 (= main after round 8). Box: the WSL box (Intel Core Ultra 9
185H, 6P + 8E + 2 LP-E cores as 22 vCPUs, 15 GB; RTX 4070 Laptop 8 GB;
the `m125_ffn_export_wsl` copy the rigs use). Lane P (descent kernels)
ran concurrently in /home/victor/wt-uperf2-p for most of the session
(load 1.5-6): every wall-clock number carries `[WSL-BOX 8T QUIET |
NOISY-SHARED]` and `[MEASURED]` / `[ASSUMED]` / `[MODEL]`; the phase
counters and the same-binary A/Bs are what to read.

The rule (unchanged): every optimization is DIFFERENTIAL — the
pre-change body stays reachable as `*_ref` / the CPU body and under
`ZK_UPERF_ORACLE=1` (or the item's own knob); the outputs are
byte-identical; the batteries hold at ZK_THREADS 1/2/7 in BOTH builds;
freeze-check's 98 on-box rows are identical to the pre-change capture;
the REAL rigs reproduce their digests (3x16 93a98700… / 0ae9cdae…;
12x128 4a3af8c3… / 742d88e1…; 12x512 2f8a92f8… / 4c259008…, accept).

## 0. One paragraph

The four CPU-side blocks of the brief (prove-group 12.3 s, commit 5.0,
CRS 2.8, transport 2.0 = 22.1 s of the 34.1 s 12x512 8T+GPU pass) are
now 12.3 s (prove-group 7.0, commit 2.6, CRS 1.3, transport 1.4) and
the pass is **25.0 s = commit 2.5 / prove 19.3 / verify 1.8** [MEASURED,
WSL-BOX 8T, load ~2.4 NOISY-SHARED-ish], RSS 6.70 GB, every digest
identical; CPU-only 86.1 -> 81.2 s (7.2 / 69.7 / 2.6, 11.0 GB); 12x128
15.6 -> 12.2 s; 3x16 4.3 -> 3.6 s. What did it: (1) a LEVEL-H DEVICE
SESSION — the level-0 h table accumulated on the device across the
u-blocks (the phi window as a value-ring POOL with the limb radix
applied on the device instead of a host `poly_scale` per digit ring, w
packed i8 from the flat store, K's split-halves accumulator resident,
one flush per exact-integer window, host fill of stage i+1 under the
device work of stage i): 4.61 -> 1.83 s, now device-bound at ~10 ms per
64x64x1024 stage; (2) ONE COMBINE KERNEL on the device for the "few
fixed small rings x many streamed slices -> one inverse per output"
family — the quinary fold (exact i64), the factored psi0 (Phi_0 streamed
from the same pool), the transport's one-sided limb-split combines (S /
T5, recombined on the device) and compute_psi: psi0 2.65 -> 1.58, fold
1.89 -> 0.84, transport 1.95 -> 1.36; (3) the commit phase's chain GEMM
as an exact int8 device kernel, the balanced digit decomposition and
the floor requant by mask/shift instead of per-element libdivs (digit
witness 1.13 -> 0.53), the flat i8 store's bound 127 in place of
whole-store `max_abs` scans (ep.matvec 1.57 -> 0.84, precommit 3.46 ->
1.63); (4) the CRS SHA-256 blocks on a hand-written 4-lane SHA-NI core
(no new crate; the constant key quads' rounds precomputed; the stream
buffer an unzeroed reused scratch): m.crs-blocks 1.92 -> 0.51, CRS 2.76
-> 1.28 — the CRS bytes are the freeze and freeze-check is identical.
Everything keeps its CPU body as the oracle behind `ZK_GPU_LH=0` /
`ZK_GPU_CB=0` / `ZK_GPU_MM=0` / `ZK_CRSNI=0` / `ZK_UPERF_ORACLE=1`;
`uperf-q battery` (101 legs on the GPU build, 4 CPU legs on the
default) is green at 1/2/7T with one digest per build, every other
lane's battery reproduces its ledger digest in both builds, freeze rows
identical, self-test / agg-matmul / bh-verifier green. Left (Section
5): the rows pass's T rings on the device (q.rows-t 1.15 s — designed as
a batched u32 GEMM with the fold reduction, not built), K's GEMM kernel
(level-h is device-bound in it), the deeper-level session overheads,
the psi0 pool fill (the host PHI MAC).

## 1. Design and where the time was

Baseline (the merged tree at 151edc9, 12x512 8T+GPU, QUIET, 34.1 s;
`fp_12x512_NO_gpu.txt`): bg.prove-group 12.30 (bg.level-h 4.61 =
ep.level-h-pairs 4.59 over 17 calls; ep.psi0-factored 2.65 with
m.psi0-ntt 1.74 and m.phi-setup 0.85; bg.fold 1.89 with m.fold-ntt 1.14;
bg.kernel-rows 1.77; bg.matvec-chunks 1.50 with ep.matvec 1.57;
bg.kernel-phi 0.39), bg.commit-phase 5.02 (d.precommit-u0 3.46,
d.chain-derive 1.33, d.digit-witness 1.13), ep.crs-expand 2.76
(m.crs-blocks 1.92, m.crs-walk 0.07), ep.transport 1.95 (m.tr-s 1.17,
m.tr-t5 0.37, m.tr-asm 0.23). Target ~22 s -> ~13 s [ASSUMED]; landed
at 12.3 s [MEASURED].

1. **The level-h device session** (`gpu::level_h_stream`, cuda.rs;
   hook at the top of `level_h_pairs_with_block`). Before: per
   1024-position u-block a host fill of r x 1024 u64 rings (one PHI_vr
   MAC per value ring, then `poly_scale` = a u128 `% q` per coefficient
   per limb), then one K GEMM call (an s_max scan of the block, u32
   pack, upload, transforms, GEMM, flush, d2h, and a host `poly_add` of
   the 4096 output rings) — 174 calls of 64x64x1024 at 12x512, each
   ~19 ms with the fill and first pack un-overlapped. After: the a
   operand is a POOL of u32 value rings (one per VALUE ring the stage
   touches — l0 digit rings share it) plus a (pool index, radix)
   descriptor per digit ring (`Phi0Source::pool_count` /
   `fill_pool_u32`); the device kernel `k_ntt_fwd_pool` computes
   `(pool * radix) % q` (pool, radix < q < 2^32: exact in u64; the same
   canonical residue `poly_scale` writes) and lifts / transforms as K's
   `k_ntt_fwd`; w is packed i8 straight from the flat store
   (`SmallRings::as_i8`, a new default trait method); s_max is the
   store's bound 127 when the level fits that window (no scan; any bound
   >= the true max keeps the exact-integer contract and the flush
   partition does not move a value); the split-halves accumulator stays
   on the device across the stages with one flush (reduce -> inverse ->
   center -> mod q -> add) per window and one d2h per level; ping-pong
   pinned staging + events overlap the host fill of stage i+1 with the
   device work of stage i. Bit-identity: the same exact 128-bit
   split-halves integers of the same products, K's flush on the same
   u128, and mod-q addition of exact partial sums is
   partition-independent (the CPU body itself relies on this across its
   u-blocks). Oracle: the unchanged loop (bypass, `ZK_GPU_LH=0` /
   `set_lh_session(false)` = K's per-block path, `ZK_UPERF_ORACLE=1`,
   the default build); `ZK_GPU_LH_BLOCK` / `set_lh_block` = positions
   per stage (default = the caller's 1024). q >= 2^32 declines (the u32
   pool). Measured: 4.61 -> 1.83 s (174 stages at 9.4-9.9 ms, host fill
   0.36 s total, drain 0.07: DEVICE-BOUND — fwd ~3 + gemm ~7 ms per
   stage per K's attribution); `uperf-q lh-bench 4096 4096 64` 8T: CPU
   body 1.353 s / K's per-block path 0.294 s / the session 0.100 s
   (2.96x over K's) [NOISY-SHARED].
2. **The combine session** (`gpu::combine_stream`, `k_combine`; sources
   `CombineSrc::{Pool, Small, ModQ}`, outputs `CombineOut::{ModQ{two_l},
   ExactI64}`). Per stage of n positions (default 2048, `ZK_GPU_CB_BLOCK`
   / `set_cb_block`): the host packs the stage's streamed rings (the
   pool + descriptors via the same fill; i8 / i64 slices [k][ub]; u32
   mod-q slices, ragged tails zero-padded), the device transforms them
   into a [t][k][ub] store (`k_ntt_fwd_pool` layout 1 / `k_ntt_fwd`),
   `k_combine` accumulates the split-halves cell (t, o, ub) over the K
   fixed rings (transformed once per session; up to two output rows),
   `k_flush_reduce` (ks = 1) + `k_ntt_inv` (mode 1 mod-q accumulate
   into a zeroed output row / new mode 2: the exact centered i64) write
   the stage's outputs in place; `k_limb_recombine` (new) does the
   host's `(v0 + mul_q(2^L, v1)) % q` on the device; the whole result
   comes back once. Hooks (each after the CPU body's own capacity
   decision, so the exact-integer contract is the caller's):
   `fold_chunks_ntt_gen` (Small, ExactI64), `psi_level0_multi_impl`
   (Pool from a `Phi0Source::new_for(.., untimed)` — value
   `compute_psi(Phi_0)` == `psi_level0_factored_multi` by F's / M's
   battery legs; the r-term window checked), `ntt_combine_general`'s
   one-sided regime (the alpha limbs from `split_limbs(balanced)` as the
   two fixed rows, exactly `fwd_modq_limbs`' lifts), `compute_psi_ntt`
   (ModQ ragged). Oracles: the loops (`ZK_GPU_CB=0` / `set_cb_session`,
   bypass, oracle mode, q >= 2^32, the default build). Measured (12x512):
   psi0 2.65 -> 1.58 (the level-0 pool sessions are now FILL-bound —
   the host PHI MAC of the act group ~190 ms per session against ~80 ms
   of device wait), fold 1.89 -> 0.84 (m.fold-ntt 1.14 -> 0.60),
   transport 1.95 -> 1.36 (m.tr-s 1.17 -> 0.72: ~0.37 in the four
   level-0->1 sessions, ~0.35 in 26 small deeper-level sessions of
   ~13 ms each — pack-bound), compute-psi 0.24 -> 0.23 (below the
   minimum work mostly), verify 2.6 -> 1.8 (its psi0 x2 + transport).
3. **The commit phase.** (a) `bf_matmul_i64`'s int8 x int8 -> i32 case
   on the device (`k_gemm_i8`, 64x64 tiles, i32 IMAD; exact sums —
   bit-identical by definition; `ZK_GPU_MM=0` keeps the CPU row-blocked
   loop): ~2-3 ms per 512x768x2048 GEMM (pack 1.4 + kernel 2.4 + d2h
   3.2 ms) against ~35 ms; the one-time device init (~0.5 s NVRTC +
   context) now lands in d.chain-derive instead of the first precommit
   GEMM (a wash for the wall). (b) `bf_floor_requant`: the Euclidean
   quotient / remainder by 2^shift as `>>` / `&` (two's complement;
   `bf_floor_requant_div` kept as the oracle). (c) The balanced digit
   decomposition (`digits_into` in the bin, `digits_into_local` in
   eval_proof.rs): the unique d == rem (mod 2^e0) in [-half, half) is
   `((rem + half) & mask) - half` and the carry `(rem - d) >> e0` is the
   exact quotient — the div/mod body computed the same digit through
   `%`, two adjustments and `/` (kept as `digits_into_div`;
   `digits::exact_digit_decompose` is the standing oracle): d.digit-
   witness 1.13 -> 0.53 (also the fold's `q.fold-split` and every
   `decompose_polys_*`). (d) The flat i8 store's bound 127 in place of
   the whole-store `max_abs` scans in `fold_chunks_ntt_gen` (wmax) and
   K's `ntt_gemm_impl` (s_max, when the call fits the 127-window: the
   i8 format is chosen either way and the window is a function of the
   bound only): ep.matvec 1.57 -> 0.84, bg.fold's non-NTT part 0.75 ->
   0.24. (e) `kernel_row_factors` memoized per `MultiClaimKernel`
   (`OnceCell` keyed by (q, s); the rows pass, the level-h source and
   the two factored psi builds shared it 4x per pass): m.phi-setup 0.85
   -> 0.26 (the G blocks were only 0.08 of it — `q.phi-gblocks`).
   Precommit-u0 3.46 -> 1.63 (its CRS share by item 4, its level-0
   matvec by (d)).
4. **The CRS.** `crs_blocks_into` now runs a hand-written SHA-NI core
   (`crs_sha_ni::blocks_into`, `std::arch::x86_64` `_mm_sha256rnds2 /
   msg1 / msg2`, runtime-detected `sha + sse4.1 + ssse3`; NO new crate —
   the `sha2` crate stays for everything else and as the oracle
   `crs_blocks_into_ref` under `ZK_CRSNI=0`): every block is one
   64-byte compression of key (32 B) || i_le (8 B) || padding, so the
   rounds that read only the key's eight words (0..7) are computed once
   per call and four blocks run in lock-step (independent `sha256rnds2`
   chains hide the latency); the counter quad is built directly
   (byte-swapped halves, 0x80000000, the length 320). The stream buffer
   is a process scratch (`CRS_SCRATCH`, taken / returned per call, kept
   up to 512 MB — the 12x512 level-0 A streams of 0.6 / 1.35 GB are
   freed after use so the peak RSS is unchanged), never zeroed
   (`set_len`; every byte of the new range is written by the block
   generator before the counters or the walk read it). Measured:
   `uperf-m crs-bench 20000` 8T v2 blocks 10.2 -> 6.4 ns/block (1T 64.9
   -> 36.9); the rig's m.crs-blocks 1.92 -> 0.51 s (the scratch reuse
   and the missing zeroing are most of the difference beyond the SHA
   rate), ep.crs-expand 2.76 -> 1.28. The remaining CRS time is the
   poly walk (~0.7 s: 2.2M 1 KB allocations + first-touch faults; a flat
   CRS storage would remove it — every consumer takes `&[Poly]`, not
   this round).

Prof ids 80-88 (`q.*`, observation only): q.lh-fill / q.lh-wait /
q.lh-stream / q.lh-smax (the level-h session), q.cb-fill / q.cb-wait
(the combine sessions), q.phi-gblocks, q.fold-split, q.rows-t; 89 stays
reserved. Runtime knobs (none changes a value): `ZK_GPU_LH` (0 = off),
`ZK_GPU_LH_BLOCK`, `ZK_GPU_CB`, `ZK_GPU_CB_BLOCK`, `ZK_GPU_MM`,
`ZK_CRSNI`; harness knobs `set_lh_session` / `set_lh_block` /
`set_cb_session` / `set_cb_block`. `ZK_GPU_VERBOSE=1` prints one line per
session (stages, fill, wait, h2d) and per chain GEMM.

## 2. What landed (files)

| item | function / kernel | oracle | call sites | status |
|---|---|---|---|---|
| level-h session | cuda.rs `level_h_stream[_force]` / `Gpu::level_h`, kernels.cu `k_ntt_fwd_pool`; eval_proof.rs `Phi0Source::pool_count` / `fill_pool_u32`, `SmallRings::as_i8` (default None; `[i8]` Some) | the loop of `level_h_pairs_with_block` (bypass / `ZK_GPU_LH=0` / oracle mode / default build) | `level_h_pairs_with` <- `bg_level_h_src` (level 0, both groups) | LANDED |
| combine session | cuda.rs `combine_stream` / `combine_accepts` / `Gpu::combine`, kernels.cu `k_combine`, `k_limb_recombine`, `k_ntt_inv` mode 2 | the CPU loops (`ZK_GPU_CB=0` / bypass / oracle mode / q >= 2^32 / default build) | `fold_chunks_ntt_gen`, `psi_level0_multi_impl` (via `Phi0Source::new_for`), `ntt_combine_general` (one-sided), `compute_psi_ntt` | LANDED |
| chain GEMM | cuda.rs `matmul_i8` / `Gpu::matmul_i8`, kernels.cu `k_gemm_i8` | `bf_matmul_i64`'s row-blocked loop (`ZK_GPU_MM=0`; `bf_matmul_i64_ref`) | `bf_derive_chain` (3 per layer) | LANDED |
| floor requant | bin `bf_floor_requant` (>> / &) | `bf_floor_requant_div` | `bf_derive_chain` | LANDED |
| digits by mask/shift | bin `digits_into`; eval_proof.rs `digits_into_local` | `digits_into_div`; `digits::exact_digit_decompose`; `decompose_poly_*_ref` | `agg_digit_witness[_cols]`, `decompose_polys_modq/small` | LANDED |
| i8 bound 127 | eval_proof.rs `fold_chunks_ntt_gen` (wmax); cuda.rs `ntt_gemm_impl` (K's s_max) | the scans (boxed stores / over-window calls still scan) | every fold / matvec / GEMM call on the flat store | LANDED |
| row-factor memo | eval_proof.rs `MultiClaimKernel::row_factors` (`OnceCell<(q, s, Vec<KElem>)>`), `kernel_row_factors` | recomputation (a pure function; the first call computes) | `PhiFactored::new`, the rows pass | LANDED |
| CRS SHA-NI | eval_proof.rs `crs_sha_ni::blocks_into`, `crs_blocks_into` dispatch, `crs_blocks_into_ni` (battery), `CRS_SCRATCH` in `expand_level_matrix_par_v2` | `crs_blocks_into_ref` (the sha2 crate; `ZK_CRSNI=0`; non-x86 / no SHA-NI); `expand_level_matrix_par_v1` / `_raw` | every CRS miss | LANDED |
| harness | bin `// [UPERF2-Q]` section: `uperf-q battery | lh-bench [rows] [cols] [r]`; ct_engine::prof ids 80-88 | — | — | LANDED |

Files touched: `zkmatrix-rs/src/ring/eval_proof.rs`, `commit.rs` (NOT
touched in the end), `gpu/cuda.rs`, `gpu/kernels.cu`, `gpu/mod.rs` (a
`// [UPERF2-Q]` block: re-exports + the stub), `ct_engine.rs` (the Q
lines only), `src/bin/ring_matmul.rs` (the commit / prove-group regions:
`bf_floor_requant[_div]`, `bf_matmul_i64` hook, `digits_into[_div]`,
`bg_multi_kernels` (the new field), `bg_fold_gen` (a timer); the
`Some("uperf-q")` dispatch line; the `// [UPERF2-Q]` section at the
end), this report, the ledger section. No new crate, no Cargo change.
Struct additions: `Gpu` (cuda.rs) gained `desc[2]`, `st_desc[2]`,
`c_src`, `c_t`, `st_c`, `cout`; `MultiClaimKernel` gained
`row_factors` (its only constructor is `bg_multi_kernels`).

## 3. Differential evidence (the final binaries: default 6a4c700, GPU 6a4c700)

| gate | result |
|---|---|
| `uperf-q battery`, GPU build, ZK_THREADS 1 / 2 / 7 (+ 7 with `ZK_GPU_MIN_MACS=0` so the hooks engage) | 101/101 legs, one BATTERY DIGEST 0df38648…: (A) fill-pool == fill on 11 windows; (A1) 10204 digit values on every (e0, l0) class at the range ends: mask/shift == div/mod == `exact_digit_decompose`; (A1b) 5632 requant values incl. i64 extremes; (A2) the SHA-NI core == `sha2` on 123105 blocks (5 keys x 12 ranges incl. counters >= 2^32, lane tails 1..3); (B) the level-h session == the CPU body cell by cell over r 3/5/8/17/64 x blocks 7/64/1024 x stages default/5/333 on the i8 store, the boxed store and a boxed |w| = 2^20 store (i64 format, 64-term windows -> 243 flushes over 135 sessions); q46 declines and the hook == the CPU body; the hook GPU-live == bypassed; (E)-(H) the fold (i8 / boxed / boxed |w| 300) / psi0 pool == `psi_level0_factored_multi` == `compute_psi(Phi_0)` / ragged compute_psi / the 12-alpha two-limb combine == `ntt_combine_general`, at r 3/8/17/64 x stages default/7/500 (72 sessions); the hooks GPU-live == bypassed; (I) the chain GEMM GPU-live == `bf_matmul_i64_ref` on 6 shapes (ragged dims, planted +-127, a zero row, the |a| > 127 decline) |
| `uperf-q battery`, default build, 1 / 2 / 7T | 4/4 CPU legs (A1, A1b, A2, fill-pool), digest c2f4ed16… |
| `uperf-pc diff-battery` | default 1T / 7T green; GPU 1T (`ZK_GPU_MIN_MACS=0`) / 7T green (O1 4/4 + par 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2 proofs identical oracle vs fast + accept) |
| `uperf-c` / `uperf-e` / `uperf-f` / `uperf-m` / `uperf-i` / `uperf-d` | default: c 1T/7T green, e 59117121…, f 1T 77583bed…, m 1T and 7T-with-every-knob-off (`ZK_PSISIMD=0 ZK_NTTMAC=0 ZK_PSI0NTT=0 ZK_GBLOCKNTT=0 ZK_CRSPAR2=0 ZK_CRSNI=0`) 37d6a49b…, i green, d 1T 46471467…; GPU (`ZK_GPU=1`, MIN_MACS=0 where the lane's kernels are behind hooks): c green, e 59117121…, f 1T/2T 77583bed…, m 37d6a49b…, i green, d 46471467… — every digest the ledger's |
| `uperf-k battery` (GPU, 1T / 7T) | 185 GEMM legs + transforms + 8 hook legs green (K's s_max path touched) |
| the other GPU lanes under `ZK_GPU=1` | uperf-o 20/20 b67af1aa…, uperf-n 30 legs 8c3f8ca1…, uperf-a f936ff79…, uperf-g 6d6a3f6b…, uperf-h b1e78285…, uperf-j 45dba7c7… (the shared `Gpu` struct only gained fields) |
| freeze-check (default build, wsl export) | 98 `ok` rows + the BF/BK rows + "freeze-check passed"; the FULL output IDENTICAL (`diff`) to the pre-change capture (`scratchpad/q_freeze_baseline.txt`, 151edc9 binary) — the CRS bytes on the SHA-NI core are the freeze |
| `agg-matmul battery` / `bh-verifier battery` / `self-test` (default build) | passed 120.0 s / 13.2 s / 247.7 s |
| the REAL rigs (GPU build, 8T, flock) | 3x16 93a98700… / 0ae9cdae… accept; 12x128 4a3af8c3… / 742d88e1… accept; 12x512 2f8a92f8… / 4c259008… accept — at EVERY landing step and with the final binary; the CPU-only 12x512 (default build) identical too |

## 4. Measurements

### 4.1 The 12x512 REAL rig, 8T + GPU (`uperf-pc full-profile 12 512`, wsl export, flock, `/usr/bin/time`) — before = the ledger's quiet 34.1 s attribution (151edc9), after = the final binary [WSL-BOX 8T, load ~2.4, lane P active: NOISY-SHARED-ish]

| phase | before | after | what moved it |
|---|---:|---:|---|
| **wall (commit / prove / verify)** | **34.1 (5.0 / 24.9 / 2.6)** | **25.0 (2.5 / 19.3 / 1.8)** | |
| peak RSS | 6.70 GB | 6.70 GB | unchanged |
| bg.prove-group | 12.30 | 7.02 | |
| — bg.level-h / ep.level-h-pairs | 4.61 / 4.59 | 1.83 / 1.81 | the session (q.lh-stream 1.64 = 174 stages; fill 0.36, drain 0.07) |
| — ep.psi0-factored | 2.65 (m.psi0-ntt 1.74, m.phi-setup 0.85) | 1.58 (m.phi-setup 0.26; the pool sessions inside q.cb-*) | combine (pool) + row-factor memo |
| — bg.fold | 1.89 (m.fold-ntt 1.14) | 0.84 (m.fold-ntt 0.60, q.fold-split 0.19) | combine (small, i64) + wmax bound + digits |
| — bg.kernel-rows | 1.77 | 1.79 (q.rows-t 1.15) | untouched (Section 5) |
| — bg.matvec-chunks / ep.matvec | 1.50 / 1.57 | 0.79 / 0.84 | K's s_max scan replaced by the bound |
| — bg.kernel-phi | 0.39 | 0.16 | row-factor memo |
| bg.commit-phase | 5.02 | 2.55 | |
| — d.precommit-u0 | 3.46 | 1.63 | CRS + matvec |
| — d.chain-derive | 1.33 | 1.10 | device GEMM + requant (carries the ~0.5 s device init now) |
| — d.digit-witness | 1.13 | 0.53 | digits by mask/shift |
| ep.crs-expand | 2.76 (m.crs-blocks 1.92, walk 0.07) | 1.28 (0.51, 0.06) | SHA-NI core + unzeroed reused scratch |
| ep.transport | 1.95 (m.tr-s 1.17, t5 0.37, asm 0.23) | 1.36 (0.72, 0.25, 0.22) | combine (two limb rows) |
| bg.verify-group | 2.43 | 1.61 | its psi0 x2 + transport x2 through the sessions |
| ep.compute-psi | 0.24 | 0.23 | mostly below the minimum work |
| the four blocks of the brief | 22.1 | 12.3 | target ~13 [ASSUMED] met |
| untouched: descents (bk.descent-gkr + trees) / claim layer | 10.8 / 1.69 | 10.5 / 1.62 | lanes P / O |

Same-binary A/B knobs for the orchestrator (one binary): `ZK_GPU_LH=0`
(K's per-block level-h), `ZK_GPU_CB=0` (the CPU combine bodies),
`ZK_GPU_MM=0` (the CPU chain GEMM), `ZK_CRSNI=0` (the sha2 CRS),
`ZK_UPERF_ORACLE=1` (everything). Landing-step rig rows (12x512 8T+GPU,
each with identical digests): session 31.5 -> +combine 30.8 -> +chain
GEMM/bounds 28.5 -> +CRS 27.8 -> +digits/requant 25.1-26.0 -> +memo
26.0 (load 3.5) -> final 25.0.

### 4.2 The other rigs (final binary; identical digests)

| rig | before (ledger) | after | notes |
|---|---:|---:|---|
| 3x16 8T+GPU | 4.3 s | 3.6 s (0.4 / 2.2 / 0.5), RSS 1.59 GB (was 1.37) | +0.2 GB: pinned staging + the CRS scratch |
| 12x128 8T+GPU | 15.6 s | 12.2 s (1.5 / 8.7 / 1.1), RSS 3.90 GB (was 3.5) | the act A0 stream (346 MB) is <= 512 MB and stays resident |
| 12x512 8T CPU-only (default build) | 86.1 s (8.9 / 72.9 / 2.6), 11.1 GB | 81.2 s (7.2 / 69.7 / 2.6), 11.0 GB [load 3-5, NOISY-SHARED] | the CPU-side items only: crs 2.7 -> 1.3, fold 2.0 -> 1.4, psi0 2.8 -> 2.4, digit-witness ~1.1 -> 0.5, commit 8.9 -> 7.2; level-h stays the CPU GEMM (21.0 s) |

### 4.3 Kernel / session benches [WSL-BOX 8T NOISY-SHARED]

- `uperf-q lh-bench 4096 4096 64` (655K digit rings, r 64, chunk 10240,
  5.37 G D-domain MACs): CPU body 1.353 s; K's per-block GEMM path
  0.294 s (10 device calls); the session 0.100 s (10 stages, 1 flush,
  h2d 157 MB; host fill 0.028 s, host wait 0.069 s) — 2.96x over K's
  path, 13.6x over the CPU body, byte-identical.
- The rig's sessions (`ZK_GPU_VERBOSE=1`, 12x512): level-h weight r 64
  chunk 55296 = 54 stages, fill 93 ms, enqueue 6 ms, wait 392 ms, h2d
  708 MB; act r 64 chunk 122727 = 120 stages, fill 269 ms, wait 888 ms,
  h2d 1666 MB (9.4-9.9 ms per stage: the device). Combine sessions:
  fold act K 64 chunk 122727 flat i8 = 60 stages, fill 58 ms, wait
  160 ms, h2d 1 GB; psi0 act pool = 60 stages, fill 187 ms, wait 81 ms
  (host-fill-bound: the PHI MACs of ~0.5M value rings with many terms);
  transport S act K 12 n_out 2 = 60 stages, fill 89 ms, wait 39 ms
  (pack-bound: 754 MB of u32 operands).
- `uperf-m crs-bench 20000` (11 x 20000 polys, 225 MB): v2 blocks 1T
  64.9 -> 36.9 ns/block, 8T 10.2 -> 6.4 ns/block; v2 total 8T 0.152 ->
  0.117 s (the remaining 0.067 s is the poly walk's allocations).
- `uperf-d gemm-bench 512` under the GPU: the chain GEMM 2.4 ms kernel
  + 1.4 pack + 3.2 d2h+widen per 512x768x2048 (the first call pays the
  device init 0.47 s); the digit witness 31.7 -> 28.8 ns per value on
  that mostly sign-binary shape (the act classes e0 = 2 gain more).

## 5. What is left / honest state

1. LANDED: everything in Section 2; the 12x512 8T+GPU pass 34.1 ->
   25.0 s (RSS unchanged), CPU-only 86.1 -> 81.2 s, digests identical
   everywhere, batteries green in both builds at 1/2/7T, freeze rows
   identical, self-test / agg-matmul / bh green.
2. NOT built — the rows pass's T rings on the device (`q.rows-t` 1.15 s
   of bg.kernel-rows 1.79): T[ki][d1][cb] = sum_row s[ki][row][d1] x
   V[row][cb] is a u32 GEMM (M = 16 n_k, N = nb x 128, K = rows) with
   the value ring V recomposed from the i8 digits on the device
   (`k_recompose_v`: sum_l radix_l x w_l in i64, then mod q — the same
   integer `mod_q_i128` reduces) and lane M's fold reduction in the
   accumulator (bursts of 4 products < 2^64 folded by 2^32 == c32 into
   a u64 plane, finalized by two 2^31 folds + one subtract — the
   canonical residue of the exact sum, the AVX2 body's own argument);
   the per-tensor round trip is too small (~5-8 ms of overhead x 214
   tensors), so the design is ONE batch per group: the whole flat store
   uploaded once (1 GB in 64 MB pinned chunks), all tensors' s factors,
   one launch pair per tensor, one d2h — hook shape: at the top of
   `kernel_pass_factored_gen`'s rows mode build the batch when
   `w0.as_i8()` is Some and `psi_mac_simd_params(q)` is Some, then the
   per-tensor loop takes its T rings from it (else the CPU path). ~0.7 s
   [ASSUMED]; not reached.
3. K's GEMM kernel: the level-h session is DEVICE-bound at ~10 ms per
   64x64x1024 stage (fwd ~3 + gemm ~7 ms; the kernel at ~48% of its
   instruction ceiling per lane O) — 1.8 s of the pass; a 1.5x on the
   kernel would be ~0.5 s. Not touched (O's finding stands: the u32-limb
   form is slower on this part; the levers are tile loads / syncs /
   occupancy).
4. The psi0 pool sessions are host-fill-bound (the PHI MAC — 16 x
   n_kernels terms per value ring, AVX2 already); the transport's
   deeper-level sessions and compute_psi are pack-bound / below the
   minimum work; the CRS poly walk (~0.7 s of 2.2M 1 KB allocations +
   faults) needs a flat CRS storage to move (every consumer takes
   `&[Poly]`).
5. Memory: the CRS scratch keeps <= 512 MB resident (`CRS_SCRATCH_KEEP`)
   — the 12x512 peak is unchanged (its level-0 A streams are freed), the
   12x128 / 3x16 peaks grew by ~0.4 / 0.2 GB (scratch + pinned staging
   of the sessions). Flip the constant to 256 MB to trade ~0.2-0.3 s of
   page faults for it. Device memory: every session releases nothing
   between calls by design (K's discipline: scratch grows on demand and
   stays; ~0.5 GB device + ~0.2 GB pinned at the rig's shapes); no
   declines were observed under `ZK_GPU_VERBOSE=1`.
6. Not a Mac build for the device parts (CUDA-only, as lanes K/L/N/O);
   the SHA-NI core is x86_64-only (runtime-detected; the sha2 path
   elsewhere), the digit / requant / bound / memo changes are portable
   Rust and land on the Mac path unchanged.
