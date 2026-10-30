#define FR_MAX_K 4
extern "C" __global__ void k_fold_rows(const u64* __restrict__ data, const u64* __restrict__ rhos, u64* __restrict__ out, int rows, int n, int k) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= n) return;
    f2 acc[FR_MAX_K];
    #pragma unroll
    for (int g = 0; g < FR_MAX_K; g++) acc[g] = f2_zero();
    for (int i = 0; i < rows; i++) {
        u64 v = data[(size_t)i * n + j];
        #pragma unroll
        for (int g = 0; g < FR_MAX_K; g++) {
            if (g < k) {
                f2 r = ld_f2(rhos, (size_t)g * rows + i);
                acc[g] = f2_add(acc[g], f2_mul_base(r, v));
            }
        }
    }
    #pragma unroll
    for (int g = 0; g < FR_MAX_K; g++) {
        if (g < k) st_f2(out, (size_t)g * n + j, acc[g]);
    }
}
