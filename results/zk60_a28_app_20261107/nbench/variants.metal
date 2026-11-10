// ================================================================ A28 bench variants
// (appended to the tree's metal_kernels.metal; every variant must write the words the tree's kernels write)

inline ulong a28_tw(uint s, uint k, constant HeadArgs &args, device const ulong *hw, device const ulong *tw) {
    return args.use_hw != 0u ? hw[ulong(k) << (TILE_LOG - s)] : tw[ulong(k) * (1UL << (args.max_log - s))];
}
// the radix-2 butterfly of k_ntt_stage: (u, v) -> (u + w v, u - w v)
inline void a28_bfly(thread ulong &u, thread ulong &v, ulong w) {
    ulong t = gl_mul(v, w);
    v = gl_sub(u, t);
    u = gl_add(u, t);
}
inline uint a28_swz(uint p) { return p ^ ((p >> 4) & 15u); }

// ---------------------------------------------------------------- head: radix 16 / 16 / 8 in registers
// 128 threads per 2048-word tile; pass 1 (stages 1..4) on positions 16 t + j, pass 2 (5..8) on
// lo + 16 m + 256 hi, pass 3 (9..11) on q + 256 m; two threadgroup exchanges.
kernel void k_a28_head16(device const ulong *src [[buffer(0)]],
                         device const ulong *pads [[buffer(1)]],
                         device const ulong *pows [[buffer(2)]],
                         device ulong *dst [[buffer(3)]],
                         device const ulong *tw [[buffer(4)]],
                         constant HeadArgs &args [[buffer(5)]],
                         device const ulong *hw [[buffer(6)]],
                         uint2 tid2 [[thread_position_in_threadgroup]],
                         uint2 tg [[threadgroup_position_in_grid]]) {
    uint t = tid2.x;
    threadgroup ulong sh[TILE];
    ulong r = ulong(tg.y);
    ulong base = ulong(tg.x) << TILE_LOG;
    ulong x[16];
    #pragma unroll
    for (uint j = 0; j < 16; j++) {
        x[j] = head_input(args.mode, src, pads, pows, r, rev_bits(base + ulong(16u * t + j), args.log_n), args.log_n, args.log_src, args.q);
    }
    #pragma unroll
    for (uint s = 1; s <= 4; s++) {
        uint h = 1u << (s - 1);
        #pragma unroll
        for (uint j = 0; j < 16; j++) {
            if ((j & h) == 0u) {
                a28_bfly(x[j], x[j + h], a28_tw(s, j & (h - 1u), args, hw, tw));
            }
        }
    }
    #pragma unroll
    for (uint j = 0; j < 16; j++) { sh[a28_swz(16u * t + j)] = x[j]; }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint lo = t & 15u, hi = t >> 4;
    #pragma unroll
    for (uint m = 0; m < 16; m++) { x[m] = sh[a28_swz(lo + 16u * m + 256u * hi)]; }
    #pragma unroll
    for (uint s = 5; s <= 8; s++) {
        uint h = 1u << (s - 5);
        #pragma unroll
        for (uint m = 0; m < 16; m++) {
            if ((m & h) == 0u) {
                a28_bfly(x[m], x[m + h], a28_tw(s, lo + 16u * (m & (h - 1u)), args, hw, tw));
            }
        }
    }
    #pragma unroll
    for (uint m = 0; m < 16; m++) { sh[a28_swz(lo + 16u * m + 256u * hi)] = x[m]; }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    device ulong *row = dst + (r << args.log_n) + base;
    #pragma unroll
    for (uint g = 0; g < 2; g++) {
        uint q = t + 128u * g;
        ulong y[8];
        #pragma unroll
        for (uint m = 0; m < 8; m++) { y[m] = sh[a28_swz(q + 256u * m)]; }
        #pragma unroll
        for (uint s = 9; s <= 11; s++) {
            uint h = 1u << (s - 9);
            #pragma unroll
            for (uint m = 0; m < 8; m++) {
                if ((m & h) == 0u) {
                    a28_bfly(y[m], y[m + h], a28_tw(s, q + 256u * (m & (h - 1u)), args, hw, tw));
                }
            }
        }
        #pragma unroll
        for (uint m = 0; m < 8; m++) { row[q + 256u * m] = args.apply_scale != 0u ? gl_mul(y[m], args.scale) : y[m]; }
    }
}

// ---------------------------------------------------------------- head: radix 8 / 8 / 8 / 4, 256 threads
kernel void k_a28_head8(device const ulong *src [[buffer(0)]],
                        device const ulong *pads [[buffer(1)]],
                        device const ulong *pows [[buffer(2)]],
                        device ulong *dst [[buffer(3)]],
                        device const ulong *tw [[buffer(4)]],
                        constant HeadArgs &args [[buffer(5)]],
                        device const ulong *hw [[buffer(6)]],
                        uint2 tid2 [[thread_position_in_threadgroup]],
                        uint2 tg [[threadgroup_position_in_grid]]) {
    uint t = tid2.x;   // 0..255
    threadgroup ulong sh[TILE];
    ulong r = ulong(tg.y);
    ulong base = ulong(tg.x) << TILE_LOG;
    ulong x[8];
    // pass 1: stages 1..3, positions 8 t + j
    #pragma unroll
    for (uint j = 0; j < 8; j++) {
        x[j] = head_input(args.mode, src, pads, pows, r, rev_bits(base + ulong(8u * t + j), args.log_n), args.log_n, args.log_src, args.q);
    }
    #pragma unroll
    for (uint s = 1; s <= 3; s++) {
        uint h = 1u << (s - 1);
        #pragma unroll
        for (uint j = 0; j < 8; j++) {
            if ((j & h) == 0u) { a28_bfly(x[j], x[j + h], a28_tw(s, j & (h - 1u), args, hw, tw)); }
        }
    }
    #pragma unroll
    for (uint j = 0; j < 8; j++) { uint p = 8u * t + j; sh[p ^ ((p >> 4) & 7u)] = x[j]; }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // pass 2: stages 4..6, positions lo + 8 m + 64 hi (lo = t & 7, hi = t >> 3)
    {
        uint lo = t & 7u, hi = t >> 3;
        #pragma unroll
        for (uint m = 0; m < 8; m++) { uint p = lo + 8u * m + 64u * hi; x[m] = sh[p ^ ((p >> 4) & 7u)]; }
        #pragma unroll
        for (uint s = 4; s <= 6; s++) {
            uint h = 1u << (s - 4);
            #pragma unroll
            for (uint m = 0; m < 8; m++) {
                if ((m & h) == 0u) { a28_bfly(x[m], x[m + h], a28_tw(s, lo + 8u * (m & (h - 1u)), args, hw, tw)); }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        #pragma unroll
        for (uint m = 0; m < 8; m++) { uint p = lo + 8u * m + 64u * hi; sh[p] = x[m]; }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // pass 3: stages 7..9, positions lo + 64 m + 512 hi (lo = t & 63, hi = t >> 6)
    {
        uint lo = t & 63u, hi = t >> 6;
        #pragma unroll
        for (uint m = 0; m < 8; m++) { x[m] = sh[lo + 64u * m + 512u * hi]; }
        #pragma unroll
        for (uint s = 7; s <= 9; s++) {
            uint h = 1u << (s - 7);
            #pragma unroll
            for (uint m = 0; m < 8; m++) {
                if ((m & h) == 0u) { a28_bfly(x[m], x[m + h], a28_tw(s, lo + 64u * (m & (h - 1u)), args, hw, tw)); }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        #pragma unroll
        for (uint m = 0; m < 8; m++) { sh[lo + 64u * m + 512u * hi] = x[m]; }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // pass 4: stages 10..11, positions q + 512 m, m < 4, two groups (q = t, t + 256)
    device ulong *row = dst + (r << args.log_n) + base;
    #pragma unroll
    for (uint g = 0; g < 2; g++) {
        uint q = t + 256u * g;
        ulong y[4];
        #pragma unroll
        for (uint m = 0; m < 4; m++) { y[m] = sh[q + 512u * m]; }
        #pragma unroll
        for (uint s = 10; s <= 11; s++) {
            uint h = 1u << (s - 10);
            #pragma unroll
            for (uint m = 0; m < 4; m++) {
                if ((m & h) == 0u) { a28_bfly(y[m], y[m + h], a28_tw(s, q + 512u * (m & (h - 1u)), args, hw, tw)); }
            }
        }
        #pragma unroll
        for (uint m = 0; m < 4; m++) { row[q + 512u * m] = args.apply_scale != 0u ? gl_mul(y[m], args.scale) : y[m]; }
    }
}

// ---------------------------------------------------------------- tail: every stage in registers
// one thread per column p of the 2048-word tile (2^G words at stride 2048), stages 12 .. 11 + G
template <uint G>
kernel void k_a28_tail_reg(device ulong *a [[buffer(0)]],
                           device const ulong *tw [[buffer(1)]],
                           constant TailArgs &args [[buffer(2)]],
                           uint2 gid [[thread_position_in_grid]]) {
    uint p = gid.x;
    device ulong *row = a + (ulong(gid.y) << args.log_n);
    ulong x[1u << G];
    #pragma unroll
    for (uint h = 0; h < (1u << G); h++) { x[h] = row[ulong(p) + (ulong(h) << TILE_LOG)]; }
    #pragma unroll
    for (uint hs = 0; hs < G; hs++) {
        uint s = TILE_LOG + 1u + hs;
        uint half_ = 1u << hs;
        ulong stride = 1UL << (args.max_log - s);
        ulong w[1u << (G - 1)];
        #pragma unroll
        for (uint kk = 0; kk < half_; kk++) { w[kk] = tw[(ulong(p) + (ulong(kk) << TILE_LOG)) * stride]; }
        #pragma unroll
        for (uint h0 = 0; h0 < (1u << G); h0++) {
            if ((h0 & half_) == 0u) { a28_bfly(x[h0], x[h0 + half_], w[h0 & (half_ - 1u)]); }
        }
    }
    #pragma unroll
    for (uint h = 0; h < (1u << G); h++) {
        row[ulong(p) + (ulong(h) << TILE_LOG)] = args.apply_scale != 0u ? gl_mul(x[h], args.scale) : x[h];
    }
}
template [[host_name("k_a28_tail_reg5")]] kernel void k_a28_tail_reg<5>(device ulong *a [[buffer(0)]], device const ulong *tw [[buffer(1)]], constant TailArgs &args [[buffer(2)]], uint2 gid [[thread_position_in_grid]]);
template [[host_name("k_a28_tail_reg3")]] kernel void k_a28_tail_reg<3>(device ulong *a [[buffer(0)]], device const ulong *tw [[buffer(1)]], constant TailArgs &args [[buffer(2)]], uint2 gid [[thread_position_in_grid]]);

// ---------------------------------------------------------------- hash: one thread per (column, chunk)
// each 1024-byte chunk's chaining value (or, for a one-chunk column, the root) written; the tree merge after
kernel void k_a28_hash_chunk(device const ulong *enc [[buffer(0)]],
                             device uint *cvs [[buffer(1)]],
                             device uint *leaves [[buffer(2)]],
                             constant HashArgs &args [[buffer(3)]],
                             uint2 gid [[thread_position_in_grid]]) {
    ulong j = ulong(gid.x);
    ulong c = ulong(gid.y);
    ulong rows = args.rows, nn = args.nn;
    if (j >= nn) { return; }
    ulong total = rows * 8UL;
    ulong n_chunks = (total + 1023UL) / 1024UL;
    if (c >= n_chunks) { return; }
    uint kw[8];
    uint base_flags = args.keyed != 0 ? KEYED_HASH : 0u;
    for (uint i = 0; i < 8; i++) { kw[i] = args.keyed != 0 ? args.key[i] : B3_IV[i]; }
    ulong chunk_bytes = min(1024UL, total - c * 1024UL);
    uint n_blocks = uint((chunk_bytes + 63UL) / 64UL);
    uint cv[8];
    for (uint i = 0; i < 8; i++) { cv[i] = kw[i]; }
    uint block[16];
    for (uint blk = 0; blk < n_blocks; blk++) {
        b3_load_block(enc, rows, nn, j, c, blk, block);
        bool last = blk + 1 == n_blocks;
        uint len = last ? uint(chunk_bytes - ulong(blk) * 64UL) : 64u;
        uint fl = base_flags | (blk == 0 ? CHUNK_START : 0u) | (last ? CHUNK_END : 0u) | ((last && n_chunks == 1) ? ROOT : 0u);
        uint nxt[8];
        b3_compress(cv, block, c, len, fl, nxt);
        for (uint i = 0; i < 8; i++) { cv[i] = nxt[i]; }
    }
    if (n_chunks == 1) {
        for (uint i = 0; i < 8; i++) { leaves[j * 8 + i] = cv[i]; }
    } else {
        for (uint i = 0; i < 8; i++) { cvs[(c * nn + j) * 8 + i] = cv[i]; }
    }
}

kernel void k_a28_hash_merge(device const uint *cvs [[buffer(0)]],
                             device uint *leaves [[buffer(1)]],
                             constant HashArgs &args [[buffer(2)]],
                             uint gid [[thread_position_in_grid]]) {
    ulong j = ulong(gid);
    ulong rows = args.rows, nn = args.nn;
    if (j >= nn) { return; }
    ulong n_chunks = (rows * 8UL + 1023UL) / 1024UL;
    if (n_chunks <= 1) { return; }
    uint kw[8];
    uint base_flags = args.keyed != 0 ? KEYED_HASH : 0u;
    for (uint i = 0; i < 8; i++) { kw[i] = args.keyed != 0 ? args.key[i] : B3_IV[i]; }
    uint stack[B3_STACK * 8];
    uint sp = 0;
    uint cv[8];
    for (ulong c = 0; c + 1 < n_chunks; c++) {
        for (uint i = 0; i < 8; i++) { cv[i] = cvs[(c * nn + j) * 8 + i]; }
        ulong total_chunks = c + 1;
        while ((total_chunks & 1UL) == 0UL) {
            sp -= 1;
            uint pb[16];
            for (uint i = 0; i < 8; i++) { pb[i] = stack[sp * 8 + i]; pb[8 + i] = cv[i]; }
            uint nxt[8];
            b3_compress(kw, pb, 0UL, 64u, base_flags | PARENT, nxt);
            for (uint i = 0; i < 8; i++) { cv[i] = nxt[i]; }
            total_chunks >>= 1;
        }
        for (uint i = 0; i < 8; i++) { stack[sp * 8 + i] = cv[i]; }
        sp += 1;
    }
    uint right[8];
    for (uint i = 0; i < 8; i++) { right[i] = cvs[((n_chunks - 1) * nn + j) * 8 + i]; }
    uint root[8];
    while (sp > 0) {
        sp -= 1;
        uint pb[16];
        for (uint i = 0; i < 8; i++) { pb[i] = stack[sp * 8 + i]; pb[8 + i] = right[i]; }
        uint nxt[8];
        b3_compress(kw, pb, 0UL, 64u, base_flags | PARENT | (sp == 0 ? ROOT : 0u), nxt);
        for (uint i = 0; i < 8; i++) { right[i] = nxt[i]; }
    }
    for (uint i = 0; i < 8; i++) { root[i] = right[i]; leaves[j * 8 + i] = root[i]; }
}

// ---------------------------------------------------------------- ALU probes (timing only; the words are not a transform)
// 16 words per thread, 11 rounds of 8 butterflies each (88 butterflies), contiguous loads and stores
template <uint V>
inline void a28_bf_v(thread ulong &u, thread ulong &v, ulong w) {
    if (V == 0u) {
        a28_bfly(u, v, w);
    } else if (V == 1u) {
        // the add/sub alone (no product): the cost of the two field additions
        ulong t = v ^ w;
        v = gl_sub(u, t);
        u = gl_add(u, t);
    } else {
        // the product alone
        u = gl_mul(v, w);
        v = u ^ v;
    }
}
template <uint V>
kernel void k_a28_alu(device ulong *a [[buffer(0)]],
                      device const ulong *hw [[buffer(1)]],
                      uint gid [[thread_position_in_grid]]) {
    ulong x[16];
    #pragma unroll
    for (uint j = 0; j < 16; j++) { x[j] = a[ulong(gid) * 16UL + j]; }
    #pragma unroll
    for (uint s = 0; s < 11; s++) {
        uint h = 1u << (s & 3u);
        #pragma unroll
        for (uint j = 0; j < 16; j++) {
            if ((j & h) == 0u) { a28_bf_v<V>(x[j], x[j + h], hw[(s * 16u + j) & 1023u]); }
        }
    }
    #pragma unroll
    for (uint j = 0; j < 16; j++) { a[ulong(gid) * 16UL + j] = x[j]; }
}
template [[host_name("k_a28_alu0")]] kernel void k_a28_alu<0>(device ulong *a [[buffer(0)]], device const ulong *hw [[buffer(1)]], uint gid [[thread_position_in_grid]]);
template [[host_name("k_a28_alu1")]] kernel void k_a28_alu<1>(device ulong *a [[buffer(0)]], device const ulong *hw [[buffer(1)]], uint gid [[thread_position_in_grid]]);
template [[host_name("k_a28_alu2")]] kernel void k_a28_alu<2>(device ulong *a [[buffer(0)]], device const ulong *hw [[buffer(1)]], uint gid [[thread_position_in_grid]]);

// ---------------------------------------------------------------- field arithmetic variants (A28)
// b: the add's two corrections as one (canonical inputs: a + b < 2p, so a carry or s >= p means s - p,
//    which is s + EPS mod 2^64); c: explicit 32-bit halves
inline ulong a28_add_b(ulong a, ulong b) {
    ulong s = a + b;
    bool ov = (s < a) | (s >= GL_P);
    return ov ? s + GL_EPS : s;
}
inline ulong a28_add_c(ulong a, ulong b) {
    uint2 x = as_type<uint2>(a), y = as_type<uint2>(b);
    uint lo = x.x + y.x;
    uint c0 = lo < x.x ? 1u : 0u;
    uint hi = x.y + y.y + c0;
    bool carry = c0 != 0u ? (hi <= x.y) : (hi < x.y);
    bool ge = (hi == 0xFFFFFFFFu) & (lo != 0u);
    if (carry | ge) { hi += (lo != 0u) ? 1u : 0u; lo -= 1u; }
    return as_type<ulong>(uint2(lo, hi));
}
inline ulong a28_sub_c(ulong a, ulong b) {
    uint2 x = as_type<uint2>(a), y = as_type<uint2>(b);
    uint lo = x.x - y.x;
    uint b0 = x.x < y.x ? 1u : 0u;
    uint hi = x.y - y.y - b0;
    bool borrow = b0 != 0u ? (x.y <= y.y) : (x.y < y.y);
    if (borrow) { hi -= (lo != 0xFFFFFFFFu) ? 1u : 0u; lo += 1u; }
    return as_type<ulong>(uint2(lo, hi));
}
// reduce128 with t1 = h0 * EPS as (h0 << 32) - h0 (no product)
inline ulong a28_reduce_b(ulong x_lo, ulong x_hi) {
    ulong x_hi_hi = x_hi >> 32;
    ulong h0 = x_hi & GL_EPS;
    ulong t0 = x_lo - x_hi_hi;
    if (x_lo < x_hi_hi) { t0 -= GL_EPS; }
    ulong t1 = (h0 << 32) - h0;
    ulong res = t0 + t1;
    if (res < t0) { res += GL_EPS; }
    return gl_canon(res);
}
inline ulong a28_mul_b(ulong a, ulong b) {
    ulong lo, hi;
    mul_64x64(a, b, lo, hi);
    return a28_reduce_b(lo, hi);
}
// the product in 32-bit limbs (mulhi), the reduction in 32-bit halves
inline ulong a28_mul_c(ulong a, ulong b) {
    uint2 x = as_type<uint2>(a), y = as_type<uint2>(b);
    uint p00l = x.x * y.x, p00h = mulhi(x.x, y.x);
    uint p01l = x.x * y.y, p01h = mulhi(x.x, y.y);
    uint p10l = x.y * y.x, p10h = mulhi(x.y, y.x);
    uint p11l = x.y * y.y, p11h = mulhi(x.y, y.y);
    ulong m = ulong(p00h) + ulong(p01l) + ulong(p10l);
    ulong lo = (m << 32) | ulong(p00l);
    ulong hi = (ulong(p11h) << 32 | ulong(p11l)) + ulong(p01h) + ulong(p10h) + (m >> 32);
    return a28_reduce_b(lo, hi);
}
template <uint V> inline ulong fadd(ulong a, ulong b) { return V == 0u ? gl_add(a, b) : (V == 1u ? a28_add_b(a, b) : a28_add_c(a, b)); }
template <uint V> inline ulong fsub(ulong a, ulong b) { return V == 2u ? a28_sub_c(a, b) : gl_sub(a, b); }
template <uint V> inline ulong fmul(ulong a, ulong b) { return V == 0u ? gl_mul(a, b) : (V == 1u ? a28_mul_b(a, b) : a28_mul_c(a, b)); }
template <uint V>
kernel void k_a28_falu(device ulong *a [[buffer(0)]],
                       device const ulong *hw [[buffer(1)]],
                       uint gid [[thread_position_in_grid]]) {
    ulong x[16];
    #pragma unroll
    for (uint j = 0; j < 16; j++) { x[j] = a[ulong(gid) * 16UL + j]; }
    #pragma unroll
    for (uint s = 0; s < 11; s++) {
        uint h = 1u << (s & 3u);
        #pragma unroll
        for (uint j = 0; j < 16; j++) {
            if ((j & h) == 0u) {
                ulong t = fmul<V>(x[j + h], hw[(s * 16u + j) & 1023u]);
                x[j + h] = fsub<V>(x[j], t);
                x[j] = fadd<V>(x[j], t);
            }
        }
    }
    #pragma unroll
    for (uint j = 0; j < 16; j++) { a[ulong(gid) * 16UL + j] = x[j]; }
}
template [[host_name("k_a28_falu0")]] kernel void k_a28_falu<0>(device ulong *a [[buffer(0)]], device const ulong *hw [[buffer(1)]], uint gid [[thread_position_in_grid]]);
template [[host_name("k_a28_falu1")]] kernel void k_a28_falu<1>(device ulong *a [[buffer(0)]], device const ulong *hw [[buffer(1)]], uint gid [[thread_position_in_grid]]);
template [[host_name("k_a28_falu2")]] kernel void k_a28_falu<2>(device ulong *a [[buffer(0)]], device const ulong *hw [[buffer(1)]], uint gid [[thread_position_in_grid]]);

// every variant's add, sub and product against the tree's on the pairs (x[i], y[i]); out[i] = a bit per mismatch
kernel void k_a28_fcheck(device const ulong *xs [[buffer(0)]],
                         device const ulong *ys [[buffer(1)]],
                         device uint *out [[buffer(2)]],
                         uint gid [[thread_position_in_grid]]) {
    ulong a = xs[gid], b = ys[gid];
    uint m = 0u;
    ulong s0 = gl_add(a, b), d0 = gl_sub(a, b), p0 = gl_mul(a, b);
    if (a28_add_b(a, b) != s0) { m |= 1u; }
    if (a28_add_c(a, b) != s0) { m |= 2u; }
    if (a28_sub_c(a, b) != d0) { m |= 4u; }
    if (a28_mul_b(a, b) != p0) { m |= 8u; }
    if (a28_mul_c(a, b) != p0) { m |= 16u; }
    // the reductions on every 128-bit input (a, b as lo, hi), canonical or not
    if (a28_reduce_b(a, b) != gl_reduce128(a, b)) { m |= 32u; }
    out[gid] = m;
}
