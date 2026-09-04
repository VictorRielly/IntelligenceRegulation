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
// [rung 2] The twiddle table is STAGE-MAJOR: stage s (len = 2^s, half =
// 2^(s-1)) owns the contiguous entries tw[half - 1 + k], k < half, which
// are the CPU table's tw_cpu[k * (max_n / len)] copied on the host (same
// values; the reads are now coalesced and max_log drops out).

#define NTT_BLK 4096
#define NTT_LOG_BLK 12

extern "C" __global__ void k_ntt_p1(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw,
                                    int log_n, int n_src, u64 scale) {
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
        const u64* tws = tw + (half - 1);
        for (int b = threadIdx.x; b < (bs >> 1); b += blockDim.x) {
            int k = b & (half - 1);
            int i = ((b >> (st - 1)) << st) + k;
            u64 w = tws[k];
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

// [UPERF3-AO] The three strided-tile kernels (`k_dif_pa`, `k_ntt_p2`,
// `k_ntt_p2_gather`) index with `q / J`, `b % J` and `b / J`, where
// J = NTT_BLK >> lt is a POWER OF TWO that is not a compile-time constant
// — so nvrtc has to emit a full 32-bit integer division for every one of
// them, several times the instruction count of the butterfly being
// indexed. `lj = NTT_LOG_BLK - lt` makes each a shift or a mask. The
// arithmetic on FIELD elements is untouched: same operands, same
// twiddles, same order, bit-for-bit the same stores. `FAST = false` keeps
// the divide form so the two can be A/B'd in one process
// (`HL_GPU_NTT_FAST=0`).
template <bool FAST>
__device__ __forceinline__ void ntt_p2_body(u64* sh, u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale) {
    const int n = 1 << log_n;
    const int lt = log_n - NTT_LOG_BLK;
    const int nt = 1 << lt;
    const int lj = NTT_LOG_BLK - lt;
    const int J = NTT_BLK >> lt;
    const int tiles_per_row = nt;
    const int row = FAST ? (int)(blockIdx.x >> lt) : (int)(blockIdx.x / tiles_per_row);
    const int tile = blockIdx.x - row * tiles_per_row;
    const int j0 = tile * J;
    u64* r = a + (size_t)row * (size_t)n;
    for (int q = threadIdx.x; q < NTT_BLK; q += blockDim.x) {
        int t = FAST ? (q >> lj) : (q / J), jj = q - t * J;
        sh[q] = r[t * NTT_BLK + j0 + jj];
    }
    __syncthreads();
    for (int st = NTT_LOG_BLK + 1; st <= log_n; st++) {
        const int hs = st - 1 - NTT_LOG_BLK;
        const int halft = 1 << hs;
        const u64* tws = tw + ((size_t)1 << (st - 1)) - 1;
        for (int b = threadIdx.x; b < (NTT_BLK >> 1); b += blockDim.x) {
            int jj = FAST ? (b & (J - 1)) : (b % J);
            int tb = FAST ? (b >> lj) : (b / J);
            int tl = tb & (halft - 1);
            int t = ((tb >> hs) << (hs + 1)) + tl;
            int k = tl * NTT_BLK + j0 + jj;
            u64 w = tws[k];
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
        int t = FAST ? (q >> lj) : (q / J), jj = q - t * J;
        u64 v = sh[q];
        if (scale != 1ULL) v = gl_mul(v, scale);
        r[t * NTT_BLK + j0 + jj] = v;
    }
}

extern "C" __global__ void k_ntt_p2(u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale) {
    __shared__ u64 sh[NTT_BLK];
    ntt_p2_body<false>(sh, a, tw, log_n, scale);
}

extern "C" __global__ void k_ntt_p2_f(u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale) {
    __shared__ u64 sh[NTT_BLK];
    ntt_p2_body<true>(sh, a, tw, log_n, scale);
}

// [UPERF3-AJ] Widen a packed narrow witness plane back to canonical
// Goldilocks u64. The host packs each element as a two's-complement signed
// integer of w bytes (w = 1, 2 or 4) — which is exact for every value the
// int8/int16/int32 witness planes produce, since `Fp::from_i64` maps
// x >= 0 to x and x < 0 to P + x. This kernel is that map, so the device
// buffer is bit-for-bit the buffer a 64-bit upload would have written.
extern "C" __global__ void k_widen(const void* __restrict__ src, u64* __restrict__ dst, long long n, int w) {
    long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    long long x;
    if (w == 1) x = (long long)((const signed char*)src)[i];
    else if (w == 2) x = (long long)((const short*)src)[i];
    else x = (long long)((const int*)src)[i];
    dst[i] = (x >= 0) ? (u64)x : (P_GL - (u64)(-x));
}

// [UPERF3-AJ] The opening's LAST NTT stage group, fused with the column
// gather. `k_ntt_p2` writes the whole encoded row back to global memory and
// `k_gather_cols_off` then reads it again to keep 256 of the nn columns;
// this kernel does the identical arithmetic (same shared-memory tile, same
// twiddles, same order) and stores ONLY the sampled columns, so the
// encoded matrix is never written and never re-read. `sel[j]` is the
// output slot of column j, or -1. The VALUES are k_ntt_p2's values.
template <bool FAST>
__device__ __forceinline__ void ntt_p2_gather_body(u64* sh, const u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale,
                                                   const int* __restrict__ sel, u64* __restrict__ out, int row0, int rows_total) {
    const int n = 1 << log_n;
    const int lt = log_n - NTT_LOG_BLK;
    const int nt = 1 << lt;
    const int lj = NTT_LOG_BLK - lt;
    const int J = NTT_BLK >> lt;
    const int tiles_per_row = nt;
    const int row = FAST ? (int)(blockIdx.x >> lt) : (int)(blockIdx.x / tiles_per_row);
    const int tile = blockIdx.x - row * tiles_per_row;
    const int j0 = tile * J;
    const u64* r = a + (size_t)row * (size_t)n;
    for (int q = threadIdx.x; q < NTT_BLK; q += blockDim.x) {
        int t = FAST ? (q >> lj) : (q / J), jj = q - t * J;
        sh[q] = r[t * NTT_BLK + j0 + jj];
    }
    __syncthreads();
    for (int st = NTT_LOG_BLK + 1; st <= log_n; st++) {
        const int hs = st - 1 - NTT_LOG_BLK;
        const int halft = 1 << hs;
        const u64* tws = tw + ((size_t)1 << (st - 1)) - 1;
        for (int b = threadIdx.x; b < (NTT_BLK >> 1); b += blockDim.x) {
            int jj = FAST ? (b & (J - 1)) : (b % J);
            int tb = FAST ? (b >> lj) : (b / J);
            int tl = tb & (halft - 1);
            int t = ((tb >> hs) << (hs + 1)) + tl;
            int k = tl * NTT_BLK + j0 + jj;
            u64 w = tws[k];
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
        int t = FAST ? (q >> lj) : (q / J), jj = q - t * J;
        int col = t * NTT_BLK + j0 + jj;
        int c = sel[col];
        if (c >= 0) {
            u64 v = sh[q];
            if (scale != 1ULL) v = gl_mul(v, scale);
            out[(size_t)c * (size_t)rows_total + (size_t)(row0 + row)] = v;
        }
    }
}

extern "C" __global__ void k_ntt_p2_gather(const u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale,
                                           const int* __restrict__ sel, u64* __restrict__ out, int row0, int rows_total) {
    __shared__ u64 sh[NTT_BLK];
    ntt_p2_gather_body<false>(sh, a, tw, log_n, scale, sel, out, row0, rows_total);
}

extern "C" __global__ void k_ntt_p2_gather_f(const u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale,
                                             const int* __restrict__ sel, u64* __restrict__ out, int row0, int rows_total) {
    __shared__ u64 sh[NTT_BLK];
    ntt_p2_gather_body<true>(sh, a, tw, log_n, scale, sel, out, row0, rows_total);
}

// [UPERF3-AO] lever L9, rung 3: THE OUTPUT-PRUNED LAST STAGE GROUP.
//
// The last group of forward stages (NTT_LOG_BLK+1 .. log_n) is, for each
// of the NTT_BLK positions qq inside a contiguous block, an INDEPENDENT
// nt = 2^lt-point transform over the block index t; the encoded column it
// produces is col = t * NTT_BLK + qq. The opening keeps only 256 of the
// 2^log_n columns, so only the ~250 distinct residues qq = col mod
// NTT_BLK can produce anything at all: of NTT_BLK = 4096 transforms per
// block, ~250 are wanted and ~3,850 are computed, stored and thrown away.
//
// This kernel is `k_ntt_p2_gather` with the tile's column axis replaced by
// a COMPACT LIST of those residues. Everything else is the same: for a
// given qq the operand pairs, the twiddles tws[tl * NTT_BLK + qq], the
// stage order and the store are identical to the dense kernel's, so the
// bytes are identical — this removes work, it does not change any
// arithmetic. `qlist` is padded to a multiple of P2SP_NC by repeating its
// last entry; the padding lanes compute and are simply never stored
// (jc >= nc_real), so no address is written twice.
//
// Grid: x over groups of P2SP_NC residues, y over the chunk's rows.
#define P2SP_LNC 6
#define P2SP_NC (1 << P2SP_LNC)
extern "C" __global__ void k_ntt_p2_gather_sp(const u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale,
                                              const int* __restrict__ sel, u64* __restrict__ out, int row0, int rows_total,
                                              const int* __restrict__ qlist, int nq) {
    __shared__ u64 sh[P2SP_NC * 32];
    const int n = 1 << log_n;
    const int lt = log_n - NTT_LOG_BLK;
    const int nt = 1 << lt;
    const int row = blockIdx.y;
    const int base = blockIdx.x * P2SP_NC;
    const int nc_real = nq - base;
    const int span = nt * P2SP_NC;
    const u64* r = a + (size_t)row * (size_t)n;
    for (int q = threadIdx.x; q < span; q += blockDim.x) {
        int t = q >> P2SP_LNC, jc = q & (P2SP_NC - 1);
        sh[q] = r[(size_t)t * NTT_BLK + qlist[base + jc]];
    }
    __syncthreads();
    for (int st = NTT_LOG_BLK + 1; st <= log_n; st++) {
        const int hs = st - 1 - NTT_LOG_BLK;
        const int halft = 1 << hs;
        const u64* tws = tw + ((size_t)1 << (st - 1)) - 1;
        for (int b = threadIdx.x; b < (span >> 1); b += blockDim.x) {
            int jc = b & (P2SP_NC - 1);
            int tb = b >> P2SP_LNC;
            int tl = tb & (halft - 1);
            int t = ((tb >> hs) << (hs + 1)) + tl;
            u64 w = tws[(size_t)tl * NTT_BLK + qlist[base + jc]];
            int i = t * P2SP_NC + jc;
            int ip = i + halft * P2SP_NC;
            u64 u = sh[i];
            u64 v = gl_mul(sh[ip], w);
            sh[i] = gl_add(u, v);
            sh[ip] = gl_sub(u, v);
        }
        __syncthreads();
    }
    for (int q = threadIdx.x; q < span; q += blockDim.x) {
        int t = q >> P2SP_LNC, jc = q & (P2SP_NC - 1);
        if (jc >= nc_real) continue;
        int col = t * NTT_BLK + qlist[base + jc];
        int c = sel[col];
        if (c >= 0) {
            u64 v = sh[q];
            if (scale != 1ULL) v = gl_mul(v, scale);
            out[(size_t)c * (size_t)rows_total + (size_t)(row0 + row)] = v;
        }
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

// ---------------------------------------------------------------------------
// [rung 2] blake3 on the device (the reference algorithm: 7-round
// compression, 1024-byte chunks with CHUNK_START / CHUNK_END, the lazy
// CV-stack merge to popcount(chunk index) before each push, the root
// roll-up with ROOT on the last compression). One thread hashes one
// column of the encoded matrix (column j = enc[i * nn + j], i < rows: the
// little-endian bytes of the u64 values, exactly what pcs::hash_columns
// feeds blake3::hash). Column lengths are multiples of 8 bytes.

#define B3_CHUNK_START 1u
#define B3_CHUNK_END 2u
#define B3_PARENT 4u
#define B3_ROOT 8u
#define B3_MAX_DEPTH 24

__device__ __forceinline__ u32 rotr32(u32 x, int n) { return (x >> n) | (x << (32 - n)); }

__device__ __forceinline__ void b3_g(u32* s, int a, int b, int c, int d, u32 mx, u32 my) {
    s[a] = s[a] + s[b] + mx;
    s[d] = rotr32(s[d] ^ s[a], 16);
    s[c] = s[c] + s[d];
    s[b] = rotr32(s[b] ^ s[c], 12);
    s[a] = s[a] + s[b] + my;
    s[d] = rotr32(s[d] ^ s[a], 8);
    s[c] = s[c] + s[d];
    s[b] = rotr32(s[b] ^ s[c], 7);
}

__device__ __forceinline__ void b3_iv(u32* cv) {
    cv[0] = 0x6A09E667u; cv[1] = 0xBB67AE85u; cv[2] = 0x3C6EF372u; cv[3] = 0xA54FF53Au;
    cv[4] = 0x510E527Fu; cv[5] = 0x9B05688Cu; cv[6] = 0x1F83D9ABu; cv[7] = 0x5BE0CD19u;
}

// state <- compress(cv, block, counter, block_len, flags); out[0..8] = the chaining value / root words.
__device__ void b3_compress(const u32* cv, const u32* block, u64 counter, u32 block_len, u32 flags, u32* out) {
    u32 s[16];
    u32 m[16];
    #pragma unroll
    for (int i = 0; i < 8; i++) s[i] = cv[i];
    s[8] = 0x6A09E667u; s[9] = 0xBB67AE85u; s[10] = 0x3C6EF372u; s[11] = 0xA54FF53Au;
    s[12] = (u32)counter; s[13] = (u32)(counter >> 32); s[14] = block_len; s[15] = flags;
    #pragma unroll
    for (int i = 0; i < 16; i++) m[i] = block[i];
    #pragma unroll
    for (int r = 0; r < 7; r++) {
        b3_g(s, 0, 4, 8, 12, m[0], m[1]);
        b3_g(s, 1, 5, 9, 13, m[2], m[3]);
        b3_g(s, 2, 6, 10, 14, m[4], m[5]);
        b3_g(s, 3, 7, 11, 15, m[6], m[7]);
        b3_g(s, 0, 5, 10, 15, m[8], m[9]);
        b3_g(s, 1, 6, 11, 12, m[10], m[11]);
        b3_g(s, 2, 7, 8, 13, m[12], m[13]);
        b3_g(s, 3, 4, 9, 14, m[14], m[15]);
        if (r < 6) {
            u32 t[16];
            t[0] = m[2]; t[1] = m[6]; t[2] = m[3]; t[3] = m[10]; t[4] = m[7]; t[5] = m[0]; t[6] = m[4]; t[7] = m[13];
            t[8] = m[1]; t[9] = m[11]; t[10] = m[12]; t[11] = m[5]; t[12] = m[9]; t[13] = m[14]; t[14] = m[15]; t[15] = m[8];
            #pragma unroll
            for (int i = 0; i < 16; i++) m[i] = t[i];
        }
    }
    #pragma unroll
    for (int i = 0; i < 8; i++) out[i] = s[i] ^ s[i + 8];
}

// Hash the column j (rows u64 values at stride nn) into out[0..8].
__device__ void b3_hash_column(const u64* __restrict__ enc, size_t nn, int rows, int j, u32* out) {
    const u32 len = (u32)rows * 8u;
    const u32 n_chunks = len == 0 ? 1u : (len + 1023u) / 1024u;
    u32 stack[B3_MAX_DEPTH][8];
    int stack_len = 0;
    u32 cv[8];
    u32 block[16];
    u32 tmp[8];
    for (u32 c = 0; c < n_chunks; c++) {
        const bool is_last = (c + 1 == n_chunks);
        const u32 chunk_len = is_last ? (len - c * 1024u) : 1024u;
        // lazy merge: the stack holds c leaves; reduce it to popcount(c) subtrees
        const int want = __popc(c);
        while (stack_len > want) {
            u32 pb[16];
            #pragma unroll
            for (int i = 0; i < 8; i++) { pb[i] = stack[stack_len - 2][i]; pb[8 + i] = stack[stack_len - 1][i]; }
            u32 iv[8];
            b3_iv(iv);
            b3_compress(iv, pb, 0ULL, 64u, B3_PARENT, tmp);
            #pragma unroll
            for (int i = 0; i < 8; i++) stack[stack_len - 2][i] = tmp[i];
            stack_len -= 1;
        }
        b3_iv(cv);
        const u32 n_blocks = chunk_len == 0 ? 1u : (chunk_len + 63u) / 64u;
        for (u32 b = 0; b < n_blocks; b++) {
            const bool last_block = (b + 1 == n_blocks);
            const u32 blen = last_block ? (chunk_len - b * 64u) : 64u;
            u32 flags = (b == 0 ? B3_CHUNK_START : 0u) | (last_block ? B3_CHUNK_END : 0u);
            if (is_last && stack_len == 0 && last_block) flags |= B3_ROOT;
            // words of this block: element e = c*128 + b*8 + w/2 (lo word for even w, hi for odd)
            #pragma unroll
            for (int w = 0; w < 16; w += 2) {
                int e = (int)(c * 128u + b * 8u) + (w >> 1);
                u64 v = (e < rows) ? enc[(size_t)e * nn + (size_t)j] : 0ULL;
                block[w] = (u32)v;
                block[w + 1] = (u32)(v >> 32);
            }
            b3_compress(cv, block, (u64)c, blen, flags, tmp);
            #pragma unroll
            for (int i = 0; i < 8; i++) cv[i] = tmp[i];
        }
        if (is_last) {
            if (stack_len == 0) {
                #pragma unroll
                for (int i = 0; i < 8; i++) out[i] = cv[i];
                return;
            }
            for (int s = stack_len - 1; s >= 0; s--) {
                u32 pb[16];
                #pragma unroll
                for (int i = 0; i < 8; i++) { pb[i] = stack[s][i]; pb[8 + i] = cv[i]; }
                u32 iv[8];
                b3_iv(iv);
                b3_compress(iv, pb, 0ULL, 64u, B3_PARENT | (s == 0 ? B3_ROOT : 0u), tmp);
                #pragma unroll
                for (int i = 0; i < 8; i++) cv[i] = tmp[i];
            }
            #pragma unroll
            for (int i = 0; i < 8; i++) out[i] = cv[i];
            return;
        }
        #pragma unroll
        for (int i = 0; i < 8; i++) stack[stack_len][i] = cv[i];
        stack_len += 1;
    }
}

// leaves[j * 8 + w] = the w-th output word of blake3(column j).
extern "C" __global__ void k_hash_cols(const u64* __restrict__ enc, u32* __restrict__ leaves, int rows, int nn) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= nn) return;
    u32 out[8];
    b3_hash_column(enc, (size_t)nn, rows, j, out);
    #pragma unroll
    for (int w = 0; w < 8; w++) leaves[(size_t)j * 8 + w] = out[w];
}

// ---------------------------------------------------------------------------
// [rung 3] The zero-check sumchecks on the device (== sumcheck.rs `prove`
// for layer.rs's zc20 / zc17 polynomials). Tables: k tables of stride L
// f2 each, table-major (tabs[t * L + i]); a round pairs i with i + half,
// evaluates the round polynomial at d = 0..=4 on cur = v0 + d * dif (the
// CPU's incremental form), and block-reduces; the fold writes v0 + r (v1
// - v0) in place. The polynomials mirror layer.rs's closures term for
// term; the sums are field sums (order-free).

#define SC_MAX_K 16
#define SC_DEG 4
#define SC_THREADS 256

__device__ __forceinline__ f2 ld_f2(const u64* p, size_t i) { f2 r; r.c0 = p[2 * i]; r.c1 = p[2 * i + 1]; return r; }
__device__ __forceinline__ void st_f2(u64* p, size_t i, f2 v) { p[2 * i] = v.c0; p[2 * i + 1] = v.c1; }
__device__ __forceinline__ f2 prm_f2(const u64* prm, int at) { f2 r; r.c0 = prm[at]; r.c1 = prm[at + 1]; return r; }

// h (a - l1)(a - l2) - (2a - l1 - l2)
__device__ __forceinline__ f2 helper_constraint(f2 h, f2 l1, f2 l2, f2 alpha) {
    f2 d1 = f2_sub(alpha, l1);
    f2 d2 = f2_sub(alpha, l2);
    return f2_sub(f2_mul(f2_mul(h, d1), d2), f2_add(d1, d2));
}

// prm: alpha 0, beta 2, g_silu 4, g_rg 6, g_ru 8, g_rh 10, g_int8 12, mu0..3 14..22, nu0..2 22..28, p_g 28, p_u 29, p_h 30
__device__ __forceinline__ f2 zc20_poly(const f2* v, const u64* prm) {
    f2 alpha = prm_f2(prm, 0), beta = prm_f2(prm, 2), g_silu = prm_f2(prm, 4), g_rg = prm_f2(prm, 6), g_ru = prm_f2(prm, 8), g_rh = prm_f2(prm, 10), g_int8 = prm_f2(prm, 12);
    f2 eqt = v[0], eq1 = v[1], eq5 = v[2];
    f2 g8 = v[3], rg = v[4], a8 = v[5], u8 = v[6], ru = v[7], h8 = v[8], rh = v[9], hg = v[10], hu = v[11], hh = v[12];
    f2 c_had = f2_sub(f2_sub(f2_mul(a8, u8), f2_mul_base(h8, prm[30])), rh);
    f2 c_hg = helper_constraint(hg, f2_add(f2_add(g8, f2_mul(beta, a8)), g_silu), f2_add(rg, g_rg), alpha);
    f2 c_hu = helper_constraint(hu, f2_add(u8, g_int8), f2_add(ru, g_ru), alpha);
    f2 c_hh = helper_constraint(hh, f2_add(h8, g_int8), f2_add(rh, g_rh), alpha);
    f2 zc = f2_add(f2_add(f2_mul(prm_f2(prm, 14), c_had), f2_mul(prm_f2(prm, 16), c_hg)), f2_add(f2_mul(prm_f2(prm, 18), c_hu), f2_mul(prm_f2(prm, 20), c_hh)));
    f2 fold1 = f2_add(f2_mul(prm_f2(prm, 22), f2_add(f2_mul_base(g8, prm[28]), rg)), f2_mul(prm_f2(prm, 24), f2_add(f2_mul_base(u8, prm[29]), ru)));
    return f2_add(f2_add(f2_mul(eqt, zc), f2_mul(eq1, fold1)), f2_mul(eq5, f2_mul(prm_f2(prm, 26), h8)));
}

// prm: alpha 0, g_int8 2, g_rd 4, mu2[3] 6..12, nu_x[3] 12..18, nu_z[3] 18..24, p_z 24
__device__ __forceinline__ f2 zc17_poly(const f2* v, const u64* prm) {
    f2 alpha = prm_f2(prm, 0), g_int8 = prm_f2(prm, 2), g_rd = prm_f2(prm, 4);
    f2 eqt = v[0], eq2 = v[1], eq4 = v[2];
    f2 zc = f2_zero(), fx = f2_zero(), fz = f2_zero();
    #pragma unroll
    for (int b = 0; b < 3; b++) {
        f2 x = v[3 + b], z = v[6 + b], rd = v[9 + b], h = v[12 + b];
        zc = f2_add(zc, f2_mul(prm_f2(prm, 6 + 2 * b), helper_constraint(h, f2_add(z, g_int8), f2_add(rd, g_rd), alpha)));
        fx = f2_add(fx, f2_mul(prm_f2(prm, 12 + 2 * b), x));
        fz = f2_add(fz, f2_mul(prm_f2(prm, 18 + 2 * b), f2_add(f2_mul_base(z, prm[24]), rd)));
    }
    return f2_add(f2_add(f2_mul(eqt, zc), f2_mul(eq2, fx)), f2_mul(eq4, fz));
}

// partial[blockIdx.x * (SC_DEG+1) + d] = the block's sum of the round polynomial at d.
// K (the table count) and KIND are template constants so cur/dif stay in
// registers (a runtime-indexed local array would spill to local memory);
// the parameters are staged in shared memory (32 u64, host-padded).
template <int K, int KIND>
__device__ __forceinline__ void sc_round_impl(const u64* __restrict__ tabs, int half, int L, const u64* __restrict__ prm, u64* __restrict__ partial) {
    __shared__ u64 sprm[32];
    __shared__ u64 red[SC_THREADS * (SC_DEG + 1) * 2];
    if (threadIdx.x < 32) sprm[threadIdx.x] = prm[threadIdx.x];
    __syncthreads();
    f2 acc[SC_DEG + 1];
    #pragma unroll
    for (int d = 0; d <= SC_DEG; d++) acc[d] = f2_zero();
    f2 cur[K], dif[K];
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < half; i += gridDim.x * blockDim.x) {
        #pragma unroll
        for (int t = 0; t < K; t++) {
            f2 v0 = ld_f2(tabs, (size_t)t * L + i);
            f2 v1 = ld_f2(tabs, (size_t)t * L + i + half);
            cur[t] = v0;
            dif[t] = f2_sub(v1, v0);
        }
        acc[0] = f2_add(acc[0], KIND == 0 ? zc20_poly(cur, sprm) : zc17_poly(cur, sprm));
        #pragma unroll
        for (int d = 1; d <= SC_DEG; d++) {
            #pragma unroll
            for (int t = 0; t < K; t++) cur[t] = f2_add(cur[t], dif[t]);
            acc[d] = f2_add(acc[d], KIND == 0 ? zc20_poly(cur, sprm) : zc17_poly(cur, sprm));
        }
    }
    #pragma unroll
    for (int d = 0; d <= SC_DEG; d++) { red[(threadIdx.x * (SC_DEG + 1) + d) * 2] = acc[d].c0; red[(threadIdx.x * (SC_DEG + 1) + d) * 2 + 1] = acc[d].c1; }
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (threadIdx.x < s) {
            #pragma unroll
            for (int d = 0; d <= SC_DEG; d++) {
                int a = (threadIdx.x * (SC_DEG + 1) + d) * 2;
                int b = ((threadIdx.x + s) * (SC_DEG + 1) + d) * 2;
                red[a] = gl_add(red[a], red[b]);
                red[a + 1] = gl_add(red[a + 1], red[b + 1]);
            }
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        #pragma unroll
        for (int d = 0; d <= SC_DEG; d++) { partial[(blockIdx.x * (SC_DEG + 1) + d) * 2] = red[d * 2]; partial[(blockIdx.x * (SC_DEG + 1) + d) * 2 + 1] = red[d * 2 + 1]; }
    }
}

extern "C" __global__ void k_sc_round_zc20(const u64* __restrict__ tabs, int half, int L, const u64* __restrict__ prm, u64* __restrict__ partial) {
    sc_round_impl<13, 0>(tabs, half, L, prm, partial);
}
extern "C" __global__ void k_sc_round_zc17(const u64* __restrict__ tabs, int half, int L, const u64* __restrict__ prm, u64* __restrict__ partial) {
    sc_round_impl<15, 1>(tabs, half, L, prm, partial);
}

// ---------------------------------------------------------------------------
// [UPERF3-AH] THE BLOCK-LOOPING ROUND KERNELS. The two zero-check
// polynomials are
//     eq_t * ZC + eq_a * F_a + eq_b * F_b,
// where ZC / F_a / F_b are SUMS OVER BLOCKS of terms that read only that
// block's own tables (10 on the F side, 4 on the D side). So a kernel can
// loop over the blocks, holding ONE block's cur/dif in registers, and
// accumulate the three partial sums at the five evaluation points; the eq
// tables join once per element. The register footprint is therefore
// independent of the block count, which is what the templated
// `sc_round_impl<K, KIND>` above could not do (its cur[K] / dif[K] force K
// to be a compile-time constant, i.e. one block shape per kernel).
// Everything is a field expression identical to the CPU closure's, term
// for term, and every sum is a field sum (order-free), so the round
// polynomials — and hence the transcript and the proof bytes — are the
// templated kernels' and the CPU's.
//   prm, F side: alpha 0, beta 2, g_act 4, g_rg 6, g_ru 8, g_rh 10,
//     g_i16 12, p_g 14, p_u 15, p_h 16, mu[4 nb] 17.., nu[3 nb] 17+8nb..
//   prm, D side: alpha 0, g_i16 2, g_rd 4, p_z 6, mu2[nb] 7..,
//     nu_x[nb] 7+2nb.., nu_z[nb] 7+4nb..
// Table order (== the CPU's `tables` vector): 3 eq tables, then the F side
// BLOCK-major (g8, rg, a16, u16, ru, h16, rh, hg, hu, hh per block) and
// the D side ROLE-major (x for every block, then z, then rd, then h).

#define SCG_THREADS 128
#define SCG_MAX_PRM 384

// The block reduction and the partial write (NV = degree + 1 values per
// round), shared by the block-looping kernels.
template <int NV>
__device__ __forceinline__ void scg_emit(const f2* acc, u64* red, u64* __restrict__ partial) {
    #pragma unroll
    for (int d = 0; d < NV; d++) { red[(threadIdx.x * NV + d) * 2] = acc[d].c0; red[(threadIdx.x * NV + d) * 2 + 1] = acc[d].c1; }
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (threadIdx.x < s) {
            #pragma unroll
            for (int d = 0; d < NV; d++) {
                int a = (threadIdx.x * NV + d) * 2;
                int b = ((threadIdx.x + s) * NV + d) * 2;
                red[a] = gl_add(red[a], red[b]);
                red[a + 1] = gl_add(red[a + 1], red[b + 1]);
            }
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        #pragma unroll
        for (int d = 0; d < NV; d++) { partial[(blockIdx.x * NV + d) * 2] = red[d * 2]; partial[(blockIdx.x * NV + d) * 2 + 1] = red[d * 2 + 1]; }
    }
}

extern "C" __global__ __launch_bounds__(SCG_THREADS, 1) void k_sc_round_zcf_gen(
        const u64* __restrict__ tabs, int half, int L, const u64* __restrict__ prm, int prm_len, int nb, u64* __restrict__ partial) {
    __shared__ u64 sprm[SCG_MAX_PRM];
    __shared__ u64 red[SCG_THREADS * (SC_DEG + 1) * 2];
    for (int i = threadIdx.x; i < prm_len; i += blockDim.x) sprm[i] = prm[i];
    __syncthreads();
    const f2 alpha = prm_f2(sprm, 0), beta = prm_f2(sprm, 2), g_act = prm_f2(sprm, 4);
    const f2 g_rg = prm_f2(sprm, 6), g_ru = prm_f2(sprm, 8), g_rh = prm_f2(sprm, 10), g_i16 = prm_f2(sprm, 12);
    const u64 p_g = sprm[14], p_u = sprm[15], p_h = sprm[16];
    f2 acc[SC_DEG + 1];
    #pragma unroll
    for (int d = 0; d <= SC_DEG; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < half; i += gridDim.x * blockDim.x) {
        f2 zc[SC_DEG + 1], fa[SC_DEG + 1], fb[SC_DEG + 1];
        #pragma unroll
        for (int d = 0; d <= SC_DEG; d++) { zc[d] = f2_zero(); fa[d] = f2_zero(); fb[d] = f2_zero(); }
        for (int b = 0; b < nb; b++) {
            const u64* base = tabs + (size_t)(3 + 10 * b) * (size_t)L * 2;
            f2 cur[10], dif[10];
            #pragma unroll
            for (int t = 0; t < 10; t++) {
                f2 v0 = ld_f2(base, (size_t)t * L + i);
                f2 v1 = ld_f2(base, (size_t)t * L + i + half);
                cur[t] = v0;
                dif[t] = f2_sub(v1, v0);
            }
            const f2 mu0 = prm_f2(sprm, 17 + 8 * b), mu1 = prm_f2(sprm, 19 + 8 * b), mu2 = prm_f2(sprm, 21 + 8 * b), mu3 = prm_f2(sprm, 23 + 8 * b);
            const int no = 17 + 8 * nb + 6 * b;
            const f2 nu0 = prm_f2(sprm, no), nu1 = prm_f2(sprm, no + 2), nu2 = prm_f2(sprm, no + 4);
            #pragma unroll
            for (int d = 0; d <= SC_DEG; d++) {
                if (d) {
                    #pragma unroll
                    for (int t = 0; t < 10; t++) cur[t] = f2_add(cur[t], dif[t]);
                }
                f2 g8 = cur[0], rg = cur[1], a16 = cur[2], u16 = cur[3], ru = cur[4], h16 = cur[5], rh = cur[6], hg = cur[7], hu = cur[8], hh = cur[9];
                f2 c_had = f2_sub(f2_sub(f2_mul(a16, u16), f2_mul_base(h16, p_h)), rh);
                f2 c_hg = helper_constraint(hg, f2_add(f2_add(g8, f2_mul(beta, a16)), g_act), f2_add(rg, g_rg), alpha);
                f2 c_hu = helper_constraint(hu, f2_add(u16, g_i16), f2_add(ru, g_ru), alpha);
                f2 c_hh = helper_constraint(hh, f2_add(h16, g_i16), f2_add(rh, g_rh), alpha);
                zc[d] = f2_add(zc[d], f2_add(f2_add(f2_mul(mu0, c_had), f2_mul(mu1, c_hg)), f2_add(f2_mul(mu2, c_hu), f2_mul(mu3, c_hh))));
                fa[d] = f2_add(fa[d], f2_add(f2_mul(nu0, f2_add(f2_mul_base(g8, p_g), rg)), f2_mul(nu1, f2_add(f2_mul_base(u16, p_u), ru))));
                fb[d] = f2_add(fb[d], f2_mul(nu2, h16));
            }
        }
        f2 e0 = ld_f2(tabs, (size_t)i), e1 = ld_f2(tabs, (size_t)L + i), e5 = ld_f2(tabs, (size_t)2 * L + i);
        f2 d0 = f2_sub(ld_f2(tabs, (size_t)i + half), e0);
        f2 d1 = f2_sub(ld_f2(tabs, (size_t)L + i + half), e1);
        f2 d5 = f2_sub(ld_f2(tabs, (size_t)2 * L + i + half), e5);
        #pragma unroll
        for (int d = 0; d <= SC_DEG; d++) {
            if (d) { e0 = f2_add(e0, d0); e1 = f2_add(e1, d1); e5 = f2_add(e5, d5); }
            acc[d] = f2_add(acc[d], f2_add(f2_add(f2_mul(e0, zc[d]), f2_mul(e1, fa[d])), f2_mul(e5, fb[d])));
        }
    }
    scg_emit<SC_DEG + 1>(acc, red, partial);
}

extern "C" __global__ __launch_bounds__(SCG_THREADS, 1) void k_sc_round_zcd_gen(
        const u64* __restrict__ tabs, int half, int L, const u64* __restrict__ prm, int prm_len, int nb, u64* __restrict__ partial) {
    __shared__ u64 sprm[SCG_MAX_PRM];
    __shared__ u64 red[SCG_THREADS * (SC_DEG + 1) * 2];
    for (int i = threadIdx.x; i < prm_len; i += blockDim.x) sprm[i] = prm[i];
    __syncthreads();
    const f2 alpha = prm_f2(sprm, 0), g_i16 = prm_f2(sprm, 2), g_rd = prm_f2(sprm, 4);
    const u64 p_z = sprm[6];
    f2 acc[SC_DEG + 1];
    #pragma unroll
    for (int d = 0; d <= SC_DEG; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < half; i += gridDim.x * blockDim.x) {
        f2 zc[SC_DEG + 1], fx[SC_DEG + 1], fz[SC_DEG + 1];
        #pragma unroll
        for (int d = 0; d <= SC_DEG; d++) { zc[d] = f2_zero(); fx[d] = f2_zero(); fz[d] = f2_zero(); }
        for (int c = 0; c < nb; c++) {
            f2 cur[4], dif[4];
            #pragma unroll
            for (int t = 0; t < 4; t++) {
                size_t off = (size_t)(3 + t * nb + c) * (size_t)L;
                f2 v0 = ld_f2(tabs, off + i);
                f2 v1 = ld_f2(tabs, off + i + half);
                cur[t] = v0;
                dif[t] = f2_sub(v1, v0);
            }
            const f2 mu2 = prm_f2(sprm, 7 + 2 * c), nux = prm_f2(sprm, 7 + 2 * nb + 2 * c), nuz = prm_f2(sprm, 7 + 4 * nb + 2 * c);
            #pragma unroll
            for (int d = 0; d <= SC_DEG; d++) {
                if (d) {
                    #pragma unroll
                    for (int t = 0; t < 4; t++) cur[t] = f2_add(cur[t], dif[t]);
                }
                f2 x = cur[0], z = cur[1], rd = cur[2], h = cur[3];
                zc[d] = f2_add(zc[d], f2_mul(mu2, helper_constraint(h, f2_add(z, g_i16), f2_add(rd, g_rd), alpha)));
                fx[d] = f2_add(fx[d], f2_mul(nux, x));
                fz[d] = f2_add(fz[d], f2_mul(nuz, f2_add(f2_mul_base(z, p_z), rd)));
            }
        }
        f2 e0 = ld_f2(tabs, (size_t)i), e2 = ld_f2(tabs, (size_t)L + i), e4 = ld_f2(tabs, (size_t)2 * L + i);
        f2 d0 = f2_sub(ld_f2(tabs, (size_t)i + half), e0);
        f2 d2 = f2_sub(ld_f2(tabs, (size_t)L + i + half), e2);
        f2 d4 = f2_sub(ld_f2(tabs, (size_t)2 * L + i + half), e4);
        #pragma unroll
        for (int d = 0; d <= SC_DEG; d++) {
            if (d) { e0 = f2_add(e0, d0); e2 = f2_add(e2, d2); e4 = f2_add(e4, d4); }
            acc[d] = f2_add(acc[d], f2_add(f2_add(f2_mul(e0, zc[d]), f2_mul(e2, fx[d])), f2_mul(e4, fz[d])));
        }
    }
    scg_emit<SC_DEG + 1>(acc, red, partial);
}

// out[m f2] = sum over n entries of m f2 each (one block).
extern "C" __global__ void k_reduce_f2(const u64* __restrict__ partial, int n, int m, u64* __restrict__ out) {
    __shared__ u64 red[1024 * 2];
    for (int c = 0; c < m; c++) {
        f2 acc = f2_zero();
        for (int i = threadIdx.x; i < n; i += blockDim.x) acc = f2_add(acc, ld_f2(partial, (size_t)i * m + c));
        red[threadIdx.x * 2] = acc.c0;
        red[threadIdx.x * 2 + 1] = acc.c1;
        __syncthreads();
        for (int s = blockDim.x / 2; s > 0; s >>= 1) {
            if (threadIdx.x < s) {
                red[threadIdx.x * 2] = gl_add(red[threadIdx.x * 2], red[(threadIdx.x + s) * 2]);
                red[threadIdx.x * 2 + 1] = gl_add(red[threadIdx.x * 2 + 1], red[(threadIdx.x + s) * 2 + 1]);
            }
            __syncthreads();
        }
        if (threadIdx.x == 0) { out[c * 2] = red[0]; out[c * 2 + 1] = red[1]; }
        __syncthreads();
    }
}

// fold every table: tabs[t][i] = v0 + r (v1 - v0), i < half.
extern "C" __global__ void k_sc_fold(u64* __restrict__ tabs, int k, int half, int L, u64 r0, u64 r1) {
    int g = blockIdx.x * blockDim.x + threadIdx.x;
    if (g >= k * half) return;
    int t = g / half;
    int i = g - t * half;
    f2 r; r.c0 = r0; r.c1 = r1;
    f2 a = ld_f2(tabs, (size_t)t * L + i);
    f2 b = ld_f2(tabs, (size_t)t * L + i + half);
    st_f2(tabs, (size_t)t * L + i, f2_add(a, f2_mul(r, f2_sub(b, a))));
}

// Table builders: from a base-field slice (c1 = 0), from a (re, im) pair of slices, and the eq table of a point.
extern "C" __global__ void k_tab_from_fp(const u64* __restrict__ src, u64* __restrict__ dst, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    dst[2 * i] = src[i];
    dst[2 * i + 1] = 0ULL;
}
extern "C" __global__ void k_tab_from_fp2(const u64* __restrict__ re, const u64* __restrict__ im, u64* __restrict__ dst, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    dst[2 * i] = re[i];
    dst[2 * i + 1] = im[i];
}
// eq(r, x) for x = idx (r[0] the MOST significant index bit, as mle::eq_table_msb): the product of the per-bit factors.
extern "C" __global__ void k_eq_table(const u64* __restrict__ r, u64* __restrict__ dst, int nv) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= (1 << nv)) return;
    f2 one; one.c0 = 1; one.c1 = 0;
    f2 acc = one;
    for (int i = 0; i < nv; i++) {
        f2 ri = ld_f2(r, i);
        int bit = (idx >> (nv - 1 - i)) & 1;
        acc = f2_mul(acc, bit ? ri : f2_sub(one, ri));
    }
    st_f2(dst, idx, acc);
}

// ---------------------------------------------------------------------------
// [rung 4] The PCS opening's row-combinations on the device: out[g][j] =
// sum_i rho[g][i] * data[i][j] for k <= 4 row-weight vectors at once (==
// pcs::fold_rows_multi over the systematic data). One thread per column;
// the rho reads are warp-uniform broadcasts.

#define FR_MAX_K 4

extern "C" __global__ void k_fold_rows(const u64* __restrict__ data, const u64* __restrict__ rhos, u64* __restrict__ out, int rows, int n, int k) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= n) return;
    f2 acc[FR_MAX_K];
    #pragma unroll
    for (int g = 0; g < FR_MAX_K; g++) acc[g] = f2_zero();
    for (int i = 0; i < rows; i++) {
        u64 v = data[(size_t)i * n + j];
        #pragma unroll
        for (int g = 0; g < FR_MAX_K; g++) {
            if (g < k) {
                f2 r = ld_f2(rhos, (size_t)g * rows + i);
                acc[g] = f2_add(acc[g], f2_mul_base(r, v));
            }
        }
    }
    #pragma unroll
    for (int g = 0; g < FR_MAX_K; g++) {
        if (g < k) st_f2(out, (size_t)g * n + j, acc[g]);
    }
}

// ---------------------------------------------------------------------------
// [rung 4b] The LogUp helper columns on the device: h = 1/(alpha - l1) +
// 1/(alpha - l2) with l1 = v1 + beta * w + c1 (w optional), l2 = v2 + c2,
// v1 / w / v2 base-field slices of the resident A data; h's (re, im) go
// straight into the H data buffer. Inverses by Montgomery's trick over a
// per-thread chunk of HC elements (2 HC denominators) with one Fermat
// inversion; inverses are unique, so the values equal the CPU's
// batch_inverse2's.

#define HC 8

__device__ __forceinline__ u64 gl_pow_pm2(u64 a) {
    // a^(p - 2), p - 2 = 0xFFFFFFFE_FFFFFFFF: square-and-multiply, MSB first.
    u64 e = 0xFFFFFFFEFFFFFFFFULL;
    u64 acc = 1ULL;
    u64 base = a;
    for (int i = 0; i < 64; i++) {
        if ((e >> i) & 1ULL) acc = gl_mul(acc, base);
        base = gl_mul(base, base);
    }
    return acc;
}
__device__ __forceinline__ f2 f2_inv(f2 a) {
    u64 norm = gl_sub(gl_mul(a.c0, a.c0), gl_mul(gl_mul(a.c1, a.c1), NONRES));
    u64 ninv = gl_pow_pm2(norm);
    f2 r;
    r.c0 = gl_mul(a.c0, ninv);
    r.c1 = gl_mul(gl_sub(0ULL, a.c1), ninv);
    return r;
}

// prm: alpha 0, beta 2, c1 4, c2 6
extern "C" __global__ void k_helper(const u64* __restrict__ a, int off_v1, int off_w, int off_v2, int n, const u64* __restrict__ prm,
                                    u64* __restrict__ h, int off_re, int off_im) {
    int t = blockIdx.x * blockDim.x + threadIdx.x;
    int base = t * HC;
    if (base >= n) return;
    f2 alpha = prm_f2(prm, 0), beta = prm_f2(prm, 2), c1 = prm_f2(prm, 4), c2 = prm_f2(prm, 6);
    f2 den[2 * HC];
    int cnt = (n - base) < HC ? (n - base) : HC;
    #pragma unroll
    for (int i = 0; i < HC; i++) {
        if (i < cnt) {
            f2 v1; v1.c0 = a[off_v1 + base + i]; v1.c1 = 0;
            f2 l1 = f2_add(v1, c1);
            if (off_w >= 0) { f2 w; w.c0 = a[off_w + base + i]; w.c1 = 0; l1 = f2_add(l1, f2_mul(beta, w)); }
            f2 v2; v2.c0 = a[off_v2 + base + i]; v2.c1 = 0;
            f2 l2 = f2_add(v2, c2);
            den[2 * i] = f2_sub(alpha, l1);
            den[2 * i + 1] = f2_sub(alpha, l2);
        } else {
            den[2 * i].c0 = 1; den[2 * i].c1 = 0;
            den[2 * i + 1].c0 = 1; den[2 * i + 1].c1 = 0;
        }
    }
    // Montgomery: prefix products, one inversion, backward sweep
    f2 pre[2 * HC];
    f2 acc; acc.c0 = 1; acc.c1 = 0;
    #pragma unroll
    for (int i = 0; i < 2 * HC; i++) { pre[i] = acc; acc = f2_mul(acc, den[i]); }
    f2 inv = f2_inv(acc);
    #pragma unroll
    for (int i = 2 * HC - 1; i >= 0; i--) {
        f2 d = den[i];
        den[i] = f2_mul(inv, pre[i]);
        inv = f2_mul(inv, d);
    }
    #pragma unroll
    for (int i = 0; i < HC; i++) {
        if (i < cnt) {
            f2 hv = f2_add(den[2 * i], den[2 * i + 1]);
            h[off_re + base + i] = hv.c0;
            h[off_im + base + i] = hv.c1;
        }
    }
}

// partial[blockIdx.x] = the block's sum of src[off + i], i < n (base field).
extern "C" __global__ void k_sum_fp(const u64* __restrict__ src, int off, int n, u64* __restrict__ partial) {
    __shared__ u64 red[256];
    u64 acc = 0;
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += gridDim.x * blockDim.x) acc = gl_add(acc, src[off + i]);
    red[threadIdx.x] = acc;
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (threadIdx.x < s) red[threadIdx.x] = gl_add(red[threadIdx.x], red[threadIdx.x + s]);
        __syncthreads();
    }
    if (threadIdx.x == 0) partial[blockIdx.x] = red[0];
}

// ---------------------------------------------------------------------------
// [rung 4c] eq tables from two half tables (eq(r, x) factorizes over the
// variable split: the same product, one f2_mul per entry) and the MLE
// evaluations of base-field slices against a resident eq table (the
// prover's `eval_many`: sum_i data[off + i] * eq[i], block partials).

extern "C" __global__ void k_eq_join(const u64* __restrict__ hi, const u64* __restrict__ lo, u64* __restrict__ dst, int lo_bits, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;
    f2 h = ld_f2(hi, idx >> lo_bits);
    f2 l = ld_f2(lo, idx & ((1 << lo_bits) - 1));
    st_f2(dst, idx, f2_mul(h, l));
}

// partial[blockIdx.x * m + s] = the block's sum over i of data[offs[s] + i] * eq[i], for m slices.
extern "C" __global__ void k_dot_slices(const u64* __restrict__ data, const int* __restrict__ offs, int m, const u64* __restrict__ eq, int n, u64* __restrict__ partial) {
    __shared__ u64 red[256 * 2];
    for (int s = 0; s < m; s++) {
        int off = offs[s];
        f2 acc = f2_zero();
        for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += gridDim.x * blockDim.x) {
            acc = f2_add(acc, f2_mul_base(ld_f2(eq, i), data[off + i]));
        }
        red[threadIdx.x * 2] = acc.c0;
        red[threadIdx.x * 2 + 1] = acc.c1;
        __syncthreads();
        for (int st = blockDim.x / 2; st > 0; st >>= 1) {
            if (threadIdx.x < st) {
                red[threadIdx.x * 2] = gl_add(red[threadIdx.x * 2], red[(threadIdx.x + st) * 2]);
                red[threadIdx.x * 2 + 1] = gl_add(red[threadIdx.x * 2 + 1], red[(threadIdx.x + st) * 2 + 1]);
            }
            __syncthreads();
        }
        if (threadIdx.x == 0) { partial[(blockIdx.x * m + s) * 2] = red[0]; partial[(blockIdx.x * m + s) * 2 + 1] = red[1]; }
        __syncthreads();
    }
}

// ---------------------------------------------------------------------------
// [rung 4d] The inverse transform as a DIF (Gentleman-Sande) NTT: natural
// order in, bit-reversed order out, NO gather anywhere. Pass A runs the
// first log_n - 12 stages (len = n .. 8192) on the strided [2^(log_n-12)]
// x [J] tile (coalesced), pass B the last 12 (len = 4096 .. 2) on
// contiguous 4096-blocks; the 1/n scale rides on the last store. The
// coefficient buffer then holds coef[rev(p)] at p, which is exactly the
// bit-reversed input order the forward DIT (k_ntt_p1) wants: with
// zero padding by R = 2^rb, DIT position x = m * R reads coef-buffer[m]
// (rev_{log_nn}(m R) == rev_{log_n}(m)) and every other position is 0 —
// a contiguous load. Values: the same evaluations (unique), as before.

template <bool FAST>
__device__ __forceinline__ void dif_pa_body(u64* sh, const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw, int log_n) {
    const int n = 1 << log_n;
    const int lt = log_n - NTT_LOG_BLK;
    const int nt = 1 << lt;
    const int lj = NTT_LOG_BLK - lt;
    const int J = NTT_BLK >> lt;
    const int row = FAST ? (int)(blockIdx.x >> lt) : (int)(blockIdx.x / nt);
    const int tile = blockIdx.x - row * nt;
    const int j0 = tile * J;
    const u64* s = src + (size_t)row * (size_t)n;
    u64* d = dst + (size_t)row * (size_t)n;
    for (int q = threadIdx.x; q < NTT_BLK; q += blockDim.x) {
        int t = FAST ? (q >> lj) : (q / J), jj = q - t * J;
        sh[q] = s[t * NTT_BLK + j0 + jj];
    }
    __syncthreads();
    for (int st = log_n; st > NTT_LOG_BLK; st--) {
        const int hs = st - 1 - NTT_LOG_BLK;
        const int halft = 1 << hs;
        const u64* tws = tw + ((size_t)1 << (st - 1)) - 1;
        for (int b = threadIdx.x; b < (NTT_BLK >> 1); b += blockDim.x) {
            int jj = FAST ? (b & (J - 1)) : (b % J);
            int tb = FAST ? (b >> lj) : (b / J);
            int tl = tb & (halft - 1);
            int t = ((tb >> hs) << (hs + 1)) + tl;
            int k = tl * NTT_BLK + j0 + jj;
            u64 w = tws[k];
            int i = t * J + jj;
            int ip = i + halft * J;
            u64 u = sh[i];
            u64 v = sh[ip];
            sh[i] = gl_add(u, v);
            sh[ip] = gl_mul(gl_sub(u, v), w);
        }
        __syncthreads();
    }
    for (int q = threadIdx.x; q < NTT_BLK; q += blockDim.x) {
        int t = FAST ? (q >> lj) : (q / J), jj = q - t * J;
        d[t * NTT_BLK + j0 + jj] = sh[q];
    }
}

extern "C" __global__ void k_dif_pa(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw, int log_n) {
    __shared__ u64 sh[NTT_BLK];
    dif_pa_body<false>(sh, src, dst, tw, log_n);
}

extern "C" __global__ void k_dif_pa_f(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw, int log_n) {
    __shared__ u64 sh[NTT_BLK];
    dif_pa_body<true>(sh, src, dst, tw, log_n);
}

extern "C" __global__ void k_dif_pb(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw, int log_n, u64 scale) {
    __shared__ u64 sh[NTT_BLK];
    const int n = 1 << log_n;
    const int lb = log_n < NTT_LOG_BLK ? log_n : NTT_LOG_BLK;
    const int bs = 1 << lb;
    const int blocks_per_row = n >> lb;
    const int row = blockIdx.x / blocks_per_row;
    const int blk = blockIdx.x - row * blocks_per_row;
    const u64* s = src + (size_t)row * (size_t)n + (size_t)blk * (size_t)bs;
    u64* d = dst + (size_t)row * (size_t)n + (size_t)blk * (size_t)bs;
    for (int q = threadIdx.x; q < bs; q += blockDim.x) sh[q] = s[q];
    __syncthreads();
    for (int st = lb; st >= 1; st--) {
        const int half = 1 << (st - 1);
        const u64* tws = tw + (half - 1);
        for (int b = threadIdx.x; b < (bs >> 1); b += blockDim.x) {
            int k = b & (half - 1);
            int i = ((b >> (st - 1)) << st) + k;
            u64 w = tws[k];
            u64 u = sh[i];
            u64 v = sh[i + half];
            sh[i] = gl_add(u, v);
            sh[i + half] = gl_mul(gl_sub(u, v), w);
        }
        __syncthreads();
    }
    for (int q = threadIdx.x; q < bs; q += blockDim.x) {
        u64 v = sh[q];
        if (scale != 1ULL) v = gl_mul(v, scale);
        d[q] = v;
    }
}

// The forward DIT's first pass with the bit-reversed-order coefficient
// buffer (rows x n_src) as input, zero-padded by R = 2^rb (log_n = log of
// n_src + rb): position x = m R reads src[m], others are 0 (contiguous).
// [UPERF3-AO] SKIP = true drops the first `rb` stages, which on this input
// are not arithmetic at all but a BROADCAST. The source is the size-n_src
// coefficient buffer in bit-reversed order, zero-padded R = 2^rb-fold:
// position x holds s[x >> rb] when x == 0 (mod R) and 0 otherwise, and
// stages 1..rb mix only WITHIN each aligned group of R positions, whose
// only nonzero member is index 0. A butterfly with a zero odd leg writes u
// to both legs — gl_mul(0, w) = 0 for every w, and gl_add(u, 0) =
// gl_sub(u, 0) = u for canonical u < P — so after stage rb the tile holds
// sh[x] == s[x >> rb] at EVERY x, which is exactly the load below. (Each
// block covers a bs = 2^lb-aligned span and R | bs, so no group straddles
// a block.) Byte-identical, rb fewer stages and rb fewer barriers, on the
// largest kernel of both the commit encode and the opening re-encode.
// SKIP = false is the original, for the A/B (`HL_GPU_PAD_SKIP=0`).
template <bool SKIP>
__device__ __forceinline__ void dit_p1_pad_body(u64* sh, const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw,
                                                int log_n, int n_src, int rb) {
    const int n = 1 << log_n;
    const int lb = log_n < NTT_LOG_BLK ? log_n : NTT_LOG_BLK;
    const int bs = 1 << lb;
    const int blocks_per_row = n >> lb;
    const int row = blockIdx.x / blocks_per_row;
    const int blk = blockIdx.x - row * blocks_per_row;
    const u64* s = src + (size_t)row * (size_t)n_src;
    u64* d = dst + (size_t)row * (size_t)n + (size_t)blk * (size_t)bs;
    const int mask = (1 << rb) - 1;
    const int st0 = (SKIP && rb > 0 && rb <= lb) ? rb : 0;
    for (int q = threadIdx.x; q < bs; q += blockDim.x) {
        int x = blk * bs + q;
        sh[q] = (st0 != 0 || (x & mask) == 0) ? s[x >> rb] : 0ULL;
    }
    __syncthreads();
    for (int st = st0 + 1; st <= lb; st++) {
        const int half = 1 << (st - 1);
        const u64* tws = tw + (half - 1);
        for (int b = threadIdx.x; b < (bs >> 1); b += blockDim.x) {
            int k = b & (half - 1);
            int i = ((b >> (st - 1)) << st) + k;
            u64 w = tws[k];
            u64 u = sh[i];
            u64 v = gl_mul(sh[i + half], w);
            sh[i] = gl_add(u, v);
            sh[i + half] = gl_sub(u, v);
        }
        __syncthreads();
    }
    for (int q = threadIdx.x; q < bs; q += blockDim.x) d[q] = sh[q];
}

extern "C" __global__ void k_dit_p1_pad(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw,
                                        int log_n, int n_src, int rb) {
    __shared__ u64 sh[NTT_BLK];
    dit_p1_pad_body<false>(sh, src, dst, tw, log_n, n_src, rb);
}

extern "C" __global__ void k_dit_p1_pad_s(const u64* __restrict__ src, u64* __restrict__ dst, const u64* __restrict__ tw,
                                          int log_n, int n_src, int rb) {
    __shared__ u64 sh[NTT_BLK];
    dit_p1_pad_body<true>(sh, src, dst, tw, log_n, n_src, rb);
}

// [UPERF3-ZA] The ZK row encoding's coefficient step (new kernel; nothing
// above changes): out[row][i] = (coef[i] - pad[i]) h^i for i < q, coef[i] h^i
// for q <= i < n, pad[i - n] h^i for n <= i < n + q, 0 beyond — the
// coefficients of f_data + Z_n g_pad scaled onto the coset, ready for the
// size-nn forward NTT (== pcs::encode_row_zk on every row).
extern "C" __global__ void k_zk_pad_scale(const u64* __restrict__ coef, const u64* __restrict__ pads, const u64* __restrict__ pows,
                                          u64* __restrict__ out, int rows, int n, int q, int nn) {
    size_t g = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (g >= (size_t)rows * (size_t)nn) return;
    int row = (int)(g / (size_t)nn);
    int i = (int)(g - (size_t)row * (size_t)nn);
    u64 v = 0ULL;
    if (i < n) {
        v = coef[(size_t)row * (size_t)n + i];
        if (i < q) v = gl_sub(v, pads[(size_t)row * (size_t)q + i]);
    } else if (i < n + q) {
        v = pads[(size_t)row * (size_t)q + (i - n)];
    }
    out[g] = gl_mul(v, pows[i]);
}

// ---------------------------------------------------------------------------
// [UPERF3-AC] THE CHUNKED COMMIT (new kernels; nothing above changes).
//
// k_hash_cols_stream: the streaming form of k_hash_cols. The encoded matrix
// arrives in ROW CHUNKS [row0, row0 + rc) — every chunk but the last is a
// multiple of 128 rows = 1024 column bytes = exactly one blake3 chunk, so a
// row-chunk boundary is a blake3 chunk boundary and no partial chunk state
// is needed; the per-column CV STACK lives in `state` across launches:
//   state[(8 s + i) * nn + j] = stack[s][i] of column j (s < B3_MAX_DEPTH),
//   state[(8 B3_MAX_DEPTH) * nn + j] = its stack length (zeroed before the
//   first chunk).
// The launch that holds the last row finishes the column exactly as
// b3_hash_column does (the same compressions with the same flags in the
// same order — blake3 is a function of the byte string, and the byte
// string is the same column) and writes its 8 words to `leaves`.

#define B3_STATE_SLOTS (8 * B3_MAX_DEPTH + 1)

extern "C" __global__ void k_hash_cols_stream(const u64* __restrict__ enc, u32* __restrict__ state, int rc, int row0, int rows, int nn,
                                              u32* __restrict__ leaves) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= nn) return;
    const u32 len = (u32)rows * 8u;
    const u32 n_chunks = (len + 1023u) / 1024u;
    const size_t snn = (size_t)nn;
    #define STK(s, i) state[((size_t)(8 * (s) + (i))) * snn + (size_t)j]
    int stack_len = (int)state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j];
    u32 cv[8];
    u32 block[16];
    u32 tmp[8];
    const u32 c_begin = (u32)(row0 / 128);
    const u32 c_end = (u32)((row0 + rc + 127) / 128);
    for (u32 c = c_begin; c < c_end; c++) {
        const bool is_last = (c + 1 == n_chunks);
        const u32 chunk_len = is_last ? (len - c * 1024u) : 1024u;
        const int want = __popc(c);
        while (stack_len > want) {
            u32 pb[16];
            #pragma unroll
            for (int i = 0; i < 8; i++) { pb[i] = STK(stack_len - 2, i); pb[8 + i] = STK(stack_len - 1, i); }
            u32 iv[8];
            b3_iv(iv);
            b3_compress(iv, pb, 0ULL, 64u, B3_PARENT, tmp);
            #pragma unroll
            for (int i = 0; i < 8; i++) STK(stack_len - 2, i) = tmp[i];
            stack_len -= 1;
        }
        b3_iv(cv);
        const u32 n_blocks = (chunk_len + 63u) / 64u;
        for (u32 b = 0; b < n_blocks; b++) {
            const bool last_block = (b + 1 == n_blocks);
            const u32 blen = last_block ? (chunk_len - b * 64u) : 64u;
            u32 flags = (b == 0 ? B3_CHUNK_START : 0u) | (last_block ? B3_CHUNK_END : 0u);
            if (is_last && stack_len == 0 && last_block) flags |= B3_ROOT;
            #pragma unroll
            for (int w = 0; w < 16; w += 2) {
                int e = (int)(c * 128u + b * 8u) + (w >> 1);
                u64 v = (e < rows) ? enc[(size_t)(e - row0) * snn + (size_t)j] : 0ULL;
                block[w] = (u32)v;
                block[w + 1] = (u32)(v >> 32);
            }
            b3_compress(cv, block, (u64)c, blen, flags, tmp);
            #pragma unroll
            for (int i = 0; i < 8; i++) cv[i] = tmp[i];
        }
        if (is_last) {
            for (int s = stack_len - 1; s >= 0; s--) {
                u32 pb[16];
                #pragma unroll
                for (int i = 0; i < 8; i++) { pb[i] = STK(s, i); pb[8 + i] = cv[i]; }
                u32 iv[8];
                b3_iv(iv);
                b3_compress(iv, pb, 0ULL, 64u, B3_PARENT | (s == 0 ? B3_ROOT : 0u), tmp);
                #pragma unroll
                for (int i = 0; i < 8; i++) cv[i] = tmp[i];
            }
            #pragma unroll
            for (int w = 0; w < 8; w++) leaves[(size_t)j * 8 + w] = cv[w];
            return;
        }
        #pragma unroll
        for (int i = 0; i < 8; i++) STK(stack_len, i) = cv[i];
        stack_len += 1;
    }
    state[(size_t)(8 * B3_MAX_DEPTH) * snn + (size_t)j] = (u32)stack_len;
    #undef STK
}

// Column gather from a ROW CHUNK: out[c * rows + row0 + i] = enc[i * nn + idx[c]], i < rc
// (the opening's columns assembled chunk by chunk from a re-encoded chunk).
extern "C" __global__ void k_gather_cols_off(const u64* __restrict__ enc, u64* __restrict__ out, const int* __restrict__ idx,
                                             int rc, int row0, int rows, int nn, int q) {
    int g = blockIdx.x * blockDim.x + threadIdx.x;
    if (g >= rc * q) return;
    int c = g / rc;
    int i = g - c * rc;
    out[(size_t)c * (size_t)rows + (size_t)(row0 + i)] = enc[(size_t)i * (size_t)nn + (size_t)idx[c]];
}

// [UPERF3-AH] (rung 3, lane AD's item) The ZK TABLE zero-check on the
// device: eq(tau3) * sum_i mu3_i (h_i (alpha - tval_i) - m_i) over
// log_S = max(log n, 16) variables, DEGREE 3 (4 evaluation points per
// round, not 5). Tables: 0 = eq(tau3), then per slot i the multiplicity
// row m (a base-field row of the A data), the helper h (an (re, im) pair
// of H rows) and the PUBLIC table values tval (uploaded), each
// ZERO-EXTENDED from its own 2^log_size to 2^log_S — the host builds the
// same three vectors with `resize(big, ZERO)`, so the device buffer is
// zeroed once and only the live prefix is written.
//   prm: alpha 0, mu3[ns] 2..

extern "C" __global__ __launch_bounds__(SCG_THREADS, 1) void k_sc_round_tab_gen(
        const u64* __restrict__ tabs, int half, int L, const u64* __restrict__ prm, int prm_len, int ns, u64* __restrict__ partial) {
    __shared__ u64 sprm[SCG_MAX_PRM];
    __shared__ u64 red[SCG_THREADS * 4 * 2];
    for (int i = threadIdx.x; i < prm_len; i += blockDim.x) sprm[i] = prm[i];
    __syncthreads();
    const f2 alpha = prm_f2(sprm, 0);
    f2 acc[4];
    #pragma unroll
    for (int d = 0; d < 4; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < half; i += gridDim.x * blockDim.x) {
        f2 sum[4];
        #pragma unroll
        for (int d = 0; d < 4; d++) sum[d] = f2_zero();
        for (int t = 0; t < ns; t++) {
            f2 cur[3], dif[3];
            #pragma unroll
            for (int r = 0; r < 3; r++) {
                size_t off = (size_t)(1 + 3 * t + r) * (size_t)L;
                f2 v0 = ld_f2(tabs, off + i);
                f2 v1 = ld_f2(tabs, off + i + half);
                cur[r] = v0;
                dif[r] = f2_sub(v1, v0);
            }
            const f2 mu = prm_f2(sprm, 2 + 2 * t);
            #pragma unroll
            for (int d = 0; d < 4; d++) {
                if (d) {
                    #pragma unroll
                    for (int r = 0; r < 3; r++) cur[r] = f2_add(cur[r], dif[r]);
                }
                sum[d] = f2_add(sum[d], f2_mul(mu, f2_sub(f2_mul(cur[1], f2_sub(alpha, cur[2])), cur[0])));
            }
        }
        f2 e = ld_f2(tabs, (size_t)i);
        f2 de = f2_sub(ld_f2(tabs, (size_t)i + half), e);
        #pragma unroll
        for (int d = 0; d < 4; d++) {
            if (d) e = f2_add(e, de);
            acc[d] = f2_add(acc[d], f2_mul(e, sum[d]));
        }
    }
    scg_emit<4>(acc, red, partial);
}
