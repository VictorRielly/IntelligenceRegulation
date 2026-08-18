# U-PERF2 lane I — SIMD Goldilocks NTT (the length-128 transform every NTT-domain kernel pays)

Branch `uperf2-i` (worktree /home/victor/wt-uperf2-i), opened at d38e9ce
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane I" + "Agent I status".
Box: the WSL box (Intel Core Ultra 9 185H — 6 P + 8 E + 2 LP-E cores as
22 threads, 15 GB; AVX2 + BMI2 + ADX, NO AVX-512 / IFMA per
`/proc/cpuinfo`; the local m125 re-export is here, so the 3x16 and 12x64
real-data rigs run). Lane H (descent tree memory) built and ran its
rigs concurrently the whole session (load 1-8): every number below is
`[WSL-BOX ... NOISY-SHARED]`; the scalar/SIMD pairs are taken
back-to-back in ONE binary (`ZK_NTT_SIMD=0` vs default), so the ratios
are trustworthy while the absolute microseconds move by 10-25% between
repeats (three `uperf-i bench` repeats are listed, not one).

## 0. One paragraph

The length-128 negacyclic Goldilocks NTT (`aux_ntt_core.rs`) now has an
AVX2 body — 4 x u64 lanes, the SAME Cooley-Tukey DIT forward / Gentleman-
Sande DIF inverse with the same twiddle order and output order — whose
values are IDENTICAL to lane C's branchless scalar `ntt_fwd_fast` /
`ntt_inv_fast` by construction: every vector op returns the canonical
representative in [0, p) of the same field expression, so equality
follows from the uniqueness of canonical representatives, not from luck
(and `uperf-i battery` asserts it on 5,192 rings including 1,096 planted
extremes: unit vectors x extreme values at every one of the 128
positions, all-constant rings, EPS multiples, mixed extremes; forward,
inverse, three round-trip compositions, and the `_best` dispatch). Two
Goldilocks-specific levers made it 2.2-3.0x rather than the 1.6x a naive
port gets: (a) the twiddles of the five outer stages (64th roots of
unity and below) and 1/n are all signed powers of two (2 has order 192
in Z_p*), so those butterflies multiply by shifts + the same reduction
with the sign folded into a store/load-offset swap; only the two
innermost stages pay the four-`vpmuludq` u64 x u64 product; (b) the
`vpmuludq` is emitted through a one-instruction `asm!` because LLVM
re-lowers the intrinsic as a 64-bit multiply idiom for loop-invariant
twiddles (6 wasted ops per butterfly, seen in the disassembly). Measured
[WSL-BOX 1T NOISY-SHARED, best of 3 x 3 repeats]: forward 1.00-1.04 ->
0.41-0.46 us (2.2-2.5x), inverse 1.20-1.26 -> 0.42-0.44 us (2.7-3.0x).
The seven `ntt_fwd_fast` / `ntt_inv_fast` call lines of eval_proof.rs
now go through `ntt_fwd_best` / `ntt_inv_best` (AVX2 when detected and
`ZK_NTT_SIMD` != 0, else the scalar body): matvec 1.44x, transport
1.51x, combine 1.61x, psi 1.27x, fold e=5 1.57x at 1T; level-h 1.15x
(MAC-bound at r = 64); the REAL 3x16 / 12x64 rigs reproduce their
digests exactly (Section 4.4). A NEON mirror (2 x u64, `vmull_u32`,
`vshlq_u64` signed-count shifts) is written behind
`cfg(target_arch = "aarch64")` for the Mac — [UNTESTED-NEON], compiled
out here, every intrinsic signature checked against the toolchain's
stdarch source. Gates at HEAD: `uperf-i battery`, `uperf-pc diff-battery`
1T/7T (E2E), `uperf-c` 1T/7T, `uperf-f` 1T/2T, freeze-check 98 rows
identical to the pre-change capture, `self-test` (290 s), the rig
digests.

## 1. What landed (files)

- `zkmatrix-rs/src/aux_ntt_core.rs` (additive):
  - `NttTables` gains `psi_l2` / `ipsi_l2` (the m = 32 stage twiddles in
    the 4-lane layout `(s_2k, s_2k, s_2k+1, s_2k+1)`), `psi_pw2` /
    `ipsi_pw2` / `n_inv_pw2` (the `Pw2 { k, neg }` signed power-of-two
    forms of psi_brv[1..32] / ipsi_brv[1..32] / 1/n, solved by
    `pow2_form` and value-checked at build) — same values, no new
    constants; accessors `psi_brv(i)`, `ipsi_brv(i)`, `n_inv()`,
    `psi_pw2(i)`, `ipsi_pw2(i)`, `n_inv_pw2()`.
  - `mod gl_avx2` (x86_64): `add` / `sub` / `mul` / `mul_pow2` on
    `__m256i`, the butterflies `dit` / `gs` / `dit_pow2` / `gs_pow2`,
    const-generic `fwd_stage<M>` / `inv_stage<H>` for the outer stages,
    `#[target_feature(enable = "avx2")] pub unsafe fn ntt_fwd / ntt_inv`.
  - `mod gl_neon` (aarch64): the same functions on `uint64x2_t`
    [UNTESTED-NEON].
  - Dispatch: `simd_ntt_available()` (`is_x86_feature_detected!("avx2")`
    / true on aarch64), `simd_ntt_enabled()` (that AND `ZK_NTT_SIMD` !=
    "0", read once), `simd_ntt_label()`, `ntt_fwd_simd` / `ntt_inv_simd`
    (the SIMD body directly, for the battery/bench), `ntt_fwd_best` /
    `ntt_inv_best` (what eval_proof.rs calls).
- `zkmatrix-rs/src/ring/eval_proof.rs`: the 7 call lines (+ 3 `use`
  lines) `ntt_fwd_fast` / `ntt_inv_fast` -> `_best` in
  `ntt_gemm_modq_small_gen` (forward + flush inverse), `fwd_small`,
  `fwd_modq`, `fwd_modq_limbs` (x2), `flush_split`. Nothing else there.
- `zkmatrix-rs/src/bin/ring_matmul.rs`: `// [UPERF2-I]` section,
  `uperf-i battery | bench [n]`, registered next to the other `uperf-*`
  arms in `main`.
- This report + "Agent I status" in PROGRESS_UPERF2.md.

Not touched: transcript / RNG / oracle routing (`ZK_UPERF_ORACLE` still
selects the pre-Phase-0 arithmetic; the SIMD switch is orthogonal and
lives under `ZK_NTT_SIMD`), any other kernel.

## 2. Method (why the values are identical, and where the speed comes from)

### 2.1 Canonical vector arithmetic (the identity argument)

Values are u64 in [0, p), p = 2^64 - 2^32 + 1, EPS = 2^32 - 1 = 2^64 mod p.
AVX2 has no unsigned 64-bit compare and no 64 x 64 multiply, so:

- unsigned `a > b` = `_mm256_cmpgt_epi64(a ^ 2^63, b ^ 2^63)`;
- `add(a, b)` for a, b < p: `a + b >= p` iff `a > (p-1) - b` (no wrap
  since b < p), and `((p-1) - b) ^ 2^63 == ((p-1) ^ 2^63) - b` mod 2^64
  because `x ^ 2^63 == x + 2^63` mod 2^64 — so one xor, one sub, one
  cmpgt, then `a + b - (mask & p)` mod 2^64, which is the exact value in
  [0, p) in both cases: 6 ops;
- `sub(a, b)`: `a - b + (borrow_mask & p)` mod 2^64: 6 ops;
- `mul(a, w)`: four `vpmuludq` partial products carried in 32-bit
  columns (every intermediate < 2^64: partial products <= (2^32-1)^2,
  column carries < 2^32) give (hi, lo) of the 128-bit product; then
  `gl_reduce128`'s identity `x == lo + EPS*hi_lo - hi_hi (mod p)` (2^64
  == EPS, 2^96 == -1) with each term canonical: `c = lo mod p` (one
  conditional subtract, lo < 2^64 < 2p), `e = EPS*hi_lo` (< p; a fifth
  `vpmuludq` by EPS), `hi_hi < 2^32 < p`; `r = sub(add(c, e), hi_hi)`.
  15 + 17 = 32 ops per four lanes;
- `mul_pow2(x, +-2^k)`, 0 <= k < 96 (the outer-stage twiddles, see
  2.2): x 2^k = L + 2^64 H with L = (x << k) mod 2^64 and
  H = x 2^k >> 64 < 2^k; k <= 32: H_hi = 0, `r = add(L mod p, EPS*H)`
  (14 ops); 32 < k < 64: `r = sub(add(L mod p, EPS*H_lo), x >> (96-k))`
  (21 ops); 64 <= k < 96: L = 0 and with y = x 2^(k-64) < 2^95,
  x 2^k = y 2^64 == EPS*y_lo - y_hi with y_lo the low 32 bits of
  x << (k-64) and y_hi = x >> (96-k): `r = sub(EPS*y_lo, y_hi)` (9 ops).
  Every shifted-down term is < 2^63 < p, so the add/sub contracts hold.
  The sign: a DIT butterfly with -2^k is the +2^k pair stored swapped;
  a GS butterfly with -2^k is the +2^k butterfly on swapped operands
  ((v + u, (v - u) 2^k)); the 1/n = -2^89 scale folds the sign into its
  final subtraction (`sub(y_hi, e)`). All per group, no per-butterfly
  branch.

Since every op returns the canonical value of the exact same field
expression the scalar `gl_add` / `gl_sub` / `gl_mul` return, and the
butterflies are applied in the same (stage, group, j) structure with the
same twiddles (the tables are the scalar tables; the `psi_l2` copies and
`Pw2` forms are value-checked against them at build), the transform's
outputs are the same canonical field elements. `uperf-i battery` is the
witness, not the argument.

### 2.2 The two Goldilocks levers

1. Powers of two. 2^96 = 2^64 2^32 == EPS 2^32 = 2^64 - 2^32 == -1
   (mod p), so 2 has order 192 in Z_p* and the subgroup <2> contains
   every root of unity of order dividing 64. The forward stages m = 1, 2,
   4, 8, 16 use psi^{64 x odd}, psi^{32 x odd}, ..., psi^{4 x odd} — 2nd
   .. 64th roots — and the inverse stages h = 16 .. 1 their inverses;
   1/n = 2^-7 = 2^185 = -2^89. All are +-2^k with k < 96 (the actual
   forms: `python3` search over 2^k mod p; classes lo/mid/hi split about
   24 / 33 / 23 of the 80 outer-stage vector butterflies). Only the m =
   32 (psi^{2 x odd}: 128th roots) and m = 64 (psi^{odd}: 256th roots)
   stages need the general u64 x u64 (128th roots are not in <2>: 128
   does not divide 192). A separate-twist cyclic NTT would not help (one
   more general stage's worth of twist multiplies).
2. The opaque `vpmuludq`. Through `_mm256_mul_epu32` LLVM sees a
   generic zext/mul pattern; for the loop-invariant broadcast twiddle it
   hoists the zero-extension out of the loop, loses the "high halves are
   zero" fact at the block boundary and re-lowers the multiply as the
   3-`vpmuludq` 64-bit idiom (two of them by a known-zero half, plus
   shifts/adds), and strength-reduces `hi_lo * EPS` into
   shift-and-subtract — 8 wasted instructions of ~60 per butterfly in
   the first build's disassembly. A one-instruction `asm!("vpmuludq")`
   (pure, nomem) keeps exactly 4 + 1 multiplies. (Because the crate is
   built for the x86-64 baseline — cargo does not read
   `zkmatrix-rs/.cargo/config.toml`'s `target-cpu=native` when invoked
   from the repo root, which every lane does — the helper carries
   `#[target_feature(enable = "avx2")]` and inlines into the AVX2 bodies.
   Note for the orchestrator: this also means every lane's "native"
   build has in fact been a baseline x86-64 build.)

### 2.3 Layout of the two inner stages

Stages with len >= 4 are whole-vector butterflies (a[j..j+4] with
a[j+len..j+len+4]). The forward m = 32 (len 2) and m = 64 (len 1) stages
run chained on each 8-element block a[8k..8k+8] = vectors (x, y):
`permute2x128` gives u = (a0, a1, a4, a5), v = (a2, a3, a6, a7) — the
len-2 pairs, twiddle vector (s_2k, s_2k, s_2k+1, s_2k+1) from `psi_l2`;
then `unpacklo/hi` on the results give (a0, a2, a4, a6), (a1, a3, a5,
a7) — the len-1 pairs, twiddles psi_brv[64+4k..] contiguous; two
`unpack` + two `permute2x128` restore the block. The inverse chains len
1 then len 2 the same way in reverse. 8 shuffles per 8 vector
butterflies. NEON (2 lanes) needs only one `vzip1q/vzip2q` split for the
len-1 stage.

### 2.4 Safety

The only `unsafe` is the intrinsics: `_mm256_loadu/storeu_si256` at
offsets 0..128 step 4 (and 8k, 8k+4 for k < 16) inside a `[u64; 128]`
— in bounds by the type; twiddle loads at fixed offsets inside the
fixed-size tables; the AVX2 entry points are `#[target_feature(enable
= "avx2")]` and are reached only after `is_x86_feature_detected!("avx2")`
(`ntt_fwd_simd` asserts it again — a cached load). No aliasing (one
`&mut [u64; 128]`), no threads (per-thread transforms), no allocation.

## 3. Differential evidence (all at HEAD of uperf2-i)

| gate | result |
|---|---|
| `uperf-i battery` (ZK_THREADS 1) | 5,192 rings (1,096 planted/extreme + 4,096 random): fwd simd == fast, inv simd == fast, round trips simd/simd, simd/fast, fast/simd, `_best` == fast; also fast == the original `ntt_fwd`/`ntt_inv` on a sample. Passed. |
| `uperf-pc diff-battery` 1T / 7T | passed (O1/O2/O3/O5/E2E: 2/2 proofs identical oracle vs fast + accept) |
| `uperf-c diff-battery` 1T / 7T | passed |
| `uperf-f diff-battery` 1T / 2T | 40/40 legs |
| freeze-check | 98 `ok` rows identical to the pre-change capture from the d38e9ce build (scratchpad/i_freeze_baseline.txt == the orchestrator's merge-G capture), then the expected BF panic |
| `self-test` | passed in 290 s |
| REAL rigs | Section 4.4: statement / EVAL-PROOF digests identical to the ledger's (3x16 93a98700… / 0ae9cdae…; 12x64 80763ea5… / 63f4a3a4…), SIMD on and `ZK_NTT_SIMD=0` |

## 4. Measurements

### 4.1 The transform itself — `uperf-i bench 200000` [WSL-BOX 1T NOISY-SHARED], best of 3 passes per row, three repeats

| repeat | fwd scalar | fwd AVX2 | ratio | inv scalar | inv AVX2 | ratio |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 1.035 us | 0.410 us | 2.53x | 1.264 us | 0.429 us | 2.95x |
| 2 | 1.003 us | 0.410 us | 2.45x | 1.197 us | 0.444 us | 2.70x |
| 3 | 0.996 us | 0.458 us | 2.17x | 1.222 us | 0.419 us | 2.91x |

Steps on the way (same bench, 1e5 rings): naive canonical AVX2 port
1.64x / 1.61x; + opaque `vpmuludq` 1.91x / 2.04x; + power-of-two outer
stages 2.30x / 2.50x; + const-generic stages and offset-swapped signs
2.2-3.0x (the last step is inside the noise; it removed the
per-butterfly sign branch and the dynamic trip counts).

(Lane C's report measured the scalar `ntt_fwd_fast` at 1.50 us on a
noisier moment of this box; the same binary path measures 1.00-1.04 us
here — the SIMD ratio is what transfers.)

### 4.2 Kernel benches, one binary, `ZK_NTT_SIMD=0` vs default [WSL-BOX NOISY-SHARED]

| kernel (bench) | 1T scalar | 1T AVX2 | ratio | 8T scalar | 8T AVX2 | ratio |
|---|---:|---:|---:|---:|---:|---:|
| level-h `kernel-bench 64 8192` (us/product) | 0.176 (5.92 s) | 0.154 (5.17 s) | 1.15x | 0.039 (1.32 s) | 0.029 (0.96 s) | 1.37x |
| matvec `kernel-bench 64 8192` | 0.380 (2.19 s) | 0.265 (1.53 s) | 1.44x | 0.115 (0.66 s) | 0.084 (0.48 s) | 1.37x |
| kpass rows `kpass-bench 512 2048` (us/digit ring) | 2.98 | 2.80 | 1.06x | 0.91 | 0.76 | 1.20x |
| kpass phi | 2.76 | 2.80 | 1.0x | 1.27 | 0.98 | 1.30x |
| fold e=2 `uperf-c bench 16 2048` (us/(c x w)) | 1.944 | 1.672 | 1.16x | 0.672 | 0.475 | 1.41x |
| fold e=5 | 1.981 | 1.258 | 1.57x | 0.581 | 0.287 | 2.02x |
| psi (us/(c x phi) term) | 2.237 | 1.767 | 1.27x | 0.389 | 0.222 | 1.75x |
| combine(12) (us/general product) | 3.125 | 1.937 | 1.61x | 0.452 | 0.280 | 1.61x |
| transport (us/next-witness ring) | 17.91 | 11.89 | 1.51x | 3.71 | 3.17 | 1.17x |

Reading: the kernels that transform each operand once (fold, psi,
combine, transport, matvec at r = 11) move by 1.3-1.6x; level-h at r =
64 is MAC-bound (transforms amortize as 2/r) and moves 1.15x; the
kernel passes barely transform at this shape (their cost is the K-field
weight rows). The 8T rows are noisier (the other lane's threads).

### 4.3 What it means for the composed prove

The transform share lane C estimated (30-40% of level-h / matvec /
fold / psi / transport at 8T) is roughly halved: those phases should
move 1.15-1.6x each, i.e. a 3x16 prove of ~6.7 s at 8T should lose ~1
s and a 12x64 prove of ~33 s ~4-5 s — the rig rows below are the
measurement, not this estimate.

### 4.4 REAL rigs (`uperf-pc full-profile`, the local m125 re-export, flock-serialized) [WSL-BOX NOISY-SHARED, load 3-5]

One binary; `ZK_NTT_SIMD=0` = the scalar transform, default = AVX2. The
3x16 1T pair was run twice in opposite orders (SIMD-then-scalar, then
scalar-then-SIMD) because the box was loaded; both orders agree.

| rig | transform | wall | commit / prove / verify | level-h | matvec (ep) | transport | fold | psi0-fact. | kernel rows | peak RSS | digests |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 3x16, 1T (run 1) | AVX2 | **25.6 s** | 2.7 / 19.4 / 3.4 | 7.45 | 2.15 | 1.79 | 0.87 | 4.28 | 2.44 | 0.96 GB | 93a98700… / 0ae9cdae… |
| 3x16, 1T (run 1) | scalar | 34.5 s | 3.9 / 26.3 / 4.2 | 9.96 | 3.87 | 3.74 | 1.96 | 4.56 | 3.11 | 0.96 GB | identical |
| 3x16, 1T (run 2) | scalar | 32.9 s | 3.6 / 25.2 / 4.0 | 10.31 | 3.51 | 2.86 | 1.69 | 4.43 | 2.80 | 0.96 GB | identical |
| 3x16, 1T (run 2) | AVX2 | **27.1 s** | 2.9 / 20.9 / 3.2 | 7.95 | 2.38 | 1.82 | 0.94 | 4.28 | 2.56 | 0.96 GB | identical |
| 3x16, 8T | AVX2 | **9.2 s** | 1.3 / 6.6 / 1.2 | 2.07 | 1.06 | 0.57 | 0.44 | 1.48 | 0.59 | 1.04 GB | identical |
| 3x16, 8T | scalar | 9.8 s | 1.4 / 7.1 / 1.2 | 2.26 | 1.19 | 0.74 | 0.57 | 1.46 | 0.59 | 1.03 GB | identical |
| 12x64, 8T | AVX2 | **41.0 s** | 5.3 / 31.8 / 3.4 | 8.94 | 3.94 | 1.19 | 1.91 | 5.08 | 2.25 | 4.06 GB | 80763ea5… / 63f4a3a4… |
| 12x64, 8T | scalar | 43.1 s | 5.6 / 33.6 / 3.5 | 9.96 | 4.36 | 1.68 | 2.34 | 4.86 | 2.27 | 4.04 GB | identical |

(level-h = `ep.level-h-pairs`; the phase columns are process-global
prof totals in seconds; "identical" = statement digest 93a98700… /
EVAL-PROOF DIGEST 0ae9cdae… for 3x16 and 80763ea5… / 63f4a3a4… for
12x64, `accept = true`, 985,142 B counted at 3x16 — the ledger's
values on every row.)

Reading: at 1T the composed 3x16 pass drops from 32.9-34.5 s to
25.6-27.1 s (~1.25x end to end; prove 25.2-26.3 -> 19.4-20.9 s), with
level-h -25%, matvec -35-45%, transport -35-50%, fold -45-55%,
kernel-rows -10%; the phases that do not transform (psi0-factored,
descents, commit, claim layer) are unchanged. At 8T the transform share
of the composed pass is small (the 8T pass is dominated by the descents,
commit and psi0 phases, and level-h/matvec are MAC/memory-bound there):
3x16 9.8 -> 9.2 s, 12x64 43.1 -> 41.0 s (~1.05x; the ledger's quiet
lane-G number for 12x64 8T was 41.3 s — this box was loaded for both of
these rows). The Mac's 1T full-statement prove is where the transform
share is largest (lane C's 30-40% of level-h/matvec/fold/psi/transport);
its NEON body is untested (Section 5).

## 5. What is left / honest state

- NEON is UNTESTED: it mirrors the AVX2 body function by function
  (same classes, same terms, same offset swaps), every intrinsic
  signature was checked against the toolchain's stdarch source
  (`vsliq_n_u64(a, b)` keeps a's low bits and inserts b << 32;
  `vshlq_u64` shifts by a signed per-lane count, negative = right,
  |count| >= 64 = 0; `vzip1q/2q_u64`; `vcgtq_u64` gives the unsigned
  mask directly, so no sign flips), but no aarch64 target/std is
  installed here (`rustup target list --installed` = x86_64 only) so it
  was not even type-checked. FIRST THING ON THE MAC: `cargo build
  --release` then `ring_matmul uperf-i battery` and `uperf-i bench`; if
  the battery fails, `ZK_NTT_SIMD=0` restores the scalar body everywhere
  (one env var, no rebuild) — the dispatch defaults to NEON on aarch64.
- Not tried (each a few % at most on this box, in estimated order):
  keeping values in the sign-flipped representation between ops (saves
  the xors before the compares, ~8%); the mid-class (32 < k < 64)
  power-of-two multiply via 2^k = -(2^(k+32)) 2^64 (21 -> 17 ops on ~a
  third of the outer-stage butterflies); interleaving two rings per
  transform (the API is per ring; the callers' closures own the ring
  loop). AVX-512 IFMA (52-bit multiply-add) would change the picture on
  a box that has it — this one does not.
- The 12x128 rig was not run by this lane (lane H's memory number; the
  transform change is shape-independent and the 3x16 / 12x64 digests
  are the evidence).
- The `.cargo/config.toml` `target-cpu=native` finding (Section 2.2)
  is worth a line in the TASK_BOARD: either move it to the repo root or
  accept that runtime detection (`is_x86_feature_detected!`) is what
  actually gates the SIMD paths — as this lane assumes.
