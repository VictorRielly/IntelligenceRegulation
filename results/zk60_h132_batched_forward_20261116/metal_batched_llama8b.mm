// metal_batched_llama8b.mm
// Consolidated Batch 5 (D80a Gate + H128 + H132):
//   1. Verbatim Stage-2 exact_int_gemm_simd_32x64 (metal_int_gemm.mm)
//   2. Verbatim Production hashline [A4] WPROD_SRC (k_wprod_sg_2x4, k_wprod_sg_4x2, k_wprod_int)
//   3. Upgraded exact_int_gemm_64x64_v2 (64x64x32, centered signed byte split skipping chi when hi==0,
//      hardware transpose_matrix coalesced weight loads for both [N,K] and [K,N], batched 1-barrier slab flush,
//      GROUP_M=8 L2/SLC tile swizzle, and exact associative SPLIT_K=4 reduction)
//   4. End-to-end host-i64 drop-in benchmark (including i64 range-check + NEON pack + page views + cmdbuf)
//   5. Resident 1-CommandBuffer Batched K=1,2,4,8 32-Layer Exact-Integer Llama-3-8B Forward + MPS FP16 baseline

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <arm_neon.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <vector>
#include <chrono>
#include <algorithm>

static const char* kBatch5ExactMSL = R"MSL(
#include <metal_stdlib>
#include <metal_simdgroup_matrix>
#include <metal_atomic>
using namespace metal;

// ============================================================================
// PART A: Verbatim Production hashline [A4] WPROD_SRC (src/gpu/metal.rs:4258-4475)
// ============================================================================
struct WProdArgs {
    uint t;       // output rows (true tokens)
    uint k;       // terms per output (the inner width)
    uint n;       // output columns (the outer width)
    uint kp;      // row stride of the packed activations, a multiple of WP_BK
    uint in_out;  // 1: w[i * n + j]; 0: w[j * k + i]
    uint os;      // row stride of the output
    ulong w_off;  // byte offset of w in its buffer
};

#define WP_BM 64
#define WP_BN 64
#define WP_BK 32
#define WP_SLAB_TILES 16
#define WP_INT_TILES 8

template <typename T>
inline void wp_weights(threadgroup T *b, device const char *w, constant WProdArgs &a, uint k0, uint n0, uint tid) {
    if (a.in_out != 0) {
        const uint r = tid >> 3, c = (tid & 7) * 8, i = k0 + r;
        for (uint e = 0; e < 8; e++) {
            const uint j = n0 + c + e;
            b[r * WP_BN + c + e] = (i < a.k && j < a.n) ? T(w[(ulong)i * a.n + j]) : T(0);
        }
    } else {
        const uint c = tid >> 2, r = (tid & 3) * 8, j = n0 + c;
        for (uint e = 0; e < 8; e++) {
            const uint i = k0 + r + e;
            b[(r + e) * WP_BN + c] = (i < a.k && j < a.n) ? T(w[(ulong)j * a.k + i]) : T(0);
        }
    }
}

template <uint FM, uint FN>
kernel void k_wprod_sg(device const short *x [[buffer(0)]],
                       device const char *wbuf [[buffer(1)]],
                       device long *out [[buffer(2)]],
                       constant WProdArgs &a [[buffer(3)]],
                       uint2 tg [[threadgroup_position_in_grid]],
                       uint tid [[thread_index_in_threadgroup]],
                       uint sg [[simdgroup_index_in_threadgroup]],
                       uint lane [[thread_index_in_simdgroup]]) {
    threadgroup float xlo[WP_BM * WP_BK];
    threadgroup float xhi[WP_BM * WP_BK];
    threadgroup float wt[WP_BK * WP_BN];
    threadgroup float scr[8 * 64];
    device const char *w = wbuf + a.w_off;
    const uint m0 = tg.y * WP_BM, n0 = tg.x * WP_BN;
    const uint sgn = WP_BN / (8 * FN);
    const uint r0 = (sg / sgn) * 8 * FM, c0 = (sg % sgn) * 8 * FN;
    simdgroup_float8x8 clo[FM][FN], chi[FM][FN];
    int2 ilo[FM][FN], ihi[FM][FN];
    for (uint i = 0; i < FM; i++) {
        for (uint j = 0; j < FN; j++) {
            clo[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            chi[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            ilo[i][j] = int2(0);
            ihi[i][j] = int2(0);
        }
    }
    threadgroup float *sc = scr + sg * 64;
    const uint nkt = (a.k + WP_BK - 1) / WP_BK;
    for (uint kt = 0; kt < nkt; kt++) {
        const uint k0 = kt * WP_BK;
        {
            const uint r = tid >> 2, c = (tid & 3) * 8;
            device const short *src = x + (ulong)(m0 + r) * a.kp + k0 + c;
            for (uint e = 0; e < 8; e++) {
                const int v = int(src[e]);
                const int lo = v & 255;
                xlo[r * WP_BK + c + e] = float(lo);
                xhi[r * WP_BK + c + e] = float((v - lo) / 256);
            }
        }
        wp_weights(wt, w, a, k0, n0, tid);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        for (uint kk = 0; kk < WP_BK; kk += 8) {
            simdgroup_float8x8 b[FN];
            for (uint j = 0; j < FN; j++) {
                simdgroup_load(b[j], wt + kk * WP_BN + c0 + j * 8, WP_BN);
            }
            for (uint i = 0; i < FM; i++) {
                simdgroup_float8x8 al, ah;
                simdgroup_load(al, xlo + (r0 + i * 8) * WP_BK + kk, WP_BK);
                simdgroup_load(ah, xhi + (r0 + i * 8) * WP_BK + kk, WP_BK);
                for (uint j = 0; j < FN; j++) {
                    simdgroup_multiply_accumulate(clo[i][j], al, b[j], clo[i][j]);
                    simdgroup_multiply_accumulate(chi[i][j], ah, b[j], chi[i][j]);
                }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if ((kt + 1) % WP_SLAB_TILES == 0 || kt + 1 == nkt) {
            for (uint i = 0; i < FM; i++) {
                for (uint j = 0; j < FN; j++) {
                    simdgroup_store(clo[i][j], sc, 8);
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    ilo[i][j] += int2(int(sc[2 * lane]), int(sc[2 * lane + 1]));
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    simdgroup_store(chi[i][j], sc, 8);
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    ihi[i][j] += int2(int(sc[2 * lane]), int(sc[2 * lane + 1]));
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    clo[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                    chi[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                }
            }
        }
    }
    for (uint i = 0; i < FM; i++) {
        for (uint j = 0; j < FN; j++) {
            const uint row = m0 + r0 + i * 8 + (lane >> 2);
            const uint col = n0 + c0 + j * 8 + 2 * (lane & 3);
            if (row < a.t) {
                device long *o = out + (ulong)row * a.os;
                if (col < a.n) {
                    o[col] = long(ihi[i][j].x) * 256 + long(ilo[i][j].x);
                }
                if (col + 1 < a.n) {
                    o[col + 1] = long(ihi[i][j].y) * 256 + long(ilo[i][j].y);
                }
            }
        }
    }
}

#define WP_SG_INSTANCE(NAME, FM, FN) \
template [[host_name(NAME)]] [[kernel]] void k_wprod_sg<FM, FN>( \
    device const short *x [[buffer(0)]], device const char *wbuf [[buffer(1)]], device long *out [[buffer(2)]], \
    constant WProdArgs &a [[buffer(3)]], uint2 tg [[threadgroup_position_in_grid]], uint tid [[thread_index_in_threadgroup]], \
    uint sg [[simdgroup_index_in_threadgroup]], uint lane [[thread_index_in_simdgroup]]);
WP_SG_INSTANCE("k_wprod_sg_4x2", 4, 2)
WP_SG_INSTANCE("k_wprod_sg_2x4", 2, 4)

kernel void k_wprod_int(device const short *x [[buffer(0)]],
                        device const char *wbuf [[buffer(1)]],
                        device long *out [[buffer(2)]],
                        constant WProdArgs &a [[buffer(3)]],
                        uint2 tg [[threadgroup_position_in_grid]],
                        uint tid [[thread_index_in_threadgroup]]) {
    threadgroup int4 xt4[WP_BK * WP_BM / 4];
    threadgroup int4 wt4[WP_BK * WP_BN / 4];
    threadgroup int *xt = (threadgroup int *)xt4;
    threadgroup int *wt = (threadgroup int *)wt4;
    device const char *w = wbuf + a.w_off;
    const uint m0 = tg.y * WP_BM, n0 = tg.x * WP_BN;
    const uint tr = tid >> 4, tc = tid & 15;
    int4 acc[4];
    long tot[4][4];
    for (uint i = 0; i < 4; i++) {
        acc[i] = int4(0);
        for (uint j = 0; j < 4; j++) {
            tot[i][j] = 0;
        }
    }
    const uint nkt = (a.k + WP_BK - 1) / WP_BK;
    for (uint kt = 0; kt < nkt; kt++) {
        const uint k0 = kt * WP_BK;
        {
            const uint r = tid >> 2, c = (tid & 3) * 8;
            device const short *src = x + (ulong)(m0 + r) * a.kp + k0 + c;
            for (uint e = 0; e < 8; e++) {
                xt[(c + e) * WP_BM + r] = int(src[e]);
            }
        }
        wp_weights(wt, w, a, k0, n0, tid);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        for (uint kk = 0; kk < WP_BK; kk++) {
            const int4 av = xt4[kk * (WP_BM / 4) + tr];
            const int4 bv = wt4[kk * (WP_BN / 4) + tc];
            acc[0] += av.x * bv;
            acc[1] += av.y * bv;
            acc[2] += av.z * bv;
            acc[3] += av.w * bv;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if ((kt + 1) % WP_INT_TILES == 0 || kt + 1 == nkt) {
            for (uint i = 0; i < 4; i++) {
                tot[i][0] += long(acc[i].x);
                tot[i][1] += long(acc[i].y);
                tot[i][2] += long(acc[i].z);
                tot[i][3] += long(acc[i].w);
                acc[i] = int4(0);
            }
        }
    }
    for (uint i = 0; i < 4; i++) {
        const uint row = m0 + tr * 4 + i;
        if (row < a.t) {
            for (uint j = 0; j < 4; j++) {
                const uint col = n0 + tc * 4 + j;
                if (col < a.n) {
                    out[(ulong)row * a.os + col] = tot[i][j];
                }
            }
        }
    }
}

// ============================================================================
// PART B: Verbatim Stage-2 Kernel (metal_int_gemm.mm: 32x64, 128 threads)
// ============================================================================
struct GemmParamsV2 {
    uint M;
    uint K;
    uint N;
    uint kp;       // row stride of X (either K or padded multiple of 32)
    uint is_i8;    // 1: X_raw is int8_t*, 0: X_raw is int16_t*
    uint in_out;   // 0: W is [N, K]; 1: W is [K, N]
    uint os;       // output row stride (usually N)
    uint split_k;  // 1 or 4
    ulong w_off;   // byte offset in W buffer
};

kernel void exact_int_gemm_simd_32x64(
    device const uchar* X_raw   [[buffer(0)]],
    device const char*  W_buf   [[buffer(1)]],
    device long*        C_i64   [[buffer(2)]],
    constant GemmParamsV2& p    [[buffer(3)]],
    uint tid                    [[thread_index_in_threadgroup]],
    uint sg_id                  [[simdgroup_index_in_threadgroup]],
    uint sg_lane                [[thread_index_in_simdgroup]],
    uint2 tgid                  [[threadgroup_position_in_grid]])
{
    threadgroup float A_lo[32][36];
    threadgroup float A_hi[32][36];
    threadgroup float Bt_smem[32][68];
    threadgroup float C_scratch[4][64];

    const uint m0 = tgid.y * 32U;
    const uint n0 = tgid.x * 64U;
    const uint M = p.M, K = p.K, N = p.N, kp = p.kp;
    const bool i8_mode = (p.is_i8 != 0U);
    device const char* W_i8 = W_buf + p.w_off;

    device const char* X_i8 = reinterpret_cast<device const char*>(X_raw);
    device const ushort* X_u16 = reinterpret_cast<device const ushort*>(X_raw);

    simdgroup_float8x8 acc_lo[4][2];
    simdgroup_float8x8 acc_hi[4][2];
    long i64_acc[16];
    for (uint i = 0; i < 16U; ++i) i64_acc[i] = 0L;
    for (uint r = 0; r < 4U; ++r) {
        for (uint c = 0; c < 2U; ++c) {
            acc_lo[r][c] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            if (!i8_mode) acc_hi[r][c] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
        }
    }

    const uint num_tiles = (K + 31U) >> 5;
    for (uint t = 0; t < num_tiles; ++t) {
        const uint k0 = t << 5;
        for (uint idx = tid; idx < 1024U; idx += 128U) {
            uint r_loc = idx >> 5, k_loc = idx & 31U;
            uint gm = m0 + r_loc, gk = k0 + k_loc;
            if (gm < M && gk < K) {
                ulong x_off = (ulong)gm * (ulong)kp + (ulong)gk;
                if (i8_mode) {
                    A_lo[r_loc][k_loc] = (float)X_i8[x_off];
                } else {
                    ushort u = X_u16[x_off];
                    short s_val = as_type<short>(u);
                    A_lo[r_loc][k_loc] = (float)(u & 0xFFU);
                    A_hi[r_loc][k_loc] = (float)(s_val >> 8);
                }
            } else {
                A_lo[r_loc][k_loc] = 0.0f;
                if (!i8_mode) A_hi[r_loc][k_loc] = 0.0f;
            }
        }
        for (uint idx = tid; idx < 2048U; idx += 128U) {
            uint n_loc = idx >> 5, k_loc = idx & 31U;
            uint gn = n0 + n_loc, gk = k0 + k_loc;
            if (gn < N && gk < K) {
                Bt_smem[k_loc][n_loc] = (p.in_out != 0U)
                    ? (float)W_i8[(ulong)gk * (ulong)N + (ulong)gn]
                    : (float)W_i8[(ulong)gn * (ulong)K + (ulong)gk];
            } else {
                Bt_smem[k_loc][n_loc] = 0.0f;
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        for (uint ks = 0; ks < 32U; ks += 8U) {
            simdgroup_float8x8 fragB0, fragB1;
            simdgroup_load(fragB0, &Bt_smem[ks][sg_id * 16U], 68);
            simdgroup_load(fragB1, &Bt_smem[ks][sg_id * 16U + 8U], 68);
            for (uint r = 0; r < 4U; ++r) {
                simdgroup_float8x8 fragA_lo;
                simdgroup_load(fragA_lo, &A_lo[r * 8U][ks], 36);
                simdgroup_multiply_accumulate(acc_lo[r][0], fragA_lo, fragB0, acc_lo[r][0]);
                simdgroup_multiply_accumulate(acc_lo[r][1], fragA_lo, fragB1, acc_lo[r][1]);
                if (!i8_mode) {
                    simdgroup_float8x8 fragA_hi;
                    simdgroup_load(fragA_hi, &A_hi[r * 8U][ks], 36);
                    simdgroup_multiply_accumulate(acc_hi[r][0], fragA_hi, fragB0, acc_hi[r][0]);
                    simdgroup_multiply_accumulate(acc_hi[r][1], fragA_hi, fragB1, acc_hi[r][1]);
                }
            }
        }

        if (((t + 1U) & 15U) == 0U || (t + 1U) == num_tiles) {
            for (uint r = 0; r < 4U; ++r) {
                for (uint c = 0; c < 2U; ++c) {
                    uint base_i = (r * 2U + c) * 2U;
                    simdgroup_store(acc_lo[r][c], &C_scratch[sg_id][0], 8);
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    long lo0 = (long)C_scratch[sg_id][sg_lane];
                    long lo1 = (long)C_scratch[sg_id][sg_lane + 32U];
                    acc_lo[r][c] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                    if (!i8_mode) {
                        simdgroup_barrier(mem_flags::mem_threadgroup);
                        simdgroup_store(acc_hi[r][c], &C_scratch[sg_id][0], 8);
                        simdgroup_barrier(mem_flags::mem_threadgroup);
                        long hi0 = (long)C_scratch[sg_id][sg_lane];
                        long hi1 = (long)C_scratch[sg_id][sg_lane + 32U];
                        acc_hi[r][c] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                        i64_acc[base_i + 0U] += hi0 * 256L + lo0;
                        i64_acc[base_i + 1U] += hi1 * 256L + lo1;
                    } else {
                        i64_acc[base_i + 0U] += lo0;
                        i64_acc[base_i + 1U] += lo1;
                    }
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    const uint row_in_8_0 = sg_lane >> 3;
    const uint row_in_8_1 = row_in_8_0 + 4U;
    const uint col_in_8   = sg_lane & 7U;
    for (uint r = 0; r < 4U; ++r) {
        for (uint c = 0; c < 2U; ++c) {
            uint base_i = (r * 2U + c) * 2U;
            uint gn = n0 + sg_id * 16U + c * 8U + col_in_8;
            if (gn < N) {
                uint gm0 = m0 + r * 8U + row_in_8_0;
                uint gm1 = m0 + r * 8U + row_in_8_1;
                if (gm0 < M) C_i64[(ulong)gm0 * (ulong)p.os + (ulong)gn] = i64_acc[base_i + 0U];
                if (gm1 < M) C_i64[(ulong)gm1 * (ulong)p.os + (ulong)gn] = i64_acc[base_i + 1U];
            }
        }
    }
}

// ============================================================================
// PART C: Specialized Exact-Integer GEMM Kernels (64x64x32, 256 threads)
//   1. k_wprod_fast_i8_2x4: Dedicated single-limb int8 activation kernel (8 simdgroup_float8x8
//      accumulators, no hi-limb branch around FMAs, 16 KiB shared RAM, FAST_WS=65
//      padded shared-memory weight stride for both [N,K] and [K,N], 2-barrier slab flush)
//   2. k_wprod_fast_i16_2x4: Dedicated two-limb int16 activation kernel (no branch around FMAs,
//      FAST_WS=65 padded shared-memory weight stride, 4-barrier slab flush vs 32)
// ============================================================================
#define FAST_WS 65U

inline void fast_load_weights_65(
    threadgroup float* wt, device const char* W_i8,
    uint K, uint N, uint in_out, uint k0, uint n0, uint tid)
{
    if (in_out != 0U) {
        const uint r = tid >> 3, c = (tid & 7U) << 3;
        const uint gk = k0 + r;
        if (gk < K && n0 + c + 8U <= N) {
            device const char* src = W_i8 + (ulong)gk * (ulong)N + (ulong)(n0 + c);
            for (uint e = 0; e < 8U; ++e) wt[r * FAST_WS + c + e] = float(src[e]);
        } else {
            for (uint e = 0; e < 8U; ++e) {
                const uint gn = n0 + c + e;
                wt[r * FAST_WS + c + e] = (gk < K && gn < N) ? float(W_i8[(ulong)gk * (ulong)N + gn]) : 0.0f;
            }
        }
    } else {
        const uint c = tid >> 2, r = (tid & 3U) << 3;
        const uint gn = n0 + c;
        if (gn < N && k0 + r + 8U <= K) {
            device const char* src = W_i8 + (ulong)gn * (ulong)K + (ulong)(k0 + r);
            for (uint e = 0; e < 8U; ++e) wt[(r + e) * FAST_WS + c] = float(src[e]);
        } else {
            for (uint e = 0; e < 8U; ++e) {
                const uint gk = k0 + r + e;
                wt[(r + e) * FAST_WS + c] = (gk < K && gn < N) ? float(W_i8[(ulong)gn * (ulong)K + gk]) : 0.0f;
            }
        }
    }
}

kernel void k_wprod_fast_i8_2x4(
    device const char*  X_i8    [[buffer(0)]],
    device const char*  W_buf   [[buffer(1)]],
    device long*        C_i64   [[buffer(2)]],
    constant GemmParamsV2& p    [[buffer(3)]],
    uint3 tgid                  [[threadgroup_position_in_grid]],
    uint tid                    [[thread_index_in_threadgroup]],
    uint sg                     [[simdgroup_index_in_threadgroup]],
    uint lane                   [[thread_index_in_simdgroup]])
{
    threadgroup float xlo[2048];
    threadgroup float wt[32U * FAST_WS]; // 2080 floats (>= 2048, reused as second half of slab flush!)

    const uint m0 = tgid.y * 64U;
    const uint n0 = tgid.x * 64U;
    const uint M = p.M, K = p.K, N = p.N, kp = p.kp;
    device const char* W_i8 = W_buf + p.w_off;

    const uint nkt_total = (K + 31U) >> 5;
    uint kt_begin = 0U, kt_end = nkt_total;
    if (p.split_k > 1U) {
        const uint total_slabs = (nkt_total + 15U) >> 4;
        const uint slabs_per_z = (total_slabs + p.split_k - 1U) / p.split_k;
        kt_begin = min(nkt_total, tgid.z * slabs_per_z * 16U);
        kt_end   = min(nkt_total, (tgid.z + 1U) * slabs_per_z * 16U);
    }

    const uint r0 = (sg >> 1) * 16U;
    const uint c0 = (sg & 1U) * 32U;

    simdgroup_float8x8 clo[2][4];
    int2 ilo[2][4];
    for (uint i = 0; i < 2U; ++i) {
        for (uint j = 0; j < 4U; ++j) {
            clo[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            ilo[i][j] = int2(0);
        }
    }

    for (uint kt = kt_begin; kt < kt_end; ++kt) {
        const uint k0 = kt << 5;
        {
            const uint r = tid >> 2, c = (tid & 3U) << 3;
            const uint gm = m0 + r;
            if (gm < M && k0 + c + 8U <= K) {
                device const char* src = X_i8 + (ulong)gm * (ulong)kp + (ulong)(k0 + c);
                for (uint e = 0; e < 8U; ++e) xlo[r * 32U + c + e] = float(src[e]);
            } else {
                for (uint e = 0; e < 8U; ++e) {
                    xlo[r * 32U + c + e] = (gm < M && k0 + c + e < K)
                        ? float(X_i8[(ulong)gm * (ulong)kp + (ulong)(k0 + c + e)]) : 0.0f;
                }
            }
        }
        fast_load_weights_65(wt, W_i8, K, N, p.in_out, k0, n0, tid);
        threadgroup_barrier(mem_flags::mem_threadgroup);

        for (uint kk = 0; kk < 32U; kk += 8U) {
            simdgroup_float8x8 b[4];
            for (uint j = 0; j < 4U; ++j) {
                simdgroup_load(b[j], wt + kk * FAST_WS + c0 + j * 8U, FAST_WS);
            }
            for (uint i = 0; i < 2U; ++i) {
                simdgroup_float8x8 al;
                simdgroup_load(al, xlo + (r0 + i * 8U) * 32U + kk, 32);
                for (uint j = 0; j < 4U; ++j) {
                    simdgroup_multiply_accumulate(clo[i][j], al, b[j], clo[i][j]);
                }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        if (((kt + 1U) & 15U) == 0U || (kt + 1U) == kt_end) {
            threadgroup float* sc0 = xlo + sg * 256U;
            threadgroup float* sc1 = wt  + sg * 256U;
            for (uint j = 0; j < 4U; ++j) {
                simdgroup_store(clo[0][j], sc0 + j * 64U, 8);
                simdgroup_store(clo[1][j], sc1 + j * 64U, 8);
                clo[0][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                clo[1][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (uint j = 0; j < 4U; ++j) {
                threadgroup const float* p0 = sc0 + j * 64U;
                threadgroup const float* p1 = sc1 + j * 64U;
                ilo[0][j] += int2((int)p0[2U * lane], (int)p0[2U * lane + 1U]);
                ilo[1][j] += int2((int)p1[2U * lane], (int)p1[2U * lane + 1U]);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
        }
    }

    const ulong slice_stride = (p.split_k > 1U) ? ((ulong)M * (ulong)p.os) : 0UL;
    device long* out_base = C_i64 + (ulong)tgid.z * slice_stride;
    for (uint i = 0; i < 2U; ++i) {
        for (uint j = 0; j < 4U; ++j) {
            const uint row = m0 + r0 + i * 8U + (lane >> 2);
            const uint col = n0 + c0 + j * 8U + 2U * (lane & 3U);
            if (row < M) {
                device long* o = out_base + (ulong)row * (ulong)p.os;
                if (col < N)      o[col]      = (long)ilo[i][j].x;
                if (col + 1U < N) o[col + 1U] = (long)ilo[i][j].y;
            }
        }
    }
}

kernel void k_wprod_fast_i16_2x4(
    device const short* X_i16   [[buffer(0)]],
    device const char*  W_buf   [[buffer(1)]],
    device long*        C_i64   [[buffer(2)]],
    constant GemmParamsV2& p    [[buffer(3)]],
    uint3 tgid                  [[threadgroup_position_in_grid]],
    uint tid                    [[thread_index_in_threadgroup]],
    uint sg                     [[simdgroup_index_in_threadgroup]],
    uint lane                   [[thread_index_in_simdgroup]])
{
    threadgroup float xlo[2048];
    threadgroup float xhi[2048];
    threadgroup float wt[32U * FAST_WS];

    const uint m0 = tgid.y * 64U;
    const uint n0 = tgid.x * 64U;
    const uint M = p.M, K = p.K, N = p.N, kp = p.kp;
    device const char* W_i8 = W_buf + p.w_off;

    const uint nkt_total = (K + 31U) >> 5;
    uint kt_begin = 0U, kt_end = nkt_total;
    if (p.split_k > 1U) {
        const uint total_slabs = (nkt_total + 8U - 1U) >> 3; // 8 tiles = 256 terms <= 255*128*256 < 2^24!
        const uint slabs_per_z = (total_slabs + p.split_k - 1U) / p.split_k;
        kt_begin = min(nkt_total, tgid.z * slabs_per_z * 8U);
        kt_end   = min(nkt_total, (tgid.z + 1U) * slabs_per_z * 8U);
    }

    const uint r0 = (sg >> 1) * 16U;
    const uint c0 = (sg & 1U) * 32U;

    simdgroup_float8x8 clo[2][4], chi[2][4];
    int2 ilo[2][4], ihi[2][4];
    for (uint i = 0; i < 2U; ++i) {
        for (uint j = 0; j < 4U; ++j) {
            clo[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            chi[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            ilo[i][j] = int2(0);
            ihi[i][j] = int2(0);
        }
    }

    for (uint kt = kt_begin; kt < kt_end; ++kt) {
        const uint k0 = kt << 5;
        {
            const uint r = tid >> 2, c = (tid & 3U) << 3;
            const uint gm = m0 + r;
            if (gm < M && k0 + c + 8U <= K) {
                device const short* src = X_i16 + (ulong)gm * (ulong)kp + (ulong)(k0 + c);
                for (uint e = 0; e < 8U; ++e) {
                    const int v = int(src[e]);
                    const int lo = v & 255;
                    xlo[r * 32U + c + e] = float(lo);
                    xhi[r * 32U + c + e] = float((v - lo) / 256);
                }
            } else {
                for (uint e = 0; e < 8U; ++e) {
                    const int v = (gm < M && k0 + c + e < K)
                        ? int(X_i16[(ulong)gm * (ulong)kp + (ulong)(k0 + c + e)]) : 0;
                    const int lo = v & 255;
                    xlo[r * 32U + c + e] = float(lo);
                    xhi[r * 32U + c + e] = float((v - lo) / 256);
                }
            }
        }
        fast_load_weights_65(wt, W_i8, K, N, p.in_out, k0, n0, tid);
        threadgroup_barrier(mem_flags::mem_threadgroup);

        for (uint kk = 0; kk < 32U; kk += 8U) {
            simdgroup_float8x8 b[4];
            for (uint j = 0; j < 4U; ++j) {
                simdgroup_load(b[j], wt + kk * FAST_WS + c0 + j * 8U, FAST_WS);
            }
            for (uint i = 0; i < 2U; ++i) {
                simdgroup_float8x8 al, ah;
                simdgroup_load(al, xlo + (r0 + i * 8U) * 32U + kk, 32);
                simdgroup_load(ah, xhi + (r0 + i * 8U) * 32U + kk, 32);
                for (uint j = 0; j < 4U; ++j) {
                    simdgroup_multiply_accumulate(clo[i][j], al, b[j], clo[i][j]);
                    simdgroup_multiply_accumulate(chi[i][j], ah, b[j], chi[i][j]);
                }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        if (((kt + 1U) & 7U) == 0U || (kt + 1U) == kt_end) {
            threadgroup float* sc0 = xlo + sg * 256U;
            threadgroup float* sc1 = xhi + sg * 256U;
            for (uint j = 0; j < 4U; ++j) {
                simdgroup_store(clo[0][j], sc0 + j * 64U, 8);
                simdgroup_store(clo[1][j], sc1 + j * 64U, 8);
                clo[0][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                clo[1][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (uint j = 0; j < 4U; ++j) {
                threadgroup const float* p0 = sc0 + j * 64U;
                threadgroup const float* p1 = sc1 + j * 64U;
                ilo[0][j] += int2((int)p0[2U * lane], (int)p0[2U * lane + 1U]);
                ilo[1][j] += int2((int)p1[2U * lane], (int)p1[2U * lane + 1U]);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (uint j = 0; j < 4U; ++j) {
                simdgroup_store(chi[0][j], sc0 + j * 64U, 8);
                simdgroup_store(chi[1][j], sc1 + j * 64U, 8);
                chi[0][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                chi[1][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            for (uint j = 0; j < 4U; ++j) {
                threadgroup const float* p0 = sc0 + j * 64U;
                threadgroup const float* p1 = sc1 + j * 64U;
                ihi[0][j] += int2((int)p0[2U * lane], (int)p0[2U * lane + 1U]);
                ihi[1][j] += int2((int)p1[2U * lane], (int)p1[2U * lane + 1U]);
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
        }
    }

    const ulong slice_stride = (p.split_k > 1U) ? ((ulong)M * (ulong)p.os) : 0UL;
    device long* out_base = C_i64 + (ulong)tgid.z * slice_stride;
    for (uint i = 0; i < 2U; ++i) {
        for (uint j = 0; j < 4U; ++j) {
            const uint row = m0 + r0 + i * 8U + (lane >> 2);
            const uint col = n0 + c0 + j * 8U + 2U * (lane & 3U);
            if (row < M) {
                device long* o = out_base + (ulong)row * (ulong)p.os;
                if (col < N)      o[col]      = (long)ihi[i][j].x * 256L + (long)ilo[i][j].x;
                if (col + 1U < N) o[col + 1U] = (long)ihi[i][j].y * 256L + (long)ilo[i][j].y;
            }
        }
    }
}

kernel void exact_reduce_splitk4(
    device const long* partial_in [[buffer(0)]],
    device long*       out_i64    [[buffer(1)]],
    constant uint3&    dims       [[buffer(2)]], // .x = M, .y = N, .z = os
    uint gid                      [[thread_position_in_grid]])
{
    const ulong total = (ulong)dims.x * (ulong)dims.y;
    if ((ulong)gid >= total) return;
    const uint row = gid / dims.y;
    const uint col = gid % dims.y;
    const ulong stride = (ulong)dims.x * (ulong)dims.y;
    const ulong idx = (ulong)gid;
    out_i64[(ulong)row * (ulong)dims.z + (ulong)col] =
        partial_in[idx] + partial_in[stride + idx] +
        partial_in[2UL * stride + idx] + partial_in[3UL * stride + idx];
}

// ============================================================================
// PART D: Resident 32-Layer Exact-Integer Non-GEMM Kernels (H132)
// ============================================================================
inline long sar_i64(long v, uint sh) {
    if (sh == 0U) return v;
    return (v >= 0L) ? (v >> sh) : -(((-v - 1L) >> sh) + 1L);
}

inline long requant_i64(long acc, uint sh) {
    if (sh == 0U) return acc;
    return sar_i64(acc + (1L << (sh - 1U)), sh);
}

inline long exact_isqrt_i64(long ss) {
    if (ss <= 0L) return 0L;
    ulong n = (ulong)ss;
    ulong x = max(1UL, (ulong)sqrt((float)n));
    x = (x + n / x) >> 1;
    x = (x + n / x) >> 1;
    while ((x + 1UL) * (x + 1UL) <= n) ++x;
    while (x * x > n) --x;
    return (long)x;
}

kernel void exact_int_embed_gather(
    device const int*   tok_ids [[buffer(0)]],
    device const short* emb_i16 [[buffer(1)]],
    device short*       x_out   [[buffer(2)]],
    constant uint2&     dims    [[buffer(3)]],
    uint gid                    [[thread_position_in_grid]])
{
    ulong total = (ulong)dims.x * (ulong)dims.y;
    if ((ulong)gid >= total) return;
    uint row = gid / dims.y;
    uint col = gid % dims.y;
    int tid = tok_ids[row];
    x_out[gid] = emb_i16[(ulong)tid * (ulong)dims.y + (ulong)col];
}

struct NormParams {
    uint M;
    uint D;
    long cn;
    uint tn;
    long ceps;
    uint wrho;
};

kernel void exact_int_rmsnorm(
    device const short* x_in    [[buffer(0)]],
    device const char*  gamma   [[buffer(1)]],
    device char*        y_out   [[buffer(2)]],
    constant NormParams& p      [[buffer(3)]],
    device atomic_uint* bad_cnt [[buffer(4)]],
    uint row                    [[threadgroup_position_in_grid]],
    uint lid                    [[thread_index_in_threadgroup]])
{
    if (row >= p.M) return;
    threadgroup long sq_sum[256];
    ulong base = (ulong)row * (ulong)p.D;
    long local_ss = 0L;
    for (uint d = lid; d < p.D; d += 256U) {
        long xv = (long)x_in[base + d];
        local_ss += xv * xv;
    }
    sq_sum[lid] = local_ss;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = 128U; stride > 0U; stride >>= 1U) {
        if (lid < stride) sq_sum[lid] += sq_sum[lid + stride];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    long ss = p.ceps + sq_sum[0];
    long Dv_raw = exact_isqrt_i64(ss);
    if (lid == 0U) {
        long a1 = ss - Dv_raw * Dv_raw;
        long a2 = 2L * Dv_raw - a1;
        if (Dv_raw < 1L || Dv_raw >= (1L << 24) || a1 < 0L || a1 >= (1L << 24) || a2 < 0L || a2 >= (1L << 24)) {
            atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        }
    }
    long Dv = max(Dv_raw, 1L);
    long dv = Dv << p.tn;
    long den = 2L * dv;

    for (uint d = lid; d < p.D; d += 256U) {
        long xv = (long)x_in[base + d];
        long gv = (long)gamma[d];
        long num = 2L * xv * (gv * p.cn) + dv;
        long q = num / den;
        long rho = num - q * den;
        if (rho < 0L) {
            q -= 1L;
            rho += den;
        }
        long sigma = den - 1L - rho;
        long lim = 1L << p.wrho;
        if (q < -127L || q > 127L || rho < 0L || rho >= lim || sigma < 0L || sigma >= lim) {
            atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        }
        y_out[base + d] = (char)q;
    }
}

struct QkvRopeParams {
    uint M;
    uint T;
    uint sh_qkv;
    uint sh_rope;
};

kernel void exact_int_qkv_rope(
    device const long* q_raw    [[buffer(0)]],
    device const long* k_raw    [[buffer(1)]],
    device const long* v_raw    [[buffer(2)]],
    device const long* rope_cos [[buffer(3)]],
    device const long* rope_sin [[buffer(4)]],
    device char*       qr_out   [[buffer(5)]],
    device char*       kr_out   [[buffer(6)]],
    device char*       v_out    [[buffer(7)]],
    constant QkvRopeParams& p   [[buffer(8)]],
    device atomic_uint* bad_cnt [[buffer(9)]],
    uint gid                    [[thread_position_in_grid]])
{
    const uint pairs_per_row = 48U * 64U;
    if (gid >= p.M * pairs_per_row) return;
    const uint gm = gid / pairs_per_row;
    const uint rem = gid % pairs_per_row;
    const uint h_idx = rem >> 6;
    const uint d = rem & 63U;
    const uint t_loc = gm % p.T;

    if (h_idx < 32U) {
        ulong base = (ulong)gm * 4096UL + (ulong)(h_idx * 128U);
        long qa = requant_i64(q_raw[base + d], p.sh_qkv);
        long qb = requant_i64(q_raw[base + d + 64U], p.sh_qkv);
        if (qa < -127L || qa > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        if (qb < -127L || qb > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        long cc = (long)rope_cos[t_loc * 64U + d];
        long ss = (long)rope_sin[t_loc * 64U + d];
        long r0 = requant_i64(cc * qa - ss * qb, p.sh_rope);
        long r1 = requant_i64(ss * qa + cc * qb, p.sh_rope);
        if (r0 < -127L || r0 > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        if (r1 < -127L || r1 > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        qr_out[base + d]       = (char)r0;
        qr_out[base + d + 64U] = (char)r1;
    } else if (h_idx < 40U) {
        uint kh = h_idx - 32U;
        ulong base = (ulong)gm * 1024UL + (ulong)(kh * 128U);
        long ka = requant_i64(k_raw[base + d], p.sh_qkv);
        long kb = requant_i64(k_raw[base + d + 64U], p.sh_qkv);
        if (ka < -127L || ka > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        if (kb < -127L || kb > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        long cc = (long)rope_cos[t_loc * 64U + d];
        long ss = (long)rope_sin[t_loc * 64U + d];
        long r0 = requant_i64(cc * ka - ss * kb, p.sh_rope);
        long r1 = requant_i64(ss * ka + cc * kb, p.sh_rope);
        if (r0 < -127L || r0 > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        if (r1 < -127L || r1 > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        kr_out[base + d]       = (char)r0;
        kr_out[base + d + 64U] = (char)r1;
    } else {
        uint vh = h_idx - 40U;
        ulong base = (ulong)gm * 1024UL + (ulong)(vh * 128U);
        long va = requant_i64(v_raw[base + d], p.sh_qkv);
        long vb = requant_i64(v_raw[base + d + 64U], p.sh_qkv);
        if (va < -127L || va > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        if (vb < -127L || vb > 127L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        v_out[base + d]       = (char)va;
        v_out[base + d + 64U] = (char)vb;
    }
}

struct AttnParams {
    uint K_req;
    uint T;
    uint sh_s;
    uint sh_o;
    uint f_e;
    uint f_p;
    uint wrho_s;
};

kernel void exact_int_causal_gqa_attn(
    device const char* qr_in    [[buffer(0)]],
    device const char* kr_in    [[buffer(1)]],
    device const char* v_in     [[buffer(2)]],
    device const long* exp_tab  [[buffer(3)]],
    device char*       o_out    [[buffer(4)]],
    constant AttnParams& p      [[buffer(5)]],
    device atomic_uint* bad_cnt [[buffer(6)]],
    uint3 tgid                  [[threadgroup_position_in_grid]],
    uint lid                    [[thread_index_in_threadgroup]])
{
    const uint hq = tgid.x;
    const uint t  = tgid.y;
    const uint r  = tgid.z;
    if (hq >= 32U || t >= p.T || r >= p.K_req) return;

    const uint kv = hq >> 2;
    const uint gm_q = r * p.T + t;

    threadgroup char q_sh[128];
    threadgroup long red_sh[128];
    threadgroup long p_sh[128];

    q_sh[lid] = qr_in[(ulong)gm_q * 4096UL + (ulong)(hq * 128U + lid)];
    threadgroup_barrier(mem_flags::mem_threadgroup);

    long masked = -999999L;
    if (lid < p.T) {
        ulong k_base = (ulong)(r * p.T + lid) * 1024UL + (ulong)(kv * 128U);
        long sacc = 0L;
        for (uint d = 0; d < 128U; ++d) {
            sacc += (long)q_sh[d] * (long)kr_in[k_base + d];
        }
        long s8 = requant_i64(sacc, p.sh_s);
        if (s8 < -127L || s8 > 127L) {
            atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        }
        masked = (lid <= t) ? s8 : -127L;
    }
    red_sh[lid] = masked;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = 64U; stride > 0U; stride >>= 1U) {
        if (lid < stride) red_sh[lid] = max(red_sh[lid], red_sh[lid + stride]);
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    const long best = red_sh[0];
    threadgroup_barrier(mem_flags::mem_threadgroup);

    long E = 0L;
    if (lid < p.T) {
        long delta = best - masked;
        if (delta < 0L || delta > 255L) {
            atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        }
        E = exp_tab[(uint)clamp(delta, 0L, 255L)];
        red_sh[lid] = (lid <= t) ? E : 0L;
    } else {
        red_sh[lid] = 0L;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = 64U; stride > 0U; stride >>= 1U) {
        if (lid < stride) red_sh[lid] += red_sh[lid + stride];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    const long total = red_sh[0];
    if (lid == 0U) {
        long lo_den = 1L << p.f_e;
        long hi_den = (long)max(1U, p.T) << p.f_e;
        if (total < lo_den || total > hi_den) {
            atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        }
    }

    if (lid < p.T) {
        long prob = 0L;
        long rho = 0L;
        if (lid <= t && total > 0L) {
            long num = E << p.f_p;
            prob = num / total;
            rho = num - prob * total;
        }
        long sigma = total - 1L - rho;
        if (prob < 0L || prob > (1L << p.f_p) || sigma < 0L || sigma >= (1L << p.wrho_s)) {
            atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
        }
        p_sh[lid] = (lid <= t) ? prob : 0L;
    } else {
        p_sh[lid] = 0L;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    long oacc = 0L;
    for (uint j = 0; j <= t; ++j) {
        ulong v_idx = (ulong)(r * p.T + j) * 1024UL + (ulong)(kv * 128U + lid);
        oacc += p_sh[j] * (long)v_in[v_idx];
    }
    long o8 = requant_i64(oacc, p.sh_o);
    if (o8 < -127L || o8 > 127L) {
        atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    }
    o_out[(ulong)gm_q * 4096UL + (ulong)(hq * 128U + lid)] = (char)o8;
}

struct Res1Params {
    uint total_elems;
    uint sh_ao;
};

kernel void exact_int_res1(
    device const short* x_in    [[buffer(0)]],
    device const long*  ao_raw  [[buffer(1)]],
    device short*       x1_out  [[buffer(2)]],
    constant Res1Params& p      [[buffer(3)]],
    device atomic_uint* bad_cnt [[buffer(4)]],
    uint gid                    [[thread_position_in_grid]])
{
    if (gid >= p.total_elems) return;
    long ao = requant_i64(ao_raw[gid], p.sh_ao);
    if (ao < -32768L || ao > 32767L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    long x1 = (long)x_in[gid] + ao;
    if (x1 < -32768L || x1 > 32767L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    x1_out[gid] = (short)x1;
}

struct SwiGluParams {
    uint total_elems;
    uint sh_g;
    uint sh_u;
    uint sh_h;
};

kernel void exact_int_swiglu(
    device const long*  g_raw   [[buffer(0)]],
    device const long*  u_raw   [[buffer(1)]],
    device const short* act_tab [[buffer(2)]],
    device short*       h_out   [[buffer(3)]],
    constant SwiGluParams& p    [[buffer(4)]],
    device atomic_uint* bad_cnt [[buffer(5)]],
    uint gid                    [[thread_position_in_grid]])
{
    if (gid >= p.total_elems) return;
    long g8 = requant_i64(g_raw[gid], p.sh_g);
    long u16 = requant_i64(u_raw[gid], p.sh_u);
    if (g8 < -128L || g8 > 127L)       atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    if (u16 < -32768L || u16 > 32767L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    long a16 = (long)act_tab[(uint)clamp(g8 + 128L, 0L, 255L)];
    long h16 = requant_i64(a16 * u16, p.sh_h);
    if (h16 < -32768L || h16 > 32767L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    h_out[gid] = (short)h16;
}

struct Res2Params {
    uint total_elems;
    uint sh_z;
    uint sh_r2;
};

kernel void exact_int_res2(
    device const short* x1_in   [[buffer(0)]],
    device const long*  z_raw   [[buffer(1)]],
    device short*       x_out   [[buffer(2)]],
    constant Res2Params& p      [[buffer(3)]],
    device atomic_uint* bad_cnt [[buffer(4)]],
    uint gid                    [[thread_position_in_grid]])
{
    if (gid >= p.total_elems) return;
    long z16 = requant_i64(z_raw[gid], p.sh_z);
    if (z16 < -32768L || z16 > 32767L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    long x2 = (p.sh_r2 != 0U)
        ? requant_i64((long)x1_in[gid] + (z16 << p.sh_r2), p.sh_r2)
        : ((long)x1_in[gid] + z16);
    if (x2 < -32768L || x2 > 32767L) atomic_fetch_add_explicit(bad_cnt, 1U, memory_order_relaxed);
    x_out[gid] = (short)x2;
}

kernel void exact_int_gather_last_tokens(
    device const short* x_in    [[buffer(0)]],
    device short*       x_last  [[buffer(1)]],
    constant uint3&     dims    [[buffer(2)]],
    uint gid                    [[thread_position_in_grid]])
{
    uint total = dims.x * dims.z;
    if (gid >= total) return;
    uint r = gid / dims.z;
    uint d = gid % dims.z;
    ulong src_row = (ulong)r * (ulong)dims.y + (ulong)(dims.y - 1U);
    x_last[gid] = x_in[src_row * (ulong)dims.z + (ulong)d];
}

kernel void exact_int_head_scale(
    device long*       l_raw     [[buffer(0)]],
    device const long* head_mult [[buffer(1)]],
    constant uint2&    dims      [[buffer(2)]],
    uint gid                     [[thread_position_in_grid]])
{
    ulong total = (ulong)dims.x * (ulong)dims.y;
    if ((ulong)gid >= total) return;
    uint col = gid % dims.y;
    l_raw[gid] *= head_mult[col];
}

kernel void fp16_rmsnorm_rows(
    device const half* x   [[buffer(0)]],
    device half*       out [[buffer(1)]],
    constant uint&     D   [[buffer(2)]],
    uint row               [[threadgroup_position_in_grid]],
    uint tid               [[thread_index_in_threadgroup]],
    uint sg_id             [[simdgroup_index_in_threadgroup]],
    uint sg_lane           [[thread_index_in_simdgroup]])
{
    threadgroup float sg_sums[8];
    float ss = 0.0f;
    for (uint j = tid; j < D; j += 256U) {
        float v = float(x[(ulong)row * D + j]);
        ss += v * v;
    }
    ss = simd_sum(ss);
    if (sg_lane == 0U) sg_sums[sg_id] = ss;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float tot = 0.0f;
    if (tid < 8U) tot = sg_sums[tid];
    tot = simd_sum(tot);
    if (tid == 0U) sg_sums[0] = rsqrt(tot / float(D) + 1e-5f);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float inv = sg_sums[0];
    for (uint j = tid; j < D; j += 256U) {
        out[(ulong)row * D + j] = half(float(x[(ulong)row * D + j]) * inv);
    }
}

kernel void fp16_swiglu(
    device const half* g   [[buffer(0)]],
    device const half* u   [[buffer(1)]],
    device half*       out [[buffer(2)]],
    constant uint&     N   [[buffer(3)]],
    uint gid               [[thread_position_in_grid]])
{
    if (gid >= N) return;
    float gv = float(g[gid]);
    float silu = gv / (1.0f + exp(-gv));
    out[gid] = half(silu * float(u[gid]));
}

kernel void fp16_gather_last_tokens(
    device const half* x_in   [[buffer(0)]],
    device half*       x_last [[buffer(1)]],
    constant uint3&    dims   [[buffer(2)]],
    uint gid                  [[thread_position_in_grid]])
{
    uint total = dims.x * dims.z;
    if (gid >= total) return;
    uint r = gid / dims.z;
    uint d = gid % dims.z;
    ulong src_row = (ulong)r * (ulong)dims.y + (ulong)(dims.y - 1U);
    x_last[gid] = x_in[src_row * (ulong)dims.z + (ulong)d];
}
)MSL";

struct WeightSlot {
    id<MTLBuffer> buf = nil;
    uint32_t N = 0;      // output cols
    uint32_t K = 0;      // inner terms
    uint32_t in_out = 0; // 0: [N, K]; 1: [K, N]
};

struct LayerDeviceMeta {
    int base_slot = 0;
    id<MTLBuffer> gamma_a = nil;
    id<MTLBuffer> gamma_m = nil;
    id<MTLBuffer> exp_tab = nil;
    id<MTLBuffer> act_tab = nil;
    id<MTLBuffer> rope_cos = nil;
    id<MTLBuffer> rope_sin = nil;
    int64_t cn_a = 0, cn_m = 0, ceps = 0;
    uint32_t tn = 0, wrho = 0;
    uint32_t sh_qkv = 0, sh_rope = 0, sh_s = 0, sh_o = 0, sh_ao = 0;
    uint32_t sh_g = 0, sh_u = 0, sh_h = 0, sh_z = 0, sh_r2 = 0;
    uint32_t f_e = 0, f_p = 0;
};

static id<MTLDevice> g_dev = nil;
static id<MTLCommandQueue> g_queue = nil;

static id<MTLComputePipelineState> g_pso_gemm_32x64 = nil;
static id<MTLComputePipelineState> g_pso_fast_i8_2x4 = nil;
static id<MTLComputePipelineState> g_pso_fast_i16_2x4 = nil;
static id<MTLComputePipelineState> g_pso_reduce_splitk4 = nil;
static id<MTLComputePipelineState> g_pso_wprod_2x4 = nil;
static id<MTLComputePipelineState> g_pso_wprod_4x2 = nil;
static id<MTLComputePipelineState> g_pso_wprod_int = nil;

static id<MTLComputePipelineState> g_pso_embed = nil;
static id<MTLComputePipelineState> g_pso_norm = nil;
static id<MTLComputePipelineState> g_pso_qkv_rope = nil;
static id<MTLComputePipelineState> g_pso_attn = nil;
static id<MTLComputePipelineState> g_pso_res1 = nil;
static id<MTLComputePipelineState> g_pso_swiglu = nil;
static id<MTLComputePipelineState> g_pso_res2 = nil;
static id<MTLComputePipelineState> g_pso_gather_last = nil;
static id<MTLComputePipelineState> g_pso_head_scale = nil;
static id<MTLComputePipelineState> g_pso_fp16_norm = nil;
static id<MTLComputePipelineState> g_pso_fp16_swiglu = nil;
static id<MTLComputePipelineState> g_pso_fp16_gather_last = nil;

static std::vector<WeightSlot> g_slots;
static LayerDeviceMeta g_layers[32];
static id<MTLBuffer> g_emb_buf = nil;
static id<MTLBuffer> g_final_gamma_buf = nil;
static id<MTLBuffer> g_head_mult_buf = nil;
static int64_t g_fn_cn = 0, g_fn_ceps = 0;
static uint32_t g_fn_tn = 0, g_fn_wrho = 0;

static constexpr uint32_t MAX_M = 1024;
static constexpr uint32_t DIM_D = 4096;
static constexpr uint32_t DIM_KV = 1024;
static constexpr uint32_t DIM_F = 16384;
static constexpr uint32_t DIM_V = 128256;

static id<MTLBuffer> g_tok_buf = nil;
static id<MTLBuffer> g_x_buf = nil;
static id<MTLBuffer> g_x1_buf = nil;
static id<MTLBuffer> g_xlast_buf = nil;
static id<MTLBuffer> g_norm_buf = nil;
static id<MTLBuffer> g_qr_buf = nil;
static id<MTLBuffer> g_kr_buf = nil;
static id<MTLBuffer> g_v_buf = nil;
static id<MTLBuffer> g_o_buf = nil;
static id<MTLBuffer> g_h_buf = nil;
static id<MTLBuffer> g_raw0_buf = nil;
static id<MTLBuffer> g_raw1_buf = nil;
static id<MTLBuffer> g_raw2_buf = nil;
static id<MTLBuffer> g_splitk_buf = nil; // [4 * MAX_M * DIM_F] int64 for Split-K=4 partials
static id<MTLBuffer> g_bad_buf = nil;

// Dedicated H128 1-block 7-projection buffers (all 7 outputs retained for word-for-word verification!)
static id<MTLBuffer> g_b7_x_i16_pad[7]; // padded (tp, kp) int16 buffers for k_wprod_* & v2
static id<MTLBuffer> g_b7_x_i8_pad[7];  // padded (tp, kp) int8 buffers
static id<MTLBuffer> g_b7_w[7];         // 7 weight buffers (f=14336 or f_pad=16384)
static id<MTLBuffer> g_b7_out[7];       // 7 distinct output buffers!

static id<MTLComputePipelineState> makePSO(id<MTLLibrary> lib, const char* name) {
    NSError* err = nil;
    id<MTLFunction> fn = [lib newFunctionWithName:[NSString stringWithUTF8String:name]];
    if (!fn) { fprintf(stderr, "Missing Metal fn: %s\n", name); return nil; }
    id<MTLComputePipelineState> pso = [g_dev newComputePipelineStateWithFunction:fn error:&err];
    if (!pso) { fprintf(stderr, "PSO err %s: %s\n", name, [[err localizedDescription] UTF8String]); }
    return pso;
}

struct GemmParamsHost {
    uint32_t M, K, N, kp, is_i8, in_out, os, split_k;
    uint64_t w_off;
};

static inline void encodeGemmV2(
    id<MTLComputeCommandEncoder> enc, int kernel_mode,
    id<MTLBuffer> x_buf, uint32_t kp, int is_i8, uint32_t M, uint32_t K,
    id<MTLBuffer> w_buf, uint64_t w_off, uint32_t N, uint32_t in_out,
    id<MTLBuffer> out_buf, uint32_t os)
{
    if (kernel_mode == 0) {
        // Verbatim Stage-2 32x64
        GemmParamsHost p = {M, K, N, kp, (uint32_t)(is_i8 ? 1 : 0), in_out, os, 1U, w_off};
        [enc setComputePipelineState:g_pso_gemm_32x64];
        [enc setBuffer:x_buf offset:0 atIndex:0];
        [enc setBuffer:w_buf offset:0 atIndex:1];
        [enc setBuffer:out_buf offset:0 atIndex:2];
        [enc setBytes:&p length:sizeof(p) atIndex:3];
        [enc dispatchThreadgroups:MTLSizeMake((N + 63U) / 64U, (M + 31U) / 32U, 1)
            threadsPerThreadgroup:MTLSizeMake(128, 1, 1)];
    } else if (kernel_mode == 1) {
        // Upgraded Zero-Spill 64x64 (SPLIT_K = 1)
        id<MTLComputePipelineState> pso = is_i8 ? g_pso_fast_i8_2x4 : g_pso_fast_i16_2x4;
        GemmParamsHost p = {M, K, N, kp, (uint32_t)(is_i8 ? 1 : 0), in_out, os, 1U, w_off};
        [enc setComputePipelineState:pso];
        [enc setBuffer:x_buf offset:0 atIndex:0];
        [enc setBuffer:w_buf offset:0 atIndex:1];
        [enc setBuffer:out_buf offset:0 atIndex:2];
        [enc setBytes:&p length:sizeof(p) atIndex:3];
        [enc dispatchThreadgroups:MTLSizeMake((N + 63U) / 64U, (M + 63U) / 64U, 1)
            threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
    } else if (kernel_mode == 5) {
        // Upgraded Zero-Spill 64x64 + Auto Exact Associative SPLIT_K = 4 when M <= 256 && K >= 2048 && N <= DIM_F
        id<MTLComputePipelineState> pso = is_i8 ? g_pso_fast_i8_2x4 : g_pso_fast_i16_2x4;
        const bool do_sk4 = (M <= 256U && K >= 2048U && N <= DIM_F);
        if (!do_sk4) {
            GemmParamsHost p = {M, K, N, kp, (uint32_t)(is_i8 ? 1 : 0), in_out, os, 1U, w_off};
            [enc setComputePipelineState:pso];
            [enc setBuffer:x_buf offset:0 atIndex:0];
            [enc setBuffer:w_buf offset:0 atIndex:1];
            [enc setBuffer:out_buf offset:0 atIndex:2];
            [enc setBytes:&p length:sizeof(p) atIndex:3];
            [enc dispatchThreadgroups:MTLSizeMake((N + 63U) / 64U, (M + 63U) / 64U, 1)
                threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
        } else {
            GemmParamsHost p = {M, K, N, kp, (uint32_t)(is_i8 ? 1 : 0), in_out, N, 4U, w_off};
            [enc setComputePipelineState:pso];
            [enc setBuffer:x_buf offset:0 atIndex:0];
            [enc setBuffer:w_buf offset:0 atIndex:1];
            [enc setBuffer:g_splitk_buf offset:0 atIndex:2];
            [enc setBytes:&p length:sizeof(p) atIndex:3];
            [enc dispatchThreadgroups:MTLSizeMake((N + 63U) / 64U, (M + 63U) / 64U, 4)
                threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];

            uint32_t rdims[3] = {M, N, os};
            uint64_t tot = (uint64_t)M * (uint64_t)N;
            [enc setComputePipelineState:g_pso_reduce_splitk4];
            [enc setBuffer:g_splitk_buf offset:0 atIndex:0];
            [enc setBuffer:out_buf offset:0 atIndex:1];
            [enc setBytes:rdims length:sizeof(rdims) atIndex:2];
            [enc dispatchThreadgroups:MTLSizeMake((NSUInteger)((tot + 255ULL) / 256ULL), 1, 1)
                threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
        }
    } else {
        // Production [A4] routes: 2 = k_wprod_sg_2x4, 3 = k_wprod_sg_4x2, 4 = k_wprod_int
        id<MTLComputePipelineState> pso = (kernel_mode == 2) ? g_pso_wprod_2x4
                                        : (kernel_mode == 3) ? g_pso_wprod_4x2 : g_pso_wprod_int;
        struct { uint32_t t, k, n, kp, in_out, os; uint64_t w_off; } wa =
            {M, K, N, kp, in_out, os, w_off};
        uint32_t tp = ((M + 63U) / 64U) * 64U;
        [enc setComputePipelineState:pso];
        [enc setBuffer:x_buf offset:0 atIndex:0];
        [enc setBuffer:w_buf offset:0 atIndex:1];
        [enc setBuffer:out_buf offset:0 atIndex:2];
        [enc setBytes:&wa length:sizeof(wa) atIndex:3];
        [enc dispatchThreadgroups:MTLSizeMake((N + 63U) / 64U, tp / 64U, 1)
            threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
    }
}

// ARM64 NEON exact i64 -> i16 range check & pack (with zero-padding to tp x kp, matching metal.rs:wprod_run!)
static inline bool neon_pack_i64_to_i16_padded(
    const int64_t* src, uint32_t t, uint32_t xs, uint32_t k,
    int16_t* dst, uint32_t tp, uint32_t kp)
{
    uint64_t bad_or = 0ULL;
    for (uint32_t r = 0; r < t; ++r) {
        const int64_t* srow = src + (size_t)r * xs;
        int16_t* drow = dst + (size_t)r * kp;
        uint32_t c = 0;
        const int64x2_t v32768 = vdupq_n_s64(32768);
        for (; c + 8U <= k; c += 8U) {
            int64x2_t v0 = vld1q_s64(srow + c + 0);
            int64x2_t v1 = vld1q_s64(srow + c + 2);
            int64x2_t v2 = vld1q_s64(srow + c + 4);
            int64x2_t v3 = vld1q_s64(srow + c + 6);
            // v fits in [-32768, 32767] iff (uint64_t)(v + 32768) < 65536 iff ((v + 32768) >> 16) == 0
            uint64x2_t u0 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v0, v32768), 16));
            uint64x2_t u1 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v1, v32768), 16));
            uint64x2_t u2 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v2, v32768), 16));
            uint64x2_t u3 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v3, v32768), 16));
            uint64x2_t u01 = vorrq_u64(u0, u1);
            uint64x2_t u23 = vorrq_u64(u2, u3);
            uint64x2_t uall = vorrq_u64(u01, u23);
            bad_or |= vgetq_lane_u64(uall, 0) | vgetq_lane_u64(uall, 1);

            int32x4_t n01 = vcombine_s32(vmovn_s64(v0), vmovn_s64(v1));
            int32x4_t n23 = vcombine_s32(vmovn_s64(v2), vmovn_s64(v3));
            int16x8_t p8  = vcombine_s16(vmovn_s32(n01), vmovn_s32(n23));
            vst1q_s16(drow + c, p8);
        }
        for (; c < k; ++c) {
            int64_t v = srow[c];
            int16_t d = (int16_t)v;
            if ((int64_t)d != v) bad_or |= 1ULL;
            drow[c] = d;
        }
        if (kp > k) memset(drow + k, 0, (kp - k) * sizeof(int16_t));
    }
    if (tp > t) {
        memset(dst + (size_t)t * kp, 0, (size_t)(tp - t) * kp * sizeof(int16_t));
    }
    return (bad_or == 0ULL);
}

// ARM64 NEON fast i64 -> i8 check + pack (falls back to false if any element outside [-128, 127])
static inline bool neon_try_pack_i64_to_i8_padded(
    const int64_t* src, uint32_t t, uint32_t xs, uint32_t k,
    int8_t* dst, uint32_t tp, uint32_t kp)
{
    uint64_t bad_or = 0ULL;
    const int64x2_t v128 = vdupq_n_s64(128);
    for (uint32_t r = 0; r < t; ++r) {
        const int64_t* srow = src + (size_t)r * xs;
        int8_t* drow = dst + (size_t)r * kp;
        uint32_t c = 0;
        for (; c + 8U <= k; c += 8U) {
            int64x2_t v0 = vld1q_s64(srow + c + 0);
            int64x2_t v1 = vld1q_s64(srow + c + 2);
            int64x2_t v2 = vld1q_s64(srow + c + 4);
            int64x2_t v3 = vld1q_s64(srow + c + 6);
            uint64x2_t u0 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v0, v128), 8));
            uint64x2_t u1 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v1, v128), 8));
            uint64x2_t u2 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v2, v128), 8));
            uint64x2_t u3 = vreinterpretq_u64_s64(vshrq_n_s64(vaddq_s64(v3, v128), 8));
            uint64x2_t uall = vorrq_u64(vorrq_u64(u0, u1), vorrq_u64(u2, u3));
            bad_or |= vgetq_lane_u64(uall, 0) | vgetq_lane_u64(uall, 1);
            int32x4_t n01 = vcombine_s32(vmovn_s64(v0), vmovn_s64(v1));
            int32x4_t n23 = vcombine_s32(vmovn_s64(v2), vmovn_s64(v3));
            int16x8_t p16 = vcombine_s16(vmovn_s32(n01), vmovn_s32(n23));
            int8x8_t  p8  = vmovn_s16(p16);
            vst1_s8(drow + c, p8);
        }
        for (; c < k; ++c) {
            int64_t v = srow[c];
            int8_t d = (int8_t)v;
            if ((int64_t)d != v) bad_or |= 1ULL;
            drow[c] = d;
        }
        if (kp > k) memset(drow + k, 0, (kp - k) * sizeof(int8_t));
        if (bad_or != 0ULL) return false;
    }
    if (tp > t) {
        memset(dst + (size_t)t * kp, 0, (size_t)(tp - t) * kp * sizeof(int8_t));
    }
    return (bad_or == 0ULL);
}

static inline id<MTLBuffer> makePageView(const void* ptr, size_t byte_len, uint64_t* offset_out) {
    size_t page = (size_t)getpagesize();
    uintptr_t p = (uintptr_t)ptr;
    uintptr_t base = p & ~(page - 1ULL);
    uintptr_t end  = (p + byte_len + page - 1ULL) & ~(page - 1ULL);
    *offset_out = (uint64_t)(p - base);
    return [g_dev newBufferWithBytesNoCopy:(void*)base
                                    length:(NSUInteger)(end - base)
                                   options:MTLResourceStorageModeShared
                               deallocator:nil];
}

extern "C" {

int zk60_batched_init(char* dev_name_out, int max_len) {
    @autoreleasepool {
        g_dev = MTLCreateSystemDefaultDevice();
        if (!g_dev) return -1;
        if (dev_name_out && max_len > 0) {
            snprintf(dev_name_out, (size_t)max_len, "%s", [[g_dev name] UTF8String]);
        }
        NSError* err = nil;
        MTLCompileOptions* opts = [[MTLCompileOptions alloc] init];
        opts.languageVersion = MTLLanguageVersion3_1;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        opts.fastMathEnabled = NO; // Match production hashline wctx() strict IEEE-754!
#pragma clang diagnostic pop
        id<MTLLibrary> lib = [g_dev newLibraryWithSource:[NSString stringWithUTF8String:kBatch5ExactMSL]
                                                 options:opts error:&err];
        if (!lib) {
            fprintf(stderr, "Metal compile err: %s\n", [[err localizedDescription] UTF8String]);
            return -2;
        }
        g_pso_gemm_32x64     = makePSO(lib, "exact_int_gemm_simd_32x64");
        g_pso_fast_i8_2x4    = makePSO(lib, "k_wprod_fast_i8_2x4");
        g_pso_fast_i16_2x4   = makePSO(lib, "k_wprod_fast_i16_2x4");
        g_pso_reduce_splitk4 = makePSO(lib, "exact_reduce_splitk4");
        g_pso_wprod_2x4      = makePSO(lib, "k_wprod_sg_2x4");
        g_pso_wprod_4x2      = makePSO(lib, "k_wprod_sg_4x2");
        g_pso_wprod_int      = makePSO(lib, "k_wprod_int");
        g_pso_embed          = makePSO(lib, "exact_int_embed_gather");
        g_pso_norm           = makePSO(lib, "exact_int_rmsnorm");
        g_pso_qkv_rope       = makePSO(lib, "exact_int_qkv_rope");
        g_pso_attn           = makePSO(lib, "exact_int_causal_gqa_attn");
        g_pso_res1           = makePSO(lib, "exact_int_res1");
        g_pso_swiglu         = makePSO(lib, "exact_int_swiglu");
        g_pso_res2           = makePSO(lib, "exact_int_res2");
        g_pso_gather_last    = makePSO(lib, "exact_int_gather_last_tokens");
        g_pso_head_scale     = makePSO(lib, "exact_int_head_scale");
        g_pso_fp16_norm        = makePSO(lib, "fp16_rmsnorm_rows");
        g_pso_fp16_swiglu      = makePSO(lib, "fp16_swiglu");
        g_pso_fp16_gather_last = makePSO(lib, "fp16_gather_last_tokens");
        if (!g_pso_gemm_32x64 || !g_pso_fast_i8_2x4 || !g_pso_fast_i16_2x4 || !g_pso_reduce_splitk4 || !g_pso_wprod_2x4 || !g_pso_embed || !g_pso_attn || !g_pso_fp16_norm) return -3;

        g_queue = [g_dev newCommandQueue];
        g_slots.resize(256);

        MTLResourceOptions sh = MTLResourceStorageModeShared;
        g_tok_buf    = [g_dev newBufferWithLength:MAX_M * sizeof(int32_t) options:sh];
        g_x_buf      = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_D * sizeof(int16_t) options:sh];
        g_x1_buf     = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_D * sizeof(int16_t) options:sh];
        g_xlast_buf  = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_D * sizeof(int16_t) options:sh];
        g_norm_buf   = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_F * sizeof(int16_t) options:sh];
        g_qr_buf     = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_D * sizeof(int8_t)  options:sh];
        g_kr_buf     = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_KV * sizeof(int8_t) options:sh];
        g_v_buf      = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_KV * sizeof(int8_t) options:sh];
        g_o_buf      = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_D * sizeof(int8_t)  options:sh];
        g_h_buf      = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_F * sizeof(int16_t) options:sh];
        g_raw0_buf   = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_V * sizeof(int64_t) options:sh];
        g_raw1_buf   = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_F * sizeof(int64_t) options:sh];
        g_raw2_buf   = [g_dev newBufferWithLength:(size_t)MAX_M * DIM_KV * sizeof(int64_t) options:sh];
        g_splitk_buf = [g_dev newBufferWithLength:4ULL * 256ULL * DIM_F * sizeof(int64_t) options:sh]; // 128 MiB
        g_bad_buf    = [g_dev newBufferWithLength:sizeof(uint32_t) options:sh];

        for (int p = 0; p < 7; ++p) {
            g_b7_x_i16_pad[p] = [g_dev newBufferWithLength:256ULL * DIM_F * sizeof(int16_t) options:sh];
            g_b7_x_i8_pad[p]  = [g_dev newBufferWithLength:256ULL * DIM_F * sizeof(int8_t)  options:sh];
            g_b7_w[p]         = [g_dev newBufferWithLength:(size_t)DIM_D * DIM_F * sizeof(int8_t) options:sh];
            g_b7_out[p]       = [g_dev newBufferWithLength:256ULL * DIM_F * sizeof(int64_t) options:sh];
        }
        return 0;
    }
}

int zk60_register_weight(int slot_id, const int8_t* data, uint32_t N, uint32_t K, uint32_t in_out) {
    @autoreleasepool {
        if (slot_id < 0) return -1;
        if ((size_t)slot_id >= g_slots.size()) g_slots.resize((size_t)slot_id + 16);
        id<MTLBuffer> b = [g_dev newBufferWithBytes:data length:(size_t)N * (size_t)K options:MTLResourceStorageModeShared];
        if (!b) return -2;
        g_slots[(size_t)slot_id] = {b, N, K, in_out};
        return 0;
    }
}

const int8_t* zk60_weight_ptr(int slot_id) {
    if (slot_id < 0 || (size_t)slot_id >= g_slots.size() || !g_slots[(size_t)slot_id].buf) return nullptr;
    return reinterpret_cast<const int8_t*>([g_slots[(size_t)slot_id].buf contents]);
}

int zk60_register_head_and_emb(
    const int16_t* emb_i16, uint32_t V, uint32_t D,
    const int8_t* final_gamma_i8, int64_t fn_cn, uint32_t fn_tn, int64_t fn_ceps, uint32_t fn_wrho,
    const int64_t* head_mult_i64)
{
    @autoreleasepool {
        MTLResourceOptions sh = MTLResourceStorageModeShared;
        g_emb_buf         = [g_dev newBufferWithBytes:emb_i16 length:(size_t)V * D * sizeof(int16_t) options:sh];
        g_final_gamma_buf = [g_dev newBufferWithBytes:final_gamma_i8 length:D * sizeof(int8_t) options:sh];
        g_head_mult_buf   = [g_dev newBufferWithBytes:head_mult_i64 length:V * sizeof(int64_t) options:sh];
        g_fn_cn = fn_cn; g_fn_tn = fn_tn; g_fn_ceps = fn_ceps; g_fn_wrho = fn_wrho;
        return (g_emb_buf && g_final_gamma_buf && g_head_mult_buf) ? 0 : -1;
    }
}

int zk60_register_layer_meta(
    int layer_idx, int base_slot,
    const int8_t* gamma_a, const int8_t* gamma_m,
    const int64_t* exp_256, const int16_t* act_256,
    const int64_t* rope_cos_128x64, const int64_t* rope_sin_128x64,
    int64_t cn_a, int64_t cn_m, uint32_t tn, int64_t ceps, uint32_t wrho,
    uint32_t sh_qkv, uint32_t sh_rope, uint32_t sh_s, uint32_t sh_o, uint32_t sh_ao,
    uint32_t sh_g, uint32_t sh_u, uint32_t sh_h, uint32_t sh_z, uint32_t sh_r2,
    uint32_t f_e, uint32_t f_p)
{
    @autoreleasepool {
        if (layer_idx < 0 || layer_idx >= 32) return -1;
        MTLResourceOptions sh = MTLResourceStorageModeShared;
        LayerDeviceMeta& L = g_layers[layer_idx];
        L.base_slot = base_slot;
        L.gamma_a  = [g_dev newBufferWithBytes:gamma_a length:4096 options:sh];
        L.gamma_m  = [g_dev newBufferWithBytes:gamma_m length:4096 options:sh];
        L.exp_tab  = [g_dev newBufferWithBytes:exp_256 length:256 * sizeof(int64_t) options:sh];
        L.act_tab  = [g_dev newBufferWithBytes:act_256 length:256 * sizeof(int16_t) options:sh];
        L.rope_cos = [g_dev newBufferWithBytes:rope_cos_128x64 length:128 * 64 * sizeof(int64_t) options:sh];
        L.rope_sin = [g_dev newBufferWithBytes:rope_sin_128x64 length:128 * 64 * sizeof(int64_t) options:sh];
        L.cn_a = cn_a; L.cn_m = cn_m; L.tn = tn; L.ceps = ceps; L.wrho = wrho;
        L.sh_qkv = sh_qkv; L.sh_rope = sh_rope; L.sh_s = sh_s; L.sh_o = sh_o; L.sh_ao = sh_ao;
        L.sh_g = sh_g; L.sh_u = sh_u; L.sh_h = sh_h; L.sh_z = sh_z; L.sh_r2 = sh_r2;
        L.f_e = f_e; L.f_p = f_p;
        return 0;
    }
}

// ============================================================================
// H128 Scope A & B: Full 7-Projection Block Comparison on Production Shapes
//   projs[p]: (t_rows, k_inner, n_outer, in_out, act_fits_i8)
// ============================================================================
int zk60_setup_block7_buffers(
    uint32_t t_rows,
    const uint32_t* k_arr,      // [7]
    const uint32_t* n_arr,      // [7]
    const int64_t* const* x_ptrs, // [7] host int64_t[t_rows * k]
    const int8_t* const* w_ptrs)  // [7] host int8_t[k * n]
{
    @autoreleasepool {
        uint32_t tp = ((t_rows + 63U) / 64U) * 64U;
        for (int p = 0; p < 7; ++p) {
            uint32_t k = k_arr[p], n = n_arr[p];
            uint32_t kp = ((k + 31U) / 32U) * 32U;
            bool ok16 = neon_pack_i64_to_i16_padded(
                x_ptrs[p], t_rows, k, k,
                reinterpret_cast<int16_t*>([g_b7_x_i16_pad[p] contents]), tp, kp);
            if (!ok16) return -(10 + p);
            neon_try_pack_i64_to_i8_padded(
                x_ptrs[p], t_rows, k, k,
                reinterpret_cast<int8_t*>([g_b7_x_i8_pad[p] contents]), tp, kp);
            memcpy([g_b7_w[p] contents], w_ptrs[p], (size_t)k * (size_t)n);
        }
        return 0;
    }
}

// Scope A: Resident Device Buffers (measures pure GPU ms & cmdbuf wall ms; 1 cmdbuf vs 7 cmdbufs!)
//   route:
//     0 = Stage-2 32x64 (is_i8 on i8-fitting projections)
//     1 = Upgraded 64x64_v2 (SPLIT_K=1, int16 input -> dynamic hi==0 skip!)
//     2 = Production [A4] k_wprod_sg_2x4 (verbatim WPROD_SRC, int16 input)
//     3 = Production [A4] k_wprod_sg_4x2
//     4 = Production [A4] k_wprod_int
//     5 = Upgraded 64x64_v2 + SPLIT_K=4 (int16 input -> dynamic hi==0 skip, 100% drop-in!)
//     6 = Upgraded 64x64_v2 + SPLIT_K=4 + is_i8=1 where valid
int zk60_run_block7_resident(
    uint32_t t_rows,
    const uint32_t* k_arr,
    const uint32_t* n_arr,
    const uint32_t* in_out_arr,
    const uint32_t* fits_i8_arr,
    int route,
    int seven_cmdbufs,
    int64_t* const* out_host_ptrs, // optional [7] for word-for-word check!
    double* gpu_ms_out,
    double* cmdbuf_wall_ms_out)
{
    @autoreleasepool {
        auto t0 = std::chrono::steady_clock::now();
        double total_gpu_ms = 0.0;

        auto encodeOne = [&](id<MTLComputeCommandEncoder> enc, int p) {
            uint32_t k = k_arr[p], n = n_arr[p];
            uint32_t kp = ((k + 31U) / 32U) * 32U;
            uint32_t io = in_out_arr[p];
            bool use_i8 = (route == 0 || route == 1 || route == 6) && (fits_i8_arr[p] != 0U);
            id<MTLBuffer> xb = use_i8 ? g_b7_x_i8_pad[p] : g_b7_x_i16_pad[p];
            int eff_mode = (route == 6) ? 5 : route;
            encodeGemmV2(enc, eff_mode, xb, kp, use_i8 ? 1 : 0, t_rows, k, g_b7_w[p], 0ULL, n, io, g_b7_out[p], n);
        };

        if (seven_cmdbufs) {
            for (int p = 0; p < 7; ++p) {
                id<MTLCommandBuffer> cb = [g_queue commandBuffer];
                id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
                encodeOne(enc, p);
                [enc endEncoding];
                [cb commit];
                [cb waitUntilCompleted];
                if ([cb status] != MTLCommandBufferStatusCompleted) return -2;
                total_gpu_ms += ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
            }
        } else {
            id<MTLCommandBuffer> cb = [g_queue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
            for (int p = 0; p < 7; ++p) encodeOne(enc, p);
            [enc endEncoding];
            [cb commit];
            [cb waitUntilCompleted];
            if ([cb status] != MTLCommandBufferStatusCompleted) return -2;
            total_gpu_ms = ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
        }

        auto t1 = std::chrono::steady_clock::now();
        if (out_host_ptrs) {
            for (int p = 0; p < 7; ++p) {
                if (out_host_ptrs[p]) {
                    memcpy(out_host_ptrs[p], [g_b7_out[p] contents], (size_t)t_rows * n_arr[p] * sizeof(int64_t));
                }
            }
        }
        if (gpu_ms_out) *gpu_ms_out = total_gpu_ms;
        if (cmdbuf_wall_ms_out) *cmdbuf_wall_ms_out = std::chrono::duration<double, std::milli>(t1 - t0).count();
        return 0;
    }
}

// Scope B: Full End-to-End Host-i64 Drop-In Benchmark (matches metal.rs::wprod_run:
//   starts from host int64_t* activations + page-aligned host int8_t* weights + page-aligned host int64_t* outputs,
//   times i64 range-check & pack + weight/output page views + MTLCommandBuffer + GPU execution!)
int zk60_run_block7_e2e_host_i64(
    uint32_t t_rows,
    const uint32_t* k_arr,
    const uint32_t* n_arr,
    const uint32_t* in_out_arr,
    const int64_t* const* x_host_ptrs, // [7] host int64_t[t_rows * k]
    const int8_t* const* w_host_ptrs,  // [7] host int8_t[k * n]
    int64_t* const* out_host_ptrs,     // [7] page-aligned host int64_t[t_rows * n]
    int route,                         // 0=32x64, 2=prod_A4_2x4, 5=v2_sk4_i16, 6=v2_sk4_auto_i8
    int seven_cmdbufs,                 // 1 = 7 separate calls like current witness.rs; 0 = batched cmdbuf
    double* pack_ms_out,
    double* view_encode_ms_out,
    double* cmdbuf_wall_ms_out,
    double* gpu_ms_out,
    double* total_e2e_ms_out)
{
    @autoreleasepool {
        auto t_start = std::chrono::steady_clock::now();
        uint32_t tp = ((t_rows + 63U) / 64U) * 64U;
        double pack_ms = 0.0, view_ms = 0.0, cb_wall_ms = 0.0, gpu_ms = 0.0;

        bool used_i8[7] = {false, false, false, false, false, false, false};

        if (seven_cmdbufs) {
            for (int p = 0; p < 7; ++p) {
                uint32_t k = k_arr[p], n = n_arr[p], io = in_out_arr[p];
                uint32_t kp = ((k + 31U) / 32U) * 32U;

                auto tp0 = std::chrono::steady_clock::now();
                if (route == 0 || route == 1 || route == 6) {
                    used_i8[p] = neon_try_pack_i64_to_i8_padded(
                        x_host_ptrs[p], t_rows, k, k,
                        reinterpret_cast<int8_t*>([g_b7_x_i8_pad[p] contents]), tp, kp);
                }
                if (!used_i8[p]) {
                    if (!neon_pack_i64_to_i16_padded(
                            x_host_ptrs[p], t_rows, k, k,
                            reinterpret_cast<int16_t*>([g_b7_x_i16_pad[p] contents]), tp, kp)) {
                        return -(20 + p);
                    }
                }
                auto tp1 = std::chrono::steady_clock::now();
                pack_ms += std::chrono::duration<double, std::milli>(tp1 - tp0).count();

                uint64_t w_off = 0ULL, o_off = 0ULL;
                id<MTLBuffer> w_view = makePageView(w_host_ptrs[p], (size_t)k * n, &w_off);
                id<MTLBuffer> o_view = makePageView(out_host_ptrs[p], (size_t)t_rows * n * sizeof(int64_t), &o_off);
                bool direct_out = (o_view != nil && o_off == 0ULL);
                id<MTLBuffer> ob = direct_out ? o_view : g_b7_out[p];
                id<MTLBuffer> xb = used_i8[p] ? g_b7_x_i8_pad[p] : g_b7_x_i16_pad[p];
                int eff_mode = (route == 6) ? 5 : route;

                id<MTLCommandBuffer> cb = [g_queue commandBuffer];
                id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
                encodeGemmV2(enc, eff_mode, xb, kp, used_i8[p] ? 1 : 0, t_rows, k, w_view, w_off, n, io, ob, n);
                [enc endEncoding];
                auto tv1 = std::chrono::steady_clock::now();
                view_ms += std::chrono::duration<double, std::milli>(tv1 - tp1).count();

                [cb commit];
                [cb waitUntilCompleted];
                if ([cb status] != MTLCommandBufferStatusCompleted) return -2;
                auto tc1 = std::chrono::steady_clock::now();
                cb_wall_ms += std::chrono::duration<double, std::milli>(tc1 - tv1).count();
                gpu_ms += ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;

                if (!direct_out) {
                    memcpy(out_host_ptrs[p], [g_b7_out[p] contents], (size_t)t_rows * n * sizeof(int64_t));
                }
            }
        } else {
            auto tp0 = std::chrono::steady_clock::now();
            for (int p = 0; p < 7; ++p) {
                uint32_t k = k_arr[p];
                uint32_t kp = ((k + 31U) / 32U) * 32U;
                if (route == 0 || route == 1 || route == 6) {
                    used_i8[p] = neon_try_pack_i64_to_i8_padded(
                        x_host_ptrs[p], t_rows, k, k,
                        reinterpret_cast<int8_t*>([g_b7_x_i8_pad[p] contents]), tp, kp);
                }
                if (!used_i8[p]) {
                    if (!neon_pack_i64_to_i16_padded(
                            x_host_ptrs[p], t_rows, k, k,
                            reinterpret_cast<int16_t*>([g_b7_x_i16_pad[p] contents]), tp, kp)) {
                        return -(20 + p);
                    }
                }
            }
            auto tp1 = std::chrono::steady_clock::now();
            pack_ms = std::chrono::duration<double, std::milli>(tp1 - tp0).count();

            id<MTLBuffer> w_views[7];
            id<MTLBuffer> o_views[7];
            bool direct_outs[7];
            id<MTLCommandBuffer> cb = [g_queue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
            for (int p = 0; p < 7; ++p) {
                uint32_t k = k_arr[p], n = n_arr[p], io = in_out_arr[p];
                uint32_t kp = ((k + 31U) / 32U) * 32U;
                uint64_t w_off = 0ULL, o_off = 0ULL;
                w_views[p] = makePageView(w_host_ptrs[p], (size_t)k * n, &w_off);
                o_views[p] = makePageView(out_host_ptrs[p], (size_t)t_rows * n * sizeof(int64_t), &o_off);
                direct_outs[p] = (o_views[p] != nil && o_off == 0ULL);
                id<MTLBuffer> ob = direct_outs[p] ? o_views[p] : g_b7_out[p];
                id<MTLBuffer> xb = used_i8[p] ? g_b7_x_i8_pad[p] : g_b7_x_i16_pad[p];
                int eff_mode = (route == 6) ? 5 : route;
                encodeGemmV2(enc, eff_mode, xb, kp, used_i8[p] ? 1 : 0, t_rows, k, w_views[p], w_off, n, io, ob, n);
            }
            [enc endEncoding];
            auto tv1 = std::chrono::steady_clock::now();
            view_ms = std::chrono::duration<double, std::milli>(tv1 - tp1).count();

            [cb commit];
            [cb waitUntilCompleted];
            if ([cb status] != MTLCommandBufferStatusCompleted) return -2;
            auto tc1 = std::chrono::steady_clock::now();
            cb_wall_ms = std::chrono::duration<double, std::milli>(tc1 - tv1).count();
            gpu_ms = ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;

            for (int p = 0; p < 7; ++p) {
                if (!direct_outs[p]) {
                    memcpy(out_host_ptrs[p], [g_b7_out[p] contents], (size_t)t_rows * n_arr[p] * sizeof(int64_t));
                }
            }
        }

        auto t_end = std::chrono::steady_clock::now();
        if (pack_ms_out) *pack_ms_out = pack_ms;
        if (view_encode_ms_out) *view_encode_ms_out = view_ms;
        if (cmdbuf_wall_ms_out) *cmdbuf_wall_ms_out = cb_wall_ms;
        if (gpu_ms_out) *gpu_ms_out = gpu_ms;
        if (total_e2e_ms_out) *total_e2e_ms_out = std::chrono::duration<double, std::milli>(t_end - t_start).count();
        return 0;
    }
}

// ============================================================================
// H132: Full Resident 32-Layer + Head Exact-Integer Forward in ONE CommandBuffer!
//   kernel_mode: 0 = Stage-2 32x64, 1 = 64x64_v2 (SPLIT_K=1), 5 = 64x64_v2 + Auto SPLIT_K=4
// ============================================================================
int zk60_forward_resident_batched(
    const int32_t* tok_ids, uint32_t K_req, uint32_t T_len,
    int kernel_mode, int last_token_only_head, int include_head,
    int16_t* x_final_out, int64_t* logits_out, uint32_t* refusals_out,
    double* gpu_ms_out, double* wall_ms_out)
{
    @autoreleasepool {
        const uint32_t M = K_req * T_len;
        if (M == 0 || M > MAX_M || T_len == 0 || T_len > 128) return -1;

        auto t0 = std::chrono::steady_clock::now();
        memcpy([g_tok_buf contents], tok_ids, M * sizeof(int32_t));
        *reinterpret_cast<uint32_t*>([g_bad_buf contents]) = 0U;

        const uint32_t wrho_s_base = (T_len > 1U) ? (32U - __builtin_clz(T_len - 1U)) : 0U;

        id<MTLCommandBuffer> cb = [g_queue commandBuffer];
        id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];

        // 0. Gather token embeddings -> g_x_buf [M, 4096]
        {
            uint32_t dims[2] = {M, DIM_D};
            [enc setComputePipelineState:g_pso_embed];
            [enc setBuffer:g_tok_buf offset:0 atIndex:0];
            [enc setBuffer:g_emb_buf offset:0 atIndex:1];
            [enc setBuffer:g_x_buf offset:0 atIndex:2];
            [enc setBytes:dims length:sizeof(dims) atIndex:3];
            uint32_t tot = M * DIM_D;
            [enc dispatchThreadgroups:MTLSizeMake((tot + 255U) / 256U, 1, 1)
                threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
        }

        // 1..32. All 32 Transformer Blocks on GPU without any host sync!
        for (int l = 0; l < 32; ++l) {
            const LayerDeviceMeta& L = g_layers[l];
            const int bs = L.base_slot;
            const uint32_t F_dim = g_slots[(size_t)(bs + 4)].N;

            // (a) Attention RMSNorm
            {
                struct { uint32_t M, D; int64_t cn; uint32_t tn; int64_t ceps; uint32_t wrho; } np =
                    {M, DIM_D, L.cn_a, L.tn, L.ceps, L.wrho};
                [enc setComputePipelineState:g_pso_norm];
                [enc setBuffer:g_x_buf offset:0 atIndex:0];
                [enc setBuffer:L.gamma_a offset:0 atIndex:1];
                [enc setBuffer:g_norm_buf offset:0 atIndex:2];
                [enc setBytes:&np length:sizeof(np) atIndex:3];
                [enc setBuffer:g_bad_buf offset:0 atIndex:4];
                [enc dispatchThreadgroups:MTLSizeMake(M, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }

            // (b) Q, K, V Exact Integer GEMMs
            const auto& wq = g_slots[(size_t)(bs + 0)];
            const auto& wk = g_slots[(size_t)(bs + 1)];
            const auto& wv = g_slots[(size_t)(bs + 2)];
            encodeGemmV2(enc, kernel_mode, g_norm_buf, DIM_D, 1, M, DIM_D, wq.buf, 0ULL, wq.N, wq.in_out, g_raw0_buf, wq.N);
            encodeGemmV2(enc, kernel_mode, g_norm_buf, DIM_D, 1, M, DIM_D, wk.buf, 0ULL, wk.N, wk.in_out, g_raw1_buf, wk.N);
            encodeGemmV2(enc, kernel_mode, g_norm_buf, DIM_D, 1, M, DIM_D, wv.buf, 0ULL, wv.N, wv.in_out, g_raw2_buf, wv.N);

            // (c) Fused QKV Requant + Per-Request RoPE
            {
                uint32_t qp[4] = {M, T_len, L.sh_qkv, L.sh_rope};
                uint32_t tot = M * 48U * 64U;
                [enc setComputePipelineState:g_pso_qkv_rope];
                [enc setBuffer:g_raw0_buf offset:0 atIndex:0];
                [enc setBuffer:g_raw1_buf offset:0 atIndex:1];
                [enc setBuffer:g_raw2_buf offset:0 atIndex:2];
                [enc setBuffer:L.rope_cos offset:0 atIndex:3];
                [enc setBuffer:L.rope_sin offset:0 atIndex:4];
                [enc setBuffer:g_qr_buf offset:0 atIndex:5];
                [enc setBuffer:g_kr_buf offset:0 atIndex:6];
                [enc setBuffer:g_v_buf offset:0 atIndex:7];
                [enc setBytes:qp length:sizeof(qp) atIndex:8];
                [enc setBuffer:g_bad_buf offset:0 atIndex:9];
                [enc dispatchThreadgroups:MTLSizeMake((tot + 255U) / 256U, 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }

            // (d) Block-Diagonal Per-Request Causal GQA Attention
            {
                uint32_t ap[7] = {K_req, T_len, L.sh_s, L.sh_o, L.f_e, L.f_p, wrho_s_base + L.f_e};
                [enc setComputePipelineState:g_pso_attn];
                [enc setBuffer:g_qr_buf offset:0 atIndex:0];
                [enc setBuffer:g_kr_buf offset:0 atIndex:1];
                [enc setBuffer:g_v_buf offset:0 atIndex:2];
                [enc setBuffer:L.exp_tab offset:0 atIndex:3];
                [enc setBuffer:g_o_buf offset:0 atIndex:4];
                [enc setBytes:ap length:sizeof(ap) atIndex:5];
                [enc setBuffer:g_bad_buf offset:0 atIndex:6];
                [enc dispatchThreadgroups:MTLSizeMake(32, T_len, K_req)
                    threadsPerThreadgroup:MTLSizeMake(128, 1, 1)];
            }

            // (e) Wo Exact Integer GEMM + Residual 1
            const auto& wo = g_slots[(size_t)(bs + 3)];
            encodeGemmV2(enc, kernel_mode, g_o_buf, DIM_D, 1, M, DIM_D, wo.buf, 0ULL, wo.N, wo.in_out, g_raw0_buf, wo.N);
            {
                uint32_t rp[2] = {M * DIM_D, L.sh_ao};
                [enc setComputePipelineState:g_pso_res1];
                [enc setBuffer:g_x_buf offset:0 atIndex:0];
                [enc setBuffer:g_raw0_buf offset:0 atIndex:1];
                [enc setBuffer:g_x1_buf offset:0 atIndex:2];
                [enc setBytes:rp length:sizeof(rp) atIndex:3];
                [enc setBuffer:g_bad_buf offset:0 atIndex:4];
                [enc dispatchThreadgroups:MTLSizeMake((rp[0] + 255U) / 256U, 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }

            // (f) FFN RMSNorm
            {
                struct { uint32_t M, D; int64_t cn; uint32_t tn; int64_t ceps; uint32_t wrho; } np =
                    {M, DIM_D, L.cn_m, L.tn, L.ceps, L.wrho};
                [enc setComputePipelineState:g_pso_norm];
                [enc setBuffer:g_x1_buf offset:0 atIndex:0];
                [enc setBuffer:L.gamma_m offset:0 atIndex:1];
                [enc setBuffer:g_norm_buf offset:0 atIndex:2];
                [enc setBytes:&np length:sizeof(np) atIndex:3];
                [enc setBuffer:g_bad_buf offset:0 atIndex:4];
                [enc dispatchThreadgroups:MTLSizeMake(M, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }

            // (g) Wg & Wu Exact Integer GEMMs + SwiGLU
            const auto& wg = g_slots[(size_t)(bs + 4)];
            const auto& wu = g_slots[(size_t)(bs + 5)];
            encodeGemmV2(enc, kernel_mode, g_norm_buf, DIM_D, 1, M, DIM_D, wg.buf, 0ULL, wg.N, wg.in_out, g_raw0_buf, wg.N);
            encodeGemmV2(enc, kernel_mode, g_norm_buf, DIM_D, 1, M, DIM_D, wu.buf, 0ULL, wu.N, wu.in_out, g_raw1_buf, wu.N);
            {
                uint32_t sp[4] = {M * F_dim, L.sh_g, L.sh_u, L.sh_h};
                [enc setComputePipelineState:g_pso_swiglu];
                [enc setBuffer:g_raw0_buf offset:0 atIndex:0];
                [enc setBuffer:g_raw1_buf offset:0 atIndex:1];
                [enc setBuffer:L.act_tab offset:0 atIndex:2];
                [enc setBuffer:g_h_buf offset:0 atIndex:3];
                [enc setBytes:sp length:sizeof(sp) atIndex:4];
                [enc setBuffer:g_bad_buf offset:0 atIndex:5];
                [enc dispatchThreadgroups:MTLSizeMake((sp[0] + 255U) / 256U, 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }

            // (h) Wd Exact Integer GEMM (int16 activations -> is_i8 = 0) + Residual 2
            const auto& wd = g_slots[(size_t)(bs + 6)];
            encodeGemmV2(enc, kernel_mode, g_h_buf, F_dim, 0, M, F_dim, wd.buf, 0ULL, wd.N, wd.in_out, g_raw0_buf, wd.N);
            {
                uint32_t rp2[3] = {M * DIM_D, L.sh_z, L.sh_r2};
                [enc setComputePipelineState:g_pso_res2];
                [enc setBuffer:g_x1_buf offset:0 atIndex:0];
                [enc setBuffer:g_raw0_buf offset:0 atIndex:1];
                [enc setBuffer:g_x_buf offset:0 atIndex:2];
                [enc setBytes:rp2 length:sizeof(rp2) atIndex:3];
                [enc setBuffer:g_bad_buf offset:0 atIndex:4];
                [enc dispatchThreadgroups:MTLSizeMake((rp2[0] + 255U) / 256U, 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }
        }

        uint32_t M_head = last_token_only_head ? K_req : M;
        if (include_head) {
            id<MTLBuffer> x_for_head = g_x_buf;
            if (last_token_only_head) {
                uint32_t gd[3] = {K_req, T_len, DIM_D};
                [enc setComputePipelineState:g_pso_gather_last];
                [enc setBuffer:g_x_buf offset:0 atIndex:0];
                [enc setBuffer:g_xlast_buf offset:0 atIndex:1];
                [enc setBytes:gd length:sizeof(gd) atIndex:2];
                uint32_t tot = K_req * DIM_D;
                [enc dispatchThreadgroups:MTLSizeMake((tot + 255U) / 256U, 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
                x_for_head = g_xlast_buf;
            }
            {
                struct { uint32_t M, D; int64_t cn; uint32_t tn; int64_t ceps; uint32_t wrho; } np =
                    {M_head, DIM_D, g_fn_cn, g_fn_tn, g_fn_ceps, g_fn_wrho};
                [enc setComputePipelineState:g_pso_norm];
                [enc setBuffer:x_for_head offset:0 atIndex:0];
                [enc setBuffer:g_final_gamma_buf offset:0 atIndex:1];
                [enc setBuffer:g_norm_buf offset:0 atIndex:2];
                [enc setBytes:&np length:sizeof(np) atIndex:3];
                [enc setBuffer:g_bad_buf offset:0 atIndex:4];
                [enc dispatchThreadgroups:MTLSizeMake(M_head, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }
            const auto& wh = g_slots[224];
            encodeGemmV2(enc, kernel_mode, g_norm_buf, DIM_D, 1, M_head, DIM_D, wh.buf, 0ULL, wh.N, wh.in_out, g_raw0_buf, wh.N);
            {
                uint32_t hd[2] = {M_head, wh.N};
                uint64_t tot = (uint64_t)hd[0] * (uint64_t)hd[1];
                [enc setComputePipelineState:g_pso_head_scale];
                [enc setBuffer:g_raw0_buf offset:0 atIndex:0];
                [enc setBuffer:g_head_mult_buf offset:0 atIndex:1];
                [enc setBytes:hd length:sizeof(hd) atIndex:2];
                [enc dispatchThreadgroups:MTLSizeMake((NSUInteger)((tot + 255ULL) / 256ULL), 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            }
        }

        [enc endEncoding];
        [cb commit];
        [cb waitUntilCompleted];
        if ([cb status] != MTLCommandBufferStatusCompleted) return -2;

        if (x_final_out) {
            memcpy(x_final_out, [g_x_buf contents], (size_t)M * DIM_D * sizeof(int16_t));
        }
        if (include_head && logits_out) {
            memcpy(logits_out, [g_raw0_buf contents], (size_t)M_head * g_slots[224].N * sizeof(int64_t));
        }
        if (refusals_out) {
            *refusals_out = *reinterpret_cast<const uint32_t*>([g_bad_buf contents]);
        }
        auto t1 = std::chrono::steady_clock::now();
        if (gpu_ms_out)  *gpu_ms_out  = ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
        if (wall_ms_out) *wall_ms_out = std::chrono::duration<double, std::milli>(t1 - t0).count();
        return 0;
    }
}

struct FP16RingLayer {
    id<MTLBuffer> wq = nil, wk = nil, wv = nil, wo = nil, wg = nil, wu = nil, wd = nil;
    MPSMatrix *mq = nil, *mk = nil, *mv = nil, *mo = nil, *mg = nil, *mu = nil, *md = nil;
};
static std::vector<FP16RingLayer> g_fp16_ring;
static id<MTLBuffer> g_fp16_bHead = nil;
static MPSMatrix* g_fp16_mHead = nil;
static id<MTLBuffer> g_fp16_bx = nil, g_fp16_by = nil, g_fp16_bxlast = nil, g_fp16_bylast = nil;
static id<MTLBuffer> g_fp16_bq = nil, g_fp16_bk = nil, g_fp16_bv = nil, g_fp16_bs = nil;
static id<MTLBuffer> g_fp16_bo = nil, g_fp16_bg = nil, g_fp16_bu = nil, g_fp16_bh = nil, g_fp16_blogits = nil;

static MPSMatrix* allocFP16Mat(uint32_t rows, uint32_t cols, __strong id<MTLBuffer>* b_out) {
    size_t bytes = (size_t)rows * (size_t)cols * 2ULL;
    id<MTLBuffer> b = [g_dev newBufferWithLength:bytes options:MTLResourceStorageModeShared];
    *b_out = b;
    uint16_t* p = (uint16_t*)[b contents];
    for (size_t i = 0; i < (size_t)rows * cols; i += 64) p[i] = 0x211FU;
    MPSMatrixDescriptor* desc = [MPSMatrixDescriptor matrixDescriptorWithRows:rows columns:cols rowBytes:(NSUInteger)cols * 2U dataType:MPSDataTypeFloat16];
    return [[MPSMatrix alloc] initWithBuffer:b descriptor:desc];
}

int zk60_init_fp16_ring() {
    @autoreleasepool {
        if (!g_fp16_ring.empty()) return 0;
        const uint32_t D = 4096, KV = 1024, F = 14336, V = 128256, H = 32;
        g_fp16_ring.resize(6);
        for (int r = 0; r < 6; ++r) {
            g_fp16_ring[r].mq = allocFP16Mat(D, D, &g_fp16_ring[r].wq);
            g_fp16_ring[r].mk = allocFP16Mat(KV, D, &g_fp16_ring[r].wk);
            g_fp16_ring[r].mv = allocFP16Mat(KV, D, &g_fp16_ring[r].wv);
            g_fp16_ring[r].mo = allocFP16Mat(D, D, &g_fp16_ring[r].wo);
            g_fp16_ring[r].mg = allocFP16Mat(F, D, &g_fp16_ring[r].wg);
            g_fp16_ring[r].mu = allocFP16Mat(F, D, &g_fp16_ring[r].wu);
            g_fp16_ring[r].md = allocFP16Mat(D, F, &g_fp16_ring[r].wd);
        }
        g_fp16_mHead = allocFP16Mat(V, D, &g_fp16_bHead);
        allocFP16Mat(MAX_M, D, &g_fp16_bx);
        allocFP16Mat(MAX_M, D, &g_fp16_by);
        allocFP16Mat(16U,   D, &g_fp16_bxlast);
        allocFP16Mat(16U,   D, &g_fp16_bylast);
        allocFP16Mat(MAX_M, D, &g_fp16_bq);
        allocFP16Mat(MAX_M, KV, &g_fp16_bk);
        allocFP16Mat(MAX_M, KV, &g_fp16_bv);
        allocFP16Mat(MAX_M * H, 128U, &g_fp16_bs); // up to K=8 * H=32 * T=128 * 128
        allocFP16Mat(MAX_M, D, &g_fp16_bo);
        allocFP16Mat(MAX_M, F, &g_fp16_bg);
        allocFP16Mat(MAX_M, F, &g_fp16_bu);
        allocFP16Mat(MAX_M, F, &g_fp16_bh);
        allocFP16Mat(MAX_M, V, &g_fp16_blogits);
        return 0;
    }
}

void zk60_free_fp16_ring() {
    @autoreleasepool {
        g_fp16_ring.clear();
        g_fp16_mHead = nil; g_fp16_bHead = nil;
        g_fp16_bx = g_fp16_by = g_fp16_bxlast = g_fp16_bylast = nil;
        g_fp16_bq = g_fp16_bk = g_fp16_bv = g_fp16_bs = nil;
        g_fp16_bo = g_fp16_bg = g_fp16_bu = g_fp16_bh = g_fp16_blogits = nil;
    }
}

int zk60_run_fp16_batched_llama8b(
    uint32_t K_req, uint32_t T_len, int last_token_only_head,
    double* gpu_ms_out, double* wall_ms_out)
{
    @autoreleasepool {
        if (g_fp16_ring.empty()) return -1;
        const uint32_t D = 4096, KV = 1024, F = 14336, V = 128256, H = 32, DH = 128;
        const uint32_t M = K_req * T_len;
        const uint32_t M_head = last_token_only_head ? K_req : M;

        auto view2d = [&](id<MTLBuffer> b, uint32_t r, uint32_t c) -> MPSMatrix* {
            MPSMatrixDescriptor* d = [MPSMatrixDescriptor matrixDescriptorWithRows:r columns:c rowBytes:(NSUInteger)c * 2U dataType:MPSDataTypeFloat16];
            return [[MPSMatrix alloc] initWithBuffer:b descriptor:d];
        };
        MPSMatrix* mx      = view2d(g_fp16_bx, M, D);
        MPSMatrix* my      = view2d(g_fp16_by, M, D);
        MPSMatrix* mq_act  = view2d(g_fp16_bq, M, D);
        MPSMatrix* mk_act  = view2d(g_fp16_bk, M, KV);
        MPSMatrix* mv_act  = view2d(g_fp16_bv, M, KV);
        MPSMatrix* mo_act  = view2d(g_fp16_bo, M, D);
        MPSMatrix* mg_act  = view2d(g_fp16_bg, M, F);
        MPSMatrix* mu_act  = view2d(g_fp16_bu, M, F);
        MPSMatrix* mh_act  = view2d(g_fp16_bh, M, F);
        MPSMatrix* my_head = view2d(last_token_only_head ? g_fp16_bylast : g_fp16_by, M_head, D);
        MPSMatrix* mlogits = view2d(g_fp16_blogits, M_head, V);

        // Per-request K_req batched MPSMatrix views for O(K_req * T_len^2) sequence attention
        MPSMatrixDescriptor* dQ_b = [MPSMatrixDescriptor matrixDescriptorWithRows:H * T_len columns:DH matrices:K_req rowBytes:DH * 2U matrixBytes:(NSUInteger)(H * T_len * DH * 2U) dataType:MPSDataTypeFloat16];
        MPSMatrixDescriptor* dK_b = [MPSMatrixDescriptor matrixDescriptorWithRows:T_len columns:DH matrices:K_req rowBytes:DH * 2U matrixBytes:(NSUInteger)(T_len * KV * 2U) dataType:MPSDataTypeFloat16];
        MPSMatrixDescriptor* dS_b = [MPSMatrixDescriptor matrixDescriptorWithRows:H * T_len columns:T_len matrices:K_req rowBytes:T_len * 2U matrixBytes:(NSUInteger)(H * T_len * T_len * 2U) dataType:MPSDataTypeFloat16];
        MPSMatrix* mQ_b = [[MPSMatrix alloc] initWithBuffer:g_fp16_bq descriptor:dQ_b];
        MPSMatrix* mK_b = [[MPSMatrix alloc] initWithBuffer:g_fp16_bk descriptor:dK_b];
        MPSMatrix* mV_b = [[MPSMatrix alloc] initWithBuffer:g_fp16_bv descriptor:dK_b];
        MPSMatrix* mS_b = [[MPSMatrix alloc] initWithBuffer:g_fp16_bs descriptor:dS_b];
        MPSMatrix* mO_b = [[MPSMatrix alloc] initWithBuffer:g_fp16_bo descriptor:dQ_b];

        MPSMatrixMultiplication* mm_dd     = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:M resultColumns:D  interiorColumns:D  alpha:1.0 beta:0.0];
        MPSMatrixMultiplication* mm_dkv    = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:M resultColumns:KV interiorColumns:D  alpha:1.0 beta:0.0];
        MPSMatrixMultiplication* mm_df     = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:M resultColumns:F  interiorColumns:D  alpha:1.0 beta:0.0];
        MPSMatrixMultiplication* mm_fd_res = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:M resultColumns:D  interiorColumns:F  alpha:1.0 beta:1.0];
        MPSMatrixMultiplication* mm_dd_res = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:M resultColumns:D  interiorColumns:D  alpha:1.0 beta:1.0];
        MPSMatrixMultiplication* mm_score  = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:H * T_len resultColumns:T_len interiorColumns:DH alpha:0.088388 beta:0.0];
        MPSMatrixMultiplication* mm_sv     = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:NO  resultRows:H * T_len resultColumns:DH    interiorColumns:T_len alpha:1.0 beta:0.0];
        MPSMatrixMultiplication* mm_head   = [[MPSMatrixMultiplication alloc] initWithDevice:g_dev transposeLeft:NO transposeRight:YES resultRows:M_head resultColumns:V interiorColumns:D alpha:1.0 beta:0.0];

        auto t0 = std::chrono::steady_clock::now();
        id<MTLCommandBuffer> cb = [g_queue commandBuffer];
        for (int l = 0; l < 32; ++l) {
            const auto& lw = g_fp16_ring[(size_t)(l % 6)];
            {
                id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
                uint32_t d_arg = D;
                [enc setComputePipelineState:g_pso_fp16_norm];
                [enc setBuffer:g_fp16_bx offset:0 atIndex:0];
                [enc setBuffer:g_fp16_by offset:0 atIndex:1];
                [enc setBytes:&d_arg length:4 atIndex:2];
                [enc dispatchThreadgroups:MTLSizeMake(M, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
                [enc endEncoding];
            }
            [mm_dd encodeToCommandBuffer:cb leftMatrix:my rightMatrix:lw.mq resultMatrix:mq_act];
            [mm_dkv encodeToCommandBuffer:cb leftMatrix:my rightMatrix:lw.mk resultMatrix:mk_act];
            [mm_dkv encodeToCommandBuffer:cb leftMatrix:my rightMatrix:lw.mv resultMatrix:mv_act];
            [mm_score encodeToCommandBuffer:cb leftMatrix:mQ_b rightMatrix:mK_b resultMatrix:mS_b];
            [mm_sv encodeToCommandBuffer:cb leftMatrix:mS_b rightMatrix:mV_b resultMatrix:mO_b];
            [mm_dd_res encodeToCommandBuffer:cb leftMatrix:mo_act rightMatrix:lw.mo resultMatrix:mx];
            {
                id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
                uint32_t d_arg = D;
                [enc setComputePipelineState:g_pso_fp16_norm];
                [enc setBuffer:g_fp16_bx offset:0 atIndex:0];
                [enc setBuffer:g_fp16_by offset:0 atIndex:1];
                [enc setBytes:&d_arg length:4 atIndex:2];
                [enc dispatchThreadgroups:MTLSizeMake(M, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
                [enc endEncoding];
            }
            [mm_df encodeToCommandBuffer:cb leftMatrix:my rightMatrix:lw.mg resultMatrix:mg_act];
            [mm_df encodeToCommandBuffer:cb leftMatrix:my rightMatrix:lw.mu resultMatrix:mu_act];
            {
                id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
                uint32_t mf = M * F;
                [enc setComputePipelineState:g_pso_fp16_swiglu];
                [enc setBuffer:g_fp16_bg offset:0 atIndex:0];
                [enc setBuffer:g_fp16_bu offset:0 atIndex:1];
                [enc setBuffer:g_fp16_bh offset:0 atIndex:2];
                [enc setBytes:&mf length:4 atIndex:3];
                [enc dispatchThreadgroups:MTLSizeMake((mf + 255U) / 256U, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
                [enc endEncoding];
            }
            [mm_fd_res encodeToCommandBuffer:cb leftMatrix:mh_act rightMatrix:lw.md resultMatrix:mx];
        }
        {
            id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
            id<MTLBuffer> src_x = g_fp16_bx;
            id<MTLBuffer> dst_y = g_fp16_by;
            if (last_token_only_head) {
                uint32_t gd[3] = {K_req, T_len, D};
                uint32_t tot = K_req * D;
                [enc setComputePipelineState:g_pso_fp16_gather_last];
                [enc setBuffer:g_fp16_bx offset:0 atIndex:0];
                [enc setBuffer:g_fp16_bxlast offset:0 atIndex:1];
                [enc setBytes:gd length:sizeof(gd) atIndex:2];
                [enc dispatchThreadgroups:MTLSizeMake((tot + 255U) / 256U, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
                src_x = g_fp16_bxlast;
                dst_y = g_fp16_bylast;
            }
            uint32_t d_arg = D;
            [enc setComputePipelineState:g_pso_fp16_norm];
            [enc setBuffer:src_x offset:0 atIndex:0];
            [enc setBuffer:dst_y offset:0 atIndex:1];
            [enc setBytes:&d_arg length:4 atIndex:2];
            [enc dispatchThreadgroups:MTLSizeMake(M_head, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
            [enc endEncoding];
        }
        [mm_head encodeToCommandBuffer:cb leftMatrix:my_head rightMatrix:g_fp16_mHead resultMatrix:mlogits];
        [cb commit];
        [cb waitUntilCompleted];
        if ([cb status] != MTLCommandBufferStatusCompleted) return -2;
        auto t1 = std::chrono::steady_clock::now();
        if (gpu_ms_out)  *gpu_ms_out  = ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
        if (wall_ms_out) *wall_ms_out = std::chrono::duration<double, std::milli>(t1 - t0).count();
        return 0;
    }
}

} // extern "C"
