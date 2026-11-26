#!/usr/bin/env python3
"""A28: platform counts by volume class from one monthly aggregated file.

Usage (run with -I; standard library only):
  python3 -I 20261126-apps-platform-volume-classes.py <data_sources.html> <download.html> <aggregated-simple-YYYY-MM-01-csv.zip>

Inputs are untrusted data: read as bytes/text only, never executed. The zip is
never extracted; its CSV members are decompressed in memory with a hard cap.
Platform names are read to group rows but are never printed.
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
from datetime import date

GZ_CAP = 300 * 1024 * 1024  # bytes read per gz member, hard cap
ZIP_DECLARED_CAP = 300 * 1024 * 1024


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def text_of(path):
    t = open(path, encoding='utf-8', errors='replace').read()
    t = re.sub(r'(?s)<(script|style).*?</\1>', '', t)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t)
    return re.sub(r'\s+', ' ', t)


def main(argv):
    paths = {}
    for p in argv:
        b = os.path.basename(p)
        if b.endswith('.zip'):
            paths['zip'] = p
        elif b.startswith('data_sources'):
            paths['docs'] = p
        elif b.startswith('download'):
            paths['dl'] = p
    for k in ('zip', 'docs', 'dl'):
        if k not in paths:
            print('missing input:', k)
            return 2

    print('== inputs (sha256, bytes)')
    for k in ('docs', 'dl', 'zip'):
        p = paths[k]
        print(os.path.basename(p), sha256(p), os.path.getsize(p))

    print('\n== quoted sentences re-checked against the files')
    docs = text_of(paths['docs'])
    dl = text_of(paths['dl'])
    quotes = [
        ('docs', 'https://dsa.pages.code.europa.eu/transparency-database/dsa-tdb/data_sources.html, section "Aggregated data"',
         'We provide aggregated data in both CSV and parquet format.'),
        ('docs', 'same page, section "Aggregated data"',
         'These aggregated views report the overall count of Statements of Reasons (SoRs) that share the same value in a specific subset of the categorical features.'),
        ('docs', 'same page, section "Aggregated data", list "In aggregating the data"',
         'The created_at datetime field is truncated (floored) at the day level.'),
        ('docs', 'same page, same list',
         'The count of SoRs is reported in the count column.'),
        ('docs', 'same page, section "Versions", Limited version',
         'This version contains the SoRs data aggregated in a way to reproduce the website version of the dashboard'),
        ('docs', 'same page, section "Versions", Limited version, group-by list',
         'platform_name created_at (truncated to day) source_type'),
        ('docs', 'same page, section "Aggregated data", file naming',
         'aggregated - { simple , complete } - YYYY - MM . { parquet , csv } . zip'),
        ('docs', 'same page, section "Aggregated data", warning',
         'The aggregated data provisioning is still in an experimentatl phase and are not guaranteed to be up-to-date with the raw data.'),
        ('dl', 'https://transparency.dsa.ec.europa.eu/explore-data/download, notification',
         'You can also download daily aggregates of statements of reasons submissions in csv or Parquet format.'),
    ]
    found = 0
    for k, where, q in quotes:
        src = docs if k == 'docs' else dl
        ok = q in src
        found += ok
        print('FOUND' if ok else 'NOT FOUND', '|', where, '|', q)
    print('quotations found: %d of %d' % (found, len(quotes)))

    print('\n== archive (never extracted)')
    z = zipfile.ZipFile(paths['zip'])
    infos = z.infolist()
    declared = sum(i.file_size for i in infos)
    print('members: %d, declared uncompressed total: %d bytes (stop rule: > %d)' % (len(infos), declared, ZIP_DECLARED_CAP))
    if declared > ZIP_DECLARED_CAP:
        print('STOP: declared size over the rule')
        return 3
    parts = [i for i in infos if i.filename.endswith('.csv.gz') and not os.path.basename(i.filename).startswith('.')]
    print('csv.gz parts:', len(parts))

    header = None
    totals = {}          # platform -> statements
    dates_by = {}        # platform -> set of days
    all_days = set()
    rows = 0
    total_count = 0
    bad_count = 0
    empty_platform_rows = 0
    row_count_in_parts = []
    for info in parts:
        raw = gzip.GzipFile(fileobj=io.BytesIO(z.read(info))).read(GZ_CAP + 1)
        if len(raw) > GZ_CAP:
            print('STOP: a part decompresses to more than the cap')
            return 4
        rdr = csv.reader(io.StringIO(raw.decode('utf-8')))
        h = next(rdr)
        if header is None:
            header = h
        elif h != header:
            print('STOP: parts have different headers')
            return 5
        ip, ic, id_ = h.index('platform_name'), h.index('count'), h.index('created_at')
        n = 0
        for r in rdr:
            n += 1
            try:
                c = int(r[ic])
            except ValueError:
                bad_count += 1
                continue
            p = r[ip]
            if p == '':
                empty_platform_rows += 1
            d = r[id_][:10]
            totals[p] = totals.get(p, 0) + c
            dates_by.setdefault(p, set()).add(d)
            all_days.add(d)
            total_count += c
        rows += n
        row_count_in_parts.append(n)
    print('data rows per part:', row_count_in_parts, 'total rows:', rows)
    print('rows with an unreadable count:', bad_count)
    print('rows with an empty platform_name:', empty_platform_rows)

    print('\n== columns (header of the file)')
    print(','.join(header))

    days_sorted = sorted(all_days)
    y, m = int(days_sorted[0][:4]), int(days_sorted[0][5:7])
    first = date(y, m, 1)
    nxt = date(y + (m == 12), (m % 12) + 1, 1)
    days_in_month = (nxt - first).days
    months_seen = sorted(set(d[:7] for d in days_sorted))
    print('\n== what a row counts')
    print('One row = one combination of (automated_decision, automated_detection, category, content-type flags, decision fields,')
    print('platform_name, day, source_type); the count column is the number of statements of reasons in that combination')
    print('(SOURCE, quoted above). Summing count per platform gives that platform\'s statements in the file.')
    print('distinct days present in the file: %d; months present: %s; days in that month: %d' % (len(all_days), ','.join(months_seen), days_in_month))
    print('days range from %s to %s; calendar days missing from the file: %d' % (days_sorted[0], days_sorted[-1], days_in_month - len(all_days)))

    print('\n== counts (COUNTED from the file, DERIVED means)')
    print('platforms in the file (distinct platform_name values):', len(totals))
    print('statements in the month (sum of count):', total_count)

    def classify(mean):
        if mean < 1000:
            return 'under 1,000'
        if mean <= 30000:
            return '1,000 to 30,000'
        return 'over 30,000'

    classes = ['under 1,000', '1,000 to 30,000', 'over 30,000']
    for label, den in (('mean = month total / %d calendar days of the month' % days_in_month, lambda p: days_in_month),
                       ('mean = month total / days on which the platform appears', lambda p: len(dates_by[p]))):
        cnt = {c: 0 for c in classes}
        stm = {c: 0 for c in classes}
        for p, t in totals.items():
            c = classify(t / den(p))
            cnt[c] += 1
            stm[c] += t
        print('\nBasis:', label)
        for c in classes:
            print('  class %-16s platforms: %4d   statements: %12d   share of month: %6.2f%%' % (c, cnt[c], stm[c], 100.0 * stm[c] / total_count))
        print('  check: platforms %d, statements %d' % (sum(cnt.values()), sum(stm.values())))

    a = {p: classify(t / days_in_month) for p, t in totals.items()}
    b = {p: classify(t / len(dates_by[p])) for p, t in totals.items()}
    diff = sum(1 for p in totals if a[p] != b[p])
    print('\nplatforms whose class differs between the two bases:', diff)
    full = sum(1 for p in totals if len(dates_by[p]) == len(all_days))
    print('platforms present on every day in the file:', full, 'of', len(totals))
    hist = {}
    for p in totals:
        k = len(dates_by[p])
        bucket = '1 day' if k == 1 else ('2 to 7 days' if k <= 7 else ('8 to %d days' % (len(all_days) - 1) if k < len(all_days) else 'every day'))
        hist[bucket] = hist.get(bucket, 0) + 1
    print('platforms by number of days present:', ', '.join('%s: %d' % (k, hist[k]) for k in sorted(hist)))
    mx = max(totals.values())
    print('largest platform share of the month: %.2f%%' % (100.0 * mx / total_count))
    ts = sorted(totals.values(), reverse=True)
    print('top 5 platforms together: %.2f%% of the month' % (100.0 * sum(ts[:5]) / total_count))
    print('platform names printed: NONE')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
