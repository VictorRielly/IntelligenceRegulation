#!/usr/bin/env python3
"""Read-only verification of retained inputs/logs; writes local validation only."""
import datetime
import hashlib
import json
from pathlib import Path
import resource
import signal
import os

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_AS, (512*2**20,512*2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (55,55))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    r = json.loads((HERE/'result.json').read_text())
    assert r['status'] == 'passed' and r['differential_cases'] == 385
    assert r['field_outputs_compared'] == 29290
    assert r['independent_eq_entries'] == 13260
    assert r['independent_matrix_mles'] == 360
    assert r['fixture_refusals'] == 6 and len(r['negative_controls']) == 8
    assert all(r['negative_controls'].values())
    assert r['source_sha256'] == sha(HERE/'experiment.py')
    assert r['threads'] == 1 and len(r['cpu_affinity']) == 1
    assert r['elapsed_s'] < 60 and r['peak_rss_kib'] < 512*1024
    assert all(r[k] is None for k in ['proving_s','verification_s','complete_readiness_s'])
    for path,want in json.loads((HERE/'source-pins.json').read_text()).items():
        assert sha(Path(path)) == want, path
    history = json.loads((HERE/'history-prefixes.json').read_text())
    for name in ['FINDINGS.md','sources.jsonl']:
        data = (ROOT/name).read_bytes()[:history[name]['bytes']]
        assert hashlib.sha256(data).hexdigest() == history[name]['sha256'], name
    records = json.loads((HERE/'source-records.json').read_text())
    log = [json.loads(line) for line in (ROOT/'sources.jsonl').read_text().splitlines()]
    assert len(records) == 6
    for src in records:
        assert sum(s.get('id')==src['id'] for s in log) == 1
        assert src in log and src['accessed_date'] == '2026-09-26'
    b = json.loads((HERE/'bottleneck.json').read_text())
    assert sha(Path(b['comparison_path'])) == b['comparison_sha256']
    comp = json.loads(Path(b['comparison_path']).read_text())
    assert comp['state'] == 'passed'
    assert (Path(b['comparison_path']).parent/'run.done').read_text().strip() == '0'
    for case in b['runs']:
        path = Path(case['log_path'])
        assert sha(path) == case['sha256'] == case['summary']['log_sha256']
        data = path.read_text()
        assert all(line in data for line in case['selected_lines'])
        a = case['accounting']
        assert abs(a['known_readiness_s']-sum(a[k] for k in ['prove_s','witness_s','serialization_s'])) < 1e-9
        assert a['entire_three_slots_ceiling_fraction'] < .001
    traffic = json.loads((HERE/'traffic.json').read_text())
    for t in traffic:
        rows,cols,batch,tile = [t[k] for k in ['rows','cols','batch','row_tile']]
        coeff = ((rows+tile-1)//tile)*cols*batch*16
        assert coeff == t['coefficient_bytes']
        assert t['independent_resident_bytes'] == batch*rows*cols + coeff + 16*batch*rows
        assert t['batched_resident_bytes'] == rows*cols + coeff + 16*batch*rows
        assert t['accumulator_update_bytes'] == 32*batch*rows*cols
        if batch == 1: assert t['resident_reduction_fraction'] == 0
    artifacts={str(p.relative_to(ROOT)):sha(p) for p in HERE.iterdir()
               if p.is_file() and p.name not in ['validation.json','validation.log']}
    out=dict(status='passed',run_identity=r['run_identity'],
             checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
             retained_sources_match=True,retained_owner_log_hashes_match=True,
             historical_findings_and_sources_prefix_preserved=True,
             source_records_added=len(records),artifact_sha256=artifacts,
             experiment_command='python3 experiments/batched-weight-fold-20260926/experiment.py > experiments/batched-weight-fold-20260926/run.log 2>&1',
             validation_command='python3 experiments/batched-weight-fold-20260926/validate.py > experiments/batched-weight-fold-20260926/validation.log 2>&1',
             cwd=str(ROOT),native_patch_applied=False,native_builds=False,gpu_jobs=False,
             production_or_runtime_writes=False,git_operations=False,dependencies_installed=False,
             downloaded_code_executed=False,external_writes_or_messages=False)
    (HERE/'validation.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out,indent=2))

if __name__ == '__main__':
    main()
