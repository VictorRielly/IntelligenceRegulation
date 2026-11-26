"""Triage of Astra's A31 handoff: derive every counted figure of the handoff from (a) the JSON printed by the handoff's
own program in my re-run and (b) my second count, and say which figures are found in the handoff's text.
Usage: python3 -I a31_compare.py RECOUNT.json SECOND.json HANDOFF.md. Prints; exits non-zero on any mismatch."""
import json
import sys

A = json.load(open(sys.argv[1]))
J = json.load(open(sys.argv[2]))
H = open(sys.argv[3], encoding='utf-8').read()
ok = True


def check(label, cond):
    global ok
    print(('ok   ' if cond else 'FAIL ') + label)
    ok = ok and bool(cond)


T = 'CONTENT_TYPE_'
sets = J['by_content_type_set']


def tot(pred, key='statements'):
    return sum(e[key] for e in sets if pred(set(e['content_type'])))


mine = {
    'all': tot(lambda s: True),
    'text': tot(lambda s: T + 'TEXT' in s),
    'text alone': tot(lambda s: s == {T + 'TEXT'}),
    'text and product': tot(lambda s: {T + 'TEXT', T + 'PRODUCT'} <= s),
    'text and image': tot(lambda s: {T + 'TEXT', T + 'IMAGE'} <= s),
    'text and other': tot(lambda s: {T + 'TEXT', T + 'OTHER'} <= s),
    'text and descriptor': tot(lambda s: T + 'TEXT' in s, 'with_description'),
}
c = A['counts']
check('rows %s in both counts and in the handoff' % format(c['all'], ','), c['all'] == mine['all'] == J['rows'] == 30120164 and '**30,120,164**' in H)
check('the seven counts of the handoff program equal my second count: %s' % {k: c.get(k, 0) for k in mine}, all(c.get(k, 0) == v for k, v in mine.items()))
check('text-tagged 1,266,513 = 4.205%% of all', c['text'] == 1266513 and '%.3f%%' % (100.0 * c['text'] / c['all']) == '4.205%' and '**1,266,513 (4.205%)**' in H)
check('text alone 1,185,967 = 93.64%', c['text alone'] == 1185967 and '%.2f%%' % (100.0 * c['text alone'] / c['text']) == '93.64%'
      and '| Text as the sole media type | 1,185,967 | 93.64% |' in H)
check('text and image 80,341 = 6.34%', c['text and image'] == 80341 and '%.2f%%' % (100.0 * c['text and image'] / c['text']) == '6.34%'
      and '| Text and image | 80,341 | 6.34% |' in H)
check('text and product 0', c.get('text and product', 0) == 0 and '| Text and product | 0 | 0.00% |' in H)
check('text and other 2,614 = 0.21%, each with a description', c['text and other'] == 2614 == c['text and descriptor']
      and '%.2f%%' % (100.0 * c['text and other'] / c['text']) == '0.21%' and '| Text and other, with a subtype description | 2,614 | 0.21% |' in H
      and 'Only 2,614 text-tagged filings supplied a description' in H)
d = A['descriptors']
check('exact description matches equal in both counts: %s' % d, d == J['exact_description_matches'])
check('posts 302 and comments 625 outside the text tag, none inside', d['posts'] == [0, 302] and d['comments'] == [0, 625] and '**302**' in H and '**625**' in H)
check('no exact match for messages, reviews or listing descriptions in either set',
      d['messages'] == d['reviews'] == d['listing descriptions'] == [0, 0]
      and 'No exact descriptor matched a message, review or listing-description term in either set' in H)
m = A['text descriptor mentions']
check('no text-tagged description mentions any of the five forms: %s' % m, all(v == 0 for v in m.values()) and m == J['text_tagged_description_mentions']
      and 'None of these descriptions mentioned the five forms' in H)
check('the day\x27s text share lies inside the monthly range 3.03 to 6.82 percent of A30', 3.03 <= 100.0 * c['text'] / c['all'] <= 6.82 and '3.03–6.82%' in H)
print('     media-type sets among text-tagged statements (my count; sets with fewer than 1 in 10,000 pooled):')
small = 0
for e in sets:
    s = set(e['content_type'])
    if T + 'TEXT' in s:
        if e['statements'] * 10000 >= c['text']:
            print('       %-58s %10s  %6.2f%%' % (' + '.join(x[len(T):].lower() for x in e['content_type']), format(e['statements'], ','), 100.0 * e['statements'] / c['text']))
        else:
            small += e['statements']
print('       %-58s %10s' % ('all smaller sets together', format(small, ',')))
print('     distinct descriptions among text-tagged statements:', J['distinct_descriptions_among_text_tagged'])
print('RESULT:', 'ALL FIGURES REPRODUCED' if ok else 'MISMATCH')
sys.exit(0 if ok else 1)
