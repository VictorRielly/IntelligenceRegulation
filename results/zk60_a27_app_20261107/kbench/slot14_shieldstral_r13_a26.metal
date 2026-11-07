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

#define SC_K 64
#define SC_D 5
// slot 14 (03 D zero-check (hosts 12, 13D)) at hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2: 64 tables (44 base), 83 nodes, 3 terms
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
            ulong v19 = ln_base(tabs, (19UL * a.cap + i) * 2UL, (19UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v20 = ln_base(tabs, (20UL * a.cap + i) * 2UL, (20UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v21 = ln_base(tabs, (21UL * a.cap + i) * 2UL, (21UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v22 = ln_base(tabs, (22UL * a.cap + i) * 2UL, (22UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v23 = ln_base(tabs, (23UL * a.cap + i) * 2UL, (23UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v24 = ln_base(tabs, (24UL * a.cap + i) * 2UL, (24UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v25 = ln_base(tabs, (25UL * a.cap + i) * 2UL, (25UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v26 = ln_base(tabs, (26UL * a.cap + i) * 2UL, (26UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v27 = ln_base(tabs, (27UL * a.cap + i) * 2UL, (27UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v28 = ln_base(tabs, (28UL * a.cap + i) * 2UL, (28UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v29 = ln_base(tabs, (29UL * a.cap + i) * 2UL, (29UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v30 = ln_base(tabs, (30UL * a.cap + i) * 2UL, (30UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v31 = ln_base(tabs, (31UL * a.cap + i) * 2UL, (31UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v32 = ln_base(tabs, (32UL * a.cap + i) * 2UL, (32UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v33 = ln_base(tabs, (33UL * a.cap + i) * 2UL, (33UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v34 = ln_base(tabs, (34UL * a.cap + i) * 2UL, (34UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v35 = ln_base(tabs, (35UL * a.cap + i) * 2UL, (35UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v36 = ln_base(tabs, (36UL * a.cap + i) * 2UL, (36UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v37 = ln_base(tabs, (37UL * a.cap + i) * 2UL, (37UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v38 = ln_base(tabs, (38UL * a.cap + i) * 2UL, (38UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v39 = ln_base(tabs, (39UL * a.cap + i) * 2UL, (39UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v40 = ln_base(tabs, (40UL * a.cap + i) * 2UL, (40UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v41 = ln_base(tabs, (41UL * a.cap + i) * 2UL, (41UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v42 = ln_base(tabs, (42UL * a.cap + i) * 2UL, (42UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v43 = ln_base(tabs, (43UL * a.cap + i) * 2UL, (43UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v44 = ln_base(tabs, (44UL * a.cap + i) * 2UL, (44UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v45 = ln_base(tabs, (45UL * a.cap + i) * 2UL, (45UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v46 = ln_ext(tabs, (46UL * a.cap + i) * 2UL, (46UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v47 = ln_ext(tabs, (47UL * a.cap + i) * 2UL, (47UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v48 = ln_ext(tabs, (48UL * a.cap + i) * 2UL, (48UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v49 = ln_ext(tabs, (49UL * a.cap + i) * 2UL, (49UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v50 = ln_ext(tabs, (50UL * a.cap + i) * 2UL, (50UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v51 = ln_ext(tabs, (51UL * a.cap + i) * 2UL, (51UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v52 = ln_ext(tabs, (52UL * a.cap + i) * 2UL, (52UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v53 = ln_ext(tabs, (53UL * a.cap + i) * 2UL, (53UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v54 = ln_ext(tabs, (54UL * a.cap + i) * 2UL, (54UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v55 = ln_ext(tabs, (55UL * a.cap + i) * 2UL, (55UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v56 = ln_ext(tabs, (56UL * a.cap + i) * 2UL, (56UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v57 = ln_ext(tabs, (57UL * a.cap + i) * 2UL, (57UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v58 = ln_ext(tabs, (58UL * a.cap + i) * 2UL, (58UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v59 = ln_ext(tabs, (59UL * a.cap + i) * 2UL, (59UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v60 = ln_ext(tabs, (60UL * a.cap + i) * 2UL, (60UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v61 = ln_ext(tabs, (61UL * a.cap + i) * 2UL, (61UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v62 = ln_ext(tabs, (62UL * a.cap + i) * 2UL, (62UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong v63 = ln_base(tabs, (63UL * a.cap + i) * 2UL, (63UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            ulong n0 = gl_add(gl_add(gl_add(cf[0u], gl_mul(cf[2u], v11)), gl_mul(cf[4u], v12)), gl_mul(cf[6u], v13));
            ulong n1 = gl_add(gl_add(gl_add(cf[8u], gl_mul(cf[10u], v14)), gl_mul(cf[12u], v15)), gl_mul(cf[14u], v16));
            ulong n2 = gl_add(gl_add(gl_add(cf[16u], gl_mul(cf[18u], v29)), gl_mul(cf[20u], v30)), gl_mul(cf[22u], v31));
            ulong n3 = gl_add(gl_add(gl_add(cf[24u], gl_mul(cf[26u], v32)), gl_mul(cf[28u], v33)), gl_mul(cf[30u], v34));
            ulong n4 = gl_add(gl_add(gl_add(gl_mul(gl_mul(cf[32u], v3), v5), gl_mul(cf[34u], v44)), gl_mul(gl_mul(cf[36u], v8), v44)), gl_neg_sc(n0));
            ulong n5 = gl_add(gl_add(gl_add(n0, n1), 1UL), gl_mul(cf[38u], v44));
            ulong n6 = gl_add(gl_add(cf[40u], gl_mul(cf[42u], v6)), gl_mul(cf[44u], v7));
            ulong n7 = gl_add(gl_add(v5, cf[46u]), gl_neg_sc(n6));
            ulong n8 = gl_add(gl_add(cf[48u], gl_mul(cf[50u], v9)), gl_mul(cf[52u], v10));
            ulong n9 = gl_add(gl_add(v8, cf[54u]), gl_neg_sc(n8));
            ulong n10 = gl_add(gl_add(cf[56u], gl_mul(cf[58u], v18)), gl_mul(cf[60u], v19));
            ulong n11 = gl_add(gl_add(v17, cf[62u]), gl_neg_sc(n10));
            ulong n12 = gl_add(gl_add(cf[64u], gl_mul(cf[66u], v24)), gl_mul(cf[68u], v25));
            ulong n13 = gl_add(gl_add(v23, cf[70u]), gl_neg_sc(n12));
            ulong n14 = gl_add(gl_add(v23, gl_neg_sc(v5)), gl_neg_sc(v17));
            ulong n15 = gl_add(gl_add(gl_add(gl_mul(gl_mul(cf[72u], v4), v23), gl_mul(cf[74u], v45)), gl_mul(gl_mul(cf[76u], v26), v45)), gl_neg_sc(n2));
            ulong n16 = gl_add(gl_add(gl_add(n2, n3), 1UL), gl_mul(cf[78u], v45));
            ulong n17 = gl_add(gl_add(cf[80u], gl_mul(cf[82u], v27)), gl_mul(cf[84u], v28));
            ulong n18 = gl_add(gl_add(v26, cf[86u]), gl_neg_sc(n17));
            ulong n19 = gl_add(gl_add(cf[88u], gl_mul(cf[90u], v36)), gl_mul(cf[92u], v37));
            ulong n20 = gl_add(gl_add(v35, cf[94u]), gl_neg_sc(n19));
            ulong n21 = gl_add(gl_add(cf[96u], gl_mul(cf[98u], v42)), gl_mul(cf[100u], v43));
            ulong n22 = gl_add(gl_add(v41, cf[102u]), gl_neg_sc(n21));
            ulong n23 = gl_add(gl_add(v41, gl_neg_sc(v23)), gl_neg_sc(v35));
            fp2 n24 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_mulb(CF(cf, 52u), n4), f2_mulb(CF(cf, 53u), n5)), f2_mulb(CF(cf, 54u), n7)), f2_mulb(CF(cf, 55u), n9)), f2_mulb(CF(cf, 56u), n11)), f2_mulb(CF(cf, 57u), n13)), f2_mulb(CF(cf, 58u), n14)), f2_mulb(CF(cf, 59u), n15)), f2_mulb(CF(cf, 60u), n16)), f2_mulb(CF(cf, 61u), n18)), f2_mulb(CF(cf, 62u), n20)), f2_mulb(CF(cf, 63u), n22)), f2_mulb(CF(cf, 64u), n23));
            fp2 n25 = f2_addb(CF(cf, 65u), gl_mul(cf[132u], v6));
            fp2 n26 = f2_addb(CF(cf, 67u), gl_mul(cf[136u], v7));
            fp2 n27 = f2_add(f2_add(f2_mul(f2_mul(v46, n25), n26), f2_neg(n25)), f2_neg(n26));
            fp2 n28 = f2_addb(CF(cf, 69u), gl_mul(cf[140u], v9));
            fp2 n29 = f2_addb(CF(cf, 71u), gl_mul(cf[144u], v10));
            fp2 n30 = f2_add(f2_add(f2_mul(f2_mul(v47, n28), n29), f2_neg(n28)), f2_neg(n29));
            fp2 n31 = f2_addb(CF(cf, 73u), gl_mul(cf[148u], v11));
            fp2 n32 = f2_addb(CF(cf, 75u), gl_mul(cf[152u], v12));
            fp2 n33 = f2_add(f2_add(f2_mul(f2_mul(v48, n31), n32), f2_neg(n31)), f2_neg(n32));
            fp2 n34 = f2_addb(CF(cf, 77u), gl_mul(cf[156u], v13));
            fp2 n35 = f2_addb(CF(cf, 79u), gl_mul(cf[160u], v14));
            fp2 n36 = f2_add(f2_add(f2_mul(f2_mul(v49, n34), n35), f2_neg(n34)), f2_neg(n35));
            fp2 n37 = f2_addb(CF(cf, 81u), gl_mul(cf[164u], v15));
            fp2 n38 = f2_addb(CF(cf, 83u), gl_mul(cf[168u], v16));
            fp2 n39 = f2_add(f2_add(f2_mul(f2_mul(v50, n37), n38), f2_neg(n37)), f2_neg(n38));
            fp2 n40 = f2_addb(CF(cf, 85u), gl_mul(cf[172u], v18));
            fp2 n41 = f2_addb(CF(cf, 87u), gl_mul(cf[176u], v19));
            fp2 n42 = f2_add(f2_add(f2_mul(f2_mul(v51, n40), n41), f2_neg(n40)), f2_neg(n41));
            fp2 n43 = f2_addb(CF(cf, 89u), gl_mul(cf[180u], v20));
            fp2 n44 = f2_addb(CF(cf, 91u), gl_mul(cf[184u], v21));
            fp2 n45 = f2_add(f2_add(f2_mul(f2_mul(v52, n43), n44), f2_neg(n43)), f2_neg(n44));
            fp2 n46 = f2_addb(CF(cf, 93u), gl_mul(cf[188u], v22));
            fp2 n47 = f2_addb(CF(cf, 95u), gl_mul(cf[192u], v22));
            fp2 n48 = f2_add(f2_add(f2_mul(f2_mul(v53, n46), n47), f2_neg(n46)), f2_neg(n47));
            fp2 n49 = f2_addb(CF(cf, 97u), gl_mul(cf[196u], v24));
            fp2 n50 = f2_addb(CF(cf, 99u), gl_mul(cf[200u], v25));
            fp2 n51 = f2_add(f2_add(f2_mul(f2_mul(v54, n49), n50), f2_neg(n49)), f2_neg(n50));
            fp2 n52 = f2_addb(CF(cf, 101u), gl_mul(cf[204u], v27));
            fp2 n53 = f2_addb(CF(cf, 103u), gl_mul(cf[208u], v28));
            fp2 n54 = f2_add(f2_add(f2_mul(f2_mul(v55, n52), n53), f2_neg(n52)), f2_neg(n53));
            fp2 n55 = f2_addb(CF(cf, 105u), gl_mul(cf[212u], v29));
            fp2 n56 = f2_addb(CF(cf, 107u), gl_mul(cf[216u], v30));
            fp2 n57 = f2_add(f2_add(f2_mul(f2_mul(v56, n55), n56), f2_neg(n55)), f2_neg(n56));
            fp2 n58 = f2_addb(CF(cf, 109u), gl_mul(cf[220u], v31));
            fp2 n59 = f2_addb(CF(cf, 111u), gl_mul(cf[224u], v32));
            fp2 n60 = f2_add(f2_add(f2_mul(f2_mul(v57, n58), n59), f2_neg(n58)), f2_neg(n59));
            fp2 n61 = f2_addb(CF(cf, 113u), gl_mul(cf[228u], v33));
            fp2 n62 = f2_addb(CF(cf, 115u), gl_mul(cf[232u], v34));
            fp2 n63 = f2_add(f2_add(f2_mul(f2_mul(v58, n61), n62), f2_neg(n61)), f2_neg(n62));
            fp2 n64 = f2_addb(CF(cf, 117u), gl_mul(cf[236u], v36));
            fp2 n65 = f2_addb(CF(cf, 119u), gl_mul(cf[240u], v37));
            fp2 n66 = f2_add(f2_add(f2_mul(f2_mul(v59, n64), n65), f2_neg(n64)), f2_neg(n65));
            fp2 n67 = f2_addb(CF(cf, 121u), gl_mul(cf[244u], v38));
            fp2 n68 = f2_addb(CF(cf, 123u), gl_mul(cf[248u], v39));
            fp2 n69 = f2_add(f2_add(f2_mul(f2_mul(v60, n67), n68), f2_neg(n67)), f2_neg(n68));
            fp2 n70 = f2_addb(CF(cf, 125u), gl_mul(cf[252u], v40));
            fp2 n71 = f2_addb(CF(cf, 127u), gl_mul(cf[256u], v40));
            fp2 n72 = f2_add(f2_add(f2_mul(f2_mul(v61, n70), n71), f2_neg(n70)), f2_neg(n71));
            fp2 n73 = f2_addb(CF(cf, 129u), gl_mul(cf[260u], v42));
            fp2 n74 = f2_addb(CF(cf, 131u), gl_mul(cf[264u], v43));
            fp2 n75 = f2_add(f2_add(f2_mul(f2_mul(v62, n73), n74), f2_neg(n73)), f2_neg(n74));
            ulong n76 = gl_add(1UL, gl_neg_sc(v63));
            fp2 n77 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_addb(f2_mulb(CF(cf, 135u), v6), gl_add(cf[266u], gl_mul(cf[268u], v5))), f2_mulb(CF(cf, 136u), v7)), f2_mulb(CF(cf, 137u), v8)), f2_mulb(CF(cf, 138u), v9)), f2_mulb(CF(cf, 139u), v10)), f2_mulb(CF(cf, 140u), v11)), f2_mulb(CF(cf, 141u), v12)), f2_mulb(CF(cf, 142u), v13)), f2_mulb(CF(cf, 143u), v14)), f2_mulb(CF(cf, 144u), v15)), f2_mulb(CF(cf, 145u), v16)), f2_mulb(CF(cf, 146u), v17)), f2_mulb(CF(cf, 147u), v18)), f2_mulb(CF(cf, 148u), v19)), f2_mulb(CF(cf, 149u), v20)), f2_mulb(CF(cf, 150u), v21)), f2_mulb(CF(cf, 151u), v22)), f2_mulb(CF(cf, 152u), v23)), f2_mulb(CF(cf, 153u), v24)), f2_mulb(CF(cf, 154u), v25)), f2_mulb(CF(cf, 155u), v26)), f2_mulb(CF(cf, 156u), v27)), f2_mulb(CF(cf, 157u), v28)), f2_mulb(CF(cf, 158u), v29)), f2_mulb(CF(cf, 159u), v30)), f2_mulb(CF(cf, 160u), v31)), f2_mulb(CF(cf, 161u), v32)), f2_mulb(CF(cf, 162u), v33)), f2_mulb(CF(cf, 163u), v34)), f2_mulb(CF(cf, 164u), v35)), f2_mulb(CF(cf, 165u), v36)), f2_mulb(CF(cf, 166u), v37)), f2_mulb(CF(cf, 167u), v38)), f2_mulb(CF(cf, 168u), v39)), f2_mulb(CF(cf, 169u), v40)), f2_mulb(CF(cf, 170u), v41)), f2_mulb(CF(cf, 171u), v42)), f2_mulb(CF(cf, 172u), v43));
            fp2 n78 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_mul(CF(cf, 173u), n27), f2_mul(CF(cf, 174u), n30)), f2_mul(CF(cf, 175u), n33)), f2_mul(CF(cf, 176u), n36)), f2_mul(CF(cf, 177u), n39)), f2_mul(CF(cf, 178u), n42)), f2_mul(CF(cf, 179u), n45)), f2_mul(CF(cf, 180u), n48)), f2_mul(CF(cf, 181u), n51)), f2_mul(CF(cf, 182u), n54)), f2_mul(CF(cf, 183u), n57)), f2_mul(CF(cf, 184u), n60)), f2_mul(CF(cf, 185u), n63)), f2_mul(CF(cf, 186u), n66)), f2_mul(CF(cf, 187u), n69)), f2_mul(CF(cf, 188u), n72)), f2_mul(CF(cf, 189u), n75)), f2_mul(f2_mulb(CF(cf, 190u), n76), n77)), f2_mulb(n24, v63));
            ulong n79 = gl_add(gl_add(gl_add(cf[382u], gl_mul(cf[384u], v20)), gl_mul(cf[386u], v21)), gl_mul(cf[388u], v22));
            ulong n80 = gl_add(gl_add(gl_mul(cf[390u], v17), n79), cf[392u]);
            ulong n81 = gl_add(gl_add(gl_add(cf[394u], gl_mul(cf[396u], v38)), gl_mul(cf[398u], v39)), gl_mul(cf[400u], v40));
            ulong n82 = gl_add(gl_add(gl_mul(cf[402u], v35), n81), cf[404u]);
            fp2 out = f2(0UL, 0UL);
            out = f2_add(out, f2_mul(v0, n78));
            out = f2_add(out, f2_mulb(f2_mulb(f2_mul(CF(cf, 203u), v1), v63), n80));
            out = f2_add(out, f2_mulb(f2_mulb(f2_mul(CF(cf, 204u), v2), v63), n82));
            acc = f2_add(acc, out);
        }
    }
    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
    part[o] = acc.c0;
    part[o + 1] = acc.c1;
}

// slot 14 (03 D zero-check (hosts 12, 13D)) at hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2: 64 tables (0 base), 83 nodes, 3 terms
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
            fp2 v29 = ln_ext(tabs, (29UL * a.cap + i) * 2UL, (29UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v30 = ln_ext(tabs, (30UL * a.cap + i) * 2UL, (30UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v31 = ln_ext(tabs, (31UL * a.cap + i) * 2UL, (31UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v32 = ln_ext(tabs, (32UL * a.cap + i) * 2UL, (32UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v33 = ln_ext(tabs, (33UL * a.cap + i) * 2UL, (33UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v34 = ln_ext(tabs, (34UL * a.cap + i) * 2UL, (34UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v35 = ln_ext(tabs, (35UL * a.cap + i) * 2UL, (35UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v36 = ln_ext(tabs, (36UL * a.cap + i) * 2UL, (36UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v37 = ln_ext(tabs, (37UL * a.cap + i) * 2UL, (37UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v38 = ln_ext(tabs, (38UL * a.cap + i) * 2UL, (38UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v39 = ln_ext(tabs, (39UL * a.cap + i) * 2UL, (39UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v40 = ln_ext(tabs, (40UL * a.cap + i) * 2UL, (40UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v41 = ln_ext(tabs, (41UL * a.cap + i) * 2UL, (41UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v42 = ln_ext(tabs, (42UL * a.cap + i) * 2UL, (42UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v43 = ln_ext(tabs, (43UL * a.cap + i) * 2UL, (43UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v44 = ln_ext(tabs, (44UL * a.cap + i) * 2UL, (44UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v45 = ln_ext(tabs, (45UL * a.cap + i) * 2UL, (45UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v46 = ln_ext(tabs, (46UL * a.cap + i) * 2UL, (46UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v47 = ln_ext(tabs, (47UL * a.cap + i) * 2UL, (47UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v48 = ln_ext(tabs, (48UL * a.cap + i) * 2UL, (48UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v49 = ln_ext(tabs, (49UL * a.cap + i) * 2UL, (49UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v50 = ln_ext(tabs, (50UL * a.cap + i) * 2UL, (50UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v51 = ln_ext(tabs, (51UL * a.cap + i) * 2UL, (51UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v52 = ln_ext(tabs, (52UL * a.cap + i) * 2UL, (52UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v53 = ln_ext(tabs, (53UL * a.cap + i) * 2UL, (53UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v54 = ln_ext(tabs, (54UL * a.cap + i) * 2UL, (54UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v55 = ln_ext(tabs, (55UL * a.cap + i) * 2UL, (55UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v56 = ln_ext(tabs, (56UL * a.cap + i) * 2UL, (56UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v57 = ln_ext(tabs, (57UL * a.cap + i) * 2UL, (57UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v58 = ln_ext(tabs, (58UL * a.cap + i) * 2UL, (58UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v59 = ln_ext(tabs, (59UL * a.cap + i) * 2UL, (59UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v60 = ln_ext(tabs, (60UL * a.cap + i) * 2UL, (60UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v61 = ln_ext(tabs, (61UL * a.cap + i) * 2UL, (61UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v62 = ln_ext(tabs, (62UL * a.cap + i) * 2UL, (62UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 v63 = ln_ext(tabs, (63UL * a.cap + i) * 2UL, (63UL * a.cap + i + a.nhalf) * 2UL, d, dd);
            fp2 n0 = f2_add(f2_add(f2_addb(f2_mulb(v11, cf[2u]), cf[0u]), f2_mulb(v12, cf[4u])), f2_mulb(v13, cf[6u]));
            fp2 n1 = f2_add(f2_add(f2_addb(f2_mulb(v14, cf[10u]), cf[8u]), f2_mulb(v15, cf[12u])), f2_mulb(v16, cf[14u]));
            fp2 n2 = f2_add(f2_add(f2_addb(f2_mulb(v29, cf[18u]), cf[16u]), f2_mulb(v30, cf[20u])), f2_mulb(v31, cf[22u]));
            fp2 n3 = f2_add(f2_add(f2_addb(f2_mulb(v32, cf[26u]), cf[24u]), f2_mulb(v33, cf[28u])), f2_mulb(v34, cf[30u]));
            fp2 n4 = f2_add(f2_add(f2_add(f2_mul(f2_mulb(v3, cf[32u]), v5), f2_mulb(v44, cf[34u])), f2_mul(f2_mulb(v8, cf[36u]), v44)), f2_neg(n0));
            fp2 n5 = f2_add(f2_addb(f2_add(n0, n1), 1UL), f2_mulb(v44, cf[38u]));
            fp2 n6 = f2_add(f2_addb(f2_mulb(v6, cf[42u]), cf[40u]), f2_mulb(v7, cf[44u]));
            fp2 n7 = f2_add(f2_addb(v5, cf[46u]), f2_neg(n6));
            fp2 n8 = f2_add(f2_addb(f2_mulb(v9, cf[50u]), cf[48u]), f2_mulb(v10, cf[52u]));
            fp2 n9 = f2_add(f2_addb(v8, cf[54u]), f2_neg(n8));
            fp2 n10 = f2_add(f2_addb(f2_mulb(v18, cf[58u]), cf[56u]), f2_mulb(v19, cf[60u]));
            fp2 n11 = f2_add(f2_addb(v17, cf[62u]), f2_neg(n10));
            fp2 n12 = f2_add(f2_addb(f2_mulb(v24, cf[66u]), cf[64u]), f2_mulb(v25, cf[68u]));
            fp2 n13 = f2_add(f2_addb(v23, cf[70u]), f2_neg(n12));
            fp2 n14 = f2_add(f2_add(v23, f2_neg(v5)), f2_neg(v17));
            fp2 n15 = f2_add(f2_add(f2_add(f2_mul(f2_mulb(v4, cf[72u]), v23), f2_mulb(v45, cf[74u])), f2_mul(f2_mulb(v26, cf[76u]), v45)), f2_neg(n2));
            fp2 n16 = f2_add(f2_addb(f2_add(n2, n3), 1UL), f2_mulb(v45, cf[78u]));
            fp2 n17 = f2_add(f2_addb(f2_mulb(v27, cf[82u]), cf[80u]), f2_mulb(v28, cf[84u]));
            fp2 n18 = f2_add(f2_addb(v26, cf[86u]), f2_neg(n17));
            fp2 n19 = f2_add(f2_addb(f2_mulb(v36, cf[90u]), cf[88u]), f2_mulb(v37, cf[92u]));
            fp2 n20 = f2_add(f2_addb(v35, cf[94u]), f2_neg(n19));
            fp2 n21 = f2_add(f2_addb(f2_mulb(v42, cf[98u]), cf[96u]), f2_mulb(v43, cf[100u]));
            fp2 n22 = f2_add(f2_addb(v41, cf[102u]), f2_neg(n21));
            fp2 n23 = f2_add(f2_add(v41, f2_neg(v23)), f2_neg(v35));
            fp2 n24 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_mul(CF(cf, 52u), n4), f2_mul(CF(cf, 53u), n5)), f2_mul(CF(cf, 54u), n7)), f2_mul(CF(cf, 55u), n9)), f2_mul(CF(cf, 56u), n11)), f2_mul(CF(cf, 57u), n13)), f2_mul(CF(cf, 58u), n14)), f2_mul(CF(cf, 59u), n15)), f2_mul(CF(cf, 60u), n16)), f2_mul(CF(cf, 61u), n18)), f2_mul(CF(cf, 62u), n20)), f2_mul(CF(cf, 63u), n22)), f2_mul(CF(cf, 64u), n23));
            fp2 n25 = f2_add(CF(cf, 65u), f2_mulb(v6, cf[132u]));
            fp2 n26 = f2_add(CF(cf, 67u), f2_mulb(v7, cf[136u]));
            fp2 n27 = f2_add(f2_add(f2_mul(f2_mul(v46, n25), n26), f2_neg(n25)), f2_neg(n26));
            fp2 n28 = f2_add(CF(cf, 69u), f2_mulb(v9, cf[140u]));
            fp2 n29 = f2_add(CF(cf, 71u), f2_mulb(v10, cf[144u]));
            fp2 n30 = f2_add(f2_add(f2_mul(f2_mul(v47, n28), n29), f2_neg(n28)), f2_neg(n29));
            fp2 n31 = f2_add(CF(cf, 73u), f2_mulb(v11, cf[148u]));
            fp2 n32 = f2_add(CF(cf, 75u), f2_mulb(v12, cf[152u]));
            fp2 n33 = f2_add(f2_add(f2_mul(f2_mul(v48, n31), n32), f2_neg(n31)), f2_neg(n32));
            fp2 n34 = f2_add(CF(cf, 77u), f2_mulb(v13, cf[156u]));
            fp2 n35 = f2_add(CF(cf, 79u), f2_mulb(v14, cf[160u]));
            fp2 n36 = f2_add(f2_add(f2_mul(f2_mul(v49, n34), n35), f2_neg(n34)), f2_neg(n35));
            fp2 n37 = f2_add(CF(cf, 81u), f2_mulb(v15, cf[164u]));
            fp2 n38 = f2_add(CF(cf, 83u), f2_mulb(v16, cf[168u]));
            fp2 n39 = f2_add(f2_add(f2_mul(f2_mul(v50, n37), n38), f2_neg(n37)), f2_neg(n38));
            fp2 n40 = f2_add(CF(cf, 85u), f2_mulb(v18, cf[172u]));
            fp2 n41 = f2_add(CF(cf, 87u), f2_mulb(v19, cf[176u]));
            fp2 n42 = f2_add(f2_add(f2_mul(f2_mul(v51, n40), n41), f2_neg(n40)), f2_neg(n41));
            fp2 n43 = f2_add(CF(cf, 89u), f2_mulb(v20, cf[180u]));
            fp2 n44 = f2_add(CF(cf, 91u), f2_mulb(v21, cf[184u]));
            fp2 n45 = f2_add(f2_add(f2_mul(f2_mul(v52, n43), n44), f2_neg(n43)), f2_neg(n44));
            fp2 n46 = f2_add(CF(cf, 93u), f2_mulb(v22, cf[188u]));
            fp2 n47 = f2_add(CF(cf, 95u), f2_mulb(v22, cf[192u]));
            fp2 n48 = f2_add(f2_add(f2_mul(f2_mul(v53, n46), n47), f2_neg(n46)), f2_neg(n47));
            fp2 n49 = f2_add(CF(cf, 97u), f2_mulb(v24, cf[196u]));
            fp2 n50 = f2_add(CF(cf, 99u), f2_mulb(v25, cf[200u]));
            fp2 n51 = f2_add(f2_add(f2_mul(f2_mul(v54, n49), n50), f2_neg(n49)), f2_neg(n50));
            fp2 n52 = f2_add(CF(cf, 101u), f2_mulb(v27, cf[204u]));
            fp2 n53 = f2_add(CF(cf, 103u), f2_mulb(v28, cf[208u]));
            fp2 n54 = f2_add(f2_add(f2_mul(f2_mul(v55, n52), n53), f2_neg(n52)), f2_neg(n53));
            fp2 n55 = f2_add(CF(cf, 105u), f2_mulb(v29, cf[212u]));
            fp2 n56 = f2_add(CF(cf, 107u), f2_mulb(v30, cf[216u]));
            fp2 n57 = f2_add(f2_add(f2_mul(f2_mul(v56, n55), n56), f2_neg(n55)), f2_neg(n56));
            fp2 n58 = f2_add(CF(cf, 109u), f2_mulb(v31, cf[220u]));
            fp2 n59 = f2_add(CF(cf, 111u), f2_mulb(v32, cf[224u]));
            fp2 n60 = f2_add(f2_add(f2_mul(f2_mul(v57, n58), n59), f2_neg(n58)), f2_neg(n59));
            fp2 n61 = f2_add(CF(cf, 113u), f2_mulb(v33, cf[228u]));
            fp2 n62 = f2_add(CF(cf, 115u), f2_mulb(v34, cf[232u]));
            fp2 n63 = f2_add(f2_add(f2_mul(f2_mul(v58, n61), n62), f2_neg(n61)), f2_neg(n62));
            fp2 n64 = f2_add(CF(cf, 117u), f2_mulb(v36, cf[236u]));
            fp2 n65 = f2_add(CF(cf, 119u), f2_mulb(v37, cf[240u]));
            fp2 n66 = f2_add(f2_add(f2_mul(f2_mul(v59, n64), n65), f2_neg(n64)), f2_neg(n65));
            fp2 n67 = f2_add(CF(cf, 121u), f2_mulb(v38, cf[244u]));
            fp2 n68 = f2_add(CF(cf, 123u), f2_mulb(v39, cf[248u]));
            fp2 n69 = f2_add(f2_add(f2_mul(f2_mul(v60, n67), n68), f2_neg(n67)), f2_neg(n68));
            fp2 n70 = f2_add(CF(cf, 125u), f2_mulb(v40, cf[252u]));
            fp2 n71 = f2_add(CF(cf, 127u), f2_mulb(v40, cf[256u]));
            fp2 n72 = f2_add(f2_add(f2_mul(f2_mul(v61, n70), n71), f2_neg(n70)), f2_neg(n71));
            fp2 n73 = f2_add(CF(cf, 129u), f2_mulb(v42, cf[260u]));
            fp2 n74 = f2_add(CF(cf, 131u), f2_mulb(v43, cf[264u]));
            fp2 n75 = f2_add(f2_add(f2_mul(f2_mul(v62, n73), n74), f2_neg(n73)), f2_neg(n74));
            fp2 n76 = f2_addb(f2_neg(v63), 1UL);
            fp2 n77 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_addb(f2_mulb(v5, cf[268u]), cf[266u]), f2_mul(CF(cf, 135u), v6)), f2_mul(CF(cf, 136u), v7)), f2_mul(CF(cf, 137u), v8)), f2_mul(CF(cf, 138u), v9)), f2_mul(CF(cf, 139u), v10)), f2_mul(CF(cf, 140u), v11)), f2_mul(CF(cf, 141u), v12)), f2_mul(CF(cf, 142u), v13)), f2_mul(CF(cf, 143u), v14)), f2_mul(CF(cf, 144u), v15)), f2_mul(CF(cf, 145u), v16)), f2_mul(CF(cf, 146u), v17)), f2_mul(CF(cf, 147u), v18)), f2_mul(CF(cf, 148u), v19)), f2_mul(CF(cf, 149u), v20)), f2_mul(CF(cf, 150u), v21)), f2_mul(CF(cf, 151u), v22)), f2_mul(CF(cf, 152u), v23)), f2_mul(CF(cf, 153u), v24)), f2_mul(CF(cf, 154u), v25)), f2_mul(CF(cf, 155u), v26)), f2_mul(CF(cf, 156u), v27)), f2_mul(CF(cf, 157u), v28)), f2_mul(CF(cf, 158u), v29)), f2_mul(CF(cf, 159u), v30)), f2_mul(CF(cf, 160u), v31)), f2_mul(CF(cf, 161u), v32)), f2_mul(CF(cf, 162u), v33)), f2_mul(CF(cf, 163u), v34)), f2_mul(CF(cf, 164u), v35)), f2_mul(CF(cf, 165u), v36)), f2_mul(CF(cf, 166u), v37)), f2_mul(CF(cf, 167u), v38)), f2_mul(CF(cf, 168u), v39)), f2_mul(CF(cf, 169u), v40)), f2_mul(CF(cf, 170u), v41)), f2_mul(CF(cf, 171u), v42)), f2_mul(CF(cf, 172u), v43));
            fp2 n78 = f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_add(f2_mul(CF(cf, 173u), n27), f2_mul(CF(cf, 174u), n30)), f2_mul(CF(cf, 175u), n33)), f2_mul(CF(cf, 176u), n36)), f2_mul(CF(cf, 177u), n39)), f2_mul(CF(cf, 178u), n42)), f2_mul(CF(cf, 179u), n45)), f2_mul(CF(cf, 180u), n48)), f2_mul(CF(cf, 181u), n51)), f2_mul(CF(cf, 182u), n54)), f2_mul(CF(cf, 183u), n57)), f2_mul(CF(cf, 184u), n60)), f2_mul(CF(cf, 185u), n63)), f2_mul(CF(cf, 186u), n66)), f2_mul(CF(cf, 187u), n69)), f2_mul(CF(cf, 188u), n72)), f2_mul(CF(cf, 189u), n75)), f2_mul(f2_mul(CF(cf, 190u), n76), n77)), f2_mul(v63, n24));
            fp2 n79 = f2_add(f2_add(f2_addb(f2_mulb(v20, cf[384u]), cf[382u]), f2_mulb(v21, cf[386u])), f2_mulb(v22, cf[388u]));
            fp2 n80 = f2_addb(f2_add(f2_mulb(v17, cf[390u]), n79), cf[392u]);
            fp2 n81 = f2_add(f2_add(f2_addb(f2_mulb(v38, cf[396u]), cf[394u]), f2_mulb(v39, cf[398u])), f2_mulb(v40, cf[400u]));
            fp2 n82 = f2_addb(f2_add(f2_mulb(v35, cf[402u]), n81), cf[404u]);
            fp2 out = f2(0UL, 0UL);
            out = f2_add(out, f2_mul(v0, n78));
            out = f2_add(out, f2_mul(f2_mul(f2_mul(CF(cf, 203u), v1), v63), n80));
            out = f2_add(out, f2_mul(f2_mul(f2_mul(CF(cf, 204u), v2), v63), n82));
            acc = f2_add(acc, out);
        }
    }
    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
    part[o] = acc.c0;
    part[o + 1] = acc.c1;
}
