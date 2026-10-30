"""Token round 18: the pass criterion of A5_PATCH_REVIEW.md section 4.4 step 10 on the fail control's log.

usage: fail_check.py FAIL.log FAIL.guard.json EQ_FAIL_DIR OWN_FAIL_OWNERS_DIR OUT.json
Pass: the child exits 1; the log has job 0's `proved`, then `removed` lines (job 1's own and the batch's for job 0's
three directories), then `refused`, then the fail-closed `app-outcome` line, and no `batch-proved`; nothing is left in
either directory (the review's `find ... -mindepth 1 -maxdepth 1 | wc -l` = 0).
"""
import json, os, sys
log, gj, eq, own, out = sys.argv[1:6]
ev = []
for line in open(log):
    line = line.strip()
    if line.startswith('{"event"'):
        try:
            ev.append(json.loads(line))
        except ValueError:
            ev.append({'event': 'UNPARSED', 'line': line[:200]})
kinds = [e.get('event') for e in ev]
g = json.load(open(gj))
left = sorted(os.listdir(eq)) + sorted(os.listdir(own))
proved = [i for i, k in enumerate(kinds) if k == 'proved']
removed = [i for i, k in enumerate(kinds) if k == 'removed']
refused = [i for i, k in enumerate(kinds) if k == 'refused']
outcome = [i for i, k in enumerate(kinds) if k == 'app-outcome' and ev[i].get('outcome') == 'flagged']
rm_paths = [ev[i].get('path') for i in removed]
# make_fail_request.py names job k's run <EQ_FAIL>/<name> and its owner <OWN_FAIL>/owners/<name>
job0 = [os.path.join(eq, 'c0'), os.path.join(eq, 'c0') + '.unverified-statement', os.path.join(own, 'c0')]
checks = {
    'child_rc_1': g.get('child_rc') == 1,
    'one_proved_job0': len(proved) == 1,
    'removed_after_proved': bool(removed) and bool(proved) and min(removed) > proved[0],
    'job0_three_dirs_removed': all(p in rm_paths for p in job0),
    'refused_after_removed': bool(refused) and bool(removed) and refused[0] > max(removed),
    'fail_closed_after_refused': bool(outcome) and bool(refused) and outcome[0] > refused[0],
    'no_batch_proved': 'batch-proved' not in kinds,
    'no_removal_failed': 'REMOVAL-FAILED' not in kinds,
    'nothing_left': left == [],
}
res = {'ok': all(checks.values()), 'checks': checks, 'events': kinds, 'removed_paths': rm_paths, 'left': left,
       'guard': {k: g.get(k) for k in ('exit', 'child_rc', 'child_wall_seconds', 'peak_rss_gib', 'peak_cgroup_gib', 'guard_killed', 'hard_killed', 'refused', 'note')}}
json.dump(res, open(out, 'w'), indent=1)
print(json.dumps({'ok': res['ok'], 'checks': checks, 'left': left}))
sys.exit(0 if res['ok'] else 1)
