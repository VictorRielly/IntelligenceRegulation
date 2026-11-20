#!/usr/bin/env python3
"""For each theorem in a list, print which productionReady / top theorems its body references,
and the body length. Usage: calls.py FILE NAME..."""
import re
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from binders import load  # noqa: E402

path = sys.argv[1]
for name in sys.argv[2:]:
    d = load(path, name)
    body = d['body']
    refs = sorted(set(re.findall(r'[A-Za-z_.]*productionReady[A-Za-z_0-9.]*', body)))
    print('==', name, 'line', d['line'], 'binders', len(d['binders']), 'bodylen', len(body))
    print('   refs:', refs)
    print('   head:', ' '.join(body.split())[:400])
