// Research adapter sketch, UNCOMPILED. Not a production patch.
// Place after existing fzs_derived_at; no new host coefficients or parameters.
// Caller remains raw && !FOLD phase1b; existing BASE selection ONLY.
// Existing private owners, randomness, table stores and barriers remain.
template <bool DIFF>
__device__ __forceinline__ u64 fzs_glonly_scalar_component(
    const u64* sv, const u64* sd, int j, int lane) {
    const int o = ((3 + j) * FZS_PAIRS + lane) * 2;
    return DIFF ? sd[o] : sv[o];
}

template <bool DIFF>
__device__ __forceinline__ f2 fzs_glonly_base_gl(
    const u64* sv, const u64* sd, int lane, const u64* s) {
    const u64 h = fzs_glonly_scalar_component<DIFF>(sv, sd, 6, lane);
    u64 f0 = gl_sub(0ULL, gl_mul(h, s[FZ_KH]));
    if (!DIFF) f0 = gl_add(f0, s[FZ_KHH]);
    f0 = gl_sub(gl_sub(f0, fzs_glonly_scalar_component<DIFF>(sv, sd, 9, lane)),
                gl_mul(fzs_glonly_scalar_component<DIFF>(sv, sd, 10, lane), s[FZ_P1]));
    u64 f1 = fzs_glonly_scalar_component<DIFF>(sv, sd, 3, lane);
    if (!DIFF) f1 = gl_add(f1, 32768ULL);
    f1 = gl_sub(gl_sub(f1, fzs_glonly_scalar_component<DIFF>(sv, sd, 4, lane)),
                gl_mul(fzs_glonly_scalar_component<DIFF>(sv, sd, 5, lane), s[FZ_P1]));
    u64 fh = h;
    if (!DIFF) fh = gl_add(fh, 32768ULL);
    fh = gl_sub(gl_sub(fh, fzs_glonly_scalar_component<DIFF>(sv, sd, 7, lane)),
                gl_mul(fzs_glonly_scalar_component<DIFF>(sv, sd, 8, lane), s[FZ_P1]));
    return f2_add(f2_add(f2_mul_base(prm_f2(s,FZ_MU),f0),
                         f2_mul_base(prm_f2(s,FZ_MU+2),f1)),
                  f2_mul_base(prm_f2(s,FZ_MU+4),fh));
}


template <bool BASE>
__device__ __forceinline__ void fzs_gl_only_pair_candidate(
    const u64* sv, const u64* sd, int lane, int which, const u64* s,
    f2& lo, f2& dif, f2& hi) {
    if (BASE && which == 0) {
        lo = fzs_glonly_base_gl<false>(sv, sd, lane, s);
        dif = fzs_glonly_base_gl<true>(sv, sd, lane, s);
        hi = f2_add(lo, dif);
    } else {
        // PL and every non-BASE case retain the current literal implementation.
        lo = fzs_derived_at(sv, sd, lane, false, which, s);
        hi = fzs_derived_at(sv, sd, lane, true, which, s);
        dif = f2_sub(hi, lo);
    }
}
// Only replace the two evaluations and subtraction inside i < npairs:
// f2 hi;
// fzs_gl_only_pair_candidate<BASE>(sv, sd, lane, which, sp, lo, dif, hi);
// Keep both st_f2(tabs, ...) stores, all shared stores, and __syncthreads().
// Do not call on FOLD rounds, relax BASE eligibility, omit high, or scalarize
// coefficients/results. Inspection/compilation, register/occupancy evidence,
// masked native rounds, next challenges, receipt identity and fresh independent
// verification plus existing refusal/privacy gates are still owed to the owner.
