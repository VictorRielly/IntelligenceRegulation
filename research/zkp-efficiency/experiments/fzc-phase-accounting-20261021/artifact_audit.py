"""Final integrity check, without rerunning the numerical experiment."""
import datetime,hashlib,json
from pathlib import Path
E=Path(__file__).resolve().parent;R=E.parents[1]
checks=0
def check(x):
    global checks
    assert x
    checks+=1
manifest=json.loads((E/'artifact-manifest.json').read_text())
for entry in manifest:
    p=R/entry['path'];check(p.is_relative_to(R) and not p.is_relative_to(R/'runtime'))
    check(hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256'])
prior_src=(E/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
added=(E/'source-records.jsonl').read_bytes();full=(R/'sources.jsonl').read_bytes()
check(full==prior_src+added)
old=[json.loads(l) for l in prior_src.splitlines()];new=[json.loads(l) for l in added.splitlines()]
check(len(old)==751 and len(new)==9 and len(full.splitlines())==760)
for record in new:
    check(record['access_date']=='2026-10-21' and record['run_id']=='20261021T041854Z-cfd5ba2e')
    check(record['external_execution'] is False and record['reproduced_performance'] is False)
    check(record['url'].startswith('https://') and 'date_evidence' in record and 'implementation_license' in record)
prior_find=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
check((R/'FINDINGS.md').read_bytes().startswith(prior_find))
check(len(prior_find.splitlines())==10218)
old_h=json.loads((E/'prior-hypotheses.json').read_text());h=json.loads((E/'hypotheses.json').read_text())
check(len(h)==len(old_h)==34);check([x['rank'] for x in h]==list(range(1,35)))
for a,b in zip(old_h,h):
    if a['rank'] not in [1,3,25,34]:check(a==b)
    else:check(a!=b and b['falsification'] and b['privacy_soundness'])
for x in json.loads((E/'source-pins.json').read_text()):
    check(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
    check(hashlib.sha256((R/x['copy']).read_bytes()).hexdigest()==x['sha256'])
result=json.loads((E/'result.json').read_text());source=json.loads((E/'source-audit-result.json').read_text())
check(result['checks']==6829 and source['checks']==59)
check(result['threads']==1 and result['rss_kib']<512*1024 and result['wall_seconds']<60)
check(source['rss_kib']<512*1024 and source['wall_seconds']<60)
check(result['critical_path_counterexample']['overlap']['before']==result['critical_path_counterexample']['serial']['before']==30)
check(result['critical_path_counterexample']['overlap']['saved']==0)
check(result['critical_path_counterexample']['serial']['saved']==8)
check(result['negative_control_types']==21)
metrics=json.loads((E/'target-accounting.json').read_text())
for k in ['completed_independently_verified_full_stack_proofs','complete_model_passes','proved_positions']:check(metrics[k]==0)
for k in ['witness_seconds','proof_seconds','serialization_seconds','verification_seconds','startup_seconds','startup_fraction','steady_state_proved_positions_per_second','total_workload_proved_positions_per_second','model_context_length','accelerator']:check(metrics[k] is None)
for path in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261021T041854Z-cfd5ba2e.md']:
    text=path.read_text();check('20261021T041854Z-cfd5ba2e' in text and 'unmeasured' in text and 'unachieved' in text)
    check('one-hot' in text and ('parked' in text or 'park' in text))
check('Next cycle no earlier than2026-10-21T05:18:54Z' in (R/'STATE.md').read_text())
checkpoint=json.loads((E/'checkpoint-updates.json').read_text())
check(datetime.datetime.fromisoformat(checkpoint['utc'])<datetime.datetime(2026,10,21,4,38,54,tzinfo=datetime.timezone.utc))
out={'status':'PASS_ARTIFACT_AND_HISTORY_INTEGRITY','checks':checks,'artifact_hashes':len(manifest),
     'preserved_prior_sources':751,'new_sources':9,'preserved_prior_findings_lines':10218,
     'retained_hypotheses':34,'live_source_pins':3,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(E/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
