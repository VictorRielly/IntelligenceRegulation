#!/usr/bin/env python3
"""Names every guarded job in results/zk60_resource_guard/history.jsonl (the main checkout's) whose run overlapped a timed leg of the sets in RAW_DIR.
A leg's window is its utc_start to utc_end (driver records); a job's window is ts_end minus child_wall_seconds to ts_end. Standard library only.

usage: overlap_check.py [RAW_DIR]
"""
import datetime
import json
import sys
from pathlib import Path

raw = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw'
hist = Path('/Users/victorrielly/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl')


def ts(s):
    return datetime.datetime.strptime(s, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()


legs = []
for sub in ('hf_smoke', 'hf_set1', 'hf_set2', 'hf_trace', 'hf_lt8'):
    p = raw / sub / 't2_results.json'
    if p.exists():
        for l in json.load(open(p))['legs']:
            legs.append((sub, l['leg'], l['arm'], ts(l['utc_start']), ts(l['utc_end'])))
mine = {json.load(open(f))['run_id'] for f in raw.glob('*.guard.json')}
jobs = []
for line in open(hist):
    try:
        j = json.loads(line)
    except ValueError:
        continue
    if 'ts_end' not in j or j.get('child_wall_seconds') is None:
        continue
    end = ts(j['ts_end'])
    jobs.append((j.get('run_id'), j.get('label'), j.get('class'), end - float(j['child_wall_seconds']), end))
found = 0
for sub, n, arm, a, b in legs:
    for rid, label, cls, s, e in jobs:
        if rid in mine:
            continue
        if s < b and e > a:
            found += 1
            print(f'{sub} leg {n} (arm {arm}) overlapped by guarded job {rid} {label} class {cls}: {e - s:.0f} s, overlap {min(b, e) - max(a, s):.0f} s')
print(f'{len(legs)} timed legs checked against {len(jobs)} history records; {found} overlaps by jobs other than this test\'s own')
