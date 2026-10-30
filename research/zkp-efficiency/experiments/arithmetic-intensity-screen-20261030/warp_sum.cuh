// Locally authored, UNCOMPILED CUDA sketch. Never included in production.
// Requires canonical x, a full converged physical warp, sm_80+.
// No CUB dependency. Integer redux has existed since PTX7.0.
// gl_reduce must be the pinned native canonical Goldilocks reducer.
__device__ __forceinline__ unsigned int zke_redux32(unsigned int v) {
    unsigned int s;
    // Volatile keeps every lane's collective even when its result is unused.
    asm volatile("redux.sync.add.u32 %0, %1, 0xffffffff;" : "=r"(s) : "r"(v));
    return s;
}

// Only lane0's return value is meaningful. All lanes execute all three redux.
__device__ __forceinline__ u64 zke_warp_sum_leader(u64 x) {
    const unsigned int mask27 = (1U << 27) - 1U;
    unsigned int s0 = zke_redux32((unsigned int)x & mask27);
    unsigned int s1 = zke_redux32((unsigned int)(x >> 27) & mask27);
    unsigned int s2 = zke_redux32((unsigned int)(x >> 54));
    if ((threadIdx.x & 31) != 0) return 0;
    u64 low = (u64)s0 + ((u64)s1 << 27);
    u64 sum = low + ((u64)s2 << 54);
    u64 high = (u64)(s2 >> 10) + (sum < low);
    return gl_reduce(sum, high);
}

// Tail-only replacement concept for scg_emit<NV>. Input acc is unchanged.
// scratch allocated at WARPS*NV*2 u64, not the old THREADS*NV*2.
// Caller supplies exact launched THREADS; public guard keeps old fallback.
// A k_reduce_f2 loop needs an additional CTA barrier before scratch reuse.
template <int THREADS, int NV>
__device__ __forceinline__ void zke_emit_tail(
        const f2* acc, u64* scratch, u64* partial) {
    static_assert(THREADS >= 32 && THREADS <= 1024 && THREADS % 32 == 0, "CTA");
    static_assert(NV >= 1 && NV <= 6, "evaluation count");
    const int lane = threadIdx.x & 31;
    const int warp = threadIdx.x >> 5;
    const int NW = THREADS / 32;
    #pragma unroll
    for (int d = 0; d < NV; ++d) {
        u64 a = zke_warp_sum_leader(acc[d].c0);
        u64 b = zke_warp_sum_leader(acc[d].c1);
        if (lane == 0) {
            scratch[(warp * NV + d) * 2] = a;
            scratch[(warp * NV + d) * 2 + 1] = b;
        }
    }
    __syncthreads();
    if (warp == 0) {
        #pragma unroll
        for (int d = 0; d < NV; ++d) {
            u64 a = lane < NW ? scratch[(lane * NV + d) * 2] : 0;
            u64 b = lane < NW ? scratch[(lane * NV + d) * 2 + 1] : 0;
            a = zke_warp_sum_leader(a);
            b = zke_warp_sum_leader(b);
            if (lane == 0) {
                partial[(blockIdx.x * NV + d) * 2] = a;
                partial[(blockIdx.x * NV + d) * 2 + 1] = b;
            }
        }
    }
}
