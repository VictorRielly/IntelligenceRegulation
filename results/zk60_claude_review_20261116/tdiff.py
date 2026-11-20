#!/usr/bin/env python3
"""Token-level diff of one or more binder types between two theorems, or print a full binder type.
Usage:
  tdiff.py FILE1 NAME1 FILE2 NAME2 binder [binder2 ...]   (binder may be old=new to compare renamed)
  tdiff.py --full FILE NAME binder
"""
import difflib
import re
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from binders import load  # noqa: E402

TOK = re.compile(r'\s+|[()\[\]{},]|[^\s()\[\]{},]+')


def toks(s):
    return [t for t in TOK.findall(s) if not t.isspace()]


def get(d, n):
    for b in d['binders']:
        if b['name'] == n:
            return b['type']
    if n == 'CONCL':
        return d['concl']
    raise SystemExit('no binder %s' % n)


if sys.argv[1] == '--full':
    d = load(sys.argv[2], sys.argv[3])
    for n in sys.argv[4:]:
        print('==', n)
        print(get(d, n))
    sys.exit()

a = load(sys.argv[1], sys.argv[2])
b = load(sys.argv[3], sys.argv[4])
for spec in sys.argv[5:]:
    on, _, nn = spec.partition('=')
    nn = nn or on
    ta, tb = toks(get(a, on)), toks(get(b, nn))
    print('==', spec)
    sm = difflib.SequenceMatcher(a=ta, b=tb, autojunk=False)
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op == 'equal':
            continue
        ctx = ' '.join(ta[max(0, i1 - 8):i1])
        print('  %s @..%s..: OLD[%s] NEW[%s]' % (op, ctx[-120:], ' '.join(ta[i1:i2])[:600], ' '.join(tb[j1:j2])[:600]))
