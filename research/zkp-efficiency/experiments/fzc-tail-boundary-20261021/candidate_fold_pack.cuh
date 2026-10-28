// RESEARCH SKETCH, UNCOMPILED. Requires existing f2/ld_f2/st_f2 helpers.
// Replace boundary k_sc_fold + k_fzc_pack ONLY when existing to_host is true.
// Source remains untouched; no derived table is needed after moving to host.
// One fresh disjoint output allocation, k * half Fp2; keep current copy/sync.
extern "C" __global__ void k_fzc_fold_pack_candidate(
    const u64* __restrict__ tabs, int k, long long stride, int half,
    u64 r0, u64 r1, u64* __restrict__ packed) {
    const long long g = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (g >= (long long)k * half) return;
    const long long t = g / half, i = g - t * half;
    f2 r; r.c0 = r0; r.c1 = r1;
    const f2 a = ld_f2(tabs, (size_t)(t * stride + i));
    const f2 b = ld_f2(tabs, (size_t)(t * stride + i + half));
    st_f2(packed, (size_t)g, f2_add(a, f2_mul(r, f2_sub(b, a))));
}
