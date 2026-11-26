#!/usr/bin/env python3
"""Coordinator's cross-check for A28 (run with python3 -I; standard library only).

Usage: python3 -I 20261126-apps-platform-volume-classes-crosscheck.py <aggregated zip> <publisher .sha1 file> <download table page html> [more pages]

Independent of the tick's script: recounts the classes from the zip, compares the zip's SHA-1
with the publisher's, and compares the zip's per-day totals with the website's daily table.
Prints no platform name, no clock reading and no path.
"""
import csv
import gzip
import hashlib
import html
import io
import os
import re
import sys
import zipfile


def digest(path, name):
    h = hashlib.new(name)
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def table_rows(path):
    t = open(path, encoding='utf-8', errors='replace').read()
    out = {}
    pat = re.compile(
        r'data-ecl-table-header="Date">\s*(\d{4}-\d{2}-\d{2})\s*</td>\s*'
        r'<td[^>]*data-ecl-table-header="Statements of reasons">([^<]*)</td>')
    for m in pat.finditer(t):
        n = re.sub(r'[^0-9]', '', html.unescape(m.group(2)))
        out[m.group(1)] = int(n)
    return out


def main(argv):
    zpath, spath, pages = argv[0], argv[1], argv[2:]
    print('== the zip')
    print('bytes', os.path.getsize(zpath))
    print('sha256', digest(zpath, 'sha256'))
    s1 = digest(zpath, 'sha1')
    pub = open(spath, encoding='utf-8', errors='replace').read().split()
    print('sha1  ', s1)
    print('publisher sha1 file: %d bytes, first field equals the zip sha1: %s'
          % (os.path.getsize(spath), bool(pub) and pub[0].lower() == s1))

    z = zipfile.ZipFile(zpath)
    declared = sum(i.file_size for i in z.infolist())
    assert declared <= 300 * 1024 * 1024
    per_day = {}
    per_plat = {}
    days_of = {}
    rows = 0
    for info in z.infolist():
        if not info.filename.endswith('.csv.gz'):
            continue
        raw = gzip.decompress(z.read(info))
        rd = csv.DictReader(io.StringIO(raw.decode('utf-8')))
        for r in rd:
            rows += 1
            c = int(r['count'])
            d = r['created_at'][:10]
            p = r['platform_name']
            per_day[d] = per_day.get(d, 0) + c
            per_plat[p] = per_plat.get(p, 0) + c
            days_of.setdefault(p, set()).add(d)
    total = sum(per_day.values())
    ndays = len(per_day)
    print('\n== recount (independent parser)')
    print('rows %d; days %d (%s to %s); platforms %d; statements %d'
          % (rows, ndays, min(per_day), max(per_day), len(per_plat), total))

    def cls(mean):
        return 0 if mean < 1000 else (1 if mean <= 30000 else 2)
    names = ['under 1,000', '1,000 to 30,000', 'over 30,000']
    for label, den in (('31 days', lambda p: 31), ('days present', lambda p: len(days_of[p]))):
        n = [0, 0, 0]
        s = [0, 0, 0]
        for p, t in per_plat.items():
            k = cls(t / den(p))
            n[k] += 1
            s[k] += t
        print('basis %-12s' % label, '; '.join('%s: %d platforms, %d statements, %.2f%%'
              % (names[k], n[k], s[k], 100.0 * s[k] / total) for k in range(3)))
    ts = sorted(per_plat.values(), reverse=True)
    print('largest %.2f%%; top five %.2f%%; top 20 %.2f%%'
          % (100.0 * ts[0] / total, 100.0 * sum(ts[:5]) / total, 100.0 * sum(ts[:20]) / total))
    # platforms near a class boundary on the 31-day basis (within 10 percent of 1,000 or 30,000)
    near = sum(1 for t in per_plat.values()
               if 900 <= t / 31 <= 1100 or 27000 <= t / 31 <= 33000)
    print('platforms whose 31-day mean is within 10 percent of a class boundary:', near)
    print('mean a day over the month: %d' % (total // 31))

    print('\n== against the website daily table (statements of reasons per day, all platforms)')
    web = {}
    for p in pages:
        r = table_rows(p)
        print('page rows %d (%s to %s)' % (len(r), min(r) if r else '-', max(r) if r else '-'))
        web.update(r)
    both = sorted(d for d in per_day if d in web)
    print('days of the file found in the table: %d of %d' % (len(both), ndays))
    if both:
        wsum = sum(web[d] for d in both)
        fsum = sum(per_day[d] for d in both)
        print('table sum over those days: %d; file sum over those days: %d; file / table = %.4f'
              % (wsum, fsum, fsum / wsum))
        eq = sum(1 for d in both if web[d] == per_day[d])
        print('days on which the two are equal: %d' % eq)
        ratios = sorted((per_day[d] / web[d], d) for d in both)
        print('lowest file/table ratio %.4f on %s; highest %.4f on %s'
              % (ratios[0][0], ratios[0][1], ratios[-1][0], ratios[-1][1]))
        within = sum(1 for x, _ in ratios if 0.99 <= x <= 1.01)
        print('days within 1 percent: %d' % within)
        for d in both:
            print('  %s table %11d file %11d ratio %.4f' % (d, web[d], per_day[d], per_day[d] / web[d]))
        print('table mean a day over those days: %d' % (wsum // len(both)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
