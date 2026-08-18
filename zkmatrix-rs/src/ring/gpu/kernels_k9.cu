// [UPERF2-L] CUDA kernels of the GPU rung, step 2: the K-field lane kernels
// (kfield.rs's packed descent round / ixf round / fold / tree step) on the
// device. Compiled at first use by NVRTC (cudarc), never by nvcc.
//
// THE ARITHMETIC (== kfield.rs, lane J's formulation, U_PERF2_KSIMD_REPORT
// Section 3): K = Z_q[Y]/(Y^16 - s) with 2^30 < q < 2^31, c31 = 2^31 mod q
// (< 1024), c32 = 2 c31. Elements are 16 canonical u32 coefficients. A
// product is the 16x16 schoolbook: for output coefficient t the products
// a_i b_{t-i} (< 2^62 each) are summed in BURSTS of <= 4 exactly in u64,
// each burst s folded once by 2^32 == c32 into one u64 accumulator
// acc_t += (s & m32) + c32 (s >> 32) (< 2^42 per burst; <= 8 bursts per t
// for the two-product wire: acc_t < 2^45). The reduction lands the
// CANONICAL representative in [0, q): h_t = canon1(fold31(acc_{t+16}))
// (< 2^31 + 399 * 2^14 < 2q), v = acc_t + s h_t < 2^63, fold31 twice
// (< 2^41, then < 2^31 + 399 * 2^10 < 2q), canon1 — fold31(v) = (v & m31)
// + c31 (v >> 31) == v (mod q). Every stored coefficient is therefore the
// canonical representative of the same field expression the CPU body
// stores (fold t0 + r (t1 - t0) [+ c]; PL = p0 + lambda q0; the wire
// PL Q1 + P1 Q0; the tree step's pL qR + pR qL and qL qR; the ixf inner
// factors), and canonical representatives are unique — identical bytes.
//
// THE NODE SUMS: the CPU accumulates the products eq x wire in exact
// integer planes and reduces once per round (kt_round_g_finalize: per t
// (sum_t + s * (sum_{t+16} mod q)) mod q). Here every term eq x wire is
// reduced to its canonical value (the same chain) and the node value is
// the canonical SUM mod q of those terms (per thread, then a fixed-order
// block reduction, then a u64 atomic add of canonical values — < 2^49 —
// reduced mod q on the host): reduction commutes with addition, so the
// node value is the same field element the CPU's planes finalize to; the
// host deposits it into acc_lo[t*KL] (acc_hi = 0), which the caller's
// finalize returns unchanged. Round polynomials identical.
//
// Layout of a packed table (kfield.rs module note): KL = 8 lanes per block,
// coefficient-major inside the block: coefficient j of lane l of block b at
// word b*128 + j*8 + l. Element e is lane e%8 of block e/8.

typedef unsigned long long u64;
typedef unsigned int u32;

#define KDEG 16
#define KL 8
#define KBLK 128
#define M32 0xFFFFFFFFULL
#define M31 0x7FFFFFFFULL
#define CL_MEMBER 0x80000000u

// Threads per block of the round kernels (the per-thread state lives in
// static shared memory: 5 tables x (e1, dd) x 16 u32 = 640 B per thread).
#ifndef TK9
#define TK9 64
#endif
#define SH_WORDS (5 * 2 * KDEG)

// Kernel parameters (by value; == k9.rs K9Params, #[repr(C)]).
struct K9P {
    u32 q, s, c31, c32;
    u32 nn;            // nodes evaluated
    u32 nodes[5];      // the x values (0, 2, 3, ..)
    u32 has_fc;        // fold add-constants present
    u32 has_nc;        // node add-constants present
    u32 has_ee;        // eq scale E(e) present (extract modes)
    u32 mode;          // 0 fold, 1 extract, 2 extract-fold (informational)
    u32 kind;          // ixf kind (0 prod3, 1 had, 2 rq)
    u32 deg;           // ixf degree
    u32 pad0, pad1;
    u32 r[KDEG];       // the pending fold challenge r_prev (fold modes) / the fold r
    u32 lambda[KDEG];  // PL = p0 + lambda q0
    u32 ee[KDEG];      // E(e)
    u32 fc[4][KDEG];   // fold add-constants
    u32 nc[5][4][KDEG];// node add-constants [node][pl,p1,q0,q1]
};

// ---------------------------------------------------------------------------
// Lane-scalar primitives (== kfield.rs addm32 / subm32 / fold31 / canon).

__device__ __forceinline__ u32 addm(u32 a, u32 b, u32 q) {
    u32 s = a + b;          // < 2^32: both < q < 2^31
    u32 t = s - q;
    return (s < q) ? s : t;
}
__device__ __forceinline__ u32 subm(u32 a, u32 b, u32 q) {
    u32 d = a - b;
    u32 e = d + q;
    return (a >= b) ? d : e;
}
__device__ __forceinline__ u64 fold31(u64 v, u32 c31) {
    return (v & M31) + (u64)c31 * (v >> 31);
}
// v < 2q (and < 2^32): one conditional subtraction.
__device__ __forceinline__ u32 canon1(u64 v, u32 q) {
    u32 r = (u32)v;
    u32 r2 = r - q;
    return (r < q) ? r : r2;
}

// acc[31] += a * b (16x16 schoolbook, burst-folded; see the header).
__device__ __forceinline__ void kmac(const u32* a, const u32* b, u64* acc, u32 c32) {
#pragma unroll
    for (int t = 0; t < 31; t++) {
        const int i0 = (t < 15) ? 0 : (t - 15);
        const int i1 = (t < 15) ? t : 15;
        u64 s = 0;
        int cnt = 0;
#pragma unroll
        for (int i = i0; i <= i1; i++) {
            s += (u64)a[i] * (u64)b[t - i];
            cnt++;
            if (cnt == 4) {
                acc[t] += (s & M32) + (u64)c32 * (s >> 32);
                s = 0;
                cnt = 0;
            }
        }
        if (cnt) acc[t] += (s & M32) + (u64)c32 * (s >> 32);
    }
}

// out[16] = canonical reduction of acc[31] (each acc_t < 2^45).
__device__ __forceinline__ void kred(const u64* acc, u32* out, u32 q, u32 s, u32 c31) {
    u32 h[15];
#pragma unroll
    for (int t = 0; t < 15; t++) h[t] = canon1(fold31(acc[t + 16], c31), q);
#pragma unroll
    for (int t = 0; t < 16; t++) {
        u64 v = acc[t] + ((t < 15) ? (u64)s * (u64)h[t] : 0ULL);
        v = fold31(v, c31);
        v = fold31(v, c31);
        out[t] = canon1(v, q);
    }
}

// out = a * b (canonical).
__device__ __forceinline__ void kmul(const u32* a, const u32* b, u32* out, const K9P& P) {
    u64 acc[31];
#pragma unroll
    for (int t = 0; t < 31; t++) acc[t] = 0;
    kmac(a, b, acc, P.c32);
    kred(acc, out, P.q, P.s, P.c31);
}

// out = t0 + r (t1 - t0) [+ c] (== fold_pair_blocks per lane).
__device__ __forceinline__ void kfold(const u32* t0, const u32* t1, const u32* r, const u32* c, u32* out, const K9P& P) {
    u32 d[KDEG];
#pragma unroll
    for (int j = 0; j < KDEG; j++) d[j] = subm(t1[j], t0[j], P.q);
    u32 m[KDEG];
    kmul(d, r, m, P);
#pragma unroll
    for (int j = 0; j < KDEG; j++) {
        u32 v = addm(t0[j], m[j], P.q);
        out[j] = c ? addm(v, c[j], P.q) : v;
    }
}

// Load coefficient j of 4 consecutive lanes (lanes 4h..4h+3 of block b).
__device__ __forceinline__ uint4 ld4(const u32* tab, u32 blk, u32 h, int j) {
    return *((const uint4*)(tab + (size_t)blk * KBLK + j * KL + 4 * h));
}
__device__ __forceinline__ uint2 ld2(const u32* tab, u32 blk, u32 h, int j) {
    return *((const uint2*)(tab + (size_t)blk * KBLK + j * KL + 2 * h));
}
__device__ __forceinline__ void st2(u32* tab, u32 blk, u32 h, int j, u32 a, u32 b) {
    *((uint2*)(tab + (size_t)blk * KBLK + j * KL + 2 * h)) = make_uint2(a, b);
}

// ---------------------------------------------------------------------------
// The compact leaves (kfield::CompactLeaves::expand_blocks, per element):
// element E of the instance's leaf layer: words w0 = w[2E], w1 = w[2E+1];
// member (w1 bit 31): p = (1, 0..), q = (w0, w1 & ~bit31, alpha[2..]);
// dummy: p = 0, q = (1, 0..); exceptions (idx, p[16], q[16]) sorted override.

struct CLSrc {
    const u32* w;      // 2 words per leaf
    const u32* alpha;  // 16
    const u32* exc;    // n_exc x (1 + 16 + 16) words: idx, p, q
    u32 n_exc;
};

__device__ __forceinline__ void cl_get(const CLSrc& c, u32 E, u32* p, u32* q) {
    u32 w0 = c.w[2 * E], w1 = c.w[2 * E + 1];
    bool m = (w1 & CL_MEMBER) != 0;
#pragma unroll
    for (int j = 0; j < KDEG; j++) { p[j] = 0; q[j] = 0; }
    if (m) {
        p[0] = 1;
        q[0] = w0;
        q[1] = w1 & ~CL_MEMBER;
#pragma unroll
        for (int j = 2; j < KDEG; j++) q[j] = c.alpha[j];
    } else {
        q[0] = 1;
    }
    for (u32 k = 0; k < c.n_exc; k++) {
        const u32* e = c.exc + k * 33;
        if (e[0] == E) {
#pragma unroll
            for (int j = 0; j < KDEG; j++) { p[j] = e[1 + j]; q[j] = e[17 + j]; }
        }
    }
}

// ---------------------------------------------------------------------------
// The node loop of one element pair (== round_g5_pair per lane): the five
// tables' (e1, dd) sit in shared memory (SoA by thread); nodes x != 1:
// x == 0 -> e0 = e1 - dd, x >= 2 -> e1 + (x-1) dd by successive adds (the
// same canonical values as the CPU's running extrapolation); the masked
// add-constants; wire = PL Q1 + P1 Q0 (one reduction); term = eq x wire
// (canonical); accn[node] += term (mod q).

#define SH_AT(k, w, j) sh[(((k) * 2 + (w)) * KDEG + (j)) * TK9 + threadIdx.x]

__device__ __forceinline__ void node_val(const u32* sh, int k, u32 x, u32* v, u32 q) {
    if (x == 0) {
#pragma unroll
        for (int j = 0; j < KDEG; j++) v[j] = subm(SH_AT(k, 0, j), SH_AT(k, 1, j), q);
    } else {
#pragma unroll
        for (int j = 0; j < KDEG; j++) {
            u32 e1 = SH_AT(k, 0, j), dd = SH_AT(k, 1, j);
            u32 c = e1;
            for (u32 xx = 1; xx < x; xx++) c = addm(c, dd, q);
            v[j] = c;
        }
    }
}

__device__ __forceinline__ void node_loop(const u32* sh, const K9P& P, u32 accn[5][KDEG]) {
#pragma unroll 1
    for (int ni = 0; ni < (int)P.nn; ni++) {
        const u32 x = P.nodes[ni];
        u32 pl[KDEG], q1[KDEG];
        u64 acc[31];
#pragma unroll
        for (int t = 0; t < 31; t++) acc[t] = 0;
        node_val(sh, 1, x, pl, P.q);
        node_val(sh, 4, x, q1, P.q);
        if (P.has_nc) {
#pragma unroll
            for (int j = 0; j < KDEG; j++) { pl[j] = addm(pl[j], P.nc[ni][0][j], P.q); q1[j] = addm(q1[j], P.nc[ni][3][j], P.q); }
        }
        kmac(pl, q1, acc, P.c32);
        u32 p1[KDEG], q0[KDEG];
        node_val(sh, 2, x, p1, P.q);
        node_val(sh, 3, x, q0, P.q);
        if (P.has_nc) {
#pragma unroll
            for (int j = 0; j < KDEG; j++) { p1[j] = addm(p1[j], P.nc[ni][1][j], P.q); q0[j] = addm(q0[j], P.nc[ni][2][j], P.q); }
        }
        kmac(p1, q0, acc, P.c32);
        u32 w[KDEG];
        kred(acc, w, P.q, P.s, P.c31);
        u32 eq[KDEG];
        node_val(sh, 0, x, eq, P.q);
        u32 tm[KDEG];
        kmul(eq, w, tm, P);
#pragma unroll
        for (int t = 0; t < KDEG; t++) accn[ni][t] = addm(accn[ni][t], tm[t], P.q);
    }
}

// Block reduction of accn (mod q, fixed order within the block) + one u64
// atomic add of the canonical block sum per (node, t) into partial.
__device__ __forceinline__ void reduce_nodes(u32 accn[5][KDEG], u32 nn, u64* partial, u32 q) {
    __shared__ u32 red[5 * KDEG][TK9 / 32];
    const int lane = threadIdx.x & 31, wid = threadIdx.x >> 5;
#pragma unroll 1
    for (int ni = 0; ni < (int)nn; ni++) {
#pragma unroll
        for (int t = 0; t < KDEG; t++) {
            u32 v = accn[ni][t];
#pragma unroll
            for (int o = 16; o > 0; o >>= 1) {
                u32 u = __shfl_down_sync(0xffffffffu, v, o);
                v = addm(v, u, q);
            }
            if (lane == 0) red[ni * KDEG + t][wid] = v;
        }
    }
    __syncthreads();
    for (int idx = threadIdx.x; idx < (int)nn * KDEG; idx += TK9) {
        u32 v = red[idx][0];
#pragma unroll
        for (int w = 1; w < TK9 / 32; w++) v = addm(v, red[idx][w], q);
        atomicAdd(partial + idx, (u64)v);
    }
}

// Put (e1, dd) of table k for this thread into shared from (e0, e1).
__device__ __forceinline__ void put_state(u32* sh, int k, const u32* e0, const u32* e1, u32 q) {
#pragma unroll
    for (int j = 0; j < KDEG; j++) {
        SH_AT(k, 0, j) = e1[j];
        SH_AT(k, 1, j) = subm(e1[j], e0[j], q);
    }
}

// ---------------------------------------------------------------------------
// FUSE_FOLD: state-(t-1) -> state t (out-of-place), the node loop on state t.
// Thread = one state-t element pair i (elements 2i, 2i+1 = the fold of the
// state-(t-1) elements 4i..4i+3: block i/2, lanes 4(i&1)..); grid-stride
// over the launch's n pairs. in_k / out_k are the launch's (range's) first
// blocks; the five tables: eq, pl, p1, q0, q1.

extern "C" __global__ void k_fold_round(K9P P, const u32* in0, const u32* in1, const u32* in2, const u32* in3, const u32* in4,
                                        u32* out0, u32* out1, u32* out2, u32* out3, u32* out4, u32 n, u64* partial) {
    __shared__ u32 sh[SH_WORDS * TK9];
    u32 accn[5][KDEG];
#pragma unroll
    for (int ni = 0; ni < 5; ni++)
#pragma unroll
        for (int t = 0; t < KDEG; t++) accn[ni][t] = 0;
    const u32* ins[5] = {in0, in1, in2, in3, in4};
    u32* outs[5] = {out0, out1, out2, out3, out4};
    for (u32 i = blockIdx.x * TK9 + threadIdx.x; i < n; i += gridDim.x * TK9) {
        const u32 ib = i >> 1, ih = i & 1;    // source block, half
        const u32 ob = i >> 2, oh = i & 3;    // dest block, pair slot
#pragma unroll 1
        for (int k = 0; k < 5; k++) {
            u32 s0[KDEG], s1[KDEG], s2[KDEG], s3[KDEG];
#pragma unroll
            for (int j = 0; j < KDEG; j++) {
                uint4 v = ld4(ins[k], ib, ih, j);
                s0[j] = v.x; s1[j] = v.y; s2[j] = v.z; s3[j] = v.w;
            }
            const u32* c = (P.has_fc && k > 0) ? P.fc[k - 1] : (const u32*)0;
            u32 e0[KDEG], e1[KDEG];
            kfold(s0, s1, P.r, c, e0, P);
            kfold(s2, s3, P.r, c, e1, P);
#pragma unroll
            for (int j = 0; j < KDEG; j++) st2(outs[k], ob, oh, j, e0[j], e1[j]);
            put_state(sh, k, e0, e1, P.q);
        }
        node_loop(sh, P, accn);
    }
    reduce_nodes(accn, P.nn, partial, P.q);
}

// ---------------------------------------------------------------------------
// FUSE_EXTRACT (round 0): the tree layer read directly (packed: pp/qq are
// the instance's layer blocks from the range's first block; compact: the
// CLSrc with `e_base` = the range's first layer element), the b-part eq
// (eqb from the range's first state-0 element) times E(e); no writes.
// Thread = state-0 pair i: layer elements 4i..4i+3 (p0[2i] = L[4i], p1[2i]
// = L[4i+1], p0[2i+1] = L[4i+2], p1[2i+1] = L[4i+3]); eq elements 2i, 2i+1.

template <bool COMPACT>
__device__ __forceinline__ void extract_round_body(const K9P& P, const u32* pp, const u32* qq, CLSrc cl, u32 e_base,
                                                   const u32* eqb, u32 n, u64* partial) {
    __shared__ u32 sh[SH_WORDS * TK9];
    u32 accn[5][KDEG];
#pragma unroll
    for (int ni = 0; ni < 5; ni++)
#pragma unroll
        for (int t = 0; t < KDEG; t++) accn[ni][t] = 0;
    for (u32 i = blockIdx.x * TK9 + threadIdx.x; i < n; i += gridDim.x * TK9) {
        u32 pv[4][KDEG], qv[4][KDEG];
        if (COMPACT) {
#pragma unroll
            for (int u = 0; u < 4; u++) cl_get(cl, e_base + 4 * i + u, pv[u], qv[u]);
        } else {
            const u32 lb = i >> 1, lh = i & 1;
#pragma unroll
            for (int j = 0; j < KDEG; j++) {
                uint4 a = ld4(pp, lb, lh, j);
                uint4 b = ld4(qq, lb, lh, j);
                pv[0][j] = a.x; pv[1][j] = a.y; pv[2][j] = a.z; pv[3][j] = a.w;
                qv[0][j] = b.x; qv[1][j] = b.y; qv[2][j] = b.z; qv[3][j] = b.w;
            }
        }
        // eq: elements 2i, 2i+1 of eqb (block i/4, slot i&3), times E(e).
        {
            u32 a0[KDEG], a1[KDEG];
#pragma unroll
            for (int j = 0; j < KDEG; j++) {
                uint2 v = ld2(eqb, i >> 2, i & 3, j);
                a0[j] = v.x; a1[j] = v.y;
            }
            if (P.has_ee) {
                u32 b0[KDEG], b1[KDEG];
                kmul(a0, P.ee, b0, P);
                kmul(a1, P.ee, b1, P);
                put_state(sh, 0, b0, b1, P.q);
            } else {
                put_state(sh, 0, a0, a1, P.q);
            }
        }
        // PL = p0 + lambda q0 at state 0: pl[2i] from (pv[0], qv[0]), pl[2i+1] from (pv[2], qv[2]).
        {
            u32 m0[KDEG], m1[KDEG];
            kmul(qv[0], P.lambda, m0, P);
            kmul(qv[2], P.lambda, m1, P);
#pragma unroll
            for (int j = 0; j < KDEG; j++) { m0[j] = addm(pv[0][j], m0[j], P.q); m1[j] = addm(pv[2][j], m1[j], P.q); }
            put_state(sh, 1, m0, m1, P.q);
        }
        put_state(sh, 2, pv[1], pv[3], P.q); // p1
        put_state(sh, 3, qv[0], qv[2], P.q); // q0
        put_state(sh, 4, qv[1], qv[3], P.q); // q1
        node_loop(sh, P, accn);
    }
    reduce_nodes(accn, P.nn, partial, P.q);
}

extern "C" __global__ void k_extract_round(K9P P, const u32* pp, const u32* qq, const u32* eqb, u32 n, u64* partial) {
    CLSrc cl = {0, 0, 0, 0};
    extract_round_body<false>(P, pp, qq, cl, 0, eqb, n, partial);
}
extern "C" __global__ void k_extract_round_cl(K9P P, const u32* w, const u32* alpha, const u32* exc, u32 n_exc, u32 e_base,
                                              const u32* eqb, u32 n, u64* partial) {
    CLSrc cl = {w, alpha, exc, n_exc};
    extract_round_body<true>(P, 0, 0, cl, e_base, eqb, n, partial);
}

// ---------------------------------------------------------------------------
// FUSE_EXTRACT_FOLD (round 1): the tree layer read directly, folded with
// r_0 (+ the masked add-constants on p0/p1/q0/q1), PL_1 = p0_1 + lambda
// q0_1, the eq = fold(eqb) x E(e); writes the five STATE-1 tables (out_k
// from the range's first block). Thread = state-1 pair i: layer elements
// 8i..8i+7 (block i): p0 state-0 = L[8i], L[8i+2], L[8i+4], L[8i+6]; p1 =
// the odd ones; eq state-0 elements 4i..4i+3.

template <bool COMPACT>
__device__ __forceinline__ void extract_fold_body(const K9P& P, const u32* pp, const u32* qq, CLSrc cl, u32 e_base, const u32* eqb,
                                                  u32* out0, u32* out1, u32* out2, u32* out3, u32* out4, u32 n, u64* partial) {
    __shared__ u32 sh[SH_WORDS * TK9];
    u32 accn[5][KDEG];
#pragma unroll
    for (int ni = 0; ni < 5; ni++)
#pragma unroll
        for (int t = 0; t < KDEG; t++) accn[ni][t] = 0;
    for (u32 i = blockIdx.x * TK9 + threadIdx.x; i < n; i += gridDim.x * TK9) {
        const u32 ob = i >> 2, oh = i & 3;
        // eq: state-0 elements 4i..4i+3 -> fold -> x E(e).
        {
            u32 s0[KDEG], s1[KDEG], s2[KDEG], s3[KDEG];
#pragma unroll
            for (int j = 0; j < KDEG; j++) {
                uint4 v = ld4(eqb, i >> 1, i & 1, j);
                s0[j] = v.x; s1[j] = v.y; s2[j] = v.z; s3[j] = v.w;
            }
            u32 f0[KDEG], f1[KDEG];
            kfold(s0, s1, P.r, 0, f0, P);
            kfold(s2, s3, P.r, 0, f1, P);
            if (P.has_ee) {
                u32 g0[KDEG], g1[KDEG];
                kmul(f0, P.ee, g0, P);
                kmul(f1, P.ee, g1, P);
#pragma unroll
                for (int j = 0; j < KDEG; j++) st2(out0, ob, oh, j, g0[j], g1[j]);
                put_state(sh, 0, g0, g1, P.q);
            } else {
#pragma unroll
                for (int j = 0; j < KDEG; j++) st2(out0, ob, oh, j, f0[j], f1[j]);
                put_state(sh, 0, f0, f1, P.q);
            }
        }
        // p0/p1 (from the p layer) and q0/q1 (from the q layer), folded.
        u32 p0e0[KDEG], p0e1[KDEG], q0e0[KDEG], q0e1[KDEG];
#pragma unroll 1
        for (int which = 0; which < 2; which++) {
            u32 lv[8][KDEG];
            if (COMPACT) {
                u32 dump[KDEG];
#pragma unroll
                for (int u = 0; u < 8; u++) {
                    if (which == 0) cl_get(cl, e_base + 8 * i + u, lv[u], dump);
                    else cl_get(cl, e_base + 8 * i + u, dump, lv[u]);
                }
            } else {
                const u32* L = which == 0 ? pp : qq;
#pragma unroll
                for (int j = 0; j < KDEG; j++) {
                    uint4 a = ld4(L, i, 0, j);
                    uint4 b = ld4(L, i, 1, j);
                    lv[0][j] = a.x; lv[1][j] = a.y; lv[2][j] = a.z; lv[3][j] = a.w;
                    lv[4][j] = b.x; lv[5][j] = b.y; lv[6][j] = b.z; lv[7][j] = b.w;
                }
            }
            const u32* c0 = P.has_fc ? P.fc[which == 0 ? 0 : 2] : (const u32*)0; // p0 / q0
            const u32* c1 = P.has_fc ? P.fc[which == 0 ? 1 : 3] : (const u32*)0; // p1 / q1
            u32 a0[KDEG], a1[KDEG], b0[KDEG], b1[KDEG];
            kfold(lv[0], lv[2], P.r, c0, a0, P);  // x0 state-1 element 2i
            kfold(lv[4], lv[6], P.r, c0, a1, P);  // x0 state-1 element 2i+1
            kfold(lv[1], lv[3], P.r, c1, b0, P);  // x1
            kfold(lv[5], lv[7], P.r, c1, b1, P);
            if (which == 0) {
#pragma unroll
                for (int j = 0; j < KDEG; j++) { p0e0[j] = a0[j]; p0e1[j] = a1[j]; }
                // p1 -> table 2 (out2)
#pragma unroll
                for (int j = 0; j < KDEG; j++) st2(out2, ob, oh, j, b0[j], b1[j]);
                put_state(sh, 2, b0, b1, P.q);
            } else {
#pragma unroll
                for (int j = 0; j < KDEG; j++) { q0e0[j] = a0[j]; q0e1[j] = a1[j]; }
                // q0 -> table 3, q1 -> table 4
#pragma unroll
                for (int j = 0; j < KDEG; j++) { st2(out3, ob, oh, j, a0[j], a1[j]); st2(out4, ob, oh, j, b0[j], b1[j]); }
                put_state(sh, 3, a0, a1, P.q);
                put_state(sh, 4, b0, b1, P.q);
            }
        }
        // PL_1 = p0_1 + lambda q0_1 -> table 1.
        {
            u32 m0[KDEG], m1[KDEG];
            kmul(q0e0, P.lambda, m0, P);
            kmul(q0e1, P.lambda, m1, P);
#pragma unroll
            for (int j = 0; j < KDEG; j++) { m0[j] = addm(p0e0[j], m0[j], P.q); m1[j] = addm(p0e1[j], m1[j], P.q); }
#pragma unroll
            for (int j = 0; j < KDEG; j++) st2(out1, ob, oh, j, m0[j], m1[j]);
            put_state(sh, 1, m0, m1, P.q);
        }
        node_loop(sh, P, accn);
    }
    reduce_nodes(accn, P.nn, partial, P.q);
}

extern "C" __global__ void k_extract_fold(K9P P, const u32* pp, const u32* qq, const u32* eqb,
                                          u32* out0, u32* out1, u32* out2, u32* out3, u32* out4, u32 n, u64* partial) {
    CLSrc cl = {0, 0, 0, 0};
    extract_fold_body<false>(P, pp, qq, cl, 0, eqb, out0, out1, out2, out3, out4, n, partial);
}
extern "C" __global__ void k_extract_fold_cl(K9P P, const u32* w, const u32* alpha, const u32* exc, u32 n_exc, u32 e_base, const u32* eqb,
                                             u32* out0, u32* out1, u32* out2, u32* out3, u32* out4, u32 n, u64* partial) {
    CLSrc cl = {w, alpha, exc, n_exc};
    extract_fold_body<true>(P, 0, 0, cl, e_base, eqb, out0, out1, out2, out3, out4, n, partial);
}

// ---------------------------------------------------------------------------
// The plain fold (kt_fold_par): out[i] = in[2i] + r (in[2i+1] - in[2i]).
// Thread = one output element i (in block i/4, slot i&3; out block i/8, lane i&7).

extern "C" __global__ void k_fold_table(K9P P, const u32* in, u32* out, u32 n) {
    for (u32 i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += gridDim.x * blockDim.x) {
        u32 t0[KDEG], t1[KDEG];
#pragma unroll
        for (int j = 0; j < KDEG; j++) {
            uint2 v = ld2(in, i >> 2, i & 3, j);
            t0[j] = v.x; t1[j] = v.y;
        }
        u32 o[KDEG];
        kfold(t0, t1, P.r, 0, o, P);
        u32* dst = out + (size_t)(i >> 3) * KBLK + (i & 7);
#pragma unroll
        for (int j = 0; j < KDEG; j++) dst[j * KL] = o[j];
    }
}

// ---------------------------------------------------------------------------
// The tree step (tree_step_body per parent element): np = pL qR + pR qL
// (one reduction), nq = qL qR; parent e from children 2e, 2e+1.

extern "C" __global__ void k_tree_step(K9P P, const u32* cp, const u32* cq, u32* np, u32* nq, u32 n) {
    for (u32 e = blockIdx.x * blockDim.x + threadIdx.x; e < n; e += gridDim.x * blockDim.x) {
        u32 pl[KDEG], pr[KDEG], ql[KDEG], qr[KDEG];
#pragma unroll
        for (int j = 0; j < KDEG; j++) {
            uint2 a = ld2(cp, e >> 2, e & 3, j);
            uint2 b = ld2(cq, e >> 2, e & 3, j);
            pl[j] = a.x; pr[j] = a.y; ql[j] = b.x; qr[j] = b.y;
        }
        u64 acc[31];
#pragma unroll
        for (int t = 0; t < 31; t++) acc[t] = 0;
        kmac(pl, qr, acc, P.c32);
        kmac(pr, ql, acc, P.c32);
        u32 o[KDEG];
        kred(acc, o, P.q, P.s, P.c31);
        u32* dp = np + (size_t)(e >> 3) * KBLK + (e & 7);
#pragma unroll
        for (int j = 0; j < KDEG; j++) dp[j * KL] = o[j];
        kmul(ql, qr, o, P);
        u32* dq = nq + (size_t)(e >> 3) * KBLK + (e & 7);
#pragma unroll
        for (int j = 0; j < KDEG; j++) dq[j * KL] = o[j];
    }
}

// The tree step from the compact leaves (children 2e, 2e+1 expanded on the fly).
extern "C" __global__ void k_tree_step_cl(K9P P, const u32* w, const u32* alpha, const u32* exc, u32 n_exc, u32 e_base,
                                          u32* np, u32* nq, u32 n) {
    CLSrc cl = {w, alpha, exc, n_exc};
    for (u32 e = blockIdx.x * blockDim.x + threadIdx.x; e < n; e += gridDim.x * blockDim.x) {
        u32 pl[KDEG], pr[KDEG], ql[KDEG], qr[KDEG];
        cl_get(cl, e_base + 2 * e, pl, ql);
        cl_get(cl, e_base + 2 * e + 1, pr, qr);
        u64 acc[31];
#pragma unroll
        for (int t = 0; t < 31; t++) acc[t] = 0;
        kmac(pl, qr, acc, P.c32);
        kmac(pr, ql, acc, P.c32);
        u32 o[KDEG];
        kred(acc, o, P.q, P.s, P.c31);
        u32* dp = np + (size_t)(e >> 3) * KBLK + (e & 7);
#pragma unroll
        for (int j = 0; j < KDEG; j++) dp[j * KL] = o[j];
        kmul(ql, qr, o, P);
        u32* dq = nq + (size_t)(e >> 3) * KBLK + (e & 7);
#pragma unroll
        for (int j = 0; j < KDEG; j++) dq[j * KL] = o[j];
    }
}

// ---------------------------------------------------------------------------
// The ixf round (ixf_round_body per lane): nodes x = 0..=deg (all), the
// inner factor by kind, term = eq x inner (canonical), accn[x] += term.
// The five tables' (e0, e1) per thread in shared: SH_AT(k, 0) = e1,
// SH_AT(k, 1) = dd — the same node_val: x == 0 -> e0, x == 1 -> e1, x >= 2
// -> e1 + (x-1) dd (== the CPU's e1 / successive adds).

extern "C" __global__ void k_ixf_round(K9P P, const u32* t0, const u32* t1, const u32* t2, const u32* t3, const u32* t4, u32 n, u64* partial) {
    __shared__ u32 sh[SH_WORDS * TK9];
    u32 accn[5][KDEG];
#pragma unroll
    for (int x = 0; x < 5; x++)
#pragma unroll
        for (int t = 0; t < KDEG; t++) accn[x][t] = 0;
    const u32* tabs[5] = {t0, t1, t2, t3, t4};
    const int nt = (P.kind == 0) ? 3 : (P.kind == 1 ? 4 : 5);
    const int nd = (int)P.deg + 1;
    for (u32 i = blockIdx.x * TK9 + threadIdx.x; i < n; i += gridDim.x * TK9) {
#pragma unroll 1
        for (int k = 0; k < nt; k++) {
            u32 a0[KDEG], a1[KDEG];
#pragma unroll
            for (int j = 0; j < KDEG; j++) {
                uint2 v = ld2(tabs[k], i >> 2, i & 3, j);
                a0[j] = v.x; a1[j] = v.y;
            }
            put_state(sh, k, a0, a1, P.q);
        }
#pragma unroll 1
        for (int x = 0; x < nd; x++) {
            u32 inner[KDEG];
            if (P.kind == 0 || P.kind == 1) {
                u32 v1[KDEG], v2[KDEG];
                node_val(sh, 1, x, v1, P.q);
                node_val(sh, 2, x, v2, P.q);
                kmul(v1, v2, inner, P);
                if (P.kind == 1) {
                    u32 v3[KDEG];
                    node_val(sh, 3, x, v3, P.q);
#pragma unroll
                    for (int j = 0; j < KDEG; j++) inner[j] = subm(inner[j], v3[j], P.q);
                }
            } else {
                u32 v4[KDEG], v2[KDEG];
                node_val(sh, 4, x, v4, P.q);
                node_val(sh, 2, x, v2, P.q);
                kmul(v4, v2, inner, P);
                u32 v1[KDEG], v3[KDEG];
                node_val(sh, 1, x, v1, P.q);
                node_val(sh, 3, x, v3, P.q);
#pragma unroll
                for (int j = 0; j < KDEG; j++) inner[j] = subm(subm(v1[j], inner[j], P.q), v3[j], P.q);
            }
            u32 v0[KDEG], tm[KDEG];
            node_val(sh, 0, x, v0, P.q);
            kmul(v0, inner, tm, P);
#pragma unroll
            for (int t = 0; t < KDEG; t++) accn[x][t] = addm(accn[x][t], tm[t], P.q);
        }
    }
    reduce_nodes(accn, (u32)nd, partial, P.q);
}
