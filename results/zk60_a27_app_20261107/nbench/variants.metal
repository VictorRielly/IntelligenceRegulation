// A27 NTT bench variants (appended to metal_kernels.metal): the head with two stages per barrier
// (radix-4 in registers: the same two radix-2 butterflies per element pair, so the same words).
inline ulong a27_tw(uint s, uint k, ulong x, constant HeadArgs &args, device const ulong *hw, device const uint *hx, device const ulong *tw) {
    if (s <= args.pow2) { return gl_mul_pow2(x, hx[k << (6u - s)]); }
    ulong w = args.use_hw != 0u ? hw[ulong(k) << (TILE_LOG - s)] : tw[ulong(k) * (1UL << (args.max_log - s))];
    return gl_mul(x, w);
}

kernel void k_ntt_head_r4(device const ulong *src [[buffer(0)]],
                          device const ulong *pads [[buffer(1)]],
                          device const ulong *pows [[buffer(2)]],
                          device ulong *dst [[buffer(3)]],
                          device const ulong *tw [[buffer(4)]],
                          constant HeadArgs &args [[buffer(5)]],
                          device const ulong *hw [[buffer(6)]],
                          device const uint *hx [[buffer(7)]],
                          uint2 tid2 [[thread_position_in_threadgroup]],
                          uint2 nth2 [[threads_per_threadgroup]],
                          uint2 tg [[threadgroup_position_in_grid]]) {
    uint tid = tid2.x;
    uint nth = nth2.x;
    threadgroup ulong sh[TILE];
    uint L = min(args.log_n, TILE_LOG);
    uint tile = 1u << L;
    ulong r = ulong(tg.y);
    ulong base = ulong(tg.x) << L;
    for (uint k = tid; k < tile; k += nth) {
        ulong g = base + ulong(k);
        sh[k] = head_input(args.mode, src, pads, pows, r, rev_bits(g, args.log_n), args.log_n, args.log_src, args.q);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint s = 1;
    for (; s + 1 <= L; s += 2) {
        uint h = 1u << (s - 1);
        for (uint b = tid; b < (tile >> 2); b += nth) {
            uint grp = b >> (s - 1);
            uint k = b & (h - 1);
            uint i0 = (grp << (s + 1)) + k;
            ulong a = sh[i0], bb = sh[i0 + h], c = sh[i0 + 2u * h], d = sh[i0 + 3u * h];
            ulong t1 = a27_tw(s, k, bb, args, hw, hx, tw);
            ulong a1 = gl_add(a, t1), b1 = gl_sub(a, t1);
            ulong t2 = a27_tw(s, k, d, args, hw, hx, tw);
            ulong c1 = gl_add(c, t2), d1 = gl_sub(c, t2);
            ulong t3 = a27_tw(s + 1u, k, c1, args, hw, hx, tw);
            ulong t4 = a27_tw(s + 1u, k + h, d1, args, hw, hx, tw);
            sh[i0] = gl_add(a1, t3);
            sh[i0 + 2u * h] = gl_sub(a1, t3);
            sh[i0 + h] = gl_add(b1, t4);
            sh[i0 + 3u * h] = gl_sub(b1, t4);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (s == L) {
        uint h = 1u << (s - 1);
        for (uint b = tid; b < (tile >> 1); b += nth) {
            uint grp = b >> (s - 1);
            uint k = b & (h - 1);
            uint i0 = (grp << s) + k;
            ulong u = sh[i0];
            ulong v = a27_tw(s, k, sh[i0 + h], args, hw, hx, tw);
            sh[i0] = gl_add(u, v);
            sh[i0 + h] = gl_sub(u, v);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    device ulong *row = dst + (r << args.log_n) + base;
    for (uint k = tid; k < tile; k += nth) {
        ulong x = sh[k];
        row[k] = args.apply_scale != 0u ? gl_mul(x, args.scale) : x;
    }
}

// the head's loads and stores only (no stage): a floor for the head's memory traffic
kernel void k_ntt_head_floor(device const ulong *src [[buffer(0)]],
                             device const ulong *pads [[buffer(1)]],
                             device const ulong *pows [[buffer(2)]],
                             device ulong *dst [[buffer(3)]],
                             device const ulong *tw [[buffer(4)]],
                             constant HeadArgs &args [[buffer(5)]],
                             device const ulong *hw [[buffer(6)]],
                             device const uint *hx [[buffer(7)]],
                             uint2 tid2 [[thread_position_in_threadgroup]],
                             uint2 nth2 [[threads_per_threadgroup]],
                             uint2 tg [[threadgroup_position_in_grid]]) {
    uint tid = tid2.x;
    uint nth = nth2.x;
    threadgroup ulong sh[TILE];
    uint L = min(args.log_n, TILE_LOG);
    uint tile = 1u << L;
    ulong r = ulong(tg.y);
    ulong base = ulong(tg.x) << L;
    for (uint k = tid; k < tile; k += nth) {
        ulong g = base + ulong(k);
        sh[k] = head_input(args.mode, src, pads, pows, r, rev_bits(g, args.log_n), args.log_n, args.log_src, args.q);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    device ulong *row = dst + (r << args.log_n) + base;
    for (uint k = tid; k < tile; k += nth) {
        row[k] = sh[tile - 1u - k];
    }
}

// the tail with two stages per barrier (radix-4 in registers): the same butterflies, so the same words
kernel void k_ntt_tail_r4(device ulong *a [[buffer(0)]],
                          device const ulong *tw [[buffer(1)]],
                          constant TailArgs &args [[buffer(2)]],
                          uint2 tid2 [[thread_position_in_threadgroup]],
                          uint2 nth2 [[threads_per_threadgroup]],
                          uint2 tg [[threadgroup_position_in_grid]]) {
    uint tid = tid2.x;
    uint nth = nth2.x;
    threadgroup ulong sh[TILE];
    uint G = args.log_n - TILE_LOG;
    uint C = TILE >> G;
    ulong low0 = ulong(tg.x) * ulong(C);
    device ulong *row = a + (ulong(tg.y) << args.log_n);
    for (uint t = tid; t < TILE; t += nth) {
        uint c = t % C;
        uint h = t / C;
        sh[h * C + c] = row[low0 + ulong(c) + (ulong(h) << TILE_LOG)];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint s = TILE_LOG + 1;
    for (; s + 1 <= args.log_n; s += 2) {
        uint hs = s - TILE_LOG - 1;
        uint H = 1u << hs;
        ulong st0 = 1UL << (args.max_log - s);
        ulong st1 = 1UL << (args.max_log - s - 1);
        for (uint b = tid; b < (TILE >> 2); b += nth) {
            uint c = b % C;
            uint hb = b / C;
            uint grp = hb >> hs;
            uint kh = hb & (H - 1);
            uint h0 = (grp << (hs + 2)) + kh;
            ulong kk = low0 + ulong(c) + (ulong(kh) << TILE_LOG);
            ulong w0 = tw[kk * st0];
            ulong w1 = tw[kk * st1];
            ulong w2 = tw[(kk + (ulong(H) << TILE_LOG)) * st1];
            ulong x0 = sh[h0 * C + c], x1 = sh[(h0 + H) * C + c], x2 = sh[(h0 + 2u * H) * C + c], x3 = sh[(h0 + 3u * H) * C + c];
            ulong t = gl_mul(x1, w0);
            ulong y0 = gl_add(x0, t), y1 = gl_sub(x0, t);
            t = gl_mul(x3, w0);
            ulong y2 = gl_add(x2, t), y3 = gl_sub(x2, t);
            t = gl_mul(y2, w1);
            sh[h0 * C + c] = gl_add(y0, t);
            sh[(h0 + 2u * H) * C + c] = gl_sub(y0, t);
            t = gl_mul(y3, w2);
            sh[(h0 + H) * C + c] = gl_add(y1, t);
            sh[(h0 + 3u * H) * C + c] = gl_sub(y1, t);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (s == args.log_n) {
        uint hs = s - TILE_LOG - 1;
        uint half_h = 1u << hs;
        ulong stride = 1UL << (args.max_log - s);
        for (uint b = tid; b < (TILE >> 1); b += nth) {
            uint c = b % C;
            uint hb = b / C;
            uint grp = hb >> hs;
            uint kh = hb & (half_h - 1);
            uint h0 = (grp << (hs + 1)) + kh;
            uint h1 = h0 + half_h;
            ulong k = low0 + ulong(c) + (ulong(kh) << TILE_LOG);
            ulong w = tw[k * stride];
            ulong u = sh[h0 * C + c];
            ulong v = gl_mul(sh[h1 * C + c], w);
            sh[h0 * C + c] = gl_add(u, v);
            sh[h1 * C + c] = gl_sub(u, v);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    for (uint t = tid; t < TILE; t += nth) {
        uint c = t % C;
        uint h = t / C;
        ulong x = sh[h * C + c];
        row[low0 + ulong(c) + (ulong(h) << TILE_LOG)] = args.apply_scale != 0u ? gl_mul(x, args.scale) : x;
    }
}
