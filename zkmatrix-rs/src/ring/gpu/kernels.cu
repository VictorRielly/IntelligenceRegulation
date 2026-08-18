// [UPERF2-K] CUDA kernels of the GPU rung — compiled at first use by NVRTC
// (cudarc), never by nvcc. Rules of this file:
//   * Goldilocks arithmetic ports aux_ntt_core.rs EXACTLY: reduce128 /
//     add_p / sub_p (branchless forms), the psi-twisted negacyclic length-128
//     NTT (Cooley-Tukey DIT forward with psi_brv, Gentleman-Sande DIF
//     inverse with ipsi_brv and the 1/n scale), the same twiddle order and
//     the same bit-reversed output order. Every value is the CANONICAL
//     representative in [0, p) of the same field expression, so the values
//     are identical to the CPU's by the uniqueness of canonical
//     representatives (the battery `uperf-k battery` is the witness).
//   * The GEMM accumulates the exact split halves (low / high u64 halves
//     of every 64 x 64 product, each as a 128-bit integer sum: a u64 lane +
//     a carry count) — the same integers `dot_split_halves` sums on the
//     CPU — and the flush computes gl_reduce128(acc_lo + EPS * acc_hi) on
//     the same u128, then the same inverse transform, center, mod q, add.
//   * No __int128 (NVRTC has none by default): 64 x 64 -> 128 products via
//     __umul64hi; 128-bit sums by explicit carries.
// Types: u64 = unsigned long long throughout (matches Rust u64).

typedef unsigned long long u64;
typedef unsigned int u32;
typedef long long i64;
typedef signed char i8;

#define P_GL 0xFFFFFFFF00000001ULL
#define EPS_GL 0xFFFFFFFFULL
#define D_RING 128

// ---------------------------------------------------------------------------
// Goldilocks primitives (== aux_ntt_core: reduce128 / add_p / sub_p / mul_p).

__device__ __forceinline__ u64 gl_reduce(u64 lo, u64 hi) {
    // x = lo + 2^64 hi, hi = 2^32 hi_hi + hi_lo, 2^64 == EPS, 2^96 == -1 (mod p):
    // x == lo + EPS*hi_lo - hi_hi. Same branch structure as reduce128 (the
    // borrow / carry adjustments cannot double-wrap; see aux_ntt_core.rs).
    u64 hi_lo = hi & EPS_GL;
    u64 hi_hi = hi >> 32;
    u64 t = lo - hi_hi;
    if (lo < hi_hi) t -= EPS_GL;
    u64 t1 = (hi_lo << 32) - hi_lo; // hi_lo * (2^32 - 1), exact
    u64 r = t + t1;
    if (r < t) r += EPS_GL;
    if (r >= P_GL) r -= P_GL;
    return r;
}

__device__ __forceinline__ u64 gl_mul(u64 a, u64 b) {
    return gl_reduce(a * b, __umul64hi(a, b));
}

// a, b < p.
__device__ __forceinline__ u64 gl_add(u64 a, u64 b) {
    u64 s = a + b;
    if (s < a) s += EPS_GL;      // carried: a+b-2^64+EPS = a+b-p (cannot re-carry)
    else if (s >= P_GL) s -= P_GL;
    return s;
}

// a, b < p.
__device__ __forceinline__ u64 gl_sub(u64 a, u64 b) {
    u64 d = a - b;
    if (a < b) d -= EPS_GL;      // borrowed: a-b+2^64-EPS = a-b+p (no re-borrow)
    return d;
}

// ---------------------------------------------------------------------------
// The mulmod probe (the orchestrator's feasibility kernel, kept for
// `uperf-k probe`).

extern "C" __global__ void k_mulmod_probe(const u64* a, const u64* b, u64* out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    out[i] = gl_mul(a[i], b[i]);
}

// ---------------------------------------------------------------------------
// Forward transform of a batch of rings: R_FWD rings per block, in shared
// memory, R_FWD * 64 butterflies per stage spread over the block's threads
// (== ntt_fwd_fast: stage m = 1, 2, .., 64 with len = 64, .., 1, twiddle
// psi_brv[m + i] for group i, standard-order input, bit-reversed output).
//
// Input: `src` holds n_slots rings, ring-major (slot * 128 + coeff), in one
// of the lift formats:
//   fmt 0: u32 mod-q value  -> lift_to_p(balanced_mod_q(x, q))
//   fmt 1: u64 mod-q value  -> the same
//   fmt 2: i8 small value   -> lift_to_p(x)
//   fmt 3: i64 small value  -> lift_to_p(x)
//   fmt 4: u64 raw Z_p value (battery), no lift
// Output: t-major planes, dst[t * n_slots + slot] = fwd(ring slot)[t] — with
// slot = ub * n_rings + idx this is exactly the [t][ub][idx] layout the GEMM
// tiles read contiguously.

#ifndef R_FWD
#define R_FWD 32
#endif
#define RS_FWD 129   // padded row stride (bank-conflict relief on the transposed store)
#ifndef T_FWD
#define T_FWD 256    // threads per transform block
#endif

__device__ __forceinline__ u64 lift_modq(u64 x, u64 q) {
    // balanced_mod_q: v = x > q/2 ? x - q : x ; lift_to_p: v >= 0 ? v : p - |v|
    return (x > (q >> 1)) ? (P_GL - (q - x)) : x;
}

__device__ __forceinline__ u64 lift_small(i64 v) {
    return (v >= 0) ? (u64)v : (P_GL - (u64)(-v));
}

extern "C" __global__ void k_ntt_fwd(const void* src, int fmt, u64 q, int n_slots, u64* dst, const u64* psi_brv) {
    __shared__ u64 sh[R_FWD * RS_FWD];
    __shared__ u64 tw[D_RING];
    const int slot0 = blockIdx.x * R_FWD;
    for (int i = threadIdx.x; i < D_RING; i += blockDim.x) tw[i] = psi_brv[i];
    // Load + lift (coalesced over the ring-major source).
    for (int e = threadIdx.x; e < R_FWD * D_RING; e += blockDim.x) {
        int r = e / D_RING, c = e % D_RING;
        int slot = slot0 + r;
        u64 v = 0;
        if (slot < n_slots) {
            size_t g = (size_t)slot * D_RING + c;
            if (fmt == 0) v = lift_modq((u64)((const u32*)src)[g], q);
            else if (fmt == 1) v = lift_modq(((const u64*)src)[g], q);
            else if (fmt == 2) v = lift_small((i64)((const i8*)src)[g]);
            else if (fmt == 3) v = lift_small(((const i64*)src)[g]);
            else v = ((const u64*)src)[g];
        }
        sh[r * RS_FWD + c] = v;
    }
    __syncthreads();
    // Seven DIT stages: stage s has m = 2^s groups of len = 2^(6-s)
    // butterflies (shifts, not divisions — the loop variable is a power of 2).
#pragma unroll 1
    for (int st = 0; st < 7; ++st) {
        const int m = 1 << st;
        const int lg = 6 - st;
        const int len = 1 << lg;
        for (int k = threadIdx.x; k < R_FWD * (D_RING >> 1); k += blockDim.x) {
            int r = k >> 6, b = k & 63;
            int i = b >> lg, jj = b & (len - 1);
            int j = r * RS_FWD + ((i * len) << 1) + jj;
            u64 s = tw[m + i];
            u64 u = sh[j];
            u64 v = gl_mul(sh[j + len], s);
            sh[j] = gl_add(u, v);
            sh[j + len] = gl_sub(u, v);
        }
        __syncthreads();
    }
    // Transposed store: for each t, the block's R_FWD slots are contiguous.
    for (int e = threadIdx.x; e < R_FWD * D_RING; e += blockDim.x) {
        int t = e / R_FWD, r = e - t * R_FWD;
        int slot = slot0 + r;
        if (slot < n_slots) dst[(size_t)t * n_slots + slot] = sh[r * RS_FWD + t];
    }
}

// ---------------------------------------------------------------------------
// The D = 128 batched GEMMs with split-halves accumulation.
//   A_t[t][k][ia] (na per k, n_k positions), B_t[t][k][ib]
//   acc[((s*D + t)*na + ia)*nb + ib][4] += (lo, carry_lo, hi, carry_hi) over
//   the split s's k range — 128-bit exact sums of the low halves and of the
//   high halves of the products (== dot_split_halves' u128 pair).
// Block: 16 x 16 threads, each owning the 4 x 4 cells
//   ia = ia0 + ty + 16*i, ib = ib0 + tx + 16*j (strided: conflict-free
//   shared reads), tile 64 x 64 per (t, split); K in KB = 16 steps.

#define TM_G 64
#define TN_G 64
#define KB_G 32

// 128-bit accumulate of a 64-bit addend: acc (u64 lane) + carry count (u32),
// one carry-chained pair (add.cc / addc) instead of a compare + add.
#define ACC128(lo, c, x) asm volatile("{\n\tadd.cc.u64 %0, %0, %2;\n\taddc.u32 %1, %1, 0;\n\t}" : "+l"(lo), "+r"(c) : "l"(x))

// The body is a macro over RI = rows per thread (RI = 4 -> a 64-row tile,
// RI = 1 -> a 16-row tile for the skinny matvec shapes na <= 16); the
// column side is always 64 (4 per thread).
#define GEMM_BODY(RI)                                                                                                   \
    __shared__ u64 As[KB_G][16 * RI];                                                                                   \
    __shared__ u64 Bs[KB_G][TN_G];                                                                                      \
    const int TM = 16 * RI;                                                                                             \
    const int t = blockIdx.z / ks;                                                                                      \
    const int s = blockIdx.z - t * ks;                                                                                  \
    const int k0 = s * k_per_split;                                                                                     \
    int k1 = k0 + k_per_split;                                                                                          \
    if (k1 > n_k) k1 = n_k;                                                                                             \
    const int ia0 = blockIdx.y * TM;                                                                                    \
    const int ib0 = blockIdx.x * TN_G;                                                                                  \
    const int tx = threadIdx.x, ty = threadIdx.y;                                                                       \
    const int tid = ty * 16 + tx;                                                                                       \
    const u64* Ap = A + (size_t)t * n_k * na;                                                                           \
    const u64* Bp = B + (size_t)t * n_k * nb;                                                                           \
    u64 lo[RI][4], hi[RI][4];                                                                                           \
    u32 clo[RI][4], chi[RI][4];                                                                                         \
    _Pragma("unroll") for (int i = 0; i < RI; ++i)                                                                      \
        _Pragma("unroll") for (int j = 0; j < 4; ++j) { lo[i][j] = 0; hi[i][j] = 0; clo[i][j] = 0; chi[i][j] = 0; }   \
    for (int kb = k0; kb < k1; kb += KB_G) {                                                                            \
        for (int e = tid; e < KB_G * TM; e += 256) {                                                                    \
            int kk = e / TM, i = e - kk * TM;                                                                           \
            int k = kb + kk, ia = ia0 + i;                                                                              \
            As[kk][i] = (k < k1 && ia < na) ? Ap[(size_t)k * na + ia] : 0ULL;                                           \
        }                                                                                                               \
        for (int e = tid; e < KB_G * TN_G; e += 256) {                                                                  \
            int kk = e / TN_G, j = e - kk * TN_G;                                                                       \
            int k = kb + kk, ib = ib0 + j;                                                                              \
            Bs[kk][j] = (k < k1 && ib < nb) ? Bp[(size_t)k * nb + ib] : 0ULL;                                           \
        }                                                                                                               \
        __syncthreads();                                                                                                \
        _Pragma("unroll 4") for (int kk = 0; kk < KB_G; ++kk) {                                                         \
            u64 av[RI], bv[4];                                                                                          \
            _Pragma("unroll") for (int i = 0; i < RI; ++i) av[i] = As[kk][ty + 16 * i];                                 \
            _Pragma("unroll") for (int j = 0; j < 4; ++j) bv[j] = Bs[kk][tx + 16 * j];                                  \
            _Pragma("unroll") for (int i = 0; i < RI; ++i) {                                                            \
                _Pragma("unroll") for (int j = 0; j < 4; ++j) {                                                         \
                    u64 pl = av[i] * bv[j];                                                                             \
                    u64 ph = __umul64hi(av[i], bv[j]);                                                                  \
                    ACC128(lo[i][j], clo[i][j], pl);                                                                    \
                    ACC128(hi[i][j], chi[i][j], ph);                                                                    \
                }                                                                                                       \
            }                                                                                                           \
        }                                                                                                               \
        __syncthreads();                                                                                                \
    }                                                                                                                   \
    _Pragma("unroll") for (int i = 0; i < RI; ++i) {                                                                    \
        int ia = ia0 + ty + 16 * i;                                                                                     \
        if (ia >= na) continue;                                                                                         \
        _Pragma("unroll") for (int j = 0; j < 4; ++j) {                                                                 \
            int ib = ib0 + tx + 16 * j;                                                                                 \
            if (ib >= nb) continue;                                                                                     \
            size_t c = ((((size_t)s * D_RING + t) * na + ia) * nb + ib) * 4;                                            \
            u64 l0 = acc[c], l1 = acc[c + 1], h0 = acc[c + 2], h1 = acc[c + 3];                                         \
            u64 nl = l0 + lo[i][j]; l1 += (nl < l0) + (u64)clo[i][j];                                                   \
            u64 nh = h0 + hi[i][j]; h1 += (nh < h0) + (u64)chi[i][j];                                                   \
            acc[c] = nl; acc[c + 1] = l1; acc[c + 2] = nh; acc[c + 3] = h1;                                             \
        }                                                                                                               \
    }

// 64 x 64 tile (RI = 4).
extern "C" __global__ void k_gemm_split(const u64* __restrict__ A, const u64* __restrict__ B, u64* acc, int na, int nb, int n_k, int ks, int k_per_split) {
    GEMM_BODY(4)
}

// 16 x 64 tile (RI = 1): the skinny shapes (na <= 16, e.g. the KAPPA_AGG = 11
// matvec rows) — no idle rows.
extern "C" __global__ void k_gemm_split_m16(const u64* __restrict__ A, const u64* __restrict__ B, u64* acc, int na, int nb, int n_k, int ks, int k_per_split) {
    GEMM_BODY(1)
}

// ---------------------------------------------------------------------------
// Window flush, step 1: per (cell, t): sum the splits' 128-bit pairs, then
// v = gl_reduce128(acc_lo + EPS * acc_hi) — the SAME u128 the CPU reduces —
// into V[cell * 128 + t] (ring-major, bit-reversed order = the inverse
// transform's input order).

extern "C" __global__ void k_flush_reduce(const u64* acc, int ks, int na, int nb, u64* V) {
    int cell = blockIdx.x;           // ia * nb + ib
    int t = threadIdx.x;             // 0..127
    if (cell >= na * nb || t >= D_RING) return;
    u64 lo0 = 0, lo1 = 0, hi0 = 0, hi1 = 0;
    for (int s = 0; s < ks; ++s) {
        size_t c = (((size_t)s * D_RING + t) * (size_t)na * nb + cell) * 4;
        u64 a0 = acc[c], a1 = acc[c + 1], b0 = acc[c + 2], b1 = acc[c + 3];
        u64 nl = lo0 + a0; lo1 += (nl < lo0) + a1; lo0 = nl;
        u64 nh = hi0 + b0; hi1 += (nh < hi0) + b1; hi0 = nh;
    }
    // x = (lo1:lo0) + EPS * (hi1:hi0), as a u128 (cannot overflow: the
    // window bound keeps both sums < 2^95, EPS*hi < 2^127).
    // EPS * hi0 = (hi0 << 32) - hi0 as a 128-bit value:
    u64 e_lo = hi0 * EPS_GL;
    u64 e_hi = __umul64hi(hi0, EPS_GL);
    // + EPS * hi1 * 2^64:
    e_hi += hi1 * EPS_GL;
    u64 x_lo = lo0 + e_lo;
    u64 x_hi = lo1 + e_hi + (x_lo < lo0);
    V[(size_t)cell * D_RING + t] = gl_reduce(x_lo, x_hi);
}

// ---------------------------------------------------------------------------
// Inverse transform of a batch of rings in ring-major layout (== ntt_inv_fast:
// stages h = 64 .. 1 with len = 1 .. 64, twiddle ipsi_brv[h + i], then the 1/n
// scale), then per coefficient:
//   mode 0: write the raw Z_p value (battery);
//   mode 1: c = mod_q_centered(center_from_p(v), q); out = zq.add(out, c)
//           (the window's exact partial sum folded into the mod-q output).

extern "C" __global__ void k_ntt_inv(u64* V, int n_slots, const u64* ipsi_brv, u64 n_inv, int mode, u64 q, u64* out) {
    __shared__ u64 sh[R_FWD * RS_FWD];
    __shared__ u64 tw[D_RING];
    const int slot0 = blockIdx.x * R_FWD;
    for (int i = threadIdx.x; i < D_RING; i += blockDim.x) tw[i] = ipsi_brv[i];
    for (int e = threadIdx.x; e < R_FWD * D_RING; e += blockDim.x) {
        int r = e / D_RING, c = e - r * D_RING;
        int slot = slot0 + r;
        sh[r * RS_FWD + c] = (slot < n_slots) ? V[(size_t)slot * D_RING + c] : 0ULL;
    }
    __syncthreads();
    // Seven GS stages: stage st has len = 2^st, h = 64 >> st groups.
#pragma unroll 1
    for (int st = 0; st < 7; ++st) {
        const int lg = st;
        const int len = 1 << lg;
        const int h = (D_RING >> 1) >> st;
        for (int k = threadIdx.x; k < R_FWD * (D_RING >> 1); k += blockDim.x) {
            int r = k >> 6, b = k & 63;
            int i = b >> lg, jj = b & (len - 1);
            int j = r * RS_FWD + ((i * len) << 1) + jj;
            u64 s = tw[h + i];
            u64 u = sh[j];
            u64 v = sh[j + len];
            sh[j] = gl_add(u, v);
            sh[j + len] = gl_mul(gl_sub(u, v), s);
        }
        __syncthreads();
    }
    for (int e = threadIdx.x; e < R_FWD * D_RING; e += blockDim.x) {
        int r = e / D_RING, c = e - r * D_RING;
        int slot = slot0 + r;
        if (slot >= n_slots) continue;
        u64 v = gl_mul(sh[r * RS_FWD + c], n_inv);
        size_t g = (size_t)slot * D_RING + c;
        if (mode == 0) {
            out[g] = v;
        } else {
            // center_from_p: (-(p-1)/2, (p-1)/2]; mod_q_centered; zq.add.
            u64 mag; int neg;
            if (v > (P_GL >> 1)) { mag = P_GL - v; neg = 1; } else { mag = v; neg = 0; }
            u64 r0 = mag % q;
            u64 c0 = (neg && r0 != 0) ? (q - r0) : r0;
            u64 o = out[g] + c0;
            if (o >= q) o -= q;
            out[g] = o;
        }
    }
}
