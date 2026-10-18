typedef unsigned long long u64;
typedef unsigned int u32;
typedef long long i64;
typedef int i32;
typedef unsigned char u8;

#define P_GL 0xFFFFFFFF00000001ULL
#define EPS_GL 0xFFFFFFFFULL
#define NONRES 7ULL

// ---------------------------------------------------------------------------
// Goldilocks primitives (== field.rs: reduce128 / add / sub / mul).

__device__ __forceinline__ u64 gl_reduce(u64 lo, u64 hi) {
    u64 hi_lo = hi & EPS_GL;
    u64 hi_hi = hi >> 32;
    u64 t = lo - hi_hi;
    if (lo < hi_hi) t -= EPS_GL;
    u64 t1 = (hi_lo << 32) - hi_lo; // hi_lo * (2^32 - 1), exact
    u64 r = t + t1;
    if (r < t) r += EPS_GL;
    if (r >= P_GL) r -= P_GL;
    return r;
}

__device__ __forceinline__ u64 gl_mul(u64 a, u64 b) {
    return gl_reduce(a * b, __umul64hi(a, b));
}

// a, b < p.
__device__ __forceinline__ u64 gl_add(u64 a, u64 b) {
    u64 s = a + b;
    if (s < a) s += EPS_GL;
    else if (s >= P_GL) s -= P_GL;
    return s;
}

// a, b < p.
__device__ __forceinline__ u64 gl_sub(u64 a, u64 b) {
    u64 d = a - b;
    if (a < b) d -= EPS_GL;
    return d;
}

