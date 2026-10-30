#!/usr/bin/env python3
"""Token round 19, the receipt-bytes check: round 19's single prove of job 0 (moderate sexual, Astra's public 17-id
sentence, FIXED PUBLIC entropy job0.bin = round 18's) against round 18's recorded digests of the same job
(r18/logs/eq/digests.json: single-c0 = batch-c0 = r16b-c0). Same 30 files as round 18's compare.py: 28 receipt
segments, the unverified statement.json, the owner's input.dec.

usage: compare19.py EQ19 OWN19 R18_DIGESTS OUT.json
"""
import hashlib, json, os, sys
EQ, OWN, R18, OUT = sys.argv[1:5]
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
mine = triple(f'{EQ}/single/c0', f'{OWN}/single-owner/c0')
r18 = json.load(open(R18))['trees']
rows = {k: mine == r18[k] for k in ('single-c0', 'batch-c0', 'r16b-c0')}
files = sum(map(len, mine.values()))
ok = all(rows.values()) and files == 30 and len(mine['receipt']) == 28
json.dump({'note': 'SHA-256 of a test-only receipt made with FIXED PUBLIC entropy (it hides nothing); deleted after this comparison',
           'ok': ok, 'files': files, 'equals_round_18': rows, 'tree': mine}, open(OUT, 'w'), indent=1, sort_keys=True)
print(json.dumps({'ok': ok, 'files': files, 'equals_round_18': rows})); sys.exit(0 if ok else 1)
