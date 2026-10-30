from pathlib import Path
import datetime,hashlib,json,re
D=Path(__file__).resolve().parent;R=D.parents[1];P=R.parents[1]
RUN='20261030T104123Z-3535232c'
checks={}
for name in ['FINDINGS.md','sources.jsonl']:
    old=(D/'startup'/name).read_bytes();current=(R/name).read_bytes()
    assert current.startswith(old),name;checks[name+'_preserved_prefix']=True
old=[json.loads(s) for s in (D/'startup/sources.jsonl').read_text().splitlines()]
current=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
new=[s for s in current if s.get('run_id')==RUN];assert len(old)==1070 and len(new)==9 and len(current)==1079
assert len({s['id'] for s in new})==9 and all(s['external_execution'] is False and s['reproduced_performance'] is False for s in new)
checks['sources_append_count']=9
for pin in json.loads((D/'artifact-manifest.json').read_text()):
    f=D/pin['path'];b=f.read_bytes();assert len(b)==pin['bytes'] and hashlib.sha256(b).hexdigest()==pin['sha256'],str(f)
checks['manifest_entries_verified']=len(json.loads((D/'artifact-manifest.json').read_text()))
t=json.loads((D/'target-accounting.json').read_text());assert t['proved_positions']==t['complete_model_passes']==t['complete_independently_verified_full_stack_proofs']==0
assert not t['target_achieved'] and not t['workload_kinds_run'] and t['gpu_count']==0
for k in ['witness_s','proof_s','serialization_s','verification_s','startup_s','initial_prefill_s','startup_fraction','steady_proved_tokens_per_s','total_workload_proved_tokens_per_s']:
    assert t[k] is None
checks['zero_count_and_unmeasured_clocks']=True
r=json.loads((D/'result.json').read_text());assert (r['fixture_groups'],r['independent_scalar_jobs'],r['rust_job_runs'],r['control_count'],r['numeric_limb_comparisons'])==(42,126,378,22,21744)
for row in r['rows']:
    assert row['field_work_saved']==0
    assert row['schedules'][0]['round_evaluate_fold_submissions']==2*sum(row['n'])
    assert all(x['round_evaluate_fold_submissions']==2*max(row['n']) for x in row['schedules'][1:])
checks['result_accounting_verified']=True
for f in [R/'STATE.md',R/'PROGRESS.md',R/'progress'/f'{RUN}.md',R/'handoffs/20261030-separate-proof-round-batch.md']:
    text=f.read_text();assert '0 / 0 / 0' in text and 'unmeasured' in text and 'No measured proving improvement' in text
checks['required_reports_verified']=True
memory=[]
for name in ['AGENDA.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md']:
    actual=R/name if name=='AGENDA.md' else P/'docs/zkmatrix-poc'/name
    memory.append(dict(path=str(actual),unchanged=actual.read_bytes()==(D/'startup'/name).read_bytes(),sha256=hashlib.sha256(actual.read_bytes()).hexdigest()))
assert all(x['unchanged'] for x in memory),memory
checks['owner_memory_unchanged']=memory
now=datetime.datetime.now(datetime.timezone.utc);start=datetime.datetime.fromisoformat('2026-10-30T10:41:23+00:00')
assert (now-start).total_seconds()<1200
checks['completed_within_cycle_deadline']=True;checks['at']=now.isoformat();checks['status']='PASS'
(D/'final-audit.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps(checks,indent=2))
