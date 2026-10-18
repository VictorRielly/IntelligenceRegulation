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
__device__ __forceinline__ f2 ld_f2(const u64* p, size_t i) { nread++; f2 r; r.c0 = p[2 * i]; r.c1 = p[2 * i + 1]; return r; }
__device__ __forceinline__ void st_f2(u64* p, size_t i, f2 v) { nwrite++; p[2 * i] = v.c0; p[2 * i + 1] = v.c1; }
__device__ __forceinline__ f2 prm_f2(const u64* prm, int at) { f2 r; r.c0 = prm[at]; r.c1 = prm[at + 1]; return r; }
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
#define FZS_K0(SUPP) ((SUPP) ? 21 : 20)
#define FZS_KD(SUPP) ((SUPP) ? 23 : 21)


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
