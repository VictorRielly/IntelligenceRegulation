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

extern "C" __global__ void k_ntt_p2(u64* __restrict__ a, const u64* __restrict__ tw, int log_n, u64 scale) {
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
        const u64* tws = tw + ((size_t)1 << (st - 1)) - 1;
        for (int b = threadIdx.x; b < (NTT_BLK >> 1); b += blockDim.x) {
            int jj = b % J;
            int tb = b / J;
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
