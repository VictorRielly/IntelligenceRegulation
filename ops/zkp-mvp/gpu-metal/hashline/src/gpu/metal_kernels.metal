// [ZK60-METAL M0/M1, 2026-10-31] hashline's commitment encode-and-hash on the
// Apple GPU (Metal Shading Language, compiled at run time from this source).
//
// DIFFERENTIAL DISCIPLINE (the same as the CUDA kernels): every kernel computes
// the canonical Goldilocks representative of the same mathematical quantity the
// CPU computes (zkp-core field.rs / ntt.rs / pcs.rs / pcs/encode_buffer.rs), and
// BLAKE3 is a function, so the leaves are byte-identical to the CPU's. The CPU
// stays the oracle; tests/zk60_metal_commit.rs compares every output.

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------- Goldilocks
// p = 2^64 - 2^32 + 1; EPS = 2^64 mod p = 2^32 - 1. Canonical values (< p)
// everywhere, exactly as zkp-core's Fp.
constant ulong GL_P = 0xFFFFFFFF00000001UL;
constant ulong GL_EPS = 0xFFFFFFFFUL;

inline ulong gl_canon(ulong v) { return v >= GL_P ? v - GL_P : v; }

// Fp::add: overflowing add, + EPS on carry, then Fp::new
inline ulong gl_add(ulong a, ulong b) {
    ulong r = a + b;
    if (r < a) { r += GL_EPS; }
    return gl_canon(r);
}

// Fp::sub: overflowing sub, - EPS on borrow (no final reduction needed)
inline ulong gl_sub(ulong a, ulong b) {
    ulong r = a - b;
    if (a < b) { r -= GL_EPS; }
    return r;
}

// the full 128-bit product as (lo, hi) from 32-bit limbs (exact)
inline void mul_64x64(ulong a, ulong b, thread ulong &lo, thread ulong &hi) {
    ulong a0 = a & 0xFFFFFFFFUL, a1 = a >> 32;
    ulong b0 = b & 0xFFFFFFFFUL, b1 = b >> 32;
    ulong p00 = a0 * b0;
    ulong p01 = a0 * b1;
    ulong p10 = a1 * b0;
    ulong p11 = a1 * b1;
    ulong mid = (p00 >> 32) + (p01 & 0xFFFFFFFFUL) + (p10 & 0xFFFFFFFFUL);
    lo = (p00 & 0xFFFFFFFFUL) | (mid << 32);
    hi = p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32);
}

// field.rs reduce128, line for line
inline ulong gl_reduce128(ulong x_lo, ulong x_hi) {
    ulong x_hi_hi = x_hi >> 32;
    ulong x_hi_lo = x_hi & GL_EPS;
    ulong t0 = x_lo - x_hi_hi;
    if (x_lo < x_hi_hi) { t0 -= GL_EPS; }
    ulong t1 = x_hi_lo * GL_EPS;
    ulong res = t0 + t1;
    if (res < t0) { res += GL_EPS; }
    return gl_canon(res);
}

inline ulong gl_mul(ulong a, ulong b) {
    ulong lo, hi;
    mul_64x64(a, b, lo, hi);
    return gl_reduce128(lo, hi);
}

inline ulong rev_bits(ulong i, uint log_n) {
    // reverse the low log_n bits of i (log_n <= 32 here)
    uint lo = uint(i & 0xFFFFFFFFUL);
    uint r = reverse_bits(lo);
    return log_n == 0 ? 0 : ulong(r >> (32 - log_n));
}

// ------------------------------------------------------------- field probe
struct ProbeArgs { ulong count; };

// out[3i..3i+3] = (a+b, a-b, a*b) for the M0 unit equality against field.rs
kernel void k_gl_probe(device const ulong *a [[buffer(0)]],
                       device const ulong *b [[buffer(1)]],
                       device ulong *out [[buffer(2)]],
                       constant ProbeArgs &args [[buffer(3)]],
                       uint gid [[thread_position_in_grid]]) {
    if (ulong(gid) >= args.count) { return; }
    ulong x = a[gid], y = b[gid];
    out[3 * gid + 0] = gl_add(x, y);
    out[3 * gid + 1] = gl_sub(x, y);
    out[3 * gid + 2] = gl_mul(x, y);
}

// -------------------------------------------------------------------- NTT
// The CPU's transform (ntt.rs): bit-reversal permutation, then radix-2
// Cooley-Tukey stages len = 2, 4, ..., n with w = tw[k * (max_n / len)].
// Rows are independent; row r occupies [r * n, (r + 1) * n).

struct CopyRevArgs { ulong rows; uint log_n; uint pad0; };

// dst[r*n + rev(i)] = src[r*n + i]   (out of place)
kernel void k_bitrev_copy(device const ulong *src [[buffer(0)]],
                          device ulong *dst [[buffer(1)]],
                          constant CopyRevArgs &args [[buffer(2)]],
                          uint2 gid [[thread_position_in_grid]]) {
    ulong n = 1UL << args.log_n;
    ulong i = ulong(gid.x);
    ulong r = ulong(gid.y);
    if (i >= n || r >= args.rows) { return; }
    dst[r * n + rev_bits(i, args.log_n)] = src[r * n + i];
}

struct StageArgs { ulong rows; uint log_n; uint log_len; ulong stride; };

// one butterfly per thread: gid.x in [0, n/2), gid.y = row
kernel void k_ntt_stage(device ulong *a [[buffer(0)]],
                        device const ulong *tw [[buffer(1)]],
                        constant StageArgs &args [[buffer(2)]],
                        uint2 gid [[thread_position_in_grid]]) {
    ulong half_n = 1UL << (args.log_n - 1);
    ulong b = ulong(gid.x);
    ulong r = ulong(gid.y);
    if (b >= half_n || r >= args.rows) { return; }
    ulong half_len = 1UL << (args.log_len - 1);
    ulong grp = b >> (args.log_len - 1);
    ulong k = b & (half_len - 1);
    ulong base = r * (half_n << 1) + (grp << args.log_len) + k;
    ulong w = tw[k * args.stride];
    ulong u = a[base];
    ulong v = gl_mul(a[base + half_len], w);
    a[base] = gl_add(u, v);
    a[base + half_len] = gl_sub(u, v);
}

struct ScaleArgs { ulong rows; uint log_n; uint pad0; ulong s; };

// a[r*n + i] *= s  (the inverse transform's 1/n), gid.x = i, gid.y = row
kernel void k_scale(device ulong *a [[buffer(0)]],
                    constant ScaleArgs &args [[buffer(1)]],
                    uint2 gid [[thread_position_in_grid]]) {
    ulong n = 1UL << args.log_n;
    ulong i = ulong(gid.x);
    ulong r = ulong(gid.y);
    if (i >= n || r >= args.rows) { return; }
    a[r * n + i] = gl_mul(a[r * n + i], args.s);
}

// ------------------------------------------------------- row initializers
// Both write the forward transform's input straight into bit-reversed
// position, so the forward NTT needs no separate permutation pass.

struct InitArgs { ulong rows; uint log_n; uint log_nn; ulong q; };

// plain (ntt.rs rs_encode): out[i] = coeffs[i] for i < n, 0 above
kernel void k_init_plain_bitrev(device const ulong *coeffs [[buffer(0)]],
                                device ulong *enc [[buffer(1)]],
                                constant InitArgs &args [[buffer(2)]],
                                uint2 gid [[thread_position_in_grid]]) {
    ulong n = 1UL << args.log_n;
    ulong nn = 1UL << args.log_nn;
    ulong i = ulong(gid.x);
    ulong r = ulong(gid.y);
    if (i >= nn || r >= args.rows) { return; }
    ulong x = i < n ? coeffs[r * n + i] : 0UL;
    enc[r * nn + rev_bits(i, args.log_nn)] = x;
}

// hiding (pcs/encode_buffer.rs initialize_row, including its q > n branch):
//   i <  n:      (coeffs[i] - (i < q ? pad[i] : 0)) * pows[i]
//   n <= i < n+q: (n + j < q ? pad[j] - pad[n + j] : pad[j]) * pows[i],  j = i - n
//   above:        0
kernel void k_init_zk_bitrev(device const ulong *coeffs [[buffer(0)]],
                             device const ulong *pads [[buffer(1)]],
                             device const ulong *pows [[buffer(2)]],
                             device ulong *enc [[buffer(3)]],
                             constant InitArgs &args [[buffer(4)]],
                             uint2 gid [[thread_position_in_grid]]) {
    ulong n = 1UL << args.log_n;
    ulong nn = 1UL << args.log_nn;
    ulong q = args.q;
    ulong i = ulong(gid.x);
    ulong r = ulong(gid.y);
    if (i >= nn || r >= args.rows) { return; }
    device const ulong *pad = pads + r * q;
    ulong x;
    if (i < n) {
        ulong c = coeffs[r * n + i];
        x = gl_mul(i < q ? gl_sub(c, pad[i]) : c, pows[i]);
    } else if (i < n + q) {
        ulong j = i - n;
        ulong v = (n + j < q) ? gl_sub(pad[j], pad[n + j]) : pad[j];
        x = gl_mul(v, pows[i]);
    } else {
        x = 0UL;
    }
    enc[r * nn + rev_bits(i, args.log_nn)] = x;
}

// ------------------------------------------------- fused NTT (M2, two passes)
// The same transform as k_bitrev_copy + k_ntt_stage (ntt.rs), in two memory
// passes instead of log_n + 1:
//   HEAD: one threadgroup per TILE-long block of the bit-reversed working
//         array: GATHER its inputs (input(rev(g))), run stages 1..min(log_n, 11)
//         in threadgroup memory, write the block back contiguously.
//   TAIL: stages 12..log_n. Those butterflies only connect indices that differ
//         in bits 11..log_n-1, so a group is 2^G elements at stride 2^11
//         (G = log_n - 11); a threadgroup holds C = TILE / 2^G consecutive
//         groups (coalesced loads), runs the G stages, writes back.
// The input of HEAD is one of: a natural-order copy (mode 0, the inverse
// transform of the data), the plain RS-encoder row (mode 1) or the hiding row
// of encode_buffer.rs (mode 2), so the row initialization is fused too.
// The optional `scale` multiplies every output (the inverse's 1/n) in the
// kernel that writes the final values. Same twiddles, same butterflies, same
// order of stages: the values are the CPU's.

#define TILE_LOG 11u
#define TILE (1u << TILE_LOG)

struct HeadArgs { ulong rows; uint log_n; uint log_src; uint mode; uint max_log; ulong q; ulong scale; uint apply_scale; uint pad0; };

inline ulong head_input(uint mode, device const ulong *src, device const ulong *pads, device const ulong *pows,
                        ulong r, ulong i, uint log_n, uint log_src, ulong q) {
    if (mode == 0u) {
        return src[(r << log_n) + i];
    }
    ulong ns = 1UL << log_src;
    if (mode == 1u) {
        return i < ns ? src[(r << log_src) + i] : 0UL;
    }
    // mode 2: encode_buffer.rs initialize_row
    device const ulong *pad = pads + r * q;
    if (i < ns) {
        ulong c = src[(r << log_src) + i];
        return gl_mul(i < q ? gl_sub(c, pad[i]) : c, pows[i]);
    } else if (i < ns + q) {
        ulong j = i - ns;
        ulong v = (ns + j < q) ? gl_sub(pad[j], pad[ns + j]) : pad[j];
        return gl_mul(v, pows[i]);
    }
    return 0UL;
}

kernel void k_ntt_head(device const ulong *src [[buffer(0)]],
                       device const ulong *pads [[buffer(1)]],
                       device const ulong *pows [[buffer(2)]],
                       device ulong *dst [[buffer(3)]],
                       device const ulong *tw [[buffer(4)]],
                       constant HeadArgs &args [[buffer(5)]],
                       uint2 tid2 [[thread_position_in_threadgroup]],
                       uint2 nth2 [[threads_per_threadgroup]],
                       uint2 tg [[threadgroup_position_in_grid]]) {
    // all three as uint2 (MSL: thread attributes must share one vector width);
    // the threadgroups are one-dimensional
    uint tid = tid2.x;
    uint nth = nth2.x;
    threadgroup ulong sh[TILE];
    uint L = min(args.log_n, TILE_LOG);
    uint tile = 1u << L;
    ulong r = ulong(tg.y);
    ulong base = ulong(tg.x) << L;
    for (uint k = tid; k < tile; k += nth) {
        ulong g = base + ulong(k);
        sh[k] = head_input(args.mode, src, pads, pows, r, rev_bits(g, args.log_n), args.log_n, args.log_src, args.q);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = 1; s <= L; s++) {
        uint half_len = 1u << (s - 1);
        ulong stride = 1UL << (args.max_log - s);
        for (uint b = tid; b < (tile >> 1); b += nth) {
            uint grp = b >> (s - 1);
            uint k = b & (half_len - 1);
            uint i0 = (grp << s) + k;
            ulong w = tw[ulong(k) * stride];
            ulong u = sh[i0];
            ulong v = gl_mul(sh[i0 + half_len], w);
            sh[i0] = gl_add(u, v);
            sh[i0 + half_len] = gl_sub(u, v);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    device ulong *row = dst + (r << args.log_n) + base;
    for (uint k = tid; k < tile; k += nth) {
        ulong x = sh[k];
        row[k] = args.apply_scale != 0u ? gl_mul(x, args.scale) : x;
    }
}

struct TailArgs { ulong rows; uint log_n; uint max_log; ulong scale; uint apply_scale; uint pad0; };

kernel void k_ntt_tail(device ulong *a [[buffer(0)]],
                       device const ulong *tw [[buffer(1)]],
                       constant TailArgs &args [[buffer(2)]],
                       uint2 tid2 [[thread_position_in_threadgroup]],
                       uint2 nth2 [[threads_per_threadgroup]],
                       uint2 tg [[threadgroup_position_in_grid]]) {
    // all three as uint2 (MSL: thread attributes must share one vector width);
    // the threadgroups are one-dimensional
    uint tid = tid2.x;
    uint nth = nth2.x;
    threadgroup ulong sh[TILE];
    uint G = args.log_n - TILE_LOG;          // 1..11
    uint C = TILE >> G;                      // consecutive groups per threadgroup
    ulong low0 = ulong(tg.x) * ulong(C);
    device ulong *row = a + (ulong(tg.y) << args.log_n);
    for (uint t = tid; t < TILE; t += nth) {
        uint c = t % C;
        uint h = t / C;
        sh[h * C + c] = row[low0 + ulong(c) + (ulong(h) << TILE_LOG)];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = TILE_LOG + 1; s <= args.log_n; s++) {
        uint hs = s - TILE_LOG - 1;
        uint half_h = 1u << hs;
        ulong stride = 1UL << (args.max_log - s);
        for (uint b = tid; b < (TILE >> 1); b += nth) {
            uint c = b % C;
            uint hb = b / C;
            uint grp = hb >> hs;
            uint kh = hb & (half_h - 1);
            uint h0 = (grp << (hs + 1)) + kh;
            uint h1 = h0 + half_h;
            ulong k = low0 + ulong(c) + (ulong(kh) << TILE_LOG);
            ulong w = tw[k * stride];
            ulong u = sh[h0 * C + c];
            ulong v = gl_mul(sh[h1 * C + c], w);
            sh[h0 * C + c] = gl_add(u, v);
            sh[h1 * C + c] = gl_sub(u, v);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    for (uint t = tid; t < TILE; t += nth) {
        uint c = t % C;
        uint h = t / C;
        ulong x = sh[h * C + c];
        row[low0 + ulong(c) + (ulong(h) << TILE_LOG)] = args.apply_scale != 0u ? gl_mul(x, args.scale) : x;
    }
}

// --------------------------------------------------------------- row folds
// out[g][j] = sum_i rho_g[i] * src[i * nn + j * ir]  over Fp2 (rho in Fp2,
// src in Fp): zkp-core pcs.rs fold_rows_host. Fp2 values are (c0, c1) pairs of
// canonical u64; mul_base multiplies both coordinates. One thread per column j,
// up to 8 rho vectors at a time; zero entries are skipped exactly as the host
// skips them (field addition is exact, so the order is immaterial).

struct FoldArgs { ulong rows; ulong n; ulong nn; ulong ir; uint k; uint pad0; };

kernel void k_fold_rows(device const ulong *src [[buffer(0)]],
                        device const ulong *rho [[buffer(1)]],
                        device ulong *out [[buffer(2)]],
                        constant FoldArgs &args [[buffer(3)]],
                        uint gid [[thread_position_in_grid]]) {
    ulong j = ulong(gid);
    if (j >= args.n) { return; }
    uint k = args.k;
    ulong a0[8], a1[8];
    for (uint g = 0; g < 8; g++) { a0[g] = 0UL; a1[g] = 0UL; }
    for (ulong i = 0; i < args.rows; i++) {
        ulong v = src[i * args.nn + j * args.ir];
        if (v == 0UL) { continue; }
        for (uint g = 0; g < k; g++) {
            ulong o = (ulong(g) * args.rows + i) * 2UL;
            a0[g] = gl_add(a0[g], gl_mul(rho[o], v));
            a1[g] = gl_add(a1[g], gl_mul(rho[o + 1], v));
        }
    }
    for (uint g = 0; g < k; g++) {
        ulong o = (ulong(g) * args.n + j) * 2UL;
        out[o] = a0[g];
        out[o + 1] = a1[g];
    }
}

// The same fold with the rows split into blocks (gid.y = row block), so there
// are n x blocks threads instead of n; partial sums go to
// part[((b * k + g) * n + j) * 2 ...], then k_fold_reduce adds the blocks.
struct FoldPartArgs { ulong rows; ulong n; ulong nn; ulong ir; ulong rows_per_block; uint k; uint blocks; };

kernel void k_fold_partial(device const ulong *src [[buffer(0)]],
                           device const ulong *rho [[buffer(1)]],
                           device ulong *part [[buffer(2)]],
                           constant FoldPartArgs &args [[buffer(3)]],
                           uint2 gid [[thread_position_in_grid]]) {
    ulong j = ulong(gid.x);
    uint b = gid.y;
    if (j >= args.n || b >= args.blocks) { return; }
    uint k = args.k;
    ulong a0[8], a1[8];
    for (uint g = 0; g < 8; g++) { a0[g] = 0UL; a1[g] = 0UL; }
    ulong i0 = ulong(b) * args.rows_per_block;
    ulong i1 = min(args.rows, i0 + args.rows_per_block);
    for (ulong i = i0; i < i1; i++) {
        ulong v = src[i * args.nn + j * args.ir];
        if (v == 0UL) { continue; }
        for (uint g = 0; g < k; g++) {
            ulong o = (ulong(g) * args.rows + i) * 2UL;
            a0[g] = gl_add(a0[g], gl_mul(rho[o], v));
            a1[g] = gl_add(a1[g], gl_mul(rho[o + 1], v));
        }
    }
    for (uint g = 0; g < k; g++) {
        ulong o = ((ulong(b) * k + g) * args.n + j) * 2UL;
        part[o] = a0[g];
        part[o + 1] = a1[g];
    }
}

kernel void k_fold_reduce(device const ulong *part [[buffer(0)]],
                          device ulong *out [[buffer(1)]],
                          constant FoldPartArgs &args [[buffer(2)]],
                          uint2 gid [[thread_position_in_grid]]) {
    ulong j = ulong(gid.x);
    uint g = gid.y;
    if (j >= args.n || g >= args.k) { return; }
    ulong s0 = 0UL, s1 = 0UL;
    for (uint b = 0; b < args.blocks; b++) {
        ulong o = ((ulong(b) * args.k + g) * args.n + j) * 2UL;
        s0 = gl_add(s0, part[o]);
        s1 = gl_add(s1, part[o + 1]);
    }
    ulong o = (ulong(g) * args.n + j) * 2UL;
    out[o] = s0;
    out[o + 1] = s1;
}

// --------------------------------------------------------- column gather
// out[c * rows + i] = enc[i * nn + idx[c]]  (the opened columns, contiguous)
struct GatherArgs { ulong rows; ulong nn; ulong nidx; };

kernel void k_gather_cols(device const ulong *enc [[buffer(0)]],
                          device const ulong *idx [[buffer(1)]],
                          device ulong *out [[buffer(2)]],
                          constant GatherArgs &args [[buffer(3)]],
                          uint2 gid [[thread_position_in_grid]]) {
    ulong c = ulong(gid.x);
    ulong i = ulong(gid.y);
    if (c >= args.nidx || i >= args.rows) { return; }
    out[c * args.rows + i] = enc[i * args.nn + idx[c]];
}

// ------------------------------------------------------------------ BLAKE3
// One thread hashes one column: the little-endian bytes of
// enc[0*nn + j], enc[1*nn + j], ..., enc[(rows-1)*nn + j] (pcs.rs
// hash_columns / hash_columns_keyed). The full BLAKE3 tree: 1024-byte chunks,
// 64-byte blocks, the chaining-value stack of the reference implementation,
// ROOT on the final compression, KEYED_HASH with the key as the IV.

constant uint B3_IV[8] = {0x6A09E667u, 0xBB67AE85u, 0x3C6EF372u, 0xA54FF53Au,
                          0x510E527Fu, 0x9B05688Cu, 0x1F83D9ABu, 0x5BE0CD19u};
constant uint B3_PERM[16] = {2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8};
constant uint CHUNK_START = 1u, CHUNK_END = 2u, PARENT = 4u, ROOT = 8u, KEYED_HASH = 16u;

inline uint rotr32(uint x, uint n) { return (x >> n) | (x << (32u - n)); }

inline void b3_g(thread uint *s, uint a, uint b, uint c, uint d, uint mx, uint my) {
    s[a] = s[a] + s[b] + mx; s[d] = rotr32(s[d] ^ s[a], 16u);
    s[c] = s[c] + s[d];      s[b] = rotr32(s[b] ^ s[c], 12u);
    s[a] = s[a] + s[b] + my; s[d] = rotr32(s[d] ^ s[a], 8u);
    s[c] = s[c] + s[d];      s[b] = rotr32(s[b] ^ s[c], 7u);
}

// the compression function; returns the first 8 words of the output
// (state[i] ^ state[i + 8]), which is both the chaining value and the
// first 32 output bytes of a ROOT compression with output counter 0
inline void b3_compress(thread const uint *cv, thread const uint *block, ulong counter,
                        uint block_len, uint flags, thread uint *out8) {
    uint s[16];
    for (uint i = 0; i < 8; i++) { s[i] = cv[i]; }
    s[8] = B3_IV[0]; s[9] = B3_IV[1]; s[10] = B3_IV[2]; s[11] = B3_IV[3];
    s[12] = uint(counter & 0xFFFFFFFFUL); s[13] = uint(counter >> 32);
    s[14] = block_len; s[15] = flags;
    uint m[16];
    for (uint i = 0; i < 16; i++) { m[i] = block[i]; }
    for (uint round = 0; round < 7; round++) {
        b3_g(s, 0, 4, 8, 12, m[0], m[1]);
        b3_g(s, 1, 5, 9, 13, m[2], m[3]);
        b3_g(s, 2, 6, 10, 14, m[4], m[5]);
        b3_g(s, 3, 7, 11, 15, m[6], m[7]);
        b3_g(s, 0, 5, 10, 15, m[8], m[9]);
        b3_g(s, 1, 6, 11, 12, m[10], m[11]);
        b3_g(s, 2, 7, 8, 13, m[12], m[13]);
        b3_g(s, 3, 4, 9, 14, m[14], m[15]);
        if (round < 6) {
            uint t[16];
            for (uint i = 0; i < 16; i++) { t[i] = m[B3_PERM[i]]; }
            for (uint i = 0; i < 16; i++) { m[i] = t[i]; }
        }
    }
    for (uint i = 0; i < 8; i++) { out8[i] = s[i] ^ s[i + 8]; }
}

// the 16 message words of block `blk` of chunk `chunk` of column j
inline void b3_load_block(device const ulong *enc, ulong rows, ulong nn, ulong j,
                          ulong chunk, uint blk, thread uint *w) {
    // element index of the block's first byte: (chunk * 1024 + blk * 64) / 8
    ulong e0 = chunk * 128UL + ulong(blk) * 8UL;
    for (uint t = 0; t < 8; t++) {
        ulong e = e0 + ulong(t);
        ulong v = e < rows ? enc[e * nn + j] : 0UL;
        w[2 * t] = uint(v & 0xFFFFFFFFUL);
        w[2 * t + 1] = uint(v >> 32);
    }
}

struct HashArgs { ulong rows; ulong nn; uint keyed; uint pad0; uint key[8]; };

#define B3_STACK 40

kernel void k_hash_cols(device const ulong *enc [[buffer(0)]],
                        device uint *leaves [[buffer(1)]],
                        constant HashArgs &args [[buffer(2)]],
                        uint gid [[thread_position_in_grid]]) {
    ulong j = ulong(gid);
    if (j >= args.nn) { return; }
    ulong rows = args.rows;
    ulong nn = args.nn;
    uint kw[8];
    uint base_flags = args.keyed != 0 ? KEYED_HASH : 0u;
    for (uint i = 0; i < 8; i++) { kw[i] = args.keyed != 0 ? args.key[i] : B3_IV[i]; }

    ulong total = rows * 8UL;                       // bytes in the column
    ulong n_chunks = (total + 1023UL) / 1024UL;     // >= 1 (rows >= 1)
    uint stack[B3_STACK * 8];
    uint sp = 0;
    uint block[16];
    uint cv[8];

    // every chunk but the last: its chaining value, merged into the stack
    for (ulong c = 0; c + 1 < n_chunks; c++) {
        for (uint i = 0; i < 8; i++) { cv[i] = kw[i]; }
        for (uint blk = 0; blk < 16; blk++) {      // a non-final chunk is full
            b3_load_block(enc, rows, nn, j, c, blk, block);
            uint fl = base_flags | (blk == 0 ? CHUNK_START : 0u) | (blk == 15 ? CHUNK_END : 0u);
            uint nxt[8];
            b3_compress(cv, block, c, 64u, fl, nxt);
            for (uint i = 0; i < 8; i++) { cv[i] = nxt[i]; }
        }
        ulong total_chunks = c + 1;
        while ((total_chunks & 1UL) == 0UL) {      // add_chunk_chaining_value
            sp -= 1;
            uint pb[16];
            for (uint i = 0; i < 8; i++) { pb[i] = stack[sp * 8 + i]; pb[8 + i] = cv[i]; }
            uint nxt[8];
            b3_compress(kw, pb, 0UL, 64u, base_flags | PARENT, nxt);
            for (uint i = 0; i < 8; i++) { cv[i] = nxt[i]; }
            total_chunks >>= 1;
        }
        for (uint i = 0; i < 8; i++) { stack[sp * 8 + i] = cv[i]; }
        sp += 1;
    }

    // the last chunk: compress all but its final block; keep the final block
    // as the pending "output" (input cv, block, counter, len, flags)
    ulong c = n_chunks - 1;
    ulong chunk_bytes = total - c * 1024UL;         // 1..1024
    uint n_blocks = uint((chunk_bytes + 63UL) / 64UL);
    for (uint i = 0; i < 8; i++) { cv[i] = kw[i]; }
    for (uint blk = 0; blk + 1 < n_blocks; blk++) {
        b3_load_block(enc, rows, nn, j, c, blk, block);
        uint fl = base_flags | (blk == 0 ? CHUNK_START : 0u);
        uint nxt[8];
        b3_compress(cv, block, c, 64u, fl, nxt);
        for (uint i = 0; i < 8; i++) { cv[i] = nxt[i]; }
    }
    uint last = n_blocks - 1;
    b3_load_block(enc, rows, nn, j, c, last, block);
    uint out_cv[8];
    for (uint i = 0; i < 8; i++) { out_cv[i] = cv[i]; }
    uint out_block[16];
    for (uint i = 0; i < 16; i++) { out_block[i] = block[i]; }
    ulong out_counter = c;
    uint out_len = uint(chunk_bytes - ulong(last) * 64UL);
    uint out_flags = base_flags | (last == 0 ? CHUNK_START : 0u) | CHUNK_END;

    // fold the stack from the top: output = parent(stack[i], cv(output))
    while (sp > 0) {
        uint ocv[8];
        b3_compress(out_cv, out_block, out_counter, out_len, out_flags, ocv);
        sp -= 1;
        for (uint i = 0; i < 8; i++) { out_block[i] = stack[sp * 8 + i]; out_block[8 + i] = ocv[i]; }
        for (uint i = 0; i < 8; i++) { out_cv[i] = kw[i]; }
        out_counter = 0UL;
        out_len = 64u;
        out_flags = base_flags | PARENT;
    }

    // the root: the pending output compressed with ROOT, output counter 0
    uint root[8];
    b3_compress(out_cv, out_block, 0UL, out_len, out_flags | ROOT, root);
    for (uint i = 0; i < 8; i++) { leaves[j * 8 + i] = root[i]; }
}
