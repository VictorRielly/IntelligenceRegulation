"""Applications item A27: which hash and size records the project already keeps for one classifier receipt, counted
against the fields of a hashed external reference (C2PA 2.5, section 9.4.2.2: url, alg, hash, optional size).

Reads four record files of one qualification run of the app (another agent's records, on the project's machine only,
not in the public tree on 2026-11-26) and, when a store directory is given, stream-hashes the receipt's files there.
Writes nothing, builds nothing, runs no prover and no app code. Output carries no clock reading.

Usage: python3 20261126-apps-receipt-reference-records.py [RUNS_DIR_OF_THE_PUBLIC_STORE]
"""
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
QREL = 'results/zk60_astra_20261026/app_composed_native_20261122/qualification-20261125T070919.014403Z/'
Q = os.path.join(REPO, QREL)
RUNS = sys.argv[1] if len(sys.argv) > 1 else None
HEX64 = re.compile(r'^[0-9a-f]{64}$')


def sha_file(p, chunk=1 << 22):
    h = hashlib.sha256()
    n = 0
    with open(p, 'rb') as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
            n += len(b)
    return h.hexdigest(), n


def lines_with(name, pat):
    out = []
    with open(os.path.join(Q, name), encoding='utf-8') as f:
        for i, l in enumerate(f, 1):
            if re.search(pat, l):
                out.append(i)
    return out


if not os.path.isdir(Q):
    print('record directory not present on this machine:', QREL)
    sys.exit(2)

print('records read from', QREL)
man = json.load(open(os.path.join(Q, 'manifest.json'), encoding='utf-8'))
res = json.load(open(os.path.join(Q, 'RESULT.json'), encoding='utf-8'))
dst = json.load(open(os.path.join(Q, 'downloaded_store.json'), encoding='utf-8'))
l_msha = lines_with('manifest.json', r'"manifest_sha256"')
l_ruri = lines_with('manifest.json', r'"receipt_uris"')
l_note = lines_with('manifest.json', r'Public content only; privacy not claimed')
print('manifest.json: entries %d | lines of manifest_sha256 %s | lines of receipt_uris %s | profile note at line %s'
      % (len(man['entries']), l_msha, l_ruri, l_note))
assert len(man['entries']) == len(l_msha) == len(l_ruri) == 3 and len(l_note) == 1
print('manifest.json: signature alg %s | issuer name: %s' % (man['signature']['alg'], man['issuer']['name']))
print('RESULT.json: passed = %s (line %s) | guard_exit = %s (line %s) | public_fixture_only = %s'
      % (res['passed'], lines_with('RESULT.json', r'"passed"'), res['guard_exit'], lines_with('RESULT.json', r'"guard_exit"'),
         res['public_fixture_only']))
print('downloaded_store.json: accepted = %s | publication_matches checks true: %d of %d (lines %s)'
      % (dst['accepted'], sum(1 for k, v in dst['checks'].items() if k.endswith('publication_matches') and v is True),
         sum(1 for k in dst['checks'] if k.endswith('publication_matches')), lines_with('downloaded_store.json', r'publication_matches')))
print()

tot_seg = 0
tot_bytes = 0
first = None
for e in man['entries']:
    cat, chunk = e['category'], e['chunk']
    name = cat + '.publication.json'
    p = os.path.join(Q, name)
    raw = open(p, 'rb').read()
    inv = json.loads(raw)
    dig = hashlib.sha256(raw).hexdigest()
    segs = inv['segments']
    keys = sorted(set(tuple(sorted(s.keys())) for s in segs))
    n_hash = sum(1 for s in segs if isinstance(s.get('sha256'), str) and HEX64.match(s['sha256']))
    n_len = sum(1 for s in segs if isinstance(s.get('bytes'), int) and s['bytes'] > 0)
    names_ok = [s['file'] for s in segs] == ['segment-%03d.bin' % i for i in range(len(segs))]
    total = sum(s['bytes'] for s in segs)
    sizes = sorted(s['bytes'] for s in segs)
    n_http = raw.count(b'http')
    print('== %s (chunk %d): %s' % (cat, chunk, name))
    print('   inventory file: %d bytes, %d newline characters (one line: every field is at line 1), sha256 %s' % (len(raw), raw.count(b'\n'), dig))
    print('   signed manifest entry bundle.manifest_sha256 equals the sha256 of this file: %s | bundle.receipt_uris = %d'
          % (e['bundle']['manifest_sha256'] == dig, e['bundle']['receipt_uris']))
    print('   bundle keys in the signed manifest: %s' % sorted(e['bundle'].keys()))
    print('   segments: %d | key sets: %s | names segment-000.. in order: %s' % (len(segs), keys, names_ok))
    print('   with a 64-hex sha256: %d of %d | with a positive integer byte length: %d of %d' % (n_hash, len(segs), n_len, len(segs)))
    print('   sum of byte lengths: %d | smallest %d | largest %d | distinct hashes %d'
          % (total, sizes[0], sizes[-1], len(set(s['sha256'] for s in segs))))
    print('   segments_json_sha256 = %r | statement_sha256 is 64-hex: %s | statement_uri scheme: %s | occurrences of "http" in the file: %d'
          % (inv['segments_json_sha256'], bool(HEX64.match(inv['statement_sha256'])), inv['statement_uri'].split(':')[0], n_http))
    print('   verdict field: %s | schema: %s' % (inv['verdict'], inv['schema']))
    assert e['bundle']['receipt_uris'] == len(segs)
    if RUNS:
        d = os.path.join(RUNS, '%s-c%d' % (inv['post_id'], chunk))
        present = same_len = same_hash = 0
        nbytes = 0
        for s in segs:
            f = os.path.join(d, s['file'])
            if not os.path.isfile(f):
                continue
            present += 1
            h, n = sha_file(f)
            nbytes += n
            same_len += (n == s['bytes'])
            same_hash += (h == s['sha256'])
        extra = len([x for x in os.listdir(d) if x.startswith('segment-')]) - present if os.path.isdir(d) else 0
        print('   files in the store directory <runs>/<post id>-c%d: present %d of %d | length equal %d | sha256 equal %d | bytes read %d | other segment files %d'
              % (chunk, present, len(segs), same_len, same_hash, nbytes, extra))
    tot_seg += len(segs)
    tot_bytes += total
    if first is None:
        first = (cat, len(segs), total, len(raw), dig, sizes)
    print()

cat, n, total, inv_len, dig, sizes = first
print('== one classifier receipt (%s) against the fields of a hashed external reference' % cat)
print('   route A, one reference per file: references needed %d | hash on record %d | length on record %d | http(s) URL on record 0' % (n, n, n))
print('   route B, one reference to one archive of the %d files: digest of the archive on record 0 | length of the archive on record 0' % n)
print('     (the files\x27 lengths sum to %d bytes [DERIVED]; an archive format adds its own framing, so neither value follows from the records)' % total)
print('   route C, one reference to the inventory file: digest on record 1 (in the signed manifest, equal to the file\x27s sha256) | length on record 0')
print('     (the file is %d bytes [COUNTED here]; it lists the %d hashes and lengths) | http(s) URL on record 0' % (inv_len, n))
print('   inventory bytes per receipt byte: %d / %d = 1 / %d [DERIVED]' % (inv_len, total, round(total / inv_len)))
print('== the whole item of this run: categories %d | files %d | bytes %d' % (len(man['entries']), tot_seg, tot_bytes))
