// CPU-only arithmetic/builtin substitutes for source-level CUDA schedule tests.
// These deliberately do not emulate CUDA instructions, warps, caches or races.
#include <cstdint>
#include <cstddef>
using u64 = uint64_t;
constexpr u64 PRIME = 0xffffffff00000001ULL;
struct f2 { u64 c0, c1; };
static u64 nread = 0, nwrite = 0;
static u64 gl_add(u64 a, u64 b) { return (u64)(((unsigned __int128)a + b) % PRIME); }
static u64 gl_sub(u64 a, u64 b) { return (u64)(((unsigned __int128)a + PRIME - b) % PRIME); }
static u64 gl_mul(u64 a, u64 b) { return (u64)(((unsigned __int128)a * b) % PRIME); }
static f2 f2_zero() { return {0,0}; }
static f2 f2_add(f2 a, f2 b) { return {gl_add(a.c0,b.c0),gl_add(a.c1,b.c1)}; }
static f2 f2_sub(f2 a, f2 b) { return {gl_sub(a.c0,b.c0),gl_sub(a.c1,b.c1)}; }
static f2 f2_mul(f2 a, f2 b) { return {gl_add(gl_mul(a.c0,b.c0),gl_mul(7,gl_mul(a.c1,b.c1))),gl_add(gl_mul(a.c0,b.c1),gl_mul(a.c1,b.c0))}; }
static f2 f2_mul_base(f2 a, u64 b) { return {gl_mul(a.c0,b),gl_mul(a.c1,b)}; }
struct Dim { int x; };
static Dim threadIdx{0}, blockIdx{0}, blockDim{1}, gridDim{1};
#define __device__
#define __global__
#define __forceinline__ inline
#define __shared__
#define __syncthreads() ((void)0)
#define __launch_bounds__(...)
#define FZ_D 5
#define FZ_SUPP 1
#define FZ_LEAN 0
#include "instrumented.cu"
#include "fold.cu"

template<int D, bool S> static void dispatch(u64* tabs, int len, int stride,
    const u64* prm, int one, int lean, int fused, u64 r0, u64 r1, u64* out) {
    if (fused) {
        if (lean) fzl_fold_round_impl<D,S>(tabs,len/2,stride,r0,r1,prm,one,out);
        else fzc_fold_round_impl<D,S>(tabs,len/2,stride,r0,r1,prm,one,out);
    } else {
        if (lean) fzl_round_impl<D,S>(tabs,len/2,stride,prm,one,out);
        else fzc_round_impl<D,S>(tabs,len/2,stride,prm,one,out);
    }
}
extern "C" void calc_round(u64* tabs, int len, int stride, int degree,
    int supp, const u64* prm, int one, int lean, int fused, u64 r0, u64 r1,
    u64* out, u64* counts) {
    threadIdx.x = blockIdx.x = 0; blockDim.x = gridDim.x = 1;
    nread=nwrite=0;
    if (degree==4) {
        if (supp) dispatch<4,true>(tabs,len,stride,prm,one,lean,fused,r0,r1,out);
        else dispatch<4,false>(tabs,len,stride,prm,one,lean,fused,r0,r1,out);
    } else {
        if (supp) dispatch<5,true>(tabs,len,stride,prm,one,lean,fused,r0,r1,out);
        else dispatch<5,false>(tabs,len,stride,prm,one,lean,fused,r0,r1,out);
    }
    counts[0]=nread; counts[1]=nwrite;
}
extern "C" void calc_fold(u64* tabs, int len, int stride, int k,
    u64 r0, u64 r1, u64* counts) {
    nread=nwrite=0; blockIdx.x=0; blockDim.x=gridDim.x=1;
    for (int i=0;i<k*(len/2);i++) {
        threadIdx.x=i;
        k_sc_fold(tabs,k,len/2,stride,r0,r1);
    }
    threadIdx.x=0; counts[0]=nread; counts[1]=nwrite;
}
