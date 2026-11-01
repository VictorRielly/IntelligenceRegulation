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

struct HeadArgs { ulong rows; uint log_n; uint log_src; uint mode; uint max_log; ulong q; ulong scale; uint apply_scale; uint use_hw; };

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
                       device const ulong *hw [[buffer(6)]],
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
            // [M12] the same word from the compact table: tw[k << (max_log - s)]
            // = hw[k << (11 - s)], 8 KB of consecutive words
            ulong w = args.use_hw != 0u ? hw[ulong(k) << (TILE_LOG - s)] : tw[ulong(k) * stride];
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

// ------------------------------------------------- sumcheck table fold (M3)
// tab[t][i] = lo + r * (hi - lo) for i < half, every table t (zkp-core
// sumcheck/rounds.rs ClosureRounds::fold); tables are Fp2 (c0, c1) pairs, table
// t at [t * cap, t * cap + len).
inline ulong gl_neg(ulong a) { return a == 0UL ? 0UL : GL_P - a; }

struct FoldTabArgs { ulong nhalf; ulong cap; ulong k; ulong r0; ulong r1; };

kernel void k_fold_tables(device ulong *tabs [[buffer(0)]],
                          constant FoldTabArgs &args [[buffer(1)]],
                          uint2 gid [[thread_position_in_grid]]) {
    ulong i = ulong(gid.x);
    ulong t = ulong(gid.y);
    if (i >= args.nhalf || t >= args.k) { return; }
    ulong lo_i = (t * args.cap + i) * 2UL;
    ulong hi_i = (t * args.cap + i + args.nhalf) * 2UL;
    ulong l0 = tabs[lo_i], l1 = tabs[lo_i + 1];
    ulong d0 = gl_sub(tabs[hi_i], l0), d1 = gl_sub(tabs[hi_i + 1], l1);
    // r * d over Fp2 (u^2 = 7), as Fp2::mul
    ulong ac = gl_mul(args.r0, d0), bd = gl_mul(args.r1, d1);
    ulong ad = gl_mul(args.r0, d1), bc = gl_mul(args.r1, d0);
    ulong m0 = gl_add(ac, gl_mul(bd, 7UL));
    ulong m1 = gl_add(ad, bc);
    tabs[lo_i] = gl_add(l0, m0);
    tabs[lo_i + 1] = gl_add(l1, m1);
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

// ------------------------------------------- M6: the Fiat-Shamir step on the device
// zkp-core `transcript.rs` on one thread, byte for byte.
// - The message is at most one BLAKE3 chunk (1024 bytes): every block is
//   compressed with chunk counter 0, CHUNK_START on the first block, and
//   CHUNK_END | ROOT on the last; the key replaces the IV under KEYED_HASH.
// - absorb: BLAKE3(state || le64(|label|) || label || le64(|data|) || data)
// - squeeze: out = BLAKE3(state || "squeeze" || le64(counter)), and the state becomes out
// - challenge: Fp2(reduce(out[0..16]), reduce(out[16..32])), `Fp::from_u128`
inline void b3_hash_short(thread const uchar *msg, uint len, uint keyed, thread const uint *key, thread uint *out8) {
    uint cv[8];
    uint base = keyed != 0u ? KEYED_HASH : 0u;
    for (uint i = 0; i < 8; i++) { cv[i] = keyed != 0u ? key[i] : B3_IV[i]; }
    uint nblocks = len == 0u ? 1u : (len + 63u) / 64u;
    for (uint b = 0; b < nblocks; b++) {
        uint block[16];
        for (uint i = 0; i < 16; i++) { block[i] = 0u; }
        uint blen = len == 0u ? 0u : min(64u, len - 64u * b);
        for (uint i = 0; i < blen; i++) { block[i / 4u] |= uint(msg[64u * b + i]) << (8u * (i % 4u)); }
        uint fl = base | (b == 0u ? CHUNK_START : 0u) | (b == nblocks - 1u ? (CHUNK_END | ROOT) : 0u);
        uint nxt[8];
        b3_compress(cv, block, 0UL, blen, fl, nxt);
        for (uint i = 0; i < 8; i++) { cv[i] = nxt[i]; }
    }
    for (uint i = 0; i < 8; i++) { out8[i] = cv[i]; }
}

inline void put_le64(thread uchar *dst, ulong v) {
    for (uint i = 0; i < 8; i++) { dst[i] = uchar((v >> (8u * i)) & 0xFFUL); }
}

// absorb(b"sc-round", Fp2 values): `n` Fp2 words (c0, c1 interleaved) into `state` (8 words)
inline void fs_absorb_round(thread uint *state, thread const ulong *vals, uint n, uint keyed, thread const uint *key) {
    uchar msg[32 + 8 + 8 + 8 + 16 * 8];
    uint at = 0;
    for (uint i = 0; i < 8; i++) { for (uint b = 0; b < 4; b++) { msg[at++] = uchar((state[i] >> (8u * b)) & 0xFFu); } }
    put_le64(msg + at, 8UL); at += 8;
    uchar label[8] = {115, 99, 45, 114, 111, 117, 110, 100}; // "sc-round"
    for (uint i = 0; i < 8; i++) { msg[at++] = label[i]; }
    put_le64(msg + at, ulong(16u * n)); at += 8;
    for (uint i = 0; i < 2u * n; i++) { put_le64(msg + at, vals[i]); at += 8; }
    b3_hash_short(msg, at, keyed, key, state);
}

// squeeze + challenge_fp2: the new state, and the challenge (c0, c1)
inline void fs_challenge(thread uint *state, ulong counter, uint keyed, thread const uint *key, thread ulong *r) {
    uchar msg[32 + 7 + 8];
    uint at = 0;
    for (uint i = 0; i < 8; i++) { for (uint b = 0; b < 4; b++) { msg[at++] = uchar((state[i] >> (8u * b)) & 0xFFu); } }
    uchar sq[7] = {115, 113, 117, 101, 101, 122, 101}; // "squeeze"
    for (uint i = 0; i < 7; i++) { msg[at++] = sq[i]; }
    put_le64(msg + at, counter); at += 8;
    b3_hash_short(msg, at, keyed, key, state);
    r[0] = gl_reduce128(ulong(state[0]) | (ulong(state[1]) << 32), ulong(state[2]) | (ulong(state[3]) << 32));
    r[1] = gl_reduce128(ulong(state[4]) | (ulong(state[5]) << 32), ulong(state[6]) | (ulong(state[7]) << 32));
}

// TEST KERNEL: one round's absorb + challenge, as `Transcript::absorb_fp2(b"sc-round", ..)` then
// `challenge_fp2()`. io: [0..8) state words in and out, [8] counter, [9] keyed, [10..18) key words,
// [18] n, then 2n value words; out: [0..8) the new state, [8], [9] the challenge
struct FsTestArgs { uint n; uint keyed; ulong counter; };
kernel void k_fs_test(device const uint *st_in [[buffer(0)]],
                      device const uint *key_in [[buffer(1)]],
                      device const ulong *vals_in [[buffer(2)]],
                      device ulong *out [[buffer(3)]],
                      constant FsTestArgs &a [[buffer(4)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x != 0u) { return; }
    uint state[8], key[8];
    for (uint i = 0; i < 8; i++) { state[i] = st_in[i]; key[i] = key_in[i]; }
    ulong vals[16];
    for (uint i = 0; i < 2u * a.n && i < 16u; i++) { vals[i] = vals_in[i]; }
    fs_absorb_round(state, vals, a.n, a.keyed, key);
    ulong r[2];
    fs_challenge(state, a.counter, a.keyed, key, r);
    for (uint i = 0; i < 8; i++) { out[i] = ulong(state[i]); }
    out[8] = r[0];
    out[9] = r[1];
}

// ------------------------------------------- M6: a sumcheck round's transcript step on the device
// One round of zkp-core `prove_rounds` under the CFS masker, after the round kernel wrote its
// partials: reduce the partials to the unmasked round s(0..=D) (s(1) from the claim when the
// round recovers it), mask it (`CfsMasker::mask_round`: s + c g_j), absorb it as `sc-round`,
// squeeze the challenge r, and update the running terms (the claim s(r), sum_{i<j} u_i(r_i),
// prod_{i<j} r_i). The fold kernel below then reads r from `out`. The host replays every round
// through the real transcript afterwards and refuses the attempt on any difference.
//  fs:  [0..8) state words, [8..16) key words, [16] counter, [17] keyed, [18] recover_one,
//       [19..21) the unmasked claim, [21..23) sum_{i<j} u_i(r_i), [23..25) prod_{i<j} r_i
//  mk:  [0..2) c, [2..4) a', [4..4+d1) interpolation weights (base words), then per round j
//       2 (2 + d1 + D) words: 2^(n-1-j), a_0 + sum_{i>j} u_i(1)/2, u_j(0..=D), a_{j,1..=D}
//  out: per round j, 2 (2 d1 + 1) words: s(0..=D), the masked message, r
struct fq2 { ulong c0; ulong c1; };
inline fq2 q2(ulong a, ulong b) { fq2 r; r.c0 = a; r.c1 = b; return r; }
inline fq2 q2_add(fq2 a, fq2 b) { return q2(gl_add(a.c0, b.c0), gl_add(a.c1, b.c1)); }
inline fq2 q2_sub(fq2 a, fq2 b) { return q2(gl_sub(a.c0, b.c0), gl_sub(a.c1, b.c1)); }
// Fp2::mul (u^2 = 7), schoolbook: the same field element as any other form
inline fq2 q2_mul(fq2 a, fq2 b) {
    ulong ac = gl_mul(a.c0, b.c0), bd = gl_mul(a.c1, b.c1);
    ulong ad = gl_mul(a.c0, b.c1), bc = gl_mul(a.c1, b.c0);
    return q2(gl_add(ac, gl_mul(bd, 7UL)), gl_add(ad, bc));
}
inline fq2 q2_mulb(fq2 a, ulong b) { return q2(gl_mul(a.c0, b), gl_mul(a.c1, b)); }
inline fq2 q2_at(device const ulong *p, ulong w) { return q2(p[w], p[w + 1]); }

struct FsStepArgs { uint nthreads; uint d1; uint j; uint eval_one; uint tgw; uint pad0; };

kernel void k_sc_fs_step(device const ulong *part [[buffer(0)]],
                         device ulong *fs [[buffer(1)]],
                         device const ulong *mk [[buffer(2)]],
                         device ulong *out [[buffer(3)]],
                         constant FsStepArgs &a [[buffer(4)]],
                         uint t [[thread_position_in_threadgroup]]) {
    threadgroup ulong red[2 * 256];
    threadgroup ulong tot[16];
    uint d1 = a.d1;
    // the partial sums, point by point: a strided sum per thread, then a tree
    // (field addition is exact, so the grouping changes no value)
    for (uint d = 0; d < d1; d++) {
        fq2 acc = q2(0UL, 0UL);
        if (d != 1u || a.eval_one != 0u) {
            for (uint g = t; g < a.nthreads; g += a.tgw) { acc = q2_add(acc, q2_at(part, (ulong(g) * ulong(d1) + ulong(d)) * 2UL)); }
        }
        red[2u * t] = acc.c0;
        red[2u * t + 1u] = acc.c1;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        for (uint s = a.tgw / 2u; s > 0u; s >>= 1) {
            if (t < s) {
                red[2u * t] = gl_add(red[2u * t], red[2u * (t + s)]);
                red[2u * t + 1u] = gl_add(red[2u * t + 1u], red[2u * (t + s) + 1u]);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
        }
        if (t == 0u) { tot[2u * d] = red[0]; tot[2u * d + 1u] = red[1]; }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (t != 0u) { return; }
    uint D = d1 - 1u;
    fq2 s[8];
    for (uint d = 0; d < d1; d++) { s[d] = q2(tot[2u * d], tot[2u * d + 1u]); }
    fq2 claim = q2(fs[19], fs[20]);
    if (a.eval_one == 0u) { s[1] = q2_sub(claim, s[0]); }
    // the CFS mask's round message g_j(x) = 2^(n-1-j) (base + u_j(x)) + a' prod x
    ulong rec = 4UL + ulong(d1) + ulong(a.j) * 2UL * ulong(2u + d1 + D);
    fq2 c = q2_at(mk, 0UL), ap = q2_at(mk, 2UL);
    fq2 scale = q2_at(mk, rec), stat = q2_at(mk, rec + 2UL);
    fq2 pre = q2(fs[21], fs[22]), prod = q2(fs[23], fs[24]);
    fq2 base = q2_add(stat, pre);
    fq2 app = q2_mul(ap, prod);
    ulong vals[16];
    for (uint x = 0; x < d1; x++) {
        fq2 g = q2_add(q2_mul(scale, q2_add(base, q2_at(mk, rec + 4UL + 2UL * ulong(x)))), q2_mulb(app, ulong(x)));
        fq2 m = q2_add(s[x], q2_mul(c, g));
        vals[2u * x] = m.c0;
        vals[2u * x + 1u] = m.c1;
    }
    uint st[8], key[8];
    for (uint i = 0; i < 8; i++) { st[i] = uint(fs[i]); key[i] = uint(fs[8u + i]); }
    uint keyed = uint(fs[17]);
    fs_absorb_round(st, vals, d1, keyed, key);
    ulong rr[2];
    fs_challenge(st, fs[16], keyed, key, rr);
    fq2 r = q2(rr[0], rr[1]);
    // the running terms of the next round: u_j(r), the product, the claim s(r)
    fq2 uj = q2(0UL, 0UL), xp = q2(1UL, 0UL);
    for (uint e = 0; e < D; e++) {
        xp = q2_mul(xp, r);
        uj = q2_add(uj, q2_mul(q2_at(mk, rec + 4UL + 2UL * ulong(d1) + 2UL * ulong(e)), xp));
    }
    pre = q2_add(pre, uj);
    prod = q2_mul(prod, r);
    if (fs[18] != 0UL) {
        // zkp-core `mle::interpolate_eval` at r over the points 0..=D
        fq2 acc = q2(0UL, 0UL);
        for (uint i = 0; i < d1; i++) {
            fq2 num = q2(1UL, 0UL);
            for (uint m = 0; m < d1; m++) {
                if (m != i) { num = q2_mul(num, q2(gl_sub(r.c0, ulong(m)), r.c1)); }
            }
            acc = q2_add(acc, q2_mulb(q2_mul(s[i], num), mk[4u + i]));
        }
        claim = acc;
    }
    for (uint i = 0; i < 8; i++) { fs[i] = ulong(st[i]); }
    fs[16] = fs[16] + 1UL;
    fs[19] = claim.c0; fs[20] = claim.c1;
    fs[21] = pre.c0; fs[22] = pre.c1;
    fs[23] = prod.c0; fs[24] = prod.c1;
    ulong o = ulong(a.j) * 2UL * ulong(2u * d1 + 1u);
    for (uint d = 0; d < d1; d++) {
        out[o + 2UL * ulong(d)] = s[d].c0;
        out[o + 2UL * ulong(d) + 1UL] = s[d].c1;
        out[o + 2UL * ulong(d1 + d)] = vals[2u * d];
        out[o + 2UL * ulong(d1 + d) + 1UL] = vals[2u * d + 1u];
    }
    out[o + 4UL * ulong(d1)] = r.c0;
    out[o + 4UL * ulong(d1) + 1UL] = r.c1;
}

// k_fold_tables with the challenge read from device memory (`out` at word `roff`)
struct FoldDevArgs { ulong nhalf; ulong cap; ulong k; ulong roff; };

kernel void k_fold_tables_dev(device ulong *tabs [[buffer(0)]],
                              constant FoldDevArgs &args [[buffer(1)]],
                              device const ulong *rbuf [[buffer(2)]],
                              uint2 gid [[thread_position_in_grid]]) {
    ulong i = ulong(gid.x);
    ulong t = ulong(gid.y);
    if (i >= args.nhalf || t >= args.k) { return; }
    ulong r0 = rbuf[args.roff], r1 = rbuf[args.roff + 1UL];
    ulong lo_i = (t * args.cap + i) * 2UL;
    ulong hi_i = (t * args.cap + i + args.nhalf) * 2UL;
    ulong l0 = tabs[lo_i], l1 = tabs[lo_i + 1];
    ulong d0 = gl_sub(tabs[hi_i], l0), d1 = gl_sub(tabs[hi_i + 1], l1);
    ulong ac = gl_mul(r0, d0), bd = gl_mul(r1, d1);
    ulong ad = gl_mul(r0, d1), bc = gl_mul(r1, d0);
    ulong m0 = gl_add(ac, gl_mul(bd, 7UL));
    ulong m1 = gl_add(ad, bc);
    tabs[lo_i] = gl_add(l0, m0);
    tabs[lo_i + 1] = gl_add(l1, m1);
}

// [M6] the first stage of a large round's partial-sum reduction, across the whole GPU: thread w
// sums the partials w, w + width, ... of each point into part2[w]; the transcript step then
// reduces `width` entries instead of `nthreads` in one threadgroup. Point 1 is skipped (written
// as zero) when the round recovers s(1) from the claim. Field addition is exact: same sums.
struct PartRedArgs { uint nthreads; uint d1; uint width; uint eval_one; };

kernel void k_sc_part_reduce(device const ulong *part [[buffer(0)]],
                             device ulong *part2 [[buffer(1)]],
                             constant PartRedArgs &a [[buffer(2)]],
                             uint w [[thread_position_in_grid]]) {
    if (w >= a.width) { return; }
    for (uint d = 0; d < a.d1; d++) {
        ulong s0 = 0UL, s1 = 0UL;
        if (d != 1u || a.eval_one != 0u) {
            for (uint g = w; g < a.nthreads; g += a.width) {
                ulong o = (ulong(g) * ulong(a.d1) + ulong(d)) * 2UL;
                s0 = gl_add(s0, part[o]);
                s1 = gl_add(s1, part[o + 1UL]);
            }
        }
        ulong o2 = (ulong(w) * ulong(a.d1) + ulong(d)) * 2UL;
        part2[o2] = s0;
        part2[o2 + 1UL] = s1;
    }
}
