// [ZK60-GZC] the private block's slot 18 (SC_FZC, the f-cube zero-check)
// on the device: the round kernels. Compiled by NVRTC at first use, ONE
// variant per module, behind the field primitives of `kernels.cu` (the host
// prepends that file's primitive section verbatim, so the arithmetic is the
// same code). `hashline/src/gpu/fzc.rs` carries the parameter layout below,
// the canonical table order and `FzcDesc::eval`, the host mirror of
// `fzc_poly` that the tests compare against the slot's own closure
// (`private_block/argument.rs`, SC_FZC arm). Tables (Fp2, table-major, stride
// L): 0..2 eq(tau), eq(p_g), eq(p_u); 3..13 the A planes G8, RGL, A16, U16,
// UL0, UL1, H16, HL0, HL1, RH0, RH1; 14..18 the five U8 helpers; 19 the
// activation-pair helper; 20 the support indicator (SUPP only). Every value
// is the canonical representative of the closure's field element: the
// expressions below are the closure's polynomial rearranged by field
// identities only, and every sum is a field sum, so the round sums — hence
// the transcript and the proof bytes — are the CPU's.

// copied verbatim from kernels.cu (rung 3 / UPERF3-AH)
__device__ __forceinline__ f2 ld_f2(const u64* p, size_t i) { f2 r; r.c0 = p[2 * i]; r.c1 = p[2 * i + 1]; return r; }
__device__ __forceinline__ void st_f2(u64* p, size_t i, f2 v) { p[2 * i] = v.c0; p[2 * i + 1] = v.c1; }
__device__ __forceinline__ f2 prm_f2(const u64* prm, int at) { f2 r; r.c0 = prm[at]; r.c1 = prm[at + 1]; return r; }
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

#define FZ_THREADS 128
#define FZ_ALPHA 0
#define FZ_BETA 2
#define FZ_GACT 4
#define FZ_NU0 6
#define FZ_NU1 8
#define FZ_MU 10
#define FZ_MUPAD 28
#define FZ_LKC 30
#define FZ_LKK 48
#define FZ_KH 57
#define FZ_KHH 58
#define FZ_KG 59
#define FZ_KGH 60
#define FZ_P1 61
#define FZ_PADW 62
#define FZ_LEN 84

__device__ __forceinline__ f2 f2_base(u64 c) { f2 r; r.c0 = c; r.c1 = 0ULL; return r; }

// alpha - (cst_k + coef_k * x): the U8 LogUp denominator of lookup k
__device__ __forceinline__ f2 fz_den(const u64* s, int k, f2 x, f2 alpha) {
    return f2_sub(alpha, f2_add(prm_f2(s, FZ_LKC + 2 * k), f2_mul_base(x, s[FZ_LKK + k])));
}
// mu * (h d1 d2 - d1 - d2): one paired U8 helper relation
__device__ __forceinline__ f2 fz_pair(f2 mu, f2 h, f2 d1, f2 d2) {
    return f2_mul(mu, f2_sub(f2_sub(f2_mul(f2_mul(h, d1), d2), d1), d2));
}

template <bool SUPP>
__device__ __forceinline__ f2 fzc_poly(const f2* v, const u64* s) {
    const f2 alpha = prm_f2(s, FZ_ALPHA);
    const f2 G8 = v[3], RGL = v[4], A16 = v[5], U16 = v[6], UL0 = v[7], UL1 = v[8], H16 = v[9], HL0 = v[10], HL1 = v[11], RH0 = v[12], RH1 = v[13];
    // the nine U8 denominators (lookup planes RGL RGL UL0 UL1 HL0 HL1 RH0 RH1 RH1)
    const f2 d0 = fz_den(s, 0, RGL, alpha), d1 = fz_den(s, 1, RGL, alpha);
    const f2 d2 = fz_den(s, 2, UL0, alpha), d3 = fz_den(s, 3, UL1, alpha);
    const f2 d4 = fz_den(s, 4, HL0, alpha), d5 = fz_den(s, 5, HL1, alpha);
    const f2 d6 = fz_den(s, 6, RH0, alpha), d7 = fz_den(s, 7, RH1, alpha);
    const f2 d8 = fz_den(s, 8, RH1, alpha);
    f2 zc = fz_pair(prm_f2(s, FZ_MU + 8), v[14], d0, d1);
    zc = f2_add(zc, fz_pair(prm_f2(s, FZ_MU + 10), v[15], d2, d3));
    zc = f2_add(zc, fz_pair(prm_f2(s, FZ_MU + 12), v[16], d4, d5));
    zc = f2_add(zc, fz_pair(prm_f2(s, FZ_MU + 14), v[17], d6, d7));
    zc = f2_add(zc, f2_mul(prm_f2(s, FZ_MU + 16), f2_sub(f2_mul(v[18], d8), f2_base(1ULL))));
    // the activation pair lookup (never gated)
    const f2 fact_den = f2_sub(alpha, f2_add(f2_add(f2_add(G8, f2_base(128ULL)), f2_mul(prm_f2(s, FZ_BETA), A16)), prm_f2(s, FZ_GACT)));
    zc = f2_add(zc, f2_mul(prm_f2(s, FZ_MU + 6), f2_sub(f2_mul(v[19], fact_den), f2_base(1ULL))));
    // the three gated clauses: the product and the two int16 decompositions
    const u64 p1 = s[FZ_P1];
    const f2 f0 = f2_add(f2_sub(f2_sub(f2_mul(A16, U16), f2_mul_base(H16, s[FZ_KH])), f2_add(RH0, f2_mul_base(RH1, p1))), f2_base(s[FZ_KHH]));
    const f2 f1 = f2_sub(f2_add(U16, f2_base(32768ULL)), f2_add(UL0, f2_mul_base(UL1, p1)));
    const f2 fh = f2_sub(f2_add(H16, f2_base(32768ULL)), f2_add(HL0, f2_mul_base(HL1, p1)));
    const f2 gated = f2_add(f2_add(f2_mul(prm_f2(s, FZ_MU + 0), f0), f2_mul(prm_f2(s, FZ_MU + 2), f1)), f2_mul(prm_f2(s, FZ_MU + 4), fh));
    // the two hosted matmul terms
    const f2 host_g = f2_sub(f2_add(f2_mul_base(G8, s[FZ_KG]), RGL), f2_base(s[FZ_KGH]));
    const f2 host = f2_add(f2_mul(f2_mul(prm_f2(s, FZ_NU0), v[1]), host_g), f2_mul(f2_mul(prm_f2(s, FZ_NU1), v[2]), U16));
    if (SUPP) {
        const f2 S = v[20];
        // the batched pad-zero term: mu_pad (1 - S) sum_j w_j A_j (w_j = 0 off the group)
        f2 lin = f2_zero();
        #pragma unroll
        for (int j = 0; j < 11; j++) lin = f2_add(lin, f2_mul(prm_f2(s, FZ_PADW + 2 * j), v[3 + j]));
        zc = f2_add(zc, f2_mul(f2_mul(prm_f2(s, FZ_MUPAD), f2_sub(f2_base(1ULL), S)), lin));
        zc = f2_add(zc, f2_mul(S, gated));
        return f2_add(f2_mul(v[0], zc), f2_mul(S, host));
    } else {
        zc = f2_add(zc, gated);
        return f2_add(f2_mul(v[0], zc), host);
    }
}

// The round: partial[block][d] = the block's sum of P over its pairs at d =
// 0..D (d = 1 skipped, left zero, unless `one`: the host recovers s(1) from
// the claim exactly as ClosureRounds::recover_one does).
template <int D, bool SUPP>
__device__ __forceinline__ void fzc_round_impl(const u64* __restrict__ tabs, int half, long long L, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    constexpr int K = SUPP ? 21 : 20;
    __shared__ u64 sp[FZ_LEN];
    __shared__ u64 red[FZ_THREADS * (D + 1) * 2];
    for (int i = threadIdx.x; i < FZ_LEN; i += blockDim.x) sp[i] = prm[i];
    __syncthreads();
    f2 acc[D + 1];
    #pragma unroll
    for (int d = 0; d <= D; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < half; i += gridDim.x * blockDim.x) {
        f2 cur[K], dif[K];
        #pragma unroll
        for (int t = 0; t < K; t++) {
            f2 v0 = ld_f2(tabs, (size_t)t * (size_t)L + i);
            f2 v1 = ld_f2(tabs, (size_t)t * (size_t)L + i + half);
            cur[t] = v0;
            dif[t] = f2_sub(v1, v0);
        }
        acc[0] = f2_add(acc[0], fzc_poly<SUPP>(cur, sp));
        #pragma unroll
        for (int d = 1; d <= D; d++) {
            #pragma unroll
            for (int t = 0; t < K; t++) cur[t] = f2_add(cur[t], dif[t]);
            if (d != 1 || one) acc[d] = f2_add(acc[d], fzc_poly<SUPP>(cur, sp));
        }
    }
    scg_emit<D + 1>(acc, red, partial);
}

// The FUSED fold + next round (v2): fold every table at r over the pre-fold
// half `hp` and evaluate the next round on the folded values in registers.
// Thread i < q = hp / 2 owns entries i, i + q, i + hp, i + q + hp of every
// table and writes the folded i and i + q (disjoint per thread: no race).
// The folded values are the k_sc_fold's (same expression); the round sums
// are fzc_round_impl's on the folded tables.
template <int D, bool SUPP>
__device__ __forceinline__ void fzc_fold_round_impl(u64* __restrict__ tabs, int hp, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    constexpr int K = SUPP ? 21 : 20;
    __shared__ u64 sp[FZ_LEN];
    __shared__ u64 red[FZ_THREADS * (D + 1) * 2];
    for (int i = threadIdx.x; i < FZ_LEN; i += blockDim.x) sp[i] = prm[i];
    __syncthreads();
    f2 r; r.c0 = r0; r.c1 = r1;
    const int q = hp >> 1;
    f2 acc[D + 1];
    #pragma unroll
    for (int d = 0; d <= D; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < q; i += gridDim.x * blockDim.x) {
        f2 cur[K], dif[K];
        #pragma unroll
        for (int t = 0; t < K; t++) {
            const size_t base = (size_t)t * (size_t)L;
            f2 a0 = ld_f2(tabs, base + i), a1 = ld_f2(tabs, base + i + hp);
            f2 b0 = ld_f2(tabs, base + i + q), b1 = ld_f2(tabs, base + i + q + hp);
            f2 lo = f2_add(a0, f2_mul(r, f2_sub(a1, a0)));
            f2 hi = f2_add(b0, f2_mul(r, f2_sub(b1, b0)));
            st_f2(tabs, base + i, lo);
            st_f2(tabs, base + i + q, hi);
            cur[t] = lo;
            dif[t] = f2_sub(hi, lo);
        }
        acc[0] = f2_add(acc[0], fzc_poly<SUPP>(cur, sp));
        #pragma unroll
        for (int d = 1; d <= D; d++) {
            #pragma unroll
            for (int t = 0; t < K; t++) cur[t] = f2_add(cur[t], dif[t]);
            if (d != 1 || one) acc[d] = f2_add(acc[d], fzc_poly<SUPP>(cur, sp));
        }
    }
    scg_emit<D + 1>(acc, red, partial);
}


// ---------------------------------------------------------------------------
// [ZK60-GZC] v3, THE LEAN EVALUATION OF THE SAME POLYNOMIAL. Same tables,
// same points, same field elements; only the arithmetic is reorganised:
//   * STAGED: each group of terms reads only its own tables, so a thread
//     holds per-point accumulators (zc, hs: 2 (D+1) Fp2) instead of all 21
//     tables' value/difference pairs (84 u64) — lower register pressure;
//   * LINEAR FORMS ARE STEPPED: every factor that is linear in the tables
//     (the nine U8 denominators, the l2 limb sums, the activation
//     denominator, the pad sum, the host term, mu x a table) is formed once
//     per pair at the pair's first point together with its difference and
//     advanced by one addition per point; only the products are evaluated
//     per point (17 Fp2 products per point instead of 41 plus 14 base);
//   * KARATSUBA Fp2 products (3 base products, 7x as additions).
// Exactness: every expression is a field identity of the closure's
// polynomial (distributivity, commutativity), so every round sum is the
// same canonical element. `fz_mulk` is f2_mul's value (c0 = ac + 7bd, c1 =
// ad + bc = (a+b)(c+d) - ac - bd mod p).

__device__ __forceinline__ f2 fz_mulk(f2 a, f2 b) {
    const u64 ac = gl_mul(a.c0, b.c0);
    const u64 bd = gl_mul(a.c1, b.c1);
    const u64 m = gl_mul(gl_add(a.c0, a.c1), gl_add(b.c0, b.c1));
    const u64 bd2 = gl_add(bd, bd);
    const u64 bd4 = gl_add(bd2, bd2);
    const u64 bd8 = gl_add(bd4, bd4);
    f2 r;
    r.c0 = gl_add(ac, gl_sub(bd8, bd));
    r.c1 = gl_sub(gl_sub(m, ac), bd);
    return r;
}
__device__ __forceinline__ f2 fz_neg(f2 a) { return f2_sub(f2_zero(), a); }

// (value at the pair's first point, difference) of table t: plain loads
// (never the non-coherent path: the fused kernel re-reads values it has just
// written in the same thread)
__device__ __forceinline__ void fz_ld(const u64* tabs, size_t L, int t, int i, int half, f2& v, f2& dv) {
    const size_t o = (size_t)t * L + (size_t)i;
    const f2 a = ld_f2(tabs, o);
    const f2 b = ld_f2(tabs, o + (size_t)half);
    v = a;
    dv = f2_sub(b, a);
}

template <int D, bool SUPP>
__device__ __forceinline__ void fz_lean_pair(const u64* tabs, size_t L, int i, int half, const u64* s, int one, f2* acc) {
    f2 zc[D + 1], hs[D + 1];
    #pragma unroll
    for (int d = 0; d <= D; d++) { zc[d] = f2_zero(); hs[d] = f2_zero(); }
    const f2 alpha = prm_f2(s, FZ_ALPHA);
    // ---- the five U8 helper relations (lookup planes, A positions: 1 1 4 5 7 8 9 10 10)
    #pragma unroll
    for (int k = 0; k < 5; k++) {
        const int p1 = (k == 0) ? 1 : (k == 1) ? 4 : (k == 2) ? 7 : (k == 3) ? 9 : 10;
        const int p2 = (k == 0) ? 1 : (k == 1) ? 5 : (k == 2) ? 8 : 10;
        const f2 mu = prm_f2(s, FZ_MU + 8 + 2 * k);
        f2 h, dh;
        fz_ld(tabs, L, 14 + k, i, half, h, dh);
        f2 mh = fz_mulk(mu, h), dmh = fz_mulk(mu, dh);
        f2 a1, da1;
        fz_ld(tabs, L, 3 + p1, i, half, a1, da1);
        const u64 c1 = s[FZ_LKK + 2 * k];
        f2 d1 = f2_sub(alpha, f2_add(prm_f2(s, FZ_LKC + 4 * k), f2_mul_base(a1, c1)));
        const f2 dd1 = fz_neg(f2_mul_base(da1, c1));
        if (k < 4) {
            f2 a2, da2;
            fz_ld(tabs, L, 3 + p2, i, half, a2, da2);
            const u64 c2 = s[FZ_LKK + 2 * k + 1];
            f2 d2 = f2_sub(alpha, f2_add(prm_f2(s, FZ_LKC + 4 * k + 2), f2_mul_base(a2, c2)));
            const f2 dd2 = fz_neg(f2_mul_base(da2, c2));
            f2 md = fz_mulk(mu, f2_add(d1, d2));
            const f2 dmd = fz_mulk(mu, f2_add(dd1, dd2));
            #pragma unroll
            for (int d = 0; d <= D; d++) {
                if (d) { mh = f2_add(mh, dmh); d1 = f2_add(d1, dd1); d2 = f2_add(d2, dd2); md = f2_add(md, dmd); }
                if (d == 1 && !one) continue;
                zc[d] = f2_add(zc[d], f2_sub(fz_mulk(fz_mulk(mh, d1), d2), md));
            }
        } else {
            #pragma unroll
            for (int d = 0; d <= D; d++) {
                if (d) { mh = f2_add(mh, dmh); d1 = f2_add(d1, dd1); }
                if (d == 1 && !one) continue;
                zc[d] = f2_add(zc[d], f2_sub(fz_mulk(mh, d1), mu));
            }
        }
    }
    // ---- the activation pair: mu3 (HF FD - 1), FD = alpha - (G8 + 128 + beta A16 + g_act)
    {
        const f2 mu3 = prm_f2(s, FZ_MU + 6), beta = prm_f2(s, FZ_BETA);
        f2 hf, dhf, g8, dg8, a16, da16;
        fz_ld(tabs, L, 19, i, half, hf, dhf);
        fz_ld(tabs, L, 3, i, half, g8, dg8);
        fz_ld(tabs, L, 5, i, half, a16, da16);
        f2 mhf = fz_mulk(mu3, hf);
        const f2 dmhf = fz_mulk(mu3, dhf);
        f2 fd = f2_sub(alpha, f2_add(f2_add(f2_add(g8, f2_base(128ULL)), fz_mulk(beta, a16)), prm_f2(s, FZ_GACT)));
        const f2 dfd = fz_neg(f2_add(dg8, fz_mulk(beta, da16)));
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { mhf = f2_add(mhf, dmhf); fd = f2_add(fd, dfd); }
            if (d == 1 && !one) continue;
            zc[d] = f2_add(zc[d], f2_sub(fz_mulk(mhf, fd), mu3));
        }
    }
    // ---- S and E0, needed by the gated, pad and final stages
    f2 sv = f2_zero(), dsv = f2_zero();
    if (SUPP) fz_ld(tabs, L, 20, i, half, sv, dsv);
    // ---- the pad term: mu_pad (1 - S) sum_j w_j A_j (skipping zero weights: a
    // warp-uniform test of a public parameter)
    if (SUPP) {
        f2 pl = f2_zero(), dpl = f2_zero();
        #pragma unroll
        for (int j = 0; j < 11; j++) {
            const f2 w = prm_f2(s, FZ_PADW + 2 * j);
            if ((w.c0 | w.c1) == 0ULL) continue;
            f2 a, da;
            fz_ld(tabs, L, 3 + j, i, half, a, da);
            pl = f2_add(pl, fz_mulk(w, a));
            dpl = f2_add(dpl, fz_mulk(w, da));
        }
        const f2 mp = prm_f2(s, FZ_MUPAD);
        pl = fz_mulk(mp, pl);
        const f2 dplm = fz_mulk(mp, dpl);
        f2 om = f2_sub(f2_base(1ULL), sv);
        const f2 dom = fz_neg(dsv);
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { pl = f2_add(pl, dplm); om = f2_add(om, dom); }
            if (d == 1 && !one) continue;
            zc[d] = f2_add(zc[d], fz_mulk(om, pl));
        }
    }
    // ---- the gated clauses: g (mu0 f0 + mu1 f1 + mu2 f2) = g (MA U16 + GL)
    {
        const u64 p1 = s[FZ_P1];
        const f2 mu0 = prm_f2(s, FZ_MU + 0), mu1 = prm_f2(s, FZ_MU + 2), mu2 = prm_f2(s, FZ_MU + 4);
        f2 a16, da16, u16, du16, h16, dh16, r0, dr0, r1, dr1, ul0, dul0, ul1, dul1, hl0, dhl0, hl1, dhl1;
        fz_ld(tabs, L, 5, i, half, a16, da16);
        fz_ld(tabs, L, 6, i, half, u16, du16);
        fz_ld(tabs, L, 9, i, half, h16, dh16);
        fz_ld(tabs, L, 12, i, half, r0, dr0);
        fz_ld(tabs, L, 13, i, half, r1, dr1);
        fz_ld(tabs, L, 7, i, half, ul0, dul0);
        fz_ld(tabs, L, 8, i, half, ul1, dul1);
        fz_ld(tabs, L, 10, i, half, hl0, dhl0);
        fz_ld(tabs, L, 11, i, half, hl1, dhl1);
        // f0's linear part, f1, f2 at the first point, and their differences
        const f2 f0l = f2_add(f2_sub(fz_neg(f2_mul_base(h16, s[FZ_KH])), f2_add(r0, f2_mul_base(r1, p1))), f2_base(s[FZ_KHH]));
        const f2 df0l = f2_sub(fz_neg(f2_mul_base(dh16, s[FZ_KH])), f2_add(dr0, f2_mul_base(dr1, p1)));
        const f2 f1 = f2_sub(f2_add(u16, f2_base(32768ULL)), f2_add(ul0, f2_mul_base(ul1, p1)));
        const f2 df1 = f2_sub(du16, f2_add(dul0, f2_mul_base(dul1, p1)));
        const f2 fh = f2_sub(f2_add(h16, f2_base(32768ULL)), f2_add(hl0, f2_mul_base(hl1, p1)));
        const f2 dfh = f2_sub(dh16, f2_add(dhl0, f2_mul_base(dhl1, p1)));
        f2 gl = f2_add(f2_add(fz_mulk(mu0, f0l), fz_mulk(mu1, f1)), fz_mulk(mu2, fh));
        const f2 dgl = f2_add(f2_add(fz_mulk(mu0, df0l), fz_mulk(mu1, df1)), fz_mulk(mu2, dfh));
        f2 ma = fz_mulk(mu0, a16);
        const f2 dma = fz_mulk(mu0, da16);
        f2 sg = sv;
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { gl = f2_add(gl, dgl); ma = f2_add(ma, dma); u16 = f2_add(u16, du16); if (SUPP) sg = f2_add(sg, dsv); }
            if (d == 1 && !one) continue;
            const f2 gated = f2_add(fz_mulk(ma, u16), gl);
            zc[d] = f2_add(zc[d], SUPP ? fz_mulk(sg, gated) : gated);
        }
    }
    // ---- the two hosted matmul terms: nu0 E1 (K_g G8 + RGL - K_g/2) + nu1 E2 U16
    {
        f2 e1, de1, e2, de2, g8, dg8, rg, drg, u16, du16;
        fz_ld(tabs, L, 1, i, half, e1, de1);
        fz_ld(tabs, L, 2, i, half, e2, de2);
        fz_ld(tabs, L, 3, i, half, g8, dg8);
        fz_ld(tabs, L, 4, i, half, rg, drg);
        fz_ld(tabs, L, 6, i, half, u16, du16);
        const f2 nu0 = prm_f2(s, FZ_NU0), nu1 = prm_f2(s, FZ_NU1);
        f2 n1 = fz_mulk(nu0, e1), n2 = fz_mulk(nu1, e2);
        const f2 dn1 = fz_mulk(nu0, de1), dn2 = fz_mulk(nu1, de2);
        f2 hg = f2_sub(f2_add(f2_mul_base(g8, s[FZ_KG]), rg), f2_base(s[FZ_KGH]));
        const f2 dhg = f2_add(f2_mul_base(dg8, s[FZ_KG]), drg);
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { n1 = f2_add(n1, dn1); n2 = f2_add(n2, dn2); hg = f2_add(hg, dhg); u16 = f2_add(u16, du16); }
            if (d == 1 && !one) continue;
            hs[d] = f2_add(fz_mulk(n1, hg), fz_mulk(n2, u16));
        }
    }
    // ---- the final combination: E0 zc + S hs
    {
        f2 e0, de0;
        fz_ld(tabs, L, 0, i, half, e0, de0);
        f2 sg = sv;
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { e0 = f2_add(e0, de0); if (SUPP) sg = f2_add(sg, dsv); }
            if (d == 1 && !one) continue;
            const f2 hpart = SUPP ? fz_mulk(sg, hs[d]) : hs[d];
            acc[d] = f2_add(acc[d], f2_add(fz_mulk(e0, zc[d]), hpart));
        }
    }
}

template <int D, bool SUPP>
__device__ __forceinline__ void fzl_round_impl(const u64* tabs, int half, long long L, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    __shared__ u64 sp[FZ_LEN];
    __shared__ u64 red[FZ_THREADS * (D + 1) * 2];
    for (int i = threadIdx.x; i < FZ_LEN; i += blockDim.x) sp[i] = prm[i];
    __syncthreads();
    f2 acc[D + 1];
    #pragma unroll
    for (int d = 0; d <= D; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < half; i += gridDim.x * blockDim.x)
        fz_lean_pair<D, SUPP>(tabs, (size_t)L, i, half, sp, one, acc);
    scg_emit<D + 1>(acc, red, partial);
}

// the fused form: the fold of every table first (the k_sc_fold expression,
// written in place: entries i and i + q), then the lean evaluation of the
// next round on the folded entries just written (same thread, plain loads)
template <int D, bool SUPP>
__device__ __forceinline__ void fzl_fold_round_impl(u64* tabs, int hp, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    constexpr int K = SUPP ? 21 : 20;
    __shared__ u64 sp[FZ_LEN];
    __shared__ u64 red[FZ_THREADS * (D + 1) * 2];
    for (int i = threadIdx.x; i < FZ_LEN; i += blockDim.x) sp[i] = prm[i];
    __syncthreads();
    f2 r; r.c0 = r0; r.c1 = r1;
    const int q = hp >> 1;
    f2 acc[D + 1];
    #pragma unroll
    for (int d = 0; d <= D; d++) acc[d] = f2_zero();
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < q; i += gridDim.x * blockDim.x) {
        #pragma unroll 3
        for (int t = 0; t < K; t++) {
            const size_t base = (size_t)t * (size_t)L;
            const f2 a0 = ld_f2(tabs, base + i), a1 = ld_f2(tabs, base + i + hp);
            const f2 b0 = ld_f2(tabs, base + i + q), b1 = ld_f2(tabs, base + i + q + hp);
            st_f2(tabs, base + i, f2_add(a0, fz_mulk(r, f2_sub(a1, a0))));
            st_f2(tabs, base + i + q, f2_add(b0, fz_mulk(r, f2_sub(b1, b0))));
        }
        fz_lean_pair<D, SUPP>(tabs, (size_t)L, i, q, sp, one, acc);
    }
    scg_emit<D + 1>(acc, red, partial);
}


// ---------------------------------------------------------------------------
// [ZK60-GZC] DIAGNOSIS AID (HL_GZC_WARM_MS, never on a proof's data path): a
// pure-arithmetic spin of `iters` dependent Goldilocks products per thread.
// It reads and writes no table (one word, only on an impossible value), so
// its duration measures the SM clock and nothing else.
extern "C" __global__ void k_fzc_spin(u64* out, int iters) {
    u64 x = (u64)threadIdx.x + 2ULL, y = (u64)blockIdx.x + 3ULL;
    for (int i = 0; i < iters; i++) { x = gl_mul(x, y); y = gl_add(y, x); }
    if (x == 0x123456789ULL && y == 0x987654321ULL) out[0] = x;
}

// ---------------------------------------------------------------------------
// The two entry points of this module: FZ_D (4 or 5), FZ_SUPP (0 or 1) and
// FZ_LEAN (0: v1/v2 direct evaluation, 1: v3 lean evaluation) are defined
// by the host in front of this source (cuda.rs `fzc_module`).
#if FZ_LEAN
extern "C" __global__ __launch_bounds__(FZ_THREADS) void k_fzc_round(const u64* tabs, int half, long long L, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    fzl_round_impl<FZ_D, (FZ_SUPP != 0)>(tabs, half, L, prm, one, partial);
}
extern "C" __global__ __launch_bounds__(FZ_THREADS) void k_fzc_fold_round(u64* tabs, int hp, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    fzl_fold_round_impl<FZ_D, (FZ_SUPP != 0)>(tabs, hp, L, r0, r1, prm, one, partial);
}
#else
extern "C" __global__ __launch_bounds__(FZ_THREADS, 1) void k_fzc_round(const u64* __restrict__ tabs, int half, long long L, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    fzc_round_impl<FZ_D, (FZ_SUPP != 0)>(tabs, half, L, prm, one, partial);
}
extern "C" __global__ __launch_bounds__(FZ_THREADS, 1) void k_fzc_fold_round(u64* __restrict__ tabs, int hp, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, int one, u64* __restrict__ partial) {
    fzc_fold_round_impl<FZ_D, (FZ_SUPP != 0)>(tabs, hp, L, r0, r1, prm, one, partial);
}
#endif
