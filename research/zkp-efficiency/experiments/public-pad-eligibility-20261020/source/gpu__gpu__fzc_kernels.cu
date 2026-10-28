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
// [ZK60-GZC] v4, THE TERM-GROUP SPLIT (round 2, K1) WITH THE REDUCTION FOLDED
// INTO THE ROUND KERNEL (K3). Same tables, same points, same field elements.
// The slot polynomial is a SUM of independent groups, each closed under its
// own factor of E0 (or S):
//   P = sum_{k<4} (mu_{4+k} E0) (H_k d_2k d_2k+1 - d_2k - d_2k+1)   groups 0-3
//     + E0 (mu_8 (H_4 d_8 - 1) + mu_3 (HF FD - 1))                   group 4
//     + E0 mu_pad (1 - S) sum_j w_j A_j            (SUPP only)       group 5
//     + E0 S^[SUPP] (mu_0 f0 + mu_1 f1 + mu_2 f2)                    group 6
//     + S^[SUPP] (nu_0 E1 (K_g G8 + RGL - K_g/2) + nu_1 E2 U16)      group 7
// (= E0 zc + S hs, the lean form distributed over E0), so ONE WARP PER GROUP
// evaluates its group for 32 consecutive pairs and every group sums
// independently into the block reduction: <= 80 live registers instead of 255,
// and a serial chain per thread ~8x shorter. A block is 32 x NG threads
// (NG = 8 with the support indicator, 7 without: 3 blocks = 24 / 21 warps):
//   phase 1: the block loads (round 0) or FOLDS (fused rounds: the k_sc_fold
//     expression, written in place to i and i + q exactly as v2) every table
//     entry of its 32 pairs ONCE, coalesced, into shared memory as (value at
//     the pair's first point, difference);
//   phase 2: warp g evaluates group g at the points from shared memory.
// The block partials are summed by the LAST block to finish (threadfence +
// counter, the CUDA "threadFenceReduction" pattern) into `sums`, which the
// host copies into a page-locked buffer: one launch and one sync per round.
// Field sums are exact, so the order of every addition is irrelevant.
#define FZS_PAIRS 32

__device__ __forceinline__ void fzs_get(const u64* sv, const u64* sd, int t, int x, f2& v, f2& dv) {
    const int o = (t * FZS_PAIRS + x) * 2;
    v.c0 = sv[o]; v.c1 = sv[o + 1];
    dv.c0 = sd[o]; dv.c1 = sd[o + 1];
}

// A product of two linear forms a(d) = a + d da, b(d) = b + d db is the
// quadratic c0 + c1 d + c2 d^2 with c0 = a b, c1 = a db + da b, c2 = da db;
// terms accumulate into (c0, c1, c2). It is then STEPPED over d = 0, 1, ...
// by forward differences: p(0) = c0, dp(0) = c1 + c2, ddp = 2 c2,
// p(d+1) = p(d) + dp(d), dp(d+1) = dp(d) + ddp — exact identities of the
// polynomial, so every p(d) is the same field element as a direct product.
// Three live values per quadratic instead of two linear forms (four).
__device__ __forceinline__ void q2_term(f2& c0, f2& c1, f2& c2, f2 a, f2 da, f2 b, f2 db) {
    c0 = f2_add(c0, fz_mulk(a, b));
    c1 = f2_add(c1, f2_add(fz_mulk(a, db), fz_mulk(da, b)));
    c2 = f2_add(c2, fz_mulk(da, db));
}
__device__ __forceinline__ void q2_steps(f2 c0, f2 c1, f2 c2, f2& p, f2& dp, f2& ddp) {
    p = c0;
    dp = f2_add(c1, c2);
    ddp = f2_add(c2, c2);
}

// [round 3] the DERIVED tables, appended after the slot's own K0 tables
// (21 with the support indicator, 20 without), built once on the device
// from the others and folded with them (a fold is linear, so a derived
// table stays the same linear combination of the folded tables; the
// constant of an affine combination is a fixed point of every fold):
//   T_GL = K0:      mu0 f0l + mu1 f1 + mu2 f2 (the gated clauses' affine part)
//   T_PL = K0 + 1:  mu_pad sum_j w_j A_j       (the pad sum; SUPP only)
#define FZS_K0(SUPP) ((SUPP) ? 21 : 20)
#define FZS_KD(SUPP) ((SUPP) ? 23 : 21)

// A Fp2 linear form times a BASE linear form (b, db have c1 = 0 in round 0
// when the A planes and S are base-field, the host's BASE flag): the same
// quadratic coefficients as q2_term with two base products per Fp2 product.
__device__ __forceinline__ void q2_term_b(f2& c0, f2& c1, f2& c2, f2 a, f2 da, u64 b, u64 db) {
    c0 = f2_add(c0, f2_mul_base(a, b));
    c1 = f2_add(c1, f2_add(f2_mul_base(a, db), f2_mul_base(da, b)));
    c2 = f2_add(c2, f2_mul_base(da, db));
}

// group g of the pair in lane x, accumulated into acc[0..D] (d = 1 skipped
// unless ONE, as every other variant; ONE is a template parameter so the
// recovery rounds, which never evaluate s(1), carry no accumulator for it).
// BASE (round 0 only, decided by the host): tables 3..13 (the A planes) and
// table 20 (S) hold base-field values, so products with their linear forms
// use base multiplications; every value is the same field element.
template <int D, bool SUPP, bool ONE, bool BASE>
__device__ __forceinline__ void fzs_group(int g, const u64* sv, const u64* sd, int x, const u64* s, f2* acc) {
    constexpr int K0 = FZS_K0(SUPP);
    const f2 alpha = prm_f2(s, FZ_ALPHA);
    if (g < 4) {
        // a paired U8 helper: lookups 2g, 2g+1 on A positions (1,1) (4,5) (7,8) (9,10).
        // inner(d) = H d1 d2 - d1 - d2 is a CUBIC in d: evaluated directly at
        // d = 0..3 and stepped by forward differences (exact), then
        // (mu E0)(d) inner(d): one product per evaluated point
        const int p1 = (g == 0) ? 1 : (g == 1) ? 4 : (g == 2) ? 7 : 9;
        const int p2 = (g == 0) ? 1 : (g == 1) ? 5 : (g == 2) ? 8 : 10;
        f2 ip, idp, iddp, idddp;
        {
            f2 h, dh, t, dt;
            fzs_get(sv, sd, 14 + g, x, h, dh);
            fzs_get(sv, sd, 3 + p1, x, t, dt);
            const u64 c1 = s[FZ_LKK + 2 * g], c2 = s[FZ_LKK + 2 * g + 1];
            f2 d1 = f2_sub(alpha, f2_add(prm_f2(s, FZ_LKC + 4 * g), f2_mul_base(t, c1)));
            const f2 dd1 = fz_neg(f2_mul_base(dt, c1));
            fzs_get(sv, sd, 3 + p2, x, t, dt);
            f2 d2 = f2_sub(alpha, f2_add(prm_f2(s, FZ_LKC + 4 * g + 2), f2_mul_base(t, c2)));
            const f2 dd2 = fz_neg(f2_mul_base(dt, c2));
            // i(0), then the difference table built incrementally
            ip = f2_sub(f2_sub(fz_mulk(fz_mulk(h, d1), d2), d1), d2);
            h = f2_add(h, dh); d1 = f2_add(d1, dd1); d2 = f2_add(d2, dd2);
            const f2 i1 = f2_sub(f2_sub(fz_mulk(fz_mulk(h, d1), d2), d1), d2);
            idp = f2_sub(i1, ip);
            h = f2_add(h, dh); d1 = f2_add(d1, dd1); d2 = f2_add(d2, dd2);
            const f2 i2 = f2_sub(f2_sub(fz_mulk(fz_mulk(h, d1), d2), d1), d2);
            const f2 t2 = f2_sub(i2, i1);
            iddp = f2_sub(t2, idp);
            h = f2_add(h, dh); d1 = f2_add(d1, dd1); d2 = f2_add(d2, dd2);
            const f2 i3 = f2_sub(f2_sub(fz_mulk(fz_mulk(h, d1), d2), d1), d2);
            idddp = f2_sub(f2_sub(f2_sub(i3, i2), t2), iddp);
        }
        f2 e0, de0;
        fzs_get(sv, sd, 0, x, e0, de0);
        f2 em = fz_mulk(prm_f2(s, FZ_MU + 8 + 2 * g), e0);
        const f2 dem = fz_mulk(prm_f2(s, FZ_MU + 8 + 2 * g), de0);
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { em = f2_add(em, dem); ip = f2_add(ip, idp); idp = f2_add(idp, iddp); iddp = f2_add(iddp, idddp); }
            if (d == 1 && !ONE) continue;
            acc[d] = f2_add(acc[d], fz_mulk(em, ip));
        }
    } else if (g == 4) {
        // the single U8 helper (lookup 8 on RH1, A position 10) AND the
        // activation pair, which share E0:
        //   E0 (mu8 (H4 d8 - 1) + mu3 (HF FD - 1)),  FD = alpha - (G8 + 128 + beta A16 + g_act)
        // = E0 q(d), q = mh d8 + mhf FD - (mu8 + mu3) a quadratic in d (stepped)
        const f2 mu8 = prm_f2(s, FZ_MU + 16), mu3 = prm_f2(s, FZ_MU + 6);
        f2 c0 = fz_neg(f2_add(mu8, mu3)), c1 = f2_zero(), c2 = f2_zero();
        {
            f2 t, dt;
            fzs_get(sv, sd, 18, x, t, dt); // H4
            const f2 mh = fz_mulk(mu8, t), dmh = fz_mulk(mu8, dt);
            fzs_get(sv, sd, 13, x, t, dt); // RH1
            const u64 c = s[FZ_LKK + 8];
            const f2 d8 = f2_sub(alpha, f2_add(prm_f2(s, FZ_LKC + 16), f2_mul_base(t, c)));
            const f2 dd8 = fz_neg(f2_mul_base(dt, c));
            q2_term(c0, c1, c2, mh, dmh, d8, dd8);
        }
        {
            f2 t, dt;
            fzs_get(sv, sd, 19, x, t, dt); // HF
            const f2 mhf = fz_mulk(mu3, t), dmhf = fz_mulk(mu3, dt);
            fzs_get(sv, sd, 3, x, t, dt); // G8
            f2 fd = f2_sub(f2_sub(alpha, f2_add(t, f2_base(128ULL))), prm_f2(s, FZ_GACT));
            f2 dfd = fz_neg(dt);
            fzs_get(sv, sd, 5, x, t, dt); // A16
            if (BASE) {
                fd = f2_sub(fd, f2_mul_base(prm_f2(s, FZ_BETA), t.c0));
                dfd = f2_sub(dfd, f2_mul_base(prm_f2(s, FZ_BETA), dt.c0));
            } else {
                fd = f2_sub(fd, fz_mulk(prm_f2(s, FZ_BETA), t));
                dfd = f2_sub(dfd, fz_mulk(prm_f2(s, FZ_BETA), dt));
            }
            q2_term(c0, c1, c2, mhf, dmhf, fd, dfd);
        }
        f2 q, dq, ddq;
        q2_steps(c0, c1, c2, q, dq, ddq);
        f2 e0, de0;
        fzs_get(sv, sd, 0, x, e0, de0);
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { e0 = f2_add(e0, de0); q = f2_add(q, dq); dq = f2_add(dq, ddq); }
            if (d == 1 && !ONE) continue;
            acc[d] = f2_add(acc[d], fz_mulk(e0, q));
        }
    } else if (g == 5) {
        // the pad term (SUPP only): E0 q(d), q = (1 - S) PL, PL the derived table
        f2 c0 = f2_zero(), c1 = f2_zero(), c2 = f2_zero();
        {
            f2 pl, dpl, sv0, dsv;
            fzs_get(sv, sd, K0 + 1, x, pl, dpl);
            fzs_get(sv, sd, 20, x, sv0, dsv);
            if (BASE) q2_term_b(c0, c1, c2, pl, dpl, gl_sub(1ULL, sv0.c0), gl_sub(0ULL, dsv.c0));
            else q2_term(c0, c1, c2, f2_sub(f2_base(1ULL), sv0), fz_neg(dsv), pl, dpl);
        }
        f2 q, dq, ddq;
        q2_steps(c0, c1, c2, q, dq, ddq);
        f2 e0, de0;
        fzs_get(sv, sd, 0, x, e0, de0);
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { e0 = f2_add(e0, de0); q = f2_add(q, dq); dq = f2_add(dq, ddq); }
            if (d == 1 && !ONE) continue;
            acc[d] = f2_add(acc[d], fz_mulk(e0, q));
        }
    } else if (g == 6) {
        // the gated clauses: S^[SUPP] (mu0 A16 U16 + GL), GL the derived table;
        // B(d) = mu0 A16 U16 + GL is a quadratic in d
        f2 b0, b1, b2 = f2_zero();
        fzs_get(sv, sd, K0, x, b0, b1); // GL and its difference
        {
            const f2 mu0 = prm_f2(s, FZ_MU + 0);
            f2 a16, da16, u16, du16;
            fzs_get(sv, sd, 5, x, a16, da16);
            fzs_get(sv, sd, 6, x, u16, du16);
            if (BASE) {
                // A16 U16 = au + (a du + da u) d + da du d^2 in the base field, then times mu0
                const u64 a = a16.c0, da = da16.c0, u = u16.c0, du = du16.c0;
                b0 = f2_add(b0, f2_mul_base(mu0, gl_mul(a, u)));
                b1 = f2_add(b1, f2_mul_base(mu0, gl_add(gl_mul(a, du), gl_mul(da, u))));
                b2 = f2_mul_base(mu0, gl_mul(da, du));
            } else {
                q2_term(b0, b1, b2, fz_mulk(mu0, a16), fz_mulk(mu0, da16), u16, du16);
            }
        }
        f2 qb, dqb, ddqb;
        q2_steps(b0, b1, b2, qb, dqb, ddqb);
        f2 e0, de0;
        fzs_get(sv, sd, 0, x, e0, de0);
        if (SUPP) {
            // A(d) = E0 S, a second quadratic: the group is A(d) B(d)
            f2 sg, dsg, a0 = f2_zero(), a1 = f2_zero(), a2 = f2_zero();
            fzs_get(sv, sd, 20, x, sg, dsg);
            if (BASE) q2_term_b(a0, a1, a2, e0, de0, sg.c0, dsg.c0);
            else q2_term(a0, a1, a2, e0, de0, sg, dsg);
            f2 qa, dqa, ddqa;
            q2_steps(a0, a1, a2, qa, dqa, ddqa);
            #pragma unroll
            for (int d = 0; d <= D; d++) {
                if (d) { qa = f2_add(qa, dqa); dqa = f2_add(dqa, ddqa); qb = f2_add(qb, dqb); dqb = f2_add(dqb, ddqb); }
                if (d == 1 && !ONE) continue;
                acc[d] = f2_add(acc[d], fz_mulk(qa, qb));
            }
        } else {
            #pragma unroll
            for (int d = 0; d <= D; d++) {
                if (d) { e0 = f2_add(e0, de0); qb = f2_add(qb, dqb); dqb = f2_add(dqb, ddqb); }
                if (d == 1 && !ONE) continue;
                acc[d] = f2_add(acc[d], fz_mulk(e0, qb));
            }
        }
    } else {
        // the two hosted matmul terms (no E0): S^[SUPP] q(d),
        // q = (nu0 E1) HG + (nu1 E2) U16 a quadratic in d (HG, U16 base in BASE)
        f2 c0 = f2_zero(), c1 = f2_zero(), c2 = f2_zero();
        {
            f2 t, dt;
            fzs_get(sv, sd, 1, x, t, dt); // E1
            const f2 n1 = fz_mulk(prm_f2(s, FZ_NU0), t), dn1 = fz_mulk(prm_f2(s, FZ_NU0), dt);
            fzs_get(sv, sd, 3, x, t, dt); // G8
            f2 hg = f2_sub(f2_mul_base(t, s[FZ_KG]), f2_base(s[FZ_KGH]));
            f2 dhg = f2_mul_base(dt, s[FZ_KG]);
            fzs_get(sv, sd, 4, x, t, dt); // RGL
            hg = f2_add(hg, t); dhg = f2_add(dhg, dt);
            if (BASE) q2_term_b(c0, c1, c2, n1, dn1, hg.c0, dhg.c0);
            else q2_term(c0, c1, c2, n1, dn1, hg, dhg);
        }
        {
            f2 t, dt, u16, du16;
            fzs_get(sv, sd, 2, x, t, dt); // E2
            fzs_get(sv, sd, 6, x, u16, du16);
            const f2 n2 = fz_mulk(prm_f2(s, FZ_NU1), t), dn2 = fz_mulk(prm_f2(s, FZ_NU1), dt);
            if (BASE) q2_term_b(c0, c1, c2, n2, dn2, u16.c0, du16.c0);
            else q2_term(c0, c1, c2, n2, dn2, u16, du16);
        }
        f2 q, dq, ddq;
        q2_steps(c0, c1, c2, q, dq, ddq);
        f2 sg = f2_zero(), dsg = f2_zero();
        if (SUPP) fzs_get(sv, sd, 20, x, sg, dsg);
        #pragma unroll
        for (int d = 0; d <= D; d++) {
            if (d) { q = f2_add(q, dq); dq = f2_add(dq, ddq); if (SUPP) sg = f2_add(sg, dsg); }
            if (d == 1 && !ONE) continue;
            acc[d] = f2_add(acc[d], SUPP ? (BASE ? f2_mul_base(q, sg.c0) : fz_mulk(sg, q)) : q);
        }
    }
}

// [round 3] build the derived tables (T_GL, and T_PL with the support
// indicator) at every entry i < L of the slot's own tables
template <bool SUPP>
__device__ __forceinline__ void fzs_derive_impl(u64* tabs, long long L, const u64* __restrict__ s) {
    constexpr int K0 = FZS_K0(SUPP);
    const long long i = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= L) return;
    const u64 p1 = s[FZ_P1];
    auto T = [&](int t) { return ld_f2(tabs, (size_t)t * (size_t)L + (size_t)i); };
    // f0l = -K_h H16 + K_h/2 - RH0 - 256 RH1; f1 = U16 + 32768 - UL0 - 256 UL1; f2 = H16 + 32768 - HL0 - 256 HL1
    const f2 h16 = T(9);
    const f2 f0l = f2_sub(f2_sub(f2_add(fz_neg(f2_mul_base(h16, s[FZ_KH])), f2_base(s[FZ_KHH])), T(12)), f2_mul_base(T(13), p1));
    const f2 f1 = f2_sub(f2_sub(f2_add(T(6), f2_base(32768ULL)), T(7)), f2_mul_base(T(8), p1));
    const f2 fh = f2_sub(f2_sub(f2_add(h16, f2_base(32768ULL)), T(10)), f2_mul_base(T(11), p1));
    const f2 gl = f2_add(f2_add(fz_mulk(prm_f2(s, FZ_MU + 0), f0l), fz_mulk(prm_f2(s, FZ_MU + 2), f1)), fz_mulk(prm_f2(s, FZ_MU + 4), fh));
    st_f2(tabs, (size_t)K0 * (size_t)L + (size_t)i, gl);
    if (SUPP) {
        f2 pl = f2_zero();
        #pragma unroll
        for (int j = 0; j < 11; j++) {
            const f2 w = prm_f2(s, FZ_PADW + 2 * j);
            if ((w.c0 | w.c1) == 0ULL) continue;
            pl = f2_add(pl, fz_mulk(w, T(3 + j)));
        }
        st_f2(tabs, (size_t)(K0 + 1) * (size_t)L + (size_t)i, fz_mulk(prm_f2(s, FZ_MUPAD), pl));
    }
}

// [round 4] RAW SOURCES. In round 0 and in the fused round 1 a table may be
// read straight from the device-resident commitment rows instead of a
// widened copy: srcd[3 t] = mode (0: the Fp2 table in `tabs`, 1: a base
// plane, srcd[3 t + 1] its u64 words, 2: a helper pair, srcd[3 t + 1] /
// srcd[3 t + 2] the re / im words). Round 1's fold writes the folded halves
// into `tabs`, which every later round reads. Same values as the widened
// copies (a base plane widens to (a, 0), a pair to (re, im)).
__device__ __forceinline__ f2 fzs_ld(const u64* tabs, long long L, const u64* srcd, int raw, int t, size_t idx) {
    if (raw) {
        const u64 mode = srcd[3 * t];
        if (mode == 1ULL) {
            f2 r;
            r.c0 = ((const u64*)srcd[3 * t + 1])[idx];
            r.c1 = 0ULL;
            return r;
        }
        if (mode == 2ULL) {
            f2 r;
            r.c0 = ((const u64*)srcd[3 * t + 1])[idx];
            r.c1 = ((const u64*)srcd[3 * t + 2])[idx];
            return r;
        }
    }
    return ld_f2(tabs, (size_t)t * (size_t)L + idx);
}

// [round 4] the derived tables INSIDE round 0, from the A values the block
// just staged (lane x; `hi` = the pair's second entry, value + difference):
// T_GL (which = 0) or T_PL (which = 1), the same expressions as k_fzc_derive
__device__ __forceinline__ f2 fzs_a(const u64* sv, const u64* sd, int j, int x, bool hi) {
    f2 v, dv;
    fzs_get(sv, sd, 3 + j, x, v, dv);
    return hi ? f2_add(v, dv) : v;
}
__device__ __forceinline__ f2 fzs_derived_at(const u64* sv, const u64* sd, int x, bool hi, int which, const u64* s) {
    if (which == 0) {
        const u64 p1 = s[FZ_P1];
        const f2 h16 = fzs_a(sv, sd, 6, x, hi);
        f2 f0l = f2_add(fz_neg(f2_mul_base(h16, s[FZ_KH])), f2_base(s[FZ_KHH]));
        f0l = f2_sub(f0l, fzs_a(sv, sd, 9, x, hi));
        f0l = f2_sub(f0l, f2_mul_base(fzs_a(sv, sd, 10, x, hi), p1));
        f2 f1 = f2_add(fzs_a(sv, sd, 3, x, hi), f2_base(32768ULL));
        f1 = f2_sub(f1, fzs_a(sv, sd, 4, x, hi));
        f1 = f2_sub(f1, f2_mul_base(fzs_a(sv, sd, 5, x, hi), p1));
        f2 fh = f2_add(h16, f2_base(32768ULL));
        fh = f2_sub(fh, fzs_a(sv, sd, 7, x, hi));
        fh = f2_sub(fh, f2_mul_base(fzs_a(sv, sd, 8, x, hi), p1));
        return f2_add(f2_add(fz_mulk(prm_f2(s, FZ_MU + 0), f0l), fz_mulk(prm_f2(s, FZ_MU + 2), f1)), fz_mulk(prm_f2(s, FZ_MU + 4), fh));
    }
    f2 pl = f2_zero();
    #pragma unroll
    for (int j = 0; j < 11; j++) {
        const f2 w = prm_f2(s, FZ_PADW + 2 * j);
        if ((w.c0 | w.c1) == 0ULL) continue;
        pl = f2_add(pl, fz_mulk(w, fzs_a(sv, sd, j, x, hi)));
    }
    return fz_mulk(prm_f2(s, FZ_MUPAD), pl);
}

// One round (FOLD = false: round 0, pairs (i, i + half)) or one fused fold +
// next round (FOLD = true: fold every table at r over the pre-fold half hp,
// in place, then the round on the folded tables' pairs (i, i + q), q = hp/2).
// Race-free for the same reason as v2: chunk pairs are disjoint, a block
// writes only i and i + q of its own pairs, and reads of i + hp, i + q + hp
// are never written in this launch; phase 2 reads shared memory only.
template <int D, bool SUPP, bool FOLD, bool ONE, bool BASE>
__device__ __forceinline__ void fzs_impl(u64* tabs, int hn, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, u64* __restrict__ partial, unsigned int* cnt, u64* __restrict__ sums, const u64* __restrict__ srcd, int raw, u64 mapped, u64 seq) {
    constexpr int K = FZS_KD(SUPP); // the slot's tables + the derived ones
    constexpr int NG = SUPP ? 8 : 7;
    constexpr int NT = 32 * NG;
    constexpr int NV = D + 1;
    __shared__ u64 sp[FZ_LEN];
    __shared__ u64 sv[K * FZS_PAIRS * 2];
    __shared__ u64 sd[K * FZS_PAIRS * 2];
    __shared__ u64 red[NG * NV * 2];
    __shared__ u64 ssrc[FZS_K0(SUPP) * 3];
    __shared__ int am_last;
    constexpr int K0 = FZS_K0(SUPP);
    const int tid = threadIdx.y * 32 + threadIdx.x;
    for (int i = tid; i < FZ_LEN; i += NT) sp[i] = prm[i];
    if (raw) for (int i = tid; i < K0 * 3; i += NT) ssrc[i] = srcd[i];
    // round 0 from raw sources stages the slot's K0 tables and then derives
    // T_GL / T_PL in place (phase 1b); every other launch stages all K
    const int kstage = (raw && !FOLD) ? K0 : K;
    const int npairs = FOLD ? (hn >> 1) : hn;
    f2 r; r.c0 = r0; r.c1 = r1;
    f2 acc[NV];
    #pragma unroll
    for (int d = 0; d < NV; d++) acc[d] = f2_zero();
    int g = threadIdx.y;
    if (!SUPP && g >= 5) g += 1; // no pad group without the support indicator
    const int nchunks = (npairs + FZS_PAIRS - 1) / FZS_PAIRS;
    for (int c = blockIdx.x; c < nchunks; c += gridDim.x) {
        const int base = c * FZS_PAIRS;
        __syncthreads(); // the previous chunk's readers are done (and sp is loaded)
        for (int it = tid; it < kstage * FZS_PAIRS; it += NT) {
            const int t = it / FZS_PAIRS, lane = it % FZS_PAIRS, i = base + lane;
            const int o = (t * FZS_PAIRS + lane) * 2;
            // raw sources exist for the slot's own tables only (the derived
            // ones live in `tabs`, written by round 0)
            const int rawt = (raw && t < K0) ? 1 : 0;
            f2 lo = f2_zero(), dif = f2_zero();
            if (i < npairs) {
                const size_t tb = (size_t)t * (size_t)L;
                if (FOLD) {
                    const int hp = hn, q = npairs;
                    const f2 a0 = fzs_ld(tabs, L, ssrc, rawt, t, (size_t)i), a1 = fzs_ld(tabs, L, ssrc, rawt, t, (size_t)(i + hp));
                    const f2 b0 = fzs_ld(tabs, L, ssrc, rawt, t, (size_t)(i + q)), b1 = fzs_ld(tabs, L, ssrc, rawt, t, (size_t)(i + q + hp));
                    lo = f2_add(a0, fz_mulk(r, f2_sub(a1, a0)));
                    const f2 hi = f2_add(b0, fz_mulk(r, f2_sub(b1, b0)));
                    st_f2(tabs, tb + i, lo);
                    st_f2(tabs, tb + i + q, hi);
                    dif = f2_sub(hi, lo);
                } else {
                    lo = fzs_ld(tabs, L, ssrc, rawt, t, (size_t)i);
                    dif = f2_sub(fzs_ld(tabs, L, ssrc, rawt, t, (size_t)(i + npairs)), lo);
                }
            }
            sv[o] = lo.c0; sv[o + 1] = lo.c1;
            sd[o] = dif.c0; sd[o + 1] = dif.c1;
        }
        __syncthreads();
        if (raw && !FOLD) {
            // phase 1b (round 0 from raw sources): the derived tables, written
            // to `tabs` at full length (round 1 folds them) and staged
            const int nder = SUPP ? 2 : 1;
            if (tid < 32 * nder) {
                const int lane = tid & 31, which = tid >> 5, i = base + lane, t = K0 + which;
                const int o = (t * FZS_PAIRS + lane) * 2;
                f2 lo = f2_zero(), dif = f2_zero();
                if (i < npairs) {
                    lo = fzs_derived_at(sv, sd, lane, false, which, sp);
                    const f2 hi = fzs_derived_at(sv, sd, lane, true, which, sp);
                    dif = f2_sub(hi, lo);
                    const size_t tb = (size_t)t * (size_t)L;
                    st_f2(tabs, tb + i, lo);
                    st_f2(tabs, tb + i + npairs, hi);
                }
                sv[o] = lo.c0; sv[o + 1] = lo.c1;
                sd[o] = dif.c0; sd[o + 1] = dif.c1;
            }
            __syncthreads();
        }
        if (base + (int)threadIdx.x < npairs) fzs_group<D, SUPP, ONE, BASE>(g, sv, sd, threadIdx.x, sp, acc);
    }
    // the block's partial: warp shuffles, then one value per warp in shared
    #pragma unroll
    for (int d = 0; d < NV; d++) {
        u64 c0 = acc[d].c0, c1 = acc[d].c1;
        #pragma unroll
        for (int off = 16; off > 0; off >>= 1) {
            c0 = gl_add(c0, __shfl_down_sync(0xffffffffu, c0, off));
            c1 = gl_add(c1, __shfl_down_sync(0xffffffffu, c1, off));
        }
        if (threadIdx.x == 0) { red[(threadIdx.y * NV + d) * 2] = c0; red[(threadIdx.y * NV + d) * 2 + 1] = c1; }
    }
    __syncthreads();
    if (tid < NV * 2) {
        u64 v = 0ULL;
        for (int w = 0; w < NG; w++) v = gl_add(v, red[w * NV * 2 + tid]);
        partial[(size_t)blockIdx.x * NV * 2 + tid] = v;
    }
    // K3: the last block to finish sums every block's partial into `sums`
    __threadfence();
    __syncthreads();
    if (tid == 0) am_last = (atomicAdd(cnt, 1u) == gridDim.x - 1) ? 1 : 0;
    __syncthreads();
    if (am_last) {
        if (tid < NV * 2) {
            u64 v = 0ULL;
            for (int b = 0; b < (int)gridDim.x; b++) v = gl_add(v, __ldcg(&partial[(size_t)b * NV * 2 + tid]));
            sums[tid] = v;
            // [round 4] the mapped page-locked result: the words, then (after
            // a system fence) the sequence flag the host polls
            if (mapped) ((volatile u64*)mapped)[tid] = v;
        }
        if (tid == 0) *cnt = 0u; // ready for the next launch (stream order)
        if (mapped) {
            __threadfence_system();
            __syncthreads();
            if (tid == 0) ((volatile u64*)mapped)[NV * 2] = seq;
        }
    }
}

// K4 aid: pack the live prefix (len entries) of every table contiguously for
// ONE device-to-host copy when the tail rounds move to the host.
extern "C" __global__ void k_fzc_pack(const u64* __restrict__ tabs, int k, long long L, int len, u64* __restrict__ out) {
    const long long idx = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= (long long)k * len) return;
    const long long t = idx / len, i = idx - t * len;
    out[2 * idx] = tabs[2 * (t * L + i)];
    out[2 * idx + 1] = tabs[2 * (t * L + i) + 1];
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
// by the host in front of this source (cuda.rs `fzc_module`), with FZ_SPLIT
// (1: v4, the term-group split with the fused reduction; its entry points
// take the counter and the sums buffer).
#if FZ_SPLIT
#define FZS_NT ((FZ_SUPP != 0) ? 256 : 224)
// `_r` = the recovery rounds (s(1) not evaluated), the others evaluate s(1);
// `_b` = round 0 with base-field A planes and S (the host's BASE flag)
#define FZS_ROUND(NAME, ONE, BASE) \
extern "C" __global__ __launch_bounds__(FZS_NT, 3) void NAME(u64* tabs, int half, long long L, const u64* __restrict__ prm, u64* __restrict__ partial, unsigned int* cnt, u64* __restrict__ sums, const u64* __restrict__ srcd, int raw, u64 mapped, u64 seq) { \
    fzs_impl<FZ_D, (FZ_SUPP != 0), false, ONE, BASE>(tabs, half, L, 0ULL, 0ULL, prm, partial, cnt, sums, srcd, raw, mapped, seq); \
}
FZS_ROUND(k_fzc_round, true, false)
FZS_ROUND(k_fzc_round_r, false, false)
FZS_ROUND(k_fzc_round_b, true, true)
FZS_ROUND(k_fzc_round_rb, false, true)
extern "C" __global__ __launch_bounds__(FZS_NT, 3) void k_fzc_fold_round(u64* tabs, int hp, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, u64* __restrict__ partial, unsigned int* cnt, u64* __restrict__ sums, const u64* __restrict__ srcd, int raw, u64 mapped, u64 seq) {
    fzs_impl<FZ_D, (FZ_SUPP != 0), true, true, false>(tabs, hp, L, r0, r1, prm, partial, cnt, sums, srcd, raw, mapped, seq);
}
extern "C" __global__ __launch_bounds__(FZS_NT, 3) void k_fzc_fold_round_r(u64* tabs, int hp, long long L, u64 r0, u64 r1, const u64* __restrict__ prm, u64* __restrict__ partial, unsigned int* cnt, u64* __restrict__ sums, const u64* __restrict__ srcd, int raw, u64 mapped, u64 seq) {
    fzs_impl<FZ_D, (FZ_SUPP != 0), true, false, false>(tabs, hp, L, r0, r1, prm, partial, cnt, sums, srcd, raw, mapped, seq);
}
extern "C" __global__ void k_fzc_derive(u64* tabs, long long L, const u64* __restrict__ prm) {
    fzs_derive_impl<(FZ_SUPP != 0)>(tabs, L, prm);
}
#elif FZ_LEAN
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
