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


inline ulong gl_neg_sc(ulong a) { return a == 0UL ? 0UL : GL_P - a; }
struct fp2 { ulong c0; ulong c1; };
inline fp2 f2(ulong a, ulong b) { fp2 r; r.c0 = a; r.c1 = b; return r; }
inline fp2 f2_add(fp2 a, fp2 b) { return f2(gl_add(a.c0, b.c0), gl_add(a.c1, b.c1)); }
inline fp2 f2_sub(fp2 a, fp2 b) { return f2(gl_sub(a.c0, b.c0), gl_sub(a.c1, b.c1)); }
inline fp2 f2_neg(fp2 a) { return f2(gl_neg_sc(a.c0), gl_neg_sc(a.c1)); }
// Fp2::mul: (a0 + a1 u)(b0 + b1 u), u^2 = 7. [M4e] Karatsuba: three base
// products, the cross term as (a0 + a1)(b0 + b1) - ac - bd, and 7 bd as
// 8 bd - bd by doublings: the same field elements as Fp2::mul (exact
// arithmetic, every operation returns the canonical word), two products fewer.
inline ulong gl_mul7(ulong x) { ulong x2 = gl_add(x, x); ulong x4 = gl_add(x2, x2); return gl_sub(gl_add(x4, x4), x); }
inline fp2 f2_mul(fp2 a, fp2 b) {
    ulong ac = gl_mul(a.c0, b.c0), bd = gl_mul(a.c1, b.c1);
    ulong cross = gl_mul(gl_add(a.c0, a.c1), gl_add(b.c0, b.c1));
    return f2(gl_add(ac, gl_mul7(bd)), gl_sub(gl_sub(cross, ac), bd));
}
inline fp2 CF(constant ulong *cf, uint i) { return f2(cf[2 * i], cf[2 * i + 1]); }
// [M3b] mixed operands: an extension value times / plus a base-field word
inline fp2 f2_mulb(fp2 a, ulong b) { return f2(gl_mul(a.c0, b), gl_mul(a.c1, b)); }
inline fp2 f2_addb(fp2 a, ulong b) { return f2(gl_add(a.c0, b), a.c1); }
// [M4e] a table's value at point d of the pair's line (lo at 0, hi at 1,
// lo + d (hi - lo) beyond: what the CPU reaches by adding the step d times)
inline ulong ln_base(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    ulong l = tabs[lo];
    if (d == 0u) { return l; }
    ulong h = tabs[hi];
    if (d == 1u) { return h; }
    return gl_add(l, gl_mul(gl_sub(h, l), dd));
}
inline fp2 ln_ext(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    fp2 l = f2(tabs[lo], tabs[lo + 1]);
    if (d == 0u) { return l; }
    fp2 h = f2(tabs[hi], tabs[hi + 1]);
    if (d == 1u) { return h; }
    return f2_add(l, f2_mulb(f2_sub(h, l), dd));
}

#define SC_K 29
#define SC_D 5
// slot 18 (14 F zero-check (hosts 13G, 13U)) at hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2: 29 tables (18 base), 37 nodes, 3 terms
struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };
#ifndef SC_DE
#define SC_DE SC_D
#endif
kernel void k_sc_round0(device const ulong *tabs [[buffer(0)]],
                       device ulong *part [[buffer(1)]],
                       constant ulong *cf [[buffer(2)]],
                       constant RoundArgs &a [[buffer(3)]],
                       uint tid [[thread_position_in_grid]]) {
    uint np = a.eval_one != 0u ? SC_DE + 1u : SC_DE;
    uint grp = tid >> 5;
    uint di = grp % np;
    uint d = (a.eval_one != 0u || di == 0u) ? di : di + 1u;
    uint gid = (grp / np) * 32u + (tid & 31u);
    if (gid >= a.nthreads) { return; }
    ulong dd = ulong(d);
    fp2 acc = f2(0UL, 0UL);
    if (d != 1u || a.eval_one != 0u) {
        for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {
            fp2 v0 = ln_ext(tabs, (0UL * a.cap + i) * 2UL, (0UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v1 = ln_ext(tabs, (1UL * a.cap + i) * 2UL, (1UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v2 = ln_ext(tabs, (2UL * a.cap + i) * 2UL, (2UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v3 = ln_base(tabs, (3UL * a.cap + i) * 2UL, (3UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v4 = ln_base(tabs, (4UL * a.cap + i) * 2UL, (4UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v5 = ln_base(tabs, (5UL * a.cap + i) * 2UL, (5UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v6 = ln_base(tabs, (6UL * a.cap + i) * 2UL, (6UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v7 = ln_base(tabs, (7UL * a.cap + i) * 2UL, (7UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v8 = ln_base(tabs, (8UL * a.cap + i) * 2UL, (8UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v9 = ln_base(tabs, (9UL * a.cap + i) * 2UL, (9UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v10 = ln_base(tabs, (10UL * a.cap + i) * 2UL, (10UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v11 = ln_base(tabs, (11UL * a.cap + i) * 2UL, (11UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v12 = ln_base(tabs, (12UL * a.cap + i) * 2UL, (12UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v13 = ln_base(tabs, (13UL * a.cap + i) * 2UL, (13UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v14 = ln_base(tabs, (14UL * a.cap + i) * 2UL, (14UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v15 = ln_base(tabs, (15UL * a.cap + i) * 2UL, (15UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v16 = ln_base(tabs, (16UL * a.cap + i) * 2UL, (16UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v17 = ln_base(tabs, (17UL * a.cap + i) * 2UL, (17UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v18 = ln_base(tabs, (18UL * a.cap + i) * 2UL, (18UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v19 = ln_ext(tabs, (19UL * a.cap + i) * 2UL, (19UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v20 = ln_ext(tabs, (20UL * a.cap + i) * 2UL, (20UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v21 = ln_ext(tabs, (21UL * a.cap + i) * 2UL, (21UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v22 = ln_ext(tabs, (22UL * a.cap + i) * 2UL, (22UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v23 = ln_ext(tabs, (23UL * a.cap + i) * 2UL, (23UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v24 = ln_ext(tabs, (24UL * a.cap + i) * 2UL, (24UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v25 = ln_ext(tabs, (25UL * a.cap + i) * 2UL, (25UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v26 = ln_ext(tabs, (26UL * a.cap + i) * 2UL, (26UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v27 = ln_base(tabs, (27UL * a.cap + i) * 2UL, (27UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v28 = ln_base(tabs, (28UL * a.cap + i) * 2UL, (28UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong n0 = gl_add(gl_add(cf[0u], gl_mul(cf[2u], v17)), gl_mul(cf[4u], v18));
            ulong n1 = gl_add(gl_add(gl_add(cf[6u], gl_mul(cf[8u], v14)), gl_mul(cf[10u], v15)), gl_mul(cf[12u], v16));
            ulong n2 = gl_add(gl_add(gl_add(gl_mul(v7, v8), gl_mul(cf[14u], v13)), gl_neg_sc(n0)), cf[16u]);
            ulong n3 = gl_add(gl_add(cf[18u], gl_mul(cf[20u], v9)), gl_mul(cf[22u], v10));
            ulong n4 = gl_add(gl_add(v8, cf[24u]), gl_neg_sc(n3));
            ulong n5 = gl_add(gl_add(v13, cf[26u]), gl_neg_sc(n1));
            fp2 n6 = f2_add(f2_add(f2_addb(CF(cf, 14u), gl_neg_sc(v3)), f2_mulb(CF(cf, 15u), v7)), f2_mulb(CF(cf, 16u), v27));
            fp2 n7 = f2_addb(f2_mul(v26, n6), gl_neg_sc(1UL));
            fp2 n8 = f2_add(f2_add(f2_mulb(CF(cf, 17u), n2), f2_mulb(CF(cf, 18u), n4)), f2_mulb(CF(cf, 19u), n5));
            fp2 n9 = f2_addb(CF(cf, 20u), gl_mul(cf[42u], v4));
            fp2 n10 = f2_addb(CF(cf, 22u), gl_mul(cf[46u], v5));
            fp2 n11 = f2_add(f2_add(f2_mul(f2_mul(v19, n9), n10), f2_neg(n9)), f2_neg(n10));
            fp2 n12 = f2_addb(CF(cf, 24u), gl_mul(cf[50u], v6));
            fp2 n13 = f2_addb(CF(cf, 26u), gl_mul(cf[54u], v6));
            fp2 n14 = f2_add(f2_add(f2_mul(f2_mul(v20, n12), n13), f2_neg(n12)), f2_neg(n13));
            fp2 n15 = f2_addb(CF(cf, 28u), gl_mul(cf[58u], v9));
            fp2 n16 = f2_addb(CF(cf, 30u), gl_mul(cf[62u], v10));
            fp2 n17 = f2_add(f2_add(f2_mul(f2_mul(v21, n15), n16), f2_neg(n15)), f2_neg(n16));
            fp2 n18 = f2_addb(CF(cf, 32u), gl_mul(cf[66u], v11));
            fp2 n19 = f2_addb(CF(cf, 34u), gl_mul(cf[70u], v12));
            fp2 n20 = f2_add(f2_add(f2_mul(f2_mul(v22, n18), n19), f2_neg(n18)), f2_neg(n19));
            fp2 n21 = f2_addb(CF(cf, 36u), gl_mul(cf[74u], v12));
            fp2 n22 = f2_addb(CF(cf, 38u), gl_mul(cf[78u], v14));
            fp2 n23 = f2_add(f2_add(f2_mul(f2_mul(v23, n21), n22), f2_neg(n21)), f2_neg(n22));
            fp2 n24 = f2_addb(CF(cf, 40u), gl_mul(cf[82u], v15));
            fp2 n25 = f2_addb(CF(cf, 42u), gl_mul(cf[86u], v16));
            fp2 n26 = f2_add(f2_add(f2_mul(f2_mul(v24, n24), n25), f2_neg(n24)), f2_neg(n25));
            fp2 n27 = f2_addb(CF(cf, 44u), gl_mul(cf[90u], v17));
            fp2 n28 = f2_addb(CF(cf, 46u), gl_mul(cf[94u], v18));
            fp2 n29 = f2_add(f2_add(f2_mul(f2_mul(v25, n27), n28), f2_neg(n27)), f2_neg(n28));
            ulong n30 = gl_add(1UL, gl_neg_sc(v28));
            fp2 n31 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_addb(f2_mulb(CF(cf, 50u), v4), gl_add(cf[96u], gl_mul(cf[98u], v3))), f2_mulb(CF(cf, 51u), v5)), f2_mulb(CF(cf, 52u), v6)), f2_mulb(CF(cf, 53u), v7)), f2_mulb(CF(cf, 54u), v8)), f2_mulb(CF(cf, 55u), v9)), f2_mulb(CF(cf, 56u), v10)), f2_mulb(CF(cf, 57u), v11)), f2_mulb(CF(cf, 58u), v12)), f2_mulb(CF(cf, 59u), v13)), f2_mulb(CF(cf, 60u), v14)), f2_mulb(CF(cf, 61u), v15)), f2_mulb(CF(cf, 62u), v16)), f2_mulb(CF(cf, 63u), v17)), f2_mulb(CF(cf, 64u), v18));
            fp2 n32 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_mul(CF(cf, 65u), n11), f2_mul(CF(cf, 66u), n14)), f2_mul(CF(cf, 67u), n17)), f2_mul(CF(cf, 68u), n20)), f2_mul(CF(cf, 69u), n23)), f2_mul(CF(cf, 70u), n26)), f2_mul(CF(cf, 71u), n29)), f2_mul(CF(cf, 72u), n7)), f2_mul(f2_mulb(CF(cf, 73u), n30), n31)), f2_mulb(n8, v28));
            ulong n33 = gl_add(gl_add(gl_add(cf[148u], gl_mul(cf[150u], v4)), gl_mul(cf[152u], v5)), gl_mul(cf[154u], v6));
            ulong n34 = gl_add(gl_add(gl_mul(cf[156u], v3), n33), cf[158u]);
            ulong n35 = gl_add(gl_add(cf[160u], gl_mul(cf[162u], v11)), gl_mul(cf[164u], v12));
            ulong n36 = gl_add(gl_add(gl_mul(cf[166u], v8), n35), cf[168u]);
            fp2 out = f2(0UL, 0UL);
            out = f2_add(out, f2_mul(v0, n32));
            out = f2_add(out, f2_mulb(f2_mulb(f2_mul(CF(cf, 85u), v1), v28), n34));
            out = f2_add(out, f2_mulb(f2_mulb(f2_mul(CF(cf, 86u), v2), v28), n36));
            acc = f2_add(acc, out);
        }
    }
    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
    part[o] = acc.c0;
    part[o + 1] = acc.c1;
}

// slot 18 (14 F zero-check (hosts 13G, 13U)) at hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2: 29 tables (0 base), 37 nodes, 3 terms
#ifndef SC_DE
#define SC_DE SC_D
#endif
kernel void k_sc_round(device const ulong *tabs [[buffer(0)]],
                       device ulong *part [[buffer(1)]],
                       constant ulong *cf [[buffer(2)]],
                       constant RoundArgs &a [[buffer(3)]],
                       uint tid [[thread_position_in_grid]]) {
    uint np = a.eval_one != 0u ? SC_DE + 1u : SC_DE;
    uint grp = tid >> 5;
    uint di = grp % np;
    uint d = (a.eval_one != 0u || di == 0u) ? di : di + 1u;
    uint gid = (grp / np) * 32u + (tid & 31u);
    if (gid >= a.nthreads) { return; }
    ulong dd = ulong(d);
    fp2 acc = f2(0UL, 0UL);
    if (d != 1u || a.eval_one != 0u) {
        for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {
            fp2 v0 = ln_ext(tabs, (0UL * a.cap + i) * 2UL, (0UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v1 = ln_ext(tabs, (1UL * a.cap + i) * 2UL, (1UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v2 = ln_ext(tabs, (2UL * a.cap + i) * 2UL, (2UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v3 = ln_ext(tabs, (3UL * a.cap + i) * 2UL, (3UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v4 = ln_ext(tabs, (4UL * a.cap + i) * 2UL, (4UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v5 = ln_ext(tabs, (5UL * a.cap + i) * 2UL, (5UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v6 = ln_ext(tabs, (6UL * a.cap + i) * 2UL, (6UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v7 = ln_ext(tabs, (7UL * a.cap + i) * 2UL, (7UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v8 = ln_ext(tabs, (8UL * a.cap + i) * 2UL, (8UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v9 = ln_ext(tabs, (9UL * a.cap + i) * 2UL, (9UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v10 = ln_ext(tabs, (10UL * a.cap + i) * 2UL, (10UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v11 = ln_ext(tabs, (11UL * a.cap + i) * 2UL, (11UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v12 = ln_ext(tabs, (12UL * a.cap + i) * 2UL, (12UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v13 = ln_ext(tabs, (13UL * a.cap + i) * 2UL, (13UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v14 = ln_ext(tabs, (14UL * a.cap + i) * 2UL, (14UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v15 = ln_ext(tabs, (15UL * a.cap + i) * 2UL, (15UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v16 = ln_ext(tabs, (16UL * a.cap + i) * 2UL, (16UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v17 = ln_ext(tabs, (17UL * a.cap + i) * 2UL, (17UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v18 = ln_ext(tabs, (18UL * a.cap + i) * 2UL, (18UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v19 = ln_ext(tabs, (19UL * a.cap + i) * 2UL, (19UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v20 = ln_ext(tabs, (20UL * a.cap + i) * 2UL, (20UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v21 = ln_ext(tabs, (21UL * a.cap + i) * 2UL, (21UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v22 = ln_ext(tabs, (22UL * a.cap + i) * 2UL, (22UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v23 = ln_ext(tabs, (23UL * a.cap + i) * 2UL, (23UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v24 = ln_ext(tabs, (24UL * a.cap + i) * 2UL, (24UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v25 = ln_ext(tabs, (25UL * a.cap + i) * 2UL, (25UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v26 = ln_ext(tabs, (26UL * a.cap + i) * 2UL, (26UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v27 = ln_ext(tabs, (27UL * a.cap + i) * 2UL, (27UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v28 = ln_ext(tabs, (28UL * a.cap + i) * 2UL, (28UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 n0 = f2_add(f2_addb(f2_mulb(v17, cf[2u]), cf[0u]), f2_mulb(v18, cf[4u]));
            fp2 n1 = f2_add(f2_add(f2_addb(f2_mulb(v14, cf[8u]), cf[6u]), f2_mulb(v15, cf[10u])), f2_mulb(v16, cf[12u]));
            fp2 n2 = f2_addb(f2_add(f2_add(f2_mul(v7, v8), f2_mulb(v13, cf[14u])), f2_neg(n0)), cf[16u]);
            fp2 n3 = f2_add(f2_addb(f2_mulb(v9, cf[20u]), cf[18u]), f2_mulb(v10, cf[22u]));
            fp2 n4 = f2_add(f2_addb(v8, cf[24u]), f2_neg(n3));
            fp2 n5 = f2_add(f2_addb(v13, cf[26u]), f2_neg(n1));
            fp2 n6 = f2_add(f2_add(f2_add(CF(cf, 14u), f2_neg(v3)), f2_mul(CF(cf, 15u), v7)), f2_mul(CF(cf, 16u), v27));
            fp2 n7 = f2_addb(f2_mul(v26, n6), gl_neg_sc(1UL));
            fp2 n8 = f2_add(f2_add(f2_mul(CF(cf, 17u), n2), f2_mul(CF(cf, 18u), n4)), f2_mul(CF(cf, 19u), n5));
            fp2 n9 = f2_add(CF(cf, 20u), f2_mulb(v4, cf[42u]));
            fp2 n10 = f2_add(CF(cf, 22u), f2_mulb(v5, cf[46u]));
            fp2 n11 = f2_add(f2_add(f2_mul(f2_mul(v19, n9), n10), f2_neg(n9)), f2_neg(n10));
            fp2 n12 = f2_add(CF(cf, 24u), f2_mulb(v6, cf[50u]));
            fp2 n13 = f2_add(CF(cf, 26u), f2_mulb(v6, cf[54u]));
            fp2 n14 = f2_add(f2_add(f2_mul(f2_mul(v20, n12), n13), f2_neg(n12)), f2_neg(n13));
            fp2 n15 = f2_add(CF(cf, 28u), f2_mulb(v9, cf[58u]));
            fp2 n16 = f2_add(CF(cf, 30u), f2_mulb(v10, cf[62u]));
            fp2 n17 = f2_add(f2_add(f2_mul(f2_mul(v21, n15), n16), f2_neg(n15)), f2_neg(n16));
            fp2 n18 = f2_add(CF(cf, 32u), f2_mulb(v11, cf[66u]));
            fp2 n19 = f2_add(CF(cf, 34u), f2_mulb(v12, cf[70u]));
            fp2 n20 = f2_add(f2_add(f2_mul(f2_mul(v22, n18), n19), f2_neg(n18)), f2_neg(n19));
            fp2 n21 = f2_add(CF(cf, 36u), f2_mulb(v12, cf[74u]));
            fp2 n22 = f2_add(CF(cf, 38u), f2_mulb(v14, cf[78u]));
            fp2 n23 = f2_add(f2_add(f2_mul(f2_mul(v23, n21), n22), f2_neg(n21)), f2_neg(n22));
            fp2 n24 = f2_add(CF(cf, 40u), f2_mulb(v15, cf[82u]));
            fp2 n25 = f2_add(CF(cf, 42u), f2_mulb(v16, cf[86u]));
            fp2 n26 = f2_add(f2_add(f2_mul(f2_mul(v24, n24), n25), f2_neg(n24)), f2_neg(n25));
            fp2 n27 = f2_add(CF(cf, 44u), f2_mulb(v17, cf[90u]));
            fp2 n28 = f2_add(CF(cf, 46u), f2_mulb(v18, cf[94u]));
            fp2 n29 = f2_add(f2_add(f2_mul(f2_mul(v25, n27), n28), f2_neg(n27)), f2_neg(n28));
            fp2 n30 = f2_addb(f2_neg(v28), 1UL);
            fp2 n31 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_addb(f2_mulb(v3, cf[98u]), cf[96u]), f2_mul(CF(cf, 50u), v4)), f2_mul(CF(cf, 51u), v5)), f2_mul(CF(cf, 52u), v6)), f2_mul(CF(cf, 53u), v7)), f2_mul(CF(cf, 54u), v8)), f2_mul(CF(cf, 55u), v9)), f2_mul(CF(cf, 56u), v10)), f2_mul(CF(cf, 57u), v11)), f2_mul(CF(cf, 58u), v12)), f2_mul(CF(cf, 59u), v13)), f2_mul(CF(cf, 60u), v14)), f2_mul(CF(cf, 61u), v15)), f2_mul(CF(cf, 62u), v16)), f2_mul(CF(cf, 63u), v17)), f2_mul(CF(cf, 64u), v18));
            fp2 n32 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_mul(CF(cf, 65u), n11), f2_mul(CF(cf, 66u), n14)), f2_mul(CF(cf, 67u), n17)), f2_mul(CF(cf, 68u), n20)), f2_mul(CF(cf, 69u), n23)), f2_mul(CF(cf, 70u), n26)), f2_mul(CF(cf, 71u), n29)), f2_mul(CF(cf, 72u), n7)), f2_mul(f2_mul(CF(cf, 73u), n30), n31)), f2_mul(v28, n8));
            fp2 n33 = f2_add(f2_add(f2_addb(f2_mulb(v4, cf[150u]), cf[148u]), f2_mulb(v5, cf[152u])), f2_mulb(v6, cf[154u]));
            fp2 n34 = f2_addb(f2_add(f2_mulb(v3, cf[156u]), n33), cf[158u]);
            fp2 n35 = f2_add(f2_addb(f2_mulb(v11, cf[162u]), cf[160u]), f2_mulb(v12, cf[164u]));
            fp2 n36 = f2_addb(f2_add(f2_mulb(v8, cf[166u]), n35), cf[168u]);
            fp2 out = f2(0UL, 0UL);
            out = f2_add(out, f2_mul(v0, n32));
            out = f2_add(out, f2_mul(f2_mul(f2_mul(CF(cf, 85u), v1), v28), n34));
            out = f2_add(out, f2_mul(f2_mul(f2_mul(CF(cf, 86u), v2), v28), n36));
            acc = f2_add(acc, out);
        }
    }
    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
    part[o] = acc.c0;
    part[o + 1] = acc.c1;
}
