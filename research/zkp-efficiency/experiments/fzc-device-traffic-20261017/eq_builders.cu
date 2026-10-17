extern "C" __global__ void k_eq_table(const u64* __restrict__ r, u64* __restrict__ dst, int nv) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= (1 << nv)) return;
    f2 one; one.c0 = 1; one.c1 = 0;
    f2 acc = one;
    for (int i = 0; i < nv; i++) {
        f2 ri = ld_f2(r, i);
        int bit = (idx >> (nv - 1 - i)) & 1;
        acc = f2_mul(acc, bit ? ri : f2_sub(one, ri));
    }
    st_f2(dst, idx, acc);
}
extern "C" __global__ void k_eq_join(const u64* __restrict__ hi, const u64* __restrict__ lo, u64* __restrict__ dst, int lo_bits, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;
    f2 h = ld_f2(hi, idx >> lo_bits);
    f2 l = ld_f2(lo, idx & ((1 << lo_bits) - 1));
    st_f2(dst, idx, f2_mul(h, l));
}
