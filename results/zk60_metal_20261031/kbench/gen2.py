# [M4g probe] variants of a dumped slot library's later-round kernel:
#   k_vE  the prover's M4e form (one thread per (pair, point), point = tid % (D+1))
#   k_vL  the same loads and line values, body replaced by the sum of the values (a floor)
#   k_vG  one POINT per SIMD group of 32 lanes (no divergence), point 1 not launched when
#         eval_one == 0 (its groups exit at once)
#   k_vH  G + the line value's step times d as a small-integer product (two 32-bit products)
import re, sys
src = open(sys.argv[1]).read()
out = sys.argv[2]
k = int(re.search(r'#define SC_K (\d+)', src).group(1))
dmax = int(re.search(r'#define SC_D (\d+)', src).group(1))
kern = src[src.index('kernel void k_sc_round('):]
lines = kern.splitlines()
if any('if (d == 1u && a.eval_one == 0u) { continue; }' in l for l in lines):
    b0 = next(i for i, l in enumerate(lines) if 'if (d == 1u && a.eval_one == 0u) { continue; }' in l) + 1
    b1 = next(i for i, l in enumerate(lines) if 'acc[d] = f2_add(acc[d], out);' in l)
else:
    # an M4e-generated library: the body follows the last line-value load
    b0 = max(i for i, l in enumerate(lines) if ' = ln_ext(' in l or ' = ln_base(' in l) + 1
    b1 = next(i for i, l in enumerate(lines) if 'acc = f2_add(acc, out);' in l)
body = lines[b0:b1]
helpers = '''
inline fp2 kb_ln_ext(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    fp2 l = f2(tabs[lo], tabs[lo + 1]);
    if (d == 0u) { return l; }
    fp2 h = f2(tabs[hi], tabs[hi + 1]);
    if (d == 1u) { return h; }
    return f2_add(l, f2_mulb(f2_sub(h, l), dd));
}
// a * s for s < 2^32: the canonical product from two 32-bit partial products
inline ulong gl_mul_small(ulong a, ulong s) {
    ulong p0 = (a & 0xFFFFFFFFUL) * s;
    ulong p1 = (a >> 32) * s;
    ulong lo = p0 + (p1 << 32);
    ulong hi = (p1 >> 32) + (lo < p0 ? 1UL : 0UL);
    return gl_reduce128(lo, hi);
}
inline fp2 kb_ln_small(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    fp2 l = f2(tabs[lo], tabs[lo + 1]);
    if (d == 0u) { return l; }
    fp2 h = f2(tabs[hi], tabs[hi + 1]);
    if (d == 1u) { return h; }
    fp2 w = f2_sub(h, l);
    return f2_add(l, f2(gl_mul_small(w.c0, dd), gl_mul_small(w.c1, dd)));
}
'''
def loads(fn):
    return '\n'.join(f'            fp2 v{t} = {fn}(tabs, ({t}UL * a.cap + i) * 2UL, ({t}UL * a.cap + i + a.nhalf) * 2UL, d, dd);' for t in range(k))
head = lambda name: f'''kernel void {name}(device const ulong *tabs [[buffer(0)]],
                       device ulong *part [[buffer(1)]],
                       constant ulong *cf [[buffer(2)]],
                       constant RoundArgs &a [[buffer(3)]],
                       uint tid [[thread_position_in_grid]]) {{
'''
idxE = '''    uint d = tid % (SC_D + 1u);
    uint gid = tid / (SC_D + 1u);
    if (gid >= a.nthreads) { return; }
'''
# G: groups of 32 lanes share one point; np points launched (D + 1, or D without point 1)
idxG = '''    uint np = a.eval_one != 0u ? SC_D + 1u : SC_D;
    uint grp = tid >> 5;
    uint di = grp % np;
    uint d = (a.eval_one != 0u || di == 0u) ? di : di + 1u;
    uint gid = (grp / np) * 32u + (tid & 31u);
    if (gid >= a.nthreads) { return; }
'''
loop = '''    ulong dd = ulong(d);
    fp2 acc = f2(0UL, 0UL);
    if (d != 1u || a.eval_one != 0u) {
        for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {
'''
tail = '''            acc = f2_add(acc, out);
        }
    }
    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
    part[o] = acc.c0;
    part[o + 1] = acc.c1;
}
'''
floor_body = '            fp2 out = v0;\n' + '\n'.join(f'            out = f2_add(out, v{t});' for t in range(1, k)) + '\n'
vE = head('k_vE') + idxE + loop + loads('kb_ln_ext') + '\n' + '\n'.join(body) + '\n' + tail
vL = head('k_vL') + idxE + loop + loads('kb_ln_ext') + '\n' + floor_body + tail
vG = head('k_vG') + idxG + loop + loads('kb_ln_ext') + '\n' + '\n'.join(body) + '\n' + tail
vH = head('k_vH') + idxG + loop + loads('kb_ln_small') + '\n' + '\n'.join(body) + '\n' + tail
vLG = head('k_vLG') + idxG + loop + loads('kb_ln_small') + '\n' + floor_body + tail
open(out, 'w').write(src + helpers + vE + vL + vG + vH + vLG)
print('k', k, 'D', dmax, 'body lines', len(body))
