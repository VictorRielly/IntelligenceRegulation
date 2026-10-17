#!/usr/bin/env python3
"""Read-only source/history checks; writes this experiment's audit artifacts."""
import hashlib
import json
import os
from pathlib import Path
import resource
import signal

HERE = Path(__file__).resolve().parent
RESEARCH = HERE.parent.parent


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def main():
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(55,55))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    pins=json.loads((HERE/'source-pins.json').read_text())
    for p in pins:
        assert sha(Path(p['path']))==p['sha256'],p['path']
        if p['snapshot']:
            assert sha(HERE/p['snapshot'])==p['sha256'],p['snapshot']
    prefix=json.loads((HERE/'history-prefixes.json').read_text())
    for f in ['FINDINGS.md','sources.jsonl']:
        with (RESEARCH/f).open('rb') as src:b=src.read(prefix[f]['bytes'])
        assert hashlib.sha256(b).hexdigest()==prefix[f]['sha256'],f
    assert sha(RESEARCH/'AGENDA.md')==prefix['AGENDA.md']['sha256']
    assert sha(HERE/'previous-state.md')==prefix['STATE.md']['sha256']
    assert sha(HERE/'previous-progress.md')==prefix['PROGRESS.md']['sha256']
    source_records=json.loads((HERE/'source-records.json').read_text())
    all_records=[json.loads(l) for l in (RESEARCH/'sources.jsonl').read_text().splitlines()]
    assert all_records[-len(source_records):]==source_records
    assert len({r['id'] for r in all_records})==len(all_records)
    for r in source_records:
        assert r['accessed_date']=='2026-09-27'
        assert all(k in r for k in ['published','updated','implementation_license','inspected_commit_id'])
    for directory in [HERE,HERE/'initial']:
        result=json.loads((directory/'result.json').read_text())
        assert result['status']=='passed'
        assert result['source_sha256']==sha(directory/'experiment.py')
        assert all(result['negative_controls'].values())
        assert result['elapsed_s']<60 and result['peak_rss_kib']<512*1024
        assert result['threads']==1 and len(result['affinity'])==1
        assert all(result[k] is None for k in ['proving_s','verification_s','complete_readiness_s'])
        assert not result['gpu_executed'] and not result['native_compiled']
    b=json.loads((HERE/'bottleneck.json').read_text())
    for run in b['runs']:
        assert sha(Path(run['log_path']))==run['sha256']
    final=json.loads((HERE/'result.json').read_text())
    assert len(final['negative_controls'])==13
    assert final['flat_chunk_stride_comparisons']==16
    assert final['independent_sector_formula']=={'compact':45568,'fused':49920}
    for c in final['traffic_cases']:
        assert c['compact']['logical_bytes']-c['fused']['logical_bytes']==c['logical_bytes_saved']
        assert c['coset_multiplications_compact']==c['coset_multiplications_fused']
    paths=[p for p in HERE.rglob('*') if p.is_file() and p.name not in
           ['artifact-sha256.json','validation.json','validation.log']]
    paths += [RESEARCH/'STATE.md',RESEARCH/'PROGRESS.md',RESEARCH/'FINDINGS.md',RESEARCH/'sources.jsonl',
              RESEARCH/'progress/20260927T015233Z-c29b434c.md',
              RESEARCH/'handoffs/20260927-ntt-pad-load-fusion.md']
    hashes={str(p.relative_to(RESEARCH)):sha(p) for p in paths}
    (HERE/'artifact-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
    check={'status':'passed','artifact_hashes':len(hashes),'original_source_hashes':len(pins),
           'snapshot_pairs':sum(bool(p['snapshot']) for p in pins),'owner_logs':len(b['runs']),
           'history_prefixes':2,'archived_state_progress':2,'source_records_appended':len(source_records),
           'experiment_runs':2,'native_or_gpu_execution':False,'production_mutation':False,
           'scope':'Hash, history and retained result audit only; no new performance or proof verification.'}
    (HERE/'validation.json').write_text(json.dumps(check,indent=2)+'\n')
    print(json.dumps(check,indent=2))


if __name__=='__main__':
    main()
