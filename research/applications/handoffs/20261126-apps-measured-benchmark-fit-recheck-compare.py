"""Triage of applications handoff A33: derive every counted figure of the handoff from the coordinator's independent
count and look for it in the handoff. Usage: python3 -I this.py RECHECK.json HANDOFF.md. Exits non-zero on a mismatch."""
import json
import sys

J = json.load(open(sys.argv[1]))
H = open(sys.argv[2], encoding='utf-8').read()
A, B = J['moderation prompts'], J['chatbot user messages']
ok = True


def check(label, cond):
    global ok
    print(('ok   ' if cond else 'FAIL ') + label)
    ok = ok and bool(cond)


def pct(a, b):
    return '%.2f%%' % (100.0 * a / b)


def n(x):
    return format(x, ',')


def row(label, f, with_pct=True):
    a, b = f(A), f(B)
    ra, rb = A['totals']['rows'], B['totals']['rows']
    cell = (lambda v, r: '%s (%s)' % (n(v), pct(v, r))) if with_pct else (lambda v, r: n(v))
    line = '| %s | %s | %s |' % (label, cell(a, ra), cell(b, rb))
    check(line, line in H)


check('rows 1,680 and 5,083; each set adds up; no blank row', (A['totals']['rows'], B['totals']['rows']) == (1680, 5083)
      and all(s['totals']['fits'] + s['totals']['characters only'] + s['totals']['tokens only'] + s['totals']['both limits'] == s['totals']['rows']
              and 'blank' not in s['totals'] for s in (A, B)) and '| Blank after trimming | 0 | 0 |' in H)
row('Fits 1,000 trimmed characters and 336 content tokens', lambda s: s['totals']['fits'])
row('Fits one chunk in every policy (≤49 tokens, three proofs)', lambda s: s['totals']['actual: one chunk for all three'])
row('Fits a single chunk for each of the two 55-token policies', lambda s: s['totals']['actual: one chunk for each 55-token policy'])
row('Exceeds character limit only', lambda s: s['totals']['characters only'], False)
row('Exceeds token limit only', lambda s: s['totals']['tokens only'], False)
row('Exceeds both limits', lambda s: s['totals']['both limits'], False)
check('headline: 1,348 of 1,680 (80.24%) and 4,888 of 5,083 (96.16%)',
      'Of 1,680 OpenAI moderation prompts, 1,348 fit the installed app (80.24%). Of 5,083 ToxicChat user messages, 4,888 fit (96.16%).' in H
      and (A['accepted'], B['accepted']) == (1348, 4888) and (pct(1348, 1680), pct(4888, 5083)) == ('80.24%', '96.16%'))
line = '| Total planned proofs | %s | %s |' % (n(A['planned_proofs']), n(B['planned_proofs']))
check(line, line in H)
line = '| Mean (total proofs / accepted posts) | %.2f | %.2f |' % (A['planned_proofs'] / A['accepted'], B['planned_proofs'] / B['accepted'])
check(line, line in H)
line = '| Median / 95th percentile, nearest rank | %d / %d | %d / %d |' % (A['median_nearest_rank'], A['p95_nearest_rank'], B['median_nearest_rank'], B['p95_nearest_rank'])
check(line, line in H)
check('the histogram of proofs adds up to the accepted posts and to the planned proofs in both sets',
      all(sum(s['proofs_histogram'].values()) == s['accepted'] and sum(int(k) * v for k, v in s['proofs_histogram'].items()) == s['planned_proofs'] for s in (A, B)))
check('every accepted post needs at least three proofs; the smallest count is 3 in both sets', min(int(k) for k in A['proofs_histogram']) == 3 == min(int(k) for k in B['proofs_histogram']))
E = 'length_rule_errors'
K = {'p196': 'one chunk for all three at 196 characters: promised by the length rule but not true',
     'm196': 'one chunk for all three at 196 characters: true but missed by the length rule',
     'p220': 'one chunk for each 55-token policy at 220 characters: promised by the length rule but not true',
     'm220': 'one chunk for each 55-token policy at 220 characters: true but missed by the length rule',
     'w': 'whole at 1000 characters: promised by the length rule but not true'}
check('196-character rule: promises 22 and 24 that need more; misses 39 and 83', (A[E][K['p196']], B[E][K['p196']], A[E][K['m196']], B[E][K['m196']]) == (22, 24, 39, 83)
      and 'would promise one chunk per policy for **22** OpenAI and **24** ToxicChat texts that actually need more. It would miss **39** and **83** genuine one-chunk fits.' in H)
check('220-character rule: 24 and 39 for the first set, 22 and 60 for the second', (A[E][K['p220']], A[E][K['m220']], B[E][K['p220']], B[E][K['m220']]) == (24, 39, 22, 60)
      and 'At 220 characters those two error counts are 24 and 39 for OpenAI, 22 and 60 for ToxicChat.' in H)
check('a 1,000-character check alone would admit four and two rows over the token limit', (A[E][K['w']], B[E][K['w']]) == (4, 2)
      and (A['totals']['tokens only'], B['totals']['tokens only']) == (4, 2) and 'would admit four and two token-overflow rows respectively' in H)
check('6,763 rows in all', A['totals']['rows'] + B['totals']['rows'] == 6763)
print('RESULT:', 'ALL FIGURES REPRODUCED' if ok else 'MISMATCH')
sys.exit(0 if ok else 1)
