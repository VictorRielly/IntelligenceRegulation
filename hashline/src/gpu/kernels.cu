// [UPERF3-XX] hashline's CUDA kernels — compiled at first use by NVRTC
// (cudarc), never by nvcc. Rules of this file:
//   * Goldilocks arithmetic yields the CANONICAL representative in [0, p)
//     of the same field expression the CPU computes (field.rs), so every
//     value is identical to the CPU's by uniqueness of representatives.
//     The reduction is the CPU's reduce128 (x = lo + 2^64 hi, hi = 2^32
//     hi_hi + hi_lo, 2^64 == EPS, 2^96 == -1 mod p: x == lo + EPS*hi_lo
//     - hi_hi) with the same borrow / carry adjustments.
//   * No __int128 (NVRTC has none by default): 64 x 64 -> 128 products
//     via __umul64hi.
// Types: u64 = unsigned long long throughout (matches Rust u64).

typedef unsigned long long u64;
typedef unsigned int u32;
typedef long long i64;
typedef int i32;
typedef unsigned char u8;

#define P_GL 0xFFFFFFFF00000001ULL
#define EPS_GL 0xFFFFFFFFULL
#define NONRES 7ULL

// ---------------------------------------------------------------------------
// Goldilocks primitives (== field.rs: reduce128 / add / sub / mul).

__device__ __forceinline__ u64 gl_reduce(u64 lo, u64 hi) {
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
    if (s < a) s += EPS_GL;
    else if (s >= P_GL) s -= P_GL;
    return s;
}

// a, b < p.
__device__ __forceinline__ u64 gl_sub(u64 a, u64 b) {
    u64 d = a - b;
    if (a < b) d -= EPS_GL;
    return d;
}

// F_{p^2} = F_p[u] / (u^2 - 7): (c0, c1).
struct f2 { u64 c0, c1; };

__device__ __forceinline__ f2 f2_add(f2 a, f2 b) { f2 r; r.c0 = gl_add(a.c0, b.c0); r.c1 = gl_add(a.c1, b.c1); return r; }
__device__ __forceinline__ f2 f2_sub(f2 a, f2 b) { f2 r; r.c0 = gl_sub(a.c0, b.c0); r.c1 = gl_sub(a.c1, b.c1); return r; }
__device__ __forceinline__ f2 f2_mul(f2 a, f2 b) {
    u64 ac = gl_mul(a.c0, b.c0);
    u64 bd = gl_mul(a.c1, b.c1);
    u64 ad = gl_mul(a.c0, b.c1);
    u64 bc = gl_mul(a.c1, b.c0);
    f2 r;
    r.c0 = gl_add(ac, gl_mul(bd, NONRES));
    r.c1 = gl_add(ad, bc);
    return r;
}
__device__ __forceinline__ f2 f2_mul_base(f2 a, u64 b) { f2 r; r.c0 = gl_mul(a.c0, b); r.c1 = gl_mul(a.c1, b); return r; }
__device__ __forceinline__ f2 f2_zero() { f2 r; r.c0 = 0; r.c1 = 0; return r; }

// ---------------------------------------------------------------------------
// The probe: mul / add / sub of canonical pairs, compared on the host
// against field.rs.

extern "C" __global__ void k_probe(const u64* a, const u64* b, u64* om, u64* oa, u64* os, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    u64 x = a[i], y = b[i];
    om[i] = gl_mul(x, y);
    oa[i] = gl_add(x, y);
    os[i] = gl_sub(x, y);
}

// ---------------------------------------------------------------------------
// [rung 1] The batched row NTT (== ntt.rs `transform`: bit-reversal, then
// radix-2 DIT stages len = 2, 4, .., n with twiddle tw[k * (max_n / len)]
// from the size-2^max_log table; the inverse is the same stages on the
// inverse table followed by the 1/n scale). Two passes per transform:
//   p1: the first min(12, log_n) stages on 4096-element blocks in shared
//       memory, the bit-reversed gather done on the load (positions >=
//       n_src read as zero — the RS zero padding without materializing
//       it);
//   p2: the remaining log_n - 12 stages on a [2^(log_n-12)] x [J] tile
//       (elements x = t * 4096 + j; for len > 4096 the butterfly partner
//       of x differs only in t, so the tile is closed under those stages).
// The scale (1/n for the inverse, 1 otherwise) is applied on the store
// of the last pass. Values are the canonical representatives of the
// same evaluations the CPU computes.

#define NTT_BLK 4096
#define NTT_LOG_BLK 12

extern "C" __global__ void k_ntt_p1(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw,
                                    int log_n, int n_src, int max_log, u64 scale) {
    __shared__ u64 sh[NTT_BLK];
    const int n = 1 << log_n;
    const int lb = log_n < NTT_LOG_BLK ? log_n : NTT_LOG_BLK;
    const int bs = 1 << lb;
    const int blocks_per_row = n >> lb;
    const int row = blockIdx.x / blocks_per_row;
    const int blk = blockIdx.x - row * blocks_per_row;
    const u64* s = src + (size_t)row * (size_t)n_src;
    u64* d = dst + (size_t)row * (size_t)n + (size_t)blk * (size_t)bs;
    for (int q = threadIdx.x; q < bs; q += blockDim.x) {
        int x = blk * bs + q;
        int r = (int)(__brev((u32)x) >> (32 - log_n));
        sh[q] = (r < n_src) ? s[r] : 0ULL;
    }
    __syncthreads();
    for (int st = 1; st <= lb; st++) {
        const int half = 1 << (st - 1);
        const int stride = 1 << (max_log - st);
        for (int b = threadIdx.x; b < (bs >> 1); b += blockDim.x) {
            int k = b & (half - 1);
            int i = ((b >> (st - 1)) << st) + k;
            u64 w = tw[k * stride];
            u64 u = sh[i];
            u64 v = gl_mul(sh[i + half], w);
            sh[i] = gl_add(u, v);
            sh[i + half] = gl_sub(u, v);
        }
        __syncthreads();
    }
    const bool last = (log_n <= NTT_LOG_BLK);
    for (int q = threadIdx.x; q < bs; q += blockDim.x) {
        u64 v = sh[q];
        if (last && scale != 1ULL) v = gl_mul(v, scale);
        d[q] = v;
    }
}

extern "C" __global__ void k_ntt_p2(u64* __restrict__ a, const u64* __restrict__ tw, int log_n, int max_log, u64 scale) {
    __shared__ u64 sh[NTT_BLK];
    const int n = 1 << log_n;
    const int lt = log_n - NTT_LOG_BLK;
    const int nt = 1 << lt;
    const int J = NTT_BLK >> lt;
    const int tiles_per_row = nt;
    const int row = blockIdx.x / tiles_per_row;
    const int tile = blockIdx.x - row * tiles_per_row;
    const int j0 = tile * J;
    u64* r = a + (size_t)row * (size_t)n;
    for (int q = threadIdx.x; q < NTT_BLK; q += blockDim.x) {
        int t = q / J, jj = q - t * J;
        sh[q] = r[t * NTT_BLK + j0 + jj];
    }
    __syncthreads();
    for (int st = NTT_LOG_BLK + 1; st <= log_n; st++) {
        const int hs = st - 1 - NTT_LOG_BLK;
        const int halft = 1 << hs;
        const int stride = 1 << (max_log - st);
        for (int b = threadIdx.x; b < (NTT_BLK >> 1); b += blockDim.x) {
            int jj = b % J;
            int tb = b / J;
            int tl = tb & (halft - 1);
            int t = ((tb >> hs) << (hs + 1)) + tl;
            int k = tl * NTT_BLK + j0 + jj;
            u64 w = tw[(size_t)k * (size_t)stride];
            int i = t * J + jj;
            int ip = i + halft * J;
            u64 u = sh[i];
            u64 v = gl_mul(sh[ip], w);
            sh[i] = gl_add(u, v);
            sh[ip] = gl_sub(u, v);
        }
        __syncthreads();
    }
    for (int q = threadIdx.x; q < NTT_BLK; q += blockDim.x) {
        int t = q / J, jj = q - t * J;
        u64 v = sh[q];
        if (scale != 1ULL) v = gl_mul(v, scale);
        r[t * NTT_BLK + j0 + jj] = v;
    }
}

// [rung 1] Column gather for the PCS opening: out[c * rows + i] = enc[i * nn + idx[c]].
extern "C" __global__ void k_gather_cols(const u64* __restrict__ enc, u64* __restrict__ out, const int* __restrict__ idx,
                                         int rows, int nn, int q) {
    int g = blockIdx.x * blockDim.x + threadIdx.x;
    if (g >= rows * q) return;
    int c = g / rows;
    int i = g - c * rows;
    out[g] = enc[(size_t)i * (size_t)nn + (size_t)idx[c]];
}
