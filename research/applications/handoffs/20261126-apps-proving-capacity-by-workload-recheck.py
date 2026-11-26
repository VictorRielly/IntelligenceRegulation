"""Coordinator's check of applications handoff A34 (daily proving capacity and download sizes for two measured
text workloads). Usage, from the repository root:
  python3 -I this.py results/zk60_lane_threads_20261122/raw results/zk60_astra_20261026/app_composed_native_20261122 \
      research/applications/handoffs/20261126-apps-measured-benchmark-fit-recheck.json \
      research/applications/handoffs/20261126-apps-proving-capacity-by-workload.md
Standard library only; nothing of the app is imported and no signature is verified here. It recomputes, from the raw
records of the 22 November timing sets, the mean rate of each of the three settings and the receipt size; from the three
pilot publications, the segment inventory; and from the coordinator's own count for A33, every derived figure of the
handoff's two tables. Prints one line per check; exits non-zero on a failure."""
import collections
import hashlib
import json
import math
import os
import sys

RAW, PILOT, A33, HAND = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
H = open(HAND, encoding='utf-8').read()
ok = True


def check(label, cond):
    global ok
    print(('ok   ' if cond else 'FAIL ') + label)
    ok = ok and bool(cond)


# 1. the timing records: six lanes, eight threads; settings "6x8" (the thread-setting sets), C and D (the tail-round sets)
rates = collections.defaultdict(list)
sizes = collections.Counter()
legs = requests = 0
for group in ('lt_set2', 'lt_set2b', 'lt_set3', 'tr_set1', 'tr_set1b'):
    for leg in json.load(open(os.path.join(RAW, group, 't2_results.json')))['legs']:
        if (leg['lanes'], leg['threads']) != (6, 8):
            continue
        arm = '6x8' if group.startswith('lt') else leg['arm']
        if arm == 'E':
            continue
        c = leg['completions']
        assert (leg['N'], leg['timed'], len(c)) == (6, 48, 54)
        assert all(x['status'] == 'proved' for x in c)
        assert leg['verify_summary'] == {'receipts': 54, 'checked': 54, 'other': 0}
        rate = 48 * 128 / (c[-1]['t_abs'] - c[5]['t_abs'])
        assert math.isclose(rate, leg['rate'], rel_tol=1e-8)
        rates[arm].append(rate)
        legs += 1
        requests += len(c)
        for x in c:
            sizes[x['receipt_bytes']] += 1
mean = {k: sum(v) / len(v) for k, v in rates.items()}
check('legs per setting: six, four and four; 14 legs, 756 requests, all proved and checked',
      {k: len(v) for k, v in rates.items()} == {'6x8': 6, 'C': 4, 'D': 4} and (legs, requests) == (14, 756)
      and 'all 756 requests including warm-up were proved and checked' in H)
check('every receipt is 669,561,472 bytes', dict(sizes) == {669561472: 756} and 'all 756 receipts were 669,561,472 bytes each' in H)
RECEIPT = 669561472
check('mean rates %.3f / %.3f / %.3f padded positions a second' % (mean['6x8'], mean['C'], mean['D']),
      ['%.3f' % mean[k] for k in ('6x8', 'C', 'D')] == ['48.637', '48.963', '49.997'])

# 2. the three pilot publications of the same 14-token post
seg = {}
dup = 0
entries = 0
for tag in ('20261124T082610.220713Z', '20261124T183850.945359Z', '20261125T070919.014403Z'):
    run = os.path.join(PILOT, 'qualification-' + tag)
    signed = json.load(open(os.path.join(run, 'manifest.json')))
    assert signed['item']['content_length_tokens'] == 14
    for e in signed['entries']:
        raw = open(os.path.join(run, e['category'] + '.publication.json'), 'rb').read()
        assert hashlib.sha256(raw).hexdigest() == e['bundle']['manifest_sha256']
        inv = json.loads(raw)
        assert inv['statement_sha256'] == e['statement_sha256'] and len(inv['segments']) == 28
        assert sum(s['bytes'] for s in inv['segments']) == RECEIPT
        entries += 1
        for s in inv['segments']:
            dup += s['sha256'] in seg
            seg[s['sha256']] = s['bytes']
check('nine signed inventories of 28 segments each; 252 distinct segment hashes; 6,026,053,248 bytes',
      (entries, len(seg), dup, sum(seg.values())) == (9, 252, 0, 6026053248) and 9 * RECEIPT == 6026053248
      and '**252 distinct segment hashes and 6,026,053,248 bytes**' in H)
arc = json.load(open(os.path.join(PILOT, 'DOWNLOAD_RESUME.json')))
check('one measured archive: 2,008,826,368 bytes; three receipts are 2,008,684,416; the rest is 141,952',
      arc['passed'] and arc['bytes'] == 2008826368 and 3 * RECEIPT == 2008684416 and arc['bytes'] - 3 * RECEIPT == 141952
      and all(s in H for s in ('2,008,684,416 bytes', '2,008,826,368 bytes', '141,952 bytes')))

# 3. the two workloads, from the coordinator's own count for A33
J = json.load(open(A33))
W = {}
for name, key in (('OpenAI', 'moderation prompts'), ('ToxicChat', 'chatbot user messages')):
    s = J[key]
    hist = sorted((int(k), v) for k, v in s['proofs_histogram'].items())
    acc, jobs, total = sum(v for _, v in hist), sum(k * v for k, v in hist), s['totals']['rows']
    q = {}
    for p in (0.5, 0.95):
        t = math.ceil(p * acc)
        for k, v in hist:
            t -= v
            if t <= 0:
                q[p] = k
                break
    W[name] = (total, acc, jobs, q)
check('workloads: 1,680 received / 1,348 eligible / 8,919 requests and 5,083 / 4,888 / 18,251',
      W['OpenAI'][:3] == (1680, 1348, 8919) and W['ToxicChat'][:3] == (5083, 4888, 18251)
      and '1,680 received / 1,348 eligible / 8,919 requests' in H and '5,083 / 4,888 / 18,251' in H)


def n(x):
    return format(int(round(x)), ',')


for arm, label in (('6x8', 'Six thread-setting legs, defaults'), ('C', 'Four later tail-round legs, default C'), ('D', 'Same later comparison, experimental D')):
    calls = mean[arm] * 86400 / 128
    cells = []
    for name in ('OpenAI', 'ToxicChat'):
        total, acc, jobs, _ = W[name]
        cells.append('%s / %s' % (n(calls * total / jobs), n(calls * acc / jobs)))
    line = '| %s | %.3f | %s | %s | %s |' % (label, mean[arm], n(calls), cells[0], cells[1])
    check(line, line in H)
calls = mean['6x8'] * 86400 / 128
check('headline: about 4,962 eligible posts a day for the first mix and 8,793 for the second',
      (n(calls * 1348 / 8919), n(calls * 4888 / 18251)) == ('4,962', '8,793')
      and 'about 4,962 eligible posts per day for the OpenAI moderation mix or 8,793 for the ToxicChat mix' in H)
gb = lambda k: '%.3f GB' % (k * RECEIPT / 1e9)
a, b = W['OpenAI'], W['ToxicChat']
line = '| Mean per eligible text | %s | %s |' % (gb(a[2] / a[1]), gb(b[2] / b[1]))
check(line, line in H)
line = '| Median per eligible text | %s (%d receipts) | %s (%d receipts) |' % (gb(a[3][0.5]), a[3][0.5], gb(b[3][0.5]), b[3][0.5])
check(line, line in H)
line = '| 95th percentile per eligible text | %s (%d receipts) | %s (%d receipts) |' % (gb(a[3][0.95]), a[3][0.95], gb(b[3][0.95]), b[3][0.95])
check(line, line in H)
line = '| All eligible texts in the source file | %.3f TB | %.3f TB |' % (a[2] * RECEIPT / 1e12, b[2] * RECEIPT / 1e12)
check(line, line in H)
check('sustained generation at the first row\x27s rate: %.3f decimal TB a day' % (calls * RECEIPT / 1e12),
      '%.3f' % (calls * RECEIPT / 1e12) == '21.982' and 'would yield 21.982 decimal TB/day' in H)
print('RESULT:', 'ALL CHECKS PASSED' if ok else 'SOMETHING FAILED')
sys.exit(0 if ok else 1)
