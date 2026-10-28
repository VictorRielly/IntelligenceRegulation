#!/usr/bin/env python3
"""Final provenance/report consistency check, no native work."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import resource
import signal

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    checks=0
    def ck(ok):
        nonlocal checks
        assert ok
        checks+=1
    sha=lambda b:hashlib.sha256(b).hexdigest()
    pins=json.loads((HERE/'source-pins.json').read_text())
    manifest=json.loads((HERE/'native/manifest_frozen.json').read_text())
    matched=0
    for p in pins:
        ck(sha(Path(p['source']).read_bytes())==p['sha256'])
        ck(sha((HERE/p['snapshot']).read_bytes())==p['sha256'])
        if p['r8_manifest_match']:
            rel=p['snapshot'][len('native/'):].replace('__','/')
            ck(manifest['files'][rel]==p['sha256']); matched+=1
    ck(matched==11)
    # Preserve original source/findings prefixes byte for byte.
    for name in ['sources.jsonl','FINDINGS.md']:
        old=(HERE/'startup'/name).read_bytes(); ck((ROOT/name).read_bytes().startswith(old))
    all_sources=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
    ours=json.loads((HERE/'source-records.json').read_text())
    ck(len(all_sources)==471); ck(all_sources[462:]==ours)
    for s in ours:
        ck(s['access_date']=='2026-10-19')
        ck('published' in s and 'updated' in s and 'implementation_license' in s and 'inspected_commit_id' in s)
        ck(s['reproduced_performance'] is False)
    results=json.loads((HERE/'result.json').read_text())
    audit=json.loads((HERE/'audit-result.json').read_text())
    ck(results['status']==audit['status']=='PASS')
    ck(results['checks']==67404 and audit['checks']==2738)
    ck(results['wall_seconds']<60 and audit['wall_seconds']<60)
    ck(results['rss_kib']<512*1024 and audit['rss_kib']<512*1024)
    ck(results['threads']==audit['threads']==1)
    ck(all(results['negative_controls'].values()))
    acct=json.loads((HERE/'target-accounting.json').read_text())
    ck(acct['new_target_positions']==acct['new_target_proofs']==acct['new_target_passes']==0)
    for field in ['startup_fraction','witness_seconds','proof_seconds','serialization_seconds','verification_seconds','target_total_workload_positions_per_second','target_steady_state_positions_per_second']:
        ck(acct[field] is None)
    for f in [ROOT/'STATE.md',ROOT/'PROGRESS.md',ROOT/'progress/20261019T171854Z-d589849d.md',HERE/'README.md']:
        text=f.read_text()
        ck('20261019T171854Z-d589849d' in text)
        ck('No speed improvement measured' in text)
        ck('0/0/0' in text)
        ck('raw arrays' in text)
        ck('0027' in text)
    ck('18:18:54' in (ROOT/'STATE.md').read_text())
    hyp=json.loads((HERE/'hypotheses.json').read_text())
    ck(len(hyp)>=3 and 'ownership transfer' in hyp[2]['hypothesis'])
    for row in hyp:
        ck(all(key in row for key in ['rank','hypothesis','baseline','eliminated_work','added_costs','end_to_end_ceiling','prerequisites','integration_cost','exactness','privacy_soundness','falsification']))
    ck('scope' in results and 'Synthetic' in results['scope'])
    val=dict(status='PASS',checks=checks,source_pins_unchanged=len(pins),r8_manifest_matches=matched,
      prior_sources_and_findings_preserved=True,source_records_before=462,source_records_after=471,
      timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (HERE/'validation.json').write_text(json.dumps(val,indent=2)+'\n')
    print(json.dumps(val))


if __name__=='__main__': main()
