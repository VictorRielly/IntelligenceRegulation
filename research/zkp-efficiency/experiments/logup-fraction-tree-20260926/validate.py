#!/usr/bin/env python3
"""Validate retained evidence without repeating the experiment or running a proof."""
import datetime
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
RESEARCH=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
    result=json.loads((HERE/'result.json').read_text())
    assert result==json.loads((HERE/'run.log').read_text())
    assert result['source_sha256']==sha((HERE/'experiment.py').read_bytes())
    assert result['status']=='passed'
    assert result['fraction_cases']==150 and result['lookup_identities']==100
    assert result['independent_mle_checks']==300
    assert len(result['negative_controls'])==15 and all(result['negative_controls'].values())
    assert result['elapsed_s']<60 and result['peak_rss_kib']<512*1024
    assert result['threads']==1 and len(result['affinity'])==1
    for key in ['proving_s','verification_s','complete_readiness_s']:
        assert result[key] is None
    pins=json.loads((HERE/'source-pins.json').read_text())['files']
    for entry in pins:
        assert sha(Path(entry['path']).read_bytes())==entry['sha256'],entry['path']
        if 'snapshot' in entry:
            assert sha((HERE/entry['snapshot']).read_bytes())==entry['sha256']
    b=json.loads((HERE/'bottleneck.json').read_text())
    assert sha(Path(b['comparison_path']).read_bytes())==b['comparison_sha256']
    for row in b['runs']:
        assert sha(Path(row['log_path']).read_bytes())==row['sha256']
    h=json.loads((HERE/'history-prefixes.json').read_text())
    for name in ['FINDINGS.md','sources.jsonl']:
        assert sha((RESEARCH/name).read_bytes()[:h[name]['bytes']])==h[name]['sha256']
    assert sha((HERE/'previous-STATE.md').read_bytes())==h['STATE.md']['sha256']
    records=json.loads((HERE/'source-records.json').read_text())
    all_records=[json.loads(line) for line in (RESEARCH/'sources.jsonl').read_text().splitlines()]
    assert all_records[-8:]==records and len(records)==8
    assert len({x.get('id') for x in all_records})==len(all_records)
    costs=result['costs']
    # Independently sum all layer widths, rather than closed-form node count.
    total_nodes=sum(2**j for j in range(28))
    for option in costs['tree_options']:
        assert option['full_tree_bytes']==total_nodes*32
        assert option['flat_unencoded_tree_base_rows']==65536
        assert option['merge_count']==sum(2**j for j in range(27))
        assert option['extension_multiplications']==3*option['merge_count']
    assert costs['h_rows']==7120
    assert all(any('7120 rows' in s for s in row['h_phase_lines']) for row in b['runs'] if row['summary']['arm']=='new')
    assert costs['gross_helper_data_rows']+2+100+2==costs['h_rows']
    assert costs['net_commitment_rows_saved'] is None
    initial=json.loads((HERE/'initial/result.json').read_text())
    assert initial['differential_digest']==result['differential_digest']
    assert sha((HERE/'initial/experiment.py').read_bytes())==initial['source_sha256']
    assert initial==json.loads((HERE/'initial/run.log').read_text())
    out=dict(status='passed',validated_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source_files=len(pins),native_snapshots=sum('snapshot' in e for e in pins),owner_logs=len(b['runs']),
        preserved_history_prefixes=True,source_records=8,initial_correction_preserved=True,
        result_sha256=sha((HERE/'result.json').read_bytes()),run_log_sha256=sha((HERE/'run.log').read_bytes()),
        experiment_reexecuted=False,native_proofs_executed=False)
    (HERE/'validation.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
