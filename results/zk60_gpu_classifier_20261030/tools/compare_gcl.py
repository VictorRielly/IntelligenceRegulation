#!/usr/bin/env python3
"""GPU classifier lane (D53): byte identity of ONE job-0 receipt (fixed public entropy job0.bin) against round 18's
recorded digests (r18/logs/eq/digests.json, tree 'single-c0' = 'batch-c0' = 'r16b-c0'; r19b re-confirmed them).
The 30 files: 28 receipt segments, the unverified statement.json, the owner's input.dec.
usage: compare_gcl.py RUN_DIR OWNER_DIR OUT.json [LABEL]"""
import hashlib, json, os, sys
RUN, OWN, OUT = sys.argv[1:4]
LABEL = sys.argv[4] if len(sys.argv) > 4 else ''
R18 = '/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/logs/eq/digests.json'
def tree(d):
    out = {}
    for root, _, files in os.walk(d):
        for f in files:
            p, h = os.path.join(root, f), hashlib.sha256()
            with open(p, 'rb') as fh:
                for b in iter(lambda: fh.read(1 << 20), b''): h.update(b)
            out[os.path.relpath(p, d)] = h.hexdigest()
    return out
mine = {'receipt': tree(RUN), 'statement': tree(RUN + '.unverified-statement'), 'owner': tree(OWN)}
ref = json.load(open(R18))['trees']
rows = {k: mine == ref[k] for k in ('single-c0', 'batch-c0', 'r16b-c0')}
diff = sorted(f'{g}/{f}' for g in ('receipt', 'statement', 'owner') for f in set(mine[g]) | set(ref['single-c0'][g]) if mine[g].get(f) != ref['single-c0'][g].get(f))
files = sum(map(len, mine.values()))
size = sum(os.path.getsize(os.path.join(RUN, f)) for f in mine['receipt'])
ok = all(rows.values()) and files == 30 and len(mine['receipt']) == 28
json.dump({'label': LABEL, 'note': 'SHA-256 of a test-only receipt made with FIXED PUBLIC entropy (it hides nothing); deleted after this comparison',
           'ok': ok, 'files': files, 'receipt_bytes': size, 'equals_round_18': rows, 'differing_files': diff, 'tree': mine}, open(OUT, 'w'), indent=1, sort_keys=True)
print(json.dumps({'label': LABEL, 'ok': ok, 'files': files, 'receipt_bytes': size, 'equals_round_18': rows, 'differing_files': diff[:10]}))
sys.exit(0 if ok else 1)
