#!/usr/bin/env python3
"""Read one run of run_v1t.py. Standard library only.

usage: read_v1t.py structure <label>     the shape of the output only: no time is read or printed
       read_v1t.py full <label>          the reading: per block, the median over the tables with least and most

A row's time is its ns-a-unit column times its size (the seconds column is printed to the millisecond only); the
reader checks that the two agree to 0.51 ms on every row it uses.
"""
import json
import re
import statistics
import sys
from pathlib import Path

RAW = Path(__file__).resolve().parent / 'raw'
PROFILE = 'private-classify-run-shieldstral-3b-t128-w16r2-dev-only/2'
PUB = (0, 1, 4, 14, 15, 16, 17, 18, 19)
FOLD = (5, 6, 7, 10, 11, 12, 13)
EXPECT = {0: 3145728, 1: 3145728, 4: 4194304, 14: 38797312, 15: 15728640, 16: 3932160, 17: 19922944, 18: 79691776,
          19: 1900544}
FOLD_ENTRIES = 243269632
BAND = (85.0, 197.0)


def tables(label):
    T, cur, cli, events = [], None, [], []
    for l in (RAW / (label + '.log')).read_text(errors='replace').split('\n'):
        if l.startswith('PB-CLI verify | '):
            c = [x.strip() for x in l.split('|')]
            cli.append((c[1], c[2]))
        elif l.lstrip().startswith('{"event"'):
            events.append(json.loads(l))
        elif l.startswith('PB-TIMING verify [') and 'phases, wall' in l:
            m = re.match(r'PB-TIMING verify \[([^\]]+)\] (\d+) phases, wall ([0-9.]+) s', l)
            cur = {'profile': m.group(1), 'phases': int(m.group(2)), 'wall': float(m.group(3)), 'rows': [], 'unacc': None}
            T.append(cur)
        elif cur is not None and l.startswith('PB-TIMING verify | '):
            c = [x.strip() for x in l.split('|')]
            if c[1].startswith('unaccounted'):
                cur['unacc'] = float(c[4].rstrip('%'))
            elif len(c) >= 9 and re.fullmatch(r'[0-9.]+', c[3]) and c[1] not in ('SUM OF PHASES', 'WALL CLOCK OF THE CALL'):
                size = int(c[5].split()[0])
                cur['rows'].append({'name': c[1], 'sec': float(c[3]), 'size': size, 'ns': float(c[8]),
                                    't': float(c[8]) * size / 1e9})
    return T, cli, events


def slot(r):
    m = re.match(r'slot (\d\d) ', r['name'])
    return int(m.group(1)) if m else None


def structure(label):
    T, cli, events = tables(label)
    res = json.loads((RAW / (label + '.results.json')).read_text())
    guard = json.loads((RAW / (label + '.guard.json')).read_text())
    sizes = [{slot(r): r['size'] for r in t['rows'] if slot(r) in PUB} for t in T]
    facts = {
        'guard exit 0, not killed by the guard': res['guard_exit'] == 0 and guard.get('guard_killed') is None,
        'one classified event, no refusal': [e.get('event') for e in events] == ['classified'],
        '26 tables': len(T) == 26,
        'every header names the W16R2 development run profile': all(t['profile'].endswith(PROFILE) for t in T),
        'every table has 30 rows and says 30 phases': all(len(t['rows']) == 30 and t['phases'] == 30 for t in T),
        '23 slot rows in every table': all(sorted(slot(r) for r in t['rows'] if slot(r) is not None) == list(range(23)) for t in T),
        'the nine public-table slots print the expected sizes in every table': all(s == EXPECT for s in sizes),
        'median unaccounted share at most 0.5%': statistics.median(t['unacc'] for t in T) <= 0.5,
        'export and models listings unchanged': all(res['listing_unchanged'].values()),
        'nothing written under the scratch owner-private directory': res['files_under_scratch_owner_private'] == [],
        'ns-a-unit times size agrees with the seconds column to 0.51 ms on every row': all(abs(r['t'] - r['sec']) < 0.00051 for t in T for r in t['rows']),
    }
    return T, cli, events, res, guard, facts, (sizes[0] if sizes else {})


def main():
    mode, label = sys.argv[1], sys.argv[2]
    T, cli, events, res, guard, facts, size0 = structure(label)
    print('label %s | arm %s | run %s | policy %s' % (label, res['arm'], res['run'], res['policy']))
    for k, v in facts.items():
        print(('ok   ' if v else 'FAIL ') + k)
    print('sizes printed for slots 0, 1, 4, 14 to 19 in the first table:', size0)
    print('row names of the first table that are not slots:', [r['name'] for r in T[0]['rows'] if slot(r) is None] if T else [])
    print('PB-CLI lines:', [c[0] for c in cli])
    void = not all(facts.values())
    print('STRUCTURE: ' + ('VOID' if void else 'sound'))
    if mode == 'structure':
        return 1 if void else 0
    assert mode == 'full'

    def stat(f):
        xs = [f(t) * 1000 for t in T]
        return statistics.median(xs), min(xs), max(xs)

    def rows(t, pred):
        return sum(r['t'] for r in t['rows'] if pred(r))

    groups = [
        ('S_pub: slots 0, 1, 4, 14 to 19', lambda t: rows(t, lambda r: slot(r) in PUB)),
        ('F: slots 5 to 7, 10 to 13 (weight folds)', lambda t: rows(t, lambda r: slot(r) in FOLD)),
        ('the other seven slots', lambda t: rows(t, lambda r: slot(r) is not None and slot(r) not in PUB + FOLD)),
        ('setup: transcript header + the A and H roots', lambda t: rows(t, lambda r: r['name'].startswith('transcript header'))),
        ('verify M', lambda t: rows(t, lambda r: r['name'].startswith('verify M'))),
        ('verify A', lambda t: rows(t, lambda r: r['name'].startswith('verify A'))),
        ('verify H', lambda t: rows(t, lambda r: r['name'].startswith('verify H'))),
        ('T: setup + 23 slots + M + A + H', lambda t: rows(t, lambda r: slot(r) is not None or r['name'].startswith(('transcript header', 'verify M', 'verify A', 'verify H')))),
        ('boundary opening', lambda t: rows(t, lambda r: r['name'].startswith('verify boundary'))),
        ('load: block load + statement check', lambda t: rows(t, lambda r: r['name'].startswith('run: block load'))),
        ('frame: decode', lambda t: rows(t, lambda r: r['name'].startswith('frame:'))),
        ('wall of a table', lambda t: t['wall']),
    ]
    print('\nper block, ms: median (least to most) over %d tables' % len(T))
    out = {}
    for name, f in groups:
        med, lo, hi = stat(f)
        out[name] = (med, lo, hi)
        print('  %-48s %8.1f  (%.1f to %.1f)' % (name, med, lo, hi))
    for s in PUB:
        med, lo, hi = stat(lambda t, s=s: rows(t, lambda r: slot(r) == s))
        print('    slot %02d %8.2f  (%.2f to %.2f)' % (s, med, lo, hi))
    f_med = out['F: slots 5 to 7, 10 to 13 (weight folds)'][0]
    print('  F as ns a padded weight entry (%d entries a block): %.3f' % (FOLD_ENTRIES, f_med * 1e6 / FOLD_ENTRIES))
    for c in cli:
        print('  PB-CLI | %s | %s' % c)
    print('  guard: the verifier process ran %.1f s, peak memory %s GiB' % (guard['child_wall_seconds'], guard['peak_rss_gib']))
    s_pub = out['S_pub: slots 0, 1, 4, 14 to 19'][0]
    if void:
        verdict = 'VOID (a structure check failed): no reading'
    elif res['arm'] != 't1':
        verdict = 'NOT A ONE-THREAD RUN: no reading against the band'
    elif s_pub < BAND[0]:
        verdict = 'BELOW THE BAND: the estimate of the replay is too high even at its lowest rates (median S_pub %.1f ms < %.0f)' % (s_pub, BAND[0])
    elif s_pub <= BAND[1]:
        verdict = 'INSIDE THE BAND: consistent with the estimate; an upper bound on the replay only (median S_pub %.1f ms in %.0f to %.0f)' % (s_pub, BAND[0], BAND[1])
    else:
        verdict = 'ABOVE THE BAND: not decisive for the replay, the rows hold other work (median S_pub %.1f ms > %.0f)' % (s_pub, BAND[1])
    print('READING: ' + verdict)
    return 1 if void else 0


if __name__ == '__main__':
    sys.exit(main())
