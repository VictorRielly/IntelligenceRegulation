#!/usr/bin/env python3
"""A30: the counts of A28 (platform names by volume class) and A29 (share of statements with the text content type)
repeated over several monthly aggregated files of the EU transparency database.

Usage (run with -I; standard library only):
  python3 -I 20261126-apps-months-check.py <aggregated-simple-YYYY-MM-01-csv.zip> [more monthly zips ...]

Inputs are untrusted data: read in memory, never extracted, never executed. Platform names are read to group rows and
are never printed. No clock reading and no path is printed.
"""
import csv
import gzip
import hashlib
import io
import os
import sys
import zipfile
from datetime import date

RATE_LO, RATE_HI = 32805, 33750   # requests a day per machine at 48.6 and 50.0 tokens/s (A25)
CAP = 300 * 1024 * 1024


def cls(mean):
    return 0 if mean < 1000 else (1 if mean <= 30000 else 2)


def read(path):
    z = zipfile.ZipFile(path)
    assert sum(i.file_size for i in z.infolist()) <= CAP
    r = {'rows': 0, 'total': 0, 'days': set(), 'plat': {}, 'ptext': {}, 'flag': {}, 'text_only': 0, 'header': None, 'odd': 0}
    for info in z.infolist():
        if not info.filename.endswith('.csv.gz') or os.path.basename(info.filename).startswith('.'):
            continue
        rd = csv.DictReader(io.StringIO(gzip.decompress(z.read(info)).decode('utf-8')))
        flags = [c for c in rd.fieldnames if c.startswith('CONTENT_TYPE_')]
        if r['header'] is None:
            r['header'] = list(rd.fieldnames)
        else:
            assert r['header'] == list(rd.fieldnames)
        for row in rd:
            c = int(row['count'])
            r['rows'] += 1
            r['total'] += c
            r['days'].add(row['created_at'][:10])
            p = row['platform_name']
            r['plat'][p] = r['plat'].get(p, 0) + c
            on = []
            for f in flags:
                if row[f] == 'true':
                    on.append(f)
                elif row[f] != 'false':
                    r['odd'] += 1
            for f in on:
                r['flag'][f] = r['flag'].get(f, 0) + c
            if 'CONTENT_TYPE_TEXT' in on:
                r['ptext'][p] = r['ptext'].get(p, 0) + c
                if len(on) == 1:
                    r['text_only'] += c
    return r


def main(argv):
    if not argv:
        print('usage: <monthly zip> [more ...]')
        return 2
    print('== inputs (sha256, bytes)')
    months = []
    for p in argv:
        h = hashlib.sha256(open(p, 'rb').read()).hexdigest()
        print(os.path.basename(p), h, os.path.getsize(p))
        months.append((os.path.basename(p), read(p)))
    months.sort()
    heads = set(tuple(r['header']) for _, r in months)
    print('\ncolumn lists identical across the %d files: %s; flag cells neither true nor false: %d'
          % (len(months), len(heads) == 1, sum(r['odd'] for _, r in months)))

    print('\n== A28 repeated: platform names by volume class (class = month total / calendar days of the month)')
    print('month    days   names   statements   mean a day | under 1,000 | 1,000 to 30,000 | over 30,000 (share) | largest  top 5')
    info = {}
    for name, r in months:
        ds = sorted(r['days'])
        y, m = int(ds[0][:4]), int(ds[0][5:7])
        assert all(d[:7] == ds[0][:7] for d in ds)
        dim = (date(y + (m == 12), m % 12 + 1, 1) - date(y, m, 1)).days
        n = [0, 0, 0]
        s = [0, 0, 0]
        for p, t in r['plat'].items():
            k = cls(t / dim)
            n[k] += 1
            s[k] += t
        ts = sorted(r['plat'].values(), reverse=True)
        tot = r['total']
        info[name] = (ds[0][:7], dim, n)
        print('%s %2d/%2d  %5d  %11d  %10d | %4d %5.2f%% | %4d %5.2f%% | %4d %5.2f%% | %5.2f%% %5.2f%%'
              % (ds[0][:7], len(ds), dim, len(r['plat']), tot, tot // dim, n[0], 100.0 * s[0] / tot, n[1], 100.0 * s[1] / tot,
                 n[2], 100.0 * s[2] / tot, 100.0 * ts[0] / tot, 100.0 * sum(ts[:5]) / tot))

    print('\n== A29 repeated: content types (share of the month\x27s statements carrying each flag)')
    print('month     text  text alone  product   other   video   image | text-type a day  machines | names with text: under 1,000 / 1,000 to 30,000 / over 30,000 (top class share of text)')
    worst = 0.0
    for name, r in months:
        mon, dim, _ = info[name]
        tot = r['total']
        f = r['flag']
        t = f.get('CONTENT_TYPE_TEXT', 0)
        n = [0, 0, 0]
        s = [0, 0, 0]
        for p, v in r['ptext'].items():
            k = cls(v / dim)
            n[k] += 1
            s[k] += v
        share = 100.0 * t / tot
        worst = max(worst, share)
        print('%s %5.2f%%     %5.2f%%   %5.2f%%  %5.2f%%  %5.2f%%  %5.2f%% | %14d  %4.1f to %4.1f | %3d / %3d / %3d (%5.2f%%)'
              % (mon, share, 100.0 * r['text_only'] / tot, 100.0 * f.get('CONTENT_TYPE_PRODUCT', 0) / tot,
                 100.0 * f.get('CONTENT_TYPE_OTHER', 0) / tot, 100.0 * f.get('CONTENT_TYPE_VIDEO', 0) / tot,
                 100.0 * f.get('CONTENT_TYPE_IMAGE', 0) / tot, t // dim, t / dim / RATE_HI, t / dim / RATE_LO,
                 n[0], n[1], n[2], 100.0 * s[2] / t if t else 0.0))
    print('highest text share in any month: %.2f%%; kill line of A29 (over 10 percent in any month): %s'
          % (worst, 'KILLED' if worst > 10.0 else 'not reached'))

    print('\n== names across the months (COUNTED; none printed)')
    sets = [set(r['plat']) for _, r in months]
    union = set().union(*sets)
    inter = set(sets[0]).intersection(*sets[1:]) if len(sets) > 1 else sets[0]
    print('distinct names over all files: %d; present in every file: %d' % (len(union), len(inter)))
    stable = 0
    moved = 0
    for p in union:
        ks = set()
        for name, r in months:
            if p in r['plat']:
                ks.add(cls(r['plat'][p] / info[name][1]))
        if len(ks) == 1:
            stable += 1
        else:
            moved += 1
    print('names in the same class in every month they appear: %d; names that change class at least once: %d' % (stable, moved))
    print('platform names printed: NONE')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
