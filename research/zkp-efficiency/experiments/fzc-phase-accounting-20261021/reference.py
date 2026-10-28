"""Separate integer-tick replay; imports no candidate or its helpers.

For deliberately small synthetic traces only. An independent walk finds the
deepest scope active in each unit interval, then counts that unit once.
"""
from collections import Counter

def replay(spans):
    nodes={s['id']:s for s in spans}
    def depth(s):
        n=0
        while s['parent'] is not None:
            n+=1; s=nodes[s['parent']]
        return n
    depths={s['id']:depth(s) for s in spans}
    out=Counter({s['id']:0 for s in spans})
    for thread in {s['thread'] for s in spans}:
        group=[s for s in spans if s['thread']==thread]
        lo=min(s['start_ns'] for s in group); hi=max(s['end_ns'] for s in group)
        for tick in range(lo,hi):
            live=[s for s in group if s['start_ns']<=tick<s['end_ns']]
            winner=max(live,key=lambda s:depths[s['id']])
            out[winner['id']]+=1
    return dict(out)

def path_enumeration(tasks, remove=()):
    nodes={t['id']:t for t in tasks}
    def walk(n):
        t=nodes[n]
        return (0 if t['role'] in remove else t['duration'])+max((walk(p) for p in t['deps']),default=0)
    return max((walk(n) for n in nodes),default=0)

def selected_ticks(spans, selected):
    selected=[s for s in spans if s['id'] in selected]
    ticks=set()
    for s in selected:
        for tick in range(s['start_ns'],s['end_ns']):
            ticks.add((s['thread'],tick))
    return len(ticks)
