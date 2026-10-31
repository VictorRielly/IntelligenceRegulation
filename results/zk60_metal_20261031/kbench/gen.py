# variants of a dumped slot library's k_sc_round (the extension-round kernel)
import re, sys
src = open(sys.argv[1]).read()
out = sys.argv[2]
k = int(re.search(r'#define SC_K (\d+)', src).group(1))
kern = src[src.index('kernel void k_sc_round('):]
lines = kern.splitlines()
b0 = next(i for i, l in enumerate(lines) if 'if (d == 1u && a.eval_one == 0u) { continue; }' in l)
b1 = next(i for i, l in enumerate(lines) if 'acc[d] = f2_add(acc[d], out);' in l)
body = lines[b0 + 1:b1]
def lazy(body):
    seen, res = set(), []
    for l in body:
        for t in sorted(set(int(x) for x in re.findall(r'\bv(\d+)\b', l))):
            if t not in seen:
                seen.add(t)
                res.append(f'            fp2 v{t} = ln_ext(tabs, ({t}UL * a.cap + i) * 2UL, ({t}UL * a.cap + i + a.nhalf) * 2UL, d, dd);')
        res.append(l)
    return '\n'.join(res)
helper = '''
inline fp2 ln_ext(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    fp2 l = f2(tabs[lo], tabs[lo + 1]);
    if (d == 0u) { return l; }
    fp2 h = f2(tabs[hi], tabs[hi + 1]);
    if (d == 1u) { return h; }
    return f2_add(l, f2_mulb(f2_sub(h, l), dd));
}
'''
sig = lambda name: f'''kernel void {name}(device const ulong *tabs [[buffer(0)]],
                       device ulong *part [[buffer(1)]],
                       constant ulong *cf [[buffer(2)]],
                       constant RoundArgs &a [[buffer(3)]],
                       uint gid [[thread_position_in_grid]]) {{
    if (gid >= a.nthreads) {{ return; }}
'''
tail = '''    for (uint d = 0; d <= SC_D; d++) {
        ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
        part[o] = acc[d].c0;
        part[o + 1] = acc[d].c1;
    }
}
'''
lb = lazy(body)
# B: pair outer, d inner, lazy line values
vB = sig('k_vB') + '''    fp2 acc[SC_D + 1];
    for (uint d = 0; d <= SC_D; d++) { acc[d] = f2(0UL, 0UL); }
    for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {
        for (uint d = 0; d <= SC_D; d++) {
            if (d == 1u && a.eval_one == 0u) { continue; }
            ulong dd = ulong(d);
''' + lb + '''
            acc[d] = f2_add(acc[d], out);
        }
    }
''' + tail
# C: d outer, pair inner, lazy line values, one running sum
vC = sig('k_vC') + '''    fp2 acc[SC_D + 1];
    for (uint d = 0; d <= SC_D; d++) {
        fp2 s = f2(0UL, 0UL);
        if (d != 1u || a.eval_one != 0u) {
            ulong dd = ulong(d);
            for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {
''' + lb + '''
                s = f2_add(s, out);
            }
        }
        acc[d] = s;
    }
''' + tail
# D: like C but the d loop fully unrolled into straight code (no dynamic acc index)
dmax = int(re.search(r'#define SC_D (\d+)', src).group(1))
vD = sig('k_vD') + '    fp2 acc[SC_D + 1];\n'
for d in range(dmax + 1):
    vD += f'''    {{
        const uint d = {d}u; ulong dd = {d}UL; fp2 s = f2(0UL, 0UL);
        if (d != 1u || a.eval_one != 0u) {{
            for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {{
{lb}
                s = f2_add(s, out);
            }}
        }}
        acc[{d}] = s;
    }}
'''
vD += tail
open(out, 'w').write(src + helper + vB + vC + vD)
print('k', k, 'D', dmax, 'body lines', len(body))

# E: one thread per (pair stride, point d): tid = g * (D + 1) + d; eager line values
pro = []
for t in range(k):
    pro.append(f'            fp2 v{t} = ln_ext(tabs, ({t}UL * a.cap + i) * 2UL, ({t}UL * a.cap + i + a.nhalf) * 2UL, d, dd);')
sigE = lambda name: f'''kernel void {name}(device const ulong *tabs [[buffer(0)]],
                       device ulong *part [[buffer(1)]],
                       constant ulong *cf [[buffer(2)]],
                       constant RoundArgs &a [[buffer(3)]],
                       uint tid [[thread_position_in_grid]]) {{
    uint d = tid % (SC_D + 1u);
    uint gid = tid / (SC_D + 1u);
    if (gid >= a.nthreads) {{ return; }}
    ulong dd = ulong(d);
    fp2 s = f2(0UL, 0UL);
    if (d != 1u || a.eval_one != 0u) {{
        for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {{
'''
tailE = '''            s = f2_add(s, out);
        }
    }
    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
    part[o] = s.c0;
    part[o + 1] = s.c1;
}
'''
vE = sigE('k_vE') + '\n'.join(pro) + '\n' + '\n'.join(body) + '\n' + tailE
vF = sigE('k_vF') + lb + '\n' + tailE
open(out, 'a').write(vE + vF)
print('E/F added')
