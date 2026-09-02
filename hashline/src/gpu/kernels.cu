// [UPERF3-XX] hashline's CUDA kernels — compiled at first use by NVRTC
// (cudarc), never by nvcc. Rules of this file:
//   * Goldilocks arithmetic yields the CANONICAL representative in [0, p)
//     of the same field expression the CPU computes (field.rs), so every
//     value is identical to the CPU's by uniqueness of representatives.
//     The reduction is the CPU's reduce128 (x = lo + 2^64 hi, hi = 2^32
//     hi_hi + hi_lo, 2^64 == EPS, 2^96 == -1 mod p: x == lo + EPS*hi_lo
//     - hi_hi) with the same borrow / carry adjustments.
//   * No __int128 (NVRTC has none by default): 64 x 64 -> 128 products
//     via __umul64hi.
// Types: u64 = unsigned long long throughout (matches Rust u64).

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

// F_{p^2} = F_p[u] / (u^2 - 7): (c0, c1).
struct f2 { u64 c0, c1; };

__device__ __forceinline__ f2 f2_add(f2 a, f2 b) { f2 r; r.c0 = gl_add(a.c0, b.c0); r.c1 = gl_add(a.c1, b.c1); return r; }
__device__ __forceinline__ f2 f2_sub(f2 a, f2 b) { f2 r; r.c0 = gl_sub(a.c0, b.c0); r.c1 = gl_sub(a.c1, b.c1); return r; }
__device__ __forceinline__ f2 f2_mul(f2 a, f2 b) {
    u64 ac = gl_mul(a.c0, b.c0);
    u64 bd = gl_mul(a.c1, b.c1);
    u64 ad = gl_mul(a.c0, b.c1);
    u64 bc = gl_mul(a.c1, b.c0);
    f2 r;
    r.c0 = gl_add(ac, gl_mul(bd, NONRES));
    r.c1 = gl_add(ad, bc);
    return r;
}
__device__ __forceinline__ f2 f2_mul_base(f2 a, u64 b) { f2 r; r.c0 = gl_mul(a.c0, b); r.c1 = gl_mul(a.c1, b); return r; }
__device__ __forceinline__ f2 f2_zero() { f2 r; r.c0 = 0; r.c1 = 0; return r; }

// ---------------------------------------------------------------------------
// The probe: mul / add / sub of canonical pairs, compared on the host
// against field.rs.

extern "C" __global__ void k_probe(const u64* a, const u64* b, u64* om, u64* oa, u64* os, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    u64 x = a[i], y = b[i];
    om[i] = gl_mul(x, y);
    oa[i] = gl_add(x, y);
    os[i] = gl_sub(x, y);
}
