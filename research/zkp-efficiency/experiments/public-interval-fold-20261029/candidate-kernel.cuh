// UNCOMPILED owner-review sketch. Include only after native f2 helpers.
// Rust Run{word:u32,len:u32} is 8 bytes and maps to uint2.
// Host MUST validate current public provenance, canonical spans, row bounds,
// k in 1..=4, flags, exact current support and per-call buffer lifetime.
// Register separately in native FUNCS; existing dense/list kernels are fallbacks.
extern "C" __global__ void k_fold_rows_public_runs(
    const u64* __restrict__ data, const u64* __restrict__ rhos,
    u64* __restrict__ out, const uint2* __restrict__ spans,
    int span_count, int rows, int n, int k) {
    int j=blockIdx.x*blockDim.x+threadIdx.x;
    if (j>=n) return;
    f2 acc[4];
    #pragma unroll
    for(int g=0;g<4;g++) acc[g]=f2_zero();
    for(int si=0;si<span_count;si++) {
        uint2 s=spans[si];
        unsigned start=s.x>>4, flags=s.x&15;
        unsigned end=start+s.y; // prevalidated on host, no wrap or truncation
        for(unsigned r=start;r<end;r++) {
            u64 v=data[(size_t)r*n+j];
            #pragma unroll
            for(int g=0;g<4;g++) {
                if(g<k && (flags&(1u<<g))) {
                    f2 w=ld_f2(rhos,(size_t)g*rows+r);
                    acc[g]=f2_add(acc[g],f2_mul_base(w,v));
                }
            }
        }
    }
    #pragma unroll
    for(int g=0;g<4;g++) if(g<k) st_f2(out,(size_t)g*n+j,acc[g]);
}
