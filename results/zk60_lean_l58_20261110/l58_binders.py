#!/usr/bin/env python3
"""D63 lane L58 (2026-11-10): list the explicit binders of a top theorem (L50's parser) and its section's explicit
variables, and the binders gone or new against another theorem. Read-only.
usage: python3 -I l58_binders.py <file.lean> <theorem> [<file0.lean> <theorem0>]
"""
import re
import sys


def top_binders(text):
    i = text.index(" ") + 1
    i = text.index(" ", i)
    out = []
    depth = 0
    start = None
    opener = None
    pairs = {"(": ")", "{": "}", "[": "]", "⦃": "⦄"}
    closers = set(pairs.values())
    while i < len(text):
        c = text[i]
        if depth == 0 and c == ":" and text[i:i + 2] == ":=":
            break
        if depth == 0 and c == ":" and opener is None:
            break
        if c in pairs:
            if depth == 0:
                start = i
                opener = c
            depth += 1
        elif c in closers:
            depth -= 1
            if depth == 0 and opener is not None:
                inner = text[start + 1:i]
                names = inner[:inner.index(":")].split() if opener in "({" and ":" in inner else []
                out.append((opener, names))
                opener = None
        i += 1
    return out


def explicit(path, th):
    src = open(path).read()
    a = src.index("theorem %s " % th)
    b = src.index("εzkTarget :=", a)
    names = [n for (k, ns) in top_binders(src[a:b]) if k == "(" for n in ns]
    sec = src[src.rindex("section ", 0, a):a]
    svars = []
    for m in re.finditer(r"^variable (.*?)(?=^\S)", sec, re.S | re.M):
        for g in re.finditer(r"\(([^():]*?) :", m.group(1)):
            svars += g.group(1).split()
    return svars, names


sv, ex = explicit(sys.argv[1], sys.argv[2])
print("section variables (explicit):", " ".join(sv))
print("explicit binders (%d):" % len(ex), " ".join(ex))
if len(sys.argv) > 4:
    sv0, ex0 = explicit(sys.argv[3], sys.argv[4])
    print("gone:", " ".join(n for n in sv0 + ex0 if n not in sv + ex))
    print("new:", " ".join(n for n in sv + ex if n not in sv0 + ex0))
