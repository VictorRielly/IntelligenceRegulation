// [UPERF2-O] CUDA kernels of the GPU rung, step 3: the claim layer's stacked
// zero-check instances with the factor tables BUILT ON THE DEVICE from the
// compact operands, and the ixf round + fold on device-resident tables.
// Compiled at first use by NVRTC (cudarc), never by nvcc; its own module
// (`zkgpu_ixf`, ring/gpu/ixf.rs) — independent of lane L's kernels_k9.cu,
// whose K-field arithmetic header is COPIED below verbatim (lane N owns that
// file this round; the arithmetic is lane J's formulation, U_PERF2_KSIMD_
// REPORT.md Section 3, restated in kernels_k9.cu's header: canonical u32
// coefficients, 16x16 schoolbook in bursts of 4 folded by 2^32 == c32, the
// reduction h_t = canon1(fold31(acc_{t+16})), v = acc_t + s h_t, fold31 x2,
// canon1 — every stored coefficient the canonical representative of the
// same field expression, and canonical representatives are unique).
//
// WHAT THIS MODULE COMPUTES (== fold.rs `ixf_sumcheck_prove_packed` on the
// tables bg_zc_prove builds; U_PERF2_CLAIM2_REPORT.md Section 2.2):
//   * The three STACKED tables: element idx of table k = embed(to_mod(v))
//     with v the i64 witness value at (layer idx >> n_pos, row (idx & (np-1))
//     >> lcp, col (idx & (np-1)) & (cols_pad-1)) — zero for a pad layer, a
//     padded column or a row past the layer's rows (`k_oixf_build`); to_mod
//     is `Zq::to_mod` verbatim (C's truncated % == Rust's %).
//   * The EQ factor is never materialized: eq_t[i] = eqL_t[i & (2^a - 1)] x
//     eqH[i >> a] (a = the low bits still unbound; the multilinear eq is a
//     product of the eq over the low variables and the eq over the high
//     variables, and folding a variable of the low group folds only eqL —
//     the same field element per entry as folding the materialized table,
//     because folding = substituting the variable in a multilinear form);
//     when the low group is exhausted the remaining eq is a small table
//     G_t (<= 4096 elements) uploaded per round. Both small tables come
//     from the host's `kt_eq_table_par` (the same values as gkr::eq_table).
//   * The REQUANT SHIFT table sh~[idx] = sh[idx >> n_pos] is a per-slot
//     BROADCAST while position variables remain (its fold leaves it
//     unchanged: both pair elements are equal), the folded 16-slot layer
//     table L_t afterwards.
//   * The round: nodes x = 0..deg, node values from the pair (e0, e1) as
//     the CPU's e0 / e1 / e1 + (x-1)(e1 - e0); inner factor by kind (Had:
//     v1 v2 - v3; Rq: (v1 - v4 v2) - v3), term = eq x inner (canonical),
//     summed mod q per thread, block-reduced in a fixed order, one u64
//     atomic add of canonical values per (node, t) — reduced mod q on the
//     host: the same field element the CPU's exact planes finalize to
//     (reduction commutes with addition; lane L's Section 2.2 argument).
//   * The fold: out[i] = in[2i] + r (in[2i+1] - in[2i]) (kfold), out of
//     place, on the three stacked tables only.
// Layout of a packed table (kfield.rs module note): KL = 8 lanes per block,
// coefficient-major inside the block: coefficient j of lane l of block b at
// word b*128 + j*8 + l. Element e is lane e%8 of block e/8.

typedef unsigned long long u64;
typedef unsigned int u32;
typedef long long i64;

#define KDEG 16
#define KL 8
#define KBLK 128
#define M32 0xFFFFFFFFULL
#define M31 0x7FFFFFFFULL

#ifndef TOX
#define TOX 32
#endif
#ifndef OIXF_MINB
#define OIXF_MINB 1
#endif

// Kernel parameters (by value; == ixf.rs OixfParams, #[repr(C)]).
struct OP {
    u32 q, s, c31, c32;
    u32 kind;      // 1 had, 2 rq
    u32 deg;       // nodes = deg + 1 (<= 4)
    u32 eq_mode;   // 0: eqL[2p'..] x eqH[j] (lo_bits = unbound low variables of the pair index); 1: G[2p], G[2p+1]
    u32 lo_bits;   // eq_mode 0: p' = p & ((1 << lo_bits) - 1), j = p >> lo_bits  (lo_bits = a - 1 >= 0)
    u32 sh_mode;   // 0: none (had); 1: broadcast sh[p >> sh_shift]; 2: pair L[2p], L[2p+1]
    u32 sh_shift;
    u32 n_pairs;   // pairs per table this round
    u32 pad0;
};

// ---------------------------------------------------------------------------
// Lane-scalar primitives (== kernels_k9.cu / kfield.rs addm32 / subm32 / fold31 / canon).

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
__device__ __forceinline__ u32 canon1(u64 v, u32 q) {
    u32 r = (u32)v;
    u32 r2 = r - q;
    return (r < q) ? r : r2;
}

// acc[31] += a * b (16x16 schoolbook, burst-folded; == kernels_k9.cu kmac).
__device__ __forceinline__ void kmac(const u32* a, const u32* b, u64* acc, u32 c32) {
#pragma unroll
    for (int t = 0; t < 31; t++) {
        const int i0 = (t < 15) ? 0 : (t - 15);
        const int i1 = (t < 15) ? t : 15;
        u64 s = 0;
        int cnt = 0;
#pragma unroll
        for (int i = i0; i <= i1; i++) {
            s = madw(a[i], b[t - i], s);
            cnt++;
            if (cnt == 4) {
                acc[t] += madw(c32, (u32)(s >> 32), s & M32);
                s = 0;
                cnt = 0;
            }
        }
        if (cnt) acc[t] += madw(c32, (u32)(s >> 32), s & M32);
    }
}

// out[16] = canonical reduction of acc[31] (each acc_t < 2^45; == kred).
__device__ __forceinline__ void kred(const u64* acc, u32* out, u32 q, u32 s, u32 c31) {
    u32 h[15];
#pragma unroll
    for (int t = 0; t < 15; t++) h[t] = canon1(fold31(acc[t + 16], c31), q);
#pragma unroll
    for (int t = 0; t < 16; t++) {
        u64 v = (t < 15) ? madw(s, h[t], acc[t]) : acc[t];
        v = fold31(v, c31);
        v = fold31(v, c31);
        out[t] = canon1(v, q);
    }
}

// out = a * b (canonical). (A two-pass form with one live acc_t was tried:
// fewer live registers but less ILP — 3x SLOWER at the same occupancy; the
// 31-accumulator form stays.)
__device__ __forceinline__ void kmul(const u32* a, const u32* b, u32* out, const OP& P) {
    u64 acc[31];
#pragma unroll
    for (int t = 0; t < 31; t++) acc[t] = 0;
    kmac(a, b, acc, P.c32);
    kred(acc, out, P.q, P.s, P.c31);
}

// out = t0 + r (t1 - t0) (== fold_pair_blocks per lane, no add-constant).
__device__ __forceinline__ void kfold(const u32* t0, const u32* t1, const u32* r, u32* out, const OP& P) {
    u32 d[KDEG];
#pragma unroll
    for (int j = 0; j < KDEG; j++) d[j] = subm(t1[j], t0[j], P.q);
    u32 m[KDEG];
    kmul(d, r, m, P);
#pragma unroll
    for (int j = 0; j < KDEG; j++) out[j] = addm(t0[j], m[j], P.q);
}

// Coefficient j of the two consecutive lanes (2h, 2h+1) of block b.
__device__ __forceinline__ uint2 ld2(const u32* tab, u32 blk, u32 h, int j) {
    return *((const uint2*)(tab + (size_t)blk * KBLK + j * KL + 2 * h));
}
// Element e (all 16 coefficients).
__device__ __forceinline__ void ldel(const u32* tab, u32 e, u32* v) {
    const u32* p = tab + (size_t)(e >> 3) * KBLK + (e & 7);
#pragma unroll
    for (int j = 0; j < KDEG; j++) v[j] = p[j * KL];
}
__device__ __forceinline__ void stel(u32* tab, u32 e, const u32* v) {
    u32* p = tab + (size_t)(e >> 3) * KBLK + (e & 7);
#pragma unroll
    for (int j = 0; j < KDEG; j++) p[j * KL] = v[j];
}

// ---------------------------------------------------------------------------
// The stacked table build: element idx = embed(to_mod(value)) — coefficient
// 0 = the canonical residue, coefficients 1..15 = 0. Sources: the layers'
// i64 tensors concatenated in one device buffer, per-layer offsets (in
// elements) and rows in `lay` (u64 words: off[0..16], rows[16..32]).
//   li = idx >> n_pos; pos = idx & (np - 1); i = pos >> lcp; j = pos & (cols_pad - 1)
//   v = (li < n_layers && i < rows[li] && j < cols_real) ? src[off[li] + i * cols_real + j] : 0

extern "C" __global__ void k_oixf_build(const i64* __restrict__ src, const u64* __restrict__ lay, u32 n_layers, u32 n_pos, u32 lcp,
                                        u32 cols_real, u64 q, u32* __restrict__ dst, u32 n) {
    // One thread per element; a warp writes 32 consecutive elements = 4
    // blocks: coefficient 0 of 8 lanes per block are 8 consecutive words
    // (coalesced enough), the 15 zero planes are strided stores.
    for (u32 idx = blockIdx.x * blockDim.x + threadIdx.x; idx < n; idx += gridDim.x * blockDim.x) {
        u32 li = idx >> n_pos;
        u32 pos = idx & ((1u << n_pos) - 1u);
        u32 i = pos >> lcp;
        u32 j = pos & ((1u << lcp) - 1u);
        u32 v0 = 0;
        if (li < n_layers && j < cols_real && (u64)i < lay[16 + li]) {
            i64 v = src[lay[li] + (u64)i * cols_real + j];
            i64 r = v % (i64)q;
            if (r < 0) r += (i64)q;
            v0 = (u32)r;
        }
        u32* p = dst + (size_t)(idx >> 3) * KBLK + (idx & 7);
        p[0] = v0;
#pragma unroll
        for (int jj = 1; jj < KDEG; jj++) p[jj * KL] = 0;
    }
}

// ---------------------------------------------------------------------------
// The plain fold (== k_fold_table / kt_fold_par): out[i] = in[2i] + r (in[2i+1] - in[2i]).
// Thread = one output element i (in block i/4, slot i&3; out block i/8, lane i&7).

extern "C" __global__ void k_oixf_fold(OP P, const u32* __restrict__ rr16, const u32* __restrict__ in, u32* __restrict__ out, u32 n) {
    u32 rr[KDEG];
#pragma unroll
    for (int j = 0; j < KDEG; j++) rr[j] = rr16[j];
    for (u32 i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += gridDim.x * blockDim.x) {
        u32 t0[KDEG], t1[KDEG];
#pragma unroll
        for (int j = 0; j < KDEG; j++) {
            uint2 v = ld2(in, i >> 2, i & 3, j);
            t0[j] = v.x; t1[j] = v.y;
        }
        u32 o[KDEG];
        kfold(t0, t1, rr, o, P);
        stel(out, i, o);
    }
}

// ---------------------------------------------------------------------------
// The round. Per thread: one element pair p (elements 2p, 2p+1) per grid
// stride; the three stacked tables' (e1, dd) in shared memory (SoA by
// thread), the eq pair (e0, e1) formed from the small tables, the shift
// pair broadcast / from the small layer table. Node values as the CPU:
// x == 0 -> e0 = e1 - dd, x == 1 -> e1, x >= 2 -> e1 + (x-1) dd by successive
// modular adds. accn[x] += red(eq(x) * inner(x)) mod q.

#define SHW (3 * 2 * KDEG)
#define SH_AT(k, w, j) sh[(((k) * 2 + (w)) * KDEG + (j)) * TOX + threadIdx.x]

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
__device__ __forceinline__ void put_state(u32* sh, int k, const u32* e0, const u32* e1, u32 q) {
#pragma unroll
    for (int j = 0; j < KDEG; j++) {
        SH_AT(k, 0, j) = e1[j];
        SH_AT(k, 1, j) = subm(e1[j], e0[j], q);
    }
}
// Node value of a register-held pair (e0, e1) at x (dd computed here).
__device__ __forceinline__ void node_val_reg(const u32* e0, const u32* e1, u32 x, u32* v, u32 q) {
    if (x == 0) {
#pragma unroll
        for (int j = 0; j < KDEG; j++) v[j] = e0[j];
    } else {
#pragma unroll
        for (int j = 0; j < KDEG; j++) {
            u32 dd = subm(e1[j], e0[j], q);
            u32 c = e1[j];
            for (u32 xx = 1; xx < x; xx++) c = addm(c, dd, q);
            v[j] = c;
        }
    }
}

// out = s * b for a BASE-FIELD scalar s (a K-element with only coordinate 0
// set: the shift table's embed(2^shift) entries while position variables
// remain): the schoolbook has one product per output t < 16 and none above,
// so h_t = 0 and out[t] = canon1(fold31(fold31(fold32(s b_t)))) — exactly
// kmul's chain for that operand (the same intermediate integers), 16
// products instead of 256.
__device__ __forceinline__ void kmul_scalar(u32 s, const u32* b, u32* out, const OP& P) {
#pragma unroll
    for (int t = 0; t < KDEG; t++) {
        u64 pr = mulw(s, b[t]);
        u64 acc = madw(P.c32, (u32)(pr >> 32), pr & M32);
        acc = fold31(acc, P.c31);
        acc = fold31(acc, P.c31);
        out[t] = canon1(acc, P.q);
    }
}

// Block reduction of accn (mod q, fixed order within the block) + one u64
// atomic add of the canonical block sum per (node, t) into partial.
// (A grouped variant — the block's pairs sharing the eq high factor H[j],
// applied once to the block sum — was measured neutral-to-slower: the eq
// kmuls it saves are paid back by the fixed per-block grid and the extra
// atomics; removed.)
__device__ __forceinline__ void reduce_nodes(u32 accn[4][KDEG], u32 nn, u64* partial, u32 q) {
    __shared__ u32 red[4 * KDEG][TOX / 32];
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
    for (int idx = threadIdx.x; idx < (int)nn * KDEG; idx += TOX) {
        u32 v = red[idx][0];
#pragma unroll
        for (int w = 1; w < TOX / 32; w++) v = addm(v, red[idx][w], q);
        atomicAdd(partial + idx, (u64)v);
    }
}

extern "C" __global__ void __launch_bounds__(TOX, OIXF_MINB)
k_oixf_round(OP P, const u32* __restrict__ t1, const u32* __restrict__ t2, const u32* __restrict__ t3,
             const u32* __restrict__ eqA, const u32* __restrict__ eqB, const u32* __restrict__ shp, u64* partial) {
    __shared__ u32 sh[SHW * TOX];
    u32 accn[4][KDEG];
#pragma unroll
    for (int x = 0; x < 4; x++)
#pragma unroll
        for (int t = 0; t < KDEG; t++) accn[x][t] = 0;
    const int nd = (int)P.deg + 1;
    const u32 n = P.n_pairs;
    for (u32 p = blockIdx.x * TOX + threadIdx.x; p < n; p += gridDim.x * TOX) {
        // the three stacked tables' pairs -> shared (e1, dd)
        {
            u32 a0[KDEG], a1[KDEG];
#pragma unroll
            for (int j = 0; j < KDEG; j++) { uint2 v = ld2(t1, p >> 2, p & 3, j); a0[j] = v.x; a1[j] = v.y; }
            put_state(sh, 0, a0, a1, P.q);
#pragma unroll
            for (int j = 0; j < KDEG; j++) { uint2 v = ld2(t2, p >> 2, p & 3, j); a0[j] = v.x; a1[j] = v.y; }
            put_state(sh, 1, a0, a1, P.q);
#pragma unroll
            for (int j = 0; j < KDEG; j++) { uint2 v = ld2(t3, p >> 2, p & 3, j); a0[j] = v.x; a1[j] = v.y; }
            put_state(sh, 2, a0, a1, P.q);
        }
        // the eq pair (registers): mode 0 = eqL x H per pair; mode 1 = the
        // small table G.
        u32 q0[KDEG], q1[KDEG];
        if (P.eq_mode == 0) {
            const u32 pp = p & ((1u << P.lo_bits) - 1u);
            const u32 j = p >> P.lo_bits;
            u32 l0[KDEG], l1[KDEG], h1[KDEG];
#pragma unroll
            for (int jj = 0; jj < KDEG; jj++) { uint2 v = ld2(eqA, pp >> 2, pp & 3, jj); l0[jj] = v.x; l1[jj] = v.y; }
            ldel(eqB, j, h1);
            kmul(l0, h1, q0, P);
            kmul(l1, h1, q1, P);
        } else {
#pragma unroll
            for (int jj = 0; jj < KDEG; jj++) { uint2 v = ld2(eqA, p >> 2, p & 3, jj); q0[jj] = v.x; q1[jj] = v.y; }
        }
        // The node loop is unrolled over the maximum node count (4) with a
        // guard, so `accn[x]` is a static register index (a runtime bound
        // would push the accumulators to local memory).
#pragma unroll
        for (int x = 0; x < 4; x++) {
            if (x >= nd) break;
            u32 inner[KDEG];
            if (P.kind == 1) {
                u32 v1[KDEG], v2[KDEG];
                node_val(sh, 0, x, v1, P.q);
                node_val(sh, 1, x, v2, P.q);
                kmul(v1, v2, inner, P);
                u32 v3[KDEG];
                node_val(sh, 2, x, v3, P.q);
#pragma unroll
                for (int j = 0; j < KDEG; j++) inner[j] = subm(inner[j], v3[j], P.q);
            } else {
                u32 v2[KDEG];
                node_val(sh, 1, x, v2, P.q);
                if (P.sh_mode == 1) {
                    // the shift is a per-slot base-field scalar (both pair
                    // elements equal: every node value is that scalar)
                    const u32 s4 = shp[(size_t)((p >> P.sh_shift) >> 3) * KBLK + ((p >> P.sh_shift) & 7)];
                    kmul_scalar(s4, v2, inner, P);
                } else {
                    u32 s0[KDEG], s1[KDEG], v4[KDEG];
#pragma unroll
                    for (int jj = 0; jj < KDEG; jj++) { uint2 v = ld2(shp, p >> 2, p & 3, jj); s0[jj] = v.x; s1[jj] = v.y; }
                    node_val_reg(s0, s1, x, v4, P.q);
                    kmul(v4, v2, inner, P);
                }
                u32 v1[KDEG], v3[KDEG];
                node_val(sh, 0, x, v1, P.q);
                node_val(sh, 2, x, v3, P.q);
#pragma unroll
                for (int j = 0; j < KDEG; j++) inner[j] = subm(subm(v1[j], inner[j], P.q), v3[j], P.q);
            }
            u32 v0[KDEG], tm[KDEG];
            node_val_reg(q0, q1, x, v0, P.q);
            kmul(v0, inner, tm, P);
#pragma unroll
            for (int t = 0; t < KDEG; t++) accn[x][t] = addm(accn[x][t], tm[t], P.q);
        }
    }
    reduce_nodes(accn, (u32)nd, partial, P.q);
}
