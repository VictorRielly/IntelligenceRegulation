"""A5_PATCH_REVIEW.md section 4.3 step 8 (compare byte for byte; run BEFORE any verify), as written there, plus one
addition (token round 18): `--digests OUT` writes every compared file's SHA-256 to OUT (public digests of test-only
receipts made with fixed public entropy; kept as evidence after the receipts themselves are deleted).

usage: compare.py EQ OWN [--digests OUT.json]
"""
import hashlib, json, os, sys
EQ, OWN = sys.argv[1], sys.argv[2]
def tree(d):
    out = {}
    for root, _, files in os.walk(d):
        for f in files:
            p, h = os.path.join(root, f), hashlib.sha256()
            with open(p, 'rb') as fh:
                for b in iter(lambda: fh.read(1 << 20), b''): h.update(b)
            out[os.path.relpath(p, d)] = h.hexdigest()
    return out
def triple(out, owner):
    return {'receipt': tree(out), 'statement': tree(out + '.unverified-statement'), 'owner': tree(owner)}
rows, ok, dig = [], True, {}
for i in range(3):
    b = triple(f'{EQ}/batch/a5eq-c{i}', f'{OWN}/batch/owners/c{i}')
    s = triple(f'{EQ}/single/c{i}', f'{OWN}/single-owner/c{i}')
    same = b == s and all(b.values())
    rows.append({'job': i, 'batch_equals_single': same, 'files': sum(map(len, b.values()))}); ok &= same
    dig[f'batch-c{i}'], dig[f'single-c{i}'] = b, s
r = triple(f'{EQ}/r16b/c0', f'{OWN}/r16b-owner/c0'); s0 = triple(f'{EQ}/single/c0', f'{OWN}/single-owner/c0')
rows.append({'job': 0, 'r16b_equals_candidate_single': r == s0 and all(r.values())}); ok &= r == s0
dig['r16b-c0'] = r
if '--digests' in sys.argv:
    with open(sys.argv[sys.argv.index('--digests') + 1], 'w') as f:
        json.dump({'note': 'SHA-256 of test-only receipts made with FIXED PUBLIC entropy (they hide nothing); the receipts are deleted after this comparison', 'trees': dig}, f, indent=1, sort_keys=True)
print(json.dumps({'ok': ok, 'rows': rows})); sys.exit(0 if ok else 1)
