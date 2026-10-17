// Same CPU-only substitutions and instrumented ld/st as the round census.
#include "shim.cpp"
#include "eq_builders.cu"
extern "C" void leaf_eq(const u64* r,int n,u64* dst,u64* cnt) {
    nread=nwrite=0; blockIdx.x=0; blockDim.x=gridDim.x=1;
    for(int i=0;i<(1<<n);i++) { threadIdx.x=i; k_eq_table(r,dst,n); }
    threadIdx.x=0; cnt[0]=nread; cnt[1]=nwrite;
}
extern "C" void join_eq(const u64* hi,const u64* lo,int lb,int n,u64* dst,u64* cnt) {
    nread=nwrite=0; blockIdx.x=0; blockDim.x=gridDim.x=1;
    for(int i=0;i<n;i++) { threadIdx.x=i; k_eq_join(hi,lo,dst,lb,n); }
    threadIdx.x=0; cnt[0]=nread; cnt[1]=nwrite;
}
