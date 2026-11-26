"""Triage of Astra's A17 handoff: derive every figure of the handoff from (a) the cells printed by the handoff's own
program in my re-run and (b) my second count, and say which figures are found in the handoff's text.
Usage: python3 -I a17_compare.py RECOUNT.out.txt SECOND.json HANDOFF.md. Prints; exits non-zero on any mismatch."""
import collections
import csv
import json
import sys

rec, sec, hand = sys.argv[1], sys.argv[2], sys.argv[3]
H = open(hand, encoding='utf-8').read()
P = 'STATEMENT_CATEGORY_'
A = collections.Counter()
for row in csv.reader(open(rec, encoding='utf-8', errors='replace')):
    if len(row) == 5 and row[0] in ('True', 'False') and row[4].isdigit():
        A[(row[0] == 'True', row[1] == 'True', row[2], row[3] == 'True')] += int(row[4])
J = json.load(open(sec))
B = collections.Counter()
raw_det, raw_dec, addst = collections.Counter(), collections.Counter(), collections.Counter()
for det, dec, cat, st, n in J['cells']:
    B[(det == 'Yes', dec == 'AUTOMATED_DECISION_FULLY', cat, st == 'non-empty list')] += n
    raw_det[det] += n
    raw_dec[dec] += n
    addst[st] += n
ok = True


def check(label, cond):
    global ok
    print(('ok   ' if cond else 'FAIL ') + label)
    ok = ok and bool(cond)


check('cells of the handoff program (my re-run) equal the cells of my second count: %d cells' % len(A), A == B and len(A) > 0)
check('rows %s in both, and in the handoff' % format(sum(A.values()), ','), sum(A.values()) == J['rows'] == 30120164 and '30,120,164' in H)
check('302 CSV files in 31 inner archives', (J['csv_files'], J['inner_archives']) == (302, 31) and '302 CSV files in 31 inner ZIPs' in H)
print('     raw automated_detection values:', dict(raw_det))
print('     raw automated_decision values:', dict(raw_dec))
print('     additional-category field states:', dict(addst))
check('blank 26,601,192 and empty lists 3,511,867 as the handoff says',
      addst['blank'] == 26601192 and addst['empty list'] == 3511867 and '26,601,192 additional fields were blank and 3,511,867 were empty lists' in H)

G = {'Detected': lambda k: k[0], 'Fully decided': lambda k: k[1], 'Either': lambda k: k[0] or k[1]}
tot = {g: sum(v for k, v in A.items() if f(k)) for g, f in G.items()}
both = sum(v for k, v in A.items() if k[0] and k[1])
check('group sizes 25,339,814 / 13,646,725 / 25,469,494, overlap 13,517,045',
      (tot['Detected'], tot['Fully decided'], tot['Either'], both) == (25339814, 13646725, 25469494, 13517045)
      and all(s in H for s in ('**25,339,814**', '**13,646,725**', '**25,469,494**', '13,517,045')))


def cnt(g, pred):
    return sum(v for k, v in A.items() if G[g](k) and pred(k))


rows = [('Other violation of terms and conditions', 'OTHER_VIOLATION_TC', ('76.23%', '82.93%', '76.16%')),
        ('Consumer information', 'CONSUMER_INFORMATION', ('13.22%', '0.20%', '13.15%')),
        ('Unsafe and prohibited products', 'UNSAFE_AND_PROHIBITED_PRODUCTS', ('3.05%', '5.32%', '3.11%')),
        ('Illegal or harmful speech', 'ILLEGAL_OR_HARMFUL_SPEECH', ('2.35%', '4.06%', '2.36%')),
        ('Scams and fraud', 'SCAMS_AND_FRAUD', ('1.95%', '2.45%', '2.00%')),
        ('Violence', 'VIOLENCE', ('1.70%', '2.99%', '1.70%'))]
cats = sorted(set(k[2] for k in A))
for label, code, want in rows:
    got = tuple('%.2f%%' % (100.0 * cnt(g, lambda k: k[2] == P + code) / tot[g]) for g in G)
    line = '| %s | %s | %s | %s |' % ((label,) + want)
    check('%s: %s' % (label, ' / '.join(got)), got == want and P + code in cats and line in H)
order = sorted(cats, key=lambda c: -cnt('Detected', lambda k: k[2] == c))
check('the six rows are the six largest primary categories among detected statements',
      [c[len(P):] for c in order[:6]] == [r[1] for r in rows])
print('     next two among detected:', [(c[len(P):], '%.2f%%' % (100.0 * cnt('Detected', lambda k: k[2] == c) / tot['Detected'])) for c in order[6:8]])

OT, NS = P + 'OTHER_VIOLATION_TC', P + 'NOT_SPECIFIED_NOTICE'
t = {
    'other': [cnt(g, lambda k: k[2] == OT) for g in G],
    'notspec': [cnt(g, lambda k: k[2] == NS) for g in G],
    'add': [cnt(g, lambda k: k[3]) for g in G],
    'bothca': [cnt(g, lambda k: k[3] and k[2] in (OT, NS)) for g in G],
    'union': [cnt(g, lambda k: k[3] or k[2] in (OT, NS)) for g in G],
}
check('OTHER_VIOLATION_TC 19,316,591 / 11,317,631 / 19,397,342', t['other'] == [19316591, 11317631, 19397342]
      and '| \x60OTHER_VIOLATION_TC\x60 | 19,316,591 | 11,317,631 | 19,397,342 |' in H)
check('NOT_SPECIFIED_NOTICE 1,462 / 789 / 1,462', t['notspec'] == [1462, 789, 1462] and '| \x60NOT_SPECIFIED_NOTICE\x60 | 1,462 | 789 | 1,462 |' in H)
pa = ['%.3f%%' % (100.0 * t['add'][i] / tot[g]) for i, g in enumerate(G)]
check('additional 6,822 (0.027%%) / 6,813 (0.050%%) / 6,822 (0.027%%): got %s %s' % (t['add'], pa),
      t['add'] == [6822, 6813, 6822] and pa == ['0.027%', '0.050%', '0.027%'] and '| Additional | 6,822 (0.027%) | 6,813 (0.050%) | 6,822 (0.027%) |' in H)
check('both catch-all and additional 9 / 6 / 9', t['bothca'] == [9, 6, 9] and '| Both catch-all and additional | 9 | 6 | 9 |' in H)
pu = ['%.2f%%' % (100.0 * t['union'][i] / tot[g]) for i, g in enumerate(G)]
check('catch-all or additional 19,324,866 (76.26%%) / 11,325,227 (82.99%%) / 19,405,617 (76.19%%): got %s %s' % (t['union'], pu),
      t['union'] == [19324866, 11325227, 19405617] and pu == ['76.26%', '82.99%', '76.19%']
      and '| **Catch-all or additional** | **19,324,866 (76.26%)** | **11,325,227 (82.99%)** | **19,405,617 (76.19%)** |' in H)
rest = tot['Detected'] - t['union'][0]
check('named primary category and no additional, detected: 6,014,948 = 23.74%%', rest == 6014948 and '%.2f%%' % (100.0 * rest / tot['Detected']) == '23.74%'
      and '6,014,948 ÷ 25,339,814 = 23.74%' in H)
check('headline sentence: 19,316,591 of 25,339,814 (76.23%)', '19,316,591 of 25,339,814 statements reporting automated detection (76.23%)' in H)
check('A13 kill condition (most detected rows have an additional category or sit in the two catch-all codes) holds for this day',
      2 * t['union'][0] > tot['Detected'])
allf = sum(v for k, v in A.items() if k[3])
print('     non-empty additional lists over all filings:', allf, '| blank + empty + non-empty =', addst['blank'] + addst['empty list'] + allf)

print('BY VOLUME CLASS of the filer\x27s detected statements on the day (no names):')
print('     filers with at least one detected statement:', J['filers_with_a_detected_statement'], '| field platform_name present:', J['has_platform_name'])
sd = sc = 0
for c in J['by_class']:
    sd += c['detected']
    sc += c['catch_all']
    print('     %-12s filers %4d | with a catch-all majority %4d | detected %10s | catch-all share %6.2f%%' % (
        c['class'], c['filers'], c['filers_with_catch_all_majority'], format(c['detected'], ','),
        100.0 * c['catch_all'] / c['detected'] if c['detected'] else 0.0))
check('class totals add up to the detected group and to the two catch-all codes', sd == tot['Detected'] and sc == t['other'][0] + t['notspec'][0])
nf = sum(c['filers'] for c in J['by_class'])
nm = sum(c['filers_with_catch_all_majority'] for c in J['by_class'])
check('every filer with a detected statement is in one class', nf == J['filers_with_a_detected_statement'])
top = J['by_class'][0]
print('     filers with a catch-all majority among their own detected statements: %d of %d (%.1f%%)' % (nm, nf, 100.0 * nm / nf))
print('     the %d filers of the class \x22%s\x22 filed %.2f%% of the detected statements' % (top['filers'], top['class'], 100.0 * top['detected'] / sd))
low = J['by_class'][2:]
print('     the three classes under 100k pooled: catch-all share %.2f%% of %s detected statements, %d filers' % (
    100.0 * sum(c['catch_all'] for c in low) / sum(c['detected'] for c in low), format(sum(c['detected'] for c in low), ','),
    sum(c['filers'] for c in low)))
print('RESULT:', 'ALL FIGURES REPRODUCED' if ok else 'MISMATCH')
sys.exit(0 if ok else 1)
