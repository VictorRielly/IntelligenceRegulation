"""Pass-6 B: match package-385 guard stages against results/zk60_resource_guard/history.jsonl (read-only)."""
import json, glob, os
R = '/Users/victorrielly/IntelligenceRegulation'
B = R + '/results/zk60_sol_20261105_w16r3/b3'
d = json.load(open(B + '/D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'))
rows = {}
hist = R + '/results/zk60_resource_guard/history.jsonl'
n = 0
for line in open(hist):
    n += 1
    try: r = json.loads(line)
    except Exception: continue
    rid = r.get('run_id') or r.get('id')
    if rid: rows.setdefault(rid, []).append(r)
print('history rows', n, 'distinct ids', len(rows))
want = dict((k, v['run_id']) for k, v in d['successful_guarded_stages'].items())
want['FAILED-identity'] = d['historical_failed_identity_guard']['run_id']
want['FAILED-packaging'] = d['historical_packaging_failure_guard']['run_id']
for name, rid in want.items():
    rs = rows.get(rid)
    if not rs:
        print(name, rid, 'NOT IN HISTORY'); continue
    r = rs[-1]
    keys = ('label', 'tag', 'class', 'exit', 'child_rc', 'child_wall_seconds', 'peak_rss_gib', 'started_utc', 'finished_utc', 'cmd')
    print(name, rid, len(rs), 'rows;', {k: (str(r.get(k))[:140]) for k in keys if k in r})
