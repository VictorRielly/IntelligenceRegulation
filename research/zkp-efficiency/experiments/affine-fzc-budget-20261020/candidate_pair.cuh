// Research adapter sketch; NOT compiled or device-validated. Owner review only.
// Insert after fzs_get's definition in the pinned fzc_kernels.cu.
// Uses that file's existing f2, fz_mulk and parameter layout.
// prepared_pad[22] is shared-staged Fp2(mu_pad * pad_w[j]), recomputed once
// per sumcheck from the CURRENT public descriptor. Original params retained.
// No private-value-dependent branches and no transcript/RNG calls.

template <bool DIFF>
__device__ __forceinline__ f2 fzs_component(
    const u64* sv, const u64* sd, int j, int lane) {
    f2 v, dv;
    fzs_get(sv, sd, 3 + j, lane, v, dv);
    return DIFF ? dv : v;
}

template <bool DIFF>
__device__ __forceinline__ f2 fzs_gl_component(
    const u64* sv, const u64* sd, int lane, const u64* s) {
    const f2 h = fzs_component<DIFF>(sv, sd, 6, lane);
    f2 f0 = fz_neg(f2_mul_base(h, s[FZ_KH]));
    if (!DIFF) f0 = f2_add(f0, f2_base(s[FZ_KHH]));
    f0 = f2_sub(f0, fzs_component<DIFF>(sv, sd, 9, lane));
    f0 = f2_sub(f0, f2_mul_base(fzs_component<DIFF>(sv, sd, 10, lane), s[FZ_P1]));
    f2 f1 = fzs_component<DIFF>(sv, sd, 3, lane);
    if (!DIFF) f1 = f2_add(f1, f2_base(32768ULL));
    f1 = f2_sub(f1, fzs_component<DIFF>(sv, sd, 4, lane));
    f1 = f2_sub(f1, f2_mul_base(fzs_component<DIFF>(sv, sd, 5, lane), s[FZ_P1]));
    f2 fh = h;
    if (!DIFF) fh = f2_add(fh, f2_base(32768ULL));
    fh = f2_sub(fh, fzs_component<DIFF>(sv, sd, 7, lane));
    fh = f2_sub(fh, f2_mul_base(fzs_component<DIFF>(sv, sd, 8, lane), s[FZ_P1]));
    return f2_add(f2_add(fz_mulk(prm_f2(s, FZ_MU), f0),
                         fz_mulk(prm_f2(s, FZ_MU + 2), f1)),
                  fz_mulk(prm_f2(s, FZ_MU + 4), fh));
}

__device__ __forceinline__ void fzs_derived_pair_candidate(
    const u64* sv, const u64* sd, int lane, int which,
    const u64* s, const u64* prepared_pad, f2& lo, f2& dif) {
    if (which == 0) {
        lo = fzs_gl_component<false>(sv, sd, lane, s);
        dif = fzs_gl_component<true>(sv, sd, lane, s);
        return;
    }
    lo = f2_zero(); dif = f2_zero();
    #pragma unroll
    for (int j = 0; j < 11; j++) {
        const f2 w = prm_f2(prepared_pad, 2 * j);
        if ((w.c0 | w.c1) == 0ULL) continue; // public coefficient only
        f2 v, dv; fzs_get(sv, sd, 3 + j, lane, v, dv);
        lo = f2_add(lo, fz_mulk(w, v));
        dif = f2_add(dif, fz_mulk(w, dv));
    }
}

// RAW ROUND ZERO ONLY, replacing the two fzs_derived_at calls:
//   fzs_derived_pair_candidate(sv, sd, lane, which, sp, prepared_pad, lo, dif);
//   const f2 hi = f2_add(lo, dif); // required to retain the global high store
//   st_f2(tabs, tb+i, lo); st_f2(tabs, tb+i+npairs, hi);
//   ...same shared lo/dif stores and existing barrier...
// IMPORTANT: the high reconstruction above costs one Fp2 addition per
// derived pair. affine.py pair costs omit this STORE-ONLY reconstruction;
// cost_probe.py accounts for it separately in the raw_pair variant.
// Fallbacks, subsequent derived folds and all original parameters unchanged.
