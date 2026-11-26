"""Coordinator's second, independent count for Astra's A17 handoff (2026-11-26).
Usage: python3 -I a17_second.py ARCHIVE.zip PUBLISHER_SHA1_FILE OUT.json
Reads the all-platform daily light archive of the EU DSA transparency database (a ZIP of ZIPs of CSV files) as data:
nothing is unpacked to disk, nothing executed. Differs from the handoff's program in method: the file's SHA-1 is
compared with the publisher's checksum file fetched separately; inner archives are read in memory; cells are keyed by
the RAW field values (so the spellings the handoff's program tests for are shown, not assumed); the additional-category
field is split into blank, empty list and non-empty list.
Fixed before the count was run, in addition to the handoff's cells: per filer, the number of statements with automated
detection and how many of those have the primary category OTHER_VIOLATION_TC or NOT_SPECIFIED_NOTICE, reported ONLY by
volume class of the filer's detected statements on the day (1M and more, 100k to 1M, 10k to 100k, 1k to 10k, under 1k):
filers in the class, filers with a catch-all majority, pooled catch-all share. No filer name is printed or written."""
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

cells = collections.Counter()
per = {}
addstate = {}


def add_state(s):
    r = addstate.get(s)
    if r is None:
        if s == '':
            r = 'blank'
        else:
            v = json.loads(s)
            assert isinstance(v, list) and all(isinstance(x, str) and x.strip() for x in v), s[:80]
            r = 'non-empty list' if v else 'empty list'
        addstate[s] = r
    return r


CATCH = ('STATEMENT_CATEGORY_OTHER_VIOLATION_TC', 'STATEMENT_CATEGORY_NOT_SPECIFIED_NOTICE')
n_inner = n_csv = rows = 0
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
                ix = {k: i for i, k in enumerate(fields)}
                d, f_, c, a = ix['automated_detection'], ix['automated_decision'], ix['category'], ix['category_addition']
                pn = ix.get('platform_name')
                for row in rd:
                    rows += 1
                    det, cat = row[d], row[c]
                    cells[(det, row[f_], cat, add_state(row[a]))] += 1
                    if pn is not None and det == 'Yes':
                        t = per.get(row[pn])
                        if t is None:
                            t = per[row[pn]] = [0, 0]
                        t[0] += 1
                        if cat in CATCH:
                            t[1] += 1

classes = [('1M and more', 10 ** 6, None), ('100k to 1M', 10 ** 5, 10 ** 6), ('10k to 100k', 10 ** 4, 10 ** 5),
           ('1k to 10k', 10 ** 3, 10 ** 4), ('under 1k', 1, 10 ** 3)]
byclass = []
for label, lo, hi in classes:
    m = [t for t in per.values() if t[0] >= lo and (hi is None or t[0] < hi)]
    byclass.append({'class': label, 'filers': len(m), 'filers_with_catch_all_majority': sum(1 for t in m if 2 * t[1] > t[0]),
                    'detected': sum(t[0] for t in m), 'catch_all': sum(t[1] for t in m)})
out = {
    'sha1': h.hexdigest(), 'inner_archives': n_inner, 'csv_files': n_csv, 'rows': rows, 'fields': header,
    'has_platform_name': 'platform_name' in (header or []),
    'cells': [[k[0], k[1], k[2], k[3], v] for k, v in sorted(cells.items())],
    'filers_with_a_detected_statement': len(per), 'by_class': byclass,
}
json.dump(out, open(outp, 'w'), indent=1)
print('rows', rows, '| inner archives', n_inner, '| csv files', n_csv, '| cells', len(cells), '| filers with a detected statement', len(per))
