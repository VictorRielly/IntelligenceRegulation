#!/usr/bin/env python3
"""K0: build k0.metal. The field helpers, a27_fold_pair and k_fold_tables_dev3 are copied VERBATIM (text slices)
from the prover's metal_kernels.metal (read only). Two copy kernels of ours are appended.
usage: mk_k0_src.py <metal_kernels.metal> <out k0.metal>
"""
import sys

s = open(sys.argv[1]).read()
out = sys.argv[2]


def between(a, b):
    i = s.index(a)
    j = s.index(b, i)
    return s[i:j]


field = between('#include <metal_stdlib>', 'inline ulong rev_bits(')
a27 = between('inline ulong a27_mul7(', 'kernel void k_fold_tables3(')
struct = between('struct FoldDevArgs {', '\n') + '\n'
i = s.index('kernel void k_fold_tables_dev3(')
j = s.index('\n}\n', i) + 3
fold = s[i:j]

ours = '''
// ---- ours (not in the prover) -------------------------------------------------------------------------
// copy A (k_copy_pat): the fold's thread mapping, loads, and in-place store, with the arithmetic replaced by xor.
// Moves the same bytes the same way: two 16 B element reads (lo, hi) and one 16 B write (lo) per (pair, table).
kernel void k_copy_pat(device ulong *tabs [[buffer(0)]],
                       constant FoldDevArgs &args [[buffer(1)]],
                       device const ulong *rbuf [[buffer(2)]],
                       uint2 gid [[thread_position_in_grid]]) {
    ulong i = ulong(gid.x);
    ulong t = ulong(gid.y);
    if (i >= args.nhalf || t >= args.k) { return; }
    ulong lo_i = (t * args.cap + i) * 2UL;
    ulong hi_i = (t * args.cap + i + args.nhalf) * 2UL;
    ulong l0 = tabs[lo_i], l1 = tabs[lo_i + 1];
    ulong h0 = tabs[hi_i], h1 = tabs[hi_i + 1];
    tabs[lo_i] = l0 ^ h0;
    tabs[lo_i + 1] = l1 ^ h1;
}

// copy B (k_copy_vec): a plain streaming copy with 16-byte vector accesses, source and destination separate
// buffers. Per (pair, table): read lo and hi (32 B, contiguous per table so coalesced across i), write 16 B.
// Same bytes as the fold: k * nhalf * 32 read, k * nhalf * 16 written.
kernel void k_copy_vec(device const ulong2 *src [[buffer(0)]],
                       device ulong2 *dst [[buffer(1)]],
                       constant FoldDevArgs &args [[buffer(2)]],
                       uint2 gid [[thread_position_in_grid]]) {
    ulong i = ulong(gid.x);
    ulong t = ulong(gid.y);
    if (i >= args.nhalf || t >= args.k) { return; }
    ulong lo_e = t * args.cap + i;
    ulong2 l = src[lo_e];
    ulong2 h = src[lo_e + args.nhalf];
    dst[t * args.nhalf + i] = l ^ h;
}
'''
open(out, 'w').write('// K0 bench source. Verbatim from metal_kernels.metal: field helpers, a27_mul7/a27_fold_pair, FoldDevArgs, k_fold_tables_dev3.\n'
                      + field + '\n' + a27 + '\n' + struct + '\n' + fold + ours)
print('wrote', out, len(field), len(a27), len(struct), len(fold))
