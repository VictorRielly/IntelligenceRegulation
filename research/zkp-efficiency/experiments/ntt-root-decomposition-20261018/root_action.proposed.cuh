// RESEARCH: host-compiled only. No CUDA/PTX/native-proof performance gate.
// Requires canonical native gl_mul/gl_sub/gl_reduce, u64/u32, P_GL.
// low points to an immutable, direction-bound native-root plan. Its stage
// s>6 has 2^(s-6) words at offset 2^(s-6)-2; stages<=6 need no words.
// Host must bind generator7/root64=2^39 and validate capacity before launch.
// Inputs a<P_GL, 1<=s<=32, k<2^(s-1). All dispatch is PUBLIC.
#ifndef ROOT_COUNT
#define ROOT_COUNT(name) ((void)0)
#endif

__device__ __forceinline__ u64 root_shift(u64 a, u32 e) {
    if (e == 0) return a;
    ROOT_COUNT(root_shift_calls);
    const bool neg = e >= 96;
    if (neg) e -= 96;
    u64 r;
    if (e == 0) r = a;
    else if (e < 64) r = gl_reduce(a << e, a >> (64-e));
    else {
        const u32 sh = e-64;
        const u64 high = sh ? a >> (64-sh) : 0ULL;
        r = gl_sub(gl_reduce(0ULL, a << sh), high << 32);
    }
    return neg && r ? P_GL-r : r;
}

__device__ __forceinline__ u64 root_apply_parts(u64 a, u64 low, bool has_low, u32 high, bool inverse) {
    if (has_low) { ROOT_COUNT(root_general_calls); a=gl_mul(a,low); }
    u32 e=(39U*high)%192U;
    if(inverse && e) e=192U-e;
    return root_shift(a,e);
}

__device__ __forceinline__ u64 root_action(u64 a, const u64* low, u32 s, u32 k, bool inverse) {
    u32 high;
    u64 factor=1;
    bool has_low=false;
    if (s <= 6) high = k << (6-s);
    else {
        const u32 d = s-6;
        const u32 len = 1U << d;
        const u32 l = k & (len-1U);
        high = k >> d;
        if (l) {
            ROOT_COUNT(root_word_reads);
            factor=low[(size_t)len-2U+l];
            has_low=true;
        }
    }
    return root_apply_parts(a,factor,has_low,high,inverse);
}
