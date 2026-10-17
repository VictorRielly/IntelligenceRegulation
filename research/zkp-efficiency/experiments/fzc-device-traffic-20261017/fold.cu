extern "C" __global__ void k_sc_fold(u64* __restrict__ tabs, int k, int half, int L, u64 r0, u64 r1) {
    int g = blockIdx.x * blockDim.x + threadIdx.x;
    if (g >= k * half) return;
    int t = g / half;
    int i = g - t * half;
    f2 r; r.c0 = r0; r.c1 = r1;
    f2 a = ld_f2(tabs, (size_t)t * L + i);
    f2 b = ld_f2(tabs, (size_t)t * L + i + half);
    st_f2(tabs, (size_t)t * L + i, f2_add(a, f2_mul(r, f2_sub(b, a))));
}
