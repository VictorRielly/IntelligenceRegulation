#!/usr/bin/env python3
"""A25 arithmetic and quotation check. Reads files, prints; writes nothing.

Run (the inputs are the downloaded pages, never executed, read as text only):
  python3 -I 20261126-apps-daily-volume.py STATUS.md README.md download.html home.html year.html data_sources.html \
      dashboard.html [extra files for sha256 only ...]
  STATUS.md  = docs/zkmatrix-poc/MVP_STATUS.md
  README.md  = results/zk60_lane_threads_20261122/README.md
Every quoted sentence is looked up in the whitespace-normalised text of its file (tags removed, entities
decoded); a miss prints CHECK FAILED and the arithmetic below it should not be trusted. Only file base names
are printed.
"""
import hashlib
import html
import os
import re
import sys


def norm_html(t):
    t = re.sub(r'<script.*?</script>|<style.*?</style>', '', t, flags=re.S)
    t = re.sub(r'<[^>]+>', ' ', t)
    return re.sub(r'\s+', ' ', html.unescape(t)).strip()


def norm_md(t):
    return re.sub(r'\s+', ' ', t).strip()


def load(path, is_html):
    with open(path, encoding='utf-8', errors='replace') as f:
        raw = f.read()
    return norm_html(raw) if is_html else norm_md(raw), raw


if len(sys.argv) < 8:
    sys.exit('need: STATUS README download home year data_sources dashboard [extras...]')
paths = sys.argv[1:]
names = ['status page', 'lane-threads README', 'DSA download page', 'DSA homepage', 'arXiv 2504.06976 (html)',
         'dsa-tdb data-sources page', 'DSA dashboard page']
texts = {}
print('== inputs (sha256) ==')
for i, p in enumerate(paths):
    with open(p, 'rb') as f:
        h = hashlib.sha256(f.read()).hexdigest()
    label = names[i] if i < len(names) else 'extra file (sha only)'
    print('%s  %s  [%s]' % (h, os.path.basename(p), label))
    if i < len(names):
        texts[names[i]] = load(p, i >= 2)[0]
        if i == 2:
            texts['_download_raw'] = load(p, True)[1]


def check(key, *needles):
    ok = True
    for s in needles:
        hit = norm_md(s) in texts[key]
        ok &= hit
        print(('ok   ' if hit else 'CHECK FAILED ') + '[%s] "%s"' % (key, norm_md(s)))
    return ok


print()
print('== 1. quoted sentences found in the files ==')
check('status page',
      '**2026-11-23 UTC, speed against the 50 tokens/s target [MEASURED; details and limits in the dated entries further down]:**',
      'The trained 3B classifier that the app runs proves 48.6 to 50.0 tokens/s at six lanes with eight threads each '
      '(`results/zk60_lane_threads_20261122/README.md`).',
      "On the installed classifier profile one run of one policy over one chunk takes 2.6 to 2.7 s of the machine's "
      'six-lane capacity (128 padded positions at the 47.1 to 50.0 tok/s of the 22 November sets, which are not ranked) '
      'and one 0.67 GB receipt.',
      'the app\'s deployment file on the project\'s machine says "Public content only; privacy not claimed"',
      '**Nov 23, 23:12 UTC, speed [MEASURED by Claude at the installed app profile; gains DERIVED from the raw completions]:',
      'So the installed profile, with this fifth switch, measures about 53 to 55 tok/s on public test posts with the '
      'trained 3B classifier; the day began at about 46.5. This is not the private 8B target.')
check('lane-threads README',
      'rate = 48 x 128 / (c[L+48] - c[L])',
      'a fresh `zk60_classify serve --lanes L --lane-threads T --witness-cache-gib 16` per leg on the installed W16R2 Shieldstral export',
      'per-thread Metal queues, the eight public posts, L warm-up requests then 48 timed',
      '| **6 x 8** | 6 | **48.64** | **+3.2%** |',
      'Levels over four legs each: X 48.96, Y 50.00, Z 49.70 tok/s.')
check('DSA homepage',
      'Below you can find some summary statistics on the statements of reasons submitted by providers of online platforms '
      'to the Commission in the last six months (180 days, see the Data retention policy for details).',
      '4 911 188 424 Total number of statements of reasons submitted',
      '396 Number of active platforms')
check('DSA download page',
      'On this page, you can download zipped csv files containing the daily submissions of statements of reasons, '
      'either for all platforms collectively or for each platform individually.',
      'Date Statements of reasons Full Size Light Size')
check('arXiv 2504.06976 (html)',
      'The SoRs cover all self-reported moderation actions that eight very large social media platforms took in the EU '
      'between March and October 2024.',
      'In detail, our data includes 646.1M SoRs from TikTok, 300.8M from Instagram, 260.2M from Facebook, 81.9M from '
      'Pinterest, 36.3M from YouTube, 2.3M from Snapchat, 628K from X, and 293K from LinkedIn.')
check('dsa-tdb data-sources page',
      'These aggregated views report the overall count of Statements of Reasons (SoRs) that share the same value in a '
      'specific subset of the categorical features.')
if 'platform_name' in texts['dsa-tdb data-sources page']:
    print('ok   [dsa-tdb data-sources page] the token platform_name occurs (aggregation field)')
else:
    print('CHECK FAILED [dsa-tdb data-sources page] token platform_name absent')
dash = texts['DSA dashboard page']
print('dashboard page: %d characters of text; contains a statement count: %s; contains "platforms active": %s'
      % (len(dash), bool(re.search(r'\d{1,3}( \d{3}){2,}', dash)), 'active platforms' in dash))

print()
print('== 2. the platform selector on the download page (counted from the raw option list) ==')
raw = open(paths[2], encoding='utf-8', errors='replace').read()
sel = re.search(r'<select[^>]*id="platform_id".*?</select>', raw, flags=re.S)
opts = [re.sub(r'\s+', ' ', html.unescape(x)).strip() for x in re.findall(r'<option[^>]*>(.*?)</option>', sel.group(0), flags=re.S)]
print('options %d; placeholders %s; platform names %d [COUNTED]; this is the list of platforms that can be chosen, '
      'not a count of platforms active in a period' % (len(opts), opts[:2], len(opts) - 2))

print()
print('== 3. daily totals on page 1 of the download table (all platforms, statements of reasons a day) ==')
rows = re.findall(r'(\d{4}-\d\d-\d\d) (\d{1,3}(?: \d{3})+) zip', texts['DSA download page'])
vals = [(d, int(n.replace(' ', ''))) for d, n in rows]
print('rows %d, from %s to %s' % (len(vals), vals[-1][0], vals[0][0]))
tot = sum(v for _, v in vals)
print('sum %s; mean a day %s; min %s (%s); max %s (%s)' % (
    format(tot, ','), format(round(tot / len(vals)), ','),
    format(min(v for _, v in vals), ','), min(vals, key=lambda x: x[1])[0],
    format(max(v for _, v in vals), ','), max(vals, key=lambda x: x[1])[0]))
print('days with fewer than 1 million: %d' % sum(1 for _, v in vals if v < 1_000_000))

print()
print('== 4. homepage window: 180 days, all active platforms ==')
HOME_TOTAL = 4_911_188_424
ACTIVE = 396
DAYS = 180
per_day = HOME_TOTAL / DAYS
print('statements a day, mean over the 180 days: %s / %d = %s [DERIVED]' % (format(HOME_TOTAL, ','), DAYS, format(round(per_day), ',')))
print('mean a day per active platform: %s / %d = %s [DERIVED; a mean over a very uneven spread, NOT a class count]'
      % (format(round(per_day), ','), ACTIVE, format(round(per_day / ACTIVE), ',')))

print()
print('== 5. eight-platform table: statements over March to October 2024, mean a day (DERIVED) ==')
DAYS_2024 = 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31  # March..October inclusive
print('days March to October 2024: %d' % DAYS_2024)
EIGHT = [('p1', 646.1e6), ('p2', 300.8e6), ('p3', 260.2e6), ('p4', 81.9e6), ('p5', 36.3e6), ('p6', 2.3e6),
         ('p7', 628e3), ('p8', 293e3)]  # same order as the quoted sentence; names withheld here
classes = {'under 1,000': 0, '1,000 to 30,000': 0, 'over 30,000': 0}
for n, v in EIGHT:
    d = v / DAYS_2024
    c = 'under 1,000' if d < 1000 else ('1,000 to 30,000' if d <= 30000 else 'over 30,000')
    classes[c] += 1
    print('%s: %s / %d = %s a day -> %s' % (n, format(round(v), ','), DAYS_2024, format(round(d), ','), c))
print('class counts among these eight (ONLY these eight very large platforms, 2024, an average over the whole period): %s' % classes)
print('sum of the eight: %s statements' % format(round(sum(v for _, v in EIGHT)), ','))

print()
print('== 6. requests one machine proves a day at one request per statement (DERIVED) ==')
WINDOW = 128  # padded positions per request (status page sentence above; one chunk, one policy)
SEC = 86400
print('one request = one chunk window of %d padded positions under one policy = one category' % WINDOW)
print('%-52s %8s %12s %12s %14s' % ('rate set (tokens/s; padded positions)', 'tok/s', 'req/s', 'req/day', 'statements/day at 3 categories'))
SETS = [('status sentence, low end (22 Nov sets)', 48.6),
        ('lane-threads README, 6x8 level of 6 legs', 48.64),
        ('lane-threads README, default arm, 4 legs', 48.96),
        ('status sentence, high end (README tail-250 arm, 4 legs)', 50.0)]
for lab, r in SETS:
    rs = r / WINDOW
    print('%-52s %8.2f %12.4f %12s %14s' % (lab, r, rs, format(round(rs * SEC), ','), format(round(rs * SEC / 3), ',')))
print('separate, later test (23 Nov 23:12 UTC entry, other binary, not merged then; NOT chained with the rows above):')
for lab, r in [('later entry, low end', 53.0), ('later entry, high end', 55.0)]:
    rs = r / WINDOW
    print('%-52s %8.2f %12.4f %12s %14s' % (lab, r, rs, format(round(rs * SEC), ','), format(round(rs * SEC / 3), ',')))
print('seconds a request occupies the stream: %d/48.6 = %.3f s; %d/50.0 = %.3f s (status page says 2.6 to 2.7 s)' % (WINDOW, WINDOW / 48.6, WINDOW, WINDOW / 50.0))

print()
print('== 7. one machine against the all-platform totals (DERIVED; one request per statement, one chunk each) ==')
lo = 48.6 / WINDOW * SEC
hi = 50.0 / WINDOW * SEC
for lab, total in [('homepage 180-day mean a day', per_day), ('page-1 table mean a day (%s to %s)' % (vals[-1][0], vals[0][0]), tot / len(vals))]:
    print('%-58s %12s a day: one machine covers %.3f%% to %.3f%%; %s to %s machines' % (
        lab, format(round(total), ','), 100 * lo / total, 100 * hi / total, format(round(total / hi), ','), format(round(total / lo), ',')))
for lab, v in [('smallest of the eight, mean a day', 293e3 / DAYS_2024), ('the second smallest', 628e3 / DAYS_2024),
               ('the middle-class one with the most', 2.3e6 / DAYS_2024)]:
    print('%-58s %12s a day: %.2f to %.2f machine-days of capacity a day' % (lab, format(round(v), ','), v / hi, v / lo))
print('Statements of reasons that need J chunks (a post longer than one chunk) divide these figures by J; the repository')
print('records give J = 3 to 22 for posts at T = 128 (A18); no source read here gives the share of statements that are text.')
