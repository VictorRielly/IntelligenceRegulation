"""Pass-6 A: recompute every pin of package 385 (read-only, stdout)."""
import json, os, hashlib, sys, collections
R = '/Users/victorrielly/IntelligenceRegulation'
B = R + '/results/zk60_sol_20261105_w16r3/b3'
p = B + '/D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'
d = json.load(open(p))
pins = d['pins']
items = list(pins.items())
print('pins', len(items), 'sample', items[:2])
def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for c in iter(lambda: f.read(1 << 20), b''):
            h.update(c)
    return h.hexdigest()
ok = bad = miss = sym = outside = zero = absolute = 0
big = 0
badl, missl, outl = [], [], []
cats = collections.Counter()
for k, v in items:
    exp = v if isinstance(v, str) else (v.get('sha256') or v.get('hash'))
    path = k if os.path.isabs(k) else os.path.join(B, k)
    real = os.path.realpath(path)
    if os.path.isabs(k): absolute += 1
    if not os.path.exists(path):
        miss += 1; missl.append(k); continue
    if os.path.islink(path): sym += 1
    if not real.startswith(R + '/'):
        outside += 1; outl.append((k, real))
    if os.path.getsize(path) == 0: zero += 1
    got = sha(path)
    if got == exp: ok += 1
    else: bad += 1; badl.append((k, exp, got))
    # category: tree
    rel = os.path.relpath(real, R)
    cats['/'.join(rel.split('/')[:3])] += 1
print('ok', ok, 'bad', bad, 'missing', miss, 'symlinks', sym, 'outside repo', outside, 'zero-byte', zero, 'absolute keys', absolute)
print('bad', badl[:20])
print('missing', missl[:20])
print('outside', outl[:20])
for c, n in cats.most_common(25): print(' ', n, c)
# earlier Claude review files
for k, v in items:
    if 'zk60_claude_review' in k or 'SOL_D78_REVIEW' in k or 'sol_d78_review' in k:
        path = k if os.path.isabs(k) else os.path.join(B, k)
        print('REVIEW PIN', k, 'match' if os.path.exists(path) and sha(path) == (v if isinstance(v, str) else v.get('sha256')) else 'MISMATCH/missing')
