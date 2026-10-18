// Research-only, host-tested candidate; no native/CUDA integration.
// Coefficients are proof-local and must be prepared after this proof's mu_pad.
static void prepare_pad(const u64* s, f2* weighted) {
    for (int j=0;j<11;j++) {
        const f2 w=prm_f2(s,FZ_PADW+2*j);
        weighted[j]=(w.c0|w.c1) ? fz_mulk(prm_f2(s,FZ_MUPAD),w) : f2_zero();
    }
}
template<bool SUPP, bool BASE>
static void candidate_derive(u64* tabs, long long L, const u64* s, const f2* weighted) {
    constexpr int K0=FZS_K0(SUPP);
    const long long i=(long long)blockIdx.x*blockDim.x+threadIdx.x;
    if(i>=L) return;
    auto T=[&](int t){return ld_f2(tabs,(size_t)t*L+i);};
    f2 gl;
    if(BASE) {
        const u64 h=T(9).c0;
        const u64 a=gl_sub(gl_sub(gl_sub(s[FZ_KHH],gl_mul(h,s[FZ_KH])),T(12).c0),gl_mul(T(13).c0,s[FZ_P1]));
        const u64 b=gl_sub(gl_sub(gl_add(T(6).c0,32768),T(7).c0),gl_mul(T(8).c0,s[FZ_P1]));
        const u64 c=gl_sub(gl_sub(gl_add(h,32768),T(10).c0),gl_mul(T(11).c0,s[FZ_P1]));
        gl=f2_add(f2_add(f2_mul_base(prm_f2(s,FZ_MU),a),f2_mul_base(prm_f2(s,FZ_MU+2),b)),f2_mul_base(prm_f2(s,FZ_MU+4),c));
    } else {
        const f2 h=T(9);
        const f2 a=f2_sub(f2_sub(f2_add(fz_neg(f2_mul_base(h,s[FZ_KH])),f2_base(s[FZ_KHH])),T(12)),f2_mul_base(T(13),s[FZ_P1]));
        const f2 b=f2_sub(f2_sub(f2_add(T(6),f2_base(32768)),T(7)),f2_mul_base(T(8),s[FZ_P1]));
        const f2 c=f2_sub(f2_sub(f2_add(h,f2_base(32768)),T(10)),f2_mul_base(T(11),s[FZ_P1]));
        gl=f2_add(f2_add(fz_mulk(prm_f2(s,FZ_MU),a),fz_mulk(prm_f2(s,FZ_MU+2),b)),fz_mulk(prm_f2(s,FZ_MU+4),c));
    }
    st_f2(tabs,(size_t)K0*L+i,gl);
    if(SUPP) {
        f2 pl=f2_zero();
        for(int j=0;j<11;j++) {
            // Match the old public-weight skip predicate, even if mu_pad=0.
            const f2 w=prm_f2(s,FZ_PADW+2*j);
            if((w.c0|w.c1)==0) continue;
            const f2 a=T(3+j);
            pl=f2_add(pl,BASE ? f2_mul_base(weighted[j],a.c0) : fz_mulk(weighted[j],a));
        }
        st_f2(tabs,(size_t)(K0+1)*L+i,pl);
    }
}
