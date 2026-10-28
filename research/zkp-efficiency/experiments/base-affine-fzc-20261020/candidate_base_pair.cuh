// Research adapter sketch, UNCOMPILED. Not a production patch.
// Include after cycle0097's fzs_derived_pair_candidate definition, itself
// after fzs_get. Retain that extension fallback. Host prepares pad weights
// freshly per sumcheck; never cache masks/challenges or alter original prm.
// Existing BASE flag only, round0/raw/!FOLD. No new private-value tests.

template <bool DIFF>
__device__ __forceinline__ u64 fzs_scalar_component(
    const u64* sv, const u64* sd, int j, int lane) {
    const int o = ((3 + j) * FZS_PAIRS + lane) * 2;
    return DIFF ? sd[o] : sv[o];
}

template <bool DIFF>
__device__ __forceinline__ f2 fzs_base_gl(
    const u64* sv, const u64* sd, int lane, const u64* s) {
    const u64 h = fzs_scalar_component<DIFF>(sv, sd, 6, lane);
    u64 f0 = gl_sub(0ULL, gl_mul(h, s[FZ_KH]));
    if (!DIFF) f0 = gl_add(f0, s[FZ_KHH]);
    f0 = gl_sub(gl_sub(f0, fzs_scalar_component<DIFF>(sv, sd, 9, lane)),
                gl_mul(fzs_scalar_component<DIFF>(sv, sd, 10, lane), s[FZ_P1]));
    u64 f1 = fzs_scalar_component<DIFF>(sv, sd, 3, lane);
    if (!DIFF) f1 = gl_add(f1, 32768ULL);
    f1 = gl_sub(gl_sub(f1, fzs_scalar_component<DIFF>(sv, sd, 4, lane)),
                gl_mul(fzs_scalar_component<DIFF>(sv, sd, 5, lane), s[FZ_P1]));
    u64 fh = h;
    if (!DIFF) fh = gl_add(fh, 32768ULL);
    fh = gl_sub(gl_sub(fh, fzs_scalar_component<DIFF>(sv, sd, 7, lane)),
                gl_mul(fzs_scalar_component<DIFF>(sv, sd, 8, lane), s[FZ_P1]));
    return f2_add(f2_add(f2_mul_base(prm_f2(s,FZ_MU),f0),
                         f2_mul_base(prm_f2(s,FZ_MU+2),f1)),
                  f2_mul_base(prm_f2(s,FZ_MU+4),fh));
}

template <bool BASE>
__device__ __forceinline__ void fzs_base_pair_candidate(
    const u64* sv, const u64* sd, int lane, int which, const u64* s,
    const u64* prepared_pad, f2& lo, f2& dif) {
    if (!BASE) {
        fzs_derived_pair_candidate(sv,sd,lane,which,s,prepared_pad,lo,dif);
        return;
    }
    if (which == 0) {
        lo = fzs_base_gl<false>(sv,sd,lane,s);
        dif = fzs_base_gl<true>(sv,sd,lane,s);
        return;
    }
    lo=f2_zero(); dif=f2_zero();
    #pragma unroll
    for(int j=0;j<11;j++) {
        const f2 w=prm_f2(prepared_pad,2*j);
        if ((w.c0 | w.c1)==0ULL) continue; // current public coefficient
        lo=f2_add(lo,f2_mul_base(w,fzs_scalar_component<false>(sv,sd,j,lane)));
        dif=f2_add(dif,f2_mul_base(w,fzs_scalar_component<true>(sv,sd,j,lane)));
    }
}
// In fzs_impl's existing raw&&!FOLD phase1b ONLY:
// fzs_base_pair_candidate<BASE>(sv,sd,lane,which,sp,prepared_pad,lo,dif);
// const f2 hi=f2_add(lo,dif);  // STORE high endpoint; counted by probe.py
// Keep both global stores, both-coordinate shared stores, and same barrier.
// No BASE specialization for later rounds: FOLD wrapper passes BASE=false.
// No change to source descriptor lifetimes, raw/dense eligibility, tail/finals.
