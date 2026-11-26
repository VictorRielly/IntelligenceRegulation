"""Coordinator's second, independent count for Astra's A31 handoff (2026-11-26).
Usage: python3 -I a31_second.py ARCHIVE.zip PUBLISHER_SHA1_FILE OUT.json
Reads the all-platform daily light archive of the EU DSA transparency database (a ZIP of ZIPs of CSV files) as data:
nothing is unpacked to disk, nothing executed. Differs from the handoff's program in method: the file's SHA-1 is
compared with the publisher's checksum file fetched separately; inner archives are read in memory; statements are
counted by the RAW value of the content_type field (so every combination of media types is shown, not only the four
the handoff tests for); the description field content_type_other is only counted, never written out.
No filer name and no free-text description is printed or written."""
import collections
import csv
import hashlib
import io
import json
import re
import sys
import zipfile

arc, shaf, outp = sys.argv[1], sys.argv[2], sys.argv[3]
csv.field_size_limit(1 << 30)
h = hashlib.sha1()
with open(arc, 'rb') as f:
    while True:
        b = f.read(1 << 24)
        if not b:
            break
        h.update(b)
pub = re.findall(r'\b[0-9a-f]{40}\b', open(shaf, encoding='utf-8', errors='replace').read())
assert len(pub) == 1 and pub[0] == h.hexdigest(), (pub, h.hexdigest())

GROUPS = {
    'posts': ('post', 'posts', 'social media post', 'social media posts'),
    'comments': ('comment', 'comments'),
    'messages': ('message', 'messages', 'direct message', 'direct messages', 'private message', 'private messages'),
    'reviews': ('review', 'reviews', 'product review', 'product reviews'),
    'listing descriptions': ('listing description', 'listing descriptions', 'product description', 'product descriptions'),
}
EXACT = {t: g for g, ts in GROUPS.items() for t in ts}
WORD = {g: re.compile(r'(?<![a-z])(?:' + '|'.join(re.escape(x) for x in ts) + r')(?![a-z])') for g, ts in GROUPS.items()}

by_type = collections.Counter()          # raw content_type value -> statements
desc_by_type = collections.Counter()     # raw content_type value -> statements with a non-empty description
exact = collections.Counter()            # (group, text-tagged) -> statements whose description equals a term
mention = collections.Counter()          # group -> text-tagged statements whose description contains a term
distinct_text_desc = set()
rows = n_inner = n_csv = 0
header = None
with zipfile.ZipFile(arc) as outer:
    for name in outer.namelist():
        n_inner += 1
        inner = zipfile.ZipFile(io.BytesIO(outer.read(name)))
        for part in inner.namelist():
            n_csv += 1
            with inner.open(part) as raw:
                rd = csv.reader(io.TextIOWrapper(raw, encoding='utf-8-sig', newline=''))
                fields = next(rd)
                if header is None:
                    header = fields
                assert fields == header
                t, o = fields.index('content_type'), fields.index('content_type_other')
                for row in rd:
                    rows += 1
                    ct = row[t]
                    by_type[ct] += 1
                    d = row[o].strip().casefold()
                    if d:
                        desc_by_type[ct] += 1
                        is_text = '\x22CONTENT_TYPE_TEXT\x22' in ct
                        g = EXACT.get(d)
                        if g:
                            exact[(g, is_text)] += 1
                        if is_text:
                            distinct_text_desc.add(d)
                            for g2, pat in WORD.items():
                                if pat.search(d):
                                    mention[g2] += 1
types = []
for ct, n in sorted(by_type.items(), key=lambda kv: -kv[1]):
    v = json.loads(ct)
    assert isinstance(v, list) and all(isinstance(x, str) for x in v)
    types.append({'content_type': sorted(v), 'raw_forms': 1, 'statements': n, 'with_description': desc_by_type.get(ct, 0)})
# merge raw forms that are the same set in another order
merged = {}
for e in types:
    k = tuple(e['content_type'])
    if k in merged:
        merged[k]['raw_forms'] += 1
        merged[k]['statements'] += e['statements']
        merged[k]['with_description'] += e['with_description']
    else:
        merged[k] = e
out = {
    'sha1': h.hexdigest(), 'inner_archives': n_inner, 'csv_files': n_csv, 'rows': rows,
    'by_content_type_set': sorted(merged.values(), key=lambda e: -e['statements']),
    'exact_description_matches': {g: [exact[(g, True)], exact[(g, False)]] for g in GROUPS},
    'text_tagged_description_mentions': {g: mention[g] for g in GROUPS},
    'distinct_descriptions_among_text_tagged': len(distinct_text_desc),
}
json.dump(out, open(outp, 'w'), indent=1)
print('rows', rows, '| content-type sets', len(merged), '| raw forms', len(by_type))
