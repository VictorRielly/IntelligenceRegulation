#!/usr/bin/env python3
"""A29: share of statements of reasons whose content type is text, from one monthly aggregated file.

Usage (run with -I; standard library only):
  python3 -I 20261126-apps-text-share.py <api-documentation.html> <data_sources.html> <aggregated-simple-YYYY-MM-01-csv.zip>

Inputs are untrusted data: read as bytes or text only, never executed; the zip is never extracted.
Platform names are read to group rows and are never printed. No clock reading and no path is printed.
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

SCHEMA = ['CONTENT_TYPE_APP', 'CONTENT_TYPE_AUDIO', 'CONTENT_TYPE_IMAGE', 'CONTENT_TYPE_PRODUCT',
          'CONTENT_TYPE_SYNTHETIC_MEDIA', 'CONTENT_TYPE_TEXT', 'CONTENT_TYPE_VIDEO', 'CONTENT_TYPE_OTHER']
RATE_LO, RATE_HI = 32805, 33750   # requests a day per machine at 48.6 and 50.0 tokens/s (A25, DERIVED from MEASURED)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def text_of(path):
    t = open(path, encoding='utf-8', errors='replace').read()
    t = re.sub(r'(?s)<(script|style)\b.*?</\1>', ' ', t)
    t = re.sub(r'(?s)<[^>]+>', ' ', t)
    return re.sub(r'\s+', ' ', html.unescape(t))


def cls(mean):
    return 0 if mean < 1000 else (1 if mean <= 30000 else 2)


CLASSES = ['under 1,000', '1,000 to 30,000', 'over 30,000']


def main(argv):
    if len(argv) != 3:
        print('usage: <api-documentation.html> <data_sources.html> <aggregated zip>')
        return 2
    api_p, docs_p, zip_p = argv
    print('== inputs (sha256, bytes)')
    for p in (api_p, docs_p, zip_p):
        print(os.path.basename(p), sha256(p), os.path.getsize(p))

    print('\n== quoted sentences re-checked against the files')
    api, docs = text_of(api_p), text_of(docs_p)
    quotes = [
        (api, 'https://transparency.dsa.ec.europa.eu/page/api-documentation, "Content type (content_type)"',
         'This is a required attribute, and it tells us what type of content is targeted by the statement of reason. '
         'The value provided must be an array with at least one of the following: CONTENT_TYPE_APP App '
         'CONTENT_TYPE_AUDIO Audio CONTENT_TYPE_IMAGE Image CONTENT_TYPE_PRODUCT Product CONTENT_TYPE_SYNTHETIC_MEDIA '
         'Synthetic media CONTENT_TYPE_TEXT Text CONTENT_TYPE_VIDEO Video CONTENT_TYPE_OTHER Other'),
        (api, 'same page, "Content type other (content_type_other)"',
         'This is required if CONTENT_TYPE_OTHER was the content_type. It is a content type that is not part of '
         'provided content type list. Limited to 500 characters.'),
        (docs, 'https://dsa.pages.code.europa.eu/transparency-database/dsa-tdb/data_sources.html, "Aggregated data"',
         'All the array fields like content_type or decision_visibility are pivoted, that is, for each one of their '
         'possible values a new column is created and filled with a boolean, indicating whether the SoR has that value '
         'or not.'),
        (docs, 'same page, "Versions", note under the limited version',
         'The content_type field is pivoted and we also add the dsa_tdb.types.CONTENT_TYPE_OTHER_NORMALIZATION '
         'additional values. These values are meant to map recurring values found in the content_type_other field to '
         'standardized values.'),
        (docs, 'same page, "Aggregated data"', 'The count of SoRs is reported in the count column.'),
    ]
    found = 0
    for src, where, q in quotes:
        ok = q in src
        found += ok
        print('FOUND' if ok else 'NOT FOUND', '|', where, '|', q)
    print('quotations found: %d of %d' % (found, len(quotes)))

    z = zipfile.ZipFile(zip_p)
    declared = sum(i.file_size for i in z.infolist())
    if declared > 300 * 1024 * 1024:
        print('STOP: declared size over the rule')
        return 3
    flags = None
    total = 0
    rows = 0
    per_flag = {}
    combos = {}
    nflags = {}
    per_day_text = {}
    days = set()
    plat_total = {}
    plat_text = {}
    cat_all = {}
    cat_text = {}
    extra_with_other = 0
    extra_any = 0
    odd_values = 0
    for info in z.infolist():
        if not info.filename.endswith('.csv.gz') or os.path.basename(info.filename).startswith('.'):
            continue
        rd = csv.DictReader(io.StringIO(gzip.decompress(z.read(info)).decode('utf-8')))
        if flags is None:
            flags = [c for c in rd.fieldnames if c.startswith('CONTENT_TYPE_')]
        for r in rd:
            rows += 1
            c = int(r['count'])
            total += c
            on = []
            for f in flags:
                v = r[f]
                if v == 'true':
                    on.append(f)
                elif v != 'false':
                    odd_values += 1
            for f in on:
                per_flag[f] = per_flag.get(f, 0) + c
            key = tuple(on)
            combos[key] = combos.get(key, 0) + c
            nflags[len(on)] = nflags.get(len(on), 0) + c
            d = r['created_at'][:10]
            days.add(d)
            p = r['platform_name']
            plat_total[p] = plat_total.get(p, 0) + c
            cat = r['category']
            cat_all[cat] = cat_all.get(cat, 0) + c
            if 'CONTENT_TYPE_TEXT' in on:
                per_day_text[d] = per_day_text.get(d, 0) + c
                plat_text[p] = plat_text.get(p, 0) + c
                cat_text[cat] = cat_text.get(cat, 0) + c
            ex = [f for f in on if f not in SCHEMA]
            if ex:
                extra_any += c
                if 'CONTENT_TYPE_OTHER' in on:
                    extra_with_other += c
    nd = len(days)
    extras = [f for f in flags if f not in SCHEMA]

    def pct(x):
        return '%.2f%%' % (100.0 * x / total)

    print('\n== the file')
    print('rows %d; days %d (%s to %s); statements %d; platform names %d (none printed)'
          % (rows, nd, min(days), max(days), total, len(plat_total)))
    print('flag columns: %d; the eight values of the submission schema present: %s; further columns: %s'
          % (len(flags), all(f in flags for f in SCHEMA), ', '.join(extras)))
    print('flag cells that are neither true nor false: %d' % odd_values)

    print('\n== statements carrying each flag (COUNTED; one statement can carry several, so the shares add to over 100%)')
    for f in sorted(flags, key=lambda f: -per_flag.get(f, 0)):
        print('  %-30s %12d  %7s  %s' % (f, per_flag.get(f, 0), pct(per_flag.get(f, 0)),
                                         'schema' if f in SCHEMA else 'added by the aggregation'))
    print('sum of the flag shares: %.2f%%' % (100.0 * sum(per_flag.values()) / total))
    print('statements by number of flags set: ' + ', '.join('%d: %d (%s)' % (k, nflags[k], pct(nflags[k]))
                                                            for k in sorted(nflags)))
    print('statements with an added flag: %d (%s); of those with CONTENT_TYPE_OTHER also set: %d'
          % (extra_any, pct(extra_any), extra_with_other))

    print('\n== text (COUNTED)')
    t_any = per_flag.get('CONTENT_TYPE_TEXT', 0)
    t_only = combos.get(('CONTENT_TYPE_TEXT',), 0)
    print('text flag set: %d (%s of the month)' % (t_any, pct(t_any)))
    print('text flag alone: %d (%s of the month; %.2f%% of text-flag statements)' % (t_only, pct(t_only), 100.0 * t_only / t_any))
    print('text flag with at least one other flag: %d (%s of the month)' % (t_any - t_only, pct(t_any - t_only)))
    print('no text flag: %d (%s of the month)' % (total - t_any, pct(total - t_any)))
    partner = {}
    for key, c in combos.items():
        if 'CONTENT_TYPE_TEXT' in key:
            for f in key:
                if f != 'CONTENT_TYPE_TEXT':
                    partner[f] = partner.get(f, 0) + c
    print('text-flag statements that also carry: ' + ', '.join(
        '%s %d (%.2f%%)' % (f[len('CONTENT_TYPE_'):], c, 100.0 * c / t_any) for f, c in sorted(partner.items(), key=lambda x: -x[1])))
    dt = sorted(per_day_text.values())
    print('text-flag statements a day: mean over %d days %d; lowest day %d; highest day %d; days with none: %d'
          % (nd, t_any // nd, dt[0], dt[-1], nd - len(per_day_text)))

    print('\n== text-flag statements by the category the platform reported (COUNTED; the file\x27s category column)')
    print('  %-67s %10s %8s   %s' % ('category', 'text-flag', 'share', 'the category\x27s share of ALL statements'))
    for cat, c in sorted(cat_text.items(), key=lambda x: -x[1]):
        print('  %-67s %10d %7.2f%%   %6.2f%%' % (cat, c, 100.0 * c / t_any, 100.0 * cat_all[cat] / total))
    print('categories in the file: %d; with a text-flag statement: %d' % (len(cat_all), len(cat_text)))
    i0, i1 = api.find('Category (category)'), api.find('Additional categories (category_addition)')
    listed = sorted(set(re.findall(r'STATEMENT_CATEGORY_[A-Z_]+', api[i0:i1]))) if 0 <= i0 < i1 else []
    print('categories listed under "Category (category)" on the API page: %d; every category of the file is among them: %s; '
          'one with SEX or PORN in its name: %s'
          % (len(listed), all(c in listed for c in cat_all), any('SEX' in c or 'PORN' in c for c in listed)))
    near = ['STATEMENT_CATEGORY_ILLEGAL_OR_HARMFUL_SPEECH', 'STATEMENT_CATEGORY_VIOLENCE', 'STATEMENT_CATEGORY_CYBER_VIOLENCE',
            'STATEMENT_CATEGORY_CYBER_VIOLENCE_AGAINST_WOMEN']
    nsum = sum(cat_text.get(c, 0) for c in near)
    print('the four categories with SPEECH or VIOLENCE in their name together: %d text-flag statements, %.2f%% of text-flag '
          'statements, %.0f a day, %.1f to %.1f machines (DERIVED; a grouping by name only, not a validated mapping to the '
          'installed classifier\x27s policies)' % (nsum, 100.0 * nsum / t_any, nsum / nd, nsum / nd / RATE_HI, nsum / nd / RATE_LO))

    print('\n== the ten largest flag combinations (COUNTED)')
    for key, c in sorted(combos.items(), key=lambda x: -x[1])[:10]:
        label = ' + '.join(f[len('CONTENT_TYPE_'):] for f in key) if key else '(no flag)'
        print('  %-44s %12d  %7s' % (label, c, pct(c)))
    print('distinct combinations: %d' % len(combos))

    print('\n== by volume class of the platform name (class = all statements / %d days, as in A28)' % nd)
    for k in range(3):
        ps = [p for p, t in plat_total.items() if cls(t / nd) == k]
        allc = sum(plat_total[p] for p in ps)
        txt = sum(plat_text.get(p, 0) for p in ps)
        withtext = sum(1 for p in ps if plat_text.get(p, 0) > 0)
        print('  %-16s names %3d; with a text-flag statement %3d; text-flag statements %10d = %6.2f%% of the class, %6.2f%% of all text-flag statements'
              % (CLASSES[k], len(ps), withtext, txt, 100.0 * txt / allc, 100.0 * txt / t_any))
    print('names with at least one text-flag statement: %d of %d' % (len(plat_text), len(plat_total)))

    print('\n== names by their TEXT-FLAG volume alone (mean a day over %d days)' % nd)
    n = [0, 0, 0]
    s = [0, 0, 0]
    for p, t in plat_text.items():
        k = cls(t / nd)
        n[k] += 1
        s[k] += t
    for k in range(3):
        print('  %-16s names %3d; text-flag statements %10d (%.2f%% of text-flag statements)' % (CLASSES[k], n[k], s[k], 100.0 * s[k] / t_any))
    ts = sorted(plat_text.values(), reverse=True)
    print('largest name %.2f%% of text-flag statements; top five %.2f%%' % (100.0 * ts[0] / t_any, 100.0 * sum(ts[:5]) / t_any))

    print('\n== against the machine rate of A25 (DERIVED; one request per statement, one chunk, one policy)')
    m = t_any / nd
    print('text-flag statements a day %.0f: %.1f to %.1f machines at %d to %d requests a day per machine'
          % (m, m / RATE_HI, m / RATE_LO, RATE_LO, RATE_HI))
    mo = t_only / nd
    print('text flag alone, a day %.0f: %.1f to %.1f machines' % (mo, mo / RATE_HI, mo / RATE_LO))
    for k in range(3):
        mk = s[k] / nd
        print('  names with a text-flag mean %-16s together %.0f a day: %.2f to %.2f machines' % (CLASSES[k], mk, mk / RATE_HI, mk / RATE_LO))
    print('platform names printed: NONE')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
