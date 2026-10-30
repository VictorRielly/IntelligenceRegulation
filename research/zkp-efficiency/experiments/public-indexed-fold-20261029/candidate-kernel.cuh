// UNCOMPILED OWNER-REVIEW SKETCH. Append after native k_fold_rows and register
// k_fold_rows_indexed in cuda.rs FUNCS. This is not a production patch.
// CPU indexed_fold(..., membership=true) tests the algorithm, not CUDA codegen.
// Host contract: 1<=k<=4; rows<2^28; sorted unique in-range row words;
// flags use only k low bits and equal a current verifier-public support or
// safe public support superset. All current length/mask/proximity checks stay.
// rho buffer layout and output layout are identical to native k_fold_rows.
extern "C" __global__ void k_fold_rows_indexed(
    const u64* __restrict__ data, const u64* __restrict__ rhos,
    const unsigned int* __restrict__ plan, u64* __restrict__ out,
    int rows, int n, int k, int count
) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= n) return;
    f2 acc[FR_MAX_K];
    #pragma unroll
    for (int g = 0; g < FR_MAX_K; g++) acc[g] = f2_zero();
    for (int pos = 0; pos < count; pos++) {
        unsigned int word = plan[pos];
        unsigned int row = word >> 4;
        unsigned int flags = word & 15U;
        u64 v = data[(size_t)row * n + j];
        #pragma unroll
        for (int g = 0; g < FR_MAX_K; g++) {
            if (g < k && (flags & (1U << g))) {
                f2 r = ld_f2(rhos, (size_t)g * rows + row);
                acc[g] = f2_add(acc[g], f2_mul_base(r, v));
            }
        }
    }
    #pragma unroll
    for (int g = 0; g < FR_MAX_K; g++) {
        if (g < k) st_f2(out, (size_t)g * n + j, acc[g]);
    }
}
