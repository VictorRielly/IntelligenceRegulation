// UNCOMPILED research helper, NOT a production patch or CUDA verification.
// Interface uses pinned canonical gl_reduce/gl_sub/gl_mul and typedef u64/u32.
// Native generator7 root64 = 2^39; host must validate source/domain/direction.
// All dispatch decisions are public. All existing masks, RNG and PCS remain.
// CUDA owner must inspect PTX, divergence, registers and enclosing timing.

__device__ __forceinline__ u64 gl_mul_pow2_192(u64 a, u32 e) {
    // Precondition a<P_GL, e<192. Never shift a u64 by 64.
    const bool neg = e >= 96;
    if (neg) e -= 96;
    u64 r;
    if (e == 0) r = a;
    else if (e < 64) r = gl_reduce(a << e, a >> (64-e));
    else {
        const u32 s = e-64;
        const u64 high = s ? a >> (64-s) : 0ULL;
        r = gl_sub(gl_reduce(0ULL, a << s), high << 32);
    }
    return neg && r ? P_GL-r : r;
}

__device__ __forceinline__ u64 gl_mul_native_twiddle(
        u64 a, u64 native_w, u32 stage, u32 k, bool inverse) {
    // Precondition 1<=stage<=32, k<2^(stage-1), native_w is the
    // unchanged stage-major entry in the pinned forward/inverse table.
    // Stage>=7 partial eligibility causes divergence: profile before promotion.
    u32 e;
    if (stage <= 6) e = (39U * (k << (6-stage))) % 192U;
    else {
        const u32 s = stage-6;
        if (k & ((1U << s)-1U)) return gl_mul(a,native_w);
        e = (39U * (k >> s)) % 192U;
    }
    if (inverse && e) e = 192U-e;
    return gl_mul_pow2_192(a,e);
}

// Known inverse size 2^log_n uses e=(192-log_n)%192; this is separate
// from twiddle-stage counts. Arbitrary scale and every coset h^i KEEP gl_mul.
// First bounded owner candidate should specialize only first6 stages and
// known inverse scale. Do not alter pruned/pad-skipped stages or add kernels.
