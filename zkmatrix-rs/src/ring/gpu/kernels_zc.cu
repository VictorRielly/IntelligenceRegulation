// [UPERF3-RR] U-PERF3 round 10, lane RR — Stage A's aggregate zero-check
// (zc_range::zc_agg_prove_masked's round loop) on the device. Compiled at
// first use by NVRTC (cudarc), never by nvcc; its own module (`zkgpu_zc`,
// ring/gpu/zc_agg.rs) — independent of the k9 / ixf modules, whose lane-
// scalar primitives (addm / subm / mulw / madw / fold31 / canon1) are copied
// verbatim below.
//
// WHAT THIS MODULE COMPUTES (== zc_range.rs round_sums / fold_base /
// fold_ext / build_eq_full + compact_even on the stacked instance):
//   * E_c = F_q[Z] / (Z^c - s) with c = ZC_C (4: the pass's SubExt::new(kf,
//     4)); an element = c canonical u32 coordinates. E x E: schoolbook c^2
//     products, each folded by 2^32 == c32 into a < 2^40 term (<= c terms
//     per output coefficient, < 2^42), then the CPU's red_planes chain:
//     h_t = canon(fold31(fold31(acc_{t+c}))), out_t = canon(fold31(fold31(
//     acc_t + s h_t))) — every stored coordinate is the canonical
//     representative of the same field expression as the CPU's split-plane
//     accumulate + e_red_block, and canonical representatives are unique.
//   * base x E (a scalar times an element): per coordinate mulm = the CPU's
//     mulm (fold31 twice, canon).
//   * The round (round_sums): per pair p (elements 2p, 2p+1 of every table)
//     and node x: v_k(x) = a + x (b - a) per table (extrap_lanes); for a
//     plane k < w: f = prod_a (v - alpha_a) (f_chain: the alphabet is
//     subtracted from coordinate 0 only), acc[k] += eq[p] * f; rec -=
//     2^(e0 k) v (rec_sub_scaled); for the rem table k = w: rec += v,
//     acc[w] += eq[p] * rec. Sums mod q per thread, block-reduced in a
//     fixed order, one u64 atomic add of the canonical block sum per
//     (node, constraint, coordinate) into `partial` — reduced mod q on the
//     host: the same field element the CPU's exact planes finalize to
//     (reduction commutes with addition). Round 0 reads BASE tables (plain
//     u32, the committed residues; values and f are base-field scalars,
//     eq x f = a scalar scaling) — k_zc_round_base; later rounds read E
//     tables — k_zc_round_ext.
//   * The fold: out[i] = in[2i] + r (in[2i+1] - in[2i]) — k_zc_fold_base
//     (base in, E out: coordinate 0 carries a, every coordinate carries
//     (b - a) r_j) and k_zc_fold_ext (E in, E out), out of place.
//   * The eq table at PAIR granularity: eq_pairs[p] = A[(2p) & mask] x
//     B[(2p) >> hl] from the two half tables (build_eq_full's A / B, built on
//     the host: 2^hl + 2^(n-hl) elements) — k_zc_eq_build; per round the
//     even-lane compaction eq'[i] = eq[2i] — k_zc_eq_compact.
// Layout of an E table (zc_range.rs ETab): KL = 8 lanes per block,
// coordinate-major inside the block: coordinate j of lane l of block b at
// word b*c*8 + j*8 + l. Element e is lane e%8 of block e/8; the pair
// (2p, 2p+1) is lanes 2(p%4), 2(p%4)+1 of block p/4 (adjacent words).
// A base table is a plain u32 array (element i at word i).

typedef unsigned long long u64;
typedef unsigned int u32;

#define KL 8
#define M32 0xFFFFFFFFULL
#define M31 0x7FFFFFFFULL

#ifndef ZC_C
#define ZC_C 4
#endif
#define C ZC_C
// Tables held in registers per thread: w + 1 <= WMAX (the pass's classes
// have w <= 10).
#define WMAX 12
#ifndef TZC
#define TZC 128
#endif
#define TEL 128

// Kernel parameters (by value; == zc_agg.rs ZcParams, #[repr(C)]).
struct ZP {
    u32 q, s, c31, c32;
    u32 w;          // planes; tables = w + 1
    u32 nalpha;     // alphabet size deg_f (<= 4)
    u32 nn;         // nodes this round (<= 4)
    u32 n_pairs;    // pairs per table this round
    u32 nodes[4];   // node values x (canonical residues)
    u32 alpha[4];   // the alphabet residues
    u32 pow2[WMAX]; // 2^(e0 k) mod q, k < w
};

// ---------------------------------------------------------------------------
// Lane-scalar primitives (== zc_range.rs addm32 / subm32 / fold31 / canon32 / mulm).

__device__ __forceinline__ u32 addm(u32 a, u32 b, u32 q) {
    u32 s = a + b;
    u32 t = s - q;
    return (s < q) ? s : t;
}
__device__ __forceinline__ u32 subm(u32 a, u32 b, u32 q) {
    u32 d = a - b;
    u32 e = d + q;
    return (a >= b) ? d : e;
}
__device__ __forceinline__ u64 mulw(u32 a, u32 b) {
    u64 r;
    asm("mul.wide.u32 %0, %1, %2;" : "=l"(r) : "r"(a), "r"(b));
    return r;
}
__device__ __forceinline__ u64 madw(u32 a, u32 b, u64 c) {
    u64 r;
    asm("mad.wide.u32 %0, %1, %2, %3;" : "=l"(r) : "r"(a), "r"(b), "l"(c));
    return r;
}
__device__ __forceinline__ u64 fold31(u64 v, u32 c31) {
    return madw(c31, (u32)(v >> 31), v & M31);
}
// One conditional subtraction: valid for v < 2q (every use below feeds a
// value < 2^31 + 2^21 after two fold31 steps).
__device__ __forceinline__ u32 canon1(u64 v, u32 q) {
    u32 r = (u32)v;
    u32 r2 = r - q;
    return (r < q) ? r : r2;
}
// a * b canonical (== mulm: p < 2^62 -> fold31 x2 -> canon).
__device__ __forceinline__ u32 mulm(u32 a, u32 b, const ZP& P) {
    u64 p = mulw(a, b);
    p = fold31(p, P.c31);
    p = fold31(p, P.c31);
    return canon1(p, P.q);
}

// ---------------------------------------------------------------------------
// E_c arithmetic on register arrays of C coordinates.

// out = a * b (canonical; == SubExt::mul / e_mac + e_red_block).
__device__ __forceinline__ void emul(const u32* a, const u32* b, u32* out, const ZP& P) {
    u64 acc[2 * C - 1];
#pragma unroll
    for (int t = 0; t < 2 * C - 1; t++) acc[t] = 0;
#pragma unroll
    for (int i = 0; i < C; i++)
#pragma unroll
        for (int j = 0; j < C; j++) {
            u64 p = mulw(a[i], b[j]);
            acc[i + j] += madw(P.c32, (u32)(p >> 32), p & M32);
        }
    u32 h[C - 1];
#pragma unroll
    for (int t = 0; t < C - 1; t++) h[t] = canon1(fold31(fold31(acc[t + C], P.c31), P.c31), P.q);
#pragma unroll
    for (int t = 0; t < C; t++) {
        u64 v = (t < C - 1) ? madw(P.s, h[t], acc[t]) : acc[t];
        v = fold31(v, P.c31);
        v = fold31(v, P.c31);
        out[t] = canon1(v, P.q);
    }
}
// out = x * b for a base-field scalar x (== SubExt::scale / e_mac_base).
__device__ __forceinline__ void escale(u32 x, const u32* b, u32* out, const ZP& P) {
#pragma unroll
    for (int t = 0; t < C; t++) out[t] = mulm(x, b[t], P);
}
// v = a + x (b - a) per coordinate (== extrap_lanes on the ext path).
__device__ __forceinline__ void eextrap(const u32* a, const u32* b, u32 x, u32* v, const ZP& P) {
#pragma unroll
    for (int t = 0; t < C; t++) v[t] = addm(a[t], mulm(x, subm(b[t], a[t], P.q), P), P.q);
}
// f = prod_a (v - alpha_a): the alphabet lives in coordinate 0 (== the CPU
// ext-round f chain: ef = ev - alpha_0 on coordinate 0, then E x E products
// with (ev - alpha) per further alpha, each reduced canonical).
__device__ __forceinline__ void efchain(const u32* v, u32* f, const ZP& P) {
#pragma unroll
    for (int t = 0; t < C; t++) f[t] = v[t];
    f[0] = subm(f[0], P.alpha[0], P.q);
#pragma unroll
    for (int a = 1; a < 4; a++) {
        if (a >= (int)P.nalpha) break;
        u32 et[C];
#pragma unroll
        for (int t = 0; t < C; t++) et[t] = v[t];
        et[0] = subm(et[0], P.alpha[a], P.q);
        u32 nf[C];
        emul(f, et, nf, P);
#pragma unroll
        for (int t = 0; t < C; t++) f[t] = nf[t];
    }
}

// E-table element access (ETab layout).
__device__ __forceinline__ void ld_e(const u32* tab, u32 e, u32* v) {
    const u32* p = tab + (size_t)(e >> 3) * (C * KL) + (e & 7);
#pragma unroll
    for (int j = 0; j < C; j++) v[j] = p[j * KL];
}
__device__ __forceinline__ void st_e(u32* tab, u32 e, const u32* v) {
    u32* p = tab + (size_t)(e >> 3) * (C * KL) + (e & 7);
#pragma unroll
    for (int j = 0; j < C; j++) p[j * KL] = v[j];
}
// The pair (2p, 2p+1) of an E table: lanes 2(p&3), 2(p&3)+1 of block p>>2.
__device__ __forceinline__ void ld_pair_e(const u32* tab, u32 p, u32* a, u32* b) {
    const u32* base = tab + (size_t)(p >> 2) * (C * KL) + 2 * (p & 3);
#pragma unroll
    for (int j = 0; j < C; j++) {
        uint2 v = *((const uint2*)(base + j * KL));
        a[j] = v.x;
        b[j] = v.y;
    }
}

// ---------------------------------------------------------------------------
// The block reduction: per (table k <= w, coordinate j) the thread sums
// (canonical) are warp-shuffled mod q, the warp leaders' values summed mod q
// across the block's warps in a fixed order, and one u64 atomic add of the
// canonical block sum lands in partial[(ni * (w + 1) + k) * C + j].

__device__ __forceinline__ void reduce_acc(u32 acc[WMAX][C], u32 ntab, u64* partial, u32 q) {
    __shared__ u32 red[WMAX * C][TZC / 32];
    const int lane = threadIdx.x & 31, wid = threadIdx.x >> 5;
#pragma unroll
    for (int k = 0; k < WMAX; k++) {
        if (k >= (int)ntab) break;
#pragma unroll
        for (int j = 0; j < C; j++) {
            u32 v = acc[k][j];
#pragma unroll
            for (int o = 16; o > 0; o >>= 1) {
                u32 u = __shfl_down_sync(0xffffffffu, v, o);
                v = addm(v, u, q);
            }
            if (lane == 0) red[k * C + j][wid] = v;
        }
    }
    __syncthreads();
    const u64* base = partial + (size_t)blockIdx.y * ntab * C;
    for (int idx = threadIdx.x; idx < (int)(ntab * C); idx += TZC) {
        u32 v = red[idx][0];
#pragma unroll
        for (int w = 1; w < TZC / 32; w++) v = addm(v, red[idx][w], q);
        atomicAdd((u64*)(base + idx), (u64)v);
    }
}

// ---------------------------------------------------------------------------
// The BASE round (round 0): tables are plain u32 arrays; per pair the values
// v_k(x) and f are base-field scalars (the CPU's base path: extrap_lanes /
// f_chain_lanes / mac_base / rec_sub_scaled / rec_add), eq is E.
// grid.y = node index; `tabs` = the w + 1 table pointers (u64 words).

extern "C" __global__ void __launch_bounds__(TZC)
k_zc_round_base(ZP P, const u64* __restrict__ tabs, const u32* __restrict__ eq, u64* __restrict__ partial) {
    const int ni = blockIdx.y;
    const u32 x = P.nodes[ni];
    const u32 ntab = P.w + 1;
    u32 acc[WMAX][C];
#pragma unroll
    for (int k = 0; k < WMAX; k++)
#pragma unroll
        for (int j = 0; j < C; j++) acc[k][j] = 0;
    for (u32 p = blockIdx.x * TZC + threadIdx.x; p < P.n_pairs; p += gridDim.x * TZC) {
        u32 e[C];
        ld_e(eq, p, e);
        u32 rec = 0;
#pragma unroll
        for (int k = 0; k < WMAX; k++) {
            if (k >= (int)ntab) break;
            const u32* T = (const u32*)tabs[k];
            uint2 ab = *((const uint2*)(T + 2 * (size_t)p));
            u32 v = addm(ab.x, mulm(x, subm(ab.y, ab.x, P.q), P), P.q);
            if (k < (int)P.w) {
                u32 f = subm(v, P.alpha[0], P.q);
#pragma unroll
                for (int a = 1; a < 4; a++) {
                    if (a >= (int)P.nalpha) break;
                    f = mulm(f, subm(v, P.alpha[a], P.q), P);
                }
#pragma unroll
                for (int j = 0; j < C; j++) acc[k][j] = addm(acc[k][j], mulm(e[j], f, P), P.q);
                rec = subm(rec, mulm(P.pow2[k], v, P), P.q);
            } else {
                rec = addm(rec, v, P.q);
#pragma unroll
                for (int j = 0; j < C; j++) acc[k][j] = addm(acc[k][j], mulm(e[j], rec, P), P.q);
            }
        }
    }
    reduce_acc(acc, ntab, partial, P.q);
}

// The E round (rounds >= 1): tables are E tables.

extern "C" __global__ void __launch_bounds__(TZC)
k_zc_round_ext(ZP P, const u64* __restrict__ tabs, const u32* __restrict__ eq, u64* __restrict__ partial) {
    const int ni = blockIdx.y;
    const u32 x = P.nodes[ni];
    const u32 ntab = P.w + 1;
    u32 acc[WMAX][C];
#pragma unroll
    for (int k = 0; k < WMAX; k++)
#pragma unroll
        for (int j = 0; j < C; j++) acc[k][j] = 0;
    for (u32 p = blockIdx.x * TZC + threadIdx.x; p < P.n_pairs; p += gridDim.x * TZC) {
        u32 e[C];
        ld_e(eq, p, e);
        u32 rec[C];
#pragma unroll
        for (int j = 0; j < C; j++) rec[j] = 0;
#pragma unroll
        for (int k = 0; k < WMAX; k++) {
            if (k >= (int)ntab) break;
            const u32* T = (const u32*)tabs[k];
            u32 a[C], b[C], v[C], tm[C];
            ld_pair_e(T, p, a, b);
            eextrap(a, b, x, v, P);
            if (k < (int)P.w) {
                u32 f[C];
                efchain(v, f, P);
                emul(e, f, tm, P);
#pragma unroll
                for (int j = 0; j < C; j++) acc[k][j] = addm(acc[k][j], tm[j], P.q);
                u32 sv[C];
                escale(P.pow2[k], v, sv, P);
#pragma unroll
                for (int j = 0; j < C; j++) rec[j] = subm(rec[j], sv[j], P.q);
            } else {
#pragma unroll
                for (int j = 0; j < C; j++) rec[j] = addm(rec[j], v[j], P.q);
                emul(e, rec, tm, P);
#pragma unroll
                for (int j = 0; j < C; j++) acc[k][j] = addm(acc[k][j], tm[j], P.q);
            }
        }
    }
    reduce_acc(acc, ntab, partial, P.q);
}

// ---------------------------------------------------------------------------
// The folds. r = the C coordinates of the challenge (device buffer).

// base in (plain u32), E out: out[i] = a + r (b - a): coordinate 0 = a +
// d r_0, coordinate j = d r_j (== fold_base: lo[l] += a on plane 0, then
// mac_base_fixed, then e_red_block).
extern "C" __global__ void k_zc_fold_base(ZP P, const u32* __restrict__ r, const u32* __restrict__ in, u32* __restrict__ out, u32 n_out) {
    u32 rr[C];
#pragma unroll
    for (int j = 0; j < C; j++) rr[j] = r[j];
    for (u32 i = blockIdx.x * blockDim.x + threadIdx.x; i < n_out; i += gridDim.x * blockDim.x) {
        uint2 ab = *((const uint2*)(in + 2 * (size_t)i));
        u32 d = subm(ab.y, ab.x, P.q);
        u32 o[C];
#pragma unroll
        for (int j = 0; j < C; j++) o[j] = mulm(d, rr[j], P);
        o[0] = addm(o[0], ab.x, P.q);
        st_e(out, i, o);
    }
}

// E in, E out (== fold_ext).
extern "C" __global__ void k_zc_fold_ext(ZP P, const u32* __restrict__ r, const u32* __restrict__ in, u32* __restrict__ out, u32 n_out) {
    u32 rr[C];
#pragma unroll
    for (int j = 0; j < C; j++) rr[j] = r[j];
    for (u32 i = blockIdx.x * blockDim.x + threadIdx.x; i < n_out; i += gridDim.x * blockDim.x) {
        u32 a[C], b[C], d[C], m[C], o[C];
        ld_pair_e(in, i, a, b);
#pragma unroll
        for (int j = 0; j < C; j++) d[j] = subm(b[j], a[j], P.q);
        emul(d, rr, m, P);
#pragma unroll
        for (int j = 0; j < C; j++) o[j] = addm(a[j], m[j], P.q);
        st_e(out, i, o);
    }
}

// ---------------------------------------------------------------------------
// The eq table at pair granularity from the two half tables (plain arrays of
// C words per element): eq_pairs[p] = A[(2p) & mask] * B[(2p) >> hl].
extern "C" __global__ void k_zc_eq_build(ZP P, const u32* __restrict__ A, const u32* __restrict__ B, u32 hl, u32* __restrict__ out, u32 n_pairs) {
    const u32 mask = (1u << hl) - 1u;
    for (u32 p = blockIdx.x * blockDim.x + threadIdx.x; p < n_pairs; p += gridDim.x * blockDim.x) {
        const u32 x = 2 * p;
        u32 a[C], b[C], o[C];
#pragma unroll
        for (int j = 0; j < C; j++) {
            a[j] = A[(size_t)(x & mask) * C + j];
            b[j] = B[(size_t)(x >> hl) * C + j];
        }
        emul(a, b, o, P);
        st_e(out, p, o);
    }
}

// The even-lane compaction (== compact_even): out[i] = in[2i].
extern "C" __global__ void k_zc_eq_compact(const u32* __restrict__ in, u32* __restrict__ out, u32 n_out) {
    for (u32 i = blockIdx.x * blockDim.x + threadIdx.x; i < n_out; i += gridDim.x * blockDim.x) {
        u32 v[C], dummy[C];
        ld_pair_e(in, i, v, dummy);
        st_e(out, i, v);
    }
}
