#!/usr/bin/env python3
"""Parse Lean 4 declaration binders (read-only review helper).

Usage:
  binders.py show FILE NAME [width]        -> one binder per line + conclusion
  binders.py diff FILE1 NAME1 FILE2 NAME2  -> removed / added / changed / kept
  binders.py body FILE NAME [maxchars]     -> proof body text after ':='
  binders.py json FILE NAME                -> json dump of binders
"""
import json
import re
import sys

OPEN = {'(': ')', '{': '}', '[': ']', '⦃': '⦄'}
CLOSE = set(OPEN.values())
DECL_RE = re.compile(r'^(?:@\[[^\]]*\]\s*)?(?:private |protected |noncomputable )*(theorem|lemma|def|abbrev|structure|instance)\s+(\S+)', re.M)


def find_decl(text, name):
    for m in DECL_RE.finditer(text):
        n = m.group(2)
        if n == name or n.endswith('.' + name):
            return m
    raise SystemExit('not found: %s' % name)


def parse(text, name):
    m = find_decl(text, name)
    i = m.end()
    binders = []
    n = len(text)
    concl = None
    body_start = None
    while i < n:
        c = text[i]
        if c in OPEN:
            depth = 0
            j = i
            stack = []
            while j < n:
                ch = text[j]
                if ch in OPEN:
                    stack.append(OPEN[ch])
                elif ch in CLOSE:
                    if stack and stack[-1] == ch:
                        stack.pop()
                    if not stack:
                        break
                j += 1
            binders.append((c, text[i + 1:j]))
            i = j + 1
            continue
        if c == ':' and text[i:i + 2] != ':=':
            # conclusion until top-level ':='
            j = i + 1
            stack = []
            while j < n:
                ch = text[j]
                if ch in OPEN:
                    stack.append(OPEN[ch])
                elif ch in CLOSE and stack:
                    stack.pop()
                elif not stack and text[j:j + 2] == ':=':
                    break
                j += 1
            concl = text[i + 1:j]
            body_start = j + 2
            break
        if text[i:i + 2] == ':=':
            body_start = i + 2
            break
        i += 1
    # body ends at next declaration
    nm = DECL_RE.search(text, body_start or i)
    body_end = nm.start() if nm else n
    out = []
    for kind, inner in binders:
        # split names : type at first top-level ':'
        stack = []
        k = None
        for idx, ch in enumerate(inner):
            if ch in OPEN:
                stack.append(ch)
            elif ch in CLOSE and stack:
                stack.pop()
            elif ch == ':' and not stack and inner[idx:idx + 2] != ':=':
                k = idx
                break
        if k is None:
            names = ['_inst']
            ty = inner
        else:
            names = inner[:k].split()
            ty = inner[k + 1:]
        ty = ' '.join(ty.split())
        for nm_ in names:
            out.append({'kind': kind, 'name': nm_, 'type': ty})
    return {
        'binders': out,
        'concl': ' '.join((concl or '').split()),
        'body': text[body_start:body_end] if body_start else '',
        'line': text[:m.start()].count('\n') + 1,
    }


def load(path, name):
    with open(path, encoding='utf-8') as f:
        return parse(f.read(), name)


def trunc(s, w):
    return s if len(s) <= w else s[:w] + ' ...[+%d]' % (len(s) - w)


def main():
    cmd = sys.argv[1]
    if cmd == 'show':
        d = load(sys.argv[2], sys.argv[3])
        w = int(sys.argv[4]) if len(sys.argv) > 4 else 200
        print('# line', d['line'], 'binders', len(d['binders']))
        for b in d['binders']:
            print('%s%s : %s' % (b['kind'], b['name'], trunc(b['type'], w)))
        print('CONCL:', trunc(d['concl'], 4 * w))
    elif cmd == 'json':
        d = load(sys.argv[2], sys.argv[3])
        print(json.dumps(d, ensure_ascii=False, indent=1))
    elif cmd == 'body':
        d = load(sys.argv[2], sys.argv[3])
        w = int(sys.argv[4]) if len(sys.argv) > 4 else 3000
        print(trunc(d['body'], w))
    elif cmd == 'diff':
        a = load(sys.argv[2], sys.argv[3])
        b = load(sys.argv[4], sys.argv[5])
        w = int(sys.argv[6]) if len(sys.argv) > 6 else 160
        da = {x['name']: x['type'] for x in a['binders']}
        db = {x['name']: x['type'] for x in b['binders']}
        print('# OLD %s (%d)  NEW %s (%d)' % (sys.argv[3], len(da), sys.argv[5], len(db)))
        for k in da:
            if k not in db:
                print('REMOVED %s : %s' % (k, trunc(da[k], w)))
        for k in db:
            if k not in da:
                print('ADDED   %s : %s' % (k, trunc(db[k], w)))
        for k in da:
            if k in db and da[k] != db[k]:
                print('CHANGED %s\n   old: %s\n   new: %s' % (k, trunc(da[k], w), trunc(db[k], w)))
        kept = [k for k in da if k in db and da[k] == db[k]]
        print('KEPT (%d): %s' % (len(kept), ' '.join(kept)))
        print('CONCL same:', a['concl'] == b['concl'])
        if a['concl'] != b['concl']:
            print('  old:', trunc(a['concl'], 600))
            print('  new:', trunc(b['concl'], 600))


if __name__ == '__main__':
    main()
