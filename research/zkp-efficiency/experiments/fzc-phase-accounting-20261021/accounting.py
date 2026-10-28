"""Research-only public-metadata host interval accounting. Never a GPU timer.

Integers are nanoseconds from ONE monotonic host domain. Each thread has a
root; only direct children are subtracted. Parallel thread-wall is not elapsed
workload time. Unknown intervals remain charged to their enclosing scope.
"""
from collections import Counter, defaultdict

PHASES = frozenset('attempt constructor build module round tail finals masked_protocol poll copy sync host_alloc host_map host_zero host_free device_alloc device_free report caller cleanup driver witness serialization other'.split())
ROLES = frozenset('none round_fallback_pin round_mapped_pin tail_pin tail_device_pack device_part device_sums device_finals device_counter device_params device_src table_arena'.split())
KEYS = frozenset('id parent thread clock start_ns end_ns phase role outcome requested_bytes'.split())

def summarize(spans):
    by_id, children, roots = {}, defaultdict(list), {}
    for s in spans:
        if set(s) != KEYS:
            raise ValueError('schema fields')
        if type(s['id']) is not int or s['id'] in by_id:
            raise ValueError('duplicate/noninteger id')
        if s['parent'] is not None and type(s['parent']) is not int:
            raise ValueError('parent id')
        if type(s['thread']) is not int or s['thread'] < 0:
            raise ValueError('thread ordinal')
        if s['clock'] != 'host_monotonic_ns':
            raise ValueError('mixed/unknown clock domain')
        if any(type(s[k]) is not int for k in ['start_ns','end_ns','requested_bytes']):
            raise ValueError('noninteger clock/size')
        if min(s['start_ns'],s['requested_bytes']) < 0 or s['end_ns'] < s['start_ns']:
            raise ValueError('negative interval/size')
        if s['phase'] not in PHASES or s['role'] not in ROLES or s['outcome'] not in ['success','infrastructure_error','not_applicable']:
            raise ValueError('unknown public enum')
        by_id[s['id']] = s
    for s in spans:
        parent = s['parent']
        if parent is None:
            if s['thread'] in roots:
                raise ValueError('multiple roots per thread')
            roots[s['thread']] = s['id']
        else:
            if parent not in by_id:
                raise ValueError('orphan')
            p = by_id[parent]
            if p['thread'] != s['thread'] or not (p['start_ns'] <= s['start_ns'] <= s['end_ns'] <= p['end_ns']):
                raise ValueError('parent containment/thread')
            children[parent].append(s)
    # Explicit ancestry is needed even for zero-duration cycles.
    for s in spans:
        seen, cur = set(), s['id']
        while cur is not None:
            if cur in seen:
                raise ValueError('cycle')
            seen.add(cur)
            cur = by_id[cur]['parent']
    for group in children.values():
        positive = sorted((s for s in group if s['end_ns'] > s['start_ns']), key=lambda s:s['start_ns'])
        for a,b in zip(positive,positive[1:]):
            if a['end_ns'] > b['start_ns']:
                raise ValueError('overlapping siblings')
    inclusive, exclusive, role_events, per_thread, per_id = Counter(),Counter(),Counter(),Counter(),{}
    for s in spans:
        duration = s['end_ns'] - s['start_ns']
        own = duration - sum(x['end_ns']-x['start_ns'] for x in children[s['id']])
        if own < 0:
            raise ValueError('negative exclusive time')
        inclusive[s['phase']] += duration
        exclusive[s['phase']] += own
        per_id[s['id']] = own
        per_thread[s['thread']] += own
        if s['phase'] in ['host_alloc','device_alloc','host_map','host_free','device_free']:
            role_events[(s['phase'],s['role'],s['outcome'])] += 1
    for thread, root in roots.items():
        s=by_id[root]
        if per_thread[thread] != s['end_ns']-s['start_ns']:
            raise ValueError('unreconciled thread')
    return {'inclusive_ns':dict(inclusive),'exclusive_ns':dict(exclusive),
            'exclusive_by_id_ns':per_id,'thread_wall_ns':dict(per_thread),
            'role_events':{'/'.join(k):v for k,v in sorted(role_events.items())},
            'sum_thread_wall_ns':sum(per_thread.values()),
            'warning':'Thread-wall sums, host allocation time and device time are not end-to-end savings.'}

def critical_path(tasks, remove=()):
    """Synthetic max-plus DAG only; no claim that a native dependency graph exists."""
    finish={}
    for t in tasks:
        if t['id'] in finish or any(p not in finish for p in t['deps']):
            raise ValueError('DAG order/identity')
        finish[t['id']] = max((finish[p] for p in t['deps']),default=0)+(0 if t['role'] in remove else t['duration'])
    return max(finish.values(),default=0)

def family_thread_wall(spans, selected):
    """Union of selected scopes, including descendants exactly once per thread.

    This is interval coverage, not removable work. A host allocator wrapper can
    contain binding, zeroing or waiting that a safe pool still needs to perform.
    """
    totals=summarize(spans)
    nodes={s['id']:s for s in spans}
    selected=set(selected)
    if not selected.issubset(nodes):
        raise ValueError('unknown selected scope')
    out=0
    for s in spans:
        cur=s['id']
        while cur is not None:
            if cur in selected:
                out+=totals['exclusive_by_id_ns'][s['id']]
                break
            cur=nodes[cur]['parent']
    return out
