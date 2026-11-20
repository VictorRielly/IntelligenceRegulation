#!/usr/bin/env python3
"""Co-coordinator (Claude), 2026-11-16: wake the Claude session when the other coordinator posts.

Polls the two coordination files for text appended after start and exits, printing the new entries.

Immediate wake: an entry by the Antigravity coordinator, or one by Sol or Astra that names Claude or the
co-coordinator together with a question or a request.
Batched wake: an entry that only announces a package "ready for cross-review". These arrive every twenty minutes or so
and each wake costs the session tokens, so they are collected and reported together BATCH_MIN minutes after the
first one (or at once with any immediate entry).

Read-only. Exits 0 with the matching entries; exits 3 after MAX_HOURS with nothing matched (so silence is reported,
not assumed).

usage: watch_coordination.py [max_hours] [batch_minutes]
"""
import os
import re
import sys
import time

FILES = [
    '/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/RECOVERY_COORDINATION.md',
    '/Users/victorrielly/IntelligenceRegulation/docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md',
]
MAX_HOURS = float(sys.argv[1]) if len(sys.argv) > 1 else 6.0
BATCH_MIN = float(sys.argv[2]) if len(sys.argv) > 2 else 90.0
COORD = re.compile(r'^\s*(#+\s*)?Coordinator\b(?!.*\(Claude\))')
OWN = re.compile(r'^\s*(#+\s*)?(Claude\b|Co-coordinator \(Claude\))')
ASK = r'(\?|please|request|object|disagree|blocked)'
NOW = re.compile(r'((\bClaude\b|co-?coordinator).*' + ASK + r')', re.I | re.S)
LATER = re.compile(r'\bClaude\b|co-?coordinator|ready for cross-review', re.I)

HDR = re.compile(r'^\s*(#+\s*)?[A-Z][A-Za-z\-]{1,20}(\s+[a-z\-]+)?(\s*\([^)]{0,40}\))?\s+20\d\d-\d\d-\d\dT')
HDR2 = re.compile(r'^\s*#+\s.{0,100}20\d\d-\d\d-\d\dT')
# 2026-11-20: Sol's form "Sol — <title> (<ISO time>)." matched neither header pattern, so four entries of
# 18:32Z and 18:43Z were taken for the tail of the preceding Claude entry and dropped; found by hand at 22:17Z.
# Any first line that opens with another author's name and carries a time is that author's header.
HDR3 = re.compile(r'^\s*(#+\s*)?(\[[^\]]{0,40}\]\s*)?(Sol|Astra|Antigravity|Gemini)\b.{0,200}20\d\d-\d\d-\d\dT')
# Files where every appended paragraph is someone else's (Astra answers in its own progress file).
FILES_ANY = [
    '/Users/victorrielly/IntelligenceRegulation/results/zk60_astra_20261026/PROGRESS.md',
]
SA_NOW = re.compile(r'\bA3\d\b|\bpins?\b|cross-?review|coordinator|\?', re.I)
own = {}

pos = {f: os.path.getsize(f) for f in FILES + FILES_ANY}
end = time.time() + MAX_HOURS * 3600
batched = []
first_batched = None
agy_batched = None
AGY_BATCH_MIN = 45.0
AGY_NOW = re.compile(r'\?|URGENT|sign-?off|say which|please|question|object|blocked|disagree|your ruling', re.I)
while time.time() < end:
    time.sleep(20)
    hits = []
    for f in FILES_ANY:
        try:
            size = os.path.getsize(f)
        except OSError:
            continue
        if size > pos[f]:
            with open(f, 'rb') as fh:
                fh.seek(pos[f])
                new = fh.read().decode('utf-8', 'replace').strip()
            if new:
                batched.append('[%s]\n%s' % (os.path.basename(f), new[:3000]))
                if first_batched is None:
                    first_batched = time.time()
        pos[f] = size
    for f in FILES:
        try:
            size = os.path.getsize(f)
        except OSError:
            continue
        if size <= pos[f]:
            pos[f] = min(pos[f], size)
            continue
        with open(f, 'rb') as fh:
            fh.seek(pos[f])
            new = fh.read().decode('utf-8', 'replace')
        pos[f] = size
        for para in re.split(r'\n\s*\n', new):
            first = para.strip().split('\n', 1)[0] if para.strip() else ''
            if not first:
                continue
            # An entry opens with "<name> <ISO time>:"; its later paragraphs carry no signature and belong to the
            # same author, so remember who is writing (a Claude entry that mentions Antigravity is still Claude's).
            if HDR.match(first):
                own[f] = bool(OWN.match(first))
            elif HDR3.match(first):
                own[f] = False
            elif HDR2.match(first):
                # "### [<ISO time>] <name> ..." (the form Antigravity used on 2026-11-17 12:29Z; the first
                # version of this script did not see it as a header, kept the previous author, and slept
                # through the entry).
                own[f] = bool(re.search(r'\bClaude\b', first[:80])) and 'Antigravity' not in first[:80]
            if own.get(f) or OWN.match(first):
                continue
            entry = '[%s]\n%s' % (os.path.basename(f), para.strip()[:6000])
            head = para[:1500]
            if re.match(r'\s*(Sol|Astra)\s+\S+:\s*Acknowledg', first):
                batched.append(entry)  # a plain acknowledgement needs no reply
                if first_batched is None:
                    first_batched = time.time()
            elif COORD.match(first) or 'Antigravity' in first[:80]:
                # 2026-11-20: back online, Antigravity posts a status entry every ten to fifteen minutes and
                # each wake costs the session tokens. Wake at once only when the entry asks for something;
                # a status-only entry is reported within AGY_BATCH_MIN minutes.
                if AGY_NOW.search(para):
                    hits.append(entry)
                else:
                    batched.append(entry)
                    if first_batched is None:
                        first_batched = time.time()
                    if agy_batched is None:
                        agy_batched = time.time()
            elif NOW.search(head):
                hits.append(entry)
            elif re.match(r'\s*(Sol|Astra)\b', first) and SA_NOW.search(head):
                # 2026-11-17: Sol's and Astra's answers to the pin question, and Sol's review request, named
                # neither "Claude" nor "co-coordinator" and were missed for ten minutes.
                hits.append(entry)
            elif LATER.search(head) or not own.get(f, True):
                # 2026-11-20: an entry by another author that matches none of the patterns above is still
                # reported, batched; silence about it cost three and a half hours.
                batched.append(entry)
                if first_batched is None:
                    first_batched = time.time()
    due = first_batched is not None and time.time() - first_batched >= BATCH_MIN * 60
    due = due or (agy_batched is not None and time.time() - agy_batched >= AGY_BATCH_MIN * 60)
    if hits or due:
        print('\n\n'.join(batched + hits))
        sys.exit(0)
if batched:
    print('\n\n'.join(batched))
    sys.exit(0)
print('no entry from the Antigravity coordinator and none addressed to Claude in %.1f hours' % MAX_HOURS)
sys.exit(3)
